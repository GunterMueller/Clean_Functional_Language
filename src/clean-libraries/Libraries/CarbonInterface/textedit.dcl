definition module textedit;

import mac_types;

::	TEHandle	:==	Handle;
::	CharsHandle	:==	Handle;

TEFlushDefault	:==	0;		TEJustLeft		:==	0;		// Flush according to system direction
TECenter		:==	1;		TEJustCenter	:==	1;		// Centered for all scripts
TEFlushRight	:==	-1;		TEJustRight		:==	-1;		// Flush right for all scripts
TEFlushLeft		:==	-2;		TEForceLeft		:==	-2;		// Flush left for all scripts

TEScrpHandle	:==	2740;								// Handle to TextEdit scrap (0xAB4)
TEScrpLength	:==	2736;								// Size in bytes of TextEdit scrap (long, 0xAB0)

teLengthOffset	:==	60;									// The offset to the teLength field in a TERec record
hTextOffset		:==	62;									// The offset to the hText    field in a TERec record

//	Initialization, creation and disposing.
TEInit :: !*Toolbox -> *Toolbox;
TENew :: !Rect !Rect !*Toolbox -> (!TEHandle,!*Toolbox);
TEDispose :: !TEHandle	!*Toolbox -> *Toolbox;

//	Activating, deactivating.
TEActivate 	:: !TEHandle !*Toolbox -> *Toolbox;
TEDeactivate :: !TEHandle !*Toolbox -> *Toolbox;

//	Setting and getting text.
TEKey :: !Char !TEHandle !*Toolbox -> *Toolbox;
TESetText :: !{#Char} !TEHandle !*Toolbox -> *Toolbox;
TEGetText :: !TEHandle !*Toolbox -> (!CharsHandle,!*Toolbox);

//	Setting caret and selection.
TEIdle :: !TEHandle !*Toolbox -> *Toolbox;
TEClick :: !(!Int,!Int) !Bool !TEHandle	!*Toolbox -> *Toolbox;
TESetSelect :: !Int !Int !TEHandle !*Toolbox -> *Toolbox;

//	Displaying and scrolling text.
TEUpdate :: !Rect !TEHandle	!*Toolbox -> *Toolbox;
TETextBox :: !{#Char} !Rect !Int !*Toolbox -> *Toolbox;
TECalText :: !TEHandle	!*Toolbox -> *Toolbox;
TEScroll :: !Int !Int !TEHandle	!*Toolbox -> *Toolbox;
TEPinScroll :: !Int !Int !TEHandle	!*Toolbox -> *Toolbox;
TEAutoView :: !Bool !TEHandle !*Toolbox -> *Toolbox;
TESelView :: !TEHandle	!*Toolbox -> *Toolbox;

//	Modifying text.
TEDelete :: !TEHandle !*Toolbox -> *Toolbox;
TEInsert :: !{#Char} !TEHandle	!*Toolbox -> *Toolbox;
TECut :: !TEHandle !*Toolbox -> *Toolbox;
TECopy :: !TEHandle !*Toolbox -> *Toolbox;
TEPaste :: !TEHandle !*Toolbox -> *Toolbox;

//	Byte offsets and Points.
TEGetOffset :: !(!Int,!Int) !TEHandle !*Toolbox -> (!Int,!*Toolbox);
