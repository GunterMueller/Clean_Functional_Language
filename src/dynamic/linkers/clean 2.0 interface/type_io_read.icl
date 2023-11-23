implementation module type_io_read

import StdEnv, StdMaybe
import StdDynamicTypes, type_io_common, StrictnessList

import ExtString, general, BitSet, DefaultElem
from pdSymbolTable import EmptyLibraryList
from ReadObject import class ExtFileSystem,read_library_files, ::NamesTable, ::SNamesTable, ::LibraryList, ::NamesTableElement, read_library_files_new

// 
// External dependencies:
// 1. syntax.{icl,dcl},compiler
//    tcl-file format can change
// 2. predef
//    built-in types should also be inserted in find_types2
//
// A pair of types are equivalent:
// 1. modulo alpha conversion i.e. the type arguments of 
//    constructors and existential variables are normalized.
// 2. for algebraic types only: the order of constructors
//    is *not* significant.
//
// The normalizing needed for the points above is done at compile
// time in the module type_io.
//
// Strictness annotations are significant in a data-type because
// its implementation changes.
//
// Unsupported:
// - abstract datatypes
// - synonym types
//
// The bring-up-to-date cycle of the IDE guarantees that type 
// information is correct

// CommonDefs
empty_tio_common_def :: TIO_CommonDefs
empty_tio_common_def
    = { TIO_CommonDefs |
        tio_com_type_defs               = {}
    ,   tio_com_cons_defs               = {}
    ,   tio_imported_modules            = {}
    ,   tio_n_exported_com_type_defs    = 0
    ,   tio_n_exported_com_cons_defs    = 0
    ,   tio_module                      = 0
	,	tio_global_module_strings		= {}
    }
    
