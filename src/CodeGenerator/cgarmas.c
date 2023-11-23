/*
	File:	 cgarmas.c
	Author:  John van Groningen
	Machine: ARM
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
# ifndef R_ARM_LDR_PC_G0
/* R_ARM_PC13 */
#  define R_ARM_LDR_PC_G0 4
# endif
# ifndef R_ARM_CALL
#  define R_ARM_CALL 28
# endif
# ifndef R_ARM_JUMP24
#  define R_ARM_JUMP24 29
# endif
# ifndef R_ARM_LDC_PC_G0
#  define R_ARM_LDC_PC_G0 67
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

#define LONG_WORD_RELOCATION 0
#define CALL_RELOCATION 1
#define BRANCH_RELOCATION 2
#define JUMP_RELOCATION 3
#define DUMMY_BRANCH_RELOCATION 4
#define LDR_OFFSET_RELOCATION 5 /* R_ARM_LDR_PC_G0 */
#define VLDR_OFFSET_RELOCATION 6 /* R_ARM_LDC_PC_G0 */
#define RELATIVE_LONG_WORD_RELOCATION 7

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

#define MAX_LITERAL_LDR_OFFSET 4092
#define MAX_LITERAL_VLDR_OFFSET 1008

static unsigned long literal_table_at_offset;
static unsigned char *literal_table_at_buffer_p;

static void write_branch_and_literals (void);

static void store_c (int c)
{
	if (code_buffer_free>0){
		--code_buffer_free;
		*code_buffer_p++=c;
	} else {
		struct object_buffer *new_buffer;

		current_code_buffer->size=BUFFER_SIZE;
	
		new_buffer=memory_allocate (sizeof (struct object_buffer));
	
		new_buffer->size=0;
		new_buffer->next=NULL;
	
		current_code_buffer->next=new_buffer;
		current_code_buffer=new_buffer;
		code_buffer_offset+=BUFFER_SIZE;

		code_buffer_free=BUFFER_SIZE-1;
		code_buffer_p=new_buffer->data;

		*code_buffer_p++=c;

		if (literal_table_at_offset-(unsigned long)code_buffer_offset <= (unsigned long) BUFFER_SIZE)
			literal_table_at_buffer_p = current_code_buffer->data + (literal_table_at_offset-(unsigned long)code_buffer_offset);
	}
}

static void store_l (ULONG i)
{
	if (code_buffer_p>=literal_table_at_buffer_p)
		write_branch_and_literals();

	store_c (i);
	store_c (i>>8);
	store_c (i>>16);
	store_c (i>>24);
}

