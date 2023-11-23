definition module EstherTransform

import EstherBackend

:: TransformException
	= CaseBadConstructorArity
	| NotSupported !String

generic transform e :: !e -> Core

dynamicTuple :: !Int -> Dynamic
dynamicCons :: Dynamic
dynamicNil :: Dynamic

derive transform EITHER, CONS, FIELD, OBJECT, Core
derive transform NTstatements

