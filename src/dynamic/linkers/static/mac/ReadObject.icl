implementation module ReadObject;

import SymbolTable, ExtString, SortSymbols;

from ConvertMWObject import read_mw_object_files;
import xcoff;
import ExtFile;
import DebugUtilities;

is_nil [] = True;
is_nil _ = False;

not_nil [] = False;
not_nil _ = True;

empty_section_string :: .String;
empty_section_string = createArray 0 ' ';



read_string_table :: *File -> (!Bool,!String,!*File);
read_string_table file0
	| not ok
//			= error file1;
		= (True,"",file1);
	| string_table_size==0
		= (True,"",file1);
	| string_table_size<4
		= error file1;
	| not (size string_table_string==string_table_size2)
		= error file2;
		= (True,string_table_string,file2);
	{}{
		error file=(False,"",file);
		(string_table_string,file2)=freads file1 string_table_size2;
		string_table_size2=string_table_size-4;
		(ok,string_table_size,file1)=freadi file0;
	}

read_symbols :: Int *File -> (!Bool,!String,!String,!*File);
read_symbols n_symbols file0
	# symbol_table_size=n_symbols*SIZE_OF_SYMBOL;
	  (symbol_table_string,file1)=freads file0 symbol_table_size;
	| not (size symbol_table_string==symbol_table_size)
		= (False,"","",file1);
		= (ok,symbol_table_string,string_table,file2);
		{
			(ok,string_table,file2)=read_string_table file1;
		}

read_symbol_table :: !Int !Int !*File -> (!Bool,!String,!String,!*File);
read_symbol_table symbol_table_offset n_symbols file0
	| not fseek_ok
		= error file1;
		= read_symbols n_symbols file1;
	{}{
		(fseek_ok,file1)=fseek file0 symbol_table_offset FSeekSet;
		error file=(False,"","",file);
	}

read_other_section_headers :: Int *File -> (!Bool,!*File);
read_other_section_headers n_sections file0
	| n_sections==2
		= (True,file0);
	| not (size header_string==SIZE_OF_SECTION_HEADER)
		= (False,file1);
		= read_other_section_headers (dec n_sections) file1;
	{}{
		(header_string,file1) = freads file0 SIZE_OF_SECTION_HEADER;
	}

read_xcoff_text_or_data_section_header :: String *File -> (!Bool,!Int,!Int,!Int,!Int,!Int,!*File);
read_xcoff_text_or_data_section_header section_name file0
	| (size header_string==SIZE_OF_SECTION_HEADER && header_string % (0,4)==section_name && (header_string CHAR 5)=='\0')
		= (True,s_relptr,s_nreloc,s_scnptr,s_size,s_vaddr,file1);{
			s_vaddr=header_string LONG 12;
			s_size=header_string LONG 16;
			s_scnptr=header_string LONG 20;
			s_relptr=header_string LONG 24;
			s_nreloc=header_string WORD 32;
		}
		= (False,0,0,0,0,0,file1);
	{}{
		(header_string,file1) = freads file0 SIZE_OF_SECTION_HEADER;
	}
	
parse_xcoff_header :: String *File -> (!Bool,!Int,!Int,!Int,!*File);
parse_xcoff_header header_string file
	# f_nscns=header_string WORD 2;
	| not (header_string WORD 0==0x01DF && f_nscns>=2)
		= error file;
	# f_symptr=header_string LONG 8;
	  f_nsyms=header_string LONG 12;
	  f_opthdr=header_string WORD 16;
	| f_opthdr==0
		= (True,f_nscns,f_symptr,f_nsyms,file);
		# (fseek_ok,file)=fseek file f_opthdr FSeekCur;
		| fseek_ok
			= (True,f_nscns,f_symptr,f_nsyms,file)
			= (error file);
	{}{		
		error file = (False,0,0,0,file);
	}

