/*
	File:	cgwas.c
	Author:	John van Groningen
*/

#include <stdio.h>
#include <string.h>
#include <ctype.h>

#define MODULES

#include "cgport.h"

#ifndef G_POWER

#include "cgrconst.h"
#include "cgtypes.h"
#include "cg.h"
#include "cgiconst.h"
#include "cgcode.h"
#include "cginstructions.h"
#include "cgwas.h"

#pragma segment Code5

#define IO_BUF_SIZE 8192

#ifdef SUN
# define sun_flag 1
#else
# define sun_flag 0
#endif

static FILE *assembly_file;

static void w_as_newline (VOID)
{
	putc ('\n',assembly_file);
}

static void w_as_opcode (char *opcode)
{
	fprintf (assembly_file,"\t%s\t",opcode);
}

static void w_as_instruction_without_parameters (char *opcode)
{
	fprintf (assembly_file,"\t%s\n",opcode);
}

static void w_as_define_local_label (int label_number)
{
	fprintf (assembly_file,"l_%d:\n",label_number);
}

static void w_as_define_internal_label (int label_number)
{
	fprintf (assembly_file,"i_%d:\n",label_number);
}

#ifdef MODULES
void w_as_new_module (int flag)
{
	if (flag)
		fprintf (assembly_file,";\tmodule+\n");
	else
		fprintf (assembly_file,";\tmodule\n");
}
#endif

static int in_data_section;

void w_as_to_data_section (VOID)
{
	if (!in_data_section){
		in_data_section=1;
		w_as_instruction_without_parameters (sun_flag ? ".data" : "data");
	}
}

static void w_as_to_code_section (VOID)
{
	if (in_data_section){
		in_data_section=0;
		w_as_instruction_without_parameters (sun_flag ? ".text" : "code");
	}
}

void w_as_internal_label_value (int label_id)
{
	w_as_to_data_section();
	if (sun_flag)
		fprintf (assembly_file,"\t.long\ti_%d\n",label_id);
	else {
		fprintf (assembly_file,"\tdatarefs\trelative\n");
		fprintf (assembly_file,"\tdc.w\ti_%d\n",label_id);
		fprintf (assembly_file,"\tdatarefs\tabsolute\n");
	}
}

void w_as_word_in_data_section (int n)
{
	w_as_to_data_section();
	w_as_opcode (sun_flag ? ".word" : "dc.w");
	fprintf (assembly_file,"%d",n);
	w_as_newline();
}

void w_as_long_in_data_section (long n)
{
	w_as_to_data_section();
	w_as_opcode (sun_flag ? ".long" : "dc.l");
	fprintf (assembly_file,"%d",n);
	w_as_newline();
}

void w_as_label_in_data_section (char *label_name)
{
	w_as_to_data_section ();
	if (sun_flag)
		fprintf (assembly_file,"\t.long\t%s\n",label_name);
	else {
		fprintf (assembly_file,"\tdatarefs\trelative\n");
		fprintf (assembly_file,"\tdc.w\t%s\n",label_name);
		fprintf (assembly_file,"\tdatarefs\tabsolute\n");
	}
}

void w_as_descriptor_in_data_section (char *label_name)
{
	w_as_to_data_section ();
	if (sun_flag)
		fprintf (assembly_file,"\t.long\t%s\n",label_name);
	else
		fprintf (assembly_file,"\tdc.l\t%s\n",label_name);
}

void w_as_descriptor_in_code_section (char *label_name)
{
	w_as_to_code_section ();
	if (sun_flag)
		fprintf (assembly_file,"\t.long\t%s\n",label_name);
	else
		fprintf (assembly_file,"\tdc.l\t%s\n",label_name);
}

static void w_as_label_in_code_section (char *label_name)
{
	w_as_to_code_section ();
	if (sun_flag)
		fprintf (assembly_file,"\t.long\t%s\n",label_name);
	else {
		fprintf (assembly_file,"\tdatarefs\trelative\n");
		fprintf (assembly_file,"\tdc.w\t%s\n",label_name);
		fprintf (assembly_file,"\tdatarefs\tabsolute\n");
	}
}

#define MAX_BYTES_PER_LINE 16

static int w_as_data (int n,unsigned char *data,int length)
{
	register int i,in_string;
	
	in_string=0;
	
	for (i=0; i<length; ++i){
		int c;
		
		if (n>=MAX_BYTES_PER_LINE){
			if (in_string){
				putc ('\"',assembly_file);
				in_string=0;
			}
			w_as_newline();
			n=0;
		}
		if (n==0)
			w_as_opcode (sun_flag ? ".byte" : "dc.b");
		else
			if (!in_string)
				putc (',',assembly_file);
		
		c=data[i];
		if (isalnum (c) || c=='_' || c==' '){
			if (!in_string){
				putc ('\"',assembly_file);
				in_string=1;
			}
			putc (c,assembly_file);
		} else {
			if (in_string){
				putc ('\"',assembly_file);
				putc (',',assembly_file);
				in_string=0;
			}
			fprintf (assembly_file,sun_flag ? "0x%02x" : "$%02x",c);
		}
		++n;
	}
	
	if (in_string)
		putc ('\"',assembly_file);

	return n;
}

static int w_as_zeros (register int n,register int length)
{
	register int i;
	
	for (i=0; i<length; ++i){
		if (n>=MAX_BYTES_PER_LINE){
			w_as_newline();
			n=0;
		}
		if (n==0)
			w_as_opcode (sun_flag ? ".byte" : "dc.b");
		else
			putc (',',assembly_file);
		fprintf (assembly_file,"0");
		++n;
	}
	return n;
}

void w_as_c_string_in_code_section (char *string,int length,int label_number)
{
	register int n;
	
	w_as_to_code_section();
	
	w_as_define_local_label (label_number);
	
	n=w_as_data (0,(unsigned char *)string,length);
	n=w_as_zeros (n,length & 1 ? 1 : 2);
	if (n>0)
		w_as_newline();
}

void w_as_define_local_label_in_code_section (int label_number)
{	
	w_as_to_code_section();
	
	w_as_define_local_label (label_number);	
}

void w_as_abc_string_in_code_section (char *string,int length)
{
	int n;
	
	w_as_to_code_section();
		
	w_as_opcode (sun_flag ? ".long" : "dc.l");
	fprintf (assembly_file,"%d\n",length);
	n=w_as_data (0,(unsigned char *)string,length);
	if (length & 3)
		n=w_as_zeros (n,4-(length & 3));
	if (n>0)
		w_as_newline();
}

void w_as_c_string_in_data_section (char *string,int length)
{
	register int n;
	
	w_as_to_data_section();
		
	n=w_as_data (0,(unsigned char *)string,length);

	n=w_as_zeros (n,4-(length & 3));
/*	n=w_as_zeros (n,length & 1 ? 1 : 2); */

	if (n>0)
		w_as_newline();
}

