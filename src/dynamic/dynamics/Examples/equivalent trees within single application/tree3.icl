implementation module tree3

import StdEnv
import StdDynamic


/*
:: Tree = Leaf Int | Node Tree Tree

what_is_it (Node t1 t2) = "Node"
what_is_it (Leaf a)	= "Leaf"

f :: Dynamic -> Int
f (t :: Tree)
	= abort ("Een match 2" +++ what_is_it t)
*/

//:: Tree c d = Node c d (Tree c d) (Tree c d) | Leaf
:: Tree a  b = Node a b (Tree a b) (Tree a b) | Leaf | Dummy

/*
:: Test = {
		name		:: Bool
	,	veld		:: Int
	};
*/

what_is_it (Node _ _ t1 t2) = 1
what_is_it (Leaf)	= 2

f3 :: Dynamic -> Int
f3 (t :: Tree Int Int)
	= what_is_it t
