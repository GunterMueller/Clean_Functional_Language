
#ifndef VOID
#	ifdef THINK_C
#		define VOID void
#	else
#		define VOID
#	endif
#endif

#ifndef LONG
#	define LONG long
#endif

#ifndef ULONG
#	define ULONG unsigned long
#endif

void code_absR (void);
void code_acosR (VOID);
void code_add_args (int source_offset,int n_arguments,int destination_offset);
void code_addI (VOID);
#if defined (I486) || defined (ARM)
void code_addLU (VOID);
#endif
#ifndef M68000
void code_addIo (VOID);
#endif
void code_algtype (int n_constructors);
void code_addR (VOID);
void code_andB (VOID);
void code_and (VOID);
void code_array (VOID);
void code_asinR (VOID);
void code_atanR (VOID);
void code_build (char descriptor_name[],int arity,char *code_name);
void code_buildh (char descriptor_name[],int arity);
void code_buildB (int value);
void code_buildC (int value);
void code_buildI (CleanInt value);
void code_buildR  (double value);
void code_buildAC (char *string,int string_length);
void code_buildB_b (int b_offset);
void code_buildC_b (int b_offset);
void code_buildF_b (int b_offset);
void code_buildI_b (int b_offset);
void code_buildR_b  (int b_offset);
void code_buildhr (char descriptor_name[],int a_size,int b_size);
void code_build_r (char descriptor_name[],int a_size,int b_size,int a_offset,int b_offset);
void code_build_u (char descriptor_name[],int a_size,int b_size,char *code_name);
void code_CtoI (VOID);
void code_catS (int source_offset_1,int source_offset_2,int destination_offset);
#if defined (M68000) || defined (G_POWER)
void code_call (char *s1,int length,char *label);
#endif
void code_ccall (char *label,char *s,int length);
void code_centry (char *c_function_name,char *clean_function_label,char *s,int length);
void code_channelP (int a_offset);
void code_cmpS (int a_offset_1,int a_offset_2);
void code_ceilingR (VOID);
#if defined (I486) || defined (ARM)
void code_clzb (VOID);
#endif
void code_copy_graph (int a_offset);
void code_CtoAC (VOID);
void code_currentP (VOID);
void code_cosR (VOID);
void code_create (int n_arguments);
void code_create_array (char *element_descriptor,int a_size,int b_size);
void code_create_array_ (char *element_descriptor,int a_size,int b_size);
void code_create_channel (char *label_name);
void code_decI (VOID);
void code_del_args (int source_offset,int n_arguments,int destination_offset);
void code_divI (VOID);
#if defined (I486) || (defined (ARM) && !defined (G_A64))
void code_divLU (VOID);
#endif
void code_divR (VOID);
#if defined (I486) || defined (ARM) || defined (G_POWER)
 void code_divU (VOID);
