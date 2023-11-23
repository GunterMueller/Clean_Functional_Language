implementation module pp

// pretty printing
import syntax, transform, utilities

// -----------------------------------------------------------------------------------------------------------------------		
showComponents3 :: !*{! Group} !Int !Bool !*{# FunDef} !*File  -> (!*{! Group}, !*{# FunDef},!*File)
showComponents3 comps comp_index show_types fun_defs file
	# pp_state
		= InitPPState file
	# (comps,fun_defs,{file})
		= showComponents4 comps comp_index show_types fun_defs pp_state
	= (comps,fun_defs,file)
where
	showComponents4 comps comp_index show_types fun_defs pp_state
		| comp_index >= size comps
			= (comps, fun_defs, pp_state)
			
			# (comp, comps) = comps![comp_index]
			# (fun_defs, pp_state) = show_component comp.group_members show_types fun_defs (pp_state <#< "component " <#< comp_index <#< '\n')
			= showComponents4 comps (inc comp_index) show_types fun_defs pp_state
	where
		show_component [] show_types fun_defs pp_state
			= (fun_defs, pp_state <#< '\n')

		show_component [fun:funs] show_types fun_defs pp_state
			# (fun_def, fun_defs) = fun_defs![fun]
			| show_types
				= show_component funs show_types fun_defs (pp_state <#< fun_def.fun_type <#< '\n' <#< fun_def)
				= show_component funs show_types fun_defs (pp_state <#< fun_def)

:: PPState = {
		file			:: !.File
	,	indent_level	:: !Int
	}
	
InitPPState :: !*File -> *PPState
InitPPState file
	= { PPState |
		file			= file
	,	indent_level	= 3
	}

PPState_writes :: !{#.Char} !*PPState -> .PPState	
PPState_writes s pp_state=:{file,indent_level}
	#! file
		= write_indent indent_level file
	#! file
		= fwrites s file
	= {pp_state & file = file}
where 
	write_indent 0 file
		= file
	write_indent i file
		= write_indent (dec i) (fwritec ' ' file)
	
	
	
// class (<<<) infixl a :: !*File !a -> *File
class (<#<) infixl a :: *PPState !a -> *PPState

instance <#< {#Char}
where
	(<#<) pp_state=:{file} s
		# file
			= fwrites s file
		= { pp_state & file = file }
		
instance <#< Int
where
	(<#<) pp_state=:{file} i
		# file
			= fwrites (toString i) file
		= { pp_state & file = file }

instance <#< Char
where
	(<#<) pp_state=:{file,indent_level} '\n'
		# file
			= fwritec '\n' file
		# file
			= write_indent indent_level file
		= { pp_state & file = file }
	where 
		write_indent 0 file
			= file
		write_indent i file
			= write_indent (dec i) (fwritec ' ' file)

	(<#<) pp_state=:{file} c
		# file
			= fwritec c file
		= { pp_state & file = file }

	
instance <#< Bool
where
	(<#<) pp_state=:{file} bool 
		# file
			= fwrites (toString bool) file
		= { pp_state & file = file }

instance <#< (a,b) | <#< a & <#< b
where
	(<#<) pp_state (x,y) = pp_state <#< '(' <#< x <#< ", " <#< y <#< ") "

instance <#< (a,b,c) | <#< a & <#< b & <#< c
where
	(<#<) pp_state (x,y,z) = pp_state <#< '(' <#< x <#< ", " <#< y <#< ", " <#< z <#< ") "

instance <#< (a,b,c,d) | <#< a & <#< b & <#< c & <#< d
where
	(<#<) pp_state (w,x,y,z) = pp_state <#< '(' <#< w <#< ", " <#< x <#< ", " <#< y <#< ", " <#< z <#< ") "

instance <#< (a,b,c,d,e) | <#< a & <#< b & <#< c & <#< d & <#< e
where
	(<#<) pp_state (v,w,x,y,z) = pp_state <#< '(' <#< v <#< ", " <#< w <#< ", " <#< x <#< ", " <#< y <#< ", " <#< z <#< ") "

instance <#< [a] | <#< a
where
	(<#<) pp_state [] = pp_state <#< "[]"
	(<#<) pp_state l  = showTail (pp_state <#< "[") l
	where
		showTail f [x]   = f <#< x <#< "] "
		showTail f [a:x] = showTail (f <#< a <#< ", ") x
		showTail f []    = f <#< "] "
		
		
// COMPILER


instance <#< BasicType
where
	(<#<) pp_state BT_Int			= pp_state <#< "Int"
	(<#<) pp_state BT_Char			= pp_state <#< "Char"
	(<#<) pp_state BT_Real			= pp_state <#< "Real"
	(<#<) pp_state BT_Bool			= pp_state <#< "Bool"
/*	(<#<) pp_state (BT_String _)	= pp_state <#< "String" */
	(<#<) pp_state BT_Dynamic		= pp_state <#< "Dynamic"
	(<#<) pp_state BT_File			= pp_state <#< "File"
	(<#<) pp_state BT_World			= pp_state <#< "World"

instance <#< TypeVar
where
	(<#<) pp_state varid = pp_state <#< varid.tv_name 

instance <#< AttributeVar
where
	(<#<) pp_state {av_name,av_info_ptr} = pp_state <#< av_name 


/*
instance toString AttributeVar
where
//	toString {av_name,av_info_ptr} = toString av_name + "[" + toString (ptrToInt av_info_ptr) + "]"
	toString {av_name,av_info_ptr} = toString av_name
*/

instance <#< AType
where
	(<#<) pp_state {at_annotation,at_attribute,at_type}
		= pp_state <#< at_annotation <#< at_attribute <#< at_type

instance <#< TypeAttribute
where
	(<#<) pp_state ta
		= pp_state <#< toString ta

/*
instance toString TypeAttribute
where
	toString (TA_Unique)
		= "* "
	toString (TA_TempVar tav_number)
		= "u" + toString tav_number + ": "
	toString (TA_Var avar)
		= toString avar + ": "
	toString (TA_RootVar avar)
		= toString avar + ": "
	toString (TA_Anonymous)
		= ". "
	toString TA_None
		= ""
	toString TA_Multi
		= "o "
	toString (TA_List _ _)
		= "??? "
	toString TA_TempExVar
		= PA_BUG "(E)" (abort "toString TA_TempExVar")
*/


instance <#< Annotation
where
	(<#<) pp_state an = pp_state <#< toString an

/*
instance toString Annotation
where
	toString AN_Strict	= "!" 
	toString _			= "" 
*/

instance <#< ATypeVar
where
	(<#<) pp_state {atv_annotation,atv_attribute,atv_variable}
		= pp_state <#< atv_annotation <#< atv_attribute <#< atv_variable

instance <#< ConsVariable
where
	(<#<) pp_state (CV tv)
		= pp_state <#< tv
	(<#<) pp_state (TempCV tv)
		= pp_state <#<  "v" <#< tv <#< ' ' 

instance <#< Type
where
	(<#<) pp_state (TV varid)
		= pp_state <#< varid
	(<#<) pp_state (TempV tv_number)
		= pp_state  <#< 'v' <#< tv_number <#< ' ' 
	(<#<) pp_state (TA consid types)
		= pp_state  <#< consid <#< " " <#< types
	(<#<) pp_state (arg_type --> res_type)
		= pp_state <#< arg_type <#< " -> " <#< res_type
	(<#<) pp_state (type :@: types)
		= pp_state <#< type <#< " @" <#< types
	(<#<) pp_state (TB tb)
		= pp_state <#< tb
/*	(<#<) pp_state (TFA vars types)
		= pp_state <#< "A." <#< vars <#< ':' <#< types
*/	(<#<) pp_state (TQV varid)
		= pp_state <#< "E." <#< varid
	(<#<) pp_state (TempQV tv_number)
		= pp_state  <#< "E." <#< tv_number <#< ' ' 
	(<#<) pp_state TE
		= pp_state <#< "### EMPTY ###"
/*
instance <#< [a] | <#< , needs_brackets a
where
	(<#<) pp_state [] 		= pp_state
	(<#<) pp_state [x:xs]
		| needs_brackets x
			= pp_state <#< " (" <#< x <#< ')' <#< xs
			= pp_state <#< ' ' <#< x <#< xs
*/

instance <#< SymbolType
where
	(<#<) pp_state st=:{st_vars,st_attr_vars}
		| st.st_arity == 0
			= write_inequalities st.st_attr_env (write_contexts st.st_context (pp_state <#< '[' <#< st_vars <#< ',' <#< st_attr_vars <#< ']' <#< st.st_result))
			= write_inequalities st.st_attr_env (write_contexts st.st_context (pp_state <#< '[' <#< st_vars <#< ',' <#< st_attr_vars <#< ']' <#< st.st_args <#< " -> " <#< st.st_result))

write_contexts [] pp_state
	= pp_state
write_contexts [tc : tcs] pp_state
	= write_contexts2 tcs (pp_state <#< " | " <#< tc) 
where
	write_contexts2 [] pp_state
		= pp_state
	write_contexts2 [tc : tcs] pp_state
		= write_contexts2 tcs (pp_state <#< " & " <#< tc)

instance <#< AttrInequality
where
	(<#<) pp_state {ai_demanded,ai_offered}
		= pp_state <#< ai_offered <#< " <= " <#< ai_demanded
	
write_inequalities [] pp_state
	= pp_state
write_inequalities [ineq:ineqs] pp_state
	= write_remaining_inequalities ineqs (pp_state <#< ',' <#< ineq)
where
	write_remaining_inequalities [] pp_state
		= pp_state
	write_remaining_inequalities [ineq:ineqs] pp_state
		= write_remaining_inequalities ineqs (pp_state <#< ' ' <#< ineq)

instance <#< TypeContext
where
	(<#<) pp_state co = pp_state <#< co.tc_class <#< " " <#< co.tc_types <#< " <" <#< ptrToInt co.tc_var <#< '>'

instance <#< SymbIdent
where
	(<#<) pp_state symb=:{symb_kind = SK_Function symb_index } = pp_state <#< symb.symb_name <#<  '@' <#< symb_index
	(<#<) pp_state symb=:{symb_kind = SK_GeneratedFunction _ symb_index } = pp_state <#< symb.symb_name <#<  '@' <#< symb_index
	(<#<) pp_state symb=:{symb_kind = SK_OverloadedFunction symb_index } = pp_state <#< symb.symb_name <#<  "[o]@" <#< symb_index
	(<#<) pp_state symb = pp_state <#< symb.symb_name 

instance <#< TypeSymbIdent
where
	(<#<) pp_state symb	= pp_state <#< symb.type_name <#< '.' <#< symb.type_index

/*
instance <#< ClassSymbIdent
where
	(<#<) pp_state symb	= pp_state <#< symb.cs_name 
*/

instance <#< BoundVar
where
	(<#<) pp_state {var_name,var_info_ptr,var_expr_ptr}
		= pp_state <#< var_name <#< '<' <#< ptrToInt var_info_ptr <#< '>'

instance <#< (Bind a b) | <#< a & <#< b 
where
	(<#<) pp_state {bind_src,bind_dst} = pp_state <#< bind_dst <#<  " = " <#< bind_src 


instance <#< AlgebraicPattern
where
	(<#<) pp_state g = pp_state <#< g.ap_symbol <#< g.ap_vars <#< " -> " <#< g.ap_expr

instance <#< BasicPattern
where
	(<#<) pp_state g = pp_state <#< g.bp_value <#< " -> " <#< g.bp_expr

instance <#< CasePatterns
where
	(<#<) pp_state (BasicPatterns type patterns) = pp_state <#< " " <#<patterns
	(<#<) pp_state (AlgebraicPatterns type patterns) = pp_state <#< patterns
	(<#<) pp_state (DynamicPatterns patterns) = pp_state <#< patterns
	(<#<) pp_state NoPattern = pp_state 

instance <#< Qualifier
where
	(<#<) pp_state {qual_generators,qual_filter = Yes qual_filter} = pp_state <#< qual_generators <#< "| " <#< qual_filter
	(<#<) pp_state {qual_generators,qual_filter = No} = pp_state <#< qual_generators

instance <#< Generator
where
	(<#<) pp_state {gen_kind,gen_pattern,gen_expr}
		= pp_state <#< gen_pattern <#< (if gen_kind "<-" "<-:") <#< gen_expr

instance <#< BasicValue
where
	(<#<) pp_state (BVI int)	= pp_state <#< int
	(<#<) pp_state (BVC char)	= pp_state <#< char
	(<#<) pp_state (BVB bool)	= pp_state <#< bool
	(<#<) pp_state (BVR real)	= pp_state <#< real
	(<#<) pp_state (BVS string)	= pp_state <#< string
	
instance <#< Sequence
where
	(<#<) pp_state (SQ_From expr) = pp_state <#< expr
	(<#<) pp_state (SQ_FromTo from_expr to_expr) = pp_state <#< from_expr <#< ".."  <#< to_expr
	(<#<) pp_state (SQ_FromThen from_expr then_expr) = pp_state <#< from_expr  <#< ',' <#< then_expr <#< ".."
	(<#<) pp_state (SQ_FromThenTo from_expr then_expr to_expr) = pp_state <#< from_expr  <#< ',' <#< then_expr <#< ".." <#< to_expr

instance <#< Expression
where
	(<#<) pp_state (Var ident) = pp_state <#< ident
	(<#<) pp_state (App {app_symb, app_args, app_info_ptr})
		= pp_state <#< app_symb <#< ' ' <#< app_args
	(<#<) pp_state (f_exp @ a_exp) = pp_state <#< '(' <#< f_exp <#< " @ " <#< a_exp <#< ')'
	(<#<) pp_state (Let {let_info_ptr, let_strict_binds, let_lazy_binds, let_expr}) 
			= write_binds "" (write_binds "!" (pp_state <#< "let" <#< '\n') let_strict_binds) let_lazy_binds <#< "in" <#< '\n' <#< let_expr
	where
		write_binds x pp_state []
			= pp_state
		write_binds x pp_state [bind : binds]
			= write_binds x (pp_state <#< x <#< " " <#< bind <#< '\n') binds
 	(<#<) pp_state (Case {case_expr,case_guards,case_default=No})
		= pp_state <#< "case " <#< case_expr <#< " of" <#< '\n' <#< case_guards
	(<#<) pp_state (Case {case_expr,case_guards,case_default= Yes def_expr})
		= pp_state <#< "case " <#< case_expr <#< " of" <#< '\n' <#< case_guards <#< '\n' <#< "\t-> " <#< def_expr
	(<#<) pp_state (BasicExpr basic_value basic_type) = pp_state <#< basic_value
	(<#<) pp_state (Conditional {if_cond,if_then,if_else}) =
			else_part (pp_state <#< "IF " <#< if_cond <#< '\n' <#< "THEN\n" <#< if_then) if_else
	where
		else_part pp_state No = pp_state <#< '\n'
		else_part pp_state (Yes else) = pp_state <#< "\nELSE\n" <#< else <#< '\n'

/*	(<#<) pp_state (Conditional {if_cond = {con_positive,con_expression},if_then,if_else}) =
			else_part (pp_state <#< (if con_positive "IF " "IFNOT ") <#< con_expression <#< "\nTHEN\n" <#< if_then) if_else
	where
		else_part pp_state No = pp_state <#< '\n'
		else_part pp_state (Yes else) = pp_state <#< "\nELSE\n" <#< else <#< '\n'
*/
 	(<#<) pp_state (Selection opt_tuple expr selectors) = pp_state <#< expr <#< selector_kind opt_tuple <#< selectors
	where
		selector_kind No		= '.'
		selector_kind (Yes _)	= '!'
	(<#<) pp_state (Update expr1 selections expr2) =  pp_state <#< '{' <#< expr1  <#< " & " <#<  selections <#< " = " <#< expr2 <#< '}'
	(<#<) pp_state (RecordUpdate cons_symbol expression expressions) = pp_state <#< '{' <#< cons_symbol <#< ' ' <#< expression <#< " & " <#< expressions <#< '}'
	(<#<) pp_state (TupleSelect field field_nr expr) = pp_state <#< expr <#<'.' <#< field_nr
	(<#<) pp_state (Lambda vars expr) = pp_state <#< '\\' <#< vars <#< " -> " <#< expr
	(<#<) pp_state WildCard = pp_state <#< '_'
	(<#<) pp_state (MatchExpr _ cons expr) = pp_state <#< cons <#< " =: " <#< expr
	(<#<) pp_state EE = pp_state <#< "** E **"
	(<#<) pp_state (NoBind _) = pp_state <#< "** NB **"
	(<#<) pp_state (DynamicExpr {dyn_expr,dyn_uni_vars,dyn_type_code})     = writeVarPtrs (pp_state <#< "dynamic " <#< dyn_expr <#< " :: dyn_uni_vars") dyn_uni_vars <#< "dyn_type_code=" <#< dyn_type_code 
//	(<#<) pp_state (TypeCase type_case)      = pp_state <#< type_case
	(<#<) pp_state (TypeCodeExpression type_code)      = pp_state <#< type_code
	(<#<) pp_state (Constant symb _ _ _)         = pp_state <#<  "** Constant **" <#< symb

	(<#<) pp_state (ABCCodeExpr code_sequence do_inline)      = pp_state <#< (if do_inline "code inline\n" "code\n") <#< code_sequence
	(<#<) pp_state (AnyCodeExpr input output code_sequence)   = pp_state <#< "code\n" <#< input <#< "\n" <#< output <#< "\n" <#< code_sequence

	(<#<) pp_state (FreeVar {fv_name})         	= pp_state <#< fv_name
	(<#<) pp_state (ClassVariable info_ptr)         	= pp_state <#< "ClassVariable " <#< ptrToInt info_ptr

	(<#<) pp_state expr         				= abort ("<#< (Expression) [line 1290]" )//<<- expr)
	
instance <#< TypeCase
where
	(<#<) pp_state {type_case_dynamic,type_case_patterns,type_case_default}
			= pp_state <#< "typecase " <#< type_case_dynamic <#< "of\n" <#<
				type_case_patterns <#< type_case_default

instance <#< DynamicPattern
where
	(<#<) pp_state {dp_type_patterns_vars,dp_var,dp_rhs,dp_type_code}
			= writeVarPtrs (pp_state <#< dp_var <#< " :: ")  dp_type_patterns_vars <#<  dp_type_code <#< " = " <#< dp_rhs

writeVarPtrs pp_state []
	= pp_state
writeVarPtrs pp_state vars
	= write_var_ptrs (pp_state <#< '<') vars <#< '>'
	where
		write_var_ptrs pp_state [var]
			= pp_state <#< ptrToInt var
		write_var_ptrs pp_state [var : vars]
			= write_var_ptrs (pp_state <#< ptrToInt var <#< '.') vars
		
		
instance <#< TypeCodeExpression
where
	(<#<) pp_state TCE_Empty
		= pp_state
	(<#<) pp_state (TCE_Var info_ptr)
		= pp_state <#< "TCE_Var " <#< ptrToInt info_ptr
// MV ..
	(<#<) pp_state (TCE_TypeTerm info_ptr)
		= pp_state <#< "TCE_TypeTerm " <#< ptrToInt info_ptr
// .. MV	
	(<#<) pp_state (TCE_Constructor index exprs)
		= pp_state <#< "TCE_Constructor " <#< index <#< ' ' <#< exprs
	(<#<) pp_state (TCE_Selector selectors info_ptr)
		= pp_state <#< "TCE_Selector " <#< selectors <#< "VAR " <#< ptrToInt info_ptr

instance <#< Selection
where
	(<#<) pp_state (RecordSelection selector _) = pp_state <#< selector
	(<#<) pp_state (ArraySelection _ _ index_expr) = pp_state <#< '[' <#< index_expr <#< ']'
	(<#<) pp_state (DictionarySelection var selections _ index_expr) = pp_state <#< '(' <#< var <#< '.' <#< selections <#< ')' <#< '[' <#< index_expr <#< ']'

instance <#< LocalDefs
where
	(<#<) pp_state (LocalParsedDefs defs) = pp_state <#< defs
	(<#<) pp_state (CollectedLocalDefs defs) = pp_state <#< defs

instance <#< (NodeDef dst) | <#< dst 
where
	(<#<) pp_state {nd_dst,nd_alts,nd_locals} = pp_state <#< nd_dst <#< nd_alts <#< nd_locals


instance <#< CollectedLocalDefs
where
	(<#<) pp_state {loc_functions,loc_nodes}
		= pp_state <#< loc_functions <#< loc_nodes
/*
	(<#<) pp_state {def_types,def_constructors,def_selectors,def_macros,def_classes,def_members,def_instances}
		= pp_state <#< def_types <#< def_constructors <#< def_selectors <#< def_macros <#< def_classes <#< def_members <#< def_instances
*/

instance <#< ParsedExpr
where
	(<#<) pp_state (PE_List exprs) = pp_state <#< exprs
	(<#<) pp_state (PE_Tuple args) = pp_state <#< '(' <#< args <#< ')'
	(<#<) pp_state (PE_Basic basic_value) = pp_state <#< basic_value
	(<#<) pp_state (PE_Selection is_unique expr selectors) =  pp_state <#< expr <#< (if is_unique '!' '.') <#< selectors
	(<#<) pp_state (PE_Update expr1 selections expr2) =  pp_state <#< '{' <#< expr1  <#< " & " <#<  selections <#< " = " <#< expr2 <#< '}'
	(<#<) pp_state (PE_Record PE_Empty _ fields) = pp_state <#< '{' <#< fields <#< '}'
	(<#<) pp_state (PE_Record rec _ fields) = pp_state <#< '{' <#< rec <#< " & " <#< fields <#< '}'
	(<#<) pp_state (PE_Compr True expr quals) = pp_state <#< '[' <#< expr <#< " \\ " <#< quals <#< ']'
	(<#<) pp_state (PE_Compr False expr quals) = pp_state <#< '{' <#< expr <#< " \\ " <#< quals <#< '}'
	(<#<) pp_state (PE_Sequ seq) = pp_state <#< '[' <#< seq <#< ']'
	(<#<) pp_state PE_Empty = pp_state <#< "** E **"
	(<#<) pp_state (PE_Ident symb) = pp_state <#< symb
	(<#<) pp_state PE_WildCard = pp_state <#< '_'
	(<#<) pp_state (PE_Lambda _ exprs expr _) = pp_state <#< '\\' <#< exprs <#< " -> " <#< expr
	(<#<) pp_state (PE_Bound bind) = pp_state <#< bind
	(<#<) pp_state (PE_Case _ expr alts) = pp_state <#< "case " <#< expr <#< " of\n" <#< alts
	(<#<) pp_state (PE_Let _ defs expr) = pp_state <#< "let " <#< defs <#< " in\n" <#< expr
	(<#<) pp_state (PE_DynamicPattern expr type) = pp_state <#< expr <#< "::" <#< type
	(<#<) pp_state (PE_Dynamic expr maybetype)
		= case maybetype of
			Yes type
				-> pp_state <#< "dynamic " <#< expr <#< "::" <#< type
			No
				-> pp_state <#< "dynamic " <#< expr
	(<#<) pp_state _ = pp_state <#< "some expression"


instance <#< ParsedSelection
where
	(<#<) pp_state (PS_Record selector _)	= pp_state <#< selector
	(<#<) pp_state (PS_Array index_expr)	= pp_state <#< '[' <#< index_expr <#< ']'
	(<#<) pp_state PS_Erroneous				= pp_state <#< "Erroneous selector" // PK

instance <#< CaseAlt
where
	(<#<) pp_state {calt_pattern,calt_rhs} = pp_state <#< calt_pattern <#< " -> " <#< calt_rhs

instance <#< ParsedBody
where
	(<#<) pp_state {pb_args,pb_rhs} = pp_state <#< pb_args <#< " = " <#< pb_rhs
	
instance <#< BackendBody
where
	(<#<) pp_state {bb_args,bb_rhs} = pp_state <#< bb_args <#< " = " <#< bb_rhs

instance <#< FunctionPattern
where
	(<#<) pp_state (FP_Basic val (Yes var))
		= pp_state <#< var <#< "=:" <#< val
	(<#<) pp_state (FP_Basic val No)
		= pp_state <#< val
	(<#<) pp_state (FP_Algebraic constructor vars (Yes var))
		= pp_state <#< var <#< "=:" <#< constructor <#< vars
	(<#<) pp_state (FP_Algebraic constructor vars No)
		= pp_state <#< constructor <#< vars
	(<#<) pp_state (FP_Variable var) = pp_state <#< var 
	(<#<) pp_state (FP_Dynamic vars var type_code _)
		= writeVarPtrs (pp_state <#< var <#< " :: ") vars <#<  type_code
	(<#<) pp_state (FP_Empty) = pp_state <#< '_' 


instance <#< FunKind
where
	(<#<) pp_state (FK_Function False) = pp_state <#< "FK_Function"
	(<#<) pp_state (FK_Function True) = pp_state <#< "Lambda"
	(<#<) pp_state FK_Macro = pp_state <#< "FK_Macro"
	(<#<) pp_state FK_Caf = pp_state <#< "FK_Caf"
	(<#<) pp_state FK_Unknown = pp_state <#< "FK_Unknown"

instance <#< FunDef
where
	(<#<) pp_state {fun_symb,fun_index,fun_body=ParsedBody bodies} = pp_state <#< fun_symb <#< '.' <#< fun_index <#< ' ' <#< bodies 
	(<#<) pp_state {fun_symb,fun_index,fun_body=CheckedBody {cb_args,cb_rhs},fun_info={fi_free_vars,fi_def_level,fi_calls}} = pp_state <#< fun_symb <#< '.'
			<#< fun_index <#< "\nC " <#< cb_args <#< " = " <#< cb_rhs 
//			<#< fun_index <#< '.' <#< fi_def_level <#< ' ' <#< '[' <#< fi_free_vars <#< ']' <#< cb_args <#< " = " <#< cb_rhs 
	(<#<) pp_state {fun_symb,fun_index,fun_body=TransformedBody {tb_args,tb_rhs},fun_info={fi_free_vars,fi_def_level,fi_calls}} = pp_state <#< fun_symb <#< '.'
			<#< fun_index <#< "\nT "  <#< tb_args <#< '[' <#< fi_calls <#< ']' <#< " = " <#< tb_rhs 
//			<#< fun_index <#< '.' <#< fi_def_level <#< ' ' <#< '[' <#< fi_free_vars <#< ']' <#< tb_args <#< " = " <#< tb_rhs 
	(<#<) pp_state {fun_symb,fun_index,fun_body=BackendBody body,fun_type=Yes type} = pp_state <#< type <#< '\n' <#< fun_symb <#< '.'
			<#< fun_index <#< body <#< '\n'
	(<#<) pp_state {fun_symb,fun_index,fun_body=NoBody,fun_type=Yes type} = pp_state <#< type <#< '\n' <#< fun_symb <#< '.'
			<#< fun_index <#< "Array function\n"

instance <#< FunCall
where
	(<#<) pp_state { fc_level,fc_index }
			= pp_state <#< fc_index <#< '.' <#< fc_level

instance <#< FreeVar
where
	(<#<) pp_state {fv_name,fv_info_ptr,fv_count} = pp_state <#< fv_name <#< '.' <#< fv_count <#< '<' <#< ptrToInt fv_info_ptr <#< '>'

instance <#< DynamicType
where
	(<#<) pp_state {dt_uni_vars,dt_type}
		| isEmpty dt_uni_vars
			= pp_state <#< "DynamicType" <#< dt_type
			= pp_state <#< "DynamicType" <#< "A." <#< dt_uni_vars <#< ":" <#< dt_type
			

instance <#< SignClassification
where
	(<#<) pp_state {sc_pos_vect,sc_neg_vect} = write_signs pp_state sc_pos_vect sc_neg_vect 0
	where
		write_signs pp_state sc_pos_vect sc_neg_vect index
			| sc_pos_vect == 0 && sc_neg_vect == 0
				= pp_state
			#	index_bit = (1 << index)
			| sc_pos_vect bitand index_bit == 0
				| sc_neg_vect bitand index_bit == 0
					= write_signs (pp_state <#< 'O') sc_pos_vect sc_neg_vect (inc index)
					= write_signs (pp_state <#< '-') sc_pos_vect (sc_neg_vect bitand (bitnot index_bit)) (inc index)
				| sc_neg_vect bitand index_bit == 0
					= write_signs (pp_state <#< '+') (sc_pos_vect bitand (bitnot index_bit)) sc_neg_vect (inc index)
					= write_signs (pp_state <#< 'T') (sc_pos_vect bitand (bitnot index_bit)) (sc_neg_vect bitand (bitnot index_bit)) (inc index)
				
instance <#< TypeKind
where
	(<#<) pp_state (KindVar _) = pp_state <#< "**"
	(<#<) pp_state KindConst
		= pp_state <#< '*'
	(<#<) pp_state (KindArrow arity)
		= write_kinds pp_state arity
	where
		write_kinds pp_state 1
			= pp_state <#< "* -> *"
		write_kinds pp_state n
			= write_kinds (pp_state <#< "* -> ") (dec n)
		

instance <#< TypeDefInfo
where
	(<#<) pp_state {tdi_group,tdi_group_vars,tdi_cons_vars}
		= pp_state <#< '[' <#< tdi_group <#< '=' <#< tdi_group_vars <#< '=' <#< tdi_cons_vars <#< ']'

instance <#< DefinedSymbol
where
	(<#<) pp_state {ds_ident}
		= pp_state <#< ds_ident 

instance <#< (TypeDef a) | <#< a
where
	(<#<) pp_state {td_name, td_args, td_rhs}
		= pp_state <#< ":: " <#< td_name <#< ' ' <#< td_args <#< td_rhs

instance <#< TypeRhs
where
	(<#<) pp_state (SynType type)
		= pp_state <#< " :== " <#< type 
	(<#<) pp_state (AlgType data)
		= pp_state <#< " = " <#< data 
	(<#<) pp_state (RecordType record)
		= pp_state <#< " = " <#< '{' <#< record <#< '}'
	(<#<) pp_state _
		= pp_state 


instance <#< RecordType
where
	(<#<) pp_state {rt_fields} = iFoldSt (\index pp_state -> pp_state <#< rt_fields.[index]) 0 (size rt_fields) pp_state

instance <#< FieldSymbol
where
	(<#<) pp_state {fs_name} = pp_state <#< fs_name

/*
	where
		write_data_defs pp_state []
			= pp_state
		write_data_defs pp_state [d:ds]
			= write_data_defs (pp_state <#< d <#< '\n') ds
*/

instance <#< InstanceType
where
	(<#<) pp_state it = write_contexts it.it_context (pp_state <#< it.it_types) 

instance <#< RhsDefsOfType
where
	(<#<) pp_state (ConsList cons_defs) = pp_state <#< cons_defs
	(<#<) pp_state (SelectorList _ _ sel_defs) = pp_state <#< sel_defs
	(<#<) pp_state (TypeSpec type) = pp_state <#< type
	(<#<) pp_state _ = pp_state

instance <#< ParsedConstructor
where
	(<#<) pp_state {pc_cons_name,pc_arg_types} = pp_state <#< pc_cons_name <#< pc_arg_types

instance <#< ParsedSelector
where
	(<#<) pp_state {ps_field_name,ps_field_type} = pp_state <#< ps_field_name <#< ps_field_type


instance <#< ModuleKind
where
	(<#<) pp_state kind 		= pp_state

instance <#< ConsDef
where
	(<#<) pp_state {cons_symb,cons_type} = pp_state <#< cons_symb <#< " :: " <#< cons_type

instance <#< SelectorDef
where
	(<#<) pp_state {sd_symb} = pp_state <#< sd_symb

instance <#< ClassDef
where
	(<#<) pp_state {class_name} = pp_state <#< class_name

instance <#< ClassInstance
where
	(<#<) pp_state {ins_class,ins_type} = pp_state <#< ins_class <#< " :: " <#< ins_type

instance <#< (Optional a) | <#< a
where
	(<#<) pp_state (Yes x) = pp_state <#< x
	(<#<) pp_state No = pp_state
	
instance <#< (Module a) | <#< a
where
	(<#<) pp_state {mod_name,mod_type,mod_defs} = pp_state <#< mod_type <#< mod_name <#< mod_defs

instance <#< (CollectedDefinitions a b) | <#< a & <#< b
where
	(<#<) pp_state {def_types,def_constructors,def_selectors,def_macros,def_classes,def_members,def_instances}
		= pp_state

instance <#< ParsedDefinition
where
	(<#<) pp_state (PD_Function _ name _ exprs rhs _ ) = pp_state <#< name <#< exprs <#< " = " <#< rhs
	(<#<) pp_state (PD_NodeDef  _ pattern rhs) = pp_state <#< pattern <#< " =: " <#< rhs
	(<#<) pp_state (PD_TypeSpec _ name prio st sp) = pp_state <#< name <#< st
	(<#<) pp_state (PD_Type td) = pp_state <#< td
	(<#<) pp_state _ = pp_state

instance <#< Rhs
where
	(<#<) pp_state {rhs_alts,rhs_locals} = pp_state <#< rhs_alts <#< rhs_locals

instance <#< OptGuardedAlts
where
	(<#<) pp_state (GuardedAlts guarded_exprs def_expr) = pp_state <#< guarded_exprs <#< def_expr
	(<#<) pp_state (UnGuardedExpr unguarded_expr) = pp_state <#< unguarded_expr

instance <#< ExprWithLocalDefs
where
	(<#<) pp_state {ewl_expr,ewl_locals} = pp_state <#< ewl_expr <#< ewl_locals

instance <#< GuardedExpr
where
	(<#<) pp_state {alt_nodes,alt_guard,alt_expr} = pp_state <#< '|' <#< alt_guard <#< alt_expr


instance <#< IndexRange
where
	(<#<) pp_state {ir_from,ir_to}
		| ir_from == ir_to
			= pp_state
			= pp_state <#< ir_from <#< "---" <#< ir_to

instance <#< Ident
where
//	(<#<) pp_state {id_name,id_index} = pp_state <#< id_name <#< '.' <#< id_index
	(<#<) pp_state {id_name} = pp_state <#< id_name

instance <#< (Global a) | <#< a
where
	(<#<) pp_state {glob_object,glob_module} = pp_state <#< glob_object <#< "M:" <#< glob_module

instance <#< Position
where
	(<#<) pp_state (FunPos pp_state_name line func) = pp_state <#< '[' <#< pp_state_name <#< ',' <#< line <#< ',' <#< func <#< ']'
	(<#<) pp_state (LinePos pp_state_name line) = pp_state <#< '[' <#< pp_state_name <#< ',' <#< line <#< ']'
	(<#<) pp_state _ = pp_state

instance <#< TypeVarInfo
where
	(<#<) pp_state TVI_Empty				= pp_state <#< "TVI_Empty"
	(<#<) pp_state (TVI_Type _)				= pp_state <#< "TVI_Type"
	(<#<) pp_state (TVI_Forward	_) 			= pp_state <#< "TVI_Forward"
	(<#<) pp_state (TVI_TypeKind _)			= pp_state <#< "TVI_TypeKind"
	(<#<) pp_state (TVI_SignClass _ _ _) 	= pp_state <#< "TVI_SignClass"
	(<#<) pp_state (TVI_PropClass _ _ _) 	= pp_state <#< "TVI_PropClass"

instance <#< (Import from_symbol) | <#< from_symbol
where
	(<#<) pp_state {import_module, import_symbols}
		= pp_state <#< "import " <#< import_module <#< import_symbols

instance <#< ImportDeclaration
where
	(<#<) pp_state (ID_Function ident)			= pp_state <#< ident
	(<#<) pp_state (ID_Class ident optIdents)	= pp_state <#< "class " <#< ident <#< optIdents
	(<#<) pp_state (ID_Type ident optIdents)	= pp_state <#< ":: " <#< ident <#< optIdents
	(<#<) pp_state (ID_Record ident optIdents)	= pp_state <#< ident <#< " { " <#< optIdents <#< " } "
	(<#<) pp_state (ID_Instance i1 i2 tup)		= pp_state <#< "instance " <#< i1 <#< i2 <#< tup // !ImportedIdent !Ident !(![Type],![TypeContext])

instance <#< ImportedIdent
where
	(<#<) pp_state {ii_ident, ii_extended}	= pp_state <#< ii_ident <#< ' ' <#< ii_extended

		
