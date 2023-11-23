/*
	File:      cgpas.c
	Author:    John van Groningen
	Copyright: University of Nijmegen
	Machine:   Power Macintosh
*/

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>

#include "cgport.h"

#ifdef G_POWER

#if defined (LINUX_ELF)
#   define ELF
#	include <elf.h>
#elif defined (MACH_O)
#	define G_MACH_O
#	define G_MACH_O_SCATTERED
#	include </usr/include/mach-o/loader.h>
#	include </usr/include/mach-o/nlist.h>
#	include </usr/include/mach-o/ppc/reloc.h>
#else
#	define XCOFF
#endif

#ifdef GNU_C
# include <ppc_intrinsics.h>
#endif

#define for_l(v,l,n) for(v=(l);v!=NULL;v=v->n)

#undef USE_DCBZ

#define TRL_RELOCATIONS

#include "cgrconst.h"
#include "cgtypes.h"
#include "cg.h"
#include "cgiconst.h"
#include "cgcode.h"
#include "cginstructions.h"
#include "cgpas.h"
#include "cgptoc.h"

#define FP_REVERSE_SUB_DIV_OPERANDS 1

#define IO_BUFFER_SIZE 16384
#define BUFFER_SIZE 4096

struct object_buffer {
	struct object_buffer *	next;
	int						size;
	unsigned char			data [BUFFER_SIZE];
};

#define CONDITIONAL_BRANCH_RELOCATION 0
#define BRANCH_RELOCATION 1
#ifndef ELF
# define TOC_RELOCATION 2
#endif
#define LONG_WORD_RELOCATION 3
#define DUMMY_CONDITIONAL_BRANCH_RELOCATION 4
#ifdef XCOFF
# define TRL_RELOCATION 5
#endif
#if defined (ELF) || defined (G_MACH_O)
# define HIGH_RELOCATION 6
# define LOW_RELOCATION 7
#endif

struct relocation {
	struct relocation *		next;
	unsigned long			offset;
	struct object_label	*	relocation_object_label;
	union {
		struct label *								u_label;
#define 					relocation_label		relocation_u.u_label
		struct toc_label *							u_toc_label;
#define 					relocation_toc_label	relocation_u.u_toc_label
	} relocation_u;
#if defined (ELF) || defined (G_MACH_O)
	long					relocation_addend;
#endif
	short				kind;
};

static struct relocation *first_code_relocation,**last_code_relocation_l;
static struct relocation *first_data_relocation,**last_data_relocation_l;
static int n_code_relocations,n_data_relocations;

static struct object_buffer *first_code_buffer,*current_code_buffer;
static int code_buffer_free,code_buffer_offset;
static unsigned int *code_buffer_p;

static struct object_buffer *first_data_buffer,*current_data_buffer;
static int data_buffer_free,data_buffer_offset;
static unsigned int *data_buffer_p;

static void initialize_buffers (void)
{
	struct object_buffer *new_code_buffer,*new_data_buffer;
	
	new_code_buffer=memory_allocate_type (struct object_buffer);
	
	new_code_buffer->size=0;
	new_code_buffer->next=NULL;
	
	first_code_buffer=new_code_buffer;
	current_code_buffer=new_code_buffer;
	code_buffer_offset=0;
	
	code_buffer_free=BUFFER_SIZE;
	code_buffer_p=(unsigned int*)new_code_buffer->data;

	new_data_buffer=memory_allocate_type (struct object_buffer);
	
	new_data_buffer->size=0;
	new_data_buffer->next=NULL;
	
	first_data_buffer=new_data_buffer;
	current_data_buffer=new_data_buffer;
	data_buffer_offset=0;
	
	data_buffer_free=BUFFER_SIZE;
	data_buffer_p=(unsigned int*)new_data_buffer->data;
}

static void store_instruction2 (int c)
{
	struct object_buffer *new_buffer;

	current_code_buffer->size=BUFFER_SIZE;

	new_buffer=memory_allocate_type (struct object_buffer);

	new_buffer->size=0;
	new_buffer->next=NULL;

	current_code_buffer->next=new_buffer;
	current_code_buffer=new_buffer;
	code_buffer_offset+=BUFFER_SIZE;

	code_buffer_free=BUFFER_SIZE-4;
	code_buffer_p=(unsigned int*)new_buffer->data;

	*code_buffer_p++=c;
}

static void store_instruction (int c)
{
	if (code_buffer_free>=4){
		code_buffer_free-=4;
		*code_buffer_p++=c;
	} else
		store_instruction2 (c);
}

static void store_long_word_in_data_section2 (ULONG c)
{
	struct object_buffer *new_buffer;

	current_data_buffer->size=BUFFER_SIZE;

	new_buffer=memory_allocate_type (struct object_buffer);

	new_buffer->size=0;
	new_buffer->next=NULL;

	current_data_buffer->next=new_buffer;
	current_data_buffer=new_buffer;
	data_buffer_offset+=BUFFER_SIZE;

	data_buffer_free=BUFFER_SIZE-4;
	data_buffer_p=(unsigned int*)new_buffer->data;

	*data_buffer_p++=c;
}

void store_long_word_in_data_section (ULONG c)
{
	if (data_buffer_free>=4){
		data_buffer_free-=4;
		*data_buffer_p++=c;
	} else
		store_long_word_in_data_section2 (c);
}

void store_2_words_in_data_section (UWORD w1,UWORD w2)
{
	store_long_word_in_data_section ((w1<<16) | ((UWORD)w2));
}

static void flush_code_buffer (void)
{
	current_code_buffer->size=BUFFER_SIZE-code_buffer_free;
	code_buffer_offset+=BUFFER_SIZE-code_buffer_free;
}

static void flush_data_buffer (void)
{
	current_data_buffer->size=BUFFER_SIZE-data_buffer_free;
	data_buffer_offset+=BUFFER_SIZE-data_buffer_free;
}

static FILE *output_file;

static void write_buffers_and_release_memory (struct object_buffer **first_buffer_l)
{
	struct object_buffer *buffer,*next_buffer;
	
	for (buffer=*first_buffer_l; buffer!=NULL; buffer=next_buffer){
		int size;
		
		size=buffer->size;
		
		if (fwrite (buffer->data,1,size,output_file)!=size)
			error ("Write error");
		
		next_buffer=buffer->next;
		
		memory_free (buffer);
	}
	
	*first_buffer_l=NULL;
}

void store_abc_string_in_data_section (char *string,int length)
{
	unsigned char *string_p;
	
	string_p=(unsigned char*)string;
	store_long_word_in_data_section (length);
	
	while (length>=4){
		store_long_word_in_data_section (*(ULONG*)string_p);
		string_p+=4;
		length-=4;
	}
	
	if (length>0){
		ULONG d;
		int shift;
				
		d=0;
		shift=24;
		while (length>0){
			d |= string_p[0]<<shift;
			shift-=8;
			--length;
			++string_p;
		}
		store_long_word_in_data_section (d);
	}
} 

void store_c_string_in_data_section (char *string,int length)
{
	unsigned char *string_p;
	ULONG d;
	int shift;
	
	string_p=(unsigned char*)string;
	
	while (length>=4){
		store_long_word_in_data_section (*(ULONG*)string_p);
		string_p+=4;
		length-=4;
	}
			
	d=0;
	shift=24;
	while (length>0){
		d |= string_p[0]<<shift;
		shift-=8;
		--length;
		++string_p;
	}
	store_long_word_in_data_section (d);
}

#define CURRENT_CODE_OFFSET (code_buffer_offset+((unsigned char*)code_buffer_p-current_code_buffer->data))
#define CURRENT_DATA_OFFSET (data_buffer_offset+((unsigned char*)data_buffer_p-current_data_buffer->data))

static void store_label_plus_offset_in_data_section (LABEL *label,int offset)
{
	struct relocation *new_relocation;

#ifdef G_MACH_O
	store_long_word_in_data_section (0);
#else
	store_long_word_in_data_section (offset);
#endif

	new_relocation=fast_memory_allocate_type (struct relocation);
	++n_data_relocations;
	
	*last_data_relocation_l=new_relocation;
	last_data_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;
	
	new_relocation->relocation_label=label;
	new_relocation->offset=CURRENT_DATA_OFFSET-4;
	new_relocation->kind=LONG_WORD_RELOCATION;
#if defined (ELF) || defined (G_MACH_O)
	new_relocation->relocation_addend=offset;
#endif
}

void store_label_in_data_section (LABEL *label)
{
	store_label_plus_offset_in_data_section (label,0);
}

void store_descriptor_in_data_section (LABEL *label)
{
	store_label_plus_offset_in_data_section (label,2);
}

#define CODE_CONTROL_SECTION 0
#define DATA_CONTROL_SECTION 1
#define IMPORTED_CODE_LABEL 2
#define EXPORTED_CODE_LABEL 3
#define EXPORTED_DATA_LABEL 4
#define MERGED_CODE_CONTROL_SECTION 5
#ifdef G_MACH_O
# define STUB_CONTROL_SECTION 6
#endif

struct object_label {
	struct object_label *	next;
	union {
		unsigned long		offset;						/* CODE_CONTROL_SECTION,DATA_CONTROL_SECTION */
		struct label *		label;						/* IMPORTED_CODE_LABEL,EXPORTED_CODE_LABEL */
	} object_label_u1;
	union {
		long				reference;					/* CODE_CONTROL_SECTION,DATA_CONTROL_SECTION */
		unsigned long		size;						/* CODE_CONTROL_SECTION,DATA_CONTROL_SECTION */
		unsigned long		string_offset;				/* IMPORTED_CODE_LABEL,EXPORTED_CODE_LABEL */
	} object_label_u2;
	int						object_label_number;
	short					kind;
};

#define object_label_offset object_label_u1.offset
#define object_label_label object_label_u1.label

#define object_label_reference object_label_u2.reference
#define object_label_size object_label_u2.size
#define object_label_string_offset object_label_u2.string_offset

static struct object_label *first_object_label,**last_object_label_l;
static struct object_label *code_csect_object_label,*data_csect_object_label;
static int n_object_labels;
#ifdef G_MACH_O
static int n_section_object_labels,n_exported_object_labels;
static struct object_label *stub_csect_object_label;
#endif

static unsigned long string_table_offset;

void define_data_label (LABEL *label)
{
	label->label_object_label=data_csect_object_label;
	label->label_offset=CURRENT_DATA_OFFSET;	

	if (label->label_flags & EXPORT_LABEL){
		struct object_label *new_object_label;
		int string_length;
		
		new_object_label=fast_memory_allocate_type (struct object_label);
		*last_object_label_l=new_object_label;
		last_object_label_l=&new_object_label->next;
		new_object_label->next=NULL;
		
		new_object_label->object_label_label=label;
		new_object_label->object_label_number=n_object_labels;
		++n_object_labels;

		string_length=strlen (label->label_name);
#ifdef XCOFF
		if (string_length<8)
			new_object_label->object_label_string_offset=0;
		else {
#endif
			new_object_label->object_label_string_offset=string_table_offset;
			string_table_offset+=string_length+1;
#ifdef XCOFF
		}
#endif
		new_object_label->kind=EXPORTED_DATA_LABEL;
	}
}

static void as_labels (struct block_label *labels)
{
	for (; labels!=NULL; labels=labels->block_label_next)
#if 0
		if (labels->block_label_label->label_number==0)
#endif
		{
			LABEL *label;
			
			label=labels->block_label_label;
			
			label->label_object_label=code_csect_object_label;
			label->label_offset=CURRENT_CODE_OFFSET;
			
			if (label->label_flags & EXPORT_LABEL){
				struct object_label *new_object_label;
				int string_length;

				code_csect_object_label->object_label_reference=-2;
								
				new_object_label=fast_memory_allocate_type (struct object_label);
				*last_object_label_l=new_object_label;
				last_object_label_l=&new_object_label->next;
				new_object_label->next=NULL;
				
				new_object_label->object_label_label=label;
				new_object_label->object_label_number=n_object_labels;
				++n_object_labels;
		
				string_length=strlen (label->label_name);
#ifdef XCOFF
				if (string_length<8)
					new_object_label->object_label_string_offset=0;
				else {
#endif
					new_object_label->object_label_string_offset=string_table_offset;
					string_table_offset+=string_length+1;
#ifdef XCOFF
				}
#endif
				new_object_label->kind=EXPORTED_CODE_LABEL;				
			}
		}
}

extern void store_descriptor_string_in_data_section (char *string,int length,LABEL *string_label)
{
	define_data_label (string_label);
	store_abc_string_in_data_section (string,length);
}

static void as_branch_label (struct label *label,int relocation_kind)
{
	struct relocation *new_relocation;

	new_relocation=fast_memory_allocate_type (struct relocation);
	++n_code_relocations;
	
	*last_code_relocation_l=new_relocation;
	last_code_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;
	
	new_relocation->relocation_label=label;
	new_relocation->offset=CURRENT_CODE_OFFSET-4;
	new_relocation->relocation_object_label=code_csect_object_label;
	new_relocation->kind=relocation_kind;
}

enum { SIZE_QBYTE, SIZE_DBYTE, SIZE_BYTE };

#define REGISTER_O0 (-13)
#define REGISTER_O1 (-23)
#define REGISTER_R0 (-24)
#define RTOC		(-22)
#ifdef USE_DCBZ
# define REGISTER_R9 (-15)
#endif
#define REGISTER_R3 (-21)

static unsigned char real_reg_num [32] =
{
	0,12,2,3,4,5,6,7,8,9,10,11,1,13,14,15,
	16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
};

#define reg_num(r) (real_reg_num[(r)+24])

#define as_i_dai(i,rd,ra,si) store_instruction ((i<<26)|(reg_num(rd)<<21)|(reg_num(ra)<<16)|((UWORD)(si)))
#define as_i_dad(i,rd,ra,d) store_instruction ((i<<26)|(reg_num(rd)<<21)|(reg_num(ra)<<16)|((UWORD)(d)))
#define as_i_sab(rs,ra,rb,i2) store_instruction ((31<<26)|(reg_num(rs)<<21)|(reg_num(ra)<<16)|(reg_num(rb)<<11)|(i2<<1))
#define as_i_dab(rd,ra,rb,i2) store_instruction ((31<<26)|(reg_num(rd)<<21)|(reg_num(ra)<<16)|(reg_num(rb)<<11)|(i2<<1))
#define as_i_dabo_(rd,ra,rb,i2) store_instruction ((31<<26)|(reg_num(rd)<<21)|(reg_num(ra)<<16)|(reg_num(rb)<<11)|(i2<<1)|1025)
#define as_i_sad(i,rs,ra,d) store_instruction ((i<<26)|(reg_num(rs)<<21)|(reg_num(ra)<<16)|((UWORD)(d)))
#define as_i_sahbe(i,rs,ra,sh,mb,me) store_instruction ((i<<26)|(reg_num(rs)<<21)|(reg_num(ra)<<16)|(sh<<11)|(mb<<6)|(me<<1))
#define as_i_dac(i,fd,fa,fb) store_instruction ((63<<26)|(fd<<21)|(fa<<16)|(fb<<11)|(i<<1))

#define as_add(rd,ra,rb)	as_i_dab (rd,ra,rb,266)
#define as_addo_(rd,ra,rb)	as_i_dabo_ (rd,ra,rb,266)
#define as_addi(rd,ra,si)	as_i_dai (14,rd,ra,si)
#define as_addic_(rd,ra,si)	as_i_dai (13,rd,ra,si)
#define as_addis(rd,ra,si)	as_i_dai (15,rd,ra,si)
#define as_addze(rd,ra)		store_instruction ((31<<26)|(reg_num(rd)<<21)|(reg_num(ra)<<16)|(202<<1))
#define as_and(ra,rs,rb)	as_i_sab (rs,ra,rb,28)
#define as_andi_(ra,rs,si)	as_i_dai (28,rs,ra,si)
#define as_andis_(ra,rs,si)	as_i_dai (29,rs,ra,si)
#define as_b()				store_instruction (18<<26)
#define as_bctr()			store_instruction ((19<<26)|(20<<21)|(528<<1))
#define as_bctrl()			store_instruction ((19<<26)|(20<<21)|(528<<1)|1)
#define as_bl()				store_instruction ((18<<26)|1)
#define as_blr()			store_instruction ((19<<26)|(20<<21)|(16<<1))
#define as_cmp(ra,rb)		store_instruction ((31<<26)|(reg_num(ra)<<16)|(reg_num(rb)<<11)|(0<<1))
#define as_cmpi(ra,si)		store_instruction ((11<<26)|(reg_num(ra)<<16)|((UWORD)(si)))
#define as_cmpl(ra,rb)		store_instruction ((31<<26)|(reg_num(ra)<<16)|(reg_num(rb)<<11)|(32<<1))
#define as_divw(rd,ra,rb)	as_i_dab (rd,ra,rb,491)
#define as_divwu(rd,ra,rb)	as_i_dab (rd,ra,rb,459)
#define as_bc(i)			store_instruction ((16<<26)|(i))
#define as_bcl(i)			store_instruction ((16<<26)|1|(i))
#ifdef USE_DCBZ
# define as_dcbz(ra,rb)	store_instruction ((31<<26)|(reg_num(ra)<<16)|(reg_num(rb)<<11)|(1014<<1))
#endif
#define as_extb(ra,rb)		store_instruction ((31<<26)|(reg_num(ra)<<21)|(reg_num(rb)<<16)|(954<<1))
#define as_fabs(fd,fb)		as_i_dac (264,(fd),0,(fb))
#define as_fadd(fd,fa,fc)	as_i_dac (21,(fd),(fa),(fc))
#define as_fcmpu(fa,fb)		as_i_dac (0,0,(fa),(fb))
#define as_fctiw(fd,fb)		as_i_dac (14,(fd),0,(fb))
#define as_fdiv(fd,fa,fc)	as_i_dac (18,(fd),(fa),(fc))
#define as_fmr(fd,fb)		as_i_dac (72,(fd),0,(fb))
#define as_fmadd(fd,fa,fb,fc) store_instruction ((63<<26)|((fd)<<21)|((fa)<<16)|((fc)<<11)|((fb)<<6)|(29<<1))
#define as_fmsub(fd,fa,fb,fc) store_instruction ((63<<26)|((fd)<<21)|((fa)<<16)|((fc)<<11)|((fb)<<6)|(28<<1))
#define as_fmul(fd,fa,fc)	store_instruction ((63<<26)|((fd)<<21)|((fa)<<16)|((fc)<<6)|(25<<1))
#define as_fnmsub(fd,fa,fb,fc) store_instruction ((63<<26)|((fd)<<21)|((fa)<<16)|((fc)<<11)|((fb)<<6)|(30<<1))
#define as_fneg(fd,fb)		as_i_dac (40,(fd),0,(fb))
#define as_fsub(fd,fa,fc)	as_i_dac (20,(fd),(fa),(fc))
#define as_lbz(rd,d,ra)		as_i_dad (34,rd,ra,d)
#define as_lbzu(rd,d,ra)	as_i_dad (35,rd,ra,d)
#define as_lbzx(rd,ra,rb)	as_i_dab (rd,ra,rb,87)
#define as_lha(rd,d,ra)		as_i_dad (42,rd,ra,d)
#define as_lhau(rd,d,ra)	as_i_dad (43,rd,ra,d)
#define as_lhax(rd,ra,rb)	as_i_dab (rd,ra,rb,343)
#define as_lfd(fd,d,ra)		store_instruction ((50<<26)|((fd)<<21)|(reg_num(ra)<<16)|(UWORD)d)
#define as_lfdx(fd,ra,rb)	store_instruction ((31<<26)|((fd)<<21)|(reg_num(ra)<<16)|(reg_num(rb)<<11)|(599<<1))
#define as_lis(rd,si)		as_addis (rd,REGISTER_R0,si)
#define as_li(rd,si)		as_addi (rd,REGISTER_R0,si)
#define as_lwz(rd,d,ra)		as_i_dad (32,rd,ra,d)
#define as_lwzu(rd,d,ra)	as_i_dad (33,rd,ra,d)
#define as_lwzx(rd,ra,rb)	as_i_dab (rd,ra,rb,23)
#define as_mcrxr(rd)		store_instruction ((31<<26)|(reg_num(rd)<<23)|(512<<1))
#define as_mflr(rd)			as_mfspr (8,rd)
#define as_mfspr(spr,rd)	store_instruction ((31<<26)|(reg_num(rd)<<21)|(spr<<16)|(339<<1));
#define as_mr(rd,ra)		as_or (rd,ra,ra)
#define as_mtlr(rs)			as_mtspr (8,rs)
#define as_mtctr(rs)		as_mtspr (9,rs)
#define as_mtspr(spr,rs)	store_instruction ((31<<26)|(reg_num(rs)<<21)|(spr<<16)|(467<<1));
#define as_mulhw(rd,ra,rb)	as_i_dab (rd,ra,rb,75)
#define as_mulhwu(rd,ra,rb)	as_i_dab (rd,ra,rb,11)
#define as_mulli(rd,ra,si)	as_i_dai (7,rd,ra,si)
#define as_mullw(rd,ra,rb)	as_i_dab (rd,ra,rb,235)
#define as_mullwo_(rd,ra,rb)as_i_dabo_ (rd,ra,rb,235)
#define as_nand(ra,rs,rb)	as_i_sab (rs,ra,rb,476)
#define as_neg(rd,ra)		store_instruction ((31<<26)|(reg_num(rd)<<21)|(reg_num(ra)<<16)|(104<<1))
#define as_nop()			store_instruction (24<<26)
#define as_or(ra,rs,rb)		as_i_sab (rs,ra,rb,444)
#define as_ori(ra,rs,si)	as_i_dai (24,rs,ra,si)
#define as_oris(ra,rs,si)	as_i_dai (25,rs,ra,si)
#define as_rlwinm(ra,rs,sh,mb,me) as_i_sahbe (21,rs,ra,sh,mb,me)
#define as_slw(ra,rs,rb)	as_i_sab (rs,ra,rb,24)
#define as_slwi(ra,rs,sh)	as_rlwinm (ra,rs,sh,0,31-sh)
#define as_sraw(ra,rs,rb)	as_i_sab (rs,ra,rb,792)
#define as_srawi(ra,rs,sh)	store_instruction ((31<<26)|(reg_num (rs)<<21)|(reg_num(ra)<<16)|(sh<<11)|(824<<1))
#define as_srw(ra,rs,rb)	as_i_sab (rs,ra,rb,536)
#define as_srwi(ra,rs,sh)	as_rlwinm (ra,rs,32-sh,sh,31)
#define as_stb(rs,d,ra)		as_i_sad (38,rs,ra,d)
#define as_stbu(rs,d,ra)	as_i_sad (39,rs,ra,d)
#define as_stbx(rs,ra,rb)	as_i_sab (rs,ra,rb,215)
#define as_stfd(fs,d,ra)	store_instruction ((54<<26)|((fs)<<21)|(reg_num(ra)<<16)|(UWORD)d)
#define as_stfdx(fs,ra,rb)	store_instruction ((31<<26)|((fs)<<21)|(reg_num(ra)<<16)|(reg_num(rb)<<11)|(727<<1))
#define as_sth(rs,d,ra)		as_i_sad (44,rs,ra,d)
#define as_sthu(rs,d,ra)	as_i_sad (45,rs,ra,d)
#define as_sthx(rs,ra,rb)	as_i_sab (rs,ra,rb,407)
#define as_stw(rs,d,ra)		as_i_sad (36,rs,ra,d)
#define as_stwu(rs,d,ra)	as_i_sad (37,rs,ra,d)
#define as_stwx(rs,ra,rb)	as_i_sab (rs,ra,rb,151)
#define as_sub(rx,ry,rz)	as_subf (rx,rz,ry)
#define as_subo_(rx,ry,rz)	as_subfo_ (rx,rz,ry)
#define as_subf(rd,ra,rb)	as_i_dab (rd,ra,rb,40)
#define as_subfo_(rd,ra,rb)	as_i_dabo_ (rd,ra,rb,40)
#define as_xor(ra,rs,rb)	as_i_sab (rs,ra,rb,316)
#define as_xori(ra,rs,si)	as_i_dai (26,rs,ra,si)
#define as_xoris(ra,rs,si)	as_i_dai (27,rs,ra,si)

