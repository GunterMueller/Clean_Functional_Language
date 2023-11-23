implementation module httpSubServer
import StdEnv, Directory
import httpUtil
import code from "REGEXP.OBJ"
import code from "REGSUB.OBJ"
import code from "REGERROR.OBJ"
import code from "CFUNCLIB.OBJ"
import code from "SUBSERVER.OBJ", library "KERNEL32.TXT", library "USER32.TXT", library "WSOCK32.TXT"

RegisterSubProcToServer :: !Int !Int !Int !String !String -> Int;
RegisterSubProcToServer _ _ _ _ _ = code{
	ccall RegisterSubProcToServer "IIISS:I"
}

WaitForMessage :: (!Bool,!Socket,!String);
WaitForMessage  = code{
	ccall WaitForMessage ":VIIS"
}

RecvContent :: !Socket !String -> Bool;
RecvContent _ _ = code{
	ccall RecvContent "IS:I"
}

HTTPrecvC :: !Socket !String -> Int;
HTTPrecvC _ _ = code{
	ccall HTTPrecvC "IS:I"
}

MatchRegExpr :: !String -> Bool;
MatchRegExpr _ = code{
	ccall MatchRegExpr "S:I"
}

FreeSharedMem :: !Int !*env -> *env;
FreeSharedMem _ _ = code{
	ccall FreeSharedMem  "I:V:A"
}

SetContentLength :: !Int !*env -> *env;
SetContentLength _ _ = code{
	ccall SetContentLength  "I:V:A"
}

