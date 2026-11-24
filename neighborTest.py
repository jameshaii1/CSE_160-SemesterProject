from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # example.topo is a mesh with cycles and nodes that have several
    # neighbors each (unlike long_line.topo, where every node has at
    # most two) -- better for actually seeing a neighbor table fill up.
    s.loadTopo("long_line.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");

    # Turn on all of the sensors. Neighbor discovery starts itself as
    # soon as each node's radio comes up (AMControl.startDone calls
    # findNeighbor()), so there's no ping/command needed to kick this off.
    s.bootAll();

    # Add the channels we care about for neighbor discovery specifically.
    # GENERAL_CHANNEL is left out on purpose -- it's just radio-level
    # "Packet Received" noise that drowns out the neighbor table dump.
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.NEIGHBOR_CHANNEL);

    # neighborTimer fires every 500ms -- run long enough to see several
    # rounds of ping -> reply -> addNeighbor, so counts actually grow
    # and you can tell a real neighbor apart from a one-off fluke.
    s.runTime(15);
    s.neighborDMP(3);



    # Dump node 3's neighbor table -- it has the most links in example.topo
    # (1, 2, 4, 5, 6), so it's the clearest node to inspect.
  #  s.moteOff(4);
 #   s.runTime(9);
#
   # s.neighborDMP(3);

   # s.runTime(1);
#
 #   s.moteOn(4);
  #  s.runTime(15);
   # s.neighborDMP(3);

    #s.runTime(1);

if __name__ == '__main__':
    main()
