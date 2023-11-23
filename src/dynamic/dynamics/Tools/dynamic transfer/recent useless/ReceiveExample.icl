module ReceiveExample

import TCPChannel



AChannelFile :: ChannelFile *World -> *World
AChannelFile chfile world = world

AnInt :: Int *World -> *World
AnInt i world = world

AnIntList :: [Int] *World -> *World
AnIntList l world = world

AString :: String *World -> *World
AString s w
	= w

Start world 
	# ( channel, _, world ) = serverConnect 11111 world
	# ( i, channel, world ) = Receive channel world
	# world = AString i world
	= closeChannels channel world
