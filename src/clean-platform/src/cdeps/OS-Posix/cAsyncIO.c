#ifdef __APPLE__
#include <sys/event.h>
#else // Linux
#include <sys/epoll.h>
#include <sys/types.h>
#include <sys/socket.h>
#endif

#include <stdio.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>
#include "cAsyncIO.h"
#include "queue.h"
#include "hashtable.h"
#include "../Clean.h"

// Maximum number of file descriptors that will be monitored.
#define MAX_SUPPORTED_FDS 2500

// Events returned to Clean.
#define AcceptEventSock 0
#define ConnectEventSock 1
#define ReadEventSock 2
#define WriteEventSock 4
#define ReadAndWriteEventSock 6
#define DisconnectEventSock 8
#define WriteEventNop 10

CleanString rcv_buf;
int rcv_buf_size;
// Hashtable storing the data that is to be sent for every client/pipe.
hashtable_t* ht;

// Allocates receive buffer/HT once per execution of the program (does not need to be freed).
int ioInitC () {
	// Init rcv_buf_size.
	int s = socket(PF_INET, SOCK_STREAM, 0);
	socklen_t idc = sizeof(rcv_buf_size);
	getsockopt(s, SOL_SOCKET, SO_RCVBUF, (void*) &rcv_buf_size, &idc);
	close(s);

	// Initialize receive buffer, one receive buffer for all fds is sufficient.
	rcv_buf = (CleanString) malloc(rcv_buf_size + sizeof(long));
	if (rcv_buf == NULL) {
		return -1;
	}

	// Create hash table for writequeues.
	ht = initHT(MAX_SUPPORTED_FDS);
	if (ht == NULL) {
		return -1;
	}
	#ifdef __APPLE__
	// Creates kqueue fd.
	return kqueue();
	#else // Linux, create epoll fd.
	return epoll_create1(0);
	#endif
}

int fdToFdStr(int fd, char* fd_str_buf) {
	int err = sprintf(fd_str_buf, "%d", fd);
	if (err < 0) {
		printf("cAsyncIO.c, sprintf failed.\n");
		return -1;
	}
	return 0;
}

int ioMonitorFd (int main_fd, int fd) {
	char fd_str[9];
	int err = fdToFdStr(fd, fd_str);
	// io_data_t is retrieved and used by ioGetEventsC to determine which event should be returned to Clean.
	io_data_t* io_data = getHT(ht, fd_str)->io_data;
	if (io_data == NULL) {
		return -1;
	}

	int op = io_data->op;

	#ifdef __APPLE__
	struct kevent e;

	// Watch for readability.
	if (op == AcceptEventSock || op == ReadEventSock || op == ReadEventPipe) {
		EV_SET(&e, fd, EVFILT_READ, EV_ADD | EV_ENABLE, 0, 0, (void*) io_data);
	}
	else { // Watch for readability and writability (ReadAndWriteEvent)
		EV_SET(&e, fd, EVFILT_WRITE, EV_ADD | EV_ENABLE, 0, 0, (void*) io_data);
		kevent(main_fd, &e, 1, NULL, 0, NULL);
		EV_SET(&e, fd, EVFILT_READ, EV_ADD  | EV_ENABLE, 0, 0, (void*) io_data);
	}

	return kevent(main_fd, &e, 1, NULL, 0, NULL);

	#else // Linux
	struct epoll_event e;

	// Watch for readability.
	if (op == AcceptEventSock || op == ReadEventSock) {
		e.events = EPOLLIN | EPOLLERR | EPOLLHUP;
	} else { // Watch for readability and writability (ReadAndWriteEvent)
		e.events = EPOLLIN | EPOLLOUT | EPOLLERR | EPOLLHUP;
	}
	e.data.fd = fd;
	e.data.ptr = io_data;

	// Start monitoring file descriptor for events.
	if (epoll_ctl(main_fd, EPOLL_CTL_ADD, fd, &e)) {
		if (errno != EEXIST) {
			return -1;
		}

		// File descriptor already being monitored, modify event list.
		if (epoll_ctl(main_fd, EPOLL_CTL_MOD, fd, &e) == -1) {
			return -1;
		}
	}
	return 0;
	#endif
}

