/*
	File:	 cgawas.c
	Author:  John van Groningen
	Machine: opteron athlon64
*/

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#if defined (LINUX) && defined (G_AI64)
# include <stdint.h>
# include <inttypes.h>
#endif

#undef GENERATIONAL_GC
#define LEA_ADDRESS

#include "cgport.h"
#include "cgrconst.h"
#include "cgtypes.h"
#include "cg.h"
#include "cgiconst.h"
#include "cgcode.h"
#include "cginstructions.h"
#include "cgaas.h"

#include "cgiwas.h"

int intel_asm=
#ifdef _WINDOWS_
	1;
#else
	0;
#endif
int intel_directives=
#ifdef _WINDOWS_
     1;
#else
     0;
#endif

extern int sse_128;

#define for_l(v,l,n) for(v=(l);v!=NULL;v=v->n)

#define IO_BUF_SIZE 8192

static FILE *assembly_file;

static void w_as_newline (VOID)
{
	putc ('\n',assembly_file);
}

static void w_as_opcode (char *opcode)
{
#ifdef MACH_O64
	if (!intel_asm)
		fprintf (assembly_file,"\t%s ",opcode);
	else
#endif
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
	fprintf (assembly_file,intel_directives ? "l_%d label ptr\n" : "l_%d:\n",label_number);
}

static void w_as_define_internal_label (int label_number)
{
	fprintf (assembly_file,"i_%d:\n",label_number);
}

static void w_as_define_internal_data_label (int label_number)
{
	fprintf (assembly_file,intel_directives? "i_%d label ptr\n" : "i_%d:\n",label_number);
}

void w_as_internal_label_value (int label_id)
{
	fprintf (assembly_file,intel_directives ? "\tdd\ti_%d\n" : "\t.long\ti_%d\n",label_id);
}

#ifdef MACH_O64
void w_as_internal_label_value_offset (int label_id)
{
	fprintf (assembly_file,"\t.long\ti_%d - .\n",label_id);
}
#endif

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
		w_as_instruction_without_parameters (intel_directives ? ".code" : ".text");
	}
}

static void w_as_align (int i)
{
#if defined (DOS) || defined (_WINDOWS_) || defined (LINUX_ELF)
	fprintf (assembly_file,intel_directives ? "\talign\t%d\n" : "\t.align\t%d\n",1<<i);
#else
	fprintf (assembly_file,intel_directives ? "\talign\t%d\n" : "\t.align\t%d\n",i);
#endif
}

static void w_as_space (int i)
{
	if (intel_directives){
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
	w_as_opcode (intel_directives ? "dw" : ".word");
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
	w_as_opcode (intel_directives ? "dd" : ".long");
	fprintf (assembly_file,"%d",n);
	w_as_newline();
}

static void print_int64 (uint_64 n)
{
	static char digits[32];
	char *p;
/*
	if (n<0){
		fputc ('-',assembly_file);
		n=-n;
	}
*/	
	p=&digits[31];
	*p='\0';
	while (n>9){
		uint_64 m;
		
		m=n/10;
		*--p='0'+(n-10*m);
		n=m;	
	}
	*--p='0'+n;
	
	fputs (p,assembly_file);
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
	w_as_opcode (intel_directives ? "dq" : ".quad");

#ifdef LINUX
	if ((int)n==n)
		fprintf (assembly_file,"%" PRId64,n);
	else
		fprintf (assembly_file,"%" PRIu64,n);
#else
	if ((int)n==n)
		fprintf (assembly_file,"%I64i",n);
	else
		fprintf (assembly_file,"%I64u",n);
#endif	
	w_as_newline();
}

void w_as_label_in_data_section (char *label_name)
{
	w_as_to_data_section ();
#ifdef MACH_O64
	fprintf (assembly_file,"\t.quad\t%s\n",label_name);
#else
	fprintf (assembly_file,intel_directives ? "\tdd\t%s\n" : "\t.long\t%s\n",label_name);
#endif
}

#ifdef MACH_O64
void w_as_label_offset_in_data_section (char *label_name)
{
	w_as_to_data_section ();
	fprintf (assembly_file,"\t.long\t%s - .\n",label_name);
}
#endif

void w_as_label_in_code_section (char *label_name)
{
	w_as_to_code_section ();
#ifdef MACH_O64
	fprintf (assembly_file,"\t.long\t%s - .\n",label_name);
#else
	fprintf (assembly_file,intel_directives ? "\tdd\t%s\n" : "\t.long\t%s\n",label_name);
#endif
}

#ifdef MACH_O64
void w_as_label_minus_label_in_code_section (char *label_name1,char *label_name2,int offset2)
{
	w_as_to_code_section ();
	if (offset2==0)
		fprintf (assembly_file,"\t.long\t%s - %s\n",label_name1,label_name2);
	else
		if (offset2>0)
			fprintf (assembly_file,"\t.long\t%s - (%s + %d)\n",label_name1,label_name2,offset2);
		else
			fprintf (assembly_file,"\t.long\t%s - (%s - %d)\n",label_name1,label_name2,-offset2);
}
#endif

void w_as_descriptor_in_data_section (char *label_name)
{
	w_as_to_data_section();
	w_as_align (3);
	fprintf (assembly_file,intel_directives ? "\tdq\t%s+2\n" : "\t.quad\t%s+2\n",label_name);
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
				w_as_opcode (intel_directives ? "db" : ".ascii");
				putc ('\"',assembly_file);
				in_string=1;
			}
			putc (c,assembly_file);
		} else {
			if (n==0)
				w_as_opcode (intel_directives ? "db" : ".byte");
			else {
				if (in_string){
					putc ('\"',assembly_file);
					w_as_newline();
					w_as_opcode (intel_directives ? "db" : ".byte");
					in_string=0;
				} else
					putc (',',assembly_file);
			}

			fprintf (assembly_file,intel_directives ? "%02xh" : "0x%02x",c);
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
			w_as_opcode (intel_directives ? "db" : ".byte");
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

#ifdef MACH_O64
void w_as_align_and_define_data_label (int label_number)
{
	w_as_to_data_section();
	w_as_align (3);	
	w_as_define_local_data_label (label_number);
}
#endif

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
	
	w_as_opcode (intel_directives ? "dq" : ".quad");
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

	w_as_opcode (intel_directives ? "dd" : ".long");
	fprintf (assembly_file,"%d\n",length);
	n=w_as_data (0,string,length);
	if (length & 3)
		n=w_as_zeros (n,4-(length & 3));
	if (n>0)
		w_as_newline();
}

enum { SIZE_OBYTE, SIZE_QBYTE, SIZE_DBYTE, SIZE_BYTE, };

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
	if (intel_directives)
		fprintf (assembly_file," label ptr");
	else
		w_as_colon();
	w_as_newline();
}

void w_as_define_label (LABEL *label)
{
	if (label->label_flags & EXPORT_LABEL){
		w_as_opcode (intel_directives ? "public" : ".globl");
		w_as_label (label->label_name);
		w_as_newline();
	}
	
	w_as_label (label->label_name);
	if (intel_directives)
		fprintf (assembly_file,"\tlabel ptr");
	else
		w_as_colon();
	w_as_newline();
}

