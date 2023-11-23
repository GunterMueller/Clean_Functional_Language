implementation module pdObjectToMem;

import ProcessSerialNumber;
import ExtInt;
from DynamicLink import ReplyReq, ReplyReqS, MakeNonUnique, ReceiveCodeDataAdr, mwrites, FlushBuffers;
import CommonObjectToDisk;
from DynamicLinkerOffsets import Dcompute_imported_library_symbol_offsets_for_libraries;
import IdataSection;
import StdEnv;
import pdSymbolTable;
import State;
import pdExtInt, pdExtString;
import ExtArray;
import memory;
import LinkerMessages;
import LinkerOffsets;
import _SystemDynamic;
from LibraryInstance import ::Libraries(..);

// Client <-> Server communication
class SendAddressToClient a
where {
	SendAddressToClient :: !ProcessSerialNumber a !*f -> *f
};

instance SendAddressToClient Int
where {
	SendAddressToClient _ start_addr io
		| ReplyReq start_addr
			= io;
};

instance SendAddressToClient {#Char}
where {
	SendAddressToClient _ s_symbol_addresses io
		| ReplyReqS s_symbol_addresses
			= io;
};

symbol_addresses_to_string symbol_addresses
	# symbol_addresses_string=createArray ((length symbol_addresses)<<2) '\0';
	= fill_symbol_addresses_string 0 symbol_addresses symbol_addresses_string;
	where {
		fill_symbol_addresses_string i [symbol_address:symbol_addresses] symbol_addresses_string
			# symbol_addresses_string = WriteLong symbol_addresses_string i symbol_address;
			= fill_symbol_addresses_string (i+4) symbol_addresses symbol_addresses_string;
		fill_symbol_addresses_string i [] symbol_addresses_string
			= symbol_addresses_string;
	}

instance SendAddressToClient [Int]
where {
	SendAddressToClient _ symbol_addresses io
		#! s = symbol_addresses_to_string symbol_addresses
		| ReplyReqS s
			= io;
};

instance SendAddressToClient (Int,[Int])
where {
	SendAddressToClient _ (id,symbol_addresses) io
		#! encoded_symbol_addresses = symbol_addresses_to_string symbol_addresses
		#! encoded_id
			= FromIntToString id;
		| ReplyReqS (encoded_id +++ encoded_symbol_addresses)
			= io;
}; 

instance SendAddressToClient ({#Char},Int,[Int])
where {
	SendAddressToClient _ (string,id,symbol_addresses) io
		#! encoded_symbol_addresses = symbol_addresses_to_string symbol_addresses
		#! encoded_id = FromIntToString id;
		| ReplyReqS (string +++ encoded_id +++ encoded_symbol_addresses)
			= io;
}; 

instance SendAddressToClient ({#Char},{#Char},Int,[Int])
where {
	SendAddressToClient _ (string,s2,id,symbol_addresses) io
		#! encoded_symbol_addresses = symbol_addresses_to_string symbol_addresses
		#! encoded_id = FromIntToString id;
		| ReplyReqS (string +++ s2 +++ encoded_id +++ encoded_symbol_addresses)
			= io;
}; 

instance SendAddressToClient ({#Char},{#Char},Int,[Int],{#Char})
where {
	SendAddressToClient _ (string,s2,id,symbol_addresses,encoded_type_redirection_table) io
		#! encoded_symbol_addresses = symbol_addresses_to_string symbol_addresses
		#! encoded_id = FromIntToString id;
		| ReplyReqS (string +++ s2 +++ encoded_id +++ encoded_symbol_addresses +++ encoded_type_redirection_table)
			= io;
}; 

class EncodeClientMessage a
where {
	EncodeClientMessage :: a -> String
};

instance EncodeClientMessage [Int]
where {
	EncodeClientMessage symbol_addresses
		= symbol_addresses_to_string symbol_addresses
};

instance Target2 Int
where {
	WriteOutput {file_or_memory,offset,aligned_offset,string,state} mem_ptr
		#! q = mwrites file_or_memory aligned_offset string 0/*mem_ptr*/;
		| q==q
			= (state,mem_ptr);
			= (state,mem_ptr);
};

:: WriteImageInfo
	= {
		wii_code_start	:: !Int
	,	wii_code_end	:: !Int
	,	wii_data_start	:: !Int
	,	wii_data_end	:: !Int
	};
	
default_write_image_info :: WriteImageInfo;
default_write_image_info
	= {
		wii_code_start	= 0
	,	wii_code_end	= 0
	,	wii_data_start	= 0
	,	wii_data_end	= 0
	};

getMemory3 :: !*f -> (!*Mem,!*f);
getMemory3 io
	= (Mem,io);
		
putMemory3 :: !*Mem !*f -> *f;
putMemory3 mem io
		= io;
	
ReceiveCodeDataAdr3 text_end_vaddr bss_end_vaddr mem
	#! (b1,i1,i2)
		= ReceiveCodeDataAdr text_end_vaddr bss_end_vaddr;
	= (b1,i1,i2,mem);
	
FlushBuffers3 file mem
	#! q = FlushBuffers file;
	= (q,mem);

need_base_libraries2 :: !Libraries !*State !*Mem -> (!Libraries,!*State,!*Mem);
need_base_libraries2 libraries state mem
	#! (libraries,state) = need_base_libraries libraries state;
	= (libraries,state,mem);
{
	need_base_libraries :: !Libraries !*State -> (!Libraries,!*State);
	need_base_libraries libraries state
		#! (n_libraries,library_names) = concat_library_names 0 libraries ""; 
		#! (ok,library_addresses) = NeedBaseLibraries library_names n_libraries;
		| not ok
			#! msg = "NeedBaseLibraries: one of the required dynamic libraries cannot be found (needs improvement)";
			= (libraries,AddMessage (LinkerError msg) state);
		= (store_base_addresses library_addresses 0 libraries,state);
	where
	{
		concat_library_names :: !Int !Libraries !String  -> (!Int,!String);
		concat_library_names n_libraries EmptyLibraries library_names_string
			= (n_libraries,library_names_string +++ "\0");
		concat_library_names n_libraries (Libraries library_list libraries) library_names_string
			# (n_libraries,library_names_string) = concat_library_names2 n_libraries library_list library_names_string;
			= concat_library_names n_libraries libraries library_names_string;
		{
			concat_library_names2 :: !Int !LibraryList !String  -> (!Int,!String);
			concat_library_names2 n_libraries EmptyLibraryList library_names_string
				= (n_libraries,library_names_string);
			concat_library_names2 n_libraries (Library library_name _ _ _ librarylists) library_names_string
			    | library_name == ""
			    	= abort "concat_library_names2:  library without name";
					= concat_library_names2 (inc n_libraries) librarylists (library_names_string +++ library_name +++ "\0");
		}
	
		NeedBaseLibraries :: !String !Int -> (!Bool,!String);
		NeedBaseLibraries _ _
			= code {
				ccall NeedBaseLibraries "SI-IS"
			};
	
		store_base_addresses :: !String !Int !Libraries -> Libraries;
		store_base_addresses _ _ EmptyLibraries
			= EmptyLibraries;
		store_base_addresses library_addresses ith_address (Libraries library_list libraries)
			#! (ith_address,library_list) = store_base_addresses2 library_addresses ith_address library_list;
			#! libraries = store_base_addresses library_addresses ith_address libraries;
			= Libraries library_list libraries;
		{
			store_base_addresses2 :: !String !Int !LibraryList -> (!Int,!LibraryList);
			store_base_addresses2 _ ith_address EmptyLibraryList
				= (ith_address,EmptyLibraryList);
			store_base_addresses2 library_addresses ith_address (Library library_name library_base_address library_symbols_list n_library_symbols library_list)
				#! library_base_address = library_addresses ILONG ith_address;
				#! (ith_address,new_libraries) = store_base_addresses2 library_addresses (ith_address+4) library_list
				= (ith_address,Library library_name library_base_address library_symbols_list n_library_symbols new_libraries);
		}
	}
}

compute_idata_strings_size_for_libraries :: !Libraries !Int !Int !Int !*{#Bool} !*{#Int} -> (!Int,!Int,!*{#Bool},!*{#Int});
compute_idata_strings_size_for_libraries EmptyLibraries idata_string_size n_imported_symbols0 library_file_n marked_bool_a marked_offset_a
	= (idata_string_size,n_imported_symbols0,marked_bool_a,marked_offset_a);
compute_idata_strings_size_for_libraries (Libraries library_list libraries) idata_string_size n_imported_symbols0 library_file_n marked_bool_a marked_offset_a
	#! first_symbol_n = marked_offset_a.[size marked_offset_a+library_file_n];
	# (marked_bool_a,idata_string_size,n_imported_symbols0)
		= compute_idata_strings_size library_list idata_string_size n_imported_symbols0 first_symbol_n marked_bool_a;
	# library_file_n = compute_new_library_file_n library_list library_file_n;
	= compute_idata_strings_size_for_libraries libraries idata_string_size n_imported_symbols0 library_file_n marked_bool_a marked_offset_a;
	{
		compute_new_library_file_n EmptyLibraryList library_file_n
			= library_file_n;
		compute_new_library_file_n (Library _ _ _ _ library_list) library_file_n
			= compute_new_library_file_n library_list (library_file_n+1);
	}

write_image :: !Libraries !*State *f -> *(!Int,!WriteImageInfo,*State,*f) | FileEnv f;
write_image all_libraries state=:{n_xcoff_symbols,n_library_symbols,library_list,n_libraries,n_xcoff_files,linker_state_info={one_pass_link}} files
	# (mem,files) = getMemory3 files;

	#! (marked_bool_a,state) = select_marked_bool_a state;
	#! (marked_offset_a,state) = select_marked_offset_a state;
	#! (module_offset_a,state) = select_module_offset_a state;
	#! (xcoff_a,state) = select_xcoff_a state;

	# xcoff_list = xcoff_array_to_list 0 xcoff_a;

	// TEXT, calculating text size
	#! (marked_bool_a,text_end_vaddr0,module_offset_a, xcoff_list)
		= compute_module_offsets Text 0 xcoff_list 0 0 marked_bool_a module_offset_a;
	
	#! (_,n_imported_symbols,marked_bool_a,marked_offset_a)
		= compute_idata_strings_size_for_libraries all_libraries 0 0 (~n_libraries) marked_bool_a marked_offset_a;

	# text_end_vaddr = text_end_vaddr0+4 * n_imported_symbols;

	// DATA, calculating data size		
	# (marked_bool_a,data_end_vaddr,module_offset_a, xcoff_list)
		= compute_module_offsets Data 0 xcoff_list 0 0 marked_bool_a module_offset_a;

	# bss_vaddr = data_end_vaddr;

	#! (marked_bool_a,bss_end_vaddr,module_offset_a, xcoff_list)
		= compute_module_offsets Bss 0 xcoff_list bss_vaddr 0 marked_bool_a module_offset_a;

	#! (ok,code_p,data_p,mem) 
		= ReceiveCodeDataAdr3 text_end_vaddr bss_end_vaddr mem;
	| not ok
		= abort ("killed" +++ toString code_p +++ " - " +++ toString bss_vaddr); 
	
	#! (udata_p,data_p) = MakeNonUnique data_p;
	#! (ucode_p,code_p) = MakeNonUnique code_p;

	// verbose
//	#! code_msg = if (text_end_vaddr <> 0) [Verbose ("!code from " +++ (hex_int code_p) +++ " to " +++ (hex_int (dec code_p+text_end_vaddr)) +++ " - " +++ toString (/*dec*/ text_end_vaddr) +++ " bytes")] [];
//	#! data_msg = if (bss_end_vaddr <> 0) [Verbose ("!data from " +++ (hex_int data_p) +++ " to " +++ (hex_int (dec data_p+bss_end_vaddr)) +++ " - " +++ toString (/*dec*/ bss_end_vaddr) +++ " bytes")] [];
		
	#! wii
		= {	wii_code_start	= code_p
		,	wii_code_end	= code_p + text_end_vaddr
		,	wii_data_start	= data_p
		,	wii_data_end	= data_p + bss_end_vaddr
		};
	
	// head contains code start address of current link session
	#! state = { state & begin_end_addresses = [{ca_begin = code_p,ca_end = code_p + text_end_vaddr}:state.begin_end_addresses] };
			
	// Rebase text segment	
	#! (marked_bool_a,_,module_offset_a, xcoff_list)
		= compute_module_offsets Text code_p xcoff_list 0 0 marked_bool_a module_offset_a;
	
	/*
		The base of each library is calculated again and again. Clearly this can
	 	be optimized but then also the AddAndInit must also be adopted because 
	 	the bases need to be filled in the library list. 
	*/
	#! (all_libraries,state,mem) = need_base_libraries2 all_libraries state mem;

	#! (ok,state) = IsErrorOccured state;
	| not ok
		= (0,default_write_image_info,state,files);

	#! (all_libraries,_,marked_bool_a,module_offset_a,marked_offset_a)
		= Dcompute_imported_library_symbol_offsets_for_libraries all_libraries (code_p+text_end_vaddr0) (~n_libraries) marked_bool_a module_offset_a marked_offset_a;

	// ----
	// DATA
	#! (marked_bool_a,_,module_offset_a, xcoff_list)
		= compute_module_offsets Data data_p xcoff_list 0 0 marked_bool_a module_offset_a;

	#! (marked_bool_a,_,module_offset_a, xcoff_list)
		= compute_module_offsets Bss data_p xcoff_list bss_vaddr 0 marked_bool_a module_offset_a;

	#! (s_module_offset_a,module_offset_a)
		= usize module_offset_a;
	#! (module_offset_a,marked_bool_a)
		= loopAst f (module_offset_a,marked_bool_a) n_xcoff_symbols;
	with {
		f i (module_offset_a,marked_bool_a)
			| module_offset_a.[i] < 0
				#! (index,module_offset_a) = module_offset_a![i];
				#! (offset,module_offset_a) = module_offset_a![~index];
				| (marked_bool_a.[~index] && offset > 0)		// extra check
					#! module_offset_a = { module_offset_a & [i] = offset };
					= (module_offset_a,marked_bool_a);
					= abort ("unmark1ed or offset <= 0   (" +++ toString offset +++ ")");
				= (module_offset_a,marked_bool_a);
	};

	#! state = { state &
		n_libraries = n_libraries,
		n_xcoff_symbols = n_xcoff_symbols,
		n_library_symbols = n_library_symbols,
	
		n_xcoff_files = n_xcoff_files,
		marked_bool_a = marked_bool_a,
		marked_offset_a = marked_offset_a,
		module_offset_a = module_offset_a,
		xcoff_a = xcoff_list_to_xcoff_array xcoff_list n_xcoff_files,
		linker_state_info.one_pass_link = one_pass_link
 	 };

	#! ((file,_,state),files)
		= (accFiles (write_code_to_pe_files n_xcoff_files True 0 0 (0,0) state one_pass_link ucode_p) files);//
	#! (q,mem)
		= FlushBuffers3 file mem;

	| q <> 1
		= abort "FlushBuffers";

	#! files = putMemory3 mem files;
	= (0,wii,state,files);
