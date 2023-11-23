definition module StdAGEC

import genericgecs, GecArrow

// BimapGEC:  make an a-value with a b-editor

derive gGEC BimapGEC								

:: BimapGEC a b 	
	= 	{ toGEC   :: a (Current b) -> b								// specify how to convert a into b, possibly using previous b settings
		, fromGEC :: b -> a											// specify how to convert b back to a
		, updGEC  :: (A. .ps: b -> *(PSt ps) -> *(Bool,b,*PSt ps))	// if true apply and store the new b-value
		, value   :: a												// store initial a-value, will automatically always contain latest a-value made with b-editor
		, pred    :: a -> (UpdateA,a)								// only pass through new value if its satisfies this predicate, display new value
		}


:: Current a		=	Undefined 	| Defined a				// Undefined for a new-editor, Defined when a new value is set in an existing editor
:: UpdateA			=	DontTest	| TestStore | TestStoreUpd	// resp dont apply predicate, store new value in editor, store and raise update 		

mkBimapGEC  :: (a (Current b) -> b) (A. .ps: b *(PSt .ps) -> *(Bool,b,*(PSt .ps))) (b -> a) (a -> (.UpdateA,a)) a -> .(BimapGEC a b)

to_BimapGEC 		:: (Bimap a b) a -> (BimapGEC a b)		// will TestStoreUpd

// abstract editors

derive gGEC  AGEC
derive bimap AGEC
derive ggen AGEC

:: AGEC a			// abstract GEC for an a-value maintained with a b-editor

mkAGEC  			:: !(BimapGEC a b)     !String -> AGEC a | gGEC{|*|} b
mkAGEC`  			:: !(BimapGEC a (g b)) !String -> AGEC a | gGEC{|*->*|} g // variant used to make dummy AGEC's

^^					:: (AGEC a) -> a
(^=) infixl			:: (AGEC a) a -> (AGEC a)

// conversion function for defining a gGEC specialization in terms of an AGEC

Specialize 			:: a (a -> AGEC a) (GECArgs a (PSt .ps)) !(PSt .ps) -> *(!GECVALUE a (PSt .ps),!(PSt .ps))

// conversion between implicit and explicit dictionaries

mkxAGEC  			:: (TgGEC b *(PSt .ps)) !(BimapGEC a b) !String -> AGEC a

// converting AGEC to GecCircuits and vica versa

derive gGEC GecComb

:: GecComb a b =	{ inout :: (a,b)
					, gec	 :: GecCircuit a b
					}

AGECtoCGEC :: String	(AGEC a) 		-> (GecCircuit a a) 	| gGEC{|*|}/*, generate{|*|}*/ a		// Create CGEC in indicated window 
CGECtoAGEC :: 			(GecCircuit a a ) a 	-> (AGEC a) 	| gGEC{|*|} a		// Use CGEC as AGEC 

