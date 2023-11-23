/*
	(Concurrent) Clean Compiler: ABC instructions
	Authors:  Sjaak Smetsers & John van Groningen
*/

#include "compiledefines.h"
#include "types.t"
#include "system.h"
#include "comsupport.h"

#include <ctype.h>

#include "syntaxtr.t"

#include "settings.h"
#include "sizes.h"
#include "codegen_types.h"
#include "codegen1.h"
#include "codegen2.h"
#include "instructions.h"
#include "statesgen.h"

#ifdef NO_CLIB
# define isdigit clean_compiler_isdigit
# define isspace clean_compiler_isspace
#endif

#define for_l(v,l,n) for(v=(l);v!=NULL;v=v->n)

#define BINARY_ABC 0
#undef MEMORY_PROFILING_WITH_N_STRING

#ifdef CLEAN_FILE_IO

struct clean_file *clean_abc_file = NULL;

void PutCOutFile (char c)
{
	file_write_char (c,clean_abc_file);
}

void PutSOutFile (char *s)
{
	file_write_characters ((unsigned char*)s,strlen (s),clean_abc_file);
}

void PutIOutFile (long i)
{
	file_write_int (i,clean_abc_file);
}

#else
File OutFile;

#define PutSOutFile(s) FPutS ((s),OutFile)
#define PutCOutFile(s) FPutC ((s),OutFile)

void PutIOutFile (long i)
{
	fprintf (OutFile,"%ld",i);
}
#endif

static void error_in_function (char *m)
{
	ErrorInCompiler ("instructions.c",m,"");
}

#define N_DoDebug				0
#define N_DoReuseUniqueNodes	1
#define N_DoParallel			2

#define N_NoDescriptors 3
/*
#define N_NoMemoryProfiling		3
*/
#define N_DoStrictnessAnalysis	4
#define N_NoTimeProfiling		5
#define N_ExportLocalLabels 6
#define N_DoWarning				7
#define N_System				8
#define N_DoFusion				9
#define N_Do64BitArch			10
#define N_Dynamics				11
#define N_DoGenericFusion		12
#define N_DoCallGraphProfiling	13
#define N_TclFile				14

#define N_OPTIONS 15

static void ConvertOptionsToString (char *optstring)
{
	optstring[N_DoDebug]              = DoDebug ? '1' : '0';
	optstring[N_DoReuseUniqueNodes]   = !DoReuseUniqueNodes ? '1' : '0';
	optstring[N_DoParallel]           = DoParallel ? '1' : '0';

	optstring[N_NoDescriptors] = !DoDescriptors ? '1' : '0';
/*
	optstring[N_NoMemoryProfiling]    = !DoProfiling ? '1' : '0';
*/
	optstring[N_DoStrictnessAnalysis] = DoStrictnessAnalysis ? '1' : '0';

	optstring[N_NoTimeProfiling]      = !DoTimeProfiling ? '1' : '0';
	optstring[N_ExportLocalLabels] = ExportLocalLabels ? '1' : '0';
	optstring[N_DoWarning]            = DoWarning ? '1' : '0';
	optstring[N_System]               = '0';

	optstring[N_DoFusion] = DoFusion ? '1' : '0';
	optstring[N_Do64BitArch] = ObjectSizes[RealObj]!=2 ? '1' : '0';
	optstring[N_Dynamics] = Dynamics ? '1' : '0';
	optstring[N_DoGenericFusion] = DoGenericFusion ? '1' : '0';
	optstring[N_DoCallGraphProfiling] = DoCallGraphProfiling ? '1' : '0';
	optstring[N_TclFile] = TclFile ? '1' : '0';

	optstring[N_OPTIONS]='\0';
}

#define D_PREFIX "d"
#define N_PREFIX "n"
#define L_PREFIX "l"

#define EA_PREFIX "ea"
#define EU_PREFIX "eu"
#define S_PREFIX "s"

#define R_PREFIX "r"
#define RECORD_N_PREFIX "c"
#define RECORD_D_PREFIX "t"
#define CONSTRUCTOR_R_PREFIX "k"

#define LOCAL_D_PREFIX "d"

char *ABCFileName;

Bool OpenABCFile (char *fname)
{
#ifdef CLEAN_FILE_IO
	if (clean_abc_file!=NULL){
		ABCFileName = fname;
		return True;
	} else
		return False;
#else
	OutFile = FOpen (fname, "w");

	if (OutFile!=NULL){
		/* setvbuf ((FILE*) OutFile, NULL, _IOFBF, 8192); */
		OpenedFile = OutFile;
		ABCFileName = fname;
		return True;
	} else
		return False;
#endif
}

void WriteLastNewlineToABCFile (void)
{
	PutCOutFile ('\n');
}

void CloseABCFile (char *fname)
{
#ifdef CLEAN_FILE_IO
	clean_abc_file=NULL;
#else
	if (OutFile){
		if (FClose (OutFile) != 0){
			CompilerError = True;
			CurrentLine = 0;
			
			StaticMessage_s_s (True, "<open file>", "Write error (disk full?)");
		}
		if (CompilerError)
			FDelete (fname);
		OpenedFile = NULL;
	}
#endif
}

static Bool DescriptorNeeded (SymbDef sdef)
{
	return (sdef->sdef_exported || 
			(sdef->sdef_kind!=IMPRULE && sdef->sdef_kind!=SYSRULE) || 
			sdef->sdef_mark & SDEF_USED_CURRIED_MASK) ||
			((DoParallel || DoDescriptors) && (sdef->sdef_mark & (SDEF_USED_CURRIED_MASK | SDEF_USED_LAZILY_MASK)));
}

static void put_label_module_prefix_name (char *module_name,char *prefix,char *name)
{
	PutSOutFile ("e_");
	PutSOutFile (module_name);
	PutCOutFile ('_');
	PutSOutFile (prefix);
	PutSOutFile (name);
}

static void put_space_label_module_prefix_name (char *module_name,char *prefix,char *name)
{
	PutSOutFile (" e_");
	PutSOutFile (module_name);
	PutCOutFile ('_');
	PutSOutFile (prefix);
	PutSOutFile (name);
}

static void put_space_label_module_constructor_r_name (char *module_name,char *name)
{
	PutSOutFile (" e_");
	PutSOutFile (module_name);
	PutSOutFile ("_" CONSTRUCTOR_R_PREFIX);
	PutSOutFile (name);
}

static void put_space_label_module_d_name (char *module_name,char *name)
{
	PutSOutFile (" e_");
	PutSOutFile (module_name);
	PutSOutFile ("_" D_PREFIX);
	PutSOutFile (name);
}

static void put_space_label_module_ea_name (char *module_name,char *name)
{
	PutSOutFile (" e_");
	PutSOutFile (module_name);
	PutSOutFile ("_" EA_PREFIX);
	PutSOutFile (name);
}

static void put_space_label_module_eu_name (char *module_name,char *name)
{
	PutSOutFile (" e_");
	PutSOutFile (module_name);
	PutSOutFile ("_" EU_PREFIX);
	PutSOutFile (name);
}

static void put_space_label_module_l_name (char *module_name,char *name)
{
	PutSOutFile (" e_");
	PutSOutFile (module_name);
	PutSOutFile ("_" L_PREFIX);
	PutSOutFile (name);
}

static void put_space_label_module_n_name (char *module_name,char *name)
{
	PutSOutFile (" e_");
	PutSOutFile (module_name);
	PutSOutFile ("_" N_PREFIX);
	PutSOutFile (name);
}

static void put_space_label_module_r_name (char *module_name,char *name)
{
	PutSOutFile (" e_");
	PutSOutFile (module_name);
	PutSOutFile ("_" R_PREFIX);
	PutSOutFile (name);
}

static void put_space_label_module_record_d_name (char *module_name,char *name)
{
	PutSOutFile (" e_");
	PutSOutFile (module_name);
	PutSOutFile ("_" RECORD_D_PREFIX);
	PutSOutFile (name);
}

static void put_space_label_module_record_n_name (char *module_name,char *name)
{
	PutSOutFile (" e_");
	PutSOutFile (module_name);
	PutSOutFile ("_" RECORD_N_PREFIX);
	PutSOutFile (name);
}

static void put_space_label_module_s_name (char *module_name,char *name)
{
	PutSOutFile (" e_");
	PutSOutFile (module_name);
	PutSOutFile ("_" S_PREFIX);
	PutSOutFile (name);
}

static void put_space_quoted_string (char *s)
{
	PutSOutFile (" \"");
	PutSOutFile (s);
	PutCOutFile ('\"');
}

static void Put_SOutFile (char *s)
{
	PutCOutFile (' ');
	PutSOutFile (s);
}

static void PutSSOutFile (char *s1,char *s2)
{
	PutSOutFile (s1);
	PutSOutFile (s2);
}

static void PutSUOutFile (char *s1,unsigned int u)
{
	PutSOutFile (s1);
	PutIOutFile ((int)u);
}

static void PutSdotSOutFile (char *s1,char *s2)
{
	PutSOutFile (s1);
	PutCOutFile ('.');
	PutSOutFile (s2);
}

static void PutSdotUOutFile (char *s1,unsigned int u)
{
	PutSOutFile (s1);
	PutCOutFile ('.');
	PutIOutFile ((int)u);
}

static void PutSSdotDOutFile (char *s1,char *s2,int i)
{
	PutSOutFile (s1);
	PutSOutFile (s2);
	PutCOutFile ('.');
	PutIOutFile (i);
}

static void PutSSdotSOutFile (char *s1,char *s2,char *s3)
{
	PutSOutFile (s1);
	PutSOutFile (s2);
	PutCOutFile ('.');
	PutSOutFile (s3);
}

static void PutSSdotUOutFile (char *s1,char *s2,unsigned int u)
{
	PutSOutFile (s1);
	PutSOutFile (s2);
	PutCOutFile ('.');
	PutIOutFile ((int)u);
}

static void PutdotSOutFile (char *s)
{
	PutCOutFile ('.');
	PutSOutFile (s);
}

static void PutdotUOutFile (unsigned int u)
{
	PutCOutFile ('.');
	PutIOutFile ((int)u);
}

static void GenLabel (Label label)
{
	if (label->lab_issymbol){
		SymbDef def;
		char *module_name;

		def=label->lab_symbol;
		module_name = label->lab_mod;
		
		if (module_name!=NULL)
			put_label_module_prefix_name (module_name,label->lab_pref,def->sdef_name);
		else if (DoDebug){
			if (def->sdef_kind==IMPRULE)
				PutSSdotUOutFile (label->lab_pref,def->sdef_name,def->sdef_number);
			else
				PutSSOutFile (label->lab_pref,def->sdef_name);
		} else if (def->sdef_number==0)
			PutSSOutFile (label->lab_pref,def->sdef_name);
		else if (label->lab_pref[0] == '\0')
			PutSUOutFile (LOCAL_D_PREFIX,def->sdef_number);
		else
			PutSUOutFile (label->lab_pref,def->sdef_number);
	} else {
		PutSOutFile (label->lab_pref);
		PutSOutFile (label->lab_name);
	}
	if (label->lab_post!=0)
		PutdotUOutFile (label->lab_post);
}

static void GenDescriptorOrNodeEntryLabel (Label label)
{
	if (label->lab_issymbol){
		SymbDef def;
		char *module_name;

		def=label->lab_symbol;
		module_name = label->lab_mod;
		
		if (module_name!=NULL)
			put_label_module_prefix_name (module_name,label->lab_pref,def->sdef_name);
		else if (ExportLocalLabels){
			put_label_module_prefix_name (CurrentModule,label->lab_pref,def->sdef_name);
			if (def->sdef_kind==IMPRULE)
				PutdotUOutFile (def->sdef_number);
		} else if (DoDebug){
			if (def->sdef_kind==IMPRULE)
				PutSSdotUOutFile (label->lab_pref,def->sdef_name,def->sdef_number);
			else
				PutSSOutFile (label->lab_pref,def->sdef_name);
		} else if (def->sdef_number==0)
			PutSSOutFile (label->lab_pref,def->sdef_name);
		else if (label->lab_pref[0] == '\0')
			PutSUOutFile (LOCAL_D_PREFIX,def->sdef_number);
		else
			PutSUOutFile (label->lab_pref,def->sdef_number);
	} else {
		PutSOutFile (label->lab_pref);
		PutSOutFile (label->lab_name);
	}
	if (label->lab_post!=0)
		PutdotUOutFile (label->lab_post);
}

#if BINARY_ABC
static void put_n (long n)
{
	while (!(n>=-64 && n<=63)){
		PutCOutFile (128+(n & 127));
		n=n>>7;
	}

	PutCOutFile (n+64);
}

static long integer_string_to_integer (char *s_p)
{
	long integer;
	int minus_sign,last_char;
	
	minus_sign=0;
	last_char=*s_p++;
	if (last_char=='+' || last_char=='-'){
		if (last_char=='-')
			minus_sign=!minus_sign;
		last_char=*s_p++;;
	}
			
	integer=last_char-'0';
	last_char=*s_p++;;
	
	while ((unsigned)(last_char-'0')<10u){
		integer*=10;
		integer+=last_char-'0';
		last_char=*s_p++;;
	}
		
	if (minus_sign)
		integer=-integer;
	
	return integer;
}
#endif

static void put_arguments_i_b (char *i1)
{
#if BINARY_ABC
	if (!DoDebug){
		put_n (integer_string_to_integer (i1));
		return;
	}
#endif
	PutCOutFile (' ');
	PutSOutFile (i1);
}

static void put_arguments_in_b (char *i1,long n1)
{
#if BINARY_ABC
	if (!DoDebug){
		put_n (integer_string_to_integer (i1));
		put_n (n1);
		return;
	}
#endif
	PutCOutFile (' ');
	PutSOutFile (i1);
	PutCOutFile (' ');
	PutIOutFile (n1);
}

static void put_arguments_n_b (long n1)
{
#if BINARY_ABC
	if (!DoDebug){
		put_n (n1);
		return;
	}
#endif
	PutCOutFile (' ');
	PutIOutFile (n1);
}

static void put_arguments_nn_b (long n1,long n2)
{
#if BINARY_ABC
	if (!DoDebug){
		put_n (n1);
		put_n (n2);
		return;
	}
#endif
	PutCOutFile (' ');
	PutIOutFile (n1);
	PutCOutFile (' ');
	PutIOutFile (n2);
}

static void put_arguments_nnn_b (long n1,long n2,long n3)
{
#if BINARY_ABC
	if (!DoDebug){
		put_n (n1);
		put_n (n2);
		put_n (n3);
		return;
	}
#endif
	PutCOutFile (' ');
	PutIOutFile (n1);
	PutCOutFile (' ');
	PutIOutFile (n2);
	PutCOutFile (' ');
	PutIOutFile (n3);
}

static void put_arguments_nnnn_b (long n1,long n2,long n3,long n4)
{
#if BINARY_ABC
	if (!DoDebug){
		put_n (n1);
		put_n (n2);
		put_n (n3);
		put_n (n4);
		return;
	}
#endif
	PutCOutFile (' ');
	PutIOutFile (n1);
	PutCOutFile (' ');
	PutIOutFile (n2);
	PutCOutFile (' ');
	PutIOutFile (n3);
	PutCOutFile (' ');
	PutIOutFile (n4);
}

static void put_arguments_nnnnn_b (long n1,long n2,long n3,long n4,long n5)
{
#if BINARY_ABC
	if (!DoDebug){
		put_n (n1);
		put_n (n2);
		put_n (n3);
		put_n (n4);
		put_n (n5);
		return;
	}
#endif
	PutCOutFile (' ');
	PutIOutFile (n1);
	PutCOutFile (' ');
	PutIOutFile (n2);
	PutCOutFile (' ');
	PutIOutFile (n3);
	PutCOutFile (' ');
	PutIOutFile (n4);
	PutCOutFile (' ');
	PutIOutFile (n5);
}

#if !BINARY_ABC

#define put_instructionb(a) put_instruction(I##a)
#define put_instruction_b(a) put_instruction_(I##a)
#define put_directiveb(a) put_directive(D##a)
#define put_directive_b(a) put_directive_(D##a)

#else

