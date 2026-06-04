-- =============================================================================
-- pktgen_stats_logger.lua
-- Logs pktgen-DPDK port statistics (throughput, packet rates, errors, etc.)
-- to a timestamped CSV file at a configurable interval.
--
-- Usage (from pktgen prompt):
--   pktgen> script pktgen_stats_logger.lua
--
-- Or launch pktgen with:
--   pktgen ... -- -f pktgen_stats_logger.lua
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------
local CFG = {
    ports         = { 0, 1 },       -- Ports to monitor (adjust as needed)
    interval_ms   = 1000,           -- Sampling interval in milliseconds
    duration_s    = 60,             -- Total run duration in seconds (0 = infinite)
    log_dir       = "/tmp",         -- Directory for the log file
    log_prefix    = "pktgen_stats", -- Log filename prefix
    send_traffic  = true,           -- Whether to start/stop traffic automatically
    packet_size   = 64,             -- Packet size in bytes (for auto-traffic)
    -- Traffic config per port (only used when send_traffic = true)
    traffic = {
        [0] = { dst_mac = "d0:e0:f0:00:01:02",
                src_ip  = "192.168.0.1",
                dst_ip  = "192.168.0.2",
                sport   = 1234,
                dport   = 5678 },
        [1] = { dst_mac = "a0:b0:c0:00:01:02",
                src_ip  = "192.168.1.1",
                dst_ip  = "192.168.1.2",
                sport   = 1234,
                dport   = 5678 },
    },
}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Return a formatted timestamp string (YYYY-MM-DD HH:MM:SS).
local function timestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

--- Return a compact timestamp suitable for a filename (YYYYMMDD_HHMMSS).
local function timestamp_filename()
    return os.date("%Y%m%d_%H%M%S")
end

--- Sleep for `ms` milliseconds using pktgen's built-in sleep.
local function sleep_ms(ms)
    pktgen.sleep(ms)
end

