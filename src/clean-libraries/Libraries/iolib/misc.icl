implementation module misc;

// from StdString import String;
import	StdClass;
import StdInt;


    

Append :: ![x] !x -> [x];
Append [e:r] x #!
		strict1=strict1;
		=
		[e : strict1];
	where {
	strict1=Append r x;
		
	};
Append r x =  [x];

Concat :: ![x] ![x] -> [x];
Concat [e:r] l #!
		strict1=strict1;
		=
		[e : strict1];
	where {
	strict1=Concat r l;
		
	};
Concat r l =  l;

Evaluate_2 :: !x !y -> x;
Evaluate_2 x y =  x;

UEvaluate_2 :: !* x !y -> *x;
UEvaluate_2 x y =  x;

Evaluate_1 :: !x !y -> y;
Evaluate_1 x y =  y;

Reverse :: ![x] -> [x];
Reverse xs =  Reverse` xs [];

Reverse` :: ![x] ![x] -> [x];
Reverse` [a : b] y =  Reverse` b [a : y];
Reverse` x y =  y;

Head :: ![x] -> x;
Head [x : tl] =  x;

Minimum :: !Int !Int -> Int;
Minimum m n
   | m <= n =  m;
   =  n;

Maximum :: !Int !Int -> Int;
Maximum m n
   | m >= n =  m;
   =  n;

import StdFile;

    
K :: * x !y -> *x;
K x y =  x;

N :: * x String -> *x;
N x mes =  K x (fwrites mes stderr);
