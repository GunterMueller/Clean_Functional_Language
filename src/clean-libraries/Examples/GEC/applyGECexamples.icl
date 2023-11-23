module applyGECexamples

import StdEnv, StdIO
import basicEditors, StdGEC

// TO TEST JUST REPLACE THE EXAMPLE NAME myEditor IN THE START RULE WITH ANY OF THE EXAMPLES BELOW
// ALL EXAMPLES HAVE TO BE OF TYPE ((PSt Void) -> (PSt Void))

Start :: *World -> *World
Start world = startGEC myEditor2 world

// modifying a list to balanced tree

import tree
derive gGEC Tree 

myEditor1 = applyGECs ("List","Balanced Tree") fromListToBalTree [1,5,2]     

// same, but now ensure that the resulting tree cannot be edited
// using a specialisation for the type Mode


myEditor2 = applyGECs ("List","Balanced Tree") (Display o fromListToBalTree) [1,5,2]     

