
#ifdef ANDROID
# define SOFT_FP_CC
#endif

#define NO_REG_OR_PAD 128
#define PAD_4_AFTER 129

#ifndef THUMB
# define i_move_idaa_r i_move_id_r
# define i_move_r_idaa i_move_r_id
# define REGISTER_R0 REGISTER_D4
#else
# define REGISTER_R0 REGISTER_D1
#endif

void code_ccall (char *c_function_name,char *s,int length)
{
	LABEL *label;
	int l,min_index;
	int a_offset,b_offset,a_result_offset,b_result_offset;
	int result,a_o,b_o,float_parameters;
	int n_clean_b_register_parameters,clean_b_register_parameter_n;
	int n_extra_clean_b_register_parameters;
	int first_pointer_result_index,callee_pops_arguments,save_state_in_global_variables;
	int function_address_parameter;
	int c_offset,c_register_parameter_n,c_register_pair_parameter_n,c_parameter_offset;
#ifndef SOFT_FP_CC
	int c_fp_register_parameter_n;
#endif
	int c_parameter_padding;
	int previous_word_l;
	unsigned char reg_or_pad[100]; /* 128 = no_reg_or_pad, <128 = reg number, 129 = pad 4 bytes after */

	function_address_parameter=0;

	if (length>100)
		error_s (ccall_error_string,c_function_name);

	for (l=0; l<length; ++l)
		reg_or_pad[l] = NO_REG_OR_PAD;

	if (*s=='G'){
		++s;
		--length;
		save_state_in_global_variables=1;
		if (saved_heap_p_label==NULL)
			saved_heap_p_label=enter_label ("saved_heap_p",IMPORT_LABEL);
		if (saved_a_stack_p_label==NULL)
			saved_a_stack_p_label=enter_label ("saved_a_stack_p",IMPORT_LABEL);
	} else	
		save_state_in_global_variables=0;

	if (*s=='P'){
		++s;
		--length;
		callee_pops_arguments=1;
	} else
		callee_pops_arguments=0;

	float_parameters=0;
			
	a_offset=0;
	b_offset=0;
	n_clean_b_register_parameters=0;
	c_register_parameter_n=0;
	c_register_pair_parameter_n=0;
	c_parameter_offset = 0;
	c_parameter_padding = 0;
#ifndef SOFT_FP_CC
	c_fp_register_parameter_n=0;
#endif

	previous_word_l = -1;
	for (l=0; l<length; ++l){
		switch (s[l]){
			case '-':
			case ':':
				min_index=l;
				break;
			case 'I':
			case 'p':
				if (c_register_parameter_n<4){
					reg_or_pad[l] = c_register_parameter_n;
					if (c_register_parameter_n>=c_register_pair_parameter_n)
						++c_register_parameter_n;
					else
						c_register_parameter_n=c_register_pair_parameter_n+2;
				} else {
					previous_word_l = l;
					c_parameter_offset+=STACK_ELEMENT_SIZE;
				}
				b_offset+=STACK_ELEMENT_SIZE;
				if (!float_parameters)
					++n_clean_b_register_parameters;
				continue;
			case 'r':
				if (c_register_parameter_n<4){
					reg_or_pad[l] = c_register_parameter_n;
					if (c_register_parameter_n>=c_register_pair_parameter_n)
						++c_register_parameter_n;
					else
						c_register_parameter_n=c_register_pair_parameter_n;
				} else {
					previous_word_l = l;
					c_parameter_offset+=STACK_ELEMENT_SIZE;
				}
				float_parameters=1;
				b_offset+=8;
				continue;
			case 'R':
				float_parameters=1;
				b_offset+=8;
#ifdef SOFT_FP_CC
				if (c_register_parameter_n<4){
					if ((c_register_parameter_n & 1)==0){
						reg_or_pad[l] = c_register_parameter_n;
						c_register_parameter_n+=2;
						c_register_pair_parameter_n = c_register_parameter_n;
						previous_word_l = -1;
						continue;
					} else {
						if (c_register_pair_parameter_n<=c_register_parameter_n)
							c_register_pair_parameter_n = c_register_parameter_n+1;
						if (c_register_pair_parameter_n<4){
							reg_or_pad[l] = c_register_pair_parameter_n;
							c_register_pair_parameter_n+=2;
							previous_word_l = -1;
							continue;
						} else
							c_register_parameter_n=4;
					}
				}
#else
				if (c_fp_register_parameter_n<8){
					reg_or_pad[l] = c_fp_register_parameter_n++;
					continue;
				}
#endif
				if (c_parameter_offset & 4){
					if (previous_word_l<0 || reg_or_pad[previous_word_l]!=NO_REG_OR_PAD)
						internal_error_in_function ("code_ccall");
					reg_or_pad[previous_word_l]=PAD_4_AFTER;
					c_parameter_padding+=4;
					c_parameter_offset+=4;
				}
				c_parameter_offset+=8;
				previous_word_l = -1;
				continue;
			case 'S':
			case 's':
			case 'A':
				if (c_register_parameter_n<4){
					reg_or_pad[l] = c_register_parameter_n;
					if (c_register_parameter_n>=c_register_pair_parameter_n)
						++c_register_parameter_n;
					else
						c_register_parameter_n=c_register_pair_parameter_n+2;
				} else {
					previous_word_l = l;
					c_parameter_offset+=STACK_ELEMENT_SIZE;
				}
				a_offset+=STACK_ELEMENT_SIZE;
				continue;
			case 'O':
			case 'F':
				if (function_address_parameter)
					error_s (ccall_error_string,c_function_name);
				function_address_parameter=s[l];
				
				while (l+1<length && (s[l+1]=='*' || s[l+1]=='[')){
					++l;
					if (s[l]=='['){
						++l;
						while (l<length && (unsigned)(s[l]-'0')<(unsigned)10)
							++l;
						if (!(l<length && s[l]==']'))
							error_s (ccall_error_string,c_function_name);
					}
				}
				b_offset+=STACK_ELEMENT_SIZE;
				if (!float_parameters)
					++n_clean_b_register_parameters;
				continue;
			default:
				error_s (ccall_error_string,c_function_name);
		}
		break;
	}
	if (l>=length)
		error_s (ccall_error_string,c_function_name);
	
	n_extra_clean_b_register_parameters=0;

	for (++l; l<length; ++l){
		switch (s[l]){
			case 'I':
			case 'p':
				continue;
			case 'R':
				float_parameters=1;
				continue;
			case 'S':
				continue;
			case 'A':
				++l;
				if (l<length && (s[l]=='i' || s[l]=='r')){
					continue;
				} else {
					error_s (ccall_error_string,c_function_name);
					break;
				}
			case ':':
				if (l==min_index+1 || l==length-1)
					error_s (ccall_error_string,c_function_name);
				else {
					int new_length;
					
					new_length=l;
					
					for (++l; l<length; ++l){
						switch (s[l]){
							case 'I':
							case 'p':
								if (!float_parameters)
									++n_extra_clean_b_register_parameters;
								break;
							case 'R':
								float_parameters=1;
								break;
							case 'S':
							case 'A':
								continue;
							default:
								error_s (ccall_error_string,c_function_name);
						}
					}
					
					length=new_length;
				}
				break;
			case 'V':
				if (l==min_index+1 && l!=length-1)
					continue;
			default:
				error_s (ccall_error_string,c_function_name);
		}
	}

	if (n_clean_b_register_parameters>N_DATA_PARAMETER_REGISTERS){
		n_clean_b_register_parameters=N_DATA_PARAMETER_REGISTERS;
		n_extra_clean_b_register_parameters=0;
	} else if (n_clean_b_register_parameters+n_extra_clean_b_register_parameters>N_DATA_PARAMETER_REGISTERS)
		n_extra_clean_b_register_parameters=N_DATA_PARAMETER_REGISTERS-n_clean_b_register_parameters;

	end_basic_block_with_registers (0,n_clean_b_register_parameters+n_extra_clean_b_register_parameters,e_vector);

	b_offset-=n_clean_b_register_parameters<<STACK_ELEMENT_LOG_SIZE;

	if (n_extra_clean_b_register_parameters!=0)
		push_extra_clean_b_register_parameters (n_extra_clean_b_register_parameters);

	c_offset=b_offset;

	if (s[min_index]=='-' && length-1!=min_index+1){
		result='V';
		first_pointer_result_index=min_index+1;
	} else {
		result=s[min_index+1];
		first_pointer_result_index=min_index+2;

		switch (result){
			case 'I':
			case 'p':
			case 'R':
			case 'S':
				break;
			case 'A':
				++first_pointer_result_index;
		}
	}

	a_result_offset=0;
	b_result_offset=0;

	for (l=first_pointer_result_index; l<length; ++l){
		switch (s[l]){
			case 'I':
			case 'p':
				if (c_register_parameter_n<4){
					reg_or_pad[l] = c_register_parameter_n;
					if (c_register_parameter_n>=c_register_pair_parameter_n)
						++c_register_parameter_n;
					else
						c_register_parameter_n=c_register_pair_parameter_n+2;
				} else
					c_parameter_offset+=STACK_ELEMENT_SIZE;
				b_result_offset+=STACK_ELEMENT_SIZE;
				continue;
			case 'R':
				if (c_register_parameter_n<4){
					reg_or_pad[l] = c_register_parameter_n;
					if (c_register_parameter_n>=c_register_pair_parameter_n)
						++c_register_parameter_n;
					else
						c_register_parameter_n=c_register_pair_parameter_n+2;
				} else
					c_parameter_offset+=STACK_ELEMENT_SIZE;
				b_result_offset+=8;
				continue;
			case 'S':
				if (c_register_parameter_n<4){
					reg_or_pad[l] = c_register_parameter_n;
					if (c_register_parameter_n>=c_register_pair_parameter_n)
						++c_register_parameter_n;
					else
						c_register_parameter_n=c_register_pair_parameter_n+2;
				} else
					c_parameter_offset+=STACK_ELEMENT_SIZE;
				a_result_offset+=STACK_ELEMENT_SIZE;
				continue;
			case 'A':
				if (c_register_parameter_n<4){
					reg_or_pad[l] = c_register_parameter_n;
					if (c_register_parameter_n>=c_register_pair_parameter_n)
						++c_register_parameter_n;
					else
						c_register_parameter_n=c_register_pair_parameter_n+2;
				} else
					c_parameter_offset+=STACK_ELEMENT_SIZE;
				++l;
				a_result_offset+=STACK_ELEMENT_SIZE;
				continue;
		}
	}

	if (!function_address_parameter)
		label = enter_c_function_name_label (c_function_name);

	{
	int c_offset_before_pushing_arguments,function_address_reg,function_address_s_index;

	a_o=-b_result_offset-a_result_offset;
	b_o=0;

	if (a_result_offset+b_result_offset>b_offset){
		i_sub_i_r (a_result_offset+b_result_offset-b_offset,B_STACK_POINTER);
		c_offset=a_result_offset+b_result_offset;
	}

	c_offset_before_pushing_arguments=c_offset;

#ifndef THUMB
	i_move_r_r (B_STACK_POINTER,REGISTER_A2);
	if (c_parameter_offset & 4){
		i_sub_i_r (4,B_STACK_POINTER);
		i_or_i_r (4,B_STACK_POINTER);
	} else {
		i_and_i_r (-8,B_STACK_POINTER);		
	}
#else
	if (c_parameter_offset & 4){
		i_addi_r_r (-4,B_STACK_POINTER,REGISTER_A3);
		i_move_r_r (B_STACK_POINTER,REGISTER_A2);
		i_ori_r_r (4,REGISTER_A3,REGISTER_A3);
	} else {
		i_move_r_r (B_STACK_POINTER,REGISTER_A2);
		i_andi_r_r (-8,REGISTER_A2,REGISTER_A3);
	}
	i_move_r_r (REGISTER_A3,B_STACK_POINTER);
#endif

	for (l=length-1; l>=first_pointer_result_index; --l){
		switch (s[l]){
			case 'I':
			case 'p':
				b_o-=STACK_ELEMENT_SIZE;
				if (reg_or_pad[l]<NO_REG_OR_PAD){
#ifndef THUMB
					i_lea_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_A2,REGISTER_R0-reg_or_pad[l]);
#endif
				} else {
					if (b_o+c_offset_before_pushing_arguments==0)
						i_move_r_pd (REGISTER_A2,B_STACK_POINTER);
					else {
						i_lea_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_A2,REGISTER_A3);
						i_move_r_pd (REGISTER_A3,B_STACK_POINTER);
					}
					c_offset+=STACK_ELEMENT_SIZE;
				}
				break;
			case 'i':
			case 'r':
				--l;
			case 'S':
				if (reg_or_pad[l]<NO_REG_OR_PAD){
#ifndef THUMB
					i_lea_id_r (a_o+c_offset_before_pushing_arguments,REGISTER_A2,REGISTER_R0-reg_or_pad[l]);
#endif
				} else {
					if (a_o+c_offset_before_pushing_arguments==0)
						i_move_r_pd (REGISTER_A2,B_STACK_POINTER);
					else {
						i_lea_id_r (a_o+c_offset_before_pushing_arguments,REGISTER_A2,REGISTER_A3);
						i_move_r_pd (REGISTER_A3,B_STACK_POINTER);
					}
					c_offset+=STACK_ELEMENT_SIZE;
				}
				a_o+=STACK_ELEMENT_SIZE;
				break;
			case 'R':
				b_o-=8;
				if (reg_or_pad[l]<NO_REG_OR_PAD){
#ifndef THUMB
					i_lea_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_A2,REGISTER_R0-reg_or_pad[l]);
#endif
				} else {
					if (b_o+c_offset_before_pushing_arguments==0)
						i_move_r_pd (REGISTER_A2,B_STACK_POINTER);
					else {
						i_lea_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_A2,REGISTER_A3);
						i_move_r_pd (REGISTER_A3,B_STACK_POINTER);
					}
					c_offset+=STACK_ELEMENT_SIZE;
				}
				break;
			case 'V':
				break;
			default:
				error_s (ccall_error_string,c_function_name);
		}
	}

	{
		int last_register_parameter_index,reg_n,c_offset_1;
		
		last_register_parameter_index=-1;
			
		reg_n=0;
		l=0;
		while (reg_n<n_clean_b_register_parameters && l<min_index){
			if (s[l]=='I' || s[l]=='p' || s[l]=='F' || s[l]=='O'){
				++reg_n;
				last_register_parameter_index=l;
			}
			++l;
		}
		
		c_offset_1=0;

		for (l=min_index-1; l>=0; --l){
			switch (s[l]){
				case 'I':
				case 'p':
				case 'S':
				case 's':
				case 'A':
					if (reg_or_pad[l]>=NO_REG_OR_PAD){
						if (reg_or_pad[l]==PAD_4_AFTER)
							c_offset_1+=4;
						c_offset_1+=STACK_ELEMENT_SIZE;
					}
					break;
				case 'R':
					if (reg_or_pad[l]>=NO_REG_OR_PAD)
						c_offset_1+=8;
					break;
				case 'O':
				case 'F':
				case '*':
				case ']':
					while (l>=0 && (s[l]!='F' && s[l]!='O'))
						--l;
					if (reg_or_pad[l]>=NO_REG_OR_PAD)
						c_offset_1+=STACK_ELEMENT_SIZE;
					break;
			}
		}
		
		if (c_offset_1!=0){
			i_sub_i_r (c_offset_1,B_STACK_POINTER);
			c_offset += c_offset_1;
		}

		{
			int l,c_offset_2,not_finished;
#ifdef THUMB
			int new_reg[2];
			
			new_reg[0]=new_reg[1]=-1;
#else
			int new_reg[5];
			
			new_reg[0]=new_reg[1]=new_reg[2]=new_reg[3]=new_reg[4]=-1; /* [0] not used */
#endif

			c_offset_2 = c_offset_1;
			reg_n=0;
			for (l=min_index-1; l>=0; --l){
				switch (s[l]){
					case 'I':
					case 'p':
						if (reg_or_pad[l]<NO_REG_OR_PAD){
							if (l<=last_register_parameter_index){
#ifdef THUMB
								if (reg_or_pad[l]<2)
									new_reg [1-reg_or_pad[l]] = n_extra_clean_b_register_parameters+reg_n;
								else
									i_move_r_r (REGISTER_D0+n_extra_clean_b_register_parameters+reg_n,REGISTER_R0-reg_or_pad[l]);
#else
								new_reg [4-reg_or_pad[l]] = n_extra_clean_b_register_parameters+reg_n;
#endif
								++reg_n;
							}
						} else {
							if (reg_or_pad[l]==PAD_4_AFTER)
								c_offset_2-=4;
							c_offset_2-=STACK_ELEMENT_SIZE;
							if (l<=last_register_parameter_index){
								i_move_r_idaa (REGISTER_D0+n_extra_clean_b_register_parameters+reg_n,c_offset_2,B_STACK_POINTER);
								++reg_n;
							}
						}
						break;
					case 'S':
					case 's':
					case 'A':
						if (reg_or_pad[l]>=NO_REG_OR_PAD){
							if (reg_or_pad[l]==PAD_4_AFTER)
								c_offset_2-=4;
							c_offset_2-=STACK_ELEMENT_SIZE;
						}
						break;
					case 'R':
						if (reg_or_pad[l]>=NO_REG_OR_PAD)
							c_offset_2-=8;
						break;
					case 'O':
					case 'F':
					case '*':
					case ']':
						while (l>=0 && (s[l]!='F' && s[l]!='O'))
							--l;
						if (reg_or_pad[l]<NO_REG_OR_PAD){
							if (l<=last_register_parameter_index){
#ifdef THUMB
								if (reg_or_pad[l]<2)
									new_reg [1-reg_or_pad[l]] = n_extra_clean_b_register_parameters+reg_n;
								else
									i_move_r_r (REGISTER_D0+n_extra_clean_b_register_parameters+reg_n,REGISTER_R0-reg_or_pad[l]);
#else
								new_reg [4-reg_or_pad[l]] = n_extra_clean_b_register_parameters+reg_n;
#endif
								++reg_n;
							}
						}
						break;
				}
			}
			
			do {
				not_finished=0;
#ifdef THUMB
				for (reg_n=0; reg_n<=1; ++reg_n){
					int n;
				
					n=new_reg[reg_n];
					if (n>=0 && n!=reg_n){
						if (new_reg[0]!=reg_n && new_reg[1]!=reg_n){
							i_move_r_r (REGISTER_D0+n,REGISTER_D0+reg_n);
							new_reg[reg_n]=-1;
						} else
							not_finished=1;
					}
				}
#else
				for (reg_n=1; reg_n<=4; ++reg_n){
					int n;
				
					n=new_reg[reg_n];
					if (n>=0 && n!=reg_n){
						if (new_reg[1]!=reg_n && new_reg[2]!=reg_n && new_reg[3]!=reg_n && new_reg[4]!=reg_n){
							i_move_r_r (REGISTER_D0+n,REGISTER_D0+reg_n);
							new_reg[reg_n]=-1;
						} else
							not_finished=1;
					}
				}
#endif
			} while (not_finished); /* infinite loop in case of cycle */
		}

		reg_n=0;
		a_o=-a_offset;
		b_o=0;
		for (l=min_index-1; l>=0; --l){
			switch (s[l]){
				case 'I':
				case 'p':
					if (reg_or_pad[l]<NO_REG_OR_PAD){
						if (l<=last_register_parameter_index){
							/* i_move_r_r (REGISTER_D0+n_extra_clean_b_register_parameters+reg_n,REGISTER_R0-reg_or_pad[l]); */
							++reg_n;
						} else {
							b_o-=STACK_ELEMENT_SIZE;
							i_move_idaa_r (b_o+c_offset_before_pushing_arguments,REGISTER_A2,REGISTER_R0-reg_or_pad[l]);
						}
					} else {
						if (reg_or_pad[l]==PAD_4_AFTER)
							c_offset_1-=4;
						c_offset_1-=STACK_ELEMENT_SIZE;
						if (l<=last_register_parameter_index){
							/* i_move_r_idaa (REGISTER_D0+n_extra_clean_b_register_parameters+reg_n,c_offset_1,B_STACK_POINTER); */
							++reg_n;
						} else {
							b_o-=STACK_ELEMENT_SIZE;
							i_move_idaa_r (b_o+c_offset_before_pushing_arguments,REGISTER_A2,6/*r12*/);
							i_move_r_idaa (6/*r12*/,c_offset_1,B_STACK_POINTER);
						}
					}
					break;
				case 'S':
					if (reg_or_pad[l]<NO_REG_OR_PAD){
						i_move_idaa_r (a_o,A_STACK_POINTER,REGISTER_R0-reg_or_pad[l]);
						i_add_i_r (STACK_ELEMENT_SIZE,REGISTER_R0-reg_or_pad[l]);
					} else {
						if (reg_or_pad[l]==PAD_4_AFTER)
							c_offset_1-=4;
						c_offset_1-=STACK_ELEMENT_SIZE;
						i_move_idaa_r (a_o,A_STACK_POINTER,REGISTER_A0);
						i_add_i_r (STACK_ELEMENT_SIZE,REGISTER_A0);
						i_move_r_idaa (REGISTER_A0,c_offset_1,B_STACK_POINTER);
					}
					a_o+=STACK_ELEMENT_SIZE;
					break;
				case 'R':
					if (reg_or_pad[l]<NO_REG_OR_PAD){
						b_o-=8;
#ifdef SOFT_FP_CC
						i_move_idaa_r (b_o+c_offset_before_pushing_arguments,REGISTER_A2,REGISTER_R0-reg_or_pad[l]);
						i_move_idaa_r (b_o+c_offset_before_pushing_arguments+4,REGISTER_A2,REGISTER_R0-(reg_or_pad[l]+1));
#else
						i_fmove_id_fr (b_o+c_offset_before_pushing_arguments,REGISTER_A2,reg_or_pad[l]);
#endif
					} else {
						c_offset_1-=8;
						b_o-=8;
						i_move_idaa_r (b_o+c_offset_before_pushing_arguments,REGISTER_A2,6/*r12*/);
						i_move_r_idaa (6/*r12*/,c_offset_1,B_STACK_POINTER);
						i_move_idaa_r (b_o+c_offset_before_pushing_arguments+4,REGISTER_A2,6/*r12*/);
						i_move_r_idaa (6/*r12*/,c_offset_1+4,B_STACK_POINTER);
					}
					break;
				case 's':
					if (reg_or_pad[l]<NO_REG_OR_PAD){
						i_move_idaa_r (a_o,A_STACK_POINTER,REGISTER_R0-reg_or_pad[l]);
						i_add_i_r (2*STACK_ELEMENT_SIZE,REGISTER_R0-reg_or_pad[l]);							
					} else {
						if (reg_or_pad[l]==PAD_4_AFTER)
							c_offset_1-=4;
						c_offset_1-=STACK_ELEMENT_SIZE;
						i_move_idaa_r (a_o,A_STACK_POINTER,REGISTER_A0);
						i_add_i_r (2*STACK_ELEMENT_SIZE,REGISTER_A0);
						i_move_r_idaa (REGISTER_A0,c_offset_1,B_STACK_POINTER);
					}
					a_o+=STACK_ELEMENT_SIZE;
					break;
				case 'A':
					if (reg_or_pad[l]<NO_REG_OR_PAD){
						i_move_idaa_r (a_o,A_STACK_POINTER,REGISTER_R0-reg_or_pad[l]);
						i_add_i_r (3*STACK_ELEMENT_SIZE,REGISTER_R0-reg_or_pad[l]);
					} else {
						if (reg_or_pad[l]==PAD_4_AFTER)
							c_offset_1-=4;
						c_offset_1-=STACK_ELEMENT_SIZE;
						i_move_idaa_r (a_o,A_STACK_POINTER,REGISTER_A0);
						i_add_i_r (3*STACK_ELEMENT_SIZE,REGISTER_A0);
						i_move_r_idaa (REGISTER_A0,c_offset_1,B_STACK_POINTER);
					}
					a_o+=STACK_ELEMENT_SIZE;
					break;
				case 'O':
				case 'F':
				case '*':
				case ']':
					while (l>=0 && (s[l]!='F' && s[l]!='O'))
						--l;
					if (reg_or_pad[l]<NO_REG_OR_PAD){
						if (l<=last_register_parameter_index){
							/* i_move_r_r (REGISTER_D0+n_extra_clean_b_register_parameters+reg_n,REGISTER_R0-reg_or_pad[l]); */
							++reg_n;
						} else {
							b_o-=STACK_ELEMENT_SIZE;
							i_move_idaa_r (b_o+c_offset_before_pushing_arguments,REGISTER_A2,REGISTER_R0-reg_or_pad[l]);
						}
						
						function_address_reg = REGISTER_R0-reg_or_pad[l];
						function_address_s_index = l+1;
						break;
					}
				default:
					error_s (ccall_error_string,c_function_name);
			}
		}
	}

