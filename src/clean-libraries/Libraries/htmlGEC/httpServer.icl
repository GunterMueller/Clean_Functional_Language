implementation module httpServer

import StdEnv,StdTCP

from httpUtil import unlines, cSplit, endWith, splitAfter, wordsWith, unwords, readFile

from  htmlSettings import DEBUGSERVER

(<<?) file s 
	= case DEBUGSERVER of
		True	= file <<< s <<< "\n" 
		False	= file


printArguments :: Arguments -> String
printArguments args
	= unwords ["(" +++ f +++ "," +++ v +++ ")" \\ (f,v) <- args]
	
// De belangrijkste functie om waarden van formulieren te achterhalen:
// Bijvoorbeeld: getArgValue "sort" zal de waarde van pulldown menu 'sort' achterhalen.
// Indien het argument niet voor komt dan wordt de lege string terug gegeven.
getArgValue :: String Arguments -> String
getArgValue a arguments
	= hd ([v \\ (f,v) <- arguments | f == a] ++ [""])

//functie die de HTTP-server start
StartServer :: Int [(String,(String String Arguments *World-> ([String],String,*World)))] *World -> *World
StartServer poortNr linktofunctionlist world
	// open console voor debuggen:
	# (console,world) 	= stdio world
	# console			= fwrites "Open your favorite browser and surf to http://localhost/clean\n" console


	//luister op de opgegeven poort:
	# (listen,world) = listenOnPort poortNr world
	
	//en ga de eindeloze lus in:
	= loop linktofunctionlist listen [] [] [] console world

