implementation module StdFunc

// ****************************************************************************************
//	Concurrent Clean Standard Library Module Version 2.0
//	Copyright 1995 University of Nijmegen
//
//	Changes made for Sparkle 0.0.3a (8 January 2002):
//		o The macro definitions for 'flip', 'o', '`bind`' and 'return' have been
//		  replaced by functions.
//		o The lambda expression within 'o' has been replaced with an explicitly
//		  named local function ('oo').
// ****************************************************************************************

import StdClass, StdMisc, StdInt

id :: !.a -> .a
id x = x

const :: !.a .b -> .a
const x y = x

// Sparkle
flip ::!.(.a -> .(.b -> .c)) .b .a -> .c
flip f a b
	= f b a

// Sparkle
(o) infixr 9 :: u:(.a -> .b) u:(.c -> .a) -> u:(.c -> .b)
(o) f g
//	= \ x -> f (g x)
	= oo f g
	where
		oo f g x
			= f (g x)

twice :: !(.a -> .a) .a -> .a
twice f x = f (f x)

while :: !(a -> .Bool) (a -> a) a -> a
while p f x	
	| p x	= 	while p f (f x)
			= 	x

until::!(a -> .Bool) (a -> a) a -> a
until p f x
	| p x 	= x
			= until p f (f x)

iter :: !Int (.a -> .a) .a -> .a
iter 0 f x	= 	x
iter n f x
	| n > 0	= 	iter (n-1) f (f x)
			= 	abort "Error: Negative index given to iter."

seq :: ![.(.s -> .s)] .s -> .s
seq [f:fs] arg	=	seq fs (f arg)
seq [] arg		=	arg

seqList::![St .s .a] .s -> ([.a],.s)
seqList [f:fs] io = ([a:as],iol)
where
	(as,iol) = seqList fs io1 
	(a,io1)  = f io
seqList [] io = ([],io)

//	for people who like state manipulation with monads

:: St s a :== s -> *(a,s)

// Sparkle
(`bind`) infix 0 :: w:(St .s .a) v:(.a -> .(St .s .b)) -> u:(St .s .b), [u <= v, u <= w]
(`bind`) f g
	= \st0 -> let (r,st1) = f st0 in g r st1

// Sparkle
return :: u:a -> u:(St .s u:a)
return r
	= \s -> (r,s)