void w_as_descriptor_string_in_code_section
	(char *string,int length,int string_code_label_id,LABEL *string_label)
{
	register int n;
	
	w_as_to_code_section();
	
	w_as_define_internal_label (string_code_label_id);
	
	if (!sun_flag){
		fprintf (assembly_file,"\tlea\t6+*(pc),a0\n");
		fprintf (assembly_file,"\trts\n");
#ifdef MODULES
		w_as_new_module (1);
#endif
	}
	
	w_as_define_local_label (string_label->label_number);
	
	w_as_opcode (sun_flag ? ".long" : "dc.l");
	fprintf (assembly_file,"%d\n",length);
	n=w_as_data (0,(unsigned char *)string,length);
	if (length & 3)
		n=w_as_zeros (n,4-(length & 3));
	if (n>0)
		w_as_newline();
}

enum { SIZE_LONG, SIZE_WORD, SIZE_BYTE };

static void w_as_opcode_and_size (char *opcode,int size_flag)
{
	switch (size_flag){
		case SIZE_BYTE:
	 		fprintf (assembly_file,sun_flag ? "\t%sb\t" : "\t%s.b\t",opcode);
			return;
		case SIZE_WORD:
	 		fprintf (assembly_file,sun_flag ? "\t%sw\t" : "\t%s.w\t",opcode);
			return;
		case SIZE_LONG:
	 		fprintf (assembly_file,sun_flag ? "\t%sl\t" : "\t%s.l\t",opcode);
			return;
		default:
			internal_error_in_function ("w_as_opcode_and_size");
	}
}

static void w_as_opcode_and_d (char *opcode)
{
	fprintf (assembly_file,sun_flag ? "\t%sd\t" : "\t%s.d\t",opcode);
}

static void w_as_opcode_and_x (char *opcode)
{
	fprintf (assembly_file,sun_flag ? "\t%sx\t" : "\t%s.x\t",opcode);
}

static void w_as_label (register char *label)
{
	int c;
	
	while (c=*label++,c!=0)
		putc (c,assembly_file);
}

static void w_as_colon (VOID)
{
	putc (':',assembly_file);
}

static void w_as_define_label_name (char *label_name)
{
	w_as_label (label_name);
	w_as_colon();
	w_as_newline();
}

void w_as_define_label (LABEL *label)
{
	if (label->label_flags & EXPORT_LABEL){
		w_as_opcode (sun_flag ? ".globl" : "export");
		w_as_label (label->label_name);
		w_as_newline();
	}
			
	w_as_label (label->label_name);
	w_as_colon();
	w_as_newline();
}

static void w_as_local_label (int label_number)
{
	fprintf (assembly_file,"l_%d",label_number);
}

static void w_as_internal_label (int label_number)
{
	fprintf (assembly_file,"i_%d",label_number);
}

void w_as_abc_string_and_label_in_code_section (char *string,int length,char *label_name)
{
	int n;
	
	w_as_to_code_section();
	
	w_as_define_label_name (label_name);
	
	w_as_opcode (sun_flag ? ".long" : "dc.l");
	fprintf (assembly_file,"%d\n",length);
	n=w_as_data (0,(unsigned char *)string,length);
	if (length & 3)
		n=w_as_zeros (n,4-(length & 3));
	if (n>0)
		w_as_newline();
}

static void w_as_immediate (LONG i)
{
	fprintf (assembly_file,"#%ld",i);
}

static void w_as_indirect (int i,int reg)
{
	if (sun_flag)
		fprintf (assembly_file,"a%d@(%d)",a_reg_num (reg),i);
	else
		fprintf (assembly_file,"%d(a%d)",i,a_reg_num (reg));
}

static void w_as_register (int reg)
{
	if (is_d_register (reg))
		fprintf (assembly_file,"d%d",d_reg_num (reg));
	else
		fprintf (assembly_file,"a%d",a_reg_num (reg));
}

static struct relocatable_words_list *first_relocatable_word,*last_relocatable_word;
static int n_relocatable_words,n_relocatable_longs;

static void w_as_null_descriptor (char *label_name)
{
	if (sun_flag){
		fprintf (assembly_file,"rl_%d:",n_relocatable_longs++);
		w_as_opcode (".long");
		fprintf (assembly_file,"%s\n",label_name);
	} else {
		fprintf (assembly_file,"\tdatarefs\trelative\n");
		fprintf (assembly_file,"\tdc.w\t%s\n",label_name);
		fprintf (assembly_file,"\tdatarefs\tabsolute\n");
	}
}

static void w_as_opcode_immediate_descriptor (char *opcode,char *label_name,int arity,int size_flag)
{
	if (sun_flag){
		if (size_flag==SIZE_WORD){
			struct relocatable_words_list *new_relocatable_word;
			
			fprintf (assembly_file,"rw_%d:",n_relocatable_words++);
			w_as_opcode (opcode);
			fprintf (assembly_file,"#%d",arity<<3);
			
			new_relocatable_word=(struct relocatable_words_list*)fast_memory_allocate (sizeof (struct relocatable_words_list));
			new_relocatable_word->relocatable_next=NULL;
			new_relocatable_word->relocatable_label_name=label_name;
			if (first_relocatable_word==NULL)
				first_relocatable_word=new_relocatable_word;
			else
				last_relocatable_word->relocatable_next=new_relocatable_word;
			last_relocatable_word=new_relocatable_word;
		} else {
			fprintf (assembly_file,"rl_%d:",n_relocatable_longs++);
			w_as_opcode (opcode);
			fprintf (assembly_file,"#%s",label_name);
			if (arity!=0)
				fprintf (assembly_file,"+%d",arity<<3);
		}
	} else {
		w_as_opcode (opcode);
		fprintf (assembly_file,"#%s",label_name);
		if (arity!=0)
			fprintf (assembly_file,"+%d",arity<<2);
	}
}

static void w_as_comma (VOID)
{
	putc (',',assembly_file);
}

static void w_as_minus (VOID)
{
	putc ('-',assembly_file);
}

static void w_as_slash (VOID)
{
	putc ('/',assembly_file);
}
	
