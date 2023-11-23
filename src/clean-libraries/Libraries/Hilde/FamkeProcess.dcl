definition module FamkeProcess

from FamkeKernel import :: FamkePort

:: ProcessId = {processIp :: !Int, processNr :: !Int}

processId :: !*World -> (!ProcessId, !*World)

newProcess :: !(*World -> *World) !*World -> (!ProcessId, !*World)
newProcessAt :: !String !(*World -> *World) !*World -> (!ProcessId, !*World)
reuseProcess :: !ProcessId !(*World -> *World) !*World -> *World
joinProcess :: !ProcessId !*World -> *World
killProcess :: !ProcessId !*World -> *World
shutdown :: !*World -> *World

reservePort :: !*World -> (!FamkePort .a .b, !*World)
freePort :: !(FamkePort .a .b) !*World -> *World

StartProcess :: !(*World -> *World) !*World -> *World
