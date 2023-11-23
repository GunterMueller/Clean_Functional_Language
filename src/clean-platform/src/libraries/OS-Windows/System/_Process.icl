implementation module System._Process

import StdEnv

import Data.Func
import Data.Maybe
import System.FilePath
import System.OSError
import System.Process
import System._Pointer
from System._WinBase import
	:: DWORD, :: SIZE_T, :: LPVOID, :: LPDWORD, :: LPCTSTR, :: HANDLE,
	:: PHANDLE, :: LPSECURITY_ATTRIBUTES, :: LPPROCESS_INFORMATION,
	:: LPSTARTUPINFO, :: LPOVERLAPPED, :: SECURITY_ATTRIBUTES,
	:: LPTHREAD_START_ROUTINE,
	SECURITY_ATTRIBUTES_SIZE_INT, SECURITY_ATTRIBUTES_SIZE_BYTES,
	SECURITY_ATTRIBUTES_nLength_INT_OFFSET,
	SECURITY_ATTRIBUTES_bInheritHandle_INT_OFFSET,
	PROCESS_INFORMATION_size_int, PROCESS_INFORMATION_hProcess_int_offset,
	PROCESS_INFORMATION_hThread_int_offset,
	STARTUPINFO_size_int, STARTUPINFO_size_bytes, STARTUPINFO_cb_int_offset,
	STARTUPINFO_hStdInput_int_offset, STARTUPINFO_hStdOutput_int_offset,
	STARTUPINFO_hStdError_int_offset, STARTUPINFO_set_dwFlags,
	STARTF_USESTDHANDLES, DETACHED_PROCESS, HANDLE_FLAG_INHERIT,
	NULL, TRUE, INFINITE, STILL_ACTIVE,
	getProcessHeap, heapAlloc, heapFree,
	getLastError,
	createPipe, setHandleInformation, closeHandle,
	peekNamedPipe, readFile, writeFile,
	CreateThread, TerminateThread,
	waitForSingleObject, waitForMultipleObjects,
	createProcessA, createProcessA_dir, getExitCodeProcess
import qualified System._WinBase
import Text
import Text.GenJSON

import code from "systemprocess.o"

:: WritePipe =: WritePipe Int
:: ReadPipe =: ReadPipe Int

derive JSONEncode WritePipe, ReadPipe
derive JSONDecode WritePipe, ReadPipe

_openPipePair :: !Bool !*World -> (!MaybeOSError (Int, Int), !*World)
_openPipePair close_right_not_left w
	# (heap, w) = getProcessHeap w
	# (ptr, w) = heapAlloc heap 0 (IF_INT_64_OR_32 16 8) w
	| ptr == 0 = abort "heapAlloc failed"
	# (ok, w) = createPipe ptr (ptr + IF_INT_64_OR_32 8 4) securityAttributes 0 w
	| not ok
		# (_, w) = heapFree heap 0 ptr w
		= getLastOSError w
	# (rEnd, ptr)  = readIntP ptr 0
	# (wEnd, ptr)  = readIntP ptr (IF_INT_64_OR_32 8 4)
	# (_, w) = heapFree heap 0 ptr w
    # (ok, w) = setHandleInformation (if close_right_not_left wEnd rEnd) HANDLE_FLAG_INHERIT 0 w
    | not ok
		= getLastOSError w
		= (Ok (rEnd, wEnd), w)
where
	securityAttributes =
		{ createArray SECURITY_ATTRIBUTES_SIZE_INT 0
		& [SECURITY_ATTRIBUTES_nLength_INT_OFFSET]        = SECURITY_ATTRIBUTES_SIZE_BYTES
		, [SECURITY_ATTRIBUTES_bInheritHandle_INT_OFFSET] = TRUE
		}

instance closePipe WritePipe
where
	closePipe :: !WritePipe !*World -> (!MaybeOSError (), !*World)
	closePipe (WritePipe pipe) w = closePipe` pipe w

instance closePipe ReadPipe
where
	closePipe :: !ReadPipe !*World -> (!MaybeOSError (), !*World)
	closePipe (ReadPipe pipe) w = closePipe` pipe w

closePipe` :: !Int !*World -> (!MaybeOSError (), !*World)
closePipe` pipe w
	# (res, w) = closeHandle pipe w
	| not res = getLastOSError w
	| otherwise = (Ok (), w)

_blockPipe :: !ReadPipe !*World -> (!MaybeOSError (), !*World)
_blockPipe (ReadPipe pipe) w
	# (ok, w) = readFile pipe NULL 0 NULL NULL w
	| not ok
		# (err, w) = getLastError w
		| err == 109 // broken pipe: see comments on _startProcess why we ignore this
			= (Ok (), w)
			= getLastOSError w
	| otherwise
		= (Ok (), w)