static void w_as_parameter (register struct parameter *parameter)
{
	switch (parameter->parameter_type){
		case P_REGISTER:
		{
			int reg=parameter->parameter_data.reg.r;
			if (is_d_register (reg))
				fprintf (assembly_file,"d%d",d_reg_num (reg));
			else
				fprintf (assembly_file,"a%d",a_reg_num (reg));
			break;
		}
		case P_LABEL:
			if (parameter->parameter_data.l->label_number!=0)
				w_as_local_label (parameter->parameter_data.l->label_number);
			else
				w_as_label (parameter->parameter_data.l->label_name);
			break;
		case P_INDIRECT:
			if (sun_flag){
				if (parameter->parameter_offset==0)
					fprintf (assembly_file,"a%d@",a_reg_num (parameter->parameter_data.reg.r));
				else
					fprintf (assembly_file,"a%d@(%d)",a_reg_num (parameter->parameter_data.reg.r),
							parameter->parameter_offset);
			} else {
				if (parameter->parameter_offset==0)
					fprintf (assembly_file,"(a%d)",a_reg_num (parameter->parameter_data.reg.r));
				else
					fprintf (assembly_file,"%d(a%d)",parameter->parameter_offset,
							a_reg_num (parameter->parameter_data.reg.r));
			}
			break;
		case P_IMMEDIATE:
			fprintf (assembly_file,"#%ld",parameter->parameter_data.i);
			break;
		case P_POST_INCREMENT:
			if (sun_flag)
				fprintf (assembly_file,"a%d@+",a_reg_num (parameter->parameter_data.reg.r));
			else
				fprintf (assembly_file,"(a%d)+",a_reg_num (parameter->parameter_data.reg.r));	
			break;
		case P_PRE_DECREMENT:
			if (sun_flag)
				fprintf (assembly_file,"a%d@-",a_reg_num (parameter->parameter_data.reg.r));
			else
				fprintf (assembly_file,"-(a%d)",a_reg_num (parameter->parameter_data.reg.r));
			break;
		case P_F_REGISTER:
			fprintf (assembly_file,"fp%d",parameter->parameter_data.reg.r);
			break;
		case P_F_IMMEDIATE:
			fprintf (assembly_file,sun_flag ? "#0r%.20e" : "#\"%g\"",*parameter->parameter_data.r);
			break;
		case P_INDEXED:
		{
			struct index_registers *index_registers;
			int offset;
			
			index_registers=parameter->parameter_data.ir;
			offset=parameter->parameter_offset;
			
			if ((offset & 3)==0)
				fprintf (assembly_file,"%d(a%d,d%d.l)",offset>>2,
					a_reg_num (index_registers->a_reg.r),d_reg_num (index_registers->d_reg.r));
			else
				fprintf (assembly_file,"%d(a%d,d%d.l*%d)",offset>>2,
					a_reg_num (index_registers->a_reg.r),d_reg_num (index_registers->d_reg.r),
					1<<(offset & 3));
			break;
		}
		default:
			internal_error_in_function ("w_as_parameter");
	}
}

static void w_as_move_instruction (struct instruction *instruction,int size_flag)
{
	if (size_flag==SIZE_LONG
		&& instruction->instruction_parameters[0].parameter_type==P_DESCRIPTOR_NUMBER)
	{
		w_as_opcode_immediate_descriptor (
			sun_flag ? "movel" : "moved",
			instruction->instruction_parameters[0].parameter_data.l->label_name,
			instruction->instruction_parameters[0].parameter_offset,SIZE_LONG
		);
		w_as_comma();
		w_as_parameter (&instruction->instruction_parameters[1]);
		w_as_newline();
		return;
	}

	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		LONG i;
		
		i=instruction->instruction_parameters[0].parameter_data.i;
		
		if (size_flag==SIZE_LONG && i<128 && i>=-128
			&& instruction->instruction_parameters[1].parameter_type==P_REGISTER
			&& is_d_register (instruction->instruction_parameters[1].parameter_data.reg.r))
		{
			w_as_opcode ("moveq");
			w_as_immediate (i);
			w_as_comma();
			w_as_parameter (&instruction->instruction_parameters[1]);
			w_as_newline();
			return;
		}
		
		if (i==0 && instruction->instruction_parameters[1].parameter_type!=P_REGISTER){
			w_as_opcode_and_size ("clr",size_flag);
			w_as_parameter (&instruction->instruction_parameters[1]);
			w_as_newline();
			return;
		}
	}
	
	w_as_opcode_and_size ("move",size_flag);
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_comma();
	w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_newline();
}

static void w_as_dyadic_instruction (struct instruction *instruction,char *opcode)
{
	w_as_opcode (opcode);
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_comma();
	w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_newline();
}

static void w_as_lea_instruction (struct instruction *instruction)
{
	w_as_opcode ("lea");
	w_as_parameter (&instruction->instruction_parameters[0]);
	if (instruction->instruction_parameters[0].parameter_type==P_LABEL &&
		instruction->instruction_parameters[0].parameter_offset!=0)
	{
		int offset;
		
		offset=instruction->instruction_parameters[0].parameter_offset;
		fprintf (assembly_file,offset>=0 ? "+%d" : "%d",offset);
	}
	w_as_comma();
	w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_newline();
}

static void w_as_dyadic_float_instruction (struct instruction *instruction,char *opcode)
{
	if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER
		&& instruction->instruction_parameters[1].parameter_type==P_F_REGISTER)
	{
		if (sun_flag)
			w_as_opcode_and_x (opcode);
		else
			w_as_opcode (opcode);
	} else
		w_as_opcode_and_d (opcode);
	
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_comma();
	w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_newline();
}

static void w_as_monadic_instruction (struct instruction *instruction,char *opcode)
{
	w_as_opcode (opcode);
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();
}

static void w_as_add_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER
		&& instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE)
	{
		LONG i=instruction->instruction_parameters[0].parameter_data.i;
		
		if (i<=8 && i>=-8 && i!=0){
			if (i>0){
				w_as_opcode_and_size ("addq",SIZE_LONG);
				w_as_immediate ((LONG)i);
				w_as_comma();
				w_as_parameter (&instruction->instruction_parameters[1]);
				w_as_newline();
			} else {
				w_as_opcode_and_size ("subq",SIZE_LONG);
				w_as_immediate ((LONG)-i);
				w_as_comma();
				w_as_parameter (&instruction->instruction_parameters[1]);
				w_as_newline();
			}
			return;
		} else {
			int reg;
			
			reg=instruction->instruction_parameters[1].parameter_data.reg.r;
			if (is_a_register (reg) && i>=-32768 && i<32768){
				w_as_opcode ("lea");
				w_as_indirect ((int)i,reg);
				w_as_comma();
				w_as_parameter (&instruction->instruction_parameters[1]);
				w_as_newline();
				return;
			}
		}
	}
	w_as_opcode_and_size ("add",SIZE_LONG);
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_comma();
	w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_newline();
}

static void w_as_sub_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER
		&& instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE)
	{
		LONG i=instruction->instruction_parameters[0].parameter_data.i;
		
		if (i<=8 && i>=-8 && i!=0){
			if (i>0){
				w_as_opcode_and_size ("subq",SIZE_LONG);
				w_as_immediate ((LONG)i);
				w_as_comma();
				w_as_parameter (&instruction->instruction_parameters[1]);
				w_as_newline();
			} else {
				w_as_opcode_and_size ("addq",SIZE_LONG);
				w_as_immediate ((LONG)-i);
				w_as_comma();
				w_as_parameter (&instruction->instruction_parameters[1]);
				w_as_newline();
			}
			return;
		} else {
			int reg;
			
			reg=instruction->instruction_parameters[1].parameter_data.reg.r;
			if (is_a_register (reg) && i>-32768 && i<=32768){
				w_as_opcode ("lea");
				w_as_indirect ((int)-i,reg);
				w_as_comma();
				w_as_parameter (&instruction->instruction_parameters[1]);
				w_as_newline();
				return;
			}
		}
	}
	w_as_opcode_and_size ("sub",SIZE_LONG);
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_comma();
	w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_newline();
}

