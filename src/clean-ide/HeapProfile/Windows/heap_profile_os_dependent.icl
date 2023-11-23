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

import code from "file_exists.";

PCorMac pc mac :== pc;
	
FileExists :: !String -> Bool;
FileExists _ = 
	code {
		ccall FileExists "S-I"
	};

/*
	Assumptions:	
	1.	The image base is always used to load the image (offset 28 in Optional 
		Header) which is true beginning from version 4.0 of Windows.
	2.	Exactly one text and data section exists which is true for all Clean
		programs produced by the Clean linker.
	3.	Dynamically linked programs are (yet) unsupported.
*/

IF_BIG_ENDIAN big little :== little;

:: Text :== {#Char};

read_application_name :: !*File -> (!{#Char},!*File);
read_application_name file
	# (ok,length, file) = freadi file;
	| ok
		= freads file length;
		= ("",file);

read_text_addresses :: !*File -> (!{#Int},!*File);
read_text_addresses file = ({},file);

read_application :: !{#Char} !{#Char} Header !Files -> (!Bool,!{#Char},!Text,Header,!Files);
read_application file_name application_file_name header files
	#! (ok,app_file,files) = fopen application_file_name FReadData files;
	| not ok
		= (False,"","",header,files); //abort ("cannot open application file: "+++ toString application_file_name);
	#! (ok,app_file) = ReadPESignature app_file;
	| not ok
		= abort "invalid application file";
	#! (n_sections, optional_header_size, app_file) = ReadCOFFHeader app_file;
	#! (code_size,data_size,base_of_code,image_base,section_alignment,file_alignment,app_file) = ReadOptionalHeader app_file optional_header_size;
	#! ((rva_raw_text,text),(rva_raw_data,data),rva_bss,app_file) = ReadSections 0 n_sections (0,"") (0,"") 0 app_file;
	#! (ok,files)  = fclose app_file files;
	| not ok
		= abort ("cannot close application file: "+++ toString application_file_name);
	# header = ({ Header | header & text_begin = image_base+rva_raw_text,data_begin = image_base+rva_raw_data});
	= (True,data,text,header,files);
{}{
	ReadPESignature app_file 
		# (ok, app_file) = fseek app_file 0x3c FSeekSet;
		| not ok
			= (False,app_file);
		#! (_, signature_offset, app_file) = freadi app_file;
		# (ok, app_file) = fseek app_file signature_offset FSeekSet;
		| not ok
			= (False,app_file);
		#! (pe_signature, app_file) = freads app_file 4;
		= (pe_signature == "PE\0\0", app_file);

	ReadCOFFHeader app_file
		#! (coff_header, app_file) = freads app_file 20
		#! machine = coff_header WORD 0;
		| machine <> IF_INT_64_OR_32 0x8664 0x14c
			= abort ("invalid application file for i386: "+++toString machine);
		#! n_sections = coff_header WORD 2;
		#! optional_header_size = coff_header WORD 16;
		#! characteristics = coff_header WORD 18;
		| (characteristics bitand 3) <> 3
			= abort ("not an exectuable image or relocations not stripped");	
		= (n_sections, optional_header_size, app_file);

	ReadOptionalHeader app_file optional_header_size
		#! (optional_header, app_file) = freads app_file optional_header_size;
		#! magic  = optional_header WORD 0;
		| magic <> IF_INT_64_OR_32 0x20b 0x10b
			= abort ("incorrect magic number");
		#! code_size = optional_header LONG 4;
		#! data_size = optional_header LONG 8;
		#! base_of_code = optional_header LONG 20;
		#! image_base = IF_INT_64_OR_32
							(((optional_header LONG 24) bitand 0xffffffff) + (optional_header LONG 28<<32))
							(optional_header LONG 28);
		#! section_alignment = optional_header LONG 32;
		#! file_alignment = optional_header LONG 36;
		= (code_size,data_size,base_of_code,image_base,section_alignment,file_alignment,app_file);

	ReadSections section_n n_sections text=:(rva_raw_text,raw_text) data=:(rva_raw_data,raw_data) rva_bss app_file
		| (section_n == n_sections)
			| size raw_text == 0 || size raw_data == 0
				= abort "ReadSections: executable does not contain a .text or .data section";
				= (text,data,rva_bss,app_file);
			#! (section_header,app_file) = freads app_file 40;					
			| section_header % (0,5) == ".text\0"
				#! (raw_text,app_file) = read_raw_data raw_text section_header app_file;
				#! rva_raw_text = section_header LONG 12;
				= ReadSections (inc section_n) n_sections (rva_raw_text,raw_text) data  rva_bss app_file;
				
			| section_header % (0,5) == ".data\0"
				#! (raw_data,app_file) = read_raw_data raw_data section_header app_file;
				#! rva_raw_data = section_header LONG 12;
				= ReadSections (inc section_n) n_sections text (rva_raw_data,raw_data) rva_bss app_file;	
				= ReadSections (inc section_n) n_sections text data rva_bss app_file;
	{}{
		read_raw_data raw_data section_header app_file
			| size raw_data == 0
				#! (next_section_header_offset,app_file) = fposition app_file;
				#! raw_data_offset = section_header LONG 20;
				#! size_of_raw_data = section_header LONG 16;
				#! (ok,app_file) = fseek app_file raw_data_offset FSeekSet;
				| not ok
					= abort "read_raw_data: could not seek";
				#! (raw_data,app_file) = freads app_file size_of_raw_data;
				#! (ok,app_file) = fseek app_file next_section_header_offset FSeekSet
				| not ok
					= abort "read_raw_data: could not seek";
				= (raw_data,app_file);
				= abort "read_raw_data: more than one .text or .data section";
	}
}

PageNumberOffsetFromEndInFileName:==5;

get_text_resource_n address header text :== in_text_section address header.text_begin (size text);
	
in_text_section :: !Int !Int !Int -> Int;
in_text_section address text_begin size_text
	| address >= text_begin && address < text_begin + size_text
		= 0;
		= -1;

long_in_text_resource _ /* text_resource_n */ a header text
	:== text LONG (a - header.text_begin);

relocate_descriptor descriptor header :== descriptor + header.data_begin;

is_closure descriptor :== (descriptor bitand 2) == 0;

non_relocated_descriptor_to_data_offset descriptor header _/*data*/ :== descriptor - 2 - header.data_begin;

relocated_descriptor_to_data_offset descriptor header _/*data*/ :== descriptor - 2 - header.data_begin;

address_to_data_offset a data_begin _ /*data*/ :== a - data_begin;

non_record_arity arity :== arity;
	
get_string_from_pointer name_pointer data_begin data
	:== get_string_from_offset (address_to_data_offset name_pointer data_begin data) data;

get_string_from_offset name_offset data
	:== data % (name_offset + 4,name_offset + 3 + name_length);	
{
	name_length = data LONG name_offset;
}

constructor_name :: !Int !Int !Int !{#Char} {#Char} -> (!{#Char},!{#Char});
constructor_name data_begin data_offset arity data text
	# descriptor_max_arity_offset = data_offset + (data WORD (data_offset+2));
	#! string_offset = descriptor_max_arity_offset+12;
	# module_name_pointer = data LONG (descriptor_max_arity_offset + 8);
/*
	# nameP = data_offset - (data WORD (data_offset+2));
	# total_descriptor_arity = data WORD (nameP - 2);
	#! string_offset = nameP+4 + (total_descriptor_arity << 3);
	# module_name_pointer = data LONG (nameP - 12);
*/
	= (get_string_from_offset string_offset data, get_string_from_pointer module_name_pointer data_begin data);

closure_text_offset descriptor _ /*text_resource_n*/ header
	:== descriptor - header.text_begin - 4;

get_closure_arity text_offset _ /*text_resource_n*/ text
	:== text LONG text_offset;

is_selector arity :== arity < 0 && arity >= (-4);

get_closure_name :: !Int .a .b !Header !{#Char} !{#Char} -> .(!{#Char},!{#Char});
get_closure_name text_offset arity text_resource_n header text data
	# descriptor_pointer = text LONG (text_offset - 4);
	# descriptor_offset = address_to_data_offset descriptor_pointer header.data_begin data;

	# descriptor_max_arity_offset = descriptor_offset + (data WORD (descriptor_offset+2));
	#! function_name_offset = descriptor_max_arity_offset+12;
	# module_name_pointer = data LONG (descriptor_max_arity_offset + 8);
/*
	# descriptor_arity=data WORD (descriptor_offset-2);
	#! function_name_offset = descriptor_offset+4+(descriptor_arity<<3);
	#! module_name_pointer = data LONG (descriptor_offset - 12);
*/
	= (get_string_from_offset function_name_offset data,get_string_from_pointer module_name_pointer header.data_begin data);

record_name :: !Header !Int !{#Char} .b -> .(!{#Char},!{#Char});
record_name header data_offset data text
	#! function_name_pointer = data LONG (data_offset-4);
	#! function_name = get_string_from_pointer function_name_pointer header.data_begin data;
	#! module_name_pointer = data LONG (data_offset-8);
	= (function_name,get_string_from_pointer module_name_pointer header.data_begin data);

(BYTE) string i :== toInt (string.[i]);

(WORD) string i :== IF_BIG_ENDIAN
						((string BYTE i<<8) bitor (string BYTE (i+1)))
						((string BYTE i) bitor (string BYTE (i+1) << 8));

(LONG) :: !{#Char} !Int -> Int;
(LONG) string i
	# r = IF_BIG_ENDIAN
			((string BYTE i<<24) bitor (string BYTE (i+1)<<16) bitor (string BYTE (i+2)<<8) bitor (string BYTE (i+3)))
			(((string BYTE i) bitor (string BYTE (i+1) << 8) bitor (string BYTE (i+2) << 16) bitor (string BYTE (i+3) << 24)));
	= IF_INT_64_OR_32 ((r<<32)>>32) r;
