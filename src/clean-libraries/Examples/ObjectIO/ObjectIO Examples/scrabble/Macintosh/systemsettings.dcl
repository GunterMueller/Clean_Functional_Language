definition module systemsettings


import	StdPicture


/*	This module contains macro's to make the scrabble application platform customisable.
*/


//	For graphics:

//	Font information:

font size			:==	{SerifFontDef & fSize=size}
letterfont			:== {SerifFontDef & fSize=10,fStyles=[BoldStyle]}
smallfont			:== {fName="Helvetica",fSize=6,fStyles=[]}

//	Background colour:

rbBackground		:==	White

