/*
	File:	 cgtwas.c
	Author:  John van Groningen
	Machine: Thumb2
*/

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>

#include "cgport.h"
#include "cgrconst.h"
#include "cgtypes.h"
#include "cg.h"
#include "cgiconst.h"
#include "cgcode.h"
#include "cginstructions.h"
#include "cgarmas.h"
#include "cgarmwas.h"

#define for_l(v,l,n) for(v=(l);v!=NULL;v=v->n)

#define IO_BUF_SIZE 8192

#define FP_REVERSE_SUB_DIV_OPERANDS 1

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

static void w_as_define_local_data_label (int label_number)
{
	fprintf (assembly_file,"l_%d:\n",label_number);
}

static void w_as_define_internal_label (int label_number)
{
	fprintf (assembly_file,"i_%d:\n",label_number);
}

static void w_as_define_internal_data_label (int label_number)
{
	fprintf (assembly_file,"i_%d:\n",label_number);
}

void w_as_internal_label_value (int label_id)
{
	fprintf (assembly_file,"\t.long\ti_%d\n",label_id);
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
		w_as_instruction_without_parameters (".text");
	}
}

static void w_as_align (int i)
{
	fprintf (assembly_file,"\t.p2align\t%d\n",i);
}

static void w_as_space (int i)
{
	fprintf (assembly_file,"\t.space\t%d\n",i);
}

void w_as_word_in_data_section (int n)
{
	w_as_to_data_section();
	w_as_opcode (".hword");
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
	w_as_opcode (".long");
	fprintf (assembly_file,"%d",n);
	w_as_newline();
}

void w_as_label_in_data_section (char *label_name)
{
	w_as_to_data_section ();
	fprintf (assembly_file,"\t.long\t%s\n",label_name);
}

static void w_as_label_in_code_section (char *label_name)
{
	w_as_to_code_section ();
	fprintf (assembly_file,"\t.long\t%s\n",label_name);
}

void w_as_descriptor_in_data_section (char *label_name)
{
	w_as_to_data_section();
	w_as_align (2);
	fprintf (assembly_file,"\t.long\t%s+2\n",label_name);
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
	else
		n=w_as_zeros (n,4);
	if (n>0)
		w_as_newline();
}

