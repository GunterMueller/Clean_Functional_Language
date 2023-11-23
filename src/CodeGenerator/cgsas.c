/*
	File:		cgsas.c
	Author:		John van Groningen
	Machine:	Sun 4
	At:			University of Nijmegen
*/

#include <stdio.h>
#include <string.h>

#define ELF_TARGET_SPARC
#include <elf.h>

#define ELF
#undef ALIGN_REAL_ARRAYS

#include "cgport.h"
#include "cgrconst.h"
#include "cgtypes.h"
#include "cg.h"
#include "cgiconst.h"
#include "cgcode.h"
#include "cgswas.h"

#ifdef ALIGN_REAL_ARRAYS
# define LOAD_STORE_ALIGNED_REAL 4
#endif

#define FUNCTION_LEVEL_LINKING

#define for_l(v,l,n) for(v=(l);v!=NULL;v=v->n)

#define U4(s,v1,v2,v3,v4) s->v1;s->v2;s->v3;s->v4
#define U5(s,v1,v2,v3,v4,v5) s->v1;s->v2;s->v3;s->v4;s->v5

#define IO_BUFFER_SIZE 16384
#define BUFFER_SIZE 4096

struct object_buffer {
	struct object_buffer *	next;
	int						size;
	unsigned char			data [BUFFER_SIZE];
};

#define BRANCH_RELOCATION 0
#define CALL_RELOCATION 1
#define LONG_WORD_RELOCATION 2
#define HI22_RELOCATION 3
#define LO12_RELOCATION 4
#ifdef FUNCTION_LEVEL_LINKING
# define DUMMY_BRANCH_RELOCATION 5
#endif

#ifdef FUNCTION_LEVEL_LINKING
# define TEXT_LABEL_ID (0x7fff-2)
# define DATA_LABEL_ID (0x7fff-3)
#else
# define TEXT_LABEL_ID 1
# define DATA_LABEL_ID 2
#endif

#define CODE_CONTROL_SECTION 0
#define DATA_CONTROL_SECTION 1
#define IMPORTED_LABEL 2
#define EXPORTED_CODE_LABEL 3
#define EXPORTED_DATA_LABEL 4

struct object_label {
	struct object_label *	next;
	union {
		unsigned long		offset;			/* CODE_CONTROL_SECTION,DATA_CONTROL_SECTION */
		struct label *		label;			/* IMPORTED_LABEL,EXPORTED_CODE_LABEL */
	} object_label_u1;
	union {
		unsigned long		length;			/* CODE_CONTROL_SECTION,DATA_CONTROL_SECTION */
		unsigned long		string_offset;	/* IMPORTED_LABEL,EXPORTED_CODE_LABEL */
	} object_label_u2;
	int						object_label_number;
#ifdef FUNCTION_LEVEL_LINKING
	int						object_label_n_relocations;	/* CODE_CONTROL_SECTION,DATA_CONTROL_SECTION */
	short					object_label_section_n;		/* CODE_CONTROL_SECTION,DATA_CONTROL_SECTION */
#endif
	unsigned char			object_label_kind;
	unsigned char			object_section_align8;
};

#define object_label_offset object_label_u1.offset
#define object_label_label object_label_u1.label

#define object_label_length object_label_u2.length
#define object_label_string_offset object_label_u2.string_offset

struct relocation {
	struct relocation *		next;
	unsigned long			relocation_offset;
	struct label *			relocation_label;
	long					relocation_addend;
#ifdef FUNCTION_LEVEL_LINKING
	struct object_label	*	relocation_object_label;	/* for BRANCH_RELOCATION, CALL_RELOCATION and DUMMY_BRANCH_RELOCATION */
#endif
	short					relocation_kind;
};

static FILE *output_file;

static int n_code_relocations,n_data_relocations;
static struct object_label *code_object_label,*data_object_label;

static struct relocation *first_code_relocation,**last_code_relocation_l;
static struct relocation *first_data_relocation,**last_data_relocation_l;

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

static struct object_label *first_object_label,**last_object_label_l;
#ifdef FUNCTION_LEVEL_LINKING
static int n_code_sections,n_data_sections;
#endif

#ifdef FUNCTION_LEVEL_LINKING
void as_new_data_module (void)
{
	struct object_label *new_object_label;
	unsigned long current_data_offset;
	int data_section_label_number;
	
	new_object_label=fast_memory_allocate_type (struct object_label);
	data_object_label=new_object_label;

	data_section_label_number=0;
	current_data_offset=CURRENT_DATA_OFFSET;

	*last_object_label_l=new_object_label;
	last_object_label_l=&new_object_label->next;
	new_object_label->next=NULL;
	
	new_object_label->object_label_offset=current_data_offset;
	new_object_label->object_label_number=data_section_label_number;
	new_object_label->object_label_section_n=n_data_sections;
	++n_data_sections;
	new_object_label->object_label_length=0;
	new_object_label->object_label_kind=DATA_CONTROL_SECTION;
	new_object_label->object_section_align8=0;
}

static void as_new_code_module (void)
{
	struct object_label *new_object_label;
	unsigned long current_code_offset;
	int code_section_label_number;
	
	new_object_label=fast_memory_allocate_type (struct object_label);
	code_object_label=new_object_label;

	code_section_label_number=0;
	current_code_offset=CURRENT_CODE_OFFSET;

	*last_object_label_l=new_object_label;
	last_object_label_l=&new_object_label->next;
	new_object_label->next=NULL;
	
	new_object_label->object_label_offset=current_code_offset;
	new_object_label->object_label_number=code_section_label_number;
	new_object_label->object_label_section_n=n_code_sections;
	++n_code_sections;
	new_object_label->object_label_length=0;
	new_object_label->object_label_kind=CODE_CONTROL_SECTION;
}
#endif

static void store_label_plus_offset_in_data_section (LABEL *label,int offset)
{
	struct relocation *new_relocation;

	store_long_word_in_data_section (0);

	new_relocation=fast_memory_allocate_type (struct relocation);
	++n_data_relocations;
	
	*last_data_relocation_l=new_relocation;
	last_data_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;
	
	new_relocation->relocation_label=label;
	new_relocation->relocation_offset=CURRENT_DATA_OFFSET-4;
	new_relocation->relocation_kind=LONG_WORD_RELOCATION;
	new_relocation->relocation_addend=offset;
}

static int n_object_labels;

static unsigned long string_table_offset;

void define_data_label (LABEL *label)
{
	label->label_id=DATA_LABEL_ID;
#ifdef FUNCTION_LEVEL_LINKING
	label->label_object_label=data_object_label;
#endif
	label->label_offset=CURRENT_DATA_OFFSET;	

	if (label->label_flags & EXPORT_LABEL){
		struct object_label *new_object_label;
		int string_length;
		
		new_object_label=fast_memory_allocate_type (struct object_label);
		*last_object_label_l=new_object_label;
		last_object_label_l=&new_object_label->next;
		new_object_label->next=NULL;
		
		new_object_label->object_label_label=label;
#if defined (RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL) && defined (FUNCTION_LEVEL_LINKING)
		new_object_label->object_label_number = n_object_labels;
#endif 

		++n_object_labels;

		string_length=strlen (label->label_name);
		new_object_label->object_label_string_offset=string_table_offset;
		string_table_offset+=string_length+1;

#if defined (RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL) && defined (FUNCTION_LEVEL_LINKING)
		label->label_object_label=new_object_label;	
		new_object_label->object_label_section_n = data_object_label->object_label_section_n;
#endif

		new_object_label->object_label_kind=EXPORTED_DATA_LABEL;
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

			label->label_id=TEXT_LABEL_ID;			
#ifdef FUNCTION_LEVEL_LINKING
			label->label_object_label=code_object_label;
#endif
			label->label_offset=CURRENT_CODE_OFFSET;
			
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
				new_object_label->object_label_string_offset=string_table_offset;
				string_table_offset+=string_length+1;
				new_object_label->object_label_kind=EXPORTED_CODE_LABEL;				
			}
		}
}

void store_label_in_data_section (LABEL *label)
{
	store_label_plus_offset_in_data_section (label,0);
}

void store_descriptor_in_data_section (LABEL *label)
{
	store_label_plus_offset_in_data_section (label,2);
}

void store_descriptor_string_in_data_section (char *string,int length,LABEL *string_label)
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
	new_relocation->relocation_offset=CURRENT_CODE_OFFSET-4;
#ifdef FUNCTION_LEVEL_LINKING
	new_relocation->relocation_object_label=code_object_label;
#endif
	new_relocation->relocation_kind=relocation_kind;
	new_relocation->relocation_addend=0;
}

static void as_hi_or_lo_label (struct label *label,int offset,int relocation_kind)
{
	struct relocation *new_relocation;

	new_relocation=fast_memory_allocate_type (struct relocation);
	++n_code_relocations;
	
	*last_code_relocation_l=new_relocation;
	last_code_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;
	
	new_relocation->relocation_label=label;
	new_relocation->relocation_offset=CURRENT_CODE_OFFSET-4;
	new_relocation->relocation_kind=relocation_kind;
	new_relocation->relocation_addend=offset;
}

static void store_label_in_code_section (struct label *label)
{
	struct toc_label *t_label;
	struct relocation *new_relocation;

	store_instruction (0);

	new_relocation=fast_memory_allocate_type (struct relocation);
	++n_code_relocations;
	
	*last_code_relocation_l=new_relocation;
	last_code_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;
	
	new_relocation->relocation_offset=CURRENT_CODE_OFFSET-4;

	new_relocation->relocation_label=label;
	new_relocation->relocation_kind=LONG_WORD_RELOCATION;
	new_relocation->relocation_addend=0;
}

#define REGISTER_G0 (-16)
#define REGISTER_I6 (-10)
#define REGISTER_O0 8
#define REGISTER_O1 9
#define REGISTER_O7 15

/*
static char register_type  [32]="ggggggiiggiiiiiilllllllloooooooo";
static char register_number[32]="01234767565432100123456701234567";
*/

static unsigned char real_reg_num [32] =
{
	0,1,2,3,4,7,30,31,
	5,6,29,28,27,26,25,24,
	16,17,18,19,20,21,22,23,
	8,9,10,11,12,13,14,15
};

#define reg_num(r) (real_reg_num[(r)+16])

#define as_i_id0(i,rd) store_instruction(0x1000000|(reg_num(rd)<<25)|((i)&0x3fffff))
#define as_i_bic(i,cond) store_instruction((cond<<25)|(2<<22)|((i)&0x3fffffff))
#define as_i_bica(i,cond) store_instruction((1<<29)|(cond<<25)|(2<<22)|(i)&0x3fffffff)
#define as_i_call(i) store_instruction((1<<30)|i)
#define as_i_fbic(i,cond) store_instruction((cond<<25)|(6<<22)|i)
#define as_i_fbica(i,cond) store_instruction((1<<29)|(cond<<25)|(6<<22)|i)
#define as_i_abd2(ra,rb,rd,op) store_instruction(0x80000000|((op)<<19)|(reg_num(rd)<<25)|(reg_num(ra)<<14)|reg_num(rb))
#define as_i_fb2(fa,fb,op,opf) store_instruction(0x80000000|((op)<<19)|((fa)<<14)|((opf)<<5)|(fb))
#define as_i_ff2(ra,rd,op,opf) store_instruction(0x80000000|((op)<<19)|((rd)<<25)|((opf)<<5)|(ra))
#define as_i_fff2(ra,rb,rd,op,opf) store_instruction(0x80000000|((op)<<19)|((rd)<<25)|((ra)<<14)|((opf)<<5)|(rb))
#define as_i_aid2(ra,i,rd,op) store_instruction(0x80000000|((op)<<19)|(reg_num(rd)<<25)|(reg_num(ra)<<14)|0x2000|((i)&0x1fff))
#define as_i_abd3(ra,rb,rd,op) store_instruction(0xc0000000|((op)<<19)|(reg_num(rd)<<25)|(reg_num(ra)<<14)|reg_num(rb))
#define as_i_aod3(ra,o,rd,op) store_instruction(0xc0000000|((op)<<19)|(reg_num(rd)<<25)|(reg_num(ra)<<14)|0x2000|((o)&0x1fff))
#define as_i_foa3(fa,o,ra,op) store_instruction(0xc0000000|((op)<<19)|((fa)<<25)|((reg_num(ra))<<14)|0x2000|((o)&0x1fff))
#define as_i_fab3(fa,ra,rb,op) store_instruction(0xc0000000|((op)<<19)|((fa)<<25)|((reg_num(ra))<<14)|(reg_num(rb)))

