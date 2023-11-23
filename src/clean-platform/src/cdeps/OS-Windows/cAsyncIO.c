#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <mswsock.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <windows.h>
#include <handleapi.h>
#include <stdio.h>
#include <io.h>
#include <fcntl.h>
#include <processthreadsapi.h>
#include <errhandlingapi.h>
#include <fileapi.h>
#include <winbase.h>
#include "cAsyncIO.h"
#include "hashtable.h"
#include "Basetsd.h"
#include "../Clean.h"
#pragma comment(lib, "ws2_32.lib")

// Maximum number of file descriptors that will be monitored by the I/O multiplexing mechanism.
#define MAX_SUPPORTED_FDS 2500

// Events returned to Clean.
#define AcceptEventSock 0
#define ConnectEventSock 1
#define ReadEventSock 2
#define WriteEventSock 4
#define ReadAndWriteEventSock 6
#define DisconnectEventSock 8
#define WriteEventNopSock 10

int rcv_buf_size;
hashtable_t* ht;
DWORD bytes_received;
DWORD idc;

typedef struct io_data_s {
	SOCKET fd;
	int op;
	char* data_buffer;
	// Used for storing IP addr.
	char buffer[2 * (sizeof(SOCKADDR_IN) + 16)];
	// Overlapped is a field to allow io_data_t to be retrieved in ioGetEventsC through the overlapped struct
	// This is done using the CONTAINING_RECORD function.
	OVERLAPPED overlapped;
} io_data_t;

int fdToFdStr(int fd, char* p_fd_str) {
	int err = sprintf(p_fd_str, "%d", fd);
	if (err < 0) {
		return -1;
	}
	return 0;
}

int ioInitC() {
	// Request winsock2.2.
	WSADATA wsaData;
	int err = WSAStartup(MAKEWORD(2,2), &wsaData);

	if (err) {
		return -1;
	}

	// Init rcv_buf_size.
	int s;
	s = socket (PF_INET, SOCK_STREAM, 0);
	int size = sizeof(rcv_buf_size);
	getsockopt (s, SOL_SOCKET, SO_RCVBUF,  (char*) &rcv_buf_size, &size);
	closesocket(s);

	// Init hashtable for storing write/receivebuffers.
	ht = initHT(2500);

	HANDLE iocp = CreateIoCompletionPort(INVALID_HANDLE_VALUE,NULL,0,0);
	if (iocp == NULL) {
		return -1;
	}
	return PtrToInt(iocp);
}

int ioMonitorFd (int main_fd, int fd, int op) {
	HANDLE iocp = CreateIoCompletionPort((HANDLE) IntToPtr(fd), (HANDLE) IntToPtr(main_fd), fd, 1);
	if(iocp == NULL) {
		fprintf(stderr, "Error: ioMonitorFd failed.\n");
		return -1;
	}
	return 0;
}

/* Frees data related to I/O operation.
 * Frees buffer for storing data after data was sent.
 */
