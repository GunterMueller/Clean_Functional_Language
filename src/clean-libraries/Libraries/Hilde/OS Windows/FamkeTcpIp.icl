implementation module FamkeTcpIp

import StdClass, StdBool, StdInt, StdArray, StdMisc, Marshall, StdString
import code from "windowsTcpIp.obj", library "windowsWS2_32_library"

:: TcpIp a
	= {socket :: !Int, port :: !Int}

instance sendTcpIp String
where
	sendTcpIp x tcpip=:{socket, port}
		# len = size x
		  (error, sent, tcpip) = tcpIpSend socket 4 (marshall len) True tcpip
		| error <> 0 = (False, tcpip)
		| sent <> 4 = abort "TcpIp error: sent <> 4"
		# (error, sent, tcpip) = tcpIpSend socket len x True tcpip
		| error <> 0 || sent <> len = abort ("TcpIp error(" +++ toString error +++ "): error <> 0 || sent <> len")
		= (True, tcpip)
	where
		tcpIpSend :: !Int !Int !{#Char} !Bool !*env -> (!Int, !Int, !*env)
		tcpIpSend socket len buffer block env = code inline {
				ccall	tcpIpSend	"IIsI:II:A"
			}

instance receiveTcpIp String
where
	receiveTcpIp blocking tcpip=:{socket, port}
		# (error, read, buffer, tcpip) = tcpIpReceive socket 4 blocking tcpip
		| error <> 0 = (False, "", tcpip)
		| read == 0
			| blocking = abort "TcpIp error: read == 0 && blocking"
			= (False, "", tcpip)
		| read <> 4 = abort "TcpIp error: read <> 4"
		# len = unmarshall buffer
		  (error, read, buffer, tcpip) = tcpIpReceive socket len True tcpip
		| error <> 0 || read <> len = abort ("TcpIp error(" +++ toString error +++ "): error <> 0 || read <> len")
		= (True, buffer, tcpip)
	where
		tcpIpReceive :: !Int !Int !Bool !*env -> (!Int, !Int, !*{#Char}, !*env)
		tcpIpReceive socket len blocking env = code inline {|B| socket | len | blocking
				push_b			1							|B| len | socket | len | blocking
				create_array_	CHAR 0 1					|A| !buffer={#Char} | env |B| socket | len | blocking
				push_a			0							|A| !buffer | !buffer | env
				ccall		tcpIpReceive	"IIsI:II:AA"	|B| error | read |A| !buffer | env
			}

instance closeTcpIp String
where
	closeTcpIp {socket, port} env 
		# (error, env) = tcpIpClose True socket env
		= (error == 0, env)

instance receiveTcpIp (TcpIp .a)
where
	receiveTcpIp blocking tcpip=:{socket, port} 
		# (error, socket`) = tcpIpAccept socket blocking
		| error <> 0
			| blocking = abort ("TcpIp error(" +++ toString error +++ "): error <> 0 && blocking")
			= (False, {socket = -1, port = 0}, tcpip)
		= (True, {socket = socket`, port = -2}, tcpip)
	where
		tcpIpAccept :: !Int !Bool -> (!Int, !Int)
		tcpIpAccept socket block = code inline {
			ccall	tcpIpAccept	"II:II"
		}

instance closeTcpIp (TcpIp .a)
where
	closeTcpIp {socket, port} env 
		# (error, env) = tcpIpClose False socket env
		= (error == 0, env)

instance TcpIp World 
where
	listenTcpIp (FixedPort port) env
		# env = tcpip env
		  (error, socket, env) = tcpIpListenerAtPort port env
		= (error == 0, port, {socket = socket, port = port}, env)
	where
		tcpIpListenerAtPort :: !Int !*World -> (!Int, !Int, !*World)
		tcpIpListenerAtPort port world = code inline {
				ccall	tcpIpListenerAtPort	"I:II:A"
			}
	listenTcpIp AnyPort env
		# env = tcpip env
		  (error, port, socket, env) = tcpIpListener env
		= (error == 0, port, {socket = socket, port = port}, env)
	where
		tcpIpListener :: !*World -> (!Int, !Int, !Int, !*World)
		tcpIpListener world = code inline {
				ccall	tcpIpListener	":III:A"
			}

	connectTcpIp blocking ip port env
		# env = tcpip env
		  (error, socket, env) = tcpIpConnect ip port blocking env
//		= (error == 0, {socket = socket, port = -1}, if (error <> 0) (trace_n ("(connectTcpIp " +++ toString ip +++ " " +++ toString port +++ ") == " +++ toString error) env) env)
		= (error == 0, {socket = socket, port = -1}, env)
	where
		tcpIpConnect :: !Int !Int !Bool !*World -> (!Int, !Int, !*World)
		tcpIpConnect ip port blocking world = code inline {
				ccall	tcpIpConnect	"III:II:A"
			}

	resolveTcpIp hostname env
		# env = tcpip env
		  (error, ip, env) = tcpIpAddress (marshall hostname) env
		= (error == 0, ip, env)
	where
		tcpIpAddress :: !{#Char} !*World -> (!Int, !Int, !*World)
		tcpIpAddress name world = code inline {
				ccall	tcpIpAddress	"s:II:A"
			}

tcpip :: !*World -> *World
tcpip world
	# (error, world) = tcpIpSetup world
	| error <> 0 = abort ("TcpIp error(" +++ toString error +++ "): cannot initialize TCP/IP")
	= world
where
	tcpIpSetup :: !*World -> (!Int, !*World)
	tcpIpSetup env = code inline {
		ccall	tcpIpSetup	":I:A"
	}

tcpIpClose :: !Bool !Int !*env -> (!Int, !*env)
tcpIpClose shutdown socket env = code {
	ccall	tcpIpClose	"II:I:A"
}
