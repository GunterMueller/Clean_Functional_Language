/*
** Program: Clean Prover System
** Module:  RemoveModules (.icl)
** 
** Author:  Maarten de Mol
** Created: 13 March 2001
*/

implementation module
	RemoveModules

import
	StdIO,
	Depends,
	MarkUpText,
	MdM_IOlib,
	States
from StdFunc import seq

// ------------------------------------------------------------------------------------------------------------------------
haveOverlapPtrs :: ![ModulePtr] ![ModulePtr] -> Bool
// ------------------------------------------------------------------------------------------------------------------------
haveOverlapPtrs [ptr:ptrs] set2
	| isMember ptr set2						= True
	= haveOverlapPtrs ptrs set2
haveOverlapPtrs [] set2
	= False

// ------------------------------------------------------------------------------------------------------------------------
removeModules :: !Bool ![ModulePtr] !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------
removeModules rectify ptrs pstate
	| isEmpty ptrs							= selectModules pstate
	# (used_bys, pstate)					= umap modulesUsingModule ptrs pstate
	# used_by								= removeMembers (removeDup (flatten used_bys)) ptrs
	| not (isEmpty used_by)
		# (mod, pstate)						= accHeaps (readPointer (hd used_by)) pstate
		= showError [X_RemoveModules ("imported by module " +++ mod.pmName)] pstate
	# (used_ins, pstate)					= umap theoremsUsingModule ptrs pstate
	# used_in								= flatten used_ins
	| not (isEmpty used_in)
		# (theorem, pstate)					= accHeaps (readPointer (hd used_in)) pstate
		= showError [X_RemoveModules ("used in theorem " +++ theorem.thName)] pstate
	| not rectify							= actually_remove ptrs pstate
	# (name, pstate)						= accHeaps (getPointerName (hd ptrs)) pstate
	# fname									= case length ptrs of
												1	-> [CmText "Remove module ", CmIText name, CmText " from memory?"]
												_	-> [CmText "Remove ", CmIText "all", CmText " modules from memory?"]
	# (ok, pstate)							= rectifyDialog fname pstate
	| not ok								= pstate
	= actually_remove ptrs pstate
	where
		actually_remove :: ![ModulePtr] !*PState -> *PState
		actually_remove ptrs pstate
			# (all_modules, pstate)			= pstate!ls.stProject.prjModules
			# all_modules					= removeMembers all_modules ptrs
			# pstate						= {pstate & ls.stProject.prjModules = all_modules}
			# pstate						= broadcast Nothing (RemovedCleanModules ptrs) pstate
			# pstate						= appHeapsProject findABCFunctions pstate
			= pstate






















// ------------------------------------------------------------------------------------------------------------------------
// boxControl :: (MarkUpText a) _ _ -> _
// ------------------------------------------------------------------------------------------------------------------------
boxControl text markup_attrs attrs
	# resize							= find_resize attrs
	= CompoundControl
			( MarkUpControl text markup_attrs resize )
			[ ControlHMargin			1 1
			, ControlVMargin			1 1
			, ControlItemSpace			1 1
			, ControlLook				True (\_ {newFrame} -> seq [setPenColour Black, draw newFrame])
			: attrs
			]
	where
		find_resize [ControlResize fun:_]
			= [ControlResize fun]
		find_resize [other:rest]
			= find_resize rest
		find_resize []
			= []

// ------------------------------------------------------------------------------------------------------------------------   
LightBlue	:== RGB {r=224, g=227, b=253}
MyGreen		:== RGB {r=  0, g=150, b= 75}
// ------------------------------------------------------------------------------------------------------------------------   