#endif
void code_entierR (VOID);
void code_eqB (VOID);
void code_eqB_a (int value,int a_offset);
void code_eqB_b (int value,int b_offset);
void code_eqC (VOID);
void code_eqC_a (int value,int a_offset);
void code_eqC_b (int value,int b_offset);
void code_eqD_b (char descriptor_name[],int arity);
void code_eqI (VOID);
void code_eqI_a (CleanInt value,int a_offset);
void code_eqI_b (CleanInt value,int b_offset);
void code_eqR (VOID);
void code_eqR_a (double value,int a_offset);
void code_eqR_b (double value,int b_offset);
void code_eqAC_a (char *string,int string_length);
void code_eq_desc (char descriptor_name[],int arity,int a_offset);
void code_eq_desc_b (char descriptor_name[],int arity);
void code_eq_nulldesc (char descriptor_name[],int a_offset);
void code_eq_symbol (int a_offset_1,int a_offset_2);
void code_exit_false (char label_name[]);
void code_expR (VOID);
void code_fill (char *,int,char *,int);
void code_fillh (char *,int,int);
void code_fill1 (char descriptor_name[],int arity,int a_offset,char bits[]);
void code_fill2 (char descriptor_name[],int arity,int a_offset,char bits[]);
void code_fill3 (char descriptor_name[],int arity,int a_offset,char bits[]);
void code_fill1_r (char descriptor_name[],int a_size,int b_size,int root_offset,char bits[]);
void code_fill2_r (char descriptor_name[],int a_size,int b_size,int root_offset,char bits[]);
void code_fill3_r (char descriptor_name[],int a_size,int b_size,int root_offset,char bits[]);
void code_fill_r (char descriptor_name[],int n1,int n2,int n3,int n4,int n5);
void code_fillcaf (char *label_name,int a_size,int b_size);
void code_fillcp (char *,int,char *,int,char bits[]);
void code_fillcp_u (char descriptor_name[],int a_size,int b_size,char *code_name,int a_offset,char bits[]);
void code_fill_u (char descriptor_name[],int a_size,int b_size,char *code_name,int a_offset);
void code_fillA_a  (char *descriptor,int a_offset_1,int a_offset_2);
void code_fillB (int value,int a_offset);
void code_fillB_b  (int b_offset,int a_offset);
void code_fillC (int value,int a_offset);
void code_fillC_b (int b_offset,int a_offset);
void code_fillF_b (int b_offset,int a_offset);
void code_fillI (CleanInt value,int a_offset);
void code_fillI_b (int b_offset,int a_offset);
void code_fillR  (double value,int a_offset);
void code_fillR_b (int b_offset,int a_offset);
void code_fill_a (int from_offset,int to_offset);
#if defined (I486) || defined (ARM)
void code_floordivI (VOID);
#endif
void code_get_desc_arity (int a_offset);
void code_get_desc_arity_offset (void);
void code_get_node_arity (int a_offset);
void code_get_desc0_number (void);
void code_get_desc_flags_b (void);
void code_get_thunk_arity (void);
void code_get_thunk_desc (void);
void code_gtC (VOID);
void code_gtI (VOID);
void code_gtR (VOID);
#if defined (I486) || defined (ARM)
void code_gtU (VOID);
#endif
void code_halt (VOID);
void code_in (char parameters[]);
void code_incI (VOID);
void code_instruction (CleanInt i);
void code_is_record (int a_offset);
void code_ItoC (VOID);
void code_ItoP (VOID);
void code_ItoR (VOID);
void code_jmp (char label_name[]);
void code_jmpD (char c1,char c2,char descriptor_name[],int arity,char label_name1[],char label_name2[]);
void code_jmp_ap (int n_args);
void code_jmp_ap_upd (int n_args);
void code_jmp_i (int n_args);
void code_jmp_not_eqZ (char *integer_string,int integer_string_length,char label_name[]);
void code_jmp_upd (char label_name[]);
void code_jmp_eval (VOID);
void code_jmp_eval_upd (VOID);
void code_jmp_false (char label_name[]);
void code_jmp_true (char label_name[]);
void code_jrsr (char label_name[]);
void code_jsr (char label_name[]);
void code_jsr_ap (int n_args);
void code_jsr_eval (int a_offset);
void code_jsr_i (int n_args);
void code_lnR (VOID);
void code_load_i (CleanInt offset);
void code_load_module_name (void);
void code_load_si16 (CleanInt offset);
#ifdef G_A64
void code_load_si32 (CleanInt offset);
#endif
void code_load_ui8 (CleanInt offset);
void code_log10R (VOID);
void code_ltC (VOID);
void code_ltI (VOID);
void code_ltR (VOID);
#if defined (I486) || defined (ARM)
void code_ltU (VOID);
void code_modI (VOID);
#endif
void code_remI (VOID);
#if defined (I486) || defined (ARM)
 void code_remU (VOID);
