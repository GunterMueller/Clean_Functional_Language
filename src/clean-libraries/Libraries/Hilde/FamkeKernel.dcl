definition module FamkeKernel

import StdDynamic

:: FamkePort a b
	= FamkeProcessServer !Int
	| FamkeNameServer
	| FamkeAnyServer
	| FamkeServer !Int !Int

:: FamkeServer a b 
:: FamkeChannel a b 

famkeOpen :: !(FamkePort .a .b) !*World -> (!Bool, FamkePort .a .b, *FamkeServer .a .b, !*World)
famkeAccept :: !Bool !*(FamkeServer .a .b) !*World -> (!Bool, !*FamkeChannel .b .a, !*FamkeServer .a .b, !*World)
famkeClose :: !*(FamkeServer .a .b) !*World -> *World

famkeConnect :: !Bool !(FamkePort .a .b) !*World -> (!Bool, !*FamkeChannel .a .b, !*World)
famkeDisconnect :: !*(FamkeChannel .a .b) !*World -> *World

famkeSend :: a !*(FamkeChannel a .b) !*World -> (!Bool, !*FamkeChannel a .b, !*World) | TC a
famkeReceive :: !Bool !*(FamkeChannel .a b) !*World -> (!Bool, b, !*FamkeChannel .a b, !*World) | TC b

StartKernel :: !Int !.(*World -> *World) !*World -> *World