#define put_instructionb(a) if (DoDebug) put_instruction(I##a); else put_instruction_code(C##a)
#define put_instruction_b(a) if (DoDebug) put_instruction_(I##a); else put_instruction_code(C##a)
#define put_directiveb(a) if (DoDebug) put_directive(D##a); else put_instruction_code(C##a)
#define put_directive_b(a) if (DoDebug) put_directive_(D##a); else put_instruction_code(C##a)

enum {
	Cbuild=136,
	Cbuildh,
	CbuildI,
	CbuildB_b,
	CbuildC_b,
	CbuildI_b,
	CbuildR_b,
	CbuildF_b,
	Ceq_desc,
	CeqD_b,
	CeqI_a,
	CeqI_b,
	Cfill,
	Cfillh,
	CfillI,
	CfillB_b,
	CfillC_b,
	CfillF_b,
	CfillI_b,
	CfillR_b,
	Cfill_a,
	Cjmp,
	Cjmp_false,
	Cjmp_true,
	Cjsr,
	Cjsr_eval,
	Cpop_a,
	Cpop_b,
	CpushB_a,
	CpushC_a,
	CpushI_a,
	CpushF_a,
	CpushR_a,
	CpushD,
	CpushI,
	Cpush_a,
	Cpush_b,
	Cpush_arg,
	Cpush_args,
	Cpush_args_u,
	Cpush_node,
	Cpush_node_u,
	Cpush_r_args,
	Cpush_r_args_a,
	Cpush_r_args_b,
	Cpush_r_args_u,
	Crepl_arg,
	Crepl_args,
	Crepl_r_args,
	Crepl_r_args_a,
	Crtn,
	Cupdate_a,
	Cupdate_b,
	Cupdatepop_a,
	Cupdatepop_b,
	
	Cd,
	Co,
	Cimpdesc,
	Cimplab,
	Cimpmod,
	Cn
};
#endif

#define IbuildB "buildB"
#define IbuildC "buildC"
#define IbuildI "buildI"
#define IbuildR "buildR"

#define IbuildB_b "buildB_b"
#define IbuildC_b "buildC_b"
#define IbuildF_b "buildF_b"
#define IbuildI_b "buildI_b"
#define IbuildR_b "buildR_b"

#define IfillB "fillB"
#define IfillC "fillC"
#define IfillI "fillI"
#define IfillR "fillR"

#define IfillB_b "fillB_b"
#define IfillC_b "fillC_b"
#define IfillI_b "fillI_b"
#define IfillR_b "fillR_b"
#define IfillF_b "fillF_b"

#define IeqB_a "eqB_a"
#define IeqC_a "eqC_a"
#define IeqI_a "eqI_a"
#define IeqR_a "eqR_a"

#define IeqAC_a "eqAC_a"

#define IeqB_b "eqB_b"
#define IeqC_b "eqC_b"
#define IeqI_b "eqI_b"
#define IeqR_b "eqR_b"

#define InotB "notB"

#define IpushB "pushB"
#define IpushI "pushI"
#define IpushC "pushC"
#define IpushR "pushR"
#define IpushZR "pushZR"
#define IpushZ "pushZ"

#define IpushD "pushD"

#define IpushB_a "pushB_a"
#define IpushC_a "pushC_a"
#define IpushI_a "pushI_a"
#define IpushR_a "pushR_a"
#define IpushF_a "pushF_a"

#define IpushD_a "pushD_a"

#define Ipush_array "push_array"
#define Ipush_arraysize "push_arraysize"
#define Iselect "select"
#define Iupdate "update"
#define Ireplace "replace"

#define Ipush_arg "push_arg"
#define Ipush_args "push_args"
#define Ipush_args_u "push_args_u"
#define Ipush_r_args "push_r_args"
#define Ipush_r_args_u "push_r_args_u"
#define Ipush_r_args_a "push_r_args_a"
#define Ipush_r_args_b "push_r_args_b"
#define Ipush_r_arg_u "push_r_arg_u"
#define Irepl_arg "repl_arg"
#define Irepl_args "repl_args"
#define Irepl_r_args "repl_r_args"
#define Irepl_r_args_a "repl_r_args_a"

#define Ipush_node "push_node"
#define Ipush_node_u "push_node_u"

#define Ifill "fill"
#define Ifillcp "fillcp"
#define Ifill_u "fill_u"
#define Ifillcp_u "fillcp_u"
#define Ifillh "fillh"
#define Ifill1 "fill1"
#define Ifill2 "fill2"
#define Ifill3 "fill3"

#define Ibuild "build"
#define Ibuildh "buildh"
#define Ibuild_u "build_u"
#define IbuildAC "buildAC"

#define Ifill_r "fill_r"
#define Ifill1_r "fill1_r"
#define Ifill2_r "fill2_r"
#define Ifill3_r "fill3_r"

#define Ibuildhr "buildhr"
#define Ibuild_r "build_r"

#define Ifill_a "fill_a"

#define Ipush_a "push_a"
#define Ipush_b "push_b"

#define Ijsr_eval "jsr_eval"
#define Ijsr_ap "jsr_ap"
#define Ijsr_i "jsr_i"

#define Ipop_a "pop_a"
#define Ipop_b "pop_b"
#define Ieq_desc "eq_desc"
#define IeqD_b "eqD_b"

#define Ijmp_false "jmp_false"
#define Ijmp_true "jmp_true"
#define Ijmp "jmp"
#define Ijsr "jsr"

#define Icreate "create"
#define Iprint "print"

#define Iupdate_a "update_a"
#define Iupdate_b "update_b"
#define Iupdatepop_a "updatepop_a"
#define Iupdatepop_b "updatepop_b"
#define Iupdate_b "update_b"
#define Ipop_a "pop_a"
#define Ipop_b "pop_b"

#define Iget_node_arity "get_node_arity"
#define Iget_desc_arity "get_desc_arity"

#define Ipush_arg_b "push_arg_b"

#define Irtn "rtn"

#define Ijmp_eval "jmp_eval"
#define Ijmp_eval_upd "jmp_eval_upd"
#define Ijmp_ap "jmp_ap"
#define Ijmp_ap_upd "jmp_ap_upd"
#define Ijmp_i "jmp_i"
#define Ijmp_not_eqZ "jmp_not_eqZ"
#define Ijmp_upd "jmp_upd"

#define Ihalt "halt"

#define Itestcaf "testcaf"
#define Ipushcaf "pushcaf"
#define Ifillcaf "fillcaf"

#define Iin "in"
#define Iout "out"

static void put_instruction (char *instruction)
{
	PutCOutFile ('\n');
	PutCOutFile ('\t');
	PutSOutFile (instruction);
}

static void put_instruction_ (char *instruction)
{
	PutCOutFile ('\n');
	PutCOutFile ('\t');
	PutSOutFile (instruction);
	PutCOutFile (' ');
}

static void put_instruction_code (int instruction_code)
{
	PutCOutFile (instruction_code);
}

static void write_compiler_generated_function_name_to_out_file (char *name, char *name_end, unsigned line_nr)
{
	char *parsed_digits;

	PutSOutFile (name);
	
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
		PutSOutFile ("[line: ");
		PutIOutFile ((int)line_nr);
		PutCOutFile (']');
		if (parsed_digits)
			name_end=parsed_digits;
	} else
		if (parsed_digits){
			char *d_p;

			PutSOutFile ("[line:");
			for (d_p=name_end+1; d_p<parsed_digits; ++d_p)
				PutCOutFile (*d_p);
			PutCOutFile (']');

			name_end=parsed_digits;
		}
	PutSOutFile (name_end);
}

static void WriteSymbolOfIdentToOutFile (char *name, unsigned line_nr)
{
	char *name_end;

	for (name_end=name; *name_end!=';' && *name_end!='\0'; ++name_end)
		;

	if (*name=='\\' && name+1==name_end){
		write_compiler_generated_function_name_to_out_file ("<lambda>",name_end,line_nr);
		return;
	}

	if (*name == '_'){
		if (name+2==name_end && name[1]=='c'){
			write_compiler_generated_function_name_to_out_file ("<case>",name_end,line_nr);
			return;
		} else if (name+3==name_end && name[1]=='i' && name[2]=='f'){
			write_compiler_generated_function_name_to_out_file ("<if>",name_end,line_nr);
			return;
		}
	} else
		if (line_nr > 0 && *name_end == ';' && isdigit (name_end[1])){
			char *end_name;

			for (; name!=name_end; name++)
				PutCOutFile (*name);

			for (end_name = name_end + 2; *end_name!=';' && *end_name!='\0'; end_name++)
				 ;
			
			PutSOutFile (" [line: ");
			PutIOutFile ((int)line_nr);
			PutCOutFile (']');

			if (*end_name == '\0')
				return;

			name = end_name;
		}

	PutSOutFile (name);
}

void WriteSymbolToOutFile (Symbol symbol)
{
	if (symbol->symb_kind==definition)
		WriteSymbolOfIdentToOutFile (symbol->symb_def->sdef_name, 0);
	else
		PutSOutFile (symbol_to_string (symbol));
}

static void GenGetWL (int offset)
{
	put_instruction ("getWL");
	put_arguments_n_b (offset);
}

static void GenPutWL (int offset)
{
	put_instruction ("putWL");
	put_arguments_n_b (offset);
}

static void GenRelease (void)
{
	put_instruction ("release");
}

static void TreatWaitListBeforeFill (int offset, FillKind fkind)
{
	if (DoParallel && fkind != NormalFill)
		GenGetWL (offset);	
}

static void TreatWaitListAfterFill (int offset, FillKind fkind)
{
	if (DoParallel){
		switch (fkind){
			case ReleaseAndFill:GenRelease ();		break;
			case PartialFill:	GenPutWL (offset);	break;
			default:							break;
		}
	}
}

#define Da "a"
#define Dai "ai"
#define Dkeep "keep"
#define Dd "d"
#define Do "o"
#define Dimpdesc "impdesc"
#define Dimplab "implab"
#define Dimpmod "impmod"
#define Dexport "export"
#define Dn "n"
#define Dnu "nu"
#define Dn_string "n_string"
#define Ddesc "desc"
#define Ddesc0 "desc0"
#define Ddescn "descn"
#define Ddescs "descs"
#define Ddescexp "descexp"
#define Drecord "record"
#define Dmodule "module"
#define Ddepend "depend"
#define Dcomp "comp"
#define Dstart "start"
#define Dstring "string"
#define Dcaf "caf"
#define Dendinfo "endinfo"

#define Dpb "pb"
#define Dpd "pd"
#define Dpn "pn"
#define Dpl "pl"
#define Dpld "pld"
#define Dpt "pt"
#define Dpe "pe"

static void put_directive (char *directive)
{
	PutCOutFile ('\n');
	PutCOutFile ('.');
	PutSOutFile (directive);
}

static void put_directive_ (char *directive)
{
	PutCOutFile ('\n');
	PutCOutFile ('.');
	PutSOutFile (directive);
	PutCOutFile (' ');
}

static void put_first_directive (char *directive)
{
	PutCOutFile ('.');
	PutSOutFile (directive);
}

void BuildBasicFromB (ObjectKind kind,int b_offset)
{
	switch (kind){
		case IntObj:
		case ProcIdObj:
		case RedIdObj:
			put_instructionb (buildI_b); break;
		case BoolObj:
			put_instructionb (buildB_b); break;
		case CharObj:
			put_instructionb (buildC_b); break;
		case RealObj:
			put_instructionb (buildR_b); break;
		case FileObj:
			put_instructionb (buildF_b); break;
		default:
			error_in_function ("BuildBasicFromB");
			return;
	}

	put_arguments_n_b (b_offset);
}

void FillBasicFromB (ObjectKind kind, int boffs, int aoffs, FillKind fkind)
{
	TreatWaitListBeforeFill (aoffs, fkind);
	switch (kind){
		case IntObj:
		case ProcIdObj:			/* we assume proc_id and red_id	*/
		case RedIdObj:			/* to be integers				*/
			put_instructionb (fillI_b); break;
		case BoolObj:
			put_instructionb (fillB_b); break;
		case CharObj:
			put_instructionb (fillC_b); break;
		case RealObj:
			put_instructionb (fillR_b); break;
		case FileObj:
			put_instructionb (fillF_b); break;
		default:
			error_in_function ("FillBasicFromB");
			return;
	}
	put_arguments_nn_b (boffs,aoffs);
	TreatWaitListAfterFill (aoffs, fkind);
}

void BuildBasic (ObjectKind obj,SymbValue val)
{
	switch (obj){
		case IntObj:
			put_instructionb (buildI);
			put_arguments_i_b (val.val_int);
			break;
		case BoolObj:
			put_instruction_ (IbuildB);
			PutSOutFile (val.val_bool ? "TRUE" : "FALSE");
			break;
		case CharObj:
			put_instruction (IbuildC);
			Put_SOutFile (val.val_char);
			break;
		case RealObj:
			put_instruction (IbuildR);
			Put_SOutFile (val.val_real);
			break;
		default:
			error_in_function ("BuildBasic");
			return;
	}
}

void FillBasic (ObjectKind obj, SymbValue val, int offset, FillKind fkind)
{
	TreatWaitListBeforeFill (offset, fkind);
	switch (obj){
		case IntObj:
			put_instructionb (fillI);
			put_arguments_in_b (val.val_int,offset);
			break;
		case BoolObj:
			put_instruction (IfillB);
			PutSOutFile (val.val_bool ? " TRUE" : " FALSE");
			put_arguments_n_b (offset);
			break;
		case CharObj:
			put_instruction (IfillC);
			Put_SOutFile (val.val_char);
			put_arguments_n_b (offset);
			break;
		case RealObj:
			put_instruction (IfillR);
			Put_SOutFile (val.val_real);
			put_arguments_n_b (offset);
			break;
		default:
			error_in_function ("FillBasic");
			return;
	}
	TreatWaitListAfterFill (offset, fkind);
}

void IsBasic (ObjectKind obj, SymbValue val, int offset)
{
	switch (obj){
		case IntObj:
			put_instructionb (eqI_a);
			put_arguments_in_b (val.val_int,offset);
			return;
		case BoolObj:
			put_instruction (IeqB_a);
			PutSOutFile (val.val_bool ? " TRUE" : " FALSE");
			break;
		case CharObj:
			put_instruction (IeqC_a);
			Put_SOutFile (val.val_char);
			break;
		case RealObj:
			put_instruction (IeqR_a);
			Put_SOutFile (val.val_real);
			break;
		default:
			error_in_function ("IsBasic");
			return;
	}
	put_arguments_n_b (offset);
}

void IsString (SymbValue val)
{
	put_instruction_ (IeqAC_a);
	PutSOutFile (val.val_string);
}

void PushBasic (ObjectKind obj, SymbValue val)
{
	switch (obj){
		case IntObj:
			put_instructionb (pushI);
			put_arguments_i_b (val.val_int);
			break;
		case BoolObj:
			put_instruction_ (IpushB);
			PutSOutFile (val.val_bool ? "TRUE" : "FALSE");
			break;
		case CharObj:
			put_instruction (IpushC);
			Put_SOutFile (val.val_char);
			break;
		case RealObj:
			put_instruction_ (IpushR);
			PutSOutFile (val.val_real);
			break;
		default:
			error_in_function ("PushBasic");
			return;
	}
}

void GenPushReducerId (int i)
{
	put_instructionb (pushI);
	put_arguments_n_b (i);
}

void GenPushArgNr (int argnr)
{
	put_instructionb (pushI);
	put_arguments_n_b (argnr);
}

void EqBasic (ObjectKind obj, SymbValue val, int offset)
{
	switch (obj){
		case IntObj:
			put_instructionb (eqI_b);
			put_arguments_in_b (val.val_int,offset);
			return;
		case BoolObj:
			put_instruction (IeqB_b);
			PutSOutFile (val.val_bool ? " TRUE" : " FALSE");
			break;
		case CharObj:
			put_instruction (IeqC_b);
			Put_SOutFile (val.val_char);
			break;
		case RealObj:
			put_instruction (IeqR_b);
			Put_SOutFile (val.val_real);
			break;
		default:
			error_in_function ("EqBasic");
			return;
	}
	put_arguments_n_b (offset);
}

void GenNotB (void)
{
	put_instruction (InotB);
}

