implementation module m1

import StdEnv
import StdDynamic

:: Tree a = Node a (Tree a) (Tree a) | Leaf | Test [Tree a] Real

m1_func :: Dynamic -> Int
m1_func (t :: (Tree Int))
	= abort "Tree Int";
m1_func _
	= abort "faalt";
	
count :: (Tree Int) Int -> Int
count Leaf n_leafs
	= inc n_leafs
count (Node _ left right) n_leafs
	= count left (count right n_leafs)
count q _
	= abort "count does not match";
