/*
	File:      cgpwas.c
	Machine:   Power Macintosh
	Author:    John van Groningen
	Copyright: University of Nijmegen
*/

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>

#include "cgport.h"

#ifdef MACH_O
#define GNU_SYNTAX
#endif
#undef ONLY_REGISTER_NUMBERS

#ifdef GNU_SYNTAX
# define IF_GNU(a,b) a
#else
# define IF_GNU(a,b) b
#endif

#ifdef MACH_O
# define IF_MACH_O(a,b) a
#else
# define IF_MACH_O(a,b) b
#endif

#ifndef MACH_O
# define NEWLINE_STRING "\015"
# define NEWLINE_CHAR '\015'
#else
# define NEWLINE_STRING "\012"
# define NEWLINE_CHAR '\012'
#endif

#ifdef G_POWER

#include "cgrconst.h"
#include "cgtypes.h"
#include "cg.h"
#include "cgiconst.h"
#include "cgcode.h"
#include "cginstructions.h"
#include "cgptoc.h"
#include "cgpwas.h"

#ifdef GNU_C
# include <ppc_intrinsics.h>
#endif

#define FP_REVERSE_SUB_DIV_OPERANDS 1

#define for_l(v,l,n) for(v=(l);v!=NULL;v=v->n)

#define IO_BUF_SIZE 8192

static FILE *assembly_file;

static void w_as_newline (VOID)
{
	putc (NEWLINE_CHAR,assembly_file);
}

static void w_as_opcode (char *opcode)
{
	fprintf (assembly_file,"\t%s\t",opcode);
}

static void w_as_instruction_without_parameters (char *opcode)
{
	fprintf (assembly_file,"\t%s" NEWLINE_STRING,opcode);
}

static void w_as_define_local_label (int label_number)
{
	fprintf (assembly_file,"l_%d:" NEWLINE_STRING,label_number);
}

static void w_as_define_internal_label (int label_number)
{
	fprintf (assembly_file,"i_%d:" NEWLINE_STRING,label_number);
}

#define DC_L IF_GNU (".long","dc.l")
#define DC_B IF_GNU (".byte","dc.b")

void w_as_internal_label_value (int label_id)
{
	fprintf (assembly_file,"\t" DC_L "\ti_%d" NEWLINE_STRING,label_id);
}

static int in_data_section;

static int data_module_number,code_module_number;

static void w_as_new_code_module (VOID)
{
	++code_module_number;
#ifdef GNU_SYNTAX
	fprintf (assembly_file,IF_MACH_O ("\t.text" NEWLINE_STRING,"\t.section\t\".text\"" NEWLINE_STRING));
#else
	fprintf (assembly_file,"\tcsect\t.m_%d{PR}" NEWLINE_STRING,code_module_number);
#endif
	in_data_section=0;
}

static void w_as_to_code_section (VOID)
{
	if (in_data_section){
		in_data_section=0;
#ifdef GNU_SYNTAX
		fprintf (assembly_file,IF_MACH_O ("\t.text" NEWLINE_STRING,"\t.section\t\".text\"" NEWLINE_STRING));
#else
		fprintf (assembly_file,"\tcsect\t.m_%d{PR}" NEWLINE_STRING,code_module_number);
#endif
	}
}

void w_as_new_data_module (VOID)
{
	++data_module_number;
#ifdef GNU_SYNTAX
	fprintf (assembly_file,IF_MACH_O ("\t.data" NEWLINE_STRING,"\t.section\t\".data\"" NEWLINE_STRING));
#else
	fprintf (assembly_file,"\tcsect\t.d_%d{RW}" NEWLINE_STRING,data_module_number);
#endif
	in_data_section=1;
}

void w_as_to_data_section (VOID)
{
	if (!in_data_section){
		in_data_section=1;
#ifdef GNU_SYNTAX
		fprintf (assembly_file,IF_MACH_O ("\t.data" NEWLINE_STRING,"\t.section\t\".data\"" NEWLINE_STRING));
#else
		fprintf (assembly_file,"\tcsect\t.d_%d{RW}" NEWLINE_STRING,data_module_number);
#endif
	}
}

void w_as_word_in_data_section (int n)
{
	w_as_to_data_section();
	w_as_opcode (IF_GNU (IF_MACH_O (".short",".word"),"dc.w"));
	fprintf (assembly_file,"%d",n);
	w_as_newline();
}

void w_as_long_in_data_section (int n)
{
	w_as_to_data_section();
	w_as_opcode (DC_L);
	fprintf (assembly_file,"%d",n);
	w_as_newline();
}

void w_as_label_in_data_section (char *label_name)
{
	w_as_to_data_section ();
	fprintf (assembly_file,"\t" DC_L "\t%s" NEWLINE_STRING,label_name);
}

static void w_as_label_in_code_section (char *label_name)
{
	w_as_to_code_section ();
	fprintf (assembly_file,"\t" DC_L "\t%s" NEWLINE_STRING,label_name);
}

void w_as_descriptor_in_data_section (char *label_name)
{
	w_as_to_data_section ();
	fprintf (assembly_file,"\t" DC_L "\t%s+2" NEWLINE_STRING,label_name);
}

#define MAX_BYTES_PER_LINE 16

static int w_as_data (int n,char *data_p,int length)
{
	int i,in_string;
	unsigned char *data;
	
	data=(unsigned char*)data_p;
	
	in_string=0;
	
	for (i=0; i<length; ++i){
		int c;
		
		if (n>=MAX_BYTES_PER_LINE){
			if (in_string){
				putc (IF_GNU ('\"','\''),assembly_file);
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
				w_as_opcode (IF_MACH_O (".ascii",DC_B));
				putc (IF_GNU ('\"','\''),assembly_file);
				in_string=1;
			}
			putc (c,assembly_file);
		} else {
			if (n==0)
				w_as_opcode (DC_B);
			else {
				if (in_string){
					putc (IF_GNU ('\"','\''),assembly_file);
					w_as_newline();
					w_as_opcode (DC_B);
					in_string=0;
				} else
					putc (',',assembly_file);
			}

			fprintf (assembly_file,"0x%02x",c);
		}
		++n;
	}
	
	if (in_string){
		putc (IF_GNU ('\"','\''),assembly_file);
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
			w_as_opcode (DC_B);
		else
			putc (',',assembly_file);
		fprintf (assembly_file,"0");
		++n;
	}
	return n;
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
	w_as_newline();
}

void w_as_define_data_label (int label_number)
{
	w_as_to_data_section();
	
	w_as_define_local_label (label_number);
}

void w_as_abc_string_in_data_section (char *string,int length)
{
	int n;
	
	w_as_to_data_section();
	
	w_as_opcode (DC_L);
	fprintf (assembly_file,"%d" NEWLINE_STRING,length);
	n=w_as_data (0,string,length);
	if (length & 3)
		n=w_as_zeros (n,4-(length & 3));
	if (n>0)
		w_as_newline();
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

void w_as_descriptor_string_in_data_section (char *string,int length,int string_label_id,LABEL *string_label)
{
	int n;
	
	w_as_to_data_section();
	
	w_as_define_internal_label (string_label_id);
	w_as_define_local_label (string_label->label_number);

	w_as_opcode (DC_L);
	fprintf (assembly_file,"%d" NEWLINE_STRING,length);
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
		w_as_opcode (IF_GNU (IF_MACH_O (".globl",".global"),"export"));
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
	
	w_as_opcode (DC_L);
	fprintf (assembly_file,"%d" NEWLINE_STRING,length);
	n=w_as_data (0,string,length);
	if (length & 3)
		n=w_as_zeros (n,4-(length & 3));
	if (n>0)
		w_as_newline();
}

#define REGISTER_O0 (-13)
#define REGISTER_O1 (-23)
#define REGISTER_R0 (-24)
#define RTOC (-22)
#define REGISTER_R3 (-21)
#define REGISTER_SP (-12)

static unsigned char real_reg_num [32] =
{
	0,12,2,3,4,5,6,7,8,9,10,11,1,13,14,15,
	16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
};

#define reg_num(r) (real_reg_num[(r)+24])

static void w_as_indirect (int i,int reg)
{
#ifdef ONLY_REGISTER_NUMBERS
	if (i>=0)
		fprintf (assembly_file,"%d(%d)",i,reg_num (reg));
	else
		fprintf (assembly_file,"-%d(%d)",-i,reg_num (reg));
#else
	if (i>=0)
		fprintf (assembly_file,"%d(r%d)",i,reg_num (reg));
	else
		fprintf (assembly_file,"-%d(r%d)",-i,reg_num (reg));
#endif
}

static void w_as_indexed (int offset,struct index_registers *index_registers)
{
	int reg1,reg2;
	
	if (offset!=0)
		internal_error_in_function ("w_as_indexed");

	reg1=index_registers->a_reg.r;
	reg2=index_registers->d_reg.r;
#ifdef ONLY_REGISTER_NUMBERS
	fprintf (assembly_file,"%d,%d",reg_num (reg1),reg_num (reg2));
#else
	fprintf (assembly_file,"r%d,r%d",reg_num (reg1),reg_num (reg2));
#endif
}

static void w_as_register (int reg)
{
#ifdef ONLY_REGISTER_NUMBERS
	fprintf (assembly_file,"%d",reg_num (reg));
#else
	fprintf (assembly_file,"r%d",reg_num (reg));
#endif
}

static void w_as_register_comma (int reg)
{
#ifdef ONLY_REGISTER_NUMBERS
	fprintf (assembly_file,"%d,",reg_num (reg));
#else
	fprintf (assembly_file,"r%d,",reg_num (reg));
#endif
}

static void w_as_register_newline (int reg)
{
#ifdef ONLY_REGISTER_NUMBERS
	fprintf (assembly_file,"%d" NEWLINE_STRING,reg_num (reg));
#else
	fprintf (assembly_file,"r%d" NEWLINE_STRING,reg_num (reg));
#endif
}

void w_as_c_string_and_label_in_code_section (char *string,int length,char *label_name)
{
	int n;
	
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
#ifdef ONLY_REGISTER_NUMBERS
	fprintf (assembly_file,"%d",fp_reg+14);
#else
	fprintf (assembly_file,IF_MACH_O ("f%d","fp%d"),fp_reg+14);
#endif
}

static void w_as_fp_register_comma (int fp_reg)
{
#ifdef ONLY_REGISTER_NUMBERS
	fprintf (assembly_file,"%d,",fp_reg+14);
#else
	fprintf (assembly_file,IF_MACH_O ("f%d,","fp%d,"),fp_reg+14);
#endif
}

static void w_as_comma (VOID)
{
	putc (',',assembly_file);
}

static void w_as_toc_label (struct toc_label *toc_label)
{
	struct label *label;
	int offset,t_label_number;
	
	offset=toc_label->toc_label_offset;
	label=toc_label->toc_label_label;	
	t_label_number=toc_label->toc_t_label_number;
	
	if (offset!=0){
		w_as_opcode ("tc");
		fprintf (assembly_file,"t_%d{TC}",t_label_number);
		w_as_comma();
		if (label->label_number!=0)
			w_as_local_label (label->label_number);
		else
			w_as_label (label->label_name);
		if (offset>=0)
			fprintf (assembly_file,"+%d" NEWLINE_STRING,offset);
		else
			fprintf (assembly_file,"-%d" NEWLINE_STRING,-offset);
	} else {
		w_as_opcode ("tc");
		fprintf (assembly_file,"t_%d{TC}",t_label_number);
		w_as_comma();
		if (label->label_number!=0)
			w_as_local_label (label->label_number);
		else
			w_as_label (label->label_name);
		w_as_newline();
	}
}

#ifdef GNU_SYNTAX
static void load_label (struct label *label,int offset,int reg)
{
	w_as_opcode ("lis");
	w_as_register_comma (reg);

# ifdef MACH_O
	fprintf (assembly_file,"ha16(");
# endif
	if (label->label_number!=0)
		w_as_local_label (label->label_number);
	else
		w_as_label (label->label_name);
	if (offset!=0){
		if (offset>=0)
			fprintf (assembly_file,"+%d",offset);
		else
			fprintf (assembly_file,"-%d",-offset);
	}
# ifdef MACH_O
	fprintf (assembly_file,")" NEWLINE_STRING);
# else
	fprintf (assembly_file,"@ha" NEWLINE_STRING);
# endif

	w_as_opcode ("addi");
	w_as_register_comma (reg);
	w_as_register_comma (reg);
	
# ifdef MACH_O
	fprintf (assembly_file,"lo16(");
# endif
	if (label->label_number!=0)
		w_as_local_label (label->label_number);
	else
		w_as_label (label->label_name);
	if (offset!=0){
		if (offset>=0)
			fprintf (assembly_file,"+%d",offset);
		else
			fprintf (assembly_file,"-%d",-offset);
	}
# ifdef MACH_O
	fprintf (assembly_file,")" NEWLINE_STRING);
# else
	fprintf (assembly_file,"@l" NEWLINE_STRING);
# endif
}
#endif

static void w_as_load_descriptor (struct parameter *parameter,int reg)
{
#ifdef GNU_SYNTAX
	load_label (parameter->parameter_data.l,2+(parameter->parameter_offset<<3),reg);
#else
	int t_label_number;

	t_label_number=make_toc_label (parameter->parameter_data.l,2+(parameter->parameter_offset<<3));

	w_as_opcode ("lwz");
	w_as_register_comma (reg);
	fprintf (assembly_file,"t_%d{TC}(RTOC)" NEWLINE_STRING,t_label_number);
#endif
}

static void w_as_load_label_parameter (struct parameter *parameter,int reg)
{
#ifdef GNU_SYNTAX
	load_label (parameter->parameter_data.l,parameter->parameter_offset,reg);
#else
	int t_label_number;

	t_label_number=make_toc_label (parameter->parameter_data.l,parameter->parameter_offset);

	w_as_opcode ("lwz");
	w_as_register_comma (reg);
	fprintf (assembly_file,"t_%d{TC}(RTOC)" NEWLINE_STRING,t_label_number);
#endif
}

static void w_as_load_label (struct label *label,int reg)
{
#ifdef GNU_SYNTAX
	load_label (label,0,reg);
#else
	int t_label_number;

	t_label_number=make_toc_label (label,0);

	w_as_opcode ("lwz");
	w_as_register_comma (reg);
	fprintf (assembly_file,"t_%d{TC}(RTOC)" NEWLINE_STRING,t_label_number);
#endif
}

static void w_as_load_label_with_offset (struct label *label,int offset,int reg)
{
#ifdef GNU_SYNTAX
	load_label (label,offset,reg);
#else
	int t_label_number;

	t_label_number=make_toc_label (label,offset);

	w_as_opcode ("lwz");
	w_as_register_comma (reg);
	fprintf (assembly_file,"t_%d{TC}(RTOC)" NEWLINE_STRING,t_label_number);
#endif
}

static void w_as_parameter (register struct parameter *parameter)
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
#ifdef ONLY_REGISTER_NUMBERS
			fprintf (assembly_file,"%d",parameter->parameter_data.reg.r+14);
#else
			fprintf (assembly_file,IF_MACH_O ("f%d","fp%d"),parameter->parameter_data.reg.r+14);
#endif
			break;
		default:
			internal_error_in_function ("w_as_parameter");
	}
}