#define LD_OP 0
#define LDUB_OP 1
#define LDUH_OP 2
#define LDSB_OP 9
#define LDSH_OP 10
#define ST_OP 4
#define STB_OP 5
#define STH_OP 6

#define LDF_OP 0x20
#define LDDF_OP 0x23
#define	STF_OP 0x24
#define STDF_OP 0x27

#define AND_OP 1
#define OR_OP 2
#define XOR_OP 3
#define SLL_OP 0x25
#define SRL_OP 0x26
#define SRA_OP 0x27

#define FADDD_OP 0x42
#define FDIVD_OP 0x4e
#define FMULD_OP 0x4a
#define FSUBD_OP 0x46

#define A_COND 0x8
#define E_COND 0x1
#define GE_COND 0xb
#define G_COND 0xa
#define L_COND 0x3
#define LE_COND 0x2
#define NE_COND 0x9
#define CS_COND 0x5
#define VC_COND 0xf
#define VS_COND 0x7

#define FE_COND 0x9
#define FGE_COND 0xb
#define FG_COND 0x6
#define FLE_COND 0xd
#define FL_COND 0x4
#define FNE_COND 0x1

#define as_add(ra,rb,rd) as_i_abd2(ra,rb,rd,0)
#define as_addcc(ra,rb,rd) as_i_abd2(ra,rb,rd,0x10)
#define as_addcci(ra,i,rd) as_i_aid2(ra,i,rd,0x10)
#define as_addi(ra,i,rd) as_i_aid2(ra,i,rd,0)
#define as_andcci(ra,i,rd) as_i_aid2(ra,i,rd,0x11)
#define as_faddd(fa,fb,fd) as_i_fff2(fa,fb,fd,0x34,FADDD_OP)
#define as_fcmpd(fa,fb) as_i_fb2(fa,fb,0x35,0x52)
#define as_fdtoi(fa,fd) as_i_ff2(fa,fd,0x34,0xd2)
#define as_fitod(fa,fd) as_i_ff2(fa,fd,0x34,0xc8)
#define as_fdivd(fa,fb,fd) as_i_fff2(fa,fb,fd,0x34,FDIVD_OP)
#define as_fmuld(fa,fb,fd) as_i_fff2(fa,fb,fd,0x34,FMULD_OP)
#define as_fsqrtd(fa,fd) as_i_ff2(fa,fd,0x34,0x2a)
#define as_fsubd(fa,fb,fd) as_i_fff2(fa,fb,fd,0x34,FSUBD_OP)
#define as_jmpli(i,ra,rd) as_i_aid2(ra,i,rd,0x38)
#define as_ld(o,ra,rd) as_i_aod3(ra,o,rd,LD_OP)
#define as_lddf(o,ra,fd) as_i_foa3(fd,o,ra,LDDF_OP)
#define as_lddf_x(ra,rb,fd) as_i_fab3(fd,ra,rb,LDDF_OP)
#define as_ldf(o,ra,fd) as_i_foa3(fd,o,ra,LDF_OP)
#define as_ldf_x(ra,rb,fd) as_i_fab3(fd,ra,rb,LDF_OP)
#define as_ldsh(o,ra,rd) as_i_aod3(ra,o,rd,LDSH_OP)
#define as_ldsh_x(ra,rb,rd) as_i_abd3(ra,rb,rd,LDSH_OP)
#define as_ld_x(ra,rb,rd) as_i_abd3(ra,rb,rd,LD_OP)
#define as_fmovs(fa,fd) as_i_ff2(fa,fd,0x34,1);
#define as_fnegs(fa,fd) as_i_ff2(fa,fd,0x34,5);
#define as_fabss(fa,fd) as_i_ff2(fa,fd,0x34,9);
#define as_or(ra,rb,rd) as_i_abd2(ra,rb,rd,OR_OP)
#define as_orcc(ra,rb,rd) as_i_abd2(ra,rb,rd,0x12)
#define as_ori(ra,i,rd) as_i_aid2(ra,i,rd,OR_OP)
#define as_sethi(i,rd) as_i_id0(i,rd)
#define as_slli(ra,i,rd) as_i_aid2(ra,i,rd,SLL_OP)
#define as_stdf(fa,o,rd) as_i_foa3(fa,o,rd,STDF_OP)
#define as_stdf_x(fa,ra,rb) as_i_fab3(fa,ra,rb,STDF_OP)
#define as_stf(fa,o,rd) as_i_foa3(fa,o,rd,STF_OP)
#define as_sub(ra,rb,rd) as_i_abd2(ra,rb,rd,4)
#define as_subcc(ra,rb,rd) as_i_abd2(ra,rb,rd,0x14)
#define as_subcci(ra,i,rd) as_i_aid2(ra,i,rd,0x14)

#define as_btst(i,ra) as_i_aid2(ra,i,REGISTER_G0,0x11)
#define as_clr(rd) as_or(REGISTER_G0,REGISTER_G0,rd)
#define as_cmp(ra,rb) as_subcc(ra,rb,REGISTER_G0)
#define as_cmpi(ra,i) as_subcci(ra,i,REGISTER_G0)
#define as_dec(i,rd) as_i_aid2(rd,i,rd,4)
#define as_deccc(i,rd) as_i_aid2(rd,i,rd,0x14)
#define as_inc(i,rd) as_i_aid2(rd,i,rd,0)
#define as_inccc(i,rd) as_i_aid2(rd,i,rd,0x10)
#define as_mov(ra,rd) as_or(REGISTER_G0,ra,rd)
#define as_movi(i,rd) as_ori(REGISTER_G0,i,rd)
#define as_nop() as_sethi(0,REGISTER_G0)
#define as_retl() as_jmpli(8,REGISTER_O7,REGISTER_G0)
#define as_tst(ra) as_orcc(REGISTER_G0,ra,REGISTER_G0)
#define as_load(op,o,ra,rd) as_i_aod3(ra,o,rd,op)
#define as_load_x(op,ra,rb,rd) as_i_abd3(ra,rb,rd,op)
#define as_store(op,rd,o,ra) as_i_aod3(ra,o,rd,op)
#define as_store_x(op,rd,ra,rb) as_i_abd3(ra,rb,rd,op)

#define as_st(rd,o,ra) as_store(ST_OP,rd,o,ra)

static void as_set (int i,int rd)
{
	if (i>=-4096 && i<=4095)
		as_movi (i,rd);
	else {
		as_sethi (i>>10,rd);
		if ((i & 1023)!=0)
			as_ori (rd,i & 1023,rd);
	}
}

enum { SIZE_LONG, SIZE_WORD, SIZE_BYTE };

static void as_ld_parameter (struct parameter *parameter,int rd)
{
	if (parameter->parameter_type==P_INDIRECT)
		as_ld (parameter->parameter_offset,parameter->parameter_data.reg.r,rd);
	else if (parameter->parameter_type==P_INDEXED && parameter->parameter_offset==0)
		as_ld_x (parameter->parameter_data.ir->a_reg.r,parameter->parameter_data.ir->d_reg.r,rd);
	else
		internal_error_in_function ("as_ld_parameter");
}

static void as_ldsh_parameter (struct parameter *parameter,int rd)
{
	if (parameter->parameter_type==P_INDIRECT)
		as_ldsh (parameter->parameter_offset,parameter->parameter_data.reg.r,rd);
	else if (parameter->parameter_type==P_INDEXED && parameter->parameter_offset==0)
		as_ldsh_x (parameter->parameter_data.ir->a_reg.r,parameter->parameter_data.ir->d_reg.r,rd);
	else
		internal_error_in_function ("as_ldsh_parameter");
}

static struct parameter as_register_parameter (struct parameter parameter,int size_flag)
{
	switch (parameter.parameter_type){
		case P_DESCRIPTOR_NUMBER:
			as_sethi (0,REGISTER_O0);
			as_hi_or_lo_label (parameter.parameter_data.l,2+(parameter.parameter_offset<<3),HI22_RELOCATION);

			as_ori (REGISTER_O0,0,REGISTER_O0);
			as_hi_or_lo_label (parameter.parameter_data.l,2+(parameter.parameter_offset<<3),LO12_RELOCATION);

			parameter.parameter_type=P_REGISTER;
			parameter.parameter_data.reg.r=REGISTER_O0;
			break;
		case P_IMMEDIATE:
			if (parameter.parameter_data.i==0){
				parameter.parameter_type=P_REGISTER;
				parameter.parameter_data.reg.r=REGISTER_G0;
			} else {
				as_set (parameter.parameter_data.i,REGISTER_O0);

				parameter.parameter_type=P_REGISTER;
				parameter.parameter_data.reg.r=REGISTER_O0;
			}
			break;
		case P_REGISTER:
			break;
		case P_INDIRECT:
			as_load (size_flag==SIZE_LONG ? LD_OP : size_flag==SIZE_WORD ? LDSH_OP : LDUB_OP,
					 parameter.parameter_offset,parameter.parameter_data.reg.r,REGISTER_O0);

			parameter.parameter_type=P_REGISTER;
			parameter.parameter_data.reg.r=REGISTER_O0;
			break;
		case P_INDEXED:
			if (parameter.parameter_offset!=0)
				internal_error_in_function ("as_register_parameter");
			
			as_load_x (size_flag==SIZE_LONG ? LD_OP : size_flag==SIZE_WORD ? LDSH_OP : LDUB_OP,
					   parameter.parameter_data.ir->a_reg.r,parameter.parameter_data.ir->d_reg.r,REGISTER_O0);

			parameter.parameter_type=P_REGISTER;
			parameter.parameter_data.reg.r=REGISTER_O0;
			break;
		default:
			internal_error_in_function ("as_register_parameter");
	}
	return parameter;
}

