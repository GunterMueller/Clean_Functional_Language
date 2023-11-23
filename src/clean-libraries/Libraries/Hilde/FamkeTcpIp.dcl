definition module FamkeTcpIp

:: TcpIpPort = AnyPort | FixedPort !Int

:: TcpIp a

class sendTcpIp a :: !.a !*(TcpIp .a) -> (!Bool, !*TcpIp .a)
class receiveTcpIp a :: !Bool !*(TcpIp .a) -> (!Bool, !.a, !*TcpIp .a)
class closeTcpIp a :: !*(TcpIp .a) !*env -> (!Bool, !*env) | TcpIp env

class TcpIp env 
where
	listenTcpIp :: !TcpIpPort !*env -> (!Bool, !Int, !*TcpIp *(TcpIp .a), !*env)
	connectTcpIp :: !Bool !Int !Int !*env -> (!Bool, !*TcpIp .a, !*env)
	resolveTcpIp :: !String !*env -> (!Bool, !Int, !*env)

localhostIp env :== resolveTcpIp "" env

instance sendTcpIp String
instance receiveTcpIp String
instance closeTcpIp String

instance receiveTcpIp (TcpIp .a)
instance closeTcpIp (TcpIp .a)

instance TcpIp World 