static void store_l_no_literal_table (ULONG i)
{
	store_c (i);
	store_c (i>>8);
	store_c (i>>16);
	store_c (i>>24);
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

struct literal_entry {
	LABEL				  * le_label;
	int						le_offset;
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
			n_mapping_symbols+=1; /* $d at begin of section, $a */
		else
			n_mapping_symbols+=2; /* $d and $a */

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

			if (literal_entry->le_label){
				literal_entry->le_label->label_flags &= ~HAS_LITERAL_ENTRY;
				if (!pic_flag){
					store_l_no_literal_table (literal_entry->le_offset);
					store_label_in_code_section (literal_entry->le_label);
				} else {
					store_l_no_literal_table (current_code_offset - load_data_offset -12 + literal_entry->le_offset);
					store_relative_label_in_code_section (literal_entry->le_label);
				}
			} else {
				if (literal_entry->le_r_p==NULL){
					store_l_no_literal_table (literal_entry->le_offset);
				} else {
					// to do: align 8
					store_l_no_literal_table (((LONG*)(literal_entry->le_r_p))[0]);
					store_l_no_literal_table (((LONG*)(literal_entry->le_r_p))[1]);
				}
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
	new_relocation->relocation_kind=relocation_kind;
}

static void write_branch_and_literals (void)
{
	LABEL *new_label;

	literal_table_at_offset = 0ul-1ul;
	literal_table_at_buffer_p = (unsigned char*)0ul-1ul;

	new_label=allocate_memory_from_heap (sizeof (struct label));
	
	store_l (0xea000000); /* b */
	as_branch_label (new_label,JUMP_RELOCATION);

	write_literals();

	new_label->label_flags=0;
	new_label->label_id=TEXT_LABEL_ID;
#ifdef FUNCTION_LEVEL_LINKING
	new_label->label_object_label=code_object_label;
#endif
	new_label->label_offset=CURRENT_CODE_OFFSET;
}

static void as_literal_label_ldr (struct label *label)
{
	struct relocation *new_relocation;
	unsigned long current_code_offset;

	new_relocation=fast_memory_allocate_type (struct relocation);
	
	*last_code_relocation_l=new_relocation;
	last_code_relocation_l=&new_relocation->next;
	new_relocation->next=NULL;

	current_code_offset = CURRENT_CODE_OFFSET-4;

	if (current_code_offset+MAX_LITERAL_LDR_OFFSET < literal_table_at_offset){
		literal_table_at_offset = current_code_offset+MAX_LITERAL_LDR_OFFSET;

		if (literal_table_at_offset-(unsigned long)code_buffer_offset <= (unsigned long) BUFFER_SIZE)
			literal_table_at_buffer_p = current_code_buffer->data + (literal_table_at_offset-(unsigned long)code_buffer_offset);
	}
	
	new_relocation->relocation_label=label;
	new_relocation->relocation_offset=current_code_offset;
	label->label_offset=current_code_offset; /* for pic store offset of load instead, label offset stored by write_literals */
#ifdef FUNCTION_LEVEL_LINKING
	new_relocation->relocation_object_label=code_object_label;
#endif
	new_relocation->relocation_kind=LDR_OFFSET_RELOCATION;
}

static void as_literal_label_vldr (struct label *label)
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
	
	new_relocation->relocation_label=label;
	new_relocation->relocation_offset=current_code_offset;
	label->label_offset=current_code_offset; /* for pic store offset of load instead, label offset stored by write_literals */
#ifdef FUNCTION_LEVEL_LINKING
	new_relocation->relocation_object_label=code_object_label;
#endif
	new_relocation->relocation_kind=VLDR_OFFSET_RELOCATION;
}

static void as_literal_constant_entry (int offset)
{
	struct literal_entry *new_literal_entry;

	new_literal_entry=allocate_memory_from_heap (sizeof (struct literal_entry));

	new_literal_entry->le_label=NULL;
	new_literal_entry->le_offset=offset;
	new_literal_entry->le_r_p=NULL;

	*literal_entry_l=new_literal_entry;
	literal_entry_l=&new_literal_entry->le_next;
	
	new_literal_entry->le_next=NULL;
	
	as_literal_label_ldr (&new_literal_entry->le_load_instruction_label);
}

static void as_literal_label_entry (LABEL *label,int offset)
{
	struct literal_entry *new_literal_entry;

	if (label->label_flags & HAS_LITERAL_ENTRY && label->label_literal_entry->le_offset==offset)
		new_literal_entry=label->label_literal_entry;
	else {
		new_literal_entry=allocate_memory_from_heap (sizeof (struct literal_entry));

		new_literal_entry->le_label=label;
		new_literal_entry->le_offset=offset;
		new_literal_entry->le_r_p=NULL;

		*literal_entry_l=new_literal_entry;
		literal_entry_l=&new_literal_entry->le_next;
		
		new_literal_entry->le_next=NULL;
		
		if (!pic_flag){
			label->label_flags |= HAS_LITERAL_ENTRY;
			label->label_literal_entry=new_literal_entry;
		}
	}
	
	as_literal_label_ldr (&new_literal_entry->le_load_instruction_label);
}

static void as_float_load_int_literal_entry (int offset)
{
	struct literal_entry *new_literal_entry;
	
	new_literal_entry=allocate_memory_from_heap (sizeof (struct literal_entry));

	new_literal_entry->le_label=NULL;
	new_literal_entry->le_offset=offset;
	new_literal_entry->le_r_p=NULL;

	*literal_entry_l=new_literal_entry;
	literal_entry_l=&new_literal_entry->le_next;
	
	new_literal_entry->le_next=NULL;

	as_literal_label_vldr (&new_literal_entry->le_load_instruction_label);
}

static void as_float_literal_entry (DOUBLE *r_p)
{
	struct literal_entry *new_literal_entry;
	
	new_literal_entry=allocate_memory_from_heap (sizeof (struct literal_entry));

	new_literal_entry->le_r_p=r_p;
	new_literal_entry->le_label=NULL;
	new_literal_entry->le_offset=0;

	*literal_entry_l=new_literal_entry;
	literal_entry_l=&new_literal_entry->le_next;
	
	new_literal_entry->le_next=NULL;

	as_literal_label_vldr (&new_literal_entry->le_load_instruction_label);
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
		--n_mapping_symbols; /* $a at end of section */

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
	++n_mapping_symbols; /* $a at begin of section */
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

static unsigned char real_reg_num [16]
	= { 13, 10, 9, 11, 8, 7, 6, 4, 3, 2, 1, 0, 5, 12, 14, 15 };

#define ESP (-6)
#define EBP (-3)
#define EAX 0
#define REGISTER_PC 8
#define REGISTER_R5 5

#define REGISTER_S0 6
#define REGISTER_S1 7

static int immediate_shift (unsigned int i)
{
	if ((i & ~0xff)==0) return 0;
	if ((i & ~0x3fc)==0) return 2;
	if ((i & ~0xff0)==0) return 4;
	if ((i & ~0x3fc0)==0) return 6;
	if ((i & ~0xff00)==0) return 8;
	if ((i & ~0x3fc00)==0) return 10;
	if ((i & ~0xff000)==0) return 12;
	if ((i & ~0x3fc0000)==0) return 14;
	if ((i & ~0xff0000)==0) return 16;
	if ((i & ~0x3fc0000)==0) return 18;
	if ((i & ~0xff00000)==0) return 20;
	if ((i & ~0x3fc00000)==0) return 22;
	if ((i & ~0xff000000)==0) return 24;
	if ((i & ~0xfc000003)==0) return 26;
	if ((i & ~0xf000000f)==0) return 28;
	if ((i & ~0xc000003f)==0) return 30;
	return -1;
}

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

static void as_move_i_r (int i,int reg1)
{
	int shift;
	
	shift = immediate_shift (i);
	if (shift>=0)
		store_l_is (0xe3a00000 | (reg_num (reg1)<<12),i,shift); /* mov rd,#i<<s */
	else {
		shift = immediate_shift (~i);
		if (shift>=0)
			store_l_is (0xe3e00000 | (reg_num (reg1)<<12),~i,shift); /* mvn rd,#i<<s */
		else {
			store_l (0xe59f0000 | (reg_num (reg1)<<12)); /* ldr rt,[pc+imm] */
			as_literal_constant_entry (i);
		}
	}
}

static void as_mov_r_r (int s_reg,int d_reg)
{
	int i_code;

	i_code = 0xe1A00000 | (reg_num (d_reg)<<12) | reg_num (s_reg);

	store_l (i_code); 
}

static void as_ldr_id_r (int offset,int sa_reg,int d_reg)
{
	int i_code;

	i_code = 0xe5100000 | (reg_num (sa_reg)<<16) | (reg_num (d_reg)<<12);

	if (offset<0)
		i_code |= (-offset) & 0xfff;
	else
		i_code |= (1<<23) | (offset & 0xfff);

	store_l (i_code); 
}

static void as_ldr_id_r_update (int offset,int sa_reg,int d_reg)
{
	int i_code;

	i_code = 0xe5300000 | (reg_num (sa_reg)<<16) | (reg_num (d_reg)<<12);

	if (offset<0)
		i_code |= (-offset) & 0xfff;
	else
		i_code |= (1<<23) | (offset & 0xfff);

	store_l (i_code); 
}

static void as_ldr_id_r_post_add (int offset,int sa_reg,int d_reg)
{
	int i_code;

	i_code = 0xe4100000 | (reg_num (sa_reg)<<16) | (reg_num (d_reg)<<12);

	if (offset<0)
		i_code |= (-offset) & 0xfff;
	else
		i_code |= (1<<23) | (offset & 0xfff);

	store_l (i_code); 
}

static void as_ldrb_id_r (int offset,int sa_reg,int d_reg)
{
	int i_code;

	i_code = 0xe5500000 | (reg_num (sa_reg)<<16) | (reg_num (d_reg)<<12);

	if (offset<0)
		i_code |= (-offset) & 0xfff;
	else
		i_code |= (1<<23) | (offset & 0xfff);

	store_l (i_code); 
}

static void as_ldrsh_id_r (int offset,int sa_reg,int d_reg)
{
	int i_code;

	i_code = 0xe15000f0 | (reg_num (sa_reg)<<16) | (reg_num (d_reg)<<12);

	if (offset<0)
		i_code |= (((-offset)<<4) & 0xf00) | ((-offset) & 0xf);
	else
		i_code |= (1<<23) | ((offset<<4) & 0xf00) | (offset & 0xf);

	store_l (i_code); 
}

static void as_ldr_ix_r (int reg_n,int reg_m,int shift,int reg_t)
{
	store_l (0xe7900000 | (reg_num (reg_n)<<16) | (reg_num (reg_t)<<12) | (shift<<7) | reg_num (reg_m));
}

static void as_ldrb_ix_r (int reg_n,int reg_m,int shift,int reg_t)
{
	store_l (0xe7d00000 | (reg_num (reg_n)<<16) | (reg_num (reg_t)<<12) | (shift<<7) | reg_num (reg_m));
}

static void as_subs_is_r_r (int i,int shift,int s_reg,int d_reg)
{
	store_l_is (0xe2500000 | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<12),i,shift);
}

#define ARM_OP_LSL 0
#define ARM_OP_LSR 1
#define ARM_OP_ASR 2
#define ARM_OP_ROR 3

static void as_shift_i_r_r (int shift_op,int i,int reg_m,int reg_d)
{
	store_l (0xe1a00000 | (shift_op<<5) | (reg_num (reg_d)<<12) | (i<<7) | reg_num (reg_m));
}

static void as_lsl_i_r_r (int i,int reg_m,int reg_d)
{
	store_l (0xe1a00000 | (ARM_OP_LSL<<5) | (reg_num (reg_d)<<12) | (i<<7) | reg_num (reg_m));
}

static void as_lsr_i_r_r (int i,int reg_m,int reg_d)
{
	store_l (0xe1a00000 | (ARM_OP_LSR<<5) | (reg_num (reg_d)<<12) | (i<<7) | reg_num (reg_m));
}

static void as_asr_i_r_r (int i,int reg_m,int reg_d)
{
	store_l (0xe1a00000 | (ARM_OP_ASR<<5) | (reg_num (reg_d)<<12) | (i<<7) | reg_num (reg_m));
}

static void as_shift_r_r_r (int shift_op,int reg_m,int reg_n,int reg_d)
{
	store_l (0xe1a00010 | (shift_op<<5) | (reg_num (reg_d)<<12) | (reg_num (reg_m)<<8) | reg_num (reg_n));
}

static void as_str_r_id (int s_reg,int offset,int da_reg)
{
	int i_code;

	i_code = 0xe5000000 | (reg_num (da_reg)<<16) | (reg_num (s_reg)<<12);

	if (offset<0)
		i_code |= (-offset) & 0xfff;
	else
		i_code |= (1<<23) | (offset & 0xfff);

	store_l (i_code); 
}

static void as_str_r_id_update (int s_reg,int offset,int da_reg)
{
	int i_code;

	i_code = 0xe5200000 | (reg_num (da_reg)<<16) | (reg_num (s_reg)<<12);

	if (offset<0)
		i_code |= (-offset) & 0xfff;
	else
		i_code |= (1<<23) | (offset & 0xfff);

	store_l (i_code); 
}

static void as_str_r_id_post_add (int s_reg,int offset,int da_reg)
{
	int i_code;

	i_code = 0xe4000000 | (reg_num (da_reg)<<16) | (reg_num (s_reg)<<12);

	if (offset<0)
		i_code |= (-offset) & 0xfff;
	else
		i_code |= (1<<23) | (offset & 0xfff);

	store_l (i_code); 
}

static void as_str_r_ix (int reg_t,int reg_n,int reg_m,int shift)
{
	store_l (0xe7800000 | (reg_num (reg_n)<<16) | (reg_num (reg_t)<<12) | (shift<<7) | reg_num (reg_m));
}

static void as_strb_r_id (int s_reg,int offset,int da_reg)
{
	int i_code;

	i_code = 0xe5400000 | (reg_num (da_reg)<<16) | (reg_num (s_reg)<<12);

	if (offset<0)
		i_code |= (-offset) & 0xfff;
	else
		i_code |= (1<<23) | (offset & 0xfff);

	store_l (i_code); 
}

static void as_strb_r_ix (int reg_t,int reg_n,int reg_m,int shift)
{
	store_l (0xe7c00000 | (reg_num (reg_n)<<16) | (reg_num (reg_t)<<12) | (shift<<7) | reg_num (reg_m));
}

static void as_tst_ir_r (int i,int shift,int reg)
{
	store_l_is (0xe3100000 | (reg_num (reg)<<16),i,shift);
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

	store_l (i_code); 
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

	store_l (i_code); 
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

	store_l (i_code); 
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

	store_l (i_code); 
}

#define ARM_OP_AND 0
#define ARM_OP_EOR 1
#define ARM_OP_SUB 2
#define ARM_OP_RSB 3
#define ARM_OP_ADD 4
#define ARM_OP_ADC 5
#define ARM_OP_SBC 6
#define ARM_OP_CMP 10
#define ARM_OP_CMN 11
#define ARM_OP_ORR 12
#define ARM_OP_BIC 14
#define ARM_OP_MVN 15

static void as_op_r_r_r (int op,int reg_m,int reg_n,int reg_d)
{
	store_l (0xe0000000 | (op<<21) | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<12) | reg_num(reg_m));
}