static void as_move_instruction (struct instruction *instruction,int size_flag)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_REGISTER:
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_DESCRIPTOR_NUMBER:
					as_sethi (0,instruction->instruction_parameters[1].parameter_data.reg.r);
					as_hi_or_lo_label (	instruction->instruction_parameters[0].parameter_data.l,
										2+(instruction->instruction_parameters[0].parameter_offset<<3),HI22_RELOCATION);

					as_ori (instruction->instruction_parameters[1].parameter_data.reg.r,0,
							instruction->instruction_parameters[1].parameter_data.reg.r);
					as_hi_or_lo_label (	instruction->instruction_parameters[0].parameter_data.l,
										2+(instruction->instruction_parameters[0].parameter_offset<<3),LO12_RELOCATION);
					break;
				case P_IMMEDIATE:
					as_set (instruction->instruction_parameters[0].parameter_data.i,
							instruction->instruction_parameters[1].parameter_data.reg.r);
					break;
				case P_REGISTER:
					as_mov (instruction->instruction_parameters[0].parameter_data.reg.r,
							instruction->instruction_parameters[1].parameter_data.reg.r);
					return;
				case P_INDIRECT:
					as_load (size_flag==SIZE_LONG ? LD_OP : size_flag==SIZE_WORD ? LDSH_OP : LDUB_OP,
							 instruction->instruction_parameters[0].parameter_offset,
							 instruction->instruction_parameters[0].parameter_data.reg.r,
							 instruction->instruction_parameters[1].parameter_data.reg.r);
					break;
				case P_INDEXED:
					if (instruction->instruction_parameters[0].parameter_offset!=0)
						internal_error_in_function ("as_move_instruction");
						
					as_load_x (size_flag==SIZE_LONG ? LD_OP : size_flag==SIZE_WORD ? LDSH_OP : LDUB_OP,
							   instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,
							   instruction->instruction_parameters[0].parameter_data.ir->d_reg.r,
							   instruction->instruction_parameters[1].parameter_data.reg.r);
					break;
				default:
					internal_error_in_function ("as_move_instruction");
					return;
			}
			return;
		case P_INDIRECT:
		{
			struct parameter parameter_0;
			int offset;

			parameter_0=as_register_parameter (instruction->instruction_parameters[0],size_flag);

			offset=instruction->instruction_parameters[1].parameter_offset;

			if (((offset << (32-13)) >> (32-13))==offset){
				as_store (size_flag==SIZE_LONG ? ST_OP : size_flag==SIZE_WORD ? STH_OP : STB_OP,
						  parameter_0.parameter_data.reg.r,offset,instruction->instruction_parameters[1].parameter_data.reg.r);
			} else {
				as_sethi (offset>>10,REGISTER_O1);
		
				as_add (REGISTER_O1,instruction->instruction_parameters[1].parameter_data.reg.r,REGISTER_O1);

				as_store (size_flag==SIZE_LONG ? ST_OP : size_flag==SIZE_WORD ? STH_OP : STB_OP,
						  parameter_0.parameter_data.reg.r,offset & 1023,REGISTER_O1);
			}

			return;
		}
		case P_INDEXED:
		{
			struct parameter parameter_0;

			if (instruction->instruction_parameters[1].parameter_offset!=0)
				internal_error_in_function ("as_move_instruction");
			
			parameter_0=as_register_parameter (instruction->instruction_parameters[0],size_flag);

			as_store_x (size_flag==SIZE_LONG ? ST_OP : size_flag==SIZE_WORD ? STH_OP : STB_OP,
						parameter_0.parameter_data.reg.r,instruction->instruction_parameters[1].parameter_data.ir->a_reg.r,
						instruction->instruction_parameters[1].parameter_data.ir->d_reg.r);
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
				as_sethi (0,instruction->instruction_parameters[1].parameter_data.reg.r);
				as_hi_or_lo_label (	instruction->instruction_parameters[0].parameter_data.l,
									instruction->instruction_parameters[0].parameter_offset,HI22_RELOCATION);

				as_ori (instruction->instruction_parameters[1].parameter_data.reg.r,0,
						instruction->instruction_parameters[1].parameter_data.reg.r);
				as_hi_or_lo_label (	instruction->instruction_parameters[0].parameter_data.l,
									instruction->instruction_parameters[0].parameter_offset,LO12_RELOCATION);
				return;
			case P_INDIRECT:
				as_addi (instruction->instruction_parameters[0].parameter_data.reg.r,
						 instruction->instruction_parameters[0].parameter_offset,
						 instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_INDEXED:
				as_add (instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,
						instruction->instruction_parameters[0].parameter_data.ir->d_reg.r,
						instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
		}

	internal_error_in_function ("as_lea_instruction");
}

static void as_sll_instruction (struct instruction *instruction)
{
	as_slli (	instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[2].parameter_data.i,
				instruction->instruction_parameters[1].parameter_data.reg.r);
}

static void as_logical_or_shift_instruction (struct instruction *instruction,int opcode)
{
	struct parameter parameter;

	parameter=instruction->instruction_parameters[0];

	switch (parameter.parameter_type){
		case P_IMMEDIATE:
			if ((unsigned)(parameter.parameter_data.i+4096)>=(unsigned)8192){
				as_set (parameter.parameter_data.i,REGISTER_O0);

				parameter.parameter_type=P_REGISTER;
				parameter.parameter_data.reg.r=REGISTER_O0;
			} else {
				as_i_aid2 ( instruction->instruction_parameters[1].parameter_data.reg.r,
							parameter.parameter_data.i,
							instruction->instruction_parameters[1].parameter_data.reg.r,opcode);
				return;
			}
			break;
		case P_INDIRECT:
			as_ld (parameter.parameter_offset,parameter.parameter_data.reg.r,REGISTER_O0);

			parameter.parameter_type=P_REGISTER;
			parameter.parameter_data.reg.r=REGISTER_O0;
			break;
		case P_INDEXED:
			if (parameter.parameter_offset!=0)
				internal_error_in_function ("as_tryadic_instruction");

			as_ld_x (parameter.parameter_data.ir->a_reg.r,parameter.parameter_data.ir->d_reg.r,REGISTER_O0);

			parameter.parameter_type=P_REGISTER;
			parameter.parameter_data.reg.r=REGISTER_O0;			
	}

	as_i_abd2 (	instruction->instruction_parameters[1].parameter_data.reg.r,
				parameter.parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r,opcode);
}

static void as_add_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_add (instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[0].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
			if ((unsigned)(instruction->instruction_parameters[0].parameter_data.i+4096)<(unsigned)8192){
				as_inc (instruction->instruction_parameters[0].parameter_data.i,
						instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			} else {
				as_set (instruction->instruction_parameters[0].parameter_data.i,REGISTER_O0);

				as_add (instruction->instruction_parameters[1].parameter_data.reg.r,REGISTER_O0,
						instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}
		default:
			as_ld_parameter (&instruction->instruction_parameters[0],REGISTER_O0);

			as_add (instruction->instruction_parameters[1].parameter_data.reg.r,REGISTER_O0,
					instruction->instruction_parameters[1].parameter_data.reg.r);
	}
}

static void as_add_o_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_addcc (	instruction->instruction_parameters[1].parameter_data.reg.r,
						instruction->instruction_parameters[0].parameter_data.reg.r,
						instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
			if ((unsigned)(instruction->instruction_parameters[0].parameter_data.i+4096)<(unsigned)8192){
				as_inccc (	instruction->instruction_parameters[0].parameter_data.i,
							instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			} else {
				as_set (instruction->instruction_parameters[0].parameter_data.i,REGISTER_O0);
				
				as_addcc (instruction->instruction_parameters[1].parameter_data.reg.r,REGISTER_O0,
						  instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}
		default:
			as_ld_parameter (&instruction->instruction_parameters[0],REGISTER_O0);

			as_addcc (	instruction->instruction_parameters[1].parameter_data.reg.r,REGISTER_O0,
						instruction->instruction_parameters[1].parameter_data.reg.r);
	}
}

static void as_sub_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_sub (instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[0].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
			if ((unsigned)(instruction->instruction_parameters[0].parameter_data.i+4096)<(unsigned)8192){
				as_dec (instruction->instruction_parameters[0].parameter_data.i,
						instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			} else {
				as_set (instruction->instruction_parameters[0].parameter_data.i,REGISTER_O0);

				as_sub (instruction->instruction_parameters[1].parameter_data.reg.r,REGISTER_O0,
						instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}
		default:
			as_ld_parameter (&instruction->instruction_parameters[0],REGISTER_O0);

			as_sub (instruction->instruction_parameters[1].parameter_data.reg.r,REGISTER_O0,
					instruction->instruction_parameters[1].parameter_data.reg.r);
	}
}

static void as_sub_o_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_subcc (instruction->instruction_parameters[1].parameter_data.reg.r,
					  instruction->instruction_parameters[0].parameter_data.reg.r,
					  instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
			if ((unsigned)(instruction->instruction_parameters[0].parameter_data.i+4096)<(unsigned)8192){
				as_deccc (instruction->instruction_parameters[0].parameter_data.i,
						  instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			} else {
				as_set (instruction->instruction_parameters[0].parameter_data.i,REGISTER_O0);

				as_subcc (instruction->instruction_parameters[1].parameter_data.reg.r,REGISTER_O0,
						  instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}
		default:
			as_ld_parameter (&instruction->instruction_parameters[0],REGISTER_O0);

			as_subcc (instruction->instruction_parameters[1].parameter_data.reg.r,REGISTER_O0,
					  instruction->instruction_parameters[1].parameter_data.reg.r);
	}
}

static void as_cmp_instruction (struct instruction *instruction)
{
	struct parameter parameter_0,parameter_1;

	parameter_0=instruction->instruction_parameters[0];
	parameter_1=instruction->instruction_parameters[1];

	if (parameter_1.parameter_type==P_INDIRECT){
		as_ld (parameter_1.parameter_offset,parameter_1.parameter_data.reg.r,REGISTER_O1);

		parameter_1.parameter_type=P_REGISTER;
		parameter_1.parameter_data.reg.r=REGISTER_O1;
	} else if (parameter_1.parameter_type==P_INDEXED){
		if (parameter_1.parameter_offset!=0)
			internal_error_in_function ("as_cmp_instruction");
		
		as_ld_x (parameter_1.parameter_data.ir->a_reg.r,parameter_1.parameter_data.ir->d_reg.r,REGISTER_O1);

		parameter_1.parameter_type=P_REGISTER;
		parameter_1.parameter_data.reg.r=REGISTER_O1;
	}

	switch (parameter_0.parameter_type){
		case P_DESCRIPTOR_NUMBER:
			as_sethi (0,REGISTER_O0);
			as_hi_or_lo_label (parameter_0.parameter_data.l,2+(parameter_0.parameter_offset<<3),HI22_RELOCATION);

			as_ori (REGISTER_O0,0,REGISTER_O0);
			as_hi_or_lo_label (parameter_0.parameter_data.l,2+(parameter_0.parameter_offset<<3),LO12_RELOCATION);

			parameter_0.parameter_type=P_REGISTER;
			parameter_0.parameter_data.reg.r=REGISTER_O0;
			break;
		case P_IMMEDIATE:
			if ((unsigned)(parameter_0.parameter_data.i+4096)>=(unsigned)8192){
				as_set (parameter_0.parameter_data.i,REGISTER_O0);

				parameter_0.parameter_type=P_REGISTER;
				parameter_0.parameter_data.reg.r=REGISTER_O0;
			} else {
				as_cmpi (parameter_1.parameter_data.reg.r,parameter_0.parameter_data.i);
				return;
			}
			break;
		case P_REGISTER:
			break;
		default:
			as_ld_parameter (&parameter_0,REGISTER_O0);

			parameter_0.parameter_type=P_REGISTER;
			parameter_0.parameter_data.reg.r=REGISTER_O0;
	}

	as_cmp (parameter_1.parameter_data.reg.r,parameter_0.parameter_data.reg.r);
}

#if 0
static void as_cmpw_instruction (struct instruction *instruction)
{
	struct parameter parameter_0,parameter_1;

	parameter_0=instruction->instruction_parameters[0];
	parameter_1=instruction->instruction_parameters[1];

	if (parameter_1.parameter_type==P_INDIRECT){
		as_ldsh (parameter_1.parameter_offset,parameter_1.parameter_data.reg.r,REGISTER_O1);

		parameter_1.parameter_type=P_REGISTER;
		parameter_1.parameter_data.reg.r=REGISTER_O1;
	} else if (parameter_1.parameter_type==P_INDEXED){
		if (parameter_1.parameter_offset!=0)
			internal_error_in_function ("as_cmpw_instruction");

		as_ldsh_x (parameter_1.parameter_data.ir->a_reg.r,parameter_1.parameter_data.ir->d_reg.r,REGISTER_O1);

		parameter_1.parameter_type=P_REGISTER;
		parameter_1.parameter_data.reg.r=REGISTER_O1;
	}

	switch (parameter_0.parameter_type){
		case P_DESCRIPTOR_NUMBER:
			as_sethi (0,REGISTER_O0);
			as_hi_or_lo_label (parameter_0.parameter_data.l,2+(parameter_0.parameter_offset<<3),HI22_RELOCATION);

			as_ori (REGISTER_O0,0,REGISTER_O0);
			as_hi_or_lo_label (parameter_0.parameter_data.l,2+(parameter_0.parameter_offset<<3),LO12_RELOCATION);

			parameter_0.parameter_type=P_REGISTER;
			parameter_0.parameter_data.reg.r=REGISTER_O0;
			break;
		case P_IMMEDIATE:
			if ((unsigned)(parameter_0.parameter_data.i+4096)>=(unsigned)8192){
				as_set (parameter_0.parameter_data.i,REGISTER_O0);

				parameter_0.parameter_type=P_REGISTER;
				parameter_0.parameter_data.reg.r=REGISTER_O0;
			} else {
				as_cmpi (parameter_1.parameter_data.reg.r,parameter_0.parameter_data.i);
				return;
			}
			break;
		case P_REGISTER:
			break;
		default:
			as_ldsh_parameter (&parameter_0,REGISTER_O0);

			parameter_0.parameter_type=P_REGISTER;
			parameter_0.parameter_data.reg.r=REGISTER_O0;
	}

	as_cmp (parameter_1.parameter_data.reg.r,parameter_0.parameter_data.reg.r);
}
#endif

static void as_tst_instruction (struct instruction *instruction,int size_flag)
{
	struct parameter parameter_0;

	if (size_flag!=SIZE_LONG)
		internal_error_in_function ("as_tst_instruction");

	parameter_0=as_register_parameter (instruction->instruction_parameters[0],size_flag);

	as_tst (parameter_0.parameter_data.reg.r);
}

static void as_btst_instruction (struct instruction *instruction)
{
	as_btst (instruction->instruction_parameters[0].parameter_data.i,
			 instruction->instruction_parameters[1].parameter_data.reg.r);
}

void as_jmp_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_LABEL){
		if (instruction->instruction_parameters[0].parameter_data.l->label_flags & LOCAL_LABEL){
			as_i_bica (0,A_COND);
			as_branch_label (instruction->instruction_parameters[0].parameter_data.l,BRANCH_RELOCATION);
			return;
		} else {
			as_i_call (0);
			as_branch_label (instruction->instruction_parameters[0].parameter_data.l,CALL_RELOCATION);

			as_nop();
		}
	} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
		as_jmpli (	instruction->instruction_parameters[0].parameter_offset,
					instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_G0);

		as_nop();
	} else
		internal_error_in_function ("as_jmp_instruction");
}

static void as_branch_instruction (struct instruction *instruction,int condition)
{
	as_i_bic (0,condition);
	as_branch_label (instruction->instruction_parameters[0].parameter_data.l,BRANCH_RELOCATION);

	as_nop();
}

static void as_index_error_branch_instruction (struct instruction *instruction)
{
	as_i_bic (12>>2,CS_COND);
	
	as_nop();

	as_i_bica (0,A_COND);
	as_branch_label (instruction->instruction_parameters[0].parameter_data.l,BRANCH_RELOCATION);
}

static void as_float_branch_instruction (struct instruction *instruction,int condition)
{
	as_nop();

	as_i_fbic (0,condition);
	as_branch_label (instruction->instruction_parameters[0].parameter_data.l,BRANCH_RELOCATION);

	as_nop();
}

static void as_jsr_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_LABEL){
		as_i_call (0);
		as_branch_label (instruction->instruction_parameters[0].parameter_data.l,CALL_RELOCATION);

		if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT)
			as_st (REGISTER_O7,instruction->instruction_parameters[1].parameter_data.i,B_STACK_POINTER);
		else
			as_nop();
	} else if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT){
		as_jmpli (	instruction->instruction_parameters[0].parameter_offset,
					instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_O7);


		as_st (REGISTER_O7,instruction->instruction_parameters[1].parameter_data.i,B_STACK_POINTER);
	} else
		internal_error_in_function ("as_jsr_instruction");		
}