/* NB: Windows' WaitForMultipleObjects does not work on pipes. For this reason
 * we create threads for each ReadPipe. Each thread receives a pipe, on which
 * it does a ReadFile with an empty buffer (see systemprocess.c) to block on
 * the pipe. We wait on these threads. When the wait is done, we terminate all
 * threads.
 * The threads to read the pipes must be implemented in C to prevent them from
 * corrupting the Clean heap.
 */
_blockAnyPipe :: ![ReadPipe] !*World -> (!MaybeOSError (), !*World)
_blockAnyPipe pipes w
	# pipes_arr = {p \\ ReadPipe p <- pipes}
	# pipes_arr_ptr = aStackPtr pipes_arr + IF_INT_64_OR_32 24 12
	# npipes = size pipes_arr
	# (threads, (_, w)) = mapSt
		(\(ReadPipe p) (i, w)
			#! (handle,id,w) = CreateThread
				0 0
				readFileInSeparateThreadAddress
				(pipes_arr_ptr + (i << IF_INT_64_OR_32 3 2))
				0 w
			-> (handle, (i+1, w)))
		pipes
		(0, w)
	# threads_arr = {t \\ t <- threads}
	#! (i, w) = waitForMultipleObjects npipes threads_arr False 0xffffffff w
	#! w = seqSt (\h w -> snd (TerminateThread h 0 w)) threads w
	| 0 <= i && i < npipes
		= (Ok (), w)
	| 0x80 <= i && i < 0x80+npipes
		= abort "_blockAnyPipe: waitForMultipleObjects returned WAIT_ABANDONED"
	| i == 0x102 // WAIT_TIMEOUT; should not occur with 0xffffffff as timeout
		= abort "_blockAnyPipe: waitForMultipleObjects returned WAIT_TIMEOUT"
	| i == 0xffffffff // WAIT_FAILED
		= getLastOSError w
	// NB: we have to prevent pipes_arr from being garbage collected because
	// it is used by the reading threads. This guard makes sure that it remains
	// on the stack.
	| size pipes_arr < 0
		= abort "cannot happen"
	| otherwise
		= abort ("_blockAnyPipe: waitForMultipleObjects returned unknown response value "+++toString i)