int ioGetEventsC (int main_fd, int timeout, int doTimeout, int max_events, CleanIntArray pFdList, CleanIntArray pEvKinds) {
	ULONG numEvents;
	int size = CleanIntArraySize(pFdList);
	OVERLAPPED_ENTRY ovls [100];
	if (max_events > 100) {
		max_events = 100;
	}
	BOOL success;
	if (doTimeout) {
		success = GetQueuedCompletionStatusEx((HANDLE) IntToPtr(main_fd), (LPOVERLAPPED_ENTRY) ovls, size, &numEvents, (DWORD) 2000, (BOOL) FALSE);
	} else {
		success = GetQueuedCompletionStatusEx((HANDLE) IntToPtr(main_fd), (LPOVERLAPPED_ENTRY) ovls, size, &numEvents, (DWORD) 2000, (BOOL) FALSE);
	}
	if(success) {
		for (int i = 0; i < numEvents; i++) {
			// Retrieve io_data_t struct from OVERLAPPED struct passed to async operation (acceptEx, ...).
			io_data_t* io_data = (io_data_t*) CONTAINING_RECORD(ovls[i].lpOverlapped, io_data_t, overlapped);
			pFdList[i] = io_data->fd;
			pEvKinds[i] = io_data->op;

			int disconnect_ev = DisconnectEventSock;

			if (io_data->op == WriteEventSock)  {
				char key[5];
				int err = fdToFdStr(io_data->fd, key);
				if (err) {
					fprintf(stderr, "Error: fdToFdStr failed.\n");
					continue;
				}
				table_entry_t* entry = getHT(ht, key);
				if (entry == NULL) {
					fprintf(stderr, "Error: getHT failed.\n");
					continue;
				}
				if (entry->packets_to_write <= 0) {
					fprintf(stderr, "Error: packets to write negative.\n");
					continue;
				}

				entry->packets_to_write--;

				if (entry->packets_to_write != 0) {
					pEvKinds[i] = WriteEventNopSock;
				}
				free(io_data->data_buffer);
			}

			// If WSARecv()/ReadFile completed, the length of the CleanString receive buffer passed back to Clean
			// upon the next call to retrieveDataC
			// equals the amount of bytes transferred. 0 bytes having been transferred indicates a disconnect.
			// This is done because the parameter given to WSARecv/ReadFile may return incorrect results.
			// See: https://docs.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-wsarecv (Sockets)
			if (io_data->op == ReadEventSock) {

				// Graceful disconnect.
				if(ovls[i].dwNumberOfBytesTransferred == 0) {
					pEvKinds[i] = disconnect_ev;
					free(io_data);
					continue;
				}

				char key[5];
				int err = fdToFdStr(io_data->fd, key);
				if (err) {
					fprintf(stderr, "Error: fdToFdStr failed!\n");
					pEvKinds[i] = disconnect_ev;
					continue;
				}
				table_entry_t* entry = getHT(ht, key);
				if (entry == NULL) {
					fprintf(stderr, "Error: Entry is null failed\n");
					pEvKinds[i] = disconnect_ev;
					continue;
				}

				CleanStringLength(entry->rcv_buf_clean) = ovls[i].dwNumberOfBytesTransferred;
			}
			free(io_data);
		}
		return numEvents;
	}
	else {
		if (GetLastError() != WAIT_TIMEOUT) {
			fprintf(stderr, "Error retrieving I/O events.\n");
			return -1;
		}
		return 0;
	}
}

// Allocates memory for storing fd and op (I/O event which the fd is monitored for), should be freed.
io_data_t* initIOData(int fd, int op, char* data_buffer) {
	io_data_t *io_data = (io_data_t*) calloc(1, sizeof(io_data_t));
	if (io_data == NULL) {
		return NULL;
	}
	io_data->fd = fd;
	io_data->op = op;
	io_data->data_buffer = data_buffer;
	memset(&io_data->overlapped, 0, sizeof(OVERLAPPED));
	return io_data;
}

// Allocates memory for client, which should be freed.
int allocHashtableEntry(int client_fd) {
	char key[5];
	int err = fdToFdStr(client_fd, key);
	if (err) {
		return -1;
	}

	// Allocate hashtable entry.
	table_entry_t *entry = (table_entry_t*) calloc(1, sizeof(table_entry_t)+129);
	if (entry == NULL) {
		return -1;
	}

	// Allocate receive buffer.
	entry->rcv_buf_clean = (CleanString) calloc(1, rcv_buf_size + sizeof(long));
	if (entry->rcv_buf_clean == NULL) {
		return -1;
	}
	CleanStringLength(entry->rcv_buf_clean) = rcv_buf_size;

	entry->packets_to_write = 0;

	return putHT(ht, key, entry);
}

/* Allocates memory for client, which should be freed.
 * Allocates memory for I/O operation, which should be freed.
 */
