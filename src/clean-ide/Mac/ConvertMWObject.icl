implementation module ConvertMWObject;

import StdClass,StdInt,StdChar,StdBool,StdString,StdArray,StdFile,StdMisc;
from StdList import ++,hd;

import linker2,linker3;

XMC_RO:==1;
XMC_TI:==12;
XMC_TB:==13;
XMC_TD:==16;

HUNK_START:==0x4567;
HUNK_END:==0x4568;
HUNK_SEGMENT:==0x4569;
HUNK_LOCAL_CODE:==0x456a;
HUNK_GLOBAL_CODE:==0x456b;
HUNK_LOCAL_UDATA:==0x456c;
HUNK_GLOBAL_UDATA:==0x456d;
HUNK_LOCAL_IDATA:==0x456e;
HUNK_GLOBAL_IDATA:==0x456f;
HUNK_GLOBAL_ENTRY:==0x4570;
HUNK_LOCAL_ENTRY:==0x4571;
HUNK_XREF_16BIT:==0x4573;
HUNK_XREF_16BIT_IL:==0x4574;
HUNK_XREF_24BIT:==0x4575;
HUNK_XREF_32BIT:==0x4576;
HUNK_XREF_32BIT_REL:==0x4577;

read_file_data_records n_object_files file
	| n_object_files==0
		= ([],file);
	# (_,moddate,file)=freadi file;
	  (_,filename,file)=freadi file;
	  (_,fullpathname,file)=freadi file;
	  (_,objectstart,file)=freadi file;
	  (_,objectsize,file)=freadi file;
	  (file_error,file) = ferror file;
	| file_error
		= abort "Error in file data records";
		# (rest,file) = read_file_data_records (n_object_files-1) file;
		= ([(objectstart,objectsize):rest],file);

read_object_header object_file_offset object_file_size file
	# (seek_ok,file)=fseek file object_file_offset FSeekSet;
	| not seek_ok
		= abort "Seek failed";
	# (_,magic_word,file)=freadi file;
	  (_,version_and_flags,file)=freadi file;
	  (_,obj_size,file)=freadi file;
	  (_,name_table_offset,file)=freadi file;
	  (_,nametable_names,file)=freadi file;
	  (_,symtable_offset,file)=freadi file;
	  (_,symtable_size,file)=freadi file;
	  (_,code_size,file)=freadi file;
	  (_,udata_size,file)=freadi file;
	  (_,idata_size,file)=freadi file;
	  (_,toc_size,file)=freadi file;
	  (_,old_def_version,file)=freadi file;
	  (_,old_imp_version,file)=freadi file;
	  (_,current_version,file)=freadi file;
	  (seek_ok,file)=fseek file 52 FSeekCur;
	  (file_error,file) = ferror file;
	| not seek_ok || file_error || magic_word<>0x504F5752
		= abort "Error in object header";
		= (name_table_offset,nametable_names,obj_size,file);

:: MWRelocation = {
		relocation_kind		::Int,
		relocation_class	::Int,
		relocation_name_id	::Int,
		relocation_offset	::Int
	};