static void as_x_op_r_r_r (int x_op,int reg_m,int reg_n,int reg_d)
{
	store_l (0xe0000000 | (x_op<<20) | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<12) | reg_num(reg_m));
}

static void as_op_is_r_r (int op,int i,int shift,int s_reg,int d_reg)
{
	store_l_is (0xe2000000 | (op<<21) | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<12),i,shift);
}

static void as_x_op_is_r_r (int x_op,int i,int shift,int s_reg,int d_reg)
{
	store_l_is (0xe2000000 | (x_op<<20) | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<12),i,shift);
}

static void as_add_r_r_r (int reg_m,int reg_n,int reg_d)
{
	store_l (0xe0000000 | (ARM_OP_ADD<<21) | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<12) | reg_num (reg_m));
}

static void as_add_r_r_r_no_literal_table (int reg_m,int reg_n,int reg_d)
{
	store_l_no_literal_table (0xe0000000 | (ARM_OP_ADD<<21) | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<12) | reg_num (reg_m));
}

static void as_add_r_lsl_r_r (int reg_m,int lsl_m,int reg_n,int reg_d)
{
	store_l (0xe0000000 | (ARM_OP_ADD<<21) | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<12) | (lsl_m<<7) | reg_num (reg_m));
}

static void as_add_r_lsr_r_r (int reg_m,int lsr_m,int reg_n,int reg_d)
{
	store_l (0xe0000020 | (ARM_OP_ADD<<21) | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<12) | (lsr_m<<7) | reg_num (reg_m));
}

static void as_add_r_asr_r_r (int reg_m,int asr_m,int reg_n,int reg_d)
{
	store_l (0xe0000040 | (ARM_OP_ADD<<21) | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<12) | (asr_m<<7) | reg_num (reg_m));
}

static void as_add_is_r_r (int i,int shift,int s_reg,int d_reg)
{
	store_l_is (0xe2000000 | (ARM_OP_ADD<<21) | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<12),i,shift);
}

static void as_add_cc_is_r_r (int cc,int i,int shift,int s_reg,int d_reg)
{
	store_l_is (0x02000000 | (cc<<28) | (ARM_OP_ADD<<21) | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<12),i,shift);
}

static void as_sub_r_r_r (int reg_m,int reg_n,int reg_d)
{
	store_l (0xe0000000 | (ARM_OP_SUB<<21) | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<12) | reg_num(reg_m));
}

static void as_sub_r_lsl_r_r (int reg_m,int lsl_m,int reg_n,int reg_d)
{
	store_l (0xe0000000 | (ARM_OP_SUB<<21) | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<12) | (lsl_m<<7) | reg_num(reg_m));
}

static void as_sub_r_lsr_r_r (int reg_m,int lsr_m,int reg_n,int reg_d)
{
	store_l (0xe0000020 | (ARM_OP_SUB<<21) | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<12) | (lsr_m<<7) | reg_num(reg_m));
}

static void as_sub_r_asr_r_r (int reg_m,int asr_m,int reg_n,int reg_d)
{
	store_l (0xe0000040 | (ARM_OP_SUB<<21) | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<12) | (asr_m<<7) | reg_num(reg_m));
}

static void as_sub_is_r_r (int i,int shift,int s_reg,int d_reg)
{
	store_l_is (0xe2000000 | (ARM_OP_SUB<<21) | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<12),i,shift);
}

static void as_sub_cc_is_r_r (int cc,int i,int shift,int s_reg,int d_reg)
{
	store_l_is (0x02000000 | (cc<<28) | (ARM_OP_SUB<<21) | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<12),i,shift);
}

static void as_rsb_is_r_r (int i,int shift,int s_reg,int d_reg)
{
	store_l_is (0xe2000000 | (ARM_OP_RSB<<21) | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<12),i,shift);
}

static void as_cmp_r_r (int reg_m,int reg_n)
{
	store_l (0xe0100000 | (ARM_OP_CMP<<21) | (reg_num (reg_n)<<16) | reg_num(reg_m));
}

static void as_cmp_is_r (int i,int shift,int s_reg)
{
	store_l_is (0xe2100000 | (ARM_OP_CMP<<21) | (reg_num (s_reg)<<16),i,shift);
}

static void as_cmn_is_r (int i,int shift,int s_reg)
{
	store_l_is (0xe2100000 | (ARM_OP_CMN<<21) | (reg_num (s_reg)<<16),i,shift);
}

static void as_and_is_r_r (int i,int shift,int s_reg,int d_reg)
{
	store_l_is (0xe2000000 | (ARM_OP_AND<<21) | (reg_num (s_reg)<<16) | (reg_num (d_reg)<<12),i,shift);
}

static void as_and_r_lsr_r_r (int reg_m,int lsr_m,int reg_n,int reg_d)
{
	store_l (0xe0000020 | (ARM_OP_AND<<21) | (reg_num (reg_n)<<16) | (reg_num (reg_d)<<12) | (lsr_m<<7) | reg_num(reg_m));
}

static void as_mla_r_r_r_r (int n_reg,int m_reg,int a_reg,int d_reg)
{
	store_l (0xe0200090 | (reg_num (d_reg)<<16) | (reg_num (a_reg)<<12) | (reg_num (m_reg)<<8) | reg_num (n_reg));
}

static void as_mls_r_r_r_r (int n_reg,int m_reg,int a_reg,int d_reg)
{
	store_l (0xe0600090 | (reg_num (d_reg)<<16) | (reg_num (a_reg)<<12) | (reg_num (m_reg)<<8) | reg_num (n_reg));
}

static void as_smmul_r_r_r (int n_reg,int m_reg,int d_reg)
{
	store_l (0xe750f010 | (reg_num (d_reg)<<16) | (reg_num (m_reg)<<8) | reg_num (n_reg));
}