void PushBasicFromAOnB (ObjectKind kind,int offset)
{
	switch (kind){
		case IntObj:
		case ProcIdObj:
		case RedIdObj:
			put_instructionb (pushI_a);
			break;
		case BoolObj:
			put_instructionb (pushB_a);
			break;
		case CharObj:
			put_instructionb (pushC_a);
			break;
		case RealObj:
			put_instructionb (pushR_a);
			break;
		case FileObj:
			put_instructionb (pushF_a);
			break;
		default:
			error_in_function ("PushBasicFromAOnB");
			return;
	}
	put_arguments_n_b (offset);
}

void GenPushD_a (int a_offset)
{
	put_instruction (IpushD_a);
	put_arguments_n_b (a_offset);
}
	
void PushBasicOnB (ObjectKind obj, int offset)
{
	int i;

	for (i = ObjectSizes[obj]; i > 0; i--)
		GenPushB (offset + ObjectSizes[obj] - 1);
}

void UpdateBasic (int size, int srcoffset, int dstoffset)
{
	if (srcoffset < dstoffset){
		int i;
		
		for (i=size-1; i >= 0; i--)
			GenUpdateB (srcoffset+i, dstoffset+i);
	} else if (srcoffset > dstoffset){
		int i;
		
		for (i=0; i < size; i++)
			GenUpdateB (srcoffset+i, dstoffset+i);
	}
}

static Bool IsDirective (Instructions instruction, char *directive)
{
	char *s;

	s=instruction->instr_this;
	while (isspace(*s))
		++s;
	if (*s!='.')
		return False;

	for (; *directive; ++directive)
		if (*directive!=*++s)
			return False;

	return True;
}

static Bool IsInlineFromCurrentModule (SymbDef def)
{
	RuleAlts alt;
	Instructions instruction, next;
	/*
	if (def->sdef_kind!=IMPRULE)
		return False;
	*/
	alt=def->sdef_rule->rule_alts;

	if (alt->alt_kind!=ExternalCall || !alt->alt_rhs_code->co_is_abc_code)
		return False;
	
	instruction=alt->alt_rhs_code->co_instr;

	if (!IsDirective(instruction, "inline"))
		return False;

	for (instruction=instruction->instr_next;(next=instruction->instr_next)!=NULL;instruction=next)
		;

	return (IsDirective(instruction, "end"));
}

/*
	For ABC to target machine code generation we supply the abc code
	with special stack layout directives. The routines for doing this
	are 'GenBStackElems', 'GenStackLayoutOfNode' and 'GenStackLayoutOfState'.
*/

static char BElems[] = BASIC_ELEMS_STRING;

static void GenBStackElems (StateS state)
{
	if (IsSimpleState (state)){
		if (state.state_kind == OnB)
			PutCOutFile (BElems [(int) state.state_object]);			
	} else {
		int arity;
		States argstates;
		
		switch (state.state_type){
			case TupleState:
				argstates = state.state_tuple_arguments;
				break;
			case RecordState:
				argstates = state.state_record_arguments;
				break;
			case ArrayState:
				return;
			default:
				error_in_function ("GenBStackElems");
				return;
		}
		for (arity=0; arity < state.state_arity; ++arity)
			GenBStackElems (argstates[arity]);
	}
}

static void GenABStackElems (StateS state)
{
	if (IsSimpleState (state)){
		if (state.state_kind == OnB)
			PutCOutFile (BElems [(int) state.state_object]);
		else
			PutCOutFile ('a');
	} else {
		int arity;
		States argstates;
		
		switch (state.state_type){
			case TupleState:
				argstates = state.state_tuple_arguments;			
				PutCOutFile ('(');
				if (state.state_arity>0){
					GenABStackElems (argstates[0]);
					for (arity=1; arity < state.state_arity; arity++){
						PutCOutFile (',');
						GenABStackElems (argstates[arity]);
					}
				}
				PutCOutFile (')');
				break;
			case RecordState:
				argstates = state.state_record_arguments;
				PutCOutFile ('(');
				for (arity=0; arity < state.state_arity; arity++)
					GenABStackElems (argstates[arity]);
				PutCOutFile (')');
				return;
			case ArrayState:
				PutCOutFile ('a');
				return;
			default:
				error_in_function ("GenABStackElems");
				return;
		}
	}
}

static void GenABStackElemsForRecordDesc (StateS state)
{
	if (IsSimpleState (state)){
		if (state.state_kind == OnB)
			PutCOutFile (BElems [(int) state.state_object]);
		else
			PutCOutFile ('a');
	} else {
		int arity;
		States argstates;
		
		switch (state.state_type){
			case TupleState:
				argstates = state.state_tuple_arguments;			
				PutCOutFile ('(');
				if (state.state_arity>0){
					GenABStackElemsForRecordDesc (argstates[0]);
					for (arity=1; arity < state.state_arity; ++arity){
						PutCOutFile (',');
						GenABStackElemsForRecordDesc (argstates[arity]);
					}
				}
				PutCOutFile (')');
				return;
			case RecordState:
				argstates = state.state_record_arguments;
				PutCOutFile ('{');
				for (arity=0; arity < state.state_arity; ++arity)
					GenABStackElemsForRecordDesc (argstates[arity]);
				PutCOutFile ('}');
				return;
			case ArrayState:
				PutCOutFile ('a');
				return;
			default:
				error_in_function ("GenABStackElemsForRecordDesc");
		}
	}
}

static void GenABStackElemsOfRecord (StateS state)
{
	if (state.state_type==RecordState){
		int arity;
		States argstates;

		argstates = state.state_record_arguments;
		for (arity=0; arity < state.state_arity; ++arity)
			GenABStackElemsForRecordDesc (argstates[arity]);
	} else
		GenABStackElemsForRecordDesc (state);
}

static int AddSizeOfStatesAndImportRecords (int arity, States states, int *asize, int *bsize);

static int AddSizeOfStateAndImportRecords (StateS state, int *asize, int *bsize)
{
	if (IsSimpleState (state)){
		if (state.state_kind == OnB)
			*bsize += ObjectSizes [state.state_object];
		else if (state.state_kind != Undefined)
			*asize += SizeOfAStackElem;
		return 0;
	} else {
		switch (state.state_type){
			case RecordState:
			{
				SymbDef record_sdef;

				record_sdef = state.state_record_symbol;
				if (record_sdef->sdef_exported || record_sdef->sdef_module!=CurrentModule || ExportLocalLabels){
					if ((record_sdef->sdef_mark & SDEF_RECORD_R_LABEL_IMPORTED_MASK)!=0){
						record_sdef->sdef_mark |= SDEF_USED_STRICTLY_MASK;
					} else {
						record_sdef->sdef_mark |= SDEF_USED_STRICTLY_MASK;
						record_sdef->sdef_mark |= SDEF_USED_STRICTLY_MASK | SDEF_RECORD_R_LABEL_IMPORTED_MASK;
						GenImpRecordDesc (record_sdef->sdef_module,record_sdef->sdef_name);
					}
				}

				(void) AddSizeOfStatesAndImportRecords (state.state_arity, state.state_record_arguments, asize, bsize);
				return 1;
			}
			case TupleState:
				return AddSizeOfStatesAndImportRecords (state.state_arity, state.state_tuple_arguments, asize, bsize);
			case ArrayState:
				*asize += SizeOfAStackElem;
				return 0;
		}
	}
	return 0;
}

static int AddSizeOfStatesAndImportRecords (int arity, States states, int *asize, int *bsize)
{
	int has_unboxed_record;
	
	has_unboxed_record=0;
	for (; arity; arity--)
		has_unboxed_record |= AddSizeOfStateAndImportRecords (states [arity-1], asize, bsize);
	return has_unboxed_record;
}

static void GenUnboxedRecordLabelsReversed (StateS state)
{
	if (!IsSimpleState (state)){
		int arity;
		States argstates;
		
		switch (state.state_type){
			case TupleState:
				argstates = state.state_tuple_arguments;			
				for (arity=state.state_arity-1; arity>=0; --arity)
					GenUnboxedRecordLabelsReversed (argstates[arity]);
				return;
			case RecordState:
			{
				SymbDef record_sdef;

				argstates = state.state_record_arguments;
				for (arity=state.state_arity-1; arity>=0 ; --arity)
					GenUnboxedRecordLabelsReversed (argstates[arity]);

				record_sdef = state.state_record_symbol;
				if (!record_sdef->sdef_exported && record_sdef->sdef_module==CurrentModule && !ExportLocalLabels){
					if (DoDebug)
						PutSSOutFile (" " R_PREFIX,record_sdef->sdef_name);
					else
						PutSUOutFile (" " R_PREFIX,record_sdef->sdef_number);
				} else
					put_space_label_module_r_name (record_sdef->sdef_module,record_sdef->sdef_name);
				return;
			}
			case ArrayState:
				return;
			default:
				error_in_function ("GenUnboxedRecordLabelsReversed");
				return;
		}
	}
}

static void GenUnboxedRecordLabelsReversedForRecord (StateS state)
{
	if (state.state_type==RecordState){
		int arity;
		States argstates;

		argstates = state.state_record_arguments;
		for (arity=state.state_arity-1; arity>=0; --arity)
			GenUnboxedRecordLabelsReversed (argstates[arity]);
	} else
		GenUnboxedRecordLabelsReversed (state);
}

void GenDStackLayout (int asize,int bsize,Args fun_args)
{
	if (DoStackLayout){
		put_directiveb (d);
		if (bsize > 0){
			put_arguments_nn_b (asize,bsize);
			PutCOutFile (' ');

			while (fun_args!=NULL){
				GenBStackElems (fun_args->arg_state);
				fun_args=fun_args->arg_next;
			}
		} else
			put_arguments_nn_b (asize,0);
	}
}

void GenOStackLayout (int asize,int bsize,Args fun_args)
{
	if (DoStackLayout){
		put_directiveb (o);
		if (bsize > 0){
			put_arguments_nn_b (asize,bsize);
			PutCOutFile (' ');

			while (fun_args!=NULL){
				GenBStackElems (fun_args->arg_state);
				fun_args=fun_args->arg_next;
			}
		} else
			put_arguments_nn_b (asize,0);
	}
}

static void GenABCInstructions (Instructions ilist)
{
	for (; ilist; ilist = ilist->instr_next){
		char *instruction_name;
		
		instruction_name=ilist->instr_this;
		
		PutCOutFile ('\n');
		if (instruction_name[0]==':')
			PutSOutFile (&instruction_name[1]);
		else {
			if (instruction_name[0]!='.')
				PutCOutFile ('\t');
			PutSOutFile (instruction_name);
		}
	}
}

static void CallFunction2 (Label label, SymbDef def, Bool isjsr, StateS root_state, Args fun_args, int arity)
{
	int ain,aout,bin,bout;
	Args arg;
	
	ain=0;
	bin=0;
	
	if (fun_args != NULL){
		for (arg = fun_args; arg; arg = arg -> arg_next)
			AddSizeOfState  (arg -> arg_state, &ain, &bin);
	} else
		ain = arity;
	DetermineSizeOfState (root_state, &aout, &bout);

	if (IsSimpleState (root_state) && (root_state.state_kind!=OnB && root_state.state_kind!=StrictRedirection))
		ain++;

	if (label->lab_mod && label->lab_mod==CurrentModule)
		label->lab_mod = NULL;

	label->lab_pref = s_pref;

	if (def->sdef_kind==IMPRULE){
		if ((def->sdef_mark & SDEF_INLINE_IS_CONSTRUCTOR)!=0){
			generate_is_constructor (def->sdef_rule);
			if (!isjsr)
				GenRtn (aout, bout, root_state);
			return;
		} else if (IsInlineFromCurrentModule (def)){
			Instructions instruction, last, first, next;

			instruction=def->sdef_rule->rule_alts->alt_rhs_code->co_instr;
			instruction=instruction->instr_next;
			first=instruction;

			last=NULL;
			for (;(next=instruction->instr_next)!=NULL;instruction=next)
				last=instruction;

			last->instr_next=NULL;
			GenInstructions (first);
			last->instr_next=instruction;

			if (!isjsr)
				GenRtn (aout, bout, root_state);
			return;
		}
	} else if ((def->sdef_mark & SDEF_DEFRULE_ABC_CODE)!=0 && (def->sdef_kind==SYSRULE || def->sdef_kind==DEFRULE)){
		GenABCInstructions (def->sdef_abc_code);
		if (!isjsr)
			GenRtn (aout, bout, root_state);
		return;
	}

	GenDStackLayout (ain, bin, fun_args);
	if (isjsr){
		GenJsr (label);
		GenOStackLayoutOfState (aout, bout, root_state);
	} else
		GenJmp (label);
}

void CallFunction (Label label, SymbDef def, Bool isjsr, Node root)
{
	if (def->sdef_arfun<NoArrayFun)
		CallArrayFunction (def,isjsr,&root->node_state);
	else
		CallFunction2 (label, def, isjsr, root->node_state, root->node_arguments, root->node_arity);
}

void CallFunction1 (Label label, SymbDef def, StateS root_state, Args fun_args, int arity)
{
	CallFunction2 (label, def, True, root_state, fun_args, arity);
}

static void GenArraySize (Label elemdesc, int asize, int bsize)
{
	put_instruction_ (Ipush_arraysize);
	GenLabel (elemdesc);
	put_arguments_nn_b (asize, bsize);
}

static void GenArraySelect (Label elemdesc, int asize, int bsize)
{
	put_instruction_ (Iselect);
	GenLabel (elemdesc);
	put_arguments_nn_b (asize, bsize);
}

static void GenArrayUpdate (Label elemdesc, int asize, int bsize)
{
	put_instruction_ (Iupdate);
	GenLabel (elemdesc);
	put_arguments_nn_b (asize, bsize);	
}

static void GenArrayReplace (Label elemdesc, int asize, int bsize)
{
	put_instruction_ (Ireplace);
	GenLabel (elemdesc);
	put_arguments_nn_b (asize, bsize);
}

#if CLEAN2
static int CaseFailNumber;
#endif

