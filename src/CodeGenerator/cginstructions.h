extern INSTRUCTION_GRAPH g_new_node (int instruction_code,int arity,int arg_size);
extern INSTRUCTION_GRAPH g_instruction_1 (int instruction_code,INSTRUCTION_GRAPH graph_1);
extern INSTRUCTION_GRAPH g_instruction_2 (int instruction_code,INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2);
extern INSTRUCTION_GRAPH g_instruction_2_0 (int instruction_code,INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2);
extern INSTRUCTION_GRAPH g_test_o (INSTRUCTION_GRAPH graph_1);
extern INSTRUCTION_GRAPH g_allocate (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2,int n);
extern INSTRUCTION_GRAPH g_before (INSTRUCTION_GRAPH graph_1,int n);
extern INSTRUCTION_GRAPH g_copy (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2);
extern INSTRUCTION_GRAPH g_create_1 (INSTRUCTION_GRAPH graph_1);
extern INSTRUCTION_GRAPH g_create_2 (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2);
extern INSTRUCTION_GRAPH g_create_3 (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2,INSTRUCTION_GRAPH graph_3);
extern INSTRUCTION_GRAPH g_create_m (int arity);
extern INSTRUCTION_GRAPH g_create_r (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2);
extern INSTRUCTION_GRAPH g_exit_if (LABEL *label,INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2);
extern INSTRUCTION_GRAPH g_fill_2  (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2);
extern INSTRUCTION_GRAPH g_fill_3 (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2,INSTRUCTION_GRAPH graph_3);
extern INSTRUCTION_GRAPH g_fill_4 (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2,INSTRUCTION_GRAPH graph_3,INSTRUCTION_GRAPH graph_4);
extern INSTRUCTION_GRAPH g_fill_m (INSTRUCTION_GRAPH graph_1,int arity);
extern INSTRUCTION_GRAPH g_fill_r (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2,INSTRUCTION_GRAPH graph_3);
extern INSTRUCTION_GRAPH g_fjoin (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2);
extern INSTRUCTION_GRAPH g_fload (int offset,int stack);
extern INSTRUCTION_GRAPH g_fload_i (DOUBLE v);
extern INSTRUCTION_GRAPH g_fload_id (int offset,INSTRUCTION_GRAPH graph_1);
extern INSTRUCTION_GRAPH g_fload_x (INSTRUCTION_GRAPH graph_1,int offset,int shift,INSTRUCTION_GRAPH graph_2);
#if defined (I486) || defined (ARM)
extern INSTRUCTION_GRAPH g_fload_s_x (INSTRUCTION_GRAPH graph_1,int offset,int shift,INSTRUCTION_GRAPH graph_2);
#endif
extern INSTRUCTION_GRAPH g_lea (LABEL *label);
extern INSTRUCTION_GRAPH g_lea_i (LABEL *label,int offset);
extern INSTRUCTION_GRAPH g_load (int offset,int stack);
extern INSTRUCTION_GRAPH g_load_i (CleanInt value);
extern INSTRUCTION_GRAPH g_load_id (int offset,INSTRUCTION_GRAPH graph_1);
extern INSTRUCTION_GRAPH g_load_b_x (INSTRUCTION_GRAPH graph_1,int offset,int sign_extend,INSTRUCTION_GRAPH graph_2);
extern INSTRUCTION_GRAPH g_load_x (INSTRUCTION_GRAPH graph_1,int offset,int shift,INSTRUCTION_GRAPH graph_2);
extern INSTRUCTION_GRAPH g_load_b_id (int offset,INSTRUCTION_GRAPH graph_1);
extern INSTRUCTION_GRAPH g_load_des_i (LABEL *descriptor_label,int arity);
extern INSTRUCTION_GRAPH g_load_des_id (int offset,INSTRUCTION_GRAPH graph_1);
#ifdef G_A64
extern INSTRUCTION_GRAPH g_load_s_x (INSTRUCTION_GRAPH graph_1,int offset,int shift,INSTRUCTION_GRAPH graph_2);
#endif
extern INSTRUCTION_GRAPH g_load_sqb_id (int offset,INSTRUCTION_GRAPH graph_1);
extern INSTRUCTION_GRAPH g_movem (int offset,INSTRUCTION_GRAPH graph_1,int n);
extern INSTRUCTION_GRAPH g_movemi (int number,INSTRUCTION_GRAPH movem_graph);
extern INSTRUCTION_GRAPH g_fregister (int float_reg);
extern INSTRUCTION_GRAPH g_fstore_x (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2,int offset,int shift,INSTRUCTION_GRAPH graph_3);
#if defined (I486) || defined (ARM)
extern INSTRUCTION_GRAPH g_fstore_s_x (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2,int offset,int shift,INSTRUCTION_GRAPH graph_3);
#endif
extern INSTRUCTION_GRAPH g_g_register (int reg);
extern INSTRUCTION_GRAPH g_register (int reg);
extern INSTRUCTION_GRAPH g_store (int offset,int reg_1,INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2);
extern INSTRUCTION_GRAPH g_store_b_x (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2,int offset,INSTRUCTION_GRAPH graph_3);
#ifdef G_A64
extern INSTRUCTION_GRAPH g_store_s_x (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2,int offset,int shift,INSTRUCTION_GRAPH graph_3);
#endif
extern INSTRUCTION_GRAPH g_store_x (INSTRUCTION_GRAPH graph_1,INSTRUCTION_GRAPH graph_2,int offset,int shift,INSTRUCTION_GRAPH graph_3);
extern INSTRUCTION_GRAPH g_store_r (int reg_1,INSTRUCTION_GRAPH graph_1);

extern LABEL *w_code_descriptor_length_and_string (char *string,int length);
extern LABEL *w_code_string (char *string,int length);
extern LABEL *w_code_length_and_string (char *string,int length);
extern void w_descriptor_string (char *string,int length,int string_code_label_id,LABEL *string_label);

extern void init_cginstructions (void);

extern LABEL	*realloc_0_label,*realloc_1_label,*realloc_2_label,*realloc_3_label,
				*schedule_0_label,*schedule_1_label,*schedule_2_label,*schedule_3_label,
				*schedule_eval_label,*stack_overflow_label;

#ifdef SEPARATE_A_AND_B_STACK_OVERFLOW_CHECKS
extern LABEL	*end_a_stack_label,*end_b_stack_label;
#endif