static int w_as_register_parameter (struct parameter parameter,int size_flag)
{
	switch (parameter.parameter_type){
		case P_DESCRIPTOR_NUMBER:
			w_as_load_descriptor (&parameter,REGISTER_O0);

			return REGISTER_O0;
		case P_IMMEDIATE:
		{
			int i;
				
			i=parameter.parameter_data.i;
			
			if (i!=(WORD)i){
				w_as_opcode ("lis");
				w_as_register_comma (REGISTER_O0);
				w_as_immediate ((i-(WORD)i)>>16);
				w_as_newline();
			
				i=(WORD)i;

				w_as_opcode ("addi");
				w_as_register_comma (REGISTER_O0);
				w_as_register_comma (REGISTER_O0);
				w_as_immediate (i);
				w_as_newline();
			} else {
				w_as_opcode ("li");
				w_as_register_comma (REGISTER_O0);
				w_as_immediate (i);
				w_as_newline();
			}		

			return REGISTER_O0;
		}
		case P_REGISTER:
			return parameter.parameter_data.reg.r;
		case P_INDIRECT:
			w_as_opcode (size_flag==SIZE_LONG ? "lwz" :
						 size_flag==SIZE_WORD ? "lha" : /* "ldsb" */ "lbz");
			w_as_register_comma (REGISTER_O0);
			w_as_indirect (parameter.parameter_offset,parameter.parameter_data.reg.r);
			w_as_newline();

			return REGISTER_O0;
		case P_INDIRECT_WITH_UPDATE:
			w_as_opcode (size_flag==SIZE_LONG ? "lwzu" :
						 size_flag==SIZE_WORD ? "lhau" : /* "ldsb" */ "lbzu");
			w_as_register_comma (REGISTER_O0);
			w_as_indirect (parameter.parameter_offset,parameter.parameter_data.reg.r);
			w_as_newline();

			return REGISTER_O0;
		case P_INDEXED:
			w_as_opcode (size_flag==SIZE_LONG ? "lwzx" :
						 size_flag==SIZE_WORD ? "lhax" : /*"ldsbx" */ "lbzx" );
			w_as_register_comma (REGISTER_O0);
			w_as_indexed (parameter.parameter_offset,parameter.parameter_data.ir);
			w_as_newline();

			return REGISTER_O0;
		default:
			internal_error_in_function ("w_as_register_parameter");
			return REGISTER_O0;
	}
}

static void w_as_move_instruction (struct instruction *instruction,int size_flag)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_REGISTER:
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_DESCRIPTOR_NUMBER:
					w_as_load_descriptor (
						&instruction->instruction_parameters[0],
						instruction->instruction_parameters[1].parameter_data.reg.r
					);
					return;
				case P_IMMEDIATE:
				{
					int i,r;
					
					i=instruction->instruction_parameters[0].parameter_data.i;
					r=instruction->instruction_parameters[1].parameter_data.reg.r;
					
					if (i!=(WORD)i){
						w_as_opcode ("lis");
						w_as_register_comma (r);
						w_as_immediate ((i-(WORD)i)>>16);
						w_as_newline();
					
						i=(WORD)i;

						w_as_opcode ("addi");
						w_as_register_comma (r);
						w_as_register_comma (r);
						w_as_immediate (i);
						w_as_newline();
					} else {
						w_as_opcode ("li");
						w_as_register_comma (r);
						w_as_immediate (i);
						w_as_newline();
					}		
					return;
				}
				case P_REGISTER:
					w_as_opcode ("mr");
					w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_register (instruction->instruction_parameters[0].parameter_data.reg.r);
					w_as_newline();
					return;
				case P_INDIRECT:
					w_as_opcode (size_flag==SIZE_LONG ? "lwz" :
								 size_flag==SIZE_WORD ? "lha" : "lbz");
					w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_indirect (instruction->instruction_parameters[0].parameter_offset,
								   instruction->instruction_parameters[0].parameter_data.reg.r);
					w_as_newline();
					return;
				case P_INDIRECT_WITH_UPDATE:
					w_as_opcode (size_flag==SIZE_LONG ? "lwzu" :
								 size_flag==SIZE_WORD ? "lhau" : "lbzu");
					w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_indirect (instruction->instruction_parameters[0].parameter_offset,
								   instruction->instruction_parameters[0].parameter_data.reg.r);
					w_as_newline();
					return;
				case P_INDEXED:
					w_as_opcode (size_flag==SIZE_LONG ? "lwzx" :
								 size_flag==SIZE_WORD ? "lhax" : "lbzx");
					w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_indexed (instruction->instruction_parameters[0].parameter_offset,
								  instruction->instruction_parameters[0].parameter_data.ir);
					w_as_newline();
					return;
				default:
					internal_error_in_function ("w_as_move_instruction");
					return;
			}
		case P_INDIRECT:
		{
			int reg;

			reg=w_as_register_parameter (instruction->instruction_parameters[0],size_flag);

			w_as_opcode (size_flag==SIZE_LONG ? "stw" :
						 size_flag==SIZE_WORD ? "sth" : "stb");
			w_as_register_comma (reg);
			w_as_indirect (instruction->instruction_parameters[1].parameter_offset,
						   instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_newline();
			return;
		}
		case P_INDIRECT_WITH_UPDATE:
		{
			int reg;

			reg=w_as_register_parameter (instruction->instruction_parameters[0],size_flag);

			w_as_opcode (size_flag==SIZE_LONG ? "stwu" :
						 size_flag==SIZE_WORD ? "sthu" : "stbu");
			
			w_as_register_comma (reg);
			w_as_indirect (instruction->instruction_parameters[1].parameter_offset,
						   instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_newline();
			return;
		}
		case P_INDEXED:
		{
			int reg;

			reg=w_as_register_parameter (instruction->instruction_parameters[0],size_flag);

			w_as_opcode (size_flag==SIZE_LONG ? "stwx" :
						 size_flag==SIZE_WORD ? "sthx" : "stbx");
			w_as_register_comma (reg);
			w_as_indexed (instruction->instruction_parameters[1].parameter_offset,
						  instruction->instruction_parameters[1].parameter_data.ir);
			w_as_newline();
			return;
		}
		case P_INDIRECT_HP:
		{
			int reg1,reg2;
			LONG offset;

			reg1=w_as_register_parameter (instruction->instruction_parameters[0],size_flag);
			offset=instruction->instruction_parameters[1].parameter_data.i;
			reg2=HEAP_POINTER;

			if (offset!=(WORD)offset){
				w_as_opcode ("addis");
				w_as_register_comma (REGISTER_O0);
				w_as_register_comma (reg2);
				w_as_immediate ((offset-(WORD)offset)>>16);
				w_as_newline();
			
				reg2=REGISTER_O0;
				offset=(WORD)offset;
			}

			w_as_opcode (size_flag==SIZE_LONG ? "stw" :
						 size_flag==SIZE_WORD ? "sth" : "stb");
			w_as_register_comma (reg1);
			w_as_indirect (offset,reg2);
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
				w_as_load_label_parameter (&instruction->instruction_parameters[0],
					instruction->instruction_parameters[1].parameter_data.reg.r);				
				return;
			case P_INDIRECT:
				w_as_opcode ("addi");
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_immediate (instruction->instruction_parameters[0].parameter_offset);
				w_as_newline();
				return;
			case P_INDEXED:
				w_as_opcode ("add");
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_register_comma (instruction->instruction_parameters[0].parameter_data.ir->a_reg.r);
				w_as_register (instruction->instruction_parameters[0].parameter_data.ir->d_reg.r);
				w_as_newline();
				return;				
		}

	internal_error_in_function ("w_as_lea_instruction");
}

static void w_as_or_or_eor_instruction (struct instruction *instruction,char *opcode)
{	
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		long i;

		i=instruction->instruction_parameters[0].parameter_data.i;

		if ((unsigned short) i != i){
			int h;
			
			h=(unsigned)i >> (unsigned)16;
			
			fprintf (assembly_file,"\t%sis\t",opcode);
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_immediate (h);
			w_as_newline();
			
			i=(unsigned short)i;
		}

		fprintf (assembly_file,"\t%si\t",opcode);

		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_immediate (i);
		w_as_newline();

	} else {
		int reg;

		reg=w_as_register_parameter (instruction->instruction_parameters[0],SIZE_LONG);

		w_as_opcode (opcode);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register (reg);
		w_as_newline();
	}
}

static void w_as_tryadic_instruction (struct instruction *instruction,char *opcode)
{
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		fprintf (assembly_file,"\t%si\t",opcode);
	
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_parameter (&instruction->instruction_parameters[0]);
		w_as_newline();
	} else {
		int reg;

		reg=w_as_register_parameter (instruction->instruction_parameters[0],SIZE_LONG);
	
		w_as_opcode (opcode);
		
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_register (reg);
		w_as_newline();
	}
}

static void w_as_i_instruction (struct instruction *instruction,char *opcode)
{
	w_as_opcode (opcode);
	w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
	w_as_immediate (instruction->instruction_parameters[2].parameter_data.i);
	w_as_newline();
}

static void w_as_and_instruction (struct instruction *instruction)
{
	int reg;
	
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		int i,i2;

		i=instruction->instruction_parameters[0].parameter_data.i;

		if (i==(UWORD)i){
			w_as_opcode ("andi.");
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_immediate (i);
			w_as_newline();

			return;
		} else if (((UWORD)i)==0){
			w_as_opcode ("andis.");
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_immediate (((unsigned int)i)>>16);
			w_as_newline();

			return;
		} else if (i2=i | (i-1),(i2 & (i2+1))==0){
			int n_leading_0_bits,n_leading_0_bits_and_1_bits;
			
			n_leading_0_bits = __cntlzw (i);
			n_leading_0_bits_and_1_bits = __cntlzw (i ^ ((unsigned)0xffffffffu>>(unsigned)n_leading_0_bits));
			
			w_as_opcode ("rlwinm");
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_immediate (0);
			w_as_comma();
			w_as_immediate (n_leading_0_bits);
			w_as_comma();
			w_as_immediate (n_leading_0_bits_and_1_bits-1);
			w_as_newline();
			
			return;
		} else {
			w_as_opcode ("lis");
			w_as_register_comma (REGISTER_O0);
			w_as_immediate ((i-(WORD)i)>>16);
			w_as_newline();
				
			i=(WORD)i;
	
			w_as_opcode ("addi");
			w_as_register_comma (REGISTER_O0);
			w_as_register_comma (REGISTER_O0);
			w_as_immediate (i);
			w_as_newline();

			reg=REGISTER_O0;
	
			w_as_opcode ("and");
		}
	} else {
		reg=w_as_register_parameter (instruction->instruction_parameters[0],SIZE_LONG);

		w_as_opcode ("and");
	}
	
	w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_register (reg);
	w_as_newline();
}

