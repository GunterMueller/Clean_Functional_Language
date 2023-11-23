/*
** Program: Sparkle
** Module:  WarningStdEnv (.icl)
** 
** Author:  Maarten de Mol
** Created: 3 July 2007
*/

implementation module
	WarningStdEnv

import
	StdEnv,
	StdIO

import
	MdM_IOlib

import
	CoreTypes,
	States

// ------------------------------------------------------------------------------------------------------------------------
warningStdEnv :: ![ModulePtr] !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------
warningStdEnv ptrs pstate
	# (modules, pstate)							= accHeaps (find_stdenv ptrs) pstate
	| isEmpty modules							= pstate
	# (dialog_id, pstate)						= accPIO openId pstate
	# (ok_id, pstate)							= accPIO openId pstate
	# modules									= sortBy (\(_,n1,_)(_,n2,_)->n1<n2) modules 
	= snd (openModalDialog 0 (warningDialog modules dialog_id ok_id) pstate)
	where
		find_stdenv :: ![ModulePtr] !*CHeaps -> (![(ModulePtr, String, String)], !*CHeaps)
		find_stdenv [ptr:ptrs] heaps
			# (mod, heaps)						= readPointer ptr heaps
			# (feedback_names, heaps)			= find_stdenv ptrs heaps
			# l									= size mod.pmPath
			= case mod.pmPath%(l-8,l) == "\\StdEnv\\" || mod.pmPath%(l-7,l) == "\\StdEnv" of
				True							-> ([(ptr,mod.pmName,mod.pmPath): feedback_names], heaps)
				False							-> (feedback_names, heaps)
		find_stdenv [] heaps
			= ([], heaps)

// ------------------------------------------------------------------------------------------------------------------------
// warningDialog :: [(ModulePtr,String,String)] Id Id -> Window
// ------------------------------------------------------------------------------------------------------------------------
warningDialog modules dialog_id ok_id
	= Dialog "Warning!"
			(	MarkUpControl		[	CmColour				Red
									,	CmBText					"Warning! "
									,	CmEndColour
									,	CmText					"The following modules from the "
									,	CmBText					"normal"
									,	CmText					" StdEnv were loaded:"
									]
									[ MarkUpBackgroundColour	getDialogBackgroundColour
									, MarkUpTextColour			Black
									, MarkUpTextSize			11
									, MarkUpWidth				540
									]
									[]
			:+: boxedMarkUp			Black DoNotResize (show modules)
									[ MarkUpBackgroundColour	White
									, MarkUpTextColour			Black
									, MarkUpTextSize			9
									, MarkUpNrLinesI			7 7
									, MarkUpHScroll
									, MarkUpVScrollI			1
									, MarkUpWidth				540
									]
									[ ControlPos				(Left, zero)
									]
			:+:	MarkUpControl		[	CmText					"Sparkle may experience difficulties with handling these modules."
									,	CmNewline
									,	CmText					"Please consider using "
									,	CmBText					"{Clean}\\Libraries\\Sparkle Env\\"
									,	CmText					" instead."
									]
									[ MarkUpBackgroundColour	getDialogBackgroundColour
									, MarkUpTextColour			Black
									, MarkUpTextSize			11
									, MarkUpWidth				540
									]
									[ ControlPos				(Left, zero)
									]
			:+: ButtonControl		"Continue"
									[ ControlFunction			(noLS (closeWindow dialog_id))
									, ControlSelectState		Able
									, ControlId					ok_id
									, ControlPos				(Center, OffsetVector {vx=0,vy=20})
									]
			)
			[ WindowCancel			ok_id
			, WindowClose			(noLS (closeWindow dialog_id))
			, WindowId				dialog_id
			, WindowOk				ok_id
			]
	where
		show :: ![(ModulePtr, String, String)] -> MarkUpText a
		show [(ptr, name, path): modules]
			=	[ CmHorSpace				5
				, CmBText					name
				, CmHorSpace				15
				, CmAlign					"@Path"
				, CmText					("(" +++ path +++ ")")
				, CmNewlineI				True 1 (Just (RGB {r=235, g=235, b=235}))
				: show modules
				]
		show []
			=	[]