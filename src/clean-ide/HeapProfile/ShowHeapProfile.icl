implementation module ShowHeapProfile

import StdInt,StdBool,StdReal,StdClass,StdArray,StdString,StdChar,StdFile,StdList,StdMisc,StdEnum,StdOrdList,StdFunc;

import heap_profile_os_dependent

import StdPrint;

import Help;

ApplicationName :==  "ShowHeapProfile";
HelpFileName :== ApplicationName +++ "Help";

::	Descriptors = {
		int_descriptor		:: !Int,
		char_descriptor		:: !Int,
		real_descriptor		:: !Int,
		bool_descriptor		:: !Int,
		string_descriptor	:: !Int, 
		array_descriptor	:: !Int
	};

empty_descriptors :: Descriptors; 
empty_descriptors = {
	Descriptors |
	int_descriptor = 0,
	char_descriptor = 0,
	real_descriptor = 0,
	bool_descriptor = 0,
	string_descriptor = 0,
	array_descriptor = 0
	};
	
	
empty_header :: Header;
empty_header  = {
	heap_begin = 0,
	heap_end = 0,
	heap2_begin = 0,
	heap2_end = 0,
	text_begin = 0,	// for PowerPC
	data_begin = 0,
	small_integers = 0,
	characters = 0,
	text_addresses= {}	// for 68k
	};

/* PC
	import expand_8_3_names_in_path,ArgEnv;//,handler;

	/*
	system_dependent_initial_IO
		=[open_heap_file_from_command_line];
	where {
		openDDE fileName s io
			# (s,io) = file_close_function s io;
			# expanded_file_name = expand_8_3_names_in_path fileName;
			= open_file_function expanded_file_name {s & application_name = expanded_file_name} io;
	}	
		
	open_heap_file_from_command_line s io
		| size commandline == 1
			= (s,io);
			# expanded_file_name = expand_8_3_names_in_path commandline.[1];
			= open_file_function expanded_file_name /*{s & application_name = expanded_file_name}*/ io;
	where {
		commandline = getCommandLine;
	}
	*/
*/

/* Mac */
/*
	system_dependent_initial_IO=[];
	
	apple_event_open_function file_name s=:{node_size_sum} io
		| node_size_sum<0
			= open_file_function file_name s io;
			# (_, s,io) = OpenNotice (Notice ["A file is already open"] (NoticeButton 0 "OK") []) s io;
			= (s,io);
*/
// end for Mac

remove_null_chars_from_string s
	= remove_null_chars_from_string 0;
where
	remove_null_chars_from_string n
		| n>=size s
			= s;
		| s.[n]=='\0'
			= s % (0,n-1);
			= remove_null_chars_from_string (n+1);

freadi8 :: !*File -> (!Bool,!Int,!*File);
freadi8 file
	# (r1,i1,file) = freadi file;
	# (r2,i2,file) = freadi file;
	= (r1 && r2,(i1 bitand 0xffffffff) + (i2<<32),file);

read_heap_file file_name files
	# (ok,file,files) = fopen file_name FReadData files;
	| not ok
		# (_,files) = fclose file files;
		= (False,empty_header,empty_descriptors,{},{},{},{},files)
	#!(application_name,file) = read_application_name file;
	  (_,heap_begin,file) = IF_INT_64_OR_32 (freadi8 file) (freadi file);
	  (_,heap_end,file) = IF_INT_64_OR_32 (freadi8 file) (freadi file);
	  (_,heap2_begin,file) = IF_INT_64_OR_32 (freadi8 file) (freadi file);
	  (_,heap2_end,file) = IF_INT_64_OR_32 (freadi8 file) (freadi file);
	  (_,stack_begin,file) = IF_INT_64_OR_32 (freadi8 file) (freadi file);
	  (_,stack_end,file) = IF_INT_64_OR_32 (freadi8 file) (freadi file);
	  (_,text_begin,file) = IF_INT_64_OR_32 (freadi8 file) (freadi file);
	  (_,data_begin,file) = IF_INT_64_OR_32 (freadi8 file) (freadi file);
	  (_,small_integers,file) = IF_INT_64_OR_32 (freadi8 file) (freadi file);
	  (_,characters,file) = IF_INT_64_OR_32 (freadi8 file) (freadi file);
	  (_,int_descriptor,file) = IF_INT_64_OR_32 (freadi8 file) (freadi file);
	  (_,char_descriptor,file) = IF_INT_64_OR_32 (freadi8 file) (freadi file);
	  (_,real_descriptor,file) = IF_INT_64_OR_32 (freadi8 file) (freadi file);
	  (_,bool_descriptor,file) = IF_INT_64_OR_32 (freadi8 file) (freadi file);
	  (_,string_descriptor,file) = IF_INT_64_OR_32 (freadi8 file) (freadi file);
	  (_,array_descriptor,file) = IF_INT_64_OR_32 (freadi8 file) (freadi file);
	# (error,file) = ferror file;
	| error
		= abort "error reading heap file";
	# (text_addresses,file)=read_text_addresses file;
	# (stack,file) = freads file (stack_end-stack_begin);
	| size stack<>stack_end-stack_begin
		= abort "error reading stack from heap file";

	# (heap,file) = freads file (heap_end-heap_begin);
	| size heap<>heap_end-heap_begin
		= abort ("error reading heap from heap file" +++ (toString heap_begin) +++ " - " +++ (toString heap_end) +++ " - " +++ (toString (size heap)));
	# (heap2,file) = freads file (heap2_end-heap2_begin);
	| size heap2<>heap2_end-heap2_begin
		= abort "error reading heap2 from heap file";
	# (ok,files) =fclose file files;
	| not ok
		= abort "error closing heap file";
	= ( True,
		{heap_begin=heap_begin,heap_end=heap_end,heap2_begin=heap2_begin,heap2_end=heap2_end,
		 text_begin=text_begin,data_begin=data_begin,
		 small_integers=small_integers,characters=characters,text_addresses=text_addresses},
		{int_descriptor=int_descriptor,char_descriptor=char_descriptor,real_descriptor=real_descriptor,
		 bool_descriptor=bool_descriptor,string_descriptor=string_descriptor,array_descriptor=array_descriptor},
		stack,heap,heap2,remove_null_chars_from_string application_name,files
	  );

(BYTE) string i :== toInt (string.[i]);

(WORD) string i :== IF_BIG_ENDIAN
						((string BYTE i<<8) bitor (string BYTE (i+1)))
						((string BYTE i) bitor (string BYTE (i+1) << 8));