int modifyIOMonitorOp(int fd, int newOp) {
	char fd_str[9];
	fdToFdStr(fd,fd_str);
	table_entry_t* entry = getHT(ht,fd_str);
	if (entry == NULL) {
		return -1;
	}
	io_data_t* io_data = entry->io_data;
	io_data->op = newOp;
	return putHT(ht, entry->key, entry->queue, io_data);
}

// Frees packet and data contents after sending the packet over to the peer.
#ifdef __APPLE__
int ioGetEventsC (int main_fd, int timeout, int doTimeout, int max_events, CleanIntArray p_fd_list, CleanIntArray p_ev_kinds) {
	struct kevent events[MAX_SUPPORTED_FDS];
	int num_events;
	// Retrieve events.
	int num_events;
	if (doTimeout) {
		struct timespec time = {.tv_sec = timeout/1000, .tv_nsec = (timeout % 1000) * 1000000};
		num_events = kevent(main_fd, NULL, 0, events, max_events, &time);
	} else {
		num_events = kevent(main_fd, NULL, 0, events, max_events, NULL);
	}
	if(num_events == -1) {
		printf("ioGetEventsC: Error retrieving events.\n");
		return -1;
	}

	for (int i = 0; i < num_events; i++) {
		io_data_t* io_data = (io_data_t*) events[i].udata;
		p_fd_list[i] = io_data->fd;

		int read_ev, write_ev, disconnect_ev;
		// Monitoring pipe.
		if (io_data->op == ReadAndWriteEventPipe || io_data->op == ReadEventPipe) {
			read_ev = ReadEventPipe;
			write_ev = WriteEventPipe;
			disconnect_ev = DisconnectEventPipe;
		} else { // Monitoring socket.
			read_ev = ReadEventSock;
			write_ev = WriteEventSock;
			disconnect_ev = DisconnectEventSock;
		}

		if (events[i].flags & EV_ERROR){
			printf("ioGetEventsC: EV_ERROR %d.\n", errno);
			p_ev_kinds[i] = disconnect_ev;
			continue;
		}

		if (events[i].flags & EV_EOF){
			p_ev_kinds[i] = disconnect_ev;
			continue;
		}

		// If both read and write are monitored it is determined whether this event is a read or write event.
		// Unlike for epoll (Linux), it is not possible for a read and write event to be returned at the same time.
		if (io_data->op == ReadAndWriteEventSock || io_data->op == ReadAndWriteEventPipe) {
			if (events[i].filter == EVFILT_READ) {
				p_ev_kinds[i] = read_ev;
			} else {
				p_ev_kinds[i] = write_ev;
			}
		} else {
			p_ev_kinds[i] = io_data->op;
		}

		if(io_data->op == ConnectEventSock) {
			// Stop monitoring for writability.
			struct kevent e;
			EV_SET(&e, events[i].ident, EVFILT_WRITE, EV_DELETE, 0, 0, NULL);
			if (kevent(main_fd, &e, 1, NULL, 0, NULL) == -1) {
				return -1;
			}

			// Check if connection attempt succeeded.
			struct sockaddr_in addr;
			socklen_t addr_len = sizeof(addr);
			int err = getpeername(io_data->fd, (struct sockaddr*) &addr, &addr_len);
			if (err) {
				printf("Connection attempt for fd %d failed.", io_data->fd);
				continue;
			}
			// Monitor for readability after connecting.
			modifyIOMonitorOp(io_data->fd, ReadEventSock);
			ioMonitorFd(main_fd, io_data->fd);
		}

		// Write data if necessary.
		if ((io_data->op == ReadAndWriteEventSock || io_data->op == ReadAndWriteEventPipe)
			&& events[i].filter == EVFILT_WRITE) {
			// Retrieve write queue hashtable entry for fd.
			char fd_str[9];
			fdToFdStr(io_data->fd, fd_str);
			queue_t* write_queue = getHT(ht, fd_str)->queue;

			if (write_queue == NULL) {
				return -1;
			}

			// Writequeue was found, write data in writequeue.
			while (!isEmpty(write_queue)) {
				int total_bytes_sent = 0;
				packet_t* packet = dequeue(write_queue);
				while (total_bytes_sent < packet->size) {
					int bytes_sent = write(io_data->fd, packet->data+total_bytes_sent, packet->size-total_bytes_sent);
					if(bytes_sent == -1) {
						if (errno != EWOULDBLOCK && errno != EAGAIN) {
							printf("write failed, errno: %d\n", errno);
						}
						// Broken pipe (ungraceful disconnect by peer).
						if (errno == EPIPE || errno == ECONNRESET) {
							p_ev_kinds[i] = disconnect_ev;
							free(packet->data);
							free(packet);
							goto endWrite;
						} else if (errno == EWOULDBLOCK || errno == EAGAIN) {
							/* The fd remains monitored for writability but the write attempt is aborted
							 * until the fd is writable again.
							 * goto is used to easily break out of the writing loop
							 * as the writequeue might not be empty.
							 * The file descriptor remains monitored for writability.
							 * The data remaining in the packet that was not completely sent is requeued in front.
							 */
							int err
								= enqueueFront(write_queue, packet->data+total_bytes_sent, packet->size-total_bytes_sent);
							if (err) {
								return -1;
							}

							err = putHT(ht, fd_str, write_queue, io_data);
							if (err) {
								return -1;
							}

							p_ev_kinds[i] = WriteEventNop;
							free(packet->data);
							free(packet);
							goto endWrite;
						} else {
							return -1;
						}
					}
					total_bytes_sent += bytes_sent;
				}
				free(packet->data);
				free(packet);
			}
			// All data in the write queue has been sent.
			// Stop monitoring for writability (until there is data to be sent again).
			struct kevent e;
			EV_SET(&e, events[i].ident, EVFILT_WRITE, EV_DELETE, 0, 0, NULL);
			if(kevent(main_fd, &e, 1, NULL, 0, NULL) == -1) {
				return -1;
			}
			endWrite: ;
		}
	}
	return num_events;
}
// Frees packet and data contents after sending the packet over to the peer.
#else // Linux
int ioGetEventsC (int main_fd, int timeout, int doTimeout, int max_events, CleanIntArray p_fd_list, CleanIntArray p_ev_kinds) {
	struct epoll_event events[MAX_SUPPORTED_FDS];

	// Retrieve events.
	int num_events;
	if (doTimeout) {
		num_events = epoll_wait(main_fd, events, max_events, timeout);
	} else {
		num_events = epoll_wait(main_fd, events, max_events, -1);
	}

	if(num_events == -1) {
		printf("epoll_wait returned error: %d\n", errno);
		return -1;
	}

	for (int i = 0; i < num_events; i++) {
		io_data_t* io_data = (io_data_t*) events[i].data.ptr;
		p_fd_list[i] = io_data->fd;

		int read_ev, write_ev, read_and_write_ev, disconnect_ev;
		read_ev = ReadEventSock;
		write_ev = WriteEventSock;
		read_and_write_ev = ReadAndWriteEventSock;
		disconnect_ev = DisconnectEventSock;

		// If the fd is being monitored for readability and writability,
		// the specific event returned needs to be determined.
		if (io_data->op == ReadAndWriteEventSock) {
			// Socket was readable and writable, which indicates that data should be sent and read.
			if ((events[i].events & EPOLLIN) && (events[i].events & EPOLLOUT)) {
				p_ev_kinds[i] = read_and_write_ev;
			} else if (events[i].events & EPOLLIN) { // Readable.
				p_ev_kinds[i] = read_ev;
			} else { // Writable.
				p_ev_kinds[i] = write_ev;
			}
		} else {
			p_ev_kinds[i] = io_data->op;
		}

		if (events[i].events & EPOLLERR) {
			printf("EPOLLERR %d\n", errno);
			p_ev_kinds[i] = disconnect_ev;
			continue;
		}

		if (events[i].events & EPOLLHUP) {
			p_ev_kinds[i] = disconnect_ev;
			continue;
		}

		if (io_data->op == ConnectEventSock) {
			struct sockaddr_in addr;
			socklen_t addr_len = sizeof(addr);
			// Check if connection attempt succeeded.
			int err = getpeername(io_data->fd, (struct sockaddr*) &addr, &addr_len);
			if (err) {
				printf("Connection attempt for fd %d failed.", io_data->fd);
				continue;
			}

			// Monitor for readability after connecting.
			modifyIOMonitorOp(io_data->fd, ReadEventSock);
			ioMonitorFd(main_fd, io_data->fd);
		}

		// Write data if necessary.
		if ((io_data->op == ReadAndWriteEventSock) && (events[i].events & EPOLLOUT)) {
			// Retrieve write queue hashtable entry for fd.
			char fd_str[9];
			fdToFdStr(io_data->fd, fd_str);
			queue_t* write_queue = getHT(ht, fd_str)->queue;

			if (write_queue == NULL) {
				return -1;
			}

			// Writequeue was found, write data in writequeue.
			while (!isEmpty(write_queue)) {
				int total_bytes_sent = 0;
				packet_t* packet = dequeue(write_queue);
				while (total_bytes_sent < packet->size) {
					int bytes_sent = write(io_data->fd, packet->data+total_bytes_sent, packet->size-total_bytes_sent);
					if (bytes_sent == -1) {
						if (errno != EWOULDBLOCK && errno != EAGAIN) {
							printf("write failed, errno: %d\n", errno);
						}
						// Broken pipe (ungraceful disconnect by peer).
						if (errno == ECONNRESET || errno == EPIPE) {
							p_ev_kinds[i] = disconnect_ev;
							free(packet->data);
							free(packet);
							goto endWrite;
						} else if (errno == EWOULDBLOCK || errno == EAGAIN) {
							/* The fd remains monitored for writability but the write attempt is aborted
							 * until the fd is writable again.
							 * goto is used to easily break out of the writing loop as the writequeue
							 * might not be empty.
							 * Because of the location of endwrite, the file descriptor remains monitored for writability.
							 * The data remaining in the packet that was not completely sent is requeued in front.
							 */
							int err = enqueueFront(write_queue, packet->data+total_bytes_sent, packet->size-total_bytes_sent);
							if (err) {
								return -1;
							}

							err = putHT(ht, fd_str, write_queue, io_data);
							if (err) {
								return -1;
							}
							if ((events[i].events & EPOLLIN) && (events[i].events & EPOLLOUT)) {
								p_ev_kinds[i] = read_ev;
							} else {
								p_ev_kinds[i] = WriteEventNop;
							}
							free(packet->data);
							free(packet);
							goto endWrite;
						} else {
						    return -1;
                        }
					}
					total_bytes_sent += bytes_sent;
				}
				free(packet->data);
				free(packet);
			}

			// All data in the write queue has been sent.
			// Stop monitoring for writability (until there is data to be sent again).
			events[i].events = EPOLLIN | EPOLLERR | EPOLLHUP;
			if (epoll_ctl(main_fd, EPOLL_CTL_MOD, io_data->fd, &events[i])) {
				return -1;
			}
			endWrite: ;
		}
	}
	return num_events;
}
#endif

