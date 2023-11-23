module callprocesswithoutputtest

import StdEnv
import System.Process
import System.CommandLine
import Data.Error
import Data.Func
import StdDebug

Start w
	# (mbProcessResult, w) = callProcessWithOutput
		"echo"
		["foobar"]
		?None
		w
	| isError mbProcessResult = setReturnCode -1 w
	# ({exitCode, stdout}) = fromOk mbProcessResult
	= if (exitCode <> 0 || stdout <> expectedOutput)
		(setReturnCode 0 (snd $ fclose (stderr <<< "Expected output: " <<< expectedOutput <<< " Actual output: " <<< stdout) w))
		w
where
	expectedOutput = "foobar\n"
