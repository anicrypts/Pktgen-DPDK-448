-- Literally Just Enable Latency

package.path = package.path ..";?.lua;test/?.lua;app/?.lua;"
require "Pktgen";

pktgen.clr();
pktgen.sleep(2);

pktgen.set(0, "rate", 100);
pktgen.latency(0, "enable");
pktgen.sleep(1);

printf("starting traffic\n");
pktgen.start(0);