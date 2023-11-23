module SendExample

import TCPChannel 

Start world
	# ( channel, world ) = clientConnect "localhost" 11111 world
	# ( channel, world ) = Send "d" channel world
//	# ( channel, world ) = SendAcked [1,2,3,4] channel world
	= closeChannels channel world