definition module htmlRefFormlib

import htmlExceptions

// The Ref2 structure is used to refer to a file with indicated name containing a value of indicated type.
// This can be used to share information, the file name is used as key.
// The file is openend read-only (Mode = Display) or it can be edited and the new value is written to file.

:: Ref2 a			= Ref2 String
instance			== (Ref2 a)

invokeRefEditor 	:: !((InIDataId b) *HSt -> (Form d,*HSt)) !(InIDataId b) !*HSt -> (!Form b,!*HSt)

universalRefEditor 	:: !Lifespan !(InIDataId (Ref2 a)) !(a -> Judgement)     !*HSt -> (!Form a,!*HSt)	| iData a
