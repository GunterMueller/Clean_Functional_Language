
#include <ctype.h>

#include "compiledefines.h"

#ifndef CLEAN_FILE_IO

#include "types.t"
#include "system.h"
#include "syntaxtr.t"
#include "comsupport.h"
#include "settings.h"
#include "sizes.h"
#include "dbprint.h"
#include "codegen_types.h"

#define for_l(v,l,n) for(v=(l);v!=NULL;v=v->n)

#define PrintAnnotation(annot)

#undef PRINT_alt_lifted_node_ids
#undef PRINT_NODE_ID_REF_COUNTS
#define PRINT_ALL_NODE_ID_ADDRESSES
#define PRINT_NODE_ID_REF_COUNT		

static void PrintUnaryState (StateKind kind, ObjectKind obj, File file)
{	
	switch (kind)
	{	case OnB: FPutS ("OnB ", file); break;
		case OnA: FPutS ("OnA ", file); break;
		case StrictOnA: FPutS ("StrictOnA ", file); break;
		case SemiStrict: FPutS ("SemiStrict ", file); break;
		case StrictRedirection: FPutS ("StrictRedirection ", file); break;
		case Parallel: FPutS ("Parallel ", file); break;
		case Undefined: FPutS ("Undefined ", file); break;
		case UnderEval: FPutS ("UnderEval ", file); break;
	}
	switch (obj)
	{	case UnknownObj: FPutS ("??? ", file); break;
		case IntObj: FPutS ("Int ", file); break;
		case BoolObj: FPutS ("Bool ", file); break;
		case CharObj: FPutS ("Char ", file); break;
		case RealObj: FPutS ("Real ", file); break;
		case FileObj: FPutS ("File ", file); break;
		case TupleObj: FPutS ("Tuple ", file); break;
		case ListObj: FPutS ("List ", file); break;
		case ProcIdObj: FPutS ("ProcId ", file); break;
		case RecordObj: FPutS ("Record ", file); break;
	}
}

void PrintState (StateS state, File file)
{
	switch (state.state_type){
		case TupleState:
		{
			int i,arity;
			
			arity=state.state_arity;
			fprintf (file,"t%d",arity);
			
			for (i=0; i<arity; ++i){
				fprintf (file," ");
				PrintState (state.state_tuple_arguments[i],file);
			}
			
			break;
		}
		case RecordState:
			FPutC ('r',file);
			break;
		case ArrayState:
			FPutC ('a',file);
			break;
		case SimpleState:
			PrintUnaryState (state.state_kind,state.state_object, file);
			break;
	}
}

void DPrintNodeId (NodeId nid, File file)
{
	if (nid){
		if (nid->nid_name){
			fprintf (file, "%s",nid->nid_name);
#ifdef PRINT_ALL_NODE_ID_ADDRESSES
			fprintf (file, "@i_%lx", (long) nid);
#endif
		} else
			fprintf (file, "i_%lx", (long) nid);

#ifdef PRINT_NODE_ID_REF_COUNT		
		fprintf (file, "<%d>", nid->nid_refcount);
#endif
	} else
		fprintf (file," 00000000");
}

void DPrintNodeIdS (char *s,NodeId node_id,File file)
{
	fprintf (file,"%s",s);
	DPrintNodeId (node_id,file);
	fprintf (file,"\n");
}

static void DPrintTypeVar (TypeVar tv, Node follow, File file)
{
	if (tv){
		fprintf (file, "i_%lx", (long) tv);
		if (follow)
			FPutS (" = ", file);
	}
}

static void PrintArgument (Args arg,Bool brackets,int n_leading_spaces,File file)
{
	/*	
	PrintState (arg->arg_state, file);
	
	if ((arg->arg_state.state_mark & STATE_UNIQUE_MASK)!=0)
		fprintf (file,"*");
	*/
	
	if (arg->arg_node->node_kind==NodeIdNode)
		DPrintNodeId (arg->arg_node->node_node_id,file);
	else
		PrintRuleNode (arg->arg_node,brackets,n_leading_spaces,file);
}

static void print_spaces (int n_leading_spaces,File file)
{
	int n;
	
	for (n=0; n<n_leading_spaces; ++n)
		FPutC (' ',file);
}

