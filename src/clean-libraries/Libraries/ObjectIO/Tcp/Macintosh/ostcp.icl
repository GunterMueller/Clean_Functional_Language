implementation module ostcp

import	StdInt, StdTuple, StdBool
import	StdTCPDef, StdTime
import	StdChannels
import	tcp, ostick
import	code from "cTCP.", library "OpenTransport_library"


OSinstallTCP :: !*OSToolbox -> *OSToolbox
OSinstallTCP tb
	// dummy on Mac...
	= tb

// endpoint state codes (C dependent)
IDLE			:== 2
DATAXFER		:== 5
JUSTRECEIVE		:== 6
JUSTSEND		:== 7

os_eom :: !EndpointRef !*env -> (!Bool, !*env)
os_eom endpointRef env
	#!	(available, env)	= data_availableC endpointRef env
	|	available
		= (False, env)
	#!	(state, env)		= getEndpointStateC endpointRef env
	= (state<>DATAXFER && state<>JUSTRECEIVE, env)

os_disconnected :: !EndpointRef !*env -> (!Bool, !*env)
os_disconnected endpointRef env
	# (state, env)	= getEndpointStateC endpointRef env
	= (state<>DATAXFER && state<>JUSTSEND, env)

os_connectrequestavailable :: !EndpointRef !*env -> (!Bool, !*env)
os_connectrequestavailable er env
	# (res,env)	= os_connectrequestavailable er env
	= (res<>0,env)
where
	os_connectrequestavailable :: !EndpointRef !*env -> (!Int, !*env)
	os_connectrequestavailable _ _
		= code
			{
				ccall os_connectrequestavailable "I:I:A"
			}

os_connectTCP :: !Int !Bool !(!Bool, !Int) !(!Int,!Int) !*env -> (!(!InetErrCode,!Bool,!EndpointRef), !*env)
os_connectTCP chanEnvKind block mbTimeout (inetHost, inetPort) env
	# destinationStr	= (toDottedDecimal inetHost)+++":"+++toString inetPort+++"\0"
	= os_connectTCPC chanEnvKind block mbTimeout destinationStr env


os_connectTCPC	::	!Int !Bool !(!Bool, !Int) !String !*env 
				->	(!(!InetErrCode,!Bool,!EndpointRef), !*env)
// in: chanEnvKind block doTimeout stoptime destination
// out: Bool:timeout expired
os_connectTCPC a b c d env
	# ((a,b,c),env)	= os_connectTCPC a b c d env
	= ((a,b<>0,c),env)
where
	os_connectTCPC	::	!Int !Bool !(!Bool, !Int) !String !*env 
					->	(!(!InetErrCode,!Int,!EndpointRef), !*env)
	os_connectTCPC _ _ _ _ _
		= code
			{
				ccall os_connectTCPC "IIIIS:VIII:A"
			}

os_select_inetevents :: !EndpointRef !InetReceiverCategory !Int !Bool !Bool !Bool !*env -> *env
os_select_inetevents endpointRef receiverType referenceCount get_receive_events get_sendable_events 
					alreadyEom env
	# env	= setEndpointDataC endpointRef referenceCount get_receive_events get_sendable_events alreadyEom env
	| receiverType==ListenerReceiver
		# (connectRequestAvl,env)	= os_connectrequestavailable endpointRef env
		| connectRequestAvl
			= ensureEventInQueueC endpointRef IE_CONNECTREQUEST receiverType env
		= env 
	| receiverType==RChanReceiver
		# (dataAvailable, env)	= data_availableC endpointRef env
		| dataAvailable
			= ensureEventInQueueC endpointRef IE_RECEIVED receiverType env
		= env
	| receiverType==SChanReceiver
		= ensureEventInQueueC endpointRef IE_SENDABLE receiverType env

ensureEventInQueueC :: !EndpointRef !InetEvent !InetReceiverCategory !*env -> *env
ensureEventInQueueC _ _ _ _
	= code
		{
			ccall ensureEventInQueueC "III:V:A"
		}

getEndpointStateC	::	!EndpointRef !*env -> (!Int, !*env)
// returns one of the possible endpoint states listed above or something else
getEndpointStateC _ _
	= code
		{
			ccall getEndpointStateC "I:I:A"
		}

getMbStopTime :: !(Maybe Timeout) !*env -> (!(!Bool, !Int), !*env) | ChannelEnv env
getMbStopTime Nothing env
	=((False,0), env)
getMbStopTime (Just timeout) env
	# (now, env) = getCurrentTick env
	= ((True, timeout + (unpack_tick now)), env)

