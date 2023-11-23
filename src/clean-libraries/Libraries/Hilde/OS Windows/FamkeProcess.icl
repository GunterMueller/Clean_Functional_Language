implementation module FamkeProcess

import FamkeKernel
import FamkeRpc, LoesListSeq, LoesKeyList, FamkeTcpIp, StdException
import StdBool, StdInt, StdMisc, StdString, StdList, StdArray, StdTuple, ArgEnv, Windows
from DynamicLinkerInterface import GetDynamicLinkerPath

TRACE msg x :== trace_n msg x; import StdDebug

:: ProcessIp :== Int
:: ProcessNr :== Int

:: ProtocolIn
	= ClientWorkRequest !ProcessNr !Int
	| ClientException !ProcessNr !Int
	| NewProcess Process
	| ReuseProcess !ProcessNr Process
	| JoinProcess !ProcessId !ProcessNr
	| KillProcess !ProcessId !ProcessNr
	| Shutdown
	| ReservePort
	| FreePort !Int

:: ProtocolOut
	= ClientDoMoreWork Process
	| ClientNoMoreWork
	| ProcessCreated !ProcessNr
	| ProcessReused
	| ProcessJoined
	| ProcessKilled
	| ShuttingDown
	| PortReserved !Int
	| PortFreed

processId :: !*World -> (!ProcessId, !*World)
processId famke 
	# (_, ip, famke) = localhostIp famke
	= ({processIp = ip, processNr = cast famke}, cast famke)
where
	cast :: !.a -> .b
	cast _ = code inline {
			pop_a	0
		}

newProcess :: !(*World -> *World) !*World -> (!ProcessId, !*World)
newProcess process famke = newProcessAt "localhost" process famke

newProcessAt :: !String !(*World -> *World) !*World -> (!ProcessId, !*World)
newProcessAt host process famke
	# (ok, ip, famke) = resolveTcpIp host famke
	| not ok = newProcess process famke
	# (ProcessCreated nr, famke) = rpcProcessServer ip (NewProcess process) famke
	= ({processIp = ip, processNr = nr}, famke)

reuseProcess :: !ProcessId !(*World -> *World) !*World -> *World
reuseProcess {processIp, processNr} process famke
	# (reply, famke) = rpcProcessServer processIp (ReuseProcess processNr process) famke
	= case reply of ProcessReused -> famke

joinProcess :: !ProcessId !*World -> *World
joinProcess {processIp, processNr} famke
	# (self, famke) = processId famke
	  (reply, famke) = rpcProcessServer processIp (JoinProcess self processNr) famke
	= case reply of ProcessJoined -> famke

killProcess :: !ProcessId !*World -> *World
killProcess {processIp, processNr} famke
	# (self, famke) = processId famke
	  (reply, famke) = rpcProcessServer processIp (KillProcess self processNr) famke
	= case reply of ProcessKilled -> famke

shutdown :: !*World -> *World
shutdown famke
	# (_, ip, famke) = localhostIp famke
	  (reply, famke) = rpcProcessServer ip Shutdown famke
	= case reply of ShuttingDown -> famke

reservePort :: !*World -> (!FamkePort .a .b, !*World)
reservePort famke
	# (_, ip, famke) = localhostIp famke
	  (reply, famke) = rpcProcessServer ip ReservePort famke
	= case reply of PortReserved p -> (FamkeServer ip p, famke)

freePort :: !(FamkePort .a .b) !*World -> *World
freePort (FamkeServer _ famkePort) famke
	# (_, ip, famke) = localhostIp famke
	  (reply, famke) = rpcProcessServer ip (FreePort famkePort) famke
	= case reply of PortFreed -> famke

rpcProcessServer :: !ProcessIp !ProtocolIn !*World -> (!ProtocolOut, !*World)
rpcProcessServer ip request famke = rpc (FamkeProcessServer ip) request famke

:: Process :== *World -> *World

