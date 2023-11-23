/*
	File:	 cgtas.c
	Author:  John van Groningen
	Machine: Thumb2
*/

#define RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL
#define OPTIMISE_BRANCHES

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#ifdef LINUX_ELF 
#	define ELF
#endif

#if defined (ELF)
#	define FUNCTION_LEVEL_LINKING
#endif

#include "cgport.h"

#include "cgrconst.h"
#include "cgtypes.h"
#include "cg.h"
#include "cgiconst.h"
#include "cgcode.h"
#include "cgarmas.h"
#include "cginstructions.h"

#define FP_REVERSE_SUB_DIV_OPERANDS 1

#ifdef ELF
# include <elf.h>
# ifdef ANDROID
#  include <asm/elf.h>
#  ifndef EF_ARM_EABI_VER5
#   define EF_ARM_EABI_VER5 0x05000000
#  endif
# endif
# ifndef ELF32_ST_INFO
#  define ELF32_ST_INFO(b,t) (((b)<<4)+((t)&0xf))
# endif
# ifndef ELF32_R_INFO
#  define ELF32_R_INFO(s,t) (((s)<<8)+(unsigned char)(t))
# endif
# ifndef R_ARM_THM_CALL
#  define R_ARM_THM_CALL R_ARM_THM_PC22
# endif
#endif

#define for_l(v,l,n) for(v=(l);v!=NULL;v=v->n)

#define U3(s,v1,v2,v3) s->v1;s->v2;s->v3
#define U4(s,v1,v2,v3,v4) s->v1;s->v2;s->v3;s->v4
#define U5(s,v1,v2,v3,v4,v5) s->v1;s->v2;s->v3;s->v4;s->v5

#ifdef FUNCTION_LEVEL_LINKING
# define TEXT_LABEL_ID (-2)
# define DATA_LABEL_ID (-3)
#else
# ifdef ELF
#  define TEXT_LABEL_ID 1
#  define DATA_LABEL_ID 2
# else
#  define TEXT_LABEL_ID 0
#  define DATA_LABEL_ID 2
# endif
#endif

#define IO_BUFFER_SIZE 8192
#define BUFFER_SIZE 4096

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

static struct object_label *first_object_label,**last_object_label_l;

struct object_buffer {
	struct object_buffer *next;
	int size;
	unsigned char data [BUFFER_SIZE];
};

static struct object_buffer *first_code_buffer,*current_code_buffer;
static int code_buffer_free,code_buffer_offset;
static unsigned char *code_buffer_p;

static struct object_buffer *first_data_buffer,*current_data_buffer;
static int data_buffer_free,data_buffer_offset;
static unsigned char *data_buffer_p;

static void initialize_buffers (void)
{
	struct object_buffer *new_code_buffer,*new_data_buffer;
	
	new_code_buffer=memory_allocate (sizeof (struct object_buffer));
	
	new_code_buffer->size=0;
	new_code_buffer->next=NULL;
	
	first_code_buffer=new_code_buffer;
	current_code_buffer=new_code_buffer;
	code_buffer_offset=0;
	
	code_buffer_free=BUFFER_SIZE;
	code_buffer_p=(void*)new_code_buffer->data;

	new_data_buffer=memory_allocate (sizeof (struct object_buffer));
	
	new_data_buffer->size=0;
	new_data_buffer->next=NULL;
	
	first_data_buffer=new_data_buffer;
	current_data_buffer=new_data_buffer;
	data_buffer_offset=0;
	
	data_buffer_free=BUFFER_SIZE;
	data_buffer_p=new_data_buffer->data;
}

static FILE *output_file;

static void write_c (int c)
{
	fputc (c,output_file);
}

static void write_w (int c)
{
	fputc (c,output_file);
	fputc (c>>8,output_file);
}

static void write_l (int c)
{
	fputc (c,output_file);
	fputc (c>>8,output_file);
	fputc (c>>16,output_file);
	fputc (c>>24,output_file);
}

#define LONG_WORD_RELOCATION 0
#define CALL_RELOCATION 1
#define BRANCH_RELOCATION 2
#define SHORT_BRANCH_RELOCATION 3 /* R_ARM_THM_JUMP8 */
#define JUMP_RELOCATION 4 /* optimisable */
#define LONG_JUMP_RELOCATION 5 /* not optimisable */
#define DUMMY_BRANCH_RELOCATION 6
#define LDR_OFFSET_RELOCATION 7 /* R_ARM_THM_PC12 optimisable */
#define LONG_LDR_OFFSET_RELOCATION 8 /* R_ARM_THM_PC12 not optimisable*/
#define VLDR_OFFSET_RELOCATION 9 /* R_ARM_THM_PC8 */
#define RELATIVE_LONG_WORD_RELOCATION 10
#define ADJUST_ADR_RELOCATION 11
#define MOVW_RELOCATION 12 /* R_ARM_THM_MOVW_ABS_NC */
#define MOVT_RELOCATION 13 /* R_ARM_THM_MOVT_ABS */
#define BRANCH_SKIP_BRANCH_RELOCATION 14
#ifdef OPTIMISE_BRANCHES
# define ALIGN_RELOCATION 15
# define NEW_SHORT_BRANCH_RELOCATION 16
# define SHORT_JUMP_RELOCATION 17 /* R_ARM_THM_JUMP11 */
# define NEW_SHORT_JUMP_RELOCATION 18
# define SHORT_LDR_OFFSET_RELOCATION 19 /* R_ARM_THM_PC8 */
# define NEW_SHORT_LDR_OFFSET_RELOCATION 20
# define ADR_RELOCATION 21 /* R_ARM_THM_ALU_PREL_11_0 */
# define LONG_WORD_LITERAL_RELOCATION 22
# define NEW_UNUSED_LONG_WORD_LITERAL_RELOCATION 23
# define UNUSED_LONG_WORD_LITERAL_RELOCATION 24
/* # define RELATIVE_LONG_WORD_LITERAL_RELOCATION 25 */
#endif

#ifndef R_ARM_THM_JUMP11
# define R_ARM_THM_JUMP11 102
#endif
#ifndef R_ARM_THM_JUMP8
# define R_ARM_THM_JUMP8 103
#endif

struct relocation {
	struct relocation *			next;
	unsigned long				relocation_offset;
	union {
		struct {
			WORD				s_align1;
			WORD				s_align2;
		} u_s;
		struct label *			u_label;
		struct literal_entry *	u_literal_entry_p; /* for all *LDR_OFFSET_RELOCATION */
	} relocation_u;
#ifdef FUNCTION_LEVEL_LINKING
# ifdef OPTIMISE_BRANCHES
	union {
		struct object_label	*	u2_object_label;
		struct mapping_symbol *	u2_mapping_symbol; /* for all *LONG_WORD_LITERAL_RELOCATION */
	} relocation_u2;
# else
	struct object_label	*		relocation_object_label;
# endif
#endif
	short						relocation_kind;
};

#define relocation_label relocation_u.u_label
#define relocation_literal_entry_p relocation_u.u_literal_entry_p
#define relocation_align1 relocation_u.u_s.s_align1
#define relocation_align2 relocation_u.u_s.s_align2
#ifdef OPTIMISE_BRANCHES
#define relocation_object_label relocation_u2.u2_object_label
#define relocation_mapping_symbol relocation_u2.u2_mapping_symbol
#endif

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

static struct relocation *first_code_relocation,**last_code_relocation_l;
static struct relocation *first_data_relocation,**last_data_relocation_l;
static int n_code_relocations,n_data_relocations;

static int n_object_labels;

static unsigned long string_table_offset;

static struct object_label *code_object_label,*data_object_label;
#ifdef FUNCTION_LEVEL_LINKING
static int n_code_sections,n_data_sections;
#endif

struct call_and_jump {
	struct call_and_jump *cj_next;
	struct label *cj_call_label;
	struct label cj_label;
	struct label cj_jump;
};

static struct call_and_jump *first_call_and_jump,*last_call_and_jump;

struct mapping_symbol {
	struct mapping_symbol *ms_next;
	unsigned long ms_data_offset;
	unsigned long ms_table_size;
};

static struct mapping_symbol *first_mapping_symbol,*last_mapping_symbol;
int n_mapping_symbols; /* not length of struct mapping_symbol list */
unsigned long last_mapping_symbol_code_offset,end_code_offset;

void initialize_assembler (FILE *output_file_d)
{
	output_file=output_file_d;
#ifdef ELF
	n_object_labels=1;
#else
	n_object_labels=0;
#endif
	setvbuf (output_file,NULL,_IOFBF,IO_BUFFER_SIZE);

	first_object_label=NULL;
	last_object_label_l=&first_object_label;
	
	first_code_relocation=NULL;
	first_data_relocation=NULL;
	last_code_relocation_l=&first_code_relocation;
	last_data_relocation_l=&first_data_relocation;
	n_code_relocations=0;
	n_data_relocations=0;
	
	first_call_and_jump=NULL;
	first_mapping_symbol=NULL;
	n_mapping_symbols=0;
#ifdef ELF
# ifndef FUNCTION_LEVEL_LINKING
	string_table_offset=13;
# else
	string_table_offset=7;
# endif
#else
	string_table_offset=4;
#endif
	initialize_buffers();

#ifdef FUNCTION_LEVEL_LINKING
	code_object_label=NULL;
	n_code_sections=0;
	
	data_object_label=NULL;
	n_data_sections=0;
#else	
	code_object_label=fast_memory_allocate_type (struct object_label);
# ifdef ELF
	++n_object_labels;
# else
	n_object_labels+=2;
# endif	
	*last_object_label_l=code_object_label;
	last_object_label_l=&code_object_label->next;
	code_object_label->next=NULL;
	
	code_object_label->object_label_offset=0;
	code_object_label->object_label_length=0;
	code_object_label->object_label_kind=CODE_CONTROL_SECTION;

	data_object_label=fast_memory_allocate_type (struct object_label);
# ifdef ELF
	++n_object_labels;
# else
	n_object_labels+=2;
# endif	
	*last_object_label_l=data_object_label;
	last_object_label_l=&data_object_label->next;
	data_object_label->next=NULL;
	
	data_object_label->object_label_offset=0;
	data_object_label->object_label_length=0;
	data_object_label->object_label_kind=DATA_CONTROL_SECTION;
	data_object_label->object_section_align8=0;
#endif
}

#define MAX_LITERAL_INSTRUCTION_OFFSET 4088
#define MAX_LITERAL_VLDR_OFFSET 1012

static unsigned long literal_table_at_offset;
static unsigned char *literal_table_at_buffer_p;

static void write_branch_and_literals (void);

static void store_2c (unsigned short i)
{
	if (code_buffer_free>0){
		code_buffer_free-=2;
		code_buffer_p[0]=i;
		code_buffer_p[1]=i>>8;
		code_buffer_p+=2;
	} else {
		struct object_buffer *new_buffer;

		current_code_buffer->size=BUFFER_SIZE;
	
		new_buffer=memory_allocate (sizeof (struct object_buffer));
	
		new_buffer->size=0;
		new_buffer->next=NULL;
	
		current_code_buffer->next=new_buffer;
		current_code_buffer=new_buffer;
		code_buffer_offset+=BUFFER_SIZE;

		code_buffer_free=BUFFER_SIZE-2;
		code_buffer_p=new_buffer->data;

		code_buffer_p[0]=i;
		code_buffer_p[1]=i>>8;
		code_buffer_p+=2;

		if (literal_table_at_offset-(unsigned long)code_buffer_offset <= (unsigned long) BUFFER_SIZE)
			literal_table_at_buffer_p = current_code_buffer->data + (literal_table_at_offset-(unsigned long)code_buffer_offset);
	}
}

static void store_w (unsigned short i)
{
	if (code_buffer_p>=literal_table_at_buffer_p)
		write_branch_and_literals();

	store_2c (i);
}

static void store_l (ULONG i)
{
	if (code_buffer_p>=literal_table_at_buffer_p)
		write_branch_and_literals();

	store_2c (i);
	store_2c (i>>16);
}

static void store_lsw (ULONG i)
{
	if (code_buffer_p>=literal_table_at_buffer_p)
		write_branch_and_literals();

	store_2c (i>>16);
	store_2c (i);
}

static void store_l_no_literal_table (ULONG i)
{
	store_2c (i);
	store_2c (i>>16);
}

static void store_lsw_no_literal_table (ULONG i)
{
	store_2c (i>>16);
	store_2c (i);
}

void store_long_word_in_data_section (ULONG c)
{
	if (data_buffer_free>=4){
		data_buffer_free-=4;
		*(ULONG*)data_buffer_p=c;
		data_buffer_p+=4;
	} else {
		struct object_buffer *new_buffer;

		current_data_buffer->size=BUFFER_SIZE;
	
		new_buffer=memory_allocate (sizeof (struct object_buffer));
	
		new_buffer->size=0;
		new_buffer->next=NULL;
	
		current_data_buffer->next=new_buffer;
		current_data_buffer=new_buffer;
		data_buffer_offset+=BUFFER_SIZE;
	
		data_buffer_free=BUFFER_SIZE-4;
		data_buffer_p=(void*)new_buffer->data;

		*(ULONG*)data_buffer_p=c;
		data_buffer_p+=4;
	}
}

void store_2_words_in_data_section (UWORD w1,UWORD w2)
{
	store_long_word_in_data_section (((UWORD)w1) | (w2<<16));
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
		shift=0;
		while (length>0){
			d |= string_p[0]<<shift;
			shift+=8;
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
	shift=0;
	while (length>0){
		d |= string_p[0]<<shift;
		shift+=8;
		--length;
		++string_p;
	}
	store_long_word_in_data_section (d);
} 

#define CURRENT_CODE_OFFSET (code_buffer_offset+(code_buffer_p-current_code_buffer->data))
#define CURRENT_DATA_OFFSET (data_buffer_offset+(data_buffer_p-current_data_buffer->data))

static void store_label_in_code_section (struct label *label)
{
	struct relocation *new_relocation;

	new_relocation=fast_memory_allocate_type (struct relocation);
	++n_code_relocations;
	
	*last_code_relocation_l=new_relocation;
	last_code_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;
	
	new_relocation->relocation_label=label;
	new_relocation->relocation_offset=CURRENT_CODE_OFFSET-4;
	new_relocation->relocation_kind=LONG_WORD_RELOCATION;
}

#ifdef OPTIMISE_BRANCHES
static void store_label_in_literal_table (struct literal_entry *literal_entry_p)
{
	struct relocation *new_relocation;

	new_relocation=fast_memory_allocate_type (struct relocation);
	++n_code_relocations;
	
	*last_code_relocation_l=new_relocation;
	last_code_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;
	
	new_relocation->relocation_literal_entry_p=literal_entry_p;
	new_relocation->relocation_offset=CURRENT_CODE_OFFSET-4;
	new_relocation->relocation_mapping_symbol=last_mapping_symbol;
	new_relocation->relocation_kind=LONG_WORD_LITERAL_RELOCATION;
}
#endif

static void store_relative_label_in_code_section (struct label *label)
{
	struct relocation *new_relocation;
	
	new_relocation=fast_memory_allocate_type (struct relocation);
	++n_code_relocations;
	
	*last_code_relocation_l=new_relocation;
	last_code_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;
	
	new_relocation->relocation_label=label;
	new_relocation->relocation_offset=CURRENT_CODE_OFFSET-4;
	new_relocation->relocation_kind=RELATIVE_LONG_WORD_RELOCATION;
}

static void store_low_label_word_in_code_section (struct label *label)
{
	struct relocation *new_relocation;

	new_relocation=fast_memory_allocate_type (struct relocation);
	++n_code_relocations;
	
	*last_code_relocation_l=new_relocation;
	last_code_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;
	
	new_relocation->relocation_label=label;
	new_relocation->relocation_offset=CURRENT_CODE_OFFSET-4;
	new_relocation->relocation_kind=MOVW_RELOCATION;
}

static void store_high_label_word_in_code_section (struct label *label)
{
	struct relocation *new_relocation;

	new_relocation=fast_memory_allocate_type (struct relocation);
	++n_code_relocations;
	
	*last_code_relocation_l=new_relocation;
	last_code_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;
	
	new_relocation->relocation_label=label;
	new_relocation->relocation_offset=CURRENT_CODE_OFFSET-4;
	new_relocation->relocation_kind=MOVT_RELOCATION;
}

struct literal_entry {
	LABEL				  * le_label;
	int						le_offset;
	DOUBLE *				le_r_p;
	int						le_usage_count;
	struct label 			le_load_instruction_label;
	struct literal_entry  *	le_next;
};

struct literal_entry *first_literal_entry,**literal_entry_l,**remaining_literal_entry_l;

static void begin_data_mapping (void)
{
	unsigned long current_code_offset;
	struct mapping_symbol *new_mapping_symbol;
	
	current_code_offset = CURRENT_CODE_OFFSET;
	
	if (! (first_mapping_symbol!=NULL && last_mapping_symbol_code_offset==current_code_offset && last_mapping_symbol->ms_data_offset>=current_code_offset)){
		new_mapping_symbol = allocate_memory_from_heap (sizeof (struct mapping_symbol));
		new_mapping_symbol->ms_next = NULL;
		new_mapping_symbol->ms_data_offset = current_code_offset;
		
		if (first_mapping_symbol==NULL)
			first_mapping_symbol = new_mapping_symbol;
		else
			last_mapping_symbol->ms_next = new_mapping_symbol;
		last_mapping_symbol = new_mapping_symbol;
	}
}	

static void as_nop (void)
{
	store_w (0xbf00); /* nop */
}

static void as_nop_w (void)
{
	store_lsw (0xf3af8000); /* nop */
}

static void write_literal_entries (void)
{
	struct literal_entry *literal_entry,**literal_entry_l;
	unsigned long current_code_offset;

	literal_entry_l=remaining_literal_entry_l;
	literal_entry=*literal_entry_l;
	do {
		unsigned long load_data_offset;
		
		load_data_offset = literal_entry->le_load_instruction_label.label_offset;
		current_code_offset = CURRENT_CODE_OFFSET;

		literal_entry->le_load_instruction_label.label_flags=0;
		literal_entry->le_load_instruction_label.label_id=TEXT_LABEL_ID;
#ifdef FUNCTION_LEVEL_LINKING
		literal_entry->le_load_instruction_label.label_object_label=code_object_label;
#endif
		literal_entry->le_load_instruction_label.label_offset=current_code_offset;

		if (literal_entry->le_label){
/*			literal_entry->le_label->label_flags &= ~HAS_LITERAL_ENTRY; */
			if (!pic_flag){
				store_l_no_literal_table (literal_entry->le_offset);
#ifdef OPTIMISE_BRANCHES
				store_label_in_literal_table (literal_entry);
#else
				store_label_in_code_section (literal_entry->le_label);
#endif
			} else {
				store_l_no_literal_table (current_code_offset - load_data_offset -12 + literal_entry->le_offset);
				store_relative_label_in_code_section (literal_entry->le_label);
			}
		} else {
			if (literal_entry->le_r_p==NULL){
				store_l_no_literal_table (literal_entry->le_offset);
			} else {
				/* to do: align 8 */
				store_l_no_literal_table (((LONG*)(literal_entry->le_r_p))[0]);
				store_l_no_literal_table (((LONG*)(literal_entry->le_r_p))[1]);
			}
		}
	} while (literal_entry_l=&literal_entry->le_next,(literal_entry=*literal_entry_l)!=NULL);

	remaining_literal_entry_l=literal_entry_l;
	
	current_code_offset = CURRENT_CODE_OFFSET;
	last_mapping_symbol_code_offset = current_code_offset;
	last_mapping_symbol->ms_table_size = current_code_offset - last_mapping_symbol->ms_data_offset;
}

static void write_literals (void)
{
	if (*remaining_literal_entry_l!=NULL){
		int align;
		
		align = 3 & -(CURRENT_CODE_OFFSET-code_object_label->object_label_offset);
#ifdef OPTIMISE_BRANCHES
		{
			struct relocation *new_relocation;

			new_relocation=fast_memory_allocate_type (struct relocation);
			
			*last_code_relocation_l=new_relocation;
			last_code_relocation_l=&new_relocation->next;
			new_relocation->next=NULL;
			
			U5 (new_relocation,
				relocation_offset=CURRENT_CODE_OFFSET,
				relocation_kind=ALIGN_RELOCATION,
				relocation_align1=align,
				relocation_align2=align,			
				relocation_object_label=code_object_label);
		}
#endif
		switch (align){
			case 0:
				break;
			case 2:
				as_nop();
				break;
			default:
				internal_error_in_function ("write_literals");
		}

		begin_data_mapping();
		write_literal_entries();
	}

	literal_table_at_offset = 0ul-1ul;
	literal_table_at_buffer_p = (unsigned char*)0ul-1ul;
}

static void write_literals_already_aligned (void)
{
	if (*remaining_literal_entry_l!=NULL){
		begin_data_mapping();
		write_literal_entries();
	}

	literal_table_at_offset = 0ul-1ul;
	literal_table_at_buffer_p = (unsigned char*)0ul-1ul;
}

static void as_branch_label (struct label *label,int relocation_kind)
{
	struct relocation *new_relocation;
	
	new_relocation=fast_memory_allocate_type (struct relocation);
	
	*last_code_relocation_l=new_relocation;
	last_code_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;

	new_relocation->relocation_label=label;
	new_relocation->relocation_offset=CURRENT_CODE_OFFSET-4;
#ifdef FUNCTION_LEVEL_LINKING
	new_relocation->relocation_object_label=code_object_label;
#endif
	new_relocation->relocation_kind=relocation_kind;
}

static void as_short_branch_label (struct label *label,int relocation_kind)
{
	struct relocation *new_relocation;
	
	new_relocation=fast_memory_allocate_type (struct relocation);
	
	*last_code_relocation_l=new_relocation;
	last_code_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;

	new_relocation->relocation_label=label;
	new_relocation->relocation_offset=CURRENT_CODE_OFFSET-2;
#ifdef FUNCTION_LEVEL_LINKING
	new_relocation->relocation_object_label=code_object_label;
#endif
	new_relocation->relocation_kind=relocation_kind;
}

static void write_branch_and_literals (void)
{
	struct literal_entry *empty_literal_entry_after_table;

	literal_table_at_offset = 0ul-1ul;
	literal_table_at_buffer_p = (unsigned char*)0ul-1ul;

	empty_literal_entry_after_table=allocate_memory_from_heap (sizeof (struct literal_entry));

	store_lsw_no_literal_table (0xf0009000); /* b */
	as_branch_label (&empty_literal_entry_after_table->le_load_instruction_label,LONG_JUMP_RELOCATION);

	write_literals();

	empty_literal_entry_after_table->le_load_instruction_label.label_flags=0;
	empty_literal_entry_after_table->le_load_instruction_label.label_id=TEXT_LABEL_ID;
#ifdef FUNCTION_LEVEL_LINKING
	empty_literal_entry_after_table->le_load_instruction_label.label_object_label=code_object_label;
#endif
	empty_literal_entry_after_table->le_load_instruction_label.label_offset=CURRENT_CODE_OFFSET;

	empty_literal_entry_after_table->le_label=NULL;
	empty_literal_entry_after_table->le_r_p=NULL;
	empty_literal_entry_after_table->le_offset=0;

	empty_literal_entry_after_table->le_next = *remaining_literal_entry_l;
	*remaining_literal_entry_l = empty_literal_entry_after_table;
	literal_entry_l = remaining_literal_entry_l = &empty_literal_entry_after_table->le_next;
}

static void as_literal_label (struct literal_entry *literal_entry_p,int relocation_kind)
{
	struct relocation *new_relocation;
	unsigned long current_code_offset;

	new_relocation=fast_memory_allocate_type (struct relocation);
	
	*last_code_relocation_l=new_relocation;
	last_code_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;

	current_code_offset = CURRENT_CODE_OFFSET-4;

	if (current_code_offset+MAX_LITERAL_INSTRUCTION_OFFSET < literal_table_at_offset){
		literal_table_at_offset = current_code_offset+MAX_LITERAL_INSTRUCTION_OFFSET;

		if (literal_table_at_offset-(unsigned long)code_buffer_offset <= (unsigned long) BUFFER_SIZE)
			literal_table_at_buffer_p = current_code_buffer->data + (literal_table_at_offset-(unsigned long)code_buffer_offset);
	}
	
	new_relocation->relocation_literal_entry_p=literal_entry_p;
	new_relocation->relocation_offset=current_code_offset;
	if (pic_flag)
		literal_entry_p->le_load_instruction_label.label_offset=current_code_offset; /* for pic store offset of load instead, label offset stored by write_literals */
#ifdef FUNCTION_LEVEL_LINKING
	new_relocation->relocation_object_label=code_object_label;
#endif
	new_relocation->relocation_kind=relocation_kind;
}

static void as_literal_label_vldr (struct literal_entry *literal_entry_p)
{
	struct relocation *new_relocation;
	unsigned long current_code_offset;

	new_relocation=fast_memory_allocate_type (struct relocation);
	
	*last_code_relocation_l=new_relocation;
	last_code_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;

	current_code_offset = CURRENT_CODE_OFFSET-4;

	if (current_code_offset+MAX_LITERAL_VLDR_OFFSET < literal_table_at_offset){
		literal_table_at_offset = current_code_offset+MAX_LITERAL_VLDR_OFFSET;

		if (literal_table_at_offset-(unsigned long)code_buffer_offset <= (unsigned long) BUFFER_SIZE)
			literal_table_at_buffer_p = current_code_buffer->data + (literal_table_at_offset-(unsigned long)code_buffer_offset);
	}
	
	new_relocation->relocation_literal_entry_p=literal_entry_p;
	new_relocation->relocation_offset=current_code_offset;
	if (pic_flag)
		literal_entry_p->le_load_instruction_label.label_offset=current_code_offset; /* for pic store offset of load instead, label offset stored by write_literals */
#ifdef FUNCTION_LEVEL_LINKING
	new_relocation->relocation_object_label=code_object_label;
#endif
	new_relocation->relocation_kind=VLDR_OFFSET_RELOCATION;
}

static void as_literal_constant_entry (int i,int ldr_offset_relocation)
{
	struct literal_entry *new_literal_entry;

	new_literal_entry=allocate_memory_from_heap (sizeof (struct literal_entry));

	new_literal_entry->le_label=NULL;
	new_literal_entry->le_offset=i;
	new_literal_entry->le_r_p=NULL;
	new_literal_entry->le_usage_count=1;

	*literal_entry_l=new_literal_entry;
	literal_entry_l=&new_literal_entry->le_next;
	
	new_literal_entry->le_next=NULL;
	
	as_literal_label (new_literal_entry,ldr_offset_relocation);
}

static void as_literal_label_entry (LABEL *label,int offset,int ldr_offset_relocation)
{
	struct literal_entry *new_literal_entry;

	if (label->label_flags & HAS_LITERAL_ENTRY && label->label_literal_entry->le_offset==offset){
		new_literal_entry=label->label_literal_entry;

		if (new_literal_entry->le_load_instruction_label.label_id==-4){
			/* table not yet generated */
			++new_literal_entry->le_usage_count;
			as_literal_label (new_literal_entry,ldr_offset_relocation);
			return;
		}

		if (CURRENT_CODE_OFFSET-4+8 - new_literal_entry->le_load_instruction_label.label_offset <= MAX_LITERAL_INSTRUCTION_OFFSET
#ifdef FUNCTION_LEVEL_LINKING
			&& new_literal_entry->le_load_instruction_label.label_object_label==code_object_label
#endif
		){
			++new_literal_entry->le_usage_count;
			as_literal_label (new_literal_entry,LONG_LDR_OFFSET_RELOCATION);
			return;
		}

		label->label_flags &= ~HAS_LITERAL_ENTRY;
	}

	new_literal_entry=allocate_memory_from_heap (sizeof (struct literal_entry));

	new_literal_entry->le_label=label;
	new_literal_entry->le_offset=offset;
	new_literal_entry->le_r_p=NULL;
	new_literal_entry->le_usage_count=1;

	*literal_entry_l=new_literal_entry;
	literal_entry_l=&new_literal_entry->le_next;
	
	new_literal_entry->le_next=NULL;
	
	if (!pic_flag){
		label->label_flags |= HAS_LITERAL_ENTRY;
		label->label_literal_entry=new_literal_entry;
		new_literal_entry->le_load_instruction_label.label_id=-4;
	}
	
	as_literal_label (new_literal_entry,ldr_offset_relocation);
}

static void as_float_load_int_literal_entry (int offset)
{
	struct literal_entry *new_literal_entry;
	
	new_literal_entry=allocate_memory_from_heap (sizeof (struct literal_entry));

	new_literal_entry->le_label=NULL;
	new_literal_entry->le_offset=offset;
	new_literal_entry->le_r_p=NULL;
	new_literal_entry->le_usage_count=1;

	*literal_entry_l=new_literal_entry;
	literal_entry_l=&new_literal_entry->le_next;
	
	new_literal_entry->le_next=NULL;

	as_literal_label_vldr (new_literal_entry);
}

static void as_float_literal_entry (DOUBLE *r_p)
{
	struct literal_entry *new_literal_entry;
	
	new_literal_entry=allocate_memory_from_heap (sizeof (struct literal_entry));

	new_literal_entry->le_r_p=r_p;
	new_literal_entry->le_label=NULL;
	new_literal_entry->le_offset=0;
	new_literal_entry->le_usage_count=1;

	*literal_entry_l=new_literal_entry;
	literal_entry_l=&new_literal_entry->le_next;
	
	new_literal_entry->le_next=NULL;

	as_literal_label_vldr (new_literal_entry);
}

#ifdef FUNCTION_LEVEL_LINKING
void as_new_data_module (void)
{
	struct object_label *new_object_label;
	unsigned long current_data_offset;
	int data_section_label_number;
	
	new_object_label=fast_memory_allocate_type (struct object_label);
	data_object_label=new_object_label;

# ifdef ELF
	data_section_label_number=0;
# else
	data_section_label_number=n_object_labels;
	n_object_labels+=2;
# endif
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

	current_code_offset=CURRENT_CODE_OFFSET;

	new_object_label=fast_memory_allocate_type (struct object_label);
	code_object_label=new_object_label;

# ifdef ELF
	code_section_label_number=0;
# else
	code_section_label_number=n_object_labels;
	n_object_labels+=2;
# endif

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

	store_long_word_in_data_section (offset);

	new_relocation=fast_memory_allocate_type (struct relocation);
	++n_data_relocations;
	
	*last_data_relocation_l=new_relocation;
	last_data_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;
	
	new_relocation->relocation_label=label;
	new_relocation->relocation_offset=CURRENT_DATA_OFFSET-4;
	new_relocation->relocation_kind=LONG_WORD_RELOCATION;
}

#define reg_num(r) (real_reg_num[(r)+7])

static unsigned char real_reg_num[16]
/*	= { 13, 10, 9, 11, 8, 7, 6, 4, 3, 2, 1, 0, 5, 12, 14, 15 }; */
	= { 13,  6, 5, 12, 4, 3, 2, 1, 0,10, 9, 8,11,  7, 14, 15 };

#define REGISTER_PC 8
#define REGISTER_R11 5

#define REGISTER_S0 6
#define REGISTER_S1 7

static int immediate_shift (unsigned int i)
{
	int n_leading_zeros;
	
	if ((i & ~0xff)==0)
		return 0;

	n_leading_zeros = __builtin_clz (i);
	if ((i & ~(0xff000000>>n_leading_zeros))==0)
		return 24-n_leading_zeros;
	if ((i>>16)==(i & 0xffff)){
		if ((i & ~0x00ff00ff)==0)
			return 25;
		if ((i & ~0xff00ff00)==0)
			return 26;
		if (((i>>8) & 0xff)==(i & 0xff))
			return 27;
	}
	return -1;
}

static void store_l_is (int i_code,int i,int shift)
{
	if (shift==0){
		i_code |= i & 0xff;
	} else if (shift<=24){
		int rotate_right;

		i_code |= ((unsigned)i>>shift) & 0x7f;
		rotate_right = 32-shift;
		i_code |= ((rotate_right & 16)<<(26-4)) | ((rotate_right & 14)<<(12-1)) | ((rotate_right & 1)<<7);
	} else if (shift==25){
		i_code |= (1<<12) | (i & 0xff);
	} else if (shift==26){
		i_code |= (2<<12) | ((i>>8) & 0xff);
	} else if (shift==27){
		i_code |= (3<<12) | (i & 0xff);
	} else
		internal_error_in_function ("store_l_is");
	
	store_lsw (i_code); 
}

static void as_ldr_r_literal (int reg1)
{
	store_lsw (0xf8df0000 | (reg_num (reg1)<<12)); /* ldr rt,[pc+imm] */
}

static void as_movw_i_r (int i,int reg1)
{
	store_lsw (0xf2400000 | ((i & 0x800)<<(26-11)) | ((i & 0xf700)<<4) | (reg_num (reg1)<<8) | (i & 0xff)); /* movw rd,#i */
}

static void as_move_i_r (int i,int reg1)
{
	int shift;
	
	shift = immediate_shift (i);
	if (shift>=0)
		store_l_is (0xf04f0000 | (reg_num (reg1)<<8),i,shift); /* mov rd,#i<<s */
	else {
		shift = immediate_shift (~i);
		if (shift>=0)
			store_l_is (0xf06f0000 | (reg_num (reg1)<<8),~i,shift); /* mvn rd,#i<<s */
		else if ((i & ~0xffff)==0)
			as_movw_i_r (i,reg1);
		else {
			as_ldr_r_literal (reg1);
			as_literal_constant_entry (i,reg_num (reg1)<8 ? LDR_OFFSET_RELOCATION : LONG_LDR_OFFSET_RELOCATION);
		}
	}
}

static void as_mov_r_r (int s_reg,int d_reg)
{
	int s_reg_n,d_reg_n,i_code;

	s_reg_n=reg_num (s_reg);
	d_reg_n=reg_num (d_reg);

	i_code = 0xe4600 | ((d_reg_n & 8)<<(7-3)) | (s_reg_n<<3) | (d_reg_n & 7);

	store_w (i_code); 
}

static void as_movt_i_r (int i,int reg1)
{
	store_lsw (0xf2c00000 | ((i & 0x800)<<(26-11)) | ((i & 0xf700)<<4) | (reg_num (reg1)<<8) | (i & 0xff)); /* movt rd,#i */
}

static void as_ldr_id_r (int offset,int sa_reg,int d_reg)
{
	int sa_reg_n,d_reg_n,i_code;
	
	sa_reg_n=reg_num (sa_reg);
	d_reg_n=reg_num (d_reg);
	
	if (offset>=0){
		if (d_reg_n<8){
			if (sa_reg_n<8 && (offset & ~0x7c)==0){
				i_code = 0x6800 | (offset<<(6-2)) | (sa_reg_n<<3) | d_reg_n;
				store_w (i_code);
				return;
			} else if (sa_reg_n==13/*sp*/ && (offset & ~0x3fc)==0){
				i_code = 0x9800 | (d_reg_n<<8) | (offset>>2);
				store_w (i_code);
				return;
			}
		}
		if ((offset & ~0xfff)==0){
			i_code = 0xf8d00000 | (sa_reg_n<<16) | (d_reg_n<<12) | offset;
			store_lsw (i_code);
			return;
		}
	} else if (((-offset) & ~0xff)==0){
		i_code = 0xf8500c00 | (sa_reg_n<<16) | (d_reg_n<<12) | (-offset);
		store_lsw (i_code);
		return;
	}

	internal_error_in_function ("as_ldr_id_r");
}

static void as_ldr_id_r_update (int offset,int sa_reg,int d_reg)
{
	int sa_reg_n,d_reg_n,i_code;
	
	sa_reg_n=reg_num (sa_reg);
	d_reg_n=reg_num (d_reg);

	if (offset>=0){
		if ((offset & ~0xff)==0){
			i_code = 0xf8500f00 | (sa_reg_n<<16) | (d_reg_n<<12) | offset;
			store_lsw (i_code);
			return;
		}
	} else {
		if (((-offset) & ~0xff)==0){
			i_code = 0xf8500d00 | (sa_reg_n<<16) | (d_reg_n<<12) | (-offset);
			store_lsw (i_code);
			return;
		}
	}

	internal_error_in_function ("as_ldr_id_r_update");
}

static void as_ldr_id_r_post_add (int offset,int sa_reg,int d_reg)
{
	int sa_reg_n,d_reg_n,i_code;
	
	sa_reg_n=reg_num (sa_reg);
	d_reg_n=reg_num (d_reg);

	if (offset>=0){
		if (offset==4 && sa_reg==B_STACK_POINTER){
			if (d_reg_n<8){
				store_w (0xbc00 | (1<<d_reg_n)); /* pop  */
				return;
			} else if (d_reg_n==15){
				store_w (0xbd00); /* pop {pc} */
				return;		
			}
		}
		if ((offset & ~0xff)==0){
			i_code = 0xf8500b00 | (sa_reg_n<<16) | (d_reg_n<<12) | offset;
			store_lsw (i_code);
			return;
		}
	} else {
		if (((-offset) & ~0xff)==0){
			i_code = 0xf8500900 | (sa_reg_n<<16) | (d_reg_n<<12) | (-offset);
			store_lsw (i_code);
			return;
		}
	}

	internal_error_in_function ("as_ldr_id_r_post_add");
}

static void as_ldrb_id_r (int offset,int sa_reg,int d_reg)
{
	int sa_reg_n,d_reg_n,i_code;
	
	sa_reg_n=reg_num (sa_reg);
	d_reg_n=reg_num (d_reg);
	
	if (offset>=0){
		if (d_reg_n<8 && sa_reg_n<8 && (offset & ~0x1f)==0){
			i_code = 0x7800 | (offset<<6) | (sa_reg_n<<3) | d_reg_n;
			store_w (i_code);
			return;
		}
		if ((offset & ~0xfff)==0){
			i_code = 0xf8900000 | (sa_reg_n<<16) | (d_reg_n<<12) | offset;
			store_lsw (i_code);
			return;
		}
	} else if (((-offset) & ~0xff)==0){
		i_code = 0xf8100c00 | (sa_reg_n<<16) | (d_reg_n<<12) | (-offset);
		store_lsw (i_code);
		return;
	}

	internal_error_in_function ("as_ldrb_id_r");
}

static void as_ldrd_id_r_r (int offset,int sa_reg,int d_reg1,int d_reg2)
{
	if (offset>=0){
		if ((offset & ~0x3fc)==0){
			store_lsw (0xe9d00000 | (reg_num (sa_reg)<<16) | (reg_num (d_reg1)<<12) | (reg_num (d_reg2)<<8) | (offset>>2));
			return;
		}
	} else if (((-offset) & ~0x3fc)==0){
		store_lsw (0xe9500000 | (reg_num (sa_reg)<<16) | (reg_num (d_reg1)<<12) | (reg_num (d_reg2)<<8) | (-(offset>>2)));
		return;
	}

	internal_error_in_function ("as_ldrd_id_r_r");
}

static void as_ldrd_id_r_r_update (int offset,int sa_reg,int d_reg1,int d_reg2)
{
	if (offset>=0){
		if ((offset & ~0x3fc)==0){
			store_lsw (0xe9f00000 | (reg_num (sa_reg)<<16) | (reg_num (d_reg1)<<12) | (reg_num (d_reg2)<<8) | (offset>>2));
			return;
		}
	} else if (((-offset) & ~0x3fc)==0){
		store_lsw (0xe9700000 | (reg_num (sa_reg)<<16) | (reg_num (d_reg1)<<12) | (reg_num (d_reg2)<<8) | (-(offset>>2)));
		return;
	}

	internal_error_in_function ("as_ldrd_id_r_r_update");
}

static void as_ldrsh_id_r (int offset,int sa_reg,int d_reg)
{
	int sa_reg_n,d_reg_n,i_code;
	
	sa_reg_n=reg_num (sa_reg);
	d_reg_n=reg_num (d_reg);
	
	if (offset>=0){
		if ((offset & ~0xfff)==0){
			i_code = 0xf9b00000 | (sa_reg_n<<16) | (d_reg_n<<12) | offset;
			store_lsw (i_code);
			return;
		}
	} else if (((-offset) & ~0xff)==0){
		i_code = 0xf9300c00 | (sa_reg_n<<16) | (d_reg_n<<12) | (-offset);
		store_lsw (i_code);
		return;
	}

	internal_error_in_function ("as_ldrsh_id_r");
}

static void as_ldr_ix_r (int reg_n,int reg_m,int shift,int reg_t)
{
	int reg_n_n,reg_m_n,reg_t_n;

	reg_n_n=reg_num (reg_n);
	reg_m_n=reg_num (reg_m);
	reg_t_n=reg_num (reg_t);
	
	if (shift==0 && reg_n_n<8 && reg_m_n<8 && reg_t_n<8)
		store_w (0x5800 | (reg_m_n<<6) | (reg_n_n<<3) | reg_t_n);
	else
		store_lsw (0xf8500000 | (reg_n_n<<16) | (reg_t_n<<12) | (shift<<4) | reg_m_n);
}

static void as_ldrb_ix_r (int reg_n,int reg_m,int shift,int reg_t)
{
	int reg_n_n,reg_m_n,reg_t_n;

	reg_n_n=reg_num (reg_n);
	reg_m_n=reg_num (reg_m);
	reg_t_n=reg_num (reg_t);

	if (shift==0 && reg_n_n<8 && reg_m_n<8 && reg_t_n<8)
		store_w (0x5c00 | (reg_m_n<<6) | (reg_n_n<<3) | reg_t_n);
	else
		store_lsw (0xf8100000 | (reg_n_n<<16) | (reg_t_n<<12) | (shift<<4) | reg_m_n);
}

static void as_subs_is_r_r (int i,int shift,int s_reg,int d_reg)
{
	int s_reg_n,d_reg_n;
	
	s_reg_n=reg_num (s_reg);
	d_reg_n=reg_num (d_reg);
	
	if (s_reg_n<8 && d_reg_n<8 && shift==0){
		if ((i & ~7)==0){
			store_w (0x1e00 | (i<<6) | (s_reg_n<<3) | d_reg_n);
			return;
		} else if ((i & ~0xff)==0 && s_reg_n==d_reg_n){
			store_w (0x3800 | (d_reg_n<<8) | i);
			return;
		}
	}

	store_l_is (0xf1b00000 | (s_reg_n<<16) | (d_reg_n<<8),i,shift);
}

static void as_asr_i_r_r (int i,int reg_m,int reg_d)
{
	store_lsw (0xea4f0020 | ((i & 28)<<(12-2)) | (reg_num (reg_d)<<8) | ((i & 3)<<6) | reg_num (reg_m));
}

static void as_asr_r_r_r (int reg_m,int reg_n,int reg_d)
{
	store_lsw (0xfa40f000 | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<8) | reg_num (reg_m));
}

