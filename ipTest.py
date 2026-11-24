from TestSim import TestSim

def main():
    s = TestSim();
    s.runTime(1);
    s.loadTopo("long_line.topo");
    s.loadNoise("no_noise.txt");
    s.bootAll();

    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    s.addChannel(s.ROUTING_CHANNEL);

    # wait for routes: ~3 s per hop plus neighbor discovery. 60 is plenty for 6 hops.
    s.runTime(60);

    s.ping(1, 4, "Hello");     # 3 hops: 1 -> 2 -> 3 -> 4
    s.runTime(10);

    s.ping(1, 19, "Far");      # 18 hops: no route, must be dropped (not flooded)
    s.runTime(10);

if __name__ == '__main__':
    main()
