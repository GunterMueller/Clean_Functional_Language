definition module dialogs;

import mac_types;

::	ProcPtr :== Int;
//	Creating and Disposing of Dialogs

NewDialog		:: !Ptr !Rect !{#Char} !Bool !Int !WindowPtr !Bool !Int !Handle !*Toolbox -> (!DialogPtr,!*Toolbox);
NewCDialog		:: !Ptr !Rect !{#Char} !Bool !Int !WindowPtr !Bool !Int !Handle !*Toolbox -> (!DialogPtr,!*Toolbox);
NewFeaturesDialog :: !Ptr !Rect !{#Char} !Bool !Int !WindowPtr !Bool !Int !Handle !Int !*Toolbox -> (!DialogPtr,!*Toolbox);
GetNewDialog :: !Int !Ptr !WindowPtr !*Toolbox -> (!DialogPtr,!*Toolbox);
DisposDialog	:: !DialogPtr !*Toolbox -> *Toolbox;

DrawDialog :: !DialogPtr !*Toolbox -> *Toolbox;
SetDialogFont :: !Int !*Toolbox -> *Toolbox;

//	Handling Dialog Events

ModalDialog		:: !ProcPtr !DialogPtr				!*Toolbox -> (!Int, !*Toolbox);
IsDialogEvent	:: !(!Int,!Int,!Int,!Int,!Int,!Int) !*Toolbox -> (!Bool,!*Toolbox);
DialogSelect	:: !(!Int,!Int,!Int,!Int,!Int,!Int) !*Toolbox -> (!Bool,!DialogPtr,!Int,!*Toolbox);

//	Invoking Alerts

//	Manipulating Items in Dialogs and Alerts

GetDItem				:: !DialogPtr !Int !*Toolbox -> (!Int,!Handle,!Rect,!*Toolbox);
SetIText				:: !Handle !{#Char} !*Toolbox -> *Toolbox;
GetIText				:: !Handle !{#Char} !*Toolbox -> (!{#Char},!*Toolbox);
SelIText				:: !DialogPtr !Int !Int !Int !*Toolbox -> *Toolbox;
SetDialogDefaultItem :: !DialogPtr !Int !*Toolbox -> (!Int,!*Toolbox);
SetDialogCancelItem :: !DialogPtr !Int !*Toolbox -> (!Int,!*Toolbox);
OutlineButtonFunction	:: ProcPtr;
DisposeUserItemUPP :: !ProcPtr !*Toolbox -> *Toolbox;