static void w_as_cmp_instruction (struct instruction *instruction,int size_flag)
{
	if (instruction->instruction_parameters[0].parameter_type==P_DESCRIPTOR_NUMBER){
		switch (size_flag){
			case SIZE_WORD:
				w_as_opcode_immediate_descriptor (
					sun_flag ? "cmpw" : "cmpdw",
					instruction->instruction_parameters[0].parameter_data.l->label_name,
					instruction->instruction_parameters[0].parameter_offset,SIZE_WORD
				);
				break;
			case SIZE_LONG:
				w_as_opcode_immediate_descriptor (
					sun_flag ? "cmpl" : "cmpd",
					instruction->instruction_parameters[0].parameter_data.l->label_name,
					instruction->instruction_parameters[0].parameter_offset,SIZE_LONG
				);
				break;
			default:
				internal_error_in_function ("w_as_cmp_instruction");
		}
		w_as_comma();
		w_as_parameter (&instruction->instruction_parameters[1]);
		w_as_newline();
		return;
	}
	
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE
		&& instruction->instruction_parameters[0].parameter_data.i==0
		&& (instruction->instruction_parameters[1].parameter_type!=P_REGISTER
			|| is_d_register (instruction->instruction_parameters[1].parameter_data.reg.r)))
	{
		w_as_opcode_and_size ("tst",size_flag);
		w_as_parameter (&instruction->instruction_parameters[1]);
		w_as_newline();
	} else {
		w_as_opcode_and_size ("cmp",size_flag);
		w_as_parameter (&instruction->instruction_parameters[0]);
		w_as_comma();
		w_as_parameter (&instruction->instruction_parameters[1]);
		w_as_newline();
	}
}

static void w_as_tst_instruction (struct instruction *instruction)
{
	w_as_opcode_and_size ("tst",SIZE_LONG);
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();
}

static void w_as_jsr_schedule (unsigned int n_a_and_f_registers)
{
	if (n_a_and_f_registers & 15){
		if ((n_a_and_f_registers & 15)==1){
			w_as_opcode ("fmove");
			fprintf (assembly_file,"fp0");
		} else {
			w_as_opcode ("fmovem");
			fprintf (assembly_file,"fp0-fp%d",(n_a_and_f_registers & 15)-1);
		}
		fprintf (assembly_file,",-(sp)\n");
	}

	w_as_opcode ("jsr");
	switch (n_a_and_f_registers>>4){
		case 0:		w_as_label (schedule_0_label->label_name);	break;
		case 1:		w_as_label (schedule_1_label->label_name);	break;
		case 2:		w_as_label (schedule_2_label->label_name);	break;
		case 3:		w_as_label (schedule_3_label->label_name);	break;
		case 256>>4:w_as_label (schedule_eval_label->label_name);	break;
		default:	internal_error_in_function ("w_as_jsr_schedule");
	}
	w_as_newline();

	if (n_a_and_f_registers & 15){
		if ((n_a_and_f_registers & 15)==1){
			w_as_opcode ("fmove");
			fprintf (assembly_file,"(sp)+,fp0\n");
		} else {
			w_as_opcode ("fmovem");
			fprintf (assembly_file,"(sp)+,fp0-fp%d\n",(n_a_and_f_registers & 15)-1);
		}
	}
}

static void w_as_jmp_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_LABEL
		&& instruction->instruction_parameters[0].parameter_data.l->label_flags & LOCAL_LABEL
	){
		if (parallel_flag){
			w_as_opcode ("dbra");
			w_as_register (REGISTER_D6);
			w_as_comma();
			w_as_parameter (&instruction->instruction_parameters[0]);
			w_as_newline();
			
			w_as_jsr_schedule (instruction->instruction_parameters[0].parameter_offset);
		}
		w_as_opcode ("bra");
	} else {
		if (parallel_flag){
			int n_a_and_f_registers;
			
			if (instruction->instruction_parameters[0].parameter_type==P_LABEL)
				n_a_and_f_registers=instruction->instruction_parameters[0].parameter_offset;
			else
				n_a_and_f_registers=instruction->instruction_parameters[0].parameter_data.reg.u;
	
			if (n_a_and_f_registers!=128){
				w_as_opcode ("dbra");
				w_as_register (REGISTER_D6);
				w_as_comma();
		
				fprintf (assembly_file,"%d(pc)",(n_a_and_f_registers & 15) ? 16 : 8);
				w_as_newline();
				
				w_as_jsr_schedule (n_a_and_f_registers);
			}				
		}
		w_as_opcode (sun_flag ? "jra" : "jmp");
	}
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();
}

static void w_as_jsr_instruction (struct instruction *instruction)
{	
	if (instruction->instruction_parameters[0].parameter_type==P_LABEL
		&& instruction->instruction_parameters[0].parameter_data.l->label_flags & LOCAL_LABEL
	){
		if (parallel_flag){
			int n_a_and_f_registers;
			
			n_a_and_f_registers=instruction->instruction_parameters[0].parameter_offset;
			
			w_as_opcode ("pea");
			fprintf (assembly_file,"%d(pc)",(n_a_and_f_registers & 15) ? 24 : 16);
			w_as_newline();
			
			w_as_opcode ("dbra");
			w_as_register (REGISTER_D6);
			w_as_comma();
			w_as_parameter (&instruction->instruction_parameters[0]);
			w_as_newline();

			w_as_jsr_schedule (n_a_and_f_registers);
			w_as_opcode ("bra");
		} else
			w_as_opcode ("bsr");
	} else {
		if (parallel_flag){
			int n_a_and_f_registers;
			
			w_as_opcode ("dbra");
			w_as_register (REGISTER_D6);
			w_as_comma();
			
			if (instruction->instruction_parameters[0].parameter_type==P_LABEL)
				n_a_and_f_registers=instruction->instruction_parameters[0].parameter_offset;
			else
				n_a_and_f_registers=instruction->instruction_parameters[0].parameter_data.reg.u;

			fprintf (assembly_file,"%d(pc)",(n_a_and_f_registers & 15) ? 16 : 8);
			w_as_newline();
			
			w_as_jsr_schedule (n_a_and_f_registers);
		}
		w_as_opcode (sun_flag ? "jbsr": "jsr");
	}
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();
}

static void w_as_extb_instruction (struct instruction *instruction)
{
	if (!mc68000_flag){
		w_as_opcode_and_size ("extb",SIZE_LONG);
		w_as_parameter (&instruction->instruction_parameters[0]);
		w_as_newline();
	} else {
		w_as_opcode_and_size ("ext",SIZE_WORD);
		w_as_parameter (&instruction->instruction_parameters[0]);
		w_as_newline();
		w_as_opcode_and_size ("ext",SIZE_LONG);
		w_as_parameter (&instruction->instruction_parameters[0]);
		w_as_newline();
	}
}

static void w_as_set_condition_instruction (struct instruction *instruction,char *opcode)
{
	w_as_monadic_instruction (instruction,opcode);
	
	w_as_extb_instruction (instruction);
}

