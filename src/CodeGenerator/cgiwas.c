/*
	File:	 cgiwas.c
	Author:  John van Groningen
	Machine: 80386 80486
*/

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>

#define FSUB_FDIV_REVERSED

#include "cgport.h"
#include "cgrconst.h"
#include "cgtypes.h"
#include "cg.h"
#include "cgiconst.h"
#include "cgcode.h"
#include "cginstructions.h"
#include "cgias.h"

#include "cgiwas.h"

int intel_asm=0;

#define for_l(v,l,n) for(v=(l);v!=NULL;v=v->n)

#define IO_BUF_SIZE 8192

static FILE *assembly_file;

static void w_as_newline (VOID)
{
	putc ('\n',assembly_file);
}

static void w_as_opcode (char *opcode)
{
	fprintf (assembly_file,"\t%s\t",opcode);
}

static void w_as_opcode_p (char *opcode)
{
	fprintf (assembly_file,"\t%sp\t",opcode);
}

static void w_as_instruction_without_parameters (char *opcode)
{
	fprintf (assembly_file,"\t%s\n",opcode);
}

static void w_as_define_local_label (int label_number)
{
	fprintf (assembly_file,"l_%d:\n",label_number);
}

static void w_as_define_local_data_label (int label_number)
{
	fprintf (assembly_file,intel_asm ? "l_%d label ptr\n" : "l_%d:\n",label_number);
}

static void w_as_define_internal_label (int label_number)
{
	fprintf (assembly_file,"i_%d:\n",label_number);
}

static void w_as_define_internal_data_label (int label_number)
{
	fprintf (assembly_file,intel_asm ? "i_%d label ptr\n" : "i_%d:\n",label_number);
}

void w_as_internal_label_value (int label_id)
{
	fprintf (assembly_file,intel_asm ? "\tdd\ti_%d\n" : "\t.long\ti_%d\n",label_id);
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

#ifdef DATA_IN_CODE_SECTION
# define w_as_to_data_section w_as_to_code_section
#endif

static void w_as_to_code_section (VOID)
{
	if (in_data_section){
		in_data_section=0;
		w_as_instruction_without_parameters (intel_asm ? ".code" : ".text");
	}
}

static void w_as_align (int i)
{
#if defined (DOS) || defined (_WINDOWS_) || defined (LINUX_ELF)
	fprintf (assembly_file,intel_asm ? "\talign\t%d\n" : "\t.align\t%d\n",1<<i);
#else
	fprintf (assembly_file,intel_asm ? "\talign\t%d\n" : "\t.align\t%d\n",i);
#endif
}

static void w_as_space (int i)
{
	if (intel_asm){
		if (i>0){
			w_as_opcode ("db");
			fprintf (assembly_file,"0");
			while (--i>0)
				fprintf (assembly_file,",0");
			w_as_newline();
		}
	} else
		fprintf (assembly_file,"\t.space\t%d\n",i);
}

void w_as_word_in_data_section (int n)
{
	w_as_to_data_section();
	w_as_opcode (intel_asm ? "dw" : ".word");
	fprintf (assembly_file,"%d",n);
	w_as_newline();
}

void w_as_long_in_data_section (int n)
{
#ifdef DATA_IN_CODE_SECTION
	if (!in_data_section){
		in_data_section=1;
		w_as_instruction_without_parameters (".data");
	}
#else
	w_as_to_data_section();
#endif
	w_as_opcode (intel_asm ? "dd" : ".long");
	fprintf (assembly_file,"%d",n);
	w_as_newline();
}

void w_as_label_in_data_section (char *label_name)
{
	w_as_to_data_section ();
	fprintf (assembly_file,intel_asm ? "\tdd\t%s\n" : "\t.long\t%s\n",label_name);
}

static void w_as_label_in_code_section (char *label_name)
{
	w_as_to_code_section ();
	fprintf (assembly_file,intel_asm ? "\tdd\t%s\n" : "\t.long\t%s\n",label_name);
}

void w_as_descriptor_in_data_section (char *label_name)
{
	w_as_to_data_section();
	w_as_align (2);
	fprintf (assembly_file,intel_asm ? "\tdd\t%s+2\n" : "\t.long\t%s+2\n",label_name);
}

#define MAX_BYTES_PER_LINE 16

static int w_as_data (int n,char *data,int length)
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
		
		c=((unsigned char*)data)[i];
		if (isalnum (c) || c=='_' || c==' ' || c=='.'){
			if (!in_string){
				if (n!=0)
					w_as_newline();
				w_as_opcode (intel_asm ? "db" : ".ascii");
				putc ('\"',assembly_file);
				in_string=1;
				n=0;
			}
			putc (c,assembly_file);
		} else {
			if (n==0)
				w_as_opcode (intel_asm ? "db" : ".byte");
			else {
				if (in_string){
					putc ('\"',assembly_file);
					w_as_newline();
					w_as_opcode (intel_asm ? "db" : ".byte");
					in_string=0;
					n=0;
				} else
					putc (',',assembly_file);
			}

			fprintf (assembly_file,intel_asm ? "%02xh" : "0x%02x",c);
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
			w_as_opcode (intel_asm ? "db" : ".byte");
		else
			putc (',',assembly_file);
		fprintf (assembly_file,"0");
		++n;
	}
	return n;
}

void w_as_define_data_label (int label_number)
{
	w_as_to_data_section();
	
	w_as_define_local_data_label (label_number);
}

void w_as_labeled_c_string_in_data_section (char *string,int length,int label_number)
{
	int n;
	
	w_as_to_data_section();
	
	w_as_define_local_data_label (label_number);
	
	n=w_as_data (0,string,length);
	if (length & 3)
		n=w_as_zeros (n,4-(length & 3));
	else
		n=w_as_zeros (n,4);
	if (n>0)
		w_as_newline();
}

void w_as_c_string_in_data_section (char *string,int length)
{
	int n;
	
	w_as_to_data_section();
	
	n=w_as_data (0,string,length);
	if (length & 3)
		n=w_as_zeros (n,4-(length & 3));
	/* CHANGED 30-7-92 */
	else
		n=w_as_zeros (n,4);
	/* */
	if (n>0)
		w_as_newline();
}

void w_as_abc_string_in_data_section (char *string,int length)
{
	int n;
	
	w_as_to_data_section();
	
	w_as_opcode (intel_asm ? "dd" : ".long");
	fprintf (assembly_file,"%d\n",length);
	n=w_as_data (0,string,length);
	if (length & 3)
		n=w_as_zeros (n,4-(length & 3));
	if (n>0)
		w_as_newline();
}

void w_as_descriptor_string_in_data_section (char *string,int length,int string_label_id,LABEL *string_label)
{
	int n;
	
	w_as_to_data_section();
	
	w_as_define_internal_data_label (string_label_id);
	w_as_define_local_data_label (string_label->label_number);

	w_as_opcode (intel_asm ? "dd" : ".long");
	fprintf (assembly_file,"%d\n",length);
	n=w_as_data (0,string,length);
	if (length & 3)
		n=w_as_zeros (n,4-(length & 3));
	if (n>0)
		w_as_newline();
}

enum { SIZE_LONG, SIZE_WORD, SIZE_BYTE };

static void w_as_label (char *label)
{
	int c;
	
	while ((c=*label++)!=0)
		putc (c,assembly_file);
}

static void w_as_immediate_label (char *label)
{
	int c;
	
	if (!intel_asm)
		putc ('$',assembly_file);
	else
		fprintf (assembly_file,"offset ");
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

static void w_as_define_data_label_name (char *label_name)
{
	w_as_label (label_name);
	if (intel_asm)
		fprintf (assembly_file," label ptr");
	else
		w_as_colon();
	w_as_newline();
}

void w_as_define_label (LABEL *label)
{
	if (label->label_flags & EXPORT_LABEL){
		w_as_opcode (intel_asm ? "public" : ".globl");
		w_as_label (label->label_name);
		w_as_newline();
	}
	
	w_as_label (label->label_name);
	if (intel_asm)
		fprintf (assembly_file,"\tlabel ptr");
	else
		w_as_colon();
	w_as_newline();
}

static void w_as_define_code_label (LABEL *label)
{
	if (label->label_flags & EXPORT_LABEL){
		w_as_opcode (intel_asm ? "public" : ".globl");
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
	fprintf (assembly_file,intel_asm ? "%ld" : "$%ld",i);
}

void w_as_abc_string_and_label_in_data_section (char *string,int length,char *label_name)
{
	int n;

	w_as_to_data_section();
	
	w_as_define_data_label_name (label_name);
	
	w_as_opcode (intel_asm ? "dd" : ".long");
	fprintf (assembly_file,"%d\n",length);
	n=w_as_data (0,string,length);
	if (length & 3)
		n=w_as_zeros (n,4-(length & 3));
	if (n>0)
		w_as_newline();
}

#ifdef MORE_PARAMETER_REGISTERS
static char register_name_char1[10]="sdsbdcabdc";
static char register_name_char2[10]="piipxxxxxx";

static char byte_register_name_char1[10]="____dcabdc";
#else
static char register_name_char1[8]="sdsbdcab";
static char register_name_char2[8]="piipxxxx";

static char byte_register_name_char1[8]="____dcab";
#endif

#define REGISTER_O0 (-3)

static void w_as_indirect (int i,int reg)
{
	if (!intel_asm){
		if (i!=0){
			fprintf (assembly_file,"%d(%%e%c%c)",i,register_name_char1[reg+6],register_name_char2[reg+6]);
		} else
			fprintf (assembly_file,"(%%e%c%c)",register_name_char1[reg+6],register_name_char2[reg+6]);
	} else {
		if (i>0)
			fprintf (assembly_file,"%d[e%c%c]",i,register_name_char1[reg+6],register_name_char2[reg+6]);
		else if (i==0)
			fprintf (assembly_file,"[e%c%c]",register_name_char1[reg+6],register_name_char2[reg+6]);	
		else
			fprintf (assembly_file,"(%d)[e%c%c]",i,register_name_char1[reg+6],register_name_char2[reg+6]);
	}
}

static void w_as_indexed (int offset,struct index_registers *index_registers)
{	
	int reg1,reg2,shift;

	reg1=index_registers->a_reg.r;
	reg2=index_registers->d_reg.r;

	shift=offset & 3;
	offset=offset>>2;

	if (offset!=0){
		if (!intel_asm || offset>0){
			if (shift!=0)
				fprintf (assembly_file,intel_asm ? "%d[e%c%c+e%c%c*%d]" : "%d(%%e%c%c,%%e%c%c,%d)",offset,
						 register_name_char1[reg1+6],register_name_char2[reg1+6],
						 register_name_char1[reg2+6],register_name_char2[reg2+6],1<<shift);
			else
				fprintf (assembly_file,intel_asm ? "%d[e%c%c+e%c%c]" : "%d(%%e%c%c,%%e%c%c)",offset,
						 register_name_char1[reg1+6],register_name_char2[reg1+6],
						 register_name_char1[reg2+6],register_name_char2[reg2+6]);
		} else {
			if (shift!=0)
				fprintf (assembly_file,"(%d)[e%c%c+e%c%c*%d]",offset,
						 register_name_char1[reg1+6],register_name_char2[reg1+6],
						 register_name_char1[reg2+6],register_name_char2[reg2+6],1<<shift);
			else
				fprintf (assembly_file,"(%d)[e%c%c+e%c%c]",offset,
						 register_name_char1[reg1+6],register_name_char2[reg1+6],
						 register_name_char1[reg2+6],register_name_char2[reg2+6]);
		}
	} else {
		if (shift!=0)
			fprintf (assembly_file,intel_asm ? "[e%c%c+e%c%c*%d]" : "(%%e%c%c,%%e%c%c,%d)",
					 register_name_char1[reg1+6],register_name_char2[reg1+6],
					 register_name_char1[reg2+6],register_name_char2[reg2+6],1<<shift);
		else
			fprintf (assembly_file,intel_asm ? "[e%c%c+e%c%c]" : "(%%e%c%c,%%e%c%c)",
					 register_name_char1[reg1+6],register_name_char2[reg1+6],
					 register_name_char1[reg2+6],register_name_char2[reg2+6]);
	}
}

static void w_as_register (int reg)
{
	if (!intel_asm)
		putc ('%',assembly_file);
	putc ('e',assembly_file);
	putc (register_name_char1[reg+6],assembly_file);
	putc (register_name_char2[reg+6],assembly_file);
}

static void w_as_comma (VOID)
{
	putc (',',assembly_file);
}

static void w_as_register_comma (int reg)
{
	w_as_register (reg);
	w_as_comma();
}

static void w_as_comma_register (int reg)
{
	w_as_comma();
	w_as_register (reg);
}

void w_as_c_string_and_label_in_code_section (char *string,int length,char *label_name)
{
	int n;
	
/*	w_as_to_code_section(); */
	w_as_to_data_section();
	
	w_as_define_data_label_name (label_name);
	
	n=w_as_data (0,string,length);
	n=w_as_zeros (n,4-(length & 3));
	if (n>0)
		w_as_newline();
}

static void w_as_scratch_register (void)
{
	w_as_register (REGISTER_O0);
}

static void w_as_scratch_register_comma (void)
{
	w_as_register (REGISTER_O0);
	w_as_comma();
}

static void w_as_comma_scratch_register (void)
{
	w_as_comma();
	w_as_register (REGISTER_O0);
}

static void w_as_fp_register (int fp_reg)
{
	fprintf (assembly_file,intel_asm ? "st(%d)" : "%%st(%d)",fp_reg);
}

static void w_as_fp_register_newline (int fp_reg)
{
	fprintf (assembly_file,intel_asm ? "st(%d)\n" : "%%st(%d)\n",fp_reg);
}

static void w_as_descriptor (LABEL *label,int arity)
{
	if (!intel_asm)
		putc ('$',assembly_file);
	else
		fprintf (assembly_file,"offset ");

	if (label->label_number!=0)
		w_as_local_label (label->label_number);
	else
		w_as_label (label->label_name);

	if (arity!=0)
		if (arity>0)
			fprintf (assembly_file,"+%d",arity);
		else
			fprintf (assembly_file,"-%d",-arity);
}
		
static void w_as_parameter (struct parameter *parameter)
{
	switch (parameter->parameter_type){
		case P_REGISTER:
			w_as_register (parameter->parameter_data.reg.r);
			break;
		case P_LABEL:
			if (intel_asm)
				fprintf (assembly_file,"offset ");
			if (parameter->parameter_data.l->label_number!=0)
				w_as_local_label (parameter->parameter_data.l->label_number);
			else
				w_as_label (parameter->parameter_data.l->label_name);
			break;
		case P_IMMEDIATE:
			fprintf (assembly_file,intel_asm ? "%ld" : "$%ld",parameter->parameter_data.i);
			break;
		case P_INDIRECT:
			w_as_indirect (parameter->parameter_offset,parameter->parameter_data.reg.r);
			break;
		case P_INDEXED:
			w_as_indexed (parameter->parameter_offset,parameter->parameter_data.ir);
			break;
		case P_F_REGISTER:
			fprintf (assembly_file,intel_asm ? "st(%d)" : "%%st(%d)",parameter->parameter_data.reg.r<<1);
			break;
		default:
			internal_error_in_function ("w_as_parameter");
	}
}

static void w_as_branch_parameter (struct parameter *parameter)
{
	switch (parameter->parameter_type){
		case P_LABEL:
			if (parameter->parameter_data.l->label_number!=0)
				w_as_local_label (parameter->parameter_data.l->label_number);
			else
				w_as_label (parameter->parameter_data.l->label_name);
			break;
		default:
			internal_error_in_function ("w_as_branch_parameter");
	}
}

static void w_as_parameter_comma (struct parameter *parameter)
{
	w_as_parameter (parameter);
	w_as_comma();
}

static void w_as_comma_parameter (struct parameter *parameter)
{
	w_as_comma();
	w_as_parameter (parameter);
}

static void w_as_comma_word_parameter (struct parameter *parameter)
{
	int reg;
	
	w_as_comma();
	if (parameter->parameter_type!=P_REGISTER)
		internal_error_in_function ("w_as_comma_word_parameter");

	reg=parameter->parameter_data.reg.r;

	putc (register_name_char1[reg+6],assembly_file);
	putc (register_name_char2[reg+6],assembly_file);
}

static void w_as_comma_byte_register (int reg)
{	
	w_as_comma();

	putc (byte_register_name_char1[reg+6],assembly_file);
	putc ('l',assembly_file);
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

			if (!intel_asm){
				if (offset!=0)
					fprintf (assembly_file,"%d(%%e%c%c)",
							 offset,register_name_char1[reg+6],register_name_char2[reg+6]);
				else
					fprintf (assembly_file,"(%%e%c%c)",
							 register_name_char1[reg+6],register_name_char2[reg+6]);
			} else {
				fprintf (assembly_file,"near ptr ");
				if (offset>0)
					fprintf (assembly_file,"%d[e%c%c]",
							 offset,register_name_char1[reg+6],register_name_char2[reg+6]);
				else if (offset==0)
					fprintf (assembly_file,"[e%c%c]",
							 register_name_char1[reg+6],register_name_char2[reg+6]);
				else
					fprintf (assembly_file,"(%d)[e%c%c]",
							 offset,register_name_char1[reg+6],register_name_char2[reg+6]);
			}
			break;
		}
		case P_REGISTER:
		{
			int reg;

			reg=parameter->parameter_data.reg.r;

			fprintf (assembly_file,intel_asm ? "e%c%c" : "%%e%c%c",register_name_char1[reg+6],register_name_char2[reg+6]);
			break;
		}
		default:
			internal_error_in_function ("w_as_jump_parameter");
	}
}

static void w_as_opcode_movl (void)
{
	w_as_opcode (intel_asm ? "mov" : "movl");
}

static void w_as_opcode_move (int size_flag)
{
	w_as_opcode (intel_asm  ? (size_flag==SIZE_LONG ? "mov" : size_flag==SIZE_WORD ? "movsx" : "movzx")
							: (size_flag==SIZE_LONG ? "movl" : size_flag==SIZE_WORD ? "movswl" : "movzbl")
							);
}

static void w_as_register_register_newline (int reg1,int reg2)
{
	if (intel_asm)
		w_as_register_comma (reg2);
	w_as_register (reg1);
	if (!intel_asm)
		w_as_comma_register (reg2);
	w_as_newline();
}

static void w_as_opcode_register_newline (char *opcode,int reg1)
{
	w_as_opcode (opcode);
	w_as_register (reg1);
	w_as_newline();
}

static void w_as_opcode_register_register_newline (char *opcode,int reg1,int reg2)
{
	w_as_opcode (opcode);
	w_as_register_register_newline (reg1,reg2);
}

static void w_as_movl_register_register_newline (int reg1,int reg2)
{
	w_as_opcode_movl();
	w_as_register_register_newline (reg1,reg2);
}

static void w_as_immediate_register_newline (int i,int reg)
{
	if (!intel_asm){
		w_as_immediate (i);
		w_as_comma_register (reg);
	} else {
		w_as_register_comma (reg);
		w_as_immediate (i);
	}
	w_as_newline();
}