void CallArrayFunction (SymbDef array_def,Bool is_jsr,StateP node_state_p)
{
	LabDef elem_desc;
	int asize, bsize;
	Bool elem_is_lazy;
	StateS array_state;
	ArrayFunKind fkind;
	StateP function_state_p;
	
	fkind = (ArrayFunKind)array_def->sdef_arfun;

	switch (array_def->sdef_kind)
	{
		case DEFRULE:
		case SYSRULE:
			function_state_p = array_def->sdef_rule_type->rule_type_state_p;
			break;
		case IMPRULE:
			function_state_p = array_def->sdef_rule->rule_state_p;
			break;
		default:
			error_in_function ("CallArrayFunction");
			break;
	}

	switch (fkind){
		case CreateArrayFun:
		case _CreateArrayFun:
			array_state = function_state_p[-1];
			break;
	 	case _UnqArraySelectNextFun:
		case _UnqArraySelectLastFun:
		case _ArrayUpdateFun:
			if (function_state_p[0].state_type==TupleState)
				array_state=function_state_p[0].state_tuple_arguments[0];
			else
				error_in_function ("CallArrayFunction");
			break;
		default:
			array_state = function_state_p[0];
	}

	if (array_state.state_type == ArrayState){
		StateS elem_state = array_state.state_array_arguments [0];

		if (array_state.state_mark & STATE_PACKED_ARRAY_MASK){
			elem_desc.lab_mod		= NULL;
			elem_desc.lab_pref		= no_pref;
			elem_desc.lab_issymbol	= False;
			elem_desc.lab_post		= 0;

			if (elem_state.state_object==IntObj)
				elem_desc.lab_name = "INT32";
			else if (elem_state.state_object==RealObj)
				elem_desc.lab_name = "REAL32";
			else
				error_in_function ("CallArrayFunction");

			asize = 0;
			bsize = 1;
		} else {
			DetermineArrayElemDescr (elem_state, & elem_desc);
			DetermineSizeOfState	(elem_state, & asize, & bsize);
		}

		elem_is_lazy = elem_state.state_type==SimpleState && elem_state.state_kind==OnA;
	} else
		error_in_function ("CallArrayFunction");

	switch (fkind){
		case CreateArrayFun:
			put_instruction_ ("create_array");
			GenLabel (&elem_desc);
			put_arguments_nn_b (asize,bsize);
			break;
		case _CreateArrayFun:
			put_instruction_ ("create_array_");
			GenLabel (&elem_desc);
			put_arguments_nn_b (asize,bsize);
			break;
		case ArraySelectFun:
			GenArraySelect (&elem_desc,asize,bsize);
			if (elem_is_lazy){
				if (is_jsr)
					GenJsrEval (0);
				else {
					GenJmpEval ();
					return;
				}
			}
			break;
		case UnqArraySelectFun:
#ifdef OBSERVE_ARRAY_SELECTS_IN_PATTERN
			if (! (node_state_p->state_type==TupleState
				&& node_state_p->state_tuple_arguments[1].state_type==SimpleState
				&& node_state_p->state_tuple_arguments[1].state_kind==Undefined))
			{
				GenPushA (0);
			}
			GenArraySelect (&elem_desc,asize,bsize);
			break;
#endif
		case _UnqArraySelectFun:
			GenPushA (0);
			GenArraySelect (&elem_desc,asize,bsize);
			break;
		case _UnqArraySelectNextFun:
		case _UnqArraySelectLastFun:
		{
			int record_or_array_a_size,record_or_array_b_size;
			
			if (node_state_p->state_type!=TupleState)
				error_in_function ("CallArrayFunction");

			DetermineSizeOfState (node_state_p->state_tuple_arguments[1],&record_or_array_a_size,&record_or_array_b_size);
			
			if (record_or_array_b_size>0){
				int i;
				
				GenPushB (record_or_array_b_size);
				
				for (i=record_or_array_b_size; i>=0; --i)
					GenUpdateB (i,i+1);
				
				GenPopB (1);
			}

			GenArraySelect (&elem_desc,asize,bsize);
			break;
		}
		case _ArrayUpdateFun:
		{
			int i,result_a_size,result_b_size;
			
			DetermineSizeOfState (*node_state_p,&result_a_size,&result_b_size);

			if (asize!=0){
				for (i=0; i<asize; ++i)
					GenPushA (result_a_size+asize);
			
				for (i=result_a_size-1; i>=0; --i)
					GenUpdateA (i+asize+1,i+asize+1+asize);

				for (i=asize-1; i>=0; --i)
					GenUpdateA (i,i+1+asize);

				GenPopA (asize);
			}			
			
			if (result_b_size!=0){
				int b_size_with_index;

				b_size_with_index=bsize+1;

				for (i=0; i<b_size_with_index; ++i)
					GenPushB (result_b_size+b_size_with_index-1);
				
				for (i=result_b_size-1; i>=0; --i)
					GenUpdateB (i+b_size_with_index,i+b_size_with_index+b_size_with_index);

				for (i=b_size_with_index-1; i>=0; --i)
					GenUpdateB (i,i+b_size_with_index);

				GenPopB (b_size_with_index);				
			}

			GenArrayUpdate (&elem_desc,asize,bsize);
							
			for (i=0; i<result_a_size; ++i)
				GenKeep (0,i+1);
			
			GenPopA (1);

			break;
		}
		case ArrayUpdateFun:
			GenArrayUpdate (& elem_desc, asize, bsize);
			break;
		case ArrayReplaceFun:
			GenArrayReplace (& elem_desc, asize, bsize);
			break;
		case ArraySizeFun:
			GenArraySize (& elem_desc, asize, bsize);
			break;
		case UnqArraySizeFun:
			GenPushA (0);
			GenArraySize (& elem_desc, asize, bsize);
			break;
	}
	
	if (! is_jsr){
		DetermineSizeOfState (*node_state_p,&asize,&bsize);
		GenRtn (asize,bsize,*node_state_p);
	}	
}

void GenNewContext (Label contlab, int offset)
{
	put_instruction_ ("set_entry");
	GenLabel (contlab);
	put_arguments_n_b (offset);
}

void GenSetDefer (int offset)
{
	put_instruction ("set_defer");
	put_arguments_n_b (offset);
}

void GenReplArgs (int arity, int nrargs)
{
	if (nrargs > 0){
		put_instructionb (repl_args);
		put_arguments_nn_b (arity,nrargs);
	} else
		GenPopA (1);
}

void GenReplArg (int arity, int argnr)
{
	put_instructionb (repl_arg);
	put_arguments_nn_b (arity,argnr);
}

void GenPushArgs (int offset, int arity, int nrargs)
{
	if (nrargs > 0){
		put_instructionb (push_args);
		put_arguments_nnn_b (offset,arity,nrargs);
	}
}

void GenPushArgsU (int offset, int arity, int nrargs)
{
	if (nrargs > 0){
		put_instructionb (push_args_u);
		put_arguments_nnn_b (offset,arity,nrargs);
	}
}

void GenPushArg (int offset, int arity, int argnr)
{
	put_instructionb (push_arg);
	put_arguments_nnn_b (offset,arity,argnr);
}

void GenPushRArgs (int offset, int nr_a_args, int nr_b_args)
{
	if (nr_a_args + nr_b_args > 0){
		put_instructionb (push_r_args);
		put_arguments_nnn_b (offset,nr_a_args,nr_b_args);
	}
}

void GenPushRArgsU (int offset,int n_a_args,int n_b_args)
{
	if (n_a_args + n_b_args > 0){
		put_instructionb (push_r_args_u);
		put_arguments_nnn_b (offset,n_a_args,n_b_args);
	}
}

void GenPushRArgA (int offset,int tot_nr_a_args,int tot_nr_b_args,int args_nr,int nr_a_args)
{
	if (nr_a_args > 0){
		put_instructionb (push_r_args_a);
		put_arguments_nnnnn_b (offset,tot_nr_a_args,tot_nr_b_args,args_nr,nr_a_args);
	}
}

void GenPushRArgB (int offset,int tot_nr_a_args,int tot_nr_b_args,int args_nr,int nr_b_args)
{
	if (nr_b_args > 0){
		put_instructionb (push_r_args_b);
		put_arguments_nnnnn_b (offset,tot_nr_a_args,tot_nr_b_args,args_nr,nr_b_args);
	}
}

void GenPushRArgU (int offset,int tot_nr_a_args,int tot_nr_b_args,int args_a_nr,int nr_a_args,int args_b_nr,int nr_b_args)
{
	put_instructionb (push_r_arg_u);
	put_arguments_nnn_b (offset,tot_nr_a_args,tot_nr_b_args);
	put_arguments_nnnn_b (args_a_nr,nr_a_args,args_b_nr,nr_b_args);
}

void GenReplRArgs (int nr_a_args, int nr_b_args)
{
	if (nr_a_args +  nr_b_args > 0){
		put_instructionb (repl_r_args);
		put_arguments_nn_b (nr_a_args,nr_b_args);
	} else
		GenPopA (1);
}

void GenReplRArgA (int tot_nr_a_args, int tot_nr_b_args, int args_nr, int nr_a_args)
{
	if (nr_a_args > 0){
		put_instructionb (repl_r_args_a);
		put_arguments_nnnn_b (tot_nr_a_args,tot_nr_b_args,args_nr,nr_a_args);
	} else
		GenPopA (1);
}

void GenPushNode (Label contlab, int arity)
{
	put_instruction_b (push_node);
	GenLabel (contlab);
	put_arguments_n_b (arity);
}

void GenPushNodeU (Label contlab,int a_size,int b_size)
{
	put_instruction_b (push_node_u);
	GenLabel (contlab);
	put_arguments_nn_b (a_size,b_size);
}

void GenFill (Label symblab,int arity,Label contlab,int offset,FillKind fkind)
{
	TreatWaitListBeforeFill (offset, fkind);

	put_instruction_b (fill);
	
	if (!symblab->lab_issymbol || DescriptorNeeded (symblab->lab_symbol))
		GenDescriptorOrNodeEntryLabel (symblab);
	else
		PutSOutFile (empty_lab.lab_name);
	
	put_arguments_n_b (arity);
	
	PutCOutFile (' ');
	GenDescriptorOrNodeEntryLabel (contlab);
	
	put_arguments_n_b (offset);

	if (arity < 0)
		arity = 1;
	TreatWaitListAfterFill (offset-arity, fkind);
}

void GenFillU (Label symblab,int a_size,int b_size,Label contlab,int offset)
{
	put_instruction_ (Ifill_u);
	
	if (!symblab->lab_issymbol || DescriptorNeeded (symblab->lab_symbol))
		GenDescriptorOrNodeEntryLabel (symblab);
	else
		PutSOutFile (empty_lab.lab_name);
	
	put_arguments_nn_b (a_size,b_size);
	
	PutCOutFile (' ');
	GenDescriptorOrNodeEntryLabel (contlab);
	
	put_arguments_n_b (offset);
}

void GenFillcp (Label symblab,int arity,Label contlab,int offset,char bits[])
{
	put_instruction_b (fillcp);
	
	if (!symblab->lab_issymbol || DescriptorNeeded (symblab->lab_symbol))
		GenDescriptorOrNodeEntryLabel (symblab);
	else
		PutSOutFile (empty_lab.lab_name);
	
	put_arguments_n_b (arity);
	
	PutCOutFile (' ');
	GenDescriptorOrNodeEntryLabel (contlab);
	
	put_arguments_n_b (offset);

	Put_SOutFile (bits);
}

void GenFillcpU (Label symblab,int a_size,int b_size,Label contlab,int offset,char bits[])
{
	put_instruction_b (fillcp_u);
	
	if (!symblab->lab_issymbol || DescriptorNeeded (symblab->lab_symbol))
		GenDescriptorOrNodeEntryLabel (symblab);
	else
		PutSOutFile (empty_lab.lab_name);
		
	put_arguments_nn_b (a_size,b_size);

	PutCOutFile (' ');
	GenDescriptorOrNodeEntryLabel (contlab);
	
	put_arguments_n_b (offset);

	Put_SOutFile (bits);
}

void GenFillh (Label symblab, int arity, int offset, FillKind fkind)
{
	TreatWaitListBeforeFill (offset, fkind);

	put_instruction_b (fillh);
	
	if (!symblab->lab_issymbol || DescriptorNeeded (symblab->lab_symbol))
		GenDescriptorOrNodeEntryLabel (symblab);
	else
		PutSOutFile (empty_lab.lab_name);
	
	put_arguments_nn_b (arity,offset);

	if (arity < 0)
		arity = 1;
	TreatWaitListAfterFill (offset-arity, fkind);
}

void GenFill1 (Label symblab,int arity,int offset,char bits[])
{
	put_instruction_ (Ifill1);
	
	if (!symblab->lab_issymbol || DescriptorNeeded (symblab->lab_symbol))
		GenLabel (symblab);
	else
		PutSOutFile (empty_lab.lab_name);
	
	put_arguments_nn_b (arity,offset);
	Put_SOutFile (bits);
}

void GenFill2 (Label symblab,int arity,int offset,char bits[])
{	
	put_instruction_ (Ifill2);
	GenLabel (symblab);
	put_arguments_nn_b (arity,offset);
	Put_SOutFile (bits);
}

void GenFill3 (Label symblab,int arity,int offset,char bits[])
{	
	put_instruction_ (Ifill3);
	GenLabel (symblab);
	put_arguments_nn_b (arity,offset);
	Put_SOutFile (bits);
}

void GenBuild (Label symblab,int arity,Label contlab)
{
	put_instructionb (build);

	PutCOutFile (' ');
	if (!symblab->lab_issymbol || DescriptorNeeded (symblab->lab_symbol))
		GenDescriptorOrNodeEntryLabel (symblab);
	else
		PutSOutFile (empty_lab.lab_name);
	
	put_arguments_n_b (arity);
	
	PutCOutFile (' ');
	GenDescriptorOrNodeEntryLabel (contlab);
}

void GenBuildh (Label symblab,int arity)
{
	put_instructionb (buildh);
	
	PutCOutFile (' ');
	if (!symblab->lab_issymbol || DescriptorNeeded (symblab->lab_symbol))
		GenLabel (symblab);
	else
		PutSOutFile (empty_lab.lab_name);
	
	put_arguments_n_b (arity);
}

void GenBuildPartialFunctionh (Label symblab,int arity)
{
	put_instructionb (buildh);
	
	PutCOutFile (' ');
	if (!symblab->lab_issymbol || DescriptorNeeded (symblab->lab_symbol))
		GenDescriptorOrNodeEntryLabel (symblab);
	else
		PutSOutFile (empty_lab.lab_name);
	
	put_arguments_n_b (arity);
}

void GenBuildU (Label symblab,int a_size,int b_size,Label contlab)
{
	put_instruction (Ibuild_u);
	
	PutCOutFile (' ');
	if (!symblab->lab_issymbol || DescriptorNeeded (symblab->lab_symbol))
		GenDescriptorOrNodeEntryLabel (symblab);
	else
		PutSOutFile (empty_lab.lab_name);
	
	put_arguments_nn_b (a_size,b_size);
	
	PutCOutFile (' ');
	GenDescriptorOrNodeEntryLabel (contlab);
}

void GenBuildArrayPop (void)
{
	GenBuildh (& BasicDescriptors [ArrayObj], 1);
}

void GenBuildArray (int argoffset)
{
	GenPushA (argoffset);
	GenBuildArrayPop();
}

void GenBuildString (SymbValue val)
{
	put_instruction_ (IbuildAC);
	PutSOutFile (val.val_string);
}

void GenPushZ (SymbValue val)
{
	put_instruction_ (IpushZ);
	PutSOutFile (val.val_string);
}

void GenPushZR (SymbValue val)
{
	put_instruction_ (IpushZR);
	PutSOutFile (val.val_string);
}

static void GenFieldLabel (Label label,char *record_name)
{
	SymbDef def;
	
	def = (SymbDef) label->lab_name;
		
	if (label->lab_mod){
		put_label_module_prefix_name (label->lab_mod,label->lab_pref,record_name);
		PutdotSOutFile (def->sdef_name);
	} else if (ExportLocalLabels){
		put_label_module_prefix_name (CurrentModule,label->lab_pref,record_name);
		PutdotSOutFile (def->sdef_name);
	} else if (DoDebug){
		PutSSdotSOutFile (label->lab_pref,record_name,def->sdef_name);
		if (def->sdef_kind==IMPRULE)
			PutdotUOutFile (def->sdef_number);
	} else if (def->sdef_number==0)
		PutSSOutFile (label->lab_pref,def->sdef_name);
	else if (label->lab_pref[0] == '\0')
		PutSUOutFile (LOCAL_D_PREFIX,def->sdef_number);
	else
		PutSUOutFile (label->lab_pref,def->sdef_number);
}

void GenBuildFieldSelector (Label symblab,Label contlab,char *record_name,int arity)
{
	put_instruction_b (build);

	if (!symblab->lab_issymbol || DescriptorNeeded (symblab->lab_symbol))
		GenFieldLabel (symblab,record_name);
	else
		PutSOutFile (empty_lab.lab_name);

	put_arguments_n_b (arity);

	PutCOutFile (' ');
	GenFieldLabel (contlab,record_name);
}

void GenFieldLabelDefinition (Label label,char *record_name)
{
	PutSOutFile ("\n");
	GenFieldLabel (label,record_name);
}

void GenFillFieldSelector (Label symblab,Label contlab,char *record_name,int arity,int offset,FillKind fkind)
{
	TreatWaitListBeforeFill (offset,fkind);
	
	put_instruction_b (fill);

	if (!symblab->lab_issymbol || DescriptorNeeded (symblab->lab_symbol))
		GenFieldLabel (symblab,record_name);
	else
		PutSOutFile (empty_lab.lab_name);

	put_arguments_n_b (arity);

	PutCOutFile (' ');
	GenFieldLabel (contlab,record_name);

	put_arguments_n_b (offset);

	TreatWaitListAfterFill (offset-1,fkind);
}

void GenFillR (Label symblab,int nr_a_args,int nr_b_args,int rootoffset,int a_offset,int b_offset,FillKind fkind,Bool pop_args)
{
	TreatWaitListBeforeFill (rootoffset, fkind);
	
	put_instruction_ (Ifill_r);
	
	if (! symblab->lab_issymbol || DescriptorNeeded (symblab->lab_symbol))
		GenLabel (symblab);
	else
		PutSOutFile (empty_lab.lab_name);

	if (nr_a_args==0)
		a_offset=0;
	if (nr_b_args==0)
		b_offset=0;
	
	put_arguments_nnnnn_b (nr_a_args,nr_b_args,rootoffset,a_offset,b_offset);
	
	if (pop_args){
		GenPopA (nr_a_args);
		GenPopB (nr_b_args);
		TreatWaitListAfterFill (rootoffset-nr_a_args, fkind);		
	} else
		TreatWaitListAfterFill (rootoffset, fkind);
}