#define w_i_dad(i,rd,ra,d)	write_l ((i<<26)|(reg_num(rd)<<21)|(reg_num(ra)<<16)|((UWORD)(d)))
#define w_i_dai(i,rd,ra,si) write_l ((i<<26)|(reg_num(rd)<<21)|(reg_num(ra)<<16)|((UWORD)(si)))

#define w_addi(rd,ra,si)	w_i_dai (14,rd,ra,si)
#define w_addis(rd,ra,si)	w_i_dai (15,rd,ra,si)
#define w_bcl(i)			write_l ((16<<26)|1|(i))
#define w_bctr()			write_l ((19<<26)|(20<<21)|(528<<1))
#define w_lwz(rd,d,ra)		w_i_dad (32,rd,ra,d)
#define w_mflr(rd)			w_mfspr (8,rd)
#define w_mfspr(spr,rd)		write_l ((31<<26)|(reg_num(rd)<<21)|(spr<<16)|(339<<1));
#define w_mtlr(rs)			w_mtspr (8,rs)
#define w_mtctr(rs)			w_mtspr (9,rs)
#define w_mtspr(spr,rs)		write_l ((31<<26)|(reg_num(rs)<<21)|(spr<<16)|(467<<1));

static void as_load_label (struct label *label,int offset,int reg)
{
	struct toc_label *t_label;
	struct relocation *new_relocation;

#ifndef XCOFF
# ifdef G_MACH_O
	as_lis (reg,0);
# else
	as_lis (reg,(offset-(WORD)offset)>>16);
# endif
#else
	t_label=new_toc_label (label,offset);

	as_lwz (reg,t_label->toc_t_label_number<<2,RTOC);
#endif
	new_relocation=fast_memory_allocate_type (struct relocation);
#ifndef G_MACH_O
	++n_code_relocations;
#else
	n_code_relocations+=2;
#endif

	*last_code_relocation_l=new_relocation;
	last_code_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;
	
	new_relocation->offset=CURRENT_CODE_OFFSET-4;
	new_relocation->relocation_object_label=code_csect_object_label;

#ifdef XCOFF
	new_relocation->relocation_toc_label=t_label;
# ifdef TRL_RELOCATIONS
	if (label->label_flags & DATA_LABEL)
		new_relocation->kind=TRL_RELOCATION;
	else
# endif
	new_relocation->kind=TOC_RELOCATION;
#else
	new_relocation->relocation_label=label;
	new_relocation->kind=HIGH_RELOCATION;
	new_relocation->relocation_addend=offset;

# ifdef G_MACH_O
	as_addi (reg,reg,0);
# else
	as_addi (reg,reg,(WORD)offset);
# endif

	new_relocation=fast_memory_allocate_type (struct relocation);
#ifndef G_MACH_O
	++n_code_relocations;
#else
	n_code_relocations+=2;
#endif
	
	*last_code_relocation_l=new_relocation;
	last_code_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;
	
	new_relocation->offset=CURRENT_CODE_OFFSET-4;
	new_relocation->relocation_object_label=code_csect_object_label;
	new_relocation->relocation_label=label;
	new_relocation->kind=LOW_RELOCATION;
	new_relocation->relocation_addend=offset;
#endif
}

#ifndef XCOFF

# define as_load_label1(label,offset,reg,relocation_kind) as_load_label(label,offset,reg)

static void store_label_in_code_section (struct label *label,int offset)
{
	struct toc_label *t_label;
	struct relocation *new_relocation;

	store_instruction (0);

	new_relocation=fast_memory_allocate_type (struct relocation);
	++n_code_relocations;
	
	*last_code_relocation_l=new_relocation;
	last_code_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;
	
	new_relocation->offset=CURRENT_CODE_OFFSET-4;
	new_relocation->relocation_object_label=code_csect_object_label;

	new_relocation->relocation_label=label;
	new_relocation->kind=LONG_WORD_RELOCATION;
	new_relocation->relocation_addend=offset;
}

#else
static void as_load_label1 (struct label *label,int offset,int reg,int relocation_kind)
{
	struct toc_label *t_label;
	struct relocation *new_relocation;

	t_label=new_toc_label (label,offset);

	as_lwz (reg,t_label->toc_t_label_number<<2,RTOC);

	new_relocation=fast_memory_allocate_type (struct relocation);
	++n_code_relocations;
	
	*last_code_relocation_l=new_relocation;
	last_code_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;
	
	new_relocation->offset=CURRENT_CODE_OFFSET-4;
	new_relocation->relocation_object_label=code_csect_object_label;
	new_relocation->relocation_toc_label=t_label;
	new_relocation->kind=relocation_kind;
}
#endif

static void as_load_descriptor (struct parameter *parameter,int reg)
{
	as_load_label1 (parameter->parameter_data.l,2+(parameter->parameter_offset<<3),reg,TRL_RELOCATION);
}

static void as_load_label_parameter (struct parameter *parameter,int reg)
{
	as_load_label (parameter->parameter_data.l,parameter->parameter_offset,reg);
}

static int as_register_parameter (struct parameter parameter,int size_flag)
{
	switch (parameter.parameter_type){
		case P_DESCRIPTOR_NUMBER:
			as_load_descriptor (&parameter,REGISTER_O0);
			return REGISTER_O0;
		case P_IMMEDIATE:
		{
			int i;
			
			i=parameter.parameter_data.i;
			
			if (i!=(WORD)i){
				as_lis (REGISTER_O0,(i-(WORD)i)>>16);
			
				i=(WORD)i;

				as_addi (REGISTER_O0,REGISTER_O0,i);
			} else
				as_li (REGISTER_O0,i);

			return REGISTER_O0;
		}
		case P_REGISTER:
			return parameter.parameter_data.reg.r;
		case P_INDIRECT:
			if (size_flag==SIZE_QBYTE)
				as_lwz (REGISTER_O0,parameter.parameter_offset,parameter.parameter_data.reg.r);
			else if (size_flag==SIZE_DBYTE)
				as_lha (REGISTER_O0,parameter.parameter_offset,parameter.parameter_data.reg.r);
			else
				as_lbz (REGISTER_O0,parameter.parameter_offset,parameter.parameter_data.reg.r);

			return REGISTER_O0;
		case P_INDIRECT_WITH_UPDATE:
			if (size_flag==SIZE_QBYTE)
				as_lwzu (REGISTER_O0,parameter.parameter_offset,parameter.parameter_data.reg.r);
			else if (size_flag==SIZE_DBYTE)
				as_lhau (REGISTER_O0,parameter.parameter_offset,parameter.parameter_data.reg.r);
			else
				as_lbzu (REGISTER_O0,parameter.parameter_offset,parameter.parameter_data.reg.r);

			return REGISTER_O0;
		case P_INDEXED:
			if (size_flag==SIZE_QBYTE)
				as_lwzx (REGISTER_O0,parameter.parameter_data.ir->a_reg.r,parameter.parameter_data.ir->d_reg.r);
			else if (size_flag==SIZE_DBYTE)
				as_lhax (REGISTER_O0,parameter.parameter_data.ir->a_reg.r,parameter.parameter_data.ir->d_reg.r);
			else
				as_lbzx (REGISTER_O0,parameter.parameter_data.ir->a_reg.r,parameter.parameter_data.ir->d_reg.r);

			return REGISTER_O0;
		default:
			internal_error_in_function ("as_register_parameter");
			return REGISTER_O0;
	}
}

static void as_move_instruction (struct instruction *instruction,int size_flag)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_REGISTER:
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_DESCRIPTOR_NUMBER:
					as_load_descriptor (
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
						as_lis (r,(i-(WORD)i)>>16);
					
						i=(WORD)i;

						as_addi (r,r,i);
					} else
						as_li (r,i);
					return;
				}
				case P_REGISTER:
					as_mr (	instruction->instruction_parameters[1].parameter_data.reg.r,
							instruction->instruction_parameters[0].parameter_data.reg.r);
					return;
				case P_INDIRECT:
					if (size_flag==SIZE_QBYTE)
						as_lwz (
							instruction->instruction_parameters[1].parameter_data.reg.r,
							instruction->instruction_parameters[0].parameter_offset,
							instruction->instruction_parameters[0].parameter_data.reg.r);
					else if (size_flag==SIZE_DBYTE)
						as_lha (
							instruction->instruction_parameters[1].parameter_data.reg.r,
							instruction->instruction_parameters[0].parameter_offset,
							instruction->instruction_parameters[0].parameter_data.reg.r);
					else
						as_lbz (
							instruction->instruction_parameters[1].parameter_data.reg.r,
							instruction->instruction_parameters[0].parameter_offset,
							instruction->instruction_parameters[0].parameter_data.reg.r);
					return;
				case P_INDIRECT_WITH_UPDATE:
					if (size_flag==SIZE_QBYTE)
						as_lwzu (
							instruction->instruction_parameters[1].parameter_data.reg.r,
							instruction->instruction_parameters[0].parameter_offset,
							instruction->instruction_parameters[0].parameter_data.reg.r);
					else if (size_flag==SIZE_DBYTE)
						as_lhau (
							instruction->instruction_parameters[1].parameter_data.reg.r,
							instruction->instruction_parameters[0].parameter_offset,
							instruction->instruction_parameters[0].parameter_data.reg.r);
					else
						as_lbzu (
							instruction->instruction_parameters[1].parameter_data.reg.r,
							instruction->instruction_parameters[0].parameter_offset,
							instruction->instruction_parameters[0].parameter_data.reg.r);
					return;
				case P_INDEXED:
					if (size_flag==SIZE_QBYTE)
						as_lwzx (
							instruction->instruction_parameters[1].parameter_data.reg.r,
							instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,
							instruction->instruction_parameters[0].parameter_data.ir->d_reg.r);
					else if (size_flag==SIZE_DBYTE)
						as_lhax (
							instruction->instruction_parameters[1].parameter_data.reg.r,
							instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,
							instruction->instruction_parameters[0].parameter_data.ir->d_reg.r);
					else
						as_lbzx (
							instruction->instruction_parameters[1].parameter_data.reg.r,
							instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,
							instruction->instruction_parameters[0].parameter_data.ir->d_reg.r);
					return;
				default:
					internal_error_in_function ("as_move_instruction");
					return;
			}
		case P_INDIRECT:
		{
			int reg;

			reg=as_register_parameter (instruction->instruction_parameters[0],size_flag);

			if (size_flag==SIZE_QBYTE)
				as_stw (reg,
					instruction->instruction_parameters[1].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
			else if (size_flag==SIZE_DBYTE)
				as_sth (reg,
					instruction->instruction_parameters[1].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
			else
				as_stb (reg,
					instruction->instruction_parameters[1].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		}
		case P_INDIRECT_WITH_UPDATE:
		{
			int reg;

			reg=as_register_parameter (instruction->instruction_parameters[0],size_flag);

			if (size_flag==SIZE_QBYTE)
				as_stwu (reg,
					instruction->instruction_parameters[1].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
			else if (size_flag==SIZE_DBYTE)
				as_sthu	(reg,
					instruction->instruction_parameters[1].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
			else
				as_stbu (reg,
					instruction->instruction_parameters[1].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		}
		case P_INDEXED:
		{
			int reg;

			reg=as_register_parameter (instruction->instruction_parameters[0],size_flag);

			if (size_flag==SIZE_QBYTE)
				as_stwx (reg,
					instruction->instruction_parameters[1].parameter_data.ir->a_reg.r,
					instruction->instruction_parameters[1].parameter_data.ir->d_reg.r);
			else if (size_flag==SIZE_DBYTE)
				as_sthx (reg,
					instruction->instruction_parameters[1].parameter_data.ir->a_reg.r,
					instruction->instruction_parameters[1].parameter_data.ir->d_reg.r);
			else
				as_stbx (reg,
					instruction->instruction_parameters[1].parameter_data.ir->a_reg.r,
					instruction->instruction_parameters[1].parameter_data.ir->d_reg.r);
			return;
		}
		case P_INDIRECT_HP:
		{
			int reg1,reg2;
			LONG offset;

			reg1=as_register_parameter (instruction->instruction_parameters[0],size_flag);
			offset=instruction->instruction_parameters[1].parameter_data.i;
			reg2=HEAP_POINTER;

			if (offset!=(WORD)offset){
				as_addis (REGISTER_O0,reg2,(offset-(WORD)offset)>>16);
				reg2=REGISTER_O0;
				offset=(WORD)offset;
			}

			if (size_flag==SIZE_QBYTE)
				as_stw (reg1,offset,reg2);
			else if (size_flag==SIZE_DBYTE)
				as_sth	(reg1,offset,reg2);
			else
				as_stb (reg1,offset,reg2);
			return;
		}
		default:
			internal_error_in_function ("as_move_instruction");
	}
}

static void as_lea_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER)
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_LABEL:
				as_load_label_parameter (&instruction->instruction_parameters[0],
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_INDIRECT:
				as_addi (
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[0].parameter_data.reg.r,
					instruction->instruction_parameters[0].parameter_offset);
				return;
			case P_INDEXED:
				as_add (
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,
					instruction->instruction_parameters[0].parameter_data.ir->d_reg.r);
				return;				
		}

	internal_error_in_function ("as_lea_instruction");
}

static void as_addi_instruction (struct instruction *instruction)
{
	as_addi (instruction->instruction_parameters[1].parameter_data.reg.r,
			instruction->instruction_parameters[0].parameter_data.reg.r,
			instruction->instruction_parameters[2].parameter_data.i);
}

static void as_add_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_add (instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[0].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
		{
			int i,r;
			
			i=instruction->instruction_parameters[0].parameter_data.i;
			r=instruction->instruction_parameters[1].parameter_data.reg.r;
			
			if (i!=(WORD)i){
				as_addis (r,r,(i-(WORD)i)>>16);
			
				i=(WORD)i;
			}

			as_addi (r,r,i);
			return;
		}
		default:
		{
			int reg;

			reg=as_register_parameter (instruction->instruction_parameters[0],SIZE_QBYTE);

			as_add (instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r,reg);
		}
	}
}

static void as_extb_instruction (struct instruction *instruction)
{
	int reg;

	reg=instruction->instruction_parameters[0].parameter_data.reg.r;

	as_extb (reg,reg);
}

static void as_addo_instruction (struct instruction *instruction)
{
	int reg;

	reg=as_register_parameter (instruction->instruction_parameters[0],SIZE_QBYTE);

	as_addo_ (instruction->instruction_parameters[1].parameter_data.reg.r,
			  instruction->instruction_parameters[1].parameter_data.reg.r,reg);
}

static void as_sub_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_sub (instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[0].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
		{
			int i,r;
			
			i= -instruction->instruction_parameters[0].parameter_data.i;
			r=instruction->instruction_parameters[1].parameter_data.reg.r;
			
			if (i!=(WORD)i){
				as_addis (r,r,(i-(WORD)i)>>16);
			
				i=(WORD)i;
			}

			as_addi (r,r,i);
			return;
		}
		default:
		{
			int reg;

			reg=as_register_parameter (instruction->instruction_parameters[0],SIZE_QBYTE);
			
			as_sub (instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r,reg);
		}
	}
}

static void as_subo_instruction (struct instruction *instruction)
{
	int reg;

	reg=as_register_parameter (instruction->instruction_parameters[0],SIZE_QBYTE);
	
	as_subo_ (instruction->instruction_parameters[1].parameter_data.reg.r,
			  instruction->instruction_parameters[1].parameter_data.reg.r,reg);
}

