/*
	File:		cgswas.c
	Author:		John van Groningen
	Machine:	Sun 4
	At:			University of Nijmegen
*/

#include <stdio.h>
#include <string.h>

#include "cgport.h"
#include "cgrconst.h"
#include "cgtypes.h"
#include "cg.h"
#include "cgiconst.h"
#include "cgcode.h"
#include "cgswas.h"

#define GAS

#define IO_BUF_SIZE 8192

#define SP_G5

#undef ALIGN_REAL_ARRAYS

#ifdef ALIGN_REAL_ARRAYS
# define LOAD_STORE_ALIGNED_REAL 4
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

void w_as_internal_label_value (int label_id)
{
	fprintf (assembly_file,"\t.word\ti_%d\n",label_id);
}

static int in_data_section;

#ifdef FUNCTION_LEVEL_LINKING
void w_as_new_data_module (void)
{
}
#endif

void w_as_to_data_section (VOID)
{
	if (!in_data_section){
		in_data_section=1;
		w_as_instruction_without_parameters (".data");
	}
}

static void w_as_to_code_section (VOID)
{
	if (in_data_section){
		in_data_section=0;
		w_as_instruction_without_parameters (".text");
	}
}

void w_as_word_in_data_section (int n)
{
	w_as_to_data_section();
	w_as_opcode (".half");
	fprintf (assembly_file,"%d",n);
	w_as_newline();
}

void w_as_long_in_data_section (int n)
{
	w_as_to_data_section();
	w_as_opcode (".word");
	fprintf (assembly_file,"%d",n);
	w_as_newline();
}

void w_as_label_in_data_section (char *label_name)
{
	w_as_to_data_section ();
	fprintf (assembly_file,"\t.word\t%s\n",label_name);
}

static void w_as_label_in_code_section (char *label_name)
{
	w_as_to_code_section ();
	fprintf (assembly_file,"\t.word\t%s\n",label_name);
}

void w_as_descriptor_in_data_section (char *label_name)
{
	w_as_to_data_section ();
	fprintf (assembly_file,"\t.word\t%s+2\n",label_name);
}

#define MAX_BYTES_PER_LINE 16

static int w_as_data (register int n,register unsigned char *data,register int length)
{
	int i,in_string;
	
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
		
		c=data[i];
		if (isalnum (c) || c=='_' || c==' '){
			if (!in_string){
				if (n!=0)
					w_as_newline();
				w_as_opcode (".ascii");
				putc ('\"',assembly_file);
				in_string=1;
				n=0;
			}
			putc (c,assembly_file);
		} else {
			if (n==0)
				w_as_opcode (".byte");
			else {
				if (in_string){
					putc ('\"',assembly_file);
					w_as_newline();
					w_as_opcode (".byte");
					in_string=0;
					n=0;
				} else
					putc (',',assembly_file);
			}

			fprintf (assembly_file,"0x%02x",c);
		}
		++n;
	}
	
	if (in_string){
		putc ('\"',assembly_file);
		w_as_newline();
		return 0;
	} else
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
			w_as_opcode (".byte");
		else
			putc (',',assembly_file);
		fprintf (assembly_file,"0");
		++n;
	}
	return n;
}

void w_as_c_string_in_data_section (char *string,int length)
{
	register int n;
	
	w_as_to_data_section();
		
	n=w_as_data (0,string,length);
	n=w_as_zeros (n,4-(length & 3));
/*	n=w_as_zeros (n,length & 1 ? 1 : 2); */
	if (n>0)
		w_as_newline();
}

void w_as_define_data_label (int label_number)
{
	w_as_to_data_section();
	
	w_as_define_local_label (label_number);
}

void w_as_labeled_c_string_in_data_section (char *string,int length,int label_number)
{
	int n;
	
	w_as_to_data_section();
	
	w_as_define_local_label (label_number);
	
	n=w_as_data (0,string,length);
	if (length & 3)
		n=w_as_zeros (n,4-(length & 3));
	else
		n=w_as_zeros (n,4);
	if (n>0)
		w_as_newline();
}

void w_as_abc_string_in_data_section (char *string,int length)
{
	int n;
	
	w_as_to_data_section();
	
	w_as_opcode (".word");
	fprintf (assembly_file,"%d\n",length);
	n=w_as_data (0,string,length);
	if (length & 3)
		n=w_as_zeros (n,4-(length & 3));
	if (n>0)
		w_as_newline();
}

void w_as_descriptor_string_in_data_section
	(char *string,int length,int string_label_id,LABEL *string_label)
{
	int n;
	
	w_as_to_data_section();
	
	w_as_define_internal_label (string_label_id);
	w_as_define_local_label (string_label->label_number);

	w_as_opcode (".word");
	fprintf (assembly_file,"%d\n",length);
	n=w_as_data (0,string,length);
	if (length & 3)
		n=w_as_zeros (n,4-(length & 3));
	if (n>0)
		w_as_newline();
}

enum { SIZE_LONG, SIZE_WORD, SIZE_BYTE };

static void w_as_opcode_and_d (char *opcode)
{
	fprintf (assembly_file,"\t%sd\t",opcode);
}

static void w_as_label (char *label)
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
		w_as_opcode (".global");
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

static void w_as_immediate (LONG i)
{
	fprintf (assembly_file,"%ld",i);
}

void w_as_abc_string_and_label_in_data_section (char *string,int length,char *label_name)
{
	int n;
	
	w_as_to_data_section();
	
	w_as_define_label_name (label_name);
	
	w_as_opcode (".long");
	fprintf (assembly_file,"%d\n",length);
	n=w_as_data (0,string,length);
	if (length & 3)
		n=w_as_zeros (n,4-(length & 3));
	if (n>0)
		w_as_newline();
}

static char register_type  [32]="ggggggiiggiiiiiilllllllloooooooo";
#ifdef SP_G5
static char register_number[32]="01234767565432100123456701234567";
#else
static char register_number[32]="01234567765432100123456701234567";
#endif

#define REGISTER_G0 (-16)
#define REGISTER_G5 (-11)
#define REGISTER_I6 (-10)
#define REGISTER_O0 8
#define REGISTER_O1 9
#define REGISTER_O7 15

static void w_as_indirect (int i,int reg)
{
	if (i!=0){
		if (i>0)
			fprintf (assembly_file,"[%%%c%c+%d]",register_type[reg+16],register_number[reg+16],i);
		else
			fprintf (assembly_file,"[%%%c%c-%d]",register_type[reg+16],register_number[reg+16],-i);
	} else
		fprintf (assembly_file,"[%%%c%c]",register_type[reg+16],register_number[reg+16]);
}

static void w_as_indexed (int offset,struct index_registers *index_registers)
{
	int reg1,reg2;
	
	if (offset!=0)
		internal_error_in_function ("w_as_indexed");

	reg1=index_registers->a_reg.r;
	reg2=index_registers->d_reg.r;
	fprintf (assembly_file,"[%%%c%c+%%%c%c]",
			 register_type[reg1+16],register_number[reg1+16],
			 register_type[reg2+16],register_number[reg2+16]);
}

static void w_as_register (int reg)
{
	putc ('%',assembly_file);
	putc (register_type[reg+16],assembly_file);
	putc (register_number[reg+16],assembly_file);
}

static void w_as_register_comma (int reg)
{
	putc ('%',assembly_file);
	putc (register_type[reg+16],assembly_file);
	putc (register_number[reg+16],assembly_file);
	putc (',',assembly_file);
}

static void w_as_register_newline (int reg)
{
	putc ('%',assembly_file);
	putc (register_type[reg+16],assembly_file);
	putc (register_number[reg+16],assembly_file);
	putc ('\n',assembly_file);
}

void w_as_c_string_and_label_in_code_section (char *string,int length,char *label_name)
{
	register int n;
	
/*	w_as_to_code_section(); */
	w_as_to_data_section();
	
	w_as_define_label_name (label_name);
	
	n=w_as_data (0,string,length);
	n=w_as_zeros (n,4-(length & 3));
	if (n>0)
		w_as_newline();
}

static void w_as_scratch_register (void)
{
	w_as_register (REGISTER_O0);
}

static void w_as_fp_register (int fp_reg)
{
	fprintf (assembly_file,"%%f%d",fp_reg);
}

static void w_as_fp_register_newline (int fp_reg)
{
	fprintf (assembly_file,"%%f%d\n",fp_reg);
}

static void w_as_opcode_descriptor (char *opcode,char *label_name,int arity)
{
	w_as_opcode (opcode);
	fprintf (assembly_file,"%s+0x%x",label_name,2/* 0x80000000 */+(arity<<3));
}
		
static void w_as_comma (VOID)
{
	putc (',',assembly_file);
}