SendDataToClient :: !Socket !{#Char} !*env -> (!Socket,*env);
SendDataToClient 0 _ world = (0,world)
SendDataToClient socket data world
	# (_,world) = sendAPI socket data (size data) 0 world
	= (socket,world)
where
	sendAPI :: !Socket !{#Char} !Int !Int !*env -> (!Int,*env);
	sendAPI _ _ _ _ _ = code{
		ccall send@16 "PIsII:I:A"
	}

HTTPdisconnectGracefulC :: !Socket !*env -> *env;
HTTPdisconnectGracefulC _ _ = code{
	ccall HTTPdisconnectGracefulC  "I:V:A"
}

makeNewString :: !Int -> {#.Char}//function to allocate memory for a new string
makeNewString _ = code inline{
	create_array_ CHAR 0 1
}

ReadTotalHeaderFromSocket :: Int [String] Socket !*World -> ([String],Socket,*World)
ReadTotalHeaderFromSocket 0 header socket world//first line (example: GET / HTTP/1.0)
	# (newheaderline,socket,world) = ReadHeaderFromSocket socket world
	| socket==0 = ([],0,world)
	# (newheaderline,socket,world) = case newheaderline of//empty line is allowed at the beginning of a request -> RFC2616 section 4.1
		"\r\n" -> ReadHeaderFromSocket socket world
		_ -> (newheaderline,socket,world)
	| socket==0 = ([],0,world)
	# newheaderline = newheaderline % (0,size newheaderline - 3)//remove '\r\n' at the end of the line
	# (method,location,getDataArray,version) = GetFirstLine newheaderline
	| method=="" || location=="" || version=="" || version % (0,4)<>"HTTP/"//check correctness of the first line
		# (socket,world) = SendDataToClient socket "HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n" world
		# world = HTTPdisconnectGracefulC socket world
		= ([],0,world)
	| MatchRegExpr location//match the new location against the regular expression, no match means sending back to mainserver
		# (headerlist,socket,world) = ReadTotalHeaderFromSocket 1 (header++[newheaderline]) socket world
		| socket==0 = ([],0,world)
		# hostname = (GetHeaderData headerlist "HOST:")
		| hostname==""
			# (socket,world) = SendDataToClient socket "HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n" world
			# world = HTTPdisconnectGracefulC socket world
			= ([],0,world)
		# (socket,world) = SendDataToClient socket "HTTP/1.1 302 Found\r\nConnection: close\r\nLocation: http://" world
		# (socket,world) = SendDataToClient socket hostname world
		# (socket,world) = SendDataToClient socket location world
		# (socket,world) = SendDataToClient socket "\r\nContent-Type: text/plain\r\nContent-Length: 18\r\n\r\nSubserver Redirect" world//a little text is required when using a redirect -> RFC2616 section 10.3.2
		# world = HTTPdisconnectGracefulC socket world
		= ([],0,world)
	= ReadTotalHeaderFromSocket 1 (header++[newheaderline]) socket world
ReadTotalHeaderFromSocket 99 header socket world//reached maximum lines, must be an evil request
	= ([],0,HTTPdisconnectGracefulC socket world)
ReadTotalHeaderFromSocket linenumber header socket world
	# (newheaderline,socket,world) = ReadHeaderFromSocket socket world
	| newheaderline=="\r\n" || socket==0 = (header,socket,world)//stop reading header
	# newheaderline = newheaderline % (0,size newheaderline - 3)//remove '\r\n' at the end of the line
	= ReadTotalHeaderFromSocket (linenumber+1) (header++[newheaderline]) socket world

ReadHeaderFromSocket :: Socket !*World -> (String,Socket,*World)
ReadHeaderFromSocket socket world
	# (success,world) = ReadHeaderFromSocket` world
	| success = (data,socket,world)//reading header succeeded
	| otherwise = ("",0,HTTPdisconnectGracefulC socket world)//reading header failed
where
	data = makeNewString 4092//4092 = sizeof(a page in Windows) - sizeof(int), hope to increase some allocation speed this way
	ReadHeaderFromSocket` :: !*World -> (Bool,*World)
	ReadHeaderFromSocket` world
		# eorl = HTTPrecvC socket data//eorl = short for End Of Read Line
		| eorl==2 = (False,world)//line too long, or timeout
		| eorl==1 = (True,world)//reached the '\n'
		= ReadHeaderFromSocket` world//eorl=0, keep reading the line

WaitForMessageLoop :: ([String] Int Socket *World -> (Socket,*World)) Socket !*World -> *World
WaitForMessageLoop handlefunction 0 world
	#! (success,socket,header) = WaitForMessage
	| success
		#! headerlist = SplitToStringArray header "\r\n"
		#! world = FreeSharedMem 0 world//from this point, the same code as below, TODO: replace same code
		#! cl = toInt(GetHeaderData headerlist "CONTENT-LENGTH:")
		#! encoding = GetHeaderData headerlist "TRANSFER-ENCODING:"
		| cl==0 && encoding <> "" && encoding <> "chunked"//only chunked is required, otherwise send 501 Unimplemented -> RFC2616 section 3.6
			#! (socket,world) = SendDataToClient socket "HTTP/1.1 501 Unimplemented\r\nConnection: close\r\nContent-Type: text/plain\r\nContent-Length: 27\r\n\r\nOnly Chunked Is Implemented" world//a little text is required when using a 5xx error -> RFC2616 section 10.5
			= WaitForMessageLoop handlefunction 0 (HTTPdisconnectGracefulC socket world)
		#! cl = case encoding of
					"chunked" = -1//-1 represents the chunked mode in both the ReceiveString and the functions in C
					_ = cl
		#! world = SetContentLength cl world//remember the contentlength in C, so later we check on it to know if there is data on the socket
		#! (socket,world) = case (GetHeaderData headerlist "EXPECT:") of
						"100-continue" -> SendDataToClient socket "HTTP/1.1 100 Continue\r\n\r\n" world//a client could expect a 100 reply before sending the data -> RFC2616 section 8.2.3
						_ -> (socket,world)
		#! (socket,world) = handlefunction headerlist cl socket world
		= WaitForMessageLoop handlefunction socket world
	= world
WaitForMessageLoop handlefunction socket world
	#! (headerlist,socket,world) = ReadTotalHeaderFromSocket 0 [] socket world
	| socket==0 = WaitForMessageLoop handlefunction 0 world
	#! cl = toInt(GetHeaderData headerlist "CONTENT-LENGTH:")
	#! encoding = GetHeaderData headerlist "TRANSFER-ENCODING:"
	| cl==0 && encoding <> "" && encoding <> "chunked"//only chunked is required, otherwise send 501 Unimplemented -> RFC2616 section 3.6
		#! (socket,world) = SendDataToClient socket "HTTP/1.1 501 Unimplemented\r\nConnection: close\r\nContent-Type: text/plain\r\nContent-Length: 27\r\n\r\nOnly Chunked Is Implemented" world//a little text is required when using a 5xx error -> RFC2616 section 10.5
		= WaitForMessageLoop handlefunction 0 (HTTPdisconnectGracefulC socket world)
	#! cl = case encoding of
				"chunked" = -1
				_ = cl
	#! world = SetContentLength cl world//remember the contentlength in C, so later we check on it to know if there is data on the socket
	#! (socket,world) = case (GetHeaderData headerlist "EXPECT:") of
					"100-continue" -> SendDataToClient socket "HTTP/1.1 100 Continue\r\n\r\n" world//a client could expect a 100 reply before sending the data -> RFC2616 section 8.2.3
					_ -> (socket,world)
	#! (socket,world) = handlefunction headerlist cl socket world
	= WaitForMessageLoop handlefunction socket world

//gebruikers afhandelfunctie voor het verzenden van een bestand
SendFile :: String ![String] !Socket !*World -> (Socket,*World)
SendFile directory header sock world 
	# (method,location,getDataArray,version) = GetFirstLine (hd header)
	# location = directory +++ CheckLocation location
	| location==""
		# (sock,world) = SendDataToClient sock (version +++" 404 Not Found\r\nContent-Length: 0\r\n\r\n") world
		= DetectHttpVersionAndClose version (GetHeaderData header "Connection:") sock world
	# (ok,file,world) = fopen location FReadData world//probeer bestand te openen
	| not ok 
		# (sock,world) = SendDataToClient sock (version +++" 404 Not Found\r\nContent-Length: 0\r\n\r\n") world
		= DetectHttpVersionAndClose version (GetHeaderData header "Connection:") sock world
	# ((_,path),world)=	pd_StringToPath location world
	# ((error,info),world)= getFileInfo path world
	# {pi_fileInfo=piinfo}=info
	# {fileSize=sizeFile}=piinfo
	# string = GetHeaderData header "Content-Range:"
	| string<>"" 
		# first = FindIndexInString string "-" 0
		# firstPoint = toInt(string % (6,first-1))
		# tmp = string % (first+1,size string)
		# second = FindIndexInString tmp "/" 0
		# secondPoint = toInt(tmp % (0,second-1))
		# thirdPoint = toInt(tmp % (second+1,size tmp))
		| first==(-1) || second ==(-1) || firstPoint >= secondPoint || secondPoint > thirdPoint || secondPoint > (fst sizeFile)
			# (sock,world) = SendDataToClient sock "HTTP/1.0 400 Bad Request\r\nContent-Length: 0\r\n\r\n" world
			= DetectHttpVersionAndClose version (GetHeaderData header "Connection:") sock world
		# (ok,file) = fseek file firstPoint FSeekSet
		| not ok
			# (sock,world) = SendDataToClient sock (version+++" 501 Internal Server Error\r\nContent-Length: 0\r\n\r\n") world
			# (_,world) = fclose file world	
			= DetectHttpVersionAndClose version (GetHeaderData header "Connection:") sock world
		# (sock,world) = SendDataToClient sock (version+++" 206 Partial content\r\n") world
		# (sock,world) = SendDataToClient sock ("Content-Range: "+++string+++"\r\n") world
		# contentType= getContentTypeGF (location % ((FindIndexInString location "." 0),size location))
		# (sock,world) = SendDataToClient sock ("Content-Length: "+++toString(secondPoint-firstPoint)) world
		# (sock,world) = SendDataToClient sock ("\r\nAccept-Ranges: bytes\r\n\r\n") world
		| method<>"HEAD"
			# (sock,file,world) = SendFile` (secondPoint-firstPoint) sock file world
			# (_,world) = fclose file world
			= DetectHttpVersionAndClose version (GetHeaderData header "Connection:") sock world
		# (_,world) = fclose file world
		= DetectHttpVersionAndClose version (GetHeaderData header "Connection:") sock world
	# contentType= getContentTypeGF (location % ((FindIndexInString location "." 0),size location))
	# (sock,world) = SendDataToClient sock (version+++" 200 OK\r\n") world
	# (sock,world) = SendDataToClient sock ("Content-Type: "+++contentType+++"\r\n") world
	# (sock,world) = SendDataToClient sock ("Content-Length: "+++(toString (fst sizeFile))+++"\r\n\r\n") world
	| method<>"HEAD"
		# (sock,file,world) = SendFile` (fst sizeFile) sock file world
		# (_,world) = fclose file world
		= DetectHttpVersionAndClose version (GetHeaderData header "Connection:") sock world
	# (_,world) = fclose file world
	= DetectHttpVersionAndClose version (GetHeaderData header "Connection:") sock world

SendFile` :: !Int !Socket !*File !*World-> (Socket,*File,*World)//functie die alle gegevens uit een bestand leest
SendFile` bytes sock file world
	# read = case (bytes>4096) of
		True = 4096
		_ = bytes
	# (data,file) = freads file read
	# (sock,world)= SendDataToClient sock data world
	| (bytes-read)==0 = (sock,file,world)
	= SendFile` (bytes-read) sock file world

DetectHttpVersionAndClose :: !String !String !Socket !*World -> (Socket,*World)
DetectHttpVersionAndClose version connection sock world
	| version=="HTTP/1.0" = (0,HTTPdisconnectGracefulC sock world)
	| connection == "close" = (0,HTTPdisconnectGracefulC sock world)
	= (sock,world)
	
SendString :: !String !String ![String] !Socket !*World -> (Socket,*World)
SendString _ _ _ 0 world = (0,world)//called function with a closed socket
SendString str contenttype requestheader sock world
	# (method,location,getDataArray,version) = GetFirstLine (hd requestheader)
	# (sock,world) = case version of//does not exist in the other SendString function
					"HTTP/1.0" -> SendDataToClient sock "HTTP/1.0" world//does not exist in the other SendString function
					_ -> SendDataToClient sock "HTTP/1.1" world//does not exist in the other SendString function
	| method<>"GET" && method<>"HEAD" && method<>"POST"
		# (sock,world) = SendDataToClient sock " 405 Method Not Allowed\r\nAllow: GET, HEAD, POST\r\nConnection: close\r\n\r\n" world//an Allow-field must be present with a 405 error -> RFC2616 section 14.7
		= (0,HTTPdisconnectGracefulC sock world)//does not exist in the other SendString function
	# (sock,world) = SendDataToClient sock " 200 OK\r\nContent-Type: " world
	# (sock,world) = SendDataToClient sock contenttype world
	# (sock,world) = SendDataToClient sock "\r\nContent-Length: " world
	# strsize = (toString (size str))
	# (sock,world) = SendDataToClient sock strsize world
	# (sock,world) = SendDataToClient sock "\r\n\r\n" world
	# (sock,world) = case method of
					"HEAD" -> (sock,world)
					_ -> SendDataToClient sock str world
	= DetectHttpVersionAndClose version (GetHeaderData requestheader "CONNECTION:") sock world

ReadChunkSize :: !Socket !*World -> (Int,Socket,*World)
ReadChunkSize sock world
	# (data,sock,world) = ReadHeaderFromSocket sock world
	= (HexLineToInt (fromString (data % (0,size data - 3))),sock,world)

ReadChunkData :: !Int !Socket !*World -> (String,Socket,*World)
ReadChunkData 0 sock world = ("",sock,world)//reached the end of the chunked data
ReadChunkData _ 0 world = ("",0,world)//function called with a closed socket
ReadChunkData chunksize sock world
	# world = SetContentLength chunksize world//set to the actuall size, so RecvContent (in C) won't get stuck on it
	# (_,chunkdata,sock,world) = ReceiveString chunksize 1 sock world
	# world = SetContentLength 0 world//set to 0, so ReadHeaderFromSocket won't get stuck on it
	# (_,sock,world) = ReadHeaderFromSocket sock world//read an empty line
	# (chunksize,sock,world) = ReadChunkSize sock world
	# (newchunkdata,sock,world) = ReadChunkData chunksize sock world
	= (chunkdata+++newchunkdata,sock,world)//WARNING: possibly creating giga-strings here

ReceiveString :: !Int !Int !Socket !*World -> (Int,String,Socket,*World)
ReceiveString _ _ 0 world = (-1,"",0,world)//function called with a closed socket
ReceiveString _ 0 sock world = (-1,"",sock,world)//contentlength was zero no data downloaded
ReceiveString _ -1 sock world//-1 means that 'Transfer-Encoding: chunked' is used, chunked is required for all 1.1 apps -> RFC2616 section 3.6.1
	# world = SetContentLength 0 world//set to 0, so ReceiveString won't get stuck on it
	# (chunksize,sock,world) = ReadChunkSize sock world
	# (allchunkdata,sock,world) = ReadChunkData chunksize sock world
	| sock==0 = (0,"",0,HTTPdisconnectGracefulC sock world)//stop reading content
	# world = SetContentLength -1 world//the ReceiveString messes up the contentlength in C, so set it back
	= (0,allchunkdata,sock,world)
ReceiveString expectedlength contentlength sock world
	# expectedlength = case expectedlength of
						0 -> contentlength//autodetect expected length
						_ -> expectedlength
	# data = makeNewString expectedlength
	| RecvContent sock data = (0,"",0,world)//timed-out or disconnected, close was already done in the RecvContent-function
	| expectedlength < contentlength = (contentlength-expectedlength,data,sock,world)
	= (0,data,sock,world)

ReceiveFile :: !Int !Socket !*File !*World -> (Bool,*File,*World)
ReceiveFile _ 0 file world = (False,file,world)//called with closed socket
ReceiveFile 0 _ file world = (True,file,world)//called with a contentlength of zero or reached the end of the data
ReceiveFile contentlength socket file world
	# (alldatareceived,data,socket,world) = ReceiveString 4096 contentlength socket world
	# file = fwrites data file
	= ReceiveFile alldatareceived socket file world