void GenFill1R (Label symblab,int n_a_args,int n_b_args,int rootoffset,char bits[])
{	
	put_instruction_ (Ifill1_r);
	
	if (! symblab->lab_issymbol || DescriptorNeeded (symblab->lab_symbol))
		GenLabel (symblab);
	else
		PutSOutFile (empty_lab.lab_name);
	
	put_arguments_nnn_b (n_a_args,n_b_args,rootoffset);
	Put_SOutFile (bits);
}

void GenFill2R (Label symblab,int n_a_args,int n_b_args,int rootoffset,char bits[])
{	
	put_instruction_ (Ifill2_r);
	
	if (! symblab->lab_issymbol || DescriptorNeeded (symblab->lab_symbol))
		GenLabel (symblab);
	else
		PutSOutFile (empty_lab.lab_name);
	
	put_arguments_nnn_b (n_a_args,n_b_args,rootoffset);
	Put_SOutFile (bits);
}

void GenFill3R (Label symblab,int n_a_args,int n_b_args,int rootoffset,char bits[])
{	
	put_instruction_ (Ifill3_r);
	
	if (! symblab->lab_issymbol || DescriptorNeeded (symblab->lab_symbol))
		GenLabel (symblab);
	else
		PutSOutFile (empty_lab.lab_name);
	
	put_arguments_nnn_b (n_a_args,n_b_args,rootoffset);
	Put_SOutFile (bits);
}

void GenBuildhr (Label symblab,int nr_a_args,int nr_b_args)
{
	put_instruction_ (Ibuildhr);
	
	if (!symblab->lab_issymbol || DescriptorNeeded (symblab->lab_symbol))
		GenLabel (symblab);
	else
		PutSOutFile (empty_lab.lab_name);

	put_arguments_nn_b (nr_a_args,nr_b_args);
}

void GenBuildR (Label symblab,int nr_a_args,int nr_b_args,int a_offset,int b_offset)
{
	put_instruction_ (Ibuild_r);
	
	if (!symblab->lab_issymbol || DescriptorNeeded (symblab->lab_symbol))
		GenLabel (symblab);
	else
		PutSOutFile (empty_lab.lab_name);

	if (nr_a_args==0)
		a_offset=0;
	if (nr_b_args==0)
		b_offset=0;

	put_arguments_nnnn_b (nr_a_args,nr_b_args,a_offset,b_offset);
}

void GenFillFromA (int src, int dst, FillKind fkind)
{
	if (src == dst)
		return;
	
	TreatWaitListBeforeFill (dst, fkind);
	put_instructionb (fill_a);
	put_arguments_nn_b (src,dst);
	TreatWaitListAfterFill (dst, fkind);
}

void GenFillArrayAndPop (int rootoffset, FillKind fkind)
{
	GenFillh (&BasicDescriptors [ArrayObj], 1, rootoffset, fkind);
}

void GenFillArray (int argoffset, int rootoffset, FillKind fkind)
{
	GenPushA (argoffset);
	GenFillh (&BasicDescriptors [ArrayObj], 1, rootoffset+1, fkind);
}

void GenPushArray (int rootoffset)
{
	put_instruction (Ipush_array);
	put_arguments_n_b (rootoffset);
}

void GenRtn (int asize, int bsize, StateS resultstate)
{
	GenDStackLayoutOfState (asize, bsize, resultstate);
	put_instructionb (rtn);
}

void GenPushA (int offset)
{
	if (offset<0)
		error_in_function ("GenPushA");

	put_instructionb (push_a);
	put_arguments_n_b (offset);
}

void GenPushB (int offset)
{
	if (offset<0)
		error_in_function ("GenPushB");

	put_instructionb (push_b);
	put_arguments_n_b (offset);
}

void GenJsrEval (int offset)
{
	put_instructionb (jsr_eval);
	put_arguments_n_b (offset);
}

void GenJsrAp (int n_args)
{
	put_instructionb (jsr_ap);
	put_arguments_n_b (n_args);
}

void GenJsrI (int n_args)
{
	put_instructionb (jsr_i);
	put_arguments_n_b (n_args);
}

void GenJmpEval (void)
{
	put_instruction (Ijmp_eval);
}

void GenJmpAp (int n_args)
{
	put_instructionb (jmp_ap);
	put_arguments_n_b (n_args);
}

void GenJmpApUpd (int n_args)
{
	put_instructionb (jmp_ap_upd);
	put_arguments_n_b (n_args);
}

void GenJmpI (int n_args)
{
	put_instructionb (jmp_i);
	put_arguments_n_b (n_args);
}

void GenJmpNotEqZ (SymbValue val,Label tolab)
{
	put_instruction (Ijmp_not_eqZ);
	Put_SOutFile (val.val_string);
	PutCOutFile (' ');
	GenLabel (tolab);
}

void GenJmpUpd (Label tolab)
{
	put_instruction_b (jmp_upd);
	GenLabel (tolab);
}

void GenPopA (int nr)
{
	if (nr > 0){
		put_instructionb (pop_a);
		put_arguments_n_b (nr);
	}
}

void GenPopB (int nr)
{
	if (nr > 0){
		put_instructionb (pop_b);
		put_arguments_n_b (nr);
	}
}

void GenEqDesc (Label symblab,int arity,int offset)
{
	put_instruction_b (eq_desc);
	GenLabel (symblab);
	put_arguments_nn_b (arity,offset);
}

void GenEqD_b (Label symblab,int arity)
{
	put_instruction_b (eqD_b);
	GenLabel (symblab);
	put_arguments_n_b (arity);
}

void GenExitFalse (Label to)
{
	put_instruction_ ("exit_false");
	GenLabel (to);
}

void GenJmpFalse (Label to)
{
	put_instruction_b (jmp_false);
	GenLabel (to);
}

void GenJmpTrue (Label to)
{
	put_instruction_b (jmp_true);
	GenLabel (to);
}

void GenJmp (Label tolab)
{
	put_instruction_b (jmp);
	GenLabel (tolab);
}

void GenJmpD (Label symblab,int arity,SymbolP compare_symbol,SymbolP symbol1,SymbolP symbol2,Label to1,Label to2)
{
	put_instruction_ ("jmpD");

	if (symbol1==compare_symbol){
		PutCOutFile ('e');
		PutCOutFile (symbol2<compare_symbol ? 'b' : 'a');
	} else if (symbol2==compare_symbol){
		PutCOutFile (symbol1<compare_symbol ? 'b' : 'a');
		PutCOutFile ('e');
	} else if (symbol1<symbol2){
		PutCOutFile ('b');
		PutCOutFile ('a');
	} else {
		PutCOutFile ('a');
		PutCOutFile ('b');
	}
	PutCOutFile (' ');
	GenLabel (symblab);
	put_arguments_n_b (arity);
	PutCOutFile (' ');
	GenLabel (to1);
	PutCOutFile (' ');
	GenLabel (to2);
}

void GenJsr (Label tolab)
{
	put_instruction_b (jsr);
	GenLabel (tolab);
}

void GenCreate (int arity)
{
	put_instruction (Icreate);
	if (arity != -1)
		put_arguments_n_b (arity);
}

void GenDumpString (char *str)
{
	put_instruction (Iprint);
	put_space_quoted_string (str);
	put_instruction (Ihalt);
}

void GenLabelDefinition (Label lab)
{
	if (lab){
		PutCOutFile ('\n');
		GenLabel (lab);
	}
}

void GenNodeEntryLabelDefinition (Label lab)
{
	PutCOutFile ('\n');
	GenDescriptorOrNodeEntryLabel (lab);
}

void GenUpdateA (int src, int dst)
{
	if (src != dst){
		put_instructionb (update_a);
		put_arguments_nn_b (src,dst);
	}
}

void GenUpdatePopA (int src, int dst)
{
	if (src!=dst){
		if (dst!=0){
			put_instructionb (updatepop_a);
			put_arguments_nn_b (src,dst);
		} else {
			put_instructionb (update_a);
			put_arguments_nn_b (src,dst);
		}
	} else
		if (dst > 0){
			put_instructionb (pop_a);
			put_arguments_n_b (dst);
		}
}

void GenUpdateB (int src, int dst)
{
	if (src != dst){
		put_instructionb (update_b);
		put_arguments_nn_b (src,dst);
	}
}

void GenUpdatePopB (int src, int dst)
{
	if (src!=dst){
		if (dst!=0){
			put_instructionb (updatepop_b);
			put_arguments_nn_b (src,dst);
		} else {
			put_instructionb (update_b);
			put_arguments_nn_b (src,dst);
		}
	} else
		if (dst > 0) {
			put_instructionb (pop_b);
			put_arguments_n_b (dst);
		}
}

void GenHalt (void)
{
	put_instruction (Ihalt);
}

void GenSetRedId (int offset)
{
	put_instruction ("set_red_id");
	put_arguments_n_b (offset);
}

void GenNewParallelReducer (int offset, char *reducer_code)
{
	put_instruction ("new_ext_reducer");
	Put_SOutFile (reducer_code);
	put_arguments_n_b (offset);
}

void GenNewContInterleavedReducer (int offset)
{
	put_instruction ("new_int_reducer");
	PutSOutFile (" _cont_reducer");
	put_arguments_n_b (offset);
	put_instruction ("force_cswitch");
}

void GenNewInterleavedReducer (int offset, char *reducer_code)
{
	put_instruction ("new_int_reducer");
	Put_SOutFile (reducer_code);
	put_arguments_n_b (offset);
}

void GenSendGraph (char *code, int graphoffs, int chanoffs)
{
	put_instruction ("send_graph");
	Put_SOutFile (code);
	put_arguments_nn_b (graphoffs, chanoffs);
}

void GenCreateChannel (char *code)
{
	put_instruction_ ("create_channel");
	PutSOutFile (code);
}

void GenNewP (void)
{
	put_instruction ("newP");
}

void SetContinue (int offset)
{
	put_instruction ("set_continue");
	put_arguments_n_b (offset);
}

void SetContinueOnReducer (int offset)
{
	put_instruction ("set_continue2");
	put_arguments_n_b (offset);
}

void GenGetNodeArity (int offset)
{
	put_instruction (Iget_node_arity);
	put_arguments_n_b (offset);
}

static void GenGetDescArity (int offset)
{
	put_instruction (Iget_desc_arity);
	put_arguments_n_b (offset);
}

void GenPushArgB (int offset)
{
	put_instruction (Ipush_arg_b);
	put_arguments_n_b (offset);
}

extern char *current_imported_module; /* from statesgen.c */

void GenImpRecordDesc (char *module_name,char *record_name)
{
	if (current_imported_module!=module_name){
		current_imported_module = module_name;
		GenImpMod (module_name);
	}

	put_directiveb (impdesc);
	put_space_label_module_r_name (module_name,record_name);
}

void GenImport (SymbDef sdef)
{
	if (DoStackLayout){	
		char *name;
		
		name = sdef->sdef_name;

		switch (sdef->sdef_kind){
			case DEFRULE:
			case SYSRULE:
				if (sdef->sdef_mark & (SDEF_USED_CURRIED_MASK | SDEF_USED_LAZILY_MASK)){
					put_directiveb (impdesc);
					put_space_label_module_d_name (sdef->sdef_module,name);
				}
				if (sdef->sdef_mark & SDEF_USED_STRICTLY_MASK && sdef->sdef_arfun==NoArrayFun){
					put_directiveb (implab);
					put_space_label_module_s_name (sdef->sdef_module,name);
				}
				break;
			case FIELDSELECTOR:
				if (sdef->sdef_mark & SDEF_USED_LAZILY_MASK){
					char *record_name;
	
					record_name	= sdef->sdef_type->type_symbol->ts_def->sdef_name;
	
					put_directiveb (impdesc);
					put_space_label_module_d_name (sdef->sdef_module,record_name);
					PutdotSOutFile (name);

					put_directiveb (implab);
					put_space_label_module_n_name (sdef->sdef_module,record_name);
					PutdotSOutFile (name);
				
					if (sdef->sdef_calledwithrootnode){
						put_space_label_module_ea_name (sdef->sdef_module,record_name);
						PutdotSOutFile (name);
					} else if (sdef->sdef_returnsnode)
						PutSOutFile (" _");
				}
				return;
			case RECORDTYPE:
				if (sdef->sdef_mark & (SDEF_USED_STRICTLY_MASK | SDEF_USED_LAZILY_MASK)){
					GenImpRecordDesc (sdef->sdef_module,name);
					
					sdef->sdef_mark |= SDEF_RECORD_R_LABEL_IMPORTED_MASK;
				}
				
				if (!sdef->sdef_strict_constructor)
					return;

				if (sdef->sdef_mark & SDEF_USED_LAZILY_MASK){
					put_directiveb (impdesc);
					put_space_label_module_record_d_name (sdef->sdef_module,name);
					put_directiveb (implab);
					put_space_label_module_record_n_name (sdef->sdef_module,name);
				}
				return;
			case CONSTRUCTOR:
				if ((sdef->sdef_mark & (SDEF_USED_STRICTLY_MASK | SDEF_USED_LAZILY_MASK | SDEF_USED_CURRIED_MASK))==0)
					return;
				
				if (!sdef->sdef_strict_constructor){
					put_directiveb (impdesc);
					put_space_label_module_d_name (sdef->sdef_module,name);
					return;
				}

				if (sdef->sdef_mark & (SDEF_USED_STRICTLY_MASK | SDEF_USED_LAZILY_MASK)){
					put_directiveb (impdesc);
					put_space_label_module_constructor_r_name (sdef->sdef_module,name);
				}

				if (sdef->sdef_mark & (SDEF_USED_LAZILY_MASK | SDEF_USED_CURRIED_MASK)){
					put_directiveb (impdesc);
					put_space_label_module_d_name (sdef->sdef_module,name);
				}
				break;
			default:
				return;
		}

		if (sdef->sdef_mark & SDEF_USED_LAZILY_MASK){
			put_directiveb (implab);
			put_space_label_module_n_name (sdef->sdef_module,name);
			if ((sdef->sdef_calledwithrootnode || sdef->sdef_returnsnode) && 
				!(sdef->sdef_kind==CONSTRUCTOR && !sdef->sdef_strict_constructor))
			{
				if (sdef->sdef_calledwithrootnode)
					put_space_label_module_ea_name (sdef->sdef_module,name);
				else
					PutSOutFile (" _");
			}
		}
	}	
}

void GenExportStrictAndEaEntry (SymbDef sdef)
{
	char *name;
	
	name = sdef->sdef_name;
	
	put_directive (Dexport);
	put_space_label_module_s_name (CurrentModule,name);

	if (sdef->sdef_calledwithrootnode){
		put_directive (Dexport);
		put_space_label_module_ea_name (CurrentModule,name);
	}
}

void GenExportFieldSelector (SymbDef sdef)
{
	char *name;
	char *record_name;
	
	name = sdef->sdef_name;
	
	record_name=sdef->sdef_type->type_symbol->ts_def->sdef_name;

	put_directive (Dexport);
	put_space_label_module_d_name (CurrentModule,record_name);
	PutdotSOutFile (name);
	put_directive (Dexport);
	put_space_label_module_n_name (CurrentModule,record_name);
	PutdotSOutFile (name);

	if (sdef->sdef_calledwithrootnode){
		put_directive (Dexport);
		put_space_label_module_ea_name (CurrentModule,record_name);
		PutdotSOutFile (name);
	}
}

void GenExportEaEntry (SymbDef sdef)
{
	if (sdef->sdef_calledwithrootnode){
		put_directive (Dexport);
		put_space_label_module_ea_name (CurrentModule,sdef->sdef_name);
	}
}

void GenExportEuEntry (SymbDef sdef)
{
	if (sdef->sdef_calledwithrootnode){
		put_directive (Dexport);
		put_space_label_module_eu_name (CurrentModule,sdef->sdef_name);
	}
}

void GenDAStackLayout (int asize)
{
	if (DoStackLayout){
		put_directiveb (d);
		put_arguments_nn_b (asize,0);
	}
}

void GenOAStackLayout (int asize)
{
	if (DoStackLayout){
		put_directiveb (o);
		put_arguments_nn_b (asize,0);
	}
}

