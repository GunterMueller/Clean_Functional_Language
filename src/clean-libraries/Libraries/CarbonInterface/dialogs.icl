implementation module dialogs;

import mac_types;

::	ProcPtr :== Int;

//	Creating and Disposing of Dialogs

NewDialog :: !Ptr !Rect !{#Char} !Bool !Int !WindowPtr !Bool !Int !Handle !*Toolbox -> (!DialogPtr, !*Toolbox);
NewDialog dStorage (left,top,right,bottom) title visible procID behind goAwayFlag refCon items t 
= code (right=W,bottom=W,left=W,top=W,dStorage=D0,title=O0D1SD2,visible=D3,procID=D4, 
	behind=D5,goAwayFlag=D6,refCon=D7,items=A0,t=U) (dialog=D0,z=I8Z)
{
	instruction 0x703E001F	|	andi. r30,r1,31
	instruction	0x7C3E0850	|	sub r1,r1,r30
                                       		                    
	instruction 0x92E1FFF8	|	stw	r23,-8(sp)
	call	.NewDialog

	instruction 0x7C21F214	|	add r1,r1,r30
};

NewCDialog :: !Ptr !Rect !{#Char} !Bool !Int !WindowPtr !Bool !Int !Handle !*Toolbox -> (!DialogPtr,!*Toolbox);
NewCDialog dStorage (left,top,right,bottom) title visible procID behind goAwayFlag refCon items t
= code (right=W,bottom=W,left=W,top=W,dStorage=D0,title=O0D1SD2,visible=D3,procID=D4,
	behind=D5,goAwayFlag=D6,refCon=D7,items=A0,t=U) (dialog=D0,z=I8Z)
{
	instruction 0x703E001F	|	andi. r30,r1,31
	instruction	0x7C3E0850	|	sub r1,r1,r30

	instruction 0x92E1FFF8	|	stw	r23,-8(sp)
	call	.NewColorDialog

	instruction 0x7C21F214	|	add r1,r1,r30
};

NewFeaturesDialog :: !Ptr !Rect !{#Char} !Bool !Int !WindowPtr !Bool !Int !Handle !Int !*Toolbox -> (!DialogPtr,!*Toolbox);
NewFeaturesDialog dStorage rect title visible procID behind goAwayFlag refCon items flags t
	= NewFeaturesDialog1 dStorage rect title (if visible 1 0) procID behind (if goAwayFlag 1 0) refCon items flags t;

NewFeaturesDialog1 :: !Ptr !Rect !{#Char} !Int !Int !WindowPtr !Int !Int !Handle !Int !*Toolbox -> (!DialogPtr,!*Toolbox);
NewFeaturesDialog1 dStorage (left,top,right,bottom) title visible procID behind goAwayFlag refCon items flags t
= code (right=W,bottom=W,left=W,top=W,dStorage=D0,title=O0D1SD2,visible=D3,procID=D4,
	behind=D5,goAwayFlag=D6,refCon=D7,items=A0,flags=A1,t=U) (dialog=D0,z=I8Z)
{
	instruction 0x703E001F	|	andi. r30,r1,31
	instruction	0x7C3E0850	|	sub r1,r1,r30

	instruction 0x92E1FFF8	|	stw	r23,-8(sp)
	instruction 0x92C1FFF4	|	stw	r22,-12(sp)
	call	.NewFeaturesDialog

	instruction 0x7C21F214	|	add r1,r1,r30
};

GetNewDialog :: !Int !Ptr !WindowPtr !*Toolbox -> (!DialogPtr,!*Toolbox);
GetNewDialog dialogID dStorage behind t = code (dialogID=D0,dStorage=D1,behind=D2,t=U)(dialog_pointer=D0,z=Z){
	call .GetNewDialog
};

DisposDialog :: !DialogPtr !*Toolbox -> *Toolbox;
DisposDialog theDialog t = code (theDialog=D0,t=U)(z=Z){
	call	.DisposeDialog
};

DrawDialog :: !DialogPtr !*Toolbox -> *Toolbox;
DrawDialog theDialog t = code (theDialog=D0,t=U)(z=Z){
	call	.DrawDialog
};

SetDialogFont :: !Int !*Toolbox -> *Toolbox;
SetDialogFont font_number t = code (font_number=D0,t=U)(z=Z){
	call	.SetDialogFont
};

//	Handling Dialog Events

ModalDialog :: !ProcPtr !DialogPtr !*Toolbox -> (!Int,!*Toolbox);
//ModalDialog filterProc dialog t = code (filterProc=R2D0,dialog=O0D1U,t=U)(itemHit=W,z=Z){
ModalDialog filterProc dialog t = code (filterProc=R4D0,dialog=O0D1U,t=U)(itemHit=W,z=I2Z){
	call	.ModalDialog
};

IsDialogEvent :: !(!Int,!Int,!Int,!Int,!Int,!Int) !*Toolbox -> (!Bool,!*Toolbox);
IsDialogEvent event tb = IsDialogEvent1 event;

IsDialogEvent1 :: !(!Int,!Int,!Int,!Int,!Int,!Int) -> (!Bool,!*Toolbox);
IsDialogEvent1 (what,message,when,h,v,modifiers) = code (modifiers=W,h=W,v=W,when=L,message=L,what=W)(result=B0,z=I16Z){
	instruction 0x38610000	|	addi	r3,sp,0
	call	.IsDialogEvent
};

DialogSelect :: !(!Int,!Int,!Int,!Int,!Int,!Int) !*Toolbox -> (!Bool,!DialogPtr,!Int,!*Toolbox);
DialogSelect r t = DialogSelect1 r;

DialogSelect1 :: !(!Int,!Int,!Int,!Int,!Int,!Int) -> (!Bool,!DialogPtr,!Int,!*Toolbox);
DialogSelect1 (what,message,when,h,v,modifiers) = code (modifiers=W,h=W,v=W,when=L,message=L,what=W)(result=B0,theDialog=L,itemHit=W,z=I18Z){
	instruction 0x3821FFF8	|	subi	sp,sp,8
	instruction 0x38610008	|	addi	r3,sp,8
	instruction 0x38810000	|	addi	r4,sp,0
	instruction 0x38A10004	|	addi	r5,sp,4
	call	.DialogSelect
};

//	Invoking Alerts

//	Manipulating Items in Dialogs and Alerts

GetDItem :: !DialogPtr !Int !*Toolbox -> (!Int,!Handle,!Rect,!*Toolbox);
GetDItem theDialog itemNo tb
	=	(itemType,item,(left,top,right,bottom),NewToolbox);
	{
		(itemType,item,right,bottom,left,top) = GetDItem1 theDialog itemNo tb
	};

GetDItem1 :: !DialogPtr !Int !*Toolbox -> (!Int,!Handle,!Int,!Int,!Int,!Int);
//GetDItem1 theDialog itemNo t = code (theDialog=R14D0,itemNo=D1,t=O0D2O2D3O6D4U)(itemType=W,item=L,right=W,bottom=W,left=W,top=W){
GetDItem1 theDialog itemNo t = code (theDialog=R16D0,itemNo=D1,t=O0D2O4D3O8D4U)(itemType=W,item=I2L,right=W,bottom=W,left=W,top=W){
	call	.GetDialogItem
};

SetIText :: !Handle !{#Char} !*Toolbox -> *Toolbox;
SetIText item text t = code (item=D0,text=SD1,t=U)(z=Z){
	call	.SetDialogItemText
};

GetIText :: !Handle !{#Char} !*Toolbox -> (!{#Char},!*Toolbox);
GetIText item text tb = (GetIText1 item text tb, NewToolbox);

GetIText1 :: !Handle !{#Char} !*Toolbox -> {#Char};
GetIText1 item text t = code (item=D0,text=U,t=U)(new_text=A0){
	instruction 0x3AA00000	|	li		r21,0
	instruction 0x92B70004	|	stw		r21,4(r23)
	instruction 0x38970007	|	addi	r4,r23,7
	call	.GetDialogItemText
};

SelIText :: !DialogPtr !Int !Int !Int !*Toolbox -> *Toolbox;
SelIText theDialog itemNo strtSel endSel t = code (theDialog=D0,itemNo=D1,strtSel=D2,endSel=D3,t=U)(z=Z){
	call	.SelectDialogItemText
};

SetDialogDefaultItem :: !DialogPtr !Int !*Toolbox -> (!Int,!*Toolbox);
SetDialogDefaultItem theDialog newItem tb = code (theDialog=D0,newItem=D1,tb=U)(r=D0,z=Z){
	call .SetDialogDefaultItem
};

SetDialogCancelItem :: !DialogPtr !Int !*Toolbox -> (!Int,!*Toolbox);
SetDialogCancelItem theDialog newItem tb = code (theDialog=D0,newItem=D1,tb=U)(r=D0,z=Z){
	call .SetDialogCancelItem
};

OutlineButtonFunction :: ProcPtr;
OutlineButtonFunction = code ()(function_address=D0){
	call	.myoutlinebuttonfunction
}

DisposeUserItemUPP :: !ProcPtr !*Toolbox -> *Toolbox;
DisposeUserItemUPP proc_ptr t = code (proc_ptr=D0,t=U)(z=Z){
	call	.DisposeUserItemUPP
}
