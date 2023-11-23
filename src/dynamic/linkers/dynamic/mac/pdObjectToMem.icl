implementation module pdObjectToMem;

import DLState;

import DebugUtilities;

import ExtFile;
import LinkerOffsets;
import pdLinkerOffsets;
import CommonObjectToDisk;

from ioState import IOStateGetToolbox,IOStateSetToolbox;
from deltaIOState import FileEnv;


import ExtInt;

// PowerMacInterface
import memory,pointer,codefragments;

import ProcessSerialNumber;

// Client <-> Server communication
class SendAddressToClient a
where {
	SendAddressToClient :: !ProcessSerialNumber a !(IOState *s) -> !(IOState *s)
};

import process;

from ExtLibrary import GetToolBox,ASyncSend,ToRecvID,ConfirmID;

instance SendAddressToClient !Int
where {
//	SendAddressToClient :: !ProcessSerialNumber !Int !(IOState *s) -> !(IOState *s);
	SendAddressToClient client_id start_addr io
		#! (toolbox,io)
			= GetToolBox io;
		#! (oserr,toolbox)
			= ASyncSend ConfirmID (FromIntToString start_addr) client_id 0 toolbox;
		#! io
			= PutToolBox toolbox io;
		= io;

/*
	| client_id == client_id
		= abort ("SendAddressToClient !Int; " +++ hex_int start_addr); // io; //abort "SendAddressToClient (Int): unimplemented";
*/

/*
//	| True
//		= abort "Init";
	#! (toolbox,io)
		= GetToolBox io;
	#! (oserr,toolbox)
		= ASyncSend ConfirmID "123456789" client_id 0 toolbox;
	#! io
		= PutToolBox toolbox io;



*/
};

