
void show_instructions (struct instruction *instructions);
void initialize_linearization (VOID);
void evaluate_arguments_and_free_addresses (union instruction_parameter arguments[],int n_arguments);
void get_n_virtual_registers (int *n_virtual_a_regs_p,int *n_virtual_d_regs_p,int *n_virtual_f_regs_p);
void calculate_and_linearize_branch_false (LABEL *label,INSTRUCTION_GRAPH graph);
void calculate_and_linearize_branch_true (LABEL *label,INSTRUCTION_GRAPH graph);
void linearize_branch (char condition,LABEL *label);
void calculate_and_linearize_graph (INSTRUCTION_GRAPH graph);

void free_all_aregisters (VOID);
void free_all_dregisters (VOID);
void free_all_fregisters (VOID);
void allocate_aregister (int aregister);
void allocate_dregister (int dregister);
void allocate_fregister (int fregister);
#ifdef M68000
	void instruction_pd (int instruction_code,int register_1);
#endif
void i_jmp_l (LABEL *label,int n_a_registers);
void i_jmp_id (int offset_1,int register_1,int n_a_registers);
#if defined (M68000) || defined (I486)
	void i_jsr_id (int offset,int register_1,int n_a_registers);
	void i_jsr_l (LABEL *label,int n_a_registers);
#else
	void i_jsr_l_id (LABEL *label,int offset);
#endif
#ifdef I486
	void i_jsr_r (int register_1);
#endif
#if ! (defined (sparc) || defined (G_POWER))
	void i_rts (void);
# if defined (I486) || defined (ARM)
	void i_rts_i (int offset);
# endif
# if defined (I486) || defined (ARM)
	void i_rts_profile (void);
	void i_jmp_r (int a_reg);
	void i_jmp_r_profile (int a_reg);
	void i_jmp_l_profile (LABEL *label,int offset);
	void i_jmp_id_profile (int offset_1,int register_1,int n_a_registers);
# endif
#else
# ifndef ARM
		void i_jsr_id_id (int offset_1,int register_1,int offset_2);
# endif
	void i_rts (int offset_1,int offset_2);
# ifdef G_POWER
		void i_rts_c (void);
		void i_rts_r (int register1,int offset_1);
		void i_rts_r_profile (int register1,int offset_1);
		void i_jmp_l_profile (LABEL *label,int offset);
		void i_jmp_id_profile (int offset_1,int register_1,int n_a_registers);
		void i_rts_profile (int offset_1,int offset_2);
# endif
#endif
#if defined (G_POWER) || defined (ARM)
	void i_jsr_id_idu (int offset_1,int register_1,int offset_2);
	void i_jsr_l_idu (LABEL *label,int offset);
#endif
#if defined (ARM)
	void i_jsr_r_idu (int register_1,int offset);
#endif
#if defined (sparc) || defined (ARM)
	void i_call_l (LABEL *label);
	void i_call_r (int register_1);
#elif defined (G_POWER)
	void i_call_l (LABEL *label,int frame_size);
	void i_call_r (int register_1,int frame_size);
#endif
void i_beq_l (LABEL *label);
#ifdef M68000
	extern LONG *i_bmi_i (VOID);
	void i_bmi_l (LABEL *label);
#endif
#if defined (G_POWER) || defined (ARM) || defined (G_AI64)
	void i_and_i_r (LONG value,int register_1);
#endif
#ifdef THUMB
	void i_andi_r_r (LONG value,int register_1,int register_2);
#endif
#if defined (G_POWER) || defined (G_AI64) || defined (ARM)
	void i_or_i_r (LONG value,int register_1);
#endif
#ifdef THUMB
	void i_ori_r_r (LONG value,int register_1,int register_2);
#endif
#ifdef G_POWER
	void i_bnep_l (LABEL *label);
	void i_mtctr (int register_1);
#endif
#if defined (sparc) || defined (I486) || defined (ARM)
	void i_bne_l (LABEL *label);
#endif
#if defined (sparc) || defined (I486) || defined (ARM) || defined (G_POWER)
	void i_btst_i_r (LONG i,int register_1);
#endif
#if defined (I486) || defined (ARM)
	void i_btst_i_id (LONG i,int offset,int register_1);
#endif
#ifdef G_AI64
	void i_exg_r_r (int register_1,int register_2);