static void w_as_define_code_label (LABEL *label)
{
	if (label->label_flags & EXPORT_LABEL){
		w_as_opcode (intel_directives ? "public" : ".globl");
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

static void w_as_immediate (int_64 i)
{
#ifdef LINUX
	if ((int)i==i)
		fprintf (assembly_file,intel_asm ? "%" PRIi64 : "$%" PRIi64,i);
	else
		fprintf (assembly_file,intel_asm ? "%" PRIu64 : "$%" PRIu64,i);
#else
	if ((int)i==i)
		fprintf (assembly_file,intel_asm ? "%I64i" : "$%I64u",i);
	else
		fprintf (assembly_file,intel_asm ? "%I64u" : "$%I64u",i);
#endif
}

void w_as_abc_string_and_label_in_data_section (char *string,int length,char *label_name)
{
	int n;

	w_as_to_data_section();
	
	w_as_define_data_label_name (label_name);
	
	w_as_opcode (intel_directives ? "dd" : ".long");
	fprintf (assembly_file,"%d\n",length);
	n=w_as_data (0,string,length);
	if (length & 3)
		n=w_as_zeros (n,4-(length & 3));
	if (n>0)
		w_as_newline();
}

static char *register_name[16]=	{"sp","di","si","bp","9","8","dx","cx","ax","bx",
								"10","11","12","13","14","15"};

static char register_name_char1[16]="sdsb98dcab111111";
static char register_name_char2[16]="piip  xxxx012345";

static char *byte_register_name[16]= {"spl","dil","sil","bpl","r9b","r8b","dl","cl","al","bl",
									  "r10b","r11b","r12b","r13b","r14b","r15b"};

static char *dbyte_register_name[16]= {"sp","di","si","bp","r9w","r8w","dx","cx","ax","bx",
									  "r10w","r11w","r12w","r13w","r14w","r15w"};

static char *qbyte_register_name[16]= {"esp","edi","esi","ebp","r9l","r8l","edx","ecx","eax","ebx",
									  "r10l","r11l","r12l","r13l","r14l","r15l"};

#define REGISTER_O0 (-5)
#define REGISTER_R8 (-3)
#define REGISTER_R9 (-4)
#define REGISTER_R15 7

static void w_as_indirect (int i,int reg)
{
	if (!intel_asm){
		if (i!=0){
			fprintf (assembly_file,"%d(%%r%s)",i,register_name[reg+8]);
		} else
			fprintf (assembly_file,"(%%r%s)",register_name[reg+8]);
	} else {
		if (i>0)
			fprintf (assembly_file,"%d[r%s]",i,register_name[reg+8]);
		else if (i==0)
			fprintf (assembly_file,"[r%s]",register_name[reg+8]);	
		else
			fprintf (assembly_file,"(%d)[r%s]",i,register_name[reg+8]);
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
				fprintf (assembly_file,intel_asm ? "%d[r%s+r%s*%d]" : "%d(%%r%s,%%r%s,%d)",offset,
						 register_name[reg1+8],register_name[reg2+8],1<<shift);
			else
				fprintf (assembly_file,intel_asm ? "%d[r%s+r%s]" : "%d(%%r%s,%%r%s)",offset,
						 register_name[reg1+8],register_name[reg2+8]);
		} else {
			if (shift!=0)
				fprintf (assembly_file,"(%d)[r%s+r%s*%d]",offset,
						 register_name[reg1+8],register_name[reg2+8],1<<shift);
			else
				fprintf (assembly_file,"(%d)[r%s+r%s]",offset,
						 register_name[reg1+8],register_name[reg2+8]);
		}
	} else {
		if (shift!=0)
			fprintf (assembly_file,intel_asm ? "[r%s+r%s*%d]" : "(%%r%s,%%r%s,%d)",
					 register_name[reg1+8],register_name[reg2+8],1<<shift);
		else
			fprintf (assembly_file,intel_asm ? "[r%s+r%s]" : "(%%r%s,%%r%s)",
					 register_name[reg1+8],register_name[reg2+8]);
	}
}

static void w_as_register (int reg)
{
	char c2;

	if (!intel_asm)
		putc ('%',assembly_file);
	putc ('r',assembly_file);
	putc (register_name_char1[reg+8],assembly_file);
	c2=register_name_char2[reg+8];
	if (c2!=' ')
		putc (c2,assembly_file);
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
	fprintf (assembly_file,intel_asm ? "xmm%d" : "%%xmm%d",fp_reg);
}

static void w_as_fp_register_newline (int fp_reg)
{
	fprintf (assembly_file,intel_asm ? "xmm%d\n" : "%%xmm%d\n",fp_reg);
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

static void w_as_lea_descriptor (LABEL *label,int arity,int register_1)
{
	w_as_opcode (intel_asm ? "lea" : "leaq");

	if (intel_asm)
		w_as_register_comma (register_1);

	if (label->label_number!=0)
		w_as_local_label (label->label_number);
	else
		w_as_label (label->label_name);

	if (arity!=0)
		if (arity>0)
			fprintf (assembly_file,"+%d",arity);
		else
			fprintf (assembly_file,"-%d",-arity);

#if defined (MACH_O64) || defined (LINUX)
	fprintf (assembly_file,"%s",intel_asm ? "[rip]" : "(%rip)");
#endif
	
	if (!intel_asm)
		w_as_comma_register (register_1);
	w_as_newline();
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
			w_as_immediate (parameter->parameter_data.imm);
			break;
		case P_INDIRECT:
			w_as_indirect (parameter->parameter_offset,parameter->parameter_data.reg.r);
			break;
		case P_INDEXED:
			w_as_indexed (parameter->parameter_offset,parameter->parameter_data.ir);
			break;
		case P_F_REGISTER:
			fprintf (assembly_file,intel_asm ? "xmm%d" : "%%xmm%d",parameter->parameter_data.reg.r<<1);
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
	char c2;
	
	w_as_comma();
	if (parameter->parameter_type!=P_REGISTER)
		internal_error_in_function ("w_as_comma_word_parameter");

	reg=parameter->parameter_data.reg.r;

	putc (register_name_char1[reg+8],assembly_file);
	c2=register_name_char2[reg+8];
	if (c2!=' ')
		putc (c2,assembly_file);
}

static void w_as_byte_register (int reg)
{
	if (!intel_asm)
		putc ('%',assembly_file);
	fprintf (assembly_file,"%s",byte_register_name[reg+8]);
}

static void w_as_byte_register_comma (int reg)
{	
	w_as_byte_register (reg);
	w_as_comma();
}

static void w_as_comma_byte_register (int reg)
{	
	w_as_comma();
	w_as_byte_register (reg);
}

static void w_as_qbyte_register (int reg)
{
	fprintf (assembly_file,intel_asm ? "%s" : "%%%s",qbyte_register_name[reg+8]);
}

static void w_as_qbyte_register_comma (int reg)
{
	w_as_qbyte_register (reg);
	w_as_comma();
}

static void w_as_comma_qbyte_register (int reg)
{	
	w_as_comma();
	w_as_qbyte_register (reg);
}

#ifdef MACH_O64
static void intel_syntax (void)
{
	w_as_opcode (".intel_syntax");
	fprintf (assembly_file,"noprefix\n");
}

static void att_syntax (void)
{
	fprintf (assembly_file,"\t.att_syntax\n");
}
#endif

static void w_as_call_or_jump (struct parameter *parameter,char *opcode)
{
	switch (parameter->parameter_type){
		case P_LABEL:
#ifdef MACH_O64
			if (intel_asm)
				att_syntax();
#endif
			w_as_opcode (opcode);
	
			if (parameter->parameter_data.l->label_number!=0)
				w_as_local_label (parameter->parameter_data.l->label_number);
			else
				w_as_label (parameter->parameter_data.l->label_name);
#ifdef MACH_O64
			w_as_newline();
			if (intel_asm)
				intel_syntax();
			return;
#else
			break;
#endif
		case P_INDIRECT:
		{
			int offset,reg;

			offset=parameter->parameter_offset;
			reg=parameter->parameter_data.reg.r;
	
			if (!intel_asm){
				w_as_opcode (opcode);
				if (offset!=0)
					fprintf (assembly_file,"*%d(%%r%s)",offset,register_name[reg+8]);
				else
					fprintf (assembly_file,"*(%%r%s)",register_name[reg+8]);
			} else {
#ifdef MACH_O64
				w_as_opcode (opcode);
				if (offset!=0)
					fprintf (assembly_file,"qword ptr %d[r%s]",offset,register_name[reg+8]);
				else
					fprintf (assembly_file,"qword ptr (%d)[r%s]",offset,register_name[reg+8]);
#else
#if 1
				if (offset!=0){
					w_as_opcode (intel_asm ? "movsxd" : "movslq");
					/*
					if (reg==REGISTER_R8 || reg==REGISTER_R9)
						fprintf (assembly_file,"r%cd",register_name_char1[reg+8]);
					else
						fprintf (assembly_file,"r%c%cd",register_name_char1[reg+8],register_name_char2[reg+8]);
					*/
					/*
					fprintf (assembly_file,"ebp");
					*/
					w_as_scratch_register();
					w_as_comma();
					if (offset>0)
						fprintf (assembly_file,"dword ptr %d[r%s]",offset,register_name[reg+8]);
					else
						fprintf (assembly_file,"dword ptr (%d)[r%s]",offset,register_name[reg+8]);
					
					w_as_newline();
					
					reg=REGISTER_O0;
				}
#endif
				w_as_opcode (opcode);
#ifndef MACH_O64
				fprintf (assembly_file,"near ptr ");
#endif
				if (offset>0)
					fprintf (assembly_file,
#if 1
							"r%s",
#else
							"%d[r%s]",offset,
#endif							 
							 register_name[reg+8]);
				else if (offset==0)
					fprintf (assembly_file,"[r%s]",register_name[reg+8]);
				else
					fprintf (assembly_file,
#if 1
							"r%s",
#else
							"(%d)[r%s]",offset,
#endif
							 register_name[reg+8]);
#endif
			}
			break;
		}
		case P_REGISTER:
		{
			int reg;

			w_as_opcode (opcode);
	
			reg=parameter->parameter_data.reg.r;

			fprintf (assembly_file,intel_asm ? "r%s" : "*%%r%s",register_name[reg+8]);
			break;
		}
		default:
			internal_error_in_function ("w_as_jump_parameter");
	}
	w_as_newline();
}

static void w_as_opcode_movl (void)
{
	w_as_opcode (intel_asm ? "mov" : "movl");
}

static void w_as_opcode_movq (void)
{
	w_as_opcode (intel_asm ? "mov" : "movq");
}

static void w_as_opcode_move (int size_flag)
{
	w_as_opcode (intel_asm  ? (size_flag==SIZE_OBYTE ? "mov"  :
							   size_flag==SIZE_BYTE  ? "movzx" :
							   size_flag==SIZE_DBYTE ? "movsx" : "movsxd")
							: (size_flag==SIZE_OBYTE ? "movq" :
							   size_flag==SIZE_BYTE  ? "movzbq" :
							   size_flag==SIZE_DBYTE  ? "movswq" : "movslq")
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

static void w_as_movq_register_register_newline (int reg1,int reg2)
{
	w_as_opcode_movq();
	w_as_register_register_newline (reg1,reg2);
}

static void w_as_immediate_register_newline (int_64 i,int reg)
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

static void print_ptr (int size_flag)
{
	char *s;

	switch (size_flag){
		case SIZE_BYTE:  s="byte ptr "; break;
		case SIZE_DBYTE: s="word ptr "; break;
		case SIZE_QBYTE: s="dword ptr "; break;
		case SIZE_OBYTE: s="qword ptr "; break;
		default: return;
	}
	fputs (s,assembly_file);
}

static void w_as_move_instruction (struct instruction *instruction,int size_flag)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_REGISTER:
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_DESCRIPTOR_NUMBER:
#ifdef LEA_ADDRESS
					w_as_lea_descriptor (
						instruction->instruction_parameters[0].parameter_data.l,
						instruction->instruction_parameters[0].parameter_offset,
						instruction->instruction_parameters[1].parameter_data.reg.r
					);
					return;
#else
					w_as_opcode_movq();
					if (intel_asm)
						w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_descriptor (
						instruction->instruction_parameters[0].parameter_data.l,
						instruction->instruction_parameters[0].parameter_offset
					);
					break;
#endif
				case P_IMMEDIATE:
					if (   (int)instruction->instruction_parameters[0].parameter_data.imm==instruction->instruction_parameters[0].parameter_data.imm
						&& (int)instruction->instruction_parameters[0].parameter_data.imm>=0)
					{
						w_as_opcode_movl();
						if (intel_asm)
							w_as_qbyte_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
						w_as_immediate (instruction->instruction_parameters[0].parameter_data.imm);
						if (!intel_asm)
							w_as_comma_qbyte_register (instruction->instruction_parameters[1].parameter_data.reg.r);
						w_as_newline();
						return;
					}

					w_as_opcode_movq();
					if (intel_asm)
						w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_immediate (instruction->instruction_parameters[0].parameter_data.imm);
					break;
				case P_INDIRECT:
					w_as_opcode_move (size_flag);
					if (intel_asm){
						w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
						if (size_flag!=SIZE_OBYTE)
							print_ptr (size_flag);
					}
					w_as_indirect (instruction->instruction_parameters[0].parameter_offset,
								   instruction->instruction_parameters[0].parameter_data.reg.r);
					break;
				case P_INDEXED:
					w_as_opcode_move (size_flag);
					if (intel_asm){
						w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
						if (size_flag!=SIZE_OBYTE)
							print_ptr (size_flag);
					}
					w_as_indexed (instruction->instruction_parameters[0].parameter_offset,
								  instruction->instruction_parameters[0].parameter_data.ir);
					break;					
				case P_REGISTER:
					w_as_opcode_movq();
					if (intel_asm)
						w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_register (instruction->instruction_parameters[0].parameter_data.reg.r);
					break;
				case P_POST_INCREMENT:
					w_as_opcode (intel_asm ? "pop" : "popq");
					w_as_register (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_newline();
					return;
				case P_LABEL:
					w_as_opcode_movq();
					if (intel_asm)
						w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					if (instruction->instruction_parameters[0].parameter_data.l->label_number!=0)
						w_as_local_label (instruction->instruction_parameters[0].parameter_data.l->label_number);
					else
						w_as_label (instruction->instruction_parameters[0].parameter_data.l->label_name);
#if defined (MACH_O64) || defined (LINUX)
					fprintf (assembly_file,"%s",intel_asm ? "[rip]" : "(%rip)");
#endif
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
						if (size_flag!=SIZE_OBYTE)
							print_ptr (size_flag);
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
						if (size_flag!=SIZE_OBYTE)
							print_ptr (size_flag);
					}
					w_as_indexed (parameter.parameter_offset,parameter.parameter_data.ir);
					if (!intel_asm)
						w_as_comma_scratch_register();
					w_as_newline();
		
					parameter.parameter_type=P_REGISTER;
					parameter.parameter_data.reg.r=REGISTER_O0;
					break;
				case P_DESCRIPTOR_NUMBER:
#ifdef LEA_ADDRESS
					w_as_lea_descriptor (parameter.parameter_data.l,parameter.parameter_offset,REGISTER_O0);
					
					w_as_opcode_movq();
					if (intel_asm){
						w_as_indirect (instruction->instruction_parameters[1].parameter_offset,
									   instruction->instruction_parameters[1].parameter_data.reg.r);
						w_as_comma();
					}
					w_as_scratch_register();
#else
					w_as_opcode_movq();
					if (intel_asm){
						print_ptr (size_flag);
						w_as_indirect (instruction->instruction_parameters[1].parameter_offset,
									   instruction->instruction_parameters[1].parameter_data.reg.r);
						w_as_comma();
					}
					w_as_descriptor (parameter.parameter_data.l,parameter.parameter_offset);
#endif
					if (!intel_asm){
						w_as_comma();
						w_as_indirect (instruction->instruction_parameters[1].parameter_offset,
									   instruction->instruction_parameters[1].parameter_data.reg.r);
					}
					w_as_newline();
					return;
				case P_IMMEDIATE:
					if ((int)parameter.parameter_data.imm!=parameter.parameter_data.imm){
						w_as_opcode_movq();
						if (intel_asm)
							w_as_scratch_register_comma();
						w_as_immediate (parameter.parameter_data.imm);
						if (!intel_asm)
							w_as_comma_scratch_register();
						w_as_newline();

						parameter.parameter_type=P_REGISTER;
						parameter.parameter_data.reg.r=REGISTER_O0;
					}
					break;
				case P_REGISTER:
					break;
				case P_POST_INCREMENT:
					w_as_opcode (intel_asm ? "pop" : "popq");
					w_as_indirect (instruction->instruction_parameters[1].parameter_offset,
									   instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_newline();
					return;
				default:
					internal_error_in_function ("w_as_move");
			}

			w_as_opcode (intel_asm ? "mov" : (size_flag==SIZE_OBYTE ? "movq" : 
											  size_flag==SIZE_BYTE  ? "movb" :
											  size_flag==SIZE_DBYTE ? "movw" :"movl"));
			if (!intel_asm){
				if (size_flag==SIZE_BYTE && parameter.parameter_type==P_REGISTER)
					w_as_byte_register_comma (parameter.parameter_data.reg.r);
				else
					w_as_parameter_comma (&parameter);
			} else if (parameter.parameter_type==P_IMMEDIATE)
				print_ptr (size_flag);
			w_as_indirect (instruction->instruction_parameters[1].parameter_offset,
						   instruction->instruction_parameters[1].parameter_data.reg.r);
			if (intel_asm){
				if (size_flag==SIZE_OBYTE || parameter.parameter_type==P_IMMEDIATE)
					w_as_comma_parameter (&parameter);
				else if (size_flag==SIZE_DBYTE)
					w_as_comma_word_parameter (&parameter);
				else {
					if (parameter.parameter_type!=P_REGISTER)
						internal_error_in_function ("w_as_move_instruction");
					if (size_flag==SIZE_BYTE)
						w_as_comma_byte_register (parameter.parameter_data.reg.r);
					else
						w_as_comma_qbyte_register (parameter.parameter_data.reg.r);
				}
			}
			w_as_newline();
			return;
		}
		case P_PRE_DECREMENT:
			if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE &&
				(int)instruction->instruction_parameters[0].parameter_data.imm!=instruction->instruction_parameters[0].parameter_data.imm)
			{
				w_as_opcode_movq();
				if (intel_asm)
					w_as_scratch_register_comma();
				w_as_immediate (instruction->instruction_parameters[0].parameter_data.imm);
				if (!intel_asm)
					w_as_comma_scratch_register();
				w_as_newline();

				w_as_opcode (intel_asm ? "push" : "pushq");
				w_as_scratch_register();
				w_as_newline();
			} else {
				w_as_opcode (intel_asm ? "push" : "pushq");
				if (instruction->instruction_parameters[0].parameter_type==P_DESCRIPTOR_NUMBER)
					w_as_descriptor (instruction->instruction_parameters[0].parameter_data.l,instruction->instruction_parameters[0].parameter_offset);
				else
					w_as_parameter (&instruction->instruction_parameters[0]);
				w_as_newline();
			}
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
						if (size_flag!=SIZE_OBYTE)
							print_ptr (size_flag);
					}
					w_as_indirect (parameter.parameter_offset,parameter.parameter_data.reg.r);
					if (!intel_asm)
						w_as_comma_scratch_register();
					w_as_newline();
		
					parameter.parameter_type=P_REGISTER;
					parameter.parameter_data.reg.r=REGISTER_O0;
					break;
				case P_DESCRIPTOR_NUMBER:
					w_as_opcode_movq();
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
					if ((int)parameter.parameter_data.imm!=parameter.parameter_data.imm){
						w_as_opcode_movq();
						if (intel_asm)
							w_as_scratch_register_comma();
						w_as_immediate (parameter.parameter_data.imm);
						if (!intel_asm)
							w_as_comma_scratch_register();
						w_as_newline();

						parameter.parameter_type=P_REGISTER;
						parameter.parameter_data.reg.r=REGISTER_O0;
					}
					break;
				case P_REGISTER:
					break;
				case P_POST_INCREMENT:
					w_as_opcode (intel_asm ? "pop" : "popq");
					w_as_indexed (instruction->instruction_parameters[1].parameter_offset,
									  instruction->instruction_parameters[1].parameter_data.ir);
					w_as_newline();
					return;
				default:
					internal_error_in_function ("w_as_move");
			}

			w_as_opcode (intel_asm ? "mov" : (size_flag==SIZE_OBYTE ? "movq" : size_flag==SIZE_DBYTE ? "movw" : "movb"));
			if (!intel_asm){
				if (size_flag==SIZE_BYTE && parameter.parameter_type==P_REGISTER)
					w_as_byte_register_comma (parameter.parameter_data.reg.r);					
				else
					w_as_parameter_comma (&parameter);
			}
			else if (parameter.parameter_type==P_IMMEDIATE)
				fprintf (assembly_file,size_flag==SIZE_OBYTE ? "qword ptr " : size_flag==SIZE_DBYTE ? "word ptr " : "byte ptr ");
			w_as_indexed (instruction->instruction_parameters[1].parameter_offset,
						  instruction->instruction_parameters[1].parameter_data.ir);
			if (intel_asm){
				if (size_flag==SIZE_OBYTE || parameter.parameter_type==P_IMMEDIATE)
					w_as_comma_parameter (&parameter);
				else if (size_flag==SIZE_DBYTE)
					w_as_comma_word_parameter (&parameter);
				else {
					if (parameter.parameter_type!=P_REGISTER)
						internal_error_in_function ("w_as_move_instruction");
					if (size_flag==SIZE_BYTE)
						w_as_comma_byte_register (parameter.parameter_data.reg.r);
					else
						w_as_comma_qbyte_register (parameter.parameter_data.reg.r);
				}
			}
			w_as_newline();
			return;
		}
		case P_LABEL:
			if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
				w_as_opcode_movq();
				if (!intel_asm){
					w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
				}
				if (instruction->instruction_parameters[1].parameter_data.l->label_number!=0)
					w_as_local_label (instruction->instruction_parameters[1].parameter_data.l->label_number);
				else
					w_as_label (instruction->instruction_parameters[1].parameter_data.l->label_name);
