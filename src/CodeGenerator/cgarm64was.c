/*
	File:	 cgarm64was.c
	Author:  John van Groningen
	Machine: AArch64
*/

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <stdint.h>
#include <inttypes.h>

#include "cgport.h"
#include "cgrconst.h"
#include "cgtypes.h"
#include "cg.h"
#include "cgiconst.h"
#include "cgcode.h"
#include "cginstructions.h"
#include "cgarm64as.h"
#include "cgarm64was.h"

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

void w_as_new_data_module (void)
{
}

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

void w_as_align_and_define_data_label (int label_number)
{
	w_as_to_data_section();
	w_as_align (3);	
	w_as_define_local_data_label (label_number);
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

void w_as_word64_in_data_section (int_64 n)
{
#ifdef DATA_IN_CODE_SECTION
        if (!in_data_section){
                in_data_section=1;
                w_as_instruction_without_parameters (".data");
        }
#else
        w_as_to_data_section();
#endif
        w_as_opcode (".quad");
        if ((int)n==n)
                fprintf (assembly_file,"%" PRId64,n);
        else
                fprintf (assembly_file,"%" PRIu64,n);
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
	w_as_align (3);
	fprintf (assembly_file,"\t.quad\t%s+2\n",label_name);
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

static int w_as_zeros (int n,int length)
{
	int i;
	
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
	
	w_as_opcode (".quad");
	fprintf (assembly_file,"%d\n",length);
	n=w_as_data (0,string,length);
	if (length & 7)
		n=w_as_zeros (n,8-(length & 7));
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

enum { SIZE_WORD, SIZE_BYTE };

static void w_as_label_name (char *label)
{
	int c;
	
	while ((c=*label++)!=0)
		putc (c,assembly_file);
}

#define MAX_LITERAL_INSTRUCTION_OFFSET 1023

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
		w_as_label_name (parameter_p->parameter_data.l->label_name);
}

#ifdef USE_LITERAL_TABLES
static void w_as_immediate_label (LABEL *label)
{
	if (instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET < ltorg_at_instruction_n)
		ltorg_at_instruction_n = instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET;

	putc ('=',assembly_file);
	if (label->label_number!=0)
		w_as_local_label (label->label_number);
	else
		w_as_label_name (label->label_name);
}

static void w_as_immediate_label_name (char *label_name)
{
	if (instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET < ltorg_at_instruction_n)
		ltorg_at_instruction_n = instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET;

	putc ('=',assembly_file);
	w_as_label_name (label_name);
}
#endif

static void w_as_colon (VOID)
{
	putc (':',assembly_file);
}

static void w_as_define_label_name (char *label_name)
{
	w_as_label_name (label_name);
	w_as_colon();
	w_as_newline();
}

static void w_as_define_data_label_name (char *label_name)
{
	w_as_label_name (label_name);
	w_as_colon();
	w_as_newline();
}

void w_as_define_label (LABEL *label)
{
	if (label->label_flags & EXPORT_LABEL){
		w_as_opcode (".globl");
		w_as_label_name (label->label_name);
		w_as_newline();
	}
	
	w_as_label_name (label->label_name);
	w_as_colon();
	w_as_newline();
}

static void w_as_define_code_label (LABEL *label)
{
	if (label->label_flags & EXPORT_LABEL){
		w_as_opcode (".globl");
		w_as_label_name (label->label_name);
		w_as_newline();
	}
	
	w_as_label_name (label->label_name);
	w_as_colon();
	w_as_newline();
}

static void w_as_internal_label (int label_number)
{
	fprintf (assembly_file,"i_%d",label_number);
}

static void w_as_immediate (long i)
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

static char *register_name[30]
  = {"x24","x23","x22","x21","x20","x28","x27","x26","x15","x14","x13","x12","x11","x10","x9","x8",
 	 "x6","x5","x4","x3","x2","x1","x0","x7","x25","x16","x17","x29","x30","x31"};

static char *word_register_name[30]
  = {"w24","w23","w22","w21","w20","w28","w27","w26","w15","w14","w13","w12","w11","w10","w9","w8",
  	 "w6","w5","w4","w3","w2","w1","w0","w7","w25","w16","w17","w29","w30","w31"};

#define REGISTER_S0 9
#define REGISTER_S1 10
#define REGISTER_X29 11
#define REGISTER_X30 12
#define REGISTER_X31 13

static void w_as_indirect (int i,int reg)
{
	if (i==0)
		fprintf (assembly_file,"[%s]",register_name[reg+N_REAL_A_REGISTERS]);
	else
		fprintf (assembly_file,"[%s,#%d]",register_name[reg+N_REAL_A_REGISTERS],i);
}

static void w_as_indirect_with_update (int i,int reg)
{
	if (i==0)
		fprintf (assembly_file,"[%s]",register_name[reg+N_REAL_A_REGISTERS]);
	else
		fprintf (assembly_file,"[%s,#%d]!",register_name[reg+N_REAL_A_REGISTERS],i);
}

static void w_as_indirect_post_add (int i,int reg)
{
	if (i==0)
		fprintf (assembly_file,"[%s]",register_name[reg+N_REAL_A_REGISTERS]);
	else
		fprintf (assembly_file,"[%s],#%d",register_name[reg+N_REAL_A_REGISTERS],i);
}

static void w_as_register (int reg)
{
	fputs (register_name[reg+N_REAL_A_REGISTERS],assembly_file);
}

static void w_as_word_register (int reg)
{
	fputs (word_register_name[reg+N_REAL_A_REGISTERS],assembly_file);
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

static void w_as_word_register_comma (int reg)
{
	w_as_word_register (reg);
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
		fprintf (assembly_file,"[%s,%s,lsl #%d]",register_name[reg1+N_REAL_A_REGISTERS],register_name[reg2+N_REAL_A_REGISTERS],shift);
	else
		fprintf (assembly_file,"[%s,%s]",register_name[reg1+N_REAL_A_REGISTERS],register_name[reg2+N_REAL_A_REGISTERS]);
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
		w_as_opcode (".ltorg");
		w_as_newline();

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

static void w_as_immediate_comma (long i)
{
	fprintf (assembly_file,"#%ld",i);
	w_as_comma();
}

static void w_as_immediate_newline (long i)
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
	fprintf (assembly_file,"x16");
}

static void w_as_scratch_register_comma (void)
{
	fprintf (assembly_file,"x16");
	w_as_comma();
}

static void w_as_scratch_register_newline (void)
{
	fprintf (assembly_file,"x16");
	w_as_newline_after_instruction();
}

static void w_as_word_scratch_register_comma (void)
{
	fprintf (assembly_file,"w16");
	w_as_comma();
}

static void w_as_comma_scratch_register (void)
{
	w_as_comma();
	fprintf (assembly_file,"x16");
}

static void w_as_comma_scratch_register_newline (void)
{
	w_as_comma();
	fprintf (assembly_file,"x16");
	w_as_newline_after_instruction();
}

static void w_as_zero_register_comma (void)
{
	fprintf (assembly_file,"xzr");
	w_as_comma();
}

static void w_as_zero_register_newline (void)
{
	fprintf (assembly_file,"xzr");
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

static void w_as_label (LABEL *label)
{
	if (label->label_number!=0)
		w_as_local_label (label->label_number);
	else
		w_as_label_name (label->label_name);
}

static void w_as_label_with_offset (LABEL *label,int offset)
{
	if (label->label_number!=0)
		w_as_local_label (label->label_number);
	else
		w_as_label_name (label->label_name);

	if (offset!=0)
		if (offset>0)
			fprintf (assembly_file,"+%d",offset);
		else
			fprintf (assembly_file,"%d",offset);
}

#ifdef USE_LITERAL_TABLES
static void w_as_descriptor (LABEL *label,int offset)
{
	if (instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET < ltorg_at_instruction_n)
		ltorg_at_instruction_n = instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET;

	putc ('=',assembly_file);
	w_as_label_with_offset (label,offset);
}
#endif

static void w_as_load_label_with_offset (int reg_n,LABEL *label,int offset)
{
#ifdef USE_LITERAL_TABLES
	w_as_opcode ("ldr");
	w_as_register_comma (reg_n);
	w_as_descriptor (label,offset);
	w_as_newline_after_instruction();
#else
	w_as_opcode ("adrp");
	w_as_register_comma (reg_n);
	w_as_label_with_offset (label,offset);
	w_as_newline_after_instruction();

	w_as_opcode ("add");
	w_as_register_comma (reg_n);
	w_as_register_comma (reg_n);
	fprintf (assembly_file,"#:lo12:");	
	w_as_label_with_offset (label,offset);
	w_as_newline_after_instruction();
#endif
}

static void w_as_load_scratch_register_descriptor (LABEL *label,int offset)
{
#ifdef USE_LITERAL_TABLES
	w_as_opcode ("ldr");
	w_as_scratch_register_comma();
	w_as_descriptor (label,offset);
	w_as_newline_after_instruction();
#else
	w_as_opcode ("adrp");
	w_as_scratch_register_comma();
	w_as_label_with_offset (label,offset);
	w_as_newline_after_instruction();

	w_as_opcode ("add");
	w_as_scratch_register_comma();
	w_as_scratch_register_comma();
	fprintf (assembly_file,"#:lo12:");	
	w_as_label_with_offset (label,offset);
	w_as_newline_after_instruction();
#endif
}

static void w_as_load_label (int reg_n,LABEL *label)
{
#ifdef USE_LITERAL_TABLES
	w_as_opcode ("ldr");
	w_as_register_comma (reg_n);
	w_as_immediate_label (label);
	w_as_newline_after_instruction();
#else
	w_as_opcode ("adrp");
	w_as_register_comma (reg_n);
	if (label->label_number!=0)
		w_as_local_label (label->label_number);
	else
		w_as_label_name (label->label_name);
	w_as_newline_after_instruction();

	w_as_opcode ("add");
	w_as_register_comma (reg_n);
	w_as_register_comma (reg_n);
	fprintf (assembly_file,"#:lo12:");	
	if (label->label_number!=0)
		w_as_local_label (label->label_number);
	else
		w_as_label_name (label->label_name);
	w_as_newline_after_instruction();
#endif
}

static void w_as_load_scratch_register_label (LABEL *label)
{
#ifdef USE_LITERAL_TABLES
	w_as_opcode ("ldr");
	w_as_scratch_register_comma();
	w_as_immediate_label (label);
	w_as_newline_after_instruction();
#else
	w_as_opcode ("adrp");
	w_as_scratch_register_comma();
	if (label->label_number!=0)
		w_as_local_label (label->label_number);
	else
		w_as_label_name (label->label_name);
	w_as_newline_after_instruction();

	w_as_opcode ("add");
	w_as_scratch_register_comma();
	w_as_scratch_register_comma();
	fprintf (assembly_file,"#:lo12:");	
	if (label->label_number!=0)
		w_as_local_label (label->label_number);
	else
		w_as_label_name (label->label_name);
	w_as_newline_after_instruction();
#endif
}

static void w_as_load_label_name (int reg_n,char *label_name)
{
#ifdef USE_LITERAL_TABLES
	w_as_opcode ("ldr");
	w_as_register_comma (reg_n);
	w_as_immediate_label_name (label_name);
	w_as_newline_after_instruction();
#else
	w_as_opcode ("adrp");
	w_as_register_comma (reg_n);
	w_as_label_name (label_name);
	w_as_newline_after_instruction();

	w_as_opcode ("add");
	w_as_register_comma (reg_n);
	w_as_register_comma (reg_n);
	fprintf (assembly_file,"#:lo12:");	
	w_as_label_name (label_name);
	w_as_newline_after_instruction();
#endif
}

static int add_or_sub_immediate (unsigned long i)
{
	if ((i & ~0xfffl)==0) return 1;
	if ((i & ~0xfff000l)==0) return 1;

	i=-i;

	if ((i & ~0xfffl)==0) return 1;
	if ((i & ~0xfff000l)==0) return 1;

	return 0;
}

static int bitmask_immediate (unsigned long i)
{
	if (i==0l || i==-1l)
		return 0;

	if ((i & 0x8000000000000000l)!=0)
		i = ~i;

	if ((i & (i + (i & (-i))))==0) return 1; /* all 1 bits are consecutive */

	if ((i>>32u)!=(i & 0xffffffffl))
		return 0;
	
	i &= 0xffffffffl;
	if ((i & (i + (i & (-i))))==0) return 1;

	if ((i>>16u)!=(i & 0xffffl))
		return 0;

	i &= 0xffffl;
	if ((i & (i + (i & (-i))))==0) return 1;

	if ((i>>8)!=(i & 0xffl))
		return 0;

	i &= 0xffl;
	if ((i & (i + (i & (-i))))==0) return 1;

	if ((i>>4)!=(i & 0xfl))
		return 0;

	i &= 0xfl;
	if ((i & (i + (i & (-i))))==0) return 1;

	if ((i>>2)!=(i & 0x3l))
		return 0;

	i &= 0x3l;
	if ((i & (i + (i & (-i))))==0) return 1;

	return 0;
}

static int movz_or_movn_immediate (unsigned long i)
{
	unsigned long not_i;

	/* movz */
	if ((i & ~0xffffl)==0) return 1;
	if ((i & ~0xffff0000l)==0) return 1;
	if ((i & ~0xffff00000000l)==0) return 1;
	if ((i & ~0xffff000000000000l)==0) return 1;

	not_i = ~i;

	/* movn */
	if ((not_i & ~0xffffl)==0) return 1;
	if ((not_i & ~0xffff0000l)==0) return 1;
	if ((not_i & ~0xffff00000000l)==0) return 1;
	if ((not_i & ~0xffff000000000000l)==0) return 1;

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

static void w_as_opcode_load_byte_or_short_register_comma (int size_flag,int dreg)
{
	if (size_flag==SIZE_WORD){
		w_as_opcode ("ldrsh");
		w_as_register_comma (dreg);
	} else {
		w_as_opcode ("ldrb");
		w_as_word_register_comma (dreg);
	}
}

static void w_as_ld_indexed (struct parameter *parameter_p,int dreg)
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

		w_as_opcode_ldr();
		w_as_register_comma (dreg);
		w_as_indexed_no_offset_newline (offset,REGISTER_S0,reg2);
	} else {
		w_as_opcode_ldr();
		w_as_register_comma (dreg);
		w_as_indexed_no_offset_ir_newline (offset,parameter_p->parameter_data.ir);
	}
}

static void w_as_ldsw_indexed (struct parameter *parameter_p,int dreg)
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

		w_as_opcode ("ldrsw");
		w_as_register_comma (dreg);
		w_as_indexed_no_offset_newline (offset,REGISTER_S0,reg2);
	} else {
		w_as_opcode ("ldrsw");
		w_as_register_comma (dreg);
		w_as_indexed_no_offset_ir_newline (offset,parameter_p->parameter_data.ir);
	}
}

static void w_as_ld_indexed_byte_or_short (struct parameter *parameter_p,int dreg,int size_flag)
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

		w_as_opcode_load_byte_or_short_register_comma (size_flag,dreg);
		w_as_indexed_no_offset_newline (offset,REGISTER_S0,reg2);
	} else {
		w_as_opcode_load_byte_or_short_register_comma (size_flag,dreg);
		w_as_indexed_no_offset_ir_newline (offset,parameter_p->parameter_data.ir);
	}
}

