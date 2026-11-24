#include "../../includes/packet.h"

//the place to declare the functions 

interface NeighborDiscovery{
  command void findNeighbor();

  //gets info on the sender's source and destination
  command void reply(pack reply); 

  command void addNeighbor(pack neighborResponse);

  command void printNeighbors();

  command bool isNeighbor(uint16_t id);
}
