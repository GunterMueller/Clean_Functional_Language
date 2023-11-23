implementation module htmlDefault

import StdGeneric

// default values generator

generic defval a ::  a 
defval{|Int|}  				= 0
defval{|Real|}  			= 0.0
defval{|String|}  			= ""
defval{|UNIT|} 			 	= UNIT
defval{|EITHER|} dl dr  	= RIGHT  dr
//defval{|EITHER|} dl dr   	= LEFT   dl
defval{|PAIR|}   dl dr  	= PAIR   dl dr
defval{|CONS|}   dc     	= CONS   dc
defval{|FIELD|}  df     	= FIELD  df
defval{|OBJECT|} do     	= OBJECT do
//defval{|AGEC|}   da 	    = undef

defaultval :: a | defval{|*|} a
defaultval = defval {|*|}