static void as_lsl_i_r_r (int i,int reg_m,int reg_d)
{
	store_lsw (0xea4f0000 | ((i & 28)<<(12-2)) | (reg_num (reg_d)<<8) | ((i & 3)<<6) | reg_num (reg_m));
}

static void as_lsl_r_r_r (int reg_m,int reg_n,int reg_d)
{
	store_lsw (0xfa00f000 | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<8) | reg_num (reg_m));
}

static void as_lsls_i_r_r (int i,int reg_m,int reg_d)
{
	store_w (/*0x0000 | */ ((i & 31)<<6) | (reg_num (reg_m)<<3) | reg_num (reg_d));
}

static void as_lsr_i_r_r (int i,int reg_m,int reg_d)
{
	store_lsw (0xea4f0010 | ((i & 28)<<(12-2)) | (reg_num (reg_d)<<8) | ((i & 3)<<6) | reg_num (reg_m));
}

static void as_lsr_r_r_r (int reg_m,int reg_n,int reg_d)
{
	store_lsw (0xfa20f000 | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<8) | reg_num (reg_m));
}

static void as_ror_i_r_r (int i,int reg_m,int reg_d)
{
	store_lsw (0xea4f0030 | ((i & 28)<<(12-2)) | (reg_num (reg_d)<<8) | ((i & 3)<<6) | reg_num (reg_m));
}

static void as_ror_r_r_r (int reg_m,int reg_n,int reg_d)
{
	store_lsw (0xfa60f000 | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<8) | reg_num (reg_m));
}

static void as_str_r_id (int s_reg,int offset,int da_reg)
{
	int s_reg_n,da_reg_n;

	s_reg_n=reg_num (s_reg);
	da_reg_n=reg_num (da_reg);

	if (offset>=0){
		if (s_reg_n<8){
			if (da_reg_n<8 && (offset & ~0x7c)==0){
				store_w (0x6000 | (offset<<(6-2)) | (da_reg_n<<3) | s_reg_n);
				return;
			} else if (da_reg_n==13/*sp*/ && (offset & ~0x3fc)==0){
				store_w (0x9000 | (s_reg_n<<8) | (offset>>2));
				return;
			}
		}
		if ((offset & ~0xfff)==0){
			store_lsw (0xf8c00000 | (da_reg_n<<16) | (s_reg_n<<12) | offset);
			return;
		}
	} else if (((-offset) & ~0xff)==0){
		store_lsw (0xf8400c00 | (da_reg_n<<16) | (s_reg_n<<12) | (-offset));
		return;
	}

	internal_error_in_function ("as_str_r_id");
}

static void as_str_r_id_update (int s_reg,int offset,int da_reg)
{
	int s_reg_n,da_reg_n,i_code;

	s_reg_n=reg_num (s_reg);
	
	if (offset==-4 && da_reg==B_STACK_POINTER){
		if (s_reg_n<8){
			store_w (0xb400 | (1<<s_reg_n)); /* push  */
			return;
		} else if (s_reg_n==14){
			store_w (0xb500); /* push {lr} */
			return;		
		}
	}

	da_reg_n=reg_num (da_reg);

	if (offset>=0){
		if ((offset & ~0xff)==0){
			i_code = 0xf8400f00 | (da_reg_n<<16) | (s_reg_n<<12) | offset;
			store_lsw (i_code);
			return;
		}
	} else {
		if (((-offset) & ~0xff)==0){
			i_code = 0xf8400d00 | (da_reg_n<<16) | (s_reg_n<<12) | (-offset);
			store_lsw (i_code);
			return;
		}
	}

	internal_error_in_function ("as_str_r_id_update");
}

static void as_str_r_id_post_add (int s_reg,int offset,int da_reg)
{
	int s_reg_n,da_reg_n,i_code;
	
	s_reg_n=reg_num (s_reg);
	da_reg_n=reg_num (da_reg);

	if (offset==4 && s_reg_n<8 && da_reg_n<8){
		store_w (0xc000 | (da_reg_n<<8) | (1<<s_reg_n)); /* stm ! */
		return;
	}

	if (offset>=0){
		if ((offset & ~0xff)==0){
			i_code = 0xf8400b00 | (da_reg_n<<16) | (s_reg_n<<12) | offset;
			store_lsw (i_code);
			return;
		}
	} else {
		if (((-offset) & ~0xff)==0){
			i_code = 0xf8400900 | (da_reg_n<<16) | (s_reg_n<<12) | (-offset);
			store_lsw (i_code);
			return;
		}
	}

	internal_error_in_function ("as_str_r_id_post_add");
}

static void as_str_r_ix (int reg_t,int reg_n,int reg_m,int shift)
{
	int reg_t_n,reg_n_n,reg_m_n;

	reg_t_n=reg_num (reg_t);
	reg_n_n=reg_num (reg_n);
	reg_m_n=reg_num (reg_m);
	
	if (shift==0 && reg_n_n<8 && reg_m_n<8 && reg_t_n<8)
		store_w (0x5000 | (reg_m_n<<6) | (reg_n_n<<3) | reg_t_n);
	else
		store_lsw (0xf8400000 | (reg_n_n<<16) | (reg_t_n<<12) | (shift<<4) | reg_m_n);
}

static void as_strb_r_id (int s_reg,int offset,int da_reg)
{
	int s_reg_n,da_reg_n;

	s_reg_n=reg_num (s_reg);
	da_reg_n=reg_num (da_reg);

	if (offset>=0){
		if (s_reg_n<8){
			if (da_reg_n<8 && (offset & ~0x1f)==0){
				store_w (0x7000 | (offset<<6) | (da_reg_n<<3) | s_reg_n);
				return;
			}
		}
		if ((offset & ~0xfff)==0){
			store_lsw (0xf8800000 | (da_reg_n<<16) | (s_reg_n<<12) | offset);
			return;
		}
	} else if (((-offset) & ~0xff)==0){
		store_lsw (0xf8000c00 | (da_reg_n<<16) | (s_reg_n<<12) | (-offset));
		return;
	}

	internal_error_in_function ("as_strb_r_id");
}

static void as_strb_r_ix (int reg_t,int reg_n,int reg_m,int shift)
{
	int reg_t_n,reg_n_n,reg_m_n;

	reg_t_n=reg_num (reg_t);
	reg_n_n=reg_num (reg_n);
	reg_m_n=reg_num (reg_m);
	
	if (shift==0 && reg_n_n<8 && reg_m_n<8 && reg_t_n<8)
		store_w (0x5400 | (reg_m_n<<6) | (reg_n_n<<3) | reg_t_n);
	else
		store_lsw (0xf8000000 | (reg_n_n<<16) | (reg_t_n<<12) | (shift<<4) | reg_m_n);
}

static void as_strd_r_r_id (int s_reg1,int s_reg2,int offset,int da_reg)
{
	if (offset>=0){
		if ((offset & ~0x3fc)==0){
			store_lsw (0xe9c00000 | (reg_num (da_reg)<<16) | (reg_num (s_reg1)<<12) | (reg_num (s_reg2)<<8) | (offset>>2));
			return;
		}
	} else if (((-offset) & ~0x3fc)==0){
		store_lsw (0xe9400000 | (reg_num (da_reg)<<16) | (reg_num (s_reg1)<<12) | (reg_num (s_reg2)<<8) | (-(offset>>2)));
		return;
	}

	internal_error_in_function ("as_strd_r_r_id");
}

static void as_strd_r_r_id_post_add (int s_reg1,int s_reg2,int offset,int da_reg)
{
	int s_reg1_n,s_reg2_n,da_reg_n;

	s_reg1_n=reg_num (s_reg1);
	s_reg2_n=reg_num (s_reg2);
	da_reg_n=reg_num (da_reg);

	if (offset==8 && da_reg_n<8 && s_reg2_n<8 && s_reg1_n<s_reg2_n){
		store_w (0xc000 | (da_reg_n<<8) | (1<<s_reg1_n) | (1<<s_reg2_n)); /* stm ! */
		return;
	}

	if (offset>=0){
		if ((offset & ~0x3fc)==0){
			store_lsw (0xe8e00000 | (da_reg_n<<16) | (s_reg1_n<<12) | (s_reg2_n<<8) | (offset>>2));
			return;
		}
	} else if (((-offset) & ~0x3fc)==0){
		store_lsw (0xe8600000 | (da_reg_n<<16) | (s_reg1_n<<12) | (s_reg2_n<<8) | (-(offset>>2)));
		return;
	}

	internal_error_in_function ("as_strd_r_r_id_post_add");
}

static void as_tst_ir_r (int i,int shift,int reg)
{
	store_l_is (0xf0100f00 | (reg_num (reg)<<16),i,shift);
}

static void as_vldr_r_id (int dreg,int offset,int sa_reg)
{
	int i_code;

	i_code = 0xed100b00 | (reg_num (sa_reg)<<16) | (dreg<<12);

	offset>>=2;
	if (offset<0)
		i_code |= (-offset) & 0xff;
	else
		i_code |= (1<<23) | (offset & 0xff);

	store_lsw (i_code); 
}

static void as_vldr_s_id (int sreg,int offset,int sa_reg)
{
	int i_code;

	i_code = 0xed100a00 | (reg_num (sa_reg)<<16) | (sreg<<12);

	offset>>=2;
	if (offset<0)
		i_code |= (-offset) & 0xff;
	else
		i_code |= (1<<23) | (offset & 0xff);

	store_lsw (i_code); 
}

static void as_vstr_r_id (int dreg,int offset,int da_reg)
{
	int i_code;

	i_code = 0xed000b00 | (reg_num (da_reg)<<16) | (dreg<<12);

	offset>>=2;
	if (offset<0)
		i_code |= (-offset) & 0xff;
	else
		i_code |= (1<<23) | (offset & 0xff);

	store_lsw (i_code); 
}

static void as_vstr_s_id (int sreg,int offset,int da_reg)
{
	int i_code;

	i_code = 0xed000a00 | (reg_num (da_reg)<<16) | (sreg<<12);

	offset>>=2;
	if (offset<0)
		i_code |= (-offset) & 0xff;
	else
		i_code |= (1<<23) | (offset & 0xff);

	store_lsw (i_code); 
}

#define THUMB2_OP_ADD 8
#define THUMB2_OP_ADC 10
#define THUMB2_OP_SBC 11
#define THUMB2_OP_SUB 13

static void as_op_s_r_r_r (int op,int reg_m,int reg_n,int reg_d)
{
	store_lsw (0xea100000 | (op<<21) | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<8) | reg_num (reg_m)); /* data processing (shifted register) */
}

static void as_op_s_is_r_r (int op,int i,int shift,int s_reg,int d_reg)
{
	store_l_is (0xf0100000 | (op<<21) | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<8),i,shift); /* data processing (modified immediate) */
}

static void as_add_r_r_r (int reg_m,int reg_n,int reg_d)
{
	int d_reg_n;
	
	d_reg_n=reg_num (reg_d);
	
	if (reg_d==reg_n)
		store_w (0x4400 | ((d_reg_n & 8)<<(7-3)) | (reg_num (reg_m)<<3) | (d_reg_n & 7));
	else if (reg_d==reg_m)
		store_w (0x4400 | ((d_reg_n & 8)<<(7-3)) | (reg_num (reg_n)<<3) | (d_reg_n & 7));
	else
		store_lsw (0xeb000000 | (reg_num (reg_n)<<16) | (d_reg_n<<8) | reg_num (reg_m));
}

static void as_add_pc_r_no_literal_table (int reg)
{
	int reg_n;
	
	reg_n=reg_num (reg);

	store_2c (0x4400 | ((reg_n & 8)<<(7-3)) | (15<<3) | (reg_n & 7));
}

static void as_add_r_lsl_r_r (int reg_m,int lsl_m,int reg_n,int reg_d)
{
	store_lsw (0xeb000000 | (reg_num (reg_n)<<16) | ((lsl_m & 28)<<(12-2)) | (reg_num (reg_d)<<8) | ((lsl_m & 3)<<6) | reg_num (reg_m));
}

static void as_add_r_lsr_r_r (int reg_m,int lsr_m,int reg_n,int reg_d)
{
	store_lsw (0xeb000010 | (reg_num (reg_n)<<16) | ((lsr_m & 28)<<(12-2)) | (reg_num (reg_d)<<8) | ((lsr_m & 3)<<6) | reg_num (reg_m));
}

static void as_add_r_asr_r_r (int reg_m,int asr_m,int reg_n,int reg_d)
{
	store_lsw (0xeb000020 | (reg_num (reg_n)<<16) | ((asr_m & 28)<<(12-2)) | (reg_num (reg_d)<<8) | ((asr_m & 3)<<6) | reg_num (reg_m));
}

static void as_add_is_r_r (int i,int shift,int s_reg,int d_reg)
{
	store_l_is (0xf1000000 | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<8),i,shift);
}

static void as_adds_i_r (int i,int d_reg)
{
	store_w (0x3000 | (reg_num (d_reg)<<8) | i);
}

static void as_adds_is_r_r (int i,int shift,int s_reg,int d_reg)
{
	int s_reg_n,d_reg_n;

	s_reg_n=reg_num (s_reg);
	d_reg_n=reg_num (d_reg);

	if (shift==0 && s_reg_n<8 && d_reg_n<8){
		if ((i & ~7)==0){
			store_w (0x1c00 | (i<<6) | (s_reg_n<<3) | d_reg_n);
			return;
		} else if ((i & ~0xff)==0 && s_reg_n==d_reg_n){
			as_adds_i_r (i,d_reg);
			return;
		}
	}
	
	store_l_is (0xf1100000 | (s_reg_n<<16) | (d_reg_n<<8),i,shift);
}

static void as_add_i_sp (int i)
{
	store_w (0xb000 | (i>>2));
}

static void as_addw_i_r_r (int i,int s_reg,int d_reg)
{
	store_lsw (0xf2000000 | ((i<<(16+10-11)) & 0x4000000) | (reg_num (s_reg)<<16) | ((i<<(12-8)) & 0x7000) | (reg_num (d_reg)<<8) | (i & 0xff));
}

static void as_sub_r_r_r (int reg_m,int reg_n,int reg_d)
{
	store_lsw (0xeba00000 | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<8) | reg_num(reg_m));
}

static void as_sub_r_lsl_r_r (int reg_m,int lsl_m,int reg_n,int reg_d)
{
	store_lsw (0xeba00000 | (reg_num (reg_n)<<16) | ((lsl_m & 28)<<(12-2)) | (reg_num (reg_d)<<8) | ((lsl_m & 3)<<6) | reg_num (reg_m));
}

static void as_sub_r_lsr_r_r (int reg_m,int lsr_m,int reg_n,int reg_d)
{
	store_lsw (0xeba00010 | (reg_num (reg_n)<<16) | ((lsr_m & 28)<<(12-2)) | (reg_num (reg_d)<<8) | ((lsr_m & 3)<<6) | reg_num (reg_m));
}

static void as_sub_r_asr_r_r (int reg_m,int asr_m,int reg_n,int reg_d)
{
	store_lsw (0xeba00020 | (reg_num (reg_n)<<16) | ((asr_m & 28)<<(12-2)) | (reg_num (reg_d)<<8) | ((asr_m & 3)<<6) | reg_num (reg_m));
}

static void as_sub_is_r_r (int i,int shift,int s_reg,int d_reg)
{
	store_l_is (0xf1a00000 | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<8),i,shift);
}

static void as_sub_i_sp (int i)
{
	store_w (0xb080 | (i>>2));
}

static void as_subs_i_r (int i,int d_reg)
{
	store_w (0x3800 | (reg_num (d_reg)<<8) | i);
}

static void as_subw_i_r_r (int i,int s_reg,int d_reg)
{
	store_lsw (0xf2a00000 | ((i<<(16+10-11)) & 0x4000000) | (reg_num (s_reg)<<16) | ((i<<(12-8)) & 0x7000) | (reg_num (d_reg)<<8) | (i & 0xff));
}

static void as_rsb_is_r_r (int i,int shift,int s_reg,int d_reg)
{
	store_l_is (0xf1c00000 | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<8),i,shift);
}

static void as_cmp_r_r (int reg_m,int reg_n)
{
	int reg_m_n,reg_n_n;

	reg_m_n=reg_num (reg_m);
	reg_n_n=reg_num (reg_n);

	if (reg_m_n<8 && reg_n_n<8)
		store_w (0x4280 | (reg_m_n<<3) | reg_n_n);
	else
		store_w (0x4500 | ((reg_n_n & 8)<<(7-3)) | (reg_m_n<<3) | (reg_n_n & 7));
}

static void as_cmp_is_r (int i,int shift,int s_reg)
{
	int s_reg_n;
	
	s_reg_n=reg_num (s_reg);
	if (shift==0 && s_reg_n<8)
		store_w (0x2800 | (s_reg_n<<8) | i);
	else
		store_l_is (0xf1b00f00 | (s_reg_n<<16),i,shift);
}

static void as_cmn_is_r (int i,int shift,int s_reg)
{
	store_l_is (0xf1100f00 | (reg_num (s_reg)<<16),i,shift);
}

static void as_and_is_r_r (int i,int shift,int s_reg,int d_reg)
{
	store_l_is (0xf0000000 | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<8),i,shift);
}

static void as_and_r_r_r (int reg_m,int reg_n,int reg_d)
{
	store_lsw (0xea000000 | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<8) | reg_num (reg_m));
}

static void as_and_r_lsr_r_r (int reg_m,int lsr_m,int reg_n,int reg_d)
{
	store_lsw (0xea000010 | (reg_num (reg_n)<<16) | ((lsr_m & 28)<<(12-2)) | (reg_num (reg_d)<<8) | ((lsr_m & 3)<<6) | reg_num (reg_m));
}

static void as_bic_is_r_r (int i,int shift,int s_reg,int d_reg)
{
	store_l_is (0xf0200000 | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<8),i,shift);
}

static void as_eor_is_r_r (int i,int shift,int s_reg,int d_reg)
{
	store_l_is (0xf0800000 | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<8),i,shift);
}

static void as_eor_r_r_r (int reg_m,int reg_n,int reg_d)
{
	store_lsw (0xea800000 | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<8) | reg_num (reg_m));
}

static void as_orr_is_r_r (int i,int shift,int s_reg,int d_reg)
{
	store_l_is (0xf0400000 | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<8),i,shift);
}

static void as_orr_r_r_r (int reg_m,int reg_n,int reg_d)
{
	store_lsw (0xea400000 | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<8) | reg_num (reg_m));
}

static void as_mla_r_r_r_r (int n_reg,int m_reg,int a_reg,int d_reg)
{
	store_lsw (0xfb000000 | (reg_num (n_reg)<<16) | (reg_num (a_reg)<<12) | (reg_num (d_reg)<<8) | reg_num (m_reg));
}

static void as_mls_r_r_r_r (int n_reg,int m_reg,int a_reg,int d_reg)
{
	store_lsw (0xfb000010 | (reg_num (n_reg)<<16) | (reg_num (a_reg)<<12) | (reg_num (d_reg)<<8) | reg_num (m_reg));
}

static void as_smmul_r_r_r (int n_reg,int m_reg,int d_reg)
{
	store_lsw (0xfb50f000 | (reg_num (n_reg)<<16) | (reg_num (d_reg)<<8) | reg_num (m_reg));
}

static void as_smmla_r_r_r (int n_reg,int m_reg,int a_reg,int d_reg)
{
	store_lsw (0xfb500000 | (reg_num (n_reg)<<16) | (reg_num (a_reg)<<12) | (reg_num (d_reg)<<8) | reg_num (m_reg));
}

static void as_move_d_r (LABEL *label,int arity,int reg1)
{
	as_ldr_r_literal (reg1);
	as_literal_label_entry (label,arity,reg_num (reg1)<8 ? LDR_OFFSET_RELOCATION : LONG_LDR_OFFSET_RELOCATION);
	if (pic_flag)
		as_add_pc_r_no_literal_table (reg1);
}

static void as_move_l_r (LABEL *label,int reg1)
{
	as_ldr_r_literal (reg1);
	as_literal_label_entry (label,0,reg_num (reg1)<8 ? LDR_OFFSET_RELOCATION : LONG_LDR_OFFSET_RELOCATION);
	if (pic_flag)
		as_add_pc_r_no_literal_table (reg1);
}

static void as_moves_i_r (int i,int d_reg)
{
	store_w (0x2000 | (reg_num (d_reg)<<8) | i); /* mov rd,# */
}

static void as_uxtb_r_r_w (int s_reg,int d_reg)
{
	store_w (0xb2c0 | (reg_num (s_reg)<<3) | reg_num (d_reg));
}

static void as_uxth_r_r_w (int s_reg,int d_reg)
{
	store_w (0xb280 | (reg_num (s_reg)<<3) | reg_num (d_reg));
}

static void as_load_indexed_reg (int offset,struct index_registers *index_registers,int reg)
{
	int reg1,reg2;

	reg1=index_registers->a_reg.r;
	reg2=index_registers->d_reg.r;
	if ((offset & -4)!=0){
		int shift;

		shift = immediate_shift (offset>>2);
		if (shift>=0){
			as_add_is_r_r (offset>>2,shift,reg1,REGISTER_S0);
			as_ldr_ix_r (REGISTER_S0,reg2,offset & 3,reg);
			return;
		} else {
			shift = immediate_shift (-(offset>>2));
			if (shift>=0){
				as_sub_is_r_r (-(offset>>2),shift,reg1,REGISTER_S0);
				as_ldr_ix_r (REGISTER_S0,reg2,offset & 3,reg);
				return;
			}
		}
	} else {
		as_ldr_ix_r (reg1,reg2,offset & 3,reg);
		return;
	}

	internal_error_in_function ("as_load_indexed_reg");
}

static void as_store_b_reg_indexed (int reg,int offset,struct index_registers *index_registers,int scratch_reg)
{
	int reg1,reg2;
	
	reg1=index_registers->a_reg.r;
	reg2=index_registers->d_reg.r;
	if ((offset & -4)!=0){
		int shift;

		shift = immediate_shift (offset>>2);
		if (shift>=0){
			as_add_is_r_r (offset>>2,shift,reg1,scratch_reg);
			as_strb_r_ix (reg,scratch_reg,reg2,offset & 3);
			return;
		}
	} else {
		as_strb_r_ix (reg,reg1,reg2,offset & 3);
		return;
	}
	
	internal_error_in_function ("as_store_b_reg_indexed");
}

static void as_load_parameter_to_scratch_register (struct parameter *parameter_p)
{
	switch (parameter_p->parameter_type){
		case P_INDIRECT:
			as_ldr_id_r (parameter_p->parameter_offset,parameter_p->parameter_data.reg.r,REGISTER_S0);
			break;
		case P_INDEXED:
			as_load_indexed_reg (parameter_p->parameter_offset,parameter_p->parameter_data.ir,REGISTER_S0);
			break;
		case P_POST_INCREMENT:
			as_ldr_id_r_post_add (4,parameter_p->parameter_data.reg.r,REGISTER_S0);
			break;
		case P_INDIRECT_WITH_UPDATE:
			as_ldr_id_r_update (parameter_p->parameter_offset,parameter_p->parameter_data.reg.r,REGISTER_S0);
			break;
		case P_INDIRECT_POST_ADD:
			as_ldr_id_r_post_add (parameter_p->parameter_offset,parameter_p->parameter_data.reg.r,REGISTER_S0);
			break;
		default:
			internal_error_in_function ("as_load_parameter_to_scratch_register");
			return;
	}
}

#ifndef NO_STRD
static struct instruction *as_str_or_strd_id (struct instruction *instruction,struct parameter *d_parameter_p,int s_reg)
{
	struct instruction *next_instruction;
	int offset,a_reg;
	
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
						as_strd_r_r_id (s_reg,next_instruction->instruction_parameters[0].parameter_data.reg.r,offset,a_reg);
						return next_instruction;
					}
				} else if (next_instruction->instruction_parameters[1].parameter_offset==offset-4){
					if (offset-4>=-1020 && offset-4<=1020){
						as_strd_r_r_id (next_instruction->instruction_parameters[0].parameter_data.reg.r,s_reg,offset-4,a_reg);
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

							as_ldr_id_r (next_instruction->instruction_parameters[0].parameter_offset,la_reg,s_reg2);
							as_strd_r_r_id (s_reg,s_reg2,offset,a_reg);
							return next_instruction;
						}
					} else if (next_instruction->instruction_parameters[1].parameter_offset==offset-4){
						if (offset-4>=-1020 && offset-4<=1020){
							int s_reg2;
							
							s_reg2 = s_reg!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

							as_ldr_id_r (next_instruction->instruction_parameters[0].parameter_offset,la_reg,s_reg2);
							as_strd_r_r_id (s_reg2,s_reg,offset-4,a_reg);
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

							as_move_d_r (next_instruction->instruction_parameters[0].parameter_data.l,
										 next_instruction->instruction_parameters[0].parameter_offset,s_reg2);
							as_strd_r_r_id (s_reg,s_reg2,offset,a_reg);
							return next_instruction;
						}
					} else if (next_instruction->instruction_parameters[1].parameter_offset==offset-4){
						if (offset-4>=-1020 && offset-4<=1020){
							int s_reg2;
							
							s_reg2 = s_reg!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

							as_move_d_r (next_instruction->instruction_parameters[0].parameter_data.l,
										 next_instruction->instruction_parameters[0].parameter_offset,s_reg2);
							as_strd_r_r_id (s_reg2,s_reg,offset-4,a_reg);
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
			/* str str,# */
			as_strd_r_r_id_post_add (next_instruction->instruction_parameters[0].parameter_data.reg.r,s_reg,
									 next_instruction->instruction_parameters[1].parameter_offset,a_reg);
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
							as_ldr_id_r (offset1,a_reg,next_instruction->instruction_parameters[1].parameter_data.reg.r);
							as_strd_r_r_id (s_reg,next_next_instruction->instruction_parameters[0].parameter_data.reg.r,offset,a_reg);							
							return next_next_instruction;	
						}
					} else if (offset2==offset-4){
						if (offset-4>=-1020 && offset-4<=1020){
							as_ldr_id_r (offset1,a_reg,next_instruction->instruction_parameters[1].parameter_data.reg.r);
							as_strd_r_r_id (next_next_instruction->instruction_parameters[0].parameter_data.reg.r,s_reg,offset-4,a_reg);
							return next_next_instruction;
						}
					}
				}
			}
		}
	}

	as_str_r_id (s_reg,offset,a_reg);
	return instruction;
}

static struct instruction *as_optimize_str_id_str_scratch_id (struct instruction *instruction,int s_reg,int offset,int a_reg)
{
	if ((offset & 3)==0 && s_reg!=B_STACK_POINTER && instruction->instruction_parameters[1].parameter_data.reg.r==a_reg){
		if (instruction->instruction_parameters[1].parameter_offset==offset+4){
			if (offset>=-1020 && offset<=1020){
				as_strd_r_r_id (s_reg,REGISTER_S0,offset,a_reg);
				return instruction;
			}
		} else if (instruction->instruction_parameters[1].parameter_offset==offset-4){
			if (offset-4>=-1020 && offset-4<=1020){
				as_strd_r_r_id (REGISTER_S0,s_reg,offset-4,a_reg);
				return instruction;
			}
		}
	}