static void w_as_ld_large_immediate (long i,int reg)
{
	if (instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET < ltorg_at_instruction_n)
		ltorg_at_instruction_n = instruction_n_after_ltorg+MAX_LITERAL_INSTRUCTION_OFFSET;

	w_as_opcode ("ldr");
	w_as_register_comma (reg);
	fprintf (assembly_file,"=%ld",i);
	w_as_newline_after_instruction();
}

static void w_as_mov_r_i (int reg,long i)
{
	w_as_opcode_mov();
	w_as_register_comma (reg);
	w_as_immediate_newline (i);
}

static void w_as_movk_r_i_lsl_16 (int reg,long i)
{
	w_as_opcode ("movk");
	w_as_register_comma (reg);
	w_as_immediate (((unsigned long)i>>16u) & 0xffff);
	fputs (",lsl #16",assembly_file);
	w_as_newline_after_instruction();
}

static void w_as_ld_immediate (long i,int reg)
{
	if (movz_or_movn_immediate(i)){
		w_as_mov_r_i (reg,i);
	} else if (bitmask_immediate (i)){
		w_as_mov_r_i (reg,i);
	} else if ((i & ~0xffffffffl)==0){
		w_as_mov_r_i (reg,i & 0xffff);
		w_as_movk_r_i_lsl_16 (reg,i);
	} else if ((~i & ~0xffffffffl)==0){
		w_as_opcode ("movn");
		w_as_register_comma (reg);
		w_as_immediate_newline (~i & 0xffff);

		w_as_movk_r_i_lsl_16 (reg,i);
	} else
		w_as_ld_large_immediate (i,reg);
}

static int w_as_ld_immediate_or_negative (long i,int reg)
{
	if (movz_or_movn_immediate (i)){
		w_as_mov_r_i (reg,i);
		return 1;
	} else if (movz_or_movn_immediate (-i)){
		w_as_mov_r_i (reg,-i);
		return -1;
	} else if (bitmask_immediate (i)){
		w_as_mov_r_i (reg,i);
		return 1;
	} else if (bitmask_immediate (-i)){
		w_as_mov_r_i (reg,-i);
		return -1;
	} else if ((i & ~0xffffffffl)==0){
		w_as_mov_r_i (reg,i & 0xffff);
		w_as_movk_r_i_lsl_16 (reg,i);
		return 1;
	} else if ((-i & ~0xffffffffl)==0){
		w_as_mov_r_i (reg,-i & 0xffff);
		w_as_movk_r_i_lsl_16 (reg,-i);
		return -1;
	} else {
		w_as_ld_large_immediate (i,reg);
		return 1;
	}
}

static int w_as_register_parameter (struct parameter *parameter_p)
{
	switch (parameter_p->parameter_type){
		case P_REGISTER:
			return parameter_p->parameter_data.reg.r;
		case P_LABEL:
			w_as_load_scratch_register_label (parameter_p->parameter_data.l);
			return REGISTER_S0;
		case P_INDIRECT:
			w_as_opcode ("ldr");
			w_as_scratch_register_comma();
			w_as_indirect_newline (parameter_p->parameter_offset,parameter_p->parameter_data.reg.r);
			return REGISTER_S0;
		case P_INDEXED:
			w_as_ld_indexed (parameter_p,REGISTER_S0);
			return REGISTER_S0;
		case P_INDIRECT_WITH_UPDATE:
			w_as_opcode ("ldr");
			w_as_scratch_register_comma;
			w_as_indirect_with_update_newline (parameter_p->parameter_offset,parameter_p->parameter_data.reg.r);
			return REGISTER_S0;
		case P_PRE_DECREMENT:
			w_as_opcode ("ldr");
			w_as_scratch_register_comma();
			fprintf (assembly_file,"[x28,#-8]!");
			w_as_newline_after_instruction();
			return REGISTER_S0;
		case P_POST_INCREMENT:
			w_as_opcode ("ldr");
			w_as_scratch_register_comma();
			fprintf (assembly_file,"[x28],#8");
			w_as_newline_after_instruction();
			return REGISTER_S0;
		case P_INDIRECT_POST_ADD:
			w_as_opcode ("ldr");
			w_as_scratch_register_comma();
			w_as_indirect_post_add_newline (parameter_p->parameter_offset,parameter_p->parameter_data.reg.r);
			return REGISTER_S0;
		case P_IMMEDIATE:
			w_as_ld_immediate (parameter_p->parameter_data.i,REGISTER_S0);
			return REGISTER_S0;
		case P_F_REGISTER:
			w_as_opcode ("ldr");
			w_as_scratch_register_comma();
			fprintf (assembly_file,"%%st(%d)",parameter_p->parameter_data.reg.r);
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
				w_as_label_name (parameter->parameter_data.l->label_name);
			break;
		case P_INDIRECT:
		{
			int offset,reg;

			offset=parameter->parameter_offset;
			reg=parameter->parameter_data.reg.r;

			if (offset!=0)
				fprintf (assembly_file,"%d(%%%s)",offset,register_name[reg+N_REAL_A_REGISTERS]);
			else
				fprintf (assembly_file,"(%%%s)",register_name[reg+N_REAL_A_REGISTERS]);
			break;
		}
		case P_REGISTER:
		{
			int reg;

			reg=parameter->parameter_data.reg.r;

			fprintf (assembly_file,"%s",register_name[reg+N_REAL_A_REGISTERS]);
			break;
		}
		default:
			internal_error_in_function ("w_as_jump_parameter");
	}
}

static void w_as_opcode_store (void)
{
	w_as_opcode ("str");
}