static void as_cmp_instruction (struct instruction *instruction)
{
	struct parameter parameter_0,parameter_1;

	parameter_0=instruction->instruction_parameters[0];
	parameter_1=instruction->instruction_parameters[1];

	if (parameter_1.parameter_type==P_INDIRECT){
		as_lwz (REGISTER_O1,parameter_1.parameter_offset,parameter_1.parameter_data.reg.r);

		parameter_1.parameter_type=P_REGISTER;
		parameter_1.parameter_data.reg.r=REGISTER_O1;
	} else if (parameter_1.parameter_type==P_INDEXED){
		as_lwzx (REGISTER_O1,parameter_1.parameter_data.ir->a_reg.r,parameter_1.parameter_data.ir->d_reg.r);

		parameter_1.parameter_type=P_REGISTER;
		parameter_1.parameter_data.reg.r=REGISTER_O1;
	}

	switch (parameter_0.parameter_type){
		case P_DESCRIPTOR_NUMBER:
			as_load_descriptor (&parameter_0,REGISTER_O0);

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
				as_lis (REGISTER_O0,(i-(WORD)i)>>16);
			
				i=(WORD)i;

				as_addi (REGISTER_O0,REGISTER_O0,i);

				parameter_0.parameter_type=P_REGISTER;
				parameter_0.parameter_data.reg.r=REGISTER_O0;
			}
			break;
		}
		case P_INDIRECT:
			as_lwz (REGISTER_O0,parameter_0.parameter_offset,parameter_0.parameter_data.reg.r);
			
			parameter_0.parameter_type=P_REGISTER;
			parameter_0.parameter_data.reg.r=REGISTER_O0;
			break;
		case P_INDEXED:
			as_lwzx (REGISTER_O0,parameter_0.parameter_data.ir->a_reg.r,parameter_0.parameter_data.ir->d_reg.r);
			
			parameter_0.parameter_type=P_REGISTER;
			parameter_0.parameter_data.reg.r=REGISTER_O0;
			break;
	}

	if (parameter_0.parameter_type==P_IMMEDIATE){
		as_cmpi (parameter_1.parameter_data.reg.r,parameter_0.parameter_data.i);
	} else
		as_cmp (parameter_1.parameter_data.reg.r,parameter_0.parameter_data.reg.r);
}

#if 0
static void as_cmpw_instruction (struct instruction *instruction)
{
	struct parameter parameter_0,parameter_1;

	parameter_0=instruction->instruction_parameters[0];
	parameter_1=instruction->instruction_parameters[1];

	if (parameter_1.parameter_type==P_INDIRECT){
		as_lha (REGISTER_O1,parameter_1.parameter_offset,parameter_1.parameter_data.reg.r);

		parameter_1.parameter_type=P_REGISTER;
		parameter_1.parameter_data.reg.r=REGISTER_O1;
	} else if (parameter_1.parameter_type==P_INDEXED){
		as_lhax (REGISTER_O1,parameter_1.parameter_data.ir->a_reg.r,parameter_1.parameter_data.ir->d_reg.r);

		parameter_1.parameter_type=P_REGISTER;
		parameter_1.parameter_data.reg.r=REGISTER_O1;
	}

	switch (parameter_0.parameter_type){
		case P_DESCRIPTOR_NUMBER:
			as_load_descriptor (&parameter_0,REGISTER_O0);

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
				as_lis (REGISTER_O0,(i-(WORD)i)>>16);
			
				i=(WORD)i;

				as_addi (REGISTER_O0,REGISTER_O0,i);

				parameter_0.parameter_type=P_REGISTER;
				parameter_0.parameter_data.reg.r=REGISTER_O0;
			}
			break;
		}
		case P_INDIRECT:
			as_lha (REGISTER_O0,parameter_0.parameter_offset,parameter_0.parameter_data.reg.r);
			
			parameter_0.parameter_type=P_REGISTER;
			parameter_0.parameter_data.reg.r=REGISTER_O0;
			break;
		case P_INDEXED:
			as_lhax (REGISTER_O0,parameter_0.parameter_data.ir->a_reg.r,parameter_0.parameter_data.ir->d_reg.r);
			
			parameter_0.parameter_type=P_REGISTER;
			parameter_0.parameter_data.reg.r=REGISTER_O0;
			break;
	}

	if (parameter_0.parameter_type==P_IMMEDIATE){
		as_cmpi (parameter_1.parameter_data.reg.r,parameter_0.parameter_data.i);
	} else
		as_cmp (parameter_1.parameter_data.reg.r,parameter_0.parameter_data.reg.r);
}
#endif

static void as_cmplw_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
		instruction->instruction_parameters[1].parameter_type==P_REGISTER)
	{
		as_lwz (REGISTER_O0,instruction->instruction_parameters[0].parameter_offset,instruction->instruction_parameters[0].parameter_data.reg.r);
		as_cmpl (instruction->instruction_parameters[1].parameter_data.reg.r,REGISTER_O0);
	} else
		internal_error_in_function ("as_cmplw_instruction");	
}

static void as_slwi_instruction (struct instruction *instruction)
{
	as_slwi (instruction->instruction_parameters[1].parameter_data.reg.r,
			instruction->instruction_parameters[0].parameter_data.reg.r,
			instruction->instruction_parameters[2].parameter_data.i);
}

static void as_slw_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){	
		as_slwi (instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[0].parameter_data.i);
	} else {
		int reg;

		reg=as_register_parameter (instruction->instruction_parameters[0],SIZE_QBYTE);
	
		as_slw (instruction->instruction_parameters[1].parameter_data.reg.r,
			instruction->instruction_parameters[1].parameter_data.reg.r,reg);
	}
}

static void as_srw_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){	
		as_srwi (instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[0].parameter_data.i);
	} else {
		int reg;

		reg=as_register_parameter (instruction->instruction_parameters[0],SIZE_QBYTE);
	
		as_srw (instruction->instruction_parameters[1].parameter_data.reg.r,
			instruction->instruction_parameters[1].parameter_data.reg.r,reg);
	}
}

static void as_sraw_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){	
		as_srawi (instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[0].parameter_data.i);
	} else {
		int reg;

		reg=as_register_parameter (instruction->instruction_parameters[0],SIZE_QBYTE);
	
		as_sraw (instruction->instruction_parameters[1].parameter_data.reg.r,
			instruction->instruction_parameters[1].parameter_data.reg.r,reg);
	}
}

static void as_mul_instruction (struct instruction *instruction)
{
	int r,reg;
	
	r=instruction->instruction_parameters[1].parameter_data.reg.r;
	
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_IMMEDIATE:
		{
			int i;
			
			i=instruction->instruction_parameters[0].parameter_data.i;
			
			if (i!=(WORD)i){
				as_lis (REGISTER_O0,(i-(WORD)i)>>16);
			
				i=(WORD)i;

				as_addi (REGISTER_O0,REGISTER_O0,i);
			} else {
				as_mulli (r,r,i);
				return;
			}		
			
			reg=REGISTER_O0;
			break;
		}
		default:
			reg=as_register_parameter (instruction->instruction_parameters[0],SIZE_QBYTE);
	}
	
	as_mullw (r,r,reg);
}

static void as_umulh_instruction (struct instruction *instruction)
{
	int r,reg;
	
	r=instruction->instruction_parameters[1].parameter_data.reg.r;

	reg=as_register_parameter (instruction->instruction_parameters[0],SIZE_QBYTE);
	
	as_mulhwu (r,r,reg);
}

static void as_mulo_instruction (struct instruction *instruction)
{
	int r,reg;
	
	reg=as_register_parameter (instruction->instruction_parameters[0],SIZE_QBYTE);

	r=instruction->instruction_parameters[1].parameter_data.reg.r;
		
	as_mullwo_ (r,r,reg);
}

/*
	From The PowerPC Compiler Writer’s Guide,
	Warren, Henry S., Jr., IBM Research Report RC 18601 [1992]. Changing Division by a
	Constant to Multiplication in Two’s Complement Arithmetic, (December 21),
	Granlund, Torbjorn and Montgomery, Peter L. [1994]. SIGPLAN Notices, 29 (June), 61.
*/

struct ms magic (int d)
	/* must have 2 <= d <= 231-1 or -231 <= d <= -2 */
{
	int p;
	unsigned int ad, anc, delta, q1, r1, q2, r2, t;
	const unsigned int two31 = 2147483648;/* 231 */
	struct ms mag;

	ad = abs(d);
	t = two31 + ((unsigned int)d >> 31);
	anc = t - 1 - t%ad; /* absolute value of nc */
	p = 31;				/* initialize p */
	q1 = two31/anc;		/* initialize q1 = 2p/abs(nc) */
	r1 = two31 - q1*anc;/* initialize r1 = rem(2p,abs(nc)) */
	q2 = two31/ad;		/* initialize q2 = 2p/abs(d) */
	r2 = two31 - q2*ad;	/* initialize r2 = rem(2p,abs(d)) */

	do {
		p = p + 1;
		q1 = 2*q1; 		/* update q1 = 2p/abs(nc) */
		r1 = 2*r1;	 	/* update r1 = rem(2p/abs(nc)) */
		if (r1 >= anc) {/* must be unsigned comparison */
			q1 = q1 + 1;
			r1 = r1 - anc;
		}
		q2 = 2*q2;		/* update q2 = 2p/abs(d) */
		r2 = 2*r2;		/* update r2 = rem(2p/abs(d)) */
		if (r2 >= ad) { /* must be unsigned comparison */
			q2 = q2 + 1;
			r2 = r2 - ad;
		}
		delta = ad - r2;
	} while (q1 < delta || (q1 == delta && r1 == 0));

	mag.m = q2 + 1;
	if (d < 0) mag.m = -mag.m;	/* resulting magic number */
	mag.s = p - 32;				/* resulting shift */

	return mag;
}

static void as_divi (int i,int s_reg,int d_reg)
{
	struct ms ms;

	ms=magic (abs (i));			

	as_lis (REGISTER_O0,(ms.m-(WORD)ms.m)>>16);
	as_addi (REGISTER_O0,REGISTER_O0,(WORD)ms.m);
	as_mulhw (REGISTER_O0,REGISTER_O0,s_reg);

	if (ms.m<0)
		as_add (REGISTER_O0,REGISTER_O0,s_reg);
	if (i>=0)
		as_srwi (d_reg,s_reg,31);
	else
		as_srawi (d_reg,s_reg,31);
	if (ms.s>0)
		as_srawi (REGISTER_O0,REGISTER_O0,ms.s);

	if (i>=0)
		as_add (d_reg,d_reg,REGISTER_O0);
	else
		as_sub (d_reg,d_reg,REGISTER_O0);
}

static void as_div_instruction (struct instruction *instruction)
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
			
			as_srawi (sd_reg,sd_reg,log2i);
			as_addze (sd_reg,sd_reg);			

			return;
		} else if (i>1 || (i<-1 && i!=0x80000000)){
			sd_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

			as_divi (i,sd_reg,sd_reg);

			return;
		}
	}

	reg=as_register_parameter (instruction->instruction_parameters[0],SIZE_QBYTE);
	
	as_divw (instruction->instruction_parameters[1].parameter_data.reg.r,
			instruction->instruction_parameters[1].parameter_data.reg.r,reg);
}

static void as_divu_instruction (struct instruction *instruction)
{
	int reg;

	reg=as_register_parameter (instruction->instruction_parameters[0],SIZE_QBYTE);
	
	as_divwu (instruction->instruction_parameters[1].parameter_data.reg.r,
			 instruction->instruction_parameters[1].parameter_data.reg.r,reg);
}

static void as_rem_instruction (struct instruction *instruction)
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

			as_srawi (REGISTER_O1,sd_reg,31);

			if (log2i==1){
				as_andi_ (sd_reg,sd_reg,1);
				as_xor (sd_reg,sd_reg,REGISTER_O1);				
			} else {
				as_rlwinm (REGISTER_O1,REGISTER_O1,0,32-log2i,31);
				as_add (sd_reg,sd_reg,REGISTER_O1);								
				as_rlwinm (sd_reg,sd_reg,0,32-log2i,31);
			}

			as_sub (sd_reg,sd_reg,REGISTER_O1);
			
			return;
		} else if (i>1 || (i<-1 && i!=0x80000000)){
			int i2;
			
			sd_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

			as_divi (i,sd_reg,REGISTER_O1);

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
					
					if (n_shifts>0)
						as_slwi (REGISTER_O1,REGISTER_O1,n_shifts);
					
					as_sub (sd_reg,sd_reg,REGISTER_O1);

					n>>=1;
					n_shifts=1;
				}
			} else {
				if (i!=(WORD)i){
					as_lis (REGISTER_O0,(i-(WORD)i)>>16);
				
					i=(WORD)i;

					as_addi (REGISTER_O0,REGISTER_O0,i);
					as_mullw (REGISTER_O1,REGISTER_O1,REGISTER_O0);
				} else
					as_mulli (REGISTER_O1,REGISTER_O1,i);
				
				as_sub (sd_reg,sd_reg,REGISTER_O1);
			}

			return;
		}
	}

	reg=as_register_parameter (instruction->instruction_parameters[0],SIZE_QBYTE);
	
	as_divw (REGISTER_O1,instruction->instruction_parameters[1].parameter_data.reg.r,reg);
	as_mullw (REGISTER_O1,REGISTER_O1,reg);
	as_sub (instruction->instruction_parameters[1].parameter_data.reg.r,
			instruction->instruction_parameters[1].parameter_data.reg.r,REGISTER_O1);
}

static void as_and_instruction (struct instruction *instruction)
{
	int reg;
	
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		int i,i2;

		i=instruction->instruction_parameters[0].parameter_data.i;

		if (i==(UWORD)i){
			as_andi_ (instruction->instruction_parameters[1].parameter_data.reg.r,
					  instruction->instruction_parameters[1].parameter_data.reg.r,i);
			return;
		} else if (((UWORD)i)==0){
			as_andis_ (	instruction->instruction_parameters[1].parameter_data.reg.r,
						instruction->instruction_parameters[1].parameter_data.reg.r,
						((unsigned int)i)>>16);
			return;
		} else if (i2=i | (i-1),(i2 & (i2+1))==0){
			int n_leading_0_bits,n_leading_0_bits_and_1_bits;
			
			n_leading_0_bits = __cntlzw (i);
			n_leading_0_bits_and_1_bits = __cntlzw (i ^ ((unsigned)0xffffffffu>>(unsigned)n_leading_0_bits));
			
			as_rlwinm (	instruction->instruction_parameters[1].parameter_data.reg.r,
						instruction->instruction_parameters[1].parameter_data.reg.r,
						0,n_leading_0_bits,n_leading_0_bits_and_1_bits-1);
			return;
		} else {
			as_lis (REGISTER_O0,(i-(WORD)i)>>16);
				
			i=(WORD)i;
	
			as_addi (REGISTER_O0,REGISTER_O0,i);

			reg=REGISTER_O0;
		}
	} else
		reg=as_register_parameter (instruction->instruction_parameters[0],SIZE_QBYTE);
	
	as_and (instruction->instruction_parameters[1].parameter_data.reg.r,
			instruction->instruction_parameters[1].parameter_data.reg.r,reg);
}

static void as_or_instruction (struct instruction *instruction)
{	
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		long i;

		i=instruction->instruction_parameters[0].parameter_data.i;

		if ((unsigned short) i != i){
			int h;
			
			h=(unsigned)i >> (unsigned)16;
			
			as_oris (instruction->instruction_parameters[1].parameter_data.reg.r,
					 instruction->instruction_parameters[1].parameter_data.reg.r,h);
						
			i=(unsigned short)i;
		}

		as_ori (instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r,i);
	} else {
		int reg;

		reg=as_register_parameter (instruction->instruction_parameters[0],SIZE_QBYTE);

		as_or (instruction->instruction_parameters[1].parameter_data.reg.r,
			   instruction->instruction_parameters[1].parameter_data.reg.r,reg);
	}
}

static void as_xor_instruction (struct instruction *instruction)
{	
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		long i;

		i=instruction->instruction_parameters[0].parameter_data.i;

		if ((unsigned short) i != i){
			int h;
			
			h=(unsigned)i >> (unsigned)16;
			
			as_xoris (instruction->instruction_parameters[1].parameter_data.reg.r,
					 instruction->instruction_parameters[1].parameter_data.reg.r,h);
						
			i=(unsigned short)i;
		}

		as_xori (instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r,i);
	} else {
		int reg;

		reg=as_register_parameter (instruction->instruction_parameters[0],SIZE_QBYTE);

		as_xor (instruction->instruction_parameters[1].parameter_data.reg.r,
			   instruction->instruction_parameters[1].parameter_data.reg.r,reg);
	}
}

static void as_tst_instruction (struct instruction *instruction)
{
	int reg;

	reg=as_register_parameter (instruction->instruction_parameters[0],SIZE_QBYTE);

	as_cmpi (reg,0);
}

static void as_jmp_instruction (struct instruction *instruction)
{
	struct parameter *parameter0;
	
	parameter0=&instruction->instruction_parameters[0];

	switch (parameter0->parameter_type){
		case P_LABEL:
			as_b();
			as_branch_label (parameter0->parameter_data.l,BRANCH_RELOCATION);
			return;
		case P_INDIRECT:
		{
			int offset,reg;

			offset=parameter0->parameter_offset;
			reg=parameter0->parameter_data.reg.r;

			if (offset!=0){
				as_addi (REGISTER_O0,reg,offset);
				
				as_mtctr (REGISTER_O0);
			} else
				as_mtctr (reg);

			as_bctr();
			return;
		}
		default:
			internal_error_in_function ("as_jmp_instruction");
	}
}

static void as_jmpp_instruction (struct instruction *instruction)
{
	struct parameter *parameter0;
	int offset;
	
	parameter0=&instruction->instruction_parameters[0];
	offset=parameter0->parameter_offset;

	switch (parameter0->parameter_type){
		case P_LABEL:
			if (offset==0){
				as_mflr (REGISTER_R0);	
				as_bl();
				as_branch_label (profile_t_label,BRANCH_RELOCATION);
			}

			store_instruction ((18<<26) + offset);
			as_branch_label (instruction->instruction_parameters[0].parameter_data.l,BRANCH_RELOCATION);
			return;
		case P_INDIRECT:
		{
			int reg;

			reg=parameter0->parameter_data.reg.r;

			if (offset!=0){
				as_addi (REGISTER_O0,reg,offset);
				
				as_mtctr (REGISTER_O0);
			} else
				as_mtctr (reg);
			
			as_b();
			as_branch_label (profile_ti_label,BRANCH_RELOCATION);
			return;
		}
		default:
			internal_error_in_function ("as_jmpp_instruction");
	}
}

static void as_neg_instruction (struct instruction *instruction)
{	
	as_neg (instruction->instruction_parameters[0].parameter_data.reg.r,instruction->instruction_parameters[0].parameter_data.reg.r);
}

static void as_not_instruction (struct instruction *instruction)
{	
	as_nand (instruction->instruction_parameters[0].parameter_data.reg.r,instruction->instruction_parameters[0].parameter_data.reg.r,instruction->instruction_parameters[0].parameter_data.reg.r);
}

static void write_c (int c)
{
	fputc (c,output_file);
}

static void write_w (int c)
{
	fputc (c>>8,output_file);
	fputc (c,output_file);
}

#ifdef G_MACH_O_SCATTERED
static void write_3b (int c)
{
	fputc (c>>16,output_file);
	fputc (c>>8,output_file);
	fputc (c,output_file);
}
#endif

static void write_l (int c)
{
	fputc (c>>24,output_file);
	fputc (c>>16,output_file);
	fputc (c>>8,output_file);
	fputc (c,output_file);
}

#ifdef G_MACH_O
struct stub {
	LABEL *stub_label;
	struct object_label *stub_object_label;
	struct stub *stub_next;
};

static struct stub *first_stub,**next_stub_l;
static int n_stubs;

static void compute_offsets_of_stub_labels (void)
{
	struct stub *stub;
	unsigned int stub_offset1;
	
	stub_offset1=code_buffer_offset+data_buffer_offset;

	for_l (stub,first_stub,stub_next){
		LABEL *label;
		
		label=stub->stub_label;
		label->label_offset=stub_offset1;
		label->label_flags &= ~STUB_GENERATED;
		
		stub_offset1+=36;
	}
}

