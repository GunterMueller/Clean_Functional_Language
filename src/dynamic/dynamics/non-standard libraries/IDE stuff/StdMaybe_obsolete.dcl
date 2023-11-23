definition module StdMaybe

//	********************************************************************************
//	Clean Standard Object I/O library, version 1.2
//	
//	StdMaybe defines the Maybe type.
//	********************************************************************************

from	StdFunc			import St
from	StdOverloaded	import ==
//from	StdIOBasic		import IdFun
::	IdFUNMPM st
	:==	st -> st
	
::	Maybe x
	=	Just x
	|	Nothing

isJust		:: !(Maybe .x) -> Bool		// case @1 of (Just _) -> True; _ -> False
isNothing	:: !(Maybe .x) -> Bool		// not o isJust
fromJust	:: !(Maybe .x) -> .x		// \(Just x) -> x

appMaybe	:: .(IdFUNMPM .x) !(Maybe .x) -> Maybe .x
// appMaybe f (Just x) = Just (f x)
// appMaybe f Nothing  = Nothing

accMaybe	:: .(St .x .a) !(Maybe .x) -> (!Maybe .a,!Maybe .x)
// accMaybe f (Just x) = (Just (fst (f x)),Just (snd (f x)))
// accMaybe f Nothing  = (Nothing,Nothing)

mapMaybe	:: .(.x -> .y) !(Maybe .x) -> Maybe .y
// mapMaybe f (Just x) = Just (f x)
// mapMaybe f Nothing  = Nothing

instance ==       (Maybe x) | == x
//	Nothing==Nothing
//	Just a ==Just b <= a==b