static void PrintArguments (Args args, char separator, Bool brackets,int n_leading_spaces,File file)
{
	if (args!=NULL){
		PrintArgument (args,brackets,n_leading_spaces,file);
		for (args = args -> arg_next; args; args = args -> arg_next){
			FPutC (separator, file);
			if (separator=='\n')
				print_spaces (n_leading_spaces,file);
			PrintArgument (args, brackets,n_leading_spaces,file);
		}
	}
}

static void print_compiler_generated_function_name (char *name, char *name_end, unsigned line_nr, File file)
{
	char *parsed_digits;

	FPutS (name,file);
	
	parsed_digits=NULL;
	if (name_end[0]==';' && isdigit (name_end[1])){
		char *s;
		
		s=name_end+2;
		while (isdigit (*s))
			++s;
		if (*s==';')
			parsed_digits=s;
	}
	
	if (line_nr>0){
		fprintf (file,"[line: %u]", line_nr);
		if (parsed_digits)
			name_end=parsed_digits;
	} else
		if (parsed_digits){
			char *d_p;

			FPutS ("[line:",file);
			for (d_p=name_end+1; d_p<parsed_digits; ++d_p)
				FPutC (*d_p,file);
			FPutC (']',file);

			name_end=parsed_digits;
		}
	FPutS (name_end,file);
}

static void PrintSymbolOfIdent (char *name, unsigned line_nr, File file)
{
	char *name_end;

	for (name_end=name; *name_end!=';' && *name_end!='\0'; ++name_end)
		;

	if (*name=='\\' && name+1==name_end){
		print_compiler_generated_function_name ("<lambda>",name_end,line_nr,file);
		return;
	}

	if (*name == '_'){
		if (name+2==name_end && name[1]=='c'){
			print_compiler_generated_function_name ("<case>",name_end,line_nr,file);
			return;
		} else if (name+3==name_end && name[1]=='i' && name[2]=='f'){
			print_compiler_generated_function_name ("<if>",name_end,line_nr,file);
			return;
		}
	} else
		if (line_nr > 0 && *name_end == ';' && isdigit (name_end[1])){
			char *end_name;

			for (; name!=name_end; name++)
				FPutC (*name, file);

			for (end_name = name_end + 2; *end_name!=';' && *end_name!='\0'; end_name++)
				 ;
			
			fprintf (file, " [line: %u]", line_nr);
			
			if (*end_name == '\0')
				return;

			name = end_name;
		}

	FPutS (name, file);
}

static void PrintSymbol (Symbol symbol, File file)
{
	if (symbol->symb_kind==definition)
		PrintSymbolOfIdent (symbol->symb_def->sdef_name, 0, file);
	else
		FPutS (symbol_to_string (symbol), file);
}

static void PrintTypeSymbol (TypeSymbol type_symbol, File file)
{
	if (type_symbol->ts_kind==definition)
		PrintSymbolOfIdent (type_symbol->ts_def->sdef_name, 0, file);
	else
		FPutS (type_symbol_to_string (type_symbol), file);
}

