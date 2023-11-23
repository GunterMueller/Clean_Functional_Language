definition module layoutGEC

import genericgecs

// simple lay out macro's

derive gGEC (,), (,,)						// A tuple-editor is used to place things next to each other
											// A PAIR-editor by default places things below each other

(<->) infixl 5	//:: a b -> (a,b)			// Place a and b next to each other	
(<->) x y :== (x,y)
(<|>) infixl 4	//:: a b -> (PAIR a b)		// Place a above b
(<|>) x y :== PAIR x y

:: <|> x y :== PAIR x y
:: <-> x y :== (x,y)

derive gGEC <|*>, <|*|>, <*|>, <^*>, <-*>, <.*>

:: <|*> a b 	= <|*>  infixl 2 a b			// Below and Right
:: <|*|> a b 	= <|*|> infixl 2 a b			// Below and Centered			
:: <*|> a b 	= <*|>  infixl 2 a b			// Below and Left

:: <^*> a b 	= <^*>  infixl 3 a b			// Next  and Top
:: <-*> a b 	= <-*>  infixl 3 a b			// Next  and Centered
:: <.*> a b 	= <.*>  infixl 3 a b			// Next  and Bottom			
			