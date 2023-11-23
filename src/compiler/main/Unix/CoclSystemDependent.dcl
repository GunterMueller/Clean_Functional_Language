// this is for Unix
definition module CoclSystemDependent

from StdFile import ::Files
import DirectorySeparator

PathSeparator
	:==	':'

SystemDependentDevices :: [a]
SystemDependentInitialIO :: [a]

ensureCleanSystemFilesExists :: !String !*Files -> (!Bool, !*Files)
set_compiler_id :: Int -> Int

compiler_loop :: ([{#Char}] *st -> *(Bool, *st)) *st -> (!Bool, !*st)