:: FileContents = {
		code_offset			:: !Int,
		code_list			:: [String],
		data_offset			:: !Int,
		data_list			:: [String],
		text_relocation_n	:: !Int,
		text_relocations	:: [MWRelocation],
		data_relocation_n	:: !Int,
		data_relocations	:: [MWRelocation],
		local_symbols		:: !.{#Bool},
		symbol_table		:: !.SymbolTable
	};

read_object_data_hunks file_contents file
	# (read_ok,i,file)=freadi file;
	| not read_ok
		= abort "Error in object data";
		= read_object_data_next_hunk i file_contents file;

read_object_data_next_hunk :: !Int *FileContents !*File -> (!.FileContents,!.File);
read_object_data_next_hunk i file_contents file
	# hunk_code=i>>16;
	| hunk_code==HUNK_END
		= (file_contents,file);
	| hunk_code==HUNK_LOCAL_CODE
		# (_,name_id,file)=freadi file;
		= read_rest_of_code_hunk name_id i {file_contents & local_symbols={file_contents.local_symbols & [name_id]=True}} file;
	| hunk_code==HUNK_GLOBAL_CODE
		# (_,name_id,file)=freadi file;
		= read_rest_of_code_hunk name_id i file_contents file;
	| hunk_code==HUNK_LOCAL_IDATA
		# (_,name_id,file)=freadi file;
		  sm_class=(i>>8) bitand 255;
		| sm_class<>XMC_TC
			= read_rest_of_data_hunk name_id i {file_contents & local_symbols={file_contents.local_symbols & [name_id]=True}} file;
			= read_rest_of_data_hunk name_id i file_contents file;	
	| hunk_code==HUNK_GLOBAL_IDATA
		# (_,name_id,file)=freadi file;
		= read_rest_of_data_hunk name_id i file_contents file;	
	| hunk_code==HUNK_LOCAL_UDATA
		# (_,name_id,file)=freadi file;
		= read_rest_of_bss_hunk name_id i {file_contents & local_symbols={file_contents.local_symbols & [name_id]=True}} file;
	| hunk_code==HUNK_GLOBAL_UDATA
		# (_,name_id,file)=freadi file;
		= read_rest_of_bss_hunk name_id i file_contents file;
	| hunk_code==HUNK_SEGMENT
		# (_,name_id,file)=freadi file;
		= read_object_data_hunks {file_contents & local_symbols={file_contents.local_symbols & [name_id]=True}} file;

	read_rest_of_code_hunk :: Int !Int !*FileContents !*File -> (!.FileContents,!.File);
	read_rest_of_code_hunk name_id i file_contents file
		# (_,code_size,file)=freadi file;
		  (_,sym_offset,file)=freadi file;
		  (_,sym_decl_offset,file)=freadi file;
		  (code_string,file)=freads file code_size;
		| size code_string==code_size
			# sm_class=(i>>8)bitand 255;
			| sm_class==XMC_PR || sm_class==XMC_GL
				# (read_ok,i,file)=freadi file;
				| read_ok
					# (i,file_contents,file) = read_code_entries name_id i file_contents file;
					  code_module_offset=file_contents.code_offset;
					  first_relocation_n = file_contents.text_relocation_n;
					  (i,end_relocation_n,relocations,file)=read_object_hunk_relocations i first_relocation_n code_module_offset file_contents.FileContents.text_relocations file;
					  (text_symbols,file_contents) = file_contents!FileContents.symbol_table.text_symbols;
					  file_contents = {FileContents | file_contents &	code_list=[code_string:file_contents.code_list],
																		code_offset=code_module_offset+code_size,
																		text_relocation_n=end_relocation_n, text_relocations=relocations,
					  													symbol_table.symbols.[name_id<<1]=
																	 		Module {section_n=TEXT_SECTION,module_offset=code_module_offset,
															 				length=code_size, first_relocation_n=first_relocation_n,
														 					end_relocation_n=end_relocation_n, align=2},
																		symbol_table.text_symbols=SymbolIndex (name_id<<1) text_symbols};
					= read_object_data_next_hunk i file_contents file;
					= error;
				= error;
		{}{
			error=>abort "Error in object file";
		}

	read_code_entries :: !Int !Int *FileContents !*File -> (!Int,!.FileContents,!.File);
	read_code_entries module_name_id i file_contents file
		# hunk_code=i>>16;
		| hunk_code==HUNK_GLOBAL_ENTRY
			# (_,name_id,file)=freadi file;
			  (_,offset,file)=freadi file;
			  (_,_,file)=freadi file;
			  (_,_,file)=freadi file;
			  (text_symbols,file_contents) = file_contents!FileContents.symbol_table.text_symbols;
			  file_contents = {FileContents | file_contents & symbol_table.symbols.[name_id<<1]=
		 													Label {label_section_n=TEXT_SECTION,label_offset=offset,label_module_n=module_name_id<<1}
// removed 4-12-1997										,symbol_table.text_symbols=SymbolIndex (name_id<<1) text_symbols
		 													};
			  (_,i,file)=freadi file;
			= read_code_entries module_name_id i file_contents file;
			= (i,file_contents,file);

	read_rest_of_data_hunk :: Int Int !*FileContents !*File -> (!.FileContents,!.File);
	read_rest_of_data_hunk name_id old_i file_contents file
		# (_,data_size,file)=freadi file;
		  (_,sym_offset,file)=freadi file;
		  (_,sym_decl_offset,file)=freadi file;
		  (data_string,file)=freads file data_size;
		| size data_string<>data_size
			= abort "Error in object data";
			# file = seek;
				with {
					seek
						| (data_size bitand 3==0)
							= file;
							# (seek_ok,file) = fseek file (4-(data_size bitand 3)) FSeekCur;
							| not seek_ok
								= abort "Seek failed";
								= file;
				}
			  sm_class=(old_i>>8) bitand 255;
			| sm_class==XMC_TI || sm_class==XMC_TB
				# (i,file) = skip_object_hunk_relocations file;
				= read_object_data_next_hunk i file_contents file;
			# first_relocation_n = file_contents.data_relocation_n;
			  data_module_offset=file_contents.data_offset;
			  (_,i,file)=freadi file;
			  (i,end_relocation_n,relocations,file)=read_object_hunk_relocations i first_relocation_n data_module_offset file_contents.FileContents.data_relocations file;
			#! file_contents = {file_contents & data_list=[data_string:file_contents.data_list],
												data_offset=data_module_offset+data_size,
												data_relocation_n=end_relocation_n, data_relocations=relocations};
			| sm_class==XMC_RW || sm_class==XMC_RO
				# file_contents = {FileContents | file_contents & symbol_table.symbols.[name_id<<1]=
												 				Module {section_n=DATA_SECTION, module_offset=data_module_offset,
												 						length=data_size, first_relocation_n=first_relocation_n,
												 						end_relocation_n=end_relocation_n, align=2}};
				  (data_symbols,file_contents) = file_contents!FileContents.symbol_table.data_symbols;
				  file_contents = {FileContents | file_contents & symbol_table.data_symbols=SymbolIndex (name_id<<1) data_symbols};
				= read_object_data_next_hunk i file_contents file;
			| sm_class==XMC_TC
				# name_id2=1+(name_id<<1);
				  file_contents = {FileContents | file_contents & symbol_table.symbols.[name_id2]=
												 				Module {section_n=TOC_SECTION, module_offset=data_module_offset,
												 						length=data_size, first_relocation_n=first_relocation_n,
												 						end_relocation_n=end_relocation_n, align=2}};
				  (data_symbols,file_contents) = file_contents!FileContents.symbol_table.data_symbols;
				  file_contents = {FileContents | file_contents & symbol_table.data_symbols=SymbolIndex name_id2 data_symbols};
				= read_object_data_next_hunk i file_contents file;
			| sm_class==XMC_DS || sm_class==XMC_TD
				# file_contents = {FileContents | file_contents & symbol_table.symbols.[name_id<<1]=
												 				Module {section_n=TOC_SECTION, module_offset=data_module_offset,
												 						length=data_size, first_relocation_n=first_relocation_n,
												 						end_relocation_n=end_relocation_n, align=2}};
				  (data_symbols,file_contents) = file_contents!FileContents.symbol_table.data_symbols;
				  file_contents = {FileContents | file_contents & symbol_table.data_symbols=SymbolIndex (name_id<<1) data_symbols};
				= read_object_data_next_hunk i file_contents file;
			| sm_class==XMC_TC0
				# file_contents = {FileContents | file_contents & symbol_table.symbols.[name_id<<1]=
												 				Module {section_n=TOC_SECTION, module_offset=data_module_offset,
												 						length=data_size, first_relocation_n=first_relocation_n,
												 						end_relocation_n=end_relocation_n, align=2}};
				  (toc0_symbol,file_contents) = file_contents!FileContents.symbol_table.toc0_symbol;
				  file_contents = {FileContents | file_contents & symbol_table.toc0_symbol=SymbolIndex (name_id<<1) toc0_symbol};
				= read_object_data_next_hunk i file_contents file;

	read_rest_of_bss_hunk name_id old_i file_contents file
		# (_,size,file)=freadi file;
		  (_,sym_offset,file)=freadi file;
		  (_,sym_decl_offset,file)=freadi file;
		  sm_class=(old_i>>8) bitand 255;
		| sm_class==XMC_RW || sm_class==XMC_RO
			# file_contents = {FileContents | file_contents & symbol_table.symbols.[name_id<<1]=
											 				Module {section_n=BSS_SECTION, module_offset=0,
											 						length=size, first_relocation_n=0,
											 						end_relocation_n=0, align=2}};
			  (bss_symbols,file_contents) = file_contents!FileContents.symbol_table.bss_symbols;
			  file_contents = {FileContents | file_contents & symbol_table.bss_symbols=SymbolIndex (name_id<<1) bss_symbols};
			= read_object_data_hunks file_contents file;
		| sm_class==XMC_TD
			# data_module_offset=file_contents.data_offset;
			  file_contents = {file_contents & data_list=[createArray size '\0':file_contents.data_list],
											   data_offset=data_module_offset+size};
			  file_contents = {FileContents | file_contents & symbol_table.symbols.[name_id<<1]=
											 				Module {section_n=TOC_SECTION, module_offset=data_module_offset,
											 						length=size, first_relocation_n=0,
											 						end_relocation_n=0, align=2}};
			  (data_symbols,file_contents) = file_contents!FileContents.symbol_table.data_symbols;
			  file_contents = {FileContents | file_contents & symbol_table.data_symbols=SymbolIndex (name_id<<1) data_symbols};
			= read_object_data_hunks file_contents file;
			

	read_object_hunk_relocations i old_relocation_n module_offset old_relocations file
		# (i,relocation_n,relocations,file)=read_object_hunk_next_relocation i old_relocation_n module_offset old_relocations file;
		  n_new_relocations=relocation_n-old_relocation_n;
		| n_new_relocations<=1 || relocations_are_sorted relocations n_new_relocations
			= (i,relocation_n,relocations,file);
			# relocations=sort_relocations relocations n_new_relocations;
			= (i,relocation_n,relocations,file);

	relocations_are_sorted [{relocation_offset}:relocations] n_relocations
		= relocations_are_sorted2 relocation_offset relocations (n_relocations-1);
	{
		relocations_are_sorted2 previous_offset relocations 0
			= True;
		relocations_are_sorted2 previous_offset [{relocation_offset}:relocations] n_relocations
			= previous_offset>=relocation_offset && relocations_are_sorted2 relocation_offset relocations (n_relocations-1);
	}

	sort_relocations relocations n_new_relocations
		# (relocations1,relocations2)=split_at n_new_relocations relocations
		= hd (msort (pair relocations1)) ++ relocations2;
	{
		split_at 0 xs = ([],xs);
		split_at n [x:xs] = ([x:xs`],xs``);
		{
			(xs`,xs``) = split_at (n-1) xs;
		}
		
		pair [x1,x2:xs]
			| x1.relocation_offset>=x2.relocation_offset
				= [[x1,x2]:pair xs];
				= [[x2,x1]:pair xs];
		pair x = [x];

		msort [x1,x2:xs] = msort (merge_stage [x1,x2:xs]);
		msort x	= x;

		merge_stage [xs1,xs2:xxs] = [ mlists xs1 xs2 : merge_stage xxs ];
		merge_stage x = x;

		mlists xn=:[x:xs] yn=:[y:ys]
			| x.relocation_offset>=y.relocation_offset
				= [x : mlists xs yn];
				= [y : mlists xn ys];
		mlists [] ys = ys;
		mlists xs [] = xs;
	}


	read_object_hunk_next_relocation i relocation_n module_offset relocations file
		# hunk_code=i>>16;
		| hunk_code==HUNK_XREF_16BIT || hunk_code==HUNK_XREF_16BIT_IL || hunk_code==HUNK_XREF_24BIT || 
		  hunk_code==HUNK_XREF_32BIT || hunk_code==HUNK_XREF_32BIT_REL
			# (_,name_id,file)=freadi file;
			  (_,offset,file)=freadi file;
			  (_,next_i,file)=freadi file;
			= read_object_hunk_next_relocation next_i (relocation_n+1) module_offset
					[{relocation_kind=hunk_code, relocation_class=(i>>8) bitand 255,
					  relocation_name_id=name_id<<1, relocation_offset=module_offset+offset
					 }:relocations] file;
			= (i,relocation_n,relocations,file);

	skip_object_hunk_relocations file
		# (read_ok,i,file)=freadi file;
		| not read_ok
			= abort "Error in object data";
			# hunk_code=i>>16;
			| hunk_code==HUNK_XREF_16BIT || hunk_code==HUNK_XREF_16BIT_IL || hunk_code==HUNK_XREF_24BIT ||
			  hunk_code==HUNK_XREF_32BIT || hunk_code==HUNK_XREF_32BIT_REL
				# (_,name_id,file)=freadi file;
				  (_,offset,file)=freadi file;
				= skip_object_hunk_relocations file;
				= (i,file);
		
