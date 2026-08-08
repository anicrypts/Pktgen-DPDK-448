sudo -E  taskset -c 16-31 build/app/pktgen -l 16-31 -n 4 -a e2:00.0 -- -v -m "[17-31:17-31].0" -s 0:${PCAP_PATH} -f scripts/benchmark.lua -o ${SAMPLE_STATS_FILE_PATH} -u ${SUM_STATS_FILE_PATH}