// eindeloze lus-functie, elke keer als er een nieuwe client verbind of gegevens beschikbaar zijn,
// wordt deze functie opnieuw aangeroepen.
loop :: [(String,(String String Arguments *World-> ([String],String,*World)))] TCP_Listener [TCP_RChannel] [TCP_SChannel] [[String]] !*File *World -> *World
loop linktofunctionlist listen rchannels schannels httpheaders console world
	# console = console <<? "waiting" //TESTING ONLY
	
	//plak de twee luisterlijsten aan elkaar:
	# glue = (TCP_Listeners [listen]) :^: (TCP_RChannels rchannels)
	
	//selecteer het kanaal waarop iets beschikbaar is:
	# ([(who,what):_],glue,_,world) = selectChannel_MT Nothing glue Void world
	
	//de twee luisterlijsten weer uit elkaar halen:
	# ((TCP_Listeners [listen:_]) :^: (TCP_RChannels rchannels)) = glue
	
	//nieuwe client wil verbinden:
	| who==0
		# (tReport,mbNewMember,listen,world) = receive_MT (Just 0) listen world
		| tReport<>TR_Success = loop linktofunctionlist listen rchannels schannels httpheaders console world//foutje, bedankt
		# (_,{sChannel,rChannel}) = fromJust mbNewMember
		# (ipnr,{sChannel,rChannel}) = fromJust mbNewMember//TESTING ONLY for if you want to know the IP-number
		# console = console <<? ("connected: "+++toString ipnr)//TESTING ONLY
		= loop linktofunctionlist listen [rChannel:rchannels] [sChannel:schannels] [[""]:httpheaders] console world//gelukt, er is nu een cient bijgekomen
		
	// Een client heeft nieuwe gegevens:
	| otherwise
		// echt lijstnummer zit 1 onder het nummer wat hier gebruikt wordt (want de onderste was degene waar nieuwe cients op verbinden)
		# who = who-1
		// selecteer juiste client om mee verder te gaan (ontvangkanaal):
		# (currentrchannel,rchannels) = selectFromList who rchannels
		// selecteer juiste client om mee verder te gaan (verstuurkanaal):
		# (currentschannel,schannels) = selectFromList who schannels
		// selecteer juiste reeds ontvangen gegevens van client om mee verder te gaan:
		# (currenthttpheader,httpheaders) = selectFromList who httpheaders
		
		// gegevens zijn beschikbaar:
		| what==SR_Available
			# (data,currentrchannel,world) = receive currentrchannel world//ontvang gegevens
			# console = console <<? ( "data downloaded:\n" +++ toString data) //TESTING ONLY

			//ontvangen gegevens toevoegen aan de reeds ontvangen gegevens van die client:
			# currenthttpheader = addHeaders (init currenthttpheader) (fromString ((last currenthttpheader) +++ (toString data)))
			
			// Client gebruikt incorrecte methode in de header:
			| isWrongMethod (hd currenthttpheader)
				# console = console <<? ("wrong method:\n\n" +++ hd currenthttpheader)//TESTING ONLY
				//foute methode of gewoon rotzooi, verbreek met client:
				# (currentschannel,world) = send (toByteSeq "HTTP/1.0 400 Bad Request\r\n\r\n") currentschannel world
				# world = closeRChannel currentrchannel world
				# world = closeChannel currentschannel world
				# console = console <<? "channels closed"//TESTING ONLY
				// client zit niet meer in de lijst:
				= loop linktofunctionlist listen rchannels schannels httpheaders console world
				
			// alle HTTP-headers zijn ontvangen:
			| hasAllHTTPHeaders currenthttpheader
				# console = console <<? "all HTTP-headers received"//TESTING ONLY
				# contentlength = getContentLength currenthttpheader
				# console = console <<? ("content-length:"+++toString contentlength+++"\nreceived data:"+++toString (size (last currenthttpheader)))//TESTING ONLY
				// client heeft alles goed gestuurd en wacht op antwoord:
				| contentlength==0 || contentlength<=size (last currenthttpheader) // bug repaired 3/12/2005 MJP
					// vraag methode en opgevraagde locatie op:
					# (method,location) = getMethodAndLocation (hd currenthttpheader)
					
					// genereer gegevens voor de client via een andere functie:
					# (bs,world) = makeReturnData location linktofunctionlist method (tl currenthttpheader) world

					# console = console <<? (unlines [method,location])//TESTING ONLY
					
					// stuur gegevens naar client en verbreek verbinding:
					# (currentschannel,world) = send bs currentschannel world
					# world = closeRChannel currentrchannel world
					# world = closeChannel currentschannel world
					# console = console <<? "channels closed" //TESTING ONLY
					
					//client is klaar en verbroken, dus niet meer in lijst zetten:
					= loop linktofunctionlist listen rchannels schannels httpheaders console world
					
				//client wil gegevens sturen (bijv. via POST uit een formulier), maar heeft dat nog niet gedaan, dus doorgaan met deze client
				| otherwise = loop linktofunctionlist listen [currentrchannel:rchannels] [currentschannel:schannels] [currenthttpheader:httpheaders] console world
				
			//client heeft nog niet alles verstuurd, maar is wel in HTTP-formaat bezig, dus doorgaan met deze client
			| otherwise = loop linktofunctionlist listen [currentrchannel:rchannels] [currentschannel:schannels] [currenthttpheader:httpheaders] console world
			
		//client verbrak verbinding (of viel weg), dus verbreek verbinding met client:
		| otherwise
			# console = console <<?  "user closed" //TESTING ONLY
			# world = closeRChannel currentrchannel world
			# world = closeChannel currentschannel world
			# console = console <<?  "channels closed"//TESTING ONLY
			= loop linktofunctionlist listen rchannels schannels httpheaders console world//client zit niet meer in de lijst

//functie die een element selecteert, zodat je daarmee verder kunt werken
//selectFromList :: !Int [.a] -> (!.a,![.a])
selectFromList nr list
	# (left,[element:right]) = splitAt nr list
	= (element,left++right)

//functie die probeert te luisteren op poort 80:
listenOnPort :: Int !*World -> (TCP_Listener,!*World)
listenOnPort port world
	# (ok,mbListener,world) = openTCP_Listener port world//probeer te luisteren, of het lukt komt in ok-variabele
	| ok = (fromJust mbListener,world)//gelukt
	| otherwise = abort "Poort bezet!"//niet gelukt