void w_as_abc_string_in_data_section (char *string,int length)
{
	int n;
	
	w_as_to_data_section();
	
	w_as_opcode (".long");
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

	w_as_opcode (".long");
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

#define MAX_LITERAL_INSTRUCTION_OFFSET 1023
#define MAX_LITERAL_LDR_OFFSET 255

static unsigned int instruction_n_after_ltorg,ltorg_at_instruction_n;

static void w_as_local_label (int label_number)
{
	fprintf (assembly_file,"l_%d",label_number);
}

static void w_as_label_parameter (struct parameter *parameter_p)
{
	if (parameter_p->parameter_data.l->label_number!=0)
		w_as_local_label (parameter_p->parameter_data.l->label_number);
	else
		w_as_label (parameter_p->parameter_data.l->label_name);
}

static void w_as_immediate_label (LABEL *label)
{
	if (instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET < ltorg_at_instruction_n)
		ltorg_at_instruction_n = instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET;

	putc ('=',assembly_file);
	if (label->label_number!=0)
		w_as_local_label (label->label_number);
	else
		w_as_label (label->label_name);
}

static void w_as_immediate_label_name (char *label_name)
{
	if (instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET < ltorg_at_instruction_n)
		ltorg_at_instruction_n = instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET;

	putc ('=',assembly_file);
	w_as_label (label_name);
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
	w_as_colon();
	w_as_newline();
}

void w_as_define_label (LABEL *label)
{
	if (label->label_flags & EXPORT_LABEL){
		w_as_opcode (".globl");
		w_as_label (label->label_name);
		w_as_newline();
	}
	
	w_as_label (label->label_name);
	w_as_colon();
	w_as_newline();
}

static void w_as_define_code_label (LABEL *label)
{
	if (label->label_flags & EXPORT_LABEL){
		w_as_opcode (".globl");
		w_as_label (label->label_name);
		w_as_newline();
	}
	
	w_as_label (label->label_name);
	w_as_colon();
	w_as_newline();
}

static void w_as_internal_label (int label_number)
{
	fprintf (assembly_file,"i_%d",label_number);
}

static void w_as_immediate (LONG i)
{
	fprintf (assembly_file,"#%ld",i);
}

void w_as_abc_string_and_label_in_data_section (char *string,int length,char *label_name)
{
	int n;

	w_as_to_data_section();
	
	w_as_define_data_label_name (label_name);
	
	w_as_opcode (".long");
	fprintf (assembly_file,"%d\n",length);
	n=w_as_data (0,string,length);
	if (length & 3)
		n=w_as_zeros (n,4-(length & 3));
	if (n>0)
		w_as_newline();
}

static char *register_name[15]=
//	{"sp","r10","r9","r11","r8","r7","r6","r4","r3","r2","r1","r0","r5","r12","r14"};
	{"sp","r6","r5","r12","r4","r3","r2","r1","r0","r10","r9","r8","r11","r7","r14"};

#define REGISTER_S0 6
#define REGISTER_S1 7

static void w_as_indirect (int i,int reg)
{
	if (i==0)
		fprintf (assembly_file,"[%s]",register_name[reg+7]);
	else
		fprintf (assembly_file,"[%s,#%d]",register_name[reg+7],i);
}

static void w_as_indirect_with_update (int i,int reg)
{
	if (i==0)
		fprintf (assembly_file,"[%s]",register_name[reg+7]);
	else
		fprintf (assembly_file,"[%s,#%d]!",register_name[reg+7],i);
}

static void w_as_indirect_post_add (int i,int reg)
{
	if (i==0)
		fprintf (assembly_file,"[%s]",register_name[reg+7]);
	else
		fprintf (assembly_file,"[%s],#%d",register_name[reg+7],i);
}

static void w_as_register (int reg)
{
	fputs (register_name[reg+7],assembly_file);
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

static void w_as_indexed_no_offset (int offset,int reg1,int reg2)
{	
	int shift;

	shift=offset & 3;
	if (shift!=0)
		fprintf (assembly_file,"[%s,%s,lsl #%d]",register_name[reg1+7],register_name[reg2+7],shift);
	else
		fprintf (assembly_file,"[%s,%s]",register_name[reg1+7],register_name[reg2+7]);
}

struct float_constant {
	DOUBLE *				float_constant_r_p;
	int						float_constant_label_number;
	struct float_constant *	float_constant_next;
};

struct float_constant *first_float_constant,**float_constant_l;

static void write_float_constants (void)
{
	struct float_constant *float_constant;

	float_constant=first_float_constant;

	if (float_constant!=NULL){
		w_as_align (3);
		
		for (; float_constant!=NULL; float_constant=float_constant->float_constant_next){
			w_as_define_internal_data_label (float_constant->float_constant_label_number);
		
			w_as_opcode (".double");
			fprintf (assembly_file,"0r%.20e",*float_constant->float_constant_r_p);
			w_as_newline();		
		}

		float_constant_l=&first_float_constant;
		first_float_constant=NULL;
	}
}

static void w_as_newline_after_instruction (VOID)
{
	w_as_newline();
	++instruction_n_after_ltorg;
	if (instruction_n_after_ltorg>=ltorg_at_instruction_n){
		int label_id;
		
		label_id=next_label_id++;

		w_as_opcode ("b");
		w_as_internal_label (label_id);
		w_as_newline();
	
		write_float_constants();
		w_as_instruction_without_parameters (".ltorg");

		w_as_define_internal_label (label_id);

		instruction_n_after_ltorg = 0u;
		ltorg_at_instruction_n = 0u-1u;	
	}
}

static void w_as_indexed_no_offset_newline (int offset,int reg1,int reg2)
{
	w_as_indexed_no_offset (offset,reg1,reg2);
	w_as_newline_after_instruction();
}

static void w_as_indexed_no_offset_ir_newline (int offset,struct index_registers *index_registers)
{
	w_as_indexed_no_offset (offset,index_registers->a_reg.r,index_registers->d_reg.r);
	w_as_newline_after_instruction();
}

static void w_as_register_newline (int reg)
{
	w_as_register (reg);
	w_as_newline_after_instruction();
}

static void w_as_indirect_newline (int i,int reg)
{
	w_as_indirect (i,reg);
	w_as_newline_after_instruction();
}

static void w_as_indirect_with_update_newline (int i,int reg)
{
	w_as_indirect_with_update (i,reg);
	w_as_newline_after_instruction();
}

static void w_as_indirect_post_add_newline (int i,int reg)
{
	w_as_indirect_post_add (i,reg);
	w_as_newline_after_instruction();
}

static void w_as_immediate_newline (LONG i)
{
	fprintf (assembly_file,"#%ld",i);
	w_as_newline_after_instruction();
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
	fprintf (assembly_file,"r7");
}

static void w_as_scratch_register_comma (void)
{
	fprintf (assembly_file,"r7");
	w_as_comma();
}

static void w_as_comma_scratch_register (void)
{
	w_as_comma();
	fprintf (assembly_file,"r7");
}

static void w_as_comma_scratch_register_newline (void)
{
	w_as_comma();
	fprintf (assembly_file,"r7");
	w_as_newline_after_instruction();
}

static void w_as_fp_register (int fp_reg)
{
	fprintf (assembly_file,"d%d",fp_reg);
}

static void w_as_fp_register_comma (int fp_reg)
{
	fprintf (assembly_file,"d%d,",fp_reg);
}

static void w_as_fp_register_newline (int fp_reg)
{
	fprintf (assembly_file,"d%d",fp_reg);
	w_as_newline_after_instruction();
}

static void w_as_descriptor (LABEL *label,int arity)
{
	if (instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET < ltorg_at_instruction_n)
		ltorg_at_instruction_n = instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET;

	putc ('=',assembly_file);
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

static int mov_or_mov_neg_immediate (unsigned int i)
{
	if ((i & ~0xff)==0)
		return 1;
	if ((i & ~(0xff000000>>__builtin_clz (i)))==0)
		return 1;
	if ((i>>16)==(i & 0xffff)){
		if ((i & ~0x00ff00ff)==0)
			return 1;
		if ((i & ~0xff00ff00)==0)
			return 1;
		if (((i>>8) & 0xff)==(i & 0xff))
			return 1;
	}

	i = -i;

	if ((i & ~0xff)==0)
		return 1;
	if ((i & ~(0xff000000>>__builtin_clz (i)))==0)
		return 1;
	if ((i>>16)==(i & 0xffff)){
		if ((i & ~0x00ff00ff)==0)
			return 1;
		if ((i & ~0xff00ff00)==0)
			return 1;
		if (((i>>8) & 0xff)==(i & 0xff))
			return 1;
	}
	
	return 0;
}

static int mov_or_mov_not_immediate (unsigned int i)
{
	if ((i & ~0xff)==0)
		return 1;
	if ((i & ~(0xff000000>>__builtin_clz (i)))==0)
		return 1;
	if ((i>>16)==(i & 0xffff)){
		if ((i & ~0x00ff00ff)==0)
			return 1;
		if ((i & ~0xff00ff00)==0)
			return 1;
		if (((i>>8) & 0xff)==(i & 0xff))
			return 1;
	}

	i = ~i;

	if ((i & ~0xff)==0)
		return 1;
	if ((i & ~(0xff000000>>__builtin_clz (i)))==0)
		return 1;
	if ((i>>16)==(i & 0xffff)){
		if ((i & ~0x00ff00ff)==0)
			return 1;
		if ((i & ~0xff00ff00)==0)
			return 1;
		if (((i>>8) & 0xff)==(i & 0xff))
			return 1;
	}
	
	return 0;
}

static void w_as_opcode_mov (void)
{
	w_as_opcode ("mov");
}

static void w_as_opcode_ldr (void)
{
	w_as_opcode ("ldr");
}

static void w_as_opcode_ldr_register_comma (int reg1)
{
	w_as_opcode ("ldr");
	w_as_register_comma (reg1);
}

static void w_as_opcode_load (int size_flag)
{
	w_as_opcode (size_flag==SIZE_LONG ? "ldr" : size_flag==SIZE_WORD ? "ldrsh" : "ldrb");
}

static void w_as_opcode_str (void)
{
	w_as_opcode ("str");
}

static void w_as_opcode_str_register_comma (int reg1)
{
	w_as_opcode ("str");
	w_as_register_comma (reg1);
}

static void w_as_ld_indexed (struct parameter *parameter_p,int dreg,int size_flag)
{
	int offset;

	offset=parameter_p->parameter_offset;
	if ((offset & -4)!=0){
		int reg1,reg2;
	
		reg1=parameter_p->parameter_data.ir->a_reg.r;
		reg2=parameter_p->parameter_data.ir->d_reg.r;

		w_as_opcode ("add");
		w_as_scratch_register_comma();	
		w_as_register_comma (reg1);
		w_as_immediate_newline (offset>>2);

		w_as_opcode_load (size_flag);
		w_as_register_comma (dreg);
		w_as_indexed_no_offset_newline (offset,REGISTER_S0,reg2);
	} else {
		w_as_opcode_load (size_flag);
		w_as_register_comma (dreg);
		w_as_indexed_no_offset_ir_newline (offset,parameter_p->parameter_data.ir);
	}
}

static int w_as_register_parameter (struct parameter *parameter_p)
{
	switch (parameter_p->parameter_type){
		case P_REGISTER:
			return parameter_p->parameter_data.reg.r;
		case P_LABEL:
			w_as_opcode_ldr();
			w_as_scratch_register_comma();
			w_as_immediate_label (parameter_p->parameter_data.l);
			w_as_newline_after_instruction();
			return REGISTER_S0;
		case P_IMMEDIATE:
		{
			int i;

			i=parameter_p->parameter_data.i;
			if (mov_or_mov_not_immediate (i)){
				w_as_opcode_mov();
				w_as_scratch_register_comma();
				w_as_immediate_newline (i);
			} else {
				if (instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET < ltorg_at_instruction_n)
					ltorg_at_instruction_n = instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET;

				w_as_opcode_ldr();
				w_as_scratch_register_comma();
				fprintf (assembly_file,"=%d",i);	
				w_as_newline_after_instruction();
			}
			return REGISTER_S0;
		}
		case P_INDIRECT:
			w_as_opcode_ldr();
			w_as_scratch_register_comma();
			w_as_indirect_newline (parameter_p->parameter_offset,parameter_p->parameter_data.reg.r);
			return REGISTER_S0;
		case P_INDEXED:
			w_as_ld_indexed (parameter_p,REGISTER_S0,SIZE_LONG);
			return REGISTER_S0;
		case P_INDIRECT_WITH_UPDATE:
			w_as_opcode_ldr();
			w_as_scratch_register_comma;
			w_as_indirect_with_update_newline (parameter_p->parameter_offset,parameter_p->parameter_data.reg.r);
			return REGISTER_S0;
		case P_PRE_DECREMENT:
			w_as_opcode_ldr();
			w_as_scratch_register_comma();
			fprintf (assembly_file,"[sp,#-4]");
			w_as_newline_after_instruction();
			return REGISTER_S0;
		case P_POST_INCREMENT:
			w_as_opcode ("pop");
			fprintf (assembly_file,"{");
			w_as_scratch_register();
			fprintf (assembly_file,"}");
			w_as_newline_after_instruction();
			return REGISTER_S0;
		case P_INDIRECT_POST_ADD:
			w_as_opcode_ldr();
			w_as_scratch_register_comma();
			w_as_indirect_post_add_newline (parameter_p->parameter_offset,parameter_p->parameter_data.reg.r);
			return REGISTER_S0;
		case P_F_REGISTER:
			w_as_opcode_ldr();
			w_as_scratch_register_comma();
			fprintf (assembly_file,"%%st(%d)",parameter_p->parameter_data.reg.r<<1);
			w_as_newline_after_instruction();
			return REGISTER_S0;
		default:
			internal_error_in_function ("w_as_register_parameter");
	}
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
				fprintf (assembly_file,"%d(%%%s)",offset,register_name[reg+7]);
			else
				fprintf (assembly_file,"(%%%s)",register_name[reg+7]);
			break;
		}
		case P_REGISTER:
		{
			int reg;

			reg=parameter->parameter_data.reg.r;

			fprintf (assembly_file,"%s",register_name[reg+7]);
			break;
		}
		default:
			internal_error_in_function ("w_as_jump_parameter");
	}
}

static void w_as_opcode_store (int size_flag)
{
	w_as_opcode (size_flag==SIZE_LONG ? "str" : size_flag==SIZE_WORD ? "strh" : "strb");
}

static void w_as_register_register_newline (int reg1,int reg2)
{
	w_as_register_comma (reg1);
	w_as_register (reg2);
	w_as_newline_after_instruction();
}

static void w_as_opcode_register_newline (char *opcode,int reg1)
{
	w_as_opcode (opcode);
	w_as_register (reg1);
	w_as_newline_after_instruction();
}

static void w_as_ldrd_register_register_comma (int reg1,int reg2)
{
	w_as_opcode ("ldrd");
	w_as_register_comma (reg1);
	w_as_register_comma (reg2);
}

static void w_as_strd_register_register_comma (int reg1,int reg2)
{
	w_as_opcode ("strd");
	w_as_register_comma (reg1);
	w_as_register_comma (reg2);
}

static void w_as_opcode_register_register_newline (char *opcode,int reg1,int reg2)
{
	w_as_opcode (opcode);
	w_as_register_register_newline (reg1,reg2);
}

static void w_as_mov_register_register_newline (int reg1,int reg2)
{
	w_as_opcode_mov();
	w_as_register_register_newline (reg1,reg2);
}

static void w_as_immediate_register_newline (int i,int reg)
{
	w_as_immediate (i);
	w_as_comma_register (reg);
	w_as_newline_after_instruction();
}

static void w_as_ld_large_immediate (int i,int reg)
{
	if (instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET < ltorg_at_instruction_n)
		ltorg_at_instruction_n = instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET;

	w_as_opcode_ldr();
	w_as_register_comma (reg);
	fprintf (assembly_file,"=%d",i);	
	w_as_newline_after_instruction();
}

static void w_as_ld_immediate (int i,int reg)
{
	if (mov_or_mov_not_immediate (i)){
		w_as_opcode_mov();
		w_as_register_comma (reg);
		w_as_immediate_newline (i);
	} else if ((i & ~0xffff)==0){
		w_as_opcode ("movw");
		w_as_register_comma (reg);
		w_as_immediate_newline (i);
	} else
		w_as_ld_large_immediate (i,reg);
}

static void w_as_lsl_register_newline (int reg,int shift)
{
	w_as_register (reg);
	if (shift!=0)
		fprintf (assembly_file,",lsl #%d",shift);
	w_as_newline_after_instruction();
}

#define reg_num(r) (real_reg_num[(r)+7])

static unsigned char real_reg_num [16]
//	= { 13, 10, 9, 11, 8, 7, 6, 4, 3, 2, 1, 0, 5, 12, 14, 15 };
	= { 13,  6, 5, 12, 4, 3, 2, 1, 0,10, 9, 8,11,  7, 14, 15 };

static void w_as_pop_r (int d_reg)
{
	int d_reg_n;
	
	d_reg_n=reg_num (d_reg);
	if (d_reg_n<8 || d_reg_n==15){
		w_as_opcode ("pop");
		fprintf (assembly_file,"{");
		w_as_register (d_reg);
		fprintf (assembly_file,"}");
		w_as_newline_after_instruction();
	} else {
		w_as_opcode_ldr();	
		w_as_register (d_reg);
		fprintf (assembly_file,",[sp],#4");
		w_as_newline_after_instruction();		
	}
}

static void w_as_push_r (int s_reg)
{
	int s_reg_n;
	
	s_reg_n=reg_num (s_reg);
	if (s_reg_n<8 || s_reg_n==14){
		w_as_opcode ("push");
		fprintf (assembly_file,"{");
		w_as_register (s_reg);
		fprintf (assembly_file,"}");
		w_as_newline_after_instruction();
	} else {
		w_as_opcode_str();	
		w_as_register (s_reg);
		fprintf (assembly_file,",[sp,#-4]!");
		w_as_newline_after_instruction();	
	}
}

static void w_as_ldr_ldr_or_ldrd (int offset1,int a_reg1,int d_reg1,int offset2,int a_reg2,int d_reg2)
{
#ifndef NO_LDRD
	if (a_reg1==a_reg2 && d_reg1!=a_reg1 && (offset1 & 3)==0 && d_reg1!=B_STACK_POINTER && d_reg2!=B_STACK_POINTER){
		if (offset2==offset1+4){
			if (offset1>=-1020 && offset1<=1020){
				w_as_ldrd_register_register_comma (d_reg1,d_reg2);
				w_as_indirect_newline (offset1,a_reg1);
				return;
			}
		} else if (offset2==offset1-4){
			if (offset2>=-1020 && offset2<=1020){
				w_as_ldrd_register_register_comma (d_reg2,d_reg1);
				w_as_indirect_newline (offset2,a_reg1);
				return;
			}
		}
	}
#endif

	w_as_opcode_ldr_register_comma (d_reg1);
	w_as_indirect_newline (offset1,a_reg1);

	w_as_opcode_ldr_register_comma (d_reg2);
	w_as_indirect_newline (offset2,a_reg2);
}

#ifndef NO_STRD
static struct instruction *w_as_str_or_strd_id (struct instruction *instruction,struct parameter *d_parameter_p,int s_reg)
{
	struct instruction *next_instruction;
	int a_reg,offset;

	next_instruction=instruction->instruction_next;
	offset=d_parameter_p->parameter_offset;
	a_reg=d_parameter_p->parameter_data.reg.r;

	if (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
		(offset & 3)==0 && s_reg!=B_STACK_POINTER
	){
		if (next_instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
			next_instruction->instruction_parameters[1].parameter_data.reg.r==a_reg
		){
			if (next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
				next_instruction->instruction_parameters[0].parameter_data.reg.r!=B_STACK_POINTER
			){
				/* str str */
				if (next_instruction->instruction_parameters[1].parameter_offset==offset+4){
					if (offset>=-1020 && offset<=1020){
						w_as_strd_register_register_comma (s_reg,next_instruction->instruction_parameters[0].parameter_data.reg.r);
						w_as_indirect_newline (offset,a_reg);
						return next_instruction;
					}
				} else if (next_instruction->instruction_parameters[1].parameter_offset==offset-4){
					if (offset-4>=-1020 && offset-4<=1020){
						w_as_strd_register_register_comma (next_instruction->instruction_parameters[0].parameter_data.reg.r,s_reg);
						w_as_indirect_newline (offset-4,a_reg);
						return next_instruction;
					}
				}
			}

			if (next_instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
				int la_reg;
				
				la_reg = next_instruction->instruction_parameters[0].parameter_data.reg.r;
				if (la_reg==a_reg
					? (next_instruction->instruction_parameters[0].parameter_offset+4<=offset ||
					   next_instruction->instruction_parameters[0].parameter_offset>=offset+4)
					: (a_reg!=REGISTER_S0 &&
					   (la_reg==A_STACK_POINTER || la_reg==B_STACK_POINTER || a_reg==A_STACK_POINTER || a_reg==B_STACK_POINTER))
				){
					/* str ldr->str */
					if (next_instruction->instruction_parameters[1].parameter_offset==offset+4){
						if (offset>=-1020 && offset<=1020){
							int s_reg2;
							
							s_reg2 = s_reg!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

							w_as_opcode_ldr_register_comma (s_reg2);
							w_as_indirect_newline (next_instruction->instruction_parameters[0].parameter_offset,la_reg);

							w_as_strd_register_register_comma (s_reg,s_reg2);
							w_as_indirect_newline (offset,a_reg);
							return next_instruction;
						}
					} else if (next_instruction->instruction_parameters[1].parameter_offset==offset-4){
						if (offset-4>=-1020 && offset-4<=1020){
							int s_reg2;
							
							s_reg2 = s_reg!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

							w_as_opcode_ldr_register_comma (s_reg2);
							w_as_indirect_newline (next_instruction->instruction_parameters[0].parameter_offset,la_reg);

							w_as_strd_register_register_comma (s_reg2,s_reg);
							w_as_indirect_newline (offset-4,a_reg);
							return next_instruction;
						}
					}															
				}
			}

			if (next_instruction->instruction_parameters[0].parameter_type==P_DESCRIPTOR_NUMBER){
				if (a_reg!=REGISTER_S0){
					/* str ldr_descr->str */
					if (next_instruction->instruction_parameters[1].parameter_offset==offset+4){
						if (offset>=-1020 && offset<=1020){
							int s_reg2;
							
							s_reg2 = s_reg!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

							w_as_opcode_ldr_register_comma (s_reg2);
							w_as_descriptor (next_instruction->instruction_parameters[0].parameter_data.l,
											 next_instruction->instruction_parameters[0].parameter_offset);
							w_as_newline_after_instruction();

							w_as_strd_register_register_comma (s_reg,s_reg2);
							w_as_indirect_newline (offset,a_reg);
							return next_instruction;
						}
					} else if (next_instruction->instruction_parameters[1].parameter_offset==offset-4){
						if (offset-4>=-1020 && offset-4<=1020){
							int s_reg2;
							
							s_reg2 = s_reg!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

							w_as_opcode_ldr_register_comma (s_reg2);
							w_as_descriptor (next_instruction->instruction_parameters[0].parameter_data.l,
											 next_instruction->instruction_parameters[0].parameter_offset);
							w_as_newline_after_instruction();

							w_as_strd_register_register_comma (s_reg2,s_reg);
							w_as_indirect_newline (offset-4,a_reg);
							return next_instruction;
						}
					}															
				}
			}
		}

		if (offset==4 && next_instruction->instruction_parameters[1].parameter_type==P_INDIRECT_POST_ADD &&
			next_instruction->instruction_parameters[1].parameter_data.reg.r==a_reg &&
			next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
			next_instruction->instruction_parameters[0].parameter_data.reg.r!=B_STACK_POINTER &&
			(next_instruction->instruction_parameters[1].parameter_offset & 3)==0 &&
			next_instruction->instruction_parameters[1].parameter_offset>=-1020 &&
			next_instruction->instruction_parameters[1].parameter_offset<=1020
		){
			int s_reg2;

			s_reg2=next_instruction->instruction_parameters[0].parameter_data.reg.r;

			if (next_instruction->instruction_parameters[1].parameter_offset==8 &&
				reg_num (a_reg)<8 && reg_num (s_reg)<8 && reg_num (s_reg2)<reg_num (s_reg)
			){
				w_as_opcode ("stmia");
				w_as_register (a_reg);
				fprintf (assembly_file,"!,{");
				w_as_register (s_reg2);
				w_as_comma_register (s_reg);
				fprintf (assembly_file,"}");
				w_as_newline_after_instruction();
				return next_instruction;
			} 

			/* str str,# */
			w_as_strd_register_register_comma (s_reg2,s_reg);
			w_as_indirect_post_add_newline (next_instruction->instruction_parameters[1].parameter_offset,a_reg);
			return next_instruction;
		}

		if (next_instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
			next_instruction->instruction_parameters[0].parameter_data.reg.r==a_reg &&
			next_instruction->instruction_parameters[1].parameter_type==P_REGISTER &&
			next_instruction->instruction_parameters[1].parameter_data.reg.r!=a_reg &&
			next_instruction->instruction_parameters[1].parameter_data.reg.r!=s_reg &&
			next_instruction->instruction_parameters[1].parameter_data.reg.r!=B_STACK_POINTER
		){
			struct instruction *next_next_instruction;

			next_next_instruction=next_instruction->instruction_next;
			if (next_next_instruction!=NULL && next_next_instruction->instruction_icode==IMOVE &&
				next_next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
				next_next_instruction->instruction_parameters[0].parameter_data.reg.r!=next_instruction->instruction_parameters[0].parameter_data.reg.r &&
				next_next_instruction->instruction_parameters[0].parameter_data.reg.r!=B_STACK_POINTER &&
				next_next_instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
				next_next_instruction->instruction_parameters[1].parameter_data.reg.r==a_reg
			){
				int offset1,offset2;
				/* str ldr str*/

				offset1=next_instruction->instruction_parameters[0].parameter_offset;
				offset2=next_next_instruction->instruction_parameters[1].parameter_offset;
				if (offset+4<=offset1 || offset>=offset1+4){
					if (offset2==offset+4){
						if (offset>=-1020 && offset<=1020){
							w_as_opcode_ldr_register_comma (next_instruction->instruction_parameters[1].parameter_data.reg.r);
							w_as_indirect_newline (offset1,a_reg);
						
							w_as_strd_register_register_comma (s_reg,next_next_instruction->instruction_parameters[0].parameter_data.reg.r);
							w_as_indirect_newline (offset,a_reg);
							
							return next_next_instruction;	
						}
					} else if (offset2==offset-4){
						if (offset-4>=-1020 && offset-4<=1020){
							w_as_opcode_ldr_register_comma (next_instruction->instruction_parameters[1].parameter_data.reg.r);
							w_as_indirect_newline (offset1,a_reg);

							w_as_strd_register_register_comma (next_next_instruction->instruction_parameters[0].parameter_data.reg.r,s_reg);
							w_as_indirect_newline (offset-4,a_reg);
							
							return next_next_instruction;
						}
					}
				}
			}
		}
	}

	w_as_opcode_str_register_comma (s_reg);
	w_as_indirect_newline (offset,a_reg);
	return instruction;
}

static struct instruction *w_as_optimize_str_id_str_scratch_id (struct instruction *instruction,int s_reg,int offset,int a_reg)
{
	if ((offset & 3)==0 && s_reg!=B_STACK_POINTER && instruction->instruction_parameters[1].parameter_data.reg.r==a_reg){
		if (instruction->instruction_parameters[1].parameter_offset==offset+4){
			if (offset>=-1020 && offset<=1020){
				w_as_strd_register_register_comma (s_reg,REGISTER_S0);
				w_as_indirect_newline (offset,a_reg);
				return instruction;
			}
		} else if (instruction->instruction_parameters[1].parameter_offset==offset-4){
			if (offset-4>=-1020 && offset-4<=1020){
				w_as_strd_register_register_comma (REGISTER_S0,s_reg);
				w_as_indirect_newline (offset-4,a_reg);
				return instruction;
			}
		}
	}

	w_as_opcode_str_register_comma (s_reg);
	w_as_indirect_newline (offset,a_reg);

	return w_as_str_or_strd_id (instruction,&instruction->instruction_parameters[1],REGISTER_S0);
}
#endif

static void w_as_ldr_ldr_or_ldrd_id (int offset1,int a_reg1,int d_reg1,int offset2,int a_reg2,int d_reg2)
{
#ifndef NO_LDRD
	if (a_reg1==a_reg2 && d_reg1!=a_reg1 && (offset1 & 3)==0 && d_reg1!=B_STACK_POINTER && d_reg2!=B_STACK_POINTER){
		if (offset2==offset1+4){
			if (offset1>=-1020 && offset1<=1020){
				w_as_ldrd_register_register_comma (d_reg1,d_reg2);
				w_as_indirect_newline (offset1,a_reg1);
				return;
			}
		} else if (offset2==offset1-4){
			if (offset2>=-1020 && offset2<=1020){
				w_as_ldrd_register_register_comma (d_reg2,d_reg1);
				w_as_indirect_newline (offset2,a_reg1);
				return;
			}
		}
	}
#endif

	w_as_opcode_ldr_register_comma (d_reg1);
	w_as_indirect_newline (offset1,a_reg1);
	
	w_as_opcode_ldr_register_comma (d_reg2);
	w_as_indirect_newline (offset2,a_reg2);
}

static struct instruction *w_as_push (struct instruction *instruction,int s_reg)
{
	struct instruction *next_instruction;

	next_instruction=instruction->instruction_next;
	if (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
		next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
		next_instruction->instruction_parameters[1].parameter_type==P_PRE_DECREMENT &&
		next_instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER &&
		reg_num (next_instruction->instruction_parameters[0].parameter_data.reg.r) < reg_num (s_reg)
	){
		int extra_pushed_registers[16],n_extra_pushed_registers,last_pushed_reg;
		
		n_extra_pushed_registers=0;

		do {
			last_pushed_reg = next_instruction->instruction_parameters[0].parameter_data.reg.r;
			extra_pushed_registers[n_extra_pushed_registers++] = last_pushed_reg;

			instruction=next_instruction;
			next_instruction=instruction->instruction_next;
		} while (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
				next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
				next_instruction->instruction_parameters[1].parameter_type==P_PRE_DECREMENT &&
				next_instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER &&
				reg_num (next_instruction->instruction_parameters[0].parameter_data.reg.r) < reg_num (last_pushed_reg));

		w_as_opcode ("push");
		fprintf (assembly_file,"{");		
		while (n_extra_pushed_registers>0){
			--n_extra_pushed_registers;
			w_as_register_comma (extra_pushed_registers[n_extra_pushed_registers]);
		}
		w_as_register (s_reg);
		fprintf (assembly_file,"}");
		w_as_newline_after_instruction();
	} else
		w_as_push_r (s_reg);
	
	return instruction;
}

#ifndef NO_OPT_INDEXED
static int indirect_offset_next_or_previous_aligned (int offset1,int offset2)
{
	if ((offset1 & 0x3)==0){
		if (offset2==offset1+4){
			if (offset1>=-1020 && offset1<=1020)
				return 1;
		} else if (offset2==offset1-4){
			if (offset2>=-1020 && offset2<=1020)
				return 2;
		}
	}

	return 0;
}

static int index_offset_next_or_previous_aligned (int offset1,int offset2)
{
	if ((offset1 & 0xc)==0){
		if (offset2==offset1+(4<<2)){
			if ((offset1>>2)>=-1020 && (offset1>>2)<=1020)
				return 1;
		} else if (offset2==offset1-(4<<2)){
			if (((offset1-(4<<2))>>2)>=-1020 && ((offset1-(4<<2))>>2)<=1020)
				return 2;
		}
	}

	return 0;
}

static struct instruction *w_as_more_load_indexed (struct instruction *instruction,int reg1,int reg2,int reg3,int offset)
{
	struct instruction *previous_instruction;

	do {
		int load_offset1;

		load_offset1=instruction->instruction_parameters[0].parameter_offset;

		if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
			int d_reg;
			struct instruction *instruction2;

			d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

			if (d_reg==reg1 || d_reg==reg2){
				w_as_opcode_ldr_register_comma (d_reg);
				w_as_indirect_newline (load_offset1>>2,reg3);

				return instruction;
			}

			instruction2=instruction->instruction_next;
			if (instruction2!=NULL && instruction2->instruction_icode==IMOVE &&
				instruction2->instruction_parameters[0].parameter_type==P_REGISTER &&
				instruction2->instruction_parameters[0].parameter_data.reg.r==d_reg &&
				(instruction2->instruction_parameters[1].parameter_type==P_INDIRECT ||
				 instruction2->instruction_parameters[1].parameter_type==P_PRE_DECREMENT ||
				 (instruction2->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE &&
			 	  instruction2->instruction_parameters[1].parameter_data.reg.r!=reg1 &&
				  instruction2->instruction_parameters[1].parameter_data.reg.r!=reg2))
			){
				int store_offset1,store_a_reg1;
				struct instruction *instruction3;
				
				store_offset1=instruction2->instruction_parameters[1].parameter_offset;
				store_a_reg1=instruction2->instruction_parameters[1].parameter_data.reg.r;

				instruction3=instruction2->instruction_next;
				if (instruction3!=NULL && instruction3->instruction_icode==IMOVE &&
					instruction3->instruction_parameters[0].parameter_type==P_INDEXED &&
					instruction3->instruction_parameters[0].parameter_data.ir->a_reg.r==reg1 &&
					instruction3->instruction_parameters[0].parameter_data.ir->d_reg.r==reg2 &&
					(instruction3->instruction_parameters[0].parameter_offset & 3)==(offset & 3) &&
					instruction3->instruction_parameters[1].parameter_type==P_REGISTER
				){
					if (instruction2->instruction_parameters[1].parameter_type!=P_INDIRECT){
						w_as_opcode_ldr_register_comma (d_reg);
						w_as_indirect_newline (load_offset1>>2,reg3);
						
						if (instruction2->instruction_parameters[1].parameter_type==P_PRE_DECREMENT ||
							(store_a_reg1==B_STACK_POINTER && store_offset1==-4) /* P_INDIRECT_WITH_UPDATE */
						){
							w_as_push_r (d_reg);
						} else {/* P_INDIRECT_WITH_UPDATE */
							w_as_opcode_str_register_comma (d_reg);
							w_as_indirect_with_update_newline (store_offset1,store_a_reg1);
						}

						previous_instruction=instruction2;
						instruction=instruction3;
					} else {
						int load_offset2,d_reg2;
						struct instruction *instruction4;

						load_offset2=instruction3->instruction_parameters[0].parameter_offset;
						d_reg2=instruction3->instruction_parameters[1].parameter_data.reg.r;

						if (d_reg2==reg1 || d_reg2==reg2){
							w_as_opcode_ldr_register_comma (d_reg);
							w_as_indirect_newline (load_offset1>>2,reg3);
							
							w_as_opcode_str_register_comma (d_reg);
							w_as_indirect_newline (store_offset1,store_a_reg1);

							w_as_opcode_ldr_register_comma (d_reg2);
							w_as_indirect_newline (load_offset2>>2,reg3);
							return instruction3;
						}
						
						instruction4=instruction3->instruction_next;
						if (instruction4!=NULL && instruction4->instruction_icode==IMOVE &&
							instruction4->instruction_parameters[0].parameter_type==P_REGISTER &&
							instruction4->instruction_parameters[0].parameter_data.reg.r==d_reg2 &&
							instruction4->instruction_parameters[1].parameter_type==P_INDIRECT
						){
							int store_offset2,store_a_reg2;
							
							store_offset2=instruction4->instruction_parameters[1].parameter_offset;
							store_a_reg2=instruction4->instruction_parameters[1].parameter_data.reg.r;

							if (store_a_reg1!=d_reg2 && store_a_reg1!=reg1 && (store_a_reg1==A_STACK_POINTER || store_a_reg1==B_STACK_POINTER) &&
								d_reg!=B_STACK_POINTER && d_reg2!=B_STACK_POINTER
							){
								int use_ldrd,use_strd;
								
								use_ldrd = index_offset_next_or_previous_aligned (load_offset1,load_offset2);
								use_strd = store_a_reg1==store_a_reg2 ? indirect_offset_next_or_previous_aligned (store_offset1,store_offset2) : 0;

								if (use_ldrd || use_strd){
									if (d_reg==d_reg2)
										d_reg = reg3!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

									if (use_ldrd){
										if (use_ldrd==1){
											w_as_ldrd_register_register_comma (d_reg,d_reg2);
											w_as_indirect_newline (load_offset1>>2,reg3);
										} else {
											w_as_ldrd_register_register_comma (d_reg2,d_reg);
											w_as_indirect_newline (load_offset2>>2,reg3);
										}
									} else {
										w_as_opcode_ldr_register_comma (d_reg);
										w_as_indirect_newline (load_offset1>>2,reg3);

										w_as_opcode_ldr_register_comma (d_reg2);
										w_as_indirect_newline (load_offset2>>2,reg3);
									}
									if (use_strd){
										if (use_strd==1){
											w_as_strd_register_register_comma (d_reg,d_reg2);
											w_as_indirect_newline (store_offset1,store_a_reg1);
										} else {
											w_as_strd_register_register_comma (d_reg2,d_reg);
											w_as_indirect_newline (store_offset2,store_a_reg1);
										}
									} else {
										w_as_opcode_str_register_comma (d_reg);
										w_as_indirect_newline (store_offset1,store_a_reg1);
										
										w_as_opcode_str_register_comma (d_reg2);
										w_as_indirect_newline (store_offset2,store_a_reg2);
									}
								} else {
									w_as_opcode_ldr_register_comma (d_reg);
									w_as_indirect_newline (load_offset1>>2,reg3);

									w_as_opcode_str_register_comma (d_reg);
									w_as_indirect_newline (store_offset1,store_a_reg1);

									w_as_opcode_ldr_register_comma (d_reg2);
									w_as_indirect_newline (load_offset2>>2,reg3);

									w_as_opcode_str_register_comma (d_reg2);
									w_as_indirect_newline (store_offset2,store_a_reg2);
								}
							} else {
								w_as_opcode_ldr_register_comma (d_reg);
								w_as_indirect_newline (load_offset1>>2,reg3);

								w_as_opcode_str_register_comma (d_reg);
								w_as_indirect_newline (store_offset1,store_a_reg1);
								
								w_as_opcode_ldr_register_comma (d_reg2);
								w_as_indirect_newline (load_offset2>>2,reg3);
								
								w_as_opcode_str_register_comma (d_reg2);
								w_as_indirect_newline (store_offset2,store_a_reg2);
							}

							previous_instruction=instruction4;
							instruction=previous_instruction->instruction_next;
						} else {
							w_as_opcode_ldr_register_comma (d_reg);
							w_as_indirect_newline (load_offset1>>2,reg3);
							
							w_as_opcode_str_register_comma (d_reg);
							w_as_indirect_newline (store_offset1,store_a_reg1);

							w_as_opcode_ldr_register_comma (d_reg2);
							w_as_indirect_newline (load_offset2>>2,reg3);

							previous_instruction=instruction3;
							instruction=instruction4;
						}
					}
				} else {
					w_as_opcode_ldr_register_comma (d_reg);
					w_as_indirect_newline (load_offset1>>2,reg3);

					if (instruction2->instruction_parameters[1].parameter_type==P_INDIRECT){
						w_as_opcode_str_register_comma (d_reg);
						w_as_indirect_newline (store_offset1,store_a_reg1);
					} else if (instruction2->instruction_parameters[1].parameter_type==P_PRE_DECREMENT ||
							   (store_a_reg1==B_STACK_POINTER && store_offset1==-4) /* P_INDIRECT_WITH_UPDATE */
					){
						w_as_push_r (d_reg);
					} else {/* P_INDIRECT_WITH_UPDATE */
						w_as_opcode_str_register_comma (d_reg);
						w_as_indirect_with_update_newline (store_offset1,store_a_reg1);
					}

					previous_instruction=instruction2;
					instruction=instruction3;
				}
			} else if (instruction2!=NULL && instruction2->instruction_icode==IMOVE &&
					instruction2->instruction_parameters[0].parameter_type==P_INDEXED &&
					instruction2->instruction_parameters[0].parameter_data.ir->a_reg.r==reg1 &&
					instruction2->instruction_parameters[0].parameter_data.ir->d_reg.r==reg2 &&
					(instruction2->instruction_parameters[0].parameter_offset & 3)==(offset & 3) &&
					instruction2->instruction_parameters[1].parameter_type==P_REGISTER &&
					instruction2->instruction_parameters[1].parameter_data.reg.r!=d_reg &&
					instruction2->instruction_parameters[1].parameter_data.reg.r!=B_STACK_POINTER &&
					d_reg!=B_STACK_POINTER
			){
				int load_offset2,use_ldrd;
				
				load_offset2=instruction2->instruction_parameters[0].parameter_offset;
	
				use_ldrd = index_offset_next_or_previous_aligned (load_offset1,load_offset2);
				if (use_ldrd){
					int d_reg2;
					
					d_reg2=instruction2->instruction_parameters[1].parameter_data.reg.r;
					if (use_ldrd==1){
						w_as_ldrd_register_register_comma (d_reg,d_reg2);
						w_as_indirect_newline (load_offset1>>2,reg3);
					} else {
						w_as_ldrd_register_register_comma (d_reg2,d_reg);
						w_as_indirect_newline (load_offset2>>2,reg3);
					}

					if (d_reg2==reg1 || d_reg2==reg2)
						return instruction2;

					previous_instruction=instruction2;
					instruction=previous_instruction->instruction_next;					
				} else {
					w_as_opcode_ldr_register_comma (d_reg);
					w_as_indirect_newline (load_offset1>>2,reg3);
			
					previous_instruction=instruction;
					instruction=instruction2;
				}
			} else {
				w_as_opcode_ldr_register_comma (d_reg);
				w_as_indirect_newline (load_offset1>>2,reg3);

				previous_instruction=instruction;
				instruction=previous_instruction->instruction_next;
			}
		} else {
			int d_reg;

			d_reg = reg3!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

			w_as_opcode_ldr_register_comma (d_reg);
			w_as_indirect_newline (load_offset1>>2,reg3);

			switch (instruction->instruction_parameters[1].parameter_type){
				case P_INDIRECT:
					w_as_opcode_str_register_comma (d_reg);
					w_as_indirect_newline (instruction->instruction_parameters[1].parameter_offset,
										   instruction->instruction_parameters[1].parameter_data.reg.r);
					break;
				case P_PRE_DECREMENT:
					w_as_push_r (d_reg);
					break;
				case P_INDIRECT_WITH_UPDATE:
					if (instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER &&
						instruction->instruction_parameters[1].parameter_offset==-4
					){
						w_as_push_r (d_reg);
					} else {
						w_as_opcode_str_register_comma (d_reg);
						w_as_indirect_with_update_newline (instruction->instruction_parameters[1].parameter_offset,
														   instruction->instruction_parameters[1].parameter_data.reg.r);
					}

					if (instruction->instruction_parameters[1].parameter_data.reg.r==reg1 ||
						instruction->instruction_parameters[1].parameter_data.reg.r==reg2)
						return instruction;
					break;
				default:
					internal_error_in_function ("w_as_more_load_indexed");
			}

			previous_instruction=instruction;
			instruction=previous_instruction->instruction_next;
		}

		while (instruction!=NULL && instruction->instruction_icode==IMOVE &&
			   instruction->instruction_parameters[0].parameter_type==P_REGISTER
		){
			int s_reg;
			
			s_reg=instruction->instruction_parameters[0].parameter_data.reg.r;

			if (instruction->instruction_parameters[1].parameter_type==P_REGISTER &&
				instruction->instruction_parameters[1].parameter_data.reg.r!=reg1 &&
				instruction->instruction_parameters[1].parameter_data.reg.r!=reg2 &&
				instruction->instruction_parameters[1].parameter_data.reg.r!=reg3
			){
				int d_reg;
				
				d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

				w_as_mov_register_register_newline (d_reg,s_reg);

				previous_instruction=instruction;
				instruction=previous_instruction->instruction_next;					

				if ((s_reg==reg1 || s_reg==reg2) && reg1!=reg2 &&
					instruction!=NULL && instruction->instruction_icode==IMOVE &&
					instruction->instruction_parameters[0].parameter_type==P_INDEXED &&
					instruction->instruction_parameters[0].parameter_data.ir->a_reg.r==reg1 &&
					instruction->instruction_parameters[0].parameter_data.ir->d_reg.r==reg2 &&
					(instruction->instruction_parameters[0].parameter_offset & 3)==(offset & 3) &&
					instruction->instruction_parameters[1].parameter_type==P_REGISTER &&
					instruction->instruction_parameters[1].parameter_data.reg.r==s_reg
				){
					w_as_opcode_ldr_register_comma (s_reg);
					w_as_indirect_newline (instruction->instruction_parameters[0].parameter_offset>>2,reg3);
				
					if (s_reg==reg1)
						reg1=d_reg;
					if (s_reg==reg2)
						reg2=d_reg;
					
					previous_instruction=instruction;
					instruction=previous_instruction->instruction_next;				
				}
			} else if (instruction->instruction_parameters[1].parameter_type==P_PRE_DECREMENT &&
					   instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER
			){
				struct instruction *instruction2;

				instruction2=instruction->instruction_next;
				if (instruction2!=NULL && instruction2->instruction_icode==IMOVE &&
					instruction2->instruction_parameters[0].parameter_type==P_REGISTER &&
					instruction2->instruction_parameters[1].parameter_type==P_PRE_DECREMENT
				)
					break;
				
				w_as_push_r (s_reg);
	
				previous_instruction=instruction;
				instruction=instruction2;
			} else
				break;
		}
	} while (instruction!=NULL && instruction->instruction_icode==IMOVE &&
		instruction->instruction_parameters[0].parameter_type==P_INDEXED &&
		instruction->instruction_parameters[0].parameter_data.ir->a_reg.r==reg1 &&
		instruction->instruction_parameters[0].parameter_data.ir->d_reg.r==reg2 &&
		(instruction->instruction_parameters[0].parameter_offset & 3)==(offset & 3) &&
		(instruction->instruction_parameters[1].parameter_type==P_REGISTER ||
		 instruction->instruction_parameters[1].parameter_type==P_INDIRECT ||
		 instruction->instruction_parameters[1].parameter_type==P_PRE_DECREMENT ||
		 instruction->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE));
	
	return previous_instruction;
}

