/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/protocol.h"
#include "includes/socket.h"


module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;

   uses interface NeighborDiscovery; 
   uses interface Flooding; 
   uses interface DistanceVector; 
   uses interface IP; 
   uses interface Transport; 
}

implementation{
   pack sendPackage;
   socket_t clientFd;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void Boot.booted(){
      call AMControl.start();

      dbg(GENERAL_CHANNEL, "Booted\n");
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
        call NeighborDiscovery.findNeighbor();
        call DistanceVector.createTopo();
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      //dbg(GENERAL_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         if (myMsg -> protocol == PROTOCOL_FLOOD){
            if (call Flooding.flood(*myMsg) == SUCCESS){
            dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
            }
         }
         if (myMsg -> protocol == PROTOCOL_NEIGHBOR){
               call NeighborDiscovery.reply(*myMsg);
            }
         if (myMsg -> protocol == PROTOCOL_NEIGHBOR_PINGREPLY){
            call NeighborDiscovery.addNeighbor(*myMsg);
         }
         if (myMsg -> protocol == PROTOCOL_DV){

            call DistanceVector.receive(msg, myMsg);
         }
         if (myMsg -> protocol == PROTOCOL_PING || myMsg -> protocol == PROTOCOL_PINGREPLY){
            call IP.receive(myMsg);
         }
         if (myMsg -> protocol == PROTOCOL_TCP){
            call IP.receive(myMsg);
         }
         return msg;
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_PING, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
      call IP.send(sendPackage);
   }

   event void CommandHandler.printNeighbors(){
      call NeighborDiscovery.printNeighbors();
   }

   event void CommandHandler.printRouteTable(){
      call DistanceVector.print();
   }
   event void CommandHandler.flood(uint16_t destination, uint8_t *payload){
      makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_PING, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
      call Flooding.flood(sendPackage);

   }

   event void CommandHandler.findNeighbor(){}

   event void CommandHandler.printLinkState(){
      
   }

   event void CommandHandler.printDistanceVector(){
      call DistanceVector.print();
   }

   event void CommandHandler.setTestServer(){
      socket_t fd = call Transport.socket();
      socket_addr_t addr;

      if (fd == NO_SOCKET) {
      dbg(TRANSPORT_CHANNEL, "socket out of range\n");
      return;
      }
      addr.port = 1; //test
      addr.addr = TOS_NODE_ID;
      if (call Transport.bind(fd, &addr) == FAIL){
      dbg(TRANSPORT_CHANNEL, "failed\n");
      return;
      } else {
         dbg(TRANSPORT_CHANNEL, "%hu bounded to %hu\n",fd, addr.port);
      }
      
      if (call Transport.listen(fd) == FAIL){
      dbg(TRANSPORT_CHANNEL, "failed\n");
      return;
      }
      else {dbg(TRANSPORT_CHANNEL, "server: listening on port: %hu, fd %hu\n",addr.port,fd);
      }
   }



   event void CommandHandler.setTestClient(){
      socket_addr_t addr;
      socket_addr_t addrServer;
      clientFd = call Transport.socket();

      addrServer.port = 1; 
      addrServer.addr = 3; 

      addr.port = 2; //test
      addr.addr = TOS_NODE_ID;


      if (clientFd == NO_SOCKET) {
      dbg(TRANSPORT_CHANNEL, "socket out of range\n");
      return;
      }

      if (call Transport.bind(clientFd, &addr) == FAIL){
      dbg(TRANSPORT_CHANNEL, "failed\n");
      return;
      } else {
         dbg(TRANSPORT_CHANNEL, "%hu bounded to %hu\n",clientFd, addr.port);
      }

      if (call Transport.connect(clientFd, &addrServer) == FAIL){
         dbg(TRANSPORT_CHANNEL,"FAILED\n");
         return;
      } else{
         dbg(TRANSPORT_CHANNEL,"SYN_SENT\n");
      }
   }

   event void CommandHandler.setTestClose(){
      call Transport.close(clientFd);

   }
   event void CommandHandler.setTestWrite(){
      uint16_t i;
      uint8_t array[10];
      uint32_t n; 
      for (i = 0; i < 10; i++){
         array[i]= i;
      }
      n = call Transport.write(clientFd, array,10);
      dbg(TRANSPORT_CHANNEL, "write returned %lu\n", n);
   }

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}