static void w_as_move_instruction (struct instruction *instruction,int size_flag)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_REGISTER:
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_DESCRIPTOR_NUMBER:
					w_as_opcode_movl();
					if (intel_asm)
						w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_descriptor (
						instruction->instruction_parameters[0].parameter_data.l,
						instruction->instruction_parameters[0].parameter_offset
					);
					break;
				case P_IMMEDIATE:
					w_as_opcode_movl();
					if (intel_asm)
						w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_immediate (instruction->instruction_parameters[0].parameter_data.i);
					break;
				case P_INDIRECT:
					w_as_opcode_move (size_flag);
					if (intel_asm){
						w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
						if (size_flag!=SIZE_LONG)
							fprintf (assembly_file,size_flag==SIZE_WORD ? "word ptr " : "byte ptr ");
					}
					w_as_indirect (instruction->instruction_parameters[0].parameter_offset,
								   instruction->instruction_parameters[0].parameter_data.reg.r);
					break;
				case P_INDEXED:
					w_as_opcode_move (size_flag);
					if (intel_asm){
						w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
						if (size_flag!=SIZE_LONG)
							fprintf (assembly_file,size_flag==SIZE_WORD ? "word ptr " : "byte ptr ");
					}
					w_as_indexed (instruction->instruction_parameters[0].parameter_offset,
								  instruction->instruction_parameters[0].parameter_data.ir);
					break;					
				case P_REGISTER:
					w_as_opcode_movl();
					if (intel_asm)
						w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_register (instruction->instruction_parameters[0].parameter_data.reg.r);
					break;
				case P_POST_INCREMENT:
					w_as_opcode (intel_asm ? "pop" : "popl");
					w_as_register (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_newline();
					return;
				case P_LABEL:
					w_as_opcode_movl();
					if (intel_asm){
						w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
						fprintf (assembly_file,"offset ");
					}
					if (instruction->instruction_parameters[0].parameter_data.l->label_number!=0)
						w_as_local_label (instruction->instruction_parameters[0].parameter_data.l->label_number);
					else
						w_as_label (instruction->instruction_parameters[0].parameter_data.l->label_name);
					break;
				default:
					internal_error_in_function ("w_as_move_instruction");
					return;
			}
			if (!intel_asm)
				w_as_comma_register (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_newline();
			return;
		case P_INDIRECT:
		{
			struct parameter parameter;
			
			parameter=instruction->instruction_parameters[0];

			switch (parameter.parameter_type){
				case P_INDIRECT:
					w_as_opcode_move (size_flag);
					if (intel_asm){
						w_as_scratch_register_comma();
						if (size_flag!=SIZE_LONG)
							fprintf (assembly_file,size_flag==SIZE_WORD ? "word ptr " : "byte ptr ");
					}
					w_as_indirect (parameter.parameter_offset,parameter.parameter_data.reg.r);
					if (!intel_asm)
						w_as_comma_scratch_register();
					w_as_newline();
		
					parameter.parameter_type=P_REGISTER;
					parameter.parameter_data.reg.r=REGISTER_O0;
					break;
				case P_INDEXED:
					w_as_opcode_move (size_flag);
					if (intel_asm){
						w_as_scratch_register_comma();
						if (size_flag!=SIZE_LONG)
							fprintf (assembly_file,size_flag==SIZE_WORD ? "word ptr " : "byte ptr ");
					}
					w_as_indexed (parameter.parameter_offset,parameter.parameter_data.ir);
					if (!intel_asm)
						w_as_comma_scratch_register();
					w_as_newline();
		
					parameter.parameter_type=P_REGISTER;
					parameter.parameter_data.reg.r=REGISTER_O0;
					break;
				case P_DESCRIPTOR_NUMBER:
					w_as_opcode_movl();
					if (intel_asm){
						w_as_indirect (instruction->instruction_parameters[1].parameter_offset,
									   instruction->instruction_parameters[1].parameter_data.reg.r);
						w_as_comma();
					}
					w_as_descriptor (parameter.parameter_data.l,parameter.parameter_offset);
					if (!intel_asm){
						w_as_comma();
						w_as_indirect (instruction->instruction_parameters[1].parameter_offset,
									   instruction->instruction_parameters[1].parameter_data.reg.r);
					}
					w_as_newline();
					return;
				case P_IMMEDIATE:
				case P_REGISTER:
					break;
				case P_POST_INCREMENT:
					w_as_opcode (intel_asm ? "pop" : "popl");
					w_as_indirect (instruction->instruction_parameters[1].parameter_offset,
									   instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_newline();
					return;
				default:
					internal_error_in_function ("w_as_move");
			}

			if (size_flag==SIZE_BYTE && parameter.parameter_type==P_REGISTER && parameter.parameter_data.reg.r<REGISTER_A1){
				int reg,reg1;
				
				reg=parameter.parameter_data.reg.r;
				
				w_as_opcode_register_register_newline ("xchg",reg,REGISTER_D0);

				reg1=instruction->instruction_parameters[1].parameter_data.reg.r;
				if (reg1==reg)
					reg1=REGISTER_D0;
				else if (reg1==REGISTER_D0)
					reg1=reg;

				w_as_opcode (intel_asm ? "mov" : "movb");
				if (!intel_asm)
					w_as_register_comma (REGISTER_D0);
				w_as_indirect (instruction->instruction_parameters[1].parameter_offset,reg1);
				if (intel_asm){
					if (parameter.parameter_type!=P_REGISTER)
						internal_error_in_function ("w_as_move_instruction");
					w_as_comma_byte_register (REGISTER_D0);
				}
				w_as_newline();

				w_as_opcode_register_register_newline ("xchg",reg,REGISTER_D0);

				return;
			}

			w_as_opcode (intel_asm ? "mov" : (size_flag==SIZE_LONG ? "movl" : size_flag==SIZE_WORD ? "movw" : "movb"));
			if (!intel_asm)
				w_as_parameter_comma (&parameter);
			else if (parameter.parameter_type==P_IMMEDIATE)
				fprintf (assembly_file,size_flag==SIZE_LONG ? "dword ptr " : size_flag==SIZE_WORD ? "word ptr " : "byte ptr ");
			w_as_indirect (instruction->instruction_parameters[1].parameter_offset,
						   instruction->instruction_parameters[1].parameter_data.reg.r);
			if (intel_asm){
				if (size_flag==SIZE_LONG || parameter.parameter_type==P_IMMEDIATE)
				w_as_comma_parameter (&parameter);
				else if (size_flag==SIZE_WORD)
					w_as_comma_word_parameter (&parameter);
				else {
					if (parameter.parameter_type!=P_REGISTER)
						internal_error_in_function ("w_as_move_instruction");
					w_as_comma_byte_register (parameter.parameter_data.reg.r);
				}
			}
			w_as_newline();
			return;
		}
		case P_PRE_DECREMENT:
			w_as_opcode (intel_asm ? "push" : "pushl");
			if (instruction->instruction_parameters[0].parameter_type==P_DESCRIPTOR_NUMBER)
				w_as_descriptor (instruction->instruction_parameters[0].parameter_data.l,instruction->instruction_parameters[0].parameter_offset);
			else
				w_as_parameter (&instruction->instruction_parameters[0]);
			w_as_newline();
			return;
		case P_INDEXED:
		{
			struct parameter parameter;
			
			parameter=instruction->instruction_parameters[0];

			switch (parameter.parameter_type){
				case P_INDIRECT:
					w_as_opcode_move (size_flag);
					if (intel_asm){
						w_as_scratch_register_comma();
						if (size_flag!=SIZE_LONG)
							fprintf (assembly_file,size_flag==SIZE_WORD ? "word ptr " : "byte ptr ");
					}
					w_as_indirect (parameter.parameter_offset,parameter.parameter_data.reg.r);
					if (!intel_asm)
						w_as_comma_scratch_register();
					w_as_newline();
		
					parameter.parameter_type=P_REGISTER;
					parameter.parameter_data.reg.r=REGISTER_O0;
					break;
				case P_DESCRIPTOR_NUMBER:
					w_as_opcode_movl();
					if (intel_asm){
						w_as_indexed (instruction->instruction_parameters[1].parameter_offset,
									  instruction->instruction_parameters[1].parameter_data.ir);
						w_as_comma();
					}
					w_as_descriptor (parameter.parameter_data.l,parameter.parameter_offset);
					if (!intel_asm){
						w_as_comma();
						w_as_indexed (instruction->instruction_parameters[1].parameter_offset,
									  instruction->instruction_parameters[1].parameter_data.ir);
					}
					w_as_newline();
					return;
				case P_IMMEDIATE:
				case P_REGISTER:
					break;
				case P_POST_INCREMENT:
					w_as_opcode (intel_asm ? "pop" : "popl");
					w_as_indexed (instruction->instruction_parameters[1].parameter_offset,
									  instruction->instruction_parameters[1].parameter_data.ir);
					w_as_newline();
					return;
				default:
					internal_error_in_function ("w_as_move");
			}

			if (size_flag==SIZE_BYTE && parameter.parameter_type==P_REGISTER && parameter.parameter_data.reg.r<REGISTER_A1){
				int reg,reg1,reg2;
				struct index_registers index_registers;
				
				reg=parameter.parameter_data.reg.r;
				
				w_as_opcode_register_register_newline ("xchg",reg,REGISTER_D0);

				reg1=instruction->instruction_parameters[1].parameter_data.ir->a_reg.r;
				reg2=instruction->instruction_parameters[1].parameter_data.ir->d_reg.r;
				
				if (reg1==reg)
					reg1=REGISTER_D0;
				else if (reg1==REGISTER_D0)
					reg1=reg;

				if (reg2==reg)
					reg2=REGISTER_D0;
				else if (reg2==REGISTER_D0)
					reg2=reg;

				index_registers.a_reg.r=reg1;
				index_registers.d_reg.r=reg2;
				
				w_as_opcode (intel_asm ? "mov" : "movb");
				if (!intel_asm)
					w_as_register_comma (REGISTER_D0);
				w_as_indexed (instruction->instruction_parameters[1].parameter_offset,&index_registers);
				if (intel_asm){
					if (parameter.parameter_type!=P_REGISTER)
						internal_error_in_function ("w_as_move_instruction");
					w_as_comma_byte_register (REGISTER_D0);
				}
				w_as_newline();

				w_as_opcode_register_register_newline ("xchg",reg,REGISTER_D0);

				return;
			}

			w_as_opcode (intel_asm ? "mov" : (size_flag==SIZE_LONG ? "movl" : size_flag==SIZE_WORD ? "movw" : "movb"));
			if (!intel_asm)
				w_as_parameter_comma (&parameter);
			else if (parameter.parameter_type==P_IMMEDIATE)
				fprintf (assembly_file,size_flag==SIZE_LONG ? "dword ptr " : size_flag==SIZE_WORD ? "word ptr " : "byte ptr ");
			w_as_indexed (instruction->instruction_parameters[1].parameter_offset,
						  instruction->instruction_parameters[1].parameter_data.ir);
			if (intel_asm){
				if (size_flag==SIZE_LONG || parameter.parameter_type==P_IMMEDIATE)
				w_as_comma_parameter (&parameter);
				else if (size_flag==SIZE_WORD)
					w_as_comma_word_parameter (&parameter);
				else {
					if (parameter.parameter_type!=P_REGISTER)
						internal_error_in_function ("w_as_move_instruction");
					w_as_comma_byte_register (parameter.parameter_data.reg.r);
				}
			}
			w_as_newline();
			return;
		}
		case P_LABEL:
			if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
				w_as_opcode_movl();
				if (!intel_asm){
					w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
					fprintf (assembly_file,"offset ");
				}
				if (instruction->instruction_parameters[1].parameter_data.l->label_number!=0)
					w_as_local_label (instruction->instruction_parameters[1].parameter_data.l->label_number);
				else
					w_as_label (instruction->instruction_parameters[1].parameter_data.l->label_name);
				if (intel_asm)
					w_as_comma_register (instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_newline();
				return;
			}
		default:
			internal_error_in_function ("w_as_move_instruction");
	}
}

static void w_as_lea_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		w_as_opcode (intel_asm ? "lea" : "leal");

		if (intel_asm)
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_parameter (&instruction->instruction_parameters[0]);
		if (instruction->instruction_parameters[0].parameter_type==P_LABEL
			&& instruction->instruction_parameters[0].parameter_offset!=0)
		{
			int offset;

			offset=instruction->instruction_parameters[0].parameter_offset;
			fprintf (assembly_file,offset>=0 ? "+%d" : "%d",offset);
		}
		if (!intel_asm)
			w_as_comma_register (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_newline();
		return;
	}
	internal_error_in_function ("w_as_lea_instruction");
}

static void w_as_dyadic_instruction (struct instruction *instruction,char *opcode)
{
	w_as_opcode (opcode);
	if (intel_asm){
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_parameter (&instruction->instruction_parameters[0]);
	} else {
		w_as_parameter (&instruction->instruction_parameters[0]);
		w_as_comma_register (instruction->instruction_parameters[1].parameter_data.reg.r);
	}
	w_as_newline();
}