	as_str_r_id (s_reg,offset,a_reg);

	return as_str_or_strd_id (instruction,&instruction->instruction_parameters[1],REGISTER_S0);
}

static void as_str_id_str_id_or_strd_id (int s_reg1,int offset1,int a_reg1,int s_reg2,int offset2,int a_reg2)
{
	if ((offset1 & 3)==0 && a_reg1==a_reg2 && s_reg1!=B_STACK_POINTER && s_reg2!=B_STACK_POINTER){
		if (offset2==offset1+4){
			if (offset1>=-1020 && offset1<=1020){
				as_strd_r_r_id (s_reg1,s_reg2,offset1,a_reg1);
				return;
			}
		} else if (offset2==offset1-4){
			if (offset1-4>=-1020 && offset1-4<=1020){
				as_strd_r_r_id (s_reg2,s_reg1,offset1-4,a_reg1);
				return;
			}
		}
	}

	as_str_r_id (s_reg1,offset1,a_reg1);
	as_str_r_id (s_reg2,offset2,a_reg2);
}
#endif

static void as_ldr_ldr_or_ldrd_id (int offset1,int a_reg1,int d_reg1,int offset2,int a_reg2,int d_reg2)
{
#ifndef NO_LDRD
	if (a_reg1==a_reg2 && d_reg1!=a_reg1 && (offset1 & 3)==0 && d_reg1!=B_STACK_POINTER && d_reg2!=B_STACK_POINTER){
		if (offset2==offset1+4){
			if (offset1>=-1020 && offset1<=1020){
				as_ldrd_id_r_r (offset1,a_reg1,d_reg1,d_reg2);
				return;
			}
		} else if (offset2==offset1-4){
			if (offset2>=-1020 && offset2<=1020){
				as_ldrd_id_r_r (offset2,a_reg1,d_reg2,d_reg1);
				return;
			}
		}
	}
#endif

	as_ldr_id_r (offset1,a_reg1,d_reg1);
	as_ldr_id_r (offset2,a_reg2,d_reg2);
}

static struct instruction *as_push (struct instruction *instruction,int s_reg)
{
	struct instruction *next_instruction;

	next_instruction=instruction->instruction_next;
	if (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
		next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
		next_instruction->instruction_parameters[1].parameter_type==P_PRE_DECREMENT &&
		next_instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER &&
		reg_num (next_instruction->instruction_parameters[0].parameter_data.reg.r) < reg_num (s_reg)
	){
		unsigned short register_list;
		int last_pushed_reg;

		register_list = 1u << (unsigned)reg_num (s_reg);

		do {
			last_pushed_reg = next_instruction->instruction_parameters[0].parameter_data.reg.r;
			register_list |= 1u << (unsigned)reg_num (last_pushed_reg);

			instruction=next_instruction;
			next_instruction=instruction->instruction_next;
		} while (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
				next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
				next_instruction->instruction_parameters[1].parameter_type==P_PRE_DECREMENT &&
				next_instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER &&
				reg_num (next_instruction->instruction_parameters[0].parameter_data.reg.r) < reg_num (last_pushed_reg));

		if ((register_list & ~0x40ff)==0){
			if ((register_list & ~0xff)==0)
				store_w (0xb400 | register_list); /* push */
			else
				store_w (0xb500 | (register_list & 0xff)); /* push */
		} else
			store_lsw (0xe92d0000 | register_list); /* stmdb */

		return instruction;
	}

	as_str_r_id_update (s_reg,-4,B_STACK_POINTER);
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

static struct instruction *as_more_load_indexed (struct instruction *instruction,int reg1,int reg2,int reg3,int offset)
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
				as_ldr_id_r (load_offset1>>2,reg3,d_reg);
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
						as_ldr_id_r (load_offset1>>2,reg3,d_reg);
						if (instruction2->instruction_parameters[1].parameter_type==P_PRE_DECREMENT)
							as_str_r_id_update (d_reg,-4,B_STACK_POINTER);
						else /* P_INDIRECT_WITH_UPDATE */
							as_str_r_id_update (d_reg,store_offset1,store_a_reg1);

						previous_instruction=instruction2;
						instruction=instruction3;
					} else {
						int load_offset2,d_reg2;
						struct instruction *instruction4;

						load_offset2=instruction3->instruction_parameters[0].parameter_offset;
						d_reg2=instruction3->instruction_parameters[1].parameter_data.reg.r;

						if (d_reg2==reg1 || d_reg2==reg2){
							as_ldr_id_r (load_offset1>>2,reg3,d_reg);
							as_str_r_id (d_reg,store_offset1,store_a_reg1);
							as_ldr_id_r (load_offset2>>2,reg3,d_reg2);
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
										if (use_ldrd==1)
											as_ldrd_id_r_r (load_offset1>>2,reg3,d_reg,d_reg2);
										else
											as_ldrd_id_r_r (load_offset2>>2,reg3,d_reg2,d_reg);
									} else {
										as_ldr_id_r (load_offset1>>2,reg3,d_reg);
										as_ldr_id_r (load_offset2>>2,reg3,d_reg2);
									}
									if (use_strd){
										if (use_strd==1)
											as_strd_r_r_id (d_reg,d_reg2,store_offset1,store_a_reg1);
										else
											as_strd_r_r_id (d_reg2,d_reg,store_offset2,store_a_reg1);
									} else {
										as_str_r_id (d_reg,store_offset1,store_a_reg1);
										as_str_r_id (d_reg2,store_offset2,store_a_reg2);
									}
								} else {
									as_ldr_id_r (load_offset1>>2,reg3,d_reg);
									as_str_r_id (d_reg,store_offset1,store_a_reg1);
									as_ldr_id_r (load_offset2>>2,reg3,d_reg2);
									as_str_r_id (d_reg2,store_offset2,store_a_reg2);
								}
							} else {
								as_ldr_id_r (load_offset1>>2,reg3,d_reg);
								as_str_r_id (d_reg,store_offset1,store_a_reg1);
								as_ldr_id_r (load_offset2>>2,reg3,d_reg2);
								as_str_r_id (d_reg2,store_offset2,store_a_reg2);
							}

							previous_instruction=instruction4;
							instruction=previous_instruction->instruction_next;
						} else {
							as_ldr_id_r (load_offset1>>2,reg3,d_reg);
							as_str_r_id (d_reg,store_offset1,store_a_reg1);
							as_ldr_id_r (load_offset2>>2,reg3,d_reg2);

							previous_instruction=instruction3;
							instruction=instruction4;
						}
					}
				} else {
					as_ldr_id_r (load_offset1>>2,reg3,d_reg);
					if (instruction2->instruction_parameters[1].parameter_type==P_INDIRECT)
						as_str_r_id (d_reg,store_offset1,store_a_reg1);
					else if (instruction2->instruction_parameters[1].parameter_type==P_PRE_DECREMENT)
						as_str_r_id_update (d_reg,-4,B_STACK_POINTER);
					else /* P_INDIRECT_WITH_UPDATE */
						as_str_r_id_update (d_reg,store_offset1,store_a_reg1);

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
					if (use_ldrd==1)
						as_ldrd_id_r_r (load_offset1>>2,reg3,d_reg,d_reg2);
					else
						as_ldrd_id_r_r (load_offset2>>2,reg3,d_reg2,d_reg);

					if (d_reg2==reg1 || d_reg2==reg2)
						return instruction2;

					previous_instruction=instruction2;
					instruction=previous_instruction->instruction_next;					
				} else {
					as_ldr_id_r (load_offset1>>2,reg3,d_reg);
			
					previous_instruction=instruction;
					instruction=instruction2;
				}
			} else {
				as_ldr_id_r (load_offset1>>2,reg3,d_reg);
			
				previous_instruction=instruction;
				instruction=previous_instruction->instruction_next;
			}
		} else {
			int d_reg;
			
			d_reg = reg3!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

			as_ldr_id_r (load_offset1>>2,reg3,d_reg);

			switch (instruction->instruction_parameters[1].parameter_type){
				case P_INDIRECT:
					as_str_r_id (d_reg,instruction->instruction_parameters[1].parameter_offset,
									   instruction->instruction_parameters[1].parameter_data.reg.r);
					break;
				case P_PRE_DECREMENT:
					as_str_r_id_update (d_reg,-4,B_STACK_POINTER);
					break;
				case P_INDIRECT_WITH_UPDATE:
					as_str_r_id_update (d_reg,instruction->instruction_parameters[1].parameter_offset,
											  instruction->instruction_parameters[1].parameter_data.reg.r);

					if (instruction->instruction_parameters[1].parameter_data.reg.r==reg1 ||
						instruction->instruction_parameters[1].parameter_data.reg.r==reg2)
						return instruction;
					break;
				default:
					internal_error_in_function ("as_more_load_indexed");
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

				as_mov_r_r (s_reg,d_reg);

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
					as_ldr_id_r (instruction->instruction_parameters[0].parameter_offset>>2,reg3,s_reg);
				
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
				
				as_str_r_id_update (s_reg,-4,B_STACK_POINTER);

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

static struct instruction *as_maybe_more_load_indexed (struct instruction *instruction,int reg1,int reg2,int reg3,int offset)
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
		return as_more_load_indexed (instruction2,reg1,reg2,reg3,offset);
	
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

static struct instruction *as_more_store_indexed (struct instruction *previous_instruction,int reg1,int reg2,int reg3,int index_shift)
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

											as_ldr_ldr_or_ldrd_id (offset,a_reg,d_reg,load_offset2,a_reg2,d_reg2);
											as_strd_r_r_id (d_reg,d_reg2,store_offset>>2,reg3);

											previous_instruction=next_next_next_instruction;
											continue;
										}
									} else if (store_offset2==store_offset-(4<<2)){
										if (((store_offset-(4<<2))>>2)>=-1020 && ((store_offset-(4<<2))>>2)<=1020){
											if (d_reg==d_reg2)
												d_reg = reg3!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

											as_ldr_ldr_or_ldrd_id (offset,a_reg,d_reg,load_offset2,a_reg2,d_reg2);
											as_strd_r_r_id (d_reg2,d_reg,(store_offset-4)>>2,reg3);

											previous_instruction=next_next_next_instruction;
											continue;
										}
									}
								}

								as_ldr_id_r (offset,a_reg,d_reg);
								as_str_r_id (d_reg,store_offset>>2,reg3);

								as_ldr_id_r (load_offset2,a_reg2,d_reg2);
								as_str_r_id (d_reg2,store_offset2>>2,reg3);

								previous_instruction=next_next_next_instruction;
								continue;
							}
						}
					}

					as_ldr_id_r (offset,a_reg,d_reg);

					use_strd = store_index_next_or_previous (next_next_instruction,d_reg,store_offset,reg1,reg2,index_shift);
					if (use_strd){
						int s_reg2;
					
						s_reg2=next_next_instruction->instruction_parameters[0].parameter_data.reg.r;
						if (use_strd==1)
							as_strd_r_r_id (d_reg,s_reg2,store_offset>>2,reg3);
						else
							as_strd_r_r_id (s_reg2,d_reg,(store_offset-(4<<2))>>2,reg3);
						
						previous_instruction=next_next_instruction;
						continue;
					}

					as_str_r_id (d_reg,store_offset>>2,reg3);
					
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
				if (use_strd==1)
					as_strd_r_r_id (s_reg1,s_reg2,offset1>>2,reg3);
				else
					as_strd_r_r_id (s_reg2,s_reg1,(offset1-(4<<2))>>2,reg3);
				
				previous_instruction=next_instruction;
				continue;
			}

			as_str_r_id (s_reg1,offset1>>2,reg3);

			previous_instruction=instruction;
			continue;
		}
		
		break;
	}

	return previous_instruction;
}

static struct instruction *as_move_indexed_load_store_sequence (struct parameter *s_parameter_p,struct instruction *instruction) 
{
	struct instruction *next_instruction,*next_next_instruction;
	int store_address_without_offset_computed;
	int reg1,reg2,offset;

	reg1=s_parameter_p->parameter_data.ir->a_reg.r;
	reg2=s_parameter_p->parameter_data.ir->d_reg.r;
	offset=s_parameter_p->parameter_offset;

	as_add_r_lsl_r_r (reg2,offset & 3,reg1,REGISTER_S0);
	as_ldr_id_r (offset>>2,REGISTER_S0,instruction->instruction_parameters[1].parameter_data.reg.r);

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
										as_str_r_id (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r,
													 s_offset>>2,REGISTER_S1);
									} else {
										as_add_r_lsl_r_r (reg2,offset & 3,reg1,REGISTER_S1);

										store_address_without_offset_computed = 1;

										as_str_r_id (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r,
													 s_offset>>2,REGISTER_S1);
									}
								} else {
									if (store_address_without_offset_computed){
										as_str_r_id (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r,
													 s_offset>>2,REGISTER_S1);

										store_address_without_offset_computed = 0;
									} else {
										int shift;

										shift = immediate_shift (s_offset>>2);
										if (shift>=0)
											as_add_is_r_r (s_offset>>2,shift,reg1,REGISTER_S1);
										else
											internal_error_in_function ("as_move_indexed_load_store_sequence");

										as_str_r_ix (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r,
													 REGISTER_S1,reg2,s_offset & 3);
									}
								}
							} else {
								as_str_r_ix (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r,
											 store_indexed_instruction->instruction_parameters[1].parameter_data.ir->a_reg.r,
											 store_indexed_instruction->instruction_parameters[1].parameter_data.ir->d_reg.r,s_offset & 3);

								store_address_without_offset_computed = 0;
							}
						}
						
						as_ldr_id_r (load_indexed_instruction->instruction_parameters[0].parameter_offset>>2,REGISTER_S0,
									 load_indexed_instruction->instruction_parameters[1].parameter_data.reg.r);
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
						as_str_r_id (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r,
									 s_offset>>2,REGISTER_S1);
					} else {
						as_add_r_lsl_r_r (reg2,offset & 3,reg1,REGISTER_S1);

						store_address_without_offset_computed = 1;

						as_str_r_id (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r,
									 s_offset>>2,REGISTER_S1);																	
					}
				} else {
					if (store_address_without_offset_computed){
						as_str_r_id (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r,
									 s_offset>>2,REGISTER_S1);
						
						store_address_without_offset_computed = 0;
					} else {
						int shift;

						shift = immediate_shift (s_offset>>2);
						if (shift>=0)
							as_add_is_r_r (s_offset>>2,shift,reg1,REGISTER_S1);
						else
							internal_error_in_function ("as_move_indexed_load_store_sequence");

						as_str_r_ix (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r,
									 REGISTER_S1,reg2,s_offset & 3);
					}
				}
			} else {
				as_str_r_ix (store_indexed_instruction->instruction_parameters[0].parameter_data.reg.r,
							 store_indexed_instruction->instruction_parameters[1].parameter_data.ir->a_reg.r,
							 store_indexed_instruction->instruction_parameters[1].parameter_data.ir->d_reg.r,s_offset & 3);

				store_address_without_offset_computed = 0;
			}
		}
		
		as_ldr_id_r (load_indexed_instruction->instruction_parameters[0].parameter_offset>>2,REGISTER_S0,
					 load_indexed_instruction->instruction_parameters[1].parameter_data.reg.r);

		if (store_address_without_offset_computed){
			instruction=instruction->instruction_next;

			as_str_r_id (instruction->instruction_parameters[0].parameter_data.reg.r,
						 instruction->instruction_parameters[1].parameter_offset>>2,REGISTER_S1);
		}

		break;
	}
	
	return instruction;
}								
#endif

static struct instruction *as_move_instruction (struct parameter *s_parameter_p,struct instruction *instruction)
{
	struct parameter *d_parameter_p;
	int s_reg;

	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		int d_reg;
		
		d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

		switch (s_parameter_p->parameter_type){
			case P_REGISTER:
				as_mov_r_r (s_parameter_p->parameter_data.reg.r,d_reg);
				return instruction;
			case P_DESCRIPTOR_NUMBER:
				as_move_d_r (s_parameter_p->parameter_data.l,s_parameter_p->parameter_offset,d_reg);
				return instruction;
			case P_IMMEDIATE:
				as_move_i_r (s_parameter_p->parameter_data.i,d_reg);
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
										as_ldrd_id_r_r (offset,a_reg,d_reg,next_instruction->instruction_parameters[1].parameter_data.reg.r);
										return next_instruction;
									}
								} else if (next_instruction->instruction_parameters[0].parameter_offset==offset-4){
									if (offset-4>=-1020 && offset-4<=1020){
										as_ldrd_id_r_r (offset-4,a_reg,next_instruction->instruction_parameters[1].parameter_data.reg.r,d_reg);
										return next_instruction;
									}
								}
							}
						} else {
							if (next_instruction->instruction_parameters[0].parameter_offset==offset+4){
								if (offset>=-1020 && offset<=1020){
									as_ldrd_id_r_r (offset,a_reg,d_reg,REGISTER_S0);
									
									d_parameter_p=&next_instruction->instruction_parameters[1];
									instruction=next_instruction;
									s_reg = REGISTER_S0;
									break;
								}
							} else if (next_instruction->instruction_parameters[0].parameter_offset==offset-4){
								if (offset-4>=-1020 && offset-4<=1020){
									as_ldrd_id_r_r (offset-4,a_reg,REGISTER_S0,d_reg);
									
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
								as_ldrd_id_r_r_update (offset-4,a_reg,next_instruction->instruction_parameters[1].parameter_data.reg.r,d_reg);
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
												as_ldrd_id_r_r (offset,a_reg,d_reg,d_reg2);

												return as_str_or_strd_id (next_next_instruction,
																		  &next_instruction->instruction_parameters[1],s_reg);
											}
										} else if (offset2==offset-4){
											if (offset-4>=-1020 && offset-4<=1020){
												as_ldrd_id_r_r (offset-4,a_reg,d_reg2,d_reg);

												return as_str_or_strd_id (next_next_instruction,
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
												as_ldrd_id_r_r (offset,a_reg,d_reg,REGISTER_S0);
												
												return as_optimize_str_id_str_scratch_id (next_next_instruction,s_reg,offset1,a_reg);
											}
										} else if (offset2==offset-4){
											if (offset2>=-1020 && offset2<=1020){
												as_ldrd_id_r_r (offset2,a_reg,REGISTER_S0,d_reg);

												return as_optimize_str_id_str_scratch_id (next_next_instruction,s_reg,offset1,a_reg);
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

									as_add_r_lsl_r_r (reg2,store_offset & 3,reg1,reg_s);

									if (a_reg2!=reg1 && (a_reg2==A_STACK_POINTER || a_reg2==B_STACK_POINTER) && (store_offset & 0xc)==0){
										if (store_offset+(4<<2)==store_offset2){
											if ((store_offset>>2)>=-1020 && (store_offset>>2)<=1020){
												if (d_reg==d_reg2)
													d_reg = reg_s!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

												as_ldr_ldr_or_ldrd_id (offset,a_reg,d_reg,load_offset2,a_reg2,d_reg2);
												as_strd_r_r_id (d_reg,d_reg2,store_offset>>2,reg_s);

												return as_more_store_indexed (next_next_next_instruction,reg1,reg2,reg_s,store_offset & 3);
											}
										} else if (store_offset2==store_offset-(4<<2)){
											if (((store_offset-(4<<2))>>2)>=-1020 && ((store_offset-(4<<2))>>2)<=1020){
												if (d_reg==d_reg2)
													d_reg = reg_s!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

												as_ldr_ldr_or_ldrd_id (offset,a_reg,d_reg,load_offset2,a_reg2,d_reg2);
												as_strd_r_r_id (d_reg2,d_reg,(store_offset-4)>>2,reg_s);

												return as_more_store_indexed (next_next_next_instruction,reg1,reg2,reg_s,store_offset & 3);
											}
										}
									}

									as_ldr_id_r (offset,a_reg,d_reg);
									as_str_r_id (d_reg,store_offset>>2,reg_s);

									as_ldr_id_r (load_offset2,a_reg2,d_reg2);
									as_str_r_id (d_reg2,store_offset2>>2,reg_s);

									return as_more_store_indexed (next_next_next_instruction,reg1,reg2,reg_s,store_offset & 3);
								}
							}
						}

						if ((store_offset & -4)!=0){
							int reg_s,shift;

							reg_s = d_reg!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;
							shift = immediate_shift (store_offset>>2);
							if (shift>=0){
								as_ldr_id_r (offset,a_reg,d_reg);
								as_add_is_r_r (store_offset>>2,shift,reg1,reg_s);
								as_str_r_ix (d_reg,reg_s,reg2,store_offset & 3);
								return next_instruction;
							}
						}
					}
# endif
				}
#endif

				as_ldr_id_r (offset,a_reg,d_reg);
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
									as_add_r_lsl_r_r (reg2,offset & 3,reg1,REGISTER_S0);
									
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
												if (use_ldrd==1)
													as_ldrd_id_r_r (offset>>2,REGISTER_S0,d_reg,d_reg2);
												else
													as_ldrd_id_r_r (offset2>>2,REGISTER_S0,d_reg2,d_reg);
												
												if (d_reg2==reg1 || d_reg2==reg2 || d_reg2==REGISTER_S0)
													return instruction2;

												return as_maybe_more_load_indexed (instruction2,reg1,reg2,REGISTER_S0,offset);								
											}
										}
									}

									as_ldr_id_r (offset>>2,REGISTER_S0,d_reg);
									return as_more_load_indexed (instruction2,reg1,reg2,REGISTER_S0,offset);
								} else if (instruction2->instruction_parameters[1].parameter_type==P_INDIRECT ||
										   instruction2->instruction_parameters[1].parameter_type==P_PRE_DECREMENT ||
										   instruction2->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE
								){
									as_add_r_lsl_r_r (reg2,offset & 3,reg1,REGISTER_S0);
									as_ldr_id_r (offset>>2,REGISTER_S0,d_reg);
									return as_more_load_indexed (instruction2,reg1,reg2,REGISTER_S0,offset);
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
									
									as_add_r_lsl_r_r (reg2,offset & 3,reg1,REGISTER_S0);

									if (instruction2->instruction_parameters[1].parameter_type!=P_INDIRECT){
										as_ldr_id_r (offset>>2,REGISTER_S0,d_reg);
										if (instruction2->instruction_parameters[1].parameter_type==P_PRE_DECREMENT)
											as_str_r_id_update (d_reg,-4,B_STACK_POINTER);
										else /* P_INDIRECT_WITH_UPDATE */
											as_str_r_id_update (d_reg,instruction2->instruction_parameters[1].parameter_offset,
															  		  instruction2->instruction_parameters[1].parameter_data.reg.r);

										return as_more_load_indexed (instruction3,reg1,reg2,REGISTER_S0,offset);
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
														if (use_ldrd==1)
															as_ldrd_id_r_r (offset>>2,REGISTER_S0,d_reg,d_reg2);
														else
															as_ldrd_id_r_r (load_offset2>>2,REGISTER_S0,d_reg2,d_reg);
													} else {
														as_ldr_id_r (offset>>2,REGISTER_S0,d_reg);
														as_ldr_id_r (load_offset2>>2,REGISTER_S0,d_reg2);
													}
													if (use_strd){
														if (use_strd==1)
															as_strd_r_r_id (d_reg,d_reg2,store_offset1,store_a_reg1);
														else
															as_strd_r_r_id (d_reg2,d_reg,store_offset2,store_a_reg1);
													} else {
														as_str_r_id (d_reg,store_offset1,store_a_reg1);
														as_str_r_id (d_reg2,store_offset2,store_a_reg2);
													}
												} else {
													as_ldr_id_r (offset>>2,REGISTER_S0,d_reg);
													as_str_r_id (d_reg,store_offset1,store_a_reg1);
													as_ldr_id_r (load_offset2>>2,REGISTER_S0,d_reg2);
													as_str_r_id (d_reg2,store_offset2,store_a_reg2);
												}
											} else {
												as_ldr_id_r (offset>>2,REGISTER_S0,d_reg);
												as_str_r_id (d_reg,store_offset1,store_a_reg1);
												as_ldr_id_r (load_offset2>>2,REGISTER_S0,d_reg2);
												as_str_r_id (d_reg2,store_offset2,store_a_reg2);
											}
											
											return as_maybe_more_load_indexed (instruction4,reg1,reg2,REGISTER_S0,offset);
										}
									}

									as_ldr_id_r (offset>>2,REGISTER_S0,d_reg);
									as_str_r_id (d_reg,instruction2->instruction_parameters[1].parameter_offset,
													   instruction2->instruction_parameters[1].parameter_data.reg.r);

									return as_more_load_indexed (instruction3,reg1,reg2,REGISTER_S0,offset);
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
									return as_move_indexed_load_store_sequence (s_parameter_p,instruction);
							}
						}
					}
				}
#endif
				as_load_indexed_reg (s_parameter_p->parameter_offset,s_parameter_p->parameter_data.ir,d_reg);
				return instruction;
			case P_POST_INCREMENT:
				if (s_parameter_p->parameter_data.reg.r==B_STACK_POINTER){
					struct instruction *next_instruction;

					next_instruction=instruction->instruction_next;
					if (next_instruction!=NULL){
						if (next_instruction->instruction_icode==IMOVE &&
							next_instruction->instruction_parameters[0].parameter_type==P_POST_INCREMENT &&
							next_instruction->instruction_parameters[0].parameter_data.reg.r==B_STACK_POINTER &&
							next_instruction->instruction_parameters[1].parameter_type==P_REGISTER &&
							reg_num (next_instruction->instruction_parameters[1].parameter_data.reg.r) > reg_num (d_reg)
						){
							unsigned short register_list;
							int last_popped_reg;

							register_list = 1u << (unsigned)reg_num (d_reg);

							do {
								last_popped_reg = next_instruction->instruction_parameters[1].parameter_data.reg.r;
								register_list |= 1u << (unsigned)reg_num (last_popped_reg);

								instruction=next_instruction;
								next_instruction=instruction->instruction_next;
							} while (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
									next_instruction->instruction_parameters[0].parameter_type==P_POST_INCREMENT &&
									next_instruction->instruction_parameters[0].parameter_data.reg.r==B_STACK_POINTER &&
									next_instruction->instruction_parameters[1].parameter_type==P_REGISTER &&
									reg_num (next_instruction->instruction_parameters[1].parameter_data.reg.r) > reg_num (last_popped_reg));

							if (next_instruction!=NULL && next_instruction->instruction_icode==IRTS){
								if ((register_list & ~0xff)==0)
									store_w (0xbd00 | register_list); /* pop */
								else
									store_lsw (0xe8bd8000 | register_list); /* ldmia */
								write_literals();
								return next_instruction;
							}

							if ((register_list & ~0x80ff)==0){
								if ((register_list & ~0xff)==0)
									store_w (0xbc00 | register_list); /* pop */
								else
									store_w (0xbd00 | (register_list & 0xff)); /* pop */
							} else
								store_lsw (0xe8bd0000 | register_list); /* ldmia */

							return instruction;
						} else if (next_instruction->instruction_icode==IRTS){
							unsigned short register_list;

							register_list = 1u << (unsigned)reg_num (d_reg);
							if ((register_list & ~0xff)==0)
								store_w (0xbd00 | register_list); /* pop */
							else
								store_lsw (0xe8bd8000 | register_list); /* ldmia */
							write_literals();
							return next_instruction;
						}
					}
				}

				as_ldr_id_r_post_add (4,s_parameter_p->parameter_data.reg.r,d_reg);
				return instruction;
			case P_INDIRECT_WITH_UPDATE:
				as_ldr_id_r_update (s_parameter_p->parameter_offset,s_parameter_p->parameter_data.reg.r,d_reg);
				return instruction;
			case P_INDIRECT_POST_ADD:
				as_ldr_id_r_post_add (s_parameter_p->parameter_offset,s_parameter_p->parameter_data.reg.r,d_reg);
				return instruction;
			case P_LABEL:
				as_move_l_r (s_parameter_p->parameter_data.l,d_reg);
				as_ldr_id_r (0,d_reg,d_reg);
				return instruction;
			case P_INDIRECT_ANY_ADDRESS:
				as_ldr_id_r (s_parameter_p->parameter_offset,s_parameter_p->parameter_data.reg.r,d_reg);
				return instruction;
			default:
				internal_error_in_function ("as_move_instruction");
				return instruction;
		}
	} else if (s_parameter_p->parameter_type==P_REGISTER){
		s_reg = s_parameter_p->parameter_data.reg.r;

		switch (instruction->instruction_parameters[1].parameter_type){
			case P_INDIRECT:
#ifndef NO_STRD
				return as_str_or_strd_id (instruction,&instruction->instruction_parameters[1],s_reg);
#else
				as_str_r_id (s_reg,instruction->instruction_parameters[1].parameter_offset,
								   instruction->instruction_parameters[1].parameter_data.reg.r);
				return instruction;
#endif
			case P_PRE_DECREMENT:
				if (instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER)
					return as_push (instruction,s_reg);

				as_str_r_id_update (s_reg,-4,instruction->instruction_parameters[1].parameter_data.reg.r);
				return instruction;
			case P_INDEXED:
			{
				int reg_0,reg1,reg2,offset;
		
				reg_0 = s_reg;

				offset=instruction->instruction_parameters[1].parameter_offset;
				reg1=instruction->instruction_parameters[1].parameter_data.ir->a_reg.r;
				reg2=instruction->instruction_parameters[1].parameter_data.ir->d_reg.r;

				if ((offset & -4)!=0){
					int reg_s,shift;

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
							int reg3,use_strd;
							
							reg3 = s_reg!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

							as_add_r_lsl_r_r (reg2,offset & 3,reg1,reg3);

							use_strd = index_next_or_previous_aligned (next_instruction,reg_0,offset);
							if (use_strd){
								int s_reg2;
							
								s_reg2=next_instruction->instruction_parameters[0].parameter_data.reg.r;
								if (use_strd==1)
									as_strd_r_r_id (reg_0,s_reg2,offset>>2,reg3);
								else
									as_strd_r_r_id (s_reg2,reg_0,(offset-(4<<2))>>2,reg3);
								
								instruction=next_instruction;
							} else
								as_str_r_id (reg_0,offset>>2,reg3);

							return as_more_store_indexed (instruction,reg1,reg2,reg3,offset & 3);
						}
					}
#endif
					reg_s = reg_0!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;
					shift = immediate_shift (offset>>2);
					if (shift>=0){
						as_add_is_r_r (offset>>2,shift,reg1,reg_s);
						as_str_r_ix (reg_0,reg_s,reg2,offset & 3);
						return instruction;
					}
				} else {
					as_str_r_ix (reg_0,reg1,reg2,offset & 3);
					return instruction;				
				}

				internal_error_in_function ("as_move_instruction");
				return instruction;
			}
			case P_POST_INCREMENT:
				as_str_r_id_post_add (s_reg,4,instruction->instruction_parameters[1].parameter_data.reg.r);
				return instruction;
			case P_INDIRECT_WITH_UPDATE:
				as_str_r_id_update (s_reg,instruction->instruction_parameters[1].parameter_offset,
										  instruction->instruction_parameters[1].parameter_data.reg.r);
				return instruction;
			case P_INDIRECT_POST_ADD:
				as_str_r_id_post_add (s_reg,instruction->instruction_parameters[1].parameter_offset,
											instruction->instruction_parameters[1].parameter_data.reg.r);
				return instruction;
			case P_LABEL:
			{
				int reg_s;

				reg_s = s_reg!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

				as_move_l_r (instruction->instruction_parameters[1].parameter_data.l,reg_s);
				as_str_r_id (s_reg,0,reg_s);
				return instruction;
			}
			case P_INDIRECT_ANY_ADDRESS:
				as_str_r_id (s_reg,instruction->instruction_parameters[1].parameter_offset,
								   instruction->instruction_parameters[1].parameter_data.reg.r);
				return instruction;
		}
		internal_error_in_function ("as_move_instruction");
		return instruction;
	} else {
		d_parameter_p = &instruction->instruction_parameters[1];
		s_reg = REGISTER_S0;
	
		switch (s_parameter_p->parameter_type){
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
							next_instruction->instruction_parameters[1].parameter_data.reg.r==sa_reg
						){
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
											as_ldr_ldr_or_ldrd_id
												(s_parameter_p->parameter_offset,s_parameter_p->parameter_data.reg.r,REGISTER_S0,
												 next_instruction->instruction_parameters[0].parameter_offset,la2_reg,REGISTER_S1);

											as_strd_r_r_id (REGISTER_S0,REGISTER_S1,offset,sa_reg);
											return next_instruction;
										}
									} else if (next_instruction->instruction_parameters[1].parameter_offset==offset-4){
										if (offset-4>=-1020 && offset-4<=1020){
											as_ldr_ldr_or_ldrd_id
												(s_parameter_p->parameter_offset,s_parameter_p->parameter_data.reg.r,REGISTER_S0,
												 next_instruction->instruction_parameters[0].parameter_offset,la2_reg,REGISTER_S1);

											as_strd_r_r_id (REGISTER_S1,REGISTER_S0,offset-4,sa_reg);
											return next_instruction;
										}
									}
								}
							}
						}