static struct instruction *w_as_maybe_more_load_indexed (struct instruction *instruction,int reg1,int reg2,int reg3,int offset)
{
	struct instruction *instruction2;

	instruction2=instruction->instruction_next;
	if (instruction2!=NULL && instruction2->instruction_icode==IMOVE &&
		instruction2->instruction_parameters[0].parameter_type==P_INDEXED &&
		instruction2->instruction_parameters[0].parameter_data.ir->a_reg.r==reg1 &&
		instruction2->instruction_parameters[0].parameter_data.ir->d_reg.r==reg2 &&
		(instruction2->instruction_parameters[0].parameter_offset & 3)==(offset & 3) &&								
		(instruction2->instruction_parameters[1].parameter_type==P_REGISTER ||
		 instruction2->instruction_parameters[1].parameter_type==P_INDIRECT ||
		 instruction2->instruction_parameters[1].parameter_type==P_PRE_DECREMENT ||
		 instruction2->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE)
	)
		return w_as_more_load_indexed (instruction2,reg1,reg2,reg3,offset);
	
	return instruction;
}

static int index_next_or_previous_aligned (struct instruction *instruction,int s_reg1,int offset1)
{
	if (s_reg1!=B_STACK_POINTER &&
		instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
		instruction->instruction_parameters[0].parameter_data.reg.r!=B_STACK_POINTER &&
		(offset1 & 0xc)==0
	){
		if (instruction->instruction_parameters[1].parameter_offset==offset1+(4<<2)){
			if ((offset1>>2)>=-1020 && (offset1>>2)<=1020)
				return 1;
		} else if (instruction->instruction_parameters[1].parameter_offset==offset1-(4<<2)){
			if (((offset1-(4<<2))>>2)>=-1020 && ((offset1-(4<<2))>>2)<=1020)
				return 2;
		}
	}

	return 0;
}

static int store_index_next_or_previous (struct instruction *instruction,int s_reg1,int offset1,int reg1,int reg2,int index_shift)
{
	if (instruction!=NULL &&
		instruction->instruction_icode==IMOVE &&
		instruction->instruction_parameters[1].parameter_type==P_INDEXED &&
		instruction->instruction_parameters[1].parameter_data.ir->a_reg.r==reg1 &&
		instruction->instruction_parameters[1].parameter_data.ir->d_reg.r==reg2 &&
		(instruction->instruction_parameters[1].parameter_offset & 3)==index_shift
	)
		return index_next_or_previous_aligned (instruction,s_reg1,offset1);

	return 0;
}

static struct instruction *w_as_more_store_indexed (struct instruction *previous_instruction,int reg1,int reg2,int reg3,int index_shift)
{
	struct instruction *instruction;

	while (instruction=previous_instruction->instruction_next,
		instruction!=NULL && instruction->instruction_icode==IMOVE
	){
		if (instruction->instruction_parameters[1].parameter_type==P_REGISTER &&
			instruction->instruction_parameters[0].parameter_type==P_INDIRECT
		){
			int d_reg,a_reg,offset;
			struct instruction *next_instruction;
			
			d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;
			a_reg=instruction->instruction_parameters[0].parameter_data.reg.r;
			offset=instruction->instruction_parameters[0].parameter_offset;

			next_instruction=instruction->instruction_next;
			if (d_reg!=reg1 && d_reg!=reg2 && d_reg!=reg3 && d_reg!=a_reg &&
				next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
				(offset & 3)==0 && d_reg!=B_STACK_POINTER
			){
				if (next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
					next_instruction->instruction_parameters[0].parameter_data.reg.r==d_reg &&
					next_instruction->instruction_parameters[1].parameter_type==P_INDEXED &&
					next_instruction->instruction_parameters[1].parameter_data.ir->a_reg.r==reg1 &&
					next_instruction->instruction_parameters[1].parameter_data.ir->d_reg.r==reg2 &&
					(next_instruction->instruction_parameters[1].parameter_offset & 3)==index_shift
				){
					/* ldr->str_indexed */
					int store_offset,use_strd;
					struct instruction *next_next_instruction;
			
					store_offset=next_instruction->instruction_parameters[1].parameter_offset;
		
					next_next_instruction=next_instruction->instruction_next;
					if (reg1!=d_reg && reg2!=d_reg &&
						next_next_instruction!=NULL && next_next_instruction->instruction_icode==IMOVE &&
						next_next_instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
						next_next_instruction->instruction_parameters[1].parameter_type==P_REGISTER
					){
						struct instruction *next_next_next_instruction;
						int d_reg2,a_reg2;
						
						a_reg2=next_next_instruction->instruction_parameters[0].parameter_data.reg.r;
						d_reg2=next_next_instruction->instruction_parameters[1].parameter_data.reg.r;

						next_next_next_instruction=next_next_instruction->instruction_next;
						if (reg1!=d_reg2 && reg2!=d_reg2 &&
							next_next_next_instruction!=NULL && next_next_next_instruction->instruction_icode==IMOVE &&
							next_next_next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
							next_next_next_instruction->instruction_parameters[0].parameter_data.reg.r==d_reg2 &&
							next_next_next_instruction->instruction_parameters[1].parameter_type==P_INDEXED &&
							next_next_next_instruction->instruction_parameters[1].parameter_data.ir->a_reg.r==reg1 &&
							next_next_next_instruction->instruction_parameters[1].parameter_data.ir->d_reg.r==reg2 &&
							(next_next_next_instruction->instruction_parameters[1].parameter_offset & 3)==index_shift
						){
							/* ldr->str_indexed ldr->str_indexed */
							int shift;

							if (reg3!=d_reg && reg3!=d_reg2){
								int load_offset2,store_offset2;

								load_offset2=next_next_instruction->instruction_parameters[0].parameter_offset;
								store_offset2=next_next_next_instruction->instruction_parameters[1].parameter_offset;

								if (a_reg2!=reg1 && (a_reg2==A_STACK_POINTER || a_reg2==B_STACK_POINTER) &&
									d_reg!=B_STACK_POINTER && d_reg2!=B_STACK_POINTER)
								{
									if (store_offset+(4<<2)==store_offset2){
										if ((store_offset>>2)>=-1020 && (store_offset>>2)<=1020){
											if (d_reg==d_reg2)
												d_reg = reg3!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

											w_as_ldr_ldr_or_ldrd_id (offset,a_reg,d_reg,load_offset2,a_reg2,d_reg2);

											w_as_strd_register_register_comma (d_reg,d_reg2);
											w_as_indirect_newline (store_offset>>2,reg3);

											previous_instruction=next_next_next_instruction;
											continue;
										}
									} else if (store_offset2==store_offset-(4<<2)){
										if (((store_offset-(4<<2))>>2)>=-1020 && ((store_offset-(4<<2))>>2)<=1020){
											if (d_reg==d_reg2)
												d_reg = reg3!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

											w_as_ldr_ldr_or_ldrd_id (offset,a_reg,d_reg,load_offset2,a_reg2,d_reg2);

											w_as_strd_register_register_comma (d_reg2,d_reg);
											w_as_indirect_newline ((store_offset-4)>>2,reg3);

											previous_instruction=next_next_next_instruction;
											continue;
										}
									}
								}

								w_as_opcode_ldr_register_comma (d_reg);
								w_as_indirect_newline (offset,a_reg);

								w_as_opcode_str_register_comma (d_reg);
								w_as_indirect_newline (store_offset>>2,reg3);

								w_as_opcode_ldr_register_comma (d_reg2);
								w_as_indirect_newline (load_offset2,a_reg2);

								w_as_opcode_str_register_comma (d_reg2);
								w_as_indirect_newline (store_offset2>>2,reg3);

								previous_instruction=next_next_next_instruction;
								continue;
							}
						}
					}

					w_as_opcode_ldr_register_comma (d_reg);
					w_as_indirect_newline (offset,a_reg);

					use_strd = store_index_next_or_previous (next_next_instruction,d_reg,store_offset,reg1,reg2,index_shift);
					if (use_strd){
						int s_reg2;
					
						s_reg2=next_next_instruction->instruction_parameters[0].parameter_data.reg.r;
						if (use_strd==1){
							w_as_strd_register_register_comma (d_reg,s_reg2);
							w_as_indirect_newline (store_offset>>2,reg3);
						} else {
							w_as_strd_register_register_comma (s_reg2,d_reg);
							w_as_indirect_newline ((store_offset-(4<<2))>>2,reg3);
						}
						
						previous_instruction=next_next_instruction;
						continue;
					}

					w_as_opcode_str_register_comma (d_reg);
					w_as_indirect_newline (store_offset>>2,reg3);
					
					previous_instruction=next_instruction;
					continue;
				}
			}
		} else if (instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
			instruction->instruction_parameters[1].parameter_type==P_INDEXED &&
			instruction->instruction_parameters[1].parameter_data.ir->a_reg.r==reg1 &&
			instruction->instruction_parameters[1].parameter_data.ir->d_reg.r==reg2 &&
			(instruction->instruction_parameters[1].parameter_offset & 3)==index_shift
		){
			struct instruction *next_instruction;
			int s_reg1,offset1,use_strd;

			s_reg1=instruction->instruction_parameters[0].parameter_data.reg.r;
			offset1=instruction->instruction_parameters[1].parameter_offset;
			
			next_instruction=instruction->instruction_next;
			use_strd = store_index_next_or_previous (next_instruction,s_reg1,offset1,reg1,reg2,index_shift);
			if (use_strd){
				int s_reg2;
			
				s_reg2=next_instruction->instruction_parameters[0].parameter_data.reg.r;
				if (use_strd==1){
					w_as_strd_register_register_comma (s_reg1,s_reg2);
					w_as_indirect_newline (offset1>>2,reg3);
				} else {
					w_as_strd_register_register_comma (s_reg2,s_reg1);
					w_as_indirect_newline ((offset1-(4<<2))>>2,reg3);
				}				
				
				previous_instruction=next_instruction;
				continue;
			}

			w_as_opcode_str_register_comma (s_reg1);
			w_as_indirect_newline (offset1>>2,reg3);

			previous_instruction=instruction;
			continue;
		}
		
		break;
	}

	return previous_instruction;
}

static struct instruction *w_as_move_indexed_load_store_sequence (struct instruction *instruction) 
{
	struct instruction *next_instruction,*next_next_instruction;
	int store_address_without_offset_computed;
	int reg1,reg2,offset;

	reg1=instruction->instruction_parameters[0].parameter_data.ir->a_reg.r;
	reg2=instruction->instruction_parameters[0].parameter_data.ir->d_reg.r;
	offset=instruction->instruction_parameters[0].parameter_offset;

	w_as_opcode ("add");
	w_as_register_comma (REGISTER_S0);	
	w_as_register_comma (reg1);
	w_as_lsl_register_newline (reg2,offset & 3);

	w_as_opcode_ldr_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_indirect_newline (offset>>2,REGISTER_S0);

	next_instruction=instruction->instruction_next;
	next_next_instruction=next_instruction->instruction_next;
	
	store_address_without_offset_computed = 0;