static void as_rts_instruction (struct instruction *instruction)
{
	int b_offset;
	
	as_ld (instruction->instruction_parameters[0].parameter_offset,B_STACK_POINTER,REGISTER_O7);

	as_retl();

	b_offset=instruction->instruction_parameters[1].parameter_data.i;
	if (b_offset==0)
		as_nop();
	else {
		if (b_offset<0)
			as_dec (-b_offset,B_STACK_POINTER);
		else
			as_inc (b_offset,B_STACK_POINTER);
	}
}

static void as_set_condition_instruction (struct instruction *instruction,int condition)
{
	as_clr (instruction->instruction_parameters[0].parameter_data.reg.r);

	as_i_bica (2-1,condition);

	as_movi (-1,instruction->instruction_parameters[0].parameter_data.reg.r);
}

static void as_set_float_condition_instruction (struct instruction *instruction,int condition)
{
	as_nop();

	as_clr (instruction->instruction_parameters[0].parameter_data.reg.r);

	as_i_fbica (2-1,condition);

	as_movi (-1,instruction->instruction_parameters[0].parameter_data.reg.r);
}

extern struct label *dot_rem_label,*dot_div_label,*dot_mul_label;

static void w_as_mod_instruction (struct instruction *instruction)
{
	as_mov (instruction->instruction_parameters[2].parameter_data.reg.r,REGISTER_O0);

	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_i_call (0);
			as_branch_label (dot_rem_label,CALL_RELOCATION);

			as_mov (instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_O1);
			break;
		case P_IMMEDIATE:
		{
			long v;
			
			v=instruction->instruction_parameters[0].parameter_data.i;

			if ((unsigned)(v+4096) < (unsigned)8192){
				as_i_call (0);
				as_branch_label (dot_rem_label,CALL_RELOCATION);

				as_movi (v,REGISTER_O1);
			} else {
				as_sethi (v>>10,REGISTER_O1);

				as_i_call (0);
				as_branch_label (dot_rem_label,CALL_RELOCATION);
			
				as_ori (REGISTER_O1,v & 1023,REGISTER_O1);
			}
			break;
		}
		default:
			as_i_call (0);
			as_branch_label (dot_rem_label,CALL_RELOCATION);

			as_ld_parameter (&instruction->instruction_parameters[0],REGISTER_O1);
	}

	as_mov (REGISTER_O0,instruction->instruction_parameters[1].parameter_data.reg.r);
}

static void w_as_mul_or_div_instruction (struct instruction *instruction,struct label *mul_or_div_label)
{
	as_mov (instruction->instruction_parameters[1].parameter_data.reg.r,REGISTER_O0);

	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_i_call (0);
			as_branch_label (mul_or_div_label,CALL_RELOCATION);

			as_mov (instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_O1);
			break;
		case P_IMMEDIATE:
		{
			long v;
			
			v=instruction->instruction_parameters[0].parameter_data.i;

			if ((unsigned)(v+4096) < (unsigned)8192){
				as_i_call (0);
				as_branch_label (mul_or_div_label,CALL_RELOCATION);
	
				as_movi (v,REGISTER_O1);
			} else {
				as_sethi (v>>10,REGISTER_O1);

				as_i_call (0);
				as_branch_label (mul_or_div_label,CALL_RELOCATION);

				as_ori (REGISTER_O1,v & 1023,REGISTER_O1);
			}
			break;
		}
		default:
			as_i_call (0);
			as_branch_label (mul_or_div_label,CALL_RELOCATION);

			as_ld_parameter (&instruction->instruction_parameters[0],REGISTER_O1);
	}

	as_mov (REGISTER_O0,instruction->instruction_parameters[1].parameter_data.reg.r);
}

static void as_neg_instruction (struct instruction *instruction)
{
	as_sub (REGISTER_G0,instruction->instruction_parameters[0].parameter_data.reg.r,instruction->instruction_parameters[0].parameter_data.reg.r);
}

#ifndef FUNCTION_LEVEL_LINKING
static int data_section_alignment_mask;
#endif

static void as_load_float_immediate (double float_value,int fp_reg)
{
	struct label *new_label;

	new_label=allocate_memory_from_heap_type (struct label);

	new_label->label_flags=DATA_LABEL;
	new_label->label_id=DATA_LABEL_ID;
#ifdef FUNCTION_LEVEL_LINKING
	new_label->label_object_label=data_object_label;
	
	data_object_label->object_section_align8=1;
#else
	data_section_alignment_mask |= 7;
#endif

#ifdef FUNCTION_LEVEL_LINKING
	if ((((unsigned char*)data_buffer_p-current_data_buffer->data)-data_object_label->object_label_offset) & 4)
#else
	if ((((unsigned char*)data_buffer_p-current_data_buffer->data) & 4)!=0)
#endif
		store_long_word_in_data_section (0);

	new_label->label_offset=CURRENT_DATA_OFFSET;
	
	new_label->label_number=next_label_id++;

	store_long_word_in_data_section (((ULONG*)&float_value)[0]);
	store_long_word_in_data_section (((ULONG*)&float_value)[1]);

	as_sethi (0,REGISTER_O0);
	as_hi_or_lo_label (new_label,0,HI22_RELOCATION);

	as_lddf (0,REGISTER_O0,fp_reg<<1);
	as_hi_or_lo_label (new_label,0,LO12_RELOCATION);
}

static void as_load_float_indirect (struct parameter *parameter_p,int f_reg)
{
#ifdef ALIGN_REAL_ARRAYS
	if (parameter_p->parameter_flags & LOAD_STORE_ALIGNED_REAL)
		as_lddf (parameter_p->parameter_offset,parameter_p->parameter_data.reg.r,f_reg<<1);						
	else {
#endif
	as_ldf (parameter_p->parameter_offset,parameter_p->parameter_data.reg.r,f_reg<<1);
	as_ldf (parameter_p->parameter_offset+4,parameter_p->parameter_data.reg.r,(f_reg<<1)+1);
#ifdef ALIGN_REAL_ARRAYS
	}
#endif
}

static void as_load_float_indexed (struct parameter *parameter_p,int f_reg)
{
	int offset;
	
	offset=parameter_p->parameter_offset>>2;
	
#ifdef ALIGN_REAL_ARRAYS
	if (parameter_p->parameter_flags & LOAD_STORE_ALIGNED_REAL){
		if (offset==0)
			as_lddf_x (parameter_p->parameter_data.ir->a_reg.r,parameter_p->parameter_data.ir->d_reg.r,f_reg<<1);
		else {
			as_add (parameter_p->parameter_data.ir->a_reg.r,parameter_p->parameter_data.ir->d_reg.r,REGISTER_O0);
			as_lddf (offset,REGISTER_O0,f_reg<<1);
		}
	} else {
#endif
	as_add (parameter_p->parameter_data.ir->a_reg.r,parameter_p->parameter_data.ir->d_reg.r,REGISTER_O0);
	as_ldf (offset,REGISTER_O0,f_reg<<1);
	as_ldf (offset+4,REGISTER_O0,(f_reg<<1)+1);
#ifdef ALIGN_REAL_ARRAYS
	}
#endif
}

static int as_float_parameter (struct parameter parameter)
{
	switch (parameter.parameter_type){
		case P_F_IMMEDIATE:
			as_load_float_immediate (*parameter.parameter_data.r,15);
			return 15;
		case P_INDIRECT:
#ifdef ALIGN_REAL_ARRAYS
			if (parameter.parameter_flags & LOAD_STORE_ALIGNED_REAL)
				as_lddf (parameter.parameter_offset,parameter.parameter_data.reg.r,30);
			else {
#endif
			as_ldf (parameter.parameter_offset,parameter.parameter_data.reg.r,30);
			as_ldf (parameter.parameter_offset+4,parameter.parameter_data.reg.r,31);
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
				if (offset==0)
					as_lddf_x (parameter.parameter_data.ir->a_reg.r,parameter.parameter_data.ir->d_reg.r,30);
				else {
					as_add (parameter.parameter_data.ir->a_reg.r,parameter.parameter_data.ir->d_reg.r,REGISTER_O0);

					as_lddf (offset,REGISTER_O0,30);
				}
			} else {
#endif
			as_add (parameter.parameter_data.ir->a_reg.r,parameter.parameter_data.ir->d_reg.r,REGISTER_O0);

			as_ldf (offset,REGISTER_O0,30);
			as_ldf (offset+4,REGISTER_O0,31);
#ifdef ALIGN_REAL_ARRAYS
			}
#endif
			return 15;
		}
		case P_F_REGISTER:
			return parameter.parameter_data.reg.r;
	}
	internal_error_in_function ("as_float_parameter");
	return 0;
}

static void as_compare_float_instruction (struct instruction *instruction)
{
	int f_reg;

	f_reg=as_float_parameter (instruction->instruction_parameters[0]);

	as_fcmpd (instruction->instruction_parameters[1].parameter_data.reg.r<<1,f_reg<<1);
}

static void as_sqrt_float_instruction (struct instruction *instruction)
{
	int f_reg;

	f_reg=as_float_parameter (instruction->instruction_parameters[0]);

	as_fsqrtd (f_reg<<1,instruction->instruction_parameters[1].parameter_data.reg.r<<1);
}

static void as_neg_float_instruction (struct instruction *instruction)
{
	int freg1,freg2;

	freg2=instruction->instruction_parameters[1].parameter_data.reg.r;
	
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_INDIRECT:
			as_load_float_indirect (&instruction->instruction_parameters[0],freg2);
			freg1=freg2;
			break;
		case P_INDEXED:
			as_load_float_indexed (&instruction->instruction_parameters[0],freg2);
			freg1=freg2;
			break;
		default:
			freg1=as_float_parameter (instruction->instruction_parameters[0]);
	}

	as_fnegs (freg1<<1,freg2<<1);

	if (freg1!=freg2)
		as_fmovs ((freg1<<1)+1,(freg2<<1)+1);
}

