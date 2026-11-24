#include "../../includes/packet.h"
#include "../../includes/channels.h"


module IPP{
    provides interface IP;

    uses interface DistanceVector; 
    uses interface Transport; 
    uses interface SimpleSend as LinkSender;
}


implementation{

    error_t forward(pack msg){
        uint16_t hop = call DistanceVector.nextHop(msg.dest);
        error_t fwdpack; 
        if (hop == 0){
        dbg(ROUTING_CHANNEL, "no useable route\n");
        return FAIL; 
        }

        dbg(ROUTING_CHANNEL, "Routing Packet - src: %hu, dest: %hu, seq: %hu , next hop : %hu, cost : %hu\n", msg.src, msg.dest, msg.seq, hop, call DistanceVector.cost(msg.dest));
        fwdpack = call LinkSender.send(msg, hop);
        return fwdpack; 
    }

    command error_t IP.send(pack msg){
       // size = memcpy(msg.dest, msg.payload, )
        return forward(msg);
    }

    void deliver(pack* msg){
        pack reply; 
        if (msg->protocol == PROTOCOL_PING){
                dbg(ROUTING_CHANNEL, "PING FROM %hu, seq: %hu, payload: %s\n", msg->src, msg->seq, msg->payload);
                memset(&reply, 0, sizeof(pack));

                reply.src = TOS_NODE_ID; 
                reply.dest = msg->src; 
                reply.TTL = MAX_TTL; 
                reply.protocol = PROTOCOL_PINGREPLY;
                reply.seq = msg->seq;
                memcpy(reply.payload, msg->payload, PACKET_MAX_PAYLOAD_SIZE);
                forward(reply);
            }
            else if (msg->protocol == PROTOCOL_PINGREPLY){
                dbg(ROUTING_CHANNEL, "REPLY FROM %hu, seq: %hu, payload: %s\n", msg->src, msg->seq, msg->payload);
            }
            else if (msg->protocol == PROTOCOL_TCP){
                call Transport.receive(msg);
            }
        }


    command void IP.receive(pack* msg){
        pack copy; 
        if (msg->dest == TOS_NODE_ID){
            if (msg->TTL > 0){
                dbg(ROUTING_CHANNEL, "PACKET ARRIVED\n");
                deliver(msg);
            }
            else{
                dbg(ROUTING_CHANNEL, "DROPPING PACKET\n");
            }
        }
        else {
            if (msg->TTL <= 1){
                dbg(ROUTING_CHANNEL, "DROPPING PACKET\n");
                return;
            }
            copy = *msg; 
            copy.TTL--; 
            forward(copy);
        }
        
    }    
}
