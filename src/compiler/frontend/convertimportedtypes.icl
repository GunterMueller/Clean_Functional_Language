implementation module convertimportedtypes

import syntax, expand_types, utilities
from containers import inNumberSet

cDontRemoveAnnotations :== False

convertIclModule :: !Int !Int !Int !{#CommonDefs} !*{#{#CheckedTypeDef}} !ImportedConstructors !*VarHeap !*TypeHeaps !*GenericHeap
									 -> (!{#Bool},!*{#{#CheckedTypeDef}},!ImportedConstructors,!*VarHeap,!*TypeHeaps,!*GenericHeap)
convertIclModule main_dcl_module_n start_index_generic_classes first_not_exported_generic_def_index common_defs imported_types imported_conses
		var_heap type_heaps generic_heap
	#! types_and_heaps = convertConstructorTypes common_defs.[main_dcl_module_n].com_cons_defs main_dcl_module_n common_defs (imported_types, imported_conses, var_heap, type_heaps)
	# (imported_types,imported_conses,var_heap,type_heaps)
		= convertSelectorTypes common_defs.[main_dcl_module_n].com_selector_defs main_dcl_module_n common_defs types_and_heaps
	  {com_class_defs,com_type_defs,com_cons_defs,com_selector_defs,com_member_defs,com_instance_defs,com_generic_defs} = common_defs.[main_dcl_module_n]
	  (imported_types,imported_conses,var_heap,type_heaps)
		= convert_member_types_of_module 0 start_index_generic_classes
			com_class_defs com_type_defs com_cons_defs com_selector_defs com_member_defs main_dcl_module_n common_defs
				imported_types imported_conses var_heap type_heaps
	#! n_generic_classes = size com_class_defs - start_index_generic_classes
	# not_exported_generic_classes = createArray n_generic_classes False
	  (not_exported_generic_classes,generic_heap)
		= mark_not_exported_generic_classes_of_module first_not_exported_generic_def_index com_generic_defs start_index_generic_classes not_exported_generic_classes generic_heap
	  (imported_types,imported_conses,var_heap,type_heaps)
		= convert_not_exported_generic_member_types_of_module 0 start_index_generic_classes not_exported_generic_classes
			com_class_defs com_type_defs com_cons_defs com_selector_defs com_member_defs main_dcl_module_n common_defs
				imported_types imported_conses var_heap type_heaps
	  (imported_conses,var_heap) = mark_imported_classes_in_instances 0 main_dcl_module_n com_instance_defs common_defs imported_conses var_heap
	= (not_exported_generic_classes,imported_types,imported_conses,var_heap,type_heaps,generic_heap)

convertDclModule :: !Int !{# DclModule} !{# CommonDefs} !*{#{# CheckedTypeDef}} !ImportedConstructors !*VarHeap !*TypeHeaps
													-> (!*{#{# CheckedTypeDef}},!ImportedConstructors,!*VarHeap,!*TypeHeaps)
convertDclModule main_dcl_module_n dcl_mods common_defs imported_types imported_conses var_heap type_heaps
	# {dcl_functions,dcl_common=dcl_common=:{com_type_defs,com_cons_defs,com_selector_defs},dcl_has_macro_conversions} = dcl_mods.[main_dcl_module_n]
	| dcl_has_macro_conversions
		#!(icl_type_defs, imported_types) = imported_types![main_dcl_module_n]
		  common_defs = { common \\ common <-: common_defs }
		  common_defs = { common_defs & [main_dcl_module_n] = dcl_common }
		  types_and_heaps = convert_dcl_functions dcl_functions common_defs ( { imported_types & [main_dcl_module_n] = com_type_defs }, imported_conses, var_heap, type_heaps)
		  types_and_heaps = convertConstructorTypes com_cons_defs main_dcl_module_n common_defs types_and_heaps
		  (imported_types, imported_conses, var_heap, type_heaps) = convertSelectorTypes com_selector_defs main_dcl_module_n common_defs types_and_heaps
		= ({ imported_types & [main_dcl_module_n] = icl_type_defs}, imported_conses, var_heap, type_heaps)
		= (imported_types, imported_conses, var_heap, type_heaps)
where
	convert_dcl_functions dcl_functions common_defs types_and_heaps
		= iFoldSt (convert_dcl_function dcl_functions common_defs) 0 (size dcl_functions) types_and_heaps

	convert_dcl_function dcl_functions common_defs dcl_index (imported_types, imported_conses, var_heap, type_heaps)
		#!{ft_type, ft_type_ptr, ft_ident} = dcl_functions.[dcl_index]
		  (ft_type, imported_types, imported_conses, type_heaps, var_heap)
		  	= convertSymbolType cDontRemoveAnnotations common_defs ft_type main_dcl_module_n imported_types imported_conses type_heaps var_heap
		= (imported_types, imported_conses, var_heap <:= (ft_type_ptr, VI_ExpandedType ft_type), type_heaps)

convertConstructorTypes cons_defs main_dcl_module_n common_defs types_and_heaps
	= iFoldSt (convert_constructor_type common_defs cons_defs) 0 (size cons_defs) types_and_heaps
where
	convert_constructor_type common_defs cons_defs cons_index (imported_types, imported_conses, var_heap, type_heaps)  
		#!{cons_type_ptr, cons_type, cons_ident} = cons_defs.[cons_index]
		  (cons_type, imported_types, imported_conses, type_heaps, var_heap)
				= convertSymbolType cDontRemoveAnnotations common_defs cons_type main_dcl_module_n imported_types imported_conses type_heaps var_heap
		= (imported_types, imported_conses, var_heap <:= (cons_type_ptr, VI_ExpandedType cons_type), type_heaps)

convertSelectorTypes selector_defs main_dcl_module_n common_defs types_and_heaps
	= iFoldSt (convert_selector_type common_defs selector_defs) 0 (size selector_defs) types_and_heaps
where
	convert_selector_type common_defs selector_defs sel_index (imported_types, imported_conses, var_heap, type_heaps)  
		#!{sd_type_ptr, sd_type, sd_ident} = selector_defs.[sel_index]
		  (sd_type, imported_types, imported_conses, type_heaps, var_heap)
				= convertSymbolType cDontRemoveAnnotations common_defs sd_type main_dcl_module_n imported_types imported_conses type_heaps var_heap
		  (sd_type_ptr_v,var_heap) = readPtr sd_type_ptr var_heap
		= case sd_type_ptr_v of
			VI_ExpandedMemberType expanded_member_type _
				# var_heap = writePtr sd_type_ptr (VI_ExpandedMemberType expanded_member_type (VI_ExpandedType sd_type)) var_heap
				-> (imported_types, imported_conses, var_heap, type_heaps)
			_
				# var_heap = writePtr sd_type_ptr (VI_ExpandedType sd_type) var_heap
				-> (imported_types, imported_conses, var_heap, type_heaps)

convertMemberTypes :: !Int !{#DclModule} !{#CommonDefs} !NumberSet !*{#{#CheckedTypeDef}} !ImportedConstructors !*VarHeap !*TypeHeaps
															   -> (!*{#{#CheckedTypeDef}},!ImportedConstructors,!*VarHeap,!*TypeHeaps)
convertMemberTypes main_dcl_module_n dcl_mods common_defs used_module_numbers imported_types imported_conses var_heap type_heaps
	= convert_member_types 0 main_dcl_module_n dcl_mods common_defs used_module_numbers imported_types imported_conses var_heap type_heaps

convert_member_types module_i main_dcl_module_n dcl_mods common_defs used_module_numbers imported_types imported_conses var_heap type_heaps
	| module_i==size dcl_mods
		= (imported_types,imported_conses,var_heap,type_heaps)
	| inNumberSet module_i used_module_numbers
		# {dcl_common={com_class_defs,com_type_defs,com_cons_defs,com_selector_defs,com_member_defs}} = dcl_mods.[module_i]
		#! n_classes = size com_class_defs
		# (imported_types,imported_conses,var_heap,type_heaps)
			= convert_member_types_of_module 0 n_classes
				com_class_defs com_type_defs com_cons_defs com_selector_defs com_member_defs main_dcl_module_n common_defs
					imported_types imported_conses var_heap type_heaps
		= convert_member_types (module_i+1) main_dcl_module_n dcl_mods common_defs used_module_numbers imported_types imported_conses var_heap type_heaps
		= convert_member_types (module_i+1) main_dcl_module_n dcl_mods common_defs used_module_numbers imported_types imported_conses var_heap type_heaps

cons_type_ptr_and_index_of_class :: !Int !Int !{#CommonDefs} -> (!VarInfoPtr,!Int)
cons_type_ptr_and_index_of_class module_n class_index common_defs
	# {com_class_defs,com_type_defs,com_cons_defs} = common_defs.[module_n]
	  {ds_index=type_index} = com_class_defs.[class_index].class_dictionary
	  {td_rhs=RecordType {rt_constructor={ds_index=cons_index}}} = com_type_defs.[type_index]
	= (com_cons_defs.[cons_index].cons_type_ptr,cons_index)

mark_imported_classes_in_instances :: !Int !Int !{#ClassInstance} {#CommonDefs} !ImportedConstructors !*VarHeap
																			-> (!ImportedConstructors,!*VarHeap)
mark_imported_classes_in_instances instance_i main_dcl_module_n instance_defs common_defs imported_conses var_heap
	| instance_i<size instance_defs
		# {gi_module,gi_index} = instance_defs.[instance_i].ins_class_index
		| gi_module==main_dcl_module_n
			= mark_imported_classes_in_instances (instance_i+1) main_dcl_module_n instance_defs common_defs imported_conses var_heap
			# (cons_type_ptr,cons_index) = cons_type_ptr_and_index_of_class gi_module gi_index common_defs
			= case sreadPtr cons_type_ptr var_heap of
				VI_Used
					-> mark_imported_classes_in_instances (instance_i+1) main_dcl_module_n instance_defs common_defs imported_conses var_heap
				VI_ExpandedType _
					-> mark_imported_classes_in_instances (instance_i+1) main_dcl_module_n instance_defs common_defs imported_conses var_heap
				_
					# var_heap = writePtr cons_type_ptr VI_Used var_heap
					  imported_conses = [{glob_module=gi_module,glob_object=cons_index}:imported_conses]
					-> mark_imported_classes_in_instances (instance_i+1) main_dcl_module_n instance_defs common_defs imported_conses var_heap
		= (imported_conses,var_heap)

mark_imported_class :: !Int !Int !Int {#CommonDefs} !ImportedConstructors !*VarHeap
												-> (!ImportedConstructors,!*VarHeap)
mark_imported_class	module_n class_index main_module_n common_defs imported_conses var_heap
	| module_n==main_module_n
		= (imported_conses,var_heap)
	# (cons_type_ptr,cons_index) = cons_type_ptr_and_index_of_class module_n class_index common_defs
	= case sreadPtr cons_type_ptr var_heap of
		VI_Used
			-> (imported_conses,var_heap)
		VI_ExpandedType _
			-> (imported_conses,var_heap)
		_
			# var_heap = writePtr cons_type_ptr VI_Used var_heap
			  imported_conses = [{glob_module=module_n,glob_object=cons_index}:imported_conses]
			-> (imported_conses,var_heap)

convert_member_types_of_module :: !Int !Int !{#ClassDef} !{#CheckedTypeDef} !{#ConsDef} !{#SelectorDef} !{#MemberDef} !Int !{#CommonDefs}
										!*{#{#CheckedTypeDef}} ![Global Int] !*VarHeap !*TypeHeaps
									-> (!*{#{#CheckedTypeDef}},![Global Int],!*VarHeap,!*TypeHeaps)
convert_member_types_of_module class_i stop_class_i class_defs type_defs cons_defs selector_defs member_defs main_dcl_module_n common_defs
								imported_types imported_conses var_heap type_heaps
	| class_i==stop_class_i
		= (imported_types,imported_conses,var_heap,type_heaps)
		# (imported_types,imported_conses,var_heap,type_heaps)
			= convert_member_type_of_module class_i class_defs type_defs cons_defs selector_defs member_defs main_dcl_module_n common_defs
											imported_types imported_conses var_heap type_heaps
		= convert_member_types_of_module (class_i+1) stop_class_i class_defs type_defs cons_defs selector_defs member_defs main_dcl_module_n common_defs
											imported_types imported_conses var_heap type_heaps

mark_not_exported_generic_classes_of_module :: !Int !{#GenericDef} !Int !*{#Bool} !*GenericHeap -> (!*{#Bool},!*GenericHeap)
mark_not_exported_generic_classes_of_module generic_def_i generic_defs start_index_generic_classes not_exported_generic_classes generic_heap
	| generic_def_i<size generic_defs
		# ({gen_classes}, generic_heap) = readPtr generic_defs.[generic_def_i].gen_info_ptr generic_heap
		# not_exported_generic_classes
			= mark_not_exported_generic_classes_of_class_infos 0 gen_classes start_index_generic_classes not_exported_generic_classes
		= mark_not_exported_generic_classes_of_module (generic_def_i+1) generic_defs start_index_generic_classes not_exported_generic_classes generic_heap
		= (not_exported_generic_classes,generic_heap)

mark_not_exported_generic_classes_of_class_infos :: !Int !GenericClassInfos !Int !*{#Bool} -> *{#Bool}
mark_not_exported_generic_classes_of_class_infos gen_class_i gen_classes start_index_generic_classes not_exported_generic_classes
	| gen_class_i<size gen_classes
		# gen_class_infos = gen_classes.[gen_class_i]
		# not_exported_generic_classes
			= mark_not_exported_generic_classes_of_class_info_list gen_class_infos start_index_generic_classes not_exported_generic_classes
		= mark_not_exported_generic_classes_of_class_infos (gen_class_i+1) gen_classes start_index_generic_classes not_exported_generic_classes
		= not_exported_generic_classes

mark_not_exported_generic_classes_of_class_info_list :: ![GenericClassInfo] !Int !*{#Bool} -> *{#Bool}
mark_not_exported_generic_classes_of_class_info_list [{gci_class}:gcis] start_index_generic_classes not_exported_generic_classes
	# generic_class_i = gci_class-start_index_generic_classes;
	| generic_class_i>=0 && generic_class_i<size not_exported_generic_classes
		# not_exported_generic_classes & [generic_class_i] = True;
		= mark_not_exported_generic_classes_of_class_info_list gcis start_index_generic_classes not_exported_generic_classes
mark_not_exported_generic_classes_of_class_info_list [] start_index_generic_classes not_exported_generic_classes
	= not_exported_generic_classes

convert_not_exported_generic_member_types_of_module :: !Int !Int !{#Bool} !{#ClassDef} !{#CheckedTypeDef} !{#ConsDef} !{#SelectorDef} !{#MemberDef} !Int !{#CommonDefs}
													!*{#{#CheckedTypeDef}} ![Global Int] !*VarHeap !*TypeHeaps
												-> (!*{#{#CheckedTypeDef}},![Global Int],!*VarHeap,!*TypeHeaps)
convert_not_exported_generic_member_types_of_module generic_class_i start_index_generic_classes not_exported_generic_classes
		class_defs type_defs cons_defs selector_defs member_defs main_dcl_module_n common_defs imported_types imported_conses var_heap type_heaps
	| generic_class_i<size not_exported_generic_classes
		| not_exported_generic_classes.[generic_class_i]
			# gen_class_i = start_index_generic_classes+generic_class_i
			# (imported_types,imported_conses,var_heap,type_heaps)
				= convert_member_type_of_module gen_class_i class_defs type_defs cons_defs selector_defs member_defs main_dcl_module_n common_defs
												imported_types imported_conses var_heap type_heaps
			= convert_not_exported_generic_member_types_of_module (generic_class_i+1) start_index_generic_classes not_exported_generic_classes
				class_defs type_defs cons_defs selector_defs member_defs main_dcl_module_n common_defs imported_types imported_conses var_heap type_heaps

			= convert_not_exported_generic_member_types_of_module (generic_class_i+1) start_index_generic_classes not_exported_generic_classes
				class_defs type_defs cons_defs selector_defs member_defs main_dcl_module_n common_defs imported_types imported_conses var_heap type_heaps
		= (imported_types,imported_conses,var_heap,type_heaps)

convert_member_type_of_module :: !Int !{#ClassDef} !{#CheckedTypeDef} !{#ConsDef} !{#SelectorDef} !{#MemberDef} !Int !{#CommonDefs}
										!*{#{#CheckedTypeDef}} ![Global Int] !*VarHeap !*TypeHeaps
									-> (!*{#{#CheckedTypeDef}},![Global Int],!*VarHeap,!*TypeHeaps)
convert_member_type_of_module class_i class_defs type_defs cons_defs selector_defs member_defs main_dcl_module_n common_defs
								imported_types imported_conses var_heap type_heaps
	# {class_dictionary,class_members} = class_defs.[class_i]
	  {td_rhs=RecordType {rt_constructor,rt_fields}} = type_defs.[class_dictionary.ds_index]
	  {cons_ident,cons_type_ptr} = cons_defs.[rt_constructor.ds_index]
	  (cons_type_ptr_v,var_heap) = readPtr cons_type_ptr var_heap
	| case cons_type_ptr_v of VI_Used -> True; VI_ExpandedType _  -> True; _ -> False;
		= convert_member_types_of_class 0 class_members rt_fields selector_defs member_defs main_dcl_module_n common_defs
											imported_types imported_conses var_heap type_heaps
		= (imported_types,imported_conses,var_heap,type_heaps)

convert_member_types_of_class :: !Int !{#DefinedSymbol} !{#FieldSymbol} !{#SelectorDef} !{#MemberDef} !Int !{#CommonDefs}
										!*{#{#CheckedTypeDef}} ![Global Int] !*VarHeap !*TypeHeaps
									-> (!*{#{#CheckedTypeDef}},![Global Int],!*VarHeap,!*TypeHeaps)
convert_member_types_of_class i class_members rt_fields selector_defs member_defs main_dcl_module_n common_defs
								imported_types imported_conses var_heap type_heaps
	| i<size class_members
		# class_member_index = class_members.[i].ds_index
		  {fs_ident,fs_index} = rt_fields.[i]
		  {me_ident,me_type} = member_defs.[class_member_index]
		  {sd_ident,sd_type_ptr} = selector_defs.[fs_index]
		  (sd_type_ptr_v,var_heap) = readPtr sd_type_ptr var_heap
		= case sd_type_ptr_v of
			VI_ExpandedMemberType _ _
				-> convert_member_types_of_class (i+1) class_members rt_fields selector_defs member_defs main_dcl_module_n common_defs
														imported_types imported_conses var_heap type_heaps
			VI_ExpandedType _
				# (converted_me_type, imported_types,imported_conses,type_heaps,var_heap)
					= convertSymbolType cDontRemoveAnnotations common_defs me_type main_dcl_module_n
										imported_types imported_conses type_heaps var_heap
				  var_heap = writePtr sd_type_ptr (VI_ExpandedMemberType converted_me_type sd_type_ptr_v) var_heap
				-> convert_member_types_of_class (i+1) class_members rt_fields selector_defs member_defs main_dcl_module_n common_defs
														imported_types imported_conses var_heap type_heaps
			_
				# (converted_me_type, imported_types,imported_conses,type_heaps,var_heap)
					= convertSymbolType cDontRemoveAnnotations common_defs me_type main_dcl_module_n imported_types imported_conses type_heaps var_heap
				  var_heap = writePtr sd_type_ptr (VI_ExpandedMemberType converted_me_type VI_Empty) var_heap
				-> convert_member_types_of_class (i+1) class_members rt_fields selector_defs member_defs main_dcl_module_n common_defs
														imported_types imported_conses var_heap type_heaps
		= (imported_types,imported_conses,var_heap,type_heaps)

make_abstract_types_in_implementation_module_abstract :: !Int !{#DclModule} !*{#{#CheckedTypeDef}} -> *{#{#CheckedTypeDef}}
make_abstract_types_in_implementation_module_abstract main_dcl_module_n dcl_mods imported_types
	# {dcl_common={com_type_defs},dcl_has_macro_conversions} = dcl_mods.[main_dcl_module_n]
	| dcl_has_macro_conversions
		# abstract_type_indexes = iFoldSt (determine_abstract_type com_type_defs) 0 (size com_type_defs) []
		| isEmpty abstract_type_indexes
			= imported_types
			#!(icl_type_defs, imported_types) = imported_types![main_dcl_module_n]
			  type_defs = foldSt insert_abstract_type abstract_type_indexes { icl_type_def \\ icl_type_def <-: icl_type_defs }
			= {imported_types & [main_dcl_module_n] = type_defs}
		= imported_types
where
	determine_abstract_type dcl_type_defs type_index abstract_type_indexes
		# {td_rhs} = dcl_type_defs.[type_index]
		= case td_rhs of
			AbstractType _
				-> [type_index : abstract_type_indexes]
			_
				-> abstract_type_indexes

	insert_abstract_type type_index type_defs
		# icl_index=type_index
		# (type_def, type_defs) = type_defs![icl_index]
		= { type_defs & [icl_index] = { type_def & td_rhs = AbstractType cAllBitsClear }}

convertMemberTypesAndImportedTypeSpecifications
	:: !Int !Int !NumberSet !{#DclModule} !{#{#FunType}} !{#CommonDefs} !ImportedConstructors !ImportedFunctions !*{#{#CheckedTypeDef}}
		!*TypeHeaps !*VarHeap -> (!*TypeHeaps, !*VarHeap)
convertMemberTypesAndImportedTypeSpecifications main_dcl_module_n start_index_generic_classes
		used_module_numbers dcl_mods dcl_functions common_defs imported_conses imported_functions imported_types type_heaps var_heap
	# imported_types = make_abstract_types_in_implementation_module_abstract main_dcl_module_n dcl_mods imported_types;
	# {com_class_defs,com_type_defs,com_cons_defs,com_selector_defs,com_member_defs} = common_defs.[main_dcl_module_n]
	#! n_classes = size com_class_defs
	# (imported_types,imported_conses,var_heap,type_heaps)
		= convert_member_types_of_module start_index_generic_classes n_classes 
			com_class_defs com_type_defs com_cons_defs com_selector_defs com_member_defs main_dcl_module_n common_defs
				imported_types imported_conses var_heap type_heaps
	# (imported_types,imported_conses,var_heap,type_heaps)
		= convertMemberTypes main_dcl_module_n dcl_mods common_defs used_module_numbers imported_types imported_conses var_heap type_heaps
	= convert_imported_type_specs dcl_functions common_defs imported_conses imported_functions imported_types type_heaps var_heap
where
	convert_imported_type_specs dcl_functions common_defs imported_conses imported_functions imported_types type_heaps var_heap
		# (imported_types, imported_conses, type_heaps, var_heap)
				= foldSt (convert_imported_function dcl_functions common_defs) imported_functions (imported_types, imported_conses, type_heaps, var_heap)
		= convert_imported_constructors common_defs imported_conses imported_types type_heaps var_heap

	convert_imported_function dcl_functions common_defs {glob_object,glob_module} (imported_types, imported_conses, type_heaps, var_heap)
		#!{ft_type_ptr,ft_type,ft_ident} = dcl_functions.[glob_module].[glob_object]
		  (ft_type, imported_types, imported_conses, type_heaps, var_heap)
				= convertSymbolType cDontRemoveAnnotations common_defs ft_type main_dcl_module_n imported_types imported_conses type_heaps var_heap
		= (imported_types, imported_conses, type_heaps, var_heap <:= (ft_type_ptr, VI_ExpandedType ft_type))

	convert_imported_constructors common_defs [] imported_types type_heaps var_heap
		= (type_heaps, var_heap)
	convert_imported_constructors common_defs [ {glob_module, glob_object} : conses ] imported_types type_heaps var_heap 
		#!{com_cons_defs,com_selector_defs} = common_defs.[glob_module]
		  {cons_type_ptr,cons_type,cons_type_index,cons_ident} = common_defs.[glob_module].com_cons_defs.[glob_object]
		  (cons_type, imported_types, conses, type_heaps, var_heap)
		  		= convertSymbolType cDontRemoveAnnotations common_defs cons_type main_dcl_module_n imported_types conses type_heaps var_heap
		  var_heap = var_heap <:= (cons_type_ptr, VI_ExpandedType cons_type)
		  ({td_rhs}, imported_types) = imported_types![glob_module].[cons_type_index]
				//---> ("convert_imported_constructors", cons_ident, cons_type)
		= case td_rhs of
			RecordType {rt_fields}
				# (imported_types, conses, type_heaps, var_heap)
						= iFoldSt (convert_type_of_imported_field glob_module com_selector_defs rt_fields) 0 (size rt_fields)
							(imported_types, conses, type_heaps, var_heap)
				-> convert_imported_constructors common_defs conses imported_types type_heaps var_heap
			_
				-> convert_imported_constructors common_defs conses imported_types type_heaps var_heap
		where
			convert_type_of_imported_field module_index selector_defs fields field_index (imported_types, conses, type_heaps, var_heap)
				#!field_index = fields.[field_index].fs_index
				  {sd_type_ptr,sd_type,sd_ident} = selector_defs.[field_index]
				  (sd_type, imported_types, conses, type_heaps, var_heap)
				  		= convertSymbolType cDontRemoveAnnotations common_defs sd_type main_dcl_module_n imported_types conses type_heaps var_heap
				  (sd_type_ptr_v,var_heap) = readPtr sd_type_ptr var_heap
				= case sd_type_ptr_v of
					VI_ExpandedMemberType expanded_member_type _
						# var_heap = writePtr sd_type_ptr (VI_ExpandedMemberType expanded_member_type (VI_ExpandedType sd_type)) var_heap
						-> (imported_types, conses, type_heaps, var_heap)
					_
						# var_heap = writePtr sd_type_ptr (VI_ExpandedType sd_type) var_heap
						-> (imported_types, conses, type_heaps, var_heap)