static void as_smmla_r_r_r (int n_reg,int m_reg,int a_reg,int d_reg)
{
	store_l (0xe7500010 | (reg_num (d_reg)<<16) | (reg_num (a_reg)<<12) | (reg_num (m_reg)<<8) | reg_num (n_reg));
}

static void as_smmls_r_r_r (int n_reg,int m_reg,int a_reg,int d_reg)
{
	store_l (0xe75000d0 | (reg_num (d_reg)<<16) | (reg_num (a_reg)<<12) | (reg_num (m_reg)<<8) | reg_num (n_reg));
}

static void as_move_d_r (LABEL *label,int arity,int reg1)
{
	store_l (0xe59f0000 | (reg_num (reg1)<<12)); /* ldr rt,[pc+imm] */
	as_literal_label_entry (label,arity);
	if (pic_flag)
		as_add_r_r_r_no_literal_table (REGISTER_PC,reg1,reg1);
}

static void as_move_l_r (LABEL *label,int reg1)
{
	store_l (0xe59f0000 | (reg_num (reg1)<<12)); /* ldr rt,[pc+imm] */
	as_literal_label_entry (label,0);
	if (pic_flag)
		as_add_r_r_r_no_literal_table (REGISTER_PC,reg1,reg1);
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

static void as_move_parameter_reg (struct parameter *parameter_p,int reg)
{
	switch (parameter_p->parameter_type){
		case P_REGISTER:
			as_mov_r_r (parameter_p->parameter_data.reg.r,reg);
			return;
		case P_DESCRIPTOR_NUMBER:
			as_move_d_r (parameter_p->parameter_data.l,parameter_p->parameter_offset,reg);
			return;
		case P_IMMEDIATE:
			as_move_i_r (parameter_p->parameter_data.i,reg);
			return;
		case P_INDIRECT:
			as_ldr_id_r (parameter_p->parameter_offset,parameter_p->parameter_data.reg.r,reg);
			return;
		case P_INDEXED:
			as_load_indexed_reg (parameter_p->parameter_offset,parameter_p->parameter_data.ir,reg);
			return;
		case P_POST_INCREMENT:
			as_ldr_id_r_post_add (4,parameter_p->parameter_data.reg.r,reg);
			return;
		case P_INDIRECT_WITH_UPDATE:
			as_ldr_id_r_update (parameter_p->parameter_offset,parameter_p->parameter_data.reg.r,reg);
			return;
		case P_INDIRECT_POST_ADD:
			as_ldr_id_r_post_add (parameter_p->parameter_offset,parameter_p->parameter_data.reg.r,reg);
			return;
		case P_LABEL:
			as_move_l_r (parameter_p->parameter_data.l,reg);
			as_ldr_id_r (0,reg,reg);
			return;
		default:
			internal_error_in_function ("as_move_parameter_reg");
			return;
	}
}

static void as_move_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		as_move_parameter_reg (&instruction->instruction_parameters[0],
			instruction->instruction_parameters[1].parameter_data.reg.r);
		return;
	} else if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
		switch (instruction->instruction_parameters[1].parameter_type){
			case P_INDIRECT:
				as_str_r_id (instruction->instruction_parameters[0].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_PRE_DECREMENT:
				as_str_r_id_update (instruction->instruction_parameters[0].parameter_data.reg.r,
					-4,instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_INDEXED:
			{
				int reg_0,reg_s,reg1,reg2,offset;
		
				reg_0 = instruction->instruction_parameters[0].parameter_data.reg.r;
				reg_s = REGISTER_S0;

				offset=instruction->instruction_parameters[1].parameter_offset;
				reg1=instruction->instruction_parameters[1].parameter_data.ir->a_reg.r;
				reg2=instruction->instruction_parameters[1].parameter_data.ir->d_reg.r;

				if ((offset & -4)!=0){
					int shift;
		
					shift = immediate_shift (offset>>2);
					if (shift>=0){
						as_add_is_r_r (offset>>2,shift,reg1,reg_s);
						as_str_r_ix (reg_0,reg_s,reg2,offset & 3);
						return;
					}
				} else {
					as_str_r_ix (reg_0,reg1,reg2,offset & 3);
					return;				
				}

				internal_error_in_function ("as_move_instruction");
				return;
			}
			case P_POST_INCREMENT:
				as_ldr_id_r_post_add (4,instruction->instruction_parameters[1].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_INDIRECT_WITH_UPDATE:
				as_str_r_id_update (instruction->instruction_parameters[0].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_INDIRECT_POST_ADD:
				as_str_r_id_post_add (instruction->instruction_parameters[0].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_LABEL:
				as_move_l_r (instruction->instruction_parameters[1].parameter_data.l,REGISTER_S0);
				as_str_r_id (instruction->instruction_parameters[0].parameter_data.reg.r,0,REGISTER_S0);
				return;
		}
	} else {
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_INDIRECT:
				as_ldr_id_r (instruction->instruction_parameters[0].parameter_offset,
					instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_S0);
				break;
			case P_INDEXED:
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
				as_ldr_id_r_post_add (4,instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_S0);
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
				return;
		}

		switch (instruction->instruction_parameters[1].parameter_type){
			case P_INDIRECT:
				as_str_r_id (REGISTER_S0,
					instruction->instruction_parameters[1].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_PRE_DECREMENT:
				as_str_r_id_update (REGISTER_S0,-4,instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_INDEXED:
			{
				int reg_0,reg_s,reg1,reg2,offset;
		
				reg_0 = REGISTER_S0;
				reg_s = REGISTER_S1;

				offset=instruction->instruction_parameters[1].parameter_offset;
				reg1=instruction->instruction_parameters[1].parameter_data.ir->a_reg.r;
				reg2=instruction->instruction_parameters[1].parameter_data.ir->d_reg.r;

				if ((offset & -4)!=0){
					int shift;
		
					shift = immediate_shift (offset>>2);
					if (shift>=0){
						as_add_is_r_r (offset>>2,shift,reg1,reg_s);
						as_str_r_ix (reg_0,reg_s,reg2,offset & 3);
						return;
					}
				} else {
					as_str_r_ix (reg_0,reg1,reg2,offset & 3);
					return;				
				}

				internal_error_in_function ("as_move_instruction");
				return;
			}
			case P_INDIRECT_WITH_UPDATE:
				as_str_r_id_update (REGISTER_S0,instruction->instruction_parameters[1].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_INDIRECT_POST_ADD:
				as_str_r_id_post_add (REGISTER_S0,instruction->instruction_parameters[1].parameter_offset,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_LABEL:
				as_move_l_r (instruction->instruction_parameters[1].parameter_data.l,REGISTER_S1);
				as_str_r_id (REGISTER_S0,0,REGISTER_S1);
				return;
		}
	}
	internal_error_in_function ("as_move_instruction");
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
			store_l (0xe9300000 | (reg_num (s_reg)<<16) | register_list); /* ldmdb */
			return;
		} else if (instruction->instruction_parameters[0].parameter_type==P_POST_INCREMENT){
			store_l (0xe8b00000 | (reg_num (s_reg)<<16) | register_list); /* ldmia */
			return;
		}
	} else {
		int d_reg,n;
		
		d_reg = instruction->instruction_parameters[n_regs].parameter_data.reg.r;

		for (n=0; n<n_regs; ++n)
			register_list |= 1u << (unsigned)reg_num(instruction->instruction_parameters[n].parameter_data.reg.r);

		if (instruction->instruction_parameters[n_regs].parameter_type==P_PRE_DECREMENT){
			store_l (0xe9200000 | (reg_num (d_reg)<<16) | register_list); /* stmdb */
			return;
		} else if (instruction->instruction_parameters[n_regs].parameter_type==P_POST_INCREMENT){
			store_l (0xe8a00000 | (reg_num (d_reg)<<16) | register_list); /* stmia */
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

			store_l (0xe59f0000 | (reg_num (REGISTER_S0)<<12)); /* ldr rt,[pc+imm] */
			as_literal_constant_entry (i);
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

			store_l (0xe59f0000 | (reg_num (REGISTER_S0)<<12)); /* ldr rt,[pc+imm] */
			as_literal_constant_entry (i);
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

	store_l (0xe59f0000 | (reg_num (REGISTER_S0)<<12)); /* ldr rt,[pc+imm] */
	as_literal_constant_entry (i);

	as_add_r_r_r (REGISTER_S0,s_reg,d_reg);
}

static void as_add_or_sub_x_instruction (struct instruction *instruction,int arm_x_op,int arm_x_op_r)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_x_op_r_r_r (arm_x_op,instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
		{
			int shift,i;
			
			i = instruction->instruction_parameters[0].parameter_data.i;
			shift = immediate_shift (i);
			if (shift>=0){
				as_x_op_is_r_r (arm_x_op,i,shift,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}
			
			shift = immediate_shift (-i);
			if (shift>=0){
				as_x_op_is_r_r (arm_x_op_r,-i,shift,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;			
			}

			store_l (0xe59f0000 | (reg_num (REGISTER_S0)<<12)); /* ldr rt,[pc+imm] */
			as_literal_constant_entry (i);
			break;
		}
		default:
			as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
	}

	as_x_op_r_r_r (arm_x_op,REGISTER_S0,instruction->instruction_parameters[1].parameter_data.reg.r,
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
	
	store_l (0xe59f0000 | (reg_num (reg_i)<<12)); /* ldr rt,[pc+imm] */
	as_literal_constant_entry (i);

	as_cmp_r_r (reg_i,reg);
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
			store_l (0xea000000);
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
				store_l (0xeb000000); /* bl */
				as_branch_label (profile_t_label,CALL_RELOCATION);

				store_l (0xea000000); /* b */
			} else {
				if (offset & 3)
					internal_error_in_function ("as_jmpp_instruction");

				store_l (0xea000000 + ((offset>>2) & 0xffffff)); /* b */
			}
			
			as_branch_label (instruction->instruction_parameters[0].parameter_data.l,JUMP_RELOCATION);
			break;
		}
		case P_INDIRECT:
			store_l (0xeb000000); /* bl */
			as_branch_label (profile_t_label,CALL_RELOCATION);				

			as_ldr_id_r (instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_PC);
			break;
		case P_REGISTER:
		{
			int reg_0;

			reg_0=instruction->instruction_parameters[0].parameter_data.reg.r;
			if (reg_0!=REGISTER_A3){
				store_l (0xeb000000); /* bl */
				as_branch_label (profile_t_label,CALL_RELOCATION);

				as_mov_r_r (reg_0,REGISTER_PC);
			} else {
				store_l (0xea000000); /* b */
				as_branch_label (profile_ti_label,JUMP_RELOCATION);
			}
			break;
		}
		default:
			internal_error_in_function ("as_jmpp_instruction");
	}

	write_literals();
}

static void as_jsr_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_LABEL:
			if (instruction->instruction_arity>1)
				switch (instruction->instruction_parameters[1].parameter_type){
					case P_INDIRECT_WITH_UPDATE:
						as_str_r_id_update (REGISTER_PC,instruction->instruction_parameters[1].parameter_offset,B_STACK_POINTER);
						break;
					case P_INDIRECT:
						as_str_r_id (REGISTER_PC,instruction->instruction_parameters[1].parameter_offset,B_STACK_POINTER);
				}
			store_l (0xeb000000); /* bl */
			as_branch_label (instruction->instruction_parameters[0].parameter_data.l,CALL_RELOCATION);
			break;
		case P_INDIRECT:
			as_ldr_id_r (instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_S0);
			if (instruction->instruction_arity>1)
				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE)
					as_str_r_id_update (REGISTER_PC,-4,B_STACK_POINTER);
			store_l (0xe12fff30 | reg_num (REGISTER_S0)); /* blx r12*/			
			break;
		case P_REGISTER:
			if (instruction->instruction_arity>1)
				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT_WITH_UPDATE)
					as_str_r_id_update (REGISTER_PC,-4,B_STACK_POINTER);
			store_l (0xe12fff30 | reg_num (instruction->instruction_parameters[0].parameter_data.reg.r)); /* blx rm*/			
			break;
		default:
			internal_error_in_function ("as_jsr_instruction");
	}
}

static void as_rts_instruction()
{
	store_l (0xe49df004); /* ldr pc,[sp],#4 */
	write_literals();
}

static void as_rtsi_instruction (struct instruction *instruction)
{
	int offset;
	
	offset = instruction->instruction_parameters[0].parameter_data.imm;
	store_l (0xe49df000 | (offset & 0xfff)); /* ldr pc,[sp],#offset */
	write_literals();
}

static void as_rtsp_instruction()
{
	store_l (0xea000000); /* b */
	as_branch_label (profile_r_label,JUMP_RELOCATION);
	write_literals();
}

static void as_branch_instruction (struct instruction *instruction,int condition_code)
{
	store_l ((condition_code<<28) | 0x0a000000); /* b */
	as_branch_label (instruction->instruction_parameters[0].parameter_data.l,BRANCH_RELOCATION);
}

static void as_nop (void)
{
	/* mov r0,r0 */
	store_l (0xe1A00000); 
}

static void as_shift_instruction (struct instruction *instruction,int shift_code)
{
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		as_shift_i_r_r (shift_code,instruction->instruction_parameters[0].parameter_data.i & 31,
			instruction->instruction_parameters[1].parameter_data.reg.r,
			instruction->instruction_parameters[1].parameter_data.reg.r);
	} else {
		int s_reg,d_reg;

		s_reg = instruction->instruction_parameters[0].parameter_data.reg.r;
		d_reg = instruction->instruction_parameters[1].parameter_data.reg.r;
		as_shift_r_r_r (shift_code,s_reg,d_reg,d_reg);
	}
}