static void w_as_shift_instruction (struct instruction *instruction,char *opcode)
{
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		w_as_opcode (opcode);
		if (intel_asm)
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_immediate (instruction->instruction_parameters[0].parameter_data.i & 31);
		if (!intel_asm)
			w_as_comma_register (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_newline();
	} else if (
		instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
		instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A0
	){
		w_as_opcode (opcode);
		if (intel_asm)
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		fprintf (assembly_file,intel_asm ? "cl" : "%%cl");
		if (!intel_asm)
			w_as_comma_register (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_newline();		
	} else {
		int r;
		
		w_as_movl_register_register_newline (REGISTER_A0,REGISTER_O0);

		w_as_opcode_movl();
		if (intel_asm)
			w_as_register_comma (REGISTER_A0);
		w_as_parameter (&instruction->instruction_parameters[0]);
		if (!intel_asm)
			w_as_comma_register (REGISTER_A0);
		w_as_newline();

		w_as_opcode (opcode);
		if (!intel_asm)
			fprintf (assembly_file,"%%cl,");
		r=instruction->instruction_parameters[1].parameter_data.reg.r;
		if (r==REGISTER_A0)
			w_as_scratch_register();
		else
			w_as_register (r);
		if (intel_asm)
			fprintf (assembly_file,",cl");
		w_as_newline();

		w_as_movl_register_register_newline (REGISTER_O0,REGISTER_A0);
	}
}

static void w_as_shift_s_instruction (struct instruction *instruction,char *opcode)
{
	if (instruction->instruction_parameters[0].parameter_type!=P_REGISTER){
		if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
			w_as_opcode (opcode);
			if (intel_asm)
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_immediate (instruction->instruction_parameters[0].parameter_data.i & 31);
			if (!intel_asm)
				w_as_comma_register (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_newline();
		} else
			internal_error_in_function ("w_as_shift_s_instruction");
	} else {
		int r0;
		
		r0=instruction->instruction_parameters[0].parameter_data.reg.r;
		if (r0==REGISTER_A0){
			w_as_opcode (opcode);
			if (intel_asm)
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			fprintf (assembly_file,intel_asm ? "cl" : "%%cl");
			if (!intel_asm)
				w_as_comma_register (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_newline();		
		} else {
			int scratch_register;

			scratch_register=instruction->instruction_parameters[2].parameter_data.reg.r;
			if (scratch_register==REGISTER_A0){
				w_as_movl_register_register_newline (r0,REGISTER_A0);

				w_as_opcode (opcode);
				if (!intel_asm)
					fprintf (assembly_file,"%%cl,");
				w_as_register (instruction->instruction_parameters[1].parameter_data.reg.r);
				if (intel_asm)
					fprintf (assembly_file,",cl");
				w_as_newline();
			} else {
				int r;
				
				w_as_movl_register_register_newline (REGISTER_A0,scratch_register);
				w_as_movl_register_register_newline (r0,REGISTER_A0);

				w_as_opcode (opcode);
				if (!intel_asm)
					fprintf (assembly_file,"%%cl,");
				r=instruction->instruction_parameters[1].parameter_data.reg.r;
				if (r==REGISTER_A0)
					w_as_register (scratch_register);
				else
					w_as_register (r);
				if (intel_asm)
					fprintf (assembly_file,",cl");
				w_as_newline();

				w_as_movl_register_register_newline (scratch_register,REGISTER_A0);
			}
		}
	}
}

static void w_as_cmp_instruction (struct instruction *instruction)
{
	struct parameter parameter_0,parameter_1;

	parameter_0=instruction->instruction_parameters[0];
	parameter_1=instruction->instruction_parameters[1];

	switch (parameter_0.parameter_type){
		case P_DESCRIPTOR_NUMBER:
			w_as_opcode (intel_asm ? "cmp" : "cmpl");
			if (intel_asm)
				w_as_parameter_comma (&parameter_1);
			w_as_descriptor (parameter_0.parameter_data.l,parameter_0.parameter_offset);
			if (!intel_asm)
				w_as_comma_parameter (&parameter_1);
			w_as_newline();
			return;
		case P_IMMEDIATE:
			if (parameter_0.parameter_data.i==0 && parameter_1.parameter_type==P_REGISTER){
				w_as_opcode (intel_asm ? "test" : "testl");
				w_as_register (parameter_1.parameter_data.reg.r);
				w_as_comma_register (parameter_1.parameter_data.reg.r);
				w_as_newline();
				return;
			}
	}

	w_as_opcode (intel_asm ? "cmp" : "cmpl");
	if (intel_asm){
		if (parameter_0.parameter_type==P_IMMEDIATE)
			fprintf (assembly_file,"dword ptr ");
		w_as_parameter_comma (&parameter_1);
	}
	w_as_parameter (&parameter_0);
	if (!intel_asm)
		w_as_comma_parameter (&parameter_1);
	w_as_newline();
}

#if 0
static void w_as_cmpw_instruction (struct instruction *instruction)
{
	struct parameter parameter_0,parameter_1;

	parameter_0=instruction->instruction_parameters[0];
	parameter_1=instruction->instruction_parameters[1];

	if (parameter_1.parameter_type==P_INDIRECT){
		w_as_opcode (intel_asm ? "movsx" : "movswl");

		if (intel_asm)
			w_as_scratch_register_comma();
		w_as_parameter (&parameter_1);
		if (!intel_asm)
			w_as_comma_scratch_register();
		w_as_newline();

		parameter_1.parameter_type=P_REGISTER;
		parameter_1.parameter_data.reg.r=REGISTER_O0;
	}

	switch (parameter_0.parameter_type){
		case P_DESCRIPTOR_NUMBER:
			w_as_opcode (intel_asm ? "cmp" : "cmpl");
			if (intel_asm)
				w_as_parameter_comma (&parameter_1);
			w_as_descriptor (parameter_0.parameter_data.l,parameter_0.parameter_offset);
			if (!intel_asm)
				w_as_comma_parameter (&parameter_1);
			w_as_newline();
			return;
		case P_INDIRECT:
			w_as_opcode (intel_asm ? "movsx" : "movswl");
			if (intel_asm)
				w_as_scratch_register_comma();
			w_as_parameter (&parameter_0);
			if (!intel_asm)
				w_as_comma_scratch_register();
			w_as_newline();

			parameter_0.parameter_type=P_REGISTER;
			parameter_0.parameter_data.reg.r=REGISTER_O0;
	}

	w_as_opcode (intel_asm ? "cmp" : "cmpl");
	if (intel_asm){
		if (parameter_0.parameter_type==P_IMMEDIATE)
			fprintf (assembly_file,"dword ptr ");
		w_as_parameter_comma (&parameter_1);
	}
	w_as_parameter (&parameter_0);
	if (!intel_asm)
		w_as_comma_parameter (&parameter_1);
	w_as_newline();
}
#endif

static void w_as_tst_instruction (struct instruction *instruction)
{
	struct parameter parameter_0,parameter_1;

	parameter_0=instruction->instruction_parameters[0];
	parameter_1=instruction->instruction_parameters[1];

	w_as_opcode (intel_asm ? "test" : "testl");
	if (intel_asm){
		if (parameter_0.parameter_type==P_IMMEDIATE)
			fprintf (assembly_file,"dword ptr ");
		w_as_parameter_comma (&parameter_1);
	}
	w_as_parameter (&parameter_0);
	if (!intel_asm)
		w_as_comma_parameter (&parameter_1);
	w_as_newline();
}

static void w_as_monadic_instruction (struct instruction *instruction,char *opcode)
{
	w_as_opcode (opcode);
	w_as_register (instruction->instruction_parameters[0].parameter_data.reg.r);
	w_as_newline();
}

static void w_as_clzb_instruction (struct instruction *instruction)
{
	struct parameter *parameter_0_p,*parameter_1_p;

	parameter_0_p=&instruction->instruction_parameters[0];
	parameter_1_p=&instruction->instruction_parameters[1];

#if 0
	w_as_opcode (intel_asm ? "lzcnt" : "lzcntl");
	if (intel_asm)
		w_as_parameter_comma (parameter_1_p);
	w_as_parameter (parameter_0_p);
	if (!intel_asm)
		w_as_comma_parameter (parameter_1_p);
	w_as_newline();
#else
	w_as_opcode_movl();
	w_as_immediate_register_newline (63,parameter_1_p->parameter_data.reg.r);

	w_as_opcode (intel_asm ? "bsr" : "bsrl");
	if (intel_asm)
		w_as_parameter_comma (parameter_1_p);
	w_as_parameter (parameter_0_p);
	if (!intel_asm)
		w_as_comma_parameter (parameter_1_p);
	w_as_newline();

	w_as_opcode (intel_asm ? "xor" : "xorl");
	if (intel_asm){
		w_as_register_comma (parameter_1_p->parameter_data.reg.r);
		w_as_immediate (31);
	} else {
		w_as_immediate (31);
		w_as_comma_register (parameter_1_p->parameter_data.reg.r);
	}
	w_as_newline();
#endif
}

static void w_as_btst_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		w_as_opcode (intel_asm ? "test" : "testb");
		if (intel_asm)
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_immediate (instruction->instruction_parameters[0].parameter_data.i);
		if (!intel_asm)
			w_as_comma_register (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_newline();
	} else {
		w_as_opcode (intel_asm ? "test" : "testb");
		if (intel_asm){
			fprintf (assembly_file,"byte ptr ");
			w_as_indirect (instruction->instruction_parameters[1].parameter_offset,instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_comma();
		}
		w_as_immediate (instruction->instruction_parameters[0].parameter_data.i);
		if (!intel_asm){
			w_as_comma();
			w_as_indirect (instruction->instruction_parameters[1].parameter_offset,instruction->instruction_parameters[1].parameter_data.reg.r);
		}
		w_as_newline();
	}
}

void w_as_jmp_instruction (struct instruction *instruction)
{
	w_as_opcode ("jmp");

	w_as_jump_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();
}

void w_as_jmpp_instruction (struct instruction *instruction)
{
	struct parameter *parameter_p;

	parameter_p=&instruction->instruction_parameters[0];

	switch (parameter_p->parameter_type){
		case P_LABEL:
		{
			int offset;

			offset=parameter_p->parameter_offset;

			if (offset==0){
				w_as_opcode ("call");
				w_as_label ("profile_t");
				w_as_newline();			
			}
			
			w_as_opcode ("jmp");
			if (parameter_p->parameter_data.l->label_number!=0)
				w_as_local_label (parameter_p->parameter_data.l->label_number);
			else
				w_as_label (parameter_p->parameter_data.l->label_name);
			
			if (offset!=0)
				fprintf (assembly_file,"+%d",offset);

			break;
		}
		case P_INDIRECT:
		case P_REGISTER:
			w_as_opcode ("call");
			w_as_label ("profile_t");
			w_as_newline();			
		
			w_as_opcode ("jmp");
			w_as_jump_parameter (&instruction->instruction_parameters[0]);
			break;		
		default:
			internal_error_in_function ("w_as_jmpp_instruction");
	}

	w_as_newline();
}

static void w_as_branch_instruction (struct instruction *instruction,char *opcode)
{
	w_as_opcode (opcode);
	w_as_branch_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();
}

static void as_test_floating_point_condition_code (int n)
{
	fprintf (assembly_file,intel_asm ? "\tfnstsw\tax\n" : "\tfnstsw\t%%ax\n");

	switch (n){
		case 0:
			fprintf (assembly_file,intel_asm ? "\tand\tah,68\n\txor\tah,64\n" : "\tandb\t$68,%%ah\n\txorb\t$64,%%ah\n");
			break;
		case 1:
			fprintf (assembly_file,intel_asm ? "\tand\tah,69\n\tcmp\tah,1\n" : "\tandb\t$69,%%ah\n\tcmpb\t$1,%%ah\n");
			break;
		case 2:
			fprintf (assembly_file,intel_asm ? "\tand\tah,69\n" : "\tandb\t$69,%%ah\n");
			break;
		case 3:
			fprintf (assembly_file,intel_asm ? "\tand\tah,64\n" : "\tandb\t$64,%%ah\n");
			break;
		case 4:
			fprintf (assembly_file,intel_asm ? "\tand\tah,69\n\tdec\tah\n\tcmp\tah,64\n" : "\tandb\t$69,%%ah\n\tdecb\t%%ah\n\tcmpb\t$64,%%ah\n");
			break;
		case 5:
			fprintf (assembly_file,intel_asm ? "\tand\tah,5\n" : "\tand\t$5,%%ah\n");
			break;
	}
}

static void w_as_jsr_instruction (struct instruction *instruction)
{
	w_as_opcode ("call");
	w_as_jump_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();
}

static void w_as_set_condition_instruction (struct instruction *instruction,char *opcode)
{
	int r;
	char *reg_s;
	
	r=instruction->instruction_parameters[0].parameter_data.reg.r;
		
	switch (r){
		case REGISTER_D0:
			reg_s=intel_asm ? "al" : "%%al";
			break;
		case REGISTER_D1:
			reg_s=intel_asm ? "bl" : "%%bl";
			break;
		case REGISTER_A0:
			reg_s=intel_asm ? "cl" : "%%cl";
			break;				
		case REGISTER_A1:
			reg_s=intel_asm ? "dl" : "%%dl";
			break;
		default:
			reg_s=NULL;
	}
	
	if (reg_s!=NULL){
		w_as_opcode (opcode);
		fputs (reg_s,assembly_file);
		w_as_newline();

		w_as_opcode (intel_asm ? "movzx" : "movzbl");
		if (intel_asm)
			w_as_register_comma (r);
		fputs (reg_s,assembly_file);
		if (!intel_asm)
			w_as_comma_register (r);
		w_as_newline();
	} else {
		w_as_movl_register_register_newline (REGISTER_D0,r);
		
		w_as_opcode (opcode);
		fprintf (assembly_file,intel_asm ? "al" : "%%al");
		w_as_newline();

		w_as_opcode (intel_asm ? "movzx" : "movzbl");
		if (intel_asm)
			w_as_register_comma (REGISTER_D0);
		fprintf (assembly_file,intel_asm ? "al" : "%%al");
		if (!intel_asm)
			w_as_comma_register (REGISTER_D0);
		w_as_newline();

		w_as_opcode_register_register_newline ("xchg",r,REGISTER_D0);
	}
}

static void w_as_set_float_condition_instruction (struct instruction *instruction,int n)
{
	int r;

	r=instruction->instruction_parameters[0].parameter_data.reg.r;

	if (r!=REGISTER_D0)
		w_as_movl_register_register_newline (REGISTER_D0,r);

	as_test_floating_point_condition_code (n);

	w_as_opcode (n!=4 ? "sete" : "setb");
	fprintf (assembly_file,intel_asm ? "al" : "%%al");
	w_as_newline();

	w_as_opcode (intel_asm ? "movzx" : "movzbl");
	if (intel_asm)
		w_as_register_comma (REGISTER_D0);
	fprintf (assembly_file,intel_asm ? "al" : "%%al");
	if (!intel_asm)
		w_as_comma_register (REGISTER_D0);
	w_as_newline();

	if (r!=REGISTER_D0)
		w_as_opcode_register_register_newline ("xchg",r,REGISTER_D0);
}

static void w_as_convert_float_condition_instruction (struct instruction *instruction,int n)
{
	int r;

	r=instruction->instruction_parameters[0].parameter_data.reg.r;

	if (r!=REGISTER_D0)
		w_as_movl_register_register_newline (REGISTER_D0,r);

	as_test_floating_point_condition_code (n);

	if (r!=REGISTER_D0)
		w_as_movl_register_register_newline (r,REGISTER_D0);
}

static void w_as_div_rem_i_instruction (struct instruction *instruction,int compute_remainder)
{
	int s_reg1,s_reg2,s_reg3,i,sd_reg,i_reg,tmp_reg,abs_i;
#ifdef THREAD32
	int tmp2_reg;
#endif
	struct ms ms;

	if (instruction->instruction_parameters[0].parameter_type!=P_IMMEDIATE)
		internal_error_in_function ("w_as_div_rem_i_instruction");
		
	i=instruction->instruction_parameters[0].parameter_data.i;

	if (! ((i>1 || (i<-1 && i!=0x80000000))))
		internal_error_in_function ("w_as_div_rem_i_instruction");
	
	abs_i=abs (i);

	if (compute_remainder)
		i=abs_i;

	ms=magic (abs_i);
	
	sd_reg=instruction->instruction_parameters[1].parameter_data.reg.r;
	tmp_reg=instruction->instruction_parameters[2].parameter_data.reg.r;

#ifndef THREAD32
	if (sd_reg==tmp_reg)
		internal_error_in_function ("w_as_div_rem_i_instruction");		

	if (sd_reg==REGISTER_A1){
		if (tmp_reg!=REGISTER_D0)
			w_as_movl_register_register_newline (REGISTER_D0,tmp_reg);

		w_as_movl_register_register_newline (REGISTER_A1,REGISTER_O0);
		
		s_reg1=sd_reg;
		s_reg2=REGISTER_O0;
		i_reg=REGISTER_D0;
	} else if (sd_reg==REGISTER_D0){
		if (tmp_reg!=REGISTER_A1)
			w_as_movl_register_register_newline (REGISTER_A1,tmp_reg);			
		
		w_as_movl_register_register_newline (REGISTER_D0,REGISTER_O0);

		s_reg1=REGISTER_A1;
		s_reg2=REGISTER_O0;
		i_reg=REGISTER_A1;
	} else {
		if (tmp_reg==REGISTER_D0)
			w_as_movl_register_register_newline (REGISTER_A1,REGISTER_O0);			
		else if (tmp_reg==REGISTER_A1)
			w_as_movl_register_register_newline (REGISTER_D0,REGISTER_O0);						
		else {
			w_as_movl_register_register_newline (REGISTER_D0,REGISTER_O0);
			w_as_movl_register_register_newline (REGISTER_A1,tmp_reg);
		}
		
		s_reg1=sd_reg;
		s_reg2=sd_reg;
		i_reg=REGISTER_D0;
	}
#else
	tmp2_reg=instruction->instruction_parameters[3].parameter_data.reg.r;

	if (sd_reg==tmp_reg || sd_reg==tmp2_reg)
		internal_error_in_function ("w_as_div_rem_i_instruction");		

	if (sd_reg==REGISTER_A1){
		if (tmp2_reg==REGISTER_D0){
			s_reg2=tmp_reg;
		} else {
			if (tmp_reg!=REGISTER_D0)
				w_as_movl_register_register_newline (REGISTER_D0,tmp_reg);
			s_reg2=tmp2_reg;
		}
		
		w_as_movl_register_register_newline (REGISTER_A1,s_reg2);
		
		s_reg1=sd_reg;
		i_reg=REGISTER_D0;
	} else if (sd_reg==REGISTER_D0){
		if (tmp2_reg==REGISTER_A1){
			s_reg2=tmp_reg;
		} else {
			if (tmp_reg!=REGISTER_A1)
				w_as_movl_register_register_newline (REGISTER_A1,tmp_reg);			
			s_reg2=tmp2_reg;
		}

		w_as_movl_register_register_newline (REGISTER_D0,s_reg2);

		s_reg1=REGISTER_A1;
		i_reg=REGISTER_A1;
	} else {
		if (tmp_reg==REGISTER_D0){
			if (tmp2_reg!=REGISTER_A1)
				w_as_movl_register_register_newline (REGISTER_A1,tmp2_reg);			
		} else if (tmp_reg==REGISTER_A1){
			if (tmp2_reg!=REGISTER_D0)
				w_as_movl_register_register_newline (REGISTER_D0,tmp2_reg);						
		} else {
			if (tmp2_reg==REGISTER_D0){
				w_as_movl_register_register_newline (REGISTER_A1,tmp_reg);
			} else if (tmp2_reg==REGISTER_A1){
				w_as_movl_register_register_newline (REGISTER_D0,tmp_reg);
			} else {
				w_as_movl_register_register_newline (REGISTER_D0,tmp2_reg);
				w_as_movl_register_register_newline (REGISTER_A1,tmp_reg);
			}
		}
		
		s_reg1=sd_reg;
		s_reg2=sd_reg;
		i_reg=REGISTER_D0;
	}
#endif

	w_as_opcode_movl();
	w_as_immediate_register_newline (ms.m,i_reg);

	w_as_opcode (intel_asm ? "imul" : "imull");
	w_as_register (s_reg1);
	w_as_newline();
	
	if (compute_remainder)
		w_as_movl_register_register_newline (s_reg2,REGISTER_D0);

	if (ms.m<0)
		w_as_opcode_register_register_newline ("add",s_reg2,REGISTER_A1);

	if (compute_remainder){
		if (s_reg2==sd_reg && s_reg2!=REGISTER_D0 && s_reg2!=REGISTER_A1){
			s_reg3=s_reg2;
			s_reg2=REGISTER_D0;
		} else
			s_reg3=REGISTER_D0;
	}

	w_as_opcode (i>=0 ? "shr" : "sar");
	w_as_immediate_register_newline (31,s_reg2);

	if (ms.s>0){
		w_as_opcode ("sar");
		w_as_immediate_register_newline (ms.s,REGISTER_A1);
	}

	if (!compute_remainder){
		if (sd_reg==REGISTER_A1){
			if (i>=0)
				w_as_opcode_register_register_newline ("add",s_reg2,REGISTER_A1);
			else {
				w_as_opcode_register_register_newline ("sub",REGISTER_A1,s_reg2);
				w_as_movl_register_register_newline (s_reg2,sd_reg);
			}
		} else if (sd_reg==REGISTER_D0){
			struct index_registers index_registers;

			if (i>=0){
				index_registers.a_reg.r=REGISTER_A1;
				index_registers.d_reg.r=s_reg2;
						
				w_as_opcode (intel_asm ? "lea" : "leal");
				if (intel_asm)
					w_as_register_comma (sd_reg);
				w_as_indexed (0,&index_registers);
				if (!intel_asm)
					w_as_comma_register (sd_reg);
				w_as_newline();
			} else {
				w_as_movl_register_register_newline (s_reg2,sd_reg);
				w_as_opcode_register_register_newline ("sub",REGISTER_A1,sd_reg);			
			}
		} else
			w_as_opcode_register_register_newline (i>=0 ? "add" : "sub",REGISTER_A1,s_reg2); /* s_reg2==sd_reg */
	} else {
		int i2;
		
		w_as_opcode_register_register_newline ("add",s_reg2,REGISTER_A1);

		i2=i & (i-1);
		if ((i2 & (i2-1))==0){
			unsigned int n;
			int n_shifts;

			n=i;
			
			n_shifts=0;
			while (n>0){
				while ((n & 1)==0){
					n>>=1;
					++n_shifts;
				}
				
				if (n_shifts>0){
					w_as_opcode ("shl");
					w_as_immediate_register_newline (n_shifts,REGISTER_A1);
				}
				
				w_as_opcode_register_register_newline ("sub",REGISTER_A1,s_reg3);

				n>>=1;
				n_shifts=1;
			}
		} else {
			w_as_opcode (intel_asm ? "imul" : "imull");
			w_as_immediate_register_newline (i,REGISTER_A1);

			w_as_opcode_register_register_newline ("sub",REGISTER_A1,s_reg3);
		}
		
		if (sd_reg!=s_reg3)
			w_as_movl_register_register_newline (s_reg3,sd_reg);
	}

#ifndef THREAD32
	if (sd_reg==REGISTER_A1){
		if (tmp_reg!=REGISTER_D0)
			w_as_movl_register_register_newline (tmp_reg,REGISTER_D0);
	} else if (sd_reg==REGISTER_D0){
		if (tmp_reg!=REGISTER_A1)
			w_as_movl_register_register_newline (tmp_reg,REGISTER_A1);
	} else {
		if (tmp_reg==REGISTER_D0)
			w_as_movl_register_register_newline (REGISTER_O0,REGISTER_A1);
		else if (tmp_reg==REGISTER_A1)
			w_as_movl_register_register_newline (REGISTER_O0,REGISTER_D0);						
		else {
			w_as_movl_register_register_newline (REGISTER_O0,REGISTER_D0);			
			w_as_movl_register_register_newline (tmp_reg,REGISTER_A1);			
		}
	}
#else
	if (sd_reg==REGISTER_A1){
		if (tmp2_reg!=REGISTER_D0 && tmp_reg!=REGISTER_D0)
			w_as_movl_register_register_newline (tmp_reg,REGISTER_D0);
	} else if (sd_reg==REGISTER_D0){
		if (tmp2_reg!=REGISTER_A1 && tmp_reg!=REGISTER_A1)
			w_as_movl_register_register_newline (tmp_reg,REGISTER_A1);
	} else {
		if (tmp_reg==REGISTER_D0){
			if (tmp2_reg!=REGISTER_A1)
				w_as_movl_register_register_newline (tmp2_reg,REGISTER_A1);
		} else if (tmp_reg==REGISTER_A1){
			if (tmp2_reg!=REGISTER_D0)
				w_as_movl_register_register_newline (tmp2_reg,REGISTER_D0);						
		} else {
			if (tmp2_reg==REGISTER_D0){
				w_as_movl_register_register_newline (tmp_reg,REGISTER_A1);
			} else if (tmp2_reg==REGISTER_A1){
				w_as_movl_register_register_newline (tmp_reg,REGISTER_D0);
			} else {
				w_as_movl_register_register_newline (tmp2_reg,REGISTER_D0);			
				w_as_movl_register_register_newline (tmp_reg,REGISTER_A1);
			}
		}
	}
#endif
}

static void w_as_sar_31_r (int reg_1)
{
	w_as_opcode ("sar");
	w_as_immediate_register_newline (31,reg_1);
}

#ifndef THREAD32
static void w_as_div_instruction (struct instruction *instruction,int unsigned_div)
{
	int d_reg;

	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE && unsigned_div==0){
		int i,log2i;
		
		i=instruction->instruction_parameters[0].parameter_data.i;

		if ((i & (i-1))==0 && i>0){
			if (i==1)
				return;
			
			log2i=0;
			while (i>1){
				i=i>>1;
				++log2i;
			}
			
			w_as_movl_register_register_newline (d_reg,REGISTER_O0);

			if (log2i==1){
				w_as_sar_31_r (REGISTER_O0);

				w_as_opcode_register_register_newline ("sub",REGISTER_O0,d_reg);
			} else {
				w_as_sar_31_r (d_reg);

				w_as_opcode ("and");
				w_as_immediate_register_newline ((1<<log2i)-1,d_reg);

				w_as_opcode_register_register_newline ("add",REGISTER_O0,d_reg);
			}
			
			w_as_opcode ("sar");
			w_as_immediate_register_newline (log2i,d_reg);

			return;
		}
		
		internal_error_in_function ("w_as_div_instruction");
		return;
	}

	switch (d_reg){
		case REGISTER_D0:
			w_as_movl_register_register_newline (REGISTER_A1,REGISTER_O0);

			if (unsigned_div){
				w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);				
				w_as_opcode (intel_asm ? "div" : "divl");
			} else {
				w_as_instruction_without_parameters ("cdq");
				w_as_opcode (intel_asm ? "idiv" : "idivl");			
			}
			
			if (instruction->instruction_parameters[0].parameter_type==P_REGISTER
				&& instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A1)
			{
				w_as_scratch_register();
			} else {
				if (intel_asm)
					fprintf (assembly_file,"dword ptr ");
				if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT
				&& instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A1)
				{
					w_as_indirect (instruction->instruction_parameters[0].parameter_offset,REGISTER_O0);
				} else
					w_as_parameter (&instruction->instruction_parameters[0]);
			}
			w_as_newline();
		
			w_as_movl_register_register_newline (REGISTER_O0,REGISTER_A1);
			break;
		case REGISTER_A1:
			w_as_movl_register_register_newline (REGISTER_D0,REGISTER_O0);
	
			w_as_movl_register_register_newline (REGISTER_A1,REGISTER_D0);
	
			if (unsigned_div){
				w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);				
				w_as_opcode (intel_asm ? "div" : "divl");
			} else {
				w_as_instruction_without_parameters ("cdq");
				w_as_opcode (intel_asm ? "idiv" : "idivl");			
			}
			if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
				int r;
				
				r=instruction->instruction_parameters[0].parameter_data.reg.r;
				if (r==REGISTER_D0)
					r=REGISTER_O0;
				else if (r==REGISTER_A1)
					r=REGISTER_D0;
				
				w_as_register (r);
			} else {
				if (intel_asm)
					fprintf (assembly_file,"dword ptr ");
				if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
				int r;
				
				r=instruction->instruction_parameters[0].parameter_data.reg.r;
				if (r==REGISTER_D0)
					r=REGISTER_O0;
				else if (r==REGISTER_A1)
					r=REGISTER_D0;

				w_as_indirect (instruction->instruction_parameters[0].parameter_offset,r);					
			} else
				w_as_parameter (&instruction->instruction_parameters[0]);
			}
			w_as_newline();
	
			w_as_movl_register_register_newline (REGISTER_D0,REGISTER_A1);
		
			w_as_movl_register_register_newline (REGISTER_O0,REGISTER_D0);
			break;
		default:
			w_as_movl_register_register_newline (REGISTER_A1,REGISTER_O0);
	
			w_as_opcode_register_register_newline ("xchg",REGISTER_D0,d_reg);
	
			if (unsigned_div){
				w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);				
				w_as_opcode (intel_asm ? "div" : "divl");
			} else {
				w_as_instruction_without_parameters ("cdq");
				w_as_opcode (intel_asm ? "idiv" : "idivl");			
			}
			if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
				int r;
				
				r=instruction->instruction_parameters[0].parameter_data.reg.r;
				if (r==REGISTER_D0)
					r=d_reg;
				else if (r==REGISTER_A1)
					r=REGISTER_O0;
				else if (r==d_reg)
					r=REGISTER_D0;
				
				w_as_register (r);			
			} else {
				if (intel_asm)
					fprintf (assembly_file,"dword ptr ");
				if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
				int r;
				
				r=instruction->instruction_parameters[0].parameter_data.reg.r;
				if (r==REGISTER_D0)
					r=d_reg;
				else if (r==REGISTER_A1)
					r=REGISTER_O0;
				else if (r==d_reg)
					r=REGISTER_D0;
				
				w_as_indirect (instruction->instruction_parameters[0].parameter_offset,r);
			} else
				w_as_parameter (&instruction->instruction_parameters[0]);
			}
			w_as_newline();
	
			w_as_opcode_register_register_newline ("xchg",REGISTER_D0,d_reg);
		
			w_as_movl_register_register_newline (REGISTER_O0,REGISTER_A1);
	}
}
#else
static void w_as_div_instruction (struct instruction *instruction,int unsigned_div)
{
	int d_reg,tmp_reg;

	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;
	tmp_reg=instruction->instruction_parameters[2].parameter_data.reg.r;

	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		int i,log2i;
		
		i=instruction->instruction_parameters[0].parameter_data.i;

		if (unsigned_div==0 && (i & (i-1))==0 && i>0){
			if (i==1)
				return;
			
			log2i=0;
			while (i>1){
				i=i>>1;
				++log2i;
			}
			
			w_as_movl_register_register_newline (d_reg,tmp_reg);

			if (log2i==1){
				w_as_sar_31_r (tmp_reg);

				w_as_opcode_register_register_newline ("sub",tmp_reg,d_reg);
			} else {
				w_as_sar_31_r (d_reg);

				w_as_opcode ("and");
				w_as_immediate_register_newline ((1<<log2i)-1,d_reg);

				w_as_opcode_register_register_newline ("add",tmp_reg,d_reg);
			}
			
			w_as_opcode ("sar");
			w_as_immediate_register_newline (log2i,d_reg);

			return;
		}
		
		internal_error_in_function ("w_as_div_instruction");
		return;
	}

	switch (d_reg){
		case REGISTER_D0:
			if (tmp_reg==REGISTER_A1){
				if (unsigned_div){
					w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);				
					w_as_opcode (intel_asm ? "div" : "divl");
				} else {
					w_as_instruction_without_parameters ("cdq");
					w_as_opcode (intel_asm ? "idiv" : "idivl");			
				}
				w_as_parameter (&instruction->instruction_parameters[0]);
				w_as_newline();
			} else {
				w_as_movl_register_register_newline (REGISTER_A1,REGISTER_O0);

				if (unsigned_div){
					w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);				
					w_as_opcode (intel_asm ? "div" : "divl");
				} else {
					w_as_instruction_without_parameters ("cdq");
					w_as_opcode (intel_asm ? "idiv" : "idivl");			
				}
				
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER
					&& instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A1)
				{
					w_as_scratch_register();
				} else {
					if (intel_asm)
						fprintf (assembly_file,"dword ptr ");
					if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT
					&& instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A1)
					{
						w_as_indirect (instruction->instruction_parameters[0].parameter_offset,REGISTER_O0);
					} else
						w_as_parameter (&instruction->instruction_parameters[0]);
				}
				w_as_newline();
			
				w_as_movl_register_register_newline (REGISTER_O0,REGISTER_A1);
			}
			break;
		case REGISTER_A1:
			if (tmp_reg==REGISTER_D0){
				w_as_movl_register_register_newline (REGISTER_A1,REGISTER_D0);
		
				if (unsigned_div){
					w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);				
					w_as_opcode (intel_asm ? "div" : "divl");
				} else {
					w_as_instruction_without_parameters ("cdq");
					w_as_opcode (intel_asm ? "idiv" : "idivl");			
				}
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_A1)
						r=REGISTER_D0;
					
					w_as_register (r);
				} else {
					if (intel_asm)
						fprintf (assembly_file,"dword ptr ");
					if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_A1)
						r=REGISTER_D0;

					w_as_indirect (instruction->instruction_parameters[0].parameter_offset,r);					
				} else
					w_as_parameter (&instruction->instruction_parameters[0]);
				}
				w_as_newline();
		
				w_as_movl_register_register_newline (REGISTER_D0,REGISTER_A1);
			} else {
				w_as_movl_register_register_newline (REGISTER_D0,tmp_reg);
		
				w_as_movl_register_register_newline (REGISTER_A1,REGISTER_D0);
		
				if (unsigned_div){
					w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);				
					w_as_opcode (intel_asm ? "div" : "divl");
				} else {
					w_as_instruction_without_parameters ("cdq");
					w_as_opcode (intel_asm ? "idiv" : "idivl");			
				}
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=tmp_reg;
					else if (r==REGISTER_A1)
						r=REGISTER_D0;
					
					w_as_register (r);
				} else {
					if (intel_asm)
						fprintf (assembly_file,"dword ptr ");
					if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=tmp_reg;
					else if (r==REGISTER_A1)
						r=REGISTER_D0;

					w_as_indirect (instruction->instruction_parameters[0].parameter_offset,r);					
				} else
					w_as_parameter (&instruction->instruction_parameters[0]);
				}
				w_as_newline();
		
				w_as_movl_register_register_newline (REGISTER_D0,REGISTER_A1);

				w_as_movl_register_register_newline (tmp_reg,REGISTER_D0);
			}
			break;
		default:
			if (tmp_reg==REGISTER_D0){
				w_as_movl_register_register_newline (d_reg,REGISTER_D0);
				w_as_movl_register_register_newline (REGISTER_A1,d_reg);

				if (unsigned_div){
					w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);				
					w_as_opcode (intel_asm ? "div" : "divl");
				} else {
					w_as_instruction_without_parameters ("cdq");
					w_as_opcode (intel_asm ? "idiv" : "idivl");			
				}
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_A1)
						r=d_reg;
					else if (r==d_reg)
						r=REGISTER_D0;
					
					w_as_register (r);			
				} else {
					if (intel_asm)
						fprintf (assembly_file,"dword ptr ");
					if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_A1)
						r=d_reg;
					else if (r==d_reg)
						r=REGISTER_D0;
					
					w_as_indirect (instruction->instruction_parameters[0].parameter_offset,r);
				} else
					w_as_parameter (&instruction->instruction_parameters[0]);
				}
				w_as_newline();

				w_as_movl_register_register_newline (d_reg,REGISTER_A1);
				w_as_movl_register_register_newline (REGISTER_D0,d_reg);
			} else if (tmp_reg==REGISTER_A1){
				w_as_opcode_register_register_newline ("xchg",REGISTER_D0,d_reg);
		
				if (unsigned_div){
					w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);				
					w_as_opcode (intel_asm ? "div" : "divl");
				} else {
					w_as_instruction_without_parameters ("cdq");
					w_as_opcode (intel_asm ? "idiv" : "idivl");			
				}
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=d_reg;
					else if (r==d_reg)
						r=REGISTER_D0;
					
					w_as_register (r);			
				} else {
					if (intel_asm)
						fprintf (assembly_file,"dword ptr ");
					if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=d_reg;
					else if (r==d_reg)
						r=REGISTER_D0;
					
					w_as_indirect (instruction->instruction_parameters[0].parameter_offset,r);
				} else
					w_as_parameter (&instruction->instruction_parameters[0]);
				}
				w_as_newline();
		
				w_as_opcode_register_register_newline ("xchg",REGISTER_D0,d_reg);
			} else {
				w_as_movl_register_register_newline (REGISTER_A1,tmp_reg);
		
				w_as_opcode_register_register_newline ("xchg",REGISTER_D0,d_reg);
		
				if (unsigned_div){
					w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);				
					w_as_opcode (intel_asm ? "div" : "divl");
				} else {
					w_as_instruction_without_parameters ("cdq");
					w_as_opcode (intel_asm ? "idiv" : "idivl");			
				}
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=d_reg;
					else if (r==REGISTER_A1)
						r=tmp_reg;
					else if (r==d_reg)
						r=REGISTER_D0;
					
					w_as_register (r);			
				} else {
					if (intel_asm)
						fprintf (assembly_file,"dword ptr ");
					if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
						int r;
					
						r=instruction->instruction_parameters[0].parameter_data.reg.r;
						if (r==REGISTER_D0)
							r=d_reg;
						else if (r==REGISTER_A1)
							r=tmp_reg;
						else if (r==d_reg)
							r=REGISTER_D0;
					
						w_as_indirect (instruction->instruction_parameters[0].parameter_offset,r);
					} else
						w_as_parameter (&instruction->instruction_parameters[0]);
				}
				w_as_newline();
		
				w_as_opcode_register_register_newline ("xchg",REGISTER_D0,d_reg);
			
				w_as_movl_register_register_newline (tmp_reg,REGISTER_A1);
			}
	}
}
#endif