static void write_stubs (void)
{
	struct stub *stub;
	unsigned int stub_offset1,stub_offset2;
	
	stub_offset1=code_buffer_offset+data_buffer_offset;
	stub_offset2=stub_offset1+n_stubs*36;

	for_l (stub,first_stub,stub_next){
		unsigned int offset_diff;
		
		offset_diff=stub_offset2-(stub_offset1+8);
		w_mflr (REGISTER_R0);
		w_bcl ((20<<21)|(31<<16)|4);
		w_mflr (REGISTER_O0);
		w_addis (REGISTER_O0,REGISTER_O0,(offset_diff-(WORD)offset_diff)>>16);
		w_mtlr (REGISTER_R0);
		w_lwz (REGISTER_O1,offset_diff & 0xffff,REGISTER_O0);
		w_mtctr (REGISTER_O1);
		w_addi (REGISTER_O0,REGISTER_O0,offset_diff & 0xffff);
		w_bctr();

		stub_offset1+=36;
		stub_offset2+=4;
	}

	for_l (stub,first_stub,stub_next)
		write_l (0);
}

extern LABEL *dyld_stub_binding_helper_p_label;

static void write_stub_relocations_and_indirect_symbols (void)
{
	struct stub *stub;
	unsigned int stub_offset1,stub_offset2,picsymbol_stub_section_offset;

	picsymbol_stub_section_offset=code_buffer_offset+data_buffer_offset;
	
	stub_offset1=0;
	stub_offset2=picsymbol_stub_section_offset+n_stubs*36;

	for_l (stub,first_stub,stub_next){
		unsigned int offset_diff;
		
		offset_diff=stub_offset2-(picsymbol_stub_section_offset+stub_offset1+8);
		
		write_l ((1<<31) | (2<<28) | (PPC_RELOC_HA16_SECTDIFF<<24) | (stub_offset1+12));
		write_l (stub_offset2);
		write_l ((1<<31) | (2<<28) | (PPC_RELOC_PAIR<<24) | (offset_diff & 0xffff));
		write_l (picsymbol_stub_section_offset+stub_offset1+8);

		write_l ((1<<31) | (2<<28) | (PPC_RELOC_LO16_SECTDIFF<<24) | (stub_offset1+20));
		write_l (stub_offset2);
		write_l ((1<<31) | (2<<28) | (PPC_RELOC_PAIR<<24) | (offset_diff>>16));
		write_l (picsymbol_stub_section_offset+stub_offset1+8);

		write_l ((1<<31) | (2<<28) | (PPC_RELOC_LO16_SECTDIFF<<24) | (stub_offset1+28));
		write_l (stub_offset2);
		write_l ((1<<31) | (2<<28) | (PPC_RELOC_PAIR<<24) | (offset_diff>>16));
		write_l (picsymbol_stub_section_offset+stub_offset1+8);

		stub_offset1+=36;
		stub_offset2+=4;
	}

	stub_offset2=0;
	for_l (stub,first_stub,stub_next){
		write_l (stub_offset2);
		write_l (PPC_RELOC_VANILLA | (2<<5) | (1<<4) | (dyld_stub_binding_helper_p_label->label_object_label->object_label_number<<8));
		stub_offset2+=4;
	}

	for_l (stub,first_stub,stub_next){
		struct object_label *object_label;
		
		object_label=stub->stub_object_label;
		if (object_label->kind!=IMPORTED_CODE_LABEL)
			internal_error_in_function ("write_stub_relocations_and_indirect_symbols");
		
		write_l (object_label->object_label_number);
	}
	
	for_l (stub,first_stub,stub_next)
		write_l (stub->stub_object_label->object_label_number);
}
#endif

static void as_jsr_instruction (struct instruction *instruction)
{
	struct parameter *parameter0;

	parameter0=&instruction->instruction_parameters[0];

	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		int frame_size;
		
		frame_size=instruction->instruction_parameters[1].parameter_data.i;
		
		if (parameter0->parameter_type==P_REGISTER){
#ifdef G_MACH_O
			as_mtctr (parameter0->parameter_data.reg.r);
#else
			as_lwz (REGISTER_O1,0,parameter0->parameter_data.reg.r);
			as_stw (RTOC,20-(frame_size+28),B_STACK_POINTER);
			as_lwz (RTOC,4,parameter0->parameter_data.reg.r);
			as_mtctr (REGISTER_O1);
#endif
		}

		if (!(instruction->instruction_arity & NO_MFLR))
			as_mflr (REGISTER_R0);			

#ifdef ALIGN_C_CALLS
# if 0
		as_mr (REGISTER_O0,B_STACK_POINTER);
		as_ori (B_STACK_POINTER,B_STACK_POINTER,28);
# endif
		as_stw (REGISTER_R0,-28-4,B_STACK_POINTER);
		as_stwu (REGISTER_O0,-(frame_size+28),B_STACK_POINTER);
#else
		as_stw (REGISTER_R0,-4,B_STACK_POINTER);
		as_stwu (B_STACK_POINTER,-frame_size,B_STACK_POINTER);
#endif
		if (parameter0->parameter_type==P_REGISTER){
			as_bctrl();
#ifdef G_MACH_O
			as_nop();
#else
			as_lwz (RTOC,20,B_STACK_POINTER);
#endif
		} else {
			struct label *label;
			
			as_bl();
			
			label=parameter0->parameter_data.l;
#ifdef G_MACH_O
			if (label->label_name[0]=='_'){
				if (!(label->label_flags & STUB_GENERATED)){
					struct stub *new_stub;
					
					label->label_flags |= STUB_GENERATED;
					label->label_offset=n_stubs*36;

					if (stub_csect_object_label==NULL){
						struct object_label *new_object_label;
						
						new_object_label=fast_memory_allocate_type (struct object_label);
						stub_csect_object_label=new_object_label;
										
						new_object_label->object_label_reference=-1;
						new_object_label->object_label_offset=0;
						new_object_label->object_label_number=-1;
						new_object_label->kind=STUB_CONTROL_SECTION;
					}
					
					new_stub=allocate_memory_from_heap (sizeof (struct stub));
					
					new_stub->stub_label=label;
					new_stub->stub_object_label=label->label_object_label;
					label->label_object_label=stub_csect_object_label;
					
					*next_stub_l=new_stub;
					next_stub_l=&new_stub->stub_next;
					new_stub->stub_next=NULL;
					++n_stubs;
				}
			}
#endif
			as_branch_label (label,BRANCH_RELOCATION);
			as_nop();
		}
	
#ifdef ALIGN_C_CALLS
		as_lwz (REGISTER_R0,frame_size-4,B_STACK_POINTER);
		as_lwz (B_STACK_POINTER,0,B_STACK_POINTER);
#else
		as_lwz (REGISTER_R0,frame_size-4,B_STACK_POINTER);
		as_addi (B_STACK_POINTER,B_STACK_POINTER,frame_size);
#endif
		if (!(instruction->instruction_arity & NO_MTLR))
			as_mtlr (REGISTER_R0);
		
		return;
	}

	if (parameter0->parameter_type==P_INDIRECT){
		int offset,reg;

		offset=parameter0->parameter_offset;
		reg=parameter0->parameter_data.reg.r;

		if (offset!=0){
			as_addi (REGISTER_O0,reg,offset);
			as_mtctr (REGISTER_O0);
		} else
			as_mtctr (reg);
	}

	if (!(instruction->instruction_arity & NO_MFLR))
		as_mflr (REGISTER_R0);

	if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE)
		as_stwu (REGISTER_R0,instruction->instruction_parameters[1].parameter_data.i,B_STACK_POINTER);
	else
		as_stw (REGISTER_R0,instruction->instruction_parameters[1].parameter_data.i,B_STACK_POINTER);

	switch (parameter0->parameter_type){
		case P_LABEL:
			as_bl();
			as_branch_label (parameter0->parameter_data.l,BRANCH_RELOCATION);
			break;
		case P_INDIRECT:
			as_bctrl();
			break;
		default:
			internal_error_in_function ("as_jsr_instruction");
	}

	if (!(instruction->instruction_arity & NO_MTLR))
		as_mtlr (REGISTER_R0);
}

static void as_new_code_module (void)
{
	struct object_label *new_object_label;
	unsigned long current_code_offset;
	int code_section_label_number;

#if !defined (XCOFF) && !defined (G_MACH_O_SCATTERED)
	if (code_csect_object_label!=NULL)
		return;
#endif

	new_object_label=fast_memory_allocate_type (struct object_label);
	code_csect_object_label=new_object_label;

	code_section_label_number=n_object_labels;
	++n_object_labels;

	current_code_offset=CURRENT_CODE_OFFSET;

	*last_object_label_l=new_object_label;
	last_object_label_l=&new_object_label->next;
	new_object_label->next=NULL;
	
	new_object_label->object_label_reference=-1;
	new_object_label->object_label_offset=current_code_offset;
	new_object_label->object_label_number=code_section_label_number;
	new_object_label->kind=CODE_CONTROL_SECTION;
}

void as_new_data_module (void)
{
	struct object_label *new_object_label;
	unsigned long current_data_offset;
	int data_section_label_number;

#if !defined (XCOFF) && !defined (G_MACH_O_SCATTERED)
	if (data_csect_object_label!=NULL)
		return;
#endif
	
	new_object_label=fast_memory_allocate_type (struct object_label);
	data_csect_object_label=new_object_label;

	data_section_label_number=n_object_labels;
	++n_object_labels;

	current_data_offset=CURRENT_DATA_OFFSET;

	*last_object_label_l=new_object_label;
	last_object_label_l=&new_object_label->next;
	new_object_label->next=NULL;
	
	new_object_label->object_label_reference=-1;
	new_object_label->object_label_offset=current_data_offset;
	new_object_label->object_label_number=data_section_label_number;
	new_object_label->kind=DATA_CONTROL_SECTION;
}

struct call_and_jump {
	struct call_and_jump *	cj_next;
	struct label *			cj_call_label;
	struct label			cj_label;
	struct label			cj_jump_label;
};

static struct call_and_jump *first_call_and_jump,*last_call_and_jump;

static void as_call_and_jump (struct call_and_jump *call_and_jump)
{
	call_and_jump->cj_label.label_object_label=code_csect_object_label;
	call_and_jump->cj_label.label_offset=CURRENT_CODE_OFFSET;

	if (call_and_jump->cj_jump_label.label_flags & FAR_CONDITIONAL_JUMP_LABEL){
		as_b();
		as_branch_label (call_and_jump->cj_call_label,BRANCH_RELOCATION);	
	} else {
		as_mflr (REGISTER_R0);

		as_bl();
		as_branch_label (call_and_jump->cj_call_label,BRANCH_RELOCATION);
	
		as_b();
		as_branch_label (&call_and_jump->cj_jump_label,BRANCH_RELOCATION);
	}
}

static void as_rts_begin (struct instruction *instruction)
{
	LONG b_offset;

	if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT)
		as_lwz (REGISTER_R0,instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r);
	else
		as_mr (REGISTER_R0,instruction->instruction_parameters[0].parameter_data.reg.r);

	b_offset=instruction->instruction_parameters[1].parameter_data.i;
	if (b_offset!=0){
		if (b_offset!=(WORD) b_offset){
			as_addis (B_STACK_POINTER,B_STACK_POINTER,(b_offset-(WORD)b_offset)>>16);
					
			b_offset=(WORD)b_offset;
		}
		
		as_addi (B_STACK_POINTER,B_STACK_POINTER,b_offset);
	}
}

static void as_rts_instruction (struct instruction *instruction)
{
	if (instruction->instruction_arity>0)
		as_rts_begin (instruction);

	as_blr();
}

static void as_rtsp_instruction (struct instruction *instruction)
{
	as_rts_begin (instruction);

	as_b();
	as_branch_label (profile_r_label,BRANCH_RELOCATION);
}

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

static void as_branch_instruction (struct instruction *instruction,int i_code)
{
	if (instruction->instruction_parameters[0].parameter_type!=P_LABEL)
		internal_error_in_function ("as_branch_instruction");
	else {
		LABEL *label;
		
		label=instruction->instruction_parameters[0].parameter_data.l;
		
		as_bc (i_code);
		
		if (label->label_flags & FAR_CONDITIONAL_JUMP_LABEL){
			struct call_and_jump *new_call_and_jump;

			new_call_and_jump=allocate_new_call_and_jump();

			new_call_and_jump->cj_call_label=label;
			new_call_and_jump->cj_label.label_flags=0;

			as_branch_label (&new_call_and_jump->cj_label,CONDITIONAL_BRANCH_RELOCATION);
			
			new_call_and_jump->cj_jump_label.label_object_label=code_csect_object_label;
			new_call_and_jump->cj_jump_label.label_flags=FAR_CONDITIONAL_JUMP_LABEL;
		} else
			as_branch_label (label,CONDITIONAL_BRANCH_RELOCATION);
	}
}

static void as_branchno_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type!=P_LABEL)
		internal_error_in_function ("as_branchno_instruction");
	else {
		LABEL *label;
		
		label=instruction->instruction_parameters[0].parameter_data.l;
		
		as_bc ((4<<21)|(3<<16)); /* bns */
		
		if (label->label_flags & FAR_CONDITIONAL_JUMP_LABEL){
			struct call_and_jump *new_call_and_jump;

			new_call_and_jump=allocate_new_call_and_jump();

			new_call_and_jump->cj_call_label=label;
			new_call_and_jump->cj_label.label_flags=0;

			label=&new_call_and_jump->cj_label;
			
			new_call_and_jump->cj_jump_label.label_object_label=code_csect_object_label;
			new_call_and_jump->cj_jump_label.label_flags=FAR_CONDITIONAL_JUMP_LABEL;
		}
		
		as_branch_label (label,CONDITIONAL_BRANCH_RELOCATION);
		
		as_mcrxr (0);
		
		as_bc ((4<<21)|(1<<16)); /* bng */
		as_branch_label (label,CONDITIONAL_BRANCH_RELOCATION);
	}
}

static void as_brancho_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type!=P_LABEL)
		internal_error_in_function ("as_branchno_instruction");
	else {
		LABEL *label;
		
		label=instruction->instruction_parameters[0].parameter_data.l;
		
		as_bc ((4<<21)|(3<<16)|12); /* bns */
		
		if (label->label_flags & FAR_CONDITIONAL_JUMP_LABEL){
			struct call_and_jump *new_call_and_jump;

			new_call_and_jump=allocate_new_call_and_jump();

			new_call_and_jump->cj_call_label=label;
			new_call_and_jump->cj_label.label_flags=0;

			label=&new_call_and_jump->cj_label;
			
			new_call_and_jump->cj_jump_label.label_object_label=code_csect_object_label;
			new_call_and_jump->cj_jump_label.label_flags=FAR_CONDITIONAL_JUMP_LABEL;
		}
		
		as_mcrxr (0);
		
		as_bc ((12<<21)|(1<<16)); /* bgt */
		as_branch_label (label,CONDITIONAL_BRANCH_RELOCATION);
	}
}

static void as_index_error_branch_instruction (struct instruction *instruction)
{
	as_bc ((13<<21)|(0<<16)|8); /* blt+ */
	as_b();
	as_branch_label (instruction->instruction_parameters[0].parameter_data.l,BRANCH_RELOCATION);
}

static void as_set_condition_instruction (struct instruction *instruction,int i_code)
{
	as_li (instruction->instruction_parameters[0].parameter_data.reg.r,0);
	store_instruction ((16<<26)|i_code|8);
	as_li (instruction->instruction_parameters[0].parameter_data.reg.r,-1);
}

static void as_setno_condition_instruction (struct instruction *instruction)
{
	as_li (instruction->instruction_parameters[0].parameter_data.reg.r,0);

	as_bc ((4<<21)|(3<<16)|12); /* bns */
	as_mcrxr (0);
	as_bc ((12<<21)|(1<<16)|8); /* bgt */

	as_li (instruction->instruction_parameters[0].parameter_data.reg.r,-1);
}

static void as_seto_condition_instruction (struct instruction *instruction)
{
	as_li (instruction->instruction_parameters[0].parameter_data.reg.r,0);

	as_bc ((4<<21)|(3<<16)|16); /* bns */
	as_mcrxr (0);
	as_bc ((4<<21)|(1<<16)|8); /* bng */

	as_li (instruction->instruction_parameters[0].parameter_data.reg.r,-1);
}

static void as_load_float_immediate (double float_value,int fp_reg)
{
	struct label *new_label;
	
	as_new_data_module();
	
	new_label=allocate_memory_from_heap_type (struct label);

	new_label->label_flags=DATA_LABEL;
	new_label->label_object_label=data_csect_object_label;
	new_label->label_offset=CURRENT_DATA_OFFSET;
	
	new_label->label_number=next_label_id++;

	store_long_word_in_data_section (((ULONG*)&float_value)[0]);
	store_long_word_in_data_section (((ULONG*)&float_value)[1]);

	as_load_label (new_label,0,REGISTER_O0);
	as_lfd (fp_reg+14,0,REGISTER_O0);
}

static int as_float_parameter (struct parameter parameter)
{
	switch (parameter.parameter_type){
		case P_F_IMMEDIATE:
			as_load_float_immediate (*parameter.parameter_data.r,17);
			return 17;
		case P_INDIRECT:
			as_lfd (31,parameter.parameter_offset,parameter.parameter_data.reg.r);
			return 17;
		case P_INDEXED:
			as_lfdx (31,parameter.parameter_data.ir->a_reg.r,parameter.parameter_data.ir->d_reg.r);
			return 17;
		case P_F_REGISTER:
			return parameter.parameter_data.reg.r;
		default:
			internal_error_in_function ("as_float_parameter");
			return 17;
	}
}

static void as_fadd_instruction (struct instruction *instruction)
{
	int freg;

	freg=as_float_parameter (instruction->instruction_parameters[0]);

	as_fadd (instruction->instruction_parameters[1].parameter_data.reg.r+14,
			 instruction->instruction_parameters[1].parameter_data.reg.r+14,freg+14);
}

