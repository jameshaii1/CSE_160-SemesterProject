from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    s.runTime(1);


    s.loadTopo("long_line.topo");

    s.loadNoise("no_noise.txt");

    s.bootAll();

    s.addChannel(s.GENERAL_CHANNEL);
    s.addChannel(s.FLOODING_CHANNEL);
    s.addChannel(s.NEIGHBOR_CHANNEL);

    s.runTime(1);

    s.ping(6, 19, "TESTING SOMETHING!");

    s.runTime(10);

if __name__ == '__main__':
    main()
