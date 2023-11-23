definition module htmlStylelib

import htmlStyleDef, StdInt

// predefined styles used internally, may also be used by end-user
// can be redefined if one does not like the styles chosen

CleanStyle 			:: Standard_Attr	// for text
EditBoxStyle 		:: Standard_Attr	// for an editable box
DisplayBoxStyle 	:: Standard_Attr	// for a non-editable box
TableHeaderStyle 	:: Standard_Attr	// for table headers
TableRowStyle 		:: Standard_Attr	// for tables

// Some related default constants used for the length of input boxes

defsize  :== 12 						// size of inputfield
defpixel :== 107						// size in pixels for buttons, pull-down buttons

// definition of clean styles

CleanStyles			:: [Style]
