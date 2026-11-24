#include "../../includes/packet.h"


interface DistanceVector{
    command void createTopo(); 
    command void receive(message_t* msg, pack* advertisement);
    command void send(uint16_t neighbor);
    command uint16_t nextHop(uint16_t dest);
    command uint8_t cost(uint16_t dest);
    command void print();
}