#ifndef THREAD32
static void w_as_rem_instruction (struct instruction *instruction,int unsigned_rem)
{
	int d_reg;

	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE && unsigned_rem==0){
		int i,log2i;
		
		i=instruction->instruction_parameters[0].parameter_data.i;
		
		if (i<0 && i!=0x80000000)
			i=-i;
		
		if (! ((i & (i-1))==0 && i>1)){
			internal_error_in_function ("w_as_rem_instruction");
			return;
		}
				
		log2i=0;
		while (i>1){
			i=i>>1;
			++log2i;
		}
		
		w_as_movl_register_register_newline (d_reg,REGISTER_O0);

		if (log2i==1){
			w_as_opcode ("and");
			w_as_immediate_register_newline (1,d_reg);

			w_as_sar_31_r (REGISTER_O0);

			w_as_opcode_register_register_newline ("xor",REGISTER_O0,d_reg);
		} else {
			w_as_sar_31_r (REGISTER_O0);

			w_as_opcode ("and");
			w_as_immediate_register_newline ((1<<log2i)-1,REGISTER_O0);

			w_as_opcode_register_register_newline ("add",REGISTER_O0,d_reg);

			w_as_opcode ("and");
			w_as_immediate_register_newline ((1<<log2i)-1,d_reg);
		}
		
		w_as_opcode_register_register_newline ("sub",REGISTER_O0,d_reg);

		return;
	}

	switch (d_reg){
		case REGISTER_D0:
			w_as_movl_register_register_newline (REGISTER_A1,REGISTER_O0);

			if (unsigned_rem){
				w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);				
				w_as_opcode (intel_asm ? "div" : "divl");
			} else {
				w_as_instruction_without_parameters ("cdq");
				w_as_opcode (intel_asm ? "idiv" : "idivl");
			}

			if (instruction->instruction_parameters[0].parameter_type==P_REGISTER
				&& instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A1)
			{
				w_as_scratch_register();
			} else {
				if (intel_asm)
					fprintf (assembly_file,"dword ptr ");
				if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT
				&& instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A1)
				{
					w_as_indirect (instruction->instruction_parameters[0].parameter_offset,REGISTER_O0);
				} else
					w_as_parameter (&instruction->instruction_parameters[0]);
			}
			w_as_newline();

			w_as_movl_register_register_newline (REGISTER_A1,REGISTER_D0);

			w_as_movl_register_register_newline (REGISTER_O0,REGISTER_A1);
	
			break;		
		case REGISTER_A1:
			w_as_movl_register_register_newline (REGISTER_D0,REGISTER_O0);
	
			w_as_movl_register_register_newline (REGISTER_A1,REGISTER_D0);
	
			if (unsigned_rem){
				w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);				
				w_as_opcode (intel_asm ? "div" : "divl");
			} else {
				w_as_instruction_without_parameters ("cdq");
				w_as_opcode (intel_asm ? "idiv" : "idivl");
			}
			if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
				int r;
				
				r=instruction->instruction_parameters[0].parameter_data.reg.r;
				if (r==REGISTER_D0)
					r=REGISTER_O0;
				else if (r==REGISTER_A1)
					r=REGISTER_D0;
				
				w_as_register (r);
			} else {
				if (intel_asm)
					fprintf (assembly_file,"dword ptr ");
				if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					int r;
				
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=REGISTER_O0;
					else if (r==REGISTER_A1)
						r=REGISTER_D0;
				
					w_as_indirect (instruction->instruction_parameters[0].parameter_offset,r);
				} else
					w_as_parameter (&instruction->instruction_parameters[0]);
			}
			w_as_newline();

			w_as_movl_register_register_newline (REGISTER_O0,REGISTER_D0);
			break;
		default:	
			w_as_movl_register_register_newline (REGISTER_A1,REGISTER_O0);

			w_as_opcode_register_register_newline ("xchg",REGISTER_D0,d_reg);
	
			if (unsigned_rem){
				w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);				
				w_as_opcode (intel_asm ? "div" : "divl");
			} else {
				w_as_instruction_without_parameters ("cdq");
				w_as_opcode (intel_asm ? "idiv" : "idivl");
			}
			if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
				int r;
				
				r=instruction->instruction_parameters[0].parameter_data.reg.r;
				if (r==REGISTER_D0)
					r=d_reg;
				else if (r==REGISTER_A1)
					r=REGISTER_O0;
				else if (r==d_reg)
					r=REGISTER_D0;
				
				w_as_register (r);
			} else {
				if (intel_asm)
					fprintf (assembly_file,"dword ptr ");
				if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					int r;
				
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=d_reg;
					else if (r==REGISTER_A1)
						r=REGISTER_O0;
					else if (r==d_reg)
						r=REGISTER_D0;
				
					w_as_indirect (instruction->instruction_parameters[0].parameter_offset,r);				
				} else
					w_as_parameter (&instruction->instruction_parameters[0]);
			}
			w_as_newline();

			w_as_movl_register_register_newline (d_reg,REGISTER_D0);

			w_as_movl_register_register_newline (REGISTER_A1,d_reg);

			w_as_movl_register_register_newline (REGISTER_O0,REGISTER_A1);
	}
}
#else
static void w_as_rem_instruction (struct instruction *instruction,int unsigned_rem)
{
	int d_reg,tmp_reg;

	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;
	tmp_reg=instruction->instruction_parameters[2].parameter_data.reg.r;

	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE && unsigned_rem==0){
		int i,log2i;
		
		i=instruction->instruction_parameters[0].parameter_data.i;
		
		if (i<0 && i!=0x80000000)
			i=-i;
		
		if (! ((i & (i-1))==0 && i>1)){
			internal_error_in_function ("w_as_rem_instruction");
			return;
		}
				
		log2i=0;
		while (i>1){
			i=i>>1;
			++log2i;
		}
		
		w_as_movl_register_register_newline (d_reg,tmp_reg);

		if (log2i==1){
			w_as_opcode ("and");
			w_as_immediate_register_newline (1,d_reg);

			w_as_sar_31_r (tmp_reg);

			w_as_opcode_register_register_newline ("xor",tmp_reg,d_reg);
		} else {
			w_as_sar_31_r (tmp_reg);

			w_as_opcode ("and");
			w_as_immediate_register_newline ((1<<log2i)-1,tmp_reg);

			w_as_opcode_register_register_newline ("add",tmp_reg,d_reg);

			w_as_opcode ("and");
			w_as_immediate_register_newline ((1<<log2i)-1,d_reg);
		}
		
		w_as_opcode_register_register_newline ("sub",tmp_reg,d_reg);

		return;
	}

	switch (d_reg){
		case REGISTER_D0:
			if (tmp_reg==REGISTER_A1){
				if (unsigned_rem){
					w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);				
					w_as_opcode (intel_asm ? "div" : "divl");
				} else {
					w_as_instruction_without_parameters ("cdq");
					w_as_opcode (intel_asm ? "idiv" : "idivl");
				}

				w_as_parameter (&instruction->instruction_parameters[0]);
				w_as_newline();

				w_as_movl_register_register_newline (REGISTER_A1,REGISTER_D0);
			} else {
				w_as_movl_register_register_newline (REGISTER_A1,tmp_reg);

				if (unsigned_rem){
					w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);				
					w_as_opcode (intel_asm ? "div" : "divl");
				} else {
					w_as_instruction_without_parameters ("cdq");
					w_as_opcode (intel_asm ? "idiv" : "idivl");
				}

				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER
					&& instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A1)
				{
					w_as_scratch_register();
				} else {
					if (intel_asm)
						fprintf (assembly_file,"dword ptr ");
					if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT
					&& instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A1)
					{
						w_as_indirect (instruction->instruction_parameters[0].parameter_offset,tmp_reg);
					} else
						w_as_parameter (&instruction->instruction_parameters[0]);
				}
				w_as_newline();

				w_as_movl_register_register_newline (REGISTER_A1,REGISTER_D0);

				w_as_movl_register_register_newline (tmp_reg,REGISTER_A1);
			}
			break;		
		case REGISTER_A1:
			if (tmp_reg==REGISTER_D0){		
				w_as_movl_register_register_newline (REGISTER_A1,REGISTER_D0);
		
				if (unsigned_rem){
					w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);				
					w_as_opcode (intel_asm ? "div" : "divl");
				} else {
					w_as_instruction_without_parameters ("cdq");
					w_as_opcode (intel_asm ? "idiv" : "idivl");
				}
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_A1)
						r=REGISTER_D0;
					
					w_as_register (r);
				} else {
					if (intel_asm)
						fprintf (assembly_file,"dword ptr ");
					if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
						int r;
					
						r=instruction->instruction_parameters[0].parameter_data.reg.r;
						if (r==REGISTER_A1)
							r=REGISTER_D0;
					
						w_as_indirect (instruction->instruction_parameters[0].parameter_offset,r);
					} else
						w_as_parameter (&instruction->instruction_parameters[0]);
				}
				w_as_newline();
			} else {
				w_as_movl_register_register_newline (REGISTER_D0,tmp_reg);
		
				w_as_movl_register_register_newline (REGISTER_A1,REGISTER_D0);
		
				if (unsigned_rem){
					w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);				
					w_as_opcode (intel_asm ? "div" : "divl");
				} else {
					w_as_instruction_without_parameters ("cdq");
					w_as_opcode (intel_asm ? "idiv" : "idivl");
				}
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=tmp_reg;
					else if (r==REGISTER_A1)
						r=REGISTER_D0;
					
					w_as_register (r);
				} else {
					if (intel_asm)
						fprintf (assembly_file,"dword ptr ");
					if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
						int r;
					
						r=instruction->instruction_parameters[0].parameter_data.reg.r;
						if (r==REGISTER_D0)
							r=tmp_reg;
						else if (r==REGISTER_A1)
							r=REGISTER_D0;
					
						w_as_indirect (instruction->instruction_parameters[0].parameter_offset,r);
					} else
						w_as_parameter (&instruction->instruction_parameters[0]);
				}
				w_as_newline();

				w_as_movl_register_register_newline (tmp_reg,REGISTER_D0);
			}
			break;
		default:
			if (tmp_reg==REGISTER_D0){
				w_as_movl_register_register_newline (d_reg,REGISTER_D0);
				w_as_movl_register_register_newline (REGISTER_A1,d_reg);
		
				if (unsigned_rem){
					w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);				
					w_as_opcode (intel_asm ? "div" : "divl");
				} else {
					w_as_instruction_without_parameters ("cdq");
					w_as_opcode (intel_asm ? "idiv" : "idivl");
				}
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_A1)
						r=d_reg;
					else if (r==d_reg)
						r=REGISTER_D0;
					
					w_as_register (r);
				} else {
					if (intel_asm)
						fprintf (assembly_file,"dword ptr ");
					if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
						int r;
					
						r=instruction->instruction_parameters[0].parameter_data.reg.r;
						if (r==REGISTER_A1)
							r=d_reg;
						else if (r==d_reg)
							r=REGISTER_D0;
					
						w_as_indirect (instruction->instruction_parameters[0].parameter_offset,r);				
					} else
						w_as_parameter (&instruction->instruction_parameters[0]);
				}
				w_as_newline();

				w_as_opcode_register_register_newline ("xchg",d_reg,REGISTER_A1);
			} else if (tmp_reg==REGISTER_A1){
				w_as_opcode_register_register_newline ("xchg",REGISTER_D0,d_reg);
		
				if (unsigned_rem){
					w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);				
					w_as_opcode (intel_asm ? "div" : "divl");
				} else {
					w_as_instruction_without_parameters ("cdq");
					w_as_opcode (intel_asm ? "idiv" : "idivl");
				}
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=d_reg;
					else if (r==d_reg)
						r=REGISTER_D0;
					
					w_as_register (r);
				} else {
					if (intel_asm)
						fprintf (assembly_file,"dword ptr ");
					if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
						int r;
					
						r=instruction->instruction_parameters[0].parameter_data.reg.r;
						if (r==REGISTER_D0)
							r=d_reg;
						else if (r==d_reg)
							r=REGISTER_D0;
					
						w_as_indirect (instruction->instruction_parameters[0].parameter_offset,r);				
					} else
						w_as_parameter (&instruction->instruction_parameters[0]);
				}
				w_as_newline();

				w_as_movl_register_register_newline (d_reg,REGISTER_D0);

				w_as_movl_register_register_newline (REGISTER_A1,d_reg);
			} else {
				w_as_movl_register_register_newline (REGISTER_A1,tmp_reg);

				w_as_opcode_register_register_newline ("xchg",REGISTER_D0,d_reg);
		
				if (unsigned_rem){
					w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);				
					w_as_opcode (intel_asm ? "div" : "divl");
				} else {
					w_as_instruction_without_parameters ("cdq");
					w_as_opcode (intel_asm ? "idiv" : "idivl");
				}
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=d_reg;
					else if (r==REGISTER_A1)
						r=tmp_reg;
					else if (r==d_reg)
						r=REGISTER_D0;
					
					w_as_register (r);
				} else {
					if (intel_asm)
						fprintf (assembly_file,"dword ptr ");
					if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
						int r;
					
						r=instruction->instruction_parameters[0].parameter_data.reg.r;
						if (r==REGISTER_D0)
							r=d_reg;
						else if (r==REGISTER_A1)
							r=tmp_reg;
						else if (r==d_reg)
							r=REGISTER_D0;
					
						w_as_indirect (instruction->instruction_parameters[0].parameter_offset,r);				
					} else
						w_as_parameter (&instruction->instruction_parameters[0]);
				}
				w_as_newline();

				w_as_movl_register_register_newline (d_reg,REGISTER_D0);

				w_as_movl_register_register_newline (REGISTER_A1,d_reg);

				w_as_movl_register_register_newline (tmp_reg,REGISTER_A1);
			}
	}
}
#endif

static void w_as_2movl_registers (int reg1,int reg2,int reg3)
{
	w_as_movl_register_register_newline (reg2,reg3);
	w_as_movl_register_register_newline (reg1,reg2);
}

static void w_as_3movl_registers (int reg1,int reg2,int reg3,int reg4)
{
	w_as_movl_register_register_newline (reg3,reg4);
	w_as_movl_register_register_newline (reg2,reg3);
	w_as_movl_register_register_newline (reg1,reg2);
}

static void w_as_mulud_instruction (struct instruction *instruction)
{
	int reg_1,reg_2;
#ifdef THREAD32
	int reg_3;
#endif
	
	reg_1=instruction->instruction_parameters[0].parameter_data.reg.r;
	reg_2=instruction->instruction_parameters[1].parameter_data.reg.r;

#ifdef THREAD32
	reg_3=instruction->instruction_parameters[2].parameter_data.reg.r;

	if (reg_3==REGISTER_D0){
		if (reg_1==REGISTER_A1){
			w_as_movl_register_register_newline (reg_2,REGISTER_D0);
			w_as_opcode_register_newline ("mul",reg_1);
			w_as_movl_register_register_newline (REGISTER_D0,reg_2);
		} else if (reg_2==REGISTER_A1){
			w_as_movl_register_register_newline (reg_2,REGISTER_D0);
			w_as_opcode_register_newline ("mul",reg_1);
			w_as_2movl_registers (REGISTER_D0,REGISTER_A1,reg_1);
		} else {
			w_as_2movl_registers (REGISTER_A1,reg_2,REGISTER_D0);
			w_as_opcode_register_newline ("mul",reg_1);
			w_as_3movl_registers (REGISTER_D0,reg_2,REGISTER_A1,reg_1);
		}
		return;
	}

	if (reg_3==REGISTER_A1){
		if (reg_2==REGISTER_D0){
			w_as_opcode_register_newline ("mul",reg_1);
			w_as_movl_register_register_newline (REGISTER_A1,reg_1);
		} else if (reg_1==REGISTER_D0){
			w_as_opcode_register_newline ("mul",reg_2);
			w_as_2movl_registers (REGISTER_A1,REGISTER_D0,reg_2);
		} else {
			w_as_opcode_register_register_newline ("xchg",reg_2,REGISTER_D0);
			w_as_opcode_register_newline ("mul",reg_1);
			w_as_opcode_register_register_newline ("xchg",reg_2,REGISTER_D0);
			w_as_movl_register_register_newline (REGISTER_A1,reg_1);
		}
		return;
	}

	if (reg_2==REGISTER_D0){
		if (reg_1==REGISTER_A1){
			w_as_opcode_register_newline ("mul",reg_1);
		} else {
			w_as_movl_register_register_newline (REGISTER_A1,reg_3);
			w_as_opcode_register_newline ("mul",reg_1);
			w_as_2movl_registers (reg_3,REGISTER_A1,reg_1);
		}
	} else if (reg_1==REGISTER_A1){
		w_as_2movl_registers (reg_2,REGISTER_D0,reg_3);
		w_as_opcode_register_newline ("mul",reg_1);
		w_as_2movl_registers (reg_3,REGISTER_D0,reg_2);
	} else if (reg_1==REGISTER_D0){
		if (reg_2==REGISTER_A1){
			w_as_opcode_register_newline ("mul",REGISTER_A1);
			w_as_opcode_register_register_newline ("xchg",REGISTER_A1,REGISTER_D0);
		} else {
			w_as_movl_register_register_newline (REGISTER_A1,reg_3);
			w_as_opcode_register_newline ("mul",reg_2);
			w_as_3movl_registers (reg_3,REGISTER_A1,REGISTER_D0,reg_2);
		}
	} else if (reg_2==REGISTER_A1){
		w_as_2movl_registers (reg_2,REGISTER_D0,reg_3);		
		w_as_opcode_register_newline ("mul",reg_1);
		w_as_3movl_registers (reg_3,REGISTER_D0,REGISTER_A1,reg_1);
	} else {
		w_as_opcode_register_register_newline ("xchg",reg_2,REGISTER_D0);
		w_as_movl_register_register_newline (REGISTER_A1,reg_3);
		w_as_opcode_register_newline ("mul",reg_1);
		w_as_opcode_register_register_newline ("xchg",reg_2,REGISTER_D0);
		w_as_2movl_registers (reg_3,REGISTER_A1,reg_1);
	}
#else
	if (reg_2==REGISTER_D0){
		if (reg_1==REGISTER_A1){
			w_as_opcode_register_newline ("mul",reg_1);
		} else {
			w_as_movl_register_register_newline (REGISTER_A1,REGISTER_O0);
			w_as_opcode_register_newline ("mul",reg_1);
			w_as_2movl_registers (REGISTER_O0,REGISTER_A1,reg_1);
		}
	} else if (reg_1==REGISTER_A1){
		w_as_2movl_registers (reg_2,REGISTER_D0,REGISTER_O0);
		w_as_opcode_register_newline ("mul",reg_1);
		w_as_2movl_registers (REGISTER_O0,REGISTER_D0,reg_2);
	} else if (reg_1==REGISTER_D0){
		if (reg_2==REGISTER_A1){
			w_as_opcode_register_newline ("mul",REGISTER_A1);
			w_as_opcode_register_register_newline ("xchg",REGISTER_A1,REGISTER_D0);
		} else {
			w_as_movl_register_register_newline (REGISTER_A1,REGISTER_O0);
			w_as_opcode_register_newline ("mul",reg_2);
			w_as_3movl_registers (REGISTER_O0,REGISTER_A1,REGISTER_D0,reg_2);
		}
	} else if (reg_2==REGISTER_A1){
		w_as_2movl_registers (reg_2,REGISTER_D0,REGISTER_O0);		
		w_as_opcode_register_newline ("mul",reg_1);
		w_as_3movl_registers (REGISTER_O0,REGISTER_D0,REGISTER_A1,reg_1);
	} else {
		w_as_opcode_register_register_newline ("xchg",reg_2,REGISTER_D0);
		w_as_movl_register_register_newline (REGISTER_A1,REGISTER_O0);
		w_as_opcode_register_newline ("mul",reg_1);
		w_as_opcode_register_register_newline ("xchg",reg_2,REGISTER_D0);
		w_as_2movl_registers (REGISTER_O0,REGISTER_A1,reg_1);
	}
#endif
}