static void w_as_opcode_store_byte_or_short (int size_flag)
{
	w_as_opcode (size_flag==SIZE_WORD ? "strh" : "strb");
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

static void w_as_lsl_register_newline (int reg,int shift)
{
	w_as_register (reg);
	if (shift!=0)
		fprintf (assembly_file,",lsl #%d",shift);
	w_as_newline_after_instruction();
}

#ifndef NO_LDRD
static void w_as_ldp_register_register_comma (int reg1,int reg2)
{
	w_as_opcode ("ldp");
	w_as_register_comma (reg1);
	w_as_register_comma (reg2);
}
#endif

static void w_as_ldr_ldr_or_ldp (int offset1,int a_reg1,int d_reg1,int offset2,int a_reg2,int d_reg2)
{
#ifndef NO_LDRD
	if (a_reg1==a_reg2 && d_reg1!=a_reg1 && (offset1 & 7)==0){
		if (offset2==offset1+8){
			if (offset1>=-512 && offset1<=504){
				w_as_ldp_register_register_comma (d_reg1,d_reg2);
				w_as_indirect_newline (offset1,a_reg1);
				return;
			}
		} else if (offset2==offset1-8){
			if (offset2>=-512 && offset2<=504){
				w_as_ldp_register_register_comma (d_reg2,d_reg1);
				w_as_indirect_newline (offset2,a_reg1);
				return;
			}
		}
	}
#endif

	w_as_opcode_ldr();
	w_as_register_comma (d_reg1);
	w_as_indirect_newline (offset1,a_reg1);

	w_as_opcode_ldr();
	w_as_register_comma (d_reg2);
	w_as_indirect_newline (offset2,a_reg2);
}

#ifndef NO_STRD
static void w_as_stp_register_register_comma (int reg1,int reg2)
{
	w_as_opcode ("stp");
	w_as_register_comma (reg1);
	w_as_register_comma (reg2);
}

static struct instruction *w_as_str_or_stp_id (struct instruction *instruction,struct parameter *d_parameter_p,int s_reg)
{
	int a_reg,offset;
	struct instruction *next_instruction;

	a_reg=d_parameter_p->parameter_data.reg.r;
	offset=d_parameter_p->parameter_offset;

	next_instruction=instruction->instruction_next;
	if (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE && (offset & 7)==0){
		if (next_instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
			next_instruction->instruction_parameters[1].parameter_data.reg.r==a_reg
		){
			if (next_instruction->instruction_parameters[0].parameter_type==P_REGISTER){
				/* str str */
				if (next_instruction->instruction_parameters[1].parameter_offset==offset+8){
					if (offset>=-512 && offset<=504){
						w_as_stp_register_register_comma (s_reg,next_instruction->instruction_parameters[0].parameter_data.reg.r);
						w_as_indirect_newline (offset,a_reg);
						return next_instruction;
					}
				} else if (next_instruction->instruction_parameters[1].parameter_offset==offset-8){
					if (offset-8>=-512 && offset-8<=504){
						w_as_stp_register_register_comma (next_instruction->instruction_parameters[0].parameter_data.reg.r,s_reg);
						w_as_indirect_newline (offset-8,a_reg);
						return next_instruction;
					}
				}
			}

			if (next_instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
				int la_reg;
				
				la_reg = next_instruction->instruction_parameters[0].parameter_data.reg.r;
				if (la_reg==a_reg
					? (next_instruction->instruction_parameters[0].parameter_offset+8<=offset ||
					   next_instruction->instruction_parameters[0].parameter_offset>=offset+8)
					: (a_reg!=REGISTER_S0 &&
					   (la_reg==A_STACK_POINTER || la_reg==B_STACK_POINTER || a_reg==A_STACK_POINTER || a_reg==B_STACK_POINTER))
				){
					/* str ldr->str */
					if (next_instruction->instruction_parameters[1].parameter_offset==offset+8){
						if (offset>=-512 && offset<=504){
							int s_reg2;
							
							s_reg2 = s_reg!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

							w_as_opcode_ldr();
							w_as_register_comma (s_reg2);
							w_as_indirect_newline (next_instruction->instruction_parameters[0].parameter_offset,la_reg);

							w_as_stp_register_register_comma (s_reg,s_reg2);
							w_as_indirect_newline (offset,a_reg);
							return next_instruction;
						}
					} else if (next_instruction->instruction_parameters[1].parameter_offset==offset-8){
						if (offset-8>=-512 && offset-8<=504){
							int s_reg2;
							
							s_reg2 = s_reg!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

							w_as_opcode_ldr();
							w_as_register_comma (s_reg2);
							w_as_indirect_newline (next_instruction->instruction_parameters[0].parameter_offset,la_reg);

							w_as_stp_register_register_comma (s_reg2,s_reg);
							w_as_indirect_newline (offset-8,a_reg);
							return next_instruction;
						}
					}															
				}
			}

			if (next_instruction->instruction_parameters[0].parameter_type==P_DESCRIPTOR_NUMBER){
				if (a_reg!=REGISTER_S0){
					/* str ldr_descr->str */
					if (next_instruction->instruction_parameters[1].parameter_offset==offset+8){
						if (offset>=-512 && offset<=504){
							int s_reg2;
							
							s_reg2 = s_reg!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

							w_as_load_label_with_offset (s_reg2,next_instruction->instruction_parameters[0].parameter_data.l,
														 next_instruction->instruction_parameters[0].parameter_offset);

							w_as_stp_register_register_comma (s_reg,s_reg2);
							w_as_indirect_newline (offset,a_reg);
							return next_instruction;
						}
					} else if (next_instruction->instruction_parameters[1].parameter_offset==offset-8){
						if (offset-8>=-512 && offset-8<=504){
							int s_reg2;
							
							s_reg2 = s_reg!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

							w_as_load_label_with_offset (s_reg2,next_instruction->instruction_parameters[0].parameter_data.l,
														 next_instruction->instruction_parameters[0].parameter_offset);

							w_as_stp_register_register_comma (s_reg2,s_reg);
							w_as_indirect_newline (offset-8,a_reg);
							return next_instruction;
						}
					}															
				}
			}
		}

		if (offset==8 && next_instruction->instruction_parameters[1].parameter_type==P_INDIRECT_POST_ADD &&
			next_instruction->instruction_parameters[1].parameter_data.reg.r==a_reg &&
			next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
			(next_instruction->instruction_parameters[1].parameter_offset & 7)==0 &&
			next_instruction->instruction_parameters[1].parameter_offset>=-512 &&
			next_instruction->instruction_parameters[1].parameter_offset<=504
		){
			/* str str,# */
			w_as_stp_register_register_comma (next_instruction->instruction_parameters[0].parameter_data.reg.r,s_reg);
			w_as_indirect_post_add_newline (next_instruction->instruction_parameters[1].parameter_offset,a_reg);
			return next_instruction;
		}

		if (next_instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
			next_instruction->instruction_parameters[0].parameter_data.reg.r==a_reg &&
			next_instruction->instruction_parameters[1].parameter_type==P_REGISTER &&
			next_instruction->instruction_parameters[1].parameter_data.reg.r!=a_reg &&
			next_instruction->instruction_parameters[1].parameter_data.reg.r!=s_reg
		){
			struct instruction *next_next_instruction;

			next_next_instruction=next_instruction->instruction_next;
			if (next_next_instruction!=NULL && next_next_instruction->instruction_icode==IMOVE &&
				next_next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
				next_next_instruction->instruction_parameters[0].parameter_data.reg.r!=next_instruction->instruction_parameters[0].parameter_data.reg.r &&
				next_next_instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
				next_next_instruction->instruction_parameters[1].parameter_data.reg.r==a_reg
			){
				int offset1,offset2;
				/* str ldr str*/

				offset1=next_instruction->instruction_parameters[0].parameter_offset;
				offset2=next_next_instruction->instruction_parameters[1].parameter_offset;
				if (offset+8<=offset1 || offset>=offset1+8){
					if (offset2==offset+8){
						if (offset>=-512 && offset<=504){
							w_as_opcode_ldr();
							w_as_register_comma (next_instruction->instruction_parameters[1].parameter_data.reg.r);
							w_as_indirect_newline (offset1,a_reg);
						
							w_as_stp_register_register_comma (s_reg,next_next_instruction->instruction_parameters[0].parameter_data.reg.r);
							w_as_indirect_newline (offset,a_reg);
							
							return next_next_instruction;	
						}
					} else if (offset2==offset-8){
						if (offset-8>=-512 && offset-8<=504){
							w_as_opcode_ldr();
							w_as_register_comma (next_instruction->instruction_parameters[1].parameter_data.reg.r);
							w_as_indirect_newline (offset1,a_reg);

							w_as_stp_register_register_comma (next_next_instruction->instruction_parameters[0].parameter_data.reg.r,s_reg);
							w_as_indirect_newline (offset-8,a_reg);
							
							return next_next_instruction;
						}
					}
				}
			}
		}
	}

	w_as_opcode_store();
	w_as_register_comma (s_reg);
	w_as_indirect_newline (offset,a_reg);
	return instruction;
}

static struct instruction *w_as_str_str_or_stp_id (struct instruction *instruction,int s_reg,int offset,int a_reg)
{
	if ((offset & 7)==0 && instruction->instruction_parameters[1].parameter_data.reg.r==a_reg){
		if (instruction->instruction_parameters[1].parameter_offset==offset+8){
			if (offset>=-512 && offset<=504){
				w_as_stp_register_register_comma (s_reg,REGISTER_S0);
				w_as_indirect_newline (offset,a_reg);
				return instruction;
			}
		} else if (instruction->instruction_parameters[1].parameter_offset==offset-8){
			if (offset-8>=-512 && offset-8<=504){
				w_as_stp_register_register_comma (REGISTER_S0,s_reg);
				w_as_indirect_newline (offset-8,a_reg);
				return instruction;
			}
		}
	}

	w_as_opcode_store();
	w_as_register_comma (s_reg);
	w_as_indirect_newline (offset,a_reg);

	return w_as_str_or_stp_id (instruction,&instruction->instruction_parameters[1],REGISTER_S0);
}
#endif

#ifndef NO_OPT_INDEXED
static struct instruction *w_as_more_load_indexed (struct instruction *next_instruction,int reg1,int reg2,int reg3,int offset)
{
	struct instruction *instruction;
	
	do {
		int d_reg;

		if (next_instruction->instruction_parameters[1].parameter_type==P_REGISTER){
			d_reg=next_instruction->instruction_parameters[1].parameter_data.reg.r;

			w_as_opcode_ldr();
			w_as_register_comma (d_reg);
			w_as_indirect_newline (next_instruction->instruction_parameters[0].parameter_offset>>2,reg3);

			if (d_reg==reg1 || d_reg==reg2)
				return next_instruction;
		} else {
			d_reg = reg3!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

			w_as_opcode_ldr();
			w_as_register_comma (d_reg);
			w_as_indirect_newline (next_instruction->instruction_parameters[0].parameter_offset>>2,reg3);

			switch (next_instruction->instruction_parameters[1].parameter_type){
				case P_INDIRECT:
					w_as_opcode_store();
					w_as_register_comma (d_reg);
					w_as_indirect_newline (next_instruction->instruction_parameters[1].parameter_offset,
										   next_instruction->instruction_parameters[1].parameter_data.reg.r);
					break;
				case P_PRE_DECREMENT:
					w_as_opcode_store();
					w_as_register (d_reg);
					fprintf (assembly_file,",[x28,#-8]!");
					w_as_newline_after_instruction();
					break;
				case P_INDIRECT_WITH_UPDATE:
					w_as_opcode_store();
					w_as_register_comma (d_reg);
					w_as_indirect_with_update_newline (next_instruction->instruction_parameters[1].parameter_offset,
													   next_instruction->instruction_parameters[1].parameter_data.reg.r);

					if (next_instruction->instruction_parameters[1].parameter_data.reg.r==reg1 ||
						next_instruction->instruction_parameters[1].parameter_data.reg.r==reg2)
						return next_instruction;
					break;
				default:
					internal_error_in_function ("w_as_more_load_indexed");
			}
		}
		
		instruction=next_instruction;
		next_instruction=instruction->instruction_next;

	} while (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
		next_instruction->instruction_parameters[0].parameter_type==P_INDEXED &&
		next_instruction->instruction_parameters[0].parameter_data.ir->a_reg.r==reg1 &&
		next_instruction->instruction_parameters[0].parameter_data.ir->d_reg.r==reg2 &&
		(next_instruction->instruction_parameters[0].parameter_offset & 3)==(offset & 3) &&
		(next_instruction->instruction_parameters[1].parameter_type==P_REGISTER ||
		 next_instruction->instruction_parameters[1].parameter_type==P_INDIRECT ||
		 next_instruction->instruction_parameters[1].parameter_type==P_PRE_DECREMENT ||
		 next_instruction->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE));
	
	return instruction;
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

	w_as_opcode_ldr();
	w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
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
										w_as_opcode_store();
										w_as_register_comma (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r);
										w_as_indirect_newline (s_offset>>2,REGISTER_S1);
									} else {
										w_as_opcode ("add");
										w_as_register_comma (REGISTER_S1);	
										w_as_register_comma (reg1);
										w_as_lsl_register_newline (reg2,s_offset & 3);

										store_address_without_offset_computed = 1;

										w_as_opcode_store();
										w_as_register_comma (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r);
										w_as_indirect_newline (s_offset>>2,REGISTER_S1);																	
									}
								} else {
									if (store_address_without_offset_computed){
										w_as_opcode_store();
										w_as_register_comma (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r);
										w_as_indirect_newline (s_offset>>2,REGISTER_S1);

										store_address_without_offset_computed = 0;
									} else {
										w_as_opcode ("add");
										w_as_register_comma (REGISTER_S1);	
										w_as_register_comma (reg1);
										w_as_immediate_newline (s_offset>>2);

										w_as_opcode_store();
										w_as_register_comma (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r);
										w_as_indexed_no_offset_newline (s_offset,REGISTER_S1,reg2);
									}
								}
							} else {
								w_as_opcode_store();
								w_as_register_comma (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r);
								w_as_indexed_no_offset_ir_newline (s_offset,
														   		   store_indexed_instruction->instruction_parameters[1].parameter_data.ir);

								store_address_without_offset_computed = 0;
							}
						}
						
						w_as_opcode_ldr();
						w_as_register_comma (load_indexed_instruction->instruction_parameters[1].parameter_data.reg.r);
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
						w_as_opcode_store();
						w_as_register_comma (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r);
						w_as_indirect_newline (s_offset>>2,REGISTER_S1);
					} else {
						w_as_opcode ("add");
						w_as_register_comma (REGISTER_S1);	
						w_as_register_comma (reg1);
						w_as_lsl_register_newline (reg2,s_offset & 3);

						store_address_without_offset_computed = 1;

						w_as_opcode_store();
						w_as_register_comma (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r);
						w_as_indirect_newline (s_offset>>2,REGISTER_S1);																	
					}
				} else {
					if (store_address_without_offset_computed){
						w_as_opcode_store();
						w_as_register_comma (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r);
						w_as_indirect_newline (s_offset>>2,REGISTER_S1);
						
						store_address_without_offset_computed = 0;
					} else {
						w_as_opcode ("add");
						w_as_register_comma (REGISTER_S1);	
						w_as_register_comma (reg1);
						w_as_immediate_newline (s_offset>>2);

						w_as_opcode_store();
						w_as_register_comma (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r);
						w_as_indexed_no_offset_newline (s_offset,REGISTER_S1,reg2);
					}
				}
			} else {
				w_as_opcode_store();
				w_as_register_comma (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_indexed_no_offset_ir_newline (s_offset,
										   		   store_indexed_instruction->instruction_parameters[1].parameter_data.ir);

				store_address_without_offset_computed = 0;
			}
		}
		
		w_as_opcode_ldr();
		w_as_register_comma (load_indexed_instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_indirect_newline (load_indexed_instruction->instruction_parameters[0].parameter_offset>>2,REGISTER_S0);

		if (store_address_without_offset_computed){
			instruction=instruction->instruction_next;

			w_as_opcode_store();
			w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
			w_as_indirect_newline (instruction->instruction_parameters[1].parameter_offset>>2,REGISTER_S1);
		}

		break;
	}
	
	return instruction;
}								
#endif

