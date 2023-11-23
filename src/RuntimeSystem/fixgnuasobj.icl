module fixgnuasobj;

import StdInt,StdChar,StdString,StdBool,StdFile,StdArray,StdMisc,StdClass;

import ArgEnv;

/*
	swap_bytes i = ((i>>24) bitand 0xff) bitor ((i>>8) bitand 0xff00) bitor ((i<<8) bitand 0xff0000) bitor (i<<24);
	
	Freadi :: !*File -> (!Bool,!Int,!*File);
	Freadi f0 = (b,swap_bytes i,f1);
	{
		(b,i,f1)=freadi f0;
	}
	
	Fwritei i f :== fwritei (swap_bytes i) f;
*/

Freadi f:==freadi f;
Fwritei i f:==fwritei i f;

read_little_endian_word_at offset f0
	| ok1 && ok2
		= (i,f2);
	{}{
		(ok2,i,f2)=Freadi f1;
		(ok1,f1)=fseek f0 offset FSeekSet;
	}

copy_to_offset current_offset offset i0 o0
	| offset>=current_offset
		= (offset,i1,o1);
	{}{
		(i1,o1)=copy_bytes (offset-current_offset) i0 o0;
	}
		
copy_bytes n_bytes i0 o0
	| size bytes==n_bytes
		= (i1,fwrites bytes o0);
	{}{
		(bytes,i1)=freads i0 n_bytes;
	}

replace_long offset v i0 o0
	| ok
		= (offset+4,i1,Fwritei v o0);
	{}{
		(ok,_,i1)=freadi i0;
	}

copy_and_fix_data_relocations 0 data_addr offset i0 o0
	= (offset,i0,o0);
copy_and_fix_data_relocations n data_addr offset i0 o0
	| ok1 && size bytes==6
		= copy_and_fix_data_relocations (n-1) data_addr (offset+10) i2 o1;
	{}{
		o1=fwrites bytes (Fwritei new_relocation_offset o0);
		new_relocation_offset=relocation_offset-data_addr;
		(bytes,i2)=freads i1 6;
		(ok1,relocation_offset,i1)=Freadi i0;
	}

(BYTE) string i :== toInt (string.[i]);

(IWORD) string i = (string BYTE (i+1)<<8) bitor (string BYTE i);

(ILONG) string i
	= (string BYTE (i+3)<<24) bitor (string BYTE (i+2)<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE i);

copy_and_fix_symbols 0 data_addr offset0 i0 o0
	= (offset0,i0,o0);
copy_and_fix_symbols n data_addr offset0 i0 o0
	| size bytes<>18
		= abort "copy_and_fix_symbols: read error\n";
	| section_n<>2
		= copy_and_fix_symbols (n-1-n_aux) data_addr offset1 i2 o2;
		{
			(offset1,i2,o2)=copy_aux n_aux (offset0+18) i1 o1;
			o1=fwrites bytes o0;
		}
		= copy_and_fix_symbols (n-1-n_aux) data_addr offset1 i2 o4;
		{
			(offset1,i2,o4)=copy_aux n_aux (offset0+18) i1 o3;
			o3=fwrites (bytes % (12,17)) o2;
			o2=Fwritei (value-data_addr) o1;
			o1=fwrites (bytes % (0,7)) o0;
			value=bytes ILONG 8;
		}
	{
		(bytes,i1)=freads i0 18;
		n_aux=bytes BYTE 17;
		section_n=bytes IWORD 12;
	}

copy_aux 0 offset i0 o0
	= (offset,i0,o0);
copy_aux n offset i0 o0
	| size bytes==aux_size
		= (offset+aux_size,i1,o1);
	{}{
		o1=fwrites bytes o0;
		(bytes,i1)=freads i0 aux_size;
		aux_size=n*18;
	}

copy_rest_of_file i0 o0
	| size bytes<16384
		= (i1,fwrites bytes o0);
		= copy_rest_of_file i1 (fwrites bytes o0);
	{}{
		(bytes,i1)=freads i0 16384;
	}

//input_file_name:=="_startup1.o";
//output_file_name:=="_startup1.obj";

Start w0
	# command_line=getCommandLine;
	| size command_line<>3
		= abort "input file name and output file name expected";
	#
	input_file_name = command_line.[1];
	output_file_name = command_line.[2];
	files0=w0;
	(open_ok1,f0,files1)=fopen input_file_name FReadData files0;
	(symbol_table_offset,f1)=read_little_endian_word_at 0x8 f0;
	(n_symbols,f2)=read_little_endian_word_at 0xc f1;
	(data_addr,f3)=read_little_endian_word_at 0x44 f2;
	(data_addr_,f4)=read_little_endian_word_at 0x48 f3;
	(data_relocation_table_offset,f5)=read_little_endian_word_at 0x54 f4;
	(n_relocations,f6)=read_little_endian_word_at 0x5c f5;
	(seek_ok,i0) = fseek f6 0 FSeekSet;
	(open_ok2,o0,files2)=fopen output_file_name FWriteData files1;
	(new_offset0,i1,o1)=copy_to_offset 0 0x44 i0 o0;
	(new_offset1,i2,o2)=replace_long new_offset0 0 i1 o1;
	(new_offset2,i3,o3)=replace_long new_offset1 0 i2 o2;		
	(new_offset4,i5,o5) = f;
	with {
		f | n_relocations==0
			= (new_offset2,i3,o3);
			= copy_and_fix_data_relocations n_relocations data_addr new_offset3 i4 o4;
			{
				(new_offset3,i4,o4)=copy_to_offset new_offset2 data_relocation_table_offset i3 o3;
			}
	}
	(new_offset5,i6,o6)=copy_to_offset new_offset4 symbol_table_offset i5 o5;
	(new_offset6,i7,o7)=copy_and_fix_symbols n_symbols data_addr new_offset5 i6 o6;
	(i8,o8)=copy_rest_of_file i7 o7;
	(close_ok1,files4)=fclose o8 files2;
	| open_ok1 && data_addr==data_addr_ && seek_ok && open_ok2 && close_ok1
		= (symbol_table_offset,n_symbols,data_addr,data_relocation_table_offset,n_relocations,files4);
//		# (stdout,files) = stdio files4;
//		= stdout <<< symbol_table_offset <<< ' ' <<< n_symbols <<< ' ' <<< data_addr <<< ' ' <<< data_relocation_table_offset <<< ' ' <<< n_relocations;