void GenDStackLayoutOfStates (int asize,int bsize,int n_states,StateP state_p)
{
	if (DoStackLayout){
		put_directiveb (d);
		if (bsize > 0){
			int i;
	
			put_arguments_nn_b (asize,bsize);
			PutCOutFile (' ');

			for (i=0; i<n_states; ++i)
				GenBStackElems (state_p[i]);
		} else
			put_arguments_nn_b (asize,0);
	}
}

void GenOStackLayoutOfStates (int asize,int bsize,int n_states,StateP state_p)
{
	if (DoStackLayout){
		put_directiveb (o);
		if (bsize > 0){
			int i;
			
			put_arguments_nn_b (asize,bsize);
			PutCOutFile (' ');

			for (i=0; i<n_states; ++i)
				GenBStackElems (state_p[i]);
		} else
			put_arguments_nn_b (asize,0);
	}
}

void GenDStackLayoutOfState (int asize, int bsize, StateS resultstate)
{
	if (DoStackLayout){
		put_directiveb (d);
		if (bsize > 0){
			put_arguments_nn_b (asize,bsize);
			PutCOutFile (' ');
			GenBStackElems (resultstate);
		} else
			put_arguments_nn_b (asize,0);
	}		
}

void GenOStackLayoutOfState (int asize, int bsize, StateS resultstate)
{
	if (DoStackLayout){
		put_directiveb (o);
		if (bsize > 0){
			put_arguments_nn_b (asize,bsize);
			PutCOutFile (' ');
			GenBStackElems (resultstate);
		} else
			put_arguments_nn_b (asize,0);
	}		
}

void GenJmpEvalUpdate (void)
{
	put_instruction (Ijmp_eval_upd);
}

void GenNodeEntryDirective (int arity,Label label,Label label2)
{
	if (DoStackLayout){
		put_directiveb (n);
		put_arguments_n_b (arity);

		PutCOutFile (' ');
		if (DescriptorNeeded (label->lab_symbol))
			GenDescriptorOrNodeEntryLabel (label);
		else
			PutSOutFile (empty_lab.lab_name);

		if (label2){
			PutCOutFile (' ');
			GenLabel (label2);
		}
#ifdef MEMORY_PROFILING_WITH_N_STRING
		if (DoProfiling && arity>=0 && !DoParallel){
			put_directive (Dn_string);
			put_space_quoted_string (label->lab_symbol->sdef_name);
		}
#endif
	}
}

void GenApplyEntryDirective (int arity,Label label)
{
	put_directiveb (a);
	put_arguments_n_b (arity);
	PutCOutFile (' ');
	GenLabel (label);
}

void GenApplyInstanceEntryDirective (int arity,Label label,Label label2)
{
	put_directiveb (ai);
	put_arguments_n_b (arity);
	PutCOutFile (' ');
	if (label==NULL)
		PutSOutFile (empty_lab.lab_name);
	else
		GenLabel (label);
	PutCOutFile (' ');
	GenLabel (label2);
}

void GenLazyRecordNodeEntryDirective (int arity,Label label,Label label2)
{
	if (DoStackLayout){
		put_directiveb (n);
		put_arguments_n_b (arity);

		PutCOutFile (' ');
		if (DescriptorNeeded (label->lab_symbol))
			GenLabel (label);
		else
			PutSOutFile (empty_lab.lab_name);

		if (label2){
			PutCOutFile (' ');
			GenLabel (label2);
		}

#ifdef MEMORY_PROFILING_WITH_N_STRING
		if (DoProfiling && arity>=0 && !DoParallel){
			put_directive (Dn_string);
			put_space_quoted_string (label->lab_symbol->sdef_name);
		}
#endif
	}
}

void GenNodeEntryDirectiveForLabelWithoutSymbol (int arity,Label label,Label label2)
{
	if (DoStackLayout){
		put_directiveb (n);
		put_arguments_n_b (arity);

		PutCOutFile (' ');
		GenLabel (label);

		if (label2){
			PutCOutFile (' ');
			GenLabel (label2);
		}

#ifdef MEMORY_PROFILING_WITH_N_STRING
		if (DoProfiling && arity>=0 && !DoParallel){
			put_directive (Dn_string);
			put_space_quoted_string (label->lab_name);
		}
#endif
	}
}

void GenNodeEntryDirectiveUnboxed (int a_size,int b_size,Label label,Label label2)
{
	if (DoStackLayout){
		put_directive (Dnu);
		put_arguments_nn_b (a_size,b_size);

		PutCOutFile (' ');
		if (DescriptorNeeded (label->lab_symbol))
			GenDescriptorOrNodeEntryLabel (label);
		else
			PutSOutFile (empty_lab.lab_name);

		if (label2){
			PutCOutFile (' ');
			GenLabel (label2);
		}

# ifdef MEMORY_PROFILING_WITH_N_STRING
		if (DoProfiling && !DoParallel){
			put_directive (Dn_string);
			put_space_quoted_string (label->lab_symbol->sdef_name);
		}
# endif
	}
}

void GenFieldNodeEntryDirective (int arity,Label label,Label label2,char *record_name)
{
	if (DoStackLayout){
		put_directiveb (n);
		put_arguments_n_b (arity);
		
		PutCOutFile (' ');
		if (DescriptorNeeded (label->lab_symbol))
			GenFieldLabel (label,record_name);
		else
			PutSOutFile (empty_lab.lab_name);
		
		if (label2!=NULL){
			PutCOutFile (' ');
			if (label2==&empty_lab)
				PutSOutFile (empty_lab.lab_name);				
			else
				GenFieldLabel (label2,record_name);
		}
	}
}

void GenConstructorDescriptorAndExport (SymbDef sdef)
{
	char *name;
	LabDef *add_argument_label;

	name = sdef->sdef_name;

	if (sdef->sdef_arity>0)
		add_argument_label=&add_arg_lab;
	else
		add_argument_label=&hnf_lab;

	if (sdef->sdef_exported || ExportLocalLabels){
		put_directive (Dexport);
		put_space_label_module_d_name (CurrentModule,name);
		put_directive (Ddesc);
		put_space_label_module_d_name (CurrentModule,name);
	} else if (DoDebug){
		put_directive (Ddesc);
		PutSSOutFile (" " D_PREFIX, name);
	} else {
		put_directive (Ddesc);
		PutSUOutFile (" " LOCAL_D_PREFIX,sdef->sdef_number);
	}
	Put_SOutFile (hnf_lab.lab_name);
	Put_SOutFile (add_argument_label->lab_name);
	put_arguments_n_b (sdef->sdef_arity);
	PutSOutFile (" 0");
	put_space_quoted_string (name);
}

void GenConstructor0DescriptorAndExport (SymbDef sdef,int constructor_n)
{
	char *name;

	name = sdef->sdef_name;

	if (sdef->sdef_exported || ExportLocalLabels){
		put_directive (Dexport);
		put_space_label_module_d_name (CurrentModule,name);
		put_directive (Ddesc0);
		put_space_label_module_d_name (CurrentModule,name);
	} else if (DoDebug){
		put_directive (Ddesc0);
		PutSSOutFile (" " D_PREFIX,name);
	} else {
		put_directive (Ddesc0);
		PutSUOutFile (" " LOCAL_D_PREFIX,sdef->sdef_number);
	}
	put_arguments_n_b (constructor_n);
	put_space_quoted_string (name);
}

void GenRecordDescriptor (SymbDef sdef)
{
	int asize,bsize,has_unboxed_record;
	char *name;
	StateS recstate;
	
	recstate = sdef->sdef_record_state;

	asize=0;
	bsize=0;
	if (recstate.state_type==RecordState)
		has_unboxed_record = AddSizeOfStatesAndImportRecords (recstate.state_arity,recstate.state_record_arguments,&asize,&bsize);
	 else
		has_unboxed_record = AddSizeOfStateAndImportRecords (recstate,&asize,&bsize);

	name = sdef->sdef_name;

	if (sdef->sdef_exported || ExportLocalLabels){
		put_directive (Dexport);
		put_space_label_module_r_name (CurrentModule,name);
		put_directive (Drecord);
		put_space_label_module_r_name (CurrentModule,name);
	} else if (DoDebug){
		put_directive (Drecord);
		PutSSOutFile (" " R_PREFIX,name);
	} else {
		put_directive (Drecord);
		PutSUOutFile (" " R_PREFIX,sdef->sdef_number);
	}

	PutCOutFile (' ');
	GenABStackElemsOfRecord (recstate);
	
	put_arguments_nn_b (asize,bsize);
	if (has_unboxed_record)
		GenUnboxedRecordLabelsReversedForRecord (recstate); 
	put_space_quoted_string (name);
}

#ifdef STRICT_LISTS
void GenUnboxedConsRecordDescriptor (SymbDef sdef,int tail_strict)
{
	int asize,bsize,has_unboxed_record;
	char *name,*unboxed_record_cons_prefix;
	StateS tuple_arguments_state[2];

	tuple_arguments_state[0] = sdef->sdef_record_state;
	tuple_arguments_state[1] = LazyState;

	DetermineSizeOfState (tuple_arguments_state[1],&asize,&bsize);
	if (tuple_arguments_state[0].state_type==RecordState)
		has_unboxed_record = AddSizeOfStatesAndImportRecords (tuple_arguments_state[0].state_arity,tuple_arguments_state[0].state_record_arguments,&asize,&bsize);
	else
		has_unboxed_record = AddSizeOfStateAndImportRecords (tuple_arguments_state[0],&asize,&bsize);

	name = sdef->sdef_name;
	
	unboxed_record_cons_prefix=tail_strict ? "r_Cons#!" : "r_Cons#";
	
	if (ExportLocalLabels){
		put_directive (Dexport);
		put_space_label_module_prefix_name (CurrentModule,unboxed_record_cons_prefix,name);
		put_directive (Drecord);
		put_space_label_module_prefix_name (CurrentModule,unboxed_record_cons_prefix,name);
	} else {
		put_directive_ (Drecord);
		PutSSOutFile (unboxed_record_cons_prefix,name);
	}

	PutSOutFile (" lR");

	GenABStackElemsOfRecord (tuple_arguments_state[0]);
	GenABStackElems (tuple_arguments_state[1]);
	
	put_arguments_nn_b (asize,bsize);
	if (has_unboxed_record)
		GenUnboxedRecordLabelsReversedForRecord (tuple_arguments_state[0]);
	
	if (!sdef->sdef_exported && sdef->sdef_module==CurrentModule && !ExportLocalLabels){
		if (DoDebug)
			PutSSOutFile (" " R_PREFIX,name);
		else
			PutSUOutFile (" " R_PREFIX,sdef->sdef_number);
	} else
		put_space_label_module_r_name (sdef->sdef_module,name);

	if (ExportLocalLabels){
		PutSOutFile (tail_strict ? " \"_Cons#!" : " \"_Cons#");
		PutSOutFile (name);
		PutSOutFile ("\"");
	} else {
		PutSOutFile (" \"[#");
		PutSOutFile (name);
		PutSOutFile (tail_strict ? "!]\"" : "]\"");
	}
}
#endif

void GenUnboxedJustRecordDescriptor (SymbDef sdef)
{
	int asize,bsize,has_unboxed_record;
	char *name,*unboxed_record_cons_prefix;

	asize=0;
	bsize=0;
	if (sdef->sdef_record_state.state_type==RecordState)
		has_unboxed_record = AddSizeOfStatesAndImportRecords (sdef->sdef_record_state.state_arity,sdef->sdef_record_state.state_record_arguments,&asize,&bsize);
	else
		has_unboxed_record = AddSizeOfStateAndImportRecords (sdef->sdef_record_state,&asize,&bsize);

	name = sdef->sdef_name;
	
	unboxed_record_cons_prefix="r_Just#";
	
	if (ExportLocalLabels){
		put_directive (Dexport);
		put_space_label_module_prefix_name (CurrentModule,unboxed_record_cons_prefix,name);
		put_directive (Drecord);
		put_space_label_module_prefix_name (CurrentModule,unboxed_record_cons_prefix,name);
	} else {
		put_directive_ (Drecord);
		PutSSOutFile (unboxed_record_cons_prefix,name);
	}

	PutCOutFile (' ');

	GenABStackElemsOfRecord (sdef->sdef_record_state);

	put_arguments_nn_b (asize,bsize);
	if (has_unboxed_record)
		GenUnboxedRecordLabelsReversedForRecord (sdef->sdef_record_state);
	
	if (!sdef->sdef_exported && sdef->sdef_module==CurrentModule && !ExportLocalLabels){
		if (DoDebug)
			PutSSOutFile (" " R_PREFIX,name);
		else
			PutSUOutFile (" " R_PREFIX,sdef->sdef_number);
	} else
		put_space_label_module_r_name (sdef->sdef_module,name);

	if (ExportLocalLabels){
		PutSOutFile (" \"_Just#");
		PutSOutFile (name);
		PutSOutFile ("\"");
	} else {
		PutSOutFile (" \"+?#");
		PutSOutFile (name);
		PutSOutFile ("\"");
	}
}

void GenStrictConstructorDescriptor (SymbDef sdef,StateP constructor_arg_states)
{
	int asize,bsize,state_arity,arg_n,has_unboxed_record;
	StateP constructor_arg_state_p;
	char *name;

	state_arity=sdef->sdef_arity;

	asize = 0;
	bsize = 0;
	has_unboxed_record = 0;
	for (arg_n=0,constructor_arg_state_p=constructor_arg_states; arg_n<state_arity; ++arg_n,++constructor_arg_state_p)
		has_unboxed_record |= AddSizeOfStateAndImportRecords (*constructor_arg_state_p,&asize,&bsize);

	name = sdef->sdef_name;
	
	if (sdef->sdef_exported || ExportLocalLabels){
		put_directive (Dexport);
		put_space_label_module_constructor_r_name (CurrentModule,name);
		put_directive (Drecord);
		put_space_label_module_constructor_r_name (CurrentModule,name);
	} else if (DoDebug){
		put_directive (Drecord);
		PutSSOutFile (" " CONSTRUCTOR_R_PREFIX,name);
	} else {
		put_directive (Drecord);
		PutSUOutFile (" " CONSTRUCTOR_R_PREFIX,sdef->sdef_number);
	}

	PutCOutFile (' ');
	PutCOutFile ('d');

	for (arg_n=0,constructor_arg_state_p=constructor_arg_states; arg_n<state_arity; ++arg_n,++constructor_arg_state_p)
		 GenABStackElemsForRecordDesc (*constructor_arg_state_p);
	
	put_arguments_nn_b (asize, bsize);
	if (has_unboxed_record)
		for (arg_n=state_arity-1; arg_n>=0; --arg_n)
			GenUnboxedRecordLabelsReversed (constructor_arg_states[arg_n]);
	put_space_quoted_string (name);	
}

void GenArrayFunctionDescriptor (SymbDef arr_fun_def, Label desclab, int arity)
{
	LabDef descriptor_label;
	char *name;
	
	name = arr_fun_def->sdef_name;
	
	if (ExportLocalLabels){
		put_directive (Dexport);
		put_space_label_module_d_name (CurrentModule,name);
		if (arr_fun_def->sdef_mark & SDEF_USED_LAZILY_MASK){
			put_directive (Dexport);
			put_space_label_module_n_name (CurrentModule,name);
		}
	}

	descriptor_label=*desclab;
	descriptor_label.lab_pref=d_pref;
	
	put_directive (arr_fun_def->sdef_mark & SDEF_USED_CURRIED_MASK ? Ddesc : Ddescn);	
	if (ExportLocalLabels){
		put_space_label_module_d_name (CurrentModule,name);
	} else {
		PutCOutFile (' ');
		GenLabel (&descriptor_label);
	}

	PutCOutFile (' ');
	GenLabel (&empty_lab);

	if (arr_fun_def->sdef_mark & SDEF_USED_CURRIED_MASK){
		LabDef lazylab;
		
		PutCOutFile (' ');

		lazylab = *desclab;
		lazylab.lab_pref = l_pref;
		GenLabel (&lazylab);
	}

	put_arguments_n_b (arity);
	PutSOutFile (" 0");
	put_space_quoted_string (name);
}