// Allocates memory for storing a hashtable entry, the entry and its contents should be freed.
int allocHashtableEntry(int fd, io_data_t* io_data) {
	char key[9];
	int err = fdToFdStr(fd, key);

	if (err) {
		return -1;
	}

	queue_t* queue = initQueue();
	if (queue == NULL) {
		return -1;
	}

	return putHT(ht, key, queue, io_data);
}

// Allocates a struct for storing the fd and I/O event (op) the fd is monitored for, should be freed.
io_data_t* initIOData(int fd, int op) {
	io_data_t* io_data = (io_data_t*) malloc(sizeof(io_data_t));
	if (io_data == NULL) {
		return NULL;
	}
	io_data->fd = fd;
	io_data->op = op;
	return io_data;
}

// Allocates memory for client, which should be freed.
void acceptCAsyncIO (int main_fd, int server, int *p_err_code, int *p_client_fd) {
	// Accept connection request.
	int client_fd = accept(server, (struct sockaddr*) 0, (int*) 0);
	if (client_fd == -1) {
		if (errno == EAGAIN || errno == EWOULDBLOCK || errno == ECONNABORTED || errno == EPROTO) {
			*p_err_code = -2;
			close(client_fd);
			return;
		} else {
			*p_err_code = -1;
			close(client_fd);
			return;
		}
	}

	// Set the client socket to be non-blocking.
	int flags = fcntl(client_fd, F_GETFL, 0);
	fcntl(client_fd, F_SETFL, flags | O_NONBLOCK);

	// Allocate a struct used for storing information on how the fd is monitored to ioGetEventsC
	io_data_t* io_data = initIOData(client_fd, ReadEventSock);
	if (io_data == NULL) {
		*p_err_code = -1;
		return;
	}

	/* Allocate a hashtable entry for the client, in which the data to be written is stored.
	 The data is read from a queue located in the hashtable enry by ioGetEventsC if the client socket is writable.*/
	int err = allocHashtableEntry(client_fd, io_data);
	if (err) {
		*p_err_code = -1;
		return;
	}

	// Monitor client socket for readability.
	*p_err_code = ioMonitorFd(main_fd, client_fd);
	*p_client_fd = client_fd;
}

