module selfGECexamples

/********************************************************************
*                                                                   *
*   This module contains some small examples using selfGEC.         *
*                                                                   *
********************************************************************/

import StdEnv, StdIO
import basicEditors, StdGEC

// TO TEST JUST REPLACE THE EXAMPLE NAME myEditor IN THE START RULE WITH ANY OF THE EXAMPLES BELOW
// ALL EXAMPLES HAVE TO BE OF TYPE ((PSt Void) -> (PSt Void))

Start :: *World -> *World
Start world = startGEC myEditor2 world

// Self sorting list

myEditor1 = selfGEC "Self Sorting List" sort [1..5]

// Self balancing tree

import tree
derive gGEC Tree

myEditor2 = selfGEC "Tree" balanceTree (Node Leaf 1 Leaf)

// Playing with buttons

from   guigecs import defTextWidths

myEditor3 = selfGEC "Buttons" handlebuts (initbuts 0)
where
	initbuts i	= i <|> OneTwoThree <|> (Button defTextWidths "Clear")
	OneTwoThree = but "1" <-> but "2" <-> but "3"
	but i		= Button (defTextWidths/3) i

 	handlebuts (i <|> onetwothree <|> Pressed) = initbuts 0                                            
 	handlebuts (i <|> (Pressed<->two<->three) <|> clear) = initbuts (i+1)                                             
  	handlebuts (i <|> (one<->Pressed<->three) <|> clear) = initbuts (i+2)                                             
  	handlebuts (i <|> (one<->two<->Pressed)   <|> clear) = initbuts (i+3)                                             
	handlebuts else = else                                             

        