#if defined (MACH_O64) || defined (LINUX)
				fprintf (assembly_file,"%s",intel_asm ? "[rip]" : "(%rip)");
#endif
				if (intel_asm)
					w_as_comma_register (instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_newline();
				return;
			}
		default:
			internal_error_in_function ("w_as_move_instruction");
	}
}

static void w_as_loadsqb_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_INDIRECT:
				w_as_opcode (intel_asm ? "movsxd" : "movslq");
				if (intel_asm){
					w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					fprintf (assembly_file,"dword ptr ");
				}
				w_as_indirect (instruction->instruction_parameters[0].parameter_offset,
							   instruction->instruction_parameters[0].parameter_data.reg.r);
				break;
			case P_INDEXED:
				w_as_opcode (intel_asm ? "movsxd" : "movslq");
				if (intel_asm){
					w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					fprintf (assembly_file,"dword ptr ");
				}
				w_as_indexed (instruction->instruction_parameters[0].parameter_offset,
							  instruction->instruction_parameters[0].parameter_data.ir);
				break;					
			case P_REGISTER:
				w_as_opcode (intel_asm ? "movsxd" : "movslq");
				if (intel_asm){
					w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_qbyte_register (instruction->instruction_parameters[0].parameter_data.reg.r);
				} else {
					w_as_qbyte_register (instruction->instruction_parameters[0].parameter_data.reg.r);
					w_as_comma_register (instruction->instruction_parameters[1].parameter_data.reg.r);
				}
				w_as_newline();
				return;
			default:
				internal_error_in_function ("w_as_loadsqb_instruction");
				return;
		}
		if (!intel_asm)
			w_as_comma_register (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_newline();
		return;
	}
	internal_error_in_function ("w_as_loadsqb_instruction");
}

static void w_as_lea_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		w_as_opcode (intel_asm ? "lea" : "leaq");

		if (intel_asm)
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		if (instruction->instruction_parameters[0].parameter_type==P_LABEL){
#ifndef MACH_O64
			if (intel_asm)
				fprintf (assembly_file,"offset ");
#endif
			if (instruction->instruction_parameters[0].parameter_data.l->label_number!=0)
				w_as_local_label (instruction->instruction_parameters[0].parameter_data.l->label_number);
			else
				w_as_label (instruction->instruction_parameters[0].parameter_data.l->label_name);
			if (instruction->instruction_parameters[0].parameter_offset!=0){
				int offset;

				offset=instruction->instruction_parameters[0].parameter_offset;
				fprintf (assembly_file,offset>=0 ? "+%d" : "%d",offset);
			}
#if defined (MACH_O64) || defined (LINUX)
			fprintf (assembly_file,"%s",intel_asm ? "[rip]" : "(%rip)");
#endif
		} else
			w_as_parameter (&instruction->instruction_parameters[0]);
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
	w_as_opcode (intel_asm ? "lzcnt" : "lzcntq");
	if (intel_asm)
		w_as_parameter_comma (parameter_1_p);
	w_as_parameter (parameter_0_p);
	if (!intel_asm)
		w_as_comma_parameter (parameter_1_p);
	w_as_newline();
#else
	w_as_opcode_movl();
	w_as_immediate_register_newline (127,parameter_1_p->parameter_data.reg.r);

	w_as_opcode (intel_asm ? "bsr" : "bsrq");
	if (intel_asm)
		w_as_parameter_comma (parameter_1_p);
	w_as_parameter (parameter_0_p);
	if (!intel_asm)
		w_as_comma_parameter (parameter_1_p);
	w_as_newline();

	w_as_opcode (intel_asm ? "xor" : "xorq");
	if (intel_asm){
		w_as_register_comma (parameter_1_p->parameter_data.reg.r);
		w_as_immediate (63);
	} else {
		w_as_immediate (63);
		w_as_comma_register (parameter_1_p->parameter_data.reg.r);
	}
	w_as_newline();
#endif
}

static void w_as_shift_instruction (struct instruction *instruction,char *opcode)
{
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		w_as_opcode (opcode);
		if (intel_asm)
			w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_immediate (instruction->instruction_parameters[0].parameter_data.i & 63);
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
		
		w_as_movq_register_register_newline (REGISTER_A0,REGISTER_O0);

		w_as_opcode_movq();
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

		w_as_movq_register_register_newline (REGISTER_O0,REGISTER_A0);
	}
}

static void w_as_shift_s_instruction (struct instruction *instruction,char *opcode)
{
	if (instruction->instruction_parameters[0].parameter_type!=P_REGISTER){
		if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
			w_as_opcode (opcode);
			if (intel_asm)
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_immediate (instruction->instruction_parameters[0].parameter_data.i & 63);
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
				w_as_movq_register_register_newline (r0,REGISTER_A0);

				w_as_opcode (opcode);
				if (!intel_asm)
					fprintf (assembly_file,"%%cl,");
				w_as_register (instruction->instruction_parameters[1].parameter_data.reg.r);
				if (intel_asm)
					fprintf (assembly_file,",cl");
				w_as_newline();
			} else {
				int r;
				
				w_as_movq_register_register_newline (REGISTER_A0,scratch_register);
				w_as_movq_register_register_newline (r0,REGISTER_A0);

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

				w_as_movq_register_register_newline (scratch_register,REGISTER_A0);
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
			w_as_lea_descriptor (parameter_0.parameter_data.l,parameter_0.parameter_offset,REGISTER_O0);

			w_as_opcode (intel_asm ? "cmp" : "cmpq");
			if (intel_asm)
				w_as_parameter_comma (&parameter_1);
			w_as_scratch_register();
			if (!intel_asm)
				w_as_comma_parameter (&parameter_1);
			w_as_newline();
			return;
		case P_IMMEDIATE:
			if (parameter_0.parameter_data.i==0 && parameter_1.parameter_type==P_REGISTER){
				w_as_opcode (intel_asm ? "test" : "testq");
				w_as_register (parameter_1.parameter_data.reg.r);
				w_as_comma_register (parameter_1.parameter_data.reg.r);
				w_as_newline();
				return;
			}
	}

	w_as_opcode (intel_asm ? "cmp" : "cmpq");
	if (intel_asm){
		if (parameter_0.parameter_type==P_IMMEDIATE && parameter_1.parameter_type!=P_REGISTER)
			fprintf (assembly_file,"qword ptr ");
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
			w_as_lea_descriptor (parameter_0.parameter_data.l,parameter_0.parameter_offset,REGISTER_O0);

			w_as_opcode (intel_asm ? "cmp" : "cmpq");
			if (intel_asm)
				w_as_parameter_comma (&parameter_1);
			w_as_scratch_register();
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
			break;
	}

	w_as_opcode (intel_asm ? "cmp" : "cmpq");
	if (intel_asm){
		if (parameter_0.parameter_type==P_IMMEDIATE && parameter_1.parameter_type!=P_REGISTER)
			fprintf (assembly_file,"qword ptr ");
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

	w_as_opcode (intel_asm ? "test" : "testq");
	if (intel_asm){
		if (parameter_0.parameter_type==P_IMMEDIATE && parameter_1.parameter_type!=P_REGISTER)
			fprintf (assembly_file,"qword ptr ");
		w_as_parameter_comma (&parameter_1);
	}
	w_as_parameter (&parameter_0);
	if (!intel_asm)
		w_as_comma_parameter (&parameter_1);
	w_as_newline();
}

static void w_as_btst_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		w_as_opcode (intel_asm ? "test" : "testb");
		if (intel_asm)
			w_as_byte_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
		w_as_immediate (instruction->instruction_parameters[0].parameter_data.i);
		if (!intel_asm)
			w_as_comma_byte_register (instruction->instruction_parameters[1].parameter_data.reg.r);
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
	w_as_call_or_jump (&instruction->instruction_parameters[0],"jmp");
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
		
			w_as_call_or_jump (&instruction->instruction_parameters[0],"jmp");
			return;
		default:
			internal_error_in_function ("w_as_jmpp_instruction");
	}

	w_as_newline();
}

static void w_as_branch_instruction (struct instruction *instruction,char *opcode)
{
#ifdef MACH_O64
	if (intel_asm)
		att_syntax();
#endif
	w_as_opcode (opcode);
	w_as_branch_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();
#ifdef MACH_O64
	if (intel_asm)
		intel_syntax();
#endif
}

