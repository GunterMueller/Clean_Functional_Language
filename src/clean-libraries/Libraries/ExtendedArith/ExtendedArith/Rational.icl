implementation module Rational

import StdEnv, BigInt, ExtendedArithBasics

//	utilities for ratio calculations

:: Rational	// denom>0 && (gcd num denom==1) && (num==0 => denom==1)
	=	{	num		::	!.BigInt
		,	denom	::	!.BigInt	
		}

simplify :: !Rational -> Rational
simplify {num, denom}
	| denom==%0
	 	= abort "Rational: division by zero\n"
	| num==%0
 		= zero
	| g==%1
 		= adjust_signs num denom
	= adjust_signs (num/g) (denom/g)
where
	g = gcd num denom
	adjust_signs num denom
		| denom>%0
			= { num=num, denom=denom }
		= { num= ~num, denom= ~denom }
		

instance == Rational
where
	(==) r1 r2 = r1.num == r2.num && r1.denom == r2.denom

instance < Rational
where
	(<) r1 r2 = r1.num*r2.denom < r2.num*r1.denom

// Arithmetic:

instance + Rational
where
	(+) x y = simplify	{	num  = x.num * y.denom + x.denom * y.num
						,	denom  = x.denom * y.denom
						}

instance - Rational
where
	(-) x y = simplify	{	num = x.num * y.denom - x.denom * y.num
						,	denom = x.denom * y.denom
						}

instance zero Rational
where
	zero = { num = zero, denom = one }

instance * Rational
where
	(*) x y = simplify	{	num = x.num * y.num
						,	denom = x.denom * y.denom
						}

instance / Rational
where
	(/) x y = simplify	{	num = x.num * y.denom
						,	denom = x.denom * y.num
						}

instance one Rational
where
	one = {num = one, denom = one}


instance abs Rational
where
    abs r = { r & num = abs r.num }

instance sign Rational
where
	sign r = sign r.num

instance ~ Rational
where
    ~ r = { r & num = ~ r.num }

instance toReal			Rational
where
	toReal {num, denom} = ratioToReal num denom
	
numerator :: !Rational -> BigInt
numerator r	= r.num

denominator :: !Rational -> BigInt
denominator r = r.denom

class (/:)  infix  7	a	:: !a	!a	->	Rational
class toRational   a ::    !a -> Rational

instance /: Int
where
	(/:) num denom
		= simplify { num = toBigInt num, denom = toBigInt denom }

instance /: BigInt
where
	(/:) num denom
		= simplify { num = num, denom = denom }

instance toRational Int
where
	toRational i
		= { num = toBigInt i, denom = one }

instance toRational BigInt
where
	toRational i
		= { num = i, denom = one }

instance EqInt		Rational
where
	(==%) r i
		= r.num==toBigInt i && r.denom==one
		
instance LessInt	Rational
where
	(<%) r i
		= r.num < (toBigInt i)*r.denom

instance GreaterInt	Rational
where
	(>%) r i
		= r.num > (toBigInt i)*r.denom

instance +%			Rational
where
	(+%) x y_num = simplify	{	num  = x.num + x.denom * (toBigInt y_num)
							,	denom  = x.denom
							}
		
instance -%			Rational
where
	(-%) x y_num = simplify	{	num = x.num - x.denom * (toBigInt y_num)
							,	denom = x.denom
							}

instance %-			Rational
where
	(%-) x_num y = simplify	{	num = (toBigInt x_num) * y.denom - y.num
							,	denom = y.denom
							}

instance *%			Rational
where
	(*%) r i
		= simplify { r & num = r.num*(toBigInt i) }

instance ^%			Rational
where
	(^%) {num, denom} exp
		# bigExp = abs (toBigInt exp)
		| exp<0
			= { num = denom^bigExp, denom = num^bigExp }
		= { num = num^bigExp, denom = denom^bigExp }