static void w_as_opcode_indirect (char *opcode,int offset,int reg)
{
	if (((offset << (32-13)) >> (32-13))==offset){
		w_as_opcode (opcode);
		w_as_indirect (offset,reg);
	 } else {
		w_as_opcode ("sethi");
		w_as_immediate (offset>>10);
		w_as_comma();
		w_as_register (REGISTER_O1);
		w_as_newline();

		w_as_opcode ("add");
		w_as_register (REGISTER_O1);
		w_as_comma();
		w_as_register (reg);
		w_as_comma();
		w_as_register (REGISTER_O1);
		w_as_newline();

		w_as_opcode (opcode);
		w_as_indirect (offset & 1023,REGISTER_O1);
	}
}

static void w_as_parameter (struct parameter *parameter)
{
	switch (parameter->parameter_type){
		case P_REGISTER:
			w_as_register (parameter->parameter_data.reg.r);
			break;
		case P_LABEL:
			if (parameter->parameter_data.l->label_number!=0)
				w_as_local_label (parameter->parameter_data.l->label_number);
			else
				w_as_label (parameter->parameter_data.l->label_name);
			break;
		case P_INDIRECT:
			w_as_indirect (parameter->parameter_offset,parameter->parameter_data.reg.r);
			break;
		case P_INDEXED:
			w_as_indexed (parameter->parameter_offset,parameter->parameter_data.ir);
			break;
		case P_IMMEDIATE:
			fprintf (assembly_file,"%ld",parameter->parameter_data.i);
			break;
		case P_F_REGISTER:
			fprintf (assembly_file,"%%f%d",parameter->parameter_data.reg.r<<1);
			break;
		default:
			internal_error_in_function ("w_as_parameter");
	}
}

static void w_as_ld_parameter (struct parameter *parameter)
{
	if (parameter->parameter_type!=P_INDIRECT){
		w_as_opcode ("ld");
		w_as_parameter (parameter);
	} else
		w_as_opcode_indirect ("ld",parameter->parameter_offset,parameter->parameter_data.reg.r);
}

static void w_as_opcode_parameter (char *opcode,struct parameter *parameter)
{
	if (parameter->parameter_type!=P_INDIRECT){
		w_as_opcode (opcode);
		w_as_parameter (parameter);
	} else
		w_as_opcode_indirect (opcode,parameter->parameter_offset,parameter->parameter_data.reg.r);
}

static void w_as_jump_parameter (register struct parameter *parameter)
{
	switch (parameter->parameter_type){
		case P_LABEL:
			if (parameter->parameter_data.l->label_number!=0)
				w_as_local_label (parameter->parameter_data.l->label_number);
			else
				w_as_label (parameter->parameter_data.l->label_name);
			break;
		case P_INDIRECT:
		{
			int offset,reg;

			offset=parameter->parameter_offset;
			reg=parameter->parameter_data.reg.r;

			if (offset!=0)
				fprintf (assembly_file,"%%%c%c+%d",
						 register_type[reg+16],register_number[reg+16],offset);
			else
				fprintf (assembly_file,"%%%c%c",
						 register_type[reg+16],register_number[reg+16]);
			break;
		}
		default:
			internal_error_in_function ("w_as_jump_parameter");
	}
}

static struct parameter w_as_register_parameter (struct parameter parameter,int size_flag)
{
	switch (parameter.parameter_type){
		case P_DESCRIPTOR_NUMBER:
			w_as_opcode_descriptor ("set",
				parameter.parameter_data.l->label_name,
				parameter.parameter_offset
			);
			w_as_comma();
			w_as_register (REGISTER_O0);
			w_as_newline();

			parameter.parameter_type=P_REGISTER;
			parameter.parameter_data.reg.r=REGISTER_O0;
			break;
		case P_IMMEDIATE:
			if (parameter.parameter_data.i==0){
				parameter.parameter_type=P_REGISTER;
				parameter.parameter_data.reg.r=REGISTER_G0;
			} else {
				w_as_opcode ("set");
				w_as_immediate (parameter.parameter_data.i);
				w_as_comma();
				w_as_register (REGISTER_O0);
				w_as_newline();

				parameter.parameter_type=P_REGISTER;
				parameter.parameter_data.reg.r=REGISTER_O0;
			}
			break;
		case P_REGISTER:
			break;
		case P_INDIRECT:
			w_as_opcode_indirect (	size_flag==SIZE_LONG ? "ld" : size_flag==SIZE_WORD ? "ldsh" : "ldub",
									parameter.parameter_offset,parameter.parameter_data.reg.r);
			w_as_comma();
			w_as_register (REGISTER_O0);
			w_as_newline();

			parameter.parameter_type=P_REGISTER;
			parameter.parameter_data.reg.r=REGISTER_O0;
			break;
		case P_INDEXED:
			w_as_opcode (size_flag==SIZE_LONG ? "ld" : size_flag==SIZE_WORD ? "ldsh" : "ldub");
			w_as_indexed (parameter.parameter_offset,parameter.parameter_data.ir);
			w_as_comma();
			w_as_register (REGISTER_O0);
			w_as_newline();

			parameter.parameter_type=P_REGISTER;
			parameter.parameter_data.reg.r=REGISTER_O0;
			break;
		default:
			internal_error_in_function ("w_as_register_parameter");
	}
	return parameter;
}