static void w_as_float_branch_instruction (struct instruction *instruction,int n)
{
	int label_number;
	
	switch (n){
		case 2:
			w_as_opcode ("ja");
#ifdef MACH_O64
			if (instruction->instruction_parameters[0].parameter_type==P_LABEL){
				if (instruction->instruction_parameters[0].parameter_data.l->label_number!=0)
					w_as_local_label (instruction->instruction_parameters[0].parameter_data.l->label_number);
				else
					w_as_label (instruction->instruction_parameters[0].parameter_data.l->label_name);
			} else
#endif
			w_as_parameter (&instruction->instruction_parameters[0]);
			w_as_newline();
			return;
		case 3:
			w_as_opcode ("jne");
#ifdef MACH_O64
			if (instruction->instruction_parameters[0].parameter_type==P_LABEL){
				if (instruction->instruction_parameters[0].parameter_data.l->label_number!=0)
					w_as_local_label (instruction->instruction_parameters[0].parameter_data.l->label_number);
				else
					w_as_label (instruction->instruction_parameters[0].parameter_data.l->label_name);
			} else
#endif
			w_as_parameter (&instruction->instruction_parameters[0]);
			w_as_newline();
			return;
		case 5:
			w_as_opcode ("jae");
#ifdef MACH_O64
			if (instruction->instruction_parameters[0].parameter_type==P_LABEL){
				if (instruction->instruction_parameters[0].parameter_data.l->label_number!=0)
					w_as_local_label (instruction->instruction_parameters[0].parameter_data.l->label_number);
				else
					w_as_label (instruction->instruction_parameters[0].parameter_data.l->label_name);
			} else
#endif
			w_as_parameter (&instruction->instruction_parameters[0]);
			w_as_newline();
			return;
	}

	label_number=next_label_id++;

	w_as_opcode ("jp");
	w_as_internal_label (label_number);
	w_as_newline();

	switch (n){
		case 0:
			w_as_opcode ("je");
			break;
		case 1:
			w_as_opcode ("jb");
			break;
		case 4:
			w_as_opcode ("jbe");
			break;
	}

#ifdef MACH_O64
	if (instruction->instruction_parameters[0].parameter_type==P_LABEL){
		if (instruction->instruction_parameters[0].parameter_data.l->label_number!=0)
			w_as_local_label (instruction->instruction_parameters[0].parameter_data.l->label_number);
		else
			w_as_label (instruction->instruction_parameters[0].parameter_data.l->label_name);
	} else
#endif
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();

	w_as_define_internal_label (label_number);
}

static void w_as_float_branch_not_instruction (struct instruction *instruction,int n)
{
	if (((1<<n) & ((1<<0)|(1<<1)|(1<<4)))!=0 /* n==0 || n==1 || n==4 */){
		w_as_opcode ("jp");
#ifdef MACH_O64
		if (instruction->instruction_parameters[0].parameter_type==P_LABEL){
			if (instruction->instruction_parameters[0].parameter_data.l->label_number!=0)
				w_as_local_label (instruction->instruction_parameters[0].parameter_data.l->label_number);
			else
				w_as_label (instruction->instruction_parameters[0].parameter_data.l->label_name);
		} else
#endif
		w_as_parameter (&instruction->instruction_parameters[0]);
		w_as_newline();
	}

	switch (n){
		case 2:
			w_as_opcode ("jbe" /* "jna" */);
			break;
		case 3:
			w_as_opcode ("je");
			break;
		case 5:
			w_as_opcode ("jb" /* "jnae" */);
			break;
		case 0:
			w_as_opcode ("jne");
			break;
		case 1:
			w_as_opcode ("jae" /* "jnb" */);
			break;
		case 4:
			w_as_opcode ("ja" /* "jnbe" */);
			break;
	}

#ifdef MACH_O64
	if (instruction->instruction_parameters[0].parameter_type==P_LABEL){
		if (instruction->instruction_parameters[0].parameter_data.l->label_number!=0)
			w_as_local_label (instruction->instruction_parameters[0].parameter_data.l->label_number);
		else
			w_as_label (instruction->instruction_parameters[0].parameter_data.l->label_name);
	} else
#endif
	w_as_parameter (&instruction->instruction_parameters[0]);
	w_as_newline();
}

static void w_as_jsr_instruction (struct instruction *instruction)
{
	w_as_call_or_jump (&instruction->instruction_parameters[0],"call");
}

static void w_as_set_condition_instruction (struct instruction *instruction,char *opcode)
{
	int r;
	
	r=instruction->instruction_parameters[0].parameter_data.reg.r;
	
	w_as_opcode (opcode);
	w_as_byte_register (r);
	w_as_newline();

	w_as_opcode (intel_asm ? "movzx" : "movzbq");
	if (intel_asm)
		w_as_register_comma (r);
	w_as_byte_register (r);
	if (!intel_asm)
		w_as_comma_register (r);
	w_as_newline();
}

static void w_as_set_float_condition_instruction (struct instruction *instruction,int n)
{
	int r;

	r=instruction->instruction_parameters[0].parameter_data.reg.r;

	switch (n){
		case 2:
			w_as_opcode ("seta");
			w_as_byte_register (r);
			w_as_newline();
			break;
		case 5:
			w_as_opcode ("setae");
			w_as_byte_register (r);
			w_as_newline();
			break;
		case 3:
			w_as_opcode ("setne");
			w_as_byte_register (r);
			w_as_newline();
			break;
		default:
			w_as_opcode ("setnp");
			if (!intel_asm)
				putc ('%',assembly_file);
			fprintf (assembly_file,"bpl");
			w_as_newline();

			switch (n){
				case 0:
					w_as_opcode ("sete");
					break;
				case 1:
					w_as_opcode ("setb");
					break;
				case 4:
					w_as_opcode ("setbe");
					break;
			}
			w_as_byte_register (r);
			w_as_newline();

			w_as_opcode ("and");
			if (intel_asm){
				w_as_byte_register (r);
				w_as_comma();
			}
			if (!intel_asm)
				putc ('%',assembly_file);
			fprintf (assembly_file,"bpl");
			if (!intel_asm){
				w_as_comma();
				w_as_byte_register (r);
			}
			w_as_newline();
	}

	w_as_opcode ("movzx");
	if (intel_asm)
		w_as_register_comma (r);
	w_as_byte_register (r);
	if (!intel_asm)
		w_as_comma_register (r);
	w_as_newline();
}

static void w_as_div_rem_i_instruction (struct instruction *instruction,int compute_remainder)
{
	int s_reg1,s_reg2,s_reg3,sd_reg,i_reg,tmp_reg;
	struct ms ms;
	int_64 i,abs_i;

	if (instruction->instruction_parameters[0].parameter_type!=P_IMMEDIATE)
		internal_error_in_function ("w_as_div_rem_i_instruction");

	i=instruction->instruction_parameters[0].parameter_data.imm;

	if (! ((i>1 || (i<-1 && i!=0x8000000000000000ll))))
		internal_error_in_function ("w_as_div_rem_i_instruction");
	
	abs_i=i>=0 ? i : -i;

	if (compute_remainder)
		i=abs_i;

	ms=magic (abs_i);
	
	sd_reg=instruction->instruction_parameters[1].parameter_data.reg.r;
	tmp_reg=instruction->instruction_parameters[2].parameter_data.reg.r;

	if (sd_reg==tmp_reg)
		internal_error_in_function ("w_as_div_rem_i_instruction");		

	if (sd_reg==REGISTER_A1){
		if (tmp_reg!=REGISTER_D0)
			w_as_movq_register_register_newline (REGISTER_D0,tmp_reg);

		w_as_movq_register_register_newline (REGISTER_A1,REGISTER_O0);
		
		s_reg1=sd_reg;
		s_reg2=REGISTER_O0;
		i_reg=REGISTER_D0;
	} else if (sd_reg==REGISTER_D0){
		if (tmp_reg!=REGISTER_A1)
			w_as_movq_register_register_newline (REGISTER_A1,tmp_reg);			
		
		w_as_movq_register_register_newline (REGISTER_D0,REGISTER_O0);

		s_reg1=REGISTER_A1;
		s_reg2=REGISTER_O0;
		i_reg=REGISTER_A1;
	} else {
		if (tmp_reg==REGISTER_D0)
			w_as_movq_register_register_newline (REGISTER_A1,REGISTER_O0);			
		else if (tmp_reg==REGISTER_A1)
			w_as_movq_register_register_newline (REGISTER_D0,REGISTER_O0);						
		else {
			w_as_movq_register_register_newline (REGISTER_D0,REGISTER_O0);
			w_as_movq_register_register_newline (REGISTER_A1,tmp_reg);
		}
		
		s_reg1=sd_reg;
		s_reg2=sd_reg;
		i_reg=REGISTER_D0;
	}

	w_as_opcode_movq();
	w_as_immediate_register_newline (ms.m,i_reg);

	w_as_opcode (intel_asm ? "imul" : "imulq");
	w_as_register (s_reg1);
	w_as_newline();
	
	if (compute_remainder)
		w_as_movq_register_register_newline (s_reg2,REGISTER_D0);

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
	w_as_immediate_register_newline (63,s_reg2);

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
				w_as_movq_register_register_newline (s_reg2,sd_reg);
			}
		} else if (sd_reg==REGISTER_D0){
			struct index_registers index_registers;

			if (i>=0){
				index_registers.a_reg.r=REGISTER_A1;
				index_registers.d_reg.r=s_reg2;
						
				w_as_opcode (intel_asm ? "lea" : "leaq");
				if (intel_asm)
					w_as_register_comma (sd_reg);
				w_as_indexed (0,&index_registers);
				if (!intel_asm)
					w_as_comma_register (sd_reg);
				w_as_newline();
			} else {
				w_as_movq_register_register_newline (s_reg2,sd_reg);
				w_as_opcode_register_register_newline ("sub",REGISTER_A1,sd_reg);			
			}
		} else
			w_as_opcode_register_register_newline (i>=0 ? "add" : "sub",REGISTER_A1,s_reg2); /* s_reg2==sd_reg */
	} else {
		int_64 i2;
		
		w_as_opcode_register_register_newline ("add",s_reg2,REGISTER_A1);

		i2=i & (i-1);
		if ((i2 & (i2-1))==0){
			uint_64 n;
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
			if (((int)i)==i){
				w_as_opcode (intel_asm ? "imul" : "imulq");
				w_as_immediate_register_newline (i,REGISTER_A1);
			} else {
				w_as_opcode_movq();
				w_as_immediate_register_newline (i,s_reg2);

				w_as_opcode_register_register_newline (intel_asm ? "imul" : "imulq",s_reg2,REGISTER_A1);
			}

			w_as_opcode_register_register_newline ("sub",REGISTER_A1,s_reg3);
		}
		
		if (sd_reg!=s_reg3)
			w_as_movq_register_register_newline (s_reg3,sd_reg);
	}

	if (sd_reg==REGISTER_A1){
		if (tmp_reg!=REGISTER_D0)
			w_as_movq_register_register_newline (tmp_reg,REGISTER_D0);
	} else if (sd_reg==REGISTER_D0){
		if (tmp_reg!=REGISTER_A1)
			w_as_movq_register_register_newline (tmp_reg,REGISTER_A1);
	} else {
		if (tmp_reg==REGISTER_D0)
			w_as_movq_register_register_newline (REGISTER_O0,REGISTER_A1);
		else if (tmp_reg==REGISTER_A1)
			w_as_movq_register_register_newline (REGISTER_O0,REGISTER_D0);						
		else {
			w_as_movq_register_register_newline (REGISTER_O0,REGISTER_D0);			
			w_as_movq_register_register_newline (tmp_reg,REGISTER_A1);			
		}
	}
}

static void w_as_div_instruction (struct instruction *instruction,int unsigned_div)
{
	int d_reg;

	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE && unsigned_div==0){
		int_64 i;
		int log2i;
		
		i=instruction->instruction_parameters[0].parameter_data.imm;
		
		if ((i & (i-1))==0 && i>0){		
			if (i==1)
				return;
			
			log2i=0;
			while (i>1){
				i=i>>1;
				++log2i;
			}
			
			w_as_movq_register_register_newline (d_reg,REGISTER_O0);

			if (log2i==1){
				w_as_opcode ("sar");
				w_as_immediate_register_newline (63,REGISTER_O0);

				w_as_opcode_register_register_newline ("sub",REGISTER_O0,d_reg);
			} else {
				if (log2i<32){
					w_as_opcode ("sar");
					w_as_immediate_register_newline (63,d_reg);

					w_as_opcode ("and");
					w_as_immediate_register_newline ((1<<log2i)-1,d_reg);
				} else {
					w_as_opcode ("sar");
					w_as_immediate_register_newline (log2i-1,d_reg);

					w_as_opcode ("shr");
					w_as_immediate_register_newline (64-log2i,d_reg);
				}

				w_as_opcode_register_register_newline ("add",REGISTER_O0,d_reg);
			}
			
			w_as_opcode ("sar");
			w_as_immediate_register_newline (log2i,d_reg);

			return;
		} else {
			internal_error_in_function ("w_as_div_instruction");
			return;
		}
	}

	switch (d_reg){
		case REGISTER_D0:
			w_as_movq_register_register_newline (REGISTER_A1,REGISTER_O0);
	
			if (unsigned_div){
				w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);
				w_as_opcode (intel_asm ? "div" : "divq");
			} else {
				w_as_instruction_without_parameters ("cqo");
				w_as_opcode (intel_asm ? "idiv" : "idivq");
			}

			if (instruction->instruction_parameters[0].parameter_type==P_REGISTER
				&& instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A1)
			{
				w_as_scratch_register();
			} else {
				if (intel_asm)
					fprintf (assembly_file,"qword ptr ");
				if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT
				&& instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A1)
				{
					w_as_indirect (instruction->instruction_parameters[0].parameter_offset,REGISTER_O0);
				} else
					w_as_parameter (&instruction->instruction_parameters[0]);
			}
			w_as_newline();
		
			w_as_movq_register_register_newline (REGISTER_O0,REGISTER_A1);
			break;
		case REGISTER_A1:
			w_as_movq_register_register_newline (REGISTER_D0,REGISTER_O0);
	
			w_as_movq_register_register_newline (REGISTER_A1,REGISTER_D0);
	
			if (unsigned_div){
				w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);
				w_as_opcode (intel_asm ? "div" : "divq");
			} else {
				w_as_instruction_without_parameters ("cqo");
				w_as_opcode (intel_asm ? "idiv" : "idivq");
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
					fprintf (assembly_file,"qword ptr ");
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
	
			w_as_movq_register_register_newline (REGISTER_D0,REGISTER_A1);
		
			w_as_movq_register_register_newline (REGISTER_O0,REGISTER_D0);
			break;
		default:
			w_as_movq_register_register_newline (REGISTER_A1,REGISTER_O0);
	
			w_as_opcode_register_register_newline ("xchg",REGISTER_D0,d_reg);
	
			if (unsigned_div){
				w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);
				w_as_opcode (intel_asm ? "div" : "divq");
			} else {
				w_as_instruction_without_parameters ("cqo");
				w_as_opcode (intel_asm ? "idiv" : "idivq");
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
					fprintf (assembly_file,"qword ptr ");
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
		
			w_as_movq_register_register_newline (REGISTER_O0,REGISTER_A1);
	}
}