static void as_lsli_instruction (struct instruction *instruction)
{
	as_lsl_i_r_r (instruction->instruction_parameters[2].parameter_data.i & 31,
		instruction->instruction_parameters[0].parameter_data.reg.r,
		instruction->instruction_parameters[1].parameter_data.reg.r);
}

static void as_logic_instruction (struct instruction *instruction,int arm_op)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_op_r_r_r (arm_op,instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
		{
			int shift,i;

			i = instruction->instruction_parameters[0].parameter_data.i;
			shift = immediate_shift (i);
			if (shift>=0){
				as_op_is_r_r (arm_op,i,shift,
					instruction->instruction_parameters[1].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			}

			shift = immediate_shift (~i);
			if (shift>=0){
				if (arm_op==ARM_OP_AND){
					as_op_is_r_r (ARM_OP_BIC,~i,shift,
						instruction->instruction_parameters[1].parameter_data.reg.r,
						instruction->instruction_parameters[1].parameter_data.reg.r);		
				} else {
					store_l_is (0xe3e00000 | (reg_num (REGISTER_S0)<<12),~i,shift); /* mvn rd,#i<<s */
					as_op_r_r_r (arm_op,REGISTER_S0,
						instruction->instruction_parameters[1].parameter_data.reg.r,
						instruction->instruction_parameters[1].parameter_data.reg.r);
				}
				return;
			}

			store_l (0xe59f0000 | (reg_num (REGISTER_S0)<<12)); /* ldr rt,[pc+imm] */
			as_literal_constant_entry (i);
			as_op_r_r_r (arm_op,REGISTER_S0,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		}
		default:
			as_load_parameter_to_scratch_register (&instruction->instruction_parameters[0]);
			as_op_r_r_r (arm_op,REGISTER_S0,
				instruction->instruction_parameters[1].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
	}
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
	store_l (0xe0000090 | (real_d_regn<<16) | (real_d_regn<<8) | reg_num (s_regn)); /* mul rd,rn,rm */
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
			if (log2i<=8)
				as_add_cc_is_r_r (CONDITION_LT,abs_i-1,0,d_reg,d_reg);
			else {
				as_add_is_r_r (abs_i,immediate_shift (abs_i),d_reg,REGISTER_S0);
				as_sub_cc_is_r_r (CONDITION_LT,1,0,REGISTER_S0,d_reg);
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

static void as_mulud_instruction (struct instruction *instruction)
{
	int rn_1,rn_2;

	rn_1=reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);
	rn_2=reg_num (instruction->instruction_parameters[1].parameter_data.reg.r);

	store_l (0xe0800090 | (rn_1<<16 | (rn_2<<12)) | (rn_1<<8) | rn_2); /* umull */
}

static void as_set_condition_instruction (struct instruction *instruction,int condition_code_true,int condition_code_false)
{
	unsigned int rn;
	
	rn = reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);

	store_l (0x03a00001 | (condition_code_true<<28) | (rn<<12)); /* movcc rd,#1 */
	store_l (0x03a00000 | (condition_code_false<<28) | (rn<<12)); /* movcc rd,#0 */
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
	store_l (0xe0000000 | (ARM_OP_MVN<<21) | (regn<<12) | regn); /* mvn rd,rm */
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

		store_l (0xe16f0f10 | (reg_num (d_reg)<<12) | reg_num (s_reg));	/* clz */

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
					
					store_l (0xeeb00b40 | (reg1<<12) | reg0); /* vmov dd,dm */
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
					as_vldr_r_id (instruction->instruction_parameters[1].parameter_data.reg.r,0,REGISTER_PC);
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

		store_l (0xeeb70ac0 | (freg<<12) | freg); /* vcvtr.f64.f32 dd,sm */
		return;
	}

	internal_error_in_function ("as_floads_instruction");
}

static void as_fmoves_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
		int s_freg;
				
		s_freg=instruction->instruction_parameters[0].parameter_data.reg.r;

		store_l (0xeeb70bc0 | (15<<12) | s_freg); /* vcvtr.f32.f64 sd,dm */

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
			as_vldr_r_id (15,0,REGISTER_PC);
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
	store_l (0xee000b00 | code | (d_freg<<16) | (d_freg<<12) | s_freg);
}