static void as_abs_float_instruction (struct instruction *instruction)
{
	int freg1,freg2;

	freg2=instruction->instruction_parameters[1].parameter_data.reg.r;
	
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_INDIRECT:
			as_load_float_indirect (&instruction->instruction_parameters[0],freg2);
			freg1=freg2;
			break;
		case P_INDEXED:
			as_load_float_indexed (&instruction->instruction_parameters[0],freg2);
			freg1=freg2;
			break;
		default:
			freg1=as_float_parameter (instruction->instruction_parameters[0]);
	}

	as_fabss (freg1<<1,freg2<<1);

	if (freg1!=freg2)
		as_fmovs ((freg1<<1)+1,(freg2<<1)+1);
}

static void as_tryadic_float_instruction (struct instruction *instruction,int opcode)
{
	int f_reg;

	f_reg=as_float_parameter (instruction->instruction_parameters[0]);

	as_i_fff2 (instruction->instruction_parameters[1].parameter_data.reg.r<<1,f_reg<<1,
			   instruction->instruction_parameters[1].parameter_data.reg.r<<1,
			   0x34,opcode);
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
											as_faddd (reg0<<1,reg_s<<1,reg1<<1);
											break;
										case IFSUB:
											as_fsubd (reg0<<1,reg_s<<1,reg1<<1);
											break;
										case IFMUL:
											as_fmuld (reg0<<1,reg_s<<1,reg1<<1);
											break;
										case IFDIV:
											as_fdivd (reg0<<1,reg_s<<1,reg1<<1);
											break;
									}
									
									return next_instruction;
								}
						}

					as_fmovs (reg0<<1,reg1<<1);
					as_fmovs ((reg0<<1)+1,(reg1<<1)+1);
				
					return instruction;
				}
				case P_INDIRECT:
					as_load_float_indirect (&instruction->instruction_parameters[0],instruction->instruction_parameters[1].parameter_data.reg.r);
					return instruction;
				case P_INDEXED:
					as_load_float_indexed (&instruction->instruction_parameters[0],instruction->instruction_parameters[1].parameter_data.reg.r);
					return instruction;
				case P_F_IMMEDIATE:
					as_load_float_immediate (*instruction->instruction_parameters[0].parameter_data.r,instruction->instruction_parameters[1].parameter_data.reg.r);
					return instruction;
			}
			break;
		case P_INDIRECT:
			if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
#ifdef ALIGN_REAL_ARRAYS
				if (instruction->instruction_parameters[1].parameter_flags & LOAD_STORE_ALIGNED_REAL){
					as_stdf (instruction->instruction_parameters[0].parameter_data.reg.r<<1,
							 instruction->instruction_parameters[1].parameter_offset,
							 instruction->instruction_parameters[1].parameter_data.reg.r);
				} else {
#endif
				as_stf (instruction->instruction_parameters[0].parameter_data.reg.r<<1,
						instruction->instruction_parameters[1].parameter_offset,
						instruction->instruction_parameters[1].parameter_data.reg.r);

				as_stf ((instruction->instruction_parameters[0].parameter_data.reg.r<<1)+1,
						instruction->instruction_parameters[1].parameter_offset+4,
						instruction->instruction_parameters[1].parameter_data.reg.r);
#ifdef ALIGN_REAL_ARRAYS
				}
#endif
				return instruction;
			}
			break;
		case P_INDEXED:
			if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
				int offset;
				
				offset=instruction->instruction_parameters[1].parameter_offset>>2;
#ifdef ALIGN_REAL_ARRAYS
				if (instruction->instruction_parameters[1].parameter_flags & LOAD_STORE_ALIGNED_REAL){
					if (offset==0)
						as_stdf_x (instruction->instruction_parameters[0].parameter_data.reg.r<<1,
								   instruction->instruction_parameters[1].parameter_data.ir->a_reg.r,
								   instruction->instruction_parameters[1].parameter_data.ir->d_reg.r);	
					else {
						as_add (instruction->instruction_parameters[1].parameter_data.ir->a_reg.r,
								instruction->instruction_parameters[1].parameter_data.ir->d_reg.r,REGISTER_O0);

						as_stdf (instruction->instruction_parameters[0].parameter_data.reg.r<<1,offset,REGISTER_O0);			
					}
				} else {
#endif
				as_add (instruction->instruction_parameters[1].parameter_data.ir->a_reg.r,
						instruction->instruction_parameters[1].parameter_data.ir->d_reg.r,REGISTER_O0);

				as_stf (instruction->instruction_parameters[0].parameter_data.reg.r<<1,offset,REGISTER_O0);
				as_stf ((instruction->instruction_parameters[0].parameter_data.reg.r<<1)+1,offset+4,REGISTER_O0);
#ifdef ALIGN_REAL_ARRAYS
				}
#endif
				return instruction;
			}
	}
	internal_error_in_function ("as_fmove_instruction");
	return instruction;
}

static void as_fmove_hl_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT
		&&	instruction->instruction_parameters[1].parameter_type==P_F_REGISTER)
	{
		if (instruction->instruction_icode==IFMOVEHI)
			as_ldf (instruction->instruction_parameters[0].parameter_offset,
					instruction->instruction_parameters[0].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r<<1);
		else
			as_ldf (instruction->instruction_parameters[0].parameter_offset,
					instruction->instruction_parameters[0].parameter_data.reg.r,
					(instruction->instruction_parameters[1].parameter_data.reg.r<<1)+1);
		return;
	}
	
	internal_error_in_function ("as_fmove_hl_instruction");
}

static void as_fmovel_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
		if (instruction->instruction_parameters[1].parameter_type!=P_REGISTER)
			internal_error_in_function ("as_fmovel_instruction");

		as_fdtoi (instruction->instruction_parameters[0].parameter_data.reg.r<<1,31);

		as_stf (31,-4,REGISTER_I6);

		as_ld (-4,REGISTER_I6,instruction->instruction_parameters[1].parameter_data.reg.r);
	} else {
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_REGISTER:
				as_st (instruction->instruction_parameters[0].parameter_data.reg.r,-4,REGISTER_I6);

				as_ldf (-4,REGISTER_I6,31);
				break;
			case P_INDIRECT:
				as_ldf (instruction->instruction_parameters[0].parameter_offset,
						instruction->instruction_parameters[0].parameter_data.reg.r,31);
				break;
			case P_INDEXED:
				if (instruction->instruction_parameters[0].parameter_offset!=0)
					internal_error_in_function ("as_movel_instruction");

				as_ldf_x (instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,
						  instruction->instruction_parameters[0].parameter_data.ir->d_reg.r,31);
				break;
			case P_IMMEDIATE:
				as_set (instruction->instruction_parameters[0].parameter_data.i,REGISTER_O0);

				as_st (REGISTER_O0,-4,REGISTER_I6);

				as_ldf (-4,REGISTER_I6,31);
				break;			
			default:
				internal_error_in_function ("as_fmovel_instruction");
		}

		as_fitod (31,instruction->instruction_parameters[1].parameter_data.reg.r<<1);
	}
}

static void as_instructions (register struct instruction *instruction)
{
	while (instruction!=NULL){
		switch (instruction->instruction_icode){
			case IMOVE:
				as_move_instruction (instruction,SIZE_LONG);
				break;
			case ILEA:
				as_lea_instruction (instruction);
				break;
			case IADD:
				as_add_instruction (instruction);
				break;
			case IADDI:
				as_addi (instruction->instruction_parameters[0].parameter_data.reg.r,
						 instruction->instruction_parameters[2].parameter_data.i,
						 instruction->instruction_parameters[1].parameter_data.reg.r);
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
				as_branch_instruction (instruction,E_COND);
				break;
			case IBGE:
				as_branch_instruction (instruction,GE_COND);
				break;
			case IBGT:
				as_branch_instruction (instruction,G_COND);
				break;
			case IBHS:
				as_index_error_branch_instruction (instruction);
				break;
			case IBLE:
				as_branch_instruction (instruction,LE_COND);
				break;
			case IBLT:
				as_branch_instruction (instruction,L_COND);
				break;
			case IBNE:
				as_branch_instruction (instruction,NE_COND);
				break;
			case IBNO:
				as_branch_instruction (instruction,VC_COND);
				break;
			case IBO:
				as_branch_instruction (instruction,VS_COND);
				break;
			case ILSLI:
				as_sll_instruction (instruction);
				break;
			case ILSL:
				as_logical_or_shift_instruction (instruction,SLL_OP);
				break;
			case ILSR:
				as_logical_or_shift_instruction (instruction,SRL_OP);
				break;
			case IASR:
				as_logical_or_shift_instruction (instruction,SRA_OP);
				break;
			case IMUL:
				w_as_mul_or_div_instruction (instruction,dot_mul_label);
				break;
			case IDIV:
				w_as_mul_or_div_instruction (instruction,dot_div_label);
				break;
			case IREM:
				w_as_mod_instruction (instruction);
				break;
			case IAND:
				as_logical_or_shift_instruction (instruction,AND_OP);
				break;
			case IOR:
				as_logical_or_shift_instruction (instruction,OR_OP);
				break;
			case IEOR:
				as_logical_or_shift_instruction (instruction,XOR_OP);
				break;
			case ISEQ:
				as_set_condition_instruction (instruction,E_COND);
				break;
			case ISGE:
				as_set_condition_instruction (instruction,GE_COND);
				break;
			case ISGT:
				as_set_condition_instruction (instruction,G_COND);
				break;
			case ISLE:
				as_set_condition_instruction (instruction,LE_COND);
				break;
			case ISLT:
				as_set_condition_instruction (instruction,L_COND);
				break;
			case ISNE:
				as_set_condition_instruction (instruction,NE_COND);
				break;
			case ISNO:
				as_set_condition_instruction (instruction,VC_COND);
				break;
			case ISO:
				as_set_condition_instruction (instruction,VS_COND);
				break;			
#if 0
			case ICMPW:
				as_cmpw_instruction (instruction);
				break;
#endif
			case ITST:
				as_tst_instruction (instruction,SIZE_LONG);
				break;
			case IBTST:
				as_btst_instruction (instruction);
				break;
			case IMOVEDB:
				as_move_instruction (instruction,SIZE_WORD);
				break;
			case IMOVEB:
				as_move_instruction (instruction,SIZE_BYTE);
				break;
			case INEG:
				as_neg_instruction (instruction);
				break;
			case IFMOVE:
				instruction=as_fmove_instruction (instruction);
				break;
			case IFMOVEHI:
			case IFMOVELO:
				as_fmove_hl_instruction (instruction);
				break;
			case IFADD:
				as_tryadic_float_instruction (instruction,FADDD_OP);
				break;
			case IFSUB:
				as_tryadic_float_instruction (instruction,FSUBD_OP);
				break;
			case IFCMP:
				as_compare_float_instruction (instruction);
				break;
			case IFDIV:
				as_tryadic_float_instruction (instruction,FDIVD_OP);
				break;
			case IFMUL:
				as_tryadic_float_instruction (instruction,FMULD_OP);
				break;
			case IFBEQ:
				as_float_branch_instruction (instruction,FE_COND);
				break;
			case IFBGE:
				as_float_branch_instruction (instruction,FGE_COND);
				break;
			case IFBGT:
				as_float_branch_instruction (instruction,FG_COND);
				break;
			case IFBLE:
				as_float_branch_instruction (instruction,FLE_COND);
				break;
			case IFBLT:
				as_float_branch_instruction (instruction,FL_COND);
				break;
			case IFBNE:
				as_float_branch_instruction (instruction,FNE_COND);
				break;
			case IFMOVEL:
				as_fmovel_instruction (instruction);
				break;
			case IFSQRT:
				as_sqrt_float_instruction (instruction);
				break;
			case IFNEG:
				as_neg_float_instruction (instruction);
				break;
			case IFABS:
				as_abs_float_instruction (instruction);
				break;
			case IFSEQ:
				as_set_float_condition_instruction (instruction,FE_COND);
				break;
			case IFSGE:
				as_set_float_condition_instruction (instruction,FGE_COND);
				break;
			case IFSGT:
				as_set_float_condition_instruction (instruction,FG_COND);
				break;
			case IFSLE:
				as_set_float_condition_instruction (instruction,FLE_COND);
				break;
			case IFSLT:
				as_set_float_condition_instruction (instruction,FL_COND);
				break;
			case IFSNE:
				as_set_float_condition_instruction (instruction,FNE_COND);
				break;
			case IWORD:
				store_instruction (instruction->instruction_parameters[0].parameter_data.i);
				break;
			case IADDO:
				as_add_o_instruction (instruction);
				break;
			case ISUBO:
				as_sub_o_instruction (instruction);
				break;
			case IFTST:
			default:
				internal_error_in_function ("as_instructions");
		}
		instruction=instruction->instruction_next;
	}
}

