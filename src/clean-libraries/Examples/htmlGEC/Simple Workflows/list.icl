module list

import StdEnv, StdHtml

// (c) 2007 MJP

// Just a simple test to see if more complex iData editors can be used
// A list can be edited by user 0 and is shipped for further editing to user 1 
// When finished the sum of the list is displayed by user 0

derive gForm []
derive gUpd  []

Start world = doHtmlServer (multiUserTask 2 True listControl) world

listControl
=	[Txt "Define the list:",Br,Br] 
	?>>	appIData (vertlistFormButs 5 True (Init,sFormId "list0" [0])) =>> \list ->	
	("Control List:",1) 
	@:	[Txt "Check the list:",Br,Br] 
		?>>	appIData (vertlistFormButs 1 True (Init,sFormId "list1" list)) =>> \list ->
	[Txt "sum of list = ",Br,Br] 
	?>>	editTask "OK" (DisplayMode (sum list))		 