	for (;;){
		struct instruction *store_indexed_instruction,*load_indexed_instruction;

		store_indexed_instruction=next_instruction;
		load_indexed_instruction=next_next_instruction;

		instruction=next_next_instruction;
	
		{
			int reg1,reg2;

			reg1=load_indexed_instruction->instruction_parameters[0].parameter_data.ir->a_reg.r;
			reg2=load_indexed_instruction->instruction_parameters[0].parameter_data.ir->d_reg.r;

			if (load_indexed_instruction->instruction_parameters[1].parameter_data.reg.r!=reg1 &&
				load_indexed_instruction->instruction_parameters[1].parameter_data.reg.r!=reg2
			){
				int offset;
				
				offset=instruction->instruction_parameters[0].parameter_offset;

				next_instruction=instruction->instruction_next;
				if (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
					next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
					next_instruction->instruction_parameters[1].parameter_type==P_INDEXED
				){
					next_next_instruction=next_instruction->instruction_next;
					if (next_next_instruction!=NULL && next_next_instruction->instruction_icode==IMOVE &&
						next_next_instruction->instruction_parameters[0].parameter_type==P_INDEXED &&
						next_next_instruction->instruction_parameters[0].parameter_data.ir->a_reg.r==reg1 &&
						next_next_instruction->instruction_parameters[0].parameter_data.ir->d_reg.r==reg2 &&
						(next_next_instruction->instruction_parameters[0].parameter_offset & 3)==(offset & 3) &&								
						next_next_instruction->instruction_parameters[1].parameter_type==P_REGISTER
					){
						{
							int s_offset;

							s_offset=store_indexed_instruction->instruction_parameters[1].parameter_offset;
							if ((s_offset & -4)!=0){
								int reg1,reg2;
								
								reg1=store_indexed_instruction->instruction_parameters[1].parameter_data.ir->a_reg.r;
								reg2=store_indexed_instruction->instruction_parameters[1].parameter_data.ir->d_reg.r;
								
								/* compute next store_address_without_offset_computed */
								if (next_instruction->instruction_parameters[1].parameter_data.ir->a_reg.r==reg1 &&
									next_instruction->instruction_parameters[1].parameter_data.ir->d_reg.r==reg2 &&
									(next_instruction->instruction_parameters[1].parameter_offset & 3)==(s_offset & 3) &&
									load_indexed_instruction->instruction_parameters[1].parameter_data.reg.r!=reg1 &&
									load_indexed_instruction->instruction_parameters[1].parameter_data.reg.r!=reg2
								){
									if (store_address_without_offset_computed){
										w_as_opcode_str_register_comma (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r);
										w_as_indirect_newline (s_offset>>2,REGISTER_S1);
									} else {
										w_as_opcode ("add");
										w_as_register_comma (REGISTER_S1);	
										w_as_register_comma (reg1);
										w_as_lsl_register_newline (reg2,s_offset & 3);

										store_address_without_offset_computed = 1;

										w_as_opcode_str_register_comma (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r);
										w_as_indirect_newline (s_offset>>2,REGISTER_S1);																	
									}
								} else {
									if (store_address_without_offset_computed){
										w_as_opcode_str_register_comma (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r);
										w_as_indirect_newline (s_offset>>2,REGISTER_S1);

										store_address_without_offset_computed = 0;
									} else {
										w_as_opcode ("add");
										w_as_register_comma (REGISTER_S1);	
										w_as_register_comma (reg1);
										w_as_immediate_newline (s_offset>>2);

										w_as_opcode_str_register_comma (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r);
										w_as_indexed_no_offset_newline (s_offset,REGISTER_S1,reg2);
									}
								}
							} else {
								w_as_opcode_str_register_comma (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r);
								w_as_indexed_no_offset_ir_newline (s_offset,
														   		   store_indexed_instruction->instruction_parameters[1].parameter_data.ir);

								store_address_without_offset_computed = 0;
							}
						}
						
						w_as_opcode_ldr_register_comma (load_indexed_instruction->instruction_parameters[1].parameter_data.reg.r);
						w_as_indirect_newline (load_indexed_instruction->instruction_parameters[0].parameter_offset>>2,REGISTER_S0);

						continue;
					}
				}
			}
		}

		{
			int s_offset;

			s_offset=store_indexed_instruction->instruction_parameters[1].parameter_offset;
			if ((s_offset & -4)!=0){
				struct instruction *next_instruction;
				int reg1,reg2;
								
				reg1=store_indexed_instruction->instruction_parameters[1].parameter_data.ir->a_reg.r;
				reg2=store_indexed_instruction->instruction_parameters[1].parameter_data.ir->d_reg.r;
				next_instruction=instruction->instruction_next;

				/* compute next store_address_without_offset_computed */
				if (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
					next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
					next_instruction->instruction_parameters[1].parameter_type==P_INDEXED &&
					next_instruction->instruction_parameters[1].parameter_data.ir->a_reg.r==reg1 &&
					next_instruction->instruction_parameters[1].parameter_data.ir->d_reg.r==reg2 &&
					(next_instruction->instruction_parameters[1].parameter_offset & 3)==(s_offset & 3) &&
					load_indexed_instruction->instruction_parameters[1].parameter_data.reg.r!=reg1 &&
					load_indexed_instruction->instruction_parameters[1].parameter_data.reg.r!=reg2
				){
					if (store_address_without_offset_computed){
						w_as_opcode_str_register_comma (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r);
						w_as_indirect_newline (s_offset>>2,REGISTER_S1);
					} else {
						w_as_opcode ("add");
						w_as_register_comma (REGISTER_S1);	
						w_as_register_comma (reg1);
						w_as_lsl_register_newline (reg2,s_offset & 3);

						store_address_without_offset_computed = 1;

						w_as_opcode_str_register_comma (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r);
						w_as_indirect_newline (s_offset>>2,REGISTER_S1);																	
					}
				} else {
					if (store_address_without_offset_computed){
						w_as_opcode_str_register_comma (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r);
						w_as_indirect_newline (s_offset>>2,REGISTER_S1);
						
						store_address_without_offset_computed = 0;
					} else {
						w_as_opcode ("add");
						w_as_register_comma (REGISTER_S1);	
						w_as_register_comma (reg1);
						w_as_immediate_newline (s_offset>>2);

						w_as_opcode_str_register_comma (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r);
						w_as_indexed_no_offset_newline (s_offset,REGISTER_S1,reg2);
					}
				}
			} else {
				w_as_opcode_str_register_comma (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_indexed_no_offset_ir_newline (s_offset,
										   		   store_indexed_instruction->instruction_parameters[1].parameter_data.ir);

				store_address_without_offset_computed = 0;
			}
		}
		
		w_as_opcode_ldr_register_comma (load_indexed_instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_indirect_newline (load_indexed_instruction->instruction_parameters[0].parameter_offset>>2,REGISTER_S0);

		if (store_address_without_offset_computed){
			instruction=instruction->instruction_next;

			w_as_opcode_str_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
			w_as_indirect_newline (instruction->instruction_parameters[1].parameter_offset>>2,REGISTER_S1);
		}

		break;
	}
	
	return instruction;
}								
#endif

static void add_pc_to_pop (void)
{
	fprintf (assembly_file,",pc}");
	w_as_newline_after_instruction();

	write_float_constants();
	w_as_instruction_without_parameters (".ltorg");
	instruction_n_after_ltorg = 0u;
	ltorg_at_instruction_n = 0u-1u;
}

static struct instruction *w_as_move_instruction (struct parameter *s_parameter_p,struct instruction *instruction)
{
	struct parameter *d_parameter_p;
	int s_reg;

	d_parameter_p=&instruction->instruction_parameters[1];

	if (d_parameter_p->parameter_type==P_REGISTER){
		int d_reg;
		
		d_reg=d_parameter_p->parameter_data.reg.r;

		switch (s_parameter_p->parameter_type){
			case P_REGISTER:
				w_as_mov_register_register_newline (d_reg,s_parameter_p->parameter_data.reg.r);
				return instruction;
			case P_DESCRIPTOR_NUMBER:
				w_as_opcode_ldr_register_comma (d_reg);
				w_as_descriptor (s_parameter_p->parameter_data.l,s_parameter_p->parameter_offset);
				w_as_newline_after_instruction();
				return instruction;
			case P_IMMEDIATE:
				w_as_ld_immediate (s_parameter_p->parameter_data.i,d_reg);
				return instruction;
			case P_INDIRECT:
			{
				int a_reg,offset;
#ifndef NO_LDRD
				struct instruction *next_instruction;
#endif
				a_reg=s_parameter_p->parameter_data.reg.r;
				offset=s_parameter_p->parameter_offset;

#ifndef NO_LDRD
				next_instruction=instruction->instruction_next;
				if (d_reg!=a_reg && next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
					(offset & 3)==0 && d_reg!=B_STACK_POINTER
				){
					if (next_instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
						next_instruction->instruction_parameters[0].parameter_data.reg.r==a_reg
					){
						/* ldr ldr */
						if (next_instruction->instruction_parameters[1].parameter_type==P_REGISTER){
							if (next_instruction->instruction_parameters[1].parameter_data.reg.r!=B_STACK_POINTER){
								if (next_instruction->instruction_parameters[0].parameter_offset==offset+4){
									if (offset>=-1020 && offset<=1020){
										w_as_ldrd_register_register_comma (d_reg,next_instruction->instruction_parameters[1].parameter_data.reg.r);
										w_as_indirect_newline (offset,a_reg);
										return next_instruction;
									}
								} else if (next_instruction->instruction_parameters[0].parameter_offset==offset-4){
									if (offset-4>=-1020 && offset-4<=1020){
										w_as_ldrd_register_register_comma (next_instruction->instruction_parameters[1].parameter_data.reg.r,d_reg);
										w_as_indirect_newline (offset-4,a_reg);
										return next_instruction;
									}
								}
							}
						} else {
							if (next_instruction->instruction_parameters[0].parameter_offset==offset+4){
								if (offset>=-1020 && offset<=1020){
									w_as_ldrd_register_register_comma (d_reg,REGISTER_S0);
									w_as_indirect_newline (offset,a_reg);
									
									d_parameter_p=&next_instruction->instruction_parameters[1];
									instruction=next_instruction;
									s_reg = REGISTER_S0;
									break;
								}
							} else if (next_instruction->instruction_parameters[0].parameter_offset==offset-4){
								if (offset-4>=-1020 && offset-4<=1020){
									w_as_ldrd_register_register_comma (REGISTER_S0,d_reg);
									w_as_indirect_newline (offset-4,a_reg);
									
									d_parameter_p=&next_instruction->instruction_parameters[1];
									instruction=next_instruction;
									s_reg = REGISTER_S0;
									break;
								}
							}
						}
					}
					
					if (next_instruction->instruction_parameters[0].parameter_type==P_INDIRECT_WITH_UPDATE &&
						next_instruction->instruction_parameters[0].parameter_data.reg.r==a_reg &&
						next_instruction->instruction_parameters[1].parameter_type==P_REGISTER &&
						next_instruction->instruction_parameters[1].parameter_data.reg.r!=B_STACK_POINTER
					){
						if (next_instruction->instruction_parameters[0].parameter_offset==offset-4 &&
							next_instruction->instruction_parameters[1].parameter_data.reg.r!=d_reg &&
							next_instruction->instruction_parameters[1].parameter_data.reg.r!=B_STACK_POINTER
						){
							if (offset-4>=-1020 && offset-4<=1020){
								w_as_ldrd_register_register_comma (next_instruction->instruction_parameters[1].parameter_data.reg.r,d_reg);
								w_as_indirect_with_update_newline (offset-4,a_reg);
								return next_instruction;
							}
						}
					}
					
					if (next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
						next_instruction->instruction_parameters[0].parameter_data.reg.r!=B_STACK_POINTER &&
						next_instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
						next_instruction->instruction_parameters[1].parameter_data.reg.r==a_reg
					){
						struct instruction *next_next_instruction;
						int s_reg;

						s_reg=next_instruction->instruction_parameters[0].parameter_data.reg.r;

						next_next_instruction=next_instruction->instruction_next;
						if (next_next_instruction!=NULL && next_next_instruction->instruction_icode==IMOVE &&
							next_next_instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
							next_next_instruction->instruction_parameters[0].parameter_data.reg.r==a_reg
						){
							if (next_next_instruction->instruction_parameters[1].parameter_type==P_REGISTER){
								int d_reg2;
								
								d_reg2=next_next_instruction->instruction_parameters[1].parameter_data.reg.r;
								if (d_reg2!=d_reg && d_reg2!=B_STACK_POINTER && d_reg2!=a_reg && d_reg2!=s_reg){
									int offset1,offset2;
									/* ldr str ldr */

									offset1=next_instruction->instruction_parameters[1].parameter_offset;
									offset2=next_next_instruction->instruction_parameters[0].parameter_offset;
									if (offset1+4<=offset2 || offset1>=offset2+4){
										if (offset2==offset+4){
											if (offset>=-1020 && offset<=1020){
												w_as_ldrd_register_register_comma (d_reg,d_reg2);
												w_as_indirect_newline (offset,a_reg);
																
												return w_as_str_or_strd_id (next_next_instruction,
																			&next_instruction->instruction_parameters[1],s_reg);
											}
										} else if (offset2==offset-4){
											if (offset2>=-1020 && offset2<=1020){
												w_as_ldrd_register_register_comma (d_reg2,d_reg);
												w_as_indirect_newline (offset2,a_reg);

												return w_as_str_or_strd_id (next_next_instruction,
																			&next_instruction->instruction_parameters[1],s_reg);
											}
										}
									}
								}
							}
							if (next_next_instruction->instruction_parameters[1].parameter_type==P_INDIRECT){
								if (REGISTER_S0!=d_reg && REGISTER_S0!=a_reg && REGISTER_S0!=s_reg){
									int offset1,offset2;
									/* ldr str ldr->str */

									offset1=next_instruction->instruction_parameters[1].parameter_offset;
									offset2=next_next_instruction->instruction_parameters[0].parameter_offset;
									if (offset1+4<=offset2 || offset1>=offset2+4){
										if (offset2==offset+4){
											if (offset>=-1020 && offset<=1020){
												w_as_ldrd_register_register_comma (d_reg,REGISTER_S0);
												w_as_indirect_newline (offset,a_reg);
												
												return w_as_optimize_str_id_str_scratch_id (next_next_instruction,s_reg,offset1,a_reg);
											}
										} else if (offset2==offset-4){
											if (offset2>=-1020 && offset2<=1020){
												w_as_ldrd_register_register_comma (REGISTER_S0,d_reg);
												w_as_indirect_newline (offset2,a_reg);

												return w_as_optimize_str_id_str_scratch_id (next_next_instruction,s_reg,offset1,a_reg);
											}
										}
									}
								}
							}
						}
					}

# ifndef NO_OPT_INDEXED
					if (next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
						next_instruction->instruction_parameters[0].parameter_data.reg.r==d_reg &&
						next_instruction->instruction_parameters[1].parameter_type==P_INDEXED
					){
						/* ldr->str_indexed */
						int reg1,reg2,store_offset;
						struct instruction *next_next_instruction;
				
						store_offset=next_instruction->instruction_parameters[1].parameter_offset;
						reg1=next_instruction->instruction_parameters[1].parameter_data.ir->a_reg.r;
						reg2=next_instruction->instruction_parameters[1].parameter_data.ir->d_reg.r;
								
						next_next_instruction=next_instruction->instruction_next;
						if (reg1!=d_reg && reg2!=d_reg &&
							next_next_instruction!=NULL && next_next_instruction->instruction_icode==IMOVE &&
							next_next_instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
							next_next_instruction->instruction_parameters[1].parameter_type==P_REGISTER
						){
							struct instruction *next_next_next_instruction;
							int d_reg2,a_reg2;
							
							a_reg2=next_next_instruction->instruction_parameters[0].parameter_data.reg.r;
							d_reg2=next_next_instruction->instruction_parameters[1].parameter_data.reg.r;

							next_next_next_instruction=next_next_instruction->instruction_next;
							if (reg1!=d_reg2 && reg2!=d_reg2 &&
								next_next_next_instruction!=NULL && next_next_next_instruction->instruction_icode==IMOVE &&
								next_next_next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
								next_next_next_instruction->instruction_parameters[0].parameter_data.reg.r==d_reg2 &&
								next_next_next_instruction->instruction_parameters[1].parameter_type==P_INDEXED &&
								next_next_next_instruction->instruction_parameters[1].parameter_data.ir->a_reg.r==reg1 &&
								next_next_next_instruction->instruction_parameters[1].parameter_data.ir->d_reg.r==reg2 &&
								(next_next_next_instruction->instruction_parameters[1].parameter_offset & 3)==(store_offset & 3)
							){
								/* ldr->str_indexed ldr->str_indexed */
								int reg_s,shift;

								reg_s = d_reg!=REGISTER_S0 && d_reg2!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;
								if (reg_s!=d_reg && reg_s!=d_reg2){
									int load_offset2,store_offset2;

									load_offset2=next_next_instruction->instruction_parameters[0].parameter_offset;
									store_offset2=next_next_next_instruction->instruction_parameters[1].parameter_offset;

									w_as_opcode ("add");
									w_as_register_comma (reg_s);
									w_as_register_comma (reg1);
									w_as_lsl_register_newline (reg2,store_offset & 3);

									if (a_reg2!=reg1 && (a_reg2==A_STACK_POINTER || a_reg2==B_STACK_POINTER) && (store_offset & 0xc)==0){
										if (store_offset+(4<<2)==store_offset2){
											if ((store_offset>>2)>=-1020 && (store_offset>>2)<=1020){
												if (d_reg==d_reg2)
													d_reg = reg_s!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

												w_as_ldr_ldr_or_ldrd_id (offset,a_reg,d_reg,load_offset2,a_reg2,d_reg2);

												w_as_strd_register_register_comma (d_reg,d_reg2);
												w_as_indirect_newline (store_offset>>2,reg_s);

												return w_as_more_store_indexed (next_next_next_instruction,reg1,reg2,reg_s,store_offset & 3);
											}
										} else if (store_offset2==store_offset-(4<<2)){
											if (((store_offset-(4<<2))>>2)>=-1020 && ((store_offset-(4<<2))>>2)<=1020){
												if (d_reg==d_reg2)
													d_reg = reg_s!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

												w_as_ldr_ldr_or_ldrd_id (offset,a_reg,d_reg,load_offset2,a_reg2,d_reg2);

												w_as_strd_register_register_comma (d_reg2,d_reg);
												w_as_indirect_newline ((store_offset-4)>>2,reg_s);

												return w_as_more_store_indexed (next_next_next_instruction,reg1,reg2,reg_s,store_offset & 3);
											}
										}
									}

									w_as_opcode_ldr_register_comma (d_reg);
									w_as_indirect_newline (offset,a_reg);

									w_as_opcode_str_register_comma (d_reg);
									w_as_indirect_newline (store_offset>>2,reg_s);

									w_as_opcode_ldr_register_comma (d_reg2);
									w_as_indirect_newline (load_offset2,a_reg2);

									w_as_opcode_str_register_comma (d_reg2);
									w_as_indirect_newline (store_offset2>>2,reg_s);

									return w_as_more_store_indexed (next_next_next_instruction,reg1,reg2,reg_s,store_offset & 3);
								}
							}
						}

						if ((store_offset & -4)!=0){
							int reg_s;

							reg_s = d_reg!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

							w_as_opcode_ldr_register_comma (d_reg);
							w_as_indirect_newline (offset,a_reg);

							w_as_opcode ("add");
							w_as_register_comma (reg_s);
							w_as_register_comma (reg1);
							w_as_immediate_newline (store_offset>>2);

							w_as_opcode_str_register_comma (d_reg);
							w_as_indexed_no_offset_newline (store_offset /* & 3 */,reg_s,reg2);
							return next_instruction;
						}
					}
# endif
				}
#endif

				w_as_opcode_ldr_register_comma (d_reg);
				w_as_indirect_newline (offset,a_reg);
				return instruction;
			}
			case P_INDEXED:
#ifndef NO_OPT_INDEXED
				if ((s_parameter_p->parameter_offset & -4)!=0 && d_reg!=REGISTER_S0){
					int reg1,reg2;

					reg1=s_parameter_p->parameter_data.ir->a_reg.r;
					reg2=s_parameter_p->parameter_data.ir->d_reg.r;

					if (d_reg!=reg1 && d_reg!=reg2){
						struct instruction *instruction2;
						int offset;
						
						offset=s_parameter_p->parameter_offset;

						instruction2=instruction->instruction_next;
						if (instruction2!=NULL && instruction2->instruction_icode==IMOVE){
							if (instruction2->instruction_parameters[0].parameter_type==P_INDEXED &&
								instruction2->instruction_parameters[0].parameter_data.ir->a_reg.r==reg1 &&
								instruction2->instruction_parameters[0].parameter_data.ir->d_reg.r==reg2 &&
								(instruction2->instruction_parameters[0].parameter_offset & 3)==(offset & 3)
							){
								if (instruction2->instruction_parameters[1].parameter_type==P_REGISTER){
									w_as_opcode ("add");
									w_as_register_comma (REGISTER_S0);	
									w_as_register_comma (reg1);
									w_as_lsl_register_newline (reg2,offset & 3);

									if (d_reg!=B_STACK_POINTER &&
										instruction2->instruction_parameters[1].parameter_data.reg.r!=d_reg &&
										instruction2->instruction_parameters[1].parameter_data.reg.r!=B_STACK_POINTER
									){
										struct instruction *instruction3;
										
										instruction3=instruction2->instruction_next;
										if (! (instruction3!=NULL && instruction3->instruction_icode==IMOVE &&
											   instruction3->instruction_parameters[0].parameter_type==P_REGISTER &&
											   instruction3->instruction_parameters[0].parameter_data.reg.r==d_reg &&
											   (instruction3->instruction_parameters[1].parameter_type==P_INDIRECT ||
												instruction3->instruction_parameters[1].parameter_type==P_PRE_DECREMENT ||
												(instruction3->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE &&
										 		 instruction3->instruction_parameters[1].parameter_data.reg.r!=reg1 &&
												 instruction3->instruction_parameters[1].parameter_data.reg.r!=reg2)))
										){
											int use_ldrd,offset2,d_reg2;

											offset2=instruction2->instruction_parameters[0].parameter_offset;
											d_reg2=instruction2->instruction_parameters[1].parameter_data.reg.r;
											
											use_ldrd = index_offset_next_or_previous_aligned (offset,offset2);
											if (use_ldrd){
												if (use_ldrd==1){
													w_as_ldrd_register_register_comma (d_reg,d_reg2);
													w_as_indirect_newline (offset>>2,REGISTER_S0);
												} else {
													w_as_ldrd_register_register_comma (d_reg2,d_reg);
													w_as_indirect_newline (offset2>>2,REGISTER_S0);
												}
												if (d_reg2==reg1 || d_reg2==reg2 || d_reg2==REGISTER_S0)
													return instruction2;

												return w_as_maybe_more_load_indexed (instruction2,reg1,reg2,REGISTER_S0,offset);								
											}
										}
									}

									w_as_opcode_ldr_register_comma (d_reg);
									w_as_indirect_newline (offset>>2,REGISTER_S0);

									return w_as_more_load_indexed (instruction2,reg1,reg2,REGISTER_S0,offset);
								} else if (instruction2->instruction_parameters[1].parameter_type==P_INDIRECT ||
										   instruction2->instruction_parameters[1].parameter_type==P_PRE_DECREMENT ||
										   instruction2->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE
								){
									w_as_opcode ("add");
									w_as_register_comma (REGISTER_S0);	
									w_as_register_comma (reg1);
									w_as_lsl_register_newline (reg2,offset & 3);

									w_as_opcode_ldr_register_comma (d_reg);
									w_as_indirect_newline (offset>>2,REGISTER_S0);

									return w_as_more_load_indexed (instruction2,reg1,reg2,REGISTER_S0,offset);
								}
							}

							if (instruction2->instruction_parameters[0].parameter_type==P_REGISTER &&
								instruction2->instruction_parameters[0].parameter_data.reg.r==d_reg &&
								(instruction2->instruction_parameters[1].parameter_type==P_INDIRECT ||
								 instruction2->instruction_parameters[1].parameter_type==P_PRE_DECREMENT ||
								 (instruction2->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE &&
							 	  instruction2->instruction_parameters[1].parameter_data.reg.r!=reg1 &&
								  instruction2->instruction_parameters[1].parameter_data.reg.r!=reg2))
							){
								struct instruction *instruction3;
								
								instruction3=instruction2->instruction_next;
								if (instruction3!=NULL && instruction3->instruction_icode==IMOVE &&
									instruction3->instruction_parameters[0].parameter_type==P_INDEXED &&
									instruction3->instruction_parameters[0].parameter_data.ir->a_reg.r==reg1 &&
									instruction3->instruction_parameters[0].parameter_data.ir->d_reg.r==reg2 &&
									(instruction3->instruction_parameters[0].parameter_offset & 3)==(offset & 3) &&								
									instruction3->instruction_parameters[1].parameter_type==P_REGISTER
								){
									int d_reg2;

									w_as_opcode ("add");
									w_as_register_comma (REGISTER_S0);	
									w_as_register_comma (reg1);
									w_as_lsl_register_newline (reg2,offset & 3);

									if (instruction2->instruction_parameters[1].parameter_type!=P_INDIRECT){
										w_as_opcode_ldr_register_comma (d_reg);
										w_as_indirect_newline (offset>>2,REGISTER_S0);

										if (instruction2->instruction_parameters[1].parameter_type==P_PRE_DECREMENT){
											w_as_push_r (d_reg);
										} else { /* P_INDIRECT_WITH_UPDATE */
											w_as_opcode_str_register_comma (d_reg);
											w_as_indirect_with_update_newline (instruction2->instruction_parameters[1].parameter_offset,
															  				   instruction2->instruction_parameters[1].parameter_data.reg.r);
										}

										return w_as_more_load_indexed (instruction3,reg1,reg2,REGISTER_S0,offset);
									}

									d_reg2 = instruction3->instruction_parameters[1].parameter_data.reg.r;
									if (d_reg2!=reg1 && d_reg2!=reg2){
										struct instruction *instruction4;
										
										instruction4=instruction3->instruction_next;
										if (instruction4!=NULL && instruction4->instruction_icode==IMOVE &&
											instruction4->instruction_parameters[0].parameter_type==P_REGISTER &&
											instruction4->instruction_parameters[0].parameter_data.reg.r==d_reg2 &&
											instruction4->instruction_parameters[1].parameter_type==P_INDIRECT
										){
											int store_a_reg1,store_a_reg2,load_offset2,store_offset1,store_offset2;
											
											store_a_reg1=instruction2->instruction_parameters[1].parameter_data.reg.r;
											store_offset1=instruction2->instruction_parameters[1].parameter_offset;
											load_offset2=instruction3->instruction_parameters[0].parameter_offset;
											store_a_reg2=instruction4->instruction_parameters[1].parameter_data.reg.r;
											store_offset2=instruction4->instruction_parameters[1].parameter_offset;
											
											if (store_a_reg1!=d_reg2 && store_a_reg1!=reg1 && (store_a_reg1==A_STACK_POINTER || store_a_reg1==B_STACK_POINTER) &&
												d_reg!=B_STACK_POINTER && d_reg2!=B_STACK_POINTER
											){
												int use_ldrd,use_strd;
												
												use_ldrd = index_offset_next_or_previous_aligned (offset,load_offset2);
												use_strd = store_a_reg1==store_a_reg2 ? indirect_offset_next_or_previous_aligned (store_offset1,store_offset2) : 0;

												if (use_ldrd || use_strd){
													if (d_reg==d_reg2)
														d_reg = REGISTER_S1;

													if (use_ldrd){
														if (use_ldrd==1){
															w_as_ldrd_register_register_comma (d_reg,d_reg2);
															w_as_indirect_newline (offset>>2,REGISTER_S0);
														} else {
															w_as_ldrd_register_register_comma (d_reg2,d_reg);
															w_as_indirect_newline (load_offset2>>2,REGISTER_S0);
														}
													} else {
														w_as_opcode_ldr_register_comma (d_reg);
														w_as_indirect_newline (offset>>2,REGISTER_S0);

														w_as_opcode_ldr_register_comma (d_reg2);
														w_as_indirect_newline (load_offset2>>2,REGISTER_S0);
													}
													if (use_strd){
														if (use_strd==1){
															w_as_strd_register_register_comma (d_reg,d_reg2);
															w_as_indirect_newline (store_offset1,store_a_reg1);
														} else {
															w_as_strd_register_register_comma (d_reg2,d_reg);
															w_as_indirect_newline (store_offset2,store_a_reg1);
														}
													} else {
														w_as_opcode_str_register_comma (d_reg);
														w_as_indirect_newline (store_offset1,store_a_reg1);

														w_as_opcode_str_register_comma (d_reg2);
														w_as_indirect_newline (store_offset2,store_a_reg2);
													}
												} else {
													w_as_opcode_ldr_register_comma (d_reg);
													w_as_indirect_newline (offset>>2,REGISTER_S0);

													w_as_opcode_str_register_comma (d_reg);
													w_as_indirect_newline (store_offset1,store_a_reg1);

													w_as_opcode_ldr_register_comma (d_reg2);
													w_as_indirect_newline (load_offset2>>2,REGISTER_S0);

													w_as_opcode_str_register_comma (d_reg2);
													w_as_indirect_newline (store_offset2,store_a_reg2);
												}
											} else {
												w_as_opcode_ldr_register_comma (d_reg);
												w_as_indirect_newline (offset>>2,REGISTER_S0);
												
												w_as_opcode_str_register_comma (d_reg);
												w_as_indirect_newline (store_offset1,store_a_reg1);

												w_as_opcode_ldr_register_comma (d_reg2);
												w_as_indirect_newline (load_offset2>>2,REGISTER_S0);

												w_as_opcode_str_register_comma (d_reg2);
												w_as_indirect_newline (store_offset2,store_a_reg2);
											}
											
											return w_as_maybe_more_load_indexed (instruction4,reg1,reg2,REGISTER_S0,offset);
										}
									}

									w_as_opcode_ldr_register_comma (d_reg);
									w_as_indirect_newline (offset>>2,REGISTER_S0);

									w_as_opcode_str_register_comma (d_reg);
									w_as_indirect_newline (instruction2->instruction_parameters[1].parameter_offset,
														   instruction2->instruction_parameters[1].parameter_data.reg.r);

									return w_as_more_load_indexed (instruction3,reg1,reg2,REGISTER_S0,offset);
								}
							}

							if (instruction2->instruction_parameters[0].parameter_type==P_REGISTER &&
								instruction2->instruction_parameters[1].parameter_type==P_INDEXED
							){
								struct instruction *instruction3;
								
								instruction3=instruction2->instruction_next;
								if (instruction3!=NULL && instruction3->instruction_icode==IMOVE &&
									instruction3->instruction_parameters[0].parameter_type==P_INDEXED &&
									instruction3->instruction_parameters[0].parameter_data.ir->a_reg.r==reg1 &&
									instruction3->instruction_parameters[0].parameter_data.ir->d_reg.r==reg2 &&
									(instruction3->instruction_parameters[0].parameter_offset & 3)==(offset & 3) &&								
									instruction3->instruction_parameters[1].parameter_type==P_REGISTER
								)
									return w_as_move_indexed_load_store_sequence (instruction);
							}
						}
					}
				}
#endif

				w_as_ld_indexed (s_parameter_p,d_reg,SIZE_LONG);
				return instruction;
			case P_INDIRECT_WITH_UPDATE:
				w_as_opcode_ldr_register_comma (d_reg);
				w_as_indirect_with_update_newline (s_parameter_p->parameter_offset,s_parameter_p->parameter_data.reg.r);
				return instruction;
			case P_POST_INCREMENT:
			{
				struct instruction *next_instruction;

				next_instruction=instruction->instruction_next;
				if (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
					next_instruction->instruction_parameters[0].parameter_type==P_POST_INCREMENT &&
					next_instruction->instruction_parameters[0].parameter_data.reg.r==B_STACK_POINTER &&
					next_instruction->instruction_parameters[1].parameter_type==P_REGISTER &&
					reg_num (next_instruction->instruction_parameters[1].parameter_data.reg.r) > reg_num (d_reg)
				){
					int last_popped_reg;

					w_as_opcode ("pop");
					fprintf (assembly_file,"{");
					w_as_register (d_reg);

					do {
						last_popped_reg = next_instruction->instruction_parameters[1].parameter_data.reg.r;
						w_as_comma_register (last_popped_reg);
							
						instruction=next_instruction;
						next_instruction=instruction->instruction_next;
					} while (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
						next_instruction->instruction_parameters[0].parameter_type==P_POST_INCREMENT &&
						next_instruction->instruction_parameters[0].parameter_data.reg.r==B_STACK_POINTER &&
						next_instruction->instruction_parameters[1].parameter_type==P_REGISTER &&
						reg_num (next_instruction->instruction_parameters[1].parameter_data.reg.r) > reg_num (last_popped_reg));

					if (next_instruction!=NULL && next_instruction->instruction_icode==IRTS){
						add_pc_to_pop();
						return next_instruction;
					}

					fprintf (assembly_file,"}");
					w_as_newline_after_instruction();

					return instruction;
				} else if (next_instruction!=NULL && next_instruction->instruction_icode==IRTS){
					w_as_opcode ("pop");
					fprintf (assembly_file,"{");
					w_as_register (d_reg);
					add_pc_to_pop();

					return next_instruction;
				} else {
					w_as_pop_r (d_reg);

					return instruction;
				}
			}
			case P_INDIRECT_POST_ADD:
				w_as_opcode_ldr_register_comma (d_reg);
				w_as_indirect_post_add_newline (s_parameter_p->parameter_offset,s_parameter_p->parameter_data.reg.r);
				return instruction;
			case P_LABEL:
				w_as_opcode_mov();
				w_as_label_parameter (s_parameter_p);
				w_as_comma_register (d_reg);
				w_as_newline_after_instruction();
				return instruction;
			case P_INDIRECT_ANY_ADDRESS:
				w_as_opcode_ldr_register_comma (d_reg);
				w_as_indirect_newline (s_parameter_p->parameter_offset,s_parameter_p->parameter_data.reg.r);
				return instruction;
			default:
				internal_error_in_function ("w_as_move_instruction");
				return instruction;
		}
	} else {
		struct parameter s_parameter;

		s_parameter=*s_parameter_p;
		d_parameter_p=&instruction->instruction_parameters[1];

		switch (s_parameter.parameter_type){
			case P_REGISTER:
				s_reg=s_parameter.parameter_data.reg.r;
				break;
			case P_INDIRECT:

#ifndef NO_STRD
				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT){
					int sa_reg,offset;
					struct instruction *next_instruction;

					sa_reg=instruction->instruction_parameters[1].parameter_data.reg.r;
					offset=instruction->instruction_parameters[1].parameter_offset;

					next_instruction=instruction->instruction_next;
					if (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
						next_instruction->instruction_parameters[0].parameter_type==P_INDIRECT
					){
						if (next_instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
							next_instruction->instruction_parameters[1].parameter_data.reg.r==sa_reg)
						{
							int la2_reg;
							
							la2_reg = next_instruction->instruction_parameters[0].parameter_data.reg.r;
							
							/* do ldr before str ? */
							if (la2_reg==sa_reg
								? (next_instruction->instruction_parameters[0].parameter_offset+4<=offset ||
								   next_instruction->instruction_parameters[0].parameter_offset>=offset+4)
								: (la2_reg==A_STACK_POINTER || la2_reg==B_STACK_POINTER || sa_reg==A_STACK_POINTER || sa_reg==B_STACK_POINTER)
							){
								/* ldr->str ldr->str */
								if ((offset & 3)==0){
									if (next_instruction->instruction_parameters[1].parameter_offset==offset+4){
										if (offset>=-1020 && offset<=1020){
											w_as_ldr_ldr_or_ldrd
												(s_parameter.parameter_offset,s_parameter.parameter_data.reg.r,REGISTER_S0,
												 next_instruction->instruction_parameters[0].parameter_offset,la2_reg,REGISTER_S1);

											w_as_strd_register_register_comma (REGISTER_S0,REGISTER_S1);
											w_as_indirect_newline (offset,sa_reg);
											return next_instruction;
										}
									} else if (next_instruction->instruction_parameters[1].parameter_offset==offset-4){
										if (offset-4>=-1020 && offset-4<=1020){
											w_as_ldr_ldr_or_ldrd
												(s_parameter.parameter_offset,s_parameter.parameter_data.reg.r,REGISTER_S0,
												 next_instruction->instruction_parameters[0].parameter_offset,la2_reg,REGISTER_S1);

											w_as_strd_register_register_comma (REGISTER_S1,REGISTER_S0);
											w_as_indirect_newline (offset-4,sa_reg);
											return next_instruction;
										}
									}
								}
							}
						}
# ifndef NO_LDRD
						if (next_instruction->instruction_parameters[0].parameter_data.reg.r==s_parameter.parameter_data.reg.r){
							if (next_instruction->instruction_parameters[1].parameter_type==P_REGISTER){
								int la2_reg;
								
								la2_reg = next_instruction->instruction_parameters[0].parameter_data.reg.r;
								if (la2_reg==sa_reg
									? (next_instruction->instruction_parameters[0].parameter_offset+4<=offset ||
									   next_instruction->instruction_parameters[0].parameter_offset>=offset+4)
									: (la2_reg==A_STACK_POINTER || la2_reg==B_STACK_POINTER || sa_reg==A_STACK_POINTER || sa_reg==B_STACK_POINTER)
								){
									if (next_instruction->instruction_parameters[1].parameter_data.reg.r!=sa_reg &&
										next_instruction->instruction_parameters[1].parameter_data.reg.r!=REGISTER_S0
									){
										/* ldr->str ldr */
										if ((s_parameter.parameter_offset & 3)==0 &&
											next_instruction->instruction_parameters[1].parameter_data.reg.r!=B_STACK_POINTER
										){
											if (next_instruction->instruction_parameters[0].parameter_offset==s_parameter.parameter_offset+4){
												if (s_parameter.parameter_offset>=-1020 && s_parameter.parameter_offset<=1020){
													w_as_ldrd_register_register_comma (REGISTER_S0,next_instruction->instruction_parameters[1].parameter_data.reg.r);
													w_as_indirect_newline (s_parameter.parameter_offset,la2_reg);

													/* parameters of instruction not used below */
													instruction=next_instruction;
													s_reg = REGISTER_S0;
													break;
												}
											} else if (next_instruction->instruction_parameters[0].parameter_offset==s_parameter.parameter_offset-4){
												if (next_instruction->instruction_parameters[0].parameter_offset>=-1020 && next_instruction->instruction_parameters[0].parameter_offset<=1020){
													w_as_ldrd_register_register_comma (next_instruction->instruction_parameters[1].parameter_data.reg.r,REGISTER_S0);
													w_as_indirect_newline (next_instruction->instruction_parameters[0].parameter_offset,la2_reg);

													/* parameters of instruction not used below */
													instruction=next_instruction;
													s_reg = REGISTER_S0;
													break;
												}
											}
										}
									}
								}
							} else {
								/* ldr->str ldr-> */
								if (sa_reg==s_parameter.parameter_data.reg.r &&
									(next_instruction->instruction_parameters[0].parameter_offset+4<=offset ||
									 next_instruction->instruction_parameters[0].parameter_offset>=offset+4)
								){
									if (sa_reg!=REGISTER_S0){
										int offset1;
										
										offset1=s_parameter.parameter_offset;
										if ((offset1 & 3)==0){
											int offset2;
											
											offset2=next_instruction->instruction_parameters[0].parameter_offset;
											if (offset2==offset1+4){
												w_as_ldrd_register_register_comma (REGISTER_S0,REGISTER_S1);
												w_as_indirect_newline (offset1,sa_reg);
												
												w_as_opcode_str_register_comma (REGISTER_S0);
												w_as_indirect_newline (offset,sa_reg);

												d_parameter_p=&next_instruction->instruction_parameters[1];
												instruction=next_instruction;
												s_reg = REGISTER_S1;
												break;
											} else if (offset2==offset1-4){
												w_as_ldrd_register_register_comma (REGISTER_S1,REGISTER_S0);
												w_as_indirect_newline (offset2,sa_reg);
												
												w_as_opcode_str_register_comma (REGISTER_S0);
												w_as_indirect_newline (offset,sa_reg);

												d_parameter_p=&next_instruction->instruction_parameters[1];
												instruction=next_instruction;
												s_reg = REGISTER_S1;
												break;
											}
										}
									}
								}
							}
						}
# endif
					}
				}
#endif

				w_as_opcode_ldr();
				w_as_scratch_register_comma();
				w_as_indirect_newline (s_parameter.parameter_offset,s_parameter.parameter_data.reg.r);
				s_reg = REGISTER_S0;
				break;
			case P_INDEXED:

#ifndef NO_OPT_INDEXED
				if ((s_parameter.parameter_offset & -4)!=0 &&
					(d_parameter_p->parameter_type==P_INDIRECT ||
					 d_parameter_p->parameter_type==P_PRE_DECREMENT ||
					 d_parameter_p->parameter_type==P_INDIRECT_WITH_UPDATE)
				){
					int reg1,reg2;

					reg1=s_parameter.parameter_data.ir->a_reg.r;
					reg2=s_parameter.parameter_data.ir->d_reg.r;

					if (! (d_parameter_p->parameter_type==P_INDIRECT_WITH_UPDATE &&
						   (d_parameter_p->parameter_data.reg.r==reg1 || d_parameter_p->parameter_data.reg.r==reg2))
					){
						struct instruction *instruction2;
						int offset;

						offset=s_parameter.parameter_offset;

						instruction2=instruction->instruction_next;
						if (instruction2!=NULL && instruction2->instruction_icode==IMOVE &&
							instruction2->instruction_parameters[0].parameter_type==P_INDEXED &&
							instruction2->instruction_parameters[0].parameter_data.ir->a_reg.r==reg1 &&
							instruction2->instruction_parameters[0].parameter_data.ir->d_reg.r==reg2 &&
							(instruction2->instruction_parameters[0].parameter_offset & 3)==(offset & 3) &&
							(instruction2->instruction_parameters[1].parameter_type==P_REGISTER ||
							 instruction2->instruction_parameters[1].parameter_type==P_INDIRECT ||
							 instruction2->instruction_parameters[1].parameter_type==P_PRE_DECREMENT ||
							 instruction2->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE)
						){
							w_as_opcode ("add");
							w_as_register_comma (REGISTER_S0);
							w_as_register_comma (reg1);
							w_as_lsl_register_newline (reg2,offset & 3);

							w_as_opcode_ldr_register_comma (REGISTER_S1);
							w_as_indirect_newline (offset>>2,REGISTER_S0);

							if (d_parameter_p->parameter_type==P_INDIRECT){
								w_as_opcode_str_register_comma (REGISTER_S1);
								w_as_indirect_newline (d_parameter_p->parameter_offset,d_parameter_p->parameter_data.reg.r);
							} else if (d_parameter_p->parameter_type==P_PRE_DECREMENT || 
								/* P_INDIRECT_WITH_UPDATE */
								(d_parameter_p->parameter_data.reg.r==B_STACK_POINTER && d_parameter_p->parameter_offset==-4)
							){
								w_as_push_r (REGISTER_S1);
								w_as_newline_after_instruction();					
							} else {
								w_as_opcode_str_register_comma (REGISTER_S1);
								w_as_indirect_with_update_newline (d_parameter_p->parameter_offset,
							 									   d_parameter_p->parameter_data.reg.r);
							}

							return w_as_more_load_indexed (instruction2,reg1,reg2,REGISTER_S0,offset);
						}
					}
				}
#endif

				w_as_ld_indexed (&s_parameter,REGISTER_S0,SIZE_LONG);
				s_reg = REGISTER_S0;
				break;
			case P_DESCRIPTOR_NUMBER:
				w_as_opcode_ldr();
				w_as_scratch_register();
				w_as_comma();
				w_as_descriptor (s_parameter.parameter_data.l,s_parameter.parameter_offset);
				w_as_newline_after_instruction();
				s_reg = REGISTER_S0;
				break;
			case P_IMMEDIATE:
				w_as_ld_immediate (s_parameter_p->parameter_data.i,REGISTER_S0);
				s_reg = REGISTER_S0;
				break;
			case P_POST_INCREMENT:
				w_as_pop_r (REGISTER_S0);
				s_reg = REGISTER_S0;
				break;
			case P_INDIRECT_WITH_UPDATE:
				w_as_opcode_ldr();
				w_as_scratch_register_comma();
				w_as_indirect_with_update (s_parameter.parameter_offset,s_parameter.parameter_data.reg.r);
				w_as_newline_after_instruction();
				s_reg = REGISTER_S0;
				break;
			case P_INDIRECT_POST_ADD:
				w_as_opcode_ldr();
				w_as_scratch_register_comma();
				w_as_indirect_post_add (s_parameter.parameter_offset,s_parameter.parameter_data.reg.r);
				w_as_newline_after_instruction();
				s_reg = REGISTER_S0;
				break;
			default:
				internal_error_in_function ("w_as_move_instruction");
				return instruction;
		}
	}

	switch (d_parameter_p->parameter_type){
		case P_INDIRECT:
#ifndef NO_STRD
			return w_as_str_or_strd_id (instruction,d_parameter_p,s_reg);
#else
			w_as_opcode_str_register_comma (s_reg);
			w_as_indirect_newline (d_parameter_p->parameter_offset,d_parameter_p->parameter_data.reg.r);
			return instruction;
#endif
		case P_PRE_DECREMENT:
			return w_as_push (instruction,s_reg);
		case P_INDEXED:
		{
			int offset;

			offset=d_parameter_p->parameter_offset;
			if ((offset & -4)!=0){
				int reg1,reg2,reg3;

				reg1=d_parameter_p->parameter_data.ir->a_reg.r;
				reg2=d_parameter_p->parameter_data.ir->d_reg.r;

				if (s_reg==REGISTER_S0)
					reg3=REGISTER_S1;
				else
					reg3=REGISTER_S0;

#ifndef NO_OPT_INDEXED
				{
					struct instruction *next_instruction;

					next_instruction=instruction->instruction_next;
					if (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
						next_instruction->instruction_parameters[1].parameter_type==P_INDEXED &&
						next_instruction->instruction_parameters[1].parameter_data.ir->a_reg.r==reg1 &&
						next_instruction->instruction_parameters[1].parameter_data.ir->d_reg.r==reg2 &&
						(next_instruction->instruction_parameters[1].parameter_offset & 3)==(offset & 3) &&
						(next_instruction->instruction_parameters[0].parameter_type==P_REGISTER ||
						 next_instruction->instruction_parameters[0].parameter_type==P_INDIRECT)
					){
						int use_strd;
						
						w_as_opcode ("add");
						w_as_register_comma (reg3);	
						w_as_register_comma (reg1);
						w_as_lsl_register_newline (reg2,offset & 3);

						use_strd = index_next_or_previous_aligned (next_instruction,s_reg,offset);
						if (use_strd){
							int s_reg2;
						
							s_reg2=next_instruction->instruction_parameters[0].parameter_data.reg.r;
							if (use_strd==1){
								w_as_strd_register_register_comma (s_reg,s_reg2);
								w_as_indirect_newline (offset>>2,reg3);
							} else {
								w_as_strd_register_register_comma (s_reg2,s_reg);
								w_as_indirect_newline ((offset-(4<<2))>>2,reg3);
							}
							
							instruction=next_instruction;
						} else {
							w_as_opcode_str_register_comma (s_reg);
							w_as_indirect_newline (offset>>2,reg3);
						}

						return w_as_more_store_indexed (instruction,reg1,reg2,reg3,offset & 3);
					}
				}
#endif

				w_as_opcode ("add");
				w_as_register_comma (reg3);	
				w_as_register_comma (reg1);
				w_as_immediate_newline (offset>>2);

				w_as_opcode_str_register_comma (s_reg);
				w_as_indexed_no_offset_newline (offset,reg3,reg2);
			} else {
				w_as_opcode_str_register_comma (s_reg);
				w_as_indexed_no_offset_ir_newline (offset,d_parameter_p->parameter_data.ir);
			}
			return instruction;
		}
		case P_INDIRECT_WITH_UPDATE:
			if (d_parameter_p->parameter_data.reg.r==B_STACK_POINTER && d_parameter_p->parameter_offset==-4){
				w_as_push_r (s_reg);
			} else {

#if 0
				/* not yet implemented in cgtas.c */
#ifndef NO_STRD
				if (d_parameter_p->parameter_offset==-8){
					struct instruction *next_instruction;

					next_instruction=instruction->instruction_next;
					if (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
						next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
						next_instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
						next_instruction->instruction_parameters[1].parameter_offset==4 &&
						next_instruction->instruction_parameters[1].parameter_data.reg.r==d_parameter_p->parameter_data.reg.r
					){
						if (d_parameter_p->parameter_data.reg.r==B_STACK_POINTER && s_reg!=B_STACK_POINTER &&
							next_instruction->instruction_parameters[0].parameter_data.reg.r!=B_STACK_POINTER &&
							reg_num (s_reg) < reg_num (next_instruction->instruction_parameters[0].parameter_data.reg.r)
						){
							w_as_opcode ("push");
							fprintf (assembly_file,"{");
							w_as_register_comma (s_reg);
							w_as_register (next_instruction->instruction_parameters[0].parameter_data.reg.r);
							fprintf (assembly_file,"}");
							w_as_newline_after_instruction();					
						
							return next_instruction;
						}
					}
				}
#endif
#endif
				w_as_opcode_str_register_comma (s_reg);
				w_as_indirect_with_update_newline (d_parameter_p->parameter_offset,
												   d_parameter_p->parameter_data.reg.r);
			}
			return instruction;
		case P_INDIRECT_POST_ADD:
			if (d_parameter_p->parameter_offset==4 && reg_num (s_reg)<8 && reg_num (d_parameter_p->parameter_data.reg.r)<8){
				w_as_opcode ("stmia");
				w_as_register (d_parameter_p->parameter_data.reg.r);
				fprintf (assembly_file,"!,{");
				w_as_register (s_reg);
				fprintf (assembly_file,"}");
				w_as_newline_after_instruction();
				return instruction;
			}

			w_as_opcode_str_register_comma (s_reg);
			w_as_indirect_post_add_newline (d_parameter_p->parameter_offset,
											d_parameter_p->parameter_data.reg.r);
			return instruction;
		case P_LABEL:
			w_as_opcode_mov();
			w_as_register_comma (s_reg);
			w_as_label_parameter (d_parameter_p);
			w_as_newline_after_instruction();
			return instruction;
		case P_INDIRECT_ANY_ADDRESS:
			w_as_opcode_str_register_comma (s_reg);
			w_as_indirect_newline (d_parameter_p->parameter_offset,d_parameter_p->parameter_data.reg.r);
			return instruction;
		default:
			internal_error_in_function ("w_as_move_instruction");
	}

	return instruction;
}

static struct instruction *w_as_move_instruction_may_modify_condition_flags (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		int i;
				
		i=instruction->instruction_parameters[0].parameter_data.i;
		if (i>=0 && i<256){
			if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
				int d_reg;

				d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

				if (reg_num (d_reg)<8)
					w_as_opcode ("movs");
				else
					w_as_opcode_mov();
				w_as_register_comma (d_reg);
				w_as_immediate_newline (i);

				return instruction;
			} else {
				struct parameter s_parameter;
				
				w_as_opcode ("movs");
				w_as_scratch_register_comma();
				w_as_immediate_newline (i);
				w_as_ld_immediate (i,REGISTER_S0);

				s_parameter.parameter_type=P_REGISTER;
				s_parameter.parameter_data.reg.r=REGISTER_S0;

				return w_as_move_instruction (&s_parameter,instruction);
			}
		}
	}

	return w_as_move_instruction (&instruction->instruction_parameters[0],instruction);
}