void acceptCAsyncIO (int main_fd, int listen_fd, int *p_err_code, int *p_client_fd) {
	//Function pointer for AcceptEx() function.
	LPFN_ACCEPTEX acceptEx = NULL;
	GUID guid_acceptex = WSAID_ACCEPTEX;

	SOCKET client_fd = INVALID_SOCKET;

	// Load AcceptEx function into memory (this is the recommended way to use the AcceptEx function).
	int err = WSAIoctl(
			(SOCKET) listen_fd,
			SIO_GET_EXTENSION_FUNCTION_POINTER,
			&guid_acceptex,
			sizeof(guid_acceptex),
			&acceptEx,
			sizeof(acceptEx),
			&idc,
			NULL,
			NULL
			);

	if (err == SOCKET_ERROR) {
		*p_err_code = -1;
		return;
	}

	// Create socket.
	client_fd = WSASocket(AF_INET, SOCK_STREAM, 0, NULL, 0, WSA_FLAG_OVERLAPPED);
	if (client_fd == INVALID_SOCKET) {
		*p_err_code = -1;
		return;
	}
	*p_client_fd = (int) client_fd;

	// Initialize buffers and add the buffers to a hashtable which holds the buffers of the client socket.
	err = allocHashtableEntry((int) client_fd);
	if (err) {
		*p_err_code = -1;
		return;
	}

	// Information passed to ioGetEventsC which retrieves/uses io_data_t once the connection is accepted.
	io_data_t *io_data = initIOData(listen_fd, AcceptEventSock, NULL);
	if (io_data == NULL)  {
		*p_err_code = -1;
		return;
	}

	BOOL ok = acceptEx(
				(SOCKET) listen_fd,
				(SOCKET) client_fd,
				(PVOID) io_data->buffer,
				0,
				sizeof(SOCKADDR_IN) + 16,
				sizeof(SOCKADDR_IN) + 16,
				&idc,
				&(io_data->overlapped)
			  );
	if (WSAGetLastError() != WSA_IO_PENDING && !ok) {
		fprintf(stderr, "Error: AcceptEx failed %d.\n", WSAGetLastError());
		*p_err_code = -1;
		return;
	}
	err = ioMonitorFd(main_fd, client_fd, 0);
	if (err) {
		*p_err_code = -1;
		return;
	}
	*p_err_code = 1;
}

void windowsAcceptC (int main_fd, int listen_fd, int *p_err_code, int *p_client_fd) {
	acceptCAsyncIO(main_fd, listen_fd, p_err_code, p_client_fd);
}

void tcplistenC(int main_fd, int port, int *p_err_code, int *p_listen_fd) {
	SOCKET      listen_fd;
	SOCKADDR_IN srv_adr;

	listen_fd = WSASocket(AF_INET, SOCK_STREAM, 0, NULL, 0, WSA_FLAG_OVERLAPPED);
	if (listen_fd==INVALID_SOCKET)
		return;

	srv_adr.sin_family = AF_INET;
	srv_adr.sin_addr.s_addr = INADDR_ANY;
	srv_adr.sin_port = htons((short int)port);

	*p_err_code = bind(listen_fd, (LPSOCKADDR) &srv_adr, sizeof(srv_adr));
	if (*p_err_code) {
		closesocket(listen_fd);
		return;
	};

	*p_err_code = listen (listen_fd,128);
	if (*p_err_code) {
		closesocket(listen_fd);
		return;
	};

	*p_err_code = ioMonitorFd(main_fd, listen_fd, 0);
	if (*p_err_code) {
		closesocket(listen_fd);
		return;
	}

	*p_listen_fd = (int) listen_fd;
}

