implementation module tree

import StdEnv
import StdDynamic

//:: *R ls = { f1 :: (*ls, Int) }

/*
:: Tree = Leaf Int | Node Tree Tree

what_is_it (Node t1 t2) = "Node"
what_is_it (Leaf a)	= "Leaf"

f :: Dynamic -> Int
f (t :: Tree)
	= abort ("Een match 2" +++ what_is_it t)
*/

:: Tree c d = Node c d (Tree c d) (Tree c d) | Leaf
//:: Tree a  b = E.via Node a b via (Tree a b) (Tree a b) | Leaf

/*
:: Test = {
		name		:: Bool
	,	veld		:: Int
	};
*/

what_is_it (Node  _ _ t1 t2) = 1
what_is_it (Leaf)	= 2

f :: Dynamic -> Int
f (t :: Tree Int Int)
	= what_is_it t