read_relocations offset n_relocations file0
	| n_relocations==0
		= (True,"",file0)
	| not fseek_ok	
		= (False,"",file1);
		= (size relocation_string==relocation_size,relocation_string,file2);
	{}{
		(relocation_string,file2) = freads file1 relocation_size;
		relocation_size=n_relocations * SIZE_OF_RELOCATION;
		(fseek_ok,file1)=fseek file0 offset FSeekSet;
	}

read_text_section :: Bool Int Int *File -> (!Bool,!*String,!*File);
read_text_section one_pass_link offset section_size file0
	| one_pass_link && section_size > 2048
		= (True,empty_section_string,file0);
		= read_section one_pass_link offset section_size file0;

read_section :: Bool Int Int *File -> (!Bool,!*String,!*File);
read_section one_pass_link offset section_size file0
	| not one_pass_link || section_size==0
		= (True,empty_section_string,file0)
	| not fseek_ok
		= (False,empty_section_string,file1);
	| size section_string==section_size
		= (True,section_string,file2);
		= (False,section_string,file2);
	{}{
		(section_string,file2) = freads file1 section_size;
		(fseek_ok,file1)=fseek file0 offset FSeekSet;
	}

open_file_and_read_xcoff_header :: !String !*Files -> (!Bool,!String,!*File,!*Files);
open_file_and_read_xcoff_header file_name files
	# (open_ok,file,files) = fopen file_name (FReadData + 0) files;
	| not open_ok
		= error ("Cannot open file \""+++file_name+++"\"") file files;
	# (header_string,file) = freads file SIZE_OF_HEADER;
	| size header_string<>SIZE_OF_HEADER
		= error ("Cannot read header of file \""+++file_name+++"\"") file files;
		= (True,header_string,file,files);
	{}{
		error error_message file files = (False,error_message,file,files);
	}
	
/*
read_xcoff_files :: ![String] *NamesTable Bool !*Files !Int -> (![String],!Sections,!Int,![*Xcoff],!*NamesTable,!*Files);
read_xcoff_files file_names names_table0 one_pass_link files file_n
	= case file_names of {
		[]
			-> ([],EndSections,file_n,[],names_table0,files);
		[file_name:file_names]
			# (ok,xcoff_header_or_error_message,file,files) = open_file_and_read_xcoff_header file_name files;
			| not ok
				-> ([xcoff_header_or_error_message],EndSections,file_n,[],names_table0,files);
			| xcoff_header_or_error_message WORD 0==0x01DF
				# (error,text_section,data_section,xcoff_file0,names_table1,files) = read_xcoff_file file_name names_table0 one_pass_link xcoff_header_or_error_message file files file_n;
				| is_nil error
					#  xcoff_file1 = store_xcoff_relocations_in_modules (sort_modules xcoff_file0);
					   (error2,sections,file_n1,xcoff_files,symbol_table2,files) = read_xcoff_files file_names names_table1 one_pass_link files (inc file_n);
					-> (error2,Sections text_section data_section sections,file_n1,[xcoff_file1:xcoff_files],symbol_table2,files);
					-> (error,EndSections,file_n,[],names_table1,files);
			| xcoff_header_or_error_message LONG 0==0x4D574F42
				# (error,mw_sections2,mw_xcoff_files,file_n2,names_table1,files) = read_mw_object_files file_name file_n names_table0 xcoff_header_or_error_message file files;
				| is_nil error
					#  (error2,sections,file_n1,xcoff_files,symbol_table2,files) 
						= read_xcoff_files file_names names_table1 one_pass_link files file_n2;



					-> (error2,append_sections mw_sections2 sections,file_n1,mw_xcoff_files++xcoff_files,symbol_table2,files);
					{
						append_sections EndSections sections = sections;
						append_sections (Sections a b r) sections = Sections a b (append_sections r sections);
					}
					-> (error,EndSections,file_n,[],names_table1,files);
				-> (["Not an xcoff file: \""+++file_name+++"\""],EndSections,file_n,[],names_table0,files);
	}
	
*/

