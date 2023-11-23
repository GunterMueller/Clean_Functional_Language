module ReceiveDynamicExample
 
import SendDynamic, StdEnv, DynID

import code from library "StaticClientChannel_library"

hostname = "socrates.cs.kun.nl"
//id :: DynamicID
dynid = fromString "C:\\WIND95\\Desktop\\Clean\\cvs\\dynamic\\dynamics\\examples\\apply\\non-predefined result type\\value.dyn" 
 
Start world 
	= RequestDynamic dynid hostname world

//Start world  
//	= ReceiveDynamics world
/*	
ReceiveDynamics :: *World -> *World
ReceiveDynamics world 
	#( ok, dynID, world ) = ReceiveDynamic world
	| ok = ReceiveDynamics world
	| otherwise = Log "ERROR receiving dynamic\n" world
*/
