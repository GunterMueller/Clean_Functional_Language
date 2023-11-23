definition module PmDialogues

import StdPSt
import PmTypes, PmProject, IdeState

projectOptions	:: !(PSt General) -> PSt General
projectDefaults	:: !(PSt General) -> PSt General

project_directory_up :: !(PSt General) -> PSt General
project_directory_down :: !(PSt General) -> PSt General

doPathsDialog	::					// Display a Paths dialogue
	!String										// Dialogue title string
	!Pathname									// Application path
	!Pathname									// Project path
	!(List Pathname)							// List of paths
	((List Pathname) (PSt .l) -> (PSt .l))	// Save paths function
	(PSt .l) -> (PSt .l)

doCompilerOptionsDialog ::			// Display Compiler Options dialogue
	!String										// Dialogue title string
	!CompilerOptions							// Compiler options
	(CompilerOptions (PSt .l) -> (PSt .l))	// Save options function
	!(PSt .l) -> (PSt .l)
