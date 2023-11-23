implementation module my_scrap;

import StdClass,StdInt;
from StdArray import createArray,createArray_u;

import memory;

from ioState import IOState,IOStateSetToolbox;

TextResourceType :== 0x54455854;	// 'TEXT'

IOPutScrap :: !{#Char} !(IOState s) -> IOState s;
IOPutScrap string io
	| PutScrap string TextResourceType ZeroScrap==0
		= io;
		= io;

IOGetScrap :: !(IOState s) -> (!{#Char},!IOState s);
IOGetScrap io
	| handle==0
		= ("",io);
	| size<=0
		= ("",IOStateSetToolbox t2 io);
		{
			(error,t2)=DisposHandle handle t1;
		}
		= (string,IOStateSetToolbox t3 io);
		{
			(error,t3)=DisposHandle handle t2;
			(string,t2)=handle_to_string handle size t1;
		}
	{
		(size,offset,t1)=GetScrap handle TextResourceType;
		(handle,new_handle_error,t0)=NewHandle 0 NewToolbox;
	}

handle_to_string :: !Handle !Int !*Toolbox -> (!{#Char},!*Toolbox);
handle_to_string handle size t0
	=	(string,t1);
	{
		t1=copy_handle_data_to_string string handle size t0;
		string = createArray size ' ';
	}

PutScrap :: !{#Char} !Int !Int -> Int;
/*
PutScrap string resource_type t = code (string=U,resource_type=D1,t=U)(r=D0){
	instruction 0x38B70008	|	addi	r5,r23,8
	instruction 0x80770004	|	lwz		r3,4(r23)
	call	.PutScrap
}
*/
PutScrap string resource_type t = code (string=CS0D2,resource_type=D1,t=U)(r=D0){
	call	.PutScrap
}

ZeroScrap :: Int;
ZeroScrap = code ()(r=D0){
	call	.ZeroScrap
}

GetScrap :: !Handle !Int -> (!Int,!Int,!*Toolbox);
GetScrap handle resource_type = code (handle=D0,resource_type=R4O0D2D1)(r=D0,offset=L,t=Z){
	call	.GetScrap
}
