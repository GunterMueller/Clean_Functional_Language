module apply2GECexamples

import StdEnv, StdIO
import basicEditors, StdGEC

// TO TEST JUST REPLACE THE EXAMPLE NAME myEditor IN THE START RULE WITH ANY OF THE EXAMPLES BELOW
// ALL EXAMPLES HAVE TO BE OF TYPE ((PSt Void) -> (PSt Void))

Start :: *World -> *World
Start world = startGEC myEditor1 world

// two lists editors resulting in a balanced tree

import tree
derive gGEC Tree

myEditor1 = apply2GECs ("List1","List2","Balanced Tree") makeBalancedTree [1] [1]      
where                                                                               
    makeBalancedTree l1 l2 = fromListToBalTree (l1 ++ l2)                                

// two lists editors resulting in a non-editable balanced tree


myEditor2 = apply2GECs ("List1","List2","Balanced Tree") makeBalancedTree [1] [1]      
where                                                                               
    makeBalancedTree l1 l2 = Display (fromListToBalTree (l1 ++ l2))                                