static void w_as_move_byte_or_word_instruction (struct instruction *instruction,int size_flag)
{
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_DESCRIPTOR_NUMBER:
				w_as_opcode_ldr();
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_descriptor (instruction->instruction_parameters[0].parameter_data.l,
								 instruction->instruction_parameters[0].parameter_offset);
				w_as_newline_after_instruction();
				return;
			case P_IMMEDIATE:
				w_as_ld_immediate (instruction->instruction_parameters[0].parameter_data.i,
								   instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_REGISTER:
				w_as_opcode_mov();
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_register (instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_newline_after_instruction();
				return;
			case P_INDIRECT:
				w_as_opcode_load (size_flag);
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_indirect_newline (instruction->instruction_parameters[0].parameter_offset,
									   instruction->instruction_parameters[0].parameter_data.reg.r);
				return;
			case P_INDEXED:
				w_as_ld_indexed (&instruction->instruction_parameters[0],
								 instruction->instruction_parameters[1].parameter_data.reg.r,size_flag);
				return;
			case P_INDIRECT_WITH_UPDATE:
				w_as_opcode_load (size_flag);
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_indirect_with_update_newline (instruction->instruction_parameters[0].parameter_offset,
												   instruction->instruction_parameters[0].parameter_data.reg.r);
				return;
			case P_POST_INCREMENT:
				w_as_pop_r (instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_INDIRECT_POST_ADD:
				w_as_opcode_ldr();
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_indirect_post_add_newline (instruction->instruction_parameters[0].parameter_offset,
												instruction->instruction_parameters[0].parameter_data.reg.r);
				return;
			case P_LABEL:
				w_as_opcode_mov();
				w_as_label_parameter (&instruction->instruction_parameters[0]);
				w_as_comma_register (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_newline_after_instruction();
				return;
		}
		internal_error_in_function ("w_as_move_byte_or_word_instruction");
		return;
	} else {
		struct parameter parameter;
		int s_reg;

		parameter=instruction->instruction_parameters[0];

		switch (parameter.parameter_type){
			case P_REGISTER:
				s_reg=parameter.parameter_data.reg.r;
				break;
			case P_INDIRECT:
				w_as_opcode_load (size_flag);
				w_as_scratch_register_comma();
				w_as_indirect_newline (parameter.parameter_offset,parameter.parameter_data.reg.r);
				s_reg = REGISTER_S0;
				break;
			case P_INDEXED:
				w_as_ld_indexed (&parameter,REGISTER_S0,size_flag);
				s_reg = REGISTER_S0;
				break;
			case P_DESCRIPTOR_NUMBER:
				w_as_opcode_ldr();
				w_as_scratch_register();
				w_as_comma();
				w_as_descriptor (parameter.parameter_data.l,parameter.parameter_offset);
				w_as_newline_after_instruction();
				s_reg = REGISTER_S0;
				break;
			case P_IMMEDIATE:
				w_as_ld_immediate (instruction->instruction_parameters[0].parameter_data.i,REGISTER_S0);
				s_reg = REGISTER_S0;
				break;
			case P_POST_INCREMENT:
				w_as_pop_r (REGISTER_S0);
				s_reg = REGISTER_S0;
				break;
			case P_INDIRECT_WITH_UPDATE:
				w_as_opcode_ldr();
				w_as_scratch_register_comma();
				w_as_indirect_with_update (parameter.parameter_offset,parameter.parameter_data.reg.r);
				w_as_newline_after_instruction();
				s_reg = REGISTER_S0;
				break;
			case P_INDIRECT_POST_ADD:
				w_as_opcode_ldr();
				w_as_scratch_register_comma();
				w_as_indirect_post_add (parameter.parameter_offset,parameter.parameter_data.reg.r);
				w_as_newline_after_instruction();
				s_reg = REGISTER_S0;
				break;
			default:
				internal_error_in_function ("w_as_move_byte_or_word_instruction");
				return;
		}

		switch (instruction->instruction_parameters[1].parameter_type){
			case P_INDIRECT:
				w_as_opcode (size_flag==SIZE_WORD ? "strh" : "strb");
				w_as_register_comma (s_reg);
				w_as_indirect_newline (instruction->instruction_parameters[1].parameter_offset,
									   instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_PRE_DECREMENT:
				w_as_push_r (s_reg);
				return;
			case P_INDEXED:
			{
				int offset;

				offset=instruction->instruction_parameters[1].parameter_offset;
				if ((offset & -4)!=0){
					int reg1,reg2,reg3;
	
					reg1=instruction->instruction_parameters[1].parameter_data.ir->a_reg.r;
					reg2=instruction->instruction_parameters[1].parameter_data.ir->d_reg.r;

					if (s_reg==REGISTER_S0)
						reg3=REGISTER_S1;
					else
						reg3=REGISTER_S0;

					w_as_opcode ("add");
					w_as_register_comma (reg3);	
					w_as_register_comma (reg1);
					w_as_immediate_newline (offset>>2);

					w_as_opcode_store (size_flag);
					w_as_register_comma (s_reg);
					w_as_indexed_no_offset_newline (offset,reg3,reg2);
				} else {
					w_as_opcode_store (size_flag);
					w_as_register_comma (s_reg);
					w_as_indexed_no_offset_ir_newline (instruction->instruction_parameters[1].parameter_offset,
													   instruction->instruction_parameters[1].parameter_data.ir);
				}
				return;
			}
			case P_INDIRECT_WITH_UPDATE:
				w_as_opcode (size_flag==SIZE_WORD ? "strh" : "strb");
				w_as_register_comma (s_reg);
				w_as_indirect_with_update_newline (instruction->instruction_parameters[1].parameter_offset,
												   instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_INDIRECT_POST_ADD:
				w_as_opcode (size_flag==SIZE_WORD ? "strh" : "strb");
				w_as_register_comma (s_reg);
				w_as_indirect_post_add_newline (instruction->instruction_parameters[1].parameter_offset,
												instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_LABEL:
				w_as_opcode_mov();
				w_as_register_comma (s_reg);
				w_as_label_parameter (&instruction->instruction_parameters[1]);
				w_as_newline_after_instruction();
				return;
			default:
				internal_error_in_function ("w_as_move_byte_or_word_instruction");
		}
	}
}

static void w_as_movem_instruction (struct instruction *instruction)
{
	int n_regs,n;
	unsigned short register_list;
	
	n_regs = instruction->instruction_arity-1;
	register_list = 0u;
	
	if (instruction->instruction_parameters[0].parameter_type!=P_REGISTER){
		int s_reg;

		s_reg = instruction->instruction_parameters[0].parameter_data.reg.r;

		for (n=0; n<n_regs; ++n)
			register_list |= 1u << (unsigned)reg_num(instruction->instruction_parameters[1+n].parameter_data.reg.r);

		if (instruction->instruction_parameters[0].parameter_type==P_PRE_DECREMENT){
			w_as_opcode ("ldmdb");
			w_as_register (s_reg);
			fprintf (assembly_file,"!,");
		} else if (instruction->instruction_parameters[0].parameter_type==P_POST_INCREMENT){
			if (s_reg==B_STACK_POINTER && (register_list & ~0xff)==0)
				w_as_opcode ("pop");
			else {
				w_as_opcode ("ldmia");
				w_as_register (s_reg);
				fprintf (assembly_file,"!,");
			}
		} else {
			internal_error_in_function ("w_as_movem_instruction");
			return;
		}
	} else {
		int d_reg,n;
		
		d_reg = instruction->instruction_parameters[n_regs].parameter_data.reg.r;

		for (n=0; n<n_regs; ++n)
			register_list |= 1u << (unsigned)reg_num(instruction->instruction_parameters[n].parameter_data.reg.r);

		if (instruction->instruction_parameters[n_regs].parameter_type==P_PRE_DECREMENT){
			if (d_reg==B_STACK_POINTER && (register_list & ~0xff)==0){
				w_as_opcode ("push");
			} else {
				w_as_opcode ("stmdb");
				w_as_register (d_reg);
				fprintf (assembly_file,"!,");
			}
		} else if (instruction->instruction_parameters[n_regs].parameter_type==P_POST_INCREMENT){
			w_as_opcode ("stmia");
			w_as_register (d_reg);
			fprintf (assembly_file,"!,");
		} else {
			internal_error_in_function ("w_as_movem_instruction");
			return;		
		}
	}

	fprintf (assembly_file,"{");
	n=0;
	while (n<16){
		if (register_list & (1u << (unsigned)n)){
			fprintf (assembly_file,"r%d",n);
			++n;
			while (n<16){
				if (register_list & (1u << (unsigned)n))
					fprintf (assembly_file,",r%d",n);
				++n;
			}
			break;
		} else
			++n;
	}
	fprintf (assembly_file,"}");
	w_as_newline_after_instruction();
}

static void w_as_lea_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_INDIRECT:
				w_as_opcode ("add");
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
				fprintf (assembly_file,"#%d",instruction->instruction_parameters[0].parameter_offset);
				w_as_newline_after_instruction();
				return;
			case P_INDEXED:
				if (instruction->instruction_parameters[0].parameter_offset==0){
					w_as_opcode ("add");
					w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_register_comma (instruction->instruction_parameters[0].parameter_data.ir->a_reg.r);
					w_as_register_newline (instruction->instruction_parameters[0].parameter_data.ir->d_reg.r);
					return;
				}
				break;
			case P_LABEL:
				if (instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET < ltorg_at_instruction_n)
					ltorg_at_instruction_n = instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET;

				w_as_opcode_ldr();
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
				putc ('=',assembly_file);
				w_as_label_parameter (&instruction->instruction_parameters[0]);
				if (instruction->instruction_parameters[0].parameter_offset!=0){
					int offset;

					offset=instruction->instruction_parameters[0].parameter_offset;
					fprintf (assembly_file,offset>=0 ? "+%d" : "%d",offset);
				}
				w_as_newline_after_instruction();
				return;
		}
	}
	internal_error_in_function ("w_as_lea_instruction");
}

static void w_as_dyadic_instruction (struct instruction *instruction,char *opcode)
{
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE &&
		mov_or_mov_not_immediate (instruction->instruction_parameters[0].parameter_data.i))
	{
		w_as_opcode (opcode);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_immediate_newline (instruction->instruction_parameters[0].parameter_data.i);
	} else {
		int reg0;

		reg0 = w_as_register_parameter (&instruction->instruction_parameters[0]);

		w_as_opcode (opcode);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_newline (reg0);
	}
}

static void w_as_add_instruction (struct instruction *instruction)
{
	int reg0,reg1;

	reg1=instruction->instruction_parameters[1].parameter_data.reg.r;
	
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		if (mov_or_mov_not_immediate (instruction->instruction_parameters[0].parameter_data.i)){
			w_as_opcode ("add");
			w_as_register_comma (reg1);
			w_as_register_comma (reg1);
			w_as_immediate_newline (instruction->instruction_parameters[0].parameter_data.i);
			return;
		}
		if ((instruction->instruction_parameters[0].parameter_data.i & ~0xfff)==0){
			w_as_opcode ("addw");
			w_as_register_comma (reg1);
			w_as_register_comma (reg1);
			w_as_immediate_newline (instruction->instruction_parameters[0].parameter_data.i);
			return;
		}
		if ((-instruction->instruction_parameters[0].parameter_data.i & ~0xfff)==0){
			w_as_opcode ("subw");
			w_as_register_comma (reg1);
			w_as_register_comma (reg1);
			w_as_immediate_newline (instruction->instruction_parameters[0].parameter_data.i);
			return;
		}
	}

	reg0 = w_as_register_parameter (&instruction->instruction_parameters[0]);

	w_as_opcode ("add");
	w_as_register_comma (reg1);
	w_as_register_comma (reg1);
	w_as_register_newline (reg0);
}