static void as_fdiv_instruction (struct instruction *instruction)
{
	int freg;

	freg=as_float_parameter (instruction->instruction_parameters[0]);

	if (instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
		as_fdiv (instruction->instruction_parameters[1].parameter_data.reg.r+14,
				 freg+14,instruction->instruction_parameters[1].parameter_data.reg.r+14);
	else
		as_fdiv (instruction->instruction_parameters[1].parameter_data.reg.r+14,
				 instruction->instruction_parameters[1].parameter_data.reg.r+14,freg+14);
}

static void as_fsub_instruction (struct instruction *instruction)
{
	int freg;

	freg=as_float_parameter (instruction->instruction_parameters[0]);

	if (instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
		as_fsub (instruction->instruction_parameters[1].parameter_data.reg.r+14,
				 freg+14,instruction->instruction_parameters[1].parameter_data.reg.r+14);
	else
		as_fsub (instruction->instruction_parameters[1].parameter_data.reg.r+14,
				 instruction->instruction_parameters[1].parameter_data.reg.r+14,freg+14);
}

#ifdef FMADD
#define FP_REG_LAST_USE 4

static struct instruction * as_fmul_instruction (struct instruction *instruction)
#else
static void as_fmul_instruction (struct instruction *instruction)
#endif
{
	int freg;

	freg=as_float_parameter (instruction->instruction_parameters[0]);

#ifdef FMADD
	{
		struct instruction *next_instruction;
		
		next_instruction=instruction->instruction_next;
		if (fmadd_flag && next_instruction!=NULL)
			if (next_instruction->instruction_icode==IFADD){
				if (next_instruction->instruction_parameters[0].parameter_type==P_F_REGISTER &&
					next_instruction->instruction_parameters[0].parameter_data.reg.r!=next_instruction->instruction_parameters[1].parameter_data.reg.r)
				{
					if (next_instruction->instruction_parameters[0].parameter_data.reg.r==instruction->instruction_parameters[1].parameter_data.reg.r &&
						next_instruction->instruction_parameters[0].parameter_flags & FP_REG_LAST_USE)
					{
						as_fmadd (	next_instruction->instruction_parameters[1].parameter_data.reg.r+14,
									freg+14,
									instruction->instruction_parameters[1].parameter_data.reg.r+14,
									next_instruction->instruction_parameters[1].parameter_data.reg.r+14);

						return next_instruction;
					} else if (next_instruction->instruction_parameters[1].parameter_data.reg.r==instruction->instruction_parameters[1].parameter_data.reg.r){
						as_fmadd (	next_instruction->instruction_parameters[1].parameter_data.reg.r+14,
									freg+14,
									instruction->instruction_parameters[1].parameter_data.reg.r+14,
									next_instruction->instruction_parameters[0].parameter_data.reg.r+14);

						return next_instruction;
					}
				} else if (next_instruction->instruction_parameters[1].parameter_data.reg.r==instruction->instruction_parameters[1].parameter_data.reg.r){
					if (next_instruction->instruction_parameters[0].parameter_type==P_F_IMMEDIATE){
							as_load_float_immediate (*next_instruction->instruction_parameters[0].parameter_data.r,16);
							as_fmadd (	next_instruction->instruction_parameters[1].parameter_data.reg.r+14,
										freg+14,
										instruction->instruction_parameters[1].parameter_data.reg.r+14,
										16+14);

							return next_instruction;
					} else if (	next_instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
							as_lfd (16+14,next_instruction->instruction_parameters[0].parameter_offset,next_instruction->instruction_parameters[0].parameter_data.reg.r);
							as_fmadd (	next_instruction->instruction_parameters[1].parameter_data.reg.r+14,
										freg+14,
										instruction->instruction_parameters[1].parameter_data.reg.r+14,
										16+14);

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
						if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
							as_fmsub (	next_instruction->instruction_parameters[1].parameter_data.reg.r+14,
										freg+14,
										instruction->instruction_parameters[1].parameter_data.reg.r+14,
										next_instruction->instruction_parameters[1].parameter_data.reg.r+14);
						else
							as_fnmsub (	next_instruction->instruction_parameters[1].parameter_data.reg.r+14,
										freg+14,
										instruction->instruction_parameters[1].parameter_data.reg.r+14,
										next_instruction->instruction_parameters[1].parameter_data.reg.r+14);
					
						return next_instruction;
					} else if (next_instruction->instruction_parameters[1].parameter_data.reg.r==instruction->instruction_parameters[1].parameter_data.reg.r)
					{
						if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
							as_fnmsub (	next_instruction->instruction_parameters[1].parameter_data.reg.r+14,
										freg+14,
										instruction->instruction_parameters[1].parameter_data.reg.r+14,
										next_instruction->instruction_parameters[0].parameter_data.reg.r+14);
						else
							as_fmsub (	next_instruction->instruction_parameters[1].parameter_data.reg.r+14,
										freg+14,
										instruction->instruction_parameters[1].parameter_data.reg.r+14,
										next_instruction->instruction_parameters[0].parameter_data.reg.r+14);
						return next_instruction;
					}
				} else if (next_instruction->instruction_parameters[1].parameter_data.reg.r==instruction->instruction_parameters[1].parameter_data.reg.r){
					if (next_instruction->instruction_parameters[0].parameter_type==P_F_IMMEDIATE){
						as_load_float_immediate (*next_instruction->instruction_parameters[0].parameter_data.r,16);
						if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
							as_fnmsub (	next_instruction->instruction_parameters[1].parameter_data.reg.r+14,
										freg+14,
										instruction->instruction_parameters[1].parameter_data.reg.r+14,
										16+14);
						else
							as_fmsub (	next_instruction->instruction_parameters[1].parameter_data.reg.r+14,
										freg+14,
										instruction->instruction_parameters[1].parameter_data.reg.r+14,
									16+14);

						return next_instruction;
					} else if (next_instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
						as_lfd (16+14,next_instruction->instruction_parameters[0].parameter_offset,next_instruction->instruction_parameters[0].parameter_data.reg.r);
						if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
							as_fnmsub (	next_instruction->instruction_parameters[1].parameter_data.reg.r+14,
										freg+14,
										instruction->instruction_parameters[1].parameter_data.reg.r+14,
										16+14);
						else
							as_fmsub (	next_instruction->instruction_parameters[1].parameter_data.reg.r+14,
										freg+14,
										instruction->instruction_parameters[1].parameter_data.reg.r+14,
									16+14);

						return next_instruction;
					}
				}
			}
	}
#endif

	as_fmul (instruction->instruction_parameters[1].parameter_data.reg.r+14,
		  	 instruction->instruction_parameters[1].parameter_data.reg.r+14,freg+14);
#ifdef FMADD
	return instruction;
#endif
}

static void as_fneg_instruction (struct instruction *instruction)
{
	int freg;

	freg=as_float_parameter (instruction->instruction_parameters[0]);

	as_fneg (instruction->instruction_parameters[1].parameter_data.reg.r+14,freg+14);
}

static void as_fabs_instruction (struct instruction *instruction)
{
	int freg;

	freg=as_float_parameter (instruction->instruction_parameters[0]);

	as_fabs (instruction->instruction_parameters[1].parameter_data.reg.r+14,freg+14);
}

static void as_compare_float_instruction (struct instruction *instruction)
{
	int freg;
	
	freg=as_float_parameter (instruction->instruction_parameters[0]);

	as_fcmpu (instruction->instruction_parameters[1].parameter_data.reg.r+14,freg+14);
}

static struct instruction *as_fmove_instruction (struct instruction *instruction)
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
							case IFADD: case IFSUB: case IFMUL: case IFDIV:
								if (next_instruction->instruction_parameters[1].parameter_data.reg.r==reg1)
								{
									int reg_s;

									reg_s=as_float_parameter (next_instruction->instruction_parameters[0]);

									if (reg_s==reg1)
										reg_s=reg0;
									
									switch (next_instruction->instruction_icode){
										case IFADD:
											as_fadd (reg1+14,reg0+14,reg_s+14);
											break;
										case IFSUB:
											if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
												as_fsub (reg1+14,reg_s+14,reg0+14);
											else
												as_fsub (reg1+14,reg0+14,reg_s+14);
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
														as_fmadd (	next_of_next_instruction->instruction_parameters[1].parameter_data.reg.r+14,
																	reg0+14,reg_s+14,
																	next_of_next_instruction->instruction_parameters[1].parameter_data.reg.r+14);
														
														return next_of_next_instruction;
													} else if (next_of_next_instruction->instruction_parameters[1].parameter_data.reg.r==reg1){
														if (next_of_next_instruction->instruction_parameters[0].parameter_type==P_F_IMMEDIATE){
															as_load_float_immediate (*next_of_next_instruction->instruction_parameters[0].parameter_data.r,16);
															as_fmadd (reg1+14,reg0+14,reg_s+14,16+14);
															
															return next_of_next_instruction;
														} else if (next_of_next_instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
															as_lfd (16+14,next_of_next_instruction->instruction_parameters[0].parameter_offset,next_of_next_instruction->instruction_parameters[0].parameter_data.reg.r);
															as_fmadd (reg1+14,reg0+14,reg_s+14,16+14);
															
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
															as_fmsub (	next_of_next_instruction->instruction_parameters[1].parameter_data.reg.r+14,
																		reg0+14,reg_s+14,
																		next_of_next_instruction->instruction_parameters[1].parameter_data.reg.r+14);
														else
															as_fnmsub (	next_of_next_instruction->instruction_parameters[1].parameter_data.reg.r+14,
																		reg0+14,reg_s+14,
																		next_of_next_instruction->instruction_parameters[1].parameter_data.reg.r+14);
														
														return next_of_next_instruction;					
													} else if (next_of_next_instruction->instruction_parameters[1].parameter_data.reg.r==reg1){
														if (next_of_next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
															as_fnmsub (	next_of_next_instruction->instruction_parameters[1].parameter_data.reg.r+14,
																		reg0+14,reg_s+14,
																		next_of_next_instruction->instruction_parameters[0].parameter_data.reg.r+14);
														else
															as_fmsub (	next_of_next_instruction->instruction_parameters[1].parameter_data.reg.r+14,
																		reg0+14,reg_s+14,
																		next_of_next_instruction->instruction_parameters[0].parameter_data.reg.r+14);
														
														return next_of_next_instruction;
													}
												}

											}
										}
#endif
											as_fmul (reg1+14,reg0+14,reg_s+14);
											break;
										case IFDIV:
											if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
												as_fdiv (reg1+14,reg_s+14,reg0+14);
											else
												as_fdiv (reg1+14,reg0+14,reg_s+14);
											break;
									}									
									return next_instruction;
								}
						}

					as_fmr (reg1+14,reg0+14);				
					return instruction;
				}
				case P_INDIRECT:
					as_lfd (instruction->instruction_parameters[1].parameter_data.reg.r+14,
							instruction->instruction_parameters[0].parameter_offset,
							instruction->instruction_parameters[0].parameter_data.reg.r);
					return instruction;
				case P_F_IMMEDIATE:
					as_load_float_immediate (*instruction->instruction_parameters[0].parameter_data.r,instruction->instruction_parameters[1].parameter_data.reg.r);
					return instruction;
				case P_INDEXED:
					as_lfdx (instruction->instruction_parameters[1].parameter_data.reg.r+14,
							 instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,
							 instruction->instruction_parameters[0].parameter_data.ir->d_reg.r);
					return instruction;
			}
			break;
		case P_INDIRECT:
			if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
				as_stfd (instruction->instruction_parameters[0].parameter_data.reg.r+14,
						 instruction->instruction_parameters[1].parameter_offset,
						 instruction->instruction_parameters[1].parameter_data.reg.r);
				return instruction;
			}
			break;
		case P_INDEXED:
			if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
				as_stfdx (instruction->instruction_parameters[0].parameter_data.reg.r+14,
						  instruction->instruction_parameters[1].parameter_data.ir->a_reg.r,
						  instruction->instruction_parameters[1].parameter_data.ir->d_reg.r);
				return instruction;
			}
			break;

	}
	internal_error_in_function ("w_as_fmove_instruction");
	return instruction;
}

static void as_btst_instruction (struct instruction *instruction)
{
	as_andi_ (REGISTER_O0,instruction->instruction_parameters[1].parameter_data.reg.r,
			  instruction->instruction_parameters[0].parameter_data.i);
}

extern LABEL *r_to_i_buffer_label;

static void as_fmovel_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
		if (instruction->instruction_parameters[1].parameter_type!=P_REGISTER)
			internal_error_in_function ("as_fmovel_instruction");

		as_fctiw (31,instruction->instruction_parameters[0].parameter_data.reg.r+14);
		as_load_label (r_to_i_buffer_label,0,REGISTER_O0);
		as_stfd (31,0,REGISTER_O0);
		as_lwz (instruction->instruction_parameters[1].parameter_data.reg.r,4,REGISTER_O0);
	} else {
		int reg;
		struct label *new_label;

		reg=as_register_parameter (instruction->instruction_parameters[0],SIZE_QBYTE);
		
		as_new_data_module();
	
		new_label=allocate_memory_from_heap_type (struct label);

		new_label->label_flags=DATA_LABEL;
		new_label->label_object_label=data_csect_object_label;
		new_label->label_offset=CURRENT_DATA_OFFSET;

		new_label->label_number=next_label_id++;

		store_long_word_in_data_section (0x43300000);
		store_long_word_in_data_section (0x00000000);
		store_long_word_in_data_section (0x43300000);
		store_long_word_in_data_section (0x80000000);
	
		/*
		lwz		o1,t_n{TC}(RTOC)
		xoris	o0,reg,0x8000
		lfd		fp31,8(o1)
		stw		o0,4(o1)
		lfd		freg,0(o1)
		fsub	freg,freg,fp31
		*/

		as_load_label (new_label,0,REGISTER_O1);
		as_xoris (REGISTER_O0,reg,0x8000);
		as_lfd (31,8,REGISTER_O1);
		as_stw (REGISTER_O0,4,REGISTER_O1);
		as_lfd (instruction->instruction_parameters[1].parameter_data.reg.r+14,0,REGISTER_O1);
		as_fsub (instruction->instruction_parameters[1].parameter_data.reg.r+14,
				instruction->instruction_parameters[1].parameter_data.reg.r+14,31);
	}
}

static void write_instructions (struct instruction *instructions)
{
	struct instruction *instruction;
	
	for_l (instruction,instructions,instruction_next){
		switch (instruction->instruction_icode){
			case IMOVE:
				as_move_instruction (instruction,SIZE_QBYTE);
				break;
			case ILEA:
				as_lea_instruction (instruction);
				break;
			case IADD:
				as_add_instruction (instruction);
				break;
			case IADDI:
				as_addi_instruction (instruction);
				break;
			case ISUB:
				as_sub_instruction (instruction);
				break;
			case ICMP:
				as_cmp_instruction (instruction);
				break;
			case IJMP:
				as_jmp_instruction (instruction);
				break;
			case IJSR:
				as_jsr_instruction (instruction);
				break;
			case IRTS:
				as_rts_instruction (instruction);
				break;
			case IBEQ:
			case IFBEQ:
				as_branch_instruction (instruction,(12<<21)|(2<<16));
				break;
			case IBGE:
			case IFBGE:
				as_branch_instruction (instruction,(4<<21)|(0<<16));
				break;
			case IBGT:
			case IFBGT:
				as_branch_instruction (instruction,(12<<21)|(1<<16));
				break;
			case IBLE:
			case IFBLE:
				as_branch_instruction (instruction,(4<<21)|(1<<16));
				break;
			case IBLT:
			case IFBLT:
				as_branch_instruction (instruction,(12<<21)|(0<<16));
				break;
			case IBNE:
			case IFBNE:
				as_branch_instruction (instruction,(4<<21)|(2<<16));
				break;
			case IBNEP:
				as_branch_instruction (instruction,(5<<21)|(2<<16));
				break;			
			case IBHS:
				as_index_error_branch_instruction (instruction);
				break;
			case IBNO:
				as_branchno_instruction (instruction);
				break;
			case IBO:
				as_brancho_instruction (instruction);
				break;
			case ICMPLW:
				as_cmplw_instruction (instruction);
				break;
			case ILSLI:
				as_slwi_instruction (instruction);
				break;
			case ILSL:
				as_slw_instruction (instruction);
				break;
			case ILSR:
				as_srw_instruction (instruction);
				break;
			case IASR:
				as_sraw_instruction (instruction);
				break;
			case IMUL:
				as_mul_instruction (instruction);
				break;
			case IDIV:
				as_div_instruction (instruction);
				break;
			case IDIVU:
				as_divu_instruction (instruction);
				break;
			case IREM:
				as_rem_instruction (instruction);
				break;
			case IAND:
				as_and_instruction (instruction);
				break;
			case IOR:
				as_or_instruction (instruction);
				break;
			case IEOR:
				as_xor_instruction (instruction);
				break;
			case ISEQ:
			case IFSEQ:
				as_set_condition_instruction (instruction,(4<<21)|(2<<16));
				break;
			case ISGE:
			case IFSGE:
				as_set_condition_instruction (instruction,(12<<21)|(0<<16));
				break;
			case ISGT:
			case IFSGT:
				as_set_condition_instruction (instruction,(4<<21)|(1<<16));
				break;
			case ISLE:
			case IFSLE:
				as_set_condition_instruction (instruction,(12<<21)|(1<<16));
				break;
			case ISLT:
			case IFSLT:
				as_set_condition_instruction (instruction,(4<<21)|(0<<16));
				break;
			case ISNE:
			case IFSNE:
				as_set_condition_instruction (instruction,(12<<21)|(2<<16));
				break;
			case ISNO:
				as_setno_condition_instruction (instruction);
				break;
			case ISO:
				as_seto_condition_instruction (instruction);
				break;
#if 0
			case ICMPW:
				as_cmpw_instruction (instruction);
				break;
#endif
			case ITST:
				as_tst_instruction (instruction);
				break;
			case IBTST:
				as_btst_instruction (instruction);
				break;
			case IMOVEDB:
				as_move_instruction (instruction,SIZE_DBYTE);
				break;
			case IMOVEB:
				as_move_instruction (instruction,SIZE_BYTE);
				break;
			case IEXTB:
				as_extb_instruction (instruction);
				break;
			case INEG:
				as_neg_instruction (instruction);
				break;
			case INOT:
				as_not_instruction (instruction);
				break;
			case IFABS:
				as_fabs_instruction (instruction);
				break;				
			case IFMOVE:
				instruction=as_fmove_instruction (instruction);
				break;
			case IFADD:
				as_fadd_instruction (instruction);
				break;
			case IFCMP:
				as_compare_float_instruction (instruction);
				break;
			case IFDIV:
				as_fdiv_instruction (instruction);
				break;
			case IFMUL:
#ifdef FMADD
				instruction=as_fmul_instruction (instruction);
#else
				as_fmul_instruction (instruction);
#endif
				break;
			case IFNEG:
				as_fneg_instruction (instruction);
				break;				
			case IFSUB:
				as_fsub_instruction (instruction);
				break;
			case IFMOVEL:
				as_fmovel_instruction (instruction);
				break;
			case IWORD:
				store_instruction (instruction->instruction_parameters[0].parameter_data.i);
				break;
			case IMTCTR:
				as_mtctr (instruction->instruction_parameters[0].parameter_data.reg.r);
				break;
			case IJMPP:
				as_jmpp_instruction (instruction);
				break;
			case IRTSP:
				as_rtsp_instruction (instruction);
				break;
			case IADDO:
				as_addo_instruction (instruction);
				break;
			case ISUBO:
				as_subo_instruction (instruction);
				break;
			case IMULO:
				as_mulo_instruction (instruction);
				break;
			case IUMULH:
				as_umulh_instruction (instruction);
				break;
			default:
				internal_error_in_function ("write_instructions");
		}
	}
}

static void as_garbage_collect_test (register struct basic_block *block)
{
	LONG n_cells;
	struct call_and_jump *new_call_and_jump;

	new_call_and_jump=allocate_new_call_and_jump();

	n_cells= -block->block_n_new_heap_cells;	
	
	if (n_cells!=(WORD) n_cells){
		as_addis (REGISTER_D7,REGISTER_D7,(n_cells-(WORD)n_cells)>>16);
		n_cells=(WORD)n_cells;
	}

	as_addic_ (REGISTER_D7,REGISTER_D7,n_cells);

#ifdef USE_DCBZ
	as_dcbz (REGISTER_A6,REGISTER_R9);
#endif
	
	if (block->block_gc_kind!=0){		
		switch (block->block_n_begin_a_parameter_registers){
			case 0:		new_call_and_jump->cj_call_label=collect_00_label;	break;
			case 1:		new_call_and_jump->cj_call_label=collect_01_label;	break;
			case 2:		new_call_and_jump->cj_call_label=collect_02_label;	break;
			case 3:		new_call_and_jump->cj_call_label=collect_03_label;	break;
			default:	internal_error_in_function ("as_garbage_collect_test");
		}
		new_call_and_jump->cj_label.label_flags=0;

		if (block->block_gc_kind==2)
			as_mflr (REGISTER_R0);

		as_bc ((12/* 13 */<<21)|(0<<16)|1); /* bltl */
		as_branch_label (&new_call_and_jump->cj_label,CONDITIONAL_BRANCH_RELOCATION);
		
		if (block->block_gc_kind==1)
			as_mtlr (REGISTER_R0);

		new_call_and_jump->cj_jump_label.label_object_label=code_csect_object_label;
		new_call_and_jump->cj_jump_label.label_flags=FAR_CONDITIONAL_JUMP_LABEL;
	} else {	
		switch (block->block_n_begin_a_parameter_registers){
			case 0:		new_call_and_jump->cj_call_label=collect_0_label;	break;
			case 1:		new_call_and_jump->cj_call_label=collect_1_label;	break;
			case 2:		new_call_and_jump->cj_call_label=collect_2_label;	break;
			case 3:		new_call_and_jump->cj_call_label=collect_3_label;	break;
			default:	internal_error_in_function ("as_garbage_collect_test");
		}
		new_call_and_jump->cj_label.label_flags=0;
		
		as_bc ((12<<21)|(0<<16)); /* blt */
		as_branch_label (&new_call_and_jump->cj_label,CONDITIONAL_BRANCH_RELOCATION);
	
		new_call_and_jump->cj_jump_label.label_flags=0;
		new_call_and_jump->cj_jump_label.label_object_label=code_csect_object_label;
		new_call_and_jump->cj_jump_label.label_offset=CURRENT_CODE_OFFSET;
	}
}