static void w_as_divdu_instruction (struct instruction *instruction)
{
	int reg_1,reg_2,reg_3;
	
	reg_1=instruction->instruction_parameters[0].parameter_data.reg.r;
	reg_2=instruction->instruction_parameters[1].parameter_data.reg.r;
	reg_3=instruction->instruction_parameters[2].parameter_data.reg.r;

#ifdef THREAD32
	if (reg_3==REGISTER_D0){
		if (reg_2==REGISTER_A1)
			w_as_opcode_register_newline ("div",reg_1);
		else {
			w_as_opcode_register_register_newline ("xchg",REGISTER_A1,reg_2);
			if (reg_1==reg_2)
				w_as_opcode_register_newline ("div",REGISTER_A1);
			else if (reg_1==REGISTER_A1)
				w_as_opcode_register_newline ("div",reg_2);
			else
				w_as_opcode_register_newline ("div",reg_1);
			w_as_opcode_register_register_newline ("xchg",REGISTER_A1,reg_2);
		}
	} else if (reg_3==REGISTER_A1){
		w_as_opcode_register_register_newline ("xchg",REGISTER_D0,REGISTER_A1);
		if (reg_2==REGISTER_D0){
			if (reg_1==REGISTER_D0)
				w_as_opcode_register_newline ("div",REGISTER_A1);			
			else if (reg_1==REGISTER_A1)
				w_as_opcode_register_newline ("div",REGISTER_D0);
			else
				w_as_opcode_register_newline ("div",reg_1);
		} else {
			w_as_opcode_register_register_newline ("xchg",REGISTER_A1,reg_2);
			if (reg_1==reg_2)
				w_as_opcode_register_newline ("div",REGISTER_A1);
			else if (reg_1==REGISTER_D0)
				w_as_opcode_register_newline ("div",reg_2);
			else if (reg_1==REGISTER_A1)
				w_as_opcode_register_newline ("div",REGISTER_D0);
			else
				w_as_opcode_register_newline ("div",reg_1);
			w_as_opcode_register_register_newline ("xchg",REGISTER_A1,reg_2);
		}
		w_as_opcode_register_register_newline ("xchg",REGISTER_D0,REGISTER_A1);
	} else {
		if (reg_2==REGISTER_A1){
			w_as_opcode_register_register_newline ("xchg",REGISTER_D0,reg_3);
			if (reg_1==reg_3)
				w_as_opcode_register_newline ("div",REGISTER_D0);
			else if (reg_1==REGISTER_D0)
				w_as_opcode_register_newline ("div",reg_3);
			else
				w_as_opcode_register_newline ("div",reg_1);
			w_as_opcode_register_register_newline ("xchg",REGISTER_D0,reg_3);
		} else if (reg_2==REGISTER_D0){
			w_as_opcode_register_register_newline ("xchg",REGISTER_A1,REGISTER_D0);
			w_as_opcode_register_register_newline ("xchg",REGISTER_D0,reg_3);
			if (reg_1==reg_3)
				w_as_opcode_register_newline ("div",REGISTER_D0);
			else if (reg_1==REGISTER_D0)
				w_as_opcode_register_newline ("div",REGISTER_A1);
			else if (reg_1==REGISTER_A1)
				w_as_opcode_register_newline ("div",reg_3);
			else
				w_as_opcode_register_newline ("div",reg_1);
			w_as_opcode_register_register_newline ("xchg",REGISTER_D0,reg_3);
			w_as_opcode_register_register_newline ("xchg",REGISTER_A1,REGISTER_D0);
		} else {
			w_as_opcode_register_register_newline ("xchg",REGISTER_D0,reg_3);
			w_as_opcode_register_register_newline ("xchg",REGISTER_A1,reg_2);
			if (reg_1==REGISTER_D0)
				w_as_opcode_register_newline ("div",reg_3);
			else if (reg_1==REGISTER_A1)
				w_as_opcode_register_newline ("div",reg_2);
			else if (reg_1==reg_3)
				w_as_opcode_register_newline ("div",REGISTER_D0);
			else if (reg_1==reg_2)
				w_as_opcode_register_newline ("div",REGISTER_A1);
			else
				w_as_opcode_register_newline ("div",reg_1);					
			w_as_opcode_register_register_newline ("xchg",REGISTER_A1,reg_2);
			w_as_opcode_register_register_newline ("xchg",REGISTER_D0,reg_3);
		}
	}
#else
	if (reg_1==REGISTER_D0){
		if (reg_3==REGISTER_D0){
			if (reg_2==REGISTER_A1)
				w_as_opcode_register_newline ("div",reg_1);
			else {
				w_as_2movl_registers (reg_2,REGISTER_A1,REGISTER_O0);
				w_as_opcode_register_newline ("div",reg_1);
				w_as_2movl_registers (REGISTER_O0,REGISTER_A1,reg_2);
			}
		} else if (reg_3==REGISTER_A1){
			if (reg_2==REGISTER_D0){
				w_as_opcode_register_register_newline ("xchg",REGISTER_A1,REGISTER_D0);
				w_as_opcode_register_newline ("div",REGISTER_A1);
				w_as_opcode_register_register_newline ("xchg",REGISTER_A1,REGISTER_D0);							
			} else {
				w_as_3movl_registers (reg_2,REGISTER_A1,REGISTER_D0,REGISTER_O0);
				w_as_opcode_register_newline ("div",REGISTER_O0);
				w_as_3movl_registers (REGISTER_O0,REGISTER_D0,REGISTER_A1,reg_2);
			}
		} else {
			if (reg_2==REGISTER_A1){
				w_as_2movl_registers (reg_3,REGISTER_D0,REGISTER_O0);
				w_as_opcode_register_newline ("div",REGISTER_O0);
				w_as_2movl_registers (REGISTER_O0,REGISTER_D0,reg_3);
			} else if (reg_2==REGISTER_D0){
				w_as_3movl_registers (reg_3,REGISTER_D0,REGISTER_A1,REGISTER_O0);
				w_as_opcode_register_newline ("div",REGISTER_A1);
				w_as_3movl_registers (REGISTER_O0,REGISTER_A1,REGISTER_D0,reg_3);
			} else {
				w_as_opcode_register_register_newline ("xchg",reg_3,REGISTER_D0);
				w_as_2movl_registers (reg_2,REGISTER_A1,REGISTER_O0);
				w_as_opcode_register_newline ("div",reg_3);
				w_as_2movl_registers (REGISTER_O0,REGISTER_A1,reg_2);
				w_as_opcode_register_register_newline ("xchg",reg_3,REGISTER_D0);
			}
		}
	} else if (reg_1==REGISTER_A1){
		if (reg_2==REGISTER_A1){
			if (reg_3==REGISTER_D0)
				w_as_opcode_register_newline ("div",reg_1);
			else {
				w_as_2movl_registers (reg_3,REGISTER_D0,REGISTER_O0);
				w_as_opcode_register_newline ("div",reg_1);
				w_as_2movl_registers (REGISTER_O0,REGISTER_D0,reg_3);
			}
		} else if (reg_2==REGISTER_D0){
			if (reg_3==REGISTER_A1){
				w_as_opcode_register_register_newline ("xchg",REGISTER_A1,REGISTER_D0);
				w_as_opcode_register_newline ("div",REGISTER_D0);
				w_as_opcode_register_register_newline ("xchg",REGISTER_A1,REGISTER_D0);							
			} else {
				w_as_3movl_registers (reg_3,REGISTER_D0,REGISTER_A1,REGISTER_O0);
				w_as_opcode_register_newline ("div",REGISTER_O0);
				w_as_3movl_registers (REGISTER_O0,REGISTER_A1,REGISTER_D0,reg_3);
			}
		} else {
			if (reg_3==REGISTER_D0){
				w_as_2movl_registers (reg_2,REGISTER_A1,REGISTER_O0);
				w_as_opcode_register_newline ("div",REGISTER_O0);
				w_as_2movl_registers (REGISTER_O0,REGISTER_A1,reg_2);
			} else if (reg_3==REGISTER_A1){
				w_as_3movl_registers (reg_2,REGISTER_A1,REGISTER_D0,REGISTER_O0);
				w_as_opcode_register_newline ("div",REGISTER_D0);
				w_as_3movl_registers (REGISTER_O0,REGISTER_D0,REGISTER_A1,reg_2);
			} else {
				w_as_opcode_register_register_newline ("xchg",reg_2,REGISTER_A1);
				w_as_2movl_registers (reg_3,REGISTER_D0,REGISTER_O0);
				w_as_opcode_register_newline ("div",reg_2);
				w_as_2movl_registers (REGISTER_O0,REGISTER_D0,reg_3);
				w_as_opcode_register_register_newline ("xchg",reg_2,REGISTER_A1);
			}
		}
	} else {
		if (reg_3==REGISTER_D0){
			if (reg_2==REGISTER_A1){
				w_as_opcode_register_newline ("div",reg_1);
			} else {
				w_as_2movl_registers (reg_2,REGISTER_A1,REGISTER_O0);
				w_as_opcode_register_newline ("div",reg_1);
				w_as_2movl_registers (REGISTER_O0,REGISTER_A1,reg_2);
			}
		} else if (reg_2==REGISTER_A1){
			w_as_2movl_registers (reg_3,REGISTER_D0,REGISTER_O0);
			w_as_opcode_register_newline ("div",reg_1);
			w_as_2movl_registers (REGISTER_O0,REGISTER_D0,reg_3);
		} else if (reg_2==REGISTER_D0){
			if (reg_3==REGISTER_A1){
				w_as_opcode_register_register_newline ("xchg",REGISTER_A1,REGISTER_D0);
				w_as_opcode_register_newline ("div",reg_1);
				w_as_opcode_register_register_newline ("xchg",REGISTER_A1,REGISTER_D0);
			} else {
				w_as_3movl_registers (reg_3,REGISTER_D0,REGISTER_A1,REGISTER_O0);
				w_as_opcode_register_newline ("div",reg_1);
				w_as_3movl_registers (REGISTER_O0,REGISTER_A1,REGISTER_D0,reg_3);
			}
		} else if (reg_3==REGISTER_A1){
			w_as_3movl_registers (reg_2,REGISTER_A1,REGISTER_D0,REGISTER_O0);
			w_as_opcode_register_newline ("div",reg_1);
			w_as_3movl_registers (REGISTER_O0,REGISTER_D0,REGISTER_A1,reg_2);
		} else {
			w_as_opcode_register_register_newline ("xchg",reg_3,REGISTER_D0);
			w_as_2movl_registers (reg_2,REGISTER_A1,REGISTER_O0);
			w_as_opcode_register_newline ("div",reg_1);
			w_as_2movl_registers (REGISTER_O0,REGISTER_A1,reg_2);
			w_as_opcode_register_register_newline ("xchg",reg_3,REGISTER_D0);
		}
	}
#endif
}

static void w_as_or_r_r (int reg_1,int reg_2)
{
	w_as_opcode_register_register_newline (intel_asm ? "or" : "orl",reg_1,reg_2);
}

static void w_as_xor_r_r (int reg_1,int reg_2)
{
	w_as_opcode_register_register_newline (intel_asm ? "xor" : "xorl",reg_1,reg_2);
}

static void w_as_floordiv_mod (int reg_1,int compute_mod)
{
	/* reg_1 not EAX or EDX */
	w_as_instruction_without_parameters ("cdq");
	w_as_opcode_register_newline (intel_asm ? "idiv" : "idivl",reg_1);

	if (!compute_mod){
		w_as_sar_31_r (reg_1);

		w_as_opcode_register_register_newline (intel_asm ? "add" : "addl",reg_1,REGISTER_A1);

		w_as_xor_r_r (reg_1,REGISTER_A1);

		w_as_sar_31_r (REGISTER_A1);

		w_as_opcode_register_register_newline (intel_asm ? "add" : "addl",REGISTER_A1,REGISTER_D0);	
	} else {
		w_as_movl_register_register_newline (reg_1,REGISTER_D0);

		w_as_sar_31_r (reg_1);

		w_as_opcode_register_register_newline (intel_asm ? "add" : "addl",REGISTER_A1,reg_1);

		w_as_xor_r_r (REGISTER_D0,reg_1);

		w_as_sar_31_r (reg_1);

		w_as_opcode_register_register_newline (intel_asm ? "and" : "andl",reg_1,REGISTER_D0);
		
		w_as_opcode_register_register_newline (intel_asm ? "add" : "addl",REGISTER_A1,REGISTER_D0);
	}
}

static void w_as_mul_shift_magic (int s)
{
	w_as_opcode (intel_asm ? "mul" : "mull");
	w_as_register (REGISTER_A1);
	w_as_newline();

	if (s>0){
		w_as_opcode ("shr");
		w_as_immediate_register_newline (s,REGISTER_A1);
	}
}

static void w_as_floordiv_ni (int reg_1,int reg_2,int reg_3,int i)
{
	struct ms ms;

	ms=magic (i);

	if (reg_2==REGISTER_D0){
		if (reg_1==REGISTER_A1){
			reg_3=reg_1;
			reg_3=REGISTER_A1;
		}
		w_as_movl_register_register_newline (REGISTER_D0,reg_1);

		w_as_opcode ("sub");
		w_as_immediate_register_newline (1,REGISTER_D0);

		w_as_or_r_r (REGISTER_D0,reg_1);

		if (reg_3!=REGISTER_A1)
			w_as_movl_register_register_newline (REGISTER_A1,reg_3);

		w_as_sar_31_r (reg_1);
		w_as_opcode_movl();
		w_as_immediate_register_newline (ms.m,REGISTER_A1);

		w_as_xor_r_r (reg_1,REGISTER_D0);

		w_as_mul_shift_magic (ms.s);

		w_as_opcode_register_newline ("not",reg_1);
		w_as_movl_register_register_newline (reg_1,REGISTER_D0);
		w_as_xor_r_r (REGISTER_A1,REGISTER_D0);

		if (reg_3!=REGISTER_A1)
			w_as_movl_register_register_newline (reg_3,REGISTER_A1);
	} else if (reg_2==REGISTER_A1){
		if (reg_3==REGISTER_D0){
			reg_3=reg_1;
			reg_1=REGISTER_D0;
		}
		w_as_movl_register_register_newline (REGISTER_A1,reg_3);

		w_as_opcode ("sub");
		w_as_immediate_register_newline (1,REGISTER_A1);

		w_as_or_r_r (REGISTER_A1,reg_3);

		if (reg_1!=REGISTER_D0)
			w_as_movl_register_register_newline (REGISTER_D0,reg_1);

		w_as_sar_31_r (reg_3);
		w_as_opcode_movl();
		w_as_immediate_register_newline (ms.m,REGISTER_D0);

		w_as_xor_r_r (reg_3,REGISTER_A1);
		
		w_as_mul_shift_magic (ms.s);

		w_as_opcode_register_newline ("not",reg_3);
		if (reg_1!=REGISTER_D0)
			w_as_movl_register_register_newline (reg_1,REGISTER_D0);

		w_as_xor_r_r (reg_3,REGISTER_A1);
	} else {
		if (reg_3==REGISTER_D0){
			reg_3=reg_1;
			reg_1=REGISTER_D0;
		} else if (reg_1==REGISTER_A1){
			reg_3=reg_1;
			reg_3=REGISTER_A1;
		}
		/* reg_3!=REGISTER_D0 && reg_1!=REGISTER_A1 */
		if (reg_1==REGISTER_D0){
			w_as_opcode_movl();
			w_as_immediate_register_newline (-1,REGISTER_D0);

			w_as_opcode_register_register_newline ("add",reg_2,REGISTER_D0);

			w_as_or_r_r (REGISTER_D0,reg_2);

			if (reg_3!=REGISTER_A1)
				w_as_movl_register_register_newline (REGISTER_A1,reg_3);

			w_as_sar_31_r (reg_2);

			w_as_opcode_movl();
			w_as_immediate_register_newline (ms.m,REGISTER_A1);

			w_as_xor_r_r (reg_2,REGISTER_D0);

			w_as_mul_shift_magic (ms.s);
			w_as_opcode_register_newline ("not",reg_2);
			w_as_xor_r_r (REGISTER_A1,reg_2);

			if (reg_3!=REGISTER_A1)
				w_as_movl_register_register_newline (reg_3,REGISTER_A1);
		} else if (reg_3==REGISTER_A1){
			w_as_opcode_movl();
			w_as_immediate_register_newline (-1,REGISTER_A1);

			w_as_opcode_register_register_newline ("add",reg_2,REGISTER_A1);

			w_as_or_r_r (REGISTER_A1,reg_2);

			w_as_movl_register_register_newline (REGISTER_D0,reg_1);

			w_as_sar_31_r (reg_2);

			w_as_opcode_movl();
			w_as_immediate_register_newline (ms.m,REGISTER_D0);

			w_as_xor_r_r (reg_2,REGISTER_A1);

			w_as_mul_shift_magic (ms.s);
			w_as_opcode_register_newline ("not",reg_2);

			w_as_movl_register_register_newline (reg_1,REGISTER_D0);

			w_as_xor_r_r (REGISTER_A1,reg_2);
		} else {
			w_as_movl_register_register_newline (REGISTER_D0,reg_1);
			w_as_opcode_movl();
			w_as_immediate_register_newline (-1,REGISTER_D0);
		
			w_as_opcode_register_register_newline ("add",reg_2,REGISTER_D0);

			w_as_or_r_r (REGISTER_D0,reg_2);

			w_as_sar_31_r (reg_2);

			w_as_movl_register_register_newline (REGISTER_A1,reg_3);

			w_as_opcode_movl();
			w_as_immediate_register_newline (ms.m,REGISTER_A1);

			w_as_xor_r_r (reg_2,REGISTER_D0);

			w_as_mul_shift_magic (ms.s);
			w_as_opcode_register_newline ("not",reg_2);

			w_as_movl_register_register_newline (reg_1,REGISTER_D0);

			w_as_xor_r_r (REGISTER_A1,reg_2);

			w_as_movl_register_register_newline (reg_3,REGISTER_A1);
		}
	}
}

static void w_as_floordiv_i (int reg_1,int reg_2,int reg_3,int i)
{
	struct ms ms;

	if (i<0){
		w_as_floordiv_ni (reg_1,reg_2,reg_3,-i);
		return;
	}

	ms=magic (i);

	if (reg_2==REGISTER_D0){
		if (reg_1==REGISTER_A1){
			reg_3=reg_1;
			reg_3=REGISTER_A1;
		}
		w_as_movl_register_register_newline (REGISTER_D0,reg_1);
		if (reg_3!=REGISTER_A1)
			w_as_movl_register_register_newline (REGISTER_A1,reg_3);

		w_as_sar_31_r (reg_1);
		w_as_opcode_movl();
		w_as_immediate_register_newline (ms.m,REGISTER_A1);

		w_as_xor_r_r (reg_1,REGISTER_D0);

		w_as_mul_shift_magic (ms.s);

		w_as_movl_register_register_newline (reg_1,REGISTER_D0);
		w_as_xor_r_r (REGISTER_A1,REGISTER_D0);

		if (reg_3!=REGISTER_A1)
			w_as_movl_register_register_newline (reg_3,REGISTER_A1);
	} else if (reg_2==REGISTER_A1){
		if (reg_3==REGISTER_D0){
			reg_3=reg_1;
			reg_1=REGISTER_D0;
		}
		w_as_movl_register_register_newline (REGISTER_A1,reg_3);
		if (reg_1!=REGISTER_D0)
			w_as_movl_register_register_newline (REGISTER_D0,reg_1);

		w_as_sar_31_r (reg_3);
		w_as_opcode_movl();
		w_as_immediate_register_newline (ms.m,REGISTER_D0);

		w_as_xor_r_r (reg_3,REGISTER_A1);
		
		w_as_mul_shift_magic (ms.s);

		if (reg_1!=REGISTER_D0)
			w_as_movl_register_register_newline (reg_1,REGISTER_D0);

		w_as_xor_r_r (reg_3,REGISTER_A1);
	} else {
		if (reg_3==REGISTER_D0){
			reg_3=reg_1;
			reg_1=REGISTER_D0;
		} else if (reg_1==REGISTER_A1){
			reg_3=reg_1;
			reg_3=REGISTER_A1;
		}
		/* reg_3!=REGISTER_D0 && reg_1!=REGISTER_A1 */
		if (reg_1==REGISTER_D0){
			w_as_movl_register_register_newline (reg_2,REGISTER_D0);
			w_as_sar_31_r (reg_2);

			if (reg_3!=REGISTER_A1)
				w_as_movl_register_register_newline (REGISTER_A1,reg_3);

			w_as_xor_r_r (reg_2,REGISTER_D0);

			w_as_opcode_movl();
			w_as_immediate_register_newline (ms.m,REGISTER_A1);
			w_as_mul_shift_magic (ms.s);
			w_as_xor_r_r (REGISTER_A1,reg_2);

			if (reg_3!=REGISTER_A1)
				w_as_movl_register_register_newline (reg_3,REGISTER_A1);
		} else if (reg_3==REGISTER_A1){
			w_as_movl_register_register_newline (reg_2,REGISTER_A1);
			w_as_sar_31_r (reg_2);

			w_as_movl_register_register_newline (REGISTER_D0,reg_1);

			w_as_xor_r_r (reg_2,REGISTER_A1);

			w_as_opcode_movl();
			w_as_immediate_register_newline (ms.m,REGISTER_D0);
			w_as_mul_shift_magic (ms.s);

			w_as_movl_register_register_newline (reg_1,REGISTER_D0);

			w_as_xor_r_r (REGISTER_A1,reg_2);
		} else {
			w_as_movl_register_register_newline (REGISTER_D0,reg_1);
			w_as_movl_register_register_newline (reg_2,REGISTER_D0);
			w_as_sar_31_r (reg_2);

			w_as_xor_r_r (reg_2,REGISTER_D0);

			w_as_movl_register_register_newline (REGISTER_A1,reg_3);

			w_as_opcode_movl();
			w_as_immediate_register_newline (ms.m,REGISTER_A1);
			w_as_mul_shift_magic (ms.s);

			w_as_movl_register_register_newline (reg_1,REGISTER_D0);

			w_as_xor_r_r (REGISTER_A1,reg_2);

			w_as_movl_register_register_newline (reg_3,REGISTER_A1);
		}
	}
}

