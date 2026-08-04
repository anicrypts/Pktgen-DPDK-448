package.path = package.path ..";?.lua;test/?.lua;app/?.lua;"

require "Pktgen"

printf("Starting trial\n");

pktgen.clr();
pktgen.reset(0);
pktgen.stop(0);
pktgen.latency('0', 'enable');
pktgen.delay(200);

printf("Starting traffic\n");
pktgen.start(0);
sleep(5);


prints("portStats", pktgen.portStats('0', 'port'));
prints("portRates", pktgen.portStats("0", "rate"));

pktgen.stop(0);
sleep(1);

pktgen.quit();



