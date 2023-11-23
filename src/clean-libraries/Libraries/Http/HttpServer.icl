implementation module HttpServer

import Http, HttpUtil, HttpTextUtil
import StdList, StdTuple, StdArray, StdFile, StdBool, StdMisc
import StdTCP

//Start the HTTP server
http_startServer :: [HTTPServerOption] [((String -> Bool),(HTTPRequest *World-> (HTTPResponse,*World)))] *World -> *World
http_startServer options handlers world
	//Start the listener
	# (listener,world)	= startListener (getPortOption options) world
	//Enter the endless loop
	= loop options handlers listener [] [] [] world

// Try to open a listener on the given port
startListener :: Int !*World -> (TCP_Listener,!*World)
startListener port world
	# (success, mbListener, world) = openTCP_Listener port world
	| success	= (fromJust mbListener,world)
	| otherwise = abort ("Error: The server port " +++ (toString port) +++ " is currently occupied!\n" +++
						 "Probably a previous application is still running and you have forgotten to close it.\n" +++
						 "It is also possible that another web server running on your machine is using this port.\n\n\n")

//Main event loop, it is called each time a client connects or data arrives
loop ::	[HTTPServerOption]
		[((String -> Bool),(HTTPRequest *World-> (HTTPResponse,*World)))]
		TCP_Listener [TCP_RChannel] [TCP_SChannel]
		[(HTTPRequest,Bool,Bool,Bool)]
		*World -> *World
loop options handlers listener rchannels schannels requests world
	//Join the listener with the open channels
	# glue = (TCP_Listeners [listener]) :^: (TCP_RChannels rchannels)
	//Select the channel which has data available
	# ([(who,what):_],glue,_,world) = selectChannel_MT Nothing glue Void world
	//Split the listener from the open channels
	# ((TCP_Listeners [listener:_]) :^: (TCP_RChannels rchannels)) = glue
	//A new client attempts to connect
	| who == 0
		# world										= debug "New connection opened" options world
		# (tReport, mbNewMember, listener, world)	= receive_MT (Just 0) listener world
		| tReport <> TR_Success						= loop options handlers listener rchannels schannels requests world //Just continue
		# (ip,{sChannel,rChannel})					= fromJust mbNewMember
		# request									= {http_emptyRequest & client_name = toString ip, server_port = getPortOption options}
		= loop options handlers listener [rChannel:rchannels] [sChannel:schannels] [(request,False,False,False):requests] world		
	//A client has new data
	| otherwise
		// Select the offset without the listener
		# who = who - 1
		// Select the right read channel from the list
		# (currentrchannel, rchannels) = selectFromList who rchannels
		// Select the right write channel from the list
		# (currentschannel, schannels) = selectFromList who schannels
		// Select the right incomplete request from the list
		# ((request, method_done, headers_done, data_done), requests) = selectFromList who requests
		
		// New data is available
		| what == SR_Available
			// Fetch the new data from the receive channel
			# (data,currentrchannel,world) = receive currentrchannel world
		
			//Add new data to the request
			# (request, method_done, headers_done, data_done, error) = http_addRequestData request method_done headers_done data_done (toString data)
			| error
				//Sent bad request response and disconnect
				# (currentschannel,world) = send (toByteSeq "HTTP/1.0 400 Bad Request\r\n\r\n") currentschannel world
				# world = closeRChannel currentrchannel world
				# world = closeChannel currentschannel world
				= loop options handlers listener rchannels schannels requests world
		
			//Process a completed request
			| method_done && headers_done && data_done
				#  request			= if (getParseOption options) (http_parseArguments request) request
				# world				= debug "Processing request:" options world
				# world				= debug request	options world
				// Create a response
				# (response,world)	= http_makeResponse request handlers (getStaticOption options)world
				# world				= debug "Generated response:" options world
				# world				= debug response options world
				// Encode the response to the HTTP protocol format
				# (reply, world) = http_encodeResponse response True world
				// Send the encoded response to the client
				# (currentschannel,world) = send (toByteSeq reply) currentschannel world
				# world				= debug "Sent encoded reply:" options world
				# world				= debug reply options world
				// Close the connection
				# world = closeChannel currentschannel world
				# world = closeRChannel currentrchannel world
				# world				= debug "Closed connection" options world			
				= loop options handlers listener rchannels schannels requests world		
		
			//We do not have everything we need yet, so continue
			| otherwise = loop options handlers listener [currentrchannel:rchannels] [currentschannel:schannels] [(request,method_done, headers_done, data_done):requests] world
			
		//We lost the connection
		| otherwise
			# world = closeRChannel currentrchannel world
			# world = closeChannel currentschannel world
			= loop options handlers listener rchannels schannels requests world
where
	selectFromList nr list
		# (left,[element:right]) = splitAt nr list
		= (element,left++right)

getPortOption :: [HTTPServerOption] -> Int
getPortOption [] = 80
getPortOption [x:xs] = case x of (HTTPServerOptPort port)	= port
								 _							= getPortOption xs

getStaticOption :: [HTTPServerOption] -> Bool
getStaticOption [] = False
getStaticOption [x:xs] = case x of (HTTPServerOptStaticFallback b) = b
								   _							   = getStaticOption xs

getParseOption :: [HTTPServerOption] -> Bool
getParseOption [] = True
getParseOption [x:xs] = case x of (HTTPServerOptParseArguments b)	= b						
								  _									= getParseOption xs

getDebugOption :: [HTTPServerOption] -> Bool
getDebugOption [] = False
getDebugOption [x:xs] = case x of (HTTPServerOptDebug b)	= b
								  _							= getDebugOption xs
								  
debug:: a [HTTPServerOption] *World -> *World | toString a
debug msg options world
	| not (getDebugOption options)	= world
	# (sio, world)					= stdio world
	# sio							= fwrites ((toString msg) +++ "\n") sio
	= snd (fclose sio world)