// functie die de Content-Length teruggeeft:
getContentLength :: [String] -> Int
getContentLength [str:rest]
 | (str % (0,15)) == "Content-Length: " = toInt (str % (16,99))
 | (str % (0,14)) == "Content-Length:" = toInt (str % (15,99))
 | otherwise = getContentLength rest
getContentLength _ = 0

//functie die gegevens bij de reeds ontvangen headers toevoegt:
addHeaders :: [String] [Char] -> [String]
addHeaders headers ca
 | isMember "" headers = headers ++ [toString ca]
 | otherwise
  # (newheader,rest,bool) = addHeaders` ca
  # headers = headers ++ [newheader]
  | rest==[]
   | bool = headers
   | otherwise = headers ++ [""]
  | otherwise = addHeaders headers rest
where
   addHeaders` :: [Char] -> (String,[Char],Bool)
   addHeaders` c
    | index == length c = (toString c,[],True)
    | otherwise = (toString (take index c),drop (index+2) c,False)
   where index = findCRLF 0 c

findCRLF :: Int [Char] -> Int//zoek naar positie van de eerste CFLF
findCRLF nr ['\r\n':rest] = nr
findCRLF nr [b:r] = findCRLF (nr+1) r
findCRLF nr _ = nr

isWrongMethod :: String -> Bool//functie die controleert of de methode (die de client stuurt) wel goed is volgens HTTP/1.0
isWrongMethod str
	| (str % (5,5)) == ""  	= False		// ??
	| (str % (0,4)) == "GET /" = False
	| (str % (0,5)) == "POST /" = False
	| (str % (0,5)) == "HEAD /" = False
	| otherwise = True

hasAllHTTPHeaders :: [String] -> Bool//functie die controleert of alle HTTP-headers binnen zijn
hasAllHTTPHeaders ["",_] = True
hasAllHTTPHeaders [_:rest] = hasAllHTTPHeaders rest
hasAllHTTPHeaders _ = False

getMethodAndLocation :: String -> (String,String)//functie die methode en opgegeven locatie teruggeeft
getMethodAndLocation request
	# (method, locationVersion)	= cSplit ' ' request
	# (location, version)		= cSplit ' ' locationVersion
	= (method, (toString o removeEscapes o fromString) location)

//URLDecode-functie (zet %?? om naar juiste characters, %20 naar spatie bijv.)
removeEscapes :: [Char] -> [Char]
removeEscapes [] = []
removeEscapes ['%',a,b:tail] = [(toChar (16 * toInt (hexToChar a))) + hexToChar b : removeEscapes tail] 
removeEscapes [head:tail] = [head : removeEscapes tail]

//functie is onderdeel van removeEscapes
hexToChar :: Char -> Char
hexToChar a
	| a >= '0' && a <= '9' = a - '0'
	| a >= 'A' && a <= 'F' = a - 'A' + (toChar 10)
	| a >= 'a' && a <= 'f' = a - 'a' + (toChar 10)
	= toChar 0


makeArguments :: String -> Arguments
makeArguments input = map makeArg (wordsWith '&' input)
where
	makeArg s			= cSplit '=' s

//functie die de functie van de gebruiker aanroept en zorgt voor HTTP-opmaak die meteen verstuurd kan worden:
makeReturnData :: String [(String,(String String Arguments *World-> ([String],String,*World)))] String [String] *World-> (ByteSeq,*World)
makeReturnData str linktofunctionlist method overigeHeaders world
	= activatedFunction (splitLink str) linktofunctionlist