// ------------------------------------------------------------------------------------------------------------------------
selectModules :: !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------
selectModules pstate
	# (dialog_id, pstate)					= accPIO openId pstate
	# (dialog_rid, pstate)					= accPIO openRId pstate
	# (list_rid, pstate)					= accPIO openRId pstate
	# (ok_id, pstate)						= accPIO openId pstate
	# (close_id, pstate)					= accPIO openId pstate
	# (cancel_id, pstate)					= accPIO openId pstate
	# (deselect_id, pstate)					= accPIO openId pstate
	# (all_modules, pstate)					= pstate!ls.stProject.prjModules
	# (used_modules, pstate)				= filter_used all_modules pstate
	# (fmodules, pstate)					= showModules [] used_modules pstate
	= snd (openModalDialog ([], used_modules) (removeDialog dialog_id dialog_rid list_rid ok_id close_id cancel_id deselect_id fmodules) pstate)
	where
		filter_used :: ![ModulePtr] !*PState -> (![ModulePtr], !*PState)
		filter_used [ptr:ptrs] pstate
			# (ptrs, pstate)				= filter_used ptrs pstate
			# (theorems, pstate)			= theoremsUsingModule ptr pstate
			= case isEmpty theorems of
				True	-> (ptrs, pstate)
				False	-> ([ptr:ptrs], pstate)
		filter_used [] pstate
			= ([], pstate)

// ------------------------------------------------------------------------------------------------------------------------
//removeDialog :: !Id !(RId _) -> _
// ------------------------------------------------------------------------------------------------------------------------
removeDialog dialog_id dialog_rid list_rid ok_id close_id cancel_id deselect_id fmodules
	= Dialog "Remove modules"
		(		Receiver					dialog_rid receive
												[]
			:+:	MarkUpControl				[CmBText "Select modules to remove:"]
												[ MarkUpFontFace			"Times New Roman"
												, MarkUpTextSize			10
												, MarkUpBackgroundColour	getDialogBackgroundColour
												]
												[]
			:+: boxControl					fmodules
												[ MarkUpFontFace			"Times New Roman"
												, MarkUpTextSize			10
												, MarkUpBackgroundColour	White
												, MarkUpHScroll
												, MarkUpVScroll
												, MarkUpWidth				300
												, MarkUpHeight				400
												, MarkUpLinkStyle			False Black LightBlue False Blue LightBlue
												, MarkUpLinkStyle			False Black White False Blue White
												, MarkUpReceiver			list_rid
												, MarkUpEventHandler		(clickHandler (\cmd state -> snd (asyncSend dialog_rid cmd state)))
												]
												[ ControlPos				(Left, zero)
												]
			:+:	ButtonControl				"Remove!"
												[ ControlPos				(Right, zero)
												, ControlId					ok_id
												, ControlSelectState		Unable
												, ControlFunction			remove
												]
			:+:	ButtonControl				"Close set"
												[ ControlPos				(LeftOf ok_id, zero)
												, ControlId					close_id
												, ControlFunction			close
												, ControlSelectState		Unable
												]
			:+:	ButtonControl				"Deselect all"
												[ ControlPos				(LeftOf close_id, zero)
												, ControlId					deselect_id
												, ControlFunction			deselect
												]
			:+:	ButtonControl				"Cancel"
												[ ControlPos				(LeftOf ok_id, zero)
												, ControlHide
												, ControlFunction			(noLS (closeWindow dialog_id))
												, ControlId					cancel_id
												]
		)
		[ WindowId							dialog_id
		, WindowClose						(noLS (closeWindow dialog_id))
		, WindowOk							ok_id
		, WindowCancel						cancel_id
		]
	where
		refresh :: ![ModulePtr] ![ModulePtr] !*PState -> *PState
		refresh selected used pstate
			# (fmodules, pstate)			= showModules selected used pstate
			# pstate						= changeMarkUpText list_rid fmodules pstate
			# pstate						= case isEmpty selected of
												True	-> appPIO (disableControls [close_id,deselect_id]) pstate
												False	-> appPIO (enableControls [close_id,deselect_id]) pstate
			# (closed, pstate)				= enclose selected [] pstate
			# is_closed						= (length closed) == (length selected)
			# is_unused						= not (haveOverlapPtrs selected used)
			# pstate						= case is_closed && is_unused && not (isEmpty selected) of
												True	-> appPIO (enableControls [ok_id]) pstate
												False	-> appPIO (disableControls [ok_id]) pstate
			= pstate
	
		receive :: !ModulePtr (!(![ModulePtr], ![ModulePtr]), !*PState) -> (!(![ModulePtr], ![ModulePtr]), !*PState)
		receive ptr ((selected, used), pstate)
			# selected						= case isMember ptr selected of
												True	-> removeMember ptr selected
												False	-> [ptr:selected]
			= ((selected, used), refresh selected used pstate)
		
		close :: !(!(![ModulePtr], ![ModulePtr]), !*PState) -> (!(![ModulePtr], ![ModulePtr]), !*PState)
		close ((selected, used), pstate)
			# (selected, pstate)			= enclose selected [] pstate
			= ((selected, used), refresh selected used pstate)
		
		deselect :: !(!(![ModulePtr], ![ModulePtr]), !*PState) -> (!(![ModulePtr], ![ModulePtr]), !*PState)
		deselect ((selected, used), pstate)
			= (([], used), refresh [] used pstate)
		
		enclose :: ![ModulePtr] ![ModulePtr] !*PState -> (![ModulePtr], *PState)
		enclose [ptr:ptrs] seen pstate
			| isMember ptr seen				= enclose ptrs seen pstate
			# (mod, pstate)					= accHeaps (readPointer ptr) pstate
			# (imported_by, pstate)			= modulesUsingModule ptr pstate
			= enclose (ptrs ++ imported_by) [ptr:seen] pstate
		enclose [] seen pstate
			= (seen, pstate)
		
		remove :: !(!(![ModulePtr], ![ModulePtr]), !*PState) -> (!(![ModulePtr], ![ModulePtr]), !*PState)
		remove ((selected, used), pstate)
			# pstate						= removeModules False selected pstate
			# pstate						= closeWindow dialog_id pstate
			= ((selected,used), pstate)

