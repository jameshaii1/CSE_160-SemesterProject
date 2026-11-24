//neighbor discovery
//after nd we have. a table 
//use this table to find the shortest path to each using djikstra

#define infinity 16
#define maxNodes 255 

#include "../../includes/packet.h"

module DistanceVectorP{
    provides interface DistanceVector; 

    uses interface NeighborDiscovery;
    uses interface Timer<TMilli> as DVTimer;
    uses interface Timer<TMilli> as offsetTimer;
    uses interface SimpleSend as DVSender;
    uses interface AMPacket;


    uses interface Random;

}

implementation{
    //neighbor table
    uint32_t nodes;
    uint16_t i; 
    uint8_t j,k, /*current node's*/neighbors[maxNodes], neighborCounter;

    enum { ROUTE_UNUSED = 0, ROUTE_UNKNOWN = 11, ROUTE_VALID = 111 };

        typedef struct {
            uint8_t nextHop, cost, state; uint32_t lastHeard, withdrawStart; } Route; 
        Route routes[maxNodes + 1];



    void markUnreachable(uint16_t d){
        if (routes[d].state != ROUTE_VALID)return; 

            routes[d].cost = infinity; 
            routes[d].state = ROUTE_UNKNOWN; 
            routes[d].withdrawStart = call DVTimer.getNow();
    }
    command void DistanceVector.createTopo(){
        //distance vector table
        for (i = 0; i <= maxNodes; i++){
            routes[i].cost = infinity;
            routes[i].state = ROUTE_UNUSED;
            routes[i].nextHop = 0; 
            routes[i].lastHeard = 0; 
            routes[i].withdrawStart = 0; 
        }

        routes[TOS_NODE_ID].cost = 0;
        routes[TOS_NODE_ID].nextHop = TOS_NODE_ID;
        routes[TOS_NODE_ID].state = ROUTE_VALID;
        routes[TOS_NODE_ID].lastHeard = call DVTimer.getNow();

        call offsetTimer.startOneShot(call Random.rand16() % 1000);
    }

    event void offsetTimer.fired(){
       call DVTimer.startPeriodic(3000);
    }


    event void DVTimer.fired(){
        uint32_t now = call DVTimer.getNow();
        bool neighborCheck; 

        //neighbor 1,2..N for this nodebased on nodeID
        neighborCounter = 0; 
        for (i = 1; i <= maxNodes ; i++){
            //Check if next node is a neighbor
            if (i == TOS_NODE_ID) continue; 
            neighborCheck = call NeighborDiscovery.isNeighbor(i);
            if (neighborCheck){
                routes[i].cost = 1; //all are neighbors so the cost to get to someone is 1
                routes[i].nextHop = i;
                routes[i].state = ROUTE_VALID;
                routes[i].lastHeard = now;
                neighbors[neighborCounter] = i;
                neighborCounter++;
            }
            else if (routes[i].state == ROUTE_VALID){
                if (!call NeighborDiscovery.isNeighbor(routes[i].nextHop)){
                    markUnreachable(i);
                }
                else if (now - routes[i].lastHeard > 18000){
                    markUnreachable(i);
                }
            } else if(routes[i].state == ROUTE_UNKNOWN){
                if (now - routes[i].withdrawStart > 12000){
                    routes[i].state = ROUTE_UNUSED; 
                    routes[i].cost = infinity; 
                    routes[i].nextHop = 0; 
                }
            }
        
        }
        //then we send our neighbors our neighbor table. 
        for(j = 0; j < neighborCounter; j++){
            call DistanceVector.send(neighbors[j]);
            //dbg(NEIGHBOR_CHANNEL, "neighbors of %hu: %hu\n", TOS_NODE_ID, neighbors[j]);
            
        }
    }

    command void DistanceVector.send(uint16_t neighbor){
        //we turn our neighbor table into a ad packet
        pack ad; 
        uint8_t key = 0 /*The dest,cost pair of each node*/,  
        maxPairs = 10, //the packet payload mover so 1 byte is dest, 1 byte is cost 
        cost; 

        //reset the packet contents to 0 for clean slate
        memset(&ad, 0, sizeof(pack));
        ad.src = TOS_NODE_ID; 
        ad.dest = neighbor; 
        ad.TTL = 1;  
        ad.protocol = PROTOCOL_DV; 

        
        for (i = 0; i <= maxNodes; i++){
            //validity check
            if (routes[i].state == ROUTE_UNUSED) continue; 

            if (routes[i].state == ROUTE_UNKNOWN){
                cost = infinity; 
            }
            else{            
                cost = routes[i].cost;
                //if the next hop is my neighbor, but i isn't me 
                if (routes[i].nextHop == neighbor && i != TOS_NODE_ID){
                    cost = infinity; 
                }
            }

            //20 bytes to use, I send first byte dest, second byte how much it costs
            //dest
            ad.payload[2* key] = i; 
            //cost
            ad.payload[2* key + 1] = cost; 
            //next payload
            key++;

            //after we've reached the end of the payload
            //send it off and wipe the slate clean for the next ad
            if (key == maxPairs) { 
                call DVSender.send(ad, neighbor);
                memset(&ad.payload, 0, sizeof(ad.payload));
                key = 0;
            }
        }
        if (key > 0){
            //keep going until we reach packet capacity
            call DVSender.send(ad, neighbor);
        }


    }

    command void DistanceVector.receive(message_t* msg, pack* ad){
        //received from shows that this is our neighbor
        uint16_t neighbor = call AMPacket.source(msg);
        uint8_t key, dest, cost, candidate, maxPairs = 10;


        //confirm neighborcheck
        if (call NeighborDiscovery.isNeighbor(neighbor)){

            //check the pairs
            for (key = 0; key <maxPairs; key++){
                dest = ad->payload[2 * key];

                if (dest == 0) break;
                cost = ad->payload[2*key+1];
                if (cost > infinity) continue; 
                if (dest == TOS_NODE_ID) continue; 

                candidate = (cost >= infinity) ? infinity : cost + 1; 
                //if this possible route is more efficient, update the routing table

                if (candidate < infinity){

                    switch(routes[dest].state ){
                        case ROUTE_UNUSED:
                        case ROUTE_UNKNOWN : 
                            routes[dest].cost = candidate; 
                            routes[dest].nextHop = neighbor; 
                            routes[dest].state = ROUTE_VALID; 
                            routes[dest].lastHeard = call DVTimer.getNow();
                            break;

                        case ROUTE_VALID : 
                        if (candidate < routes[dest].cost){
                            routes[dest].cost = candidate; 
                            routes[dest].nextHop = neighbor;
                            routes[dest].state = ROUTE_VALID; 
                            routes[dest].lastHeard = call DVTimer.getNow();
                        } 
                        else if (routes[dest].nextHop == neighbor){
                            routes[dest].cost = candidate;
                            routes[dest].lastHeard = call DVTimer.getNow();
                        }
                            break; 
                    } 
                } else{
                        if (routes[dest].state == ROUTE_VALID && routes[dest].nextHop == neighbor){
                            markUnreachable(dest);
                        } 
                    }
            }
        }

    }
 
    command uint16_t DistanceVector.nextHop(uint16_t dest){
        if (dest == 0 || dest > maxNodes) return 0;     

        if (routes[dest].state == ROUTE_VALID)
        return routes[dest].nextHop;
        else {
            return 0; 
        }
    }
    command uint8_t DistanceVector.cost(uint16_t dest){
        if (dest == 0 || dest > maxNodes) return infinity;     
        if (routes[dest].state == ROUTE_VALID)
        return routes[dest].cost;
        else {
            return infinity; 
        }
    }
    
    command void DistanceVector.print(){
        uint16_t d;
        dbg(ROUTING_CHANNEL, "Routing table of %hu (dest|nextHop|cost)\n", TOS_NODE_ID);
        for (d = 1; d <= maxNodes; d++){
            if (routes[d].state == ROUTE_UNUSED)continue; 
            if (routes[d].state == ROUTE_VALID){
            dbg(ROUTING_CHANNEL, "%hu %hhu %hhu VALID\n", d, routes[d].nextHop, routes[d].cost);
            }
            else{   
                dbg(ROUTING_CHANNEL, "%hu - INF UNREACHABLE\n", d);
            }

        }
    }
}