static void w_as_move_instruction (struct instruction *instruction,int size_flag)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_REGISTER:
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_DESCRIPTOR_NUMBER:
					w_as_opcode_descriptor ("set",
						instruction->instruction_parameters[0].parameter_data.l->label_name,
						instruction->instruction_parameters[0].parameter_offset
					);
					break;
				case P_IMMEDIATE:
					w_as_opcode ("set");
					w_as_immediate (instruction->instruction_parameters[0].parameter_data.i);
					break;
				case P_REGISTER:
					w_as_opcode ("mov");
					w_as_register (instruction->instruction_parameters[0].parameter_data.reg.r);
					break;
				case P_INDIRECT:
					w_as_opcode_indirect (	size_flag==SIZE_LONG ? "ld" : size_flag==SIZE_WORD ? "ldsh" : "ldub",
											instruction->instruction_parameters[0].parameter_offset,
											instruction->instruction_parameters[0].parameter_data.reg.r);
					break;
				case P_INDEXED:
					w_as_opcode (size_flag==SIZE_LONG ? "ld" : size_flag==SIZE_WORD ? "ldsh" : "ldub");
					w_as_indexed (instruction->instruction_parameters[0].parameter_offset,
								  instruction->instruction_parameters[0].parameter_data.ir);
					break;
				default:
					internal_error_in_function ("w_as_move_instruction");
					return;
			}
			w_as_comma();
			w_as_register (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_newline();
			return;
		case P_INDIRECT:
		{
			struct parameter parameter_0;
			int offset;

			parameter_0=w_as_register_parameter (instruction->instruction_parameters[0],size_flag);

			offset=instruction->instruction_parameters[1].parameter_offset;

			if (((offset << (32-13)) >> (32-13))==offset){
				w_as_opcode (size_flag==SIZE_LONG ? "st" : size_flag==SIZE_WORD ? "sth" : "stb");
				w_as_register (parameter_0.parameter_data.reg.r);
				w_as_comma();
				w_as_indirect (offset,instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_newline();
			} else {
				w_as_opcode ("sethi");
				w_as_immediate (offset>>10);
				w_as_comma();
				w_as_register (REGISTER_O1);
				w_as_newline();
		
				w_as_opcode ("add");
				w_as_register (REGISTER_O1);
				w_as_comma();
				w_as_register (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_comma();
				w_as_register (REGISTER_O1);
				w_as_newline();

				w_as_opcode (size_flag==SIZE_LONG ? "st" : size_flag==SIZE_WORD ? "sth" : "stb");
				w_as_register (parameter_0.parameter_data.reg.r);
				w_as_comma();
				w_as_indirect (offset & 1023,REGISTER_O1);
				w_as_newline();
			}

			return;
		}
		case P_INDEXED:
		{
			struct parameter parameter_0;

			parameter_0=w_as_register_parameter (instruction->instruction_parameters[0],size_flag);

			w_as_opcode (size_flag==SIZE_LONG ? "st" : size_flag==SIZE_WORD ? "sth" : "stb");
			w_as_register (parameter_0.parameter_data.reg.r);
			w_as_comma();
			w_as_indexed (instruction->instruction_parameters[1].parameter_offset,
						  instruction->instruction_parameters[1].parameter_data.ir);
			w_as_newline();
			return;
		}
		default:
			internal_error_in_function ("w_as_move_instruction");
	}
}

static void w_as_lea_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER)
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_LABEL:
				w_as_opcode ("set");
				w_as_parameter (&instruction->instruction_parameters[0]);
				if (instruction->instruction_parameters[0].parameter_offset!=0){
					int offset;
		
					offset=instruction->instruction_parameters[0].parameter_offset;
					fprintf (assembly_file,offset>=0 ? "+%d" : "%d",offset);
				}
				w_as_comma();
				w_as_register (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_newline();
				return;
			case P_INDIRECT:
				w_as_opcode ("add");
				w_as_register (instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_comma();
				w_as_immediate (instruction->instruction_parameters[0].parameter_offset);
				w_as_comma();
				w_as_register (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_newline();
				return;
			case P_INDEXED:
				w_as_opcode ("add");
				w_as_register (instruction->instruction_parameters[0].parameter_data.ir->a_reg.r);
				w_as_comma();
				w_as_register (instruction->instruction_parameters[0].parameter_data.ir->d_reg.r);
				w_as_comma();
				w_as_register (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_newline();
				return;				
		}

	internal_error_in_function ("w_as_lea_instruction");
}

static void w_as_i_instruction (struct instruction *instruction,char *opcode)
{
	w_as_opcode (opcode);
	w_as_register (instruction->instruction_parameters[0].parameter_data.reg.r);
	w_as_comma();
	w_as_immediate (instruction->instruction_parameters[2].parameter_data.i);
	w_as_comma();
	w_as_register (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_newline();
}

static void w_as_tryadic_instruction (struct instruction *instruction,char *opcode)
{
	struct parameter parameter;

	parameter=instruction->instruction_parameters[0];

	switch (parameter.parameter_type){
		case P_IMMEDIATE:
			if ((unsigned)(parameter.parameter_data.i+4096)>=(unsigned)8192){
				w_as_opcode ("set");
				w_as_immediate (parameter.parameter_data.i);
				w_as_comma();
				w_as_register (REGISTER_O0);
				w_as_newline();

				parameter.parameter_type=P_REGISTER;
				parameter.parameter_data.reg.r=REGISTER_O0;
			}
			break;
		case P_INDIRECT:
			w_as_opcode_indirect ("ld",parameter.parameter_offset,parameter.parameter_data.reg.r);
			w_as_comma();
			w_as_register (REGISTER_O0);
			w_as_newline();

			parameter.parameter_type=P_REGISTER;
			parameter.parameter_data.reg.r=REGISTER_O0;
			break;
		case P_INDEXED:
			w_as_opcode ("ld");
			w_as_indexed (parameter.parameter_offset,parameter.parameter_data.ir);
			w_as_comma();
			w_as_register (REGISTER_O0);
			w_as_newline();

			parameter.parameter_type=P_REGISTER;
			parameter.parameter_data.reg.r=REGISTER_O0;			
	}

	w_as_opcode (opcode);
	w_as_register (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_comma();
	w_as_parameter (&parameter);
	w_as_comma();
	w_as_register (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_newline();
}

static void w_as_add_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			w_as_opcode ("add");
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
			w_as_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
			if ((unsigned)(instruction->instruction_parameters[0].parameter_data.i+4096)<(unsigned)8192){
				w_as_opcode ("inc");
				w_as_immediate (instruction->instruction_parameters[0].parameter_data.i);
				w_as_comma();
				w_as_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			} else {
				w_as_opcode ("set");
				w_as_immediate (instruction->instruction_parameters[0].parameter_data.i);
				w_as_comma();
				w_as_scratch_register();
				w_as_newline();

				w_as_opcode ("add");
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_scratch_register();
				w_as_comma();
				w_as_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}
		default:
			w_as_ld_parameter (&instruction->instruction_parameters[0]);
			w_as_comma();
			w_as_scratch_register();
			w_as_newline();

			w_as_opcode ("add");
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_scratch_register();
			w_as_comma();
			w_as_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
	}
}

static void w_as_add_o_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			w_as_opcode ("addcc");
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
			w_as_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
			if ((unsigned)(instruction->instruction_parameters[0].parameter_data.i+4096)<(unsigned)8192){
				w_as_opcode ("inccc");
				w_as_immediate (instruction->instruction_parameters[0].parameter_data.i);
				w_as_comma();
				w_as_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			} else {
				w_as_opcode ("set");
				w_as_immediate (instruction->instruction_parameters[0].parameter_data.i);
				w_as_comma();
				w_as_scratch_register();
				w_as_newline();

				w_as_opcode ("addcc");
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_scratch_register();
				w_as_comma();
				w_as_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}
		default:
			w_as_ld_parameter (&instruction->instruction_parameters[0]);
			w_as_comma();
			w_as_scratch_register();
			w_as_newline();

			w_as_opcode ("addcc");
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_scratch_register();
			w_as_comma();
			w_as_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
	}
}

static void w_as_sub_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			w_as_opcode ("sub");
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
			w_as_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
			if ((unsigned)(instruction->instruction_parameters[0].parameter_data.i+4096)<(unsigned)8192){
				w_as_opcode ("dec");
				w_as_immediate (instruction->instruction_parameters[0].parameter_data.i);
				w_as_comma();
				w_as_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			} else {
				w_as_opcode ("set");
				w_as_immediate (instruction->instruction_parameters[0].parameter_data.i);
				w_as_comma();
				w_as_scratch_register();
				w_as_newline();

				w_as_opcode ("sub");
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_scratch_register();
				w_as_comma();
				w_as_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}
		default:
			w_as_ld_parameter (&instruction->instruction_parameters[0]);
			w_as_comma();
			w_as_scratch_register();
			w_as_newline();

			w_as_opcode ("sub");
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_scratch_register();
			w_as_comma();
			w_as_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
	}
}

static void w_as_sub_o_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			w_as_opcode ("subcc");
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
			w_as_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
			if ((unsigned)(instruction->instruction_parameters[0].parameter_data.i+4096)<(unsigned)8192){
				w_as_opcode ("deccc");
				w_as_immediate (instruction->instruction_parameters[0].parameter_data.i);
				w_as_comma();
				w_as_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			} else {
				w_as_opcode ("set");
				w_as_immediate (instruction->instruction_parameters[0].parameter_data.i);
				w_as_comma();
				w_as_scratch_register();
				w_as_newline();

				w_as_opcode ("subcc");
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_scratch_register();
				w_as_comma();
				w_as_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}
		default:
			w_as_ld_parameter (&instruction->instruction_parameters[0]);
			w_as_comma();
			w_as_scratch_register();
			w_as_newline();

			w_as_opcode ("subcc");
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_scratch_register();
			w_as_comma();
			w_as_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
	}
}

static void w_as_cmp_instruction (struct instruction *instruction)
{
	struct parameter parameter_0,parameter_1;

	parameter_0=instruction->instruction_parameters[0];
	parameter_1=instruction->instruction_parameters[1];

	if (parameter_1.parameter_type==P_INDIRECT){
		w_as_opcode_parameter ("ld",&parameter_1);
		w_as_comma();
		w_as_register (REGISTER_O1);
		w_as_newline();

		parameter_1.parameter_type=P_REGISTER;
		parameter_1.parameter_data.reg.r=REGISTER_O1;
	} else if (parameter_1.parameter_type==P_INDEXED){
		w_as_opcode ("ld");

		w_as_parameter (&parameter_1);
		w_as_comma();
		w_as_register (REGISTER_O1);
		w_as_newline();

		parameter_1.parameter_type=P_REGISTER;
		parameter_1.parameter_data.reg.r=REGISTER_O1;
	}

	switch (parameter_0.parameter_type){
		case P_DESCRIPTOR_NUMBER:
			w_as_opcode_descriptor ("set",
				parameter_0.parameter_data.l->label_name,
				parameter_0.parameter_offset
			);
			w_as_comma();
			w_as_register (REGISTER_O0);
			w_as_newline();

			parameter_0.parameter_type=P_REGISTER;
			parameter_0.parameter_data.reg.r=REGISTER_O0;
			break;
		case P_IMMEDIATE:
			if ((unsigned)(parameter_0.parameter_data.i+4096)>=(unsigned)8192){
				w_as_opcode ("set");
				w_as_parameter (&parameter_0);
				w_as_comma();
				w_as_register (REGISTER_O0);
				w_as_newline();

				parameter_0.parameter_type=P_REGISTER;
				parameter_0.parameter_data.reg.r=REGISTER_O0;
			}
			break;
		case P_REGISTER:
			break;
		default:
			w_as_opcode_parameter ("ld",&parameter_0);
			w_as_comma();
			w_as_register (REGISTER_O0);
			w_as_newline();

			parameter_0.parameter_type=P_REGISTER;
			parameter_0.parameter_data.reg.r=REGISTER_O0;
	}

	w_as_opcode ("cmp");
	w_as_parameter (&parameter_1);
	w_as_comma();
	w_as_parameter (&parameter_0);
	w_as_newline();
}

