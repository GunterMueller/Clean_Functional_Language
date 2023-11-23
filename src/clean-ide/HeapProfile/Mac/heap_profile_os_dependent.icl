implementation module heap_profile_os_dependent;

import StdEnv;

::	Header = {
		heap_begin		:: !Int,
		heap_end		:: !Int,
		heap2_begin		:: !Int,
		heap2_end		:: !Int,
		text_begin		:: !Int,	// for PowerPC
		data_begin		:: !Int,
		small_integers	:: !Int,
		characters		:: !Int,
		text_addresses	:: !{#Int}	// for 68k
	};

from files import GetFInfo,NewToolbox,:: Toolbox;

PCorMac pc mac :== mac;
	
FileExists	:: !String -> Bool;
FileExists name = result==0;
{
	(result,_,_)	= GetFInfo name NewToolbox;
}

/* for PowerPC */

	IF_BIG_ENDIAN big little :== big;

	:: Text :== {#Char};

	read_application_name :: !*File -> (!{#Char},!*File);
	read_application_name file = freads file 32;

	read_text_addresses :: !*File -> (!{#Int},!*File);
	read_text_addresses file = ({},file);

	read_application :: !{#Char} !{#Char} Header !Files -> (!Bool,!{#Char},!Text,Header,!Files);
	read_application file_name application_file_name header files
		# application_file_name=replace_file_name_in_path file_name application_file_name;
		# (ok,file,files) = fopen application_file_name FReadData files;
		| not ok
			= abort ("cannot open application file: "+++toString application_file_name);
		# (ok,xcoff_magic,file) = freadi file;
//		| not ok || (xcoff_magic>>16)<>0x01DF
		| not ok || xcoff_magic<>0x4A6F7921
			= abort "not an application file";
//		# (ok1,file) = fseek file 0x94 FSeekSet;
		# (ok1,file) = fseek file 0x54 FSeekSet;
		  (ok2,data_section_size,file) = freadi file;
		  (ok3,data_section_offset,file) = freadi file;
		| not ok1 || not ok2 || not ok3
			= abort "error reading application file";
		# (ok,file) = fseek file data_section_offset FSeekSet;
		  (data,file) = freads file data_section_size;
		| not ok || size data<>data_section_size
			= abort "error reading application file";
//		# (ok1,file) = fseek file 0x6C FSeekSet;
		# (ok1,file) = fseek file 0x38 FSeekSet;
		  (ok2,text_section_size,file) = freadi file;
		  (ok3,text_section_offset,file) = freadi file;
		| not ok1 || not ok2 || not ok3
			= abort "error reading application file";
		# (ok,file) = fseek file text_section_offset FSeekSet;
		  (text,file) = freads file text_section_size;
		| not ok || size text<>text_section_size
			= abort "error reading application file";
		# (ok,files) =fclose file files;
		| not ok
			= abort "error closing application file";
		= (True,data,text,header,files);

	PageNumberOffsetFromEndInFileName:==1;

	get_text_resource_n address header text :== in_text_section address header.text_begin (size text);
	
	in_text_section :: !Int !Int !Int -> Int;
	in_text_section address text_begin size_text
		| address>=text_begin && address<text_begin+size_text
			= 0;
			= -1;

	long_in_text_resource _ /*text_resource_n*/ a header text
		:== text LONG (a-header.text_begin);

	relocate_descriptor descriptor header :== descriptor+header.data_begin;

	is_closure descriptor :== (descriptor bitand 2)==0;

	non_relocated_descriptor_to_data_offset descriptor _/*header*/ _/*data*/ :== descriptor-2;

	relocated_descriptor_to_data_offset descriptor header _ /*data*/ :== descriptor-2-header.data_begin;

	address_to_data_offset a data_begin _ /*data*/ :== a-data_begin;

	non_record_arity :: !Int -> Int;
	non_record_arity arity=arity;
	
	constructor_name data_begin data_offset arity data text :== constructor_name_ data_offset arity data text;

	constructor_name_ :: !Int !Int !{#Char} {#Char} -> (!{#Char},!{#Char});
	constructor_name_ data_offset arity data text
		# descriptor_max_arity_offset = data_offset + (data WORD (data_offset+2));
		#! string_offset = descriptor_max_arity_offset+12;
		# module_name_offset = data LONG (descriptor_max_arity_offset + 8);
/*
		# descriptor_offset=data_offset-(data WORD (data_offset+2));
		  descriptor_arity=data WORD (descriptor_offset-2);
		  string_offset=descriptor_offset+4+(descriptor_arity<<3);
		  module_name_offset = data LONG (descriptor_offset-12);
*/
		  string_length=data LONG string_offset;		  
		  module_name_length = data LONG module_name_offset;		  
		= (data % (string_offset+4,string_offset+3+string_length),data % (module_name_offset+4,module_name_offset+3+module_name_length));

	closure_text_offset descriptor _ /*text_resource_n*/ header
		:== descriptor-header.text_begin-4;

	get_closure_arity text_offset _ /*text_resource_n*/ text
		:== text LONG text_offset;

	is_selector arity :== arity<0 && arity>=(-4);

	get_closure_name :: !Int .a .b .c !{#Char} !{#Char} -> .(!{#Char},!{#Char});
	get_closure_name text_offset arity text_resource_n header text data
		# descriptor_toc_offset = text WORD (text_offset - 2);
		| descriptor_toc_offset bitand 3<>0
			= abort "get_closure_name";
		# descriptor_offset = data LONG (descriptor_toc_offset-0x8000);

		# descriptor_max_arity_offset = descriptor_offset + (data WORD (descriptor_offset+2));
		#! string_offset = descriptor_max_arity_offset+12;
		# module_name_offset = data LONG (descriptor_max_arity_offset + 8);

/*
		  descriptor_arity=data WORD (descriptor_offset-2);
		  string_offset=descriptor_offset+4+(descriptor_arity<<3);
		  module_name_offset = data LONG (descriptor_offset-12);
*/
		  string_length=(data LONG string_offset);
		  module_name_length = data LONG module_name_offset;
		= (data % (string_offset+4,string_offset+3+string_length),data % (module_name_offset+4,module_name_offset+3+module_name_length));

	record_name :: .a !Int !{#Char} .b -> .(!{#Char},!{#Char});
	record_name header data_offset data text
		# string_offset=data LONG (data_offset-4);
		  string_length=(data LONG string_offset);
		  module_name_offset = data LONG (data_offset-8);
		  module_name_length = data LONG module_name_offset;
		= (data % (string_offset+4,string_offset+3+string_length),data % (module_name_offset+4,module_name_offset+3+module_name_length));

	record_type data_offset data text
		# type_string_offset=data_offset+4;
		  end_type_string_offset=find_zero_char type_string_offset data;
		= data % (type_string_offset,dec end_type_string_offset);

				  			  
// end for PowerPC 
/* */

// for 68k
/*
	IF_BIG_ENDIAN big little :== big;

	:: Text :== {!{#Char}};

	read_application_name file = freads file 32;

	read_text_addresses file
		# (text_address_list,file) = read_text_address_list file;
										with {
											read_text_address_list file
												# (ok,text_address,file) = freadi file;
												| not ok
													= abort "error reading text addresses";
												| text_address==0
													= ([],file);
													# (text_addresses,file) = read_text_address_list file;
													= ([text_address:text_addresses],file);
										}
		= ({ i \\ i<-text_address_list},file);

	read_application :: {#Char} {#Char} Header Files -> (!{#Char},!Text,Header,!Files);
	read_application file_name application_file_name header files
		# application_file_name=replace_file_name_in_path file_name application_file_name;
		# (ref_num,t)=HOpenResFile 0 0 application_file_name 3 0;
		| ref_num==(-1)
			= abort "cannot open application file";
		# (code_resource_list,t)=load_code_resources 0 t;
		# (res_error,_)=ResError (CloseResFile ref_num t);
		| res_error<>0
			= abort "error closing application file";
			# code_resources = createArray (length code_resource_list) "";
			  code_resources = fill_array 0 code_resource_list code_resources;
			  		with {
			  			fill_array i [] code_resources = code_resources;
		  				fill_array i [e:l] code_resources = fill_array (inc i) l {code_resources & [i]=e};
		  			}
			  last_code_resource_n = dec (size code_resources);
			  last_code_resource = code_resources.[last_code_resource_n];
			  data_section_size = ((toInt last_code_resource.[0xfc]-0x18)<<16)
		  						 + (toInt last_code_resource.[0xfd]<<8)
		  						 + toInt last_code_resource.[0xfe];
			  data = last_code_resource % (0x101,0x100+data_section_size);
			= (True,data,code_resources,header,files);

	PageNumberOffsetFromEndInFileName:==1;

	load_code_resources n t
		# (h,t)=Get1Resource "CODE" n t;
		| h==0
			= ([],t);
			# (s,t)=GetHandleSize h t;
			  (code_resource,t)=handle_to_string h s t;
			  (code_resources,t)=load_code_resources (inc n) t;
			= ([code_resource:code_resources],t);
 
	handle_to_string :: !Handle !Int !Toolbox -> (!{#Char},!Toolbox);
	handle_to_string handle size t0
		=	(string,t1);
		{
			t1=copy_handle_data_to_string string handle size t0;
			string = createArray size ' ';
		}

	get_text_resource_n address header text :== find_text_resource_n address header.text_addresses text;

	find_text_resource_n address text_addresses text
		= find_text_resource_n 0;
		{
			find_text_resource_n resource_n
				| resource_n>=size text_addresses
					= -1;
				# text_address=text_addresses.[resource_n];
				| address>=text_address && address<text_address+size text.[resource_n]
					= resource_n;
					= find_text_resource_n (inc resource_n);
		}

	long_in_text_resource text_resource_n a header text
		:== text.[text_resource_n] LONG (a-header.text_addresses.[text_resource_n]);

	relocate_descriptor descriptor header :== descriptor;

	is_closure descriptor :== descriptor>=0;

	non_relocated_descriptor_to_data_offset descriptor _/*header*/ data :== size data+descriptor;

	relocated_descriptor_to_data_offset descriptor header data :== size data+descriptor;

	address_to_data_offset a data_begin data :== a-(data_begin-size data);

	non_record_arity arity = arity>>2;

	constructor_name data_begin data_offset arity data text :==	constructor_name_ data_begin data_offset arity data text;
	
	constructor_name_ data_offset arity data text
		# descriptor_offset=data_offset-(arity<<2);
		  string_jump_table_offset=data WORD (descriptor_offset-2);
		= string_from_jump_table_offset string_jump_table_offset text;

	string_from_jump_table_offset string_jump_table_offset text
		# string_offset=(text.[0] WORD (string_jump_table_offset-18))+6;
	  	  string_resource_n=text.[0] WORD (string_jump_table_offset-14);
		  string_length=text.[string_resource_n] LONG (string_offset+4);
		= text.[string_resource_n] % (string_offset+8,string_offset+7+string_length);

	closure_text_offset descriptor text_resource_n header
		:== descriptor-header.text_addresses.[text_resource_n]-2;

	get_closure_arity text_offset text_resource_n text 
		:==text.[text_resource_n] WORD text_offset;
	
	is_selector arity :== arity>=65532;

	(SWORD) string i 
		| w<32768
			= w;
			= w-65536;
		{}{
			w = (string BYTE i<<8) bitor (string BYTE (i+1));
		 }

	get_closure_name text_offset arity text_resource_n header text
		# text_resource=text.[text_resource_n];
		  encoded_string_size=text_resource LONG (text_offset-4);
		  string_size=(encoded_string_size>>2) bitand 63;
		| encoded_string_size==(string_size<<2) bitor (string_size<<10) bitor (string_size<<18) bitor (string_size<<26) bitor 0x00010203
			# string_offset=text_offset-4-((string_size+3) bitand (-4));
			= text_resource % (string_offset,string_offset+string_size-1);
		# encoded_string_size2=text_resource LONG (text_offset-14);
		  string_size2=(encoded_string_size2>>2) bitand 63;
		| (string_size bitand 0xffff)==0 && encoded_string_size2==(string_size2<<2) bitor (string_size2<<10) bitor (string_size2<<18) bitor (string_size2<<26) bitor 0x00010203
			# string_offset=text_offset-14-((string_size2+3) bitand (-4));
			= text_resource % (string_offset,string_offset+string_size2-1);
		# next_text_offset=text_offset+2+text_resource SWORD (text_offset+4);
		| text_resource WORD (text_offset+2)==0x4efa && text_resource WORD next_text_offset==arity
			= get_closure_name2 next_text_offset arity text_resource_n header text;
		# a5_offset=text_resource SWORD (text_offset+4);
		  text0=text.[0];
		  next_resource_offset=(text0 WORD (a5_offset-18))+2;
		  next_resource_n=text0 WORD (a5_offset-14);
		| text_resource WORD (text_offset+2)==0x4eed && a5_offset>=16
			&& text0 WORD (a5_offset-16)==0x3f3c && text0 WORD (a5_offset-12)==0xa9f0
			&& text.[next_resource_n] WORD next_resource_offset==arity
			= get_closure_name2 next_resource_offset arity next_resource_n header text;
			= "Function"+++toString (arity);

	get_closure_name2 text_offset arity text_resource_n header text
		# text_resource=text.[text_resource_n];
		  encoded_string_size=text_resource LONG (text_offset-4);
		  string_size=(encoded_string_size>>2) bitand 63;
		| encoded_string_size==(string_size<<2) bitor (string_size<<10) bitor (string_size<<18) bitor (string_size<<26) bitor 0x00010203
			# string_offset=text_offset-4-((string_size+3) bitand (-4));
			= text_resource % (string_offset,string_offset+string_size-1);
		# encoded_string_size2=text_resource LONG (text_offset-14);
		  string_size2=(encoded_string_size2>>2) bitand 63;
		| (string_size bitand 0xffff)==0 && encoded_string_size2==(string_size2<<2) bitor (string_size2<<10) bitor (string_size2<<18) bitor (string_size2<<26) bitor 0x00010203
			# string_offset=text_offset-14-((string_size2+3) bitand (-4));
			= text_resource % (string_offset,string_offset+string_size2-1);
			= "Function"+++toString (arity);

	record_name header data_offset data text
		# string_jump_table_offset=data WORD (data_offset-2);
		= string_from_jump_table_offset string_jump_table_offset text;

	record_type data_offset data text
		# type_string_offset=data_offset+4;
		  end_type_string_offset=find_zero_char type_string_offset data;
		= data % (type_string_offset,dec end_type_string_offset);

	::	Toolbox:==Int;
	::	Handle:==Int;

	// in resources.icl
	HOpenResFile :: !Int !Int !{#Char} !Int !Toolbox -> (!Int,!Toolbox);
	HOpenResFile vRefNum dirID fileName permission t
	= code (vRefNum=R2W,dirID=L,fileName=S,permission=D1,t=U)(refNum=W,t2=Z){
		instruction 0x1F01			|	move.b	d1,-(sp)
		instruction 0xA81A
	}

	CloseResFile :: !Int !Toolbox -> Toolbox;
	CloseResFile refNum t = code (refNum=W,t=U)(t2=Z){
		instruction	0xA99A
	}

	ResError :: !Toolbox -> (!Int,!Toolbox);
	ResError t = code (t=R2U)(res_error=W,t2=Z){
		instruction 0xA9AF
	}

	Get1Resource :: !{#Char} !Int !Toolbox -> (!Handle,!Toolbox);
	Get1Resource theType index t = code (theType=R4A0,index=D1,t=u)(handle=L,t2=Z){
		instruction 0x2F28 0x0008	|	move.l	8(a0),-(sp)
		instruction 0x3F01			|	move.w	d1,-(sp)
		instruction	0xA81F
	}

	// in memory.icl
	GetHandleSize :: !Handle !Toolbox -> (!Int,!Toolbox);
	GetHandleSize handle t = code (handle=D1,t=U)(result_code=D1,z=Z){
		instruction 0x2041	||	move.l	d1,a0
		instruction 0xA025
		instruction 0x2200	||	move.l	d0,d1	
	}

	copy_handle_data_to_string :: !{#Char} !Handle !Int !Toolbox -> Toolbox;
	copy_handle_data_to_string string handle size t0 = code (string=A0,handle=D2,size=D1,t0=U)(t1=Z){
		instruction	0x2248		||	move.l	a0,a1
		instruction	0x2042		||	move.l	d2,a0
		instruction	0x5089		||	addq.l	#8,a1
		instruction	0x2050		||	move.l	(a0),a0
		instruction	0x2001		||	move.l	d1,d0
		instruction 0xA22E		|| BlockMoveData
	}	
*/
// end for 68k

(BYTE) string i :== toInt (string.[i]);

(WORD) string i :== IF_BIG_ENDIAN
						((string BYTE i<<8) bitor (string BYTE (i+1)))
						((string BYTE i) bitor (string BYTE (i+1) << 8));

(LONG) :: !{#Char} !Int -> Int;
(LONG) string i	= IF_BIG_ENDIAN
					((string BYTE i<<24) bitor (string BYTE (i+1)<<16) bitor (string BYTE (i+2)<<8) bitor (string BYTE (i+3)))
					(((string BYTE i) bitor (string BYTE (i+1) << 8) bitor (string BYTE (i+2) << 16) bitor (string BYTE (i+3) << 24)));

find_zero_char i s
	| s.[i]=='\0'
		= i;
		= find_zero_char (inc i) s;

replace_file_name_in_path path file_name
	= remove_file_name_from_path (size path-1)+++file_name;
{
	remove_file_name_from_path i
		| i<0
			= path;
		| path.[i]==':'
			= path % (0,i);
			= remove_file_name_from_path (i-1);
}
