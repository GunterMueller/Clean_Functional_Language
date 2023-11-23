implementation module FamkeConcurrentClean

import StdGeneric, FamkeKernel
import FamkeProcess, StdString, StdArray, StdInt, StdReal, StdMisc, StdBool, StdTuple
from CleanTricks import unsafeTypeCast, unsafeTypeAttrCast

:: ProcId 
	:== ProcessId

``P`` :: !(*World -> *(a, *World)) !*World -> (a, !*World) | SendGraph{|*|}, ReceiveGraph{|*|}, TC a
``P`` f famke
	# (port, famke) = reservePort famke
	  (_, famke) = newProcess (sendNfPieceWise port f) famke
	  (famke`, famke) = unsafeCopy famke
	= (wait port famke`, famke)
where
	unsafeCopy :: !*a -> (!*a, !*a)
	unsafeCopy x = code inline {
		push_a	0
	}

	sendNfPieceWise :: !(FamkePort String String)  !(*World -> *(a, *World)) !*World -> *World | SendGraph{|*|} a
	sendNfPieceWise port f famke
		# (channel, famke) = tryToBeServer port famke
		  (x, famke) = f famke
		  (channel, famke) = SendGraph{|*|} x channel famke
//		  (_, channel, famke) = famkeSend x channel famke
		  famke = famkeDisconnect channel famke
		= famke

	wait :: !(FamkePort String String) !*World -> a | ReceiveGraph{|*|} a
	wait port famke
		# (channel, famke) = tryToBeServer port famke
		  (x, channel, famke) = ReceiveGraph{|*|} channel famke
//		  (_, x, channel, famke) = famkeReceive True channel famke
//		  famke = famkeDisconnect channel famke
		= x //(x, famke)

	tryToBeServer port famke
		# (ok, _, server, famke) = famkeOpen port famke
		| not ok = beClient port famke
		# (ok, channel, server, famke) = famkeAccept True server famke
		| not ok = abort "famkeAccept failed"
		# famke = famkeClose server famke
		  famke = freePort port famke
		= (channel, famke)

	beClient port famke
		# (ok, channel, famke) = famkeConnect True port famke
		| not ok = beClient port famke
		= (channel, famke)
		
generic SendGraph a :: !a !*(FamkeChannel String String) !*World -> *(!*FamkeChannel String String, !*World)
SendGraph{|UNIT|} _ channel famke = (channel, famke)
SendGraph{|PAIR|} gl gr (PAIR l r) channel famke
	# (channel, famke) = freeze gl l channel famke
	= freeze gr r channel famke
SendGraph{|EITHER|} gl gr (LEFT l) channel famke
	# (ok, channel, famke) = famkeSend "LEFT" channel famke
	| not ok = abort "SendGraph failed"
	= freeze gl l channel famke
SendGraph{|EITHER|} gl gr (RIGHT r) channel famke
	# (ok, channel, famke) = famkeSend "RIGH" channel famke
	| not ok = abort "SendGraph failed"
	= freeze gr r channel famke
SendGraph{|CONS|} gx (CONS x) channel famke = freeze gx x channel famke
SendGraph{|FIELD|} gx (FIELD x) channel famke = freeze gx x channel famke
SendGraph{|OBJECT|} gx (OBJECT x) channel famke = freeze gx x channel famke
SendGraph{|String|} x channel famke = freeze sendGraph x channel famke
SendGraph{|Char|} x channel famke 
	#!s = {x}
	= freeze sendGraph s channel famke
SendGraph{|Int|} x channel famke 
	#!s = toString x
	= freeze sendGraph s channel famke
SendGraph{|Real|} x channel famke 
	#!s = toString x
	= freeze sendGraph s channel famke
SendGraph{|Bool|} x channel famke 
	#!s = if x "True" "Fals"
	= freeze sendGraph s channel famke
SendGraph{|Dynamic|} x channel famke
	# (ok, channel, famke) = unsafeFamkeSendDynamic x channel famke
	| not ok = abort "SendGraph failed"
	= (channel, famke)

sendGraph s channel famke
	# (ok, channel, famke) = famkeSend s channel famke
	| not ok = abort "SendGraph failed"
	= (channel, famke)