#endif
void code_mulI (VOID);
#ifndef M68000
void code_mulIo (VOID);
#endif
void code_mulR (VOID);
#if defined (I486) || defined (ARM) || defined (G_POWER)
void code_mulUUL (VOID);
#endif
void code_negI (void);
void code_negR (VOID);
void code_new_ext_reducer (char descriptor_name[],int a_offset);
void code_new_int_reducer (char label_name[],int a_offset);
void code_newP (VOID);
void code_no_op (VOID);
void code_notB (VOID);
void code_not (VOID);
void code_orB (VOID);
void code_or (VOID);
void code_out (char parameters[]);
void code_parallel (VOID);
void code_pause (VOID);
void code_pop_a (int n);
void code_pop_b (int n);
void code_powR (VOID);
void code_print (char *string,int length);
void code_print_char (VOID);
void code_print_int (VOID);
void code_print_real (VOID);
#if 0
void code_print_r_arg (int a_offset);
#endif
void code_print_sc (char *string,int length);
void code_print_symbol (int a_offset);
void code_print_symbol_sc (int a_offset);
void code_printD (VOID);
#ifdef FINALIZERS
void code_push_finalizers(VOID);
#endif
void code_push_r_args (int n1,int n2,int n3);
void code_push_r_args_a (int n1,int n2,int n3,int n4,int n5);
void code_push_r_args_b (int n1,int n2,int n3,int n4,int n5);
void code_push_r_args_u (int n1,int n2,int n3);
void code_repl_r_args (int n1,int n2);
void code_repl_r_args_a (int n1,int n2,int n3,int n4);
void code_repl_r_args_b (int n1,int n2,int n3,int n4);
void code_pushA_a (int a_offset);
void code_pushB (int b);
void code_pushB_a (int a_offset);
void code_pushC (int c);
void code_pushC_a (int a_offset);
void code_pushD (char *descriptor);
void code_pushD_a (int a_offset);
void code_pushF_a (int a_offset);
void code_pushI (CleanInt i);
void code_pushI_a (int a_offset);
void code_pushL (char *label_name);
void code_pushLc (char *c_function_name);
void code_pushR (double r);
void code_pushR_a (int a_offset);
void code_pushzs (char *string,int length);
void code_push_a (int a_offset);
void code_push_b (int b_offset);
void code_push_a_b (int a_offset);
void code_push_a_r_args (VOID);
void code_push_b_a (int b_offset);
void code_push_t_r_a (int a_offset);
void code_push_t_r_args (VOID);
void code_push_arg (int a_offset,int arity,int argument_number);
void code_push_arg_b (int a_offset);
void code_push_args (int a_offset,int arity,int n_arguments);
void code_push_args_u (int a_offset,int arity,int n_arguments);
void code_push_arraysize (char *element_descriptor,int a_size,int b_size);
void code_pushcaf (char *label_name,int a_size,int b_size);
void code_push_node (char *label_name,int n_arguments);
void code_push_node_u (char *label_name,int a_size,int b_size);
void code_push_r_arg_D (VOID);
void code_push_r_arg_t (VOID);
void code_push_r_arg_u (int a_offset,int a_size,int b_size,int a_arg_offset,int a_arg_size,int b_arg_offset,int b_arg_size);
void code_pushZ (char *integer_string,int length);
void code_pushZR (int sign,char *integer_string,int integer_string_length,int exponent);
void code_release (VOID);
void code_randomP (VOID);
void code_replace (char element_descriptor[],int a_size,int b_size);
void code_repl_arg (int arity,int argument_n);
void code_repl_args (int arity,int n_arguments);
void code_repl_args_b (VOID);
void code_repl_r_a_args_n_a (VOID);
#if defined (I486) || defined (ARM)
void code_rotl (void);
void code_rotr (void);
#endif
void code_rtn (VOID);
void code_RtoI (VOID);
void code_select (char *element_descriptor,int a_size,int b_size);
void code_send_graph (char descriptor_name[],int a_offset_1,int a_offset_2);
void code_send_request (int a_offset);
void code_set_continue (int a_offset);
void code_set_defer (int a_offset);
void code_set_entry (char *label_name,int a_offset);
#ifdef FINALIZERS
void code_set_finalizers(VOID);
#endif
void code_shiftl (VOID);
void code_shiftr (VOID);
void code_shiftrU (VOID);
void code_sinR (VOID);
#if defined (I486) && !defined (G_AI64)
void code_sincosR (VOID);
#endif
void code_sliceS (int source_offset,int destination_offset);
void code_sqrtR (VOID);
void code_stop_reducer (VOID);
void code_subI (VOID);
#if defined (I486) || defined (ARM)
void code_subLU (VOID);
#endif
#ifndef M68000
void code_subIo (VOID);
#endif
void code_subR (VOID);
void code_suspend (VOID);
void code_tanR (VOID);
void code_testcaf (char *label_name);
void code_truncateR (VOID);
void code_update (char *element_descriptor,int a_size,int b_size);
void code_update_a (int a_offset_1,int a_offset_2);
void code_updatepop_a (int a_offset_1,int a_offset_2);
void code_update_b (int b_offset_1,int b_offset_2);
void code_updatepop_b (int b_offset_1,int b_offset_2);
void code_updateS (int source_offset,int destination_offset);
void code_xor (VOID);

void code_a (int number_of_arguments,char *ea_label_name);
void code_ai (int n_apply_args,char *ea_label_name,char *instance_member_code_name);
void code_caf (char *label_name,int a_size,int b_size);
void code_comp (int version,char *options);
void code_d (int da,int db,ULONG vector[]);
void code_desc (char *s1,char *s2,char *s3,int n,int lazy_record_flag,char *s4,int l);
void code_desc0 (char label_name[],int desc0_number,char descriptor_name[],int descriptor_name_length);
void code_descn (char label_name[],char node_entry_label_name[],int arity,int lazy_record_flag,char descriptor_name[],int descriptor_name_length);
void code_descexp (char *s1,char *s2,char *s3,int n,int lazy_record_flag,char *s4,int l);
#ifdef NEW_DESCRIPTORS
void code_descs (char *s1,char *s2,char *s3,int offset1,int offset2,char *s4,int l);
#endif
void code_record (char *s1,char *s2,int n1,int n2,char *s3,int s3_length);
void code_record_start (char record_label_name[],char type[],int a_size,int b_size);
void code_record_descriptor_label (char descriptor_name[]);
void code_record_end (char record_name[],int record_name_length);
void code_depend (char *module_name,int module_name_length);
void code_export (char *label_name);
void code_impdesc (char *label_name);
void code_implab_node_entry (char *label_name,char *ea_label_name);
void code_implab (char *label_name);
void code_impmod (char *module_name);
void code_keep (int a_offset_1,int a_offset_2);
void code_n (int number_of_arguments,char *descriptor_name,char *ea_label_name);
void code_nu (int a_size,int b_size,char *descriptor_name,char *ea_label_name);
void code_n_string (char *s1,int l);
void code_o (int oa,int ob,ULONG vector[]);
void code_pb (char string[],int string_length);
void code_pd (void);
void code_pe (void);
void code_pl (void);
void code_pld (void);
void code_pn (void);
void code_pt (void);
void code_module (char *s1,char *s2,int l);
void code_start (char *label_name);
void code_string (char *s1,char *s2,int l);

void code_dummy (VOID);
	
void code_label (char *label);
void code_newlocallabel (char *label_name);

void initialize_coding (VOID);