static void w_as_add_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			w_as_opcode ("add");
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_register (instruction->instruction_parameters[0].parameter_data.reg.r);
			w_as_newline();
			return;
		case P_IMMEDIATE:
		{
			int i,r;
			
			i=instruction->instruction_parameters[0].parameter_data.i;
			r=instruction->instruction_parameters[1].parameter_data.reg.r;
			
			if (i!=(WORD)i){
				w_as_opcode ("addis");
				w_as_register_comma (r);
				w_as_register_comma (r);
				w_as_immediate ((i-(WORD)i)>>16);
				w_as_newline();
			
				i=(WORD)i;
			}

			w_as_opcode ("addi");
			w_as_register_comma (r);
			w_as_register_comma (r);
			w_as_immediate (i);
			w_as_newline();

			return;
		}
		default:
		{
			int reg;

			reg=w_as_register_parameter (instruction->instruction_parameters[0],SIZE_LONG);
			
			w_as_opcode ("add");
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_register (reg);
			w_as_newline();
		}
	}
}

static void w_as_extb_instruction (struct instruction *instruction)
{
	int reg;
	
	reg=instruction->instruction_parameters[0].parameter_data.reg.r;

	w_as_opcode ("extsb");
	w_as_register_comma (reg);
	w_as_register (reg);
	w_as_newline();
}

static void w_as_addo_instruction (struct instruction *instruction)
{
	int reg;

	reg=w_as_register_parameter (instruction->instruction_parameters[0],SIZE_LONG);
	
	w_as_opcode ("addo.");
	w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_register (reg);
	w_as_newline();
}

static void w_as_sub_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			w_as_opcode ("sub");
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_register (instruction->instruction_parameters[0].parameter_data.reg.r);
			w_as_newline();
			return;
		case P_IMMEDIATE:
		{
			int i,r;
			
			i= -instruction->instruction_parameters[0].parameter_data.i;
			r=instruction->instruction_parameters[1].parameter_data.reg.r;
			
			if (i!=(WORD)i){
				w_as_opcode ("addis");
				w_as_register_comma (r);
				w_as_register_comma (r);
				w_as_immediate ((i-(WORD)i)>>16);
				w_as_newline();
			
				i=(WORD)i;
			}

			w_as_opcode ("addi");
			w_as_register_comma (r);
			w_as_register_comma (r);
			w_as_immediate (i);
			w_as_newline();

			return;
		}
		default:
		{
			int reg;

			reg=w_as_register_parameter (instruction->instruction_parameters[0],SIZE_LONG);
			
			w_as_opcode ("sub");
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_register (reg);
			w_as_newline();
		}
	}
}

static void w_as_subo_instruction (struct instruction *instruction)
{
	int reg;

	reg=w_as_register_parameter (instruction->instruction_parameters[0],SIZE_LONG);
	
	w_as_opcode ("subo.");
	w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_register (reg);
	w_as_newline();
}

static void w_as_cmp_instruction (struct instruction *instruction)
{
	struct parameter parameter_0,parameter_1;

	parameter_0=instruction->instruction_parameters[0];
	parameter_1=instruction->instruction_parameters[1];

	if (parameter_1.parameter_type==P_INDIRECT || parameter_1.parameter_type==P_INDEXED){
		if (parameter_1.parameter_type==P_INDIRECT)
			w_as_opcode ("lwz");
		else
			w_as_opcode ("lwzx");

		w_as_register_comma (REGISTER_O1);
		w_as_parameter (&parameter_1);
		w_as_newline();

		parameter_1.parameter_type=P_REGISTER;
		parameter_1.parameter_data.reg.r=REGISTER_O1;
	}

	switch (parameter_0.parameter_type){
		case P_DESCRIPTOR_NUMBER:
			w_as_load_descriptor (&parameter_0,REGISTER_O0);

			parameter_0.parameter_type=P_REGISTER;
			parameter_0.parameter_data.reg.r=REGISTER_O0;
			break;
		case P_REGISTER:
			break;
		case P_IMMEDIATE:
		{
			int i;
				
			i=parameter_0.parameter_data.i;
			
			if (i!=(WORD)i){
				w_as_opcode ("lis");
				w_as_register_comma (REGISTER_O0);
				w_as_immediate ((i-(WORD)i)>>16);
				w_as_newline();
			
				i=(WORD)i;

				w_as_opcode ("addi");
				w_as_register_comma (REGISTER_O0);
				w_as_register_comma (REGISTER_O0);
				w_as_immediate (i);
				w_as_newline();

				parameter_0.parameter_type=P_REGISTER;
				parameter_0.parameter_data.reg.r=REGISTER_O0;
			}
			break;
		}
		case P_INDIRECT:
			w_as_opcode ("lwz");
			w_as_register_comma (REGISTER_O0);
			w_as_parameter (&parameter_0);
			w_as_newline();

			parameter_0.parameter_type=P_REGISTER;
			parameter_0.parameter_data.reg.r=REGISTER_O0;
			break;
		case P_INDEXED:
			w_as_opcode ("lwzx");
			w_as_register_comma (REGISTER_O0);
			w_as_parameter (&parameter_0);
			w_as_newline();

			parameter_0.parameter_type=P_REGISTER;
			parameter_0.parameter_data.reg.r=REGISTER_O0;
			break;
	}

	w_as_opcode (parameter_0.parameter_type==P_IMMEDIATE ? "cmpwi" : "cmpw");
	w_as_immediate (0);
	w_as_comma();
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

	if (parameter_1.parameter_type==P_INDIRECT || parameter_1.parameter_type==P_INDEXED){
		if (parameter_1.parameter_type==P_INDIRECT)
			w_as_opcode ("lha");
		else
			w_as_opcode ("lhax");

		w_as_register_comma (REGISTER_O1);
		w_as_parameter (&parameter_1);
		w_as_newline();

		parameter_1.parameter_type=P_REGISTER;
		parameter_1.parameter_data.reg.r=REGISTER_O1;
	}

	switch (parameter_0.parameter_type){
		case P_DESCRIPTOR_NUMBER:
			w_as_load_descriptor (&parameter_0,REGISTER_O0);

			parameter_0.parameter_type=P_REGISTER;
			parameter_0.parameter_data.reg.r=REGISTER_O0;
			break;
		case P_REGISTER:
			break;
		case P_IMMEDIATE:
		{
			int i;
				
			i=parameter_0.parameter_data.i;
			
			if (i!=(WORD)i){
				w_as_opcode ("lis");
				w_as_register_comma (REGISTER_O0);
				w_as_immediate ((i-(WORD)i)>>16);
				w_as_newline();
			
				i=(WORD)i;

				w_as_opcode ("addi");
				w_as_register_comma (REGISTER_O0);
				w_as_register_comma (REGISTER_O0);
				w_as_immediate (i);
				w_as_newline();

				parameter_0.parameter_type=P_REGISTER;
				parameter_0.parameter_data.reg.r=REGISTER_O0;
			}
			break;
		}
		case P_INDIRECT:
			w_as_opcode ("lha");
			w_as_register_comma (REGISTER_O0);
			w_as_parameter (&parameter_0);
			w_as_newline();

			parameter_0.parameter_type=P_REGISTER;
			parameter_0.parameter_data.reg.r=REGISTER_O0;
			break;
		case P_INDEXED:
			w_as_opcode ("lhax");
			w_as_register_comma (REGISTER_O0);
			w_as_parameter (&parameter_0);
			w_as_newline();

			parameter_0.parameter_type=P_REGISTER;
			parameter_0.parameter_data.reg.r=REGISTER_O0;
			break;
	}

	w_as_opcode (parameter_0.parameter_type==P_IMMEDIATE ? "cmpwi" : "cmpw");
	w_as_immediate (0);
	w_as_comma();
	w_as_parameter (&parameter_1);
	w_as_comma();
	w_as_parameter (&parameter_0);
	w_as_newline();
}
#endif

static void w_as_cmplw_instruction (struct instruction *instruction)
{
	w_as_opcode ("lwz");
	w_as_register_comma (REGISTER_O0);
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();

	w_as_opcode ("cmplw");
	w_as_immediate (0);
	w_as_comma();
	w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_comma();
	w_as_register (REGISTER_O0);
	w_as_newline();
}

static void w_as_tst_instruction (struct instruction *instruction)
{
	int reg;

	reg=w_as_register_parameter (instruction->instruction_parameters[0],SIZE_LONG);

	w_as_opcode ("cmpwi");
	w_as_immediate (0);
	w_as_comma();
	w_as_register_comma (reg);
	w_as_immediate (0);
	w_as_newline();
}

static void w_as_btst_instruction (struct instruction *instruction)
{
	w_as_opcode ("andi.");
	w_as_register_comma (REGISTER_O0);
	w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_immediate (instruction->instruction_parameters[0].parameter_data.i);
	w_as_newline();
}

void w_as_jmp_instruction (struct instruction *instruction)
{
	struct parameter *parameter0;
	
	parameter0=&instruction->instruction_parameters[0];

	switch (parameter0->parameter_type){
		case P_LABEL:
			w_as_opcode ("b");
			if (parameter0->parameter_data.l->label_number!=0)
				w_as_local_label (parameter0->parameter_data.l->label_number);
			else
				w_as_label (parameter0->parameter_data.l->label_name);

			w_as_newline();
			return;
		case P_INDIRECT:
		{
			int offset,reg;

			offset=parameter0->parameter_offset;
			reg=parameter0->parameter_data.reg.r;

			if (offset!=0){
				w_as_opcode ("la");
				w_as_register_comma (REGISTER_O0);
				w_as_indirect (offset,reg);
				w_as_newline();

				w_as_opcode ("mtctr");
				w_as_register (REGISTER_O0);
				w_as_newline();
			} else {
				w_as_opcode ("mtctr");
				w_as_register (reg);
				w_as_newline();
			}

			w_as_instruction_without_parameters ("bctr");
			return;
		}
		default:
			internal_error_in_function ("w_as_jmp_instruction");
	}
}

static void w_as_jmpp_instruction (struct instruction *instruction)
{
	struct parameter *parameter0;
	
	parameter0=&instruction->instruction_parameters[0];

	switch (parameter0->parameter_type){
		case P_LABEL:
		{
			int offset;

			offset=instruction->instruction_parameters[0].parameter_offset;
			if (offset==0){
				w_as_opcode ("mflr");
				w_as_register (REGISTER_R0);
				w_as_newline();

				w_as_opcode ("bl");
				w_as_label ("profile_t");
				w_as_newline();
			}

			w_as_opcode ("b");
			if (instruction->instruction_parameters[0].parameter_data.l->label_number!=0)
				w_as_local_label (instruction->instruction_parameters[0].parameter_data.l->label_number);
			else
				w_as_label (instruction->instruction_parameters[0].parameter_data.l->label_name);

			if (offset!=0)
				fprintf (assembly_file,"+%d",offset);

			w_as_newline();
			return;
		}
		case P_INDIRECT:
		{
			int offset,reg;

			offset=parameter0->parameter_offset;
			reg=parameter0->parameter_data.reg.r;

			if (offset!=0){
				w_as_opcode ("la");
				w_as_register_comma (REGISTER_O0);
				w_as_indirect (offset,reg);
				w_as_newline();

				w_as_opcode ("mtctr");
				w_as_register (REGISTER_O0);
				w_as_newline();
			} else {
				w_as_opcode ("mtctr");
				w_as_register (reg);
				w_as_newline();
			}

			w_as_opcode ("b");
			w_as_label ("profile_ti");
			w_as_newline();
			return;
		}
		default:
			internal_error_in_function ("w_as_jmpp_instruction");
	}
}

static void w_as_neg_instruction (struct instruction *instruction)
{
	w_as_opcode ("neg");
	w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
	w_as_register_newline (instruction->instruction_parameters[0].parameter_data.reg.r);
}

static void w_as_not_instruction (struct instruction *instruction)
{
	w_as_opcode ("nand");
	w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
	w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
	w_as_register_newline (instruction->instruction_parameters[0].parameter_data.reg.r);
}

struct call_and_jump {
	struct call_and_jump *	cj_next;
	WORD					cj_label_id;
	WORD					cj_jump_id; /* or -1 for far conditional jump */
	char *					cj_call_label_name;
};

static struct call_and_jump *first_call_and_jump,*last_call_and_jump;

static struct call_and_jump *allocate_new_call_and_jump (void)
{
	struct call_and_jump *new_call_and_jump;

	new_call_and_jump=allocate_memory_from_heap_type (struct call_and_jump);

	new_call_and_jump->cj_next=NULL;

	if (first_call_and_jump!=NULL)
		last_call_and_jump->cj_next=new_call_and_jump;
	else
		first_call_and_jump=new_call_and_jump;
	last_call_and_jump=new_call_and_jump;

