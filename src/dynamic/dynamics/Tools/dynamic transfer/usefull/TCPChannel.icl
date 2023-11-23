implementation module TCPChannel

import StdTCP, DynID, StdEnv, CopyFile

from StdSystem import ticksPerSecond

buffersize = 8192
// the buffer size for file transfer

:: ChannelFile = ChannelFile_ String String

OldName :: ChannelFile -> String
OldName (ChannelFile_ a b) = a

NewName :: ChannelFile -> String
NewName (ChannelFile_ a b) = b

(String) :: String -> String
(String) x = x

Log :: String *World -> *World
Log st world 
	# ( console, world ) = stdio world
	#  console = fwrites st console
	# ( ok, world ) = fclose console world 
	= world

serverConnect :: Int *World -> (TCP_DuplexChannel, IPAddress, *World)
// connects as a server
serverConnect port world 
	#(ok, mbListener, world ) = openTCP_Listener port world
	| not ok 
		= abort "cannot listen on port"
	# listener = fromJust mbListener
	#((ip, duplexChannel), listener, world) = receive listener world
	# world = closeRChannel listener world
	| otherwise 	
		= (duplexChannel, ip, world )

clientConnect :: String Int *World -> (TCP_DuplexChannel, *World)
// connect as a client
clientConnect hostname port world
	# (mbIPAddr, world)	= lookupIPAddress hostname world
	|	isNothing mbIPAddr	  
		= abort ( hostname +++" not found\n")
	# (tReport, mbDuplexChan, world) = connectTCP_MT (Just (5*ticksPerSecond)) (fromJust mbIPAddr, port) world
	|	tReport <> TR_Success
		= abort (   hostname+++" does not respond on port "   +++toString port+++"\n")
//	# world = Log ("connected to "+++hostname+++"\n") world
	= (fromJust mbDuplexChan, world)



SendAck :: *TCP_DuplexChannel *World -> ( *TCP_DuplexChannel, *World )
// send acknowledgement 
SendAck channel world
		# {rChannel = rc, sChannel = sc } = channel
		# (sc, world) = send (toByteSeq "ack") sc world
		= ({sChannel = sc, rChannel = rc}, world)

ReceiveAck :: *TCP_DuplexChannel *World -> ( *TCP_DuplexChannel, *World )
// receive acknowledgement
ReceiveAck channel world
		# { rChannel = rc, sChannel = sc } = channel
		# ( ack, rc, world ) = receive rc world
		= ({sChannel = sc, rChannel = rc}, world)
	

class ThroughChannel a where
// sending and receiving data through a TCP_DuplexChannel
	Send :: a *TCP_DuplexChannel *World -> ( *TCP_DuplexChannel, *World )
	Receive :: *TCP_DuplexChannel *World -> ( a, *TCP_DuplexChannel, *World )
	
	SendAcked :: a *TCP_DuplexChannel *World -> ( *TCP_DuplexChannel, *World )
	SendAcked x channel world
		# ( channel, world ) = Send x channel world
		:== ReceiveAck channel world
		
	ReceiveAcked :: *TCP_DuplexChannel *World -> ( a, *TCP_DuplexChannel, *World )
	ReceiveAcked channel world
		# ( x, channel, world ) = Receive channel world
		# ( channel, world ) = SendAck channel world
		:== ( x, channel, world )


instance ThroughChannel String where
	Send :: String *TCP_DuplexChannel *World -> (*TCP_DuplexChannel, *World)
	Send string channel world
		# {rChannel = rc, sChannel = sc } = channel
//		# world = Log (string+++"\n") world
		# (sc, world) = send (toByteSeq string) sc world
		= ({sChannel = sc, rChannel = rc}, world)
	
	Receive :: *TCP_DuplexChannel *World -> ( String, *TCP_DuplexChannel, *World) 
	Receive channel world
		# {rChannel = rc, sChannel = sc } = channel
		# ( byteseq, rc, world ) = receive rc world
//		# world = Log ("["+++(toString byteseq)+++"]\n") world
		= ( (toString byteseq), {sChannel = sc, rChannel = rc}, world)


