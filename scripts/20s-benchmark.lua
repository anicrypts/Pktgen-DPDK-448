package.path = package.path ..";?.lua;test/?.lua;app/?.lua;"
require "Pktgen";

pktgen.clr();
pktgen.delay(100);

pktgen.set(0, "rate", 100);
pktgen.jitter(0, 20);
pktgen.latency(0, "enable");
pktgen.delay(200);

-- printf("starting traffic\n");
pktgen.start(0);
pktgen.page("latency");
pktgen.sleep(30);
-- printf("stopping traffic\n");
pktgen.stop(0);
pktgen.quit();
