from TestSim import TestSim

def main():
    s = TestSim();
    s.runTime(1);

    s.loadTopo("long_line.topo");
    s.loadNoise("no_noise.txt");
    s.bootAll();

    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.TRANSPORT_CHANNEL);


    s.runTime(150);
    s.testServer(3);

    s.runTime(10);
    s.testClient(1);

    s.runTime(10);
    s.testWrite(1);

    s.runTime(10);
    s.testClose(1);

    s.runTime(300);

if __name__ == '__main__':
    main()