#ifdef THUMB
	a_o=-b_result_offset-a_result_offset;
	b_o=0;
	for (l=length-1; l>=first_pointer_result_index; --l){
		switch (s[l]){
			case 'I':
			case 'p':
				b_o-=STACK_ELEMENT_SIZE;
				if (reg_or_pad[l]<NO_REG_OR_PAD){
					if (b_o+c_offset_before_pushing_arguments==0)
						i_move_r_r (REGISTER_A2,REGISTER_R0-reg_or_pad[l]);
					else
						i_lea_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_A2,REGISTER_R0-reg_or_pad[l]);
				}
				break;
			case 'i':
			case 'r':
				--l;
			case 'S':
				if (reg_or_pad[l]<NO_REG_OR_PAD){
					if (a_o+c_offset_before_pushing_arguments==0)
						i_move_r_r (REGISTER_A2,REGISTER_R0-reg_or_pad[l]);
					else
						i_lea_id_r (a_o+c_offset_before_pushing_arguments,REGISTER_A2,REGISTER_R0-reg_or_pad[l]);
				}
				a_o+=STACK_ELEMENT_SIZE;
				break;
			case 'R':
				b_o-=8;
				if (reg_or_pad[l]<NO_REG_OR_PAD){
					if (b_o+c_offset_before_pushing_arguments==0)
						i_move_r_r (REGISTER_A2,REGISTER_R0-reg_or_pad[l]);
					else
						i_lea_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_A2,REGISTER_R0-reg_or_pad[l]);
				}
				break;
			case 'V':
				break;
			default:
				error_s (ccall_error_string,c_function_name);
		}
	}
