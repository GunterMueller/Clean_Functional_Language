module networkio

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
import StdDebug

Start w
	/* The following function creates an AIOWorld, which is required to perform network I/O in an asynchronous manner.
	 * The 0 argument passed to createAIOWorld is the default state of the AIOWorld.
	 * The state is used to keep track of how many messages were
	 * sent over the connection and close the connection when this number exceeds 9 (see handlersListener, handlersClient).
	 **/
	# aioworld = fromOk (createAIOWorld 0 w)
	/**
	 * A listener is created which listens for connections on the provided port (1234).
	 * The handlersListener argument is a record of callback functions
	 * which used to communicate with the clients that connect to the listener (see handlersListener).
	 *
	 */
	# aioworld = addListener handlersListener (Port 1234) aioworld
	/**
	 * Similarly, this function establishes a connection to the listener that was created above.
	 * The handlersClient argument is used to communicate with the listener.
	 */
	# (_, aioworld) = addConnection handlersClient "localhost" (Port 1234) aioworld
	/*
	 * The loop function evaluates the callbacks functions that are
	 * provided by handlersClient and handlersListener when I/O events occur.
	 */
	= loop (?Just 24) (?Just 100) 1 aioworld

:: DataReceivedByListener :== [String]
:: DataReceivedByClient :== [String]

// The example models communication between server and client through the model of a tennis game.

// The listener sends (serves) the first message, after which the message is returned by the client.
// The listener then proceeds by returning the message back to the client.
// After 10 messages have been exchanged, the connection is terminated making use of the state.
handlersListener :: ConnectionHandlers (AIOWorld Int)
handlersListener =
	{ConnectionHandlers
	/**
	 * In this example, the onConnect function is used to send 'serve (ping)' back to the client that connected.
	 */
	| onConnect = \_ str env -> (["serve (ping)"], False, env)
	/**
	 * In this case the onData function is used to send 'ping' to the client that sent data.
	 * In case the amount of messages that were exchanged exceeded 9, the connection is closed.
	 * The amount of messages is incremented by one using the environment since a message was received.
	 */
	, onData    = \_ data env -> trace_n data
		( [if (env.state < 9) "ping" ""]
		, if (env.state < 9) False True
		, {env & state = inc env.state}
		)
	, onTick    = \_ env -> ([], False, env)
	, onDisconnect = \_ env -> env
	}

handlersClient :: ConnectionHandlers (AIOWorld Int)
handlersClient =
	{ConnectionHandlers
	| onConnect = \_ str env -> ([], False, env)
	/**
	 * The onData function is used to send 'pong' back over the connection when data is received.
	 * In case the amount of messages that was sent exceeded 9, the connection is closed.
	 * The amount of messages is incremented by one using the environment since a message was received.
	 */
	, onData    = \_ data env -> trace_n data
		( [if (env.state < 9) "pong" ""]
		, if (env.state < 9) False True
		, {env & state = inc env.state}
		)
	, onTick    = \_ env -> ([], False, env)
	, onDisconnect = \_ env -> env
	}

