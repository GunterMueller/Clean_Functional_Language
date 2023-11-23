/*
	module owner: Ronny Wichers Schreur
*/
implementation module TypeEquivalences

import StdEnv
from utilities import foldSt, mapSt
from containers import equal_strictness_lists
import type_io_read
import StdDynamicTypes, StdMaybe

(:-) infixl 9
(:-) x f
	=	f x

:: NamedType =
	{	nt_name :: !{#Char}
	,	nt_type :: !TIO_TypeReference
	}

nameType :: {#Char} {#TIO_CommonDefs} TIO_TypeReference -> NamedType
nameType string_table defs type_ref =
	{	nt_name = type_name string_table defs type_ref
	,	nt_type = type_ref
	}

instance < NamedType where
	(<) a b
		=	a.nt_name < b.nt_name

:: TypeComponent =
	{	tc_lib_instance_n :: !Int
	,	tc_name :: !{#Char}
	,	tc_component :: ![NamedType]
	}

:: TypeComponents
	:==	.HashTable {#Char} [TypeComponent]

initComponents :: .TypeComponents
initComponents
	=	initHashTable

:: LibraryRef =
	{	lr_library :: !Int
	,	lr_ref :: !TIO_GlobalIndex
	}

undefinedLibRef
	=	{	lr_library = -1
		,	lr_ref = {tio_glob_object = -1, tio_glob_module = -1}
		}

instance == LibraryRef where
	(==) a b
		=	a.lr_library == b.lr_library
		&&	a.lr_ref == b.lr_ref

:: Map
	:==	{#.{#LibraryRef}}
:: SymbolsMap
	:==	{#.{!Maybe [({#Char}, (Int, Int))]}}

:: LibInstance =
	{	li_string_table :: !{#Char}
	,	li_defs :: !{#TIO_CommonDefs}
	,	li_type_map :: !.Map
	,	li_cons_map :: !.Map
	}

dummyLibInstance
	=	{	li_string_table = ""
		,	li_defs = {}
		,	li_type_map = {}
		,	li_cons_map = {}
		}

initLibInstance :: {#Char} {#TIO_CommonDefs} -> .LibInstance
initLibInstance string_table defs
	=	{	dummyLibInstance
		&	li_string_table = string_table
		,	li_defs = defs
		,	li_type_map = type_map
		,	li_cons_map = cons_map
		}
	where
		type_map
			=	{create_map types \\ {tio_com_type_defs=types} <-: defs}
		cons_map
			=	{create_map conses \\ {tio_com_cons_defs=conses} <-: defs}
		create_map a
			=	createArray (size a) undefinedLibRef

:: LibInstances
	:==	GrowingArray LibInstance
:: LibEquivalences
	:==	GrowingArray [Replacement LibraryInstanceTypeReference]

addInstance :: Int LibInstance *LibInstances -> *LibInstances
addInstance index lib_instance instances
	=	setGrowingArray index lib_instance instances

fillComponentMap :: !TypeComponent LibInstance TypeComponent *LibInstance
	-> *LibInstance
fillComponentMap to to_inst frm frm_inst
	=	fillMap to.tc_lib_instance_n to.tc_component to_inst
			frm.tc_component frm_inst

class fillMap a :: !Int !a !LibInstance !a !*LibInstance -> *LibInstance

instance fillMap [a] | fillMap a where
	fillMap to_i [] to_inst [] frm_inst
		=	frm_inst
	fillMap to_i [t:ts] to_inst [f:fs] frm_inst
		=	frm_inst
		:-	fillMap to_i t to_inst f
		:-	fillMap to_i ts to_inst fs

instance fillMap NamedType where
	fillMap to_i to to_inst frm frm_inst
		=	fillMap to_i to.nt_type to_inst frm.nt_type frm_inst

instance fillMap TIO_TypeReference where
	fillMap _ {tio_type_without_definition=Just _} _ _ frm_inst
		=	frm_inst
	fillMap to_i {tio_tr_module_n=to_mod, tio_tr_type_def_n=to_type} to_inst
			{tio_tr_module_n=frm_mod, tio_tr_type_def_n=frm_type} frm_inst
		# (to_type_def, to_inst)
			=	to_inst!li_defs.[to_mod].tio_com_type_defs.[to_type]
		# (frm_type_def, frm_inst)
			=	frm_inst!li_defs.[frm_mod].tio_com_type_defs.[frm_type]
		=	{frm_inst & li_type_map.[frm_mod, frm_type] = to_ref}
		:-	fillMapModule to_i to_mod to_type_def to_inst frm_mod frm_type_def
		where
			to_ref
				=	{ lr_library = to_i
					, lr_ref = {tio_glob_object=to_type, tio_glob_module=to_mod}
					}

class fillMapModule a :: !Int !Int !a !LibInstance !Int !a
							!*LibInstance -> *LibInstance

instance fillMapModule [a] | fillMapModule a where
	fillMapModule _ _ [] _ _ [] frm_inst
		=	frm_inst
	fillMapModule to_i to_mod [t:ts] to_inst frm_mod [f:fs] frm_inst
		=	frm_inst
		:-	fillMapModule to_i to_mod t to_inst frm_mod f
		:-	fillMapModule to_i to_mod ts to_inst frm_mod fs

instance fillMapModule {#e} | fillMapModule e & Array {#} e where
	fillMapModule to_i to_mod to to_inst frm_mod frm frm_inst
		=	fillMapModule to_i to_mod [e \\ e <-: to] to_inst
				frm_mod [e \\ e <-: frm] frm_inst

instance fillMapModule (TIO_TypeDef a) | fillMapModule a where
	fillMapModule to_i to_mod to to_inst frm_mod frm frm_inst
		=	fillMapModule to_i to_mod to.tio_td_rhs to_inst
				frm_mod frm.tio_td_rhs frm_inst

instance fillMapModule TIO_TypeRhs where
	fillMapModule to_i to_mod (TIO_AlgType to_conses) to_inst
			frm_mod (TIO_AlgType frm_conses) frm_inst
		// assume constructors are in same order (contrary to old algorithm)
		=	fillMapModule to_i to_mod to_conses to_inst
				frm_mod frm_conses frm_inst
	fillMapModule to_i to_mod (TIO_RecordType to_record) to_inst
		frm_mod (TIO_RecordType frm_record) frm_inst
		=	fillMapModule to_i to_mod to_record to_inst
				frm_mod frm_record frm_inst
	fillMapModule to_i to_mod (TIO_GenericDictionaryType to_record) to_inst
		frm_mod (TIO_GenericDictionaryType frm_record) frm_inst
		=	fillMapModule to_i to_mod to_record to_inst
				frm_mod frm_record frm_inst
	fillMapModule _ _ _ _ _ _ frm_inst
		=	frm_inst

instance fillMapModule TIO_ConstructorSymbol where
	fillMapModule to_i to_mod {tio_cons={tio_ds_index=to_cons}} to_inst
					  frm_mod {tio_cons={tio_ds_index=frm_cons}} frm_inst
		# cons_ref = { lr_library = to_i+1, lr_ref = {tio_glob_object=to_cons, tio_glob_module=to_mod} }
		= {frm_inst & li_cons_map.[frm_mod, frm_cons] = cons_ref}

instance fillMapModule TIO_RecordType where
	fillMapModule to_i to_mod {tio_rt_constructor={tio_ds_index=to_cons}} to_inst
					  frm_mod {tio_rt_constructor={tio_ds_index=frm_cons}} frm_inst
		# cons_ref = { lr_library = to_i+1, lr_ref = {tio_glob_object=to_cons, tio_glob_module=to_mod} }
		= {frm_inst & li_cons_map.[frm_mod, frm_cons] = cons_ref}

:: TypeEquivalences =
	{	te_n_lib_instances :: !Int
	,	te_lib_instances :: !.LibInstances
	,	te_lib_equivalences :: !.LibEquivalences
	,	te_lib_symbols :: !.{.SymbolsMap}
	,	te_components :: !.TypeComponents
	}

newTypeEquivalences :: .TypeEquivalences
newTypeEquivalences =
	{	te_n_lib_instances = 0
	// +++ combine these two arrays
	,	te_lib_instances = init dummyLibInstance
	,	te_lib_equivalences = init []
	,	te_components = initComponents
	,	te_lib_symbols = {undef \\ _ <- [0..100-1]} // FIXME
	}
	where
		init value
			=	initGrowingArray 10 2 1 10 value

class findComponent a :: TypeComponent a
	u:(v:LibInstances, w:LibInstance)
		-> ((!Bool, !TypeComponent), u:(v:LibInstances, w:LibInstance))

instance findComponent (Maybe a) | findComponent a where
	findComponent component Nothing st
		=	((False, component), st)
	findComponent component (Just components) st
		=	findComponent component components st

instance findComponent [a] | findComponent a where
	findComponent component [] st
		=	((False, component), st)
	findComponent component [h:tl] st
		# ((found, component), st)
			=	findComponent component h st
		| found
			=	((found, component), st)
		// otherwise
			=	findComponent component tl st

instance findComponent TypeComponent where
	findComponent component existing st=:(instances, frm_instance)
		# inst
			=	eq_info component.tc_lib_instance_n frm_instance
					existing.tc_lib_instance_n instances
		| equivalent_types inst component existing
			=	((True, existing), st)
		// otherwise
			=	((False, component), st)
		where
			eq_info :: !Int !LibInstance !Int !LibInstances -> EqInfo
			eq_info new_lib new exist_lib instances
				| new_lib == exist_lib
					=	{exist_instance=new, new_instance=new}
				// otherwise
					# (exist, instances)
						=	getGrowingArray exist_lib instances
					=	{exist_instance=exist, new_instance=new}

addComponent :: TypeComponent (*LibInstance, [Replacement TypeComponent],
		*TypeEquivalences) 
			-> (*LibInstance, [Replacement TypeComponent], *TypeEquivalences)
addComponent frm_component (frm_inst, replacements, tes)
	# te_components
		=	tes.te_components
	# (maybe_components, te_components)
		=	getHashTable frm_component.tc_name te_components
	# tes
		=	{tes & te_components = te_components}
	# ((found, to_component), (instances, frm_inst))
		=	findComponent frm_component maybe_components
				(tes.te_lib_instances, frm_inst)
	# tes
		=	{tes & te_lib_instances = instances}
	# (to_inst, tes)
		=	tes!te_lib_instances.ga_array.[to_component.tc_lib_instance_n]
	# frm_inst
		=	fillComponentMap to_component to_inst frm_component frm_inst
	| found
		# replacements
			=	[{frm=frm_component,to=to_component} : replacements]
		=	(frm_inst, replacements, tes)
	// otherwise
		# components
			=	add_component frm_component maybe_components
		# te_components
			=	setHashTable frm_component.tc_name components tes.te_components
		=	(frm_inst, replacements, {tes & te_components = te_components})
	where
		add_component c Nothing
			=	[c]
		add_component c (Just l)
			=	[c : l]

addTypeEquivalences :: !Int !Int !{#Char} !{#TIO_CommonDefs} !*TypeEquivalences
	-> *TypeEquivalences
addTypeEquivalences lib_instance_n type_table_n string_table defs tes
	# lib_instance_n
		=	lib_instance_n-1
	| lib_instance_n <> type_table_n
		=	abort "addTypeEquivalences: indices out of sync"
	| lib_instance_n <> tes.te_n_lib_instances
		=	abort "addTypeEquivalences: out of order library instance"
	# lib_instance
		=	initLibInstance string_table defs
	# tes
		=	{	tes
			&	te_n_lib_instances = tes.te_n_lib_instances+1
			,	te_lib_instances = addInstance tes.te_n_lib_instances
						lib_instance tes.te_lib_instances
			,	te_lib_equivalences = setGrowingArray lib_instance_n
						[] tes.te_lib_equivalences
			}
	# lib_instance
		=	initLibInstance string_table defs
	# components
		=	typeComponents lib_instance_n string_table defs
	# (lib_instance, rc, tes)
		=	foldSt addComponent components (lib_instance, [], tes)
	# replacements
		=	concat (map replaceTypes rc)
	=	{	tes
		&	te_lib_instances.ga_array.[lib_instance_n] = lib_instance
		,	te_lib_equivalences.ga_array.[lib_instance_n] = replacements
		,	te_lib_symbols.[lib_instance_n] = symbols_map
		}
	where
		replaceTypes {frm, to}
			=	[	{frm=conv frm frmT,to=conv to toT}
				\\	{nt_type=frmT} <- frm.tc_component
				&	{nt_type=toT} <- to.tc_component
				]
			where
				conv tc ref
					=	LIT_TypeReference (LibRef (tc.tc_lib_instance_n+1)) ref
		symbols_map
			=	{create_symbols types \\ {tio_com_type_defs=types} <-: defs}
		create_symbols a
			| False
				=	undef
			=	createArray (size a) Nothing

getTypeEquivalences :: !Int u:TypeEquivalences
	-> ([Replacement LibraryInstanceTypeReference], u:TypeEquivalences)
getTypeEquivalences lib_instance_n tes
	# lib_instance_n
		=	lib_instance_n-1
	# (replacements, te_lib_equivalences)
		=	getGrowingArray lib_instance_n tes.te_lib_equivalences
	# tes
		=	{tes & te_lib_equivalences=te_lib_equivalences}
	=	(replacements, tes)

:: EqInfo =
	{	exist_instance :: !LibInstance
	,	new_instance :: !LibInstance
	}

class equivalent_types a :: !EqInfo !a !a -> Bool

instance equivalent_types [a] | equivalent_types a where
	equivalent_types _ [] []
		=	True
	equivalent_types info [a:as] [b:bs]
		=	equivalent_types info a b
		&&	equivalent_types info as bs
	equivalent_types _ _ _
		=	False

instance equivalent_types TypeComponent where
	equivalent_types info a b
		=	a.tc_name == b.tc_name
		&&	equivalent_types info a.tc_component b.tc_component

instance equivalent_types NamedType where
	equivalent_types info a b
		=	a.nt_name == b.nt_name
		&&	equivalent_types info a.nt_type b.nt_type

instance equivalent_types TIO_TypeReference where
	equivalent_types info=:{exist_instance, new_instance} a b
		=	equivalent info
				a.tio_tr_module_n (td new_instance.li_defs a)
				b.tio_tr_module_n (td exist_instance.li_defs b)
		where
			td defs {tio_tr_module_n, tio_tr_type_def_n}
				=	defs.[tio_tr_module_n].tio_com_type_defs.[tio_tr_type_def_n]

class equivalent a :: EqInfo !Int !a !Int !a -> Bool

instance equivalent [a] | equivalent a where
	equivalent _ _ [] _ []
		=	True
	equivalent info am [a:as] bm [b:bs]
		=	equivalent info am a bm b
		&&	equivalent info am as bm bs
	equivalent _ _ _ _ _
		=	False

instance equivalent {#e} | Array {#} e & equivalent e where
	equivalent info am a bm b
		=	size a == size b
		&&	equivalent info am [e \\ e <-: a] bm [e \\ e <-: b]

instance equivalent (TIO_TypeDef a) | equivalent a where
	equivalent info am a bm b
		=	equal_symbols info a.tio_td_name b.tio_td_name
		&&	a.tio_td_arity == b.tio_td_arity
		&&	equivalent_types info a.tio_td_args b.tio_td_args
		&&	equivalent info am a.tio_td_rhs bm b.tio_td_rhs

instance equivalent TIO_TypeRhs where
	equivalent info am (TIO_AlgType a) bm (TIO_AlgType b)
		=	equivalent info am a bm b
	equivalent info am (TIO_RecordType a) bm (TIO_RecordType b)
		=	equivalent info am a bm b
	equivalent info am (TIO_GenericDictionaryType a) bm (TIO_GenericDictionaryType b)
		=	equivalent info am a bm b
	equivalent _ _ _ _ _
		=	False

instance equivalent TIO_ConstructorSymbol where
	equivalent info=:{exist_instance, new_instance} am a bm b
		=	equivalent_types info
				(cons new_instance.li_defs am a)
				(cons exist_instance.li_defs bm b)
		where
			cons defs mod {tio_cons={tio_ds_index}}
				=	defs.[mod].tio_com_cons_defs.[tio_ds_index]

instance equivalent_types TIO_ConsDef where
	equivalent_types info a b
		=	equal_symbols info a.tio_cons_symb b.tio_cons_symb
		&&	equivalent_types info a.tio_cons_type b.tio_cons_type
		&&	equivalent_types info a.tio_cons_exi_vars b.tio_cons_exi_vars

instance equivalent TIO_FieldSymbol where
	equivalent info=:{exist_instance, new_instance} am a bm b
		=	equal_symbols info a.tio_fs_name b.tio_fs_name

instance equivalent TIO_RecordType where
	equivalent info=:{exist_instance,new_instance} am a bm b
		=	equivalent info am a.tio_rt_fields bm b.tio_rt_fields
		&&	equivalent_types info
				new_instance  .li_defs.[am].tio_com_cons_defs.[a.tio_rt_constructor.tio_ds_index]
				exist_instance.li_defs.[bm].tio_com_cons_defs.[b.tio_rt_constructor.tio_ds_index]

instance equivalent_types TIO_SymbolType where
	equivalent_types info a b
		=	equivalent_types info a.tio_st_vars b.tio_st_vars
		&&	equivalent_types info a.tio_st_args b.tio_st_args
		&&	equal_strictness_lists a.tio_st_args_strictness b.tio_st_args_strictness
		&&	equivalent_types info a.tio_st_result b.tio_st_result

instance equivalent_types TIO_ATypeVar where
	equivalent_types info a b
		// where are the attributes???
		=	equivalent_types info a.tio_atv_variable b.tio_atv_variable

instance equivalent_types TIO_TypeVar where
	equivalent_types info a b
		// alpha conversion done at compile time ???
		=	a.tio_tv_name == b.tio_tv_name

instance equivalent_types TIO_AType where
	equivalent_types info a b
		// where are the attributes???
		=	equivalent_types info a.tio_at_type b.tio_at_type

instance equivalent_types TIO_Type where
	equivalent_types info (TIO_TAS ati aa as) (TIO_TAS bti ba bs)
		=	equivalent_types info ati bti
		&&	equivalent_types info aa ba
		&&	equal_strictness_lists as bs
	equivalent_types info (at ----> aa) (bt ----> ba)
		=	equivalent_types info at bt
		&&	equivalent_types info aa ba
	equivalent_types info (TIO_GTV atv) (TIO_GTV btv)
		=	equivalent_types info atv btv
	equivalent_types info (TIO_TV atv) (TIO_TV btv)
		=	equivalent_types info atv btv
	equivalent_types info (TIO_TQV atv) (TIO_TQV btv)
		=	equivalent_types info atv btv
	equivalent_types _ (TIO_TB at) (TIO_TB bt)
		=	at == bt
	equivalent_types info (av :@@: at) (bv :@@: bt)
		=	equivalent_types info av bv
		&&	equivalent_types info at bt
	equivalent_types info (TIO_GenericFunction kind_string1 tio_symbol_type1) (TIO_GenericFunction kind_string2 tio_symbol_type2)
		= kind_string1==kind_string2 && equivalent_types info tio_symbol_type1 tio_symbol_type2
	equivalent_types info TIO_TE TIO_TE
		= True
	equivalent_types _ _ _
		=	False

instance equivalent_types TIO_ConsVariable where
	equivalent_types info (TIO_CV a) (TIO_CV b)
		=	equivalent_types info a b

instance == TIO_BasicType where
	(==) TIO_BT_Int TIO_BT_Int
		=	True
	(==) TIO_BT_Char TIO_BT_Char
		=	True
	(==) TIO_BT_Real TIO_BT_Real
		=	True
	(==) TIO_BT_Bool TIO_BT_Bool
		=	True
	(==) TIO_BT_Dynamic TIO_BT_Dynamic
		=	True
	(==) TIO_BT_File TIO_BT_File
		=	True
	(==) TIO_BT_World TIO_BT_World
		=	True
	(==) (TIO_BT_String _) (TIO_BT_String _)
		=	True
	(==) _ _
		=	False

instance equivalent_types TIO_TypeSymbIdent where
	equivalent_types info a b
		=	equivalent_refs info a.tio_type_name_ref b.tio_type_name_ref
		where
			equivalent_refs _ {tio_type_without_definition=Just a}
									{tio_type_without_definition=Just b}
				=	a == b
			equivalent_refs {exist_instance, new_instance} a=:{tio_type_without_definition=Nothing} b=:{tio_type_without_definition=Nothing}
				=	(a_mapped == undefinedLibRef
				||	a_mapped == b_mapped)
			where
				a_mapped
					=	map_type new_instance a
				b_mapped
					=	map_type exist_instance b
				map_type {li_type_map} {tio_tr_module_n, tio_tr_type_def_n}
					=	li_type_map.[tio_tr_module_n, tio_tr_type_def_n]
			equivalent_refs _ _ _
				= False
			
equal_symbols :: EqInfo Int Int -> Bool
equal_symbols {exist_instance, new_instance} a b
	=	get_name_from_string_table a new_instance.li_string_table
	==	get_name_from_string_table b exist_instance.li_string_table

typeComponents :: Int {#Char} {#TIO_CommonDefs} -> [TypeComponent]
typeComponents lib_instance_n string_table defs
	=	map (type_component lib_instance_n) named_components
	where
		components
			=	sccTypes string_table defs
		named_components
			=	map (map (nameType string_table defs)) components
		type_component lib_instance_n component =
			{	tc_lib_instance_n = lib_instance_n
			,	tc_name = component_name
			,	tc_component = sorted_components
			}
		where
			sorted_components
				=	sort component
			component_name
				=	hd [nt_name \\ {nt_name} <- sorted_components]
//				=	concatStrings [nt_name \\ {nt_name} <- sorted_components]

type_name :: {#Char} {#TIO_CommonDefs} TIO_TypeReference -> {#Char}
type_name string_table defs {tio_tr_module_n, tio_tr_type_def_n}
	= get_name_from_string_table defs.[tio_tr_module_n].tio_com_type_defs.[tio_tr_type_def_n].tio_td_name string_table

setTypeSymbols :: [({#Char}, (Int, Int))] LibraryInstanceTypeReference
					*TypeEquivalences -> *TypeEquivalences
setTypeSymbols symbols (LIT_TypeReference (LibRef library)
			{tio_tr_module_n, tio_tr_type_def_n}) tes
	# library
		=	library-1
	# (ref, tes)
		=	tes!te_lib_instances.ga_array.[library]
			.li_type_map.[tio_tr_module_n , tio_tr_type_def_n]
	=	{tes & te_lib_symbols.[ref.lr_library].
			[ref.lr_ref.tio_glob_module, ref.lr_ref.tio_glob_object]
				=	Just symbols}

getTypeSymbols :: LibraryInstanceTypeReference u:TypeEquivalences
	-> (Maybe [({#Char}, (Int, Int))], u:TypeEquivalences)
getTypeSymbols x=:(LIT_TypeReference (LibRef library)
			{tio_tr_module_n, tio_tr_type_def_n}) tes
	# library
		=	library-1
	| False
		=	undef
	# (ref, tes)
		=	tes!te_lib_instances.ga_array.[library]
			.li_type_map.[tio_tr_module_n , tio_tr_type_def_n]
	| False
		=	undef
	=	tes!te_lib_symbols.[ref.lr_library].
			[ref.lr_ref.tio_glob_module, ref.lr_ref.tio_glob_object]

sccTypes string_table defs
	# (nds, tgt)
		=	nodes tgt
	# (edgs, tgt)
		=	mapSt edges (filter (\{tio_tr_module_n=mod} -> mod == 0) nds) tgt
	# gp
		=	zip2 nds edgs
	=	reverse (partitions state).components
	where 

		state =
			{	graph = type_graph_table
			,	stack = []
			,	num = 0
			,	components = []
			}
		type_graph_table =
			{	tg_defs = defs
			,	tg_table =
					{	createArray (size tio_com_type_defs) NotVisited
					\\	{tio_com_type_defs} <-: defs
					}
			}
		tgt =
			{	tg_defs = defs
			,	tg_table =
					{	createArray (size tio_com_type_defs) NotVisited
					\\	{tio_com_type_defs} <-: defs
					}
			}

instance toString TIO_TypeReference where
	toString {tio_tr_module_n, tio_tr_type_def_n}
		=	"<" +++ toString tio_tr_module_n +++ ", "
				+++ toString tio_tr_type_def_n +++ ">"

class SccGraph g n | == n where
	nodes :: .g -> ([n], .g)
	edges :: n .g -> ([n], .g)
	get_number :: n .g -> (Int, .g)
	set_number:: n Int *g -> *g

:: TypeGraph =
	{	tg_defs :: {#TIO_CommonDefs}
	,	tg_table :: .{#.{#Int}}
	}

:: G =
	{	g_graph :: {![Int]}
	,	g_table :: .{#Int}
	}

instance SccGraph G Int where
	nodes g=:{g_graph}
		=	([0..size g_graph-1], g)
	edges n g
		=	g!g_graph.[n]
	get_number n g
		=	g!g_table.[n]
	set_number n number g
		=	{g & g_table.[n] = number}

// quadratic
concatStrings
	:==	foldl (+++) ""
concat
	:==	foldr (++) []

instance == TIO_GlobalIndex
where
	(==) a b
		=	a.tio_glob_module == b.tio_glob_module
		&&	a.tio_glob_object == b.tio_glob_object

instance toString TIO_GlobalIndex where
	toString {tio_glob_object, tio_glob_module}
		=	"<" +++ toString tio_glob_object +++ ", "
		+++	toString tio_glob_module +++ ">"

instance == TIO_TypeReference
where
	(==) {tio_type_without_definition=Just type_name1}
			{tio_type_without_definition=Just type_name2}
		= type_name1 == type_name2
	(==) {tio_type_without_definition=Nothing,tio_tr_module_n=tio_tr_module_n1,tio_tr_type_def_n=tio_tr_type_def_n1}
			{tio_type_without_definition=Nothing,tio_tr_module_n=tio_tr_module_n2,tio_tr_type_def_n=tio_tr_type_def_n2}
        =	tio_tr_module_n1 == tio_tr_module_n2
        &&	tio_tr_type_def_n1 == tio_tr_type_def_n2
	(==) _ _
		= False

instance SccGraph TypeGraph TIO_TypeReference where
	nodes g=:{tg_defs}
		=	(concat [module_types mod def \\ def <-: tg_defs & mod <- [0..]], g)
		where
			module_types :: Int TIO_CommonDefs -> [TIO_TypeReference]
			module_types mod defs
				=	[	type_ref type_def_n mod 
					\\	type_def_n <- [0..]
					&	type_def <-: defs.tio_com_type_defs
					|	algebraic_or_record_type type_def.tio_td_rhs
					]
				where
					type_ref type_def_n mod =
						{	tio_type_without_definition = Nothing
						,   tio_tr_module_n = mod
						,   tio_tr_type_def_n = type_def_n
						}

					algebraic_or_record_type (TIO_AlgType _)
						=	True
					algebraic_or_record_type (TIO_RecordType _)
						=	True
					algebraic_or_record_type (TIO_GenericDictionaryType _)
						=	True
					algebraic_or_record_type _
						=	False

	edges {tio_tr_type_def_n, tio_tr_module_n} g
		# (defs, g)
			=	g!tg_defs.[tio_tr_module_n]
		  type_def
			=	defs.tio_com_type_defs.[tio_tr_type_def_n]
		=	(get_type_edges defs type_def, g)

	get_number {tio_tr_type_def_n, tio_tr_module_n} g
		=	g!tg_table.[tio_tr_module_n, tio_tr_type_def_n]

	set_number {tio_tr_type_def_n, tio_tr_module_n} number g
		=	{g & tg_table.[tio_tr_module_n, tio_tr_type_def_n] = number}

class get_type_edges a :: TIO_CommonDefs a -> [TIO_TypeReference]

instance get_type_edges (TIO_TypeDef a) | get_type_edges a where
	get_type_edges defs {tio_td_rhs}
		=	get_type_edges defs tio_td_rhs

instance get_type_edges TIO_TypeRhs where
	get_type_edges defs (TIO_AlgType cons_symbols)
		=	get_edges [get_cons_type defs cons \\ cons <- cons_symbols]
		where
			get_cons_type defs {tio_cons={tio_ds_index}}
				=	defs.tio_com_cons_defs.[tio_ds_index]
	get_type_edges defs (TIO_RecordType record_type)
		=	get_type_edges defs record_type
	get_type_edges defs (TIO_GenericDictionaryType record_type)
		=	get_type_edges defs record_type
	get_type_edges _ _
		=	[]

instance get_type_edges TIO_RecordType where
	get_type_edges defs {tio_rt_constructor={tio_ds_index}}
		=	get_edges defs.tio_com_cons_defs.[tio_ds_index]

class get_edges a :: a -> [TIO_TypeReference]

instance get_edges [a] | get_edges a where
	get_edges l
		=	concat (map get_edges l)

instance get_edges TIO_ConsDef where
	get_edges {tio_cons_type}
		=	get_edges tio_cons_type.tio_st_args

instance get_edges TIO_AType where
	get_edges {tio_at_type}
		=	get_edges tio_at_type

instance get_edges TIO_Type where
	get_edges (TIO_TAS type_symb args _)
		=	get_edges type_symb ++ get_edges args
	get_edges (a ----> b)
		=	get_edges a ++ get_edges b
	get_edges (_ :@@: args)
		=	get_edges args
	get_edges _
		=	[]

instance get_edges TIO_TypeSymbIdent where
	get_edges {tio_type_name_ref}
		=	get_edges tio_type_name_ref

instance get_edges TIO_TypeReference where
	get_edges {tio_type_without_definition=Just _}
		=	[]
	get_edges type_ref
		=	[type_ref]

:: PState g n =
	{	graph :: g
	,	num :: Int
	,	stack :: [n]
	,	components :: [[n]]
	}		

NotVisited
	:==	-1
MAXINT
	:==	1000000

sccSimple graph
	=	reverse (partitions state).components
	where
		state =
			{	graph = graph_table
			,	stack = []
			,	num = 0
			,	components = []
			}
		graph_table =
			{	g_graph = graph
			,	g_table = createArray (size graph) NotVisited
			}

partitions ::  *(PState *g n) -> *PState *g n | SccGraph g n
partitions state=:{graph}
	# (nodes, graph)
		=	nodes graph
	=	foldSt part nodes {state & graph=graph}
	where
		part :: n *(PState *g n) -> *PState *g n | SccGraph g n
		part n s
			=	snd (partition n s)

partition :: n *(PState *g n) -> (Int, *PState *g n) | SccGraph g n
partition node state=:{graph}
	# (num, graph)
		=	get_number node graph
	# state
		=	{state & graph = graph}
	| num == NotVisited
		# (num, state=:{graph})
			=	push node state
		# (edges, graph)
			=	edges node graph
		# state
			=	{state & graph = graph}
		# (minima, state)
			=	mapSt partition edges state
		# minimum
			=	foldl min MAXINT minima
		| num <= minimum
			=	(MAXINT, pop_component node MAXINT [] state)
		// otherwise
			=	(minimum, state)
	// otherwise
		=	(num, state)

push :: n *(PState *g n) -> (Int, *PState *g n) | SccGraph g n
push node state=:{num, stack, graph}
	# graph
		=	set_number node num graph
	=	(num, {state & graph = graph, stack = [node:stack], num = num+1})

pop :: Int *(PState *g n) -> (n, *PState *g n) | SccGraph g n
pop max_num state=:{num, graph, stack=[top:stack]}
	# graph
		=	set_number top max_num graph
	=	(top, {state & graph = graph, stack = stack})

pop_component :: n Int [n] *(PState *g n) -> *PState *g n | SccGraph g n
pop_component until max_num comp state=:{components}
	# (top, state)
		=	pop max_num state
	# comp
		=	[top:comp]
	| top == until
		=	{state & components = [comp:components]}
	// otherwise
		=	pop_component until max_num comp state

// growing arrays

:: GrowingArray e =
	{	ga_numerator :: !Int
	,	ga_denominator :: !Int
	,	ga_min_step :: !Int
	,	ga_array :: !.{!e}
	,	ga_default :: e
	}

initGrowingArray :: Int Int Int Int e -> *GrowingArray e | Array {!} e
initGrowingArray size num den step default_value =
	{	ga_numerator = num
	,	ga_denominator = den
	,	ga_min_step = step
	,	ga_array = createArray size default_value
	,	ga_default = default_value
	}

setGrowingArray :: Int e *(GrowingArray e) -> *GrowingArray e | Array {!} e
setGrowingArray index element a
	| index < size a.ga_array
		=	{a & ga_array.[index] = element}
	| index > size a.ga_array
		=	abort "setGrowingArray: index too large"
	// otherwise
		=	setGrowingArray index element (grow a)
	where
		grow :: *(GrowingArray e) -> *GrowingArray e | Array {!} e
		grow a=:{ga_array, ga_numerator, ga_denominator, ga_min_step,
					ga_default}
			# (s, ga_array)
				=	usize ga_array
			# n
				=	(s * ga_numerator) / ga_denominator
			# n
				=	min n (s + ga_min_step)
			# ga_array =	
				{	createArray n ga_default
				&	[i] = e
				\\	i <- [0..] & e <-: ga_array
				}
			=	{a & ga_array = ga_array}

getGrowingArray :: Int u:(GrowingArray e) -> (e, u:GrowingArray e) | Array {!} e
getGrowingArray index a
	=	a!ga_array.[index]

// binary tree

:: Tree k a
	=	Leaf
	|	Node k a (Tree k a) (Tree k a)

getTree :: k (Tree k a) -> Maybe a | <, == k
getTree k Leaf
	=	Nothing
getTree k tree=:(Node kn value left right)
	| k < kn
		=	getTree k left
	| k == kn
		=	Just value
	// k > kn
		=	getTree k right

setTree :: k a (Tree k a) -> Tree k a | <, == k
setTree k v Leaf
	=	Node k v Leaf Leaf
setTree k v tree=:(Node kn value left right)
	| k < kn
		=	Node kn value (setTree k v left) right
	| k == kn
		=	Node kn v left right
	// k > kn
		=	Node kn value left (setTree k v right)

// hash table

:: HashTable k a
	:==	{!Tree k a}

HashTableSize
	:==	1023

initHashTable :: *HashTable k a
initHashTable
	=	createArray HashTableSize Leaf

class hash a :: a -> Int
instance hash {#Char} where
	hash name
		| h < 0
			=	h + HashTableSize
		// otherwise
			=	h
		where
			h
				=	hash_value name (size name) 0 rem HashTableSize
			hash_value :: !String !Int !Int -> Int
			hash_value name index val
				| index == 0
					=	val
				// otherwise
					=	hash_value name (index-1)
							(val << 2 + toInt name.[index-1])

getHashTable :: k *(HashTable k a)-> (Maybe a, *HashTable k a) | <, ==, hash k
getHashTable k table
	# (tree, table)
		=	table![h]
	=	(getTree k tree, table)
	where
		h = hash k

setHashTable :: k a *(HashTable k a) -> *HashTable k a | <, ==, hash k
setHashTable k v table
	# (tree, table)
		=	table![h]
	=	{table & [h] = setTree k v tree}
	where
		h = hash k
