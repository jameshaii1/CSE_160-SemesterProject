#include "../../includes/packet.h"

#define window 5

module NeighborDiscoveryP{
    provides interface NeighborDiscovery;
    uses interface AMPacket; 
    uses interface Timer<TMilli> as neighborTimer;
    uses interface Timer<TMilli> as offsetTimer;
    uses interface SimpleSend as neighborSender;
    uses interface Hashmap<uint16_t> as neighborTable;
    uses interface Hashmap<uint16_t> as linkQualityTable; 

    uses interface Random;



}

//the neighbor discovery table isn't being updated, it just sends whether or not at the time the radio starts
//if nodes are neighbors, needs to be constantly updated, even if a node dies 
//test s.moteoff(3); 


implementation {


    uint16_t seqCounter = 0;
    uint16_t stw = 0; //sent this window



    command void NeighborDiscovery.findNeighbor(){
        call offsetTimer.startOneShot(call Random.rand16() % 333);
    //    dbg(NEIGHBOR_CHANNEL, "STARTING TIMER\n");
    }

    event void offsetTimer.fired(){
        call neighborTimer.startPeriodic(750);
        dbg(NEIGHBOR_CHANNEL, "REFIRING NEIGHBOR DISCOVERY \n");

    }

    event void neighborTimer.fired(){
        uint16_t  linkQuality = 0, replyCount = 0; 
        uint32_t keysCopy[60], i, id, size; 
        uint32_t* pointer; 

        //creating neighbor packet after timer is started
        pack neighborPack; 

        neighborPack.src = TOS_NODE_ID; 
        neighborPack.dest = AM_BROADCAST_ADDR; 
        neighborPack.TTL = 1; 
        neighborPack.protocol = PROTOCOL_NEIGHBOR;


        if (stw == window){
            //when the window is full, you calculate the link quality
            size = call neighborTable.size();
            pointer = call neighborTable.getKeys();
            for (i = 0; i < size; i++){
                keysCopy[i] = pointer[i];
            }

            for (i = 0; i < size; i++){
                id = keysCopy[i];
                replyCount = call neighborTable.get(id);

                linkQuality = (replyCount * 100) / window; 
                call linkQualityTable.insert(id, linkQuality);

                if (replyCount == 0){
                   call neighborTable.remove(id);
                   call linkQualityTable.remove(id);
                }
                else{
                   call neighborTable.insert(id, 0);
                }
            }
        stw = 0; 
        }
        seqCounter++; 
        stw++; 
        neighborPack.seq = seqCounter; 


      //  dbg(NEIGHBOR_CHANNEL, "PACKETS SENT: %hu \n", totalSent);
        call neighborSender.send(neighborPack, AM_BROADCAST_ADDR);
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
        replyPack.seq = neighborPing.seq;

        call neighborSender.send(replyPack, replyPack.dest);
    }

    command void NeighborDiscovery.addNeighbor(pack neighborResponse){
        uint16_t replyCount = 0; 

        if (neighborResponse.seq == seqCounter){            
            if (call neighborTable.contains(neighborResponse.src)){
                replyCount = call neighborTable.get(neighborResponse.src);
                call neighborTable.insert(neighborResponse.src, (replyCount + 1));
            } else{
                call neighborTable.insert(neighborResponse.src, 1);
            } 
        }
        else {
            dbg(NEIGHBOR_CHANNEL, "packet failed reply src=%hu replyseq=%hu mySeq=%hu\n", neighborResponse.src, neighborResponse.seq, seqCounter);
        }
    }

    command void NeighborDiscovery.printNeighbors(){
        uint32_t* keys = call neighborTable.getKeys();
        uint16_t size = call neighborTable.size();
        uint16_t quality ;
        uint16_t i;

        dbg(NEIGHBOR_CHANNEL, "Neighbors: %hu\n", size);
        for (i = 0; i < size; i++){
            if (call linkQualityTable.contains(keys[i])){
                quality = call linkQualityTable.get(keys[i]);
                dbg(NEIGHBOR_CHANNEL, "Node: %lu   Link Quality: %hu%%\n", keys[i], quality);
            } else {
                dbg(NEIGHBOR_CHANNEL, "Node: %lu   Link Quality: n/a (new)\n", keys[i]);
            }
        }
        
    }

}