static void w_as_movem_instruction (struct instruction *instruction)
{
	int first_register_index,last_register_index,register_index;
	int previous_register,previous_count;
	
	w_as_opcode_and_size ("movem",SIZE_LONG);
	
	if (instruction->instruction_parameters[0].parameter_type!=P_REGISTER){
		w_as_parameter (&instruction->instruction_parameters[0]);
		first_register_index=1;
		last_register_index=instruction->instruction_arity-1;
		w_as_comma();
		if (sun_flag && last_register_index==1)
			previous_count=1;
		else
			previous_count=0;
	} else {
		first_register_index=0;
		last_register_index=instruction->instruction_arity-2;
		previous_count=0;
	}
	
	previous_register=instruction->instruction_parameters[first_register_index].parameter_data.reg.r;
	w_as_register (previous_register);
	
	for (register_index=first_register_index+1; register_index<=last_register_index; ++register_index){
		int reg;
		
		reg=instruction->instruction_parameters[register_index].parameter_data.reg.r;
		if (is_d_register (reg) 
			? is_d_register (previous_register) && d_reg_num (previous_register)+1==d_reg_num (reg)
			: is_a_register (previous_register) && a_reg_num (previous_register)+1==a_reg_num (reg))
		{
			++previous_count;
			previous_register=reg;
		} else {
			if (previous_count>1)
				w_as_minus();
			else
				w_as_slash();
			if (previous_count>0)
				w_as_register (previous_register);
			w_as_slash();
			w_as_register (reg);
			previous_register=reg;
			previous_count=0;
		}
	}
	
	if (previous_count>0){
		if (previous_count>1)
			w_as_minus();
		else
			w_as_slash();
		w_as_register (previous_register);
	}
	
	if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
		w_as_comma();
		w_as_parameter (&instruction->instruction_parameters[instruction->instruction_arity-1]);
	}
	
	w_as_newline();
}

static void w_as_mod_instruction (struct instruction *instruction)
{
	w_as_opcode (sun_flag ? "divsll" : "tdivs.l");
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_comma();
	w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_colon();
	w_as_parameter (&instruction->instruction_parameters[2]);
	w_as_newline();
}

static int next_bmove_label;

static void w_as_bmove_instruction (struct instruction *instruction)
{
	char label_1_string[12],label_2_string[12];
	
	sprintf (label_1_string,"b%d",next_bmove_label++);
	sprintf (label_2_string,"b%d",next_bmove_label++);
	
	w_as_opcode (sun_flag ? "bras" : "bra.s");
	w_as_label (label_2_string);
	w_as_newline();
	
	w_as_define_label_name (label_1_string);
	
	w_as_opcode_and_size ("move",SIZE_LONG);
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_comma();
	w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_newline();
	
	w_as_define_label_name (label_2_string);
	
	w_as_opcode ("dbra");
	w_as_parameter (&instruction->instruction_parameters[2]);
	w_as_comma();
	w_as_label (label_1_string);
	w_as_newline();
}

static void w_as_eor_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE
		&& instruction->instruction_parameters[0].parameter_data.i==-1)
	{
		w_as_opcode_and_size ("not",SIZE_LONG);
		w_as_parameter (&instruction->instruction_parameters[1]);
		w_as_newline();
	} else
		w_as_dyadic_instruction (instruction,sun_flag ? "eorl" : "eor.l");
}

static void w_as_ext_instruction (struct instruction *instruction)
{
	w_as_opcode_and_size ("ext",SIZE_LONG);
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();
}

static void w_as_word_instruction (struct instruction *instruction)
{
	fprintf (assembly_file,sun_flag ? "\t.word\t%d\n" : "\tdc.w\t%d\n",
			(int)instruction->instruction_parameters[0].parameter_data.i);
}

static void w_as_instructions (register struct instruction *instruction)
{
	while (instruction!=NULL){
		switch (instruction->instruction_icode){
			case IMOVE:
				w_as_move_instruction (instruction,SIZE_LONG);
				break;
			case ILEA:
				w_as_lea_instruction (instruction);
				break;
			case IADD:
				w_as_add_instruction (instruction);
				break;
			case ISUB:
				w_as_sub_instruction (instruction);
				break;
			case ICMP:
				w_as_cmp_instruction (instruction,SIZE_LONG);
				break;
			case IJMP:
				w_as_jmp_instruction (instruction);
				break;
			case IJSR:
				w_as_jsr_instruction (instruction);
				break;
			case IRTS:
				w_as_instruction_without_parameters ("rts");
				break;
			case IBEQ:
				w_as_monadic_instruction (instruction,"beq");
				break;
			case IBGE:
				w_as_monadic_instruction (instruction,"bge");
				break;
			case IBGT:
				w_as_monadic_instruction (instruction,"bgt");
				break;
			case IBHS:
				w_as_monadic_instruction (instruction,"bhs");
				break;
			case IBLE:
				w_as_monadic_instruction (instruction,"ble");
				break;
			case IBLT:
				w_as_monadic_instruction (instruction,"blt");
				break;
			case IBNE:
				w_as_monadic_instruction (instruction,"bne");
				break;
			case IBMI:
				w_as_monadic_instruction (instruction,"bmi.s");
				break;
			case ILSL:
				w_as_dyadic_instruction (instruction,sun_flag ? "lsll" : "lsl.l");
				break;
			case ILSR:
				w_as_dyadic_instruction (instruction,sun_flag ? "lsrl" : "lsr.l");
				break;
			case IASR:
				w_as_dyadic_instruction (instruction,sun_flag ? "asrl" : "asr.l");
				break;
			case IMUL:
				w_as_dyadic_instruction (instruction,sun_flag ? "mulsl" : "muls.l");
				break;
			case IDIV:
				w_as_dyadic_instruction (instruction,sun_flag ? "divsl" : "divs.l");
				break;
			case IEXG:
				w_as_dyadic_instruction (instruction,"exg");
				break;
			case IREM:
				w_as_mod_instruction (instruction);
				break;
			case IMOVEM:
				w_as_movem_instruction (instruction);
				break;
			case IBMOVE:
				w_as_bmove_instruction (instruction);
				break;
			case IAND:
				w_as_dyadic_instruction (instruction,sun_flag ? "andl" : "and.l");
				break;
			case IOR:
				w_as_dyadic_instruction (instruction,sun_flag ? "orl" : "or.l");
				break;
			case IEOR:
				w_as_eor_instruction (instruction);
				break;
			case ISEQ:
				w_as_set_condition_instruction (instruction,"seq");
				break;
			case ISGE:
				w_as_set_condition_instruction (instruction,"sge");
				break;
			case ISGT:
				w_as_set_condition_instruction (instruction,"sgt");
				break;
			case ISLE:
				w_as_set_condition_instruction (instruction,"sle");
				break;
			case ISLT:
				w_as_set_condition_instruction (instruction,"slt");
				break;
			case ISNE:
				w_as_set_condition_instruction (instruction,"sne");
				break;
			case ICMPW:
				w_as_cmp_instruction (instruction,SIZE_WORD);
				break;
			case ITST:
				w_as_tst_instruction (instruction);
				break;
			case IMOVEDB:
				w_as_move_instruction (instruction,SIZE_WORD);
				break;
			case IMOVEB:
				w_as_move_instruction (instruction,SIZE_BYTE);
				break;
			case IFMOVE:
				w_as_dyadic_float_instruction (instruction,"fmove");
				break;
			case IFADD:
				w_as_dyadic_float_instruction (instruction,"fadd");
				break;
			case IFSUB:
				w_as_dyadic_float_instruction (instruction,"fsub");
				break;
			case IFCMP:
				w_as_dyadic_float_instruction (instruction,"fcmp");
				break;
			case IFDIV:
				w_as_dyadic_float_instruction (instruction,"fdiv");
				break;
			case IFMUL:
				w_as_dyadic_float_instruction (instruction,"fmul");
				break;
			case IFREM:
				w_as_dyadic_float_instruction (instruction,"frem");
				break;
			case IFBEQ:
				w_as_monadic_instruction (instruction,"fbeq");
				break;
			case IFBGE:
				w_as_monadic_instruction (instruction,"fbge");
				break;
			case IFBGT:
				w_as_monadic_instruction (instruction,"fbgt");
				break;
			case IFBLE:
				w_as_monadic_instruction (instruction,"fble");
				break;
			case IFBLT:
				w_as_monadic_instruction (instruction,"fblt");
				break;
			case IFBNE:
				w_as_monadic_instruction (instruction,"fbne");
				break;
			case IFMOVEL:
				w_as_dyadic_instruction (instruction,sun_flag ? "fmovel" : "fmove.l");
				break;
			case IFACOS:
				w_as_dyadic_float_instruction (instruction,"facos");
				break;
			case IFASIN:
				w_as_dyadic_float_instruction (instruction,"fasin");
				break;
			case IFATAN:
				w_as_dyadic_float_instruction (instruction,"fatan");
				break;
			case IFCOS:
				w_as_dyadic_float_instruction (instruction,"fcos");
				break;
			case IFEXP:
				w_as_dyadic_float_instruction (instruction,"fetox");
				break;
			case IFLN:
				w_as_dyadic_float_instruction (instruction,"flogn");
				break;
			case IFLOG10:
				w_as_dyadic_float_instruction (instruction,"flog10");
				break;
			case IFNEG:
				w_as_dyadic_float_instruction (instruction,"fneg");
				break;
			case IFSIN:
				w_as_dyadic_float_instruction (instruction,"fsin");
				break;
			case IFSQRT:
				w_as_dyadic_float_instruction (instruction,"fsqrt");
				break;
			case IFTAN:
				w_as_dyadic_float_instruction (instruction,"ftan");
				break;
			case IFSEQ:
				w_as_set_condition_instruction (instruction,"fseq");
				break;
			case IFSGE:
				w_as_set_condition_instruction (instruction,"fsge");
				break;
			case IFSGT:
				w_as_set_condition_instruction (instruction,"fsgt");
				break;
			case IFSLE:
				w_as_set_condition_instruction (instruction,"fsle");
				break;
			case IFSLT:
				w_as_set_condition_instruction (instruction,"fslt");
				break;
			case IFSNE:
				w_as_set_condition_instruction (instruction,"fsne");
				break;
			case IWORD:
				w_as_word_instruction (instruction);
				break;
			case ISCHEDULE:
				w_as_jsr_schedule (instruction->instruction_parameters[0].parameter_data.i);
				break;
			case IEXTB:
				w_as_extb_instruction (instruction);
				break;
			case IEXT:
				w_as_ext_instruction (instruction);
				break;
			case IFTST:
			default:
				internal_error_in_function ("w_as_instructions");
		}
		instruction=instruction->instruction_next;
	}
}