/*
	one_pass dynamic linking is not yet supported
*/
ReadXcoffM :: !String !Int !NamesTable !Bool !Int !*Files -> ((![String],![*Xcoff],!NamesTable),!Files);  
ReadXcoffM file_name object_file_offset names_table one_pass_link file_n files
	#! (errors,_,_,xcoffs,names_table,files)
		= ReadXcoff file_name 0 names_table one_pass_link files file_n;
	= ((errors,xcoffs,names_table),files);


/*
	ReadXcoff
	
	Important:
			

*/
ReadXcoff :: !String !Int !NamesTable !Bool !*Files !Int -> (![String],!*String,!*String,![*Xcoff],!NamesTable,!Files);  
ReadXcoff file_name /*object_file_offset*/ _ names_table one_pass_link files file_n
	# (ok,xcoff_header_or_error_message,file,files) 
		= open_file_and_read_xcoff_header file_name files;
	| not ok
		= error xcoff_header_or_error_message  names_table file files;

	| xcoff_header_or_error_message WORD 0==0x01DF
		# (error,text_section,data_section,xcoff_file,names_table,files) 
			= read_xcoff_file file_name names_table one_pass_link xcoff_header_or_error_message file files file_n;
		# xcoff_file
			= store_xcoff_relocations_in_modules (sort_modules xcoff_file);
		= (error,text_section,data_section,[xcoff_file],names_table,files);
	
	| xcoff_header_or_error_message LONG 0==0x4D574F42
		#! (error,mw_sections2,mw_xcoff_files,_,names_table,files)
			 = read_mw_object_files file_name file_n names_table xcoff_header_or_error_message file files;
		= (error,{},{},mw_xcoff_files,names_table,files);

		= abort "ReadXcoff: unknown format";	
where
{
	error :: String !NamesTable !*File !*Files -> (![String],!*String,!*String,![*Xcoff],!NamesTable,!Files);
	error error_string names_table file files
		= ([error_string],empty_section_string,empty_section_string,[],names_table, snd (fclose file files) );
}
		
	
read_xcoff_file :: !String *NamesTable Bool !String !*File !*Files Int -> (![String],!*String,!*String,!*Xcoff,!*NamesTable,!*Files);
read_xcoff_file file_name names_table0 one_pass_link header_string file files1 file_n
	# (ok1,n_sections,symbol_table_offset,n_symbols,file) = parse_xcoff_header header_string file;
	| not ok1
		= error ("Not an xcoff file: \""+++file_name+++"\"") file files1;
	#	(ok2,text_relocation_offset,n_text_relocations,text_section_offset,text_section_size,text_v_address,file)
			= read_xcoff_text_or_data_section_header ".text" file;
	| not ok2
		= error "Error in text section header" file files1;
	#	(ok3,data_relocation_offset,n_data_relocations,data_section_offset,data_section_size,data_v_address,file)
			= read_xcoff_text_or_data_section_header ".data" file;
	| not ok3
		= error "Error in data section header" file files1;
	#	(ok4,file)
			= read_other_section_headers n_sections file;
	| not ok4
		= error "Error in section header" file files1;
	#	(ok5,text_section,file)
			= read_text_section one_pass_link text_section_offset text_section_size file;
	| not ok5
		= error "Error in text section" file files1;
	#	(ok6,data_section,file)
			= read_section one_pass_link data_section_offset data_section_size file;
	| not ok6
		= error "Error in data section" file files1;
	#	(ok7,text_relocations,file)
			= read_relocations text_relocation_offset n_text_relocations file;
	| not ok7
		= error "Error in text relocations" file files1;
	#	(ok8,data_relocations,file)
			= read_relocations data_relocation_offset n_data_relocations file;
	| not ok8
		= error "Error in data relocations" file files1;
	#	(ok9,symbol_table_string,string_table,file)
			= read_symbol_table symbol_table_offset n_symbols file;
	| not ok9
		= error ("Error in symbol table "+++file_name) file files1;
		= ([],text_section,data_section,xcoff_file,names_table1,close_file file files1);
		{
// 
			xcoff_file={module_name= extract_module_name file_name,header=header,symbol_table=symbol_table0,n_symbols=n_symbols_2,
						text_relocations=text_relocations,data_relocations=data_relocations,
						n_text_relocations=n_text_relocations,n_data_relocations=n_data_relocations};
			header={file_name=file_name,text_section_offset=text_section_offset,data_section_offset=data_section_offset,
					text_section_size=text_section_size,data_section_size=data_section_size,
					text_v_address=text_v_address,data_v_address=data_v_address};
			(names_table1,symbol_table0)
					=define_symbols n_symbols_2 symbol_table_string string_table names_table0 file_n;
			n_symbols_2						= (inc n_symbols) >> 1;
		}
	{	
		close_file file files1 = files2;
		{
			(_,files2)=fclose file files1;
		}

		error :: String !*File *Files -> (![String],!*String,!*String,!*Xcoff,!*NamesTable,!*Files);
		error error_string file files1
			= ([error_string +++ "of object file '" +++ file_name +++ "'"],empty_section_string,empty_section_string,empty_xcoff,names_table0,close_file file files1);
	}