static void as_check_stack (struct basic_block *block)
{
#ifdef SEPARATE_A_AND_B_STACK_OVERFLOW_CHECKS
	if (block->block_a_stack_check_size>0){		
		as_load_label (end_a_stack_label,0,REGISTER_O0);

		as_addi (REGISTER_O1,A_STACK_POINTER,block->block_a_stack_check_size);
		
		as_lwz (REGISTER_O0,0,REGISTER_O0);
		as_cmp (REGISTER_O1,REGISTER_O0);

		as_bc ((5<<21)|(1<<16)|8); /* ble+ */
		as_b();
		as_branch_label (stack_overflow_label,BRANCH_RELOCATION);
	}
	if (block->block_b_stack_check_size>0){		
		as_load_label (end_b_stack_label,0,REGISTER_O0);

		as_addi (REGISTER_O1,B_STACK_POINTER,-block->block_b_stack_check_size);
		
		as_lwz (REGISTER_O0,0,REGISTER_O0);
		as_cmp (REGISTER_O1,REGISTER_O0);

		as_bc ((13<<21)|(1<<16)|8);	/* bgt+ */
		as_b();
		as_branch_label (stack_overflow_label,BRANCH_RELOCATION);
	}
#else
	int size;

	size=block->block_stack_check_size+1024;

	as_sub (REGISTER_O0,B_STACK_POINTER,A_STACK_POINTER);
	as_cmpi (REGISTER_O0,size);
	as_bc ((13<<21)|(1<<16)|8);	/* bgt+ */
	as_b();
	as_branch_label (stack_overflow_label,BRANCH_RELOCATION);
#endif
}

static void as_import_labels (struct label_node *label_node)
{
	LABEL *label;
	
	if (label_node==NULL)
		return;
	
	label=&label_node->label_node_label;
	
	if (!(label->label_flags & LOCAL_LABEL) && label->label_number==0){
		struct object_label *new_object_label;
		int string_length;
		
		new_object_label=fast_memory_allocate_type (struct object_label);
		*last_object_label_l=new_object_label;
		last_object_label_l=&new_object_label->next;
		new_object_label->next=NULL;
		
		new_object_label->object_label_label=label;
		new_object_label->object_label_number=n_object_labels;

		label->label_object_label=new_object_label;
		label->label_offset=0;

		++n_object_labels;

		string_length=strlen (label->label_name);
#ifdef XCOFF
		if (string_length<8)
			new_object_label->object_label_string_offset=0;
		else {
#endif
			new_object_label->object_label_string_offset=string_table_offset;
			string_table_offset+=string_length+1;
#ifdef XCOFF
		}
#endif

		new_object_label->kind=IMPORTED_CODE_LABEL;
	}
	
	as_import_labels (label_node->label_node_left);
	as_import_labels (label_node->label_node_right);
}

static void as_profile_call (struct basic_block *block)
{
	LABEL *profile_label;
	
	if (profile_table_flag){
		as_load_label (profile_table_label,32764,REGISTER_R3);
		as_mflr (REGISTER_R0);
		as_addi (REGISTER_R3,REGISTER_R3,block->block_profile_function_label->label_arity-32764);
	} else {
		as_load_label (block->block_profile_function_label,0,REGISTER_R3);
		as_mflr (REGISTER_R0);
	}
	as_bl();
	
	if (block->block_n_node_arguments>-100)
		profile_label=block->block_profile==2 ? profile_n2_label : profile_n_label;
	else {
		switch (block->block_profile){
			case 2:  profile_label=profile_s2_label; break;
			case 4:  profile_label=profile_l_label;  break;
			case 5:  profile_label=profile_l2_label; break;
			default: profile_label=profile_s_label;
		}
	}
	as_branch_label (profile_label,BRANCH_RELOCATION);
}

#ifdef NEW_APPLY
extern LABEL *add_empty_node_labels[];

static void as_apply_update_entry (struct basic_block *block)
{
	if (block->block_profile)
		as_profile_call (block);

	if (block->block_n_node_arguments==-200){
		as_b();
		as_branch_label (block->block_ea_label,BRANCH_RELOCATION);
		as_nop();
		as_nop();
		as_nop();
	} else {
		as_mflr (REGISTER_R0);
		as_bl();
		as_branch_label (add_empty_node_labels[block->block_n_node_arguments+200],BRANCH_RELOCATION);
		as_mtlr (REGISTER_R0);
		as_b();
		as_branch_label (block->block_ea_label,BRANCH_RELOCATION);
	}
}
#endif

static void write_code (void)
{
	struct basic_block *block;

	first_call_and_jump=NULL;
#ifdef G_MACH_O
	first_stub=NULL;
	next_stub_l=&first_stub;
	n_stubs=0;
#endif

	if (!(first_block->block_begin_module && !first_block->block_link_module))
		as_new_code_module();

	for_l (block,first_block,block_next){
		if (block->block_begin_module){
			if (block->block_link_module){
#if defined (XCOFF) || defined (G_MACH_O_SCATTERED)
				if (code_csect_object_label!=NULL 
					&& CURRENT_CODE_OFFSET!=code_csect_object_label->object_label_offset
					&& block->block_labels)
				{
					as_branch_label (block->block_labels->block_label_label,DUMMY_CONDITIONAL_BRANCH_RELOCATION);
					as_new_code_module();
				}
#endif
			} else {
				if (first_call_and_jump!=NULL){
					struct call_and_jump *call_and_jump;
					struct object_label *gc_test_csect_object_label;
	
					gc_test_csect_object_label=code_csect_object_label;
					
					for_l (call_and_jump,first_call_and_jump,cj_next){
						if (call_and_jump->cj_jump_label.label_object_label!=gc_test_csect_object_label){
							as_new_code_module();
							gc_test_csect_object_label=call_and_jump->cj_jump_label.label_object_label;
						}
						as_call_and_jump (call_and_jump);
					}
			
					first_call_and_jump=NULL;
				}
	
				as_new_code_module();
			}
		}
		
		if (block->block_n_node_arguments>-100){
			if (block->block_ea_label!=NULL){
				int n_node_arguments;
				extern LABEL *eval_fill_label,*eval_upd_labels[];
				
				n_node_arguments=block->block_n_node_arguments;

				if (n_node_arguments<-2)
					n_node_arguments=1;
				
				if (n_node_arguments>=0 && block->block_ea_label!=eval_fill_label){
					as_load_label (block->block_ea_label,0,REGISTER_A2);

					if (!block->block_profile){					
						as_b();
						as_branch_label (eval_upd_labels[n_node_arguments],BRANCH_RELOCATION);

						as_nop();
#if defined (ELF) || defined (G_MACH_O)
						as_nop();
#endif
					} else {
						if (profile_table_flag){
							store_instruction ((18<<26) | ((-8) & 0x3fffffc));
							as_branch_label (eval_upd_labels[n_node_arguments],BRANCH_RELOCATION);

							as_load_label (profile_table_label,32764,REGISTER_R3);	
							as_addi (REGISTER_R3,REGISTER_R3,block->block_profile_function_label->label_arity-32764);
							store_instruction ((18<<26)|(-16 & 0x3fffffc));
						} else {
							as_load_label (block->block_profile_function_label,0,REGISTER_R3);

							store_instruction ((18<<26) | ((-8) & 0x3fffffc));
							as_branch_label (eval_upd_labels[n_node_arguments],BRANCH_RELOCATION);
						}
					}
				} else {
					as_b();
					as_branch_label (block->block_ea_label,BRANCH_RELOCATION);
					
					as_nop();
					as_nop();
#if defined (ELF) || defined (G_MACH_O)
					as_nop();
					as_nop();
#endif
				}
				
				if (block->block_descriptor!=NULL && 
					(block->block_n_node_arguments<0 || parallel_flag || module_info_flag))
				{
#if defined (ELF) || defined (G_MACH_O)
					store_label_in_code_section (block->block_descriptor,0);
#else
					as_load_label1 (block->block_descriptor,0,REGISTER_R0,TOC_RELOCATION);
#endif
					/* store_instruction (0); */
				} else
					store_instruction (0);
			} else
				if (block->block_descriptor!=NULL &&
					(block->block_n_node_arguments<0 || parallel_flag || module_info_flag))
				{
#if defined (ELF) || defined (G_MACH_O)
					store_label_in_code_section (block->block_descriptor,0);
#else
					as_load_label1 (block->block_descriptor,0,REGISTER_R0,TOC_RELOCATION);
#endif
					/* store_instruction (0); */
				}
				/* else
					store_instruction (0);
				*/

			store_instruction (block->block_n_node_arguments);
		}
#ifdef NEW_APPLY
		else if (block->block_n_node_arguments<-100)
			as_apply_update_entry (block);
#endif

		as_labels (block->block_labels);

		if (block->block_profile)
			as_profile_call (block);

		if (block->block_n_new_heap_cells!=0)
			as_garbage_collect_test (block);

		if (check_stack
#ifdef SEPARATE_A_AND_B_STACK_OVERFLOW_CHECKS
			&& (block->block_a_stack_check_size>0 || block->block_b_stack_check_size>0)
#else
			&& block->block_stack_check_size>0
#endif
			)
			as_check_stack (block);
		write_instructions (block->block_instructions);
	}

	{
		struct call_and_jump *call_and_jump;

		for_l (call_and_jump,first_call_and_jump,cj_next)
			as_call_and_jump (call_and_jump);
	}
}

void initialize_assembler (FILE *output_file_d)
{
	output_file=output_file_d;
#ifdef ELF
	n_object_labels=0;
#else
	n_object_labels=0;
#endif
	setvbuf (output_file,NULL,_IOFBF,IO_BUFFER_SIZE);

	first_object_label=NULL;
	last_object_label_l=&first_object_label;

	code_csect_object_label=NULL;
	data_csect_object_label=NULL;
#ifdef G_MACH_O
	stub_csect_object_label=NULL;	
#endif
	
	first_code_relocation=NULL;
	first_data_relocation=NULL;
	last_code_relocation_l=&first_code_relocation;
	last_data_relocation_l=&first_data_relocation;
	n_code_relocations=0;
	n_data_relocations=0;
#ifdef ELF
	string_table_offset=13;
#else
	string_table_offset=4;
#endif
	initialize_buffers();
}

static void relocate_branches (void)
{
	struct relocation *relocation,**relocation_p;
	struct object_buffer *object_buffer;
	int buffer_offset;
	struct label *label;
	int instruction_offset;
	ULONG *instruction_p;
	
	object_buffer=first_code_buffer;
	buffer_offset=0;
	
	relocation_p=&first_code_relocation;
	
	while (relocation=*relocation_p,relocation!=NULL){
		switch (relocation->kind){
			case CONDITIONAL_BRANCH_RELOCATION:
				label=relocation->relocation_label;
				if (label->label_object_label==NULL)
					internal_error_in_function ("relocate_branches");
			
				instruction_offset=relocation->offset;
				while (instruction_offset >= buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					buffer_offset+=BUFFER_SIZE;
				}
				
				instruction_p=(ULONG*)((char*)(object_buffer->data)+(instruction_offset-buffer_offset));

				*instruction_p= ((*instruction_p)& 0xffff0003) | (label->label_offset-instruction_offset & 0xfffc);

				if (label->label_object_label->object_label_number==relocation->relocation_object_label->object_label_number){
					*relocation_p=relocation->next;
					--n_code_relocations;
					continue;
				}
				break;
			case BRANCH_RELOCATION:
				label=relocation->relocation_label;
				if (label->label_object_label==NULL)
					internal_error_in_function ("relocate_branches");

				instruction_offset=relocation->offset;
				while (instruction_offset >= buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					buffer_offset+=BUFFER_SIZE;
				}
				
				instruction_p=(ULONG*)((char*)(object_buffer->data)+(instruction_offset-buffer_offset));

				*instruction_p = ((*instruction_p) & 0xfc000003) | ((*instruction_p+label->label_offset-instruction_offset) & 0x3fffffc);
			
				if (label->label_object_label->object_label_number==relocation->relocation_object_label->object_label_number){
					*relocation_p=relocation->next;
					--n_code_relocations;
					continue;
				}
				break;
			case DUMMY_CONDITIONAL_BRANCH_RELOCATION:
				label=relocation->relocation_label;
				if (label->label_object_label==NULL)
					internal_error_in_function ("relocate_branches");

				if (label->label_object_label->object_label_number==relocation->relocation_object_label->object_label_number){
					*relocation_p=relocation->next;
					--n_code_relocations;
					continue;
				}
				break;
#ifdef G_MACH_O
			case HIGH_RELOCATION:
			{
				int addend;

				label=relocation->relocation_label;
				if (label->label_object_label==NULL)
					internal_error_in_function ("relocate_branches");

				addend=relocation->relocation_addend+label->label_offset;
				if (label->label_object_label->kind==DATA_CONTROL_SECTION || label->label_object_label->kind==EXPORTED_DATA_LABEL)
					addend+=code_buffer_offset;

				addend=(addend-(WORD)addend)>>16;
				
				if (addend!=0){
					UWORD *instruction_w_p;
					
					instruction_offset=relocation->offset;
					while (instruction_offset >= buffer_offset+BUFFER_SIZE){
						object_buffer=object_buffer->next;
						buffer_offset+=BUFFER_SIZE;
					}
					
					instruction_w_p=(UWORD*)((char*)(object_buffer->data)+(instruction_offset-buffer_offset));
					instruction_w_p[1]+=addend;
				}
				break;
			}
			case LOW_RELOCATION:
			{
				int addend;

				label=relocation->relocation_label;
				if (label->label_object_label==NULL)
					internal_error_in_function ("relocate_branches");

				addend=relocation->relocation_addend+label->label_offset;			
				if (label->label_object_label->kind==DATA_CONTROL_SECTION || label->label_object_label->kind==EXPORTED_DATA_LABEL)
					addend+=code_buffer_offset;

				addend=((unsigned)addend) & 0xffff;
				
				if (addend!=0){
					UWORD *instruction_w_p;

					instruction_offset=relocation->offset;
					while (instruction_offset >= buffer_offset+BUFFER_SIZE){
						object_buffer=object_buffer->next;
						buffer_offset+=BUFFER_SIZE;
					}
					
					instruction_w_p=(UWORD*)((char*)(object_buffer->data)+(instruction_offset-buffer_offset));
					instruction_w_p[1]+=addend;
				}
				
				break;
			}
			case LONG_WORD_RELOCATION:
			{
				int addend;
				
				label=relocation->relocation_label;
				if (label->label_object_label==NULL)
					internal_error_in_function ("relocate_branches");

				addend=relocation->relocation_addend+label->label_offset;
				if (label->label_object_label->kind==DATA_CONTROL_SECTION || label->label_object_label->kind==EXPORTED_DATA_LABEL)
					addend+=code_buffer_offset;
				
				if (addend!=0){
					int data_offset;
					
					data_offset=relocation->offset;
					while (data_offset >= buffer_offset+BUFFER_SIZE){
						object_buffer=object_buffer->next;
						buffer_offset+=BUFFER_SIZE;
					}
	
					*(ULONG*)((char*)(object_buffer->data)+(data_offset-buffer_offset)) += addend;
				}
				break;
			}
#endif
		}

		relocation_p=&relocation->next;
	}
}