::  TIO_CommonDefs =
    {   tio_com_type_defs               :: !.{# TIO_CheckedTypeDef}
    ,   tio_com_cons_defs               :: !.{# TIO_ConsDef}
    ,   tio_imported_modules            :: !.{#Int}							// offsets in string table
    ,   tio_n_exported_com_type_defs    :: !Int
    ,   tio_n_exported_com_cons_defs    :: !Int
    ,   tio_module                      :: !Int								// offset in string table
	,	tio_global_module_strings		:: !{#{#Char}}
    }
        
::  TIO_CheckedTypeDef  :== TIO_TypeDef TIO_TypeRhs
    
::  TIO_TypeDef type_rhs =
    {
        tio_td_name                         :: !Int
    ,   tio_td_arity                        :: !Int
    ,   tio_td_args                         :: ![TIO_ATypeVar]      // -
    ,   tio_td_rhs                          :: !type_rhs
    ,   tio_type_equivalence_table_index    :: !Optional Int
    }
    
::  TIO_TypeRhs = TIO_AlgType ![TIO_ConstructorSymbol]
                | TIO_SynType !TIO_AType
                | TIO_RecordType !TIO_RecordType
				| TIO_GenericDictionaryType !TIO_RecordType
                | TIO_AbstractType !TIO_BITVECT
                | TIO_UnknownType
                
::  TIO_DefinedSymbol = 
    {   tio_ds_ident            :: !Int
    ,   tio_ds_arity            :: !Int
    ,   tio_ds_index            :: !TIO_Index
    }
        
::	TIO_RecordType =
	{
		tio_rt_constructor		:: !TIO_DefinedSymbol
	,	tio_rt_fields			:: !{# TIO_FieldSymbol}
	}

::  TIO_ConsDef =
    {	tio_cons_symb           :: !Int 
    ,   tio_cons_type           :: !TIO_SymbolType
    ,   tio_cons_type_index     :: !TIO_Index           // remove?
    ,   tio_cons_exi_vars       :: ![TIO_ATypeVar]      // REMOVE   - set of all E vars
    }

:: TIO_SelectorDef = 
    { 
        tio_sd_type             :: !TIO_SymbolType
    }
    
::  TIO_ATypeVar =
    {
        tio_atv_variable        :: !TIO_TypeVar
    }
    
::  TIO_Annotation = TIO_AN_Strict | TIO_AN_None 

::  TIO_AType =
    {
		tio_at_type             :: !TIO_Type
    }

::	TIO_Type =	TIO_TAS !TIO_TypeSymbIdent ![TIO_AType] !StrictnessList
			|	TIO_TAS_tcl !TIO_TypeSymbIdent !TIO_GlobalIndex ![TIO_AType] !StrictnessList
			|	(---->) infixr 9 !TIO_AType !TIO_AType
			|	(:@@:) infixl 9 !TIO_ConsVariable ![TIO_AType]
			|	TIO_TB !TIO_BasicType
			| 	TIO_GTV !TIO_TypeVar
			| 	TIO_TV !TIO_TypeVar
			|	TIO_TQV	TIO_TypeVar
			|	TIO_GenericFunction !{#Char} /*kind*/ !TIO_SymbolType
			|	TIO_TE
			|	TIO_DefaultElem
			            
::	TIO_SymbolType =
	{	tio_st_vars				:: ![TIO_TypeVar]
	,	tio_st_args				:: ![TIO_AType]
	,	tio_st_args_strictness	:: !StrictnessList
	,	tio_st_arity			:: !Int
	,	tio_st_result			:: !TIO_AType
	}
    
::  TIO_BasicType   = TIO_BT_Int | TIO_BT_Char | TIO_BT_Real | TIO_BT_Bool | TIO_BT_Dynamic
                    | TIO_BT_File | TIO_BT_World
                    | TIO_BT_String !TIO_Type /* the internal string type synonym only used to type string denotations */
                    
instance toString TIO_BasicType
where 
	toString TIO_BT_Int			= "Int"
	toString TIO_BT_Char		= "Char"
	toString TIO_BT_Real		= "Real"
	toString TIO_BT_Bool		= "Bool"
	toString TIO_BT_Dynamic		= "Dynamic"
	toString TIO_BT_File		= "File"
	toString TIO_BT_World		= "World"
	toString (TIO_BT_String _)	= "String"
    
::  TIO_TypeVar =
    {   
        tio_tv_name         :: !Int
    }

::  TIO_ConsVariable = TIO_CV       !TIO_TypeVar
                     | TIO_TempCV   !TIO_TempVarId
                     | TIO_TempQCV  !TIO_TempVarId
                     
::  TIO_TempVarId       :== Int

::  TIO_TypeSymbIdent =
	{   tio_type_name_ref   :: !TIO_TypeReference
	,   tio_type_arity      :: !Int
	}

::	TIO_GlobalIndex =
	{	tio_glob_object		:: !TIO_Index
	,	tio_glob_module		:: !TIO_Index
	}
    
TIO_NoIndex	:== -1
	
instance == TIO_TypeReference
where
	(==) {tio_type_without_definition=Just type_name1} {tio_type_without_definition=Just type_name2}
		= type_name1 == type_name2
	(==) {tio_type_without_definition=Nothing,tio_tr_module_n=tio_tr_module_n1,tio_tr_type_def_n=tio_tr_type_def_n1}
			{tio_type_without_definition=Nothing,tio_tr_module_n=tio_tr_module_n2,tio_tr_type_def_n=tio_tr_type_def_n2}
        = tio_tr_module_n1 == tio_tr_module_n2 && tio_tr_type_def_n1 == tio_tr_type_def_n2
	(==) _ _
		= False

class isTypeWithoutDefinition a :: !a -> Bool

instance isTypeWithoutDefinition TIO_TypeReference
where 
	isTypeWithoutDefinition {tio_type_without_definition}
		= isJust tio_type_without_definition

makeTypeWithoutDefinition :: !String -> TIO_TypeReference
makeTypeWithoutDefinition type_name_without_definition
	= { default_elem &
		tio_type_without_definition = Just type_name_without_definition
	}

:: TypeTableTypeReference
	= TypeTableTypeReference !Int !TIO_TypeReference

instance toString TypeTableTypeReference
where
	toString (TypeTableTypeReference type_table_i _)
		= " <" +++ toString type_table_i +++ ">"

instance == TypeTableTypeReference
where
	(==) (TypeTableTypeReference _ {tio_type_without_definition=Just type_name1}) (TypeTableTypeReference _ {tio_type_without_definition=Just type_name2})
		= type_name1 == type_name2
	(==) (TypeTableTypeReference type_table1 tio_type_ref1) (TypeTableTypeReference type_table2 tio_type_ref2)
		= abort ("== (TypeTableReference) "
			+++ toString type_table1 +++ " " +++ toString tio_type_ref1
			+++ " and "  
			+++ toString type_table2 +++ " " +++ toString tio_type_ref2
			)
			(type_table1 == type_table2 && tio_type_ref1 == tio_type_ref2)

instance toString TIO_TypeReference where
	toString {tio_tr_module_n, tio_tr_type_def_n}
		=	"<" +++ toString tio_tr_module_n +++ ", "
				+++ toString tio_tr_type_def_n +++ ">"

instance isTypeWithoutDefinition TypeTableTypeReference
where
	isTypeWithoutDefinition (TypeTableTypeReference _ tio_type_reference)
		= isTypeWithoutDefinition tio_type_reference

instance == LibraryInstanceTypeReference
where
    (==) (LIT_TypeReference library_instance_i1 tio_type_ref1) (LIT_TypeReference library_instance_i2 tio_type_ref2)
        = library_instance_i1 == library_instance_i2 && tio_type_ref1 == tio_type_ref2;
        
instance == LibRef
where
	(==) (LibRef i) (LibRef j)
		= i == j;
	(==) _ _
		= False;

instance isTypeWithoutDefinition LibraryInstanceTypeReference
where
	isTypeWithoutDefinition (LIT_TypeReference _ tio_type_reference)
		= isTypeWithoutDefinition tio_type_reference

::  TIO_Priority = TIO_Prio TIO_Assoc Int | TIO_NoPrio

::  TIO_Assoc   = TIO_LeftAssoc | TIO_RightAssoc | TIO_NoAssoc

::  TIO_Index   :== Int

::  TIO_BITVECT :== Int

::  TIO_FieldSymbol = { tio_fs_name :: !Int }

// read
:: *TypeIOState = {
    // String index table
        tis_current_string_index        :: !Int
    // String hash table
    ,   tis_string_hash_table           :: !*{[HashTableElement]}
    ,   tis_string_table                :: !String
    // Used by TypeDef
    ,   tis_current_module_i            :: !Int
    ,   tis_current_def_i               :: !Int
    // ?
    ,   tis_max_types_per_module        :: !{#Int}
    ,   tis_n_common_defs               :: !Int
    ,   tis_max_types                   :: !Int
    // used after equivalent types have been determined
    ,   tis_equivalent_type_definitions :: !{#EquivalentTypeDef}
    // used to reuse the read_type_info
    ,   tis_reading_typ_file            :: !Bool                    // .typ file
    };

NAME_TABLE_SIZE         :== 4096;
NAME_TABLE_SIZE_MASK    :== 4095;

default_hash_table_element
    = {	hte_name                    = ""
    ,   hte_index                   = 0
    ,   hte_type_refs               = NoTypeName
    ,   hte_module_ref              = NoModuleName
    }
    
:: HashTableElement
    = {	hte_name                    :: !String
    ,   hte_index                   :: !Int
    ,   hte_type_refs               :: !TypeName            // references types with same names
    ,   hte_module_ref              :: !ModuleName
    }

:: TypeName
    = NoTypeName
    | TypeName [TIO_TypeReference]          // references to possibly different but equally named types
    ;

isNoTypeName :: TypeName -> Bool   
isNoTypeName NoTypeName     = True
isNoTypeName _              = False
    
:: ModuleName
    = NoModuleName
    | ModuleName Int                        // module index in {TIO_CommonDefs}-array
    ;
    
default_type_io_state :: *TypeIOState
default_type_io_state 
    = { TypeIOState |
    // String index table
        tis_current_string_index        = 0
    // String hash table
    ,   tis_string_hash_table           = createArray NAME_TABLE_SIZE []
    ,   tis_string_table                = {}
    // Used by TypeDef
    ,   tis_current_module_i            = 0
	,   tis_current_def_i               = 0
    // ?
    ,   tis_max_types_per_module        = {}
    ,   tis_n_common_defs               = 0
    ,   tis_max_types                   = 0
    ,   tis_equivalent_type_definitions = {}
    // used to reuse the read_type_info
    ,   tis_reading_typ_file            = False                 // .typ file
    };

get_type_name :: !TIO_TypeReference !String !*{#TIO_CommonDefs} -> (!String,!*{#TIO_CommonDefs});
get_type_name {tio_tr_module_n,tio_tr_type_def_n} tis_string_table tio_common_defs
    #! (tio_td_name,tio_common_defs) = tio_common_defs![tio_tr_module_n].tio_com_type_defs.[tio_tr_type_def_n].tio_td_name;
    #! (null_index_found,null_index)
        = CharIndex tis_string_table tio_td_name '\0';
    | not null_index_found
        = abort "get_type_name: internal error";
    # type_name = tis_string_table % (tio_td_name,dec null_index);
    = (type_name,tio_common_defs);
    
name_hash :: !String -> Int;
name_hash symbol_name = (simple_hash symbol_name 0 0) bitand NAME_TABLE_SIZE_MASK;
where
    simple_hash string index value
        | index== size string
            = value;
            = simple_hash string (inc index) (((value<<2) bitxor (value>>10)) bitxor (string BYTE index));

name_hash2 :: !Int !String -> Int;
name_hash2 i symbol_name = (simple_hash symbol_name i 0) bitand NAME_TABLE_SIZE_MASK;
where
    simple_hash string index value
        | symbol_name.[i] == '\0'
            = value;
            = simple_hash string (inc index) (((value<<2) bitxor (value>>10)) bitxor (string BYTE index));

isYes (Yes _)   = True
isYes _         = False

insert_name :: !(Optional Int) (Optional (!Int,!Int)) !.{#Char} !*TypeIOState -> *(!Int,!*TypeIOState);            
insert_name opt_module_ref opt_type_ref name type_io_state=:{tis_current_string_index,tis_string_hash_table}
    // lookup name
    # hash_value_of_name
        = name_hash name
    # (hash_table_elements,type_io_state)
        = type_io_state!tis_string_hash_table.[hash_value_of_name]
    # (result,left,right)
        = split hash_table_elements [];

	// make hash table entry available
    # (hash_table_element=:{hte_module_ref,hte_type_refs,hte_index})
        = case result of 
            Yes hash_table_element
                -> hash_table_element
            _
            	// create a new hash table entry
                # hash_table_element
                    = { default_hash_table_element &
                        hte_name    = name
                    ,   hte_index   = tis_current_string_index
                    }
                -> hash_table_element
    # hash_table_element
        = f opt_type_ref
      with
         f (Yes (tio_tr_module_n,tio_tr_type_def_n))
                # tio_type_reference
                    =  { default_elem & tio_tr_module_n=tio_tr_module_n,tio_tr_type_def_n=tio_tr_type_def_n}
                = case hte_type_refs of
                    NoTypeName
                        -> { hash_table_element & hte_type_refs = TypeName [tio_type_reference] }
                    TypeName hte_type_refs
                        -> { hash_table_element & hte_type_refs = TypeName [tio_type_reference:hte_type_refs] }
         f No
                    = hash_table_element

    // insert module index in hash table
    # hash_table_element
    	= f opt_module_ref
      with
    	f   (Yes module_n)
                = case hte_module_ref of 
                    ModuleName i
                        | module_n == i
                            -> hash_table_element
                    NoModuleName
                        # hash_table_element
                            = { hash_table_element &
                                hte_module_ref = ModuleName module_n
                            }
                        -> hash_table_element
        f   No
                = hash_table_element

    # type_io_state = {type_io_state & tis_string_hash_table =
						{type_io_state.tis_string_hash_table & [hash_value_of_name] = [hash_table_element:left] ++ right}}
    | not (isYes result)
        # type_io_state
            = { type_io_state &
                tis_current_string_index    = (inc (size name)) + tis_current_string_index
            }
        = (tis_current_string_index,type_io_state)
        = (hte_index,type_io_state)
where
    split [] left
        = (No,left,[])
    split [x=:{hte_name}:right] left
        | hte_name == name
            = (Yes x,left,right)
        = split right [x:left]      

type_io_find_name :: !String !*TypeIOState -> *(!Bool,!HashTableElement,!*TypeIOState); 
type_io_find_name name type_io_state
    # hashed_name = name_hash name;
    # (hash_table_elements,type_io_state)
        = type_io_state!tis_string_hash_table.[hashed_name];
    # elements
        = [ hash_table_element \\ hash_table_element=:{hte_name} <- hash_table_elements | hte_name == name];
    # is_empty
        = isEmpty elements
    = (not is_empty,if is_empty default_hash_table_element (hd elements),type_io_state);

// ReadTypeInfo
// 
// Description:
// Reads type information from a tcl-file and replaces string by offsets in a string table to
// be constructed later.
//
// Depending on the context a distinction is made among names. There are tree groups:
// 1. type definiton names
//    Equally named types are collected together in the hash table by collecting pointers to
//    their definitions. These types are the potential candidates for strict type equality.
// 2. module names
//    Additional information stored with a module name is its index in the {#TIO_CommonDefs}
// 3. type names refering to a type definition
//    These names occur only on the right hand side of type and are initialized with a default
//    pointer value.
// 4. to other names, no special information is attached.
class ReadTypeInfo a
where
    read_type_info :: !*File !*TypeIOState -> (!Bool,!a,!*File,!*TypeIOState)

instance ReadTypeInfo TIO_CommonDefs
where
    read_type_info tcl_file type_io_state=:{tis_reading_typ_file}
        # (ok1,tio_com_type_defs,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        # (ok2,tio_com_cons_defs,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        # (ok3,tio_imported_modules,tcl_file,type_io_state)
            = case tis_reading_typ_file of
                False
                    # (_,n_imported_modules,tcl_file)
                        = freadi tcl_file                    	
                    -> read_directly_imported_modules 0 n_imported_modules (createArray n_imported_modules 0) type_io_state tcl_file
                True
                    # (ok,tio_imported_modules,tcl_file,file)
                    	= read_type_info tcl_file type_io_state
                    -> (ok,tio_imported_modules,tcl_file,file)
        # (ok5,tio_global_module_strings,type_io_state,tcl_file)
            = case tis_reading_typ_file of
                False   
                	// .tcl-file
			        # (ok,tio_global_module_strings,tcl_file,type_io_state)
			        	= read_type_info tcl_file type_io_state
			        | size tio_global_module_strings == 0
			        	-> abort "instance ReadTypeInfo TIO_CommonDefs; internal error"
			        -> (ok,tio_global_module_strings,type_io_state,tcl_file)
			    True
			    	-> (True,{},type_io_state,tcl_file)
        # (ok6,n_exported_com_type_defs,tcl_file)
            = freadi tcl_file 
        # (ok7,n_exported_com_cons_defs,tcl_file)
            = freadi tcl_file           
        # (ok8,tio_module,tcl_file)
            = case tis_reading_typ_file of
                False	-> (True,0,tcl_file)
                True	-> freadi tcl_file
 
        # tio_common_defs
            = { default_elem & 
                tio_com_type_defs               = tio_com_type_defs
            ,   tio_com_cons_defs               = tio_com_cons_defs
            ,   tio_imported_modules            = tio_imported_modules
            ,   tio_n_exported_com_type_defs    = n_exported_com_type_defs
            ,   tio_n_exported_com_cons_defs    = n_exported_com_cons_defs
            ,   tio_module                      = tio_module
            ,	tio_global_module_strings		= tio_global_module_strings
            }
        = (ok1&&ok2&&ok3&&ok5&&ok6&&ok7&&ok8,tio_common_defs,tcl_file,type_io_state) 
    where
        read_directly_imported_modules :: !Int !Int !*{#Int} !*TypeIOState !*File -> (!Bool,!*{#Int},!*File,!*TypeIOState)
        read_directly_imported_modules i n_imported_modules tio_imported_modules type_io_state tcl_file
            | i == n_imported_modules
                = (True,tio_imported_modules,tcl_file,type_io_state)
                
                # (ok,s,tcl_file)
                    = freadi tcl_file
                | not ok
                    = (True,tio_imported_modules,tcl_file,type_io_state)

                # (module_name,tcl_file)
                    = freads tcl_file s
                # (module_name_offset,type_io_state)
                    = insert_name No No module_name type_io_state
                = read_directly_imported_modules (inc i) n_imported_modules { tio_imported_modules & [i] = module_name_offset } type_io_state tcl_file

instance ReadTypeInfo (TIO_TypeDef a) | ReadTypeInfo a & DefaultElem a
where
    read_type_info tcl_file type_io_state=:{tis_current_module_i,tis_current_def_i}
        // td_name
        #! (ok1,_,id_name_index,tcl_file,type_io_state)
            = read_ident (Yes (tis_current_module_i,tis_current_def_i)) tcl_file type_io_state
        | not ok1
            = (False,default_elem,tcl_file,type_io_state)
            
        // td_arity
        #! (ok2,td_arity,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        | not ok2
            = (False,default_elem,tcl_file,type_io_state)
            
        // td_args
        #! (ok2,td_args,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        | not ok2
            = (False,default_elem,tcl_file,type_io_state)

        // td_rhs
        #! (ok2,td_rhs,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        | not ok2
            = (False,default_elem,tcl_file,type_io_state)

        # type_def
            = updateTypeDefRhs { default_elem &
                tio_td_name     = id_name_index
            ,   tio_td_arity    = td_arity
            ,   tio_td_args     = td_args
            } td_rhs
        = (ok1,type_def,tcl_file,type_io_state)

updateTypeDefRhs :: (TIO_TypeDef a) a -> (TIO_TypeDef a)
updateTypeDefRhs type_def rhs
    =   {type_def & tio_td_rhs = rhs}

instance ReadTypeInfo TIO_ConstructorSymbol
where
	read_type_info tcl_file type_io_state
        # (ok,cons,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        | not ok
            = (False,default_elem,tcl_file,type_io_state)
		=	(True,{tio_cons=cons},tcl_file,type_io_state)

instance ReadTypeInfo TIO_TypeRhs
where
    read_type_info tcl_file type_io_state
        # (ok1,c,tcl_file)
            = freadc tcl_file
        | not ok1
            = (False,default_elem,tcl_file,type_io_state)
        | c == AlgTypeCode
            # (ok,defined_symbols,tcl_file,type_io_state)
                = read_type_info tcl_file type_io_state
            = (ok,TIO_AlgType defined_symbols,tcl_file,type_io_state)
        | c == SynTypeCode
            = (True,TIO_SynType default_elem,tcl_file,type_io_state)
        | c == RecordTypeCode
            # (ok1,rt_constructor,tcl_file,type_io_state)
                = read_type_info tcl_file type_io_state
            # (ok2,rt_fields,tcl_file,type_io_state)
                = read_type_info tcl_file type_io_state
            # record_type = { tio_rt_constructor = rt_constructor, tio_rt_fields = rt_fields };
            = (ok1 && ok2,TIO_RecordType record_type,tcl_file,type_io_state)
		| c == GenericDictionaryTypeCode
            # (ok1,rt_constructor,tcl_file,type_io_state)
                = read_type_info tcl_file type_io_state
            # (ok2,rt_fields,tcl_file,type_io_state)
                = read_type_info tcl_file type_io_state 
            # record_type = { tio_rt_constructor = rt_constructor, tio_rt_fields = rt_fields };
            = (ok1 && ok2,TIO_GenericDictionaryType record_type,tcl_file,type_io_state)
        | c == AbstractTypeCode
            = (True,TIO_AbstractType default_elem,tcl_file,type_io_state)

instance ReadTypeInfo TIO_DefinedSymbol
where
    read_type_info tcl_file type_io_state
        # (ok1,_,ident_name_index,tcl_file,type_io_state)
            = read_ident No tcl_file type_io_state            
        | not ok1
            = (False,default_elem,tcl_file,type_io_state)
            
        // ds_arity
        # (ok2,ds_arity,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        | not ok2
            = (False,default_elem,tcl_file,type_io_state)
        
        // ds_index
        # (ok3,ds_index,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        
        # defined_symbol
            = { default_elem &
                tio_ds_ident    = ident_name_index
            ,   tio_ds_arity    = ds_arity
            ,   tio_ds_index    = ds_index
            }
        = (ok3,defined_symbol,tcl_file,type_io_state)
        
instance ReadTypeInfo TIO_ConsDef 
where
    read_type_info tcl_file type_io_state
        # (ok1,_,cons_symb,tcl_file,type_io_state)
            = read_ident No tcl_file type_io_state
        # (ok2,cons_type,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        # (ok3,cons_type_index,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        # (ok4,cons_exi_vars,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        # consdef
            = { default_elem &
                tio_cons_symb           = cons_symb
            ,   tio_cons_type           = cons_type
            ,   tio_cons_type_index     = cons_type_index
            ,   tio_cons_exi_vars       = cons_exi_vars
            }
        = (ok1&&ok2&&ok3&&ok4,consdef,tcl_file,type_io_state)
        
instance ReadTypeInfo Char
where
    read_type_info tcl_file type_io_state
        # (ok,c,tcl_file)
            = freadc tcl_file
        = (ok,c,tcl_file,type_io_state)

// reading tcl-file
read_ident :: (Optional (Int,Int)) !*File !*TypeIOState -> *(!Bool,!{#Char},!Int,!*File,!*TypeIOState)
read_ident opt_type_ref tcl_file type_io_state=:{tis_reading_typ_file=False}
    # (ok1,i,tcl_file)
        = freadi tcl_file
    # (id_name,tcl_file)
        = freads tcl_file i;    
    # (id_name_index,type_io_state)
        = insert_name No opt_type_ref id_name type_io_state
    = (ok1,id_name,id_name_index,tcl_file,type_io_state)

read_ident _ tcl_file type_io_state
    # (ok1,i,tcl_file)
        = freadi tcl_file
    = (ok1,"",i,tcl_file,type_io_state)

instance ReadTypeInfo TIO_ATypeVar
where
    read_type_info tcl_file type_io_state
        // atv_variable
        # (ok2,atv_variable,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        | not ok2
            = (False,default_elem,tcl_file,type_io_state)
        # atypevar = {default_elem & tio_atv_variable = atv_variable}
        = (True,atypevar,tcl_file,type_io_state)
        
instance ReadTypeInfo TIO_TypeVar
where
    read_type_info tcl_file type_io_state
        # (ok1,tv_name,tcl_file)
            = freadi tcl_file
        # typevar = {default_elem & tio_tv_name = tv_name}
        = (ok1,typevar,tcl_file,type_io_state)

instance ReadTypeInfo TIO_Annotation
where
    read_type_info tcl_file type_io_state
        #! (ok1,c,tcl_file)
            = freadc tcl_file
        # annotation
            = if (c == '!') TIO_AN_Strict TIO_AN_None
        = (ok1,annotation,tcl_file,type_io_state)
        
instance ReadTypeInfo TIO_FieldSymbol
where
    read_type_info tcl_file type_io_state
		# (ok1,_,fs_name,tcl_file,type_io_state)
			= read_ident No tcl_file type_io_state
		# field_symbol = { TIO_FieldSymbol | tio_fs_name = fs_name }
		= (ok1,field_symbol,tcl_file,type_io_state)

instance ReadTypeInfo TIO_SymbolType
where 
    read_type_info tcl_file type_io_state
        # (ok1,st_vars,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        # (ok2,st_args,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        # (ok3,st_args_strictness,tcl_file,type_io_state)
        	= read_type_info tcl_file type_io_state
        # (ok4,st_arity,tcl_file, type_io_state)
            = read_type_info tcl_file type_io_state
        # (ok5,st_result,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
            
        # symbol_type
            = { default_elem &
                tio_st_vars				= st_vars
            ,   tio_st_args				= st_args
            ,	tio_st_args_strictness	= st_args_strictness
            ,   tio_st_arity			= st_arity
            ,   tio_st_result			= st_result
            }
        = (ok1&&ok2&&ok3&&ok4&&ok5,symbol_type,tcl_file,type_io_state)
        
instance ReadTypeInfo StrictnessList
where 
	read_type_info tcl_file type_io_state
        # (ok,c,tcl_file)
            = freadc tcl_file
        | not ok
            = (False,default_elem,tcl_file,type_io_state)
            
        | c == NotStrictCode
        	= (True,NotStrict,tcl_file,type_io_state)
        | c == StrictCode
        	# (ok,i,tcl_file)
        		= freadi tcl_file
        	= (ok,Strict i,tcl_file,type_io_state)
        | c == StrictListCode
        	# (ok1,i,tcl_file)
        		= freadi tcl_file
        	# (ok2,tail,tcl_file,type_io_state)
        		= read_type_info tcl_file type_io_state
        	= (ok1&&ok2,StrictList i tail,tcl_file,type_io_state)
        	
        	= abort ("instance ReadTypeInfo StrictnessList; " +++ toString (toInt c));
				
instance ReadTypeInfo TIO_AType
where 
    read_type_info tcl_file type_io_state
        # (ok2,at_type,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        # atype = {default_elem & tio_at_type = at_type}
        = (ok2,atype,tcl_file,type_io_state)
        
instance ReadTypeInfo TIO_Type
where
    read_type_info tcl_file type_io_state=:{tis_reading_typ_file}
        # (ok,c,tcl_file)
            = freadc tcl_file
        | not ok
            = (False,default_elem,tcl_file,type_io_state)
     
        | c == TypeTASCode
            # (ok1,type_symb_ident,tcl_file,type_io_state)
                = read_type_info tcl_file type_io_state
            | tis_reading_typ_file
	            # (ok2,atypes,tcl_file,type_io_state)
    	            = read_type_info tcl_file type_io_state
        	    # (ok3,strictness,tcl_file,type_io_state)
            	    = read_type_info tcl_file type_io_state
				= (ok1 && ok2 && ok3,TIO_TAS type_symb_ident atypes strictness,tcl_file,type_io_state)

				# (ok2,global_index,tcl_file,type_io_state)
					= read_type_info tcl_file type_io_state
				# (ok3,atypes,tcl_file,type_io_state)
					= read_type_info tcl_file type_io_state
				# (ok4,strictness,tcl_file,type_io_state)
					= read_type_info tcl_file type_io_state
				= (ok1 && ok2 && ok3 && ok4,TIO_TAS_tcl type_symb_ident global_index atypes strictness,tcl_file,type_io_state)

        | c == TypeArrowCode
            # (ok1,atype1,tcl_file,type_io_state)
                = read_type_info tcl_file type_io_state
            # (ok2,atype2,tcl_file,type_io_state)
                = read_type_info tcl_file type_io_state
            = (ok1&&ok2,atype1 ----> atype2,tcl_file,type_io_state)

        | c == TypeConsApplyCode
            # (ok1,cons_variable,tcl_file,type_io_state)
                = read_type_info tcl_file type_io_state
            # (ok2,atypes,tcl_file,type_io_state)
                = read_type_info tcl_file type_io_state
            = (ok1&&ok2,cons_variable :@@: atypes,tcl_file,type_io_state)
    
        | c == BT_IntCode
            = (True,TIO_TB TIO_BT_Int,tcl_file,type_io_state);
        | c == BT_CharCode
            = (True,TIO_TB TIO_BT_Char,tcl_file,type_io_state);
        | c == BT_RealCode
            = (True,TIO_TB TIO_BT_Real,tcl_file,type_io_state);
        | c == BT_BoolCode
            = (True,TIO_TB TIO_BT_Bool,tcl_file,type_io_state);
        | c == BT_DynamicCode
            = (True,TIO_TB TIO_BT_Dynamic,tcl_file,type_io_state);
        | c == BT_FileCode
            = (True,TIO_TB TIO_BT_File,tcl_file,type_io_state);
        | c == BT_WorldCode
            = (True,TIO_TB TIO_BT_World,tcl_file,type_io_state);
        | c == BT_StringCode
            # (ok,type,tcl_file,type_io_state)
                = read_type_info tcl_file type_io_state     
            = (ok,TIO_TB (TIO_BT_String type),tcl_file,type_io_state);
                
        | c == TypeGTVCode
            # (ok,type_var,tcl_file,type_io_state)
                = read_type_info tcl_file type_io_state 
            = (ok,TIO_GTV type_var,tcl_file,type_io_state);
            
        | c == TypeTVCode
            # (ok,type_var,tcl_file,type_io_state)
                = read_type_info tcl_file type_io_state     
            = (ok,TIO_TV type_var,tcl_file,type_io_state)
            
        | c == TypeTQVCode
			# (ok,type_var,tcl_file,type_io_state)
				= read_type_info tcl_file type_io_state     
			= (ok,TIO_TQV type_var,tcl_file,type_io_state)

		| c == GenericFunctionTypeCode
			# (ok1,kind_length,tcl_file) = freadi tcl_file
			  (kind,tcl_file) = freads tcl_file kind_length;
			  (ok2,symbol_type,tcl_file,type_io_state) = read_type_info tcl_file type_io_state
			= (ok1 && size kind==kind_length && ok2,TIO_GenericFunction kind symbol_type,tcl_file,type_io_state)

		| c == TypeTECode
			= (True,TIO_TE,tcl_file,type_io_state)

			# (j,tcl_file) = fposition tcl_file
            = abort ("<" +++ toString j +++ "   error " +++ toString (toInt c) +++ (if tis_reading_typ_file " typ file is being read" ""))
            
instance ReadTypeInfo TIO_ConsVariable
where
    read_type_info tcl_file type_io_state
        # (ok,cv,tcl_file)
            = freadc tcl_file
        | cv == ConsVariableCVCode
            # (ok1,cons_variable_cv_code,tcl_file,type_io_state)
                = read_type_info tcl_file type_io_state
            = (ok1,TIO_CV cons_variable_cv_code,tcl_file,type_io_state)
            
        | cv == ConsVariableTempCVCode
            # (ok1,cons_variable_tempcv_code,tcl_file,type_io_state)
                = read_type_info tcl_file type_io_state
            = (ok1,TIO_TempCV cons_variable_tempcv_code,tcl_file,type_io_state)
            
        | cv == ConsVariableTempQCVCode
            # (ok1,cons_variable_tempqcv_code,tcl_file,type_io_state)
                = read_type_info tcl_file type_io_state
            = (ok1,TIO_TempQCV cons_variable_tempqcv_code,tcl_file,type_io_state)

instance ReadTypeInfo TIO_GlobalIndex
where
    read_type_info tcl_file type_io_state
        # (ok1,tio_glob_object,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        # (ok2,tio_glob_module,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
            
        # tio_global
            = { TIO_GlobalIndex |
                tio_glob_object		= tio_glob_object
            ,   tio_glob_module		= tio_glob_module
            }
        = (ok1&&ok2,tio_global,tcl_file,type_io_state)

instance ReadTypeInfo TIO_TypeSymbIdent
where
    // used to read a Clean Type file (.tcl)
    read_type_info tcl_file type_io_state=:{tis_reading_typ_file=False}
        # (ok1,c,tcl_file)
            = freadc tcl_file
        # (ok2,type_as_string,type_name,tcl_file,type_io_state)
            = read_ident No tcl_file type_io_state
        # (ok3,type_arity,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
		# tio_type_ref
			= { 
				tio_type_without_definition = if (c == TypeSymbIdentWithoutDefinition) (Just type_as_string) Nothing
			,	tio_tr_module_n 			= type_name
			,	tio_tr_type_def_n 			= type_name
			}
        # type_symb_ident
            = { default_elem &
                tio_type_name_ref	= tio_type_ref
            ,   tio_type_arity		= type_arity
            }
		= (ok1&&ok2&&ok3,type_symb_ident,tcl_file,type_io_state)

    // reading .typ-file
    read_type_info tcl_file type_io_state
        # (ok1,tio_type_name_ref,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        # (ok2,tio_type_arity,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        # type_symb_ident
            = { default_elem &
                tio_type_name_ref   = tio_type_name_ref
            ,   tio_type_arity      = tio_type_arity
            }
        = (ok1&&ok2,type_symb_ident,tcl_file,type_io_state)

	// only in case of .type-file
instance ReadTypeInfo TIO_TypeReference
where
    read_type_info tcl_file type_io_state
        # (ok1,tio_type_without_definition,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        # (ok2,tio_tr_module_n,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        # (ok3,tio_tr_type_def_n,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
            
        # tio_type_reference
            = { default_elem &
            	tio_type_without_definition	= tio_type_without_definition
            ,   tio_tr_module_n				= tio_tr_module_n
            ,   tio_tr_type_def_n			= tio_tr_type_def_n
            }
        = (ok1&&ok2&&ok3,tio_type_reference,tcl_file,type_io_state)
                
// basic and structural write_type_info's
instance ReadTypeInfo (Maybe a) | ReadTypeInfo a
where 
    read_type_info tcl_file type_io_state
        # (ok,c,tcl_file)
            = freadc tcl_file
        | not ok
            = (False,default_elem,tcl_file,type_io_state)

		| c == MaybeNoneCode
			= (ok,Nothing,tcl_file,type_io_state)
		| c == MaybeJustCode
	        # (ok,a,tcl_file,type_io_state)
	            = read_type_info tcl_file type_io_state
	        = (ok,Just a,tcl_file,type_io_state)

instance ReadTypeInfo Int
where 
    read_type_info tcl_file type_io_state
        # (ok,i,tcl_file)
            = freadi tcl_file           
        = (ok,i,tcl_file,type_io_state)
    
instance ReadTypeInfo {#b} | ReadTypeInfo b & DefaultElem b & Array {#} b
where 
    read_type_info tcl_file type_io_state
        # (ok,s_unboxed_array,tcl_file)
            = freadi tcl_file
        | not ok
            = (False,{default_elem},tcl_file,type_io_state)
        # unboxed_array
            = { default_elem \\ i <- [1..s_unboxed_array] }
        = read_type_info_loop 0 s_unboxed_array tcl_file unboxed_array type_io_state
    where
        read_type_info_loop i limit tcl_file unboxed_array type_io_state
            | i == limit
                = (True,unboxed_array,tcl_file,type_io_state)
            # (ok,elem,tcl_file,type_io_state)
                = read_type_info tcl_file { type_io_state & tis_current_def_i = i };
            | not ok
                = (False,unboxed_array,tcl_file,type_io_state)                
                = read_type_info_loop (inc i) limit tcl_file {unboxed_array & [i] = elem} type_io_state

instance ReadTypeInfo {b} | ReadTypeInfo b & DefaultElem b & Array {} b
where 
    read_type_info tcl_file type_io_state
        # (ok,s_unboxed_array,tcl_file)
            = freadi tcl_file
        | not ok
            = (False,{default_elem},tcl_file,type_io_state)
        # unboxed_array
            = { default_elem \\ i <- [1..s_unboxed_array] }
        = read_type_info_loop 0 s_unboxed_array tcl_file unboxed_array type_io_state
    where
        read_type_info_loop i limit tcl_file unboxed_array type_io_state
            | i == limit
                = (True,unboxed_array,tcl_file,type_io_state)                
            # (ok,elem,tcl_file,type_io_state)
                = read_type_info tcl_file { type_io_state & tis_current_def_i = i };
            | not ok
                = (False,unboxed_array,tcl_file,type_io_state)
                = read_type_info_loop (inc i) limit tcl_file {unboxed_array & [i] = elem} type_io_state

instance ReadTypeInfo [a] | ReadTypeInfo a
where
    read_type_info tcl_file type_io_state
        # (ok1,limit,tcl_file)
            = freadi tcl_file
        | not ok1
            = (False,[],tcl_file,type_io_state)            
        = read_type_info_loop 0 limit tcl_file [] type_io_state
    where
        read_type_info_loop i limit tcl_file elems type_io_state
            | i == limit
                = (True,reverse elems,tcl_file,type_io_state)
            # (ok,elem,tcl_file,type_io_state)
                = read_type_info tcl_file type_io_state
            | not ok 
                = (False,[],tcl_file,type_io_state)
                = read_type_info_loop (inc i) limit tcl_file [elem:elems] type_io_state
               
instance ReadTypeInfo (a,b) | ReadTypeInfo a & ReadTypeInfo b
where
	read_type_info tcl_file type_io_state
		# (a_ok,a,tcl_file,type_io_state)
			= read_type_info tcl_file type_io_state
		# (b_ok,b,tcl_file,type_io_state)
			= read_type_info tcl_file type_io_state
		= (a_ok&&b_ok,(a,b),tcl_file,type_io_state)
    
instance DefaultElem (Maybe a)
where
	default_elem
		= Nothing
		
instance DefaultElem (TIO_TypeDef a) | DefaultElem a
where   
    default_elem
        = { TIO_TypeDef |
            tio_td_name                     = default_elem
        ,   tio_td_arity                    = default_elem
        ,   tio_td_args                     = default_elem
        ,   tio_td_rhs                      = default_elem
        ,   tio_type_equivalence_table_index    = default_elem
        }
    
instance DefaultElem TIO_TypeRhs
where
    default_elem
        = TIO_UnknownType
        
instance DefaultElem TIO_ATypeVar
where
    default_elem
        = {TIO_ATypeVar | tio_atv_variable = default_elem}

instance DefaultElem TIO_TypeVar
where
    default_elem
        = {TIO_TypeVar | tio_tv_name = default_elem}

instance DefaultElem [a]
where
    default_elem
        = []
        
instance DefaultElem TIO_DefinedSymbol
where
    default_elem
        = { TIO_DefinedSymbol |
            tio_ds_ident        = default_elem
        ,   tio_ds_arity        = default_elem
        ,   tio_ds_index        = default_elem
        }
        
instance DefaultElem TIO_ConsDef
where
    default_elem
        = { TIO_ConsDef |
            tio_cons_symb           = default_elem
        ,   tio_cons_type           = default_elem
        ,   tio_cons_type_index     = default_elem
        ,   tio_cons_exi_vars       = default_elem
        }

instance DefaultElem TIO_SymbolType
where
    default_elem
        = { TIO_SymbolType |
            tio_st_vars					= default_elem
        ,   tio_st_args					= default_elem
        ,	tio_st_args_strictness		= default_elem
        ,   tio_st_arity				= default_elem
        ,   tio_st_result				= default_elem
        }       
        
instance DefaultElem StrictnessList
where
	default_elem
		= NotStrict

instance DefaultElem TIO_AType
where
    default_elem
        = {TIO_AType | tio_at_type = default_elem}

instance DefaultElem TIO_Type
where
    default_elem
        = TIO_DefaultElem // TIO_TE
      
instance DefaultElem TIO_Annotation
where
    default_elem
        = TIO_AN_None
        
instance DefaultElem TIO_Assoc
where
    default_elem
        = TIO_NoAssoc
    
instance DefaultElem TIO_RecordType
where
    default_elem
		= {TIO_RecordType | tio_rt_constructor = default_elem, tio_rt_fields = {}}

instance DefaultElem TIO_FieldSymbol
where
    default_elem
        = {TIO_FieldSymbol | tio_fs_name = default_elem}

instance DefaultElem TIO_ConstructorSymbol
where
    default_elem
        = {TIO_ConstructorSymbol | tio_cons = default_elem}

instance DefaultElem TIO_TypeSymbIdent
where
    default_elem
        = { TIO_TypeSymbIdent |
            tio_type_name_ref       = default_elem
        ,   tio_type_arity          = default_elem
        }

instance DefaultElem TIO_GlobalIndex
where
	default_elem
		= { TIO_GlobalIndex |
			tio_glob_object		= default_elem
		,	tio_glob_module		= default_elem
		}
		
instance DefaultElem TIO_CommonDefs
where
    default_elem
        = { TIO_CommonDefs |
            tio_com_type_defs               = {}
        ,   tio_com_cons_defs               = {}
        ,   tio_imported_modules            = {}
        ,   tio_n_exported_com_type_defs    = 0
        ,   tio_n_exported_com_cons_defs    = 0
        ,   tio_module                      = 0
		,	tio_global_module_strings		= {}
        }

instance DefaultElem (Optional a)
where
    default_elem
        = No;

:: EquivalentTypeDef
    = { 
        type_name   :: Int
    ,   partitions  :: !{#{#TIO_TypeReference}}
    };

instance ExtFileSystem (!*File,Int,Int)
where
    rlf_fopen n _ (file,_,_)
        # (ok,n_lines,file)
            = freadi file
        = (ok,file,(stderr,0,n_lines))
        
    rlf_fclose file _
        = (True,(file,-1,-1))
        
    rlf_freadline file (_,line_i,n_lines)
        | line_i == n_lines
            = ({},file,(stderr,line_i,n_lines))
        # (ok,c,file)
            = freadc file
        # (line,file)
            = freads file (toInt c)
        = (line,file,(stderr,inc line_i,n_lines))

:: RTI
    = { 
        rti_n_libraries         :: !Int
    ,   rti_library_list        :: !LibraryList
    ,   rti_n_library_symbols   :: !Int
    };

default_RTI :: RTI;
default_RTI
    = { RTI |
        rti_n_libraries         = 0 
    ,   rti_library_list        = EmptyLibraryList
    ,   rti_n_library_symbols   = 0
    };

read_type_information typ_file_name names_table files :== read_type_information_new True typ_file_name names_table files;

read_type_information_new :: !Bool !String !*NamesTable !*Files -> (!Bool,!RTI,!*{#TIO_CommonDefs},!*TypeIOState,!*NamesTable,!*Files)
read_type_information_new use_names_table typ_file_name names_table files
    # (ok,typ_file,files)
        = fopen typ_file_name FReadData files
    | not ok
        = abort ("Error opening type file '" +++ typ_file_name +++ "'");
        
    // read contents of libraries
    # (ok,n_libraries,typ_file)
        = freadi typ_file
    # library_file_names = [ typ_file_name \\ i <- [1..n_libraries] ]
    # (read_library_errors,library_list,n_library_symbols,(typ_file,_,_),names_table)
        = read_library_files_new use_names_table library_file_names (~n_libraries) 0 (typ_file,0,0) names_table;

    # type_io_state = {default_type_io_state & tis_reading_typ_file = True};
    # (ok1,tio_common_defs,typ_file,type_io_state)
        = read_type_info typ_file type_io_state
    # tio_common_defs3
        = tio_common_defs2 tio_common_defs
    # (ok2,typ_file,tio_common_defs3,type_io_state)
        = read_and_initialize_type_io_state tio_common_defs3 typ_file
    # ok2 = True
    # (_,files)
        = fclose typ_file files
        
    # rti
        = { default_RTI &
            rti_n_libraries         = n_libraries 
        ,   rti_library_list        = library_list
        ,   rti_n_library_symbols   = n_library_symbols
        };
        
    = (ok1&&ok2,rti,tio_common_defs3,type_io_state,names_table,files)
where
    tio_common_defs2 :: !{#TIO_CommonDefs} -> *{#TIO_CommonDefs}
    tio_common_defs2 tio_common_defs
        = { tio_common_def \\ tio_common_def <-: tio_common_defs }

read_and_initialize_type_io_state :: !*{#TIO_CommonDefs} !*File -> (!Bool,*File,!*{#TIO_CommonDefs},!*TypeIOState)
read_and_initialize_type_io_state tio_common_defs typ_file
    // n_common_defs
    # (tis_n_common_defs,tio_common_defs) = usize tio_common_defs
        
    // string table
    # (ok1,s_tis_string_table,typ_file)
        = freadi typ_file
    # (tis_string_table,typ_file)
        = freads typ_file s_tis_string_table
    | not ok1
        = (False,typ_file,tio_common_defs,default_type_io_state)
        
    // equivalent type definitions
    # (ok2,tis_equivalent_type_definitions,typ_file,type_io_state)
        = read_type_info typ_file default_type_io_state 

    # type_io_state
        = { default_type_io_state &
        // from disk ...
            tis_string_table                = tis_string_table
        ,   tis_equivalent_type_definitions = tis_equivalent_type_definitions
        ,   tis_n_common_defs               = tis_n_common_defs
        // ... from disk
        }
    # (tio_common_defs,type_io_state)
        = initialize_type_io_state tio_common_defs type_io_state
        
    = (True,typ_file,tio_common_defs,type_io_state)
    
instance ReadTypeInfo EquivalentTypeDef
where 
    read_type_info tcl_file type_io_state
        # (ok1,type_name,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        # (ok2,partitions,tcl_file,type_io_state)
            = read_type_info tcl_file type_io_state
        # equivalent_type_def = {default_elem & type_name = type_name, partitions = partitions}
        = (ok1&&ok2,equivalent_type_def,tcl_file,type_io_state)
        
instance DefaultElem EquivalentTypeDef
where
	default_elem
		= {EquivalentTypeDef | type_name = default_elem, partitions  = default_elem}

initialize_type_io_state :: !*{#TIO_CommonDefs} !*TypeIOState -> (!*{#TIO_CommonDefs},!*TypeIOState)
initialize_type_io_state tio_common_defs type_io_state=:{tis_n_common_defs=n_common_defs}
    # max_types_per_module
		= createArray n_common_defs 0;
    # (max_types,max_types_per_module,tio_common_defs)
		= build_type_equivalent_index_array 0 n_common_defs 0 max_types_per_module tio_common_defs;
    # type_io_state = {type_io_state &
        // used during type definition checks
            tis_max_types_per_module	= max_types_per_module
        ,   tis_max_types				= max_types
        }
    = (tio_common_defs,type_io_state)
where
    build_type_equivalent_index_array :: !Int !Int !Int !*{#Int} !*{#TIO_CommonDefs} -> *(!Int,!*{#Int},!*{#TIO_CommonDefs});
    build_type_equivalent_index_array i limit max_types max_types_per_module tio_common_defs
        | i == limit
            = (max_types,max_types_per_module,tio_common_defs);
        # (tio_common_def,tio_common_defs) = tio_common_defs![i];
        # n_types = size tio_common_def.tio_com_type_defs;
        = build_type_equivalent_index_array (inc i) limit (max_types + n_types) { max_types_per_module & [i] = max_types} tio_common_defs;

get_name_from_string_table :: !Int !String -> String
get_name_from_string_table index string_table
    | index < 0 || index >= (size string_table)
        = abort "index out of range in get_name_from_string_table";
    # (ok,null_index)
        = CharIndex string_table index '\0'
    | not ok
        = abort "get_name_from_string_table: corrupt, string not terminated with a null" 
    = (string_table % (index,dec null_index));
