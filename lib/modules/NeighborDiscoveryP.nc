#include "../../includes/packet.h"


module NeighborDiscoveryP{
    provides interface NeighborDiscovery;
    uses interface AMPacket; 
    uses interface Timer<TMilli> as neighborTimer;
    uses interface Timer<TMilli> as offsetTimer;
    uses interface SimpleSend as neighborSender;
    uses interface Hashmap<uint16_t> as neighborTable;

    uses interface Random;



}

//the neighbor discovery table isn't being updated, it just sends whether or not at the time the radio starts
//if nodes are neighbors, needs to be constantly updated, even if a node dies 
//test s.moteoff(3); 


implementation {
    uint16_t totalSent = 0;

    command void NeighborDiscovery.findNeighbor(){
        call offsetTimer.startOneShot(call Random.rand16() % 333);
    //    dbg(NEIGHBOR_CHANNEL, "STARTING TIMER\n");
    }

    event void offsetTimer.fired(){
        call neighborTimer.startPeriodic(750);
        dbg(NEIGHBOR_CHANNEL, "REFIRING NEIGHBOR DISCOVERY")
    }

    event void neighborTimer.fired(){

        //creating neighbor packet after timer is started
        pack neighborPack; 
        neighborPack.src = TOS_NODE_ID; 
        neighborPack.dest = AM_BROADCAST_ADDR; 
        neighborPack.TTL = 1; 
        neighborPack.seq = 0; 
        neighborPack.protocol = PROTOCOL_NEIGHBOR;

        //broadcast to neighbors
        totalSent++;
      //  dbg(NEIGHBOR_CHANNEL, "PACKETS SENT: %hu \n", totalSent);
        call neighborSender.send(neighborPack, AM_BROADCAST_ADDR);

        //check to see if it replied back

    }
    
//why initialize the neighbor packet here? 
//link quality, could be apart of this table and if link quality < threshhold
//then remove from the table

    command void NeighborDiscovery.reply(pack neighborPing){
        pack replyPack; 
        replyPack.src = TOS_NODE_ID; 
        replyPack.dest = neighborPing.src; 
        replyPack.TTL = 1; 
        replyPack.protocol = PROTOCOL_PINGREPLY; 
        replyPack.seq = 0;

        call neighborSender.send(replyPack, replyPack.dest);
    }

    command void NeighborDiscovery.addNeighbor(pack neighborResponse){
        uint16_t replyCount = 0; //neighbor replies  

        if (call neighborTable.contains(neighborResponse.src)){
            replyCount = call neighborTable.get(neighborResponse.src);
            call neighborTable.insert(neighborResponse.src, replyCount + 1);
        } else{
            call neighborTable.insert(neighborResponse.src, 1);
        }

    }

    command void NeighborDiscovery.printNeighbors(){
        uint32_t* keys = call neighborTable.getKeys();
        uint16_t size = call neighborTable.size();
        uint16_t i;
        uint16_t count;
        uint16_t linkQuality;

        dbg(NEIGHBOR_CHANNEL, "Neighbors: %hu\n", size);
        for (i = 0; i < size; i++){
            count = call neighborTable.get(keys[i]);
            if (totalSent > 0){
                linkQuality = ((count * 100) / totalSent);
            }
            dbg(NEIGHBOR_CHANNEL, "Neighbor: %lu   Link Quality: %hu%% \n", keys[i], linkQuality);
        }
    }

}
