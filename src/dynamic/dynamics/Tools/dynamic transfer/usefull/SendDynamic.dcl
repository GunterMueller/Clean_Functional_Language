definition module SendDynamic

import DynamicRefTools, Directory, DynID, TCPChannel

dynamicPort :== 11702
 
/*
:: Bool = NoDynError | MissingID [String]
IsDynError :: Bool -> Bool
*/

/*
SendDynamicToHost :: String String *World -> (Bool, *World)
// send a dynamic with its dependencies through network to a host
// result is trueif the operation succeeds (filename, hostname, w ) -> ( succeed, w )
// pair of ReceiveDynamic
*/
/*
SendDynamicsToHost :: [DynamicID] String *World -> (Bool, *World)
// sends dynamic files without thier dependencies through network
// result is true if all of the dynamics arrive 
// SendDynamicsToHost ids hostname w -> ( ok, w ) 
*/
//SendFileAcked :: String *TCP_DuplexChannel *World -> (Bool, *World)
// sends a file through TCP channel
// ( filename, channel, w) -> ( ok, w )
// pair of ReceiveFile
 
Log :: String *f -> *f
// writes a line of text to the log 

//ReceiveFileAcked :: *TCP_DuplexChannel *World -> ( Bool, String, String, *TCP_DuplexChannel, *World )
// waits for a dynamic to be sent here
// returns the dynamic name as a result
// pair of SendFileToHost

/*
ReceiveDynamic :: *World -> (Bool, DynamicID, *World)
// recieves a dynamic and its dependencies
// returns true if the operation succeeds
// returns the Dynamic iD as result
// pair of SendDynamicToHost 
*/

/*
ReceiveDynamics :: *World -> (Bool, [DynamicID], *World)
// receives dynamic files without their dependencies
// ReceiveDynamics w -> (ok, ids, w)
// results true if all arrive 
*/

AnswerDynamicRequest :: *World -> ( Bool, *World )
// waits for a dynamic request determines the dependencies of that
// sends the ids of these dynamics
// and waits for a list of dynamics that are needed on the other side
// then sends the dynamics needed
 
RequestDynamic :: String String *World -> *World
// sends a dynamic request through network and receives the ids of the needed dynamics
// determines which dynamics are needed and sends the ids of those
// then waits for those to arrive
// RequestDynamic filename hostname w - > w


StoreDynamic :: String [String] String *f -> *f | FileSystem f 
// copies only the dynamic and its dependencies to a user specified folder
// stores the dynamic and its dependencies 
// excluding those in the list to the given directory 
// the dynamic files are copied to the given directory


LoadDynamic :: String *f -> *f | FileSystem f
// loads contents of a directory and puts the files
// to the local dynamics and libraries directory

 