read_xcoff_files :: ![String] *NamesTable Bool !*Files !Int -> (![String],!Sections,!Int,![*Xcoff],!*NamesTable,!*Files);
read_xcoff_files file_names names_table0 one_pass_link files file_n
	= case file_names of {
		[]
			-> ([],EndSections,file_n,[],names_table0,files);
		[file_name:file_names]
			# (ok,xcoff_header_or_error_message,file,files) = open_file_and_read_xcoff_header file_name files;
			| not ok
				-> ([xcoff_header_or_error_message],EndSections,file_n,[],names_table0,files);
			| xcoff_header_or_error_message WORD 0==0x01DF
				# (error,text_section,data_section,xcoff_file0,names_table1,files) = read_xcoff_file file_name names_table0 one_pass_link xcoff_header_or_error_message file files file_n;
				| is_nil error
					#  xcoff_file1 = store_xcoff_relocations_in_modules (sort_modules xcoff_file0);
					   (error2,sections,file_n1,xcoff_files,symbol_table2,files) = read_xcoff_files file_names names_table1 one_pass_link files (inc file_n);
					-> (error2,Sections text_section data_section sections,file_n1,[xcoff_file1:xcoff_files],symbol_table2,files);
					-> (error,EndSections,file_n,[],names_table1,files);
			| xcoff_header_or_error_message LONG 0==0x4D574F42
				# (error,mw_sections2,mw_xcoff_files,file_n2,names_table1,files) = read_mw_object_files file_name file_n names_table0 xcoff_header_or_error_message file files;
				| is_nil error
					#  (error2,sections,file_n1,xcoff_files,symbol_table2,files) = read_xcoff_files file_names names_table1 one_pass_link files file_n2;
					-> (error2,append_sections mw_sections2 sections,file_n1,mw_xcoff_files++xcoff_files,symbol_table2,files);
					{
						append_sections EndSections sections = sections;
						append_sections (Sections a b r) sections = Sections a b (append_sections r sections);
					}
					-> (error,EndSections,file_n,[],names_table1,files);
				-> (["Not an xcoff file: \""+++file_name+++"\""],EndSections,file_n,[],names_table0,files);
	}
	
