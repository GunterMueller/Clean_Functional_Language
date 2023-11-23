implementation module check_instances

import StdEnv,StdOverloadedList
import syntax,compare_types,utilities,checksupport
from expand_types import simplifyAndCheckTypeApplication
from overloading import ::ClassInstanceInfo,::InstanceTree(..)

:: SortedInstances = SI_Node ![Global Index] !SortedInstances !SortedInstances | SI_Empty

check_if_class_instances_overlap :: !*ClassInstanceInfo !{#CommonDefs} !*TypeVarHeap !*ErrorAdmin -> (!*ClassInstanceInfo,!*TypeVarHeap,!*ErrorAdmin)
check_if_class_instances_overlap class_instances common_defs tvh error_admin
	= check_class_instances_of_modules 0 class_instances common_defs tvh error_admin

check_class_instances_of_modules :: !Int !*ClassInstanceInfo !{#CommonDefs} !*TypeVarHeap !*ErrorAdmin -> (!*ClassInstanceInfo,!*TypeVarHeap,!*ErrorAdmin)
check_class_instances_of_modules module_n class_instances common_defs tvh error_admin
	| module_n<size class_instances
		# (class_instances,tvh,error_admin) = check_class_instances_of_module 0 module_n class_instances common_defs tvh error_admin
		= check_class_instances_of_modules (module_n+1) class_instances common_defs tvh error_admin
		= (class_instances,tvh,error_admin)

check_class_instances_of_module :: !Int !Int !*ClassInstanceInfo !{#CommonDefs} !*TypeVarHeap !*ErrorAdmin -> (!*ClassInstanceInfo,!*TypeVarHeap,!*ErrorAdmin)
check_class_instances_of_module class_n module_n class_instances common_defs tvh error_admin
	| class_n<size class_instances.[module_n]
		# (instances,class_instances) = class_instances![module_n].[class_n]
		| instances=:IT_Empty
			= check_class_instances_of_module (class_n+1) module_n class_instances common_defs tvh error_admin
			# (normal_instances,default_instances,other_instances,tvh)
				= classify_and_sort_instances instances SI_Empty SI_Empty [] common_defs tvh
			  (tvh,error_admin) = check_if_sorted_instances_overlap normal_instances common_defs tvh error_admin
			  (tvh,error_admin) = check_if_sorted_instances_overlap default_instances common_defs tvh error_admin
			  (tvh,error_admin) = check_if_other_instances_overlap normal_instances default_instances other_instances common_defs tvh error_admin

			  (other_instance_tree,error_admin) = add_instances_to_instance_tree other_instances common_defs IT_Empty error_admin
			  (default_instance_tree,error_admin) = add_sorted_instances_to_instance_tree default_instances common_defs IT_Empty error_admin
			  class_instances & [module_n].[class_n] = IT_Trees normal_instances other_instance_tree default_instance_tree

			= check_class_instances_of_module (class_n+1) module_n class_instances common_defs tvh error_admin
		= (class_instances,tvh,error_admin)

classify_and_sort_instances :: !InstanceTree !SortedInstances !SortedInstances ![Global Index] !{#CommonDefs} !*TypeVarHeap
										-> *(!SortedInstances,!SortedInstances,![Global Index],!*TypeVarHeap)
classify_and_sort_instances (IT_Node instance_index=:{glob_module,glob_object} left right) normal_instances default_instances other_instances common_defs tvh
	#! {ins_type={it_types},ins_specials} = common_defs.[glob_module].com_instance_defs.[glob_object]
	| ins_specials=:SP_GenerateRecordInstances
		# (default_instances,tvh) = add_to_sorted_instances instance_index it_types default_instances common_defs tvh
		= classify_and_sort_left_and_right_instances left right normal_instances default_instances other_instances common_defs tvh
	# (is_normal_instance,tvh) = instance_root_types_specified it_types common_defs tvh
	| is_normal_instance
		# (normal_instances,tvh) = add_to_sorted_instances instance_index it_types normal_instances common_defs tvh
		= classify_and_sort_left_and_right_instances left right normal_instances default_instances other_instances common_defs tvh
	# (is_default_instance,tvh) = check_if_default_instance_types it_types [] common_defs False tvh
	| is_default_instance
		# (default_instances,tvh) = add_to_sorted_instances instance_index it_types default_instances common_defs tvh
		= classify_and_sort_left_and_right_instances left right normal_instances default_instances other_instances common_defs tvh
		# other_instances = [instance_index:other_instances]
		= classify_and_sort_left_and_right_instances left right normal_instances default_instances other_instances common_defs tvh
where
	classify_and_sort_left_and_right_instances left right normal_instances default_instances other_instances common_defs tvh
		# (normal_instances,default_instances,other_instances,tvh)
			= classify_and_sort_instances left normal_instances default_instances other_instances common_defs tvh
		# (normal_instances,default_instances,other_instances,tvh)
			= classify_and_sort_instances right normal_instances default_instances other_instances common_defs tvh
		= (normal_instances,default_instances,other_instances,tvh)
classify_and_sort_instances IT_Empty normal_instances default_instances other_instances common_defs tvh
	= (normal_instances,default_instances,other_instances,tvh)

add_to_sorted_instances :: !(Global Index) ![Type] !SortedInstances !{#CommonDefs} !*TypeVarHeap -> (!SortedInstances,!*TypeVarHeap)
add_to_sorted_instances instance_index instance_types (SI_Node instances=:[{glob_module,glob_object}:_] left right) common_defs tvh
	#! {ins_type={it_types}} = common_defs.[glob_module].com_instance_defs.[glob_object]
	# (compare_value,tvh) = compare_instance_root_types instance_types it_types common_defs tvh
	| compare_value==Equal
		= (SI_Node (instances++[instance_index]) left right,tvh)
	| compare_value==Smaller
		# (left,tvh) = add_to_sorted_instances instance_index instance_types left common_defs tvh
		= (SI_Node instances left right,tvh)
		# (right,tvh) = add_to_sorted_instances instance_index instance_types right common_defs tvh
		= (SI_Node instances left right,tvh)
add_to_sorted_instances instance_index instances_types SI_Empty common_defs tvh
	= (SI_Node [instance_index] SI_Empty SI_Empty,tvh)

check_if_other_instances_overlap :: SortedInstances SortedInstances ![Global Index] !{#CommonDefs} *TypeVarHeap !*ErrorAdmin
										-> (!*TypeVarHeap,!*ErrorAdmin)
check_if_other_instances_overlap normal_instances default_instances [] common_defs tvh error_admin
	= (tvh,error_admin)
check_if_other_instances_overlap normal_instances default_instances other_instances common_defs tvh error_admin
	# instances = add_instances_from_tree_to_list normal_instances [] common_defs
	# instances = add_instances_from_tree_to_list default_instances instances common_defs
	# (_,tvh,error_admin) = check_if_instances_overlap other_instances instances common_defs tvh error_admin
	= (tvh,error_admin)

add_instances_from_tree_to_list :: !SortedInstances ![([Type],Global Int)] !{#CommonDefs} -> [([Type],Global Int)]
add_instances_from_tree_to_list (SI_Node instances left right) l common_defs
	# l = add_instances_from_tree_to_list left l common_defs
	# l = add_instances_from_list instances l common_defs
	= add_instances_from_tree_to_list right l common_defs
where
	add_instances_from_list [instance_index=:{glob_module,glob_object}:instances] l common_defs
		#! it_types = common_defs.[glob_module].com_instance_defs.[glob_object].ins_type.it_types
		= [(it_types,instance_index):add_instances_from_list instances l common_defs]
	add_instances_from_list [] l common_defs
		= l
add_instances_from_tree_to_list SI_Empty l common_defs
	= l

check_if_sorted_instances_overlap :: !SortedInstances !{#CommonDefs} !*TypeVarHeap !*ErrorAdmin -> (!*TypeVarHeap,!*ErrorAdmin)
check_if_sorted_instances_overlap (SI_Node [_] left right) common_defs tvh error_admin
	# (tvh,error_admin) = check_if_sorted_instances_overlap left common_defs tvh error_admin
	= check_if_sorted_instances_overlap right common_defs tvh error_admin
check_if_sorted_instances_overlap (SI_Node [instance_index=:{glob_module,glob_object}:instances] left right) common_defs tvh error_admin
	#! {ins_type={it_types},ins_specials,ins_ident} = common_defs.[glob_module].com_instance_defs.[glob_object]
	# (_,tvh,error_admin) = check_if_instances_overlap instances [(it_types,instance_index)] common_defs tvh error_admin
	# (tvh,error_admin) = check_if_sorted_instances_overlap left common_defs tvh error_admin
	= check_if_sorted_instances_overlap right common_defs tvh error_admin
check_if_sorted_instances_overlap SI_Empty common_defs tvh error_admin
	= (tvh,error_admin)

add_sorted_instances_to_instance_tree :: !SortedInstances !{#CommonDefs} !*InstanceTree !*ErrorAdmin -> (!*InstanceTree,!*ErrorAdmin)
add_sorted_instances_to_instance_tree (SI_Node instances left right) common_defs instance_tree error_admin
	# (instance_tree,error_admin) = add_instances_to_instance_tree instances common_defs instance_tree error_admin
	# (instance_tree,error_admin) = add_sorted_instances_to_instance_tree left common_defs instance_tree error_admin
	= add_sorted_instances_to_instance_tree right common_defs instance_tree error_admin
add_sorted_instances_to_instance_tree SI_Empty common_defs instance_tree error_admin
	= (instance_tree,error_admin)

add_instances_to_instance_tree :: ![Global Int] !{#CommonDefs} !*InstanceTree !*ErrorAdmin -> (!*InstanceTree,!*ErrorAdmin)
add_instances_to_instance_tree [instance_index=:{glob_module,glob_object}:instances] common_defs instance_tree error_admin
	#! it_types = common_defs.[glob_module].com_instance_defs.[glob_object].ins_type.it_types
	# (instance_tree,error_admin) = insert_instance_in_tree it_types glob_module glob_object common_defs instance_tree error_admin
	= add_instances_to_instance_tree instances common_defs instance_tree error_admin
add_instances_to_instance_tree [] common_defs instance_tree error_admin
	= (instance_tree,error_admin)

insert_instance_in_tree ::  ![Type] !Index !Index !{#CommonDefs} !*InstanceTree !*ErrorAdmin -> (!*InstanceTree,!*ErrorAdmin)
insert_instance_in_tree ins_types new_ins_module new_ins_index common_defs (IT_Node ins=:{glob_object,glob_module} it_less it_greater) error_admin
	#! {ins_type={it_types}} = common_defs.[glob_module].com_instance_defs.[glob_object]
	# cmp = compareInstances ins_types it_types // to do: use compare that expands synonym types
	| cmp == Smaller
		# (it_less,error_admin) = insert_instance_in_tree ins_types new_ins_module new_ins_index common_defs it_less error_admin
		= (IT_Node ins it_less it_greater, error_admin)
	| cmp == Greater
		# (it_greater,error_admin) = insert_instance_in_tree ins_types new_ins_module new_ins_index common_defs it_greater error_admin
		= (IT_Node ins it_less it_greater, error_admin)
	| ins.glob_object==new_ins_index && ins.glob_module==new_ins_module
		= (IT_Node ins it_less it_greater, error_admin)
		# error_admin = overlapping_instance_error new_ins_module new_ins_index ins common_defs error_admin
		= (IT_Node ins it_less it_greater, error_admin)
insert_instance_in_tree ins_types new_ins_module new_ins_index common_defs IT_Empty error_admin
	= (IT_Node {glob_object = new_ins_index,glob_module = new_ins_module} IT_Empty IT_Empty, error_admin)

check_if_instances_overlap :: ![Global Index] ![([Type],Global Index)] !{#CommonDefs} !*TypeVarHeap !*ErrorAdmin
							-> (![([Type],Global Index)],!*TypeVarHeap,!*ErrorAdmin)
check_if_instances_overlap [instance_index=:{glob_module,glob_object}:instances] previous_instances common_defs tvh error_admin
	#! {ins_type={it_types},ins_specials} = common_defs.[glob_module].com_instance_defs.[glob_object]
	# (maybe_overlapping_instance_index,previous_instances,tvh)
		= check_instance it_types instance_index previous_instances common_defs tvh
	| maybe_overlapping_instance_index.glob_module<> -1
		# error_admin = overlapping_instance_error glob_module glob_object maybe_overlapping_instance_index common_defs error_admin
		= check_if_instances_overlap instances previous_instances common_defs tvh error_admin
		= check_if_instances_overlap instances previous_instances common_defs tvh error_admin
check_if_instances_overlap [] previous_instances common_defs tvh error_admin
	= (previous_instances,tvh,error_admin)

check_instance :: ![Type] !(Global Index) ![([Type],Global Index)] !{#CommonDefs} !*TypeVarHeap
					-> (!Global Index,![([Type],Global Index)],!*TypeVarHeap)
check_instance instance_types instance_index [previous_instance=:(previous_instance_type,previous_instance_index):previous_instances] common_defs tvh
	# ins_ident = common_defs.[instance_index.glob_module].com_instance_defs.[instance_index.glob_object].ins_ident
	# (overlaps,subst,tvh) = unify_instances instance_types previous_instance_type common_defs [] tvh
	# tvh = restore_type_var_infos subst tvh
	| overlaps
		// instance not added to previous_instances
		= (previous_instance_index,[previous_instance:previous_instances],tvh)
		# (maybe_overlapping_instance,previous_instances,tvh)
			= check_instance instance_types instance_index previous_instances common_defs tvh
		= (maybe_overlapping_instance,[previous_instance:previous_instances],tvh)
check_instance instance_types instance_index [] common_defs tvh
	= ({glob_module = -1,glob_object = -1},[(instance_types,instance_index)],tvh)

restore_type_var_infos [(tv_info_ptr,tv_info):tv_infos] tvh
	# tvh = writePtr tv_info_ptr tv_info tvh
	= restore_type_var_infos tv_infos tvh
restore_type_var_infos [] tvh
	= tvh

overlapping_instance_error :: !Int !Int !(Global Int) !{#CommonDefs} !*ErrorAdmin -> *ErrorAdmin
// almost same function as in module type
overlapping_instance_error new_ins_module new_ins_index instance_index common_defs error
	# {ins_ident,ins_pos} = common_defs.[new_ins_module].com_instance_defs.[new_ins_index]
	  error = checkErrorWithPosition ins_ident ins_pos " instance is overlapping with the instance in the next error" error
	  {ins_ident,ins_pos} = common_defs.[instance_index.glob_module].com_instance_defs.[instance_index.glob_object]
	= checkErrorWithPosition ins_ident ins_pos " instance is overlapping with the instance in the previous error" error

unify_instances :: ![Type] ![Type] !{#CommonDefs} [(TypeVarInfoPtr,TypeVarInfo)] !*TypeVarHeap -> (!Bool,[(TypeVarInfoPtr,TypeVarInfo)],!*TypeVarHeap)
unify_instances [t1 : ts1] [t2 : ts2] common_defs subst tvh
	# (succ, subst, tvh) = unify_instances_types t1 t2 common_defs subst tvh
	| succ
		= unify_instances ts1 ts2 common_defs subst tvh
		= (False, subst, tvh)
unify_instances [] [] common_defs subst tvh
	= (True, subst, tvh)
unify_instances _ _ common_defs subst tvh
	= (False, subst, tvh)

unify_instances_types :: !Type !Type !{#CommonDefs} [(TypeVarInfoPtr,TypeVarInfo)] !*TypeVarHeap -> *(!Bool,[(TypeVarInfoPtr,TypeVarInfo)],!*TypeVarHeap)
unify_instances_types tv=:(TV {tv_info_ptr}) type2 common_defs subst tvh
	# (tv_info, tvh) = readPtr tv_info_ptr tvh
	= case tv_info of
		TVI_Type type
			-> unify_instances_types type type2 common_defs subst tvh
		old_tv_info
			-> unify_variable_with_type tv_info_ptr type2 old_tv_info subst common_defs tvh
	where
		unify_variable_with_type :: !TypeVarInfoPtr !Type !TypeVarInfo [(TypeVarInfoPtr,TypeVarInfo)] {#CommonDefs} !*TypeVarHeap -> (!Bool,[(TypeVarInfoPtr,TypeVarInfo)],!*TypeVarHeap)
		unify_variable_with_type tv_info_ptr tv2=:(TV {tv_info_ptr=tv_info_ptr2}) old_tv_info subst common_defs tvh
			# (tv_info2, tvh) = readPtr tv_info_ptr2 tvh
			= case tv_info2 of
				TVI_Type type2
					-> unify_variable_with_type tv_info_ptr type2 old_tv_info subst common_defs tvh
				_
					| tv_info_ptr == tv_info_ptr2
						-> (True, subst, tvh)
						# tvh = writePtr tv_info_ptr (TVI_Type tv2) tvh
						# subst = [(tv_info_ptr,old_tv_info) : subst]
						-> (True, subst, tvh)
		unify_variable_with_type tv_info_ptr type old_tv_info subst common_defs tvh
			| contains_type_variable tv_info_ptr type tvh
				# (succ, type, tvh) = try_to_expand_in_unify_instances type common_defs tvh
				| succ
					= unify_variable_with_type tv_info_ptr type old_tv_info subst common_defs tvh
					= (False, subst, tvh)
				# tvh = writePtr tv_info_ptr (TVI_Type type) tvh
				# subst = [(tv_info_ptr,old_tv_info) : subst]
				= (True, subst, tvh)
unify_instances_types type tv=:(TV _) common_defs subst heaps
	= unify_instances_types tv type common_defs subst heaps
unify_instances_types (TB tb1) (TB tb2) common_defs subst tvh
	| tb1 == tb2
		= (True, subst, tvh)
		= (False, subst, tvh)
unify_instances_types t1=:(TA cons_id1 cons_args1) t2=:(TA cons_id2 cons_args2) common_defs subst tvh
	| cons_id1 == cons_id2
		= unify_instances_arg_types cons_args1 cons_args2 common_defs subst tvh
		= expand_and_unify_instance_types t1 t2 common_defs subst tvh
unify_instances_types t1=:(TA cons_id1 cons_args1) t2=:(TAS cons_id2 cons_args2 _) common_defs subst tvh
	| cons_id1 == cons_id2
		= unify_instances_arg_types cons_args1 cons_args2 common_defs subst tvh
		= expand_and_unify_instance_types t1 t2 common_defs subst tvh
unify_instances_types t1=:(TAS cons_id1 cons_args1 _) t2=:(TA cons_id2 cons_args2) common_defs subst tvh
	| cons_id1 == cons_id2
		= unify_instances_arg_types cons_args1 cons_args2 common_defs subst tvh
		= expand_and_unify_instance_types t1 t2 common_defs subst tvh
unify_instances_types t1=:(TAS cons_id1 cons_args1 _) t2=:(TAS cons_id2 cons_args2 _) common_defs subst tvh
	| cons_id1 == cons_id2
		= unify_instances_arg_types cons_args1 cons_args2 common_defs subst tvh
		= expand_and_unify_instance_types t1 t2 common_defs subst tvh
unify_instances_types (arg_type1 --> res_type1) (arg_type2 --> res_type2) common_defs subst tvh
	# (succ, subst, tvh) = unify_instances_types arg_type1.at_type arg_type2.at_type common_defs subst tvh
	| succ
		= unify_instances_types res_type1.at_type res_type2.at_type common_defs subst tvh
		= (False, subst, tvh)
unify_instances_types TArrow TArrow common_defs subst tvh
	= (True, subst, tvh)
unify_instances_types (TArrow1 t1) (TArrow1 t2) common_defs subst tvh
	= unify_instances_types t1.at_type t2.at_type common_defs subst tvh
unify_instances_types (CV cons_var :@: types) type2 common_defs subst tvh
	# (_, type2, tvh) = try_to_expand_in_unify_instances type2 common_defs tvh
	= unify_instances_type_applications cons_var types type2 common_defs subst tvh
unify_instances_types type1 (CV cons_var :@: types) common_defs subst tvh
	# (_, type1, tvh) = try_to_expand_in_unify_instances type1 common_defs tvh
	= unify_instances_type_applications cons_var types type1 common_defs subst tvh
unify_instances_types type1 type2 common_defs subst tvh
	= expand_and_unify_instance_types type1 type2 common_defs subst tvh

unify_instances_arg_types :: ![AType] ![AType] !{#CommonDefs} [(TypeVarInfoPtr,TypeVarInfo)] !*TypeVarHeap -> (!Bool,[(TypeVarInfoPtr,TypeVarInfo)],!*TypeVarHeap)
unify_instances_arg_types [t1 : ts1] [t2 : ts2] common_defs subst tvh
	# (succ, subst, tvh) = unify_instances_types t1.at_type t2.at_type common_defs subst tvh
	| succ
		= unify_instances_arg_types ts1 ts2 common_defs subst tvh
		= (False, subst, tvh)
unify_instances_arg_types [] [] common_defs subst tvh
	= (True, subst, tvh)
unify_instances_arg_types _ _ common_defs subst tvh
	= (False, subst, tvh)

contains_type_variable :: !TypeVarInfoPtr !Type !TypeVarHeap -> Bool
contains_type_variable tv_info_ptr (TV tv) tvh
	= case sreadPtr tv.tv_info_ptr tvh of
		TVI_Type type
			-> contains_type_variable tv_info_ptr type tvh
		_
			-> tv_info_ptr == tv.tv_info_ptr
contains_type_variable tv_info_ptr (TA _ cons_args) tvh
	= contains_type_variable_in_args tv_info_ptr cons_args tvh
contains_type_variable tv_info_ptr (TAS _ cons_args _) tvh
	= contains_type_variable_in_args tv_info_ptr cons_args tvh
contains_type_variable tv_info_ptr (arg_type --> res_type) tvh
	= contains_type_variable tv_info_ptr arg_type.at_type tvh || contains_type_variable tv_info_ptr res_type.at_type tvh
contains_type_variable tv_info_ptr (CV tv :@: types) tvh
	= case sreadPtr tv.tv_info_ptr tvh of
		TVI_Type type
			-> contains_type_variable tv_info_ptr type tvh || contains_type_variable_in_args tv_info_ptr types tvh
		_
			-> tv_info_ptr == tv.tv_info_ptr || contains_type_variable_in_args tv_info_ptr types tvh
contains_type_variable tv_info_ptr (TArrow1 arg_type) tvh
	= contains_type_variable tv_info_ptr arg_type.at_type tvh
contains_type_variable _ _ _
	= False

contains_type_variable_in_args :: !TypeVarInfoPtr ![AType] !TypeVarHeap -> Bool
contains_type_variable_in_args tv_info_ptr [{at_type}:list] tvh
	= contains_type_variable tv_info_ptr at_type tvh || contains_type_variable_in_args tv_info_ptr list tvh
contains_type_variable_in_args tv_info_ptr [] _
	= False

unify_instances_type_applications :: !TypeVar ![AType] !Type !{#CommonDefs} [(TypeVarInfoPtr,TypeVarInfo)] !*TypeVarHeap -> (!Bool,[(TypeVarInfoPtr,TypeVarInfo)],!*TypeVarHeap)
unify_instances_type_applications cv=:{tv_info_ptr} type_args type2 common_defs subst tvh
	# (tv_info, tvh) = readPtr tv_info_ptr tvh
	= case tv_info of
		TVI_Type type1
			# (ok, simplified_type) = simplifyAndCheckTypeApplication type1 type_args
			| ok
				-> unify_instances_types simplified_type type2 common_defs subst tvh
				-> (False, subst, tvh)
			-> unify_instances_CV_with_type cv type_args type2 common_defs subst tvh

unify_instances_CV_with_type :: !TypeVar ![AType] !Type {#CommonDefs} [(TypeVarInfoPtr,TypeVarInfo)] !*TypeVarHeap -> (!Bool,[(TypeVarInfoPtr,TypeVarInfo)],!*TypeVarHeap)
unify_instances_CV_with_type cv1 type_args1 type=:(CV cv2=:{tv_info_ptr}:@: type_args2) common_defs subst tvh
	# (tv_info2, tvh) = readPtr tv_info_ptr tvh
	= case tv_info2 of
		TVI_Type type2
			# (ok, simplified_type) = simplifyAndCheckTypeApplication type2 type_args2
			| ok
				-> unify_instances_CV_with_type cv1 type_args1 simplified_type common_defs subst tvh
				-> (False, subst, tvh)
			-> unify_instances_CV_application_with_CV_application cv1 type_args1 cv2 type_args2 common_defs subst tvh
unify_instances_CV_with_type cv type_args type=:(TA type_cons cons_args) common_defs subst tvh
	# diff = type_cons.type_arity - length type_args
	| diff >= 0
		# (succ, subst, tvh) = unify_instances_arg_types type_args (drop diff cons_args) common_defs subst tvh
		| succ
			= unify_instances_types (TV cv) (TA {type_cons & type_arity = diff} (take diff cons_args)) common_defs subst tvh
		    = (False, subst, tvh)
		= (False, subst, tvh)
unify_instances_CV_with_type cv type_args type=:(TAS type_cons cons_args strictness) common_defs subst tvh
	# diff = type_cons.type_arity - length type_args
	| diff >= 0
		# (succ, subst, tvh) = unify_instances_arg_types type_args (drop diff cons_args) common_defs subst tvh
		| succ
			= unify_instances_types (TV cv) (TAS {type_cons & type_arity = diff} (take diff cons_args) strictness) common_defs subst tvh
		    = (False, subst, tvh)
		= (False, subst, tvh)
unify_instances_CV_with_type cv [type_arg1, type_arg2] type=:(atype1 --> atype2) common_defs subst tvh
	# (succ, subst, tvh) = unify_instances_types type_arg1.at_type atype1.at_type common_defs subst tvh
	| succ
		# (succ, subst, tvh) = unify_instances_types type_arg2.at_type atype2.at_type common_defs subst tvh
		| succ
			= unify_instances_types (TV cv) TArrow common_defs subst tvh
			= (False, subst, tvh)
		= (False, subst, tvh)
unify_instances_CV_with_type cv [type_arg] type=:(atype1 --> atype2) common_defs subst tvh
	# (succ, subst, tvh) = unify_instances_types type_arg.at_type atype2.at_type common_defs subst tvh
	| succ
		= unify_instances_types (TV cv) (TArrow1 atype1) common_defs subst tvh
		= (False, subst, tvh)
unify_instances_CV_with_type cv [] type=:(atype1 --> atype2) common_defs subst tvh
	= unify_instances_types (TV cv) type  common_defs subst tvh
unify_instances_CV_with_type cv [type_arg] type=:(TArrow1 atype) common_defs subst tvh
	# (succ, subst, tvh) = unify_instances_types type_arg.at_type atype.at_type common_defs subst tvh
	| succ
		= unify_instances_types (TV cv) TArrow common_defs subst tvh
		= (False, subst, tvh)
unify_instances_CV_with_type cv [] type=:(TArrow1 atype) common_defs subst tvh
	= unify_instances_types (TV cv) type common_defs subst tvh
unify_instances_CV_with_type cv [] TArrow common_defs subst tvh
	= unify_instances_types (TV cv) TArrow common_defs subst tvh
unify_instances_CV_with_type cv type_args type common_defs subst tvh
	= (False, subst, tvh)

unify_instances_CV_application_with_CV_application :: !TypeVar ![AType] !TypeVar ![AType] !{#CommonDefs} [(TypeVarInfoPtr,TypeVarInfo)] !*TypeVarHeap -> (!Bool,[(TypeVarInfoPtr,TypeVarInfo)],!*TypeVarHeap)
unify_instances_CV_application_with_CV_application cv1 type_args1 cv2 type_args2 common_defs subst tvh
	# arity1 = length type_args1
	  arity2 = length type_args2
	  diff = arity1 - arity2
	| diff == 0
		| cv1.tv_info_ptr == cv2.tv_info_ptr
		    = unify_instances_arg_types type_args1 type_args2 common_defs subst tvh
			# (old_tv_info1,tvh) = readPtr cv1.tv_info_ptr tvh
			# tvh = writePtr cv1.tv_info_ptr (TVI_Type (TV cv2)) tvh
			# subst = [(cv1.tv_info_ptr,old_tv_info1) : subst]
		    = unify_instances_arg_types type_args1 type_args2 common_defs subst tvh
	| diff < 0
		# diff = ~diff
		  (succ, subst, tvh) = unify_instances_types (TV cv1) (CV cv2 :@: take diff type_args2) common_defs subst tvh
		| succ
		    = unify_instances_arg_types type_args1 (drop diff type_args2) common_defs subst tvh
			= (False, subst, tvh)
		# (succ, subst, tvh) = unify_instances_types (CV cv1 :@: take diff type_args1) (TV cv2) common_defs subst tvh
		| succ
		    = unify_instances_arg_types (drop diff type_args1) type_args2 common_defs subst tvh
			= (False, subst, tvh)

expand_and_unify_instance_types :: !Type !Type !{#CommonDefs} [(TypeVarInfoPtr,TypeVarInfo)] !*TypeVarHeap -> *(!Bool,[(TypeVarInfoPtr,TypeVarInfo)],!*TypeVarHeap)
expand_and_unify_instance_types type1 type2 common_defs subst tvh
	# (succ1, type1, tvh) = try_to_expand_in_unify_instances type1 common_defs tvh
	  (succ2, type2, tvh) = try_to_expand_in_unify_instances type2 common_defs tvh
	| succ1 || succ2
		= unify_instances_types type1 type2 common_defs subst tvh
		= (False, subst, tvh)

try_to_expand_in_unify_instances :: !Type {#CommonDefs} *TypeVarHeap -> (!.Bool,!Type,!*TypeVarHeap)
try_to_expand_in_unify_instances type=:(TA {type_index={glob_object,glob_module}} type_args) common_defs tvh
	#! {td_rhs,td_args} = common_defs.[glob_module].com_type_defs.[glob_object]
	= case td_rhs of
		SynType {at_type}
			# (expanded_type, tvh) = substitute_instance_type td_args type_args at_type tvh
			-> (True, expanded_type, tvh)
		_
			-> (False, type, tvh)
try_to_expand_in_unify_instances type common_defs tvh
	= (False, type, tvh)

substitute_instance_type :: ![ATypeVar] ![AType] !Type !*TypeVarHeap -> (!Type,!*TypeVarHeap)
substitute_instance_type form_type_args act_type_args orig_type tvh
	# (old_type_var_infos,tvh) = bind_type_vars form_type_args act_type_args tvh
	  (expanded_type, tvh) = substitute_type orig_type tvh
	  tvh = restore_bindings_of_type_vars form_type_args old_type_var_infos tvh
	= (expanded_type, tvh)
where
	bind_type_vars form_type_args act_type_args tvh
		= fold2St bind_type form_type_args act_type_args ([],tvh)
	where
		bind_type {atv_variable={tv_info_ptr}} {at_type} (type_var_infos,tvh)
			# (type_var_info,tvh) = readPtr tv_info_ptr tvh
			# tvh = writePtr tv_info_ptr (TVI_Type at_type) tvh
			= ([type_var_info:type_var_infos],tvh)

	restore_bindings_of_type_vars form_type_args old_type_var_infos tvh
		= fold2St restore_type_var_info form_type_args old_type_var_infos tvh
	where
		restore_type_var_info {atv_variable={tv_info_ptr}} old_type_var_info tvh
			= writePtr tv_info_ptr old_type_var_info tvh

	substitute_type :: !Type !*TypeVarHeap -> (!Type,!*TypeVarHeap)
	substitute_type tv=:(TV {tv_info_ptr}) tvh
		# (tv_info, tvh) = readPtr tv_info_ptr tvh
		= case tv_info of
			TVI_Type type
				-> (type,tvh)
			_
				-> (tv,tvh)
	substitute_type (TA cons_id cons_args=:[_:_]) tvh
		# (cons_args_r, tvh) = substitute_type_args cons_args tvh
		= (TA cons_id cons_args_r, tvh)
	substitute_type (TAS cons_id cons_args strictness) tvh
		# (cons_args_r, tvh) = substitute_type_args cons_args tvh
		= (TAS cons_id cons_args_r strictness, tvh)
	substitute_type (arg_type --> res_type) tvh
		# (arg_type_r, tvh) = substitute_type arg_type.at_type tvh
		# (res_type_r, tvh) = substitute_type res_type.at_type tvh
		= ({arg_type & at_type=arg_type_r} --> {res_type & at_type=res_type_r}, tvh)
	substitute_type type=:(CV type_var :@: types) tvh
		# (tv_info, tvh) = readPtr type_var.tv_info_ptr tvh
		  (types_r, tvh) = substitute_type_args types tvh
		= case tv_info of
			TVI_Type s_type
				# (ok, simplified_type) = simplifyAndCheckTypeApplication s_type types_r
				| ok
					-> (simplified_type, tvh)
					-> (TE, tvh) // error
			_
				-> (CV type_var :@: types_r, tvh)
	substitute_type (TArrow1 arg_type) tvh
		# (arg_type_r, tvh) = substitute_type arg_type.at_type tvh
		= (TArrow1 {arg_type & at_type=arg_type_r}, tvh)
	substitute_type type tvh
		= (type, tvh)
	
	substitute_type_args [t:ts] tvh
		# (t_r, tvh) = substitute_type t.at_type tvh
		  (ts_r, tvh) = substitute_type_args ts tvh
		= ([{t & at_type=t_r}:ts_r], tvh)
	substitute_type_args [] tvh
		= ([], tvh)

compare_instance_root_types :: ![Type] ![Type] !{#CommonDefs} !*TypeVarHeap -> (!Int,!*TypeVarHeap)
compare_instance_root_types [type1:types1] [type2:types2] common_defs tvh
	# (compare_value,tvh) = compare_root_types type1 type2 common_defs tvh
	| compare_value==Equal
		= compare_instance_root_types types1 types2 common_defs tvh
		= (compare_value,tvh)
compare_instance_root_types [] [] common_defs tvh
	= (Equal,tvh)

compare_root_types :: !Type !Type !{#CommonDefs} !*TypeVarHeap -> (!CompareValue,!*TypeVarHeap)
compare_root_types type1=:(TA {type_index=type_index1} args1) type2=:(TA {type_index=type_index2} args2) common_defs tvh
	#! {td_rhs,td_args} = common_defs.[type_index1.glob_module].com_type_defs.[type_index1.glob_object]
	| td_rhs=:SynType _
		= compare_root_types_syn_type1 td_rhs td_args args1 type2 common_defs tvh
	#! {td_rhs,td_args} = common_defs.[type_index2.glob_module].com_type_defs.[type_index2.glob_object]
	| td_rhs=:SynType _
		= compare_root_types_syn_type2 type1 td_rhs td_args args2 common_defs tvh
		= compare_root_types_TAs type_index1 args1 type_index2 args2 tvh
compare_root_types type1=:(TA {type_index=type_index1} args1) type2=:(TAS {type_index=type_index2} args2 _) common_defs tvh
	#! {td_rhs,td_args} = common_defs.[type_index1.glob_module].com_type_defs.[type_index1.glob_object]
	| td_rhs=:SynType _
		= compare_root_types_syn_type1 td_rhs td_args args1 type2 common_defs tvh
		= compare_root_types_TAs type_index1 args1 type_index2 args2 tvh
compare_root_types (TA {type_index=type_index1} type_args) type2 common_defs tvh
	#! {td_rhs,td_args} = common_defs.[type_index1.glob_module].com_type_defs.[type_index1.glob_object]
	| td_rhs=:SynType _
		= compare_root_types_syn_type1 td_rhs td_args type_args type2 common_defs tvh
		= (Smaller,tvh)
compare_root_types (TAS {type_index=type_index1} args1 _) (TAS {type_index=type_index2} args2 _) common_defs tvh
	= compare_root_types_TAs type_index1 args1 type_index2 args2 tvh
compare_root_types type1=:(TAS {type_index=type_index1} args1 _) type2=:(TA {type_index=type_index2} args2) common_defs tvh
	#! {td_rhs,td_args} = common_defs.[type_index2.glob_module].com_type_defs.[type_index2.glob_object]
	| td_rhs=:SynType _
		= compare_root_types_syn_type2 type1 td_rhs td_args args2 common_defs tvh
		= compare_root_types_TAs type_index1 args1 type_index2 args2 tvh
compare_root_types type1 (TA {type_index=type_index2} type_args) common_defs tvh
	#! {td_rhs,td_args} = common_defs.[type_index2.glob_module].com_type_defs.[type_index2.glob_object]
	| td_rhs=:SynType _
		= compare_root_types_syn_type2 type1 td_rhs td_args type_args common_defs tvh
		= (Greater,tvh)
compare_root_types (TB bt1) (TB bt2) common_defs tvh
	| equal_constructor bt1 bt2
		= (Equal,tvh)
	| less_constructor bt1 bt2
		= (Smaller,tvh)
		= (Greater,tvh)
compare_root_types type1 type2 common_defs tvh
	| equal_constructor type1 type2
		= (Equal,tvh)
	| less_constructor type1 type2
		= (Smaller,tvh)
		= (Greater,tvh)

compare_root_types_syn_type1 (SynType {at_type=type1=:TV _}) td_args args1 type2 common_defs tvh
	# (expanded_type, tvh) = substitute_instance_type td_args args1 type1 tvh
	= compare_root_types expanded_type type2 common_defs tvh
compare_root_types_syn_type1 (SynType {at_type=type1=:(CV _ :@: _)}) td_args args1 type2 common_defs tvh
	# (expanded_type, tvh) = substitute_instance_type td_args args1 type1 tvh
	= compare_root_types expanded_type type2 common_defs tvh
compare_root_types_syn_type1 (SynType {at_type=type1}) td_args args1 type2 common_defs tvh
	= compare_root_types type1 type2 common_defs tvh

compare_root_types_syn_type2 type1 (SynType {at_type=type2=:TV _}) td_args args2 common_defs tvh
	# (expanded_type, tvh) = substitute_instance_type td_args args2 type2 tvh
	= compare_root_types type1 expanded_type common_defs tvh
compare_root_types_syn_type2 type1 (SynType {at_type=type2=:(CV _ :@: _)}) td_args args2 common_defs tvh
	# (expanded_type, tvh) = substitute_instance_type td_args args2 type2 tvh
	= compare_root_types type1 expanded_type common_defs tvh
compare_root_types_syn_type2 type1 (SynType {at_type=type2}) td_args args2 common_defs tvh
	= compare_root_types type1 type2 common_defs tvh

compare_root_types_TAs :: !(Global Int) ![AType] !(Global Int) ![AType] !*TypeVarHeap -> (!CompareValue,!*TypeVarHeap)
compare_root_types_TAs type_index1 args1 type_index2 args2 tvh
	| type_index1.glob_module==type_index2.glob_module
		| type_index1.glob_object==type_index2.glob_object
			# n_args1 = length args1
			# n_args2 = length args1
			| n_args1==n_args2
				= (Equal,tvh)
			| n_args1<n_args2
				= (Smaller,tvh)
				= (Greater,tvh)
		| type_index1.glob_object<type_index2.glob_object
			= (Smaller,tvh)
			= (Greater,tvh)
	| type_index1.glob_module<type_index2.glob_module
		= (Smaller,tvh)
		= (Greater,tvh)

instance_root_types_specified :: ![Type] !{#CommonDefs} !*TypeVarHeap -> (!Bool,!*TypeVarHeap)
instance_root_types_specified [type:types] common_defs tvh
	# (can_be_compared,tvh) = root_type_can_be_compared type common_defs tvh
	| can_be_compared
		= instance_root_types_specified types common_defs tvh
		= (False,tvh)
instance_root_types_specified [] common_defs tvh
	= (True,tvh)

root_type_can_be_compared :: !Type !{#CommonDefs} !*TypeVarHeap -> (!Bool,!*TypeVarHeap)
root_type_can_be_compared (TA {type_index={glob_object,glob_module}} type_args) common_defs tvh
	#! {td_rhs,td_args} = common_defs.[glob_module].com_type_defs.[glob_object]
	= case td_rhs of
		SynType {at_type=TA _ _}
			-> (True,tvh)
		SynType {at_type=TAS _ _ _}
			-> (True,tvh)
		SynType {at_type=syn_type_rhs=:TV _}
			# (expanded_type, tvh) = substitute_instance_type td_args type_args syn_type_rhs tvh
			-> root_type_can_be_compared expanded_type common_defs tvh
		SynType {at_type=syn_type_rhs=:(CV _ :@: _)}
			# (expanded_type, tvh) = substitute_instance_type td_args type_args syn_type_rhs tvh
			-> root_type_can_be_compared expanded_type common_defs tvh
		SynType {at_type}
			| type_is_basic_or_function_type at_type
				-> (True,tvh)
				-> (False,tvh)
		_
			-> (True,tvh)
root_type_can_be_compared (TAS _ _ _) common_defs tvh
	= (True,tvh)
root_type_can_be_compared type common_defs tvh
	| type_is_basic_or_function_type type
		= (True,tvh)
		= (False,tvh)

type_is_basic_or_function_type :: !Type -> Bool
type_is_basic_or_function_type (TB _) = True
type_is_basic_or_function_type (_ --> _) = True
type_is_basic_or_function_type TArrow = True
type_is_basic_or_function_type (TArrow1 _) = True
type_is_basic_or_function_type _ = False

check_if_default_instance_types :: ![Type] ![TypeVarInfoPtr] !{#CommonDefs} !Bool !*TypeVarHeap -> (!Bool,!*TypeVarHeap)
check_if_default_instance_types [type:types] previous_type_vars common_defs has_root_type_var tvh
	# (is_polymorphic,previous_type_vars,has_root_type_var,tvh) = check_if_default_instance_type_arg type previous_type_vars common_defs has_root_type_var tvh
	| is_polymorphic
		= check_if_default_instance_types types previous_type_vars common_defs has_root_type_var tvh
		= (False,tvh)
check_if_default_instance_types [] previous_type_vars common_defs has_root_type_var tvh
	= (has_root_type_var,tvh)

check_if_default_instance_type_arg :: !Type ![TypeVarInfoPtr] !{#CommonDefs} !Bool !*TypeVarHeap -> (!Bool,[TypeVarInfoPtr],!Bool,!*TypeVarHeap)
check_if_default_instance_type_arg (TV {tv_info_ptr}) previous_type_vars common_defs has_root_type_var tvh
	| IsMember tv_info_ptr previous_type_vars
		= (False,previous_type_vars,has_root_type_var,tvh)
		# has_root_type_var = True
		= (True,[tv_info_ptr:previous_type_vars],has_root_type_var,tvh)
check_if_default_instance_type_arg (TA {type_index={glob_object,glob_module}} type_args) previous_type_vars common_defs has_root_type_var tvh
	#! {td_rhs,td_args} = common_defs.[glob_module].com_type_defs.[glob_object]
	= case td_rhs of
		SynType {at_type=syn_type_rhs}
			# (expanded_type, tvh) = substitute_instance_type td_args type_args syn_type_rhs tvh
			-> check_if_default_instance_type_arg expanded_type previous_type_vars common_defs has_root_type_var tvh
		_
			-> only_used_once_type_variables type_args previous_type_vars common_defs has_root_type_var tvh
check_if_default_instance_type_arg (TAS _ type_args _) previous_type_vars common_defs has_root_type_var tvh
	= only_used_once_type_variables type_args previous_type_vars common_defs has_root_type_var tvh
check_if_default_instance_type_arg (TB _) previous_type_vars common_defs has_root_type_var tvh
	= (True,previous_type_vars,has_root_type_var,tvh)
check_if_default_instance_type_arg (type1 --> type2) previous_type_vars common_defs has_root_type_var tvh
	= only_used_once_type_variables [type1,type2] previous_type_vars common_defs has_root_type_var tvh
check_if_default_instance_type_arg TArrow previous_type_vars common_defs has_root_type_var tvh
	= (True,previous_type_vars,has_root_type_var,tvh)
check_if_default_instance_type_arg (TArrow1 type) previous_type_vars common_defs has_root_type_var tvh
	= only_used_once_type_variables [type] previous_type_vars common_defs has_root_type_var tvh
check_if_default_instance_type_arg type previous_type_vars common_defs has_root_type_var tvh
	= (False,previous_type_vars,has_root_type_var,tvh)

only_used_once_type_variables :: ![AType] ![TypeVarInfoPtr] !{#CommonDefs} !Bool !*TypeVarHeap -> (!Bool,[TypeVarInfoPtr],!Bool,!*TypeVarHeap)
only_used_once_type_variables [{at_type=TV {tv_info_ptr}}:type_args] previous_type_vars common_defs has_root_type_var tvh
	| IsMember tv_info_ptr previous_type_vars
		= (False,previous_type_vars,has_root_type_var,tvh)
		# previous_type_vars = [tv_info_ptr:previous_type_vars]
		= only_used_once_type_variables type_args previous_type_vars common_defs has_root_type_var tvh
only_used_once_type_variables [type_arg1=:{at_type=TA {type_index={glob_object,glob_module}} type_args_TA}:type_args] previous_type_vars common_defs has_root_type_var tvh
	#! {td_rhs,td_args} = common_defs.[glob_module].com_type_defs.[glob_object]
	= case td_rhs of
		SynType {at_type=syn_type_rhs}
			# (expanded_type, tvh) = substitute_instance_type td_args type_args_TA syn_type_rhs tvh
			-> only_used_once_type_variables [{type_arg1 & at_type=expanded_type}:type_args] previous_type_vars common_defs has_root_type_var tvh
		_
			-> (False,previous_type_vars,has_root_type_var,tvh)
only_used_once_type_variables [_:_] previous_type_vars common_defs has_root_type_var tvh
	= (False,previous_type_vars,has_root_type_var,tvh)
only_used_once_type_variables [] previous_type_vars common_defs has_root_type_var tvh
	= (True,previous_type_vars,has_root_type_var,tvh)