#if 0
static void w_as_cmpw_instruction (struct instruction *instruction)
{
	struct parameter parameter_0,parameter_1;

	parameter_0=instruction->instruction_parameters[0];
	parameter_1=instruction->instruction_parameters[1];

	if (parameter_1.parameter_type==P_INDIRECT){
		w_as_opcode_parameter ("ldsh",&parameter_1);
		w_as_comma();
		w_as_register (REGISTER_O1);
		w_as_newline();

		parameter_1.parameter_type=P_REGISTER;
		parameter_1.parameter_data.reg.r=REGISTER_O1;
	} else if (parameter_1.parameter_type==P_INDEXED){
		w_as_opcode ("ldsh");

		w_as_parameter (&parameter_1);
		w_as_comma();
		w_as_register (REGISTER_O1);
		w_as_newline();

		parameter_1.parameter_type=P_REGISTER;
		parameter_1.parameter_data.reg.r=REGISTER_O1;
	}

	switch (parameter_0.parameter_type){
		case P_DESCRIPTOR_NUMBER:
			w_as_opcode_descriptor ("set",
				parameter_0.parameter_data.l->label_name,
				parameter_0.parameter_offset
			);
			w_as_comma();
			w_as_register (REGISTER_O0);
			w_as_newline();

			parameter_0.parameter_type=P_REGISTER;
			parameter_0.parameter_data.reg.r=REGISTER_O0;
			break;
		case P_IMMEDIATE:
			if ((unsigned)(parameter_0.parameter_data.i+4096)>=(unsigned)8192){
				w_as_opcode ("set");
				w_as_parameter (&parameter_0);
				w_as_comma();
				w_as_register (REGISTER_O0);
				w_as_newline();

				parameter_0.parameter_type=P_REGISTER;
				parameter_0.parameter_data.reg.r=REGISTER_O0;
			}
			break;
		case P_REGISTER:
			break;
		default:
			w_as_opcode_parameter ("ldsh",&parameter_0);
			w_as_comma();
			w_as_register (REGISTER_O0);
			w_as_newline();

			parameter_0.parameter_type=P_REGISTER;
			parameter_0.parameter_data.reg.r=REGISTER_O0;
	}

	w_as_opcode ("cmp");
	w_as_parameter (&parameter_1);
	w_as_comma();
	w_as_parameter (&parameter_0);
	w_as_newline();
}
#endif

static void w_as_tst_instruction (struct instruction *instruction,int size_flag)
{
	struct parameter parameter_0;

	parameter_0=w_as_register_parameter (instruction->instruction_parameters[0],size_flag);

	w_as_opcode (size_flag==SIZE_LONG ? "tst" : "tstb");
	w_as_register (parameter_0.parameter_data.reg.r);
	w_as_newline();
}

static void w_as_btst_instruction (struct instruction *instruction)
{
	w_as_opcode ("btst");
	w_as_immediate (instruction->instruction_parameters[0].parameter_data.i);
	w_as_comma();
	w_as_register (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_newline();
}

void w_as_jmp_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_LABEL){
		if (instruction->instruction_parameters[0].parameter_data.l->label_flags & LOCAL_LABEL){
			w_as_opcode ("b,a");
			w_as_jump_parameter (&instruction->instruction_parameters[0]);
			w_as_newline();

			return;
		} else
			w_as_opcode ("call");
	} else
		w_as_opcode ("jmp");

	w_as_jump_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();

	w_as_instruction_without_parameters ("nop");
}

static void w_as_branch_instruction (struct instruction *instruction,char *opcode)
{
	w_as_opcode (opcode);
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();

	w_as_instruction_without_parameters ("nop");
}

static void w_as_index_error_branch_instruction (struct instruction *instruction)
{
/*	w_as_opcode ("bleu"); */
	w_as_opcode ("bcs");
	fprintf (assembly_file,".+12");
	w_as_newline();
	
	w_as_instruction_without_parameters ("nop");

	w_as_opcode ("b,a");
	w_as_jump_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();
}

static void w_as_float_branch_instruction (struct instruction *instruction,char *opcode)
{
	w_as_instruction_without_parameters ("nop");

	w_as_opcode (opcode);
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();

	w_as_instruction_without_parameters ("nop");
}

static char local_c_stack_overflow_label_name[]="l_c_stack_overflow";

/*
static void w_as_check_c_stack (void)
{
	w_as_opcode ("cmp");
	w_as_register (C_STACK_POINTER);
	w_as_comma();
	w_as_register (REGISTER_G5);
	w_as_newline();

	w_as_opcode ("bleu");
	w_as_label (local_c_stack_overflow_label_name);
	w_as_newline();
}
*/

static void w_as_jsr_instruction (struct instruction *instruction)
{
	/*
	if (check_c_stack)
		w_as_check_c_stack();
	*/
	
	w_as_opcode ("call");
	w_as_jump_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();

	if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT){
		w_as_opcode ("st");
		w_as_register (REGISTER_O7);
		w_as_comma();
		w_as_indirect (instruction->instruction_parameters[1].parameter_data.i,B_STACK_POINTER);
		w_as_newline();
	} else
		w_as_instruction_without_parameters ("nop");
}

static void w_as_rts_instruction (struct instruction *instruction)
{
	int b_offset;
	
	w_as_opcode_indirect ("ld",instruction->instruction_parameters[0].parameter_offset,B_STACK_POINTER);
	w_as_comma();
	w_as_register (REGISTER_O7);
	w_as_newline();

	w_as_instruction_without_parameters ("retl");

	b_offset=instruction->instruction_parameters[1].parameter_data.i;
	if (b_offset==0)
		w_as_instruction_without_parameters ("nop");
	else {
		if (b_offset<0){
			w_as_opcode ("dec");
			w_as_immediate (-b_offset);
		} else {
			w_as_opcode ("inc");
			w_as_immediate (b_offset);
		}
		w_as_comma();
		w_as_register (B_STACK_POINTER);
		w_as_newline();
	}
}

static void w_as_set_condition_instruction (struct instruction *instruction,char *opcode)
{
	w_as_opcode ("clr");
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();

	w_as_opcode (opcode);
	fprintf (assembly_file,".+8");
	w_as_newline();

	w_as_opcode ("mov");
	fprintf (assembly_file,"-1");
	w_as_comma();
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();
}

static void w_as_set_float_condition_instruction (struct instruction *instruction,char *opcode)
{
	w_as_instruction_without_parameters ("nop");
	w_as_set_condition_instruction (instruction,opcode);
}

static void w_as_mod_instruction (struct instruction *instruction)
{
	w_as_opcode ("mov");
	w_as_parameter (&instruction->instruction_parameters[2]);
	w_as_comma();
	w_as_register (REGISTER_O0);
	w_as_newline();

	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			w_as_opcode ("call");
			fprintf (assembly_file,".rem");
			w_as_newline();

			w_as_opcode ("mov");
			w_as_parameter (&instruction->instruction_parameters[0]);
			break;
		case P_IMMEDIATE:
		{
			long v;
			
			v=instruction->instruction_parameters[0].parameter_data.i;

			if ((unsigned)(v+4096) < (unsigned)8192){
				w_as_opcode ("call");
				fprintf (assembly_file,".rem");
				w_as_newline();
	
				w_as_opcode ("mov");
				w_as_immediate (v);
			} else {
				w_as_opcode ("sethi");
				fprintf (assembly_file,"%%hi ");
#ifdef GAS
				fprintf (assembly_file,"(");
#endif
				w_as_immediate (v);
#ifdef GAS
				fprintf (assembly_file,")");
#endif
				w_as_comma();
				w_as_register (REGISTER_O1);
				w_as_newline();

				w_as_opcode ("call");
				fprintf (assembly_file,".rem");
				w_as_newline();
			
				w_as_opcode ("or");
				w_as_register (REGISTER_O1);
				w_as_comma();
				fprintf (assembly_file,"%%lo ");
#ifdef GAS
				fprintf (assembly_file,"(");
#endif
				w_as_immediate (v);
#ifdef GAS
				fprintf (assembly_file,")");
#endif
			}
			break;
		}
		default:
			w_as_opcode ("call");
			fprintf (assembly_file,".rem");
			w_as_newline();

			w_as_ld_parameter (&instruction->instruction_parameters[0]);
	}
    w_as_comma();
	w_as_register (REGISTER_O1);
	w_as_newline();

	w_as_opcode ("mov");
	w_as_register (REGISTER_O0);
    w_as_comma();
    w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_newline();
}

static void w_as_mul_or_div_instruction (struct instruction *instruction,char *mul_or_div_label_name)
{
	w_as_opcode ("mov");
	w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_comma();
	w_as_register (REGISTER_O0);
	w_as_newline();

	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			w_as_opcode ("call");
			fprintf (assembly_file,mul_or_div_label_name);
			w_as_newline();

			w_as_opcode ("mov");
			w_as_parameter (&instruction->instruction_parameters[0]);
			break;
		case P_IMMEDIATE:
		{
			long v;
			
			v=instruction->instruction_parameters[0].parameter_data.i;

			if ((unsigned)(v+4096) < (unsigned)8192){
				w_as_opcode ("call");
				fprintf (assembly_file,mul_or_div_label_name);
				w_as_newline();
	
				w_as_opcode ("mov");
				w_as_immediate (v);
			} else {
				w_as_opcode ("sethi");
				fprintf (assembly_file,"%%hi ");
#ifdef GAS
				fprintf (assembly_file,"(");
#endif
				w_as_immediate (v);
#ifdef GAS
				fprintf (assembly_file,")");
#endif
				w_as_comma();
				w_as_register (REGISTER_O1);
				w_as_newline();

				w_as_opcode ("call");
				fprintf (assembly_file,mul_or_div_label_name);
				w_as_newline();
			
				w_as_opcode ("or");
				w_as_register (REGISTER_O1);
				w_as_comma();
				fprintf (assembly_file,"%%lo ");
#ifdef GAS
				fprintf (assembly_file,"(");
#endif
				w_as_immediate (v);
#ifdef GAS
				fprintf (assembly_file,")");
#endif
			}
			break;
		}
		default:
			w_as_opcode ("call");
			fprintf (assembly_file,mul_or_div_label_name);
			w_as_newline();

			w_as_ld_parameter (&instruction->instruction_parameters[0]);
	}

    w_as_comma();
	w_as_register (REGISTER_O1);
    w_as_newline();

	w_as_opcode ("mov");
	w_as_register (REGISTER_O0);
    w_as_comma();
    w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_newline();
}

