#include "../../includes/packet.h"


configuration NeighborDiscoveryC{
    provides interface NeighborDiscovery; 
}

implementation{
    //gathers the implementation from the module
    components NeighborDiscoveryP; 
    components new TimerMilliC() as neighborTimer;
    components new TimerMilliC() as offsetTimer;
    components RandomC as Random;  
    components new SimpleSendC(AM_PACK) as neighborSender; 
    components new HashmapC(uint16_t, 60) as neighborTable; 
    components new HashmapC(uint16_t, 60) as linkQualityTable; 



    NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery; 

    


    NeighborDiscoveryP.neighborTimer -> neighborTimer; 
    NeighborDiscoveryP.neighborSender -> neighborSender; 
    NeighborDiscoveryP.neighborTable -> neighborTable;
    NeighborDiscoveryP.linkQualityTable -> linkQualityTable; 
    NeighborDiscoveryP.offsetTimer -> offsetTimer; 
    NeighborDiscoveryP.Random -> Random;
}
