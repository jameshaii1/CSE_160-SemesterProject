#include "../../includes/packet.h"

configuration IPC{
    provides interface IP; 
}

implementation {
    components IPP; 
    components DistanceVectorC;  
    components TCPC;
    components new SimpleSendC(AM_PACK) as IPSender; 

    IP = IPP.IP; 
    IPP.DistanceVector -> DistanceVectorC; 
    IPP.Transport -> TCPC; 
    IPP.LinkSender -> IPSender; 
}