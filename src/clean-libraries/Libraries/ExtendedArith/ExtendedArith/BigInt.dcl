definition module BigInt

import	StdOverloaded
import	ExtendedArithBasics
from	_SystemBigInt	import
		:: BigInt,
		instance zero       BigInt,
		instance one        BigInt,
		instance EqInt      BigInt,
		instance LessInt    BigInt,
		instance GreaterInt BigInt,
		instance +%         BigInt,
		instance -%         BigInt,
		instance %-         BigInt,
		instance *%         BigInt,
		class toBigInt (..),
		instance toBigInt   Int

// integers of unbounded length: 

:: NonNegBool	:== Bool // whether a number is non negative
:: Base			:== Int  // base for conversion from/to Strings, must be within [2..36]

// Comparison operators:

instance ==				BigInt
instance <				BigInt
instance isEven			BigInt
instance isOdd			BigInt

// Arithmetic:

instance +				BigInt
instance -				BigInt
//instance zero			BigInt

instance *				BigInt
instance /				BigInt				//	Truncated to 0
//instance one 			BigInt

instance ^				BigInt
instance sqrt			BigInt

instance abs 			BigInt
instance sign 			BigInt
instance ~ 				BigInt

instance mod			BigInt
instance rem			BigInt
instance gcd			BigInt
instance lcm			BigInt

quotRem :: !u:BigInt !.BigInt -> (!.BigInt,!v:BigInt), [u <= v]
	// quotient (truncated to 0) and remainder 
divMod  :: !.BigInt !.BigInt  -> (!.BigInt,!BigInt)
	// quotient (truncated to -infinity) and remainder 
powMod  :: !BigInt !BigInt !BigInt -> .BigInt
	// powMod b e m = (b^e) mod (abs m), requirements: e>=0, m<>0

// specialised versions for operations with 32 bit numbers

//instance EqInt		BigInt
//instance LessInt		BigInt
//instance GreaterInt	BigInt
//instance +%			BigInt
//instance -%			BigInt
//instance %-			BigInt
//instance *%			BigInt
instance ^%				BigInt

// conversion

instance toString BigInt
bigIntToString	::	!Base !Bool !BigInt -> String
	// Bool: digits above '9' are uppercase
stringToBigInt	::	!Base !String -> .BigInt

//class toBigInt		a	:: !a		->	.BigInt
//instance toBigInt 	Int
instance toBigInt 		{#Char}

instance toReal			BigInt
instance toInt			BigInt
	// truncates to -(2^31) resp. (2^31)-1
	
unpackBigInt :: !u:BigInt -> (!NonNegBool, !u:{#Int})
	/*	access to the internal representation. The elements of the array should be
		interpreted as unsigned 32 bit digits. 
		BigInt==zero -> the returned array is {0}
		otherwise    -> the returned array contains no trailing zeros */
packBigInt :: !NonNegBool !u:{#Int} -> u:BigInt
	/*	iff the array contains trailing zeros and the size of that array is bigger
		than one then the array will be copied */

ratioToReal :: !BigInt !BigInt -> Real
	// convert arg1/arg2 to real

// inplace operations:

(.+.)  infix  6	:: !*BigInt !*BigInt -> .BigInt // addition
(.+ )  infixl 6	:: !*BigInt ! BigInt -> .BigInt

(.-.)  infix  6	:: !*BigInt !*BigInt -> .BigInt // subtraction
(.- )  infixl 6	:: !*BigInt ! BigInt -> .BigInt
( -.)  infix  6	:: ! BigInt !*BigInt -> .BigInt

copyBigInt :: !u:BigInt -> (!.BigInt,!u:BigInt)

nrOfBits :: !BigInt -> Int
fitsIntoInt :: !BigInt -> Bool					// whether a BigInt fits into a 32 bit Int

// RWS FIXME
// the remainder of this file should not be exported, but because of
// the way names are generated in Clean 2.0 it is exported.


// *** don't use these functions ***

:: BigInt2	= 	{	sign_or_number	::	!Int
				,	limbs			::	!.{#Int}
				}
:: BigInt2`		:== BigInt2 // with this type the limbs array may also be an array with one element that fits into a single word

addBB :: !BigInt2 !BigInt2 -> BigInt2
addBS :: !BigInt2 !Int -> BigInt2
addSB :: !Int !BigInt2 -> BigInt2
add_inplace_S_UB :: !Int !*BigInt2 -> .BigInt2
add_inplace_UB_B :: !*BigInt2 !BigInt2 -> .BigInt2
add_inplace_UB_UB :: !*BigInt2 !*BigInt2 -> .BigInt2
bigIntToStringB	::	 !Int !Bool !BigInt2 -> String
copyB :: !u:BigInt -> (!.BigInt,!u:BigInt)
equalBB :: !BigInt2 !BigInt2 -> Bool
gcdBB :: !BigInt2 !BigInt2 -> BigInt
gcdSB :: !Int !BigInt2 -> BigInt
gcdSS :: !BigInt2 !Int -> BigInt2
handle_add_overflow :: !BigInt2 -> .BigInt2
handle_mult_overflow :: !Int !Int -> .BigInt2
handle_pow_overflow1 :: !Int !Int !Int -> BigInt
handle_sub_overflow :: !BigInt2 -> .BigInt2
intToString :: !Int !Bool !Int -> String
lessBB :: !BigInt2 !BigInt2 -> Bool
mulBB :: !BigInt2 !BigInt2 -> .BigInt2
mulBS :: !BigInt2 !Int -> .BigInt2
neg_minInt :: !BigInt2 -> .BigInt2
neg_minInt_0 :: .BigInt2
powBS :: !BigInt2` !Int -> .BigInt
powSB :: !Int !BigInt2 -> .BigInt2
quotBB :: !BigInt2 !BigInt2 -> BigInt2
quotBS :: !u:BigInt2 !Int -> .BigInt2
quotRemBB :: !u:BigInt2` !.BigInt2` -> (!.BigInt2,!v:BigInt2), [u <= v];
quotRemBS :: !u:BigInt2 !Int -> (!.BigInt2,!v:BigInt2), [u <= v]
quotRemI :: !Int !Int -> (!Int,!Int)
quotRemSB :: !Int !.BigInt2 -> (!.BigInt2,!v:BigInt2)
quotSB :: !Int !.BigInt2 -> .BigInt2
remBB :: !BigInt2 !BigInt2 -> BigInt2
remBS :: !BigInt2 !Int -> BigInt2
remSB :: !Int !BigInt2 -> .BigInt2
small_to_big2 :: !Int -> .BigInt2`
subBMinInt :: !BigInt2 !Int -> BigInt2
min_Int_entry2 :: !Int -> Int;