static void w_as_rem_instruction (struct instruction *instruction,int unsigned_rem)
{
	int d_reg;

	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE && unsigned_rem==0){
		int log2i;
		int_64 i;
		
		i=instruction->instruction_parameters[0].parameter_data.imm;
		
		if (i<0 && i!=0x8000000000000000ll)
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
		
		w_as_movq_register_register_newline (d_reg,REGISTER_O0);

		if (log2i==1){
			w_as_opcode ("and");
			w_as_immediate_register_newline (1,d_reg);

			w_as_opcode ("sar");
			w_as_immediate_register_newline (63,REGISTER_O0);

			w_as_opcode_register_register_newline ("xor",REGISTER_O0,d_reg);
		} else {
			w_as_opcode ("sar");
			w_as_immediate_register_newline (63,REGISTER_O0);

			w_as_opcode_register_register_newline ("add",REGISTER_O0,d_reg);

			if (log2i<32){
				w_as_opcode ("and");
				w_as_immediate_register_newline ((1<<log2i)-1,REGISTER_O0);

				w_as_opcode ("and");
				w_as_immediate_register_newline ((1<<log2i)-1,d_reg);
			} else {
				w_as_opcode ("shr");
				w_as_immediate_register_newline (64-log2i,REGISTER_O0);

				w_as_opcode ("shl");
				w_as_immediate_register_newline (64-log2i,d_reg);			

				w_as_opcode ("shr");
				w_as_immediate_register_newline (64-log2i,d_reg);			
			}
		}
		
		w_as_opcode_register_register_newline ("sub",REGISTER_O0,d_reg);

		return;
	}

	switch (d_reg){
		case REGISTER_D0:
			w_as_movq_register_register_newline (REGISTER_A1,REGISTER_O0);

			if (unsigned_rem){
				w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);
				w_as_opcode (intel_asm ? "div" : "divq");
			} else {
				w_as_instruction_without_parameters ("cqo");
				w_as_opcode (intel_asm ? "idiv" : "idivq");
			}

			if (instruction->instruction_parameters[0].parameter_type==P_REGISTER
				&& instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A1)
			{
				w_as_scratch_register();
			} else {
				if (intel_asm)
					fprintf (assembly_file,"qword ptr ");
				if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT
				&& instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A1)
				{
					w_as_indirect (instruction->instruction_parameters[0].parameter_offset,REGISTER_O0);
				} else
					w_as_parameter (&instruction->instruction_parameters[0]);
			}
			w_as_newline();

			w_as_movq_register_register_newline (REGISTER_A1,REGISTER_D0);

			w_as_movq_register_register_newline (REGISTER_O0,REGISTER_A1);
	
			break;		
		case REGISTER_A1:
			w_as_movq_register_register_newline (REGISTER_D0,REGISTER_O0);
	
			w_as_movq_register_register_newline (REGISTER_A1,REGISTER_D0);
	
			if (unsigned_rem){
				w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);
				w_as_opcode (intel_asm ? "div" : "divq");
			} else {
				w_as_instruction_without_parameters ("cqo");
				w_as_opcode (intel_asm ? "idiv" : "idivq");
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
					fprintf (assembly_file,"qword ptr ");
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

			w_as_movq_register_register_newline (REGISTER_O0,REGISTER_D0);
			break;
		default:	
			w_as_movq_register_register_newline (REGISTER_A1,REGISTER_O0);

			w_as_opcode_register_register_newline ("xchg",REGISTER_D0,d_reg);
	
			if (unsigned_rem){
				w_as_opcode_register_register_newline ("xor",REGISTER_A1,REGISTER_A1);
				w_as_opcode (intel_asm ? "div" : "divq");
			} else {
				w_as_instruction_without_parameters ("cqo");	
				w_as_opcode (intel_asm ? "idiv" : "idivq");
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
					fprintf (assembly_file,"qword ptr ");
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

			w_as_movq_register_register_newline (d_reg,REGISTER_D0);

			w_as_movq_register_register_newline (REGISTER_A1,d_reg);

			w_as_movq_register_register_newline (REGISTER_O0,REGISTER_A1);
	}
}

static void w_as_2movq_registers (int reg1,int reg2,int reg3)
{
	w_as_movq_register_register_newline (reg2,reg3);
	w_as_movq_register_register_newline (reg1,reg2);
}

static void w_as_3movq_registers (int reg1,int reg2,int reg3,int reg4)
{
	w_as_movq_register_register_newline (reg3,reg4);
	w_as_movq_register_register_newline (reg2,reg3);
	w_as_movq_register_register_newline (reg1,reg2);
}

static void w_as_mulud_instruction (struct instruction *instruction)
{
	int reg_1,reg_2;
	
	reg_1=instruction->instruction_parameters[0].parameter_data.reg.r;
	reg_2=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (reg_2==REGISTER_D0){
		if (reg_1==REGISTER_A1){
			w_as_opcode_register_newline ("mul",reg_1);
		} else {
			w_as_movq_register_register_newline (REGISTER_A1,REGISTER_O0);
			w_as_opcode_register_newline ("mul",reg_1);
			w_as_2movq_registers (REGISTER_O0,REGISTER_A1,reg_1);
		}
	} else if (reg_1==REGISTER_A1){
		w_as_2movq_registers (reg_2,REGISTER_D0,REGISTER_O0);
		w_as_opcode_register_newline ("mul",reg_1);
		w_as_2movq_registers (REGISTER_O0,REGISTER_D0,reg_2);
	} else if (reg_1==REGISTER_D0){
		if (reg_2==REGISTER_A1){
			w_as_opcode_register_newline ("mul",REGISTER_A1);
			w_as_opcode_register_register_newline ("xchg",REGISTER_A1,REGISTER_D0);
		} else {
			w_as_movq_register_register_newline (REGISTER_A1,REGISTER_O0);
			w_as_opcode_register_newline ("mul",reg_2);
			w_as_3movq_registers (REGISTER_O0,REGISTER_A1,REGISTER_D0,reg_2);
		}
	} else if (reg_2==REGISTER_A1){
		w_as_2movq_registers (reg_2,REGISTER_D0,REGISTER_O0);		
		w_as_opcode_register_newline ("mul",reg_1);
		w_as_3movq_registers (REGISTER_O0,REGISTER_D0,REGISTER_A1,reg_1);
	} else {
		w_as_opcode_register_register_newline ("xchg",reg_2,REGISTER_D0);
		w_as_movq_register_register_newline (REGISTER_A1,REGISTER_O0);
		w_as_opcode_register_newline ("mul",reg_1);
		w_as_opcode_register_register_newline ("xchg",reg_2,REGISTER_D0);
		w_as_2movq_registers (REGISTER_O0,REGISTER_A1,reg_1);
	}
}

