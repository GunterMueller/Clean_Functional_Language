#ifndef __CASYNCIO__
#define __CASYNCIO__

#include "hashtable.h"
#include "../Clean.h"

typedef struct io_data_s io_data_t;

// Functions called through Clean Foreign Function Interface.
int ioInitC();
int ioGetEventsC(int main_fd, int timeout, int doTimeout, int max_events, CleanIntArray p_fd_list, CleanIntArray p_ev_kinds);
void windowsAcceptC (int main_fd, int listen_fd, int *p_err_code, int *p_client_fd);
void acceptCAsyncIO (int main_fd, int listen_fd, int *p_err_code, int *p_client_fd);
void tcplistenC(int main_fd, int port, int *p_err_code, int *p_listen_fd);
void connectC (int main_fd, int ip_addr, int port, int *p_err_code, int *p_client_fd);
int queueWriteSockC(int main_fd, int fd, char *p_write_data, int size);
int signalWriteSockC(int main_fd, int fd);
int getpeernameC(int client_fd, int listen_fd, int *p_host);
void retrieveDataC(int main_fd, int fd, int *p_err_code, CleanString *p_received);
void windowsReadSockC(int fd, int *p_err_code);
int cleanupFdC(int main_fd, int fd, int isASocket);
int windowsIncPacketsToWriteC(int fd, int num_packets);
int anyPendingPacketsC(int fd, int* anyPackets);
#endif