:: *State =
	{	working		:: !.KeyList ProcessNr .Working
	,	waiting		:: !.[#.Waiting!]
	,	nextid		:: !ProcessNr
	,	executable	:: !String
	,	server		:: !.RpcServer ProtocolIn ProtocolOut
	,	famke		:: !.World
	,	ports		:: !.[#Int]
	}

:: WorkingState = NotConnected | Connected !Int | Disconnect

:: Working = 
	{	workingWork		:: !.[Process!]
	,	workingJoin		:: !.[#.Join!]
	,	workingId		:: !ProcessNr
	,	workingState	:: !WorkingState
	}

:: Join =
	{	joinId		:: !ProcessId
	,	joinReply	:: !.(ProtocolOut -> *(*World -> *World))
	}

:: Waiting =
	{	waitingReply	:: !.(ProtocolOut -> *(*World -> *World))
	,	waitingWorking	:: !.Working
	}

startProcessServer :: !String !(*World -> *World) !*World -> *World
startProcessServer executable process famke
	# (_, ip, famke) = localhostIp famke
	  (_, server, famke) = rpcOpen (FamkeProcessServer ip) (TRACE "Famke Process Server" famke)
	  st = {working = Empty, waiting = Empty, nextid = 1, executable = executable, server = server, famke = famke, ports = [#0xFA01..0xFAFF]}
	  {server, famke} = newProcess` process (\_ famke -> famke) st
	= rpcClose server famke
where
	processServer st=:{working, waiting, server, famke}
	  	# (done, working) = uIsEmpty working
		| done  
			# famke = Fold (endWaitingClient 0) famke waiting
			= TRACE ("All clients idle, shutting down") {st & working = working, waiting = Empty, famke = famke}
		# (request, reply, server, famke) = rpcWait server famke
		  st = {st & working = working, server = server, famke = famke}
		= case request of
			ClientWorkRequest self osId -> clientWorkRequest self osId reply st
			ClientException self osId -> clientException self osId reply st
			NewProcess process -> newProcess` process reply st
			ReuseProcess id process -> renewProcess` id process reply st
			JoinProcess self id -> joinProcess` self id reply st
			KillProcess self id -> killProcess` self id reply st
			Shutdown -> shutdown` reply st
			ReservePort -> reservePort` reply st
			FreePort p -> freePort` p reply st

	clientWorkRequest self osId reply st=:{working, waiting, famke}
		# (maybe, working) = uExtractK self working
		= case maybe of
			Just w=:{workingWork, workingJoin, workingState}
				# famke = Foldr (joinClient self) famke workingJoin
				-> case workingState of
					Disconnect
						# w = {w & workingJoin=Empty} // JvG: prevent uniqueness error caused by use of unique workingJoin in Foldr
						-> processServer {st & working = working, famke = endWaitingClient 0 {waitingReply = reply, waitingWorking=w} famke}
					_
						# (maybe, workingWork) = uDeCons workingWork
						  w = {w & workingWork = workingWork, workingJoin = Empty, workingState = Connected osId}
						-> case maybe of
							Just process
								# famke = reply (ClientDoMoreWork process) famke
								  working = uInsertK self w working
								-> TRACE ("Process client " +++ toString self +++ " put to work") (processServer {st & working = working, famke = famke})
							_
						  		# waiting = uSnoc waiting {waitingReply = reply, waitingWorking = w}
						  		-> TRACE ("Process client " +++ toString self +++ " idle") (processServer {st & working = working, waiting = waiting, famke = famke})
	  		_ -> TRACE ("Process client " +++ toString self +++ " does not exist") (processServer {st & working = working, famke = famke})
		
	clientException self osId reply st=:{working}
		# (_, working) = uExtractK self working
		  st=:{famke} = TRACE ("Process client " +++ toString self +++ " had an exception") {st & working = working}
		  famke = reply ClientNoMoreWork famke
		= processServer {st & famke = famke}
	
	newProcess` process reply st=:{working, waiting, nextid} 
		# (maybe, waiting) = uDeCons waiting
		  (id, st=:{famke}) = case maybe of
								Just client -> reuseClient client process {st & waiting = waiting}
								_ -> (nextid, launchClient nextid process {st & waiting = waiting, nextid = nextid + 1})
		  famke = reply (ProcessCreated id) famke
		= processServer {st & famke = famke}
	
	renewProcess` id process reply st=:{working, waiting} 
		# (maybe, working) = uExtractK id working
		  st=:{famke} = case maybe of
							Just w=:{workingWork}
								# working = uInsertK id {w & workingWork = uSnoc workingWork process} working
								-> {st & working = working}
							_
								# (maybe, waiting) = extractWaiting id waiting
								  st = {st & working = working, waiting = waiting}
								-> case maybe of
									Just client -> snd (reuseClient client process st)
									_ -> launchClient id process st
		  famke = reply ProcessReused famke
		= processServer {st & famke = famke}
	
	joinProcess` self nr reply st=:{working, famke}
		# (_, ip, famke) = localhostIp famke
		  (maybe, working) = uExtractK nr working
		= case maybe of
			Just w=:{workingJoin} | self <> {processIp = ip, processNr = nr}
				# working = uInsertK nr {w & workingJoin = uCons {joinId = self, joinReply = reply} workingJoin} working
				-> TRACE ("Process client " +++ toString self +++ " waiting to join " +++ toString nr)
					(processServer {st & working = working, famke=famke /* JvG: added update of famke to fix uniqueness error */})
			_
				# famke = reply ProcessJoined famke
				-> TRACE ("Process client " +++ toString self +++ " joined " +++ toString nr) (processServer {st & working = working, famke = famke})
	
	killProcess` self nr reply st=:{working, famke}
		# (_, ip, famke) = localhostIp famke
		  (maybe, working) = uExtractK nr working
		  st=:{waiting, famke} = TRACE ("Process client " +++ toString self +++ " wants " +++ toString nr +++ " killed") {st & working = working, famke = famke}
		= case maybe of
			Just client
				# st=:{famke} = endWorkingClient self client st
				  famke = if (self <> {processIp = ip, processNr = nr}) (reply ProcessKilled famke) famke
				-> processServer {st & famke = famke}
			_
				# (maybe, waiting) = extractWaiting nr waiting
				  famke = case maybe of
							Just client -> endWaitingClient self client famke
							_ -> famke
				  famke = reply ProcessKilled famke
				-> processServer {st & waiting = waiting, famke = famke}
	
	shutdown` reply st=:{working, waiting, famke}
		# (_, ip, famke) = localhostIp famke
		  famke = Fold (endWaitingClient {processIp = ip, processNr = 0}) famke waiting
		  st = Fold (endWorkingClient {processIp = ip, processNr = 0}) {st & working = Empty, waiting = Empty, famke = famke} working
		= TRACE "Process server starts killing all clients" (processServer st)

	launchClient nr process st=:{executable, working, famke}
		# (ok, famke) = launchExecutable executable [toString nr] famke
		| not ok = abort "launchExecutable failed"
		# working = uInsertK nr {workingWork = uCons process Empty, workingJoin = Empty, workingId = nr, workingState = NotConnected} working
		= TRACE ("Process client " +++ toString nr +++ " launched") {st & working = working, famke = famke}
	
	reuseClient {waitingReply, waitingWorking=waitingWorking=:{workingId}} process st=:{working, famke}
		# famke = waitingReply (ClientDoMoreWork process) famke
		  working = uInsertK workingId waitingWorking working
		= TRACE ("Process client " +++ toString workingId +++ " reused") (workingId, {st & working = working, famke = famke})
	
	joinClient self {joinId, joinReply} famke = joinReply ProcessJoined (TRACE ("Process client " +++ toString joinId +++ " joined " +++ toString self) famke)
	
	endWaitingClient self {waitingReply, waitingWorking={workingId}} famke
		# famke = waitingReply ClientNoMoreWork famke
		= TRACE ("Process client " +++ toString self +++ " ended " +++ toString workingId +++ ", which was idle") famke

	endWorkingClient self w=:{workingJoin, workingId, workingState} st=:{working, famke}
		= case workingState of
			Connected osId
				# (ok, handle, famke) = OpenProcess PROCESS_TERMINATE False osId famke
				| not ok -> abort "OpenProcess failed"
				# (ok, famke) = TerminateProcess handle 0 famke
				| not ok -> abort "TerminateProcess failed"
				# famke = if (self.processNr <> 0) (Foldr (joinClient self) famke workingJoin) famke
				-> TRACE ("Process client " +++ toString self +++ " ended (killed) " +++ toString workingId) {st & famke = famke}
			_ -> {st & working = uInsertK workingId {w & workingState = Disconnect} working}

	extractWaiting id xs 
		# (maybe, xs) = uDeCons xs
		= case maybe of
			Just x=:{waitingWorking={workingId}}
				| workingId == id -> (Just x, xs)
				# (maybe, xs) = extractWaiting id xs
				-> (maybe, uCons x xs)
			_ -> (Nothing, xs)

	reservePort` reply st=:{ports=[|p:ports], famke}
		# famke = reply (PortReserved p) famke
		  st = {st & ports = ports, famke = famke}
		= TRACE ("Process reserved port " +++ toString p) (processServer st)

	freePort` p reply st=:{ports, famke}
		# famke = reply PortFreed famke
		  st = {st & ports = [|p:ports], famke = famke}
		= TRACE ("Process freed port " +++ toString p) (processServer st)

startProcessClient :: !*World -> *World
startProcessClient famke
	# (id, famke) = processId famke
	  (osId, famke) = GetCurrentProcessId famke
	= processClient id osId famke
where
	processClient id=:{processIp, processNr} osId famke
		# (reply, famke) = rpcProcessServer processIp (ClientWorkRequest processNr osId) famke
		= case reply of
			ClientDoMoreWork f 
				#!famke = TRACE ("Famke Process Client " +++ toString processNr +++ " working") famke
				  (maybe, famke) = ((\env -> (Nothing, f env)) catchAllIO (\d env -> (Just d, env))) famke
			  	  famke = TRACE ("Famke Process Client " +++ toString processNr+++ " done") famke
			  	-> case maybe of
			  		Just exception
						# (reply, famke) = rpcProcessServer processIp (ClientException processNr osId) famke
						-> case reply of ClientNoMoreWork -> raiseDynamic exception		
			  		_ -> processClient id osId famke
			ClientNoMoreWork -> famke

StartProcess :: !(*World -> *World) !*World -> *World
StartProcess f world 
	# (_, executable, args, world) = commandLine world
	= case args of
		[id] -> StartKernel (toInt id) startProcessClient world
		[] -> StartKernel 0 (startProcessServer executable f) world

commandLine :: !*World -> (!String, !String, ![String], !*World)
commandLine world
	# [arg0:args] = [x \\ x <-: getCommandLine]
	  (executable, world) = if (arg0 <> GetDynamicLinkerPath +++ "\\utilities\\ConsoleClient.exe")
								 (arg0, world)
								let (_, batch, world`) = GetConsoleTitle world in (batch, world`)
	= (toString (reverse (getPath (reverse (fromString executable)))), executable, args, world)
where
	getPath ['\\':xs] = xs
	getPath [x:xs] = [x:getPath xs]

launchExecutable :: !String ![String] !*World -> (!Bool, !*World)
launchExecutable program args famke 
	# (ok, info, famke) = CreateProcess (foldl concat ("\"" +++ program +++ "\"") args) False 0 famke
	| not ok = (False, famke)
	# (ok1, famke) = CloseHandle info.hThread famke
	  (ok2, famke) = CloseHandle info.hProcess famke
	= (ok1 && ok2, famke)
where
	concat x y = x +++ " \"" +++ y +++ "\""

instance toString ProcessId
where
	toString {processIp, processNr} = toString processIp +++ ":" +++ toString processNr

instance == ProcessId
where
	(==) x y = x.processIp == y.processIp && x.processNr == y.processNr
