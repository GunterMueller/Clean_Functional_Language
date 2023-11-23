module equivalent_type_implementations_within_an_application

import StdDynamic

import m1

:: Tree a = Node a (Tree a) (Tree a) | Leaf | Test [Tree a] Real

Start
	= m1_func (dynamic tree)
where
	tree
		= Node 1 Leaf Leaf
		