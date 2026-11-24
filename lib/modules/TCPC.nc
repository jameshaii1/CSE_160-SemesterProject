#include "../../includes/tcp.h"


configuration TCPC {
    provides interface Transport; 
}

implementation{
    components TCPP; 
    components IPC;
    components MainC; 
    components new TimerMilliC() as TCPTimer; 



    Transport = TCPP.Transport;
    TCPP.IP ->IPC; 
    TCPP.TCPTimer -> TCPTimer; 
    TCPP -> MainC.Boot;
}