definition module FamkeRpc

from FamkeKernel import :: FamkePort(..)

:: RpcId a b :== FamkePort a b

:: RpcServer a b

rpc :: !(RpcId a b) a !*World -> (b, !*World) | TC a & TC b

rpcOpen :: !(RpcId .a .b) !*World -> (!RpcId .a .b, !*RpcServer .a .b, !*World)
rpcWait :: !*(RpcServer a b) !*World -> (a, !*(b -> *(*World -> *World)), !*RpcServer a b, !*World) | TC a & TC b
rpcClose :: !*(RpcServer .a .b) !*World -> *World
