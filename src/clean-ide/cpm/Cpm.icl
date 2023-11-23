/**
 * CPM: Clean Project Manager
 *
 * CPM is a tool for managing CleanIDE-compatible projects on the commandline
 * and is targeted at OS X and Linux users who do not have access to the
 * CleanIDE.
 */
module Cpm

/**
 * Clean libraries imports
 */
import StdEnv,ArgEnv
from Platform import DirSeparatorString

/**
 * CPM imports
 */
import Parser,CpmLogic

/**
 * CleanIDE imports
 */
from UtilIO import GetCurrentDirectory,GetFullApplicationPath,GetLongPathName

/**
 * Start function which reads the program arguments, starts the parser and
 * starts processing the parse results.
 */
Start :: *World -> *World
Start world
  # commandline = getCommandLine
	args = [arg \\ arg <-: commandline]
    (pwd_ok,pwd) = GetCurrentDirectory
    (cpmd, world) = accFiles GetFullApplicationPath world
    cleandir = if (cpmd % (size cpmd-4,size cpmd-1)==DirSeparatorString+++"bin") (cpmd % (0,size cpmd-5)) cpmd
    ch = case getEnvironmentVariable "CLEAN_HOME" of
				EnvironmentVariable ch -> ch
				EnvironmentVariableUndefined -> cleandir
  | pwd_ok
	= doCpmAction cleandir pwd (parseCpmLogic args) world
	= abort "Failed to read current directory"
