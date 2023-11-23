
#define NO_REG 128

static int real_reg_n[8]
	= { REGISTER_D6, REGISTER_D5, REGISTER_D4, REGISTER_D3, REGISTER_D2, REGISTER_D1, REGISTER_D0, REGISTER_D7  };

#define REGISTER_X29 11
#define REGISTER_X31 13

#if !(defined (THUMB) || defined (G_A64))
#define i_move_idaa_r i_move_id_r
#define i_move_r_idaa i_move_r_id
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
	int c_offset,c_register_parameter_n,c_parameter_offset,c_stack_frame_size;
	int c_fp_register_parameter_n;
	int previous_word_l;
	unsigned char reg[100]; /* 128 = no_reg, <128 = reg number */

	function_address_parameter=0;

	if (length>100)
		error_s (ccall_error_string,c_function_name);

	for (l=0; l<length; ++l)
		reg[l] = NO_REG;

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
	c_parameter_offset = 0;
	c_fp_register_parameter_n=0;

	previous_word_l = -1;
	for (l=0; l<length; ++l){
		switch (s[l]){
			case '-':
			case ':':
				min_index=l;
				break;
			case 'I':
			case 'p':
				if (c_register_parameter_n<8){
					reg[l] = c_register_parameter_n++;
				} else {
					previous_word_l = l;
					c_parameter_offset+=STACK_ELEMENT_SIZE;
				}
				b_offset+=STACK_ELEMENT_SIZE;
				if (!float_parameters)
					++n_clean_b_register_parameters;
				continue;
			case 'r':
				if (c_register_parameter_n<8){
					reg[l] = c_register_parameter_n++;
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
				if (c_fp_register_parameter_n<8){
					reg[l] = c_fp_register_parameter_n++;
					continue;
				}
				c_parameter_offset+=8;
				previous_word_l = -1;
				continue;
			case 'S':
			case 's':
			case 'A':
				if (c_register_parameter_n<8){
					reg[l] = c_register_parameter_n++;
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
				if (c_register_parameter_n<8){
					reg[l] = c_register_parameter_n++;
				} else
					c_parameter_offset+=STACK_ELEMENT_SIZE;
				b_result_offset+=STACK_ELEMENT_SIZE;
				continue;
			case 'R':
				if (c_register_parameter_n<8){
					reg[l] = c_register_parameter_n++;
				} else
					c_parameter_offset+=STACK_ELEMENT_SIZE;
				b_result_offset+=8;
				continue;
			case 'S':
				if (c_register_parameter_n<8){
					reg[l] = c_register_parameter_n++;
				} else
					c_parameter_offset+=STACK_ELEMENT_SIZE;
				a_result_offset+=STACK_ELEMENT_SIZE;
				continue;
			case 'A':
				if (c_register_parameter_n<8){
					reg[l] = c_register_parameter_n++;
				} else
					c_parameter_offset+=STACK_ELEMENT_SIZE;
				++l;
				a_result_offset+=STACK_ELEMENT_SIZE;
				continue;
		}
	}

	if (!function_address_parameter)
		label = enter_c_function_name_label (c_function_name);

	c_stack_frame_size = (c_parameter_offset+15) & -16;
	if (c_stack_frame_size!=0)
		i_sub_i_r (c_stack_frame_size,REGISTER_X31);

	{
	int c_offset_before_pushing_arguments,function_address_reg,function_address_s_index;

	a_o=-b_result_offset-a_result_offset;
	b_o=0;

	if (a_result_offset+b_result_offset>b_offset){
		i_sub_i_r (a_result_offset+b_result_offset-b_offset,B_STACK_POINTER);
		c_offset=a_result_offset+b_result_offset;
	}

	c_offset_before_pushing_arguments=c_offset;

	i_move_r_r (B_STACK_POINTER,REGISTER_X29);

	for (l=length-1; l>=first_pointer_result_index; --l){
		switch (s[l]){
			case 'I':
			case 'p':
				b_o-=STACK_ELEMENT_SIZE;
				if (reg[l]<NO_REG)
					/*i_lea_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_X29,real_reg_n[reg[l]])*/;
				else {
					i_lea_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_X29,REGISTER_A3);
					c_parameter_offset-=STACK_ELEMENT_SIZE;
					i_move_r_id (REGISTER_A3,c_parameter_offset,REGISTER_X31);
				}
				break;
			case 'i':
			case 'r':
				--l;
			case 'S':
				if (reg[l]<NO_REG)
					/*i_lea_id_r (a_o+c_offset_before_pushing_arguments,REGISTER_X29,real_reg_n[reg[l]])*/;
				else {
					i_lea_id_r (a_o+c_offset_before_pushing_arguments,REGISTER_X29,REGISTER_A3);
					c_parameter_offset-=STACK_ELEMENT_SIZE;
					i_move_r_id (REGISTER_A3,c_parameter_offset,REGISTER_X31);
				}
				a_o+=STACK_ELEMENT_SIZE;
				break;
			case 'R':
				b_o-=8;
				if (reg[l]<NO_REG)
					/*i_lea_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_X29,real_reg_n[reg[l]])*/;
				else {
					i_lea_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_X29,REGISTER_A3);
					c_parameter_offset-=STACK_ELEMENT_SIZE;
					i_move_r_id (REGISTER_A3,c_parameter_offset,REGISTER_X31);
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
					if (reg[l]>=NO_REG){
						c_offset_1+=STACK_ELEMENT_SIZE;
					}
					break;
				case 'R':
					if (reg[l]>=NO_REG)
						c_offset_1+=8;
					break;
				case 'O':
				case 'F':
				case '*':
				case ']':
					while (l>=0 && (s[l]!='F' && s[l]!='O'))
						--l;
					if (reg[l]>=NO_REG)
						c_offset_1+=STACK_ELEMENT_SIZE;
					break;
			}
		}
		
		if (c_offset_1!=0){
			i_sub_i_r (c_offset_1,B_STACK_POINTER);
			c_offset += c_offset_1;
		}

		{
			int l,c_offset_2,not_finished,new_reg[7];
			
			new_reg[0]=new_reg[1]=new_reg[2]=new_reg[3]=new_reg[4]=new_reg[5]=new_reg[6]=-1;

			c_offset_2 = c_offset_1;
			reg_n=0;
			for (l=min_index-1; l>=0; --l){
				switch (s[l]){
					case 'I':
					case 'p':
						if (reg[l]<NO_REG){
							if (l<=last_register_parameter_index){
								if (reg[l]>6)
									i_move_r_r (REGISTER_D0+n_extra_clean_b_register_parameters+reg_n,real_reg_n[reg[l]]);
								else
									new_reg [6-reg[l]] = n_extra_clean_b_register_parameters+reg_n;
								++reg_n;
							}
						} else {
							c_offset_2-=STACK_ELEMENT_SIZE;
							if (l<=last_register_parameter_index){
								i_move_r_id (REGISTER_D0+n_extra_clean_b_register_parameters+reg_n,c_offset_2,B_STACK_POINTER);
								++reg_n;
							}
						}
						break;
					case 'S':
					case 's':
					case 'A':
						if (reg[l]>=NO_REG){
							c_offset_2-=STACK_ELEMENT_SIZE;
						}
						break;
					case 'R':
						if (reg[l]>=NO_REG)
							c_offset_2-=8;
						break;
					case 'O':
					case 'F':
					case '*':
					case ']':
						while (l>=0 && (s[l]!='F' && s[l]!='O'))
							--l;
						if (reg[l]<NO_REG){
							if (l<=last_register_parameter_index){
								if (reg[l]>6)
									i_move_r_r (REGISTER_D0+n_extra_clean_b_register_parameters+reg_n,real_reg_n[reg[l]]);
								else
									new_reg [6-reg[l]] = n_extra_clean_b_register_parameters+reg_n;
								++reg_n;
							}
						}
						break;
				}
			}
			
			do {
				int progress;
				
				not_finished=0;
				progress=0;

				for (reg_n=0; reg_n<=6; ++reg_n){
					int n;
				
					n=new_reg[reg_n];
					if (n>=0 && n!=reg_n){
						if (new_reg[0]!=reg_n && new_reg[1]!=reg_n && new_reg[2]!=reg_n && new_reg[3]!=reg_n &&
							new_reg[4]!=reg_n && new_reg[5]!=reg_n && new_reg[6]!=reg_n)
						{
							i_move_r_r (REGISTER_D0+n,REGISTER_D0+reg_n);
							new_reg[reg_n]=-1;
							progress=1;
						} else
							not_finished=1;
					}
				}
				
				if (!progress && not_finished)
					error_s (ccall_error_string,c_function_name);

			} while (not_finished); /* infinite loop in case of cycle */
		}

		reg_n=0;
		a_o=-a_offset;
		b_o=0;
		for (l=min_index-1; l>=0; --l){
			switch (s[l]){
				case 'I':
				case 'p':
					if (reg[l]<NO_REG){
						if (l<=last_register_parameter_index){
							/* i_move_r_r (REGISTER_D0+n_extra_clean_b_register_parameters+reg_n,real_reg_n[reg[l]]); */
							++reg_n;
						} else {
							b_o-=STACK_ELEMENT_SIZE;
							i_move_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_X29,real_reg_n[reg[l]]);
						}
					} else {
						c_offset_1-=STACK_ELEMENT_SIZE;
						if (l<=last_register_parameter_index){
							/* i_move_r_id (REGISTER_D0+n_extra_clean_b_register_parameters+reg_n,c_offset_1,B_STACK_POINTER); */
							++reg_n;
						} else {
							b_o-=STACK_ELEMENT_SIZE;
							i_move_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_X29,6/*r12*/);
							i_move_r_id (6/*r12*/,c_offset_1,B_STACK_POINTER);
						}
					}
					break;
				case 'S':
					if (reg[l]<NO_REG){
						i_move_id_r (a_o,A_STACK_POINTER,real_reg_n[reg[l]]);
						i_add_i_r (STACK_ELEMENT_SIZE,real_reg_n[reg[l]]);
					} else {
						c_offset_1-=STACK_ELEMENT_SIZE;
						i_move_id_r (a_o,A_STACK_POINTER,REGISTER_A0);
						i_add_i_r (STACK_ELEMENT_SIZE,REGISTER_A0);
						i_move_r_id (REGISTER_A0,c_offset_1,B_STACK_POINTER);
					}
					a_o+=STACK_ELEMENT_SIZE;
					break;
				case 'R':
					if (reg[l]<NO_REG){
						b_o-=8;
						i_fmove_id_fr (b_o+c_offset_before_pushing_arguments,REGISTER_X29,reg[l]);
					} else {
						c_offset_1-=8;
						b_o-=8;
						i_move_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_X29,6/*r12*/);
						i_move_r_id (6/*r12*/,c_offset_1,B_STACK_POINTER);
					}
					break;
				case 's':
					if (reg[l]<NO_REG){
						i_move_id_r (a_o,A_STACK_POINTER,real_reg_n[reg[l]]);
						i_add_i_r (2*STACK_ELEMENT_SIZE,real_reg_n[reg[l]]);							
					} else {
						c_offset_1-=STACK_ELEMENT_SIZE;
						i_move_id_r (a_o,A_STACK_POINTER,REGISTER_A0);
						i_add_i_r (2*STACK_ELEMENT_SIZE,REGISTER_A0);
						i_move_r_id (REGISTER_A0,c_offset_1,B_STACK_POINTER);
					}
					a_o+=STACK_ELEMENT_SIZE;
					break;
				case 'A':
					if (reg[l]<NO_REG){
						i_move_id_r (a_o,A_STACK_POINTER,real_reg_n[reg[l]]);
						i_add_i_r (3*STACK_ELEMENT_SIZE,real_reg_n[reg[l]]);							
					} else {
						c_offset_1-=STACK_ELEMENT_SIZE;
						i_move_id_r (a_o,A_STACK_POINTER,REGISTER_A0);
						i_add_i_r (3*STACK_ELEMENT_SIZE,REGISTER_A0);
						i_move_r_id (REGISTER_A0,c_offset_1,B_STACK_POINTER);
					}
					a_o+=STACK_ELEMENT_SIZE;
					break;
				case 'O':
				case 'F':
				case '*':
				case ']':
					while (l>=0 && (s[l]!='F' && s[l]!='O'))
						--l;
					if (reg[l]<NO_REG){
						if (l<=last_register_parameter_index){
							/* i_move_r_r (REGISTER_D0+n_extra_clean_b_register_parameters+reg_n,real_reg_n[reg[l]]); */
							++reg_n;
						} else {
							b_o-=STACK_ELEMENT_SIZE;
							i_move_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_X29,real_reg_n[reg[l]]);
						}
						
						function_address_reg = real_reg_n[reg[l]];
						function_address_s_index = l+1;
						break;
					}
				default:
					error_s (ccall_error_string,c_function_name);
			}
		}
	}

	a_o=-b_result_offset-a_result_offset;
	b_o=0;

	for (l=length-1; l>=first_pointer_result_index; --l){
		switch (s[l]){
			case 'I':
			case 'p':
				b_o-=STACK_ELEMENT_SIZE;
				if (reg[l]<NO_REG)
					i_lea_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_X29,real_reg_n[reg[l]]);
				break;
			case 'i':
			case 'r':
				--l;
			case 'S':
				if (reg[l]<NO_REG)
					i_lea_id_r (a_o+c_offset_before_pushing_arguments,REGISTER_X29,real_reg_n[reg[l]]);
				a_o+=STACK_ELEMENT_SIZE;
				break;
			case 'R':
				b_o-=8;
				if (reg[l]<NO_REG)
					i_lea_id_r (b_o+c_offset_before_pushing_arguments,REGISTER_X29,real_reg_n[reg[l]]);
				break;
			case 'V':
				break;
			default:
				error_s (ccall_error_string,c_function_name);
		}
	}

	if (save_state_in_global_variables){
		i_lea_l_i_r (saved_a_stack_p_label,0,REGISTER_D6);
		i_move_r_id (A_STACK_POINTER,0,REGISTER_D6);
		i_lea_l_i_r (saved_heap_p_label,0,REGISTER_D6);
		i_move_r_id (HEAP_POINTER,0,REGISTER_D6);
		i_move_r_id (6,8,6/*heap free counter*/);
	}

	i_move_r_r (REGISTER_X29,B_STACK_POINTER);

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
			
			i_move_id_r (n,function_address_reg,REGISTER_D6);
			function_address_reg = REGISTER_D6;
		}
		
		i_call_r (function_address_reg);
	}

	if (save_state_in_global_variables){
		i_lea_l_i_r (saved_a_stack_p_label,0,REGISTER_D6);
		i_move_id_r (0,REGISTER_D6,A_STACK_POINTER);
		i_lea_l_i_r (saved_heap_p_label,0,REGISTER_D6);
		i_move_id_r (0,REGISTER_D6,HEAP_POINTER);
		i_move_id_r (8,REGISTER_D6,6/*heap free counter*/);
	}