# ifndef NO_LDRD
						if (next_instruction->instruction_parameters[0].parameter_data.reg.r==s_parameter_p->parameter_data.reg.r){
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
										if ((s_parameter_p->parameter_offset & 3)==0 &&
											next_instruction->instruction_parameters[1].parameter_data.reg.r!=B_STACK_POINTER
										){
											if (next_instruction->instruction_parameters[0].parameter_offset==s_parameter_p->parameter_offset+4){
												if (s_parameter_p->parameter_offset>=-1020 && s_parameter_p->parameter_offset<=1020){
													as_ldrd_id_r_r (s_parameter_p->parameter_offset,la2_reg,
																	REGISTER_S0,next_instruction->instruction_parameters[1].parameter_data.reg.r);

													/* parameters of instruction not used below */
													instruction=next_instruction;
													break;
												}
											} else if (next_instruction->instruction_parameters[0].parameter_offset==s_parameter_p->parameter_offset-4){
												if (next_instruction->instruction_parameters[0].parameter_offset>=-1020 &&
													next_instruction->instruction_parameters[0].parameter_offset<=1020
												){
													as_ldrd_id_r_r (next_instruction->instruction_parameters[0].parameter_offset,la2_reg,
																	next_instruction->instruction_parameters[1].parameter_data.reg.r,REGISTER_S0);

													/* parameters of instruction not used below */
													instruction=next_instruction;
													break;
												}
											}
										}
									}
								}
							} else {
								/* ldr->str ldr-> */
								if (sa_reg==next_instruction->instruction_parameters[0].parameter_data.reg.r &&
									(next_instruction->instruction_parameters[0].parameter_offset+4<=offset ||
									 next_instruction->instruction_parameters[0].parameter_offset>=offset+4)
								){
									if (sa_reg!=REGISTER_S0){
										int offset1;
										
										offset1=s_parameter_p->parameter_offset;
										if ((offset1 & 3)==0){
											int offset2;
											
											offset2=next_instruction->instruction_parameters[0].parameter_offset;
											if (offset2==offset1+4){
												if (offset1>=-1020 && offset1<=1020){
													as_ldrd_id_r_r (offset1,sa_reg,REGISTER_S0,REGISTER_S1);
													
													as_str_r_id (REGISTER_S0,offset,sa_reg);

													/* parameters of instruction not used below */
													d_parameter_p=&next_instruction->instruction_parameters[1];
													instruction=next_instruction;
													s_reg = REGISTER_S1;
													break;
												}
											} else if (offset2==offset1-4){
												if (offset2>=-1020 && offset2<=1020){
													as_ldrd_id_r_r (offset2,sa_reg,REGISTER_S1,REGISTER_S0);
													
													as_str_r_id (REGISTER_S0,offset,sa_reg);
													
													/* parameters of instruction not used below */
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
						}
# endif
					}
				}
#endif

				as_ldr_id_r (s_parameter_p->parameter_offset,s_parameter_p->parameter_data.reg.r,REGISTER_S0);
				break;
			case P_INDEXED:

#ifndef NO_OPT_INDEXED
				if ((s_parameter_p->parameter_offset & -4)!=0 &&
					(d_parameter_p->parameter_type==P_INDIRECT ||
					 d_parameter_p->parameter_type==P_PRE_DECREMENT ||
					 d_parameter_p->parameter_type==P_INDIRECT_WITH_UPDATE)
				){
					int reg1,reg2;

					reg1=s_parameter_p->parameter_data.ir->a_reg.r;
					reg2=s_parameter_p->parameter_data.ir->d_reg.r;

					if (! (d_parameter_p->parameter_type==P_INDIRECT_WITH_UPDATE &&
						   (d_parameter_p->parameter_data.reg.r==reg1 || d_parameter_p->parameter_data.reg.r==reg2))
					){
						struct instruction *instruction2;
						int offset;

						offset=s_parameter_p->parameter_offset;

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
							as_add_r_lsl_r_r (reg2,offset & 3,reg1,REGISTER_S1);
							as_ldr_id_r (offset>>2,REGISTER_S1,REGISTER_S0);

							if (d_parameter_p->parameter_type==P_INDIRECT)
								as_str_r_id (REGISTER_S0,d_parameter_p->parameter_offset,d_parameter_p->parameter_data.reg.r);
							else if (d_parameter_p->parameter_type==P_PRE_DECREMENT)
								as_str_r_id_update (REGISTER_S0,-4,B_STACK_POINTER);
							else
								as_str_r_id_update (REGISTER_S0,d_parameter_p->parameter_offset,d_parameter_p->parameter_data.reg.r);

							return as_more_load_indexed (instruction2,reg1,reg2,REGISTER_S1,offset);
						}
					}
				}
#endif

				as_load_indexed_reg (s_parameter_p->parameter_offset,s_parameter_p->parameter_data.ir,REGISTER_S0);
				break;
			case P_DESCRIPTOR_NUMBER:
				as_move_d_r (s_parameter_p->parameter_data.l,s_parameter_p->parameter_offset,REGISTER_S0);
				break;
			case P_IMMEDIATE:
				as_move_i_r (s_parameter_p->parameter_data.i,REGISTER_S0);
				break;
			case P_POST_INCREMENT:
				as_ldr_id_r_post_add (4,s_parameter_p->parameter_data.reg.r,REGISTER_S0);
				break;
			case P_INDIRECT_WITH_UPDATE:
				as_ldr_id_r_update (s_parameter_p->parameter_offset,s_parameter_p->parameter_data.reg.r,REGISTER_S0);
				break;
			case P_INDIRECT_POST_ADD:
				as_ldr_id_r_post_add (s_parameter_p->parameter_offset,s_parameter_p->parameter_data.reg.r,REGISTER_S0);
				break;
			default:
				internal_error_in_function ("as_move_instruction");
				return instruction;
		}
	}

	switch (d_parameter_p->parameter_type){
		case P_INDIRECT:
#ifndef NO_STRD
			return as_str_or_strd_id (instruction,d_parameter_p,s_reg);
#else
			as_str_r_id (s_reg,d_parameter_p->parameter_offset,d_parameter_p->parameter_data.reg.r);
			return instruction;
#endif
		case P_PRE_DECREMENT:
			if (d_parameter_p->parameter_data.reg.r==B_STACK_POINTER)
				return as_push (instruction,s_reg);

			as_str_r_id_update (s_reg,-4,d_parameter_p->parameter_data.reg.r);
			return instruction;
		case P_INDEXED:
		{
			int reg1,reg2,offset;
	
			offset=d_parameter_p->parameter_offset;
			reg1=d_parameter_p->parameter_data.ir->a_reg.r;
			reg2=d_parameter_p->parameter_data.ir->d_reg.r;

			if ((offset & -4)!=0){
				int reg_s,shift;

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
						int reg3,use_strd;
						
						reg3 = s_reg!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

						as_add_r_lsl_r_r (reg2,offset & 3,reg1,reg3);

						use_strd = index_next_or_previous_aligned (next_instruction,s_reg,offset);
						if (use_strd){
							int s_reg2;
						
							s_reg2=next_instruction->instruction_parameters[0].parameter_data.reg.r;
							if (use_strd==1)
								as_strd_r_r_id (s_reg,s_reg2,offset>>2,reg3);
							else
								as_strd_r_r_id (s_reg2,s_reg,(offset-(4<<2))>>2,reg3);
							
							instruction=next_instruction;
						} else
							as_str_r_id (s_reg,offset>>2,reg3);

						return as_more_store_indexed (instruction,reg1,reg2,reg3,offset & 3);
					}
				}
#endif

				reg_s = s_reg!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;
				shift = immediate_shift (offset>>2);
				if (shift>=0){
					as_add_is_r_r (offset>>2,shift,reg1,reg_s);
					as_str_r_ix (s_reg,reg_s,reg2,offset & 3);
					return instruction;
				}
			} else {
				as_str_r_ix (s_reg,reg1,reg2,offset & 3);
				return instruction;				
			}

			internal_error_in_function ("as_move_instruction");
			return instruction;
		}
		case P_INDIRECT_WITH_UPDATE:
			as_str_r_id_update (s_reg,d_parameter_p->parameter_offset,d_parameter_p->parameter_data.reg.r);
			return instruction;
		case P_INDIRECT_POST_ADD:
			as_str_r_id_post_add (s_reg,d_parameter_p->parameter_offset,d_parameter_p->parameter_data.reg.r);
			return instruction;
		case P_LABEL:
		{
			int reg_s;

			reg_s = s_reg!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

			as_move_l_r (d_parameter_p->parameter_data.l,reg_s);
			as_str_r_id (s_reg,0,reg_s);
			return instruction;
		}
	}

	internal_error_in_function ("as_move_instruction");
	return instruction;
}

static struct instruction *as_move_instruction_may_modify_condition_flags (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		int i;
				
		i=instruction->instruction_parameters[0].parameter_data.i;
		if (i>=0 && i<256){
			if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
				int d_reg;

				d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

				if (reg_num (d_reg)<8)
					as_moves_i_r (i,d_reg);
				else
					as_move_i_r (i,d_reg);
				return instruction;
			} else {
				struct parameter s_parameter;
				
				as_moves_i_r (i,REGISTER_S0);

				s_parameter.parameter_type=P_REGISTER;
				s_parameter.parameter_data.reg.r=REGISTER_S0;

				return as_move_instruction (&s_parameter,instruction);
			}
		}
	}

	return as_move_instruction (&instruction->instruction_parameters[0],instruction);
}

static void as_moveb_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_REGISTER:
		{
			int reg;
			
			reg=instruction->instruction_parameters[1].parameter_data.reg.r;
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_IMMEDIATE:
					as_move_i_r (instruction->instruction_parameters[0].parameter_data.i,reg);
					return;
				case P_INDIRECT:
					as_ldrb_id_r (instruction->instruction_parameters[0].parameter_offset,
						instruction->instruction_parameters[0].parameter_data.reg.r,reg);
					return;
				case P_INDEXED:
				{
					int offset,reg1,reg2;
						
					reg1=instruction->instruction_parameters[0].parameter_data.ir->a_reg.r;
					reg2=instruction->instruction_parameters[0].parameter_data.ir->d_reg.r;

					offset=instruction->instruction_parameters[0].parameter_offset;
					if ((offset & -4)!=0){
						int shift;
			
						shift = immediate_shift (offset>>2);
						if (shift>=0){
							as_add_is_r_r (offset>>2,shift,reg1,REGISTER_S0);
							as_ldrb_ix_r (REGISTER_S0,reg2,offset & 3,reg);
							return;
						} else {
							shift = immediate_shift (-(offset>>2));
							if (shift>=0){
								as_sub_is_r_r (-(offset>>2),shift,reg1,REGISTER_S0);
								as_ldrb_ix_r (REGISTER_S0,reg2,offset & 3,reg);
								return;
							}
						}
					} else {
						as_ldrb_ix_r (reg1,reg2,offset & 3,reg);
						return;
					}

					internal_error_in_function ("as_moveb_instruction");
					return;
				}
			}

			break;
		}
		case P_INDIRECT:
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_IMMEDIATE:
					as_move_i_r (instruction->instruction_parameters[0].parameter_data.i,REGISTER_S0);
					as_strb_r_id (REGISTER_S0,
						instruction->instruction_parameters[1].parameter_offset,
						instruction->instruction_parameters[1].parameter_data.reg.r);
					return;
				case P_REGISTER:
					as_strb_r_id (instruction->instruction_parameters[0].parameter_data.reg.r,
						instruction->instruction_parameters[1].parameter_offset,
						instruction->instruction_parameters[1].parameter_data.reg.r);
					return;
			}
			break;
		case P_INDEXED:
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_IMMEDIATE:
					as_move_i_r (instruction->instruction_parameters[0].parameter_data.i,REGISTER_S0);
					as_store_b_reg_indexed (REGISTER_S0,
						instruction->instruction_parameters[1].parameter_offset,
						instruction->instruction_parameters[1].parameter_data.ir,REGISTER_S1);
					return;
				case P_REGISTER:
					as_store_b_reg_indexed (instruction->instruction_parameters[0].parameter_data.reg.r,
						instruction->instruction_parameters[1].parameter_offset,
						instruction->instruction_parameters[1].parameter_data.ir,REGISTER_S0);
					return;
			}
			break;
	}
	internal_error_in_function ("as_moveb_instruction");
}

static void as_movew_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_REGISTER:
		{
			int reg;
			
			reg=instruction->instruction_parameters[1].parameter_data.reg.r;
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_INDIRECT:
					as_ldrsh_id_r (instruction->instruction_parameters[0].parameter_offset,
						instruction->instruction_parameters[0].parameter_data.reg.r,reg);
					return;
			}
			break;
		}
	}
	internal_error_in_function ("as_movew_instruction");
}

static void as_lea_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_LABEL:
				as_move_d_r (instruction->instruction_parameters[0].parameter_data.l,
					instruction->instruction_parameters[0].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_INDIRECT:
			{
				int shift,i;
				
				i = instruction->instruction_parameters[0].parameter_offset;

				if (instruction->instruction_parameters[0].parameter_data.reg.r==B_STACK_POINTER &&
					instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER &&
					(i & 3)==0 && i>=-508 && i<=508)
				{
					if (i>0)
						as_add_i_sp (i);
					else if (i<0)
						as_sub_i_sp (-i);
					return;
				}

				shift = immediate_shift (i);
				if (shift>=0){
					as_add_is_r_r (i,shift,
						instruction->instruction_parameters[0].parameter_data.reg.r,
						instruction->instruction_parameters[1].parameter_data.reg.r);
					return;
				} else {
					shift = immediate_shift (-i);
					if (shift>=0){
						as_sub_is_r_r (-i,shift,
							instruction->instruction_parameters[0].parameter_data.reg.r,
							instruction->instruction_parameters[1].parameter_data.reg.r);
						return;
					}
				}
				break;
			}
			case P_INDEXED:
				if (instruction->instruction_parameters[0].parameter_offset==0){
					as_add_r_r_r (instruction->instruction_parameters[0].parameter_data.ir->d_reg.r,
						instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,
						instruction->instruction_parameters[1].parameter_data.reg.r);
					return;
				}
		}
	}
	internal_error_in_function ("as_lea_instruction");
}

static void as_movem_instruction (struct instruction *instruction)
{
	int n_regs;
	unsigned short register_list;
	
	n_regs = instruction->instruction_arity-1;
	register_list = 0u;

	if (instruction->instruction_parameters[0].parameter_type!=P_REGISTER){
		int s_reg,n;

		s_reg = instruction->instruction_parameters[0].parameter_data.reg.r;

		for (n=0; n<n_regs; ++n)
			register_list |= 1u << (unsigned)reg_num(instruction->instruction_parameters[1+n].parameter_data.reg.r);
		
		if (instruction->instruction_parameters[0].parameter_type==P_PRE_DECREMENT){
			store_lsw (0xe9300000 | (reg_num (s_reg)<<16) | register_list); /* ldmdb */
			return;
		} else if (instruction->instruction_parameters[0].parameter_type==P_POST_INCREMENT){
			if (s_reg==B_STACK_POINTER && (register_list & ~0xff)==0)
				store_w (0xbc00 | register_list); /* pop */
			else
				store_lsw (0xe8b00000 | (reg_num (s_reg)<<16) | register_list); /* ldmia */
			return;
		}
	} else {
		int d_reg,n;
		
		d_reg = instruction->instruction_parameters[n_regs].parameter_data.reg.r;

		for (n=0; n<n_regs; ++n)
			register_list |= 1u << (unsigned)reg_num(instruction->instruction_parameters[n].parameter_data.reg.r);

		if (instruction->instruction_parameters[n_regs].parameter_type==P_PRE_DECREMENT){
			if (d_reg==B_STACK_POINTER && (register_list & ~0xff)==0)
				store_w (0xb400 | register_list); /* push */
			else
				store_lsw (0xe9200000 | (reg_num (d_reg)<<16) | register_list); /* stmdb */
			return;
		} else if (instruction->instruction_parameters[n_regs].parameter_type==P_POST_INCREMENT){
			if (reg_num (d_reg)<8 && (register_list & ~0xff)==0)
				store_w (0xc000 | (reg_num (d_reg)<<8) | register_list); /* stm ! */
			else
				store_lsw (0xe8a00000 | (reg_num (d_reg)<<16) | register_list); /* stm ! */
			return;
		}
	}
	internal_error_in_function ("as_movem_instruction");
}

static void as_add_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_add_r_r_r (instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
		{
			int shift,i;
			
			i = instruction->instruction_parameters[0].parameter_data.i;

			if (instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER &&
				(i & 3)==0 && i>=-508 && i<=508)
			{
				if (i>0)
					as_add_i_sp (i);
				else if (i<0)
					as_sub_i_sp (-i);
				return;
			}

			shift = immediate_shift (i);
			if (shift>=0){
				as_add_is_r_r (i,shift,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}
			
			shift = immediate_shift (-i);
			if (shift>=0){
				as_sub_is_r_r (-i,shift,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;			
			}

			if ((i & ~0xfff)==0){
				as_addw_i_r_r (i,instruction->instruction_parameters[1].parameter_data.reg.r,
								 instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}

			if ((-i & ~0xfff)==0){
				as_subw_i_r_r (-i,instruction->instruction_parameters[1].parameter_data.reg.r,
								  instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}

			as_ldr_r_literal (REGISTER_S0);
			as_literal_constant_entry (i,LDR_OFFSET_RELOCATION);
			break;
		}
		default:
			as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
	}

	as_add_r_r_r (REGISTER_S0,instruction->instruction_parameters[1].parameter_data.reg.r,
		instruction->instruction_parameters[1].parameter_data.reg.r);
}

static void as_add_instruction_may_modify_condition_flags (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_add_r_r_r (instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
		{
			int shift,i;
			
			i = instruction->instruction_parameters[0].parameter_data.i;

			if (instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER &&
				(i & 3)==0 && i>=-508 && i<=508)
			{
				if (i>0)
					as_add_i_sp (i);
				else if (i<0)
					as_sub_i_sp (-i);
				return;
			}

			if (reg_num (instruction->instruction_parameters[1].parameter_data.reg.r)<8){
				if (i>=0 && i<=255){
					as_adds_i_r (i,instruction->instruction_parameters[1].parameter_data.reg.r);
					return;
				}
				if (i>=-255 && i<0){
					as_subs_i_r (-i,instruction->instruction_parameters[1].parameter_data.reg.r);
					return;
				}
			}

			shift = immediate_shift (i);
			if (shift>=0){
				as_add_is_r_r (i,shift,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}
			
			shift = immediate_shift (-i);
			if (shift>=0){
				as_sub_is_r_r (-i,shift,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;			
			}

			if ((i & ~0xfff)==0){
				as_addw_i_r_r (i,instruction->instruction_parameters[1].parameter_data.reg.r,
								 instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}

			if ((-i & ~0xfff)==0){
				as_subw_i_r_r (-i,instruction->instruction_parameters[1].parameter_data.reg.r,
								  instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}

			as_ldr_r_literal (REGISTER_S0);
			as_literal_constant_entry (i,LDR_OFFSET_RELOCATION);
			break;
		}
		default:
			as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
	}

	as_add_r_r_r (REGISTER_S0,instruction->instruction_parameters[1].parameter_data.reg.r,
		instruction->instruction_parameters[1].parameter_data.reg.r);
}

static void as_sub_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_sub_r_r_r (instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
		{
			int shift,i;
			
			i = instruction->instruction_parameters[0].parameter_data.i;

			if (instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER &&
				(i & 3)==0 && i>=-508 && i<=508)
			{
				if (i>0)
					as_sub_i_sp (i);
				else if (i<0)
					as_add_i_sp (-i);
				return;
			}

			shift = immediate_shift (i);
			if (shift>=0){
				as_sub_is_r_r (i,shift,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}

			shift = immediate_shift (-i);
			if (shift>=0){
				as_add_is_r_r (-i,shift,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}

			if ((i & ~0xfff)==0){
				as_subw_i_r_r (i,instruction->instruction_parameters[1].parameter_data.reg.r,
								 instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}

			if ((-i & ~0xfff)==0){
				as_addw_i_r_r (-i,instruction->instruction_parameters[1].parameter_data.reg.r,
								  instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}

			as_ldr_r_literal (REGISTER_S0);
			as_literal_constant_entry (i,LDR_OFFSET_RELOCATION);
			break;
		}
		default:
			as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
	}

	as_sub_r_r_r (REGISTER_S0,instruction->instruction_parameters[1].parameter_data.reg.r,
		instruction->instruction_parameters[1].parameter_data.reg.r);
}

static void as_sub_instruction_may_modify_condition_flags (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_sub_r_r_r (instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
		{
			int shift,i;
			
			i = instruction->instruction_parameters[0].parameter_data.i;

			if (instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER &&
				(i & 3)==0 && i>=-508 && i<=508)
			{
				if (i>0)
					as_sub_i_sp (i);
				else if (i<0)
					as_add_i_sp (-i);
				return;
			}

			if (reg_num (instruction->instruction_parameters[1].parameter_data.reg.r)<8){
				if (i>=0 && i<=255){
					as_subs_i_r (i,instruction->instruction_parameters[1].parameter_data.reg.r);
					return;
				}
				if (i>=-255 && i<0){
					as_adds_i_r (-i,instruction->instruction_parameters[1].parameter_data.reg.r);
					return;
				}
			}

			shift = immediate_shift (i);
			if (shift>=0){
				as_sub_is_r_r (i,shift,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}

			shift = immediate_shift (-i);
			if (shift>=0){
				as_add_is_r_r (-i,shift,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}

			if ((i & ~0xfff)==0){
				as_subw_i_r_r (i,instruction->instruction_parameters[1].parameter_data.reg.r,
								 instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}

			if ((-i & ~0xfff)==0){
				as_addw_i_r_r (-i,instruction->instruction_parameters[1].parameter_data.reg.r,
								  instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}

			as_ldr_r_literal (REGISTER_S0);
			as_literal_constant_entry (i,LDR_OFFSET_RELOCATION);
			break;
		}
		default:
			as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
	}

	as_sub_r_r_r (REGISTER_S0,instruction->instruction_parameters[1].parameter_data.reg.r,
		instruction->instruction_parameters[1].parameter_data.reg.r);
}

static void as_addi_instruction (struct instruction *instruction)
{
	int s_reg,d_reg,i,shift;
	
	s_reg = instruction->instruction_parameters[0].parameter_data.reg.r;
	d_reg = instruction->instruction_parameters[1].parameter_data.reg.r;
	i = instruction->instruction_parameters[2].parameter_data.i;

	shift = immediate_shift (i);
	if (shift>=0){
		as_add_is_r_r (i,shift,s_reg,d_reg);
		return;
	}
	
	shift = immediate_shift (-i);
	if (shift>=0){
		as_sub_is_r_r (-i,shift,s_reg,d_reg);
		return;			
	}

	as_ldr_r_literal (REGISTER_S0);
	as_literal_constant_entry (i,LDR_OFFSET_RELOCATION);

	as_add_r_r_r (REGISTER_S0,s_reg,d_reg);
}

static void as_addo_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_op_s_r_r_r (THUMB2_OP_ADD,instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
		{
			int shift,i;
			
			i = instruction->instruction_parameters[0].parameter_data.i;
			shift = immediate_shift (i);
			if (shift>=0){
				if (i==-1){
					as_subs_is_r_r (1,0,
						instruction->instruction_parameters[1].parameter_data.reg.r,
						instruction->instruction_parameters[1].parameter_data.reg.r);
					return;					
				}
				as_adds_is_r_r (i,shift,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}
			
			shift = immediate_shift (-i);
			if (shift>=0){
				as_subs_is_r_r (-i,shift,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;			
			}

			as_ldr_r_literal (REGISTER_S0);
			as_literal_constant_entry (i,LDR_OFFSET_RELOCATION);
			break;
		}
		default:
			as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
	}

	as_op_s_r_r_r (THUMB2_OP_ADD,REGISTER_S0,instruction->instruction_parameters[1].parameter_data.reg.r,
		instruction->instruction_parameters[1].parameter_data.reg.r);
}

static void as_add_or_sub_x_instruction (struct instruction *instruction,int op,int op_r)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_op_s_r_r_r (op,instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
		{
			int shift,i;
			
			i = instruction->instruction_parameters[0].parameter_data.i;
			shift = immediate_shift (i);
			if (shift>=0){
				as_op_s_is_r_r (op,i,shift,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}
			
			shift = immediate_shift (-i);
			if (shift>=0){
				as_op_s_is_r_r (op_r,-i,shift,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;			
			}

			as_ldr_r_literal (REGISTER_S0);
			as_literal_constant_entry (i,LDR_OFFSET_RELOCATION);
			break;
		}
		default:
			as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
	}

	as_op_s_r_r_r (op,REGISTER_S0,instruction->instruction_parameters[1].parameter_data.reg.r,
		instruction->instruction_parameters[1].parameter_data.reg.r);
}

enum { SIZE_LONG, SIZE_WORD, SIZE_BYTE };

static void as_cmp_i_parameter (int i,struct parameter *parameter)
{
	int reg,reg_i,shift;

	switch (parameter->parameter_type){
		case P_REGISTER:
			reg=parameter->parameter_data.reg.r;
			reg_i=REGISTER_S0;
			break;
		default:
			as_load_parameter_to_scratch_register (parameter);
			reg=REGISTER_S0;
			reg_i=REGISTER_S1;
	}

	shift = immediate_shift (i);
	if (shift>=0){
		as_cmp_is_r (i,shift,reg);
		return;
	} else {
		shift = immediate_shift (-i);
		if (shift>=0){
			as_cmn_is_r (-i,shift,reg);
			return;
		}
	}
	
	as_ldr_r_literal (reg_i);
	as_literal_constant_entry (i,reg_num (reg_i)<8 ? LDR_OFFSET_RELOCATION : LONG_LDR_OFFSET_RELOCATION);

	as_cmp_r_r (reg_i,reg);
}

static void as_cmp_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_DESCRIPTOR_NUMBER:
			switch (instruction->instruction_parameters[1].parameter_type){
				case P_REGISTER:
					as_move_d_r (instruction->instruction_parameters[0].parameter_data.l,
								 instruction->instruction_parameters[0].parameter_offset,REGISTER_S0);
					as_cmp_r_r (REGISTER_S0,instruction->instruction_parameters[1].parameter_data.reg.r);
					return;
				default:
					as_load_parameter_to_scratch_register (&instruction->instruction_parameters[1]);
					as_move_d_r (instruction->instruction_parameters[0].parameter_data.l,
								 instruction->instruction_parameters[0].parameter_offset,REGISTER_S1);
					as_cmp_r_r (REGISTER_S1,REGISTER_S0);
					return;
			}
			break;
		case P_IMMEDIATE:
			as_cmp_i_parameter (instruction->instruction_parameters[0].parameter_data.i,
								&instruction->instruction_parameters[1]);
			return;
	}

	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER)
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_REGISTER:
				as_cmp_r_r (instruction->instruction_parameters[0].parameter_data.reg.r,
							instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			default:
				as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
				as_cmp_r_r (REGISTER_S0,instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
		}

	internal_error_in_function ("as_cmp_instruction");
}

void store_label_in_data_section (LABEL *label)
{
	store_label_plus_offset_in_data_section (label,0);
}

void store_descriptor_in_data_section (LABEL *label)
{
	store_label_plus_offset_in_data_section (label,2);
}

static void as_jmp_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_LABEL:
			store_lsw (0xf0009000); /* b */
			as_branch_label (instruction->instruction_parameters[0].parameter_data.l,JUMP_RELOCATION);
			break;
		case P_INDIRECT:
			as_ldr_id_r (instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_PC);
			break;
		case P_REGISTER:
			as_mov_r_r (instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_PC);
			break;
		default:
			internal_error_in_function ("as_jmp_instruction");
	}

	write_literals();
}

static void as_jmpp_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_LABEL:
		{
			int offset;
			
			offset=instruction->instruction_parameters[0].parameter_offset;
			if (offset==0){
				store_lsw (0xf000f800); /* bl */
				as_branch_label (profile_t_label,CALL_RELOCATION);				

				store_lsw (0xf0009000); /* b */
			} else {
				if ((offset & 1) || offset<0 || offset>0x3fe) /* short jump has signed 11 bit offset */
					internal_error_in_function ("as_jmpp_instruction");

				store_lsw (0xf0009000 | ((offset<0)<<26) | ((offset>>1) & 0x7ff)); /* b */
			}
			
			as_branch_label (instruction->instruction_parameters[0].parameter_data.l,JUMP_RELOCATION);
			break;
		}
		case P_INDIRECT:
			store_lsw (0xf000f800); /* bl */
			as_branch_label (profile_t_label,CALL_RELOCATION);

			as_ldr_id_r (instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_PC);
			break;
		case P_REGISTER:
		{
			int reg_0;

			reg_0=instruction->instruction_parameters[0].parameter_data.reg.r;
			if (reg_0!=REGISTER_A3){
				store_lsw (0xf000f800); /* bl */
				as_branch_label (profile_t_label,CALL_RELOCATION);

				as_mov_r_r (instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_PC);
			} else {
				store_lsw (0xf0009000); /* b */
				as_branch_label (profile_ti_label,JUMP_RELOCATION);
			}
			break;
		}
		default:
			internal_error_in_function ("as_jmpp_instruction");
	}

	write_literals();
}

static void as_adr_s0_pc_i (int i)
{
#if 1
	struct relocation *new_relocation;
	
	new_relocation=fast_memory_allocate_type (struct relocation);
	
	*last_code_relocation_l=new_relocation;
	last_code_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;
	
	U3 (new_relocation,
		relocation_offset=CURRENT_CODE_OFFSET,
		relocation_object_label=code_object_label,
		relocation_kind=ADJUST_ADR_RELOCATION);
#else
# ifdef FUNCTION_LEVEL_LINKING
	if (code_object_label!=NULL)
		i += -(CURRENT_CODE_OFFSET-code_object_label->object_label_offset) & 2;
# else
	i += code_buffer_free & 2;
# endif
#endif
	store_lsw (0xf20f0000 | (reg_num (REGISTER_S0)<<8) | i); /* add/adr rd,pc,# */
}

static void as_adr_s1_pc_i (int i)
{
#if 1
	struct relocation *new_relocation;
	
	new_relocation=fast_memory_allocate_type (struct relocation);
	
	*last_code_relocation_l=new_relocation;
	last_code_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;
	
	U3 (new_relocation,
		relocation_offset=CURRENT_CODE_OFFSET,
		relocation_object_label=code_object_label,
		relocation_kind=ADJUST_ADR_RELOCATION);
#else
# ifdef FUNCTION_LEVEL_LINKING
	if (code_object_label!=NULL)
		i += -(CURRENT_CODE_OFFSET-code_object_label->object_label_offset) & 2;
# else
	i += code_buffer_free & 2;
# endif
#endif
	store_lsw (0xf20f0000 | (reg_num (REGISTER_S1)<<8) | i); /* add/adr rd,pc,# */
}

static void as_jsr_instruction (struct instruction *instruction)
{
	if ((unsigned long)(CURRENT_CODE_OFFSET+12) >= literal_table_at_offset)
		write_branch_and_literals(); /* no literal table between adr and bl instructions */

	switch (instruction->instruction_parameters[0].parameter_type){
		case P_LABEL:
			if (instruction->instruction_arity>1)
				switch (instruction->instruction_parameters[1].parameter_type){
					case P_INDIRECT_WITH_UPDATE:
						if (instruction->instruction_parameters[1].parameter_offset==-4){
							as_adr_s1_pc_i (7);
							store_w (0xb500); /* push {lr} */
						} else {
							as_adr_s1_pc_i (9);
							as_str_r_id_update (REGISTER_S1,instruction->instruction_parameters[1].parameter_offset,B_STACK_POINTER);
						}
						break;
					case P_INDIRECT:
					{
						int offset;
						
						offset=instruction->instruction_parameters[1].parameter_offset;
						if (offset>=0 && (offset & ~0x3fc)==0){
							as_adr_s0_pc_i (7);
							as_str_r_id (REGISTER_S0,offset,B_STACK_POINTER);
						} else {
							as_adr_s1_pc_i (9);
							as_str_r_id (REGISTER_S1,offset,B_STACK_POINTER);
						}
					}
				}
			store_lsw (0xf000f800); /* bl */
			as_branch_label (instruction->instruction_parameters[0].parameter_data.l,CALL_RELOCATION);
			break;
		case P_INDIRECT:
			as_ldr_id_r (instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_S0);
			if (instruction->instruction_arity>1)
				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE){
					if (instruction->instruction_parameters[1].parameter_offset==-4){
						as_adr_s1_pc_i (5);
						store_w (0xb500); /* push {lr} */
					} else {
						as_adr_s1_pc_i (7);
						as_str_r_id_update (REGISTER_S1,instruction->instruction_parameters[1].parameter_offset,B_STACK_POINTER);						
					}
				}
			store_w (0x4780 | (reg_num (REGISTER_S0)<<3)); /* blx r12 */
			break;
		case P_REGISTER:
			if (instruction->instruction_arity>1)
				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE){
					if (instruction->instruction_parameters[1].parameter_offset==-4){
						as_adr_s1_pc_i (5);
						store_w (0xb500); /* push {lr} */
					} else {
						as_adr_s1_pc_i (7);
						as_str_r_id_update (REGISTER_S1,instruction->instruction_parameters[1].parameter_offset,B_STACK_POINTER);						
					}
				}
			store_w (0x4780 | (reg_num (instruction->instruction_parameters[0].parameter_data.reg.r)<<3)); /* blx rm */
			break;
		default:
			internal_error_in_function ("as_jsr_instruction");
	}
}

static void as_rts_instruction()
{
	store_w (0xbd00); /* pop {pc} */
	write_literals();
}

static void as_rtsi_instruction (struct instruction *instruction)
{
	int offset;
	
	offset = instruction->instruction_parameters[0].parameter_data.imm;
	
	as_ldr_id_r_post_add (offset,B_STACK_POINTER,REGISTER_PC);
	write_literals();
}

static void as_rtsp_instruction()
{
	store_lsw (0xf0009000); /* b */
	as_branch_label (profile_r_label,LONG_JUMP_RELOCATION);
	write_literals();
}

static void as_branch_instruction (struct instruction *instruction,int condition_code)
{
	LABEL *label;
	
	label=instruction->instruction_parameters[0].parameter_data.l;
	if (label->label_flags & FAR_CONDITIONAL_JUMP_LABEL){
		struct call_and_jump *new_call_and_jump;
		int label_id;

		label_id=next_label_id++;

		new_call_and_jump=allocate_memory_from_heap (sizeof (struct call_and_jump));

		new_call_and_jump->cj_next=NULL;
		new_call_and_jump->cj_call_label=label;
		new_call_and_jump->cj_jump.label_id=-1;

		if (first_call_and_jump!=NULL)
			last_call_and_jump->cj_next=new_call_and_jump;
		else
			first_call_and_jump=new_call_and_jump;
		last_call_and_jump=new_call_and_jump;

		store_lsw ((condition_code<<22) | 0xf0008000); /* b */
		as_branch_label (&new_call_and_jump->cj_label,BRANCH_RELOCATION);
		return;
	}

	store_lsw (0xf0008000 | (condition_code<<22)); /* b */
	as_branch_label (label,BRANCH_RELOCATION);
}

static void as_lsl_instruction (struct instruction *instruction)
{
	int d_reg;
	
	d_reg = instruction->instruction_parameters[1].parameter_data.reg.r;
	
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE)
		as_lsl_i_r_r (instruction->instruction_parameters[0].parameter_data.i & 31,d_reg,d_reg);
	else
		as_lsl_r_r_r (instruction->instruction_parameters[0].parameter_data.reg.r,d_reg,d_reg);
}

static void as_lsl_instruction_may_modify_condition_flags (struct instruction *instruction)
{
	int d_reg;
	
	d_reg = instruction->instruction_parameters[1].parameter_data.reg.r;
	
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		if (reg_num (d_reg)<8)
			as_lsls_i_r_r (instruction->instruction_parameters[0].parameter_data.i & 31,d_reg,d_reg);
		else
			as_lsl_i_r_r (instruction->instruction_parameters[0].parameter_data.i & 31,d_reg,d_reg);
	} else
		as_lsl_r_r_r (instruction->instruction_parameters[0].parameter_data.reg.r,d_reg,d_reg);
}

static void as_lsr_instruction (struct instruction *instruction)
{
	int d_reg;

	d_reg = instruction->instruction_parameters[1].parameter_data.reg.r;
	
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		if ((instruction->instruction_parameters[0].parameter_data.i & 31)!=0)
			as_lsr_i_r_r (instruction->instruction_parameters[0].parameter_data.i & 31,d_reg,d_reg);
	} else {
		int s_reg;

		s_reg = instruction->instruction_parameters[0].parameter_data.reg.r;
		as_lsr_r_r_r (s_reg,d_reg,d_reg);
	}
}

static void as_asr_instruction (struct instruction *instruction)
{
	int d_reg;
	
	d_reg = instruction->instruction_parameters[1].parameter_data.reg.r;
	
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		if ((instruction->instruction_parameters[0].parameter_data.i & 31)!=0)
			as_asr_i_r_r (instruction->instruction_parameters[0].parameter_data.i & 31,d_reg,d_reg);
	} else {
		int s_reg;

		s_reg = instruction->instruction_parameters[0].parameter_data.reg.r;
		as_asr_r_r_r (s_reg,d_reg,d_reg);
	}
}

static void as_rotr_instruction (struct instruction *instruction)
{
	int d_reg;
	
	d_reg = instruction->instruction_parameters[1].parameter_data.reg.r;

	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		if ((instruction->instruction_parameters[0].parameter_data.i & 31)!=0)
			as_ror_i_r_r (instruction->instruction_parameters[0].parameter_data.i & 31,d_reg,d_reg);
	} else {
		int s_reg;

		s_reg = instruction->instruction_parameters[0].parameter_data.reg.r;
		as_ror_r_r_r (s_reg,d_reg,d_reg);
	}
}

static void as_lsli_instruction (struct instruction *instruction)
{
	as_lsl_i_r_r (instruction->instruction_parameters[2].parameter_data.i & 31,
		instruction->instruction_parameters[0].parameter_data.reg.r,
		instruction->instruction_parameters[1].parameter_data.reg.r);
}

static void as_lsli_instruction_may_modify_condition_flags (struct instruction *instruction)
{
	int s_reg,d_reg;
	
	s_reg=instruction->instruction_parameters[0].parameter_data.reg.r;
	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;
	
	if (reg_num (s_reg)<8 && reg_num (d_reg)<8)
		as_lsls_i_r_r (instruction->instruction_parameters[2].parameter_data.i & 31,s_reg,d_reg);
	else
		as_lsl_i_r_r (instruction->instruction_parameters[2].parameter_data.i & 31,s_reg,d_reg);
}

static void as_and_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_and_r_r_r (instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
		{
			int shift,i,d_reg;

			i = instruction->instruction_parameters[0].parameter_data.i;
			d_reg = instruction->instruction_parameters[1].parameter_data.reg.r;
			
			if (i==0xff && reg_num (d_reg)<8){
				as_uxtb_r_r_w (d_reg,d_reg);
				return;
			}

			if (i==0xffff && reg_num (d_reg)<8){
				as_uxth_r_r_w (d_reg,d_reg);
				return;
			}
			
			shift = immediate_shift (i);
			if (shift>=0){
				as_and_is_r_r (i,shift,d_reg,d_reg);
				return;
			}

			shift = immediate_shift (~i);
			if (shift>=0){
				as_bic_is_r_r (~i,shift,d_reg,d_reg);
				return;
			}

			as_ldr_r_literal (REGISTER_S0);
			as_literal_constant_entry (i,LDR_OFFSET_RELOCATION);
			as_and_r_r_r (REGISTER_S0,d_reg,d_reg);
			return;
		}
		default:
			as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
			as_and_r_r_r (REGISTER_S0,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
	}
}

static void as_or_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_orr_r_r_r (instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
		{
			int shift,i;

			i = instruction->instruction_parameters[0].parameter_data.i;
			shift = immediate_shift (i);
			if (shift>=0){
				as_orr_is_r_r (i,shift,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}

			shift = immediate_shift (~i);
			if (shift>=0){
				store_l_is (0xf06f0000 | (reg_num (REGISTER_S0)<<8),~i,shift); /* mvn rd,#i<<s */
				as_orr_r_r_r (REGISTER_S0,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}

			as_ldr_r_literal (REGISTER_S0);
			as_literal_constant_entry (i,LDR_OFFSET_RELOCATION);
			as_orr_r_r_r (REGISTER_S0,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		}
		default:
			as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
			as_orr_r_r_r (REGISTER_S0,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
	}
}

static void as_eor_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_eor_r_r_r (instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
		{
			int shift,i;

			i = instruction->instruction_parameters[0].parameter_data.i;
			shift = immediate_shift (i);
			if (shift>=0){
				as_eor_is_r_r (i,shift,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}

			shift = immediate_shift (~i);
			if (shift>=0){
				store_l_is (0xf06f0000 | (reg_num (REGISTER_S0)<<8),~i,shift); /* mvn rd,#i<<s */
				as_eor_r_r_r (REGISTER_S0,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}

			as_ldr_r_literal (REGISTER_S0);
			as_literal_constant_entry (i,LDR_OFFSET_RELOCATION);
			as_eor_r_r_r (REGISTER_S0,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		}
		default:
			as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
			as_eor_r_r_r (REGISTER_S0,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
	}
}

static void as_and_i_instruction (struct instruction *instruction)
{
	int s_reg,d_reg,i,shift;
	
	s_reg = instruction->instruction_parameters[0].parameter_data.reg.r;
	d_reg = instruction->instruction_parameters[1].parameter_data.reg.r;
	i = instruction->instruction_parameters[2].parameter_data.i;

	if (i==0xff && reg_num (s_reg)<8 && reg_num (d_reg)<8){
		as_uxtb_r_r_w (s_reg,d_reg);
		return;
	}

	if (i==0xffff && reg_num (s_reg)<8 && reg_num (d_reg)<8){
		as_uxth_r_r_w (s_reg,d_reg);
		return;
	}

	shift = immediate_shift (i);
	if (shift>=0){
		as_and_is_r_r (i,shift,s_reg,d_reg);
		return;
	}

	shift = immediate_shift (~i);
	if (shift>=0){
		as_bic_is_r_r (~i,shift,s_reg,d_reg);		
		return;
	}

	as_ldr_r_literal (REGISTER_S0);
	as_literal_constant_entry (i,LDR_OFFSET_RELOCATION);
	as_and_r_r_r (REGISTER_S0,s_reg,d_reg);
	return;
}

static void as_or_i_instruction (struct instruction *instruction)
{
	int s_reg,d_reg,i,shift;
	
	s_reg = instruction->instruction_parameters[0].parameter_data.reg.r;
	d_reg = instruction->instruction_parameters[1].parameter_data.reg.r;
	i = instruction->instruction_parameters[2].parameter_data.i;

	shift = immediate_shift (i);
	if (shift>=0){
		as_orr_is_r_r (i,shift,s_reg,d_reg);
		return;
	}

	shift = immediate_shift (~i);
	if (shift>=0){
		store_l_is (0xf06f0000 | (reg_num (REGISTER_S0)<<8),~i,shift); /* mvn rd,#i<<s */
		as_orr_r_r_r (REGISTER_S0,s_reg,d_reg);
		return;
	}

	as_ldr_r_literal (REGISTER_S0);
	as_literal_constant_entry (i,LDR_OFFSET_RELOCATION);
	as_orr_r_r_r (REGISTER_S0,s_reg,d_reg);
	return;
}

static void as_mul_instruction (struct instruction *instruction)
{
	int s_regn,real_d_regn;

	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			s_regn = instruction->instruction_parameters[0].parameter_data.reg.r;			
			break;
		case P_IMMEDIATE:
			as_move_i_r (instruction->instruction_parameters[0].parameter_data.i,REGISTER_S0);
			s_regn = REGISTER_S0;
			break;
		default:
			as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
			s_regn = REGISTER_S0;
	}

	real_d_regn = reg_num (instruction->instruction_parameters[1].parameter_data.reg.r);
	store_lsw (0xfb00f000 | (reg_num (s_regn)<<16) | (real_d_regn<<8) | real_d_regn); /* mul rd,rn,rm */
}

#define CONDITION_EQ 0
#define CONDITION_NE 1
#define CONDITION_HS 2
#define CONDITION_LO 3
#define CONDITION_MI 4
#define CONDITION_PL 5
#define CONDITION_VS 6
#define CONDITION_VC 7
#define CONDITION_HI 8
#define CONDITION_LS 9
#define CONDITION_GE 10
#define CONDITION_LT 11
#define CONDITION_GT 12
#define CONDITION_LE 13

/*
	From The PowerPC Compiler Writer's Guide,
	Warren, Henry S., Jr., IBM Research Report RC 18601 [1992]. Changing Division by a
	Constant to Multiplication in Two's Complement Arithmetic, (December 21),
	Granlund, Torbjorn and Montgomery, Peter L. [1994]. SIGPLAN Notices, 29 (June), 61.
*/

struct ms magic (int d)
	/* must have 2 <= d <= 231-1 or -231 <= d <= -2 */
{
	int p;
	unsigned int ad, anc, delta, q1, r1, q2, r2, t;
	const unsigned int two31 = 2147483648u;/* 231 */
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

static void as_div_instruction (struct instruction *instruction)
{
	int i,abs_i,d_reg;
	struct ms ms;

	if (instruction->instruction_parameters[0].parameter_type!=P_IMMEDIATE)
		internal_error_in_function ("as_div_instruction");
	
	i=instruction->instruction_parameters[0].parameter_data.i;
	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (i==0){
		internal_error_in_function ("as_div_instruction");
		return;
	}

	abs_i=abs (i);

	if ((abs_i & (abs_i-1))==0){
		int log2i;
		unsigned int i2;

		if (abs_i==1){
			if (i<0)
				as_rsb_is_r_r (0,0,d_reg,d_reg);
			return;
		}

		log2i=0;
		i2=abs_i;
		while (i2>1){
			i2>>=1;
			++log2i;
		}
		
		if (log2i==1)
			as_add_r_lsr_r_r (d_reg,31,d_reg,d_reg);
		else {
			as_cmp_is_r (0,0,d_reg);
			if (log2i<=8){
				store_w (0xbf08 | (CONDITION_LT<<4)); /* it lt */
				if (reg_num (d_reg)<8)
					as_adds_i_r (abs_i-1,d_reg);
				else
					as_add_is_r_r (abs_i-1,0,d_reg,d_reg);
			} else {
				as_add_is_r_r (abs_i,immediate_shift (abs_i),d_reg,REGISTER_S0);
				store_w (0xbf08 | (CONDITION_LT<<4)); /* it lt */
				as_sub_is_r_r (1,0,REGISTER_S0,d_reg);
			}
		}
		
		if (i>0)
			as_asr_i_r_r (log2i,d_reg,d_reg);
		else {
			as_move_i_r (0,REGISTER_S0);
			as_sub_r_asr_r_r (d_reg,log2i,REGISTER_S0,d_reg);		
		}

		return;
	}

	ms=magic (abs_i);

	as_move_i_r (ms.m,REGISTER_S0);
	
	if (ms.s==0){
		if (ms.m>=0){
			as_lsr_i_r_r (31,d_reg,REGISTER_S1);
			as_smmla_r_r_r (d_reg,REGISTER_S0,REGISTER_S1,d_reg);
			if (i<0)
				as_rsb_is_r_r (0,0,d_reg,d_reg);
		} else {
			if (ms.m>=0)
				as_smmul_r_r_r (REGISTER_S0,d_reg,REGISTER_S0);
			else
				as_smmla_r_r_r (REGISTER_S0,d_reg,d_reg,REGISTER_S0);

			if (i>=0)
				as_add_r_lsr_r_r (d_reg,31,REGISTER_S0,d_reg);
			else
				as_sub_r_asr_r_r (d_reg,31,REGISTER_S0,d_reg);
		}
	} else {
		if (ms.m>=0)
			as_smmul_r_r_r (REGISTER_S0,d_reg,REGISTER_S0);
		else
			as_smmla_r_r_r (REGISTER_S0,d_reg,d_reg,REGISTER_S0);

		if (i>=0){
			as_lsr_i_r_r (31,d_reg,d_reg);
			as_add_r_asr_r_r (REGISTER_S0,ms.s,d_reg,d_reg);
		} else {
			as_asr_i_r_r (31,d_reg,d_reg);
			as_sub_r_asr_r_r (REGISTER_S0,ms.s,d_reg,d_reg);
		}
	}	
}

static void as_rem_instruction (struct instruction *instruction)
{
	int i,d_reg;
	struct ms ms;

	if (instruction->instruction_parameters[0].parameter_type!=P_IMMEDIATE)
		internal_error_in_function ("as_rem_instruction");
	
	i=instruction->instruction_parameters[0].parameter_data.i;
	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (i==0){
		internal_error_in_function ("as_rem_instruction");
		return;
	}

	i=abs (i);

	if ((i & (i-1))==0){
		int log2i;
		unsigned int i2;

		if (i==1){
			as_move_i_r (0,d_reg);
			return;
		}

		as_sub_r_lsr_r_r (d_reg,31,d_reg,REGISTER_S0);
		
		log2i=0;
		i2=i;
		while (i2>1){
			i2>>=1;
			++log2i;
		}
		
		if (i<=256){
			if (log2i!=1)
				as_asr_i_r_r (log2i-1,d_reg,d_reg);
			as_and_is_r_r (i-1,0,REGISTER_S0,REGISTER_S0);
		} else {
			as_move_i_r (-1,REGISTER_S1);
			as_asr_i_r_r (log2i-1,d_reg,d_reg);
			as_and_r_lsr_r_r (REGISTER_S1,32-log2i,REGISTER_S0,REGISTER_S0);
		}

		as_sub_r_lsr_r_r (d_reg,32-log2i,REGISTER_S0,d_reg);
		return;
	}

	ms=magic (i);

	as_move_i_r (ms.m,REGISTER_S0);
	
	if (ms.s==0){
		if (ms.m>=0){
			as_lsr_i_r_r (31,d_reg,REGISTER_S1);
			as_smmla_r_r_r (d_reg,REGISTER_S0,REGISTER_S1,REGISTER_S0);
		} else {
			if (ms.m>=0)
				as_smmul_r_r_r (REGISTER_S0,d_reg,REGISTER_S0);
			else
				as_smmla_r_r_r (REGISTER_S0,d_reg,d_reg,REGISTER_S0);

			as_add_r_lsr_r_r (d_reg,31,REGISTER_S0,REGISTER_S0);
		}
	} else {
		if (ms.m>=0)
			as_smmul_r_r_r (REGISTER_S0,d_reg,REGISTER_S0);
		else
			as_smmla_r_r_r (REGISTER_S0,d_reg,d_reg,REGISTER_S0);

		as_lsr_i_r_r (31,d_reg,REGISTER_S1);
		as_add_r_asr_r_r (REGISTER_S0,ms.s,REGISTER_S1,REGISTER_S0);
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
				
				if (n_shifts>0)
					as_sub_r_lsl_r_r (REGISTER_S0,n_shifts,d_reg,d_reg);
				else
					as_sub_r_r_r (REGISTER_S0,d_reg,d_reg);
				
				n>>=1;
				n_shifts+=1;
			}
		} else {
#if 1
			as_move_i_r (-i,REGISTER_S1);
			as_mla_r_r_r_r (REGISTER_S0,REGISTER_S1,d_reg,d_reg);
#else
			/* mls is an illegal instruction on the raspberry pi b+ */
			as_move_i_r (i,REGISTER_S1);
			as_mls_r_r_r_r (REGISTER_S0,REGISTER_S1,d_reg,d_reg);
#endif
		}
	}
}

static void as_set_condition_instruction (struct instruction *instruction,int condition_code_true)
{
	unsigned int rn;
	
	rn = reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);

	store_w (0xbf04 | (condition_code_true<<4) | (((~condition_code_true) & 1)<<3)); /* ite */
	if (rn<8){
		store_w (0x2001 | (rn<<8)); /* mov rd,#1 inside IT block */
		store_w (0x2000 | (rn<<8)); /* mov rd,#0 inside IT block */
	} else {
		store_lsw (0xf04f0001 | (rn<<8)); /* mov rd,#1 */
		store_lsw (0xf04f0000 | (rn<<8)); /* mov rd,#0 */
	}
}

static void as_mulud_instruction (struct instruction *instruction)
{
	int rn_1,rn_2;

	rn_1=reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);
	rn_2=reg_num (instruction->instruction_parameters[1].parameter_data.reg.r);

	store_lsw (0xfba00000 | (rn_2<<16) | (rn_2<<12) | (rn_1<<8) | rn_1); /* umull */
}

static void as_tst_instruction (struct instruction *instruction)
{
	as_cmp_i_parameter (0,&instruction->instruction_parameters[0]);
}

static void as_btst_instruction (struct instruction *instruction)
{
	int reg1,shift;
	
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER)
		reg1=instruction->instruction_parameters[1].parameter_data.reg.r;
	else {
		reg1=instruction->instruction_parameters[1].parameter_data.reg.r;

		as_ldr_id_r (instruction->instruction_parameters[1].parameter_offset,reg1,REGISTER_S0);
		reg1 = REGISTER_S0;
	}

	shift = immediate_shift (instruction->instruction_parameters[0].parameter_data.i);
	if (shift>=0){
		as_tst_ir_r (instruction->instruction_parameters[0].parameter_data.i,shift,reg1);
		return;
	}

	internal_error_in_function ("as_btst_instruction");
}

static void as_neg_instruction (struct instruction *instruction)
{
	int reg;
	
	reg = instruction->instruction_parameters[0].parameter_data.reg.r;
	as_rsb_is_r_r (0,0,reg,reg);
}

static void as_not_instruction (struct instruction *instruction)
{	
	unsigned int regn;
	
	regn = reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);
	store_lsw (0xea6f0000 | (regn<<8) | regn); /* mvn rd,rm */
}

static void as_clzb_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		int d_reg,s_reg;

		d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

		if (instruction->instruction_parameters[0].parameter_type==P_REGISTER)
			s_reg=instruction->instruction_parameters[0].parameter_data.reg.r;
		else {
			as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
			s_reg=REGISTER_S0;
		}

		store_lsw (0xfab0f080 | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<8) | reg_num (s_reg));	/* clz */

		return;
	}

	internal_error_in_function ("as_clzb_instruction");
}