void PrintRuleNode (Node node,Bool brackets,int n_leading_spaces,File file)
{
/*
	if (IsOnACycle (node -> node_number))
		FPutS ("<C>", file);
	PrintState (node -> node_state,file);
*/
	switch (node -> node_kind){
	case NormalNode:
	{
		Symbol node_symb = node->node_symbol;
	
		if (node_symb -> symb_kind == tuple_symb){
			FPutC ('(', file);
			PrintArguments (node -> node_arguments, ',', False,n_leading_spaces,file);
			FPutC (')', file);
		}
/*
		else if (node_symb -> symb_kind == list_type)
		{	FPutC ('[', file);
			PrintArguments (node -> node_arguments, ',', False,n_leading_spaces,file);
			FPutC (']', file);
		}
*/
		else if (node_symb -> symb_kind == nil_symb)
			FPutS ("[]", file);
		else if (node_symb -> symb_kind == cons_symb)
		{	FPutC ('[', file);
			PrintArgument (node -> node_arguments, brackets,n_leading_spaces,file);
			FPutC (':', file);
			PrintArgument (node -> node_arguments -> arg_next, brackets,n_leading_spaces,file);
			FPutC (']', file);
		} else if (node_symb -> symb_kind==select_symb){
			FPutS ("_sel",file);
			FPutC ('0'+node->node_arity,file);
			FPutC (' ',file);
			PrintArgument (node -> node_arguments,True,n_leading_spaces,file);
		} else {
			if (brackets && node -> node_arguments)
				FPutC ('(', file);
			
			PrintSymbol (node_symb, file);

			if (node -> node_arguments)
			{	FPutC (' ', file);
				PrintArguments (node -> node_arguments,' ', True,n_leading_spaces,file);
				if (brackets)
					FPutC (')', file);
			}
		}
		break;
	}
	case SelectorNode:
		PrintArgument (node -> node_arguments, True,n_leading_spaces,file);
		if (node->node_arity>1){
			FPutC ('!',file);
			FPutC ('0'+node->node_arity,file);
		} else
			FPutC ('.',file);
		PrintSymbol (node->node_symbol, file);
		break;
	case IfNode:
	{
		Args elsepart, thenpart, condpart;
		
		condpart = node -> node_arguments;
		thenpart = condpart -> arg_next;
		elsepart = thenpart -> arg_next;
	
		if (brackets)
			FPutC ('(', file);
	
		FPutS ("IF ", file);
		PrintArgument (condpart, True,n_leading_spaces,file);

		FPutC ('\n',file);
		print_spaces (n_leading_spaces+4,file);
#if 0
# ifdef PRINT_NODE_ID_REF_COUNTS
		FPutS ("[ ", file);
		{
			NodeIdRefCountListP node_id_ref_count_elem;
			
			for_l (node_id_ref_count_elem,node->node_then_node_id_ref_counts,nrcl_next){
				DPrintNodeId (node_id_ref_count_elem->nrcl_node_id,file);
				fprintf (file," %d ",node_id_ref_count_elem->nrcl_ref_count);
			}		
		}
		FPutS ("]\n", file);
		print_spaces (n_leading_spaces+4,file);
# else
		if (node->node_then_strict_node_ids!=NULL){
			StrictNodeIdP strict_node_id;
			
			FPutS ("let! ", file);
			
			for_l (strict_node_id,node->node_then_strict_node_ids,snid_next){
				DPrintNodeId (strict_node_id->snid_node_id,file);
				FPutS ("; ",file);
			}
			FPutC ('\n',file);
			print_spaces (n_leading_spaces+4,file);
		}
# endif
#endif
		PrintArgument (thenpart, True,n_leading_spaces+4,file);

		if (node->node_then_node_defs!=NULL){
			FPutC ('\n',file);
			print_spaces (n_leading_spaces+4,file);
			FPutS ("{\n",file);
			PrintNodeDefs (node->node_then_node_defs,n_leading_spaces+8,file);
			print_spaces (n_leading_spaces+4,file);
			FPutC ('}', file);
		}
		
		FPutC ('\n',file);
		print_spaces (n_leading_spaces+4,file);

#if 0
# ifdef PRINT_NODE_ID_REF_COUNTS
		FPutS ("[ ", file);
		{
			NodeIdRefCountListP node_id_ref_count_elem;
			
			for_l (node_id_ref_count_elem,node->node_else_node_id_ref_counts,nrcl_next){
				DPrintNodeId (node_id_ref_count_elem->nrcl_node_id,file);
				fprintf (file," %d ",node_id_ref_count_elem->nrcl_ref_count);
			}		
		}
		FPutS ("]\n",file);
		print_spaces (n_leading_spaces+4,file);
# else
		if (node->node_else_strict_node_ids!=NULL){
			StrictNodeIdP strict_node_id;
			
			FPutS ("let! ", file);
			
			for (strict_node_id=node->node_else_strict_node_ids; strict_node_id!=NULL; strict_node_id=strict_node_id->snid_next){
				DPrintNodeId (strict_node_id->snid_node_id,file);
				FPutS ("; ",file);
			}
			FPutC ('\n',file);
			print_spaces (n_leading_spaces+4,file);
		}
# endif
#endif

		PrintArgument (elsepart, True,n_leading_spaces+4,file);
		
		if (node->node_else_node_defs!=NULL){
			FPutC ('\n', file);
			print_spaces (n_leading_spaces+4,file);
			FPutS ("{\n",file);
			PrintNodeDefs (node->node_else_node_defs,n_leading_spaces+8,file);
			print_spaces (n_leading_spaces+4,file);
			FPutS ("}\n", file);
			print_spaces (n_leading_spaces,file);
		}
		
		if (brackets)
			FPutC (')', file);
		break;
	}
	case NodeIdNode:
	{
		NodeId node_id;
		
		node_id=node->node_node_id;
		
		if (node_id->nid_name){
			fprintf (file, " %s<%d>",node_id->nid_name,node_id->nid_refcount);
#ifdef PRINT_ALL_NODE_ID_ADDRESSES
			fprintf (file, " i_%lx",(long) node_id);
#endif
		} else
			fprintf (file, " i_%lx<%d>",(long) node_id,node_id->nid_refcount);
		break;
	}
	case UpdateNode:
	{	Args field = node -> node_arguments;

		FPutC ('{', file);

		PrintArgument (field, False,n_leading_spaces,file);
		FPutS (" & ", file);
		field = field -> arg_next;
		PrintArgument (field, False,n_leading_spaces,file);
		for (field = field -> arg_next; field; field = field -> arg_next)
		{	FPutC (',', file);
			PrintArgument (field, False,n_leading_spaces,file);
		}

		FPutC ('}', file);
		break;
	}
	case MatchNode:
	{
		FPutS ("Match ",file);
		PrintSymbol (node->node_symbol,file);
		FPutC (' ',file);
		PrintArgument (node->node_arguments,False,n_leading_spaces,file);
		break;
	}
	case SwitchNode:
		FPutS ("Switch ",file);
		DPrintNodeId (node->node_node_id,file);
		FPutC ('\n',file);
		print_spaces (n_leading_spaces,file);
		PrintArguments (node->node_arguments,'\n',True,n_leading_spaces,file);
		break;		
	case CaseNode:
		FPutS ("Case: ",file);

		PrintSymbol (node->node_symbol, file);
		FPutS (" [ ",file);

		{
			NodeIdRefCountListP node_id_ref_count_elem;
			
			for_l (node_id_ref_count_elem,node->node_node_id_ref_counts,nrcl_next){
				DPrintNodeId (node_id_ref_count_elem->nrcl_node_id,file);
				fprintf (file," %d ",node_id_ref_count_elem->nrcl_ref_count);
			}
		}
		FPutS ("]\n",file);
		print_spaces (n_leading_spaces+4,file);

#if 0
# ifndef PRINT_NODE_ID_REF_COUNTS
		if (node->node_strict_node_ids!=NULL){
			StrictNodeIdP strict_node_id;
			
			FPutS ("let! ", file);
			
			for_l (strict_node_id,node->node_strict_node_ids,snid_next){
				DPrintNodeId (strict_node_id->snid_node_id,file);
				FPutS ("; ",file);
			}
			FPutC ('\n',file);
			print_spaces (n_leading_spaces+4,file);
		}
# endif
#endif
		PrintArgument (node->node_arguments,False,n_leading_spaces+4,file);
		
		if (node->node_node_defs!=NULL){
			FPutC ('\n', file);
			print_spaces (n_leading_spaces,file);
			FPutS ("{\n",file);
			PrintNodeDefs (node->node_node_defs,n_leading_spaces+4,file);
			print_spaces (n_leading_spaces,file);
			FPutS ("}\n", file);
			print_spaces (n_leading_spaces,file);
		}

		break;		
	case DefaultNode:
		FPutS ("Default: [ ",file);
		{
			NodeIdRefCountListP node_id_ref_count_elem;
			
			for_l (node_id_ref_count_elem,node->node_node_id_ref_counts,nrcl_next){
				DPrintNodeId (node_id_ref_count_elem->nrcl_node_id,file);
				fprintf (file," %d ",node_id_ref_count_elem->nrcl_ref_count);
			}		
		}
		FPutS ("]\n",file);
		print_spaces (n_leading_spaces+4,file);

#if 0
# ifndef PRINT_NODE_ID_REF_COUNTS
		if (node->node_strict_node_ids!=NULL){
			StrictNodeIdP strict_node_id;
			
			FPutS ("let! ", file);
			
			for_l (strict_node_id,node->node_strict_node_ids,snid_next){
				DPrintNodeId (strict_node_id->snid_node_id,file);
				FPutS ("; ",file);
			}
			FPutC ('\n',file);
			print_spaces (n_leading_spaces+4,file);
		}
# endif
#endif
		PrintArgument (node->node_arguments,False,n_leading_spaces+4,file);

		if (node->node_node_defs!=NULL){
			FPutC ('\n', file);
			print_spaces (n_leading_spaces,file);
			FPutS ("{\n",file);
			PrintNodeDefs (node->node_node_defs,n_leading_spaces+4,file);
			print_spaces (n_leading_spaces,file);
			FPutS ("}\n", file);
			print_spaces (n_leading_spaces,file);
		}
		break;		
	case PushNode:
	{
		NodeIdListElementP node_id_list;

		FPutS ("Push ",file);
		DPrintNodeId (node->node_arguments->arg_node->node_node_id,file);
		FPutS ("[",file);
		for_l (node_id_list,node->node_node_ids,nidl_next){
			DPrintNodeId (node_id_list->nidl_node_id,file);
			if (node_id_list->nidl_next!=NULL)
				FPutC (' ',file);				
		}
		FPutS ("]",file);
		FPutC ('\n',file);
		print_spaces (n_leading_spaces,file);
		PrintArgument (node->node_arguments->arg_next,True,n_leading_spaces,file);
		break;		
	}
	case GuardNode:
		FPutS ("Guard ",file);
		PrintArgument (node->node_arguments,True,n_leading_spaces,file);
		FPutC ('\n',file);
		print_spaces (n_leading_spaces,file);
		PrintArgument (node->node_arguments->arg_next,True,n_leading_spaces,file);

		if (node->node_node_defs!=NULL){
			FPutC ('\n', file);
			print_spaces (n_leading_spaces,file);
			FPutS ("with {\n",file);
			PrintNodeDefs (node->node_node_defs,n_leading_spaces+4,file);
			print_spaces (n_leading_spaces,file);
			FPutS ("}\n", file);
			print_spaces (n_leading_spaces,file);
		}

		break;
	case TupleSelectorsNode:
		FPutS ("TupleSelectors (",file);
		PrintArguments (node->node_arguments,',',True,n_leading_spaces,file);
		FPutS (") = ",file);
		PrintRuleNode (node->node_node,True,n_leading_spaces,file);
		break;
	case FillUniqueNode:
		FPutS ("FillUniqueNode ",file);
		DPrintNodeId (node->node_node->node_arguments->arg_node->node_node_id,file);
		FPutC (' ',file);
		PrintArguments (node->node_arguments,' ',True,n_leading_spaces,file);
		break;
	default:
		FPutC ('?',file);
		fprintf (file,"%d",(int)node->node_kind);
	}
}