--- Build a comma-separated port list string, e.g. "0,1".
local function port_list_str(ports)
    local parts = {}
    for _, p in ipairs(ports) do
        parts[#parts + 1] = tostring(p)
    end
    return table.concat(parts, ",")
end

-- ---------------------------------------------------------------------------
-- CSV log file
-- ---------------------------------------------------------------------------

local log_path = string.format("%s/%s_%s.csv",
    CFG.log_dir, CFG.log_prefix, timestamp_filename())

local log_file = io.open(log_path, "w")
if not log_file then
    error("Cannot open log file: " .. log_path)
end

--- Write the CSV header row.
local function write_header()
    local cols = {
        "timestamp",
        "elapsed_s",
        "port",
        -- Throughput
        "rx_mbps",
        "tx_mbps",
        -- Packet rates
        "rx_pps",
        "tx_pps",
        -- Cumulative counters
        "rx_packets",
        "tx_packets",
        "rx_bytes",
        "tx_bytes",
        -- Error / drop counters
        "rx_errors",
        "tx_errors",
        "rx_missed",
        "rx_nombuf",
        -- Derived
        "rx_avg_pkt_bytes",
        "tx_avg_pkt_bytes",
    }
    log_file:write(table.concat(cols, ",") .. "\n")
    log_file:flush()
end

--- Write one data row per port.
local function write_stats(elapsed, stats_by_port)
    local ts = timestamp()
    for port, s in pairs(stats_by_port) do
        local row = string.format(
            "%s,%.3f,%d,"         -- timestamp / elapsed / port
            .. "%.3f,%.3f,"       -- rx_mbps / tx_mbps
            .. "%d,%d,"           -- rx_pps  / tx_pps
            .. "%d,%d,"           -- rx_packets / tx_packets
            .. "%d,%d,"           -- rx_bytes   / tx_bytes
            .. "%d,%d,%d,%d,"     -- errors / missed / nombuf
            .. "%.1f,%.1f",       -- avg pkt size
            ts, elapsed, port,
            s.rx_mbps,  s.tx_mbps,
            s.rx_pps,   s.tx_pps,
            s.rx_pkts,  s.tx_pkts,
            s.rx_bytes, s.tx_bytes,
            s.rx_errors, s.tx_errors, s.rx_missed, s.rx_nombuf,
            s.rx_avg,   s.tx_avg
        )
        log_file:write(row .. "\n")
    end
    log_file:flush()
end

-- ---------------------------------------------------------------------------
-- Stats collection
-- ---------------------------------------------------------------------------

-- Previous cumulative counters per port (for delta / rate calculation).
local prev = {}

--- Initialise previous-counter table for a port.
local function init_prev(port)
    prev[port] = {
        rx_pkts  = 0, tx_pkts  = 0,
        rx_bytes = 0, tx_bytes = 0,
        rx_errors = 0, tx_errors = 0,
        rx_missed = 0, rx_nombuf = 0,
        time_ms  = pktgen.get_time() * 1000,
    }
end

--- Collect current stats for all configured ports.
--- Returns a table keyed by port number.
local function collect_stats()
    local results = {}
    local now_ms  = pktgen.get_time() * 1000

    for _, port in ipairs(CFG.ports) do
        -- pktgen.portStats() returns a table of port statistics.
        local ps = pktgen.portStats(port, "port")

        -- Pull raw counters (fall back to 0 if field absent).
        local rx_pkts   = ps.ipackets  or 0
        local tx_pkts   = ps.opackets  or 0
        local rx_bytes  = ps.ibytes    or 0
        local tx_bytes  = ps.obytes    or 0
        local rx_errors = ps.ierrors   or 0
        local tx_errors = ps.oerrors   or 0
        local rx_missed = ps.imissed   or 0
        local rx_nombuf = ps.rx_nombuf or 0

        if not prev[port] then
            init_prev(port)
        end

        local p       = prev[port]
        local dt_ms   = math.max(now_ms - p.time_ms, 1)  -- avoid /0
        local dt_s    = dt_ms / 1000.0

        -- Deltas
        local d_rx_pkts  = rx_pkts  - p.rx_pkts
        local d_tx_pkts  = tx_pkts  - p.tx_pkts
        local d_rx_bytes = rx_bytes  - p.rx_bytes
        local d_tx_bytes = tx_bytes  - p.tx_bytes

        -- Rates
        local rx_pps   = d_rx_pkts  / dt_s
        local tx_pps   = d_tx_pkts  / dt_s
        local rx_mbps  = (d_rx_bytes * 8) / dt_s / 1e6
        local tx_mbps  = (d_tx_bytes * 8) / dt_s / 1e6

        -- Average packet sizes (over the interval)
        local rx_avg = (d_rx_pkts > 0) and (d_rx_bytes / d_rx_pkts) or 0
        local tx_avg = (d_tx_pkts > 0) and (d_tx_bytes / d_tx_pkts) or 0

        results[port] = {
            rx_mbps   = rx_mbps,   tx_mbps   = tx_mbps,
            rx_pps    = math.floor(rx_pps),
            tx_pps    = math.floor(tx_pps),
            rx_pkts   = rx_pkts,   tx_pkts   = tx_pkts,
            rx_bytes  = rx_bytes,  tx_bytes  = tx_bytes,
            rx_errors = rx_errors, tx_errors = tx_errors,
            rx_missed = rx_missed, rx_nombuf = rx_nombuf,
            rx_avg    = rx_avg,    tx_avg    = tx_avg,
        }

        -- Update previous snapshot
        prev[port] = {
            rx_pkts   = rx_pkts,  tx_pkts   = tx_pkts,
            rx_bytes  = rx_bytes, tx_bytes  = tx_bytes,
            rx_errors = rx_errors, tx_errors = tx_errors,
            rx_missed = rx_missed, rx_nombuf = rx_nombuf,
            time_ms   = now_ms,
        }
    end

    return results
end

-- ---------------------------------------------------------------------------
-- Console summary (printed each interval)
-- ---------------------------------------------------------------------------

local function print_summary(elapsed, stats_by_port)
    print(string.rep("-", 72))
    print(string.format("  [%s]  elapsed: %.0f s", timestamp(), elapsed))
    print(string.format("  %-6s  %-10s  %-10s  %-10s  %-10s  %-8s",
        "Port", "RX Mbps", "TX Mbps", "RX pps", "TX pps", "RX err"))
    print(string.rep("-", 72))
    for _, port in ipairs(CFG.ports) do
        local s = stats_by_port[port]
        if s then
            print(string.format("  %-6d  %-10.2f  %-10.2f  %-10d  %-10d  %-8d",
                port, s.rx_mbps, s.tx_mbps, s.rx_pps, s.tx_pps, s.rx_errors))
        end
    end
    print(string.rep("-", 72))
end

-- ---------------------------------------------------------------------------
-- Traffic setup
-- ---------------------------------------------------------------------------

local function configure_traffic()
    for _, port in ipairs(CFG.ports) do
        local t = CFG.traffic[port]
        if t then
            -- Ethernet / IP / UDP defaults
            pktgen.set(port, "size",  CFG.packet_size)
            pktgen.set(port, "sport", t.sport)
            pktgen.set(port, "dport", t.dport)
            pktgen.set_mac(port, "dst", t.dst_mac)
            pktgen.set_ipaddr(port, "dst", t.dst_ip)
            pktgen.set_ipaddr(port, "src", t.src_ip .. "/24")
            pktgen.set(port, "proto", "udp")
        end
    end
end

-- ---------------------------------------------------------------------------
-- Main
-- ---------------------------------------------------------------------------

local function main()
    print("\n=== pktgen stats logger ===")
    print("Log file: " .. log_path)
    print("Ports   : " .. port_list_str(CFG.ports))
    print("Interval: " .. CFG.interval_ms .. " ms")
    if CFG.duration_s > 0 then
        print("Duration: " .. CFG.duration_s .. " s")
    else
        print("Duration: infinite (Ctrl-C to stop)")
    end
    print("")

    -- Optional: set up and start traffic
    if CFG.send_traffic then
        configure_traffic()
        pktgen.start(port_list_str(CFG.ports))
        print("Traffic started on ports: " .. port_list_str(CFG.ports))
    end

    -- Warm-up: one sampling cycle to seed the previous-counter table
    collect_stats()
    sleep_ms(CFG.interval_ms)

    -- Write CSV header
    write_header()

    local start_time = pktgen.get_time()
    local iteration  = 0

    -- Sampling loop
    while true do
        iteration = iteration + 1
        local elapsed = pktgen.get_time() - start_time

        local stats = collect_stats()
        write_stats(elapsed, stats)
        print_summary(elapsed, stats)

        -- Check duration limit
        if CFG.duration_s > 0 and elapsed >= CFG.duration_s then
            print("\nDuration reached. Stopping.")
            break
        end

        sleep_ms(CFG.interval_ms)
    end

    -- Stop traffic if we started it
    if CFG.send_traffic then
        pktgen.stop(port_list_str(CFG.ports))
        print("Traffic stopped.")
    end

    log_file:close()
    print("Stats written to: " .. log_path)
end

-- Run
main()
