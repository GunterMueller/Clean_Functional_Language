implementation module type_io_write

import type_io_read
import type_io_common

// compiler

import StrictnessList
from utilities import foldSt, mapSt
from general import ::Optional(..)
import StdEnv

// extended
//from ExtString import ends, starts
//from ExtFile import ExtractPathAndFile, ExtractPathFileAndExtension
//import SymbolTable;
from NamesTable import create_names_table, isEmptyNamesTableElement, insert_symbol_in_symbol_table,find_symbol_in_symbol_table;
from ReadObject import decode_line_from_library_file;

import type_io_static
import StdMaybe;
import StdDynamicTypes;

create_type_archive :: [String] [String] !String !*Files -> (!Bool,!*Files)
create_type_archive objects dlls typ_name files
	# (ok1,tio_common_defs,type_io_state,files)
		= collect_type_infoNEW objects files
	| not ok1
		= (False,files)		
	// write it back to disk
	= write_type_information2 typ_name dlls tio_common_defs type_io_state files

write_type_information2 :: !String [String] !*{#TIO_CommonDefs} !*TypeIOState !*Files -> (!Bool,!*Files)
write_type_information2 typ_file_name dlls tio_common_defs type_io_state files
	# (ok,typ_file,files)
		= fopen typ_file_name FWriteData files
	| not ok
		= (False,snd (fclose typ_file files))
		
	// write contents of libraries
	# typ_file
		= fwritei (length dlls) typ_file
	# (ok,typ_file,_,files)
		= foldSt copy_library_files dlls (True,typ_file,create_names_table,files)
	| not ok
		= (False,snd (fclose typ_file files))

	// write type information
	# (typ_file,_)
		= write_type_info tio_common_defs typ_file WriteTypeInfoState
	# typ_file
		= write_type_io_state type_io_state typ_file
		
	# (_,files)
		= fclose typ_file files
	= (True,files)
where	// 
	copy_library_files :: !String (!Bool,!*File,!*NamesTable,!*Files) -> (!Bool,!*File,!*NamesTable,!*Files)
	copy_library_files library_file_name (True,typ_file,names_table,files)
		# (ok,library_file,files)
			= fopen library_file_name FReadText files
		| not ok
			= abort ("copy_library_files 1" +++ library_file_name) //(False,typ_file,snd (fclose library_file files))
			
		# (library_file,contents,n_contents_lines,names_table)
			= copy_library_file library_file [] 0 names_table
		# typ_file
			= fwritei n_contents_lines typ_file
		# typ_file
			= foldSt /*fwrites*/ write_line contents typ_file
			
		# (_,files)
			= fclose library_file files
		= (True,typ_file,names_table,files)
	where
		copy_library_file :: !*File [{#Char}] !Int !*NamesTable -> (!*File,[{#Char}],!Int,!*NamesTable)
		copy_library_file library_file accu n_contents_lines names_table
			# (end_of_line,library_file)
				= fend library_file
			| end_of_line
				= (library_file,reverse accu,n_contents_lines,names_table)
			
			# (s,library_file)
				= freadline library_file

			# result
				= if (isEmpty accu) Nothing (decode_line_from_library_file s);
			# (skip_line,names_table)
				= case result of
					Nothing	
						-> (False,names_table);
					(Just symbol_name)
						# (names_table_element,names_table)
							= find_symbol_in_symbol_table symbol_name names_table;
						| isEmptyNamesTableElement names_table_element
							# names_table
								= insert_symbol_in_symbol_table symbol_name 0 0 names_table;
							-> (False,names_table);
							
							// remove duplicate library symbols
							-> (True,names_table);
			| skip_line
				= copy_library_file library_file accu n_contents_lines names_table

				= copy_library_file library_file [s:accu] (inc n_contents_lines) names_table
				
		copy_library_files _ (False,typ_file,files)
			= (False,typ_file,files)

		write_line line typ_file
			# typ_file = fwritec (toChar (size line)) typ_file
			= fwrites line typ_file

:: WriteTypeInfoState	= WriteTypeInfoState;

class WriteTypeInfo a 
where
	write_type_info :: a !*File !*WriteTypeInfoState -> (!*File,!*WriteTypeInfoState)
		
instance WriteTypeInfo TIO_CommonDefs
where
	write_type_info {tio_com_type_defs,tio_com_cons_defs,tio_imported_modules,tio_n_exported_com_type_defs,tio_n_exported_com_cons_defs,tio_module} tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info tio_com_type_defs tcl_file wtis
		# (tcl_file,wtis)
 			= write_type_info tio_com_cons_defs tcl_file wtis
 		// additional
 		# (tcl_file,wtis)
 			= write_type_info tio_imported_modules tcl_file wtis
 		# (tcl_file,wtis)
 			= write_type_info tio_n_exported_com_type_defs tcl_file wtis
 		# (tcl_file,wtis)
 			= write_type_info tio_n_exported_com_cons_defs tcl_file wtis
 		# (tcl_file,wtis)
 			= write_type_info tio_module tcl_file wtis 		
		= (tcl_file,wtis)

instance WriteTypeInfo TIO_ConsDef
where
	write_type_info {tio_cons_symb,tio_cons_type,tio_cons_type_index,tio_cons_exi_vars} tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info tio_cons_symb tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info tio_cons_type tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info tio_cons_type_index tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info tio_cons_exi_vars tcl_file wtis
		= (tcl_file,wtis)

instance WriteTypeInfo (TIO_TypeDef TIO_TypeRhs)
where 
	write_type_info {tio_td_name,tio_td_arity,tio_td_args,tio_td_rhs} tcl_file wtis
 		# (tcl_file,wtis)
 			= write_type_info tio_td_name tcl_file wtis
		# (tcl_file,wtis)
 			= write_type_info tio_td_arity tcl_file wtis 				
 		# (tcl_file,wtis)
 			= write_type_info tio_td_args tcl_file wtis
		# (tcl_file,wtis)
 			= write_type_info tio_td_rhs tcl_file wtis
 		= (tcl_file,wtis)

instance WriteTypeInfo TIO_ATypeVar
where 
	write_type_info {tio_atv_variable} tcl_file wtis
 		# (tcl_file,wtis)
 			= write_type_info tio_atv_variable tcl_file wtis
 		= (tcl_file,wtis)

instance WriteTypeInfo TIO_TypeVar
where
	write_type_info {tio_tv_name} tcl_file wtis
		# tcl_file
			= fwritei tio_tv_name tcl_file
 		= (tcl_file,wtis)	

instance WriteTypeInfo TIO_TypeRhs
where 
	write_type_info (TIO_AlgType defined_symbols) tcl_file wtis
 		# tcl_file = fwritec AlgTypeCode tcl_file
//		# defined_symbols
//			= (sortBy (\{ds_ident={id_name=id_name1}} {ds_ident={id_name=id_name2}} -> id_name1 < id_name2) defined_symbols)
		= write_type_info defined_symbols tcl_file wtis

	write_type_info (TIO_SynType _) tcl_file wtis
		# tcl_file = fwritec SynTypeCode tcl_file;
 		// unimplemented
 		= (tcl_file,wtis) 

	write_type_info (TIO_RecordType {tio_rt_constructor,tio_rt_fields}) tcl_file wtis
 		# tcl_file = fwritec RecordTypeCode tcl_file;
		  (tcl_file,wtis) = write_type_info tio_rt_constructor tcl_file wtis
		= write_type_info tio_rt_fields tcl_file wtis

	write_type_info (TIO_GenericDictionaryType {tio_rt_constructor,tio_rt_fields}) tcl_file wtis
 		# tcl_file = fwritec GenericDictionaryTypeCode tcl_file;
		  (tcl_file,wtis) = write_type_info tio_rt_constructor tcl_file wtis
		= write_type_info tio_rt_fields tcl_file wtis

	write_type_info (TIO_AbstractType _) tcl_file wtis
 		# tcl_file = fwritec AbstractTypeCode tcl_file;
 		// unimplemented
		= (tcl_file,wtis)
				
instance WriteTypeInfo TIO_ConstructorSymbol 
where
	write_type_info {tio_cons} tcl_file wtis
		= write_type_info tio_cons tcl_file wtis

instance WriteTypeInfo TIO_DefinedSymbol 
where
	write_type_info {tio_ds_ident,tio_ds_arity,tio_ds_index} tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info tio_ds_ident tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info tio_ds_arity tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info tio_ds_index tcl_file wtis
		= (tcl_file,wtis)

instance WriteTypeInfo TIO_FieldSymbol
where
	write_type_info {tio_fs_name} tcl_file wtis
		= write_type_info tio_fs_name tcl_file wtis
		
instance WriteTypeInfo TIO_SymbolType
where
	write_type_info {tio_st_vars,tio_st_args,tio_st_args_strictness,tio_st_arity,tio_st_result} tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info tio_st_vars tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info tio_st_args tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info tio_st_args_strictness tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info tio_st_arity tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info tio_st_result tcl_file wtis
		= (tcl_file,wtis)
	
instance WriteTypeInfo StrictnessList
where
	write_type_info NotStrict tcl_file wtis
		# tcl_file
			= fwritec NotStrictCode tcl_file
		= (tcl_file,wtis)
	write_type_info (Strict i) tcl_file wtis
		# tcl_file
			= fwritec StrictCode tcl_file
		# tcl_file
			= fwritei i tcl_file
		= (tcl_file,wtis)
	write_type_info (StrictList i tail) tcl_file wtis
		# tcl_file
			= fwritec StrictListCode tcl_file
		# tcl_file
			= fwritei i tcl_file
		= write_type_info tail tcl_file wtis
	
instance WriteTypeInfo TIO_AType
where
	write_type_info {tio_at_type} tcl_file wtis
		= write_type_info tio_at_type tcl_file wtis
		
instance WriteTypeInfo TIO_Type
where
	write_type_info (TIO_TAS type_symb_ident atypes strictness) tcl_file wtis
		# tcl_file
			= fwritec TypeTASCode tcl_file
		# (tcl_file,wtis)
			= write_type_info type_symb_ident tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info atypes tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info strictness tcl_file wtis			
		= (tcl_file,wtis)

	write_type_info (atype1 ----> atype2) tcl_file wtis
		# tcl_file
			= fwritec TypeArrowCode tcl_file
		# (tcl_file,wtis)
			= write_type_info atype1 tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info atype2 tcl_file wtis
		= (tcl_file,wtis)
		
	write_type_info (cons_variable :@@: atypes) tcl_file wtis
		# tcl_file
			= fwritec TypeConsApplyCode tcl_file
		# (tcl_file,wtis)
			= write_type_info cons_variable tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info atypes tcl_file wtis
		= (tcl_file,wtis)
		
	write_type_info tb=:(TIO_TB basic_type) tcl_file wtis
		# (tcl_file,wtis)
			= case basic_type of
				TIO_BT_Int		-> (fwritec BT_IntCode tcl_file,wtis)
				TIO_BT_Char		-> (fwritec BT_CharCode tcl_file,wtis)
				TIO_BT_Real		-> (fwritec BT_RealCode tcl_file,wtis)
				TIO_BT_Bool		-> (fwritec BT_BoolCode tcl_file,wtis)
				TIO_BT_Dynamic	-> (fwritec BT_DynamicCode tcl_file,wtis)
				TIO_BT_File		-> (fwritec BT_FileCode tcl_file,wtis)
				TIO_BT_World	-> (fwritec BT_WorldCode tcl_file,wtis)
				TIO_BT_String type
					# tcl_file
						= fwritec BT_StringCode tcl_file
					# (tcl_file,wtis)
						= write_type_info type tcl_file wtis
					-> (tcl_file,wtis)
		= (tcl_file,wtis)
	
	write_type_info (TIO_GTV type_var) tcl_file wtis
		# tcl_file
			= fwritec TypeGTVCode tcl_file
		# (tcl_file,wtis)
			= write_type_info type_var tcl_file wtis
		= (tcl_file,wtis)

	write_type_info (TIO_TV type_var) tcl_file wtis
		# tcl_file
			= fwritec TypeTVCode tcl_file
		# (tcl_file,wtis)
			= write_type_info type_var tcl_file wtis
		= (tcl_file,wtis)
		
	write_type_info (TIO_TQV type_var) tcl_file wtis
		# tcl_file = fwritec TypeTQVCode tcl_file
		= write_type_info type_var tcl_file wtis

	write_type_info (TIO_GenericFunction kind symbol_type) tcl_file wtis
		# tcl_file = fwritec GenericFunctionTypeCode tcl_file
		  tcl_file = fwritei (size kind) tcl_file
		  tcl_file = fwrites kind tcl_file
		= write_type_info symbol_type tcl_file wtis

	write_type_info TIO_TE tcl_file wtis
		# tcl_file = fwritec TypeTECode tcl_file
		= (tcl_file,wtis)	

instance WriteTypeInfo TIO_ConsVariable
where
	write_type_info (TIO_CV type_var) tcl_file wtis
		# tcl_file
			= fwritec ConsVariableCVCode tcl_file
		# (tcl_file,wtis)
			= write_type_info type_var tcl_file wtis
		= (tcl_file,wtis)	

	write_type_info (TIO_TempCV temp_var_id) tcl_file wtis
		# tcl_file
			= fwritec ConsVariableTempCVCode tcl_file
		# (tcl_file,wtis)
			= write_type_info temp_var_id tcl_file wtis
		= (tcl_file,wtis)	
		
	write_type_info (TIO_TempQCV temp_var_id) tcl_file wtis
		# tcl_file
			= fwritec ConsVariableTempQCVCode tcl_file
		# (tcl_file,wtis)
			= write_type_info temp_var_id tcl_file wtis
		= (tcl_file,wtis)	

instance WriteTypeInfo TIO_TypeSymbIdent
where
	write_type_info {tio_type_name_ref,tio_type_arity} tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info tio_type_name_ref tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info tio_type_arity tcl_file wtis
		= (tcl_file,wtis)

instance WriteTypeInfo TIO_GlobalIndex
where
	write_type_info {tio_glob_object,tio_glob_module} tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info tio_glob_object tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info tio_glob_module tcl_file wtis
		= (tcl_file,wtis)

instance WriteTypeInfo TIO_TypeReference
where
	write_type_info {tio_type_without_definition,tio_tr_module_n,tio_tr_type_def_n} tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info tio_type_without_definition tcl_file wtis
		# tcl_file
			= fwritei tio_tr_module_n tcl_file
		# tcl_file
			= fwritei tio_tr_type_def_n tcl_file
		= (tcl_file,wtis)

// basic and structural write_type_info's
instance WriteTypeInfo Int 
where
	write_type_info i tcl_file wtis
		= (fwritei i tcl_file,wtis)

instance WriteTypeInfo {#b} | WriteTypeInfo b & Array {#} b
where
	write_type_info unboxed_array tcl_file wtis
		# s_unboxed_array = size unboxed_array
		# tcl_file = fwritei s_unboxed_array tcl_file
		= write_type_info_loop 0 s_unboxed_array tcl_file wtis
	where 
		write_type_info_loop i limit tcl_file wtis
			| i == limit
				= (tcl_file,wtis)
			# (tcl_file,wtis)
				= write_type_info unboxed_array.[i] tcl_file wtis
			= write_type_info_loop (inc i) limit tcl_file wtis
			
instance WriteTypeInfo [a] | WriteTypeInfo a
where
	write_type_info l tcl_file wtis
		# tcl_file = fwritei (length l) tcl_file
		= write_type_info_loop l tcl_file wtis
	where
		write_type_info_loop []	tcl_file wtis
			= (tcl_file,wtis)
		write_type_info_loop [x:xs] tcl_file wtis
			# (tcl_file,wtis)
				= write_type_info x tcl_file wtis
			= write_type_info_loop xs tcl_file wtis

instance WriteTypeInfo (Maybe a) | WriteTypeInfo a
where
	write_type_info Nothing tcl_file wtis
 		# tcl_file
 			= fwritec MaybeNoneCode tcl_file
 		= (tcl_file,wtis)
 	write_type_info (Just a) tcl_file wtis
 		# tcl_file
 			= fwritec MaybeJustCode tcl_file
		# (tcl_file,wtis)
			= write_type_info a tcl_file wtis
		= (tcl_file,wtis)
		
instance WriteTypeInfo (a,b) | WriteTypeInfo a & WriteTypeInfo b
where
	write_type_info (a,b) tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info a tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info b tcl_file wtis
		= (tcl_file,wtis)

instance WriteTypeInfo Char
where
	write_type_info c tcl_file wtis
		# tcl_file
			= fwritec c tcl_file;
		= (tcl_file,wtis);

// type_io_state
write_type_io_state :: !*TypeIOState !*File -> *File
write_type_io_state type_io_state=:{tis_string_table,tis_equivalent_type_definitions} typ_file
	// string table
	# typ_file
		= fwritei (size tis_string_table) typ_file
	# typ_file
		= fwrites tis_string_table typ_file
	# (typ_file,_)
		= write_type_info tis_equivalent_type_definitions typ_file WriteTypeInfoState
	= typ_file

instance WriteTypeInfo EquivalentTypeDef
where
	write_type_info {type_name,partitions} tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info type_name tcl_file wtis
		# (tcl_file,wtis)
			= write_type_info partitions tcl_file wtis
		= (tcl_file,wtis)