// ------------------------------------------------------------------------------------------------------------------------
showModules :: ![ModulePtr] ![ModulePtr] !*PState -> (!MarkUpText ModulePtr, !*PState)
// ------------------------------------------------------------------------------------------------------------------------
showModules selected used pstate
	# (all_modules, pstate)					= pstate!ls.stProject.prjModules
	# (module_infos, pstate)				= show all_modules pstate
	# module_infos							= sortBy (\(n1,_)(n2,_) -> n1 < n2) module_infos
	# fmodules								= flatten (map snd module_infos)
	= (fmodules, pstate)
	where
		show :: ![ModulePtr] !*PState -> ([(CName, MarkUpText ModulePtr)], !*PState)
		show [ptr:ptrs] pstate
			# (module_infos, pstate)		= show ptrs pstate
			# (mod, pstate)					= accHeaps (readPointer ptr) pstate
			# is_used						= isMember ptr used
			# ftext							= case isMember ptr selected of
												True	->	[ CmBackgroundColour	LightBlue
															, CmColour				MyGreen
															, CmFontFace			"Wingdings"
															, CmBText				{toChar 252}
															, CmEndFontFace
															, CmEndColour
															, CmText				" "
															, CmLink2				0 mod.pmName ptr
															, CmColour				Red
															, CmIText				(if is_used " (used)" "")
															, CmEndColour
															, CmFillLine
															, CmEndBackgroundColour
															, CmNewlineI			False 1 Nothing
															]
												False	->	[ CmColour				White
															, CmFontFace			"Wingdings"
															, CmBText				{toChar 252}
															, CmEndFontFace
															, CmEndColour
															, CmText				" "
															, CmLink2				1 mod.pmName ptr
															, CmColour				Red
															, CmIText				(if is_used " (used)" "")
															, CmEndColour
															, CmNewlineI			False 1 Nothing
															]
			# module_info					= (mod.pmName, ftext)
			= ([module_info:module_infos], pstate)
		show [] pstate
			= ([], pstate)