static void w_as_add_instruction_may_modify_condition_flags (struct instruction *instruction)
{
	int reg0,reg1;

	reg1=instruction->instruction_parameters[1].parameter_data.reg.r;
	
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		int i;
		
		i = instruction->instruction_parameters[0].parameter_data.i;

		if (reg_num (reg1)<8){
			if (i>=0 && i<=255){
				w_as_opcode ("adds");
				w_as_register_comma (reg1);
				w_as_immediate_newline (i);
				return;
			}
			if (i>=-255 && i<0){
				w_as_opcode ("subs");
				w_as_register_comma (reg1);
				w_as_immediate_newline (-i);
				return;
			}
		}
		if (mov_or_mov_not_immediate (i)){
			w_as_opcode ("add");
			w_as_register_comma (reg1);
			w_as_register_comma (reg1);
			w_as_immediate_newline (i);
			return;
		}
		if ((i & ~0xfff)==0){
			w_as_opcode ("addw");
			w_as_register_comma (reg1);
			w_as_register_comma (reg1);
			w_as_immediate_newline (i);
			return;
		}
		if ((-i & ~0xfff)==0){
			w_as_opcode ("subw");
			w_as_register_comma (reg1);
			w_as_register_comma (reg1);
			w_as_immediate_newline (i);
			return;
		}
	}

	reg0 = w_as_register_parameter (&instruction->instruction_parameters[0]);

	w_as_opcode ("add");
	w_as_register_comma (reg1);
	w_as_register_comma (reg1);
	w_as_register_newline (reg0);
}

static void w_as_sub_instruction (struct instruction *instruction)
{
	int reg0,reg1;

	reg1=instruction->instruction_parameters[1].parameter_data.reg.r;
	
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		if (mov_or_mov_not_immediate (instruction->instruction_parameters[0].parameter_data.i)){
			w_as_opcode ("sub");
			w_as_register_comma (reg1);
			w_as_register_comma (reg1);
			w_as_immediate_newline (instruction->instruction_parameters[0].parameter_data.i);
			return;
		}
		if ((instruction->instruction_parameters[0].parameter_data.i & ~0xfff)==0){
			w_as_opcode ("subw");
			w_as_register_comma (reg1);
			w_as_register_comma (reg1);
			w_as_immediate_newline (instruction->instruction_parameters[0].parameter_data.i);
			return;
		}
		if ((-instruction->instruction_parameters[0].parameter_data.i & ~0xfff)==0){
			w_as_opcode ("addw");
			w_as_register_comma (reg1);
			w_as_register_comma (reg1);
			w_as_immediate_newline (instruction->instruction_parameters[0].parameter_data.i);
			return;
		}
	}

	reg0 = w_as_register_parameter (&instruction->instruction_parameters[0]);

	w_as_opcode ("sub");
	w_as_register_comma (reg1);
	w_as_register_comma (reg1);
	w_as_register_newline (reg0);
}

static void w_as_sub_instruction_may_modify_condition_flags (struct instruction *instruction)
{
	int reg0,reg1;

	reg1=instruction->instruction_parameters[1].parameter_data.reg.r;
	
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		int i;
		
		i = instruction->instruction_parameters[0].parameter_data.i;

		if (reg_num (reg1)<8){
			if (i>=0 && i<=255){
				w_as_opcode ("subs");
				w_as_register_comma (reg1);
				w_as_immediate_newline (i);
				return;
			}
			if (i>=-255 && i<0){
				w_as_opcode ("adds");
				w_as_register_comma (reg1);
				w_as_immediate_newline (-i);
				return;
			}
		}
		if (mov_or_mov_not_immediate (i)){
			w_as_opcode ("sub");
			w_as_register_comma (reg1);
			w_as_register_comma (reg1);
			w_as_immediate_newline (i);
			return;
		}
		if ((i & ~0xfff)==0){
			w_as_opcode ("subw");
			w_as_register_comma (reg1);
			w_as_register_comma (reg1);
			w_as_immediate_newline (i);
			return;
		}
		if ((-i & ~0xfff)==0){
			w_as_opcode ("addw");
			w_as_register_comma (reg1);
			w_as_register_comma (reg1);
			w_as_immediate_newline (i);
			return;
		}
	}

	reg0 = w_as_register_parameter (&instruction->instruction_parameters[0]);

	w_as_opcode ("sub");
	w_as_register_comma (reg1);
	w_as_register_comma (reg1);
	w_as_register_newline (reg0);
}

static void w_as_reg_reg_imm_instruction (struct instruction *instruction,char *opcode)
{
	if (mov_or_mov_not_immediate (instruction->instruction_parameters[2].parameter_data.i)){
		w_as_opcode (opcode);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
		w_as_immediate_newline (instruction->instruction_parameters[2].parameter_data.i);
	} else {
		int reg0;

		reg0 = w_as_register_parameter (&instruction->instruction_parameters[2]);

		w_as_opcode (opcode);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
		w_as_register_newline (reg0);
	}
}

static void w_as_reg_reg_imm_shift_instruction_may_modify_condition_flags (struct instruction *instruction,char *opcode,char *opcode_s)
{
	int i;
	
	i = instruction->instruction_parameters[2].parameter_data.i;

	if (reg_num (instruction->instruction_parameters[1].parameter_data.reg.r)<8 &&
		reg_num (instruction->instruction_parameters[0].parameter_data.reg.r)<8 && i>=0 && i<32
	){
		w_as_opcode (opcode_s);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
		w_as_immediate_newline (i);
	} else if (mov_or_mov_not_immediate (i)){
		w_as_opcode (opcode);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
		w_as_immediate_newline (i);
	} else {
		int reg0;

		reg0 = w_as_register_parameter (&instruction->instruction_parameters[2]);

		w_as_opcode (opcode);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
		w_as_register_newline (reg0);
	}
}

static void w_as_mul_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
		int reg0,reg1;

		reg0 = instruction->instruction_parameters[0].parameter_data.reg.r;
		reg1 = instruction->instruction_parameters[1].parameter_data.reg.r;

		if (reg0==reg1){
			w_as_opcode_mov();
			w_as_scratch_register_comma();
			w_as_register (reg0);
			w_as_newline_after_instruction();
			reg0 = REGISTER_S0;
		}

		w_as_opcode ("mul");
		w_as_register_comma (reg1);
		w_as_register_comma (reg0);
		w_as_register_newline (reg1);
	} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
		int reg0;

		reg0 = w_as_register_parameter (&instruction->instruction_parameters[0]);

		w_as_opcode ("mul");
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (reg0);
		w_as_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
	} else {
		int reg0;

		reg0 = w_as_register_parameter (&instruction->instruction_parameters[0]);

		w_as_opcode ("mul");
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (reg0);
		w_as_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
	}
}

static void w_as_shift_instruction (struct instruction *instruction,char *opcode)
{
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		w_as_opcode (opcode);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_immediate_newline (instruction->instruction_parameters[0].parameter_data.i & 31);
	} else {
		w_as_opcode (opcode);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_newline (instruction->instruction_parameters[0].parameter_data.reg.r);
	}
}

static void w_as_shift_instruction_may_modify_condition_flags (struct instruction *instruction,char *opcode,char *opcode_s)
{
	int reg;
	
	reg = instruction->instruction_parameters[1].parameter_data.reg.r;
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		int i;
		
		i = instruction->instruction_parameters[0].parameter_data.i;
		
		if (reg_num (reg)<8 && i>=0 && i<32)
			w_as_opcode (opcode_s);
		else
			w_as_opcode (opcode);
		w_as_register_comma (reg);
		w_as_register_comma (reg);
		w_as_immediate_newline (i & 31);
	} else {
		w_as_opcode (opcode);
		w_as_register_comma (reg);
		w_as_register_comma (reg);
		w_as_register_newline (instruction->instruction_parameters[0].parameter_data.reg.r);
	}
}

static void w_as_cmp_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_DESCRIPTOR_NUMBER:
		{
			int reg1,reg2;
				
			reg1 = w_as_register_parameter (&instruction->instruction_parameters[1]);
			reg2 = reg1!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

			w_as_opcode_ldr();
			w_as_register_comma (reg2);
			w_as_descriptor (instruction->instruction_parameters[0].parameter_data.l,
							 instruction->instruction_parameters[0].parameter_offset);
			w_as_newline_after_instruction();

			w_as_opcode ("cmp");
			w_as_register_comma (reg1);
			w_as_register_newline (reg2);
			return;
		}
		case P_IMMEDIATE:
		{
			int reg1;

			reg1 = w_as_register_parameter (&instruction->instruction_parameters[1]);

			if (mov_or_mov_neg_immediate (instruction->instruction_parameters[0].parameter_data.i)){
				w_as_opcode ("cmp");
				w_as_register_comma (reg1);
				w_as_immediate_newline (instruction->instruction_parameters[0].parameter_data.i);
				return;
			} else {
				int reg2;
				
				reg2 = reg1!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;
				
				w_as_ld_large_immediate (instruction->instruction_parameters[0].parameter_data.i,reg2);
				
				w_as_opcode ("cmp");
				w_as_register_comma (reg1);
				w_as_register_newline (reg2);
				return;
			}
		}
	}

	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		int reg0;

		reg0=w_as_register_parameter (&instruction->instruction_parameters[0]);

		w_as_opcode ("cmp");
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_newline (reg0);
		return;
	}

	internal_error_in_function ("w_as_cmp_instruction");
}

static void w_as_tst_instruction (struct instruction *instruction)
{
	int reg0;

	reg0=w_as_register_parameter (&instruction->instruction_parameters[0]);
	
	w_as_opcode ("cmp");
	w_as_register_comma (reg0);
	w_as_immediate_newline (0);
}

static void w_as_monadic_instruction (struct instruction *instruction,char *opcode)
{
	w_as_opcode (opcode);
	w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
	w_as_register_newline (instruction->instruction_parameters[0].parameter_data.reg.r);
}

static void w_as_clzb_instruction (struct instruction *instruction)
{
	int reg0;

	reg0=w_as_register_parameter (&instruction->instruction_parameters[0]);

	w_as_opcode ("clz");
	w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_register_newline (reg0);
}

static void w_as_btst_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		w_as_opcode ("tst");
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_immediate_newline (instruction->instruction_parameters[0].parameter_data.i);
	} else {
		w_as_opcode_ldr();
		w_as_scratch_register_comma();
		w_as_indirect_newline (instruction->instruction_parameters[1].parameter_offset,instruction->instruction_parameters[1].parameter_data.reg.r);

		w_as_opcode ("tst");
		w_as_scratch_register_comma();
		w_as_immediate_newline (instruction->instruction_parameters[0].parameter_data.i);
	}
}

static void w_as_mulud_instruction (struct instruction *instruction)
{
	int reg0,reg1;

	reg0 = instruction->instruction_parameters[0].parameter_data.reg.r;
	reg1 = instruction->instruction_parameters[1].parameter_data.reg.r;

	w_as_opcode ("umull");
	w_as_register_comma (reg1);
	w_as_register_comma (reg0);
	w_as_register_comma (reg1);
	w_as_register_newline (reg0);
}

void w_as_jmp_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_INDIRECT:
			w_as_opcode_ldr();
			fputs ("pc,",assembly_file);
			w_as_indirect_newline (instruction->instruction_parameters[0].parameter_offset,
								   instruction->instruction_parameters[0].parameter_data.reg.r);
			break;
		case P_REGISTER:
			w_as_opcode_mov();
			fputs ("pc",assembly_file);
			w_as_comma();
			w_as_register_newline (instruction->instruction_parameters[0].parameter_data.reg.r);
			break;
		default:
			w_as_opcode ("b");
			w_as_jump_parameter (&instruction->instruction_parameters[0]);
			w_as_newline_after_instruction();
	}
	write_float_constants();
	w_as_instruction_without_parameters (".ltorg");
	instruction_n_after_ltorg = 0u;
	ltorg_at_instruction_n = 0u-1u;
}

void w_as_jmpp_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_LABEL:
		{
			struct parameter *parameter_p;
			int offset;

			parameter_p=&instruction->instruction_parameters[0];
			offset=parameter_p->parameter_offset;

			if (offset==0){
				w_as_opcode ("bl");
				w_as_label ("profile_t");
				w_as_newline_after_instruction();			
			}
			
			w_as_opcode ("b");
			if (parameter_p->parameter_data.l->label_number!=0)
				w_as_local_label (parameter_p->parameter_data.l->label_number);
			else
				w_as_label (parameter_p->parameter_data.l->label_name);
			
			if (offset!=0)
				fprintf (assembly_file,"+%d",offset);

			w_as_newline_after_instruction();
			break;
		}
		case P_INDIRECT:
			w_as_opcode ("bl");
			w_as_label ("profile_t");
			w_as_newline_after_instruction();

			w_as_opcode ("ldr");
			fputs ("pc,",assembly_file);
			w_as_indirect_newline (instruction->instruction_parameters[0].parameter_offset,
								   instruction->instruction_parameters[0].parameter_data.reg.r);
			break;
		case P_REGISTER:
		{
			int reg_0;

			reg_0=instruction->instruction_parameters[0].parameter_data.reg.r;
			if (reg_0!=REGISTER_A3){
				w_as_opcode ("bl");
				w_as_label ("profile_t");
				w_as_newline_after_instruction();

				w_as_opcode_mov();
				fputs ("pc",assembly_file);
				w_as_comma();
				w_as_register_newline (reg_0);
			} else {
				w_as_opcode ("b");
				w_as_label ("profile_ti");
				w_as_newline_after_instruction();
			}
			break;
		}
		default:
			internal_error_in_function ("w_as_jmpp_instruction");
	}
	write_float_constants();
	w_as_instruction_without_parameters (".ltorg");
	instruction_n_after_ltorg = 0u;
	ltorg_at_instruction_n = 0u-1u;
}

struct call_and_jump {
	struct call_and_jump *cj_next;
	WORD cj_label_id;
	WORD cj_jump_id;
	char *cj_call_label_name;
};

static struct call_and_jump *first_call_and_jump,*last_call_and_jump;

static void w_as_branch_instruction (struct instruction *instruction,char *opcode)
{
	w_as_opcode (opcode);
	if (instruction->instruction_parameters[0].parameter_data.l->label_flags & FAR_CONDITIONAL_JUMP_LABEL){
		struct call_and_jump *new_call_and_jump;
		int label_id;

		label_id=next_label_id++;

		new_call_and_jump=allocate_memory_from_heap (sizeof (struct call_and_jump));

		new_call_and_jump->cj_next=NULL;
		new_call_and_jump->cj_call_label_name=instruction->instruction_parameters[0].parameter_data.l->label_name;
		new_call_and_jump->cj_label_id=label_id;
		new_call_and_jump->cj_jump_id=-1;

		if (first_call_and_jump!=NULL)
			last_call_and_jump->cj_next=new_call_and_jump;
		else
			first_call_and_jump=new_call_and_jump;
		last_call_and_jump=new_call_and_jump;

		w_as_internal_label (label_id);
	} else
		w_as_label_parameter (&instruction->instruction_parameters[0]);
	w_as_newline_after_instruction();
}

static void w_as_test_floating_point_condition_code (void)
{
	w_as_opcode ("fmstat");
	w_as_newline_after_instruction();
}

static void w_as_float_branch_instruction (struct instruction *instruction,char *opcode)
{
	w_as_test_floating_point_condition_code();

	/*            Z N C V
	equal         1 0 1 0
	less than     0 1 0 0
	greater than  0 0 1 0
	unordered     0 0 1 1

	bgt           Z==0 && N==V 
	ble           Z==1 || N!=V
	*/
	w_as_opcode (opcode);
	w_as_label_parameter (&instruction->instruction_parameters[0]);
	w_as_newline_after_instruction();
}

static void w_as_float_branch_vc_and_instruction (struct instruction *instruction,char *opcode)
{
	int label_id;
	
	w_as_test_floating_point_condition_code();

	label_id=next_label_id++;

	w_as_opcode ("bvs");
	w_as_internal_label (label_id);
	w_as_newline();

	w_as_opcode (opcode);
	w_as_label_parameter (&instruction->instruction_parameters[0]);
	w_as_newline_after_instruction();

	w_as_define_internal_label (label_id);
}

static void w_as_float_branch_vs_or_instruction (struct instruction *instruction,char *opcode)
{
	w_as_test_floating_point_condition_code();

	w_as_opcode ("bvs");
	w_as_label_parameter (&instruction->instruction_parameters[0]);
	w_as_newline_after_instruction();

	w_as_opcode (opcode);
	w_as_label_parameter (&instruction->instruction_parameters[0]);
	w_as_newline_after_instruction();
}

static void w_as_jsr_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
		w_as_opcode_ldr();
		w_as_scratch_register_comma();
		w_as_indirect_newline (instruction->instruction_parameters[0].parameter_offset,
							   instruction->instruction_parameters[0].parameter_data.reg.r);

		if (instruction->instruction_arity>1){
			switch (instruction->instruction_parameters[1].parameter_type){
				case P_INDIRECT_WITH_UPDATE:
				{
					int label_id;

					label_id=next_label_id++;

					w_as_opcode ("adr");
					w_as_register_comma (REGISTER_S1);
					fprintf (assembly_file,"i_%d+1",label_id);
					w_as_newline_after_instruction ();

					if (instruction->instruction_parameters[1].parameter_offset==-4){
						w_as_opcode ("push");
						fprintf (assembly_file,"{r14}");
						w_as_newline_after_instruction();
					} else {
						w_as_opcode_str_register_comma (REGISTER_S1);
						fprintf (assembly_file,"[sp,#%d]!",instruction->instruction_parameters[1].parameter_offset);
						w_as_newline_after_instruction();
					}

					w_as_opcode ("blx");
					w_as_scratch_register();
					w_as_newline_after_instruction();
	
					w_as_define_internal_label (label_id);
					return;
				}
			}
		}

		w_as_opcode ("blx");
		w_as_scratch_register();
		w_as_newline_after_instruction();
	} else {
		if (instruction->instruction_arity>1)
			switch (instruction->instruction_parameters[1].parameter_type){
				case P_INDIRECT_WITH_UPDATE:
				{
					int label_id;

					label_id=next_label_id++;

					w_as_opcode ("adr");
					w_as_register_comma (REGISTER_S1);
					fprintf (assembly_file,"i_%d+1",label_id);
					w_as_newline_after_instruction ();

					if (instruction->instruction_parameters[1].parameter_offset==-4){
						w_as_opcode ("push");
						fprintf (assembly_file,"{r14}");
						w_as_newline_after_instruction();
					} else {
						w_as_opcode_str_register_comma (REGISTER_S1);
						fprintf (assembly_file,"[sp,#%d]!",instruction->instruction_parameters[1].parameter_offset);
						w_as_newline_after_instruction();
					}

					if (instruction->instruction_parameters[0].parameter_type==P_REGISTER)
						w_as_opcode ("blx");
					else
						w_as_opcode ("bl");
					w_as_jump_parameter (&instruction->instruction_parameters[0]);
					w_as_newline_after_instruction();

					w_as_define_internal_label (label_id);
					return;
				}
				case P_INDIRECT:
				{
					int label_id,offset;

					label_id=next_label_id++;

					offset=instruction->instruction_parameters[1].parameter_offset;
					if (offset>=0 && (offset & ~0x3fc)==0){
						w_as_opcode ("adr");
						w_as_register_comma (REGISTER_S0);
						fprintf (assembly_file,"i_%d+1",label_id);
						w_as_newline_after_instruction ();

						w_as_opcode_str_register_comma (REGISTER_S0);
						fprintf (assembly_file,"[sp,#%d]",offset);
						w_as_newline_after_instruction();
					} else {
						w_as_opcode ("adr");
						w_as_register_comma (REGISTER_S1);
						fprintf (assembly_file,"i_%d+1",label_id);
						w_as_newline_after_instruction ();

						w_as_opcode_str_register_comma (REGISTER_S1);
						fprintf (assembly_file,"[sp,#%d]",offset);
						w_as_newline_after_instruction();
					}

					if (instruction->instruction_parameters[0].parameter_type==P_REGISTER)
						w_as_opcode ("blx");
					else
						w_as_opcode ("bl");
					w_as_jump_parameter (&instruction->instruction_parameters[0]);
					w_as_newline_after_instruction();

					w_as_define_internal_label (label_id);
					return;
				}
			}
		
		if (instruction->instruction_parameters[0].parameter_type==P_REGISTER)
			w_as_opcode ("blx");
		else
			w_as_opcode ("bl");
		w_as_jump_parameter (&instruction->instruction_parameters[0]);
		w_as_newline_after_instruction();
	}
}