static void w_as_number_of_arguments (int n_node_arguments)
{
	w_as_opcode (sun_flag ? ".word" : "dc.w");
	fprintf (assembly_file,"%d",n_node_arguments);
	w_as_newline();
}

struct call_and_jump {
	struct call_and_jump *cj_next;
	WORD cj_label_id;
	WORD cj_jump_id;
	char *cj_call_label_name;
};

static struct call_and_jump *first_call_and_jump,*last_call_and_jump;

static void w_as_garbage_collect_test (register struct basic_block *block)
{
	LONG n_cells;
	int label_id_1,label_id_2;
	struct call_and_jump *new_call_and_jump;

	label_id_1=next_label_id++;
	label_id_2=next_label_id++;
	
	new_call_and_jump=(struct call_and_jump*)allocate_memory_from_heap (sizeof (struct call_and_jump));
	
	new_call_and_jump->cj_next=NULL;
	new_call_and_jump->cj_label_id=label_id_1;
	new_call_and_jump->cj_jump_id=label_id_2;
	switch (block->block_n_begin_a_parameter_registers){
		case 0:		new_call_and_jump->cj_call_label_name="collect_0";	break;
		case 1:		new_call_and_jump->cj_call_label_name="collect_1";	break;
		case 2:		new_call_and_jump->cj_call_label_name="collect_2";	break;
		case 3:		new_call_and_jump->cj_call_label_name="collect_3";	break;
		default:	internal_error_in_function ("w_as_garbage_collect_test");
	}
	
	if (first_call_and_jump!=NULL)
		last_call_and_jump->cj_next=new_call_and_jump;
	else
		first_call_and_jump=new_call_and_jump;
	last_call_and_jump=new_call_and_jump;
		
	n_cells=block->block_n_new_heap_cells;
	if (n_cells<=8){
		w_as_opcode_and_size ("subq",SIZE_LONG);
		w_as_immediate (n_cells);
		w_as_comma ();
		w_as_register (REGISTER_D7);
		w_as_newline();
	} else if (n_cells<128
		&& 	block->block_n_begin_d_parameter_registers	<
			(parallel_flag ? N_DATA_PARAMETER_REGISTERS-1 : N_DATA_PARAMETER_REGISTERS))
	{
		w_as_opcode ("moveq");
		w_as_immediate (n_cells);
		w_as_comma();
		w_as_register (parallel_flag ? REGISTER_D5 : REGISTER_D6);
		w_as_newline();
		
		w_as_opcode_and_size ("sub",SIZE_LONG);
		w_as_register (parallel_flag ? REGISTER_D5: REGISTER_D6);
		w_as_comma();
		w_as_register (REGISTER_D7);
		w_as_newline();
	} else {
		w_as_opcode_and_size ("sub",SIZE_LONG);
		w_as_immediate (n_cells);
		w_as_comma();
		w_as_register (REGISTER_D7);
		w_as_newline();
	}
	
	w_as_opcode ("bcs");
	w_as_internal_label (label_id_1);
	w_as_newline ();
	
	w_as_define_internal_label (label_id_2);
}

static void w_as_call_and_jump (struct call_and_jump *call_and_jump)
{
	w_as_define_internal_label (call_and_jump->cj_label_id);
	
	w_as_opcode (sun_flag ? "jbsr" : "jsr");
	w_as_label (call_and_jump->cj_call_label_name);
	w_as_newline();
	
	w_as_opcode (sun_flag ? "bra" : "jmp");
	w_as_internal_label (call_and_jump->cj_jump_id);
	w_as_newline();
}

static void w_as_labels (register struct block_label *labels)
{
	for (; labels!=NULL; labels=labels->block_label_next)
		if (labels->block_label_label->label_number==0){
			register LABEL *label;
			
			label=labels->block_label_label;
			
			w_as_define_label (label);
		}
}

