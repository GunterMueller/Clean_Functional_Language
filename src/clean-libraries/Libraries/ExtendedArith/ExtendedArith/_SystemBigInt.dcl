system module _SystemBigInt

import	StdOverloaded,ExtendedArithBasics

:: BigInt	= 	{	_sign_or_number	::	!Int
				,	_limbs			::	!.{#Int}
				}
// For efficiency this type is _not_ abstract.
// Don't try to access the fields of this record.

instance zero       BigInt
instance one        BigInt
instance EqInt      BigInt
instance LessInt    BigInt
instance GreaterInt BigInt
instance +%         BigInt
instance -%         BigInt
instance %-         BigInt
instance *%         BigInt

class toBigInt a :: !a -> .BigInt

instance toBigInt   Int
