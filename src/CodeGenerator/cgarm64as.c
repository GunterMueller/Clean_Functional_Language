/*
	File:	 cgarm64as.c
	Author:  John van Groningen
	Machine: AArch64
*/

#define RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#ifdef LINUX_ELF 
#	define ELF
#endif

#if defined (_WINDOWS_) || defined (ELF)
#	define FUNCTION_LEVEL_LINKING
#endif

#include "cgport.h"

#include "cgrconst.h"
#include "cgtypes.h"
#include "cg.h"
#include "cgiconst.h"
#include "cgcode.h"
#include "cgarm64as.h"
#include "cginstructions.h"

#define FP_REVERSE_SUB_DIV_OPERANDS 1

#ifdef ELF
# include <elf.h>
# ifdef ANDROID
#  include <asm/elf.h>
# endif
#endif

#define for_l(v,l,n) for(v=(l);v!=NULL;v=v->n)

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

static void write_q (long c)
{
	fputc (c,output_file);
	fputc (c>>8,output_file);
	fputc (c>>16,output_file);
	fputc (c>>24,output_file);
	fputc (c>>32,output_file);
	fputc (c>>40,output_file);
	fputc (c>>48,output_file);
	fputc (c>>56,output_file);
}

#define CALL_RELOCATION 0 /* R_AARCH64_CALL26 */
#define BRANCH_RELOCATION 1 /* R_AARCH64_CONDBR19 */
#define JUMP_RELOCATION 2 /* R_AARCH64_JUMP26 */
#define DUMMY_BRANCH_RELOCATION 3 /* R_AARCH64_NONE */
#define ADRP_RELOCATION 4 /* R_AARCH64_ADR_PREL_PG_HI21 */
#define ADD_OFFSET_RELOCATION 5 /* R_AARCH64_ADD_ABS_LO12_NC */
#define LDR_PC_OFFSET_RELOCATION 6 /* R_AARCH64_LD_PREL_LO19 */
#define WORD_RELOCATION 7 /* R_AARCH64_ABS32 */
#define LONG_WORD_RELOCATION 8 /* R_AARCH64_ABS64 */
#define RELATIVE_WORD_RELOCATION 9 /* R_AARCH64_PREL32 */
#define TEST_BRANCH_RELOCATION 10 /* R_AARCH64_TSTBR14 */

struct relocation {
	struct relocation *		next;
	unsigned long			relocation_offset;
	union {
		struct {
			WORD			s_align1;
			WORD			s_align2;
		} u_s;
		struct label *		u_label;
	} relocation_u;
#ifdef FUNCTION_LEVEL_LINKING
	struct object_label	*	relocation_object_label;
#endif
	int						relocation_addend;
	short					relocation_kind;
};

#define relocation_label relocation_u.u_label
#define relocation_align1 relocation_u.u_s.s_align1
#define relocation_align2 relocation_u.u_s.s_align2

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
	unsigned long ms_code_offset;
};

static struct mapping_symbol *first_mapping_symbol,*last_mapping_symbol;
int n_mapping_symbols; /* not length of struct mapping_symbol list */
unsigned long end_code_offset;

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

#define MAX_LITERAL_INSTRUCTION_OFFSET 4092

static unsigned long literal_table_at_offset;
static unsigned char *literal_table_at_buffer_p;

static void write_branch_and_literals (void);

static void store_l_no_literal_table (ULONG i)
{
	if (code_buffer_free>0){
		code_buffer_free-=4;
		code_buffer_p[0]=i;
		code_buffer_p[1]=i>>8;
		code_buffer_p[2]=i>>16;
		code_buffer_p[3]=i>>24;
		code_buffer_p+=4;
	} else {
		struct object_buffer *new_buffer;

		current_code_buffer->size=BUFFER_SIZE;
	
		new_buffer=memory_allocate (sizeof (struct object_buffer));
	
		new_buffer->size=0;
		new_buffer->next=NULL;
	
		current_code_buffer->next=new_buffer;
		current_code_buffer=new_buffer;
		code_buffer_offset+=BUFFER_SIZE;

		code_buffer_free=BUFFER_SIZE-4;
		code_buffer_p=new_buffer->data;

		code_buffer_p[0]=i;
		code_buffer_p[1]=i>>8;
		code_buffer_p[2]=i>>16;
		code_buffer_p[3]=i>>24;
		code_buffer_p+=4;

		if (literal_table_at_offset-(unsigned long)code_buffer_offset <= (unsigned long) BUFFER_SIZE)
			literal_table_at_buffer_p = current_code_buffer->data + (literal_table_at_offset-(unsigned long)code_buffer_offset);
	}
}

static void store_l (ULONG i)
{
	if (code_buffer_p>=literal_table_at_buffer_p)
		write_branch_and_literals();

	store_l_no_literal_table (i);
}

static void store_q_no_literal_table (unsigned long i)
{
	store_l_no_literal_table (i);
	store_l_no_literal_table (i>>32);
}

void store_long_word_in_data_section (unsigned int c)
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

void store_word64_in_data_section (int_64 c)
{
	if (data_buffer_free>=8){
		data_buffer_free-=8;
		*(int_64*)data_buffer_p=c;
		data_buffer_p+=8;
	} else {
		store_long_word_in_data_section ((int)c);
		store_long_word_in_data_section ((int)(c>>32));
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
	store_word64_in_data_section (length);
	
	while (length>=8){
		store_word64_in_data_section (*(unsigned long*)string_p);
		string_p+=8;
		length-=8;
	}
	
	if (length>0){
		unsigned long d;
		int shift;

		d=0;
		shift=0;
		while (length>0){
			d |= (unsigned long)string_p[0]<<shift;
			shift+=8;
			--length;
			++string_p;
		}

		store_word64_in_data_section (d);
	}
} 

void store_abc_string4_in_data_section (char *string,int length)
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
	new_relocation->relocation_kind=WORD_RELOCATION;
	new_relocation->relocation_addend=0;
}

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
	new_relocation->relocation_kind=RELATIVE_WORD_RELOCATION;
	new_relocation->relocation_addend=0;
}

static void store_relocation_of_label_with_addend_in_code_section (int relocation_kind,struct label *label,int addend)
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
	new_relocation->relocation_addend=addend;
}

struct literal_entry {
	long					le_offset;
	DOUBLE *				le_r_p;
	struct label 			le_load_instruction_label;
	struct literal_entry  *	le_next;
};

struct literal_entry *first_literal_entry,**literal_entry_l;

static void begin_data_mapping (void)
{
	unsigned long current_code_offset;
	struct mapping_symbol *new_mapping_symbol;
	
	current_code_offset = CURRENT_CODE_OFFSET;
	
	if (! (first_mapping_symbol!=NULL && last_mapping_symbol->ms_code_offset==current_code_offset && last_mapping_symbol->ms_data_offset>=current_code_offset)){
		if (code_object_label->object_label_offset==current_code_offset)
			n_mapping_symbols+=1; /* $d at begin of section, $x */
		else
			n_mapping_symbols+=2; /* $d and $x */

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

static void write_literals (void)
{
	struct literal_entry *literal_entry;

	literal_entry=first_literal_entry;

	if (literal_entry!=NULL){
		begin_data_mapping();

		for (; literal_entry!=NULL; literal_entry=literal_entry->le_next){
			unsigned long load_data_offset,current_code_offset;
			
			load_data_offset = literal_entry->le_load_instruction_label.label_offset;
			current_code_offset = CURRENT_CODE_OFFSET;

			literal_entry->le_load_instruction_label.label_flags=0;
			literal_entry->le_load_instruction_label.label_id=TEXT_LABEL_ID;
#ifdef FUNCTION_LEVEL_LINKING
			literal_entry->le_load_instruction_label.label_object_label=code_object_label;
#endif
			literal_entry->le_load_instruction_label.label_offset=current_code_offset;

			if (literal_entry->le_r_p==NULL){
				store_q_no_literal_table (literal_entry->le_offset);
			} else {
				// to do: align 8
				store_q_no_literal_table (*((unsigned long*)literal_entry->le_r_p));
			}
		}

		literal_entry_l=&first_literal_entry;
		first_literal_entry=NULL;
		
		last_mapping_symbol->ms_code_offset = CURRENT_CODE_OFFSET;
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
	new_relocation->relocation_addend=0;
	new_relocation->relocation_kind=relocation_kind;
}

static void as_branch_label_with_addend (struct label *label,int relocation_kind,int addend)
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
	new_relocation->relocation_addend=addend;
	new_relocation->relocation_kind=relocation_kind;
}

static void write_branch_and_literals (void)
{
	LABEL *new_label;

	literal_table_at_offset = 0ul-1ul;
	literal_table_at_buffer_p = (unsigned char*)0ul-1ul;

	new_label=allocate_memory_from_heap (sizeof (struct label));
	
	store_l (0x14000000); /* b */
	as_branch_label (new_label,JUMP_RELOCATION);

	write_literals();

	new_label->label_flags=0;
	new_label->label_id=TEXT_LABEL_ID;
#ifdef FUNCTION_LEVEL_LINKING
	new_label->label_object_label=code_object_label;
#endif
	new_label->label_offset=CURRENT_CODE_OFFSET;
}

static void as_literal_label (struct label *label)
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
	
	new_relocation->relocation_label=label;
	new_relocation->relocation_offset=current_code_offset;
	label->label_offset=current_code_offset; /* for pic store offset of load instead, label offset stored by write_literals */
#ifdef FUNCTION_LEVEL_LINKING
	new_relocation->relocation_object_label=code_object_label;
#endif
	new_relocation->relocation_kind=LDR_PC_OFFSET_RELOCATION;
	new_relocation->relocation_addend=0;
}

static void as_literal_constant_entry (long offset)
{
	struct literal_entry *new_literal_entry;

	new_literal_entry=allocate_memory_from_heap (sizeof (struct literal_entry));

	new_literal_entry->le_offset=offset;
	new_literal_entry->le_r_p=NULL;

	*literal_entry_l=new_literal_entry;
	literal_entry_l=&new_literal_entry->le_next;
	
	new_literal_entry->le_next=NULL;
	
	as_literal_label (&new_literal_entry->le_load_instruction_label);
}

static void as_float_load_int_literal_entry (int offset)
{
	struct literal_entry *new_literal_entry;
	
	new_literal_entry=allocate_memory_from_heap (sizeof (struct literal_entry));

	new_literal_entry->le_offset=offset;
	new_literal_entry->le_r_p=NULL;

	*literal_entry_l=new_literal_entry;
	literal_entry_l=&new_literal_entry->le_next;
	
	new_literal_entry->le_next=NULL;

	as_literal_label (&new_literal_entry->le_load_instruction_label);
}

static void as_float_literal_entry (DOUBLE *r_p)
{
	struct literal_entry *new_literal_entry;
	
	new_literal_entry=allocate_memory_from_heap (sizeof (struct literal_entry));

	new_literal_entry->le_r_p=r_p;
	new_literal_entry->le_offset=0;

	*literal_entry_l=new_literal_entry;
	literal_entry_l=&new_literal_entry->le_next;
	
	new_literal_entry->le_next=NULL;

	as_literal_label (&new_literal_entry->le_load_instruction_label);
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
	if (first_mapping_symbol!=NULL && last_mapping_symbol->ms_code_offset==current_code_offset)
		--n_mapping_symbols; /* $x at end of section */

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
	++n_mapping_symbols; /* $x at begin of section */
}
#endif

void store_label_in_data_section (LABEL *label)
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
	new_relocation->relocation_kind=WORD_RELOCATION;
	new_relocation->relocation_addend=0;
}

static void store_long_label_plus_offset_in_data_section (LABEL *label,int offset)
{
	struct relocation *new_relocation;

	store_word64_in_data_section (0);

	new_relocation=fast_memory_allocate_type (struct relocation);
	++n_data_relocations;
	
	*last_data_relocation_l=new_relocation;
	last_data_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;
	
	new_relocation->relocation_label=label;
	new_relocation->relocation_offset=CURRENT_DATA_OFFSET-8;
	new_relocation->relocation_kind=LONG_WORD_RELOCATION;
	new_relocation->relocation_addend=offset;
}

static void store_relative_label_in_data_section (struct label *label)
{
	struct relocation *new_relocation;
	
	store_long_word_in_data_section (0);

	new_relocation=fast_memory_allocate_type (struct relocation);
	++n_data_relocations;
	
	*last_data_relocation_l=new_relocation;
	last_data_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;
	
	new_relocation->relocation_label=label;
	new_relocation->relocation_offset=CURRENT_CODE_OFFSET-4;
	new_relocation->relocation_kind=RELATIVE_WORD_RELOCATION;
	new_relocation->relocation_addend=0;
}

void store_label_offset_in_data_section (LABEL *label)
{
	store_relative_label_in_data_section (label);
}

#define reg_num(r) (real_reg_num[(r)+N_REAL_A_REGISTERS])

static unsigned char real_reg_num [30]
	= { 24, 23, 22, 21, 20, 28, 27, 26, 15, 14, 13, 12, 11, 10, 9, 8, 6, 5, 4, 3, 2, 1, 0, 7, 25, 16, 17, 29, 30, 31 };

#define REGISTER_X25 8
#define REGISTER_S0 9
#define REGISTER_S1 10
#define REGISTER_X29 11
#define REGISTER_X30 12
#define REGISTER_X31 13

static void store_l_is (int i_code,int i,int shift)
{
	if (shift==0){
		i_code |= i & 255;
	} else {
		i_code |= (((32-shift)>>1)<<8);
		i_code |= (unsigned int)i >> (unsigned int)shift;
		if (shift>=24)
			i_code |= ((unsigned int)i << (unsigned int)(32-shift)) & 255;
	}
	store_l (i_code); 
}

static int bitmask_immediate (unsigned long i)
{
	if (i==0l || i==-1l)
		return 0;

	if ((i & 0x8000000000000000l)!=0)
		i = ~i;

	if ((i & (i + (i & (-i))))==0)
		return 6; /* all 1 bits are consecutive */

	if ((i>>32u)!=(i & 0xffffffffl))
		return 0;
	
	i &= 0xffffffffl;
	if ((i & (i + (i & (-i))))==0)
		return 5;

	if ((i>>16u)!=(i & 0xffffl))
		return 0;

	i &= 0xffffl;
	if ((i & (i + (i & (-i))))==0)
		return 4;

	if ((i>>8)!=(i & 0xffl))
		return 0;

	i &= 0xffl;
	if ((i & (i + (i & (-i))))==0)
		return 3;

	if ((i>>4)!=(i & 0xfl))
		return 0;

	i &= 0xfl;
	if ((i & (i + (i & (-i))))==0)
		return 2;

	if ((i>>2)!=(i & 0x3l))
		return 0;

	i &= 0x3l;
	if ((i & (i + (i & (-i))))==0)
		return 1;

	return 0;
}

static int r_and_s_for_bitmask_immediate (int n_log2_level_bits,unsigned long i)
{
	int n_level_bits,r,s;
	unsigned long level_mask;
	
	n_level_bits = 1<<n_log2_level_bits;
	level_mask = (2ul<<(n_level_bits-1))-1ul;

	if ((i & 0x8000000000000000l)==0){
		unsigned long n;
		int n_leading_zeros,n_ones,n_trailing_zeros;

		n = i & level_mask; /* all 1 bits in n are consecutive */
		n_leading_zeros = __builtin_clzl (n);
		n_ones = __builtin_clzl (~ (n<<n_leading_zeros));
		n_trailing_zeros = 64-n_leading_zeros-n_ones;

		s = n_ones-1;
		r = (n_level_bits - n_trailing_zeros) & (n_level_bits-1);
	} else {
		unsigned long n;
		int n_leading_ones,n_zeros,n_trailing_ones;

		n = (~i) & level_mask; /* all 1 bits in n are consecutive */
		n_leading_ones = __builtin_clzl (n);
		n_zeros = __builtin_clzl (~ (n<<n_leading_ones));
		n_trailing_ones = 64-n_leading_ones-n_zeros;
	
		n_leading_ones = n_leading_ones - (64 - n_level_bits);
	
		s = n_leading_ones+n_trailing_ones-1;
		r = n_leading_ones;
	}

	s = s | (-2<<n_log2_level_bits);
	s = (s & 127) ^ 64;

	return (((s & 64) | (r & 63))<<6) | (s & 63);
}

#define LOGICAL_OP_AND  0
#define LOGICAL_OP_ORR  1
#define LOGICAL_OP_EOR  2
#define LOGICAL_OP_ANDS 3

static void as_move_bitmask_i_r (unsigned int r_and_s,int d_reg)
{
	store_l (0x92000000 | (LOGICAL_OP_ORR<<29) | (r_and_s<<10) | (31<<5) | reg_num (d_reg)); /* orr immediate */
}

static void as_movz_i_r (long i,int reg1)
{
	store_l (0xd2800000 | (i<<5) | reg_num (reg1)); /* movz */
}

static void as_movz_i_r_shift_16 (long i,int reg1)
{
	store_l (0xd2800000 | (1<<21) | ((i>>16)<<5) | reg_num (reg1)); /* movz, lsl #16 */
}

static void as_movz_i_r_shift_32 (long i,int reg1)
{
	store_l (0xd2800000 | (2<<21) | ((i>>32)<<5) | reg_num (reg1)); /* movz, lsl #32 */
}

static void as_movz_i_r_shift_48 (long i,int reg1)
{
	store_l (0xd2800000 | (3<<21) | (((unsigned long)i>>(unsigned)48)<<5) | reg_num (reg1)); /* movz, lsl #48 */
}

static void as_movn_i_r (long not_i,int reg1)
{
	store_l (0x92800000 | (not_i<<5) | reg_num (reg1)); /* movn */
}

static void as_movn_i_r_shift_16 (long not_i,int reg1)
{
	store_l (0x92800000 | (1<<21) | ((not_i>>16)<<5) | reg_num (reg1)); /* movn, lsl #16 */
}

static void as_movn_i_r_shift_32 (long not_i,int reg1)
{
	store_l (0x92800000 | (2<<21) | ((not_i>>32)<<5) | reg_num (reg1)); /* movn, lsl #32 */
}

static void as_movn_i_r_shift_48 (long not_i,int reg1)
{
	store_l (0x92800000 | (3<<21) | (((unsigned long)not_i>>(unsigned)48)<<5) | reg_num (reg1)); /* movn, lsl #48 */
}

static void as_movk_i_r_shift_16 (long i,int reg1)
{
	store_l (0xf2800000 | (1<<21) | ((i>>16)<<5) | reg_num (reg1)); /* movk, lsl #16 */
}