update_long :: *{#Char} Int Int -> .{#Char};
update_long string i v = IF_BIG_ENDIAN
					{string & [i]=toChar (v>>24),[i+1]=toChar (v>>16),[i+2]=toChar (v>>8),[i+3]=toChar v}
					{string & [i]=toChar v, [i+1]=toChar (v>>8), [i+2]=toChar (v>>16), [i+3]=toChar(v>>24)};	

heap_address e header bits1 bits2
	# heap_offset = e - header.heap_begin;
	| e>=header.heap_begin && e<header.heap_end && get_two_bits bits1 heap_offset==2
		= (True,toString (heap_offset>>2)+++": ");
	# heap_offset = e - header.heap2_begin;
	| e>=header.heap2_begin && e<header.heap2_end && get_two_bits bits2 heap_offset==2
		= (True,toString ((heap_offset+(header.heap_end-header.heap_begin))>>2)+++": ");
		= (False,"");

find_zero_char i s
	| s.[i]=='\0'
		= i;
		= find_zero_char (inc i) s;

WORD_SIZE_IN_BYTES:==IF_INT_64_OR_32 8 4;
WORD_SIZE_IN_BYTES_M1:==IF_INT_64_OR_32 7 3;
WORD_SIZE_IN_BITS_M1:==IF_INT_64_OR_32 63 31;
TWO_WORDS_SIZE_IN_BYTES:==IF_INT_64_OR_32 16 8;
THREE_WORDS_SIZE_IN_BYTES:==IF_INT_64_OR_32 24 12;
LOG_WORD_SIZE_IN_BYTES:==IF_INT_64_OR_32 3 2;
LOG_WORD_SIZE_IN_BITS:==IF_INT_64_OR_32 6 5;

MAX_STATIC_INT_OFFSET:==IF_INT_64_OR_32 512 256;
MAX_STATIC_CHAR_OFFSET:==IF_INT_64_OR_32 4096 2048;
LOG_WORD_SIZE_IN_BITS_P1:==IF_INT_64_OR_32 7 6;
LOG_WORD_SIZE_IN_BYTES_M1:==IF_INT_64_OR_32 2 1;

allocate_bit_array :: !Int -> .{#Int};
allocate_bit_array size_heap
	= createArray ((size_heap+((1<<LOG_WORD_SIZE_IN_BITS_P1)-1))>>LOG_WORD_SIZE_IN_BITS_P1) 0;

u_get_two_bits :: !*{#Int} !Int -> (!Int,!*{#Int});
u_get_two_bits bits i
	| i bitand WORD_SIZE_IN_BYTES_M1==0
		# (v,bits)=bits![i>>LOG_WORD_SIZE_IN_BITS_P1];
		= ((v >> ((i>>LOG_WORD_SIZE_IN_BYTES_M1) bitand WORD_SIZE_IN_BITS_M1)) bitand 3,bits);

get_two_bits bits i
	# v=bits.[i>>LOG_WORD_SIZE_IN_BITS_P1];
	= (v >> ((i>>LOG_WORD_SIZE_IN_BYTES_M1) bitand WORD_SIZE_IN_BITS_M1)) bitand 3;

set_two_bits bits i v
	# index=i>>LOG_WORD_SIZE_IN_BITS_P1;
	  shift=(i>>LOG_WORD_SIZE_IN_BYTES_M1) bitand WORD_SIZE_IN_BITS_M1;
	  (bi,bits)=bits![index];
	= {bits & [index]= (bi bitand (bitnot (3<<shift))) bitor (v << shift)};

:: Name :== (!String,!String);

(===) infix  4	:: !(!{#Char},!{#Char})	!(!{#Char},!{#Char})	->	Bool;
(===) (f1,m1) (f2,m2)
	= f1 == f2;

instance < (!{#Char},!{#Char}) //Name
where
	(<) (f1,m1) (f2,m2)
		= f1 < f2

get_function_name name :== function_name;
where
	(function_name,_) = name;


get_module_name name :== module_name;
where
	(_,module_name) = name;


replace_function_name new_function_name name :== (new_function_name,get_module_name name);


Array_name :== ("Array","_system");
ArrayString_name :== ("ArrayString","_system");
ArrayInt_name :== ("ArrayInt","_system");
ArrayBool_name :== ("ArrayBool","_system");
ArrayChar_name :== ("ArrayChar","_system");
ArrayReal_name :== ("ArrayReal","_system");
ArrayArray_name :== ("ArrayArray","_system");
Int_name :== ("Int","_system");
Char_name :== ("Char","_system");
Bool_name :== ("Bool","_system");
Real_name :== ("Real","_system");
String_name :== ("String","_system");
StringLarge_name :== ("String(large)","_system");
//Record_name r_size :== ("Record"+++toString r_size, "unknown module");
Total_name :== ("Total","");

// Module, 2nd string is module name
:: SizeByNodeKind = NilSizeByNodeKind | SizeByNodeKind !Name !Int !SizeByNodeKind !SizeByNodeKind;

add_size_of_node_kind string n NilSizeByNodeKind
	= SizeByNodeKind string n NilSizeByNodeKind NilSizeByNodeKind;
add_size_of_node_kind string n (SizeByNodeKind ns nn left right)
	| string<ns
		= SizeByNodeKind ns nn (add_size_of_node_kind string n left) right;
	| string===ns
		= SizeByNodeKind ns (nn+n) left right;
//	| string<ns
		= SizeByNodeKind ns nn left (add_size_of_node_kind string n right);

BEGIN_NORMAL_NODE:==1;
BEGIN_ARGUMENT_NODE:==2;
BEGIN_ARRAY_NODE:==3;

compute_sizes_by_node_kind :: !.Header .Descriptors !*{#Char} !{#Char} {#Char} {#Char} !{#Char} -> (!SizeByNodeKind,!.{#Int},!.{#Int});
compute_sizes_by_node_kind header descriptors heap heap2 data text stack
	#! size_heap=size heap;
	   bits1=allocate_bit_array size_heap;
	#! size_heap2=size heap2;
	   bits2=allocate_bit_array size_heap2;
	=  size_stack descriptors 0 NilSizeByNodeKind bits1 bits2 heap;
	where
		stack_size=size stack;
		
		size_stack :: .Descriptors !Int SizeByNodeKind *{#Int} *{#Int} *{#Char} -> (!SizeByNodeKind,!.{#Int},!.{#Int});
		size_stack descriptors i s bits1 bits2 heap
			| i>=stack_size
				= (s,bits1,bits2);
				# (s,bits1,bits2,heap)=compute_size_graph_by_node_kind descriptors header heap2 data text (stack LONG i) s bits1 bits2 heap (-1);
				= size_stack descriptors (i+WORD_SIZE_IN_BYTES) s bits1 bits2 heap;

	compute_size_next_graph_by_node_kind :: .Descriptors !Header {#Char} {#Char} {#Char} !Int !SizeByNodeKind !*{#Int} !*{#Int} !*{#Char} !Int -> (!SizeByNodeKind,!*{#Int},!*{#Int},!*{#Char});
	compute_size_next_graph_by_node_kind descriptors header heap2 data text a s bits1 bits2 heap next
		| next==(-1)
			= (s,bits1,bits2,heap);
			#! next_offset=next-header.heap_begin;
			#! bits=get_two_bits bits1 next_offset;
			| bits==0
				#! parent=heap LONG next_offset;
				#! next_argument=heap LONG (next_offset-WORD_SIZE_IN_BYTES);
				# heap=update_long heap (next_offset-WORD_SIZE_IN_BYTES) parent;
				# heap=update_long heap next_offset a;
				= compute_size_graph_by_node_kind descriptors header heap2 data text next_argument s bits1 bits2 heap (next-WORD_SIZE_IN_BYTES);
			| bits==BEGIN_NORMAL_NODE
				#! parent_argument_address=heap LONG next_offset;
				# heap=update_long heap next_offset a;
				= compute_size_next_graph_by_node_kind descriptors header heap2 data text (next-WORD_SIZE_IN_BYTES) s bits1 bits2 heap parent_argument_address;
			| bits==BEGIN_ARGUMENT_NODE
				#! parent_argument_address=heap LONG next_offset;
				# heap=update_long heap next_offset a;
				= compute_size_next_graph_by_node_kind descriptors header heap2 data text next s bits1 bits2 heap parent_argument_address;
			| bits==BEGIN_ARRAY_NODE
				#! parent_argument_address=heap LONG next_offset;						
				# heap=update_long heap next_offset a;
				= compute_size_next_graph_by_node_kind descriptors header heap2 data text (next-THREE_WORDS_SIZE_IN_BYTES) s bits1 bits2 heap parent_argument_address;

		add_size_of_node_kind_and_compute_size_next_graph_by_node_kind :: .Descriptors !Header {#Char} {#Char} {#Char} !Name !Int !SizeByNodeKind !Int !*{#Int} !*{#Int} !*{#Char} !Int -> (!SizeByNodeKind,!*{#Int},!*{#Int},!*{#Char});
		add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text string n s a bits1 bits2 heap next
			# s=add_size_of_node_kind string n s;
			= compute_size_next_graph_by_node_kind descriptors header heap2 data text a s bits1 bits2 heap next;

		/* Main */
		compute_size_graph_by_node_kind :: .Descriptors !Header {#Char} {#Char} !{#Char} !Int SizeByNodeKind !*{#Int} !*{#Int} !*{#Char} !Int -> (!SizeByNodeKind,!*{#Int},!*{#Int},!*{#Char});
		compute_size_graph_by_node_kind descriptors header heap2 data text a s bits1 bits2 heap next
			# heap_offset=a-header.heap_begin; // address_to_data_offset a header.data_begin data;
			| heap_offset<0 || a>=header.heap_end
				/*  node outside heap1 */				
				# heap_offset=a-header.heap2_begin;
				| heap_offset<0 || a>=header.heap2_end
					/* node outside heap2 and heap1 */
					| a>=header.small_integers && a<=header.small_integers+MAX_STATIC_INT_OFFSET
						// node is small integer, because the node is a small integer, it is skipped because it doesn't count.
						= compute_size_next_graph_by_node_kind descriptors header heap2 data text a s bits1 bits2 heap next;
					| a>=header.characters && a<(header.characters+MAX_STATIC_CHAR_OFFSET)
						// node is a character
						= compute_size_next_graph_by_node_kind descriptors header heap2 data text a s bits1 bits2 heap next;
					# data_offset=address_to_data_offset a header.data_begin data;
					| (data_offset<0 || data_offset>=size data)
						// node outside .data (e.g. in .text)
						# text_resource_n=get_text_resource_n a header text;
						| text_resource_n<0					
							// not in .text
							= abort ("compute_size_graph_by_node_kind: string constant" +++ toString a);
							// in .text, should be a string
						# descriptor=long_in_text_resource text_resource_n a header text;
						| descriptor==descriptors.string_descriptor
							// .text, string found
							= compute_size_next_graph_by_node_kind descriptors header heap2 data text a s bits1 bits2 heap next;									
							= abort "compute_size_graph_by_node_kind: string constant";
					# descriptor=data LONG data_offset;
					| relocate_descriptor descriptor header==descriptors.string_descriptor
						// in .data, string
						= compute_size_next_graph_by_node_kind descriptors header heap2 data text a s bits1 bits2 heap next;	
					# data_offset=non_relocated_descriptor_to_data_offset descriptor header data;
					  arity=data WORD data_offset;
					| arity==0
						= compute_size_next_graph_by_node_kind descriptors header heap2 data text a s bits1 bits2 heap next;
						= abort "compute_size_graph_by_node_kind: size 0 descriptor or shared int,char or string";									
				/* node inside heap2 */	
				# (two_bits,bits2)=u_get_two_bits bits2 heap_offset;
				| two_bits<>0
					// two_bits <> 0
					| two_bits==2
						= compute_size_next_graph_by_node_kind descriptors header heap2 data text a s bits1 bits2 heap next;
						// two_bits <> 0 and two_bits <> 2
						= compute_size_next_graph_by_node_kind descriptors header heap2 data text a s bits1 (set_two_bits bits2 heap_offset 2) heap next; // BEGIN_ARGUMENT_NODE								
				// two_bits == 0
				# bits2=set_two_bits bits2 heap_offset 1;
				  descriptor=heap2 LONG heap_offset;
				| is_closure descriptor
					// a closure found
					# text_resource_n=get_text_resource_n descriptor header text
					| text_resource_n<0
						// not in .text
						= abort "compute_size_graph_by_node_kind: closure";							
					// in .text
					# text_offset=closure_text_offset descriptor text_resource_n header;
					  arity=get_closure_arity text_offset text_resource_n text;
					| arity==0
						# s=add_size_of_node_kind (get_closure_name text_offset arity text_resource_n header text data) 3 s;
						= compute_size_next_graph_by_node_kind descriptors header heap2 data text a s bits1 bits2 heap next;																				
						// ? arity <> 0
						= abort "compute_size_graph_by_node_kind: closure";
				// not a closure			
				# data_offset=relocated_descriptor_to_data_offset descriptor header data;
				| data_offset<0 || data_offset + 1>size data
					= abort "compute_size_graph_by_node_kind";
				# arity=data WORD data_offset
				| arity==0
					// arity==0
					| descriptor==descriptors.int_descriptor
						= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text Int_name 2 s a bits1 bits2 heap next;
					| descriptor==descriptors.char_descriptor
						= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text Char_name 2 s a bits1 bits2 heap next;
					| descriptor== descriptors.bool_descriptor
						= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text Bool_name 2 s a bits1 bits2 heap next;
					| descriptor== descriptors.real_descriptor
						= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text Real_name 3 s a bits1 bits2 heap next;
					| descriptor==descriptors.string_descriptor
						# string_length=heap2 LONG (heap_offset+WORD_SIZE_IN_BYTES);
						| string_length<=256
							= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text String_name (2+((string_length+WORD_SIZE_IN_BYTES_M1)>>LOG_WORD_SIZE_IN_BYTES)) s a bits1 bits2 heap next;
							= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text StringLarge_name (2+((string_length+WORD_SIZE_IN_BYTES_M1)>>LOG_WORD_SIZE_IN_BYTES)) s a bits1 bits2 heap next;
					| descriptor==descriptors.array_descriptor
						# element_descriptor =heap2 LONG (heap_offset+TWO_WORDS_SIZE_IN_BYTES);
						  array_size=heap2 LONG (heap_offset+WORD_SIZE_IN_BYTES);
						| element_descriptor==descriptors.int_descriptor
							= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text ArrayInt_name (3+array_size) s a bits1 bits2 heap next;
						| element_descriptor==descriptors.char_descriptor
							= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text ArrayChar_name (3+((array_size+WORD_SIZE_IN_BYTES_M1)>>LOG_WORD_SIZE_IN_BYTES)) s a bits1 bits2 heap next;
						| element_descriptor==descriptors.bool_descriptor
							= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text ArrayBool_name (3+((array_size+WORD_SIZE_IN_BYTES_M1)>>LOG_WORD_SIZE_IN_BYTES)) s a bits1 bits2 heap next;
						| element_descriptor==descriptors.real_descriptor
							= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text ArrayReal_name (3+(array_size+array_size)) s a bits1 bits2 heap next;
							// dus arrays met bijv. record als elementen worden niet ondersteund?
							= abort "compute_size_graph_by_node_kind: array";											    
						// waarom kom ik hier?
						= abort "compute_size_graph_by_node_kind: arity 0";
				// arity <> 0
				# a_size=data WORD (data_offset+2);
				| arity>=256 && a_size==0
					# r_size=arity-256;
//					  name=Record_name r_size
					  name=record_name header data_offset data text;
					| r_size<=2
						= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text name (1+r_size) s a bits1 bits2 heap next;
						= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text name (2+r_size) s a bits1 bits2 heap next;
					= abort "compute_size_graph_by_node_kind";
			# (two_bits,bits1)=u_get_two_bits bits1 heap_offset;
			| two_bits<>0
				| two_bits==2 // BEGIN_ARGUMENT_NODE
					= compute_size_next_graph_by_node_kind descriptors header heap2 data text a s bits1 bits2 heap next;
					= compute_size_next_graph_by_node_kind descriptors header heap2 data text a s (set_two_bits bits1 heap_offset 2) bits2 heap next;
			# bits1=set_two_bits bits1 heap_offset 1; // BEGIN_NORMAL_NODE
			#! descriptor=heap LONG heap_offset;
			| is_closure descriptor
				# text_resource_n=get_text_resource_n descriptor header text
				| text_resource_n<0
					= abort "size_closure : closure";
				# text_offset=closure_text_offset descriptor text_resource_n header;
				  arity	= get_closure_arity text_offset text_resource_n text;
				| is_selector arity
					# name=get_closure_name text_offset arity text_resource_n header text data;
					= compute_size_arguments_by_node_kind descriptors header heap2 data text 1 a (add_size_of_node_kind (replace_function_name "Selector" name) 3 s) bits1 bits2 heap next;
					// not a selector
					# name=get_closure_name text_offset arity text_resource_n header text data;
					| arity <= 2
						=compute_size_arguments_by_node_kind descriptors header heap2 data text arity a (add_size_of_node_kind name 3 s) bits1 bits2 heap next;
				    | arity<=255
					   =compute_size_arguments_by_node_kind descriptors header heap2 data text arity a (add_size_of_node_kind name (1+arity) s) bits1 bits2 heap next;
						# a_plus_b_size =arity bitand 255;
						# b_size =arity>>8;
						# a_size =a_plus_b_size-b_size;
						| a_plus_b_size<=2
							= compute_size_arguments_by_node_kind descriptors header heap2 data text a_size a (add_size_of_node_kind name 3 s) bits1 bits2 heap next;
							= compute_size_arguments_by_node_kind descriptors header heap2 data text a_size a (add_size_of_node_kind name (1+a_plus_b_size) s) bits1 bits2 heap next;			
			# data_offset=relocated_descriptor_to_data_offset descriptor header data;
			| data_offset<0 || data_offset+1>size data
				= abort ("compute_size_graph_by_node_kind");
			# arity=data WORD data_offset
			| arity==0
				| descriptor==descriptors.int_descriptor
					= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text Int_name 2 s a bits1 bits2 heap next;
				| descriptor==descriptors.char_descriptor
					= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text Char_name 2 s a bits1 bits2 heap next;
				| descriptor==descriptors.bool_descriptor
					= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text Bool_name 2 s a bits1 bits2 heap next;
				| descriptor==descriptors.real_descriptor
					= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text Real_name 3 s a bits1 bits2 heap next;
				| descriptor==descriptors.string_descriptor
					#! string_length=heap LONG (heap_offset+WORD_SIZE_IN_BYTES);
					| string_length<=256
						= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text String_name (2+((string_length+WORD_SIZE_IN_BYTES_M1)>>LOG_WORD_SIZE_IN_BYTES)) s a bits1 bits2 heap next;
						= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text StringLarge_name (2+((string_length+WORD_SIZE_IN_BYTES_M1)>>LOG_WORD_SIZE_IN_BYTES)) s a bits1 bits2 heap next;
				| descriptor==descriptors.array_descriptor
					#! element_descriptor=heap LONG (heap_offset+TWO_WORDS_SIZE_IN_BYTES);
					#! array_size=heap LONG (heap_offset+WORD_SIZE_IN_BYTES);
					| element_descriptor==0
						= compute_size_array_elements_by_node_kind descriptors header heap2 data text array_size a (add_size_of_node_kind Array_name (3+array_size) s) bits1 bits2 heap next;	
					| element_descriptor==descriptors.string_descriptor
						= compute_size_array_elements_by_node_kind descriptors header heap2 data text array_size a (add_size_of_node_kind ArrayString_name (3+array_size) s) bits1 bits2 heap next;
					| element_descriptor==descriptors.int_descriptor
						= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text ArrayInt_name (3+array_size) s a bits1 bits2 heap next;
					| element_descriptor==descriptors.bool_descriptor
						= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text ArrayBool_name (3+((array_size+WORD_SIZE_IN_BYTES_M1)>>LOG_WORD_SIZE_IN_BYTES)) s a bits1 bits2 heap next;
					| element_descriptor==descriptors.char_descriptor
						= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text ArrayChar_name (3+((array_size+WORD_SIZE_IN_BYTES_M1)>>LOG_WORD_SIZE_IN_BYTES)) s a bits1 bits2 heap next;
					| element_descriptor==descriptors.real_descriptor
						= add_size_of_node_kind_and_compute_size_next_graph_by_node_kind descriptors header heap2 data text ArrayReal_name (3+(array_size+array_size)) s a bits1 bits2 heap next;
					| element_descriptor==descriptors.array_descriptor
						= compute_size_array_elements_by_node_kind descriptors header heap2 data text array_size a (add_size_of_node_kind ArrayArray_name (3+array_size) s) bits1 bits2 heap next;
					# data_offset=relocated_descriptor_to_data_offset element_descriptor header data;
					  arity=data WORD data_offset						
					| data_offset>=0 && data_offset+1<=size data && arity>=256
						# a_size=data WORD (data_offset+2);
						  r_size=arity-256;
						  name=record_name header data_offset data text;
						  s=add_size_of_node_kind /*(("Array"+++toString name),module_name)*/ (replace_function_name ("Array" +++ (get_function_name name)) name) (3+r_size*array_size) s;	
						| a_size==0
							= compute_size_next_graph_by_node_kind descriptors header heap2 data text a s bits1 bits2 heap next;
							= compute_size_array_arguments_by_node_kind descriptors header heap2 data text 0 0 (array_size*r_size) a_size (r_size-a_size) a s bits1 bits2 heap next;
						= abort "compute_size_graph_by_node_kind: array";
					= abort "compute_size_graph_by_node_kind: arity 0";
			| arity>=256
				# a_size=data WORD (data_offset+2);
				  r_size=arity-256;
//				  name="Record"+++toString r_size;
				  name=record_name header data_offset data text;
				| r_size<=2
					= compute_size_arguments_by_node_kind descriptors header heap2 data text a_size a (add_size_of_node_kind name (1+r_size) s) bits1 bits2 heap next;
					= compute_size_arguments_by_node_kind_of_split_node descriptors header heap2 data text a_size a (add_size_of_node_kind name (2+r_size) s) bits1 bits2 heap next;	
				# arity=non_record_arity arity;
				  name=constructor_name header.data_begin data_offset arity data text;
				# function_name=get_function_name name;
				  name=if (function_name=="_Tuple") (replace_function_name (function_name +++ toString arity) name) name;
				| arity<=2
					= compute_size_arguments_by_node_kind descriptors header heap2 data text arity a (add_size_of_node_kind name (1+arity) s) bits1 bits2 heap next;
					= compute_size_arguments_by_node_kind_of_split_node descriptors header heap2 data text arity a (add_size_of_node_kind name (2+arity) s) bits1 bits2 heap next;
		
		compute_size_arguments_by_node_kind :: .Descriptors !Header {#Char} {#Char} {#Char} !Int !Int !SizeByNodeKind !*{#Int} !*{#Int} !*{#Char} !Int -> (!SizeByNodeKind,!*{#Int},!*{#Int},!*{#Char});
		compute_size_arguments_by_node_kind descriptors header heap2 data text a_size e s bits1 bits2 heap next
			| a_size==0
				= compute_size_next_graph_by_node_kind descriptors header heap2 data text e s bits1 bits2 heap next;
				# heap_offset=e-header.heap_begin;
				# last_argument_offset=heap_offset+(a_size<<LOG_WORD_SIZE_IN_BYTES);
				# bits1=set_two_bits bits1 (heap_offset+WORD_SIZE_IN_BYTES) BEGIN_NORMAL_NODE;
				//  a=pointer to node (node to be counted), next=address van a in its parent
				#! a=heap LONG last_argument_offset;
				# heap = update_long heap last_argument_offset next;
				= compute_size_graph_by_node_kind descriptors header heap2 data text a s bits1 bits2 heap (e+(a_size<<LOG_WORD_SIZE_IN_BYTES));

		compute_size_arguments_by_node_kind_of_split_node :: .Descriptors !Header {#Char} {#Char} {#Char} !Int !Int !SizeByNodeKind !*{#Int} !*{#Int} !*{#Char} !Int -> (!SizeByNodeKind,!*{#Int},!*{#Int},!*{#Char});
		compute_size_arguments_by_node_kind_of_split_node descriptors header heap2 data text a_size e s bits1 bits2 heap next
			| a_size<2
				= compute_size_arguments_by_node_kind descriptors header heap2 data text a_size e s bits1 bits2 heap next;			
				# heap_offset=e-header.heap_begin;
				# argument2_offset=heap_offset+TWO_WORDS_SIZE_IN_BYTES;
				#! argument_part=heap LONG argument2_offset;
				# argument_part_offset=argument_part-header.heap_begin;
				# last_argument_offset=argument_part_offset+((a_size-2)<<LOG_WORD_SIZE_IN_BYTES);
				#! a=heap LONG last_argument_offset;
				# bits1=set_two_bits bits1 (heap_offset+WORD_SIZE_IN_BYTES) BEGIN_NORMAL_NODE;
				# bits1=set_two_bits bits1 argument_part_offset BEGIN_ARGUMENT_NODE;
				# heap=update_long heap argument2_offset next;
				# heap= update_long heap last_argument_offset (e+TWO_WORDS_SIZE_IN_BYTES);
				= compute_size_graph_by_node_kind descriptors header heap2 data text a s bits1 bits2 heap (argument_part+((a_size-2)<<LOG_WORD_SIZE_IN_BYTES));

		compute_size_array_elements_by_node_kind :: .Descriptors !Header {#Char} {#Char} {#Char} !Int !Int !SizeByNodeKind !*{#Int} !*{#Int} !*{#Char} !Int -> (!SizeByNodeKind,!*{#Int},!*{#Int},!*{#Char});
		compute_size_array_elements_by_node_kind descriptors header heap2 data text a_size e s bits1 bits2 heap next
			| a_size==0
				= compute_size_next_graph_by_node_kind descriptors header heap2 data text e s bits1 bits2 heap next;
				# heap_offset=e-header.heap_begin;
				# last_element_offset=heap_offset+TWO_WORDS_SIZE_IN_BYTES+(a_size<<LOG_WORD_SIZE_IN_BYTES);
				# bits1=set_two_bits bits1 (heap_offset+THREE_WORDS_SIZE_IN_BYTES) BEGIN_ARRAY_NODE;
				#! a=heap LONG last_element_offset; //get ptr to last unboxed array element
				# heap=update_long heap last_element_offset next;
				#! (s,bits1,bits2,heap)=compute_size_graph_by_node_kind descriptors header heap2 data text a s bits1 bits2 heap (e+TWO_WORDS_SIZE_IN_BYTES+(a_size<<LOG_WORD_SIZE_IN_BYTES));
				= (s,bits1,bits2,heap);

		compute_size_array_arguments_by_node_kind :: .Descriptors !Header {#Char} {#Char} {#Char} !Int Int !Int Int Int !Int SizeByNodeKind !*{#Int} !*{#Int} !*{#Char} !Int -> (!SizeByNodeKind,!*{#Int},!*{#Int},!*{#Char});
		compute_size_array_arguments_by_node_kind descriptors header heap2 data text i element_i array_size a_size b_size a s bits1 bits2 heap next
			| i>=array_size
				= compute_size_next_graph_by_node_kind descriptors header heap2 data text a s bits1 bits2 heap next;
			| element_i==a_size
				= compute_size_array_arguments_by_node_kind descriptors header heap2 data text (i+b_size) 0 array_size a_size b_size a s bits1 bits2 heap next;				
				#! e=heap LONG (a-header.heap_begin+((i+WORD_SIZE_IN_BYTES_M1)<<LOG_WORD_SIZE_IN_BYTES));
				# (s,bits1,bits2,heap)=compute_size_graph_by_node_kind descriptors header heap2 data text e s bits1 bits2 heap (-1);
				= compute_size_array_arguments_by_node_kind descriptors header heap2 data text (inc i) (inc element_i) array_size a_size b_size a s bits1 bits2 heap next;
	
show_array_bits :: !{#Int} -> [[Int]];
show_array_bits a
	= [bits a.[i] \\ i<-[0..size a-1]];
where
		bits v = [(v>>(i+i)) bitand 3 \\ i<-[0..15] | (v>>(i+i)) bitand 3>0];
	

tree_to_list :: !SizeByNodeKind -> [SizeByNodeKindElem];
tree_to_list NilSizeByNodeKind
	= [];
tree_to_list (SizeByNodeKind s i NilSizeByNodeKind right)
	=  [SizeByNodeKindElem s i : tree_to_list right];	
tree_to_list (SizeByNodeKind s i (SizeByNodeKind s0 i0 left0 right0) right)
	= tree_to_list (SizeByNodeKind s0 i0 left0 (SizeByNodeKind s i right0 right));

:: SizeByNodeKindElem = SizeByNodeKindElem !Name !Int;

compare_function_name :: !.SizeByNodeKindElem !.SizeByNodeKindElem -> Bool;
compare_function_name (SizeByNodeKindElem name1 _) (SizeByNodeKindElem name2 _)
	= (get_function_name name1) <= (get_function_name name2);

compare_module_name :: !.SizeByNodeKindElem !.SizeByNodeKindElem -> Bool;
compare_module_name (SizeByNodeKindElem name1 _) (SizeByNodeKindElem name2 _)
	= (get_module_name name1) <= (get_module_name name2);
	
compare_heap_use :: !.SizeByNodeKindElem !.SizeByNodeKindElem -> Bool;
compare_heap_use(SizeByNodeKindElem _ heap_use1) (SizeByNodeKindElem _ heap_use2)
	= heap_use1>=heap_use2;
	
sum_node_sizes l = sum_node_sizes l 0;
where
	sum_node_sizes [] s = s;
	sum_node_sizes [SizeByNodeKindElem _ m:l] s = sum_node_sizes l (s+m);

/*
import deltaEventIO,deltaPicture;
from deltaSystem import MaxFixedWindowSize;
from deltaWindow import DrawInActiveWindowFrame;
from deltaFileSelect import SelectInputFile;
from deltaMenu import EnableMenus,DisableMenus,EnableMenuItems,DisableMenuItems;
from deltaWindow import OpenWindows,CloseWindows;
from deltaDialog import OpenNotice,OpenDialog,CloseDialog;
from deltaIOState import SetGlobalCursor,ResetCursor;
*/
import StdIO,StdPicture, StdFileSelect, StdWindow;

Pos0:==4;
Pos1:==280;
Pos2:==385;
Pos3:==475;
WindowWidth:==548;
/*
monaco_font
	# (ok,font)=SelectFont "Monaco" [] 9;
	| ok
		= font;
*/
(>:) infixl;
(>:) f g:== g f;

format_string_r length string
	# string_size=size string;
	| string_size >= length
		= string;
		= (createArray (length-string_size) ' ')+++string;

format_real n_spaces n d m r
	# s=toString (toInt (m*r));
	  l=size s;
	| l<=d
		= (createArray n_spaces ' ')			+++	(createArray n '0')+++"."+++(createArray (d-l) '0')+++s;
	| l<=n+d
		= (createArray n_spaces ' ')			+++	(createArray (n+d-l) '0')+++s % (0,l-1-d) +++"."+++ s % (l-d,l-1);
	| l<=n_spaces+n+d
		= (createArray (n_spaces+n+d-l) ' ')	+++	s % (0,l-1-d) +++"."+++ s % (l-d,l-1);
		=											s % (0,l-1-d) +++"."+++ s % (l-d,l-1);

draw_string_at (x,y) s picture = drawAt {x=x,y=y} s picture; //>: MovePenTo position >: DrawString s;
draw_string_left (x,y) s picture
	# (w,picture) = getPenFontStringWidth s picture;
	= drawAt {x=x-w,y=y} s picture;

draw_table_header positions y line_y picture
	= picture
		>: draw_string_at (positions!!0+5,y) "Function"
		>: draw_string_at (positions!!1+5,y) "Module"
		>: draw_string_left (positions!!3-5,y) "Heap Use(bytes)"
		>: draw_string_left (positions!!4-5,y) "Heap Use(%)"
		>: DrawLine ((positions!!0,line_y),(positions!!4,line_y));

DrawLine ((x1,y1),(x2,y2)) picture = drawLine {x=x1,y=y1} {x=x2,y=y2} picture;
FillRectangle ((x1,y1),(x2,y2)) picture = fill {corner1={x=x1,y=y1},corner2={x=x2,y=y2}} picture;
MyGrey = RGB {r = 225, g = 225, b = 225};

draw_heap_profile_lines :: [.Int] .Bool [.SizeByNodeKindElem] .Int .Int .Int .Int *Picture -> *Picture;
draw_heap_profile_lines positions also_draw_total node_size_list y_pos line_height delta_text node_size_sum picture
	= draw_heap_profile_lines True node_size_list y_pos picture;
where
//	(pfm,picture`) = getPenFontMetrics picture;
	
	draw_heap_profile_lines background_box [] y_pos picture
		| also_draw_total
			= draw_profile_line background_box Total_name node_size_sum y_pos picture;
		= picture;
	draw_heap_profile_lines background_box [SizeByNodeKindElem name heap_size:size_by_node_kind_list] y_pos picture
		# picture = draw_profile_line background_box name heap_size y_pos picture;
		= draw_heap_profile_lines (not background_box) size_by_node_kind_list (y_pos+line_height) picture;
		
	r1 = toRegion {corner1 = {x=positions!!2+5,y=0},corner2={x=positions!!3-5,y=y_pos + (line_height * (1 + length node_size_list))}};
	r2 = toRegion {corner1 = {x=positions!!3+5,y=0},corner2={x=positions!!4-5,y=y_pos + (line_height * (1 + length node_size_list))}};

	draw_profile_line background_box name heap_size y_pos picture
//*
		# picture = case background_box of
						True
							-> picture	>: setPenColour MyGrey
										>: FillRectangle ((positions!!0,y_pos-line_height + delta_text),(positions!!5,y_pos + delta_text))
										>: DrawLine ((0,y_pos + delta_text), (positions!!4, y_pos + delta_text))
										>: setPenColour Black;
						False
							-> unfill {corner1={x=positions!!0,y=y_pos-line_height + delta_text},corner2={x=positions!!5,y=y_pos + delta_text}} picture;
//*/
		= picture	>: draw_clipped_string_at (positions!!0+5,y_pos) function_name (positions!!1 - positions!!0-10)
					>: draw_clipped_string_at (positions!!1+5,y_pos) module_name (positions!!2 - positions!!1-10)
					>: draw_string_at_left (positions!!3-5,y_pos) r1 (toString (heap_size<<LOG_WORD_SIZE_IN_BYTES))
					>: draw_string_at_left (positions!!4-5,y_pos) r2 (format_real 2 2 3 1000.0 (percentage heap_size node_size_sum));
		where
			percentage i1 i2 = if (i2==0) 0.0 ((toReal (i1*100))/(toReal i2));
			
			function_name = get_function_name name;
			module_name = get_module_name name;
			
//			clipped_function_name = if (size function_name<=50) function_name (function_name%(0,47)+++"...");
//			clipped_module_name = if (size module_name<=50) module_name (module_name % (0,47)+++"...");
			
//			delta_text = 2;

			draw_clipped_string_at (x,y) s m picture
				# l = size s
				# ss = [s:[s%(0,x)+++"..." \\ x <- [l,dec l..0]]]
				# (s,picture) = findfirstfit ss m picture;
				= picture >: drawAt {x=x,y=y} s;
			
			findfirstfit [] _ picture = ("",picture);
			findfirstfit [s:ss] m picture
				# (w,picture) = getPenFontStringWidth s picture;
				| w <= m = (s,picture)
				= findfirstfit ss m picture;
				
			draw_string_at_left (x,y) r s picture
				# (string_width_in_pixels,picture) = getPenFontStringWidth s picture;
				= appClipPicture r (drawAt {x=x-string_width_in_pixels,y=y} s) picture;
		


:: ProgState a = { node_size_list::a, node_size_sum::Int, printingSetup :: MaybePrintSetup, application_name :: String};

empty_progstate :: MaybePrintSetup -> *ProgState [.a];
empty_progstate default_ps
	= { ProgState |
		node_size_list=[],
		node_size_sum= -1,
		printingSetup=default_ps, 
		application_name="ShowHeapProfile"
	};
/*	
Start world
	# (aboutdialog,world)	= accFiles (MakeAboutDialog ApplicationName HelpFileName show_help) world;
	  (defaultPS, world)	= defaultPrintSetup world;
	# (_,world) = let {
		io_system = [DialogSystem [aboutdialog], MenuSystem [file_menu,sort_menu,page_menu] :
						(PCorMac [] [AppleEventSystem {	openHandler = apple_event_open_function,
												quitHandler= \s io -> (s,QuitIO io),
												scriptHandler = \_ s io -> (s, io),
												clipboardChangedHandler = \s io -> (s, io)}]) ];
		file_menu = PullDownMenu 1 "File" Able 
					([  MenuItem 10 "Open..."		   (Key 'O') Able file_open_function,
						MenuItem 11 "Close"			   (Key 'W') Unable file_close_function
					 ] ++
					 (if printSetupTypical
					   [MenuItem 14 "Print Setup"	   NoKey Able doPrintSetupDialog]
					   []) ++
					 [	MenuItem 13 "Print"			   (Key 'P') Unable (printTable monaco_font),
					  	MenuItem 12 "Help"             NoKey Able show_help,
						MenuItem 11 "Quit"             (Key 'Q') Able (\s io -> (s,QuitIO io))
					 ]);
		
		page_menu = PullDownMenu 3 "Page" Unable [
						MenuItem 30 "Next"				(Key 'N') Able show_next_page,
						MenuItem 31 "Previous"			(Key 'B') Able show_prev_page
					 ];
					 
		sort_menu = PullDownMenu 2 "Sort" Unable [
						MenuItem 20 "Sort by Function" (Key 'F') Able sort_by_function_name,
						MenuItem 22 "Sort by Module" (Key 'M') Able sort_by_module_name,
						MenuItem 21 "Sort by Heap Use" (Key 'H') Able sort_by_heap_use
					];
		state={node_size_list=[],node_size_sum= -1,printingSetup=defaultPS, application_name=""};
	  } in
		StartIO io_system state system_dependent_initial_IO world;
	= world;

file_open_function s io
//	# (file_selected,file_name,s,io)=selectInputFile s io;
//	| file_selected
//		# (s,io) = open_file_function file_name s io;
//		= (s,io);
	
		= (s,io);

file_close_function s io = (s,io);
	# io = io	>: DisableMenuItems [/*11,*/13]
				>: DisableMenus [2,3]
				>: CloseWindows [0]
				>: EnableMenuItems [10];
	= ({s & node_size_list=[],node_size_sum= -1},io);
*/	
p_open_file_function :: {#Char} *a -> *(Bool,{#Char},ProgState [SizeByNodeKindElem],*a) | FileEnv a;
p_open_file_function file_name ps
//	# io = SetGlobalCursor BusyCursor io;
//	#! io = openDialog (Dialog 0 "Messages" [DialogSize (MM 200.0) (MM 20.0)] 0
//			[StaticText 0 (XY (MM 30.0) (MM 7.0))
//			("Reading  "+++file_name_from_path file_name)]) io;		
	// Set-up a dummy ProgState which can be discarded in case of errors	
	# defaultPS = NoPrintSetup;
	# discardable_s = empty_progstate defaultPS;		
	# ((ok, discardable_s=:{node_size_list}, application_name), ps)
		= accFiles (open_file file_name discardable_s) ps;
	| ok
		= (ok,application_name, discardable_s, ps);
		= (ok,"",discardable_s,ps);

//open_file_function :: {#Char} *(ProgState [.SizeByNodeKindElem]) *a -> *(*ProgState [SizeByNodeKindElem],*a) | FileEnv a;
open_file_function file_name ps
	# (_,application_name,s,ps) = p_open_file_function file_name ps;
	= p_open_file_function2 application_name file_name s ps;
	
p_open_file_function2 application_name file_name s io
	= (s,io);
/*	# io = EnableMenuItems [30,31] io;
	# first_page =  if (fst (determine_previous_page file_name)) [] [31] /*back */;
	# last_page = if (fst (determine_next_page file_name)) [] [30] /*next */;
	# first_last_pages = (first_page ++ last_page);
	# io = case (length first_last_pages) of {
			2
				-> DisableMenus [3] io;
			_
				-> DisableMenuItems first_last_pages io;
		};	
	#! node_size_list = s.node_size_list;
	  window = let {
				(screen_size_x,screen_size_y)=MaxFixedWindowSize;
				line_height=ascent+descent+1;
				window_height = 6+line_height*(2+length node_size_list);
				(ascent,descent,_,_)=FontMetrics monaco_font;

				window_mouse_function ((x,y),ButtonDown,_) s io
					| y>=0 && y<3+ascent+descent
						| x<Pos1
							= sort_by_function_name s io;
						| x<Pos2
							= sort_by_module_name s io;
							= sort_by_heap_use s io;
				window_mouse_function _ s io
					= (s,io);
			   } in 
				ScrollWindow 0 ((screen_size_x-WindowWidth)>>1,10) (application_name+++" ("+++file_name_from_path file_name+++")")
						(ScrollBar (Thumb 0) (Scroll 4)) (ScrollBar (Thumb 0) (Scroll 4))
						((0,0),(WindowWidth,window_height))
						(100,10) (WindowWidth,if (window_height<=screen_size_y-40) window_height (screen_size_y-40))
						(window_update_function True) [Mouse Able window_mouse_function, GoAway file_close_function];
	  io=io //>: DisableMenuItems [10]
			>: openWindow window
//			>: EnableMenus [2,3]
//			>: EnableMenuItems [11,13]
//			>: CloseDialog 0
//			>: ResetCursor;
	= (s, io);
where {
	fst (x,y) = x;
}
*/
/*
open_file_function file_name s=:{application_name,current_page,file_open} io
	#  io = SetGlobalCursor BusyCursor io;
	#! io = OpenDialog (CommandDialog 0 "Messages" [DialogSize (MM 200.0) (MM 20.0)] 0
			[StaticText 0 (XY (MM 30.0) (MM 7.0))
			("Reading  "+++file_name_from_path file_name)]) io;
	# ((ok,  s=:{node_size_list}, application_name), io) = accFiles (open_file file_name s) io;
	| not ok
		= abort ("open_file_function: error" +++ file_name);
	# s  = { s & application_name = file_name };
	#! node_size_list = s.node_size_list;
	  window = let {
				(screen_size_x,screen_size_y)=MaxFixedWindowSize;
				line_height=ascent+descent+1;
				window_height = 6+line_height*(2+length node_size_list);
				(ascent,descent,_,_)=FontMetrics monaco_font;

				window_mouse_function ((x,y),ButtonDown,_) s io
					| y>=0 && y<3+ascent+descent
						| x<Pos1
							= sort_by_function_name s io;
						| x<Pos2
							= sort_by_module_name s io;
							= sort_by_heap_use s io;					
				window_mouse_function _ s io
					= (s,io);
			   } in 
				ScrollWindow 0 ((screen_size_x-WindowWidth)>>1,10) (application_name+++" ("+++file_name_from_path file_name+++")")
						(ScrollBar (Thumb 0) (Scroll 4)) (ScrollBar (Thumb 0) (Scroll 4))
						((0,0),(WindowWidth,window_height))
						(100,10) (WindowWidth,if (window_height<=screen_size_y-40) window_height (screen_size_y-40))
						(window_update_function True) [Mouse Able window_mouse_function, GoAway file_close_function];
	  io=io >: DisableMenuItems [10]
			>: OpenWindows [window]
			>: EnableMenus [2,3]
			>: EnableMenuItems [11,13]
			>: CloseDialog 0
			>: ResetCursor;
	= (s, io);
*/			

set_page_number :: !String !Int -> String;
set_page_number file_name new_page_number
	= file_name := (size file_name-PageNumberOffsetFromEndInFileName,toChar (new_page_number + toInt '0'));

get_page_number :: !String -> Int;
get_page_number file_name	
	= digitToInt file_name.[size file_name - PageNumberOffsetFromEndInFileName];

open_file file_name s files
	# (ok, header,descriptors,stack,heap,heap2,application_name,files) = read_heap_file file_name files;
	| not ok
		= ((ok,s,""),files);

	# s = {s & application_name = file_name };
	# (ok,data,text,header,files)= read_application file_name application_name header files;
	| not ok
		= ((ok,s,""),files);
	// .text and .data begin are at load-time e.g. an application is unrelocatable.
	# (node_sizes,_,_) /*,bits1,bits2)*/ = compute_sizes_by_node_kind header descriptors heap heap2 data text stack;
	  node_size_list=sortBy compare_heap_use (tree_to_list node_sizes);
	= ((True,{s & node_size_list=node_size_list,node_size_sum=sum_node_sizes node_size_list}, application_name),files);

//window_update_function also_draw_total area s=:{node_size_list,node_size_sum}
//	= (s,redraw_window also_draw_total area node_size_list node_size_sum);

//redraw_window also_draw_total area node_size_list node_size_sum
//	# positions={Pos0,Pos1,Pos2,Pos3,WindowWidth};
//	= redraw_window_with_positions positions also_draw_total area node_size_list node_size_sum;

replace_file_name_in_path path file_name
	= remove_file_name_from_path (size path-1)+++file_name;
where
	remove_file_name_from_path i
		| i<0
			= path;
		| path.[i]==':'
			= path % (0,i);
			= remove_file_name_from_path (i-1);


file_name_from_path path
	= file_name_from_path (size path-1);
where
	file_name_from_path i
		| i<0
			= path;
		| path.[i]==':'
			= path % (i+1,size path-1);
			= file_name_from_path (i-1);


//sort_by_function_name s io = sort_and_redraw_window compare_function_name s io;

//sort_by_heap_use s io = sort_and_redraw_window compare_heap_use s io;

//sort_by_module_name s io = sort_and_redraw_window compare_module_name s io;
/*
sort_and_redraw_window compare_function s=:{node_size_list,node_size_sum} io
	# s={s & node_size_list=sortBy compare_function node_size_list};
	= DrawInActiveWindowFrame redraw_window s io;
{
	redraw_window area s
		# (s,d)=window_update_function True area s;
		= (s,[\picture->foldr EraseRectangle picture area:d]);
}

show_help s io
	= (s, showHelp HelpFileName io);
*/	
determine_previous_page :: !String -> (!Bool,!Int);
determine_previous_page app_name 
	# current_page = get_page_number app_name;
	= determine_previous_page (dec current_page);	
where
	determine_previous_page :: !Int -> (!Bool,!Int);
	determine_previous_page page_number
		| page_number<0
			= (False,0);
		| FileExists (set_page_number app_name page_number)
			= (True,page_number);				
			= determine_previous_page (dec page_number);

determine_next_page :: !String -> (!Bool,!Int);
determine_next_page app_name
	# current_page = get_page_number app_name;
	= determine_next_page (inc current_page);
where
	determine_next_page :: !Int -> (!Bool,!Int);
	determine_next_page page_number
		| page_number>9
			= (False,0);
		| FileExists (set_page_number app_name page_number)
			= (True,page_number);				
			= determine_next_page (inc page_number);


show_next_page :: u:(ProgState [.SizeByNodeKindElem]) *a -> *(v:ProgState [SizeByNodeKindElem],*a) | FileEnv a, [u <= v];
show_next_page s=:{application_name} io
	# (has_next_page,higher_page) = determine_next_page application_name;
	| has_next_page
		# new_application_name = set_page_number application_name higher_page;
		# (ok, application_name, s,io) = p_open_file_function new_application_name /*s*/ io;
		| not ok
			= abort "show_next_page: error";
//		# io  = CloseWindows [0] io;
		# (s,io) = p_open_file_function2 application_name new_application_name s io;
		= ({s & application_name = new_application_name},io);
		= (s,io);

show_prev_page :: u:(ProgState [.SizeByNodeKindElem]) *a -> *(v:ProgState [SizeByNodeKindElem],*a) | FileEnv a, [u <= v];
show_prev_page s=:{application_name} io
	# (has_previous_page,lower_page) = determine_previous_page application_name;
	| has_previous_page
		# new_application_name = set_page_number application_name lower_page;
		# (ok, application_name, s,io) = p_open_file_function new_application_name /*s*/ io;
		| not ok
			= abort "show_next_page: error";
//		# io  = CloseWindows [0] io;
		# (s,io) = p_open_file_function2 application_name new_application_name s io;
		= ({s & application_name = new_application_name},io);
		= (s,io);

/*
open_file_function file_name s io
	# (_,s,io) = p_open_file_function file_name s io;
	= p_open_file_function2 file_name s io;
*/
	
printTable :: Font .(ProgState [SizeByNodeKindElem]) *a -> *(.ProgState [SizeByNodeKindElem],*a) | PrintEnvironments a;
printTable printFont s=:{node_size_list,node_size_sum,printingSetup,application_name} env
	# (PrintSetup printingSetup) = printingSetup; 
	# (usedPrintSetup,env) = print True True generate_pages printingSetup env;
	= ({s & printingSetup=PrintSetup usedPrintSetup},env);
where
	generate_pages { printSetup, jobInfo={range=(first,last), copies }} picture
		# {page=page=:{w=maxX,h=maxY},resolution=(horizontal_dpi,_)}
													= getPageDimensions printSetup True;
		# ((lineHeight,fontAscent,fontDescent),picture)			= formatInfo printFont picture;
		# nrLinesPerPage							= (maxY+1)/lineHeight;
		  pages_without_sum							= groupBy (nrLinesPerPage-3) node_size_list; // -3: 2 for header, and always 1 for sum line
		  printed_pages								= pages_without_sum % (first-1,last-1);
		// ensure, that sum is always printed, regardless of the range of pages the user has choosen
		| isEmpty printed_pages
			= ([],picture)
		# (all_but_last_pages,last_page)			= splitAt ((length printed_pages)-1) printed_pages;
		  positions									= [Pos0,Pos1,Pos2,Pos3,WindowWidth];
		  positions									= PCorMac [pos*horizontal_dpi/72 \\ pos <- positions] positions;
		  positions									= positions ++ [maxX];
		  all_but_last_drawfunctions				= map (\ data_in_one_page -> redraw_window_with_positions printFont lineHeight fontAscent fontDescent positions False [((0,0),page)] data_in_one_page node_size_sum) all_but_last_pages;
		  last_drawfunction							= redraw_window_with_positions printFont lineHeight fontAscent fontDescent positions True [((0,0),page)] (hd last_page) node_size_sum;
		  all_drawfuncs								= map seq (all_but_last_drawfunctions ++ [last_drawfunction]);
		  // the mapping of seq converts [[Drawfunction]] into [Drawfunction]
		// ok
		= (flatten (repeatn copies all_drawfuncs),picture);

formatInfo window_font pic
	# (fm,pic)=getFontMetrics window_font pic;
	= ((fontLineHeight fm,fm.fAscent,fm.fDescent),pic); 

redraw_window_with_positions printFont lineHeight fontAscent fontDescent positions also_draw_total area node_size_list node_size_sum
	# delta_text = fontDescent + 1;//lineHeight - fontAscent - 1;//(fontLeading / 2);
	= [	setPenFont printFont,
		draw_table_header positions (2+fontAscent) (2+lineHeight),
		draw_heap_profile_lines positions also_draw_total node_size_list (4+fontAscent+lineHeight) lineHeight delta_text node_size_sum];
/*
doPrintSetupDialog s=:{printingSetup} io
	# (printingSetup, io)	= printSetupDialog printingSetup io;
	= ({ s & printingSetup=printingSetup }, io);
*/
snd (_,b) = b;

groupBy :: !Int [x] -> [[x]];
groupBy n [] = [];
groupBy n l = [(take n l ) : (groupBy n (drop n l))]; 
