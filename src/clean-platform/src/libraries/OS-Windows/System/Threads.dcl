definition module System.Threads

/**
 * This module implements basic functionality to run code in different threads.
 * It requires a modified version of the Clean run-time system, and is
 * currently only available on Windows.
 */

import StdDynamic

:: ThreadId :== DWORD

getCurrentThreadId :: !*World -> (!ThreadId, !*World)
send :: !ThreadId !a !*World -> *(!Bool, !*World) | TC a
receive :: !*World -> *(!Int, !Dynamic, !*World)

fork :: !(*World -> *World) !*World -> (!ThreadId, !*World)
waitForThread :: !ThreadId !*World -> *World

from System._WinDef import :: LPVOID, :: DWORD

threadFunc :: !LPVOID -> DWORD
