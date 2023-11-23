module Main

import StdId
import StdFunc
import StdProcess
import EdCommon, EdState
import EdFileMenu, EdEditMenu, EdOptionsMenu
import EdKeyMapping

Start world
	# (undoId,world) = openId world
	= startIO MDI (MES (initEditorState macKeyMapping)) (processInit undoId) [] world
/*
  = startProcesses group world
  where
	group			= ProcessGroup NO_STATE process
	process			= MDIProcess initEditorState
								 processInit
								 [ ProcessNoWindowMenu ]
*/
processInit undoId
  = seq
  	[ openFileMenu undoId 		// DvA
	, openEditMenu
	, openOptionsMenu
	]
