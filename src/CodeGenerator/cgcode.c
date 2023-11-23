/*
	File: 	cgcode.c
	Author:	John van Groningen
	At:		University of Nijmegen
*/

#include <stdio.h>
#include <string.h>
#if defined (LINUX) && defined (G_AI64)
# include <stdint.h>
#elif defined (__GNUC__) && defined (__SIZEOF_POINTER__)
# if __SIZEOF_POINTER__==8
#  include <stdint.h>
# endif
#endif

#undef NO_FUNCTION_NAMES
#undef NO_CONSTRUCTOR_NAMES

#undef ARRAY_OPTIMIZATIONS
#define INDEX_CSE
#define REPLACE_MUL_BY_SHIFT

#include "cgport.h"

#if defined (G_POWER) || defined (I486) || defined (ARM) || defined (sparc)
# define NO_STRING_ADDRESS_IN_DESCRIPTOR
#endif

#if defined (I486) && !defined (G_AI64)
# define SIN_COS_CSE
#endif

#if defined (G_POWER) || defined (I486) || defined (ARM)
#	define PROFILE
# if defined (G_POWER)
#  if defined (MACH_O)
#	define PROFILE_OFFSET 16
#  else
#	define PROFILE_OFFSET 12
#  endif
# else
#  ifndef G_AI64
#   ifdef ARM
#    ifdef G_A64
#	 define PROFILE_OFFSET 16
#    else
#	 define PROFILE_OFFSET 8
#    endif
#   else
#	 define PROFILE_OFFSET 10
#   endif
#  else
#	define PROFILE_OFFSET 12
#  endif
# endif
#endif

#include "cg.h"
#include "cgconst.h"
#include "cgrconst.h"
#include "cgtypes.h"
#include "cgcodep.h"
#include "cgcode.h"
#include "cglin.h"
#include "cgcalc.h"
#include "cgstack.h"
#include "cginstructions.h"
#ifdef G_POWER
#	include "cgpas.h"
#	include "cgpwas.h"
#else
# ifdef I486
#  ifdef G_AI64
#	include "cgaas.h"
#	include "cgawas.h"
#  else
#	include "cgias.h"
#	include "cgiwas.h"
#  endif
# else
#  ifdef ARM
#   ifdef G_A64
#    include "cgarm64as.h"
#	 include "cgarm64was.h"
#   else
#    include "cgarmas.h"
#	 include "cgarmwas.h"
#   endif
#  else
#   ifdef SOLARIS
#    include "cgswas.h"
#   else
#    include "cgas.h"
#    include "cgwas.h"
#   endif
#  endif
# endif
#endif

#define for_l(v,l,n) for(v=(l);v!=NULL;v=v->n)

#define GEN_OBJ

#ifdef NEW_DESCRIPTORS
# ifdef G_A64
#  define ARITY_0_DESCRIPTOR_OFFSET (-8)
# else
#  define ARITY_0_DESCRIPTOR_OFFSET (-4)
# endif
#else
# if defined (M68000) || defined (NO_STRING_ADDRESS_IN_DESCRIPTOR)
#  ifdef G_A64
#  	define ARITY_0_DESCRIPTOR_OFFSET (-12)
#  else
#  	define ARITY_0_DESCRIPTOR_OFFSET (-8)
#  endif
# else
#  define ARITY_0_DESCRIPTOR_OFFSET (-12)
# endif
#endif
#if defined (NO_STRING_ADDRESS_IN_DESCRIPTOR)
# define DESCRIPTOR_ARITY_OFFSET (-2)
#else
# define DESCRIPTOR_ARITY_OFFSET (-6)
#endif

#ifdef G_A64
# define SIZE_OF_REAL_IN_STACK_ELEMENTS 1
#else
# define SIZE_OF_REAL_IN_STACK_ELEMENTS 2
#endif

#ifdef sparc
# undef ALIGN_REAL_ARRAYS
# undef NEW_ARRAYS
# undef LOAD_STORE_ALIGNED_REAL 4
# undef ARRAY_SIZE_BEFORE_DESCRIPTOR
#endif

#ifdef G_POWER
# undef NEW_ARRAYS
# undef ARRAY_SIZE_BEFORE_DESCRIPTOR
#endif

#ifdef NEW_ARRAYS
# ifdef ARRAY_SIZE_BEFORE_DESCRIPTOR
#  define ARRAY_ELEMENTS_OFFSET STACK_ELEMENT_SIZE
# else
#  define ARRAY_ELEMENTS_OFFSET (2<<STACK_ELEMENT_LOG_SIZE)
# endif
#else
# define ARRAY_ELEMENTS_OFFSET (3<<STACK_ELEMENT_LOG_SIZE)
#endif

#if defined (NEW_ARRAYS) || defined (ALIGN_REAL_ARRAYS)
# ifdef ARRAY_SIZE_BEFORE_DESCRIPTOR
#  define REAL_ARRAY_ELEMENTS_OFFSET STACK_ELEMENT_SIZE
# else
#  define REAL_ARRAY_ELEMENTS_OFFSET (2<<STACK_ELEMENT_LOG_SIZE)
# endif
#else
# define REAL_ARRAY_ELEMENTS_OFFSET (3<<STACK_ELEMENT_LOG_SIZE)
#endif

#ifdef __MWERKS__
int mystrcmp (char *p1,char *p2)
{
	unsigned char *s1,*s2;
	int c1,c2;

	s1=(unsigned char*)p1-1;
	s2=(unsigned char*)p2-1;
		
	do {
		c1=*++s1;
		c2=*++s2;
	} while (c1!=0 && c1==c2);
	
	return *s1-*s2;
}
#endif

#ifdef PROFILE
static int profile_offset;
#endif
#if defined (G_POWER) && defined (PROFILE)
LABEL *profile_table_label;
static int profile_table_offset;
#endif

int next_label_id;

struct label_node *labels;

struct basic_block *first_block,*last_block;
struct block_label *last_block_label;

struct instruction *last_instruction;

INSTRUCTION_GRAPH load_indexed_list;

ULONG e_vector[] = { 0 };
ULONG i_vector[] = { 0 };
#ifdef G_A64
ULONG r_vector[] = { 1 };
#else
ULONG r_vector[] = { 3 };
#endif
ULONG i_i_vector[] = { 0 };
ULONG i_i_i_vector[]= { 0 };
ULONG i_i_i_i_i_vector[]= { 0 };
#if defined (ARM) && defined (G_A64)
ULONG i_i_i_i_i_i_i_vector[]= { 0 };
#endif
#ifdef G_A64
static ULONG i_r_vector[] = { 2 };
static ULONG r_r_vector[]= { 3 };
#else
static ULONG i_r_vector[] = { 6 };
static ULONG r_r_vector[]= { 15 };
#endif

static ULONG *demanded_vector;
int demanded_a_stack_size=0;
int demanded_b_stack_size=0;
int demand_flag;

ULONG *offered_vector;
int offered_a_stack_size=0;
int offered_b_stack_size=0;

static int offered_after_jsr;
static int offered_before_label;

int reachable;

int no_memory_profiling;

#ifdef PROFILE
int no_time_profiling;
int callgraph_profiling;
static LABEL *profile_current_cost_centre_label;
#endif

#define g_add(g1,g2) g_instruction_2(GADD,(g1),(g2))
#define g_and(g1,g2) g_instruction_2(GAND,(g1),(g2))
#define g_asr(g1,g2) g_instruction_2(GASR,(g1),(g2))
#define g_bounds(g1,g2) g_instruction_2(GBOUNDS,(g1),(g2))
#define g_cmp_eq(g1,g2) g_instruction_2(GCMP_EQ,(g1),(g2))
#define g_cmp_gt(g1,g2) g_instruction_2(GCMP_GT,(g1),(g2))
#if defined (I486) || defined (ARM)
# define g_cmp_gtu(g1,g2) g_instruction_2(GCMP_GTU,(g1),(g2))
#endif
#define g_cmp_lt(g1,g2) g_instruction_2(GCMP_LT,(g1),(g2))
#if defined (I486) || defined (ARM)
# define g_cmp_ltu(g1,g2) g_instruction_2(GCMP_LTU,(g1),(g2))
#endif
#define g_cnot(g1) g_instruction_1(GCNOT,(g1))
#define g_div(g1,g2) g_instruction_2(GDIV,(g1),(g2))
#if defined (I486) || defined (ARM) || defined (G_POWER)
# define g_divu(g1,g2) g_instruction_2(GDIVU,(g1),(g2))
#endif
#define g_eor(g1,g2) g_instruction_2(GEOR,(g1),(g2))
#define g_fadd(g1,g2) g_instruction_2(GFADD,(g1),(g2))
#define g_fcmp_eq(g1,g2) g_instruction_2(GFCMP_EQ,(g1),(g2))
#define g_fcmp_gt(g1,g2) g_instruction_2(GFCMP_GT,(g1),(g2))
#define g_fcmp_lt(g1,g2) g_instruction_2(GFCMP_LT,(g1),(g2))
#define g_fdiv(g1,g2) g_instruction_2(GFDIV,(g1),(g2))
#define g_fitor(g1) g_instruction_1(GFITOR,(g1))
#if defined (I486) || defined (ARM)
# define g_floordiv(g1,g2) g_instruction_2(GFLOORDIV,(g1),(g2))
#endif
#define g_fmul(g1,g2) g_instruction_2(GFMUL,(g1),(g2))
#define g_frem(g1,g2) g_instruction_2(GFREM,(g1),(g2))
#define g_frtoi(g1) g_instruction_1(GFRTOI,(g1))
#define g_fsub(g1,g2) g_instruction_2(GFSUB,(g1),(g2))
#define g_lsl(g1,g2) g_instruction_2(GLSL,(g1),(g2))
#define g_lsr(g1,g2) g_instruction_2(GLSR,(g1),(g2))
#define g_rem(g1,g2) g_instruction_2(GREM,(g1),(g2))
#if defined (I486) || defined (ARM)
# define g_mod(g1,g2) g_instruction_2(GMOD,(g1),(g2))
# define g_remu(g1,g2) g_instruction_2(GREMU,(g1),(g2))
#endif
#define g_mul(g1,g2) g_instruction_2(GMUL,(g1),(g2))
#define g_neg(g1) g_instruction_1(GNEG,(g1))
#if defined (I486) || defined (ARM) || defined (G_POWER)
# define g_not(g1) g_instruction_1(GNOT,(g1))
#endif
#define g_or(g1,g2) g_instruction_2(GOR,(g1),(g2))
#define g_keep(g1,g2) g_instruction_2(GKEEP,(g1),(g2))
#define g_fkeep(g1,g2) g_instruction_2(GFKEEP,(g1),(g2))
#define g_sub(g1,g2) g_instruction_2(GSUB,(g1),(g2))
#if defined (I486) || defined (ARM)
#define g_clzb(g1) g_instruction_1(GCLZB,(g1))
#endif

#if defined (G_POWER) || (defined (ARM) && defined (G_A64))
# define g_umulh(g1,g2) g_instruction_2(GUMULH,(g1),(g2))
#endif

#ifdef NEW_DESCRIPTORS
# define MAX_YET_ARGS_NEEDED_ARITY 31
#else
# define MAX_YET_ARGS_NEEDED_ARITY 4
#endif

LABEL *INT_label,*BOOL_label,*CHAR_label,*REAL_label;
LABEL *_STRING__label,*_ARRAY__label;
#if defined (G_A64) && defined (LINUX)
LABEL *_STRING__0_label;
#endif

static LABEL *FILE_label;

static struct basic_block
	*last_INT_descriptor_block,*last_BOOL_descriptor_block,*last_CHAR_descriptor_block,
	*last_REAL_descriptor_block,*last_FILE_descriptor_block,*last__STRING__descriptor_block;

static INSTRUCTION_GRAPH
	last_INT_descriptor_graph,last_BOOL_descriptor_graph,last_CHAR_descriptor_graph,
	last_REAL_descriptor_graph,last_FILE_descriptor_graph,last__STRING__descriptor_graph;

LABEL	*cycle_in_spine_label,*reserve_label;

static LABEL	*halt_label,*cmp_string_label,*eqD_label,
				*slice_string_label,*print_label,*print_sc_label,
				*print_symbol_label,*print_symbol_sc_label,*D_to_S_label,
#if defined (M68000) || defined (ARM)
				*div_label,*mod_label,
#endif
#if defined (ARM) && !defined (G_A64)
				*udiv_label,*ludiv_label,
#endif
#ifdef M68000
				*mul_label,
#endif
				*update_string_label,*equal_string_label,
				*yet_args_needed_label,
				*repl_args_b_label,*push_arg_b_label,*del_args_label,*printD_label,
				*yet_args_needed_labels[MAX_YET_ARGS_NEEDED_ARITY+1],
				*new_ext_reducer_label,*ItoP_label,*create_array_label,
				*create_arrayB_label,*create_arrayC_label,*create_arrayI_label,*create_arrayR_label,*create_r_array_label,
				*create_arrayB__label,*create_arrayC__label,*create_arrayI__label,*create_arrayR__label,*create_r_array__label,
				*print_char_label,*print_int_label,*print_real_label;

#if defined (G_A64) || defined (I486)
static LABEL	*create_arrayI32_label,*create_arrayR32_label,*create_arrayI32__label,*create_arrayR32__label;
#endif

LABEL			*new_int_reducer_label,*channelP_label,*stop_reducer_label,*send_request_label,
				*send_graph_label,*string_to_string_node_label,*int_array_to_node_label,
				*real_array_to_node_label,*cat_string_label;

#ifdef M68000
static LABEL	*add_real,*sub_real,*mul_real,*div_real,*eq_real,*gt_real,*lt_real;
#endif

static LABEL	*i_to_r_real,*r_to_i_real,*sqrt_real,*exp_real,*ln_real,*log10_real,
				*cos_real,*sin_real,*tan_real,*acos_real,*asin_real,*atan_real,*pow_real,
				*entier_real_label,*truncate_real_label,*ceiling_real_label;

LABEL 			*copy_graph_label,*CHANNEL_label,*create_channel_label,*currentP_label,*newP_label,
				*randomP_label,*suspend_label;

#ifdef M68000
static LABEL	*neg_real;
#endif

static LABEL	*small_integers_label,*static_characters_label;

LABEL			*eval_fill_label,*eval_upd_labels[33];

#ifdef NEW_APPLY
LABEL			*add_empty_node_labels[33];
#endif

static LABEL	*print_r_arg_label,*push_t_r_args_label,*push_a_r_args_label,*repl_r_a_args_n_a_label;
LABEL			*index_error_label;

#ifdef G_POWER
LABEL			*r_to_i_buffer_label;
#endif

LABEL			*collect_0_label,*collect_1_label,*collect_2_label,
#if !(defined (I486) && !defined (G_AI64))
				*collect_3_label,
#endif
#ifdef G_POWER
				*collect_00_label,*collect_01_label,*collect_02_label,*collect_03_label,
				*eval_01_label,*eval_11_label,*eval_02_label,*eval_12_label,*eval_22_label,
#endif
#if defined (I486) && defined (GEN_OBJ) && !defined (G_AI64)
				*collect_0l_label,*collect_1l_label,*collect_2l_label,
# ifndef THREAD32
				*end_heap_label,
# endif
#endif
				*system_sp_label,*EMPTY_label;

#ifdef sparc
LABEL			*dot_mul_label,*dot_div_label,*dot_rem_label;
#endif
#ifdef PROFILE
LABEL	*profile_l_label,*profile_l2_label,*profile_n_label,*profile_n2_label,
		*profile_s_label,*profile_s2_label,*profile_r_label,*profile_t_label;
# if defined (G_POWER) || (defined (ARM) && !defined (G_A64))
LABEL	*profile_ti_label;
# endif
#endif

LABEL *enter_label (char *label_name,int label_flags)
{
	struct label_node **label_p,*new_label;

	label_p=&labels;
	while (*label_p!=NULL){
		struct label_node *label;
		int r;
		
		label=*label_p;
		r=strcmp (label_name,label->label_node_label.label_name);
		if (r==0){
			label->label_node_label.label_flags |= label_flags;
			return &label->label_node_label;
		}
		if (r<0)
			label_p=&label->label_node_left;
		else
			label_p=&label->label_node_right;
	}
	
	new_label=fast_memory_allocate_type (struct label_node);
	new_label->label_node_left=NULL;
	new_label->label_node_right=NULL;
	new_label->label_node_label.label_flags=label_flags;
	new_label->label_node_label.label_number=0;
	new_label->label_node_label.label_id=-1;
	new_label->label_node_label.label_name=(char*)fast_memory_allocate (strlen (label_name)+1);
	strcpy (new_label->label_node_label.label_name,label_name);
	
	new_label->label_node_label.label_last_lea_block=NULL;

	*label_p=new_label;
	return &new_label->label_node_label;
}

#if defined (G_A64) && defined (LINUX)
LABEL *enter_label_with_extension (char *label_name,char *label_name_extension,int label_flags)
{
	struct label_node **label_p,*new_label;
	int label_name_length;
	char *label_name_with_extension;

	label_name_length=strlen (label_name);

	label_p=&labels;
	while (*label_p!=NULL){
		struct label_node *label;
		int r;
		
		label=*label_p;
		r=strncmp (label_name,label->label_node_label.label_name,label_name_length);
		if (r==0){
			r=strcmp (label_name_extension,label->label_node_label.label_name+label_name_length);
			if (r==0){
				label->label_node_label.label_flags |= label_flags;
				return &label->label_node_label;
			}
		}
		if (r<0)
			label_p=&label->label_node_left;
		else
			label_p=&label->label_node_right;
	}
	
	new_label=fast_memory_allocate_type (struct label_node);
	new_label->label_node_left=NULL;
	new_label->label_node_right=NULL;
	new_label->label_node_label.label_flags=label_flags;
	new_label->label_node_label.label_number=0;
	new_label->label_node_label.label_id=-1;
	label_name_with_extension
		=(char*)fast_memory_allocate (label_name_length+strlen (label_name_extension)+1);
	strcpy (label_name_with_extension,label_name);
	strcpy (label_name_with_extension+label_name_length,label_name_extension);
	new_label->label_node_label.label_name=label_name_with_extension;
	
	new_label->label_node_label.label_last_lea_block=NULL;

	*label_p=new_label;
	return &new_label->label_node_label;
}
#endif

static int next_label;

#define LTEXT 0
#define LDATA 1

struct local_label *local_labels;

LABEL *new_local_label (int label_flags)
{
	struct local_label *local_label;
	LABEL *label;
	int id;
	
	id=next_label_id++;
	
	local_label=fast_memory_allocate_type (struct local_label);
	
	local_label->local_label_next=local_labels;
	local_labels=local_label;
	
	label=&local_label->local_label_label;
	label->label_number=next_label++;
	label->label_name=NULL;
	label->label_id=id;
	label->label_flags=label_flags;
	
	return label;
}

#define DESCRIPTOR_OFFSET	2
#define ARGUMENTS_OFFSET	STACK_ELEMENT_SIZE

static void code_monadic_real_operator (int g_code)
{
#ifdef G_A64
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;

	graph_1=s_get_b (0);
	graph_2=g_fp_arg (graph_1);

	graph_3=g_instruction_1 (g_code,graph_2);

	graph_4=g_fromf (graph_3);

	s_put_b (0,graph_4);
#else
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6;
	
	graph_2=s_get_b (1);
	graph_1=s_get_b (0);
	graph_3=g_fjoin (graph_1,graph_2);

	graph_4=g_instruction_1 (g_code,graph_3);

	g_fhighlow (graph_5,graph_6,graph_4);

	s_put_b (1,graph_6);
	s_put_b (0,graph_5);
#endif
}

static int eval_label_number;
char eval_label_s [64];

static void code_monadic_sane_operator (LABEL *label)
{
#ifdef M68000
	LABEL *label2;
	INSTRUCTION_GRAPH graph;
	struct block_label *new_label;
	
	sprintf (eval_label_s,"e_%d",eval_label_number++);
	label2=enter_label (eval_label_s,LOCAL_LABEL);
	graph=g_lea (label2);
#endif

	s_push_b (s_get_b (0));
#ifdef G_A64
	s_put_b (1,NULL);
#else
	s_put_b (1,s_get_b (2));
# ifdef M68000
	s_put_b (2,graph);
# else
	s_put_b (2,NULL);
# endif
#endif
	insert_basic_block (JSR_BLOCK,0,SIZE_OF_REAL_IN_STACK_ELEMENTS+1,r_vector,label);

#ifdef M68000
	new_label=fast_memory_allocate_type (struct block_label);
	new_label->block_label_label=label2;
	new_label->block_label_next=NULL;
	
	if (last_block->block_labels==NULL)
		last_block->block_labels=new_label;
	else
		last_block_label->block_label_next=new_label;
	last_block_label=new_label;
#endif
}

static void code_dyadic_sane_operator (LABEL *label)
{
#ifdef M68000
	LABEL *label2;
	INSTRUCTION_GRAPH graph;
	struct block_label *new_label;

	if (!mc68881_flag){
		sprintf (eval_label_s,"e_%d",eval_label_number++);
		label2=enter_label (eval_label_s,LOCAL_LABEL);
		graph=g_lea (label2);
	}
#endif

	s_push_b (s_get_b (0));
	s_put_b (1,s_get_b (2));
#ifdef G_A64
	s_put_b (2,NULL);

	insert_basic_block (JSR_BLOCK,0,2+1,r_r_vector,label);
#else
	s_put_b (2,s_get_b (3));
	s_put_b (3,s_get_b (4));

# ifdef M68000
	if (!mc68881_flag)
		s_put_b (4,graph);
	else
# endif
		s_put_b (4,NULL);

	insert_basic_block (JSR_BLOCK,0,4+1,r_r_vector,label);
#endif

#ifdef M68000
	if (!mc68881_flag){
		new_label=fast_memory_allocate_type (struct block_label);
		new_label->block_label_label=label2;
		new_label->block_label_next=NULL;
			
		if (last_block->block_labels==NULL)
			last_block->block_labels=new_label;
		else
			last_block_label->block_label_next=new_label;
		last_block_label=new_label;
	}
#endif
}

void code_absR (void)
{
	code_monadic_real_operator (GFABS);
}

void code_acosR (VOID)
{
#ifdef M68000
	if (mc68881_flag){
		code_monadic_real_operator (GFACOS);
		return
	}
#endif
	if (acos_real==NULL)
		acos_real=enter_label ("acos_real",IMPORT_LABEL);
	code_monadic_sane_operator (acos_real);
	init_b_stack (SIZE_OF_REAL_IN_STACK_ELEMENTS,r_vector);
}

void code_addI (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;

	graph_1=s_pop_b();
	graph_2=s_get_b (0);
	graph_3=g_add (graph_1,graph_2);
	
	s_put_b (0,graph_3);
}

#if defined (I486) || defined (ARM)
void code_addLU (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6;
	
	graph_3=s_get_b (2);
	graph_2=s_get_b (1);
	graph_1=s_pop_b();

	graph_4=g_new_node (GADDDU,3,3*sizeof (union instruction_parameter));
	graph_4->instruction_parameters[0].p=graph_1;
	graph_4->instruction_parameters[1].p=graph_2;
	graph_4->instruction_parameters[2].p=graph_3;

	graph_5=g_instruction_2 (GRESULT1,graph_4,NULL);
	graph_6=g_instruction_2 (GRESULT0,graph_4,NULL);
	graph_5->instruction_parameters[1].p=graph_6;
	graph_6->instruction_parameters[1].p=graph_5;

	s_put_b (1,graph_5);
	s_put_b (0,graph_6);
}
#endif

#ifndef M68000
static void code_operatorIo (int instruction_code)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;

	graph_1=s_get_b (1);
	graph_2=s_get_b (0);
	graph_3=g_instruction_2_0 (instruction_code,graph_1,graph_2);
	graph_4=g_test_o (graph_3);
	
#ifdef sparc
	if (instruction_code==GMUL_O)
		graph_4->inode_arity=0;
#endif
	
	s_put_b (1,graph_3);
	s_put_b (0,graph_4);	
}

void code_addIo (VOID)
{
	code_operatorIo (GADD_O);
}
#endif

void code_addR (VOID)
{
#ifdef G_A64
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6;

	graph_1=s_pop_b();
	graph_2=g_fp_arg (graph_1);

	graph_3=s_get_b (0);
	graph_4=g_fp_arg (graph_3);

	graph_5=g_fadd (graph_4,graph_2);

	graph_6=g_fromf (graph_5);

	s_put_b (0,graph_6);
#else
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6,graph_7,graph_8,graph_9;

# ifdef M68000	
	if (!mc68881_flag){
		if (add_real==NULL)
			add_real=enter_label ("add_real",IMPORT_LABEL);
		code_dyadic_sane_operator (add_real);
		init_b_stack (2,r_vector);
	} else {
# endif
		graph_1=s_pop_b();
		graph_2=s_pop_b();
		graph_3=g_fjoin (graph_1,graph_2);
	
		graph_5=s_get_b (1);
		graph_4=s_get_b (0);
		graph_6=g_fjoin (graph_4,graph_5);
	
		graph_7=g_fadd (graph_6,graph_3);

		g_fhighlow (graph_8,graph_9,graph_7);

		s_put_b (1,graph_9);
		s_put_b (0,graph_8);
# ifdef M68000
	}
# endif
#endif
}

void code_algtype (int n_constructors)
{
}

void code_andB (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;

	graph_1=s_pop_b();
	graph_2=s_get_b (0);
	graph_3=g_and (graph_1,graph_2);
	
	s_put_b (0,graph_3);
}

void code_and (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;

	graph_1=s_pop_b();
	graph_2=s_get_b (0);
	graph_3=g_and (graph_1,graph_2);

	s_put_b (0,graph_3);
}

void code_asinR (VOID)
{
#ifdef M68000
	if (mc68881_flag){
		code_monadic_real_operator (GFASIN);
		return;
	}
#endif
	if (asin_real==NULL)
		asin_real=enter_label ("asin_real",IMPORT_LABEL);
	code_monadic_sane_operator (asin_real);
	init_b_stack (SIZE_OF_REAL_IN_STACK_ELEMENTS,r_vector);
}

void code_atanR (VOID)
{
#ifdef M68000
	if (!mc68881_flag){
#endif
		if (atan_real==NULL)
			atan_real=enter_label ("atan_real",IMPORT_LABEL);
		code_monadic_sane_operator (atan_real);
		init_b_stack (SIZE_OF_REAL_IN_STACK_ELEMENTS,r_vector);
#ifdef M68000
	} else
		code_monadic_real_operator (GFATAN);
#endif
}

static void define_eval_upd_label_n (int arity)
{
	char eval_upd_label_name[32];

#if defined (G_AI64) && defined (LINUX)
	if (rts_got_flag){
		sprintf (eval_upd_label_name,"eval_upd_%d_",arity);
		eval_upd_labels[arity]=enter_label (eval_upd_label_name,IMPORT_LABEL | USE_GOT_LABEL);
		return;
	}
#endif
	sprintf (eval_upd_label_name,"eval_upd_%d",arity);
	eval_upd_labels[arity]=enter_label (eval_upd_label_name,IMPORT_LABEL);
}

void code_build (char descriptor_name[],int arity,char *code_name)
{
	INSTRUCTION_GRAPH graph_2,graph_3,graph_4;
	LABEL *descriptor_label,*code_label;

	if (strcmp (code_name,"__hnf")==0){
		code_buildh (descriptor_name,arity);
#ifdef PROFILE
	} else if (callgraph_profiling){
		code_build_u (descriptor_name,arity<0 ? 1 : arity,0,code_name);
#endif
	} else {
		int n_arguments;
		union instruction_parameter *parameter;

		code_label=enter_label (code_name,NODE_ENTRY_LABEL);
		code_label->label_arity=arity;

		if (descriptor_name[0]=='_' && descriptor_name[1]=='_' && descriptor_name[2]=='\0')
			descriptor_label=NULL;
		else
			descriptor_label=enter_label (descriptor_name,DATA_LABEL);

		if (arity<-2)
			arity=1;

		if (code_label->label_flags & EA_LABEL
			&&	code_label->label_ea_label!=eval_fill_label
			&&	arity>=0 && eval_upd_labels[arity]==NULL)
		{
			define_eval_upd_label_n (arity);
		}

		if (arity<0)
			arity=1;
	
		code_label->label_descriptor=descriptor_label;

		if (arity<2){
			graph_2=g_create_m (3);
			graph_2->instruction_parameters[1].p=NULL;
			graph_2->instruction_parameters[2].p=NULL;
		} else
			graph_2=g_create_m (arity+1);
		parameter=&graph_2->instruction_parameters[0];

		graph_3=g_lea (code_label);
		parameter->p=graph_3;
		++parameter;
			
		for (n_arguments=arity; n_arguments>0; --n_arguments){
			graph_4=s_pop_a();
			parameter->p=graph_4;
			++parameter;
		}
				
		s_push_a (graph_2);
	}
}

#if defined (G_A64) && defined (LINUX)
static LABEL *enter_got_label (char *descriptor_name,int arity,int label_flags)
{
	static char arity_extension[24];

	sprintf (arity_extension,"_%d",arity);
	return enter_label_with_extension (descriptor_name,arity_extension,label_flags | USE_GOT_LABEL);
}
#endif

void code_buildh (char descriptor_name[],int arity)
{
	INSTRUCTION_GRAPH graph_2,graph_3,graph_4,graph_5,graph_6;
	LABEL *descriptor_label;

	descriptor_label=enter_label (descriptor_name,DATA_LABEL);

	if (!parallel_flag && arity==0){
#if defined (G_A64) && defined (LINUX)
		if (pic_flag && descriptor_label->label_flags & USE_GOT_LABEL){
			descriptor_label=enter_label_with_extension (descriptor_name,"_Z",DATA_LABEL | USE_GOT_LABEL);
			graph_4=g_lea (descriptor_label);
		} else
#endif
		graph_4=g_lea_i (descriptor_label,ARITY_0_DESCRIPTOR_OFFSET+NODE_POINTER_OFFSET);
		s_push_a (graph_4);
		return;
	}

	if (!parallel_flag &&
		descriptor_label->label_last_lea_block==last_block &&
		descriptor_label->label_last_lea_arity==arity)
	{
		graph_2=descriptor_label->label_last_lea;
	} else {
#if defined (G_A64) && defined (LINUX)
		if (pic_flag && descriptor_label->label_flags & USE_GOT_LABEL){
			descriptor_label=enter_got_label (descriptor_name,arity,DATA_LABEL);
			graph_2=g_lea (descriptor_label);
		} else
#endif
		graph_2=g_load_des_i (descriptor_label,arity);

		if (!parallel_flag ){
			descriptor_label->label_last_lea=graph_2;
			descriptor_label->label_last_lea_block=last_block;
			descriptor_label->label_last_lea_arity=arity;
		}
	}

	switch (arity){
		case 0:
			graph_4=g_create_1 (graph_2);
			break;
		case 1:
			graph_5=s_pop_a();
			graph_4=g_create_2 (graph_2,graph_5);
			break;
		case 2:
			graph_5=s_pop_a();
			graph_6=s_pop_a();
			graph_4=g_create_3 (graph_2,graph_5,graph_6);
			break;
		default:
		{
			int n_arguments;
			union instruction_parameter *parameter;
			
			graph_5=s_pop_a();
			
			graph_3=g_create_m (arity-1);
			parameter=graph_3->instruction_parameters;
			for (n_arguments=arity-1; n_arguments>0; --n_arguments){
				graph_6=s_pop_a();
				parameter->p=graph_6;
				++parameter;
			}

			graph_4=g_create_3 (graph_2,graph_5,graph_3);
		}
	}
	
	s_push_a (graph_4);
}

static INSTRUCTION_GRAPH lea_record_descriptor (char descriptor_name[])
{
	LABEL *descriptor_label;
	
	descriptor_label=enter_label (descriptor_name,DATA_LABEL);

	if (!parallel_flag && descriptor_label->label_last_lea_block==last_block)
		return descriptor_label->label_last_lea;
	else {
#if defined (G_A64) && defined (LINUX)
		if (pic_flag && descriptor_label->label_flags & USE_GOT_LABEL){
			LABEL *descriptor_label_0;

			descriptor_label_0=enter_got_label (descriptor_name,0,DATA_LABEL);
			return g_lea (descriptor_label_0);
		} else
#endif
		{
		INSTRUCTION_GRAPH graph_1;

		graph_1=g_load_des_i (descriptor_label,0);

		if (!parallel_flag){
			descriptor_label->label_last_lea=graph_1;
			descriptor_label->label_last_lea_block=last_block;
		}

		return graph_1;
		}
	}
}

void code_buildhr (char descriptor_name[],int a_size,int b_size)
{
	INSTRUCTION_GRAPH graph_2,graph_3,graph_4,graph_5,graph_6;
	
	graph_2=lea_record_descriptor (descriptor_name);

	switch (a_size+b_size){
		case 0:
			graph_4=g_create_1 (graph_2);
			break;
		case 1:
			if (a_size!=0)
				graph_5=s_pop_a();
			else
				graph_5=s_pop_b();
			graph_4=g_create_2 (graph_2,graph_5);
			break;
		case 2:
			switch (b_size){
				case 0:
					graph_5=s_pop_a();
					graph_6=s_pop_a();
					break;				
				case 1:
					graph_5=s_pop_a();
					graph_6=s_pop_b();
					break;
				default:
					graph_5=s_pop_b();
					graph_6=s_pop_b();
			}
			graph_4=g_create_3 (graph_2,graph_5,graph_6);
			break;
		default:
		{
			union instruction_parameter *parameter;
			
			if (a_size>0){
				graph_5=s_pop_a();
				--a_size;
			} else {
				graph_5=s_pop_b();
				--b_size;
			}
			
			graph_3=g_create_m (a_size+b_size);
			
			parameter=graph_3->instruction_parameters;

			while (a_size>0){
				parameter->p=s_pop_a();
				++parameter;
				--a_size;
			}

			while (b_size>0){
				parameter->p=s_pop_b();
				++parameter;
				--b_size;
			}

			graph_4=g_create_3 (graph_2,graph_5,graph_3);
		}
	}
	
	s_push_a (graph_4);
}

void code_build_r (char descriptor_name[],int a_size,int b_size,int a_offset,int b_offset)
{
	INSTRUCTION_GRAPH graph_2,graph_3,graph_4,graph_5,graph_6;

	graph_2=lea_record_descriptor (descriptor_name);

	switch (a_size+b_size){
		case 0:
			graph_4=g_create_1 (graph_2);
			break;
		case 1:
			if (a_size!=0)
				graph_5=s_get_a (a_offset);
			else
				graph_5=s_get_b (b_offset);
			graph_4=g_create_2 (graph_2,graph_5);
			break;
		case 2:
			switch (b_size){
				case 0:
					graph_5=s_get_a (a_offset);
					graph_6=s_get_a (a_offset+1);
					break;				
				case 1:
					graph_5=s_get_a (a_offset);
					graph_6=s_get_b (b_offset);
					break;
				default:
					graph_5=s_get_b (b_offset);
					graph_6=s_get_b (b_offset+1);
			}
			graph_4=g_create_3 (graph_2,graph_5,graph_6);
			break;
		default:
		{
			union instruction_parameter *parameter;
			
			if (a_size>0){
				graph_5=s_get_a (a_offset);
				++a_offset;
				--a_size;
			} else {
				graph_5=s_get_b (b_offset);
				++b_offset;
				--b_size;
			}
			
			graph_3=g_create_m (a_size+b_size);
			
			parameter=graph_3->instruction_parameters;

			while (a_size>0){
				parameter->p=s_get_a (a_offset);
				++parameter;
				++a_offset;
				--a_size;
			}

			while (b_size>0){
				parameter->p=s_get_b (b_offset);
				++parameter;
				++b_offset;
				--b_size;
			}

			graph_4=g_create_3 (graph_2,graph_5,graph_3);
		}
	}
	
	s_push_a (graph_4);
}

void code_build_u (char descriptor_name[],int a_size,int b_size,char *code_name)
{
	INSTRUCTION_GRAPH graph_2,graph_3,graph_4;
	LABEL *descriptor_label,*code_label;
	int n_arguments;
	union instruction_parameter *parameter;

#ifdef PROFILE
	if (callgraph_profiling)
		++b_size;
#endif

	code_label=enter_label (code_name,NODE_ENTRY_LABEL);
	code_label->label_arity=a_size+b_size+(b_size<<8);

	if (descriptor_name[0]=='_' && descriptor_name[1]=='_' && descriptor_name[2]=='\0')
		descriptor_label=NULL;
	else
		descriptor_label=enter_label (descriptor_name,DATA_LABEL);

	code_label->label_descriptor=descriptor_label;

	if (a_size+b_size<2){
		graph_2=g_create_m (3);
		graph_2->instruction_parameters[1].p=NULL;
		graph_2->instruction_parameters[2].p=NULL;
	} else
		graph_2=g_create_m (a_size+b_size+1);
	parameter=&graph_2->instruction_parameters[0];

	graph_3=g_lea (code_label);
	parameter->p=graph_3;
	++parameter;
		
	for (n_arguments=a_size; n_arguments>0; --n_arguments){
		graph_4=s_pop_a();
		parameter->p=graph_4;
		++parameter;
	}

#ifdef PROFILE
	if (callgraph_profiling){
		INSTRUCTION_GRAPH graph_5;

		--b_size;

		if (profile_current_cost_centre_label==NULL)
# if (defined (I486) && !defined (G_AI64) && !defined (LINUX_ELF)) || defined (MACH_O) || defined (MACH_O64)
			profile_current_cost_centre_label=enter_label ("_profile_current_cost_centre",IMPORT_LABEL | DATA_LABEL);
# else
			profile_current_cost_centre_label=enter_label ("profile_current_cost_centre",IMPORT_LABEL | DATA_LABEL);
# endif
		graph_4=g_lea (profile_current_cost_centre_label);
		graph_5=g_load_id (0,graph_4);
		parameter[b_size].p=graph_5;
	}
#endif

	for (n_arguments=b_size; n_arguments>0; --n_arguments){
		graph_4=s_pop_b();
		parameter->p=graph_4;
		++parameter;
	}
			
	s_push_a (graph_2);
}

static INSTRUCTION_GRAPH g_BOOL_label (void)
{
#if defined (G_AI64) && defined (LINUX)
	if (rts_got_flag){
		if (BOOL_label==NULL)
			BOOL_label=enter_label ("BOOL_0",IMPORT_LABEL | DATA_LABEL | USE_GOT_LABEL);
		return g_lea (BOOL_label);
	}
#endif
	if (BOOL_label==NULL)
		BOOL_label=enter_label ("BOOL",IMPORT_LABEL | DATA_LABEL);
	return g_load_des_i (BOOL_label,0);
}

static INSTRUCTION_GRAPH g_FILE_label (void)
{
#if defined (G_AI64) && defined (LINUX)
	if (rts_got_flag){
		if (FILE_label==NULL)
			FILE_label=enter_label ("FILE_0",IMPORT_LABEL | DATA_LABEL | USE_GOT_LABEL);
		return g_lea (FILE_label);
	}
#endif
	if (FILE_label==NULL)
		FILE_label=enter_label ("FILE",IMPORT_LABEL | DATA_LABEL);
	return g_load_des_i (FILE_label,0);
}

void code_buildB (int value)
{
	INSTRUCTION_GRAPH graph_2,graph_3,graph_4;

#ifdef BOOL_REGISTER
	graph_2=g_g_register (BOOL_REGISTER);
#else
	if (!parallel_flag && last_BOOL_descriptor_block==last_block)
		graph_2=last_BOOL_descriptor_graph;
	else {
		graph_2=g_BOOL_label();

		if (!parallel_flag){
			last_BOOL_descriptor_graph=graph_2;
			last_BOOL_descriptor_block=last_block;
		}
	}
#endif
	
#if defined (I486) || defined (ARM)
	graph_3=g_load_i (value);
#else
	graph_3=g_load_i (-value);
#endif
	graph_4=g_create_2 (graph_2,graph_3);
	
	s_push_a (graph_4);
}

void code_buildB_b (int b_offset)
{
	INSTRUCTION_GRAPH graph_2,graph_3,graph_4;

#ifdef BOOL_REGISTER
	graph_2=g_g_register (BOOL_REGISTER);
#else
	if (!parallel_flag && last_BOOL_descriptor_block==last_block)
		graph_2=last_BOOL_descriptor_graph;
	else {
		graph_2=g_BOOL_label();

		if (!parallel_flag){
			last_BOOL_descriptor_graph=graph_2;
			last_BOOL_descriptor_block=last_block;
		}
	}
#endif
	
	graph_3=s_get_b (b_offset);
	graph_4=g_create_2 (graph_2,graph_3);
	
	s_push_a (graph_4);
}

static INSTRUCTION_GRAPH char_descriptor_graph (void)
{
	INSTRUCTION_GRAPH graph;
	
#ifdef REAL_REGISTER
	graph=g_g_register (CHAR_REGISTER);
#else
	if (!parallel_flag && last_CHAR_descriptor_block==last_block)
		graph=last_CHAR_descriptor_graph;
	else {
#if defined (G_AI64) && defined (LINUX)
		if (rts_got_flag){
			if (CHAR_label==NULL)
				CHAR_label=enter_label ("CHAR_0",IMPORT_LABEL | DATA_LABEL | USE_GOT_LABEL);
			graph=g_lea (CHAR_label);
		} else
#endif
		{
		if (CHAR_label==NULL)
			CHAR_label=enter_label ("CHAR",IMPORT_LABEL | DATA_LABEL);
		graph=g_load_des_i (CHAR_label,0);
		}

		if (!parallel_flag){
			last_CHAR_descriptor_graph=graph;
			last_CHAR_descriptor_block=last_block;
		}
	}
#endif
	return graph;
}

void code_buildC (int value)
{
	INSTRUCTION_GRAPH graph_2,graph_3,graph_4;

	if (!parallel_flag){
#if defined (G_AI64) && defined (LINUX)
		if (rts_got_flag){
			LABEL *static_characters_n_label;
			static char static_characters_n_s[40];

			sprintf (static_characters_n_s,"static_characters_%d",(int)value);
			static_characters_n_label=enter_label (static_characters_n_s,IMPORT_LABEL | DATA_LABEL | USE_GOT_LABEL);
			graph_4=g_lea (static_characters_n_label);
		} else
#endif
		{
		if (static_characters_label==NULL)
			static_characters_label=enter_label ("static_characters",IMPORT_LABEL | DATA_LABEL);

		graph_4=g_lea_i (static_characters_label,(value<<(1+STACK_ELEMENT_LOG_SIZE))+NODE_POINTER_OFFSET);
		}
		s_push_a (graph_4);
		return;
	}

	graph_2=char_descriptor_graph();		
	graph_3=g_load_i (value);
	graph_4=g_create_2 (graph_2,graph_3);
	
	s_push_a (graph_4);
}

void code_buildC_b (int b_offset)
{
	INSTRUCTION_GRAPH graph_2,graph_3,graph_4;

	graph_2=char_descriptor_graph();		
	graph_3=s_get_b (b_offset);
	graph_4=g_create_2 (graph_2,graph_3);
	
	s_push_a (graph_4);
}

void code_buildF_b (int b_offset)
{
	INSTRUCTION_GRAPH graph_2,graph_3,graph_4,graph_5;
	
	if (!parallel_flag && last_FILE_descriptor_block==last_block)
		graph_2=last_FILE_descriptor_graph;
	else {
		graph_2=g_FILE_label();

		if (!parallel_flag){
			last_FILE_descriptor_graph=graph_2;
			last_FILE_descriptor_block=last_block;
		}
	}
	
	graph_3=s_get_b (b_offset+1);
	graph_4=s_get_b (b_offset);
	
	graph_5=g_create_3 (graph_2,graph_3,graph_4);

	s_push_a (graph_5);
}

static INSTRUCTION_GRAPH int_descriptor_graph (void)
{
	INSTRUCTION_GRAPH graph;
	
#ifdef INT_REGISTER
	graph=g_g_register (INT_REGISTER);
#else
	if (!parallel_flag && last_INT_descriptor_block==last_block)
		graph=last_INT_descriptor_graph;
	else {
#if defined (G_AI64) && defined (LINUX)
		if (rts_got_flag){
			if (INT_label==NULL)
				INT_label=enter_label ("INT_0",IMPORT_LABEL | DATA_LABEL | USE_GOT_LABEL);
			graph=g_lea (INT_label);
		} else
#endif
		{
		if (INT_label==NULL)
			INT_label=enter_label ("INT",IMPORT_LABEL | DATA_LABEL);

		graph=g_load_des_i (INT_label,0);
		}

		if (!parallel_flag){
			last_INT_descriptor_graph=graph;
			last_INT_descriptor_block=last_block;
		}
	}
#endif
	return graph;
}

void code_buildI (CleanInt value)
{
	INSTRUCTION_GRAPH graph_3,graph_4,graph_5;

#ifndef G_A64
	if (!parallel_flag && (unsigned long)value<(unsigned long)33){
#else
	if (!parallel_flag && (uint_64)value<(uint_64)33){
#endif
#if defined (G_AI64) && defined (LINUX)
		if (rts_got_flag){
			LABEL *small_integers_n_label;
			static char small_integers_n_s[40];

			sprintf (small_integers_n_s,"small_integers_%d",(int)value);
			small_integers_n_label=enter_label (small_integers_n_s,IMPORT_LABEL | DATA_LABEL | USE_GOT_LABEL);
			graph_5=g_lea (small_integers_n_label);
		} else
#endif
		{
		if (small_integers_label==NULL)
			small_integers_label=enter_label ("small_integers",IMPORT_LABEL | DATA_LABEL);
	
		graph_5=g_lea_i (small_integers_label,(value<<(STACK_ELEMENT_LOG_SIZE+1))+NODE_POINTER_OFFSET);
		}

		s_push_a (graph_5);
		return;
	}

	graph_3=int_descriptor_graph();
	graph_4=g_load_i (value);
	graph_5=g_create_2 (graph_3,graph_4);
	
	s_push_a (graph_5);
}

void code_buildI_b (int b_offset)
{
	INSTRUCTION_GRAPH graph_3,graph_4,graph_5;

	graph_3=int_descriptor_graph();
	graph_4=s_get_b (b_offset);
	graph_5=g_create_2 (graph_3,graph_4);
	
	s_push_a (graph_5);
}

static INSTRUCTION_GRAPH real_descriptor_graph (void)
{
	INSTRUCTION_GRAPH graph;

#ifdef REAL_REGISTER
	graph=g_g_register (REAL_REGISTER);
#else
	if (!parallel_flag && last_REAL_descriptor_block==last_block)
		graph=last_REAL_descriptor_graph;
	else {
		if (REAL_label==NULL)
			REAL_label=enter_label ("REAL",IMPORT_LABEL | DATA_LABEL);

		graph=g_load_des_i (REAL_label,0);

		if (!parallel_flag){
			last_REAL_descriptor_graph=graph;
			last_REAL_descriptor_block=last_block;
		}
	}
#endif

	return graph;
}

void code_buildR (double value)
{
	INSTRUCTION_GRAPH graph_2,graph_3,graph_4,graph_5;

	graph_2=real_descriptor_graph();

	if (!mc68881_flag){
		DOUBLE r=value;
		
		graph_3=g_load_i (((long*)&r)[0]);
		graph_4=g_load_i (((long*)&r)[1]);		
		graph_5=g_create_3 (graph_2,graph_3,graph_4);
	} else {
		graph_3=g_fload_i (value);
		graph_5=g_create_r (graph_2,graph_3);
	}

	s_push_a (graph_5);
}

void code_buildR_b (int b_offset)
{
	INSTRUCTION_GRAPH graph_2,graph_3,graph_4,graph_5;

	graph_2=real_descriptor_graph();

	graph_3=s_get_b (b_offset);
#ifndef G_A64
	graph_4=s_get_b (b_offset+1);
#endif

#ifdef M68000
	if (!mc68881_flag)		
		graph_5=g_create_3 (graph_2,graph_3,graph_4);
	else
#endif
#ifdef G_A64
	graph_5=g_create_r (graph_2,g_fp_arg (graph_3));
#else
		graph_5=g_create_r (graph_2,g_fjoin (graph_3,graph_4));
#endif
	s_push_a (graph_5);
}

void code_buildAC (char *string,int string_length)
{
	INSTRUCTION_GRAPH graph_0;
	LABEL *str_label;

	str_label=w_code_descriptor_length_and_string (string,string_length);
#if NODE_POINTER_OFFSET
	graph_0=g_lea_i (str_label,NODE_POINTER_OFFSET);
#else
	graph_0=g_lea (str_label);
#endif

	s_push_a (graph_0);
}

void code_CtoI (VOID)
{
}

void code_cmpS (int a_offset_1,int a_offset_2)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	if (cmp_string_label==NULL)
		cmp_string_label=enter_label ("cmp_string",IMPORT_LABEL);
		
	graph_1=s_get_a (a_offset_1);
	graph_2=s_get_a (a_offset_2);
	
	s_push_a (graph_2);
	s_push_a (graph_1);

	s_push_b (NULL);
	insert_basic_block (JSR_BLOCK,2,0+1,e_vector,cmp_string_label);
	
	init_b_stack (1,i_vector);
}

void code_ceilingR (VOID)
{
	if (ceiling_real_label==NULL)
		ceiling_real_label=enter_label ("ceiling_real",IMPORT_LABEL);

#ifdef G_A64
	s_push_b (s_get_b (0));
	s_put_b (1,NULL);
	insert_basic_block (JSR_BLOCK,0,1+1,r_vector,ceiling_real_label);
#else
	s_push_b (s_get_b (0));
	s_put_b (1,s_get_b (2));
	s_put_b (2,NULL);

	insert_basic_block (JSR_BLOCK,0,2+1,r_vector,ceiling_real_label);
#endif

	init_b_stack (1,i_vector);
}

#if defined (I486) || defined (ARM)
void code_clzb (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	graph_1=s_get_b (0);
	graph_2=g_clzb (graph_1);
	
	s_put_b (0,graph_2);
}
#endif

void code_CtoAC (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	
	if (!parallel_flag && last__STRING__descriptor_block==last_block)
		graph_1=last__STRING__descriptor_graph;
	else {
#if defined (G_AI64) && defined (LINUX)
		if (rts_got_flag){
			if (_STRING__0_label==NULL)
				_STRING__0_label=enter_label ("__STRING___0",IMPORT_LABEL | DATA_LABEL | USE_GOT_LABEL);
			graph_1=g_lea (_STRING__0_label);
		} else
#endif
		{
		if (_STRING__label==NULL)
			_STRING__label=enter_label ("__STRING__",IMPORT_LABEL | DATA_LABEL);

		graph_1=g_load_des_i (_STRING__label,0);
		}

		if (!parallel_flag){
			last__STRING__descriptor_graph=graph_1;
			last__STRING__descriptor_block=last_block;
		}
	}

	graph_2=g_load_i (1);
	graph_3=s_pop_b();
#if !(defined (I486) || defined (ARM))
	graph_3=g_lsl (g_load_i (24),graph_3);
#endif

#ifdef ARRAY_SIZE_BEFORE_DESCRIPTOR
	graph_4=g_create_3 (graph_2,graph_1,graph_3);
	graph_4=g_add (g_load_i (STACK_ELEMENT_SIZE),graph_4);
#else
	graph_4=g_create_3 (graph_1,graph_2,graph_3);
#endif

	s_push_a (graph_4);
}

static LABEL *enter_rts_label (char *label_name)
{
	return enter_label (label_name,
#if defined (G_AI64) && defined (LINUX)
			rts_got_flag ? IMPORT_LABEL | USE_GOT_LABEL : IMPORT_LABEL);
#else
			IMPORT_LABEL);
#endif
}

static void code_create_lazy_array (VOID)
{	
	if (create_array_label==NULL)
		create_array_label=enter_rts_label ("create_array");

	s_push_b (s_get_b (0));
	s_put_b (1,NULL);
	insert_basic_block (JSR_BLOCK,1,1+1,i_vector,create_array_label);
	
	init_a_stack (1);
}

static void code_create_arrayB (VOID)
{
	if (create_arrayB_label==NULL)
		create_arrayB_label=enter_rts_label ("create_arrayB");
	
	s_push_b (s_get_b (0));
	s_put_b (1,s_get_b (2));
	s_put_b (2,NULL);
	insert_basic_block (JSR_BLOCK,0,2+1,i_i_vector,create_arrayB_label);
	
	init_a_stack (1);
}

static void code_create_arrayC (VOID)
{
	if (create_arrayC_label==NULL)
		create_arrayC_label=enter_rts_label ("create_arrayC");

	s_push_b (s_get_b (0));
	s_put_b (1,s_get_b (2));
	s_put_b (2,NULL);
	insert_basic_block (JSR_BLOCK,0,2+1,i_i_vector,create_arrayC_label);
	
	init_a_stack (1);
}

INSTRUCTION_GRAPH g_create_unboxed_int_array (int n_elements)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	int n;

	graph_1=g_new_node (GCREATE_U,n_elements+3,(n_elements+3)*sizeof (union instruction_parameter));

#if defined (G_AI64) && defined (LINUX)
	if (rts_got_flag){
		if (_ARRAY__label==NULL)
			_ARRAY__label=enter_label ("__ARRAY___0",IMPORT_LABEL | DATA_LABEL | USE_GOT_LABEL);
		graph_2=g_lea (_ARRAY__label);
	} else
#endif
	{
	if (_ARRAY__label==NULL)
		_ARRAY__label=enter_label ("__ARRAY__",IMPORT_LABEL | DATA_LABEL);
	graph_2=g_load_des_i (_ARRAY__label,0);
	}

	graph_1->instruction_parameters[0].p=graph_2;
	graph_1->instruction_parameters[1].p=g_load_i (n_elements);
	graph_1->instruction_parameters[2].p=int_descriptor_graph();

	for (n=0; n<n_elements; ++n)
		graph_1->instruction_parameters[3+n].p=NULL;
	
	return graph_1;
}

#define LESS_UNSIGNED(a,b) ((unsigned long)(a)<(unsigned long)(b))

static void code_create_arrayI (VOID)
{
	INSTRUCTION_GRAPH graph_1;

	graph_1=s_get_b (0);

	if (graph_1->instruction_code==GLOAD_I && graph_1->instruction_parameters[0].i==0){
		INSTRUCTION_GRAPH graph_2;

		s_pop_b();
		s_pop_b();

		graph_2 = g_create_unboxed_int_array (0);
					
		s_push_a (graph_2);
	} else {
		if (create_arrayI_label==NULL)
			create_arrayI_label=enter_rts_label ("create_arrayI");
		
		s_push_b (graph_1);
		s_put_b (1,s_get_b (2));
		s_put_b (2,NULL);
		insert_basic_block (JSR_BLOCK,0,2+1,i_i_vector,create_arrayI_label);
		
		init_a_stack (1);
	}
}

#if defined (G_A64) || defined (I486)
static void code_create_arrayI32 (VOID)
{
	if (create_arrayI32_label==NULL)
		create_arrayI32_label=enter_rts_label ("create_arrayI32");

	s_push_b (s_get_b (0));
	s_put_b (1,s_get_b (2));
	s_put_b (2,NULL);
	insert_basic_block (JSR_BLOCK,0,2+1,i_i_vector,create_arrayI32_label);

	init_a_stack (1);
}
#endif

static void code_create_arrayR (VOID)
{
	if (create_arrayR_label==NULL)
		create_arrayR_label=enter_rts_label ("create_arrayR");
	
#ifdef M68000
	if (!mc68881_flag){
		LABEL *label2;
		INSTRUCTION_GRAPH graph;
		struct block_label *new_label;
	
		sprintf (eval_label_s,"e_%d",eval_label_number++);
		label2=enter_label (eval_label_s,LOCAL_LABEL);
		graph=g_lea (label2);

		s_push_b (s_get_b (0));
		s_put_b (1,s_get_b (2));
		s_put_b (2,s_get_b (3));
		s_put_b (3,graph);
		insert_basic_block (JSR_BLOCK,0,3+1,i_r_vector,create_arrayR_label);		

		new_label=fast_memory_allocate_type (struct block_label);
		new_label->block_label_label=label2;
		new_label->block_label_next=NULL;
		
		if (last_block->block_labels==NULL)
			last_block->block_labels=new_label;
		else
			last_block_label->block_label_next=new_label;
		last_block_label=new_label;	
	} else {
#endif
		s_push_b (s_get_b (0));
		s_put_b (1,s_get_b (2));
#ifdef G_A64
		s_put_b (2,NULL);
		insert_basic_block (JSR_BLOCK,0,2+1,i_r_vector,create_arrayR_label);
#else
		s_put_b (2,s_get_b (3));
		s_put_b (3,NULL);
		insert_basic_block (JSR_BLOCK,0,3+1,i_r_vector,create_arrayR_label);
#endif
#ifdef M68000
	}
#endif
	
	init_a_stack (1);
}

#if defined (G_A64) || defined (I486)
static void code_create_arrayR32 (VOID)
{
	if (create_arrayR32_label==NULL)
		create_arrayR32_label=enter_rts_label ("create_arrayR32");

	s_push_b (s_get_b (0));
	s_put_b (1,s_get_b (2));
# ifdef G_A64
	s_put_b (2,NULL);
	insert_basic_block (JSR_BLOCK,0,2+1,i_r_vector,create_arrayR32_label);
# else
	s_put_b (2,s_get_b (3));
	s_put_b (3,NULL);
	insert_basic_block (JSR_BLOCK,0,3+1,i_r_vector,create_arrayR32_label);
# endif
	
	init_a_stack (1);
}
#endif

static void code_create_r_array (char element_descriptor[],int a_size,int b_size)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	LABEL *descriptor;
		
	if (create_r_array_label==NULL)
		create_r_array_label=enter_rts_label ("create_R_array");

	graph_1=s_pop_b();

	descriptor=enter_label (element_descriptor,DATA_LABEL);
#if defined (G_A64) && defined (LINUX)
	if (pic_flag && descriptor->label_flags & USE_GOT_LABEL){
		descriptor=enter_got_label (element_descriptor,0,DATA_LABEL);
		graph_2=g_lea (descriptor);
	} else
#endif
	graph_2=g_load_des_i (descriptor,0);

	graph_3=g_load_i (a_size+b_size);
	graph_4=g_load_i (a_size);

#if defined (I486)
	{
		INSTRUCTION_GRAPH graph;
		struct block_label *new_label;
		LABEL *label;

		sprintf (eval_label_s,"e_%d",eval_label_number++);
		label=enter_label (eval_label_s,LOCAL_LABEL);
		graph=g_lea (label);

		s_push_b (graph);
		s_push_b (graph_1);
		s_push_b (graph_2);
		s_push_b (graph_3);
		s_push_b (graph_4);
		insert_basic_block_with_extra_parameters_on_stack (JSR_BLOCK,0,4+1,i_i_i_i_i_vector,a_size,b_size,create_r_array_label);

		new_label=fast_memory_allocate (sizeof (struct block_label));
		new_label->block_label_label=label;
		new_label->block_label_next=NULL;
	
		if (last_block->block_labels==NULL)
			last_block->block_labels=new_label;
		else
			last_block_label->block_label_next=new_label;
		last_block_label=new_label;
	}
#else
	s_push_b (NULL);
	s_push_b (graph_1);
	s_push_b (graph_2);
	s_push_b (graph_3);
	s_push_b (graph_4);
	insert_basic_block_with_extra_parameters_on_stack (JSR_BLOCK,0,4+1,i_i_i_i_i_vector,a_size,b_size,create_r_array_label);
#endif

	if (a_size!=0){
		s_put_a (a_size,s_get_a (0));
		code_pop_a (a_size);	
	}
	
	code_pop_b (b_size);

	init_a_stack (1);
}

static int is__rocid (char *element_descriptor)
{
	return (element_descriptor[1]=='R' && element_descriptor[2]=='O' && element_descriptor[3]=='C' &&
			element_descriptor[4]=='I' && element_descriptor[5]=='D' && element_descriptor[6]=='\0');
}

static int is__orld (char *element_descriptor)
{
	return (element_descriptor[1]=='O' && element_descriptor[2]=='R' && element_descriptor[3]=='L' &&
			element_descriptor[4]=='D' && element_descriptor[5]=='\0');
}

void code_create_array (char element_descriptor[],int a_size,int b_size)
{
	switch (element_descriptor[0]){
		case 'B':
			if (element_descriptor[1]=='O' && element_descriptor[2]=='O' && element_descriptor[3]=='L' &&
				element_descriptor[4]=='\0')
			{
				code_create_arrayB();
				return;	
			}
			break;
		case 'C':
			if (element_descriptor[1]=='H' && element_descriptor[2]=='A' && element_descriptor[3]=='R' &&
				element_descriptor[4]=='\0')
			{
				code_create_arrayC();
				return;	
			}
			break;		
		case 'I':
			if (element_descriptor[1]=='N' && element_descriptor[2]=='T'){
				if (element_descriptor[3]=='\0'){
					code_create_arrayI();
					return;
				}
#if defined (G_A64) || defined (I486)
				if (element_descriptor[3]=='3' && element_descriptor[4]=='2' && element_descriptor[5]=='\0'){
					code_create_arrayI32();
					return;
				}
#endif
			}
			break;
		case 'P':
			if (is__rocid (element_descriptor)){
				code_create_arrayI();
				return;	
			}
			break;
		case 'R':
			if (element_descriptor[1]=='E' && element_descriptor[2]=='A' && element_descriptor[3]=='L'){
				if (element_descriptor[4]=='\0'){
					code_create_arrayR();
					return;
				}
#if defined (G_A64) || defined (I486)
				if (element_descriptor[4]=='3' && element_descriptor[5]=='2' && element_descriptor[6]=='\0'){
					code_create_arrayR32();
					return;
				}
#endif
			}
			break;
		case 'A':
			if (element_descriptor[1]=='R' && element_descriptor[2]=='R' && element_descriptor[3]=='A' &&
				element_descriptor[4]=='Y' && element_descriptor[5]=='\0')
			{
				code_create_lazy_array();
				return;
			}
			break;
		case 'S':
			if (element_descriptor[1]=='T' && element_descriptor[2]=='R' && element_descriptor[3]=='I' &&
				element_descriptor[4]=='N' && element_descriptor[5]=='G' && element_descriptor[6]=='\0')
			{
				code_create_lazy_array();
				return;
			}
			break;
		case 'W':
			if (is__orld (element_descriptor)){
				code_create_lazy_array();
				return;
			}
			break;
		case '_':
			if (element_descriptor[1]=='_' && element_descriptor[2]=='\0'){
				code_create_lazy_array();
				return;
			}
			break;
	}

	code_create_r_array (element_descriptor,a_size,b_size);
}

static void code_create_lazy_array_ (VOID)
{	
	INSTRUCTION_GRAPH graph_1;
	LABEL *nil_label;
	
#if defined (G_AI64) && defined (LINUX)
	if (rts_got_flag){
		nil_label=enter_label ("__Nil_Z",DATA_LABEL | USE_GOT_LABEL);
		graph_1=g_lea (nil_label);
	} else
#endif
	{
	nil_label=enter_label ("__Nil",DATA_LABEL);
	if (!parallel_flag)
		graph_1=g_lea_i (nil_label,ARITY_0_DESCRIPTOR_OFFSET+NODE_POINTER_OFFSET);
	else
		graph_1=g_create_1 (g_load_des_i (nil_label,0));
	}

	s_push_a (graph_1);
	code_create_lazy_array();
}

void code_create_array_ (char element_descriptor[],int a_size,int b_size)
{
	switch (element_descriptor[0]){
		case 'B':
			if (element_descriptor[1]=='O' && element_descriptor[2]=='O' && element_descriptor[3]=='L' &&
				element_descriptor[4]=='\0')
			{
				if (create_arrayB__label==NULL)
					create_arrayB__label=enter_rts_label ("_create_arrayB");
	
				s_push_b (s_get_b (0));
				s_put_b (1,NULL);
				insert_basic_block (JSR_BLOCK,0,1+1,i_vector,create_arrayB__label);
	
				init_a_stack (1);
				return;
			}
			break;
		case 'C':
			if (element_descriptor[1]=='H' && element_descriptor[2]=='A' && element_descriptor[3]=='R' &&
				element_descriptor[4]=='\0')
			{
				if (create_arrayC__label==NULL)
					create_arrayC__label=enter_rts_label ("_create_arrayC");
	
				s_push_b (s_get_b (0));
				s_put_b (1,NULL);
				insert_basic_block (JSR_BLOCK,0,1+1,i_vector,create_arrayC__label);
	
				init_a_stack (1);
				return;	
			}
			break;		
		case 'I':
			if (element_descriptor[1]=='N' && element_descriptor[2]=='T'){
				if (element_descriptor[3]=='\0'){
					INSTRUCTION_GRAPH graph_1;
					
					graph_1=s_get_b (0);

					if (graph_1->instruction_code==GLOAD_I && LESS_UNSIGNED (graph_1->instruction_parameters[0].i,33)){
						INSTRUCTION_GRAPH graph_2;

						s_pop_b();

						graph_2 = g_create_unboxed_int_array (graph_1->instruction_parameters[0].i);

						s_push_a (graph_2);
					} else {
						if (create_arrayI__label==NULL)
							create_arrayI__label=enter_rts_label ("_create_arrayI");

						s_push_b (graph_1);
						s_put_b (1,NULL);
						insert_basic_block (JSR_BLOCK,0,1+1,i_vector,create_arrayI__label);

						init_a_stack (1);
					}
					return;
				}
#if defined (G_A64) || defined (I486)
				if (element_descriptor[3]=='3' && element_descriptor[4]=='2' && element_descriptor[5]=='\0'){
					if (create_arrayI32__label==NULL)
						create_arrayI32__label=enter_rts_label ("_create_arrayI32");

					s_push_b (s_get_b (0));
					s_put_b (1,NULL);
					insert_basic_block (JSR_BLOCK,0,1+1,i_vector,create_arrayI32__label);

					init_a_stack (1);
					return;
				}
#endif
			}
			break;
		case 'P':
			if (is__rocid (element_descriptor)){
				if (create_arrayI__label==NULL)
					create_arrayI__label=enter_rts_label ("_create_arrayI");
	
				s_push_b (s_get_b (0));
				s_put_b (1,NULL);
				insert_basic_block (JSR_BLOCK,0,1+1,i_vector,create_arrayI__label);
	
				init_a_stack (1);
				return;	
			}
			break;
		case 'R':
			if (element_descriptor[1]=='E' && element_descriptor[2]=='A' && element_descriptor[3]=='L'){
				if (element_descriptor[4]=='\0'){
					if (create_arrayR__label==NULL)
						create_arrayR__label=enter_rts_label ("_create_arrayR");

					s_push_b (s_get_b (0));
					s_put_b (1,NULL);
					insert_basic_block (JSR_BLOCK,0,1+1,i_vector,create_arrayR__label);

					init_a_stack (1);
					return;
				}
#if defined (G_A64) || defined (I486)
				if (element_descriptor[4]=='3' && element_descriptor[5]=='2' && element_descriptor[6]=='\0'){
					if (create_arrayR32__label==NULL)
						create_arrayR32__label=enter_rts_label ("_create_arrayR32");

					s_push_b (s_get_b (0));
					s_put_b (1,NULL);
					insert_basic_block (JSR_BLOCK,0,1+1,i_vector,create_arrayR32__label);

					init_a_stack (1);
					return;
				}
#endif
			}
			break;
		case 'A':
			if (element_descriptor[1]=='R' && element_descriptor[2]=='R' && element_descriptor[3]=='A' &&
				element_descriptor[4]=='Y' && element_descriptor[5]=='\0')
			{
				code_create_lazy_array_();
				return;	
			}
			break;
		case 'S':
			if (element_descriptor[1]=='T' && element_descriptor[2]=='R' && element_descriptor[3]=='I' &&
				element_descriptor[4]=='N' && element_descriptor[5]=='G' && element_descriptor[6]=='\0')
			{
				code_create_lazy_array_();
				return;	
			}
			break;
		case 'W':
			if (is__orld (element_descriptor)){
				code_create_lazy_array_();
				return;	
			}
			break;
		case '_':
			if (element_descriptor[1]=='_' && element_descriptor[2]=='\0'){
				code_create_lazy_array_();
				return;	
			}
			break;
	}

	{
		INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
		LABEL *descriptor;

		{
			INSTRUCTION_GRAPH graph_1;
			LABEL *nil_label;
			
#if defined (G_AI64) && defined (LINUX)
			if (rts_got_flag){
				nil_label=enter_label ("__Nil_Z",DATA_LABEL | USE_GOT_LABEL);
				graph_1=g_lea (nil_label);
			} else
#endif
			{
			nil_label=enter_label ("__Nil",DATA_LABEL);
			if (!parallel_flag)
				graph_1=g_lea_i (nil_label,ARITY_0_DESCRIPTOR_OFFSET+NODE_POINTER_OFFSET);
			else
				graph_1=g_create_1 (g_load_des_i (nil_label,0));
			}

			s_push_a (graph_1);
		}
				
		if (create_r_array__label==NULL)
			create_r_array__label=enter_rts_label ("_create_r_array");

		graph_1=s_pop_b();

		descriptor=enter_label (element_descriptor,DATA_LABEL);
#if defined (G_A64) && defined (LINUX)
		if (pic_flag && descriptor->label_flags & USE_GOT_LABEL){
			descriptor=enter_got_label (element_descriptor,0,DATA_LABEL);
			graph_2=g_lea (descriptor);
		} else
#endif
		graph_2=g_load_des_i (descriptor,0);
		
		graph_3=g_load_i (a_size+b_size);
		graph_4=g_load_i (a_size);

#if defined (I486)
		{
			INSTRUCTION_GRAPH graph;
			struct block_label *new_label;
			LABEL *label;

			sprintf (eval_label_s,"e_%d",eval_label_number++);
			label=enter_label (eval_label_s,LOCAL_LABEL);
			graph=g_lea (label);

			s_push_b (graph);
			s_push_b (graph_1);
			s_push_b (graph_2);
			s_push_b (graph_3);
			s_push_b (graph_4);
			insert_basic_block (JSR_BLOCK,1,4+1,i_i_i_i_i_vector,create_r_array__label);

			new_label=fast_memory_allocate (sizeof (struct block_label));
			new_label->block_label_label=label;
			new_label->block_label_next=NULL;
		
			if (last_block->block_labels==NULL)
				last_block->block_labels=new_label;
			else
				last_block_label->block_label_next=new_label;
			last_block_label=new_label;
		}
#else
		s_push_b (NULL);
		s_push_b (graph_1);
		s_push_b (graph_2);
		s_push_b (graph_3);
		s_push_b (graph_4);
		insert_basic_block (JSR_BLOCK,1,4+1,i_i_i_i_i_vector,create_r_array__label);
#endif

		init_a_stack (1);
	}
}

#ifdef SIN_COS_CSE
#define SIN_COS_CSE_CACHE_SIZE 16 /* power of 2 */

static INSTRUCTION_GRAPH cos_cache[SIN_COS_CSE_CACHE_SIZE],sin_cache[SIN_COS_CSE_CACHE_SIZE];
static int n_cos_cache,n_sin_cache;
static struct basic_block *block_in_cos_cache,*block_in_sin_cache;

static INSTRUCTION_GRAPH search_sin_or_cos (INSTRUCTION_GRAPH graph,INSTRUCTION_GRAPH cache[SIN_COS_CSE_CACHE_SIZE],int n_cache)
{
	int n;
	
	n=n_cache;
	if (n<=SIN_COS_CSE_CACHE_SIZE){
		while (--n>=0)
			if (cache[n]->instruction_parameters[0].p==graph)
				return cache[n];
	} else {
		int e;
		
		e = n & (SIN_COS_CSE_CACHE_SIZE-1);

		n = e;
		while (--n>=0)
			if (cache[n]->instruction_parameters[0].p==graph)
				return cache[n];
		
		n = SIN_COS_CSE_CACHE_SIZE;
		while (--n>=e)
			if (cache[n]->instruction_parameters[0].p==graph)
				return cache[n];
	}
	
	return NULL;
}
#endif

void code_cosR (VOID)
{
#if defined (I486) && !defined (G_AI64)
# ifdef SIN_COS_CSE
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6;
	
	graph_2=s_get_b (1);
	graph_1=s_get_b (0);
	graph_3=g_fjoin (graph_1,graph_2);

	graph_4=NULL;
	if (block_in_sin_cache==last_block)
		graph_4 = search_sin_or_cos (graph_3,sin_cache,n_sin_cache);

	if (graph_4==NULL || graph_4->instruction_code!=GFSIN){
		graph_4=g_instruction_2 (GFCOS,graph_3,NULL); // extra argument because it may become a GFRESULT1 node
		graph_4->inode_arity=1;

		if (block_in_cos_cache==last_block){
			cos_cache [n_cos_cache & (SIN_COS_CSE_CACHE_SIZE-1)] = graph_4;
			++n_cos_cache;
		} else {
			block_in_cos_cache=last_block;
			cos_cache [0] = graph_4;
			n_cos_cache=1;
		}
	} else {
		INSTRUCTION_GRAPH sincos_graph,graph_7;

		sincos_graph=g_instruction_1 (GFSINCOS,graph_3);
		graph_7=graph_4;

		graph_4=g_instruction_2 (GFRESULT1,sincos_graph,graph_7);

		graph_7->instruction_code=GFRESULT0;
		graph_7->inode_arity=2;
		graph_7->instruction_parameters[0].p=sincos_graph;
		graph_7->instruction_parameters[1].p=graph_4;
	}

	g_fhighlow (graph_5,graph_6,graph_4);

	s_put_b (1,graph_6);
	s_put_b (0,graph_5);
# else
	code_monadic_real_operator (GFCOS);
# endif
#else
#	ifdef M68000
	if (!mc68881_flag){
#	endif
		if (cos_real==NULL)
			cos_real=enter_label ("cos_real",IMPORT_LABEL);
		code_monadic_sane_operator (cos_real);
		init_b_stack (SIZE_OF_REAL_IN_STACK_ELEMENTS,r_vector);
#	ifdef M68000
	} else
		code_monadic_real_operator (GFCOS);
#	endif
#endif
}

void code_create (int n_arguments)
{
	INSTRUCTION_GRAPH graph_1,graph_2;

	if (EMPTY_label==NULL)
		EMPTY_label=enter_label ("EMPTY",IMPORT_LABEL | DATA_LABEL);

#ifdef PROFILE
	if (callgraph_profiling)
		n_arguments++;
#endif

	if (n_arguments<=2){
#ifndef RESERVE_CODE_REGISTER
		if (!parallel_flag){
			if (cycle_in_spine_label==NULL){
				cycle_in_spine_label=enter_label ("__cycle__in__spine",IMPORT_LABEL | NODE_ENTRY_LABEL);
				cycle_in_spine_label->label_arity=0;
				cycle_in_spine_label->label_descriptor=EMPTY_label;
			}
			graph_1=g_lea (cycle_in_spine_label);
		} else {
			if (reserve_label==NULL){
				reserve_label=enter_label ("__reserve",IMPORT_LABEL | NODE_ENTRY_LABEL);
				reserve_label->label_arity=0;
				reserve_label->label_descriptor=EMPTY_label;
			}
			graph_1=g_lea (reserve_label);
		}
#else
		graph_1=g_g_register (RESERVE_CODE_REGISTER);
#endif
		graph_2=g_create_3 (graph_1,NULL,NULL);
	} else {
		char cycle_in_spine_label_n [64];
		LABEL *cycle_label_n;
		int n;

		sprintf (cycle_in_spine_label_n,"_c%d",n_arguments);
		cycle_label_n=enter_label (cycle_in_spine_label_n,NODE_ENTRY_LABEL | IMPORT_LABEL);
		cycle_label_n->label_arity=n_arguments;
		cycle_label_n->label_descriptor=EMPTY_label;

		graph_1=g_lea (cycle_label_n);
		
		graph_2=g_create_m (n_arguments+1);
		graph_2->instruction_parameters[0].p=graph_1;
		
		for (n=0; n<n_arguments; ++n)
			graph_2->instruction_parameters[n+1].p=NULL;
	}
	
	s_push_a (graph_2);
}

void code_decI (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_get_b (0);
	graph_2=g_load_i (1);
	graph_3=g_sub (graph_2,graph_1);
	s_put_b (0,graph_3);
}

void code_del_args (int source_offset,int n_arguments,int destination_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	if (del_args_label==NULL)
		del_args_label=enter_label ("del_args",IMPORT_LABEL);
	
	graph_1=s_get_a (source_offset);
	graph_2=s_get_a (destination_offset);
	graph_3=g_load_i (n_arguments<<2);
	
	s_push_a (graph_1);
	s_push_a (graph_2);

	s_push_b (NULL);

	s_push_b (graph_3);

	insert_basic_block (JSR_BLOCK,2,1+1,i_vector,del_args_label);
}

void code_divI (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;

	graph_2=s_get_b (1);

#ifdef M68000
	if (!mc68000_flag){
#endif
#if defined (ARM) && !defined (G_A64)
	if (graph_2->instruction_code==GLOAD_I && graph_2->instruction_parameters[0].i!=0){
#endif
		graph_1=s_pop_b();
#if defined (ARM) && !defined (G_A64)
		graph_2=g_load_i (graph_2->instruction_parameters[0].i);
#endif
		graph_3=g_div (graph_2,graph_1);
		s_put_b (0,graph_3);
#if defined (ARM) && !defined (G_A64)
		return;
	}
#endif
#ifdef sparc
		if (dot_div_label==NULL)
			dot_div_label=enter_label (".div",IMPORT_LABEL);
#endif
#ifdef M68000
	} else
#endif
#if defined (M68000) || (defined (ARM) && !defined (G_A64))
	{
		if (div_label==NULL)
			div_label=enter_label ("divide",IMPORT_LABEL);
		
		s_push_b (s_get_b (0));
		s_put_b (1,graph_2);
		s_put_b (2,NULL);
	
		insert_basic_block (JSR_BLOCK,0,2+1,i_i_vector,div_label);
		
		init_b_stack (1,i_vector);
	}
#endif
}

void code_divR (VOID)
{
#ifdef G_A64
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6;

	graph_1=s_pop_b();
	graph_2=g_fp_arg (graph_1);

	graph_3=s_get_b (0);
	graph_4=g_fp_arg (graph_3);

	graph_5=g_fdiv (graph_4,graph_2);

	graph_6=g_fromf (graph_5);

	s_put_b (0,graph_6);
#else
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6,graph_7,graph_8,graph_9;

# ifdef M68000
	if (!mc68881_flag){
		if (div_real==NULL)
			div_real=enter_label ("div_real",IMPORT_LABEL);
		code_dyadic_sane_operator (div_real);
		init_b_stack (2,r_vector);
	} else {
# endif
		graph_1=s_pop_b();
		graph_2=s_pop_b();
		graph_3=g_fjoin (graph_1,graph_2);
	
		graph_4=s_get_b (0);
		graph_5=s_get_b (1);
		graph_6=g_fjoin (graph_4,graph_5);
	
		graph_7=g_fdiv (graph_6,graph_3);

		g_fhighlow (graph_8,graph_9,graph_7);

		s_put_b (0,graph_8);
		s_put_b (1,graph_9);
# ifdef M68000
	}
# endif
#endif
}

#if defined (I486) || defined (ARM) || defined (G_POWER)
void code_divU (VOID)
{
# if ! (defined (ARM) && !defined (G_A64))
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;

	graph_1=s_pop_b();
	graph_2=s_get_b (0);
	graph_3=g_divu (graph_2,graph_1);
	s_put_b (0,graph_3);
# else
	INSTRUCTION_GRAPH graph_1;

	if (udiv_label==NULL)
		udiv_label=enter_label ("udivide",IMPORT_LABEL);

	graph_1=s_get_b (1);
	s_push_b (s_get_b (0));
	s_put_b (1,graph_1);
	s_put_b (2,NULL);

	insert_basic_block (JSR_BLOCK,0,2+1,i_i_vector,udiv_label);

	init_b_stack (1,i_vector);
# endif
}
#endif

#if defined (I486) || (defined (ARM) && !defined (G_A64))
void code_divLU (VOID)
{
# ifdef I486
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6;
	
	graph_3=s_get_b (2);
	graph_2=s_get_b (1);
	graph_1=s_pop_b();

	graph_4=g_new_node (GDIVDU,3,3*sizeof (union instruction_parameter));
	graph_4->instruction_parameters[0].p=graph_1;
	graph_4->instruction_parameters[1].p=graph_2;
	graph_4->instruction_parameters[2].p=graph_3;

	graph_5=g_instruction_2 (GRESULT1,graph_4,NULL);
	graph_6=g_instruction_2 (GRESULT0,graph_4,NULL);
	graph_5->instruction_parameters[1].p=graph_6;
	graph_6->instruction_parameters[1].p=graph_5;

	s_put_b (1,graph_5);
	s_put_b (0,graph_6);
# else
	INSTRUCTION_GRAPH graph_1,graph_2;

	if (ludiv_label==NULL)
		ludiv_label=enter_label ("ludivide",IMPORT_LABEL);

	graph_2=s_get_b (2);
	graph_1=s_get_b (1);
	s_push_b (s_get_b (0));
	s_put_b (1,graph_1);
	s_put_b (2,graph_2);
	s_put_b (3,NULL);

	insert_basic_block (JSR_BLOCK,0,3+1,i_i_i_vector,ludiv_label);

	init_b_stack (2,i_i_vector);
# endif
}
#endif

void code_entierR (VOID)
{
	if (entier_real_label==NULL)
		entier_real_label=enter_label ("entier_real",IMPORT_LABEL);

#ifdef G_A64
	s_push_b (s_get_b (0));
	s_put_b (1,NULL);
	insert_basic_block (JSR_BLOCK,0,1+1,r_vector,entier_real_label);
#else
	s_push_b (s_get_b (0));
	s_put_b (1,s_get_b (2));
	s_put_b (2,NULL);

	insert_basic_block (JSR_BLOCK,0,2+1,r_vector,entier_real_label);
#endif

	init_b_stack (1,i_vector);
}

void code_eqB (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_pop_b();
	graph_2=s_get_b (0);
	graph_3=g_cmp_eq (graph_2,graph_1);
	
	s_put_b (0,graph_3);
}

void code_eqB_a (int value,int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	
	graph_1=s_get_a (a_offset);
	graph_2=g_load_id (ARGUMENTS_OFFSET-NODE_POINTER_OFFSET,graph_1);
#if defined (I486) || defined (ARM)
	graph_3=g_load_i (value);
#else
	graph_3=g_load_i (-value);
#endif
	graph_4=g_cmp_eq (graph_3,graph_2);
	
	s_push_b (graph_4);
}

void code_eqB_b (int value,int b_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_get_b (b_offset);
#if defined (I486) || defined (ARM)
	graph_2=g_load_i (value);
#else
	graph_2=g_load_i (-value);
#endif
	graph_3=g_cmp_eq (graph_2,graph_1);
	
	s_push_b (graph_3);
}

void code_eqC (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_pop_b();
	graph_2=s_get_b (0);
	graph_3=g_cmp_eq (graph_2,graph_1);
	
	s_put_b (0,graph_3);
}

void code_eqC_a (int value,int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	
	graph_1=s_get_a (a_offset);
	graph_2=g_load_id (ARGUMENTS_OFFSET-NODE_POINTER_OFFSET,graph_1);
	graph_3=g_load_i (value);
	graph_4=g_cmp_eq (graph_3,graph_2);
	
	s_push_b (graph_4);
}

void code_eqC_b (int value,int b_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_get_b (b_offset);
	graph_2=g_load_i (value);
	graph_3=g_cmp_eq (graph_2,graph_1);
	
	s_push_b (graph_3);
}

void code_eqD_b (char descriptor_name[],int arity)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	LABEL *descriptor;
	
	descriptor=enter_label (descriptor_name,DATA_LABEL);
	
	graph_1=s_get_b (0);

#if defined (G_A64) && defined (LINUX)
	if (pic_flag && descriptor->label_flags & USE_GOT_LABEL){
		descriptor=enter_got_label (descriptor_name,arity,DATA_LABEL);
		graph_2=g_lea (descriptor);
	} else
#endif
	graph_2=g_load_des_i (descriptor,arity);

	graph_3=g_cmp_eq (graph_2,graph_1);
	
	s_push_b (graph_3);
}

void code_eqI (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_pop_b();
	graph_2=s_get_b (0);
	graph_3=g_cmp_eq (graph_2,graph_1);
	
	s_put_b (0,graph_3);
}

void code_eqI_a (CleanInt value,int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	
	graph_1=s_get_a (a_offset);
	graph_2=g_load_id (ARGUMENTS_OFFSET-NODE_POINTER_OFFSET,graph_1);
	graph_3=g_load_i (value);
	graph_4=g_cmp_eq (graph_3,graph_2);
	
	s_push_b (graph_4);
}

void code_eqI_b (CleanInt value,int b_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_get_b (b_offset);
	graph_2=g_load_i (value);
	graph_3=g_cmp_eq (graph_2,graph_1);
	
	s_push_b (graph_3);
}

void code_eqR (VOID)
{
#ifdef G_A64
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5;

	graph_1=s_pop_b();
	graph_2=g_fp_arg (graph_1);

	graph_3=s_pop_b();
	graph_4=g_fp_arg (graph_3);

	graph_5=g_fcmp_eq (graph_4,graph_2);

	s_push_b (graph_5);
#else
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6,graph_7;

# ifdef M68000
	if (!mc68881_flag){
		if (eq_real==NULL)
			eq_real=enter_label ("eq_real",IMPORT_LABEL);

		code_dyadic_sane_operator (eq_real);		
		init_b_stack (1,i_vector);
	} else {
# endif
		graph_1=s_pop_b();
		graph_2=s_pop_b();
		graph_3=g_fjoin (graph_1,graph_2);
	
		graph_4=s_pop_b();
		graph_5=s_pop_b();
		graph_6=g_fjoin (graph_4,graph_5);
	
		graph_7=g_fcmp_eq (graph_6,graph_3);
	
		s_push_b (graph_7);
# ifdef M68000
	}
# endif
#endif
}

void code_eqR_a (double value,int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_3,graph_4,graph_5;

#ifdef M68000	
	if (!mc68881_flag){
		INSTRUCTION_GRAPH graph_6,graph_7;

		DOUBLE r=value;
		
		if (eq_real==NULL)
			eq_real=enter_label ("eq_real",IMPORT_LABEL);
		
		graph_1=s_get_a (a_offset);
		/*
		graph_3=g_movem (ARGUMENTS_OFFSET,graph_1,2);
		graph_4=g_movemi (0,graph_3);
		graph_5=g_movemi (1,graph_3);
		*/
		graph_4=g_load_id (ARGUMENTS_OFFSET-NODE_POINTER_OFFSET,graph_1);
		graph_5=g_load_id (ARGUMENTS_OFFSET-NODE_POINTER_OFFSET+4,graph_1);
		
		graph_6=g_load_i (((long*)&r)[0]);
		graph_7=g_load_i (((long*)&r)[1]);

		s_push_b (graph_4);
		s_push_b (graph_5);
		s_push_b (graph_6);
		s_push_b (graph_7);
		
		code_dyadic_sane_operator (eq_real);
		init_b_stack (1,i_vector);
	} else {
#endif
		graph_1=s_get_a (a_offset);
		graph_3=g_fload_id (ARGUMENTS_OFFSET-NODE_POINTER_OFFSET,graph_1);
		
		graph_4=g_fload_i (value);
	
		graph_5=g_fcmp_eq (graph_4,graph_3);
	
		s_push_b (graph_5);
#ifdef M68000
	}
#endif
}

void code_eqR_b (double value,int b_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5;

#ifdef M68000
	if (!mc68881_flag){
		DOUBLE r=value;
		
		if (eq_real==NULL)
			eq_real=enter_label ("eq_real",IMPORT_LABEL);
		
		graph_1=s_get_b (b_offset+1);
		graph_2=s_get_b (b_offset);
		graph_3=g_load_i (((long*)&r)[0]);
		graph_4=g_load_i (((long*)&r)[1]);

		s_push_b (graph_1);
		s_push_b (graph_2);
		s_push_b (graph_3);
		s_push_b (graph_4);

		code_dyadic_sane_operator (eq_real);
		init_b_stack (1,i_vector);
	} else {
#endif
#ifdef G_A64
		graph_1=s_get_b (b_offset);
		graph_3=g_fp_arg (graph_1);
#else
		graph_1=s_get_b (b_offset);
		graph_2=s_get_b (b_offset+1);
		graph_3=g_fjoin (graph_1,graph_2);
#endif
		graph_4=g_fload_i (value);

		graph_5=g_fcmp_eq (graph_4,graph_3);
	
		s_push_b (graph_5);
#ifdef M68000
	}
#endif
}

void code_eqAC_a (char *string,int string_length)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	LABEL *string_label;	
	
	if (equal_string_label==NULL)
		equal_string_label=enter_label ("eqAC",
#if defined (G_AI64) && defined (LINUX)
							rts_got_flag ? (USE_GOT_LABEL | IMPORT_LABEL) :
#endif
							IMPORT_LABEL);
		
	string_label=w_code_length_and_string (string,string_length);
	
	graph_1=s_pop_a();
	graph_2=g_lea_i (string_label,-STACK_ELEMENT_SIZE);
	
	s_push_a (graph_2);
	s_push_a (graph_1);

	s_push_b (NULL);

	insert_basic_block (JSR_BLOCK,2,0+1,e_vector,equal_string_label);

	init_b_stack (1,i_vector);
}

void code_eq_desc (char descriptor_name[],int arity,int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	LABEL *descriptor;
	
	descriptor=enter_label (descriptor_name,DATA_LABEL);
	
	graph_1=s_get_a (a_offset);

#ifndef M68000
	graph_2=g_load_id (0,graph_1);
#else
	graph_2=g_load_des_id (DESCRIPTOR_OFFSET,graph_1);
#endif

#if defined (G_A64) && defined (LINUX)
	if (pic_flag && descriptor->label_flags & USE_GOT_LABEL){
		descriptor=enter_got_label (descriptor_name,arity,DATA_LABEL);
		graph_3=g_lea (descriptor);
	} else
#endif
	graph_3=g_load_des_i (descriptor,arity);

	graph_4=g_cmp_eq (graph_3,graph_2);
	
	s_push_b (graph_4);
}

void code_eq_desc_b (char descriptor_name[],int arity)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	LABEL *descriptor;

	descriptor=enter_label (descriptor_name,DATA_LABEL);
	
	graph_1=s_pop_b();

	graph_2=g_load_des_i (descriptor,arity);
	graph_3=g_cmp_eq (graph_2,graph_1);
	
	s_push_b (graph_3);
}

void code_eq_nulldesc (char descriptor_name[],int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6,graph_7,graph_8;
	LABEL *descriptor;
	
	descriptor=enter_label (descriptor_name,DATA_LABEL);
	
	graph_1=s_get_a (a_offset);

	graph_2=g_load_id (0,graph_1);
#ifdef NEW_DESCRIPTORS
	graph_5=g_load_des_id (-2,graph_2);
# ifdef MACH_O64
	graph_5=g_lsl (g_load_i (4),graph_5);
# elif defined (G_A64) && defined (LINUX)
	graph_5=g_lsl (g_load_i (pic_flag ? 4 : 3),graph_5);
# else
	graph_5=g_lsl (g_load_i (3),graph_5);
# endif
	graph_6=g_sub (graph_5,graph_2);
#else
	graph_5=g_load_des_id (2-2,graph_2);
	graph_6=g_sub (graph_5,graph_2);
#endif
	graph_7=g_load_des_i (descriptor,0);
	graph_8=g_cmp_eq (graph_7,graph_6);
	
	s_push_b (graph_8);
}

void code_eq_symbol (int a_offset_1,int a_offset_2)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	if (eqD_label==NULL)
		eqD_label=enter_label ("eqD",IMPORT_LABEL);
	
	graph_1=s_get_a (a_offset_1);
	graph_2=s_get_a (a_offset_2);
	
	s_push_a (graph_2);
	s_push_a (graph_1);

	s_push_b (NULL);
	insert_basic_block (JSR_BLOCK,2,0+1,e_vector,eqD_label);

	init_b_stack (1,i_vector);
}

void code_exit_false (char label_name[])
{
#ifndef M68000
	INSTRUCTION_GRAPH condition_graph,result_graph;
	LABEL *label;
		
	condition_graph=s_pop_b();
	result_graph=s_get_a (0);
	
	label=enter_label (label_name,
# if defined (G_POWER) || (defined (ARM) && defined (G_A64)) || defined (THUMB)
			FAR_CONDITIONAL_JUMP_LABEL
# else
			0
# endif
			);

	result_graph=g_exit_if (label,condition_graph,result_graph);
	
	s_put_a (0,result_graph);
#else
	sprintf (eval_label_s,"e_%d",eval_label_number++);
	code_jmp_true (eval_label_s);
	code_jmp (label_name);
	code_label (eval_label_s);
#endif
}

void code_expR (VOID)
{
#ifdef M68000
	if (mc68881_flag){
		code_monadic_real_operator (GFEXP);
		return;
	}
#endif
	if (exp_real==NULL)
		exp_real=enter_label ("exp_real",IMPORT_LABEL);
	code_monadic_sane_operator (exp_real);
	init_b_stack (SIZE_OF_REAL_IN_STACK_ELEMENTS,r_vector);
}

void code_fill_r (char descriptor_name[],int a_size,int b_size,int root_offset,int a_offset,int b_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6;
	
	graph_1=s_get_a (root_offset);

	graph_2=lea_record_descriptor (descriptor_name);

	switch (a_size+b_size){
		case 0:
			graph_4=g_fill_2 (graph_1,graph_2);
			break;
		case 1:
			if (a_size!=0)
				graph_5=s_get_a (a_offset);
			else
				graph_5=s_get_b (b_offset);
			graph_4=g_fill_3 (graph_1,graph_2,graph_5);
			break;
		case 2:
			switch (b_size){
				case 0:
					graph_5=s_get_a (a_offset);
					graph_6=s_get_a (a_offset+1);
					break;				
				case 1:
					graph_5=s_get_a (a_offset);
					graph_6=s_get_b (b_offset);
					break;
				default:
					graph_5=s_get_b (b_offset);
					graph_6=s_get_b (b_offset+1);
			}
			graph_4=g_fill_4 (graph_1,graph_2,graph_5,graph_6);
			break;
		default:
		{
			union instruction_parameter *parameter;
			
			if (a_size>0){
				graph_5=s_get_a (a_offset);
				++a_offset;
				--a_size;
			} else {
				graph_5=s_get_b (b_offset);
				++b_offset;
				--b_size;
			}
			
			graph_3=g_create_m (a_size+b_size);
			
			parameter=graph_3->instruction_parameters;

			while (a_size>0){
				parameter->p=s_get_a (a_offset);
				++parameter;
				++a_offset;
				--a_size;
			}

			while (b_size>0){
				parameter->p=s_get_b (b_offset);
				++parameter;
				++b_offset;
				--b_size;
			}

			graph_4=g_fill_4 (graph_1,graph_2,graph_5,graph_3);
		}
	}
	
	s_put_a (root_offset,graph_4);
}

void code_fill (char descriptor_name[],int arity,char *code_name,int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	LABEL *descriptor_label,*code_label;

	if (strcmp (code_name,"__hnf")==0){
		code_fillh (descriptor_name,arity,a_offset);
#ifdef PROFILE
	} else if (callgraph_profiling){
		code_fill_u (descriptor_name,arity<0 ? 1 : arity,0,code_name,a_offset);
#endif
	} else {
		int n_arguments;
		union instruction_parameter *parameter;

		graph_1=s_get_a (a_offset);

		code_label=enter_label (code_name,NODE_ENTRY_LABEL);
		code_label->label_arity=arity;

		if (descriptor_name[0]=='_' && descriptor_name[1]=='_' && descriptor_name[2]=='\0')
			descriptor_label=NULL;
		else
			descriptor_label=enter_label (descriptor_name,DATA_LABEL);

		if (arity<-2)
			arity=1;

		if (code_label->label_flags & EA_LABEL
			&&	code_label->label_ea_label!=eval_fill_label
			&&	arity>=0 && eval_upd_labels[arity]==NULL)
		{
			define_eval_upd_label_n (arity);
		}

		if (arity<0)
			arity=1;
	
		code_label->label_descriptor=descriptor_label;

		if (arity<2){
			graph_2=g_fill_m (graph_1,3);
			graph_2->instruction_parameters[2].p=NULL;
			graph_2->instruction_parameters[3].p=NULL;
		} else
			graph_2=g_fill_m (graph_1,arity+1);
		parameter=&graph_2->instruction_parameters[1];

		graph_3=g_lea (code_label);
		parameter->p=graph_3;
		++parameter;
			
		for (n_arguments=arity; n_arguments>0; --n_arguments){
			graph_4=s_pop_a();
			parameter->p=graph_4;
			++parameter;
		}
				
		s_put_a (a_offset-arity,graph_2);
	}
}

void code_fillcp (char descriptor_name[],int arity,char *code_name,int a_offset,char bits[])
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	LABEL *descriptor_label,*code_label;
	int argument_n;
	union instruction_parameter *parameter;

	graph_1=s_get_a (a_offset);

	if (bits[0]!='0'){
		code_label=enter_label (code_name,NODE_ENTRY_LABEL);
		code_label->label_arity=arity;

		if (descriptor_name[0]=='_' && descriptor_name[1]=='_' && descriptor_name[2]=='\0')
			descriptor_label=NULL;
		else
			descriptor_label=enter_label (descriptor_name,DATA_LABEL);

		if (arity<-2)
			arity=1;

		if (code_label->label_flags & EA_LABEL
			&&	code_label->label_ea_label!=eval_fill_label
			&&	arity>=0 && eval_upd_labels[arity]==NULL)
		{
			define_eval_upd_label_n (arity);
		}

		if (arity<0)
			arity=1;

		code_label->label_descriptor=descriptor_label;

		graph_3=g_lea (code_label);
	} else {
		if (arity<0)
			arity=1;
		graph_3=NULL;
	}

	if (arity<2){
		graph_2=g_fill_m (graph_1,3);
		graph_2->instruction_parameters[2].p=NULL;
		graph_2->instruction_parameters[3].p=NULL;
	} else
		graph_2=g_fill_m (graph_1,arity+1);
	parameter=&graph_2->instruction_parameters[1];

	parameter->p=graph_3;
	++parameter;
		
	for (argument_n=0; argument_n<arity; ++argument_n){
		if (bits[argument_n+1]!='0'){
			graph_4=s_pop_a();
			--a_offset;
		} else
			graph_4=NULL;
		parameter->p=graph_4;
		++parameter;
	}
			
	s_put_a (a_offset,graph_2);
}

void code_fillcp_u (char descriptor_name[],int a_size,int b_size,char *code_name,int a_offset,char bits[])
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	LABEL *descriptor_label,*code_label;
	int argument_n;
	union instruction_parameter *parameter;

	graph_1=s_get_a (a_offset);

	if (bits[0]!='0'){
		code_label=enter_label (code_name,NODE_ENTRY_LABEL);
		code_label->label_arity=a_size+b_size+(b_size<<8);

		if (descriptor_name[0]=='_' && descriptor_name[1]=='_' && descriptor_name[2]=='\0')
			descriptor_label=NULL;
		else
			descriptor_label=enter_label (descriptor_name,DATA_LABEL);

		code_label->label_descriptor=descriptor_label;

		graph_3=g_lea (code_label);
	} else {
		graph_3=NULL;
	}

	if (a_size+b_size<2){
		graph_2=g_fill_m (graph_1,3);
		graph_2->instruction_parameters[2].p=NULL;
		graph_2->instruction_parameters[3].p=NULL;
	} else
		graph_2=g_fill_m (graph_1,a_size+b_size+1);
	parameter=&graph_2->instruction_parameters[1];

	parameter->p=graph_3;
	++parameter;
	
	argument_n=0;
	for (; argument_n<a_size; ++argument_n){
		if (bits[argument_n+1]!='0'){
			graph_4=s_pop_a();
			--a_offset;
		} else
			graph_4=NULL;
		parameter->p=graph_4;
		++parameter;
	}

	for (; argument_n<a_size+b_size; ++argument_n){
		if (bits[argument_n+1]!='0'){
			graph_4=s_pop_b();
		} else
			graph_4=NULL;
		parameter->p=graph_4;
		++parameter;
	}
			
	s_put_a (a_offset,graph_2);
}

void code_fill_u (char descriptor_name[],int a_size,int b_size,char *code_name,int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	LABEL *descriptor_label,*code_label;
	int argument_n;
	union instruction_parameter *parameter;

	graph_1=s_get_a (a_offset);

#ifdef PROFILE
	if (callgraph_profiling)
		++b_size;
#endif

	code_label=enter_label (code_name,NODE_ENTRY_LABEL);
	code_label->label_arity=a_size+b_size+(b_size<<8);

	if (descriptor_name[0]=='_' && descriptor_name[1]=='_' && descriptor_name[2]=='\0')
		descriptor_label=NULL;
	else
		descriptor_label=enter_label (descriptor_name,DATA_LABEL);

	code_label->label_descriptor=descriptor_label;

	graph_3=g_lea (code_label);

	if (a_size+b_size<2){
		graph_2=g_fill_m (graph_1,3);
		graph_2->instruction_parameters[2].p=NULL;
		graph_2->instruction_parameters[3].p=NULL;
	} else
		graph_2=g_fill_m (graph_1,a_size+b_size+1);
	parameter=&graph_2->instruction_parameters[1];

	parameter->p=graph_3;
	++parameter;
	
	argument_n=0;
	for (; argument_n<a_size; ++argument_n){
		graph_4=s_pop_a();
		--a_offset;
		parameter->p=graph_4;
		++parameter;
	}

#ifdef PROFILE
	if (callgraph_profiling){
		INSTRUCTION_GRAPH graph_5;

		--b_size;

		if (profile_current_cost_centre_label==NULL)
# if (defined (I486) && !defined (G_AI64) && !defined (LINUX_ELF)) || defined (MACH_O) || defined (MACH_O64)
			profile_current_cost_centre_label=enter_label ("_profile_current_cost_centre",IMPORT_LABEL | DATA_LABEL);
# else
			profile_current_cost_centre_label=enter_label ("profile_current_cost_centre",IMPORT_LABEL | DATA_LABEL);
# endif
		graph_4=g_lea (profile_current_cost_centre_label);
		graph_5=g_load_id (0,graph_4);
		parameter[b_size].p=graph_5;
	}
#endif

	for (; argument_n<a_size+b_size; ++argument_n){
		graph_4=s_pop_b();
		parameter->p=graph_4;
		++parameter;
	}
			
	s_put_a (a_offset,graph_2);
}

void code_fillh (char descriptor_name[],int arity,int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6;
	LABEL *descriptor_label;

	graph_1=s_get_a (a_offset);

	descriptor_label=enter_label (descriptor_name,DATA_LABEL);

	if (!parallel_flag &&
		arity==0 && graph_1->instruction_code==GCREATE && graph_1->inode_arity>0)
	{
		graph_1->instruction_code=GLEA;
		graph_1->inode_arity=1;
		graph_1->instruction_parameters[0].l=descriptor_label;
		graph_1->instruction_parameters[1].i=ARITY_0_DESCRIPTOR_OFFSET+NODE_POINTER_OFFSET;
		return;
	}

	if (!parallel_flag &&
		descriptor_label->label_last_lea_block==last_block &&
		descriptor_label->label_last_lea_arity==arity)
	{
		graph_2=descriptor_label->label_last_lea;
	} else {
#if defined (G_A64) && defined (LINUX)
		if (pic_flag && descriptor_label->label_flags & USE_GOT_LABEL){
			descriptor_label=enter_got_label (descriptor_name,arity,DATA_LABEL);
			graph_2=g_lea (descriptor_label);
		} else
#endif
		graph_2=g_load_des_i (descriptor_label,arity);

		if (!parallel_flag ){
			descriptor_label->label_last_lea=graph_2;
			descriptor_label->label_last_lea_block=last_block;
			descriptor_label->label_last_lea_arity=arity;
		}
	}

	switch (arity){
		case 0:
			graph_4=g_fill_2 (graph_1,graph_2);
			break;
		case 1:
			graph_5=s_pop_a();
			graph_4=g_fill_3 (graph_1,graph_2,graph_5);
			break;
		case 2:
			graph_5=s_pop_a();
			graph_6=s_pop_a();
			graph_4=g_fill_4 (graph_1,graph_2,graph_5,graph_6);
			break;
		default:
		{
			int n_arguments;
			union instruction_parameter *parameter;
			
			graph_5=s_pop_a();
			
			graph_3=g_create_m (arity-1);
			parameter=graph_3->instruction_parameters;
			for (n_arguments=arity-1; n_arguments>0; --n_arguments){
				graph_6=s_pop_a();
				parameter->p=graph_6;
				++parameter;
			}

			graph_4=g_fill_4 (graph_1,graph_2,graph_5,graph_3);
		}
	}
	
	s_put_a (a_offset-arity,graph_4);
}

void code_fill1 (char descriptor_name[],int arity,int a_offset,char bits[])
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6;
	LABEL *descriptor_label;

	graph_1=s_get_a (a_offset);

	if (!parallel_flag && arity==0 && graph_1->instruction_code==GCREATE && graph_1->inode_arity>0){
		descriptor_label=enter_label (descriptor_name,DATA_LABEL);

		graph_1->instruction_code=GLEA;
		graph_1->inode_arity=1;
		graph_1->instruction_parameters[0].l=descriptor_label;
		graph_1->instruction_parameters[1].i=ARITY_0_DESCRIPTOR_OFFSET+NODE_POINTER_OFFSET;
		return;
	}

	if (bits[0]=='1'){
		descriptor_label=enter_label (descriptor_name,DATA_LABEL);

		if (!parallel_flag &&
			descriptor_label->label_last_lea_block==last_block &&
			descriptor_label->label_last_lea_arity==arity)
		{
			graph_2=descriptor_label->label_last_lea;
		} else {
			graph_2=g_load_des_i (descriptor_label,arity);

			if (!parallel_flag ){
				descriptor_label->label_last_lea=graph_2;
				descriptor_label->label_last_lea_block=last_block;
				descriptor_label->label_last_lea_arity=arity;
			}
		}
	} else
		graph_2=NULL;

	switch (arity){
		case 0:
			graph_4=g_fill_2 (graph_1,graph_2);
			break;
		case 1:
			if (bits[1]=='0')
				graph_5=NULL;
			else {
				--a_offset;
				graph_5=s_pop_a();
			}
			graph_4=g_fill_3 (graph_1,graph_2,graph_5);
			break;
		case 2:
			if (bits[1]=='0')
				graph_5=NULL;
			else {
				--a_offset;
				graph_5=s_pop_a();
			}
			if (bits[2]=='0')
				graph_6=NULL;
			else {
				--a_offset;
				graph_6=s_pop_a();
			}
			graph_4=g_fill_4 (graph_1,graph_2,graph_5,graph_6);
			break;
		default:
		{
			int argument_n;
			union instruction_parameter *parameter;
			
			if (bits[1]=='0')
				graph_5=NULL;
			else {
				--a_offset;
				graph_5=s_pop_a();
			}
			
			graph_3=g_create_m (arity-1);
			parameter=graph_3->instruction_parameters;
			
			for (argument_n=1; argument_n<arity; ++argument_n){
				if (bits[argument_n+1]=='0')
					graph_6=NULL;
				else
					graph_6=s_pop_a();
				parameter->p=graph_6;
				++parameter;
			}

			graph_4=g_fill_4 (graph_1,graph_2,graph_5,graph_3);
		}
	}
	
	s_put_a (a_offset,graph_4);
}

void code_fill2 (char descriptor_name[],int arity,int a_offset,char bits[])
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6;
	LABEL *descriptor_label;
	int argument_n;
	union instruction_parameter *parameter;

	graph_1=s_get_a (a_offset);
	if (graph_1->instruction_code==GBEFORE0)
		graph_1->instruction_code=GBEFORE;

	if (bits[0]=='1'){
		descriptor_label=enter_label (descriptor_name,DATA_LABEL);

		if (!parallel_flag &&
			descriptor_label->label_last_lea_block==last_block &&
			descriptor_label->label_last_lea_arity==arity)
		{
			graph_2=descriptor_label->label_last_lea;
		} else {
			graph_2=g_load_des_i (descriptor_label,arity);

			if (!parallel_flag ){
				descriptor_label->label_last_lea=graph_2;
				descriptor_label->label_last_lea_block=last_block;
				descriptor_label->label_last_lea_arity=arity;
			}
		}
	} else
		graph_2=NULL;
	
	if (bits[1]=='0')
		graph_5=NULL;
	else {
		graph_5=s_pop_a();
		--a_offset;
	}
	
	graph_3=g_fill_m (g_load_id (2*STACK_ELEMENT_SIZE-NODE_POINTER_OFFSET,graph_1),arity-1);

	parameter=&graph_3->instruction_parameters[1];
	for (argument_n=1; argument_n<arity; ++argument_n){
		if (bits[argument_n+1]=='0')
			graph_6=NULL;
		else {
			graph_6=s_pop_a();
			--a_offset;
		}
		
		parameter->p=graph_6;
		++parameter;
	}

	graph_4=g_fill_3 (g_keep (graph_3,graph_1),graph_2,graph_5);
	
	s_put_a (a_offset,graph_4);
}

void code_fill3 (char descriptor_name[],int arity,int a_offset,char bits[])
{
	INSTRUCTION_GRAPH graph_0,graph_1,graph_2,graph_3,graph_4,graph_5,graph_6;
	LABEL *descriptor_label;
	union instruction_parameter *parameter;
	int a_n;
	
	graph_0=s_pop_a();
	if (graph_0->instruction_code==GBEFORE0)
		graph_0->instruction_code=GBEFORE;
	--a_offset;
	
#ifndef RESERVE_CODE_REGISTER
	if (!parallel_flag){
		if (cycle_in_spine_label==NULL){
			cycle_in_spine_label=enter_label ("__cycle__in__spine",IMPORT_LABEL | NODE_ENTRY_LABEL);
			cycle_in_spine_label->label_arity=0;
			cycle_in_spine_label->label_descriptor=EMPTY_label;
		}
		graph_6=g_lea (cycle_in_spine_label);
	} else {
		if (reserve_label==NULL){
			reserve_label=enter_label ("__reserve",IMPORT_LABEL | NODE_ENTRY_LABEL);
			reserve_label->label_arity=0;
			reserve_label->label_descriptor=EMPTY_label;
		}
		graph_6=g_lea (reserve_label);
	}
#else
	graph_6=g_g_register (RESERVE_CODE_REGISTER);
#endif
	graph_0=g_fill_2 (graph_0,graph_6);
	
	graph_1=s_get_a (a_offset);
	if (graph_1->instruction_code==GBEFORE0)
		graph_1->instruction_code=GBEFORE;

	descriptor_label=enter_label (descriptor_name,DATA_LABEL);

	if (!parallel_flag && descriptor_label->label_last_lea_block==last_block && descriptor_label->label_last_lea_arity==arity)
		graph_2=descriptor_label->label_last_lea;
	else {
		graph_2=g_load_des_i (descriptor_label,arity);

		if (!parallel_flag ){
			descriptor_label->label_last_lea=graph_2;
			descriptor_label->label_last_lea_block=last_block;
			descriptor_label->label_last_lea_arity=arity;
		}
	}

	if (bits[0]=='0')
		graph_5=g_load_id (STACK_ELEMENT_SIZE,graph_0);
	else {
		graph_5=s_pop_a();
		--a_offset;
	}

	graph_0=g_load_id (2*STACK_ELEMENT_SIZE,graph_0);

	a_n=1;	

	graph_3=g_fill_m (graph_0,arity-1);
	
	parameter=&graph_3->instruction_parameters[1];

	while (a_n<arity){
		if (bits[a_n]=='0')
			parameter->p=NULL;
		else {
			parameter->p=s_pop_a();
			--a_offset;
		}
		++parameter;
		++a_n;
	}

	graph_4=g_fill_4 (graph_1,graph_2,graph_5,graph_3);
	
	s_put_a (a_offset,graph_4);
}

void code_fillB (int value,int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;

#ifdef BOOL_REGISTER
	graph_2=g_g_register (BOOL_REGISTER);
#else
	if (!parallel_flag && last_BOOL_descriptor_block==last_block)
		graph_2=last_BOOL_descriptor_graph;
	else {
		graph_2=g_BOOL_label();

		if (!parallel_flag){
			last_BOOL_descriptor_graph=graph_2;
			last_BOOL_descriptor_block=last_block;
		}
	}
#endif
	
	graph_1=s_get_a (a_offset);
#if defined (I486) || defined (ARM)
	graph_3=g_load_i (value);
#else
	graph_3=g_load_i (-value);
#endif
	graph_4=g_fill_3 (graph_1,graph_2,graph_3);
	
	s_put_a (a_offset,graph_4);
}

void code_fillB_b (int b_offset,int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	
#ifdef BOOL_REGISTER
	graph_2=g_g_register (BOOL_REGISTER);
#else
	if (!parallel_flag && last_BOOL_descriptor_block==last_block)
		graph_2=last_BOOL_descriptor_graph;
	else {
		graph_2=g_BOOL_label();

		if (!parallel_flag){
			last_BOOL_descriptor_graph=graph_2;
			last_BOOL_descriptor_block=last_block;
		}
	}
#endif
		
	graph_1=s_get_a (a_offset);
	graph_3=s_get_b (b_offset);
	graph_4=g_fill_3 (graph_1,graph_2,graph_3);

	s_put_a (a_offset,graph_4);
}

void code_fillC (int value,int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;

	graph_1=s_get_a (a_offset);

	if (!parallel_flag && graph_1->instruction_code==GCREATE){
		if (static_characters_label==NULL)
			static_characters_label=enter_label ("static_characters",IMPORT_LABEL | DATA_LABEL);
		
		graph_1->instruction_code=GLEA;
		graph_1->inode_arity=1;
		
		graph_1->instruction_parameters[0].l=static_characters_label;
		graph_1->instruction_parameters[1].i=(value<<(1+STACK_ELEMENT_LOG_SIZE))+NODE_POINTER_OFFSET;
		
		return;
	}

	graph_2=char_descriptor_graph();
	graph_3=g_load_i (value);
	graph_4=g_fill_3 (graph_1,graph_2,graph_3);
	
	s_put_a (a_offset,graph_4);
}

void code_fillC_b (int b_offset,int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	
	graph_2=char_descriptor_graph();
	graph_1=s_get_a (a_offset);
	graph_3=s_get_b (b_offset);
	graph_4=g_fill_3 (graph_1,graph_2,graph_3);

	s_put_a (a_offset,graph_4);
}

void code_fillF_b (int b_offset,int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5;
	
	if (!parallel_flag && last_FILE_descriptor_block==last_block)
		graph_2=last_FILE_descriptor_graph;
	else {
		graph_2=g_FILE_label();

		if (!parallel_flag){
			last_FILE_descriptor_graph=graph_2;
			last_FILE_descriptor_block=last_block;
		}
	}
	
	graph_1=s_get_a (a_offset);	
	graph_3=s_get_b (b_offset+1);
	graph_4=s_get_b (b_offset);
	
	graph_5=g_fill_4 (graph_1,graph_2,graph_3,graph_4);

	s_put_a (a_offset,graph_5);
}

void code_fillI (CleanInt value,int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_3,graph_4,graph_5;

	graph_1=s_get_a (a_offset);

	if (!parallel_flag &&
#ifndef G_A64
		(unsigned long)value<(unsigned long)33 && graph_1->instruction_code==GCREATE)
#else
		(uint_64)value<(uint_64)33 && graph_1->instruction_code==GCREATE)
#endif
	{
		if (small_integers_label==NULL)
			small_integers_label=enter_label ("small_integers",IMPORT_LABEL | DATA_LABEL);
		
		graph_1->instruction_code=GLEA;
		graph_1->inode_arity=1;
		
		graph_1->instruction_parameters[0].l=small_integers_label;
		graph_1->instruction_parameters[1].i=(value<<(STACK_ELEMENT_LOG_SIZE+1))+NODE_POINTER_OFFSET;
		
		return;
	}

	graph_3=int_descriptor_graph();
	graph_4=g_load_i (value);
	graph_5=g_fill_3 (graph_1,graph_3,graph_4);
	
	s_put_a (a_offset,graph_5);
}

void code_fillI_b (int b_offset,int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_3,graph_4,graph_5;
	
	graph_3=int_descriptor_graph();
	graph_1=s_get_a (a_offset);
	graph_4=s_get_b (b_offset);
	graph_5=g_fill_3 (graph_1,graph_3,graph_4);

	s_put_a (a_offset,graph_5);
}

void code_fillR (double value,int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5;

	graph_2=real_descriptor_graph();
	graph_1=s_get_a (a_offset);

	if (!mc68881_flag){
		DOUBLE r=value;
		
		graph_3=g_load_i (((long*)&r)[0]);
		graph_4=g_load_i (((long*)&r)[1]);		
		graph_5=g_fill_4 (graph_1,graph_2,graph_3,graph_4);
	} else {
		graph_3=g_fload_i (value);
		graph_5=g_fill_r (graph_1,graph_2,graph_3);
	}
	
	s_put_a (a_offset,graph_5);
}

void code_fillR_b (int b_offset,int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6;

	graph_4=real_descriptor_graph();	
	graph_1=s_get_b (b_offset);
#ifndef G_A64
	graph_2=s_get_b (b_offset+1);
#endif
	
	graph_5=s_get_a (a_offset);
	
#ifdef M68000
	if (!mc68881_flag)
		graph_6=g_fill_4 (graph_5,graph_4,graph_1,graph_2);
	else
#endif
	{
#ifdef G_A64
		graph_3=g_fp_arg (graph_1);
#else
		graph_3=g_fjoin (graph_1,graph_2);
#endif
		graph_6=g_fill_r (graph_5,graph_4,graph_3);
	}
	
	s_put_a (a_offset,graph_6);
}

void code_fill_a (int from_offset,int to_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3
#if defined (sparc) || defined (G_POWER)
	,graph_4,graph_5,graph_6,graph_7
#endif
	;
	
	if (from_offset==to_offset)
		return;

#if defined (sparc) || defined (G_POWER)
	graph_1=s_get_a (from_offset);
	graph_2=s_get_a (to_offset);
	graph_3=g_movem (0-NODE_POINTER_OFFSET,graph_1,3);
	graph_4=g_movemi (0,graph_3);
	graph_5=g_movemi (1,graph_3);
	graph_6=g_movemi (2,graph_3);
	graph_7=g_fill_4 (graph_2,graph_4,graph_5,graph_6);
	
	s_put_a (to_offset,graph_7);
#else
	graph_1=s_get_a (from_offset);
	graph_2=s_get_a (to_offset);
	graph_3=g_copy (graph_1,graph_2);

	s_put_a (to_offset,graph_3);
#endif
}

void code_fillcaf (char *label_name,int a_stack_size,int b_stack_size)
{
	union instruction_parameter *parameter;
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	int n_arguments,a_offset,b_offset;
	LABEL *label;
		
	label=enter_label (label_name,0);

	graph_1=g_lea (label);

	n_arguments=a_stack_size+b_stack_size;

	graph_2=g_fill_m (graph_1,n_arguments+1);
	parameter=&graph_2->instruction_parameters[1];

	parameter->p=g_load_i (a_stack_size>0 ? a_stack_size : 1);
	++parameter;

	for (a_offset=0; a_offset<a_stack_size; ++a_offset){
		parameter->p=s_get_a (a_offset);
		++parameter;
	}

	for (b_offset=0; b_offset<b_stack_size; ++b_offset){
		parameter->p=s_get_b (b_offset);
		++parameter;
	}

	if (a_stack_size>0){
		INSTRUCTION_GRAPH graph_5,graph_6,graph_7,graph_8;
		LABEL *caf_listp_label;

		caf_listp_label=enter_label ("caf_listp",
#if defined (G_AI64) && defined (LINUX)
										rts_got_flag ? USE_GOT_LABEL | DATA_LABEL | IMPORT_LABEL :
#endif
										DATA_LABEL | IMPORT_LABEL);
		
		graph_5=g_lea (caf_listp_label);
		graph_6=g_sub (g_load_i (STACK_ELEMENT_SIZE),g_load_id (0,graph_5));
		graph_7=g_fill_2 (graph_6,graph_2);
		graph_8=g_fill_2 (graph_5,g_keep (graph_7,graph_2));
		
		graph_3=s_get_a (0);
		graph_4=g_keep (graph_8,graph_3);
		s_put_a (0,graph_4);
	} else {
		graph_3=s_get_b (0);

#ifdef G_A64
		if (b_stack_size>0 && graph_3->instruction_code==GFROMF)
			graph_4=g_fromf (g_fkeep (graph_2,g_fp_arg (graph_3)));
		else
#else
		if (b_stack_size>=2 && graph_3->instruction_code==GFHIGH){
			graph_4=s_get_b (1);
			if (graph_4->instruction_code==GFLOW &&
				graph_3->instruction_parameters[0].p==graph_4->instruction_parameters[0].p)
			{
				INSTRUCTION_GRAPH graph_5,graph_6;

				graph_4=g_fkeep (graph_2,g_fjoin (graph_3,graph_4));

				g_fhighlow (graph_5,graph_6,graph_4);
				
				s_put_b (0,graph_5);
				s_put_b (1,graph_6);

				return;
			}
		}
#endif

		graph_4=g_keep (graph_2,graph_3);
		s_put_b (0,graph_4);
	}
}

#if defined (I486) || defined (ARM)
void code_floordivI (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;

	graph_1=s_pop_b();
	graph_2=s_get_b (0);

	if (graph_2->instruction_code==GLOAD_I){
		int n;

		n=graph_2->instruction_parameters[0].i;
		if (n>0 && (n & (n-1))==0){
			int n_bits;

			n_bits=0;
			while (n>2){
				n_bits+=2;
				n>>=2;
			}
			n_bits+=n-1;

			if (n_bits==0)
				graph_3=graph_1;
			else
				graph_3=g_asr (g_load_i (n_bits),graph_1);
			s_put_b (0,graph_3);

			return;
		} else if (n<0 && ((-n) & ((-n)-1))==0){
			INSTRUCTION_GRAPH graph_4;
			unsigned int i;
			int n_bits;
		
			i=-n;
			n_bits=0;
			while (i>2){
				n_bits+=2;
				i>>=2;
			}
			n_bits+=i-1;

			if (n_bits==0)
				graph_3=g_neg (graph_1);
			else {
				graph_4 = g_neg (g_and (g_load_i ((-n)-1),graph_1));
				if (n_bits>1) /* not for -2 */
					graph_4 = g_asr (g_load_i (n_bits),graph_4);
				graph_3 = g_sub (g_asr (g_load_i (n_bits),graph_1),graph_4);
			}

			s_put_b (0,graph_3);

			return;
		} else
			/* prevent sharing to optimise divide by constant */
			graph_2=g_load_i (n);
	}

	graph_3=g_floordiv (graph_2,graph_1);
	s_put_b (0,graph_3);
}
#endif

void code_get_desc_arity (int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6,graph_7;
	
	graph_1=s_get_a (a_offset);
#ifdef NEW_DESCRIPTORS
	graph_2=g_load_id (0,graph_1);
	graph_3=g_load_des_id (2-2,graph_2);
	graph_4=g_add (graph_3,graph_2);
	graph_7=g_load_des_id (6+DESCRIPTOR_ARITY_OFFSET,graph_4);	
#else
# ifndef M68000
	graph_2=g_load_id (0,graph_1);
	graph_3=g_load_i (-2);
# else
	graph_2=g_load_des_id (DESCRIPTOR_OFFSET,graph_1);
	graph_3=g_g_register (GLOBAL_DATA_REGISTER);
# endif
	graph_4=g_add (graph_3,graph_2);
	graph_5=g_load_des_id (2,graph_4);
	graph_6=g_sub (graph_5,graph_4);
	graph_7=g_load_des_id (DESCRIPTOR_ARITY_OFFSET,graph_6);
#endif
	s_push_b (graph_7);
}

void code_get_desc_arity_offset (void)
{
	INSTRUCTION_GRAPH graph_1;

# ifdef MACH_O64
	graph_1=g_load_i (1<<4);
# elif defined (G_A64) && defined (LINUX)
	graph_1=g_load_i (1<<(pic_flag ? 4 : 3));
# else
	graph_1=g_load_i (1<<(3));
# endif
	s_push_b (graph_1);
}

void code_get_desc0_number (void)
{
	INSTRUCTION_GRAPH graph_1,graph_2;

	graph_1=s_pop_b();
	graph_2=g_load_id (-2-2*STACK_ELEMENT_SIZE,graph_1);
	s_push_b (graph_2);
}

void code_get_node_arity (int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6;

	graph_1=s_get_a (a_offset);
	graph_2=g_load_id (0,graph_1);
	graph_6=g_load_des_id (-2,graph_2);

	s_push_b (graph_6);
}

void code_get_desc_flags_b (void)
{
	INSTRUCTION_GRAPH graph_1,graph_2;

	graph_1=s_pop_b ();
	graph_2=g_load_des_id (-2-2+DESCRIPTOR_ARITY_OFFSET,graph_1);
	
	s_push_b (graph_2);
}

void code_get_thunk_arity (void)
{
	INSTRUCTION_GRAPH graph_1,graph_2;

	graph_1=s_pop_b ();
#ifdef G_A64
	graph_2=g_load_sqb_id (-4,graph_1);
#else
	graph_2=g_load_id (-4,graph_1);
#endif

#ifdef PROFILE
	if (callgraph_profiling){
		INSTRUCTION_GRAPH graph_3,graph_4;

		graph_3=g_load_i (257);
		graph_4=g_sub (graph_3,graph_2);
		s_push_b (graph_4);
		return;
	}
#endif

	s_push_b (graph_2);
}

void code_get_thunk_desc (void)
{
	INSTRUCTION_GRAPH graph_1,graph_2;

	graph_1=s_pop_b ();

#ifdef G_A64
	graph_2=g_load_sqb_id (-8,graph_1);
#else
	graph_2=g_load_id (-8,graph_1);	
#endif

#if (defined (LINUX) && defined (G_AI64)) || defined (ARM)
#  ifndef MACH_O64
	if (pic_flag)
#  endif
	graph_2 = g_add (g_add (g_load_i (-8),graph_1),graph_2);
#endif

	s_push_b (graph_2);
}

void code_gtC (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_pop_b();
	graph_2=s_get_b (0);
	graph_3=g_cmp_gt (graph_2,graph_1);
	
	s_put_b (0,graph_3);
}

void code_gtI (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_pop_b();
	graph_2=s_get_b (0);
	graph_3=g_cmp_gt (graph_2,graph_1);
	
	s_put_b (0,graph_3);
}

void code_gtR (VOID)
{
#ifdef G_A64
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5;
	
	graph_1=s_pop_b();
	graph_2=g_fp_arg (graph_1);

	graph_3=s_pop_b();
	graph_4=g_fp_arg (graph_3);

	graph_5=g_fcmp_gt (graph_4,graph_2);

	s_push_b (graph_5);
#else
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6,graph_7;

# ifdef M68000
	if (!mc68881_flag){
		if (gt_real==NULL)
			gt_real=enter_label ("gt_real",IMPORT_LABEL);

		code_dyadic_sane_operator (gt_real);
		init_b_stack (1,i_vector);
	} else {
# endif
		graph_1=s_pop_b();
		graph_2=s_pop_b();
		graph_3=g_fjoin (graph_1,graph_2);
	
		graph_4=s_pop_b();
		graph_5=s_pop_b();
		graph_6=g_fjoin (graph_4,graph_5);
	
		graph_7=g_fcmp_gt (graph_6,graph_3);
	
		s_push_b (graph_7);
# ifdef M68000
	}
# endif
#endif
}

#if defined (I486) || defined (ARM)
void code_gtU (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_pop_b();
	graph_2=s_get_b (0);
	graph_3=g_cmp_gtu (graph_2,graph_1);
	
	s_put_b (0,graph_3);
}
#endif

void code_halt (VOID)
{
	if (halt_label==NULL)
		halt_label=enter_rts_label ("halt");
	
	end_basic_block_with_registers (0,0,e_vector);
	
	i_jmp_l (halt_label,0);

	reachable=0;
	
	begin_new_basic_block();
}

void code_incI (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_get_b (0);
	graph_2=g_load_i (1);
	graph_3=g_add (graph_2,graph_1);
	
	s_put_b (0,graph_3);
}

void code_instruction (CleanInt i)
{
	i_word_i (i);
}

void code_is_record (int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6,graph_7;
	
	graph_1=s_get_a (a_offset);
#if defined (sparc) || defined (I486) || defined (ARM) || defined (G_POWER)
	graph_2=g_load_id (0,graph_1);
	graph_5=g_load_des_id (-2,graph_2);
#else
	graph_2=g_load_des_id (DESCRIPTOR_OFFSET,graph_1);
	graph_3=g_g_register (GLOBAL_DATA_REGISTER);
	graph_4=g_add (graph_3,graph_2);
	graph_5=g_load_des_id (0,graph_4);
#endif
	
	graph_6=g_load_i (127);
	graph_7=g_cmp_gt (graph_6,graph_5);
	
	s_push_b (graph_7);
}

void code_ItoC (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_get_b (0);
	
	graph_2=g_load_i (255);
	graph_3=g_and (graph_2,graph_1);
	
	s_put_b (0,graph_3);
}

void code_ItoP (void)
{
	if (ItoP_label==NULL)
		ItoP_label=enter_label ("ItoP",IMPORT_LABEL);

	s_push_b (s_get_b (0));
	s_put_b (1,NULL);
	insert_basic_block (JSR_BLOCK,0,1+1,i_i_vector,ItoP_label);
		
	init_b_stack (1,i_vector);
}

void code_ItoR (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;

#ifdef M68000
	if (!mc68881_flag){
		if (i_to_r_real==NULL)
			i_to_r_real=enter_label ("i_to_r_real",IMPORT_LABEL);

		s_push_b (s_get_b (0));
		s_put_b (1,NULL);
		insert_basic_block (JSR_BLOCK,0,1+1,i_vector,i_to_r_real);
		init_b_stack (2,r_vector);
	} else {
#endif
		graph_1=s_pop_b();
		graph_2=g_fitor (graph_1);

#ifdef G_A64
		graph_3=g_fromf (graph_2);
#else
		g_fhighlow (graph_3,graph_4,graph_2);
#endif

#ifndef G_A64
		s_push_b (graph_4);
#endif
		s_push_b (graph_3);
#ifdef M68000
	}
#endif
}

LABEL *profile_function_label;
static struct basic_block *profile_function_block;

int profile_flag=PROFILE_NORMAL;

static void code_jmp_label (LABEL *label);

static void code_jmp_ap_ (int n_apply_args)
{
    if (n_apply_args==1){
#if defined (I486) || defined (ARM)
		end_basic_block_with_registers (2,0,e_vector);
		i_move_id_r (0,REGISTER_A1,REGISTER_A2);
# ifdef PROFILE
		if (profile_function_label!=NULL)
#  ifdef MACH_O64
			i_jmp_id_profile (8-2,REGISTER_A2,0);
#  elif defined (G_A64) && defined (LINUX)
			i_jmp_id_profile (pic_flag ? 8-2 : 4-2,REGISTER_A2,0);
#  else
			i_jmp_id_profile (4-2,REGISTER_A2,0);			
#  endif
		else
# endif
# ifdef MACH_O64
		i_jmp_id (8-2,REGISTER_A2,0);
# elif defined (G_A64) && defined (LINUX)
		i_jmp_id (pic_flag ? 8-2 : 4-2,REGISTER_A2,0);
# else
		i_jmp_id (4-2,REGISTER_A2,0);
# endif
#else
		INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5;

		graph_1=s_get_a (0);

# if defined (sparc) || defined (G_POWER)
#  pragma unused (graph_3,graph_4)
		graph_2=g_load_id (0,graph_1);
		graph_5=g_load_id (4-2,graph_2);
# else
		graph_2=g_load_des_id (DESCRIPTOR_OFFSET,graph_1);
		graph_3=g_g_register (GLOBAL_DATA_REGISTER);

		graph_4=g_add (graph_3,graph_2);

#  if defined (M68000) && !defined (SUN)
		graph_5=g_load_des_id (2,graph_4);
#  else
		graph_5=g_load_id (4,graph_4);
#  endif
# endif

		s_push_a (graph_5);

		end_basic_block_with_registers (3,0,e_vector);
# if defined (M68000) && !defined (SUN)
		i_add_r_r (GLOBAL_DATA_REGISTER,REGISTER_A2);
# endif
# ifdef PROFILE
		if (profile_function_label!=NULL)
			i_jmp_id_profile (0,REGISTER_A2,2<<4);
		else
# endif
			i_jmp_id (0,REGISTER_A2,2<<4);
#endif
		demand_flag=0;
	
		reachable=0;
	
		begin_new_basic_block();
	} else {
		char ap_label_name[32];
		LABEL *label;

		sprintf (ap_label_name,"ap_%d",n_apply_args);
		label=enter_label (ap_label_name,
#if defined (G_AI64) && defined (LINUX)
			rts_got_flag ? USE_GOT_LABEL :
#endif
			0);
		code_jmp_label (label);
	}
}

static void code_jmp_label (LABEL *label)
{
	int a_stack_size,b_stack_size,n_a_and_f_registers;
	ULONG *vector;

	if (demand_flag){
		a_stack_size=demanded_a_stack_size;
		b_stack_size=demanded_b_stack_size;
		vector=demanded_vector;
		
		end_basic_block_with_registers (a_stack_size,b_stack_size,vector);
	} else {
		generate_code_for_previous_blocks (1);
		if (!(label->label_flags & REGISTERS_ALLOCATED)){
			label->label_a_stack_size=get_a_stack_size();
			label->label_vector=&label->label_small_vector;
			label->label_b_stack_size=get_b_stack_size (&label->label_vector);
			label->label_flags |= REGISTERS_ALLOCATED;
		}
		
		a_stack_size=label->label_a_stack_size;
		b_stack_size=label->label_b_stack_size;
		vector=label->label_vector;
		
		end_stack_elements (a_stack_size,b_stack_size,vector);
		linearize_stack_graphs();
		adjust_stack_pointers();
	}

	n_a_and_f_registers=0;
	
	if (mc68881_flag){
		int parameter_n;

		for (parameter_n=0; parameter_n<b_stack_size; ++parameter_n)
			if (test_bit (vector,parameter_n))
				if (n_a_and_f_registers<N_FLOAT_PARAMETER_REGISTERS){
					++n_a_and_f_registers;
#ifndef G_A64
					++parameter_n;
#endif
				} else
					break;
	}

	n_a_and_f_registers+=
		(a_stack_size<=N_ADDRESS_PARAMETER_REGISTERS) ? (a_stack_size<<4) : (N_ADDRESS_PARAMETER_REGISTERS<<4);

#ifdef PROFILE
	if (profile_function_label!=NULL && profile_flag!=PROFILE_NOT && demand_flag){
		int tail_call_profile;
		
		if (profile_flag==PROFILE_TAIL)
			tail_call_profile=1;
		else {
			struct block_label *profile_block_label;
			
			tail_call_profile=0;
			
			if (profile_function_block!=NULL){
				for_l (profile_block_label,profile_function_block->block_labels,block_label_next)
					if (profile_block_label->block_label_label==label)
						tail_call_profile=1;
			}
		}
		
		if (! tail_call_profile)
			i_jmp_l_profile (label,0);
		else
			i_jmp_l_profile (label,profile_offset);
	} else
#endif
		i_jmp_l (label,n_a_and_f_registers);

	profile_flag=PROFILE_NORMAL;
	demand_flag=0;
	
	reachable=0;
	
	begin_new_basic_block();
}

void code_jmp (char label_name[])
{
	LABEL *label;

	label=enter_label (label_name,0);
	code_jmp_label (label);
}

void code_jmpD (char c1,char c2,char descriptor_name[],int arity,char label_name1[],char label_name2[])
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	LABEL *descriptor,*label1,*label2;

	descriptor=enter_label (descriptor_name,DATA_LABEL);

	graph_1=s_get_b (0);

#if defined (G_A64) && defined (LINUX)
	if (pic_flag && descriptor->label_flags & USE_GOT_LABEL){
		descriptor=enter_got_label (descriptor_name,arity,DATA_LABEL);
		graph_2=g_lea (descriptor);
	} else
#endif
	graph_2=g_load_des_i (descriptor,arity);

	graph_3=g_instruction_2 (c1=='b' ? GCMP_LT : c1=='a' ? GCMP_GT : GCMP_EQ,graph_2,graph_1);

	label1=enter_label (label_name1,0);
	label2=enter_label (label_name2,0);

	mark_and_count_graph (graph_3);

	generate_code_for_previous_blocks (0);

	if (!(label1->label_flags & REGISTERS_ALLOCATED)){
		label1->label_a_stack_size=get_a_stack_size();
		label1->label_vector=&label1->label_small_vector;
		label1->label_b_stack_size=get_b_stack_size (&label1->label_vector);
		label1->label_flags |= REGISTERS_ALLOCATED;
	}

	end_stack_elements (label1->label_a_stack_size,label1->label_b_stack_size,label1->label_vector);

	linearize_stack_graphs();

	calculate_and_linearize_branch_true (label1,graph_3);

	begin_new_basic_block();
#ifdef MORE_PARAMETER_REGISTERS
	init_ab_stack (label1->label_a_stack_size,label1->label_b_stack_size,label1->label_vector);
#else
	init_a_stack (label1->label_a_stack_size);
	init_b_stack (label1->label_b_stack_size,label1->label_vector);
#endif

	if (!(label2->label_flags & REGISTERS_ALLOCATED)){
		int label1_b_stack_size;
		ULONG *vector1;

		label2->label_a_stack_size=label1->label_a_stack_size;
		label1_b_stack_size=label1->label_b_stack_size;
		label2->label_b_stack_size=label1_b_stack_size;
		label2->label_flags |= REGISTERS_ALLOCATED;

		vector1 = label1->label_vector;
		if (label1_b_stack_size<=VECTOR_ELEMENT_SIZE){
			label2->label_small_vector=*vector1;
			label2->label_vector=&label2->label_small_vector;
		} else {
			int i,vector_size;
			ULONG *vector2;

			vector_size=(label1_b_stack_size+VECTOR_ELEMENT_SIZE-1)>>LOG_VECTOR_ELEMENT_SIZE;
			vector2=(ULONG*)fast_memory_allocate (vector_size*sizeof (ULONG));
			for (i=0; i<vector_size; ++i);
				vector2[i] = vector1[i];
			label2->label_vector=vector2;
		}
	}

	end_stack_elements (label2->label_a_stack_size,label2->label_b_stack_size,label2->label_vector);

	linearize_stack_graphs();

	linearize_branch (c2,label2);

	begin_new_basic_block();
#ifdef MORE_PARAMETER_REGISTERS
	init_ab_stack (label2->label_a_stack_size,label2->label_b_stack_size,label2->label_vector);
#else
	init_a_stack (label2->label_a_stack_size);
	init_b_stack (label2->label_b_stack_size,label2->label_vector);
#endif
}

void code_jmp_upd (char label_name[])
{
	LABEL *label;
	int a_stack_size,b_stack_size,n_a_and_f_registers;
	ULONG *vector;

	label=enter_label (label_name,0);
	
	if (demand_flag){
		a_stack_size=demanded_a_stack_size;
		b_stack_size=demanded_b_stack_size;
		vector=demanded_vector;
		
		end_basic_block_with_registers (a_stack_size,b_stack_size,vector);
	} else
		error ("Directive .d missing before jmp_upd instruction");

	n_a_and_f_registers=0;
	
	if (mc68881_flag){
		int parameter_n;

		for (parameter_n=0; parameter_n<b_stack_size; ++parameter_n)
			if (test_bit (vector,parameter_n))
				if (n_a_and_f_registers<N_FLOAT_PARAMETER_REGISTERS){
					++n_a_and_f_registers;
#ifndef G_A64
					++parameter_n;
#endif
				} else
					break;
	}

	n_a_and_f_registers+=
		(a_stack_size<=N_ADDRESS_PARAMETER_REGISTERS) ? (a_stack_size<<4) : (N_ADDRESS_PARAMETER_REGISTERS<<4);

	i_lea_l_i_r (label,0,REGISTER_A2);
	
	{
		char jmpupd_label_name[32];
		LABEL *jmpupd_label;

		sprintf (jmpupd_label_name,"jmpupd_%d",a_stack_size);

		jmpupd_label=enter_label (jmpupd_label_name,IMPORT_LABEL);

		i_jmp_l (jmpupd_label,n_a_and_f_registers);
	}

	profile_flag=PROFILE_NORMAL;
	demand_flag=0;
	
	reachable=0;
	
	begin_new_basic_block();
}

void code_jmp_ap (int n_apply_args)
{
	code_d (1+n_apply_args,0,e_vector);
	code_jmp_ap_ (n_apply_args);
}

void code_jmp_ap_upd (int n_apply_args)
{
#if (defined (I486) || defined (ARM)) && !defined (G_AI64)
	char apupd_label_name[32];

	code_d (1+n_apply_args,0,e_vector);

	sprintf (apupd_label_name,"apupd_%d",n_apply_args);
	code_jmp (apupd_label_name);
#else
	code_jsr_ap (n_apply_args);
	code_fill_a (0,1);
	s_remove_a();
	code_d (1,0,e_vector);
	code_rtn();
#endif
}

void code_label (char *label_name);

void code_jmp_eval (VOID)
{
	LABEL *label;

	end_basic_block_with_registers (1,0,e_vector);

	i_move_id_r (0,REGISTER_A0,REGISTER_D0);
	sprintf (eval_label_s,"e_%d",eval_label_number++);
	label=enter_label (eval_label_s,0);

#ifndef M68000
	i_btst_i_r (2,REGISTER_D0);
# ifdef G_POWER
	i_bnep_l (label);
# else
	i_bne_l (label);
# endif
# if defined (I486) || defined (ARM)
#  ifdef PROFILE
	if (profile_function_label!=NULL)
		i_jmp_r_profile (REGISTER_D0);
	else
#  endif
	i_jmp_r (REGISTER_D0);
# else
#  ifdef PROFILE
	if (profile_function_label!=NULL)
		i_jmp_id_profile (0,REGISTER_D0,256);
	else
#  endif
		i_jmp_id (0,REGISTER_D0,256);
# endif
#else
	i_bmi_l (label);
	i_move_r_r (REGISTER_D0,REGISTER_A1);
	i_jmp_id (0,REGISTER_A1,256);
#endif
	
	reachable=0;

	begin_new_basic_block();

	code_label (eval_label_s);
#if ! (defined (sparc) || defined (G_POWER))
# ifdef PROFILE
	if (profile_function_label!=NULL)
		i_rts_profile ();
	else
# endif
	i_rts ();
#else
# ifdef PROFILE
	if (profile_function_label!=NULL)
		i_rts_profile (0,4);
	else
# endif
		i_rts (0,4);
#endif
	
	demand_flag=0;

	reachable=0;
	
	begin_new_basic_block();
}

void code_jmp_eval_upd (VOID)
{
	LABEL *label;

	end_basic_block_with_registers (2,0,e_vector);

	i_move_id_r (0,REGISTER_A1,REGISTER_D0);
	sprintf (eval_label_s,"e_%d",eval_label_number++);
	label=enter_label (eval_label_s,0);

#ifndef M68000
	i_btst_i_r (2,REGISTER_D0);
# ifdef G_POWER
	i_bnep_l (label);
# else
	i_bne_l (label);
# endif
# if defined (I486) || defined (ARM)
	i_sub_i_r (20,REGISTER_D0);
#  ifdef PROFILE
	if (profile_function_label!=NULL)
		i_jmp_r_profile (REGISTER_D0);
	else
#  endif
	i_jmp_r (REGISTER_D0);
# else
#  ifdef PROFILE
	if (profile_function_label!=NULL)
#  if defined (G_POWER) && (defined (MACH_O) || defined (LINUX_ELF))
		i_jmp_id_profile (-28,REGISTER_D0,128);
#  else
		i_jmp_id_profile (-20,REGISTER_D0,128);
#  endif
	else
#  endif
#  if defined (G_POWER) && (defined (MACH_O) || defined (LINUX_ELF))
		i_jmp_id (-28,REGISTER_D0,128);
#  else
		i_jmp_id (-20,REGISTER_D0,128);
#  endif
# endif
#else
	i_bmi_l (label);
	i_move_r_r (REGISTER_D0,REGISTER_A2);
	i_jmp_id (-12,REGISTER_A2,128);
#endif
	
	reachable=0;

	begin_new_basic_block();

	code_label (eval_label_s);
#	ifdef M68000
		i_move_pi_id (REGISTER_A1,0,REGISTER_A0);
		i_move_pi_id (REGISTER_A1,4,REGISTER_A0);
		i_move_id_id (0,REGISTER_A1,8,REGISTER_A0);
#	else
		i_move_r_id (REGISTER_D0,0,REGISTER_A0);
#		if defined (I486) || defined (ARM)
#		 ifndef THREAD32
			i_move_id_id (STACK_ELEMENT_SIZE,REGISTER_A1,STACK_ELEMENT_SIZE,REGISTER_A0);
			i_move_id_id (2*STACK_ELEMENT_SIZE,REGISTER_A1,2*STACK_ELEMENT_SIZE,REGISTER_A0);
#		 else
			i_move_id_r (STACK_ELEMENT_SIZE,REGISTER_A1,REGISTER_A2);
			i_move_r_id (REGISTER_A2,STACK_ELEMENT_SIZE,REGISTER_A0);
			i_move_id_r (2*STACK_ELEMENT_SIZE,REGISTER_A1,REGISTER_A2);
			i_move_r_id (REGISTER_A2,2*STACK_ELEMENT_SIZE,REGISTER_A0);
#		 endif
#		else
			i_move_id_r (STACK_ELEMENT_SIZE,REGISTER_A1,REGISTER_D1);
			i_move_id_r (2*STACK_ELEMENT_SIZE,REGISTER_A1,REGISTER_D2);
			i_move_r_id (REGISTER_D1,STACK_ELEMENT_SIZE,REGISTER_A0);
			i_move_r_id (REGISTER_D2,2*STACK_ELEMENT_SIZE,REGISTER_A0);
#		endif
#	endif

#	if ! (defined (sparc) || defined (G_POWER))
#    ifdef PROFILE
		if (profile_function_label!=NULL)
			i_rts_profile();
		else
#    endif
		i_rts ();
#	else
#	 ifdef PROFILE
		if (profile_function_label!=NULL)
			i_rts_profile (0,4);
		else
#	 endif
			i_rts (0,4);
#	endif

	demand_flag=0;

	reachable=0;
	
	begin_new_basic_block();
}

void code_jmp_false (char label_name[])
{
	INSTRUCTION_GRAPH graph_1,store_calculate_with_overflow_graph;
	LABEL *label;
	
	label=enter_label (label_name,0);
	
	graph_1=s_pop_b();
	mark_and_count_graph (graph_1);
	
	generate_code_for_previous_blocks (0);
	
	if (!(label->label_flags & REGISTERS_ALLOCATED)){
		label->label_a_stack_size=get_a_stack_size();
		label->label_vector=&label->label_small_vector;
		label->label_b_stack_size=get_b_stack_size (&label->label_vector);
		label->label_flags |= REGISTERS_ALLOCATED;
	}
	
	end_stack_elements (label->label_a_stack_size,label->label_b_stack_size,label->label_vector);

	if (graph_1->instruction_code==GTEST_O &&
		(store_calculate_with_overflow_graph=search_and_remove_graph_from_b_stack (graph_1->instruction_parameters[0].p))!=NULL)
	{
		linearize_stack_graphs_with_overflow_test (graph_1,store_calculate_with_overflow_graph);
	} else
		linearize_stack_graphs();
	
	calculate_and_linearize_branch_false (label,graph_1);
	
	begin_new_basic_block();
#ifdef MORE_PARAMETER_REGISTERS
	init_ab_stack (label->label_a_stack_size,label->label_b_stack_size,label->label_vector);
#else
	init_a_stack (label->label_a_stack_size);
	init_b_stack (label->label_b_stack_size,label->label_vector);
#endif
}

void code_jmp_i (int n_apply_args)
{
	int a_stack_size,b_stack_size,used_n_address_parameter_registers,a_reg_n;
	ULONG *vector;

	if (!demand_flag)
		error ("Directive .d missing before jmp_i instruction");

	a_stack_size=demanded_a_stack_size;
	b_stack_size=demanded_b_stack_size;
	vector=demanded_vector;
	
	end_basic_block_with_registers (a_stack_size,b_stack_size,vector);

	used_n_address_parameter_registers=a_stack_size;
	if (used_n_address_parameter_registers>N_ADDRESS_PARAMETER_REGISTERS)
		used_n_address_parameter_registers=N_ADDRESS_PARAMETER_REGISTERS;

	a_reg_n=a_reg_num (N_ADDRESS_PARAMETER_REGISTERS);

	i_move_id_r (0,num_to_a_reg (used_n_address_parameter_registers-1),a_reg_n);

#ifdef MACH_O64
	i_move_id_r (6+((n_apply_args-1)<<4),a_reg_n,a_reg_n);
#elif defined (G_A64) && defined (LINUX)
	if (pic_flag)
		i_move_id_r (6+((n_apply_args-1)<<4),a_reg_n,a_reg_n);
	else
		i_loadsqb_id_r (2+((n_apply_args-1)<<3),a_reg_n,a_reg_n);
#else
# if defined (G_A64)
	i_loadsqb_id_r (2+((n_apply_args-1)<<3),a_reg_n,a_reg_n);
# else
	i_move_id_r (2+((n_apply_args-1)<<3),a_reg_n,a_reg_n);
# endif
#endif

	if (profile_function_label!=NULL && profile_flag!=PROFILE_NOT){
#ifndef ARM
# ifdef G_AI64
		i_sub_i_r (32,a_reg_n);
# else
		i_sub_i_r (28,a_reg_n);
# endif
#else
# ifdef G_A64
		i_sub_i_r (28,a_reg_n);
# else
		i_sub_i_r (20,a_reg_n);
# endif
#endif
		i_jmp_r_profile (a_reg_n);
	} else {
#ifndef ARM
		i_sub_i_r (20,a_reg_n);
#else
		i_sub_i_r (12,a_reg_n);
#endif
		i_jmp_r (a_reg_n);
	}

	profile_flag=PROFILE_NORMAL;
	demand_flag=0;
	
	reachable=0;
	
	begin_new_basic_block();
}

void code_jmp_true (char label_name[])
{
	INSTRUCTION_GRAPH graph_1,store_calculate_with_overflow_graph;
	LABEL *label;
	
	label=enter_label (label_name,0);
	
	graph_1=s_pop_b();
	mark_and_count_graph (graph_1);
	
	generate_code_for_previous_blocks (0);
	
	if (!(label->label_flags & REGISTERS_ALLOCATED)){
		label->label_a_stack_size=get_a_stack_size();
		label->label_vector=&label->label_small_vector;
		label->label_b_stack_size=get_b_stack_size (&label->label_vector);
		label->label_flags |= REGISTERS_ALLOCATED;
	}
	
	end_stack_elements (label->label_a_stack_size,label->label_b_stack_size,label->label_vector);

	if (graph_1->instruction_code==GTEST_O &&
		(store_calculate_with_overflow_graph=search_and_remove_graph_from_b_stack (graph_1->instruction_parameters[0].p))!=NULL)
	{
		linearize_stack_graphs_with_overflow_test (graph_1,store_calculate_with_overflow_graph);
	} else
		linearize_stack_graphs();
	
	calculate_and_linearize_branch_true (label,graph_1);
	
	begin_new_basic_block();
#ifdef MORE_PARAMETER_REGISTERS
	init_ab_stack (label->label_a_stack_size,label->label_b_stack_size,label->label_vector);
#else
	init_a_stack (label->label_a_stack_size);
	init_b_stack (label->label_b_stack_size,label->label_vector);
#endif
}

#if defined (M68000) || defined (I486) || defined (ARM)
static void define_label_in_block (LABEL *label_2)
{
	struct block_label *new_label;

	new_label=fast_memory_allocate_type (struct block_label);
	new_label->block_label_label=label_2;
	new_label->block_label_next=NULL;

	if (last_block->block_labels==NULL)
		last_block->block_labels=new_label;
	else
		last_block_label->block_label_next=new_label;
	last_block_label=new_label;
}

static int too_many_b_stack_parameters_for_registers (int b_stack_size,int n_data_parameter_registers)
{
	int offset,n_data_registers,n_float_registers;
	int n_float_parameter_registers;
	
	n_float_parameter_registers= mc68881_flag ? N_FLOAT_PARAMETER_REGISTERS : 0;

	n_data_registers=0;
	n_float_registers=0;

	for (offset=0; offset<b_stack_size; ++offset)
		if (demanded_vector[offset>>LOG_VECTOR_ELEMENT_SIZE] & (((ULONG)1)<<(offset & VECTOR_ELEMENT_MASK))){
			if (++n_float_registers>n_float_parameter_registers)
				break;
#ifndef G_A64
			++offset;
#endif
		} else
			if (++n_data_registers>n_data_parameter_registers)
				break;

	return n_data_registers>n_data_parameter_registers || n_float_registers>n_float_parameter_registers;
}
#endif

static void code_jsr_label (LABEL *label);

static void code_jsr_ap_ (int n_apply_args)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5;

	if (n_apply_args==1){
#if !(defined (I486) || defined (ARM))
		graph_1=s_get_a (0);
# if defined (sparc) || defined (G_POWER)
#  pragma unused (graph_3,graph_4)
		graph_2=g_load_id (0,graph_1);
		graph_5=g_load_id (4-2,graph_2);
# else
		graph_2=g_load_des_id (DESCRIPTOR_OFFSET,graph_1);
		graph_3=g_g_register (GLOBAL_DATA_REGISTER);
		graph_4=g_add (graph_3,graph_2);

#  if defined (M68000) && !defined (SUN)	
		graph_5=g_load_des_id (2,graph_4);
#  else
		graph_5=g_load_id (4,graph_4);
#  endif
# endif
		s_push_a (graph_5);
#endif

		if (demand_flag)
			offered_after_jsr=1;
		demand_flag=0;

#if defined (I486) || defined (ARM)
		insert_basic_block (APPLY_BLOCK,2,0,e_vector,NULL);
#else
		insert_basic_block (APPLY_BLOCK,3,0,e_vector,NULL);
#endif
		init_a_stack (1);
	} else {
		char ap_label_name[32];
		LABEL *label;

		sprintf (ap_label_name,"ap_%d",n_apply_args);
		label=enter_label (ap_label_name,
#if defined (G_AI64) && defined (LINUX)
			rts_got_flag ? USE_GOT_LABEL :
#endif
			0);
		code_jsr_label (label);
	}
}

void code_jsr_i (int n_apply_args)
{
	INSTRUCTION_GRAPH graph;
	int b_stack_size,n_data_parameter_registers,jsr_i_offset;
	LABEL *label_2;

	if (!demand_flag)
		error ("Directive .d missing before jsr_i instruction");

	offered_after_jsr=1;
	demand_flag=0;

	n_data_parameter_registers=parallel_flag ? N_DATA_PARAMETER_REGISTERS-1 : N_DATA_PARAMETER_REGISTERS;
# ifdef MORE_PARAMETER_REGISTERS
	if (demanded_a_stack_size<N_ADDRESS_PARAMETER_REGISTERS)
		n_data_parameter_registers += N_ADDRESS_PARAMETER_REGISTERS-demanded_a_stack_size;
# endif
	graph=NULL;

	b_stack_size=demanded_b_stack_size;

# if defined (M68000) || defined (I486)
	if (b_stack_size>n_data_parameter_registers || !mc68881_flag){
		if (too_many_b_stack_parameters_for_registers (b_stack_size,n_data_parameter_registers)){
			sprintf (eval_label_s,"e_%d",eval_label_number++);
			label_2=enter_label (eval_label_s,LOCAL_LABEL);
			graph=g_lea (label_2);
		}
	}
# endif

	insert_graph_in_b_stack (graph,b_stack_size,demanded_vector);

	clear_bit (demanded_vector,b_stack_size);
	++b_stack_size;

# ifdef MACH_O64
	jsr_i_offset = 6+((n_apply_args-1)<<4);
# elif defined (G_A64) && defined (LINUX)
	jsr_i_offset = pic_flag ? (6+((n_apply_args-1)<<4)) : (2+((n_apply_args-1)<<3));
# else
	jsr_i_offset = 2+((n_apply_args-1)<<3);
# endif

	if (profile_function_label!=NULL && profile_flag!=PROFILE_NOT)
		jsr_i_offset|=1;

	insert_basic_JSR_I_block (demanded_a_stack_size,b_stack_size,demanded_vector,jsr_i_offset);

# if defined (M68000) || defined (I486) || defined (ARM)
	if (graph!=NULL)
		define_label_in_block (label_2);
# endif
}

static void code_jsr_label (LABEL *label)
{
	INSTRUCTION_GRAPH graph;
	int b_stack_size,n_data_parameter_registers;
#if defined (M68000) || defined (I486) || defined (ARM)
	LABEL *label_2;
#endif		

	if (!demand_flag)
		error ("Directive .d missing before jsr instruction");

	offered_after_jsr=1;
	demand_flag=0;

	n_data_parameter_registers=parallel_flag ? N_DATA_PARAMETER_REGISTERS-1 : N_DATA_PARAMETER_REGISTERS;
#ifdef MORE_PARAMETER_REGISTERS
	if (demanded_a_stack_size<N_ADDRESS_PARAMETER_REGISTERS)
		n_data_parameter_registers += N_ADDRESS_PARAMETER_REGISTERS-demanded_a_stack_size;
#endif
	graph=NULL;

	b_stack_size=demanded_b_stack_size;

#if defined (M68000) || defined (I486)
	if (b_stack_size>n_data_parameter_registers || !mc68881_flag){
		if (too_many_b_stack_parameters_for_registers (b_stack_size,n_data_parameter_registers)){
			sprintf (eval_label_s,"e_%d",eval_label_number++);
			label_2=enter_label (eval_label_s,LOCAL_LABEL);
			graph=g_lea (label_2);
		}
	}
#endif

	insert_graph_in_b_stack (graph,b_stack_size,demanded_vector);

	clear_bit (demanded_vector,b_stack_size);
	++b_stack_size;

	insert_basic_block (JSR_BLOCK,demanded_a_stack_size,b_stack_size,demanded_vector,label);

#if defined (M68000) || defined (I486) || defined (ARM)
	if (graph!=NULL)
		define_label_in_block (label_2);
#endif
}

void code_jrsr (char label_name[])
{
	LABEL *label;

	label=enter_label (label_name,
#if defined (G_AI64) && defined (LINUX)
						rts_got_flag ? USE_GOT_LABEL :
#endif
						0);
	code_jsr_label (label);
}

void code_jsr (char label_name[])
{
	LABEL *label;

	label=enter_label (label_name,0);
	code_jsr_label (label);
}

void code_jsr_ap (int n_apply_args)
{
	code_d (1+n_apply_args,0,e_vector);
	code_jsr_ap_ (n_apply_args);
	code_o (1,0,e_vector);
}

#ifdef G_POWER
void code_jsr_from_c_to_clean (char *label_name)
{
	LABEL *label;
	INSTRUCTION_GRAPH graph;
	int b_stack_size,n_data_parameter_registers;
#if defined (M68000) || defined (I486) || defined (ARM)
	LABEL *label_2;
#endif		

	n_data_parameter_registers=parallel_flag ? N_DATA_PARAMETER_REGISTERS-1 : N_DATA_PARAMETER_REGISTERS;
	
	if (!demand_flag)
		error ("Directive .d missing before jsr instruction");
	
	label=enter_label (label_name,0);
	
	offered_after_jsr=1;
	demand_flag=0;

	graph=NULL;

	b_stack_size=demanded_b_stack_size;

#if defined (M68000) || defined (I486)
	if (b_stack_size>n_data_parameter_registers || !mc68881_flag){
		if (too_many_b_stack_parameters_for_registers (b_stack_size,n_data_parameter_registers)){
			sprintf (eval_label_s,"e_%d",eval_label_number++);
			label_2=enter_label (eval_label_s,LOCAL_LABEL);
			graph=g_lea (label_2);
		}
	}
#endif

	insert_graph_in_b_stack (graph,b_stack_size,demanded_vector);

	clear_bit (demanded_vector,b_stack_size);
	++b_stack_size;

	insert_basic_block (JSR_BLOCK_WITH_INSTRUCTIONS,demanded_a_stack_size,b_stack_size,demanded_vector,label);

#if defined (M68000) || defined (I486) || defined (ARM)
	if (graph!=NULL)
		define_label_in_block (label_2);
#endif
}
#endif

void code_jsr_eval (int a_offset)
{
	INSTRUCTION_GRAPH graph_1;
	
	if (a_offset!=0){
		graph_1=s_get_a (a_offset);
		s_push_a (graph_1);
	} else
		graph_1=s_get_a (0);

#ifdef M68000
	if (check_stack)
#endif
	{
	LABEL *label;
	struct block_label *new_label;

	sprintf (eval_label_s,"e_%d",eval_label_number++);
	label=enter_label (eval_label_s,LOCAL_LABEL);
	
	insert_basic_block (JSR_EVAL_BLOCK,0,0,e_vector,label);

	new_label=fast_memory_allocate_type (struct block_label);
	new_label->block_label_label=label;
	new_label->block_label_next=NULL;
		
	if (last_block->block_labels==NULL)
		last_block->block_labels=new_label;
	else
		last_block_label->block_label_next=new_label;
	last_block_label=new_label;
	}
#ifdef M68000
	else
		insert_basic_block (JSR_EVAL_BLOCK,0,0,e_vector,NULL);	
#endif

	if (a_offset!=0)
		s_remove_a();
}

void code_keep (int a_offset_1,int a_offset_2)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_get_a (a_offset_1);
	graph_2=s_get_a (a_offset_2);
	
	graph_3=g_keep (graph_1,graph_2);

	s_put_a (a_offset_2,graph_3);
}

void code_lnR (VOID)
{
#ifdef M68000
	if (mc68881_flag){
		code_monadic_real_operator (GFLN);
		return;
	}
#endif
	if (ln_real==NULL)
		ln_real=enter_label ("ln_real",IMPORT_LABEL);
	code_monadic_sane_operator (ln_real);
	init_b_stack (SIZE_OF_REAL_IN_STACK_ELEMENTS,r_vector);
}

void code_load_module_name (void)
{
	INSTRUCTION_GRAPH graph_1,graph_2;

	graph_1=s_pop_b ();

#ifdef G_A64
	graph_2=g_load_sqb_id (0,graph_1);
#else
	graph_2=g_load_id (0,graph_1);
#endif

#if (defined (LINUX) && defined (G_AI64)) || defined (ARM)
#  ifndef MACH_O64
	if (pic_flag)
#  endif
	graph_2 = g_add (graph_1,graph_2);
#endif

	s_push_b (graph_2);
}

void code_log10R (VOID)
{
#ifdef M68000
	if (mc68881_flag){
		code_monadic_real_operator (GFLOG10);
		return;
	}
#endif
	if (log10_real==NULL)
		log10_real=enter_label ("log10_real",IMPORT_LABEL);
	code_monadic_sane_operator (log10_real);
	init_b_stack (SIZE_OF_REAL_IN_STACK_ELEMENTS,r_vector);
}

void code_ltC (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_pop_b();
	graph_2=s_get_b (0);
	graph_3=g_cmp_lt (graph_2,graph_1);
	
	s_put_b (0,graph_3);
}

void code_ltI (VOID)
{	
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_pop_b();
	graph_2=s_get_b (0);
	graph_3=g_cmp_lt (graph_2,graph_1);
	
	s_put_b (0,graph_3);
}

void code_ltR (VOID)
{
#ifdef G_A64
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5;
	
	graph_1=s_pop_b();
	graph_2=g_fp_arg (graph_1);

	graph_3=s_pop_b();
	graph_4=g_fp_arg (graph_3);

	graph_5=g_fcmp_lt (graph_4,graph_2);

	s_push_b (graph_5);
#else
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6,graph_7;
	
# ifdef M68000
	if (!mc68881_flag){
		if (lt_real==NULL)
			lt_real=enter_label ("lt_real",IMPORT_LABEL);
		code_dyadic_sane_operator (lt_real);
		init_b_stack (1,i_vector);
	} else {
# endif
		graph_1=s_pop_b();
		graph_2=s_pop_b();
		graph_3=g_fjoin (graph_1,graph_2);
	
		graph_4=s_pop_b();
		graph_5=s_pop_b();
		graph_6=g_fjoin (graph_4,graph_5);
	
		graph_7=g_fcmp_lt (graph_6,graph_3);
	
		s_push_b (graph_7);
# ifdef M68000
	}
# endif
#endif
}

#if defined (I486) || defined (ARM)
void code_ltU (VOID)
{	
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_pop_b();
	graph_2=s_get_b (0);
	graph_3=g_cmp_ltu (graph_2,graph_1);
	
	s_put_b (0,graph_3);
}

void code_modI (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;

	graph_1=s_pop_b();
	graph_2=s_get_b (0);

	if (graph_2->instruction_code==GLOAD_I){
		int n;

		n=graph_2->instruction_parameters[0].i;
		if (n>0){
			int n2;
			
			n2=n & (n-1);
			if (n2==0)
				graph_3=g_and (g_load_i (n-1),graph_1);
			else {
				INSTRUCTION_GRAPH graph_4;
				
				graph_4=g_floordiv (g_load_i (n),graph_1);

				if ((n2 & (n2-1))==0){
					int bit_1,bit_2;

					bit_1=0;
					while ((n & 1)==0){
						++bit_1;
						n=n>>1;
					}
					n=n>>1;
					bit_2=1;
					while ((n & 1)==0){
						++bit_2;
						n=n>>1;
					}
					
					if (bit_1>0)
						graph_4=g_lsl (g_load_i (bit_1),graph_4);
					graph_3=g_sub (graph_4,graph_1);
					graph_4=g_lsl (g_load_i (bit_2),graph_4);
					graph_3=g_sub (graph_4,graph_3);
				} else
					graph_3=g_sub (g_mul (graph_2,graph_4),graph_1);
			}
			s_put_b (0,graph_3);
			return;
		} else if (n<0){
			int n2;

			n2=(-n) & ((-n)-1);
			if (n2==0)
				graph_3=g_neg (g_and (g_load_i ((-n)-1),g_neg (graph_1)));
			else {
				INSTRUCTION_GRAPH graph_4;

				graph_4=g_floordiv (g_load_i (n),graph_1);
				
				n = -n;
				
				if ((n2 & (n2-1))==0){
					int bit_1,bit_2;

					bit_1=0;
					while ((n & 1)==0){
						++bit_1;
						n=n>>1;
					}
					n=n>>1;
					bit_2=1;
					while ((n & 1)==0){
						++bit_2;
						n=n>>1;
					}
					
					if (bit_1>0)
						graph_4=g_lsl (g_load_i (bit_1),graph_4);
					graph_3=g_add (graph_4,graph_1);
					graph_4=g_lsl (g_load_i (bit_2),graph_4);
					graph_3=g_add (graph_4,graph_3);					
				} else
					graph_3=g_add (g_mul (g_load_i (n),graph_4),graph_1);
			}
			s_put_b (0,graph_3);
			return;
		}
	}

	graph_3=g_mod (graph_2,graph_1);
	s_put_b (0,graph_3);
}
#endif

void code_remI (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;

	graph_2=s_get_b (1);

#ifdef M68000
	if (!mc68000_flag){
#endif
#if defined (ARM) && !defined (G_A64)
	if (graph_2->instruction_code==GLOAD_I && graph_2->instruction_parameters[0].i!=0){
#endif
		graph_1=s_pop_b();
#if defined (ARM) && !defined (G_A64)
		graph_2=g_load_i (graph_2->instruction_parameters[0].i);
#endif
		graph_3=g_rem (graph_2,graph_1);
		s_put_b (0,graph_3);
#if defined (ARM) && !defined (G_A64)
		return;
	}
#endif
#ifdef sparc
		if (dot_rem_label==NULL)
			dot_rem_label=enter_label (".rem",IMPORT_LABEL);
#endif
#ifdef M68000
	} else
#endif
#if defined (M68000) || (defined (ARM) && !defined (G_A64))
	{
		if (mod_label==NULL)
			mod_label=enter_label ("modulo",IMPORT_LABEL);

		s_push_b (s_get_b (0));
		s_put_b (1,graph_2);
		s_put_b (2,NULL);

		insert_basic_block (JSR_BLOCK,0,2+1,i_i_vector,mod_label);

		init_b_stack (1,i_vector);
	}
#endif
}

#if defined (I486) || defined (ARM)
void code_remU (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;

	graph_1=s_pop_b();
	graph_2=s_get_b (0);
	graph_3=g_remu (graph_2,graph_1);
	s_put_b (0,graph_3);
}
#endif

static INSTRUCTION_GRAPH multiply_by_constant (unsigned int n,INSTRUCTION_GRAPH graph_1)
{
	INSTRUCTION_GRAPH graph_2;
	int n_shifts;
	
	if (n==0)
		return g_load_i (0);
	
	n_shifts=0;
	while ((n & 1)==0){
		n>>=1;
		++n_shifts;
	}
	
	graph_2=graph_1;
	
	while (n>1){
		int n_shifts2;
		
		n>>=1;

		n_shifts2=1;
		while ((n & 1)==0){
			n>>=1;
			++n_shifts2;
		}

		graph_2=g_lsl (g_load_i (n_shifts2),graph_2);
		graph_1=g_add (graph_2,graph_1);
	}

	if (n_shifts>0)
		graph_1=g_lsl (g_load_i (n_shifts),graph_1);

	return graph_1;	
}

void code_mulI (VOID)
{
#ifdef M68000
	if (!mc68000_flag){
#endif
		INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
		graph_1=s_pop_b();
		graph_2=s_get_b (0);

# ifdef REPLACE_MUL_BY_SHIFT
		if (graph_1->instruction_code==GLOAD_I){
			unsigned int n,n2;

			n=graph_1->instruction_parameters[0].i;
			n2=n & (n-1);
			if (n2==0 || (n2 & (n2-1))==0){
				graph_3=multiply_by_constant (n,graph_2);
				s_put_b (0,graph_3);
				return;
			}
		}
		if (graph_2->instruction_code==GLOAD_I){
			unsigned int n,n2;

			n=graph_2->instruction_parameters[0].i;
			n2=n & (n-1);
			if (n2==0 || (n2 & (n2-1))==0){
				graph_3=multiply_by_constant (n,graph_1);
				s_put_b (0,graph_3);
				return;
			}
		}
# endif

		graph_3=g_mul (graph_1,graph_2);
		s_put_b (0,graph_3);
#ifdef sparc
		if (dot_mul_label==NULL)
			dot_mul_label=enter_label (".mul",IMPORT_LABEL);
#endif
#ifdef M68000
	} else {
		if (mul_label==NULL)
			mul_label=enter_label ("multiply",IMPORT_LABEL);
	
		s_push_b (s_get_b (0));
		s_put_b (1,s_get_b (2));
		s_put_b (2,NULL);

		insert_basic_block (JSR_BLOCK,0,2+1,i_i_vector,mul_label);

		init_b_stack (1,i_vector);
	}
#endif
}

#if defined (I486) || defined (ARM) || defined (G_POWER)
void code_mulUUL (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
# if !(defined (G_POWER) || (defined (ARM) && defined (G_A64)))
	INSTRUCTION_GRAPH graph_5;
# endif
	
	graph_1=s_get_b (0);
	graph_2=s_get_b (1);

# if defined (G_POWER) || (defined (ARM) && defined (G_A64))
	graph_3=g_mul (graph_1,graph_2);
	graph_4=g_umulh (graph_1,graph_2);
# else
	graph_5=g_instruction_2 (GMULUD,graph_1,graph_2);
	graph_3=g_instruction_2 (GRESULT1,graph_5,NULL);
	graph_4=g_instruction_2 (GRESULT0,graph_5,NULL);
	graph_3->instruction_parameters[1].p=graph_4;
	graph_4->instruction_parameters[1].p=graph_3;
#endif
	s_put_b (1,graph_3);
	s_put_b (0,graph_4);
}
#endif

#ifndef M68000
void code_mulIo (VOID)
{
	code_operatorIo (GMUL_O);
}
#endif

void code_mulR (VOID)
{
#ifdef G_A64
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6;
	
	graph_1=s_pop_b();
	graph_2=g_fp_arg (graph_1);

	graph_3=s_get_b (0);
	graph_4=g_fp_arg (graph_3);

	graph_5=g_fmul (graph_4,graph_2);

	graph_6=g_fromf (graph_5);

	s_put_b (0,graph_6);
#else
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6,graph_7,graph_8,graph_9;
	
# ifdef M68000
	if (!mc68881_flag){
		if (mul_real==NULL)
			mul_real=enter_label ("mul_real",IMPORT_LABEL);
		code_dyadic_sane_operator (mul_real);
		init_b_stack (2,r_vector);
	} else {
# endif
		graph_1=s_pop_b();
		graph_2=s_pop_b();
		graph_3=g_fjoin (graph_1,graph_2);
	
		graph_4=s_get_b (0);
		graph_5=s_get_b (1);
		graph_6=g_fjoin (graph_4,graph_5);
	
		graph_7=g_fmul (graph_6,graph_3);

		g_fhighlow (graph_8,graph_9,graph_7);

		s_put_b (0,graph_8);
		s_put_b (1,graph_9);
# ifdef M68000
	}
# endif
#endif
}

void code_a (int n_apply_args,char *ea_label_name)
{
	LABEL *label;
	char add_empty_node_label_name[32];

	last_block->block_n_node_arguments=-200+n_apply_args;
	last_block->block_ea_label=enter_label (ea_label_name,0);
	
	if (n_apply_args>0 && add_empty_node_labels[n_apply_args]==NULL){
		sprintf (add_empty_node_label_name,"add_empty_node_%d",n_apply_args);
		add_empty_node_labels[n_apply_args]=enter_label (add_empty_node_label_name,IMPORT_LABEL);
	}
}

void code_ai (int n_apply_args,char *ea_label_name,char *instance_member_code_name)
{
	LABEL *label;
	char add_empty_node_label_name[32];

	last_block->block_n_node_arguments=-300+n_apply_args;
	if (ea_label_name[0]=='_' && ea_label_name[1]=='_' && ea_label_name[2]=='\0')
		last_block->block_ea_label=NULL;
	else
		last_block->block_ea_label=enter_label (ea_label_name,0);
	last_block->block_descriptor=enter_label (instance_member_code_name,0);
#if 0
	/* not yet implemented, do the same as code_a, ignore if no ea_label */
	if (ea_label_name[0]=='_' && ea_label_name[1]=='_' && ea_label_name[2]=='\0')
		return;

	last_block->block_n_node_arguments=-200+n_apply_args;
	last_block->block_ea_label=enter_label (ea_label_name,0);
#endif
	
	if (n_apply_args>0 && add_empty_node_labels[n_apply_args]==NULL){
		sprintf (add_empty_node_label_name,"add_empty_node_%d",n_apply_args);
		add_empty_node_labels[n_apply_args]=enter_label (add_empty_node_label_name,IMPORT_LABEL);
	}
}

void code_n (int number_of_arguments,char *descriptor_name,char *ea_label_name)
{
	LABEL *label;
	
	if (descriptor_name[0]=='_' && descriptor_name[1]=='_' && descriptor_name[2]=='\0')
		label=NULL;
	else
		label=enter_label (descriptor_name,DATA_LABEL);

	last_block->block_n_node_arguments=number_of_arguments;
	last_block->block_descriptor=label;

	if (ea_label_name!=NULL){
		if (ea_label_name[0]=='_' && ea_label_name[1]=='_' && ea_label_name[2]=='\0'){
			if (eval_fill_label==NULL)
				eval_fill_label=enter_label ("eval_fill",
#if defined (G_AI64) && defined (LINUX)
												rts_got_flag ? (IMPORT_LABEL | USE_GOT_LABEL) :
#endif
												IMPORT_LABEL);
			last_block->block_ea_label=eval_fill_label;
		} else {
			if (number_of_arguments<-2)
				number_of_arguments=1;

			if (number_of_arguments>=0 && eval_upd_labels[number_of_arguments]==NULL){
				define_eval_upd_label_n (number_of_arguments);
			}
			last_block->block_ea_label=enter_label (ea_label_name,0);
		}
	} else
		last_block->block_ea_label=NULL;
}

void code_nu (int a_size,int b_size,char *descriptor_name,char *ea_label_name)
{
	LABEL *label;
	
	if (descriptor_name[0]=='_' && descriptor_name[1]=='_' && descriptor_name[2]=='\0')
		label=NULL;
	else
		label=enter_label (descriptor_name,DATA_LABEL);

	last_block->block_n_node_arguments=a_size+b_size+(b_size<<8);
	last_block->block_descriptor=label;

	if (ea_label_name!=NULL){
		/* eval_upd not yet implemented */
		if (eval_fill_label==NULL)
			eval_fill_label=enter_label ("eval_fill",
#if defined (G_AI64) && defined (LINUX)
											rts_got_flag ? (IMPORT_LABEL | USE_GOT_LABEL) :
#endif
											IMPORT_LABEL);
		last_block->block_ea_label=eval_fill_label;
	} else
		last_block->block_ea_label=NULL;
}

void code_negI (void)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	graph_1=s_get_b (0);
	graph_2=g_neg (graph_1);
	
	s_put_b (0,graph_2);
}

void code_negR (void)
{
#ifdef M68000
	if (!mc68881_flag){
		if (neg_real==NULL)
			neg_real=enter_label ("neg_real",IMPORT_LABEL);
		code_monadic_sane_operator (neg_real);
		init_b_stack (SIZE_OF_REAL_IN_STACK_ELEMENTS,r_vector);
	} else
#endif
	code_monadic_real_operator (GFNEG);
}

void code_no_op (VOID)
{
}

void code_notB (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	graph_1=s_get_b (0);
	graph_2=g_cnot (graph_1);
	
	s_put_b (0,graph_2);
}

void code_not (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_get_b (0);
#if defined (I486) || defined (ARM) || defined (G_POWER)
	graph_3=g_not (graph_1);
#else
	graph_2=g_load_i (-1);
	graph_3=g_eor (graph_2,graph_1);
#endif
	s_put_b (0,graph_3);
}

void code_orB (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_pop_b();
	graph_2=s_get_b (0);
	graph_3=g_or (graph_1,graph_2);
	
	s_put_b (0,graph_3);
}

void code_or (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_pop_b();
	graph_2=s_get_b (0);
	graph_3=g_or (graph_1,graph_2);
	
	s_put_b (0,graph_3);
}

void code_pop_a (int n)
{
	while (n>0){
		s_remove_a();
		--n;
	}
}

void code_pop_b (int n)
{
	while (n>0){
		s_remove_b();
		--n;
	}
}

void code_powR (VOID)
{
	if (pow_real==NULL)
		pow_real=enter_label ("pow_real",IMPORT_LABEL);

	code_dyadic_sane_operator (pow_real);
	init_b_stack (SIZE_OF_REAL_IN_STACK_ELEMENTS,r_vector);
}

void code_print (char *string,int length)
{
	LABEL *string_label;
	INSTRUCTION_GRAPH graph_1;
	
	if (print_label==NULL)
#ifdef G_POWER
		print_label=enter_label ("print_",IMPORT_LABEL);
#else
		print_label=enter_label ("print",
# if defined (G_AI64) && defined (LINUX)
								rts_got_flag ? (USE_GOT_LABEL | IMPORT_LABEL) :
# endif
								IMPORT_LABEL);
#endif

	string_label=w_code_string (string,length);

	graph_1=g_lea (string_label);
	
	s_push_b (NULL);
	s_push_b (graph_1);

	insert_basic_block (JSR_BLOCK,0,1+1,i_i_vector,print_label);
}

void code_print_char (VOID)
{
	INSTRUCTION_GRAPH graph_1;
	
	if (print_char_label==NULL)
		print_char_label=enter_label ("print_char",IMPORT_LABEL);

	graph_1=s_pop_b();
	
	s_push_b (NULL);
	s_push_b (graph_1);

	insert_basic_block (JSR_BLOCK,0,1+1,i_i_vector,print_char_label);
}

void code_print_int (VOID)
{
	INSTRUCTION_GRAPH graph_1;
	
	if (print_int_label==NULL)
		print_int_label=enter_label ("print_int",IMPORT_LABEL);

	graph_1=s_pop_b();
	
	s_push_b (NULL);
	s_push_b (graph_1);

	insert_basic_block (JSR_BLOCK,0,1+1,i_i_vector,print_int_label);
}

void code_print_real (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	if (print_real_label==NULL)
		print_real_label=enter_label ("print_real",IMPORT_LABEL);

	graph_1=s_pop_b();
#ifdef G_A64
	s_push_b (NULL);
	s_push_b (graph_1);

	insert_basic_block (JSR_BLOCK,0,1+1,r_vector,print_real_label);
#else
	graph_2=s_pop_b();
	
	s_push_b (NULL);
	s_push_b (graph_2);
	s_push_b (graph_1);

	insert_basic_block (JSR_BLOCK,0,2+1,r_vector,print_real_label);
#endif
}

void code_print_sc (char *string,int length)
{
	LABEL *string_label;
	INSTRUCTION_GRAPH graph_1;
	
	if (print_sc_label==NULL)
		print_sc_label=enter_label ("print_sc",IMPORT_LABEL);
	
	string_label=w_code_string (string,length);

	graph_1=g_lea (string_label);
	
	s_push_b (NULL);
	s_push_b (graph_1);

	insert_basic_block (JSR_BLOCK,0,1+1,i_i_vector,print_sc_label);
}

void code_print_symbol (int a_offset)
{
	INSTRUCTION_GRAPH graph_1;

	if (print_symbol_label==NULL)
		print_symbol_label=enter_label ("print_symbol",IMPORT_LABEL);

	graph_1=s_get_a (a_offset);
	
	s_push_a (graph_1);

	s_push_b (NULL);
	insert_basic_block (JSR_BLOCK,1,0+1,e_vector,print_symbol_label);
}

void code_print_symbol_sc (int a_offset)
{
	INSTRUCTION_GRAPH graph_1;
	
	if (print_symbol_sc_label==NULL)
		print_symbol_sc_label=enter_label ("print_symbol_sc",IMPORT_LABEL);
	
	graph_1=s_get_a (a_offset);
	
	s_push_a (graph_1);

	s_push_b (NULL);
	insert_basic_block (JSR_BLOCK,1,0+1,e_vector,print_symbol_sc_label);
}

void code_printD (VOID)
{
	if (printD_label==NULL)
		printD_label=enter_label ("printD",IMPORT_LABEL);

	s_push_b (s_get_b (0));
	s_put_b (1,NULL);
	
	insert_basic_block (JSR_BLOCK,0,1+1,i_i_vector,printD_label);
}

#if 0
void code_print_r_arg (int a_offset)
{
	if (print_r_arg_label==NULL)
		print_r_arg_label=enter_label ("print_r_arg",IMPORT_LABEL);

	s_push_b (s_get_b (0));
	s_put_b (1,NULL);

	if (a_offset!=0)
		s_push_a (s_get_a (a_offset));

	insert_basic_block (JSR_BLOCK,1,1+1,i_i_vector,print_r_arg_label);
	
	init_a_stack (1);	
	init_b_stack (2,i_i_vector);
	
	if (a_offset!=0)
		s_put_a (a_offset,s_pop_a());
}
#endif

void code_pushcaf (char *label_name,int a_stack_size,int b_stack_size)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	LABEL *label;
	int n_arguments;
		
	label=enter_label (label_name,0);

	graph_1=g_lea (label);

	n_arguments=a_stack_size+b_stack_size;

#if! (defined (I486) || defined (ARM))
	if (n_arguments>2 && n_arguments<8){
		INSTRUCTION_GRAPH graph_2;
		
		graph_2=g_movem (4,graph_1,n_arguments);
		
		while (b_stack_size>0){
			--n_arguments;
			s_push_b (g_movemi (n_arguments,graph_2));
			--b_stack_size;
		}
	
		while (a_stack_size>0){
			--n_arguments;
			s_push_a (g_movemi (n_arguments,graph_2));
			--a_stack_size;
		}		
	} else
#endif
	{
		int offset;
		
		offset=n_arguments<<STACK_ELEMENT_LOG_SIZE;

		while (b_stack_size>0){
			s_push_b (g_load_id (offset,graph_1));
			offset-=STACK_ELEMENT_SIZE;
			--b_stack_size;
		}
	
		while (a_stack_size>0){
			s_push_a (g_load_id (offset,graph_1));
			offset-=STACK_ELEMENT_SIZE;
			--a_stack_size;
		}
	}
}

void code_pushA_a (int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	graph_1=s_get_a (a_offset);
	graph_2=g_load_id (STACK_ELEMENT_SIZE,graph_1);
	
	s_push_a (graph_2);
}

void code_pushB (int b)
{
	INSTRUCTION_GRAPH graph_1;

#if defined (I486) || defined (ARM)
	graph_1=g_load_i (b);
#else
	graph_1=g_load_i (-b);
#endif
	s_push_b (graph_1);
}

void code_pushB_a (int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	graph_1=s_get_a (a_offset);
	graph_2=g_load_id (ARGUMENTS_OFFSET-NODE_POINTER_OFFSET,graph_1);
	
	s_push_b (graph_2);
}

void code_pushC (int c)
{
	INSTRUCTION_GRAPH graph_1;
	
	graph_1=g_load_i (c);
	s_push_b (graph_1);
}

void code_pushC_a (int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	graph_1=s_get_a (a_offset);
	graph_2=g_load_id (ARGUMENTS_OFFSET-NODE_POINTER_OFFSET,graph_1);
	
	s_push_b (graph_2);
}

void code_pushD (char *descriptor)
{
	INSTRUCTION_GRAPH graph_1;
	LABEL *descriptor_label;
	
	descriptor_label=enter_label (descriptor,0);

#ifdef G_POWER
	if ((descriptor_label->label_flags & (STRING_LABEL | DATA_LABEL))==DATA_LABEL){
#else
	if (descriptor_label->label_flags & DATA_LABEL){
#endif
	
		/* graph_1=g_load_des_i (descriptor_label,0); */
		graph_1=g_lea (descriptor_label->label_descriptor);
	} else
		graph_1=g_lea (descriptor_label);

#ifndef M68000
	--graph_1->instruction_d_min_a_cost;
#endif

	s_push_b (graph_1);
}

void code_pushD_a (int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	graph_1=s_get_a (a_offset);
	graph_2=g_load_id (0,graph_1);
	
	s_push_b (graph_2);
}

void code_pushF_a (int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	
	graph_1=s_get_a (a_offset);

	graph_2=g_movem (ARGUMENTS_OFFSET-NODE_POINTER_OFFSET,graph_1,2);
	graph_3=g_movemi (0,graph_2);
	graph_4=g_movemi (1,graph_2);
	
	s_push_b (graph_3);
	s_push_b (graph_4);
}

void code_pushI (CleanInt i)
{
	INSTRUCTION_GRAPH graph_1;
	
	graph_1=g_load_i (i);
	s_push_b (graph_1);
}

void code_pushI_a (int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	graph_1=s_get_a (a_offset);
	graph_2=g_load_id (ARGUMENTS_OFFSET-NODE_POINTER_OFFSET,graph_1);
	
	s_push_b (graph_2);
}

void code_pushL (char *label_name)
{
	INSTRUCTION_GRAPH graph_1;
	LABEL *label;
	
	label=enter_label (label_name,0);

	graph_1=g_lea (label);

#ifndef M68000
	--graph_1->instruction_d_min_a_cost;
#endif

	s_push_b (graph_1);
}

void code_pushLc (char *c_function_name)
{
	INSTRUCTION_GRAPH graph_1;
	LABEL *label;

#if (defined (sparc) && !defined (SOLARIS)) || (defined (I486) && !defined (G_AI64) && !defined (LINUX_ELF)) || (defined (G_POWER) && !defined (LINUX_ELF)) || defined (MACH_O) || defined (MACH_O64)
	char label_name [202];
	
# if defined (G_POWER) && !defined (MACH_O)
	label_name[0]='.';
# else
	label_name[0]='_';
# endif
	strcpy (&label_name[1],c_function_name);

	label=enter_label (label_name,0);
#else
	label=enter_label (c_function_name,0);
#endif

	graph_1=g_lea (label);

#ifndef M68000
	--graph_1->instruction_d_min_a_cost;
#endif

	s_push_b (graph_1);
}

void code_pushR (double v)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	if (!mc68881_flag){
		DOUBLE r=v;
		
		graph_2=g_load_i (((long*)&r)[0]);
		graph_3=g_load_i (((long*)&r)[1]);
	} else {
		graph_1=g_fload_i (v);

#ifdef G_A64
		graph_2=g_fromf (graph_1);
#else
		g_fhighlow (graph_2,graph_3,graph_1);
#endif
	}
	
#ifndef G_A64
	s_push_b (graph_3);
#endif
	s_push_b (graph_2);
}

void code_pushR_a (int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	
	graph_1=s_get_a (a_offset);
	
	if (!mc68881_flag){
		graph_3=g_load_id (ARGUMENTS_OFFSET-NODE_POINTER_OFFSET,graph_1);
		graph_4=g_load_id (ARGUMENTS_OFFSET-NODE_POINTER_OFFSET+4,graph_1);
	} else {
		graph_2=g_fload_id (ARGUMENTS_OFFSET-NODE_POINTER_OFFSET,graph_1);
#ifdef G_A64
		graph_3=g_fromf (graph_2);
#else
		g_fhighlow (graph_3,graph_4,graph_2);
#endif
	}
	
#ifndef G_A64
	s_push_b (graph_4);
#endif
	s_push_b (graph_3);
}

void code_pushzs (char *string,int length)
{
	INSTRUCTION_GRAPH graph_1;
	LABEL *string_label;

	string_label=w_code_string (string,length);

	graph_1=g_lea (string_label);
	
	s_push_b (graph_1);
}

void code_push_a (int a_offset)
{
	INSTRUCTION_GRAPH graph_1;
	
	graph_1=s_get_a (a_offset);
	s_push_a (graph_1);
}

void code_push_b (int b_offset)
{
	INSTRUCTION_GRAPH graph_1;
	
	graph_1=s_get_b (b_offset);
	s_push_b (graph_1);
}

void code_push_a_b (int a_offset)
{
	INSTRUCTION_GRAPH graph_1;
	
	graph_1=s_get_a (a_offset);
	s_push_b (graph_1);
}

void code_push_a_r_args (VOID)
{
	if (push_a_r_args_label==NULL)
		push_a_r_args_label=enter_label ("push_a_r_args",IMPORT_LABEL);

	s_push_b (s_get_b (0));
	s_put_b (1,NULL);
	insert_basic_block (JSR_BLOCK,1,1+1,i_vector,push_a_r_args_label);
	
	init_b_stack (1,i_vector);	
}

void code_push_t_r_a (int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_get_a (a_offset);
#if defined (sparc) || defined (I486) || defined (ARM) || defined (G_POWER)
	graph_2=g_load_id (0,graph_1);
	graph_3=g_add (g_load_i (2),graph_2);
#else
	graph_2=g_load_des_id (DESCRIPTOR_OFFSET,graph_1);
	graph_3=g_add (g_load_i (4),g_add (g_g_register (GLOBAL_DATA_REGISTER),graph_2));
#endif
	
	s_push_b (graph_3);
}

void code_push_t_r_args (VOID)
{
	if (push_t_r_args_label==NULL)
		push_t_r_args_label=enter_label ("push_t_r_args",IMPORT_LABEL);

	s_push_b (NULL);
	insert_basic_block (JSR_BLOCK,1,0+1,e_vector,push_t_r_args_label);

	init_b_stack (1,i_vector);	
}

void code_push_arg (int a_offset,int arity,int argument_number)
{	
	INSTRUCTION_GRAPH graph_1,graph_2;

	graph_1=s_get_a (a_offset);
	if (argument_number<2 || (argument_number==2 && arity==2))
		graph_2=g_load_id (argument_number<<STACK_ELEMENT_LOG_SIZE,graph_1);
	else {
		INSTRUCTION_GRAPH graph_3;
		
		graph_3=g_load_id (2*STACK_ELEMENT_SIZE,graph_1);
		graph_2=g_load_id ((argument_number-2)<<STACK_ELEMENT_LOG_SIZE,graph_3);
	}
	
	s_push_a (graph_2);
}

void code_push_arg_b (int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	graph_2=s_get_b (0);
	
	if (graph_2->instruction_code==GLOAD_I && graph_2->instruction_parameters[0].i!=2){
		int argument_number;
		
		argument_number=graph_2->instruction_parameters[0].i;
		s_remove_b();
		s_remove_b();
		code_push_arg (a_offset,argument_number,argument_number);
	} else {	
		if (push_arg_b_label==NULL)
			push_arg_b_label=enter_label ("push_arg_b",IMPORT_LABEL);

		graph_1=s_get_a (a_offset);
		s_push_a (graph_1);

		s_push_b (s_get_b (0));
		s_put_b (1,s_get_b (2));
		s_put_b (2,NULL);
		insert_basic_block (JSR_BLOCK,1,2+1,i_i_vector,push_arg_b_label);

		init_a_stack (1);
	}
}

void code_push_args (int a_offset,int arity,int n_arguments)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	if (n_arguments==0)
		return;
		
	graph_1=s_get_a (a_offset);
	graph_2=g_load_id (ARGUMENTS_OFFSET-NODE_POINTER_OFFSET,graph_1);

	if (n_arguments!=1)
		if (n_arguments==2 && arity==2){
			graph_3=g_load_id (2*STACK_ELEMENT_SIZE-NODE_POINTER_OFFSET,graph_1);
			s_push_a (graph_3);
		} else {
			INSTRUCTION_GRAPH graph_4;
			
			graph_3=g_load_id (2*STACK_ELEMENT_SIZE-NODE_POINTER_OFFSET,graph_1);
			--n_arguments;
			
			if (n_arguments==1){
				graph_4=g_load_id (0-NODE_POINTER_OFFSET,graph_3);
				s_push_a (graph_4);
			} else {
#if ! (defined (I486) || defined (ARM))
				if (n_arguments>=8){
#endif
					while (n_arguments!=0){
						INSTRUCTION_GRAPH graph_5;
					
						--n_arguments;
	
						graph_5=g_load_id ((n_arguments<<STACK_ELEMENT_LOG_SIZE)-NODE_POINTER_OFFSET,graph_3);
	
						s_push_a (graph_5);
					}
#if ! (defined (I486) || defined (ARM))
				} else {
					graph_4=g_movem (0-NODE_POINTER_OFFSET,graph_3,n_arguments);
					while (n_arguments!=0){
						INSTRUCTION_GRAPH graph_5;
					
						--n_arguments;
	
						graph_5=g_movemi (n_arguments,graph_4);
						s_push_a (graph_5);
					}
				}
#endif
			}
		}
	
	s_push_a (graph_2);
}

void code_push_arraysize (char element_descriptor[],int a_size,int b_size)
{
	INSTRUCTION_GRAPH graph_1,graph_2;

	graph_1=s_pop_a();
#ifdef ARRAY_SIZE_BEFORE_DESCRIPTOR
	graph_2=g_load_id (-STACK_ELEMENT_SIZE,graph_1);
#else
	graph_2=g_load_id (STACK_ELEMENT_SIZE,graph_1);
#endif
	s_push_b (graph_2);
}

void code_push_b_a (int a_offset)
{
	INSTRUCTION_GRAPH graph_1;
	
	graph_1=s_get_b (a_offset);
	s_push_a (graph_1);
}

#ifdef FINALIZERS
void code_push_finalizers (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	LABEL *finalizer_list_label;

	finalizer_list_label=enter_label ("finalizer_list",DATA_LABEL | IMPORT_LABEL);

	graph_1=g_lea (finalizer_list_label);
	graph_2=g_load_id (0,graph_1);

	s_push_a (graph_2);
}
#endif

static void push_record_arguments (INSTRUCTION_GRAPH graph_1,int a_size,int b_size)
{
	INSTRUCTION_GRAPH graph_2,graph_3,graph_4,graph_5;

	switch (a_size+b_size){
		case 0:
			return;
		case 1:
			graph_2=g_load_id (ARGUMENTS_OFFSET-NODE_POINTER_OFFSET,graph_1);
			if (a_size!=0)
				s_push_a (graph_2);
			else
				s_push_b (graph_2);
			return;
		case 2:
			graph_2=g_load_id (ARGUMENTS_OFFSET-NODE_POINTER_OFFSET,graph_1);
			graph_3=g_load_id (2*STACK_ELEMENT_SIZE-NODE_POINTER_OFFSET,graph_1);
			switch (b_size){
				case 0:
					s_push_a (graph_3);
					s_push_a (graph_2);
					break;
				case 1:
					s_push_a (graph_2);
					s_push_b (graph_3);
					break;
				default:
					s_push_b (graph_3);
					s_push_b (graph_2);		
			}			
			return;
		default:
			graph_2=g_load_id (ARGUMENTS_OFFSET-NODE_POINTER_OFFSET,graph_1);
			graph_3=g_load_id (2*STACK_ELEMENT_SIZE-NODE_POINTER_OFFSET,graph_1);

#ifdef M68000
			if (a_size+b_size-1>=8){
#endif
				b_size+=a_size;
	
				while (b_size>a_size && b_size>1){
					--b_size;			
					graph_5=g_load_id (((b_size-1)<<STACK_ELEMENT_LOG_SIZE)-NODE_POINTER_OFFSET,graph_3);
					s_push_b (graph_5);
				}
	
				while (a_size>1){
					--a_size;
					graph_5=g_load_id (((a_size-1)<<STACK_ELEMENT_LOG_SIZE)-NODE_POINTER_OFFSET,graph_3);
					s_push_a (graph_5);
				}				
#ifdef M68000
			} else {
				graph_4=g_movem (0-NODE_POINTER_OFFSET,graph_3,a_size+b_size-1);
	
				b_size+=a_size;
	
				while (b_size>a_size && b_size>1){
					--b_size;			
					graph_5=g_movemi (b_size-1,graph_4);
					s_push_b (graph_5);
				}
	
				while (a_size>1){
					--a_size;			
					graph_5=g_movemi (a_size-1,graph_4);
					s_push_a (graph_5);
				}
			}
#endif
			if (a_size>0)
				s_push_a (graph_2);
			else
				s_push_b (graph_2);
			return;
	}
}

void code_push_r_args (int a_offset,int a_size,int b_size)
{
	INSTRUCTION_GRAPH graph_1;

	graph_1=s_get_a (a_offset);

	push_record_arguments (graph_1,a_size,b_size);
}

void code_push_r_arg_D (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	graph_1=s_pop_b();
	graph_2=s_get_b (0);
#ifdef MACH_O64
	graph_1=g_and (g_load_i (-8),g_add (g_load_i (8-1),graph_1));
#else
	graph_1=g_and (g_load_i (-4),g_add (g_load_i (4-1),graph_1));
#endif
#if defined (G_AI64)
# if defined (MACH_O64) || defined (LINUX)
#  ifndef MACH_O64
	if (pic_flag)
#  endif
	{
		graph_1=g_add (g_lsl (g_load_i (3),graph_2),graph_1);
		graph_2=g_load_id (0,graph_1);
	}
#  ifndef MACH_O64
	else
#  endif
# endif
# ifndef MACH_O64
	{
		graph_1=g_add (g_lsl (g_load_i (2),graph_2),graph_1);
		graph_2=g_load_sqb_id (0,graph_1);
	}
# endif
#else
	graph_1=g_add (g_lsl (g_load_i (2),graph_2),graph_1);
	graph_2=g_load_id (0,graph_1);
#endif
	s_put_b (0,graph_2);
}

void code_push_r_arg_t (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	graph_1=s_get_b (0);
	graph_2=g_load_b_id (0,graph_1);
	s_put_b (0,graph_2);
}

void code_push_r_args_a (int a_offset,int a_size,int b_size,int argument_number,int n_arguments)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_get_a (a_offset);
	graph_3=NULL;
	
	argument_number+=n_arguments;
	for (; n_arguments>0; --n_arguments){
		--argument_number;
		if (argument_number<2 || (argument_number==2 && a_size+b_size==2))
			graph_2=g_load_id (argument_number<<STACK_ELEMENT_LOG_SIZE,graph_1);
		else {
			if (graph_3==NULL)
				graph_3=g_load_id (2*STACK_ELEMENT_SIZE,graph_1);
			graph_2=g_load_id ((argument_number-2)<<STACK_ELEMENT_LOG_SIZE,graph_3);
		}
		s_push_a (graph_2); 
	}	
}

void code_push_r_args_b (int a_offset,int a_size,int b_size,int argument_number,int n_arguments)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_get_a (a_offset);
	graph_3=NULL;
	
	argument_number+=a_size+n_arguments;
	for (; n_arguments>0; --n_arguments){
		--argument_number;
		if (argument_number<2 || (argument_number==2 && a_size+b_size==2))
			graph_2=g_load_id (argument_number<<STACK_ELEMENT_LOG_SIZE,graph_1);
		else {
			if (graph_3==NULL)
				graph_3=g_load_id (2*STACK_ELEMENT_SIZE,graph_1);
			graph_2=g_load_id ((argument_number-2)<<STACK_ELEMENT_LOG_SIZE,graph_3);
		}
		s_push_b (graph_2);
	}
}

void code_push_node (char *label_name,int n_arguments)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5;

	if (EMPTY_label==NULL)
		EMPTY_label=enter_label ("EMPTY",IMPORT_LABEL | DATA_LABEL);

	if (!strcmp (label_name,"__cycle__in__spine")){
#ifndef RESERVE_CODE_REGISTER
		if (cycle_in_spine_label==NULL){
			cycle_in_spine_label=enter_label ("__cycle__in__spine",IMPORT_LABEL | NODE_ENTRY_LABEL);
			cycle_in_spine_label->label_arity=0;
			cycle_in_spine_label->label_descriptor=EMPTY_label;
		}
		graph_2=g_lea (cycle_in_spine_label);
#else
		graph_2=g_g_register (RESERVE_CODE_REGISTER);
#endif
	} else if (!strcmp (label_name,"__reserve")){
#ifndef RESERVE_CODE_REGISTER
		if (reserve_label==NULL){
			reserve_label=enter_label ("__reserve",IMPORT_LABEL | NODE_ENTRY_LABEL);
			reserve_label->label_arity=0;
			reserve_label->label_descriptor=EMPTY_label;
		}
		graph_2=g_lea (reserve_label);
#else
		graph_2=g_g_register (RESERVE_CODE_REGISTER);
#endif
	} else if (label_name[0]=='_' && label_name[1]=='_' && label_name[2]=='\0')
		graph_2=NULL;
	else {
		LABEL *label;

		label=enter_label (label_name,NODE_ENTRY_LABEL);
		label->label_arity=0;
		label->label_descriptor=EMPTY_label;		
		graph_2=g_lea (label);
	}
	
	graph_1=s_get_a (0);
	
	if (n_arguments!=0){
		if (n_arguments!=1){
			int argument_n;
#if defined (I486) || defined (ARM)
			argument_n=n_arguments;
			while (argument_n!=0){
				graph_5=g_load_id ((argument_n<<STACK_ELEMENT_LOG_SIZE)-NODE_POINTER_OFFSET,graph_1);
				--argument_n;
				s_push_a (graph_5);
			}
#else
			graph_4=g_movem (4-NODE_POINTER_OFFSET,graph_1,n_arguments);
		
			argument_n=n_arguments;
			while (argument_n!=0){
				--argument_n;
				graph_5=g_movemi (argument_n,graph_4);
				s_push_a (graph_5);
			}
#endif
		} else {
			graph_4=g_load_id (STACK_ELEMENT_SIZE-NODE_POINTER_OFFSET,graph_1);
			s_push_a (graph_4);
		}
	}

	if (graph_2==NULL)
		graph_3=graph_1;
	else
		graph_3=g_fill_2 (graph_1,graph_2);
	
	s_put_a (n_arguments,graph_3);
}

void code_push_node_u (char *label_name,int a_size,int b_size)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5;

	if (EMPTY_label==NULL)
		EMPTY_label=enter_label ("EMPTY",IMPORT_LABEL | DATA_LABEL);

	if (!strcmp (label_name,"__cycle__in__spine")){
#ifndef RESERVE_CODE_REGISTER
		if (cycle_in_spine_label==NULL){
			cycle_in_spine_label=enter_label ("__cycle__in__spine",IMPORT_LABEL | NODE_ENTRY_LABEL);
			cycle_in_spine_label->label_arity=0;
			cycle_in_spine_label->label_descriptor=EMPTY_label;
		}
		graph_2=g_lea (cycle_in_spine_label);
#else
		graph_2=g_g_register (RESERVE_CODE_REGISTER);
#endif
	} else if (!strcmp (label_name,"__reserve")){
#ifndef RESERVE_CODE_REGISTER
		if (reserve_label==NULL){
			reserve_label=enter_label ("__reserve",IMPORT_LABEL | NODE_ENTRY_LABEL);
			reserve_label->label_arity=0;
			reserve_label->label_descriptor=EMPTY_label;
		}
		graph_2=g_lea (reserve_label);
#else
		graph_2=g_g_register (RESERVE_CODE_REGISTER);
#endif
	} else if (label_name[0]=='_' && label_name[1]=='_' && label_name[2]=='\0')
		graph_2=NULL;
	else {
		LABEL *label;

		label=enter_label (label_name,NODE_ENTRY_LABEL);
		label->label_arity=0;
		label->label_descriptor=EMPTY_label;		
		graph_2=g_lea (label);
	}
	
	graph_1=s_get_a (0);
	
	if (a_size+b_size!=0){
		if (a_size+b_size!=1){
			int argument_n;
#if defined (I486) || defined (ARM)
			argument_n=a_size+b_size;
			while (argument_n!=0){
				graph_5=g_load_id ((argument_n<<(STACK_ELEMENT_LOG_SIZE))-NODE_POINTER_OFFSET,graph_1);
				--argument_n;
				if (argument_n<a_size)
					s_push_a (graph_5);
				else
					s_push_b (graph_5);
			}
#else
			graph_4=g_movem (STACK_ELEMENT_SIZE-NODE_POINTER_OFFSET,graph_1,a_size+b_size);
		
			argument_n=a_size+b_size;
			while (argument_n!=0){
				--argument_n;
				graph_5=g_movemi (argument_n,graph_4);
				if (argument_n<a_size)
					s_push_a (graph_5);
				else
					s_push_b (graph_5);
			}
#endif
		} else {
			graph_4=g_load_id (STACK_ELEMENT_SIZE-NODE_POINTER_OFFSET,graph_1);
			if (a_size>0)
				s_push_a (graph_4);
			else
				s_push_b (graph_4);
		}
	}
	
	if (graph_2==NULL)
		graph_3=graph_1;
	else
		graph_3=g_fill_2 (graph_1,graph_2);
	
	s_put_a (a_size,graph_3);
}

# if defined(sparc)
#  define MAX_INDIRECT_OFFSET 4095
# else
#  define MAX_INDIRECT_OFFSET 8191
# endif

#ifdef INDEX_CSE
#define INDEX_CSE_CACHE_SIZE 16 /* power of 2 */

static INSTRUCTION_GRAPH lsl_2_add_12_cache_index[INDEX_CSE_CACHE_SIZE];
static INSTRUCTION_GRAPH lsl_2_add_12_cache_offset[INDEX_CSE_CACHE_SIZE];
static int n_lsl_2_add_12_cache;
static struct basic_block *block_in_lsl_2_add_12_cache;

static INSTRUCTION_GRAPH lsl_3_add_12_cache_index[INDEX_CSE_CACHE_SIZE];
static INSTRUCTION_GRAPH lsl_3_add_12_cache_offset[INDEX_CSE_CACHE_SIZE];
static int n_lsl_3_add_12_cache;
static struct basic_block *block_in_lsl_3_add_12_cache;

static INSTRUCTION_GRAPH lsl_2_cache_index[INDEX_CSE_CACHE_SIZE];
static INSTRUCTION_GRAPH lsl_2_cache_offset[INDEX_CSE_CACHE_SIZE];
static int n_lsl_2_cache;
static struct basic_block *block_in_lsl_2_cache;

static INSTRUCTION_GRAPH lsl_3_cache_index[INDEX_CSE_CACHE_SIZE];
static INSTRUCTION_GRAPH lsl_3_cache_offset[INDEX_CSE_CACHE_SIZE];
static int n_lsl_3_cache;
static struct basic_block *block_in_lsl_3_cache;

static INSTRUCTION_GRAPH g_lsl_2 (INSTRUCTION_GRAPH graph_1)
{
	INSTRUCTION_GRAPH graph_2;
	int i;

	if (block_in_lsl_2_cache!=last_block){
		n_lsl_2_cache=0;
		block_in_lsl_2_cache=last_block;
	} else {
		int n;
		
		n=n_lsl_2_cache;
		if (n<=INDEX_CSE_CACHE_SIZE){
			while (--n>=0)
				if (lsl_2_cache_index[n]==graph_1)
					return lsl_2_cache_offset[n];
		} else {
			int e;
			
			e = n & (INDEX_CSE_CACHE_SIZE-1);

			n = e;
			while (--n>=0)
				if (lsl_2_cache_index[n]==graph_1)
					return lsl_2_cache_offset[n];
			
			n = INDEX_CSE_CACHE_SIZE;
			while (--n>=e)
				if (lsl_2_cache_index[n]==graph_1)
					return lsl_2_cache_offset[n];
		}
	}

	graph_2=g_lsl (g_load_i (2),graph_1);
	
	i=n_lsl_2_cache & (INDEX_CSE_CACHE_SIZE-1);
	lsl_2_cache_index[i]=graph_1;
	lsl_2_cache_offset[i]=graph_2;
	++n_lsl_2_cache;
	
	return graph_2;
}

static INSTRUCTION_GRAPH g_lsl_3 (INSTRUCTION_GRAPH graph_1)
{
	INSTRUCTION_GRAPH graph_2;
	int i;

	if (block_in_lsl_3_cache!=last_block){
		n_lsl_3_cache=0;
		block_in_lsl_3_cache=last_block;
	} else {
		int n;
		
		n=n_lsl_3_cache;
		if (n<=INDEX_CSE_CACHE_SIZE){
			while (--n>=0)
				if (lsl_3_cache_index[n]==graph_1)
					return lsl_3_cache_offset[n];
		} else {
			int e;
			
			e = n & (INDEX_CSE_CACHE_SIZE-1);

			n = e;
			while (--n>=0)
				if (lsl_3_cache_index[n]==graph_1)
					return lsl_3_cache_offset[n];
			
			n = INDEX_CSE_CACHE_SIZE;
			while (--n>=e)
				if (lsl_3_cache_index[n]==graph_1)
					return lsl_3_cache_offset[n];
		}
	}

	graph_2=g_lsl (g_load_i (3),graph_1);

	i=n_lsl_3_cache & (INDEX_CSE_CACHE_SIZE-1);
	lsl_3_cache_index[i]=graph_1;
	lsl_3_cache_offset[i]=graph_2;
	++n_lsl_3_cache;
	
	return graph_2;
}
#endif

static INSTRUCTION_GRAPH g_lsl_2_add_12 (INSTRUCTION_GRAPH graph_1)
{
	INSTRUCTION_GRAPH graph_2;
	int i;

#ifdef INDEX_CSE	
	if (block_in_lsl_2_add_12_cache!=last_block){
		n_lsl_2_add_12_cache=0;
		block_in_lsl_2_add_12_cache=last_block;
	} else {
		int n;
		
		n=n_lsl_2_add_12_cache;
		if (n<=INDEX_CSE_CACHE_SIZE){
			while (--n>=0)
				if (lsl_2_add_12_cache_index[n]==graph_1)
					return lsl_2_add_12_cache_offset[n];
		} else {
			int e;
			
			e = n & (INDEX_CSE_CACHE_SIZE-1);

			n = e;
			while (--n>=0)
				if (lsl_2_add_12_cache_index[n]==graph_1)
					return lsl_2_add_12_cache_offset[n];
			
			n = INDEX_CSE_CACHE_SIZE;
			while (--n>=e)
				if (lsl_2_add_12_cache_index[n]==graph_1)
					return lsl_2_add_12_cache_offset[n];
		}
	}
#endif

	if (graph_1->instruction_code==GADD){
		INSTRUCTION_GRAPH graph_1_arg_1,graph_1_arg_2;
		
		graph_1_arg_1=graph_1->instruction_parameters[0].p;
		graph_1_arg_2=graph_1->instruction_parameters[1].p;
		if (graph_1_arg_1->instruction_code==GLOAD_I)
			return g_add (g_load_i (ARRAY_ELEMENTS_OFFSET+(graph_1_arg_1->instruction_parameters[0].i<<2)),g_lsl_2 (graph_1_arg_2));
		if (graph_1_arg_2->instruction_code==GLOAD_I)
			return g_add (g_load_i (ARRAY_ELEMENTS_OFFSET+(graph_1_arg_2->instruction_parameters[0].i<<2)),g_lsl_2 (graph_1_arg_1));
	} else if (graph_1->instruction_code==GSUB){
		INSTRUCTION_GRAPH graph_1_arg_1,graph_1_arg_2;
		
		graph_1_arg_1=graph_1->instruction_parameters[0].p;
		graph_1_arg_2=graph_1->instruction_parameters[1].p;
		if (graph_1_arg_1->instruction_code==GLOAD_I)
			return g_add (g_load_i (ARRAY_ELEMENTS_OFFSET-(graph_1_arg_1->instruction_parameters[0].i<<2)),g_lsl_2 (graph_1_arg_2));
		if (graph_1_arg_2->instruction_code==GLOAD_I)
			return g_sub (g_lsl_2 (graph_1_arg_1),g_load_i (ARRAY_ELEMENTS_OFFSET+(graph_1_arg_2->instruction_parameters[0].i<<2)));
	}
	graph_2=g_add (g_load_i (ARRAY_ELEMENTS_OFFSET),g_lsl_2 (graph_1));
	
#ifdef INDEX_CSE
	i=n_lsl_2_add_12_cache & (INDEX_CSE_CACHE_SIZE-1);
	lsl_2_add_12_cache_index[i]=graph_1;
	lsl_2_add_12_cache_offset[i]=graph_2;
	++n_lsl_2_add_12_cache;
#endif
	
	return graph_2;
}

/* just lsl_3 for sparc if ! ALIGN_REAL_ARRAYS */
static INSTRUCTION_GRAPH g_lsl_3_add_12 (INSTRUCTION_GRAPH graph_1)
{
	INSTRUCTION_GRAPH graph_2;
	int i;

#ifdef INDEX_CSE
	if (block_in_lsl_3_add_12_cache!=last_block){
		n_lsl_3_add_12_cache=0;
		block_in_lsl_3_add_12_cache=last_block;
	} else {
		int n;
		
		n=n_lsl_3_add_12_cache;
		if (n<=INDEX_CSE_CACHE_SIZE){
			while (--n>=0)
				if (lsl_3_add_12_cache_index[n]==graph_1)
					return lsl_3_add_12_cache_offset[n];
		} else {
			int e;
			
			e = n & (INDEX_CSE_CACHE_SIZE-1);

			n = e;
			while (--n>=0)
				if (lsl_3_add_12_cache_index[n]==graph_1)
					return lsl_3_add_12_cache_offset[n];
			
			n = INDEX_CSE_CACHE_SIZE;
			while (--n>=e)
				if (lsl_3_add_12_cache_index[n]==graph_1)
					return lsl_3_add_12_cache_offset[n];
		}
	}
#endif

#if defined (sparc) && !defined (ALIGN_REAL_ARRAYS)
	graph_2=g_lsl (g_load_i (3),graph_1);
#else
	if (graph_1->instruction_code==GADD){
		INSTRUCTION_GRAPH graph_1_arg_1,graph_1_arg_2;
		
		graph_1_arg_1=graph_1->instruction_parameters[0].p;
		graph_1_arg_2=graph_1->instruction_parameters[1].p;
		if (graph_1_arg_1->instruction_code==GLOAD_I)
			return g_add (g_load_i (REAL_ARRAY_ELEMENTS_OFFSET+(graph_1_arg_1->instruction_parameters[0].i<<3)),g_lsl_3 (graph_1_arg_2));
		if (graph_1_arg_2->instruction_code==GLOAD_I)
			return g_add (g_load_i (REAL_ARRAY_ELEMENTS_OFFSET+(graph_1_arg_2->instruction_parameters[0].i<<3)),g_lsl_3 (graph_1_arg_1));
	} else if (graph_1->instruction_code==GSUB){
		INSTRUCTION_GRAPH graph_1_arg_1,graph_1_arg_2;
		
		graph_1_arg_1=graph_1->instruction_parameters[0].p;
		graph_1_arg_2=graph_1->instruction_parameters[1].p;
		if (graph_1_arg_1->instruction_code==GLOAD_I)
			return g_add (g_load_i (REAL_ARRAY_ELEMENTS_OFFSET-(graph_1_arg_1->instruction_parameters[0].i<<3)),g_lsl_3 (graph_1_arg_2));
		if (graph_1_arg_2->instruction_code==GLOAD_I)
			return g_sub (g_lsl_3 (graph_1_arg_1),g_load_i (REAL_ARRAY_ELEMENTS_OFFSET+(graph_1_arg_2->instruction_parameters[0].i<<3)));
	}
	graph_2=g_add (g_load_i (REAL_ARRAY_ELEMENTS_OFFSET),g_lsl_3 (graph_1));
#endif

#ifdef INDEX_CSE
	i=n_lsl_3_add_12_cache & (INDEX_CSE_CACHE_SIZE-1);
	lsl_3_add_12_cache_index[i]=graph_1;
	lsl_3_add_12_cache_offset[i]=graph_2;
	++n_lsl_3_add_12_cache;
#endif
	
	return graph_2;
}

static INSTRUCTION_GRAPH optimize_array_index (int offset,int shift,INSTRUCTION_GRAPH graph_1,int *offset_p)
{
	INSTRUCTION_GRAPH graph_2,graph_3;
	int new_offset;
	
	if (graph_1->instruction_code==GADD){
		graph_2=graph_1->instruction_parameters[0].p;
		graph_3=graph_1->instruction_parameters[1].p;
		
		if (graph_2->instruction_code==GLOAD_I){
			new_offset=offset+(graph_2->instruction_parameters[0].i<<shift);
			if ((unsigned)((new_offset | MAX_INDIRECT_OFFSET)+1)<=(unsigned)(MAX_INDIRECT_OFFSET+1) && !(shift==3 && (unsigned)new_offset>=(unsigned)(MAX_INDIRECT_OFFSET-4))){
				*offset_p=new_offset;
				return graph_3;
			}
		}
		if (graph_3->instruction_code==GLOAD_I){
			new_offset=offset+(graph_3->instruction_parameters[0].i<<shift);
			if ((unsigned)((new_offset | MAX_INDIRECT_OFFSET)+1)<=(unsigned)(MAX_INDIRECT_OFFSET+1) && !(shift==3 && (unsigned)new_offset>=(unsigned)(MAX_INDIRECT_OFFSET-4))){
				*offset_p=new_offset;
				return graph_2;
			}			
		}
	} else if (graph_1->instruction_code==GSUB){
		graph_2=graph_1->instruction_parameters[0].p;
		graph_3=graph_1->instruction_parameters[1].p;
		
		if (graph_2->instruction_code==GLOAD_I){
			new_offset=offset-(graph_2->instruction_parameters[0].i<<shift);
			if ((unsigned)((new_offset | MAX_INDIRECT_OFFSET)+1)<=(unsigned)(MAX_INDIRECT_OFFSET+1) && !(shift==3 && (unsigned)new_offset>=(unsigned)(MAX_INDIRECT_OFFSET-4))){
				*offset_p=new_offset;
				return graph_3;
			}			
		}
	}
	
	*offset_p=offset;
	return graph_1;
}

static void code_replaceI (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5;

	graph_1=s_get_a (0);
	graph_2=s_pop_b();
	graph_3=s_get_b (0);

	if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
		LESS_UNSIGNED (graph_2->instruction_parameters[0].i,(MAX_INDIRECT_OFFSET-ARRAY_ELEMENTS_OFFSET)>>STACK_ELEMENT_LOG_SIZE))
	{
		int offset;
		offset=ARRAY_ELEMENTS_OFFSET+(graph_2->instruction_parameters[0].i<<STACK_ELEMENT_LOG_SIZE);

		graph_5=g_load_x (graph_1,offset,0,NULL);
		graph_4=g_store_x (graph_3,graph_1,offset,0,NULL);
	} else {
		if (check_index_flag)
			graph_2=g_bounds (graph_1,graph_2);

#if defined (M68000) || defined (I486) || defined (ARM)
# ifdef M68000
		if (mc68000_flag){
			graph_2=g_lsl (g_load_i (2),graph_2);
			graph_5=g_load_x (graph_1,ARRAY_ELEMENTS_OFFSET,0,graph_2);
			graph_4=g_store_x (graph_3,graph_1,ARRAY_ELEMENTS_OFFSET,0,graph_2);
		} else
# endif
		{
			int offset;
			
			graph_2=optimize_array_index (ARRAY_ELEMENTS_OFFSET,STACK_ELEMENT_LOG_SIZE,graph_2,&offset);
			graph_5=g_load_x (graph_1,offset,STACK_ELEMENT_LOG_SIZE,graph_2);
			graph_4=g_store_x (graph_3,graph_1,offset,STACK_ELEMENT_LOG_SIZE,graph_2);
		}
#else
		graph_2=g_lsl_2_add_12 (graph_2);
		graph_5=g_load_x (graph_1,0,0,graph_2);
		graph_4=g_store_x (graph_3,graph_1,0,0,graph_2);
#endif
	}

	s_put_b (0,graph_5);	
	s_put_a (0,graph_4);
}

#ifdef G_A64
static void code_replaceI32 (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5;

	graph_1=s_get_a (0);
	graph_2=s_pop_b();
	graph_3=s_get_b (0);

	if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
		LESS_UNSIGNED (graph_2->instruction_parameters[0].i,(MAX_INDIRECT_OFFSET-ARRAY_ELEMENTS_OFFSET)>>2))
	{
		int offset;

		offset=ARRAY_ELEMENTS_OFFSET+(graph_2->instruction_parameters[0].i<<2);

		graph_5=g_load_s_x (graph_1,offset,0,NULL);
		graph_4=g_store_s_x (graph_3,graph_1,offset,0,NULL);
	} else {
		int offset;

		if (check_index_flag)
			graph_2=g_bounds (graph_1,graph_2);

		graph_2=optimize_array_index (ARRAY_ELEMENTS_OFFSET,2,graph_2,&offset);
		graph_5=g_load_s_x (graph_1,offset,2,graph_2);
		graph_4=g_store_s_x (graph_3,graph_1,offset,2,graph_2);
	}

	s_put_b (0,graph_5);	
	s_put_a (0,graph_4);
}
#endif

static INSTRUCTION_GRAPH char_or_bool_array_offset (int offset,INSTRUCTION_GRAPH graph_1)
{
	if (graph_1->instruction_code==GADD){
		INSTRUCTION_GRAPH graph_1_arg_1,graph_1_arg_2;
		
		graph_1_arg_1=graph_1->instruction_parameters[0].p;
		graph_1_arg_2=graph_1->instruction_parameters[1].p;
		if (graph_1_arg_1->instruction_code==GLOAD_I)
			return g_add (g_load_i (offset+graph_1_arg_1->instruction_parameters[0].i),graph_1_arg_2);
		else if (graph_1_arg_2->instruction_code==GLOAD_I)
			return g_add (g_load_i (offset+graph_1_arg_2->instruction_parameters[0].i),graph_1_arg_1);
	} else if (graph_1->instruction_code==GSUB){
		INSTRUCTION_GRAPH graph_1_arg_1,graph_1_arg_2;
		
		graph_1_arg_1=graph_1->instruction_parameters[0].p;
		graph_1_arg_2=graph_1->instruction_parameters[1].p;
		if (graph_1_arg_1->instruction_code==GLOAD_I)
			return g_add (g_load_i (offset-graph_1_arg_1->instruction_parameters[0].i),graph_1_arg_2);
		else if (graph_1_arg_2->instruction_code==GLOAD_I)
			return g_sub (graph_1_arg_1,g_load_i (offset+graph_1_arg_2->instruction_parameters[0].i));
	}
	
	return g_add (g_load_i (offset),graph_1);
}

static void code_replaceBC (int offset,int ext_signed)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5;
		
	graph_1=s_get_a (0);
	graph_2=s_pop_b();
	graph_3=s_get_b (0);

	if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
		LESS_UNSIGNED (graph_2->instruction_parameters[0].i,MAX_INDIRECT_OFFSET-offset))
	{
		offset+=graph_2->instruction_parameters[0].i;
		
		graph_5=g_load_b_x (graph_1,offset,ext_signed,NULL);
		graph_4=g_store_b_x (graph_3,graph_1,offset,NULL);
	} else {
		if (check_index_flag)
			graph_2=g_bounds (graph_1,graph_2);

#if defined (M68000) || defined (I486) || defined (ARM)
		{
		int new_offset;

		graph_2=optimize_array_index (offset,0,graph_2,&new_offset);
		graph_5=g_load_b_x (graph_1,new_offset,ext_signed,graph_2);
		graph_4=g_store_b_x (graph_3,graph_1,new_offset,graph_2);
		}
#else
		graph_2=char_or_bool_array_offset (offset,graph_2);
		graph_5=g_load_b_x (graph_1,0,ext_signed,graph_2);
		graph_4=g_store_b_x (graph_3,graph_1,0,graph_2);
#endif
	}
	
	s_put_b (0,graph_5);	
	s_put_a (0,graph_4);
}

static void code_lazy_replace (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5;
	
	graph_1=s_pop_a();
	graph_2=s_get_a (0);
	graph_3=s_pop_b();

	if (!check_index_flag && graph_3->instruction_code==GLOAD_I &&
		LESS_UNSIGNED (graph_3->instruction_parameters[0].i,(MAX_INDIRECT_OFFSET-ARRAY_ELEMENTS_OFFSET)>>STACK_ELEMENT_LOG_SIZE))
	{
		int offset;
		
		offset=ARRAY_ELEMENTS_OFFSET+(graph_3->instruction_parameters[0].i<<STACK_ELEMENT_LOG_SIZE);
		graph_5=g_load_x (graph_1,offset,0,NULL);
		graph_4=g_store_x (graph_2,graph_1,offset,0,NULL);
	} else {
		if (check_index_flag)
			graph_3=g_bounds (graph_1,graph_3);

#if defined (M68000) || defined (I486) || defined (ARM)
# ifdef M68000
		if (mc68000_flag){
			graph_3=g_lsl (g_load_i (2),graph_3);
			graph_5=g_load_x (graph_1,ARRAY_ELEMENTS_OFFSET,0,graph_3);
			graph_4=g_store_x (graph_2,graph_1,ARRAY_ELEMENTS_OFFSET,0,graph_3);
		} else 
# endif
		{
			int offset;

			graph_3=optimize_array_index (ARRAY_ELEMENTS_OFFSET,STACK_ELEMENT_LOG_SIZE,graph_3,&offset);
			graph_5=g_load_x (graph_1,offset,STACK_ELEMENT_LOG_SIZE,graph_3);
			graph_4=g_store_x (graph_2,graph_1,offset,STACK_ELEMENT_LOG_SIZE,graph_3);
		}
#else
		graph_3=g_lsl_2_add_12 (graph_3);
		graph_5=g_load_x (graph_1,0,0,graph_3);
		graph_4=g_store_x (graph_2,graph_1,0,0,graph_3);
#endif
	}
	
	s_put_a (0,graph_4);
	s_push_a (graph_5);
}

static void code_replaceR (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6,graph_7,graph_8,graph_9,graph_10;
	
	graph_1=s_get_a (0);
	graph_2=s_pop_b();	

	graph_3=s_pop_b();
#ifndef G_A64
	graph_4=s_pop_b();
#endif

	if (check_index_flag)
		graph_2=g_bounds (graph_1,graph_2);

#ifdef M68000
	if (!mc68881_flag){
		if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
			LESS_UNSIGNED (graph_2->instruction_parameters[0].i,(MAX_INDIRECT_OFFSET-16)>>3))
		{
			int offset;
			
			offset=REAL_ARRAY_ELEMENTS_OFFSET+(graph_2->instruction_parameters[0].i<<3);
			graph_9=g_load_x (graph_1,offset,0,NULL);
			graph_10=g_load_x (graph_1,offset+4,0,NULL);
			graph_7=g_store_x (graph_3,graph_1,offset,0,NULL);
			graph_8=g_store_x (graph_4,graph_7,offset+4,0,NULL);
		} else {
			if (mc68000_flag){
				graph_5=g_load_i (3);
				graph_6=g_lsl (graph_5,graph_2);
				graph_9=g_load_x (graph_1,REAL_ARRAY_ELEMENTS_OFFSET,0,graph_6);
				graph_10=g_load_x (graph_1,REAL_ARRAY_ELEMENTS_OFFSET+4,0,graph_6);
				graph_7=g_store_x (graph_3,graph_1,REAL_ARRAY_ELEMENTS_OFFSET,0,graph_6);
				graph_8=g_store_x (graph_4,graph_7,REAL_ARRAY_ELEMENTS_OFFSET+4,0,graph_6);
			} else {
				graph_9=g_load_x (graph_1,REAL_ARRAY_ELEMENTS_OFFSET,3,graph_2);
				graph_10=g_load_x (graph_1,REAL_ARRAY_ELEMENTS_OFFSET+4,3,graph_2);
				graph_7=g_store_x (graph_3,graph_1,REAL_ARRAY_ELEMENTS_OFFSET,3,graph_2);
				graph_8=g_store_x (graph_4,graph_7,REAL_ARRAY_ELEMENTS_OFFSET+4,3,graph_2);		
			}
		}
	} else
#endif
	{
#ifdef G_A64
		graph_7=g_fp_arg (graph_3);
#else
		graph_7=g_fjoin (graph_3,graph_4);
#endif
		if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
			LESS_UNSIGNED (graph_2->instruction_parameters[0].i,(MAX_INDIRECT_OFFSET-REAL_ARRAY_ELEMENTS_OFFSET)>>3))
		{
			int offset;
			
			offset=REAL_ARRAY_ELEMENTS_OFFSET+(graph_2->instruction_parameters[0].i<<3);
			graph_4=g_fload_x (graph_1,offset,0,NULL);
			graph_8=g_fstore_x (graph_7,graph_1,offset,0,NULL);
		} else {
#if defined (M68000) || defined (I486) || defined (ARM)
			int offset;

			graph_2=optimize_array_index (ARRAY_ELEMENTS_OFFSET,3,graph_2,&offset);
			graph_4=g_fload_x (graph_1,offset,3,graph_2);
			graph_8=g_fstore_x (graph_7,graph_1,offset,3,graph_2);
#else
			graph_2=g_lsl_3_add_12 (graph_2);
# if defined (sparc) && !defined (ALIGN_REAL_ARRAYS)
			graph_4=g_fload_x (graph_1,REAL_ARRAY_ELEMENTS_OFFSET,0,graph_2);
			graph_8=g_fstore_x (graph_7,graph_1,REAL_ARRAY_ELEMENTS_OFFSET,0,graph_2);
# else
			graph_4=g_fload_x (graph_1,0,0,graph_2);
			graph_8=g_fstore_x (graph_7,graph_1,0,0,graph_2);
# endif
#endif
		}
#ifdef ALIGN_REAL_ARRAYS
		graph_4->inode_arity |= LOAD_STORE_ALIGNED_REAL;
		graph_8->inode_arity |= LOAD_STORE_ALIGNED_REAL;
#endif

#ifdef G_A64
		graph_9=g_fromf (graph_4);
#else
		g_fhighlow (graph_9,graph_10,graph_4);
#endif
	}

	s_put_a (0,graph_8);

#ifndef G_A64
	s_push_b (graph_10);
#endif
	s_push_b (graph_9);
}

#if defined (I486) || defined (ARM)
static void code_replaceR32 (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_7,graph_8,graph_9,graph_10;

	graph_1=s_get_a (0);
	graph_2=s_pop_b();
	graph_3=s_pop_b();
# ifndef G_A64
	graph_4=s_pop_b();
# endif

	if (check_index_flag)
		graph_2=g_bounds (graph_1,graph_2);

# ifdef G_A64
	graph_7=g_fp_arg (graph_3);
# else
	graph_7=g_fjoin (graph_3,graph_4);
# endif

	if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
		LESS_UNSIGNED (graph_2->instruction_parameters[0].i,(MAX_INDIRECT_OFFSET-ARRAY_ELEMENTS_OFFSET)>>2))
	{
		int offset;
		
		offset=ARRAY_ELEMENTS_OFFSET+(graph_2->instruction_parameters[0].i<<2);
		graph_4=g_fload_s_x (graph_1,offset,0,NULL);
		graph_8=g_fstore_s_x (graph_7,graph_1,offset,0,NULL);
	} else {
		int offset;

		graph_2=optimize_array_index (ARRAY_ELEMENTS_OFFSET,2,graph_2,&offset);
		graph_4=g_fload_s_x (graph_1,offset,2,graph_2);
		graph_8=g_fstore_s_x (graph_7,graph_1,offset,2,graph_2);
	}

# ifdef G_A64
	graph_9=g_fromf (graph_4);
# else
	g_fhighlow (graph_9,graph_10,graph_4);
# endif

	s_put_a (0,graph_8);
# ifndef G_A64
	s_push_b (graph_10);
# endif
	s_push_b (graph_9);
}
#endif

static void code_r_replace (int a_size,int b_size)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	int i,element_size,offset;
	
	graph_1=s_get_a (0);
	graph_2=s_pop_b();
	
	element_size=(a_size+b_size)<<STACK_ELEMENT_LOG_SIZE;
	
	if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
		LESS_UNSIGNED (graph_2->instruction_parameters[0].i,(MAX_INDIRECT_OFFSET-ARRAY_ELEMENTS_OFFSET-(element_size-STACK_ELEMENT_SIZE))/element_size))
	{
		offset=ARRAY_ELEMENTS_OFFSET+graph_2->instruction_parameters[0].i*element_size;
		graph_3=NULL;
	} else {
		if (check_index_flag)
			graph_2=g_bounds (graph_1,graph_2);

		offset=3<<STACK_ELEMENT_LOG_SIZE;
		graph_3=multiply_by_constant ((a_size+b_size)<<STACK_ELEMENT_LOG_SIZE,graph_2);

#if defined (sparc) || defined (G_POWER)
		graph_3=g_add (graph_1,graph_3);
#endif
	}

	for (i=0; i<a_size; ++i){
		INSTRUCTION_GRAPH graph_4,graph_5;
		
		graph_4=s_get_a (i+1);
		graph_5=g_load_x (graph_1,offset+(i<<STACK_ELEMENT_LOG_SIZE),0,graph_3);
		graph_1=g_store_x (graph_4,graph_1,offset+(i<<STACK_ELEMENT_LOG_SIZE),0,graph_3);
		
		s_put_a (i,graph_5);
	}

	for (i=0; i<b_size; ++i){
		INSTRUCTION_GRAPH graph_4,graph_5;
		
		graph_4=s_get_b (i);

#ifndef G_A64
		if (graph_4->instruction_code==GFHIGH && i+1<b_size){
			INSTRUCTION_GRAPH graph_5;
			
			graph_5=s_get_b (i+1);
			if (graph_5->instruction_code==GFLOW && graph_4->instruction_parameters[0].p==graph_5->instruction_parameters[0].p){				
				INSTRUCTION_GRAPH graph_6,graph_7,graph_8,graph_9;
				
				graph_6=g_fjoin (graph_4,graph_5);
				graph_7=g_fload_x (graph_1,offset+((a_size+i)<<STACK_ELEMENT_LOG_SIZE),0,graph_3);
				graph_1=g_fstore_x (graph_6,graph_1,offset+((a_size+i)<<STACK_ELEMENT_LOG_SIZE),0,graph_3);

				g_fhighlow (graph_8,graph_9,graph_7);
	
				s_put_b (i+1,graph_9);
				s_put_b (i,graph_8);
				++i;
				
				continue;
			}
		}
#else
		if (graph_4->instruction_code==GFROMF){
			INSTRUCTION_GRAPH graph_5,graph_6,graph_7;
			
			graph_5=graph_4->instruction_parameters[0].p;
			graph_6=g_fload_x (graph_1,offset+((a_size+i)<<STACK_ELEMENT_LOG_SIZE),0,graph_3);
			graph_1=g_fstore_x (graph_5,graph_1,offset+((a_size+i)<<STACK_ELEMENT_LOG_SIZE),0,graph_3);

			graph_7=g_fromf (graph_6);

			s_put_b (i,graph_7);
			continue;
		}
#endif

		graph_5=g_load_x (graph_1,offset+((a_size+i)<<STACK_ELEMENT_LOG_SIZE),0,graph_3);
		graph_1=g_store_x (graph_4,graph_1,offset+((a_size+i)<<STACK_ELEMENT_LOG_SIZE),0,graph_3);
		
		s_put_b (i,graph_5);
	}
	
	s_put_a (a_size,graph_1);
}

void code_replace (char element_descriptor[],int a_size,int b_size)
{
	if (check_index_flag && index_error_label==NULL){
		index_error_label=enter_label ("index__error",
#if (defined (ARM) && defined (G_A64)) || defined (THUMB)
			FAR_CONDITIONAL_JUMP_LABEL);
#else
			0);
#endif
		if (!(index_error_label->label_flags & EXPORT_LABEL))
			index_error_label->label_flags |= IMPORT_LABEL;
	}

	switch (element_descriptor[0]){
		case 'B':
			if (element_descriptor[1]=='O' && element_descriptor[2]=='O' && element_descriptor[3]=='L' &&
				element_descriptor[4]=='\0')
			{
				code_replaceBC (ARRAY_ELEMENTS_OFFSET,1);
				return;	
			}
			break;
		case 'C':
			if (element_descriptor[1]=='H' && element_descriptor[2]=='A' && element_descriptor[3]=='R' &&
				element_descriptor[4]=='\0')
			{
#ifdef ARRAY_SIZE_BEFORE_DESCRIPTOR
				code_replaceBC (STACK_ELEMENT_SIZE,0);
#else
				code_replaceBC (2*STACK_ELEMENT_SIZE,0);
#endif
				return;	
			}
			break;
		case 'I':
			if (element_descriptor[1]=='N' && element_descriptor[2]=='T'){
				if (element_descriptor[3]=='\0'){
					code_replaceI();
					return;
				}
#if defined (G_A64) || defined (I486)
				if (element_descriptor[3]=='3' && element_descriptor[4]=='2' && element_descriptor[5]=='\0'){
# ifdef G_A64
					code_replaceI32();
# else
					code_replaceI();
# endif
					return;
				}
#endif
			}
			break;
		case 'P':
			if (is__rocid (element_descriptor)){
				code_replaceI();
				return;	
			}
			break;
		case 'R':
			if (element_descriptor[1]=='E' && element_descriptor[2]=='A' && element_descriptor[3]=='L'){
				if (element_descriptor[4]=='\0'){
					code_replaceR();
					return;
				}
#if defined (I486) || defined (ARM)
				if (element_descriptor[4]=='3' && element_descriptor[5]=='2' && element_descriptor[6]=='\0'){
					code_replaceR32();
					return;
				}
#endif
			}
			break;
		case 'A':
			if (element_descriptor[1]=='R' && element_descriptor[2]=='R' && element_descriptor[3]=='A' &&
				element_descriptor[4]=='Y' && element_descriptor[5]=='\0')
			{
				code_lazy_replace();
				return;	
			}
			break;
		case 'S':
			if (element_descriptor[1]=='T' && element_descriptor[2]=='R' && element_descriptor[3]=='I' &&
				element_descriptor[4]=='N' && element_descriptor[5]=='G' && element_descriptor[6]=='\0')
			{
				code_lazy_replace();
				return;	
			}
			break;
		case 'W':
			if (is__orld (element_descriptor)){
				code_lazy_replace();
				return;	
			}
			break;
		case '_':
			if (element_descriptor[1]=='_' && element_descriptor[2]=='\0'){
				code_lazy_replace();
				return;	
			}
			break;
	}

	code_r_replace (a_size,b_size);
}

void code_repl_arg (int arity,int argument_n)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	graph_1=s_pop_a();
	
	if (argument_n<2 || (argument_n==2 && arity==2))
		graph_2=g_load_id (argument_n<<STACK_ELEMENT_LOG_SIZE,graph_1);
	else {
		INSTRUCTION_GRAPH graph_3;
		
		graph_3=g_load_id (2<<STACK_ELEMENT_LOG_SIZE,graph_1);
		graph_2=g_load_id ((argument_n-2)<<STACK_ELEMENT_LOG_SIZE,graph_3);
	}
	
	s_push_a (graph_2);
}

void code_repl_args (int arity,int n_arguments)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	if (n_arguments==0)
		return;
		
	graph_1=s_pop_a();
	graph_2=g_load_id (ARGUMENTS_OFFSET-NODE_POINTER_OFFSET,graph_1);

	if (n_arguments!=1)
		if (n_arguments==2 && arity==2){
			graph_3=g_load_id (2*STACK_ELEMENT_SIZE-NODE_POINTER_OFFSET,graph_1);
			s_push_a (graph_3);
		} else {
			INSTRUCTION_GRAPH graph_4;
			
			graph_3=g_load_id (2*STACK_ELEMENT_SIZE-NODE_POINTER_OFFSET,graph_1);
			--n_arguments;
			
			if (n_arguments==1){
				graph_4=g_load_id (0-NODE_POINTER_OFFSET,graph_3);
				s_push_a (graph_4);
			} else {
#if ! (defined (I486) || defined (ARM))
				if (n_arguments>=8){
#endif
					while (n_arguments!=0){
						INSTRUCTION_GRAPH graph_5;
					
						--n_arguments;
	
						graph_5=g_load_id ((n_arguments<<STACK_ELEMENT_LOG_SIZE)-NODE_POINTER_OFFSET,graph_3);
						s_push_a (graph_5);
					}
#if ! (defined (I486) || defined (ARM))
				} else {
					graph_4=g_movem (0-NODE_POINTER_OFFSET,graph_3,n_arguments);
	
					while (n_arguments!=0){
						INSTRUCTION_GRAPH graph_5;
					
						--n_arguments;
	
						graph_5=g_movemi (n_arguments,graph_4);
						s_push_a (graph_5);
					}
				}
#endif
			}
		}
	
	s_push_a (graph_2);
}

void code_repl_args_b (VOID)
{
	if (repl_args_b_label==NULL)
		repl_args_b_label=enter_label ("repl_args_b",IMPORT_LABEL);

	s_push_b (s_get_b (0));
	s_put_b (1,s_get_b (2));
	s_put_b (2,NULL);
	insert_basic_block (JSR_BLOCK,1,2+1,i_i_vector,repl_args_b_label);
}

void code_repl_r_args (int a_size,int b_size)
{
	INSTRUCTION_GRAPH graph_1;

	graph_1=s_pop_a();

	push_record_arguments (graph_1,a_size,b_size);
}

void code_repl_r_args_a (int a_size,int b_size,int argument_number,int n_arguments)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_pop_a();
	graph_3=NULL;
	
	argument_number+=n_arguments;
	for (; n_arguments>0; --n_arguments){
		--argument_number;
		if (argument_number<2 || (argument_number==2 && a_size+b_size==2))
			graph_2=g_load_id (argument_number<<STACK_ELEMENT_LOG_SIZE,graph_1);
		else {
			if (graph_3==NULL)
				graph_3=g_load_id (2<<STACK_ELEMENT_LOG_SIZE,graph_1);
			graph_2=g_load_id ((argument_number-2)<<STACK_ELEMENT_LOG_SIZE,graph_3);
		}
		s_push_a (graph_2); 
	}	
}

void code_repl_r_a_args_n_a (VOID)
{
	if (repl_r_a_args_n_a_label==NULL)
		repl_r_a_args_n_a_label=enter_label ("repl_r_a_args_n_a",IMPORT_LABEL);

	s_push_b (NULL);
	insert_basic_block (JSR_BLOCK,1,0+1,e_vector,repl_r_a_args_n_a_label);

	init_b_stack (1,i_vector);
}

void code_release (void)
{
}

#ifdef I486
static INSTRUCTION_GRAPH remove_and_31_or_63 (INSTRUCTION_GRAPH graph)
{
	if (graph->instruction_parameters[0].p->instruction_code==GLOAD_I &&
# ifndef G_A64
		graph->instruction_parameters[0].p->instruction_parameters[0].i==31)
# else
		graph->instruction_parameters[0].p->instruction_parameters[0].i==63)
# endif
	{
		return graph->instruction_parameters[1].p;
	}
	if (graph->instruction_parameters[1].p->instruction_code==GLOAD_I &&
# ifndef G_A64
		graph->instruction_parameters[1].p->instruction_parameters[0].i==31)
# else
		graph->instruction_parameters[1].p->instruction_parameters[0].i==63)
# endif
	{
		return graph->instruction_parameters[0].p;
	}
	return graph;
}

void code_rotl (void)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;

	graph_1=s_pop_b();
	graph_2=s_get_b (0);
	if (graph_2->instruction_code==GAND)
		graph_2=remove_and_31_or_63 (graph_2);
	graph_3=g_instruction_2 (GROTL,graph_2,graph_1);

	s_put_b (0,graph_3);
}

void code_rotr (void)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;

	graph_1=s_pop_b();
	graph_2=s_get_b (0);
	if (graph_2->instruction_code==GAND)
		graph_2=remove_and_31_or_63 (graph_2);
	graph_3=g_instruction_2 (GROTR,graph_2,graph_1);
	
	s_put_b (0,graph_3);
}
#endif

void code_rtn (void)
{
	int b_offset,a_stack_size,b_stack_size,return_with_rts,n_data_parameter_registers;
	ULONG *local_demanded_vector;
	
	if (!demand_flag)
		error ("Directive .d missing before rtn instruction");

	a_stack_size=demanded_a_stack_size;
	b_stack_size=demanded_b_stack_size;
	local_demanded_vector=demanded_vector;

	n_data_parameter_registers=
		parallel_flag ? N_DATA_PARAMETER_REGISTERS-1 : N_DATA_PARAMETER_REGISTERS;

#if ! (defined (sparc) || defined (G_POWER))
	b_offset=0;
#else
	b_offset=4;
#endif
	return_with_rts=1;

	if (b_stack_size>n_data_parameter_registers || !mc68881_flag){
		int offset,n_data_registers,n_float_registers,n_float_parameter_registers;
		
		n_float_parameter_registers= mc68881_flag ? N_FLOAT_PARAMETER_REGISTERS : 0;

		n_data_registers=0;
		n_float_registers=0;

		for (offset=0; offset<b_stack_size; ++offset)
			if (local_demanded_vector[offset>>LOG_VECTOR_ELEMENT_SIZE] & (((ULONG)1)<<(offset & VECTOR_ELEMENT_MASK))){
				if (++n_float_registers>n_float_parameter_registers)
					break;
#ifndef G_A64
				++offset;
#endif
			} else
				if (++n_data_registers>n_data_parameter_registers)
					break;

		if (n_data_registers>n_data_parameter_registers || n_float_registers>n_float_parameter_registers){
			INSTRUCTION_GRAPH graph;

#if ! (defined (I486) || defined (ARM))
			graph=s_get_b (b_stack_size);
			for	(offset=b_stack_size-1; offset>=0; --offset)
				s_put_b (offset+1,s_get_b (offset));
			s_pop_b();
			s_push_a (graph);
			
			++a_stack_size;
			b_offset=0;

			return_with_rts=0;
#else
			{
				int return_address_offset;
				ULONG mask,new_vector_0;

				if (n_data_registers>n_data_parameter_registers)
					n_data_registers=n_data_parameter_registers;
				else if (n_data_registers<n_data_parameter_registers)
					n_data_parameter_registers=n_data_registers;
				if (n_float_registers>n_float_parameter_registers)
					n_float_registers=n_float_parameter_registers;				
#ifndef G_A64
				return_address_offset=n_data_registers+(n_float_registers<<1);
#else
				return_address_offset=n_data_registers+n_float_registers;
#endif
				graph=s_get_b (b_stack_size);
				for	(offset=b_stack_size-1; offset>=return_address_offset; --offset)
					s_put_b (offset+1,s_get_b (offset));
				s_put_b (return_address_offset,graph);
				
				++b_stack_size;
				mask=(1<<return_address_offset)-1;
				new_vector_0=(local_demanded_vector[0] & mask) | ((local_demanded_vector[0] & ~mask)<<1);
				if (b_stack_size < 32){
					static ULONG small_local_demanded_vector;
					
					small_local_demanded_vector=new_vector_0;
					local_demanded_vector=&small_local_demanded_vector;
				} else {
					ULONG *new_vector_p;
					int i,n_longs_in_vector;
					
					n_longs_in_vector=(b_stack_size+(1+32-1))>>5;
					new_vector_p=(ULONG*)fast_memory_allocate (n_longs_in_vector * sizeof (ULONG));
				
					new_vector_p[0]=new_vector_0;
					if (b_stack_size+(1+32-1)==n_longs_in_vector<<5){
						--n_longs_in_vector;
						new_vector_p[n_longs_in_vector]=(local_demanded_vector[n_longs_in_vector-1]>>31) & 1;
					}
					for (i=1; i<n_longs_in_vector; ++i)
						new_vector_p[i]=(local_demanded_vector[i]<<1) | ((local_demanded_vector[i-1]>>31) & 1);
				
					local_demanded_vector=new_vector_p;
				}
			}
#endif
		}
	}

#if ! (defined (I486) || defined (ARM))
	if (return_with_rts){
#endif

#if defined (I486) || defined (ARM)
		b_offset+=
			end_basic_block_with_registers_and_return_address_and_return_b_stack_offset
				(a_stack_size,b_stack_size,local_demanded_vector,n_data_parameter_registers);
#else
		b_offset+=
			end_basic_block_with_registers_and_return_b_stack_offset
				(a_stack_size,b_stack_size,local_demanded_vector,N_ADDRESS_PARAMETER_REGISTERS);
#endif

#if ! (defined (sparc) || defined (G_POWER))
		if (b_offset!=0)
			if (b_offset>0)
				i_add_i_r (b_offset,B_STACK_POINTER);
			else
				i_sub_i_r (-b_offset,B_STACK_POINTER);

# ifdef PROFILE
		if (profile_function_label!=NULL)
			i_rts_profile ();
		else
# endif
			i_rts();
#else
# ifdef PROFILE
		if (profile_function_label!=NULL)
			i_rts_profile (b_offset-4,b_offset);
		else
# endif
			i_rts (b_offset-4,b_offset);
#endif
#if ! (defined (I486) || defined (ARM))
	} else {
		b_offset+=
			end_basic_block_with_registers_and_return_b_stack_offset
				(a_stack_size,b_stack_size,local_demanded_vector,N_ADDRESS_PARAMETER_REGISTERS+1);

		if (a_stack_size>N_ADDRESS_PARAMETER_REGISTERS+1)
			a_stack_size=N_ADDRESS_PARAMETER_REGISTERS+1;

#	ifdef sparc
		if (b_offset!=0)
			if (b_offset>0)
				i_add_i_r (b_offset,B_STACK_POINTER);
			else
				i_sub_i_r (-b_offset,B_STACK_POINTER);

		i_jmp_id (8,num_to_a_reg (a_stack_size-1),(a_stack_size-1)<<4);
#	else
#		ifdef G_POWER
			if (profile_function_label!=NULL)
				i_rts_r_profile (num_to_a_reg (a_stack_size-1),b_offset);
			else
				i_rts_r (num_to_a_reg (a_stack_size-1),b_offset);
#		else
			if (b_offset!=0)
				if (b_offset>0)
					i_add_i_r (b_offset,B_STACK_POINTER);
				else
					i_sub_i_r (-b_offset,B_STACK_POINTER);

			i_jmp_id (0,num_to_a_reg (a_stack_size-1),(a_stack_size-1)<<4);
#		endif
#	endif
	}
#endif
	demand_flag=0;

	reachable=0;
	
	begin_new_basic_block();
}

void code_RtoI (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;

#if defined (G_POWER) || defined (I486) || defined (ARM)
# ifdef G_POWER
	if (r_to_i_buffer_label==NULL)
		r_to_i_buffer_label=enter_label ("r_to_i_buffer",IMPORT_LABEL);
# endif
	graph_1=s_pop_b();

# ifdef G_A64
	graph_3=g_fp_arg (graph_1);
# else
	graph_2=s_pop_b();
	graph_3=g_fjoin (graph_1,graph_2);
# endif
	graph_4=g_frtoi (graph_3);
	
	s_push_b (graph_4);
#else
# ifdef M68000
	if (!mc68881_flag){
# endif
		if (r_to_i_real==NULL)
			r_to_i_real=enter_label ("r_to_i_real",IMPORT_LABEL);

		code_monadic_sane_operator (r_to_i_real);
		init_b_stack (1,i_vector);
# ifdef M68000
	} else {
		graph_1=s_pop_b();
		graph_2=s_pop_b();
		graph_3=g_fjoin (graph_1,graph_2);
	
		graph_4=g_frtoi (graph_3);
	
		s_push_b (graph_4);
	}
# endif
#endif
}

static void code_lazy_select (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_pop_a();
	graph_2=s_pop_b();

	if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
		(unsigned long) graph_2->instruction_parameters[0].i < (unsigned long) ((MAX_INDIRECT_OFFSET-ARRAY_ELEMENTS_OFFSET)>>STACK_ELEMENT_LOG_SIZE))
	{
		graph_3=g_load_x (graph_1,ARRAY_ELEMENTS_OFFSET+(graph_2->instruction_parameters[0].i<<STACK_ELEMENT_LOG_SIZE),0,NULL);
	} else {
		if (check_index_flag)
			graph_2=g_bounds (graph_1,graph_2);

#if defined (M68000) || defined (I486) || defined (ARM)
# ifdef M68000
		if (mc68000_flag){
			graph_2=g_lsl (g_load_i (2),graph_2);
			graph_3=g_load_x (graph_1,ARRAY_ELEMENTS_OFFSET,0,graph_2);
		} else
# endif
		{
			int offset;

			graph_2=optimize_array_index (ARRAY_ELEMENTS_OFFSET,STACK_ELEMENT_LOG_SIZE,graph_2,&offset);
			graph_3=g_load_x (graph_1,offset,STACK_ELEMENT_LOG_SIZE,graph_2);
		}
#else
		graph_2=g_lsl_2_add_12 (graph_2);
		graph_3=g_load_x (graph_1,0,0,graph_2);
#endif
	}
	
	s_push_a (graph_3);
}

static void code_selectBC (int offset,int ext_signed)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_pop_a();
	graph_2=s_get_b (0);

	if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
		LESS_UNSIGNED (graph_2->instruction_parameters[0].i,MAX_INDIRECT_OFFSET-offset))
	{
		graph_3=g_load_b_x (graph_1,offset+graph_2->instruction_parameters[0].i,ext_signed,NULL);
	} else {
		if (check_index_flag)
			graph_2=g_bounds (graph_1,graph_2);

#if defined (M68000) || defined (I486) || defined (ARM)
		{
		int new_offset;

		graph_2=optimize_array_index (offset,0,graph_2,&new_offset);
		graph_3=g_load_b_x (graph_1,new_offset,ext_signed,graph_2);
		}
#else
		graph_2=char_or_bool_array_offset (offset,graph_2);
		graph_3=g_load_b_x (graph_1,0,ext_signed,graph_2);
#endif
	}
	
	s_put_b (0,graph_3);
}

static void code_selectI (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_pop_a();
	graph_2=s_get_b (0);

#ifdef ARRAY_OPTIMIZATIONS
	if (graph_1->instruction_code==GCREATE && graph_2->instruction_code==GLOAD_I){
		int i;
		
		i=graph_2->instruction_parameters[0].i;
		if (LESS_UNSIGNED (i,4) && 3+i < graph_1->inode_arity){
			INSTRUCTION_GRAPH graph_3;
			
			graph_3=graph_1->instruction_parameters[3+i].p;
			s_put_b (0,graph_3);
			return;
		}
	}
#endif

	if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
		LESS_UNSIGNED (graph_2->instruction_parameters[0].i,(MAX_INDIRECT_OFFSET-ARRAY_ELEMENTS_OFFSET)>>STACK_ELEMENT_LOG_SIZE))
	{
		graph_3=g_load_x (graph_1,ARRAY_ELEMENTS_OFFSET+(graph_2->instruction_parameters[0].i<<STACK_ELEMENT_LOG_SIZE),0,NULL);
	} else {
		if (check_index_flag)
			graph_2=g_bounds (graph_1,graph_2);

#if defined (M68000) || defined (I486) || defined (ARM)
# ifdef M68000
		if (mc68000_flag){
			graph_2=g_lsl (g_load_i (2),graph_2);
			graph_3=g_load_x (graph_1,ARRAY_ELEMENTS_OFFSET,0,graph_2);
		} else
# endif
		{
			int offset;

			graph_2=optimize_array_index (ARRAY_ELEMENTS_OFFSET,STACK_ELEMENT_LOG_SIZE,graph_2,&offset);
			graph_3=g_load_x (graph_1,offset,STACK_ELEMENT_LOG_SIZE,graph_2);
		}
#else
		graph_2=g_lsl_2_add_12 (graph_2);
		graph_3=g_load_x (graph_1,0,0,graph_2);
#endif
	}
	
	s_put_b (0,graph_3);
}

#ifdef G_A64
static void code_selectI32 (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_pop_a();
	graph_2=s_get_b (0);

	if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
		LESS_UNSIGNED (graph_2->instruction_parameters[0].i,(MAX_INDIRECT_OFFSET-ARRAY_ELEMENTS_OFFSET)>>2))
	{
		graph_3=g_load_s_x (graph_1,ARRAY_ELEMENTS_OFFSET+(graph_2->instruction_parameters[0].i<<2),0,NULL);
	} else {
		int offset;

		if (check_index_flag)
			graph_2=g_bounds (graph_1,graph_2);

		graph_2=optimize_array_index (ARRAY_ELEMENTS_OFFSET,2,graph_2,&offset);
		graph_3=g_load_s_x (graph_1,offset,2,graph_2);
	}
	
	s_put_b (0,graph_3);
}
#endif

static void code_selectR (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6;
	
	graph_1=s_pop_a();
	graph_2=s_pop_b();

	if (check_index_flag)
		graph_2=g_bounds (graph_1,graph_2);

#ifdef M68000
	if (!mc68881_flag){
		if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
			LESS_UNSIGNED (graph_2->instruction_parameters[0].i,(MAX_INDIRECT_OFFSET-16)>>3))
		{
			int offset;
		
			offset=REAL_ARRAY_ELEMENTS_OFFSET+(graph_2->instruction_parameters[0].i<<3);

			graph_5=g_load_x (graph_1,offset,0,NULL);
			graph_6=g_load_x (graph_1,offset+4,0,NULL);
		} else {
			if (mc68000_flag){
				graph_3=g_load_i (3);
				graph_4=g_lsl (graph_3,graph_2);
				graph_5=g_load_x (graph_1,REAL_ARRAY_ELEMENTS_OFFSET,0,graph_4);
				graph_6=g_load_x (graph_1,REAL_ARRAY_ELEMENTS_OFFSET+4,0,graph_4);
			} else {
				graph_5=g_load_x (graph_1,REAL_ARRAY_ELEMENTS_OFFSET,3,graph_2);
				graph_6=g_load_x (graph_1,REAL_ARRAY_ELEMENTS_OFFSET+4,3,graph_2);
			}
		}
	} else
#endif

	{
		if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
			LESS_UNSIGNED (graph_2->instruction_parameters[0].i,(MAX_INDIRECT_OFFSET-REAL_ARRAY_ELEMENTS_OFFSET)>>3))
		{
			graph_4=g_fload_x (graph_1,REAL_ARRAY_ELEMENTS_OFFSET+(graph_2->instruction_parameters[0].i<<3),0,NULL);
		} else {
#if defined (M68000) || defined (I486) || defined (ARM)
			int offset;

			graph_2=optimize_array_index (REAL_ARRAY_ELEMENTS_OFFSET,3,graph_2,&offset);
			graph_4=g_fload_x (graph_1,offset,3,graph_2);
#else
			graph_2=g_lsl_3_add_12 (graph_2);
# if defined (sparc) && !defined (ALIGN_REAL_ARRAYS)
			graph_4=g_fload_x (graph_1,REAL_ARRAY_ELEMENTS_OFFSET,0,graph_2);
# else
			graph_4=g_fload_x (graph_1,0,0,graph_2);
# endif
#endif
		}
#ifdef ALIGN_REAL_ARRAYS
		graph_4->inode_arity |= LOAD_STORE_ALIGNED_REAL;
#endif

#ifdef G_A64
		graph_5=g_fromf (graph_4);
#else
		g_fhighlow (graph_5,graph_6,graph_4);
#endif
	}

#ifndef G_A64
	s_push_b (graph_6);
#endif
	s_push_b (graph_5);
}

#if defined (I486) || defined (ARM) 
static void code_selectR32 (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6;
	
	graph_1=s_pop_a();
	graph_2=s_pop_b();

	if (check_index_flag)
		graph_2=g_bounds (graph_1,graph_2);

	if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
		LESS_UNSIGNED (graph_2->instruction_parameters[0].i,(MAX_INDIRECT_OFFSET-ARRAY_ELEMENTS_OFFSET)>>2))
	{
		graph_4=g_fload_s_x (graph_1,ARRAY_ELEMENTS_OFFSET+(graph_2->instruction_parameters[0].i<<2),0,NULL);
	} else {
		int offset;

		graph_2=optimize_array_index (ARRAY_ELEMENTS_OFFSET,2,graph_2,&offset);
		graph_4=g_fload_s_x (graph_1,offset,2,graph_2);
	}

# ifdef G_A64
	graph_5=g_fromf (graph_4);
# else
	g_fhighlow (graph_5,graph_6,graph_4);
	s_push_b (graph_6);
# endif
	s_push_b (graph_5);
}
#endif

static void code_r_select (int a_size,int b_size)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	long offset;
	int i,element_size;
	
	graph_1=s_pop_a();
	graph_2=s_pop_b();
	
	element_size=(a_size+b_size)<<STACK_ELEMENT_LOG_SIZE;
	
	if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
		LESS_UNSIGNED (graph_2->instruction_parameters[0].i,(MAX_INDIRECT_OFFSET-ARRAY_ELEMENTS_OFFSET-(element_size-STACK_ELEMENT_SIZE))/element_size))
	{
		offset=ARRAY_ELEMENTS_OFFSET+graph_2->instruction_parameters[0].i*element_size;
		graph_3=NULL;
	} else {
		if (check_index_flag)
			graph_2=g_bounds (graph_1,graph_2);

		offset=ARRAY_ELEMENTS_OFFSET;
		graph_3=multiply_by_constant ((a_size+b_size)<<STACK_ELEMENT_LOG_SIZE,graph_2);

#if defined (sparc) || defined (G_POWER)
		graph_3=g_add (graph_1,graph_3);
#endif
	}

	for (i=a_size-1; i>=0; --i){
		INSTRUCTION_GRAPH graph_4;
		
		graph_4=g_load_x (graph_1,offset+(i<<STACK_ELEMENT_LOG_SIZE),0,graph_3);
		s_push_a (graph_4);
	}

	for (i=b_size-1; i>=0; --i){
		INSTRUCTION_GRAPH graph_4;
		
		graph_4=g_load_x (graph_1,offset+((a_size+i)<<STACK_ELEMENT_LOG_SIZE),0,graph_3);
		s_push_b (graph_4);
	}
}

void code_select (char element_descriptor[],int a_size,int b_size)
{
	if (check_index_flag && index_error_label==NULL){
		index_error_label=enter_label ("index__error",
#if (defined (ARM) && defined (G_A64)) || defined (THUMB)
			FAR_CONDITIONAL_JUMP_LABEL);
#else
			0);
#endif
		if (!(index_error_label->label_flags & EXPORT_LABEL))
			index_error_label->label_flags |= IMPORT_LABEL;
	}

	switch (element_descriptor[0]){
		case 'B':
			if (element_descriptor[1]=='O' && element_descriptor[2]=='O' && element_descriptor[3]=='L' &&
				element_descriptor[4]=='\0')
			{
				code_selectBC (ARRAY_ELEMENTS_OFFSET,1);
				return;	
			}
			break;
		case 'C':
			if (element_descriptor[1]=='H' && element_descriptor[2]=='A' && element_descriptor[3]=='R' &&
				element_descriptor[4]=='\0')
			{
#ifdef ARRAY_SIZE_BEFORE_DESCRIPTOR
				code_selectBC (STACK_ELEMENT_SIZE,0);
#else
				code_selectBC (2*STACK_ELEMENT_SIZE,0);
#endif
				return;	
			}
			break;
		case 'I':
			if (element_descriptor[1]=='N' && element_descriptor[2]=='T'){
				if (element_descriptor[3]=='\0'){
					code_selectI();
					return;	
				}
#if defined (G_A64) || defined (I486)
				if (element_descriptor[3]=='3' && element_descriptor[4]=='2' && element_descriptor[5]=='\0'){
# ifdef G_A64
					code_selectI32();
# else
					code_selectI();
# endif
					return;	
				}				
#endif
			}
			break;
		case 'P':
			if (is__rocid (element_descriptor)){
				code_selectI();
				return;	
			}
			break;
		case 'R':
			if (element_descriptor[1]=='E' && element_descriptor[2]=='A' && element_descriptor[3]=='L'){
				if (element_descriptor[4]=='\0'){
					code_selectR();
					return;
				}
#if defined (I486) || defined (ARM)
				if (element_descriptor[4]=='3' && element_descriptor[5]=='2' && element_descriptor[6]=='\0'){
					code_selectR32();
					return;
				}
#endif
			}
			break;
		case 'A':
			if (element_descriptor[1]=='R' && element_descriptor[2]=='R' && element_descriptor[3]=='A' &&
				element_descriptor[4]=='Y' && element_descriptor[5]=='\0')
			{
				code_lazy_select();
				return;	
			}
			break;
		case 'S':
			if (element_descriptor[1]=='T' && element_descriptor[2]=='R' && element_descriptor[3]=='I' &&
				element_descriptor[4]=='N' && element_descriptor[5]=='G' && element_descriptor[6]=='\0')
			{
				code_lazy_select();
				return;	
			}
			break;
		case 'W':
			if (is__orld (element_descriptor)){
				code_lazy_select();
				return;	
			}
			break;
		case '_':
			if (element_descriptor[1]=='_' && element_descriptor[2]=='\0'){
				code_lazy_select();
				return;	
			}
			break;
	}

	code_r_select (a_size,b_size);
}

void code_set_entry (char *label_name,int a_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;

	if (EMPTY_label==NULL)
		EMPTY_label=enter_label ("EMPTY",IMPORT_LABEL | DATA_LABEL);
	
	if (!strcmp (label_name,"__cycle__in__spine")){
#ifndef RESERVE_CODE_REGISTER
		if (cycle_in_spine_label==NULL){
			cycle_in_spine_label=enter_label ("__cycle__in__spine",IMPORT_LABEL | NODE_ENTRY_LABEL);
			cycle_in_spine_label->label_arity=0;
			cycle_in_spine_label->label_descriptor=EMPTY_label;
		}
		graph_2=g_lea (cycle_in_spine_label);
#else
		graph_2=g_g_register (RESERVE_CODE_REGISTER);
#endif
	} else if (!strcmp (label_name,"__reserve")){
#ifndef RESERVE_CODE_REGISTER
		if (reserve_label==NULL){
			reserve_label=enter_label ("__reserve",IMPORT_LABEL | NODE_ENTRY_LABEL);
			reserve_label->label_arity=0;
			reserve_label->label_descriptor=EMPTY_label;
		}
		graph_2=g_lea (reserve_label);
#else
		graph_2=g_g_register (RESERVE_CODE_REGISTER);
#endif
	} else {
		LABEL *label;

		label=enter_label (label_name,NODE_ENTRY_LABEL);
		label->label_arity=0;
		label->label_descriptor=EMPTY_label;
		graph_2=g_lea (label);
	}
	
	graph_1=s_get_a (a_offset);
	graph_3=g_fill_2 (graph_1,graph_2);
	s_put_a (a_offset,graph_3);
}

#ifdef FINALIZERS
void code_set_finalizers (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	LABEL *finalizer_list_label;

	finalizer_list_label=enter_label ("finalizer_list",DATA_LABEL | IMPORT_LABEL);

	graph_1=g_lea (finalizer_list_label);
	graph_2=s_get_a (0);

	graph_3=g_fill_2 (graph_1,graph_2);

	graph_4=g_keep (graph_3,graph_2);

	s_put_a (0,graph_4);
}
#endif

void code_shiftl (void)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;

	graph_1=s_pop_b();
	graph_2=s_get_b (0);
#ifdef I486
	if (graph_2->instruction_code==GAND)
		graph_2=remove_and_31_or_63 (graph_2);
#endif
	graph_3=g_lsl (graph_2,graph_1);

	s_put_b (0,graph_3);
}

void code_shiftr (void)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;

	graph_1=s_pop_b();
	graph_2=s_get_b (0);
#ifdef I486
	if (graph_2->instruction_code==GAND)
		graph_2=remove_and_31_or_63 (graph_2);
#endif
	graph_3=g_asr (graph_2,graph_1);
	
	s_put_b (0,graph_3);
}

void code_shiftrU (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;

	graph_1=s_pop_b();
	graph_2=s_get_b (0);
#ifdef I486
	if (graph_2->instruction_code==GAND)
		graph_2=remove_and_31_or_63 (graph_2);
#endif
	graph_3=g_lsr (graph_2,graph_1);
	
	s_put_b (0,graph_3);
}

void code_sliceS (int source_offset,int destination_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	if (slice_string_label==NULL)
		slice_string_label=enter_label ("slice_string",IMPORT_LABEL);
	
	graph_1=s_get_a (source_offset);
	graph_2=s_get_a (destination_offset);
	
	s_push_a (graph_2);
	s_push_a (graph_1);

	s_push_b (s_get_b (0));
	s_put_b (1,s_get_b (2));
	s_put_b (2,NULL);
	insert_basic_block (JSR_BLOCK,2,2+1,i_i_vector,slice_string_label);
}

void code_sinR (VOID)
{
#if defined (I486) && !defined (G_AI64)
# ifdef SIN_COS_CSE
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6;
	
	graph_2=s_get_b (1);
	graph_1=s_get_b (0);
	graph_3=g_fjoin (graph_1,graph_2);

	graph_4=NULL;
	if (block_in_cos_cache==last_block)
		graph_4 = search_sin_or_cos (graph_3,cos_cache,n_cos_cache);

	if (graph_4==NULL || graph_4->instruction_code!=GFCOS){
		graph_4=g_instruction_2 (GFSIN,graph_3,NULL); // extra argument because it may become a GFRESULT0 node
		graph_4->inode_arity=1;

		if (block_in_sin_cache==last_block){
			sin_cache [n_sin_cache & (SIN_COS_CSE_CACHE_SIZE-1)] = graph_4;
			++n_sin_cache;
		} else {
			block_in_sin_cache=last_block;
			sin_cache [0] = graph_4;
			n_sin_cache=1;
		}
	} else {
		INSTRUCTION_GRAPH sincos_graph,graph_7;

		sincos_graph=g_instruction_1 (GFSINCOS,graph_3);
		graph_7=graph_4;

		graph_4=g_instruction_2 (GFRESULT0,sincos_graph,graph_7);

		graph_7->instruction_code=GFRESULT1;
		graph_7->inode_arity=2;
		graph_7->instruction_parameters[0].p=sincos_graph;
		graph_7->instruction_parameters[1].p=graph_4;
	}

	g_fhighlow (graph_5,graph_6,graph_4);

	s_put_b (1,graph_6);
	s_put_b (0,graph_5);
# else
	code_monadic_real_operator (GFSIN);
# endif
#else
# ifdef M68000
	if (!mc68881_flag){
# endif
		if (sin_real==NULL)
			sin_real=enter_label ("sin_real",IMPORT_LABEL);
		code_monadic_sane_operator (sin_real);
		init_b_stack (SIZE_OF_REAL_IN_STACK_ELEMENTS,r_vector);
# ifdef M68000
	} else
		code_monadic_real_operator (GFSIN);
# endif
#endif
}

#if defined (I486) && !defined (G_AI64)
void code_sincosR (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6,graph_7,graph_8,graph_9,graph_10;
	
	graph_2=s_get_b (1);
	graph_1=s_get_b (0);
	graph_3=g_fjoin (graph_1,graph_2);

	graph_4=g_instruction_1 (GFSINCOS,graph_3);

	graph_5=g_instruction_2 (GFRESULT1,graph_4,NULL);
	graph_6=g_instruction_2 (GFRESULT0,graph_4,NULL);
	graph_5->instruction_parameters[1].p=graph_6;
	graph_6->instruction_parameters[1].p=graph_5;

	g_fhighlow (graph_7,graph_8,graph_5);
	g_fhighlow (graph_9,graph_10,graph_6);

	s_put_b (1,graph_8);
	s_put_b (0,graph_7);

	s_push_b (graph_10);
	s_push_b (graph_9);
}
#endif

void code_sqrtR (VOID)
{
#ifdef M68000
	if (!mc68881_flag){
		if (sqrt_real==NULL)
			sqrt_real=enter_label ("sqrt_real",IMPORT_LABEL);
		code_monadic_sane_operator (sqrt_real);
		init_b_stack (SIZE_OF_REAL_IN_STACK_ELEMENTS,r_vector);
	} else
		code_monadic_real_operator (GFSQRT);
#else
# ifdef G_POWER
	if (sqrt_real==NULL)
		sqrt_real=enter_label ("sqrt_real",IMPORT_LABEL);
	code_monadic_sane_operator (sqrt_real);
	init_b_stack (SIZE_OF_REAL_IN_STACK_ELEMENTS,r_vector);
# else
	code_monadic_real_operator (GFSQRT);
# endif
#endif
}

void code_subI (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;

	graph_1=s_pop_b();
	graph_2=s_get_b (0);
	graph_3=g_sub (graph_2,graph_1);
	
	s_put_b (0,graph_3);
}

#if defined (I486) || defined (ARM)
void code_subLU (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6;
	
	graph_3=s_get_b (2);
	graph_2=s_get_b (1);
	graph_1=s_pop_b();

	graph_4=g_new_node (GSUBDU,3,3*sizeof (union instruction_parameter));
	graph_4->instruction_parameters[0].p=graph_1;
	graph_4->instruction_parameters[1].p=graph_2;
	graph_4->instruction_parameters[2].p=graph_3;

	graph_5=g_instruction_2 (GRESULT1,graph_4,NULL);
	graph_6=g_instruction_2 (GRESULT0,graph_4,NULL);
	graph_5->instruction_parameters[1].p=graph_6;
	graph_6->instruction_parameters[1].p=graph_5;

	s_put_b (1,graph_5);
	s_put_b (0,graph_6);
}
#endif

#ifndef M68000
void code_subIo (VOID)
{
	code_operatorIo (GSUB_O);
}
#endif

void code_subR (VOID)
{
#ifdef G_A64
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6,graph_7;

	graph_1=s_pop_b();
	graph_2=g_fp_arg (graph_1);

	graph_3=s_get_b (0);
	graph_4=g_fp_arg (graph_3);

	graph_5=g_fsub (graph_4,graph_2);

	graph_6=g_fromf (graph_5);

	s_put_b (0,graph_6);
#else
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6,graph_7,graph_8,graph_9;

# ifdef M68000	
	if (!mc68881_flag){
		if (sub_real==NULL)
			sub_real=enter_label ("sub_real",IMPORT_LABEL);
		code_dyadic_sane_operator (sub_real);
		init_b_stack (2,r_vector);
	} else {
# endif
		graph_1=s_pop_b();
		graph_2=s_pop_b();
		graph_3=g_fjoin (graph_1,graph_2);
	
		graph_4=s_get_b (0);
		graph_5=s_get_b (1);
		graph_6=g_fjoin (graph_4,graph_5);
	
		graph_7=g_fsub (graph_6,graph_3);

		g_fhighlow (graph_8,graph_9,graph_7);

		s_put_b (1,graph_9);
		s_put_b (0,graph_8);
# ifdef M68000
	}
# endif
#endif
}

void code_tanR (VOID)
{
#ifdef M68000
	if (!mc68881_flag){
#endif
		if (tan_real==NULL)
			tan_real=enter_label ("tan_real",IMPORT_LABEL);
		code_monadic_sane_operator (tan_real);
		init_b_stack (SIZE_OF_REAL_IN_STACK_ELEMENTS,r_vector);
#ifdef M68000
	} else
		code_monadic_real_operator (GFTAN);
#endif
}

void code_testcaf (char *label_name)
{
	LABEL *label;
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	label=enter_label (label_name,0);

	graph_1=g_lea (label);
	graph_2=g_load_id (0,graph_1);
	
	s_push_b (graph_2);	
}

void code_truncateR (VOID)
{
	if (truncate_real_label==NULL)
		truncate_real_label=enter_label ("truncate_real",IMPORT_LABEL);

#ifdef G_A64
	s_push_b (s_get_b (0));
	s_put_b (1,NULL);
	insert_basic_block (JSR_BLOCK,0,1+1,r_vector,truncate_real_label);
#else
	s_push_b (s_get_b (0));
	s_put_b (1,s_get_b (2));
	s_put_b (2,NULL);

	insert_basic_block (JSR_BLOCK,0,2+1,r_vector,truncate_real_label);
#endif

	init_b_stack (1,i_vector);
}

void code_update_a (int a_offset_1,int a_offset_2)
{
	if (a_offset_1!=a_offset_2){
		INSTRUCTION_GRAPH graph_1;
		
		graph_1=s_get_a (a_offset_1);
		s_put_a (a_offset_2,graph_1);
	}
}

void code_updatepop_a (int a_offset_1,int a_offset_2)
{
	code_update_a (a_offset_1,a_offset_2);
	code_pop_a (a_offset_2);
}

void code_update_b (int b_offset_1,int b_offset_2)
{
	if (b_offset_1!=b_offset_2){
		INSTRUCTION_GRAPH graph_1;
		
		graph_1=s_get_b (b_offset_1);
		s_put_b (b_offset_2,graph_1);
	}
}

void code_updatepop_b (int b_offset_1,int b_offset_2)
{
	code_update_b (b_offset_1,b_offset_2);
	code_pop_b (b_offset_2);
}

static void code_lazy_update (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	
	graph_1=s_pop_a();
	graph_2=s_get_a (0);
	graph_3=s_pop_b();

	if (!check_index_flag && graph_3->instruction_code==GLOAD_I &&
		LESS_UNSIGNED (graph_3->instruction_parameters[0].i,(MAX_INDIRECT_OFFSET-ARRAY_ELEMENTS_OFFSET)>>STACK_ELEMENT_LOG_SIZE))
	{
		graph_4=g_store_x (graph_2,graph_1,ARRAY_ELEMENTS_OFFSET+(graph_3->instruction_parameters[0].i<<STACK_ELEMENT_LOG_SIZE),0,NULL);
	} else {
		if (check_index_flag)
			graph_3=g_bounds (graph_1,graph_3);

#if defined (M68000) || defined (I486) || defined (ARM)
# ifdef M68000
		if (mc68000_flag){
			graph_3=g_lsl (g_load_i (2),graph_3);
			graph_4=g_store_x (graph_2,graph_1,ARRAY_ELEMENTS_OFFSET,0,graph_3);
		} else
# endif
		{
			int offset;

			graph_3=optimize_array_index (ARRAY_ELEMENTS_OFFSET,STACK_ELEMENT_LOG_SIZE,graph_3,&offset);
			graph_4=g_store_x (graph_2,graph_1,offset,STACK_ELEMENT_LOG_SIZE,graph_3);
		}
#else
		graph_3=g_lsl_2_add_12 (graph_3);
		graph_4=g_store_x (graph_2,graph_1,0,0,graph_3);
#endif
	}
	
	s_put_a (0,graph_4);
}

static void code_updateBC (int offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	
	graph_1=s_get_a (0);
	graph_2=s_pop_b();
	graph_3=s_pop_b();

	if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
		LESS_UNSIGNED (graph_2->instruction_parameters[0].i,MAX_INDIRECT_OFFSET-offset))
	{
		graph_4=g_store_b_x (graph_3,graph_1,offset+graph_2->instruction_parameters[0].i,NULL);
	} else {
		if (check_index_flag)
			graph_2=g_bounds (graph_1,graph_2);

#if defined (M68000) || defined (I486) || defined (ARM)
		{
		int new_offset;

		graph_2=optimize_array_index (offset,0,graph_2,&new_offset);
		graph_4=g_store_b_x (graph_3,graph_1,new_offset,graph_2);
		}
#else
		graph_2=char_or_bool_array_offset (offset,graph_2);
		graph_4=g_store_b_x (graph_3,graph_1,0,graph_2);
#endif
	}
	
	s_put_a (0,graph_4);
}

static void code_updateI (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	
	graph_1=s_get_a (0);
	graph_2=s_pop_b();
	graph_3=s_pop_b();

#ifdef ARRAY_OPTIMIZATIONS
	if (graph_1->instruction_code==GCREATE && graph_2->instruction_code==GLOAD_I){
		int i;
		
		i=graph_2->instruction_parameters[0].i;
		if (LESS_UNSIGNED (i,4) && 3+i < graph_1->inode_arity){
			graph_1->instruction_parameters[3+i].p = graph_3;
			return;
		}
	}
#endif

	if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
		LESS_UNSIGNED (graph_2->instruction_parameters[0].i,(MAX_INDIRECT_OFFSET-ARRAY_ELEMENTS_OFFSET)>>STACK_ELEMENT_LOG_SIZE))
	{
		graph_4=g_store_x (graph_3,graph_1,ARRAY_ELEMENTS_OFFSET+(graph_2->instruction_parameters[0].i<<STACK_ELEMENT_LOG_SIZE),0,NULL);
	} else {
		if (check_index_flag)
			graph_2=g_bounds (graph_1,graph_2);

#if defined (M68000) || defined (I486) || defined (ARM)
# ifdef M68000
		if (mc68000_flag){
			graph_2=g_lsl (g_load_i (2),graph_2);
			graph_4=g_store_x (graph_3,graph_1,ARRAY_ELEMENTS_OFFSET,0,graph_2);
		} else
# endif
		{
			int offset;

			graph_2=optimize_array_index (ARRAY_ELEMENTS_OFFSET,STACK_ELEMENT_LOG_SIZE,graph_2,&offset);
			graph_4=g_store_x (graph_3,graph_1,offset,STACK_ELEMENT_LOG_SIZE,graph_2);
		}
#else
		graph_2=g_lsl_2_add_12 (graph_2);
		graph_4=g_store_x (graph_3,graph_1,0,0,graph_2);
#endif
	}
	
	s_put_a (0,graph_4);
}

#ifdef G_A64
static void code_updateI32 (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4;
	
	graph_1=s_get_a (0);
	graph_2=s_pop_b();
	graph_3=s_pop_b();

	if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
		LESS_UNSIGNED (graph_2->instruction_parameters[0].i,(MAX_INDIRECT_OFFSET-ARRAY_ELEMENTS_OFFSET)>>2))
	{
		graph_4=g_store_x (graph_3,graph_1,ARRAY_ELEMENTS_OFFSET+(graph_2->instruction_parameters[0].i<<2),0,NULL);
	} else {
		int offset;

		if (check_index_flag)
			graph_2=g_bounds (graph_1,graph_2);

		graph_2=optimize_array_index (ARRAY_ELEMENTS_OFFSET,2,graph_2,&offset);
		graph_4=g_store_s_x (graph_3,graph_1,offset,2,graph_2);
	}
	
	s_put_a (0,graph_4);
}
#endif

static void code_updateR (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_5,graph_6,graph_7,graph_8;
	
	graph_1=s_get_a (0);
	graph_2=s_pop_b();	

	graph_3=s_pop_b();
#ifndef G_A64
	graph_4=s_pop_b();
#endif

	if (check_index_flag)
		graph_2=g_bounds (graph_1,graph_2);

#ifdef M68000
	if (!mc68881_flag){
		if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
			LESS_UNSIGNED (graph_2->instruction_parameters[0].i,(MAX_INDIRECT_OFFSET-16)>>3))
		{
			int offset;
			
			offset=REAL_ARRAY_ELEMENTS_OFFSET+(graph_2->instruction_parameters[0].i<<3);
			graph_7=g_store_x (graph_3,graph_1,offset,0,NULL);
			graph_8=g_store_x (graph_4,graph_7,offset+4,0,NULL);
		} else {
			if (mc68000_flag){
				graph_5=g_load_i (3);
				graph_6=g_lsl (graph_5,graph_2);
				graph_7=g_store_x (graph_3,graph_1,REAL_ARRAY_ELEMENTS_OFFSET,0,graph_6);
				graph_8=g_store_x (graph_4,graph_7,REAL_ARRAY_ELEMENTS_OFFSET+4,0,graph_6);
			} else {
				graph_7=g_store_x (graph_3,graph_1,REAL_ARRAY_ELEMENTS_OFFSET,3,graph_2);
				graph_8=g_store_x (graph_4,graph_7,REAL_ARRAY_ELEMENTS_OFFSET+4,3,graph_2);		
			}
		}
	} else
#endif
	{
#ifdef G_A64
		graph_7=g_fp_arg (graph_3);
#else
		graph_7=g_fjoin (graph_3,graph_4);
#endif
		if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
			LESS_UNSIGNED (graph_2->instruction_parameters[0].i,(MAX_INDIRECT_OFFSET-REAL_ARRAY_ELEMENTS_OFFSET)>>3))
		{
			graph_8=g_fstore_x (graph_7,graph_1,REAL_ARRAY_ELEMENTS_OFFSET+(graph_2->instruction_parameters[0].i<<3),0,NULL);
		} else {
#if defined (M68000) || defined (I486) || defined (ARM)
			int offset;

			graph_2=optimize_array_index (REAL_ARRAY_ELEMENTS_OFFSET,3,graph_2,&offset);
			graph_8=g_fstore_x (graph_7,graph_1,offset,3,graph_2);
#else
			graph_2=g_lsl_3_add_12 (graph_2);
# if defined (sparc) && !defined (ALIGN_REAL_ARRAYS)
			graph_8=g_fstore_x (graph_7,graph_1,REAL_ARRAY_ELEMENTS_OFFSET,0,graph_2);
# else
			graph_8=g_fstore_x (graph_7,graph_1,0,0,graph_2);
# endif
#endif
		}
#ifdef ALIGN_REAL_ARRAYS
		graph_8->inode_arity |= LOAD_STORE_ALIGNED_REAL;
#endif
	}

	s_put_a (0,graph_8);
}

#if defined (I486) || defined (ARM)
static void code_updateR32 (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_4,graph_7,graph_8;
	
	graph_1=s_get_a (0);
	graph_2=s_pop_b();	
	graph_3=s_pop_b();
# ifndef G_A64
	graph_4=s_pop_b();
# endif

	if (check_index_flag)
		graph_2=g_bounds (graph_1,graph_2);

# ifdef G_A64
	graph_7=g_fp_arg (graph_3);
# else
	graph_7=g_fjoin (graph_3,graph_4);
# endif

	if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
		LESS_UNSIGNED (graph_2->instruction_parameters[0].i,(MAX_INDIRECT_OFFSET-REAL_ARRAY_ELEMENTS_OFFSET)>>2))
	{
		graph_8=g_fstore_s_x (graph_7,graph_1,REAL_ARRAY_ELEMENTS_OFFSET+(graph_2->instruction_parameters[0].i<<2),0,NULL);
	} else {
		int offset;

		graph_2=optimize_array_index (REAL_ARRAY_ELEMENTS_OFFSET,2,graph_2,&offset);
		graph_8=g_fstore_s_x (graph_7,graph_1,offset,2,graph_2);
	}

	s_put_a (0,graph_8);
}
#endif

static int equal_graph (INSTRUCTION_GRAPH graph_0,INSTRUCTION_GRAPH graph_1)
{
	if (graph_0==graph_1)
		return 1;
	
	if (graph_0->instruction_code==graph_1->instruction_code){
		switch (graph_0->instruction_code){
			case GADD:
			case GLSL:
				return		equal_graph (graph_0->instruction_parameters[0].p,graph_1->instruction_parameters[0].p)
						&&	equal_graph (graph_0->instruction_parameters[1].p,graph_1->instruction_parameters[1].p);
			case GLOAD_I:
				return graph_0->instruction_parameters[0].i==graph_1->instruction_parameters[0].i;
		}
	}
	
	return 0;
}

static void code_r_update (int a_size,int b_size)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3,graph_7;
	int i,element_size,offset;
	
	graph_1=s_pop_a();
	graph_2=s_pop_b();
	
	element_size=(a_size+b_size)<<STACK_ELEMENT_LOG_SIZE;
	
	if (!check_index_flag && graph_2->instruction_code==GLOAD_I &&
		LESS_UNSIGNED (graph_2->instruction_parameters[0].i,(MAX_INDIRECT_OFFSET-ARRAY_ELEMENTS_OFFSET-(element_size-STACK_ELEMENT_SIZE))/element_size))
	{
		offset=ARRAY_ELEMENTS_OFFSET+graph_2->instruction_parameters[0].i*element_size;
		graph_3=NULL;
	} else {
		INSTRUCTION_GRAPH select_graph;

		if (check_index_flag)
			graph_2=g_bounds (graph_1,graph_2);

		offset=3<<STACK_ELEMENT_LOG_SIZE;
		graph_3=multiply_by_constant (element_size,graph_2);

#if defined (sparc) || defined (G_POWER)
		graph_3=g_add (graph_1,graph_3);	
#endif

		select_graph=load_indexed_list;
		
		while (select_graph!=NULL){
			if (select_graph->instruction_code==GLOAD_X || select_graph->instruction_code==GFLOAD_X){
				if (select_graph->instruction_parameters[0].p==graph_1){
					INSTRUCTION_GRAPH graph_4;

					graph_4=select_graph->instruction_parameters[2].p;		
					if (graph_4!=NULL && equal_graph (graph_4,graph_3)){
						graph_3=graph_4;
						break;
					}
				}
			}
			select_graph=select_graph->instruction_parameters[3].p;
		}
	}

	graph_7=graph_1;

	for (i=0; i<a_size; ++i){
		INSTRUCTION_GRAPH graph_4;
		
		graph_4=s_pop_a();
		graph_1=g_store_x (graph_4,graph_1,offset+(i<<STACK_ELEMENT_LOG_SIZE),0,graph_3);
	}

	for (i=0; i<b_size; ++i){
		INSTRUCTION_GRAPH graph_4;
		
		graph_4=s_pop_b();
		
#ifdef G_A64
		if (graph_4->instruction_code==GFROMF){
			INSTRUCTION_GRAPH graph_5;

			graph_5=g_fp_arg (graph_4);
# if defined (sparc) || defined (G_POWER)
			if (offset+((a_size+i)<<STACK_ELEMENT_LOG_SIZE)!=0 && graph_3!=NULL)
				graph_1=g_fstore_x (graph_5,graph_1,0,0,g_add (g_load_i (offset+((a_size+i)<<STACK_ELEMENT_LOG_SIZE)),graph_3));
			else
# endif
			graph_1=g_fstore_x (graph_5,graph_1,offset+((a_size+i)<<STACK_ELEMENT_LOG_SIZE),0,graph_3);

			continue;
		}		
#else
		if (graph_4->instruction_code==GFHIGH && i+1<b_size){
			INSTRUCTION_GRAPH graph_5,graph_6;
			
			graph_5=s_get_b (0);
			if (graph_5->instruction_code==GFLOW && graph_4->instruction_parameters[0].p==graph_5->instruction_parameters[0].p){
				s_pop_b();
				
				graph_6=g_fjoin (graph_4,graph_5);

				if (! (	graph_6->instruction_code==GFLOAD_X &&
						graph_6->instruction_parameters[0].p==graph_7 &&
						graph_6->instruction_parameters[1].i==((offset+((a_size+i)<<STACK_ELEMENT_LOG_SIZE))<<2) &&
						graph_6->instruction_parameters[2].p==graph_3))
				{
					graph_1=g_fstore_x (graph_6,graph_1,offset+((a_size+i)<<STACK_ELEMENT_LOG_SIZE),0,graph_3);
				}
				
				++i;
				continue;
			}
		}
#endif

		if (! ( graph_4->instruction_code==GLOAD_X &&
				graph_4->instruction_parameters[0].p==graph_7 &&
				graph_4->instruction_parameters[1].i==((offset+((a_size+i)<<STACK_ELEMENT_LOG_SIZE))<<2) &&
				graph_4->instruction_parameters[2].p==graph_3))
		{
			graph_1=g_store_x (graph_4,graph_1,offset+((a_size+i)<<STACK_ELEMENT_LOG_SIZE),0,graph_3);
		}
	}
	
	s_push_a (graph_1);
}

void code_update (char element_descriptor[],int a_size,int b_size)
{
	if (check_index_flag && index_error_label==NULL){
		index_error_label=enter_label ("index__error",
#if (defined (ARM) && defined (G_A64)) || defined (THUMB)
			FAR_CONDITIONAL_JUMP_LABEL);
#else
			0);
#endif
		if (!(index_error_label->label_flags & EXPORT_LABEL))
			index_error_label->label_flags |= IMPORT_LABEL;
	}

	switch (element_descriptor[0]){
		case 'B':
			if (element_descriptor[1]=='O' && element_descriptor[2]=='O' && element_descriptor[3]=='L' &&
				element_descriptor[4]=='\0')
			{
				code_updateBC (ARRAY_ELEMENTS_OFFSET);
				return;	
			}
			break;
		case 'C':
			if (element_descriptor[1]=='H' && element_descriptor[2]=='A' && element_descriptor[3]=='R' &&
				element_descriptor[4]=='\0')
			{
#ifdef ARRAY_SIZE_BEFORE_DESCRIPTOR
				code_updateBC (STACK_ELEMENT_SIZE);
#else
				code_updateBC (2*STACK_ELEMENT_SIZE);
#endif
				return;	
			}
			break;
		case 'I':
			if (element_descriptor[1]=='N' && element_descriptor[2]=='T'){
				if (element_descriptor[3]=='\0'){
					code_updateI();
					return;
				}
#if defined (G_A64) || defined (I486)
				if (element_descriptor[3]=='3' && element_descriptor[4]=='2' && element_descriptor[5]=='\0'){
# ifdef G_A64
					code_updateI32();
# else
					code_updateI();
# endif
					return;	
				}
#endif
			}
			break;
		case 'P':
			if (is__rocid (element_descriptor)){
				code_updateI();
				return;	
			}
			break;
		case 'R':
			if (element_descriptor[1]=='E' && element_descriptor[2]=='A' && element_descriptor[3]=='L'){
				if (element_descriptor[4]=='\0'){
					code_updateR();
					return;
				}
#if defined (I486) || defined (ARM)
				if (element_descriptor[4]=='3' && element_descriptor[5]=='2' && element_descriptor[6]=='\0'){
					code_updateR32();
					return;
				}				
#endif
			}
			break;
		case 'A':
			if (element_descriptor[1]=='R' && element_descriptor[2]=='R' && element_descriptor[3]=='A' &&
				element_descriptor[4]=='Y' && element_descriptor[5]=='\0')
			{
				code_lazy_update();
				return;	
			}
			break;
		case 'S':
			if (element_descriptor[1]=='T' && element_descriptor[2]=='R' && element_descriptor[3]=='I' &&
				element_descriptor[4]=='N' && element_descriptor[5]=='G' && element_descriptor[6]=='\0')
			{
				code_lazy_update();
				return;	
			}
			break;
		case 'W':
			if (is__orld (element_descriptor)){
				code_lazy_update();
				return;	
			}
			break;
		case '_':
			if (element_descriptor[1]=='_' && element_descriptor[2]=='\0'){
				code_lazy_update();
				return;	
			}
			break;
	}

	code_r_update (a_size,b_size);
}

void code_updateS (int source_offset,int destination_offset)
{
	INSTRUCTION_GRAPH graph_1,graph_2;
	
	if (update_string_label==NULL)
		update_string_label=enter_label ("update_string",IMPORT_LABEL);
	
	graph_1=s_get_a (source_offset);
	graph_2=s_get_a (destination_offset);
	
	s_push_a (graph_2);
	s_push_a (graph_1);

	s_push_b (s_get_b (0));
	s_put_b (1,s_get_b (2));
	s_put_b (2,NULL);
	insert_basic_block (JSR_BLOCK,2,2+1,i_i_vector,update_string_label);
}

void code_xor (VOID)
{
	INSTRUCTION_GRAPH graph_1,graph_2,graph_3;
	
	graph_1=s_pop_b();
	graph_2=s_get_b (0);
	graph_3=g_eor (graph_1,graph_2);
	
	s_put_b (0,graph_3);
}

int system_file;

void code_caf (char *label_name,int a_stack_size,int b_stack_size)
{
	LABEL *label;
	int n_arguments,n;
	
	label=enter_label (label_name,LOCAL_LABEL | DATA_LABEL);
	if (label->label_id>=0)
		error_s ("Label %d defined twice\n",label_name);
	label->label_id=next_label_id++;

#ifdef FUNCTION_LEVEL_LINKING
	as_new_data_module();
	if (assembly_flag)
		w_as_new_data_module();
#endif

	if (a_stack_size>0){
#if defined (GEN_OBJ)
# ifdef G_A64
		store_word64_in_data_section (0);
# else
		store_long_word_in_data_section (0);
# endif
#endif
		if (assembly_flag)
#ifdef G_A64
			w_as_word64_in_data_section ((int_64)0);
#else
			w_as_long_in_data_section (0);
#endif
	}

#ifdef GEN_OBJ
	define_data_label (label);
#endif

	if (assembly_flag){
		w_as_to_data_section();
		w_as_define_label (label);
	}
	
	n_arguments=a_stack_size+b_stack_size;

	for (n=0; n<=n_arguments; ++n){
#if defined (GEN_OBJ)
# ifdef G_A64
		store_word64_in_data_section (0);
# else
		store_long_word_in_data_section (0);
# endif
#endif
		if (assembly_flag)
#ifdef G_A64
			w_as_word64_in_data_section ((int_64)0);
#else
			w_as_long_in_data_section (0);
#endif
	}
}

void code_comp (int version,char *options)
{
#if defined (G_POWER) || defined (I486) || defined (ARM)
	int l;
	
	l=strlen (options);
	
	system_file = l>8 && options[8]=='1';
	no_memory_profiling = system_file && l>3 && options[3]=='1';
# ifdef PROFILE
	no_time_profiling   = system_file && l>5 && options[5]=='1';
	callgraph_profiling = l>13 && options[13]=='1';
# endif
#endif
}

struct dependency_list *first_dependency;
static struct dependency_list *last_dependency;

void code_depend (char *module_name,int module_name_length)
{
#	pragma unused (module_name_length)
	struct dependency_list *new_dependency;
	char *m_name;
	
	m_name=(char*)fast_memory_allocate (strlen (module_name)+1);
	strcpy (m_name,module_name);
	
	new_dependency=fast_memory_allocate_type (struct dependency_list);
	new_dependency->dependency_next=NULL;
	new_dependency->dependency_module_name=m_name;
	
	if (last_dependency==NULL)
		first_dependency=new_dependency;
	else
		last_dependency->dependency_next=new_dependency;
	last_dependency=new_dependency;

#ifdef M68000
	write_depend (module_name);
#endif
}

LABEL *module_label;

static LABEL *enter_descriptor_code_label (char code_label_name[],int arity)
{
	LABEL *code_label;
	
	if (!strcmp (code_label_name,"__add__arg")){
		if (arity-1>MAX_YET_ARGS_NEEDED_ARITY){
			if (yet_args_needed_label==NULL)
				yet_args_needed_label=enter_label ("yet_args_needed",IMPORT_LABEL);
			code_label=yet_args_needed_label;
		} else {
			LABEL **yet_args_needed_label_p;
			
			yet_args_needed_label_p=&yet_args_needed_labels[arity-1];
			if (*yet_args_needed_label_p==NULL){
				char label_name[64];
					
				sprintf (label_name,"yet_args_needed_%d",arity-1);
				*yet_args_needed_label_p=enter_label (label_name,IMPORT_LABEL);
			}
			code_label=*yet_args_needed_label_p;
		}
		code_label_name=code_label->label_name;
	} else
#ifdef THUMB
		code_label=enter_label (code_label_name,THUMB_FUNC_LABEL);
#else
		code_label=enter_label (code_label_name,0);
#endif

	if (code_label->label_id<0)
		code_label->label_id=next_label_id++;

	return code_label;
}

static void write_descriptor_curry_table (int arity,LABEL *code_label)
{
	int n;
	
	for (n=0; n<=arity; ++n){
#ifdef GEN_OBJ
# ifdef NEW_DESCRIPTORS
#  ifdef MACH_O64
		store_2_words_in_data_section (n,(arity-n)<<4);
#  else
#   if defined (G_A64) && defined (LINUX)
		if (pic_flag)
			store_2_words_in_data_section (n,(arity-n)<<4);
		else
#   endif
		store_2_words_in_data_section (n,(arity-n)<<3);
# endif
# else
		store_2_words_in_data_section (n,n<<3);
# endif
#endif
		if (assembly_flag){
			w_as_word_in_data_section (n);
#ifdef NEW_DESCRIPTORS
# ifdef MACH_O64
			w_as_word_in_data_section ((arity-n)<<4);
# else
#  if defined (G_A64) && defined (LINUX)
			if (pic_flag)
				w_as_word_in_data_section ((arity-n)<<4);
			else
#  endif
			w_as_word_in_data_section ((arity-n)<<3);
# endif
#else
			w_as_word_in_data_section (n<<3);
#endif
		}
		
		if (n<arity-1){
			LABEL *add_arg_label;
			
			if (n>MAX_YET_ARGS_NEEDED_ARITY){
				if (yet_args_needed_label==NULL)
					yet_args_needed_label=enter_label ("yet_args_needed",IMPORT_LABEL);
				add_arg_label=yet_args_needed_label;
			} else {
				LABEL **yet_args_needed_label_p;
				
				yet_args_needed_label_p=&yet_args_needed_labels[n];
				add_arg_label=*yet_args_needed_label_p;

				if (add_arg_label==NULL){
					char label_name[64];
					
					sprintf (label_name,"yet_args_needed_%d",n);
					add_arg_label=enter_label (label_name,IMPORT_LABEL);
					*yet_args_needed_label_p=add_arg_label;
				}
			}

			if (add_arg_label->label_id<0)
				add_arg_label->label_id=next_label_id++;

#ifdef GEN_OBJ
# if defined (MACH_O64) || (defined (G_A64) && defined (LINUX))
#  if defined (G_A64) && defined (LINUX)
			if (pic_flag)
#  endif
			store_long_word_in_data_section (0);
# endif
			store_label_in_data_section (add_arg_label);
#endif
			if (assembly_flag){
#ifdef MACH_O64
				w_as_long_in_data_section (0);
#endif
				w_as_label_in_data_section (add_arg_label->label_name);
			}
		} else
			if (n==arity-1){
#ifdef GEN_OBJ
# if defined (MACH_O64) || (defined (G_A64) && defined (LINUX))
#  if defined (G_A64) && defined (LINUX)
				if (pic_flag)
#  endif
				store_long_word_in_data_section (0);
# endif
				store_label_in_data_section (code_label);
#endif
				if (assembly_flag){
#ifdef MACH_O64
					w_as_long_in_data_section (0);
#endif
					w_as_label_in_data_section (code_label->label_name);
				}
			}
	}
}

static void code_descriptor (char label_name[],char node_entry_label_name[],char code_label_name[],LABEL *code_label,
#ifdef NEW_DESCRIPTORS
							int arity,int export_flag,LABEL *string_label,int string_code_label_id)
#else
							int arity,int export_flag,int lazy_record_flag,LABEL *string_label,int string_code_label_id)
#endif
{
	LABEL *label;
	int n;

	label=enter_label (label_name,LOCAL_LABEL | DATA_LABEL | export_flag);

	if (label->label_id>=0)
		error_s ("Label %d defined twice\n",label_name);
	label->label_id=next_label_id++;

	label->label_descriptor=string_label;

#ifdef FUNCTION_LEVEL_LINKING
	as_new_data_module();
	if (assembly_flag)
		w_as_new_data_module();
#endif

#if !defined (NEW_DESCRIPTORS) && !defined (M68000)
	/* not for 68k to maintain long word alignment */
	if (module_info_flag && module_label){
# ifdef GEN_OBJ
		store_label_in_data_section (module_label);
# endif
		if (assembly_flag)
			w_as_label_in_data_section (module_label->label_name);
	}
#endif

	if (!parallel_flag){
#if defined (M68000) && !defined (SUN)
		store_descriptor_in_data_section (label->label_id);
#else
# ifdef GEN_OBJ
		store_descriptor_in_data_section (label);
# endif
#endif
		if (assembly_flag)
			w_as_descriptor_in_data_section (label->label_name);
	}

	if (export_flag!=0)
		enter_label (node_entry_label_name,export_flag);

#ifndef NEW_DESCRIPTORS
# ifdef GEN_OBJ
#  if defined (I486) || defined (ARM)
	store_long_word_in_data_section ((arity<<16) | lazy_record_flag);
#  else
	store_2_words_in_data_section (lazy_record_flag,arity);
#  endif
# endif
	if (assembly_flag){
# if defined (sparc) || defined (I486) || defined (ARM) || defined (G_POWER)
		w_as_word_in_data_section (lazy_record_flag);
# endif
		w_as_word_in_data_section (arity);
	}
#endif

#if ! defined (NO_STRING_ADDRESS_IN_DESCRIPTOR)
# ifdef GEN_OBJ
	store_label_in_data_section (string_label);
# endif
	if (assembly_flag)
		w_as_internal_label_value (string_code_label_id);
#endif

#ifdef GEN_OBJ
	define_data_label (label);
#endif
	if (assembly_flag)
		w_as_define_label (label);

#if defined (G_A64) && defined (LINUX)
	if (pic_flag && label->label_flags & EXPORT_LABEL){
		int n;

		define_exported_data_label_with_offset
			(enter_label_with_extension (label->label_name,"_Z",label->label_flags),ARITY_0_DESCRIPTOR_OFFSET);
	
		for (n=0; n<=arity; ++n){
			static char arity_extension[24];

			sprintf (arity_extension,"_%d",n);
			define_exported_data_label_with_offset
				(enter_label_with_extension (label->label_name,arity_extension,label->label_flags),2+(n<<4));
		}
	}
#endif
}

#ifdef NEW_DESCRIPTORS
static void code_new_descriptor (int arity,int lazy_record_flag)
{
# ifdef GEN_OBJ
	store_2_words_in_data_section (lazy_record_flag,arity);
# endif
	if (assembly_flag){
		w_as_word_in_data_section (lazy_record_flag);
		w_as_word_in_data_section (arity);
	}

	if (module_info_flag && module_label){
# ifdef GEN_OBJ
#  ifdef MACH_O64
		store_label_offset_in_data_section (module_label);
#  else
#   if defined (G_A64) && defined (LINUX)
		if (pic_flag)
			store_label_offset_in_data_section (module_label);
		else
#   endif
		store_label_in_data_section (module_label);
#  endif
# endif
		if (assembly_flag)
# ifdef MACH_O64
			w_as_label_offset_in_data_section (module_label->label_name);
# else
			w_as_label_in_data_section (module_label->label_name);
# endif
	}
}
#endif

void code_desc (char label_name[],char node_entry_label_name[],char *code_label_name,
				int arity,int lazy_record_flag,char descriptor_name[],int descriptor_name_length)
{
	LABEL *string_label,*code_label;
	int string_code_label_id;

#if defined (NO_FUNCTION_NAMES) && defined (NO_CONSTRUCTOR_NAMES)
	descriptor_name_length=0;
#elif defined (NO_FUNCTION_NAMES)
	if (strcmp (code_label_name,"__add__arg")!=0)
		descriptor_name_length=0;
#endif
	
	string_code_label_id=next_label_id++;
	string_label=new_local_label (0
#ifdef G_POWER
									| DATA_LABEL
#endif
	);

	if (arity>0){
		code_label = enter_descriptor_code_label (code_label_name,arity);
		code_label_name=code_label->label_name;
	}

#ifdef NEW_DESCRIPTORS
	code_descriptor (label_name,node_entry_label_name,code_label_name,code_label,arity,0,string_label,string_code_label_id);
#else
	code_descriptor (label_name,node_entry_label_name,code_label_name,code_label,arity,0,lazy_record_flag,string_label,string_code_label_id);
#endif
	
	write_descriptor_curry_table (arity,code_label);

#ifdef NEW_DESCRIPTORS
	code_new_descriptor (arity,lazy_record_flag);
#endif

	w_descriptor_string (descriptor_name,descriptor_name_length,string_code_label_id,string_label);
}

void code_desc0 (char label_name[],int desc0_number,char descriptor_name[],int descriptor_name_length)
{
	LABEL *string_label,*label;
	int string_code_label_id;

#if defined (NO_FUNCTION_NAMES)
	descriptor_name_length=0;
#endif

	string_code_label_id=next_label_id++;
	string_label=new_local_label (0
#ifdef G_POWER
									| DATA_LABEL
#endif
	);

	label=enter_label (label_name,LOCAL_LABEL | DATA_LABEL);

	if (label->label_id>=0)
		error_s ("Label %d defined twice\n",label_name);
	label->label_id=next_label_id++;

	label->label_descriptor=string_label;

#ifdef FUNCTION_LEVEL_LINKING
	as_new_data_module();
	if (assembly_flag)
		w_as_new_data_module();
#endif

#ifdef GEN_OBJ
# ifdef G_A64
	store_word64_in_data_section (desc0_number);
# else
	store_long_word_in_data_section (desc0_number);
# endif
#endif
	if (assembly_flag)
#ifdef G_A64
		w_as_word64_in_data_section ((int_64)desc0_number);
#else
		w_as_long_in_data_section (desc0_number);
#endif

	if (!parallel_flag){
#ifdef GEN_OBJ
		store_descriptor_in_data_section (label);
#endif
		if (assembly_flag)
			w_as_descriptor_in_data_section (label->label_name);
	}
#ifdef GEN_OBJ
	define_data_label (label);
#endif
	if (assembly_flag)
		w_as_define_label (label);

#ifdef GEN_OBJ
	store_2_words_in_data_section (0,0);
#endif
	if (assembly_flag){
		w_as_word_in_data_section (0);
		w_as_word_in_data_section (0);
	}

	code_new_descriptor (0,0);

	w_descriptor_string (descriptor_name,descriptor_name_length,string_code_label_id,string_label);
}

void code_descn (char label_name[],char node_entry_label_name[],int arity,int lazy_record_flag,char descriptor_name[],
				 int descriptor_name_length)
{
	LABEL *string_label;
	int string_code_label_id;

#if defined (NO_FUNCTION_NAMES) || defined (NO_CONSTRUCTOR_NAMES)
	descriptor_name_length=0;
#endif
	
	string_code_label_id=next_label_id++;
	string_label=new_local_label (0
#ifdef G_POWER
									| DATA_LABEL
#endif
	);

#ifdef NEW_DESCRIPTORS
	code_descriptor (label_name,node_entry_label_name,NULL,NULL,0/*arity*/,0,string_label,string_code_label_id);
#else
	code_descriptor (label_name,node_entry_label_name,NULL,NULL,0/*arity*/,0,lazy_record_flag,string_label,string_code_label_id);
#endif

#ifdef GEN_OBJ
	store_2_words_in_data_section (arity,0<<3);
#endif
	if (assembly_flag){
		w_as_word_in_data_section (arity);
		w_as_word_in_data_section (0<<3);
	}

#ifdef NEW_DESCRIPTORS
	code_new_descriptor (0/*arity*/,lazy_record_flag);
#endif

	w_descriptor_string (descriptor_name,descriptor_name_length,string_code_label_id,string_label);
}

void code_descexp (char label_name[],char node_entry_label_name[],char *code_label_name,
					int arity,int lazy_record_flag,char descriptor_name[],int descriptor_name_length)
{
	LABEL *string_label,*code_label;
	int string_code_label_id;

#if defined (NO_FUNCTION_NAMES) && defined (NO_CONSTRUCTOR_NAMES)
	descriptor_name_length=0;
#elif defined (NO_FUNCTION_NAMES)
	if (strcmp (code_label_name,"__add__arg")!=0)
		descriptor_name_length=0;
#endif
	
	string_code_label_id=next_label_id++;
	string_label=new_local_label (0
#ifdef G_POWER
									| DATA_LABEL
#endif
	);

	if (arity>0){
		code_label = enter_descriptor_code_label (code_label_name,arity);
		code_label_name=code_label->label_name;
	}

#ifdef NEW_DESCRIPTORS
	code_descriptor (label_name,node_entry_label_name,code_label_name,code_label,arity,EXPORT_LABEL,string_label,string_code_label_id);
#else
	code_descriptor (label_name,node_entry_label_name,code_label_name,code_label,arity,EXPORT_LABEL,lazy_record_flag,string_label,string_code_label_id);
#endif

	write_descriptor_curry_table (arity,code_label);

#ifdef NEW_DESCRIPTORS
	code_new_descriptor (arity,lazy_record_flag);
#endif

	w_descriptor_string (descriptor_name,descriptor_name_length,string_code_label_id,string_label);
}

#ifdef NEW_DESCRIPTORS
void code_descs (char label_name[],char node_entry_label_name[],char *result_descriptor_name,
				int offset1,int offset2,char descriptor_name[],int descriptor_name_length)
{
	LABEL *string_label,*label;
	int string_code_label_id;

#if defined (NO_FUNCTION_NAMES)
	descriptor_name_length=0;
#endif
	
	string_code_label_id=next_label_id++;
	string_label=new_local_label (0
#ifdef G_POWER
									| DATA_LABEL
#endif
	);

	label=enter_label (label_name,LOCAL_LABEL | DATA_LABEL);

	if (label->label_id>=0)
		error_s ("Label %d defined twice\n",label_name);
	label->label_id=next_label_id++;

	label->label_descriptor=string_label;

#ifdef FUNCTION_LEVEL_LINKING
	as_new_data_module();
	if (assembly_flag)
		w_as_new_data_module();
#endif

	if (! (result_descriptor_name[0]=='_' && result_descriptor_name[1]=='_' && result_descriptor_name[2]=='\0')){
		LABEL *result_descriptor_label;

		result_descriptor_label=enter_label (result_descriptor_name,0);

		if (result_descriptor_label->label_id<0)
			result_descriptor_label->label_id=next_label_id++;

#ifdef GEN_OBJ
		store_descriptor_in_data_section (result_descriptor_label);
#endif
		if (assembly_flag)
			w_as_descriptor_in_data_section (result_descriptor_label->label_name);
	}

#if ! defined (NO_STRING_ADDRESS_IN_DESCRIPTOR)
# ifdef GEN_OBJ
	store_label_in_data_section (string_label);
# endif
	if (assembly_flag)
		w_as_internal_label_value (string_code_label_id);
#endif

#ifdef GEN_OBJ
	define_data_label (label);
#endif
	if (assembly_flag)
		w_as_define_label (label);

#ifdef GEN_OBJ
	store_2_words_in_data_section (0,8);
	store_2_words_in_data_section (offset1<<STACK_ELEMENT_LOG_SIZE,offset2<<STACK_ELEMENT_LOG_SIZE);
	store_2_words_in_data_section (1,0);
#endif
	if (assembly_flag){
		w_as_word_in_data_section (0);
		w_as_word_in_data_section (8);
		w_as_word_in_data_section (offset1<<STACK_ELEMENT_LOG_SIZE);
		w_as_word_in_data_section (offset2<<STACK_ELEMENT_LOG_SIZE);
		w_as_word_in_data_section (1);
		w_as_word_in_data_section (0);
	}

	code_new_descriptor (1,0);

	w_descriptor_string (descriptor_name,descriptor_name_length,string_code_label_id,string_label);
}
#endif

static void code_record_descriptor (LABEL *label,int string_code_label_id,char type[],int a_size,int b_size)
{
	LABEL *string_label;

	string_label=label->label_descriptor;

#ifndef M68000
	/* not for 68k to maintain long word alignment */
	if (module_info_flag && module_label){
# ifdef GEN_OBJ
#  ifdef MACH_O64
		store_label_offset_in_data_section (module_label);
#  else
#   if defined (G_A64) && defined (LINUX)
		if (pic_flag)
			store_label_offset_in_data_section (module_label);
		else
#   endif
		store_label_in_data_section (module_label);
#  endif
# endif
		if (assembly_flag)
# ifdef MACH_O64
			w_as_label_offset_in_data_section (module_label->label_name);
# else
			w_as_label_in_data_section (module_label->label_name);
# endif
	}
#endif

#ifdef GEN_OBJ
#  ifdef MACH_O64
	store_label_offset_in_data_section (string_label);
#  else
	store_label_in_data_section (string_label);
#  endif
#endif
	if (assembly_flag)
#ifdef MACH_O64
		w_as_internal_label_value_offset (string_code_label_id);
#else
		w_as_internal_label_value (string_code_label_id);
#endif

#ifdef GEN_OBJ
	define_data_label (label);
#endif
	if (assembly_flag)
		w_as_define_label (label);

#if defined (G_A64) && defined (LINUX)
	if (pic_flag && label->label_flags & EXPORT_LABEL)
		define_exported_data_label_with_offset (enter_label_with_extension (label->label_name,"_0",label->label_flags),2);
#endif

#ifdef GEN_OBJ
	store_2_words_in_data_section (a_size+b_size+256,a_size);
#endif
	if (assembly_flag){
		w_as_word_in_data_section (a_size+b_size+256);
		w_as_word_in_data_section (a_size);
	}
	
	{
		char *t_p;
		int length;
		
		for (t_p=type; *t_p!='\0'; ++t_p)
			switch (*t_p){
				case 'p':
					*t_p='i';
					break;
				case 'w':
					*t_p='a';
					break;
				default:
					break;
			}
		
		length=t_p-type;

#if defined (GEN_OBJ)
		store_c_string_in_data_section (type,length);
#endif

		if (assembly_flag)
			w_as_c_string_in_data_section (type,length);
	}
}

void code_record (char record_label_name[],char type[],int a_size,int b_size,char record_name[],int record_name_length)
{
	LABEL *label,*string_label;
	int string_code_label_id;

	label=enter_label (record_label_name,LOCAL_LABEL | DATA_LABEL);
	if (label->label_id>=0)
		error_s ("Label %d defined twice\n",record_label_name);
	label->label_id=next_label_id++;

#ifdef FUNCTION_LEVEL_LINKING
	as_new_data_module();
	if (assembly_flag)
		w_as_new_data_module();
#endif

	string_code_label_id=next_label_id++;
	string_label=new_local_label (0
#ifdef G_POWER
									| DATA_LABEL
#endif
	);
	label->label_descriptor=string_label;

	code_record_descriptor (label,string_code_label_id,type,a_size,b_size);

#ifdef NO_CONSTRUCTOR_NAMES
	record_name_length=0;
#endif
	w_descriptor_string (record_name,record_name_length,string_code_label_id,string_label);
}

static int record_end_string_code_label_id;
static LABEL *record_end_string_label;

void code_record_start (char record_label_name[],char type[],int a_size,int b_size)
{
	LABEL *label,*string_label;
	int string_code_label_id;

	label=enter_label (record_label_name,LOCAL_LABEL | DATA_LABEL);
	if (label->label_id>=0)
		error_s ("Label %d defined twice\n",record_label_name);
	label->label_id=next_label_id++;

#ifdef FUNCTION_LEVEL_LINKING
	as_new_data_module();
	if (assembly_flag)
		w_as_new_data_module();
#endif

	string_code_label_id=next_label_id++;
	string_label=new_local_label (0
#ifdef G_POWER
									| DATA_LABEL
#endif
	);
	label->label_descriptor=string_label;

	record_end_string_code_label_id = string_code_label_id;
	record_end_string_label = string_label;

	code_record_descriptor (label,string_code_label_id,type,a_size,b_size);
}

void code_record_descriptor_label (char descriptor_name[])
{
	LABEL *label;

	label=enter_label (descriptor_name,0);

# ifdef GEN_OBJ
	store_label_in_data_section (label);
# endif
	if (assembly_flag)
		w_as_label_in_data_section (label->label_name);
}

void code_record_end (char record_name[],int record_name_length)
{
#ifdef NO_CONSTRUCTOR_NAMES
	record_name_length=0;
#endif
	w_descriptor_string (record_name,record_name_length,record_end_string_code_label_id,record_end_string_label);
}

/*
static void show_vector (int n,unsigned int vector[])
{
	int i;
	for (i=0; i<n; ){
		if (vector[i>>LOG_VECTOR_ELEMENT_SIZE] & (((ULONG)1) << (i & VECTOR_ELEMENT_MASK))){
			printf ("R");
			i+=2;
		} else {
			printf ("I");
			i+=1;
		}
	}
	printf ("\n");
}
*/

void code_d (int da,int db,ULONG vector[])
{
	demanded_a_stack_size=da;
	demanded_b_stack_size=db;
	demanded_vector=vector;

	demand_flag=1;	
	/* show_vector (db,vector); */
}

void code_export (char *label_name)
{
	enter_label (label_name,EXPORT_LABEL);
}

#if defined (G_A64) && defined (LINUX)
extern char **sl_mods;
static int pic_sl_mod_import;
#endif

void code_impdesc (char *label_name)
{
	enter_label (label_name,
#if defined (G_A64) && defined (LINUX)
				 !pic_sl_mod_import ? IMPORT_LABEL | DATA_LABEL | USE_GOT_LABEL : IMPORT_LABEL | DATA_LABEL);
#else
				 IMPORT_LABEL | DATA_LABEL);
#endif
}

void code_implab_node_entry (char *label_name,char *ea_label_name)
{
	if (ea_label_name!=NULL){
		LABEL *ea_label,*node_label;

		node_label=enter_label (label_name,
#if defined (G_A64) && defined (LINUX)
								!pic_sl_mod_import ? IMPORT_LABEL | EA_LABEL | USE_GOT_LABEL : IMPORT_LABEL | EA_LABEL);
#else
								IMPORT_LABEL | EA_LABEL);
#endif

		if (ea_label_name[0]=='_' && ea_label_name[1]=='_' && ea_label_name[2]=='\0'){
			if (eval_fill_label==NULL)
				eval_fill_label=enter_label ("eval_fill",
#if defined (G_AI64) && defined (LINUX)
												rts_got_flag ? (IMPORT_LABEL | USE_GOT_LABEL) :
#endif
												IMPORT_LABEL);
			node_label->label_ea_label=eval_fill_label;
		} else {
			ea_label=enter_label (ea_label_name,0);
			node_label->label_ea_label=ea_label;
		}
	}
}

void code_implab (char *label_name)
{
#if defined (G_A64) && defined (LINUX)
	if (!pic_sl_mod_import)
		enter_label (label_name,IMPORT_LABEL | USE_GOT_LABEL);
#endif
/*	enter_label (label_name,IMPORT_LABEL); */
}

void code_impmod (char *module_name)
{
#if defined (G_AI64) && defined (LINUX)
	if (pic_flag){
		if (!rts_got_flag){
			pic_sl_mod_import = 1;	
		} else {
			char **sl_mod;
			
			for (sl_mod=sl_mods; *sl_mod!=NULL; ++sl_mod){
				if (!strcmp (module_name,*sl_mod)){
					pic_sl_mod_import = 1;
					return;
				}
			}
			pic_sl_mod_import = 0;
		}
	}
#endif
}

void code_o (int oa,int ob,ULONG vector[])
{
	offered_a_stack_size=oa;
	offered_b_stack_size=ob;
	offered_vector=vector;
	
	/* show_vector (ob,vector); */
	
	if (!offered_after_jsr)
		offered_before_label=1;
	else {
		offered_after_jsr=0;

		release_a_stack();
		release_b_stack();

#ifdef MORE_PARAMETER_REGISTERS
		init_ab_stack (offered_a_stack_size,offered_b_stack_size,offered_vector);
#else		
		init_a_stack (offered_a_stack_size);
		init_b_stack (offered_b_stack_size,offered_vector);
#endif
	}
}

struct profile_table {
	LABEL *label;
	int string_length;
	struct profile_table *next;
	char string[4];
};

static struct profile_table *profile_table,**profile_table_next_p;

void code_pb (char string[],int string_length)
{
#ifdef PROFILE
	if (no_time_profiling)
		return;

	if (profile_s_label==NULL){
		profile_l_label =enter_label ("profile_l",IMPORT_LABEL);
		profile_l2_label=enter_label ("profile_l2",IMPORT_LABEL);
		profile_n_label =enter_label ("profile_n",IMPORT_LABEL);
		profile_n2_label=enter_label ("profile_n2",IMPORT_LABEL);
		profile_s_label =enter_label ("profile_s",IMPORT_LABEL);
		profile_s2_label=enter_label ("profile_s2",IMPORT_LABEL);
		profile_r_label =enter_label ("profile_r",IMPORT_LABEL);
		profile_t_label =enter_label ("profile_t",IMPORT_LABEL);
# if defined (G_POWER) || (defined (ARM) && !defined (G_A64))
		profile_ti_label=enter_label ("profile_ti",IMPORT_LABEL);
# endif
	}

	profile_function_label=new_local_label (LOCAL_LABEL | DATA_LABEL);
	profile_function_block=NULL;

# if defined (G_POWER) && defined (PROFILE)
	if (profile_table_flag){
		struct profile_table *profile_table_entry;
		int string_length_4;
		
		if (profile_table_label==NULL)
			profile_table_label=profile_function_label;

		string_length_4=(string_length+1+3) & -4;
		profile_function_label->label_arity=profile_table_offset;

		profile_table_entry=(struct profile_table *)fast_memory_allocate (sizeof (struct profile_table)-4+string_length_4);
		
		profile_table_entry->label=profile_function_label;
		profile_table_entry->string_length=string_length;
		strcpy (profile_table_entry->string,string);
		
		profile_table_entry->next=NULL;
		*profile_table_next_p=profile_table_entry;
		profile_table_next_p=&profile_table_entry->next;

		if (module_label!=NULL)
			profile_table_offset+=4;

		profile_table_offset+=4+string_length_4;
		
		if (profile_table_offset>=65536)
			error ("Profile table too big\n");

		return;
	}
# endif

# ifdef FUNCTION_LEVEL_LINKING
	as_new_data_module();
	if (assembly_flag)
		w_as_new_data_module();
# endif

	if (callgraph_profiling){
		store_long_word_in_data_section (0);
		if (assembly_flag)
			w_as_long_in_data_section (0);
	}

# ifdef GEN_OBJ
#  if !(defined (ARM) && defined (G_A64))
	if (module_label!=NULL){
#   ifdef MACH_O64
		store_label_offset_in_data_section (module_label);
#   else
#    if defined (G_A64) && defined (LINUX)
		if (pic_flag)
			store_label_offset_in_data_section (module_label);
		else
#    endif
		store_label_in_data_section (module_label);
#   endif
	}
#  endif

	define_data_label (profile_function_label);
	if (!callgraph_profiling)
#  ifdef G_A64
		store_word64_in_data_section (0);
#  else
		store_long_word_in_data_section (0);
#  endif

#  if defined (ARM) && defined (G_A64)
	if (module_label!=NULL){
		if (pic_flag)
			store_label_offset_in_data_section (module_label);
		else
			store_label_in_data_section (module_label);
	}
#  endif

	store_c_string_in_data_section (string,string_length);
# endif

	if (assembly_flag){
# ifdef M68000
		w_as_to_data_section();
		if (module_label!=NULL)
			w_as_label_in_data_section (module_label->label_name);
		w_as_define_label (profile_function_label);
# else
#  if !(defined (ARM) && defined (G_A64))
		if (module_label!=NULL)
#   ifdef MACH_O64
			w_as_label_offset_in_data_section (module_label->label_name);
#   else
			w_as_label_in_data_section (module_label->label_name);
#   endif
#  endif

		w_as_define_data_label (profile_function_label->label_number);
# endif

		if (!callgraph_profiling)
# ifdef G_A64
			w_as_word64_in_data_section ((int_64)0);
# else
			w_as_long_in_data_section (0);
# endif

# if defined (ARM) && defined (G_A64)
		if (module_label!=NULL)
			w_as_label_in_data_section (module_label->label_name);
# endif

		w_as_c_string_in_data_section (string,string_length);
	}
#endif
}

#if defined (G_POWER) && defined (PROFILE)
void write_profile_table (void)
{
	struct profile_table *profile_table_entry;
	int string_length_4;
	
# ifdef FUNCTION_LEVEL_LINKING
	as_new_data_module();
	if (assembly_flag)
		w_as_new_data_module();
# endif

	for_l (profile_table_entry,profile_table,next){
		char *string;
		int string_length;
		LABEL *profile_function_label;
		
		profile_function_label=profile_table_entry->label;
		string_length=profile_table_entry->string_length;
		string=profile_table_entry->string;
		
		if (module_label!=NULL){
#ifdef GEN_OBJ
# ifdef MACH_O64
			store_label_offset_in_data_section (module_label);
# else
#  if defined (G_A64) && defined (LINUX)
			if (pic_flag)
				store_label_offset_in_data_section (module_label);
			else
#  endif
			store_label_in_data_section (module_label);
# endif
#endif
		}

#ifdef GEN_OBJ
		define_data_label (profile_function_label);
		store_long_word_in_data_section (0);
		store_c_string_in_data_section (string,string_length);
#endif
	
		if (assembly_flag){
#ifdef M68000
			w_as_to_data_section();
			if (module_label!=NULL)
				w_as_label_in_data_section (module_label->label_name);
			w_as_define_label (profile_function_label);
#else
			if (module_label!=NULL)
# ifdef MACH_O64
				w_as_label_offset_in_data_section (module_label->label_name);
# else
				w_as_label_in_data_section (module_label->label_name);
# endif
			w_as_define_data_label (profile_function_label->label_number);
#endif
			w_as_long_in_data_section (0);
			w_as_c_string_in_data_section (string,string_length);
		}
	}
	
	profile_table=NULL;
}
#endif

void code_start (char *label_name)
{
	if (strcmp ("__nostart__",label_name)==0)
		return;

	code_o (0,0,e_vector);
#if defined (SOLARIS) || defined (LINUX_ELF) || defined (MACH_O64) || defined (ARM)
	code_label ("__start");
	code_export ("__start");
#else
	code_label ("_start");
	code_export ("_start");
#endif

#if defined (M68000) && defined (SUN)
	{
		char reloc_label_name[128];
		LABEL *label;
		
		strcpy (reloc_label_name,"re_");
		strcat (reloc_label_name,this_module_name);
		
		label=enter_label (reloc_label_name,LOCAL_LABEL);
		end_basic_block_with_registers (0,0,e_vector);
		
#if defined (sparc)
		i_sub_i_r (4,B_STACK_POINTER);
#endif
		i_jsr_l (label,0);
		
		begin_new_basic_block();
	}
#endif
	code_jmp (label_name);
}

static LABEL *code_string_or_module (char label_name[],char string[],int string_length)
{
	LABEL *label;

	label=enter_label (label_name,LOCAL_LABEL
#ifdef G_POWER
								  | DATA_LABEL | STRING_LABEL
#endif
	);

	if (label->label_id>=0)
		error_s ("Label %d defined twice\n",label_name);
	label->label_id=next_label_id++;

#ifdef FUNCTION_LEVEL_LINKING
	as_new_data_module();
	if (assembly_flag)
		w_as_new_data_module();
#endif

#ifdef GEN_OBJ
	define_data_label (label);
	store_abc_string_in_data_section (string,string_length);
#endif
	if (assembly_flag)
		w_as_abc_string_and_label_in_data_section (string,string_length,label_name);

	return label;
}

#ifdef G_A64
static LABEL *code_string_or_module4 (char label_name[],char string[],int string_length)
{
	LABEL *label;

	label=enter_label (label_name,LOCAL_LABEL
# ifdef G_POWER
								  | DATA_LABEL | STRING_LABEL
# endif
	);

	if (label->label_id>=0)
		error_s ("Label %d defined twice\n",label_name);
	label->label_id=next_label_id++;

# ifdef FUNCTION_LEVEL_LINKING
	as_new_data_module();
	if (assembly_flag)
		w_as_new_data_module();
# endif

# ifdef GEN_OBJ
	define_data_label (label);
	store_abc_string4_in_data_section (string,string_length);
# endif
	
	if (assembly_flag)
		w_as_abc_string_and_label_in_data_section (string,string_length,label_name);

	return label;
}
#endif

void code_string (char label_name[],char string[],int string_length)
{
#ifdef G_A64
	code_string_or_module4 (label_name,string,string_length);
#else
	code_string_or_module (label_name,string,string_length);
#endif
}

void code_module (char label_name[],char string[],int string_length)
{	
#ifdef G_A64
	module_label=code_string_or_module4 (label_name,string,string_length);
#else
	module_label=code_string_or_module (label_name,string,string_length);
#endif
#ifdef PROFILE
	if (callgraph_profiling){
		store_long_word_in_data_section (0);
		if (assembly_flag)
			w_as_long_in_data_section (0);
	}
#endif
}

void code_label (char *label_name)
{
	struct block_label *new_label;
	LABEL *label;
	int begin_module;
	
	label=enter_label (label_name,LOCAL_LABEL);
	
	new_label=fast_memory_allocate_type (struct block_label);
	new_label->block_label_label=label;
	new_label->block_label_next=NULL;
		
	if (!offered_before_label){
		begin_module=0;
		
		if (!(label->label_flags & REGISTERS_ALLOCATED)){
			if (reachable){
				label->label_a_stack_size=get_a_stack_size();
				label->label_vector=&label->label_small_vector;
				label->label_b_stack_size=get_b_stack_size (&label->label_vector);
			} else {
				label->label_a_stack_size=0;
				label->label_b_stack_size=0;
				label->label_vector=e_vector;
			}
			label->label_flags |= REGISTERS_ALLOCATED;
		}
	} else {
		begin_module=1;
		
		offered_before_label=0;

		label->label_a_stack_size=offered_a_stack_size;
		label->label_b_stack_size=offered_b_stack_size;

#ifdef G_POWER
		label->label_flags |= REGISTERS_ALLOCATED | DOT_O_BEFORE_LABEL;
#else
		label->label_flags |= REGISTERS_ALLOCATED;
#endif
		if (offered_b_stack_size<=VECTOR_ELEMENT_SIZE){
			label->label_vector=&label->label_small_vector;
			label->label_small_vector=*offered_vector;
		} else {
			int vector_size;
			ULONG *vector,*old_vector;
			
			vector_size=(offered_b_stack_size+VECTOR_ELEMENT_SIZE-1)>>LOG_VECTOR_ELEMENT_SIZE;
			vector=(ULONG*)fast_memory_allocate (vector_size * sizeof (ULONG));
			label->label_vector=vector;
			old_vector=offered_vector;
			while (vector_size>0){
				*vector++=*old_vector++;
				--vector_size;
			}
		}
	}

	if (reachable)
		end_basic_block_with_registers (label->label_a_stack_size,label->label_b_stack_size,label->label_vector);
	else
		generate_code_for_previous_blocks (0);

#ifdef PROFILE
	if (begin_module && reachable && profile_function_label!=NULL && profile_flag!=PROFILE_NOT)

		if (! (last_block->block_instructions==NULL &&
			   last_block->block_profile==profile_flag && last_block->block_profile_function_label==profile_function_label))

			i_jmp_l_profile (label,profile_offset);
#endif

	if (last_block->block_instructions!=NULL){
		begin_new_basic_block();
		
		if (begin_module){
			last_block->block_begin_module=1;
			last_block->block_link_module=reachable;
			
			if (profile_function_label!=NULL && profile_flag!=PROFILE_NOT){
				last_block->block_profile=profile_flag;
				last_block->block_profile_function_label=profile_function_label;
				profile_function_block=last_block;
			}
		}
	} else {
		release_a_stack();
		release_b_stack();
		
		if (begin_module){
			if (!last_block->block_begin_module){
				last_block->block_begin_module=1;
				last_block->block_link_module=reachable;
			}

			if (profile_function_label!=NULL && profile_flag!=PROFILE_NOT){
				last_block->block_profile=profile_flag;
				last_block->block_profile_function_label=profile_function_label;
				profile_function_block=last_block;
			}
		}
	}

	profile_flag=PROFILE_NORMAL;

	reachable=1;

#ifdef MORE_PARAMETER_REGISTERS
	init_ab_stack (label->label_a_stack_size,label->label_b_stack_size,label->label_vector);
#else
	init_a_stack (label->label_a_stack_size);	
	init_b_stack (label->label_b_stack_size,label->label_vector);
#endif	

	if (last_block->block_labels==NULL)
		last_block->block_labels=new_label;
	else
		last_block_label->block_label_next=new_label;
	last_block_label=new_label;
}

void code_newlocallabel (char *label_name)
{
	struct label_node **label_p,*new_label;

	new_label=fast_memory_allocate_type (struct label_node);
	new_label->label_node_label.label_flags=0;
	new_label->label_node_label.label_number=next_label++;
	new_label->label_node_label.label_id=next_label++;
	new_label->label_node_label.label_last_lea_block=NULL;

	label_p=&labels;
	while (*label_p!=NULL){
		struct label_node *label;
		int r;
		
		label=*label_p;
		r=strcmp (label_name,label->label_node_label.label_name);
		if (r==0){
			new_label->label_node_left=label->label_node_left;
			new_label->label_node_right=label->label_node_right;
			new_label->label_node_label.label_name=label->label_node_label.label_name;
			
			*label_p=new_label;
			return;
		}
		if (r<0)
			label_p=&label->label_node_left;
		else
			label_p=&label->label_node_right;
	}
	
	new_label->label_node_left=NULL;
	new_label->label_node_right=NULL;

	new_label->label_node_label.label_name=(char*)fast_memory_allocate (strlen (label_name)+1);
	strcpy (new_label->label_node_label.label_name,label_name);
	
	*label_p=new_label;
}

#if 0
static void show_labels (struct block_label *labels)
{
	for (; labels!=NULL; labels=labels->block_label_next)
		if (labels->block_label_label->label_number!=0)
			printf ("L%d\n",labels->block_label_label->label_number);
		else
			printf ("%s:\n",labels->block_label_label->label_name);
}

void show_code (VOID)
{
	struct basic_block *block;

	for (block=first_block; block!=NULL; block=block->block_next){
		printf ("%d %d %d\n",block->block_n_new_heap_cells,block->block_n_begin_a_parameter_registers,
							 block->block_n_begin_d_parameter_registers);
		show_labels (block->block_labels);
		show_instructions (block->block_instructions);
		
		printf ("\n");
	}
}

static void show_import_and_export_labels (struct label_node *label_node)
{
	LABEL *label;
	
	if (label_node==NULL)
		return;
	
	label=&label_node->label_node_label;
	if (!(label->label_flags & LOCAL_LABEL) && label->label_number==0)
		printf ("IMPORT %s\n",label->label_name);
	if (label->label_flags & EXPORT_LABEL && label->label_number==0)
		printf ("EXPORT %s\n",label->label_name);
		
	show_import_and_export_labels (label_node->label_node_left);
	show_import_and_export_labels (label_node->label_node_right);
}

void show_imports_and_exports (VOID)
{
	show_import_and_export_labels (labels);
}
#endif

void initialize_coding (VOID)
{
	int n;
	
	last_INT_descriptor_block=NULL;
	last_BOOL_descriptor_block=NULL;
	last_CHAR_descriptor_block=NULL;
	last_REAL_descriptor_block=NULL;
	last_FILE_descriptor_block=NULL;
	last__STRING__descriptor_block=NULL;

	last_instruction=NULL;
	first_block=allocate_empty_basic_block();
	first_block->block_link_module=0;
	last_block=first_block;
		
	demand_flag=0;
	offered_after_jsr=0;
	offered_before_label=0;
	reachable=0;
	
	next_label=1;
	next_label_id=0;
	eval_label_number=0;
	
	labels=NULL;
	local_labels=NULL;
	last_instruction=NULL;

	INT_label=BOOL_label=CHAR_label=REAL_label=FILE_label=_STRING__label=_ARRAY__label=NULL;
#if defined (G_AI64) && defined (LINUX)
	_STRING__0_label=NULL;
	pic_sl_mod_import=!rts_got_flag;
#endif

	halt_label=cat_string_label=NULL;
	cmp_string_label=eqD_label=NULL;
	slice_string_label=D_to_S_label=NULL;
	print_label=print_sc_label=print_symbol_label=print_symbol_sc_label=NULL;
	update_string_label=equal_string_label=cycle_in_spine_label=NULL;
	entier_real_label=truncate_real_label=ceiling_real_label=NULL;
	yet_args_needed_label=string_to_string_node_label=NULL;
	int_array_to_node_label=real_array_to_node_label=NULL;
	repl_args_b_label=push_arg_b_label=del_args_label=printD_label=reserve_label=NULL;
	suspend_label=stop_reducer_label=new_int_reducer_label=new_ext_reducer_label=NULL;
	send_graph_label=send_request_label=copy_graph_label=create_channel_label=NULL;
	newP_label=ItoP_label=channelP_label=currentP_label=randomP_label=NULL;
	CHANNEL_label=EMPTY_label=system_sp_label=NULL;

	print_char_label=print_int_label=print_real_label=NULL;

	print_r_arg_label=NULL;
	push_t_r_args_label=NULL;
	repl_r_a_args_n_a_label=NULL;

	create_array_label=NULL;
	create_arrayB_label=create_arrayC_label=create_arrayI_label=create_arrayR_label=create_r_array_label=NULL;
	create_arrayB__label=create_arrayC__label=create_arrayI__label=create_arrayR__label=create_r_array__label=NULL;
	push_a_r_args_label=index_error_label=NULL;

#if defined (G_A64) || defined (I486)
	create_arrayI32_label=create_arrayR32_label=create_arrayI32__label=create_arrayR32__label=NULL;
#endif

	small_integers_label=static_characters_label=NULL;

	eval_fill_label=NULL;
	for (n=0; n<=32; ++n)
		eval_upd_labels[n]=NULL;

#ifdef NEW_APPLY
	for (n=0; n<=32; ++n)
		add_empty_node_labels[n]=NULL;
#endif

	for (n=0; n<=MAX_YET_ARGS_NEEDED_ARITY; ++n)
		yet_args_needed_labels[n]=NULL;

#ifdef M68000
	if (!mc68881_flag){
		add_real=sub_real=mul_real=div_real=eq_real=gt_real=lt_real=NULL;
		i_to_r_real=r_to_i_real=NULL;
		exp_real=ln_real=log10_real=NULL;
		cos_real=neg_real=sin_real=tan_real=acos_real=asin_real=atan_real=NULL;
	}
#else
	exp_real=ln_real=log10_real=r_to_i_real=NULL;
	cos_real=sin_real=tan_real=acos_real=asin_real=atan_real=NULL;
#endif
	pow_real=NULL;

#if defined (M68000) || defined (G_POWER)
	sqrt_real=NULL;
#endif

#ifdef G_POWER
	r_to_i_buffer_label=NULL;
#endif
	
	collect_0_label=enter_label ("collect_0",IMPORT_LABEL);
	collect_1_label=enter_label ("collect_1",IMPORT_LABEL);
	collect_2_label=enter_label ("collect_2",IMPORT_LABEL);
#if !(defined (I486) && !defined (G_AI64))
	collect_3_label=enter_label ("collect_3",IMPORT_LABEL);
#endif
#if defined (I486) && defined (GEN_OBJ) && !defined (G_AI64)
	collect_0l_label=enter_label ("collect_0l",IMPORT_LABEL);
	collect_1l_label=enter_label ("collect_1l",IMPORT_LABEL);
	collect_2l_label=enter_label ("collect_2l",IMPORT_LABEL);
# ifndef THREAD32
	end_heap_label=enter_label ("end_heap",IMPORT_LABEL);
# endif
#endif
#ifdef G_POWER
	collect_00_label=enter_label ("collect_00",IMPORT_LABEL);
	collect_01_label=enter_label ("collect_01",IMPORT_LABEL);
	collect_02_label=enter_label ("collect_02",IMPORT_LABEL);
	collect_03_label=enter_label ("collect_03",IMPORT_LABEL);

	eval_01_label=enter_label ("eval_01",IMPORT_LABEL);
	eval_11_label=enter_label ("eval_11",IMPORT_LABEL);
	eval_02_label=enter_label ("eval_02",IMPORT_LABEL);
	eval_12_label=enter_label ("eval_12",IMPORT_LABEL);
	eval_22_label=enter_label ("eval_22",IMPORT_LABEL);
#endif
	
#if defined (M68000) || defined (ARM)
	div_label=mod_label=NULL;
#endif
#if defined (ARM) && !defined (G_A64)
	udiv_label=ludiv_label=NULL;
#endif
#ifdef M68000
	mul_label=NULL;
#endif
	
	first_dependency=NULL;
	last_dependency=NULL;

#ifdef INDEX_CSE
	n_lsl_2_add_12_cache=0;
	n_lsl_3_add_12_cache=0;
	block_in_lsl_2_add_12_cache=NULL;
	block_in_lsl_3_add_12_cache=NULL;
	n_lsl_2_cache=0;
	n_lsl_3_cache=0;
	block_in_lsl_2_cache=NULL;
	block_in_lsl_3_cache=NULL;
#endif

#ifdef SIN_COS_CSE
	block_in_cos_cache=NULL;
	block_in_sin_cache=NULL;
#endif

	module_label=NULL;
#if defined (G_POWER) && defined (PROFILE)
	profile_table_label=NULL;
	profile_table_offset=0;
#endif
#ifdef PROFILE
	profile_offset=PROFILE_OFFSET;
#endif
#ifdef G_POWER
	if (profile_table_flag){
		profile_table=NULL;
		profile_table_next_p=&profile_table;
# ifdef PROFILE
		profile_offset+=4;
# endif
	}
#endif
	
	init_cginstructions();
}
