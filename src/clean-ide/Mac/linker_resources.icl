implementation module linker_resources;

import StdInt,StdClass,StdFile,StdArray,StdBool,StdChar,StdString, StdTuple;
import resources,memory,structure,files;
// RWS ...
import pointer;
// ... RWS

(THEN) infixl;
(THEN) a f :== f a;

import StdMisc;
//import dodebug;
trace_n` _ f :== f;

create_application_resource :: !{#Char} !ResourceClass !Bool (!Int, !{#Char}) !Int !Int !Int !Int !Int !Int !Int !*Files -> (!Bool,!*Files);
create_application_resource file_name r_class application_existed font_info heap_size heap_size_multiple stack_size flags application_and_extra_memory_size initial_heap_size memory_profile_minimum_heap_size files
	| trace_n` ("car",file_name) False//True
		= (False,files);
	# (error_n,t1)= if application_existed
						(SetFileType "APPL" file_name NewToolbox)
						(SetFileTypeAndCreator "APPL" "\0\0\0\0" file_name NewToolbox);
	| trace_n` ("car0",application_existed,file_name) error_n<>0
		= (False,files);
	# (ref_num,t2)=open_resource_file t1;
	| trace_n` ("car1",error_n,ref_num) ref_num==(-1)
		= (False,files);
	# (ok1,t4)=case r_class of {
				Classic	-> add_cfrg_resource file_name stack_size t2;
				Carbon	-> add_cfrg_resource file_name stack_size t2;
				MachO	-> (True,t2);
				};
	# t4 = trace_n` ("car2",ok1) t4;
	# (ok2,t5)=add_sthp_resource heap_size heap_size_multiple stack_size flags initial_heap_size t4;
	# t5 = trace_n` ("car3",ok2) t5;
	# (ok3,t6)=case r_class of {
				Classic	-> change_size_resource (heap_size+stack_size+application_and_extra_memory_size) t5;
				Carbon	-> change_size_resource (heap_size+stack_size+application_and_extra_memory_size) t5;
				MachO	-> (True,t5);
				};
	# t6 = trace_n` ("car4",ok3) t6;
	# (ok4,t7)=add_prfl_resource memory_profile_minimum_heap_size t6;
	# t7 = trace_n` ("car5",ok4) t7;
	# (ok5,t8)=add_font_resource font_info t7;
	# t8 = trace_n` ("car6",ok5) t8;
	# (ok6,t9)=case r_class of {
				Classic -> (True,t8);
				Carbon	-> add_carb_resource t8;
				MachO	-> add_carb_resource t8;//(True,t8);
				};
	# t9 = trace_n` ("car7",ok6) t9;
	# (res_error,_)=ResError (CloseResFile ref_num t9);
	| trace_n` ("car8",res_error) res_error<>0 /* || not ok0 */ || not ok1 || not ok2 || not ok3 || not ok4 || not ok5 || not ok6
		= (False,files);
		= (True,files);
{}{
	open_resource_file t0
		| ref_num0<>(-1)
			= (ref_num0,t2); {
				t2 = t1
						THEN remove_resource "PRFL" 128
						THEN remove_resource "Font" 128
						THEN remove_resource "SIZE" 0
						THEN remove_resource "SIZE" 1
						THEN remove_resource "STHP" 0
						THEN remove_resource "cfrg" 0
						THEN remove_resource "carb" 0;
			}
			= (HOpenResFile 0 0 file_name 3 (HCreateResFile 0 0 file_name t1));
		{}{
			(ref_num0,t1)=HOpenResFile 0 0 file_name 3 t0;
		}
}
/*
create_application_resource :: !{#Char} !ResourceClass /* RWS ... */ !Bool /* ... RWS */ (!Int, !{#Char}) !Int !Int !Int !Int !Int !Int !Int !*Files -> (!Bool,!*Files);
create_application_resource file_name r_class /* RWS ... */ application_existed /* ... RWS */ font_info heap_size heap_size_multiple stack_size flags application_and_extra_memory_size initial_heap_size memory_profile_minimum_heap_size files
	| error_n<>0
		= (False,files);
	| ref_num==(-1)
		= (False,files);
	| res_error<>0 /* || not ok0 */ || not ok1 || not ok2 || not ok3 || not ok4 || not ok5
		= (False,files);
		= (True,files);
{}{
	(res_error,_)=ResError (CloseResFile ref_num t9);

/* DvA ... */
	(ok6,t9)=case r_class of {
				Classic -> (True,t8);
				Carbon	-> add_carb_resource t8;
				MachO	-> add_carb_resource t8;//(True,t8);
				};
/* ... DvA */

/* RWS ... */
	(ok5,t8)=add_font_resource font_info t7;
/* ... RWS */

	(ok4,t7)=add_prfl_resource memory_profile_minimum_heap_size t6;

/* RWS ...
	(ok3,t6)=add_size_resource (heap_size+stack_size+application_and_extra_memory_size) t5;
*/
	(ok3,t6)=case r_class of {
				Classic	-> change_size_resource (heap_size+stack_size+application_and_extra_memory_size) t5;
				Carbon	-> change_size_resource (heap_size+stack_size+application_and_extra_memory_size) t5;
				MachO	-> (True,t5);
				};
/* ... RWS */
	(ok2,t5)=add_sthp_resource heap_size heap_size_multiple stack_size flags initial_heap_size t4;
	(ok1,t4)=case r_class of {
				Classic	-> add_cfrg_resource file_name stack_size t2;
				Carbon	-> add_cfrg_resource file_name stack_size t2;
				MachO	-> (True,t2);
				};
/*
	(ok1,t4)=add_code1_resource t3;
	(ok0,t3)=add_code0_resource t2;
*/
	(ref_num,t2)=open_resource_file t1;
/* RWS ...
	(error_n,t1)=SetFileTypeAndCreator "APPL" null_string4 file_name OSNewToolbox;
	null_string4=null_string2+++null_string2;
	null_string2=null_string1+++null_string1;
	null_string1=toString '\0';
*/
	(error_n,t1)= if application_existed
				(SetFileType "APPL" file_name NewToolbox)
				(SetFileTypeAndCreator "APPL" "\0\0\0\0" file_name NewToolbox);
/* RWS */

	open_resource_file t0
		| ref_num0<>(-1)
			= (ref_num0,t2); {
				t2 = t1
						THEN remove_resource "PRFL" 128
// RWS					THEN remove_resource "SIZE" (-1)
						THEN remove_resource "Font" 128
// ... RWS
						THEN remove_resource "SIZE" 0
						THEN remove_resource "SIZE" 1
						THEN remove_resource "STHP" 0
						THEN remove_resource "cfrg" 0
// DvA
						THEN remove_resource "carb" 0;
// ...DvA
			}
			= (HOpenResFile 0 0 file_name 3 (HCreateResFile 0 0 file_name t1));
		{}{
			(ref_num0,t1)=HOpenResFile 0 0 file_name 3 t0;
		}
}
*/
remove_resource resource_name n t0
	| handle==0
		= t1;
		= RemoveResource handle t1;
	{}{
		(handle,t1)=Get1Resource resource_name n t0;
	}

add_cfrg_resource :: String Int *Int -> (!Bool,!*Int);
add_cfrg_resource file_name stack_size t0
	# total_size		= 75 + (size file_name);
	# n_align4_bytes	= (4 - (total_size bitand 3)) bitand 3;
	# (handle,_,t1)		= NewHandle (total_size + n_align4_bytes) t0;
	| handle == 0
		= (False,t1);
	# (error_n,t2)		= ResError (AddResource (fill_cfrg_handle file_name n_align4_bytes handle stack_size) "cfrg" 0 "" t1);
	= (error_n==0,t2);

fill_cfrg_handle file_name n_align4_bytes handle stack_size
	= h1;
{
	(h1,_)=append_align_bytes n_align4_bytes s21;
	s21=AppendString s20 file_name;
	s20=AppendByte s19 (file_name_length);	// name
	s19=AppendWord s18 (43+file_name_length+n_align4_bytes);	// memberSize
	s18=AppendLong s17 0;		// extension_count + uWhere2
	s17=AppendLong s16 0;		// uWhere1
	s16=AppendLong s15 0;		// length
	s15=AppendLong s14 0;		// offset
	s14=AppendLong s13 0x101;	// usage (kApplicationCFrag)
	s13=AppendLong s12 stack_size;		// appStackSize
	s12=AppendLong s11 0;		// oldDefVersion
	s11=AppendLong s10 0;		// current version
	s10=AppendLong s9 0;		// reserved + update level
	s9=AppendString s8 "pwpc";	// architecture
	s8=AppendLong s7 1;
	s7=AppendLong s6 0;
	s6=AppendLong s5 0;
	s5=AppendLong s4 0;
	s4=AppendLong s3 0;
	s3=AppendLong s2 1;
	s2=AppendLong s1 0;
	s1=AppendLong s0 0;
	s0=HandleToStructure handle;
	
	file_name_length= size file_name;
	
	append_align_bytes n s
	| n==0
		=s;
		=append_align_bytes (n-1) (AppendByte s 0)
}

/*
add_code0_resource t0
	| handle==0
		= (False,t1);
		= (error_n==0,t2);
	{}{
		(error_n,t2)=ResError (AddResource (fill_resource_handle code_resource_0 handle) "CODE" 0 "" t1);
		(handle,_,t1) = NewHandle (length_resource code_resource_0) t0;
		code_resource_0=code_resource0;
	}

add_code1_resource t0
	| handle==0
		= (False,t1);
		= (error_n==0,t2);
	{}{
		(error_n,t2)=ResError (AddResource (fill_resource_handle code_resource_1 handle) "CODE" 1 "" t1);
		(handle,_,t1) = NewHandle (length_resource code_resource_1) t0;
		code_resource_1=code_resource1;
	}

fill_resource_handle resource handle
	=	h;
	{
		(h,_) = add_strings_to_structure resource (HandleToStructure handle);
		
		add_strings_to_structure [] structure = structure;
		add_strings_to_structure [s:l] structure = add_strings_to_structure l (AppendString structure s);
	};
*/

add_prfl_resource :: Int *Int -> (!Bool,!*Int);
add_prfl_resource heap_size t0
	| handle==0
		= (False,t1);
		= (error_n==0,t2);
	{}{
		(error_n,t2)=ResError (AddResource handle2 "PRFL" 128 "" t1);
		(handle2,_)=AppendLong s0 heap_size;
		s0=HandleToStructure handle;
		(handle,_,t1) = NewHandle 4 t0;
	}

add_sthp_resource :: Int Int Int Int Int *Int -> (!Bool,!*Int);
add_sthp_resource heap_size heap_size_multiple stack_size flags initial_heap_size t0
	| handle==0
		= (False,t1);
		= (error_n==0,t2);
	{}{
		(error_n,t2)=ResError (AddResource handle2 "STHP" 0 "" t1);
		(handle2,_)=AppendLong s4 initial_heap_size;
		s4=AppendLong s3 flags;
		s3=AppendLong s2 heap_size;
		s2=AppendLong s1 heap_size_multiple;
		s1=AppendLong s0 stack_size;
		s0=HandleToStructure handle;
		(handle,_,t1) = NewHandle 20 t0;
	}

/* RWS ... */
change_size_resource :: Int *Int -> (!Bool,!*Int);
change_size_resource heap_size t
	# (flags,t)=get_size_flags_and_remove_resource t
	= add_size_resource flags heap_size t;

get_size_flags_and_remove_resource :: *Int -> (!Int, !*Int);
get_size_flags_and_remove_resource t
	# (handle,t)=Get1Resource "SIZE" (-1) t;
//	# t=test_res_error "Get1Resource" t
	| handle==0
		=(0,t);
	# (ptr,t)=DereferenceHandle handle t;
	# (flags,t)=LoadWord ptr t;
	# t=RemoveResource handle t
//	# t=test_res_error "RemoveResource" t
	= (flags,t);

test_res_error s t
	# (error_n,t)=ResError t
	| error_n<>0
		=	abort ("res error " +++ toString error_n +++ " " +++ s +++ "\n");
	// otherwise
		=	t;

add_font_resource :: (Int, {#Char}) *Int -> (!Bool,!*Int);
add_font_resource (font_size, font_name) t0
	| font_size == 0 || font_name == ""
		= (True, t0)
	| handle==0
		= (False,t1);
		= (error_n==0,t2);
	{}{
		(error_n,t2)=ResError (AddResource handle2 "Font" 128 "" t1);
		(handle2,_)=AppendString s2 font_name;
		s2=AppendByte s1 font_name_size;
		s1=AppendWord s0 font_size;
		s0=HandleToStructure handle;
		(handle,_,t1) = NewHandle (3 + font_name_size) t0;
		font_name_size = size font_name;
	}
/* ... RWS */

/* DvA ... */
add_carb_resource :: *Int -> (!Bool,!*Int);
add_carb_resource t0
	| handle==0
		= (False,t1);
		= (error_n==0,t4);
	{}{
		(handle,_,t1)	= NewHandle 8 t0;
		t2				= copy_string_to_handle "\0\0\0\0\0\0\0\0" handle 8 t1;
		(error_n,t3)	= ResError (AddResource handle "carb" 0 "" t2);
//		(_,t4)			= DisposHandle handle t3;
		t4				= t3;
	}
/* ... DvA */

// RWS added flags parameter
add_size_resource :: Int Int *Int -> (!Bool,!*Int);
add_size_resource flags heap_size t0
	| handle==0
		= (False,t1);
		= (error_n==0,t2);
	{}{
		(error_n,t2)=ResError (AddResource handle2 "SIZE" (-1) "" t1);
		(handle2,_)=AppendLong s2 heap_size;
		s2=AppendLong s1 heap_size;
		s1=AppendWord s0 flags;
		s0=HandleToStructure handle;
		(handle,_,t1) = NewHandle 10 t0;
	}
	
// RWS ...
read_application_options :: !{#Char} !*Files -> (!Bool,(!Int, !{#Char}), !Int, !Int, !Int, !Int, !Int, !Int, !Int, !Int, !*Files);
read_application_options file_name files
	# (pef_read, pef_size, files)
		=	read_pef_size_from_data_fork file_name files
	| not pef_read
		=	(False, (0, ""), 0, 0, 0, 0, 0, 0, 0, 0, files)
	# (ref_num, t)
		=	HOpenResFile 0 0 file_name 1 NewToolbox
	| ref_num == (-1)
		=	(False, (0, ""), 0, 0, 0, 0, 0, 0, 0, 0, files)
	# (size_read, _, minimum_size, t)
		=	read_size_resource t
	| not size_read
		=	(False, (0, ""), 0, 0, 0, 0, 0, 0, 0, 0, files);
	# (sthp_read, stack_size, heap_size_multiple, heap_size, flags, initial_heap_size, t)
		=	read_sthp_resource t
	| not sthp_read
		=	(False, (0, ""), 0, 0, 0, 0, 0, 0, 0, 0, files);
	# (_, font_size, font_name, t)
		=	read_font_resource t
	# (_, profile_heap_size, t)
		=	read_prfl_resource t
	# (res_error, _)
		=	ResError (CloseResFile ref_num t);
	| res_error <> 0
		=	(False, (0, ""), 0, 0, 0, 0, 0, 0, 0, 0, files);
	// otherwise
		=	(True, (font_size, font_name), heap_size, heap_size_multiple, stack_size,
				flags, initial_heap_size, profile_heap_size, pef_size,
					minimum_size-heap_size-stack_size, files);

read_font_resource :: !*Toolbox -> (!Bool, !Int, !{#Char}, !*Toolbox);
read_font_resource t
	# (handle,t)
		=	Get1Resource "Font" 128 t
	| handle==0
		=	(False, 0,"",t);
	# (ptr, t)
		=	DereferenceHandle handle t;
	# (font_size, t)
		=	LoadWord ptr t;
	  ptr
	  	=	ptr+2;
	# (font_name_size, t)
		=	LoadByte ptr t;
	  ptr
	  	=	ptr+1;
	# (font_name, _, t)
		=	LoadString 0 font_name_size (createArray font_name_size ' ') ptr t;
	= (False, font_size, font_name, t);

read_size_resource :: *Int -> (!Bool, !Int, !Int, !*Int);
read_size_resource t
	# (handle,t)
		=	Get1Resource "SIZE" (-1) t
	| handle==0
		=	(False, 0, 0, t);
	# (ptr, t)
		=	DereferenceHandle handle t;
	# (flags, t)
		=	LoadWord ptr t;
	  ptr
	  	=	ptr+6; /* skip (long) size */
	# (minimum_size, t)
		=	LoadLong ptr t;
	=	(True, flags, minimum_size, t);

read_sthp_resource :: *Toolbox -> (!Bool, !Int, !Int, !Int, !Int, !Int, !*Toolbox);
read_sthp_resource t
	# (handle,t)
		=	Get1Resource "STHP" 0 t
	| handle==0
		=	(False, 0, 0, 0, 0, 0, t);
	# (ptr, t)
		=	DereferenceHandle handle t;
	# (stack_size, t)
		=	LoadLong ptr t;
	  ptr
	  	=	ptr+4;
	# (heap_size_multiple, t)
		=	LoadLong ptr t;
	  ptr
	  	=	ptr+4;
	# (heap_size, t)
		=	LoadLong ptr t;
	  ptr
	  	=	ptr+4;
	# (flags, t)
		=	LoadLong ptr t;
	  ptr
	  	=	ptr+4;
	# (initial_heap_size, t)
		=	LoadLong ptr t;
	=	(True, stack_size, heap_size_multiple, heap_size, flags, initial_heap_size, t);

read_prfl_resource :: *Toolbox -> (!Bool, !Int, !*Toolbox);
read_prfl_resource t
	# (handle,t)
		=	Get1Resource "PRFL" 128 t
	| handle==0
		=	(False, 0, t);
	# (ptr, t)
		=	DereferenceHandle handle t;
	# (profile_heap_size, t)
		=	LoadLong ptr t;
	=	(True, profile_heap_size, t);

read_pef_size_from_data_fork :: {#Char} *Files -> (!Bool, !Int, !*Files);
read_pef_size_from_data_fork name files
	# (open, file, files)
		=	fopen name FReadData files;
	| not open
		=	(False, 0, files);
	# (magic, file)
		=	freads file 12;
	| magic <> "Joy!peffpwpc"
		=	(False, 0, snd (fclose file files));
	# (sought, file)
		=	fseek file 0x30 FSeekSet;
	| not sought
		=	(False, 0, snd (fclose file files));
	# (read, pef_size, file)
		=	freadi file;
	| not read
		=	(False, 0, snd (fclose file files));
	# (closed, files)
		=	fclose file files;
	| not closed
		=	(False, 0, files);
	// otherwise
		=	(True, pef_size, files);

LoadString :: Int Int *{#Char} Ptr *Toolbox -> (!*{#Char}, Ptr, !*Toolbox);
LoadString n size string ptr t
	| n == size
		=	(string, ptr, t);
	# (char, t)
		=	LoadByte (ptr+n) t;
	=	LoadString (n+1) size {string & [n] = toChar char} ptr t;

// ... RWS 

/*
length_resource [] = 0;
length_resource [s:l] = size s+length_resource l;

code_resource0=
   ["\000\000\000\060\000\000\000\060\000\000\000\010\000\000\000\040",
    "\000\000\077\074\000\001\251\360"];

code_resource1=
   ["\000\000\000\001\116\126\376\246\110\347\003\030\107\356\377\322",
    "\111\356\376\246\101\372\002\342\056\010\130\207\046\207\160\000",
    "\047\100\000\004\056\013\125\217\110\172\002\300\057\074\160\167",
    "\160\143\160\001\057\000\110\156\377\332\110\156\376\316\110\156",
    "\376\322\077\074\000\001\252\132\112\137\147\006\160\002\140\000",
    "\002\030\125\217\057\056\377\332\110\172\002\210\057\014\110\156",
    "\377\337\077\074\000\005\252\132\112\137\146\014\160\000\020\056",
    "\377\337\014\100\000\002\147\006\160\003\140\000\001\354\125\217",
    "\057\056\377\332\110\172\002\124\110\154\000\004\110\156\377\337",
    "\077\074\000\005\252\132\112\137\146\014\160\000\020\056\377\337",
    "\014\100\000\002\147\006\160\004\140\000\001\276\125\217\057\056",
    "\377\332\110\172\002\036\110\154\000\010\110\156\377\337\077\074",
    "\000\005\252\132\112\137\146\014\160\000\020\056\377\337\014\100",
    "\000\002\147\006\160\005\140\000\001\220\125\217\057\056\377\332",
    "\110\172\001\350\110\154\000\014\110\156\377\337\077\074\000\005",
    "\252\132\112\137\146\014\160\000\020\056\377\337\014\100\000\002",
    "\147\006\160\006\140\000\001\142\125\217\057\056\377\332\110\172",
    "\001\260\110\154\000\020\110\156\377\337\077\074\000\005\252\132",
    "\112\137\146\014\160\000\020\056\377\337\014\100\000\002\147\006",
    "\160\007\140\000\001\064\125\217\057\056\377\332\110\172\001\160",
    "\110\154\000\024\110\156\377\337\077\074\000\005\252\132\112\137",
    "\146\014\160\000\020\056\377\337\014\100\000\002\147\006\160\010",
    "\140\000\001\006\125\217\057\056\377\332\110\172\001\066\110\154",
    "\000\030\110\156\377\337\077\074\000\005\252\132\112\137\146\014",
    "\160\000\020\056\377\337\014\100\000\002\147\006\160\011\140\000",
    "\000\330\125\217\057\056\377\332\110\172\000\370\110\154\000\034",
    "\110\156\377\337\077\074\000\005\252\132\112\137\146\014\160\000",
    "\020\056\377\337\014\100\000\002\147\006\160\012\140\000\000\252",
    "\125\217\057\056\377\332\110\172\000\266\110\154\000\040\110\156",
    "\377\337\077\074\000\005\252\132\112\137\146\014\160\000\020\056",
    "\377\337\014\100\000\002\147\004\160\013\140\174\125\217\057\056",
    "\377\332\110\172\000\176\110\154\000\044\110\156\377\337\077\074",
    "\000\005\252\132\112\137\146\014\160\000\020\056\377\337\014\100",
    "\000\002\147\004\160\014\140\120\075\174\252\376\377\340\035\174",
    "\000\007\377\342\102\056\377\343\160\000\055\100\377\344\102\156",
    "\377\350\102\156\377\352\055\174\000\000\000\301\377\354\102\056",
    "\377\360\035\174\000\001\377\361\075\174\000\004\377\362\055\100",
    "\377\370\055\100\377\374\101\356\377\340\054\010\055\107\377\364",
    "\057\014\040\106\116\220\130\117\114\356\030\300\376\226\116\136",
    "\116\165\012\123\145\164\120\164\162\123\151\172\145\000\022\115",
    "\141\153\145\104\141\164\141\105\170\145\143\165\164\141\142\154",
    "\145\000\016\114\115\107\145\164\103\165\162\101\160\116\141\155",
    "\145\000\012\106\151\156\144\123\171\155\142\157\154\000\020\107",
    "\145\164\123\150\141\162\145\144\114\151\142\162\141\162\171\000",
    "\007\106\123\103\154\157\163\145\000\000\006\106\123\122\145\141",
    "\144\000\006\116\145\167\120\164\162\000\006\107\145\164\105\117",
    "\106\000\006\106\123\117\160\145\156\000\014\111\156\164\145\162",
    "\146\141\143\145\114\151\142\000\100\100\100\000\174\010\002\246",
    "\275\301\377\270\220\001\000\010\224\041\376\050\140\173\000\000",
    "\061\341\000\070\062\001\001\070\063\241\001\074\063\301\001\100",
    "\063\341\001\104\062\201\001\106\062\241\001\110\062\301\001\114",
    "\201\233\000\000\200\233\000\034\141\221\000\000\140\214\000\000",
    "\110\000\004\155\200\101\000\024\143\345\000\000\070\200\000\000",
    "\142\054\000\000\110\000\004\131\200\101\000\024\054\003\000\000",
    "\101\202\000\014\070\140\000\013\110\000\004\060\201\233\000\004",
    "\250\177\000\000\143\304\000\000\110\000\004\065\200\101\000\024",
    "\054\003\000\000\101\202\000\014\070\140\000\014\110\000\004\014",
    "\201\233\000\010\200\176\000\000\060\143\000\007\110\000\004\021",
    "\200\101\000\024\140\163\000\000\054\023\000\000\100\202\000\014",
    "\070\140\000\015\110\000\003\344\060\223\000\007\124\232\000\070",
    "\200\276\000\000\220\275\000\000\201\233\000\014\143\105\000\000",
    "\250\177\000\000\143\244\000\000\110\000\003\325\200\101\000\024",
    "\054\003\000\000\100\202\000\024\200\235\000\000\200\276\000\000",
    "\174\204\050\000\101\206\000\014\070\140\000\016\110\000\003\234",
    "\201\233\000\020\250\177\000\000\110\000\003\245\200\101\000\024",
    "\054\003\000\000\101\202\000\014\070\140\000\017\110\000\003\174",
    "\250\232\000\066\124\205\020\072\174\245\040\024\124\245\030\070",
    "\174\272\050\024\060\245\000\064\220\241\001\214\250\332\000\070",
    "\124\322\020\072\176\122\060\024\126\122\030\070\176\132\220\024",
    "\062\122\000\064\250\372\000\074\124\350\020\072\175\010\070\024",
    "\125\010\030\070\175\032\100\024\202\050\000\110\176\072\210\024",
    "\063\021\000\040\201\061\000\004\125\075\020\072\177\251\350\020",
    "\127\275\030\070\177\270\350\024\201\121\000\024\177\361\120\024",
    "\202\361\000\034\176\361\270\024\203\061\000\020\175\161\120\256",
    "\175\153\007\165\101\202\000\024\211\237\000\001\175\214\007\165",
    "\063\377\000\001\100\202\377\364\210\177\000\001\174\143\007\165",
    "\063\377\000\001\101\202\000\024\210\237\000\001\174\204\007\165",
    "\063\377\000\001\100\202\377\364\210\277\000\001\174\245\007\165",
    "\063\377\000\001\101\202\000\024\210\337\000\001\174\306\007\165",
    "\063\377\000\001\100\202\377\364\063\377\000\001\067\071\377\377",
    "\073\200\000\000\100\201\000\304\210\377\000\000\174\347\007\165",
    "\101\202\000\024\211\037\000\001\175\010\007\165\063\377\000\001",
    "\100\202\377\364\063\337\000\001\211\077\000\001\175\051\007\165",
    "\143\337\000\000\101\202\000\024\211\137\000\001\175\112\007\165",
    "\063\377\000\001\100\202\377\364\175\176\370\020\231\176\377\377",
    "\201\233\000\024\127\206\020\072\174\306\260\024\060\176\377\377",
    "\142\007\000\000\141\350\000\000\074\200\160\167\140\204\160\143",
    "\070\240\000\001\140\156\000\000\110\000\002\065\200\101\000\024",
    "\070\200\000\000\230\236\377\377\054\003\000\000\101\202\000\014",
    "\070\140\000\020\110\000\002\004\210\277\000\001\174\245\007\165",
    "\063\377\000\001\101\202\000\024\210\337\000\001\174\306\007\165",
    "\063\377\000\001\100\202\377\364\063\377\000\001\063\234\000\001",
    "\174\234\310\000\101\204\377\104\203\061\000\004\073\200\000\000",
    "\143\036\000\000\057\031\000\000\100\231\000\304\201\036\000\020",
    "\060\350\377\377\201\076\000\000\057\211\000\000\100\236\000\030",
    "\201\136\000\004\175\127\120\024\063\352\377\377\211\052\377\377",
    "\110\000\000\074\143\337\000\000\071\040\000\000\211\176\000\000",
    "\054\013\000\000\101\202\000\044\141\050\000\000\061\050\000\001",
    "\054\211\000\010\100\204\000\024\175\210\370\024\210\154\000\001",
    "\057\003\000\000\100\232\377\344\063\377\377\377\211\337\000\000",
    "\231\077\000\000\201\233\000\030\143\344\000\000\124\345\020\072",
    "\174\145\260\056\142\245\000\000\142\206\000\000\110\000\001\121",
    "\200\101\000\024\231\337\000\000\200\265\000\000\220\276\000\010",
    "\054\003\000\000\100\202\001\040\210\324\000\000\054\206\000\002",
    "\101\206\000\014\070\140\000\021\110\000\001\020\063\234\000\001",
    "\063\336\000\030\177\034\310\000\101\230\377\104\201\001\001\214",
    "\200\150\000\024\174\172\030\024\201\062\000\024\177\372\110\024",
    "\200\261\000\010\070\300\000\000\057\205\000\000\100\235\000\170",
    "\201\075\000\004\201\135\000\000\175\037\120\024\174\377\120\056",
    "\054\011\000\001\100\202\000\020\175\147\370\024\221\150\000\000",
    "\110\000\000\104\054\211\000\000\100\206\000\020\175\207\030\024",
    "\221\210\000\000\110\000\000\060\057\011\000\002\100\232\000\014",
    "\070\140\000\022\110\000\000\224\125\044\020\072\174\211\040\020",
    "\124\204\030\070\174\230\040\024\201\104\377\300\175\107\120\024",
    "\221\110\000\000\060\306\000\001\063\275\000\014\177\206\050\000",
    "\101\234\377\220\201\233\000\040\200\232\000\030\110\000\000\161",
    "\200\101\000\024\200\222\000\024\174\232\040\024\200\272\000\044",
    "\177\304\050\024\201\233\000\044\142\143\000\000\200\232\000\034",
    "\174\237\040\024\174\223\040\020\110\000\000\105\200\101\000\024",
    "\054\036\001\000\100\200\000\014\070\140\000\023\110\000\000\034",
    "\143\314\000\000\110\000\000\051\200\101\000\024\070\140\000\000",
    "\110\000\000\010\113\377\376\360\200\001\001\340\060\041\001\330",
    "\174\010\003\246\271\301\377\270\116\200\000\040\200\014\000\000",
    "\220\101\000\024\174\011\003\246\200\114\000\004\116\200\004\040"];
*/