// Allocates memory for listener, which should be freed.
void tcplistenC (int main_fd, int port, int *p_err_code, int *p_listen_fd)
{
	struct sockaddr_in srv_adr;
	*p_err_code = -1;

	// Create socket that listens on any available port/address.
	int listen_fd = socket (PF_INET, SOCK_STREAM, 0);
	if (listen_fd==-1) {
		return;
	}

	srv_adr.sin_family = AF_INET;
	srv_adr.sin_addr.s_addr = INADDR_ANY;
	srv_adr.sin_port = htons((short int)port);

	int so_reuseaddr = 1;
	*p_err_code = setsockopt (listen_fd, SOL_SOCKET, SO_REUSEADDR, &so_reuseaddr, sizeof so_reuseaddr);
	if (*p_err_code){
		close(listen_fd);
		return;
	}

	// Make listening socket non-blocking.
	*p_err_code = fcntl(listen_fd, F_SETFL, fcntl(listen_fd, F_GETFL, 0) | O_NONBLOCK);
	if (*p_err_code) {
		close(listen_fd);
		return;
	}

	*p_err_code = bind (listen_fd, (struct sockaddr*) &srv_adr, sizeof(srv_adr));
	if (*p_err_code){
		close(listen_fd);
		return;
	}

	*p_err_code = listen (listen_fd, 5);
	if (*p_err_code){
		close(listen_fd);
		return;
	}

	io_data_t* io_data = initIOData(listen_fd, AcceptEventSock);
	if (io_data == NULL) {
		close(listen_fd);
		return;
	}

	int err = allocHashtableEntry(listen_fd, io_data);
	if (err) {
		close(listen_fd);
		return;
	}

	// Monitor listen socket for connection requests.
	*p_err_code = ioMonitorFd(main_fd, listen_fd);
	*p_listen_fd = listen_fd;
}

