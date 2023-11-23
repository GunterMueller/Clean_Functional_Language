definition module inputtracking

import StdMaybe
from ostypes	import :: OSWindowPtr
from iostate	import :: InputTrack,:: InputTrackKind,:: SliderTrackInfo,:: Direction, :: OSTime

trackingMouse		:: !OSWindowPtr !Int !(Maybe InputTrack) -> Bool
trackingKeyboard	:: !OSWindowPtr !Int !(Maybe InputTrack) -> Bool
trackingSlider		:: !OSWindowPtr !Int !(Maybe InputTrack) -> Bool

trackMouse			:: !OSWindowPtr !Int !(Maybe InputTrack) -> Maybe InputTrack
trackKeyboard		:: !OSWindowPtr !Int !Int !(Maybe InputTrack) -> Maybe InputTrack
trackSlider			:: !OSWindowPtr !Int !SliderTrackInfo !(Maybe InputTrack) -> Maybe InputTrack

untrackMouse		:: !(Maybe InputTrack) -> Maybe InputTrack
untrackKeyboard		:: !(Maybe InputTrack) -> Maybe InputTrack
untrackSlider		:: !(Maybe InputTrack) -> (!Maybe SliderTrackInfo,!Maybe InputTrack)