#endif

	if (save_state_in_global_variables){
		i_lea_l_i_r (saved_a_stack_p_label,0,REGISTER_D6);
		i_move_r_idaa (A_STACK_POINTER,0,REGISTER_D6);
		i_lea_l_i_r (saved_heap_p_label,0,REGISTER_D6);
		i_move_r_idaa (HEAP_POINTER,0,REGISTER_D6);
		i_move_r_idaa (REGISTER_D5,4,REGISTER_D6);
	}

	if (!function_address_parameter)
		i_call_l (label);
	else {
		int l;
		
		for (l=function_address_s_index; l<length && (s[l]=='*' || s[l]=='['); ++l){
			int n;
			
			n=0;
			
			if (s[l]=='['){
				++l;
				while (l<length && (unsigned)(s[l]-'0')<(unsigned)10){
					n=n*10+(s[l]-'0');
					++l;
				}
			}
			
			i_move_idaa_r (n,function_address_reg,REGISTER_D6);
			function_address_reg = REGISTER_D6;
		}
		
		i_call_r (function_address_reg);
	}

	if (save_state_in_global_variables){
		i_lea_l_i_r (saved_a_stack_p_label,0,REGISTER_D6);
		i_move_idaa_r (0,REGISTER_D6,A_STACK_POINTER);
		i_lea_l_i_r (saved_heap_p_label,0,REGISTER_D6);
		i_move_idaa_r (0,REGISTER_D6,HEAP_POINTER);
		i_move_idaa_r (4,REGISTER_D6,REGISTER_D5);
	}

