definition module Help

import	StdString
from	StdPSt		import :: PSt

showAbout :: String String (PSt .l) -> PSt .l
/*	showAbout opens a window:
	-	it has the title of the application name (argument 1),
	-	it displays the about information of the application (found in the helpfile, argument 2),
	-	it has an Ok button that closes this window, 
	-	it has a Help button that displays the help information (see showHelp).
*/


showHelp :: String (PSt .l) -> PSt .l
/*	showHelp opens a SDI process that displays the help information found in the helpfile 
	(argument 1).
*/
