implementation module partition

import syntax, checksupport, utilities

//	PARTITIONING

::	PartitioningInfo =
	{	pi_marks :: 		!.{# Int}
	,	pi_next_num ::		!Int
	,	pi_next_group ::	!Int
	,	pi_groups ::		![ComponentMembers]
	,	pi_deps ::			![Int]
	}

NotChecked :== -1	

partitionateFunctions :: !*{# FunDef} ![IndexRange] -> (!*{!Component}, !*{# FunDef})
partitionateFunctions fun_defs ranges
	#! max_fun_nr = size fun_defs
	# partitioning_info = { pi_marks = createArray max_fun_nr NotChecked, pi_deps = [], pi_next_num = 0, pi_next_group = 0, pi_groups = [] }
	  (fun_defs, {pi_groups,pi_next_group}) = 
	  		foldSt (partitionate_functions max_fun_nr) ranges (fun_defs, partitioning_info)
	  groups = { {component_members = group} \\ group <- reverse pi_groups }
	= (groups, fun_defs)
where
	partitionate_functions :: !Index !IndexRange !(!*{# FunDef}, !*PartitioningInfo) -> (!*{# FunDef}, !*PartitioningInfo)
	partitionate_functions max_fun_nr ir=:{ir_from,ir_to} (fun_defs, pi=:{pi_marks})
		| ir_from == ir_to
			= (fun_defs, pi)
		| pi_marks.[ir_from] == NotChecked
			# (_, fun_defs, pi) = partitionate_function ir_from max_fun_nr fun_defs pi
			= partitionate_functions max_fun_nr { ir & ir_from = inc ir_from } (fun_defs, pi)
			= partitionate_functions max_fun_nr { ir & ir_from = inc ir_from } (fun_defs, pi)

	partitionate_function :: !Int !Int !*{# FunDef} !*PartitioningInfo -> *(!Int, !*{# FunDef}, !*PartitioningInfo)
	partitionate_function fun_index max_fun_nr fun_defs pi=:{pi_next_num}
		# (fd, fun_defs) = fun_defs![fun_index]
		# {fi_calls} = fd.fun_info
		  (min_dep, fun_defs, pi) = visit_functions fi_calls max_fun_nr max_fun_nr fun_defs (push_on_dep_stack fun_index pi)
			with
				visit_functions :: ![FunCall] !Int !Int !*{# FunDef} !*PartitioningInfo -> *(!Int, !*{# FunDef}, !*PartitioningInfo)
				visit_functions [FunCall fc_index _:funs] min_dep max_fun_nr fun_defs pi=:{pi_marks} 
					#! mark = pi_marks.[fc_index]
					| mark == NotChecked
						# (mark, fun_defs, pi) = partitionate_function fc_index max_fun_nr fun_defs  pi
						= visit_functions funs (min min_dep mark) max_fun_nr fun_defs pi
						= visit_functions funs (min min_dep mark) max_fun_nr fun_defs pi
				visit_functions [DclFunCall module_index fc_index:funs] min_dep max_fun_nr fun_defs pi
					= visit_functions funs min_dep max_fun_nr fun_defs pi
				visit_functions [] min_dep max_fun_nr fun_defs pi
					= (min_dep, fun_defs, pi)
		= try_to_close_group fun_index pi_next_num min_dep max_fun_nr fun_defs pi

	push_on_dep_stack :: !Int !*PartitioningInfo -> *PartitioningInfo;
	push_on_dep_stack fun_index pi=:{pi_deps,pi_marks,pi_next_num}
		= { pi & pi_deps = [fun_index : pi_deps], pi_marks = { pi_marks & [fun_index] = pi_next_num}, pi_next_num = inc pi_next_num}

	try_to_close_group :: !Int !Int !Int !Int !*{# FunDef} !*PartitioningInfo -> *(!Int, !*{# FunDef}, !*PartitioningInfo)
	try_to_close_group fun_index fun_nr min_dep max_fun_nr fun_defs pi=:{pi_marks, pi_deps, pi_groups, pi_next_group}
		| fun_nr <= min_dep
			# (pi_deps, pi_marks, group, fun_defs)
				= close_group False False fun_index pi_deps pi_marks NoComponentMembers max_fun_nr pi_next_group fun_defs
			  pi = { pi & pi_deps = pi_deps, pi_marks = pi_marks, pi_next_group = inc pi_next_group,  pi_groups = [group : pi_groups] }
			= (max_fun_nr, fun_defs, pi)
			= (min_dep, fun_defs, pi)
	where
		close_group :: !Bool !Bool !Int ![Int] !*{# Int} !ComponentMembers !Int !Int !*{# FunDef} -> (![Int], !*{# Int}, !ComponentMembers, !*{# FunDef})
		close_group n_r_known non_recursive fun_index [d:ds] marks group max_fun_nr group_number fun_defs
			# marks = { marks & [d] = max_fun_nr }
			# (fd,fun_defs) = fun_defs![d]
			# non_recursive = case n_r_known of
								True	-> non_recursive
								_		-> case fun_index == d of
									True	-> isEmpty [fc \\ fc <- fd.fun_info.fi_calls | case fc of FunCall idx _ -> idx == d; _ -> False]
									_		-> False
			# fd = { fd & fun_info.fi_group_index = group_number, fun_info.fi_properties = set_rec_prop non_recursive fd.fun_info.fi_properties}
			# fun_defs = { fun_defs & [d] = fd}
			| d == fun_index
				= (ds, marks, ComponentMember d group, fun_defs)
				= close_group True non_recursive fun_index ds marks (ComponentMember d group) max_fun_nr group_number fun_defs

::	PartitioningInfo` = 
	{	pi_marks` :: 		!.{# Int}
	,	pi_next_num` ::		!Int
	,	pi_next_group` ::	!Int
	,	pi_groups` ::		![ComponentMembers]
	,	pi_deps` ::			![Int]
	,	pi_collect` ::		!.CountVarsFindCallsState
	}

partitionateFunctions` :: !*{#FunDef} ![IndexRange] !Index !Int !Int !*PredefinedSymbols !*VarHeap !*ExpressionHeap !*ErrorAdmin
									  -> (!*{!Component},!*{#FunDef},!*PredefinedSymbols,!*VarHeap,!*ExpressionHeap,!*ErrorAdmin)
partitionateFunctions` fun_defs ranges main_dcl_module_n def_min def_max predef_symbols var_heap sym_heap error_admin
	# (predef_alias_dummy,predef_symbols) = predef_symbols![PD_DummyForStrictAliasFun]
	# collect_info
		= {cvfci_predef_alias_dummy=predef_alias_dummy, cvfci_main_dcl_module_n=main_dcl_module_n, cvfci_def_min=def_min, cvfci_def_max=def_max}
	= partitionateFunctions` fun_defs ranges collect_info predef_symbols var_heap sym_heap error_admin
where
  partitionateFunctions` :: !*{# FunDef} ![IndexRange] !CountVarsFindCallsInfo !*PredefinedSymbols !*VarHeap !*ExpressionHeap !*ErrorAdmin -> (!*{!Component}, !*{# FunDef}, !*PredefinedSymbols, !*VarHeap, !*ExpressionHeap, !*ErrorAdmin)
  partitionateFunctions` fun_defs ranges collect_info predef_symbols var_heap sym_heap error_admin
	#! max_fun_nr = size fun_defs
	# collect_state = {cvfcs_var_heap = var_heap, cvfcs_expr_heap = sym_heap, cvfcs_error = error_admin, cvfcs_fun_calls = []}
	# partitioning_info =
		{ pi_collect` = collect_state
		, pi_marks` = createArray max_fun_nr NotChecked
		, pi_deps` = []
		, pi_next_num` = 0
		, pi_next_group` = 0
		, pi_groups` = [] 
		}
	  (fun_defs, {pi_groups`,pi_next_group`,pi_collect`}) = 
	  		foldSt (partitionate_functions max_fun_nr) ranges (fun_defs, partitioning_info)
	  groups = { {component_members = group} \\ group <- reverse pi_groups` }
	= (groups, fun_defs, predef_symbols, pi_collect`.cvfcs_var_heap, pi_collect`.cvfcs_expr_heap, pi_collect`.cvfcs_error)
	where
	partitionate_functions :: !Index !IndexRange !(!*{#FunDef}, !*PartitioningInfo`) -> (!*{#FunDef}, !*PartitioningInfo`)
	partitionate_functions max_fun_nr ir=:{ir_from,ir_to} (fun_defs, pi=:{pi_marks`})
		| ir_from == ir_to
			= (fun_defs, pi)
		| pi_marks`.[ir_from] == NotChecked
			# (_, fun_defs, pi) = partitionate_function ir_from max_fun_nr fun_defs pi
			= partitionate_functions max_fun_nr {ir & ir_from = inc ir_from} (fun_defs, pi)
			= partitionate_functions max_fun_nr {ir & ir_from = inc ir_from} (fun_defs, pi)

	partitionate_function :: !Int !Int !*{#FunDef} !*PartitioningInfo` -> *(!Int, !*{# FunDef}, !*PartitioningInfo`)
	partitionate_function fun_index max_fun_nr fun_defs pi=:{pi_next_num`,pi_collect`}
		# (fd, fun_defs) = fun_defs![fun_index]
		  (fd,pi_collect`) = determine_ref_counts collect_info fd pi_collect`
		  (fi_calls,pi_collect`) = pi_collect`!cvfcs_fun_calls
		  pi & pi_collect` = pi_collect`
		  fd & fun_info.fi_calls = fi_calls
		  fun_defs & [fun_index] = fd

		  pi = push_on_dep_stack fun_index pi
		  (min_dep, fun_defs, pi) = visit_functions fi_calls max_fun_nr max_fun_nr fun_defs pi
			with
				visit_functions :: ![FunCall] !Int !Int !*{# FunDef} !*PartitioningInfo` -> *(!Int, !*{# FunDef}, !*PartitioningInfo`)
				visit_functions [FunCall fc_index _:funs] min_dep max_fun_nr fun_defs pi=:{pi_marks`} 
					#! mark = pi_marks`.[fc_index]
					| mark == NotChecked
						# (mark, fun_defs, pi) = partitionate_function fc_index max_fun_nr fun_defs pi
						= visit_functions funs (min min_dep mark) max_fun_nr fun_defs pi
						= visit_functions funs (min min_dep mark) max_fun_nr fun_defs pi
				visit_functions [GeneratedFunCall fc_index _:funs] min_dep max_fun_nr fun_defs pi=:{pi_marks`}
					#! mark = pi_marks`.[fc_index]
					| mark == NotChecked
						# (mark, fun_defs, pi) = partitionate_function fc_index max_fun_nr fun_defs pi
						= visit_functions funs (min min_dep mark) max_fun_nr fun_defs pi
						= visit_functions funs (min min_dep mark) max_fun_nr fun_defs pi
				visit_functions [DclFunCall module_index fc_index:funs] min_dep max_fun_nr fun_defs pi
					= visit_functions funs min_dep max_fun_nr fun_defs pi
				visit_functions [] min_dep max_fun_nr fun_defs pi
					= (min_dep, fun_defs, pi)
		= try_to_close_group fun_index pi_next_num` min_dep max_fun_nr fun_defs pi

	push_on_dep_stack :: !Int !*PartitioningInfo` -> *PartitioningInfo`;
	push_on_dep_stack fun_index pi=:{pi_deps`,pi_marks`,pi_next_num`}
		= { pi & pi_deps` = [fun_index : pi_deps`], pi_marks` = { pi_marks` & [fun_index] = pi_next_num`}, pi_next_num` = inc pi_next_num`}

	try_to_close_group :: !Int !Int !Int !Int !*{# FunDef} !*PartitioningInfo` -> *(!Int, !*{# FunDef}, !*PartitioningInfo`)
	try_to_close_group fun_index fun_nr min_dep max_fun_nr fun_defs pi=:{pi_marks`, pi_deps`, pi_groups`, pi_next_group`}
		| fun_nr <= min_dep
			# (pi_deps`, pi_marks`, group, fun_defs)
				= close_group False False fun_index pi_deps` pi_marks` NoComponentMembers max_fun_nr pi_next_group` fun_defs
			  pi = { pi & pi_deps` = pi_deps`, pi_marks` = pi_marks`, pi_next_group` = inc pi_next_group`,  pi_groups` = [group : pi_groups`] }
			= (max_fun_nr, fun_defs, pi)
			= (min_dep, fun_defs, pi)
	where
		close_group :: !Bool !Bool !Int ![Int] !*{# Int} !ComponentMembers !Int !Int !*{# FunDef} -> (![Int], !*{# Int}, !ComponentMembers, !*{# FunDef})
		close_group n_r_known non_recursive fun_index [d:ds] marks group max_fun_nr group_number fun_defs
			# marks = { marks & [d] = max_fun_nr }
			# (fd,fun_defs) = fun_defs![d]
			# non_recursive = case n_r_known of
								True	-> non_recursive
								_		-> case fun_index == d of
									True	-> isEmpty [fc \\ fc <- fd.fun_info.fi_calls | case fc of FunCall idx _ -> idx == d; _ -> False]
									_		-> False
			# fd = { fd & fun_info.fi_group_index = group_number, fun_info.fi_properties = set_rec_prop non_recursive fd.fun_info.fi_properties}
			# fun_defs = { fun_defs & [d] = fd}
			| d == fun_index
				= (ds, marks, ComponentMember d group, fun_defs)
				= close_group True non_recursive fun_index ds marks (ComponentMember d group) max_fun_nr group_number fun_defs

::	PartitioningInfo`` = 
	{ pi_marks``			:: !.Marks
	, pi_next_num``			:: !Int
	, pi_next_group``		:: !Int
	, pi_groups``			:: ![ComponentMembers]
	, pi_deps``				:: !ComponentMembers
	, pi_collect``			:: !.CountVarsFindCallsState
	}

:: Marks	:== {# Mark}
:: Mark		= { m_fun :: !Int, m_mark :: !Int}

create_marks max_fun_nr functions
	= {{m_fun = fun, m_mark = NotChecked} \\ fun <- component_members_to_list functions}

component_members_to_list (ComponentMember member members)
	= [member : component_members_to_list members]
component_members_to_list (GeneratedComponentMember member _ members)
	= [member : component_members_to_list members]
component_members_to_list NoComponentMembers
	= []

get_mark max_fun_nr marks fun
	:== get_mark 0 marks fun max_fun_nr
where
	get_mark :: !Int !{#Mark} !Int !Int -> Int
	get_mark i marks fun max_fun_nr
		| i<size marks
			| marks.[i].m_fun<>fun
				= get_mark (i+1) marks fun max_fun_nr
				= marks.[i].m_mark
			= max_fun_nr

set_mark marks fun val
	:== set_mark 0 marks fun val
where
	set_mark :: !Int !*{#Mark} !Int !Int -> *{#Mark}
	set_mark i marks fun val
//		| i<size marks
		| marks.[i].m_fun<>fun
			= set_mark (i+1) marks fun val
			= {marks & [i].m_mark=val}

partitionateFunctions`` :: !Int !Int !*{#FunDef} !ComponentMembers !Index !Int !Int !*FunctionHeap !*PredefinedSymbols !*VarHeap !*ExpressionHeap !*ErrorAdmin
												  -> (!Int,![Component],!*{#FunDef},!*FunctionHeap,!*PredefinedSymbols,!*VarHeap,!*ExpressionHeap,!*ErrorAdmin)
partitionateFunctions`` max_fun_nr next_group fun_defs functions main_dcl_module_n def_min def_max fun_heap predef_symbols var_heap sym_heap error_admin
	# (predef_alias_dummy,predef_symbols) = predef_symbols![PD_DummyForStrictAliasFun]
	# collect_info
		= {cvfci_predef_alias_dummy=predef_alias_dummy, cvfci_main_dcl_module_n=main_dcl_module_n, cvfci_def_min=def_min, cvfci_def_max=def_max}
	= partitionateFunctions`` max_fun_nr next_group fun_defs functions collect_info fun_heap predef_symbols var_heap sym_heap error_admin
where
  partitionateFunctions`` :: !Int !Int !*{#FunDef} !ComponentMembers !CountVarsFindCallsInfo
  									  !*FunctionHeap !*PredefinedSymbols !*VarHeap !*ExpressionHeap !*ErrorAdmin
	-> (!Int,![Component],!*{#FunDef},!*FunctionHeap,!*PredefinedSymbols,!*VarHeap,!*ExpressionHeap,!*ErrorAdmin)
  partitionateFunctions`` max_fun_nr next_group fun_defs functions collect_info fun_heap predef_symbols var_heap sym_heap error_admin
	# marks					= create_marks max_fun_nr functions
	# collect_state = {cvfcs_var_heap = var_heap, cvfcs_expr_heap = sym_heap, cvfcs_error = error_admin, cvfcs_fun_calls = []}
	# partitioning_info =
		{ pi_marks``		= marks
		, pi_deps``			= NoComponentMembers
		, pi_next_num``		= 0
		, pi_next_group``	= next_group
		, pi_groups``		= [] 
		, pi_collect``		= collect_state
		}
	  (fun_defs, fun_heap, {pi_groups``,pi_next_group``,pi_collect``})
	  	= partitionate_component functions max_fun_nr (fun_defs, fun_heap, partitioning_info)
	  groups = [ {component_members = group} \\ group <- reverse pi_groups`` ]
	= (pi_next_group``,groups, fun_defs, fun_heap, predef_symbols, pi_collect``.cvfcs_var_heap, pi_collect``.cvfcs_expr_heap, pi_collect``.cvfcs_error)
	where
	partitionate_component :: !ComponentMembers !Index !(!*{#FunDef}, !*FunctionHeap, !*PartitioningInfo``) -> (!*{#FunDef}, !*FunctionHeap, !*PartitioningInfo``)
	partitionate_component (ComponentMember member members) max_fun_nr (fun_defs, fun_heap, pi=:{pi_marks``})
		| get_mark max_fun_nr pi_marks`` member == NotChecked
			# (_, fun_defs, fun_heap, pi) = partitionate_function member max_fun_nr fun_defs fun_heap pi
		 	= partitionate_component members max_fun_nr (fun_defs, fun_heap, pi)
		 	= partitionate_component members max_fun_nr (fun_defs, fun_heap, pi)
	partitionate_component (GeneratedComponentMember member fun_ptr members) max_fun_nr (fun_defs, fun_heap, pi=:{pi_marks``})
		| get_mark max_fun_nr pi_marks`` member == NotChecked
			# (_, fun_defs, fun_heap, pi) = partitionate_generated_function member fun_ptr max_fun_nr fun_defs fun_heap pi
			= partitionate_component members max_fun_nr (fun_defs, fun_heap, pi)
			= partitionate_component members max_fun_nr (fun_defs, fun_heap, pi)
	partitionate_component NoComponentMembers max_fun_nr (fun_defs, fun_heap, pi)
		= (fun_defs, fun_heap, pi)

	partitionate_function :: !Int !Int !*{# FunDef} !*FunctionHeap !*PartitioningInfo`` -> *(!Int, !*{# FunDef}, !*FunctionHeap, !*PartitioningInfo``)
	partitionate_function fun_index max_fun_nr fun_defs fun_heap pi=:{pi_next_num``,pi_collect``}
		# (fd,fun_defs) = fun_defs![fun_index]
		  (fd,pi_collect``) = determine_ref_counts collect_info fd pi_collect``
		  (fi_calls,pi_collect``) = pi_collect``!cvfcs_fun_calls
		  pi & pi_collect`` = pi_collect``
		  fd & fun_info.fi_calls = fi_calls
		  fun_defs & [fun_index] = fd
		  pi = push_on_dep_stack fun_index pi
		= visit_functions_and_try_to_close_group fi_calls fun_index pi_next_num`` max_fun_nr fun_defs fun_heap pi

	partitionate_generated_function :: !Int !FunctionInfoPtr !Int !*{# FunDef} !*FunctionHeap !*PartitioningInfo`` -> *(!Int, !*{# FunDef}, !*FunctionHeap, !*PartitioningInfo``)
	partitionate_generated_function fun_index fun_ptr max_fun_nr fun_defs fun_heap pi=:{pi_next_num``,pi_collect``}
		# (FI_Function gf=:{gf_fun_def=fd}, fun_heap) = readPtr fun_ptr fun_heap
		  (fd,pi_collect``) = determine_ref_counts collect_info fd pi_collect``
		  (fi_calls,pi_collect``) = pi_collect``!cvfcs_fun_calls
		  pi & pi_collect`` = pi_collect``
		  fd & fun_info.fi_calls = fi_calls
		  fun_heap = writePtr fun_ptr (FI_Function {gf & gf_fun_def = fd}) fun_heap
		  pi = push_generated_function_on_dep_stack fun_index fun_ptr pi
		= visit_functions_and_try_to_close_group fi_calls fun_index pi_next_num`` max_fun_nr fun_defs fun_heap pi

	visit_functions_and_try_to_close_group :: ![FunCall] !Int !Int !Int !*{#FunDef} !*FunctionHeap !*PartitioningInfo`` -> *(!Int,!*{#FunDef},!*FunctionHeap,!*PartitioningInfo``)
	visit_functions_and_try_to_close_group fi_calls fun_index pi_next_num`` max_fun_nr fun_defs fun_heap pi
		# (min_dep, fun_defs, fun_heap, pi) = visit_functions fi_calls max_fun_nr max_fun_nr fun_defs fun_heap pi
		= try_to_close_group fun_index pi_next_num`` min_dep max_fun_nr fun_defs fun_heap pi

	visit_functions :: ![FunCall] !Int !Int !*{# FunDef} !*FunctionHeap !*PartitioningInfo`` -> *(!Int, !*{# FunDef}, !*FunctionHeap, !*PartitioningInfo``)
	visit_functions [FunCall fc_index _:funs] min_dep max_fun_nr fun_defs fun_heap pi=:{pi_marks``} 
		#! mark = get_mark max_fun_nr pi_marks`` fc_index
		| mark == NotChecked
			# (mark, fun_defs, fun_heap, pi) = partitionate_function fc_index max_fun_nr fun_defs fun_heap pi
			= visit_functions funs (min min_dep mark) max_fun_nr fun_defs fun_heap pi
			= visit_functions funs (min min_dep mark) max_fun_nr fun_defs fun_heap pi
	visit_functions [GeneratedFunCall fc_index fun_ptr:funs] min_dep max_fun_nr fun_defs fun_heap pi=:{pi_marks``} 
		#! mark = get_mark max_fun_nr pi_marks`` fc_index
		| mark == NotChecked
			# (mark, fun_defs, fun_heap, pi) = partitionate_generated_function fc_index fun_ptr max_fun_nr fun_defs fun_heap pi
			= visit_functions funs (min min_dep mark) max_fun_nr fun_defs fun_heap pi
			= visit_functions funs (min min_dep mark) max_fun_nr fun_defs fun_heap pi
	visit_functions [DclFunCall module_index fc_index:funs] min_dep max_fun_nr fun_defs fun_heap pi
		= visit_functions funs min_dep max_fun_nr fun_defs fun_heap pi
	visit_functions [] min_dep max_fun_nr fun_defs fun_heap pi
		= (min_dep, fun_defs, fun_heap, pi)

	push_on_dep_stack :: !Int !*PartitioningInfo`` -> *PartitioningInfo``;
	push_on_dep_stack fun_index pi=:{pi_deps``,pi_marks``,pi_next_num``}
		= {pi & pi_deps`` = ComponentMember fun_index pi_deps``
			  , pi_marks`` = set_mark pi_marks`` fun_index pi_next_num``
			  , pi_next_num`` = inc pi_next_num`` }

	push_generated_function_on_dep_stack :: !Int !FunctionInfoPtr !*PartitioningInfo`` -> *PartitioningInfo``;
	push_generated_function_on_dep_stack fun_index fun_ptr pi=:{pi_deps``,pi_marks``,pi_next_num``}
		= {pi & pi_deps`` = GeneratedComponentMember fun_index fun_ptr pi_deps``
			  , pi_marks`` = set_mark pi_marks`` fun_index pi_next_num``
			  , pi_next_num`` = inc pi_next_num`` }

	try_to_close_group :: !Int !Int !Int !Int !*{# FunDef} !*FunctionHeap !*PartitioningInfo`` -> *(!Int, !*{# FunDef}, !*FunctionHeap, !*PartitioningInfo``)
	try_to_close_group fun_index fun_nr min_dep max_fun_nr fun_defs fun_heap pi=:{pi_marks``, pi_deps``, pi_groups``, pi_next_group``}
		| fun_nr <= min_dep
			# (pi_deps``, pi_marks``, group, fun_defs, fun_heap)
				= close_group False False fun_index pi_deps`` pi_marks`` NoComponentMembers max_fun_nr pi_next_group`` fun_defs fun_heap
			  pi = { pi & pi_deps`` = pi_deps``, pi_marks`` = pi_marks``, pi_next_group`` = inc pi_next_group``,  pi_groups`` = [group : pi_groups``] }
			= (max_fun_nr, fun_defs, fun_heap, pi)
			= (min_dep, fun_defs, fun_heap, pi)
	where
		close_group :: !Bool !Bool !Int !ComponentMembers !*Marks !ComponentMembers !Int !Int !*{# FunDef} !*FunctionHeap -> (!ComponentMembers, !*Marks, !ComponentMembers, !*{# FunDef}, !*FunctionHeap)
		close_group n_r_known non_recursive fun_index (ComponentMember d ds) marks group max_fun_nr group_number fun_defs fun_heap
			# marks = set_mark marks d max_fun_nr
			  (fun_info,fun_defs) = fun_defs![d].fun_info
			  non_recursive = determine_if_function_non_recursive n_r_known fun_index d fun_info.fi_calls non_recursive
			  fun_info = {fun_info & fi_group_index = group_number, fi_properties = set_rec_prop non_recursive fun_info.fi_properties}
			  fun_defs = {fun_defs & [d].fun_info = fun_info}
			| d == fun_index
				= (ds, marks, ComponentMember d group, fun_defs, fun_heap)
				= close_group True non_recursive fun_index ds marks (ComponentMember d group) max_fun_nr group_number fun_defs fun_heap
		close_group n_r_known non_recursive fun_index (GeneratedComponentMember d fun_ptr ds) marks group max_fun_nr group_number fun_defs fun_heap
			# marks = set_mark marks d max_fun_nr
			  (FI_Function gf=:{gf_fun_def={fun_info}}, fun_heap) = readPtr fun_ptr fun_heap
			  non_recursive = determine_if_function_non_recursive n_r_known fun_index d fun_info.fi_calls non_recursive
			  fun_info = {fun_info & fi_group_index = group_number, fi_properties = set_rec_prop non_recursive fun_info.fi_properties}
			  fun_heap = writePtr fun_ptr (FI_Function {gf & gf_fun_def.fun_info=fun_info}) fun_heap
			| d == fun_index
				= (ds, marks, GeneratedComponentMember d fun_ptr group, fun_defs, fun_heap)
				= close_group True non_recursive fun_index ds marks (GeneratedComponentMember d fun_ptr group) max_fun_nr group_number fun_defs fun_heap

		determine_if_function_non_recursive :: !Bool !Index !Index ![FunCall] !Bool -> Bool
		determine_if_function_non_recursive n_r_known fun_index d fi_calls non_recursive
			| n_r_known
				= non_recursive
				| fun_index == d
					= isEmpty [fc \\ fc <- fi_calls
									| case fc of FunCall idx _ -> idx == d; GeneratedFunCall idx _ -> idx == d; _ -> False]
					= False

:: CountVarsFindCallsInfo = !{
	cvfci_main_dcl_module_n		:: !Index,
	cvfci_def_min				:: !Int,
	cvfci_def_max				:: !Int,
	cvfci_predef_alias_dummy	:: !PredefinedSymbol
   }

:: CountVarsFindCallsState = {
	cvfcs_var_heap	:: !.VarHeap,
	cvfcs_expr_heap	:: !.ExpressionHeap,
	cvfcs_error		:: !.ErrorAdmin,
	cvfcs_fun_calls	:: ![FunCall]
   }

determine_ref_counts cvfci fd=:{fun_body=TransformedBody {tb_args,tb_rhs}} pi_collect
	# (new_rhs, new_args, pi_collect) = determineVariablesAndRefCounts tb_args tb_rhs cvfci {pi_collect & cvfcs_fun_calls = []}
	# fd = {fd & fun_body=TransformedBody {tb_args=new_args,tb_rhs=new_rhs}}
	= (fd,pi_collect)
determine_ref_counts cvfci fd pi_collect
	= (fd, pi_collect)

set_rec_prop non_recursive fi_properties
	| non_recursive
		= fi_properties bitor FI_IsNonRecursive
		= fi_properties bitand (bitnot FI_IsNonRecursive)

determineVariablesAndRefCounts :: ![FreeVar] !Expression !CountVarsFindCallsInfo !*CountVarsFindCallsState -> (!Expression , ![FreeVar], !*CountVarsFindCallsState)
determineVariablesAndRefCounts free_vars expr cvfci cvfcs=:{cvfcs_var_heap}
	# cvfcs & cvfcs_var_heap = clearCount free_vars cIsAGlobalVar cvfcs_var_heap
	  (expr, cvfcs) = countVarsFindCalls expr cvfci cvfcs
	  (free_vars, cvfcs_var_heap) = retrieveRefCounts free_vars cvfcs.cvfcs_var_heap
	= (expr, free_vars, {cvfcs & cvfcs_var_heap = cvfcs_var_heap})

retrieveRefCounts free_vars var_heap
	= mapSt retrieveRefCount free_vars var_heap

retrieveRefCount :: FreeVar *VarHeap -> (!FreeVar,!.VarHeap)
retrieveRefCount fv=:{fv_info_ptr} var_heap
	# (VI_Count count _, var_heap) = readPtr fv_info_ptr var_heap
	= ({ fv & fv_count = count }, var_heap)

class clearCount a :: !a !Bool !*VarHeap -> *VarHeap

instance clearCount [a] | clearCount a
where
	clearCount [x:xs] locality var_heap
		= clearCount x locality (clearCount xs locality var_heap)
	clearCount [] locality var_heap
		= var_heap

instance clearCount LetBind
where
	clearCount bind=:{lb_dst} locality var_heap
		= clearCount lb_dst locality var_heap

instance clearCount FreeVar
where
	clearCount {fv_info_ptr} locality var_heap
		= var_heap <:= (fv_info_ptr, VI_Count 0 locality)

instance clearCount (FreeVar,a)
where
	clearCount ({fv_info_ptr},_) locality var_heap
		= var_heap <:= (fv_info_ptr, VI_Count 0 locality)

//	In 'countVarsFindCalls' the reference counts of the local as well as of the global variables are determined.
//	Aliases and unreachable bindings introduced in a 'let' are removed.

class countVarsFindCalls a :: !a !CountVarsFindCallsInfo !*CountVarsFindCallsState -> (!a, !*CountVarsFindCallsState)

cContainsACycle		:== True
cContainsNoCycle	:== False

instance countVarsFindCalls Expression
where
	countVarsFindCalls (Var var) cvfci cvfcs
		# (var, cvfcs) = countVarsFindCalls var cvfci cvfcs
		= (Var var, cvfcs)
	countVarsFindCalls (App app=:{app_symb={symb_kind},app_args}) cvfci cvfcs
		# (app_args, cvfcs) = countVarsFindCalls app_args cvfci cvfcs
		# cvfcs = get_index symb_kind cvfcs
		= (App {app & app_args = app_args}, cvfcs)
	where
		get_index (SK_Function {glob_object,glob_module}) cvfcs
			| cvfci.cvfci_main_dcl_module_n == glob_module && (glob_object < cvfci.cvfci_def_max || glob_object >= cvfci.cvfci_def_min)
				= {cvfcs & cvfcs_fun_calls = [FunCall glob_object 0: cvfcs.cvfcs_fun_calls]}
				= {cvfcs & cvfcs_fun_calls = [DclFunCall glob_module glob_object: cvfcs.cvfcs_fun_calls]}
		get_index (SK_Constructor idx) cvfcs
			= cvfcs
		get_index (SK_LocalMacroFunction idx) cvfcs
			= {cvfcs & cvfcs_fun_calls = [FunCall idx 0: cvfcs.cvfcs_fun_calls]}
		get_index (SK_GeneratedFunction fun_ptr idx) cvfcs
			= {cvfcs & cvfcs_fun_calls = [GeneratedFunCall idx fun_ptr : cvfcs.cvfcs_fun_calls]}
	countVarsFindCalls (expr @ exprs) cvfci cvfcs
		# ((expr, exprs), cvfcs) = countVarsFindCalls (expr, exprs) cvfci cvfcs
		= (expr @ exprs, cvfcs)
	countVarsFindCalls (Let lad=:{let_strict_binds, let_lazy_binds, let_expr, let_info_ptr}) cvfci cvfcs=:{cvfcs_var_heap}
		# cvfcs_var_heap = determine_aliases let_strict_binds cvfcs.cvfcs_var_heap
		  cvfcs_var_heap = determine_aliases let_lazy_binds cvfcs_var_heap

		  (let_info,cvfcs_expr_heap)	= readPtr let_info_ptr cvfcs.cvfcs_expr_heap
		  let_types = case let_info of
						EI_LetType let_types	-> let_types
						_						-> repeat undef
		  cvfcs & cvfcs_var_heap=cvfcs_var_heap, cvfcs_expr_heap = cvfcs_expr_heap

		  (let_strict_binds, let_types)	= combine let_strict_binds let_types
				with
					combine [] let_types
						= ([],let_types)
					combine [lb:let_binds] [tp:let_types]
						# (let_binds,let_types)	= combine let_binds let_types
						= ([(tp, lb) : let_binds], let_types)
		  let_lazy_binds = zip2 let_types let_lazy_binds

		  (is_cyclic_s, let_strict_binds, cvfcs)
				= detect_cycles_and_handle_alias_binds True let_strict_binds cvfcs
		  (is_cyclic_l, let_lazy_binds, cvfcs)
				= detect_cycles_and_handle_alias_binds False let_lazy_binds cvfcs
		| is_cyclic_s || is_cyclic_l
			# (let_strict_bind_types,let_strict_binds) = unzip let_strict_binds
			  (let_lazy_bind_types,let_lazy_binds) = unzip let_lazy_binds
			  let_info = case let_info of
				EI_LetType _	-> EI_LetType (let_strict_bind_types ++ let_lazy_bind_types)
				_				-> let_info
			  cvfcs & cvfcs_expr_heap = writePtr let_info_ptr let_info cvfcs.cvfcs_expr_heap
			= (Let {lad & let_strict_binds = let_strict_binds, let_lazy_binds = let_lazy_binds },
					{cvfcs & cvfcs_error = checkError "" "cyclic let definition" cvfcs.cvfcs_error})
//		| otherwise
			# (let_expr, cvfcs) = countVarsFindCalls let_expr cvfci cvfcs
			  (collected_strict_binds, collected_lazy_binds, cvfcs)
				= collect_variables_in_binds let_strict_binds let_lazy_binds [] [] cvfcs
			| collected_strict_binds=:[] && collected_lazy_binds=:[]
				= (let_expr, cvfcs)
				# (let_strict_bind_types,let_strict_binds) = unzip collected_strict_binds
				  (let_lazy_bind_types,let_lazy_binds) = unzip collected_lazy_binds
				  let_info = case let_info of
					EI_LetType _	-> EI_LetType (let_strict_bind_types ++ let_lazy_bind_types)
					_				-> let_info
				  cvfcs & cvfcs_expr_heap = writePtr let_info_ptr let_info cvfcs.cvfcs_expr_heap
				= (Let {lad & let_expr = let_expr, let_strict_binds = let_strict_binds, let_lazy_binds = let_lazy_binds}, cvfcs)
		where
		/*	Set the 'var_info_field' of each  bound variable to either 'VI_Alias var' (if
			this variable is an alias for 'var') or to 'VI_Count 0 cIsALocalVar' to initialise
			the reference count info.
		*/
			determine_aliases [{lb_dst={fv_info_ptr}, lb_src = Var var} : binds] var_heap
				= determine_aliases binds (writePtr fv_info_ptr (VI_Alias var) var_heap)
			determine_aliases [bind : binds] var_heap
				= determine_aliases binds (clearCount bind cIsALocalVar var_heap)
			determine_aliases [] var_heap
				= var_heap

		/*	Remove all aliases from the list of lazy 'let'-binds. Add a _dummyForStrictAlias
			function call for the strict aliases. Be careful with cycles! */

			detect_cycles_and_handle_alias_binds :: !Bool ![(t,LetBind)] !*CountVarsFindCallsState -> (!Bool,![(t,LetBind)],!*CountVarsFindCallsState)
			detect_cycles_and_handle_alias_binds is_strict [] cvfcs
				= (cContainsNoCycle, [], cvfcs)
//			detect_cycles_and_handle_alias_binds is_strict [bind=:{bind_dst={fv_info_ptr}} : binds] cvfcs
			detect_cycles_and_handle_alias_binds is_strict [(type,bind=:{lb_dst={fv_info_ptr}}) : binds] cvfcs
				# (var_info, cvfcs_var_heap) = readPtr fv_info_ptr cvfcs.cvfcs_var_heap
				  cvfcs & cvfcs_var_heap = cvfcs_var_heap
				= case var_info of
					VI_Alias {var_info_ptr}
						| is_cyclic fv_info_ptr var_info_ptr cvfcs.cvfcs_var_heap
							-> (cContainsACycle, binds, cvfcs)
						| is_strict
							# cvfcs_var_heap = writePtr fv_info_ptr (VI_Count 0 cIsALocalVar) cvfcs.cvfcs_var_heap
							  (new_bind_src, cvfcs) = add_dummy_id_for_strict_alias bind.lb_src cvfci
															{cvfcs & cvfcs_var_heap = cvfcs_var_heap}
							  (is_cyclic, binds, cvfcs)
									= detect_cycles_and_handle_alias_binds is_strict binds cvfcs
							-> (is_cyclic, [(type,{ bind & lb_src = new_bind_src }) : binds], cvfcs)
						-> detect_cycles_and_handle_alias_binds is_strict binds cvfcs
					_
						# (is_cyclic, binds, cvfcs) = detect_cycles_and_handle_alias_binds is_strict binds cvfcs
						-> (is_cyclic, [(type,bind) : binds], cvfcs)
			where
				is_cyclic :: !VarInfoPtr !VarInfoPtr !VarHeap -> .Bool
				is_cyclic orig_info_ptr info_ptr var_heap
					| orig_info_ptr == info_ptr
						= True
						#! var_info = sreadPtr info_ptr var_heap
						= case var_info of
							VI_Alias {var_info_ptr}
								-> is_cyclic orig_info_ptr var_info_ptr var_heap
							_
								-> False

				add_dummy_id_for_strict_alias :: !.Expression !CountVarsFindCallsInfo !*CountVarsFindCallsState -> (!.Expression,!.CountVarsFindCallsState)
				add_dummy_id_for_strict_alias bind_src {cvfci_predef_alias_dummy} cvfcs=:{cvfcs_expr_heap}
					# (new_app_info_ptr, cvfcs_expr_heap) = newPtr EI_Empty cvfcs_expr_heap
					  {pds_module, pds_def} = cvfci_predef_alias_dummy
					  pds_ident = predefined_idents.[PD_DummyForStrictAliasFun]
					  app_symb = { symb_ident = pds_ident, symb_kind = SK_Function {glob_module = pds_module, glob_object = pds_def} }
					= (App { app_symb = app_symb, app_args = [bind_src], app_info_ptr = new_app_info_ptr },
						{cvfcs & cvfcs_expr_heap = cvfcs_expr_heap} )

		/*	Apply 'countVarsFindCalls' to the bound expressions (the 'bind_src' field of 'let'-bind) if
		    the corresponding bound variable (the 'bind_dst' field) has been used. This can be determined
		    by examining the reference count.
		*/
			collect_variables_in_binds :: ![(t,LetBind)] ![(t,LetBind)] ![(t,LetBind)] ![(t,LetBind)] !*CountVarsFindCallsState
																	-> (![(t,LetBind)],![(t,LetBind)],!*CountVarsFindCallsState)
			collect_variables_in_binds strict_binds lazy_binds collected_strict_binds collected_lazy_binds cvfcs
				# (bind_fond, lazy_binds, collected_lazy_binds, cvfcs)
					= examine_reachable_binds False lazy_binds collected_lazy_binds cvfcs
				# (bind_fond, strict_binds, collected_strict_binds, cvfcs)
					= examine_reachable_binds bind_fond strict_binds collected_strict_binds cvfcs
				| bind_fond
					= collect_variables_in_binds strict_binds lazy_binds collected_strict_binds collected_lazy_binds cvfcs
					# cvfcs & cvfcs_error=report_unused_strict_binds strict_binds cvfcs.cvfcs_error
					= (collected_strict_binds, collected_lazy_binds, cvfcs)

			examine_reachable_binds :: !Bool ![(t,LetBind)] ![(t,LetBind)] !*CountVarsFindCallsState -> *(!Bool,![(t,LetBind)],![(t,LetBind)],!*CountVarsFindCallsState)
			examine_reachable_binds bind_found [bind=:(type, letb=:{lb_dst=fv=:{fv_info_ptr},lb_src}) : binds] collected_binds cvfcs
				# (bind_found, binds, collected_binds, cvfcs) = examine_reachable_binds bind_found binds collected_binds cvfcs
				# (info, cvfcs_var_heap) = readPtr fv_info_ptr cvfcs.cvfcs_var_heap
				# cvfcs & cvfcs_var_heap = cvfcs_var_heap
				= case info of
					VI_Count count _
						| count > 0
							#  (lb_src, cvfcs) = countVarsFindCalls lb_src cvfci cvfcs
							-> (True, binds, [ (type, { letb & lb_dst = { fv & fv_count = count }, lb_src = lb_src }) : collected_binds ], cvfcs)
							-> (bind_found, [bind : binds], collected_binds, cvfcs)
			examine_reachable_binds bind_found [] collected_binds cvfcs
				= (bind_found, [], collected_binds, cvfcs)

			report_unused_strict_binds [(type,{lb_dst={fv_ident},lb_position}):binds] errors
				= report_unused_strict_binds binds (checkWarningWithPosition fv_ident lb_position "not used, ! ignored" errors)
			report_unused_strict_binds [] errors
				= errors

	countVarsFindCalls (Case case_expr) cvfci cvfcs
		# (case_expr, cvfcs) = countVarsFindCalls case_expr cvfci cvfcs
		= (Case case_expr, cvfcs)
	countVarsFindCalls (Selection is_unique expr selectors) cvfci cvfcs
		# ((expr, selectors), cvfcs) = countVarsFindCalls (expr, selectors) cvfci cvfcs
		= (Selection is_unique expr selectors, cvfcs)
	countVarsFindCalls (Update expr1 selectors expr2) cvfci cvfcs
		# (((expr1, expr2), selectors), cvfcs) = countVarsFindCalls ((expr1, expr2), selectors) cvfci cvfcs
		= (Update expr1 selectors expr2, cvfcs)
	countVarsFindCalls (RecordUpdate cons_symbol expression expressions) cvfci cvfcs
		# ((expression, expressions), cvfcs) = countVarsFindCalls (expression, expressions) cvfci cvfcs
		= (RecordUpdate cons_symbol expression expressions, cvfcs)
	countVarsFindCalls (TupleSelect symbol argn_nr expr) cvfci cvfcs
		# (expr, cvfcs) = countVarsFindCalls expr cvfci cvfcs
		= (TupleSelect symbol argn_nr expr, cvfcs)
	countVarsFindCalls (MatchExpr cons_ident expr) cvfci cvfcs
		# (expr, cvfcs) = countVarsFindCalls expr cvfci cvfcs
		= (MatchExpr cons_ident expr, cvfcs)
	countVarsFindCalls (IsConstructor expr cons_symbol cons_arity global_type_index case_ident position) cvfci cvfcs
		# (expr, cvfcs) = countVarsFindCalls expr cvfci cvfcs
		= (IsConstructor expr cons_symbol cons_arity global_type_index case_ident position, cvfcs)
	countVarsFindCalls (TypeSignature type_function expr) cvfci cvfcs
		# (expr, cvfcs) = countVarsFindCalls expr cvfci cvfcs
		= (TypeSignature type_function expr, cvfcs);
	countVarsFindCalls (DictionariesFunction dictionaries expr expr_type) cvfci cvfcs
		# cvfcs & cvfcs_var_heap = clearCount dictionaries cIsALocalVar cvfcs.cvfcs_var_heap
		  (expr, cvfcs) = countVarsFindCalls expr cvfci cvfcs
		  (dictionaries, var_heap) = mapSt retrieve_ref_count dictionaries cvfcs.cvfcs_var_heap
		  cvfcs & cvfcs_var_heap = var_heap
		= (DictionariesFunction dictionaries expr expr_type, cvfcs)
	where
		retrieve_ref_count (fv,a_type) var_heap
			# (fv,var_heap) = retrieveRefCount fv var_heap
			= ((fv,a_type),var_heap)
	countVarsFindCalls expr cvfci cvfcs
		= (expr, cvfcs)

instance countVarsFindCalls Selection
where
	countVarsFindCalls (ArraySelection array_select expr_ptr index_expr) cvfci cvfcs
		# (index_expr, cvfcs) = countVarsFindCalls index_expr cvfci cvfcs
		= (ArraySelection array_select expr_ptr index_expr, cvfcs)
	countVarsFindCalls (DictionarySelection dictionary_select selectors expr_ptr index_expr) cvfci cvfcs
		# ((index_expr,selectors), cvfcs) = countVarsFindCalls (index_expr,selectors) cvfci cvfcs
		= (DictionarySelection dictionary_select selectors expr_ptr index_expr, cvfcs)
	countVarsFindCalls record_selection cvfci cvfcs
		= (record_selection, cvfcs)

instance countVarsFindCalls [a] | countVarsFindCalls a
where
	countVarsFindCalls [x:xs] cvfci cvfcs
		# (x, cvfcs) = countVarsFindCalls x cvfci cvfcs
		# (xs, cvfcs) = countVarsFindCalls xs cvfci cvfcs
		= ([x:xs], cvfcs)
	countVarsFindCalls [] cvfci cvfcs
		= ([], cvfcs)

instance countVarsFindCalls (!a,!b) | countVarsFindCalls a & countVarsFindCalls b
where
	countVarsFindCalls (x,y) cvfci cvfcs
		# (x, cvfcs) = countVarsFindCalls x cvfci cvfcs
		# (y, cvfcs) = countVarsFindCalls y cvfci cvfcs
		= ((x,y), cvfcs)

instance countVarsFindCalls (Optional a) | countVarsFindCalls a
where
	countVarsFindCalls (Yes x) cvfci cvfcs
		# (x, cvfcs) = countVarsFindCalls x cvfci cvfcs
		= (Yes x, cvfcs)
	countVarsFindCalls no cvfci cvfcs
		= (no, cvfcs)

instance countVarsFindCalls (Bind a b) | countVarsFindCalls a where
	countVarsFindCalls bind=:{bind_src} cvfci cvfcs
		# (bind_src, cvfcs) = countVarsFindCalls bind_src cvfci cvfcs
		= ({bind & bind_src = bind_src}, cvfcs)

instance countVarsFindCalls Case
where
	countVarsFindCalls kees=:{ case_expr, case_guards, case_default } cvfci cvfcs
		# (case_expr, cvfcs) = countVarsFindCalls case_expr cvfci cvfcs
		# (case_guards, cvfcs) = countVarsFindCalls case_guards cvfci cvfcs
		# (case_default, cvfcs) = countVarsFindCalls case_default cvfci cvfcs
		=  ({ kees & case_expr = case_expr, case_guards = case_guards, case_default = case_default }, cvfcs)

instance countVarsFindCalls CasePatterns
where
	countVarsFindCalls (AlgebraicPatterns type patterns) cvfci cvfcs
		# (patterns, cvfcs) = countVarsFindCalls patterns cvfci cvfcs
		= (AlgebraicPatterns type patterns, cvfcs)
	countVarsFindCalls (BasicPatterns type patterns) cvfci cvfcs
		# (patterns, cvfcs) = countVarsFindCalls patterns cvfci cvfcs
		= (BasicPatterns type patterns, cvfcs)
	countVarsFindCalls (OverloadedPatterns type decons_expr patterns) cvfci cvfcs
		# (patterns, cvfcs) = countVarsFindCalls patterns cvfci cvfcs
		= (OverloadedPatterns type decons_expr patterns, cvfcs)
	countVarsFindCalls (NewTypePatterns type patterns) cvfci cvfcs
		# (patterns, cvfcs) = countVarsFindCalls patterns cvfci cvfcs
		= (NewTypePatterns type patterns, cvfcs)
	countVarsFindCalls NoPattern cvfci cvfcs
		= (NoPattern, cvfcs)

instance countVarsFindCalls AlgebraicPattern
where
	countVarsFindCalls pattern=:{ap_vars,ap_expr} cvfci cvfcs
		# cvfcs & cvfcs_var_heap = clearCount ap_vars cIsALocalVar cvfcs.cvfcs_var_heap
		  (ap_expr, cvfcs) = countVarsFindCalls ap_expr cvfci cvfcs
		  (ap_vars, cvfcs_var_heap) = retrieveRefCounts ap_vars cvfcs.cvfcs_var_heap
		= ({ pattern & ap_expr = ap_expr, ap_vars = ap_vars }, {cvfcs & cvfcs_var_heap = cvfcs_var_heap})

instance countVarsFindCalls BasicPattern
where
	countVarsFindCalls pattern=:{bp_expr} cvfci cvfcs
		# (bp_expr, cvfcs) = countVarsFindCalls bp_expr cvfci cvfcs
		= ({ pattern & bp_expr = bp_expr }, cvfcs)

instance countVarsFindCalls BoundVar
where
	countVarsFindCalls var=:{var_ident,var_info_ptr,var_expr_ptr} cvfci cvfcs=:{cvfcs_var_heap}
		# (var_info, cvfcs_var_heap) = readPtr var_info_ptr cvfcs_var_heap
		  cvfcs & cvfcs_var_heap = cvfcs_var_heap
		= case var_info of
			VI_Count count is_global
				| count > 0 || is_global
					-> (var, {cvfcs & cvfcs_var_heap = writePtr var_info_ptr (VI_Count (inc count) is_global) cvfcs.cvfcs_var_heap})
					-> (var, {cvfcs & cvfcs_var_heap = writePtr var_info_ptr (VI_Count 1 is_global) cvfcs.cvfcs_var_heap})
			VI_Alias alias
				#  (original, cvfcs) = countVarsFindCalls alias cvfci cvfcs
				-> ({ original & var_expr_ptr = var_expr_ptr }, cvfcs)
