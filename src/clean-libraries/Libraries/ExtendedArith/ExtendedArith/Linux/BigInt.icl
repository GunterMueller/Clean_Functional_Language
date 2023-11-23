implementation module BigInt

/*	This module uses the GMP library (gnu multiple precision)
	version 2.0.2
*/

/*	Read this comment before modifying this module.
	
	Have a look at the BigInt type:

		:: BigInt	= 	{	_sign_or_number	::	!Int
						,	_limbs			::	!.{#Int}
						}

	Two different representations for numbers are used: For numbers that are
	outside the range of a 32 bit Int the _limbs array contains all bits that
	represent that number (no trailing zeros). The _sign_or_number field will
	indicate then the sign of that number: 1 means positive and -1 means
	negative. We will call these numbers "big" BigInts. "Small" BigInts (the
	numbers within -2^31 to 2^31-1) are stored in the _sign_or_number field
	itself. In that case the _limbs array will be the empty-list constructor.
	So everything in this module is _not_ typesafe!
	
	Let's have a look at the addition function to see how an exported function
	on BigInts typically is written: It is written in ABC code so untypeability
	is not a problem if you are a cool hacker. First the addition
	function will check whether it's two arguments are small BigInts by
	comparing the _limbs fields with the empty-list constructor:
		- If so, then it will execute the "addIo"
		instruction. This instruction and the "mulIo" and "subIo" instructions
		have been introduced especially for the BigInt purpose. They will
		perform the obvious arithmetic operation on the two integer arguments
		and give back two basic values: a boolean that indicates, whether this
		operation overflew and an integer which is the result of the operation.
		In case of addition or subtraction this integer can be used further to
		calculate a big BigInt result. Depending on the overflow bit we are
		ready or we have to construct a big BigInt.
		- If one of the arguments is a big BigInt then another Clean function
		is called which will then call a GMP function that performs the action.

	To enable calling Clean functions from ABC code all called functions are
	exported. In this way function "f" will get the label "e_BigInt_sf".
	It is of course impossible to offer this module to the public with all
	these nasty functions being exported. So only the ABC file of this
	module should be offered, but not the icl file. The dcl file then has
	to be made a system module and the nasty functions (all lines following
	the comment "//remove this nasty stuff before publishing") can be removed
	from the dcl.

	The type BigInt2 has been introduced to avoid the underscore "_" problem.

	The GMP library defines the "mpz" layer on top of the "mpn" layer.
	The GMP distribution includes documentation about all functions
	of these layers.
	I tried to use functions from the mpn layer whenever I could, because the
	mpn layer does no allocation. ccalls to functions beginning with "__mpn"
	belong to the mpn layer, all other ccalled functions are defined in the
	file gmp.c. There is another C file "gmp_platform.c" which is the _only_
	platform dependent file for the whole BigInt stuff. This constraint should
	be preserved. Of course there is a tiny exception: one object file that
	has to be linked with this module is called "gmp.o" on wintel and MacOS
	while it is called "gmp.a" (an archive file) on unix systems. So the
	"import code from" statement in this file varies on the platforms.

	Most mpn functions expect a pointer to some sufficient big memory into
	which they will write their result. Interfacing with such a function has
	been done like follows:
		Consider a function

			int mpn_add_1 (int * DEST_PTR, const int * SRC1_PTR, int SRC1_SIZE,
							int SRC2_LIMB)
		
		This function adds one limb to an array of limbs and writes the result
		limbs to *DESTPTR. To call this function from Clean the following trick
		is used:

			mpn_add_1 :: !*{#Int} !(!{#Int}, !Int) !Int -> (!Int, !.{#Int})
			mpn_add_1 dest_ptr (src1_ptr, src1_size) src2_limb
			    = mpn_add_1C dest_ptr (src1_ptr, src1_size) src2_limb dest_ptr 

			mpn_add_1C :: !{#Int} !(!{#Int}, !Int) !Int !{#Int}
					   -> (!Int, !.{#Int})
			mpn_add_1C _ _ _ _
    			= code {
            			ccall __gmpn_add_1 "AAII:I:A"
        			}

		Note that the last parameter of mpn_add_1C is neither passed to nor
		returned from the C function. Here the last ":A" in the ccall 
		directive plays a cruical role.
		mpn_add_1C is not referential transparent, but mpn_add_1 is, so the
		latter should be called only. In this module "wrapper" functions like
		mpn_add_1 have been made macros (the types are still there in comments).
	
	In some cases it was more practical to call mpz functions. These functions
	could allocate their own memory in the "C space". There are two approaches
	to deal with this:
		- let the mpz function allocate memory in C space and copy the result
		then into the Clean heap. The Clean function "transferGMPNumberToClean"
		does the copying. This approach has the disadvantage of unnecessary
		copying but is used in the "^" instance for BigInts (which calls powBS).
		- make sure that the mpz routine will not allocate memory. This is done
		with the "powMod" and "gcd" functions. Every mpz number contains a
		limb array that can be bigger than the size that's needed for the
		actual stored number. If this limb array is always big enough for the
		needs of the mpz function, then no reallocation will happen. So it is
		cruical to pass limb arrays to the mpz functions that are big enough and
		that are allocated in the Clean heap. By very intense looking at
		the C source code of the mpz function it was possible to find out
		the maximum memory requirements of the functions "mpz_gcd"
		and "mpz_powm". The GMP library offers a possibility to customize
		memory allocation. It has been implemented that whenever mpz_gcd or
		mpz_powm would try to allocate memory a runtime error would occur.
		The calculations of maximum memory requirements can be found in function
		"gcdBB" and "powModBBB". When this library should be ported to another
		version of GMP it had to be ensured that the assumptions about
		memory usage in "mpz_gcd" and "mpz_powm" still hold. Otherwise the
		calculations had to be adjusted.

	The mpn function mpn_sqrtrem is called for calculating the squareroot.
	This function interface is only preliminary and might change in future
	GMP versions. 

	One function from the "mpq" layer is also called: mpq_get_d.

	The instances of the classes in module StdOverloaded (the "important"
	functions) are mostly written in a way that they return a unique
	result. Unfortunately this can't be exploited because the class
	definitions specify non unique result values. In case that sometime
	somebody changes the typesystem or the definition of the classes
	in StdOverloaded, he should know that making the instances that are
	defined in this module in such a way that they return unique
	results will be not much work (perhaps no work at all).
*/

import StdEnv, _SystemBigInt
import ExtendedArithBasics
import code from "gmp.o", "gmp_platform.o"

// There must not be leading zeros in the limbs array.
// there must be no limbs, if the big int fits into a single word, otherwise sign is either +1 or -1

