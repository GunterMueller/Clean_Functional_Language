definition module System._Socket

from Data.Error import :: MaybeError
from System.OSError import :: MaybeOSError, :: OSError, :: OSErrorMessage, :: OSErrorCode
from System.Socket import :: SocketType, class SocketAddress, :: SendFlag, :: RecvFlag

:: *Socket a

AF_INET :== 2
AF_INET6 :== 23
AF_IPX :== 6
AF_APPLETALK :== 16
AF_NETBIOS :== 17
AF_IRDA :== 26
AF_BTH :== 32

SOCK_STREAM :== 1
SOCK_DGRAM :== 2
SOCK_RAW :== 3
SOCK_RDM :== 4
SOCK_SEQPACKET :== 5

MSG_WAITALL :== 8
MSG_DONTROUTE :== 4
MSG_PEEK :== 2
MSG_OOB :== 1

socket :: !SocketType !*env -> *(!MaybeOSError *(Socket sa), !*env) | SocketAddress sa
bind :: !sa !*(Socket sa) -> *(!MaybeOSError (), !*Socket sa) | SocketAddress sa
listen :: !Int !*(Socket sa) -> *(!MaybeOSError (), !*Socket sa) | SocketAddress sa
accept :: !*(Socket sa) -> *(!MaybeOSError (!*Socket sa, !sa), !*Socket sa) | SocketAddress sa
close :: !*(Socket sa) !*env -> *(!MaybeOSError (), !*env) | SocketAddress sa

connect :: !sa !*(Socket sa) -> *(!MaybeOSError (), !*Socket sa) | SocketAddress sa

send :: !String ![SendFlag] !*(Socket sa) -> *(!MaybeOSError Int, !*Socket sa)
recv :: !Int ![RecvFlag] !*(Socket sa) -> *(!MaybeOSError String, !*Socket sa)

networkToHostByteOrderShort :: !Int -> Int
hostToNetworkByteOrderShort :: !Int -> Int
networkToHostByteOrderLong :: !Int -> Int
hostToNetworkByteOrderLong :: !Int -> Int