static void w_as_word_instruction (struct instruction *instruction)
{
	fprintf (assembly_file,"\t.word\t%d\n",
			(int)instruction->instruction_parameters[0].parameter_data.i);
}

static void w_as_neg_instruction (struct instruction *instruction)
{
	w_as_opcode ("sub");
	w_as_register_comma (REGISTER_G0);
    w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
    w_as_register (instruction->instruction_parameters[0].parameter_data.reg.r);
	w_as_newline();
}

static void w_as_load_float_indirect (struct parameter *parameter_p,int f_reg)
{
#ifdef ALIGN_REAL_ARRAYS
	if (parameter_p->parameter_flags & LOAD_STORE_ALIGNED_REAL){
		w_as_opcode ("ldd");
		w_as_indirect (parameter_p->parameter_offset,parameter_p->parameter_data.reg.r);
		w_as_comma();
		w_as_fp_register (f_reg<<1);
		w_as_newline();
	} else {
#endif

	w_as_opcode ("ld");
	w_as_indirect (parameter_p->parameter_offset,parameter_p->parameter_data.reg.r);
	w_as_comma();
	w_as_fp_register (f_reg<<1);
	w_as_newline();

	w_as_opcode ("ld");
	w_as_indirect (parameter_p->parameter_offset+4,parameter_p->parameter_data.reg.r);
	w_as_comma();
	w_as_fp_register ((f_reg<<1)+1);
	w_as_newline();

#ifdef ALIGN_REAL_ARRAYS
	}
#endif
}

static void w_as_load_float_indexed (struct parameter *parameter_p,int f_reg)
{
	int offset;
	
	offset=parameter_p->parameter_offset>>2;

#ifdef ALIGN_REAL_ARRAYS
	if (parameter_p->parameter_flags & LOAD_STORE_ALIGNED_REAL){
		if (offset==0){
			w_as_opcode ("ldd");
			w_as_indexed (offset,parameter_p->parameter_data.ir);
			w_as_comma();
			w_as_fp_register (f_reg<<1);
			w_as_newline();
		} else {
			w_as_opcode ("add");
			w_as_register_comma (parameter_p->parameter_data.ir->a_reg.r);
			w_as_register_comma (parameter_p->parameter_data.ir->d_reg.r);
			w_as_register_newline (REGISTER_O0);

			w_as_opcode ("ldd");
			w_as_indirect (offset,REGISTER_O0);
			w_as_comma();
			w_as_fp_register (f_reg<<1);
			w_as_newline();
		}
	} else {
#endif

	w_as_opcode ("add");
	w_as_register_comma (parameter_p->parameter_data.ir->a_reg.r);
	w_as_register_comma (parameter_p->parameter_data.ir->d_reg.r);
	w_as_register_newline (REGISTER_O0);

	w_as_opcode ("ld");
	w_as_indirect (offset,REGISTER_O0);
	w_as_comma();
	w_as_fp_register (f_reg<<1);
	w_as_newline();

	w_as_opcode ("ld");
	w_as_indirect (offset+4,REGISTER_O0);
	w_as_comma();
	w_as_fp_register ((f_reg<<1)+1);
	w_as_newline();

#ifdef ALIGN_REAL_ARRAYS
	}
#endif
}

static int w_as_float_parameter (struct parameter parameter)
{
	switch (parameter.parameter_type){
		case P_F_IMMEDIATE:
		{
			int label_number=next_label_id++;

			w_as_to_data_section();

			w_as_opcode (".align");
			fprintf (assembly_file,"8");
			w_as_newline();

			w_as_define_internal_label (label_number);

			w_as_opcode (".double");
			fprintf (assembly_file,"0r%.20e",*parameter.parameter_data.r);
			w_as_newline();

			w_as_to_code_section();

			w_as_opcode ("sethi");
#ifdef GAS
			fprintf (assembly_file,"%%hi (i_%d),%%o0",label_number);
#else
			fprintf (assembly_file,"%%hi i_%d,%%o0",label_number);
#endif
			w_as_newline();

			w_as_opcode ("ldd");
#ifdef GAS
			fprintf (assembly_file,"[%%o0+%%lo (i_%d)]",label_number);
#else
			fprintf (assembly_file,"[%%o0+%%lo i_%d]",label_number);
#endif
			w_as_comma();
			w_as_fp_register (30);
			w_as_newline();

			return 15;
		}
		case P_INDIRECT:
#ifdef ALIGN_REAL_ARRAYS
			if (parameter.parameter_flags & LOAD_STORE_ALIGNED_REAL){
				w_as_opcode ("ldd");
				w_as_indirect (parameter.parameter_offset,parameter.parameter_data.reg.r);
				w_as_comma();
				w_as_fp_register (30);
				w_as_newline();
			} else {
#endif
			w_as_opcode ("ld");
			w_as_indirect (parameter.parameter_offset,parameter.parameter_data.reg.r);
			w_as_comma();
			w_as_fp_register (30);
			w_as_newline();

			w_as_opcode ("ld");
			w_as_indirect (parameter.parameter_offset+4,parameter.parameter_data.reg.r);
			w_as_comma();
			w_as_fp_register (31);
			w_as_newline();
#ifdef ALIGN_REAL_ARRAYS
			}
#endif
			return 15;
		case P_INDEXED:
		{
			int offset;
			
			offset=parameter.parameter_offset>>2;

#ifdef ALIGN_REAL_ARRAYS
			if (parameter.parameter_flags & LOAD_STORE_ALIGNED_REAL){
				if (offset==0){
					w_as_opcode ("ldd");
					w_as_indexed (offset,parameter.parameter_data.ir);
					w_as_comma();
					w_as_fp_register (30);
					w_as_newline();
				} else {
					w_as_opcode ("add");
					w_as_register_comma (parameter.parameter_data.ir->a_reg.r);
					w_as_register_comma (parameter.parameter_data.ir->d_reg.r);
					w_as_register_newline (REGISTER_O0);

					w_as_opcode ("ldd");
					w_as_indirect (offset,REGISTER_O0);
					w_as_comma();
					w_as_fp_register (30);
					w_as_newline();
				}
			} else {
#endif
			w_as_opcode ("add");
			w_as_register_comma (parameter.parameter_data.ir->a_reg.r);
			w_as_register_comma (parameter.parameter_data.ir->d_reg.r);
			w_as_register_newline (REGISTER_O0);

			w_as_opcode ("ld");
			w_as_indirect (offset,REGISTER_O0);
			w_as_comma();
			w_as_fp_register (30);
			w_as_newline();

			w_as_opcode ("ld");
			w_as_indirect (offset+4,REGISTER_O0);
			w_as_comma();
			w_as_fp_register (31);
			w_as_newline();
#ifdef ALIGN_REAL_ARRAYS
			}
#endif
			return 15;
		case P_F_REGISTER:
			return parameter.parameter_data.reg.r;
		}
	}
	
	internal_error_in_function ("w_as_float_parameter");
	return 0;
}

static void w_as_compare_float_instruction (struct instruction *instruction)
{
	int f_reg;

	f_reg=w_as_float_parameter (instruction->instruction_parameters[0]);

	w_as_opcode_and_d ("fcmp");
	
	w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_comma();
	w_as_fp_register (f_reg<<1);
	w_as_newline();
}

static void w_as_sqrt_float_instruction (struct instruction *instruction)
{
	int f_reg;

	f_reg=w_as_float_parameter (instruction->instruction_parameters[0]);

	w_as_opcode_and_d ("fsqrt");
	
	w_as_fp_register (f_reg<<1);
	w_as_comma();
	w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_newline();
}

static void w_as_neg_or_abs_float_instruction (struct instruction *instruction,char *opcode)
{
	int freg1,freg2;

	freg2=instruction->instruction_parameters[1].parameter_data.reg.r;

	switch (instruction->instruction_parameters[0].parameter_type){
		case P_INDIRECT:
			w_as_load_float_indirect (&instruction->instruction_parameters[0],freg2);
			freg1=freg2;
			break;
		case P_INDEXED:
			w_as_load_float_indexed (&instruction->instruction_parameters[0],freg2);
			freg1=freg2;
			break;
		default:
			freg1=w_as_float_parameter (instruction->instruction_parameters[0]);
	}

	w_as_opcode (opcode);
	w_as_fp_register (freg1<<1);
	w_as_comma();
	w_as_fp_register_newline (freg2<<1);

	if (freg1!=freg2){
		w_as_opcode ("fmovs");
		w_as_fp_register ((freg1<<1)+1);
		w_as_comma();
		w_as_fp_register_newline ((freg2<<1)+1);
	}
}