instance SendAddressToClient !{#Char}
where {
//	SendAddressToClient :: !String !(IOState *s) -> !(IOState *s);
	SendAddressToClient client_id s_symbol_addresses io
		= io; //abort "SendAddressToClient (String): unimplemented";
};

instance Target2 (Int,*Int)
where {
	WriteOutput {file_or_memory,offset,string,state} (code_p,toolbox)
		#! s_string
			= size string;
		#! (string,toolbox)
			= copy_string_slice_to_memory string 0 s_string /*(code_p + offset)*/ code_p toolbox;
		= ((code_p + s_string,toolbox),state);
		
	WriteLong i (code_p,toolbox)
		#! toolbox
			= StoreLong code_p i toolbox;
		= (code_p + 4,toolbox);
		
	// dummies
	DoRelocations a
		= (True,a);
	

	BeforeWritingXcoffFile _ a state
		= (a,state);
		
	AfterWritingXcoffFile _ a state
		= (a,state)

};

write_image :: !*State (!*IOState s) -> !(!Int,!*State,!*IOState s);
write_image state=:{n_xcoff_symbols,n_library_symbols,library_list,n_libraries,n_xcoff_files,one_pass_link}  io

	#! (marked_bool_a,state)
		= select_marked_bool_a state;
		
	// compute n_imported_symbols
	#! (_,_,n_imported_symbols,marked_bool_a)
		= compute_pef_string_table_size library_list 0 0 0 n_xcoff_symbols marked_bool_a;
	
	#! state 
		= { state &
			marked_bool_a		= marked_bool_a
		};
		
	// mac
	#! (end_offset=:{library_offset,end_toc_offset,end_text_offset=pef_text_section_size1,end_data_offset,end_bss_offset_a=pef_bss_section_end1},state)
		= compute_offsets2 0 state (sections_specification True n_imported_symbols);

	// test
	#! (file_n,symbol_n,state)
		= find_name "qd" state;
	#! (first_symbol_n,state)
		= selacc_marked_offset_a file_n state;
	#! (offset,state)
		= selacc_module_offset_a (first_symbol_n+symbol_n) state;
	#! state
		= F ("offset 2a=" +++ toString offset) state;

	// reserve memory in system heap 
	# (code_p,os_err,t) = NewPtrSys (pef_text_section_size1) 0;
	| F ("code_p=" +++ hex_int code_p) os_err<>0
		= abort "AddLabel: could not reserve code"; //(False,pef_bss_section_end1,files);
	# (data_p,os_err,t) = NewPtrSys pef_bss_section_end1 t;
	| F ("data_p=" +++ hex_int data_p) os_err<>0
		// INCREASE EXTRA MEMORY
		= abort ("AddLabel: could not reserve data" +++ toString os_err);		

	// update pd_state
	#! state
		= app_pdstate (\pd_state -> { pd_state & 
				toc_p		= data_p
			,	pointers	= [code_p,data_p:pd_state.pointers]}) state;
	
	// verbose
	#! messages
		= [
			Verbose ("code from " +++ (hex_int code_p) +++ " to " +++ (hex_int (dec code_p+pef_text_section_size1)) +++ " - " +++ toString (pef_text_section_size1) +++ " bytes")
		,	Verbose ("data from " +++ (hex_int data_p) +++ " to " +++ (hex_int (dec data_p+pef_bss_section_end1)) +++ " - " +++ toString (pef_bss_section_end1) +++ " bytes")
		];
	#! state
		= SetLinkerMessages messages state;		
	// rebase code & data
	#! (_,state)
		= compute_offsets2 0 state (sections_inc_specification (code_p) data_p);
		
	// test
	#! (file_n,symbol_n,state)
		= find_name "qd" state;
	#! (first_symbol_n,state)
		= selacc_marked_offset_a file_n state;
	#! (offset,state)
		= selacc_module_offset_a (first_symbol_n+symbol_n) state;
	#! state
		= F ("offset 2b=" +++ toString offset) state;
	
/*
	// TEST ...
	#! (file_n,symbol_n,state)
		= find_name "qd" state;
		
	// mark qd-symbol
	#! (file_n_offset,state)
		= selacc_marked_offset_a file_n state;

	// insert qd's absolute address
	#! (qd_address,state)
		= acc_pd_state (\pd_state=:{qd_address} -> (qd_address,pd_state)) state;
		
	#! state
		= app_module_offset_a (\module_offset_a -> {module_offset_a & [file_n_offset + symbol_n] = qd_address }) state;
	// ... TEST	
	*/	
	
/*
	// TEST
	#! (file_n,symbol_n,state)
		= find_name "small_integers" state;
	#! (small_integers_entry,state)
		= address_of_label2 file_n symbol_n state;
	#! state
		=  F ("small_integers at: " +++ (hex_int small_integers_entry)) state;
*/	
		
	// Write code; actual code
	#! (toolbox,io)
		= IOStateGetToolbox io;
	# sections
		= EndSections; // NoSections
	# ((offset,data_sections,(code_p2,toolbox),state),io)
		= accFiles (write_to_pef_files2 0 WriteText { {} \\ i <- [1..n_xcoff_files]} 0 /* offset: */ 0 state sections (code_p,toolbox)) io;
		
	// linker glue code to library functions
	| offset <> library_offset
		= abort ("AddLabel1: mismatch between computed and produced size of code: " +++ toString offset +++ " - delta: " +++ toString (offset - library_offset));
	# (toolbox_ptr=:(code_p_end,toolbox),state)
		= write_imported_library_functions_code 0 (code_p2,toolbox) n_xcoff_symbols state;
	| code_p_end <> code_p + pef_text_section_size1
		= abort "main.icl: (internal errror)";
		
	// Write Data; imported library symbols
//	#! state
//		= app_pdstate (\pd_state -> {pd_state & toc_p = data_p}) state;

	#! ((data_p2,toolbox),state)
		= store_imported_symbol_addresses2 (data_p,toolbox) state;		
	| (data_p2 - data_p) <> 4 * n_imported_symbols
		= abort ("AddLabel: mismatch between computed and produced size of imported shared library symbols " +++ toString (data_p2 - data_p));
		
	// write toc 
	# ((actual_end_toc_offset,data_sections,(data_p3,toolbox),state),io)
		= accFiles (write_to_pef_files2 0 WriteTOC data_sections 0 (n_imported_symbols<<2) state EndSections (data_p2,toolbox)) io;
	| actual_end_toc_offset <> end_toc_offset
		# s
			= "actual: " +++ toString (data_p3 - data_p) +++ " - computed: " +++ toString (end_toc_offset);
		= abort ("AddLabel: mismatch between computed and produced size of TOC symbols" +++ s);	
	| data_p2 == data_p3
		= abort "internal error";
		
	// write data
	# ((j,_,(data_p4,toolbox),state),io)
		= accFiles (write_to_pef_files2 0 WriteData data_sections 0 end_toc_offset state EndSections (data_p3,toolbox)) io;
	| (data_p4 - data_p) <> end_data_offset
		= abort ("AddLabel: mismatch between computed and produced size of DATA symbols: " +++ "j: " +++ toString j +++ " - " +++ toString (data_p4 - data_p) +++ " - " +++ toString end_data_offset);

	// write bss
	# data_p5
		= roundup_to_multiple data_p4 4;
	# (data_p6,toolbox)
		= write_zero_longs_to_file2 ((end_offset.end_bss_offset - end_offset.begin_bss_offset) >> 2) (data_p5,toolbox);
	| (data_p6 - data_p) <> end_offset.end_bss_offset
		# s
			= "actual: " +++ toString (data_p6 - data_p) +++ " - computed: " +++ toString (end_offset.end_bss_offset);
		= abort ("AddLabel: mismatch between computed and produced size of bss symbols " +++ s);
		
	// Flush data cache
	# toolbox
		= MakeDataExecutable code_p pef_text_section_size1 toolbox;

	#! label_name
		= "main";
	// Fetch offset of main-entry in TOC-table	
	#! (file_n,symbol_n,state)
		= find_name label_name state;
	#! (main_entry,state)
		= address_of_label2 file_n symbol_n state;
		
	// main-entry in toc
	#! msg
		= "main-entry in toc=" +++ hex_int (data_p + main_entry);
	#! state
		= AddMessage (Verbose msg) state;
		
	// toc (data_p + 32768)
	#! msg
		= "toc (data_p + 32768)=" +++ hex_int (data_p + 32768);
	#! state
		= AddMessage (LinkerWarning msg) state;
		
	/*
	// TEST
		// Fetch offset of main-entry in TOC-table	
	#! (file_n,symbol_n,state)
		= find_name "small_integers" state;
	#! (small_integers_entry,state)
		= address_of_label2 file_n symbol_n state;
	*/
	
	= /*F ("small_integers at: " +++ (hex_int small_integers_entry))*/ (data_p,state,IOStateSetToolbox toolbox io);
where {
MakeDataExecutable :: !Int !Int *Toolbox -> *Toolbox;
MakeDataExecutable baseAddress length t
	| length<>0
		= MakeDataExecutable_ baseAddress length t;
		= t;

	MakeDataExecutable_ :: !Int !Int *Toolbox -> *Toolbox;
	MakeDataExecutable_ baseAddress length t = code (baseAddress=D0,length=D1,t=U)(z=Z){
		call	.MakeDataExecutable
	};


	NewPtrSys :: !Int !*Toolbox -> (!Ptr,!Int,!*Toolbox);
	NewPtrSys logicalSize t = (pointer,error,0);
	{
		error=MemError t2;
		(pointer,t2)=NewPtr2Sys logicalSize t;
	}

	NewPtr2Sys :: !Int !*Toolbox -> (!Ptr,!*Toolbox);
	NewPtr2Sys logicalSize t = code (logicalSize=D0,t=U)(pointer=D0,z=Z){
		call	.NewPtrSys
	};
	
	MemError :: !*Toolbox -> Int;
	MemError t = code (t=U)(r=D0){
		call	.MemError
	};



	// copy from PlatformLinkOptions; used to computed n_imported_symbols
	compute_pef_string_table_size :: LibraryList Int Int Int Int !*{#Bool} -> (!Int,!Int,!Int,!*{#Bool});
	compute_pef_string_table_size EmptyLibraryList string_table_file_names_size string_table_symbol_names_size0 n_imported_symbols0 symbol_n marked_bool_a
		= (string_table_file_names_size,string_table_symbol_names_size0,n_imported_symbols0,marked_bool_a);
	compute_pef_string_table_size (Library file_name imported_symbols _ libraries) string_table_file_names_size string_table_symbol_names_size0 n_imported_symbols0 symbol_n0 marked_bool_a
		#! (string_table_symbol_names_size1,n_imported_symbols1,symbol_n1,marked_bool_a)
			= string_table_size_of_symbol_names imported_symbols string_table_symbol_names_size0 n_imported_symbols0 symbol_n0 marked_bool_a;
		=	compute_pef_string_table_size libraries (1 + size file_name + string_table_file_names_size) string_table_symbol_names_size1 n_imported_symbols1 symbol_n1 marked_bool_a;
		{
			string_table_size_of_symbol_names :: LibrarySymbolsList Int Int Int !*{#Bool} -> (!Int,!Int,!Int,!*{#Bool});
			string_table_size_of_symbol_names EmptyLibrarySymbolsList string_table_symbol_names_size0 n_imported_symbols0 symbol_n marked_bool_a
				= (string_table_symbol_names_size0,n_imported_symbols0,symbol_n, marked_bool_a);
			string_table_size_of_symbol_names (LibrarySymbol symbol_name imported_symbols) string_table_symbol_names_size0 n_imported_symbols0 symbol_n marked_bool_a
				| marked_bool_a.[symbol_n]
					= string_table_size_of_symbol_names imported_symbols (1 + size symbol_name + string_table_symbol_names_size0) (inc n_imported_symbols0) (symbol_n+2) marked_bool_a;
					= string_table_size_of_symbol_names imported_symbols string_table_symbol_names_size0 n_imported_symbols0 (symbol_n+2) marked_bool_a;
		}



store_imported_symbol_addresses2 pef_file state=:{library_list,n_xcoff_symbols}
	= store_imported_symbol_addresses library_list pef_file n_xcoff_symbols state;	
where {
	store_imported_symbol_addresses EmptyLibraryList data_p n_xcoff_symbols state
		= (data_p,state);
	store_imported_symbol_addresses (Library library_name imported_symbols n_symbols libraries) data_p n_xcoff_symbols state
		# error_string
			= createArray 255 ' ';
		# (connection_id,main_address,r)
			= GetSharedLibrary library_name kPowerPCArch kLoadLib error_string;
		| r==0
			# (data_p,state) 
				= store_imported_symbol_addresses_of_library imported_symbols data_p n_xcoff_symbols state;
			= store_imported_symbol_addresses libraries data_p (n_xcoff_symbols+n_symbols) state;
			{
				store_imported_symbol_addresses_of_library EmptyLibrarySymbolsList data_p symbol_n state
					= (data_p,state);
				store_imported_symbol_addresses_of_library (LibrarySymbol symbol_name symbols) data_p symbol_n state
					# (marked_symbol,state)
						= selacc_marked_bool_a symbol_n state;
					| not marked_symbol
						= store_imported_symbol_addresses_of_library symbols data_p (symbol_n+2) state;
						# (symAddr,symClass,r) 
							= FindSymbol connection_id symbol_name;
						| r==0 && symClass == kTVectorCFragSymbol
							#! data_p
								= WriteLong symAddr data_p;
							= store_imported_symbol_addresses_of_library symbols data_p (symbol_n+2) state;
			}	

}	

write_zero_longs_to_file2 :: Int !*a -> !*a | Target2 a;
write_zero_longs_to_file2 n pef_file0
	| n==0
		= pef_file0;
		
		#! pef_file0
			= WriteLong 0 pef_file0;
		= write_zero_longs_to_file2 (dec n) pef_file0;


LinkerFunction :: !Int !*State -> (!Int,!*State);
LinkerFunction i state 
	= abort "LinkerFunction"; //(i,state);


Debugger3 :: !Int !Int !Int !Bool -> Bool;
Debugger3 code_p data_p main_offset b
	= code { 
		pop_b 3
		call	.Debugger
	}

Debugger :: !Bool -> Bool;
Debugger b
	= code {
		call	.Debugger
	}
/*
::	DynamicLinkerState = DynamicLinkerState !Int;

StartProgram :: !Int !Int !Int !*DynamicLinkerState -> (!Int,!*DynamicLinkerState);

*/

StartProgram :: !Int !Int !Int !*State -> (!Int,!*State);
StartProgram function_descriptor state_p linker_p a
	= code {
	.d 1 3 iii
		jmp	StartProgram
		.export LinkerFunction
	.o 1 1 i
	:LinkerFunction
	.d 1 1 i
		jmp LinkerFunction
	
 	}

/*
StartProgram :: !Int !Int !Int !*State -> (!Int,!*State);
StartProgram function_descriptor state_p linker_p a
	= code {
	.d 1 3 iii
		jmp	StartProgram
		.export LinkerFunction
	.o 1 1 i
	:LinkerFunction
	.d 1 1 i
		jmp e_linker_dynamic_sLinkerFunction
	}

*/

address_of_label2 :: !Int !Int !State -> (!Int,!State);
address_of_label2 file_n symbol_n state
	# (first_symbol_n,state)
		= selacc_marked_offset_a file_n state;
	# (marked,state)
		= selacc_marked_bool_a (first_symbol_n+symbol_n) state;
	| not marked 
		= (0,state);
		
		#! (label_symbol,state)
			= sel_symbol file_n symbol_n state;
		| isLabel label_symbol		
			#! module_n
				= getLabel_module_n label_symbol;
			#! offset
				= getLabel_offset label_symbol;
				
			#! (module_symbol,state)
				= sel_symbol file_n module_n state;
			| isModule module_symbol
				#! virtual_label_offset
					= getModule_virtual_label_offset module_symbol;
				#! (first_symbol_n,state) 
					= selacc_marked_offset_a file_n state;
				#! (real_module_offset,state)
					= selacc_module_offset_a (first_symbol_n + module_n) state;
				= (real_module_offset+offset-virtual_label_offset,state);

				= abort "address_of_label2: internal error (isModule)";

		| isModule label_symbol
			#! module_n
				= symbol_n;
			#! module_symbol
				= label_symbol;
				
			#! (first_symbol_n,state) 
				= selacc_marked_offset_a file_n state;
			#! (real_module_offset,state)
				= selacc_module_offset_a (first_symbol_n + module_n) state;
			= (real_module_offset,state);
}



// Test
objects_and_libraries :: (![!String],![!String],!String);
objects_and_libraries 
	= (file_names,library_file_names,executable);
where {
	executable
		= test_prj_clean_system_files +++ (toString path_separator) +++ "a.xcoff"; //"Clean:Desktop Folder:CleanPrograms:a.xcoff";

	file_names :: ![!String];
	file_names = [
		// runtime system
			"Clean:run time system:_startup_noinit.o"
//			stdenv_clean_system_files +++ (toString path_separator) +++ "_startup.o"
		,	stdenv_clean_system_files +++ (toString path_separator) +++ "_system.o"
		,	stdenv_clean_system_files +++ (toString path_separator) +++ "_library.o"
		

		// StdEnv
		,	stdenv_clean_system_files +++ (toString path_separator) +++ "_SystemEnum.o"
		,	stdenv_clean_system_files +++ (toString path_separator) +++ "StdInt.o"
		,	stdenv_clean_system_files +++ (toString path_separator) +++ "StdChar.o"
		,	stdenv_clean_system_files +++ (toString path_separator) +++ "StdMisc.o"
/*
		, 	stdenv_clean_system_files +++ (toString path_separator) +++ "_SystemArray.o"
		,	stdenv_clean_system_files +++ (toString path_separator) +++ "StdArray.o"
		,	stdenv_clean_system_files +++ (toString path_separator) +++ "StdBool.o"
		,	stdenv_clean_system_files +++ (toString path_separator) +++ "StdChar.o"

		,	stdenv_clean_system_files +++ (toString path_separator) +++ "StdCharList.o"
		,	stdenv_clean_system_files +++ (toString path_separator) +++ "StdClass.o"
		,	stdenv_clean_system_files +++ (toString path_separator) +++ "StdEnum.o"
//		,	stdenv_clean_system_files +++ (toString path_separator) +++ "StdEnv.o"
		,	stdenv_clean_system_files +++ (toString path_separator) +++ "StdFile.o"
		,	stdenv_clean_system_files +++ (toString path_separator) +++ "StdFunc.o"

		,	stdenv_clean_system_files +++ (toString path_separator) +++ "StdList.o"

		,	stdenv_clean_system_files +++ (toString path_separator) +++ "StdOrdList.o"
		,	stdenv_clean_system_files +++ (toString path_separator) +++ "StdOverloaded.o"
		,	stdenv_clean_system_files +++ (toString path_separator) +++ "StdReal.o"
		,	stdenv_clean_system_files +++ (toString path_separator) +++ "StdString.o"
		,	stdenv_clean_system_files +++ (toString path_separator) +++ "StdTuple.o"
*/


		// project
		//,	test_prj +++ (toString path_separator) +++ "test.o"
		,	test_prj_clean_system_files +++ (toString path_separator) +++ "sieve.o"

//		,	test_prj_clean_system_files +++ (toString path_separator) +++ "test.o"


//		,   test_prj +++ (toString path_separator) +++ "loop.o"
//		,	"Clean:MAC Backup 3:Linker John (orginineel):l.o"
		];
		
	library_file_names :: ![!String];
	library_file_names = [
			stdenv_clean_system_files +++ (toString path_separator) +++ "library0"
		,	stdenv_clean_system_files +++ (toString path_separator) +++ "library1"
		,	stdenv_clean_system_files +++ (toString path_separator) +++ "library2"
		];
		
	// Project
	test_prj
		= "Clean:Test project";
	test_prj_clean_system_files
		= test_prj +++ ":Clean System Files";
		
	// StdEnv
	stdenv
		= "Clean:StdEnv"; //"Clean:Clean 1.3.3(beta23):StdEnv";   // "Clean:StdEnv";
	stdenv_clean_system_files 
		= stdenv +++ ":Clean System Files";
}

// InitialLink2; macOs dummy
generate_options_file :: !*DLClientState !*DLServerState !*Files -> *(*(!String,*DLClientState,*DLServerState),*Files);
generate_options_file dl_client_state s files
	= (("",dl_client_state,s),files);