static void w_as_indirect_node_entry_jump (LABEL *label)
{
	char *new_label_name;

	new_label_name=(char*)fast_memory_allocate (strlen (label->label_name)+1+2);
	strcpy (new_label_name,"j_");
	strcat (new_label_name,label->label_name);

	if (label->label_flags & EA_LABEL){
		int label_arity;
		extern LABEL *eval_fill_label,*eval_upd_labels[];

		label_arity=label->label_arity;
		
		if (label_arity<-2)
			label_arity=1;
		
		if (label_arity>=0 && label->label_ea_label!=eval_fill_label){
			w_as_opcode ("lea");
			w_as_label (label->label_ea_label->label_name);
			w_as_comma();
			w_as_register (REGISTER_A2);
			w_as_newline();
		
			w_as_opcode ("jmp");
			w_as_label (eval_upd_labels[label_arity]->label_name);
			w_as_newline();
		} else {
			w_as_opcode ("jmp");
			w_as_label (label->label_ea_label->label_name);
			w_as_newline();
		
			w_as_instruction_without_parameters ("nop");
			w_as_instruction_without_parameters ("nop");
		}
		
		if (label->label_arity<0 || parallel_flag){
			LABEL *descriptor_label;

			descriptor_label=label->label_descriptor;

			if (descriptor_label->label_id<0)
				descriptor_label->label_id=next_label_id++;

			w_as_null_descriptor (descriptor_label->label_name);
		} else
			w_as_number_of_arguments (0);
	} else
		if (label->label_arity<0 || parallel_flag){
			LABEL *descriptor_label;

			descriptor_label=label->label_descriptor;

			if (descriptor_label->label_id<0)
				descriptor_label->label_id=next_label_id++;

			w_as_null_descriptor (descriptor_label->label_name);
		}

	w_as_number_of_arguments (label->label_arity);
	
	w_as_define_label_name (new_label_name);
	
	w_as_opcode ("jmp");
	w_as_label (label->label_name);
	w_as_newline();
	
	label->label_name=new_label_name;
}

static void w_as_indirect_defered_jump (register LABEL *label)
{
	w_as_null_descriptor (EMPTY_label->label_name);

	w_as_number_of_arguments (label->label_arity);
	
	w_as_define_local_label (label->label_number);
	
	w_as_opcode ("jmp");
	w_as_label (label->label_descriptor->label_name);
	w_as_newline();
}

static void w_as_import_labels (register struct label_node *label_node)
{
	register LABEL *label;
	
	if (label_node==NULL)
		return;
	
	label=&label_node->label_node_label;
	
	if (!(label->label_flags & LOCAL_LABEL) && label->label_number==0){
		w_as_opcode ("import");
		w_as_label (label->label_name);
		if (label->label_flags & DATA_LABEL)
			fprintf (assembly_file,":data");
		w_as_newline();
		if (label->label_flags & NODE_ENTRY_LABEL){
#ifdef MODULES
			w_as_new_module (0);
#endif
			w_as_indirect_node_entry_jump (label);
		}
	}
	
	w_as_import_labels (label_node->label_node_left);
	w_as_import_labels (label_node->label_node_right);
}

static void w_as_indirect_jumps_for_defer_labels (void)
{
	struct local_label *local_label;
	
	for (local_label=local_labels; local_label!=NULL; local_label=local_label->local_label_next){
		LABEL *label;
		
		label=&local_label->local_label_label;
		if (label->label_flags & DEFERED_LABEL){
#ifdef MODULES
			w_as_new_module (0);
#endif
			w_as_indirect_defered_jump (label);
		}
	}
}

static void w_as_begin (VOID)
{
	fprintf (assembly_file,"\tcase\ton\n");
	fprintf (assembly_file,"\tstring\tasis\n");
	if (!mc68000_flag)
		fprintf (assembly_file,"\tmachine\tmc68020\n");
	if (mc68881_flag)
		fprintf (assembly_file,"\tmc68881\n");
	fprintf (assembly_file,"\tinclude\t'descriptor_macros.h'\n");
	fprintf (assembly_file,"\tproc\n");
}

static char local_stack_overflow_label_name[]="l_stack_overflow";

static void init_stack_checking (VOID)
{
	w_as_define_label_name (local_stack_overflow_label_name);
	w_as_opcode (sun_flag ? "jra": "jmp");
	w_as_label (stack_overflow_label->label_name);
	w_as_newline();
}

#define EXTRA_STACK_SPACE 2000 /* 300 */

static void w_as_check_stack (register struct basic_block *block)
{
	int size,n_d_parameters,n_a_parameters;
	int label_id_1,label_id_2;
	
	if (parallel_flag){
		struct call_and_jump *new_call_and_jump;

		label_id_1=next_label_id++;
		label_id_2=next_label_id++;
	
		new_call_and_jump=(struct call_and_jump*)allocate_memory_from_heap (sizeof (struct call_and_jump));

		new_call_and_jump->cj_next=NULL;
		new_call_and_jump->cj_label_id=label_id_1;
		new_call_and_jump->cj_jump_id=label_id_2;
		switch (block->block_n_begin_a_parameter_registers){
			case 0:		new_call_and_jump->cj_call_label_name="realloc_0";	break;
			case 1:		new_call_and_jump->cj_call_label_name="realloc_1";	break;
			case 2:		new_call_and_jump->cj_call_label_name="realloc_2";	break;
			case 3:		new_call_and_jump->cj_call_label_name="realloc_3";	break;
			default:	internal_error_in_function ("as_garbage_check_stack");
		}
		
		if (first_call_and_jump!=NULL)
			last_call_and_jump->cj_next=new_call_and_jump;
		else
			first_call_and_jump=new_call_and_jump;
		last_call_and_jump=new_call_and_jump;
	}

	size=block->block_stack_check_size;
/*	if (parallel_flag) */
		size+=EXTRA_STACK_SPACE;
	n_d_parameters=block->block_n_begin_d_parameter_registers;
	n_a_parameters=block->block_n_begin_a_parameter_registers;
				
	if (size<=4){
		/* CMPA.L A_STACK_POINTER,B_STACK_POINTER */
		w_as_opcode_and_size ("cmp",SIZE_LONG);
		w_as_register (A_STACK_POINTER);
		w_as_comma();
		w_as_register (B_STACK_POINTER);
		w_as_newline();
		/* BLS */
		w_as_opcode ("bls");
	} else if (size<=127 
		&&	n_d_parameters <
			(parallel_flag ? N_DATA_PARAMETER_REGISTERS-1 : N_DATA_PARAMETER_REGISTERS))
	{
		/* MOVEQ #size,D5/D6 */
		w_as_opcode ("moveq");
		w_as_immediate (size);
		w_as_comma();
		w_as_register (parallel_flag ? REGISTER_D5 : REGISTER_D6);
		w_as_newline();
		/* ADD.L A_STACK_POINTER,D5/D6 */
		w_as_opcode_and_size ("add",SIZE_LONG);
		w_as_register (A_STACK_POINTER);
		w_as_comma();
		w_as_register (parallel_flag ? REGISTER_D5 : REGISTER_D6);
		w_as_newline();
		/* CMP.L B_STACK_POINTER,D5/D6 */
		w_as_opcode_and_size ("cmp",SIZE_LONG);
		w_as_register (B_STACK_POINTER);
		w_as_comma();
		w_as_register (parallel_flag ? REGISTER_D5 : REGISTER_D6);
		w_as_newline();
		/* BHI */
		w_as_opcode ("bhi");
	} else if (n_a_parameters<N_ADDRESS_PARAMETER_REGISTERS){
		/* LEA size(A_STACK_POINTER),A2 */
		w_as_opcode ("lea");
		w_as_indirect (size,A_STACK_POINTER);
		w_as_comma();
		w_as_register (REGISTER_A2);
		w_as_newline();
		/* CMPA.L B_STACK_POINTER,A2 */
		w_as_opcode_and_size ("cmp",SIZE_LONG);
		w_as_register (B_STACK_POINTER);
		w_as_comma();
		w_as_register (REGISTER_A2);
		w_as_newline();
		/* BHI */
		w_as_opcode ("bhi");
	} else {
		/* SUBA.L B_STACK_POINTER,A_STACK_POINTER */
		w_as_opcode_and_size ("sub",SIZE_LONG);
		w_as_register (B_STACK_POINTER);
		w_as_comma();
		w_as_register (A_STACK_POINTER);
		w_as_newline();
		/* CMPA.W #-size,A_STACK_POINTER */
		w_as_opcode_and_size ("cmp",SIZE_WORD);
		w_as_immediate (-size);
		w_as_comma();
		w_as_register (A_STACK_POINTER);
		w_as_newline();
		/* ADDA.L B_STACK_POINTER,A_STACK_POINTER */
		w_as_opcode_and_size ("add",SIZE_LONG);
		w_as_register (B_STACK_POINTER);
		w_as_comma();
		w_as_register (A_STACK_POINTER);
		w_as_newline();
		/* BGT */
		w_as_opcode ("bgt");
	}

	if (!parallel_flag){
		w_as_label (local_stack_overflow_label_name);
		w_as_newline();
	} else {
		w_as_internal_label (label_id_1);
		w_as_newline ();
	
		w_as_define_internal_label (label_id_2);
	}
}

