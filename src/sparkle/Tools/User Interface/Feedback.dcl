/*
** Program: Clean Prover System
** Module:  Feedback (.dcl)
** 
** Author:  Maarten de Mol
** Created: 6 December 2000
*/

definition module 
	Feedback

import 
	StdEnv,
	StdIO,
	States,
	ControlMaybe,
	MarkUpText,
	Tactics,
	RWSDebug

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: Feedback =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ fbId					:: !Id
	, fbRId					:: !RId (MarkUpMessage ProofCommand)
	, fbInfo				:: !FeedbackInfo
	, fbKind				:: !FeedbackKind
	}
inControl feedback :== feedback.fbKind == ControlFeedback
inWindow feedback  :== feedback.fbKind == (WindowFeedback zero zero)

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: FeedbackInfo =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ fiNum					:: !Int
	, fiName				:: !String
	, fiTitle				:: !String
	, fiBackground			:: !Colour
	, fiNrLines				:: !Int
	, fiItalic				:: !Bool
	, fiShow				:: !ShowFeedback
	}
instance < FeedbackInfo

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: FeedbackKind =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  ControlFeedback
	| WindowFeedback		!Vector2 !Size
instance == FeedbackKind

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: FeedbackContents			:== MarkUpText ProofCommand
:: ShowFeedback				:== Theorem *PState -> (Error, FeedbackContents, *PState)

GrayBlue					:== RGB {r=175, g=175, b=185}
// -------------------------------------------------------------------------------------------------------------------------------------------------

eventHandler				:: !(MarkUpEvent ProofCommand) !*PState -> !*PState

createFeedbackControls		:: [!Feedback] !*PState -> (ListLS (ControlMaybe (:+: (MarkUpState a) (CompoundControl (MarkUpState ProofCommand)))) ls !*PState,!*PState)
openFeedbackWindow			:: !Feedback !*PState -> !*PState
closeFeedbackWindows		:: [!Feedback] !*PState -> ([!Feedback], !*PState)
refreshFeedbacks			:: !Theorem ![Feedback] !*PState -> !*PState
updateFeedbacks				:: !ChangeLayout !FeedbackInfo ![Feedback] !*PState -> (!Bool, !Bool, ![Feedback], !*PState)