static void as_vldr_r_literal (int dreg)
{
	as_vldr_r_id (dreg,0,REGISTER_PC);
}

static void as_fmove_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_F_REGISTER:
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_F_REGISTER:
				{
					int reg0,reg1;

					reg0=instruction->instruction_parameters[0].parameter_data.reg.r;
					reg1=instruction->instruction_parameters[1].parameter_data.reg.r;
					
					store_lsw (0xeeb00b40 | (reg1<<12) | reg0); /* vmov dd,dm */
					return;
				}
				case P_INDIRECT:
					as_vldr_r_id (instruction->instruction_parameters[1].parameter_data.reg.r,
						instruction->instruction_parameters[0].parameter_offset,
						instruction->instruction_parameters[0].parameter_data.reg.r);
					return;
				case P_INDEXED:
					as_add_r_lsl_r_r (instruction->instruction_parameters[0].parameter_data.ir->d_reg.r,
						instruction->instruction_parameters[0].parameter_offset & 3,
						instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,REGISTER_S0);
					as_vldr_r_id (instruction->instruction_parameters[1].parameter_data.reg.r,
						instruction->instruction_parameters[0].parameter_offset>>2,REGISTER_S0);
					return;
				case P_F_IMMEDIATE:
					as_vldr_r_literal (instruction->instruction_parameters[1].parameter_data.reg.r);
					as_float_literal_entry (instruction->instruction_parameters[0].parameter_data.r);
					return;
				default:
					internal_error_in_function ("as_fmove_instruction");
					return;
			}
		case P_INDIRECT:
			if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
				as_vstr_r_id (instruction->instruction_parameters[0].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}
			break;
		case P_INDEXED:
			if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
				as_add_r_lsl_r_r (instruction->instruction_parameters[1].parameter_data.ir->d_reg.r,
					instruction->instruction_parameters[1].parameter_offset & 3,
					instruction->instruction_parameters[1].parameter_data.ir->a_reg.r,REGISTER_S0);
				as_vstr_r_id (instruction->instruction_parameters[0].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_offset>>2,REGISTER_S0);
				return;
			}
	}
	internal_error_in_function ("as_fmove_instruction");
	return;
}

static void as_floads_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[1].parameter_type==P_F_REGISTER){
		int freg;
				
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_INDIRECT:
				freg=instruction->instruction_parameters[1].parameter_data.reg.r;
				as_vldr_s_id (freg,instruction->instruction_parameters[0].parameter_offset,
							  instruction->instruction_parameters[0].parameter_data.reg.r);
				break;
			case P_INDEXED:
				freg=instruction->instruction_parameters[1].parameter_data.reg.r;
				as_add_r_lsl_r_r (instruction->instruction_parameters[0].parameter_data.ir->d_reg.r,
					instruction->instruction_parameters[0].parameter_offset & 3,
					instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,REGISTER_S0);
				as_vldr_s_id (freg,instruction->instruction_parameters[0].parameter_offset>>2,REGISTER_S0);
				break;
			default:
				internal_error_in_function ("as_floads_instruction");
				return;
		}

		store_lsw (0xeeb70ac0 | (freg<<12) | freg); /* vcvtr.f64.f32 dd,sm */
		return;
	}

	internal_error_in_function ("as_floads_instruction");
}

static void as_fmoves_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
		int s_freg;
				
		s_freg=instruction->instruction_parameters[0].parameter_data.reg.r;

		store_lsw (0xeeb70bc0 | (15<<12) | s_freg); /* vcvtr.f32.f64 sd,dm */

		switch (instruction->instruction_parameters[1].parameter_type){
			case P_INDIRECT:
				as_vstr_s_id (15,instruction->instruction_parameters[1].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_INDEXED:
				as_add_r_lsl_r_r (instruction->instruction_parameters[1].parameter_data.ir->d_reg.r,
					instruction->instruction_parameters[1].parameter_offset & 3,
					instruction->instruction_parameters[1].parameter_data.ir->a_reg.r,REGISTER_S0);
				as_vstr_r_id (15,instruction->instruction_parameters[1].parameter_offset>>2,REGISTER_S0);
				return;
			}
	}
	internal_error_in_function ("as_fmoves_instruction");
	return;
}

static void as_dyadic_float_instruction (struct instruction *instruction,int code)
{
	int d_freg,s_freg;
	
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_F_IMMEDIATE:
			as_vldr_r_literal (15);
			as_float_literal_entry (instruction->instruction_parameters[0].parameter_data.r);
			s_freg=15;
			break;
		case P_INDIRECT:
			as_vldr_r_id (15,instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r);
			s_freg=15;
			break;
		case P_INDEXED:
			as_add_r_lsl_r_r (instruction->instruction_parameters[0].parameter_data.ir->d_reg.r,
				instruction->instruction_parameters[0].parameter_offset & 3,
				instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,REGISTER_S0);
			as_vldr_r_id (15,instruction->instruction_parameters[0].parameter_offset>>2,REGISTER_S0);
			s_freg=15;
			break;
		case P_F_REGISTER:
			s_freg = instruction->instruction_parameters[0].parameter_data.reg.r;
			break;
		default:
			internal_error_in_function ("as_dyadic_float_instruction");
			return;
	}

	d_freg=instruction->instruction_parameters[1].parameter_data.reg.r;
	store_lsw (0xee000b00 | code | (d_freg<<16) | (d_freg<<12) | s_freg);
}

static void as_float_sub_or_div_instruction (struct instruction *instruction,int code)
{
	int d_freg,s_freg;
	
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_F_IMMEDIATE:
			as_vldr_r_literal (15);
			as_float_literal_entry (instruction->instruction_parameters[0].parameter_data.r);
			s_freg=15;
			break;
		case P_INDIRECT:
			as_vldr_r_id (15,instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r);
			s_freg=15;
			break;
		case P_INDEXED:
			as_add_r_lsl_r_r (instruction->instruction_parameters[0].parameter_data.ir->d_reg.r,
				instruction->instruction_parameters[0].parameter_offset & 3,
				instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,REGISTER_S0);
			as_vldr_r_id (15,instruction->instruction_parameters[0].parameter_offset>>2,REGISTER_S0);
			s_freg=15;
			break;
		case P_F_REGISTER:
			s_freg = instruction->instruction_parameters[0].parameter_data.reg.r;
			break;
		default:
			internal_error_in_function ("as_float_sub_or_div_instruction");
			return;
	}

	d_freg=instruction->instruction_parameters[1].parameter_data.reg.r;
	if (instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
		store_lsw (0xee000b00 | code | (s_freg<<16) | (d_freg<<12) | d_freg);
	else
		store_lsw (0xee000b00 | code | (d_freg<<16) | (d_freg<<12) | s_freg);
}

static void as_vcmp_f64_r_r (int freg_1,int freg_2)
{
	store_lsw (0xeeb40b40 | (freg_2<<12) | freg_1); /* vcmp.f64 dd,dm */
}

static void as_compare_float_instruction (struct instruction *instruction)
{
	int d_freg;
	int code1,code2;
	
	d_freg=instruction->instruction_parameters[1].parameter_data.reg.r;
		
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_F_IMMEDIATE:
		{
			DOUBLE *r_p;
			
			r_p=instruction->instruction_parameters[0].parameter_data.r;
			if ((((LONG*)r_p)[0] | ((LONG*)r_p)[1])==0){
				store_lsw (0xeeb50b40 | (d_freg<<12)); /* vcmp.f64 dd,#0.0 */
			} else {
				as_vldr_r_literal (15);
				as_float_literal_entry (instruction->instruction_parameters[0].parameter_data.r);
				as_vcmp_f64_r_r (15,d_freg);
			}
			return;
		}
		case P_INDIRECT:
			as_vldr_r_id (15,instruction->instruction_parameters[0].parameter_offset,
				 			 instruction->instruction_parameters[0].parameter_data.reg.r);
			as_vcmp_f64_r_r (15,d_freg);
			return;
		case P_INDEXED:
			as_add_r_lsl_r_r (instruction->instruction_parameters[0].parameter_data.ir->d_reg.r,
				instruction->instruction_parameters[0].parameter_offset & 3,
				instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,REGISTER_S0);
			as_vldr_r_id (15,instruction->instruction_parameters[0].parameter_offset>>2,REGISTER_S0);
			as_vcmp_f64_r_r (15,d_freg);
			return;
		case P_F_REGISTER:
			as_vcmp_f64_r_r (instruction->instruction_parameters[0].parameter_data.reg.r,d_freg);
			return;
		default:
			internal_error_in_function ("as_compare_float_instruction");
			return;
	}
}

static void as_monadic_float_instruction (struct instruction *instruction,int code)
{
	int s_freg,d_freg;
		
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_F_IMMEDIATE:
			as_vldr_r_literal (15);
			as_float_literal_entry (instruction->instruction_parameters[0].parameter_data.r);
			s_freg=15;
			break;
		case P_INDIRECT:
			as_vldr_r_id (15,instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r);
			s_freg=15;
			break;
		case P_INDEXED:
			as_add_r_lsl_r_r (instruction->instruction_parameters[0].parameter_data.ir->d_reg.r,
				instruction->instruction_parameters[0].parameter_offset & 3,
				instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,REGISTER_S0);
			as_vldr_r_id (15,instruction->instruction_parameters[0].parameter_offset>>2,REGISTER_S0);
			s_freg=15;
			break;
		case P_F_REGISTER:
			s_freg = instruction->instruction_parameters[0].parameter_data.reg.r;
			break;
		default:
			internal_error_in_function ("as_dyadic_float_instruction");
			return;
	}

	d_freg=instruction->instruction_parameters[1].parameter_data.reg.r;
	store_lsw (0xeeb00b40 | code | (d_freg<<12) | s_freg);
}

static void as_test_floating_point_condition_code (void)
{
	store_lsw (0xeef1fa10); /* vmrs APSR_nzcv,fpscr */
	/* APSR_nzcv is encoded as register 15, fpscr as register 1 */
}

static void as_float_branch_instruction (struct instruction *instruction,int condition_code)
{
	as_test_floating_point_condition_code();
	/*            Z N C V
	equal         1 0 1 0
	less than     0 1 0 0
	greater than  0 0 1 0
	unordered     0 0 1 1

	bgt           Z==0 && N==V 
	ble           Z==1 || N!=V
	*/
	
	store_lsw ((condition_code<<22) | 0xf0008000); /* b */
	as_branch_label (instruction->instruction_parameters[0].parameter_data.l,BRANCH_RELOCATION);
}

static void as_float_branch_vc_and_instruction (struct instruction *instruction,int condition_code)
{
	as_test_floating_point_condition_code();
	
	if (code_buffer_p+4>=literal_table_at_buffer_p)
		write_branch_and_literals();

	store_2c (0xd0 | (CONDITION_VS<<8) | ((6-4)>>1)); /* bvs pc+6 */

	{
		struct relocation *new_relocation;
		
		new_relocation=fast_memory_allocate_type (struct relocation);
		
		*last_code_relocation_l=new_relocation;
		last_code_relocation_l=&new_relocation->next;
		new_relocation->next=NULL;

		new_relocation->relocation_label=NULL;
		new_relocation->relocation_offset=CURRENT_CODE_OFFSET-2;
#ifdef FUNCTION_LEVEL_LINKING
		new_relocation->relocation_object_label=code_object_label;
#endif
		new_relocation->relocation_kind=BRANCH_SKIP_BRANCH_RELOCATION;
	}

	store_lsw_no_literal_table ((condition_code<<22) | 0xf0008000); /* b */
	as_branch_label (instruction->instruction_parameters[0].parameter_data.l,BRANCH_RELOCATION);
}

static void as_float_branch_vs_or_instruction (struct instruction *instruction,int condition_code)
{
	as_test_floating_point_condition_code();
	
	store_lsw ((CONDITION_VS<<22) | 0xf0008000); /* b */
	as_branch_label (instruction->instruction_parameters[0].parameter_data.l,BRANCH_RELOCATION);

	store_lsw ((condition_code<<22) | 0xf0008000); /* b */
	as_branch_label (instruction->instruction_parameters[0].parameter_data.l,BRANCH_RELOCATION);
}

static void as_set_float_condition_instruction (struct instruction *instruction,int condition_code_true)
{
	as_test_floating_point_condition_code();

	as_set_condition_instruction (instruction,condition_code_true);
}

static void as_set_float_vc_and_condition_instruction (struct instruction *instruction,int condition_code_true)
{
	unsigned int rn;

	as_test_floating_point_condition_code();

	as_set_condition_instruction (instruction,condition_code_true);
		
	rn = reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);

	store_w (0xbf08 | (CONDITION_VS<<4)); /* it vs */
	if (rn<8)
		store_w (0x2000 | (rn<<8)); /* mov rd,#0 inside IT block */
	else
		store_lsw (0xf04f0000 | (rn<<8)); /* mov rd,#0 */
}

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
#ifndef ELF
		if (string_length<8)
			new_object_label->object_label_string_offset=0;
		else
#endif
		{
			new_object_label->object_label_string_offset=string_table_offset;
			string_table_offset+=string_length+1;
		}

#if defined (RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL) && defined (FUNCTION_LEVEL_LINKING)
		label->label_object_label=new_object_label;	
		new_object_label->object_label_section_n = data_object_label->object_label_section_n;
#endif

		new_object_label->object_label_kind=EXPORTED_DATA_LABEL;
	}
}

void store_descriptor_string_in_data_section (char *string,int length,LABEL *string_label)
{
	define_data_label (string_label);
	store_abc_string_in_data_section (string,length);
}

static void as_fmovel_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
		if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
			int s_freg;

			s_freg=instruction->instruction_parameters[0].parameter_data.reg.r;

			/* s30 */
			store_lsw (0xeebd0b40 | (15<<12) | s_freg); /* vcvtr.s32.f64 sd,dm */
			store_lsw (0xee100a10 | (15<<16) | (reg_num (instruction->instruction_parameters[1].parameter_data.reg.r)<<12)); /* vmov rt,sn */
			return;
		} else
			internal_error_in_function ("as_fmovel_instruction");
	} else {
		int freg;

		switch (instruction->instruction_parameters[0].parameter_type){
			case P_REGISTER:
				freg=instruction->instruction_parameters[1].parameter_data.reg.r;				
				store_lsw (0xee000a10 | (freg<<16) | (reg_num (instruction->instruction_parameters[0].parameter_data.reg.r)<<12)); /* vmov sn,rt */
				break;
			case P_INDIRECT:
				as_ldr_id_r (instruction->instruction_parameters[0].parameter_offset,
					instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_S0);
				freg=instruction->instruction_parameters[1].parameter_data.reg.r;
				store_lsw (0xee000a10 | (freg<<16) | (reg_num (REGISTER_S0)<<12)); /* vmov sn,rt */
				break;
			case P_INDEXED:
				as_load_indexed_reg (instruction->instruction_parameters[0].parameter_offset,
					instruction->instruction_parameters[0].parameter_data.ir,REGISTER_S0);
				freg=instruction->instruction_parameters[1].parameter_data.reg.r;
				store_lsw (0xee000a10 | (freg<<16) | (reg_num (REGISTER_S0)<<12)); /* vmov sn,rt */
				break;
			case P_IMMEDIATE:
				freg=instruction->instruction_parameters[1].parameter_data.reg.r;

				as_vldr_s_id (freg,0,REGISTER_PC);
				as_float_load_int_literal_entry (instruction->instruction_parameters[0].parameter_data.i);
				break;
			default:
				internal_error_in_function ("as_fmovel_instruction");
				return;
		}
		store_lsw (0xeeb80bc0 | (freg<<12) | freg); /* vcvt.f64.s32 dd,sm */
		return;
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

				++n_object_labels;

				string_length=strlen (label->label_name);
#ifndef ELF
				if (string_length<8)
					new_object_label->object_label_string_offset=0;
				else
#endif
				{
					new_object_label->object_label_string_offset=string_table_offset;
					string_table_offset+=string_length+1;
				}
		
				new_object_label->object_label_kind=EXPORTED_CODE_LABEL;
			}
		}	
}

