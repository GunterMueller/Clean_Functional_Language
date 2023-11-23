implementation module memory;

import mac_types;

NewHandle :: !Int !*Toolbox -> (!Handle,!Int,!*Toolbox);
NewHandle logicalSize t = (handle,error,t3);
{
	(error,t3)=MemError t2;
	(handle,t2)=NewHandle2 logicalSize t;
}

	NewHandle2 :: !Int !*Toolbox -> (!Handle,!*Toolbox);
	NewHandle2 logicalSize t = code (logicalSize=D0,t=U)(handle=D0,z=Z){
		call	.NewHandle
	};

DisposHandle :: !Handle !*Toolbox -> (!Int,!*Toolbox);
DisposHandle h t = code (h=D0,t=U)(result_code=D0,z=Z){
	call	.DisposeHandle
};

NewPtr :: !Int !*Toolbox -> (!Ptr,!Int,!*Toolbox);
NewPtr logicalSize t = (pointer,error,t3);
{
	(error,t3)=MemError t2;
	(pointer,t2)=NewPtr2 logicalSize t;
}

	NewPtr2 :: !Int !*Toolbox -> (!Ptr,!*Toolbox);
	NewPtr2 _ _ = code {
		ccall NewPtr "I:I:I"
		};

DisposePtr :: !Ptr !*Toolbox -> *Toolbox;
DisposePtr _ _ = code {
	ccall DisposePtr "I:V:I"
	};

MemError :: !*Toolbox -> (!Int,!*Toolbox);
MemError t = code {
	ccall MemError ":I:I"
	};

GetHandleSize :: !Handle !*Toolbox -> (!Int,!*Toolbox);
GetHandleSize handle t = code (handle=D0,t=U)(size=D0,t2=Z){
	call	.GetHandleSize
}

copy_handle_data_to_string :: !{#Char} !Handle !Int !*Toolbox -> *Toolbox;
copy_handle_data_to_string string handle size t0 = code (string=CD1,handle=D0,size=D2,t0=U)(t1=Z){
	instruction 0x80630000	|	lwz		r3,0(r3)
	call	.BlockMoveData
}	

copy_string_slice_to_memory :: !s:{#Char} !Int !Int !Int !*Toolbox -> (!s:{#Char},!*Toolbox);
copy_string_slice_to_memory string offset size pointer t0 = code (string=CD0,offset=D3,size=D2,pointer=D1,t0=U)(s=A0,t1=Z){
	instruction 0x7C633214	|	add	r3,r3,r6
	call	.BlockMoveData
}	

copy_string_to_handle :: !{#Char} !Handle !Int !*Toolbox -> *Toolbox;
copy_string_to_handle string handle size tb = code (string=U,handle=D1,size=D2,tb=U)(z=Z){
	instruction 0x80840000	|	lwz		r4,0(r4)
	instruction 0x38770008	|	addi	r3,r23,8	
	call	.BlockMoveData
};