static void as_number_of_arguments (int n_node_arguments)
{
	store_instruction (n_node_arguments);
}

struct call_and_jump {
	struct call_and_jump *	cj_next;
	struct label *			cj_call_label;
	struct label			cj_label;
	struct label			cj_jump_label;
};

static struct call_and_jump *first_call_and_jump,*last_call_and_jump;

static void as_garbage_collect_test (struct basic_block *block)
{
	LONG n_cells;
	struct call_and_jump *new_call_and_jump;
	
	new_call_and_jump=allocate_memory_from_heap (sizeof (struct call_and_jump));

	new_call_and_jump->cj_next=NULL;
	new_call_and_jump->cj_label.label_flags=0;
	
	switch (block->block_n_begin_a_parameter_registers){
		case 0:		new_call_and_jump->cj_call_label=collect_0_label;	break;
		case 1:		new_call_and_jump->cj_call_label=collect_1_label;	break;
		case 2:		new_call_and_jump->cj_call_label=collect_2_label;	break;
		case 3:		new_call_and_jump->cj_call_label=collect_3_label;	break;
		default:	internal_error_in_function ("as_garbage_collect_test");
	}

	if (first_call_and_jump!=NULL)
		last_call_and_jump->cj_next=new_call_and_jump;
	else
		first_call_and_jump=new_call_and_jump;
	last_call_and_jump=new_call_and_jump;
	
	n_cells=block->block_n_new_heap_cells;	

	if (n_cells<4096)
		as_deccc (n_cells,REGISTER_D7);
	else {
		as_set (n_cells,REGISTER_O0);
		as_subcc (REGISTER_D7,REGISTER_O0,REGISTER_D7);
	}

	as_i_bica (0,CS_COND);
	as_branch_label (&new_call_and_jump->cj_label,BRANCH_RELOCATION);

	as_dec (4,B_STACK_POINTER);
	
	new_call_and_jump->cj_jump_label.label_flags=0;
	new_call_and_jump->cj_jump_label.label_id=TEXT_LABEL_ID;
#ifdef FUNCTION_LEVEL_LINKING
	new_call_and_jump->cj_jump_label.label_object_label=code_object_label;
#endif
	new_call_and_jump->cj_jump_label.label_offset=CURRENT_CODE_OFFSET;
}

static void as_call_and_jump (struct call_and_jump *call_and_jump)
{
	call_and_jump->cj_label.label_id=TEXT_LABEL_ID;			
#ifdef FUNCTION_LEVEL_LINKING
	call_and_jump->cj_label.label_object_label=code_object_label;
#endif
	call_and_jump->cj_label.label_offset=CURRENT_CODE_OFFSET;

	as_i_call (0);
	as_branch_label (call_and_jump->cj_call_label,CALL_RELOCATION);

	as_st (REGISTER_O7,0,B_STACK_POINTER);
	
	as_i_bica (0,A_COND);
	as_branch_label (&call_and_jump->cj_jump_label,BRANCH_RELOCATION);
}

void initialize_assembler (FILE *output_file_d)
{
	output_file=output_file_d;
	setvbuf (output_file,NULL,_IOFBF,IO_BUFFER_SIZE);

	n_object_labels=1;
	
	first_object_label=NULL;
	last_object_label_l=&first_object_label;
	
	first_code_relocation=NULL;
	first_data_relocation=NULL;
	last_code_relocation_l=&first_code_relocation;
	last_data_relocation_l=&first_data_relocation;
	n_code_relocations=0;
	n_data_relocations=0;
#ifndef FUNCTION_LEVEL_LINKING
	data_section_alignment_mask=3;
#endif

	string_table_offset=1;
	initialize_buffers();

#ifdef FUNCTION_LEVEL_LINKING
	code_object_label=NULL;
	n_code_sections=0;
	
	data_object_label=NULL;
	n_data_sections=0;
#else	
	code_object_label=fast_memory_allocate_type (struct object_label);
	++n_object_labels;
	*last_object_label_l=code_object_label;
	last_object_label_l=&code_object_label->next;
	code_object_label->next=NULL;
	
	code_object_label->object_label_offset=0;
	code_object_label->object_label_length=0;
	code_object_label->object_label_kind=CODE_CONTROL_SECTION;

	data_object_label=fast_memory_allocate_type (struct object_label);
	++n_object_labels;
	*last_object_label_l=data_object_label;
	last_object_label_l=&data_object_label->next;
	data_object_label->next=NULL;
	
	data_object_label->object_label_offset=0;
	data_object_label->object_label_length=0;
	data_object_label->object_label_kind=DATA_CONTROL_SECTION;
	data_object_label->object_section_align8=0;
#endif
}

static void as_indirect_node_entry_jump (LABEL *label)
{
	long new_label_offset;
	struct label *new_label;

#ifdef FUNCTION_LEVEL_LINKING
	as_new_code_module();
#endif

	if (label->label_flags & EA_LABEL){
		int label_arity;
		extern LABEL *eval_fill_label,*eval_upd_labels[];

		label_arity=label->label_arity;
		
		if (label_arity<-2)
			label_arity=1;

		if (label_arity>=0 && label->label_ea_label!=eval_fill_label){
			as_sethi (0,REGISTER_A2);
			as_hi_or_lo_label (label->label_ea_label,0,HI22_RELOCATION);

			as_i_call (0);
			as_branch_label (eval_upd_labels[label_arity],CALL_RELOCATION);

			as_ori (REGISTER_A2,0,REGISTER_A2);
			as_hi_or_lo_label (label->label_ea_label,0,LO12_RELOCATION);
		} else {
			as_i_call (0);
			as_branch_label (label->label_ea_label,CALL_RELOCATION);
		
			as_nop();
			as_nop();
		}
		
		if (label->label_arity<0 || parallel_flag){
			LABEL *descriptor_label;

			descriptor_label=label->label_descriptor;

			if (descriptor_label->label_id<0)
				descriptor_label->label_id=next_label_id++;

			store_label_in_code_section (descriptor_label);
		} else
			as_number_of_arguments (0);
	} else
		if (label->label_arity<0 || parallel_flag){
			LABEL *descriptor_label;

			descriptor_label=label->label_descriptor;

			if (descriptor_label->label_id<0)
				descriptor_label->label_id=next_label_id++;

			store_label_in_code_section (descriptor_label);
		}

	as_number_of_arguments (label->label_arity);
		
	new_label_offset = CURRENT_CODE_OFFSET;
		
	new_label=allocate_memory_from_heap_type (struct label);
	*new_label=*label;

	as_i_call (0);
	as_branch_label (new_label,CALL_RELOCATION);

	label->label_id=TEXT_LABEL_ID;
#ifdef FUNCTION_LEVEL_LINKING
	label->label_object_label=code_object_label;
#endif
	label->label_offset=new_label_offset;
	
	as_nop();
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

		label->label_id=n_object_labels;
		++n_object_labels;

		label->label_offset=0;

		string_length=strlen (label->label_name);
		new_object_label->object_label_string_offset=string_table_offset;
		string_table_offset+=string_length+1;

		new_object_label->object_label_kind=IMPORTED_LABEL;
	}
	
	as_import_labels (label_node->label_node_left);
	as_import_labels (label_node->label_node_right);
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

static void write_l (int c)
{
	fputc (c>>24,output_file);
	fputc (c>>16,output_file);
	fputc (c>>8,output_file);
	fputc (c,output_file);
}

static void write_zstring (char *string)
{
    char c;

    do {
        c=*string++;
        write_c (c);
    } while (c!='\0');
}

#ifdef FUNCTION_LEVEL_LINKING
static int compute_section_strings_size (int string_size_without_digits,int n_sections)
{
	int section_strings_size,max_n_digits,power10_max_n_digits;

	section_strings_size=0;
	max_n_digits=1;
	power10_max_n_digits=10;
	while (n_sections>power10_max_n_digits){
		section_strings_size-=power10_max_n_digits;
		++max_n_digits;
		power10_max_n_digits*=10;
	}
	section_strings_size+=(string_size_without_digits+max_n_digits+1)*n_sections;

	return section_strings_size;
}

static int n_digits (int n)
{
	int i,power10;

	i=1;
	power10=10;

	while (n>=power10){
		++i;
		power10*=10;
	}

	return i;
}

static int n_sections;
#endif

