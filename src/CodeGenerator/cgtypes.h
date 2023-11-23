
#ifdef I486
# undef MORE_PARAMETER_REGISTERS
#endif

#define NODE_POINTER_OFFSET 0

typedef struct label {
	char *		label_name;
	WORD		label_number;
	WORD		label_flags;
	WORD		label_a_stack_size;
	WORD		label_b_stack_size;
#ifdef FUNCTION_LEVEL_LINKING
	union {
	ULONG *							u_vector;
# define		label_vector		label_u.u_vector
	struct object_label *			u_object_label;
# define		label_object_label	label_u.u_object_label
	}			label_u;
#else
	ULONG *		label_vector;
#endif
	union {
		ULONG						u0_small_vector;
# define		label_small_vector	label_u0.u0_small_vector
		ULONG						u0_offset;
# define		label_offset		label_u0.u0_offset
	}			label_u0;
	WORD		label_id;
	WORD		label_arity;
	struct label *label_descriptor;
	union {
		struct instruction_node *	u_last_lea; /* for descriptors */
		struct label *				u_ea_label;	/* for node entry labels */
	} label_u1;
	union {
		struct basic_block *		u_last_lea_block;	/* cgcode.c */
		struct basic_block *		u_block;			/* cgopt.c */
#ifdef G_POWER
		struct toc_label *			u_toc_labels;		/* cgpwas.c */
#endif
#if defined (G_A64) && defined (LINUX)
		struct label *				u_got_jump_label;	/* cgaas.c */
#endif
#ifdef ARM
		struct literal_entry *		u_literal_entry;	/* cgarmas.c */
#endif
	} label_u2;
	WORD						label_last_lea_arity;
} LABEL;

#define label_last_lea_block label_u2.u_last_lea_block
#define label_block label_u2.u_block
#ifdef G_POWER
# define label_toc_labels label_u2.u_toc_labels
#endif
#if defined (G_A64) && defined (LINUX)
# define label_got_jump_label label_u2.u_got_jump_label
#endif
#ifdef ARM
# define label_literal_entry label_u2.u_literal_entry
#endif

#define label_last_lea label_u1.u_last_lea
#define label_ea_label label_u1.u_ea_label

#define IMPORT_LABEL		1
#define EXPORT_LABEL		2
#define LOCAL_LABEL			4
#define REGISTERS_ALLOCATED	8
#define DATA_LABEL			16
#define NODE_ENTRY_LABEL	32
#define DEFERED_LABEL		64
#define EA_LABEL			128
#ifdef G_POWER
#	define HAS_TOC_LABELS		256
#	define FAR_CONDITIONAL_JUMP_LABEL	512
#	define STRING_LABEL			1024
#	define DOT_O_BEFORE_LABEL	2048
#	define STUB_GENERATED		4096
#endif
#if defined (G_A64) && defined (LINUX)
# define USE_PLT_LABEL			4096
#endif
#ifdef ARM
#	define HAS_LITERAL_ENTRY	256
#   define C_ENTRY_LABEL	    512
#endif
#if (defined (ARM) && defined (G_A64)) || defined (THUMB)
#	define FAR_CONDITIONAL_JUMP_LABEL	1024
#endif
#ifdef THUMB
#	define THUMB_FUNC_LABEL		2048
#endif
#define CMP_BRANCH_BLOCK_LABEL	8192
#if defined (G_A64) && defined (LINUX)
# define USE_GOT_LABEL			16384
# define HAS_GOT_JUMP_LABEL		32768
#endif

struct label_node {
	struct label_node *	label_node_left;
	struct label_node *	label_node_right;
	LABEL				label_node_label;
};

struct local_label {
	struct local_label *local_label_next;
	struct label		local_label_label;
};

#if defined (I486) || defined (ARM)
struct reg {
	WORD r;
	UWORD u;
};
#else
struct reg {
	UWORD u;
	WORD r;
};
#endif

struct index_registers {
	struct reg a_reg;
	struct reg d_reg;
};

#ifndef G_A64
# define imm i
#endif

struct parameter {
	char parameter_type;
	char parameter_flags;
	short parameter_offset;
	union parameter_data {
		LONG i;
#ifdef G_A64
		int_64 imm;
#endif
		LABEL *l;
		DOUBLE *r;
		struct reg reg;
		struct index_registers *ir;
	} parameter_data;
};

#ifdef G_POWER
#	define NO_MTLR 16
#	define NO_MFLR 32
#endif

struct instruction {
	struct instruction *	instruction_next;
	struct instruction *	instruction_prev;
	WORD					instruction_icode;
	WORD					instruction_arity;
	struct parameter		instruction_parameters[VARIABLE_ARRAY_SIZE];
};

