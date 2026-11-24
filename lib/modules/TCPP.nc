#include "../../includes/tcp.h"
#include "../../includes/socket.h"

module TCPP {
    provides interface Transport;

    uses interface IP; 
    uses interface Timer<TMilli> as TCPTimer; 
    uses interface Boot; 
}


implementation {
    socket_store_t sockets[MAX_NUM_OF_SOCKETS];
    uint16_t seq_counter = 0; 

    error_t tcpBuilder(socket_t fd, uint8_t flag, uint16_t seq,uint16_t ack){
        tcp_t tcp; 
        pack tcpPack; 
        tcp.Tflags = flag; 
            tcp.src_port = sockets[fd].src; 
            tcp.dest_port = sockets[fd].dest.port; 
            tcp.seq = seq; 
            tcp.ack = ack;
            tcp.TCPwindow = 128; 
            tcp.length = 0; 
        
        memset(&tcpPack, 0, sizeof(tcpPack));
            tcpPack.src = TOS_NODE_ID;
            tcpPack.dest = sockets[fd].dest.addr; 
            tcpPack.seq = seq_counter; 
            tcpPack.TTL = MAX_TTL; 
            tcpPack.protocol = PROTOCOL_TCP; 
            memcpy(tcpPack.payload,&tcp,sizeof(tcp));
        seq_counter++; 
        call IP.send(tcpPack);

        return SUCCESS; 
    }
    error_t tcpBuilderTEMP(socket_t fd, uint8_t flag, uint16_t seq,uint16_t ack, uint8_t* buff, uint8_t bufflen){
        tcp_t tcp; 
        pack tcpPack; 
        tcp.Tflags = flag; 

        if (bufflen > DATA_CAPACITY) return FAIL; 
            tcp.src_port = sockets[fd].src; 
            tcp.dest_port = sockets[fd].dest.port; 
            tcp.seq = seq; 
            tcp.ack = ack;
            tcp.TCPwindow = 128; 
            tcp.length = bufflen; 
        
        memset(&tcpPack, 0, sizeof(tcpPack));
            tcpPack.src = TOS_NODE_ID;
            tcpPack.dest = sockets[fd].dest.addr; 
            tcpPack.seq = seq_counter; 
            tcpPack.TTL = MAX_TTL; 
            tcpPack.protocol = PROTOCOL_TCP; 
            memcpy(tcpPack.payload,&tcp,sizeof(tcp));
            if (bufflen > 0){
            memcpy(tcpPack.payload+TCP_HEADER_SIZE,buff,bufflen);
            }
        seq_counter++; 
        call IP.send(tcpPack);

        return SUCCESS; 
    }
    void closeHelper(socket_t fd, uint8_t nextState){
        tcpBuilder(fd, TCP_FIN | TCP_ACK, sockets[fd].nextSend, sockets[fd].nextExpect);
        sockets[fd].state = nextState;
        sockets[fd].retry = 0;
        sockets[fd].timeStamp = call TCPTimer.getNow(); 
        sockets[fd].nextSend++; 
    }
    
    socket_t claimSocket(){
        uint16_t i; //loop variable
        for (i = 0; i < MAX_NUM_OF_SOCKETS; i++){
            if (sockets[i].flag == FREE){ //free
                sockets[i].state = CLOSED; 
                sockets[i].flag = IN_USE; 

                sockets[i].src = 0; 
                //sender
                sockets[i].dest.port = 0;
                sockets[i].dest.addr = 0; 
                //receiver
                sockets[i].lastWritten = 0;
                sockets[i].lastAck = 0;
                sockets[i].lastSent = 0;

                sockets[i].lastRead = 0;
                sockets[i].lastRcvd = 0;
                sockets[i].nextExpected = 0;
                sockets[i].RTT = 0; 
                sockets[i].effectiveWindow = 128; 
                sockets[i].oldUnack = 0;
                sockets[i].nextSend = 0;
                sockets[i].nextExpect = 0; 
                sockets[i].timeStamp = 0;
                sockets[i].retry = 0;
                return i;
            } 
        }
        return NO_SOCKET; 
    }


    command socket_t Transport.socket(){
        return claimSocket();
        
    }

    command error_t Transport.bind(socket_t fd, socket_addr_t *addr){
        uint16_t i; //loop variable

        if (fd >= MAX_NUM_OF_SOCKETS) return FAIL; 
        if (addr == NULL) return FAIL; 
        if (sockets[fd].flag != IN_USE || sockets[fd].state != CLOSED) return FAIL; 

        for (i = 0; i < MAX_NUM_OF_SOCKETS; i++){
            if (i != fd && sockets[i].flag == IN_USE){
                if (sockets[i].src == addr->port){
                    return FAIL; 
                }
            }
        }
        sockets[fd].src = addr->port;
        return SUCCESS; 
    }
    
    command socket_t Transport.accept(socket_t fd){
        return NO_SOCKET;
    }

    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen){
        uint16_t n; 
        if (fd >= MAX_NUM_OF_SOCKETS || sockets[fd].flag != IN_USE || sockets[fd].state != ESTABLISHED) return 0;
        if (sockets[fd].oldUnack != sockets[fd].nextSend) return 0; 
        if (bufflen > DATA_CAPACITY){
            n = DATA_CAPACITY;
        } else{
            n = bufflen;
        }
        memcpy(sockets[fd].sendBuff, buff, n);
        tcpBuilderTEMP(fd, TCP_ACK, sockets[fd].nextSend, sockets[fd].nextExpect, sockets[fd].sendBuff, n );
        dbg(TRANSPORT_CHANNEL, "fd %d sent %d bytes seq %d\n", fd, n, sockets[fd].nextSend);
        sockets[fd].nextSend += n;
        sockets[fd].timeStamp = call TCPTimer.getNow();
        sockets[fd].retry = 0; 

        return n;
    }

    command error_t Transport.receive(pack* package){
        uint16_t i;
        tcp_t header;
        socket_t fd = NO_SOCKET; 
        socket_t fdC;

        memcpy(&header,package->payload, sizeof(tcp_t));

        for(i =0; i < MAX_NUM_OF_SOCKETS; i++){
            if(sockets[i].flag == IN_USE && 
            sockets[i].src  == header.dest_port &&
            sockets[i].dest.port == header.src_port&&
            sockets[i].dest.addr == package->src){
                fd = i;
                break; 
            }
        }
        if (fd == NO_SOCKET && header.Tflags == TCP_SYN){
            for (i = 0; i < MAX_NUM_OF_SOCKETS; i++){
                if(sockets[i].flag == IN_USE &&
                sockets[i].state == LISTEN &&
                sockets[i].src == header.dest_port){
                    fd = i; 
                    break;
                }
            }
        }
        if (fd == NO_SOCKET){
        dbg(TRANSPORT_CHANNEL, "no socket for port %d from node %d port %d, flags 0x%x, dropped\n",
    header.dest_port, package->src, header.src_port, header.Tflags);

            return FAIL; 
        }

        switch (sockets[fd].state){
        default: 
        break;

        case LISTEN: //SYN
        fdC = claimSocket();
        if (fdC >= MAX_NUM_OF_SOCKETS || fdC == NO_SOCKET){
            dbg(TRANSPORT_CHANNEL, "LISTEN: no free socket, dropping SYN from node %d\n", package->src);
            break;
        }

        sockets[fdC].src = sockets[fd].src;
        sockets[fdC].dest.port = header.src_port;
        sockets[fdC].dest.addr = package->src;
        sockets[fdC].nextExpect = header.seq + 1; 
        sockets[fdC].oldUnack = ISN;
        sockets[fdC].nextSend = ISN + 1; 
        sockets[fdC].state = SYN_RCVD;
        sockets[fdC].timeStamp = call TCPTimer.getNow();
        tcpBuilder(fdC, TCP_SYN | TCP_ACK, ISN, sockets[fdC].nextExpect);
        dbg(TRANSPORT_CHANNEL, "LISTEN -> SYN_RCVD: fd %d, from node %d port %d, sent SYN+ACK seq %d ack %d\n",
    fdC, package->src, header.src_port, ISN, sockets[fdC].nextExpect);
    
        break;

        case SYN_SENT: //SYN ACK
        if(header.Tflags == (TCP_SYN | TCP_ACK) &&
        header.ack == sockets[fd].nextSend){
            sockets[fd].nextExpect = header.seq + 1; 
            sockets[fd].oldUnack = header.ack;
            tcpBuilder(fd, TCP_ACK, sockets[fd].nextSend,sockets[fd].nextExpect);
            sockets[fd].state = ESTABLISHED;
            dbg(TRANSPORT_CHANNEL, "SYN_SENT -> ESTABLISHED: fd %d, sent ACK seq %d ack %d\n",
    fd, sockets[fd].nextSend, sockets[fd].nextExpect);

        }
        break;

        case SYN_RCVD: //syn ack sent, got the received, just establish
        if(header.Tflags & TCP_ACK &&
            header.ack == sockets[fd].nextSend){
            sockets[fd].oldUnack = header.ack;
            sockets[fd].state = ESTABLISHED;
            dbg(TRANSPORT_CHANNEL, "SYN_RCVD -> ESTABLISHED: fd %d, got ACK %d\n", fd, header.ack);
        }  break;

        case ESTABLISHED: 
        if ((header.Tflags & TCP_ACK) && header.ack == sockets[fd].nextSend && sockets[fd].oldUnack!= sockets[fd].nextSend){
            sockets[fd].oldUnack = header.ack;
            dbg(TRANSPORT_CHANNEL, "fd %d data acked, ack %d\n", fd, header.ack);
        }
        if (header.length > 0 && header.length <= DATA_CAPACITY){
            if (header.seq == sockets[fd].nextExpect){
                memcpy(sockets[fd].rcvdBuff, package->payload + TCP_HEADER_SIZE,header.length);
                sockets[fd].nextExpect += header.length;
                tcpBuilder(fd, TCP_ACK, sockets[fd].nextSend, sockets[fd].nextExpect );
                dbg(TRANSPORT_CHANNEL, "fd %d received %d bytes seq %d, first byte %d, sent ACK ack %d\n",
    fd, header.length, header.seq, sockets[fd].rcvdBuff[0], sockets[fd].nextExpect);
            }

         else if (header.seq < sockets[fd].nextExpect){
            tcpBuilder(fd, TCP_ACK, sockets[fd].nextSend, sockets[fd].nextExpect );
            dbg(TRANSPORT_CHANNEL, "fd %d duplicate seq %d, re-sent ACK ack %d\n",
    fd, header.seq, sockets[fd].nextExpect);
            }
        }

        if((header.Tflags & TCP_FIN) && header.seq == sockets[fd].nextExpect){
            sockets[fd].nextExpect = header.seq + 1; 
            tcpBuilder(fd,TCP_ACK, sockets[fd].nextSend,sockets[fd].nextExpect);
            sockets[fd].state = CLOSE_WAIT;
            dbg(TRANSPORT_CHANNEL, "ESTABLISHED -> CLOSE_WAIT: fd %d, got FIN seq %d, sent ACK ack %d\n",
    fd, header.seq, sockets[fd].nextExpect);
            closeHelper(fd, LAST_ACK);
            dbg(TRANSPORT_CHANNEL, "CLOSE_WAIT -> LAST_ACK: fd %d, sent FIN seq %d\n",
    fd, sockets[fd].nextSend - 1);
        }
        break;

        case FIN_WAIT_1:
        if ((header.Tflags & TCP_ACK) && header.ack == sockets[fd].nextSend ){
            sockets[fd].oldUnack = header.ack;
            sockets[fd].state = FIN_WAIT_2;
            dbg(TRANSPORT_CHANNEL, "FIN_WAIT_1 -> FIN_WAIT_2: fd %d, got ACK %d\n", fd, header.ack);
        }

        break;

        case FIN_WAIT_2:
        if (header.Tflags & TCP_FIN && header.seq == sockets[fd].nextExpect){
            sockets[fd].nextExpect = header.seq + 1; 
            tcpBuilder(fd, TCP_ACK, sockets[fd].nextSend, sockets[fd].nextExpect);
            sockets[fd].state = TIME_WAIT;
            sockets[fd].timeStamp = call TCPTimer.getNow();
            dbg(TRANSPORT_CHANNEL, "FIN_WAIT_2 -> TIME_WAIT: fd %d, got FIN seq %d, sent ACK ack %d\n",
    fd, header.seq, sockets[fd].nextExpect);
        }

        break;

        case LAST_ACK:
        if ((header.Tflags & TCP_ACK) && header.ack == sockets[fd].nextSend ){
        sockets[fd].flag = FREE;
        sockets[fd].state = CLOSED;
        dbg(TRANSPORT_CHANNEL, "LAST_ACK -> CLOSED: fd %d, got ACK %d\n", fd, header.ack);
        }
        break;


        case TIME_WAIT:
        if (header.Tflags & TCP_FIN){
            tcpBuilder(fd, TCP_ACK,sockets[fd].nextSend, sockets[fd].nextExpect);
            sockets[fd].timeStamp = call TCPTimer.getNow();
            dbg(TRANSPORT_CHANNEL, "TIME_WAIT: fd %d, repeated FIN seq %d, re-sent ACK ack %d\n",
    fd, header.seq, sockets[fd].nextExpect);
        }
        break;

        }
        
        return SUCCESS; 
    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen){
        return 0; 
    }


    //connect this fd to that addr
    command error_t Transport.connect(socket_t fd, socket_addr_t *addr){

        if (fd >= MAX_NUM_OF_SOCKETS || 
        sockets[fd].state != CLOSED ||
        sockets[fd].src == 0 ||
        sockets[fd].flag != IN_USE ||
        addr == NULL) return FAIL;  

        sockets[fd].dest = *addr;
        sockets[fd].oldUnack = ISN; 
        sockets[fd].nextSend = ISN + 1; 

        tcpBuilder(fd, TCP_SYN, ISN, 0);

        sockets[fd].state = SYN_SENT;
        sockets[fd].timeStamp = call TCPTimer.getNow();
        sockets[fd].retry = 0; 

        return SUCCESS; 
    }


    command error_t Transport.close(socket_t fd){
        if (fd >= MAX_NUM_OF_SOCKETS || sockets[fd].flag != IN_USE) return FAIL;

        switch (sockets[fd].state){
        default: return FAIL;

        case ESTABLISHED:
        closeHelper(fd, FIN_WAIT_1);
        dbg(TRANSPORT_CHANNEL, "ESTABLISHED -> FIN_WAIT_1: fd %d, sent FIN seq %d ack %d\n",
    fd, sockets[fd].nextSend - 1, sockets[fd].nextExpect);
        break;
         case CLOSE_WAIT:
        closeHelper(fd, LAST_ACK);
        dbg(TRANSPORT_CHANNEL, "CLOSE_WAIT -> LAST_ACK: fd %d, sent FIN seq %d ack %d\n",
    fd, sockets[fd].nextSend - 1, sockets[fd].nextExpect);
        break;

        case LISTEN:
        case SYN_SENT:
        dbg(TRANSPORT_CHANNEL, "close: fd %d state %d -> CLOSED, no connection to tear down\n",
    fd, sockets[fd].state);
        sockets[fd].flag = FREE;
        sockets[fd].state = CLOSED;
        }
        return SUCCESS; 
    }

    

    //optional
    command error_t Transport.release(socket_t fd){
        return FAIL; 
    }

    command error_t Transport.listen(socket_t fd){
        if (fd >= MAX_NUM_OF_SOCKETS) return FAIL; 
        if (sockets[fd].state != CLOSED) return FAIL;  
        if (sockets[fd].flag != IN_USE) return FAIL; 
        if (sockets[fd].src == 0 ) return FAIL; 
        sockets[fd].state = LISTEN; 
        return  SUCCESS; 
    }

    //timeout
    event void TCPTimer.fired(){
    uint16_t i; //loop variable
    uint32_t now = call TCPTimer.getNow();


        for (i = 0; i < MAX_NUM_OF_SOCKETS; i++){

            if (sockets[i].flag == IN_USE && sockets[i].state == TIME_WAIT &&   now - sockets[i].timeStamp > 3000){
                sockets[i].flag = FREE;
                sockets[i].state = CLOSED;
                dbg(TRANSPORT_CHANNEL, "TIME_WAIT -> CLOSED: fd %d, timer expired\n", i);
            }
        }
    }

    event void Boot.booted(){
    uint16_t i; //loop variable

        call TCPTimer.startPeriodic(3000);

        for (i = 0; i < MAX_NUM_OF_SOCKETS; i++){
            sockets[i].flag = FREE; 
            sockets[i].state = CLOSED; 
            sockets[i].src = 0; 
            //sender
            sockets[i].dest.port = 0;
            sockets[i].dest.addr = 0; 
            //receiver
            sockets[i].lastWritten = 0;
            sockets[i].lastAck = 0;
            sockets[i].lastSent = 0;

            sockets[i].lastRead = 0;
            sockets[i].lastRcvd = 0;
            sockets[i].nextExpected = 0;
            sockets[i].RTT = 0; 
            sockets[i].effectiveWindow = 128; 
        }
    }
}