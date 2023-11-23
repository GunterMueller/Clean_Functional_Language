
extern void optimize_jumps (VOID);
extern void optimize_stack_access (struct basic_block *block,int *a_offset_p,int *b_offset_p
# ifdef ARM
	,int try_adjust_b_stack_pointer
# endif
	);
extern int do_register_allocation
	(struct instruction *last_instruction,struct basic_block *basic_block,
	 int highest_a_register,int highest_d_register,int highest_f_register,
	 int not_alter_condition_codes_flag,int condition);
#ifdef G_POWER
void optimize_heap_pointer_increment (struct basic_block *block,int offset_from_heap_register);
#endif