	return new_call_and_jump;
}

static void w_as_branch_instruction (struct instruction *instruction,char *opcode)
{
	w_as_opcode (opcode);

	if (instruction->instruction_parameters[0].parameter_data.l->label_flags & FAR_CONDITIONAL_JUMP_LABEL){
		struct call_and_jump *new_call_and_jump;
		int label_id;

		label_id=next_label_id++;

		new_call_and_jump=allocate_new_call_and_jump();
					
		new_call_and_jump->cj_call_label_name=instruction->instruction_parameters[0].parameter_data.l->label_name;
		new_call_and_jump->cj_label_id=label_id;
		new_call_and_jump->cj_jump_id=-1;
		
		w_as_internal_label (label_id);
	} else
		w_as_parameter (&instruction->instruction_parameters[0]);

	w_as_newline();
}

static void w_as_index_error_branch_instruction (struct instruction *instruction)
{
	w_as_opcode ("blt+");
	fprintf (assembly_file,".+8");
	w_as_newline();

	w_as_opcode ("b");
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();
}

static void w_as_branchno_instruction (struct instruction *instruction)
{
	w_as_opcode ("bns");
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();

	w_as_opcode ("mcrxr");
	w_as_immediate (0);
	w_as_newline();
	
	w_as_opcode ("bng");
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();
}

static void w_as_brancho_instruction (struct instruction *instruction)
{
	w_as_opcode ("bns");
	fprintf (assembly_file,IF_GNU ("$+12","*+12"));
	w_as_newline();

	w_as_opcode ("mcrxr");
	w_as_immediate (0);
	w_as_newline();
	
	w_as_opcode ("bgt");
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();
}

#ifdef MACH_O
struct stub {
	char *stub_label_name;
	struct stub *stub_next;
};

static struct stub *first_stub,**next_stub_l;

static void write_stub (char *label_name,int stub_n)
{
	fprintf (assembly_file,".picsymbol_stub" NEWLINE_STRING);
	fprintf (assembly_file,"L_%s$stub:" NEWLINE_STRING,label_name);
	fprintf (assembly_file,"\t.indirect_symbol _%s" NEWLINE_STRING,label_name);
	fprintf (assembly_file,"\tmflr\tr0" NEWLINE_STRING);
	fprintf (assembly_file,"\tbcl\t20,31,L%d$pb" NEWLINE_STRING,stub_n);
	fprintf (assembly_file,"L%d$pb:" NEWLINE_STRING,stub_n);
	fprintf (assembly_file,"\tmflr\tr11" NEWLINE_STRING);
	fprintf (assembly_file,"\taddis\tr11,r11,ha16(L%d$lz-L%d$pb)" NEWLINE_STRING,stub_n,stub_n);
	fprintf (assembly_file,"\tmtlr\tr0" NEWLINE_STRING);
	fprintf (assembly_file,"\tlwz\tr12,lo16(L%d$lz-L%d$pb)(r11)" NEWLINE_STRING,stub_n,stub_n);
	fprintf (assembly_file,"\tmtctr\tr12" NEWLINE_STRING);
	fprintf (assembly_file,"\taddi\tr11,r11,lo16(L%d$lz-L%d$pb )" NEWLINE_STRING,stub_n,stub_n);
	fprintf (assembly_file,"\tbctr" NEWLINE_STRING);
	fprintf (assembly_file,".lazy_symbol_pointer" NEWLINE_STRING);
	fprintf (assembly_file,"L%d$lz:" NEWLINE_STRING,stub_n);
	fprintf (assembly_file,".indirect_symbol _%s" NEWLINE_STRING,label_name);
	fprintf (assembly_file,"\t.long\tdyld_stub_binding_helper" NEWLINE_STRING);
}

static void write_stubs (void)
{
	struct stub *stub;
	int stub_n;
	
	stub_n=1;
	for_l (stub,first_stub,stub_next){
		write_stub (stub->stub_label_name,stub_n);
		++stub_n;
	}
		
}
#endif

static void w_as_jsr_instruction (struct instruction *instruction)
{
	struct parameter *parameter0;

	parameter0=&instruction->instruction_parameters[0];

	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		int frame_size;
		
		frame_size=instruction->instruction_parameters[1].parameter_data.i;

		if (parameter0->parameter_type==P_REGISTER){
#ifdef MACH_O
			w_as_opcode ("mtctr");
			w_as_register (parameter0->parameter_data.reg.r);
			w_as_newline();
#else
			w_as_opcode ("lwz");
			w_as_register_comma (REGISTER_O1);
			w_as_indirect (0,parameter0->parameter_data.reg.r);
			w_as_newline();
			
			w_as_opcode ("stw");
			w_as_register_comma (RTOC);
			w_as_indirect (20-(frame_size+28),B_STACK_POINTER);
			w_as_newline();

			w_as_opcode ("lwz");
			w_as_register_comma (RTOC);
			w_as_indirect (4,parameter0->parameter_data.reg.r);
			w_as_newline();

			w_as_opcode ("mtctr");
			w_as_register (REGISTER_O1);
			w_as_newline();
#endif
		}

		if (!(instruction->instruction_arity & NO_MFLR)){
			w_as_opcode ("mflr");
			w_as_register (REGISTER_R0);
			w_as_newline();
		}

#ifdef ALIGN_C_CALLS
# if 0
		w_as_opcode ("mr");
		w_as_register_comma (REGISTER_O0);
		w_as_register (B_STACK_POINTER);
		w_as_newline();

		w_as_opcode ("ori");
		w_as_register_comma (B_STACK_POINTER);
		w_as_register_comma (B_STACK_POINTER);
		w_as_immediate (28);
		w_as_newline();
# endif
		w_as_opcode ("stw");
		w_as_register_comma (REGISTER_R0);
		w_as_indirect (-28-4,B_STACK_POINTER);
		w_as_newline();

		w_as_opcode ("stwu");
		w_as_register_comma (REGISTER_O0);
		w_as_indirect (-(frame_size+28),B_STACK_POINTER);
		w_as_newline();		
#else
		w_as_opcode ("stw");
		w_as_register_comma (REGISTER_R0);
		w_as_indirect (-4,B_STACK_POINTER);
		w_as_newline();

		w_as_opcode ("stwu");
		w_as_register_comma (B_STACK_POINTER);
		w_as_indirect (-frame_size,B_STACK_POINTER);
		w_as_newline();
#endif
	
		if (parameter0->parameter_type==P_REGISTER){
			w_as_instruction_without_parameters ("bctrl");
#ifdef MACH_O
			w_as_instruction_without_parameters ("nop");
#else
			w_as_opcode ("lwz");
			w_as_register_comma (RTOC);
			w_as_indirect (20,B_STACK_POINTER);
			w_as_newline();
#endif
		} else {
			w_as_opcode ("bl");
			if (parameter0->parameter_data.l->label_number!=0)
				w_as_local_label (parameter0->parameter_data.l->label_number);
			else
#ifdef MACH_O
			{
				char *label_name;
				
				label_name=parameter0->parameter_data.l->label_name;
				if (label_name[0]=='_'){
					int c;
					struct stub *new_stub;

					putc ('L',assembly_file);
					putc ('_',assembly_file);
					++label_name;
					
					if (!(parameter0->parameter_data.l->label_flags & STUB_GENERATED)){
						parameter0->parameter_data.l->label_flags |= STUB_GENERATED;
					
						new_stub=allocate_memory_from_heap (sizeof (struct stub));
						
						new_stub->stub_label_name=label_name;
						*next_stub_l=new_stub;
						next_stub_l=&new_stub->stub_next;
						new_stub->stub_next=NULL;
					}
					
					while (c=*label_name++,c!=0)
						putc (c,assembly_file);
					
					fprintf (assembly_file,"$stub");
				} else
					w_as_label (label_name);

			}
#else
				w_as_label (parameter0->parameter_data.l->label_name);
#endif
			w_as_newline();
			w_as_instruction_without_parameters ("nop");
		}
	
#ifdef ALIGN_C_CALLS
		w_as_opcode ("lwz");
		w_as_register_comma (REGISTER_R0);
		w_as_indirect (frame_size-4,B_STACK_POINTER);
		w_as_newline();

		w_as_opcode ("lwz");
		w_as_register_comma (B_STACK_POINTER);
		w_as_indirect (0,B_STACK_POINTER);
		w_as_newline();
#else
		w_as_opcode ("lwz");
		w_as_register_comma (REGISTER_R0);
		w_as_indirect (frame_size-4,B_STACK_POINTER);
		w_as_newline();

		w_as_opcode ("addi");
		w_as_register_comma (B_STACK_POINTER);
		w_as_register_comma (B_STACK_POINTER);
		w_as_immediate (frame_size);
		w_as_newline();
#endif

		if (!(instruction->instruction_arity & NO_MTLR)){
			w_as_opcode ("mtlr");
			w_as_register (REGISTER_R0);
			w_as_newline();
		}
		return;
	}


	if (parameter0->parameter_type==P_INDIRECT){
		int offset,reg;

		offset=parameter0->parameter_offset;
		reg=parameter0->parameter_data.reg.r;

		if (offset!=0){
			w_as_opcode ("la");
			w_as_register_comma (REGISTER_O0);
			w_as_indirect (offset,reg);
			w_as_newline();

			w_as_opcode ("mtctr");
			w_as_register (REGISTER_O0);
			w_as_newline();
		} else {
			w_as_opcode ("mtctr");
			w_as_register (reg);
			w_as_newline();
		}
	}

	if (!(instruction->instruction_arity & NO_MFLR)){
		w_as_opcode ("mflr");
		w_as_register (REGISTER_R0);
		w_as_newline();
	}

	w_as_opcode (instruction->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE
					? "stwu" : "stw");
	w_as_register_comma (REGISTER_R0);
	w_as_indirect (instruction->instruction_parameters[1].parameter_data.i,B_STACK_POINTER);
	w_as_newline();

	switch (parameter0->parameter_type){
		case P_LABEL:
			w_as_opcode ("bl");
			if (parameter0->parameter_data.l->label_number!=0)
				w_as_local_label (parameter0->parameter_data.l->label_number);
			else
				w_as_label (parameter0->parameter_data.l->label_name);
			break;
		case P_INDIRECT:
			w_as_opcode ("bctrl");
			break;
		default:
			internal_error_in_function ("w_as_jsr_instruction");
	}
	w_as_newline();

	if (!(instruction->instruction_arity & NO_MTLR)){
		w_as_opcode ("mtlr");
		w_as_register (REGISTER_R0);
		w_as_newline();
	}
}

static void w_as_call_and_jump (struct call_and_jump *call_and_jump)
{
	w_as_new_code_module();

	w_as_define_internal_label (call_and_jump->cj_label_id);

	if (call_and_jump->cj_jump_id==-1){
		w_as_opcode ("b");
		w_as_label (call_and_jump->cj_call_label_name);
		w_as_newline();		
	} else {
		w_as_opcode ("mflr");
		w_as_register (REGISTER_R0);
		w_as_newline();

		w_as_opcode ("bl");
		w_as_label (call_and_jump->cj_call_label_name);
		w_as_newline();
		
		w_as_opcode ("b");
		w_as_internal_label (call_and_jump->cj_jump_id);
		w_as_newline();
	}
}

static void w_as_rts_begin (struct instruction *instruction)
{
	LONG b_offset;

	if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
		w_as_opcode ("lwz");
		w_as_register_comma (REGISTER_R0);
		w_as_indirect (instruction->instruction_parameters[0].parameter_offset,instruction->instruction_parameters[0].parameter_data.reg.r);
	} else {
		w_as_opcode ("mr");
		w_as_register_comma (REGISTER_R0);
		w_as_register (instruction->instruction_parameters[0].parameter_data.reg.r);
	}
	w_as_newline();

	b_offset=instruction->instruction_parameters[1].parameter_data.i;
	if (b_offset!=0){
		if (b_offset!=(WORD) b_offset){
			w_as_opcode ("addis");
			w_as_register_comma (B_STACK_POINTER);
			w_as_register_comma (B_STACK_POINTER);
			w_as_immediate ((b_offset-(WORD)b_offset)>>16);
			w_as_newline();
					
			b_offset=(WORD)b_offset;
		}
		
		w_as_opcode ("addi");
		w_as_register_comma (B_STACK_POINTER);
		w_as_register_comma (B_STACK_POINTER);
		w_as_immediate (b_offset);
		w_as_newline();
	}
}

static void w_as_rts_instruction (struct instruction *instruction)
{
	if (instruction->instruction_arity>0)
		w_as_rts_begin (instruction);

	w_as_instruction_without_parameters ("blr");
}

static void w_as_rtsp_instruction (struct instruction *instruction)
{
	w_as_rts_begin (instruction);

	w_as_opcode ("b");
	w_as_label ("profile_r");
	w_as_newline();
}