static void as_move_i_r (long i,int reg1)
{
	long not_i;
	int n_log2_level_bits;

	if ((i & ~0xffffl)==0)             return as_movz_i_r (i,reg1);
	if ((i & ~0xffff0000l)==0)         return as_movz_i_r_shift_16 (i,reg1);
	if ((i & ~0xffff00000000l)==0)     return as_movz_i_r_shift_32 (i,reg1);
	if ((i & ~0xffff000000000000l)==0) return as_movz_i_r_shift_48 (i,reg1);

	not_i = ~i;
	if ((not_i & ~0xffffl)==0)             return as_movn_i_r (not_i,reg1);
	if ((not_i & ~0xffff0000l)==0)         return as_movn_i_r_shift_16 (not_i,reg1);
	if ((not_i & ~0xffff00000000l)==0)     return as_movn_i_r_shift_32 (not_i,reg1);
	if ((not_i & ~0xffff000000000000l)==0) return as_movn_i_r_shift_48 (not_i,reg1);

	n_log2_level_bits = bitmask_immediate (i);
	if (n_log2_level_bits!=0){
		unsigned int r_and_s;

		r_and_s = r_and_s_for_bitmask_immediate (n_log2_level_bits,i);
		as_move_bitmask_i_r (r_and_s,reg1);
		return;
	}

	if ((i & ~0xffffffffl)==0){
		as_movz_i_r (i & 0xffff,reg1);
		as_movk_i_r_shift_16 (i,reg1);
		return;
	}

	if ((~i & ~0xffffffffl)==0){
		as_movn_i_r (~i & 0xffff,reg1);
		as_movk_i_r_shift_16 (i & 0xffff0000,reg1);
		return;
	}

	store_l (0x58000000 | reg_num (reg1)); /* ldr xt,[pc+imm19] */
	as_literal_constant_entry (i);
}

static int as_move_i_or_neg_i_r (long i,int reg1)
{
	long not_i,neg_i,dec_i;
	int n_log2_level_bits;

	if ((i & ~0xffffl)==0)             { as_movz_i_r (i,reg1);          return 1; }
	if ((i & ~0xffff0000l)==0)         { as_movz_i_r_shift_16 (i,reg1); return 1; }
	if ((i & ~0xffff00000000l)==0)     { as_movz_i_r_shift_32 (i,reg1); return 1; }
	if ((i & ~0xffff000000000000l)==0) { as_movz_i_r_shift_48 (i,reg1); return 1; }

	neg_i = -i;
	if ((neg_i & ~0xffffl)==0)             { as_movz_i_r (neg_i,reg1);          return -1; }
	if ((neg_i & ~0xffff0000l)==0)         { as_movz_i_r_shift_16 (neg_i,reg1); return -1; }
	if ((neg_i & ~0xffff00000000l)==0)     { as_movz_i_r_shift_32 (neg_i,reg1); return -1; }
	if ((neg_i & ~0xffff000000000000l)==0) { as_movz_i_r_shift_48 (neg_i,reg1); return -1; }

	not_i = ~i;
	if ((not_i & ~0xffffl)==0)             { as_movn_i_r (not_i,reg1);          return 1; }
	if ((not_i & ~0xffff0000l)==0)         { as_movn_i_r_shift_16 (not_i,reg1); return 1; }
	if ((not_i & ~0xffff00000000l)==0)     { as_movn_i_r_shift_32 (not_i,reg1); return 1; }
	if ((not_i & ~0xffff000000000000l)==0) { as_movn_i_r_shift_48 (not_i,reg1); return 1; }

	dec_i = i-1; /* ~(-i) */
	if ((dec_i & ~0xffffl)==0)             { as_movn_i_r (dec_i,reg1);          return -1; }
	if ((dec_i & ~0xffff0000l)==0)         { as_movn_i_r_shift_16 (dec_i,reg1); return -1; }
	if ((dec_i & ~0xffff00000000l)==0)     { as_movn_i_r_shift_32 (dec_i,reg1); return -1; }
	if ((dec_i & ~0xffff000000000000l)==0) { as_movn_i_r_shift_48 (dec_i,reg1); return -1; }

	n_log2_level_bits = bitmask_immediate (i);
	if (n_log2_level_bits!=0){
		unsigned int r_and_s;

		r_and_s = r_and_s_for_bitmask_immediate (n_log2_level_bits,i);
		as_move_bitmask_i_r (r_and_s,reg1);
		return 1;
	}

	n_log2_level_bits = bitmask_immediate (neg_i);
	if (n_log2_level_bits!=0){
		unsigned int r_and_s;

		r_and_s = r_and_s_for_bitmask_immediate (n_log2_level_bits,neg_i);
		as_move_bitmask_i_r (r_and_s,reg1);
		return -1;
	}

	if ((i & ~0xffffffffl)==0){
		as_movz_i_r (i & 0xffff,reg1);
		as_movk_i_r_shift_16 (i,reg1);
		return 1;
	}

	if ((neg_i & ~0xffffffffl)==0){
		as_movz_i_r (neg_i & 0xffff,reg1);
		as_movk_i_r_shift_16 (neg_i,reg1);
		return -1;
	}

	store_l (0x58000000 | reg_num (reg1)); /* ldr xt,[pc+imm19] */
	as_literal_constant_entry (i);

	return 1;
}

static void as_mov_r_r (int s_reg,int d_reg)
{
	store_l (0xaa000000 | (reg_num (s_reg)<<16) | (31<<5) | reg_num (d_reg));
}

static void as_ldp_id_r_r (int offset,int sa_reg,int d_reg1,int d_reg2)
{
	if ((offset & 7)==0 && offset>=-512 && offset<=504){
		store_l (0xa9400000 | ((offset & 0x3f8)<<(15-3)) | (reg_num (d_reg2)<<10) | (reg_num (sa_reg)<<5) | reg_num (d_reg1));
		return;
	}

	internal_error_in_function ("as_ldp_id_r_r");
}

static void as_ldp_id_r_r_update (int offset,int sa_reg,int d_reg1,int d_reg2)
{
	if ((offset & 7)==0 && offset>=-512 && offset<=504){
		store_l (0xa9c00000 | ((offset & 0x3f8)<<(15-3)) | (reg_num (d_reg2)<<10) | (reg_num (sa_reg)<<5) | reg_num (d_reg1));
		return;
	}

	internal_error_in_function ("as_ldp_id_r_r_update");
}

static void as_ldp_id_post_add_r_r (int offset,int sa_reg,int d_reg1,int d_reg2)
{
	if ((offset & 7)==0 && offset>=-512 && offset<=504){
		store_l (0xa8c00000 | ((offset & 0x3f8)<<(15-3)) | (reg_num (d_reg2)<<10) | (reg_num (sa_reg)<<5) | reg_num (d_reg1));
		return;
	}

	internal_error_in_function ("as_ldp_id_post_add_r_r");
}

static void as_ldr_id_r (int offset,int sa_reg,int d_reg)
{
	int i_code;

	if ((offset & ~0x7ff8)==0){
		store_l (0xf9400000 | (offset<<(10-3)) | (reg_num (sa_reg)<<5) | reg_num (d_reg));
		return;
	}

	if (offset>=-0x100 && offset<=0xff){
		store_l (0xf8400000 | ((offset & 0x1ff)<<12) | (reg_num (sa_reg)<<5) | reg_num (d_reg)); /* ldur */
		return;
	}

	internal_error_in_function ("as_ldr_id_r");
}

static void as_ldr_id_r_update (int offset,int sa_reg,int d_reg)
{
	if (offset>=-0x100 && offset<=0xff){
		store_l (0xf8400c00 | ((offset & 0x1ff)<<12) | (reg_num (sa_reg)<<5) | reg_num (d_reg));
		return;		
	}

	internal_error_in_function ("as_ldr_id_r_update");
}

static void as_ldr_id_r_post_add (int offset,int sa_reg,int d_reg)
{
	if (offset>=-0x100 && offset<=0xff){
		store_l (0xf8400400 | ((offset & 0x1ff)<<12) | (reg_num (sa_reg)<<5) | reg_num (d_reg));
		return;		
	}

	internal_error_in_function ("as_ldr_id_r_post_add");
}

static void as_ldrw_id_r (int offset,int sa_reg,int d_reg)
{
	int i_code;

	if ((offset & ~0x7ff8)==0){
		store_l (0xb9400000 | (offset<<(10-3)) | (reg_num (sa_reg)<<5) | reg_num (d_reg));
		return;
	}

	if (offset>=-0x100 && offset<=0xff){
		store_l (0xb8400000 | ((offset & 0x1ff)<<12) | (reg_num (sa_reg)<<5) | reg_num (d_reg)); /* ldur */
		return;
	}

	internal_error_in_function ("as_ldrw_id_r");
}

static void as_ldrb_id_r (int offset,int sa_reg,int d_reg)
{
	if ((offset & ~0xfff)==0){
		store_l (0x39400000 | (offset<<10) | (reg_num (sa_reg)<<5) | reg_num (d_reg)); /* ldrb */
		return;
	}

	internal_error_in_function ("as_ldrb_id_r");
}

static void as_ldrsh_id_r (int offset,int sa_reg,int d_reg)
{
	if ((offset & ~0x1ffe)==0){
		store_l (0x79800000 | (offset<<(10-1)) | (reg_num (sa_reg)<<5) | reg_num (d_reg)); /* ldrsh */
		return;
	}

	if (offset>=-0x100 && offset<=0xff){
		store_l (0x78800000 | ((offset & 0x1ff)<<12) | (reg_num (sa_reg)<<5) | reg_num (d_reg)); /* ldursh */
		return;
	}

	internal_error_in_function ("as_ldrsh_id_r");
}

static void as_ldrsw_id_r (int offset,int sa_reg,int d_reg)
{
	if ((offset & ~0x3ffc)==0){
		store_l (0xb9800000 | (offset<<(10-2)) | (reg_num (sa_reg)<<5) | reg_num (d_reg)); /* ldrsw */
		return;
	}

	if (offset>=-0x100 && offset<=0xff){
		store_l (0xb8800000 | ((offset & 0x1ff)<<12) | (reg_num (sa_reg)<<5) | reg_num (d_reg)); /* ldursw */
		return;
	}

	internal_error_in_function ("as_ldrsw_id_r");
}

static void as_ldr_ix_r (int reg_n,int reg_m,int shift,int reg_t)
{
	if (shift==0)
		store_l (0xf8606800 | (reg_num (reg_m)<<16) | (reg_num (reg_n)<<5) | reg_num (reg_t));
	else if (shift==3)
		store_l (0xf8607800 | (reg_num (reg_m)<<16) | (reg_num (reg_n)<<5) | reg_num (reg_t));
	else
		internal_error_in_function ("as_ldr_ix_r");
}

static void as_ldrsw_ix_r (int reg_n,int reg_m,int shift,int reg_t)
{
	if (shift==0)
		store_l (0xb8a06800 | (reg_num (reg_m)<<16) | (reg_num (reg_n)<<5) | reg_num (reg_t));
	else if (shift==2)
		store_l (0xb8a07800 | (reg_num (reg_m)<<16) | (reg_num (reg_n)<<5) | reg_num (reg_t));
	else
		internal_error_in_function ("as_ldrsw_ix_r");
}

static void as_ldrb_ix_r (int reg_n,int reg_m,int reg_t)
{
	store_l (0x38606800 | (reg_num (reg_m)<<16) | (reg_num (reg_n)<<5) | reg_num (reg_t));
}

static void as_subs_i_r_r (int i,int s_reg,int d_reg)
{
	store_l (0xf1000000 | (i<<10) | (reg_num (s_reg)<<5) | reg_num (d_reg));
}

#define ARM_OP_LSL 0
#define ARM_OP_LSR 1
#define ARM_OP_ASR 2
#define ARM_OP_ROR 3

static void as_lsl_i_r_r (int i,int reg_m,int reg_d)
{
	/* ubfm xd,xn,#(64-uimm) & 63,#63-uimm */
	store_l (0xd3400000 | (((64-i) & 63)<<16) | ((63-i)<<10) | (reg_num (reg_m)<<5) | reg_num (reg_d));
}

static void as_lsr_i_r_r (int i,int reg_m,int reg_d)
{
	/* ubfm xd,xn,#uimm,#63 */
	store_l (0xd3400000 | (i<<16) | (63<<10) | (reg_num (reg_m)<<5) | reg_num (reg_d));
}

static void as_asr_i_r_r (int i,int reg_m,int reg_d)
{
	/* sbfm xd,xn,#uimm,#63 */
	store_l (0x93400000 | (i<<16) | (63<<10) | (reg_num (reg_m)<<5) | reg_num (reg_d));
}

static void as_ror_i_r_r (int i,int reg_s,int reg_d)
{
	/* extr xd,xs,xs,#uimm */
	store_l (0x93c00000 | (reg_num (reg_s)<<16) | (i<<10) | (reg_num (reg_s)<<5) | reg_num (reg_d));
}

static void as_shift_r_r_r (int shift_op,int reg_m,int reg_n,int reg_d)
{
	store_l (0x9ac02000 | (reg_num (reg_m)<<16) | (shift_op<<10) | (reg_num (reg_n)<<5) | reg_num (reg_d));
}

static void as_stp_r_r_id (int s_reg1,int s_reg2,int offset,int da_reg)
{
	if ((offset & 7)==0 && offset>=-512 && offset<=504){
		store_l (0xa9000000 | ((offset & 0x3f8)<<(15-3)) | (reg_num (s_reg2)<<10) | (reg_num (da_reg)<<5) | reg_num (s_reg1));
		return;
	}

	internal_error_in_function ("as_stp_r_r_id");
}

static void as_stp_r_r_id_update (int s_reg1,int s_reg2,int offset,int da_reg)
{
	if ((offset & 7)==0 && offset>=-512 && offset<=504){
		store_l (0xa9800000 | ((offset & 0x3f8)<<(15-3)) | (reg_num (s_reg2)<<10) | (reg_num (da_reg)<<5) | reg_num (s_reg1));
		return;
	}

	internal_error_in_function ("as_stp_r_r_id_update");
}

static void as_stp_r_r_id_post_add (int s_reg1,int s_reg2,int offset,int da_reg)
{
	if ((offset & 7)==0 && offset>=-512 && offset<=504){
		store_l (0xa8800000 | ((offset & 0x3f8)<<(15-3)) | (reg_num (s_reg2)<<10) | (reg_num (da_reg)<<5) | reg_num (s_reg1));
		return;
	}

	internal_error_in_function ("as_stp_r_r_id_post_add");
}

static void as_str_r_id (int s_reg,int offset,int da_reg)
{
	int i_code;

	if ((offset & ~0x7ff8)==0){
		store_l (0xf9000000 | (offset<<(10-3)) | (reg_num (da_reg)<<5) | reg_num (s_reg));
		return;
	}
	
	if (offset>=-0x100 && offset<=0xff){
		store_l (0xf8000000 | ((offset & 0x1ff)<<12) | (reg_num (da_reg)<<5) | reg_num (s_reg)); /* stur */
		return;
	}

	internal_error_in_function ("as_str_r_id");
}

static void as_str_r_id_update (int s_reg,int offset,int da_reg)
{
	if (offset>=-0x100 && offset<=0xff){
		store_l (0xf8000c00 | ((offset & 0x1ff)<<12) | (reg_num (da_reg)<<5) | reg_num (s_reg));
		return;		
	}

	internal_error_in_function ("as_str_r_id_update");
}

static void as_str_r_id_post_add (int s_reg,int offset,int da_reg)
{
	if (offset>=-0x100 && offset<=0xff){
		store_l (0xf8000400 | ((offset & 0x1ff)<<12) | (reg_num (da_reg)<<5) | reg_num (s_reg));
		return;		
	}

	internal_error_in_function ("as_str_r_id_post_add");
}

static void as_str_r_ix (int reg_t,int reg_n,int reg_m,int shift)
{
	if (shift==0)
		store_l (0xf8206800 | (reg_num (reg_m)<<16) | (reg_num (reg_n)<<5) | reg_num (reg_t));
	else if (shift==3)
		store_l (0xf8207800 | (reg_num (reg_m)<<16) | (reg_num (reg_n)<<5) | reg_num (reg_t));
	else
		internal_error_in_function ("as_str_r_ix");
}

static void as_str_wr_ix (int reg_t,int reg_n,int reg_m,int shift)
{
	if (shift==0)
		store_l (0xb8206800 | (reg_num (reg_m)<<16) | (reg_num (reg_n)<<5) | reg_num (reg_t));
	else if (shift==2)
		store_l (0xb8207800 | (reg_num (reg_m)<<16) | (reg_num (reg_n)<<5) | reg_num (reg_t));
	else
		internal_error_in_function ("as_str_wr_ix");
}

static void as_strb_r_id (int s_reg,int offset,int da_reg)
{
	if ((offset & ~0xfff)==0){
		store_l (0x39000000 | (offset<<10) | (reg_num (da_reg)<<5) | reg_num (s_reg));
		return;
	}
	
	internal_error_in_function ("as_strb_r_id");
}

static void as_strb_r_ix (int reg_t,int reg_n,int reg_m)
{
	store_l (0x38206800 | (reg_num (reg_m)<<16) | (reg_num (reg_n)<<5) | reg_num (reg_t));
}

static void as_sxtw_r_r (int reg_m,int reg_d)
{
	/* sbfm xd,xn,#0,#31 */
	store_l (0x93407c00 | (reg_num (reg_m)<<5) | reg_num (reg_d));
}

static void as_tst_i_r (int rotate_right,int n_bits_m1_and_levels,int reg)
{
	store_l (0xf2000000 | ((n_bits_m1_and_levels & 64)<<(22-6)) | (rotate_right<<16) | ((n_bits_m1_and_levels & 63)<<10) | (reg_num (reg)<<5) | 31); /* ands immediate */
}

static void as_ldr_id_d (int offset,int sa_reg,int dreg)
{
	if ((offset & ~0x7ff8)==0){
		store_l (0xfd400000 | offset<<(10-3) | (reg_num (sa_reg)<<5) | dreg); /* ldr */
		return;
	}

	if (offset>=-0x100 && offset<=0xff){
		store_l (0xfc400000 | ((offset & 0x1ff)<<12) | (reg_num (sa_reg)<<5) | dreg); /* ldur */
		return;
	}

	internal_error_in_function ("as_ldr_id_d");
}

static void as_ldr_literal_d (int offset,int dreg)
{
	store_l (0x5c000000 | ((offset>>2) & 0x7ffff)<<5 | dreg); /* ldr */
}

static void as_ldr_literal_s (int offset,int dreg)
{
	store_l (0x1c000000 | ((offset>>2) & 0x7ffff)<<5 | dreg); /* ldr */
}

static void as_ldr_id_s (int offset,int sa_reg,int sreg)
{
	if ((offset & ~0x3ffc)==0){
		store_l (0xbd400000 | offset<<(10-2) | (reg_num (sa_reg)<<5) | sreg); /* ldr */
		return;
	}

	if (offset>=-0x100 && offset<=0xff){
		store_l (0xbc400000 | ((offset & 0x1ff)<<12) | (reg_num (sa_reg)<<5) | sreg); /* ldur */
		return;
	}
}

static void as_str_d_id (int sreg,int offset,int da_reg)
{
	if ((offset & ~0x7ff8)==0){
		store_l (0xfd000000 | offset<<(10-3) | (reg_num (da_reg)<<5) | sreg); /* str */
		return;
	}

	if (offset>=-0x100 && offset<=0xff){
		store_l (0xfc000000 | ((offset & 0x1ff)<<12) | (reg_num (da_reg)<<5) | sreg); /* stur */
		return;
	}

	internal_error_in_function ("as_str_d_id");
}