static void w_as_floordiv_mod_instruction (struct instruction *instruction,int compute_mod)
{
	int reg_1,reg_2,reg_3;

	reg_1=instruction->instruction_parameters[0].parameter_data.reg.r;
	reg_2=instruction->instruction_parameters[1].parameter_data.reg.r;
	reg_3=instruction->instruction_parameters[2].parameter_data.reg.r;

	if (instruction->instruction_arity==4){
		w_as_floordiv_i (reg_1,reg_2,reg_3,instruction->instruction_parameters[3].parameter_data.imm);
		return;
	}

	/* reg_2 = floor (reg_2/reg_1) or mod reg_2 reg_1 */

	if (reg_2==REGISTER_D0){
		if (reg_3==REGISTER_A1){
			w_as_floordiv_mod (reg_1,compute_mod);
		} else if (reg_1==REGISTER_A1){
			w_as_movl_register_register_newline (reg_1,reg_3);
			w_as_floordiv_mod (reg_3,compute_mod);
		} else {
			w_as_movl_register_register_newline (REGISTER_A1,reg_3);
			w_as_floordiv_mod (reg_1,compute_mod);
			w_as_movl_register_register_newline (reg_3,REGISTER_A1);
		}
	} else if (reg_3==REGISTER_A1){
		if (reg_3==REGISTER_D0){
			w_as_movl_register_register_newline (reg_2/*A1*/,reg_3/*D0*/);
			w_as_floordiv_mod (reg_1,compute_mod);
			w_as_movl_register_register_newline (REGISTER_D0,reg_2/*A1*/);
		} else if (reg_1==REGISTER_D0){
			w_as_2movl_registers (reg_2/*A1*/,reg_1/*D0*/,reg_3);
			w_as_floordiv_mod (reg_3,compute_mod);
			w_as_movl_register_register_newline (REGISTER_D0,reg_2/*A1*/);
		} else {
			w_as_2movl_registers (reg_2/*A1*/,REGISTER_D0,reg_3);
			w_as_floordiv_mod (reg_1,compute_mod);
			w_as_movl_register_register_newline (reg_3,reg_1);
			w_as_2movl_registers (reg_1,REGISTER_D0,reg_2/*A1*/);
		}
	} else {
		if (reg_3==REGISTER_D0){
			if (reg_1==REGISTER_A1){
				w_as_2movl_registers (reg_1/*A1*/,reg_2,reg_3/*D0*/);
				w_as_floordiv_mod (reg_2,compute_mod);
				w_as_movl_register_register_newline (reg_3/*D0*/,reg_2);
			} else {
				w_as_2movl_registers (REGISTER_A1,reg_2,reg_3/*D0*/);
				w_as_floordiv_mod (reg_1,compute_mod);
				w_as_2movl_registers (reg_3/*D0*/,reg_2,REGISTER_A1);
			}
		} else if (reg_3==REGISTER_A1){
			if (reg_1==REGISTER_D0){
				w_as_opcode_register_register_newline ("xchg",reg_1/*D0*/,reg_2);
				w_as_floordiv_mod (reg_2,compute_mod);
				w_as_movl_register_register_newline (REGISTER_D0,reg_2);
			} else {
				w_as_opcode_register_register_newline ("xchg",REGISTER_D0,reg_2);
				w_as_floordiv_mod (reg_1,compute_mod);
				w_as_opcode_register_register_newline ("xchg",REGISTER_D0,reg_2);
			}
		} else {
			if (reg_1==REGISTER_D0){
				w_as_3movl_registers (REGISTER_A1,reg_2,reg_1/*D0*/,reg_3);
				w_as_floordiv_mod (reg_3,compute_mod);
				w_as_2movl_registers (REGISTER_D0,reg_2,REGISTER_A1);
			} else if (reg_1==REGISTER_A1){
				w_as_opcode_register_register_newline ("xchg",REGISTER_D0,reg_2);
				w_as_movl_register_register_newline (reg_1/*A1*/,reg_3);
				w_as_floordiv_mod (reg_3,compute_mod);
				w_as_opcode_register_register_newline ("xchg",REGISTER_D0,reg_2);				
			} else {
				w_as_opcode_register_register_newline ("xchg",REGISTER_D0,reg_2);
				w_as_movl_register_register_newline (REGISTER_A1,reg_3);
				w_as_floordiv_mod (reg_1,compute_mod);
				w_as_movl_register_register_newline (reg_3,REGISTER_A1);
				w_as_opcode_register_register_newline ("xchg",REGISTER_D0,reg_2);				
			}
		}
	}
}

static void w_as_word_instruction (struct instruction *instruction)
{
	fprintf (assembly_file,"\t.byte\t%d\n",
			(int)instruction->instruction_parameters[0].parameter_data.i);
}

#ifdef DATA_IN_CODE_SECTION
	struct float_constant {
		DOUBLE *				float_constant_r_p;
		int						float_constant_label_number;
		struct float_constant *	float_constant_next;
	};

	struct float_constant *first_float_constant,**float_constant_l;
	
	static void w_as_float_constant (int label_number,DOUBLE *r_p)
	{
		struct float_constant *new_float_constant;
		
		new_float_constant=allocate_memory_from_heap (sizeof (struct float_constant));

		new_float_constant->float_constant_r_p=r_p;
		new_float_constant->float_constant_label_number=label_number;

		*float_constant_l=new_float_constant;
		float_constant_l=&new_float_constant->float_constant_next;
		
		new_float_constant->float_constant_next=NULL;
	}
	
	static void write_float_constants()
	{
		struct float_constant *float_constant;

		float_constant=first_float_constant;
		
		if (float_constant!=NULL){
			w_as_align (3);
			
			for (; float_constant!=NULL; float_constant=float_constant->float_constant_next){
				w_as_define_internal_data_label (float_constant->float_constant_label_number);
			
				w_as_opcode (intel_asm ? "dq" : ".double");
				fprintf (assembly_file,intel_asm ? "%.20e" : "0r%.20e",*float_constant->float_constant_r_p);
				w_as_newline();		
			}
		}
	}
#else
	static void w_as_float_constant (int label_number,DOUBLE *r_p)
	{
		w_as_to_data_section();
	
		w_as_align (3);
	
		w_as_define_internal_data_label (label_number);
	
		w_as_opcode (intel_asm ? "dq" : ".double");
		fprintf (assembly_file,intel_asm ? "%.20e" : "0r%.20e",*r_p);
		w_as_newline();
	
		w_as_to_code_section();
	}
#endif

static void w_as_fld_parameter (struct parameter *parameter_p)
{
	switch (parameter_p->parameter_type){
		case P_F_IMMEDIATE:
		{
			int label_number;
			
			label_number=next_label_id++;

			w_as_float_constant (label_number,parameter_p->parameter_data.r);

			fprintf (assembly_file,intel_asm ? "\tfld\tqword ptr i_%d" : "\tfldl\ti_%d",label_number);
			break;
		}
		case P_INDIRECT:
			fprintf (assembly_file,intel_asm ? "\tfld\tqword ptr " : "\tfldl\t");
			w_as_indirect (parameter_p->parameter_offset,parameter_p->parameter_data.reg.r);
			break;
		case P_INDEXED:
			fprintf (assembly_file,intel_asm ? "\tfld\tqword ptr " : "\tfldl\t");
			w_as_indexed (parameter_p->parameter_offset,parameter_p->parameter_data.ir);
			break;
		case P_F_REGISTER:
			w_as_opcode ("fld");
			w_as_fp_register (parameter_p->parameter_data.reg.r);
			break;
		default:
			internal_error_in_function ("w_as_fld_parameter");
			return;
	}
}

static void w_as_opcode_parameter_newline (char *opcode,struct parameter *parameter_p)
{
	switch (parameter_p->parameter_type){
		case P_F_IMMEDIATE:
		{
			int label_number;
			
			label_number=next_label_id++;

			w_as_float_constant (label_number,parameter_p->parameter_data.r);

			fprintf (assembly_file,intel_asm ? "\t%s\tqword ptr i_%d" : "\t%sl\ti_%d",opcode,label_number);
			w_as_newline();
			break;
		}
		case P_INDIRECT:
			fprintf (assembly_file,intel_asm ? "\t%s\tqword ptr " : "\t%sl\t",opcode);
			w_as_indirect (parameter_p->parameter_offset,parameter_p->parameter_data.reg.r);
			w_as_newline();
			break;
		case P_INDEXED:
			fprintf (assembly_file,intel_asm ? "\t%s\tqword ptr " : "\t%sl\t",opcode);
			w_as_indexed (parameter_p->parameter_offset,parameter_p->parameter_data.ir);
			w_as_newline();
			break;
		case P_F_REGISTER:
			w_as_opcode (opcode);
			if (intel_asm)
				fprintf (assembly_file,"st,");
			w_as_fp_register_newline (parameter_p->parameter_data.reg.r);
			break;
		default:
			internal_error_in_function ("w_as_opcode_parameter_newline");
			return;
	}
}

#ifdef FP_STACK_OPTIMIZATIONS
#define FP_REVERSE_SUB_DIV_OPERANDS 1
#define FP_REG_ON_TOP 2
#define FP_REG_LAST_USE 4

extern struct instruction *find_next_fp_instruction (struct instruction *instruction);
extern int next_instruction_is_fld_reg (int reg0,struct instruction *instruction);

static void fstpl_instruction (int reg0,struct instruction *instruction)
{
	struct instruction *next_fp_instruction;

	next_fp_instruction=find_next_fp_instruction (instruction->instruction_next);
	if (next_fp_instruction!=NULL){		
		switch (next_fp_instruction->instruction_icode){
			case IFADD: case IFSUB: case IFMUL: case IFDIV:
				if (next_fp_instruction->instruction_parameters[1].parameter_data.reg.r==reg0){
					next_fp_instruction->instruction_parameters[1].parameter_flags |= FP_REG_ON_TOP;
				
					if (next_fp_instruction->instruction_parameters[0].parameter_type==P_F_REGISTER
						&& next_fp_instruction->instruction_parameters[0].parameter_data.reg.r==reg0)
					{
						next_fp_instruction->instruction_parameters[0].parameter_flags |= FP_REG_ON_TOP;
					}
					
					return;
				} /* else */
			case IFSQRT: case IFNEG: case IFABS: case IFSIN: case IFCOS:
				if (next_fp_instruction->instruction_parameters[0].parameter_type==P_F_REGISTER
					&& next_fp_instruction->instruction_parameters[0].parameter_data.reg.r==reg0)
				{
					next_fp_instruction->instruction_parameters[0].parameter_flags |= FP_REG_ON_TOP;

					if (!(next_fp_instruction->instruction_parameters[0].parameter_flags & FP_REG_LAST_USE)){
						w_as_opcode (intel_asm ? "fst" : "fstl");
						w_as_fp_register_newline (reg0+1);
					}

					return;						
				}
				break;
			case IFCMP:
				if (next_fp_instruction->instruction_parameters[1].parameter_data.reg.r==reg0){
					next_fp_instruction->instruction_parameters[1].parameter_flags |= FP_REG_ON_TOP;

					if (!(next_fp_instruction->instruction_parameters[1].parameter_flags & FP_REG_LAST_USE)){
						w_as_opcode (intel_asm ? "fst" : "fstl");
						w_as_fp_register_newline (reg0+1);
					}

					return;
				}
				break;
			case IFEXG:
				if (next_fp_instruction->instruction_parameters[0].parameter_data.reg.r==reg0){
					next_fp_instruction->instruction_parameters[0].parameter_flags |= FP_REG_ON_TOP;
					return;
				}
				if (next_fp_instruction->instruction_parameters[1].parameter_data.reg.r==reg0){
					next_fp_instruction->instruction_parameters[1].parameter_flags |= FP_REG_ON_TOP;					
					return;
				}
				break;
			case IFMOVE:
				if (next_fp_instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
					if (next_fp_instruction->instruction_parameters[0].parameter_data.reg.r==reg0 /* && reg0!=0 */){
						next_fp_instruction->instruction_parameters[0].parameter_flags |= FP_REG_ON_TOP;
						
						if (!(next_fp_instruction->instruction_parameters[0].parameter_flags & FP_REG_LAST_USE)){
							w_as_opcode (intel_asm ? "fst" : "fstl");
							w_as_fp_register_newline (reg0+1);
						}

						return;						
					}
					
					if (next_fp_instruction->instruction_parameters[1].parameter_type==P_F_REGISTER){
						struct instruction *next2_fp_instruction;
						int d_freg;

						next2_fp_instruction=next_fp_instruction->instruction_next;
						d_freg=next_fp_instruction->instruction_parameters[1].parameter_data.reg.r;

						if (next2_fp_instruction!=NULL && d_freg!=reg0){
							switch (next2_fp_instruction->instruction_icode){
								case IFADD: case IFSUB: case IFMUL: case IFDIV:
									if (next2_fp_instruction->instruction_parameters[1].parameter_data.reg.r==d_freg
										&& next2_fp_instruction->instruction_parameters[0].parameter_type==P_F_REGISTER)
									{
										int s_f_reg1;
										
										s_f_reg1=next_fp_instruction->instruction_parameters[0].parameter_data.reg.r;
										
										if (next2_fp_instruction->instruction_parameters[0].parameter_data.reg.r==reg0 && s_f_reg1!=reg0){
											int flags1,flags2;
											
											next_fp_instruction->instruction_parameters[0].parameter_data.reg.r=reg0;
											next2_fp_instruction->instruction_parameters[0].parameter_data.reg.r=s_f_reg1;
											
											flags1=next2_fp_instruction->instruction_parameters[0].parameter_flags;
											flags2=next_fp_instruction->instruction_parameters[0].parameter_flags;
											
											flags1 |= FP_REG_ON_TOP;

											next_fp_instruction->instruction_parameters[0].parameter_flags=flags1;
											next2_fp_instruction->instruction_parameters[0].parameter_flags=flags2;
											
											if (next2_fp_instruction->instruction_icode==IFSUB || next2_fp_instruction->instruction_icode==IFDIV)
												next2_fp_instruction->instruction_parameters[1].parameter_flags ^= FP_REVERSE_SUB_DIV_OPERANDS;
											
											if (!(flags1 & FP_REG_LAST_USE)){
												w_as_opcode (intel_asm ? "fst" : "fstl");
												w_as_fp_register_newline (reg0+1);
											}

											return;						
										}
									}
							}
						}
					}
				}
		}
	}

	w_as_opcode ("fstp");
	w_as_fp_register_newline (reg0+1);
}
#endif

static void w_as_fp0_comma_fp_register_newline (int freg)
{
	if (!intel_asm){
		w_as_fp_register (0);
		w_as_comma();
		w_as_fp_register (freg);
	} else {
		w_as_fp_register (freg);		
		w_as_comma();
		fprintf (assembly_file,"st");
	}
	w_as_newline();
}

static void w_as_dyadic_float_instruction (struct instruction *instruction,char *opcode1,char *opcode2)
{
	int d_freg;
	
	d_freg=instruction->instruction_parameters[1].parameter_data.reg.r;

#ifdef FP_STACK_OPTIMIZATIONS
	if (instruction->instruction_parameters[1].parameter_flags & FP_REG_ON_TOP){
		if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
			int reg_s;

			if (instruction->instruction_parameters[0].parameter_flags & FP_REG_ON_TOP)
				reg_s=0;
			else
				reg_s=instruction->instruction_parameters[0].parameter_data.reg.r+1;

			w_as_opcode (opcode1);
			if (intel_asm)
				fprintf (assembly_file,"st,");
			w_as_fp_register_newline (reg_s);
		} else
			w_as_opcode_parameter_newline (opcode1,&instruction->instruction_parameters[0]);

		fstpl_instruction (d_freg,instruction);	
		
		return;
	} else if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER
			   && instruction->instruction_parameters[0].parameter_flags & FP_REG_ON_TOP)
	{
		int n;
		
		n=next_instruction_is_fld_reg (d_freg,instruction);
		if (n){
			w_as_opcode (opcode2);
			if (intel_asm)
				fprintf (assembly_file,"st,");
			w_as_fp_register_newline (d_freg+1);
			
			if (n==1){
				w_as_opcode ("fst");
				w_as_fp_register_newline (d_freg+1);
			}
		} else {
			w_as_opcode_p (opcode1);
			w_as_fp0_comma_fp_register_newline (d_freg+1);
		}
		
		return;
	}
#endif

	if (d_freg==0){
		w_as_opcode_parameter_newline (opcode1,&instruction->instruction_parameters[0]);
	} else {
#ifdef FP_STACK_OPTIMIZATIONS
		int n;
#endif
		if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER
			&& instruction->instruction_parameters[0].parameter_data.reg.r==0)
		{
			w_as_opcode (opcode1);
			w_as_fp0_comma_fp_register_newline (d_freg);
			return;
		}

		w_as_fld_parameter (&instruction->instruction_parameters[0]);
		w_as_newline();

#ifdef FP_STACK_OPTIMIZATIONS
		n=next_instruction_is_fld_reg (d_freg,instruction);
		if (n){
			w_as_opcode (opcode2);
			if (intel_asm)
				fprintf (assembly_file,"st,");
			w_as_fp_register_newline (d_freg+1);
			
			if (n==1){
				w_as_opcode ("fst");
				w_as_fp_register_newline (d_freg+1);
			}
		} else {
#endif
			w_as_opcode_p (opcode1);
			w_as_fp0_comma_fp_register_newline (d_freg+1);
#ifdef FP_STACK_OPTIMIZATIONS
		}
#endif
	}
}

static void w_as_compare_float_instruction (struct instruction *instruction,char *opcode1,char *opcode2)
{
	int d_freg;
	char *opcode;
	
	d_freg=instruction->instruction_parameters[1].parameter_data.reg.r;

#ifdef FP_STACK_OPTIMIZATIONS
	if (instruction->instruction_parameters[1].parameter_flags & FP_REG_ON_TOP){
		opcode=opcode2;
	} else
#endif

	if (d_freg!=0){
		w_as_opcode ("fld");
		w_as_fp_register_newline (d_freg);
		
		opcode=opcode2;
	} else
		opcode=opcode1;
		
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_F_IMMEDIATE:
		{
			int label_number;
			
			label_number=next_label_id++;

			w_as_float_constant (label_number,instruction->instruction_parameters[0].parameter_data.r);
			
			fprintf (assembly_file,intel_asm ? "\t%s\tqword ptr i_%d" : "\t%sl\ti_%d",opcode,label_number);
			w_as_newline();
			break;
		}
		case P_INDIRECT:
			fprintf (assembly_file,intel_asm ? "\t%s\tqword ptr " : "\t%sl\t",opcode);
			w_as_indirect (instruction->instruction_parameters[0].parameter_offset,instruction->instruction_parameters[0].parameter_data.reg.r);
			w_as_newline();
			break;
		case P_INDEXED:
			fprintf (assembly_file,intel_asm ? "\t%s\tqword ptr " : "\t%sl\t",opcode);
			w_as_indexed (instruction->instruction_parameters[0].parameter_offset,instruction->instruction_parameters[0].parameter_data.ir);
			w_as_newline();
			break;
		case P_F_REGISTER:
			w_as_opcode (opcode);
			w_as_fp_register_newline (instruction->instruction_parameters[0].parameter_data.reg.r+(d_freg!=0));
			break;
		default:
			internal_error_in_function ("w_as_compare_float_instruction");
			return;
	}
}

static void w_as_monadic_float_instruction (struct instruction *instruction,char *opcode)
{
	int d_freg;
	
	d_freg=instruction->instruction_parameters[1].parameter_data.reg.r;
	
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_F_IMMEDIATE:
		{
			int label_number=next_label_id++;

			w_as_float_constant (label_number,instruction->instruction_parameters[0].parameter_data.r);
			
			fprintf (assembly_file,intel_asm ? "\tfld\tqword ptr ti_%d" : "\tfldl\ti_%d",label_number);
			w_as_newline();
			break;
		}
		case P_INDIRECT:
			if (!intel_asm)
				w_as_opcode ("fldl");
			else {
				w_as_opcode ("fld");
				fprintf (assembly_file,"qword ptr ");
			}
			w_as_indirect (instruction->instruction_parameters[0].parameter_offset,instruction->instruction_parameters[0].parameter_data.reg.r);
			w_as_newline();
			break;
		case P_INDEXED:
			if (!intel_asm)
				w_as_opcode ("fldl");
			else {
				w_as_opcode ("fld");
				fprintf (assembly_file,"qword ptr ");
			}
			w_as_indexed (instruction->instruction_parameters[0].parameter_offset,instruction->instruction_parameters[0].parameter_data.ir);
			w_as_newline();
			break;
		case P_F_REGISTER:
#ifdef FP_STACK_OPTIMIZATIONS
			if (instruction->instruction_parameters[0].parameter_flags & FP_REG_ON_TOP)
				break;
#endif
			if (instruction->instruction_parameters[0].parameter_data.reg.r==0 && d_freg==0){
				w_as_opcode (opcode);
				w_as_newline();
				return;
			} else {
				w_as_opcode (intel_asm ? "fld" : "fldl");
				w_as_fp_register_newline (instruction->instruction_parameters[0].parameter_data.reg.r);
			}
			break;
		default:
			internal_error_in_function ("w_as_monadic_float_instruction");
			return;
	}

	w_as_opcode (opcode);
	w_as_newline();

#ifdef FP_STACK_OPTIMIZATIONS
	fstpl_instruction (d_freg,instruction);	
