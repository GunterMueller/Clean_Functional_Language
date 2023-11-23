implementation module StdMaybe

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

isJust :: !(Maybe .x) -> Bool
isJust Nothing	= False
isJust _		= True

isNothing :: !(Maybe .x) -> Bool
isNothing Nothing	= True
isNothing _		= False

fromJust :: !(Maybe .x) -> .x
fromJust (Just x) = x

appMaybe :: .(IdFUNMPM .x) !(Maybe .x) -> Maybe .x
appMaybe f (Just x) = Just (f x)
appMaybe _ nothing	= nothing

accMaybe :: .(St .x .a) !(Maybe .x) -> (!Maybe .a,!Maybe .x)
accMaybe f (Just x)
	# (a,x) = f x
	= (Just a,Just x)
accMaybe _ nothing
	= (Nothing,nothing)

mapMaybe :: .(.x -> .y) !(Maybe .x) -> Maybe .y
mapMaybe f (Just x) = Just (f x)
mapMaybe _ nothing  = Nothing

instance == (Maybe x) | == x where
	(==) Nothing  maybe	= case maybe of
							Nothing -> True
							just    -> False
	(==) (Just a) maybe	= case maybe of
							Just b  -> a==b
							nothing -> False
