implementation module pointer;

import mac_types;

ClearLong :: !Ptr !*Toolbox -> *Toolbox;
ClearLong ptr tb = ClearLong1 ptr;

ClearLong1 :: !Ptr -> *Ptr;
ClearLong1 p = code (p=U)(q=A0){
	instruction	0x3B200000	|	li	r25,0
	instruction 0x93380000	|	stw	r25,0(r24)
};

LoadLong :: !Ptr !*Toolbox -> (!Int,!*Toolbox);
LoadLong ptr tb = (LoadLong1 ptr, tb);

LoadLong1 :: !Ptr -> Int;
LoadLong1 p = code (p=U)(r=A0){
	instruction 0x83180000	|	lwz	r24,0(r24)
};

LoadWord :: !Ptr !*Toolbox -> (!Int,!*Toolbox);
LoadWord ptr tb = (LoadWord1 ptr,tb);

LoadWord1 :: !Ptr -> Int;
LoadWord1 p = code (p=U)(r=A0){
	instruction	0xAB180000	|	lha	r24,0(r24)
};

LoadByte :: !Ptr !*Toolbox -> (!Int,!*Toolbox);
LoadByte ptr tb = (LoadByte1 ptr,tb);

LoadByte1 :: !Ptr -> Int;
LoadByte1 p = code (p=U)(r=A0){
	instruction	0x8B180000	|	lbz	r24,0(r24)
};

StoreLong :: !Ptr !Int !*Toolbox -> *Toolbox;
StoreLong ptr v tb = StoreLong1 ptr v;

StoreLong1 :: !Ptr !Int -> *Ptr;
StoreLong1 p v = code (p=U,v=U)(q=A0){
	instruction	0x93190000	|	stw	r24,0(r25)
	instruction	0x7F38CB78	|	mr	r24,r25
};

StoreWord :: !Ptr !Int !*Toolbox -> *Toolbox;
StoreWord ptr v tb = StoreWord1 ptr v;

StoreWord1 :: !Ptr !Int -> *Ptr;
StoreWord1 p v = code (p=U,v=U)(q=A0){
	instruction 0xB3190000	|	sth	r24,0(r25)
	instruction 0x7F38CB78	|	mr	r24,r25
};

StoreByte :: !Ptr !Int !*Toolbox -> *Toolbox;
StoreByte ptr v tb = StoreByte1 ptr v;

StoreByte1 :: !Ptr !Int -> *Ptr;
StoreByte1 p v = code (p=U,v=U)(q=A0){
	instruction 0x9B190000	|	stb	r24,0(r25)
	instruction	0x7F38CB78	|	mr	r24,r25
};

/*
IsEvaluated :: node !*Toolbox -> (!Bool,!*Toolbox);
IsEvaluated node tb = (IsEvaluated1 node,tb);
	
IsEvaluated1 :: node -> Bool;
IsEvaluated1 node = code (node=A0)(result=D0){
	instruction 0x2010		||	move.l	(a0),d0
	instruction	0xD080		||	add.l	d0,d0
	instruction 0x9180		||	subx.l	d0,d0
};
*/
