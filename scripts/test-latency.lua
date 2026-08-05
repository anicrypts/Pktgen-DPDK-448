-- referenced test/tx-rx-loopback.lua

package.path = package.path ..";?.lua;test/?.lua;app/?.lua;"
require "Pktgen";

-- set up trace values since we can't use a pcap to test
local src_ip   = "192.168.0.1";
local dst_ip   = "192.168.0.2";
local sport    = 1024;
local dport    = 5678;
local src_mac  = "e8:eb:d3:49:51:60";
local dst_mac  = "e8:eb:d3:49:50:a0"; 
local pkt_size = 96; 

pktgen.clr();
pktgen.sleep(2);

-- send continuous stream of traffic
pktgen.set(0, "count", 0);
-- pktgen.set(0, "rate", 0.1);
pktgen.latency(0, "enable");

pktgen.set(0, "size", pkt_size);
pktgen.set(0, "sport", sport);
pktgen.set(0, "dport", dport);

pktgen.set_ipaddr(0, "src", src_ip);
pktgen.set_ipaddr(0, "dst", dst_ip);
pktgen.set_mac(0, "src", src_mac);
pktgen.set_mac(0, "dst", dst_mac);
pktgen.set_proto(0, "udp");
pktgen.sleep(1);

printf("starting traffic\n");
pktgen.start(0);
pktgen.sleep(4);

prints("portStats", pktgen.portStats(0, "port"));
pktgen.sleep(5);
prints("pktStats", pktgen.pktStats(0));
pktgen.sleep(5);
prints("portRates", pktgen.portStats(0, "rate"));