// Allocates memory for client, which should be freed.
// Allocates memory for I/O operation, which should be freed.
void connectC (int main_fd, int ip_addr, int port, int *p_err_code, int *p_client_fd) {
	SOCKET client_fd;
	SOCKADDR_IN srv_adr,client_adr;
	memset(&srv_adr, 0, sizeof(SOCKADDR_IN));
	memset(&client_adr, 0, sizeof(SOCKADDR_IN));

	*p_err_code = -1;

	client_fd = WSASocket(AF_INET, SOCK_STREAM, 0, NULL, 0, WSA_FLAG_OVERLAPPED);
	if (client_fd==INVALID_SOCKET)
		return;

	client_adr.sin_family = AF_INET;
	client_adr.sin_addr.s_addr = INADDR_ANY;
	client_adr.sin_port = 0;

	int err = bind(client_fd, (LPSOCKADDR) &client_adr, sizeof(client_adr));
	if (err){
		closesocket(client_fd);
		return;
	}

	srv_adr.sin_family = AF_INET;
	srv_adr.sin_addr.s_addr = htonl(ip_addr);
	srv_adr.sin_port = htons((short int)port);

	LPFN_CONNECTEX connectEx = NULL;
	GUID guid_connectex = WSAID_CONNECTEX;

	DWORD idc;

	// Load ConnectEx function into memory (this is the recommended way to use the ConnectEx function).
	err = WSAIoctl(
			(SOCKET) client_fd,
			SIO_GET_EXTENSION_FUNCTION_POINTER,
			&guid_connectex,
			sizeof(guid_connectex),
			&connectEx,
			sizeof(connectEx),
			&idc,
			NULL,
			NULL
			);

	if (err == SOCKET_ERROR) {
		*p_err_code = -1;
		return;
	}

	// Information passed to ioGetEventsC which retrieves the completion packet once the connection is accepted.
	io_data_t *io_data = initIOData(client_fd, ConnectEventSock, NULL);
	if(io_data == NULL) {
		*p_err_code = -1;
		return;
	}

	err = ioMonitorFd(main_fd, client_fd, 0);
	if (err) {
		*p_err_code = -1;
		return;
	}

	BOOL ok = connectEx(client_fd, (SOCKADDR*) &srv_adr, sizeof(srv_adr), NULL, 0, NULL, &(io_data->overlapped));

	if (!ok && WSAGetLastError() != WSA_IO_PENDING) {
		*p_err_code = -1;
		return;
	}
	err = allocHashtableEntry((int) client_fd);
	if (err) {
		*p_err_code = -1;
		return;
	}
	*p_client_fd = (int) client_fd;
	*p_err_code = 0;
}


// Initiates asynchronous Send operation on Windows, writing the data.
// Allocates memory for I/O operation, which should be freed.
// Allocates buffer for storing data to be sent, which should be freed.
// p_write_data is not used directly as a buffer since it might be cleaned up by the Clean garbage collector.
int queueWriteSockC(int main_fd, int fd, char* p_write_data, int size) {
	char key[5];
	int err = fdToFdStr(fd, key);
	if (err) {
		return -1;
	}

	char* data_buffer = (char*)calloc(1, size);
	memcpy(data_buffer, p_write_data, size);

	io_data_t *io_data = initIOData(fd, WriteEventSock, data_buffer);
	if (io_data == NULL) {
		return -1;
	}

	// WSABUF may be stack allocated, it is copied by WSASend, the buffer itself may not.
	WSABUF write_buf;
	write_buf.buf = io_data->data_buffer;
	write_buf.len = size;

	DWORD sendBytes = 0;

	if (SOCKET_ERROR == WSASend((SOCKET) fd, &write_buf, 1, &sendBytes, 0, NULL, NULL)) {
		if(WSAGetLastError() != WSA_IO_PENDING) {
			return -1;
		}
	}
	PostQueuedCompletionStatus((HANDLE) IntToPtr(main_fd), sendBytes, fd, &(io_data->overlapped));
	return 0;
}

// Should do nothing on Windows.
int signalWriteSockC(int main_fd, int fd) {
	return 0;
}

int getpeernameC(int client_fd, int listen_fd, int* p_host) {
	SOCKADDR_IN addr = {0};
	int addr_len = sizeof(addr);
	SOCKET listen_sock = (SOCKET) listen_fd;
	// This option has to be set before being able to retrieve the address using getpeername.
	// See https://docs.microsoft.com/en-us/windows/win32/api/mswsock/nf-mswsock-acceptex
	int err
		= setsockopt((SOCKET) client_fd, SOL_SOCKET, SO_UPDATE_ACCEPT_CONTEXT, (char*) &listen_sock, sizeof(listen_sock));
	if(err == SOCKET_ERROR) {
		return -1;
	}

	if (SOCKET_ERROR == getpeername((SOCKET) client_fd, (SOCKADDR*) &addr, &addr_len)) {
		return -1;
	}
	*p_host = ntohl(addr.sin_addr.s_addr);
	return err;
}