store_xcoff_relocations_in_modules :: !*Xcoff -> !.Xcoff;
store_xcoff_relocations_in_modules xcoff=:{
		symbol_table=symbol_table=:{text_symbols,data_symbols,symbols=symbol_array0}
		,text_relocations,data_relocations,n_text_relocations,n_data_relocations}
	= { xcoff & symbol_table
			= { symbol_table &
					symbols	= store_relocations_in_modules 0 n_data_relocations data_relocations data_symbols
								(store_relocations_in_modules 0 n_text_relocations text_relocations text_symbols symbol_array0)
			  } 
	  };
	{
//		{symbol_table,text_relocations,data_relocations,n_text_relocations,n_data_relocations} = xcoff;
//		{text_symbols,data_symbols,symbols=symbol_array0} = symbol_table;
		
		store_relocations_in_modules :: Int Int String SymbolIndexList *SymbolArray -> *SymbolArray;
		store_relocations_in_modules relocation_n n_relocations relocations symbols0 symbol_array0
			| relocation_n==n_relocations
				= symbol_array0;
				= store_relocations_in_modules next_relocation_n n_relocations relocations symbols1 symbol_array1;
				{
					(next_relocation_n,symbols1,symbol_array1)=store_relocation_in_module symbols0 symbol_array0;
					relocation_offset=relocations LONG (relocation_n*SIZE_OF_RELOCATION);

					store_relocation_in_module :: SymbolIndexList *SymbolArray -> (!Int,!SymbolIndexList,!*SymbolArray);
//					store_relocation_in_module :: _ _  -> (!_,!_,!.SymbolArray);
					store_relocation_in_module symbols=:(SymbolIndex index next_symbols) symbol_array=:{[index]=symbol}
						= case symbol of {
							Module {section_n=a,module_offset,length=module_length,align=alignment}
								| relocation_offset>=module_offset && relocation_offset<module_offset+module_length
									-> (relocation_n_for_next_function,symbols,{symbol_array & [index]=module_with_relocation});
									{
										module_with_relocation= Module {section_n=a,module_offset=module_offset,length=module_length,
																		first_relocation_n=relocation_n,end_relocation_n=relocation_n_for_next_function,
																		align=alignment};
										
										relocation_n_for_next_function = add_relocations_to_function (inc relocation_n);
										
										add_relocations_to_function relocation_n
											| relocation_n==n_relocations
												= relocation_n;
											| next_relocation_offset>=module_offset && next_relocation_offset<module_offset+module_length
												= add_relocations_to_function (inc relocation_n);
												= relocation_n;
											{}{
												next_relocation_offset=relocations LONG (relocation_n*SIZE_OF_RELOCATION);
											}
										
									}
									-> store_relocation_in_module next_symbols symbol_array;
						}
				}
	}
	
import ExtInt;
 