static void w_as_divdu_instruction (struct instruction *instruction)
{
	int reg_1,reg_2,reg_3;
	
	reg_1=instruction->instruction_parameters[0].parameter_data.reg.r;
	reg_2=instruction->instruction_parameters[1].parameter_data.reg.r;
	reg_3=instruction->instruction_parameters[2].parameter_data.reg.r;

	if (reg_1==REGISTER_D0){
		if (reg_3==REGISTER_D0){
			if (reg_2==REGISTER_A1)
				w_as_opcode_register_newline ("div",reg_1);
			else {
				w_as_2movq_registers (reg_2,REGISTER_A1,REGISTER_O0);
				w_as_opcode_register_newline ("div",reg_1);
				w_as_2movq_registers (REGISTER_O0,REGISTER_A1,reg_2);
			}
		} else if (reg_3==REGISTER_A1){
			if (reg_2==REGISTER_D0){
				w_as_opcode_register_register_newline ("xchg",REGISTER_A1,REGISTER_D0);
				w_as_opcode_register_newline ("div",REGISTER_A1);
				w_as_opcode_register_register_newline ("xchg",REGISTER_A1,REGISTER_D0);							
			} else {
				w_as_3movq_registers (reg_2,REGISTER_A1,REGISTER_D0,REGISTER_O0);
				w_as_opcode_register_newline ("div",REGISTER_O0);
				w_as_3movq_registers (REGISTER_O0,REGISTER_D0,REGISTER_A1,reg_2);
			}
		} else {
			if (reg_2==REGISTER_A1){
				w_as_2movq_registers (reg_3,REGISTER_D0,REGISTER_O0);
				w_as_opcode_register_newline ("div",REGISTER_O0);
				w_as_2movq_registers (REGISTER_O0,REGISTER_D0,reg_3);
			} else if (reg_2==REGISTER_D0){
				w_as_3movq_registers (reg_3,REGISTER_D0,REGISTER_A1,REGISTER_O0);
				w_as_opcode_register_newline ("div",REGISTER_A1);
				w_as_3movq_registers (REGISTER_O0,REGISTER_A1,REGISTER_D0,reg_3);
			} else {
				w_as_opcode_register_register_newline ("xchg",reg_3,REGISTER_D0);
				w_as_2movq_registers (reg_2,REGISTER_A1,REGISTER_O0);
				w_as_opcode_register_newline ("div",reg_3);
				w_as_2movq_registers (REGISTER_O0,REGISTER_A1,reg_2);
				w_as_opcode_register_register_newline ("xchg",reg_3,REGISTER_D0);
			}
		}
	} else if (reg_1==REGISTER_A1){
		if (reg_2==REGISTER_A1){
			if (reg_3==REGISTER_D0)
				w_as_opcode_register_newline ("div",reg_1);
			else {
				w_as_2movq_registers (reg_3,REGISTER_D0,REGISTER_O0);
				w_as_opcode_register_newline ("div",reg_1);
				w_as_2movq_registers (REGISTER_O0,REGISTER_D0,reg_3);
			}
		} else if (reg_2==REGISTER_D0){
			if (reg_3==REGISTER_A1){
				w_as_opcode_register_register_newline ("xchg",REGISTER_A1,REGISTER_D0);
				w_as_opcode_register_newline ("div",REGISTER_D0);
				w_as_opcode_register_register_newline ("xchg",REGISTER_A1,REGISTER_D0);							
			} else {
				w_as_3movq_registers (reg_3,REGISTER_D0,REGISTER_A1,REGISTER_O0);
				w_as_opcode_register_newline ("div",REGISTER_O0);
				w_as_3movq_registers (REGISTER_O0,REGISTER_A1,REGISTER_D0,reg_3);
			}
		} else {
			if (reg_3==REGISTER_D0){
				w_as_2movq_registers (reg_2,REGISTER_A1,REGISTER_O0);
				w_as_opcode_register_newline ("div",REGISTER_O0);
				w_as_2movq_registers (REGISTER_O0,REGISTER_A1,reg_2);
			} else if (reg_3==REGISTER_A1){
				w_as_3movq_registers (reg_2,REGISTER_A1,REGISTER_D0,REGISTER_O0);
				w_as_opcode_register_newline ("div",REGISTER_D0);
				w_as_3movq_registers (REGISTER_O0,REGISTER_D0,REGISTER_A1,reg_2);
			} else {
				w_as_opcode_register_register_newline ("xchg",reg_2,REGISTER_A1);
				w_as_2movq_registers (reg_3,REGISTER_D0,REGISTER_O0);
				w_as_opcode_register_newline ("div",reg_2);
				w_as_2movq_registers (REGISTER_O0,REGISTER_D0,reg_3);
				w_as_opcode_register_register_newline ("xchg",reg_2,REGISTER_A1);
			}
		}
	} else {
		if (reg_3==REGISTER_D0){
			if (reg_2==REGISTER_A1){
				w_as_opcode_register_newline ("div",reg_1);
			} else {
				w_as_2movq_registers (reg_2,REGISTER_A1,REGISTER_O0);
				w_as_opcode_register_newline ("div",reg_1);
				w_as_2movq_registers (REGISTER_O0,REGISTER_A1,reg_2);
			}
		} else if (reg_2==REGISTER_A1){
			w_as_2movq_registers (reg_3,REGISTER_D0,REGISTER_O0);
			w_as_opcode_register_newline ("div",reg_1);
			w_as_2movq_registers (REGISTER_O0,REGISTER_D0,reg_3);
		} else if (reg_2==REGISTER_D0){
			if (reg_3==REGISTER_A1){
				w_as_opcode_register_register_newline ("xchg",REGISTER_A1,REGISTER_D0);
				w_as_opcode_register_newline ("div",reg_1);
				w_as_opcode_register_register_newline ("xchg",REGISTER_A1,REGISTER_D0);
			} else {
				w_as_3movq_registers (reg_3,REGISTER_D0,REGISTER_A1,REGISTER_O0);
				w_as_opcode_register_newline ("div",reg_1);
				w_as_3movq_registers (REGISTER_O0,REGISTER_A1,REGISTER_D0,reg_3);
			}
		} else if (reg_3==REGISTER_A1){
			w_as_3movq_registers (reg_2,REGISTER_A1,REGISTER_D0,REGISTER_O0);
			w_as_opcode_register_newline ("div",reg_1);
			w_as_3movq_registers (REGISTER_O0,REGISTER_D0,REGISTER_A1,reg_2);
		} else {
			w_as_opcode_register_register_newline ("xchg",reg_3,REGISTER_D0);
			w_as_2movq_registers (reg_2,REGISTER_A1,REGISTER_O0);
			w_as_opcode_register_newline ("div",reg_1);
			w_as_2movq_registers (REGISTER_O0,REGISTER_A1,reg_2);
			w_as_opcode_register_register_newline ("xchg",reg_3,REGISTER_D0);
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
			
				w_as_opcode (intel_directives ? "dq" : ".double");
# ifdef MACH_O64
				fprintf (assembly_file,"%.20e",*float_constant->float_constant_r_p);
# else
				fprintf (assembly_file,intel_asm ? "%.20e" : "0r%.20e",*float_constant->float_constant_r_p);
# endif
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
	
		w_as_opcode (intel_directives ? "dq" : ".double");
# ifdef MACH_O64
		fprintf (assembly_file,"%.20e",*r_p);
# else
		fprintf (assembly_file,intel_asm ? "%.20e" : "0r%.20e",*r_p);
# endif
		w_as_newline();
	
		w_as_to_code_section();
	}
#endif

static void w_as_opcode_parameter_newline (char *opcode,struct parameter *parameter_p)
{
	switch (parameter_p->parameter_type){
		case P_F_IMMEDIATE:
		{
			int label_number;
			
			label_number=next_label_id++;

			w_as_float_constant (label_number,parameter_p->parameter_data.r);

#ifndef MACH_O64
			fprintf (assembly_file,intel_asm ? "\t%s\tqword ptr i_%d" : "\t%sl\ti_%d",opcode,label_number);
#else
			fprintf (assembly_file,intel_asm ? "\t%s\tqword ptr i_%d[rip]" : "\t%sl\ti_%d",opcode,label_number);
#endif
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

static void w_as_dyadic_float_instruction (struct instruction *instruction,char *opcode)
{
	int d_freg;
	
	d_freg=instruction->instruction_parameters[1].parameter_data.reg.r;

	switch (instruction->instruction_parameters[0].parameter_type){
		case P_F_IMMEDIATE:
		{
			int label_number;
			
			label_number=next_label_id++;

			w_as_float_constant (label_number,instruction->instruction_parameters[0].parameter_data.r);

			w_as_opcode (opcode);
			if (intel_asm){
				w_as_fp_register (d_freg);
				w_as_comma();
#ifndef MACH_O64
				fprintf (assembly_file,"qword ptr i_%d",label_number);
#else
				fprintf (assembly_file,"qword ptr i_%d[rip]",label_number);
#endif
			} else {
#ifndef MACH_O64
				fprintf (assembly_file,"i_%d",label_number);
#else
				fprintf (assembly_file,"i_%d(%%rip)",label_number);
#endif			
				w_as_comma();
				w_as_fp_register (d_freg);
			}
			break;
		}
		case P_INDIRECT:
			w_as_opcode (opcode);
			if (intel_asm){
				w_as_fp_register (d_freg);
				w_as_comma();
			}
			w_as_indirect (instruction->instruction_parameters[0].parameter_offset,instruction->instruction_parameters[0].parameter_data.reg.r);
			if (!intel_asm){
				w_as_comma();
				w_as_fp_register (d_freg);
			}
			break;
		case P_INDEXED:
			w_as_opcode (opcode);
			if (intel_asm){
				w_as_fp_register (d_freg);
				w_as_comma();
			}
			w_as_indexed (instruction->instruction_parameters[0].parameter_offset,instruction->instruction_parameters[0].parameter_data.ir);
			if (!intel_asm){
				w_as_comma();
				w_as_fp_register (d_freg);
			}
			break;
		case P_F_REGISTER:
			w_as_opcode (opcode);
			if (intel_asm){
				w_as_fp_register (d_freg);
				w_as_comma();
			}
			w_as_fp_register (instruction->instruction_parameters[0].parameter_data.reg.r);
			if (!intel_asm){
				w_as_comma();
				w_as_fp_register (d_freg);			
			}
			break;
		default:
			internal_error_in_function ("w_as_dyadic_float_instruction");
			return;
	}
	w_as_newline();
}

static int sign_real_mask_imported=0;

static void w_as_float_neg_instruction (struct instruction *instruction)
{
	int d_freg;
	
	d_freg=instruction->instruction_parameters[1].parameter_data.reg.r;
	
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_F_IMMEDIATE:
		{
			int label_number=next_label_id++;

			w_as_float_constant (label_number,instruction->instruction_parameters[0].parameter_data.r);
			
			w_as_opcode (sse_128 ? "movsd" : "movlpd");
			if (intel_asm){
				w_as_fp_register (d_freg);
				w_as_comma();
#ifndef MACH_O64
				fprintf (assembly_file,"qword ptr i_%d",label_number);
#else
				fprintf (assembly_file,"qword ptr i_%d[rip]",label_number);
#endif
			} else {
#ifndef MACH_O64
				fprintf (assembly_file,"i_%d",label_number);
#else
				fprintf (assembly_file,"i_%d(%%rip)",label_number);
#endif			
				w_as_comma();
				w_as_fp_register (d_freg);
			}
			w_as_newline();
			break;
		}
		case P_INDIRECT:
			w_as_opcode (sse_128 ? "movsd" : "movlpd");
			if (intel_asm){
				w_as_fp_register (d_freg);
				w_as_comma();
				fprintf (assembly_file,"qword ptr ");
			}
			w_as_indirect (instruction->instruction_parameters[0].parameter_offset,instruction->instruction_parameters[0].parameter_data.reg.r);
			if (!intel_asm){
				w_as_comma();
				w_as_fp_register (d_freg);
			}
			w_as_newline();
			break;
		case P_INDEXED:
			w_as_opcode (sse_128 ? "movsd" : "movlpd");
			if (intel_asm){
				w_as_fp_register (d_freg);
				w_as_comma();
				fprintf (assembly_file,"qword ptr ");
			}
			w_as_indexed (instruction->instruction_parameters[0].parameter_offset,instruction->instruction_parameters[0].parameter_data.ir);
			if (!intel_asm){
				w_as_comma();
				w_as_fp_register (d_freg);
			}
			w_as_newline();
			break;
		case P_F_REGISTER:
			if (instruction->instruction_parameters[0].parameter_data.reg.r!=d_freg){
				w_as_opcode (sse_128 ? "movapd" : "movsd");
				if (intel_asm){
					w_as_fp_register (d_freg);
					w_as_comma();
				}
				w_as_fp_register (instruction->instruction_parameters[0].parameter_data.reg.r);
				if (!intel_asm){
					w_as_comma();
					w_as_fp_register (d_freg);
				}
				w_as_newline();
			}
			break;
		default:
			internal_error_in_function ("w_as_float_neg_instruction");
			return;
	}
	
	if (!sign_real_mask_imported){
#ifndef MACH_O64
		w_as_opcode ("extrn");
		fprintf (assembly_file,"sign_real_mask:near");
#else
		w_as_opcode (".globl");
		fprintf (assembly_file,"sign_real_mask");
#endif
		w_as_newline();
		
		sign_real_mask_imported=1;
	}

	w_as_opcode ("xorpd");
	if (intel_asm){
		w_as_fp_register (d_freg);
		w_as_comma();
#ifndef MACH_O64
		fprintf (assembly_file,"oword ptr sign_real_mask");
#else
		fprintf (assembly_file,"oword ptr sign_real_mask[rip]");
#endif
	} else {
#ifndef MACH_O64
		fprintf (assembly_file,"sign_real_mask");
#else
		fprintf (assembly_file,"sign_real_mask(%%rip)");
#endif	
		w_as_comma();
		w_as_fp_register (d_freg);
	}
	w_as_newline();
}

static int abs_real_mask_imported=0;

static void w_as_float_abs_instruction (struct instruction *instruction)
{
	int d_freg;
	
	d_freg=instruction->instruction_parameters[1].parameter_data.reg.r;
	
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_F_IMMEDIATE:
		{
			int label_number=next_label_id++;

			w_as_float_constant (label_number,instruction->instruction_parameters[0].parameter_data.r);
			
			w_as_opcode (sse_128 ? "movsd" : "movlpd");
			if (intel_asm){
				w_as_fp_register (d_freg);
				w_as_comma();
#ifndef MACH_O64
				fprintf (assembly_file,"qword ptr i_%d",label_number);
#else
				fprintf (assembly_file,"qword ptr i_%d[rip]",label_number);
#endif
			} else {
#ifndef MACH_O64
				fprintf (assembly_file,"i_%d",label_number);
#else
				fprintf (assembly_file,"i_%d(%%rip)",label_number);
#endif
				w_as_comma();
				w_as_fp_register (d_freg);
			}
			w_as_newline();
			break;
		}
		case P_INDIRECT:
			w_as_opcode (sse_128 ? "movsd" : "movlpd");
			if (intel_asm){
				w_as_fp_register (d_freg);
				w_as_comma();
				fprintf (assembly_file,"qword ptr ");
			}
			w_as_indirect (instruction->instruction_parameters[0].parameter_offset,instruction->instruction_parameters[0].parameter_data.reg.r);
			if (!intel_asm){
				w_as_comma();
				w_as_fp_register (d_freg);
			}
			w_as_newline();
			break;
		case P_INDEXED:
			w_as_opcode (sse_128 ? "movsd" : "movlpd");
			if (intel_asm){
				w_as_fp_register (d_freg);
				w_as_comma();
				fprintf (assembly_file,"qword ptr ");
			}
			w_as_indexed (instruction->instruction_parameters[0].parameter_offset,instruction->instruction_parameters[0].parameter_data.ir);
			if (!intel_asm){
				w_as_comma();
				w_as_fp_register (d_freg);
			}			
			w_as_newline();
			break;
		case P_F_REGISTER:
			if (instruction->instruction_parameters[0].parameter_data.reg.r!=d_freg){
				w_as_opcode (sse_128 ? "movapd" : "movsd");
				if (intel_asm){
					w_as_fp_register (d_freg);
					w_as_comma();
				}
				w_as_fp_register (instruction->instruction_parameters[0].parameter_data.reg.r);
				if (!intel_asm){
					w_as_comma();
					w_as_fp_register (d_freg);
				}
				w_as_newline();
			}
			break;
		default:
			internal_error_in_function ("w_as_float_abs_instruction");
			return;
	}
	
	if (!abs_real_mask_imported){
#ifndef MACH_O64
		w_as_opcode ("extrn");
		fprintf (assembly_file,"abs_real_mask:near");
#else
		w_as_opcode (".globl");
		fprintf (assembly_file,"abs_real_mask");
#endif
		w_as_newline();
		abs_real_mask_imported=1;
	}

	w_as_opcode ("andpd");
	if (intel_asm){
		w_as_fp_register (d_freg);
		w_as_comma();
#ifndef MACH_O64
		fprintf (assembly_file,"oword ptr abs_real_mask");
#else
		fprintf (assembly_file,"oword ptr abs_real_mask[rip]");
#endif
	} else {
#ifndef MACH_O64
		fprintf (assembly_file,"abs_real_mask");
#else
		fprintf (assembly_file,"abs_real_mask(%%rip)");
#endif
		w_as_comma();
		w_as_fp_register (d_freg);
	}
	w_as_newline();
}

static void w_as_fmove_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_F_REGISTER:
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_F_REGISTER:
					w_as_opcode (sse_128 ? "movapd" : "movsd");
					if (intel_asm){
						w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r);
						w_as_comma();
					}
					w_as_fp_register (instruction->instruction_parameters[0].parameter_data.reg.r);
					if (!intel_asm){
						w_as_comma();
						w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r);
					}
					break;
				case P_INDIRECT:
					w_as_opcode (sse_128 ? "movsd" : "movlpd");
					if (intel_asm){
						w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r);
						w_as_comma();
						fprintf (assembly_file,"qword ptr ");
					}
					w_as_indirect (instruction->instruction_parameters[0].parameter_offset,
								   instruction->instruction_parameters[0].parameter_data.reg.r);
					if (!intel_asm){
						w_as_comma();
						w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r);
					}
					break;
				case P_INDEXED:
					w_as_opcode (sse_128 ? "movsd" : "movlpd");
					if (intel_asm){
						w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r);
						w_as_comma();
						fprintf (assembly_file,"qword ptr ");
					}
					w_as_indexed (instruction->instruction_parameters[0].parameter_offset,
								  instruction->instruction_parameters[0].parameter_data.ir);
					if (!intel_asm){
						w_as_comma();
						w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r);
					}
					break;
				case P_F_IMMEDIATE:
				{
					int label_number=next_label_id++;

					w_as_float_constant (label_number,instruction->instruction_parameters[0].parameter_data.r);
			
					w_as_opcode (sse_128 ? "movsd" : "movlpd");
					if (intel_asm){
						w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r);
						w_as_comma();
#ifndef MACH_O64
						fprintf (assembly_file,"qword ptr i_%d",label_number);
#else
						fprintf (assembly_file,"qword ptr i_%d[rip]",label_number);
#endif
					} else {
#ifndef MACH_O64
						fprintf (assembly_file,"i_%d",label_number);
#else
						fprintf (assembly_file,"i_%d(%%rip)",label_number);
#endif
						w_as_comma();
						w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r);
					}
					break;
				}
				default:
					internal_error_in_function ("w_as_fmove_instruction");
					return;
			}
			w_as_newline();
			return;
		case P_INDIRECT:
		case P_INDEXED:
			if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
				int s_freg;
				
				s_freg=instruction->instruction_parameters[0].parameter_data.reg.r;
				
				w_as_opcode ("movsd");
				if (intel_asm)
					fprintf (assembly_file,"qword ptr ");
				else {
					w_as_fp_register (s_freg);
					w_as_comma();
				}
				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT)
					w_as_indirect (instruction->instruction_parameters[1].parameter_offset,
								   instruction->instruction_parameters[1].parameter_data.reg.r);
				else
					w_as_indexed (instruction->instruction_parameters[1].parameter_offset,
								  instruction->instruction_parameters[1].parameter_data.ir);
				
				if (intel_asm){
					w_as_comma();
					w_as_fp_register (s_freg);
				}
				w_as_newline();
				return;
			}
	}
	internal_error_in_function ("w_as_fmove_instruction");
	return;
}

