#include "../../includes/packet.h"

configuration FloodingC{
    provides interface Flooding; 
}

implementation{
    components FloodingP;
    components new SimpleSendC(AM_PACK) as FloodSender;
    components new HashmapC(uint32_t, 60) as SeenCache; 

    Flooding = FloodingP.Flooding; 

    FloodingP.FloodSender -> FloodSender; 
    FloodingP.SeenCache -> SeenCache; 


}