#endif
void i_ext_r (int register_1);
#ifdef G_AI64
void i_fcvt2s_id_fr (int offset,int register_1,int register_2);
#endif
void i_fmove_fr_fr (int register_1,int register_2);
void i_fmove_fr_id (int register_1,int offset,int register_2);
#ifdef M68000
	void i_fmove_fr_pd (int register_1,int register_2);
	void i_fmove_fr_pi (int register_1,int register_2);
#endif
void i_fmove_id_fr (int offset,int register_2,int register_1);
#ifdef M68000
	void i_fmove_pd_fr (int register_1,int register_2);
	void i_fmove_pi_fr (int register_1,int register_2);
#endif
#if defined (M68000) || defined (I486) || defined (ARM)
	void i_move_id_pd (int offset,int register_1,int register_2);
#endif
#if defined (I486) || defined (ARM)
void i_fmoves_fr_id (int register_1,int offset,int register_2);
#endif
void i_move_id_id (int offset_1,int register_1,int offset_2,int register_2);
void i_move_id_r (int offset,int register_1,int register_2);
#if defined (ARM) && (defined (THUMB) || defined (G_A64))
void i_move_idaa_r (int offset,int register_1,int register_2);
#endif
#if defined (G_POWER) || defined (ARM)
	void i_move_idu_r (int offset,int register_1,int register_2);
#endif
#if defined (ARM)
void i_move_r_idpa (int register_1,int register_2,int offset);
#endif
#ifdef G_POWER
	void i_move_id_idu (int offset1,int register_1,int offset2,int register_2);
	void i_move_r_idu (int register_1,int offset,int register_2);
	void i_movew_id_idu (int offset1,int register_1,int offset2,int register_2);
	void i_movew_r_idu (int register_1,int offset,int register_2);
#endif
void i_move_i_r (CleanInt i,int register_1);
void i_move_l_r (LABEL *label,int register_1);
#ifdef M68000
void i_move_pi_id (int register_1,int offset_2,int register_2);
void i_move_pd_r (int register_1,int register_2);
#endif
#if defined (M68000) || defined (I486) || defined (ARM)
	void i_move_pi_r (int register_1,int register_2);
#endif
#if defined (I486) || defined (ARM)
	void i_move_r_l (int register_1,LABEL *label);
#endif
void i_move_r_id (int register_1,int offset,int register_2);
#if defined (ARM) && (defined (THUMB) || defined (G_A64))
void i_move_r_idaa (int offset,int register_1,int register_2);
#endif
#if defined (M68000) || defined (I486) || defined (ARM)
	void i_move_r_pd (int register_1,int register_2);
#endif
#ifdef M68000
void i_move_r_pi (int register_1,int register_2);
#endif
void i_move_r_r (int register_1,int register_2);
#ifdef M68000
void i_movem_pd (int register_1,int n_arguments,int arguments[]);
void i_movem_pi (int register_1,int n_arguments,int arguments[]);
void i_movem_id_r (int offset,int register_1,int register_2);
void i_movew_id_pd (int offset_1,int register_1,int register_2);
void i_movew_pi_id (int register_1,int offset_2,int register_2);
void i_movew_pi_r (int register_1,int register_2);
void i_movew_r_pd (int register_1,int register_2);
#endif
#if defined (ARM)
	void i_movem_pd_rs (int register_1,int n_arguments,int arguments[]);
	void i_movem_pi_rs (int register_1,int n_arguments,int arguments[]);
	void i_movem_rs_pd (int n_arguments,int arguments[],int register_1);
	void i_movem_rs_pi (int n_arguments,int arguments[],int register_1);
#endif
#ifdef G_A64
	void i_loadsqb_r_r (int register_1,int register_2);
	void i_loadsqb_id_r (int offset,int register_1,int register_2);
#endif
void i_movew_id_r (int offset,int register_1,int register_2);
void i_lea_id_r (int offset,int register_1,int register_2);
void i_lea_l_i_r (LABEL *label,int offset,int register_1);
void i_add_i_r (LONG value,int register_1);
#ifdef THUMB
	void i_addi_r_r (LONG value,int register_1,int register_2);
#endif
void i_add_r_r (int register_1,int register_2);
void i_schedule_i (int value);
void i_sub_i_r (LONG value,int register_1);
void i_word_i (int value);

extern int local_data_offset;
extern int condition_to_set_instruction[];
