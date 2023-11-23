module arrowexamplesGEC

import StdEnv
import StdIO
import StdGEC
//from StdGecComb import selfGEC, :: CGEC

// TO TEST JUST REPLACE THE EXAMPLE NAME IN THE START RULE WITH ANY OF THE EXAMPLES BELOW
// ALL EXAMPLES HAVE TO BE OF FORM pst -> pst

goGui :: (*(PSt u:Void) -> *(PSt u:Void)) *World -> .World
goGui gui world = startIO MDI Void gui [ProcessClose closeProcess] world

Start :: *World -> *World
Start world 
= 	goGui 
 	example1
 	world  

:: BalancedTree a  	
				= BNode .(BalancedNode a)
				| BEmpty 
:: BalancedNode a =
				{ bigger :: .BalancedTree a
				, bvalue  :: a 
				, smaller:: .BalancedTree a
				} 

derive gGEC   	BalancedTree, BalancedNode//, OperatorTest

BalanceTree :: (BalancedTree a) -> (BalancedTree a) | Ord a
BalanceTree tree = toBalTree (BalTreetoList tree)

BalTreetoList :: (BalancedTree a) -> [a]
BalTreetoList BEmpty = []
BalTreetoList (BNode record) = (BalTreetoList record.bigger) ++ [record.bvalue] ++ (BalTreetoList record.smaller)	

toBalTree :: [a] -> BalancedTree a | Ord a
toBalTree list = Balance (sort list)
where
	Balance [] = BEmpty
	Balance [x] = BNode {bigger=BEmpty,bvalue=x,smaller=BEmpty}
	Balance xs
		= case splitAt (length xs/2) xs of
			(a,[b:bs]) = BNode {bigger=Balance bs,bvalue=b,smaller=Balance a}
			(as,[])    = BNode {bigger=BEmpty,bvalue=hd (reverse as),smaller=Balance (reverse (tl (reverse as)))} 

example1 = startCircuit mycircuit2 [1..5]  // connecting two editors 
where
//	mycircuit  = edit "list" <<@ toBalTree >>> edit "balanced tree"
	mycircuit2 = edit "list" >>> arr toBalTree >>> edit "balanced tree" // alternative definition

derive ggen BalancedTree, BalancedNode


example2 = startCircuit mycircuit3 (toBalTree [1..5]) // self balancing tree
where
	mycircuit  = feedback (edit "self balancing tree" >>> arr BalanceTree)
	mycircuit2 = feedback (edit "self balancing tree" <<< arr BalanceTree) // alternative
	mycircuit3 = feedback (arr BalanceTree >>> edit "self balancing tree") // alternative
	mycircuit4 = feedback (arr BalanceTree >>> edit "self balancing tree") // alternative

example3 = startCircuit mycircuit [1..5] // merge
where
	mycircuit     = evenCircuit &&& oddCircuit >>> balancedtree
	evenCircuit   = arr takeEven  >>> edit "part1"
	oddCircuit    = arr takeOdd   >>> edit "part2"
	balancedtree  = arr convert   >>> edit "balanced tree"

	takeEven list = [e \\ e <- list | isEven e]
	takeOdd list  = [e \\ e <- list | isOdd e]
	convert (f,s) = toBalTree (s ++ f) 