static void write_file_header_and_section_headers (void)
{
	unsigned int offset;

#ifdef FUNCTION_LEVEL_LINKING
	int n_code_relocation_sections,n_data_relocation_sections;
	int section_strings_size;

	n_sections=n_code_sections+n_data_sections;

	{
		struct object_label *object_label,*previous_code_object_label,*previous_data_object_label;
		struct relocation *code_relocation,*data_relocation;
		int code_offset,data_offset;

		code_relocation=first_code_relocation;		
		code_offset=0;
		n_code_relocation_sections=0;
		previous_code_object_label=NULL;

		data_relocation=first_data_relocation;		
		data_offset=0;
		n_data_relocation_sections=0;
		previous_data_object_label=NULL;

		section_strings_size=0;

		for_l (object_label,first_object_label,next){
			if (object_label->object_label_kind==CODE_CONTROL_SECTION){
				if (previous_code_object_label!=NULL){
					int code_section_length,n_code_relocations_in_section;
					
					code_section_length=object_label->object_label_offset-code_offset;
					
					n_code_relocations_in_section=0;
					while (code_relocation!=NULL && 
						(code_relocation->relocation_offset < code_offset+code_section_length
						|| (code_relocation->relocation_offset==code_offset+code_section_length && code_relocation->relocation_kind==DUMMY_BRANCH_RELOCATION)))
					{
						code_relocation->relocation_offset-=code_offset;
						++n_code_relocations_in_section;
						
						code_relocation=code_relocation->next;
					}
					
					previous_code_object_label->object_label_length=code_section_length;
					previous_code_object_label->object_label_n_relocations=n_code_relocations_in_section;
					
					code_offset+=code_section_length;
					if (n_code_relocations_in_section>0){
						section_strings_size+=13+n_digits (previous_code_object_label->object_label_section_n);
						++n_code_relocation_sections;
					}
				}
				
				previous_code_object_label=object_label;
			} else if (object_label->object_label_kind==DATA_CONTROL_SECTION){
				if (previous_data_object_label!=NULL){
					int data_section_length,n_data_relocations_in_section;
					
					data_section_length=object_label->object_label_offset-data_offset;
					
					n_data_relocations_in_section=0;
					while (data_relocation!=NULL && data_relocation->relocation_offset < data_offset+data_section_length){
						data_relocation->relocation_offset-=data_offset;
						++n_data_relocations_in_section;
						
						data_relocation=data_relocation->next;
					}
					
					previous_data_object_label->object_label_length=data_section_length;
					previous_data_object_label->object_label_n_relocations=n_data_relocations_in_section;
					
					data_offset+=data_section_length;
					if (n_data_relocations_in_section>0){
						section_strings_size+=13+n_digits (previous_data_object_label->object_label_section_n);
						++n_data_relocation_sections;
					}
				}
				
				previous_data_object_label=object_label;
			}
		}

		if (previous_code_object_label!=NULL){
			int code_section_length,n_code_relocations_in_section;
			
			code_section_length=code_buffer_offset-code_offset;
			
			n_code_relocations_in_section=0;
			while (code_relocation!=NULL){
				code_relocation->relocation_offset-=code_offset;
				++n_code_relocations_in_section;
							
				code_relocation=code_relocation->next;
			}

			previous_code_object_label->object_label_n_relocations=n_code_relocations_in_section;
			previous_code_object_label->object_label_length=code_section_length;

			if (n_code_relocations_in_section>0){
				section_strings_size+=13+n_digits (previous_code_object_label->object_label_section_n);
				++n_code_relocation_sections;
			}
		}

		if (previous_data_object_label!=NULL){
			int data_section_length,n_data_relocations_in_section;
			
			data_section_length=data_buffer_offset-data_offset;
			
			n_data_relocations_in_section=0;
			while (data_relocation!=NULL){
				data_relocation->relocation_offset-=data_offset;
				++n_data_relocations_in_section;
							
				data_relocation=data_relocation->next;
			}

			previous_data_object_label->object_label_n_relocations=n_data_relocations_in_section;
			previous_data_object_label->object_label_length=data_section_length;

			if (n_data_relocations_in_section>0){
				section_strings_size+=13+n_digits (previous_data_object_label->object_label_section_n);
				++n_data_relocation_sections;
			}
		}
	}
	
	section_strings_size+=compute_section_strings_size (7,n_code_sections)+
						  compute_section_strings_size (7,n_data_sections);
#endif

    /* header: */
    write_l (0x7f454c46);
    write_l (0x01020100);
    write_l (0);
    write_l (0);
    write_l (0x00010002);
    write_l (1);
    write_l (0);
    write_l (0);
    write_l (0x34);
    write_l (0);
    write_l (0x00340000);
    write_l (0x00000028);
#ifdef FUNCTION_LEVEL_LINKING
	write_l (0x00000001 | ((n_sections+n_code_relocation_sections+n_data_relocation_sections+4)<<16));
#else
    write_l (0x00080001);
#endif

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

#ifdef FUNCTION_LEVEL_LINKING
	offset=0xd4+40*(n_sections+n_code_relocation_sections+n_data_relocation_sections);
#else
	offset=0x174;
#endif

    /* offset 0x5c: section header 1 */
    write_l (1);     /* .shstrtab offset */
    write_l (SHT_STRTAB);
    write_l (0);
    write_l (0);
    write_l (offset); /* offset */
#ifdef FUNCTION_LEVEL_LINKING
	write_l ((27+section_strings_size+3) & -4);
#else
    write_l (64);    /* size */
#endif
    write_l (0);
    write_l (0);
    write_l (1);     /* align */
    write_l (0);
#ifdef FUNCTION_LEVEL_LINKING
	offset+=(27+section_strings_size+3) & -4;
#else
	offset+=64;
#endif

#ifdef FUNCTION_LEVEL_LINKING
	{
		struct object_label *object_label;
		int code_offset,data_offset,code_relocations_offset,data_relocations_offset,section_string_offset;

		code_offset=0;
		section_string_offset=11;
	
		for_l (object_label,first_object_label,next){
			if (object_label->object_label_kind==CODE_CONTROL_SECTION){
				int code_section_length;
				
				code_section_length=object_label->object_label_length;
					
				write_l (section_string_offset);
				write_l (SHT_PROGBITS);
				write_l (SHF_ALLOC | SHF_EXECINSTR);
				write_l (0);
				write_l (offset+code_offset);
				write_l (code_section_length);
				write_l (0);
				write_l (0);
				write_l (4);
				write_l (0);

				section_string_offset+=8+n_digits (object_label->object_label_section_n);
				code_offset+=code_section_length;
			}
		}
		offset+=(code_offset+3) & -4;

		data_offset=0;

		for_l (object_label,first_object_label,next){
			if (object_label->object_label_kind==DATA_CONTROL_SECTION){
				int data_section_length;
	
				data_section_length=object_label->object_label_length;
					
				write_l (section_string_offset);
				write_l (SHT_PROGBITS);
				write_l (SHF_ALLOC | SHF_WRITE);
				write_l (0);
				write_l (offset+data_offset);
				write_l (data_section_length);
				write_l (0);
				write_l (0);
				write_l (object_label->object_section_align8 ? 8 : 4);
				write_l (0);
				
				section_string_offset+=8+n_digits (object_label->object_label_section_n);
				data_offset+=data_section_length;
			}
		}

		offset+=(data_offset+3) & -4;

		code_relocations_offset=0;
	
		for_l (object_label,first_object_label,next){
			if (object_label->object_label_kind==CODE_CONTROL_SECTION){
				int n_code_relocations_in_section;
			
				n_code_relocations_in_section=object_label->object_label_n_relocations;
				
				if (n_code_relocations_in_section>0){
					write_l (section_string_offset);
					write_l (SHT_RELA);
					write_l (0);
					write_l (0);
					write_l (offset+code_relocations_offset);
					write_l (12*n_code_relocations_in_section);
					write_l (n_sections+n_code_relocation_sections+n_data_relocation_sections+2);
					write_l (2+object_label->object_label_section_n);
					write_l (4);
					write_l (12);
					section_string_offset+=13+n_digits (object_label->object_label_section_n);
					code_relocations_offset+=12*n_code_relocations_in_section;
				}
			}
		}
		offset+=12*n_code_relocations;

		data_relocations_offset=0;
	
		for_l (object_label,first_object_label,next){
			if (object_label->object_label_kind==DATA_CONTROL_SECTION){
				int n_data_relocations_in_section;
			
				n_data_relocations_in_section=object_label->object_label_n_relocations;
				
				if (n_data_relocations_in_section>0){
					write_l (section_string_offset);
					write_l (SHT_RELA);
					write_l (0);
					write_l (0);
					write_l (offset+data_relocations_offset);
					write_l (12*n_data_relocations_in_section);
					write_l (n_sections+n_code_relocation_sections+n_data_relocation_sections+2);
					write_l (2+n_code_sections+object_label->object_label_section_n);
					write_l (4);
					write_l (12);
					section_string_offset+=13+n_digits (object_label->object_label_section_n);
					data_relocations_offset+=12*n_data_relocations_in_section;
				}
			}
		}
		offset+=12*n_data_relocations;
	}
#else
    /* offset 0x84: section header 2 */
    write_l (11);					/* .text offset */
    write_l (SHT_PROGBITS);
    write_l (SHF_ALLOC | SHF_EXECINSTR);
    write_l (0);
    write_l (offset);
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
    write_l (offset);
    write_l (data_buffer_offset);	     /* size */
    write_l (0);
    write_l (0);
    write_l (data_section_alignment_mask+1);	/* align */
    write_l (0);
	offset+=data_buffer_offset;
    /* offet 0xd4: section header 4 */
    write_l (23); 					 	/* .rela.text offset */
    write_l (SHT_RELA);
    write_l (0);
    write_l (0);
    write_l (offset);
    write_l (12*n_code_relocations);	/* size */
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
    write_l (offset);
    write_l (12*n_data_relocations);	/* size */
    write_l (6);						/* symbol table index */
    write_l (3);						/* data section index */
    write_l (4);  						/* align */
    write_l (12);
	offset+=12*n_data_relocations;
#endif

    /* offset 0x124: section header 6 */
#ifdef FUNCTION_LEVEL_LINKING
	write_l (11+section_strings_size);
#else
    write_l (45);   /* .symtab offset */
#endif
    write_l (SHT_SYMTAB);
    write_l (0);
    write_l (0);
    write_l (offset);
	write_l (16*(n_object_labels+n_sections));
#ifdef FUNCTION_LEVEL_LINKING
	write_l (n_sections+n_code_relocation_sections+n_data_relocation_sections+3);
	write_l (1+n_sections);
#else
    write_l (7);						/* string table index */
    write_l (3);
#endif
    write_l (4); 						/* align */
    write_l (16);
	offset+=16*(n_object_labels+n_sections);
    /* offset 0x14c: section header 7 */
#ifdef FUNCTION_LEVEL_LINKING
	write_l (19+section_strings_size);
#else
    write_l (53);  						/* .strtab offset */
#endif
    write_l (SHT_STRTAB);
    write_l (0);
    write_l (0);
    write_l (offset);
    write_l (string_table_offset);	 	/* size */
    write_l (0);
    write_l (0);
    write_l (0);  						/* align */
    write_l (0);

    /* offset 0x174: section 1 */
    write_c (0);
    write_zstring (".shstrtab"); /* 1 */
#ifdef FUNCTION_LEVEL_LINKING
	{
		struct object_label *object_label;
		int section_n;
		char section_name[20];

		for (section_n=0; section_n<n_code_sections; ++section_n){
			sprintf (section_name,".text.m%d",section_n);
			write_zstring (section_name);
		}

		for (section_n=0; section_n<n_data_sections; ++section_n){
			sprintf (section_name,".data.m%d",section_n);
			write_zstring (section_name);
		}

		for_l (object_label,first_object_label,next)
			if (object_label->object_label_kind==CODE_CONTROL_SECTION && object_label->object_label_n_relocations>0){ 
				sprintf (section_name,".rela.text.m%d",object_label->object_label_section_n);
				write_zstring (section_name);
			}
	
		for_l (object_label,first_object_label,next)
			if (object_label->object_label_kind==DATA_CONTROL_SECTION && object_label->object_label_n_relocations>0){ 
				sprintf (section_name,".rela.data.m%d",object_label->object_label_section_n);
				write_zstring (section_name);
			}
	}
#else
    write_zstring (".text");     /* 11 */
    write_zstring (".data");     /* 17 */
    write_zstring (".rela.text");/* 23 */
    write_zstring (".rela.data");/* 34 */
#endif
    write_zstring (".symtab");   /* 45 */
    write_zstring (".strtab");   /* 53 */
                                 /* 61 */
#ifdef FUNCTION_LEVEL_LINKING
	if (((27+section_strings_size) & 3)!=0){
		int n;

		n=4-((27+section_strings_size) & 3);
		do {
			write_c (0);
		} while (--n);
	}
#else
	write_c (0);
	write_c (0);
	write_c (0);
	/* offset 0x1b4 */
#endif
}

static void as_indirect_node_entry_jumps (struct label_node *label_node)
{
	LABEL *label;
	
	if (label_node==NULL)
		return;
	
	label=&label_node->label_node_label;
	
	if (!(label->label_flags & LOCAL_LABEL) && label->label_number==0)
		if (label->label_flags & NODE_ENTRY_LABEL)
			as_indirect_node_entry_jump (label);
	
	as_indirect_node_entry_jumps (label_node->label_node_left);
	as_indirect_node_entry_jumps (label_node->label_node_right);
}

#ifdef NEW_APPLY
extern LABEL *add_empty_node_labels[];

static void as_apply_update_entry (struct basic_block *block)
{
	if (block->block_n_node_arguments==-200){
		as_i_bica (0,A_COND);
		as_branch_label (block->block_ea_label,BRANCH_RELOCATION);
		as_nop();
		as_nop();
		as_nop();
	} else {
		as_dec (4,B_STACK_POINTER);
		as_i_call (0);
		as_branch_label (add_empty_node_labels[block->block_n_node_arguments+200],CALL_RELOCATION);
		as_st (REGISTER_O7,0,B_STACK_POINTER);
		as_i_bica (0,A_COND);
		as_branch_label (block->block_ea_label,BRANCH_RELOCATION);
	}
}
#endif

void write_code (void)
{
	struct basic_block *block;
	struct call_and_jump *call_and_jump;

	first_call_and_jump=NULL;

	as_indirect_node_entry_jumps (labels);

#ifdef FUNCTION_LEVEL_LINKING
	if (first_block!=NULL && !first_block->block_begin_module)
		first_block->block_begin_module=1;
#endif

	for_l (block,first_block,block_next){
#ifdef FUNCTION_LEVEL_LINKING
		if (block->block_begin_module){
			if (block->block_link_module){
				if (code_object_label!=NULL && CURRENT_CODE_OFFSET!=code_object_label->object_label_offset && block->block_labels){
					struct relocation *new_relocation;
					
					new_relocation=fast_memory_allocate_type (struct relocation);
					++n_code_relocations;
					
					*last_code_relocation_l=new_relocation;
					last_code_relocation_l=&new_relocation->next;
					new_relocation->next=NULL;
					
					U5 (new_relocation,
						relocation_label=block->block_labels->block_label_label,
						relocation_offset=CURRENT_CODE_OFFSET,
						relocation_object_label=code_object_label,
						relocation_kind=DUMMY_BRANCH_RELOCATION,
						relocation_addend=0);

					as_new_code_module();
				}
			} else
				as_new_code_module();
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
					as_sethi (0,REGISTER_A2);
					as_hi_or_lo_label (block->block_ea_label,0,HI22_RELOCATION);

					as_i_call (0);
					as_branch_label (eval_upd_labels[n_node_arguments],CALL_RELOCATION);

					as_ori (REGISTER_A2,0,REGISTER_A2);
					as_hi_or_lo_label (block->block_ea_label,0,LO12_RELOCATION);
				} else {
					as_i_call (0);
					as_branch_label (block->block_ea_label,CALL_RELOCATION);
					
					as_nop();
					as_nop();
				}
				
				if (block->block_descriptor!=NULL && (block->block_n_node_arguments<0 || parallel_flag)){
					store_label_in_code_section (block->block_descriptor);
				} else
					as_number_of_arguments (0);
			} else
				if (block->block_descriptor!=NULL)
					store_label_in_code_section (block->block_descriptor);
				else
					as_number_of_arguments (0);

			as_number_of_arguments (block->block_n_node_arguments);
		}
