#ifndef __CASYNCIO__
#define __CASYNCIO__

#include "hashtable.h"
#include "../Clean.h"

typedef struct io_data_s io_data_t;

// Functions called through the Clean Foreign Function Interface.
// Allocates memory for receive buffer and hashtable once per program execution, does not require to be freed.
int ioInitC();
// Frees memory for packet after sending packet.
int ioGetEventsC(int main_fd, int timeout, int doTimeout, int max_events, CleanIntArray p_fd_list, CleanIntArray p_ev_kinds);
void acceptCAsyncIO (int main_fd, int listen_fd, int *p_err_code, int *p_client_fd);
// Allocates memory for listener, should be freed.
void tcplistenC(int main_fd, int port, int *p_err_code, int *p_listen_fd);
// Allocates memory for client, should be freed.
void connectC (int main_fd, int ip_addr, int port, int *p_err_code, int *p_client_fd);
// Allocates memory for packet, should be freed.
int queueWriteSockC(int main_fd, int fd, char *p_write_data, int size);
int signalWriteSockC(int main_fd, int fd);
int getpeernameC(int client_fd, int listen_fd, int *p_host);
void retrieveDataC(int main_fd, int fd, int *p_err_code, CleanString *p_received);
// Frees memory for client/listener.
int cleanupFdC(int main_fd, int fd, int isASocket);
int anyPendingPacketsC (int fd, int* anyPackets);
#endif