#ifdef THUMB
	if (c_offset_before_pushing_arguments-(b_result_offset+a_result_offset)!=0)
		i_add_i_r (c_offset_before_pushing_arguments-(b_result_offset+a_result_offset),REGISTER_A2);
	i_move_r_r (REGISTER_A2,B_STACK_POINTER);
#else
	if (c_offset_before_pushing_arguments-(b_result_offset+a_result_offset)==0)
		i_move_r_r (REGISTER_A2,B_STACK_POINTER);
	else
		i_lea_id_r (c_offset_before_pushing_arguments-(b_result_offset+a_result_offset),REGISTER_A2,B_STACK_POINTER);
#endif
	}

	if (a_offset!=0)
		i_sub_i_r (a_offset,A_STACK_POINTER);

	for (l=length-1; l>=first_pointer_result_index; --l){
		switch (s[l]){
			case 'I':
			case 'p':
			case 'R':
			case 'V':
				break;
			case 'S':
				if (string_to_string_node_label==NULL)
					string_to_string_node_label=enter_label ("string_to_string_node",IMPORT_LABEL);
				i_move_pi_r (B_STACK_POINTER,REGISTER_A0);
				i_jsr_l_idu (string_to_string_node_label,-4);
				i_move_r_idaa (REGISTER_A0,0,A_STACK_POINTER);
				i_add_i_r (STACK_ELEMENT_SIZE,A_STACK_POINTER);
				break;
			default:
				error_s (ccall_error_string,c_function_name);
		}
	}
		
	b_o=0;
	for (l=first_pointer_result_index; l<length; ++l){
		switch (s[l]){
			case 'I':
			case 'p':
				b_o+=STACK_ELEMENT_SIZE;
				break;
			case 'S':
			case 'V':
				break;
			case 'R':
				b_o+=8;
				break;
			default:
				error_s (ccall_error_string,c_function_name);
		}
	}

	switch (result){
		case 'I':
		case 'p':
			begin_new_basic_block();
#ifdef THUMB
			init_b_stack (2,i_i_vector);
			s_put_b (1,s_get_b (0));
			s_remove_b();
#else
			init_b_stack (5,i_i_i_i_i_vector);
			s_put_b (4,s_get_b (0));
			s_remove_b();
			s_remove_b();
			s_remove_b();
			s_remove_b();
#endif
			break;
		case 'V':
			begin_new_basic_block();
			break;
		case 'R':
			begin_new_basic_block();
#ifdef SOFT_FP_CC
			init_b_stack (5,i_i_i_i_i_vector);
			s_put_b (3,s_get_b (0));
			s_put_b (4,s_get_b (1));
			s_remove_b();
			s_remove_b();
			s_remove_b();
#else
			init_b_stack (2,r_vector);
#endif
			break;
		default:
			error_s (ccall_error_string,c_function_name);
	}
}

