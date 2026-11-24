#ifndef TCP_H
#define TCP_H

#include "packet.h"


typedef nx_struct tcp_t{
    nx_uint8_t src_port;
    nx_uint8_t dest_port; 
    nx_uint8_t Tflags; //only 3 bits used SYN, ACK, FIN
    nx_uint16_t seq; 
    nx_uint16_t ack; 
    nx_uint8_t TCPwindow; 
    nx_uint8_t length; 
}tcp_t;


enum{
    TCP_SYN = 0x01,
    TCP_ACK = 0x02,
    //SYN + ACK 0x03
    TCP_FIN = 0x04,
    TCP_HEADER_SIZE = 9, //9 bytes
    ISN = 0,
    TIMEOUT = 200,
    MAX_RETRY = 5, 
    DATA_CAPACITY = PACKET_MAX_PAYLOAD_SIZE - TCP_HEADER_SIZE
};
#endif