static struct instruction *w_as_move_instruction (struct instruction *instruction)
{
	struct parameter *d_parameter_p;
	int s_reg;

	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_DESCRIPTOR_NUMBER:
				w_as_load_label_with_offset (instruction->instruction_parameters[1].parameter_data.reg.r,
									 		 instruction->instruction_parameters[0].parameter_data.l,
									 		 instruction->instruction_parameters[0].parameter_offset);
				return instruction;
			case P_IMMEDIATE:
				w_as_ld_immediate (instruction->instruction_parameters[0].parameter_data.i,
								   instruction->instruction_parameters[1].parameter_data.reg.r);
				return instruction;
			case P_REGISTER:
				w_as_opcode_mov();
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_register (instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_newline_after_instruction();
				return instruction;
			case P_INDIRECT:
			{
				int d_reg,a_reg,offset;
#ifndef NO_LDRD
				struct instruction *next_instruction;
#endif
				d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;
				a_reg=instruction->instruction_parameters[0].parameter_data.reg.r;
				offset=instruction->instruction_parameters[0].parameter_offset;

#ifndef NO_LDRD
				next_instruction=instruction->instruction_next;
				if (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
					d_reg!=a_reg && (offset & 7)==0)
				{
					if (next_instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
						next_instruction->instruction_parameters[0].parameter_data.reg.r==a_reg
					){
						/* ldr ldr */
						if (next_instruction->instruction_parameters[1].parameter_type==P_REGISTER){
							if (next_instruction->instruction_parameters[0].parameter_offset==offset+8){
								if (offset>=-512 && offset<=504){
									w_as_ldp_register_register_comma (d_reg,next_instruction->instruction_parameters[1].parameter_data.reg.r);
									w_as_indirect_newline (offset,a_reg);
									return next_instruction;
								}
							} else if (next_instruction->instruction_parameters[0].parameter_offset==offset-8){
								if (offset-8>=-512 && offset-8<=504){
									w_as_ldp_register_register_comma (next_instruction->instruction_parameters[1].parameter_data.reg.r,d_reg);
									w_as_indirect_newline (offset-8,a_reg);
									return next_instruction;
								}
							}
						} else {
							if (next_instruction->instruction_parameters[0].parameter_offset==offset+8){
								if (offset>=-512 && offset<=504){
									w_as_ldp_register_register_comma (d_reg,REGISTER_S0);
									w_as_indirect_newline (offset,a_reg);
									
									d_parameter_p=&next_instruction->instruction_parameters[1];
									instruction=next_instruction;
									s_reg = REGISTER_S0;
									break;
								}
							} else if (next_instruction->instruction_parameters[0].parameter_offset==offset-8){
								if (offset-8>=-512 && offset-8<=504){
									w_as_ldp_register_register_comma (REGISTER_S0,d_reg);
									w_as_indirect_newline (offset-8,a_reg);
									
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
						next_instruction->instruction_parameters[1].parameter_type==P_REGISTER
					){
						if (next_instruction->instruction_parameters[0].parameter_offset==offset-8 &&
							next_instruction->instruction_parameters[1].parameter_data.reg.r!=d_reg
						){
							if (offset-8>=-512 && offset-8<=504){
								w_as_ldp_register_register_comma (next_instruction->instruction_parameters[1].parameter_data.reg.r,d_reg);
								w_as_indirect_with_update_newline (offset-8,a_reg);
								return next_instruction;
							}
						}
					}

					if (next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
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
									if (offset1+8<=offset2 || offset1>=offset2+8){
										if (offset2==offset+8){
											if (offset>=-512 && offset<=504){
												w_as_ldp_register_register_comma (d_reg,d_reg2);
												w_as_indirect_newline (offset,a_reg);
												
												return w_as_str_or_stp_id (next_next_instruction,
																		   &next_instruction->instruction_parameters[1],s_reg);
											}
										} else if (offset2==offset-8){
											if (offset2>=-512 && offset2<=504){
												w_as_ldp_register_register_comma (d_reg2,d_reg);
												w_as_indirect_newline (offset2,a_reg);

												return w_as_str_or_stp_id (next_next_instruction,
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
									if (offset1+8<=offset2 || offset1>=offset2+8){
										if (offset2==offset+8){
											if (offset>=-512 && offset<=504){
												w_as_ldp_register_register_comma (d_reg,REGISTER_S0);
												w_as_indirect_newline (offset,a_reg);
												
												return w_as_str_str_or_stp_id (next_next_instruction,s_reg,offset1,a_reg);
											}
										} else if (offset2==offset-8){
											if (offset2>=-512 && offset2<=504){
												w_as_ldp_register_register_comma (REGISTER_S0,d_reg);
												w_as_indirect_newline (offset2,a_reg);

												return w_as_str_str_or_stp_id (next_next_instruction,s_reg,offset1,a_reg);
											}
										}
									}
								}
							}
						}
					}
				}
#endif

				w_as_opcode_ldr();
				w_as_register_comma (d_reg);
				w_as_indirect_newline (offset,a_reg);
				return instruction;
			}
			case P_INDEXED:

#ifndef NO_OPT_INDEXED
				if ((instruction->instruction_parameters[0].parameter_offset & -4)!=0 &&
					instruction->instruction_parameters[1].parameter_data.reg.r!=REGISTER_S0
				){
					int reg1,reg2;

					reg1=instruction->instruction_parameters[0].parameter_data.ir->a_reg.r;
					reg2=instruction->instruction_parameters[0].parameter_data.ir->d_reg.r;

					if (instruction->instruction_parameters[1].parameter_data.reg.r!=reg1 &&
						instruction->instruction_parameters[1].parameter_data.reg.r!=reg2
					){
						struct instruction *next_instruction;
						int offset;
						
						offset=instruction->instruction_parameters[0].parameter_offset;

						next_instruction=instruction->instruction_next;
						if (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE){
							if (next_instruction->instruction_parameters[0].parameter_type==P_INDEXED &&
								next_instruction->instruction_parameters[0].parameter_data.ir->a_reg.r==reg1 &&
								next_instruction->instruction_parameters[0].parameter_data.ir->d_reg.r==reg2 &&
								(next_instruction->instruction_parameters[0].parameter_offset & 3)==(offset & 3) &&
								(next_instruction->instruction_parameters[1].parameter_type==P_REGISTER ||
								 next_instruction->instruction_parameters[1].parameter_type==P_INDIRECT ||
								 next_instruction->instruction_parameters[1].parameter_type==P_PRE_DECREMENT ||
								 next_instruction->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE)
							){
								w_as_opcode ("add");
								w_as_register_comma (REGISTER_S0);	
								w_as_register_comma (reg1);
								w_as_lsl_register_newline (reg2,offset & 3);

								w_as_opcode_ldr();
								w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
								w_as_indirect_newline (offset>>2,REGISTER_S0);

								return w_as_more_load_indexed (next_instruction,reg1,reg2,REGISTER_S0,offset);
							}

							if (next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
								next_instruction->instruction_parameters[1].parameter_type==P_INDEXED
							){
								struct instruction *next_next_instruction;
								
								next_next_instruction=next_instruction->instruction_next;
								if (next_next_instruction!=NULL && next_next_instruction->instruction_icode==IMOVE &&
									next_next_instruction->instruction_parameters[0].parameter_type==P_INDEXED &&
									next_next_instruction->instruction_parameters[0].parameter_data.ir->a_reg.r==reg1 &&
									next_next_instruction->instruction_parameters[0].parameter_data.ir->d_reg.r==reg2 &&
									(next_next_instruction->instruction_parameters[0].parameter_offset & 3)==(offset & 3) &&								
									next_next_instruction->instruction_parameters[1].parameter_type==P_REGISTER
								)
									return w_as_move_indexed_load_store_sequence (instruction);
							}
						}
					}
				}
#endif

				w_as_ld_indexed (&instruction->instruction_parameters[0],
								 instruction->instruction_parameters[1].parameter_data.reg.r);
				return instruction;
			case P_INDIRECT_WITH_UPDATE:
				w_as_opcode_ldr();
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_indirect_with_update_newline (instruction->instruction_parameters[0].parameter_offset,
												   instruction->instruction_parameters[0].parameter_data.reg.r);
				return instruction;
			case P_POST_INCREMENT:
			{
#ifndef NO_LDRD
				struct instruction *next_instruction;

				next_instruction=instruction->instruction_next;
				if (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
					next_instruction->instruction_parameters[0].parameter_type==P_POST_INCREMENT &&
					next_instruction->instruction_parameters[0].parameter_data.reg.r==B_STACK_POINTER &&
					next_instruction->instruction_parameters[1].parameter_type==P_REGISTER
				){
					w_as_ldp_register_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r,
													  next_instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_indirect_post_add_newline (16,B_STACK_POINTER);
					return next_instruction;
				}
#endif
				w_as_opcode ("ldr");
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
				fprintf (assembly_file,"[x28],#8");
				w_as_newline_after_instruction();
				return instruction;
			}
			case P_INDIRECT_POST_ADD:
				w_as_opcode ("ldr");
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_indirect_post_add_newline (instruction->instruction_parameters[0].parameter_offset,
												instruction->instruction_parameters[0].parameter_data.reg.r);
				return instruction;
			case P_LABEL:
				w_as_opcode_mov();
				w_as_label_parameter (&instruction->instruction_parameters[0]);
				w_as_comma_register (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_newline_after_instruction();
				return instruction;
			case P_INDIRECT_ANY_ADDRESS:
				w_as_opcode_ldr();
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_indirect_newline (instruction->instruction_parameters[0].parameter_offset,
									   instruction->instruction_parameters[0].parameter_data.reg.r);
				return instruction;				
			default:
				internal_error_in_function ("w_as_move_instruction");
				return instruction;
		}
	} else {
		struct parameter s_parameter;

		s_parameter=instruction->instruction_parameters[0];
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
								? (next_instruction->instruction_parameters[0].parameter_offset+8<=offset ||
								   next_instruction->instruction_parameters[0].parameter_offset>=offset+8)
								: (la2_reg==A_STACK_POINTER || la2_reg==B_STACK_POINTER || sa_reg==A_STACK_POINTER || sa_reg==B_STACK_POINTER)
							){
								/* ldr->str ldr->str */
								if ((offset & 7)==0){
									if (next_instruction->instruction_parameters[1].parameter_offset==offset+8){
										if (offset>=-512 && offset<=504){
											w_as_ldr_ldr_or_ldp
												(s_parameter.parameter_offset,s_parameter.parameter_data.reg.r,REGISTER_S0,
												 next_instruction->instruction_parameters[0].parameter_offset,la2_reg,REGISTER_S1);

											w_as_stp_register_register_comma (REGISTER_S0,REGISTER_S1);
											w_as_indirect_newline (offset,sa_reg);
											return next_instruction;
										}
									} else if (next_instruction->instruction_parameters[1].parameter_offset==offset-8){
										if (offset-8>=-512 && offset-8<=504){
											w_as_ldr_ldr_or_ldp
												(s_parameter.parameter_offset,s_parameter.parameter_data.reg.r,REGISTER_S0,
												 next_instruction->instruction_parameters[0].parameter_offset,la2_reg,REGISTER_S1);

											w_as_stp_register_register_comma (REGISTER_S1,REGISTER_S0);
											w_as_indirect_newline (offset-8,sa_reg);
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
									? (next_instruction->instruction_parameters[0].parameter_offset+8<=offset ||
									   next_instruction->instruction_parameters[0].parameter_offset>=offset+8)
									: (la2_reg==A_STACK_POINTER || la2_reg==B_STACK_POINTER || sa_reg==A_STACK_POINTER || sa_reg==B_STACK_POINTER)
								){
									if (next_instruction->instruction_parameters[1].parameter_data.reg.r!=sa_reg &&
										next_instruction->instruction_parameters[1].parameter_data.reg.r!=REGISTER_S0
									){
										/* ldr->str ldr */
										if ((s_parameter.parameter_offset & 7)==0){
											if (next_instruction->instruction_parameters[0].parameter_offset==s_parameter.parameter_offset+8){
												if (s_parameter.parameter_offset>=-512 && s_parameter.parameter_offset<=504){
													w_as_ldp_register_register_comma (REGISTER_S0,next_instruction->instruction_parameters[1].parameter_data.reg.r);
													w_as_indirect_newline (s_parameter.parameter_offset,la2_reg);

													/* parameters of instruction not used below */
													instruction=next_instruction;
													s_reg = REGISTER_S0;
													break;
												}
											} else if (next_instruction->instruction_parameters[0].parameter_offset==s_parameter.parameter_offset-8){
												if (next_instruction->instruction_parameters[0].parameter_offset>=-512 && next_instruction->instruction_parameters[0].parameter_offset<=504){
													w_as_ldp_register_register_comma (next_instruction->instruction_parameters[1].parameter_data.reg.r,REGISTER_S0);
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
									(next_instruction->instruction_parameters[0].parameter_offset+8<=offset ||
									 next_instruction->instruction_parameters[0].parameter_offset>=offset+8)
								){
									if (sa_reg!=REGISTER_S0){
										int offset1;
										
										offset1=s_parameter.parameter_offset;
										if ((offset1 & 7)==0){
											int offset2;
											
											offset2=next_instruction->instruction_parameters[0].parameter_offset;
											if (offset2==offset1+8){
												w_as_ldp_register_register_comma (REGISTER_S0,REGISTER_S1);
												w_as_indirect_newline (offset1,sa_reg);
												
												w_as_opcode ("str");
												w_as_register_comma (REGISTER_S0);
												w_as_indirect_newline (offset,sa_reg);

												d_parameter_p=&next_instruction->instruction_parameters[1];
												instruction=next_instruction;
												s_reg = REGISTER_S1;
												break;
											} else if (offset2==offset1-8){
												w_as_ldp_register_register_comma (REGISTER_S1,REGISTER_S0);
												w_as_indirect_newline (offset2,sa_reg);
												
												w_as_opcode ("str");
												w_as_register_comma (REGISTER_S0);
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
						struct instruction *next_instruction;
						int offset;

						offset=s_parameter.parameter_offset;

						next_instruction=instruction->instruction_next;
						if (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
							next_instruction->instruction_parameters[0].parameter_type==P_INDEXED &&
							next_instruction->instruction_parameters[0].parameter_data.ir->a_reg.r==reg1 &&
							next_instruction->instruction_parameters[0].parameter_data.ir->d_reg.r==reg2 &&
							(next_instruction->instruction_parameters[0].parameter_offset & 3)==(offset & 3) &&
							(next_instruction->instruction_parameters[1].parameter_type==P_REGISTER ||
							 next_instruction->instruction_parameters[1].parameter_type==P_INDIRECT ||
							 next_instruction->instruction_parameters[1].parameter_type==P_PRE_DECREMENT ||
							 next_instruction->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE)
						){
							w_as_opcode ("add");
							w_as_register_comma (REGISTER_S0);	
							w_as_register_comma (reg1);
							w_as_lsl_register_newline (reg2,offset & 3);

							w_as_opcode_ldr();
							w_as_register_comma (REGISTER_S1);
							w_as_indirect_newline (offset>>2,REGISTER_S0);

							if (d_parameter_p->parameter_type==P_INDIRECT){
								w_as_opcode_store();
								w_as_register_comma (REGISTER_S1);
								w_as_indirect_newline (d_parameter_p->parameter_offset,d_parameter_p->parameter_data.reg.r);
							} else if (d_parameter_p->parameter_type==P_PRE_DECREMENT){
								w_as_opcode_store();
								w_as_register_comma (REGISTER_S1);
								w_as_indirect_with_update_newline (-8,d_parameter_p->parameter_data.reg.r);
							} else {
								/* P_INDIRECT_WITH_UPDATE */
								w_as_opcode_store();
								w_as_register_comma (REGISTER_S1);
								w_as_indirect_with_update_newline (d_parameter_p->parameter_offset,d_parameter_p->parameter_data.reg.r);
							}

							return w_as_more_load_indexed (next_instruction,reg1,reg2,REGISTER_S0,offset);
						}
					}
				}
#endif

				w_as_ld_indexed (&s_parameter,REGISTER_S0);
				s_reg = REGISTER_S0;
				break;
			case P_DESCRIPTOR_NUMBER:
				w_as_load_scratch_register_descriptor (s_parameter.parameter_data.l,s_parameter.parameter_offset);
				s_reg = REGISTER_S0;
				break;
			case P_IMMEDIATE:
				w_as_ld_immediate (instruction->instruction_parameters[0].parameter_data.i,REGISTER_S0);
				s_reg = REGISTER_S0;
				break;
			case P_POST_INCREMENT:
				w_as_opcode ("ldr");
				w_as_scratch_register();
				fprintf (assembly_file,",[x28],#8");
				w_as_newline_after_instruction();
				s_reg = REGISTER_S0;
				break;
			case P_INDIRECT_WITH_UPDATE:
				w_as_opcode ("ldr");
				w_as_scratch_register_comma();
				w_as_indirect_with_update (s_parameter.parameter_offset,s_parameter.parameter_data.reg.r);
				w_as_newline_after_instruction();
				s_reg = REGISTER_S0;
				break;
			case P_INDIRECT_POST_ADD:
				w_as_opcode ("ldr");
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
			return w_as_str_or_stp_id (instruction,d_parameter_p,s_reg);			
#else
			w_as_opcode ("str");
			w_as_register_comma (s_reg);
			w_as_indirect_newline (d_parameter_p->parameter_offset,d_parameter_p->parameter_data.reg.r);
#endif
			return instruction;
		case P_PRE_DECREMENT:
		{
#ifndef NO_STRD
			struct instruction *next_instruction;

			next_instruction=instruction->instruction_next;
			if (next_instruction!=NULL){
				if (next_instruction->instruction_icode==IMOVE &&
					next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
					next_instruction->instruction_parameters[1].parameter_type==P_PRE_DECREMENT &&
					next_instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER
				){
					w_as_stp_register_register_comma (next_instruction->instruction_parameters[0].parameter_data.reg.r,s_reg);
					w_as_indirect_with_update_newline (-16,B_STACK_POINTER);
					return next_instruction;
				}

				if (next_instruction->instruction_icode==IJSR &&
					next_instruction->instruction_parameters[0].parameter_type!=P_INDIRECT &&
					next_instruction->instruction_arity>1 &&
					next_instruction->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE &&
					next_instruction->instruction_parameters[1].parameter_offset==-8
				){
					w_as_stp_register_register_comma (REGISTER_X30,s_reg);
					w_as_indirect_with_update_newline (-16,B_STACK_POINTER);
					
					if (next_instruction->instruction_parameters[0].parameter_type==P_REGISTER)
						w_as_opcode ("blr");
					else
						w_as_opcode ("bl");
					w_as_jump_parameter (&next_instruction->instruction_parameters[0]);
					w_as_newline_after_instruction();
					
					return next_instruction;
				}
			}
#endif
			w_as_opcode ("str");
			w_as_register (s_reg);
			fprintf (assembly_file,",[x28,#-8]!");
			w_as_newline_after_instruction();
			return instruction;
		}
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
						w_as_opcode ("add");
						w_as_register_comma (reg3);	
						w_as_register_comma (reg1);
						w_as_lsl_register_newline (reg2,offset & 3);

						w_as_opcode_store();
						w_as_register_comma (s_reg);
						w_as_indirect_newline (offset>>2,reg3);

						do {
							int reg4;
							
							if (next_instruction->instruction_parameters[0].parameter_type==P_REGISTER)
								reg4 = next_instruction->instruction_parameters[0].parameter_data.reg.r;
							else {
								/* P_INDIRECT */
								reg4 = reg3!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

								w_as_opcode_ldr();
								w_as_register_comma (reg4);
								w_as_indirect_newline (next_instruction->instruction_parameters[0].parameter_offset,
													   next_instruction->instruction_parameters[0].parameter_data.reg.r);
							}

							w_as_opcode_store();
							w_as_register_comma (reg4);
							w_as_indirect_newline (next_instruction->instruction_parameters[1].parameter_offset>>2,reg3);

							instruction=next_instruction;
							next_instruction=instruction->instruction_next;

						} while (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
								next_instruction->instruction_parameters[1].parameter_type==P_INDEXED &&
								next_instruction->instruction_parameters[1].parameter_data.ir->a_reg.r==reg1 &&
								next_instruction->instruction_parameters[1].parameter_data.ir->d_reg.r==reg2 &&
								(next_instruction->instruction_parameters[1].parameter_offset & 3)==(offset & 3) &&
								(next_instruction->instruction_parameters[0].parameter_type==P_REGISTER ||
								 next_instruction->instruction_parameters[0].parameter_type==P_INDIRECT)
						);

						return instruction;
					}
				}
#endif

				w_as_opcode ("add");
				w_as_register_comma (reg3);	
				w_as_register_comma (reg1);
				w_as_immediate_newline (offset>>2);

				w_as_opcode_store();
				w_as_register_comma (s_reg);
				w_as_indexed_no_offset_newline (offset,reg3,reg2);
			} else {
				w_as_opcode_store();
				w_as_register_comma (s_reg);
				w_as_indexed_no_offset_ir_newline (d_parameter_p->parameter_offset,d_parameter_p->parameter_data.ir);
			}
			return instruction;
		}
		case P_INDIRECT_WITH_UPDATE:
			w_as_opcode ("str");
			w_as_register_comma (s_reg);
			w_as_indirect_with_update_newline (d_parameter_p->parameter_offset,d_parameter_p->parameter_data.reg.r);
			return instruction;
		case P_INDIRECT_POST_ADD:
			w_as_opcode ("str");
			w_as_register_comma (s_reg);
			w_as_indirect_post_add_newline (d_parameter_p->parameter_offset,d_parameter_p->parameter_data.reg.r);
			return instruction;
		case P_LABEL:
			w_as_opcode_mov();
			w_as_register_comma (s_reg);
			w_as_label_parameter (d_parameter_p);
			w_as_newline_after_instruction();
			return instruction;
		case P_INDIRECT_ANY_ADDRESS:
			w_as_opcode ("str");
			w_as_register_comma (s_reg);
			w_as_indirect_newline (d_parameter_p->parameter_offset,d_parameter_p->parameter_data.reg.r);
			return instruction;
		default:
			internal_error_in_function ("w_as_move_instruction");
	}

	return instruction;
}

static void w_as_move_byte_or_short_instruction (struct instruction *instruction,int size_flag)
{
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_REGISTER:
				w_as_opcode_mov();
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_register (instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_newline_after_instruction();
				return;
			case P_INDIRECT:
				w_as_opcode_load_byte_or_short_register_comma (size_flag,
									   instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_indirect_newline (instruction->instruction_parameters[0].parameter_offset,
									   instruction->instruction_parameters[0].parameter_data.reg.r);
				return;
			case P_INDEXED:
				w_as_ld_indexed_byte_or_short (&instruction->instruction_parameters[0],
								 instruction->instruction_parameters[1].parameter_data.reg.r,size_flag);
				return;
			case P_INDIRECT_WITH_UPDATE:
				w_as_opcode_load_byte_or_short_register_comma (size_flag,
												   instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_indirect_with_update_newline (instruction->instruction_parameters[0].parameter_offset,
												   instruction->instruction_parameters[0].parameter_data.reg.r);
				return;
			case P_INDIRECT_POST_ADD:
				w_as_opcode_load_byte_or_short_register_comma (size_flag,
												instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_indirect_post_add_newline (instruction->instruction_parameters[0].parameter_offset,
												instruction->instruction_parameters[0].parameter_data.reg.r);
				return;
		}
		internal_error_in_function ("w_as_move_byte_or_short_instruction");
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
				w_as_opcode_load_byte_or_short_register_comma (size_flag,REGISTER_S0);
				w_as_indirect_newline (parameter.parameter_offset,parameter.parameter_data.reg.r);
				s_reg = REGISTER_S0;
				break;
			case P_INDEXED:
				w_as_ld_indexed_byte_or_short (&parameter,REGISTER_S0,size_flag);
				s_reg = REGISTER_S0;
				break;
			case P_IMMEDIATE:
				w_as_ld_immediate (instruction->instruction_parameters[0].parameter_data.i,REGISTER_S0);
				s_reg = REGISTER_S0;
				break;
			case P_INDIRECT_WITH_UPDATE:
				w_as_opcode_load_byte_or_short_register_comma (size_flag,REGISTER_S0);
				w_as_indirect_with_update (parameter.parameter_offset,parameter.parameter_data.reg.r);
				w_as_newline_after_instruction();
				s_reg = REGISTER_S0;
				break;
			case P_INDIRECT_POST_ADD:
				w_as_opcode_load_byte_or_short_register_comma (size_flag,REGISTER_S0);
				w_as_indirect_post_add (parameter.parameter_offset,parameter.parameter_data.reg.r);
				w_as_newline_after_instruction();
				s_reg = REGISTER_S0;
				break;
			default:
				internal_error_in_function ("w_as_move_byte_or_short_instruction");
				return;
		}

		switch (instruction->instruction_parameters[1].parameter_type){
			case P_INDIRECT:
				w_as_opcode (size_flag==SIZE_WORD ? "strh" : "strb");
				w_as_word_register_comma (s_reg);
				w_as_indirect_newline (instruction->instruction_parameters[1].parameter_offset,
									   instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_PRE_DECREMENT:
				w_as_opcode ("str");
				w_as_register (s_reg);
				fprintf (assembly_file,",[x28,#-8]!");
				w_as_newline_after_instruction();
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

					w_as_opcode_store_byte_or_short (size_flag);
					w_as_word_register_comma (s_reg);
					w_as_indexed_no_offset_newline (offset,reg3,reg2);
				} else {
					w_as_opcode_store_byte_or_short (size_flag);
					w_as_word_register_comma (s_reg);
					w_as_indexed_no_offset_ir_newline (instruction->instruction_parameters[1].parameter_offset,
					  instruction->instruction_parameters[1].parameter_data.ir);
				}
				return;
			}
			case P_INDIRECT_WITH_UPDATE:
				w_as_opcode (size_flag==SIZE_WORD ? "strh" : "strb");
				w_as_word_register_comma (s_reg);
				w_as_indirect_with_update_newline (instruction->instruction_parameters[1].parameter_offset,
												   instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_INDIRECT_POST_ADD:
				w_as_opcode (size_flag==SIZE_WORD ? "strh" : "strb");
				w_as_word_register_comma (s_reg);
				w_as_indirect_post_add_newline (instruction->instruction_parameters[1].parameter_offset,
												instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			default:
				internal_error_in_function ("w_as_move_byte_or_short_instruction");
		}
	}
}

static void w_as_moveqb_instruction (struct instruction *instruction)
{
	int s_reg;

	s_reg = w_as_register_parameter (&instruction->instruction_parameters[0]);

	switch (instruction->instruction_parameters[1].parameter_type){
		case P_INDEXED:
		{
			int offset;

			offset=instruction->instruction_parameters[1].parameter_offset;

			if ((offset & -4)!=0){
				int reg1,reg2,reg3;

				reg1=instruction->instruction_parameters[1].parameter_data.ir->a_reg.r;
				reg2=instruction->instruction_parameters[1].parameter_data.ir->d_reg.r;

				reg3 = (s_reg!=REGISTER_S0) ? REGISTER_S0 : REGISTER_S1;

				w_as_opcode ("add");
				w_as_register_comma (reg3);
				w_as_register_comma (reg1);
				w_as_immediate_newline (offset>>2);

				w_as_opcode_store();
				w_as_word_register_comma (s_reg);
				w_as_indexed_no_offset_newline (offset,reg3,reg2);
			} else {
				w_as_opcode_store();
				w_as_word_register_comma (s_reg);
				w_as_indexed_no_offset_ir_newline (offset,instruction->instruction_parameters[1].parameter_data.ir);
			}
			return;
		}
	}
	internal_error_in_function ("w_as_moveqb_instruction");
}

static void w_as_movem_instruction (struct instruction *instruction)
{
	int n_regs,n_remaining_regs;
	
	n_regs = instruction->instruction_arity-1;
	n_remaining_regs = n_regs;
	
	if (instruction->instruction_parameters[0].parameter_type!=P_REGISTER){
		int s_reg,reg_n;

		if (n_regs>2){
			int offset;

			if (instruction->instruction_parameters[0].parameter_type==P_PRE_DECREMENT)
				offset=0;
			else
				offset=n_regs<<3;

			while (n_remaining_regs>=4){
				offset-=16;
				w_as_opcode ("ldp");
				w_as_register_comma (instruction->instruction_parameters[n_remaining_regs-1].parameter_data.reg.r);
				w_as_register_comma (instruction->instruction_parameters[n_remaining_regs].parameter_data.reg.r);
				w_as_indirect_newline (offset,instruction->instruction_parameters[0].parameter_data.reg.r);
				n_remaining_regs-=2;
			}

			if (n_remaining_regs>2){
				offset-=8;
				w_as_opcode_ldr();
				w_as_register_comma (instruction->instruction_parameters[n_remaining_regs].parameter_data.reg.r);
				w_as_indirect_newline (offset,instruction->instruction_parameters[0].parameter_data.reg.r);
				--n_remaining_regs;
			}
		}

		w_as_opcode ("ldp");
		w_as_register (instruction->instruction_parameters[1].parameter_data.reg.r);
		for (reg_n=1; reg_n<n_remaining_regs; ++reg_n)
			w_as_comma_register (instruction->instruction_parameters[1+reg_n].parameter_data.reg.r);

		if (instruction->instruction_parameters[0].parameter_type==P_PRE_DECREMENT){
			fprintf (assembly_file,",[");
			w_as_register (instruction->instruction_parameters[0].parameter_data.reg.r);
			fprintf (assembly_file,",#-%d]!\n",n_regs<<3);
		} else if (instruction->instruction_parameters[0].parameter_type==P_POST_INCREMENT){
			fprintf (assembly_file,",[");
			w_as_register (instruction->instruction_parameters[0].parameter_data.reg.r);
			fprintf (assembly_file,"],#%d\n",n_regs<<3);
		} else {
			internal_error_in_function ("w_as_movem_instruction");
			return;
		}
	} else {
		int d_reg,reg_n;

		if (n_regs>2){
			int offset;

			if (instruction->instruction_parameters[n_regs].parameter_type==P_PRE_DECREMENT)
				offset=0;
			else
				offset=n_regs<<4;

			while (n_remaining_regs>=4){
				offset-=16;
				n_remaining_regs-=2;
				w_as_opcode ("stp");
				w_as_register_comma (instruction->instruction_parameters[n_remaining_regs].parameter_data.reg.r);
				w_as_register_comma (instruction->instruction_parameters[n_remaining_regs+1].parameter_data.reg.r);
				w_as_indirect_newline (offset,instruction->instruction_parameters[n_regs].parameter_data.reg.r);
			}

			if (n_remaining_regs>2){
				offset-=8;
				--n_remaining_regs;
				w_as_opcode_store();
				w_as_register_comma (instruction->instruction_parameters[n_remaining_regs].parameter_data.reg.r);
				w_as_indirect_newline (offset,instruction->instruction_parameters[n_regs].parameter_data.reg.r);
			}
		}

		w_as_opcode ("stp");
		w_as_register (instruction->instruction_parameters[0].parameter_data.reg.r);
		for (reg_n=1; reg_n<n_remaining_regs; ++reg_n)
			w_as_comma_register (instruction->instruction_parameters[reg_n].parameter_data.reg.r);

		if (instruction->instruction_parameters[n_regs].parameter_type==P_PRE_DECREMENT){
			fprintf (assembly_file,",[");
			w_as_register (instruction->instruction_parameters[n_regs].parameter_data.reg.r);
			fprintf (assembly_file,",#-%d]!\n",n_regs<<3);
		} else if (instruction->instruction_parameters[n_regs].parameter_type==P_POST_INCREMENT){
			fprintf (assembly_file,",[");
			w_as_register (instruction->instruction_parameters[n_regs].parameter_data.reg.r);
			fprintf (assembly_file,"],#%d\n",n_regs<<3);
		} else {
			internal_error_in_function ("w_as_movem_instruction");
			return;		
		}
	}
}

static void w_as_loadsqb_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		int reg;

		reg=instruction->instruction_parameters[1].parameter_data.reg.r;
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_INDIRECT:
				w_as_opcode ("ldrsw");
				w_as_register_comma (reg);
				w_as_indirect_newline (instruction->instruction_parameters[0].parameter_offset,
									   instruction->instruction_parameters[0].parameter_data.reg.r);
				return;
			case P_REGISTER:
				w_as_opcode ("sxtw");
				w_as_register_comma (reg);
				w_as_word_register (instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_newline();
				return;
			case P_INDEXED:
				w_as_ldsw_indexed (&instruction->instruction_parameters[0],reg);
				return;
		}
	}
	internal_error_in_function ("w_as_loadsqb_instruction");
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
				w_as_load_label_with_offset (instruction->instruction_parameters[1].parameter_data.reg.r,
											 instruction->instruction_parameters[0].parameter_data.l,
											 instruction->instruction_parameters[0].parameter_offset);
				return;
		}
	}
	internal_error_in_function ("w_as_lea_instruction");
}

static void w_as_add_or_sub_instruction (struct instruction *instruction,char *opcode,char *opcode_neg)
{
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		if (add_or_sub_immediate (instruction->instruction_parameters[0].parameter_data.i)){
			w_as_opcode (opcode);
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_immediate_newline (instruction->instruction_parameters[0].parameter_data.i);
		} else {
			if (w_as_ld_immediate_or_negative (instruction->instruction_parameters[0].parameter_data.i,REGISTER_S0) > 0)
				w_as_opcode (opcode);
			else
				w_as_opcode (opcode_neg);

			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_register_newline (REGISTER_S0);
		}
	} else {
		int reg0;

		reg0 = w_as_register_parameter (&instruction->instruction_parameters[0]);

		w_as_opcode (opcode);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_newline (reg0);
	}
}

static void w_as_dyadic_adc_or_sbc_instruction (struct instruction *instruction,char *opcode)
{
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE &&
		instruction->instruction_parameters[0].parameter_data.i==0)
	{
		w_as_opcode (opcode);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_zero_register_newline();
	} else {
		int reg0;

		reg0 = w_as_register_parameter (&instruction->instruction_parameters[0]);

		w_as_opcode (opcode);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_newline (reg0);
	}
}

static void w_as_dyadic_bitmask_instruction (struct instruction *instruction,char *opcode)
{
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE &&
		bitmask_immediate (instruction->instruction_parameters[0].parameter_data.i))
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

static void w_as_addi_instruction (struct instruction *instruction)
{
	long i;

	i = instruction->instruction_parameters[2].parameter_data.i;

	if (add_or_sub_immediate (i)){
		w_as_opcode ("add");
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
		w_as_immediate_newline (i);
	} else {
		if (w_as_ld_immediate_or_negative (i,REGISTER_S0) > 0)
			w_as_opcode ("add");
		else
			w_as_opcode ("sub");
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
		w_as_register_newline (REGISTER_S0);
	}
}

static void w_as_shift_reg_reg_imm_instruction (struct instruction *instruction,char *opcode)
{
	long i;

	i = instruction->instruction_parameters[2].parameter_data.i;

	if (i>=0 && i<=63){
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

static void w_as_mul_instruction (struct instruction *instruction,char *opcode)
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

		w_as_opcode (opcode);
		w_as_register_comma (reg1);
		w_as_register_comma (reg0);
		w_as_register_newline (reg1);
	} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
		int reg0;

		reg0 = w_as_register_parameter (&instruction->instruction_parameters[0]);

		w_as_opcode (opcode);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (reg0);
		w_as_register_newline (instruction->instruction_parameters[1].parameter_data.reg.r);
	} else {
		int reg0;

		reg0 = w_as_register_parameter (&instruction->instruction_parameters[0]);

		w_as_opcode (opcode);
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
		w_as_immediate_newline (instruction->instruction_parameters[0].parameter_data.i & 63);
	} else {
		w_as_opcode (opcode);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
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

			w_as_load_label_with_offset (reg2,instruction->instruction_parameters[0].parameter_data.l,
											  instruction->instruction_parameters[0].parameter_offset);

			w_as_opcode ("cmp");
			w_as_register_comma (reg1);
			w_as_register_newline (reg2);
			return;
		}
		case P_IMMEDIATE:
		{
			int reg1;

			reg1 = w_as_register_parameter (&instruction->instruction_parameters[1]);

			if (add_or_sub_immediate (instruction->instruction_parameters[0].parameter_data.i)){
				w_as_opcode ("cmp");
				w_as_register_comma (reg1);
				w_as_immediate_newline (instruction->instruction_parameters[0].parameter_data.i);
				return;
			} else {
				int reg2;
				
				reg2 = reg1!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;
				
				if (w_as_ld_immediate_or_negative (instruction->instruction_parameters[0].parameter_data.i,reg2) > 0)
					w_as_opcode ("cmp");
				else
					w_as_opcode ("cmn");
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

static struct instruction *w_as_btst_instruction (struct instruction *instruction)
{
	int s_reg;
	
	s_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (instruction->instruction_parameters[1].parameter_type!=P_REGISTER){
		w_as_opcode ("ldr");
		w_as_scratch_register_comma();
		w_as_indirect_newline (instruction->instruction_parameters[1].parameter_offset,s_reg);
		
		s_reg=REGISTER_S0;
	}

	if (instruction->instruction_parameters[0].parameter_data.i==2){
		struct instruction *next_instruction;

		next_instruction=instruction->instruction_next;
		if (next_instruction!=NULL && next_instruction->instruction_icode==IBNE &&
			next_instruction->instruction_next==NULL &&
			(next_instruction->instruction_parameters[0].parameter_data.l->label_flags & FAR_CONDITIONAL_JUMP_LABEL)==0
		){
			w_as_opcode ("tbnz");			
			w_as_register_comma (s_reg);
			w_as_immediate_comma (1);
			w_as_label (next_instruction->instruction_parameters[0].parameter_data.l);
			w_as_newline_after_instruction();			

			return next_instruction;
		}
	}

	w_as_opcode ("tst");
	w_as_register_comma (s_reg);
	w_as_immediate_newline (instruction->instruction_parameters[0].parameter_data.i);

	return instruction;
}

void w_as_jmp_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_INDIRECT:
			w_as_opcode ("ldr");
			w_as_word_scratch_register_comma();
			w_as_indirect_newline (instruction->instruction_parameters[0].parameter_offset,
								   instruction->instruction_parameters[0].parameter_data.reg.r);

			w_as_opcode ("br");
			w_as_scratch_register();
			w_as_newline_after_instruction();
			break;
		case P_REGISTER:
			w_as_opcode ("br");
			w_as_register_newline (instruction->instruction_parameters[0].parameter_data.reg.r);
			break;
		default:
			w_as_opcode ("b");
			w_as_jump_parameter (&instruction->instruction_parameters[0]);
			w_as_newline_after_instruction();
	}
	write_float_constants();
	w_as_opcode (".ltorg");
	w_as_newline();
	instruction_n_after_ltorg = 0u;
	ltorg_at_instruction_n = 0u-1u;
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
				w_as_mov_register_register_newline (REGISTER_X29,REGISTER_X30);

				w_as_opcode ("bl");
				w_as_label_name ("profile_t");
				w_as_newline_after_instruction();			
			}
			
			w_as_opcode ("b");
			if (parameter_p->parameter_data.l->label_number!=0)
				w_as_local_label (parameter_p->parameter_data.l->label_number);
			else
				w_as_label_name (parameter_p->parameter_data.l->label_name);
			
			if (offset!=0)
				fprintf (assembly_file,"+%d",offset);

			break;
		}
		case P_INDIRECT:
		case P_REGISTER:
			w_as_mov_register_register_newline (REGISTER_X29,REGISTER_X30);

			w_as_opcode ("bl");
			w_as_label_name ("profile_t");
			w_as_newline_after_instruction();			
		
			w_as_opcode ("b");
			w_as_jump_parameter (&instruction->instruction_parameters[0]);
			break;		
		default:
			internal_error_in_function ("w_as_jmpp_instruction");
	}

	w_as_newline_after_instruction();
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
		w_as_label (instruction->instruction_parameters[0].parameter_data.l);
	w_as_newline_after_instruction();
}

static void w_as_float_branch_instruction (struct instruction *instruction,char *opcode)
{
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
	
	label_id=next_label_id++;

	w_as_opcode ("bvs");
	w_as_internal_label (label_id);
	w_as_newline();

	w_as_float_branch_instruction (instruction,opcode);

	w_as_define_internal_label (label_id);
}

static void w_as_float_branch_vs_or_instruction (struct instruction *instruction,char *opcode)
{
	w_as_float_branch_instruction (instruction,"bvs");
	w_as_float_branch_instruction (instruction,opcode);
}

static void w_as_jsr_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
		w_as_opcode ("ldr");
		w_as_word_scratch_register_comma();
		w_as_indirect_newline (instruction->instruction_parameters[0].parameter_offset,
							   instruction->instruction_parameters[0].parameter_data.reg.r);

