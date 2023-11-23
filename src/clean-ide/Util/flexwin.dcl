definition module flexwin

import StdWindow

class content_size c :: FontMetrics c -> Int

::FlexBarState s
::	FlexBarWindow s ls pst
	= FlexBarWindow Title [(String, Maybe Int)] s
		(s .Int .Int [.Int] -> (.SelectState .UpdateState -> (*Picture -> *Picture)))
		![(FlexBarState s) -> FlexBarState s]
		(R2Id (MessageIn s) (MessageOut s)) [WindowAttribute *(ls,pst)]

:: MessageIn s
	= FW_DummyIn
	| FW_SetContent s
	| FW_ApplyFunction Int
	| FW_GetContent

:: MessageOut s
	= FW_DummyOut
	| FW_ContentOut s

instance Windows (FlexBarWindow s) | content_size s

//--

appInfo :: (s->s) !(FlexBarState s) -> FlexBarState s
