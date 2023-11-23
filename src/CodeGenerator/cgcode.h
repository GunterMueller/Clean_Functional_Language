
#ifndef G_A64
#define g_fhighlow(gh,gl,gf) \
	(gh)=g_instruction_2 (GFHIGH,(gf),NULL); \
	(gl)=g_instruction_2 (GFLOW,(gf),(gh)); \
	(gh)->instruction_parameters[1].p=(gl)
#endif

extern void initialize_coding (VOID);
extern void show_code (VOID);
extern void show_imports_and_exports (VOID);

extern INSTRUCTION_GRAPH g_load (int offset,int stack);
#ifdef G_A64
extern INSTRUCTION_GRAPH g_fp_arg (INSTRUCTION_GRAPH graph_1);
#else
extern INSTRUCTION_GRAPH g_fjoin (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2);
#endif
extern INSTRUCTION_GRAPH g_fregister (int float_reg);
extern INSTRUCTION_GRAPH g_fstore (int offset,int reg_1,INSTRUCTION_GRAPH graph_1,
#ifdef G_A64
									INSTRUCTION_GRAPH graph_2);
#else
									INSTRUCTION_GRAPH graph_2,INSTRUCTION_GRAPH graph_3);
#endif
extern INSTRUCTION_GRAPH g_fstore_r (int reg_1,INSTRUCTION_GRAPH graph_1);
extern INSTRUCTION_GRAPH g_store (int offset,int reg_1,INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2);
extern INSTRUCTION_GRAPH g_store_r (int reg_1,INSTRUCTION_GRAPH graph_1);
extern INSTRUCTION_GRAPH g_register (int reg);
extern INSTRUCTION_GRAPH g_fload (int offset,int stack);
extern INSTRUCTION_GRAPH g_instruction_1 (int instruction_code,INSTRUCTION_GRAPH graph_1);
extern INSTRUCTION_GRAPH g_instruction_2 (int instruction_code,INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2);
extern INSTRUCTION_GRAPH g_new_node (int,int,int);
extern INSTRUCTION_GRAPH g_create_unboxed_int_array (int n_elements);

#ifdef G_A64
# define g_fromf(g1) g_instruction_1(GFROMF,(g1))
# define g_tof(g1) g_instruction_1(GTOF,(g1))
#endif

extern LABEL *enter_label (char *label_name,int label_flags);
extern LABEL *new_local_label (int label_flags);

extern int next_label_id;
extern struct basic_block *first_block;
extern struct label_node *labels;
extern struct local_label *local_labels;
extern struct dependency_list *first_dependency;
extern LABEL
	*collect_0_label,*collect_1_label,*collect_2_label,
#if !(defined (I486) && !defined (G_AI64))
	*collect_3_label,
#endif
#ifdef I486
	*collect_0l_label,*collect_1l_label,*collect_2l_label,*end_heap_label,
#endif
#ifdef G_POWER
	*collect_00_label,*collect_01_label,*collect_02_label,*collect_03_label,
	*eval_01_label,*eval_11_label,*eval_02_label,*eval_12_label,*eval_22_label,
#endif
	*EMPTY_label;
#if defined (G_POWER) || defined (I486) || defined (ARM)
extern LABEL
	*profile_l_label,*profile_l2_label,*profile_n_label,*profile_n2_label,
	*profile_s_label,*profile_s2_label,*profile_r_label,*profile_t_label;
# if defined (G_POWER) || (defined (ARM) && !defined (G_A64))
extern LABEL *profile_ti_label;
# endif
#endif
extern INSTRUCTION_GRAPH load_indexed_list;

extern int no_memory_profiling;
extern int callgraph_profiling;

#define PROFILE_NOT 0
#define PROFILE_NORMAL 1
#define PROFILE_DOUBLE 2
#define PROFILE_TAIL 3
#define PROFILE_CURRIED 4
#define PROFILE_CURRIED_DOUBLE 5

extern LABEL *_STRING__label;
extern LABEL*copy_graph_label,*CHANNEL_label,*create_channel_label,*currentP_label,*newP_label,
			*randomP_label,*suspend_label;
extern struct block_label *last_block_label;
extern LABEL *profile_table_label;

extern void write_profile_table (void);
