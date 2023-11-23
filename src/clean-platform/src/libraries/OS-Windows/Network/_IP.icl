implementation module Network._IP

import StdEnv
import Text, System._Pointer
import code from library "Ws2_32"

_lookupIPAddress :: !String !*World -> (!?Int, !*World)
_lookupIPAddress name world
	# (_,world)		= WSAStartupC 1 (createArray 4 0) world //We supply a bogus array of 16 bytes to store the WSADATA struct in
	# (ptrhe,world) = gethostbynameC (packString name) world	
	| ptrhe == 0	= (?None, world)
	# ptrli			= readInt ptrhe 12
	# ptrad			= readInt ptrli 0
	# addr			= readInt ptrad 0
	| addr == addr
		# (_,world)		= WSACleanupC world
		= (?Just addr, world)
	where
		WSAStartupC :: !Int !{#Int} !*World -> (!Int, !*World)
		WSAStartupC a0 a1 a2 = code {
			ccall WSAStartup@8 "PIA:I:A"
		}
		WSACleanupC :: !*World -> (!Int, !*World)
		WSACleanupC a0 = code {
			ccall WSACleanup@0 "P:I:A"
		}
		gethostbynameC :: !{#Char} !*World -> (!Pointer, !*World)
		gethostbynameC a0 a1 = code {
			ccall gethostbyname@4 "Ps:I:A"
		}