void GenFunctionDescriptorAndExportNodeAndDescriptor (SymbDef sdef)
{
	char *name;

	if (!DescriptorNeeded (sdef))
		return;

	name = sdef->sdef_name;
	
	if (sdef->sdef_exported){
		put_directive (Ddescexp);
		put_space_label_module_d_name (CurrentModule,name);
		put_space_label_module_n_name (CurrentModule,name);
		put_space_label_module_l_name (CurrentModule,name);
	} else {
		if (sdef->sdef_mark & SDEF_USED_CURRIED_MASK){
			int sdef_n;
			
			sdef_n=sdef->sdef_number;

			if (ExportLocalLabels){
				put_directive (Dexport);
				put_space_label_module_d_name (CurrentModule,name);
				PutdotUOutFile (sdef_n);

				if (sdef->sdef_mark & SDEF_USED_LAZILY_MASK){
					put_directive (Dexport);
					put_space_label_module_n_name (CurrentModule,name);
					PutdotUOutFile (sdef_n);
				}

				put_directive (Ddesc);
				put_space_label_module_d_name (CurrentModule,name);
				PutdotUOutFile (sdef_n);
			} else {
				put_directive (Ddesc);
				if (DoDebug)
					PutSSdotUOutFile (" " D_PREFIX,name,sdef_n);
				else
					PutSUOutFile (" " LOCAL_D_PREFIX,sdef_n);
			}
			
			if (sdef->sdef_mark & SDEF_USED_LAZILY_MASK){
				if (ExportLocalLabels){
					put_space_label_module_n_name (CurrentModule,name);
					PutdotUOutFile (sdef_n);
				} else if (DoDebug)
					PutSSdotUOutFile (" " N_PREFIX,name,sdef_n);
				else
					PutSUOutFile (" " N_PREFIX,sdef_n);
			} else
				Put_SOutFile (hnf_lab.lab_name);
			
			if (DoDebug)
				PutSSdotUOutFile (" " L_PREFIX,name,sdef_n);
			else
				PutSUOutFile (" " L_PREFIX,sdef_n);
		} else {
			int sdef_n;

			sdef_n=sdef->sdef_number;

			if (ExportLocalLabels){
				put_directive (Dexport);
				put_space_label_module_d_name (CurrentModule,name);
				PutdotUOutFile (sdef_n);

				if (sdef->sdef_mark & SDEF_USED_LAZILY_MASK){
					put_directive (Dexport);
					put_space_label_module_n_name (CurrentModule,name);
					PutdotUOutFile (sdef_n);
				}

				put_directive (Ddescn);
				put_space_label_module_d_name (CurrentModule,name);
				PutdotUOutFile (sdef_n);
			} else {
				put_directive (Ddescn);
				if (DoDebug)
					PutSSdotUOutFile (" " D_PREFIX,name,sdef_n);
				else
					PutSUOutFile (" " LOCAL_D_PREFIX,sdef_n);
			}
			
			if (sdef->sdef_mark & SDEF_USED_LAZILY_MASK){
				if (ExportLocalLabels){
					put_space_label_module_n_name (CurrentModule,name);
					PutdotUOutFile (sdef_n);
				} else if (DoDebug)
					PutSSdotUOutFile (" " N_PREFIX,name,sdef_n);
				else
					PutSUOutFile (" " N_PREFIX,sdef_n);
			} else
				Put_SOutFile (hnf_lab.lab_name);
		}
	}
	
	put_arguments_n_b (sdef->sdef_arity);
	PutSOutFile (" 0 \"");
	if (ExportLocalLabels){
		if (sdef->sdef_exported)
			PutSOutFile (name);
		else
			PutSdotUOutFile (name,sdef->sdef_number);
	} else
		WriteSymbolOfIdentToOutFile (name, 0);
	PutCOutFile ('\"');
}

void GenConstructorFunctionDescriptorAndExportNodeAndDescriptor (SymbDef sdef)
{
	char *name;

	if (!DescriptorNeeded (sdef))
		return;

	name = sdef->sdef_name;
	
	if (sdef->sdef_exported){
		put_directive (Ddescexp);
		put_space_label_module_d_name (CurrentModule,name);
		put_space_label_module_n_name (CurrentModule,name);
		put_space_label_module_l_name (CurrentModule,name);
	} else if (ExportLocalLabels && (sdef->sdef_mark & SDEF_USED_CURRIED_MASK)!=0){
		put_directive (Ddescexp);
		put_space_label_module_d_name (CurrentModule,name);
		put_space_label_module_n_name (CurrentModule,name);
		if (DoDebug)
			PutSSOutFile (" " L_PREFIX,name);
		else
			PutSUOutFile (" " L_PREFIX,sdef->sdef_number);
	} else {
		if (sdef->sdef_mark & SDEF_USED_CURRIED_MASK){
			put_directive (Ddesc);
			
			if (DoDebug)
				PutSSOutFile (" " D_PREFIX,name);
			else
				PutSUOutFile (" " LOCAL_D_PREFIX,sdef->sdef_number);
			
			if (sdef->sdef_mark & SDEF_USED_LAZILY_MASK){
				if (DoDebug)
					PutSSOutFile (" " N_PREFIX,name);
				else
					PutSUOutFile (" " N_PREFIX,sdef->sdef_number);
			} else
				Put_SOutFile (hnf_lab.lab_name);
			
			if (DoDebug)
				PutSSOutFile (" " L_PREFIX,name);
			else
				PutSUOutFile (" " L_PREFIX,sdef->sdef_number);
		} else {
			if (ExportLocalLabels){
				put_directive (Dexport);
				put_space_label_module_d_name (CurrentModule,name);
				put_directive (Dexport);
				put_space_label_module_n_name (CurrentModule,name);
			}

			put_directive (Ddescn);

			if (ExportLocalLabels)
				put_space_label_module_d_name (CurrentModule,name);
			else {
				if (DoDebug)
					PutSSOutFile (" " D_PREFIX, name);
				else
					PutSUOutFile (" " LOCAL_D_PREFIX,sdef->sdef_number);
			}

			if (ExportLocalLabels)
				put_space_label_module_n_name (CurrentModule,name);
			else if (sdef->sdef_mark & SDEF_USED_LAZILY_MASK){
				if (DoDebug)
					PutSSOutFile (" " N_PREFIX, name);
				else
					PutSUOutFile (" " N_PREFIX,sdef->sdef_number);
			} else
				Put_SOutFile (hnf_lab.lab_name);
		}
	}
	
	put_arguments_n_b (sdef->sdef_arity);
	PutSOutFile (" 0 \"");
	WriteSymbolOfIdentToOutFile (name, 0);
	PutCOutFile ('\"');
}

#if OPTIMIZE_LAZY_TUPLE_RECURSION
void GenFunctionDescriptorForLazyTupleRecursion (SymbDef sdef,int tuple_result_arity)
{
	char *name;

	name = sdef->sdef_name;
	
	put_directive (Ddescn);

	if (sdef->sdef_exported){
		put_space_label_module_d_name (CurrentModule,name);
		PutSOutFile (".2");
		put_space_label_module_n_name (CurrentModule,name);
		PutSOutFile (".2");
	} else if (DoDebug){
		PutSSdotUOutFile (" " D_PREFIX,name,sdef->sdef_number);
		PutSOutFile (".2");
		PutSSdotUOutFile (" " N_PREFIX,name,sdef->sdef_number);
		PutSOutFile (".2");
	} else {
		PutSUOutFile (" " LOCAL_D_PREFIX,sdef->sdef_number);
		PutSOutFile (".2");
		PutSUOutFile (" " N_PREFIX,sdef->sdef_number);
		PutSOutFile (".2");
	}
	
	put_arguments_n_b (sdef->sdef_arity+tuple_result_arity);
	PutSOutFile (" 0 \"");
	WriteSymbolOfIdentToOutFile (name,0);
	PutCOutFile ('\"');

# if 1
	put_directive (Ddescn);

	if (sdef->sdef_exported){
		put_space_label_module_d_name (CurrentModule,name);
		PutSOutFile (".3");
		put_space_label_module_n_name (CurrentModule,name);
		PutSOutFile (".3");
	} else if (DoDebug){
		PutSSdotUOutFile (" " D_PREFIX,name,sdef->sdef_number);
		PutSOutFile (".3");
		PutSSdotUOutFile (" " N_PREFIX,name,sdef->sdef_number);
		PutSOutFile (".3");
	} else {
		PutSUOutFile (" " LOCAL_D_PREFIX,sdef->sdef_number);
		PutSOutFile (".3");
		PutSUOutFile (" " N_PREFIX,sdef->sdef_number);
		PutSOutFile (".3");
	}
	
	put_arguments_n_b (sdef->sdef_arity+tuple_result_arity);
	PutSOutFile (" 0 \"");
	WriteSymbolOfIdentToOutFile (name,0);
	PutCOutFile ('\"');
# endif
}
#endif

void GenLazyRecordDescriptorAndExport (SymbDef sdef)
{
	char *name;
	int arity;

	if (!DescriptorNeeded (sdef))
		return;

	name = sdef->sdef_name;
	arity = sdef->sdef_arity;
	
	if (sdef->sdef_exported){
		put_directive (Ddescexp);
		put_space_label_module_record_d_name (CurrentModule,name);
		put_space_label_module_record_n_name (CurrentModule,name);
		PutSOutFile (" _hnf");
		put_arguments_n_b (arity);
		PutSOutFile (" 1");
		put_space_quoted_string (name);
	} else {
		if (ExportLocalLabels){
			put_directive (Dexport);
			put_space_label_module_record_d_name (CurrentModule,name);
			put_directive (Dexport);
			put_space_label_module_record_n_name (CurrentModule,name);
		}

		put_directive (Ddescn);
		if (ExportLocalLabels){
			put_space_label_module_record_d_name (CurrentModule,name);
			put_space_label_module_record_n_name (CurrentModule,name);
		} else if (DoDebug){
			PutSSOutFile (" " RECORD_D_PREFIX,name);
			PutSSOutFile (" " RECORD_N_PREFIX,name);
		} else {
			PutSUOutFile (" " RECORD_D_PREFIX,sdef->sdef_number);
			PutSUOutFile (" " RECORD_N_PREFIX,sdef->sdef_number);
		}
		
		put_arguments_n_b (arity);
		PutSOutFile (" 1");
		put_space_quoted_string (name);
	}
}

static void print_result_descriptor_and_offsets (StateS field_state,int a_pos,int b_pos,int record_a_size,int record_b_size)
{
	if (field_state.state_kind!=OnB){
		PutSOutFile (" _");
		put_arguments_n_b ((a_pos<=1 && !(a_pos==1 && record_a_size+record_b_size>2)) ? a_pos+1 : a_pos+2);
		PutSOutFile (" 0");
	} else {
		char *result_descriptor_name;
		int offset1,offset2;
		
		result_descriptor_name=BasicDescriptors[field_state.state_object].lab_name;

		offset1=record_a_size+b_pos;
		offset1=(offset1<=1 && !(offset1==1 && record_a_size+record_b_size>2)) ? offset1+1 : offset1+2;

		if (ObjectSizes[field_state.state_object]>1){
			offset2=record_a_size+b_pos+1;
			offset2=(offset2==1 && record_a_size+record_b_size<=2) ? offset2+1 : offset2+2;
		} else
			offset2=0;
		
		if (field_state.state_object==FileObj){
			/* the code generator stores the fields in a FILE node in reversed order */
			int old_offset1;

			old_offset1=offset1;
			offset1=offset2;
			offset2=old_offset1;
		}
		Put_SOutFile (result_descriptor_name);
		put_arguments_nn_b (offset1,offset2);
	}
}

void GenFieldSelectorDescriptor (SymbDef sdef,StateS field_state,int a_pos,int b_pos,int record_a_size,int record_b_size)
{
	char *name,*record_name;
	int gc_updates_selector;

	if (!DescriptorNeeded (sdef))
		return;

	gc_updates_selector=IsSimpleState (field_state);

	name = sdef->sdef_name;
	record_name=sdef->sdef_type->type_symbol->ts_def->sdef_name;

	put_directive (gc_updates_selector ? Ddescs : Ddesc);
	if (sdef->sdef_exported){
		put_space_label_module_d_name (CurrentModule,record_name);
		PutdotSOutFile (name);
		put_space_label_module_n_name (CurrentModule,record_name);
		PutdotSOutFile (name);
		if (gc_updates_selector)
			print_result_descriptor_and_offsets (field_state,a_pos,b_pos,record_a_size,record_b_size);
		else
			PutSOutFile (" _hnf 1 0");
	} else if ((sdef->sdef_mark & SDEF_USED_LAZILY_MASK) || gc_updates_selector){
		if (ExportLocalLabels){
			put_space_label_module_d_name (CurrentModule,record_name);
			PutdotSOutFile (name);		
		} else if (DoDebug)
			PutSSdotSOutFile (" " D_PREFIX,record_name,name);
		else
			PutSUOutFile (" " LOCAL_D_PREFIX,sdef->sdef_number);

		if (sdef->sdef_mark & SDEF_USED_LAZILY_MASK){
			if (ExportLocalLabels){
				put_space_label_module_n_name (CurrentModule,record_name);
				PutdotSOutFile (name);
			} else if (DoDebug)
				PutSSdotSOutFile (" " N_PREFIX,record_name,name);
			else
				PutSUOutFile (" " N_PREFIX,sdef->sdef_number);
		} else
			Put_SOutFile (hnf_lab.lab_name);

		if (gc_updates_selector)
			print_result_descriptor_and_offsets (field_state,a_pos,b_pos,record_a_size,record_b_size);
		else {
			Put_SOutFile (hnf_lab.lab_name);
			PutSOutFile (" 1 0");
		}
	} else {
		if (DoDebug){
			PutSSOutFile (" " D_PREFIX, name);
		} else
			PutSUOutFile (" " LOCAL_D_PREFIX,sdef->sdef_number);
		Put_SOutFile (hnf_lab.lab_name);
		Put_SOutFile (hnf_lab.lab_name);
		PutSOutFile (" 1 0");
	}

	PutSOutFile (" \"");
	PutSdotSOutFile (record_name,name);
	PutCOutFile ('\"');
}

void GenModuleDescriptor (
#if WRITE_DCL_MODIFICATION_TIME
						ModuleFileTime file_time
#else
						void
#endif
	)
{
	put_directive (Dmodule);
	PutSSOutFile (" m_",CurrentModule);
	put_space_quoted_string (CurrentModule);

#if WRITE_DCL_MODIFICATION_TIME
	if (WriteModificationTimes){
		PutCOutFile (' ');
		PutCOutFile ('\"');
		PutSOutFile (file_time);
		PutCOutFile ('\"');
	}
#endif
}

void GenDepend (char *modname
#if WRITE_DCL_MODIFICATION_TIME
				,ModuleFileTime file_time
#endif
				)
{
	put_directive (Ddepend);
	put_space_quoted_string (modname);

#if WRITE_DCL_MODIFICATION_TIME
	if (WriteModificationTimes){
		PutCOutFile (' ');
		PutCOutFile ('\"');
		PutSOutFile (file_time);
		PutCOutFile ('\"');
	}
#endif
}

void GenStart (SymbDef startsymb)
{
	if (startsymb->sdef_module == CurrentModule){
		int arity;
		char *start_function_name;

		arity = startsymb->sdef_arity;
		startsymb->sdef_mark |= SDEF_USED_LAZILY_MASK;

		start_function_name=startsymb->sdef_name;
		
		put_directive (Dexport);
		PutSSOutFile (" __",CurrentModule);
		PutSSOutFile ("_",start_function_name);

		GenOAStackLayout (0);

		PutCOutFile ('\n');
		PutSSOutFile ("__",CurrentModule);
		PutSSOutFile ("_",start_function_name);

		if (arity!=0 || strcmp (start_function_name,"main")==0){
			put_instructionb (buildI);
			put_arguments_n_b (65536l);
		}
		
		put_instructionb (build);
		
		if (startsymb->sdef_exported)
			put_space_label_module_d_name (CurrentModule,start_function_name);
		else if (DoParallel){
			if (ExportLocalLabels){
				put_space_label_module_d_name (CurrentModule,start_function_name);
				PutdotUOutFile (startsymb->sdef_number);
			} else if (DoDebug)
				PutSSdotUOutFile (" " D_PREFIX,start_function_name,startsymb->sdef_number);
			else
				PutSUOutFile (" " LOCAL_D_PREFIX,startsymb->sdef_number);
		} else {
			PutCOutFile (' ');
			PutSOutFile (empty_lab.lab_name);
		}

		put_arguments_n_b (arity);

		if (startsymb->sdef_exported)
			put_space_label_module_n_name (CurrentModule,start_function_name);
		else if (ExportLocalLabels){
			put_space_label_module_n_name (CurrentModule,start_function_name);
			PutdotUOutFile (startsymb->sdef_number);
		} else if (DoDebug)
			PutSSdotUOutFile (" " N_PREFIX,start_function_name,startsymb->sdef_number);
		else
			PutSUOutFile (" " N_PREFIX,startsymb->sdef_number);

		if (arity==0 && strcmp (start_function_name,"main")==0){
			GenJsrEval (0);
			GenJsrAp (1);
		}
		
		GenDAStackLayout (1);
		put_instruction_b (jmp);
		PutSOutFile ("_driver");
	}
}

