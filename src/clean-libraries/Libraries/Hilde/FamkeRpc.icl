implementation module FamkeRpc

import FamkeKernel
import StdBool, StdMisc

:: RpcServer a b
	:== FamkeServer a b

rpc :: !(RpcId a b) a !*World -> (b, !*World) | TC a & TC b
rpc id request famke
	# (ok, comm, famke) = famkeConnect True id famke
	| not ok = abort "rpc: clientConnect failed"
	# (ok, comm, famke) = famkeSend request comm famke
	| not ok = abort "rpc: famkeSend failed"
	# (ok, reply, comm, famke) = famkeReceive True comm famke
	| not ok = abort "rpc: famkeReceive failed"
	# famke = famkeDisconnect comm famke
	= (reply, famke)

rpcOpen :: !(RpcId .a .b) !*World -> (!RpcId .a .b, !*RpcServer .a .b, !*World)
rpcOpen id famke 
	# (ok, id, server, famke) = famkeOpen id famke
	| not ok = abort "rpcOpen: famkeOpen failed"
	= (id, server, famke)

rpcWait :: !*(RpcServer a b) !*World -> (a, !*(b -> *(*World -> *World)), !*RpcServer a b, !*World) | TC a & TC b
rpcWait server famke
	# (ok, comm, server, famke) = famkeAccept True server famke
	| not ok = abort "rpcWait: serverConnect failed"
	# (ok, request, comm, famke) = famkeReceive True comm famke
	| not ok = abort "rpcWait: famkeReceive failed"
	= (request, rpcReply comm, server, famke)
where
	rpcReply :: !*(FamkeChannel b .a) b !*World  -> *World | TC b
	rpcReply comm reply famke
		# (ok, comm, famke) = famkeSend reply comm famke
		| not ok = abort "rpcReply: famkeSend failed"
		= famkeDisconnect comm famke

rpcClose :: !*(RpcServer .a .b) !*World -> *World
rpcClose server famke = famkeClose server famke

rpcHandle :: !.(a -> *(*World -> *(b, *World))) !*(RpcServer a b) !*World -> (!*RpcServer a b, !*World) | TC a & TC b
rpcHandle handler server famke
	# (request, return, server, famke) = rpcWait server famke
	  (reply, famke) = handler request famke
	= (server, return reply famke) 