void PrintNodeDef (NodeDefP def_p,int n_leading_spaces,File file)
{
	int n;
	
	/* fprintf (file, "%d: ", (int) def_p->def_number); */
	
	for (n=n_leading_spaces; n>0; --n)
		FPutC (' ',file);
	
	DPrintNodeId (def_p -> def_id, file);
	
	if (def_p -> def_node){
		FPutS (" = ", file);
		PrintRuleNode  (def_p->def_node, False,n_leading_spaces,file);
	}
	
	FPutS ("\n",file);
}

void PrintNodeDefs (NodeDefs defs,int n_leading_spaces,File file)
{
	for ( ; defs!=NULL; defs=defs->def_next)
		PrintNodeDef (defs,n_leading_spaces,file);
}

STRUCT (lifted_node_id,LiftedNodeId){
	NodeId					lnid_lifted_node_id;
	NodeId					lnid_lhs_node_id;
	struct lifted_node_id *	lnid_next;
};

void PrintRuleAlt (RuleAlts rulealt,int n_leading_spaces,File file)
{
	PrintRuleNode (rulealt->alt_lhs_root, False,n_leading_spaces,file);

#ifdef PRINT_alt_lifted_node_ids
	if (rulealt->alt_lifted_node_ids){
		LiftedNodeId lifted_node_id_p;
		
		FPutS (" <<",file);
		for_l (lifted_node_id_p,rulealt->alt_lifted_node_ids,lnid_next){
			FPutC (' ',file);
			DPrintNodeId (lifted_node_id_p->lnid_lhs_node_id,file);
			FPutC (':',file);
			DPrintNodeId (lifted_node_id_p->lnid_lifted_node_id,file);
		}
		FPutS (" >>",file);
	}
#endif

	if (rulealt->alt_lhs_defs){
		FPutS ("\n", file);
		PrintNodeDefs (rulealt -> alt_lhs_defs,4,file);
		FPutS (" = ", file);
	} else
		FPutS ("\n = ", file);

	if (rulealt -> alt_kind==Contractum){
#if 1
# ifndef PRINT_NODE_ID_REF_COUNTS
		if (rulealt->alt_strict_node_ids!=NULL){
			StrictNodeIdP strict_node_id;
			
			FPutS ("let! ", file);
			
			for_l (strict_node_id,rulealt->alt_strict_node_ids,snid_next){
				DPrintNodeId (strict_node_id->snid_node_id,file);
				FPutS ("; ",file);
			}
			FPutC ('\n',file);
			print_spaces (n_leading_spaces,file);
		}
# endif
#endif


		PrintRuleNode  (rulealt->alt_rhs_root, False,n_leading_spaces,file);
		FPutS ("\n", file);
		PrintNodeDefs (rulealt->alt_rhs_defs,4,file);
	} else {
/*
		FPutS (rulealt->alt_rhs_root->node_node_id->nid_name,file);
*/
	}
}

