module asynciotest

import StdEnv
import System.AsyncIO
import System.AsyncIO.AIOWorld
import Data.Error
import qualified Data.Foldable
import Data.Tuple
import Data.Func
import Data.Functor
import System.CommandLine
import Text
import Data.List
import StdDebug

Start w
	# aioworld = fromOk (createAIOWorld ([], []) w)
	# aioworld = testNetworkIo "Test 1" (Port 1234) test1Listener test1Client test1ExpectedOutputState 8 aioworld
	# aioworld = {aioworld & state = ([], [])}
	# aioworld = testNetworkIo "Test 2" (Port 1235) test2Listener test2Client test2ExpectedOutputState 8 aioworld
	# aioworld = {aioworld & state = ([], [])}
	# aioworld = testNetworkIo "Test 3" (Port 1236) test3Listener test3Client test3ExpectedOutputState 6 aioworld
	# aioworld = {aioworld & state = ([], [])}
	# aioworld = testNetworkIo "Test 4" (Port 1237) test4Listener test4Client test4ExpectedOutputState 8000 aioworld
	# aioworld = {aioworld & state = ([], [])}
	# aioworld = testWriteData "Test 5" (Port 1238) aioworld
	# aioworld = {aioworld & state = ([], [])}
	= aioworld

checkResult :: !String !([String], [String]) !*(AIOWorld ([String], [String])) -> *(AIOWorld ([String], [String]))
checkResult testName expected aioworld
	# actual = aioworld.state
	# pass = expected == actual
	| pass = aioworld
	# strExpected = 'Data.Foldable'.foldl` (+++) "" (fmap (join ", ") expected)
	# strActual = 'Data.Foldable'.foldl` (+++) "" (fmap (join ", ") actual)
	# stdErrOutput = stderr <<< testName <<< ": " <<< "Expected: '" <<< strExpected
		<<< "', Actual: '" <<< strActual <<< "'\n"
	= {aioworld & world = setReturnCode -1 $ snd $ fclose stdErrOutput aioworld.world}

testNetworkIo :: !String
                 !Port
                 !(ConnectionHandlers (AIOWorld ([String], [String])))
                 !(ConnectionHandlers (AIOWorld ([String], [String])))
                 !([String], [String])
                 !Int
                 !(AIOWorld ([String], [String]))
              -> AIOWorld ([String], [String])
testNetworkIo testName port handlersListener handlersClient expectedOutput maxIterations aioworld
	# aioworld = addListener handlersListener port aioworld
	# (_, aioworld) = addConnection handlersClient "localhost" port aioworld
	# aioworld = loop (?Just maxIterations) (?Just 0) 100 aioworld
	= checkResult testName expectedOutput aioworld

// Tests if writeData results in monitoring for writability before retrieving I/O events
// To make sure the event loop does not block when data should be sent.
testWriteData :: !String !Port !(AIOWorld ([String], [String])) -> AIOWorld ([String], [String])
testWriteData testName port aioworld
	# aioworld = addListener handlersListener port aioworld
	# (mbCid, aioworld) = addConnection handlersClient "localhost" port aioworld
	# aioworld = writeData (fromOk mbCid) ["test"] aioworld
	# aioworld = loop (?Just 3) ?None 100 aioworld
	= checkResult testName expectedOutput aioworld
where
	handlersListener :: ConnectionHandlers (AIOWorld (DataReceivedByClient, DataReceivedByListener))
	handlersListener =
		{ConnectionHandlers
		| onConnect = \_ ipAddr env -> ([], False, env)
		, onData    = \_ data env -> ([], True, {env & state = appSnd (\listenerOut -> listenerOut ++ [data]) env.state})
		, onTick    = \_ env -> ([], False, env)
		, onDisconnect = \_ env -> env
		}

	handlersClient :: ConnectionHandlers (AIOWorld (DataReceivedByClient, DataReceivedByListener))
	handlersClient =
		{ConnectionHandlers
		| onConnect = \_ ipAddr env -> ([], False, env)
		, onData    = \_ data env -> ([], False, env)
		, onTick    = \_ env -> ([], False, env)
		, onDisconnect = \_ env -> env
		}

	expectedOutput = ([], ["test"])

:: DataReceivedByListener :== [String]
:: DataReceivedByClient :== [String]

/* Test 1
 * Expected behavior:
 * 1: Client should receive "listener acknowledgement: connection was established"
 * as this is returned as output to be sent by listener onConnect.

 * 2: Listener should receive "client acknowledgement: data was received"
 * as this is returned as output by client onData (onData is called because of step 1)

 * 3: Both listener and client should have the onDisconnect callback evaluated
 * as the client returns close is True by the onData callback, resulting in the connection being closed on both ends.

 * Expected AIOWorld state after test: test1ExpectedOutputState.
 * Maximum amount of Events expected: 8
 * (InConnectionEvent OutConnectionEvent, ReadEventSock, SendEventSock, ReadEventSock, SendEventSock, OnDisconnect, OnDisconnect)
 */
test1Listener :: ConnectionHandlers (AIOWorld (DataReceivedByClient, DataReceivedByListener))
test1Listener =
	{ConnectionHandlers
	| onConnect = \_ ipAddr env -> (["listener acknowledgement: connection was established"], False, env)
	, onData    = \_ data env -> ([], False, {env & state = appSnd (\listenerOut -> listenerOut ++ [data]) env.state})
	, onTick    = \_ env -> ([], False, env)
	, onDisconnect = \_ env -> {env & state = appSnd (\listenerOut -> listenerOut ++ ["connection was closed"]) env.state}
	}