static void as_float_sub_or_div_instruction (struct instruction *instruction,int code)
{
	int d_freg,s_freg;
	
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_F_IMMEDIATE:
			as_vldr_r_id (15,0,REGISTER_PC);
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
		store_l (0xee000b00 | code | (s_freg<<16) | (d_freg<<12) | d_freg);
	else
		store_l (0xee000b00 | code | (d_freg<<16) | (d_freg<<12) | s_freg);
}

static void as_vcmp_f64_r_r (int freg_1,int freg_2)
{
	store_l (0xeeb40b40 | (freg_2<<12) | freg_1); /* vcmp.f64 dd,dm */
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
				store_l (0xeeb50b40 | (d_freg<<12)); /* vcmp.f64 dd,#0.0 */
			} else {
				as_vldr_r_id (15,0,REGISTER_PC);
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
			as_vldr_r_id (15,0,REGISTER_PC);
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
	store_l (0xeeb00b40 | code | (d_freg<<12) | s_freg);
}

static void as_test_floating_point_condition_code (void)
{
	store_l (0xeef1fa10); /* vmrs APSR_nzcv,fpscr */
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
	
	store_l ((condition_code<<28) | 0x0a000000); /* b */
	as_branch_label (instruction->instruction_parameters[0].parameter_data.l,BRANCH_RELOCATION);
}

static void as_float_branch_vc_and_instruction (struct instruction *instruction,int condition_code)
{
	as_test_floating_point_condition_code();

	if (code_buffer_p+4>=literal_table_at_buffer_p)
		write_branch_and_literals();

	store_l_no_literal_table ((CONDITION_VS<<28) | 0x0a000000 | 4); /* bvs (pc+4)+4 */
	store_l_no_literal_table ((condition_code<<28) | 0x0a000000); /* b */
	as_branch_label (instruction->instruction_parameters[0].parameter_data.l,BRANCH_RELOCATION);
}

static void as_float_branch_vs_or_instruction (struct instruction *instruction,int condition_code)
{
	as_test_floating_point_condition_code();

	store_l ((CONDITION_VS<<28) | 0x0a000000); /* b */
	as_branch_label (instruction->instruction_parameters[0].parameter_data.l,BRANCH_RELOCATION);
	store_l ((condition_code<<28) | 0x0a000000); /* b */
	as_branch_label (instruction->instruction_parameters[0].parameter_data.l,BRANCH_RELOCATION);
}

static void as_set_float_condition_instruction (struct instruction *instruction,int condition_code_true,int condition_code_false)
{
	as_test_floating_point_condition_code();

	as_set_condition_instruction (instruction,condition_code_true,condition_code_false);
}