static void w_as_floads_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_F_REGISTER:
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_INDIRECT:
					w_as_opcode ("cvtss2sd");
					w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_comma();
					if (intel_asm)
						fprintf (assembly_file,"dword ptr ");
					w_as_indirect (instruction->instruction_parameters[0].parameter_offset,
								   instruction->instruction_parameters[0].parameter_data.reg.r);
					break;
				case P_INDEXED:
					w_as_opcode ("cvtss2sd");
					w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_comma();
					if (intel_asm)
						fprintf (assembly_file,"dword ptr ");
					w_as_indexed (instruction->instruction_parameters[0].parameter_offset,
								  instruction->instruction_parameters[0].parameter_data.ir);
					break;
				default:
					internal_error_in_function ("w_as_floads_instruction");
					return;
			}
			w_as_newline();
			return;
	}
	internal_error_in_function ("w_as_floads_instruction");
	return;
}

static void w_as_fmoves_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_INDIRECT:
		case P_INDEXED:
			if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
				int s_freg;
				
				s_freg=instruction->instruction_parameters[0].parameter_data.reg.r;
				
				w_as_opcode ("movss");
				if (intel_asm)
					fprintf (assembly_file,"dword ptr ");
				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT)
					w_as_indirect (instruction->instruction_parameters[1].parameter_offset,
								   instruction->instruction_parameters[1].parameter_data.reg.r);
				else
					w_as_indexed (instruction->instruction_parameters[1].parameter_offset,
								  instruction->instruction_parameters[1].parameter_data.ir);
					
				w_as_comma();
				w_as_fp_register (s_freg);
				w_as_newline();
				return;
			}
	}
	internal_error_in_function ("w_as_fmoves_instruction");
}

static void w_as_fmovel_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
		if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
			w_as_opcode (intel_asm ? "cvtsd2si" : "cvtsd2siq");
			if (intel_asm)
				w_as_register_comma (instruction->instruction_parameters[1].parameter_data.reg.r);
			w_as_fp_register (instruction->instruction_parameters[0].parameter_data.reg.r);
			if (!intel_asm)
				w_as_comma_register (instruction->instruction_parameters[1].parameter_data.reg.r);			
			w_as_newline();
		} else
			internal_error_in_function ("w_as_fmovel_instruction");
	} else {
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_REGISTER:
				w_as_opcode (intel_asm ? "cvtsi2sd" : "cvtsi2sdq");
				if (!intel_asm)
					w_as_register_comma (instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r);
				if (intel_asm)
					w_as_comma_register (instruction->instruction_parameters[0].parameter_data.reg.r);
				w_as_newline();
				break;
			case P_INDIRECT:
				w_as_opcode (intel_asm ? "cvtsi2sd" : "cvtsi2sdq");
				if (intel_asm){
					w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_comma();
				}
				w_as_indirect (instruction->instruction_parameters[0].parameter_offset,
							   instruction->instruction_parameters[0].parameter_data.reg.r);
				if (!intel_asm){
					w_as_comma();
					w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r);
				}
				w_as_newline();
				break;
			case P_INDEXED:
				w_as_opcode (intel_asm ? "cvtsi2sd" : "cvtsi2sdq");
				if (intel_asm){
					w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_comma();
				}
				w_as_indexed (instruction->instruction_parameters[0].parameter_offset,
							  instruction->instruction_parameters[0].parameter_data.ir);
				if (!intel_asm){
					w_as_comma();
					w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r);
				}
				w_as_newline();
				break;
			case P_IMMEDIATE:
			{
				int label_number=next_label_id++;

				w_as_to_data_section();

				w_as_align (2);

				w_as_define_internal_data_label (label_number);

				w_as_opcode (intel_directives ? "dd" : ".long");
				fprintf (assembly_file,"%d",instruction->instruction_parameters[0].parameter_data.i);
				w_as_newline();

				w_as_to_code_section();

				w_as_opcode (intel_asm ? "cvtsi2sd" : "cvtsi2sdq");
				if (intel_asm){
					w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r);
					w_as_comma();
					fprintf (assembly_file,"qword ptr i_%d",label_number);
				} else {
					fprintf (assembly_file,"i_%d",label_number);				
					w_as_comma();
					w_as_fp_register (instruction->instruction_parameters[1].parameter_data.reg.r);
				}
				w_as_newline();
				break;
			}
			default:
				internal_error_in_function ("w_as_fmovel_instruction");
		}
	}
}

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

#ifdef THREAD64
static void w_as_ldtlsp_instruction (struct instruction *instruction)
{
	int reg;

	reg=instruction->instruction_parameters[1].parameter_data.reg.r;
	
	w_as_opcode ("mov");
	w_as_register_comma (reg);
	fprintf (assembly_file,"qword ptr ");
	if (instruction->instruction_parameters[0].parameter_data.l->label_number!=0)
		w_as_local_label (instruction->instruction_parameters[0].parameter_data.l->label_number);
	else
		w_as_label (instruction->instruction_parameters[0].parameter_data.l->label_name);
	w_as_newline();
		
	w_as_opcode ("mov");
	w_as_register_comma (reg);
	fprintf (assembly_file,"qword ptr gs:[1480h+");
	w_as_register (reg);
	fprintf (assembly_file,"*8]");	
	w_as_newline();
}
#endif

static void w_as_instructions (register struct instruction *instruction)
{
	while (instruction!=NULL){
		switch (instruction->instruction_icode){
			case IMOVE:
				w_as_move_instruction (instruction,SIZE_OBYTE);
				break;
			case ILEA:
				w_as_lea_instruction (instruction);
				break;
			case IADD:
				w_as_dyadic_instruction (instruction,intel_asm ? "add" : "addq");
				break;
			case ISUB:
				w_as_dyadic_instruction (instruction,intel_asm ? "sub" : "subq");
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
				w_as_dyadic_instruction (instruction,intel_asm ? "imul" : "imulq");
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
				w_as_dyadic_instruction (instruction,intel_asm ? "and" : "andq");
				break;
			case IOR:
				w_as_dyadic_instruction (instruction,intel_asm ? "or" : "orq");
				break;
			case IEOR:
				w_as_dyadic_instruction (instruction,intel_asm ? "xor" : "xorq");
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
				w_as_cmpw_instruction (instruction);
				break;
#endif
			case ITST:
				w_as_tst_instruction (instruction);
				break;
			case IBTST:
				w_as_btst_instruction (instruction);
				break;
			case ILOADSQB:
				w_as_loadsqb_instruction (instruction);
				break;
			case IMOVEB:
				w_as_move_instruction (instruction,SIZE_BYTE);
				break;
			case IMOVEDB:
				w_as_move_instruction (instruction,SIZE_DBYTE);
				break;
			case IMOVEQB:
				w_as_move_instruction (instruction,SIZE_QBYTE);
				break;
			case IEXG:
				w_as_dyadic_instruction (instruction,"xchg");
				break;
			case INEG:
				w_as_monadic_instruction (instruction,intel_asm ? "neg" : "negq");
				break;
			case INOT:
				w_as_monadic_instruction (instruction,intel_asm ? "not" : "notq");
				break;
			case ICLZB:
				w_as_clzb_instruction (instruction);
				break;
			case IADC:
				w_as_dyadic_instruction (instruction,"adc");
				break;
			case ISBB:
				w_as_dyadic_instruction (instruction,intel_asm ? "sbb" : "sbbq");
				break;
			case IMULUD:
				w_as_mulud_instruction (instruction);
				break;
			case IDIVDU:
				w_as_divdu_instruction (instruction);
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
				w_as_fmove_instruction (instruction);
				break;
			case IFADD:
				w_as_dyadic_float_instruction (instruction,"addsd");
				break;
			case IFSUB:
				w_as_dyadic_float_instruction (instruction,"subsd");
				break;
			case IFCMP:
				w_as_dyadic_float_instruction (instruction,"comisd");
				break;
			case IFDIV:
				w_as_dyadic_float_instruction (instruction,"divsd");
				break;
			case IFMUL:
				w_as_dyadic_float_instruction (instruction,"mulsd");
				break;
			case IFBEQ:
				w_as_float_branch_instruction (instruction,0);
				break;
			case IFBGE:
				w_as_float_branch_instruction (instruction,5);
				break;
			case IFBGT:
				w_as_float_branch_instruction (instruction,2);
				break;
			case IFBLE:
				w_as_float_branch_instruction (instruction,4);
				break;
			case IFBLT:
				w_as_float_branch_instruction (instruction,1);
				break;
			case IFBNE:
				w_as_float_branch_instruction (instruction,3);
				break;
			case IFBNEQ:
				w_as_float_branch_not_instruction (instruction,0);
				break;
			case IFBNGE:
				w_as_float_branch_not_instruction (instruction,5);
				break;
			case IFBNGT:
				w_as_float_branch_not_instruction (instruction,2);
				break;
			case IFBNLE:
				w_as_float_branch_not_instruction (instruction,4);
				break;
			case IFBNLT:
				w_as_float_branch_not_instruction (instruction,1);
				break;
			case IFBNNE:
				w_as_float_branch_not_instruction (instruction,3);
				break;
			case IFMOVEL:
				w_as_fmovel_instruction (instruction);
				break;
			case IFSQRT:
				w_as_dyadic_float_instruction (instruction,"sqrtsd");
				break;
			case IFNEG:
				w_as_float_neg_instruction (instruction);
				break;
			case IFABS:
				w_as_float_abs_instruction (instruction);
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
			case IWORD:
				w_as_word_instruction (instruction);
				break;
			case IFLOADS:
				w_as_floads_instruction (instruction);
				break;
			case IFCVT2S:
				w_as_dyadic_float_instruction (instruction,"cvtsd2ss");
				break;
			case IFMOVES:
				w_as_fmoves_instruction (instruction);
				break;
			case IRTSI:
				w_as_rtsi_instruction (instruction);
				break;
#ifdef THREAD64
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
	w_as_opcode (intel_directives ? "dd" : ".long");
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

static void w_as_garbage_collect_test (struct basic_block *block)
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

	w_as_opcode (intel_asm ? "sub" : "subq");
	if (intel_asm)
		w_as_register_comma (REGISTER_R15);
	w_as_immediate (n_cells);
	if (!intel_asm)
		w_as_comma_register (REGISTER_R15);
	w_as_newline();	

	w_as_opcode ("jl");
	
	w_as_internal_label (label_id_1);
	w_as_newline ();
	
	w_as_define_internal_label (label_id_2);
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

static void w_as_labels (struct block_label *labels)
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
			w_as_opcode (intel_asm ? "cmp" : "cmpq");
			if (intel_asm)
				w_as_register_comma (A_STACK_POINTER);
			fputs (end_a_stack_label->label_name,assembly_file);
			if (!intel_asm)
				w_as_comma_register (A_STACK_POINTER);
		} else {
			w_as_opcode (intel_asm ? "lea" : "leaq");
			if (intel_asm)
				w_as_scratch_register_comma();
			w_as_indirect (block->block_a_stack_check_size,A_STACK_POINTER);
			if (!intel_asm)
				w_as_comma_scratch_register();
			w_as_newline();

			w_as_opcode (intel_asm ? "cmp" : "cmpq");
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
			w_as_opcode (intel_asm ? "cmp" : "cmpq");
			if (intel_asm)
				w_as_register_comma (B_STACK_POINTER);
			fputs (end_b_stack_label->label_name,assembly_file);
			if (!intel_asm)
				w_as_comma_register (B_STACK_POINTER);
		} else {
			w_as_opcode (intel_asm ? "lea" : "leaq");
			if (intel_asm)
				w_as_scratch_register_comma();
			w_as_indirect (block->block_b_stack_check_size,B_STACK_POINTER);
			if (!intel_asm)
				w_as_comma_scratch_register();
			w_as_newline();

			w_as_opcode (intel_asm ? "cmp" : "cmpq");
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

#ifdef  MACH_O64
	if (!intel_asm)
		fprintf (assembly_file,"#NO_APP\n");
#endif
}

#ifndef GENERATIONAL_GC
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
			w_as_register (REGISTER_A4);
			w_as_newline();
			
			w_as_opcode ("jmp");
			if (!intel_asm)
				putc ('*',assembly_file);
			w_as_register (REGISTER_D0);
			w_as_newline();
		} else {
			w_as_opcode_movl();
			w_as_immediate_label (label->label_ea_label->label_name);
			w_as_comma();
			w_as_register (REGISTER_D0);
			w_as_newline();
			
			w_as_opcode ("jmp");
			if (!intel_asm)
				putc ('*',assembly_file);
			w_as_register (REGISTER_D0);
			w_as_newline();
		
			w_as_space (5);
		}
			
		if (label->label_arity<0 || parallel_flag || module_info_flag){
			LABEL *descriptor_label;
			
			descriptor_label=label->label_descriptor;

			if (descriptor_label->label_id<0)
				descriptor_label->label_id=next_label_id++;
#ifdef MACH_O64
			w_as_label_minus_label_in_code_section (descriptor_label->label_name,new_label_name,-8);
#else
			w_as_label_in_code_section (descriptor_label->label_name);
#endif
		} else
			w_as_number_of_arguments (0);
	} else
	if (label->label_arity<0 || parallel_flag || module_info_flag){
		LABEL *descriptor_label;

		descriptor_label=label->label_descriptor;

		if (descriptor_label->label_id<0)
			descriptor_label->label_id=next_label_id++;

#ifdef MACH_O64
		w_as_label_minus_label_in_code_section (descriptor_label->label_name,new_label_name,-8);
#else
		w_as_label_in_code_section (descriptor_label->label_name);
#endif
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
#ifndef MACH_O64
		w_as_opcode ("extrn");
		fprintf (assembly_file,"%s:near",label->label_name);
#else
		w_as_opcode (".globl");
		fprintf (assembly_file,"%s",label->label_name);
#endif
		w_as_newline();
	}
	
	w_as_import_labels (label_node->label_node_left);
	w_as_import_labels (label_node->label_node_right);
}

