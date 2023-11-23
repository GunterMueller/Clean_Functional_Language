module simpleGECexamples

// Just some simple editors showing values

import StdEnv, StdIO
import basicEditors

// TO TEST JUST REPLACE THE EXAMPLE NAME myEditor IN THE START RULE WITH ANY OF THE EXAMPLES BELOW
// ALL EXAMPLES HAVE TO BE OF TYPE ((PSt Void) -> (PSt Void))

Start :: *World -> *World
Start world = startGEC myEditor4 world

// List Editor
                                               
myEditor0 = mkGEC "List" [1]

// Tree Editor

import tree
derive gGEC Tree

myEditor1 = mkGEC "Tree" (Node Leaf 1.5 Leaf)
                                               
// Record Editor

:: MyRecord = 	{ name    :: String
				, street  :: String
				, number  :: Int
				, married :: Bool
				}
derive gGEC MyRecord

myEditor2 = mkGEC "Record" initRecord

initRecord = { name = "Blair", street = "Downingstreet" 
						   , number = 10, married = True }

// some combinations of simple editors using layout combinators <-> and <|> from tupleAGEC


myEditor3 = mkGEC "LayOut" init
where
	init = 0 <-> (initRecord <|> (True <-> 0))
	
// showing buttons

from   guigecs import defTextWidths

myEditor4 = mkGEC "Buttons" init
where
	init 		= OneTwoThree <|> (Button defTextWidths "Stop")
	OneTwoThree = but "1" <-> but "2" <-> but "3"
	but i		= Button (defTextWidths/3) i


	