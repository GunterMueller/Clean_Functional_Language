module test

import StdDynamic
import StdEnv

import tree
import tree2
import tree3

//:: Tree a  b = Leaf | E.via Node a  b via (Tree a b) (Tree a b)

/*111
:: Test = 1
11		name		:: Bool
	,	veld		:: !Int
	};
*/
	
:: Tree a  b = Node a b (Tree a b) (Tree a b) | Leaf | Dummy


Start world
	# (ok,world)
		= writeDynamic "yepDynamic" (dynamic Node 1 2 Leaf Leaf) world
		
	# (ok,dyn,world)
		= readDynamic "yepDynamic" world
	= ("hallo",f3 dynamic Node 1 2 Leaf Leaf)
// readDynamic :: String *f -> (Bool,Dynamic,*f) | FileSystem f


// Draft version, thesis 'First Class File I/O', page 38
// 'If we had used dynamics only within the boundaries of a single program, where all type
//  definitions are known throughout the entire prograzm a *simple* encoding of a type
//  definition would have been sufficient.'
//
// *simple*	
// The encoding would not be that simple. At least all equally named type definitions but 
// structurally different type definitions, must be distinguishable.
//
// Example 2.3.3. is wrong because it does not deal with the above mentioned type
// definitions. The problem can be solved by refining the given string representation of
// a type.
// 
// Using the following name scheme the above problem can be solved:
// type_name'module_name
//
// For example:
// Bool'StdBool
// Tree'test
// Tree'tree
// 
// Now the counterexample will behave as it should.\


