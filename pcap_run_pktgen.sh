sudo -E  taskset -c 0-15  build/app/pktgen -l 16,17,18,19,20,21,22,23 -n 4  -a e2:00.0 -- -v -m [17:17-23].0 -s 0:pcaps-others/large.pcap