#if 0
	if (c_offset_before_pushing_arguments-(b_result_offset+a_result_offset)==0)
		i_move_r_r (REGISTER_X29,B_STACK_POINTER);
	else
		i_lea_id_r (c_offset_before_pushing_arguments-(b_result_offset+a_result_offset),REGISTER_X29,B_STACK_POINTER);		
#else
	if (c_offset_before_pushing_arguments-(b_result_offset+a_result_offset)!=0)
		i_lea_id_r (c_offset_before_pushing_arguments-(b_result_offset+a_result_offset),B_STACK_POINTER,B_STACK_POINTER);		
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
				i_jsr_l_idu (string_to_string_node_label,-8);
				i_move_r_id (REGISTER_A0,0,A_STACK_POINTER);
				i_add_i_r (STACK_ELEMENT_SIZE,A_STACK_POINTER);
				break;
			default:
				error_s (ccall_error_string,c_function_name);
		}
	}

	if (c_stack_frame_size!=0)
		i_add_i_r (c_stack_frame_size,REGISTER_X31);
		
	b_o=0;
	for (l=first_pointer_result_index; l<length; ++l){
		switch (s[l]){
			case 'I':
				i_loadsqb_id_r (b_o,B_STACK_POINTER,REGISTER_A3);
				i_move_r_id (REGISTER_A3,b_o,B_STACK_POINTER);
				b_o+=STACK_ELEMENT_SIZE;
				break;
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
			i_loadsqb_r_r (real_reg_n[0],real_reg_n[0]);
		case 'p':
			begin_new_basic_block();
			init_b_stack (7,i_i_i_i_i_i_i_vector);
			s_put_b (6,s_get_b (0));
			s_remove_b();
			s_remove_b();
			s_remove_b();
			s_remove_b();
			s_remove_b();
			s_remove_b();
			break;
		case 'V':
			begin_new_basic_block();
			break;
		case 'R':
			begin_new_basic_block();
			init_b_stack (2,r_vector);
			break;
		case 'S':
			if (string_to_string_node_label==NULL)
				string_to_string_node_label=enter_label ("string_to_string_node",IMPORT_LABEL);
			i_move_r_r (REGISTER_D6,REGISTER_A0);
			i_jsr_l_idu (string_to_string_node_label,-8);
			begin_new_basic_block();
			init_a_stack (1);
			break;
		default:
			error_s (ccall_error_string,c_function_name);
	}
}