static void w_as_set_condition_instruction (struct instruction *instruction,char *opcode)
{
	w_as_opcode ("li");
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_comma();
	w_as_immediate (0);
	w_as_newline();

	w_as_opcode (opcode);
	fprintf (assembly_file,IF_GNU ("$+8","*+8"));
	w_as_newline();

	w_as_opcode ("li");
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_comma();
	w_as_immediate (-1);
	w_as_newline();
}

static void w_as_setno_condition_instruction (struct instruction *instruction)
{
	w_as_opcode ("li");
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_comma();
	w_as_immediate (0);
	w_as_newline();

	w_as_opcode ("bns");
	fprintf (assembly_file,IF_GNU ("$+12","*+12"));
	w_as_newline();

	w_as_opcode ("mcrxr");
	w_as_immediate (0);
	w_as_newline();
	
	w_as_opcode ("bgt");
	fprintf (assembly_file,IF_GNU ("$+8","*+8"));
	w_as_newline();

	w_as_opcode ("li");
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_comma();
	w_as_immediate (-1);
	w_as_newline();
}

static void w_as_seto_condition_instruction (struct instruction *instruction)
{
	w_as_opcode ("li");
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_comma();
	w_as_immediate (0);
	w_as_newline();

	w_as_opcode ("bns");
	fprintf (assembly_file,IF_GNU ("$+16","*+16"));
	w_as_newline();

	w_as_opcode ("mcrxr");
	w_as_immediate (0);
	w_as_newline();
	
	w_as_opcode ("bng");
	fprintf (assembly_file,IF_GNU ("$+8","*+8"));
	w_as_newline();

	w_as_opcode ("li");
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_comma();
	w_as_immediate (-1);
	w_as_newline();
}

static void w_as_divi (int i,int s_reg,int d_reg)
{
	struct ms ms;

	ms=magic (abs (i));
	
	w_as_opcode ("lis");
	w_as_register_comma (REGISTER_O0);
	w_as_immediate ((ms.m-(WORD)ms.m)>>16);
	w_as_newline();

	w_as_opcode ("addi");
	w_as_register_comma (REGISTER_O0);
	w_as_register_comma (REGISTER_O0);
	w_as_immediate ((WORD)ms.m);
	w_as_newline();

	w_as_opcode ("mulhw");
	w_as_register_comma (REGISTER_O0);
	w_as_register_comma (REGISTER_O0);
	w_as_register_newline (s_reg);

	if (ms.m<0){
		w_as_opcode ("add");
		w_as_register_comma (REGISTER_O0);
		w_as_register_comma (REGISTER_O0);
		w_as_register_newline (s_reg);
	}

	w_as_opcode (i>=0 ? "srwi" : "srawi");
	w_as_register_comma (d_reg);
	w_as_register_comma (s_reg);
	w_as_immediate (31);
	w_as_newline();

	if (ms.s>0){
		w_as_opcode ("srawi");
		w_as_register_comma (REGISTER_O0);
		w_as_register_comma (REGISTER_O0);
		w_as_immediate (ms.s);
		w_as_newline();
	}
				
	w_as_opcode (i>=0 ? "add" : "sub");
	w_as_register_comma (d_reg);
	w_as_register_comma (d_reg);
	w_as_register_newline (REGISTER_O0);
}

static void w_as_rem_instruction (struct instruction *instruction)
{
	int reg;
	
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		int i,sd_reg;
				
		i=instruction->instruction_parameters[0].parameter_data.i;

		if (i<0 && i!=0x80000000)
			i=-i;

		if ((i & (i-1))==0 && i>1){
			int log2i;
						
			log2i=0;
			while (i>1){
				i=i>>1;
				++log2i;
			}
			
			sd_reg=instruction->instruction_parameters[1].parameter_data.reg.r;
			
			w_as_opcode ("srawi");
			w_as_register_comma (REGISTER_O1);
			w_as_register_comma (sd_reg);
			w_as_immediate (31);
			w_as_newline();

			if (log2i==1){
				w_as_opcode ("andi.");
				w_as_register_comma (sd_reg);
				w_as_register_comma (sd_reg);
				w_as_immediate (1);
				w_as_newline();

				w_as_opcode ("xor");
				w_as_register_comma (sd_reg);
				w_as_register_comma (sd_reg);
				w_as_register_newline (REGISTER_O1);				
			} else {
				w_as_opcode ("rlwinm");
				w_as_register_comma (REGISTER_O1);
				w_as_register_comma (REGISTER_O1);
				w_as_immediate (0);
				w_as_comma();
				w_as_immediate (32-log2i);
				w_as_comma();
				w_as_immediate (31);
				w_as_newline();

				w_as_opcode ("add");
				w_as_register_comma (sd_reg);
				w_as_register_comma (sd_reg);
				w_as_register_newline (REGISTER_O1);								
				
				w_as_opcode ("rlwinm");
				w_as_register_comma (sd_reg);
				w_as_register_comma (sd_reg);
				w_as_immediate (0);
				w_as_comma();
				w_as_immediate (32-log2i);
				w_as_comma();
				w_as_immediate (31);
				w_as_newline();
			}
			
			w_as_opcode ("sub");
			w_as_register_comma (sd_reg);
			w_as_register_comma (sd_reg);
			w_as_register_newline (REGISTER_O1);
			
			return;
		} else if (i>1 || (i<-1 && i!=0x80000000)){
			int i2;
			
			sd_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

			w_as_divi (i,sd_reg,REGISTER_O1);

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
						w_as_opcode ("slwi");
						w_as_register_comma (REGISTER_O1);
						w_as_register_comma (REGISTER_O1);
						w_as_immediate (n_shifts);
						w_as_newline();
					}
					
					w_as_opcode ("sub");
					w_as_register_comma (sd_reg);
					w_as_register_comma (sd_reg);
					w_as_register_newline (REGISTER_O1);

					n>>=1;
					n_shifts=1;
				}
			} else {
				if (i!=(WORD)i){
					w_as_opcode ("lis");
					w_as_register_comma (REGISTER_O0);
					w_as_immediate ((i-(WORD)i)>>16);
					w_as_newline();
				
					i=(WORD)i;

					w_as_opcode ("addi");
					w_as_register_comma (REGISTER_O0);
					w_as_register_comma (REGISTER_O0);
					w_as_immediate (i);
					w_as_newline();

					w_as_opcode ("mullw");
					w_as_register_comma (REGISTER_O1);
					w_as_register_comma (REGISTER_O1);
					w_as_register_newline (REGISTER_O0);
				} else {
					w_as_opcode ("mulli");
					w_as_register_comma (REGISTER_O1);
					w_as_register_comma (REGISTER_O1);
					w_as_immediate (i);
					w_as_newline();
				}		

				w_as_opcode ("sub");
				w_as_register_comma (sd_reg);
				w_as_register_comma (sd_reg);
				w_as_register_newline (REGISTER_O1);
			}
			
			return;
		}
	}

	reg=w_as_register_parameter (instruction->instruction_parameters[0],SIZE_LONG);

	w_as_opcode ("divw");
	w_as_register_comma (REGISTER_O1);
	w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_register_newline (reg);

	w_as_opcode ("mullw");
	w_as_register_comma (REGISTER_O1);
	w_as_register_comma (REGISTER_O1);
	w_as_register_newline (reg);

	w_as_opcode ("sub");
	w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_register_newline (REGISTER_O1);
}

static void w_as_div_instruction (struct instruction *instruction)
{
	int reg;

	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		int i,sd_reg;
				
		i=instruction->instruction_parameters[0].parameter_data.i;
		if ((i & (i-1))==0 && i>0){
			int log2i;
			
			if (i==1)
				return;
			
			log2i=0;
			while (i>1){
				i=i>>1;
				++log2i;
			}
			
			sd_reg=instruction->instruction_parameters[1].parameter_data.reg.r;
			
			w_as_opcode ("srawi");
			w_as_register_comma (sd_reg);
			w_as_register_comma (sd_reg);
			w_as_immediate (log2i);
			w_as_newline();
			
			w_as_opcode ("addze");
			w_as_register_comma (sd_reg);
			w_as_register_newline (sd_reg);
			
			return;
		} else if (i>1 || (i<-1 && i!=0x80000000)){
			sd_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

			w_as_divi (i,sd_reg,sd_reg);

			return;
		}
	}
			
	reg=w_as_register_parameter (instruction->instruction_parameters[0],SIZE_LONG);
	
	w_as_opcode ("divw");
	
	w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_register_newline (reg);
}

static void w_as_divu_instruction (struct instruction *instruction)
{
	int reg;

	reg=w_as_register_parameter (instruction->instruction_parameters[0],SIZE_LONG);
	
	w_as_opcode ("divwu");
	
	w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
	w_as_register_newline (reg);
}

static void w_as_mul_instruction (struct instruction *instruction)
{
	int r,reg;
	
	r=instruction->instruction_parameters[1].parameter_data.reg.r;
	
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_IMMEDIATE:
		{
			int i;
			
			i=instruction->instruction_parameters[0].parameter_data.i;
			
			if (i!=(WORD)i){
				w_as_opcode ("lis");
				w_as_register_comma (REGISTER_O0);
				w_as_immediate ((i-(WORD)i)>>16);
				w_as_newline();
			
				i=(WORD)i;

				w_as_opcode ("addi");
				w_as_register_comma (REGISTER_O0);
				w_as_register_comma (REGISTER_O0);
				w_as_immediate (i);
				w_as_newline();
			} else {
				w_as_opcode ("mulli");
				w_as_register_comma (r);
				w_as_register_comma (r);
				w_as_immediate (i);
				w_as_newline();
				
				return;
			}		
			
			reg=REGISTER_O0;
			break;
		}
		default:
			reg=w_as_register_parameter (instruction->instruction_parameters[0],SIZE_LONG);
	}
	
	w_as_opcode ("mullw");
	
	w_as_register_comma (r);
	w_as_register_comma (r);
	w_as_register (reg);
	w_as_newline();
}

static void w_as_umulh_instruction (struct instruction *instruction)
{
	int r,reg;
	
	r=instruction->instruction_parameters[1].parameter_data.reg.r;
	
	reg=w_as_register_parameter (instruction->instruction_parameters[0],SIZE_LONG);
	
	w_as_opcode ("mulhwu");	
	w_as_register_comma (r);
	w_as_register_comma (r);
	w_as_register (reg);
	w_as_newline();
}

static void w_as_mulo_instruction (struct instruction *instruction)
{
	int r,reg;
		
	reg=w_as_register_parameter (instruction->instruction_parameters[0],SIZE_LONG);

	r=instruction->instruction_parameters[1].parameter_data.reg.r;
	
	w_as_opcode ("mullwo.");
	
	w_as_register_comma (r);
	w_as_register_comma (r);
	w_as_register (reg);
	w_as_newline();
}

static int next_bmove_label;

static void w_as_word_instruction (struct instruction *instruction)
{
	fprintf (assembly_file,"\t" DC_L "\t%d" NEWLINE_STRING,
			(int)instruction->instruction_parameters[0].parameter_data.i);
}

static void w_as_load_float_immediate (double float_value,int fp_reg)
{
	int label_number,t_label_number;
	struct label *new_label;

	new_label=(struct label*)allocate_memory_from_heap (sizeof (struct label));

	label_number=next_label_id++;

	w_as_to_data_section();
#ifdef GNU_SYNTAX
	fprintf (assembly_file,"\t.align\t8" NEWLINE_STRING);
#else
	fprintf (assembly_file,"\talign\t3" NEWLINE_STRING);
#endif
	new_label->label_flags=0;	
	new_label->label_number=label_number;

	/* w_as_define_internal_label (label_number); */

	w_as_define_local_label (label_number);
#ifdef GNU_SYNTAX
	w_as_opcode (".double");
	fprintf (assembly_file,"0d%.20e",float_value);
#else
	w_as_opcode ("dc.d");
	fprintf (assembly_file,"\"%.20e\"",float_value);
#endif
	w_as_newline();

/*
	w_as_instruction_without_parameters ("toc");

	w_as_opcode ("tc");
	fprintf (assembly_file,"t_%d{TC}",t_label_number);
	w_as_comma();
	w_as_internal_label (label_number);
	w_as_newline();
*/

#ifndef GNU_SYNTAX
	t_label_number=make_toc_label (new_label,0);
#endif
	w_as_to_code_section();

	w_as_opcode (IF_GNU ("lis","lwz"));
	w_as_scratch_register();
	w_as_comma();
#ifdef GNU_SYNTAX
# ifdef MACH_O
	fprintf (assembly_file,"ha16(");
# endif
	w_as_local_label (label_number);
# ifdef MACH_O
	fprintf (assembly_file,")" NEWLINE_STRING);
# else
	fprintf (assembly_file,"@ha" NEWLINE_STRING);
# endif
#else
	fprintf (assembly_file,"t_%d{TC}(RTOC)" NEWLINE_STRING,t_label_number);
#endif

	w_as_opcode ("lfd");
	w_as_fp_register_comma (fp_reg);
#ifdef GNU_SYNTAX
# ifdef MACH_O
	fprintf (assembly_file,"lo16(");
# endif
	w_as_local_label (label_number);
# ifdef MACH_O
	fprintf (assembly_file,")(");
# else
	fprintf (assembly_file,"@l(");
# endif
	w_as_scratch_register();
	fprintf (assembly_file,")" NEWLINE_STRING);
#else
	w_as_indirect (0,REGISTER_O0);
	w_as_newline();
#endif
	/*++t_label_number; */
}

