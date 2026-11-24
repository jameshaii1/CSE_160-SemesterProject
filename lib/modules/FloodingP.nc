/*
Notes:
Send a packet to a neighbor, if the node doesn't have it, send it to their neighbor
and record that you've recieved that packet. If you get the packet again
do nothing
*/
//important src and seq
//cache the message or the flooding packet? 

#include "../../includes/packet.h"
//Flooding sends everywhere but if i want to sent
//6-13 instead of 1-13, it floods backwards to 1
//isn't that the ideal behavior? 

//I think it's a consequence of using broadcast 

module FloodingP{
  provides interface Flooding;
  uses interface SimpleSend as FloodSender;

  uses interface Hashmap<uint32_t> as SeenCache; 


}
implementation {
    //use the pack's TTL variable instead of assigning a new one
    command error_t Flooding.flood(pack floodpack){
      // 32 bit integer  ( src | seq ) 
      uint32_t tablekey;

      //check if we've exhausted TTL 
      if (floodpack.TTL == 0){
        dbg(FLOODING_CHANNEL, "TTL EXHAUSTED\n");
        return FAIL; 
      }

      // create this node's table key
      tablekey = ((uint32_t)floodpack.src << 16) + floodpack.seq;

      //check if current node is already in the table
      if (call SeenCache.contains(tablekey)){
        dbg(FLOODING_CHANNEL, "KEY FOUND IN CACHE\n");
        return FAIL;
      }
  
      dbg(FLOODING_CHANNEL, "RECEIVED FLOOD PACK FROM: Node %hu\n", floodpack.src);
      dbg(FLOODING_CHANNEL, "SENDING TO: Node %hu \n", floodpack.dest);
      //add to the cache
      call SeenCache.insert(tablekey,1);
//  dbg(FLOODING_CHANNEL, "Adding to cache: %lu\n", tablekey);


      //decrement TTL after a successful cache
      floodpack.TTL--; 
      dbg(FLOODING_CHANNEL, "REMAINING TTL %hu \n", floodpack.TTL);

      //send to our neighbors
      if (call FloodSender.send(floodpack, AM_BROADCAST_ADDR) == SUCCESS){
        dbg(FLOODING_CHANNEL, "Broadcasting locally\n");
      } else {
        dbg(FLOODING_CHANNEL, "SEND FAILED from Node %hu\n", TOS_NODE_ID);
      }
      return SUCCESS;
    }
    
}
