module memorytest
/**
 * This is a manual test
 *
 * for detecting memory issues related to the System.AsyncIO library.
 * It works by establishing connections/disconnecting immidiately over and over again, whilst sending
 * some data (5MB) over to the peer each time.
 * This deals with any memory allocation possibly not being freed.
 * If the memory allocated for a client is not freed on disconnect this results in an increase in memory usage over time.
 * If the data that is queued is not freed after sending this results in an increase in memory usage over time.
 * The amount of data that is sent does not matter as long as its not a very small amount of data
 * since it will be sent over and over again, if the data is not properly freed this will quickly lead to
 * an observable increase in memory usage.
 * The test covers all scenerios that allocate memory which should be freed.
 */

import StdEnv
import System.AsyncIO
import System.AsyncIO.AIOWorld
import Data.Error
import StdDebug
import Text
import Data.List

Start w
	# aioworld = fromOk (createAIOWorld () w)
	# aioworld = addListener handlersListener port aioworld
	# (_, aioworld) = addConnection handlersClient "localhost" port aioworld
	= loop ?None ?None 100 aioworld

port :: Port
port = (Port 1234)

handlersListener :: ConnectionHandlers (AIOWorld ())
handlersListener =
	{ConnectionHandlers
	| onConnect = \_ ipAddr env -> ([], False, env)
	, onData    = \_ data env -> ([], False, env)
	, onTick    = \_ env -> ([], False, env)
	, onDisconnect = \_ env -> env
	}

handlersClient :: ConnectionHandlers (AIOWorld ())
handlersClient =
	{ConnectionHandlers
	| onConnect = \_ ipAddr env -> trace_n "OC" (output, True, env)
	, onData    = \_ data env -> ([], False, env)
	, onTick    = \_ env -> ([], False, env)
	, onDisconnect = \_ env -> snd (addConnection handlersClient "localhost" port env)
	}

// CAF 5MB string.
output :: [String]
output =: [concat (replicate 500000 "abcabcabca")]