generic ReceiveGraph b :: !*(FamkeChannel String String) !*World -> *(!b, *FamkeChannel String String, *World)
ReceiveGraph{|UNIT|} channel famke = (UNIT, channel, famke)
ReceiveGraph{|PAIR|} gl gr channel famke 
	# (l, channel, famke) = defrost gl channel famke
	  (r, channel, famke) = defrost gr channel famke
	= (PAIR l r, channel, famke)
ReceiveGraph{|EITHER|} gl gr channel famke 
	# (ok, s, channel, famke) = famkeReceive True channel famke
	| not ok = abort "ReceiveGraph failed"
	| s == "LEFT"
		# (l, channel, famke) = defrost gl channel famke
		= (LEFT l, channel, famke)
	| s == "RIGH"
		# (r, channel, famke) = defrost gr channel famke
		= (RIGHT r, channel, famke)
ReceiveGraph{|CONS|} gx channel famke
	# (x, channel, famke) = defrost gx channel famke
	= (CONS x, channel, famke)
ReceiveGraph{|FIELD|} gx channel famke
	# (x, channel, famke) = defrost gx channel famke
	= (FIELD x, channel, famke)
ReceiveGraph{|OBJECT|} gx channel famke
	# (x, channel, famke) = defrost gx channel famke
	= (OBJECT x, channel, famke)
ReceiveGraph{|String|} channel famke 
	# (x, channel, famke) = defrost receiveGraph channel famke
	= (x, channel, famke)
ReceiveGraph{|Char|} channel famke 
	# (x, channel, famke) = defrost receiveGraph channel famke
	= (x.[0], channel, famke)
ReceiveGraph{|Int|} channel famke 
	# (x, channel, famke) = defrost receiveGraph channel famke
	= (toInt x, channel, famke)
ReceiveGraph{|Real|} channel famke 
	# (x, channel, famke) = defrost receiveGraph channel famke
	= (toReal x, channel, famke)
ReceiveGraph{|Bool|} channel famke 
	# (x, channel, famke) = defrost receiveGraph channel famke
	= (case x of "True" -> True; "Fals" -> False, channel, famke)
ReceiveGraph{|Dynamic|} channel famke
	# (ok, x, channel, famke) = unsafeFamkeReceiveDynamic True channel famke
	| not ok = abort "ReceiveGraph failed"
	= (x, channel, famke)

receiveGraph channel famke 
	# (ok, s, channel, famke) = famkeReceive True channel famke
	| not ok = abort "ReceiveGraph failed"
	= (s, channel, famke)

freeze :: .(a -> .(*(FamkeChannel String .b) -> .(*World -> *(*FamkeChannel String .b, *World)))) a !*(FamkeChannel String .b) !*World -> (!*FamkeChannel String .b, !*World)
freeze g x channel famke
	# (rnf, x, famke) = (True, x, famke) //unsafeIsInRNF x famke
	| rnf
		# (ok, channel, famke) = famkeSend "_RNF" channel famke
		| not ok = abort "SendGraph failed"
		= g x channel famke
	# (ok, channel, famke) = famkeSend "_CLO" channel famke
	| not ok = abort "SendGraph failed"
	# (ok, channel, famke) = unsafeFamkeSendDynamic (dynamic unsafeTypeCast x :: A.c: c) channel famke
	| not ok = abort "SendGraph failed"
	= (channel, famke)

defrost :: .(*(FamkeChannel .a String) -> .(*World -> *(b, *FamkeChannel .a String, *World))) !*(FamkeChannel .a String) !*World -> (b, *FamkeChannel .a String, *World)
defrost g channel famke
	# (ok, s, channel, famke) = famkeReceive True channel famke
	| not ok = abort "ReceiveGraph failed"
	| s == "_RNF" = g channel famke
	| s == "_CLO"
		# (ok, d, channel, famke) = unsafeFamkeReceiveDynamic True channel famke
		| not ok = abort "ReceiveGraph failed"
		= (case d of (x :: A.c: c) -> x, channel, famke)

unsafeIsInRNF :: .a !*World -> (!Bool, .a, !*World)
unsafeIsInRNF x famke = code {	|A| x | famke
		pushD_a		0			|B| x-desc
		pushI		2			|B| 2 | x-desc
		and%					|B| (2 bitand x-desc)
		pushI		2			|B| 2 | (2 bitand x-desc)
		eqI						|B| (2 == 2 bitand x-desc)
	}