#else
	w_as_opcode ("fstp");
	w_as_fp_register_newline (d_freg+1);
#endif
}

static void w_as_fsincos_instruction (struct instruction *instruction)
{
	int f_reg1,f_reg2;
	
	f_reg1=instruction->instruction_parameters[0].parameter_data.reg.r;
	f_reg2=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (f_reg1!=0){
		w_as_opcode ("fxch");
		w_as_fp_register_newline (f_reg1);
	}

	w_as_opcode ("fsincos");
	w_as_newline();

	if (f_reg1==0){
#ifdef FP_STACK_OPTIMIZATIONS
		fstpl_instruction (f_reg2,instruction);	
#else
		w_as_opcode ("fstp");
		w_as_fp_register_newline (f_reg2+1);
#endif
	} else if (f_reg2==0){
		w_as_opcode ("fxch");
		w_as_fp_register_newline (1);

#ifdef FP_STACK_OPTIMIZATIONS
		fstpl_instruction (f_reg1,instruction);	
#else
		w_as_opcode ("fstp");
		w_as_fp_register_newline (f_reg1+1);
#endif
	} else {
		w_as_opcode ("fstp");
		w_as_fp_register_newline (f_reg2+1);

		w_as_opcode ("fxch");
		w_as_fp_register_newline (f_reg1);
	}
}

static struct instruction *w_as_fmove_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_F_REGISTER:
		{
			int reg0;

			reg0=-1;

			switch (instruction->instruction_parameters[0].parameter_type){
				case P_F_REGISTER:
				{
#ifdef FP_STACK_OPTIMIZATIONS
					if (instruction->instruction_parameters[0].parameter_flags & FP_REG_ON_TOP)
						break;
#endif

					reg0=instruction->instruction_parameters[0].parameter_data.reg.r;
					
					if (reg0==instruction->instruction_parameters[1].parameter_data.reg.r)
						return instruction;
					
					if (reg0==0){
						w_as_opcode (intel_asm ? "fst" : "fstl");
						w_as_fp_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
						return instruction;
					}

					w_as_opcode ("fld");
					w_as_fp_register_newline (instruction->instruction_parameters[0].parameter_data.reg.r);
					break;
				}
				case P_INDIRECT:
					if (!intel_asm)
						w_as_opcode ("fldl");
					else {
						w_as_opcode ("fld");
						fprintf (assembly_file,"qword ptr ");
					}
					w_as_indirect (instruction->instruction_parameters[0].parameter_offset,
								   instruction->instruction_parameters[0].parameter_data.reg.r);
					w_as_newline();
					break;
				case P_INDEXED:
					if (!intel_asm)
						w_as_opcode ("fldl");
					else {
						w_as_opcode ("fld");
						fprintf (assembly_file,"qword ptr ");
					}
					w_as_indexed (instruction->instruction_parameters[0].parameter_offset,
								   instruction->instruction_parameters[0].parameter_data.ir);
					w_as_newline();
					break;
				case P_F_IMMEDIATE:
				{
					int label_number=next_label_id++;

					w_as_float_constant (label_number,instruction->instruction_parameters[0].parameter_data.r);
			
					fprintf (assembly_file,intel_asm ? "\tfld\tqword ptr i_%d" : "\tfldl\ti_%d",label_number);
					w_as_newline();
					break;
				}
				default:
					internal_error_in_function ("w_as_fmove_instruction");
					return instruction;
			}
#ifdef FP_STACK_OPTIMIZATIONS
			fstpl_instruction (instruction->instruction_parameters[1].parameter_data.reg.r,instruction);
			return instruction;
		}
#else
			{	
 				struct instruction *next_instruction;
				int reg1;

				reg1=instruction->instruction_parameters[1].parameter_data.reg.r;
				
				next_instruction=instruction->instruction_next;
				if (next_instruction)
					switch (next_instruction->instruction_icode){
						case IFADD: case IFSUB: case IFMUL: case IFDIV:
							if (next_instruction->instruction_parameters[1].parameter_data.reg.r==reg1){
								char *opcode;
							
								switch (next_instruction->instruction_icode){
									case IFADD:
										opcode="fadd";
										break;
									case IFSUB:
# ifdef FSUB_FDIV_REVERSED
										if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
											opcode="fsubr";
										else
# endif
											opcode="fsub";
										break;
									case IFMUL:
										opcode="fmul";
										break;
									case IFDIV:
# ifdef FSUB_FDIV_REVERSED
										if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
											opcode="fdivr";
										else
# endif
											opcode="fdiv";
										break;
								}
								
								if (next_instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
									int reg_s;

									reg_s=next_instruction->instruction_parameters[0].parameter_data.reg.r;
									if (reg_s==reg1)
										reg_s=reg0;

									w_as_opcode (opcode);
									if (intel_asm)
										fprintf (assembly_file,"st,");
									w_as_fp_register_newline (reg_s+1);
								} else
									w_as_opcode_parameter_newline (opcode,&next_instruction->instruction_parameters[0]);
								
								w_as_opcode ("fstp");
								w_as_fp_register_newline (reg1+1);
								
								return next_instruction;
							}
					}
			}
		}

			w_as_opcode ("fstp");
			w_as_fp_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r+1);
			return instruction;
#endif
		case P_INDIRECT:
		case P_INDEXED:
			if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
				int s_freg;
				
				s_freg=instruction->instruction_parameters[0].parameter_data.reg.r;
				
#ifdef FP_STACK_OPTIMIZATIONS
				if (instruction->instruction_parameters[0].parameter_flags & FP_REG_ON_TOP){
					if (next_instruction_is_fld_reg (s_freg,instruction))
						w_as_opcode (intel_asm ? "fst" : "fstl");
					else {
						w_as_opcode (intel_asm ? "fstp" : "fstpl");
					}
				} else
#endif
				if (s_freg!=0){
					w_as_opcode ("fld");
					w_as_fp_register_newline (s_freg);
					
#ifdef FP_STACK_OPTIMIZATIONS
					if (next_instruction_is_fld_reg (s_freg,instruction))
						w_as_opcode (intel_asm ? "fst" : "fstl");
					else
#endif
					w_as_opcode (intel_asm ? "fstp" : "fstpl");
				} else
					w_as_opcode (intel_asm ? "fst" : "fstl");
				
				if (intel_asm)
					fprintf (assembly_file,"qword ptr ");

				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT)
					w_as_indirect (instruction->instruction_parameters[1].parameter_offset,
								   instruction->instruction_parameters[1].parameter_data.reg.r);
				else
					w_as_indexed (instruction->instruction_parameters[1].parameter_offset,
								  instruction->instruction_parameters[1].parameter_data.ir);
					
				w_as_newline();
				return instruction;
			}
	}
	internal_error_in_function ("w_as_fmove_instruction");
	return instruction;
}

static struct instruction *w_as_floads_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_F_REGISTER:
		{
			int reg0;

			reg0=-1;

			switch (instruction->instruction_parameters[0].parameter_type){
				case P_INDIRECT:
					if (!intel_asm)
						w_as_opcode ("flds");
					else {
						w_as_opcode ("fld");
						fprintf (assembly_file,"dword ptr ");
					}
					w_as_indirect (instruction->instruction_parameters[0].parameter_offset,
								   instruction->instruction_parameters[0].parameter_data.reg.r);
					w_as_newline();
					break;
				case P_INDEXED:
					if (!intel_asm)
						w_as_opcode ("flds");
					else {
						w_as_opcode ("fld");
						fprintf (assembly_file,"dword ptr ");
					}
					w_as_indexed (instruction->instruction_parameters[0].parameter_offset,
								   instruction->instruction_parameters[0].parameter_data.ir);
					w_as_newline();
					break;
				default:
					internal_error_in_function ("w_as_floads_instruction");
					return instruction;
			}
#ifdef FP_STACK_OPTIMIZATIONS
			fstpl_instruction (instruction->instruction_parameters[1].parameter_data.reg.r,instruction);
			return instruction;
		}
#else
			{	
 				struct instruction *next_instruction;
				int reg1;

				reg1=instruction->instruction_parameters[1].parameter_data.reg.r;
				
				next_instruction=instruction->instruction_next;
				if (next_instruction)
					switch (next_instruction->instruction_icode){
						case IFADD: case IFSUB: case IFMUL: case IFDIV:
							if (next_instruction->instruction_parameters[1].parameter_data.reg.r==reg1){
								char *opcode;
							
								switch (next_instruction->instruction_icode){
									case IFADD:
										opcode="fadd";
										break;
									case IFSUB:
# ifdef FSUB_FDIV_REVERSED
										if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
											opcode="fsubr";
										else
# endif
											opcode="fsub";
										break;
									case IFMUL:
										opcode="fmul";
										break;
									case IFDIV:
# ifdef FSUB_FDIV_REVERSED
										if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
											opcode="fdivr";
										else
# endif
											opcode="fdiv";
										break;
								}
								
								if (next_instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
									int reg_s;

									reg_s=next_instruction->instruction_parameters[0].parameter_data.reg.r;
									if (reg_s==reg1)
										reg_s=reg0;

									w_as_opcode (opcode);
									if (intel_asm)
										fprintf (assembly_file,"st,");
									w_as_fp_register_newline (reg_s+1);
								} else
									w_as_opcode_parameter_newline (opcode,&next_instruction->instruction_parameters[0]);
								
								w_as_opcode ("fstp");
								w_as_fp_register_newline (reg1+1);
								
								return next_instruction;
							}
					}
			}
		}

			w_as_opcode ("fstp");
			w_as_fp_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r+1);
			return instruction;
#endif
	}
	internal_error_in_function ("w_as_floads_instruction");
	return instruction;
}

static struct instruction *w_as_fmoves_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_INDIRECT:
		case P_INDEXED:
			if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
				int s_freg;
				
				s_freg=instruction->instruction_parameters[0].parameter_data.reg.r;
				
#ifdef FP_STACK_OPTIMIZATIONS
				if (instruction->instruction_parameters[0].parameter_flags & FP_REG_ON_TOP){
					if (next_instruction_is_fld_reg (s_freg,instruction))
						w_as_opcode (intel_asm ? "fst" : "fsts");
					else {
						w_as_opcode (intel_asm ? "fstp" : "fstps");
					}
				} else
#endif
				if (s_freg!=0){
					w_as_opcode ("fld");
					w_as_fp_register_newline (s_freg);
					
#ifdef FP_STACK_OPTIMIZATIONS
					if (next_instruction_is_fld_reg (s_freg,instruction))
						w_as_opcode (intel_asm ? "fst" : "fsts");
					else
#endif
					w_as_opcode (intel_asm ? "fstp" : "fstps");
				} else
					w_as_opcode (intel_asm ? "fst" : "fsts");
				
				if (intel_asm)
					fprintf (assembly_file,"dword ptr ");

				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT)
					w_as_indirect (instruction->instruction_parameters[1].parameter_offset,
								   instruction->instruction_parameters[1].parameter_data.reg.r);
				else
					w_as_indexed (instruction->instruction_parameters[1].parameter_offset,
								  instruction->instruction_parameters[1].parameter_data.ir);
					
				w_as_newline();
				return instruction;
			}
	}
	internal_error_in_function ("w_as_fmoves_instruction");
	return instruction;
}

#ifndef THREAD32
static int int_to_real_scratch_imported=0;
#endif

static void w_as_fmovel_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
		if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
			int s_freg;
			
#ifndef THREAD32
			if (intel_asm && !int_to_real_scratch_imported){
				w_as_opcode ("extrn");
				fprintf (assembly_file,"%s:near\n","int_to_real_scratch");
				int_to_real_scratch_imported=1;
			}
#endif

			s_freg=instruction->instruction_parameters[0].parameter_data.reg.r;
			if (s_freg!=0){
				w_as_opcode ("fld");
				w_as_fp_register (s_freg);
				w_as_newline();

				w_as_opcode (!intel_asm ? "fistpl" : "fistp");
			} else 
				w_as_opcode (!intel_asm ? "fistl" : "fist");
			if (intel_asm)
				fprintf (assembly_file,"dword ptr ");
#ifndef THREAD32
			w_as_label ("int_to_real_scratch");
#else
			w_as_indirect (8,REGISTER_A4);
#endif
			w_as_newline();

			w_as_opcode_movl();
			if (intel_asm){
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
				fprintf (assembly_file,"dword ptr ");
			}
#ifndef THREAD32
			w_as_label ("int_to_real_scratch");
#else
			w_as_indirect (8,REGISTER_A4);
#endif
			if (!intel_asm)
				w_as_comma_register (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_newline();
		} else
			internal_error_in_function ("w_as_fmovel_instruction");
	} else {
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_REGISTER:
#ifndef THREAD32
				if (intel_asm && !int_to_real_scratch_imported){
					w_as_opcode ("extrn");
					fprintf (assembly_file,"%s:near\n","int_to_real_scratch");
					int_to_real_scratch_imported=1;
				}
#endif
				w_as_opcode_movl();
				if (!intel_asm)
					w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
				else
					fprintf (assembly_file,"dword ptr ");
#ifndef THREAD32
				w_as_label ("int_to_real_scratch");
#else
				w_as_indirect (8,REGISTER_A4);
#endif
				if (intel_asm)
					w_as_comma_register (instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_newline();

				if (!intel_asm)
					w_as_opcode ("fildl");
				else {
					w_as_opcode ("fild");
					fprintf (assembly_file,"dword ptr ");
				}
				w_as_label ("int_to_real_scratch");
				w_as_newline();
				break;
			case P_INDIRECT:
				if (!intel_asm)
					w_as_opcode ("fildl");
				else {
					w_as_opcode ("fild");
					fprintf (assembly_file,"dword ptr ");
				}
				w_as_indirect (instruction->instruction_parameters[0].parameter_offset,
							   instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_newline();
				break;
			case P_INDEXED:
				if (!intel_asm)
					w_as_opcode ("fildl");
				else {
					w_as_opcode ("fild");
					fprintf (assembly_file,"dword ptr ");
				}
				w_as_indexed (instruction->instruction_parameters[0].parameter_offset,
							  instruction->instruction_parameters[0].parameter_data.ir);
				w_as_newline();
				break;
			case P_IMMEDIATE:
			{
				int label_number=next_label_id++;

				w_as_to_data_section();

				w_as_align (2);

				w_as_define_internal_data_label (label_number);

				w_as_opcode (intel_asm ? "dd" : ".long");
				fprintf (assembly_file,"%ld",instruction->instruction_parameters[0].parameter_data.i);
				w_as_newline();

				w_as_to_code_section();

				fprintf (assembly_file,"\tfildl\ti_%d",label_number);
				w_as_newline();
				break;
			}
			default:
				internal_error_in_function ("w_as_fmovel_instruction");
		}

#ifdef FP_STACK_OPTIMIZATIONS
		fstpl_instruction (instruction->instruction_parameters[1].parameter_data.reg.r,instruction);
#else
		w_as_opcode ("fstp");
		w_as_fp_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r+1);
#endif
	}
}

#ifdef FP_STACK_OPTIMIZATIONS
static void w_as_fexg (struct instruction *instruction)
{
	int f_reg1,f_reg2;
	
	f_reg1=instruction->instruction_parameters[0].parameter_data.reg.r;
	f_reg2=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (instruction->instruction_parameters[0].parameter_flags & FP_REG_ON_TOP){
		if (f_reg1!=f_reg2){
			w_as_opcode ("fxch");
			w_as_fp_register_newline (f_reg2+1);
		}

		fstpl_instruction (f_reg1,instruction);
		return;
	} else if (instruction->instruction_parameters[1].parameter_flags & FP_REG_ON_TOP){
		if (f_reg1!=f_reg2){
			w_as_opcode ("fxch");
			w_as_fp_register_newline (f_reg1+1);
		}

		fstpl_instruction (f_reg2,instruction);
		return;	
	} else {
		if (f_reg1!=f_reg2){
			if (f_reg1==0){
				w_as_opcode ("fxch");
				w_as_fp_register_newline (f_reg2);
			} else if (f_reg2==0){
				w_as_opcode ("fxch");
				w_as_fp_register_newline (f_reg1);
			} else {
				w_as_opcode ("fxch");
				w_as_fp_register_newline (f_reg1);

				w_as_opcode ("fxch");
				w_as_fp_register_newline (f_reg2);

				w_as_opcode ("fxch");
				w_as_fp_register_newline (f_reg1);
			}
		}
	}
}
#endif

static void w_as_rtsi_instruction (struct instruction *instruction)
{
	w_as_opcode ("ret");
	w_as_immediate (instruction->instruction_parameters[0].parameter_data.i);
	w_as_newline();
}

static void w_as_rtsp_instruction (void)
{
	w_as_opcode ("jmp");
	w_as_label ("profile_r");
	w_as_newline();	
}

#ifdef THREAD32
static void w_as_ldtlsp_instruction (struct instruction *instruction)
{
	int reg;

	reg=instruction->instruction_parameters[1].parameter_data.reg.r;
	
	w_as_opcode ("mov");
	if (intel_asm){
		w_as_register_comma (reg);
		fprintf (assembly_file,"dword ptr ");
	}
	if (instruction->instruction_parameters[0].parameter_data.l->label_number!=0)
		w_as_local_label (instruction->instruction_parameters[0].parameter_data.l->label_number);
	else
		w_as_label (instruction->instruction_parameters[0].parameter_data.l->label_name);
	if (!intel_asm)
		w_as_comma_register (reg);
	w_as_newline();

	w_as_opcode ("mov");
	if (intel_asm){
		w_as_register_comma (reg);
		fprintf (assembly_file,"dword ptr fs:[0x0e10+");
		w_as_register (reg);
		fprintf (assembly_file,"*4]");
	} else {
		fprintf (assembly_file,"fs:0x0e10(,");
		w_as_register (reg);
		fprintf (assembly_file,",4)");
		w_as_comma_register (reg);
	}
	w_as_newline();
}
#endif

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
				w_as_dyadic_instruction (instruction,intel_asm ? "add" : "addl");
				break;
			case ISUB:
				w_as_dyadic_instruction (instruction,intel_asm ? "sub" : "subl");
				break;
			case ICMP:
				w_as_cmp_instruction (instruction);
				break;
			case IJMP:
				w_as_jmp_instruction (instruction);
				break;
			case IJMPP:
				w_as_jmpp_instruction (instruction);
				break;
			case IJSR:
				w_as_jsr_instruction (instruction);
				break;
			case IRTS:
				w_as_instruction_without_parameters ("ret");
				break;
			case IRTSP:
				w_as_rtsp_instruction();
				break;
			case IBEQ:
				w_as_branch_instruction (instruction,"je");
				break;
			case IBGE:
				w_as_branch_instruction (instruction,"jge");
				break;
			case IBGEU:
				w_as_branch_instruction (instruction,"jae");
				break;
			case IBGT:
				w_as_branch_instruction (instruction,"jg");
				break;
			case IBGTU:
				w_as_branch_instruction (instruction,"ja");
				break;
			case IBLE:
				w_as_branch_instruction (instruction,"jle");
				break;
			case IBLEU:
				w_as_branch_instruction (instruction,"jbe");
				break;
			case IBLT:
				w_as_branch_instruction (instruction,"jl");
				break;
			case IBLTU:
				w_as_branch_instruction (instruction,"jb");
				break;
			case IBNE:
				w_as_branch_instruction (instruction,"jne");
				break;
			case IBO:
				w_as_branch_instruction (instruction,"jo");
				break;
			case IBNO:
				w_as_branch_instruction (instruction,"jno");
				break;
			case ILSL:
				w_as_shift_instruction (instruction,"shl");
				break;
			case ILSR:
				w_as_shift_instruction (instruction,"shr");
				break;
			case IASR:
				w_as_shift_instruction (instruction,"sar");
				break;
			case ILSL_S:
				w_as_shift_s_instruction (instruction,"shl");
				break;
			case ILSR_S:
				w_as_shift_s_instruction (instruction,"shr");
				break;
			case IASR_S:
				w_as_shift_s_instruction (instruction,"sar");
				break;
			case IMUL:
				w_as_dyadic_instruction (instruction,intel_asm ? "imul" : "imull");
				break;
			case IDIV:
				w_as_div_instruction (instruction,0);
				break;
			case IDIVI:
				w_as_div_rem_i_instruction (instruction,0);
				break;
			case IDIVU:
				w_as_div_instruction (instruction,1);
				break;
			case IREM:
				w_as_rem_instruction (instruction,0);
				break;
			case IREMI:
				w_as_div_rem_i_instruction (instruction,1);
				break;
			case IREMU:
				w_as_rem_instruction (instruction,1);
				break;
			case IAND:
				w_as_dyadic_instruction (instruction,intel_asm ? "and" : "andl");
				break;
			case IOR:
				w_as_dyadic_instruction (instruction,intel_asm ? "or" : "orl");
				break;
			case IEOR:
				w_as_dyadic_instruction (instruction,intel_asm ? "xor" : "xorl");
				break;
			case ISEQ:
				w_as_set_condition_instruction (instruction,"sete");
				break;
			case ISGE:
				w_as_set_condition_instruction (instruction,"setge");
				break;
			case ISGEU:
				w_as_set_condition_instruction (instruction,"setae");
				break;
			case ISGT:
				w_as_set_condition_instruction (instruction,"setg");
				break;
			case ISGTU:
				w_as_set_condition_instruction (instruction,"seta");
				break;
			case ISLE:
				w_as_set_condition_instruction (instruction,"setle");
				break;
			case ISLEU:
				w_as_set_condition_instruction (instruction,"setbe");
				break;
			case ISLT:
				w_as_set_condition_instruction (instruction,"setl");
				break;
			case ISLTU:
				w_as_set_condition_instruction (instruction,"setb");
				break;
			case ISNE:
				w_as_set_condition_instruction (instruction,"setne");
				break;
			case ISO:
				w_as_set_condition_instruction (instruction,"seto");
				break;
			case ISNO:
				w_as_set_condition_instruction (instruction,"setno");
				break;
#if 0
			case ICMPW:
				w_as_cmp_instruction (instruction);
				break;
