#include "../../includes/packet.h"

configuration DistanceVectorC{
    provides interface DistanceVector; 
}

implementation{

   components DistanceVectorP; 
   components NeighborDiscoveryC; 
   components new TimerMilliC() as DVTimer; 
   components new TimerMilliC() as offsetTimer;
   components RandomC as Random;
   components new SimpleSendC(AM_PACK) as DVSender;
   components ActiveMessageC;


   DistanceVector = DistanceVectorP.DistanceVector;


   DistanceVectorP.NeighborDiscovery -> NeighborDiscoveryC; 
   DistanceVectorP.DVTimer -> DVTimer;
   DistanceVectorP.offsetTimer -> offsetTimer;
   DistanceVectorP.DVSender -> DVSender;
   DistanceVectorP.AMPacket -> ActiveMessageC;
   DistanceVectorP.Random -> Random;

}