#ifdef __cplusplus
	union instruction_parameter {
		struct instruction_node *	p;
		LABEL *						l;
		LONG						i;
	};
#endif

struct instruction_node {
	WORD						instruction_code;
	WORD						inode_arity;
	WORD						node_count;
	WORD						instruction_d_min_a_cost;
	WORD 						u_aregs;
	WORD						u_dregs;
	WORD						i_aregs;
	WORD						i_dregs;
	UBYTE						node_mark;
	UBYTE						order_mode; 
	UBYTE						order_alterable;
	UBYTE						order_left;
	union instruction_parameter
#ifndef __cplusplus
	{
		struct instruction_node *	p;
		LABEL *						l;
		LONG						i;
# ifdef G_A64
		int_64						imm;
# endif
	}
#endif
	instruction_parameters[VARIABLE_ARRAY_SIZE];
};

typedef struct instruction_node INSTRUCTION_NODE,*INSTRUCTION_GRAPH;

struct block_label {
	struct block_label *	block_label_next;
	LABEL *					block_label_label;
};

struct basic_block {
	struct basic_block *		block_next;
	struct instruction *		block_instructions;
	struct instruction *		block_last_instruction;
	struct block_label *		block_labels;
	int							block_n_new_heap_cells;
	WORD						block_n_begin_a_parameter_registers;
	WORD						block_n_begin_d_parameter_registers;
	WORD						block_n_node_arguments;	/* <0 if no .n directive */
#ifdef SEPARATE_A_AND_B_STACK_OVERFLOW_CHECKS
	WORD						block_a_stack_check_size;
	WORD						block_b_stack_check_size;
#else
	WORD						block_stack_check_size;
#endif
	unsigned int				block_begin_module:1,
								block_link_module:1
#ifdef G_POWER
								,block_gc_kind:3
	/*	0						return address in lr before and after call
		1						return address in r0 before and in lr after call
		2						return address in lr before and in r0 after call
		3						return address in r0 before and after call
	*/
#endif
								,block_profile:3;
	struct label *				block_descriptor;	/* if .n directive */
	struct label *				block_ea_label;		/* if .n directive */
	struct label *				block_profile_function_label;
};

struct block_graph {
	struct block_graph *	block_graph_previous;
	struct block_graph *	block_graph_next;
	struct basic_block *	block_graph_block;
	
	WORD					block_graph_begin_a_stack_size;
	WORD					block_graph_begin_b_stack_size;
	WORD					block_graph_end_a_stack_size;
	WORD					block_graph_end_b_stack_size;
	ULONG *					block_graph_end_stack_vector;
	ULONG					block_graph_small_end_stack_vector;
	
	struct a_stack *		block_graph_a_stack;
	WORD					block_graph_a_stack_top_offset;
	WORD					block_graph_a_stack_begin_displacement;
	WORD					block_graph_a_stack_end_displacement;
	WORD					block_graph_used_a_stack_elements;
	
	struct b_stack *		block_graph_b_stack;
	WORD					block_graph_b_stack_top_offset;
	WORD					block_graph_b_stack_begin_displacement;
	WORD					block_graph_b_stack_end_displacement;
	WORD					block_graph_used_b_stack_elements;
	
	INSTRUCTION_GRAPH		block_graph_a_register_parameter_node[N_ADDRESS_PARAMETER_REGISTERS];
	INSTRUCTION_GRAPH		block_graph_d_register_parameter_node[N_DATA_PARAMETER_REGISTERS
#ifdef MORE_PARAMETER_REGISTERS
																	+ N_ADDRESS_PARAMETER_REGISTERS
#endif
																];
	INSTRUCTION_GRAPH		block_graph_f_register_parameter_node[N_FLOAT_PARAMETER_REGISTERS];
	
	WORD					block_graph_kind;
	WORD					block_graph_jsr_eval_offset;
	LABEL *					block_graph_last_instruction_label;
#ifdef SEPARATE_A_AND_B_STACK_OVERFLOW_CHECKS
	WORD					block_graph_a_stack_displacement;
	WORD					block_graph_b_stack_displacement;
#else
	WORD					block_graph_stack_displacement;
#endif
};

struct dependency_list {
	struct dependency_list *	dependency_next;
	char *						dependency_module_name;
};

#ifndef sparc
struct relocatable_words_list {
	struct relocatable_words_list *	relocatable_next;
	char *							relocatable_label_name;
};
#else
struct relocatable_longs_list {
	struct relocatable_longs_list *	relocatable_next;
	char *							relocatable_label_name;
	int								relocatable_arity;
};
#endif