static void w_as_tryadic_float_instruction (struct instruction *instruction,char *opcode)
{
	int freg;

	freg=w_as_float_parameter (instruction->instruction_parameters[0]);

	w_as_opcode_and_d (opcode);

	w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_comma();
	w_as_fp_register (freg<<1);
	w_as_comma();
	w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_newline();
}

static struct instruction *w_as_fmove_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_F_REGISTER:
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_F_REGISTER:
				{
					struct instruction *next_instruction;
					int reg0,reg1;
					
					reg0=instruction->instruction_parameters[0].parameter_data.reg.r;
					reg1=instruction->instruction_parameters[1].parameter_data.reg.r;
					
					next_instruction=instruction->instruction_next;
					if (next_instruction)
						switch (next_instruction->instruction_icode){
							case IFADD: case IFSUB: case IFMUL: case IFDIV: case IFREM:
								if (next_instruction->instruction_parameters[1].parameter_data.reg.r==reg1)
								{
									int reg_s;

									reg_s=w_as_float_parameter (next_instruction->instruction_parameters[0]);

									if (reg_s==reg1)
										reg_s=reg0;
									
									switch (next_instruction->instruction_icode){
										case IFADD:
											w_as_opcode_and_d ("fadd");
											break;
										case IFSUB:
											w_as_opcode_and_d ("fsub");
											break;
										case IFMUL:
											w_as_opcode_and_d ("fmul");
											break;
										case IFDIV:
											w_as_opcode_and_d ("fdiv");
											break;
										case IFREM:
											w_as_opcode_and_d ("frem");
									}
									w_as_fp_register (reg0<<1);
									w_as_comma();
									w_as_fp_register (reg_s<<1);
									w_as_comma();
									w_as_fp_register (reg1<<1);
									w_as_newline();
									
									return next_instruction;
								}
						}

					w_as_opcode ("fmovs");
					w_as_fp_register (reg0<<1);
					w_as_comma();
					w_as_fp_register (reg1<<1);
					w_as_newline();

					w_as_opcode ("fmovs");
					w_as_fp_register ((reg0<<1)+1);
					w_as_comma();
					w_as_fp_register ((reg1<<1)+1);
					w_as_newline();
				
					return instruction;
				}
				case P_INDIRECT:
					w_as_load_float_indirect (&instruction->instruction_parameters[0],
											  instruction->instruction_parameters[1].parameter_data.reg.r);
					return instruction;
				case P_INDEXED:
					w_as_load_float_indexed (&instruction->instruction_parameters[0],
											 instruction->instruction_parameters[1].parameter_data.reg.r);
					return instruction;
				case P_F_IMMEDIATE:
				{
					int label_number=next_label_id++;

					w_as_to_data_section();

					w_as_opcode (".align");
					fprintf (assembly_file,"8");
					w_as_newline();

					w_as_define_internal_label (label_number);

					w_as_opcode (".double");
					fprintf (assembly_file,"0r%.20e",*instruction->instruction_parameters[0].parameter_data.r);
					w_as_newline();

					w_as_to_code_section();

					w_as_opcode ("sethi");
#ifdef GAS
					fprintf (assembly_file,"%%hi (i_%d),%%o0",label_number);
#else
					fprintf (assembly_file,"%%hi i_%d,%%o0",label_number);
#endif
					w_as_newline();

					w_as_opcode ("ldd");
#ifdef GAS
					fprintf (assembly_file,"[%%o0+%%lo (i_%d)]",label_number);
#else
					fprintf (assembly_file,"[%%o0+%%lo i_%d]",label_number);
#endif
					w_as_comma();
					w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r<<1);
					w_as_newline();
					return instruction;
				}
			}
			break;
		case P_INDIRECT:
			if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
#ifdef ALIGN_REAL_ARRAYS
				if (instruction->instruction_parameters[1].parameter_flags & LOAD_STORE_ALIGNED_REAL){
					w_as_opcode ("std");
					w_as_fp_register (instruction->instruction_parameters[0].parameter_data.reg.r<<1);
					w_as_comma();
					w_as_indirect (instruction->instruction_parameters[1].parameter_offset,
								   instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_newline();

					return instruction;
				}
#endif
				w_as_opcode ("st");
				w_as_fp_register (instruction->instruction_parameters[0].parameter_data.reg.r<<1);
				w_as_comma();
				w_as_indirect (instruction->instruction_parameters[1].parameter_offset,
							   instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_newline();

				w_as_opcode ("st");
				w_as_fp_register ((instruction->instruction_parameters[0].parameter_data.reg.r<<1)+1);
				w_as_comma();
				w_as_indirect (instruction->instruction_parameters[1].parameter_offset+4,
							   instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_newline();
				return instruction;
			}
			break;
		case P_INDEXED:
		{
			int offset;
			
			offset=instruction->instruction_parameters[1].parameter_offset>>2;
			
#ifdef ALIGN_REAL_ARRAYS
			if (instruction->instruction_parameters[1].parameter_flags & LOAD_STORE_ALIGNED_REAL){
				if (offset==0){
					w_as_opcode ("std");
					w_as_fp_register (instruction->instruction_parameters[0].parameter_data.reg.r<<1);
					w_as_comma();
					w_as_indexed (offset,instruction->instruction_parameters[1].parameter_data.ir);
					w_as_newline();					
				} else {
					w_as_opcode ("add");
					w_as_register_comma (instruction->instruction_parameters[1].parameter_data.ir->a_reg.r);
					w_as_register_comma (instruction->instruction_parameters[1].parameter_data.ir->d_reg.r);
					w_as_register_newline (REGISTER_O0);

					w_as_opcode ("std");
					w_as_fp_register (instruction->instruction_parameters[0].parameter_data.reg.r<<1);
					w_as_comma();
					w_as_indirect (offset,REGISTER_O0);
					w_as_newline();
				}
				return instruction;
			}
#endif
			if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
				w_as_opcode ("add");
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.ir->a_reg.r);
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.ir->d_reg.r);
				w_as_register_newline (REGISTER_O0);

				w_as_opcode ("st");
				w_as_fp_register (instruction->instruction_parameters[0].parameter_data.reg.r<<1);
				w_as_comma();
				w_as_indirect (offset,REGISTER_O0);
				w_as_newline();

				w_as_opcode ("st");
				w_as_fp_register ((instruction->instruction_parameters[0].parameter_data.reg.r<<1)+1);
				w_as_comma();
				w_as_indirect (offset+4,REGISTER_O0);
				w_as_newline();

				return instruction;
			}
		}
	}
	internal_error_in_function ("w_as_fmove_instruction");
	return instruction;
}

static void w_as_fmove_hl_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT
		&&	instruction->instruction_parameters[1].parameter_type==P_F_REGISTER)
	{
		w_as_opcode_indirect ("ld",
								instruction->instruction_parameters[0].parameter_offset,
						 		instruction->instruction_parameters[0].parameter_data.reg.r);
		w_as_comma();
		if (instruction->instruction_icode==IFMOVEHI)
			w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r<<1);
		else
			w_as_fp_register ((instruction->instruction_parameters[1].parameter_data.reg.r<<1)+1);
	
		w_as_newline();
		return;
	}
	
	internal_error_in_function ("w_as_fmove_instruction");
}