#endif
			case ITST:
				w_as_tst_instruction (instruction);
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
			case IEXG:
				w_as_dyadic_instruction (instruction,"xchg");
				break;
			case INEG:
				w_as_monadic_instruction (instruction,intel_asm ? "neg" : "negl");
				break;
			case INOT:
				w_as_monadic_instruction (instruction,intel_asm ? "not" : "notl");
				break;
			case ICLZB:
				w_as_clzb_instruction (instruction);
				break;
			case IADC:
				w_as_dyadic_instruction (instruction,intel_asm ? "adc" : "adcl");
				break;
			case ISBB:
				w_as_dyadic_instruction (instruction,intel_asm ? "sbb" : "sbbl");
				break;
			case IMULUD:
				w_as_mulud_instruction (instruction);
				break;
			case IDIVDU:
				w_as_divdu_instruction (instruction);
				break;
			case IFLOORDIV:
				w_as_floordiv_mod_instruction (instruction,0);
				break;
			case IMOD:
				w_as_floordiv_mod_instruction (instruction,1);
				break;
			case IROTL:
				w_as_shift_instruction (instruction,"rol");
				break;
			case IROTR:
				w_as_shift_instruction (instruction,"ror");
				break;
			case IROTL_S:
				w_as_shift_s_instruction (instruction,"rol");
				break;
			case IROTR_S:
				w_as_shift_s_instruction (instruction,"ror");
				break;
			case IFMOVE:
				instruction=w_as_fmove_instruction (instruction);
				break;
			case IFADD:
				w_as_dyadic_float_instruction (instruction,"fadd","fadd");
				break;
			case IFSUB:
# ifdef FSUB_FDIV_REVERSED
				if (instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
					w_as_dyadic_float_instruction (instruction,"fsubr","fsub");
				else
# endif
					w_as_dyadic_float_instruction (instruction,"fsub","fsubr");
				break;
			case IFCMP:
				w_as_compare_float_instruction (instruction,"fcom","fcomp");
				break;
			case IFDIV:
# ifdef FSUB_FDIV_REVERSED
				if (instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
					w_as_dyadic_float_instruction (instruction,"fdivr","fdiv");
				else
# endif
					w_as_dyadic_float_instruction (instruction,"fdiv","fdivr");
				break;
			case IFMUL:
				w_as_dyadic_float_instruction (instruction,"fmul","fmul");
				break;
			case IFMOVEL:
				w_as_fmovel_instruction (instruction);
				break;
			case IFLOADS:
				instruction=w_as_floads_instruction (instruction);
				break;
			case IFMOVES:
				instruction=w_as_fmoves_instruction (instruction);
				break;
			case IFSQRT:
				w_as_monadic_float_instruction (instruction,"fsqrt");
				break;
			case IFNEG:
				w_as_monadic_float_instruction (instruction,"fchs");
				break;
			case IFABS:
				w_as_monadic_float_instruction (instruction,"fabs");
				break;
			case IFSIN:
				w_as_monadic_float_instruction (instruction,"fsin");
				break;
			case IFCOS:
				w_as_monadic_float_instruction (instruction,"fcos");
				break;
			case IFSEQ:
				w_as_set_float_condition_instruction (instruction,0);
				break;
			case IFSGE:
				w_as_set_float_condition_instruction (instruction,5);
				break;
			case IFSGT:
				w_as_set_float_condition_instruction (instruction,2);
				break;
			case IFSLE:
				w_as_set_float_condition_instruction (instruction,4);
				break;
			case IFSLT:
				w_as_set_float_condition_instruction (instruction,1);
				break;
			case IFSNE:
				w_as_set_float_condition_instruction (instruction,3);
				break;
			case IFCEQ:
				w_as_convert_float_condition_instruction (instruction,0);
				break;
			case IFCGE:
				w_as_convert_float_condition_instruction (instruction,5);
				break;
			case IFCGT:
				w_as_convert_float_condition_instruction (instruction,2);
				break;
			case IFCLE:
				w_as_convert_float_condition_instruction (instruction,4);
				break;
			case IFCLT:
				w_as_convert_float_condition_instruction (instruction,1);
				break;
			case IFCNE:
				w_as_convert_float_condition_instruction (instruction,3);
				break;
			case IWORD:
				w_as_word_instruction (instruction);
				break;
			case IRTSI:
				w_as_rtsi_instruction (instruction);
				break;
#ifdef FP_STACK_OPTIMIZATIONS
			case IFEXG:
				w_as_fexg (instruction);
				break;
#endif
			case IFSINCOS:
				w_as_fsincos_instruction (instruction);
				break;
#ifdef THREAD32
			case ILDTLSP:
				w_as_ldtlsp_instruction (instruction);
				break;
#endif
			case IFTST:
			default:
				internal_error_in_function ("w_as_instructions");
		}
		instruction=instruction->instruction_next;
	}
}

static void w_as_number_of_arguments (int n_node_arguments)
{
	w_as_opcode (intel_asm ? "dd" : ".long");
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

	n_cells=block->block_n_new_heap_cells;	

	label_id_1=next_label_id++;
	label_id_2=next_label_id++;
	
	new_call_and_jump=allocate_memory_from_heap (sizeof (struct call_and_jump));

	new_call_and_jump->cj_next=NULL;
	new_call_and_jump->cj_label_id=label_id_1;
	new_call_and_jump->cj_jump_id=label_id_2;

	switch (block->block_n_begin_a_parameter_registers){
		case 0:
			if (n_cells<=8)
				new_call_and_jump->cj_call_label_name="collect_0";
			else
				new_call_and_jump->cj_call_label_name="collect_0l";
			break;
		case 1:
			if (n_cells<=8)
				new_call_and_jump->cj_call_label_name="collect_1";
			else
				new_call_and_jump->cj_call_label_name="collect_1l";
			break;
		case 2:
			if (n_cells<=8)
				new_call_and_jump->cj_call_label_name="collect_2";
			else
				new_call_and_jump->cj_call_label_name="collect_2l";
			break;
		default:
			internal_error_in_function ("w_as_garbage_collect_test");
			return;
	}

	if (first_call_and_jump!=NULL)
		last_call_and_jump->cj_next=new_call_and_jump;
	else
		first_call_and_jump=new_call_and_jump;
	last_call_and_jump=new_call_and_jump;

#ifdef THREAD32
	w_as_opcode_movl();
	if (intel_asm)
		w_as_register_comma (HEAP_POINTER);
	w_as_indirect (0,REGISTER_A4);
	if (!intel_asm)
		w_as_comma_register (HEAP_POINTER);
	w_as_newline();
#endif

	if (n_cells<=8){
		w_as_opcode (intel_asm ? "cmp" : "cmpl");
		if (intel_asm){
			w_as_register_comma (HEAP_POINTER);
			fprintf (assembly_file,"dword ptr ");
		}
#ifndef THREAD32
		fprintf (assembly_file,"end_heap");
#else
		w_as_indirect (4,REGISTER_A4);
#endif
		if (!intel_asm)
			w_as_comma_register (HEAP_POINTER);
		w_as_newline();	
	} else {
#ifndef THREAD32
		w_as_opcode ("lea");
		if (intel_asm)
			w_as_scratch_register_comma();
		w_as_indirect ((n_cells-8)<<2,HEAP_POINTER);
		if (!intel_asm)
			w_as_comma_scratch_register();
		w_as_newline();
#else
		w_as_opcode (intel_asm ? "add" : "addl");
		w_as_immediate_register_newline ((n_cells-8)<<2,HEAP_POINTER);
#endif

		w_as_opcode (intel_asm ? "cmp" : "cmpl");
		if (intel_asm){
			w_as_scratch_register_comma();
			fprintf (assembly_file,"dword ptr ");
		}
#ifndef THREAD32
		fprintf (assembly_file,"end_heap");
#else
		w_as_indirect (4,REGISTER_A4);
#endif
		if (!intel_asm)
			w_as_comma_scratch_register();
		w_as_newline();		
	}
	w_as_opcode ("jae");
	
	w_as_internal_label (label_id_1);
	w_as_newline ();
	
	w_as_define_internal_label (label_id_2);

#ifdef THREAD32
	if (n_cells>8){
		w_as_opcode_movl();
		if (intel_asm)
			w_as_register_comma (HEAP_POINTER);
		w_as_indirect (0,REGISTER_A4);
		if (!intel_asm)
			w_as_comma_register (HEAP_POINTER);
		w_as_newline();
	}
#endif
}

static void w_as_call_and_jump (struct call_and_jump *call_and_jump)
{
	w_as_define_internal_label (call_and_jump->cj_label_id);

	w_as_opcode ("call");
	w_as_label (call_and_jump->cj_call_label_name);
	w_as_newline();
	
	w_as_opcode ("jmp");
	w_as_internal_label (call_and_jump->cj_jump_id);
	w_as_newline();
}

static void w_as_labels (register struct block_label *labels)
{
	for (; labels!=NULL; labels=labels->block_label_next)
		if (labels->block_label_label->label_number==0)
			w_as_define_code_label (labels->block_label_label);
		else
			w_as_define_local_label (labels->block_label_label->label_number);
}

static void w_as_check_stack (struct basic_block *block)
{
	if (block->block_a_stack_check_size>0){
		if (block->block_a_stack_check_size<=32){
			w_as_opcode (intel_asm ? "cmp" : "cmpl");
			if (intel_asm)
				w_as_register_comma (A_STACK_POINTER);
			fputs (end_a_stack_label->label_name,assembly_file);
			if (!intel_asm)
				w_as_comma_register (A_STACK_POINTER);
		} else {
			w_as_opcode (intel_asm ? "lea" : "leal");
			if (intel_asm)
				w_as_scratch_register_comma();
			w_as_indirect (block->block_a_stack_check_size,A_STACK_POINTER);
			if (!intel_asm)
				w_as_comma_scratch_register();
			w_as_newline();

			w_as_opcode (intel_asm ? "cmp" : "cmpl");
			if (intel_asm)
				w_as_scratch_register_comma();
			fputs (end_a_stack_label->label_name,assembly_file);
			if (!intel_asm)
				w_as_comma_scratch_register();
		}
		w_as_newline();	

		w_as_opcode ("jae");
		w_as_label (stack_overflow_label->label_name);
		w_as_newline();
	}

	if (block->block_b_stack_check_size>0){
		if (block->block_b_stack_check_size<=32){
			w_as_opcode (intel_asm ? "cmp" : "cmpl");
			if (intel_asm)
				w_as_register_comma (B_STACK_POINTER);
			fputs (end_b_stack_label->label_name,assembly_file);
			if (!intel_asm)
				w_as_comma_register (B_STACK_POINTER);
		} else {
			w_as_opcode (intel_asm ? "lea" : "leal");
			if (intel_asm)
				w_as_scratch_register_comma();
			w_as_indirect (block->block_b_stack_check_size,B_STACK_POINTER);
			if (!intel_asm)
				w_as_comma_scratch_register();
			w_as_newline();

			w_as_opcode (intel_asm ? "cmp" : "cmpl");
			if (intel_asm)
				w_as_scratch_register_comma();
			fputs (end_b_stack_label->label_name,assembly_file);
			if (!intel_asm)
				w_as_comma_scratch_register();
		}
		w_as_newline();

		w_as_opcode ("jb");
		w_as_label (stack_overflow_label->label_name);
		w_as_newline();
	}
}

void initialize_write_assembly (FILE *ass_file)
{
	assembly_file=ass_file;
	
	in_data_section=0;

	first_call_and_jump=NULL;
#ifndef THREAD32
	int_to_real_scratch_imported=0;
#endif

	if (intel_asm){
		w_as_opcode (".486");
		w_as_newline();
	
		w_as_opcode (".model");
		fprintf (assembly_file,"flat");
		w_as_newline();
	}
}

#if 0
static void w_as_indirect_node_entry_jump (LABEL *label)
{
	register char *new_label_name;

	new_label_name=fast_memory_allocate (strlen (label->label_name)+1+2);
	strcpy (new_label_name,"j_");
	strcat (new_label_name,label->label_name);

	w_as_align (2);

	if (label->label_flags & EA_LABEL){
		int label_arity;
		extern LABEL *eval_fill_label,*eval_upd_labels[];
	
		label_arity=label->label_arity;
		
		if (label_arity<-2)
			label_arity=1;
		
		if (label_arity>=0 && label->label_ea_label!=eval_fill_label){
			w_as_opcode_movl();
			w_as_immediate_label (eval_upd_labels[label_arity]->label_name);
			w_as_comma();
			w_as_register (REGISTER_D0);
			w_as_newline();
	
			w_as_opcode_movl();
			w_as_immediate_label (label->label_ea_label->label_name);
			w_as_comma();
			w_as_register (REGISTER_A2);
			w_as_newline();
			
			w_as_opcode ("jmp");
			w_as_register (REGISTER_D0);
			w_as_newline();
		} else {
			w_as_opcode_movl();
			w_as_immediate_label (label->label_ea_label->label_name);
			w_as_comma();
			w_as_register (REGISTER_D0);
			w_as_newline();
			
			w_as_opcode ("jmp");
			w_as_register (REGISTER_D0);
			w_as_newline();
		
			w_as_space (5);
		}
			
		if (label->label_arity<0 || parallel_flag || module_info_flag){
			LABEL *descriptor_label;
			
			descriptor_label=label->label_descriptor;

			if (descriptor_label->label_id<0)
				descriptor_label->label_id=next_label_id++;
	
			w_as_label_in_code_section (descriptor_label->label_name);
		} else
			w_as_number_of_arguments (0);
	} else
	if (label->label_arity<0 || parallel_flag || module_info_flag){
		LABEL *descriptor_label;

		descriptor_label=label->label_descriptor;

		if (descriptor_label->label_id<0)
			descriptor_label->label_id=next_label_id++;

		w_as_label_in_code_section (descriptor_label->label_name);
	}

	w_as_number_of_arguments (label->label_arity);
	
	w_as_define_label_name (new_label_name);
	
	w_as_opcode ("jmp");
	w_as_label (label->label_name);
	w_as_newline();
	
	label->label_name=new_label_name;
}

static void w_as_indirect_node_entry_jumps (register struct label_node *label_node)
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
#endif

extern LABEL *eval_fill_label,*eval_upd_labels[];

static void w_as_import_labels (struct label_node *label_node)
{
	LABEL *label;
	
	if (label_node==NULL)
		return;
	
	label=&label_node->label_node_label;
	
	if (!(label->label_flags & LOCAL_LABEL) && label->label_number==0){
		w_as_opcode ("extrn");
		fprintf (assembly_file,"%s:near",label->label_name);
		w_as_newline();
	}
	
	w_as_import_labels (label_node->label_node_left);
	w_as_import_labels (label_node->label_node_right);
}

static void w_as_node_entry_info (struct basic_block *block)
{
	if (block->block_ea_label!=NULL){
		int n_node_arguments;

		n_node_arguments=block->block_n_node_arguments;
		if (n_node_arguments<-2)
			n_node_arguments=1;

		if (n_node_arguments>=0 && block->block_ea_label!=eval_fill_label){
#if 1
			if (!block->block_profile){
				w_as_opcode_movl();
				if (intel_asm)
					w_as_register_comma (REGISTER_A2);
				w_as_immediate_label (block->block_ea_label->label_name);
				if (!intel_asm)
					w_as_comma_register (REGISTER_A2);
				w_as_newline();

				w_as_opcode ("jmp");
				w_as_label (eval_upd_labels[n_node_arguments]->label_name);
				w_as_newline();

				w_as_instruction_without_parameters ("nop");
				w_as_instruction_without_parameters ("nop");
			} else {
				w_as_opcode ("jmp");
				w_as_label (eval_upd_labels[n_node_arguments]->label_name);
				fprintf (assembly_file,"-7");
				w_as_newline();						

				w_as_instruction_without_parameters ("nop");
				w_as_instruction_without_parameters ("nop");
				w_as_instruction_without_parameters ("nop");

				w_as_opcode_movl();
				if (intel_asm)
					w_as_register_comma (REGISTER_D0);
				w_as_immediate_label (block->block_ea_label->label_name);
				if (!intel_asm)
					w_as_comma_register (REGISTER_D0);
				w_as_newline();

				w_as_opcode_movl();
				if (intel_asm)
					w_as_register_comma (REGISTER_A2);
				w_as_descriptor (block->block_profile_function_label,0);
				if (!intel_asm)
					w_as_comma_register (REGISTER_A2);
				w_as_newline();

				w_as_opcode ("jmp");
				fprintf (assembly_file,".-18");
				w_as_newline();
			}
#else
			w_as_opcode_movl();
			if (intel_asm)
				w_as_register_comma (REGISTER_D0);
			w_as_immediate_label (eval_upd_labels[n_node_arguments]->label_name);
			if (!intel_asm)
				w_as_comma_register (REGISTER_D0);
			w_as_newline();

			w_as_opcode_movl();
			if (intel_asm)
				w_as_register_comma (REGISTER_A2);
			w_as_immediate_label (block->block_ea_label->label_name);
			if (!intel_asm)
				w_as_comma_register (REGISTER_A2);
			w_as_newline();
		
			w_as_opcode ("jmp");
			w_as_register (REGISTER_D0);
			w_as_newline();
#endif
		} else {
			w_as_opcode_movl();
			if (intel_asm)
				w_as_register_comma (REGISTER_D0);
			w_as_immediate_label (block->block_ea_label->label_name);
			if (!intel_asm)
				w_as_comma_register (REGISTER_D0);
			w_as_newline();
		
			w_as_opcode ("jmp");
			w_as_register (REGISTER_D0);
			w_as_newline();
		
			w_as_space (5);
		}
		
		if (block->block_descriptor!=NULL && (block->block_n_node_arguments<0 || parallel_flag || module_info_flag))
			w_as_label_in_code_section (block->block_descriptor->label_name);
		else
			w_as_number_of_arguments (0);
	} else
	if (block->block_descriptor!=NULL && (block->block_n_node_arguments<0 || parallel_flag || module_info_flag))
		w_as_label_in_code_section (block->block_descriptor->label_name);

	if (callgraph_profiling && block->block_n_node_arguments>=0){
		if (block->block_descriptor && block->block_descriptor->label_name!=NULL && !strcmp (block->block_descriptor->label_name,"EMPTY"))
			w_as_number_of_arguments (0);
		else
			w_as_number_of_arguments (block->block_n_node_arguments+257);
	} else
		w_as_number_of_arguments (block->block_n_node_arguments);
}

static void w_as_profile_call (struct basic_block *block)
{
	w_as_opcode_movl();
	if (intel_asm)
		w_as_scratch_register_comma();
	w_as_descriptor (block->block_profile_function_label,0);
	if (!intel_asm)
		w_as_comma_scratch_register();
	w_as_newline();

	w_as_opcode ("call");
	
	if (block->block_n_node_arguments>-100)
		w_as_label (block->block_profile==2 ? "profile_n2" : "profile_n");
	else {
		switch (block->block_profile){
			case 2:  w_as_label ("profile_s2"); break;
			case 4:  w_as_label ("profile_l"); break;
			case 5:  w_as_label ("profile_l2"); break;
			default: w_as_label ("profile_s");
		}
	}
	w_as_newline();
}

#ifdef NEW_APPLY
extern LABEL *add_empty_node_labels[];

static void w_as_apply_update_entry (struct basic_block *block)
{
	int n_node_arguments;
		
	n_node_arguments=block->block_n_node_arguments;
	if (n_node_arguments<-200){
		w_as_opcode ("jmp");
		w_as_label (block->block_descriptor->label_name);
		w_as_newline();

		w_as_instruction_without_parameters ("nop");
		w_as_instruction_without_parameters ("nop");
		w_as_instruction_without_parameters ("nop");

		if (block->block_ea_label==NULL){
			if (block->block_profile)
				w_as_profile_call (block);

			w_as_instruction_without_parameters ("nop");
			w_as_instruction_without_parameters ("nop");
			w_as_instruction_without_parameters ("nop");
			w_as_instruction_without_parameters ("nop");
			w_as_instruction_without_parameters ("nop");
			w_as_instruction_without_parameters ("nop");
			w_as_instruction_without_parameters ("nop");
			w_as_instruction_without_parameters ("nop");
			w_as_instruction_without_parameters ("nop");
			w_as_instruction_without_parameters ("nop");		

			if (!block->block_profile){
				w_as_instruction_without_parameters ("nop");
				w_as_instruction_without_parameters ("nop");
			}
			return;
		}
		n_node_arguments+=300;
	} else
		n_node_arguments+=200;

	if (block->block_profile)
		w_as_profile_call (block);

	if (n_node_arguments==0){
		w_as_opcode ("jmp");
		w_as_label (block->block_ea_label->label_name);
		w_as_newline();

		w_as_instruction_without_parameters ("nop");
		w_as_instruction_without_parameters ("nop");
		w_as_instruction_without_parameters ("nop");
		w_as_instruction_without_parameters ("nop");
		w_as_instruction_without_parameters ("nop");
	} else {
		w_as_opcode ("call");
		w_as_label (add_empty_node_labels[n_node_arguments]->label_name);
		w_as_newline();

		w_as_opcode ("jmp");
		w_as_label (block->block_ea_label->label_name);
		w_as_newline();
	}
	
	if (!block->block_profile){
		w_as_instruction_without_parameters ("nop");
		w_as_instruction_without_parameters ("nop");
	}
}
#endif

void write_assembly (VOID)
{
	struct basic_block *block;
	struct call_and_jump *call_and_jump;

	if (intel_asm)
		w_as_import_labels (labels);

	w_as_to_code_section();

#ifdef DATA_IN_CODE_SECTION
	float_constant_l=&first_float_constant;
	first_float_constant=NULL;
#endif

	/*
	w_as_indirect_node_entry_jumps (labels);
	*/

	for_l (block,first_block,block_next){
		if (block->block_n_node_arguments>-100){
			w_as_align (2);
			w_as_node_entry_info (block);
		}
#ifdef NEW_APPLY
		else if (block->block_n_node_arguments<-100)
			w_as_apply_update_entry (block);
#endif

		w_as_labels (block->block_labels);

		if (block->block_profile)
			w_as_profile_call (block);

		if (block->block_n_new_heap_cells>0)
			w_as_garbage_collect_test (block);

		if (check_stack && (block->block_a_stack_check_size>0 || block->block_b_stack_check_size>0))
			w_as_check_stack (block);

		w_as_instructions (block->block_instructions);
	}

	for_l (call_and_jump,first_call_and_jump,cj_next)
		w_as_call_and_jump (call_and_jump);
	
#ifdef DATA_IN_CODE_SECTION
	write_float_constants();
#endif

	if (intel_asm){
		w_as_opcode ("end");
		w_as_newline();
	}
}
