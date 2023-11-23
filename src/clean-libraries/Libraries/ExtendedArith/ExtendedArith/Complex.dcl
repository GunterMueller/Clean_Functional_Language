definition module Complex

import StdEnv

:: Complex 
	= { re	:: !Real
	  , im  :: !Real
	  }
:: Polar
	= {	magn	:: !Real
	  ,	phas	:: !Real
	  }

(:+) infix 5
(:+) re im :== { re = re, im = im }

instance +		Complex 
instance -		Complex 
instance zero	Complex

instance *		Complex 
instance /		Complex
instance one 	Complex 
	
instance == 	Complex
instance ~		Complex
instance abs	Complex

instance exp	Complex 
instance ln		Complex
instance sqrt	Complex

instance sin	Complex 
instance cos	Complex 
instance tan	Complex 
instance asin	Complex 
instance acos	Complex 
instance atan	Complex 
instance sinh	Complex 
instance cosh	Complex 
instance tanh	Complex 
instance asinh	Complex 
instance acosh	Complex 
instance atanh	Complex 

conjugate :: !Complex -> Complex
	// invert imag. part

polarToComplex :: !Polar -> Complex

complexToPolar :: !Complex -> Polar

magnitude :: !Complex -> Real

phase :: !Complex -> Real // -pi <= phase <= pi

(:^) infixr 8 :: !Complex !Real -> Complex
	// exponentiation 

cis :: !Real -> Complex
	// cis p : construct complex with magnitude 1 and phase p

signumC :: !Complex -> Complex
	// signumC c: construct complex with magnitude 1 and phase of c

realPart :: !Complex -> Real

imagPart :: !Complex -> Real