		if (instruction->instruction_arity>1)
			switch (instruction->instruction_parameters[1].parameter_type){
				case P_INDIRECT_WITH_UPDATE:
					w_as_opcode ("str");
					fprintf (assembly_file,"x30,[x28,#%d]!",instruction->instruction_parameters[1].parameter_offset);
					w_as_newline_after_instruction();
					break;
				case P_INDIRECT:
					w_as_opcode ("str");
					fprintf (assembly_file,"x30,[x28,#%d]",instruction->instruction_parameters[1].parameter_offset);
					w_as_newline_after_instruction();
					break;
			}

		w_as_opcode ("blr");
		w_as_scratch_register();
		w_as_newline_after_instruction();
	} else {
		if (instruction->instruction_arity>1)
			switch (instruction->instruction_parameters[1].parameter_type){
				case P_INDIRECT_WITH_UPDATE:
					w_as_opcode ("str");
					fprintf (assembly_file,"x30,[x28,#%d]!",instruction->instruction_parameters[1].parameter_offset);
					w_as_newline_after_instruction();
					break;
				case P_INDIRECT:
					w_as_opcode ("str");
					fprintf (assembly_file,"x30,[x28,#%d]",instruction->instruction_parameters[1].parameter_offset);
					w_as_newline_after_instruction();
					break;
				case P_REGISTER:
					w_as_opcode_mov();
					w_as_register_register_newline (REGISTER_X29,REGISTER_X30);

					if (instruction->instruction_parameters[0].parameter_type==P_REGISTER)
						w_as_opcode ("blr");
					else
						w_as_opcode ("bl");
					w_as_jump_parameter (&instruction->instruction_parameters[0]);
					w_as_newline_after_instruction();

					w_as_opcode_mov();
					w_as_register_register_newline (REGISTER_X30,REGISTER_X29);
					return;
			}
		
		if (instruction->instruction_parameters[0].parameter_type==P_REGISTER)
			w_as_opcode ("blr");
		else
			w_as_opcode ("bl");
		w_as_jump_parameter (&instruction->instruction_parameters[0]);
		w_as_newline_after_instruction();
	}
}