static void relocate_data (void)
{
	struct relocation *relocation;
	struct object_buffer *object_buffer;
	int data_buffer_offset;

	object_buffer=first_data_buffer;
	data_buffer_offset=0;
	
	for_l (relocation,first_data_relocation,next){
		struct label *label;

		label=relocation->relocation_label;

		if (label->label_object_label==NULL)
			internal_error_in_function ("relocate_data");
#ifdef XCOFF
		if (relocation->kind==LONG_WORD_RELOCATION && label->label_offset!=0){
#else
# ifdef G_MACH_O
		if (relocation->kind==LONG_WORD_RELOCATION){
			int addend;

			addend=relocation->relocation_addend+label->label_offset;
			if (label->label_object_label->kind==DATA_CONTROL_SECTION || label->label_object_label->kind==EXPORTED_DATA_LABEL)
				addend+=code_buffer_offset;
			if (addend!=0){
# else
		if (relocation->kind==LONG_WORD_RELOCATION && relocation->relocation_addend+label->label_offset!=0){
# endif
#endif
			int data_offset;
			
			data_offset=relocation->offset;
			while (data_offset >= data_buffer_offset+BUFFER_SIZE){
				object_buffer=object_buffer->next;
				data_buffer_offset+=BUFFER_SIZE;
			}

#ifdef G_MACH_O
			*(ULONG*)((char*)(object_buffer->data)+(data_offset-data_buffer_offset)) += addend;
			}
#else
			*(ULONG*)((char*)(object_buffer->data)+(data_offset-data_buffer_offset)) += label->label_offset;
#endif
		}
	}
}

#ifdef ELF
static void write_zstring (char *string)
{
    char c;

    do {
        c=*string++;
        write_c (c);
    } while (c!='\0');
}
#endif

#ifdef G_MACH_O
static void write_string_16 (char *string)
{
	int i;

	i=0;

	while (i<16){
		char c;
		
		c=string[i++];
		write_c (c);
		
		if (c=='\0'){
			while (i<16){
				write_c ('\0');
				++i;
			}
			return;
		}
	}
}
#endif

static void write_file_header_and_section_headers (void)
{
#ifdef ELF
	unsigned int offset;
	
    /* header: */
    write_l (0x7f454c46);
    write_l (0x01020100);
    write_l (0);
    write_l (0);
    write_l (0x00010014);
    write_l (1);
    write_l (0);
    write_l (0);
    write_l (0x34);
    write_l (0);
    write_l (0x00340000);
    write_l (0x00000028);
    write_l (0x00080001);
	offset=0x174;
    /* offet 0x34: section header 0 */
    write_l (0);
    write_l (0);
    write_l (0);
    write_l (0);
    write_l (0);
    write_l (0);
    write_l (0);
    write_l (0);
    write_l (0);
    write_l (0);
    /* offset 0x5c: section header 1 */
    write_l (1);     /* .shstrtab offset */
    write_l (SHT_STRTAB);
    write_l (0);
    write_l (0);
    write_l (offset); /* offset */
    write_l (64);    /* size */
    write_l (0);
    write_l (0);
    write_l (1);     /* align */
    write_l (0);
	offset+=64;
    /* offset 0x84: section header 2 */
    write_l (11);					/* .text offset */
    write_l (SHT_PROGBITS);
    write_l (SHF_ALLOC | SHF_EXECINSTR);
    write_l (0);
    write_l (offset);				/* offset */
    write_l (code_buffer_offset);   /* size */
    write_l (0);
    write_l (0);
    write_l (4);					/* align */
    write_l (0);
	offset+=code_buffer_offset;
    /* offset 0xac: section header 3 */
    write_l (17);  						/* .data offset */
    write_l (SHT_PROGBITS);
    write_l (SHF_ALLOC | SHF_WRITE);
    write_l (0);
    write_l (offset); 					 /* offset */
    write_l (data_buffer_offset);	     /* size */
    write_l (0);
    write_l (0);
    write_l (4);    					 /* align */
    write_l (0);
	offset+=data_buffer_offset;
    /* offet 0xd4: section header 4 */
    write_l (23); 					 	/* .rela.text offset */
    write_l (SHT_RELA);
    write_l (0);
    write_l (0);
    write_l (offset); 					/* offset */
    write_l (12*n_code_relocations);     /* size */
    write_l (6);						/* symbol table index */
    write_l (2);						/* text section index */
    write_l (4);    					/* align */
    write_l (12);
	offset+=12*n_code_relocations;
    /* offset 0xfc: section header 5 */
    write_l (34);  						/* .rela.data offset */
    write_l (SHT_RELA);
    write_l (0);
    write_l (0);
    write_l (offset); /* offset */
    write_l (12*n_data_relocations);     /* size */
    write_l (6);						/* symbol table index */
    write_l (3);						/* data section index */
    write_l (4);  						/* align */
    write_l (12);
	offset+=12*n_data_relocations;
    /* offset 0x124: section header 6 */
    write_l (45);   /* .symtab offset */
    write_l (SHT_SYMTAB);
    write_l (0);
    write_l (0);
    write_l (offset);					/* offset */
    write_l (16*n_object_labels);		/* size */
    write_l (7);						/* string table index */
    write_l (3);
    write_l (4); 						/* align */
    write_l (16);
	offset+=16*n_object_labels;
    /* offset 0x14c: section header 7 */
    write_l (53);  						/* .strtab offset */
    write_l (SHT_STRTAB);
    write_l (0);
    write_l (0);
    write_l (offset);					/* offset */
    write_l (string_table_offset);	 	/* size */
    write_l (0);
    write_l (0);
    write_l (0);  						/* align */
    write_l (0);

    /* offset 0x174: section 1 */
    write_c (0);
    write_zstring (".shstrtab"); /* 1 */
    write_zstring (".text");     /* 11 */
    write_zstring (".data");     /* 17 */
    write_zstring (".rela.text");/* 23 */
    write_zstring (".rela.data");/* 34 */
    write_zstring (".symtab");   /* 45 */
    write_zstring (".strtab");   /* 53 */
                                 /* 61 */
	write_c (0);
	write_c (0);
	write_c (0);
	/* offset 0x1b4 */
#else
# ifdef G_MACH_O
	int segment_command_size;
	int text_section_offset,text_section_relocation_offset;

	segment_command_size = n_stubs!=0 ? sizeof (struct segment_command)+4*sizeof (struct section)
									  : sizeof (struct segment_command)+2*sizeof (struct section);

	write_l (MH_MAGIC);
	write_l (0x12/*PPC*/);
	write_l (0/*ALL*/);
	write_l (MH_OBJECT);
	write_l (3);
	write_l (segment_command_size+sizeof (struct symtab_command)+sizeof (struct dysymtab_command));
	write_l (0);

	text_section_offset=sizeof (struct mach_header)+segment_command_size+sizeof (struct symtab_command)+sizeof (struct dysymtab_command);

	write_l (LC_SEGMENT);
	write_l (segment_command_size);
	write_string_16 ("\0");
	write_l (0);
	write_l (code_buffer_offset+data_buffer_offset+(36+4)*n_stubs);
	write_l (text_section_offset);
	write_l (code_buffer_offset+data_buffer_offset+(36+4)*n_stubs);
	write_l (VM_PROT_ALL);
	write_l (VM_PROT_ALL);
	write_l (n_stubs!=0 ? 4 : 2);
	write_l (0);

	text_section_relocation_offset=text_section_offset+code_buffer_offset+data_buffer_offset+(36+4)*n_stubs;

	write_string_16 ("__text");
	write_string_16 ("__TEXT");
	write_l (0);
	write_l (code_buffer_offset);
	write_l (text_section_offset);
	write_l (0);
	write_l (text_section_relocation_offset);
	write_l (n_code_relocations);
	write_l (S_REGULAR | S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS);
	write_l (0);
	write_l (0);

	write_string_16 ("__data");
	write_string_16 ("__DATA");
	write_l (code_buffer_offset);
	write_l (data_buffer_offset);
	write_l (text_section_offset+code_buffer_offset);
	write_l (0);
	write_l (text_section_relocation_offset+8*n_code_relocations);
	write_l (n_data_relocations);
	write_l (S_REGULAR);
	write_l (0);
	write_l (0);

	if (n_stubs!=0){
		write_string_16 ("__picsymbol_stub");
		write_string_16 ("__TEXT");
		write_l (code_buffer_offset+data_buffer_offset);
		write_l (n_stubs*36);
		write_l (text_section_offset+code_buffer_offset+data_buffer_offset);
		write_l (2);
		write_l (text_section_relocation_offset+8*(n_code_relocations+n_data_relocations));
		write_l (6*n_stubs);
		write_l (S_SYMBOL_STUBS | S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS);
		write_l (0);
		write_l (36);

		write_string_16 ("__la_symbol_ptr");
		write_string_16 ("__DATA");
		write_l (code_buffer_offset+data_buffer_offset+n_stubs*36);
		write_l (n_stubs<<2);
		write_l (text_section_offset+code_buffer_offset+data_buffer_offset+n_stubs*36);
		write_l (2);
		write_l (text_section_relocation_offset+8*(n_code_relocations+n_data_relocations+6*n_stubs));
		write_l (n_stubs);
		write_l (S_LAZY_SYMBOL_POINTERS);
		write_l (0);
		write_l (0);
	}

	write_l (LC_SYMTAB);
	write_l (sizeof (struct symtab_command));
	write_l (text_section_relocation_offset+8*(n_code_relocations+n_data_relocations+(6+1+1)*n_stubs));
	write_l (n_object_labels);
	write_l (text_section_relocation_offset+8*(n_code_relocations+n_data_relocations+(6+1+1)*n_stubs)+12*n_object_labels);
	write_l (string_table_offset);

	write_l (LC_DYSYMTAB);
	write_l (sizeof (struct dysymtab_command));
#  ifdef G_MACH_O_SCATTERED
	write_l (0);
	write_l (n_section_object_labels);
	write_l (n_section_object_labels);
	write_l (n_exported_object_labels);
	write_l (n_section_object_labels+n_exported_object_labels);
	write_l (n_object_labels-n_section_object_labels-n_exported_object_labels);
#  else
	write_l (0);
	write_l (0);
	write_l (0);
	write_l (n_exported_object_labels);
	write_l (n_exported_object_labels);
	write_l (n_object_labels-n_exported_object_labels);
#  endif
	write_l (0);
	write_l (0);
	write_l (0);
	write_l (0);
	write_l (0);
	write_l (0);
	write_l (text_section_relocation_offset+8*(n_code_relocations+n_data_relocations+(6+1)*n_stubs));
	write_l (2*n_stubs);
	write_l (0);
	write_l (0);
	write_l (0);
	write_l (0);
# else
	int data_section_length;

	data_section_length=data_buffer_offset+4*t_label_number;
	
	write_w (0x01df);
	write_w (2);
	write_l (0);
	write_l (100+code_buffer_offset+data_section_length+(n_code_relocations+n_data_relocations+t_label_number)*10);
	write_l ((n_object_labels+1+t_label_number)<<1);
	write_w (0);
	write_w (0);
	
	write_c ('.');
	write_c ('t');
	write_c ('e');
	write_c ('x');
	write_c ('t');
	write_c (0);
	write_c (0);
	write_c (0);

	write_l (0);
	write_l (0);
	write_l (code_buffer_offset);
	write_l (100);
	write_l (100+code_buffer_offset+data_section_length);
	write_l (0);
	write_w (n_code_relocations);
	write_w (0);
	write_l (0x20);
	
	write_c ('.');
	write_c ('d');
	write_c ('a');
	write_c ('t');
	write_c ('a');
	write_c (0);
	write_c (0);
	write_c (0);

	write_l (0);
	write_l (0);
	write_l (data_section_length);
	write_l (100+code_buffer_offset);
	write_l (100+code_buffer_offset+data_section_length+n_code_relocations*10);
	write_l (0);
	write_w (n_data_relocations+t_label_number);
	write_w (0);
	write_l (0x40);
# endif
#endif
}

#ifdef XCOFF
static void write_toc (struct toc_label *toc_labels)
{
	struct toc_label *toc_label;
	
	for_l (toc_label,toc_labels,toc_next){
		struct label *label;

		label=toc_label->toc_label_label;
		
		if (label->label_object_label==NULL)
			internal_error_in_function ("write_toc");
		
		write_l (toc_label->toc_label_offset+label->label_offset);
	}
}
#endif

static void store_references (void)
{
	struct relocation *relocation,**relocation_p;
	
	for (relocation_p=&first_code_relocation; (relocation=*relocation_p)!=NULL; relocation_p=&relocation->next){
		struct label *label;
		struct object_label *object_label;
		
		switch (relocation->kind){
			case CONDITIONAL_BRANCH_RELOCATION:
			case DUMMY_CONDITIONAL_BRANCH_RELOCATION:
			case BRANCH_RELOCATION:
#ifndef XCOFF
			case HIGH_RELOCATION:
			case LOW_RELOCATION:
			case LONG_WORD_RELOCATION:
#endif
				label=relocation->relocation_label;
				object_label=label->label_object_label;
				break;
#ifdef XCOFF
			case TOC_RELOCATION:
			case TRL_RELOCATION:
				label=relocation->relocation_toc_label->toc_label_label;
				object_label=label->label_object_label;
				break;
#endif
			default:
				internal_error_in_function ("store_references");
		}

		if (object_label==NULL)
			internal_error_in_function ("store_references");

		if (object_label->kind==CODE_CONTROL_SECTION){
			int label_reference,relocation_label_n,label_n;
			
			label_n=object_label->object_label_number;
			relocation_label_n=relocation->relocation_object_label->object_label_number;
			
			label_reference=object_label->object_label_reference;
			
			if (relocation_label_n!=label_n){
				if (label_reference==-1)
					object_label->object_label_reference=relocation_label_n;
				else if (label_reference!=relocation_label_n)
					object_label->object_label_reference=-2;
			}
		}
	}

	for_l (relocation,first_data_relocation,next){
		struct label *label;
		struct object_label *object_label;
		
		label=relocation->relocation_label;
		object_label=label->label_object_label;

		if (object_label==NULL)
			internal_error_in_function ("store_references");

		if (relocation->kind==LONG_WORD_RELOCATION && label->label_offset!=0 && object_label->kind==CODE_CONTROL_SECTION)
			label->label_object_label->object_label_reference=-2;
	}
}

#ifdef G_MACH_O_SCATTERED
int first_module_string_offset;
#endif

static void renumber_object_labels_and_calculate_section_sizes (void)
{
	struct object_label *object_label,*previous_code_object_label,*previous_data_object_label;
#if defined (ELF) || defined (G_MACH_O)
	int section_object_label_n;
# ifdef G_MACH_O
	int first_section_object_label_n;
# endif
#endif

	previous_code_object_label=NULL;
	
	for_l (object_label,first_object_label,next){
		if (object_label->kind==CODE_CONTROL_SECTION){
			if (previous_code_object_label!=NULL){
				int reference1,reference2;
				
				reference1=previous_code_object_label->object_label_reference;
				reference2=object_label->object_label_reference;
				
				if (reference2!=-2){
					if (	reference2==previous_code_object_label->object_label_number
						||	reference1==object_label->object_label_number
						||	(reference1>=0 && reference2>=0 && reference1==reference2)
					){
						object_label->kind=MERGED_CODE_CONTROL_SECTION;
					}
				}
			}
			
			previous_code_object_label=object_label;			
		}
	}
	
#ifdef ELF
	section_object_label_n=n_object_labels;
	n_object_labels=3;
#else
# ifdef G_MACH_O
	section_object_label_n=n_object_labels;
	first_section_object_label_n=section_object_label_n;
# endif
	n_object_labels=0;
#endif

#ifdef G_MACH_O_SCATTERED
	first_module_string_offset=string_table_offset;
#endif

	previous_data_object_label=NULL;
	previous_code_object_label=NULL;

	for_l (object_label,first_object_label,next){
		switch (object_label->kind){
			case CODE_CONTROL_SECTION:
#ifndef XCOFF
				object_label->object_label_number=section_object_label_n;
				++section_object_label_n;
# ifdef G_MACH_O_SCATTERED
				string_table_offset+=14;
# endif
#else
				object_label->object_label_number=n_object_labels;
				++n_object_labels;
#endif
				if (previous_code_object_label!=NULL)
					previous_code_object_label->object_label_size=object_label->object_label_offset-previous_code_object_label->object_label_offset;
				previous_code_object_label=object_label;
				break;
			case DATA_CONTROL_SECTION:
#ifndef XCOFF
				object_label->object_label_number=section_object_label_n;
				++section_object_label_n;
# ifdef G_MACH_O_SCATTERED
				string_table_offset+=14;
# endif
#else
				object_label->object_label_number=n_object_labels;
				++n_object_labels;
#endif
				if (previous_data_object_label!=NULL)
					previous_data_object_label->object_label_size=object_label->object_label_offset-previous_data_object_label->object_label_offset;
				previous_data_object_label=object_label;
				break;
			case IMPORTED_CODE_LABEL:
#ifdef G_MACH_O
				break;
#endif
			case EXPORTED_CODE_LABEL:
			case EXPORTED_DATA_LABEL:
				object_label->object_label_number=n_object_labels;
				++n_object_labels;
				break;
			case MERGED_CODE_CONTROL_SECTION:
				object_label->object_label_number=previous_code_object_label->object_label_number;
				break;
			default:
				internal_error_in_function ("renumber_object_labels_and_calculate_section_sizes");
		}
	}

#ifdef G_MACH_O
	n_section_object_labels=section_object_label_n-first_section_object_label_n;
	n_exported_object_labels=n_object_labels;
# ifdef G_MACH_O_SCATTERED
	n_object_labels=n_section_object_labels;
	for_l (object_label,first_object_label,next){
		if (object_label->kind==EXPORTED_CODE_LABEL || object_label->kind==EXPORTED_DATA_LABEL){
			object_label->object_label_number=n_object_labels;
			++n_object_labels;
		}
	}
# endif
	for_l (object_label,first_object_label,next)
		if (object_label->kind==IMPORTED_CODE_LABEL){
			object_label->object_label_number=n_object_labels;
			++n_object_labels;
		}
#endif

	if (previous_code_object_label!=NULL)
		previous_code_object_label->object_label_size=code_buffer_offset-previous_code_object_label->object_label_offset;

	if (previous_data_object_label!=NULL)
		previous_data_object_label->object_label_size=data_buffer_offset-previous_data_object_label->object_label_offset;
}

#define R_POS 0
#define R_TOC 3
#define R_TRL 0x12 /* 4 */
#define R_BR 10
#define R_REF 15

#ifdef ELF
static void write_relocation_label_number_and_addend (struct label *label,int relocation_type,long addend)
{
	struct object_label *object_label;

	object_label=label->label_object_label;
	
	if (object_label->kind==IMPORTED_CODE_LABEL)
		write_l (ELF32_R_INFO (object_label->object_label_number,relocation_type));
	else if (object_label==code_csect_object_label){
		write_l (ELF32_R_INFO (1,relocation_type));
		addend+=label->label_offset;
	} else if (object_label==data_csect_object_label){
		write_l (ELF32_R_INFO (2,relocation_type));
		addend+=label->label_offset;
	} else
		internal_error_in_function ("write_relocation_label_number_and_addend");

	write_l (addend);
}
#endif

#ifdef G_MACH_O
static void write_relocation_symbol_number_and_kind (struct label *label,int relocation_type)
{
	struct object_label *object_label;
	int label_or_section_number;

	object_label=label->label_object_label;
	
	if (object_label->kind==IMPORTED_CODE_LABEL){
		label_or_section_number=object_label->object_label_number;
		relocation_type |= 1<<4;
	} else if (object_label==code_csect_object_label)
		label_or_section_number=1;
	else if (object_label==data_csect_object_label)
		label_or_section_number=2;
	else if (object_label==stub_csect_object_label)
		label_or_section_number=3;
	else
		internal_error_in_function ("write_relocation_symbol_number_and_kind");

	fputc (label_or_section_number>>16,output_file);
	fputc (label_or_section_number>>8,output_file);
	fputc (label_or_section_number,output_file);
	fputc (relocation_type,output_file);
}
#endif

static void write_code_relocations (void)
{
	struct relocation *relocation;

#if 1 && defined (G_MACH_O)
	{
		struct relocation *previous_relocation,*next_relocation;
		
		relocation=first_code_relocation;
		previous_relocation=NULL;
		while (relocation!=NULL){
			next_relocation=relocation->next;
			relocation->next=previous_relocation;
			previous_relocation=relocation;
			relocation=next_relocation;
		}
		first_code_relocation=previous_relocation;
	}
#endif
	
	for_l (relocation,first_code_relocation,next){
		switch (relocation->kind){
			case CONDITIONAL_BRANCH_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
				if (label->label_object_label==NULL)
					internal_error_in_function ("write_code_relocations");
#ifdef G_MACH_O_SCATTERED
				if (label->label_object_label->kind!=IMPORTED_CODE_LABEL){
					struct object_label *object_label;
					int offset;

					object_label=label->label_object_label;
					
					write_c ((1<<7) | (1<<6) | (2<<4) | PPC_RELOC_BR14);
					write_3b (relocation->offset);

					offset=label->label_offset;

					if (object_label->kind!=CODE_CONTROL_SECTION && object_label->kind!=MERGED_CODE_CONTROL_SECTION){
						if (object_label->kind==DATA_CONTROL_SECTION)
							offset+=code_buffer_offset;
						else {
							if (object_label!=stub_csect_object_label)
								internal_error_in_function ("write_code_relocations");
						}
					}

					write_l (offset);
					break;
				}
#endif
#ifndef G_MACH_O
				write_l (relocation->offset+2);
#else
				write_l (relocation->offset);
#endif
#ifdef ELF
				write_relocation_label_number_and_addend (label,R_PPC_REL14,0);
#elif defined (G_MACH_O)
				write_relocation_symbol_number_and_kind (label,PPC_RELOC_BR14 | (2<<5) | (1<<7));
#else
				write_l (label->label_object_label->object_label_number<<1);
				write_c (0x80+16-1);
				write_c (R_BR);
#endif
				break;
			}
			case DUMMY_CONDITIONAL_BRANCH_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
				if (label->label_object_label==NULL)
					internal_error_in_function ("write_code_relocations");
#ifdef G_MACH_O_SCATTERED
				if (label->label_object_label->kind!=IMPORTED_CODE_LABEL){
					struct object_label *object_label;
					int offset;

					object_label=label->label_object_label;
					
					write_c ((1<<7) | (1<<6) | (2<<4) | PPC_RELOC_BR14);
					write_3b (relocation->offset);

					offset=label->label_offset;

					if (object_label->kind!=CODE_CONTROL_SECTION && object_label->kind!=MERGED_CODE_CONTROL_SECTION){
						if (object_label->kind==DATA_CONTROL_SECTION)
							offset+=code_buffer_offset;
						else {
							if (object_label!=stub_csect_object_label)
								internal_error_in_function ("write_code_relocations");
						}
					}

					write_l (offset);
					break;
				}
#endif
#ifndef G_MACH_O
				write_l (relocation->offset+2);
#else
				write_l (relocation->offset);
#endif
#ifdef ELF
				write_relocation_label_number_and_addend (label,R_PPC_REL14,0);
#elif defined (G_MACH_O)
				write_relocation_symbol_number_and_kind (label,PPC_RELOC_BR14 | (2<<5) | (1<<7));
#else
				write_l (label->label_object_label->object_label_number<<1);
				write_c (0x80+16-1);
				write_c (R_REF /* R_BR */);
#endif
				break;
			}
			case BRANCH_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
				if (label->label_object_label==NULL)
					internal_error_in_function ("write_code_relocations");

#ifdef G_MACH_O_SCATTERED
				if (label->label_object_label->kind!=IMPORTED_CODE_LABEL){
					struct object_label *object_label;
					int offset;

					object_label=label->label_object_label;
					
					write_c ((1<<7) | (1<<6) | (2<<4) | PPC_RELOC_BR24);
					write_3b (relocation->offset);

					offset=label->label_offset;

					if (object_label->kind!=CODE_CONTROL_SECTION && object_label->kind!=MERGED_CODE_CONTROL_SECTION){
						if (object_label->kind==DATA_CONTROL_SECTION)
							offset+=code_buffer_offset;
						else {
							if (object_label!=stub_csect_object_label)
								internal_error_in_function ("write_code_relocations");
						}
					}

					write_l (offset);
					break;
				}
#endif

				write_l (relocation->offset);
#ifdef ELF
				write_relocation_label_number_and_addend (label,R_PPC_REL24,0);
#elif defined (G_MACH_O)
				write_relocation_symbol_number_and_kind (label,PPC_RELOC_BR24 | (2<<5) | (1<<7));
#else
				write_l (label->label_object_label->object_label_number<<1);
				write_c (0x80+26-1);
				write_c (R_BR);
#endif
				break;
			}
#ifdef XCOFF
			case TOC_RELOCATION:
				write_l (relocation->offset+2);
				write_l ((relocation->relocation_toc_label->toc_t_label_number+n_object_labels+1)<<1);
				write_c (16-1);
				write_c (R_TOC);
				break;
			case TRL_RELOCATION:
				write_l (relocation->offset+2);
				write_l ((relocation->relocation_toc_label->toc_t_label_number+n_object_labels+1)<<1);
				write_c (16-1);
# ifdef TRL_RELOCATIONS
				write_c (R_TRL);
# else
				write_c (R_TOC);
# endif
				break;
#else
			case HIGH_RELOCATION:
			{
# ifdef G_MACH_O
				int addend;
				struct label *label;
				
				label=relocation->relocation_label;
				if (label->label_object_label==NULL)
					internal_error_in_function ("write_code_relocations");

#  ifdef G_MACH_O_SCATTERED
				if (label->label_object_label->kind!=IMPORTED_CODE_LABEL){
					struct object_label *object_label;

					object_label=label->label_object_label;
					
					write_c ((1<<7) | (2<<4) | PPC_RELOC_HA16);
					write_3b (relocation->offset);

					addend=label->label_offset;
					
					if (object_label->kind!=CODE_CONTROL_SECTION && object_label->kind!=MERGED_CODE_CONTROL_SECTION){
						if (object_label->kind==DATA_CONTROL_SECTION)
							addend+=code_buffer_offset;
						else {
							if (object_label!=stub_csect_object_label)
								internal_error_in_function ("write_code_relocations");
						}
					}

					write_l (addend);

					write_c ((1<<7) | (2<<4) | PPC_RELOC_PAIR);
					write_3b ((addend+relocation->relocation_addend) & 0xffff);
					write_l (0);
					break;
				}
#  endif
				write_l (relocation->offset);
				write_relocation_symbol_number_and_kind (label,PPC_RELOC_HA16 | (2<<5));		
				
				addend=relocation->relocation_addend+label->label_offset;
				if (label->label_object_label->kind==DATA_CONTROL_SECTION || label->label_object_label->kind==EXPORTED_DATA_LABEL)
					addend+=code_buffer_offset;
				
				write_l (((unsigned)addend) & 0xffff);
				write_l (PPC_RELOC_PAIR | (2<<5));
# else
				write_l (relocation->offset+2);
				write_relocation_label_number_and_addend (relocation->relocation_label,R_PPC_ADDR16_HA,
															relocation->relocation_addend);
# endif
				break;
			}
			case LOW_RELOCATION:
			{
# ifdef G_MACH_O
				int addend;
				struct label *label;
		
				label=relocation->relocation_label;
				if (label->label_object_label==NULL)
					internal_error_in_function ("write_code_relocations");

#  ifdef G_MACH_O_SCATTERED
				if (label->label_object_label->kind!=IMPORTED_CODE_LABEL){
					struct object_label *object_label;

					object_label=label->label_object_label;
					
					write_c ((1<<7) | (2<<4) | PPC_RELOC_LO16);
					write_3b (relocation->offset);

					addend=label->label_offset;
					
					if (object_label->kind!=CODE_CONTROL_SECTION && object_label->kind!=MERGED_CODE_CONTROL_SECTION){
						if (object_label->kind==DATA_CONTROL_SECTION)
							addend+=code_buffer_offset;
						else {
							if (object_label!=stub_csect_object_label)
								internal_error_in_function ("write_code_relocations");
						}
					}

					write_l (addend);

					write_c ((1<<7) | (2<<4) | PPC_RELOC_PAIR);
					write_3b (((unsigned)(addend+relocation->relocation_addend))>>16);
					write_l (0);
					break;
				}
#  endif
				
				write_l (relocation->offset);
				write_relocation_symbol_number_and_kind (label,PPC_RELOC_LO16 | (2<<5));

				addend=relocation->relocation_addend+label->label_offset;
				if (label->label_object_label->kind==DATA_CONTROL_SECTION || label->label_object_label->kind==EXPORTED_DATA_LABEL)
					addend+=code_buffer_offset;

				write_l (((unsigned)addend)>>16);
				write_l (PPC_RELOC_PAIR | (2<<5));
# else
				write_l (relocation->offset+2);
				write_relocation_label_number_and_addend (relocation->relocation_label,R_PPC_ADDR16_LO,
															relocation->relocation_addend);
# endif
				break;
			}
			case LONG_WORD_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
				if (label->label_object_label==NULL)
					internal_error_in_function ("write_code_relocations");

# ifdef G_MACH_O_SCATTERED
				if (label->label_object_label->kind!=IMPORTED_CODE_LABEL){
					int addend;
					struct object_label *object_label;

					object_label=label->label_object_label;
					addend=label->label_offset;

					if (object_label->kind!=CODE_CONTROL_SECTION && object_label->kind!=MERGED_CODE_CONTROL_SECTION){
						if (object_label->kind==DATA_CONTROL_SECTION)
							addend+=code_buffer_offset;
						else {
							if (object_label!=stub_csect_object_label)
								internal_error_in_function ("write_code_relocations");
						}
					}
					
					write_c ((1<<7) | (2<<4) | PPC_RELOC_VANILLA);
					write_3b (relocation->offset);
					write_l (addend);

					break;
				}
# endif
				write_l (relocation->offset);
# ifdef G_MACH_O
				write_relocation_symbol_number_and_kind (label,PPC_RELOC_VANILLA | (2<<5));
# else
				write_relocation_label_number_and_addend (label,R_PPC_ADDR32,relocation->relocation_addend);
# endif
				break;
			}
#endif
			default:
				internal_error_in_function ("write_code_relocations");
		}
	}
}