static void as_str_s_id (int sreg,int offset,int da_reg)
{
	if ((offset & ~0x3ffc)==0){
		store_l (0xbd000000 | offset<<(10-2) | (reg_num (da_reg)<<5) | sreg); /* str */
		return;
	}

	if (offset>=-0x100 && offset<=0xff){
		store_l (0xbc000000 | ((offset & 0x1ff)<<12) | (reg_num (da_reg)<<5) | sreg); /* stur */
		return;
	}

	internal_error_in_function ("as_str_s_id");
}

static void as_logical_op_i_r_r (int op,unsigned int r_and_s,int s_reg,int d_reg)
{
	store_l (0x92000000 | (op<<29) | (r_and_s<<10) | (reg_num (s_reg)<<5) | reg_num (d_reg));
}

static void as_logical_op_r_r_r (int op,int reg_m,int reg_n,int reg_d)
{
	store_l (0x8a000000 | (op<<29) | (reg_num (reg_m)<<16) | (reg_num (reg_n)<<5) | reg_num (reg_d)); /* shifted register */
}

static void as_x_op_r_r_r (int x_op,int reg_m,int reg_n,int reg_d)
{
	store_l (x_op | (reg_num (reg_m)<<16) | (reg_num (reg_n)<<5) | reg_num (reg_d));
}

static void as_x_op_zr_r_r (int x_op,int reg_n,int reg_d)
{
	store_l (x_op | (31<<16) | (reg_num (reg_n)<<5) | reg_num (reg_d));
}

static void as_x_op_i_r_r (int x_op,int i,int s_reg,int d_reg)
{
	store_l (x_op | (i<<10) | (reg_num (s_reg)<<5) | reg_num (d_reg));
}

static void as_add_r_r_r (int reg_m,int reg_n,int reg_d)
{
	store_l (0x8b000000 | (reg_num (reg_m)<<16) | (reg_num (reg_n)<<5) | reg_num (reg_d)); /* shifted register */
}

static void as_add_r_lsl_r_r (int reg_m,int lsl_m,int reg_n,int reg_d)
{
	store_l (0x8b000000 | (ARM_OP_LSL<<22) | (reg_num (reg_m)<<16) | (lsl_m<<10) | (reg_num (reg_n)<<5) | reg_num (reg_d)); /* shifted register */
}

static void as_add_r_lsr_r_r (int reg_m,int lsr_m,int reg_n,int reg_d)
{
	store_l (0x8b000000 | (ARM_OP_LSR<<22) | (reg_num (reg_m)<<16) | (lsr_m<<10) | (reg_num (reg_n)<<5) | reg_num (reg_d)); /* shifted register */
}

static void as_add_r_asr_r_r (int reg_m,int asr_m,int reg_n,int reg_d)
{
	store_l (0x8b000000 | (ARM_OP_ASR<<22) | (reg_num (reg_m)<<16) | (asr_m<<10) | (reg_num (reg_n)<<5) | reg_num (reg_d)); /* shifted register */
}

static void as_add_i_r_r (int i,int s_reg,int d_reg)
{
	store_l (0x91000000 | (i<<10) | (reg_num (s_reg)<<5) | reg_num (d_reg));
}

static void as_add_i_r_r_shift_12 (int i,int s_reg,int d_reg)
{
	store_l (0x91000000 | (1<<22) | ((i>>12)<<10) | (reg_num (s_reg)<<5) | reg_num (d_reg));
}

static void as_sub_r_r_r (int reg_m,int reg_n,int reg_d)
{
	store_l (0xcb000000 | (reg_num (reg_m)<<16) | (reg_num (reg_n)<<5) | reg_num (reg_d)); /* shifted register */
}

static void as_sub_r_lsl_r_r (int reg_m,int lsl_m,int reg_n,int reg_d)
{
	store_l (0xcb000000 | (ARM_OP_LSL<<22) | (reg_num (reg_m)<<16) | (lsl_m<<10) | (reg_num (reg_n)<<5) | reg_num (reg_d)); /* shifted register */
}

static void as_sub_r_lsr_r_r (int reg_m,int lsr_m,int reg_n,int reg_d)
{
	store_l (0xcb000000 | (ARM_OP_LSR<<22) | (reg_num (reg_m)<<16) | (lsr_m<<10) | (reg_num (reg_n)<<5) | reg_num (reg_d)); /* shifted register */
}

static void as_sub_r_asr_r_r (int reg_m,int asr_m,int reg_n,int reg_d)
{
	store_l (0xcb000000 | (ARM_OP_ASR<<22) | (reg_num (reg_m)<<16) | (asr_m<<10) | (reg_num (reg_n)<<5) | reg_num (reg_d)); /* shifted register */
}

static void as_sub_i_r_r (int i,int s_reg,int d_reg)
{
	store_l (0xd1000000 | (i<<10) | (reg_num (s_reg)<<5) | reg_num (d_reg));
}

static void as_sub_i_r_r_shift_12 (int i,int s_reg,int d_reg)
{
	store_l (0xd1000000 | (1<<22) | ((i>>12)<<10) | (reg_num (s_reg)<<5) | reg_num (d_reg));
}

static void as_sub_i_lsl_12_r_r (int i,int s_reg,int d_reg)
{
	store_l (0xd1400000 | (i<<10) | (reg_num (s_reg)<<5) | reg_num (d_reg));
}

static void as_neg_r_r (int s_reg,int d_reg)
{
	store_l (0xcb000000 | (reg_num (s_reg)<<16) | (31<<5) | reg_num (d_reg)); /* sub shifted register */
}

static void as_neg_asr_r_r (int reg_m,int asr_m,int reg_d)
{
	store_l (0xcb000000 | (ARM_OP_ASR<<22) | (reg_num (reg_m)<<16) | (asr_m<<10) | (31<<5) | reg_num (reg_d)); /* sub shifted register */
}

static void as_ccmp_i_f_c_r (unsigned int i,unsigned int nzcv,unsigned int condition,int reg_n)
{
	store_l (0xfa400800 | (i<<16) | (condition<<12) | (reg_num (reg_n)<<5) | nzcv); /* ccmp  */
}

static void as_cinc_r_c_r (int s_reg,unsigned int condition,int d_reg)
{
	store_l (0x9a800400 | (reg_num (s_reg)<<16) | ((condition ^ 1)<<12) | (reg_num (s_reg)<<5) | reg_num (d_reg)); /* csinc  */
}

static void as_cmp_r_r (int reg_m,int reg_n)
{
	store_l (0xeb000000 | (reg_num (reg_m)<<16) | (reg_num (reg_n)<<5) | 31); /* subs shifted register */
}

static void as_cmp_i_r (unsigned int i,int s_reg)
{
	store_l (0xf1000000 | (i<<10) | (reg_num (s_reg)<<5) | 31); /* subs */
}

static void as_cmp_i_r_shift_12 (unsigned int i,int s_reg)
{
	store_l (0xf1000000 | (1<<22) | ((i>>12)<<10) | (reg_num (s_reg)<<5) | 31); /* subs */
}

static void as_cmn_r_r (int reg_m,int reg_n)
{
	store_l (0xab000000 | (reg_num (reg_m)<<16) | (reg_num (reg_n)<<5) | 31); /* adds shifted register */
}

static void as_cmn_i_r (unsigned int i,int s_reg)
{
	store_l (0xb1000000 | (i<<10) | (reg_num (s_reg)<<5) | 31); /* adds */
}

static void as_cmn_i_r_shift_12 (unsigned int i,int s_reg)
{
	store_l (0xb1000000 | (1<<22) | ((i>>12)<<10) | (reg_num (s_reg)<<5) | 31); /* adds */
}

static void as_move_d_r (LABEL *label,int arity,int reg1)
{
	store_l (0x90000000 | reg_num (reg1)); /* adrp */
	store_relocation_of_label_with_addend_in_code_section (ADRP_RELOCATION,label,arity);
	as_add_i_r_r (0,reg1,reg1);
	store_relocation_of_label_with_addend_in_code_section (ADD_OFFSET_RELOCATION,label,arity);
}

static void as_move_l_r (LABEL *label,int reg1)
{
	store_l (0x90000000 | reg_num (reg1)); /* adrp */
	store_relocation_of_label_with_addend_in_code_section (ADRP_RELOCATION,label,0);
	as_add_i_r_r (0,reg1,reg1);
	store_relocation_of_label_with_addend_in_code_section (ADD_OFFSET_RELOCATION,label,0);
}

static void as_load_indexed_reg (int offset,struct index_registers *index_registers,int reg)
{
	int reg1,reg2;

	reg1=index_registers->a_reg.r;
	reg2=index_registers->d_reg.r;
	if ((offset & -4)!=0){
		int i;

		i=offset>>2;
		if ((i & ~0xfff)==0)
			as_add_i_r_r (i,reg1,REGISTER_S0);
		else if ((-i & ~0xfff)==0)
			as_sub_i_r_r (-i,reg1,REGISTER_S0);
		else
			internal_error_in_function ("as_load_indexed_reg");

		as_ldr_ix_r (REGISTER_S0,reg2,offset & 3,reg);
		return;
	} else {
		as_ldr_ix_r (reg1,reg2,offset & 3,reg);
		return;
	}

	internal_error_in_function ("as_load_indexed_reg");
}

static void as_ldrsw_indexed_reg (int offset,struct index_registers *index_registers,int reg)
{
	int reg1,reg2;

	reg1=index_registers->a_reg.r;
	reg2=index_registers->d_reg.r;
	if ((offset & -4)!=0){
		int i;

		i=offset>>2;
		if ((i & ~0xfff)==0)
			as_add_i_r_r (i,reg1,REGISTER_S0);
		else if ((-i & ~0xfff)==0)
			as_sub_i_r_r (-i,reg1,REGISTER_S0);
		else
			internal_error_in_function ("as_ldrsw_indexed_reg");

		as_ldrsw_ix_r (REGISTER_S0,reg2,offset & 3,reg);
		return;
	} else {
		as_ldrsw_ix_r (reg1,reg2,offset & 3,reg);
		return;
	}

	internal_error_in_function ("as_ldrsw_indexed_reg");
}