static void w_as_set_condition_instruction (struct instruction *instruction,char *condition)
{
	int r;
	
	r=instruction->instruction_parameters[0].parameter_data.reg.r;
		
	w_as_opcode ("cset");
	w_as_register (r);
	fprintf (assembly_file,",%s",condition);
	w_as_newline_after_instruction();
}

static void w_as_set_float_condition_instruction (struct instruction *instruction,char *condition)
{
	w_as_set_condition_instruction (instruction,condition);
}

static void w_as_set_float_vc_and_condition_instruction (struct instruction *instruction,char *condition)
{
	int r;
	
	w_as_set_condition_instruction (instruction,condition);

	r=instruction->instruction_parameters[0].parameter_data.reg.r;

	w_as_opcode ("cssel");
	w_as_register_comma (r);
	w_as_register_comma (r);
	w_as_zero_register_comma();
	fputs ("vc",assembly_file);
	w_as_newline_after_instruction();
}

static void w_as_asr_register_newline (int reg,int shift)
{
	w_as_register (reg);
	fprintf (assembly_file,",asr #%d",shift);
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
}

static void w_as_div_instruction (struct instruction *instruction)
{
	int i,abs_i,d_reg;
	struct ms ms;

	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (instruction->instruction_parameters[0].parameter_type!=P_IMMEDIATE){
		int s_reg;

		s_reg = w_as_register_parameter (&instruction->instruction_parameters[0]);

		w_as_opcode ("sdiv");
		w_as_register_comma (d_reg);
		w_as_register_comma (d_reg);
		w_as_register_newline (s_reg);

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
			w_as_lsr_register_newline (d_reg,63);

			if (i>=0){
				w_as_opcode ("asr");
				w_as_register_comma (d_reg);
				w_as_register_comma (d_reg);
				w_as_immediate_newline (log2i);
			} else {
				w_as_opcode ("neg");
				w_as_register_comma (d_reg);
				w_as_asr_register_newline (d_reg,log2i);
				w_as_newline_after_instruction();
			}
		} else {
			w_as_opcode ("tst");
			w_as_register_comma (d_reg);
			w_as_immediate_newline (abs_i-1);

			if (i>=0){
				w_as_opcode ("asr");
				w_as_scratch_register_comma();
				w_as_register_comma (d_reg);
				w_as_immediate_newline (log2i);
			} else {
				w_as_opcode ("mvn");
				w_as_scratch_register_comma();
				w_as_asr_register_newline (d_reg,log2i);
			}

			w_as_opcode ("ccmp");
			w_as_register_comma (d_reg);
			w_as_immediate_comma (0);
			w_as_immediate_comma (0);
			fprintf (assembly_file,"ne");
			w_as_newline();

			w_as_opcode ("cinc");
			w_as_register_comma (d_reg);
			w_as_scratch_register_comma();
			if (i>=0)
				fprintf (assembly_file,"mi");
			else
				fprintf (assembly_file,"pl");
			w_as_newline();
		}
		
		return;
	}

	ms=magic (abs_i);
	
	w_as_ld_immediate (ms.m,REGISTER_S0);

	w_as_opcode ("smulh");
	w_as_scratch_register_comma();
	w_as_scratch_register_comma();
	w_as_register_newline (d_reg);

	if (ms.s==0){
		if (ms.m>=0){
			if (i>=0){
				w_as_opcode ("add");
				w_as_register_comma (d_reg);
				w_as_scratch_register_comma();
				w_as_lsr_register_newline (d_reg,63);
			} else {
				w_as_opcode ("asr");
				w_as_register_comma (d_reg);
				w_as_register_comma (d_reg);
				w_as_immediate_newline (63);

				w_as_opcode ("sub");
				w_as_register_comma (d_reg);
				w_as_register_comma (d_reg);
				w_as_scratch_register_newline();
			}
		} else {
			if (i>=0){
				w_as_opcode ("add");
				w_as_register_comma (d_reg);
				w_as_register_comma (d_reg);
				w_as_lsr_register_newline (d_reg,63);

				w_as_opcode ("add");
				w_as_register_comma (d_reg);
				w_as_scratch_register_comma();
				w_as_register_newline (d_reg);
			} else {
				w_as_opcode ("asr");
				w_as_register_comma (REGISTER_S1);
				w_as_register_comma (d_reg);
				w_as_immediate_newline (63);

				w_as_opcode ("sub");
				w_as_register_comma (d_reg);
				w_as_register_comma (REGISTER_S1);
				w_as_register_newline (d_reg);

				w_as_opcode ("sub");
				w_as_register_comma (d_reg);
				w_as_register_comma (d_reg);
				w_as_scratch_register_newline();
			}
		}
	} else {
		if (i>=0){
			w_as_opcode ("lsr");
			w_as_register_comma (REGISTER_S1);
			w_as_register_comma (d_reg);
			w_as_immediate_newline (63);
		} else {
			w_as_opcode ("asr");
			w_as_register_comma (REGISTER_S1);
			w_as_register_comma (d_reg);
			w_as_immediate_newline (63);
		}

		if (ms.m<0){
			w_as_opcode ("add");
			w_as_scratch_register_comma();
			w_as_scratch_register_comma();
			w_as_register_newline (d_reg);
		}

		if (i>=0){
			w_as_opcode ("add");
			w_as_register_comma (d_reg);
			w_as_register_comma (REGISTER_S1);
			w_as_asr_register_newline (REGISTER_S0,ms.s);
		} else {
			w_as_opcode ("sub");
			w_as_register_comma (d_reg);
			w_as_register_comma (REGISTER_S1);
			w_as_asr_register_newline (REGISTER_S0,ms.s);
		}
	}	
}

