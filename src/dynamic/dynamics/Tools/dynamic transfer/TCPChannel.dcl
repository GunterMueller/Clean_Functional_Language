definition module TCPChannel

import StdTCP, DynID

serverConnect :: Int *World -> (TCP_DuplexChannel, IPAddress, *World)
// establishes a connection as a server on a given port

clientConnect :: String Int *World -> (TCP_DuplexChannel, *World)
// establishes a connection as a client to a host on a port

closeChannels :: *TCP_DuplexChannel *World -> *World
// closes TCP channels

SendAck :: *TCP_DuplexChannel *World -> ( *TCP_DuplexChannel, *World )
// sends an acknowledgemant through a channel

ReceiveAck :: *TCP_DuplexChannel *World -> ( *TCP_DuplexChannel, *World )
// receives an acknowledgement through a channel

:: ChannelFile = ChannelFile_ String String
// a type representing a file to be sent through a TCP channel
// the two arguments represent the old and the new filenames on the
// two ends of the channel

OldName :: ChannelFile -> String
NewName :: ChannelFile -> String
// functions for retreiving the old and new filenames from a ChannelFile
// OldName: the filename of the file on the sending side
// NewName: the filename on the receiving side

class ThroughChannel a where
// sending and receiving data through a TCP_DuplexChannel
	Send :: a *TCP_DuplexChannel *World -> ( *TCP_DuplexChannel, *World )
	Receive :: *TCP_DuplexChannel *World -> ( a, *TCP_DuplexChannel, *World )
	
	SendAcked :: a *TCP_DuplexChannel *World -> ( *TCP_DuplexChannel, *World )
	SendAcked x channel world
		# ( mchannel, mworld ) = Send x channel world
		:== ReceiveAck mchannel mworld
	
	ReceiveAcked :: *TCP_DuplexChannel *World -> ( a, *TCP_DuplexChannel, *World )
	ReceiveAcked channel world
		# ( x, channel, world ) = Receive channel world
		# ( channel, world ) = SendAck channel world
		:== ( x, channel, world )

		
instance ThroughChannel String 
instance ThroughChannel [a] | ThroughChannel a 
instance ThroughChannel Int 
instance ThroughChannel DynamicID1 
instance ThroughChannel ChannelFile