static void PrintTypeArguments (TypeArgs args, char separator, File file)
{
	if (args){
		PrintTypeNode (args->type_arg_node, file);

		for (args = args->type_arg_next; args; args = args->type_arg_next){
			FPutC (separator, file);
			PrintTypeNode (args->type_arg_node, file);
		}
	}
}

static char *PrintUniVars = "uvwxyz";
#define NrOfPrintUniVars 6

void PrintTypeNode (TypeNode node, File file)
{
	if (node->type_node_annotation || node->type_node_annotation == StrictOnA)
		FPutC ('!', file);

	if (node->type_node_attribute == UniqueAttr)
		FPutC ('*', file);
	else if (node->type_node_attribute > UniqueAttr)
	{	unsigned node_attr = node->type_node_attribute - UniqueAttr;
	
		if (node_attr < NrOfPrintUniVars)
		{	FPutC (PrintUniVars[node_attr], file);
			FPutC (':', file);
		}
		else
			fprintf (file, "%u:", node_attr);
	}

	if (node->type_node_is_var)
		fprintf (file, "%d:", node->type_node_tv_argument_n);
	else if (node->type_node_symbol->ts_kind == tuple_type)
	{	FPutC ('(', file);
		PrintTypeArguments (node->type_node_arguments, ',', file);
		FPutC (')', file);
	}
	else if (node->type_node_symbol->ts_kind == list_type)
	{	FPutC ('[', file);
		PrintTypeArguments (node->type_node_arguments,',', file);
		FPutC (']', file);
	}
	else if (node->type_node_symbol->ts_kind >= array_type &&
			 node->type_node_symbol->ts_kind <= unboxed_array_type)
	{	char *delim_chars = ":|#";
		char array_delim = delim_chars [node->type_node_symbol->ts_kind - array_type];
		FPutC ('{', file);
		FPutC (array_delim, file);
		PrintTypeArguments (node->type_node_arguments,',', file);
		FPutC (array_delim, file);
		FPutC ('}', file);
	}
	else if (node->type_node_symbol->ts_kind == apply_type_symb)
	{	FPutC ('(', file);
		PrintTypeArguments (node -> type_node_arguments, ' ', file);
		FPutC (')', file);
	} else
	{	if (node->type_node_arguments)
			FPutC ('(', file);

		PrintTypeSymbol (node->type_node_symbol, file);
		
		if (node->type_node_arguments){
			FPutC (' ', file);
				
			PrintTypeArguments (node->type_node_arguments,' ', file);

			FPutC (')', file);
		}
	}
}

static void PrintAttribute (AttributeKind attr, File file)
{
	if (attr == NotUniqueAttr)
		return;
	else if (attr == UniqueAttr)
		FPutC ('*', file);
	else
		fprintf (file, "%d", attr - UniqueAttr);
}

void PrintTypeAlt (TypeAlts type_alts, File file)
{
	PrintSymbol (type_alts -> type_alt_lhs_symbol, file);
	FPutS (" :: ", file);
	PrintTypeArguments (type_alts -> type_alt_lhs_arguments, ' ', file);

	FPutS (" -> ", file);
	PrintTypeNode (type_alts -> type_alt_rhs, file);
	FPutC ('\n', file);
}

void PrintImpRule (ImpRules rule,int n_leading_spaces,File file)
{
	/*
	if (rule -> rule_type)
		PrintTypeAlt (rule -> rule_type, file);
	*/
	
	PrintRuleAlt (rule->rule_alts,n_leading_spaces,file);
}

void PrintRules (ImpRules rules,File file)
{
	ImpRuleS *rule;

	for_l (rule,rules,rule_next){
		PrintImpRule (rule,4,file);
		
		if (rule->rule_next!=NULL)
			FPutC ('\n',file);
	}
}

#endif