void initialize_write_assembly (FILE *ass_file)
{
	assembly_file=ass_file;
	
	next_bmove_label=0;
	in_data_section=0;
	first_relocatable_word=NULL;
	last_relocatable_word=NULL;
	n_relocatable_words=0;
	n_relocatable_longs=0;
	
	first_call_and_jump=NULL;
	
	if (!sun_flag)
		w_as_begin();
	
	if (check_stack && !parallel_flag)
		init_stack_checking();
}

static void w_as_relocation_routine (VOID)
{
	struct dependency_list *dependency;
	struct relocatable_words_list *r_word;
	int n;
	
	fprintf (assembly_file,"rf_%s:\t.word\t0\n",this_module_name);
	fprintf (assembly_file,"\t.globl\tre_%s\n",this_module_name);
	fprintf (assembly_file,"re_%s:\n",this_module_name);
	fprintf (assembly_file,"\ttstb\trf_%s\n",this_module_name);
	fprintf (assembly_file,"\tbne\trx_%s\n",this_module_name);
	fprintf (assembly_file,"\tst\trf_%s\n",this_module_name);
	
	fprintf (assembly_file,"\tmovel\t#%d,d0\n",n_relocatable_longs);
	fprintf (assembly_file,"\tmovel\t#%d,d1\n",n_relocatable_words);
	fprintf (assembly_file,"\tlea\trlt_%s,a0\n",this_module_name);
	fprintf (assembly_file,"\tlea\trwt_%s,a1\n",this_module_name);
	fprintf (assembly_file,"\tjbsr\ta2@\n");
	
	for (dependency=first_dependency; dependency!=NULL; dependency=dependency->dependency_next)
		fprintf (assembly_file,"\tjbsr\tre_%s\n",dependency->dependency_module_name);
	
	fprintf (assembly_file,"rx_%s:\n",this_module_name);
	fprintf (assembly_file,"\trts\n");
	
	fprintf (assembly_file,"rlt_%s:\n",this_module_name);
	for (n=0; n<n_relocatable_longs; ++n)
		fprintf (assembly_file,"\t.long\trl_%d\n",n);
	
	fprintf (assembly_file,"rwt_%s:\n",this_module_name);
	n=0;
	for (r_word=first_relocatable_word; r_word!=NULL; r_word=r_word->relocatable_next)
		fprintf (assembly_file,"\t.long\trw_%d,%s\n",n++,r_word->relocatable_label_name);
}

void write_assembly (VOID)
{
	register struct basic_block *block;
	register struct call_and_jump *call_and_jump;
	
	w_as_to_code_section();
	
	release_heap();
	
	if (!sun_flag)
		w_as_import_labels (labels);
	w_as_indirect_jumps_for_defer_labels();
	
	for (block=first_block; block!=NULL; block=block->block_next){
#ifdef MODULES
		if (block->block_begin_module)
			w_as_new_module (block->block_link_module);
#endif
		
		if (block->block_n_node_arguments>-100){
#ifdef CLOSURE_NAMES
			if (block->block_descriptor!=NULL && block->block_descriptor_or_string!=0){
				int length,n;
				char *string;
				
				string=(char*)block->block_descriptor;
				length=strlen (string);
				
				n=w_as_data (0,(unsigned char *)string,length);
				if (length & 3)
					n=w_as_zeros (n,4-(length & 3));
				if (n>0)
					w_as_newline();

				w_as_opcode (sun_flag ? ".long" : "dc.l");
				fprintf (assembly_file,"%d\n",length);
			}
#endif

			if (block->block_ea_label!=NULL){
				int n_node_arguments;
				extern LABEL *eval_fill_label,*eval_upd_labels[];
				
				n_node_arguments=block->block_n_node_arguments;

				if (n_node_arguments<-2)
					n_node_arguments=1;

				if (n_node_arguments>=0 && block->block_ea_label!=eval_fill_label){
					w_as_opcode ("lea");
					w_as_label (block->block_ea_label->label_name);
					w_as_comma();
					w_as_register (REGISTER_A2);
					w_as_newline();
				
					w_as_opcode ("jmp");
					w_as_label (eval_upd_labels[n_node_arguments]->label_name);
					w_as_newline();
				} else {
					w_as_opcode ("jmp");
					w_as_label (block->block_ea_label->label_name);
					w_as_newline();
					
					w_as_instruction_without_parameters ("nop");
					w_as_instruction_without_parameters ("nop");
				}
				
				if (block->block_descriptor!=NULL
					&& (block->block_n_node_arguments<0 || parallel_flag))
				{
					w_as_label_in_code_section (block->block_descriptor->label_name);
				} else
					w_as_number_of_arguments (0);
			} else
				if (block->block_descriptor!=NULL /* CHANGED 30-10 */
					&& (block->block_n_node_arguments<0 || parallel_flag))
				{
					w_as_label_in_code_section (block->block_descriptor->label_name);
				}
				/* else
					w_as_number_of_arguments (0);
				*/

			w_as_number_of_arguments (block->block_n_node_arguments);
		}
		
		w_as_labels (block->block_labels);
		if (block->block_n_new_heap_cells>0)
			w_as_garbage_collect_test (block);
		if (check_stack && block->block_stack_check_size>0)
			w_as_check_stack (block);
		w_as_instructions (block->block_instructions);
	}
	
	for (call_and_jump=first_call_and_jump;
		 call_and_jump!=NULL; call_and_jump=call_and_jump->cj_next)
	{
#ifdef MODULES
			w_as_new_module (0);
#endif
		w_as_call_and_jump (call_and_jump);
	}
	
	if (sun_flag)
		w_as_relocation_routine();
	
	if (!sun_flag){
		fprintf (assembly_file,"\tendproc\n");
		fprintf (assembly_file,"\tend\n");
	}
	
	release_heap();
}

#endif