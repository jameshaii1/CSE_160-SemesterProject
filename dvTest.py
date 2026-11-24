from TestSim import TestSim

def main():
    s = TestSim();
    s.runTime(1);

    # long_line.topo is 1-2-3-...: node N only hears N-1 and N+1, so a
    # route to node 4 from node 1 can only exist via 2, then 3.
    s.loadTopo("long_line.topo");
    s.loadNoise("no_noise.txt");
    s.bootAll();

    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.ROUTING_CHANNEL);
    s.addChannel(s.NEIGHBOR_CHANNEL);
    s.addChannel(s.ROUTING_CHANNEL);

    # 1) Convergence. Neighbor discovery needs ~5 rounds (about 4 s) to see
    #    neighbors, and DV advertises every 3 s, with one extra hop learned
    #    per round. 30 s is plenty for nodes 1-4.
    s.runTime(150);
    s.routeDMP(1);   # expect: 1 cost 0, 2 cost 1 via 2, 3 cost 2 via 2, 4 cost 3 via 2
    s.runTime(1);
    s.routeDMP(3);
    s.runTime(1);   # expect: 1 cost 2 via 2, 2 cost 1 via 2, 4 cost 1 via 4, 5 cost 2 via 4

    s.runTime(1);
    s.moteOff(4);
    s.runTime(15);
    s.routeDMP(3);
    s.runTime(1);


    s.runTime(5);
    s.routeDMP(1);
    s.runTime(1);


    s.moteOn(4);

    s.runTime(150);
    s.routeDMP(3);
    s.runTime(1);
    s.routeDMP(1);
    s.runTime(12);
    s.ping(1,7, "Hi");
    s.runTime(15);


if __name__ == '__main__':
    main()