static void as_store_b_reg_indexed (int reg,int offset,struct index_registers *index_registers,int scratch_reg)
{
	int reg1,reg2;
	
	reg1=index_registers->a_reg.r;
	reg2=index_registers->d_reg.r;
	if ((offset & 3)==0){
		int i;
		
		i=offset>>2;
		if (i!=0){
			as_add_i_r_r (i,reg1,scratch_reg);
			as_strb_r_ix (reg,scratch_reg,reg2);
		} else {
			as_strb_r_ix (reg,reg1,reg2);
		}
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
			as_ldr_id_r_post_add (8,parameter_p->parameter_data.reg.r,REGISTER_S0);
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

static void as_ldr_ldr_or_ldp (int offset1,int a_reg1,int d_reg1,int offset2,int a_reg2,int d_reg2)
{
#ifndef NO_LDRD
	if (a_reg1==a_reg2 && d_reg1!=a_reg1 && (offset1 & 7)==0){
		if (offset2==offset1+8){
			if (offset1>=-512 && offset1<=504){
				as_ldp_id_r_r (offset1,a_reg1,d_reg1,d_reg2);
				return;
			}
		} else if (offset2==offset1-8){
			if (offset2>=-512 && offset2<=504){
				as_ldp_id_r_r (offset2,a_reg1,d_reg2,d_reg1);
				return;
			}
		}
	}
#endif

	as_ldr_id_r (offset1,a_reg1,d_reg1);
	as_ldr_id_r (offset2,a_reg2,d_reg2);
}

#ifndef NO_STRD
static struct instruction *as_str_or_stp_id (struct instruction *instruction,struct parameter *d_parameter_p,int s_reg)
{
	struct instruction *next_instruction;
	int offset,a_reg;
	
	next_instruction=instruction->instruction_next;
	offset=d_parameter_p->parameter_offset;
	a_reg=d_parameter_p->parameter_data.reg.r;

	if (next_instruction!=NULL && next_instruction->instruction_icode==IMOVE && (offset & 7)==0){
		if (next_instruction->instruction_parameters[1].parameter_type==P_INDIRECT &&
			next_instruction->instruction_parameters[1].parameter_data.reg.r==a_reg
		){
			if (next_instruction->instruction_parameters[0].parameter_type==P_REGISTER){
				/* str str */
				if (next_instruction->instruction_parameters[1].parameter_offset==offset+8){
					if (offset>=-512 && offset<=504){
						as_stp_r_r_id (s_reg,next_instruction->instruction_parameters[0].parameter_data.reg.r,offset,a_reg);
						return next_instruction;
					}
				} else if (next_instruction->instruction_parameters[1].parameter_offset==offset-8){
					if (offset-8>=-512 && offset-8<=504){
						as_stp_r_r_id (next_instruction->instruction_parameters[0].parameter_data.reg.r,s_reg,offset-8,a_reg);
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

							as_ldr_id_r (next_instruction->instruction_parameters[0].parameter_offset,la_reg,s_reg2);
							as_stp_r_r_id (s_reg,s_reg2,offset,a_reg);
							return next_instruction;
						}
					} else if (next_instruction->instruction_parameters[1].parameter_offset==offset-8){
						if (offset-8>=-512 && offset-8<=504){
							int s_reg2;
							
							s_reg2 = s_reg!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

							as_ldr_id_r (next_instruction->instruction_parameters[0].parameter_offset,la_reg,s_reg2);
							as_stp_r_r_id (s_reg2,s_reg,offset-8,a_reg);
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

							as_move_d_r (next_instruction->instruction_parameters[0].parameter_data.l,
										 next_instruction->instruction_parameters[0].parameter_offset,s_reg2);
							as_stp_r_r_id (s_reg,s_reg2,offset,a_reg);
							return next_instruction;
						}
					} else if (next_instruction->instruction_parameters[1].parameter_offset==offset-8){
						if (offset-8>=-512 && offset-8<=504){
							int s_reg2;
							
							s_reg2 = s_reg!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

							as_move_d_r (next_instruction->instruction_parameters[0].parameter_data.l,
										 next_instruction->instruction_parameters[0].parameter_offset,s_reg2);
							as_stp_r_r_id (s_reg2,s_reg,offset-8,a_reg);
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
			as_stp_r_r_id_post_add (next_instruction->instruction_parameters[0].parameter_data.reg.r,s_reg,
									next_instruction->instruction_parameters[1].parameter_offset,a_reg);
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
							as_ldr_id_r (offset1,a_reg,next_instruction->instruction_parameters[1].parameter_data.reg.r);
							as_stp_r_r_id (s_reg,next_next_instruction->instruction_parameters[0].parameter_data.reg.r,offset,a_reg);							
							return next_next_instruction;	
						}
					} else if (offset2==offset-8){
						if (offset-8>=-512 && offset-8<=504){
							as_ldr_id_r (offset1,a_reg,next_instruction->instruction_parameters[1].parameter_data.reg.r);
							as_stp_r_r_id (next_next_instruction->instruction_parameters[0].parameter_data.reg.r,s_reg,offset-8,a_reg);
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

static struct instruction *as_str_str_or_stp_id (struct instruction *instruction,int s_reg,int offset,int a_reg)
{
	if ((offset & 7)==0 && instruction->instruction_parameters[1].parameter_data.reg.r==a_reg){
		if (instruction->instruction_parameters[1].parameter_offset==offset+8){
			if (offset>=-512 && offset<=504){
				as_stp_r_r_id (s_reg,REGISTER_S0,offset,a_reg);
				return instruction;
			}
		} else if (instruction->instruction_parameters[1].parameter_offset==offset-8){
			if (offset-8>=-512 && offset-8<=504){
				as_stp_r_r_id (REGISTER_S0,s_reg,offset-8,a_reg);
				return instruction;
			}
		}
	}

	as_str_r_id (s_reg,offset,a_reg);

	return as_str_or_stp_id (instruction,&instruction->instruction_parameters[1],REGISTER_S0);
}

static struct instruction *as_push (struct instruction *instruction,int s_reg)
{
	struct instruction *next_instruction;

	next_instruction=instruction->instruction_next;
	if (next_instruction!=NULL){
		if (next_instruction->instruction_icode==IMOVE &&
			next_instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
			next_instruction->instruction_parameters[1].parameter_type==P_PRE_DECREMENT &&
			next_instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER
		){
			as_stp_r_r_id_update (next_instruction->instruction_parameters[0].parameter_data.reg.r,s_reg,-16,B_STACK_POINTER);
			return next_instruction;
		}

		if (next_instruction->instruction_icode==IJSR &&
			next_instruction->instruction_arity>1 && 
			next_instruction->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE &&
			next_instruction->instruction_parameters[1].parameter_offset==-8 &&
			(next_instruction->instruction_parameters[0].parameter_type==P_LABEL ||
			 next_instruction->instruction_parameters[0].parameter_type==P_REGISTER)
		){
			as_stp_r_r_id_update (REGISTER_X30,s_reg,-16,B_STACK_POINTER);
			if (next_instruction->instruction_parameters[0].parameter_type==P_LABEL){
				store_l (0x94000000); /* bl */
				as_branch_label (next_instruction->instruction_parameters[0].parameter_data.l,CALL_RELOCATION);
			} else {
				store_l (0xd63f0000 | (reg_num (next_instruction->instruction_parameters[0].parameter_data.reg.r)<<5)); /* blr */
			}
			return next_instruction;
		}
	}

	as_str_r_id_update (s_reg,-8,B_STACK_POINTER);
	return instruction;
}
#endif

#ifndef NO_OPT_INDEXED
static struct instruction *as_more_load_indexed (struct instruction *next_instruction,int reg1,int reg2,int reg3,int offset)
{
	struct instruction *instruction;
	
	do {
		int d_reg;

		if (next_instruction->instruction_parameters[1].parameter_type==P_REGISTER){
			d_reg=next_instruction->instruction_parameters[1].parameter_data.reg.r;

			as_ldr_id_r (next_instruction->instruction_parameters[0].parameter_offset>>2,reg3,d_reg);

			if (d_reg==reg1 || d_reg==reg2)
				return next_instruction;
		} else {
			d_reg = reg3!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

			as_ldr_id_r (next_instruction->instruction_parameters[0].parameter_offset>>2,reg3,d_reg);

			switch (next_instruction->instruction_parameters[1].parameter_type){
				case P_INDIRECT:
					as_str_r_id (d_reg,next_instruction->instruction_parameters[1].parameter_offset,
									   next_instruction->instruction_parameters[1].parameter_data.reg.r);
					break;
				case P_PRE_DECREMENT:
					as_str_r_id_update (d_reg,-8,next_instruction->instruction_parameters[1].parameter_data.reg.r);
					break;
				case P_INDIRECT_WITH_UPDATE:
					as_str_r_id_update (d_reg,next_instruction->instruction_parameters[1].parameter_offset,
											  next_instruction->instruction_parameters[1].parameter_data.reg.r);

					if (next_instruction->instruction_parameters[1].parameter_data.reg.r==reg1 ||
						next_instruction->instruction_parameters[1].parameter_data.reg.r==reg2)
						return next_instruction;
					break;
				default:
					internal_error_in_function ("as_more_load_indexed");
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

static struct instruction *as_move_indexed_load_store_sequence (struct instruction *instruction) 
{
	struct instruction *next_instruction,*next_next_instruction;
	int store_address_without_offset_computed;
	int reg1,reg2,offset;

	reg1=instruction->instruction_parameters[0].parameter_data.ir->a_reg.r;
	reg2=instruction->instruction_parameters[0].parameter_data.ir->d_reg.r;
	offset=instruction->instruction_parameters[0].parameter_offset;

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
										int i;

										i=offset>>2;
										if ((i & ~0xfff)==0)
											as_add_i_r_r (i,reg1,REGISTER_S1);
										else if ((-i & ~0xfff)==0)
											as_sub_i_r_r (-i,reg1,REGISTER_S1);
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
						int i;

						i=offset>>2;
						if ((i & ~0xfff)==0)
							as_add_i_r_r (i,reg1,REGISTER_S1);
						else if ((-i & ~0xfff)==0)
							as_sub_i_r_r (-i,reg1,REGISTER_S1);
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

static struct instruction *as_move_instruction (struct instruction *instruction)
{
	struct parameter *d_parameter_p;
	int s_reg;

	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		int d_reg;
		
		d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

		switch (instruction->instruction_parameters[0].parameter_type){
			case P_REGISTER:
				as_mov_r_r (instruction->instruction_parameters[0].parameter_data.reg.r,d_reg);
				return instruction;
			case P_DESCRIPTOR_NUMBER:
				as_move_d_r (instruction->instruction_parameters[0].parameter_data.l,instruction->instruction_parameters[0].parameter_offset,d_reg);
				return instruction;
			case P_IMMEDIATE:
				as_move_i_r (instruction->instruction_parameters[0].parameter_data.i,d_reg);
				return instruction;
			case P_INDIRECT:
			{
				int a_reg,offset;
#ifndef NO_LDRD
				struct instruction *next_instruction;
#endif
				a_reg=instruction->instruction_parameters[0].parameter_data.reg.r;
				offset=instruction->instruction_parameters[0].parameter_offset;

#ifndef NO_LDRD
				next_instruction=instruction->instruction_next;
				if (d_reg!=a_reg && next_instruction!=NULL && next_instruction->instruction_icode==IMOVE &&
					(offset & 7)==0
				){
					if (next_instruction->instruction_parameters[0].parameter_type==P_INDIRECT &&
						next_instruction->instruction_parameters[0].parameter_data.reg.r==a_reg
					){
						/* ldr ldr */
						if (next_instruction->instruction_parameters[1].parameter_type==P_REGISTER){
							if (next_instruction->instruction_parameters[0].parameter_offset==offset+8){
								if (offset>=-512 && offset<=504){
									as_ldp_id_r_r (offset,a_reg,d_reg,next_instruction->instruction_parameters[1].parameter_data.reg.r);
									return next_instruction;
								}
							} else if (next_instruction->instruction_parameters[0].parameter_offset==offset-8){
								if (offset-8>=-512 && offset-8<=504){
									as_ldp_id_r_r (offset-8,a_reg,next_instruction->instruction_parameters[1].parameter_data.reg.r,d_reg);
									return next_instruction;
								}
							}
						} else {
							if (next_instruction->instruction_parameters[0].parameter_offset==offset+8){
								if (offset>=-512 && offset<=504){
									as_ldp_id_r_r (offset,a_reg,d_reg,REGISTER_S0);
									
									d_parameter_p=&next_instruction->instruction_parameters[1];
									instruction=next_instruction;
									s_reg = REGISTER_S0;
									break;
								}
							} else if (next_instruction->instruction_parameters[0].parameter_offset==offset-8){
								if (offset-8>=-512 && offset-8<=504){
									as_ldp_id_r_r (offset-8,a_reg,REGISTER_S0,d_reg);
									
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
								as_ldp_id_r_r_update (offset-8,a_reg,next_instruction->instruction_parameters[1].parameter_data.reg.r,d_reg);
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
							next_next_instruction->instruction_parameters[0].parameter_data.reg.r==a_reg)
						{
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
												as_ldp_id_r_r (offset,a_reg,d_reg,d_reg2);

												return as_str_or_stp_id (next_next_instruction,
																		 &next_instruction->instruction_parameters[1],s_reg);
											}
										} else if (offset2==offset-8){
											if (offset-8>=-512 && offset-8<=504){
												as_ldp_id_r_r (offset-8,a_reg,d_reg2,d_reg);

												return as_str_or_stp_id (next_next_instruction,
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
												as_ldp_id_r_r (offset,a_reg,d_reg,REGISTER_S0);
												
												return as_str_str_or_stp_id (next_next_instruction,s_reg,offset1,a_reg);
											}
										} else if (offset2==offset-8){
											if (offset2>=-512 && offset2<=504){
												as_ldp_id_r_r (offset2,a_reg,REGISTER_S0,d_reg);

												return as_str_str_or_stp_id (next_next_instruction,s_reg,offset1,a_reg);
											}
										}
									}
								}
							}
						}
					}
				}
#endif

				as_ldr_id_r (offset,a_reg,d_reg);
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
								as_add_r_lsl_r_r (reg2,offset & 3,reg1,REGISTER_S0);
								as_ldr_id_r (offset>>2,REGISTER_S0,instruction->instruction_parameters[1].parameter_data.reg.r);
								return as_more_load_indexed (next_instruction,reg1,reg2,REGISTER_S0,offset);
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
									return as_move_indexed_load_store_sequence (instruction);
							}
						}
					}
				}
#endif
				as_load_indexed_reg (instruction->instruction_parameters[0].parameter_offset,instruction->instruction_parameters[0].parameter_data.ir,d_reg);
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
					as_ldp_id_post_add_r_r (16,B_STACK_POINTER,d_reg,
											next_instruction->instruction_parameters[1].parameter_data.reg.r);
					return next_instruction;
				}
#endif
				as_ldr_id_r_post_add (8,instruction->instruction_parameters[0].parameter_data.reg.r,d_reg);
				return instruction;
			}
			case P_INDIRECT_WITH_UPDATE:
				as_ldr_id_r_update (instruction->instruction_parameters[0].parameter_offset,instruction->instruction_parameters[0].parameter_data.reg.r,d_reg);
				return instruction;
			case P_INDIRECT_POST_ADD:
				as_ldr_id_r_post_add (instruction->instruction_parameters[0].parameter_offset,instruction->instruction_parameters[0].parameter_data.reg.r,d_reg);
				return instruction;
			case P_LABEL:
				as_move_l_r (instruction->instruction_parameters[0].parameter_data.l,d_reg);
				as_ldr_id_r (0,d_reg,d_reg);
				return instruction;
			case P_INDIRECT_ANY_ADDRESS:
				as_ldr_id_r (instruction->instruction_parameters[0].parameter_offset,instruction->instruction_parameters[0].parameter_data.reg.r,d_reg);
				return instruction;
			default:
				internal_error_in_function ("as_move_instruction");
				return instruction;
		}
	} else if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
		switch (instruction->instruction_parameters[1].parameter_type){
			case P_INDIRECT:
#ifndef NO_STRD
				return as_str_or_stp_id (instruction,&instruction->instruction_parameters[1],
										 instruction->instruction_parameters[0].parameter_data.reg.r);
#else
				as_str_r_id (instruction->instruction_parameters[0].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return instruction;
#endif
			case P_PRE_DECREMENT:
				if (instruction->instruction_parameters[1].parameter_data.reg.r==B_STACK_POINTER)
					return as_push (instruction,instruction->instruction_parameters[0].parameter_data.reg.r);

				as_str_r_id_update (instruction->instruction_parameters[0].parameter_data.reg.r,
					-8,instruction->instruction_parameters[1].parameter_data.reg.r);
				return instruction;
			case P_INDEXED:
			{
				int reg_0,reg1,reg2,offset;
		
				reg_0 = instruction->instruction_parameters[0].parameter_data.reg.r;

				offset=instruction->instruction_parameters[1].parameter_offset;
				reg1=instruction->instruction_parameters[1].parameter_data.ir->a_reg.r;
				reg2=instruction->instruction_parameters[1].parameter_data.ir->d_reg.r;

				if ((offset & -4)!=0){
					int i;

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
							int reg3;
							
							if (reg_0!=REGISTER_S0)
								reg3=REGISTER_S0;
							else
								reg3=REGISTER_S1;

							as_add_r_lsl_r_r (reg2,offset & 3,reg1,reg3);
							as_str_r_id (reg_0,offset>>2,reg3);

							do {
								int reg4;
								
								if (next_instruction->instruction_parameters[0].parameter_type==P_REGISTER)
									reg4 = next_instruction->instruction_parameters[0].parameter_data.reg.r;
								else {
									/* P_INDIRECT */
									reg4 = reg3!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

									as_ldr_id_r (next_instruction->instruction_parameters[0].parameter_offset,
												 next_instruction->instruction_parameters[0].parameter_data.reg.r,reg4);
								}

								as_str_r_id (reg4,next_instruction->instruction_parameters[1].parameter_offset>>2,reg3);

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

					i=offset>>2;
					if ((i & ~0xfff)==0)
						as_add_i_r_r (i,reg1,REGISTER_S0);
					else if ((-i & ~0xfff)==0)
						as_sub_i_r_r (-i,reg1,REGISTER_S0);
					else
						internal_error_in_function ("as_move_instruction");

					as_str_r_ix (reg_0,REGISTER_S0,reg2,offset & 3);
				} else {
					as_str_r_ix (reg_0,reg1,reg2,offset & 3);
				}
				return instruction;
			}
			case P_POST_INCREMENT:
				as_str_r_id_post_add (instruction->instruction_parameters[0].parameter_data.reg.r,
					8,instruction->instruction_parameters[1].parameter_data.reg.r);
				return instruction;
			case P_INDIRECT_WITH_UPDATE:
				as_str_r_id_update (instruction->instruction_parameters[0].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return instruction;
			case P_INDIRECT_POST_ADD:
				as_str_r_id_post_add (instruction->instruction_parameters[0].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return instruction;
			case P_LABEL:
				as_move_l_r (instruction->instruction_parameters[1].parameter_data.l,REGISTER_S0);
				as_str_r_id (instruction->instruction_parameters[0].parameter_data.reg.r,0,REGISTER_S0);
				return instruction;
			case P_INDIRECT_ANY_ADDRESS:
				as_str_r_id (instruction->instruction_parameters[0].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return instruction;
		}
		internal_error_in_function ("as_move_instruction");
		return instruction;
	} else {
		d_parameter_p = &instruction->instruction_parameters[1];
		s_reg = REGISTER_S0;

		switch (instruction->instruction_parameters[0].parameter_type){
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
								? (next_instruction->instruction_parameters[0].parameter_offset+8<=offset ||
								   next_instruction->instruction_parameters[0].parameter_offset>=offset+8)
								: (la2_reg==A_STACK_POINTER || la2_reg==B_STACK_POINTER || sa_reg==A_STACK_POINTER || sa_reg==B_STACK_POINTER)
							){
								/* ldr->str ldr->str */
								if ((offset & 7)==0){
									if (next_instruction->instruction_parameters[1].parameter_offset==offset+8){
										if (offset>=-512 && offset<=504){
											as_ldr_ldr_or_ldp
												(instruction->instruction_parameters[0].parameter_offset,
												 instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_S0,
												 next_instruction->instruction_parameters[0].parameter_offset,la2_reg,REGISTER_S1);

											as_stp_r_r_id (REGISTER_S0,REGISTER_S1,offset,sa_reg);
											return next_instruction;
										}
									} else if (next_instruction->instruction_parameters[1].parameter_offset==offset-8){
										if (offset-8>=-512 && offset-8<=504){
											as_ldr_ldr_or_ldp
												(instruction->instruction_parameters[0].parameter_offset,
												 instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_S0,
												 next_instruction->instruction_parameters[0].parameter_offset,la2_reg,REGISTER_S1);

											as_stp_r_r_id (REGISTER_S1,REGISTER_S0,offset-8,sa_reg);
											return next_instruction;
										}
									}
								}
							}
						}
# ifndef NO_LDRD
						if (next_instruction->instruction_parameters[0].parameter_data.reg.r==instruction->instruction_parameters[0].parameter_data.reg.r){
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
										if ((instruction->instruction_parameters[0].parameter_offset & 7)==0){
											if (next_instruction->instruction_parameters[0].parameter_offset==instruction->instruction_parameters[0].parameter_offset+8){
												if (instruction->instruction_parameters[0].parameter_offset>=-512 && 
													instruction->instruction_parameters[0].parameter_offset<=504
												){
													as_ldp_id_r_r (instruction->instruction_parameters[0].parameter_offset,la2_reg,
																   REGISTER_S0,next_instruction->instruction_parameters[1].parameter_data.reg.r);

													/* parameters of instruction not used below */
													instruction=next_instruction;
													break;
												}
											} else if (next_instruction->instruction_parameters[0].parameter_offset==instruction->instruction_parameters[0].parameter_offset-8){
												if (next_instruction->instruction_parameters[0].parameter_offset>=-512 &&
													next_instruction->instruction_parameters[0].parameter_offset<=504
												){
													as_ldp_id_r_r (next_instruction->instruction_parameters[0].parameter_offset,la2_reg,
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
									(next_instruction->instruction_parameters[0].parameter_offset+8<=offset ||
									 next_instruction->instruction_parameters[0].parameter_offset>=offset+8)
								){
									if (sa_reg!=REGISTER_S0){
										int offset1;
										
										offset1=instruction->instruction_parameters[0].parameter_offset;
										if ((offset1 & 7)==0){
											int offset2;
											
											offset2=next_instruction->instruction_parameters[0].parameter_offset;
											if (offset2==offset1+8){
												if (offset1>=-512 && offset1<=504){
													as_ldp_id_r_r (offset1,sa_reg,REGISTER_S0,REGISTER_S1);
													
													as_str_r_id (REGISTER_S0,offset,sa_reg);

													d_parameter_p=&next_instruction->instruction_parameters[1];
													instruction=next_instruction;
													s_reg = REGISTER_S1;
													break;
												}
											} else if (offset2==offset1-8){
												if (offset2>=-512 && offset2<=504){
													as_ldp_id_r_r (offset2,sa_reg,REGISTER_S1,REGISTER_S0);
													
													as_str_r_id (REGISTER_S0,offset,sa_reg);
													
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
				as_ldr_id_r (instruction->instruction_parameters[0].parameter_offset,
					instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_S0);
				break;
			case P_INDEXED:

#ifndef NO_OPT_INDEXED
				if ((instruction->instruction_parameters[0].parameter_offset & -4)!=0 &&
					(d_parameter_p->parameter_type==P_INDIRECT ||
					 d_parameter_p->parameter_type==P_PRE_DECREMENT ||
					 d_parameter_p->parameter_type==P_INDIRECT_WITH_UPDATE)
				){
					int reg1,reg2;

					reg1=instruction->instruction_parameters[0].parameter_data.ir->a_reg.r;
					reg2=instruction->instruction_parameters[0].parameter_data.ir->d_reg.r;

					if (! (d_parameter_p->parameter_type==P_INDIRECT_WITH_UPDATE &&
						   (d_parameter_p->parameter_data.reg.r==reg1 || d_parameter_p->parameter_data.reg.r==reg2))
					){
						struct instruction *next_instruction;
						int offset;

						offset=instruction->instruction_parameters[0].parameter_offset;

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
							as_add_r_lsl_r_r (reg2,offset & 3,reg1,REGISTER_S0);
							as_ldr_id_r (offset>>2,REGISTER_S0,REGISTER_S1);

							if (d_parameter_p->parameter_type==P_INDIRECT)
								as_str_r_id (REGISTER_S1,d_parameter_p->parameter_offset,d_parameter_p->parameter_data.reg.r);
							else if (d_parameter_p->parameter_type==P_PRE_DECREMENT)
								as_str_r_id_update (REGISTER_S1,-8,d_parameter_p->parameter_data.reg.r);
							else
								as_str_r_id_update (REGISTER_S1,d_parameter_p->parameter_offset,d_parameter_p->parameter_data.reg.r);

							return as_more_load_indexed (next_instruction,reg1,reg2,REGISTER_S0,offset);
						}
					}
				}
#endif

				as_load_indexed_reg (instruction->instruction_parameters[0].parameter_offset,
					instruction->instruction_parameters[0].parameter_data.ir,REGISTER_S0);
				break;
			case P_DESCRIPTOR_NUMBER:
				as_move_d_r (instruction->instruction_parameters[0].parameter_data.l,
					instruction->instruction_parameters[0].parameter_offset,REGISTER_S0);
				break;
			case P_IMMEDIATE:
				as_move_i_r (instruction->instruction_parameters[0].parameter_data.i,REGISTER_S0);
				break;
			case P_POST_INCREMENT:
				as_ldr_id_r_post_add (8,instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_S0);
				break;
			case P_INDIRECT_WITH_UPDATE:
				as_ldr_id_r_update (instruction->instruction_parameters[0].parameter_offset,
					instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_S0);
				break;
			case P_INDIRECT_POST_ADD:
				as_ldr_id_r_post_add (instruction->instruction_parameters[0].parameter_offset,
									  instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_S0);
				break;
			default:
				internal_error_in_function ("as_move_instruction");
				return instruction;
		}
	}

	switch (d_parameter_p->parameter_type){
		case P_INDIRECT:
#ifndef NO_STRD
			return as_str_or_stp_id (instruction,d_parameter_p,s_reg);
#else
			as_str_r_id (s_reg,d_parameter_p->parameter_offset,d_parameter_p->parameter_data.reg.r);
			return instruction;
#endif
		case P_PRE_DECREMENT:
			if (d_parameter_p->parameter_data.reg.r==B_STACK_POINTER)
				return as_push (instruction,s_reg);

			as_str_r_id_update (s_reg,-8,d_parameter_p->parameter_data.reg.r);
			return instruction;
		case P_INDEXED:
		{
			int reg1,reg2,offset;
	
			offset=d_parameter_p->parameter_offset;
			reg1=d_parameter_p->parameter_data.ir->a_reg.r;
			reg2=d_parameter_p->parameter_data.ir->d_reg.r;

			if ((offset & -4)!=0){
				int i;

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
						int reg3;
						
						if (s_reg!=REGISTER_S0)
							reg3=REGISTER_S0;
						else
							reg3=REGISTER_S1;

						as_add_r_lsl_r_r (reg2,offset & 3,reg1,reg3);
						as_str_r_id (s_reg,offset>>2,reg3);

						do {
							int reg4;
							
							if (next_instruction->instruction_parameters[0].parameter_type==P_REGISTER)
								reg4 = next_instruction->instruction_parameters[0].parameter_data.reg.r;
							else {
								/* P_INDIRECT */
								reg4 = reg3!=REGISTER_S0 ? REGISTER_S0 : REGISTER_S1;

								as_ldr_id_r (next_instruction->instruction_parameters[0].parameter_offset,
											 next_instruction->instruction_parameters[0].parameter_data.reg.r,reg4);
							}

							as_str_r_id (reg4,next_instruction->instruction_parameters[1].parameter_offset>>2,reg3);

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

				i=offset>>2;
				if ((i & ~0xfff)==0)
					as_add_i_r_r (i,reg1,REGISTER_S1);
				else if ((-i & ~0xfff)==0)
					as_sub_i_r_r (-i,reg1,REGISTER_S1);
				else
					internal_error_in_function ("as_move_instruction");

				as_str_r_ix (s_reg,REGISTER_S1,reg2,offset & 3);
			} else {
				as_str_r_ix (s_reg,reg1,reg2,offset & 3);
			}
			return instruction;
		}
		case P_INDIRECT_WITH_UPDATE:
			as_str_r_id_update (s_reg,d_parameter_p->parameter_offset,d_parameter_p->parameter_data.reg.r);
			return instruction;
		case P_INDIRECT_POST_ADD:
			as_str_r_id_post_add (s_reg,d_parameter_p->parameter_offset,d_parameter_p->parameter_data.reg.r);
			return instruction;
		case P_LABEL:
			as_move_l_r (d_parameter_p->parameter_data.l,REGISTER_S1);
			as_str_r_id (s_reg,0,REGISTER_S1);
			return instruction;
	}

	internal_error_in_function ("as_move_instruction");
	return instruction;
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
					if ((offset & 3)==0){
						int i;
							
						i=offset>>2;
						if (i!=0){
							if ((i & ~0xfff)==0)
								as_add_i_r_r (offset>>2,reg1,REGISTER_S0);
							else if ((-i & ~0xfff)==0)
								as_sub_i_r_r (-i,reg1,REGISTER_S0);
							else
								internal_error_in_function ("as_moveb_instruction");
							as_ldrb_ix_r (REGISTER_S0,reg2,reg);
						} else {
							as_ldrb_ix_r (reg1,reg2,reg);
						}
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

static void as_moveqb_instruction (struct instruction *instruction)
{
	int s_reg;

	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			s_reg=instruction->instruction_parameters[0].parameter_data.reg.r;
			break;
		case P_IMMEDIATE:
			as_move_i_r (instruction->instruction_parameters[0].parameter_data.i,REGISTER_S0);
			s_reg=REGISTER_S0;
			break;
		default:
			as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
			s_reg=REGISTER_S0;
	}

	switch (instruction->instruction_parameters[1].parameter_type){
		case P_INDEXED:
		{
			int reg1,reg2,reg3,offset;

			offset=instruction->instruction_parameters[1].parameter_offset;
			reg1=instruction->instruction_parameters[1].parameter_data.ir->a_reg.r;
			reg2=instruction->instruction_parameters[1].parameter_data.ir->d_reg.r;

			if ((offset & -4)!=0){
				int i;

				reg3 = (s_reg!=REGISTER_S0) ? REGISTER_S0 : REGISTER_S1;

				i=offset>>2;
				if ((i & ~0xfff)==0)
					as_add_i_r_r (i,reg1,reg3);
				else if ((-i & ~0xfff)==0)
					as_sub_i_r_r (-i,reg1,reg3);
				else
					internal_error_in_function ("as_moveqb_instruction");

				as_str_wr_ix (s_reg,reg3,reg2,offset & 3);
			} else {
				as_str_wr_ix (s_reg,reg1,reg2,offset & 3);
			}
			return;
		}
	}
	internal_error_in_function ("as_moveqb_instruction");
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

static void as_loadsqb_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_REGISTER:
		{
			int reg;

			reg=instruction->instruction_parameters[1].parameter_data.reg.r;
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_REGISTER:
					as_sxtw_r_r (instruction->instruction_parameters[0].parameter_data.reg.r,reg);
					return;
				case P_INDIRECT:
					as_ldrsw_id_r (instruction->instruction_parameters[0].parameter_offset,
						instruction->instruction_parameters[0].parameter_data.reg.r,reg);
					return;
				case P_INDEXED:
					as_ldrsw_indexed_reg (instruction->instruction_parameters[0].parameter_offset,
						instruction->instruction_parameters[0].parameter_data.ir,reg);
					return;
			}
			break;
		}
	}
	internal_error_in_function ("as_loadsqb_instruction");
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
				int shift,i,sa_reg,d_reg;
				
				i = instruction->instruction_parameters[0].parameter_offset;
				sa_reg = instruction->instruction_parameters[0].parameter_data.reg.r;
				d_reg = instruction->instruction_parameters[1].parameter_data.reg.r;
				
				if ((i & ~0xfff)==0){
					as_add_i_r_r (i,sa_reg,d_reg);
					return;
				}
				if ((-i & ~0xfff)==0){
					as_sub_i_r_r (-i,sa_reg,d_reg);
					return;
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
				as_ldp_id_r_r (offset,instruction->instruction_parameters[0].parameter_data.reg.r,
							   instruction->instruction_parameters[n_remaining_regs-1].parameter_data.reg.r,
							   instruction->instruction_parameters[n_remaining_regs].parameter_data.reg.r);
				n_remaining_regs-=2;
			}

			if (n_remaining_regs>2){
				offset-=8;
				as_ldr_id_r (offset,instruction->instruction_parameters[0].parameter_data.reg.r,
							 instruction->instruction_parameters[n_remaining_regs].parameter_data.reg.r);
				--n_remaining_regs;
			}
		}

		if (n_remaining_regs==2){
			if (instruction->instruction_parameters[0].parameter_type==P_PRE_DECREMENT){
				as_ldp_id_r_r_update (-(n_regs<<3),instruction->instruction_parameters[0].parameter_data.reg.r,
									  instruction->instruction_parameters[1].parameter_data.reg.r,
									  instruction->instruction_parameters[2].parameter_data.reg.r);
				return;
			} else if (instruction->instruction_parameters[0].parameter_type==P_POST_INCREMENT){
				as_ldp_id_post_add_r_r (n_regs<<3,instruction->instruction_parameters[0].parameter_data.reg.r,
										instruction->instruction_parameters[1].parameter_data.reg.r,
										instruction->instruction_parameters[2].parameter_data.reg.r);
				return;
			}
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
				as_stp_r_r_id (instruction->instruction_parameters[n_remaining_regs].parameter_data.reg.r,
							   instruction->instruction_parameters[n_remaining_regs+1].parameter_data.reg.r,
							   offset,instruction->instruction_parameters[n_regs].parameter_data.reg.r);
			}

			if (n_remaining_regs>2){
				offset-=8;
				--n_remaining_regs;
				as_str_r_id (instruction->instruction_parameters[n_remaining_regs].parameter_data.reg.r,
							 offset,instruction->instruction_parameters[n_regs].parameter_data.reg.r);
			}
		}

		if (n_remaining_regs==2){
			if (instruction->instruction_parameters[n_regs].parameter_type==P_PRE_DECREMENT){
				as_stp_r_r_id_update (instruction->instruction_parameters[0].parameter_data.reg.r,
									  instruction->instruction_parameters[1].parameter_data.reg.r,
									  -(n_regs<<3),instruction->instruction_parameters[n_regs].parameter_data.reg.r);
				return;
			} else if (instruction->instruction_parameters[n_regs].parameter_type==P_POST_INCREMENT){
				as_stp_r_r_id_post_add (instruction->instruction_parameters[0].parameter_data.reg.r,
										instruction->instruction_parameters[1].parameter_data.reg.r,
										n_regs<<3,instruction->instruction_parameters[n_regs].parameter_data.reg.r);
				return;
			}
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
			long i;
			int reg1;
			
			i = instruction->instruction_parameters[0].parameter_data.i;
			reg1 = instruction->instruction_parameters[1].parameter_data.reg.r;

			if ((i & ~0xfffl)==0){
				as_add_i_r_r (i,reg1,reg1);
				return;
			}
			if ((-i & ~0xfffl)==0){
				as_sub_i_r_r (-i,reg1,reg1);
				return;
			}

			if ((i & ~0xfff000l)==0){
				as_add_i_r_r_shift_12 (i,reg1,reg1);
				return;
			}
			if ((-i & ~0xfff000l)==0){
				as_sub_i_r_r_shift_12 (-i,reg1,reg1);
				return;
			}

			if (as_move_i_or_neg_i_r (i,REGISTER_S0)>0)
				as_add_r_r_r (REGISTER_S0,reg1,reg1);
			else
				as_sub_r_r_r (REGISTER_S0,reg1,reg1);
			return;
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
			long i;
			int reg1;
			
			i = instruction->instruction_parameters[0].parameter_data.i;
			reg1 = instruction->instruction_parameters[1].parameter_data.reg.r;

			if ((i & ~0xfffl)==0){
				as_sub_i_r_r (i,reg1,reg1);
				return;
			}
			if ((-i & ~0xfffl)==0){
				as_add_i_r_r (-i,reg1,reg1);
				return;
			}

			if ((i & ~0xfff000l)==0){
				as_sub_i_r_r_shift_12 (i,reg1,reg1);
				return;
			}
			if ((-i & ~0xfff000l)==0){
				as_add_i_r_r_shift_12 (-i,reg1,reg1);
				return;
			}

			if (as_move_i_or_neg_i_r (i,REGISTER_S0)>0)
				as_sub_r_r_r (REGISTER_S0,reg1,reg1);
			else
				as_add_r_r_r (REGISTER_S0,reg1,reg1);
			return;
		}
		default:
			as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
	}

	as_sub_r_r_r (REGISTER_S0,instruction->instruction_parameters[1].parameter_data.reg.r,
		instruction->instruction_parameters[1].parameter_data.reg.r);
}

static void as_addi_instruction (struct instruction *instruction)
{
	int s_reg,d_reg;
	long i;
	
	s_reg = instruction->instruction_parameters[0].parameter_data.reg.r;
	d_reg = instruction->instruction_parameters[1].parameter_data.reg.r;
	i = instruction->instruction_parameters[2].parameter_data.i;

	if ((i & ~0xfffl)==0){
		as_add_i_r_r (i,s_reg,d_reg);
		return;
	}
	if ((-i & ~0xfffl)==0){
		as_sub_i_r_r (-i,s_reg,d_reg);
		return;
	}

	if ((i & ~0xfff000l)==0){
		as_add_i_r_r_shift_12 (i,s_reg,d_reg);
		return;
	}
	if ((-i & ~0xfff000l)==0){
		as_sub_i_r_r_shift_12 (-i,s_reg,d_reg);
		return;
	}

	if (as_move_i_or_neg_i_r (i,REGISTER_S0)>0)
		as_add_r_r_r (REGISTER_S0,s_reg,d_reg);
	else
		as_sub_r_r_r (REGISTER_S0,s_reg,d_reg);
}

static void as_adc_or_sbc_instruction (struct instruction *instruction,int arm_x_op)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_x_op_r_r_r (arm_x_op,instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
			if (instruction->instruction_parameters[0].parameter_data.i==0){
				as_x_op_zr_r_r (arm_x_op,instruction->instruction_parameters[1].parameter_data.reg.r,
										 instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}
			as_move_i_r (instruction->instruction_parameters[0].parameter_data.i,REGISTER_S0);
			break;
		default:
			as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
	}

	as_x_op_r_r_r (arm_x_op,REGISTER_S0,instruction->instruction_parameters[1].parameter_data.reg.r,
		instruction->instruction_parameters[1].parameter_data.reg.r);
}

static void as_adds_or_subs_instruction (struct instruction *instruction,int arm_x_op_sr,int arm_x_op_i)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_x_op_r_r_r (arm_x_op_sr,instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
		{
			long i;
			
			i = instruction->instruction_parameters[0].parameter_data.i;
			if ((i & ~0xfffl)==0){
				as_x_op_i_r_r (arm_x_op_i,i,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}
			if ((-i & ~0xfffl)==0){
				as_x_op_i_r_r (arm_x_op_i ^ 0x40000000,-i,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}

			as_move_i_r (i,REGISTER_S0);
			break;
		}
		default:
			as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
	}

	as_x_op_r_r_r (arm_x_op_sr,REGISTER_S0,instruction->instruction_parameters[1].parameter_data.reg.r,
		instruction->instruction_parameters[1].parameter_data.reg.r);
}

static void as_cmp_i_parameter (long i,struct parameter *parameter)
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

	if ((i & ~0xfffl)==0){
		as_cmp_i_r (i,reg);
		return;
	}
	if ((-i & ~0xfffl)==0){
		as_cmn_i_r (-i,reg);
		return;
	}

	if ((i & ~0xfff000l)==0){
		as_cmp_i_r_shift_12 (i,reg);
		return;
	}
	if ((-i & ~0xfff000l)==0){
		as_cmn_i_r_shift_12 (-i,reg);
		return;
	}

	if (as_move_i_or_neg_i_r (i,reg_i)>0)
		as_cmp_r_r (reg_i,reg);
	else
		as_cmn_r_r (reg_i,reg);
}

static void as_cmp_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_DESCRIPTOR_NUMBER:
			switch (instruction->instruction_parameters[1].parameter_type){
				case P_REGISTER:
					as_move_d_r (instruction->instruction_parameters[0].parameter_data.l,
								 instruction->instruction_parameters[0].parameter_offset,REGISTER_S1);
					as_cmp_r_r (REGISTER_S1,instruction->instruction_parameters[1].parameter_data.reg.r);
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

void store_descriptor_in_data_section (LABEL *label)
{
	store_long_label_plus_offset_in_data_section (label,2);
}

static void as_jmp_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_LABEL:
			store_l (0x14000000); /* b */
			as_branch_label (instruction->instruction_parameters[0].parameter_data.l,JUMP_RELOCATION);
			break;
		case P_INDIRECT:
			as_ldrw_id_r (instruction->instruction_parameters[0].parameter_offset,
						  instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_S0);
			store_l (0xd61f0000 | (reg_num (REGISTER_S0)<<5)); /* br */
			break;
		case P_REGISTER:
			store_l (0xd61f0000 | (reg_num (instruction->instruction_parameters[0].parameter_data.reg.r)<<5)); /* br */
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
				as_mov_r_r (REGISTER_X30,REGISTER_X29);

				store_l (0x94000000); /* bl */
				as_branch_label (profile_t_label,CALL_RELOCATION);

				store_l (0x14000000); /* b */
				as_branch_label (instruction->instruction_parameters[0].parameter_data.l,JUMP_RELOCATION);
			} else {
				store_l (0x14000000); /* b */
				as_branch_label_with_addend (instruction->instruction_parameters[0].parameter_data.l,JUMP_RELOCATION,offset);
			}
			break;
		}
		case P_INDIRECT:
			as_mov_r_r (REGISTER_X30,REGISTER_X29);

			store_l (0x94000000); /* bl */
			as_branch_label (profile_t_label,CALL_RELOCATION);				

			as_ldrw_id_r (instruction->instruction_parameters[0].parameter_offset,
						  instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_S0);
			store_l (0xd61f0000 | (reg_num (REGISTER_S0)<<5)); /* br */
			break;
		case P_REGISTER:
			as_mov_r_r (REGISTER_X30,REGISTER_X29);

			store_l (0x94000000); /* bl */
			as_branch_label (profile_t_label,CALL_RELOCATION);				

			store_l (0xd61f0000 | (reg_num (instruction->instruction_parameters[0].parameter_data.reg.r)<<5)); /* br */
			break;
		default:
			internal_error_in_function ("as_jmpp_instruction");
	}
}

static void as_jsr_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_LABEL:
			if (instruction->instruction_arity>1)
				switch (instruction->instruction_parameters[1].parameter_type){
					case P_INDIRECT_WITH_UPDATE:
						as_str_r_id_update (REGISTER_X30,instruction->instruction_parameters[1].parameter_offset,B_STACK_POINTER);
						break;
					case P_INDIRECT:
						as_str_r_id (REGISTER_X30,instruction->instruction_parameters[1].parameter_offset,B_STACK_POINTER);
						break;
					case P_REGISTER:
						as_mov_r_r (REGISTER_X30,REGISTER_X29);						
						store_l (0x94000000); /* bl */
						as_branch_label (instruction->instruction_parameters[0].parameter_data.l,CALL_RELOCATION);
						as_mov_r_r (REGISTER_X29,REGISTER_X30);
						return;
				}
			store_l (0x94000000); /* bl */
			as_branch_label (instruction->instruction_parameters[0].parameter_data.l,CALL_RELOCATION);
			break;
		case P_INDIRECT:
			as_ldrw_id_r (instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_S0);
			if (instruction->instruction_arity>1)
				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE)
					as_str_r_id_update (REGISTER_X30,-8,B_STACK_POINTER);
			store_l (0xd63f0000 | (reg_num (REGISTER_S0)<<5)); /* blr */
			break;
		case P_REGISTER:
			if (instruction->instruction_arity>1)
				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE)
					as_str_r_id_update (REGISTER_X30,-8,B_STACK_POINTER);
			store_l (0xd63f0000 | (reg_num (instruction->instruction_parameters[0].parameter_data.reg.r)<<5)); /* blr */
			break;
		default:
			internal_error_in_function ("as_jsr_instruction");
	}
}

static void as_rts_instruction()
{
	store_l (0xaa000000 | (30<<16) | (31<<5) | 29); /* mov x29,x30 */
	store_l (0xf8400400 | (8<<12) | (28<<5) | 30); /* ldr x30,[x28],#8 */
	store_l (0xd65f0000 | (29<<5)); /* ret x29 */
	write_literals();
}

static void as_rtsi_instruction (struct instruction *instruction)
{
	int offset;
	
	offset = instruction->instruction_parameters[0].parameter_data.imm;

	store_l (0xaa000000 | (30<<16) | (31<<5) | 29); /* mov x29,x30 */
	store_l (0xf8400400 | ((offset & 0xfff)<<12) | (28<<5) | 30); /* ldr x30,[x28],#offset */
	store_l (0xd65f0000 | (29<<5)); /* ret x29 */
	write_literals();
}

static void as_branch_instruction (struct instruction *instruction,int condition_code)
{
	if (instruction->instruction_parameters[0].parameter_data.l->label_flags & FAR_CONDITIONAL_JUMP_LABEL){
		struct call_and_jump *new_call_and_jump;

		new_call_and_jump=allocate_memory_from_heap (sizeof (struct call_and_jump));
		new_call_and_jump->cj_next=NULL;

		if (first_call_and_jump!=NULL)
			last_call_and_jump->cj_next=new_call_and_jump;
		else
			first_call_and_jump=new_call_and_jump;
		last_call_and_jump=new_call_and_jump;

		new_call_and_jump->cj_call_label=NULL;
		new_call_and_jump->cj_jump=*instruction->instruction_parameters[0].parameter_data.l;

		store_l (0x54000000 | condition_code); /* b.cond */
		as_branch_label (&new_call_and_jump->cj_label,BRANCH_RELOCATION);
		return;
	}

	store_l (0x54000000 | condition_code); /* b.cond */
	as_branch_label (instruction->instruction_parameters[0].parameter_data.l,BRANCH_RELOCATION);
}

static void as_nop (void)
{
	/* mov r0,r0 */
	store_l (0xd503201f); 
}

static void as_lsl_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		as_lsl_i_r_r (instruction->instruction_parameters[0].parameter_data.i & 63,
			instruction->instruction_parameters[1].parameter_data.reg.r,
			instruction->instruction_parameters[1].parameter_data.reg.r);
	} else {
		int s_reg,d_reg;

		s_reg = instruction->instruction_parameters[0].parameter_data.reg.r;
		d_reg = instruction->instruction_parameters[1].parameter_data.reg.r;
		as_shift_r_r_r (ARM_OP_LSL,s_reg,d_reg,d_reg);
	}
}

static void as_lsr_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		as_lsr_i_r_r (instruction->instruction_parameters[0].parameter_data.i & 63,
			instruction->instruction_parameters[1].parameter_data.reg.r,
			instruction->instruction_parameters[1].parameter_data.reg.r);
	} else {
		int s_reg,d_reg;

		s_reg = instruction->instruction_parameters[0].parameter_data.reg.r;
		d_reg = instruction->instruction_parameters[1].parameter_data.reg.r;
		as_shift_r_r_r (ARM_OP_LSR,s_reg,d_reg,d_reg);
	}
}

static void as_asr_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		as_asr_i_r_r (instruction->instruction_parameters[0].parameter_data.i & 63,
			instruction->instruction_parameters[1].parameter_data.reg.r,
			instruction->instruction_parameters[1].parameter_data.reg.r);
	} else {
		int s_reg,d_reg;

		s_reg = instruction->instruction_parameters[0].parameter_data.reg.r;
		d_reg = instruction->instruction_parameters[1].parameter_data.reg.r;
		as_shift_r_r_r (ARM_OP_ASR,s_reg,d_reg,d_reg);
	}
}