static void w_as_profile_call (struct basic_block *block)
{
#ifdef MACH_O64
	w_as_lea_descriptor (block->block_profile_function_label,0,REGISTER_O0);
#else
	w_as_opcode_movl();
	if (intel_asm)
		w_as_scratch_register_comma();
	w_as_descriptor (block->block_profile_function_label,0);
	if (!intel_asm)
		w_as_comma_scratch_register();
	w_as_newline();
#endif
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
		w_as_opcode ("jmp");
		w_as_label (block->block_ea_label->label_name);
		w_as_newline();

		w_as_instruction_without_parameters ("nop");
		w_as_instruction_without_parameters ("nop");
		w_as_instruction_without_parameters ("nop");
		w_as_instruction_without_parameters ("nop");
		w_as_instruction_without_parameters ("nop");
	} else {
#ifdef MACH_O64
		if (intel_asm)
			att_syntax();
#endif
		w_as_opcode ("call");
		w_as_label (add_empty_node_labels[n_node_arguments]->label_name);
		w_as_newline();

		w_as_opcode ("jmp");
		w_as_label (block->block_ea_label->label_name);
		w_as_newline();
#ifdef MACH_O64
		if (intel_asm)
			intel_syntax();
#endif
	}

	w_as_instruction_without_parameters ("nop");
	w_as_instruction_without_parameters ("nop");
}
#endif

void write_assembly (VOID)
{
	struct basic_block *block;
	struct call_and_jump *call_and_jump;

	if (intel_asm){
#ifdef MACH_O64
		intel_syntax();
#endif
		w_as_import_labels (labels);
	}
	w_as_to_code_section();

#ifdef DATA_IN_CODE_SECTION
	float_constant_l=&first_float_constant;
	first_float_constant=NULL;
#endif

/*
#ifndef GENERATIONAL_GC
	w_as_indirect_node_entry_jumps (labels);
#endif
*/

	for_l (block,first_block,block_next){
		if (block->block_n_node_arguments>-100){
			w_as_align (2);

#ifdef GENERATIONAL_GC
				if (block->block_ea_label!=NULL){
					int n_node_arguments;
					extern LABEL *eval_fill_label,*eval_upd_labels[];
					
					n_node_arguments=block->block_n_node_arguments;
					
					if (n_node_arguments<-2)
						n_node_arguments=1;
					
					if (n_node_arguments>=0 && block->block_ea_label!=eval_fill_label){
						w_as_opcode_movl();
						w_as_immediate_label (eval_upd_labels[n_node_arguments]->label_name);
						fprintf (assembly_file,"_push");
						w_as_comma_register (REGISTER_D0);
						w_as_newline();
			
						w_as_opcode_movl();
						w_as_immediate_label (block->block_ea_label->label_name);
						w_as_comma(); w_as_register (REGISTER_A4); w_as_newline();
					
						w_as_opcode ("jmp");
						w_as_register (REGISTER_D0);
						w_as_newline();
					} else {
						w_as_opcode_movl();
						w_as_immediate_label (block->block_ea_label->label_name);
						fprintf (assembly_file,"_push");
						w_as_comma(); w_as_register (REGISTER_D0); w_as_newline();
					
						w_as_opcode ("jmp"); w_as_register (REGISTER_D0); w_as_newline();
					
						w_as_space (5);
					}
					
					if (block->block_descriptor!=NULL && (block->block_n_node_arguments<0 || parallel_flag || module_info_flag))
						w_as_label_in_code_section (block->block_descriptor->label_name);
					else
						w_as_number_of_arguments (0);
				} else
				if (block->block_descriptor!=NULL)
					w_as_label_in_code_section (block->block_descriptor->label_name);
				else
					w_as_number_of_arguments (0);
					
				w_as_number_of_arguments (block->block_n_node_arguments);
				w_as_opcode (intel_asm ? "push" : "pushq"); fprintf (assembly_file,intel_asm ? "offset push_updated_node" : "$push_updated_node"); w_as_newline();
				w_as_opcode ("jmp"); fprintf (assembly_file,".+23"); w_as_newline();
				w_as_space (1);
#endif /* GENERATIONAL_GC */

			if (block->block_ea_label!=NULL){
				int n_node_arguments;

				n_node_arguments=block->block_n_node_arguments;
				if (n_node_arguments<-2)
					n_node_arguments=1;

				if (n_node_arguments>=0 && block->block_ea_label!=eval_fill_label){
					if (!block->block_profile){
						w_as_opcode ("lea");
						if (intel_asm)
							w_as_register_comma (REGISTER_A4);
						w_as_label (block->block_ea_label->label_name);
#if defined (MACH_O64) || defined (LINUX)
						fprintf (assembly_file,"%s",intel_asm ? "[rip]" : "(%rip)");						
#endif
						if (!intel_asm)
							w_as_comma_register (REGISTER_A4);
						w_as_newline();

#ifdef MACH_O64
						if (intel_asm)
							att_syntax();
#endif
						w_as_opcode ("jmp");
						w_as_label (eval_upd_labels[n_node_arguments]->label_name);
						w_as_newline();
#ifdef MACH_O64
						if (intel_asm)
							intel_syntax();
#endif
					} else {
#ifdef MACH_O64
						w_as_lea_descriptor (block->block_profile_function_label,0,REGISTER_A4);
#else
						w_as_opcode_movl();
						if (intel_asm)
							w_as_register_comma (REGISTER_A4);
						w_as_descriptor (block->block_profile_function_label,0);
						if (!intel_asm)
							w_as_comma_register (REGISTER_A4);
						w_as_newline();
#endif
						w_as_opcode ("jmp");
						w_as_label (eval_upd_labels[n_node_arguments]->label_name);
						fprintf (assembly_file,"-8");
						w_as_newline();						

						w_as_opcode ("lea");
						if (intel_asm)
							w_as_register_comma (REGISTER_D0);
						w_as_label (block->block_ea_label->label_name);
#ifdef MACH_O64
						fprintf (assembly_file,"%s",intel_asm ? "[rip]" : "(%rip)");						
#endif
						if (!intel_asm)
							w_as_comma_register (REGISTER_D0);
						w_as_newline();

						w_as_opcode ("jmp");
						fprintf (assembly_file,".-19");
						w_as_newline();

						w_as_instruction_without_parameters ("nop");
						w_as_instruction_without_parameters ("nop");
						w_as_instruction_without_parameters ("nop");
					}
				} else {
					w_as_opcode ("lea");
					if (intel_asm)
						w_as_register_comma (REGISTER_D0);
					w_as_label (block->block_ea_label->label_name);
#if defined (MACH_O64) || defined (LINUX)
					fprintf (assembly_file,"%s",intel_asm ? "[rip]" : "(%rip)");						
#endif
					if (!intel_asm)
						w_as_comma_register (REGISTER_D0);
					w_as_newline();
				
					w_as_opcode ("jmp");
					if (!intel_asm)
						putc ('*',assembly_file);
					w_as_register (REGISTER_D0);
					w_as_newline();

					w_as_space (3);
				}
				
				if (block->block_descriptor!=NULL && (block->block_n_node_arguments<0 || parallel_flag || module_info_flag)){
#ifdef MACH_O64
					struct block_label *labels;

					labels=block->block_labels;
					while (labels!=NULL && labels->block_label_label->label_number!=0)
						labels=labels->block_label_next;

					if (labels!=NULL)
						w_as_label_minus_label_in_code_section
							(block->block_descriptor->label_name,labels->block_label_label->label_name,-8);
					else
#endif
					w_as_label_in_code_section (block->block_descriptor->label_name);
				} else
					w_as_number_of_arguments (0);
			} else

#ifdef GENERATIONAL_GC
			{
			w_as_space (12);

			if (block->block_descriptor!=NULL)
#else
			if (block->block_descriptor!=NULL && (block->block_n_node_arguments<0 || parallel_flag || module_info_flag))
#endif
#ifdef MACH_O64
			{
				struct block_label *labels;

				labels=block->block_labels;
				while (labels!=NULL && labels->block_label_label->label_number!=0)
					labels=labels->block_label_next;

				if (labels!=NULL)
					w_as_label_minus_label_in_code_section
						(block->block_descriptor->label_name,labels->block_label_label->label_name,-8);
				else
#endif
				w_as_label_in_code_section (block->block_descriptor->label_name);
#ifdef MACH_O64
			}
#endif
#ifdef GENERATIONAL_GC
			else
				w_as_number_of_arguments (0);
#endif			
#ifdef GENERATIONAL_GC
			}
#endif
			if (callgraph_profiling && block->block_n_node_arguments>=0){
				if (block->block_descriptor && block->block_descriptor->label_name!=NULL && !strcmp (block->block_descriptor->label_name,"EMPTY"))
					w_as_number_of_arguments (0);
				else
					w_as_number_of_arguments (block->block_n_node_arguments+257);
			} else
				w_as_number_of_arguments (block->block_n_node_arguments);
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

#ifdef MACH_O64
	if (intel_asm && first_call_and_jump!=NULL)
		att_syntax();
#endif
	for_l (call_and_jump,first_call_and_jump,cj_next)
		w_as_call_and_jump (call_and_jump);
#ifdef MACH_O64
	if (intel_asm && first_call_and_jump!=NULL)
		intel_syntax();
#endif

#ifdef DATA_IN_CODE_SECTION
	write_float_constants();
#endif
#ifndef MACH_O64
	if (intel_asm){
		w_as_opcode ("end");
		w_as_newline();
	}
#endif
}
