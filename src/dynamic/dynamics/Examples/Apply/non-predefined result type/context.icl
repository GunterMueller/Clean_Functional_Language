module context

// levert een foutmelding van de dynamische linker op dat het type
// Tree geimplementeerd wordt door twee implementaties i.e. die van
// de dynamic en die van de applicatie aan de andere kant.
import StdDynamic, StdEnv
import StdDynamicFileIO
import path

:: Tree a = Node a (Tree a) (Tree a) | Leaf | Test [Tree a] Real

Start world
	# (ok,v,world)
		= readDynamic (p +++ "\\value") world
	| not ok
		= abort " could not read"

	# (ok,f,world)
		= readDynamic (p +++ "\\context_function") world
	| not ok
		= abort " could not read"
		
		
	#! q
		= eval_function f v == 6
	| q
		= match_against_own_tree f 
		= abort "mag niet false zijn"
			
eval_function (f :: a -> Int) (v :: a)
	= f v

match_against_own_tree (f :: (Tree Int) -> Int)
	= f Leaf
	
	