read_object_data n_names file
	# (read_ok,i,file)=freadi file;
	| not read_ok || (i>>16)<>HUNK_START
		= abort "Error in object data";
		= read_object_data_hunks {code_offset=0,code_list=[],data_offset=0,data_list=[],
								  text_relocation_n=0,text_relocations=[],data_relocation_n=0,data_relocations=[],
								  symbol_table=empty_symbol_table,
								  local_symbols=createArray n_names False} file;
		{
			empty_symbol_table = {	text_symbols=EmptySymbolIndex,
									data_symbols=EmptySymbolIndex,
									toc_symbols=EmptySymbolIndex,
									bss_symbols=EmptySymbolIndex,
									toc0_symbol=EmptySymbolIndex,
									imported_symbols=EmptySymbolIndex,
									symbols=createArray (n_names<<1) EmptySymbol
								 };
		};
		
read_names :: !Int !.Int {#Bool} SymbolIndexList Int *{!Symbol} *File *{!NamesTableElement} -> (!SymbolIndexList,!.{!Symbol},!.File,!.{!NamesTableElement});
read_names name_n n_names local_symbols imported_symbols file_n symbols file names_table
	| name_n>=n_names
		= (imported_symbols,symbols,file,names_table);		
	# (read_ok,_,file) = freadc file;
	| not read_ok
		= abort "Error in names table";
	# (read_ok,_,file) = freadc file;
	| not read_ok
		= abort "Error in names table";
	| local_symbols.[name_n]
		# file=skip_c_string file;
		= read_names (name_n+1) n_names local_symbols imported_symbols file_n symbols file names_table;
		{
			skip_c_string file
				# (read_ok,c,file) = freadc file;
				| not read_ok
					= abort "Error in names table";
				| c=='\0'
					= file;
					= skip_c_string file;
				
		}
		# (string,file) = read_c_string 0 (createArray 8 ' ') file;
			with {
				read_c_string i s file
					# (read_ok,c,file) = freadc file;
					| not read_ok
						= abort "Error in names table";
					| c=='\0'
						= (s % (0,i-1),file);
					| i<size s
						= read_c_string (i+1) {s & [i]=c} file;
						= read_c_string (i+1) (s+++.{createArray 8 ' ' & [0]=c}) file;
			}
		# name_n2=name_n<<1;
		#! symbol=symbols.[name_n2];
		= case symbol of {
			EmptySymbol
				-> read_names (name_n+1) n_names local_symbols (SymbolIndex name_n2 imported_symbols) file_n {symbols & [name_n2]=ImportLabel string} file names_table;
			_
				# names_table = insert_symbol_in_symbol_table string name_n2 file_n names_table;
				-> read_names (name_n+1) n_names local_symbols imported_symbols file_n symbols file names_table;
		  };

/*
(+++.) infixr 5 :: !{#Char} !{#Char} -> .{#Char};
(+++.) a b
	= code {
		.inline +++.
		.d 2 0
			jsr catAC
		.o 1 0
		.end
	};
*/
read_object_names n_names names_table_offset local_symbols imported_symbols file_n symbols file names_table
	# (seek_ok,file) = fseek file names_table_offset FSeekSet;
	| not seek_ok
		= abort "Seek failed";
	= read_names 1 n_names local_symbols imported_symbols file_n symbols file names_table;

convert_mw_relocations_to_xcoff_relocations n_relocations mw_relocations
	# relocation_string_size=n_relocations*SIZE_OF_RELOCATION;
	  (offset,relocations)=convert_relocations mw_relocations 0 (createArray relocation_string_size '\0');
	= relocations;

convert_relocations :: ![MWRelocation] !Int !*{#Char} -> (!Int,!.{#Char});
convert_relocations [] offset relocations
	= (offset,relocations);
convert_relocations [mw_relocation:mw_relocations] offset relocations
	# (offset,relocations)=convert_relocations mw_relocations offset relocations;
	# relocations=convert_relocation mw_relocation offset relocations;
	= (offset+SIZE_OF_RELOCATION,relocations);
{
	convert_relocation {relocation_kind,relocation_class,relocation_name_id,relocation_offset} offset relocations
		# relocation_symbol_n=relocation_name_id+relocation_name_id;
		  (relocation_type,relocation_size,relocation_offset,relocation_symbol_n) = convert_relocation_type relocation_kind relocation_class relocation_offset relocation_symbol_n;		   
		= {relocations & [offset]  =toChar (relocation_offset>>24),
						 [offset+1]=toChar (relocation_offset>>16),
						 [offset+2]=toChar (relocation_offset>>8),
						 [offset+3]=toChar relocation_offset,
						 [offset+4]=toChar (relocation_symbol_n>>24),
						 [offset+5]=toChar (relocation_symbol_n>>16),
						 [offset+6]=toChar (relocation_symbol_n>>8),
						 [offset+7]=toChar relocation_symbol_n,
						 [offset+8]=toChar relocation_size,
						 [offset+9]=toChar relocation_type
						};
		{
			convert_relocation_type HUNK_XREF_16BIT XMC_PR relocation_offset relocation_symbol_n
				= (R_MW_BR,0x8f,relocation_offset+2,relocation_symbol_n);
			convert_relocation_type HUNK_XREF_16BIT XMC_TD relocation_offset relocation_symbol_n
				= (R_MW_TOC,0x8f,relocation_offset+2,relocation_symbol_n);
			convert_relocation_type HUNK_XREF_16BIT XMC_TC relocation_offset relocation_symbol_n
				= (R_MW_TOC,0x8f,relocation_offset+2,relocation_symbol_n+1);			
			convert_relocation_type HUNK_XREF_16BIT_IL XMC_TC relocation_offset relocation_symbol_n
				= (R_MW_TOC,0x8f,relocation_offset+2,relocation_symbol_n+1);
			convert_relocation_type HUNK_XREF_24BIT XMC_PR relocation_offset relocation_symbol_n
				= (R_MW_BR,0x99,relocation_offset,relocation_symbol_n);
			convert_relocation_type HUNK_XREF_32BIT XMC_TC relocation_offset relocation_symbol_n
				= (R_MW_POS,0x1f,relocation_offset,relocation_symbol_n+1);
			convert_relocation_type HUNK_XREF_32BIT relocation_class relocation_offset relocation_symbol_n
				= (R_MW_POS,0x1f,relocation_offset,relocation_symbol_n);
		}
}

list_of_strings_to_string total_string_size string_list
	# (offset,result_string)=copy_strings_in_list_to_string 0 string_list (createArray total_string_size '\0');
	= result_string;
	{
		copy_strings_in_list_to_string offset [] result_string
			= (offset,result_string);
		copy_strings_in_list_to_string offset [string:strings] result_string
			# (offset,result_string)=copy_strings_in_list_to_string offset strings result_string;
			= copy_string_data_to_string string 0 (size string) result_string offset;
		{
			copy_string_data_to_string :: !{#Char} !Int !Int !*{#Char} !Int -> (!Int,!.{#Char});
			copy_string_data_to_string source_string source_offset source_size destination_string destination_offset
				| source_offset==source_size
					= (destination_offset,destination_string);
					# destination_string = {destination_string & [destination_offset]=source_string.[source_offset]};
					= copy_string_data_to_string source_string (source_offset+1) source_size destination_string (destination_offset+1);
		}
	}

read_object_file :: !(.Int,.a) .{#Char} .Int *File *{!.NamesTableElement} -> (!.Xcoff,!.{#Char},!.{#Char},!.File,!.{!NamesTableElement});
read_object_file (object_file_offset,object_file_size) file_name file_n file names_table
	# (name_table_offset,nametable_names,obj_size,file) = read_object_header object_file_offset object_file_size file;

	  (file_contents,file) = read_object_data nametable_names file;

	  code_list			= file_contents.FileContents.code_list;
	  code_offset		= file_contents.FileContents.code_offset;
	  data_list			= file_contents.FileContents.data_list;
	  data_offset		= file_contents.FileContents.data_offset;
	  symbol_table		= file_contents.FileContents.symbol_table;
	  text_relocation_n	= file_contents.FileContents.text_relocation_n;
	  text_relocations	= file_contents.FileContents.text_relocations;
	  data_relocation_n	= file_contents.FileContents.data_relocation_n;
	  data_relocations	= file_contents.FileContents.data_relocations;
	  
//	  {text_symbols,data_symbols,toc_symbols,bss_symbols,toc0_symbol,imported_symbols,symbols}=symbol_table;
	  text_symbols		= symbol_table.text_symbols;
	  data_symbols		= symbol_table.data_symbols;
	  toc_symbols		= symbol_table.toc_symbols;
	  bss_symbols		= symbol_table.bss_symbols;
	  toc0_symbol		= symbol_table.toc0_symbol;
	  imported_symbols	= symbol_table.imported_symbols;
	  symbols			= symbol_table.symbols;

	  (imported_symbols,symbols,file,names_table) = read_object_names nametable_names (object_file_offset+name_table_offset) file_contents.local_symbols imported_symbols file_n symbols file names_table;

	  xcoff_header={
			file_name=file_name,
			text_section_offset=0,text_section_size=code_offset,
			data_section_offset=0,data_section_size=data_offset,
			text_v_address=0,data_v_address=0
		};
	  symbol_table={
			text_symbols=reverse_symbols text_symbols,
			data_symbols=reverse_symbols data_symbols,
			toc_symbols=reverse_symbols toc_symbols,
			bss_symbols=reverse_symbols bss_symbols,
			toc0_symbol=reverse_symbols toc0_symbol,
			imported_symbols=reverse_symbols imported_symbols,
			symbols=symbols
		};
	  xcoff={	header=xcoff_header,
				symbol_table=symbol_table,
				text_relocations=convert_mw_relocations_to_xcoff_relocations text_relocation_n text_relocations,
				data_relocations=convert_mw_relocations_to_xcoff_relocations data_relocation_n data_relocations,
				n_text_relocations=text_relocation_n,
				n_data_relocations=data_relocation_n,
				n_symbols=nametable_names<<1
		};
	= (xcoff,list_of_strings_to_string code_offset code_list,list_of_strings_to_string data_offset data_list,file,names_table);

read_object_files [] file_name file_n file names_table
	= ([],EndSections,file_n,file,names_table);
read_object_files [e:r] file_name file_n file names_table
	# (xcoff,text_section,data_section,file,names_table) = read_object_file e file_name file_n file names_table;
	  (xcoffs,sections,file_n,file,names_table) = read_object_files r file_name (file_n+1) file names_table;
	= ([xcoff:xcoffs],Sections text_section data_section sections,file_n,file,names_table);

read_mw_object_files :: !String !Int !*NamesTable !String !*File !*Files -> (![String],!Sections,![*Xcoff],!Int,!*NamesTable,!*Files);
read_mw_object_files file_name file_n names_table header_string file files
	# (ok1,data_size,file)=freadi file;
	  (ok2,n_object_files,file)=freadi file;
	| not ok1 || not ok2
	  	= error ("Error in object file header \""+++file_name+++"\"") file_n names_table header_string file files;
	# (object_file_offsets_and_size,file) = read_file_data_records n_object_files file;
	  (xcoffs,sections,file_n,file,names_table) = read_object_files object_file_offsets_and_size file_name file_n file names_table;
	  (close_ok,files)=fclose file files;
	| not close_ok
		= (["Error in object file \""+++file_name+++"\""],EndSections,[],file_n,names_table,files);	
		= ([],sections,xcoffs,file_n,names_table,files);
	{}{
 		error error_string file_n names_table header_string file files
 			# (_,files)=fclose file files;
 			= ([error_string],EndSections,[],file_n,names_table,files);
	}