void GenSelectorDescriptor (Label sellab,int element_n)
{
	if (sellab->lab_issymbol){
		char *name;
		
		name=sellab->lab_symbol->sdef_name;

		put_directive (Dexport);
		put_space_label_module_d_name (sellab->lab_mod,name);
		PutdotUOutFile (sellab->lab_post);
		put_directive (Dexport);
		put_space_label_module_prefix_name (sellab->lab_mod,sellab->lab_pref,name);
		PutdotUOutFile (sellab->lab_post);

		put_directive (Ddescs);
		put_space_label_module_d_name (sellab->lab_mod,name);
		PutdotUOutFile (sellab->lab_post);
		put_space_label_module_prefix_name (sellab->lab_mod,sellab->lab_pref,name);
		PutdotUOutFile (sellab->lab_post);
	} else {
		put_directive (Ddescs);
		PutSSdotDOutFile (" " D_PREFIX, sellab->lab_name, sellab->lab_post);
		PutCOutFile (' ');
		PutSSdotDOutFile (sellab->lab_pref, sellab->lab_name, sellab->lab_post);
	}

	PutSOutFile (" _");
	put_arguments_n_b (element_n+1);
	PutSOutFile (" 0 \"");
	PutSdotUOutFile (sellab->lab_name,sellab->lab_post);
	PutCOutFile ('\"');
}

void InitFileInfo (ImpMod imod)
{
	char option_string[N_OPTIONS+1];
	SymbDef start_sdef;
	
	start_sdef=imod->im_start;

	ConvertOptionsToString (option_string);

	if (imod->im_def_module!=NULL && imod->im_def_module->dm_system_module)
		option_string[N_System]='1';

	put_first_directive (Dcomp);
	put_arguments_n_b (VERSION);
	Put_SOutFile (option_string);
	
	put_directive (Dstart);
	if (start_sdef!=NULL){
		PutSSOutFile (" __",start_sdef->sdef_module);
		PutSSOutFile ("_",start_sdef->sdef_name);
	} else
		PutSOutFile (" _nostart_");
}

static int match_error_lab_used = 0;

void GenNoMatchError (SymbDef sdef,int asp,int bsp,int string_already_generated)
{
	Bool desc_needed;
	
	desc_needed = DescriptorNeeded (sdef);

	GenPopA (asp);
	GenPopB (bsp);
	
	put_instructionb (pushD);
	PutSSOutFile (" m_",CurrentModule);

	put_instructionb (pushD);
	if (!desc_needed)
		PutSUOutFile (" x_", sdef->sdef_number);
	else if (sdef->sdef_exported)
		put_space_label_module_d_name (CurrentModule,sdef->sdef_name);
	else if (ExportLocalLabels){
		put_space_label_module_d_name (CurrentModule,sdef->sdef_name);
		if (sdef->sdef_kind==IMPRULE)
			PutdotUOutFile (sdef->sdef_number);
	} else if (DoDebug){
		PutSSOutFile (" " D_PREFIX, sdef->sdef_name);
		if (sdef->sdef_kind==IMPRULE)
			PutdotUOutFile (sdef->sdef_number);
	} else
		PutSUOutFile (" " LOCAL_D_PREFIX,sdef->sdef_number);
	
	if (DoStackLayout){
		put_directiveb (d);
		put_arguments_nn_b (0,2);
		PutCOutFile (' ');
		PutSOutFile ("ii");
	}
	
	GenJmp (&match_error_lab);
	match_error_lab_used = 1;
	
	if (!desc_needed && !string_already_generated){
		put_directive (Dstring);
		PutSUOutFile (" x_",sdef->sdef_number);
		PutSOutFile (" \"");
		WriteSymbolOfIdentToOutFile (sdef->sdef_name,0);
		PutSOutFile ("\"");
	}
}

#if CLEAN2

void GenCaseNoMatchError (SymbDefP case_def,int asp,int bsp)
{

	GenPopA (asp);
	GenPopB (bsp);

	put_instructionb (pushD);
	PutSSOutFile (" m_",CurrentModule);

	put_instructionb (pushD);
	PutSUOutFile (" case_fail",CaseFailNumber);

	GenJmp (&match_error_lab);
	match_error_lab_used = 1;
	
	put_directive (Dstring);
	PutSUOutFile (" case_fail",CaseFailNumber);
	PutSOutFile (" \"");
	WriteSymbolOfIdentToOutFile (case_def->sdef_name,0);
	PutSOutFile ("\"");		

	CaseFailNumber++;
}
#endif

static void GenImpLab (char *label_name)
{
	put_directive_b (implab);
	PutSOutFile (label_name);
}

static void GenImpLab_node_entry (char *label_name,char *ea_label_name)
{
	put_directiveb (implab);
	Put_SOutFile (label_name);
	Put_SOutFile (ea_label_name);
}

static void GenImpLab_n_and_ea_label (char *label_name)
{
	put_directiveb (implab);
	PutSSOutFile (" n",label_name);
	PutSSOutFile (" ea",label_name);
}

static void GenImpDesc (char *descriptor_name)
{
	put_directive_b (impdesc);
	PutSOutFile (descriptor_name);
}

void GenImpMod (char *module_name)
{
	put_directive_b (impmod);
	PutSOutFile (module_name);
}

void GenEndInfo (void)
{
	put_directive (Dendinfo);
}

void GenSystemImports (void)
{
	match_error_lab_used = 0;
	selector_m_error_lab_used = 0;

	if (DoStackLayout){
		 /* system module labels and descriptors */

		int selnum;

		GenImpMod ("_system");

		if (DoParallel){
			GenImpLab (channel_code);
			GenImpLab (hnf_reducer_code);
			GenImpDesc (ext_hnf_reducer_code);
			GenImpLab (nf_reducer_code);
			GenImpDesc (ext_nf_reducer_code);
			GenImpLab (reserve_lab.lab_name);
		}
		GenImpLab (cycle_lab.lab_name);
		GenImpLab (type_error_lab.lab_name);
		GenImpLab (hnf_lab.lab_name);

		GenImpDesc (ind_lab.lab_name);
		GenImpLab_node_entry (indirection_lab.lab_name,"e_system_eaind");
		GenImpDesc ("e_system_dif");
		GenImpLab_node_entry ("e_system_nif","e_system_eaif");
		GenImpLab ("e_system_sif");

		GenImpDesc ("e_system_dAP");
		GenImpLab_node_entry ("e_system_nAP","e_system_eaAP");
		GenImpLab ("e_system_sAP");

		GenImpDesc (BasicDescriptors [ArrayObj].lab_name);

		GenImpDesc (nil_lab.lab_name);
		GenImpDesc (cons_lab.lab_name);
#if STRICT_LISTS
		GenImpDesc (conss_lab.lab_name);
		GenImpLab_node_entry ("n_Conss","ea_Conss");
		GenImpDesc (consts_lab.lab_name);
		GenImpLab_node_entry ("n_Consts","ea_Consts");
		GenImpDesc (conssts_lab.lab_name);
		GenImpLab_node_entry ("n_Conssts","ea_Conssts");
#endif

		{
		int i;
		
		for (i=0; i<5; ++i){
			char *descriptor_label_name;

			if (unboxed_cons_mark[i][0]!=0){
				descriptor_label_name=unboxed_cons_labels[i][0].lab_name;
				GenImpDesc (descriptor_label_name);
				if (unboxed_cons_mark[i][0] & SDEF_USED_LAZILY_MASK)
					GenImpLab_n_and_ea_label (descriptor_label_name);
			}
			if (unboxed_cons_mark[i][1]!=0){
				descriptor_label_name=unboxed_cons_labels[i][1].lab_name;
				GenImpDesc (descriptor_label_name);
				if (unboxed_cons_mark[i][1] & SDEF_USED_LAZILY_MASK)
					GenImpLab_n_and_ea_label (descriptor_label_name);
			}
		}
		if (unboxed_cons_array_mark!=0){
			GenImpDesc (unboxed_cons_array_label.lab_name);
			if (unboxed_cons_array_mark & SDEF_USED_LAZILY_MASK)
				GenImpLab_n_and_ea_label (unboxed_cons_array_label.lab_name);
		}
		}		

		GenImpDesc (tuple_lab.lab_name);
		for (selnum=1; selnum<=NrOfGlobalSelectors; ++selnum){
			put_directiveb (impdesc);
			PutSSdotDOutFile (" " D_PREFIX,glob_sel,selnum);
			put_directiveb (implab);
			PutSSdotDOutFile (" " N_PREFIX,glob_sel,selnum);
			PutSSdotDOutFile (" " EA_PREFIX,glob_sel,selnum);
		}
#ifdef THUNK_LIFT_SELECTORS
		for (selnum=1; selnum<=NrOfGlobalSelectors; ++selnum){
			put_directiveb (impdesc);
			PutSSdotDOutFile (" " D_PREFIX,glob_selr,selnum);
			put_directiveb (implab);
			PutSSdotDOutFile (" " N_PREFIX,glob_selr,selnum);
			PutSSdotDOutFile (" " EA_PREFIX,glob_selr,selnum);
		}
#endif

		if (SeqDef!=NULL && (SeqDef->sdef_mark & (SDEF_USED_LAZILY_MASK | SDEF_USED_CURRIED_MASK))){
			GenImpDesc ("e_system_dseq");
			GenImpLab_node_entry ("e_system_nseq","e_system_easeq");	
		}

		GenImpLab ("_driver");
	}
}

void import_not_yet_imported_system_labels (void)
{
	if (match_error_lab_used ||
		selector_m_error_lab_used)
		GenImpMod ("_system");
	if (match_error_lab_used)
		GenImpLab (match_error_lab.lab_name);
	if (selector_m_error_lab_used)
		GenImpLab (selector_m_error_lab.lab_name);
}

static void print_foreign_export_type (TypeNode type)
{
	if (!type->type_node_is_var){
		SymbKind type_symbol_kind;

		type_symbol_kind=type->type_node_symbol->ts_kind;

		if (type_symbol_kind==int_type){
			PutSOutFile ("I");
			return;
		} else if (type_symbol_kind==real_type){
			PutSOutFile ("R");
			return;
		} else if (type_symbol_kind==unboxed_array_type){
			TypeNode type_node_p;

			type_node_p=type->type_node_arguments->type_arg_node;
			if (!type_node_p->type_node_is_var){
				switch (type_node_p->type_node_symbol->ts_kind){
					case char_type:
						PutSOutFile ("S");
						return;
					case int_type:
						PutSOutFile ("Ai");
						return;
					case real_type:
						PutSOutFile ("Ar");
						return;
				}
			}
		} else if (type_symbol_kind==tuple_type){
			TypeArgs type_arg_p;
			
			for_l (type_arg_p,type->type_node_arguments,type_arg_next)
				print_foreign_export_type (type_arg_p->type_arg_node);
			
			return;
		}
	}
	
	error_in_function ("print_foreign_export_type");
}

static void print_foreign_export_result_type (TypeNode type)
{
	if (!type->type_node_is_var && type->type_node_symbol->ts_kind==tuple_type)
		PutSOutFile ("V");

	print_foreign_export_type (type);
}

void GenerateForeignExports (struct foreign_export_list *foreign_export_list)
{
	struct foreign_export_list *foreign_export_p;

	for_l (foreign_export_p,foreign_export_list,fe_next){
		SymbDef function_sdef;
		TypeAlt *rule_type_p;
		TypeArgs type_arg_p;

		function_sdef=foreign_export_p->fe_symbol_p->symb_def;

		put_instruction_ ("centry");
		PutSOutFile (function_sdef->sdef_name);
		put_space_label_module_s_name (CurrentModule,function_sdef->sdef_name);
		PutSOutFile (" \"");
		
		if (foreign_export_list->fe_stdcall)
			PutCOutFile ('P');
		
		rule_type_p=function_sdef->sdef_rule->rule_type;
		
		for_l (type_arg_p,rule_type_p->type_alt_lhs_arguments,type_arg_next)
			print_foreign_export_type (type_arg_p->type_arg_node);
		
		PutSOutFile (":");
		
		print_foreign_export_result_type (rule_type_p->type_alt_rhs);
				
		PutSOutFile ("\"");
	}
}

void GenParameters (Bool input, Parameters params, int asp, int bsp)
{
	int is_first_parameter;

	if (input)
		put_instruction_ (Iin);
	else
		put_instruction_ (Iout);
	
	is_first_parameter=1;
	for (; params!=NULL; params=params->par_next){
		NodeId node_id;
		
		node_id=params->par_node_id;
		if (!is_first_parameter)
			PutCOutFile (' ');
		if (IsSimpleState (node_id->nid_state) && node_id->nid_state.state_kind==OnB){
			PutCOutFile ('b');
			PutIOutFile (bsp-node_id->nid_b_index);
		} else {
			PutCOutFile ('a');
			PutIOutFile (asp-node_id->nid_a_index);
		}
		PutCOutFile (':');
		PutSOutFile (params->par_loc_name);
		is_first_parameter=0;
	}
}

void GenInstructions (Instructions ilist)
{
	for (; ilist; ilist = ilist->instr_next){
		char *instruction_name;
		
		instruction_name=ilist->instr_this;
		
		PutCOutFile ('\n');
		if (instruction_name[0]==':')
			PutSOutFile (&instruction_name[1]);
		else {
			if (instruction_name[0]!='.')
				PutCOutFile ('\t');
			PutSOutFile (instruction_name);
		}
	}
}

void GenTestCaf (Label label)
{
	put_instruction_ (Itestcaf);
	GenLabel (label);
}

void GenPushCaf (Label label,int a_stack_size,int b_stack_size)
{
	put_instruction_ (Ipushcaf);
	GenLabel (label);
	put_arguments_nn_b (a_stack_size,b_stack_size);
}

void GenFillCaf (Label label,int a_stack_size,int b_stack_size)
{
	put_instruction_ (Ifillcaf);
	GenLabel (label);
	put_arguments_nn_b (a_stack_size,b_stack_size);
}

void GenCaf (Label label,int a_stack_size,int b_stack_size)
{
	put_directive_ (Dcaf);
	GenLabel (label);
	put_arguments_nn_b (a_stack_size,b_stack_size);
}

void GenPB (char *function_name)
{
	put_directive (Dpb);
	put_space_quoted_string (function_name);
}

void GenPB_ident (char *ident_name,unsigned int line_n)
{
	put_directive_ (Dpb);
	PutCOutFile ('\"');
	WriteSymbolOfIdentToOutFile (ident_name,line_n);
	PutCOutFile ('\"');
}

void GenPB_with_line_number (char *function_name,int line_number)
{
	put_directive (Dpb);
	PutSOutFile (" \"");
	PutSOutFile (function_name);
	PutSOutFile ("[line:");
	PutIOutFile (line_number);
	PutSOutFile ("]\"");
}

void GenPD (void)
{
	put_directive (Dpd);
}

void GenPN (void)
{
	put_directive (Dpn);
}

void GenPL (void)
{
	put_directive (Dpl);
}

void GenPLD (void)
{
	put_directive (Dpld);
}

void GenPT (void)
{
	put_directive (Dpt);
}

void GenPE (void)
{
	put_directive (Dpe);
}

void GenKeep (int a_offset1,int a_offset2)
{
	put_directive (Dkeep);
	put_arguments_nn_b (a_offset1,a_offset2);
}

#if IMPORT_OBJ_AND_LIB
void GenImpObj (char *obj_name)
{
	put_directive_ ("impobj");
	PutSOutFile (obj_name);
}

void GenImpLib (char *lib_name)
{
	put_directive_ ("implib");
	PutSOutFile (lib_name);
}
#endif

void InitInstructions (void)
{
#if CLEAN2
	CaseFailNumber = 0;
#endif

    ABCFileName	= NULL;
}