where
	aStackPtr :: !{#Int} -> Int
	aStackPtr arr = code {
		push_a_b 0
		pop_a 1
	}

	readFileInSeparateThreadAddress = IF_INT_64_OR_32 addr64 addr32
	where
		addr64 :: Int
		addr64 = code {
			pushLc readFileInSeparateThread
		}
		addr32 :: Int
		addr32 = code {
			pushLc readFileInSeparateThread@4
		}

_peekPipe :: !ReadPipe !*World -> (!MaybeOSError Int, !*World)
_peekPipe (ReadPipe pipe) w
	# (heap, w) = getProcessHeap w
	# (nBytesPtr, w) = heapAlloc heap 0 4 w
	| nBytesPtr == 0 = abort "heapAlloc failed"
	# (ok, w) = peekNamedPipe pipe NULL 0 NULL nBytesPtr NULL w
	# (nBytes, nBytesPtr) = readIntP nBytesPtr 0
	# nBytes = nBytes bitand 0xffffffff
	# (_, w) = heapFree heap 0 nBytesPtr w
	| not ok
		# (err, w) = getLastError w
		| err == 109 // broken pipe: see comments on _startProcess why we ignore this
			= (Ok 0, w)
			= getLastOSError w
	| otherwise
		= (Ok nBytes, w)

_readPipeNonBlocking :: !ReadPipe !Int !*World -> (!MaybeOSError String, !*World)
_readPipeNonBlocking (ReadPipe pipe) nBytes w
	# (heap, w) = getProcessHeap w
	# (buf, w) = heapAlloc heap 0 nBytes w
	| buf == 0 = abort "heapAlloc failed"
	# (ok, w) = readFile pipe buf nBytes NULL NULL w
	| not ok
		# (_, w) = heapFree heap 0 buf w
		# (err, w) = getLastError w
		| err == 109 // broken pipe: see comments on _startProcess why we ignore this
			= (Ok "", w)
			= getLastOSError w
	# (str, buf) = readP (\ptr -> derefCharArray ptr nBytes) buf
	# (_, w) = heapFree heap 0 buf w
	= (Ok str, w)

_writePipe :: !String !WritePipe !*World -> (!MaybeOSError (), !*World)
_writePipe data (WritePipe pipe) w
	# (ok, w) = writeFile pipe data (size data) NULL NULL w
	| ok
		= (Ok (), w)
		= getLastOSError w

_equalPipe :: !WritePipe !ReadPipe -> Bool
_equalPipe (WritePipe x) (ReadPipe y) = x == y

_startProcess ::
	!FilePath ![String] !(?String)
	!(?((Int,Int), (Int,Int), (Int,Int)))
	!*World -> (!MaybeOSError (ProcessHandle, ?ProcessIO), !*World)
_startProcess exe args dir mbPipes w
	# startupInfo =
		mbSetPipes $
		STARTUPINFO_set_dwFlags STARTF_USESTDHANDLES
		{ createArray STARTUPINFO_size_int 0
		& [STARTUPINFO_cb_int_offset] = STARTUPINFO_size_bytes
		}
	# commandLine = packString (foldr (\a b -> a +++ " " +++ b) "" (map escape [exe:args]))
	# processInformation = createArray PROCESS_INFORMATION_size_int 0
	# (ok, w) = case dir of
		?Just dir -> createProcessA_dir (packString exe) commandLine 0 0 True DETACHED_PROCESS 0 (packString dir) startupInfo processInformation w
		?None     -> createProcessA (packString exe) commandLine 0 0 True DETACHED_PROCESS 0 NULL startupInfo processInformation w
	| not ok = getLastOSError w
	# processHandle =
		{ processHandle = processInformation.[PROCESS_INFORMATION_hProcess_int_offset]
		, threadHandle = processInformation.[PROCESS_INFORMATION_hThread_int_offset]
		}
	| isNone mbPipes = (Ok (processHandle, ?None), w)
	/* NB: the pipeStdInOut, pipeStdOutIn, and pipeStdErrIn handles are
	 * inherited by the child process. We must close the handles that the
	 * parent process still has, to avoid ReadFile to block when the child
	 * process has terminated. When the child terminates and the pipe is empty,
	 * ReadFile will return error 109 (broken pipe), which is how we know that
	 * the reading is done. For details, see:
	 * https://docs.microsoft.com/en-us/windows/win32/ipc/pipe-handle-inheritance
	 */
	# (_,w) = closeHandle pipeStdInOut w
	# (_,w) = closeHandle pipeStdOutIn w
	# (_,w) = closeHandle pipeStdErrIn w
	=
		( Ok
			( processHandle
			, ?Just
				{ stdIn  = WritePipe pipeStdInIn
				, stdOut = ReadPipe  pipeStdOutOut
				, stdErr = ReadPipe  pipeStdErrOut
				}
			)
		, w
		)
where
	// We only evaluate this when mbPipes is ?Just:
	((pipeStdInOut, pipeStdInIn), (pipeStdOutOut, pipeStdOutIn), (pipeStdErrOut, pipeStdErrIn)) = fromJust mbPipes

	mbSetPipes startupInfo = if (isNone mbPipes) startupInfo
		{ startupInfo
		& [STARTUPINFO_hStdInput_int_offset]  = pipeStdInOut
		, [STARTUPINFO_hStdOutput_int_offset] = pipeStdOutIn
		, [STARTUPINFO_hStdError_int_offset]  = pipeStdErrIn
		}

	escape :: !String -> String
	escape s
		| indexOf " " s == -1
			= s
		| size s >= 2 && s.[0] == '"' && (s.[size s - 1] == '"')
			= s
			= concat3 "\"" s "\""

_startProcessPty ::
	!FilePath ![String] !(?String) !ProcessPtyOptions
	!*World -> (!MaybeOSError (ProcessHandle, ProcessIO), !*World)
_startProcessPty _ _ _ _ _ = abort "_startProcessPty"

_checkProcess :: !ProcessHandle !*World -> (!MaybeOSError (?Int), !*World)
_checkProcess handle=:{processHandle} w
	# (ok,exitCode,w) = getExitCodeProcess processHandle w
	| not ok = getLastOSError w
	| exitCode == STILL_ACTIVE = (Ok ?None, w)
	# (mbError,w) = closeProcessHandle handle w
	= (Ok (?Just exitCode), w)

_waitForProcess :: !ProcessHandle !*World -> (!MaybeOSError Int, !*World)
_waitForProcess handle=:{processHandle} w
	# (res,w) = waitForSingleObject processHandle INFINITE w
	# (ok,exitCode,w) = getExitCodeProcess processHandle w
	| not ok = getLastOSError w
	# (mbError,w) = closeProcessHandle handle w
	= (Ok exitCode, w)

_terminateProcess :: !ProcessHandle !Int !*World -> (!MaybeOSError (), !*World)
_terminateProcess hProc=:{processHandle} exitCode w
	# (ok, w) = 'System._WinBase'.terminateProcess processHandle exitCode w
	= closeProcessHandle hProc w

closeProcessHandle :: !ProcessHandle !*World -> (MaybeOSError (), *World)
closeProcessHandle handle world
	# (ok,world) = closeHandle handle.processHandle world
	| not ok = getLastOSError world
	# (ok, world) = closeHandle handle.threadHandle world
	| not ok = getLastOSError world
	= (Ok (), world)
