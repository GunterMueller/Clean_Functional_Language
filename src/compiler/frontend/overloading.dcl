definition module overloading

import StdEnv
import syntax, typesupport
from check_instances import ::SortedInstances

::	InstanceTree
	= IT_Node !(Global Index) !InstanceTree !InstanceTree
	| IT_Empty
	| IT_Trees !SortedInstances !InstanceTree !InstanceTree

::	ClassInstanceInfo :== {# .{! .InstanceTree}}

::	ArrayInstance =
	{	ai_record		:: !TypeSymbIdent
	,	ai_members		:: !{#ClassInstanceMember}
	}

::	GlobalTCInstance =
	{	gtci_type		:: !GlobalTCType
	,	gtci_index		:: !Index
	}

::	SpecialInstances =
	{	si_next_generated_unboxed_record_member_index :: !Index
	,	si_array_instances					:: ![ArrayInstance]
	,	si_list_instances					:: ![ArrayInstance]
	,	si_tail_strict_list_instances		:: ![ArrayInstance]
	,	si_unboxed_maybe_instances			:: ![ArrayInstance]
	}
	
::	OverloadingState =
	{	os_type_heaps			:: !.TypeHeaps
	,	os_var_heap				:: !.VarHeap
	,	os_symbol_heap			:: !.ExpressionHeap
	,	os_generic_heap			:: !.GenericHeap
	,	os_predef_symbols		:: !.PredefinedSymbols
	,	os_special_instances	:: !.SpecialInstances
	,	os_error				:: !.ErrorAdmin				
	}

::	LocalTypePatternVariable
::	DictionaryTypes :== [(Index, [ExprInfoPtr])]

tryToSolveOverloading :: ![(Optional [TypeContext], [ExprInfoPtr], Index)] !Int !{# CommonDefs } !ClassInstanceInfo !*Coercions !*OverloadingState
	-> (![TypeContext], !*Coercions, ![LocalTypePatternVariable], DictionaryTypes, !*OverloadingState)

::	TypeCodeInfo =
	{	tci_type_var_heap					:: !.TypeVarHeap
	,	tci_attr_var_heap					:: !.AttrVarHeap
	,	tci_common_defs						:: !{# CommonDefs }
	}

removeOverloadedFunctions :: ![Index] ![LocalTypePatternVariable] ![ErrorContexts] !Int !*{#FunDef} !*{! FunctionType} !*ExpressionHeap
														   !*TypeCodeInfo !*VarHeap !*ErrorAdmin !*{#PredefinedSymbol}
		-> (!*{#FunDef},!*{!FunctionType},!*ExpressionHeap,!*TypeCodeInfo,!*VarHeap,!*ErrorAdmin,!*{#PredefinedSymbol})
