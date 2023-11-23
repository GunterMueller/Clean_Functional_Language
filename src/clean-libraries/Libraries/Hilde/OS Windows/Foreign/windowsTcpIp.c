#include <Winsock2.h>

int tcpStarted = -1;

int tcpIpSetup()
{
	WSADATA data;

	if (tcpStarted != 0)
	    tcpStarted = WSAStartup(MAKEWORD(2, 0), &data);
    return tcpStarted;
}

int tcpIpListenerAtPort(int port, SOCKET* server)
{
	struct sockaddr_in serverAddr;
	int error;

	*server = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
	if (*server != INVALID_SOCKET)
	{
		serverAddr.sin_family = AF_INET;
		serverAddr.sin_addr.s_addr = htonl(INADDR_ANY);
		serverAddr.sin_port = htons(port);
		serverAddr.sin_zero[0] = 0;
		serverAddr.sin_zero[1] = 0;
		serverAddr.sin_zero[2] = 0;
		serverAddr.sin_zero[3] = 0;
		serverAddr.sin_zero[4] = 0;
		serverAddr.sin_zero[5] = 0;
		serverAddr.sin_zero[6] = 0;
		serverAddr.sin_zero[7] = 0;
		if (bind(*server, (struct sockaddr*)&serverAddr, sizeof(serverAddr)) == 0)
			if (listen(*server, SOMAXCONN) == 0)
				return 0;
		error = WSAGetLastError();
		closesocket(*server);
		*server = INVALID_SOCKET;
		return error;
	}
	else
		return WSAGetLastError();
}

int tcpIpListener(int* port, int backlog, SOCKET* server)
{
	struct sockaddr_in serverAddr;
	int size;
	int error;

	*port = 0;
	*server = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
	if (*server != INVALID_SOCKET)
	{
		serverAddr.sin_family = AF_INET;
		serverAddr.sin_addr.s_addr = htonl(INADDR_ANY);
		serverAddr.sin_port = 0;
		serverAddr.sin_zero[0] = 0;
		serverAddr.sin_zero[1] = 0;
		serverAddr.sin_zero[2] = 0;
		serverAddr.sin_zero[3] = 0;
		serverAddr.sin_zero[4] = 0;
		serverAddr.sin_zero[5] = 0;
		serverAddr.sin_zero[6] = 0;
		serverAddr.sin_zero[7] = 0;
		size = sizeof(serverAddr);
		if (bind(*server, (struct sockaddr*)&serverAddr, sizeof(serverAddr)) == 0)
			if (getsockname(*server, (struct sockaddr*)&serverAddr, &size) == 0)
				if (listen(*server, 1) == 0)
				{
					*port = htons(serverAddr.sin_port);
					return 0;
				}
		error = WSAGetLastError();
		closesocket(*server);
		*server = INVALID_SOCKET;
		return error;
	}
	else
		return WSAGetLastError();
}

int tcpIpAccept(SOCKET server, BOOL block, SOCKET* channel)
{
	u_long cmd;

	cmd = block ? 0 : 1;
	if (ioctlsocket(server, FIONBIO, &cmd) == 0)
	{
		*channel = accept(server, NULL, NULL);
		if (*channel != INVALID_SOCKET)
			return 0;
		else
			return WSAGetLastError();
	}
	else
	{
		*channel = INVALID_SOCKET;
		return WSAGetLastError();
	}
}

int tcpIpConnect(int addr, int port, BOOL block, SOCKET* channel)
{
	struct sockaddr_in channelAddr;
	u_long cmd;
	int error;

	*channel = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
	if (*channel != INVALID_SOCKET)
	{
		cmd = block ? 0 : 1;
		if (ioctlsocket(*channel, FIONBIO, &cmd) == 0)
		{
			channelAddr.sin_family = AF_INET;
			channelAddr.sin_addr.s_addr = htonl(addr);
			channelAddr.sin_port = htons(port);
			channelAddr.sin_zero[0] = 0;
			channelAddr.sin_zero[1] = 0;
			channelAddr.sin_zero[2] = 0;
			channelAddr.sin_zero[3] = 0;
			channelAddr.sin_zero[4] = 0;
			channelAddr.sin_zero[5] = 0;
			channelAddr.sin_zero[6] = 0;
			channelAddr.sin_zero[7] = 0;
			if (connect(*channel, (struct sockaddr*)&channelAddr, sizeof(channelAddr)) == 0)
				return 0;
		}
		error = WSAGetLastError();
		closesocket(*channel);
		*channel = INVALID_SOCKET;
		return error;
	}
	else
		return WSAGetLastError();
}

int tcpIpClose(BOOL shutup, SOCKET channel)
{
	int error;
	if (shutup)
		if (shutdown(channel, SD_BOTH) != 0)
		{
			error = WSAGetLastError();
			closesocket(channel);
			return error;
		}
	if (closesocket(channel) == 0)
		return 0;
	else
		return WSAGetLastError();
}

int tcpIpSend(SOCKET channel, int size, char* buffer, BOOL block, int* sent)
{
	u_long cmd;
	int error;

	cmd = block ? 0 : 1;
	if (ioctlsocket(channel, FIONBIO, &cmd) == 0)
	{
		 *sent = send(channel, buffer, size, 0);
		 if (*sent != size || *sent == SOCKET_ERROR)
		 {
		 	error = WSAGetLastError();
		 	closesocket(channel);
	 		return error;
		 }
		return 0;
	}
	else
	{
		*sent = 0;
		return WSAGetLastError();
	}
}

int tcpIpReceive(SOCKET channel, int size, char* buffer, BOOL block, int* read)
{
	u_long cmd;
	int acc;
	int error;

	cmd = block ? 0 : 1;
	*read = 0;
	if (ioctlsocket(channel, FIONBIO, &cmd) == 0)
	{
		while (*read < size && block)
		{
			acc = recv(channel, buffer, size - *read, 0);
			if (acc == 0 || acc == SOCKET_ERROR)
			{
				error = WSAGetLastError();
				if (acc == SOCKET_ERROR)
					closesocket(channel);
				return error;
			}
			*read += acc;
			buffer += acc;
		}
		return 0;
	}
	else
		return WSAGetLastError();
}

int tcpIpAddress(char* name, int* addr)
{
	struct hostent* ptr;
	char buffer[256];

	if (name[0] == '\0')
	{
		if (gethostname(buffer, sizeof(buffer)) != 0)
		{
			*addr = 0;
			return WSAGetLastError();
		}
		else
			name = buffer;
	}
	*addr = inet_addr(name);
	if (*addr != INADDR_NONE)
	{
		*addr = ntohl(*addr);
		return 0;
	}
	else
	{
		ptr = gethostbyname(name);
		if (ptr != NULL)
		{
			*addr = ntohl(((u_long*)(*(ptr->h_addr_list)))[0]);
			return 0;
		}
		else
		{
			*addr = 0;
			return WSAGetLastError();
		}
	}
}
