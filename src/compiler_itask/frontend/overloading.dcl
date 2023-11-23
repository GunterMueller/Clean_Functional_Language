definition module overloading

import StdEnv
import syntax, typesupport
from unitype import ::BOOLVECT
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

::	LocalTypePatternVariable
::	DictionaryTypes :== [(Index, [ExprInfoPtr])]

::	OverloadedExpressions = 
	{	oe_expr_ptrs	:: ![ExprInfoPtr]
	,	oe_fun_index	:: !Index
	}

:: ReducedOverloadedApplication
:: ReducedOverloadedContext

finishContextReduction :: ![ReducedOverloadedContext] ![ExprInfoPtr] !Int !{#CommonDefs} !ClassInstanceInfo
	!*VarHeap !*TypeHeaps !*ExpressionHeap  !*PredefinedSymbols !*SpecialInstances !*Coercions !*{!Type} !*ErrorAdmin
	-> (![ReducedOverloadedApplication], ![TypeContext], ![LocalTypePatternVariable], !*VarHeap, !*TypeHeaps, !*ExpressionHeap, !*PredefinedSymbols,
		!*SpecialInstances , !*Coercions, !*{!Type}, !*ErrorAdmin)

startContextReduction :: ![OverloadedExpressions] ![[TypeContext]] !{# CommonDefs } !ClassInstanceInfo 
	!*VarHeap !*TypeHeaps !*ExpressionHeap  !*PredefinedSymbols !*{!Type} !*ErrorAdmin
	-> (![ReducedOverloadedContext], ![ExprInfoPtr], !*VarHeap, !*TypeHeaps, !*ExpressionHeap, !*PredefinedSymbols, !*{!Type}, !*ErrorAdmin)

addDictionaries :: ![[TypeContext]] ![TypeContext] ![ReducedOverloadedApplication] !{# CommonDefs } 
	!*Heaps !*{!Type} !*ErrorAdmin -> (![TypeContext], !DictionaryTypes, !*Heaps, !*{!Type}, !*ErrorAdmin)

uniqueError :: a b *ErrorAdmin -> *ErrorAdmin | writeType b & <<< a

::	TypeCodeInfo =
	{	tci_type_var_heap					:: !.TypeVarHeap
	,	tci_attr_var_heap					:: !.AttrVarHeap
	,	tci_common_defs						:: !{# CommonDefs }
	}

removeOverloadedFunctions :: ![Index] ![LocalTypePatternVariable] ![ErrorContexts] !Int !*{#FunDef} !*{! FunctionType} !*ExpressionHeap
														   !*TypeCodeInfo !*VarHeap !*ErrorAdmin !*{#PredefinedSymbol}
		-> (!*{#FunDef},!*{!FunctionType},!*ExpressionHeap,!*TypeCodeInfo,!*VarHeap,!*ErrorAdmin,!*{#PredefinedSymbol})

liftNewVarSubstitutions :: ![ReducedOverloadedContext] !Int !*{!Type} -> (!*{#BOOLVECT},!*{!Type})