static void as_rotr_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		as_ror_i_r_r (instruction->instruction_parameters[0].parameter_data.i & 63,
			instruction->instruction_parameters[1].parameter_data.reg.r,
			instruction->instruction_parameters[1].parameter_data.reg.r);
	} else {
		int s_reg,d_reg;

		s_reg = instruction->instruction_parameters[0].parameter_data.reg.r;
		d_reg = instruction->instruction_parameters[1].parameter_data.reg.r;
		as_shift_r_r_r (ARM_OP_ROR,s_reg,d_reg,d_reg);
	}
}

static void as_lsli_instruction (struct instruction *instruction)
{
	as_lsl_i_r_r (instruction->instruction_parameters[2].parameter_data.i & 63,
		instruction->instruction_parameters[0].parameter_data.reg.r,
		instruction->instruction_parameters[1].parameter_data.reg.r);
}

static void as_logic_instruction (struct instruction *instruction,int logical_op)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_logical_op_r_r_r (logical_op,instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
		{
			int n_log2_level_bits;
			unsigned long i;

			i = instruction->instruction_parameters[0].parameter_data.i;

			n_log2_level_bits = bitmask_immediate (i);
			if (n_log2_level_bits!=0){
				unsigned int r_and_s;

				r_and_s = r_and_s_for_bitmask_immediate (n_log2_level_bits,i);

				as_logical_op_i_r_r (logical_op,r_and_s,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}

			store_l (0x58000000 | reg_num (REGISTER_S0)); /* ldr xt,[pc+imm19] */
			as_literal_constant_entry (i);
			as_logical_op_r_r_r (logical_op,REGISTER_S0,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		}
		default:
			as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
			as_logical_op_r_r_r (logical_op,REGISTER_S0,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
	}
}

static void as_mul_instruction (struct instruction *instruction,int code)
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
	store_l (code | (real_d_regn<<16) | (reg_num (s_regn)<<5) | real_d_regn);
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

struct ms magic (long d)
	/* must have 2 <= d <= 263-1 or -263 <= d <= -2 */
{
	int p;
	unsigned long ad, anc, delta, q1, r1, q2, r2, t;
	const unsigned long two63 = 1ul<<63u;/* 263 */
	struct ms mag;

	ad = abs(d);
	t = two63 + ((unsigned long)d >> 63);
	anc = t - 1 - t%ad; /* absolute value of nc */
	p = 63;				/* initialize p */
	q1 = two63/anc;		/* initialize q1 = 2p/abs(nc) */
	r1 = two63 - q1*anc;/* initialize r1 = rem(2p,abs(nc)) */
	q2 = two63/ad;		/* initialize q2 = 2p/abs(d) */
	r2 = two63 - q2*ad;	/* initialize r2 = rem(2p,abs(d)) */

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
	mag.s = p - 64;				/* resulting shift */

	return mag;
}

static void as_div_instruction (struct instruction *instruction)
{
	int i,abs_i,d_reg;
	struct ms ms;

	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (instruction->instruction_parameters[0].parameter_type!=P_IMMEDIATE){
		int s_reg,scratch_reg;

		if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
			s_reg = instruction->instruction_parameters[0].parameter_data.reg.r;
		} else {
			as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
			s_reg = REGISTER_S0;
		}

		store_l (0x9ac00c00 | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<5) | reg_num (d_reg)); /* sdiv */
		return;
	}
	
	i=instruction->instruction_parameters[0].parameter_data.i;
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
				as_neg_r_r (d_reg,d_reg);
			return;
		}

		log2i=0;
		i2=abs_i;
		while (i2>1){
			i2>>=1;
			++log2i;
		}
		
		if (log2i==1){
			as_add_r_lsr_r_r (d_reg,63,d_reg,d_reg);
			if (i>0)
				as_asr_i_r_r (log2i,d_reg,d_reg);
			else
				as_neg_asr_r_r (d_reg,log2i,d_reg);		
		} else {
			as_tst_i_r (0,64+log2i-1,d_reg);
			if (i>=0)
				as_asr_i_r_r (log2i,d_reg,REGISTER_S0);
			else
				as_neg_asr_r_r (d_reg,log2i,REGISTER_S0);
			as_ccmp_i_f_c_r (0,0,CONDITION_NE,d_reg);
			if (i>=0)
				as_cinc_r_c_r (REGISTER_S0,CONDITION_MI,d_reg);
			else
				as_cinc_r_c_r (REGISTER_S0,CONDITION_PL,d_reg);
		}
		
		return;
	}

	ms=magic (abs_i);

	as_move_i_r (ms.m,REGISTER_S0);
	store_l (0x9b407c00 | (reg_num (d_reg)<<16) | (reg_num (REGISTER_S0)<<5) | reg_num (REGISTER_S0)); /* smulh */

	if (ms.s==0){
		if (ms.m>=0){
			if (i>=0){
				as_add_r_lsr_r_r (d_reg,63,REGISTER_S0,d_reg);
			} else {
				as_asr_i_r_r (63,d_reg,d_reg);
				as_sub_r_r_r (REGISTER_S0,d_reg,d_reg);
			}
		} else {
			if (i>=0){
				as_add_r_lsr_r_r (d_reg,63,d_reg,d_reg);
				as_add_r_r_r (REGISTER_S0,d_reg,d_reg);
			} else {
				as_asr_i_r_r (63,d_reg,REGISTER_S1);
				as_sub_r_r_r (d_reg,REGISTER_S1,d_reg);
				as_sub_r_r_r (REGISTER_S0,d_reg,d_reg);
			}
		}
	} else {
		if (i>=0)
			as_lsr_i_r_r (63,d_reg,REGISTER_S1);
		else
			as_asr_i_r_r (63,d_reg,REGISTER_S1);
		if (ms.m<0)
			as_add_r_r_r (d_reg,REGISTER_S0,REGISTER_S0);
		if (i>=0)
			as_add_r_asr_r_r (REGISTER_S0,ms.s,REGISTER_S1,d_reg);
		else
			as_sub_r_asr_r_r (REGISTER_S0,ms.s,REGISTER_S1,d_reg);
	}	
}