where
	activatedFunction (link,locationName) [(as,function):bs]
		| (link == as)
			# (location, getHeader)		= cSplit '?' locationName
			# (replyheaders,data,world)	= function method location (makeArguments getHeader) world
			= (makeHttpReply (replyheaders,data) method,world)
			
		| otherwise
			= activatedFunction (link,locationName) bs
	where
		makeArguments getHeader
							= map makeArg getAndPost
		where
			lastHeader			= last overigeHeaders
			postHeader			= (lastHeader % (0,size lastHeader - 3))
			
			getAndPost			=	wordsWith '&' getHeader 
								++	wordsWith '&' postHeader
								
			makeArg s			= (f, v) //(f, withWhiteSpace v)
						where
								(f,v) = cSplit '=' s

	activatedFunction (link,locationName) _
		# (location, getHeader)		= cSplit '?' locationName
		# (replyheaders,data,world)	= readLocalFile (link+++location) world
		//= abort ("\n\nniet herkent:\n\t" +++ link +++ "\n\t" +++ location) 
		= (makeHttpReply (replyheaders,data) method,world)
	where
		readLocalFile localFile world	
		//probeer bestand te openen:		
		# (ok,file,world) = fopen localFile FReadData world
	
		//indien openen niet lukt: 404-fout:
		| not ok = (["HTTP/1.0 404 Not Found"],localFile,world)
		
		//indien openen wel lukt, lees alle gegevens uit bestand:
		# (data,file) = readFile file
		
		//sluit bestand:
		# (_,world) = fclose file world
		
		//stuur bestand terug naar gebruiker met juiste Content-Type:
		= (["HTTP/1.0 200 OK","Content-Type: " +++ getContentType localFile],data,world)


// Functie die Content-Type genereert aan de hand van de extensie:
getContentType :: String -> String
getContentType ".jpg" = "image/jpeg"
getContentType ".gif" = "image/gif"
getContentType ".bmp" = "image/x-ms-bmp"
getContentType ".htm" = "text/html"
getContentType ".html" = "text/html"
getContentType ".txt" = "text/plain"

//forceer download bij andere extensies (bij video's bijv., zodat deze niet meteen worden afgespeeld):
getContentType "" = "application/octet-stream\r\nContent-Disposition: attachment;"
getContentType str = getContentType (str % (1,size str))



// functies die naar MyUtil moeten:

/*
// witruimte in parameters bestaande uit losse woorden zal worden omgezet in andere karakters
// en kan m.b.v. onderstaande functie weer achterhaald worden.
withWhiteSpace :: String -> String
withWhiteSpace s = {toWhiteSpace c \\ c <-: s }

noWhiteSpace :: a -> String | toString a
noWhiteSpace s = {fromWhiteSpace c \\ c <-: ss }
where
	ss :: String
	ss = toString s

toWhiteSpace :: Char -> Char
toWhiteSpace '\030'	= '\n'	// record separator
toWhiteSpace '\031'	= ' '	// unit separator
toWhiteSpace c 		= c

fromWhiteSpace :: Char -> Char
fromWhiteSpace '\n'	= '\030'	// record separator
fromWhiteSpace ' '	= '\031'	// unit separator
fromWhiteSpace c 	= c
*/

//deze functie splits het adres, 1e helft geeft de link waarop functie luisterd terug, 2e helft is de link data
splitLink :: String -> (String, String)
splitLink s
	=  splitAfter '/' (s % (1, size s-1))


//deze functie zet de data om naar een byteseq, waarbij de data een reply actie is:
makeHttpReply :: ([String],String) String-> ByteSeq
// default is de content type html:
makeHttpReply ([],data) method 
	= makeHttpReply (["HTTP/1.0 200 OK","Content-Type: text/html"],data) method
	
makeHttpReply (headers,data) method
	| (hd headers == "HTTP/1.0 200 OK" || hd headers == "HTTP/1.1 401 Unauthorized")
		= (toByteSeq	(   endWith "\r\n" headers
						+++ "Content-Length: "
						+++ toString (size data)
						+++ "\r\n\r\n"+++checkHead method data))
	| otherwise
		= toByteSeq		(   endWith "\r\n" headers 
						+++ "\r\n"
						)

//functie die controleert of methode HEAD is en dan geen gegevens terugstuurt, anders wel:
checkHead :: String String -> String
checkHead method data
	| (method == "HEAD") = ""
	| otherwise = data