static void w_as_set_condition_instruction (struct instruction *instruction,char *condition,char *inv_condition)
{
	int r;
	
	fprintf (assembly_file,"\tite\t%s",condition);
	w_as_newline_after_instruction();

	r=instruction->instruction_parameters[0].parameter_data.reg.r;

	fprintf (assembly_file,"\tmov%s\t",condition);
	w_as_register (r);
	fprintf (assembly_file,",#1");
	w_as_newline_after_instruction();

	fprintf (assembly_file,"\tmov%s\t",inv_condition);
	w_as_register (r);
	fprintf (assembly_file,",#0");
	w_as_newline_after_instruction();
}

static void w_as_set_float_condition_instruction (struct instruction *instruction,char *condition,char *inv_condition)
{
	w_as_test_floating_point_condition_code();
	w_as_set_condition_instruction (instruction,condition,inv_condition);
}

static void w_as_set_float_vc_and_condition_instruction (struct instruction *instruction,char *condition,char *inv_condition)
{
	w_as_test_floating_point_condition_code();
	w_as_set_condition_instruction (instruction,condition,inv_condition);

	fputs ("\tit\tvs",assembly_file);
	w_as_newline_after_instruction();

	w_as_opcode ("movvs");
	w_as_register (instruction->instruction_parameters[0].parameter_data.reg.r);
	fprintf (assembly_file,",#0");
	w_as_newline_after_instruction();
}

static void w_as_lsr_register_newline (int reg,int shift)
{
	w_as_register (reg);
	fprintf (assembly_file,",lsr #%d",shift);
	w_as_newline_after_instruction();
}

static void w_as_lea_indexed_no_offset_ir (int s_reg,int offset,struct index_registers *index_registers)
{
	w_as_opcode ("add");
	w_as_register_comma (s_reg);
	w_as_register_comma (index_registers->a_reg.r);
	w_as_lsl_register_newline (index_registers->d_reg.r,offset & 3);
	w_as_newline_after_instruction();
}

static void w_as_div_instruction (struct instruction *instruction)
{
	int i,abs_i,d_reg;
	struct ms ms;

	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (instruction->instruction_parameters[0].parameter_type!=P_IMMEDIATE){
		internal_error_in_function ("w_as_div_instruction");
		return;
	}
	i=instruction->instruction_parameters[0].parameter_data.i;

	if (i==0){
		internal_error_in_function ("w_as_div_instruction");
		return;
	}

	abs_i=abs (i);

	if ((abs_i & (abs_i-1))==0){
		int log2i;
		unsigned int i2;

		if (abs_i==1){
			if (i<0){
				w_as_opcode ("neg");
				w_as_register_comma (d_reg);
				w_as_register_newline (d_reg);
			}
			return;
		}

		log2i=0;
		i2=abs_i;
		while (i2>1){
			i2>>=1;
			++log2i;
		}
		
		if (log2i==1){
			w_as_opcode ("add");
			w_as_register_comma (d_reg);
			w_as_register_comma (d_reg);
			w_as_lsr_register_newline (d_reg,31);
		} else {
			w_as_opcode ("cmp");
			w_as_register_comma (d_reg);
			w_as_immediate_newline (0);

			if (log2i<=8){
				w_as_opcode ("it");
				fprintf (assembly_file,"lt");
				w_as_newline_after_instruction();

				w_as_opcode ("addlt");
				w_as_register_comma (d_reg);
				w_as_register_comma (d_reg);
				w_as_immediate_newline (abs_i-1);
			} else {
				w_as_opcode ("add");
				w_as_scratch_register_comma();
				w_as_register_comma (d_reg);
				w_as_immediate_newline (abs_i);

				w_as_opcode ("it");
				fprintf (assembly_file,"lt");
				w_as_newline_after_instruction();

				w_as_opcode ("sublt");
				w_as_register_comma (d_reg);
				w_as_scratch_register_comma();
				w_as_immediate_newline (1);
			}					
		}
		
		if (i>=0){
			w_as_opcode ("asr");
			w_as_register_comma (d_reg);
			w_as_register_comma (d_reg);
			w_as_immediate_newline (log2i);
		} else {
			w_as_opcode_mov();
			w_as_scratch_register_comma();
			w_as_immediate_newline (0);

			w_as_opcode ("sub");
			w_as_register_comma (d_reg);
			w_as_scratch_register_comma();
			w_as_register (d_reg);
			fprintf (assembly_file,",asr #%d",log2i);
			w_as_newline_after_instruction();
		}
		return;
	}

	ms=magic (abs_i);

	w_as_ld_immediate (ms.m,REGISTER_S0);
	
	if (ms.s==0){
		if (ms.m>=0){
			w_as_opcode ("lsr");
			w_as_register_comma (REGISTER_S1);
			w_as_register_comma (d_reg);
			w_as_immediate_newline (31);
				
			w_as_opcode ("smmla");
			w_as_register_comma (d_reg);
			w_as_register_comma (d_reg);
			w_as_scratch_register_comma();
			w_as_register_newline (REGISTER_S1);

			if (i<0){
				w_as_opcode ("neg");
				w_as_register_comma (d_reg);
				w_as_register_newline (d_reg);
			}
		} else {
			if (ms.m>=0){
				w_as_opcode ("smmul");
				w_as_scratch_register_comma();
				w_as_scratch_register_comma();
				w_as_register_newline (d_reg);
			} else {
				w_as_opcode ("smmla");
				w_as_scratch_register_comma();
				w_as_scratch_register_comma();
				w_as_register_comma (d_reg);
				w_as_register_newline (d_reg);
			}
			if (i>=0){
				w_as_opcode ("add");
				w_as_register_comma (d_reg);
				w_as_scratch_register_comma();
				w_as_lsr_register_newline (d_reg,31);
			} else {
				w_as_opcode ("sub");
				w_as_register_comma (d_reg);
				w_as_scratch_register_comma();
				w_as_register (d_reg);
				fprintf (assembly_file,",asr #%d",31);
				w_as_newline_after_instruction();
			}		
		}
	} else {
		if (ms.m>=0){
			w_as_opcode ("smmul");
			w_as_scratch_register_comma();
			w_as_scratch_register_comma();
			w_as_register_newline (d_reg);
		} else {
			w_as_opcode ("smmla");
			w_as_scratch_register_comma();
			w_as_scratch_register_comma();
			w_as_register_comma (d_reg);
			w_as_register_newline (d_reg);
		}
		if (i>=0){
			w_as_opcode ("lsr");
			w_as_register_comma (d_reg);
			w_as_register_comma (d_reg);
			w_as_immediate_newline (31);

			w_as_opcode ("add");
			w_as_register_comma (d_reg);
			w_as_register_comma (d_reg);
			w_as_scratch_register();
			fprintf (assembly_file,",asr #%d",ms.s);
			w_as_newline_after_instruction();
		} else {
			w_as_opcode ("asr");
			w_as_register_comma (d_reg);
			w_as_register_comma (d_reg);
			w_as_immediate_newline (31);

			w_as_opcode ("sub");
			w_as_register_comma (d_reg);
			w_as_register_comma (d_reg);
			w_as_scratch_register();
			fprintf (assembly_file,",asr #%d",ms.s);
			w_as_newline_after_instruction();
		}
	}	
}

static void w_as_rem_instruction (struct instruction *instruction)
{
	int i,d_reg;
	struct ms ms;

	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (instruction->instruction_parameters[0].parameter_type!=P_IMMEDIATE){
		internal_error_in_function ("w_as_rem_instruction");
		return;
	}
	i=instruction->instruction_parameters[0].parameter_data.i;

	if (i==0){
		internal_error_in_function ("w_as_rem_instruction");
		return;
	}

	i=abs (i);

	if ((i & (i-1))==0){
		int log2i;
		unsigned int i2;

		if (i==1){
			w_as_ld_immediate (0,d_reg);
			return;
		}

		w_as_opcode ("sub");
		w_as_scratch_register_comma();
		w_as_register_comma (d_reg);
		w_as_lsr_register_newline (d_reg,31);

		log2i=0;
		i2=i;
		while (i2>1){
			i2>>=1;
			++log2i;
		}

		if (i<=256){
			if (log2i!=1){
				w_as_opcode ("asr");
				w_as_register_comma (d_reg);
				w_as_register_comma (d_reg);
				w_as_immediate_newline (log2i-1);
			}
			w_as_opcode ("and");
			w_as_scratch_register_comma();
			w_as_scratch_register_comma();
			w_as_immediate_newline (i-1);
		} else {
			w_as_ld_immediate (-1,REGISTER_S1);
			
			w_as_opcode ("asr");
			w_as_register_comma (d_reg);
			w_as_register_comma (d_reg);
			w_as_immediate_newline (log2i-1);

			w_as_opcode ("and");
			w_as_scratch_register_comma();
			w_as_scratch_register_comma();
			w_as_lsr_register_newline (REGISTER_S1,32-log2i);
		}

		w_as_opcode ("sub");
		w_as_register_comma (d_reg);
		w_as_scratch_register_comma();
		w_as_lsr_register_newline (d_reg,32-log2i);
		
		return;
	}
	

	ms=magic (i);

	w_as_ld_immediate (ms.m,REGISTER_S0);
	
	if (ms.s==0){
		if (ms.m>=0){
			w_as_opcode ("lsr");
			w_as_register_comma (REGISTER_S1);
			w_as_register_comma (d_reg);
			w_as_immediate_newline (31);
				
			w_as_opcode ("smmla");
			w_as_scratch_register_comma();
			w_as_register_comma (d_reg);
			w_as_scratch_register_comma();
			w_as_register_newline (REGISTER_S1);
		} else {
			if (ms.m>=0){
				w_as_opcode ("smmul");
				w_as_scratch_register_comma();
				w_as_scratch_register_comma();
				w_as_register_newline (d_reg);
			} else {
				w_as_opcode ("smmla");
				w_as_scratch_register_comma();
				w_as_scratch_register_comma();
				w_as_register_comma (d_reg);
				w_as_register_newline (d_reg);
			}

			w_as_opcode ("add");
			w_as_scratch_register_comma();
			w_as_scratch_register_comma();
			w_as_lsr_register_newline (d_reg,31);
		}
	} else {
		if (ms.m>=0){
			w_as_opcode ("smmul");
			w_as_scratch_register_comma();
			w_as_scratch_register_comma();
			w_as_register_newline (d_reg);
		} else {
			w_as_opcode ("smmla");
			w_as_scratch_register_comma();
			w_as_scratch_register_comma();
			w_as_register_comma (d_reg);
			w_as_register_newline (d_reg);
		}

		w_as_opcode ("lsr");
		w_as_register_comma (REGISTER_S1);
		w_as_register_comma (d_reg);
		w_as_immediate_newline (31);

		w_as_opcode ("add");
		w_as_scratch_register_comma();
		w_as_register_comma (REGISTER_S1);
		w_as_scratch_register();
		fprintf (assembly_file,",asr #%d",ms.s);
		w_as_newline_after_instruction();
	}	

	{
		unsigned int i2;
		
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
				
				w_as_opcode ("sub");
				w_as_register_comma (d_reg);
				w_as_register_comma (d_reg);
				w_as_lsl_register_newline (REGISTER_S0,n_shifts);
				
				n>>=1;
				n_shifts+=1;
			}
		} else {
#if 1
			w_as_ld_immediate (-i,REGISTER_S1);

			w_as_opcode ("mla");
			w_as_register_comma (d_reg);
			w_as_register_comma (REGISTER_S0);
			w_as_register_comma (REGISTER_S1);
			w_as_register_newline (d_reg);
#else
			/* mls is an illegal instruction on the raspberry pi b+ */
			w_as_ld_immediate (i,REGISTER_S1);

			w_as_opcode ("mls");
			w_as_register_comma (d_reg);
			w_as_register_comma (REGISTER_S0);
			w_as_register_comma (REGISTER_S1);
			w_as_register_newline (d_reg);
#endif
		}
	}
}

static void w_as_word_instruction (struct instruction *instruction)
{
	fprintf (assembly_file,"\t.hword\t%d\n",
			(int)instruction->instruction_parameters[0].parameter_data.i);
}

static void w_as_float_constant (int label_number,DOUBLE *r_p)
{
	struct float_constant *new_float_constant;
	
	new_float_constant=allocate_memory_from_heap (sizeof (struct float_constant));

	new_float_constant->float_constant_r_p=r_p;
	new_float_constant->float_constant_label_number=label_number;

	*float_constant_l=new_float_constant;
	float_constant_l=&new_float_constant->float_constant_next;
	
	new_float_constant->float_constant_next=NULL;

	if (instruction_n_after_ltorg+MAX_LITERAL_LDR_OFFSET < ltorg_at_instruction_n)
		ltorg_at_instruction_n = instruction_n_after_ltorg+MAX_LITERAL_LDR_OFFSET;
}

static void w_as_fld_parameter (struct parameter *parameter_p)
{
	switch (parameter_p->parameter_type){
		case P_F_IMMEDIATE:
		{
			int label_number;
			
			label_number=next_label_id++;

			w_as_opcode ("fldd");
			w_as_fp_register_comma (15);
			fprintf (assembly_file,"i_%d",label_number);
			w_as_newline_after_instruction();
			w_as_float_constant (label_number,parameter_p->parameter_data.r);
			return;
		}
		case P_INDIRECT:
			w_as_opcode ("fldd");
			w_as_fp_register_comma (15);
			w_as_indirect_newline (parameter_p->parameter_offset,parameter_p->parameter_data.reg.r);
			return;
		case P_INDEXED:
		{
			int offset;

			offset=parameter_p->parameter_offset;

			w_as_lea_indexed_no_offset_ir (REGISTER_S0,offset,parameter_p->parameter_data.ir);

			w_as_opcode ("fldd");
			w_as_fp_register_comma (15);
			w_as_indirect_newline (offset>>2,REGISTER_S0);
			w_as_newline_after_instruction();
			return;
		}
		default:
			internal_error_in_function ("w_as_fld_parameter");
			return;
	}
}

static void w_as_dyadic_float_instruction (struct instruction *instruction,char *opcode)
{
	int d_freg;
	
	d_freg=instruction->instruction_parameters[1].parameter_data.reg.r;
	if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
		w_as_opcode (opcode);
		w_as_fp_register_comma (d_freg);
		w_as_fp_register_comma (d_freg);
		w_as_fp_register_newline (instruction->instruction_parameters[0].parameter_data.reg.r);
	} else {
		w_as_fld_parameter (&instruction->instruction_parameters[0]);

		w_as_opcode (opcode);
		w_as_fp_register_comma (d_freg);
		w_as_fp_register_comma (d_freg);
		w_as_fp_register_newline (15);
	}
}

static void w_as_float_sub_or_div_instruction (struct instruction *instruction,char *opcode)
{
	int d_freg;
	
	d_freg=instruction->instruction_parameters[1].parameter_data.reg.r;
	if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
		w_as_opcode (opcode);
		w_as_fp_register_comma (d_freg);
		if (instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS){
			w_as_fp_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
			w_as_fp_register_newline (d_freg);
		} else {
			w_as_fp_register_comma (d_freg);
			w_as_fp_register_newline (instruction->instruction_parameters[0].parameter_data.reg.r);
		}
	} else {
		w_as_fld_parameter (&instruction->instruction_parameters[0]);

		w_as_opcode (opcode);
		w_as_fp_register_comma (d_freg);
		if (instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS){
			w_as_fp_register_comma (15);
			w_as_fp_register_newline (d_freg);
		} else {
			w_as_fp_register_comma (d_freg);
			w_as_fp_register_newline (15);
		}
	}
}

static void w_as_compare_float_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type!=P_F_REGISTER){
		if (instruction->instruction_parameters[0].parameter_type==P_F_IMMEDIATE &&
			((int*)&instruction->instruction_parameters[0].parameter_data.r)[0]==0 &&
			((int*)&instruction->instruction_parameters[0].parameter_data.r)[1]==0)
		{
			w_as_opcode ("fcmpzd");
			w_as_fp_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
		} else {
			w_as_fld_parameter (&instruction->instruction_parameters[0]);

			w_as_opcode ("fcmpd");
			w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_fp_register_newline (15);
		}
	} else {
		w_as_opcode ("fcmpd");
		w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_fp_register_newline (instruction->instruction_parameters[0].parameter_data.reg.r);
	}
}

static void w_as_monadic_float_instruction (struct instruction *instruction,char *opcode)
{
	int d_freg;
	
	d_freg=instruction->instruction_parameters[1].parameter_data.reg.r;
	if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
		w_as_opcode (opcode);
		w_as_fp_register (d_freg);
		w_as_comma();
		w_as_fp_register_newline (instruction->instruction_parameters[0].parameter_data.reg.r);
	} else {
		w_as_fld_parameter (&instruction->instruction_parameters[0]);

		w_as_opcode (opcode);
		w_as_fp_register (d_freg);
		w_as_comma();
		w_as_fp_register_newline (15);
	}
}

static void w_as_fmove_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_F_REGISTER:
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_F_REGISTER:
					w_as_opcode ("fcpyd");	
					w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_fp_register_newline (instruction->instruction_parameters[0].parameter_data.reg.r);
					return;
				case P_INDIRECT:
					w_as_opcode ("fldd");
					w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_indirect_newline (instruction->instruction_parameters[0].parameter_offset,
										   instruction->instruction_parameters[0].parameter_data.reg.r);
					return;
				case P_INDEXED:
				{
					int offset;

					offset=instruction->instruction_parameters[0].parameter_offset;

					w_as_lea_indexed_no_offset_ir (REGISTER_S0,offset,instruction->instruction_parameters[0].parameter_data.ir);

					w_as_opcode ("fldd");
					w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_indirect_newline (offset>>2,REGISTER_S0);
					return;
				}
				case P_F_IMMEDIATE:
				{
					int label_number=next_label_id++;

					w_as_opcode ("fldd");
					w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					fprintf (assembly_file,"i_%d",label_number);
					w_as_newline_after_instruction();
					w_as_float_constant (label_number,instruction->instruction_parameters[0].parameter_data.r);
					return;
				}
				default:
					internal_error_in_function ("w_as_fmove_instruction");
					return;
			}
		case P_INDIRECT:
		case P_INDEXED:
			if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT){
					w_as_opcode ("fstd");
					w_as_fp_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
					w_as_indirect_newline (instruction->instruction_parameters[1].parameter_offset,
										   instruction->instruction_parameters[1].parameter_data.reg.r);
					return;
				} else {
					int offset;

					offset=instruction->instruction_parameters[1].parameter_offset;

					w_as_lea_indexed_no_offset_ir (REGISTER_S0,offset,instruction->instruction_parameters[1].parameter_data.ir);

					w_as_opcode ("fstd");
					w_as_fp_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
					w_as_indirect_newline (offset>>2,REGISTER_S0);
					return;
				}	
			}
	}
	internal_error_in_function ("w_as_fmove_instruction");
}

static void w_as_floads_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_F_REGISTER:
		{
			int d_freg;
			
			d_freg=instruction->instruction_parameters[1].parameter_data.reg.r;

			switch (instruction->instruction_parameters[0].parameter_type){
				case P_INDIRECT:
					w_as_opcode ("vldr");
					fprintf (assembly_file,"s%d",d_freg<<1);
					w_as_indirect_newline (instruction->instruction_parameters[0].parameter_offset,
										   instruction->instruction_parameters[0].parameter_data.reg.r);
					break;
				case P_INDEXED:
				{
					int offset;

					offset=instruction->instruction_parameters[0].parameter_offset;

					w_as_lea_indexed_no_offset_ir (REGISTER_S0,offset,instruction->instruction_parameters[0].parameter_data.ir);

					w_as_opcode ("vldr");
					fprintf (assembly_file,"s%d",d_freg<<1);
					w_as_comma();
					w_as_indirect_newline (offset>>2,REGISTER_S0);
					break;
				}
				default:
					internal_error_in_function ("w_as_floads_instruction");
					return;
			}

			w_as_opcode ("vcvtr.f64.f32");
			w_as_fp_register_comma (d_freg);
			fprintf (assembly_file,"s%d",d_freg<<1);
			w_as_newline_after_instruction();
			return;
		}
	}
	internal_error_in_function ("w_as_floads_instruction");
}

static void w_as_fmoves_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
		int s_freg;
				
		s_freg=instruction->instruction_parameters[0].parameter_data.reg.r;

		w_as_opcode ("vcvtr.f32.f64");
		fprintf (assembly_file,"s%d",s_freg<<1);
		w_as_comma();
		w_as_fp_register_newline (15);

		switch (instruction->instruction_parameters[1].parameter_type){
			case P_INDIRECT:				
				w_as_opcode ("vstr");
				fprintf (assembly_file,"s%d",15<<1);
				w_as_comma();
				w_as_indirect_newline (instruction->instruction_parameters[1].parameter_offset,
									   instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_INDEXED:
			{
				int offset;

				offset=instruction->instruction_parameters[0].parameter_offset;

				w_as_lea_indexed_no_offset_ir (REGISTER_S0,offset,instruction->instruction_parameters[0].parameter_data.ir);

				w_as_opcode ("vstr");
				fprintf (assembly_file,"s%d",15<<1);
				w_as_comma();
				w_as_indirect_newline (offset>>2,REGISTER_S0);
			}
			return;
		}
	}
	internal_error_in_function ("w_as_fmoves_instruction");
}

static void w_as_fmovel_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
		if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
			int s_freg;

			s_freg=instruction->instruction_parameters[0].parameter_data.reg.r;

			w_as_opcode ("vcvtr.s32.f64" /*"ftosid"*/);
			fprintf (assembly_file,"s%d,d%d",s_freg<<1,s_freg);
			w_as_newline_after_instruction();

			w_as_opcode ("fmrs");
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			fprintf (assembly_file,"s%d",s_freg<<1);
			w_as_newline_after_instruction();
		} else
			internal_error_in_function ("w_as_fmovel_instruction");
	} else {
		int freg;

		freg=instruction->instruction_parameters[1].parameter_data.reg.r;

		switch (instruction->instruction_parameters[0].parameter_type){
			case P_REGISTER:
				w_as_opcode ("vmov");
				fprintf (assembly_file,"s%d",freg<<1);
				w_as_comma_register (instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_newline_after_instruction();
				break;
			case P_INDIRECT:
				w_as_opcode_ldr();
				w_as_scratch_register_comma();
				w_as_indirect_newline (instruction->instruction_parameters[0].parameter_offset,
									   instruction->instruction_parameters[0].parameter_data.reg.r);

				w_as_opcode ("vmov");
				fprintf (assembly_file,"s%d",freg<<1);
				w_as_comma_scratch_register_newline();
				break;
			case P_INDEXED:
				w_as_ld_indexed (&instruction->instruction_parameters[0],REGISTER_S0,SIZE_LONG);

				w_as_opcode ("vmov");
				fprintf (assembly_file,"s%d",freg<<1);
				w_as_comma_scratch_register_newline();
				break;
			case P_IMMEDIATE:
				/* the assembler does not assemble the following instruction correctly */
				w_as_opcode ("vldr" /*"flds"*/);
				fprintf (assembly_file,"s%d,=%ld",freg<<1,instruction->instruction_parameters[0].parameter_data.i);
				w_as_newline_after_instruction();
				break;
			default:
				internal_error_in_function ("w_as_fmovel_instruction");
				return;
		}

		w_as_opcode ("vcvt.f64.s32" /*"fsitod"*/);
		fprintf (assembly_file,"d%d,s%d",freg,freg<<1);
		w_as_newline_after_instruction();
		return;
	}
}