// Allocates memory for client, which should be freed.
void connectC (int main_fd, int ip_addr, int port, int *p_err_code, int *p_client_fd)
{
	*p_err_code = -1;

	struct sockaddr_in srv_adr,client_adr;
	int client_fd = socket (PF_INET, SOCK_STREAM, 0);

	if (client_fd==-1) {
		return;
	}

	// Make client socket non-blocking.
	int err = fcntl(client_fd, F_SETFL, fcntl(client_fd, F_GETFL, 0) | O_NONBLOCK);
	if (err == -1) {
		return;
	}

	client_adr.sin_family = AF_INET;
	client_adr.sin_addr.s_addr = INADDR_ANY;
	client_adr.sin_port = 0;

	err = bind (client_fd, (struct sockaddr*) &client_adr, sizeof(client_adr));

	if (err){
		close (client_fd);
		return;
	}

	srv_adr.sin_family = AF_INET;
	srv_adr.sin_addr.s_addr = htonl (ip_addr);
	srv_adr.sin_port = htons ((short int)port);
	err = connect (client_fd, (struct sockaddr*) &srv_adr, sizeof(srv_adr));
	if (err && !(errno==EINPROGRESS)){
		close (client_fd);
		return;
	}

	// Allocate a struct used for storing information on how the fd is monitored to ioGetEventsC
	io_data_t* io_data = initIOData(client_fd, ConnectEventSock);
	if (io_data == NULL) {
		return;
	}

	/* Allocate a hashtable entry for the client, in which the data to be written is stored.
	 The data is read from a queue located in the hashtable enry by ioGetEventsC if the client socket is writable.*/
	err = allocHashtableEntry(client_fd, io_data);
	if (err) {
		return;
	}

	// Monitor socket for writability to return event indicating successful connection attempt.
	*p_err_code = ioMonitorFd(main_fd, client_fd);
	*p_client_fd = client_fd;
}