void retrieveDataC(int main_fd, int fd, int *p_err_code, CleanString *p_received) {
	*p_err_code = -1;
	char key[5];
	int err = fdToFdStr(fd, key);
	if (err) {
		return;
	}

	table_entry_t* entry = getHT(ht, key);
	if (entry == NULL) {
		return;
	}

	// Return buffer from previous windowsReadSockC call.
	// Clean makes a copy of this String on the heap once this function returns.
	// The length of the buffer gets set to the correct number of bytes through ioGetEventsC.
	// This is done using the amount of bytes transferred when the read operation completes.
	*p_received = entry->rcv_buf_clean;
	*p_err_code = 1;

}

// Initiates asynchronous read operation.
// Allocates memory for I/O operation which should be freed.
void windowsReadSockC(int fd, int *p_err_code) {
	char key[5];
	int err = fdToFdStr(fd, key);
	if (err) {
		fprintf(stderr, "Error: fdToFdStr failed \n.");
		*p_err_code = -1;
		return;
	}

	table_entry_t* entry = getHT(ht, key);
	if (entry == NULL) {
		fprintf(stderr, "Error: getHT failed \n.");
		*p_err_code = -1;
		return;
	}

	// This buffer will be overwritten with the data that is received through the next WSARecv call.
	// WSABUF rcv_buf may be stack allocated,
	// the buffer contained within rcv_buf (entry->rcv_buf_clean) must live until completion.
	WSABUF rcv_buf;
	rcv_buf.buf = CleanStringCharacters(entry->rcv_buf_clean);
	rcv_buf.len = rcv_buf_size;

	io_data_t *io_data = initIOData(fd, ReadEventSock, NULL);
	if(io_data == NULL) {
		*p_err_code = -1;
		return;
	}

	DWORD flags = 0;
	// The lpNumberOfBytesRecvd parameter may return erronous results, so it is set to NULL (see MSDN for WSARecv).
	// The overlapped struct will contain the actual number of bytes transferred after completion.
	// The length of the CleanString rcv_buf_clean is set to the proper length in ioGetEventsC.
	// When the received CleanString is then returned upon the next call to retrieveDataC it will have the proper length.
	if (SOCKET_ERROR == WSARecv((SOCKET) fd, &rcv_buf, 1, NULL, &flags, &io_data->overlapped, NULL)) {
		if (WSAGetLastError() != WSA_IO_PENDING) {
			*p_err_code = -1;
			return;
		}
	}
	*p_err_code = 0;
}

// Frees memory for client.
int cleanupFdC(int main_fd, int fd, int isASocket){
	char key[5];
	int err = fdToFdStr(fd, key);
	if (err) {
		fprintf(stderr, "Error: cleanupfd failed..\n");
		return -1;
	}

	if (isASocket) {
		err = closesocket((SOCKET) fd);
		if (err) {
			fprintf(stderr, "Error: closesocket failed..\n");
			return -1;
		}
	} else {
		err = CloseHandle(IntToPtr(fd));
		if (err) {
			fprintf(stderr, "Error: closeHandle failed..\n");
			return -1;
		}
	}

	err = removeHT(ht, key);
	if (err) {
		fprintf(stderr, "Error: removeHT failed..\n");
		return -1;
	}
	return 0;
}

int fdStrToFd(char* p_fd_str) {
	int fd;
	sscanf(p_fd_str, "%d", &fd);
	return fd;
}

int windowsIncPacketsToWriteC(int fd, int num_packets) {
	char key[5];
	int err = fdToFdStr(fd, key);
	if (err) {
		return -1;
	}
	table_entry_t* entry = getHT(ht, key);
	if (entry == NULL) {
		fprintf(stderr, "Error: removeHT failed..\n");
		return -1;
	}
	entry->packets_to_write += num_packets;
	return putHT(ht, key, entry);
}

int anyPendingPacketsC(int fd, int* anyPackets) {
	*anyPackets = 0;
	char key[5];
	int err = fdToFdStr(fd, key);
	if (err) {
		return -1;
	}
	table_entry_t* entry = getHT(ht, key);
	if (entry == NULL) {
		fprintf(stderr, "Error: removeHT failed..\n");
		return -1;
	}
	*anyPackets = entry->packets_to_write != 0;
	return 0;
}