#ifdef NEW_APPLY
		else if (block->block_n_node_arguments<-100)
			as_apply_update_entry (block);
#endif

		as_labels (block->block_labels);

		if (block->block_n_new_heap_cells>0)
			as_garbage_collect_test (block);
		
		as_instructions (block->block_instructions);
	}
	
	for (call_and_jump=first_call_and_jump; call_and_jump!=NULL; call_and_jump=call_and_jump->cj_next){
#ifdef FUNCTION_LEVEL_LINKING
		as_new_code_module();
#endif
		as_call_and_jump (call_and_jump);
	}

#ifndef FUNCTION_LEVEL_LINKING
	as_nop();
#endif
}

static void relocate_code (void)
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
		label=relocation->relocation_label;

		switch (relocation->relocation_kind){
			case BRANCH_RELOCATION:
				if (label->label_id==TEXT_LABEL_ID
#ifdef FUNCTION_LEVEL_LINKING
					&& label->label_object_label==relocation->relocation_object_label
#endif
				){
					instruction_offset=relocation->relocation_offset;
					while (instruction_offset >= buffer_offset+BUFFER_SIZE){
						object_buffer=object_buffer->next;
						buffer_offset+=BUFFER_SIZE;
					}

					instruction_p=(ULONG*)((char*)(object_buffer->data)+(instruction_offset-buffer_offset));

					*instruction_p= ((*instruction_p)& 0xffc00000) | (((label->label_offset-instruction_offset+relocation->relocation_addend)>>2) & 0x3fffff);

					*relocation_p=relocation->next;
					--n_code_relocations;
					continue;
				}
#ifdef FUNCTION_LEVEL_LINKING
				else if (label->label_id==TEXT_LABEL_ID || label->label_id==DATA_LABEL_ID){
					if (label->label_object_label==NULL)
						internal_error_in_function ("relocate_code");
					
					relocation->relocation_addend -= label->label_object_label->object_label_offset;
				}
#endif
				break;
			case CALL_RELOCATION:
				if (label->label_id==TEXT_LABEL_ID
#ifdef FUNCTION_LEVEL_LINKING
					&& label->label_object_label==relocation->relocation_object_label
#endif
				){
					instruction_offset=relocation->relocation_offset;
					while (instruction_offset >= buffer_offset+BUFFER_SIZE){
						object_buffer=object_buffer->next;
						buffer_offset+=BUFFER_SIZE;
					}

					instruction_p=(ULONG*)((char*)(object_buffer->data)+(instruction_offset-buffer_offset));

					*instruction_p= ((*instruction_p)& 0xc0000000) | (((label->label_offset-instruction_offset+relocation->relocation_addend)>>2) & 0x3fffffff);					

					*relocation_p=relocation->next;
					--n_code_relocations;
					continue;
				}
#ifdef FUNCTION_LEVEL_LINKING
				else if (label->label_id==TEXT_LABEL_ID || label->label_id==DATA_LABEL_ID){
					if (label->label_object_label==NULL)
						internal_error_in_function ("relocate_code");
					
					relocation->relocation_addend -= label->label_object_label->object_label_offset;
				}
#endif
				break;
#ifdef FUNCTION_LEVEL_LINKING
			case HI22_RELOCATION:
			case LO12_RELOCATION:
			case LONG_WORD_RELOCATION:
				if (label->label_id==TEXT_LABEL_ID || label->label_id==DATA_LABEL_ID){
					if (label->label_object_label==NULL)
						internal_error_in_function ("relocate_code");
						
					relocation->relocation_addend -= label->label_object_label->object_label_offset;
				}
				break;
			case DUMMY_BRANCH_RELOCATION:
				if (label->label_id==TEXT_LABEL_ID){
					if (label->label_object_label!=relocation->relocation_object_label){
						relocation->relocation_addend -= label->label_object_label->object_label_offset;
						relocation_p=&relocation->next;
					} else {
						*relocation_p=relocation->next;
						--n_code_relocations;
					}
					continue;
				} else {
					internal_error_in_function ("relocate_code");
					*relocation_p=relocation->next;
				}
#endif
		}

		relocation_p=&relocation->next;
	}
}

static void relocate_data (void)
{
#ifdef FUNCTION_LEVEL_LINKING
	struct relocation *relocation;

	for_l (relocation,first_data_relocation,next){
		switch (relocation->relocation_kind){
			case LONG_WORD_RELOCATION:
			{
				struct label *label;
			
				label=relocation->relocation_label;
				
				if (label->label_id==TEXT_LABEL_ID || label->label_id==DATA_LABEL_ID){
					if (label->label_object_label==NULL)
						internal_error_in_function ("relocate_data");
		
					relocation->relocation_addend -= label->label_object_label->object_label_offset;
				}
			}
		}
	}
#endif
}

#ifdef FUNCTION_LEVEL_LINKING
static int elf_label_number (struct label *label)
{
	int label_n;
					
	label_n=label->label_id;
	if (label_n==TEXT_LABEL_ID){
		label_n=label->label_object_label->object_label_number;
		if (label_n==0)
			return 1+label->label_object_label->object_label_section_n;
		else
			return label_n+n_sections;
	} else if (label_n==DATA_LABEL_ID){
		label_n=label->label_object_label->object_label_number;
		if (label_n==0)
			return 1+n_code_sections+label->label_object_label->object_label_section_n;
		else
			return label_n+n_sections;
	} else {
		if (label_n==-1)
			internal_error_in_function ("elf_label_number");
		return label_n+n_sections;
	}
}
#endif

static void write_code_relocations (void)
{
	struct relocation *relocation;
	
	for_l (relocation,first_code_relocation,next){
		struct label *label;
		
		label=relocation->relocation_label;

		switch (relocation->relocation_kind){
			case BRANCH_RELOCATION:
				write_l (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_SPARC_WDISP22));
#else
				write_l (ELF32_R_INFO (label->label_id,R_SPARC_WDISP22));
#endif
				write_l (relocation->relocation_addend+label->label_offset);
				break;
			case CALL_RELOCATION:
				write_l (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_SPARC_WDISP30));
#else
				write_l (ELF32_R_INFO (label->label_id,R_SPARC_WDISP30));
#endif
				write_l (relocation->relocation_addend+label->label_offset);
				break;
			case HI22_RELOCATION:
				write_l (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_SPARC_HI22));
#else
				write_l (ELF32_R_INFO (label->label_id,R_SPARC_HI22));
#endif
				write_l (relocation->relocation_addend+label->label_offset);
				break;
			case LO12_RELOCATION:
				write_l (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_SPARC_LO10));
#else
				write_l (ELF32_R_INFO (label->label_id,R_SPARC_LO10));
#endif
				write_l (relocation->relocation_addend+label->label_offset);
				break;
			case LONG_WORD_RELOCATION:
				write_l (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_SPARC_32));
#else
				write_l (ELF32_R_INFO (label->label_id,R_SPARC_32));
#endif
				write_l (relocation->relocation_addend+label->label_offset);
				break;
			case DUMMY_BRANCH_RELOCATION:
				write_l (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_SPARC_NONE));
#else
				write_l (ELF32_R_INFO (label->label_id,R_SPARC_NONE));
#endif
				write_l (relocation->relocation_addend+label->label_offset);
				break;
			default:
				internal_error_in_function ("write_code_relocations");
		}
	}
}

static void write_data_relocations (void)
{
	struct relocation *relocation;
	
	for_l (relocation,first_data_relocation,next){
		struct label *label;
		
		label=relocation->relocation_label;
		switch (relocation->relocation_kind){
			case LONG_WORD_RELOCATION:
				write_l (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_SPARC_32));
#else
				write_l (ELF32_R_INFO (label->label_id,R_SPARC_32));
#endif
				write_l (relocation->relocation_addend+label->label_offset);
				break;
			default:
				internal_error_in_function ("write_data_relocations");
		}
	}
}

static void write_object_labels (void)
{
	struct object_label *object_label;
	int code_section_number,data_section_number;
#if defined (RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL) && defined (FUNCTION_LEVEL_LINKING)
	struct object_label *current_text_or_data_object_label;

	current_text_or_data_object_label=NULL;
#endif

	code_section_number=0;
	data_section_number=0;

	write_l (0);
	write_l (0);
	write_l (0);
	write_l (0);
# ifndef FUNCTION_LEVEL_LINKING
	write_l (0);
	write_l (0);
	write_l (0);
	write_c (ELF32_ST_INFO (STB_LOCAL,STT_SECTION));
	write_c (0);
	write_w (2);

	write_l (0);
	write_l (0);
	write_l (0);
	write_c (ELF32_ST_INFO (STB_LOCAL,STT_SECTION));
	write_c (0);
	write_w (3);
#else
	{
		int section_n;

		for (section_n=0; section_n<n_code_sections; ++section_n){
			write_l (0);
			write_l (0);
			write_l (0);
			write_c (ELF32_ST_INFO (STB_LOCAL,STT_SECTION));
			write_c (0);
			write_w (2+section_n);
		}

		for (section_n=0; section_n<n_data_sections; ++section_n){
			write_l (0);
			write_l (0);
			write_l (0);
			write_c (ELF32_ST_INFO (STB_LOCAL,STT_SECTION));
			write_c (0);
			write_w (2+n_code_sections+section_n);
		}
	}
# endif

	for_l (object_label,first_object_label,next){
		switch (object_label->object_label_kind){
			case CODE_CONTROL_SECTION:
				break;
			case DATA_CONTROL_SECTION:
#if defined (RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL) && defined (FUNCTION_LEVEL_LINKING)
				current_text_or_data_object_label=object_label;
#endif
				break;
			case IMPORTED_LABEL:
				write_l (object_label->object_label_string_offset);
				write_l (0);
				write_l (0);
				write_c (ELF32_ST_INFO (STB_GLOBAL,STT_NOTYPE));
				write_c (0);
				write_w (0);
				break;
			case EXPORTED_CODE_LABEL:
			{
				struct label *label;
				
				label=object_label->object_label_label;

				write_l (object_label->object_label_string_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_l (label->label_offset - label->label_object_label->object_label_offset);
#else
				write_l (label->label_offset);
#endif
				write_l (0);
				write_c (ELF32_ST_INFO (STB_GLOBAL,STT_FUNC));
				write_c (0);
#ifdef FUNCTION_LEVEL_LINKING
				write_w (2+label->label_object_label->object_label_section_n);
#else
				write_w (2);
#endif
				break;
			}
			case EXPORTED_DATA_LABEL:
			{
				struct label *label;
				
				label=object_label->object_label_label;

				write_l (object_label->object_label_string_offset);
#ifdef FUNCTION_LEVEL_LINKING
# ifdef RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL
				write_l (label->label_offset - current_text_or_data_object_label->object_label_offset);
# else
				write_l (label->label_offset - label->label_object_label->object_label_offset);
#endif
#else
				write_l (label->label_offset);
#endif
				write_l (0);
				write_c (ELF32_ST_INFO (STB_GLOBAL,STT_OBJECT));
				write_c (0);
#ifdef FUNCTION_LEVEL_LINKING
				write_w (2+n_code_sections+label->label_object_label->object_label_section_n);
#else
				write_w (3);
#endif
				break;
			}
			default:
				internal_error_in_function ("write_object_labels");
		}
	}
}

static void write_string_table (void)
{
	struct object_label *object_label;

	write_c (0);

	for_l (object_label,first_object_label,next){
		int object_label_kind;
		
		object_label_kind=object_label->object_label_kind;
		
		if ((object_label_kind==IMPORTED_LABEL || object_label_kind==EXPORTED_CODE_LABEL || object_label_kind==EXPORTED_DATA_LABEL)
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
}

void assemble_code (void)
{
	as_import_labels (labels);

	write_code();

	flush_data_buffer();
	flush_code_buffer();

#ifndef FUNCTION_LEVEL_LINKING
	code_object_label->object_label_length=code_buffer_offset;
	data_object_label->object_label_length=data_buffer_offset;
#endif

	relocate_code();
	relocate_data();

	write_file_header_and_section_headers();

	write_buffers_and_release_memory (&first_code_buffer);
	write_buffers_and_release_memory (&first_data_buffer);
	
	write_code_relocations();
	write_data_relocations();
	
	write_object_labels();

	write_string_table();
}