static void w_as_fmovel_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
		if (instruction->instruction_parameters[1].parameter_type!=P_REGISTER)
			internal_error_in_function ("w_as_fmovel_instruction");

		w_as_opcode ("fdtoi");
		w_as_fp_register (instruction->instruction_parameters[0].parameter_data.reg.r<<1);
		w_as_comma();
		w_as_fp_register (31);
		w_as_newline();

		w_as_opcode ("st");
		w_as_fp_register (31);
		w_as_comma();
		w_as_indirect (-4,REGISTER_I6);
		w_as_newline();

		w_as_opcode ("ld");
		w_as_indirect (-4,REGISTER_I6);
		w_as_comma();
		w_as_register (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_newline();
	} else {
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_REGISTER:
				w_as_opcode ("st");
				w_as_register (instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_comma();
				w_as_indirect (-4,REGISTER_I6);
				w_as_newline();

				w_as_opcode ("ld");
				w_as_indirect (-4,REGISTER_I6);
				w_as_comma();	
				w_as_fp_register (31);
				w_as_newline();
				break;
			case P_INDIRECT:
				w_as_opcode ("ld");
				w_as_indirect (instruction->instruction_parameters[0].parameter_offset,
							   instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_comma();
				w_as_fp_register (31);
				w_as_newline();
				break;
			case P_INDEXED:
				w_as_opcode ("ld");
				w_as_indexed (instruction->instruction_parameters[0].parameter_offset,
							  instruction->instruction_parameters[0].parameter_data.ir);
				w_as_comma();
				w_as_fp_register (31);
				w_as_newline();
				break;
			case P_IMMEDIATE:
				w_as_opcode ("set");
				w_as_immediate (instruction->instruction_parameters[0].parameter_data.i);
				w_as_comma();
				w_as_scratch_register();
				w_as_newline();

				w_as_opcode ("st");
				w_as_scratch_register();
				w_as_comma();
				w_as_indirect (-4,REGISTER_I6);
				w_as_newline();

				w_as_opcode ("ld");
				w_as_indirect (-4,REGISTER_I6);
				w_as_comma();	
				w_as_fp_register (31);
				w_as_newline();
				break;			
			default:
				internal_error_in_function ("w_as_fmovel_instruction");
		}

		w_as_opcode ("fitod");
		w_as_fp_register (31);
		w_as_comma();
		w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r<<1);
		w_as_newline();
	}
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
			case IADDI:
				w_as_i_instruction (instruction,"add");
				break;
			case ISUB:
				w_as_sub_instruction (instruction);
				break;
			case ICMP:
				w_as_cmp_instruction (instruction);
				break;
			case IJMP:
				w_as_jmp_instruction (instruction);
				break;
			case IJSR:
				w_as_jsr_instruction (instruction);
				break;
			case IRTS:
				w_as_rts_instruction (instruction);
				break;
			case IBEQ:
				w_as_branch_instruction (instruction,"be");
				break;
			case IBGE:
				w_as_branch_instruction (instruction,"bge");
				break;
			case IBGT:
				w_as_branch_instruction (instruction,"bg");
				break;
			case IBHS:
				w_as_index_error_branch_instruction (instruction);
				break;
			case IBLE:
				w_as_branch_instruction (instruction,"ble");
				break;
			case IBLT:
				w_as_branch_instruction (instruction,"bl");
				break;
			case IBNE:
				w_as_branch_instruction (instruction,"bne");
				break;
			case IBNO:
				w_as_branch_instruction (instruction,"bvc");
				break;
			case IBO:
				w_as_branch_instruction (instruction,"bvs");
				break;
			case ILSLI:
				w_as_i_instruction (instruction,"sll");
				break;
			case ILSL:
				w_as_tryadic_instruction (instruction,"sll");
				break;
			case ILSR:
				w_as_tryadic_instruction (instruction,"srl");
				break;
			case IASR:
				w_as_tryadic_instruction (instruction,"sra");
				break;
			case IMUL:
				w_as_mul_or_div_instruction (instruction,".mul");
				break;
			case IDIV:
				w_as_mul_or_div_instruction (instruction,".div");
				break;
			case IREM:
				w_as_mod_instruction (instruction);
				break;
			case IAND:
				w_as_tryadic_instruction (instruction,"and");
				break;
			case IOR:
				w_as_tryadic_instruction (instruction,"or");
				break;
			case IEOR:
				w_as_tryadic_instruction (instruction,"xor");
				break;
			case ISEQ:
				w_as_set_condition_instruction (instruction,"be,a");
				break;
			case ISGE:
				w_as_set_condition_instruction (instruction,"bge,a");
				break;
			case ISGT:
				w_as_set_condition_instruction (instruction,"bg,a");
				break;
			case ISLE:
				w_as_set_condition_instruction (instruction,"ble,a");
				break;
			case ISLT:
				w_as_set_condition_instruction (instruction,"bl,a");
				break;
			case ISNE:
				w_as_set_condition_instruction (instruction,"bne,a");
				break;
			case ISNO:
				w_as_set_condition_instruction (instruction,"bvc,a");
				break;
			case ISO:
				w_as_set_condition_instruction (instruction,"bvs,a");
				break;
#if 0
			case ICMPW:
				w_as_cmpw_instruction (instruction);
				break;
#endif
			case ITST:
				w_as_tst_instruction (instruction,SIZE_LONG);
				break;
			case IBTST:
				w_as_btst_instruction (instruction);
				break;
			case IMOVEDB:
				w_as_move_instruction (instruction,SIZE_WORD);
				break;
			case IMOVEB:
				w_as_move_instruction (instruction,SIZE_BYTE);
				break;
			case INEG:
				w_as_neg_instruction (instruction);
				break;
			case IFMOVE:
				instruction=w_as_fmove_instruction (instruction);
				break;
			case IFMOVEHI:
			case IFMOVELO:
				w_as_fmove_hl_instruction (instruction);
				break;
			case IFADD:
				w_as_tryadic_float_instruction (instruction,"fadd");
				break;
			case IFSUB:
				w_as_tryadic_float_instruction (instruction,"fsub");
				break;
			case IFCMP:
				w_as_compare_float_instruction (instruction);
				break;
			case IFDIV:
				w_as_tryadic_float_instruction (instruction,"fdiv");
				break;
			case IFMUL:
				w_as_tryadic_float_instruction (instruction,"fmul");
				break;
			case IFREM:
				w_as_tryadic_float_instruction (instruction,"frem");
				break;
			case IFBEQ:
				w_as_float_branch_instruction (instruction,"fbe");
				break;
			case IFBGE:
				w_as_float_branch_instruction (instruction,"fbge");
				break;
			case IFBGT:
				w_as_float_branch_instruction (instruction,"fbg");
				break;
			case IFBLE:
				w_as_float_branch_instruction (instruction,"fble");
				break;
			case IFBLT:
				w_as_float_branch_instruction (instruction,"fbl");
				break;
			case IFBNE:
				w_as_float_branch_instruction (instruction,"fbne");
				break;
			case IFMOVEL:
				w_as_fmovel_instruction (instruction);
				break;
			case IFSQRT:
				w_as_sqrt_float_instruction (instruction);
				break;
			case IFNEG:
				w_as_neg_or_abs_float_instruction (instruction,"fnegs");
				break;
			case IFABS:
				w_as_neg_or_abs_float_instruction (instruction,"fabss");
				break;
			case IFSEQ:
				w_as_set_float_condition_instruction (instruction,"fbe,a");
				break;
			case IFSGE:
				w_as_set_float_condition_instruction (instruction,"fbge,a");
				break;
			case IFSGT:
				w_as_set_float_condition_instruction (instruction,"fbg,a");
				break;
			case IFSLE:
				w_as_set_float_condition_instruction (instruction,"fble,a");
				break;
			case IFSLT:
				w_as_set_float_condition_instruction (instruction,"fbl,a");
				break;
			case IFSNE:
				w_as_set_float_condition_instruction (instruction,"fbne,a");
				break;
			case IWORD:
				w_as_word_instruction (instruction);
				break;
			case IADDO:
				w_as_add_o_instruction (instruction);
				break;
			case ISUBO:
				w_as_sub_o_instruction (instruction);
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
	w_as_opcode (".word");
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
	
	new_call_and_jump=allocate_memory_from_heap (sizeof (struct call_and_jump));

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

	if (n_cells<4096){
		w_as_opcode ("deccc");
		w_as_immediate (n_cells);
		w_as_comma();
		w_as_register (REGISTER_D7);
		w_as_newline();
	} else {
		w_as_opcode ("set");
		w_as_immediate (n_cells);
		w_as_comma();
		w_as_scratch_register();
		w_as_newline();

		w_as_opcode ("subcc");
		w_as_register (REGISTER_D7);
		w_as_comma();
		w_as_scratch_register();
		w_as_comma();
		w_as_register (REGISTER_D7);
		w_as_newline();
	}
	
	w_as_opcode ("bcs,a");
	w_as_internal_label (label_id_1);
	w_as_newline ();

	w_as_opcode ("dec");
	w_as_immediate (4);
	w_as_comma();
	w_as_register (B_STACK_POINTER);
	w_as_newline();
	
	w_as_define_internal_label (label_id_2);
}

static void w_as_call_and_jump (struct call_and_jump *call_and_jump)
{
	w_as_define_internal_label (call_and_jump->cj_label_id);

	w_as_opcode ("call");
	w_as_label (call_and_jump->cj_call_label_name);
	w_as_newline();

	w_as_opcode ("st");
	w_as_register (REGISTER_O7);
	w_as_comma();
	w_as_indirect (0,B_STACK_POINTER);
	w_as_newline();
	
	w_as_opcode ("b,a");
	w_as_internal_label (call_and_jump->cj_jump_id);
	w_as_newline();
}

static void w_as_labels (struct block_label *labels)
{
	for (; labels!=NULL; labels=labels->block_label_next)
		if (labels->block_label_label->label_number==0){
			LABEL *label;
			
			label=labels->block_label_label;
			
			w_as_define_label (label);
		} else
			w_as_define_local_label (labels->block_label_label->label_number);
}

/*
static void init_c_stack_checking (VOID)
{
	w_as_define_label_name (local_c_stack_overflow_label_name);
	w_as_opcode ("ba");
	w_as_label (c_stack_overflow_label->label_name);
	w_as_newline();

	w_as_instruction_without_parameters ("nop");
}
*/