static void w_as_divu_instruction (struct instruction *instruction)
{
	int d_reg,s_reg;

	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;
	s_reg = w_as_register_parameter (&instruction->instruction_parameters[0]);

	w_as_opcode ("udiv");
	w_as_register_comma (d_reg);
	w_as_register_comma (d_reg);
	w_as_register_newline (s_reg);
}

static void w_as_rem_instruction (struct instruction *instruction)
{
	int i,d_reg;
	struct ms ms;

	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (instruction->instruction_parameters[0].parameter_type!=P_IMMEDIATE){
		int s_reg,scratch_reg;

		if (instruction->instruction_parameters[1].parameter_type!=P_REGISTER){
			internal_error_in_function ("w_as_rem_instruction");
			return;
		}

		s_reg = w_as_register_parameter (&instruction->instruction_parameters[0]);

		scratch_reg = REGISTER_S0;
		if (s_reg==scratch_reg)
			scratch_reg = REGISTER_S1;

		w_as_opcode ("sdiv");
		w_as_register_comma (scratch_reg);
		w_as_register_comma (d_reg);
		w_as_register_newline (s_reg);

		w_as_opcode ("msub");
		w_as_register_comma (d_reg);
		w_as_register_comma (scratch_reg);
		w_as_register_comma (s_reg);
		w_as_register_newline (d_reg);
				
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
		w_as_lsr_register_newline (d_reg,63);

		log2i=0;
		i2=i;
		while (i2>1){
			i2>>=1;
			++log2i;
		}

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

		w_as_opcode ("sub");
		w_as_register_comma (d_reg);
		w_as_scratch_register_comma();
		w_as_lsr_register_newline (d_reg,64-log2i);
		
		return;
	}
	
	ms=magic (i);

	w_as_ld_immediate (ms.m,REGISTER_S0);
	
	w_as_opcode ("smulh");
	w_as_scratch_register_comma();
	w_as_scratch_register_comma();
	w_as_register_newline (d_reg);

	if (ms.s==0){
		if (ms.m>=0){
			w_as_opcode ("add");
			w_as_scratch_register_comma();
			w_as_scratch_register_comma();
			w_as_lsr_register_newline (d_reg,63);
		} else {
			w_as_opcode ("add");
			w_as_register_comma (REGISTER_S1);
			w_as_register_comma (d_reg);
			w_as_lsr_register_newline (d_reg,63);
			
			w_as_opcode ("add");
			w_as_scratch_register_comma();
			w_as_scratch_register_comma();
			w_as_register_newline (REGISTER_S1);
		}
	} else {
		w_as_opcode ("lsr");
		w_as_register_comma (REGISTER_S1);
		w_as_register_comma (d_reg);
		w_as_immediate_newline (63);

		if (ms.m>=0){
			w_as_opcode ("add");
			w_as_scratch_register_comma();
			w_as_register_comma (REGISTER_S1);
			w_as_asr_register_newline (REGISTER_S0,ms.s);
		} else {
			w_as_opcode ("add");
			w_as_scratch_register_comma();
			w_as_scratch_register_comma();
			w_as_register_newline (d_reg);
			
			w_as_opcode ("add");
			w_as_scratch_register_comma();
			w_as_register_comma (REGISTER_S1);
			w_as_asr_register_newline (REGISTER_S0,ms.s);
		}
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
				++n_shifts;
			}
		} else {
			w_as_ld_immediate (i,REGISTER_S1);

			w_as_opcode ("msub");
			w_as_register_comma (d_reg);
			w_as_register_comma (REGISTER_S0);
			w_as_register_comma (REGISTER_S1);
			w_as_register_newline (d_reg);
		}
	}
}