test1Client :: ConnectionHandlers (AIOWorld (DataReceivedByClient, DataReceivedByListener))
test1Client =
	{ConnectionHandlers
	| onConnect = \_ ipAddr env -> ([], False, env)
	, onData    = \_ data env ->
		( ["client acknowledgement: data was received"]
		, True
		, {env & state = appFst (\clientOut -> clientOut ++ [data]) env.state}
		)
	, onTick    = \_ env -> ([], False, env)
	, onDisconnect = \_ env -> {env & state = appFst (\clientOut -> clientOut ++ ["connection was closed"]) env.state}
	}

test1ExpectedOutputState :: (DataReceivedByClient, DataReceivedByListener)
test1ExpectedOutputState =:
	( ["listener acknowledgement: connection was established", "connection was closed"]
	, ["client acknowledgement: data was received", "connection was closed"]
	)
// END test 1

/* Test 2
 * Expected behavior:
 * 1: Listener should receive "client acknowledgement: connection was established"
 * as this is returned as output to be sent by client onConnect.
 *
 * 2: Client should receive "listener acknowledgement: data was received"
 * as this is returned as output by listener onData (onData is called because of step 1)
 *
 * 3: Both listener and client should have the onDisconnect callback evaluated
 * as the listener returns close is True by the onData callback, resulting in the connection being closed on both ends.
 *
 * Expected AIOWorld state after test: test2ExpectedOutputState
 * Maximum amount of Events expected: 8
 * (InConnectionEvent OutConnectionEvent, ReadEventSock, SendEventSock, ReadEventSock, SendEventSock
 * , OnDisconnect, OnDisconnect)
 */
test2Listener :: ConnectionHandlers (AIOWorld (DataReceivedByClient, DataReceivedByListener))
test2Listener =
	{ConnectionHandlers
	| onConnect = \_ ipAddr env -> ([], False, env)
	, onData    = \_ data env ->
		( ["listener acknowledgement: data was received"]
		, True
		, {env & state = appSnd (\listenerOut -> listenerOut ++ [data]) env.state}
		)
	, onTick    = \_ env -> ([], False, env)
	, onDisconnect = \_ env -> {env & state = appSnd (\listenerOut -> listenerOut ++ ["connection was closed"]) env.state}
	}

test2Client :: ConnectionHandlers (AIOWorld (DataReceivedByClient, DataReceivedByListener))
test2Client =
	{ConnectionHandlers
	| onConnect = \_ ipAddr env -> (["client acknowledgement: connection was established"], False, env)
	, onData    = \_ data env -> ([], False, {env & state = appFst (\clientOut -> clientOut ++ [data]) env.state})
	, onTick    = \_ env -> ([], False, env)
	, onDisconnect = \_ env -> {env & state = appFst (\clientOut -> clientOut ++ ["connection was closed"]) env.state}
	}

test2ExpectedOutputState :: (DataReceivedByClient, DataReceivedByListener)
test2ExpectedOutputState =:
	( ["listener acknowledgement: data was received", "connection was closed"]
	, ["client acknowledgement: connection was established", "connection was closed"]
	)
// END test 2

:: DataSentByListener :== [String]
:: DataSentByClient :== [String]

/* Test 3
 * Expected behavior:
 * The onTick should be called 5 times for both the listener and client when 5 ticks of the event loop are performed.
 * Expected AIOWorld state after test: test3ExpectedOutputState
 */
test3Listener :: ConnectionHandlers (AIOWorld (DataSentByClient, DataSentByListener))
test3Listener =
	{ConnectionHandlers
	| onConnect = \_ ipAddr env -> ([], False, env)
	, onData    = \_ data env -> ([], False, env)
	, onTick    = \_ env -> ([], False, env)
	, onDisconnect = \_ env -> env
	}

test3Client :: ConnectionHandlers (AIOWorld (DataSentByClient, DataSentByListener))
test3Client =
	{ConnectionHandlers
	| onConnect = \_ ipAddr env -> ([], False, env)
	, onData    = \_ data env -> ([], False, env)
	, onTick    = \_ env ->
		( []
		, if ((length $ fst env.state) == 4) True False
		, {env & state = appFst (\clientOut -> clientOut ++ ["onTickC"]) env.state}
		)
	, onDisconnect = \_ env -> env
	}

test3ExpectedOutputState :: (DataSentByClient, DataSentByListener)
test3ExpectedOutputState =: (replicate 5 "onTickC", [])
// End test 3

/* Test 4
 * Expected behavior: The client receives the whole (very large) string that is sent by the listener without the data being corrupted.
 */
test4Listener :: ConnectionHandlers (AIOWorld (DataReceivedByClient, DataReceivedByListener))
test4Listener =
	{ConnectionHandlers
	| onConnect = \_ ipAddr env -> ([(concat o fst $ test4ExpectedOutputState) /* +++ ["x"] */], True, env)
	, onData    = \_ data env -> ([], False, env)
	, onTick    = \_ env -> ([], False, env)
	, onDisconnect = \_ env -> env
	}

test4Client :: ConnectionHandlers (AIOWorld (DataReceivedByClient, DataReceivedByListener))
test4Client =
	{ConnectionHandlers
	| onConnect = \_ ipAddr env -> ([], False, env)
	, onData    = \_ data env ->
		([]
		, False
		, {env & state = appFst (\clientReceived -> if (isEmpty clientReceived) [data] ([hd clientReceived +++ data])) env.state}
		)
	, onTick    = \_ env -> ([], False, env)
	, onDisconnect = \_ env -> env
	}

// CAF 50MB string.
test4ExpectedOutputState :: (DataReceivedByClient, DataReceivedByListener)
test4ExpectedOutputState =: ([concat (replicate 5000000 "abcabcabca")], [])
// End test 4