define_symbols :: Int String String *NamesTable Int -> (!*NamesTable,!*SymbolTable);
define_symbols n_symbols symbol_table_string string_table names_table file_n
	= define_symbols_lp 0 names_table empty_symbol_table;
	{

		empty_symbol_table = {	text_symbols=EmptySymbolIndex,
								data_symbols=EmptySymbolIndex,
								toc_symbols=EmptySymbolIndex,
								bss_symbols=EmptySymbolIndex,
								toc0_symbol=EmptySymbolIndex,
								imported_symbols=EmptySymbolIndex,
								symbols=createArray n_symbols EmptySymbol
							 };

		define_symbols_lp :: !Int !*NamesTable !*SymbolTable -> (!*NamesTable,!*SymbolTable);
		define_symbols_lp symbol_n names_table0 symbol_table0
		| offset==size symbol_table_string
			= (names_table0,symbol_table0);
			= case (symbol_table_string BYTE (offset+16)) of {
					C_HIDEXT
						-> define_symbols_lp (symbol_n+1+n_numaux) names_table0 (new_symbol_table n_value);
					C_EXT
						| n_scnum==N_UNDEF
							| x_sm_typ_t==XTY_ER
								-> define_symbols_lp (symbol_n+1+n_numaux) names_table0 symbol_table1;
								{
									symbol_table1 = {symbol_table0 &
														symbols.[symbol_n_2] = ImportLabel name_of_symbol,
//														symbols = {symbol_table0.symbols & [symbol_n_2] = ImportLabel name_of_symbol},
														imported_symbols=SymbolIndex symbol_n_2 symbol_table0.imported_symbols
													};
								}
								-> abort "error in EXT symbol";
							-> define_symbols_lp (symbol_n+1+n_numaux) names_table1 (new_symbol_table n_value);
							{
								names_table1= /*case (name_of_symbol == "qd") of {
													False
														-> */insert_symbol_in_symbol_table name_of_symbol symbol_n_2 file_n names_table0;
														/*
													True
														#! s 
															= ("define_symbols: (case) 391 gevonden: " +++ name_of_symbol 
															+++ "symbol_n=" +++ (toString symbol_n) +++ "\n"
															+++ "calculated symbol_n_2=" +++ toString ((inc symbol_n) >> 1) +++ "actual symbol_n_2=" +++ toString  symbol_n_2 );
															
														-> abort s;
														
												}; */
							}
					C_FILE
						-> define_symbols_lp (symbol_n+1+n_numaux) names_table0 symbol_table0;
					C_STAT
						-> define_symbols_lp (symbol_n+1+n_numaux) names_table0 symbol_table0;
				}
			{
				new_symbol_table :: Int -> .SymbolTable;
				new_symbol_table n_value
					| x_sm_typ_t==XTY_SD
						= symbol_table_with_csect;
					| x_sm_typ_t==XTY_LD
						= symbol_table_with_label;
					| x_sm_typ_t==XTY_CM
						= symbol_table_with_common n_value;
				
				symbol_table_with_csect
					| n_scnum==TEXT_SECTION && (x_smclass==XMC_PR || x_smclass==XMC_GL)
						= {symbol_table0 &
							symbols.[symbol_n_2]= Module {section_n=TEXT_SECTION,
													module_offset=n_value,length=x_scnlen,
													first_relocation_n=0,end_relocation_n=0,
													align=x_sm_align},
							text_symbols= SymbolIndex symbol_n_2 symbol_table0.text_symbols
						  };
					| n_scnum==DATA_SECTION
						=	if (x_smclass==XMC_RW || x_smclass==XMC_RO)
								{ symbol_table0 &
									symbols.[symbol_n_2]= Module {section_n=DATA_SECTION,
															module_offset=n_value,length=x_scnlen,
															first_relocation_n=0,end_relocation_n=0,
															align=x_sm_align},
									data_symbols= SymbolIndex symbol_n_2 symbol_table0.data_symbols
					 			}
					 		(if (x_smclass==XMC_TC || x_smclass==XMC_DS)
					 			{ symbol_table0 &
									symbols.[symbol_n_2]= Module {section_n=TOC_SECTION,
															module_offset=n_value,length=x_scnlen,
															first_relocation_n=0,end_relocation_n=0,
															align=x_sm_align},
									data_symbols= SymbolIndex symbol_n_2 symbol_table0.data_symbols
					 			}
					 			
					 		// TOC Anchor
					 		(if (x_smclass==XMC_TC0)
					 			{ symbol_table0 &
									symbols.[symbol_n_2]= Module {section_n=TOC_SECTION,
															module_offset=n_value,length=x_scnlen,
															first_relocation_n=0,end_relocation_n=0,
															align=x_sm_align},
									toc0_symbol	= SymbolIndex symbol_n_2 symbol_table0.toc0_symbol
					 			}
					 			(abort "Error in symbol table")
					 		));

				symbol_table_with_label
					| n_scnum==TEXT_SECTION && x_smclass==XMC_PR
						= {symbol_table0 & symbols.[symbol_n_2]=Label {label_section_n=TEXT_SECTION,label_offset=n_value,label_module_n=x_scnlen_2}};
					| n_scnum==DATA_SECTION
						= case (x_smclass) of {
							XMC_RW
								-> {symbol_table0 & symbols.[symbol_n_2]=Label {label_section_n=DATA_SECTION,label_offset=n_value,label_module_n=x_scnlen_2}};
							XMC_TC
								-> symbol_table1;
							XMC_DS
								-> symbol_table1;
							XMC_TC0
								-> symbol_table1;
						}
						{
							symbol_table1
								=> {symbol_table0 & symbols.[symbol_n_2]=Label {label_section_n=TOC_SECTION,label_offset=n_value,label_module_n=x_scnlen_2}};
						};
					{
						x_scnlen_2 = (inc x_scnlen) >> 1;
					}
				
				symbol_table_with_common n_value
/*					| name_of_symbol == "qd"
						#! s
							= "\nn_value=" +++ (hex_int n_value) +++
							  "\nlength=" +++ (hex_int x_scnlen) +++
							  "\nx_sm_align=" +++ (hex_int x_sm_align) +++
							  "\nn_sclass=" +++ (hex_int (symbol_table_string BYTE (offset+16)));
							 
						= abort ("symbol_table_with_common: " +++ s );
*/

					| n_scnum==BSS_SECTION && (x_smclass==XMC_BS /* ADDED: */ || x_smclass==XMC_RW)
						= {symbol_table0 & 
							symbols.[symbol_n_2]= Module {section_n=BSS_SECTION,
													module_offset=n_value,length=x_scnlen,
													first_relocation_n=0,end_relocation_n=0,
													align=x_sm_align},
							bss_symbols= SymbolIndex symbol_n_2 symbol_table0.bss_symbols
						  };
					| n_scnum==BSS_SECTION
						= abort ("BSS_SECTION; x_smclass=" +++ toString x_smclass +++ "x_smtyp=" +++ toString x_sm_typ_t) ;
						  
						= abort name_of_symbol;
						  
				name_of_symbol :: {#Char}; // to help the typechecker
				name_of_symbol
					| first_chars==0
						= string_table % (string_table_offset,dec (first_zero_char_offset_or_max string_table string_table_offset (size string_table)));
						{
							string_table_offset = (symbol_table_string LONG (offset+4))-4;
						}
						= symbol_table_string % (offset,dec (first_zero_char_offset_or_max symbol_table_string offset (offset+8)));
					{}{
						first_chars = symbol_table_string LONG offset;
						
						first_zero_char_offset_or_max string offset max
							| offset>=max || string CHAR offset=='\0'
								= offset;
								= first_zero_char_offset_or_max string (offset+1) max;
					}

				x_sm_typ_t=x_smtyp bitand 7;
				x_sm_align=x_smtyp >> 3;
				
				x_scnlen=symbol_table_string LONG last_aux_offset;
				x_smtyp=symbol_table_string BYTE (last_aux_offset+10);
				x_smclass=symbol_table_string BYTE (last_aux_offset+11);

				last_aux_offset=offset+SIZE_OF_SYMBOL*n_numaux;
				
				n_value=symbol_table_string LONG (offset+8);
				n_scnum=symbol_table_string WORD (offset+12);
				n_numaux=symbol_table_string BYTE (offset+17);
			}
		{
			symbol_n_2 = FB (/*symbol_n == 391*/ name_of_symbol2 == "qd") 
							("define_symbols: 391 gevonden: " +++ name_of_symbol2 +++ toString ((inc symbol_n) >> 1) +++ " symbol_n:" +++ toString symbol_n ) 
							((inc symbol_n) >> 1);
	
	
			offset=SIZE_OF_SYMBOL*symbol_n;
			
			name_of_symbol2 :: {#Char}; // to help the typechecker
				name_of_symbol2
					| first_chars==0
						= string_table % (string_table_offset,dec (first_zero_char_offset_or_max string_table string_table_offset (size string_table)));
						{
							string_table_offset = (symbol_table_string LONG (offset+4))-4;
						}
						= symbol_table_string % (offset,dec (first_zero_char_offset_or_max symbol_table_string offset (offset+8)));
					{}{
						first_chars = symbol_table_string LONG offset;
						
						first_zero_char_offset_or_max string offset max
							| offset>=max || string CHAR offset=='\0'
								= offset;
								= first_zero_char_offset_or_max string (offset+1) max;
					}
		}
	}
	
// should be in lib.icl like its pc counterpart
read_lib_files :: ![String] ![String] !NamesTable !Int ![*Xcoff] !*Files -> (![!String],![*Xcoff],![String],!NamesTable,!Int,!*Files);
read_lib_files [] object_names names_table file_n xcoffs files
	= ([], xcoffs, object_names,  names_table, file_n, files);