static void write_data_relocations (void)
{
	struct relocation *relocation;

#if 1 && defined (G_MACH_O)
	{
		struct relocation *previous_relocation,*next_relocation;
		
		relocation=first_data_relocation;
		previous_relocation=NULL;
		while (relocation!=NULL){
			next_relocation=relocation->next;
			relocation->next=previous_relocation;
			previous_relocation=relocation;
			relocation=next_relocation;
		}
		first_data_relocation=previous_relocation;
	}
#endif

	for_l (relocation,first_data_relocation,next){
		struct label *label;
		
		label=relocation->relocation_label;

		if (label->label_object_label==NULL)
			internal_error_in_function ("write_data_relocations");

		switch (relocation->kind){
			case LONG_WORD_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
				if (label->label_object_label==NULL)
					internal_error_in_function ("write_code_relocations");

#ifdef G_MACH_O_SCATTERED
				if (label->label_object_label->kind!=IMPORTED_CODE_LABEL){
					int addend;
					struct object_label *object_label;

					object_label=label->label_object_label;
					addend=label->label_offset;

					if (object_label->kind!=CODE_CONTROL_SECTION && object_label->kind!=MERGED_CODE_CONTROL_SECTION){
						if (object_label->kind==DATA_CONTROL_SECTION)
							addend+=code_buffer_offset;
						else {
							if (object_label!=stub_csect_object_label)
								internal_error_in_function ("write_code_relocations");
						}
					}
					
					write_c ((1<<7) | (2<<4) | PPC_RELOC_VANILLA);
					write_3b (relocation->offset);
					write_l (addend);

					break;
				}
#endif

				write_l (relocation->offset);
#ifdef ELF
				write_relocation_label_number_and_addend (label,R_PPC_ADDR32,relocation->relocation_addend);
#elif defined (G_MACH_O)
				write_relocation_symbol_number_and_kind (label,PPC_RELOC_VANILLA | (2<<5));
#else
				write_l (label->label_object_label->object_label_number<<1);
				write_c (32-1);
				write_c (R_POS);
#endif
				break;
			}
			default:
				internal_error_in_function ("write_data_relocations");
		}
	}
}

#ifdef XCOFF
static void write_toc_relocations (struct toc_label *toc_labels)
{
	struct toc_label *toc_label;
	
	for_l (toc_label,toc_labels,toc_next){
		struct label *label;

		label=toc_label->toc_label_label;

		if (label->label_object_label==NULL)
			internal_error_in_function ("write_toc_label_relocations");
		
		write_l (data_buffer_offset+(toc_label->toc_t_label_number<<2));
		write_l (label->label_object_label->object_label_number<<1);
		write_c (32-1);
		write_c (R_POS);
	}
}
#endif

#define C_EXT 2
#define C_HIDEXT 107

#define XTY_ER 0
#define XTY_SD 1
#define XTY_LD 2

#define XMC_PR 0
#define XMC_TC 3
#define XMC_RW 5
#define XMC_DS 10
#define XMC_TC0 15

static void write_string_8 (char *string)
{
	int i;

	i=0;

	while (i<8){
		char c;
		
		c=string[i++];
		write_c (c);
		
		if (c=='\0'){
			while (i<8){
				write_c ('\0');
				++i;
			}
			return;
		}
	}
}

static void write_object_labels (void)
{
	struct object_label *object_label;
	int code_section_number,data_section_number;

	code_section_number=0;
	data_section_number=0;

#ifdef ELF
	write_l (0);
	write_l (0);
	write_l (0);
	write_l (0);

	write_l (1);
	write_l (0);
	write_l (0);
	write_c (ELF32_ST_INFO (STB_LOCAL,STT_SECTION));
	write_c (0);
	write_w (2);

	write_l (7);
	write_l (0);
	write_l (0);
	write_c (ELF32_ST_INFO (STB_LOCAL,STT_SECTION));
	write_c (0);
	write_w (3);
#endif

#ifdef G_MACH_O_SCATTERED
	{
	int string_table_offset;
	
	string_table_offset=first_module_string_offset;

	for_l (object_label,first_object_label,next){
		switch (object_label->kind){
			case CODE_CONTROL_SECTION:
				write_l (string_table_offset);
				write_c (N_SECT);
				write_c (1);
				write_w (0);
				write_l (object_label->object_label_offset);

				string_table_offset+=14;
				break;
			case DATA_CONTROL_SECTION:
				write_l (string_table_offset);
				write_c (N_SECT);
				write_c (2);
				write_w (0);
				write_l (object_label->object_label_offset + code_buffer_offset);

				string_table_offset+=14;
				break;
		}
	}
	}
#endif
	
	for_l (object_label,first_object_label,next){
		switch (object_label->kind){
			case CODE_CONTROL_SECTION:
			{
#if !(defined (ELF) || defined (G_MACH_O))
				char section_name[16];

				sprintf (section_name,".m_%d",code_section_number);
				++code_section_number;
				write_string_8 (section_name);

				write_l (object_label->object_label_offset);
				write_w (1);
				write_w (0);
				write_c (C_HIDEXT);
				write_c (1);
				
				write_l (object_label->object_label_size);
				write_l (0);
				write_w (0);
				write_c ((2<<3)|XTY_SD);
				write_c (XMC_PR);
				write_l (0);
				write_w (0);
#endif
				break;
			}
			case DATA_CONTROL_SECTION:
			{
#if !(defined (ELF) || defined (G_MACH_O))
				char section_name[16];

				sprintf (section_name,".d_%d",data_section_number);
				++data_section_number;
				write_string_8 (section_name);

				write_l (object_label->object_label_offset);
				write_w (2);
				write_w (0);
				write_c (C_HIDEXT);
				write_c (1);

				write_l (object_label->object_label_size);
				write_l (0);
				write_w (0);
				write_c ((2<<3)|XTY_SD);
				write_c (XMC_RW);
				write_l (0);
				write_w (0);
#endif
				break;
			}
			case IMPORTED_CODE_LABEL:
			{
				struct label *label;
				
				label=object_label->object_label_label;
#ifdef ELF
				write_l (object_label->object_label_string_offset);
				write_l (0);
				write_l (0);
				write_c (ELF32_ST_INFO (STB_GLOBAL,STT_NOTYPE));
				write_c (0);
				write_w (0);
#else
# ifdef G_MACH_O
# else
				if (object_label->object_label_string_offset==0)
					write_string_8 (label->label_name);
				else {
					write_l (0);
					write_l (object_label->object_label_string_offset);
				}
				
				write_l (0);
				write_w (0);
				write_w (0);
				write_c (C_EXT);
				write_c (1);
				
				write_l (0);
				write_l (0);
				write_w (0);
				write_c ((2<<3)|XTY_ER);
				write_c (XMC_PR);
				write_l (0);
				write_w (0);				
# endif
#endif
				break;
			}
			case EXPORTED_CODE_LABEL:
			{
				struct label *label;
				
				label=object_label->object_label_label;
#ifdef ELF
				write_l (object_label->object_label_string_offset);
				write_l (label->label_offset);
				write_l (0);
				write_c (ELF32_ST_INFO (STB_GLOBAL,STT_FUNC));
				write_c (0);
				write_w (2);
#else
# ifdef G_MACH_O
				write_l (object_label->object_label_string_offset);
				write_c (N_SECT | N_EXT);
				write_c (1);
				write_w (0);
				write_l (label->label_offset);				
# else	
				if (object_label->object_label_string_offset==0)
					write_string_8 (label->label_name);
				else {
					write_l (0);
					write_l (object_label->object_label_string_offset);
				}

				write_l (label->label_offset);
				write_w (1);
				write_w (0);
				write_c (C_EXT);
				write_c (1);
				
				write_l (label->label_object_label->object_label_number<<1);
				write_l (0);
				write_w (0);
				write_c ((2<<3)|XTY_LD);
				write_c (XMC_PR);
				write_l (0);
				write_w (0);
# endif
#endif
				break;
			}
			case EXPORTED_DATA_LABEL:
			{
				struct label *label;
				
				label=object_label->object_label_label;
#ifdef ELF
				write_l (object_label->object_label_string_offset);
				write_l (label->label_offset);
				write_l (0);
				write_c (ELF32_ST_INFO (STB_GLOBAL,STT_OBJECT));
				write_c (0);
				write_w (3);
#else
# ifdef G_MACH_O
				write_l (object_label->object_label_string_offset);
				write_c (N_SECT | N_EXT);
				write_c (2);
				write_w (0);
				write_l (label->label_offset + code_buffer_offset);
# else	
				if (object_label->object_label_string_offset==0)
					write_string_8 (label->label_name);
				else {
					write_l (0);
					write_l (object_label->object_label_string_offset);
				}

				write_l (label->label_offset);
				write_w (2);
				write_w (0);
				write_c (C_EXT);
				write_c (1);
				
				write_l (label->label_object_label->object_label_number<<1);
				write_l (0);
				write_w (0);
				write_c ((2<<3)|XTY_LD);
				write_c (XMC_RW);
				write_l (0);
				write_w (0);
# endif
#endif
				break;
			}
			case MERGED_CODE_CONTROL_SECTION:
				break;
			default:
				internal_error_in_function ("write_object_labels");
		}
	}

#ifdef G_MACH_O
	for_l (object_label,first_object_label,next)
		if (object_label->kind==IMPORTED_CODE_LABEL){
			struct label *label;

			label=object_label->object_label_label;

			write_l (object_label->object_label_string_offset);
			write_c (N_UNDF | N_EXT);
			write_c (NO_SECT);
			write_w (0);
			write_l (0);
		}
#endif
}

#ifdef XCOFF
static void write_toc_labels (struct toc_label *toc_labels)
{
	struct toc_label *toc_label;
	int toc_offset;
	
	toc_offset=data_buffer_offset;

	write_c ('T');
	write_c ('O');
	write_c ('C');
	write_c ('\0');
	write_c ('\0');
	write_c ('\0');
	write_c ('\0');
	write_c ('\0');
	
	write_l (toc_offset);
	write_w (2);
	write_w (0);
	write_c (C_HIDEXT);
	write_c (1);
	
	write_l (0);
	write_l (0);
	write_w (0);
	write_c ((2<<3)|XTY_SD);
	write_c (XMC_TC0);
	write_l (0);
	write_w (0);
	
	for_l (toc_label,toc_labels,toc_next){
		char toc_entry_name[16];
				
		sprintf (toc_entry_name,"t_%d",toc_label->toc_t_label_number);

		write_string_8 (toc_entry_name);
		
		write_l (toc_offset);
		write_w (2);
		write_w (0);
		write_c (C_HIDEXT);
		write_c (1);
		
		write_l (4);
		write_l (0);
		write_w (0);
		write_c ((2<<3)|XTY_SD);
		write_c (XMC_TC);
		write_l (0);
		write_w (0);
		
		toc_offset+=4;
	}
}
#endif

static void write_string_table (void)
{
	struct object_label *object_label;

#ifdef ELF
	write_c (0);
	write_zstring (".text");
	write_zstring (".data");
#else
	if (string_table_offset==4)
		return;
	
	write_l (string_table_offset);
#endif
	for_l (object_label,first_object_label,next){
		int object_label_kind;
		
		object_label_kind=object_label->kind;
		
		if ((object_label_kind==IMPORTED_CODE_LABEL || object_label_kind==EXPORTED_CODE_LABEL || object_label_kind==EXPORTED_DATA_LABEL)
			&& object_label->object_label_string_offset!=0)
		{
			char *s,c;
				
			s=object_label->object_label_label->label_name;

			do {
				c=*s++;
				write_c (c);
			} while (c!='\0');
		}
	}

#ifdef G_MACH_O_SCATTERED
	{
	int code_section_n,data_section_n;
	
	code_section_n=0;
	data_section_n=0;
	for_l (object_label,first_object_label,next){
		int object_label_kind,section_n,n;
		
		object_label_kind=object_label->kind;
		
		if (object_label_kind==CODE_CONTROL_SECTION){
			write_c ('_');
			write_c ('_');
			write_c ('T');
			write_c ('E');
			write_c ('X');
			write_c ('T');
			write_c ('.');
			section_n=code_section_n++;
		} else if (object_label_kind==DATA_CONTROL_SECTION){
			write_c ('_');
			write_c ('_');
			write_c ('D');
			write_c ('A');
			write_c ('T');
			write_c ('A');
			write_c ('.');
			section_n=data_section_n++;
		} else
			continue;
		
		n=section_n/100000;
		write_c ('0'+n);
		section_n-=n*100000;

		n=section_n/10000;
		write_c ('0'+n);
		section_n-=n*10000;
	
		n=section_n/1000;
		write_c ('0'+n);
		section_n-=n*1000;
	
		n=section_n/100;
		write_c ('0'+n);
		section_n-=n*100;
	
		n=section_n/10;
		write_c ('0'+n);
		section_n-=n*10;

		n=section_n;
		write_c ('0'+n);
		
		write_c ('\0');
	}
	}
#endif
}

#ifdef DYNAMIC_CODEGENERATOR
extern void allocate_memory_for_object_file (int object_file_size);
#endif

void assemble_code (void)
{
	as_import_labels (labels);
	
	write_code();

	flush_data_buffer();
	flush_code_buffer();
	*last_toc_next_p=NULL;

#ifdef G_MACH_O
	compute_offsets_of_stub_labels();
#endif
	store_references();
	renumber_object_labels_and_calculate_section_sizes();

	relocate_branches();
	relocate_data();

#ifdef DYNAMIC_CODEGENERATOR
	allocate_memory_for_object_file (100+code_buffer_offset+data_buffer_offset+4*t_label_number
									+(n_code_relocations+n_data_relocations+t_label_number)*10
									+((n_object_labels+1+t_label_number)<<1)*18+string_table_offset);
#endif
	
	write_file_header_and_section_headers();

	write_buffers_and_release_memory (&first_code_buffer);
	write_buffers_and_release_memory (&first_data_buffer);
#ifdef XCOFF
	write_toc (toc_labels);
#endif
#ifdef G_MACH_O
	write_stubs();
#endif

	write_code_relocations();
	write_data_relocations();
#ifdef XCOFF
	write_toc_relocations (toc_labels);
#endif
#ifdef G_MACH_O
	write_stub_relocations_and_indirect_symbols();
#endif

	write_object_labels();
#ifdef XCOFF
	write_toc_labels (toc_labels);
#endif
	write_string_table();
}

#endif