static struct instruction *as_instructions_using_condition_flags (struct instruction *instruction)
{
	while (instruction!=NULL){
		switch (instruction->instruction_icode){
			case IMOVE:
				instruction=as_move_instruction (&instruction->instruction_parameters[0],instruction);
				break;
			case ILEA:
				as_lea_instruction (instruction);
				break;
			case IADD:
				as_add_instruction (instruction);
				break;
			case ISUB:
				as_sub_instruction (instruction);
				break;
			case IFMOVE:
				as_fmove_instruction (instruction);
				break;
			case IBEQ:
				as_branch_instruction (instruction,CONDITION_EQ);
				return instruction->instruction_next;
			case IBGE:
				as_branch_instruction (instruction,CONDITION_GE);
				return instruction->instruction_next;
			case IBGEU:
				as_branch_instruction (instruction,CONDITION_HS);
				return instruction->instruction_next;
			case IBGT:
				as_branch_instruction (instruction,CONDITION_GT);
				return instruction->instruction_next;
			case IBGTU:
				as_branch_instruction (instruction,CONDITION_HI);
				return instruction->instruction_next;
			case IBLE:
				as_branch_instruction (instruction,CONDITION_LE);
				return instruction->instruction_next;
			case IBLEU:
				as_branch_instruction (instruction,CONDITION_LS);
				return instruction->instruction_next;
			case IBLT:
				as_branch_instruction (instruction,CONDITION_LT);
				return instruction->instruction_next;
			case IBLTU:
				as_branch_instruction (instruction,CONDITION_LO);
				return instruction->instruction_next;
			case IBNE:
				as_branch_instruction (instruction,CONDITION_NE);
				return instruction->instruction_next;
			case IBO:
				as_branch_instruction (instruction,CONDITION_VS);
				return instruction->instruction_next;
			case IBNO:
				as_branch_instruction (instruction,CONDITION_VC);
				return instruction->instruction_next;
			case IFBEQ:
				as_float_branch_instruction (instruction,CONDITION_EQ);
				return instruction->instruction_next;
			case IFBGE:
				as_float_branch_instruction (instruction,CONDITION_GE);
				return instruction->instruction_next;
			case IFBGT:
				as_float_branch_instruction (instruction,CONDITION_GT);
				return instruction->instruction_next;
			case IFBLE:
				as_float_branch_instruction (instruction,CONDITION_LS);
				return instruction->instruction_next;
			case IFBLT:
				as_float_branch_instruction (instruction,CONDITION_MI);
				return instruction->instruction_next;
			case IFBNE:
				as_float_branch_vc_and_instruction (instruction,CONDITION_NE);
				return instruction->instruction_next;
			case IFBNEQ:
				as_float_branch_instruction (instruction,CONDITION_NE);
				return instruction->instruction_next;
			case IFBNGE:
				as_float_branch_instruction (instruction,CONDITION_LT);
				return instruction->instruction_next;
			case IFBNGT:
				as_float_branch_instruction (instruction,CONDITION_LE);
				return instruction->instruction_next;
			case IFBNLE:
				as_float_branch_instruction (instruction,CONDITION_HI);
				return instruction->instruction_next;
			case IFBNLT:
				as_float_branch_instruction (instruction,CONDITION_PL);
				return instruction->instruction_next;
			case IFBNNE:
				as_float_branch_vs_or_instruction (instruction,CONDITION_EQ);
				return instruction->instruction_next;
			case IFSEQ:
				as_set_float_condition_instruction (instruction,CONDITION_EQ);
				return instruction->instruction_next;
			case IFSGE:
				as_set_float_condition_instruction (instruction,CONDITION_PL);
				return instruction->instruction_next;
			case IFSGT:
				as_set_float_condition_instruction (instruction,CONDITION_GT);
				return instruction->instruction_next;
			case IFSLE:
				as_set_float_condition_instruction (instruction,CONDITION_LE);
				return instruction->instruction_next;
			case IFSLT:
				as_set_float_condition_instruction (instruction,CONDITION_MI);
				return instruction->instruction_next;
			case IFSNE:
				as_set_float_condition_instruction (instruction,CONDITION_NE);
				return instruction->instruction_next;
			case ISEQ:
				as_set_condition_instruction (instruction,CONDITION_EQ);
				return instruction->instruction_next;
			case ISGE:
				as_set_condition_instruction (instruction,CONDITION_GE);
				return instruction->instruction_next;
			case ISGEU:
				as_set_condition_instruction (instruction,CONDITION_HS);
				return instruction->instruction_next;
			case ISGT:
				as_set_condition_instruction (instruction,CONDITION_GT);
				return instruction->instruction_next;
			case ISGTU:
				as_set_condition_instruction (instruction,CONDITION_HI);
				return instruction->instruction_next;
			case ISLE:
				as_set_condition_instruction (instruction,CONDITION_LE);
				return instruction->instruction_next;
			case ISLEU:
				as_set_condition_instruction (instruction,CONDITION_LS);
				return instruction->instruction_next;
			case ISLT:
				as_set_condition_instruction (instruction,CONDITION_LT);
				return instruction->instruction_next;
			case ISLTU:
				as_set_condition_instruction (instruction,CONDITION_LO);
				return instruction->instruction_next;
			case ISNE:
				as_set_condition_instruction (instruction,CONDITION_NE);
				return instruction->instruction_next;
			case ISO:
				as_set_condition_instruction (instruction,CONDITION_VS);
				return instruction->instruction_next;
			case ISNO:
				as_set_condition_instruction (instruction,CONDITION_VC);
				return instruction->instruction_next;
			default:
				internal_error_in_function ("as_instructions_using_condition_flags");
		}
		instruction=instruction->instruction_next;
	}

	return instruction;
}

static void as_instructions (struct instruction *instruction)
{
	while (instruction!=NULL){
		switch (instruction->instruction_icode){
			case IMOVE:
				instruction=as_move_instruction_may_modify_condition_flags (instruction);
				break;
			case ILEA:
				as_lea_instruction (instruction);
				break;
			case IADD:
				as_add_instruction_may_modify_condition_flags (instruction);
				break;
			case ISUB:
				as_sub_instruction_may_modify_condition_flags (instruction);
				break;
			case ICMP:
				as_cmp_instruction (instruction);
				instruction=as_instructions_using_condition_flags (instruction->instruction_next);
				continue;
			case IJMP:
				as_jmp_instruction (instruction);
				break;
			case IJMPP:
				as_jmpp_instruction (instruction);
				break;
			case IJSR:
				as_jsr_instruction (instruction);
				break;
			case IRTS:
				as_rts_instruction();
				break;
			case IRTSI:
				as_rtsi_instruction (instruction);
				break;
			case IRTSP:
				as_rtsp_instruction();
				break;
			case IBEQ:
				as_branch_instruction (instruction,CONDITION_EQ);
				break;
			case IBGE:
				as_branch_instruction (instruction,CONDITION_GE);
				break;
			case IBGEU:
				as_branch_instruction (instruction,CONDITION_HS);
				break;
			case IBGT:
				as_branch_instruction (instruction,CONDITION_GT);
				break;
			case IBGTU:
				as_branch_instruction (instruction,CONDITION_HI);
				break;
			case IBLE:
				as_branch_instruction (instruction,CONDITION_LE);
				break;
			case IBLEU:
				as_branch_instruction (instruction,CONDITION_LS);
				break;
			case IBLT:
				as_branch_instruction (instruction,CONDITION_LT);
				break;
			case IBLTU:
				as_branch_instruction (instruction,CONDITION_LO);
				break;
			case IBNE:
				as_branch_instruction (instruction,CONDITION_NE);
				break;
			case IBO:
				as_branch_instruction (instruction,CONDITION_VS);
				break;
			case IBNO:
				as_branch_instruction (instruction,CONDITION_VC);
				break;
			case ILSL:
				as_lsl_instruction_may_modify_condition_flags (instruction);
				break;
			case ILSR:
				as_lsr_instruction (instruction);
				break;
			case IASR:
				as_asr_instruction (instruction);
				break;
			case IMUL:
				as_mul_instruction (instruction);
				break;
			case IDIV:
				as_div_instruction (instruction);
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
				as_eor_instruction (instruction);
				break;
			case IADDI:
				as_addi_instruction (instruction);
				break;
			case IANDI:
				as_and_i_instruction (instruction);
				break;
			case IORI:
				as_or_i_instruction (instruction);
				break;
			case ILSLI:
				as_lsli_instruction_may_modify_condition_flags (instruction);
				break;
			case ISEQ:
				as_set_condition_instruction (instruction,CONDITION_EQ);
				break;
			case ISGE:
				as_set_condition_instruction (instruction,CONDITION_GE);
				break;
			case ISGEU:
				as_set_condition_instruction (instruction,CONDITION_HS);
				break;
			case ISGT:
				as_set_condition_instruction (instruction,CONDITION_GT);
				break;
			case ISGTU:
				as_set_condition_instruction (instruction,CONDITION_HI);
				break;
			case ISLE:
				as_set_condition_instruction (instruction,CONDITION_LE);
				break;
			case ISLEU:
				as_set_condition_instruction (instruction,CONDITION_LS);
				break;
			case ISLT:
				as_set_condition_instruction (instruction,CONDITION_LT);
				break;
			case ISLTU:
				as_set_condition_instruction (instruction,CONDITION_LO);
				break;
			case ISNE:
				as_set_condition_instruction (instruction,CONDITION_NE);
				break;
			case ISO:
				as_set_condition_instruction (instruction,CONDITION_VS);
				break;
			case ISNO:
				as_set_condition_instruction (instruction,CONDITION_VC);
				break;
			case ITST:
				as_tst_instruction (instruction);
				instruction=as_instructions_using_condition_flags (instruction->instruction_next);
				continue;
			case IBTST:
				as_btst_instruction (instruction);
				instruction=as_instructions_using_condition_flags (instruction->instruction_next);
				continue;
			case IMOVEDB:
				as_movew_instruction (instruction);
				break;
			case IMOVEB:
				as_moveb_instruction (instruction);
				break;
			case INEG:
				as_neg_instruction (instruction);
				break;
			case INOT:
				as_not_instruction (instruction);
				break;
			case ICLZB:
				as_clzb_instruction (instruction);
				break;
			case IMOVEM:
				as_movem_instruction (instruction);
				break;
			case IADC:
				as_add_or_sub_x_instruction (instruction,THUMB2_OP_ADC,THUMB2_OP_SBC);
				break;
			case ISBB:
				as_add_or_sub_x_instruction (instruction,THUMB2_OP_SBC,THUMB2_OP_ADC);
				break;
			case IMULUD:
				as_mulud_instruction (instruction);
				break;
			case IWORD:
				store_w (instruction->instruction_parameters[0].parameter_data.i);
				break;
			case IROTR:
				as_rotr_instruction (instruction);
				break;
			case IADDO:
				as_addo_instruction (instruction);
				break;
			case ISUBO:
				as_add_or_sub_x_instruction (instruction,THUMB2_OP_SUB,THUMB2_OP_ADD);
				break;
			case IFMOVE:
				as_fmove_instruction (instruction);
				break;
			case IFADD:
				as_dyadic_float_instruction (instruction,0x00300000);
				break;
			case IFSUB:
				as_float_sub_or_div_instruction (instruction,0x00300040);
				break;
			case IFCMP:
				as_compare_float_instruction (instruction);
				instruction=as_instructions_using_condition_flags (instruction->instruction_next);
				continue;
			case IFDIV:
				as_float_sub_or_div_instruction (instruction,0x00800000);
				break;
			case IFMUL:
				as_dyadic_float_instruction (instruction,0x00200000);
				break;
			case IFBEQ:
				as_float_branch_instruction (instruction,CONDITION_EQ);
				break;
			case IFBGE:
				as_float_branch_instruction (instruction,CONDITION_GE);
				break;
			case IFBGT:
				as_float_branch_instruction (instruction,CONDITION_GT);
				break;
			case IFBLE:
				as_float_branch_instruction (instruction,CONDITION_LS);
				break;
			case IFBLT:
				as_float_branch_instruction (instruction,CONDITION_MI);
				break;
			case IFBNE:
				as_float_branch_vc_and_instruction (instruction,CONDITION_NE);
				break;
			case IFBNEQ:
				as_float_branch_instruction (instruction,CONDITION_NE);
				break;
			case IFBNGE:
				as_float_branch_instruction (instruction,CONDITION_LT);
				break;
			case IFBNGT:
				as_float_branch_instruction (instruction,CONDITION_LE);
				break;
			case IFBNLE:
				as_float_branch_instruction (instruction,CONDITION_HI);
				break;
			case IFBNLT:
				as_float_branch_instruction (instruction,CONDITION_PL);
				break;
			case IFBNNE:
				as_float_branch_vs_or_instruction (instruction,CONDITION_EQ);
				break;
			case IFMOVEL:
				as_fmovel_instruction (instruction);
				break;
			case IFLOADS:
				as_floads_instruction (instruction);
				break;
			case IFMOVES:
				as_fmoves_instruction (instruction);
				break;
			case IFSQRT:
				as_monadic_float_instruction (instruction,0x10080);
				break;
			case IFNEG:
				as_monadic_float_instruction (instruction,0x10000);
				break;
			case IFABS:
				as_monadic_float_instruction (instruction,0x00080);
				break;
			case IFSEQ:
				as_set_float_condition_instruction (instruction,CONDITION_EQ);
				break;
			case IFSGE:
				as_set_float_condition_instruction (instruction,CONDITION_PL);
				break;
			case IFSGT:
				as_set_float_condition_instruction (instruction,CONDITION_GT);
				break;
			case IFSLE:
				as_set_float_condition_instruction (instruction,CONDITION_LE);
				break;
			case IFSLT:
				as_set_float_condition_instruction (instruction,CONDITION_MI);
				break;
			case IFSNE:
				as_set_float_vc_and_condition_instruction (instruction,CONDITION_NE);
				break;
			default:
				internal_error_in_function ("as_instructions");
		}
		instruction=instruction->instruction_next;
	}
}

static void as_garbage_collect_test (struct basic_block *block)
{
	LONG n_cells;
	struct call_and_jump *new_call_and_jump;
	int shift;

	n_cells=block->block_n_new_heap_cells;	
	
	new_call_and_jump=allocate_memory_from_heap (sizeof (struct call_and_jump));
	new_call_and_jump->cj_next=NULL;

	switch (block->block_n_begin_a_parameter_registers){
		case 0:
			new_call_and_jump->cj_call_label=collect_0_label;
			break;
		case 1:
			new_call_and_jump->cj_call_label=collect_1_label;
			break;
		case 2:
			new_call_and_jump->cj_call_label=collect_2_label;
			break;
		case 3:
			new_call_and_jump->cj_call_label=collect_3_label;
			break;
		default:
			internal_error_in_function ("as_garbage_collect_test");
			return;
	}

	if (first_call_and_jump!=NULL)
		last_call_and_jump->cj_next=new_call_and_jump;
	else
		first_call_and_jump=new_call_and_jump;
	last_call_and_jump=new_call_and_jump;

	shift = immediate_shift (n_cells);
	if (shift>=0){
		as_subs_is_r_r (n_cells,shift,REGISTER_R11,REGISTER_R11);
	} else {
		as_ldr_r_literal (REGISTER_S0);
		as_literal_constant_entry (n_cells,LDR_OFFSET_RELOCATION);

		as_op_s_r_r_r (THUMB2_OP_SUB,REGISTER_S0,REGISTER_R11,REGISTER_R11); /* subs */
	}

	store_lsw ((CONDITION_LO<<22) | 0xf0008000); /* blo */
	as_branch_label (&new_call_and_jump->cj_label,BRANCH_RELOCATION);

	new_call_and_jump->cj_jump.label_flags=0;
	new_call_and_jump->cj_jump.label_id=TEXT_LABEL_ID;
#ifdef FUNCTION_LEVEL_LINKING
	new_call_and_jump->cj_jump.label_object_label=code_object_label;
#endif
	new_call_and_jump->cj_jump.label_offset=CURRENT_CODE_OFFSET;
}

static void as_call_and_jump (struct call_and_jump *call_and_jump)
{
	call_and_jump->cj_label.label_flags=0;
	call_and_jump->cj_label.label_id=TEXT_LABEL_ID;
#ifdef FUNCTION_LEVEL_LINKING
	call_and_jump->cj_label.label_object_label=code_object_label;
#endif
	call_and_jump->cj_label.label_offset=CURRENT_CODE_OFFSET;

	if (call_and_jump->cj_jump.label_id==-1){
		store_lsw (0xf0009000); /* b */
		as_branch_label (call_and_jump->cj_call_label,LONG_JUMP_RELOCATION);
	} else {
		store_lsw (0xf000f800); /* bl */
		as_branch_label (call_and_jump->cj_call_label,CALL_RELOCATION);

		store_lsw (0xf0009000); /* b */
		as_branch_label (&call_and_jump->cj_jump,LONG_JUMP_RELOCATION);
	}
}

static void as_check_stack (struct basic_block *block)
{
#if 0
	if (block->block_a_stack_check_size>0){
		if (block->block_a_stack_check_size<=32)
			as_r_a (0073,A_STACK_POINTER,end_a_stack_label); /* cmp */
		else {
			as_id_r (0215,block->block_a_stack_check_size,A_STACK_POINTER,REGISTER_S0); /* lea */
			as_r_a (0073,REGISTER_S0,end_a_stack_label); /* cmp */
		}

		store_c (0x0f);
		store_c (0x83); /* jae */
		store_l (0);
		as_branch_label (stack_overflow_label,BRANCH_RELOCATION);
	}

	if (block->block_b_stack_check_size>0){
		if (block->block_b_stack_check_size<=32)
			as_r_a (0073,B_STACK_POINTER,end_b_stack_label); /* cmp */
		else {
			as_id_r (0215,block->block_b_stack_check_size,B_STACK_POINTER,REGISTER_S0); /* lea */
			as_r_a (0073,REGISTER_S0,end_b_stack_label); /* cmp */
		}
		
		store_c (0x0f);
		store_c (0x82); /* jb */
		store_l (0);
		as_branch_label (stack_overflow_label,BRANCH_RELOCATION);
	}
#else
	internal_error_in_function ("as_check_stack");
#endif
}

static void as_profile_call (struct basic_block *block)
{
	LABEL *profile_label;
	
	as_move_d_r (block->block_profile_function_label,0,REGISTER_A3);
	
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
	store_lsw (0xf000f800); /* bl */
	as_branch_label (profile_label,CALL_RELOCATION);
}

extern LABEL *add_empty_node_labels[];

static void as_apply_update_entry (struct basic_block *block)
{
	int n_node_arguments;

	n_node_arguments=block->block_n_node_arguments;
	if (n_node_arguments<-200){
		store_lsw (0xf0009000); /* b */
		as_branch_label (block->block_descriptor,LONG_JUMP_RELOCATION);

		if (block->block_ea_label==NULL){
			if (block->block_profile)
				as_profile_call (block);

			as_nop_w();
			as_nop_w();
			return;
		}

		n_node_arguments+=300;
	} else
		n_node_arguments+=200;

	if (block->block_profile)
		as_profile_call (block);

	if (n_node_arguments==0){
		store_lsw (0xf0009000); /* b */
		as_branch_label (block->block_ea_label,LONG_JUMP_RELOCATION);

		as_nop_w();
	} else {
		store_lsw (0xf000f800); /* bl */
		as_branch_label (add_empty_node_labels[n_node_arguments],CALL_RELOCATION);

		store_lsw (0xf0009000); /* b */
		as_branch_label (block->block_ea_label,LONG_JUMP_RELOCATION);
	}
}

static void as_node_entry_info (struct basic_block *block)
{
	if (block->block_ea_label!=NULL){
		extern LABEL *eval_fill_label,*eval_upd_labels[];
		int n_node_arguments;

		n_node_arguments=block->block_n_node_arguments;
		if (n_node_arguments<-2)
			n_node_arguments=1;

		if (n_node_arguments>=0 && block->block_ea_label!=eval_fill_label){
			if (!block->block_profile){
				if (!pic_flag){
					as_movw_i_r (0,REGISTER_A3);
					store_low_label_word_in_code_section (block->block_ea_label);

					as_movt_i_r (0,REGISTER_A3);
					store_high_label_word_in_code_section (block->block_ea_label);

					store_lsw (0xf0009000); /* b */
					as_branch_label (eval_upd_labels[n_node_arguments],LONG_JUMP_RELOCATION);
				} else {
					as_move_l_r (block->block_ea_label,REGISTER_A3);

					store_lsw (0xf0009000); /* b */
					as_branch_label (eval_upd_labels[n_node_arguments],LONG_JUMP_RELOCATION);
				}
			} else {
				as_move_l_r (block->block_ea_label,REGISTER_D0);
				as_move_l_r (block->block_profile_function_label,REGISTER_A3);

				store_lsw (0xf0009000 | 0x04000004); /* b, offset -8 */
				as_branch_label (eval_upd_labels[n_node_arguments],LONG_JUMP_RELOCATION);
			}
		} else {
			store_lsw (0xf0009000); /* b */
			as_branch_label (block->block_ea_label,LONG_JUMP_RELOCATION);
		
			as_nop_w();
			as_nop_w();
		}
		
		begin_data_mapping();

		if (block->block_descriptor!=NULL && (block->block_n_node_arguments<0 || parallel_flag || module_info_flag)){
			store_l (0);
			if (!pic_flag)
				store_label_in_code_section (block->block_descriptor);
			else
				store_relative_label_in_code_section (block->block_descriptor);
		} else
			store_l (0);
	} else {
		begin_data_mapping();

		if (block->block_descriptor!=NULL && (block->block_n_node_arguments<0 || parallel_flag || module_info_flag)){
			store_l (0);
			if (!pic_flag)
				store_label_in_code_section (block->block_descriptor);
			else
				store_relative_label_in_code_section (block->block_descriptor);
		}
		/* else
			store_l (0);
		*/
	}
	
	store_l (block->block_n_node_arguments);

	{
		unsigned long current_code_offset;
		
		current_code_offset = CURRENT_CODE_OFFSET;
		last_mapping_symbol_code_offset = current_code_offset;
		last_mapping_symbol->ms_table_size = current_code_offset - last_mapping_symbol->ms_data_offset;
	}
}

static void write_code (void)
{
	struct basic_block *block;
	struct call_and_jump *call_and_jump;

#ifdef FUNCTION_LEVEL_LINKING
	if (first_block!=NULL && !first_block->block_begin_module)
		first_block->block_begin_module=1;
#endif

	literal_entry_l=&first_literal_entry;
	first_literal_entry=NULL;
	remaining_literal_entry_l=literal_entry_l;
	
	for_l (block,first_block,block_next){
#ifdef FUNCTION_LEVEL_LINKING
		if (block->block_begin_module){
			if (block->block_link_module){
				if (code_object_label!=NULL && CURRENT_CODE_OFFSET!=code_object_label->object_label_offset && block->block_labels){
					int align;
					
					align = 3 & -(CURRENT_CODE_OFFSET-code_object_label->object_label_offset);
#ifdef OPTIMISE_BRANCHES
					{
						struct relocation *new_relocation;

						new_relocation=fast_memory_allocate_type (struct relocation);
						
						*last_code_relocation_l=new_relocation;
						last_code_relocation_l=&new_relocation->next;
						new_relocation->next=NULL;
						
						U5 (new_relocation,
							relocation_offset=CURRENT_CODE_OFFSET,
							relocation_kind=ALIGN_RELOCATION,
							relocation_align1=align,
							relocation_align2=align,			
							relocation_object_label=code_object_label);
					}
#endif
					switch (align){
						case 0:
							break;
						case 2:
							as_nop();
							break;
						default:
							internal_error_in_function ("write_code");
					}
					{
						struct relocation *new_relocation;
						
						new_relocation=fast_memory_allocate_type (struct relocation);
						
						*last_code_relocation_l=new_relocation;
						last_code_relocation_l=&new_relocation->next;
						new_relocation->next=NULL;
						
						U4 (new_relocation,
							relocation_label=block->block_labels->block_label_label,
							relocation_offset=CURRENT_CODE_OFFSET,
							relocation_object_label=code_object_label,
							relocation_kind=DUMMY_BRANCH_RELOCATION);
					}
#ifdef FUNCTION_LEVEL_LINKING
					as_new_code_module();
#endif
					*(struct object_label**)&block->block_last_instruction = code_object_label;
				} else
					*(struct object_label**)&block->block_last_instruction = NULL;			
			} else {
#ifdef FUNCTION_LEVEL_LINKING
				if (code_object_label!=NULL){
					int align;
					
					align = 3 & -(CURRENT_CODE_OFFSET-code_object_label->object_label_offset);
# ifdef OPTIMISE_BRANCHES
					{
						struct relocation *new_relocation;

						new_relocation=fast_memory_allocate_type (struct relocation);
						
						*last_code_relocation_l=new_relocation;
						last_code_relocation_l=&new_relocation->next;
						new_relocation->next=NULL;
						
						U5 (new_relocation,
							relocation_offset=CURRENT_CODE_OFFSET,
							relocation_kind=ALIGN_RELOCATION,
							relocation_align1=align,
							relocation_align2=align,			
							relocation_object_label=code_object_label);
					}
# endif
					switch (align){
						case 0:
							break;
						case 2:
							as_nop();
							break;
						default:
							internal_error_in_function ("write_code");
					}
				}
				write_literals_already_aligned();
				as_new_code_module();
#endif
				*(struct object_label**)&block->block_last_instruction = code_object_label;
			}
		} else
			*(struct object_label**)&block->block_last_instruction = NULL;
#endif

		if (block->block_n_node_arguments>-100){
#ifndef FUNCTION_LEVEL_LINKING
			if ((code_buffer_free & 3)!=0){
				as_nop();
				if ((code_buffer_free & 3)!=0)
					internal_error_in_function ("write_code");
			}
#endif
			as_node_entry_info (block);
		} else if (block->block_n_node_arguments<-100)
			as_apply_update_entry (block);

		as_labels (block->block_labels);

		if (block->block_profile)
			as_profile_call (block);

		if (block->block_n_new_heap_cells>0)
			as_garbage_collect_test (block);

		if (check_stack && (block->block_a_stack_check_size>0 || block->block_b_stack_check_size>0))
			as_check_stack (block);
		
		as_instructions (block->block_instructions);
	}

#ifdef FUNCTION_LEVEL_LINKING
	if (code_object_label!=NULL){
		int align;
		
		align = 3 & -(CURRENT_CODE_OFFSET-code_object_label->object_label_offset);
# ifdef OPTIMISE_BRANCHES
		{
			struct relocation *new_relocation;

			new_relocation=fast_memory_allocate_type (struct relocation);
			
			*last_code_relocation_l=new_relocation;
			last_code_relocation_l=&new_relocation->next;
			new_relocation->next=NULL;
			
			U5 (new_relocation,
				relocation_offset=CURRENT_CODE_OFFSET,
				relocation_kind=ALIGN_RELOCATION,
				relocation_align1=align,
				relocation_align2=align,			
				relocation_object_label=code_object_label);
		}
# endif
		switch (align){
			case 0:
				break;
			case 2:
				as_nop();
				break;
			default:
				internal_error_in_function ("write_code");
		}
	}
#endif

	write_literals_already_aligned();

	for_l (call_and_jump,first_call_and_jump,cj_next){
#ifdef FUNCTION_LEVEL_LINKING
		as_new_code_module();
#endif
		as_call_and_jump (call_and_jump);
	}
}

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

extern char *this_module_name;

#if defined (ELF) && defined (FUNCTION_LEVEL_LINKING)
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
static int n_local_section_and_mapping_symbols;
#endif

#ifdef FUNCTION_LEVEL_LINKING
static int count_mapping_symbols (void)
{
	/* $t and $d symbols */
	struct object_label *object_label;
	int n_mapping_symbols;
	struct mapping_symbol *mapping_symbol_p;

	n_mapping_symbols=0;
	mapping_symbol_p=first_mapping_symbol;
	while (mapping_symbol_p!=NULL && mapping_symbol_p->ms_table_size==0)
		mapping_symbol_p=mapping_symbol_p->ms_next;

	object_label=first_object_label;
	while (object_label!=NULL && object_label->object_label_kind!=CODE_CONTROL_SECTION)
		object_label=object_label->next;

	while (object_label!=NULL){
		struct object_label *previous_object_label;
		unsigned long current_control_section_code_offset,next_control_section_code_offset;
		
		current_control_section_code_offset=object_label->object_label_offset;
		previous_object_label=object_label;

		object_label=object_label->next;
		while (object_label!=NULL && object_label->object_label_kind!=CODE_CONTROL_SECTION)
			object_label=object_label->next;

		if (object_label!=NULL)
			next_control_section_code_offset = object_label->object_label_offset;	
		else
			next_control_section_code_offset = end_code_offset;

		if (mapping_symbol_p==NULL || mapping_symbol_p->ms_data_offset!=current_control_section_code_offset)
			++n_mapping_symbols;

		while (mapping_symbol_p!=NULL && mapping_symbol_p->ms_data_offset<next_control_section_code_offset){					
			++n_mapping_symbols;
			if (mapping_symbol_p->ms_data_offset + mapping_symbol_p->ms_table_size!=next_control_section_code_offset)
				++n_mapping_symbols;			
			mapping_symbol_p=mapping_symbol_p->ms_next;
			while (mapping_symbol_p!=NULL && mapping_symbol_p->ms_table_size==0)
				mapping_symbol_p=mapping_symbol_p->ms_next;
		}
	}
		
	return n_mapping_symbols;
}
#endif

static void write_file_header_and_section_headers (void)
{
	unsigned int offset;
	int n_code_relocation_sections,n_data_relocation_sections;
	int section_strings_size;
	
#ifdef FUNCTION_LEVEL_LINKING
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
						section_strings_size+=12+n_digits (previous_code_object_label->object_label_section_n);
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
						section_strings_size+=12+n_digits (previous_data_object_label->object_label_section_n);
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
				section_strings_size+=12+n_digits (previous_code_object_label->object_label_section_n);
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
				section_strings_size+=12+n_digits (previous_data_object_label->object_label_section_n);
				++n_data_relocation_sections;
			}
		}
	}

	n_mapping_symbols = count_mapping_symbols();

	n_sections=n_code_sections+n_data_sections;
	n_local_section_and_mapping_symbols=n_sections+n_mapping_symbols;
	
	section_strings_size+=compute_section_strings_size (7,n_code_sections)+
						  compute_section_strings_size (7,n_data_sections);
#endif

	write_l (0x464c457f);
	write_l (0x00010101);
	write_l (0);
	write_l (0);
	write_l (0x00280001);
	write_l (1);
	write_l (0);
	write_l (0);
	write_l (0x34);
	write_l (EF_ARM_EABI_VER5);
	write_l (0x00000034);
	write_l (0x00280000);
#ifdef FUNCTION_LEVEL_LINKING
	write_l (0x00010000 | (n_sections+n_code_relocation_sections+n_data_relocation_sections+4));
#else
	write_l (0x00010008);
#endif

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

	write_l (1);
	write_l (SHT_STRTAB);
	write_l (0);
	write_l (0);
	write_l (offset);
#ifdef FUNCTION_LEVEL_LINKING
	write_l ((27+section_strings_size+3) & -4);
#else
	write_l (60);
#endif
	write_l (0);
	write_l (0);
	write_l (1);
	write_l (0);
#ifdef FUNCTION_LEVEL_LINKING
	offset+=(27+section_strings_size+3) & -4;
#else
	offset+=60;
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
					write_l (SHT_REL);
					write_l (0);
					write_l (0);
					write_l (offset+code_relocations_offset);
					write_l (8*n_code_relocations_in_section);
					write_l (n_sections+n_code_relocation_sections+n_data_relocation_sections+2);
					write_l (2+object_label->object_label_section_n);
					write_l (4);
					write_l (8);
					section_string_offset+=12+n_digits (object_label->object_label_section_n);
					code_relocations_offset+=8*n_code_relocations_in_section;
				}
			}
		}
		offset+=8*n_code_relocations;

		data_relocations_offset=0;
	
		for_l (object_label,first_object_label,next){
			if (object_label->object_label_kind==DATA_CONTROL_SECTION){
				int n_data_relocations_in_section;
			
				n_data_relocations_in_section=object_label->object_label_n_relocations;
				
				if (n_data_relocations_in_section>0){
					write_l (section_string_offset);
					write_l (SHT_REL);
					write_l (0);
					write_l (0);
					write_l (offset+data_relocations_offset);
					write_l (8*n_data_relocations_in_section);
					write_l (n_sections+n_code_relocation_sections+n_data_relocation_sections+2);
					write_l (2+n_code_sections+object_label->object_label_section_n);
					write_l (4);
					write_l (8);
					section_string_offset+=12+n_digits (object_label->object_label_section_n);
					data_relocations_offset+=8*n_data_relocations_in_section;
				}
			}
		}
		offset+=8*n_data_relocations;
	}
#else
	write_l (11);
	write_l (SHT_PROGBITS);
	write_l (SHF_ALLOC | SHF_EXECINSTR);
	write_l (0);
	write_l (offset);
	write_l (code_buffer_offset);
	write_l (0);
	write_l (0);
	write_l (4);
	write_l (0);
	offset+=(code_buffer_offset+3 ) & ~3;

	write_l (17);
	write_l (SHT_PROGBITS);
	write_l (SHF_ALLOC | SHF_WRITE);
	write_l (0);
	write_l (offset);
	write_l (data_buffer_offset);
	write_l (0);
	write_l (0);
	write_l (4);
	write_l (0);
	offset+=(data_buffer_offset+3) & ~3;

	write_l (23);
	write_l (SHT_REL);
	write_l (0);
	write_l (0);
	write_l (offset);
	write_l (8*n_code_relocations);
	write_l (6);
	write_l (2);
	write_l (4);
	write_l (8);
	offset+=8*n_code_relocations;

	write_l (33);
	write_l (SHT_REL);
	write_l (0);
	write_l (0);
	write_l (offset);
	write_l (8*n_data_relocations);
	write_l (6);
	write_l (3);
	write_l (4);
	write_l (8);
	offset+=8*n_data_relocations;
#endif

#ifdef FUNCTION_LEVEL_LINKING
	write_l (11+section_strings_size);
#else
	write_l (43);
#endif
	write_l (SHT_SYMTAB);
	write_l (0);
	write_l (0);
	write_l (offset);
#ifdef FUNCTION_LEVEL_LINKING
	write_l (16*(n_object_labels+n_local_section_and_mapping_symbols));
	write_l (n_sections+n_code_relocation_sections+n_data_relocation_sections+3);
	write_l (1+n_local_section_and_mapping_symbols);
#else
	write_l (16*n_object_labels);
	write_l (7);
	write_l (3);
#endif
	write_l (4);
	write_l (16);
#ifdef FUNCTION_LEVEL_LINKING
	offset+=16*(n_object_labels+n_local_section_and_mapping_symbols);
#else
	offset+=16*n_object_labels;
#endif

#ifdef FUNCTION_LEVEL_LINKING
	write_l (19+section_strings_size);
#else
	write_l (51);
#endif
	write_l (SHT_STRTAB);
	write_l (0);
	write_l (0);
	write_l (offset);
	write_l (string_table_offset);
	write_l (0);
	write_l (0);
	write_l (0);
	write_l (0);

	write_c (0);
	write_zstring (".shstrtab");
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
				sprintf (section_name,".rel.text.m%d",object_label->object_label_section_n);
				write_zstring (section_name);
			}
	
		for_l (object_label,first_object_label,next)
			if (object_label->object_label_kind==DATA_CONTROL_SECTION && object_label->object_label_n_relocations>0){ 
				sprintf (section_name,".rel.data.m%d",object_label->object_label_section_n);
				write_zstring (section_name);
			}
	}