static void w_as_rts_instruction (void)
{
	w_as_opcode ("pop");
	fprintf (assembly_file,"{pc}");
	w_as_newline_after_instruction();

	write_float_constants();
	w_as_instruction_without_parameters (".ltorg");
	instruction_n_after_ltorg = 0u;
	ltorg_at_instruction_n = 0u-1u;
}

static void w_as_rtsi_instruction (struct instruction *instruction)
{
	int offset;

	offset = instruction->instruction_parameters[0].parameter_data.imm;
	w_as_opcode_ldr();
	fprintf (assembly_file,"pc,[sp],#%d",offset);
	w_as_newline_after_instruction();

	write_float_constants();
	w_as_instruction_without_parameters (".ltorg");
	instruction_n_after_ltorg = 0u;
	ltorg_at_instruction_n = 0u-1u;
}

static void w_as_rtsp_instruction (void)
{
	w_as_opcode ("b");
	w_as_label ("profile_r");
	w_as_newline_after_instruction();

	write_float_constants();
	w_as_instruction_without_parameters (".ltorg");
	instruction_n_after_ltorg = 0u;
	ltorg_at_instruction_n = 0u-1u;
}

static struct instruction *w_as_instructions_using_condition_flags (struct instruction *instruction)
{
	while (instruction!=NULL){
		switch (instruction->instruction_icode){
			case IMOVE:
				instruction=w_as_move_instruction (&instruction->instruction_parameters[0],instruction);
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
			case IFMOVE:
				w_as_fmove_instruction (instruction);
				break;
			case IBEQ:
				w_as_branch_instruction (instruction,"beq");
				return instruction->instruction_next;
			case IBGE:
				w_as_branch_instruction (instruction,"bge");
				return instruction->instruction_next;
			case IBGEU:
				w_as_branch_instruction (instruction,"bhs");
				return instruction->instruction_next;
			case IBGT:
				w_as_branch_instruction (instruction,"bgt");
				return instruction->instruction_next;
			case IBGTU:
				w_as_branch_instruction (instruction,"bhi");
				return instruction->instruction_next;
			case IBLE:
				w_as_branch_instruction (instruction,"ble");
				return instruction->instruction_next;
			case IBLEU:
				w_as_branch_instruction (instruction,"bls");
				return instruction->instruction_next;
			case IBLT:
				w_as_branch_instruction (instruction,"blt");
				return instruction->instruction_next;
			case IBLTU:
				w_as_branch_instruction (instruction,"blo");
				return instruction->instruction_next;
			case IBNE:
				w_as_branch_instruction (instruction,"bne");
				return instruction->instruction_next;
			case IBO:
				w_as_branch_instruction (instruction,"bvs");
				return instruction->instruction_next;
			case IBNO:
				w_as_branch_instruction (instruction,"bvc");
				return instruction->instruction_next;
			case IFBEQ:
				w_as_float_branch_instruction (instruction,"beq");
				return instruction->instruction_next;
			case IFBGE:
				w_as_float_branch_instruction (instruction,"bge");
				return instruction->instruction_next;
			case IFBGT:
				w_as_float_branch_instruction (instruction,"bgt");
				return instruction->instruction_next;
			case IFBLE:
				w_as_float_branch_instruction (instruction,"ble");
				return instruction->instruction_next;
			case IFBLT:
				w_as_float_branch_instruction (instruction,"bmi");
				return instruction->instruction_next;
			case IFBNE:
				w_as_float_branch_vc_and_instruction (instruction,"bne");
				return instruction->instruction_next;
			case IFBNEQ:
				w_as_float_branch_instruction (instruction,"bne");
				return instruction->instruction_next;
			case IFBNGE:
				w_as_float_branch_instruction (instruction,"blt");
				return instruction->instruction_next;
			case IFBNGT:
				w_as_float_branch_instruction (instruction,"ble");
				return instruction->instruction_next;
			case IFBNLE:
				w_as_float_branch_instruction (instruction,"bhi");
				return instruction->instruction_next;
			case IFBNLT:
				w_as_float_branch_instruction (instruction,"bpl");
				return instruction->instruction_next;
			case IFBNNE:
				w_as_float_branch_vs_or_instruction (instruction,"beq");
				return instruction->instruction_next;
			case IFSEQ:
				w_as_set_float_condition_instruction (instruction,"eq","ne");
				return instruction->instruction_next;
			case IFSGE:
				w_as_set_float_condition_instruction (instruction,"pl","mi");
				return instruction->instruction_next;
			case IFSGT:
				w_as_set_float_condition_instruction (instruction,"gt","le");
				return instruction->instruction_next;
			case IFSLE:
				w_as_set_float_condition_instruction (instruction,"le","gt");
				return instruction->instruction_next;
			case IFSLT:
				w_as_set_float_condition_instruction (instruction,"mi","pl");
				return instruction->instruction_next;
			case IFSNE:
				w_as_set_float_condition_instruction (instruction,"ne","eq");
				return instruction->instruction_next;
			case ISEQ:
				w_as_set_condition_instruction (instruction,"eq","ne");
				return instruction->instruction_next;
			case ISGE:
				w_as_set_condition_instruction (instruction,"ge","lt");
				return instruction->instruction_next;
			case ISGEU:
				w_as_set_condition_instruction (instruction,"hs","lo");
				return instruction->instruction_next;
			case ISGT:
				w_as_set_condition_instruction (instruction,"gt","le");
				return instruction->instruction_next;
			case ISGTU:
				w_as_set_condition_instruction (instruction,"hi","ls");
				return instruction->instruction_next;
			case ISLE:
				w_as_set_condition_instruction (instruction,"le","gt");
				return instruction->instruction_next;
			case ISLEU:
				w_as_set_condition_instruction (instruction,"ls","hi");
				return instruction->instruction_next;
			case ISLT:
				w_as_set_condition_instruction (instruction,"lt","ge");
				return instruction->instruction_next;
			case ISLTU:
				w_as_set_condition_instruction (instruction,"lo","hs");
				return instruction->instruction_next;
			case ISNE:
				w_as_set_float_vc_and_condition_instruction (instruction,"ne","eq");
				return instruction->instruction_next;
			case ISO:
				w_as_set_condition_instruction (instruction,"vs","vc");
				return instruction->instruction_next;
			case ISNO:
				w_as_set_condition_instruction (instruction,"vc","vs");
				return instruction->instruction_next;
			default:
				internal_error_in_function ("w_as_instructions_using_condition_flags");
		}
		instruction=instruction->instruction_next;
	}
	return instruction;
}

static void w_as_instructions (struct instruction *instruction)
{
	while (instruction!=NULL){
		switch (instruction->instruction_icode){
			case IMOVE:
				instruction=w_as_move_instruction_may_modify_condition_flags (instruction);
				break;
			case ILEA:
				w_as_lea_instruction (instruction);
				break;
			case IADD:
				w_as_add_instruction_may_modify_condition_flags (instruction);
				break;
			case ISUB:
				w_as_sub_instruction_may_modify_condition_flags (instruction);
				break;
			case ICMP:
				w_as_cmp_instruction (instruction);
				instruction=w_as_instructions_using_condition_flags (instruction->instruction_next);
				continue;
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
				w_as_rts_instruction();
				break;
			case IRTSI:
				w_as_rtsi_instruction (instruction);
				break;
			case IRTSP:
				w_as_rtsp_instruction();
				break;
			case IBEQ:
				w_as_branch_instruction (instruction,"beq");
				break;
			case IBGE:
				w_as_branch_instruction (instruction,"bge");
				break;
			case IBGEU:
				w_as_branch_instruction (instruction,"bhs");
				break;
			case IBGT:
				w_as_branch_instruction (instruction,"bgt");
				break;
			case IBGTU:
				w_as_branch_instruction (instruction,"bhi");
				break;
			case IBLE:
				w_as_branch_instruction (instruction,"ble");
				break;
			case IBLEU:
				w_as_branch_instruction (instruction,"bls");
				break;
			case IBLT:
				w_as_branch_instruction (instruction,"blt");
				break;
			case IBLTU:
				w_as_branch_instruction (instruction,"blo");
				break;
			case IBNE:
				w_as_branch_instruction (instruction,"bne");
				break;
			case IBO:
				w_as_branch_instruction (instruction,"bvs");
				break;
			case IBNO:
				w_as_branch_instruction (instruction,"bvc");
				break;
			case ILSL:
				w_as_shift_instruction_may_modify_condition_flags (instruction,"lsl","lsls");
				break;
			case ILSR:
				w_as_shift_instruction (instruction,"lsr");
				break;
			case IASR:
				w_as_shift_instruction (instruction,"asr");
				break;
			case IMUL:
				w_as_mul_instruction (instruction);
				break;
			case IDIV:
				w_as_div_instruction (instruction);
				break;
			case IREM:
				w_as_rem_instruction (instruction);
				break;
			case IAND:
				w_as_dyadic_instruction (instruction,"and");
				break;
			case IOR:
				w_as_dyadic_instruction (instruction,"orr");
				break;
			case IEOR:
				w_as_dyadic_instruction (instruction,"eor");
				break;
			case IADDI:
				w_as_reg_reg_imm_instruction (instruction,"add");
				break;
			case IANDI:
				w_as_reg_reg_imm_instruction (instruction,"and");
				break;
			case IORI:
				w_as_reg_reg_imm_instruction (instruction,"orr");
				break;
			case ILSLI:
				w_as_reg_reg_imm_shift_instruction_may_modify_condition_flags (instruction,"lsl","lsls");
				break;
			case ISEQ:
				w_as_set_condition_instruction (instruction,"eq","ne");
				break;
			case ISGE:
				w_as_set_condition_instruction (instruction,"ge","lt");
				break;
			case ISGEU:
				w_as_set_condition_instruction (instruction,"hs","lo");
				break;
			case ISGT:
				w_as_set_condition_instruction (instruction,"gt","le");
				break;
			case ISGTU:
				w_as_set_condition_instruction (instruction,"hi","ls");
				break;
			case ISLE:
				w_as_set_condition_instruction (instruction,"le","gt");
				break;
			case ISLEU:
				w_as_set_condition_instruction (instruction,"ls","hi");
				break;
			case ISLT:
				w_as_set_condition_instruction (instruction,"lt","ge");
				break;
			case ISLTU:
				w_as_set_condition_instruction (instruction,"lo","hs");
				break;
			case ISNE:
				w_as_set_condition_instruction (instruction,"ne","eq");
				break;
			case ISO:
				w_as_set_condition_instruction (instruction,"vs","vc");
				break;
			case ISNO:
				w_as_set_condition_instruction (instruction,"vc","vs");
				break;
			case ITST:
				w_as_tst_instruction (instruction);
				instruction=w_as_instructions_using_condition_flags (instruction->instruction_next);
				continue;
			case IBTST:
				w_as_btst_instruction (instruction);
				instruction=w_as_instructions_using_condition_flags (instruction->instruction_next);
				continue;
			case IMOVEDB:
				w_as_move_byte_or_word_instruction (instruction,SIZE_WORD);
				break;
			case IMOVEB:
				w_as_move_byte_or_word_instruction (instruction,SIZE_BYTE);
				break;
			case INEG:
				w_as_monadic_instruction (instruction,"neg");
				break;
			case INOT:
				w_as_monadic_instruction (instruction,"mvn");
				break;
			case ICLZB:
				w_as_clzb_instruction (instruction);
				break;
			case IMOVEM:
				w_as_movem_instruction (instruction);
				break;
			case IADC:
				w_as_dyadic_instruction (instruction,"adcl");
				break;
			case ISBB:
				w_as_dyadic_instruction (instruction,"sbbl");
				break;
			case IMULUD:
				w_as_mulud_instruction (instruction);
				break;
			case IROTR:
				w_as_shift_instruction (instruction,"ror");
				break;
			case IADDO:
				w_as_dyadic_instruction (instruction,"adds");
				break;
			case ISUBO:
				w_as_dyadic_instruction (instruction,"subs");
				break;
			case IFMOVE:
				w_as_fmove_instruction (instruction);
				break;
			case IFADD:
				w_as_dyadic_float_instruction (instruction,"faddd");
				break;
			case IFSUB:
				w_as_float_sub_or_div_instruction (instruction,"fsubd");
				break;
			case IFCMP:
				w_as_compare_float_instruction (instruction);
				instruction=w_as_instructions_using_condition_flags (instruction->instruction_next);
				continue;
			case IFDIV:
				w_as_float_sub_or_div_instruction (instruction,"fdivd");
				break;
			case IFMUL:
				w_as_dyadic_float_instruction (instruction,"fmuld");
				break;
			case IFBEQ:
				w_as_float_branch_instruction (instruction,"beq");
				break;
			case IFBGE:
				w_as_float_branch_instruction (instruction,"bge");
				break;
			case IFBGT:
				w_as_float_branch_instruction (instruction,"bgt");
				break;
			case IFBLE:
				w_as_float_branch_instruction (instruction,"ble");
				break;
			case IFBLT:
				w_as_float_branch_instruction (instruction,"bmi");
				break;
			case IFBNE:
				w_as_float_branch_vc_and_instruction (instruction,"bne");
				break;
			case IFBNEQ:
				w_as_float_branch_instruction (instruction,"bne");
				break;
			case IFBNGE:
				w_as_float_branch_instruction (instruction,"blt");
				break;
			case IFBNGT:
				w_as_float_branch_instruction (instruction,"ble");
				break;
			case IFBNLE:
				w_as_float_branch_instruction (instruction,"bhi");
				break;
			case IFBNLT:
				w_as_float_branch_instruction (instruction,"bpl");
				break;
			case IFBNNE:
				w_as_float_branch_vs_or_instruction (instruction,"beq");
				break;
			case IFMOVEL:
				w_as_fmovel_instruction (instruction);
				break;
			case IFLOADS:
				w_as_floads_instruction (instruction);
				break;
			case IFMOVES:
				w_as_fmoves_instruction (instruction);
				break;
			case IFSQRT:
				w_as_monadic_float_instruction (instruction,"fsqrtd");
				break;
			case IFNEG:
				w_as_monadic_float_instruction (instruction,"fnegd");
				break;
			case IFABS:
				w_as_monadic_float_instruction (instruction,"fabsd");
				break;
			case IFSEQ:
				w_as_set_float_condition_instruction (instruction,"eq","ne");
				break;
			case IFSGE:
				w_as_set_float_condition_instruction (instruction,"pl","mi");
				break;
			case IFSGT:
				w_as_set_float_condition_instruction (instruction,"gt","le");
				break;
			case IFSLE:
				w_as_set_float_condition_instruction (instruction,"le","gt");
				break;
			case IFSLT:
				w_as_set_float_condition_instruction (instruction,"mi","pl");
				break;
			case IFSNE:
				w_as_set_float_condition_instruction (instruction,"ne","eq");
				break;
			case IWORD:
				w_as_word_instruction (instruction);
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
	w_as_opcode (".long");
	fprintf (assembly_file,"%d",n_node_arguments);
	w_as_newline();
}

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
			new_call_and_jump->cj_call_label_name="collect_0";
			break;
		case 1:
			new_call_and_jump->cj_call_label_name="collect_1";
			break;
		case 2:
			new_call_and_jump->cj_call_label_name="collect_2";
			break;
		case 3:
			new_call_and_jump->cj_call_label_name="collect_3";
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

	if (mov_or_mov_not_immediate (n_cells)){
		w_as_opcode ("subs");
		fprintf (assembly_file,"r11,r11,#%ld",n_cells);
		w_as_newline_after_instruction();
	} else {
		if (instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET < ltorg_at_instruction_n)
			ltorg_at_instruction_n = instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET;

		w_as_opcode_ldr();
		w_as_scratch_register_comma();
		fprintf (assembly_file,"=%ld",n_cells);	
		w_as_newline_after_instruction();
	
		w_as_opcode ("subs");
		fputs ("r11,r11",assembly_file);
		w_as_comma_scratch_register_newline();
	}

	w_as_opcode ("blo");
	w_as_internal_label (label_id_1);
	w_as_newline_after_instruction ();
	
	w_as_define_internal_label (label_id_2);
}

static void w_as_call_and_jump (struct call_and_jump *call_and_jump)
{
	w_as_define_internal_label (call_and_jump->cj_label_id);

	if (call_and_jump->cj_jump_id==-1){
		w_as_opcode ("b");
		w_as_label (call_and_jump->cj_call_label_name);
		w_as_newline();		
	} else {
		w_as_opcode ("bl");
		w_as_label (call_and_jump->cj_call_label_name);
		w_as_newline_after_instruction();

		w_as_opcode ("b");
		w_as_internal_label (call_and_jump->cj_jump_id);
		w_as_newline_after_instruction();
	}
}

static void w_as_labels (struct block_label *labels)
{
	for (; labels!=NULL; labels=labels->block_label_next){
		if (labels->block_label_label->label_flags & THUMB_FUNC_LABEL)
			fprintf (assembly_file,"\t.thumb_func\n");
		if (labels->block_label_label->label_number==0)
			w_as_define_code_label (labels->block_label_label);
		else
			w_as_define_local_label (labels->block_label_label->label_number);
	}
}

static void w_as_thumb_labels (struct block_label *labels)
{
	for (; labels!=NULL; labels=labels->block_label_next){
		fprintf (assembly_file,"\t.thumb_func\n");
		if (labels->block_label_label->label_number==0)
			w_as_define_code_label (labels->block_label_label);
		else
			w_as_define_local_label (labels->block_label_label->label_number);
	}
}

static void w_as_check_stack (struct basic_block *block)
{
	if (block->block_a_stack_check_size>0){
		if (block->block_a_stack_check_size<=32){
			w_as_opcode ("cmpl");
			fputs (end_a_stack_label->label_name,assembly_file);
			w_as_comma_register (A_STACK_POINTER);
		} else {
			w_as_opcode ("leal");
			w_as_indirect (block->block_a_stack_check_size,A_STACK_POINTER);
			w_as_comma_scratch_register();
			w_as_newline_after_instruction();

			w_as_opcode ("cmpl");
			fputs (end_a_stack_label->label_name,assembly_file);
			w_as_comma_scratch_register();
		}
		w_as_newline_after_instruction();	

		w_as_opcode ("bhs");
		w_as_label (stack_overflow_label->label_name);
		w_as_newline_after_instruction();
	}

	if (block->block_b_stack_check_size>0){
		if (block->block_b_stack_check_size<=32){
			w_as_opcode ("cmpl");
			fputs (end_b_stack_label->label_name,assembly_file);
			w_as_comma_register (B_STACK_POINTER);
		} else {
			w_as_opcode ("leal");
			w_as_indirect (block->block_b_stack_check_size,B_STACK_POINTER);
			w_as_comma_scratch_register();
			w_as_newline_after_instruction();

			w_as_opcode ("cmpl");
			fputs (end_b_stack_label->label_name,assembly_file);
			w_as_comma_scratch_register();
		}
		w_as_newline_after_instruction();

		w_as_opcode ("jb");
		w_as_label (stack_overflow_label->label_name);
		w_as_newline_after_instruction();
	}
}

void initialize_write_assembly (FILE *ass_file)
{
	assembly_file=ass_file;
	
	in_data_section=0;

	first_call_and_jump=NULL;
}

extern LABEL *eval_fill_label,*eval_upd_labels[];

static void w_as_node_entry_info (struct basic_block *block)
{
	if (block->block_ea_label!=NULL){
		int n_node_arguments;

		n_node_arguments=block->block_n_node_arguments;
		if (n_node_arguments<-2)
			n_node_arguments=1;

		if (n_node_arguments>=0 && block->block_ea_label!=eval_fill_label){
			if (!block->block_profile){
				w_as_opcode ("movw");
				w_as_register_comma (REGISTER_A3);
				fprintf (assembly_file,"#:lower16:");
				w_as_label (block->block_ea_label->label_name);
				w_as_newline();

				w_as_opcode ("movt");
				w_as_register_comma (REGISTER_A3);
				fprintf (assembly_file,"#:upper16:");
				w_as_label (block->block_ea_label->label_name);
				w_as_newline();

				w_as_opcode ("b.w");
				w_as_label (eval_upd_labels[n_node_arguments]->label_name);
				w_as_newline();
			} else {
				w_as_opcode ("ldr.w");
				w_as_register_comma (REGISTER_D0);
				w_as_immediate_label_name (block->block_ea_label->label_name);
				w_as_newline();

				w_as_opcode ("ldr.w");
				w_as_register_comma (REGISTER_A3);
				w_as_descriptor (block->block_profile_function_label,0);
				w_as_newline();

				w_as_opcode ("b.w");
				w_as_label (eval_upd_labels[n_node_arguments]->label_name);
				fprintf (assembly_file,"-8");
				w_as_newline();						
			}
		} else {
			w_as_opcode ("b.w");
			w_as_label (block->block_ea_label->label_name);
			w_as_newline();
		
			w_as_space (8);
		}
		
		if (block->block_descriptor!=NULL && (block->block_n_node_arguments<0 || parallel_flag || module_info_flag))
			w_as_label_in_code_section (block->block_descriptor->label_name);
		else
			w_as_number_of_arguments (0);
	} else
	if (block->block_descriptor!=NULL && (block->block_n_node_arguments<0 || parallel_flag || module_info_flag))
		w_as_label_in_code_section (block->block_descriptor->label_name);

	w_as_number_of_arguments (block->block_n_node_arguments);
}

static void w_as_profile_call (struct basic_block *block)
{
	w_as_opcode_ldr();
	w_as_register_comma (REGISTER_A3);
	w_as_descriptor (block->block_profile_function_label,0);
	w_as_newline_after_instruction();

	w_as_opcode ("bl");
	
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
	w_as_newline_after_instruction();
}

extern LABEL *add_empty_node_labels[];

static void w_as_apply_update_entry (struct basic_block *block)
{
	int n_node_arguments;

	n_node_arguments=block->block_n_node_arguments;
	if (n_node_arguments<-200){
		w_as_opcode ("b.w");
		w_as_label (block->block_descriptor->label_name);
		w_as_newline();

		if (block->block_ea_label==NULL){
			if (block->block_profile)
				w_as_profile_call (block);

			w_as_instruction_without_parameters ("nop.w");
			w_as_instruction_without_parameters ("nop.w");
			return;
		}

		n_node_arguments+=300;
	} else
		n_node_arguments+=200;

	if (block->block_profile)
		w_as_profile_call (block);
	
	if (n_node_arguments==0){
		w_as_opcode ("b.w");
		w_as_label (block->block_ea_label->label_name);
		w_as_newline();

		w_as_instruction_without_parameters ("nop.w");
	} else {
		w_as_opcode ("bl.w");
		w_as_label (add_empty_node_labels[n_node_arguments]->label_name);
		w_as_newline();

		w_as_opcode ("b.w");
		w_as_label (block->block_ea_label->label_name);
		w_as_newline();
	}
}

void write_assembly (VOID)
{
	struct basic_block *block;
	struct call_and_jump *call_and_jump;

	instruction_n_after_ltorg = 0u;
	ltorg_at_instruction_n = 0u-1u;

	fprintf (assembly_file,"\t.arch armv7-a");
	w_as_newline();
	fprintf (assembly_file,"\t.syntax unified");
	w_as_newline();
	fprintf (assembly_file,"\t.thumb");
	w_as_newline();
	fprintf (assembly_file,"\t.fpu\tvfp");
	w_as_newline();

	w_as_to_code_section();

	float_constant_l=&first_float_constant;
	first_float_constant=NULL;

	for_l (block,first_block,block_next){
		if (block->block_n_node_arguments>-100){
			w_as_align (2);
			w_as_node_entry_info (block);
		} else if (block->block_n_node_arguments<-100)
			w_as_apply_update_entry (block);

		if (block->block_labels!=NULL){
			if (block->block_n_node_arguments!=-100)
				w_as_thumb_labels (block->block_labels);
			else
				w_as_labels (block->block_labels);
		}

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
	
	write_float_constants();
}