static char local_ab_stack_overflow_label_name[]="l_ab_stack_overflow";

/*
static void init_ab_stack_checking (VOID)
{
	w_as_define_label_name (local_ab_stack_overflow_label_name);
	w_as_opcode ("ba");
	w_as_label (ab_stack_overflow_label->label_name);
	w_as_newline();

	w_as_instruction_without_parameters ("nop");
}
*/
/*
static void w_as_check_ab_stack (int size,int n_d_parameters,int n_a_parameters)
{
	if (size<=4){
		w_as_opcode ("cmp");
		w_as_register (A_STACK_POINTER);
		w_as_comma();
		w_as_register (B_STACK_POINTER);
		w_as_newline();

		w_as_opcode ("bleu");
	} else {
		w_as_opcode ("add");
		w_as_register (B_STACK_POINTER);
		w_as_comma();
		w_as_immediate (size);
		w_as_comma();
		w_as_register (REGISTER_O0);
		w_as_newline();

		w_as_opcode ("cmp");
		w_as_register (REGISTER_O0);
		w_as_comma();
		w_as_register (A_STACK_POINTER);
		w_as_newline();

		w_as_opcode ("bgu");
	}
	w_as_label (local_ab_stack_overflow_label_name);
	w_as_newline();

	w_as_instruction_without_parameters ("nop");
}
*/

void initialize_write_assembly (FILE *ass_file)
{
	assembly_file=ass_file;
	
	in_data_section=0;

	first_call_and_jump=NULL;

	/*
	if (check_c_stack)
		init_c_stack_checking();
	if (check_ab_stack)
		init_ab_stack_checking();
	*/
}

static void w_as_indirect_node_entry_jump (LABEL *label)
{
	register char *new_label_name;

	new_label_name=fast_memory_allocate (strlen (label->label_name)+1+2);
	strcpy (new_label_name,"j_");
	strcat (new_label_name,label->label_name);

	if (label->label_flags & EA_LABEL){
		int label_arity;
		extern LABEL *eval_fill_label,*eval_upd_labels[];

		label_arity=label->label_arity;
		
		if (label_arity<-2)
			label_arity=1;
		
		if (label_arity>=0 && label->label_ea_label!=eval_fill_label){
			w_as_opcode ("sethi");
			fprintf (assembly_file,"%%hi ");
#ifdef GAS
			fprintf (assembly_file,"(");
#endif
			w_as_label (label->label_ea_label->label_name);
#ifdef GAS
			fprintf (assembly_file,")");
#endif
			w_as_comma();
			w_as_register (REGISTER_A2);
			w_as_newline();
		
			w_as_opcode ("call");
			w_as_label (eval_upd_labels[label_arity]->label_name);
			w_as_newline();

			w_as_opcode ("inc");
			fprintf (assembly_file,"%%lo ");
#ifdef GAS
			fprintf (assembly_file,"(");
#endif
			w_as_label (label->label_ea_label->label_name);
#ifdef GAS
			fprintf (assembly_file,")");
#endif
			w_as_comma();
			w_as_register (REGISTER_A2);
			w_as_newline();
		} else {
			w_as_opcode ("call");
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

			w_as_opcode (".long");
			w_as_label (descriptor_label->label_name);
			w_as_newline();
		} else
			w_as_number_of_arguments (0);
	} else
		if (label->label_arity<0 || parallel_flag){
			LABEL *descriptor_label;

			descriptor_label=label->label_descriptor;

			if (descriptor_label->label_id<0)
				descriptor_label->label_id=next_label_id++;

			w_as_opcode (".long");
			w_as_label (descriptor_label->label_name);
			w_as_newline();
		}

	w_as_number_of_arguments (label->label_arity);
	
	w_as_define_label_name (new_label_name);
	
	w_as_opcode ("call");
	w_as_label (label->label_name);
	w_as_newline();
	
	label->label_name=new_label_name;
	
	w_as_instruction_without_parameters ("nop");
}

static void w_as_indirect_node_entry_jumps (struct label_node *label_node)
{
	LABEL *label;
	
	if (label_node==NULL)
		return;
	
	label=&label_node->label_node_label;
	
	if (!(label->label_flags & LOCAL_LABEL) && label->label_number==0)
		if (label->label_flags & NODE_ENTRY_LABEL)
			w_as_indirect_node_entry_jump (label);
	
	w_as_indirect_node_entry_jumps (label_node->label_node_left);
	w_as_indirect_node_entry_jumps (label_node->label_node_right);
}

#ifdef SOLARIS_
static int next_section_number;
extern char *this_module_name;
#endif

#ifdef NEW_APPLY
extern LABEL *add_empty_node_labels[];

static void w_as_apply_update_entry (struct basic_block *block)
{
	if (block->block_n_node_arguments==-200){
		w_as_opcode ("ba,a");
		w_as_label (block->block_ea_label->label_name);
		w_as_newline();

		w_as_instruction_without_parameters ("nop");
		w_as_instruction_without_parameters ("nop");
		w_as_instruction_without_parameters ("nop");
	} else {
		w_as_opcode ("dec");
		w_as_immediate (4);
		w_as_comma();
		w_as_register_newline (B_STACK_POINTER);

		w_as_opcode ("call");
		w_as_label (add_empty_node_labels[block->block_n_node_arguments+200]->label_name);
		w_as_newline();

		w_as_opcode ("st");
		w_as_register (REGISTER_O7);
		w_as_comma();
		w_as_indirect (0,B_STACK_POINTER);
		w_as_newline();

		w_as_opcode ("ba,a");
		w_as_label (block->block_ea_label->label_name);
		w_as_newline();
	}
}
#endif

void write_assembly (VOID)
{
	struct basic_block *block;
	struct call_and_jump *call_and_jump;

#ifdef SOLARIS_
	next_section_number=0;
#endif

	w_as_to_code_section();
	
	w_as_indirect_node_entry_jumps (labels);

	for (block=first_block; block!=NULL; block=block->block_next){
#ifdef SOLARIS_
		if (block->block_begin_module && !block->block_link_module){
			if (block->block_labels!=NULL && block->block_labels->block_label_label->label_number==0 && block->block_labels->block_label_label->label_flags & EXPORT_LABEL)
				fprintf (assembly_file,"\t.section\t\".%s\",#alloc,#execinstr\n",block->block_labels->block_label_label->label_name);
			else
				fprintf (assembly_file,"\t.section\t\"%s.%d\",#alloc,#execinstr\n",this_module_name,next_section_number++);
		}
#endif

		if (block->block_n_node_arguments>-100){
			if (block->block_ea_label!=NULL){
				int n_node_arguments;
				extern LABEL *eval_fill_label,*eval_upd_labels[];
				
				n_node_arguments=block->block_n_node_arguments;
				
				if (n_node_arguments<-2)
					n_node_arguments=1;
				
				if (n_node_arguments>=0 && block->block_ea_label!=eval_fill_label){
					w_as_opcode ("sethi");
					fprintf (assembly_file,"%%hi ");
#ifdef GAS
					fprintf (assembly_file,"(");
#endif
					w_as_label (block->block_ea_label->label_name);
#ifdef GAS
					fprintf (assembly_file,")");
#endif
					w_as_comma();
					w_as_register (REGISTER_A2);
					w_as_newline();
				
					w_as_opcode ("call");
					w_as_label (eval_upd_labels[n_node_arguments]->label_name);
					w_as_newline();

					w_as_opcode ("inc");
					fprintf (assembly_file,"%%lo ");
#ifdef GAS
					fprintf (assembly_file,"(");
#endif
					w_as_label (block->block_ea_label->label_name);
#ifdef GAS
					fprintf (assembly_file,")");
#endif
					w_as_comma();
					w_as_register (REGISTER_A2);
					w_as_newline();
				} else {
					w_as_opcode ("call");
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
				if (block->block_descriptor!=NULL)
					w_as_label_in_code_section (block->block_descriptor->label_name);
				else
					w_as_number_of_arguments (0);

			w_as_number_of_arguments (block->block_n_node_arguments);
		}
#ifdef NEW_APPLY
		else if (block->block_n_node_arguments<-100)
			w_as_apply_update_entry (block);
#endif

		w_as_labels (block->block_labels);

		if (block->block_n_new_heap_cells>0)
			w_as_garbage_collect_test (block);
		/*
		if (check_ab_stack && block->block_ab_stack_check_size>0)
			w_as_check_ab_stack (block->block_ab_stack_check_size,
				block->block_n_begin_d_parameter_registers,block->block_n_begin_a_parameter_registers);
		*/
		
		w_as_instructions (block->block_instructions);
	}
	
	for (call_and_jump=first_call_and_jump; call_and_jump!=NULL; call_and_jump=call_and_jump->cj_next)
		w_as_call_and_jump (call_and_jump);
	
	w_as_instruction_without_parameters ("nop");
}