static void as_set_float_vc_and_condition_instruction (struct instruction *instruction,int condition_code_true,int condition_code_false)
{
	unsigned int rn;
	
	as_test_floating_point_condition_code();

	rn = reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);

	store_l (0x03a00001 | (condition_code_true<<28) | (rn<<12)); /* movcc rd,#1 */
	store_l (0x03a00000 | (condition_code_false<<28) | (rn<<12)); /* movcc rd,#0 */
	store_l (0x03a00000 | (CONDITION_VS<<28) | (rn<<12)); /* movvs rd,#0 */
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
			store_l (0xeebd0b40 | (15<<12) | s_freg); /* vcvtr.s32.f64 sd,dm */
			store_l (0xee100a10 | (15<<16) | (reg_num (instruction->instruction_parameters[1].parameter_data.reg.r)<<12)); /* vmov rt,sn */
			return;
		} else
			internal_error_in_function ("as_fmovel_instruction");
	} else {
		int freg;

		switch (instruction->instruction_parameters[0].parameter_type){
			case P_REGISTER:
				freg=instruction->instruction_parameters[1].parameter_data.reg.r;				
				store_l (0xee000a10 | (freg<<16) | (reg_num (instruction->instruction_parameters[0].parameter_data.reg.r)<<12)); /* vmov sn,rt */
				break;
			case P_INDIRECT:
				as_ldr_id_r (instruction->instruction_parameters[0].parameter_offset,
					instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_S0);
				freg=instruction->instruction_parameters[1].parameter_data.reg.r;
				store_l (0xee000a10 | (freg<<16) | (reg_num (REGISTER_S0)<<12)); /* vmov sn,rt */
				break;
			case P_INDEXED:
				as_load_indexed_reg (instruction->instruction_parameters[0].parameter_offset,
					instruction->instruction_parameters[0].parameter_data.ir,REGISTER_S0);
				freg=instruction->instruction_parameters[1].parameter_data.reg.r;
				store_l (0xee000a10 | (freg<<16) | (reg_num (REGISTER_S0)<<12)); /* vmov sn,rt */
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
		store_l (0xeeb80bc0 | (freg<<12) | freg); /* vcvt.f64.s32 dd,sm */
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
				as_move_instruction (instruction);
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
				as_shift_instruction (instruction,ARM_OP_LSL);
				break;
			case ILSR:
				as_shift_instruction (instruction,ARM_OP_LSR);
				break;
			case IASR:
				as_shift_instruction (instruction,ARM_OP_ASR);
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
				as_logic_instruction (instruction,ARM_OP_AND);
				break;
			case IOR:
				as_logic_instruction (instruction,ARM_OP_ORR);
				break;
			case IEOR:
				as_logic_instruction (instruction,ARM_OP_EOR);
				break;
			case IADDI:
				as_addi_instruction (instruction);
				break;
			case ILSLI:
				as_lsli_instruction (instruction);
				break;
			case ISEQ:
				as_set_condition_instruction (instruction,CONDITION_EQ,CONDITION_NE);
				break;
			case ISGE:
				as_set_condition_instruction (instruction,CONDITION_GE,CONDITION_LT);
				break;
			case ISGEU:
				as_set_condition_instruction (instruction,CONDITION_HS,CONDITION_LO);
				break;
			case ISGT:
				as_set_condition_instruction (instruction,CONDITION_GT,CONDITION_LE);
				break;
			case ISGTU:
				as_set_condition_instruction (instruction,CONDITION_HI,CONDITION_LS);
				break;
			case ISLE:
				as_set_condition_instruction (instruction,CONDITION_LE,CONDITION_GT);
				break;
			case ISLEU:
				as_set_condition_instruction (instruction,CONDITION_LS,CONDITION_HI);
				break;
			case ISLT:
				as_set_condition_instruction (instruction,CONDITION_LT,CONDITION_GE);
				break;
			case ISLTU:
				as_set_condition_instruction (instruction,CONDITION_LO,CONDITION_HS);
				break;
			case ISNE:
				as_set_condition_instruction (instruction,CONDITION_NE,CONDITION_EQ);
				break;
			case ISO:
				as_set_condition_instruction (instruction,CONDITION_VS,CONDITION_VC);
				break;
			case ISNO:
				as_set_condition_instruction (instruction,CONDITION_VC,CONDITION_VS);
				break;
			case ITST:
				as_tst_instruction (instruction);
				break;
			case IBTST:
				as_btst_instruction (instruction);
				break;
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
				as_add_or_sub_x_instruction (instruction,ARM_OP_ADC<<1,ARM_OP_SBC<<1);
				break;
			case ISBB:
				as_add_or_sub_x_instruction (instruction,ARM_OP_SBC<<1,ARM_OP_ADC<<1);
				break;
			case IMULUD:
				as_mulud_instruction (instruction);
				break;
			case IWORD:
				store_l (instruction->instruction_parameters[0].parameter_data.i);
				break;
			case IROTR:
				as_shift_instruction (instruction,ARM_OP_ROR);
				break;
			case IADDO:
				as_add_or_sub_x_instruction (instruction,(ARM_OP_ADD<<1) | 1,(ARM_OP_SUB<<1) | 1);
				break;
			case ISUBO:
				as_add_or_sub_x_instruction (instruction,(ARM_OP_SUB<<1) | 1,(ARM_OP_ADD<<1) | 1);
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
				break;
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
				as_set_float_condition_instruction (instruction,CONDITION_EQ,CONDITION_NE);
				break;
			case IFSGE:
				as_set_float_condition_instruction (instruction,CONDITION_GE,CONDITION_LT);
				break;
			case IFSGT:
				as_set_float_condition_instruction (instruction,CONDITION_GT,CONDITION_LE);
				break;
			case IFSLE:
				as_set_float_condition_instruction (instruction,CONDITION_LS,CONDITION_HI);
				break;
			case IFSLT:
				as_set_float_condition_instruction (instruction,CONDITION_MI,CONDITION_PL);
				break;
			case IFSNE:
				as_set_float_vc_and_condition_instruction (instruction,CONDITION_NE,CONDITION_EQ);
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
		as_subs_is_r_r (n_cells,shift,REGISTER_R5,REGISTER_R5);
	} else {
		store_l (0xe59f0000 | (reg_num (REGISTER_S0)<<12)); /* ldr rt,[pc+imm] */
		as_literal_constant_entry (n_cells);

		as_x_op_r_r_r ((ARM_OP_SUB<<1) | 1,REGISTER_S0,REGISTER_R5,REGISTER_R5); /* subs */
	}

	store_l ((CONDITION_LO<<28) | 0x0a000000); /* blo */
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

	store_l (0xeb000000); /* bl */
	as_branch_label (call_and_jump->cj_call_label,CALL_RELOCATION);

	store_l (0xea000000); /* b */
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
	store_l (0xeb000000); /* bl */
	as_branch_label (profile_label,CALL_RELOCATION);
}

extern LABEL *add_empty_node_labels[];