static void as_divu_instruction (struct instruction *instruction)
{
	int d_reg,s_reg;

	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
		s_reg = instruction->instruction_parameters[0].parameter_data.reg.r;
	} else {
		as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
		s_reg = REGISTER_S0;
	}

	store_l (0x9ac00800 | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<5) | reg_num (d_reg)); /* udiv */
	return;
}

static void as_rem_instruction (struct instruction *instruction)
{
	int i,d_reg;
	struct ms ms;

	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (instruction->instruction_parameters[0].parameter_type!=P_IMMEDIATE){
		int s_reg,scratch_reg;

		if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
			s_reg = instruction->instruction_parameters[0].parameter_data.reg.r;
			scratch_reg = REGISTER_S0;
		} else {
			as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
			s_reg = REGISTER_S0;
			scratch_reg = REGISTER_S1;
		}

		store_l (0x9ac00c00 | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<5) | reg_num (scratch_reg)); /* sdiv */
		store_l (0x9b008000 | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<10) | (reg_num (scratch_reg)<<5) | reg_num (d_reg)); /* msub */
		return;
	}
	
	i=instruction->instruction_parameters[0].parameter_data.i;

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

		as_sub_r_lsr_r_r (d_reg,63,d_reg,REGISTER_S0);
		
		log2i=0;
		i2=i;
		while (i2>1){
			i2>>=1;
			++log2i;
		}
		
		if (log2i!=1)
			as_asr_i_r_r (log2i-1,d_reg,d_reg);
		as_logical_op_i_r_r (LOGICAL_OP_AND,(64<<6)+log2i-1,REGISTER_S0,REGISTER_S0);
		as_sub_r_lsr_r_r (d_reg,64-log2i,REGISTER_S0,d_reg);
		return;
	}

	ms=magic (i);

	as_move_i_r (ms.m,REGISTER_S0);
	store_l (0x9b407c00 | (reg_num (d_reg)<<16) | (reg_num (REGISTER_S0)<<5) | reg_num (REGISTER_S0)); /* smulh */

	if (ms.s==0){
		if (ms.m>=0){
			as_add_r_lsr_r_r (d_reg,63,REGISTER_S0,REGISTER_S0);
		} else {
			as_add_r_lsr_r_r (d_reg,63,d_reg,REGISTER_S1);
			as_add_r_r_r (REGISTER_S1,REGISTER_S0,REGISTER_S0);
		}
	} else {
		as_lsr_i_r_r (63,d_reg,REGISTER_S1);

		if (ms.m>=0){
			as_add_r_asr_r_r (REGISTER_S0,ms.s,REGISTER_S1,REGISTER_S0);
		} else {
			as_add_r_r_r (d_reg,REGISTER_S0,REGISTER_S0);
			as_add_r_asr_r_r (REGISTER_S0,ms.s,REGISTER_S1,REGISTER_S0);
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
				
				if (n_shifts>0)
					as_sub_r_lsl_r_r (REGISTER_S0,n_shifts,d_reg,d_reg);
				else
					as_sub_r_r_r (REGISTER_S0,d_reg,d_reg);
				
				n>>=1;
				n_shifts=1;
			}
		} else {
			as_move_i_r (i,REGISTER_S1);
			store_l (0x9b008000 | (reg_num (REGISTER_S1)<<16) | (reg_num (d_reg)<<10) | (reg_num (REGISTER_S0)<<5) | reg_num (d_reg)); /* msub */
		}
	}
}

static void as_set_condition_instruction (struct instruction *instruction,int condition_code_false)
{
	int rn;
	
	rn = reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);

	store_l (0x9a9f07e0 | (condition_code_false<<12) | rn); /* cset rd */
}

static void as_set_vc_and_condition_instruction (struct instruction *instruction,int condition_code_false)
{
	int rn;
	
	rn = reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);

	store_l (0x9a9f07e0 | (condition_code_false<<12) | rn); /* cset rd */
	store_l (0x9a800000 | (31<<16) | (CONDITION_VC<<12) | (rn<<5) | rn); /* cssel xd,xd,xzr,vc */
}

static void as_tst_instruction (struct instruction *instruction)
{
	as_cmp_i_parameter (0,&instruction->instruction_parameters[0]);
}

static struct instruction *as_btst_instruction (struct instruction *instruction)
{
	int reg1,shift;
	unsigned long i;
	
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER)
		reg1=instruction->instruction_parameters[1].parameter_data.reg.r;
	else {
		reg1=instruction->instruction_parameters[1].parameter_data.reg.r;

		as_ldr_id_r (instruction->instruction_parameters[1].parameter_offset,reg1,REGISTER_S0);
		reg1 = REGISTER_S0;
	}

	i=instruction->instruction_parameters[0].parameter_data.i;
	
	if (i!=0){
		int bit_n;
		
		bit_n = __builtin_clzl (i);
		if (i == (1ul<<(bit_n ^ 63))){
			struct instruction *next_instruction;

			next_instruction=instruction->instruction_next;
			if (next_instruction!=NULL && next_instruction->instruction_icode==IBNE &&
				next_instruction->instruction_next==NULL &&
				(next_instruction->instruction_parameters[0].parameter_data.l->label_flags & FAR_CONDITIONAL_JUMP_LABEL)==0
			){
				bit_n = bit_n ^ 63;

				store_l (0x37000000 | ((bit_n & 32)<<(31-5)) | ((bit_n & 31)<<19) | reg_num (reg1)); /* tbnz */
				as_branch_label (next_instruction->instruction_parameters[0].parameter_data.l,TEST_BRANCH_RELOCATION);

				return next_instruction;
			}

			as_tst_i_r ((bit_n + 1) & 63,64,reg1);
			return instruction;
		}	
	}

	internal_error_in_function ("as_btst_instruction");
}

static void as_neg_instruction (struct instruction *instruction)
{
	int reg;
	
	reg = instruction->instruction_parameters[0].parameter_data.reg.r;
	as_neg_r_r (reg,reg);
}

static void as_not_instruction (struct instruction *instruction)
{	
	unsigned int regn;
	
	regn = reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);
	store_l (0xaa200000 | (regn<<16) | (31<<5) | regn); /* orn shifted register */
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

		store_l (0xdac01000 | (reg_num (s_reg)<<5) | reg_num (d_reg)); /*clz */

		return;
	}

	internal_error_in_function ("as_clzb_instruction");
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
					
					store_l (0x1e604000 | (reg0<<5) | reg1); /* fmov dd,dn */
					return;
				}
				case P_INDIRECT:
					as_ldr_id_d (instruction->instruction_parameters[0].parameter_offset,
						instruction->instruction_parameters[0].parameter_data.reg.r,
						instruction->instruction_parameters[1].parameter_data.reg.r);
					return;
				case P_INDEXED:
					as_add_r_lsl_r_r (instruction->instruction_parameters[0].parameter_data.ir->d_reg.r,
						instruction->instruction_parameters[0].parameter_offset & 3,
						instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,REGISTER_S0);
					as_ldr_id_d (instruction->instruction_parameters[0].parameter_offset>>2,REGISTER_S0,
						instruction->instruction_parameters[1].parameter_data.reg.r);
					return;
				case P_F_IMMEDIATE:
					as_ldr_literal_d (0,instruction->instruction_parameters[1].parameter_data.reg.r);
					as_float_literal_entry (instruction->instruction_parameters[0].parameter_data.r);
					return;
				default:
					internal_error_in_function ("as_fmove_instruction");
					return;
			}
		case P_INDIRECT:
			if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
				as_str_d_id (instruction->instruction_parameters[0].parameter_data.reg.r,
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
				as_str_d_id (instruction->instruction_parameters[0].parameter_data.reg.r,
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
				as_ldr_id_s (instruction->instruction_parameters[0].parameter_offset,
							  instruction->instruction_parameters[0].parameter_data.reg.r,freg);
				break;
			case P_INDEXED:
				freg=instruction->instruction_parameters[1].parameter_data.reg.r;
				as_add_r_lsl_r_r (instruction->instruction_parameters[0].parameter_data.ir->d_reg.r,
					instruction->instruction_parameters[0].parameter_offset & 3,
					instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,REGISTER_S0);
				as_ldr_id_s (instruction->instruction_parameters[0].parameter_offset>>2,REGISTER_S0,freg);
				break;
			default:
				internal_error_in_function ("as_floads_instruction");
				return;
		}

		store_l (0x1e22c000 | (freg<<5) | freg); /* fcvt dd,sm */
		return;
	}

	internal_error_in_function ("as_floads_instruction");
}

static void as_fmoves_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
		int s_freg;
				
		s_freg=instruction->instruction_parameters[0].parameter_data.reg.r;

		store_l (0x1e624000 | (s_freg<<5) | 15); /* fcvt sd,dm */

		switch (instruction->instruction_parameters[1].parameter_type){
			case P_INDIRECT:
				as_str_s_id (15,instruction->instruction_parameters[1].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_INDEXED:
				as_add_r_lsl_r_r (instruction->instruction_parameters[1].parameter_data.ir->d_reg.r,
					instruction->instruction_parameters[1].parameter_offset & 3,
					instruction->instruction_parameters[1].parameter_data.ir->a_reg.r,REGISTER_S0);
				as_str_s_id (15,instruction->instruction_parameters[1].parameter_offset>>2,REGISTER_S0);
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
			as_ldr_literal_d (0,15);
			as_float_literal_entry (instruction->instruction_parameters[0].parameter_data.r);
			s_freg=15;
			break;
		case P_INDIRECT:
			as_ldr_id_d (instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r,15);
			s_freg=15;
			break;
		case P_INDEXED:
			as_add_r_lsl_r_r (instruction->instruction_parameters[0].parameter_data.ir->d_reg.r,
				instruction->instruction_parameters[0].parameter_offset & 3,
				instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,REGISTER_S0);
			as_ldr_id_d (instruction->instruction_parameters[0].parameter_offset>>2,REGISTER_S0,15);
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
	store_l (code | (s_freg<<16) | (d_freg<<5) | d_freg);
}

static void as_float_sub_or_div_instruction (struct instruction *instruction,int code)
{
	int d_freg,s_freg;
	
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_F_IMMEDIATE:
			as_ldr_literal_d (0,15);
			as_float_literal_entry (instruction->instruction_parameters[0].parameter_data.r);
			s_freg=15;
			break;
		case P_INDIRECT:
			as_ldr_id_d (instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r,15);
			s_freg=15;
			break;
		case P_INDEXED:
			as_add_r_lsl_r_r (instruction->instruction_parameters[0].parameter_data.ir->d_reg.r,
				instruction->instruction_parameters[0].parameter_offset & 3,
				instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,REGISTER_S0);
			as_ldr_id_d (instruction->instruction_parameters[0].parameter_offset>>2,REGISTER_S0,15);
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
		store_l (code | (d_freg<<16) | (s_freg<<5) | d_freg);
	else
		store_l (code | (s_freg<<16) | (d_freg<<5) | d_freg);
}

static void as_fcmp_d_d (int freg_1,int freg_2)
{
	store_l (0x1e602000 | (freg_1<<16) | (freg_2<<5)); /* fcmp */
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
			if ((((int*)r_p)[0] | ((int*)r_p)[1])==0){
				store_l (0x1e602080 | (d_freg<<5)); /* fcmp dn,#0.0 */
			} else {
				as_ldr_literal_d (0,15);
				as_float_literal_entry (instruction->instruction_parameters[0].parameter_data.r);
				as_fcmp_d_d (15,d_freg);
			}
			return;
		}
		case P_INDIRECT:
			as_ldr_id_d (instruction->instruction_parameters[0].parameter_offset,
			 			  instruction->instruction_parameters[0].parameter_data.reg.r,15);
			as_fcmp_d_d (15,d_freg);
			return;
		case P_INDEXED:
			as_add_r_lsl_r_r (instruction->instruction_parameters[0].parameter_data.ir->d_reg.r,
				instruction->instruction_parameters[0].parameter_offset & 3,
				instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,REGISTER_S0);
			as_ldr_id_d (instruction->instruction_parameters[0].parameter_offset>>2,REGISTER_S0,15);
			as_fcmp_d_d (15,d_freg);
			return;
		case P_F_REGISTER:
			as_fcmp_d_d (instruction->instruction_parameters[0].parameter_data.reg.r,d_freg);
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
			as_ldr_literal_d (0,15);
			as_float_literal_entry (instruction->instruction_parameters[0].parameter_data.r);
			s_freg=15;
			break;
		case P_INDIRECT:
			as_ldr_id_d (instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r,15);
			s_freg=15;
			break;
		case P_INDEXED:
			as_add_r_lsl_r_r (instruction->instruction_parameters[0].parameter_data.ir->d_reg.r,
				instruction->instruction_parameters[0].parameter_offset & 3,
				instruction->instruction_parameters[0].parameter_data.ir->a_reg.r,REGISTER_S0);
			as_ldr_id_d (instruction->instruction_parameters[0].parameter_offset>>2,REGISTER_S0,15);
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
	store_l (code | (s_freg<<5) | d_freg);
}