#else
	write_zstring (".text");
	write_zstring (".data");
	write_zstring (".rel.text");
	write_zstring (".rel.data");
#endif
	write_zstring (".symtab");
	write_zstring (".strtab");

	if (((27+section_strings_size) & 3)!=0){
		int n;

		n=4-((27+section_strings_size) & 3);
		do {
			write_c (0);
		} while (--n);
	}
}

#if defined (OPTIMISE_BRANCHES)
static int search_short_branches (void)
{
	struct relocation *relocation;
	struct object_buffer *object_buffer;
	int code_buffer_offset,offset_difference;
	struct label *label;
	int instruction_offset,found_new_short_branch;
	LONG v;

	found_new_short_branch=0;
	offset_difference=0;

	object_buffer=first_code_buffer;
	code_buffer_offset=0;

	for_l (relocation,first_code_relocation,next){
		switch (relocation->relocation_kind){
			case BRANCH_RELOCATION:
				label=relocation->relocation_label;

				if (label->label_id!=TEXT_LABEL_ID)
					break;
/*
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_object_label!=relocation->relocation_object_label)
					break;
#endif
*/
				instruction_offset=relocation->relocation_offset;

				while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					code_buffer_offset+=BUFFER_SIZE;
				}
				
				v=label->label_offset-(instruction_offset+4-offset_difference);
				if (v>=-254 && v<=252){
/*				if (v>=-256 && v<=254){ */
					relocation->relocation_kind=NEW_SHORT_BRANCH_RELOCATION;
					found_new_short_branch=1;
				}
				break;
			case JUMP_RELOCATION:
			{
				unsigned int i;

				label=relocation->relocation_label;

				if (label->label_id!=TEXT_LABEL_ID)
					break;
/*
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_object_label!=relocation->relocation_object_label)
					break;
#endif
*/
				instruction_offset=relocation->relocation_offset;

				while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					code_buffer_offset+=BUFFER_SIZE;
				}
				
				v=label->label_offset-(instruction_offset+4-offset_difference);

				if (instruction_offset-code_buffer_offset<=BUFFER_SIZE-4)
					i = *(LONG*)(object_buffer->data+(instruction_offset-code_buffer_offset));
				else {
					unsigned char *p0,*p1,*p2,*p3,*end_buffer;

					p0=object_buffer->data+(instruction_offset-code_buffer_offset);
					end_buffer=object_buffer->data+BUFFER_SIZE;
					p1=p0+1;
					if (p1==end_buffer)
						p1=object_buffer->next->data;
					p2=p1+1;
					if (p2==end_buffer)
						p2=object_buffer->next->data;
					p3=p2+1;
					if (p3==end_buffer)
						p3=object_buffer->next->data;

					i = (*p0) | (*p1<<8) | (*p2<<16) | (*p3<<24);
				}

				if ((i & 0x3ff0000)!=0){
					if (i & 0x400)
						v -= (i>>15) & 0x7fe;
					else
						v += (i>>15) & 0x7fe;
				}

				if (v>=-2046 && v<=2044){
/*				if (v>=-2048 && v<=2046){ */
					relocation->relocation_kind=NEW_SHORT_JUMP_RELOCATION;
					found_new_short_branch=1;
				}
				break;
			}
			case LDR_OFFSET_RELOCATION:
			{
				struct literal_entry *literal_entry_p;

				literal_entry_p=relocation->relocation_literal_entry_p;
				instruction_offset=relocation->relocation_offset;

				if (literal_entry_p->le_label!=NULL && literal_entry_p->le_label->label_id==TEXT_LABEL_ID){
					LONG literal_offset,adr_offset;
					
					literal_offset = literal_entry_p->le_label->label_offset + literal_entry_p->le_offset;
					adr_offset = literal_offset - (((instruction_offset-offset_difference) & -4)+4);
#if 0
					if (adr_offset>-4092 && adr_offset<4092){
#else
					/* work around bug in ld, probably patched in 2.28 */
					if (adr_offset>=0 && adr_offset<4092){
#endif
						relocation->relocation_kind = ADR_RELOCATION;
						found_new_short_branch=1;
						--literal_entry_p->le_usage_count;
						break;
					}
					/* else
						printf ("LDR_OFFSET_RELOCATION %ld\n",adr_offset);
					*/
				}

				label=&literal_entry_p->le_load_instruction_label;
				if (label->label_id!=TEXT_LABEL_ID)
					break;
/*
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_object_label!=relocation->relocation_object_label)
					break;
#endif
*/
				while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					code_buffer_offset+=BUFFER_SIZE;
				}
				
				v=label->label_offset-(((instruction_offset-offset_difference) & -4)+4);
				if (v>=0 && v<1020){
					relocation->relocation_kind=NEW_SHORT_LDR_OFFSET_RELOCATION;
					found_new_short_branch=1;
				}
				break;
			}
			case LONG_LDR_OFFSET_RELOCATION:
			{
				struct literal_entry *literal_entry_p;

				literal_entry_p=relocation->relocation_literal_entry_p;
				instruction_offset=relocation->relocation_offset;

				if (literal_entry_p->le_label!=NULL && literal_entry_p->le_label->label_id==TEXT_LABEL_ID){
					LONG literal_offset,adr_offset;
					
					literal_offset = literal_entry_p->le_label->label_offset + literal_entry_p->le_offset;
					adr_offset = literal_offset - (((instruction_offset-offset_difference) & -4)+4);
#if 0
					if (adr_offset>-4092 && adr_offset<4092){
#else
					/* work around bug in ld, probably patched in 2.28 */
					if (adr_offset>=0 && adr_offset<4092){
#endif
						relocation->relocation_kind = ADR_RELOCATION;
						found_new_short_branch=1;
						--literal_entry_p->le_usage_count;
						break;
					}
					/* else
						printf ("LONG_LDR_OFFSET_RELOCATION %ld\n",adr_offset);
					*/
				}
				break;
			}
			case SHORT_BRANCH_RELOCATION:
			case SHORT_JUMP_RELOCATION:
			case SHORT_LDR_OFFSET_RELOCATION:
				offset_difference+=2;
				break;
			case ALIGN_RELOCATION:
				offset_difference += relocation->relocation_align1-relocation->relocation_align2;
				break;
#ifdef OPTIMISE_BRANCHES
			case LONG_WORD_LITERAL_RELOCATION:
				if (relocation->relocation_literal_entry_p->le_usage_count==0){
					relocation->relocation_kind = NEW_UNUSED_LONG_WORD_LITERAL_RELOCATION;
					found_new_short_branch=1;
				}
				break;
			case UNUSED_LONG_WORD_LITERAL_RELOCATION:
				offset_difference+=4;
				break;
#endif
			case CALL_RELOCATION:
			case LONG_JUMP_RELOCATION:
			case VLDR_OFFSET_RELOCATION:
			case LONG_WORD_RELOCATION:
			case RELATIVE_LONG_WORD_RELOCATION:
			case MOVW_RELOCATION:
			case MOVT_RELOCATION:
#ifdef FUNCTION_LEVEL_LINKING
			case DUMMY_BRANCH_RELOCATION:
#endif
			case BRANCH_SKIP_BRANCH_RELOCATION:
			case ADJUST_ADR_RELOCATION:
			case ADR_RELOCATION:
				break;
			default:
				internal_error_in_function ("search_short_branches");
		}
	}
	
	return found_new_short_branch;
}

static struct relocation *calculate_new_label_offset
	(ULONG *label_offset_p,int *offset_difference_p,int *new_offset_difference_p,struct relocation *relocation)
{
	while (relocation!=NULL){
		int offset2;
		
		offset2=*label_offset_p-*new_offset_difference_p;

		if (relocation->relocation_offset-*offset_difference_p>=offset2)
			if (! (relocation->relocation_offset-*offset_difference_p==offset2
					&& ((relocation->relocation_kind==ALIGN_RELOCATION && relocation->relocation_align2==0)
#ifdef FUNCTION_LEVEL_LINKING
						|| relocation->relocation_kind==DUMMY_BRANCH_RELOCATION
#endif
						)))
				break;

		switch (relocation->relocation_kind){
			case NEW_SHORT_BRANCH_RELOCATION:
				*new_offset_difference_p+=2;
				relocation->relocation_kind=SHORT_BRANCH_RELOCATION;
			case SHORT_BRANCH_RELOCATION:
				*offset_difference_p+=2;
				break;
			case NEW_SHORT_JUMP_RELOCATION:
				*new_offset_difference_p+=2;
				relocation->relocation_kind=SHORT_JUMP_RELOCATION;
			case SHORT_JUMP_RELOCATION:
				*offset_difference_p+=2;
				break;
			case NEW_SHORT_LDR_OFFSET_RELOCATION:
				*new_offset_difference_p+=2;
				relocation->relocation_kind=SHORT_LDR_OFFSET_RELOCATION;
			case SHORT_LDR_OFFSET_RELOCATION:
				*offset_difference_p+=2;
				break;
			case ALIGN_RELOCATION:
			{
				int new_align;

#ifdef FUNCTION_LEVEL_LINKING
				new_align= 3 & -(relocation->relocation_offset-*offset_difference_p-relocation->relocation_object_label->object_label_offset);
#else				
				new_align= 3 & -(relocation->relocation_offset-*offset_difference_p);
#endif
				*offset_difference_p+=relocation->relocation_align1-new_align;
				*new_offset_difference_p+=relocation->relocation_align2-new_align;
				relocation->relocation_align2=new_align;
				break;
			}
#ifdef OPTIMISE_BRANCHES
			case NEW_UNUSED_LONG_WORD_LITERAL_RELOCATION:
				*new_offset_difference_p+=4;
				relocation->relocation_kind=UNUSED_LONG_WORD_LITERAL_RELOCATION;			
			case UNUSED_LONG_WORD_LITERAL_RELOCATION:
				*offset_difference_p+=4;
				break;
#endif				
		}
		relocation=relocation->next;
	}
	
	*label_offset_p -= *new_offset_difference_p;
	
	return relocation;
}

static void adjust_label_offsets (void)
{
	struct relocation *relocation;
	struct basic_block *block;
	struct call_and_jump *call_and_jump;
	int offset_difference,new_offset_difference;
	struct literal_entry *literal_entry_p;

#ifdef FUNCTION_LEVEL_LINKING
	struct object_label *object_label;
	
	object_label=first_object_label;
#endif

	relocation=first_code_relocation;
	call_and_jump=first_call_and_jump;
	literal_entry_p=first_literal_entry;
	
	offset_difference=0;
	new_offset_difference=0;
	
	for_l (block,first_block,block_next){
		struct block_label *labels;
		
		for_l (labels,block->block_labels,block_label_next){
#if 0
			if (labels->block_label_label->label_number==0)
#endif
			{
				LABEL *label;
				int label__offset;
				
				label=labels->block_label_label;
				label__offset=label->label_offset;
				
				while (call_and_jump!=NULL && (call_and_jump->cj_jump.label_id==-1 || call_and_jump->cj_jump.label_offset<label__offset)){
					if (call_and_jump->cj_jump.label_id!=-1){
						while (literal_entry_p!=NULL && literal_entry_p->le_load_instruction_label.label_offset<call_and_jump->cj_jump.label_offset){
							relocation=calculate_new_label_offset
								(&literal_entry_p->le_load_instruction_label.label_offset,&offset_difference,&new_offset_difference,relocation);
							literal_entry_p=literal_entry_p->le_next;
						}

						relocation=calculate_new_label_offset
							(&call_and_jump->cj_jump.label_offset,&offset_difference,&new_offset_difference,relocation);
					}
					call_and_jump=call_and_jump->cj_next;
				}

				while (literal_entry_p!=NULL && literal_entry_p->le_load_instruction_label.label_offset<label__offset){
					relocation=calculate_new_label_offset
						(&literal_entry_p->le_load_instruction_label.label_offset,&offset_difference,&new_offset_difference,relocation);
					literal_entry_p=literal_entry_p->le_next;
				}

#ifdef FUNCTION_LEVEL_LINKING
				while (object_label!=NULL){
					if (object_label->object_label_kind==CODE_CONTROL_SECTION){
						if (object_label->object_label_offset!=label__offset)
							break;
						
						relocation=calculate_new_label_offset
										(&object_label->object_label_offset,&offset_difference,&new_offset_difference,relocation);
					}
					object_label=object_label->next;
				}
#endif

				relocation=calculate_new_label_offset
					(&label->label_offset,&offset_difference,&new_offset_difference,relocation);
			}
		}
		
#ifdef FUNCTION_LEVEL_LINKING
		while (object_label!=NULL){
			if (object_label->object_label_kind==CODE_CONTROL_SECTION){
				if (object_label!=(struct object_label *)block->block_last_instruction)
					break;
				
				while (call_and_jump!=NULL && (call_and_jump->cj_jump.label_id==-1 || call_and_jump->cj_jump.label_offset<object_label->object_label_offset)){
					if (call_and_jump->cj_jump.label_id!=-1){
						while (literal_entry_p!=NULL && literal_entry_p->le_load_instruction_label.label_offset<call_and_jump->cj_jump.label_offset){
							relocation=calculate_new_label_offset
								(&literal_entry_p->le_load_instruction_label.label_offset,&offset_difference,&new_offset_difference,relocation);
							literal_entry_p=literal_entry_p->le_next;
						}

						relocation=calculate_new_label_offset
							(&call_and_jump->cj_jump.label_offset,&offset_difference,&new_offset_difference,relocation);
					}
										
					call_and_jump=call_and_jump->cj_next;
				}		
				
				while (literal_entry_p!=NULL && literal_entry_p->le_load_instruction_label.label_offset<object_label->object_label_offset){
					relocation=calculate_new_label_offset
						(&literal_entry_p->le_load_instruction_label.label_offset,&offset_difference,&new_offset_difference,relocation);
					literal_entry_p=literal_entry_p->le_next;
				}

				relocation=calculate_new_label_offset
								(&object_label->object_label_offset,&offset_difference,&new_offset_difference,relocation);
			}
			object_label=object_label->next;
		}
#endif
	}
	
	for (; call_and_jump!=NULL; call_and_jump=call_and_jump->cj_next)
		if (call_and_jump->cj_jump.label_id!=-1){
			while (literal_entry_p!=NULL && literal_entry_p->le_load_instruction_label.label_offset<call_and_jump->cj_jump.label_offset){
				relocation=calculate_new_label_offset
					(&literal_entry_p->le_load_instruction_label.label_offset,&offset_difference,&new_offset_difference,relocation);
				literal_entry_p=literal_entry_p->le_next;
			}
			relocation=calculate_new_label_offset
				(&call_and_jump->cj_jump.label_offset,&offset_difference,&new_offset_difference,relocation);
		}

	while (literal_entry_p!=NULL){
		relocation=calculate_new_label_offset
			(&literal_entry_p->le_load_instruction_label.label_offset,&offset_difference,&new_offset_difference,relocation);
		literal_entry_p=literal_entry_p->le_next;
	}
			
	for_l (call_and_jump,first_call_and_jump,cj_next){
#ifdef FUNCTION_LEVEL_LINKING
		while (object_label!=NULL){
			if (object_label->object_label_kind==CODE_CONTROL_SECTION){
				if (object_label->object_label_offset!=call_and_jump->cj_label.label_offset)
					break;
				
				relocation=calculate_new_label_offset
								(&object_label->object_label_offset,&offset_difference,&new_offset_difference,relocation);
			}
			object_label=object_label->next;
		}
#endif
		relocation=calculate_new_label_offset
			(&call_and_jump->cj_label.label_offset,&offset_difference,&new_offset_difference,relocation);
	}
	
#ifdef FUNCTION_LEVEL_LINKING
	if (object_label!=NULL)
		internal_error_in_function ("adjust_label_offsets");
#endif
	
	while (relocation!=NULL){
		switch (relocation->relocation_kind){ 
			case NEW_SHORT_BRANCH_RELOCATION:
				relocation->relocation_kind=SHORT_BRANCH_RELOCATION;
				break;
			case NEW_SHORT_JUMP_RELOCATION:
				relocation->relocation_kind=SHORT_JUMP_RELOCATION;
				break;
			case NEW_SHORT_LDR_OFFSET_RELOCATION:
				relocation->relocation_kind=SHORT_LDR_OFFSET_RELOCATION;
				break;
			case NEW_UNUSED_LONG_WORD_LITERAL_RELOCATION:
				relocation->relocation_kind=UNUSED_LONG_WORD_LITERAL_RELOCATION;
				break;
			default:
				break;
		}
		relocation=relocation->next;
	}
}

static void relocate_short_branches_and_move_code (void)
{
	struct relocation *relocation,**relocation_p;
	struct object_buffer *source_object_buffer,*destination_object_buffer;
	int source_buffer_offset,destination_buffer_offset;
	int source_offset;
	int offset_difference;
	struct mapping_symbol *mapping_symbol_p;
/*	struct literal_entry *literal_entry_p; */

	source_object_buffer=first_code_buffer;
	destination_object_buffer=first_code_buffer;
	source_offset=0;
	source_buffer_offset=0;
	destination_buffer_offset=0;
	
	offset_difference=0;

	relocation_p=&first_code_relocation;

	mapping_symbol_p=first_mapping_symbol;
/*	literal_entry_p=first_literal_entry; */

	while ((relocation=*relocation_p)!=NULL){
		struct label *label;
		int instruction_offset,branch_opcode;
		LONG v,instruction;

		switch (relocation->relocation_kind){
			case SHORT_BRANCH_RELOCATION:
				label=relocation->relocation_label;
				instruction_offset=relocation->relocation_offset;
#if 0
				*relocation_p=relocation->next;
#else
				relocation->relocation_offset -= offset_difference;
				relocation_p=&relocation->next;
#endif
				break;
			case SHORT_JUMP_RELOCATION:
				label=relocation->relocation_label;
				instruction_offset=relocation->relocation_offset;
#if 0
				*relocation_p=relocation->next;
#else
				relocation->relocation_offset -= offset_difference;
				relocation_p=&relocation->next;
#endif
				break;
			case SHORT_LDR_OFFSET_RELOCATION:
				label=&relocation->relocation_literal_entry_p->le_load_instruction_label;
				instruction_offset=relocation->relocation_offset;
#if 0
				*relocation_p=relocation->next;
#else
				relocation->relocation_offset -= offset_difference;
				relocation_p=&relocation->next;
#endif
				break;
			case ADR_RELOCATION:
				label=relocation->relocation_literal_entry_p->le_label;
				instruction_offset=relocation->relocation_offset;
				relocation->relocation_offset -= offset_difference;
				relocation_p=&relocation->next;
				break;
			case UNUSED_LONG_WORD_LITERAL_RELOCATION:
				instruction_offset=relocation->relocation_offset;
				relocation->relocation_offset -= offset_difference;
				relocation_p=&relocation->next;
				break;
			case JUMP_RELOCATION:
			case LONG_JUMP_RELOCATION:
			case BRANCH_RELOCATION:
			case CALL_RELOCATION:
			case LDR_OFFSET_RELOCATION:
			case LONG_LDR_OFFSET_RELOCATION:
			case VLDR_OFFSET_RELOCATION:
			case LONG_WORD_RELOCATION:
			case LONG_WORD_LITERAL_RELOCATION:
			case RELATIVE_LONG_WORD_RELOCATION:
			case MOVW_RELOCATION:
			case MOVT_RELOCATION:
#ifdef FUNCTION_LEVEL_LINKING
			case DUMMY_BRANCH_RELOCATION:
#endif
			case ADJUST_ADR_RELOCATION:
				relocation->relocation_offset -= offset_difference;
				relocation_p=&relocation->next;
				continue;
			case ALIGN_RELOCATION:
				instruction_offset=relocation->relocation_offset;
				*relocation_p=relocation->next;
				break;
			case BRANCH_SKIP_BRANCH_RELOCATION:
				*relocation_p=relocation->next;
				if (relocation->next->relocation_kind==SHORT_BRANCH_RELOCATION){
					instruction_offset=relocation->relocation_offset;
					break;
				} else
					continue;
			default:
				internal_error_in_function ("relocate_short_branches_and_move_code 0");
		}

		while (instruction_offset!=source_offset){
			int n;
			
			n=instruction_offset-source_offset;
						
			if (source_buffer_offset==BUFFER_SIZE){
				source_object_buffer=source_object_buffer->next;
				source_buffer_offset=0;
			}
			
			if (BUFFER_SIZE-source_buffer_offset < n)
				n = BUFFER_SIZE-source_buffer_offset;
			
			if (destination_buffer_offset==BUFFER_SIZE){
				destination_object_buffer=destination_object_buffer->next;
				destination_buffer_offset=0;
			}			

			if (BUFFER_SIZE-destination_buffer_offset < n)
				n = BUFFER_SIZE-destination_buffer_offset;

			memmove (&destination_object_buffer->data[destination_buffer_offset],&source_object_buffer->data[source_buffer_offset],n);
			destination_buffer_offset+=n;
			source_buffer_offset+=n;
			source_offset+=n;
		}

		if (relocation->relocation_kind==ALIGN_RELOCATION){
			int old_align,new_align;

#ifdef FUNCTION_LEVEL_LINKING
			new_align= 3 & -(instruction_offset-offset_difference-relocation->relocation_object_label->object_label_offset);
#else						
			new_align= 3 & -(instruction_offset-offset_difference);
#endif
			old_align=relocation->relocation_align1;
			
			if (new_align!=relocation->relocation_align2)
				internal_error_in_function ("relocate_short_branches_and_move_code");

			if (old_align!=new_align){
				while (mapping_symbol_p!=NULL && mapping_symbol_p->ms_data_offset<instruction_offset){
					mapping_symbol_p->ms_data_offset -= offset_difference;
					mapping_symbol_p=mapping_symbol_p->ms_next;
				}
				while (mapping_symbol_p!=NULL && mapping_symbol_p->ms_data_offset<=instruction_offset+old_align){
					mapping_symbol_p->ms_data_offset -= (offset_difference+old_align-new_align);
					mapping_symbol_p=mapping_symbol_p->ms_next;
				}
			}
			
			offset_difference+=old_align-new_align;

			source_buffer_offset+=old_align;
			source_offset+=old_align;

			if (source_buffer_offset>BUFFER_SIZE){
				source_buffer_offset-=BUFFER_SIZE;
				source_object_buffer=source_object_buffer->next;
			}

			if (new_align!=0){
				if (destination_buffer_offset==BUFFER_SIZE){
					destination_buffer_offset=0;
					destination_object_buffer=destination_object_buffer->next;
				}
				if (new_align==2){
					destination_object_buffer->data[destination_buffer_offset++]=0;
					destination_object_buffer->data[destination_buffer_offset++]=0xbf;
				} else
					internal_error_in_function ("relocate_short_branches_and_move_code");
			}
			continue;
		} else if (relocation->relocation_kind==BRANCH_SKIP_BRANCH_RELOCATION){
			unsigned char c0,c1;
			
			if (source_buffer_offset>=BUFFER_SIZE){
				source_buffer_offset-=BUFFER_SIZE;
				source_object_buffer=source_object_buffer->next;
			}
			if (destination_buffer_offset==BUFFER_SIZE){
				destination_buffer_offset=0;
				destination_object_buffer=destination_object_buffer->next;
			}

			c0=source_object_buffer->data[source_buffer_offset++];
			++source_offset;

			--c0; /* adjust branch offset */

			destination_object_buffer->data[destination_buffer_offset++]=c0;

			if (source_buffer_offset>=BUFFER_SIZE){
				source_buffer_offset-=BUFFER_SIZE;
				source_object_buffer=source_object_buffer->next;
			}
			if (destination_buffer_offset==BUFFER_SIZE){
				destination_buffer_offset=0;
				destination_object_buffer=destination_object_buffer->next;
			}

			c1=source_object_buffer->data[source_buffer_offset++];
			++source_offset;

			destination_object_buffer->data[destination_buffer_offset++]=c1;			
			continue;
		}

		if (source_buffer_offset>=BUFFER_SIZE){
			source_buffer_offset-=BUFFER_SIZE;
			source_object_buffer=source_object_buffer->next;
		}
	
		if (source_buffer_offset<=BUFFER_SIZE-4){
			instruction = *(LONG*)(source_object_buffer->data+source_buffer_offset);
		} else {
			unsigned char *p0,*p2,*end_buffer;
			
			p0=source_object_buffer->data+source_buffer_offset;
			end_buffer=source_object_buffer->data+BUFFER_SIZE;
			p2=p0+2;
			if (p2==end_buffer)
				p2=source_object_buffer->next->data;
		
			instruction = (p0[0]) | (p0[1]<<8) | (p2[0]<<16) | (p2[1]<<24);
		}

		while (mapping_symbol_p!=NULL && mapping_symbol_p->ms_data_offset<=instruction_offset){
			mapping_symbol_p->ms_data_offset -= offset_difference;
			mapping_symbol_p=mapping_symbol_p->ms_next;
		}

		source_buffer_offset+=4;
		source_offset+=4;

		if (source_buffer_offset>BUFFER_SIZE){
			source_buffer_offset-=BUFFER_SIZE;
			source_object_buffer=source_object_buffer->next;
		}
		
		if (destination_buffer_offset==BUFFER_SIZE){
			destination_buffer_offset=0;
			destination_object_buffer=destination_object_buffer->next;
		}

		switch (relocation->relocation_kind){
			case SHORT_BRANCH_RELOCATION:
				v=label->label_offset;
				v -= instruction_offset+4-offset_difference;
				if (v<-256 || v>254 || (instruction & 0xfffffc3f)!=0x8000f000)
					internal_error_in_function ("relocate_short_branches_and_move_code");
				branch_opcode = 0xd0 | ((instruction & 0x3c0)>>6);
				offset_difference+=2;
#if 0
				destination_object_buffer->data[destination_buffer_offset++]=v>>1;
#else
				destination_object_buffer->data[destination_buffer_offset++]=0;
#endif
				destination_object_buffer->data[destination_buffer_offset++]=branch_opcode;
				break;
			case SHORT_JUMP_RELOCATION:
			{
				int jump_instruction_offset;

				v=label->label_offset;
				v -= instruction_offset+4-offset_difference;

				if ((instruction & 0x3ff0000)!=0){
					jump_instruction_offset = (instruction>>16) & 0x3ff;
					if (instruction & 0x400)
						jump_instruction_offset = -jump_instruction_offset;
					v += jump_instruction_offset<<1;
				} else
					jump_instruction_offset = 0;

				if (v<-2048 || v>2046 || (instruction & 0xd000f800)!=0x9000f000)
					internal_error_in_function ("relocate_short_branches_and_move_code");
				branch_opcode = 0xe0;
				offset_difference+=2;
#if 0
				destination_object_buffer->data[destination_buffer_offset++]=v>>1;
#else
				destination_object_buffer->data[destination_buffer_offset++]=jump_instruction_offset;
#endif
				destination_object_buffer->data[destination_buffer_offset++]=branch_opcode | ((jump_instruction_offset>>8) & 7);
				break;
			}
			case SHORT_LDR_OFFSET_RELOCATION:
				v=label->label_offset;
				v -= ((instruction_offset-offset_difference) & -4)+4;
				if (v<0 || v>1020 || (instruction & 0x8fffffff)!=0x0000f8df)
					internal_error_in_function ("relocate_short_branches_and_move_code");
				branch_opcode = 0x48 | ((instruction & 0x70000000)>>28);
				offset_difference+=2;
#if 0
				destination_object_buffer->data[destination_buffer_offset++]=v>>1;
#else
				destination_object_buffer->data[destination_buffer_offset++]=0;
#endif
				destination_object_buffer->data[destination_buffer_offset++]=branch_opcode;
				break;
			case ADR_RELOCATION:
			{
				int reg;
				
				v=label->label_offset;
				v += relocation->relocation_literal_entry_p->le_offset;
				v -= ((instruction_offset-offset_difference) & -4)+4;
				if (v<-4092 || v>4092 || (instruction & 0x0fffffff)!=0x0000f8df)
					internal_error_in_function ("relocate_short_branches_and_move_code ADR_RELOCATION");

				reg = (instruction & 0xf0000000)>>28;
				
				instruction = 0xf20f0000 | (reg<<8); /* adr */

				destination_object_buffer->data[destination_buffer_offset++]=instruction>>16;
				destination_object_buffer->data[destination_buffer_offset++]=instruction>>24;
				if (destination_buffer_offset==BUFFER_SIZE){
					destination_buffer_offset=0;
					destination_object_buffer=destination_object_buffer->next;
				}
				destination_object_buffer->data[destination_buffer_offset++]=instruction;
				destination_object_buffer->data[destination_buffer_offset++]=instruction>>8;
				break;
			}
			case UNUSED_LONG_WORD_LITERAL_RELOCATION:				
				offset_difference+=4;
				relocation->relocation_mapping_symbol->ms_table_size -= 4;
				break;
			default:
				internal_error_in_function ("relocate_short_branches_and_move_code");
		}
	}

	while (source_offset!=code_buffer_offset){
		int n;
		
		n=code_buffer_offset-source_offset;
					
		if (source_buffer_offset==BUFFER_SIZE){
			source_object_buffer=source_object_buffer->next;
			source_buffer_offset=0;
		}
		
		if (BUFFER_SIZE-source_buffer_offset < n)
			n = BUFFER_SIZE-source_buffer_offset;
		
		if (destination_buffer_offset==BUFFER_SIZE){
			destination_object_buffer=destination_object_buffer->next;
			destination_buffer_offset=0;
		}			

		if (BUFFER_SIZE-destination_buffer_offset < n)
			n = BUFFER_SIZE-destination_buffer_offset;

		memmove (&destination_object_buffer->data[destination_buffer_offset],&source_object_buffer->data[source_buffer_offset],n);
		destination_buffer_offset+=n;
		source_buffer_offset+=n;
		source_offset+=n;
	}
	
	code_buffer_offset-=offset_difference;
	
	if (destination_object_buffer!=NULL){
		struct object_buffer *next_destination_object_buffer;
		
		destination_object_buffer->size=destination_buffer_offset;
		next_destination_object_buffer=destination_object_buffer->next;
		destination_object_buffer->next=NULL;
		
		while (next_destination_object_buffer!=NULL){
			destination_object_buffer=next_destination_object_buffer;
			next_destination_object_buffer=next_destination_object_buffer->next;
			
			memory_free (destination_object_buffer);
		}
	}

	while (mapping_symbol_p!=NULL){
		mapping_symbol_p->ms_data_offset -= offset_difference;
		mapping_symbol_p=mapping_symbol_p->ms_next;
	}

	end_code_offset -= offset_difference;
}

static void optimise_branches (void)
{
	int n;
	
	for (n=0; n<3; ++n){
		if (!search_short_branches())
			break;
		
		adjust_label_offsets();
	}
	
	relocate_short_branches_and_move_code();
}
#endif

static void relocate_code (void)
{
	struct relocation *relocation,**relocation_p;
	struct object_buffer *object_buffer;
	int code_buffer_offset;
	struct label *label;
	int instruction_offset;
	LONG v;

	object_buffer=first_code_buffer;
	code_buffer_offset=0;
	
	relocation_p=&first_code_relocation;
	
	while ((relocation=*relocation_p)!=NULL){
		switch (relocation->relocation_kind){
			case BRANCH_RELOCATION:
				label=relocation->relocation_label;
				if (label->label_id==TEXT_LABEL_ID){
					instruction_offset=relocation->relocation_offset;

#ifdef FUNCTION_LEVEL_LINKING
					if (label->label_object_label!=relocation->relocation_object_label){
						v=label->label_offset-label->label_object_label->object_label_offset;

						v-=4;

						++n_code_relocations;
						relocation_p=&relocation->next;
					} else
#endif
					{
						v=label->label_offset-(instruction_offset+4);
						*relocation_p=relocation->next;
					}
				} else {
					++n_code_relocations;
					relocation_p=&relocation->next;

					instruction_offset=relocation->relocation_offset;
					v= -4;
				}

				while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					code_buffer_offset+=BUFFER_SIZE;
				}
				
				if (instruction_offset-code_buffer_offset<=BUFFER_SIZE-4){
					LONG *instruction_p;
					
					instruction_p=(LONG*)(object_buffer->data+(instruction_offset-code_buffer_offset));

					v >>= 1;
					
					*instruction_p = (*instruction_p & 0xd000fbc0)
									| ((v & 0x007ff)<<16)
									| ((v & 0x1f800)>>11)
									| ((v & 0x20000)<<(16+13-17))
									| ((v & 0x40000)<<(16+11-18))
									| ((v & 0x80000)>>(19-10));
				} else {
					unsigned char *p0,*p1,*p2,*p3,*end_buffer;
					LONG i;
					
					p0=object_buffer->data+(instruction_offset-code_buffer_offset);
					end_buffer=object_buffer->data+BUFFER_SIZE;
					p1=p0+1;
					if (p1==end_buffer)
						p1=object_buffer->next->data;
					p2=p1+1;
					if (p2==end_buffer)
						p2=object_buffer->next->data;
					p3=p2+1;
					if (p3==end_buffer)
						p3=object_buffer->next->data;

					v >>= 1;
					i = *p0 | (*p1<<8) | (*p2<<16) | (*p3<<24);
					
					i = (i & 0xd000fbc0)
						| ((v & 0x007ff)<<16)
						| ((v & 0x1f800)>>11)
						| ((v & 0x20000)<<(16+13-17))
						| ((v & 0x40000)<<(16+11-18))
						| ((v & 0x80000)>>(19-10));
	
					*p0=i;
					*p1=i>>8;
					*p2=i>>16;
					*p3=i>>24;
				}

				continue;
			case SHORT_BRANCH_RELOCATION:
				label=relocation->relocation_label;
				if (label->label_id==TEXT_LABEL_ID){
					instruction_offset=relocation->relocation_offset;

#ifdef FUNCTION_LEVEL_LINKING
					if (label->label_object_label!=relocation->relocation_object_label){
						v=label->label_offset-label->label_object_label->object_label_offset;

						v-=4;

						++n_code_relocations;
						relocation_p=&relocation->next;
					} else
#endif
					{
						v=label->label_offset-(instruction_offset+4);
						*relocation_p=relocation->next;
					}
				} else {
					++n_code_relocations;
					relocation_p=&relocation->next;

					instruction_offset=relocation->relocation_offset;
					v= -4;
				}

				while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					code_buffer_offset+=BUFFER_SIZE;
				}
				
				{
					char *instruction_p;
					
					instruction_p=(char*)(object_buffer->data+(instruction_offset-code_buffer_offset));
					*instruction_p += v>>1;
				}
				continue;
			case CALL_RELOCATION:
			case JUMP_RELOCATION:
			case LONG_JUMP_RELOCATION:
				label=relocation->relocation_label;
				if (label->label_id==TEXT_LABEL_ID){
					instruction_offset=relocation->relocation_offset;

#ifdef FUNCTION_LEVEL_LINKING
					if (label->label_object_label!=relocation->relocation_object_label){
						v=label->label_offset-label->label_object_label->object_label_offset;

						v-=4;

						++n_code_relocations;
						relocation_p=&relocation->next;
					} else
#endif
					{
						v=label->label_offset-(instruction_offset+4);
						*relocation_p=relocation->next;
					}
				} else {
					++n_code_relocations;
					relocation_p=&relocation->next;

					instruction_offset=relocation->relocation_offset;
					v= -4;
				}

				while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					code_buffer_offset+=BUFFER_SIZE;
				}
				
				if (instruction_offset-code_buffer_offset<=BUFFER_SIZE-4){
					LONG *instruction_p,i;
					
					instruction_p=(LONG*)(object_buffer->data+(instruction_offset-code_buffer_offset));

					i = *instruction_p;
					v >>= 1;
					/* only imm11 and s used */
					if ((i & 0x3ff0000)!=0){
						if (i & 0x400)
							v -= (i>>16) & 0x3ff;
						else
							v += (i>>16) & 0x3ff;
					}
					
					i = (i & 0xd000f800) | ((v & 0x7ff)<<16) | ((v & 0x1ff800)>>11);
					if ((v & 0x800000)==0)
						i = i | (((~v) & 0x200000)<<(16+13-21)) | (((~v) & 0x400000)<<(16+11-22));
					else
						i = i | ((v & 0x200000)<<(16+13-21)) | ((v & 0x400000)<<(16+11-22)) | (0x800000>>(23-10));
					*instruction_p = i;
				} else {
					unsigned char *p0,*p1,*p2,*p3,*end_buffer;
					LONG i;
					
					p0=object_buffer->data+(instruction_offset-code_buffer_offset);
					end_buffer=object_buffer->data+BUFFER_SIZE;
					p1=p0+1;
					if (p1==end_buffer)
						p1=object_buffer->next->data;
					p2=p1+1;
					if (p2==end_buffer)
						p2=object_buffer->next->data;
					p3=p2+1;
					if (p3==end_buffer)
						p3=object_buffer->next->data;

					i = *p0 | (*p1<<8) | (*p2<<16) | (*p3<<24);
					v >>= 1;
					/* only imm11 and s used */
					if ((i & 0x3ff0000)!=0){
						if (i & 0x400)
							v -= (i>>16) & 0x3ff;
						else
							v += (i>>16) & 0x3ff;
					}

					i = (i & 0xd000f800) | ((v & 0x7ff)<<16) | ((v & 0x1ff800)>>11);
					if ((v & 0x800000)==0)
						i = i | (((~v) & 0x200000)<<(16+13-21)) | (((~v) & 0x400000)<<(16+11-22));
					else
						i = i | ((v & 0x200000)<<(16+13-21)) | ((v & 0x400000)<<(16+11-22)) | (0x800000>>(23-10));
										
					*p0=i;
					*p1=i>>8;
					*p2=i>>16;
					*p3=i>>24;
				}

				continue;
