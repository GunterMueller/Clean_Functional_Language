
#define VECTOR_ELEMENT_SIZE 32
#define VECTOR_ELEMENT_MASK 31
#define LOG_VECTOR_ELEMENT_SIZE 5

#define test_bit(v,b) ((v)[(b)>>5] & (((ULONG)1) << ((b) & 31)))
#define clear_bit(v,b) (v)[(b)>>5] &= ~(((ULONG)1) << ((b) & 31))
#define set_bit(v,b) (v)[(b)>>5] |= (((ULONG)1) << ((b) & 31))

extern INSTRUCTION_GRAPH s_get_b (int offset);
extern INSTRUCTION_GRAPH s_get_a (int offset);
extern INSTRUCTION_GRAPH s_pop_a (VOID);
extern INSTRUCTION_GRAPH s_pop_b (VOID);
extern void s_put_b (int offset,INSTRUCTION_GRAPH graph);
extern void s_put_a (int offset,INSTRUCTION_GRAPH graph);
extern void s_push_a (INSTRUCTION_GRAPH graph);
extern void s_push_b (INSTRUCTION_GRAPH graph);
extern void s_remove_a (VOID);
extern void s_remove_b (VOID);

extern void initialize_stacks (VOID);
extern void init_a_stack (int a_stack_size);
extern void init_b_stack (int b_stack_size,ULONG vector[]);
#ifdef MORE_PARAMETER_REGISTERS
void init_ab_stack (int a_stack_size,int b_stack_size,ULONG vector[]);
#endif
extern int get_a_stack_size (VOID);
extern int get_b_stack_size (ULONG *vector_p[]);
extern void release_a_stack (VOID);
extern void release_b_stack (VOID);
extern void insert_graph_in_b_stack (INSTRUCTION_GRAPH graph,int b_stack_size,ULONG *vector);

extern struct basic_block *allocate_empty_basic_block (VOID);
extern void generate_code_for_previous_blocks (int jmp_jsr_or_rtn_flag);
extern void begin_new_basic_block (VOID);
extern void insert_basic_block	(int block_graph_kind,int a_stack_size,int b_stack_size,ULONG *vector_p,LABEL *label);
extern void insert_basic_block_with_extra_parameters_on_stack (int block_graph_kind,int a_stack_size,int b_stack_size,
											ULONG *vector_p,int extra_a_stack_size,int extra_b_stack_size,LABEL *label);
void insert_basic_JSR_I_block (int a_stack_size,int b_stack_size,ULONG *vector_p,int offset);
extern void adjust_stack_pointers (VOID);
extern void end_basic_block_with_registers (int n_a_parameters,int n_b_parameters,ULONG vector[]);
#if defined (I486) || defined (ARM)
extern int end_basic_block_with_registers_and_return_address_and_return_b_stack_offset
	(int n_a_parameters,int n_b_parameters,ULONG vector[],int n_data_parameter_registers);
#endif
extern int end_basic_block_with_registers_and_return_b_stack_offset
	(int n_a_parameters,int n_b_parameters,ULONG vector[],int n_adress_parameter_registers);
extern void end_stack_elements (int n_a_parameters,int n_b_parameters,ULONG vector[]);
extern int adjust_stack_pointers_without_altering_condition_codes (int float_condition,int condition);
extern void linearize_stack_graphs (VOID);

extern INSTRUCTION_GRAPH search_and_remove_graph_from_b_stack (INSTRUCTION_GRAPH calculate_with_overflow_graph);
extern void linearize_stack_graphs_with_overflow_test (INSTRUCTION_GRAPH test_overflow_graph,INSTRUCTION_GRAPH store_calculate_with_overflow_graph);

extern struct block_graph global_block;