static void as_float_branch_instruction (struct instruction *instruction,int condition_code)
{
	/*            Z N C V
	equal         1 0 1 0
	less than     0 1 0 0
	greater than  0 0 1 0
	unordered     0 0 1 1

	bgt           Z==0 && N==V 
	ble           Z==1 || N!=V
	*/	
	store_l (0x54000000 | condition_code); /* b.cond */
	as_branch_label (instruction->instruction_parameters[0].parameter_data.l,BRANCH_RELOCATION);
}

static void as_float_branch_vc_and_instruction (struct instruction *instruction,int condition_code)
{
	if (code_buffer_p+4>=literal_table_at_buffer_p)
		write_branch_and_literals();

	store_l_no_literal_table (0x54000000 | CONDITION_VS | ((8>>2)<<5)); /* b.vs pc+8 */
	store_l_no_literal_table (0x54000000 | condition_code); /* b.cond */
	as_branch_label (instruction->instruction_parameters[0].parameter_data.l,BRANCH_RELOCATION);
}

static void as_float_branch_vs_or_instruction (struct instruction *instruction,int condition_code)
{
	store_l (0x54000000 | CONDITION_VS); /* b.vs */
	as_branch_label (instruction->instruction_parameters[0].parameter_data.l,BRANCH_RELOCATION);

	as_float_branch_instruction (instruction,condition_code);
}

static void create_new_data_object_label (LABEL *label)
{
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

void define_data_label (LABEL *label)
{
	label->label_id=DATA_LABEL_ID;
#ifdef FUNCTION_LEVEL_LINKING
	label->label_object_label=data_object_label;
#endif
	label->label_offset=CURRENT_DATA_OFFSET;	

	if (label->label_flags & EXPORT_LABEL)
		create_new_data_object_label (label);
}

void define_exported_data_label_with_offset (LABEL *label,int offset)
{
	label->label_id=DATA_LABEL_ID;
#ifdef FUNCTION_LEVEL_LINKING
	label->label_object_label=data_object_label;
#endif
	label->label_offset=CURRENT_DATA_OFFSET+offset;

	create_new_data_object_label (label);
}

void store_descriptor_string_in_data_section (char *string,int length,LABEL *string_label)
{
	define_data_label (string_label);
	store_abc_string4_in_data_section (string,length);
}

static void as_fmovel_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
		if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
			/* fcvtns */
			store_l (0x9e600000
					 | (instruction->instruction_parameters[0].parameter_data.reg.r<<5)
					 | reg_num (instruction->instruction_parameters[1].parameter_data.reg.r));
			return;
		} else
			internal_error_in_function ("as_fmovel_instruction");
	} else {
		int freg;

		freg=instruction->instruction_parameters[1].parameter_data.reg.r;

		switch (instruction->instruction_parameters[0].parameter_type){
			case P_REGISTER:
				/* scvtf */
				store_l (0x9e620000 | (reg_num (instruction->instruction_parameters[0].parameter_data.reg.r)<<5) | freg);
				return;
			case P_INDIRECT:
				as_ldr_id_r (instruction->instruction_parameters[0].parameter_offset,
					instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_S0);
				break;
			case P_INDEXED:
				as_load_indexed_reg (instruction->instruction_parameters[0].parameter_offset,
					instruction->instruction_parameters[0].parameter_data.ir,REGISTER_S0);
				break;
			case P_IMMEDIATE:
				as_move_i_r (instruction->instruction_parameters[0].parameter_data.i,REGISTER_S0);
				break;
			default:
				internal_error_in_function ("as_fmovel_instruction");
				return;
		}
		/* scvtf */
		store_l (0x9e620000 | (reg_num (REGISTER_S0)<<5) | freg);
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

static void as_instructions (struct instruction *instruction)
{
	while (instruction!=NULL){
		switch (instruction->instruction_icode){
			case IMOVE:
				instruction=as_move_instruction (instruction);
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
			case ICMP:
				as_cmp_instruction (instruction);
				break;
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
				store_l (0x14000000); /* b */
				as_branch_label (profile_r_label,JUMP_RELOCATION);
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
				as_lsl_instruction (instruction);
				break;
			case ILSR:
				as_lsr_instruction (instruction);
				break;
			case IASR:
				as_asr_instruction (instruction);
				break;
			case IMUL:
				as_mul_instruction (instruction,0x9b007c00); /* mul */
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
				as_logic_instruction (instruction,LOGICAL_OP_AND);
				break;
			case IOR:
				as_logic_instruction (instruction,LOGICAL_OP_ORR);
				break;
			case IEOR:
				as_logic_instruction (instruction,LOGICAL_OP_EOR);
				break;
			case IADDI:
				as_addi_instruction (instruction);
				break;
			case ILSLI:
				as_lsli_instruction (instruction);
				break;
			case ISEQ:
				as_set_condition_instruction (instruction,CONDITION_NE);
				break;
			case ISGE:
				as_set_condition_instruction (instruction,CONDITION_LT);
				break;
			case ISGEU:
				as_set_condition_instruction (instruction,CONDITION_LO);
				break;
			case ISGT:
				as_set_condition_instruction (instruction,CONDITION_LE);
				break;
			case ISGTU:
				as_set_condition_instruction (instruction,CONDITION_LS);
				break;
			case ISLE:
				as_set_condition_instruction (instruction,CONDITION_GT);
				break;
			case ISLEU:
				as_set_condition_instruction (instruction,CONDITION_HI);
				break;
			case ISLT:
				as_set_condition_instruction (instruction,CONDITION_GE);
				break;
			case ISLTU:
				as_set_condition_instruction (instruction,CONDITION_HS);
				break;
			case ISNE:
				as_set_condition_instruction (instruction,CONDITION_EQ);
				break;
			case ISO:
				as_set_condition_instruction (instruction,CONDITION_VC);
				break;
			case ISNO:
				as_set_condition_instruction (instruction,CONDITION_VS);
				break;
			case ITST:
				as_tst_instruction (instruction);
				break;
			case IBTST:
				instruction=as_btst_instruction (instruction);
				break;
			case ILOADSQB:
				as_loadsqb_instruction (instruction);
				break;
			case IMOVEDB:
				as_movew_instruction (instruction);
				break;
			case IMOVEB:
				as_moveb_instruction (instruction);
				break;
			case IMOVEQB:
				as_moveqb_instruction (instruction);
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
				as_adc_or_sbc_instruction (instruction,0x9a000000/*register*/);
				break;
			case ISBB:
				as_adc_or_sbc_instruction (instruction,0xda000000/*register*/);
				break;
			case IUMULH:
				as_mul_instruction (instruction,0x9bc07c00); /* umulh */
				break;
			case IWORD:
				store_l (instruction->instruction_parameters[0].parameter_data.i);
				break;
			case IROTR:
				as_rotr_instruction (instruction);
				break;
			case IADDO:
				as_adds_or_subs_instruction (instruction,0xab000000/*shifted register*/,0xb1000000/*immediate*/);
				break;
			case ISUBO:
				as_adds_or_subs_instruction (instruction,0xeb000000/*shifted register*/,0xf1000000/*immediate*/);
				break;
			case IFMOVE:
				as_fmove_instruction (instruction);
				break;
			case IFADD:
				as_dyadic_float_instruction (instruction,0x1e602800);
				break;
			case IFSUB:
				as_float_sub_or_div_instruction (instruction,0x1e603800);
				break;
			case IFCMP:
				as_compare_float_instruction (instruction);
				break;
			case IFDIV:
				as_float_sub_or_div_instruction (instruction,0x1e601800);
				break;
			case IFMUL:
				as_dyadic_float_instruction (instruction,0x1e600800);
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
				as_monadic_float_instruction (instruction,0x1e61c000);
				break;
			case IFNEG:
				as_monadic_float_instruction (instruction,0x1e614000);
				break;
			case IFABS:
				as_monadic_float_instruction (instruction,0x1e60c000);
				break;
			case IFSEQ:
				as_set_condition_instruction (instruction,CONDITION_NE);
				break;
			case IFSGE:
				as_set_condition_instruction (instruction,CONDITION_LT);
				break;
			case IFSGT:
				as_set_condition_instruction (instruction,CONDITION_LE);
				break;
			case IFSLE:
				as_set_condition_instruction (instruction,CONDITION_HI);
				break;
			case IFSLT:
				as_set_condition_instruction (instruction,CONDITION_PL);
				break;
			case IFSNE:
				as_set_vc_and_condition_instruction (instruction,CONDITION_EQ);
				break;
			default:
				internal_error_in_function ("as_instructions");
		}
		instruction=instruction->instruction_next;
	}
}

static void as_garbage_collect_test (struct basic_block *block)
{
	int n_cells;
	struct call_and_jump *new_call_and_jump;

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

	if (n_cells<=0xfff){
		as_subs_i_r_r (n_cells,REGISTER_X25,REGISTER_X25);

		store_l (0x54000000 | CONDITION_LO); /* blo */
		as_branch_label (&new_call_and_jump->cj_label,BRANCH_RELOCATION);
	} else if (n_cells<=0xffffff){
		as_sub_i_lsl_12_r_r (n_cells>>12,REGISTER_X25,REGISTER_X25);
		as_subs_i_r_r (n_cells & 0xfff,REGISTER_X25,REGISTER_X25);

		store_l (0x54000000 | CONDITION_MI); /* bmi */
		as_branch_label (&new_call_and_jump->cj_label,BRANCH_RELOCATION);
	} else
		internal_error_in_function ("as_garbage_collect_test");

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

	if (call_and_jump->cj_call_label!=NULL){
		as_str_r_id_update (REGISTER_X30,-8,B_STACK_POINTER);

		store_l (0x94000000); /* bl */
		as_branch_label (call_and_jump->cj_call_label,CALL_RELOCATION);
	}

	store_l (0x14000000); /* b */
	as_branch_label (&call_and_jump->cj_jump,JUMP_RELOCATION);
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
	
	as_move_d_r (block->block_profile_function_label,0,REGISTER_S0);

	as_mov_r_r (REGISTER_X30,REGISTER_X29);

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
	store_l (0x94000000); /* bl */
	as_branch_label (profile_label,CALL_RELOCATION);
}

#ifdef NEW_APPLY
extern LABEL *add_empty_node_labels[];

static void as_apply_update_entry (struct basic_block *block)
{
	int n_node_arguments;

	n_node_arguments=block->block_n_node_arguments;
	if (n_node_arguments<-200){
		store_l (0x14000000); /* b */
		as_branch_label (block->block_descriptor,JUMP_RELOCATION);

		if (block->block_ea_label==NULL){
			if (block->block_profile)
				as_profile_call (block);

			as_nop();
			as_nop();
			return;
		}

		n_node_arguments+=300;
	} else
		n_node_arguments+=200;

	if (block->block_profile)
		as_profile_call (block);

	if (n_node_arguments==0){
		store_l (0x14000000); /* b */
		as_branch_label (block->block_ea_label,JUMP_RELOCATION);

		as_nop();
	} else {
		store_l (0x94000000); /* bl */
		as_branch_label (add_empty_node_labels[n_node_arguments],CALL_RELOCATION);

		store_l (0x14000000); /* b */
		as_branch_label (block->block_ea_label,JUMP_RELOCATION);
	}
}
#endif

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
				as_move_l_r (block->block_ea_label,REGISTER_A3);

				store_l (0x14000000); /* b */
				as_branch_label (eval_upd_labels[n_node_arguments],JUMP_RELOCATION);
			} else {
				as_move_l_r (block->block_profile_function_label,REGISTER_S0);

				store_l (0x14000000); /* b */
				as_branch_label_with_addend (eval_upd_labels[n_node_arguments],JUMP_RELOCATION,-8);

				as_move_l_r (block->block_ea_label,REGISTER_A3);
				store_l (0x14000000 | ((-20>>2) & 0x3ffffff)); /* b */
			}
		} else {
			store_l (0x14000000); /* b */
			as_branch_label (block->block_ea_label,JUMP_RELOCATION);
		
			as_nop();
			as_nop();
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

	last_mapping_symbol->ms_code_offset = CURRENT_CODE_OFFSET;
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
	
	for_l (block,first_block,block_next){
#ifdef FUNCTION_LEVEL_LINKING
		if (block->block_begin_module){
			if (block->block_link_module){
				if (code_object_label!=NULL && CURRENT_CODE_OFFSET!=code_object_label->object_label_offset && block->block_labels){
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
				write_literals();
				as_new_code_module();
#endif
				*(struct object_label**)&block->block_last_instruction = code_object_label;
			}
		} else
			*(struct object_label**)&block->block_last_instruction = NULL;
#endif

		if (block->block_n_node_arguments>-100){
			as_node_entry_info (block);
		}
#ifdef NEW_APPLY
		else if (block->block_n_node_arguments<-100)
			as_apply_update_entry (block);
#endif

		as_labels (block->block_labels);

		if (block->block_profile)
			as_profile_call (block);

		if (block->block_n_new_heap_cells>0)
			as_garbage_collect_test (block);

		if (check_stack && (block->block_a_stack_check_size>0 || block->block_b_stack_check_size>0))
			as_check_stack (block);
		
		as_instructions (block->block_instructions);
	}

	write_literals();

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

static void write_file_header_and_section_headers (void)
{
	unsigned int offset;
	int n_code_relocation_sections,n_data_relocation_sections;
	int section_strings_size;
	
#ifdef FUNCTION_LEVEL_LINKING
	n_sections=n_code_sections+n_data_sections;
	n_local_section_and_mapping_symbols=n_sections+n_mapping_symbols;

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

	write_l (0x464c457f);
	write_l (0x00010102);
	write_l (0);
	write_l (0);
	write_l (0x00b70001);
	write_l (1);
	write_q (0);
	write_q (0);
	write_q (0x40);
	write_l (EF_ARM_EABI_UNKNOWN);
	write_l (0x00000040);
	write_l (0x00400000);
#ifdef FUNCTION_LEVEL_LINKING
	write_l (0x00010000 | (n_sections+n_code_relocation_sections+n_data_relocation_sections+4));
#else
	write_l (0x00010008);
#endif

	write_l (0);
	write_l (0);
	write_q (0);
	write_q (0);
	write_q (0);
	write_q (0);
	write_l (0);
	write_l (0);
	write_q (0);
	write_q (0);
#ifdef FUNCTION_LEVEL_LINKING
	offset=64+64*(n_sections+n_code_relocation_sections+n_data_relocation_sections+4);
#else
	offset=64+64*8;
#endif

	write_l (1);
	write_l (SHT_STRTAB);
	write_q (0);
	write_q (0);
	write_q (offset);
#ifdef FUNCTION_LEVEL_LINKING
	write_q ((27+section_strings_size+3) & -4);
#else
	write_q (60);
#endif
	write_l (0);
	write_l (0);
	write_q (1);
	write_q (0);
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
				write_q (SHF_ALLOC | SHF_EXECINSTR);
				write_q (0);
				write_q (offset+code_offset);
				write_q (code_section_length);
				write_l (0);
				write_l (0);
				write_q (4);
				write_q (0);

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
				write_q (SHF_ALLOC | SHF_WRITE);
				write_q (0);
				write_q (offset+data_offset);
				write_q (data_section_length);
				write_l (0);
				write_l (0);
				write_q (object_label->object_section_align8 ? 8 : 4);
				write_q (0);

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
					write_q (0);
					write_q (0);
					write_q (offset+code_relocations_offset);
					write_q (24*n_code_relocations_in_section);
					write_l (n_sections+n_code_relocation_sections+n_data_relocation_sections+2);
					write_l (2+object_label->object_label_section_n);
					write_q (4);
					write_q (24);
					section_string_offset+=13+n_digits (object_label->object_label_section_n);
					code_relocations_offset+=24*n_code_relocations_in_section;
				}
			}
		}
		offset+=24*n_code_relocations;

		data_relocations_offset=0;
	
		for_l (object_label,first_object_label,next){
			if (object_label->object_label_kind==DATA_CONTROL_SECTION){
				int n_data_relocations_in_section;
			
				n_data_relocations_in_section=object_label->object_label_n_relocations;
				
				if (n_data_relocations_in_section>0){
					write_l (section_string_offset);
					write_l (SHT_RELA);
					write_q (0);
					write_q (0);
					write_q (offset+data_relocations_offset);
					write_q (24*n_data_relocations_in_section);
					write_l (n_sections+n_code_relocation_sections+n_data_relocation_sections+2);
					write_l (2+n_code_sections+object_label->object_label_section_n);
					write_q (4);
					write_q (24);
					section_string_offset+=13+n_digits (object_label->object_label_section_n);
					data_relocations_offset+=24*n_data_relocations_in_section;
				}
			}
		}
		offset+=24*n_data_relocations;
	}
#else
	write_l (11);
	write_l (SHT_PROGBITS);
	write_q (SHF_ALLOC | SHF_EXECINSTR);
	write_q (0);
	write_q (offset);
	write_q (code_buffer_offset);
	write_l (0);
	write_l (0);
	write_q (4);
	write_q (0);
	offset+=(code_buffer_offset+3 ) & ~3;

	write_l (17);
	write_l (SHT_PROGBITS);
	write_q (SHF_ALLOC | SHF_WRITE);
	write_q (0);
	write_q (offset);
	write_q (data_buffer_offset);
	write_l (0);
	write_l (0);
	write_q (4);
	write_q (0);
	offset+=(data_buffer_offset+3) & ~3;

	write_l (23);
	write_l (SHT_RELA);
	write_q (0);
	write_q (0);
	write_q (offset);
	write_q (24*n_code_relocations);
	write_l (6);
	write_l (2);
	write_q (4);
	write_q (24);
	offset+=24*n_code_relocations;

	write_l (33);
	write_l (SHT_RELA);
	write_q (0);
	write_q (0);
	write_q (offset);
	write_q (24*n_data_relocations);
	write_l (6);
	write_l (3);
	write_q (4);
	write_q (24);
	offset+=24*n_data_relocations;
#endif

#ifdef FUNCTION_LEVEL_LINKING
	write_l (11+section_strings_size);
#else
	write_l (43);
#endif
	write_l (SHT_SYMTAB);
	write_q (0);
	write_q (0);
	write_q (offset);