#ifdef OPTIMISE_BRANCHES
			case SHORT_JUMP_RELOCATION:
				label=relocation->relocation_label;
				if (label->label_id==TEXT_LABEL_ID){
					instruction_offset=relocation->relocation_offset;

# ifdef FUNCTION_LEVEL_LINKING
					if (label->label_object_label!=relocation->relocation_object_label){
						v=label->label_offset-label->label_object_label->object_label_offset;

						v-=4;

						++n_code_relocations;
						relocation_p=&relocation->next;
					} else
# endif
					{
						v=label->label_offset-(instruction_offset+4);
						*relocation_p=relocation->next;
					}
				} else {
					++n_code_relocations;
					relocation_p=&relocation->next;

					instruction_offset=relocation->relocation_offset;
					v= -4;
				}

				while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					code_buffer_offset+=BUFFER_SIZE;
				}
				
				{				
					unsigned short *instruction_p,instruction;
					
					instruction_p=(unsigned short*)(object_buffer->data+(instruction_offset-code_buffer_offset));

					instruction = *instruction_p;
					v >>= 1;
					
					*instruction_p = (instruction & 0xfffff800) | ((instruction+v) & 0x7ff);
				}
				continue;
#endif
			case LDR_OFFSET_RELOCATION:
			case LONG_LDR_OFFSET_RELOCATION:
				label=&relocation->relocation_literal_entry_p->le_load_instruction_label;
				if (label->label_id==TEXT_LABEL_ID){
					instruction_offset=relocation->relocation_offset;

#ifdef FUNCTION_LEVEL_LINKING
					if (label->label_object_label!=relocation->relocation_object_label){
						v=label->label_offset-label->label_object_label->object_label_offset;

						v-=4;

						++n_code_relocations;
						relocation_p=&relocation->next;
					} else
#endif
					{
						v=label->label_offset-((instruction_offset & -4)+4);
						*relocation_p=relocation->next;
					}
				} else {
					++n_code_relocations;
					relocation_p=&relocation->next;

					instruction_offset=relocation->relocation_offset;
					v= -4;
				}

				while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					code_buffer_offset+=BUFFER_SIZE;
				}

				/* offset in instruction ignored (always 0) */
				
				if (instruction_offset-code_buffer_offset<=BUFFER_SIZE-4){
					LONG *instruction_p;
					
					instruction_p=(LONG*)(object_buffer->data+(instruction_offset-code_buffer_offset));
					if (v>=0)
						*instruction_p = (*instruction_p & 0xf000ffff) | ((v & 0x00000fff)<<16);
					else
						*instruction_p = (*instruction_p & 0xf000ff7f) | (((-v) & 0x00000fff)<<16); /* clear add bit (23) */
				} else {
					unsigned char *p0,*p1,*p2,*p3,*end_buffer;
					
					p0=object_buffer->data+(instruction_offset-code_buffer_offset);
					end_buffer=object_buffer->data+BUFFER_SIZE;
					p1=p0+1;
					if (p1==end_buffer)
						p1=object_buffer->next->data;
					p2=p1+1;
					if (p2==end_buffer)
						p2=object_buffer->next->data;
					p3=p2+1;
					if (p3==end_buffer)
						p3=object_buffer->next->data;
					
					if (v<0){
						v = -v;
						*p0 &= 0x7f; /* clear add bit (23) */
					}
					*p2 = v;
					*p3 = (*p3) | ((v>>8) & 0xf);
				}
				continue;
#ifdef OPTIMISE_BRANCHES
			case SHORT_LDR_OFFSET_RELOCATION:
				label=&relocation->relocation_literal_entry_p->le_load_instruction_label;
				if (label->label_id==TEXT_LABEL_ID){
					instruction_offset=relocation->relocation_offset;

# ifdef FUNCTION_LEVEL_LINKING
					if (label->label_object_label!=relocation->relocation_object_label){
						v=label->label_offset-label->label_object_label->object_label_offset;

						v-=4;

						++n_code_relocations;
						relocation_p=&relocation->next;
					} else
# endif
					{
						v=label->label_offset-((instruction_offset & -4)+4);
						*relocation_p=relocation->next;
					}
				} else {
					++n_code_relocations;
					relocation_p=&relocation->next;

					instruction_offset=relocation->relocation_offset;
					v= -4;
				}

				while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					code_buffer_offset+=BUFFER_SIZE;
				}
				
				/* offset in instruction ignored (always 0) */

				{
					char *instruction_p;
					
					instruction_p=(char*)(object_buffer->data+(instruction_offset-code_buffer_offset));
					*instruction_p = v>>2;
				}
				continue;
#endif
			case VLDR_OFFSET_RELOCATION:
				label=&relocation->relocation_literal_entry_p->le_load_instruction_label;
				instruction_offset=relocation->relocation_offset;

				if ((instruction_offset & 2)==0){
					if (label->label_id==TEXT_LABEL_ID){
#ifdef FUNCTION_LEVEL_LINKING
						if (label->label_object_label!=relocation->relocation_object_label){
							v=label->label_offset-label->label_object_label->object_label_offset;

							v-=4;

							++n_code_relocations;
							relocation_p=&relocation->next;
						} else
#endif
						{
							v=label->label_offset-(instruction_offset+4);
							*relocation_p=relocation->next;
						}
					} else {
						++n_code_relocations;
						relocation_p=&relocation->next;
						v= -4;
					}
				} else {
					if (label->label_id==TEXT_LABEL_ID){
#ifdef FUNCTION_LEVEL_LINKING
						if (label->label_object_label!=relocation->relocation_object_label){
							v=label->label_offset-label->label_object_label->object_label_offset;

							/* v-=0; */

							++n_code_relocations;
							relocation_p=&relocation->next;
						} else
#endif
						{
							v=label->label_offset-(instruction_offset+2);
							*relocation_p=relocation->next;
						}
					} else {
						++n_code_relocations;
						relocation_p=&relocation->next;
						v=0;
					}
				}

				while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					code_buffer_offset+=BUFFER_SIZE;
				}
				
				/* offset in instruction ignored (always 0) */

				{
					unsigned char *p0,*p1,*p2,*end_buffer;
					
					p0=object_buffer->data+(instruction_offset-code_buffer_offset);
					end_buffer=object_buffer->data+BUFFER_SIZE;
					p1=p0+1;
					if (p1==end_buffer)
						p1=object_buffer->next->data;
					p2=p1+1;
					if (p2==end_buffer)
						p2=object_buffer->next->data;
					
					*p2 = (v>>2);
				}

				continue;
			case LONG_WORD_RELOCATION:
				label=relocation->relocation_label;
				relocation_p=&relocation->next;
				
				if (label->label_id==TEXT_LABEL_ID){
					instruction_offset=relocation->relocation_offset;
					v=label->label_offset;
#ifdef FUNCTION_LEVEL_LINKING
					v -= label->label_object_label->object_label_offset;
#endif
					v += 1; /* thumb instruction address */
					break;
				} else if (label->label_id==DATA_LABEL_ID
#if defined (RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL) && defined (FUNCTION_LEVEL_LINKING)
					&& !((label->label_flags & EXPORT_LABEL) && label->label_object_label->object_label_kind==EXPORTED_DATA_LABEL)
#endif
					)
				{
					instruction_offset=relocation->relocation_offset;
					v=label->label_offset;
#ifdef FUNCTION_LEVEL_LINKING
					v -= label->label_object_label->object_label_offset;
#endif
					break;
				} else
					continue;
#ifdef OPTIMISE_BRANCHES
			case LONG_WORD_LITERAL_RELOCATION:
				label=relocation->relocation_literal_entry_p->le_label;
				relocation_p=&relocation->next;
				
				if (label->label_id==TEXT_LABEL_ID){
					instruction_offset=relocation->relocation_offset;
					v=label->label_offset;
# ifdef FUNCTION_LEVEL_LINKING
					v -= label->label_object_label->object_label_offset;
# endif
					v += 1; /* thumb instruction address */
					break;
				} else if (label->label_id==DATA_LABEL_ID
# if defined (RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL) && defined (FUNCTION_LEVEL_LINKING)
					&& !((label->label_flags & EXPORT_LABEL) && label->label_object_label->object_label_kind==EXPORTED_DATA_LABEL)
# endif
					)
				{
					instruction_offset=relocation->relocation_offset;
					v=label->label_offset;
# ifdef FUNCTION_LEVEL_LINKING
					v -= label->label_object_label->object_label_offset;
# endif
					break;
				} else
					continue;
			case UNUSED_LONG_WORD_LITERAL_RELOCATION:
				--n_code_relocations;
				*relocation_p=relocation->next;
				continue;
#endif
			case RELATIVE_LONG_WORD_RELOCATION:
				label=relocation->relocation_label;
				relocation_p=&relocation->next;
				
				if (label->label_id==TEXT_LABEL_ID || (label->label_id==DATA_LABEL_ID
#if defined (RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL) && defined (FUNCTION_LEVEL_LINKING)
					&& !((label->label_flags & EXPORT_LABEL) && label->label_object_label->object_label_kind==EXPORTED_DATA_LABEL)
#endif
					))
				{
					instruction_offset=relocation->relocation_offset;
					v=label->label_offset;
#ifdef FUNCTION_LEVEL_LINKING
					v -= label->label_object_label->object_label_offset;
#endif
					break;
				} else
					continue;
#ifdef OPTIMISE_BRANCHES
			case ADR_RELOCATION:
				label=relocation->relocation_literal_entry_p->le_label;
				if (label->label_id==TEXT_LABEL_ID){
					instruction_offset=relocation->relocation_offset;

					v=label->label_offset+relocation->relocation_literal_entry_p->le_offset;

/*					printf ("ADR_RELOCATION %ld %ld\n",v,(long)relocation->relocation_literal_entry_p->le_offset); */

#ifdef FUNCTION_LEVEL_LINKING
					if (label->label_object_label!=relocation->relocation_object_label){
						v -= label->label_object_label->object_label_offset;
						v -= 4;

						++n_code_relocations;
						relocation_p=&relocation->next;
					} else
#endif
					{
						v -= (instruction_offset & -4)+4;
						*relocation_p=relocation->next;
					}
					
					v |= 1;
				} else {
					++n_code_relocations;
					relocation_p=&relocation->next;

					instruction_offset=relocation->relocation_offset;
					v = -4;
				}
				
/*				printf ("ADR_RELOCATION %ld\n",v); */

				while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					code_buffer_offset+=BUFFER_SIZE;
				}

				/* offset in instruction ignored (always 0) */
				
				if (instruction_offset-code_buffer_offset<=BUFFER_SIZE-4){
					LONG *instruction_p;
					
					instruction_p=(LONG*)(object_buffer->data+(instruction_offset-code_buffer_offset));
					if (v>=0)
						*instruction_p = (*instruction_p & 0x8f00fbff) | ((v & 0x800)>>(11-10)) | ((v & 0x700)<<(28-8)) | ((v & 0xff)<<16);
					else {
						v = -v;
						*instruction_p = (*instruction_p & 0x8f00fb5f) | 0xa0 | ((v & 0x800)>>(11-10)) | ((v & 0x700)<<(28-8)) | ((v & 0xff)<<16); /* set bits 21 and 23 */
					}
				} else {
					unsigned char *p0,*p1,*p2,*p3,*end_buffer;
					
					p0=object_buffer->data+(instruction_offset-code_buffer_offset);
					end_buffer=object_buffer->data+BUFFER_SIZE;
					p1=p0+1;
					if (p1==end_buffer)
						p1=object_buffer->next->data;
					p2=p1+1;
					if (p2==end_buffer)
						p2=object_buffer->next->data;
					p3=p2+1;
					if (p3==end_buffer)
						p3=object_buffer->next->data;
					
					if (v<0){
						v = -v;
						*p0 |= 0xa0; /* set bits 21 and 23 */
					}
					*p1 = (*p1 & 0xfb) | ((v & 0x800)>>(11-2));
					*p2 = v;
					*p3 = (*p3 & 0x8f) | ((v & 0x700)>>(8-4));
				}
				continue;
#endif
			case MOVW_RELOCATION:
			case MOVT_RELOCATION:
				label=relocation->relocation_label;
				relocation_p=&relocation->next;
				/* offset in instruction ignored (always 0) */
				continue;
			case ADJUST_ADR_RELOCATION:
				label=relocation->relocation_label;
				instruction_offset=relocation->relocation_offset;
				if (instruction_offset & 2){
					unsigned char *p0;

					while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
						object_buffer=object_buffer->next;
						code_buffer_offset+=BUFFER_SIZE;
					}

					p0=object_buffer->data+(instruction_offset-code_buffer_offset);
					if (instruction_offset-code_buffer_offset<=BUFFER_SIZE-4)
						p0[2] += 2;
					else {
						unsigned char *p1,*p2,*end_buffer;
						
						end_buffer=object_buffer->data+BUFFER_SIZE;
						p1=p0+1;
						if (p1==end_buffer)
							p1=object_buffer->next->data;
						p2=p1+1;
						if (p2==end_buffer)
							p2=object_buffer->next->data;
						*p2 += 2;
					}				
				}
				
				*relocation_p=relocation->next;
				continue;
#ifdef FUNCTION_LEVEL_LINKING
			case DUMMY_BRANCH_RELOCATION:
				label=relocation->relocation_label;
				if (label->label_id==TEXT_LABEL_ID){
					if (label->label_object_label!=relocation->relocation_object_label){
						++n_code_relocations;
						relocation_p=&relocation->next;
						continue;
					}
					*relocation_p=relocation->next;
					continue;
				} else {
					internal_error_in_function ("relocate_code");
					*relocation_p=relocation->next;
				}
#endif
			default:
				internal_error_in_function ("relocate_code");
		}

		while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
			object_buffer=object_buffer->next;
			code_buffer_offset+=BUFFER_SIZE;
		}
		
		if (instruction_offset-code_buffer_offset<=BUFFER_SIZE-4){
			LONG *instruction_p;
			
			instruction_p=(LONG*)(object_buffer->data+(instruction_offset-code_buffer_offset));
			*instruction_p += v;
		} else {
			unsigned char *p0,*p1,*p2,*p3,*end_buffer;
			
			p0=object_buffer->data+(instruction_offset-code_buffer_offset);
			end_buffer=object_buffer->data+BUFFER_SIZE;
			p1=p0+1;
			if (p1==end_buffer)
				p1=object_buffer->next->data;
			p2=p1+1;
			if (p2==end_buffer)
				p2=object_buffer->next->data;
			p3=p2+1;
			if (p3==end_buffer)
				p3=object_buffer->next->data;
		
			v+= (*p0) | (*p1<<8) | (*p2<<16) | (*p3<<24);
			
			*p0=v;
			*p1=v>>8;
			*p2=v>>16;
			*p3=v>>24;
		}
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

		if (relocation->relocation_kind==LONG_WORD_RELOCATION){
			int v,data_offset;
			
			if (label->label_id==TEXT_LABEL_ID){
				v = label->label_offset;
#ifdef FUNCTION_LEVEL_LINKING
				v -= label->label_object_label->object_label_offset;
#endif
				v += 1; /* thumb instruction address */
			} else if (label->label_id==DATA_LABEL_ID
#if defined (RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL) && defined (FUNCTION_LEVEL_LINKING)
				&& !((label->label_flags & EXPORT_LABEL) && label->label_object_label->object_label_kind==EXPORTED_DATA_LABEL)
#endif
				)
			{
				v = label->label_offset;
#ifdef FUNCTION_LEVEL_LINKING
				v -= label->label_object_label->object_label_offset;
#endif
			} else
				continue;
			
			data_offset=relocation->relocation_offset;
			while (data_offset >= data_buffer_offset+BUFFER_SIZE){
				object_buffer=object_buffer->next;
				data_buffer_offset+=BUFFER_SIZE;
			}

			if (data_offset-data_buffer_offset<=BUFFER_SIZE-4){
				LONG *data_p;
				
				data_p=(LONG*)(object_buffer->data+(data_offset-data_buffer_offset));
				*data_p += v;
			} else {
				unsigned char *p0,*p1,*p2,*p3,*end_buffer;
				
				p0=object_buffer->data+(data_offset-data_buffer_offset);
				end_buffer=object_buffer->data+BUFFER_SIZE;
				p1=p0+1;
				if (p1==end_buffer)
					p1=object_buffer->next->data;
				p2=p1+1;
				if (p2==end_buffer)
					p2=object_buffer->next->data;
				p3=p2+1;
				if (p3==end_buffer)
					p3=object_buffer->next->data;
			
				v+= (*p0) | (*p1<<8) | (*p2<<16) | (*p3<<24);
				
				*p0=v;
				*p1=v>>8;
				*p2=v>>16;
				*p3=v>>24;
			}
		}
	}
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
#ifndef ELF
		if (string_length<8)
			new_object_label->object_label_string_offset=0;
		else
#endif
		{
			new_object_label->object_label_string_offset=string_table_offset;
			string_table_offset+=string_length+1;
		}

		new_object_label->object_label_kind=IMPORTED_LABEL;
	}
	
	as_import_labels (label_node->label_node_left);
	as_import_labels (label_node->label_node_right);
}

#define C_EXT 2
#define C_STAT 3

static void write_object_labels (void)
{
	struct object_label *object_label;
#if defined (RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL) && defined (FUNCTION_LEVEL_LINKING)
	struct object_label *current_text_or_data_object_label;

	current_text_or_data_object_label=NULL;
#endif

#ifdef ELF
	write_l (0);
	write_l (0);
	write_l (0);
	write_l (0);
# ifndef FUNCTION_LEVEL_LINKING
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
# else
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

		/* $t and $d symbols */
		section_n=0;
		{
			int n_generated_mapping_symbols;
			struct mapping_symbol *mapping_symbol_p;

			n_generated_mapping_symbols=0;

			mapping_symbol_p=first_mapping_symbol;
			while (mapping_symbol_p!=NULL && mapping_symbol_p->ms_table_size==0)
				mapping_symbol_p=mapping_symbol_p->ms_next;

			object_label=first_object_label;
			while (object_label!=NULL && object_label->object_label_kind!=CODE_CONTROL_SECTION)
				object_label=object_label->next;

			while (object_label!=NULL){
				struct object_label *previous_object_label;
				unsigned long current_control_section_code_offset,next_control_section_code_offset;
				
				current_control_section_code_offset=object_label->object_label_offset;
				previous_object_label=object_label;

				object_label=object_label->next;
				while (object_label!=NULL && object_label->object_label_kind!=CODE_CONTROL_SECTION)
					object_label=object_label->next;

				if (object_label!=NULL)
					next_control_section_code_offset = object_label->object_label_offset;	
				else
					next_control_section_code_offset = end_code_offset;

				if (mapping_symbol_p==NULL || mapping_symbol_p->ms_data_offset!=current_control_section_code_offset){
					write_l (1); /* $t */
					write_l (0);
					write_l (0);
					write_c (ELF32_ST_INFO (STB_LOCAL,STT_NOTYPE));
					write_c (0);
					write_w (2+section_n);
					++n_generated_mapping_symbols;
				}

				while (mapping_symbol_p!=NULL && mapping_symbol_p->ms_data_offset<next_control_section_code_offset){
					write_l (4); /* $d */
					write_l (mapping_symbol_p->ms_data_offset-current_control_section_code_offset);
					write_l (0);
					write_c (ELF32_ST_INFO (STB_LOCAL,STT_NOTYPE));
					write_c (0);
					write_w (2+section_n);					
					++n_generated_mapping_symbols;

					if (mapping_symbol_p->ms_data_offset + mapping_symbol_p->ms_table_size!=next_control_section_code_offset){
						write_l (1); /* $t */
						write_l (mapping_symbol_p->ms_data_offset + mapping_symbol_p->ms_table_size - current_control_section_code_offset);
						write_l (0);
						write_c (ELF32_ST_INFO (STB_LOCAL,STT_NOTYPE));
						write_c (0);
						write_w (2+section_n);
						++n_generated_mapping_symbols;
					}
					
					mapping_symbol_p=mapping_symbol_p->ms_next;
					while (mapping_symbol_p!=NULL && mapping_symbol_p->ms_table_size==0)
						mapping_symbol_p=mapping_symbol_p->ms_next;
				}
				++section_n;				
			}

			if (section_n!=n_code_sections || n_generated_mapping_symbols!=n_mapping_symbols){
/*
				printf ("section_n: %d n_code_sections: %d n_generated_mapping_symbols: %d n_mapping_symbols: %d\n",
					section_n,n_code_sections,n_generated_mapping_symbols,n_mapping_symbols);
*/
				internal_error_in_function ("write_object_labels");
			}
		}		
	}
# endif
#endif

	for_l (object_label,first_object_label,next){
		switch (object_label->object_label_kind){
			case CODE_CONTROL_SECTION:
			{
#ifndef ELF
				write_string_8 (".text");
				
# ifdef FUNCTION_LEVEL_LINKING
				write_l (0);
				write_w (1+object_label->object_label_section_n);
# else
				write_l (object_label->object_label_offset);
				write_w (1);
# endif
				write_w (0);
				write_c (C_STAT);
				write_c (1);
				
				write_l (object_label->object_label_length);
# ifdef FUNCTION_LEVEL_LINKING
				write_w (object_label->object_label_n_relocations);
# else
				write_w (n_code_relocations);
# endif
				write_w (0);
				write_l (0);
				write_l (0);
				write_w (0);
#endif
				break;
			}
			case DATA_CONTROL_SECTION:
			{
#if defined (RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL) && defined (FUNCTION_LEVEL_LINKING)
				current_text_or_data_object_label=object_label;
#endif
#ifndef ELF
				write_string_8 (".data");
				
# ifdef FUNCTION_LEVEL_LINKING
				write_l (0);
				write_w (1+n_code_sections+object_label->object_label_section_n);
# else
				write_l (object_label->object_label_offset);
				write_w (2);
# endif
				write_w (0);
				write_c (C_STAT);
				write_c (1);
				
				write_l (object_label->object_label_length);
# ifdef FUNCTION_LEVEL_LINKING
				write_w (object_label->object_label_n_relocations);
# else
				write_w (n_data_relocations);
# endif
				write_w (0);
				write_l (0);
				write_l (0);
				write_w (0);
#endif
				break;
			}
			case IMPORTED_LABEL:
			{
				struct label *label;
				
				label=object_label->object_label_label;

				write_l (object_label->object_label_string_offset);
				write_l (0);
				write_l (0);
				write_c (ELF32_ST_INFO (STB_GLOBAL,STT_NOTYPE));
				write_c (0);
				write_w (0);
				break;
			}
			case EXPORTED_CODE_LABEL:
			{
				struct label *label;
				
				label=object_label->object_label_label;

				write_l (object_label->object_label_string_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_l ((label->label_offset - label->label_object_label->object_label_offset) | 1);
#else
				write_l (label->label_offset | 1);
#endif
				write_l (0);
				write_c (ELF32_ST_INFO (STB_GLOBAL,STT_FUNC));
				write_c (label->label_flags & C_ENTRY_LABEL ? STV_DEFAULT : STV_HIDDEN);
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
				write_c (label->label_flags & C_ENTRY_LABEL ? STV_DEFAULT : STV_HIDDEN);
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

#ifdef ELF
	write_c (0);
# ifndef FUNCTION_LEVEL_LINKING
	write_zstring (".text");
	write_zstring (".data");
# else
	write_zstring ("$t");
	write_zstring ("$d");
# endif
#else
	if (string_table_offset==4)
		return;
	
	write_l (string_table_offset);
#endif	
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

#define R_DIR32 6

#if defined (ELF) && defined (FUNCTION_LEVEL_LINKING)
static int elf_label_number (struct label *label)
{
	int label_n;
					
	label_n=label->label_id;
	if (label_n==TEXT_LABEL_ID){
		label_n=label->label_object_label->object_label_number;
		if (label_n==0)
			return 1+label->label_object_label->object_label_section_n;
		else
			return label_n+n_local_section_and_mapping_symbols;
	} else if (label_n==DATA_LABEL_ID){
		label_n=label->label_object_label->object_label_number;
		if (label_n==0)
			return 1+n_code_sections+label->label_object_label->object_label_section_n;
		else
			return label_n+n_local_section_and_mapping_symbols;
	} else
			return label_n+n_local_section_and_mapping_symbols;
}
#endif

static void write_code_relocations (void)
{
	struct relocation *relocation;

	for_l (relocation,first_code_relocation,next){
		switch (relocation->relocation_kind){
			case BRANCH_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
#else
				if (label->label_id<0)
#endif
					internal_error_in_function ("write_code_relocations");

				write_l (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_ARM_THM_JUMP19));
#else
				write_l (ELF32_R_INFO (label->label_id,R_ARM_THM_JUMP19));
#endif
				break;
			}
			case JUMP_RELOCATION:
			case LONG_JUMP_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
#else
				if (label->label_id<0)
#endif
					internal_error_in_function ("write_code_relocations");

				write_l (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_ARM_THM_JUMP24));
#else
				write_l (ELF32_R_INFO (label->label_id,R_ARM_THM_JUMP24));
#endif
				break;
			}
#ifdef OPTIMISE_BRANCHES
			case SHORT_JUMP_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
# ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
# else
				if (label->label_id<0)
# endif
					internal_error_in_function ("write_code_relocations");

				write_l (relocation->relocation_offset);
# ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_ARM_THM_JUMP11));
# else
				write_l (ELF32_R_INFO (label->label_id,R_ARM_THM_JUMP11));
# endif
				break;
			}
#endif
			case CALL_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
#else
				if (label->label_id<0)
#endif
					internal_error_in_function ("write_code_relocations");

				write_l (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_ARM_THM_CALL));
#else
				write_l (ELF32_R_INFO (label->label_id,R_ARM_THM_CALL));
#endif
				break;
			}
			case SHORT_BRANCH_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
#else
				if (label->label_id<0)
#endif
					internal_error_in_function ("write_code_relocations");

				write_l (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_ARM_THM_JUMP8));
#else
				write_l (ELF32_R_INFO (label->label_id,R_ARM_THM_JUMP8));
#endif
				break;
			}
			case LDR_OFFSET_RELOCATION:
			case LONG_LDR_OFFSET_RELOCATION:
			{
				struct label *label;

				label=&relocation->relocation_literal_entry_p->le_load_instruction_label;
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
#else
				if (label->label_id<0)
#endif
					internal_error_in_function ("write_code_relocations");

				write_l (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_ARM_THM_PC12));
#else
				write_l (ELF32_R_INFO (label->label_id,R_ARM_THM_PC12));
#endif
				break;				
			}
#ifdef OPTIMISE_BRANCHES
			case SHORT_LDR_OFFSET_RELOCATION:
			{
				struct label *label;
		
				label=&relocation->relocation_literal_entry_p->le_load_instruction_label;
# ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
# else
				if (label->label_id<0)
# endif
					internal_error_in_function ("write_code_relocations");

				write_l (relocation->relocation_offset);
# ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_ARM_THM_PC8));
# else
				write_l (ELF32_R_INFO (label->label_id,R_ARM_THM_PC8));
# endif
				break;
			}
#endif
			case VLDR_OFFSET_RELOCATION:
			{
				struct label *label;
		
				label=&relocation->relocation_literal_entry_p->le_load_instruction_label;
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
#else
				if (label->label_id<0)
#endif
					internal_error_in_function ("write_code_relocations");

				/* add 2, because R_ARM_THM_PC8 is for 16 bit thumb instructions */
				write_l (relocation->relocation_offset + 2);
#ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_ARM_THM_PC8));
#else
				write_l (ELF32_R_INFO (label->label_id,R_ARM_THM_PC8));
#endif
				break;				
			}
			case LONG_WORD_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
#else
				if (label->label_id<0)
#endif
					internal_error_in_function ("write_code_relocations");

				write_l (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_ARM_ABS32));
#else
				write_l (ELF32_R_INFO (label->label_id,R_ARM_ABS32));
#endif
				break;				
			}
#ifdef OPTIMISE_BRANCHES
			case LONG_WORD_LITERAL_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_literal_entry_p->le_label;
# ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
# else
				if (label->label_id<0)
# endif
					internal_error_in_function ("write_code_relocations");

				write_l (relocation->relocation_offset);
# ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_ARM_ABS32));
# else
				write_l (ELF32_R_INFO (label->label_id,R_ARM_ABS32));
# endif
				break;				
			}
#endif
			case RELATIVE_LONG_WORD_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
#else
				if (label->label_id<0)
#endif
					internal_error_in_function ("write_code_relocations");

				write_l (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_ARM_REL32));
#else
				write_l (ELF32_R_INFO (label->label_id,R_ARM_REL32));
#endif
				break;				
			}
			case MOVW_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
#else
				if (label->label_id<0)
#endif
					internal_error_in_function ("write_code_relocations");

				write_l (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_ARM_THM_MOVW_ABS_NC));
#else
				write_l (ELF32_R_INFO (label->label_id,R_ARM_THM_MOVW_ABS_NC));
#endif
				break;				
			}
			case MOVT_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
#else
				if (label->label_id<0)
#endif
					internal_error_in_function ("write_code_relocations");

				write_l (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_ARM_THM_MOVT_ABS));
#else
				write_l (ELF32_R_INFO (label->label_id,R_ARM_THM_MOVT_ABS));
#endif
				break;				
			}
#ifdef OPTIMISE_BRANCHES
			case ADR_RELOCATION:
			{
				struct label *label;

				label=relocation->relocation_literal_entry_p->le_label;
# ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
# else
				if (label->label_id<0)
# endif
					internal_error_in_function ("write_code_relocations");

				write_l (relocation->relocation_offset);
# ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_ARM_THM_ALU_PREL_11_0));
# else
				write_l (ELF32_R_INFO (label->label_id,R_ARM_THM_ALU_PREL_11_0));
# endif
				break;				
			}
#endif
#ifdef FUNCTION_LEVEL_LINKING
			case DUMMY_BRANCH_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
				if (label->label_id==-1)
					internal_error_in_function ("write_code_relocations");

				write_l (relocation->relocation_offset - 4);
				write_l (ELF32_R_INFO (elf_label_number (label),R_ARM_NONE));
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
	
	for_l (relocation,first_data_relocation,next){
		switch (relocation->relocation_kind){
			case LONG_WORD_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
#else
				if (label->label_id<0)
#endif
					internal_error_in_function ("write_data_relocations");

				write_l (relocation->relocation_offset);
#ifdef ELF
# ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_ARM_ABS32));
# else
				write_l (ELF32_R_INFO (label->label_id,R_ARM_ABS32));
# endif
#else
# ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==TEXT_LABEL_ID || label->label_id==DATA_LABEL_ID)
					write_l (label->label_object_label->object_label_number);
				else
# endif
				write_l (label->label_id);
				write_w (R_DIR32);
#endif
				break;				
			}
			default:
				internal_error_in_function ("write_data_relocations");
		}
	}
}

void assemble_code (void)
{
	literal_table_at_offset = 0ul-1ul;
	literal_table_at_buffer_p = (unsigned char*)0ul-1ul;

	as_import_labels (labels);

	write_code();

	end_code_offset=CURRENT_CODE_OFFSET;
	if (first_mapping_symbol!=NULL && last_mapping_symbol_code_offset==end_code_offset)
		--n_mapping_symbols; /* $t at end of section */

	flush_data_buffer();
	flush_code_buffer();

#ifdef OPTIMISE_BRANCHES
	optimise_branches();
#endif

#ifndef FUNCTION_LEVEL_LINKING
	code_object_label->object_label_length=code_buffer_offset;
	data_object_label->object_label_length=data_buffer_offset;
#endif

	relocate_code();
	relocate_data();

	write_file_header_and_section_headers();

	write_buffers_and_release_memory (&first_code_buffer);

# ifdef ELF
	if ((code_buffer_offset & 3)!=0){
		int n;

		n=4-(code_buffer_offset & 3);
		do {
			write_c (0);
		} while (--n);
	}
# endif

	write_buffers_and_release_memory (&first_data_buffer);

# ifdef ELF
	if ((data_buffer_offset & 3)!=0){
		int n;

		n=4-(data_buffer_offset & 3);
		do {
			write_c (0);
		} while (--n);
	}
# endif

	write_code_relocations();
	write_data_relocations();
	write_object_labels();
	write_string_table();
}
