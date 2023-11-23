implementation module inputtracking

import StdOverloaded, StdInt, StdBool, StdClass
import StdMaybe
import iostate, commondef

//import dodebug
trace_n _ f :== f

inputtrackingFatalError :: String String -> .x
inputtrackingFatalError function error
	= fatalError function "inputtracking" error


//	Access operations on InputTrack:

trackingMouse :: !OSWindowPtr !Int !(Maybe InputTrack) -> Bool
trackingMouse wPtr cNr (Just {itWindow,itControl,itKind={itkMouse}})
	= wPtr==itWindow && cNr==itControl && itkMouse
trackingMouse _ _ _
	= False

trackingKeyboard :: !OSWindowPtr !Int !(Maybe InputTrack) -> Bool
trackingKeyboard wPtr cNr (Just {itWindow,itControl,itKind={itkKeyboard}})
	= wPtr==itWindow && cNr==itControl && itkKeyboard
trackingKeyboard _ _ _
	= False

trackingSlider :: !OSWindowPtr !Int !(Maybe InputTrack) -> Bool
trackingSlider wPtr cNr (Just {itWindow,itControl,itKind={itkSlider}})
	= wPtr==itWindow && cNr==itControl && isJust itkSlider
trackingSlider _ _ _
	= False


trackMouse :: !OSWindowPtr !Int !(Maybe InputTrack) -> Maybe InputTrack
trackMouse wPtr cNr (Just it=:{itWindow,itControl,itKind=itk})
	| wPtr<>itWindow || cNr<>itControl
		= inputtrackingFatalError "trackMouse" "incorrect window/control parameters"
	| otherwise
		= Just {it & itKind.itkMouse=True}
trackMouse wPtr cNr nothing
	= Just {itWindow=wPtr,itControl=cNr,itKind={itkMouse=True,itkKeyboard=False,itkChar = 0,itkSlider=Nothing}}

trackKeyboard :: !OSWindowPtr !Int !Int !(Maybe InputTrack) -> Maybe InputTrack
trackKeyboard wPtr cNr char (Just it=:{itWindow,itControl,itKind=itk})
	| wPtr<>itWindow || cNr<>itControl
		= trace_n ("trackKeyboard",(wPtr,itWindow),(cNr,itControl)) inputtrackingFatalError "trackKeyboard" "incorrect window/control parameters"
	| otherwise
		= Just {it & itKind={itk & itkKeyboard=True, itkChar = char}}
trackKeyboard wPtr cNr char nothing
	= Just {itWindow=wPtr,itControl=cNr,itKind={itkMouse=False,itkKeyboard=True,itkChar=char,itkSlider=Nothing}}

trackSlider :: !OSWindowPtr !Int !SliderTrackInfo !(Maybe InputTrack) -> Maybe InputTrack
trackSlider wPtr cNr sti  (Just it=:{itWindow,itControl,itKind=itk})
	| wPtr<>itWindow || cNr<>itControl
		= inputtrackingFatalError "trackSlider" "incorrect window/control parameters"
	| otherwise
		= Just {it & itKind.itkSlider=Just sti}
trackSlider wPtr cNr sti nothing
	= Just {itWindow=wPtr,itControl=cNr,itKind={itkMouse=False,itkKeyboard=False,itkChar=0,itkSlider=Just sti}}


untrackMouse :: !(Maybe InputTrack) -> Maybe InputTrack
untrackMouse (Just it=:{itKind=itk})
	| itk.itkKeyboard || isJust itk.itkSlider
		= Just {it & itKind={itk & itkMouse=False}}
	| otherwise
		= Nothing
untrackMouse nothing
	= nothing

untrackKeyboard :: !(Maybe InputTrack) -> Maybe InputTrack
untrackKeyboard (Just it=:{itKind=itk})
	| itk.itkMouse || isJust itk.itkSlider
		= Just {it & itKind={itk & itkKeyboard=False,itkChar=0}}
	| otherwise
		= Nothing
untrackKeyboard nothing
	= nothing

untrackSlider :: !(Maybe InputTrack) -> (!Maybe SliderTrackInfo,!Maybe InputTrack)
untrackSlider (Just it=:{itKind=itk})
	| itk.itkKeyboard || itk.itkMouse
		# it	= Just {it & itKind={itk & itkSlider=Nothing}}
		= (itk.itkSlider,it)
	| otherwise
		= (itk.itkSlider,Nothing)
untrackSlider nothing
	= (Nothing,nothing)
