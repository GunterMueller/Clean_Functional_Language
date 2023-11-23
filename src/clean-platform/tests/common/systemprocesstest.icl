module systemprocesstest

import StdEnv
import System.CommandLine
import System.Process
import Data.Error
import Data.Func
import Text

pty = runProcessPty "/bin/sh" ["-c", "sleep 2 && echo bork"] ?None defaultPtyOptions
pio = runProcessIO  "/bin/sh" ["-c", "sleep 2 && echo bork"] ?None

test msg expected rpf pf world
	# (Ok (handle,io),world) = pf world
	# (Ok output,world) = rpf io.stdOut world
	# (Ok out,world) = waitForProcess handle world
	# (Ok _,world) = closeProcessIO io world
	# f = if (expected <> trim output)
		(setReturnCode 1 o snd o fclose (stderr <<< msg <<< "Expected: '" <<< expected <<< "', Got: '" <<< trim output <<< "'\n"))
		id
	= f world

Start world
	= test "ptynb: " "" readPipeNonBlocking pty
	$ test "pty b: " "bork" readPipeBlocking pio
	$ test "pionb: " "" readPipeNonBlocking pio
	$ test "pio b: " "bork" readPipeBlocking pio
	$ world