ATrash :: String *World -> *World
ATrash trash world = world

instance ThroughChannel [a] | ThroughChannel a where
	Send list channel world
		# ( channel, world ) = SendAcked ( length list ) channel world
		| otherwise = SendList list channel world
		where
			SendList [] channel world
				= Send "trash" channel world
			SendList [ item ] channel world 
				= Send item channel world
			SendList [ item: items ] channel world
				# ( channel, world ) = SendAcked item channel world
				= SendList items channel world
				
	Receive channel world
		# ( n, channel, world ) = ReceiveAcked channel world 
		| otherwise = ReceiveN n channel world
		where
			ReceiveN 0 channel world
				# ( trash, channel, world ) = Receive channel world
				# world = ATrash trash world
				= ( [], channel, world ) 
			ReceiveN 1 channel world 
				# ( item, channel, world ) = Receive channel world
				= ( [ item ], channel, world )
			ReceiveN i channel world 
				# ( item, channel, world ) = ReceiveAcked channel world
				# ( items, channel, world ) = ReceiveN (i-1) channel world
				= ( [item:items], channel, world )
				
instance ThroughChannel ChannelFile where
	Send chfile channel world
		# ( channel, world ) = SendAcked (OldName chfile) channel world
		# ( channel, world ) = SendAcked (NewName chfile) channel world
		# ( filesize, world ) = FileSize (OldName chfile) world
		# ( channel, world ) = SendAcked filesize channel world
		# ( ok, file, world ) =  fopen (OldName chfile) FReadData world
		| not ok = abort ("cannot open file "+++(OldName chfile)+++"\n")
		# ( file, channel, world ) = SendFileContents file channel world
		# ( ok, world ) = fclose file world
		| not ok = abort ("cannot close file "+++(OldName chfile)+++"\n")
		= ( channel, world ) 
		where
			Receive :: (*TCP_DuplexChannel *World -> (String, *TCP_DuplexChannel, *World ) )
			Receive = Receive
			SendFileContents :: *File *TCP_DuplexChannel *World -> ( *File, *TCP_DuplexChannel, *World )
			SendFileContents file channel world
				# ( end, file ) = fend file
				| end = ( file, channel, world )
				# ( buffer, file ) = freads file buffersize
				# ( channel, world ) = Send buffer channel world
				= SendFileContents file channel world

	Receive channel world
		# ( oldfilename, channel, world ) = ReceiveAcked channel world
		# ( newfilename, channel, world ) = ReceiveAcked channel world
		# ( filesize, channel, world ) = ReceiveAcked channel world
		# ( ok, file, world ) = fopen newfilename FWriteData world
		| not ok = abort ("cannot open "+++newfilename+++"\n")
		# ( file, channel, world ) = ReceiveFileContents file filesize channel world
		# (ok, world) = fclose file world
		| not ok = abort ("cannot close "+++newfilename+++"\n")
		= ( ChannelFile_ oldfilename newfilename, channel, world )
		where
			ReceiveFileContents :: *File Int *TCP_DuplexChannel *World -> ( *File, *TCP_DuplexChannel, *World ) 
			ReceiveFileContents file filesize channel world
				| 0 == filesize = ( file, channel, world )
				# ( buffer, channel, world ) = Receive channel world
				# file = fwrites buffer file
				= ReceiveFileContents file (filesize - (size buffer)) channel world
				
instance ThroughChannel Int where
	Send x channel world = Send (toString x) channel world
	Receive channel world 
		# ( string, newchannel, newworld ) = Receive channel world
		= ( toInt ( (String) string ), newchannel, newworld )
		
instance ThroughChannel DynamicID1 where
	Send x channel world = Send (toString x) channel world
	Receive channel world 
		# ( string, channel, world ) = Receive channel world
		= ( (fromString string), channel, world )	

// closes TCP channels
closeChannels :: *TCP_DuplexChannel *World -> *World
closeChannels channels world
	# { sChannel = sc, rChannel = rc } = channels
	# world = closeRChannel rc world
	# world = closeChannel sc world
	= world 
