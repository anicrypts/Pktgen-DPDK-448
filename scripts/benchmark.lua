package.path = package.path ..";?.lua;test/?.lua;app/?.lua;"
require "Pktgen";

pktgen.clr();
pktgen.delay(100);

pktgen.set(0, "rate", 100);
pktgen.latency(0, "enable");
pktgen.delay(200);

-- printf("starting traffic\n");
pktgen.start(0);
pktgen.sleep(180);
-- printf("stopping traffic\n");
pktgen.stop(0);
pktgen.quit();