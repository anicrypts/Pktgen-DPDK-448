package.path = package.path ..";?.lua;test/?.lua;app/?.lua;"

require "Pktgen"

printf("Starting trial\n");

pktgen.reset(0);
pktgen.stop(0);
--pktgen.latency(0, 'on');
sleep(2);

printf("Starting port\n");
pktgen.start(0);
sleep(5);


prints("portStats", pktgen.portStats('0', 'port'));

pktgen.stop(0);
sleep(1);

pktgen.quit();