static struct parameter w_as_float_parameter (struct parameter parameter)
{
	switch (parameter.parameter_type){
		case P_F_IMMEDIATE:
			w_as_load_float_immediate (*parameter.parameter_data.r,17);

			parameter.parameter_type=P_F_REGISTER;
			parameter.parameter_data.reg.r=17;
			break;
		case P_INDIRECT:
			w_as_opcode ("lfd");
			w_as_fp_register_comma (17);
			w_as_indirect (parameter.parameter_offset,parameter.parameter_data.reg.r);
			w_as_newline();

			parameter.parameter_type=P_F_REGISTER;
			parameter.parameter_data.reg.r=17;
			break;
		case P_INDEXED:
			w_as_opcode ("lfdx");
			w_as_fp_register_comma (17);
			w_as_indexed (parameter.parameter_offset,parameter.parameter_data.ir);
			w_as_newline();

			parameter.parameter_type=P_F_REGISTER;
			parameter.parameter_data.reg.r=17;
			break;		
	}
	return parameter;
}

static void w_as_compare_float_instruction (struct instruction *instruction)
{
	struct parameter parameter_0;

	parameter_0=w_as_float_parameter (instruction->instruction_parameters[0]);

	w_as_opcode ("fcmpu");
	
	w_as_immediate (0);
	w_as_comma();
	w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_comma();
	w_as_parameter (&parameter_0);
	w_as_newline();
}

static void w_as_dyadic_float_instruction (struct instruction *instruction,char *opcode)
{
	struct parameter parameter_0;

	parameter_0=w_as_float_parameter (instruction->instruction_parameters[0]);

	w_as_opcode (opcode);

	w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_comma();
	w_as_parameter (&parameter_0);
	w_as_newline();
}

static void w_as_tryadic_float_instruction (struct instruction *instruction,char *opcode)
{
	struct parameter parameter_0;

	parameter_0=w_as_float_parameter (instruction->instruction_parameters[0]);

	w_as_opcode (opcode);

	w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_comma();
	w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_comma();
	w_as_parameter (&parameter_0);
	w_as_newline();
}

#ifdef FMADD
#define FP_REG_LAST_USE 4

static struct instruction *w_as_fmul_instruction (struct instruction *instruction)
{
	struct instruction *next_instruction;
	
	next_instruction=instruction->instruction_next;
	if (fmadd_flag && next_instruction!=NULL)
		if (next_instruction->instruction_icode==IFADD){
			if (next_instruction->instruction_parameters[0].parameter_type==P_F_REGISTER &&
				next_instruction->instruction_parameters[0].parameter_data.reg.r!=next_instruction->instruction_parameters[1].parameter_data.reg.r)
			{
				if (next_instruction->instruction_parameters[0].parameter_flags & FP_REG_LAST_USE &&
					next_instruction->instruction_parameters[0].parameter_data.reg.r==instruction->instruction_parameters[1].parameter_data.reg.r)
				{	
					struct parameter parameter_0;

					parameter_0=w_as_float_parameter (instruction->instruction_parameters[0]);
					
					w_as_opcode ("fmadd");

					w_as_fp_register_comma (next_instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_parameter (&parameter_0);
					w_as_comma();
					w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_parameter (&next_instruction->instruction_parameters[1]);
					w_as_newline();
					
					return next_instruction;
				} else if (next_instruction->instruction_parameters[1].parameter_data.reg.r==instruction->instruction_parameters[1].parameter_data.reg.r){	
					struct parameter parameter_0;

					parameter_0=w_as_float_parameter (instruction->instruction_parameters[0]);
					
					w_as_opcode ("fmadd");

					w_as_fp_register_comma (next_instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_parameter (&parameter_0);
					w_as_comma();
					w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_parameter (&next_instruction->instruction_parameters[0]);
					w_as_newline();
					
					return next_instruction;
				}
			} else if (next_instruction->instruction_parameters[1].parameter_data.reg.r==instruction->instruction_parameters[1].parameter_data.reg.r){
				if (next_instruction->instruction_parameters[0].parameter_type==P_F_IMMEDIATE){
					struct parameter parameter_0;

					parameter_0=w_as_float_parameter (instruction->instruction_parameters[0]);

					w_as_load_float_immediate (*next_instruction->instruction_parameters[0].parameter_data.r,16);

					w_as_opcode ("fmadd");

					w_as_fp_register_comma (next_instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_parameter (&parameter_0);
					w_as_comma();
					w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_fp_register (16);
					w_as_newline();
					
					return next_instruction;
				} else if (	next_instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					struct parameter parameter_0;

					parameter_0=w_as_float_parameter (instruction->instruction_parameters[0]);

					w_as_opcode ("lfd");
					w_as_fp_register_comma (16);
					w_as_indirect (next_instruction->instruction_parameters[0].parameter_offset,next_instruction->instruction_parameters[0].parameter_data.reg.r);
					w_as_newline();

					w_as_opcode ("fmadd");

					w_as_fp_register_comma (next_instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_parameter (&parameter_0);
					w_as_comma();
					w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_fp_register (16);
					w_as_newline();
					
					return next_instruction;
				}
			}
		} else if (next_instruction->instruction_icode==IFSUB){
			if (next_instruction->instruction_parameters[0].parameter_type==P_F_REGISTER &&
				next_instruction->instruction_parameters[0].parameter_data.reg.r!=next_instruction->instruction_parameters[1].parameter_data.reg.r)
			{
				if (next_instruction->instruction_parameters[0].parameter_flags & FP_REG_LAST_USE &&
					next_instruction->instruction_parameters[0].parameter_data.reg.r==instruction->instruction_parameters[1].parameter_data.reg.r)
				{
					struct parameter parameter_0;

					parameter_0=w_as_float_parameter (instruction->instruction_parameters[0]);
					
					if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
						w_as_opcode ("fmsub");
					else
						w_as_opcode ("fnmsub");

					w_as_parameter (&next_instruction->instruction_parameters[1]);
					w_as_comma();
					w_as_parameter (&parameter_0);
					w_as_comma();
					w_as_parameter (&instruction->instruction_parameters[1]);
					w_as_comma();
					w_as_parameter (&next_instruction->instruction_parameters[1]);
					w_as_newline();
					
					return next_instruction;					
				} else if (next_instruction->instruction_parameters[1].parameter_data.reg.r==instruction->instruction_parameters[1].parameter_data.reg.r){
					struct parameter parameter_0;

					parameter_0=w_as_float_parameter (instruction->instruction_parameters[0]);
					
					if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
						w_as_opcode ("fnmsub");
					else
						w_as_opcode ("fmsub");

					w_as_parameter (&next_instruction->instruction_parameters[1]);
					w_as_comma();
					w_as_parameter (&parameter_0);
					w_as_comma();
					w_as_parameter (&instruction->instruction_parameters[1]);
					w_as_comma();
					w_as_parameter (&next_instruction->instruction_parameters[0]);
					w_as_newline();
					
					return next_instruction;
				}
			} else if (next_instruction->instruction_parameters[1].parameter_data.reg.r==instruction->instruction_parameters[1].parameter_data.reg.r){
				if (next_instruction->instruction_parameters[0].parameter_type==P_F_IMMEDIATE){
					struct parameter parameter_0;

					parameter_0=w_as_float_parameter (instruction->instruction_parameters[0]);

					w_as_load_float_immediate (*next_instruction->instruction_parameters[0].parameter_data.r,16);

					if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
						w_as_opcode ("fnmsub");
					else
						w_as_opcode ("fmsub");

					w_as_fp_register_comma (next_instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_parameter (&parameter_0);
					w_as_comma();
					w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_fp_register (16);
					w_as_newline();
					
					return next_instruction;
				} else if (next_instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					struct parameter parameter_0;

					parameter_0=w_as_float_parameter (instruction->instruction_parameters[0]);

					w_as_opcode ("lfd");
					w_as_fp_register_comma (16);
					w_as_indirect (next_instruction->instruction_parameters[0].parameter_offset,next_instruction->instruction_parameters[0].parameter_data.reg.r);
					w_as_newline();

					if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
						w_as_opcode ("fnmsub");
					else
						w_as_opcode ("fmsub");

					w_as_fp_register_comma (next_instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_parameter (&parameter_0);
					w_as_comma();
					w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_fp_register (16);
					w_as_newline();
					
					return next_instruction;
				}
			}
		}

	w_as_tryadic_float_instruction (instruction,"fmul");

	return instruction;
}
#endif

static void w_as_tryadic_reversed_float_instruction (struct instruction *instruction,char *opcode)
{
	struct parameter parameter_0;

	parameter_0=w_as_float_parameter (instruction->instruction_parameters[0]);

	w_as_opcode (opcode);

	w_as_parameter (&instruction->instruction_parameters[1]);
	w_as_comma();
	w_as_parameter (&parameter_0);
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
									struct parameter parameter_0;
									int reg_s;

									parameter_0=w_as_float_parameter (next_instruction->instruction_parameters[0]);

									reg_s=parameter_0.parameter_data.reg.r;
									if (reg_s==reg1)
										reg_s=reg0;
									
									switch (next_instruction->instruction_icode){
										case IFADD:
											w_as_opcode ("fadd");
											break;
										case IFSUB:
											if (instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS){
												int reg0_copy;
												
												reg0_copy=reg0;
												reg0=reg_s;
												reg_s=reg0_copy;
											}

											w_as_opcode ("fsub");
											break;
										case IFMUL:
#ifdef FMADD
										{
											struct instruction *next_of_next_instruction;
											
											next_of_next_instruction=next_instruction->instruction_next;
											if (fmadd_flag && next_of_next_instruction!=NULL){
												if (next_of_next_instruction->instruction_icode==IFADD){
													if (next_of_next_instruction->instruction_parameters[0].parameter_type==P_F_REGISTER &&
														next_of_next_instruction->instruction_parameters[0].parameter_data.reg.r==reg1 &&
														next_of_next_instruction->instruction_parameters[0].parameter_flags & FP_REG_LAST_USE &&
														next_of_next_instruction->instruction_parameters[1].parameter_data.reg.r!=reg1)
													{
														w_as_opcode ("fmadd");

														w_as_parameter (&next_of_next_instruction->instruction_parameters[1]);
														w_as_comma();
														w_as_fp_register_comma (reg0);
														w_as_fp_register_comma (reg_s);
														w_as_parameter (&next_of_next_instruction->instruction_parameters[1]);
														w_as_newline();
														
														return next_of_next_instruction;
													} else if (next_of_next_instruction->instruction_parameters[1].parameter_data.reg.r==reg1){
														if (next_of_next_instruction->instruction_parameters[0].parameter_type==P_F_IMMEDIATE){
															w_as_load_float_immediate (*next_of_next_instruction->instruction_parameters[0].parameter_data.r,16);
															
															w_as_opcode ("fmadd");

															w_as_fp_register_comma (reg1);
															w_as_fp_register_comma (reg0);
															w_as_fp_register_comma (reg_s);
															w_as_fp_register (16);
															w_as_newline();
															
															return next_of_next_instruction;
														} else if (	next_of_next_instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
															w_as_opcode ("lfd");
															w_as_fp_register_comma (16);
															w_as_indirect (next_of_next_instruction->instruction_parameters[0].parameter_offset,next_of_next_instruction->instruction_parameters[0].parameter_data.reg.r);
															w_as_newline();
															
															w_as_opcode ("fmadd");

															w_as_fp_register_comma (reg1);
															w_as_fp_register_comma (reg0);
															w_as_fp_register_comma (reg_s);
															w_as_fp_register (16);
															w_as_newline();
															
															return next_of_next_instruction;
														}
													}
												} else if (next_of_next_instruction->instruction_icode==IFSUB &&
													next_of_next_instruction->instruction_parameters[0].parameter_type==P_F_REGISTER &&
													next_of_next_instruction->instruction_parameters[0].parameter_data.reg.r!=next_of_next_instruction->instruction_parameters[1].parameter_data.reg.r)
												{
													if (next_of_next_instruction->instruction_parameters[0].parameter_flags & FP_REG_LAST_USE &&
														next_of_next_instruction->instruction_parameters[0].parameter_data.reg.r==reg1)
													{
														if (next_of_next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
															w_as_opcode ("fmsub");
														else
															w_as_opcode ("fnmsub");

														w_as_parameter (&next_of_next_instruction->instruction_parameters[1]);
														w_as_comma();
														w_as_fp_register_comma (reg0);
														w_as_fp_register_comma (reg_s);
														w_as_parameter (&next_of_next_instruction->instruction_parameters[1]);
														w_as_newline();
														
														return next_of_next_instruction;					
													} else if (next_of_next_instruction->instruction_parameters[1].parameter_data.reg.r==reg1){
														if (next_of_next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
															w_as_opcode ("fnmsub");
														else
															w_as_opcode ("fmsub");

														w_as_parameter (&next_of_next_instruction->instruction_parameters[1]);
														w_as_comma();
														w_as_fp_register_comma (reg0);
														w_as_fp_register_comma (reg_s);
														w_as_parameter (&next_of_next_instruction->instruction_parameters[0]);
														w_as_newline();
														
														return next_of_next_instruction;
													}
												}
											}
										}
#endif
											w_as_opcode ("fmul");
											break;
										case IFDIV:
											if (instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS){
												int reg0_copy;
												
												reg0_copy=reg0;
												reg0=reg_s;
												reg_s=reg0_copy;
											}
											w_as_opcode ("fdiv");
											break;
										case IFREM:
											w_as_opcode ("frem");
									}
									w_as_fp_register_comma (reg1);
									w_as_fp_register_comma (reg0);
									w_as_fp_register (reg_s);
									w_as_newline();
									
									return next_instruction;
								}
						}

					w_as_opcode ("fmr");
					w_as_fp_register_comma (reg1);
					w_as_fp_register (reg0);
					w_as_newline();
				
					return instruction;
				}
				case P_INDIRECT:
					w_as_opcode ("lfd");
					w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_indirect (instruction->instruction_parameters[0].parameter_offset,
								   instruction->instruction_parameters[0].parameter_data.reg.r);
					w_as_newline();

					return instruction;
				case P_F_IMMEDIATE:
					w_as_load_float_immediate (*instruction->instruction_parameters[0].parameter_data.r,instruction->instruction_parameters[1].parameter_data.reg.r);

					return instruction;
				case P_INDEXED:
					w_as_opcode ("lfdx");
					w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_indexed (instruction->instruction_parameters[0].parameter_offset,
								  instruction->instruction_parameters[0].parameter_data.ir);
					w_as_newline();

					return instruction;
			}
			break;
		case P_INDIRECT:
			if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
				w_as_opcode ("stfd");
				w_as_fp_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_indirect (instruction->instruction_parameters[1].parameter_offset,
							   instruction->instruction_parameters[1].parameter_data.reg.r);
				w_as_newline();

				return instruction;
			}
			break;
		case P_INDEXED:
			if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
				w_as_opcode ("stfdx");
				w_as_fp_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_indexed (instruction->instruction_parameters[1].parameter_offset,
							  instruction->instruction_parameters[1].parameter_data.ir);
				w_as_newline();

				return instruction;
			}
			break;

	}
	internal_error_in_function ("w_as_fmove_instruction");
	return instruction;
}

extern LABEL *r_to_i_buffer_label;

static void w_as_fmovel_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
		if (instruction->instruction_parameters[1].parameter_type!=P_REGISTER)
			internal_error_in_function ("w_as_fmovel_instruction");