:: BigInt2	= 	{	sign_or_number	::	!Int
				,	limbs			::	!.{#Int}
				}
:: BigInt2`		:== BigInt2 // with this type the limbs array may also be an array with one element that fits into a single word
:: NonNegBool	:== Bool
:: Base			:== Int

bitsPerWord	:== 32
maxInt		:== 0x7fffffff
minInt		:== 0x80000000

:: Sign 	:== Int
NonNeg		:== 1
Neg			:== -1

greater :: !Int !Int -> Bool
greater i1 i2
	// order relation between _unsigned_ integers
	|	signum i1==signum i2	= i1>i2
								= i1<0
  where
	signum i
		|	i>=0	= 1
					= 0

instance ==				BigInt
  where
	(==) _ _ = code {
			eq_desc _Nil 0 0
			jmp_false fst_is_big_eq
			eq_desc _Nil 0 1
			jmp_false not_eq
			pop_a 2
			eqI
		.d 0 1 b
			rtn
		:fst_is_big_eq
			eq_desc _Nil 0 1
			jmp_true not_eq
		.d 2 2 ii
			jmp e_BigInt_sequalBB
		:not_eq
			pop_a 2
			pop_b 2
			pushB FALSE
}

equalBB :: !BigInt2 !BigInt2 -> Bool
equalBB {sign_or_number=s1, limbs=limbs1} {sign_or_number=s2, limbs=limbs2}
	| s1<>s2
		= False
	#!	size1	= size limbs1
		size2	= size limbs2
	| size1==size2
		= (mpn_cmp limbs1 limbs2 size1)==0
	= False

instance <				BigInt
  where
	(<) _ _ = code {
			eq_desc _Nil 0 0
			jmp_false fst_is_big_lt
			eq_desc _Nil 0 1
			jmp_false snd_only_is_big_lt
			pop_a 2
			ltI
		.d 0 1 b
			rtn
		:fst_is_big_lt
			eq_desc _Nil 0 1
			jmp_false both_are_big_lt
		:fst_only_is_big_lt				|| the result only depends on the sign of the big BigInt
			pop_a 2
			pushI 0
			update_b 0 2
			pop_b 1
			ltI
		.d 0 1 b
			rtn
		:snd_only_is_big_lt				|| the result only depends on the sign of the big BigInt
			pop_a 2
			pushI 0
			update_b 0 1
			pop_b 1
			ltI
		.d 0 1 b
			rtn
		:both_are_big_lt
		.d 2 2 ii
			jmp e_BigInt_slessBB
}

lessBB :: !BigInt2 !BigInt2 -> Bool
lessBB {sign_or_number=s1, limbs=limbs1} {sign_or_number=s2, limbs=limbs2}
	| s1<>s2
		= s2>0
	#!	size1	= size limbs1
		size2	= size limbs2
	| size1==size2
		#!	comparision	= mpn_cmp limbs1 limbs2 size1
		| comparision==0
			= False
		= comparision<>s1
	| size1<size2
		= s1>0
	= s1<0

instance isEven			BigInt
  where
	isEven _ = code {
			eq_desc _Nil 0 0
			jmp_false is_big_ie
			pop_a 1
		:is_on_b_stack
			pushI 1
			and%
			pushI 0
			eqI
		.d 0 1 b
			rtn
		:is_big_ie
			pop_b 1							|| push the least significant limb 
			pushI 0
			select INT 0 0
			jmp is_on_b_stack
}		

instance isOdd			BigInt
  where
	isOdd bigInt
		= not (isEven bigInt)


instance + BigInt
  where
	(+) _ _ = code {
			eq_desc _Nil 0 0
			jmp_false fst_is_big_add
			eq_desc _Nil 0 1
			jmp_false snd_only_is_big_add
			pop_a 1
			addIo
			jmp_false no_overflow_add
		.d 1 1 i
			jmp e_BigInt_shandle_add_overflow
		:no_overflow_add
		.d 1 1 i
			rtn
		:fst_is_big_add
			eq_desc _Nil 0 1
			jmp_true fst_only_is_big_add
		.d 2 2 ii
			jmp e_BigInt_saddBB
		:fst_only_is_big_add
			push_b 1
			update_b 1 2
			update_b 0 1
			pop_b 1
			update_a 0 1
			pop_a 1
		.d 1 2 ii
			jmp e_BigInt_saddSB
		:snd_only_is_big_add
			pop_a 1
		.d 1 2 ii
			jmp e_BigInt_saddSB
}

handle_add_overflow :: !BigInt2 -> .BigInt2
handle_add_overflow {sign_or_number}
	| sign_or_number<0  = { sign_or_number = 1, limbs = {sign_or_number} }
	| sign_or_number==0 = { sign_or_number = (-1), limbs = {0,1} }
			  = { sign_or_number = (-1), limbs = {~sign_or_number}}
			  	
addSB :: !Int !BigInt2 -> BigInt2
addSB i bigInt=:{sign_or_number}
	| i==0
		= bigInt
	| i<0
		| sign_or_number<0
			= add (~i) bigInt
		= sub (~i) bigInt
	| sign_or_number<0
		= sub i bigInt
	= add i bigInt

addBS :: !BigInt2 !Int -> BigInt2
addBS b i
	= addSB i b
	
add :: !Int !BigInt2 -> .BigInt2
add i {sign_or_number, limbs}
	#!	size_limbs = size limbs
		new	= create_uninitialized_int_array (inc size_limbs)
	= { sign_or_number = sign_or_number, limbs = add_1 new (limbs, size_limbs) i}

sub :: !Int !BigInt2 -> .BigInt2
sub i {sign_or_number, limbs}
	#!	size_limbs = size limbs
		new	= create_uninitialized_int_array size_limbs
		(_, diff) = mpn_sub_1 new (limbs, size_limbs) i
	= possibly_downsize sign_or_number diff size_limbs
	
possibly_downsize :: !Sign !*Limbs !Int -> .BigInt2
possibly_downsize sign_or_number limbs i
	| i==1
		#!	limb0 = limbs.[0]
		| limb0<0
			| limb0==minInt && sign_or_number<0
				= toBigInt2 minInt
			= { sign_or_number = sign_or_number, limbs = setSize limbs 1 }
		= if (sign_or_number<0) (toBigInt2 (~limb0)) (toBigInt2 limb0)
	#!	i1 = dec i
		limb_i1 = limbs.[i1]
	| limb_i1==0
		= possibly_downsize sign_or_number limbs i1
	= { sign_or_number = sign_or_number, limbs = setSize limbs i }

possibly_downsize_without_trailing_zeros :: !Sign !u:Limbs -> u:BigInt2
possibly_downsize_without_trailing_zeros sign_or_number limbs
	| size limbs==1
		#!	limb0 = limbs.[0]
		| limb0<0
			| limb0==minInt && sign_or_number<0
				= toBigInt2 minInt
			= { sign_or_number = sign_or_number, limbs = limbs }
		= if (sign_or_number<0) (toBigInt2 (~limb0)) (toBigInt2 limb0)
	= { sign_or_number = sign_or_number, limbs = limbs }

addBB :: !BigInt2 !BigInt2 -> BigInt2
addBB {sign_or_number=s1, limbs=l1} {sign_or_number=s2, limbs=l2}
	#!	size1	= size l1
		size2	= size l2
	|	s1==s2
		= { sign_or_number=s1, limbs=addLimbs (l1, size1) (l2, size2) }
	|	s2>0
		= subtract subtract_copy_continuation (l2, size2) (l1, size1)
	= subtract subtract_copy_continuation (l1, size1) (l2, size2)

(.+.)  infix 6	:: !*BigInt !*BigInt -> .BigInt
(.+.) _ _ = code {
			eq_desc _Nil 0 0
			jmp_false fst_is_big_addiuu
			eq_desc _Nil 0 1
			jmp_false snd_only_is_big_addiuu
			pop_a 1
			addIo
			jmp_false no_overflow_addiuu
		.d 1 1 i
			jmp e_BigInt_shandle_add_overflow
		:no_overflow_addiuu
		.d 1 1 i
			rtn
		:fst_is_big_addiuu
			eq_desc _Nil 0 1
			jmp_true fst_only_is_big_addiuu
		.d 2 2 ii
			jmp e_BigInt_sadd_inplace_UB_UB
		:fst_only_is_big_addiuu
			push_b 1
			update_b 1 2
			update_b 0 1
			pop_b 1
			update_a 0 1
			pop_a 1
		.d 1 2 ii
			jmp e_BigInt_sadd_inplace_S_UB
		:snd_only_is_big_addiuu
			pop_a 1
		.d 1 2 ii
			jmp e_BigInt_sadd_inplace_S_UB
	}

add_inplace_S_UB :: !Int !*BigInt2 -> .BigInt2
add_inplace_S_UB i bigInt=:{sign_or_number}
	| i<0
		| sign_or_number<0
			= addLimb_inplace bigInt (~i)
		= subLimb_inplace bigInt (~i)
	| sign_or_number<0
		= subLimb_inplace bigInt i
	= addLimb_inplace bigInt i
  where
	addLimb_inplace {sign_or_number, limbs} i
		#!	size_limbs = size limbs
			(carry, sum) = mpn_add_1_inplace limbs size_limbs i
		| carry==0
			= { sign_or_number = sign_or_number, limbs = sum }
		= { sign_or_number = sign_or_number, limbs = append_limb (sum, size_limbs) carry }
	
	subLimb_inplace {sign_or_number, limbs} i
		#!	size_limbs = size limbs
			(_, diff) = mpn_sub_1_inplace limbs size_limbs i
		= possibly_downsize sign_or_number diff size_limbs
		
add_inplace_UB_UB :: !*BigInt2 !*BigInt2 -> .BigInt2
add_inplace_UB_UB {sign_or_number=s1, limbs=l1} {sign_or_number=s2, limbs=l2}
	#!	size1	= size l1
		size2	= size l2
	|	s1==s2
		| size1>=size2
			= { sign_or_number=s1, limbs=addLimbs_inplace (l1, size1) (l2, size2) }
		= { sign_or_number=s1, limbs=addLimbs_inplace (l2, size2) (l1, size1) }
	|	s2>0
		= subtract subtract_inplace_continuation (l2, size2) (l1, size1)
	= subtract subtract_inplace_continuation (l1, size1) (l2, size2)

(.+ )  infixl 6	:: !*BigInt ! BigInt -> .BigInt
(.+ ) _ _ = code {
			eq_desc _Nil 0 0
			jmp_false fst_is_big_addiu
			eq_desc _Nil 0 1
			jmp_false snd_only_is_big_addiu
			pop_a 1
			addIo
			jmp_false no_overflow_addiu
		.d 1 1 i
			jmp e_BigInt_shandle_add_overflow
		:no_overflow_addiu
		.d 1 1 i
			rtn
		:fst_is_big_addiu
			eq_desc _Nil 0 1
			jmp_true fst_only_is_big_addiu
		.d 2 2 ii
			jmp e_BigInt_sadd_inplace_UB_B
		:fst_only_is_big_addiu
			push_b 1
			update_b 1 2
			update_b 0 1
			pop_b 1
			update_a 0 1
			pop_a 1
		.d 1 2 ii
			jmp e_BigInt_sadd_inplace_S_UB
		:snd_only_is_big_addiu
			pop_a 1
		.d 1 2 ii
			jmp e_BigInt_saddSB
	}

add_inplace_UB_B :: !*BigInt2 !BigInt2 -> .BigInt2
add_inplace_UB_B {sign_or_number=s1, limbs=l1} {sign_or_number=s2, limbs=l2}
	#!	size1	= size l1
		size2	= size l2
	|	s1==s2
		| size1>=size2
			= { sign_or_number=s1, limbs=addLimbs_inplace (l1, size1) (l2, size2) }
		= { sign_or_number=s1, limbs=addLimbs (l2, size2) (l1, size1) }
	|	s2>0
		= subtract_inplace_SU (l2, size2) (l1, size1)
	= subtract_inplace_US (l1, size1) (l2, size2)

addLimbs :: !LimbsWithSize !LimbsWithSize -> .Limbs
addLimbs (l1, size1) (l2, size2)
	| size1>=size2
		= continuation (l1, size1) (l2, size2)
	= continuation (l2, size2) (l1, size1)
  where
	continuation long=:(_, lSize) short
		#!	new	= create_uninitialized_int_array (inc lSize)
			(carry, sum) = mpn_add new long short
		| carry<>0
			= { sum & [lSize]=carry }
		= setSize sum lSize

addLimbs_inplace :: !(!*Limbs, !Size) !LimbsWithSize -> .Limbs
/* inplace addition, which destructively updates the first parameter
   the following assertions should hold for (addLimbs_inplace (l1,s1) (l1,s2))
	size l1=s1>0, size l2=s2>0, s1>=s2
*/ 
addLimbs_inplace (long_limbs, lSize) short
	#!	(carry, sum) = mpn_add_inplace long_limbs lSize short
	| carry==0
		= sum
	= append_limb (sum, lSize) carry

append_limb :: !LimbsWithSize !Limb -> .Limbs
append_limb (array, array_size) limb 
	#!	new	= create_uninitialized_int_array (inc array_size)
		sum	= copyArray new array array_size
	= { sum & [array_size]=limb }
  where
	copyArray :: !*{#Int} !{#Int} !Int -> .{#Int}
	copyArray dest src i
		|	i==0
			= dest
		#!	i1	= dec i
		= copyArray { dest & [i1]=src.[i1] } src i1

//subtract :: (LimbsWithSize LimbsWithSize -> {#Int}) LimbsWithSize LimbsWithSize -> .BigInt2
/*	This macro is used to subtract two numbers.
	the continuation are either subtract_copy_continuation subtract_inplace_continuation
	both form an BigInt by subtracting the two LimbsWithSize parameters.
	continuation (l1, size1) (l2, size2) can rely on the following facts:
		size l1>=size1>0, size l2>=size2>0, size1>=size2,
		(l1 % (0,size1-1)) (as a number) is bigger than (l2 % (0, size2-1)) (as a number)
	The two mentioned continuations do this
*/
subtract continuation lws1 lws2
	:== subtract lws1 lws2
  where
	subtract (l1, size1) (l2, size2)
		| size1==size2
			= subtract_with_equal_length l1 l2 size1
		| size1>size2
			= continuation NonNeg (l1, size1) (l2, size2) 
		= continuation Neg (l2, size2) (l1, size1)
	subtract_with_equal_length l1 l2 0
		= toBigInt2 0
	subtract_with_equal_length l1 l2 i
		#!	i1	= dec i
			l1i	= l1.[i1]
			l2i	= l2.[i1]
		| l1i==l2i
			= subtract_with_equal_length l1 l2 i1
		| greater l1i l2i
			= continuation NonNeg (l1,i) (l2,i)
		= continuation Neg (l2,i) (l1,i)	

subtract_copy_continuation sign long=:(_,lSize) short
// used for non inplace subtraction. see comment for subtract
	#!	new	= create_uninitialized_int_array lSize
		(_, diff) = mpn_sub new long short
	= possibly_downsize sign diff lSize

subtract_inplace_continuation sign (long_limbs,lSize) short
// used for inplace subtraction. see comment for subtract
	#!	(_, diff) = mpn_sub_inplace long_limbs lSize short
	= possibly_downsize sign diff lSize
									
subtract_inplace_SU :: !LimbsWithSize !(!*Limbs, !Size) -> .BigInt2
// inplace subtraction: first argument is shared, second will be updated
subtract_inplace_SU (l1, size1) (l2, size2)
	| size1==size2
		= subtract_inplace_with_equal_length NonNeg l1 l2 size1
	| size1>size2
		= subtract subtract_copy_continuation (l1, size1) (l2, size2)
	= subtract_inplace_continuation Neg (l2, size2) (l1, size1)

subtract_inplace_US :: !(!*Limbs, !Size) !LimbsWithSize -> .BigInt2
// inplace subtraction: first argument will be updated, second is shared
subtract_inplace_US (l1, size1) (l2, size2)
	| size1==size2
		= subtract_inplace_with_equal_length Neg l2 l1 size1
	| size1>size2
		= subtract_inplace_continuation NonNeg (l1, size1) (l2, size2)
	= subtract subtract_copy_continuation (l1, size1) (l2, size2)

subtract_inplace_with_equal_length :: !Sign !{#.Int} !*{#.Int} !Int -> .BigInt2;
/*	subtract_inplace_with_equal_length x_sign l1 l2 i calculates the difference
	(l1 % (0,i-1)) - (l2 % (0,-1)) (arrays interpreted as a positive number
	i>0 !
	iff the Boolean is False, the sign of the result will be negated
*/
subtract_inplace_with_equal_length _ l1 l2 0
	= toBigInt2 0
subtract_inplace_with_equal_length x_sign l1 l2 i
	#!	i1	= dec i
		l1i	= l1.[i1]
		l2i	= l2.[i1]
	| l1i==l2i
		= subtract_inplace_with_equal_length x_sign l1 l2 i1
	| greater l1i l2i
		= subtract_big_small_inplace_SU x_sign l1 l2 i
	= subtract_inplace_continuation (~x_sign) (l2,i) (l1,i)			

subtract_big_small_inplace_SU :: !Sign !.Limbs !*Limbs !.Size -> .BigInt2
subtract_big_small_inplace_SU sign l1 l2 i
// calculate (l1 % (0,i-1))-(l2 % (0,i-1))
// the problem: l1 % (0,i-1) is bigger than l2 % (0,i-1), but the operation should
// change (unique) l2
// i>0 && (sign==-1 || sign==1)
	#!	(_, diff)	= mpn_sub_inplace l2 i (l1, i)	// diff is a negative number
		nr_effective_words= count_effective_words diff i
	| nr_effective_words==0								// the difference is 1
		= toBigInt2 sign
	// 0<nr_effective_words<=i
	// diff.[dec nr_effective_words]<>(-1), and [diff.[i]==(-1) \\ i [nr_effective_words..(dec i)]]
	#!	diff	= invert diff nr_effective_words						// make diff positive by calculating the complement
		(carry, diff)= mpn_add_1_inplace diff nr_effective_words 1	// and adding one
	| carry==0
		= possibly_downsize_without_trailing_zeros sign (setSize diff nr_effective_words)
	= { sign_or_number = sign, limbs = setSize { diff & [nr_effective_words]=1 } (inc nr_effective_words) }
  where
	count_effective_words :: !.Limbs !Int -> Int
	count_effective_words limbs i
		|	i==0
			= 0
		#	i1 = dec i
		| limbs.[i1]==(-1)
			= count_effective_words limbs i1
		= i
	invert :: !*Limbs !Int -> .Limbs
	// invert l i: invert l[j] where j<-[0..i-1]
	invert limbs i
		| i==0	= limbs
		#!	i1			= dec i
			limbs_i1	= limbs.[i1]
		= invert { limbs & [i1]=bitnot limbs_i1 } i1

instance -				BigInt
  where
	(-) _ _ = code {
		.export int_min_BigInt_entry
			eq_desc _Nil 0 0
			jmp_false fst_is_big_sub
			eq_desc _Nil 0 1
			jmp_false snd_only_is_big_sub
			pop_a 1
			subIo
			jmp_false no_overflow_sub
		.d 1 1 i
			jmp e_BigInt_shandle_sub_overflow
		:no_overflow_sub
		.d 1 1 i
			rtn
		:fst_is_big_sub
			eq_desc _Nil 0 1
			jmp_true fst_only_is_big_sub
		:both_are_big_add					|| so negate the second argument and add the numbers
			push_b 1
			pushI 0
			subI
			update_b 0 2
			pop_b 1
		.d 2 2 ii
			jmp e_BigInt_saddBB
		:snd_only_is_big_sub				|| so negate the second argument and add the numbers
			pop_a 1
		.o 1 2 ii
		:int_min_BigInt_entry
			push_b 1
			pushI 0
			subI
			update_b 0 2
			pop_b 1
		.d 1 2 ii
			jmp e_BigInt_saddSB
		:fst_only_is_big_sub				|| check out whether the small argument can be negated easily
			update_a 0 1						|| get rid of one superfluous constructor
			pop_a 1
		:bigInt_min_Int_entry
			push_b 1							|| B afterwards: x sign x
			pushI -2147483648					|| B afterwards: x sign x minInt
			eqI									|| B afterwards: x sign (x==minInt)
			jmp_false can_be_negated_sub		|| B afterwards: x sign
		.d 1 2 ii
			jmp e_BigInt_ssubBMinInt
		:can_be_negated_sub
			push_b 1							|| B afterwards: x sign x
			pushI 0								|| B afterwards: x sign x 0
			subI								|| B afterwards: x sign -x
			update_b 1 2						|| B afterwards: sign sign -x
			update_b 0 1						|| B afterwards: sign -x -x
			pop_b 1								|| B afterwards: sign -x
		.d 1 2 ii
			jmp e_BigInt_saddSB 
}

handle_sub_overflow :: !BigInt2 -> .BigInt2
handle_sub_overflow {sign_or_number}
	| sign_or_number<0  = { sign_or_number = 1, limbs = {sign_or_number} }
	// sign_or_number>0
			  = { sign_or_number = (-1), limbs = {~sign_or_number}}

subBMinInt :: !BigInt2 !Int -> BigInt2
subBMinInt big minInt
	= addBB big (u_negate2 (small_to_big2 minInt))

(.-.)  infix  6	:: !*BigInt !*BigInt -> .BigInt
(.-.) x y = x .+. (u_negate y)
(.- )  infixl 6	:: !*BigInt ! BigInt -> .BigInt
(.- ) x y = x .+ (u_negate y)
( -.)  infix  6	:: ! BigInt !*BigInt -> .BigInt
( -.) x y = (u_negate y) .+ x

copyBigInt :: !u:BigInt -> (!.BigInt,!u:BigInt)
copyBigInt _ = code {
			eq_desc _Nil 0 0
			jmp_false is_big_copy
			push_a 0
			push_b 0
		.d 2 2 ii
			rtn
		:is_big_copy
		.d 1 1 i
			jmp e_BigInt_scopyB
		}

copyB :: !u:BigInt -> (!.BigInt,!u:BigInt)
copyB b
	#!	(nonNeg, limbs) = unpackBigInt b
		size_limbs = size limbs
		new = create_uninitialized_int_array size_limbs
		(copy, limbs) = copy new limbs size_limbs
	= (packBigInt nonNeg copy, packBigInt nonNeg limbs)
  where
	copy :: !*{#Int} !u:{#Int} !Int -> (!.{#Int}, !u:{#Int})
	copy new limbs i
		| i==0
			= (new, limbs)
		#!	i1 = dec i
		 	limbs_i1 = limbs.[i1]
		 = copy { new & [i1] = limbs_i1 } limbs i1

instance *				BigInt
  where
	(*) _ _ = code {
			eq_desc _Nil 0 0
			jmp_false fst_is_big_mul
			eq_desc _Nil 0 1
			jmp_false snd_only_is_big_mul
			pop_a 1
			push_b 1
			push_b 1
			mulIo
			jmp_true mult_overflow
		.d 1 1 i
			update_b 0 2
			pop_b 2
			rtn
		:mult_overflow
			pop_b 1
			pop_a 1
		.d 0 2 ii
			jmp e_BigInt_shandle_mult_overflow
		:fst_is_big_mul
			eq_desc _Nil 0 1
			jmp_true fst_only_is_big_mul
		.d 2 2 ii
			jmp e_BigInt_smulBB
		:fst_only_is_big_mul
			update_a 0 1
			pop_a 1
		.d 1 2 ii
			jmp e_BigInt_smulBS
		:snd_only_is_big_mul
			push_b 1
			update_b 1 2
			update_b 0 1
			pop_b 1
			pop_a 1
		.d 1 2 ii
			jmp e_BigInt_smulBS
}

abs` i :== if (i<0) (~i) i

handle_mult_overflow :: !Int !Int -> .BigInt2
handle_mult_overflow i1 i2
	= mulBS (small_to_big2 i1) i2

mulBS :: !BigInt2 !Int -> .BigInt2
mulBS bigInt=:{ sign_or_number, limbs } i
	| i==0
		= toBigInt2 0
	| i==minInt
		= mulBB { sign_or_number=Neg, limbs={minInt}} bigInt
	#!	size_limbs = size limbs
		new	= create_uninitialized_int_array (inc size_limbs)
		(msl, product) = mpn_mul_1 new (limbs, size_limbs) (abs` i)
		new_sign = if (i<0) (~sign_or_number) sign_or_number
	| msl<>0
		= { sign_or_number = new_sign, limbs = { product & [size_limbs]=msl } }
	= { sign_or_number = new_sign, limbs = setSize product size_limbs }
	
mulBB :: !BigInt2 !BigInt2 -> .BigInt2
mulBB {sign_or_number=s1, limbs=l1} {sign_or_number=s2, limbs=l2} 
	= {sign_or_number=signsrule s1 s2,limbs=multdigs l1 l2}
	
multdigs :: !Limbs !Limbs -> .Limbs
// calculate product, limbs are both <>0
multdigs l1 l2
	#!	size1	= size l1
		size2	= size l2
		newSize	= size1+size2
		new		= create_uninitialized_int_array newSize
		(long, short)	= if (size1>=size2)	((l1,size1), (l2,size2))
											((l2,size2), (l1,size1))
		(most_sig_limb, product)	=  mpn_mul new long short
	| most_sig_limb==0
		= setSize product (dec newSize)
	= product


signsrule signx signy = if (signx==signy) 1 (-1)

instance /				BigInt				//	Truncated to 0
  where
	(/) _ _ = code {
			eq_desc _Nil 0 0
			jmp_false fst_is_big_div
			eq_desc _Nil 0 1
			jmp_false snd_only_is_big_div
			pop_a 1
			pushI 1							|| B afterwards: denom nom 1
			push_b 2						|| B afterwards: denom nom 1 denom
			ltI								|| B afterwards: denom nom (denom<1)
			jmp_false cant_overflow_div		|| B afterwards: denom nom
			pushI -1						|| B afterwards: denom nom -1
			push_b 2						|| B afterwards: denom nom -1 denom
			ltI								|| B afterwards: denom nom (denom< -1)
			jmp_true cant_overflow_div		|| B afterwards: denom nom
			|| -1<=denom<=0, check for division by zero or overflow (minInt/-1)
			pushI -1						|| B afterwards: denom nom -1
			push_b 2						|| B afterwards: denom nom -1 denom
			eqI								|| B afterwards: denom nom (denom== -1)
			jmp_true check_overflow_div		|| B afterwards: denom nom
		:div_by_zero_div
			pop_b 2
			buildAC "BigInt division by zero"
		.d 1 0
			jsr e_StdMisc_sabort
		:check_overflow_div					|| B           : -1 nom
			pushI -2147483648				|| B afterwards: -1 nom minInt
			push_b 1						|| B afterwards: -1 nom minInt nom
			eqI								|| B afterwards: -1 nom (nom==minInt)
			jmp_true is_overflown_div		|| B afterwards: -1 nom
			pushI 0 						|| B afterwards: -1 nom 0
			update_b 1 2					|| B afterwards: nom nom 0
			update_b 0 1					|| B afterwards: nom 0 0
			pop_b 1							|| B afterwards: nom 0
			subI							|| B afterwards: (nom/denom) where denom== -1
		.d 1 1 i
			rtn
		:is_overflown_div					|| B           : -1 nom
			pop_b 2							|| B afterwards:
			pop_a 1
		.d 0 0
			jmp e_BigInt_sneg_minInt_0
		:cant_overflow_div					|| B           : denom nom
			divI							|| B afterwards: (nom/denom)
		.d 1 1 i
			rtn
		:fst_is_big_div
			eq_desc _Nil 0 1
			jmp_false both_are_big_div
		:fst_only_is_big_div				|| B           : denom nom
			update_a 0 1					|| get rid of the superfluous constructor
			pop_a 1
		.d 1 2 ii
			jmp e_BigInt_squotBS
		:snd_only_is_big_div
			pop_a 1							|| get rid of the superfluous constructor
		.d 1 2 ii
			jmp e_BigInt_squotSB
		:both_are_big_div
		.d 2 2 ii
			jmp e_BigInt_squotBB
}

quotBB :: !BigInt2 !BigInt2 -> BigInt2
quotBB x y
	= fst (quotRemBB x y)

quotBS :: !u:BigInt2 !Int -> .BigInt2
quotBS big small 
	= fst (quotRemBB big (small_to_big2 small))

quotSB :: !Int !.BigInt2 -> .BigInt2
// here's further place for optimisations
quotSB small big = fst (quotRemBB (small_to_big2 small) big)

/*
power :: !Int !Int -> Int
power b e
	| e<0
		= abort "^ (BigInt) called with negative power argument"
	| e<2
		= if (e==0) 1 b
	= loop b (e-1) b
  where
	result is accu*(b^e)
	loop b e accu
		| e==1
			= accu*b
		= loop (b*b) (e>>1) (if (isOdd e) (accu*b) accu)
*/

instance ^ BigInt
  where
	(^) b e = code {
			eq_desc _Nil 0 0
			jmp_false base_is_big_pow
			eq_desc _Nil 0 1
			jmp_false exp_only_is_big_pow
			pop_a 1
			pushI 0					|| B afterwards: e b 0
			push_b 2				|| B afterwards: e b 0 e
			ltI						|| B afterwards: e b (e<0)
			jmp_false parameter_ok	|| B afterwards: e b
		:parameter_not_ok
			buildAC "^ (BigInt) undefined for negative exponents"
		.d 1 0
			jsr e_StdMisc_sabort
		:parameter_ok
			pushI 2					|| B afterwards: e b 2
			push_b 2				|| B afterwards: e b 2 e
			ltI						|| B afterwards: e b (e<2)
			jmp_false enter_loop	|| B afterwards: e b
			pushI 0					|| B afterwards: e b 0
			push_b 2				|| B afterwards: e b 0 e
			eqI						|| B afterwards: e b (e==0)
			jmp_true result_is_one	|| B afterwards: e b
		:exponent_is_one
			update_b 0 1			|| B afterwards: b b
			pop_b 1					|| B afterwards: b
		.d 1 1 i
			rtn
		:result_is_one				|| B           : e b
			pop_b 2					|| B afterwards:
			pushI 1					|| B afterwards: 1
		.d 1 1 i
			rtn
		:enter_loop
			pushI 1					|| B afterwards: e b 1
			push_b 2				|| B afterwards: e b 1 e
			subI					|| B afterwards: e b (e-1)
			update_b 0 2			|| B afterwards: (e-1) b (e-1)
			update_b 1 0			|| B afterwards: (e-1) b b
		:loop						|| B           : e b accu 			(new scope)
			push_b 2				|| B afterwards: e b accu e
			pushI 1					|| B afterwards: e b accu e 1
			eqI						|| B afterwards: e b accu (e==1)			
			jmp_true return_accu_b	|| B afterwards: e b accu
			push_b 1				|| B afterwards: e b accu b
			push_b 0				|| B afterwards: e b accu b b
			mulIo					|| B afterwards: e b accu (b*b) overflow
			jmp_true overflow1_pow	|| B afterwards: e b accu (b*b)
			push_b 3				|| B afterwards: e b accu (b*b) e
			pushI 1					|| B afterwards: e b accu (b*b) e 1
			and% 					|| B afterwards: e b accu (b*b) (e bitand 1) 
			pushI 0					|| B afterwards: e b accu (b*b) (e bitand 1) 0
			eqI						|| B afterwards: e b accu (b*b) (isEven e)
			jmp_true is_even		|| B afterwards: e b accu (b*b)
		:is_odd
			push_b 2				|| B afterwards: e b accu (b*b) b
			push_b 2				|| B afterwards: e b accu (b*b) b accu
			mulI					|| B afterwards: e b accu (b*b) (accu*b)     (can't overflow)
			update_b 0 2			|| B afterwards: e b (accu*b) (b*b) (accu*b)
			pop_b 1					|| B afterwards: e b (accu*b) (b*b)
		:is_even					|| B           : e b (if (isOdd e) (accu*b) accu) (b*b)
			update_b 0 2			|| B afterwards: e (b*b) (if (isOdd e) (accu*b) accu) (b*b)
			pushI 1					|| B afterwards: e (b*b) (if (isOdd e) (accu*b) accu) (b*b) 1
			update_b 0 1			|| B afterwards: e (b*b) (if (isOdd e) (accu*b) accu) 1 1
			update_b 4 0			|| B afterwards: e (b*b) (if (isOdd e) (accu*b) accu) 1 e
			shiftr%					|| B afterwards: e (b*b) (if (isOdd e) (accu*b) accu) (e>>1)
			update_b 0 3			|| B afterwards: (e>>1) (b*b) (if (isOdd e) (accu*b) accu) (e>>1)
			pop_b 1					|| B afterwards: (e>>1) (b*b) (if (isOdd e) (accu*b) accu)
			jmp loop
		:return_accu_b				|| B           : e b accu
			update_b 0 2			|| B afterwards: accu b accu
			push_b 1				|| B afterwards: accu b accu b
			mulIo					|| B afterwards: accu b (accu*b) overflow
			jmp_true overflow2_pow	|| B afterwards: accu b (b*accu)
			update_b 0 2			|| B afterwards: (b*accu) b (b*accu)
			pop_b 2					|| B afterwards: (b*accu)
		.d 1 1 i
			rtn
		:base_is_big_pow
			eq_desc _Nil 0 1
			jmp_false too_big_pow
		:base_only_is_big_pow
			update_a 0 1
			pop_a 1
		.d 1 2 ii
			jmp e_BigInt_spowBS
		:too_big_pow
			buildAC "^ (BigInt) with too big exponent"
		.d 1 0
			jsr e_StdMisc_sabort
		:exp_only_is_big_pow
			pop_a 1
		.d 1 2 ii
			jmp e_BigInt_spowSB
		:overflow1_pow				|| B           : e b accu trash		(result should be accu*(b^e))
			pop_b 1					|| B afterwards: e b accu
			pop_a 1
		.d 0 3 iii
			jmp e_BigInt_shandle_pow_overflow1
		.d 1 0
			jsr e_StdMisc_sabort
		:overflow2_pow				|| B           : accu b trash
			pop_b 1					|| B afterwards: accu b
			pop_a 1
		.d 0 2 ii
			jmp e_BigInt_shandle_mult_overflow
		}

handle_pow_overflow1 :: !Int !Int !Int -> BigInt
handle_pow_overflow1 accu b e
	// return accu*(b^e)
	= (toBigInt accu)*(powBS (small_to_big2 b) e)
	
powSB :: !Int !BigInt2 -> .BigInt2
powSB 0 e
	= toBigInt2 0
powSB 1 e
	= toBigInt2 1
powSB (-1) {limbs}
	| isOdd limbs.[0]
		= toBigInt2 (-1)
		= toBigInt2 1
powSB _ _
	= abort "^ (BigInt) exponent too big"

powBS :: !BigInt2` !Int -> .BigInt
powBS base expLimb
	| expLimb<0
		= abort "^ (BigInt) undefined for negative exponents"
	| expLimb==0
		= toBigInt 1
	// let GMP calculate the result within C memory and copy it into the heap then
	#!	(gmpSize, resultPtr)	= pow_uiC base expLimb
		size_					= abs gmpSize
		new						= create_uninitialized_int_array size_
		result					= transferGMPNumberToClean new resultPtr size_
	= bigInt2ToBigInt { sign_or_number=if (gmpSize>=0) NonNeg Neg, limbs=result }

instance abs 			BigInt
  where
	abs _ = code {
			eq_desc _Nil 0 0
			jmp_false is_big_abs
			pushI 0
			push_b 1
			ltI 
			jmp_true negate
		.d 1 1 i
			rtn
		:negate
			push_b 0
			pushI -2147483648	|| minInt
			eqI
			jmp_false can_be_negated_abs
		.d 1 1 i
			jmp e_BigInt_sneg_minInt
		:can_be_negated_abs
			pushI 0
			subI
		.d 1 1 i
			rtn
		:is_big_abs
			pop_b 1
			pushI 1
}	

instance sign 			BigInt
  where
	sign _ = code {
			eq_desc _Nil 0 0
			jmp_false is_big_sign
			pop_a 1
			push_b 0
			pushI 0
			eqI
			jmp_true is_small_zero_sign
			pushI 0
			gtI
			jmp_true is_negative_sign
		:is_positive_sign
			pushI 1
		.d 0 1 i
			rtn
		:is_negative_sign
			pushI -1
		.d 0 1 i
			rtn
		:is_small_zero_sign
			pushI 0
			update_b 0 1
			pop_b 1
		.d 0 1 i
			rtn
		:is_big_sign
			pop_a 1
}	

instance ~ 				BigInt
  where
	(~) bigInt = u_negate bigInt

u_negate :: !.BigInt -> .BigInt
u_negate _ = code {
			eq_desc _Nil 0 0
			jmp_false just_negate_sign
			push_b 0
			pushI -2147483648 		|| == 0x800000 == minInt
			eqI
			jmp_false just_negate_sign
		.d 1 1 i
			jmp e_BigInt_sneg_minInt
		:just_negate_sign
			pushI 0					|| just negate the sign
			subI
	}

u_negate2 :: !.BigInt2 -> .BigInt2
u_negate2 _ = code {
			eq_desc _Nil 0 0
			jmp_false just_negate_sign2
			push_b 0
			pushI -2147483648 		|| == 0x800000 == minInt
			eqI
			jmp_false just_negate_sign2
		.d 1 1 i
			jmp e_BigInt_sneg_minInt
		:just_negate_sign2
			pushI 0					|| just negate the sign
			subI
	}

neg_minInt :: !BigInt2 -> .BigInt2
neg_minInt _
	= { sign_or_number=NonNeg, limbs={minInt}}

neg_minInt_0 :: .BigInt2
neg_minInt_0
	= { sign_or_number=NonNeg, limbs={minInt}}

instance gcd			BigInt
  where
	gcd _ _ = code {
			eq_desc _Nil 0 0
			jmp_false fst_is_big_gcd
			eq_desc _Nil 0 1
			jmp_false snd_only_is_big_gcd
			pop_a 1
		.d 1 2 ii
			jsr e_BigInt_sgcdSS
		.o 1 1 i
		.d 1 1 i
			rtn
		:fst_is_big_gcd
			eq_desc _Nil 0 1
			jmp_true fst_only_is_big_gcd
		.d 2 2 ii
			jmp e_BigInt_sgcdBB
		:fst_only_is_big_gcd
			push_b 1
			update_b 1 2
			update_b 0 1
			pop_b 1
			update_a 0 1
			pop_a 1
		.d 1 2 ii
			jmp e_BigInt_sgcdSB 
		:snd_only_is_big_gcd
			pop_a 1
		.d 1 2 ii
			jmp e_BigInt_sgcdSB
		}
	
min_Int_entry2 :: !Int -> Int;
min_Int_entry2 _ = code {
		.d 0 1 i
			rtn

		.export bigInt_min_Int_entry2
			.o 1 2 ii
		:bigInt_min_Int_entry2
			push_b 1							|| B afterwards: x sign x
			pushI -2147483648					|| B afterwards: x sign x minInt
			eqI									|| B afterwards: x sign (x==minInt)
			jmp_false can_be_negated_subi		|| B afterwards: x sign
		.d 1 2 ii
			jmp e_BigInt_ssubBMinInt
		:can_be_negated_subi
			push_b 1							|| B afterwards: x sign x
			pushI 0								|| B afterwards: x sign x 0
			subI								|| B afterwards: x sign -x
			update_b 1 2						|| B afterwards: sign sign -x
			update_b 0 1						|| B afterwards: sign -x -x
			pop_b 1								|| B afterwards: sign -x
		.d 1 2 ii
			jmp e_BigInt_saddSB
		}
	
instance ^% BigInt
  where
	(^%) base exp
		= base ^ (toBigInt exp)
		
gcdSS :: !BigInt2 !Int -> BigInt2
gcdSS big=:{sign_or_number=a} b
	| a==0
		| b==0				= { big & sign_or_number = 0 }	// gcd 0 0 == 0
		| b==minInt			= neg_minInt_0			// gcd 0 minInt == -minInt
							= { big & sign_or_number = abs b }
	| a==minInt
		| b==minInt	|| b==0	= neg_minInt_0			// gcd minInt 0 == -minInt, gcd minInt minInt == -minInt
							= { big & sign_or_number = gcd_with_minInt b }
	| b==minInt				= { big & sign_or_number = gcd_with_minInt a }
							= { big & sign_or_number = gcd a b }

gcd_with_minInt x // = gcd minInt x
	// x<>0
	:== let ax = abs x
		in gcd ax (~(minInt rem ax))

gcdSB :: !Int !BigInt2 -> BigInt
gcdSB s b = gcdBB (small_to_big2 s) b

gcdBB :: !BigInt2 !BigInt2 -> BigInt
gcdBB u=:{limbs=ul} v=:{limbs=vl}
	#!	su	= size ul
		sv	= size vl
		tzu	= trailingZeros ul su 0
		tzv	= trailingZeros vl sv 0
		neededSize = (max tzu tzv)+sv-tzv+1
		new = create_uninitialized_int_array neededSize
	= downsizeWithMPZ_Size (gmp_gcd new u v)
  where
	trailingZeros limbs size_ index
		|	index>=size_		= if (index==1) 0 (abort "BigInt: violation of internal constraint")
		|	limbs.[index]<>0	= inc index
			= trailingZeros limbs size_ (inc index)

instance lcm			BigInt
  where
	lcm x y 
	| isZero x || isZero y	= zero
	| otherwise 			= abs ((x / gcd x y) * y)

downsizeWithMPZ_Size :: !(!Int,!*Limbs) -> .BigInt
downsizeWithMPZ_Size (gmpSize, limbs)
	// The representation of numbers differs in the MPZ and MPN layers of GMP:
	// Unlike MPN, MPZ represents zero with a limb array of size 0
	| gmpSize==0
		= toBigInt 0
	#!	sign = sign gmpSize
	| gmpSize==sign 			// gmpSize== -1 || gmpSize==1 <=> there is only one limb
		#!	limb0 = limbs.[0]
		| limb0<0
			| limb0==minInt && sign<0
				= toBigInt minInt
			= bigInt2ToBigInt { sign_or_number = sign, limbs = setSize limbs 1}
		= if (sign<0) (toBigInt (~limb0)) (toBigInt limb0)
	= bigInt2ToBigInt { sign_or_number=sign, limbs=setSize limbs (abs gmpSize) }

instance sqrt			BigInt
  where
	sqrt x
		| x<one
			| isZero x
				= zero
			= abort "squareroot of negative BigInt"
		= sqrt` (toPseudoBigInt x)
	  where
		sqrt` :: !BigInt2` -> .BigInt
		sqrt` x=:{ limbs }
			#!	size_	= size limbs
				needed_size	= (inc size_)/2
				new			= create_uninitialized_int_array needed_size
			= bigInt2ToBigInt (possibly_downsize_without_trailing_zeros NonNeg (mpn_sqrt new (limbs, size_)))

bigIntToString	::	 !Base !Bool !BigInt -> String
bigIntToString _ _ _ = code {
			eq_desc _Nil 0 0
			jmp_true fst_is_small_bitswb
		.d 1 3 ibi
			jmp e_BigInt_sbigIntToStringB
		:fst_is_small_bitswb
			pop_a 1
		.d 0 3 ibi
			jmp e_BigInt_sintToString
	}

intToString :: !Int !Bool !Int -> String
intToString base uppercase i
	| base==10
		= toString i
	= bigIntToStringB base uppercase { sign_or_number = if (i<0) (-1) 1, limbs = {abs i} }

bigIntToStringB	::	 !Int !Bool !BigInt2 -> String
bigIntToStringB base uppercase {sign_or_number,limbs}
	| base<2 || base>36
		= abort ("integerToString: base value "+++toString base+++" out of range")
	#!	is_negative				= sign_or_number<0
		first_digit				= if is_negative 1 0
		nr_of_needed_chars		= (get_max_string_sizeC base (size limbs))+first_digit
		new						= createArray nr_of_needed_chars ' '
		copy					= { limb \\ limb <-: limbs }
		(nr_of_digits_lz, bytes)= call_mpn_get_str first_digit new base copy (size copy)
								// number of digits including leading zeros
		nr_of_bytes				= nr_of_digits_lz+first_digit
		first_non_zero_digit	= scan_for_non_zero first_digit nr_of_bytes bytes
	|	first_non_zero_digit==nr_of_bytes
		= "0"
	#!	offset					= if uppercase ('A' - '\xA') ('a' - '\xA')
		nr_of_leading_zeros		= first_non_zero_digit-first_digit
		nr_of_digits			= nr_of_digits_lz-nr_of_leading_zeros
		chars = bytes_to_chars_and_shift first_digit first_non_zero_digit nr_of_digits offset bytes
		chars = setStringSize chars (nr_of_digits+first_digit)
	| is_negative
		= { chars & [0] = '-' }
	= chars
  where
	byteToChar offset i
		|	i<'\xA'	= i+ '0'
					= i+ offset
	scan_for_non_zero :: !Int !Int !.{#Char} -> Int
	scan_for_non_zero min max bytes
		| min>=max
			= max
		| bytes.[min]<>'\0'
			= min
		= scan_for_non_zero (inc min) max bytes
	bytes_to_chars_and_shift :: !Int !Int !Int !Char !*{#Char} -> .{#Char}
	bytes_to_chars_and_shift dest src i offset a
		| i==0
			= a
		#! a_src = a.[src]
		= bytes_to_chars_and_shift (inc dest) (inc src) (dec i) offset { a & [dest] = byteToChar offset a_src }

ceil_bits_per_dig :: {#Int}
// ceil_bits_per_dig.[base] = ceil (ld base)
ceil_bits_per_dig
	=:	{//  0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
			 0,0,1,2,2,3,3,3,3,4, 4, 4, 4, 4, 4, 4
		 //	 16,17,18,19,20,21,22,23,24,25,26,27,22,28,29,31
			,4 ,5 ,5 ,5 ,5 ,5 ,5 ,5 ,5 ,5 ,5 ,5 ,5 ,5 ,5 ,5
		 //	 32,33,34,35,36
		 	,5 ,6 ,6 ,6 ,6
		}

instance toString BigInt
  where
	toString i = bigIntToString 10 False i

instance toBigInt {#Char}
  where
	toBigInt ""
		= toBigInt 0
	toBigInt s
		| s.[0]=='-'
			= continuation 1 (-1)
		| s.[0]=='+'
			= continuation 1 1
		= continuation 0 1
	  where
		continuation i sign
			| s % (i,i+1) == "0x"
				= posStrToBigInt 16 (i+2) sign s
			| s.[i] == '0'
				= posStrToBigInt 8 (i+1) sign s
			= posStrToBigInt 10 i sign s

bigInt2ToBigInt :: !u:BigInt2 -> u:BigInt
bigInt2ToBigInt _
	= code inline {
			pop_a 0
		}

stringToBigInt	::	!Base !String -> .BigInt
stringToBigInt _ ""
	= toBigInt 0
stringToBigInt base asciiDigits
	| asciiDigits.[0]=='-'
		= posStrToBigInt base 1 (-1) asciiDigits
	| asciiDigits.[0]=='+'
		= posStrToBigInt base 1 1 asciiDigits
	= posStrToBigInt base 0 1 asciiDigits

posStrToBigInt :: !Int !Int !Int !String -> .BigInt
posStrToBigInt base beginIndex sign asciiDigits
	| base<2 || base>36
		= abort ("stringToBigInt: error: base value "+++toString base+++" out of range")
	#!	new_size			= ((size asciiDigits)-beginIndex)
		new					= createArray new_size ' '
		nonASCIIDigitsString= chars_to_bytes 0 beginIndex new_size asciiDigits new
		nr_of_digits		= size nonASCIIDigitsString
	| nr_of_digits==0
		= toBigInt 0
	#!	nr_of_needed_limbs	= ceil_div (nr_of_digits*ceil_bits_per_dig.[base]) bitsPerWord
		new					= create_uninitialized_int_array nr_of_needed_limbs
		(nr_of_limbs, result)= set_str new nonASCIIDigitsString base
	| nr_of_limbs==0
		= toBigInt 0
	= bigInt2ToBigInt (possibly_downsize sign result nr_of_limbs)
  where
	asciiDigitToByte ch
		| '0'<=ch && ch<='9'	= ch-'0'
		| 'A'<=ch && ch<='Z'	= ch-'A'+'\xA'
		| 'a'<=ch && ch<='z'	= ch-'a'+'\xA'
								= toChar base
	ceil_div nom denom // ceil (nom/denom)
		= (nom+denom-1)/denom

	chars_to_bytes :: !Int !Int !Int !String !*{#Char} -> .{#Char}
	chars_to_bytes dest src size_dest src_chars bytes
		| dest==size_dest
			= bytes
		#! byte = asciiDigitToByte (src_chars.[src])
		| byte>=toChar base
			= setStringSize bytes dest
		= chars_to_bytes (inc dest) (inc src) size_dest src_chars { bytes & [dest] = byte }

instance toInt BigInt
  where
	toInt _ = code {
				eq_desc _Nil 0 0
				jmp_false truncate
				pop_a 1
			.d 0 1 i
				rtn
			:truncate
				pop_a 1
				pushI 0
				ltI
				jmp_true is_positive_toInt
				pushI -2147483648			|| minInt
			.d 0 1 i
				rtn
			:is_positive_toInt
				pushI 2147483647			|| maxInt
			}

toBigInt2 :: !Int -> .BigInt2
toBigInt2 _ = code {
		build _Nil 0 _hnf
		}	

quotRem :: !u:BigInt !.BigInt -> (!.BigInt,!v:BigInt), [u <= v]
quotRem _ _ = code {
			eq_desc _Nil 0 0
			jmp_false fst_is_big_quotrem
			eq_desc _Nil 0 1
			jmp_false snd_only_is_big_quotrem
			pushI 1							|| B afterwards: denom nom 1
			push_b 2						|| B afterwards: denom nom 1 denom
			ltI								|| B afterwards: denom nom (denom<1)
			jmp_false cant_overflow_quotrem	|| B afterwards: denom nom
			pushI -1						|| B afterwards: denom nom -1
			push_b 2						|| B afterwards: denom nom -1 denom
			ltI								|| B afterwards: denom nom (denom< -1)
			jmp_true cant_overflow_quotrem	|| B afterwards: denom nom
			|| -1<=denom<=0, check for division by zero or overflow (minInt/-1)
			pushI -1						|| B afterwards: denom nom -1
			push_b 2						|| B afterwards: denom nom -1 denom
			eqI								|| B afterwards: denom nom (denom== -1)
			jmp_true check_overflow_quotrem	|| B afterwards: denom nom
		:div_by_zero_quotrem
			pop_b 2
			buildAC "BigInt division by zero"
		.d 1 0
			jsr e_StdMisc_sabort
		:check_overflow_quotrem				|| B           : -1 nom
			pushI -2147483648				|| B afterwards: -1 nom minInt
			push_b 1						|| B afterwards: -1 nom minInt nom
			eqI								|| B afterwards: -1 nom (nom==minInt)
			jmp_true is_overflown_quotrem	|| B afterwards: -1 nom
			pushI 0 						|| B afterwards: -1 nom 0
			update_b 0 2					|| B afterwards: 0 nom 0
			subI							|| B afterwards: 0 (nom/denom) where denom== -1
		.d 2 2 ii
			rtn
		:cant_overflow_quotrem				|| B           : denom nom
		.d 0 2 ii
			jsr e_BigInt_squotRemI			|| B afterwards: (denom rem nom) (denom quot nom)
		.o 0 2 ii
		.d 2 2 ii
			rtn
		:is_overflown_quotrem				|| B           : -1 minInt
			pushI 0							|| B afterwards: -1 minInt 0
			update_b 0 2					|| B afterwards: 0 minInt 0
			pop_b 2							|| B afterwards: 0
			pop_a 1
		.d 0 0
			jsr e_BigInt_sneg_minInt_0
		.o 1 1 i
		.d 2 2 ii
			rtn
		:fst_is_big_quotrem
			eq_desc _Nil 0 1
			jmp_false both_are_big_quotrem
		:fst_only_is_big_quotrem			|| B           : denom nom
			update_a 0 1					|| get rid of the superfluous constructor
			pop_a 1
		.d 1 2 ii
			jmp e_BigInt_squotRemBS
		:snd_only_is_big_quotrem
			pop_a 1							|| get rid of the superfluous constructor
		.d 1 2 ii
			jmp e_BigInt_squotRemSB
		:both_are_big_quotrem
		.d 2 2 ii
			jmp e_BigInt_squotRemBB
	}

isZero :: !.BigInt -> Bool
isZero _ = code {
		eq_desc _Nil 0 0
		jmp_false is_not_zero
		pop_a 1
		pushI 0
		eqI
	.d 0 1 b
		rtn
	:is_not_zero
		pop_a 1
		pop_b 1
		pushB FALSE
	}

isNonNegative :: !.BigInt -> Bool
isNonNegative _ = code {
		pop_a 1
		pushI -1
		ltI
	}

fitsIntoInt :: !BigInt -> Bool
fitsIntoInt _ = code {
		eq_desc _Nil 0 0
		updatepop_b 0 1
		pop_a 1
	}

divMod :: !.BigInt !.BigInt -> (!.BigInt,!BigInt)
divMod nom denom
	#! (quot, rem) = quotRem nom denom
	   signs_are_equal = (isNonNegative nom)==(isNonNegative denom)
	= if (signs_are_equal || isZero rem) (quot, rem) 
										(quot .- (toBigInt 1), rem+denom)


quotRemI :: !Int !Int -> (!Int, !Int)
quotRemI nom denom
	#! quot = nom/denom
	   rem = nom - quot*denom
	= (quot, rem)
	

small_to_big2 :: !Int -> .BigInt2`
small_to_big2 small = if (small<0) { sign_or_number = -1, limbs = {~small}}
								  { sign_or_number = 1, limbs = {small} }

quotRemBS :: !u:BigInt2 !Int -> (!.BigInt2,!v:BigInt2), [u <= v]
quotRemBS big small
	= quotRemBB big (small_to_big2 small)
	
quotRemSB :: !Int !.BigInt2 -> (!.BigInt2,!v:BigInt2)
quotRemSB small big
	// here is further place for optimisations
	= quotRemBB (small_to_big2 small) big

quotRemBB :: !u:BigInt2` !.BigInt2` -> (!.BigInt2,!v:BigInt2), [u <= v];
quotRemBB { sign_or_number=nomSign, limbs=nomLimbs } { sign_or_number=denomSign, limbs=denomLimbs }
	#!	(q,r)	= positive_DivMod nomLimbs denomLimbs
	= ( possibly_downsize_without_trailing_zeros (signsrule nomSign denomSign) q
	  , possibly_downsize_without_trailing_zeros nomSign r
	  )

positive_DivMod nomLimbs denomLimbs
	= positive_maybeDivMod True nomLimbs denomLimbs

instance rem			BigInt
  where
	rem nom denom = code {
			eq_desc _Nil 0 0
			jmp_false fst_is_big_rem
			eq_desc _Nil 0 1
			jmp_false snd_only_is_big_rem
			pushI 0							|| B afterwards: denom nom 0
			push_b 2						|| B afterwards: denom nom 0 denom
			gtI								|| B afterwards: denom nom (denom>0)
			jmp_false could_fail_rem		|| B afterwards: denom nom
		:cant_fail_rem
			modI							|| B afterwards: (nom rem denom)
			pop_a 1
		.d 1 1 i
			rtn
		:could_fail_rem
			|| reasons why denom rem nom could fail: (division by zero) or (minInt rem -1 (crashes with intel))
			pushI -1						|| B afterwards: denom nom -1
			push_b 2						|| B afterwards: denom nom -1 denom
			ltI								|| B afterwards: denom nom (denom< -1)
			jmp_true cant_fail_rem			|| B afterwards: denom nom
			pushI -1						|| B afterwards: denom nom -1 where -1<=denom<=0
			update_b 0 1					|| B afterwards: denom -1 -1  where -1<=denom<=0
			pop_b 1							|| B afterwards: denom -1     where -1<=denom<=0
			eqI								|| B afterwards: (denom== -1) where -1<=denom<=0
			jmp_false div_zero_rem			|| B afterwards:
			pushI 0							|| B afterwards: 0    (denom was -1 => remainder is 0)
			pop_a 1
		.d 1 1 i
			rtn
		:div_zero_rem
			buildAC "BigInt division by zero"
		.d 1 0
			jsr e_StdMisc_sabort
		:fst_is_big_rem
			eq_desc _Nil 0 1
			jmp_false both_are_big_rem
		:fst_only_is_big_rem
			update_a 0 1					|| get rid of the superfluous constructor
			pop_a 1
		.d 1 2 ii
			jmp e_BigInt_sremBS
		:snd_only_is_big_rem
			pop_a 1							|| get rid of the superfluous constructor
		.d 1 2 ii
			jmp e_BigInt_sremSB
		:both_are_big_rem
		.d 2 2 ii
			jmp e_BigInt_sremBB
}

remBS :: !BigInt2 !Int -> BigInt2
remBS b s
	| s==0
		= abort "BigInt division by zero"
	= remBB b (small_to_big2 s)

remSB :: !Int !BigInt2 -> .BigInt2
remSB s {limbs}
	| s==minInt && size limbs==1 && limbs.[0]==minInt
		= toBigInt2 0
	= toBigInt2 s

remBB :: !BigInt2 !BigInt2 -> BigInt2
remBB { sign_or_number=nomSign, limbs=nomLimbs } { limbs=denomLimbs }
	#!	(_,r)	= positive_maybeDivMod False nomLimbs denomLimbs
	= possibly_downsize_without_trailing_zeros nomSign r

instance mod BigInt
  where
	mod nom denom
		#	r = nom rem denom
		| isZero r || isNonNegative nom == isNonNegative denom
			= r
		= r+denom

//positive_maybeDivMod :: .Bool {#.Int} {#.Int} -> (.Limbs,.{#Limb})
positive_maybeDivMod calculateQuotient nom denom
/*	if calculateQuotient then calculate (nom div denom, nom mod denom), otherwise calculate only the
	mod part, the div part will be some array, which isn't needed anyway
	it turned out, that division is faster, when only the mpn functions are called.
	Simply calling mpz_tdiv_qr would be slower. Defining this function as a macro gains speed
	for "mod".
*/
	:== p_maybeDivMod calculateQuotient nom denom
  where
	p_maybeDivMod calculateQuotient nom denom
		#!	denomSize		= size denom
			nomSize			= size nom
		| denomSize==1
			| denom.[0]==0
				= abort "BigInt division by zero"
			| calculateQuotient
				#!	new						= create_uninitialized_int_array nomSize
					(remainder, quotient)	= mpn_divrem_1 new 0 (nom,nomSize) denom.[0]
				= (remove_leading_zeros quotient, {remainder})
			#!	remainder	= mpn_mod_1 (nom,nomSize) denom.[0]
			= ({0}, {remainder})
		| nomSize<denomSize || (nomSize==denomSize && greater denom.[dec nomSize] nom.[dec nomSize])
			// denominator is bigger than nominator
			= ({0}, nom)
		#!	(normalization_steps, normalized_denom) = normalize (denom, denomSize)
			(shifted_nom,snSize)
							= lshift_copy normalization_steps (nom,nomSize)
			(quotient, remainder)
				= maybeDivrem calculateQuotient (shifted_nom,snSize) (normalized_denom, denomSize)
			remainder = case normalization_steps of
							0 -> remainder
							_ -> snd (mpn_rshift_inplace remainder denomSize normalization_steps)
			remainder		= remove_leading_zeros_i remainder denomSize
		= (quotient, remainder)

normalize :: !(!u:{#.Int},!.Int) -> (Int,v:{#Int}), [u <= v];
// localto positive_maybeDivMod
// shift to left, until most significant bit is set, return number of shifts
normalize (limbs, size_)
	#!	normalization_steps	= countLeadingZeros limbs.[dec size_]
	| normalization_steps==0
		= (normalization_steps, limbs)
	#!	new	= create_uninitialized_int_array size_
		(_, normalized_limbs)= mpn_lshift new (limbs,size_) normalization_steps
	= (normalization_steps, normalized_limbs)

lshift_copy :: !.Int !({#.Int},Int) -> (.{#Int},Int);
// localto positive_maybeDivMod
// lshift_copy i (l,s):
// make a copy of l which is shifted i bits to the left, s=size l
lshift_copy 0 (limbs,size_)
	= ({ limb \\ limb<-:limbs }, size_)
lshift_copy i limbsWithSize=:(limbs, size_)
	#!	size1		= inc size_
		new			= create_uninitialized_int_array size1
		(shifted_limb, shifted_limbs)	= mpn_lshift new limbsWithSize i
	| shifted_limb<>0
		= ({ shifted_limbs & [size_]=shifted_limb }, size1)
	= (setSize shifted_limbs size_, size_)

//maybeDivrem :: .Bool *(*Limbs,.Int) (.Limbs,.Int) -> (.{#Int},.Limbs);
maybeDivrem calculateQuotient (shifted_nom_limbs,snSize) normalized_denom=:(_, denomSize)
// before:shifted_nom>normalized_denom
// after:if calculateQuotient, (fst result) will have no leading zeros, but (snd result) well
	| calculateQuotient
		#!	newSize			= snSize-denomSize+1
			new				= create_uninitialized_int_array newSize
			(most_sig_limb, (quotient, remainder))
				= mpn_divrem new 0 shifted_nom_limbs snSize normalized_denom
		| most_sig_limb<>0
			= ({ quotient & [dec newSize]=most_sig_limb }, remainder)
		= (setSize quotient (dec newSize), remainder)
	= ({}, remainder shifted_nom_limbs snSize normalized_denom) // (fst result) will not be further used

powMod  :: !BigInt !BigInt !BigInt -> .BigInt
powMod base exponent mod
	| isZero mod
		= abort "powMod undefined for modulus==0"
	| not (isNonNegative exponent)
		= abort "powMod undefined for exponent<0"
	= powModBBB (toPseudoBigInt base) (toPseudoBigInt exponent) (toPseudoBigInt mod)

toPseudoBigInt :: !BigInt -> BigInt2`
toPseudoBigInt _ = code {
		eq_desc _Nil 0 0
		jmp_false is_big
		pop_a 1
	.d 0 1 i
		jsr e_BigInt_ssmall_to_big2
	.o 1 1 i
	:is_big
	}

powModBBB :: !BigInt2` !BigInt2` !BigInt2` -> .BigInt
powModBBB base exponent mod
	#!	new	= create_uninitialized_int_array ((size mod.limbs)<<1)	// allocate enough space for GMP routine
	= downsizeWithMPZ_Size (powm new base exponent mod)				// and call it

unpackBigInt :: !u:BigInt -> (!NonNegBool, !u:{#Int})
unpackBigInt _ = code {
			eq_desc _Nil 0 0
			jmp_false is_big_unpack
			pop_a 1
			push_b 0					
			pushI 0
			gtI
			notB						|| B afterwards: i, is_non_negative i
			push_b 1
			update_b 1 2
			update_b 0 1
			pop_b 1						|| B afterwards: is_non_negative i, i
			push_b 1					|| calculate (abs i)
			jmp_true create_the_array
			pushI 0
			subI
		:create_the_array				|| B: is_non_negative i, abs i
			pushI 1
			create_array_ INT 0 1
			pushI 0
			update INT 0 1				|| B afterwards: is_non_negative i
		.d 1 1 b
			rtn
		:is_big_unpack
			pushI 1
			eqI
	}			

packBigInt :: !NonNegBool !u:{#Int} -> u:BigInt
packBigInt bool_sign limbs
	#!	size_limbs = size limbs
	| size_limbs==0
		= toBigInt 0
	| size_limbs==1
		#!	limb0 = limbs.[0]
		| limb0<0
			| limb0==minInt && not bool_sign
				= toBigInt minInt
			#!	sign = if bool_sign 1 (-1)
			= bigInt2ToBigInt { sign_or_number = sign, limbs = limbs }
		= if bool_sign (toBigInt limb0) (toBigInt (~limb0)) 
	#!	i = dec size_limbs
	| limbs.[i]==0
		#!	size1_of_copy = get_size1_of_copy limbs i
		= packBigInt bool_sign { limbs.[k] \\ k<-[0..size1_of_copy] }
	#!	sign = if bool_sign 1 (-1)
	= bigInt2ToBigInt { sign_or_number = sign, limbs = limbs }
  where
	get_size1_of_copy limbs i
		#!	i1 = dec i
		| i1==0 || limbs.[i1]<>0
			= i1
		= get_size1_of_copy limbs i1

instance toReal		BigInt
  where
	toReal i
		# (non_neg, limbs) = unpackBigInt i
		  bigInt2 = { sign_or_number = (bool_to_int_sign non_neg), limbs = limbs }
		| size limbs>42 // everything beyond this magic number must shurely be incredibly infinite
			= to_infinity i
		# real = bigIntToRealC bigInt2
		| abs real<1.0
			| isZero i
				= real
			// overflow. return #INF value
			= to_infinity i
		= real
		
to_infinity i :== (toReal (sign i))/0.0

ratioToReal :: !BigInt !BigInt -> Real
ratioToReal nom denom
	| isZero denom
		= to_infinity nom
	# (nom_non_neg, nom_limbs) = unpackBigInt nom
	  (denom_non_neg, denom_limbs) = unpackBigInt denom
	  nom_BigInt2 = { sign_or_number = (bool_to_int_sign nom_non_neg), limbs = nom_limbs }
	  denom_BigInt2 = { sign_or_number = (bool_to_int_sign denom_non_neg), limbs = denom_limbs }
	  real = ratioToRealC nom_BigInt2 denom_BigInt2
	| abs real<1.0
		| size nom_limbs<=size denom_limbs
			= real
		// overflow. return #INF value
		= to_infinity nom
	| size nom_limbs<size denom_limbs
		// overflow. return #INF value
		= to_infinity nom
	= real

bool_to_int_sign non_neg :== if non_neg 1 (-1)

nrOfBits :: !BigInt -> Int
nrOfBits i
	# (_, limbs) = unpackBigInt i
	  size_limbs1 = dec (size limbs)
	  msl = limbs.[size_limbs1]
	| size_limbs1==0
		| msl==0
			= 0
		= 32-(countLeadingZeros msl)
	= (32-(countLeadingZeros msl))+((size_limbs1)<<5)

remove_leading_zeros :: !*Limbs -> .Limbs
remove_leading_zeros limbs
	#!	size_	= size limbs
	= remove_leading_zeros_i limbs size_
	
remove_leading_zeros_i :: !*Limbs !Int -> .Limbs
remove_leading_zeros_i limbs index
	| index==1
		= setSize limbs 1
	#! index1	= dec index
	| limbs.[index1]==0
		= remove_leading_zeros_i limbs index1
	= setSize limbs index
	
:: Limb				:== Int
:: Limbs			:==	{#Int}
:: LimbsWithSize	:== (!Limbs, !Size)
:: SignedLimbs		:== (!Bool, !Limbs)
:: Size				:== Int
:: GMPSize			:== Int // <0 <=> number is negative
:: CPtr				:== Int

//powm :: !*Limbs !BigInt2 !BigInt2 !BigInt2 -> (!GMPSize, !.Limbs)
powm dest base exponent modulus
	:== powmC dest base exponent modulus dest

powmC :: !Limbs !BigInt2 !BigInt2 !BigInt2 !Limbs -> (!GMPSize, !.Limbs)
powmC dest base exponent modulus _
	= code inline {
			ccall powmC "AIAIAIA:I:A"
		}

//mpn_add :: !*Limbs !LimbsWithSize !LimbsWithSize -> (!Limb, !.Limbs)
mpn_add dest s1 s2
	:== mpn_addC dest s1 s2 dest

//mpn_add_inplace :: !*Limbs !Size !LimbsWithSize -> (!Limb, !.Limbs)
mpn_add_inplace sd_limbs size src2
	:== mpn_addC sd_limbs (sd_limbs, size) src2 sd_limbs

mpn_addC :: !Limbs !LimbsWithSize !LimbsWithSize !Limbs ->  (!Limb, !.Limbs)
// src1Size>=src2Size, size(dest)==src1Size, returns carry
mpn_addC destPtr (src1Ptr, src1Size) (src2Ptr, src2Size) _
	= code inline {
			ccall __gmpn_add "AAIAI:I:A"
		}

//mpn_add_1 :: !*Limbs !LimbsWithSize !Limb -> (!Limb, !.Limbs)
mpn_add_1 new limbs_with_size limb
	:== mpn_add_1C new limbs_with_size limb new

//mpn_add_1_inplace :: !*Limbs !Size !Limb -> (!Limb, !.Limbs)
mpn_add_1_inplace limbs size limb
	:== mpn_add_1C limbs (limbs, size) limb limbs

mpn_add_1C :: !Limbs !LimbsWithSize !Limb !Limbs -> (!Limb, !.Limbs)
mpn_add_1C  destPtr s1 s2 _
	= code inline {
			ccall __gmpn_add_1 "AAII:I:A"
		}

//add_1 :: !*Limbs !LimbsWithSize !Limb -> .Limbs
// optimized version of mpn_add_1 that decrements the size of the result array, if no overflow occured
add_1 new limbs_with_size limb
	:== add_1C new limbs_with_size limb new

add_1C :: !Limbs !LimbsWithSize !Limb !Limbs -> .Limbs
add_1C  destPtr s1 s2 _
	= code inline {
			ccall add_1C "AAII:V:A"
		}

//mpn_sub_1 :: !*Limbs !LimbsWithSize !Limb -> (!Limb, !.Limbs)
mpn_sub_1 new limbs_with_size limb
	:== mpn_sub_1C new limbs_with_size limb new

//mpn_sub_1_inplace :: !*Limbs !Size !Limb -> (!Limb, !.Limbs)
mpn_sub_1_inplace limbs size limb
	:== mpn_sub_1C limbs (limbs, size) limb limbs

mpn_sub_1C :: !Limbs !LimbsWithSize !Limb !Limbs -> (!Limb, !.Limbs)
mpn_sub_1C  destPtr s1 s2 _
	= code inline {
			ccall __gmpn_sub_1 "AAII:I:A"
		}

//mpn_sub_inplace :: !*Limbs !Size !LimbsWithSize -> (!Limb, !.Limbs)
mpn_sub_inplace limbs size s2
	:== mpn_subC limbs (limbs, size) s2 limbs

//mpn_sub :: !*Limbs !LimbsWithSize !LimbsWithSize -> (!Limb, !.Limbs)
mpn_sub dest s1 s2
	:== mpn_subC dest s1 s2 dest

// src1Size>=src2Size, size(dest)==src1Size, returns borrow
mpn_subC :: !Limbs !LimbsWithSize !LimbsWithSize !Limbs -> (!Limb, !.Limbs)
mpn_subC destPtr (src1Ptr, src1Size) (src2Ptr, src2Size) _
	= code inline {
			ccall __gmpn_sub "AAIAI:I:A"
		}

mpn_cmp :: !Limbs !Limbs !Size -> Int
/* compares two Numbers:
mpn_cmp l1 l2 _
	| l1>l2 = "a number grater than 0"
	| l1==l2= 0
	| l1<l2 = "a number smaller than 0"
*/
mpn_cmp l1 l2 _
	= code inline {
			ccall __gmpn_cmp "AAI-I"
		}

//mpn_mul :: !*Limbs !LimbsWithSize !LimbsWithSize -> (!Limb, !.Limbs)
mpn_mul destPtr s1 s2
	:== mpn_mulC destPtr s1 s2 destPtr

mpn_mulC :: !Limbs !LimbsWithSize !LimbsWithSize !Limbs -> (!Limb, !.Limbs)
// multiply, give back most significant limb of result
// space for result must be src1Size+src2Size
// src1Size must be >= src2Size
mpn_mulC destPtr (src1Ptr, src1Size) (src2Ptr, src2Size) _
	= code inline {
			ccall __gmpn_mul "AAIAI:I:A"
		}

//mpn_mul_1 :: !*Limbs !LimbsWithSize !Limb -> (!Limb, !.Limbs)
mpn_mul_1 new lws l
	:== mpn_mul_1C new lws l new

mpn_mul_1C :: !Limbs !LimbsWithSize !Limb !Limbs -> (!Limb, !.Limbs)
mpn_mul_1C  destPtr s1 s2 _
	= code inline {
			ccall __gmpn_mul_1 "AAII:I:A"
		}

//mpn_divrem ::  !*Limbs !Int !*Limbs !Size !LimbsWithSize -> (!Limb, !(!.Limbs, !.Limbs))
mpn_divrem destPtr xSize nomLimbs nomSize denom
	:== mpn_divremC destPtr xSize (nomLimbs, nomSize) denom (Cast destPtr, Cast nomLimbs)

mpn_divremC :: !Limbs !Int !LimbsWithSize !LimbsWithSize !*env -> (!Limb, !*env)
// divide nom by denom, write result to destPtr with the exeption of the most
// significant limb (0 or 1) which is returned. The remainder replaces nom.
// xSize<>0 can be used to calculate after comma limbs. This will not be done here,
// so xSize is always zero. (Further information about the xSize parameter is available
// in the gmp documentation.)
// Requirements: nomSize>=denomSize, most significant bit of divisor must be set
// space for dest = nomSize-denomSize+xSize
mpn_divremC destPtr xSize nom=:(nomLimbs,nomSize) denom=:(denomLimbs,denomSize) _
	= code inline {
			ccall __gmpn_divrem "AIAIAI:I:A"
		}

//remainder :: !*Limbs !Size !LimbsWithSize -> .Limbs
remainder nomLimbs nomSize denom
	:== remainderC (nomLimbs, nomSize) denom nomLimbs

remainderC :: !LimbsWithSize !LimbsWithSize !Limbs -> .Limbs
remainderC nom=:(nomLimbs,nomSize) denom=:(denomLimbs,denomSize) _
	= code inline {
			ccall remainderC "AIAI:V:A"
		}

//mpn_divrem_1 :: !*Limbs !Int !LimbsWithSize !Limb -> (!Limb, !.Limbs)
mpn_divrem_1 dest xSize nom denom
	:== mpn_divrem_1C dest xSize nom denom dest

mpn_divrem_1C :: !Limbs !Int !LimbsWithSize !Limb !Limbs -> (!Limb, !.Limbs)
// divide nom with denom (which is only one limb) and write the quotient at
// dest. return remainder. xSize is like in mpn_divrem and will always be 0.
// memory for dest = nomSize+xSize
// it is allowed that dest and (fst nom) are the same array
mpn_divrem_1C dest xSize nom denom _
	= code inline {
			ccall __gmpn_divrem_1 "AIAII:I:A"
		}

mpn_mod_1 :: !(!Limbs, !Size) !Limb -> Limb
// the argument limbs are not destroyed
mpn_mod_1 _ _
	= code inline {
			ccall __gmpn_mod_1 "AII-I"
		}

//mpn_lshift :: !*Limbs !LimbsWithSize !Int -> (!Limb, !.Limbs)
mpn_lshift dest src count
	= mpn_lshiftC dest src count dest
	
mpn_lshiftC :: !Limbs !LimbsWithSize !Int !Limbs -> (!Limb, !.Limbs)
// shift src count bits to the left and write the srcSize least significant limbs
// of the result to destPtr. The bits shifted out to the left are returned.
// requirements: 1<=count<=n-1 on a n-bit machine, when space of source and destination
// overlap then destPtr>=srcPtr 
mpn_lshiftC destPtr src=:(srcPtr,srcSize) count _
	= code inline {
			ccall __gmpn_lshift "AAII:I:A"
		}

//mpn_rshift_inplace :: !*Limbs !Size !Int -> (!Limb, !.Limbs)
mpn_rshift_inplace limbs size i
	:== mpn_rshiftC limbs (limbs, size) i limbs

mpn_rshiftC :: !Limbs !LimbsWithSize !Int !Limbs -> (!Limb, !.Limbs)
// shift src count bits to the right and write the srcSize most significant limbs
// of the result to destPtr. The bits shifted out to the right are returned.
// requirements: 1<=count<=n-1 on a n-bit machine, when space of source and destination
// overlap then destPtr<=srcPtr 
mpn_rshiftC destPtr src=:(srcPtr,srcSize) count _
	= code inline {
			ccall __gmpn_rshift "AAII:I:A"
		}


//mpn_sqrt :: !*Limbs !LimbsWithSize -> .Limbs
mpn_sqrt limbs x
	:== snd (mpn_sqrtremC limbs 0 x limbs)

mpn_sqrtremC :: !Limbs !CPtr !LimbsWithSize !Limbs -> (!Int, !.Limbs)
// This interface is only preliminary
mpn_sqrtremC dest remainderPtr x _
	= code
		{
			ccall __gmpn_sqrtrem "AIAI:I:A"
		}

//call_mpn_get_str :: !Int !*{#Char} !Int !Limbs !Size -> (!Int, !.{#Char})
call_mpn_get_str offset dest base limbs size
	:== call_mpn_get_strC offset dest base limbs size dest
	
// convert limbs into string according to base. Fill the Int array with that string.
// The array has to be big enough for the longest possible number+1.
// There maybe leading zeroes in the result
// The bytes in the array are then in range 0..base-1 (not ASCII). 
// Returns length of string.
call_mpn_get_strC :: !Int !{#Char} !Int !Limbs !Size !{#Char} -> (!Int, !.{#Char})
call_mpn_get_strC offset string base _ _ _
	= code
		{
			ccall call_mpn_get_str "ISIAI:I:A"
		}

/*
//call_mpn_get_str :: !*{#Char} !Int !Limbs !Size -> (!Int, !.{#Char})
call_mpn_get_str dest base limbs size
	:== call_mpn_get_strC dest base limbs size dest
	
// convert limbs into string according to base. Fill the Int array with that string.
// The array has to be big enough for the longest possible number+1.
// There maybe leading zeroes in the result
// The bytes in the array are then in range 0..base-1 (not ASCII). 
// Returns length of string.
call_mpn_get_strC :: !{#Char} !Int !Limbs !Size !{#Char} -> (!Int, !.{#Char})
call_mpn_get_strC string base _ _ _
	= code
		{
			ccall call_mpn_get_str "SIAI:I:A"
		}
*/

//set_str :: !*Limbs !String !Int -> (!Size, !.Limbs)
set_str dest str base
	:== set_strC dest str base dest

set_strC :: !Limbs !String !Int !Limbs -> (!Size, !.Limbs)
// convert the array of unsigned bytes (not ASCII characters) according to base base and
// fill dest with that result. return number of limbs. 
// requirement: size(dest)>=result
set_strC dest _ base _
	= code
		{
			ccall set_strC "ASI:I:A"
		}

//setStringSize :: !*{#Char} !Size -> .{#Char}
setStringSize str newSize
	:== setStringSizeC str newSize str

setStringSizeC :: !{#Char} !Int !{#Char} -> .{#Char}
setStringSizeC _ _ _
	= code inline {
			ccall setStringSizeC "SI:V:S"
		}

//setSize :: !*Limbs !Size -> .Limbs
setSize limbs newSize
	:== setSizeC limbs newSize limbs

setSizeC :: !Limbs !Int !Limbs -> .Limbs
setSizeC _ _ _
	= code inline {
			ccall setSizeC "AI:V:A"
		}

countLeadingZeros :: !Int -> Int
// returns number of leading zero bits. argument must not be 0
countLeadingZeros _
	= code inline {
			ccall countLeadingZeros "I:VI"
		}

//gmp_gcd :: !*Limbs !BigInt2 !BigInt2 -> (!GMPSize, !.Limbs)
gmp_gcd dest u v
	:== gmp_gcdC dest u v dest

gmp_gcdC :: !Limbs !BigInt2 !BigInt2 !Limbs -> (!GMPSize, !.Limbs)
gmp_gcdC dest u v _
	= code inline {
			ccall gmp_gcdC "AIAIA:I:A"
		}

pow_uiC :: !BigInt2 !Int -> (!Int, !CPtr)
pow_uiC base exp
	= code inline {
			ccall pow_uiC "IAI-II"
		}

//transferGMPNumberToClean :: !*Limbs !CPtr !Size -> !.Limbs
transferGMPNumberToClean dest src size
	:== transferGMPNumberToCleanC dest src size dest

transferGMPNumberToCleanC :: !Limbs !CPtr !Size !Limbs -> .Limbs
transferGMPNumberToCleanC dest src size _
	= code inline {
			ccall transferGMPNumberToCleanC "AII:V:A"
		}

get_max_string_sizeC :: !Base !Size -> Int
get_max_string_sizeC _ _
	= code inline {
			ccall get_max_string_sizeC "II-I"
		}

ratioToRealC :: !BigInt2 !BigInt2 -> Real
ratioToRealC nom denom
	= code inline {
			ccall ratioToRealC "IAIA-R"
		}

bigIntToRealC :: !BigInt2 -> Real
bigIntToRealC _
	= code inline {
			ccall bigIntToRealC "IA-R"
		}

create_uninitialized_int_array :: !Int -> .{#Int}
create_uninitialized_int_array size = code inline {
	create_array_ INT 0 1
	}

Cast :: !.a -> .b
Cast a
	= code inline {
			pop_a 0
		}
