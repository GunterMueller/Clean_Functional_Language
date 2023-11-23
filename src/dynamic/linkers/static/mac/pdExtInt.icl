implementation module pdExtInt;

import
	StdEnv;
	
write_long :: Int Int *{#Char} -> *{#Char};
write_long w index array
	= {array & [index]=toChar (w>>24),[index1]=toChar (w>>16),[index2]=toChar (w>>8),[index3]=toChar w};{
		index1=index+1;
		index2=index+2;
		index3=index+3;
	}
	
FromIntToString :: !Int -> !String;
FromIntToString v
	= { (toChar (v>>24)), (toChar (v>>16)), (toChar (v>>8)), (toChar v) };
	
FromStringToInt :: !String !Int -> !Int;
FromStringToInt array i
	= (toInt v3)+(toInt v2<<8)+(toInt v1<<16)+(toInt v0<<24);
where {
	v0
		= array.[i];
	v1
		= array.[i+1];
	v2 
		= array.[i+2];
	v3  
		= array.[i+3];
}	