static void as_apply_update_entry (struct basic_block *block)
{
	int n_node_arguments;

	n_node_arguments=block->block_n_node_arguments;
	if (n_node_arguments<-200){
		store_l (0xea000000); /* b */
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
		store_l (0xea000000); /* b */
		as_branch_label (block->block_ea_label,JUMP_RELOCATION);

		as_nop();
	} else {
		store_l (0xeb000000); /* bl */
		as_branch_label (add_empty_node_labels[n_node_arguments],CALL_RELOCATION);

		store_l (0xea000000); /* b */
		as_branch_label (block->block_ea_label,JUMP_RELOCATION);
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
				as_move_l_r (block->block_ea_label,REGISTER_A3);

				store_l (0xea000000); /* b */
				as_branch_label (eval_upd_labels[n_node_arguments],JUMP_RELOCATION);

				if (!pic_flag)
					as_nop();
			} else {
				as_move_l_r (block->block_ea_label,REGISTER_D0);
				as_move_l_r (block->block_profile_function_label,REGISTER_A3);

				store_l (0xea000000 + ((-8>>2) & 0xffffff)); /* b */
				as_branch_label (eval_upd_labels[n_node_arguments],JUMP_RELOCATION);
			}
		} else {
			store_l (0xea000000); /* b */
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
#if 1
					switch (3 & -(CURRENT_CODE_OFFSET-code_object_label->object_label_offset)){
						case 0:
							break;
						case 1:
							store_c (0x90);
							break;
						case 2:
							store_c (0213);
							store_c (0300 | (reg_num (EBP)<<3) | reg_num (EBP));
							break;
						case 3:
							store_c (0215);
							store_c (0x40 | (reg_num (EBP)<<3) | reg_num (EBP));
							store_c (0);
							break;
					}
#else
					while (((CURRENT_CODE_OFFSET-code_object_label->object_label_offset) & 3)!=0)
						store_c (0x90);
#endif
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
#ifndef FUNCTION_LEVEL_LINKING
			while ((code_buffer_free & 3)!=0)
				store_c (0x90);
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
		label=relocation->relocation_label;

		switch (relocation->relocation_kind){
			case CALL_RELOCATION:
			case BRANCH_RELOCATION:
			case JUMP_RELOCATION:
				if (label->label_id==TEXT_LABEL_ID){
					instruction_offset=relocation->relocation_offset;

#ifdef FUNCTION_LEVEL_LINKING
					if (label->label_object_label!=relocation->relocation_object_label){
						v=label->label_offset-label->label_object_label->object_label_offset;

						v-=8;

						++n_code_relocations;
						relocation_p=&relocation->next;
					} else
#endif
					{
						v=label->label_offset-(instruction_offset+8);
						*relocation_p=relocation->next;
					}
				} else {
					++n_code_relocations;
					relocation_p=&relocation->next;

					instruction_offset=relocation->relocation_offset;
					v= -8;
				}

				while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					code_buffer_offset+=BUFFER_SIZE;
				}
				
				if (instruction_offset-code_buffer_offset<=BUFFER_SIZE-4){
					LONG *instruction_p;
					
					instruction_p=(LONG*)(object_buffer->data+(instruction_offset-code_buffer_offset));

					v >>= 2;
					
					*instruction_p = (*instruction_p & 0xff000000) | ((*instruction_p + v) & 0x00ffffff);
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

					v >>= 2;
					v += (*p0 | (*p1<<8) | (*p2<<16));
										
					*p0=v;
					*p1=v>>8;
					*p2=v>>16;
				}

				continue;
			case LDR_OFFSET_RELOCATION:
				if (label->label_id==TEXT_LABEL_ID){
					instruction_offset=relocation->relocation_offset;

#ifdef FUNCTION_LEVEL_LINKING
					if (label->label_object_label!=relocation->relocation_object_label){
						v=label->label_offset-label->label_object_label->object_label_offset;

						v-=8;

						++n_code_relocations;
						relocation_p=&relocation->next;
					} else
#endif
					{
						v=label->label_offset-(instruction_offset+8);
						*relocation_p=relocation->next;
					}
				} else {
					++n_code_relocations;
					relocation_p=&relocation->next;

					instruction_offset=relocation->relocation_offset;
					v= -8;
				}

				while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					code_buffer_offset+=BUFFER_SIZE;
				}
				
				if (instruction_offset-code_buffer_offset<=BUFFER_SIZE-4){
					LONG *instruction_p;
					
					instruction_p=(LONG*)(object_buffer->data+(instruction_offset-code_buffer_offset));
					if (v>=0)
						*instruction_p = (*instruction_p & 0xfffff000) | (v & 0x00000fff);
					else
						*instruction_p = (*instruction_p & 0xff7ff000) | ((-v) & 0x00000fff); /* clear add bit (23) */
				} else {
					unsigned char *p0,*p1,*end_buffer;
					
					p0=object_buffer->data+(instruction_offset-code_buffer_offset);
					end_buffer=object_buffer->data+BUFFER_SIZE;
					p1=p0+1;
					if (p1==end_buffer)
						p1=object_buffer->next->data;

					v += (*p0 | (*p1<<8)) & 0xfff;
					
					if (v<0){
						unsigned char *p2;
			
						p2=p1+1;
						if (p2==end_buffer)
							p2=object_buffer->next->data;

						v = -v;
						*p2 &= 0x7f; /* clear add bit (23) */
					}
					*p0 = v;
					*p1 = (*p1) | ((v>>8) & 0xf);
				}

				continue;
			case VLDR_OFFSET_RELOCATION:
				if (label->label_id==TEXT_LABEL_ID){
					instruction_offset=relocation->relocation_offset;

#ifdef FUNCTION_LEVEL_LINKING
					if (label->label_object_label!=relocation->relocation_object_label){
						v=label->label_offset-label->label_object_label->object_label_offset;

						v-=8;

						++n_code_relocations;
						relocation_p=&relocation->next;
					} else
#endif
					{
						v=label->label_offset-(instruction_offset+8);
						*relocation_p=relocation->next;
					}
				} else {
					++n_code_relocations;
					relocation_p=&relocation->next;

					instruction_offset=relocation->relocation_offset;
					v= -8;
				}

				while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					code_buffer_offset+=BUFFER_SIZE;
				}
				
				{
					unsigned char *p0;
					
					p0=object_buffer->data+(instruction_offset-code_buffer_offset);
					
					*p0 += (v>>2);
				}

				continue;
			case LONG_WORD_RELOCATION:
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
			case RELATIVE_LONG_WORD_RELOCATION:
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
			if (label->label_id==TEXT_LABEL_ID || (label->label_id==DATA_LABEL_ID
#if defined (RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL) && defined (FUNCTION_LEVEL_LINKING)
				&& !((label->label_flags & EXPORT_LABEL) && label->label_object_label->object_label_kind==EXPORTED_DATA_LABEL)
#endif
				))
			{
				int data_offset,v;
				
				data_offset=relocation->relocation_offset;
				while (data_offset >= data_buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					data_buffer_offset+=BUFFER_SIZE;
				}
	
				v = label->label_offset;
#ifdef FUNCTION_LEVEL_LINKING
				v -= label->label_object_label->object_label_offset;
#endif
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

		/* $a and $d symbols */
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
					write_l (1); /* $a */
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

					if (mapping_symbol_p->ms_code_offset!=next_control_section_code_offset){
						write_l (1); /* $a */
						write_l (mapping_symbol_p->ms_code_offset-current_control_section_code_offset);
						write_l (0);
						write_c (ELF32_ST_INFO (STB_LOCAL,STT_NOTYPE));
						write_c (0);
						write_w (2+section_n);
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
#ifdef ELF
				write_l (object_label->object_label_string_offset);
				write_l (0);
				write_l (0);
				write_c (ELF32_ST_INFO (STB_GLOBAL,STT_NOTYPE));
				write_c (0);
				write_w (0);
#else
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
				write_c (0);
#endif
				break;
			}
			case EXPORTED_CODE_LABEL:
			{
				struct label *label;
				
				label=object_label->object_label_label;
#ifdef ELF
				write_l (object_label->object_label_string_offset);
# ifdef FUNCTION_LEVEL_LINKING
				write_l (label->label_offset - label->label_object_label->object_label_offset);
# else
				write_l (label->label_offset);
# endif
				write_l (0);
				write_c (ELF32_ST_INFO (STB_GLOBAL,STT_FUNC));
				write_c (label->label_flags & C_ENTRY_LABEL ? STV_DEFAULT : STV_HIDDEN);
# ifdef FUNCTION_LEVEL_LINKING
				write_w (2+label->label_object_label->object_label_section_n);
# else
				write_w (2);
# endif
#else
				if (object_label->object_label_string_offset==0)
					write_string_8 (label->label_name);
				else {
					write_l (0);
					write_l (object_label->object_label_string_offset);
				}

#ifdef FUNCTION_LEVEL_LINKING
				write_l (label->label_offset - label->label_object_label->object_label_offset);
				write_w (1+label->label_object_label->object_label_section_n);
#else
				write_l (label->label_offset);
				write_w (1);
#endif
				write_w (0);
				write_c (C_EXT);
				write_c (0);
#endif
				break;
			}
			case EXPORTED_DATA_LABEL:
			{
				struct label *label;
				
				label=object_label->object_label_label;
#ifdef ELF
				write_l (object_label->object_label_string_offset);
# ifdef FUNCTION_LEVEL_LINKING
#  ifdef RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL
				write_l (label->label_offset - current_text_or_data_object_label->object_label_offset);
#  else
				write_l (label->label_offset - label->label_object_label->object_label_offset);
# endif
# else
				write_l (label->label_offset);
# endif
				write_l (0);
				write_c (ELF32_ST_INFO (STB_GLOBAL,STT_OBJECT));
				write_c (label->label_flags & C_ENTRY_LABEL ? STV_DEFAULT : STV_HIDDEN);
# ifdef FUNCTION_LEVEL_LINKING
				write_w (2+n_code_sections+label->label_object_label->object_label_section_n);
# else
				write_w (3);
# endif
#else
				if (object_label->object_label_string_offset==0)
					write_string_8 (label->label_name);
				else {
					write_l (0);
					write_l (object_label->object_label_string_offset);
				}

#ifdef FUNCTION_LEVEL_LINKING
# ifdef RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL
				write_l (label->label_offset - current_text_or_data_object_label->object_label_offset);
# else
				write_l (label->label_offset - label->label_object_label->object_label_offset);
# endif
				write_w (1+n_code_sections+label->label_object_label->object_label_section_n);
#else
				write_l (label->label_offset);
				write_w (2);
#endif
				write_w (0);
				write_c (C_EXT);
				write_c (0);
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
	write_zstring ("$a");
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

				write_l (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_ARM_JUMP24));
#else
				write_l (ELF32_R_INFO (label->label_id,R_ARM_JUMP24));
#endif
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

				write_l (relocation->relocation_offset);
#ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_ARM_CALL));
#else
				write_l (ELF32_R_INFO (label->label_id,R_ARM_CALL));
#endif
				break;
			}
			case LDR_OFFSET_RELOCATION:
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
				write_l (ELF32_R_INFO (elf_label_number (label),R_ARM_LDR_PC_G0));
#else
				write_l (ELF32_R_INFO (label->label_id,R_ARM_LDR_PC_G0));
#endif
				break;				
			}
			case VLDR_OFFSET_RELOCATION:
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
				write_l (ELF32_R_INFO (elf_label_number (label),R_ARM_LDC_PC_G0));
#else
				write_l (ELF32_R_INFO (label->label_id,R_ARM_LDC_PC_G0));
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

	if (code_buffer_free & 1)
		store_c (0x90);

	end_code_offset=CURRENT_CODE_OFFSET;
	if (first_mapping_symbol!=NULL && last_mapping_symbol->ms_code_offset==end_code_offset)
		--n_mapping_symbols; /* $a at end of section */

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