#ifdef FUNCTION_LEVEL_LINKING
	write_q (24*(n_object_labels+n_local_section_and_mapping_symbols));
	write_l (n_sections+n_code_relocation_sections+n_data_relocation_sections+3);
	write_l (1+n_local_section_and_mapping_symbols);
#else
	write_q (24*n_object_labels);
	write_l (7);
	write_l (3);
#endif
	write_q (4);
	write_q (24);
#ifdef FUNCTION_LEVEL_LINKING
	offset+=24*(n_object_labels+n_local_section_and_mapping_symbols);
#else
	offset+=24*n_object_labels;
#endif

#ifdef FUNCTION_LEVEL_LINKING
	write_l (19+section_strings_size);
#else
	write_l (51);
#endif
	write_l (SHT_STRTAB);
	write_q (0);
	write_q (0);
	write_q (offset);
	write_q (string_table_offset);
	write_l (0);
	write_l (0);
	write_q (0);
	write_q (0);

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

static void relocate_code (void)
{
	struct relocation *relocation,**relocation_p;
	struct object_buffer *object_buffer;
	int code_buffer_offset;
	struct label *label;
	int instruction_offset;
	int v;

	object_buffer=first_code_buffer;
	code_buffer_offset=0;
	
	relocation_p=&first_code_relocation;
	
	while ((relocation=*relocation_p)!=NULL){
		label=relocation->relocation_label;

		switch (relocation->relocation_kind){
			case CALL_RELOCATION:
			case JUMP_RELOCATION:
				if (label->label_id==TEXT_LABEL_ID){
					instruction_offset=relocation->relocation_offset;

#ifdef FUNCTION_LEVEL_LINKING
					if (label->label_object_label!=relocation->relocation_object_label){
						v=label->label_offset-label->label_object_label->object_label_offset;

						++n_code_relocations;
						relocation->relocation_addend += v;
						relocation_p=&relocation->next;
						continue;
					} else
#endif
					{
						v=label->label_offset-instruction_offset;
						*relocation_p=relocation->next;
					}
				} else {
					++n_code_relocations;
					relocation_p=&relocation->next;

					instruction_offset=relocation->relocation_offset;
					v=0;
					continue;
				}

				v += relocation->relocation_addend;

				while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					code_buffer_offset+=BUFFER_SIZE;
				}
				
				if (instruction_offset-code_buffer_offset<=BUFFER_SIZE-4){
					int *instruction_p;
					
					instruction_p=(int*)(object_buffer->data+(instruction_offset-code_buffer_offset));

					v >>= 2;
					
					*instruction_p = (*instruction_p & 0xfc000000) | (v & 0x03ffffff);
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
					if (p2==end_buffer)
						p2=object_buffer->next->data;

					v >>= 2;
										
					*p0=v;
					*p1=v>>8;
					*p2=v>>16;
					*p3=(*p3 & 0xfc) | ((v>>24) & 0x3);
				}

				continue;
			case BRANCH_RELOCATION:
				if (label->label_id==TEXT_LABEL_ID){
					instruction_offset=relocation->relocation_offset;

#ifdef FUNCTION_LEVEL_LINKING
					if (label->label_object_label!=relocation->relocation_object_label){
						v=label->label_offset-label->label_object_label->object_label_offset;

						++n_code_relocations;
						relocation->relocation_addend += v;
						relocation_p=&relocation->next;
						continue;
					} else
#endif
					{
						v=label->label_offset-instruction_offset;
						*relocation_p=relocation->next;
					}
				} else {
					++n_code_relocations;
					relocation_p=&relocation->next;

					instruction_offset=relocation->relocation_offset;
					v=0;
					continue;
				}

				while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					code_buffer_offset+=BUFFER_SIZE;
				}
				
				if (instruction_offset-code_buffer_offset<=BUFFER_SIZE-4){
					int *instruction_p;
					
					instruction_p=(int*)(object_buffer->data+(instruction_offset-code_buffer_offset));

					v <<= 5-2;
					
					*instruction_p = (*instruction_p & 0xff00001f) | (v & 0x00ffffe0);
				} else {
					unsigned char *p0,*p1,*p2,*end_buffer;
					
					p0=object_buffer->data+(instruction_offset-code_buffer_offset);
					end_buffer=object_buffer->data+BUFFER_SIZE;
					p1=p0+1;
					if (p1==end_buffer)
						p1=object_buffer->next->data;
					p2=p1+1;
					if (p2==end_buffer)
						p2=object_buffer->next->data;

					v <<= 5-2;
			
					*p0=(*p0 & 0x1f) | (v & 0xe0);
					*p1=v>>8;
					*p2=v>>16;
				}

				continue;
			case ADRP_RELOCATION:
			case ADD_OFFSET_RELOCATION:
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
					relocation->relocation_addend += v;
				}

				continue;
			case LDR_PC_OFFSET_RELOCATION:
				if (label->label_id==TEXT_LABEL_ID){
					instruction_offset=relocation->relocation_offset;

#ifdef FUNCTION_LEVEL_LINKING
					if (label->label_object_label!=relocation->relocation_object_label){
						v=label->label_offset-label->label_object_label->object_label_offset;

						relocation->relocation_addend += v;

						++n_code_relocations;
						relocation_p=&relocation->next;
						continue;
					} else
#endif
					{
						v=label->label_offset-instruction_offset;
						*relocation_p=relocation->next;
					}
				} else {
					v=0;
					++n_code_relocations;
					relocation_p=&relocation->next;

					instruction_offset=relocation->relocation_offset;
					continue;
				}

				while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					code_buffer_offset+=BUFFER_SIZE;
				}
				
				if (instruction_offset-code_buffer_offset<=BUFFER_SIZE-4){
					int *instruction_p;
					
					instruction_p=(int*)(object_buffer->data+(instruction_offset-code_buffer_offset));

					v <<= (5-2);

					*instruction_p = (*instruction_p & 0xff00001f) | (v & 0x00ffffe0);
				} else {
					unsigned char *p0,*p1,*p2,*end_buffer;
					
					p0=object_buffer->data+(instruction_offset-code_buffer_offset);
					end_buffer=object_buffer->data+BUFFER_SIZE;
					p1=p0+1;
					if (p1==end_buffer)
						p1=object_buffer->next->data;
					p2=p1+1;
					if (p2==end_buffer)
						p2=object_buffer->next->data;

					v <<= (5-2);
					
					*p0 = (*p0 & 0x1f) | (v & 0xe0);
					*p1 = v>>8;
					*p2 = v>>16;
				}

				continue;
			case WORD_RELOCATION:
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
					relocation->relocation_addend += v;
				}
				continue;
			case RELATIVE_WORD_RELOCATION:
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
					relocation->relocation_addend += v;
				}
				continue;
			case TEST_BRANCH_RELOCATION:
				if (label->label_id==TEXT_LABEL_ID){
					instruction_offset=relocation->relocation_offset;

#ifdef FUNCTION_LEVEL_LINKING
					if (label->label_object_label!=relocation->relocation_object_label){
						v=label->label_offset-label->label_object_label->object_label_offset;

						++n_code_relocations;
						relocation->relocation_addend += v;
						relocation_p=&relocation->next;
						continue;
					} else
#endif
					{
						v=label->label_offset-instruction_offset;
						*relocation_p=relocation->next;
					}
				} else {
					++n_code_relocations;
					relocation_p=&relocation->next;

					instruction_offset=relocation->relocation_offset;
					v=0;
					continue;
				}

				while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					code_buffer_offset+=BUFFER_SIZE;
				}
				
				if (instruction_offset-code_buffer_offset<=BUFFER_SIZE-4){
					int *instruction_p;
					
					instruction_p=(int*)(object_buffer->data+(instruction_offset-code_buffer_offset));

					v <<= 5-2;
					
					*instruction_p = (*instruction_p & 0xfff8001f) | (v & 0x0007ffe0);
				} else {
					unsigned char *p0,*p1,*p2,*end_buffer;
					
					p0=object_buffer->data+(instruction_offset-code_buffer_offset);
					end_buffer=object_buffer->data+BUFFER_SIZE;
					p1=p0+1;
					if (p1==end_buffer)
						p1=object_buffer->next->data;
					p2=p1+1;
					if (p2==end_buffer)
						p2=object_buffer->next->data;

					v <<= 5-2;
			
					*p0=(*p0 & 0x1f) | (v & 0xe0);
					*p1=v>>8;
					*p2=(*p0 & 0xf8) | ((v>>16) & 7);
				}

				continue;
#ifdef FUNCTION_LEVEL_LINKING
			case DUMMY_BRANCH_RELOCATION:
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
			int *instruction_p;
			
			instruction_p=(int*)(object_buffer->data+(instruction_offset-code_buffer_offset));
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
	
	for_l (relocation,first_data_relocation,next){
		struct label *label;
		
		label=relocation->relocation_label;

		if (relocation->relocation_kind==WORD_RELOCATION){
			if (label->label_id==TEXT_LABEL_ID || (label->label_id==DATA_LABEL_ID
#if defined (RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL) && defined (FUNCTION_LEVEL_LINKING)
				&& !((label->label_flags & EXPORT_LABEL) && label->label_object_label->object_label_kind==EXPORTED_DATA_LABEL)
#endif
				))
			{
				int v;
	
				v = label->label_offset;
#ifdef FUNCTION_LEVEL_LINKING
				v -= label->label_object_label->object_label_offset;
#endif
				relocation->relocation_addend += v;
			}
		} else if (relocation->relocation_kind==LONG_WORD_RELOCATION){
			if (label->label_id==TEXT_LABEL_ID || (label->label_id==DATA_LABEL_ID
#if defined (RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL) && defined (FUNCTION_LEVEL_LINKING)
				&& !((label->label_flags & EXPORT_LABEL) && label->label_object_label->object_label_kind==EXPORTED_DATA_LABEL)
#endif
				))
			{
				long v;
					
				v = label->label_offset;
#ifdef FUNCTION_LEVEL_LINKING
				v -= label->label_object_label->object_label_offset;
#endif
				relocation->relocation_addend += v;
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
	write_q (0);
	write_q (0);
# ifndef FUNCTION_LEVEL_LINKING
	write_l (1);
	write_c (ELF32_ST_INFO (STB_LOCAL,STT_SECTION));
	write_c (0);
	write_w (2);
	write_q (0);
	write_q (0);

	write_l (7);
	write_c (ELF32_ST_INFO (STB_LOCAL,STT_SECTION));
	write_c (0);
	write_w (3);
	write_q (0);
	write_q (0);
# else
	{
		int section_n;

		for (section_n=0; section_n<n_code_sections; ++section_n){
			write_l (0);
			write_c (ELF32_ST_INFO (STB_LOCAL,STT_SECTION));
			write_c (0);
			write_w (2+section_n);
			write_q (0);
			write_q (0);
		}

		for (section_n=0; section_n<n_data_sections; ++section_n){
			write_l (0);
			write_c (ELF32_ST_INFO (STB_LOCAL,STT_SECTION));
			write_c (0);
			write_w (2+n_code_sections+section_n);
			write_q (0);
			write_q (0);
		}

		/* $x and $d symbols */
		section_n=0;
		{
			int n_generated_mapping_symbols;
			struct mapping_symbol *mapping_symbol_p;

			mapping_symbol_p=first_mapping_symbol;
			n_generated_mapping_symbols=0;

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
					write_l (1); /* $x */
					write_c (ELF32_ST_INFO (STB_LOCAL,STT_NOTYPE));
					write_c (0);
					write_w (2+section_n);
					write_q (0);
					write_q (0);
					++n_generated_mapping_symbols;
				}

				while (mapping_symbol_p!=NULL && mapping_symbol_p->ms_data_offset<next_control_section_code_offset){
					write_l (4); /* $d */
					write_c (ELF32_ST_INFO (STB_LOCAL,STT_NOTYPE));
					write_c (0);
					write_w (2+section_n);
					write_q (mapping_symbol_p->ms_data_offset-current_control_section_code_offset);
					write_q (0);
					++n_generated_mapping_symbols;				

					if (mapping_symbol_p->ms_code_offset!=next_control_section_code_offset){
						write_l (1); /* $x */
						write_c (ELF32_ST_INFO (STB_LOCAL,STT_NOTYPE));
						write_c (0);
						write_w (2+section_n);
						write_q (mapping_symbol_p->ms_code_offset-current_control_section_code_offset);
						write_q (0);
						++n_generated_mapping_symbols;
					}
					
					mapping_symbol_p=mapping_symbol_p->ms_next;
				}
				++section_n;				
			}

			if (section_n!=n_code_sections || n_generated_mapping_symbols!=n_mapping_symbols)
				internal_error_in_function ("write_object_labels");
		}		
	}
# endif
#endif

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
			{
				struct label *label;
				
				label=object_label->object_label_label;
				write_l (object_label->object_label_string_offset);
				write_c (ELF32_ST_INFO (STB_GLOBAL,STT_NOTYPE));
				write_c (0);
				write_w (0);
				write_q (0);
				write_q (0);
				break;
			}
			case EXPORTED_CODE_LABEL:
			{
				struct label *label;
				
				label=object_label->object_label_label;
				write_l (object_label->object_label_string_offset);
				write_c (ELF32_ST_INFO (STB_GLOBAL,STT_FUNC));
				write_c (label->label_flags & C_ENTRY_LABEL ? STV_DEFAULT : STV_HIDDEN);
#ifdef FUNCTION_LEVEL_LINKING
				write_w (2+label->label_object_label->object_label_section_n);
#else
				write_w (2);
#endif
#ifdef FUNCTION_LEVEL_LINKING
				write_q (label->label_offset - label->label_object_label->object_label_offset);
#else
				write_q (label->label_offset);
#endif
				write_q (0);
				break;
			}
			case EXPORTED_DATA_LABEL:
			{
				struct label *label;
				
				label=object_label->object_label_label;
				write_l (object_label->object_label_string_offset);
				write_c (ELF32_ST_INFO (STB_GLOBAL,STT_OBJECT));
				write_c (label->label_flags & C_ENTRY_LABEL ? STV_DEFAULT : STV_HIDDEN);
#ifdef FUNCTION_LEVEL_LINKING
				write_w (2+n_code_sections+label->label_object_label->object_label_section_n);
#else
				write_w (3);
#endif
#ifdef FUNCTION_LEVEL_LINKING
# ifdef RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL
				write_q (label->label_offset - current_text_or_data_object_label->object_label_offset);
# else
				write_q (label->label_offset - label->label_object_label->object_label_offset);
# endif
#else
				write_q (label->label_offset);
#endif
				write_q (0);
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
	write_zstring ("$x");
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

				write_q (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_q (ELF64_R_INFO (elf_label_number (label),R_AARCH64_CONDBR19));
#else
				write_q (ELF64_R_INFO (label->label_id,R_AARCH64_CONDBR19));
#endif
				write_q (relocation->relocation_addend);
				break;
			}
			case JUMP_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
#else
				if (label->label_id<0)
#endif
					internal_error_in_function ("write_code_relocations");

				write_q (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_q (ELF64_R_INFO (elf_label_number (label),R_AARCH64_JUMP26));
#else
				write_q (ELF64_R_INFO (label->label_id,R_AARCH64_JUMP26));
#endif
				write_q (relocation->relocation_addend);
				break;
			}
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

				write_q (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_q (ELF64_R_INFO (elf_label_number (label),R_AARCH64_CALL26));
#else
				write_q (ELF64_R_INFO (label->label_id,R_AARCH64_CALL26));
#endif
				write_q (relocation->relocation_addend);
				break;
			}
			case LDR_PC_OFFSET_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
#else
				if (label->label_id<0)
#endif
					internal_error_in_function ("write_code_relocations");

				write_q (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_q (ELF64_R_INFO (elf_label_number (label),R_AARCH64_LD_PREL_LO19));
#else
				write_q (ELF64_R_INFO (label->label_id,R_AARCH64_LD_PREL_LO19));
#endif
				write_q (relocation->relocation_addend);
				break;				
			}
			case ADRP_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
#else
				if (label->label_id<0)
#endif
					internal_error_in_function ("write_code_relocations");

				write_q (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_q (ELF64_R_INFO (elf_label_number (label),R_AARCH64_ADR_PREL_PG_HI21));
#else
				write_q (ELF64_R_INFO (label->label_id,R_AARCH64_ADR_PREL_PG_HI21));
#endif
				write_q (relocation->relocation_addend);
				break;				
			}
			case ADD_OFFSET_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
#else
				if (label->label_id<0)
#endif
					internal_error_in_function ("write_code_relocations");

				write_q (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_q (ELF64_R_INFO (elf_label_number (label),R_AARCH64_ADD_ABS_LO12_NC));
#else
				write_q (ELF64_R_INFO (label->label_id,R_AARCH64_ADD_ABS_LO12_NC));
#endif
				write_q (relocation->relocation_addend);
				break;				
			}
			case WORD_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
#else
				if (label->label_id<0)
#endif
					internal_error_in_function ("write_code_relocations");

				write_q (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_q (ELF64_R_INFO (elf_label_number (label),R_AARCH64_ABS32));
#else
				write_q (ELF64_R_INFO (label->label_id,R_AARCH64_ABS32));
#endif
				write_q (relocation->relocation_addend);
				break;				
			}
			case RELATIVE_WORD_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
#else
				if (label->label_id<0)
#endif
					internal_error_in_function ("write_code_relocations");

				write_q (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_q (ELF64_R_INFO (elf_label_number (label),R_AARCH64_PREL32));
#else
				write_q (ELF64_R_INFO (label->label_id,R_AARCH64_PREL32));
#endif
				write_q (relocation->relocation_addend);
				break;				
			}
			case TEST_BRANCH_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
#else
				if (label->label_id<0)
#endif
					internal_error_in_function ("write_code_relocations");

				write_q (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_q (ELF64_R_INFO (elf_label_number (label),R_AARCH64_TSTBR14));
#else
				write_q (ELF64_R_INFO (label->label_id,R_AARCH64_TSTBR14));
#endif
				write_q (relocation->relocation_addend);
				break;
			}
#ifdef FUNCTION_LEVEL_LINKING
			case DUMMY_BRANCH_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
				if (label->label_id==-1)
					internal_error_in_function ("write_code_relocations");

				write_q (relocation->relocation_offset - 4);
				write_q (ELF64_R_INFO (elf_label_number (label),R_AARCH64_NONE));
				write_q (0);
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
			case WORD_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==-1)
#else
				if (label->label_id<0)
#endif
					internal_error_in_function ("write_data_relocations");

				write_q (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_q (ELF64_R_INFO (elf_label_number (label),R_AARCH64_ABS32));
#else
				write_q (ELF64_R_INFO (label->label_id,R_AARCH64_ABS32));
#endif
				write_q (relocation->relocation_addend);
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
					internal_error_in_function ("write_data_relocations");

				write_q (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_q (ELF64_R_INFO (elf_label_number (label),R_AARCH64_ABS64));
#else
				write_q (ELF64_R_INFO (label->label_id,R_AARCH64_ABS64));
#endif
				write_q (relocation->relocation_addend);
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
	if (first_mapping_symbol!=NULL && last_mapping_symbol->ms_code_offset==end_code_offset)
		--n_mapping_symbols; /* $x at end of section */

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