static void w_as_word_instruction (struct instruction *instruction)
{
	fprintf (assembly_file,"\t.word\t%d\n",
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
}

static void w_as_fld_parameter (struct parameter *parameter_p)
{
	switch (parameter_p->parameter_type){
		case P_F_IMMEDIATE:
		{
			int label_number;
			
			label_number=next_label_id++;

			w_as_opcode ("ldr");
			w_as_fp_register_comma (15);
			fprintf (assembly_file,"i_%d",label_number);
			w_as_newline_after_instruction();
			w_as_float_constant (label_number,parameter_p->parameter_data.r);
			return;
		}
		case P_INDIRECT:
			w_as_opcode ("ldr");
			w_as_fp_register_comma (15);
			w_as_indirect_newline (parameter_p->parameter_offset,parameter_p->parameter_data.reg.r);
			return;
		case P_INDEXED:
		{
			int offset;

			offset=parameter_p->parameter_offset;

			w_as_lea_indexed_no_offset_ir (REGISTER_S0,offset,parameter_p->parameter_data.ir);

			w_as_opcode ("ldr");
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
			w_as_opcode ("fcmp");
			w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r);
			fprintf (assembly_file,",#0.0\n:");
		} else {
			w_as_fld_parameter (&instruction->instruction_parameters[0]);

			w_as_opcode ("fcmp");
			w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_fp_register_newline (15);
		}
	} else {
		w_as_opcode ("fcmp");
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
					w_as_opcode ("fmov");	
					w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_fp_register_newline (instruction->instruction_parameters[0].parameter_data.reg.r);
					return;
				case P_INDIRECT:
					w_as_opcode ("ldr");
					w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_indirect_newline (instruction->instruction_parameters[0].parameter_offset,
										   instruction->instruction_parameters[0].parameter_data.reg.r);
					return;
				case P_INDEXED:
				{
					int offset;

					offset=instruction->instruction_parameters[0].parameter_offset;

					w_as_lea_indexed_no_offset_ir (REGISTER_S0,offset,instruction->instruction_parameters[0].parameter_data.ir);

					w_as_opcode ("ldr");
					w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_indirect_newline (offset>>2,REGISTER_S0);
					return;
				}
				case P_F_IMMEDIATE:
				{
					int label_number=next_label_id++;

					w_as_float_constant (label_number,instruction->instruction_parameters[0].parameter_data.r);
					w_as_opcode ("ldr");
					w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					fprintf (assembly_file,"i_%d",label_number);
					w_as_newline_after_instruction();
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
					w_as_opcode ("str");
					w_as_fp_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
					w_as_indirect_newline (instruction->instruction_parameters[1].parameter_offset,
										   instruction->instruction_parameters[1].parameter_data.reg.r);
					return;
				} else {
					int offset;

					offset=instruction->instruction_parameters[1].parameter_offset;

					w_as_lea_indexed_no_offset_ir (REGISTER_S0,offset,instruction->instruction_parameters[1].parameter_data.ir);

					w_as_opcode ("str");
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
					w_as_opcode ("ldr");
					fprintf (assembly_file,"s%d",d_freg);
					w_as_indirect_newline (instruction->instruction_parameters[0].parameter_offset,
										   instruction->instruction_parameters[0].parameter_data.reg.r);
					break;
				case P_INDEXED:
				{
					int offset;

					offset=instruction->instruction_parameters[0].parameter_offset;

					w_as_lea_indexed_no_offset_ir (REGISTER_S0,offset,instruction->instruction_parameters[0].parameter_data.ir);

					w_as_opcode ("ldr");
					fprintf (assembly_file,"s%d",d_freg);
					w_as_comma();
					w_as_indirect_newline (offset>>2,REGISTER_S0);
					break;
				}
				default:
					internal_error_in_function ("w_as_floads_instruction");
					return;
			}

			w_as_opcode ("fcvt");
			w_as_fp_register_comma (d_freg);
			fprintf (assembly_file,"s%d",d_freg);
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

		w_as_opcode ("fcvt");
		fprintf (assembly_file,"s%d",15);
		w_as_comma();
		w_as_fp_register_newline (s_freg);

		switch (instruction->instruction_parameters[1].parameter_type){
			case P_INDIRECT:				
				w_as_opcode ("str");
				fprintf (assembly_file,"s%d",15);
				w_as_comma();
				w_as_indirect_newline (instruction->instruction_parameters[1].parameter_offset,
									   instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_INDEXED:
			{
				int offset;

				offset=instruction->instruction_parameters[1].parameter_offset;

				w_as_lea_indexed_no_offset_ir (REGISTER_S0,offset,instruction->instruction_parameters[1].parameter_data.ir);

				w_as_opcode ("str");
				fprintf (assembly_file,"s%d",15);
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
			w_as_opcode ("fcvtns");
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_fp_register_newline (instruction->instruction_parameters[0].parameter_data.reg.r);
		} else
			internal_error_in_function ("w_as_fmovel_instruction");
	} else {
		int freg;

		freg=instruction->instruction_parameters[1].parameter_data.reg.r;

		switch (instruction->instruction_parameters[0].parameter_type){
			case P_REGISTER:
				w_as_opcode ("scvtf");
				w_as_fp_register_comma (freg);
				w_as_register_newline (instruction->instruction_parameters[0].parameter_data.reg.r);
				return;
			case P_INDIRECT:
				w_as_opcode ("ldr");
				w_as_scratch_register_comma();
				w_as_indirect_newline (instruction->instruction_parameters[0].parameter_offset,
									   instruction->instruction_parameters[0].parameter_data.reg.r);
				break;
			case P_INDEXED:
				w_as_ld_indexed (&instruction->instruction_parameters[0],REGISTER_S0);
				break;
			case P_IMMEDIATE:
				w_as_ld_immediate (instruction->instruction_parameters[0].parameter_data.i,REGISTER_S0);
				break;
			default:
				internal_error_in_function ("w_as_fmovel_instruction");
				return;
		}

		w_as_opcode ("scvtf");
		w_as_fp_register (freg);
		w_as_comma_scratch_register_newline();
		return;
	}
}

static void w_as_rts_instruction (void)
{
	w_as_opcode_mov();
	w_as_register_register_newline (REGISTER_X29,REGISTER_X30);

	w_as_opcode ("ldr");
	fprintf (assembly_file,"x30,[x28],#8");
	w_as_newline_after_instruction();

	w_as_opcode ("ret");
	w_as_register_newline (REGISTER_X29);

	write_float_constants();
	w_as_opcode (".ltorg");
	w_as_newline();
	instruction_n_after_ltorg = 0u;
	ltorg_at_instruction_n = 0u-1u;
}

static void w_as_rtsi_instruction (struct instruction *instruction)
{
	int offset;

	offset = instruction->instruction_parameters[0].parameter_data.imm;

	w_as_opcode_mov();
	w_as_register_register_newline (REGISTER_X29,REGISTER_X30);

	w_as_opcode ("ldr");
	fprintf (assembly_file,"x30,[x28],#%d",offset);
	w_as_newline_after_instruction();

	w_as_opcode ("ret");
	w_as_register_newline (REGISTER_X29);

	write_float_constants();
	w_as_opcode (".ltorg");
	w_as_newline();
	instruction_n_after_ltorg = 0u;
	ltorg_at_instruction_n = 0u-1u;
}

static void w_as_rtsp_instruction (void)
{
	w_as_opcode ("b");
	w_as_label_name ("profile_r");
	w_as_newline_after_instruction();	
}

static void w_as_instructions (struct instruction *instruction)
{
	while (instruction!=NULL){
		switch (instruction->instruction_icode){
			case IMOVE:
				instruction=w_as_move_instruction (instruction);
				break;
			case ILEA:
				w_as_lea_instruction (instruction);
				break;
			case IADD:
				w_as_add_or_sub_instruction (instruction,"add","sub");
				break;
			case ISUB:
				w_as_add_or_sub_instruction (instruction,"sub","add");
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
				w_as_shift_instruction (instruction,"lsl");
				break;
			case ILSR:
				w_as_shift_instruction (instruction,"lsr");
				break;
			case IASR:
				w_as_shift_instruction (instruction,"asr");
				break;
			case IMUL:
				w_as_mul_instruction (instruction,"mul");
				break;
			case IDIV:
				w_as_div_instruction (instruction);
				break;
			case IDIVU:
				w_as_divu_instruction (instruction);
				break;
			case IREM:
				w_as_rem_instruction (instruction);
				break;
			case IAND:
				w_as_dyadic_bitmask_instruction (instruction,"and");
				break;
			case IOR:
				w_as_dyadic_bitmask_instruction (instruction,"orr");
				break;
			case IEOR:
				w_as_dyadic_bitmask_instruction (instruction,"eor");
				break;
			case IADDI:
				w_as_addi_instruction (instruction);
				break;
			case ILSLI:
				w_as_shift_reg_reg_imm_instruction (instruction,"lsl");
				break;
			case ISEQ:
				w_as_set_condition_instruction (instruction,"eq");
				break;
			case ISGE:
				w_as_set_condition_instruction (instruction,"ge");
				break;
			case ISGEU:
				w_as_set_condition_instruction (instruction,"hs");
				break;
			case ISGT:
				w_as_set_condition_instruction (instruction,"gt");
				break;
			case ISGTU:
				w_as_set_condition_instruction (instruction,"hi");
				break;
			case ISLE:
				w_as_set_condition_instruction (instruction,"le");
				break;
			case ISLEU:
				w_as_set_condition_instruction (instruction,"ls");
				break;
			case ISLT:
				w_as_set_condition_instruction (instruction,"lt");
				break;
			case ISLTU:
				w_as_set_condition_instruction (instruction,"lo");
				break;
			case ISNE:
				w_as_set_condition_instruction (instruction,"ne");
				break;
			case ISO:
				w_as_set_condition_instruction (instruction,"vs");
				break;
			case ISNO:
				w_as_set_condition_instruction (instruction,"vc");
				break;
			case ITST:
				w_as_tst_instruction (instruction);
				break;
			case IBTST:
				instruction=w_as_btst_instruction (instruction);
				break;
			case ILOADSQB:
				w_as_loadsqb_instruction (instruction);
				break;
			case IMOVEDB:
				w_as_move_byte_or_short_instruction (instruction,SIZE_WORD);
				break;
			case IMOVEB:
				w_as_move_byte_or_short_instruction (instruction,SIZE_BYTE);
				break;
			case IMOVEQB:
				w_as_moveqb_instruction (instruction);
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
				w_as_dyadic_adc_or_sbc_instruction (instruction,"adc");
				break;
			case ISBB:
				w_as_dyadic_adc_or_sbc_instruction (instruction,"sbc");
				break;
			case IROTR:
				w_as_shift_instruction (instruction,"ror");
				break;
			case IADDO:
				w_as_add_or_sub_instruction (instruction,"adds","subs");
				break;
			case ISUBO:
				w_as_add_or_sub_instruction (instruction,"subs","adds");
				break;
			case IUMULH:
				w_as_mul_instruction (instruction,"umulh");
				break;
			case IFMOVE:
				w_as_fmove_instruction (instruction);
				break;
			case IFADD:
				w_as_dyadic_float_instruction (instruction,"fadd");
				break;
			case IFSUB:
				w_as_float_sub_or_div_instruction (instruction,"fsub");
				break;
			case IFCMP:
				w_as_compare_float_instruction (instruction);
				break;
			case IFDIV:
				w_as_float_sub_or_div_instruction (instruction,"fdiv");
				break;
			case IFMUL:
				w_as_dyadic_float_instruction (instruction,"fmul");
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
				w_as_float_branch_instruction (instruction,"bls");
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
				w_as_monadic_float_instruction (instruction,"fsqrt");
				break;
			case IFNEG:
				w_as_monadic_float_instruction (instruction,"fneg");
				break;
			case IFABS:
				w_as_monadic_float_instruction (instruction,"fabs");
				break;
			case IFSEQ:
				w_as_set_float_condition_instruction (instruction,"eq");
				break;
			case IFSGE:
				w_as_set_float_condition_instruction (instruction,"ge");
				break;
			case IFSGT:
				w_as_set_float_condition_instruction (instruction,"gt");
				break;
			case IFSLE:
				w_as_set_float_condition_instruction (instruction,"ls");
				break;
			case IFSLT:
				w_as_set_float_condition_instruction (instruction,"mi");
				break;
			case IFSNE:
				w_as_set_float_vc_and_condition_instruction (instruction,"ne");
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
	long n_cells;
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

	if (add_or_sub_immediate (n_cells)){
		w_as_opcode ("subs");
		fprintf (assembly_file,"x25,x25,#%d",(int)n_cells);
		w_as_newline_after_instruction();

		w_as_opcode ("blo");
		w_as_internal_label (label_id_1);
		w_as_newline_after_instruction ();
	} else {
		w_as_opcode ("sub");
		fprintf (assembly_file,"x25,x25,#%d",(int)(n_cells & 0xfff000));
		w_as_comma_scratch_register_newline();

		w_as_opcode ("subs");
		fprintf (assembly_file,"x25,x25,#%d",(int)(n_cells & 0xfff));
		w_as_comma_scratch_register_newline();

		w_as_opcode ("bmi");
		w_as_internal_label (label_id_1);
		w_as_newline_after_instruction ();
	}
	
	w_as_define_internal_label (label_id_2);
}

static void w_as_call_and_jump (struct call_and_jump *call_and_jump)
{
	w_as_define_internal_label (call_and_jump->cj_label_id);

	if (call_and_jump->cj_jump_id==-1){
		w_as_opcode ("b");
		w_as_label_name (call_and_jump->cj_call_label_name);
		w_as_newline();		
	} else {
		w_as_opcode ("str");
		fprintf (assembly_file,"x30,[x28,#-8]!");
		w_as_newline_after_instruction();

		w_as_opcode ("bl");
		w_as_label_name (call_and_jump->cj_call_label_name);
		w_as_newline_after_instruction();

		w_as_opcode ("b");
		w_as_internal_label (call_and_jump->cj_jump_id);
		w_as_newline_after_instruction();
	}
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
		w_as_label_name (stack_overflow_label->label_name);
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
		w_as_label_name (stack_overflow_label->label_name);
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
				w_as_load_label_name (REGISTER_A3,block->block_ea_label->label_name);

				w_as_opcode ("b");
				w_as_label_name (eval_upd_labels[n_node_arguments]->label_name);
				w_as_newline();
#ifdef USE_LITERAL_TABLES
				w_as_instruction_without_parameters ("nop");
#endif
			} else {
				w_as_load_label_name (REGISTER_A3,block->block_ea_label->label_name);
#ifdef USE_LITERAL_TABLES
				w_as_load_label (REGISTER_S0,block->block_profile_function_label);
#endif
				w_as_opcode ("b");
				w_as_label_name (eval_upd_labels[n_node_arguments]->label_name);
				fprintf (assembly_file,"-8");
				w_as_newline();

#ifndef USE_LITERAL_TABLES
				w_as_load_label (REGISTER_S0,block->block_profile_function_label);

				w_as_opcode ("b");
				fprintf (assembly_file,".-20");
				w_as_newline();
#endif
			}
		} else {
			w_as_opcode ("b");
			w_as_label_name (block->block_ea_label->label_name);
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
	w_as_load_scratch_register_descriptor (block->block_profile_function_label,0);

	w_as_mov_register_register_newline (REGISTER_X29,REGISTER_X30);

	w_as_opcode ("bl");
	
	if (block->block_n_node_arguments>-100)
		w_as_label_name (block->block_profile==2 ? "profile_n2" : "profile_n");
	else {
		switch (block->block_profile){
			case 2:  w_as_label_name ("profile_s2"); break;
			case 4:  w_as_label_name ("profile_l"); break;
			case 5:  w_as_label_name ("profile_l2"); break;
			default: w_as_label_name ("profile_s");
		}
	}
	w_as_newline_after_instruction();
}

#ifdef NEW_APPLY
extern LABEL *add_empty_node_labels[];

static void w_as_apply_update_entry (struct basic_block *block)
{
	int n_node_arguments;

	n_node_arguments=block->block_n_node_arguments;
	if (n_node_arguments<-200){
		w_as_opcode ("b");
		w_as_label_name (block->block_descriptor->label_name);
		w_as_newline();

		if (block->block_ea_label==NULL){
			if (block->block_profile)
				w_as_profile_call (block);

			w_as_instruction_without_parameters ("nop");
			w_as_instruction_without_parameters ("nop");
			return;
		}

		n_node_arguments+=300;
	} else
		n_node_arguments+=200;

	if (block->block_profile)
		w_as_profile_call (block);
	
	if (n_node_arguments==0){
		w_as_opcode ("b");
		w_as_label_name (block->block_ea_label->label_name);
		w_as_newline();

		w_as_instruction_without_parameters ("nop");
	} else {
		w_as_opcode ("bl");
		w_as_label_name (add_empty_node_labels[n_node_arguments]->label_name);
		w_as_newline();

		w_as_opcode ("b");
		w_as_label_name (block->block_ea_label->label_name);
		w_as_newline();
	}
}
#endif

void write_assembly (VOID)
{
	struct basic_block *block;
	struct call_and_jump *call_and_jump;

	instruction_n_after_ltorg = 0u;
	ltorg_at_instruction_n = 0u-1u;

	w_as_to_code_section();

	float_constant_l=&first_float_constant;
	first_float_constant=NULL;

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
	
	write_float_constants();
}