/* Add data to write queue, which is emptied when data is sent in ioGetEventsC.
   Allocates buffer for copying data passed on by Clean which should be freed.
   Allocates packet for storing the data along with the size, which should be freed.
   The data is copied because otherwise Clean might garbage collect the data, corrupting it.*/
int queueWriteSockC(int main_fd, int fd, char* p_write_data_clean, int size) {
	char key[9];
	int err = fdToFdStr(fd, key);
	if (err) {
		return -1;
	}
	table_entry_t* entry = getHT(ht,key);
	queue_t* queue = entry->queue;
	if (queue == NULL) {
		return -1;
	}

	char* p_write_data = (char*)malloc(size);
	memcpy(p_write_data, p_write_data_clean, size);
	err = enqueue(queue, p_write_data, size);
	if (err) {
		return -1;
	}
	return putHT(ht, key, queue, entry->io_data);
}

int signalWriteSockC(int main_fd, int fd) {
	int err = modifyIOMonitorOp(fd, ReadAndWriteEventSock);
	if (err) {
		return -1;
	}
	return ioMonitorFd(main_fd, fd);
}

int getpeernameC(int client_fd, int listen_fd, int* p_host) {
	struct sockaddr_in addr;
	socklen_t addr_len = sizeof(addr);
	int err = getpeername(client_fd, (struct sockaddr*) &addr, &addr_len);
	if(!err) {
		*p_host = ntohl(addr.sin_addr.s_addr);
	}
	return err;
}

void retrieveDataC(int main_fd, int fd, int *p_err_code, CleanString *p_received) {
	int bytes_received = read(fd, CleanStringCharacters(rcv_buf), rcv_buf_size);
	// Data was received.
	if (bytes_received > 0) {
		CleanStringLength(rcv_buf) = bytes_received;
		*p_received = rcv_buf;
		*p_err_code = 1;
		return;
	}
	// Graceful peer disconnect.
	if (bytes_received == 0) {
		CleanStringLength(rcv_buf) = 0;
		*p_received = rcv_buf;
		*p_err_code = 0;
		return;
	}
	CleanStringLength(rcv_buf) = 0;
	*p_received = rcv_buf;
	if (errno == 5) {
		*p_err_code = 0;
		return;
	}
	*p_err_code = -1;
}

// Frees memory of client/listener for which the connection is cleaned up.
int cleanupFdC(int main_fd, int fd, int isASocket) {
	char key[9];
	int err = fdToFdStr(fd,key);
	if (err) {
		return -1;
	}
	err = removeHT(ht, key);
	if (err) {
		return -1;
	}

	#ifdef __APPLE__
	struct kevent e;
	EV_SET(&e, fd, EVFILT_READ, EV_DELETE, 0, 0, NULL);
	if(kevent(main_fd, &e, 1, NULL, 0, NULL) == -1) {
		return -1;
	}
	#else // Linux
	if (epoll_ctl(main_fd, EPOLL_CTL_DEL, fd, NULL)) {
		return -1;
	}
	#endif

	return close(fd);
}

int anyPendingPacketsC (int fd, int* anyPackets) {
	char fd_str[9];
	fdToFdStr(fd,fd_str);
	queue_t* queue = getHT(ht, fd_str)->queue;
	*anyPackets = !isEmpty(queue);
	return 0;
}