		w_as_opcode ("fctiw");
		w_as_fp_register_comma (17);
		w_as_fp_register (instruction->instruction_parameters[0].parameter_data.reg.r);
		w_as_newline();

		w_as_load_label (r_to_i_buffer_label,REGISTER_O0);

		w_as_opcode ("stfd");
		w_as_fp_register_comma (17);
		w_as_indirect (0,REGISTER_O0);
		w_as_newline();

		w_as_opcode ("lwz");
		w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_indirect (4,REGISTER_O0);
		w_as_newline();
	} else {
		int reg;
		int label_number,t_label_number;
		struct label *new_label;

		switch (instruction->instruction_parameters[0].parameter_type){
			case P_REGISTER:
				reg=instruction->instruction_parameters[0].parameter_data.reg.r;
				break;
			case P_INDIRECT:
				w_as_opcode ("lwz");
				w_as_register_comma (REGISTER_O0);
				w_as_indirect (	instruction->instruction_parameters[0].parameter_offset,
								instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_newline();
	
				reg=REGISTER_O0;
				break;
			case P_IMMEDIATE:
				w_as_opcode ("li");
				w_as_register_comma (REGISTER_O0);
				w_as_immediate (instruction->instruction_parameters[0].parameter_data.i);
				w_as_newline();

				reg=REGISTER_O0;
				break;
			default:
				internal_error_in_function ("w_as_fmovel_instruction");
		}
		
		label_number=next_label_id++;

		new_label=(struct label*)allocate_memory_from_heap (sizeof (struct label));

		new_label->label_flags=0;	
		new_label->label_number=label_number;
	
		w_as_to_data_section();

#ifdef GNU_SYNTAX
		fprintf (assembly_file,"\t.align\t8" NEWLINE_STRING);
#else
		fprintf (assembly_file,"\talign\t3" NEWLINE_STRING);
#endif	
/*		w_as_define_internal_label (label_number); */
		w_as_define_local_label (label_number);
	
		fprintf (assembly_file,
			"\t" DC_L "\t0x43300000" NEWLINE_STRING
			"\t" DC_L "\t0x00000000" NEWLINE_STRING
			"\t" DC_L "\t0x43300000" NEWLINE_STRING
			"\t" DC_L "\t0x80000000" NEWLINE_STRING
		);
	
/*
		w_as_instruction_without_parameters ("toc");

		w_as_opcode ("tc");
		fprintf (assembly_file,"t_%d{TC}",t_label_number);
		w_as_comma();
		w_as_internal_label (label_number);
		w_as_newline();
*/
#ifndef GNU_SYNTAX
		t_label_number=make_toc_label (new_label,0);
#endif
		w_as_to_code_section();

		/*
		lwz		o1,t_n{TC}(RTOC)
		xoris	o0,reg,0x8000
		lfd		fp31,8(o1)
		stw		o0,4(o1)
		lfd		freg,0(o1)
		fsub	freg,freg,fp31
		*/
#ifdef GNU_SYNTAX
		load_label (new_label,0,REGISTER_O1);
#else
		w_as_opcode ("lwz");
		w_as_register_comma (REGISTER_O1);
		fprintf (assembly_file,"t_%d{TC}(RTOC)" NEWLINE_STRING,t_label_number);
#endif
		w_as_opcode ("xoris");
		w_as_register_comma (REGISTER_O0);
		w_as_register_comma (reg);
		w_as_immediate (0x8000);
		w_as_newline();
		
		w_as_opcode ("lfd");
		w_as_fp_register_comma (17);
		w_as_indirect (8,REGISTER_O1);
		w_as_newline();

		w_as_opcode ("stw");
		w_as_register_comma (REGISTER_O0);
		w_as_indirect (4,REGISTER_O1);
		w_as_newline();

		w_as_opcode ("lfd");
		w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_indirect (0,REGISTER_O1);
		w_as_newline();

		w_as_opcode ("fsub");
		w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_fp_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_fp_register (17);
		w_as_newline();
		
/*		++t_label_number; */
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
				w_as_i_instruction (instruction,"addi");
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
				w_as_branch_instruction (instruction,"beq");
				break;
			case IBGE:
				w_as_branch_instruction (instruction,"bge");
				break;
			case IBGT:
				w_as_branch_instruction (instruction,"bgt");
				break;
			case IBLE:
				w_as_branch_instruction (instruction,"ble");
				break;
			case IBLT:
				w_as_branch_instruction (instruction,"blt");
				break;
			case IBNE:
				w_as_branch_instruction (instruction,"bne");
				break;
			case IBNEP:
				w_as_branch_instruction (instruction,"bne+");
				break;
			case IBHS:
				w_as_index_error_branch_instruction (instruction);
				break;
			case IBNO:
				w_as_branchno_instruction (instruction);
				break;
			case IBO:
				w_as_brancho_instruction (instruction);
				break;
			case ICMPLW:
				w_as_cmplw_instruction (instruction);
				break;
			case ILSLI:
				w_as_i_instruction (instruction,"slwi");
				break;
			case ILSL:
				w_as_tryadic_instruction (instruction,"slw");
				break;
			case ILSR:
				w_as_tryadic_instruction (instruction,"srw");
				break;
			case IASR:
				w_as_tryadic_instruction (instruction,"sraw");
				break;
			case IMUL:
				w_as_mul_instruction (instruction);
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
				w_as_and_instruction (instruction);
				break;
			case IOR:
				w_as_or_or_eor_instruction (instruction,"or");
				break;
			case IEOR:
				w_as_or_or_eor_instruction (instruction,"xor");
				break;
			case ISEQ:
				w_as_set_condition_instruction (instruction,"bne");
				break;
			case ISGE:
				w_as_set_condition_instruction (instruction,"blt");
				break;
			case ISGT:
				w_as_set_condition_instruction (instruction,"ble");
				break;
			case ISLE:
				w_as_set_condition_instruction (instruction,"bgt");
				break;
			case ISLT:
				w_as_set_condition_instruction (instruction,"bge");
				break;
			case ISNE:
				w_as_set_condition_instruction (instruction,"beq");
				break;
			case ISNO:
				w_as_setno_condition_instruction (instruction);
				break;
			case ISO:
				w_as_seto_condition_instruction (instruction);
				break;
#if 0
			case ICMPW:
				w_as_cmpw_instruction (instruction);
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
			case IEXTB:
				w_as_extb_instruction (instruction);
				break;
			case INEG:
				w_as_neg_instruction (instruction);
				break;
			case INOT:
				w_as_not_instruction (instruction);
				break;
			case IFMOVE:
				instruction=w_as_fmove_instruction (instruction);
				break;
			case IFABS:
				w_as_dyadic_float_instruction (instruction,"fabs");
				break;				
			case IFADD:
				w_as_tryadic_float_instruction (instruction,"fadd");
				break;
			case IFCMP:
				w_as_compare_float_instruction (instruction);
				break;
			case IFDIV:
				if (instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
					w_as_tryadic_reversed_float_instruction (instruction,"fdiv");
				else
					w_as_tryadic_float_instruction (instruction,"fdiv");
				break;
			case IFMUL:
#ifdef FMADD
				instruction=w_as_fmul_instruction (instruction);
#else
				w_as_tryadic_float_instruction (instruction,"fmul");
#endif
				break;
			case IFNEG:
				w_as_dyadic_float_instruction (instruction,"fneg");
				break;				
			case IFREM:
				w_as_tryadic_float_instruction (instruction,"frem");
				break;
			case IFSUB:
				if (instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
					w_as_tryadic_reversed_float_instruction (instruction,"fsub");
				else
					w_as_tryadic_float_instruction (instruction,"fsub");
				break;
			case IFBEQ:
				w_as_branch_instruction (instruction,"beq");
				break;
			case IFBGE:
				w_as_branch_instruction (instruction,"bge");
				break;
			case IFBGT:
				w_as_branch_instruction (instruction,"bgt");
				break;
			case IFBLE:
				w_as_branch_instruction (instruction,"ble");
				break;
			case IFBLT:
				w_as_branch_instruction (instruction,"blt");
				break;
			case IFBNE:
				w_as_branch_instruction (instruction,"bne");
				break;
			case IFMOVEL:
				w_as_fmovel_instruction (instruction);
				break;
			case IFSEQ:
				w_as_set_condition_instruction (instruction,"bne");
				break;
			case IFSGE:
				w_as_set_condition_instruction (instruction,"blt");
				break;
			case IFSGT:
				w_as_set_condition_instruction (instruction,"ble");
				break;
			case IFSLE:
				w_as_set_condition_instruction (instruction,"bgt");
				break;
			case IFSLT:
				w_as_set_condition_instruction (instruction,"bge");
				break;
			case IFSNE:
				w_as_set_condition_instruction (instruction,"beq");
				break;
			case IWORD:
				w_as_word_instruction (instruction);
				break;
			case IMTCTR:
				w_as_opcode ("mtctr");
				w_as_register (instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_newline();
				break;
			case IJMPP:
				w_as_jmpp_instruction (instruction);
				break;
			case IRTSP:
				w_as_rtsp_instruction (instruction);
				break;
			case IADDO:
				w_as_addo_instruction (instruction);
				break;
			case ISUBO:
				w_as_subo_instruction (instruction);
				break;
			case IMULO:
				w_as_mulo_instruction (instruction);
				break;
			case IUMULH:
				w_as_umulh_instruction (instruction);
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
	w_as_opcode (DC_L);
	fprintf (assembly_file,"%d",n_node_arguments);
	w_as_newline();
}

static void w_as_garbage_collect_test (register struct basic_block *block)
{
	LONG n_cells;
	struct call_and_jump *new_call_and_jump;

	n_cells= -block->block_n_new_heap_cells;	

	if (n_cells!=(WORD) n_cells){
		w_as_opcode ("addis");
		w_as_register_comma (REGISTER_D7);
		w_as_register_comma (REGISTER_D7);
		w_as_immediate ((n_cells-(WORD)n_cells)>>16);
		w_as_newline();
				
		n_cells=(WORD)n_cells;
	}

	w_as_opcode ("addic.");
	w_as_register_comma (REGISTER_D7);
	w_as_register_comma (REGISTER_D7);
	w_as_immediate (n_cells);
	w_as_newline();

	new_call_and_jump=allocate_new_call_and_jump();

	if (block->block_gc_kind!=0){
		int label_id_1;
				
		label_id_1=next_label_id++;
			
		new_call_and_jump->cj_label_id=label_id_1;
		new_call_and_jump->cj_jump_id=-1;

		switch (block->block_n_begin_a_parameter_registers){
			case 0:		new_call_and_jump->cj_call_label_name="collect_00";	break;
			case 1:		new_call_and_jump->cj_call_label_name="collect_01";	break;
			case 2:		new_call_and_jump->cj_call_label_name="collect_02";	break;
			case 3:		new_call_and_jump->cj_call_label_name="collect_03";	break;
			default:	internal_error_in_function ("w_as_garbage_collect_test");
		}

		if (block->block_gc_kind==2){
			w_as_opcode ("mflr");
			w_as_register (REGISTER_R0);
			w_as_newline();
		}

		w_as_opcode ("bltl-");
		w_as_internal_label (label_id_1);
		w_as_newline();

		if (block->block_gc_kind==1){
			w_as_opcode ("mtlr");
			w_as_register (REGISTER_R0);
			w_as_newline();
		}
	} else {
		int label_id_1,label_id_2;
				
		label_id_1=next_label_id++;
		label_id_2=next_label_id++;
			
		new_call_and_jump->cj_label_id=label_id_1;
		new_call_and_jump->cj_jump_id=label_id_2;
	
		switch (block->block_n_begin_a_parameter_registers){
			case 0:		new_call_and_jump->cj_call_label_name="collect_0";	break;
			case 1:		new_call_and_jump->cj_call_label_name="collect_1";	break;
			case 2:		new_call_and_jump->cj_call_label_name="collect_2";	break;
			case 3:		new_call_and_jump->cj_call_label_name="collect_3";	break;
			default:	internal_error_in_function ("w_as_garbage_collect_test");
		}
				
		w_as_opcode ("blt");
		w_as_internal_label (label_id_1);
		w_as_newline ();
	
		w_as_define_internal_label (label_id_2);
	}
}

static void w_as_check_stack (struct basic_block *block)
{
#ifdef SEPARATE_A_AND_B_STACK_OVERFLOW_CHECKS
	if (block->block_a_stack_check_size>0){		
		w_as_load_label (end_a_stack_label,REGISTER_O0);

		w_as_opcode ("addi");
		w_as_register_comma (REGISTER_O1);
		w_as_register_comma (A_STACK_POINTER);
		w_as_immediate (block->block_a_stack_check_size);
		w_as_newline();
		
		w_as_opcode ("lwz");
		w_as_register_comma (REGISTER_O0);
		w_as_indirect (0,REGISTER_O0);
		w_as_newline();

		w_as_opcode ("cmpw");
		w_as_immediate (0);
		w_as_comma();
		w_as_register_comma (REGISTER_O1);
		w_as_register (REGISTER_O0);
		w_as_newline();

		w_as_opcode ("ble+");
		fprintf (assembly_file,".+8");
		w_as_newline();

		w_as_opcode ("b");
		w_as_label (stack_overflow_label->label_name);
		w_as_newline();
	}
	if (block->block_b_stack_check_size>0){		
		w_as_load_label (end_b_stack_label,REGISTER_O0);

		w_as_opcode ("addi");
		w_as_register_comma (REGISTER_O1);
		w_as_register_comma (B_STACK_POINTER);
		w_as_immediate (block->block_b_stack_check_size);
		w_as_newline();

		w_as_opcode ("lwz");
		w_as_register_comma (REGISTER_O0);
		w_as_indirect (0,REGISTER_O0);
		w_as_newline();

		w_as_opcode ("cmpw");
		w_as_immediate (0);
		w_as_comma();
		w_as_register_comma (REGISTER_O1);
		w_as_register (REGISTER_O0);
		w_as_newline();

		w_as_opcode ("bgt+");
		fprintf (assembly_file,".+8");
		w_as_newline();

		w_as_opcode ("b");
		w_as_label (stack_overflow_label->label_name);
		w_as_newline();
	}
#else
	int size;
	
	size=block->block_stack_check_size+1024;

	w_as_opcode ("sub");
	w_as_register_comma (REGISTER_O0);
	w_as_register_comma (B_STACK_POINTER);
	w_as_register (A_STACK_POINTER);
	w_as_newline();

	w_as_opcode ("cmpwi");
	w_as_register_comma (REGISTER_O0);
	w_as_immediate (size);
	w_as_newline();

	w_as_opcode ("ble");
	w_as_label (stack_overflow_label->label_name);
	w_as_newline();
#endif
}

static void w_as_labels (register struct block_label *labels)
{
	for (; labels!=NULL; labels=labels->block_label_next)
		if (labels->block_label_label->label_number==0){
			LABEL *label;
			
			label=labels->block_label_label;
			
			w_as_define_label (label);
		} else
			w_as_define_local_label (labels->block_label_label->label_number);
}

void initialize_write_assembly (FILE *ass_file)
{
	assembly_file=ass_file;
	
	next_bmove_label=0;
	in_data_section=0;

	first_call_and_jump=NULL;
#ifndef GNU_SYNTAX
	fprintf (assembly_file,"\tstring\tasis" NEWLINE_STRING);
#endif
	data_module_number=0;
	code_module_number=0;
}

static void w_as_import_labels (register struct label_node *label_node)
{
	LABEL *label;
	
	if (label_node==NULL)
		return;
	
	label=&label_node->label_node_label;
	
	if (!(label->label_flags & LOCAL_LABEL) && label->label_number==0){
		w_as_opcode (IF_GNU (IF_MACH_O (".globl",".global"),"import"));
#ifdef MACH_O
		if (label->label_name[0]=='_'){
			char *label_name;
			int c;
				
			label_name=label->label_name;
			putc ('_',assembly_file);
			++label_name;
			while (c=*label_name++,c!=0)
				putc (c,assembly_file);

		} else
			w_as_label (label->label_name);
#else
		w_as_label (label->label_name);
#endif
		w_as_newline();
	}
		
	w_as_import_labels (label_node->label_node_left);
	w_as_import_labels (label_node->label_node_right);
}

static void w_as_node_entry_info (struct basic_block *block)
{
	if (block->block_ea_label!=NULL){
		int n_node_arguments;
		extern LABEL *eval_fill_label,*eval_upd_labels[];
		
		n_node_arguments=block->block_n_node_arguments;

		if (n_node_arguments<-2)
			n_node_arguments=1;
		
		if (n_node_arguments>=0 && block->block_ea_label!=eval_fill_label){
			w_as_load_label (block->block_ea_label,REGISTER_A2);

			if (!block->block_profile){					
				w_as_opcode ("b");
				w_as_label (eval_upd_labels[n_node_arguments]->label_name);
				w_as_newline();

				w_as_instruction_without_parameters ("nop");
#ifdef GNU_SYNTAX
				w_as_instruction_without_parameters ("nop");
#endif
			} else {						
				if (profile_table_flag){
					w_as_opcode ("b");
					w_as_label (eval_upd_labels[n_node_arguments]->label_name);
					fprintf (assembly_file,"-8");
					w_as_newline();

					w_as_load_label_with_offset (profile_table_label,32764,REGISTER_R3);

					w_as_opcode ("addi");
					w_as_register_comma (REGISTER_R3);
					w_as_register_comma (REGISTER_R3);
					w_as_immediate (block->block_profile_function_label->label_arity-32764);
					w_as_newline();
				
					w_as_opcode ("b");
					fprintf (assembly_file,IF_GNU ("$-16","*-16"));
					w_as_newline();
				} else {
					w_as_load_label (block->block_profile_function_label,REGISTER_R3);

					w_as_opcode ("b");
					w_as_label (eval_upd_labels[n_node_arguments]->label_name);
					fprintf (assembly_file,"-8");
					w_as_newline();
				}
			}
		} else {
			w_as_opcode ("b");
			w_as_label (block->block_ea_label->label_name);
			w_as_newline();
			
			w_as_instruction_without_parameters ("nop");
			w_as_instruction_without_parameters ("nop");
#ifdef GNU_SYNTAX
			w_as_instruction_without_parameters ("nop");
			w_as_instruction_without_parameters ("nop");
#endif
		}
		
		if (block->block_descriptor!=NULL && (block->block_n_node_arguments<0 || parallel_flag || module_info_flag))
#ifdef GNU_SYNTAX
			w_as_label_in_code_section (block->block_descriptor->label_name);
#else
			w_as_load_label (block->block_descriptor,REGISTER_R0);
#endif
		else
			w_as_number_of_arguments (0);
	} else {
		if (block->block_descriptor!=NULL && (block->block_n_node_arguments<0 || parallel_flag || module_info_flag))
#ifdef GNU_SYNTAX
			w_as_label_in_code_section (block->block_descriptor->label_name);
#else
			w_as_load_label (block->block_descriptor,REGISTER_R0);
#endif
		/* else
			w_as_number_of_arguments (0);
		*/
	}
	w_as_number_of_arguments (block->block_n_node_arguments);
}

static void w_as_profile_call (struct basic_block *block)
{
	if (profile_table_flag){
		w_as_load_label_with_offset (profile_table_label,32764,REGISTER_R3);
	
		w_as_opcode ("mflr");
		w_as_register (REGISTER_R0);
		w_as_newline();
		
		w_as_opcode ("addi");
		w_as_register_comma (REGISTER_R3);
		w_as_register_comma (REGISTER_R3);
		w_as_immediate (block->block_profile_function_label->label_arity-32764);
		w_as_newline();
	} else {
		w_as_load_label (block->block_profile_function_label,REGISTER_R3);
	
		w_as_opcode ("mflr");
		w_as_register (REGISTER_R0);
		w_as_newline();
	}
	
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
	w_as_newline();
}

#ifdef NEW_APPLY
extern LABEL *add_empty_node_labels[];

static void w_as_apply_update_entry (struct basic_block *block)
{
	if (block->block_profile)
		w_as_profile_call (block);

	if (block->block_n_node_arguments==-200){
		w_as_opcode ("b");
		w_as_label (block->block_ea_label->label_name);
		w_as_newline();

		w_as_instruction_without_parameters ("nop");
		w_as_instruction_without_parameters ("nop");
		w_as_instruction_without_parameters ("nop");
	} else {
		w_as_opcode ("mflr");
		w_as_register (REGISTER_R0);
		w_as_newline();

		w_as_opcode ("bl");
		w_as_label (add_empty_node_labels[block->block_n_node_arguments+200]->label_name);
		w_as_newline();

		w_as_opcode ("mtlr");
		w_as_register (REGISTER_R0);
		w_as_newline();

		w_as_opcode ("b");
		w_as_label (block->block_ea_label->label_name);
		w_as_newline();
	}
}
#endif

void write_assembly (VOID)
{
	struct basic_block *block;
	struct call_and_jump *call_and_jump;
	struct toc_label *toc_label;

#ifdef MACH_O
	first_stub=NULL;
	next_stub_l=&first_stub;
#endif
	
	w_as_to_code_section();
	
	w_as_import_labels (labels);

	for_l (block,first_block,block_next){
		if (block->block_begin_module && !block->block_link_module){
			if (first_call_and_jump!=NULL){
				struct call_and_jump *call_and_jump;
		
				for_l (call_and_jump,first_call_and_jump,cj_next)
					w_as_call_and_jump (call_and_jump);
				
				first_call_and_jump=NULL;
			}

			w_as_new_code_module();
		}

		if (block->block_n_node_arguments>-100){
			w_as_node_entry_info (block);
		}
#ifdef NEW_APPLY
		else if (block->block_n_node_arguments<-100)
			w_as_apply_update_entry (block);
#endif

		w_as_labels (block->block_labels);

		if (block->block_profile)
			w_as_profile_call (block);

		if (block->block_n_new_heap_cells!=0)
			w_as_garbage_collect_test (block);
		
		if (check_stack
#ifdef SEPARATE_A_AND_B_STACK_OVERFLOW_CHECKS
			&& (block->block_a_stack_check_size>0 || block->block_b_stack_check_size>0)
#else
			&& block->block_stack_check_size>0
#endif
			)
			w_as_check_stack (block);
		
		w_as_instructions (block->block_instructions);
	}

	for_l (call_and_jump,first_call_and_jump,cj_next)
		w_as_call_and_jump (call_and_jump);

	*last_toc_next_p=NULL;

#ifndef GNU_SYNTAX
	w_as_instruction_without_parameters ("toc");

	for_l (toc_label,toc_labels,toc_next)
		w_as_toc_label (toc_label);	
#endif

#ifdef MACH_O
	write_stubs();
#endif
}

#endif
