/*
	File:	 cgias.c
	Author:  John van Groningen
	Machine: 80386 80486 pentium
*/

#define FSUB_FDIV_REVERSED
#define RELOCATIONS_RELATIVE_TO_EXPORTED_DATA_LABEL

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#ifdef __MWERKS__
#	define I486
#endif

#define OPTIMISE_BRANCHES

#ifdef OS2
#	define OMF
#	define REMOVE_UNDERSCORE_AT_BEGIN_OF_LABEL
#endif

#ifdef LINUX_ELF 
#	define ELF
#endif

#if defined (_WINDOWS_) || defined (ELF)
#	define FUNCTION_LEVEL_LINKING
#endif

#include "cgport.h"

#ifdef __MWERKS__
#	undef G_POWER
#	define OS2
#endif

#include "cgrconst.h"
#include "cgtypes.h"
#include "cg.h"
#include "cgiconst.h"
#include "cgcode.h"
#include "cgias.h"
#include "cginstructions.h"

#ifdef ELF
# include <elf.h>
# ifndef ELF32_ST_INFO
#  define ELF32_ST_INFO(b,t) (((b)<<4)+((t)&0xf))
# endif
# ifndef ELF32_R_INFO
#  define ELF32_R_INFO(s,t) (((s)<<8)+(unsigned char)(t))
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
	unsigned short			object_label_section_n;		/* CODE_CONTROL_SECTION,DATA_CONTROL_SECTION */
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
#define SHORT_BRANCH_RELOCATION 4
#define SHORT_JUMP_RELOCATION 5
#define NEW_SHORT_BRANCH_RELOCATION 6
#define NEW_SHORT_JUMP_RELOCATION 7
#define LONG_JUMP_RELOCATION 8 /* JUMP_RELOCATION that cannot be optimised to a SHORT_JUMP_RELOCATION */
#define ALIGN_RELOCATION 9
#define DUMMY_BRANCH_RELOCATION 10

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

#ifndef OMF
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
#else
static int threads_defined;

static unsigned int define_threads (unsigned char record[])
{
	unsigned char *record_p;
	
	record_p=record;
	*record_p++ = 0x40 | (1<<2) | 0;
	*record_p++ = 1;

	*record_p++ = 0;
	*record_p++ = 1;

	*record_p++ = 1;
	*record_p++ = 2;
	
	threads_defined=1;
	
	return record_p-record;
}

static struct relocation *write_fixups (struct relocation *relocation,unsigned int offset,int size)
{
	int record_length;
	unsigned char record[1024];
	
	record_length=0;

	while (relocation!=NULL && relocation->relocation_offset < offset+size){
		struct label *label;
		int local_offset,label_id;
		
		if (record_length>1018){
			int n;
			
			write_c (0x9d);
			write_w (record_length+1);
			for (n=0; n<record_length; ++n)
				write_c (record[n]);
			write_c (0);
			
			record_length=0;
		}

		if (!threads_defined)
			record_length=define_threads (record);

		label=relocation->relocation_label;
		label_id=label->label_id;

		local_offset=relocation->relocation_offset-offset;

		switch (relocation->relocation_kind){
			case CALL_RELOCATION:
			case BRANCH_RELOCATION:
			case JUMP_RELOCATION:
			case LONG_JUMP_RELOCATION:
				if (label_id<2 || local_offset>=1024)
					internal_error_in_function ("write_fixups");

				record[record_length++]= 0x80 | (9<<2) | (local_offset>>8);
				record[record_length++]= local_offset;
				
				if (label_id==DATA_LABEL_ID)
					record[record_length++]= 0x8d;					
				else {
					record[record_length++]= 0x86;
					label_id-=3;
					if (label_id>=128)
						record[record_length++]= 0x80 | (label_id>>8);
					record[record_length++]= label_id;
				}
				break;
			case LONG_WORD_RELOCATION:
				if (label_id<0 || local_offset>=1024)
					internal_error_in_function ("write_fixups");

				record[record_length++]= 0xc0 | (9<<2) | (local_offset>>8);
				record[record_length++]= local_offset;

				if (label_id==TEXT_LABEL_ID)
					record[record_length++]= 0x8c;
				else if (label_id==DATA_LABEL_ID)
					record[record_length++]= 0x8d;					
				else {
					record[record_length++]= 0x86;
					label_id-=3;
					if (label_id>=128)
						record[record_length++]= 0x80 | (label_id>>8);
					record[record_length++]= label_id;
				}
				break;
			default:
				internal_error_in_function ("write_fixups");
		}
		relocation=relocation->next;
	}
	
	if (record_length>0){
		int n;
		
		write_c (0x9d);
		write_w (record_length+1);
		for (n=0; n<record_length; ++n)
			write_c (record[n]);
		write_c (0);
	}
	
	return relocation;
}

static void write_buffers_and_release_memory
	(struct object_buffer **first_buffer_l,int segment_index,struct relocation *relocation)
{
	struct object_buffer *buffer,*next_buffer;
	unsigned char *previous_data_p;
	int previous_size;
	unsigned int offset;
		
	offset=0;

	previous_data_p=NULL;
	previous_size=0;

	for_l (buffer,*first_buffer_l,next){
		unsigned char *data_p;
		int size;
		
		size=buffer->size;	
		data_p=buffer->data;
				
		while (previous_size+size>=1024 || (previous_size>0 && size>0)){
			struct relocation *relocation_in_two_blocks;
			int next_size;
			
			if (previous_size+size<1024)
				next_size=size;
			else
				next_size=1024-previous_size;

			relocation_in_two_blocks=relocation;
			while (relocation_in_two_blocks!=NULL && relocation_in_two_blocks->offset <= offset+previous_size+next_size-4)
				relocation_in_two_blocks=relocation_in_two_blocks->next;

			if (relocation_in_two_blocks!=NULL && relocation_in_two_blocks->offset < offset+previous_size+next_size)
				next_size -= offset+previous_size+next_size - relocation_in_two_blocks->offset;

			write_c (0xa1);
			write_w (previous_size+next_size+6);
			write_c (segment_index);
			write_l (offset);

			if (previous_data_p!=NULL)
				if (fwrite (previous_data_p,1,previous_size,output_file)!=previous_size)
					error ("Write error");
						
			if (fwrite (data_p,1,next_size,output_file)!=next_size)
				error ("Write error");
			write_c (0);
			
			relocation=write_fixups (relocation,offset,previous_size+next_size);
			
			size-=next_size;
			data_p+=next_size;

			offset+=previous_size+next_size;
			
			previous_data_p=NULL;
			previous_size=0;
		}
		
		if (size>0){
			previous_data_p=data_p;
			previous_size=size;
		}
	}

	if (previous_size>0){
		write_c (0xa1);
		write_w (previous_size+6);
		write_c (segment_index);
		write_l (offset);
	 	if (fwrite (previous_data_p,1,previous_size,output_file)!=previous_size)
			error ("Write error");
		write_c (0);

		relocation=write_fixups (relocation,offset,previous_size);
	}
		
	for (buffer=*first_buffer_l; buffer!=NULL; buffer=next_buffer){
		next_buffer=buffer->next;		
		memory_free (buffer);
	}
	
	*first_buffer_l=NULL;
}
#endif

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
#ifdef ELF
	string_table_offset=13;
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

#ifdef OMF
	threads_defined=0;
#endif
}

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
	}
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

static void store_w (UWORD i)
{
	store_c (i);
	store_c (i>>8);
}

static void store_l (register ULONG i)
{
	store_c (i);
	store_c (i>>8);
	store_c (i>>16);
	store_c (i>>24);
}

#define CURRENT_CODE_OFFSET (code_buffer_offset+(code_buffer_p-current_code_buffer->data))
#define CURRENT_DATA_OFFSET (data_buffer_offset+(data_buffer_p-current_data_buffer->data))

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
	
	new_object_label=fast_memory_allocate_type (struct object_label);
	code_object_label=new_object_label;

# ifdef ELF
	code_section_label_number=0;
# else
	code_section_label_number=n_object_labels;
	n_object_labels+=2;
# endif
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

#define reg_num(r) (real_reg_num[(r)+6])

#ifdef MORE_PARAMETER_REGISTERS
static unsigned char real_reg_num [10] =
#else
static unsigned char real_reg_num [8] =
#endif
{
	4 /*ESP*/,7 /*EDI*/,6 /*ESI*/,5 /*EBP*/,2 /*EDX*/,1 /*ECX*/,0 /*EAX*/,3 /*EBX*/
#ifdef MORE_PARAMETER_REGISTERS
	,2 /*EDX*/,1 /*ECX*/
#endif
};

#define ESP (-6)
#define EBP (-3)
#define EAX 0

#define REGISTER_O0 (-3)

static void small_as_r (int code,int reg1)
{
	store_c (code | reg_num (reg1));
}

static void as_r (int code1,int code2,int reg1)
{
	store_c (code1);
	store_c (0300 | code2 | reg_num (reg1));
}

static void as_move_i_r (int i,int reg1)
{
	store_c (0270 | reg_num (reg1));
	store_l (i);
}

static void as_move_d_r (LABEL *label,int arity,int reg1)
{
	as_move_i_r (arity,reg1);
	store_label_in_code_section (label);
}

static void as_move_l_r (LABEL *label,int reg1)
{
	as_move_i_r (0,reg1);
	store_label_in_code_section (label);
}

static void as_i_r2 (int code1,int code2,int code3,int i,int reg1)
{
	if (((signed char)i)==i){
		store_c (code1 | 2);
		store_c (0300 | code2 | reg_num (reg1));
		store_c (i);	
	} else {
		if (reg1==EAX)
			store_c (code3);
		else {
			store_c (code1);
			store_c (0300 | code2 | reg_num (reg1));
		}
		store_l (i);
	}
}

static void as_d_r2 (int code1,int code2,int code3,LABEL *label,int arity,int reg1)
{
	if (reg1==EAX)
		store_c (code3);
	else {
		store_c (code1);
		store_c (0300 | code2 | reg_num (reg1));
	}
	store_l (arity);
	store_label_in_code_section (label);
}

static void as_r_r (int code,int reg1,int reg2)
{
	store_c (code);
	store_c (0300 | (reg_num (reg2)<<3) | reg_num (reg1));
}

#define as_r_id(code,reg1,offset,reg2) as_id_r(code,offset,reg2,reg1)

static void as_id_r (int code,int offset,int reg1,int reg2)
{
	store_c (code);
	if (reg1==ESP){
		if (offset==0){
			store_c (0x04 | (reg_num (reg2)<<3));
			store_c (0044);
		} else if (((signed char)offset)==offset){
			store_c (0x44 | (reg_num (reg2)<<3));
			store_c (0044);
			store_c (offset);
		} else {
			store_c (0x84 | (reg_num (reg2)<<3));
			store_c (0044);
			store_l (offset);		
		}
	} else {
		if (offset==0 && reg1!=EBP){
			store_c ((reg_num (reg2)<<3) | reg_num (reg1));
		} else if (((signed char)offset)==offset){
			store_c (0x40 | (reg_num (reg2)<<3) | reg_num (reg1));
			store_c (offset);
		} else {
			store_c (0x80 | (reg_num (reg2)<<3) | reg_num (reg1));
			store_l (offset);		
		}
	}
}

#define as_r_x(code,reg3,offset,index_registers) as_x_r(code,offset,index_registers,reg3)

static void as_x_r (int code,int offset,struct index_registers *index_registers,int reg3)
{
	int reg1,reg2,shift;

	reg1=index_registers->a_reg.r;
	reg2=index_registers->d_reg.r;

	shift=offset & 3;
	offset=offset>>2;
	
	if (reg2==ESP)
		internal_error_in_function ("as_x_r");

	store_c (code);
	if (offset==0 && reg1!=EBP){
		store_c (0x04 | (reg_num (reg3)<<3));
		store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
	} else if (((signed char)offset)==offset){
		store_c (0x44 | (reg_num (reg3)<<3));
		store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
		store_c (offset);
	} else {
		store_c (0x84 | (reg_num (reg3)<<3));
		store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
		store_l (offset);
	}
}

static void as_xr_r (int code,int offset,int reg1,int reg2,int reg3)
{	
	int shift;

	shift=offset & 3;
	offset=offset>>2;
	
	if (reg2==ESP)
		internal_error_in_function ("as_x_r");
		
	store_c (code);
	if (offset==0 && reg1!=EBP){
		store_c (0x04 | (reg_num (reg3)<<3));
		store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
	} else if (((signed char)offset)==offset){
		store_c (0x44 | (reg_num (reg3)<<3));
		store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
		store_c (offset);
	} else {
		store_c (0x84 | (reg_num (reg3)<<3));
		store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
		store_l (offset);
	}
}


static void as_id (int code1,int code2,int offset,int reg1)
{
	store_c (code1);
	if (reg1==ESP){
		if (offset==0){
			store_c (code2 | 0x04);
			store_c (0044);
		} else if (((signed char)offset)==offset){
			store_c (code2 | 0x44);
			store_c (0044);
			store_c (offset);
		} else {
			store_c (code2 | 0x84);
			store_c (0044);
			store_l (offset);		
		}
	} else {
		if (offset==0 && reg1!=EBP){
			store_c (code2 | reg_num (reg1));
		} else if (((signed char)offset)==offset){
			store_c (code2 | 0x40 | reg_num (reg1));
			store_c (offset);
		} else {
			store_c (code2 | 0x80 | reg_num (reg1));
			store_l (offset);		
		}
	}
}

static void as_x (int code1,int code2,int offset,struct index_registers *index_registers)
{	
	int reg1,reg2,shift;

	reg1=index_registers->a_reg.r;
	reg2=index_registers->d_reg.r;

	shift=offset & 3;
	offset=offset>>2;
	
	if (reg2==ESP)
		internal_error_in_function ("as_x");
		
	store_c (code1);
	if (offset==0 && reg1!=EBP){
		store_c (0x04 | code2);
		store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
	} else if (((signed char)offset)==offset){
		store_c (0x44 | code2);
		store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
		store_c (offset);
	} else {
		store_c (0x84 | code2);
		store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
		store_l (offset);
	}
}

static void as_i_id (int code1,int code2,int i,int offset,int reg1)
{
	store_c (code1);
	if (reg1==ESP){
		if (offset==0){
			store_c (code2 | 0x04);
			store_c (0044);
		} else if (((signed char)offset)==offset){
			store_c (code2 | 0x44);
			store_c (0044);
			store_c (offset);
		} else {
			store_c (code2 | 0x84);
			store_c (0044);
			store_l (offset);		
		}
	} else {
		if (offset==0 && reg1!=EBP){
			store_c (code2 | reg_num (reg1));
		} else if (((signed char)offset)==offset){
			store_c (code2 | 0x40 | reg_num (reg1));
			store_c (offset);
		} else {
			store_c (code2 | 0x80 | reg_num (reg1));
			store_l (offset);		
		}
	}
	store_l (i);
}

static void as_i_id2 (int code1,int code2,int i,int offset,int reg1)
{
	if ((signed char)i==i)
		code1 |= 2;
	
	store_c (code1);
	if (reg1==ESP){
		if (offset==0){
			store_c (code2 | 0x04);
			store_c (0044);
		} else if (((signed char)offset)==offset){
			store_c (code2 | 0x44);
			store_c (0044);
			store_c (offset);
		} else {
			store_c (code2 | 0x84);
			store_c (0044);
			store_l (offset);		
		}
	} else {
		if (offset==0 && reg1!=EBP){
			store_c (code2 | reg_num (reg1));
		} else if (((signed char)offset)==offset){
			store_c (code2 | 0x40 | reg_num (reg1));
			store_c (offset);
		} else {
			store_c (code2 | 0x80 | reg_num (reg1));
			store_l (offset);		
		}
	}
	if ((signed char)i==i)
		store_c (i);
	else
		store_l (i);
}

static void as_d_id (int code1,int code2,LABEL *label,int arity,int offset,int reg1)
{
	as_i_id (code1,code2,arity,offset,reg1);
	store_label_in_code_section (label);
} 

static void as_i_x (int code1,int code2,int i,int offset,struct index_registers *index_registers)
{	
	int reg1,reg2,shift;

	reg1=index_registers->a_reg.r;
	reg2=index_registers->d_reg.r;

	shift=offset & 3;
	offset=offset>>2;
	
	if (reg2==ESP)
		internal_error_in_function ("as_i_x");
		
	store_c (code1);
	if (offset==0 && reg1!=EBP){
		store_c (code2 | 0x04);
		store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
	} else if (((signed char)offset)==offset){
		store_c (code2 | 0x44);
		store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
		store_c (offset);
	} else {
		store_c (code2 | 0x84);
		store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
		store_l (offset);
	}
	store_l (i);
}

static void as_i_x2 (int code1,int code2,int i,int offset,struct index_registers *index_registers)
{	
	int reg1,reg2,shift;

	reg1=index_registers->a_reg.r;
	reg2=index_registers->d_reg.r;

	shift=offset & 3;
	offset=offset>>2;
	
	if (reg2==ESP)
		internal_error_in_function ("as_i_x2");
		
	if ((signed char)i==i)
		code1 |= 2;
	
	store_c (code1);
	if (offset==0 && reg1!=EBP){
		store_c (code2 | 0x04);
		store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
	} else if (((signed char)offset)==offset){
		store_c (code2 | 0x44);
		store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
		store_c (offset);
	} else {
		store_c (code2 | 0x84);
		store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
		store_l (offset);
	}
	if ((signed char)i==i)
		store_c (i);
	else
		store_l (i);
}

static void as_d_x (int code1,int code2,LABEL *label,int arity,int offset,struct index_registers *index_registers)
{
	as_i_x (code1,code2,arity,offset,index_registers);
	store_label_in_code_section (label);
}

static void as_r_a (int code,int reg1,LABEL *label)
{
	store_c (code);
	store_c ((reg_num (reg1)<<3) | 5);
	store_l (0);
	store_label_in_code_section (label);
}

static void as_sar_i_r (int i,int reg)
{
	store_c (0301);
	store_c (0300 | (7<<3) | reg_num (reg));
	store_c (i);
}

static void as_shr_i_r (int i,int reg)
{
	store_c (0301);
	store_c (0300 | (5<<3) | reg_num (reg));
	store_c (i);
}

static void as_move_parameter_reg (struct parameter *parameter,int reg)
{
	switch (parameter->parameter_type){
		case P_REGISTER:
			as_r_r (0213,parameter->parameter_data.reg.r,reg);
			return;
		case P_DESCRIPTOR_NUMBER:
			as_move_d_r (parameter->parameter_data.l,parameter->parameter_offset,reg);
			return;
		case P_IMMEDIATE:
			as_move_i_r (parameter->parameter_data.i,reg);
			return;
		case P_INDIRECT:
			as_id_r (0213,parameter->parameter_offset,parameter->parameter_data.reg.r,reg);
			return;
		case P_INDEXED:
			as_x_r (0213,parameter->parameter_offset,parameter->parameter_data.ir,reg);
			return;					
		case P_POST_INCREMENT:
			small_as_r (0130,reg);
			return;
		case P_LABEL:
			as_r_a (0213,reg,parameter->parameter_data.l);
			return;
		default:
			internal_error_in_function ("as_move_parameter_reg");
			return;
	}
}

static void as_move_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_REGISTER:
			as_move_parameter_reg (&instruction->instruction_parameters[0],
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_INDIRECT:
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_INDIRECT:
					as_id_r (0213,instruction->instruction_parameters[0].parameter_offset,
						instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_O0);
					as_r_id (0211,REGISTER_O0,
						instruction->instruction_parameters[1].parameter_offset,
						instruction->instruction_parameters[1].parameter_data.reg.r);
					return;
				case P_INDEXED:
					as_x_r (0213,instruction->instruction_parameters[0].parameter_offset,
						instruction->instruction_parameters[0].parameter_data.ir,REGISTER_O0);
					as_r_id (0211,REGISTER_O0,
						instruction->instruction_parameters[1].parameter_offset,
						instruction->instruction_parameters[1].parameter_data.reg.r);
					return;
				case P_DESCRIPTOR_NUMBER:
					as_d_id (0307,0,instruction->instruction_parameters[0].parameter_data.l,
						instruction->instruction_parameters[0].parameter_offset,
						instruction->instruction_parameters[1].parameter_offset,
						instruction->instruction_parameters[1].parameter_data.reg.r);
					return;
				case P_IMMEDIATE:
					as_i_id (0307,0,instruction->instruction_parameters[0].parameter_data.i,
						instruction->instruction_parameters[1].parameter_offset,
						instruction->instruction_parameters[1].parameter_data.reg.r);
					return;
				case P_REGISTER:
					as_r_id (0211,instruction->instruction_parameters[0].parameter_data.reg.r,
						instruction->instruction_parameters[1].parameter_offset,
						instruction->instruction_parameters[1].parameter_data.reg.r);
					return;
				case P_POST_INCREMENT:
					as_id (0217,0,instruction->instruction_parameters[1].parameter_offset,
						instruction->instruction_parameters[1].parameter_data.reg.r);
					return;
				default:
					internal_error_in_function ("as_move_instruction");
					return;
			}
		case P_PRE_DECREMENT:
			if (instruction->instruction_parameters[1].parameter_data.reg.r==ESP)
				switch (instruction->instruction_parameters[0].parameter_type){
					case P_DESCRIPTOR_NUMBER:
						store_c (0150);
						store_l (instruction->instruction_parameters[0].parameter_offset);
						store_label_in_code_section (instruction->instruction_parameters[0].parameter_data.l);
						return;
					case P_IMMEDIATE:
					{
						int i;
						
						i=instruction->instruction_parameters[0].parameter_data.i;
						if ((signed char)i==i){
							store_c (0152);
							store_c (instruction->instruction_parameters[0].parameter_data.i);							
						} else {
							store_c (0150);
							store_l (instruction->instruction_parameters[0].parameter_data.i);
						}
						return;
					}
					case P_INDIRECT:
						as_id (0377,060,instruction->instruction_parameters[0].parameter_offset,
							instruction->instruction_parameters[0].parameter_data.reg.r);
						return;
					case P_INDEXED:
						as_x (0377,060,instruction->instruction_parameters[0].parameter_offset,
							instruction->instruction_parameters[0].parameter_data.ir);
						return;					
					case P_REGISTER:
						small_as_r (0120,instruction->instruction_parameters[0].parameter_data.reg.r);
						return;
				}
			internal_error_in_function ("as_move_instruction");
			return;
		case P_INDEXED:
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_INDIRECT:
					as_id_r (0213,instruction->instruction_parameters[0].parameter_offset,
						instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_O0);
					as_r_x (0211,REGISTER_O0,
						instruction->instruction_parameters[1].parameter_offset,
						instruction->instruction_parameters[1].parameter_data.ir);
					return;
				case P_DESCRIPTOR_NUMBER:
					as_d_x (0307,0,instruction->instruction_parameters[0].parameter_data.l,
						instruction->instruction_parameters[0].parameter_offset,
						instruction->instruction_parameters[1].parameter_offset,
						instruction->instruction_parameters[1].parameter_data.ir);
					return;
				case P_IMMEDIATE:
					as_i_x (0307,0,instruction->instruction_parameters[0].parameter_data.i,
						instruction->instruction_parameters[1].parameter_offset,
						instruction->instruction_parameters[1].parameter_data.ir);
					return;
				case P_REGISTER:
					as_r_x (0211,instruction->instruction_parameters[0].parameter_data.reg.r,
						instruction->instruction_parameters[1].parameter_offset,
						instruction->instruction_parameters[1].parameter_data.ir);
					return;
				case P_POST_INCREMENT:
					as_x (0217,000,instruction->instruction_parameters[1].parameter_offset,
						instruction->instruction_parameters[1].parameter_data.ir);
					return;
				default:
					internal_error_in_function ("as_move_instruction");
					return;
			}
		case P_LABEL:
			if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
				as_r_a (0211,instruction->instruction_parameters[0].parameter_data.reg.r,instruction->instruction_parameters[1].parameter_data.l);
				return;
			}
		default:
			internal_error_in_function ("as_move_instruction");
	}
}

static void as_moveb_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_REGISTER:
		{
			int reg;
			
			reg=instruction->instruction_parameters[1].parameter_data.reg.r;
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_REGISTER:
					if (reg_num (reg)>=4){
						store_c (0x90+reg_num (reg)); /* xchg r,D0 */

						if (reg_num (instruction->instruction_parameters[0].parameter_data.reg.r)>=4){
							if (instruction->instruction_parameters[0].parameter_data.reg.r!=reg){
								as_r_r (0207,instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_D1); /* xchg r,D1 */
								as_r_r (0212,REGISTER_D1,REGISTER_D0);
								as_r_r (0207,instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_D1); /* xchg r,D1 */
							}
						} else
							as_r_r (0212,instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_D0);

						store_c (0x90+reg_num (reg)); /* xchg r,D0 */
					} else {
						if (reg_num (instruction->instruction_parameters[0].parameter_data.reg.r)>=4){
							store_c (0x90+reg_num (instruction->instruction_parameters[0].parameter_data.reg.r)); /* xchg r,D0 */
							as_r_r (0212,REGISTER_D0,reg);						
							store_c (0x90+reg_num (instruction->instruction_parameters[0].parameter_data.reg.r)); /* xchg r,D0 */						
						} else
							as_r_r (0212,instruction->instruction_parameters[0].parameter_data.reg.r,reg);
					}
					return;
				case P_IMMEDIATE:
					if (reg_num (reg)>=4){
						store_c (0x90+reg_num (reg)); /* xchg r,D0 */
						store_c (0260 | reg_num (REGISTER_D0));
						store_c (instruction->instruction_parameters[0].parameter_data.i);
	
						store_c (0x90+reg_num (reg)); /* xchg r,D0 */
					} else {
						store_c (0260 | reg_num (reg));
						store_c (instruction->instruction_parameters[0].parameter_data.i);
					}
					return;
				case P_INDIRECT:
					/* movzbl */
					store_c (017);
					as_id_r (0266,instruction->instruction_parameters[0].parameter_offset,instruction->instruction_parameters[0].parameter_data.reg.r,reg);
					return;
				case P_INDEXED:
					/* movzbl */
					store_c (017);
					as_x_r (0266,instruction->instruction_parameters[0].parameter_offset,instruction->instruction_parameters[0].parameter_data.ir,reg);
					return;
			}

			break;
		}
		case P_INDIRECT:
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_IMMEDIATE:
				{
					int reg1,offset;
			
					offset=instruction->instruction_parameters[1].parameter_offset;
					reg1=instruction->instruction_parameters[1].parameter_data.reg.r;
				
					store_c (0306);

					if (reg1==ESP){
						if (offset==0){
							store_c (0x04);
							store_c (0044);
						} else if (((signed char)offset)==offset){
							store_c (0x44);
							store_c (0044);
							store_c (offset);
						} else {
							store_c (0x84);
							store_c (0044);
							store_l (offset);		
						}
					} else {
						if (offset==0 && reg1!=EBP){
							store_c (reg_num (reg1));
						} else if (((signed char)offset)==offset){
							store_c (0x40 | reg_num (reg1));
							store_c (offset);
						} else {
							store_c (0x80 | reg_num (reg1));
							store_l (offset);		
						}
					}
					store_c (instruction->instruction_parameters[0].parameter_data.i);
					return;
				}
				case P_REGISTER:
					if (reg_num (instruction->instruction_parameters[0].parameter_data.reg.r)>=4){
						int reg,reg1;
						
						reg=instruction->instruction_parameters[0].parameter_data.reg.r;
						
						store_c (0x90+reg_num (reg)); /* xchg r,D0 */

						reg1=instruction->instruction_parameters[1].parameter_data.reg.r;
						if (reg1==reg)
							reg1=REGISTER_D0;
						else if (reg1==REGISTER_D0)
							reg1=reg;

						as_r_id (0210,REGISTER_D0,instruction->instruction_parameters[1].parameter_offset,reg1);

						store_c (0x90+reg_num (reg)); /* xchg r,D0 */					
					} else
						as_r_id (0210,instruction->instruction_parameters[0].parameter_data.reg.r,
							instruction->instruction_parameters[1].parameter_offset,
							instruction->instruction_parameters[1].parameter_data.reg.r);
					
					return;
			}
			break;
		case P_INDEXED:
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_IMMEDIATE:
				{
					int reg1,reg2,shift,offset;
				
					offset=instruction->instruction_parameters[1].parameter_offset;
					reg1=instruction->instruction_parameters[1].parameter_data.ir->a_reg.r;
					reg2=instruction->instruction_parameters[1].parameter_data.ir->d_reg.r;
				
					shift=offset & 3;
					offset=offset>>2;
					
					if (reg2==ESP)
						internal_error_in_function ("as_moveb_instruction");
						
					store_c (0306);
				
					if (offset==0 && reg1!=EBP){
						store_c (0x04);
						store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
					} else if (((signed char)offset)==offset){
						store_c (0x44);
						store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
						store_c (offset);
					} else {
						store_c (0x84);
						store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
						store_l (offset);
					}
					store_c (instruction->instruction_parameters[0].parameter_data.i);

					return;
				}
				case P_REGISTER:
					if (reg_num (instruction->instruction_parameters[0].parameter_data.reg.r)>=4){
						int reg,reg1,reg2;
						
						reg=instruction->instruction_parameters[0].parameter_data.reg.r;

						store_c (0x90+reg_num (reg)); /* xchg r,D0 */

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
					
						as_xr_r (0210,instruction->instruction_parameters[1].parameter_offset,reg1,reg2,REGISTER_D0);

						store_c (0x90+reg_num (reg)); /* xchg r,D0 */					
					} else
						as_r_x (0210,instruction->instruction_parameters[0].parameter_data.reg.r,
							instruction->instruction_parameters[1].parameter_offset,
							instruction->instruction_parameters[1].parameter_data.ir);
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
				case P_REGISTER:
					store_c (0146);
					as_r_r (0213,instruction->instruction_parameters[0].parameter_data.reg.r,reg);
					return;
				case P_IMMEDIATE:
					store_c (0146);
					store_c (0270 | reg_num (reg));
					store_w (instruction->instruction_parameters[0].parameter_data.i);
					return;
				case P_INDIRECT:
					store_c (0017);
					as_id_r (0277,instruction->instruction_parameters[0].parameter_offset,instruction->instruction_parameters[0].parameter_data.reg.r,reg);
					return;
				case P_INDEXED:
					store_c (0017);
					as_x_r (0277,instruction->instruction_parameters[0].parameter_offset,instruction->instruction_parameters[0].parameter_data.ir,reg);
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
				as_id_r (0215,instruction->instruction_parameters[0].parameter_offset,
					instruction->instruction_parameters[0].parameter_data.reg.r,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;
			case P_INDEXED:
				as_x_r (00215,instruction->instruction_parameters[0].parameter_offset,
					instruction->instruction_parameters[0].parameter_data.ir,
					instruction->instruction_parameters[1].parameter_data.reg.r);
				return;					
		}
	}
	internal_error_in_function ("as_lea_instruction");
}

static void as_add_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_r_r (0003,instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
			as_i_r2 (0201,0000,0005,instruction->instruction_parameters[0].parameter_data.i,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_INDIRECT:
			as_id_r (0003,instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_INDEXED:
			as_x_r (0003,instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.ir,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;					
		default:
			internal_error_in_function ("as_add_instruction");
			return;
	}
}

static void as_sub_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_r_r (0053,instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
			as_i_r2 (0201,0050,0055,instruction->instruction_parameters[0].parameter_data.i,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_INDIRECT:
			as_id_r (0053,instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_INDEXED:
			as_x_r (0053,instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.ir,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;					
		default:
			internal_error_in_function ("as_sub_instruction");
			return;
	}
}

static void as_adc_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_r_r (0023,instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
			as_i_r2 (0201,0020,0025,instruction->instruction_parameters[0].parameter_data.i,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_INDIRECT:
			as_id_r (0023,instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_INDEXED:
			as_x_r (0023,instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.ir,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;					
		default:
			internal_error_in_function ("as_adc_instruction");
			return;
	}
}

static void as_sbb_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_r_r (0033,instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_IMMEDIATE:
			as_i_r2 (0201,0030,0035,instruction->instruction_parameters[0].parameter_data.i,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_INDIRECT:
			as_id_r (0033,instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_INDEXED:
			as_x_r (0033,instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.ir,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;					
		default:
			internal_error_in_function ("as_sbb_instruction");
			return;
	}
}

enum { SIZE_LONG, SIZE_WORD, SIZE_BYTE };

static void as_cmp_i_parameter (int i,struct parameter *parameter)
{
	switch (parameter->parameter_type){
		case P_REGISTER:
		{
			int r;
			
			r=parameter->parameter_data.reg.r;
			if (i==0){
				r=reg_num (r);
				store_c (0205); /* test */
				store_c (0300 | (r<<3) | r);
			} else
				as_i_r2 (0201,0070,0075,i,r);
			return;
		}
		case P_INDIRECT:
			as_i_id2 (0201,0070,i,parameter->parameter_offset,parameter->parameter_data.reg.r);
			return;
		case P_INDEXED:
			as_i_x2 (0201,0070,i,parameter->parameter_offset,parameter->parameter_data.ir);
			return;
		default:
			internal_error_in_function ("as_cmp_i_parameter");
	}
}

static void as_cmp_instruction (struct instruction *instruction)
{
	struct parameter parameter_0,parameter_1;

	parameter_0=instruction->instruction_parameters[0];
	parameter_1=instruction->instruction_parameters[1];

	switch (parameter_0.parameter_type){
		case P_DESCRIPTOR_NUMBER:
			switch (parameter_1.parameter_type){
				case P_REGISTER:
					as_d_r2 (0201,0070,0075,parameter_0.parameter_data.l,parameter_0.parameter_offset,
						parameter_1.parameter_data.reg.r);
					return;
				case P_INDIRECT:
					as_d_id (0201,0070,parameter_0.parameter_data.l,parameter_0.parameter_offset,
						parameter_1.parameter_offset,parameter_1.parameter_data.reg.r);
					return;
				case P_INDEXED:
					as_d_x (0201,0070,parameter_0.parameter_data.l,parameter_0.parameter_offset,
						parameter_1.parameter_offset,parameter_1.parameter_data.ir);
					return;
			}
			break;
		case P_IMMEDIATE:
			as_cmp_i_parameter (parameter_0.parameter_data.i,&parameter_1);
			return;
	}

	if (parameter_1.parameter_type==P_REGISTER)
		switch (parameter_0.parameter_type){
			case P_REGISTER:
				as_r_r (0073,parameter_0.parameter_data.reg.r,parameter_1.parameter_data.reg.r);
				return;
			case P_INDIRECT:
				as_id_r (0073,parameter_0.parameter_offset,parameter_0.parameter_data.reg.r,parameter_1.parameter_data.reg.r);
				return;
			case P_INDEXED:
				as_x_r (0073,parameter_0.parameter_offset,parameter_0.parameter_data.ir,parameter_1.parameter_data.reg.r);
				return;					
		}

	internal_error_in_function ("as_cmp_instruction");
}

#if 0
static void as_cmpw_instruction (struct instruction *instruction)
{
	struct parameter parameter_0,parameter_1;

	parameter_0=instruction->instruction_parameters[0];
	parameter_1=instruction->instruction_parameters[1];

	if (parameter_1.parameter_type==P_INDIRECT){
		/* movswl */
		store_c (0017);
		as_id_r (0277,instruction->instruction_parameters[1].parameter_offset,
			instruction->instruction_parameters[1].parameter_data.reg.r,REGISTER_O0);

		parameter_1.parameter_type=P_REGISTER;
		parameter_1.parameter_data.reg.r=REGISTER_O0;
	}

	switch (parameter_0.parameter_type){
		case P_DESCRIPTOR_NUMBER:
			switch (parameter_1.parameter_type){
				case P_REGISTER:
					as_d_r2 (0201,0070,0075,parameter_0.parameter_data.l,parameter_0.parameter_offset,
						parameter_1.parameter_data.reg.r);
					return;
				case P_INDIRECT:
					as_d_id (0201,0070,parameter_0.parameter_data.l,parameter_0.parameter_offset,
						parameter_1.parameter_offset,parameter_1.parameter_data.reg.r);
					return;
				case P_INDEXED:
					as_d_x (0201,0070,parameter_0.parameter_data.l,parameter_0.parameter_offset,
						parameter_1.parameter_offset,parameter_1.parameter_data.ir);
					return;
			}
			break;
		case P_IMMEDIATE:
			as_cmp_i_parameter (parameter_0.parameter_data.i,&parameter_1);
			return;
		case P_INDIRECT:
			/* movswl */
			store_c (0017);
			as_id_r (0277,instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r,REGISTER_O0);
	
			parameter_0.parameter_type=P_REGISTER;
			parameter_0.parameter_data.reg.r=REGISTER_O0;
	}

	if (parameter_1.parameter_type==P_REGISTER)
		switch (parameter_0.parameter_type){
			case P_REGISTER:
				as_r_r (0073,parameter_0.parameter_data.reg.r,parameter_1.parameter_data.reg.r);
				return;
			case P_INDIRECT:
				as_id_r (0073,parameter_0.parameter_offset,parameter_0.parameter_data.reg.r,parameter_1.parameter_data.reg.r);
				return;
			case P_INDEXED:
				as_x_r (0073,parameter_0.parameter_offset,parameter_0.parameter_data.ir,parameter_1.parameter_data.reg.r);
				return;					
		}

	internal_error_in_function ("as_cmpw_instruction");
}
#endif

void store_label_in_data_section (LABEL *label)
{
	store_label_plus_offset_in_data_section (label,0);
}

void store_descriptor_in_data_section (LABEL *label)
{
	store_label_plus_offset_in_data_section (label,2);
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

static void as_jmp_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_LABEL:
			store_c (0351);
			store_l (0);
			as_branch_label (instruction->instruction_parameters[0].parameter_data.l,JUMP_RELOCATION);
			break;
		case P_INDIRECT:
			as_id (0377,040,instruction->instruction_parameters[0].parameter_offset,
							instruction->instruction_parameters[0].parameter_data.reg.r);
			break;
		case P_REGISTER:
			store_c (0377);
			store_c (0340 | reg_num (instruction->instruction_parameters[0].parameter_data.reg.r));
			break;
		default:
			internal_error_in_function ("as_jmp_instruction");
	}
}

static void as_jmpp_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_LABEL:
		{
			int offset;
			
			offset=instruction->instruction_parameters[0].parameter_offset;
			
			if (offset==0){
				store_c (0350);
				store_l (0);
				as_branch_label (profile_t_label,CALL_RELOCATION);				
			}
			
			store_c (0351);
			store_l (offset);
			as_branch_label (instruction->instruction_parameters[0].parameter_data.l,JUMP_RELOCATION);
			break;
		}
		case P_INDIRECT:
			store_c (0350);
			store_l (0);
			as_branch_label (profile_t_label,CALL_RELOCATION);				

			as_id (0377,040,instruction->instruction_parameters[0].parameter_offset,
							instruction->instruction_parameters[0].parameter_data.reg.r);
			break;
		case P_REGISTER:
			store_c (0350);
			store_l (0);
			as_branch_label (profile_t_label,CALL_RELOCATION);				

			store_c (0377);
			store_c (0340 | reg_num (instruction->instruction_parameters[0].parameter_data.reg.r));
			break;
		default:
			internal_error_in_function ("as_jmpp_instruction");
	}
}

static void as_jsr_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_LABEL:
			store_c (0350);
			store_l (0);
			as_branch_label (instruction->instruction_parameters[0].parameter_data.l,CALL_RELOCATION);
			break;
		case P_INDIRECT:
			as_id (0377,020,instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r);
			break;
		case P_REGISTER:
			store_c (0377);
			store_c (0320 | reg_num (instruction->instruction_parameters[0].parameter_data.reg.r));
			break;
		default:
			internal_error_in_function ("as_jsr_instruction");
	}
}

static void as_branch_instruction (struct instruction *instruction,int condition_code)
{
	store_c (017);
	store_c (0200 | condition_code);
	store_l (0);
	as_branch_label (instruction->instruction_parameters[0].parameter_data.l,BRANCH_RELOCATION);
}

static void as_move_r_r (int reg1,int reg2)
{
	as_r_r (0213,reg1,reg2);
}

static void as_shift_instruction (struct instruction *instruction,int shift_code)
{
	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
		store_c (0301);
		store_c (0300 | (shift_code<<3) | reg_num (instruction->instruction_parameters[1].parameter_data.reg.r));
		store_c (instruction->instruction_parameters[0].parameter_data.i & 31);
	} else if (
		instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
		instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A0
	){
		store_c (0323);
		store_c (0300 | (shift_code<<3) | reg_num (instruction->instruction_parameters[1].parameter_data.reg.r));
	} else {
		int r;

		as_move_r_r (REGISTER_A0,REGISTER_O0);

		as_move_parameter_reg (&instruction->instruction_parameters[0],REGISTER_A0);
		
		r=instruction->instruction_parameters[1].parameter_data.reg.r;
		if (r==REGISTER_A0)
			r=REGISTER_O0;
		store_c (0323);
		store_c (0300 | (shift_code<<3) | reg_num (r));

		as_move_r_r (REGISTER_O0,REGISTER_A0);
	}
}

static void as_shift_s_instruction (struct instruction *instruction,int shift_code)
{
	if (instruction->instruction_parameters[0].parameter_type!=P_REGISTER){
		if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
			store_c (0301);
			store_c (0300 | (shift_code<<3) | reg_num (instruction->instruction_parameters[1].parameter_data.reg.r));
			store_c (instruction->instruction_parameters[0].parameter_data.i & 31);
		} else
			internal_error_in_function ("as_shift_s_instruction");
	} else {
		int r0,r1;

		r0=instruction->instruction_parameters[0].parameter_data.reg.r;
		r1=instruction->instruction_parameters[1].parameter_data.reg.r;
		if (r0==REGISTER_A0){
			store_c (0323);
			store_c (0300 | (shift_code<<3) | reg_num (r1));
		} else {
			int scratch_register;

			scratch_register=instruction->instruction_parameters[2].parameter_data.reg.r;
			if (scratch_register==REGISTER_A0){
				as_move_r_r (r0,REGISTER_A0);

				store_c (0323);
				store_c (0300 | (shift_code<<3) | reg_num (r1));
			} else {
				as_move_r_r (REGISTER_A0,scratch_register);
				as_move_r_r (r0,REGISTER_A0);
				
				if (r1==REGISTER_A0)
					r1=scratch_register;
				store_c (0323);
				store_c (0300 | (shift_code<<3) | reg_num (r1));

				as_move_r_r (scratch_register,REGISTER_A0);
			}
		}
	}
}

static void as_logic_instruction (struct instruction *instruction,int code1,int code2,int code3)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			as_r_r (code1,instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_INDIRECT:
			as_id_r (code1,instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;
		case P_INDEXED:
			as_x_r (code1,instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.ir,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			return;					
		case P_IMMEDIATE:
			if (instruction->instruction_parameters[1].parameter_data.reg.r==EAX)
				store_c (code3);
			else
				as_r (0201,code2,instruction->instruction_parameters[1].parameter_data.reg.r);
			store_l (instruction->instruction_parameters[0].parameter_data.i);
			return;
		default:
			internal_error_in_function ("as_logic_instruction");
	}
}

static void as_mul_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
			store_c (017);
			as_r_r (0257,instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			break;
		case P_INDIRECT:
			store_c (017);
			as_id_r (0257,instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.reg.r,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			break;
		case P_INDEXED:
			store_c (017);
			as_x_r (0257,instruction->instruction_parameters[0].parameter_offset,
				instruction->instruction_parameters[0].parameter_data.ir,
				instruction->instruction_parameters[1].parameter_data.reg.r);
			break;
		case P_IMMEDIATE:
		{
			int r,i;
			
			r=reg_num (instruction->instruction_parameters[1].parameter_data.reg.r);
			i=instruction->instruction_parameters[0].parameter_data.i;
			
			if ((signed char)i==i){
				store_c (0153);
				store_c (0300 | (r<<3) | r);
				store_c (i);
			} else {
				store_c (0151);
				store_c (0300 | (r<<3) | r);
				store_l (i);
			}
			break;
		}
		default:
			internal_error_in_function ("as_mul_instruction");
	}
}

static void as_parameter (int code1,int code2,struct parameter *parameter)
{
	switch (parameter->parameter_type){
		case P_REGISTER:
			as_r (code1,code2,parameter->parameter_data.reg.r);
			break;
		case P_INDIRECT:
			as_id (code1,code2,parameter->parameter_offset,parameter->parameter_data.reg.r);
			break;
		case P_INDEXED:
			as_x (code1,code2,parameter->parameter_offset,parameter->parameter_data.ir);
			break;
		default:
			internal_error_in_function ("as_parameter");
	}
}

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

static void as_div_rem_i_instruction (struct instruction *instruction,int compute_remainder)
{
	int s_reg1,s_reg2,s_reg3,i,sd_reg,i_reg,tmp_reg,abs_i;
#ifdef THREAD32
	int tmp2_reg;
#endif
	struct ms ms;

	if (instruction->instruction_parameters[0].parameter_type!=P_IMMEDIATE)
		internal_error_in_function ("as_div_rem_i_instruction");
		
	i=instruction->instruction_parameters[0].parameter_data.i;

	if (! ((i>1 || (i<-1 && i!=0x80000000))))
		internal_error_in_function ("as_div_rem_i_instruction");
	
	abs_i=abs (i);

	if (compute_remainder)
		i=abs_i;

	ms=magic (abs_i);

	sd_reg=instruction->instruction_parameters[1].parameter_data.reg.r;
	tmp_reg=instruction->instruction_parameters[2].parameter_data.reg.r;

#ifndef THREAD32
	if (sd_reg==tmp_reg)
		internal_error_in_function ("as_div_rem_i_instruction");		

	if (sd_reg==REGISTER_A1){
		if (tmp_reg!=REGISTER_D0)
			as_move_r_r (REGISTER_D0,tmp_reg);
		as_move_r_r (REGISTER_A1,REGISTER_O0);
		
		s_reg1=sd_reg;
		s_reg2=REGISTER_O0;
		i_reg=REGISTER_D0;
	} else if (sd_reg==REGISTER_D0){
		if (tmp_reg!=REGISTER_A1)
			as_move_r_r (REGISTER_A1,tmp_reg);
		as_move_r_r (REGISTER_D0,REGISTER_O0);

		s_reg1=REGISTER_A1;
		s_reg2=REGISTER_O0;
		i_reg=REGISTER_A1;
	} else {
		if (tmp_reg==REGISTER_D0)
			as_move_r_r (REGISTER_A1,REGISTER_O0);			
		else if (tmp_reg==REGISTER_A1)
			as_move_r_r (REGISTER_D0,REGISTER_O0);						
		else {
			as_move_r_r (REGISTER_D0,REGISTER_O0);
			as_move_r_r (REGISTER_A1,tmp_reg);			
		}
		
		s_reg1=sd_reg;
		s_reg2=sd_reg;
		i_reg=REGISTER_D0;
	}
#else
	tmp2_reg=instruction->instruction_parameters[3].parameter_data.reg.r;

	if (sd_reg==tmp_reg || sd_reg==tmp2_reg)
		internal_error_in_function ("as_div_rem_i_instruction");		

	if (sd_reg==REGISTER_A1){
		if (tmp2_reg==REGISTER_D0){
			s_reg2=tmp_reg;
		} else {
			if (tmp_reg!=REGISTER_D0)
				as_move_r_r (REGISTER_D0,tmp_reg);
			s_reg2=tmp2_reg;
		}
		as_move_r_r (REGISTER_A1,s_reg2);
		s_reg1=REGISTER_A1;
		i_reg=REGISTER_D0;
	} else if (sd_reg==REGISTER_D0){
		if (tmp2_reg==REGISTER_A1){
			s_reg2=tmp_reg;
		} else {
			if (tmp_reg!=REGISTER_A1)
				as_move_r_r (REGISTER_A1,tmp_reg);
			s_reg2=tmp2_reg;
		}
		as_move_r_r (REGISTER_D0,s_reg2);
		s_reg1=REGISTER_A1;
		i_reg=REGISTER_A1;
	} else {
		if (tmp_reg==REGISTER_D0){
			if (tmp2_reg!=REGISTER_A1)
				as_move_r_r (REGISTER_A1,tmp2_reg);
		} else if (tmp_reg==REGISTER_A1){
			if (tmp2_reg!=REGISTER_D0)
				as_move_r_r (REGISTER_D0,tmp2_reg);
		} else {
			if (tmp2_reg==REGISTER_D0){
				as_move_r_r (REGISTER_A1,tmp_reg);
			} else if (tmp2_reg==REGISTER_A1){
				as_move_r_r (REGISTER_D0,tmp_reg);
			} else {
				as_move_r_r (REGISTER_D0,tmp2_reg);
				as_move_r_r (REGISTER_A1,tmp_reg);
			}
		}

		s_reg1=sd_reg;
		s_reg2=sd_reg;
		i_reg=REGISTER_D0;
	}
#endif

	as_move_i_r (ms.m,i_reg);

	as_r (0367,0050,s_reg1); /* imul */

	if (compute_remainder)
		as_move_r_r (s_reg2,REGISTER_D0);

	if (ms.m<0)
		as_r_r (0003,s_reg2,REGISTER_A1); /* add */

	if (compute_remainder){
		if (s_reg2==sd_reg && s_reg2!=REGISTER_D0 && s_reg2!=REGISTER_A1){
			s_reg3=s_reg2;
			s_reg2=REGISTER_D0;
		} else
			s_reg3=REGISTER_D0;
	}

	if (i>=0)
		as_shr_i_r (31,s_reg2);
	else
		as_sar_i_r (31,s_reg2);

	if (ms.s>0)
		as_sar_i_r (ms.s,REGISTER_A1);

	if (!compute_remainder){
		if (sd_reg==REGISTER_A1){
			if (i>=0)
				as_r_r (0003,s_reg2,REGISTER_A1); /* add */
			else {
				as_r_r (0053,REGISTER_A1,s_reg2); /* sub */
				as_move_r_r (s_reg2,sd_reg);
			}
		} else if (sd_reg==REGISTER_D0){
			struct index_registers index_registers;

			if (i>=0){
				index_registers.a_reg.r=REGISTER_A1;
				index_registers.d_reg.r=s_reg2;
				
				/* lea */
				as_x_r (00215,0,&index_registers,sd_reg);
			} else {
				as_move_r_r (s_reg2,sd_reg);				
				as_r_r (0053,REGISTER_A1,sd_reg);/* sub */
			}
		} else {
			if (i>=0)
				as_r_r (0003,REGISTER_A1,s_reg2); /* add */ /* s_reg2==sd_reg */
			else
				as_r_r (0053,REGISTER_A1,s_reg2); /* sub */ /* s_reg2==sd_reg */
		}
	} else {
		int r,i2;
		
		as_r_r (0003,s_reg2,REGISTER_A1); /* add */

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
					/* shl */
					store_c (0301);
					store_c (0300 | (4<<3) | reg_num (REGISTER_A1));
					store_c (n_shifts);
				}
				
				as_r_r (0053,REGISTER_A1,s_reg3); /* sub */

				n>>=1;
				n_shifts=1;
			}
		} else {
			/* imul */
			r=reg_num (REGISTER_A1);
			if ((signed char)i==i){
				store_c (0153);
				store_c (0300 | (r<<3) | r);
				store_c (i);
			} else {
				store_c (0151);
				store_c (0300 | (r<<3) | r);
				store_l (i);
			}

			as_r_r (0053,REGISTER_A1,s_reg3); /* sub */
		}
		
		if (sd_reg!=s_reg3)
			as_move_r_r (s_reg3,sd_reg);
	}

#ifndef THREAD32
	if (sd_reg==REGISTER_A1){
		if (tmp_reg!=REGISTER_D0)
			as_move_r_r (tmp_reg,REGISTER_D0);
	} else if (sd_reg==REGISTER_D0){
		if (tmp_reg!=REGISTER_A1)
			as_move_r_r (tmp_reg,REGISTER_A1);
	} else {
		if (tmp_reg==REGISTER_D0)
			as_move_r_r (REGISTER_O0,REGISTER_A1);
		else if (tmp_reg==REGISTER_A1)
			as_move_r_r (REGISTER_O0,REGISTER_D0);						
		else {
			as_move_r_r (REGISTER_O0,REGISTER_D0);			
			as_move_r_r (tmp_reg,REGISTER_A1);			
		}
	}
#else
	if (sd_reg==REGISTER_A1){
		if (tmp2_reg!=REGISTER_D0 && tmp_reg!=REGISTER_D0)
			as_move_r_r (tmp_reg,REGISTER_D0);
	} else if (sd_reg==REGISTER_D0){
		if (tmp2_reg!=REGISTER_A1 && tmp_reg!=REGISTER_A1)
			as_move_r_r (tmp_reg,REGISTER_A1);
	} else {
		if (tmp_reg==REGISTER_D0){
			if (tmp2_reg!=REGISTER_A1)
				as_move_r_r (tmp2_reg,REGISTER_A1);
		} else if (tmp_reg==REGISTER_A1){
			if (tmp2_reg!=REGISTER_D0)
				as_move_r_r (tmp2_reg,REGISTER_D0);						
		} else {
			if (tmp2_reg==REGISTER_D0){
				as_move_r_r (tmp_reg,REGISTER_A1);
			} else if (tmp2_reg==REGISTER_A1){
				as_move_r_r (tmp_reg,REGISTER_D0);
			} else {
				as_move_r_r (tmp2_reg,REGISTER_D0);			
				as_move_r_r (tmp_reg,REGISTER_A1);
			}
		}
	}
#endif
}

#ifndef THREAD32
static void as_div_instruction (struct instruction *instruction,int unsigned_div)
{
	int d_reg,opcode2;

	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE && unsigned_div==0){
		int i,log2i;
		
		i=instruction->instruction_parameters[0].parameter_data.i;
		
		if (! ((i & (i-1))==0 && i>0)){
			internal_error_in_function ("as_div_instruction");
			return;
		}
		
		if (i==1)
			return;
		
		log2i=0;
		while (i>1){
			i=i>>1;
			++log2i;
		}
		
		as_move_r_r (d_reg,REGISTER_O0);

		if (log2i==1){
			as_sar_i_r (31,REGISTER_O0);

			as_r_r (0053,REGISTER_O0,d_reg); /* sub */
		} else {
			as_sar_i_r (31,d_reg);

			/* and */
			if (d_reg==EAX)
				store_c (045);
			else
				as_r (0201,040,d_reg);
			store_l ((1<<log2i)-1);

			as_r_r (0003,REGISTER_O0,d_reg); /* add */
		}
		
		as_sar_i_r (log2i,d_reg);

		return;
	}

	opcode2=unsigned_div ? 0060 : 0070;

	switch (d_reg){
		case REGISTER_D0:
			as_move_r_r (REGISTER_A1,REGISTER_O0);
	
			if (unsigned_div)
				as_r_r (0063,REGISTER_A1,REGISTER_A1);	/* xor */
			else
				store_c (0231);							/* cdq */
	
			/* idivl */
			if (instruction->instruction_parameters[0].parameter_type==P_REGISTER
				&& instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A1)
			{
				as_r (0367,opcode2,REGISTER_O0);
			} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT
				&& instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A1)
			{
				as_id (0367,opcode2,instruction->instruction_parameters[0].parameter_offset,REGISTER_O0);
			} else
				as_parameter (0367,opcode2,&instruction->instruction_parameters[0]);
			
			as_move_r_r (REGISTER_O0,REGISTER_A1);
			break;
		case REGISTER_A1:
			as_move_r_r (REGISTER_D0,REGISTER_O0);
			as_move_r_r (REGISTER_A1,REGISTER_D0);
	
			if (unsigned_div)
				as_r_r (0063,REGISTER_A1,REGISTER_A1);	/* xor */
			else
				store_c (0231);							/* cdq */
	
			/* idivl */
			if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
				int r;
				
				r=instruction->instruction_parameters[0].parameter_data.reg.r;
				if (r==REGISTER_D0)
					r=REGISTER_O0;
				else if (r==REGISTER_A1)
					r=REGISTER_D0;
				
				as_r (0367,opcode2,r);
			} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
				int r;
				
				r=instruction->instruction_parameters[0].parameter_data.reg.r;
				if (r==REGISTER_D0)
					r=REGISTER_O0;
				else if (r==REGISTER_A1)
					r=REGISTER_D0;

				as_id (0367,opcode2,instruction->instruction_parameters[0].parameter_offset,r);					
			} else
				as_parameter (00367,opcode2,&instruction->instruction_parameters[0]);
	
			as_move_r_r (REGISTER_D0,REGISTER_A1);
			as_move_r_r (REGISTER_O0,REGISTER_D0);
			break;
		default:
			as_move_r_r (REGISTER_A1,REGISTER_O0);
			store_c (0x90+reg_num (d_reg));	/* xchg d_reg,D0 */
	
			if (unsigned_div)
				as_r_r (0063,REGISTER_A1,REGISTER_A1);	/* xor */
			else
				store_c (0231);							/* cdq */
	
			/* idivl */
			if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
				int r;
				
				r=instruction->instruction_parameters[0].parameter_data.reg.r;
				if (r==REGISTER_D0)
					r=d_reg;
				else if (r==REGISTER_A1)
					r=REGISTER_O0;
				else if (r==d_reg)
					r=REGISTER_D0;
				
				as_r (0367,opcode2,r);			
			} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
				int r;
				
				r=instruction->instruction_parameters[0].parameter_data.reg.r;
				if (r==REGISTER_D0)
					r=d_reg;
				else if (r==REGISTER_A1)
					r=REGISTER_O0;
				else if (r==d_reg)
					r=REGISTER_D0;
				
				as_id (0367,opcode2,instruction->instruction_parameters[0].parameter_offset,r);
			} else
				as_parameter (0367,0070,&instruction->instruction_parameters[0]);
	
			store_c (0x90+reg_num (d_reg)); /* xchg d_reg,D0 */
			as_move_r_r (REGISTER_O0,REGISTER_A1);
	}
}
#else
static void as_div_instruction (struct instruction *instruction,int unsigned_div)
{
	int d_reg,tmp_reg,opcode2;

	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;
	tmp_reg=instruction->instruction_parameters[2].parameter_data.reg.r;

	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE && unsigned_div==0){
		int i,log2i;
		
		i=instruction->instruction_parameters[0].parameter_data.i;
		
		if (! ((i & (i-1))==0 && i>0)){
			internal_error_in_function ("as_div_instruction");
			return;
		}
		
		if (i==1)
			return;

		log2i=0;
		while (i>1){
			i=i>>1;
			++log2i;
		}

		as_move_r_r (d_reg,tmp_reg);

		if (log2i==1){
			as_sar_i_r (31,tmp_reg);

			as_r_r (0053,tmp_reg,d_reg); /* sub */
		} else {
			as_sar_i_r (31,d_reg);

			/* and */
			if (d_reg==EAX)
				store_c (045);
			else
				as_r (0201,040,d_reg);
			store_l ((1<<log2i)-1);

			as_r_r (0003,tmp_reg,d_reg); /* add */
		}
		
		as_sar_i_r (log2i,d_reg);

		return;
	}

	opcode2=unsigned_div ? 0060 : 0070;

	switch (d_reg){
		case REGISTER_D0:
			if (tmp_reg==REGISTER_A1){
				if (unsigned_div)
					as_r_r (0063,REGISTER_A1,REGISTER_A1);	/* xor */
				else
					store_c (0231);							/* cdq */
		
				/* idivl */
				as_parameter (0367,opcode2,&instruction->instruction_parameters[0]);
			} else {
				as_move_r_r (REGISTER_A1,tmp_reg);
		
				if (unsigned_div)
					as_r_r (0063,REGISTER_A1,REGISTER_A1);	/* xor */
				else
					store_c (0231);							/* cdq */

				/* idivl */
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER
					&& instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A1)
				{
					as_r (0367,opcode2,tmp_reg);
				} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT
					&& instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A1)
				{
					as_id (0367,opcode2,instruction->instruction_parameters[0].parameter_offset,tmp_reg);
				} else
					as_parameter (0367,opcode2,&instruction->instruction_parameters[0]);
				
				as_move_r_r (tmp_reg,REGISTER_A1);
			}
			break;
		case REGISTER_A1:
			if (tmp_reg==REGISTER_D0){
				as_move_r_r (REGISTER_A1,REGISTER_D0);
		
				if (unsigned_div)
					as_r_r (0063,REGISTER_A1,REGISTER_A1);	/* xor */
				else
					store_c (0231);							/* cdq */
		
				/* idivl */
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_A1)
						r=REGISTER_D0;
					
					as_r (0367,opcode2,r);
				} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_A1)
						r=REGISTER_D0;

					as_id (0367,opcode2,instruction->instruction_parameters[0].parameter_offset,r);					
				} else
					as_parameter (00367,opcode2,&instruction->instruction_parameters[0]);
		
				as_move_r_r (REGISTER_D0,REGISTER_A1);
			} else {
				as_move_r_r (REGISTER_D0,tmp_reg);
				as_move_r_r (REGISTER_A1,REGISTER_D0);
		
				if (unsigned_div)
					as_r_r (0063,REGISTER_A1,REGISTER_A1);	/* xor */
				else
					store_c (0231);							/* cdq */
		
				/* idivl */
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=tmp_reg;
					else if (r==REGISTER_A1)
						r=REGISTER_D0;
					
					as_r (0367,opcode2,r);
				} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=tmp_reg;
					else if (r==REGISTER_A1)
						r=REGISTER_D0;

					as_id (0367,opcode2,instruction->instruction_parameters[0].parameter_offset,r);					
				} else
					as_parameter (00367,opcode2,&instruction->instruction_parameters[0]);
		
				as_move_r_r (REGISTER_D0,REGISTER_A1);
				as_move_r_r (tmp_reg,REGISTER_D0);
			}
			break;
		default:
			if (tmp_reg==REGISTER_D0){
				as_move_r_r (d_reg,REGISTER_D0);
				as_move_r_r (REGISTER_A1,d_reg);

				if (unsigned_div)
					as_r_r (0063,REGISTER_A1,REGISTER_A1);	/* xor */
				else
					store_c (0231);							/* cdq */
		
				/* idivl */
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_A1)
						r=d_reg;
					else if (r==d_reg)
						r=REGISTER_D0;
					
					as_r (0367,opcode2,r);			
				} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_A1)
						r=d_reg;
					else if (r==d_reg)
						r=REGISTER_D0;
					
					as_id (0367,opcode2,instruction->instruction_parameters[0].parameter_offset,r);
				} else
					as_parameter (0367,0070,&instruction->instruction_parameters[0]);

				as_move_r_r (d_reg,REGISTER_A1);
				as_move_r_r (REGISTER_D0,d_reg);
			} else if (tmp_reg==REGISTER_A1){
				store_c (0x90+reg_num (d_reg));	/* xchg d_reg,D0 */
		
				if (unsigned_div)
					as_r_r (0063,REGISTER_A1,REGISTER_A1);	/* xor */
				else
					store_c (0231);							/* cdq */
		
				/* idivl */
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=d_reg;
					else if (r==d_reg)
						r=REGISTER_D0;
					
					as_r (0367,opcode2,r);			
				} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=d_reg;
					else if (r==d_reg)
						r=REGISTER_D0;
					
					as_id (0367,opcode2,instruction->instruction_parameters[0].parameter_offset,r);
				} else
					as_parameter (0367,0070,&instruction->instruction_parameters[0]);

				store_c (0x90+reg_num (d_reg)); /* xchg d_reg,D0 */
			} else {
				as_move_r_r (REGISTER_A1,tmp_reg);
				store_c (0x90+reg_num (d_reg));	/* xchg d_reg,D0 */
		
				if (unsigned_div)
					as_r_r (0063,REGISTER_A1,REGISTER_A1);	/* xor */
				else
					store_c (0231);							/* cdq */

				/* idivl */
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=d_reg;
					else if (r==REGISTER_A1)
						r=tmp_reg;
					else if (r==d_reg)
						r=REGISTER_D0;
					
					as_r (0367,opcode2,r);			
				} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=d_reg;
					else if (r==REGISTER_A1)
						r=tmp_reg;
					else if (r==d_reg)
						r=REGISTER_D0;
					
					as_id (0367,opcode2,instruction->instruction_parameters[0].parameter_offset,r);
				} else
					as_parameter (0367,0070,&instruction->instruction_parameters[0]);

				store_c (0x90+reg_num (d_reg)); /* xchg d_reg,D0 */
				as_move_r_r (tmp_reg,REGISTER_A1);
			}
	}
}
#endif

#ifndef THREAD32
static void as_rem_instruction (struct instruction *instruction,int unsigned_rem)
{
	int d_reg,opcode2;

	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE && unsigned_rem==0){
		int i,log2i;
		
		i=instruction->instruction_parameters[0].parameter_data.i;

		if (i<0 && i!=0x80000000)
			i=-i;
		
		if (! ((i & (i-1))==0 && i>1)){
			internal_error_in_function ("as_rem_instruction");
			return;
		}
				
		log2i=0;
		while (i>1){
			i=i>>1;
			++log2i;
		}

		as_move_r_r (d_reg,REGISTER_O0);

		if (log2i==1){
			/* and */
			if (d_reg==EAX)
				store_c (045);
			else
				as_r (0201,040,d_reg);
			store_l (1);

			as_sar_i_r (31,REGISTER_O0);

			as_r_r (0063,REGISTER_O0,d_reg); /* xor */
		} else {
			as_sar_i_r (31,REGISTER_O0);

			/* and */
			if (REGISTER_O0==EAX)
				store_c (045);
			else
				as_r (0201,040,REGISTER_O0);
			store_l ((1<<log2i)-1);

			as_r_r (0003,REGISTER_O0,d_reg); /* add */

			/* and */
			if (d_reg==EAX)
				store_c (045);
			else
				as_r (0201,040,d_reg);
			store_l ((1<<log2i)-1);
		}

		as_r_r (0053,REGISTER_O0,d_reg); /* sub */

		return;
	}

	opcode2=unsigned_rem ? 0060 : 0070;

	switch (d_reg){
		case REGISTER_D0:
			as_move_r_r (REGISTER_A1,REGISTER_O0);

			if (unsigned_rem)
				as_r_r (0063,REGISTER_A1,REGISTER_A1);	/* xor */
			else
				store_c (0231);							/* cdq */

			/* idivl */
			if (instruction->instruction_parameters[0].parameter_type==P_REGISTER
				&& instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A1)
			{
				as_r (0367,opcode2,REGISTER_O0);
			} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT
				&& instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A1)
			{
				as_id (0367,opcode2,instruction->instruction_parameters[0].parameter_offset,REGISTER_O0);
			} else
				as_parameter (0367,opcode2,&instruction->instruction_parameters[0]);

			as_move_r_r (REGISTER_A1,REGISTER_D0);
			as_move_r_r (REGISTER_O0,REGISTER_A1);
			break;		
		case REGISTER_A1:
			as_move_r_r (REGISTER_D0,REGISTER_O0);
			as_move_r_r (REGISTER_A1,REGISTER_D0);
	
			if (unsigned_rem)
				as_r_r (0063,REGISTER_A1,REGISTER_A1);	/* xor */
			else
				store_c (0231);							/* cdq */

			/* idivl */	
			if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
				int r;
				
				r=instruction->instruction_parameters[0].parameter_data.reg.r;
				if (r==REGISTER_D0)
					r=REGISTER_O0;
				else if (r==REGISTER_A1)
					r=REGISTER_D0;
				
				as_r (0367,opcode2,r);
			} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
				int r;
				
				r=instruction->instruction_parameters[0].parameter_data.reg.r;
				if (r==REGISTER_D0)
					r=REGISTER_O0;
				else if (r==REGISTER_A1)
					r=REGISTER_D0;
				
				as_id (0367,opcode2,instruction->instruction_parameters[0].parameter_offset,r);
			} else
				as_parameter (0367,opcode2,&instruction->instruction_parameters[0]);
		
			as_move_r_r (REGISTER_O0,REGISTER_D0);
			break;
		default:
			as_move_r_r (REGISTER_A1,REGISTER_O0);
			store_c (0x90+reg_num (d_reg)); /* xchg d_reg,D0 */
	
			if (unsigned_rem)
				as_r_r (0063,REGISTER_A1,REGISTER_A1);	/* xor */
			else
				store_c (0231);							/* cdq */
			/* idivl */
			if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
				int r;
				
				r=instruction->instruction_parameters[0].parameter_data.reg.r;
				if (r==REGISTER_D0)
					r=d_reg;
				else if (r==REGISTER_A1)
					r=REGISTER_O0;
				else if (r==d_reg)
					r=REGISTER_D0;
				
				as_r (0367,opcode2,r);
			} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
				int r;
				
				r=instruction->instruction_parameters[0].parameter_data.reg.r;
				if (r==REGISTER_D0)
					r=d_reg;
				else if (r==REGISTER_A1)
					r=REGISTER_O0;
				else if (r==d_reg)
					r=REGISTER_D0;
				
				as_id (0367,opcode2,instruction->instruction_parameters[0].parameter_offset,r);				
			} else
				as_parameter (0367,opcode2,&instruction->instruction_parameters[0]);

			as_move_r_r (d_reg,REGISTER_D0);
			as_move_r_r (REGISTER_A1,d_reg);
			as_move_r_r (REGISTER_O0,REGISTER_A1);
	}
}
#else
static void as_rem_instruction (struct instruction *instruction,int unsigned_rem)
{
	int d_reg,tmp_reg,opcode2;

	d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;
	tmp_reg=instruction->instruction_parameters[2].parameter_data.reg.r;

	if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE && unsigned_rem==0){
		int i,log2i;
		
		i=instruction->instruction_parameters[0].parameter_data.i;

		if (i<0 && i!=0x80000000)
			i=-i;
		
		if (! ((i & (i-1))==0 && i>1)){
			internal_error_in_function ("as_rem_instruction");
			return;
		}
				
		log2i=0;
		while (i>1){
			i=i>>1;
			++log2i;
		}

		as_move_r_r (d_reg,tmp_reg);

		if (log2i==1){
			/* and */
			if (d_reg==EAX)
				store_c (045);
			else
				as_r (0201,040,d_reg);
			store_l (1);

			as_sar_i_r (31,tmp_reg);

			as_r_r (0063,tmp_reg,d_reg); /* xor */
		} else {
			as_sar_i_r (31,tmp_reg);

			/* and */
			if (tmp_reg==EAX)
				store_c (045);
			else
				as_r (0201,040,tmp_reg);
			store_l ((1<<log2i)-1);

			as_r_r (0003,tmp_reg,d_reg); /* add */

			/* and */
			if (d_reg==EAX)
				store_c (045);
			else
				as_r (0201,040,d_reg);
			store_l ((1<<log2i)-1);
		}

		as_r_r (0053,tmp_reg,d_reg); /* sub */

		return;
	}

	opcode2=unsigned_rem ? 0060 : 0070;

	switch (d_reg){
		case REGISTER_D0:
			if (tmp_reg==REGISTER_A1){
				if (unsigned_rem)
					as_r_r (0063,REGISTER_A1,REGISTER_A1);	/* xor */
				else
					store_c (0231);							/* cdq */

				/* idivl */
				as_parameter (0367,opcode2,&instruction->instruction_parameters[0]);

				as_move_r_r (REGISTER_A1,REGISTER_D0);
			} else {
				as_move_r_r (REGISTER_A1,tmp_reg);

				if (unsigned_rem)
					as_r_r (0063,REGISTER_A1,REGISTER_A1);	/* xor */
				else
					store_c (0231);							/* cdq */

				/* idivl */
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER
					&& instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A1)
				{
					as_r (0367,opcode2,tmp_reg);
				} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT
					&& instruction->instruction_parameters[0].parameter_data.reg.r==REGISTER_A1)
				{
					as_id (0367,opcode2,instruction->instruction_parameters[0].parameter_offset,tmp_reg);
				} else
					as_parameter (0367,opcode2,&instruction->instruction_parameters[0]);

				as_move_r_r (REGISTER_A1,REGISTER_D0);
				as_move_r_r (tmp_reg,REGISTER_A1);
			}
			break;		
		case REGISTER_A1:
			if (tmp_reg==REGISTER_D0){
				as_move_r_r (REGISTER_A1,REGISTER_D0);
		
				if (unsigned_rem)
					as_r_r (0063,REGISTER_A1,REGISTER_A1);	/* xor */
				else
					store_c (0231);							/* cdq */

				/* idivl */	
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_A1)
						r=REGISTER_D0;
					
					as_r (0367,opcode2,r);
				} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_A1)
						r=REGISTER_D0;
					
					as_id (0367,opcode2,instruction->instruction_parameters[0].parameter_offset,r);
				} else
					as_parameter (0367,opcode2,&instruction->instruction_parameters[0]);
			} else {
				as_move_r_r (REGISTER_D0,tmp_reg);
				as_move_r_r (REGISTER_A1,REGISTER_D0);
		
				if (unsigned_rem)
					as_r_r (0063,REGISTER_A1,REGISTER_A1);	/* xor */
				else
					store_c (0231);							/* cdq */

				/* idivl */	
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=tmp_reg;
					else if (r==REGISTER_A1)
						r=REGISTER_D0;
					
					as_r (0367,opcode2,r);
				} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=tmp_reg;
					else if (r==REGISTER_A1)
						r=REGISTER_D0;
					
					as_id (0367,opcode2,instruction->instruction_parameters[0].parameter_offset,r);
				} else
					as_parameter (0367,opcode2,&instruction->instruction_parameters[0]);
			
				as_move_r_r (tmp_reg,REGISTER_D0);
			}
			break;
		default:
			if (tmp_reg==REGISTER_D0){
				as_move_r_r (d_reg,REGISTER_D0);
				as_move_r_r (REGISTER_A1,d_reg);

				if (unsigned_rem)
					as_r_r (0063,REGISTER_A1,REGISTER_A1);	/* xor */
				else
					store_c (0231);							/* cdq */
				/* idivl */
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_A1)
						r=d_reg;
					else if (r==d_reg)
						r=REGISTER_D0;
					
					as_r (0367,opcode2,r);
				} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_A1)
						r=d_reg;
					else if (r==d_reg)
						r=REGISTER_D0;
					
					as_id (0367,opcode2,instruction->instruction_parameters[0].parameter_offset,r);				
				} else
					as_parameter (0367,opcode2,&instruction->instruction_parameters[0]);
				
				as_r_r (0207,d_reg,REGISTER_A1);	/* xchg */
			} else if (tmp_reg==REGISTER_A1){
				store_c (0x90+reg_num (d_reg)); /* xchg d_reg,D0 */
		
				if (unsigned_rem)
					as_r_r (0063,REGISTER_A1,REGISTER_A1);	/* xor */
				else
					store_c (0231);							/* cdq */
				/* idivl */
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=d_reg;
					else if (r==d_reg)
						r=REGISTER_D0;
					
					as_r (0367,opcode2,r);
				} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=d_reg;
					else if (r==d_reg)
						r=REGISTER_D0;
					
					as_id (0367,opcode2,instruction->instruction_parameters[0].parameter_offset,r);				
				} else
					as_parameter (0367,opcode2,&instruction->instruction_parameters[0]);

				as_move_r_r (d_reg,REGISTER_D0);
				as_move_r_r (REGISTER_A1,d_reg);
			} else {
				as_move_r_r (REGISTER_A1,tmp_reg);
				store_c (0x90+reg_num (d_reg)); /* xchg d_reg,D0 */
		
				if (unsigned_rem)
					as_r_r (0063,REGISTER_A1,REGISTER_A1);	/* xor */
				else
					store_c (0231);							/* cdq */
				/* idivl */
				if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=d_reg;
					else if (r==REGISTER_A1)
						r=tmp_reg;
					else if (r==d_reg)
						r=REGISTER_D0;
					
					as_r (0367,opcode2,r);
				} else if (instruction->instruction_parameters[0].parameter_type==P_INDIRECT){
					int r;
					
					r=instruction->instruction_parameters[0].parameter_data.reg.r;
					if (r==REGISTER_D0)
						r=d_reg;
					else if (r==REGISTER_A1)
						r=tmp_reg;
					else if (r==d_reg)
						r=REGISTER_D0;
					
					as_id (0367,opcode2,instruction->instruction_parameters[0].parameter_offset,r);				
				} else
					as_parameter (0367,opcode2,&instruction->instruction_parameters[0]);

				as_move_r_r (d_reg,REGISTER_D0);
				as_move_r_r (REGISTER_A1,d_reg);
				as_move_r_r (tmp_reg,REGISTER_A1);
			}
	}
}
#endif

static void as_2move_registers (int reg1,int reg2,int reg3)
{
	as_move_r_r (reg2,reg3);
	as_move_r_r (reg1,reg2);
}

static void as_3move_registers (int reg1,int reg2,int reg3,int reg4)
{
	as_move_r_r (reg3,reg4);
	as_move_r_r (reg2,reg3);
	as_move_r_r (reg1,reg2);
}

static void as_mulud_instruction (struct instruction *instruction)
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
			as_move_r_r (reg_2,REGISTER_D0);
			as_r (0367,040,reg_1); /* mul */
			as_move_r_r (REGISTER_D0,reg_2);
		} else if (reg_2==REGISTER_A1){
			as_move_r_r (reg_2,REGISTER_D0);
			as_r (0367,040,reg_1); /* mul */
			as_2move_registers (REGISTER_D0,REGISTER_A1,reg_1);
		} else {
			as_2move_registers (REGISTER_A1,reg_2,REGISTER_D0);
			as_r (0367,040,reg_1); /* mul */
			as_3move_registers (REGISTER_D0,reg_2,REGISTER_A1,reg_1);
		}
		return;
	}

	if (reg_3==REGISTER_A1){
		if (reg_2==REGISTER_D0){
			as_r (0367,040,reg_1); /* mul */
			as_move_r_r (REGISTER_A1,reg_1);
		} else if (reg_1==REGISTER_D0){
			as_r (0367,040,reg_2); /* mul */
			as_2move_registers (REGISTER_A1,REGISTER_D0,reg_2);
		} else {
			store_c (0x90+reg_num (reg_2)); /* xchg reg_2,D0 */
			as_r (0367,040,reg_1); /* mul */
			store_c (0x90+reg_num (reg_2)); /* xchg reg_2,D0 */
			as_move_r_r (REGISTER_A1,reg_1);
		}
		return;
	}

	if (reg_2==REGISTER_D0){
		if (reg_1==REGISTER_A1)
			as_r (0367,040,reg_1); /* mul */
		else {
			as_move_r_r (REGISTER_A1,reg_3);
			as_r (0367,040,reg_1); /* mul */
			as_2move_registers (reg_3,REGISTER_A1,reg_1);
		}
	} else if (reg_1==REGISTER_A1){
		as_2move_registers (reg_2,REGISTER_D0,reg_3);
		as_r (0367,040,reg_1); /* mul */
		as_2move_registers (reg_3,REGISTER_D0,reg_2);
	} else if (reg_1==REGISTER_D0){
		if (reg_2==REGISTER_A1){
			as_r (0367,040,REGISTER_A1); /* mul */
			store_c (0x90+reg_num (REGISTER_A1)); /* xchg A1,D0 */
		} else {
			as_move_r_r (REGISTER_A1,reg_3);
			as_r (0367,040,reg_2); /* mul */
			as_3move_registers (reg_3,REGISTER_A1,REGISTER_D0,reg_2);
		}
	} else if (reg_2==REGISTER_A1){
		as_2move_registers (reg_2,REGISTER_D0,reg_3);
		as_r (0367,040,reg_1); /* mul */
		as_3move_registers (reg_3,REGISTER_D0,REGISTER_A1,reg_1);
	} else {
		store_c (0x90+reg_num (reg_2)); /* xchg reg_2,D0 */
		as_move_r_r (REGISTER_A1,reg_3);
		as_r (0367,040,reg_1); /* mul */
		store_c (0x90+reg_num (reg_2)); /* xchg reg_2,D0 */
		as_2move_registers (reg_3,REGISTER_A1,reg_1);
	}
#else
	if (reg_2==REGISTER_D0){
		if (reg_1==REGISTER_A1)
			as_r (0367,040,reg_1); /* mul */
		else {
			as_move_r_r (REGISTER_A1,REGISTER_O0);
			as_r (0367,040,reg_1); /* mul */
			as_2move_registers (REGISTER_O0,REGISTER_A1,reg_1);
		}
	} else if (reg_1==REGISTER_A1){
		as_2move_registers (reg_2,REGISTER_D0,REGISTER_O0);
		as_r (0367,040,reg_1); /* mul */
		as_2move_registers (REGISTER_O0,REGISTER_D0,reg_2);
	} else if (reg_1==REGISTER_D0){
		if (reg_2==REGISTER_A1){
			as_r (0367,040,REGISTER_A1); /* mul */
			store_c (0x90+reg_num (REGISTER_A1)); /* xchg A1,D0 */
		} else {
			as_move_r_r (REGISTER_A1,REGISTER_O0);
			as_r (0367,040,reg_2); /* mul */
			as_3move_registers (REGISTER_O0,REGISTER_A1,REGISTER_D0,reg_2);
		}
	} else if (reg_2==REGISTER_A1){
		as_2move_registers (reg_2,REGISTER_D0,REGISTER_O0);
		as_r (0367,040,reg_1); /* mul */
		as_3move_registers (REGISTER_O0,REGISTER_D0,REGISTER_A1,reg_1);
	} else {
		store_c (0x90+reg_num (reg_2)); /* xchg reg_2,D0 */
		as_move_r_r (REGISTER_A1,REGISTER_O0);
		as_r (0367,040,reg_1); /* mul */
		store_c (0x90+reg_num (reg_2)); /* xchg reg_2,D0 */
		as_2move_registers (REGISTER_O0,REGISTER_A1,reg_1);
	}
#endif
}

static void as_xchg_eax_r (int reg_1)
{
	store_c (0x90+reg_num (reg_1)); /* xchg reg_1,D0 */
}

static void as_xchg (int r1,int r2)
{
	if (r1==REGISTER_D0)
		store_c (0x90+reg_num (r2)); /* xchg r,D0 */
	else if (r2==REGISTER_D0)
		store_c (0x90+reg_num (r1)); /* xchg r,D0 */
	else
		as_r_r (0207,r1,r2);
}

static void as_divdu_instruction (struct instruction *instruction)
{
	int reg_1,reg_2,reg_3;

	reg_1=instruction->instruction_parameters[0].parameter_data.reg.r;
	reg_2=instruction->instruction_parameters[1].parameter_data.reg.r;
	reg_3=instruction->instruction_parameters[2].parameter_data.reg.r;

	/* reg_2:reg_3/reg_1, quotient in reg3, remainder in reg_2 */

#ifdef THREAD32
	if (reg_3==REGISTER_D0){
		if (reg_2==REGISTER_A1)
			as_r (0367,0060,reg_1); /* div */
		else {
			as_xchg (REGISTER_A1,reg_2);
			if (reg_1==reg_2)
				as_r (0367,0060,REGISTER_A1); /* div */
			else if (reg_1==REGISTER_A1)
				as_r (0367,0060,reg_2); /* div */
			else
				as_r (0367,0060,reg_1); /* div */
			as_xchg (REGISTER_A1,reg_2);
		}
	} else if (reg_3==REGISTER_A1){
		as_xchg (REGISTER_D0,REGISTER_A1);
		if (reg_2==REGISTER_D0){
			if (reg_1==REGISTER_D0)
				as_r (0367,0060,REGISTER_A1); /* div */			
			else if (reg_1==REGISTER_A1)
				as_r (0367,0060,REGISTER_D0); /* div */
			else
				as_r (0367,0060,reg_1); /* div */
		} else {
			as_xchg (REGISTER_A1,reg_2);
			if (reg_1==reg_2)
				as_r (0367,0060,REGISTER_A1); /* div */
			else if (reg_1==REGISTER_D0)
				as_r (0367,0060,reg_2); /* div */
			else if (reg_1==REGISTER_A1)
				as_r (0367,0060,REGISTER_D0); /* div */
			else
				as_r (0367,0060,reg_1); /* div */
			as_xchg (REGISTER_A1,reg_2);
		}
		as_xchg (REGISTER_D0,REGISTER_A1);
	} else {
		if (reg_2==REGISTER_A1){
			as_xchg (REGISTER_D0,reg_3);
			if (reg_1==reg_3)
				as_r (0367,0060,REGISTER_D0); /* div */
			else if (reg_1==REGISTER_D0)
				as_r (0367,0060,reg_3); /* div */
			else
				as_r (0367,0060,reg_1); /* div */
			as_xchg (REGISTER_D0,reg_3);
		} else if (reg_2==REGISTER_D0){
			as_xchg (REGISTER_A1,REGISTER_D0);
			as_xchg (REGISTER_D0,reg_3);
			if (reg_1==reg_3)
				as_r (0367,0060,REGISTER_D0); /* div */
			else if (reg_1==REGISTER_D0)
				as_r (0367,0060,REGISTER_A1); /* div */
			else if (reg_1==REGISTER_A1)
				as_r (0367,0060,reg_3); /* div */
			else
				as_r (0367,0060,reg_1); /* div */
			as_xchg (REGISTER_D0,reg_3);
			as_xchg (REGISTER_A1,REGISTER_D0);
		} else {
			as_xchg (REGISTER_D0,reg_3);
			as_xchg (REGISTER_A1,reg_2);
			if (reg_1==REGISTER_D0)
				as_r (0367,0060,reg_3); /* div */
			else if (reg_1==REGISTER_A1)
				as_r (0367,0060,reg_2); /* div */
			else if (reg_1==reg_3)
				as_r (0367,0060,REGISTER_D0); /* div */
			else if (reg_1==reg_2)
				as_r (0367,0060,REGISTER_A1); /* div */
			else
				as_r (0367,0060,reg_1); /* div */					
			as_xchg (REGISTER_A1,reg_2);
			as_xchg (REGISTER_D0,reg_3);
		}
	}
#else
	if (reg_1==REGISTER_D0){
		if (reg_3==REGISTER_D0){
			if (reg_2==REGISTER_A1)
				as_r (0367,0060,reg_1); /* div */
			else {
				as_2move_registers (reg_2,REGISTER_A1,REGISTER_O0);
				as_r (0367,0060,reg_1); /* div */
				as_2move_registers (REGISTER_O0,REGISTER_A1,reg_2);
			}
		} else if (reg_3==REGISTER_A1){
			if (reg_2==REGISTER_D0){
				as_xchg_eax_r (REGISTER_A1);  /* xchg A1,D0 */
				as_r (0367,0060,REGISTER_A1); /* div */
				as_xchg_eax_r (REGISTER_A1);  /* xchg A1,D0 */
			} else {
				as_3move_registers (reg_2,REGISTER_A1,REGISTER_D0,REGISTER_O0);
				as_r (0367,0060,REGISTER_O0); /* div */
				as_3move_registers (REGISTER_O0,REGISTER_D0,REGISTER_A1,reg_2);
			}
		} else {
			if (reg_2==REGISTER_A1){
				as_2move_registers (reg_3,REGISTER_D0,REGISTER_O0);
				as_r (0367,0060,REGISTER_O0); /* div */
				as_2move_registers (REGISTER_O0,REGISTER_D0,reg_3);
			} else if (reg_2==REGISTER_D0){
				as_3move_registers (reg_3,REGISTER_D0,REGISTER_A1,REGISTER_O0);
				as_r (0367,0060,REGISTER_A1); /* div */
				as_3move_registers (REGISTER_O0,REGISTER_A1,REGISTER_D0,reg_3);
			} else {
				as_xchg_eax_r (reg_3); /* xchg reg_3,D0 */
				as_2move_registers (reg_2,REGISTER_A1,REGISTER_O0);
				as_r (0367,0060,reg_3); /* div */
				as_2move_registers (REGISTER_O0,REGISTER_A1,reg_2);
				as_xchg_eax_r (reg_3); /* xchg reg_3,D0 */
			}
		}
	} else if (reg_1==REGISTER_A1){
		if (reg_2==REGISTER_A1){
			if (reg_3==REGISTER_D0)
				as_r (0367,0060,reg_1); /* div */
			else {
				as_2move_registers (reg_3,REGISTER_D0,REGISTER_O0);
				as_r (0367,0060,reg_1); /* div */
				as_2move_registers (REGISTER_O0,REGISTER_D0,reg_3);
			}
		} else if (reg_2==REGISTER_D0){
			if (reg_3==REGISTER_A1){
				as_xchg_eax_r (REGISTER_A1);  /* xchg A1,D0 */
				as_r (0367,0060,REGISTER_D0); /* div */
				as_xchg_eax_r (REGISTER_A1);  /* xchg A1,D0 */
			} else {
				as_3move_registers (reg_3,REGISTER_D0,REGISTER_A1,REGISTER_O0);
				as_r (0367,0060,REGISTER_O0); /* div */
				as_3move_registers (REGISTER_O0,REGISTER_A1,REGISTER_D0,reg_3);
			}
		} else {
			if (reg_3==REGISTER_D0){
				as_2move_registers (reg_2,REGISTER_A1,REGISTER_O0);
				as_r (0367,0060,REGISTER_O0); /* div */
				as_2move_registers (REGISTER_O0,REGISTER_A1,reg_2);
			} else if (reg_3==REGISTER_A1){
				as_3move_registers (reg_2,REGISTER_A1,REGISTER_D0,REGISTER_O0);
				as_r (0367,0060,REGISTER_D0); /* div */
				as_3move_registers (REGISTER_O0,REGISTER_D0,REGISTER_A1,reg_2);
			} else {
				as_r_r (0207,reg_2,REGISTER_A1); /* xchg */
				as_2move_registers (reg_3,REGISTER_D0,REGISTER_O0);
				as_r (0367,0060,reg_2); /* div */
				as_2move_registers (REGISTER_O0,REGISTER_D0,reg_3);
				as_r_r (0207,reg_2,REGISTER_A1); /* xchg */
			}
		}
	} else {
		if (reg_3==REGISTER_D0){
			if (reg_2==REGISTER_A1){
				as_r (0367,0060,reg_1); /* div */
			} else {
				as_2move_registers (reg_2,REGISTER_A1,REGISTER_O0);
				as_r (0367,0060,reg_1); /* div */
				as_2move_registers (REGISTER_O0,REGISTER_A1,reg_2);
			}
		} else if (reg_2==REGISTER_A1){
			as_2move_registers (reg_3,REGISTER_D0,REGISTER_O0);
			as_r (0367,0060,reg_1); /* div */
			as_2move_registers (REGISTER_O0,REGISTER_D0,reg_3);
		} else if (reg_2==REGISTER_D0){
			if (reg_3==REGISTER_A1){
				as_xchg_eax_r (REGISTER_A1); /* xchg A1,D0 */
				as_r (0367,0060,reg_1);      /* div */
				as_xchg_eax_r (REGISTER_A1); /* xchg A1,D0 */
			} else {
				as_3move_registers (reg_3,REGISTER_D0,REGISTER_A1,REGISTER_O0);
				as_r (0367,0060,reg_1); /* div */
				as_3move_registers (REGISTER_O0,REGISTER_A1,REGISTER_D0,reg_3);
			}
		} else if (reg_3==REGISTER_A1){
			as_3move_registers (reg_2,REGISTER_A1,REGISTER_D0,REGISTER_O0);
			as_r (0367,0060,reg_1); /* div */
			as_3move_registers (REGISTER_O0,REGISTER_D0,REGISTER_A1,reg_2);
		} else {
			as_xchg_eax_r (reg_3); /* xchg reg_3,D0 */
			as_2move_registers (reg_2,REGISTER_A1,REGISTER_O0);
			as_r (0367,0060,reg_1); /* div */
			as_2move_registers (REGISTER_O0,REGISTER_A1,reg_2);
			as_xchg_eax_r (reg_3); /* xchg reg_3,D0 */
		}
	}
#endif
}

static void as_mul_shift_magic (int s)
{
	as_r (0367,0040,REGISTER_A1); /* mul */

	if (s>0)
		as_shr_i_r (s,REGISTER_A1);
}

static void as_floordiv_ni (int reg_1,int reg_2,int reg_3,int i)
{
	struct ms ms;

	ms=magic (i);

	if (reg_2==REGISTER_D0){
		if (reg_1==REGISTER_A1){
			reg_3=reg_1;
			reg_3=REGISTER_A1;
		}
		as_move_r_r (REGISTER_D0,reg_1);

		as_i_r2 (0201,0050,0055,1,REGISTER_D0); /* sub */

		as_r_r (0013,REGISTER_D0,reg_1); /* or */

		if (reg_3!=REGISTER_A1)
			as_move_r_r (REGISTER_A1,reg_3);

		as_sar_i_r (31,reg_1);
		as_move_i_r (ms.m,REGISTER_A1);

		as_r_r (0063,reg_1,REGISTER_D0); /* xor */

		as_mul_shift_magic (ms.s);

		as_r (0367,0020,reg_1);			 /* not */

		as_move_r_r (reg_1,REGISTER_D0);
		as_r_r (0063,REGISTER_A1,REGISTER_D0); /* xor */

		if (reg_3!=REGISTER_A1)
			as_move_r_r (reg_3,REGISTER_A1);
	} else if (reg_2==REGISTER_A1){
		if (reg_3==REGISTER_D0){
			reg_3=reg_1;
			reg_1=REGISTER_D0;
		}
		as_move_r_r (REGISTER_A1,reg_3);

		as_i_r2 (0201,0050,0055,1,REGISTER_A1); /* sub */

		as_r_r (0013,REGISTER_A1,reg_3); /* or */

		if (reg_1!=REGISTER_D0)
			as_move_r_r (REGISTER_D0,reg_1);

		as_sar_i_r (31,reg_3);
		as_move_i_r (ms.m,REGISTER_D0);

		as_r_r (0063,reg_3,REGISTER_A1); /* xor */
	
		as_mul_shift_magic (ms.s);

		as_r (0367,0020,reg_3);			 /* not */
		if (reg_1!=REGISTER_D0)
			as_move_r_r (reg_1,REGISTER_D0);

		as_r_r (0063,reg_3,REGISTER_A1); /* xor */
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
			as_move_i_r (-1,REGISTER_D0);
		
			as_r_r (0003,reg_2,REGISTER_D0); /* add */

			as_r_r (0013,REGISTER_D0,reg_2); /* or */

			if (reg_3!=REGISTER_A1)
				as_move_r_r (REGISTER_A1,reg_3);

			as_sar_i_r (31,reg_2);

			as_move_i_r (ms.m,REGISTER_A1);

			as_r_r (0063,reg_2,REGISTER_D0); /* xor */

			as_mul_shift_magic (ms.s);
			as_r (0367,0020,reg_2); 		 /* not */
			as_r_r (0063,REGISTER_A1,reg_2); /* xor */

			if (reg_3!=REGISTER_A1)
				as_move_r_r (reg_3,REGISTER_A1);
		} else if (reg_3==REGISTER_A1){
			as_move_i_r (-1,REGISTER_A1);

			as_r_r (0003,reg_2,REGISTER_A1); /* add */

			as_r_r (0013,REGISTER_A1,reg_2); /* or */

			as_move_r_r (REGISTER_D0,reg_1);

			as_sar_i_r (31,reg_2);

			as_move_i_r (ms.m,REGISTER_D0);

			as_r_r (0063,reg_2,REGISTER_A1); /* xor */

			as_mul_shift_magic (ms.s);
			as_r (0367,0020,reg_2);			 /* not */

			as_move_r_r (reg_1,REGISTER_D0);

			as_r_r (0063,REGISTER_A1,reg_2); /* xor */
		} else {
			as_move_r_r (REGISTER_D0,reg_1);
			as_move_i_r (-1,REGISTER_D0);

			as_r_r (0003,reg_2,REGISTER_D0); /* add */

			as_r_r (0013,REGISTER_D0,reg_2); /* or */

			as_sar_i_r (31,reg_2);

			as_move_r_r (REGISTER_A1,reg_3);

			as_move_i_r (ms.m,REGISTER_A1);

			as_r_r (0063,reg_2,REGISTER_D0); /* xor */

			as_mul_shift_magic (ms.s);
			as_r (0367,0020,reg_2);			 /* not */

			as_move_r_r (reg_1,REGISTER_D0);

			as_r_r (0063,REGISTER_A1,reg_2); /* xor */

			as_move_r_r (reg_3,REGISTER_A1);
		}
	}
}

static void as_floordiv_i (int reg_1,int reg_2,int reg_3,int i)
{
	struct ms ms;

	if (i<0){
		as_floordiv_ni (reg_1,reg_2,reg_3,-i);
		return;
	}

	ms=magic (i);

	if (reg_2==REGISTER_D0){
		if (reg_1==REGISTER_A1){
			reg_3=reg_1;
			reg_3=REGISTER_A1;
		}
		as_move_r_r (REGISTER_D0,reg_1);
		if (reg_3!=REGISTER_A1)
			as_move_r_r (REGISTER_A1,reg_3);

		as_sar_i_r (31,reg_1);
		as_move_i_r (ms.m,REGISTER_A1);

		as_r_r (0063,reg_1,REGISTER_D0); /* xor */

		as_mul_shift_magic (ms.s);

		as_move_r_r (reg_1,REGISTER_D0);
		as_r_r (0063,REGISTER_A1,REGISTER_D0); /* xor */

		if (reg_3!=REGISTER_A1)
			as_move_r_r (reg_3,REGISTER_A1);
	} else if (reg_2==REGISTER_A1){
		if (reg_3==REGISTER_D0){
			reg_3=reg_1;
			reg_1=REGISTER_D0;
		}
		as_move_r_r (REGISTER_A1,reg_3);
		if (reg_1!=REGISTER_D0)
			as_move_r_r (REGISTER_D0,reg_1);

		as_sar_i_r (31,reg_3);
		as_move_i_r (ms.m,REGISTER_D0);

		as_r_r (0063,reg_3,REGISTER_A1); /* xor */

		as_mul_shift_magic (ms.s);

		if (reg_1!=REGISTER_D0)
			as_move_r_r (reg_1,REGISTER_D0);

		as_r_r (0063,reg_3,REGISTER_A1); /* xor */
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
			as_move_r_r (reg_2,REGISTER_D0);
			as_sar_i_r (31,reg_2);

			if (reg_3!=REGISTER_A1)
				as_move_r_r (REGISTER_A1,reg_3);

			as_r_r (0063,reg_2,REGISTER_D0); /* xor */

			as_move_i_r (ms.m,REGISTER_A1);
			as_mul_shift_magic (ms.s);
			as_r_r (0063,REGISTER_A1,reg_2); /* xor */

			if (reg_3!=REGISTER_A1)
				as_move_r_r (reg_3,REGISTER_A1);
		} else if (reg_3==REGISTER_A1){
			as_move_r_r (reg_2,REGISTER_A1);
			as_sar_i_r (31,reg_2);

			as_move_r_r (REGISTER_D0,reg_1);

			as_r_r (0063,reg_2,REGISTER_A1); /* xor */

			as_move_i_r (ms.m,REGISTER_D0);
			as_mul_shift_magic (ms.s);

			as_move_r_r (reg_1,REGISTER_D0);

			as_r_r (0063,REGISTER_A1,reg_2); /* xor */
		} else {
			as_move_r_r (REGISTER_D0,reg_1);
			as_move_r_r (reg_2,REGISTER_D0);
			as_sar_i_r (31,reg_2);

			as_r_r (0063,reg_2,REGISTER_D0); /* xor */

			as_move_r_r (REGISTER_A1,reg_3);

			as_move_i_r (ms.m,REGISTER_A1);
			as_mul_shift_magic (ms.s);

			as_move_r_r (reg_1,REGISTER_D0);

			as_r_r (0063,REGISTER_A1,reg_2); /* xor */

			as_move_r_r (reg_3,REGISTER_A1);
		}
	}
}

static void as_floordiv_mod (int reg_1,int compute_mod)
{
	/* reg_1 not EAX or EDX */
	store_c (0231); 		/* cdq */
	as_r (0367,0070,reg_1);	/* idiv */

	if (!compute_mod){
		as_sar_i_r (31,reg_1);
		as_r_r (0003,reg_1,REGISTER_A1);		/* add */
		as_r_r (0063,reg_1,REGISTER_A1);		/* xor */
		as_sar_i_r (31,REGISTER_A1);
		as_r_r (0003,REGISTER_A1,REGISTER_D0);	/* add */
	} else {
		as_move_r_r (reg_1,REGISTER_D0);
		as_sar_i_r (31,reg_1);
		as_r_r (0003,REGISTER_A1,reg_1);		/* add */
		as_r_r (0063,REGISTER_D0,reg_1);		/* xor */
		as_sar_i_r (31,reg_1);
		as_r_r (0043,reg_1,REGISTER_D0);		/* and */
		as_r_r (0003,REGISTER_A1,REGISTER_D0);	/* add */
	}
}

static void as_floordiv_mod_instruction (struct instruction *instruction,int compute_mod)
{
	int reg_1,reg_2,reg_3;
	
	reg_1=instruction->instruction_parameters[0].parameter_data.reg.r;
	reg_2=instruction->instruction_parameters[1].parameter_data.reg.r;
	reg_3=instruction->instruction_parameters[2].parameter_data.reg.r;

	if (instruction->instruction_arity==4){
		as_floordiv_i (reg_1,reg_2,reg_3,instruction->instruction_parameters[3].parameter_data.imm);
		return;
	}

	/* reg_2 = floor (reg_2/reg_1) or mod reg_2 reg_1 */

	if (reg_2==REGISTER_D0){
		if (reg_3==REGISTER_A1){
			as_floordiv_mod (reg_1,compute_mod);
		} else if (reg_1==REGISTER_A1){
			as_move_r_r (reg_1,reg_3);
			as_floordiv_mod (reg_3,compute_mod);
		} else {
			as_move_r_r (REGISTER_A1,reg_3);
			as_floordiv_mod (reg_1,compute_mod);
			as_move_r_r (reg_3,REGISTER_A1);
		}
	} else if (reg_2==REGISTER_A1){
		if (reg_3==REGISTER_D0){
			as_move_r_r (reg_2/*A1*/,reg_3/*D0*/);
			as_floordiv_mod (reg_1,compute_mod);
			as_move_r_r (REGISTER_D0,reg_2/*A1*/);
		} else if (reg_1==REGISTER_D0){
			as_2move_registers (reg_2/*A1*/,reg_1/*D0*/,reg_3);
			as_floordiv_mod (reg_3,compute_mod);
			as_move_r_r (REGISTER_D0,reg_2/*A1*/);
		} else {
			as_2move_registers (reg_2/*A1*/,REGISTER_D0,reg_3);
			as_floordiv_mod (reg_1,compute_mod);
			as_move_r_r (reg_3,reg_1);
			as_2move_registers (reg_1,REGISTER_D0,reg_2/*A1*/);
		}
	} else {
		if (reg_3==REGISTER_D0){
			if (reg_1==REGISTER_A1){
				as_2move_registers (reg_1/*A1*/,reg_2,reg_3/*D0*/);
				as_floordiv_mod (reg_2,compute_mod);
				as_move_r_r (reg_3/*D0*/,reg_2);
			} else {
				as_2move_registers (REGISTER_A1,reg_2,reg_3/*D0*/);
				as_floordiv_mod (reg_1,compute_mod);
				as_2move_registers (reg_3/*D0*/,reg_2,REGISTER_A1);
			}
		} else if (reg_3==REGISTER_A1){
			if (reg_1==REGISTER_D0){
				as_xchg_eax_r (reg_2);				
				as_floordiv_mod (reg_2,compute_mod);
				as_move_r_r (REGISTER_D0,reg_2);
			} else {
				as_xchg_eax_r (reg_2);				
				as_floordiv_mod (reg_1,compute_mod);
				as_xchg_eax_r (reg_2);				
			}
		} else {
			if (reg_1==REGISTER_D0){
				as_3move_registers (REGISTER_A1,reg_2,reg_1/*D0*/,reg_3);
				as_floordiv_mod (reg_3,compute_mod);
				as_2move_registers (REGISTER_D0,reg_2,REGISTER_A1);
			} else if (reg_1==REGISTER_A1){
				as_xchg_eax_r (reg_2);				
				as_move_r_r (reg_1/*A1*/,reg_3);
				as_floordiv_mod (reg_3,compute_mod);
				as_xchg_eax_r (reg_2);				
			} else {
				as_xchg_eax_r (reg_2);				
				as_move_r_r (REGISTER_A1,reg_3);
				as_floordiv_mod (reg_1,compute_mod);
				as_move_r_r (reg_3,REGISTER_A1);
				as_xchg_eax_r (reg_2);				
			}
		}
	}
}

static void as_set_condition_instruction (struct instruction *instruction,int condition_code)
{
	int r;
	unsigned int rn;
	
	r=instruction->instruction_parameters[0].parameter_data.reg.r;
	rn=reg_num (r);

	if (rn<4u){
		store_c (0017);
		store_c (0220 | condition_code);
		store_c (0300 | rn);

		/* movzbl */
		store_c (017);
		store_c (0266);
		store_c (0300 | (rn<<3) | rn);
	} else {
		as_move_r_r (REGISTER_D0,r);

		store_c (0017);
		store_c (0220 | condition_code);
		store_c (0300 | 0); /* %al */

		/* movzbl */
		store_c (017);
		store_c (0266);
		store_c (0300 | (reg_num (REGISTER_D0)<<3) | 0 /* %al */);

		store_c (0x90+rn); /* xchg r,D0 */
	}
}

static void as_tst_instruction (struct instruction *instruction)
{
	struct parameter parameter_0,parameter_1;

	parameter_0=instruction->instruction_parameters[0];
	parameter_1=instruction->instruction_parameters[1];

	if (parameter_0.parameter_type==P_IMMEDIATE){
		int i;

		i=parameter_0.parameter_data.i;
		switch (parameter_1.parameter_type){
			case P_REGISTER:
				if (parameter_1.parameter_data.reg.r==EAX)
					store_c (0xA9);
				else {
					store_c (0xF7);
					store_c (0300 | reg_num (parameter_1.parameter_data.reg.r));
				}
				store_l (i);
				return;
			case P_INDIRECT:
				as_i_id (0xF7,0,i,parameter_1.parameter_offset,parameter_1.parameter_data.reg.r);
				return;
			case P_INDEXED:
				as_i_x (0xF7,0,i,parameter_1.parameter_offset,parameter_1.parameter_data.ir);
				return;
		}
	} else if (parameter_1.parameter_type==P_REGISTER){
		switch (parameter_0.parameter_type){
			case P_REGISTER:
				as_r_r (0x85,parameter_0.parameter_data.reg.r,parameter_1.parameter_data.reg.r);
				return;
			case P_INDIRECT:
				as_id_r (0x85,parameter_0.parameter_offset,parameter_0.parameter_data.reg.r,parameter_1.parameter_data.reg.r);
				return;
			case P_INDEXED:
				as_x_r (0x85,parameter_0.parameter_offset,parameter_0.parameter_data.ir,parameter_1.parameter_data.reg.r);
				return;					
		}
	}

	internal_error_in_function ("as_tst_instruction");
}

static void as_btst_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		int reg1;

		reg1=instruction->instruction_parameters[1].parameter_data.reg.r;
		if (reg1==EAX)
			store_c (0250);
		else {
			store_c (0366);
			store_c (0300 | reg_num (reg1));
		}
		store_c (instruction->instruction_parameters[0].parameter_data.i);
	} else {
		int reg1,offset;

		reg1=instruction->instruction_parameters[1].parameter_data.reg.r;
		offset=instruction->instruction_parameters[1].parameter_offset;
		
		store_c (0366);
		if (reg1==ESP){
			if (offset==0){
				store_c (0x04);
				store_c (0044);
			} else if (((signed char)offset)==offset){
				store_c (0x44);
				store_c (0044);
				store_c (offset);
			} else {
				store_c (0x84);
				store_c (0044);
				store_l (offset);		
			}
		} else {
			if (offset==0 && reg1!=EBP){
				store_c (reg_num (reg1));
			} else if (((signed char)offset)==offset){
				store_c (0x40 | reg_num (reg1));
				store_c (offset);
			} else {
				store_c (0x80 | reg_num (reg1));
				store_l (offset);		
			}
		}
		store_c (instruction->instruction_parameters[0].parameter_data.i);
	}
}

static void as_exg_instruction (struct instruction *instruction)
{
	int r1,r2;
	
	r1=instruction->instruction_parameters[0].parameter_data.reg.r;
	r2=instruction->instruction_parameters[1].parameter_data.reg.r;
	as_xchg (r1,r2);
}

static void as_neg_instruction (struct instruction *instruction)
{	
	as_r (0367,0030,instruction->instruction_parameters[0].parameter_data.reg.r);
}

static void as_not_instruction (struct instruction *instruction)
{	
	as_r (0367,0020,instruction->instruction_parameters[0].parameter_data.reg.r);
}

static void as_clzb_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		int d_reg;
		struct parameter *parameter_0_p;
	
		d_reg=instruction->instruction_parameters[1].parameter_data.reg.r;
#if 0
		parameter_0_p=&instruction->instruction_parameters[0];
		
		/* the lzcnt instruction is encoded as a bsr instruction with a rep prefix */
		/* if the processor does not support lzcnt, it ignores the rep prefix and executes bsr */
		store_c (0xf3); /* rep prefix */
		store_c (0x0f);
		switch (parameter_0_p->parameter_type){
			case P_REGISTER:
				as_r_r (0xbd,parameter_0_p->parameter_data.reg.r,d_reg);
				return;
			case P_INDIRECT:
				as_id_r (0xbd,parameter_0_p->parameter_offset,parameter_0_p->parameter_data.reg.r,d_reg);
				return;
			case P_INDEXED:
				as_x_r (0xbd,parameter_0_p->parameter_offset,parameter_0_p->parameter_data.ir,d_reg);
				return;
		}
#else
		/* intel processors before Haswell do not support the lzcnt instruction, emulate it with bsr */
		as_move_i_r (63,d_reg); /* bsr does not modify the destination register if the argument is 0 */

		parameter_0_p=&instruction->instruction_parameters[0];

		/* bsr */
		store_c (0x0f);
		switch (parameter_0_p->parameter_type){
			case P_REGISTER:
				as_r_r (0xbd,parameter_0_p->parameter_data.reg.r,d_reg);
				break;
			case P_INDIRECT:
				as_id_r (0xbd,parameter_0_p->parameter_offset,parameter_0_p->parameter_data.reg.r,d_reg);
				break;
			case P_INDEXED:
				as_x_r (0xbd,parameter_0_p->parameter_offset,parameter_0_p->parameter_data.ir,d_reg);
				break;
			default:
				internal_error_in_function ("as_clzb_instruction");
				return;
		}
		
		/* xor $31,d_reg */
		if (d_reg==EAX)
			store_c (065);
		else
			as_r (0201,060,d_reg);
		store_l (31);

		return;
#endif
	}

	internal_error_in_function ("as_clzb_instruction");
}

static void as_rtsi_instruction (struct instruction *instruction)
{
	store_c (0xc2);
	store_w (instruction->instruction_parameters[0].parameter_data.i);
}

#ifdef THREAD32
static void as_ldtsp_instruction (struct instruction *instruction)
{
	int reg,reg_n;
	
	reg=instruction->instruction_parameters[1].parameter_data.reg.r;
	
	/* mov label,reg */
	as_r_a (0213,reg,instruction->instruction_parameters[0].parameter_data.l);

	reg_n=reg_num (reg);

	/* mov fs:[0x0e10+reg*4],reg */
	store_c (0x64); /* fs prefix */
	store_c (0213);
	store_c (4 | (reg_n<<3));
	store_c (0205 | (reg_n<<3));
	store_l (0x0e10);
}
#endif

static void as_f_r (int code1,int code2,int freg)
{
	store_c (code1);
	store_c (code2 | freg);
}

static void as_f_a (int code,int code2,LABEL *label)
{
	store_c (code);
	store_c ((code2<<3) | 5);
	store_l (0);
	store_label_in_code_section (label);
}

static void as_f_id (int code,int offset,int reg1,int code2)
{
	store_c (code);
	if (reg1==ESP){
		if (offset==0){
			store_c (0x04 | (code2<<3));
			store_c (0044);
		} else if (((signed char)offset)==offset){
			store_c (0x44 | (code2<<3));
			store_c (0044);
			store_c (offset);
		} else {
			store_c (0x84 | (code2<<3));
			store_c (0044);
			store_l (offset);		
		}
	} else {
		if (offset==0 && reg1!=EBP){
			store_c ((code2<<3) | reg_num (reg1));
		} else if (((signed char)offset)==offset){
			store_c (0x40 | (code2<<3) | reg_num (reg1));
			store_c (offset);
		} else {
			store_c (0x80 | (code2<<3) | reg_num (reg1));
			store_l (offset);		
		}
	}
}

static void as_f_x (int code,int offset,struct index_registers *index_registers,int code2)
{	
	int reg1,reg2,shift;

	reg1=index_registers->a_reg.r;
	reg2=index_registers->d_reg.r;

	shift=offset & 3;
	offset=offset>>2;
	
	if (reg2==ESP)
		internal_error_in_function ("as_f_x");
		
	store_c (code);
	if (offset==0 && reg1!=EBP){
		store_c (0x04 | (code2<<3));
		store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
	} else if (((signed char)offset)==offset){
		store_c (0x44 | (code2<<3));
		store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
		store_c (offset);
	} else {
		store_c (0x84 | (code2<<3));
		store_c ((shift<<6) | (reg_num (reg2)<<3) | reg_num (reg1));
		store_l (offset);
	}
}

static void as_f_i (int code1,int code2,DOUBLE *r_p)
{
	LABEL *new_label;
	
	new_label=allocate_memory_from_heap (sizeof (struct label));

	new_label->label_flags=DATA_LABEL;

	if (data_object_label==NULL)
		as_new_data_module();

	data_object_label->object_section_align8=1;
	if ((data_buffer_p-current_data_buffer->data-data_object_label->object_label_offset) & 4)
		store_long_word_in_data_section (0);

	define_data_label (new_label);
	store_long_word_in_data_section (((LONG*)r_p)[0]);
	store_long_word_in_data_section (((LONG*)r_p)[1]);
	
	as_f_a (code1,code2,new_label);
}

#ifdef FP_STACK_OPTIMIZATIONS
#define FP_REVERSE_SUB_DIV_OPERANDS 1
#define FP_REG_ON_TOP 2
#define FP_REG_LAST_USE 4

struct instruction *find_next_fp_instruction (struct instruction *instruction)
{
	while (instruction!=NULL){
		switch (instruction->instruction_icode){
			case IFADD: case IFSUB: case IFMUL: case IFDIV:
			case IFMOVEL: case IFCMP: case IFNEG: case IFABS: case IFTST: case IFREM:
#if 0
			case IFBEQ: case IFBGE: case IFBGT: case IFBLE: case IFBLT: case IFBNE:
#endif
			case IFSEQ: case IFSGE: case IFSGT: case IFSLE: case IFSLT: case IFSNE:
			case IFCEQ: case IFCGE: case IFCGT: case IFCLE: case IFCLT: case IFCNE:
			case IFCOS: case IFSIN: case IFSQRT: case IFTAN: case IFSINCOS:
			case IFEXG:
			case IWORD:
			case IFLOADS: case IFMOVES:
				return instruction;
			case IFMOVE:
				if (! (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER
					&& instruction->instruction_parameters[1].parameter_type==P_F_REGISTER
					&& instruction->instruction_parameters[0].parameter_data.reg.r==instruction->instruction_parameters[1].parameter_data.reg.r))
				{
					return instruction;
				}
		}
		instruction=instruction->instruction_next;
	}
	return instruction;
}

int next_instruction_is_fld_reg (int reg0,struct instruction *instruction)
{
	struct instruction *next_fp_instruction;
	
	next_fp_instruction=find_next_fp_instruction (instruction->instruction_next);
	if (next_fp_instruction!=NULL){
		switch (next_fp_instruction->instruction_icode){
			case IFADD: case IFSUB: case IFMUL: case IFDIV:
			case IFSQRT: case IFNEG: case IFABS: case IFSIN: case IFCOS:
				if (next_fp_instruction->instruction_parameters[0].parameter_type==P_F_REGISTER
					&& next_fp_instruction->instruction_parameters[0].parameter_data.reg.r==reg0)
				{
					next_fp_instruction->instruction_parameters[0].parameter_flags |= FP_REG_ON_TOP;
					
					if (!(next_fp_instruction->instruction_parameters[0].parameter_flags & FP_REG_LAST_USE))
						return 1;
					else
						return 2;
				}
				break;
			case IFCMP:
				if (next_fp_instruction->instruction_parameters[1].parameter_data.reg.r==reg0){
					next_fp_instruction->instruction_parameters[1].parameter_flags |= FP_REG_ON_TOP;
					
					if (!(next_fp_instruction->instruction_parameters[1].parameter_flags & FP_REG_LAST_USE))
						return 1;
					else
						return 2;
				}
				break;
			case IFEXG:
				if (next_fp_instruction->instruction_parameters[0].parameter_data.reg.r==reg0){
					next_fp_instruction->instruction_parameters[0].parameter_flags |= FP_REG_ON_TOP;					
					return 2;
				}
				if (next_fp_instruction->instruction_parameters[1].parameter_data.reg.r==reg0){
					next_fp_instruction->instruction_parameters[1].parameter_flags |= FP_REG_ON_TOP;					
					return 2;
				}
				break;
			case IFMOVE:
				if (next_fp_instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
					if (next_fp_instruction->instruction_parameters[0].parameter_data.reg.r==reg0 /* && reg0!=0 */){
						next_fp_instruction->instruction_parameters[0].parameter_flags |= FP_REG_ON_TOP;
						
						if (!(next_fp_instruction->instruction_parameters[0].parameter_flags & FP_REG_LAST_USE))
							return 1;
						else
							return 2;
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
											
											if (!(flags1 & FP_REG_LAST_USE))
												return 1;
											else
												return 2;
										}
									}
							}
						}
					}
				}
		}
	}
	
	return 0;
}

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

					if (!(next_fp_instruction->instruction_parameters[0].parameter_flags & FP_REG_LAST_USE))
						as_f_r (0xdd,0xd0,reg0+1); /* fst reg0+1 */

					return;						
				}
				break;
			case IFCMP:
				if (next_fp_instruction->instruction_parameters[1].parameter_data.reg.r==reg0){
					next_fp_instruction->instruction_parameters[1].parameter_flags |= FP_REG_ON_TOP;

					if (!(next_fp_instruction->instruction_parameters[1].parameter_flags & FP_REG_LAST_USE))
						as_f_r (0xdd,0xd0,reg0+1); /* fst reg0+1 */

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
						
						if (!(next_fp_instruction->instruction_parameters[0].parameter_flags & FP_REG_LAST_USE))
							as_f_r (0xdd,0xd0,reg0+1); /* fst reg0+1 */

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
											
											if (!(flags1 & FP_REG_LAST_USE))
												as_f_r (0xdd,0xd0,reg0+1); /* fst reg0+1 */

											return;						
										}
									}
							}
						}
					}
				}
		}
	}
	
	as_f_r (0xdd,0xd8,reg0+1); /* fstp reg0+1 */
}
#endif

static struct instruction *as_fmove_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_F_REGISTER:
#if 1
		{
			int reg0;
			
			reg0=-1;
			
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_F_REGISTER:
# ifdef FP_STACK_OPTIMIZATIONS
					if (instruction->instruction_parameters[0].parameter_flags & FP_REG_ON_TOP)
						break;
# endif
					reg0=instruction->instruction_parameters[0].parameter_data.reg.r;
					
					if (reg0==instruction->instruction_parameters[1].parameter_data.reg.r)
						return instruction;
					
					if (reg0==0){
						as_f_r (0xdd,0xd0,instruction->instruction_parameters[1].parameter_data.reg.r); /* fst reg1 */
						return instruction;
					}
			
					as_f_r (0xd9,0xc0,reg0); /* fld reg0 */
					break;
				case P_INDIRECT:
					as_f_id (0xdd,instruction->instruction_parameters[0].parameter_offset,
								  instruction->instruction_parameters[0].parameter_data.reg.r,0); /* fldl */
					break;
				case P_INDEXED:
					as_f_x (0xdd,instruction->instruction_parameters[0].parameter_offset,
							     instruction->instruction_parameters[0].parameter_data.ir,0); /* fldl */
					break;
				case P_F_IMMEDIATE:
					as_f_i (0xdd,0,instruction->instruction_parameters[0].parameter_data.r); /* fldl */
					break;
				default:
					internal_error_in_function ("as_fmove_instruction");
					return instruction;
			}
# ifdef FP_STACK_OPTIMIZATIONS
			fstpl_instruction (instruction->instruction_parameters[1].parameter_data.reg.r,instruction);
			return instruction;
		}
# else
			{
				struct instruction *next_instruction;
				int reg1;

				reg1=instruction->instruction_parameters[1].parameter_data.reg.r;
				next_instruction=instruction->instruction_next;

				if (next_instruction)
					switch (next_instruction->instruction_icode){
						case IFADD: case IFSUB: case IFMUL: case IFDIV:
							if (next_instruction->instruction_parameters[1].parameter_data.reg.r==reg1){
								if (next_instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
									int reg_s,code2;

									reg_s=next_instruction->instruction_parameters[0].parameter_data.reg.r;
									if (reg_s==reg1)
										reg_s=reg0;

									switch (next_instruction->instruction_icode){
										case IFADD:
											code2=0xc0;
											break;
										case IFSUB:
#  ifdef FSUB_FDIV_REVERSED
											if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
												code2=0xe8;
											else
#  endif
												code2=0xe0;
											break;
										case IFMUL:
											code2=0xc8;
											break;
										case IFDIV:
#  ifdef FSUB_FDIV_REVERSED
											if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
												code2=0xf8;
											else
#  endif
												code2=0xf0;
											break;
									}

									as_f_r (0xd8,code2,reg_s+1);
								} else {
									int code2;
									
									switch (next_instruction->instruction_icode){
										case IFADD:
											code2=0;
											break;
										case IFSUB:
#  ifdef FSUB_FDIV_REVERSED
											if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
												code2=5;
											else
#  endif
												code2=4;
											break;
										case IFMUL:
											code2=1;
											break;
										case IFDIV:
#  ifdef FSUB_FDIV_REVERSED
											if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
												code2=7;
											else
#  endif
												code2=6;
											break;
									}

									switch (next_instruction->instruction_parameters[0].parameter_type){
										case P_F_IMMEDIATE:	
											as_f_i (0xdc,code2,next_instruction->instruction_parameters[0].parameter_data.r);
											break;
										case P_INDIRECT:
											as_f_id (0xdc,next_instruction->instruction_parameters[0].parameter_offset,
														  next_instruction->instruction_parameters[0].parameter_data.reg.r,code2);
											break;
										case P_INDEXED:
											as_f_x (0xdc,next_instruction->instruction_parameters[0].parameter_offset,
														 next_instruction->instruction_parameters[0].parameter_data.ir,code2);
											break;
										default:
											internal_error_in_function ("as_fmove_instruction");
											return instruction;
									}
								}
									
								as_f_r (0xdd,0xd8,reg1+1); /* fstp reg1+1 */
									
								return next_instruction;
							}
					}
		
				as_f_r (0xdd,0xd8,reg1+1); /* fstp reg */
				return instruction;
			}
		}
# endif
#else
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
								if (next_instruction->instruction_parameters[0].parameter_type==P_F_REGISTER &&
									next_instruction->instruction_parameters[1].parameter_data.reg.r==reg1)
								{
									int reg_s,code2;

									reg_s=next_instruction->instruction_parameters[0].parameter_data.reg.r;
									if (reg_s==reg1)
										reg_s=reg0;
									
									as_f_r (0xd9,0xc0,reg0); /* fld reg0 */
									
									switch (next_instruction->instruction_icode){
										case IFADD:
											code2=0xc0;
											break;
										case IFSUB:
											code2=0xe0;
											break;
										case IFMUL:
											code2=0xc8;
											break;
										case IFDIV:
											code2=0xf0;
											break;
									}

									as_f_r (0xd8,code2,reg_s+1);
									as_f_r (0xdd,0xd8,reg1+1); /* fstp reg1+1 */
									
									return next_instruction;
								}
						}
					as_f_r (0xd9,0xc0,instruction->instruction_parameters[0].parameter_data.reg.r); /* fld reg */
					break;
				}
				case P_INDIRECT:
					as_f_id (0xdd,instruction->instruction_parameters[0].parameter_offset,
								  instruction->instruction_parameters[0].parameter_data.reg.r,0); /* fldl */
					break;
				case P_INDEXED:
					as_f_x (0xdd,instruction->instruction_parameters[0].parameter_offset,
								   instruction->instruction_parameters[0].parameter_data.ir,0); /* fldl */
					break;
				case P_F_IMMEDIATE:
					as_f_i (0xdd,0,instruction->instruction_parameters[0].parameter_data.r); /* fldl */
					break;
				default:
					internal_error_in_function ("as_fmove_instruction");
					return instruction;
			}
			
			as_f_r (0xdd,0xd8,instruction->instruction_parameters[1].parameter_data.reg.r+1); /* fstp reg */
			return instruction;			
#endif
		case P_INDIRECT:
		case P_INDEXED:
			if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
				int s_freg,code2;
				
				s_freg=instruction->instruction_parameters[0].parameter_data.reg.r;

#ifdef FP_STACK_OPTIMIZATIONS
				if (instruction->instruction_parameters[0].parameter_flags & FP_REG_ON_TOP){
					if (next_instruction_is_fld_reg (s_freg,instruction))
						code2=2; /* fstl */
					else
						code2=3; /* fstpl */
				} else
#endif			
				if (s_freg!=0){
					as_f_r (0xd9,0xc0,s_freg); /* fld s_freg */

#ifdef FP_STACK_OPTIMIZATIONS
					if (next_instruction_is_fld_reg (s_freg,instruction))
						code2=2; /* fstl */
					else
#endif
					code2=3; /* fstpl */
				} else
					code2=2; /* fstl */
				
				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT)
					as_f_id (0xdd,instruction->instruction_parameters[1].parameter_offset,
							  	  instruction->instruction_parameters[1].parameter_data.reg.r,code2);
				else
					as_f_x (0xdd,instruction->instruction_parameters[1].parameter_offset,
								 instruction->instruction_parameters[1].parameter_data.ir,code2);
				
				return instruction;
			}
	}
	internal_error_in_function ("as_fmove_instruction");
	return instruction;
}

static struct instruction *as_floads_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_F_REGISTER:
		{
			int reg0;
			
			reg0=-1;
			
			switch (instruction->instruction_parameters[0].parameter_type){
				case P_INDIRECT:
					as_f_id (0xd9,instruction->instruction_parameters[0].parameter_offset,
								  instruction->instruction_parameters[0].parameter_data.reg.r,0); /* flds */
					break;
				case P_INDEXED:
					as_f_x (0xd9,instruction->instruction_parameters[0].parameter_offset,
							     instruction->instruction_parameters[0].parameter_data.ir,0); /* flds */
					break;
				default:
					internal_error_in_function ("as_floads_instruction");
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
								if (next_instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
									int reg_s,code2;

									reg_s=next_instruction->instruction_parameters[0].parameter_data.reg.r;
									if (reg_s==reg1)
										reg_s=reg0;

									switch (next_instruction->instruction_icode){
										case IFADD:
											code2=0xc0;
											break;
										case IFSUB:
# ifdef FSUB_FDIV_REVERSED
											if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
												code2=0xe8;
											else
# endif
												code2=0xe0;
											break;
										case IFMUL:
											code2=0xc8;
											break;
										case IFDIV:
# ifdef FSUB_FDIV_REVERSED
											if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
												code2=0xf8;
											else
# endif
												code2=0xf0;
											break;
									}

									as_f_r (0xd8,code2,reg_s+1);
								} else {
									int code2;
									
									switch (next_instruction->instruction_icode){
										case IFADD:
											code2=0;
											break;
										case IFSUB:
# ifdef FSUB_FDIV_REVERSED
											if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
												code2=5;
											else
# endif
												code2=4;
											break;
										case IFMUL:
											code2=1;
											break;
										case IFDIV:
# ifdef FSUB_FDIV_REVERSED
											if (next_instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
												code2=7;
											else
# endif
												code2=6;
											break;
									}

									switch (next_instruction->instruction_parameters[0].parameter_type){
										case P_F_IMMEDIATE:	
											as_f_i (0xdc,code2,next_instruction->instruction_parameters[0].parameter_data.r);
											break;
										case P_INDIRECT:
											as_f_id (0xdc,next_instruction->instruction_parameters[0].parameter_offset,
														  next_instruction->instruction_parameters[0].parameter_data.reg.r,code2);
											break;
										case P_INDEXED:
											as_f_x (0xdc,next_instruction->instruction_parameters[0].parameter_offset,
														 next_instruction->instruction_parameters[0].parameter_data.ir,code2);
											break;
										default:
											internal_error_in_function ("as_floads_instruction");
											return instruction;
									}
								}
									
								as_f_r (0xdd,0xd8,reg1+1); /* fstp reg1+1 */
									
								return next_instruction;
							}
					}
		
				as_f_r (0xdd,0xd8,reg1+1); /* fstp reg */
				return instruction;
			}
		}
#endif
	}
	internal_error_in_function ("as_floads_instruction");
	return instruction;
}

static struct instruction *as_fmoves_instruction (struct instruction *instruction)
{
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_INDIRECT:
		case P_INDEXED:
			if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
				int s_freg,code2;
				
				s_freg=instruction->instruction_parameters[0].parameter_data.reg.r;

#ifdef FP_STACK_OPTIMIZATIONS
				if (instruction->instruction_parameters[0].parameter_flags & FP_REG_ON_TOP){
					if (next_instruction_is_fld_reg (s_freg,instruction))
						code2=2; /* fsts */
					else
						code2=3; /* fstps */
				} else
#endif			
				if (s_freg!=0){
					as_f_r (0xd9,0xc0,s_freg); /* fld s_freg */

#ifdef FP_STACK_OPTIMIZATIONS
					if (next_instruction_is_fld_reg (s_freg,instruction))
						code2=2; /* fsts */
					else
#endif
					code2=3; /* fstps */
				} else
					code2=2; /* fsts */
				
				if (instruction->instruction_parameters[1].parameter_type==P_INDIRECT)
					as_f_id (0xd9,instruction->instruction_parameters[1].parameter_offset,
							  	  instruction->instruction_parameters[1].parameter_data.reg.r,code2);
				else
					as_f_x (0xd9,instruction->instruction_parameters[1].parameter_offset,
								 instruction->instruction_parameters[1].parameter_data.ir,code2);
				
				return instruction;
			}
	}
	internal_error_in_function ("as_fmoves_instruction");
	return instruction;
}

static void as_dyadic_float_instruction (struct instruction *instruction,int code,int code1,int code2)
{
	int d_freg;
	
	d_freg=instruction->instruction_parameters[1].parameter_data.reg.r;

#ifdef FP_STACK_OPTIMIZATIONS
	if (instruction->instruction_parameters[1].parameter_flags & FP_REG_ON_TOP){
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_F_IMMEDIATE:	
				as_f_i (0xdc,code,instruction->instruction_parameters[0].parameter_data.r);
				break;
			case P_INDIRECT:
				as_f_id (0xdc,instruction->instruction_parameters[0].parameter_offset,
							  instruction->instruction_parameters[0].parameter_data.reg.r,code);
				break;
			case P_INDEXED:
				as_f_x (0xdc,instruction->instruction_parameters[0].parameter_offset,
							  instruction->instruction_parameters[0].parameter_data.ir,code);
				break;
			case P_F_REGISTER:
			{
				int reg_s;

				if (instruction->instruction_parameters[0].parameter_flags & FP_REG_ON_TOP)
					reg_s=0;
				else
					reg_s=instruction->instruction_parameters[0].parameter_data.reg.r+1;

				as_f_r (0xd8,code1,reg_s);
				break;
			}
			default:
				internal_error_in_function ("as_dyadic_float_instruction");
				return;
		}

		fstpl_instruction (d_freg,instruction);	
		
		return;
	} else if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER
			   && instruction->instruction_parameters[0].parameter_flags & FP_REG_ON_TOP)
	{
		int n;
		
		n=next_instruction_is_fld_reg (d_freg,instruction);		
		if (n){
			as_f_r (0xd8,code2,d_freg+1);			
			if (n==1)
				as_f_r (0xdd,0xd0,d_freg+1); /* fst d_reg+1 */
		} else {
			as_f_r (0xde,code2,d_freg+1);
		}
		
		return;
	}
#endif

	if (d_freg!=0){
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_F_IMMEDIATE:
				as_f_i (0xdd,0,instruction->instruction_parameters[0].parameter_data.r); /* fldl */
				break;
			case P_INDIRECT:
				as_f_id (0xdd,instruction->instruction_parameters[0].parameter_offset,
							  instruction->instruction_parameters[0].parameter_data.reg.r,0); /* fldl */
				break;
			case P_INDEXED:
				as_f_x (0xdd,instruction->instruction_parameters[0].parameter_offset,
						     instruction->instruction_parameters[0].parameter_data.ir,0); /* fldl */
				break;
			case P_F_REGISTER:
				if (instruction->instruction_parameters[0].parameter_data.reg.r==0){
					as_f_r (0xdc,code2,d_freg);
					return;
				}
				as_f_r (0xd9,0xc0,instruction->instruction_parameters[0].parameter_data.reg.r); /* fld reg */ 
				break;
			default:
				internal_error_in_function ("as_dyadic_float_instruction");
				return;
		}
		
#ifdef FP_STACK_OPTIMIZATIONS
		{
		int n;
		
		n=next_instruction_is_fld_reg (d_freg,instruction);
		if (n){
			as_f_r (0xd8,code2,d_freg+1);			
			if (n==1)
				as_f_r (0xdd,0xd0,d_freg+1); /* fst d_reg+1 */
		} else
#endif
		as_f_r (0xde,code2,d_freg+1);
#ifdef FP_STACK_OPTIMIZATIONS
		}
#endif
	} else {
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_F_IMMEDIATE:	
				as_f_i (0xdc,code,instruction->instruction_parameters[0].parameter_data.r);
				break;
			case P_INDIRECT:
				as_f_id (0xdc,instruction->instruction_parameters[0].parameter_offset,
							  instruction->instruction_parameters[0].parameter_data.reg.r,code);
				break;
			case P_INDEXED:
				as_f_x (0xdc,instruction->instruction_parameters[0].parameter_offset,
							  instruction->instruction_parameters[0].parameter_data.ir,code);
				break;
			case P_F_REGISTER:
				as_f_r (0xd8,code1,instruction->instruction_parameters[0].parameter_data.reg.r);
				break;
			default:
				internal_error_in_function ("as_dyadic_float_instruction");
				return;
		}
	}
}

static void as_compare_float_instruction (struct instruction *instruction)
{
	int d_freg;
	int code1,code2;
	
	d_freg=instruction->instruction_parameters[1].parameter_data.reg.r;
	
#ifdef FP_STACK_OPTIMIZATIONS
	if (instruction->instruction_parameters[1].parameter_flags & FP_REG_ON_TOP){
		code1=3;
		code2=0xd8; /* fcomp */
	} else
#endif
	if (d_freg!=0){
		as_f_r (0xd9,0xc0,d_freg); /* fld d_freg */
		
		code1=3;
		code2=0xd8; /* fcomp */
	} else {
		code1=2;
		code2=0xd0; /* fcom */
	}
	
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_F_IMMEDIATE:
			as_f_i (0xdc,code1,instruction->instruction_parameters[0].parameter_data.r);
			break;
		case P_INDIRECT:
			as_f_id (0xdc,instruction->instruction_parameters[0].parameter_offset,
						  instruction->instruction_parameters[0].parameter_data.reg.r,code1);
			break;
		case P_INDEXED:
			as_f_x (0xdc,instruction->instruction_parameters[0].parameter_offset,
						 instruction->instruction_parameters[0].parameter_data.ir,code1);
			break;
		case P_F_REGISTER:
			as_f_r (0xd8,code2,instruction->instruction_parameters[0].parameter_data.reg.r+(d_freg!=0));
			break;
		default:
			internal_error_in_function ("as_compare_float_instruction");
			return;
	}
}

static void as_monadic_float_instruction (struct instruction *instruction,int code)
{
	int d_freg;
	
	d_freg=instruction->instruction_parameters[1].parameter_data.reg.r;
			
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_F_IMMEDIATE:
			as_f_i (0xdd,0,instruction->instruction_parameters[0].parameter_data.r); /* fldl */
			break;
		case P_INDIRECT:
			as_f_id (0xdd,instruction->instruction_parameters[0].parameter_offset,
						  instruction->instruction_parameters[0].parameter_data.reg.r,0); /* fldl */
			break;
		case P_INDEXED:
			as_f_x (0xdd,instruction->instruction_parameters[0].parameter_offset,
						   instruction->instruction_parameters[0].parameter_data.ir,0); /* fldl */
			break;
		case P_F_REGISTER:
#ifdef FP_STACK_OPTIMIZATIONS
			if (instruction->instruction_parameters[0].parameter_flags & FP_REG_ON_TOP)
				break;
#endif
			if (instruction->instruction_parameters[0].parameter_data.reg.r==0 && d_freg==0){
				store_c (0xd9);
				store_c (code);
				return;
			} else
				as_f_r (0xd9,0xc0,instruction->instruction_parameters[0].parameter_data.reg.r); /* fld */
			break;
		default:
			internal_error_in_function ("as_monadic_float_instruction");
			return;
	}

	store_c (0xd9);
	store_c (code);

#ifdef FP_STACK_OPTIMIZATIONS
	fstpl_instruction (d_freg,instruction);	
#else
	as_f_r (0xdd,0xd8,d_freg+1); /* fstp */
#endif
}

static void as_fsincos_instruction (struct instruction *instruction)
{
	int f_reg1,f_reg2;
	
	f_reg1=instruction->instruction_parameters[0].parameter_data.reg.r;
	f_reg2=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (f_reg1!=0){
		store_c (0xd9); /* fxch f1 */
		store_c (0xc8+f_reg1);
	}

	store_c (0xd9); /* fsincos */
	store_c (0xfb);

	if (f_reg1==0){
#ifdef FP_STACK_OPTIMIZATIONS
		fstpl_instruction (f_reg2,instruction);	
#else
		as_f_r (0xdd,0xd8,f_reg2+1); /* fstp */
#endif
	} else if (f_reg2==0){
		store_c (0xd9); /* fxch st(1) */
		store_c (0xc8+1);

#ifdef FP_STACK_OPTIMIZATIONS
		fstpl_instruction (f_reg1,instruction);	
#else
		as_f_r (0xdd,0xd8,f_reg1+1); /* fstp */
#endif
	} else {
		as_f_r (0xdd,0xd8,f_reg2+1); /* fstp */

		store_c (0xd9); /* fxch f1 */
		store_c (0xc8+f_reg1);
	}	
}

static void as_test_floating_point_condition_code (int n)
{
	store_c (0xdf);
	store_c (0xe0); /* fnstsw %ax */
	/*
	C0 = bit 0( 8) = unordered || ST(0)<source
	C2 = bit 2(10) = unordered
	C3 = bit 6(14) = unordered || ST(0)==source
	*/
	store_c (0x80);
	store_c (0xe4); /* andb $i,%ah */

	switch (n){
		case 0:
			store_c (68);		/* andb $68,%ah */
			store_c (0x80);
			store_c (0xf4);
			store_c (64);		/* xorb $64,%ah */
			break;
		case 1:
			store_c (69);		/* andb $69,%ah */
			store_c (0x80);
			store_c (0xfc);
			store_c (1);		/* cmpb $1,%ah */
			break;
		case 2:
			store_c (69);		/* andb $69,%ah */
			break;
		case 3:
			store_c (64);		/* andb $64,%ah */
			break;
		case 4:
			store_c (69);		/* andb $69,%ah */
			store_c (0xfe);
			store_c (0xcc);		/* decb %ah */
			store_c (0x80);
			store_c (0xfc);
			store_c (64);		/* cmpb $64,%ah */
			break;
		case 5:
			store_c (5);		/* andb $5,%ah */
			break;
	}
}

static void as_set_float_condition_instruction (struct instruction *instruction,int n)
{
	int r;

	r=instruction->instruction_parameters[0].parameter_data.reg.r;

	if (r!=REGISTER_D0)
		as_r_r (0213,REGISTER_D0,r);

	as_test_floating_point_condition_code (n);

	store_c (0x0f);
	store_c (n!=4 ? 0x94 : 0x92); /* sete %al : setb %al */
	store_c (0xc0);

	/* movzbl */
	store_c (017);
	store_c (0266);
	store_c (0300 | (reg_num (REGISTER_D0)<<3) | 0 /* %al */);

	if (r!=REGISTER_D0)
		as_xchg_eax_r (r); /* xchg r,D0 */
}

static void as_convert_float_condition_instruction (struct instruction *instruction,int n)
{
	int r;

	r=instruction->instruction_parameters[0].parameter_data.reg.r;

	if (r!=REGISTER_D0)
		as_r_r (0213,REGISTER_D0,r);

	as_test_floating_point_condition_code (n);

	if (r!=REGISTER_D0)
		as_r_r (0213,r,REGISTER_D0);
}

#ifdef FP_STACK_OPTIMIZATIONS
static void as_fexg (struct instruction *instruction)
{
	int f_reg1,f_reg2;
	
	f_reg1=instruction->instruction_parameters[0].parameter_data.reg.r;
	f_reg2=instruction->instruction_parameters[1].parameter_data.reg.r;

	if (instruction->instruction_parameters[0].parameter_flags & FP_REG_ON_TOP){
		if (f_reg1!=f_reg2){
			store_c (0xd9);
			store_c (0xc8+f_reg2+1);
		}

		fstpl_instruction (f_reg1,instruction);
		return;
	} else if (instruction->instruction_parameters[1].parameter_flags & FP_REG_ON_TOP){
		if (f_reg1!=f_reg2){
			store_c (0xd9);
			store_c (0xc8+f_reg1+1);
		}

		fstpl_instruction (f_reg2,instruction);
		return;	
	} else {
		if (f_reg1!=f_reg2){
			if (f_reg1==0){
				store_c (0xd9);
				store_c (0xc8+f_reg2);
			} else if (f_reg2==0){
				store_c (0xd9);
				store_c (0xc8+f_reg1);
			} else {
				store_c (0xd9);
				store_c (0xc8+f_reg1);

				store_c (0xd9);
				store_c (0xc8+f_reg2);

				store_c (0xd9);
				store_c (0xc8+f_reg1);
			}
		}
	}
}
#endif			

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

#ifndef OMF
		++n_object_labels;
#endif
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
#ifndef THREAD32
			LABEL *new_label;
			
			new_label=allocate_memory_from_heap (sizeof (struct label));
		
			new_label->label_flags=DATA_LABEL;
			
			define_data_label (new_label);
			store_long_word_in_data_section (0);
			
			s_freg=instruction->instruction_parameters[0].parameter_data.reg.r;
			if (s_freg!=0){
				as_f_r (0xd9,0xc0,s_freg); /* fld s_freg */
				as_f_a (0xdb,3,new_label); /* fistp */
			} else
				as_f_a (0xdb,2,new_label); /* fist */
			as_r_a (0x8b,instruction->instruction_parameters[1].parameter_data.reg.r,new_label);			
#else
		s_freg=instruction->instruction_parameters[0].parameter_data.reg.r;
		if (s_freg!=0){
			as_f_r (0xd9,0xc0,s_freg);		/* fld s_freg */		
			as_f_id (0xdb,8,REGISTER_A4,3); /* fistp */
		} else
			as_f_id (0xdb,8,REGISTER_A4,2); /* fist */
		as_id_r (0213,8,REGISTER_A4,instruction->instruction_parameters[1].parameter_data.reg.r); /* mov */
#endif
		} else
			internal_error_in_function ("as_fmovel_instruction");
	} else {
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_REGISTER:
			{
#ifndef THREAD32
				LABEL *new_label;
				
				new_label=allocate_memory_from_heap (sizeof (struct label));
		
				new_label->label_flags=DATA_LABEL;
			
				define_data_label (new_label);
				store_long_word_in_data_section (0);

				as_r_a (0211,instruction->instruction_parameters[0].parameter_data.reg.r,new_label);
				as_f_a (0xdb,0,new_label); /* fildl */
#else
				as_r_id (0211,instruction->instruction_parameters[0].parameter_data.reg.r,8,REGISTER_A4); /* mov */
				as_f_id (0xdb,8,REGISTER_A4,0); /* fildl */
#endif
				break;
			}
			case P_INDIRECT:
				as_f_id (0xdb,instruction->instruction_parameters[0].parameter_offset,
							  instruction->instruction_parameters[0].parameter_data.reg.r,0); /* fildl */
				break;
			case P_INDEXED:
				as_f_x (0xdb,instruction->instruction_parameters[0].parameter_offset,
							 instruction->instruction_parameters[0].parameter_data.ir,0); /* fildl */
				break;
			case P_IMMEDIATE:
			{
				LABEL *new_label;
				
				new_label=allocate_memory_from_heap (sizeof (struct label));
		
				new_label->label_flags=DATA_LABEL;
			
				define_data_label (new_label);
				store_long_word_in_data_section (instruction->instruction_parameters[0].parameter_data.i);

				as_f_a (0xdb,0,new_label); /* fildl */
				break;
			}
			default:
				internal_error_in_function ("as_fmovel_instruction");
		}

#ifdef FP_STACK_OPTIMIZATIONS
		fstpl_instruction (instruction->instruction_parameters[1].parameter_data.reg.r,instruction);
#else
		as_f_r (0xdd,0xd8,instruction->instruction_parameters[1].parameter_data.reg.r+1); /* fstp reg */
#endif
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
#ifndef OMF
				++n_object_labels;
#endif		
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
				store_c (0303);
				break;
			case IRTSP:
				store_c (0351);
				store_l (0);
				as_branch_label (profile_r_label,JUMP_RELOCATION);
				break;
			case IBEQ:
				as_branch_instruction (instruction,004);
				break;
			case IBGE:
				as_branch_instruction (instruction,015);
				break;
			case IBGEU:
				as_branch_instruction (instruction,003);
				break;
			case IBGT:
				as_branch_instruction (instruction,017);
				break;
			case IBGTU:
				as_branch_instruction (instruction,007);
				break;
			case IBLE:
				as_branch_instruction (instruction,016);
				break;
			case IBLEU:
				as_branch_instruction (instruction,006);
				break;
			case IBLT:
				as_branch_instruction (instruction,014);
				break;
			case IBLTU:
				as_branch_instruction (instruction,002);
				break;
			case IBNE:
				as_branch_instruction (instruction,005);
				break;
			case IBO:
				as_branch_instruction (instruction,0);
				break;
			case IBNO:
				as_branch_instruction (instruction,1);
				break;
			case ILSL:
				as_shift_instruction (instruction,4);
				break;
			case ILSR:
				as_shift_instruction (instruction,5);
				break;
			case IASR:
				as_shift_instruction (instruction,7);
				break;
			case ILSL_S:
				as_shift_s_instruction (instruction,4);
				break;
			case ILSR_S:
				as_shift_s_instruction (instruction,5);
				break;
			case IASR_S:
				as_shift_s_instruction (instruction,7);
				break;
			case IMUL:
				as_mul_instruction (instruction);
				break;
			case IDIV:
				as_div_instruction (instruction,0);
				break;
			case IDIVI:
				as_div_rem_i_instruction (instruction,0);
				break;
			case IDIVU:
				as_div_instruction (instruction,1);
				break;
			case IREM:
				as_rem_instruction (instruction,0);
				break;
			case IREMI:
				as_div_rem_i_instruction (instruction,1);
				break;
			case IREMU:
				as_rem_instruction (instruction,1);
				break;
			case IAND:
				as_logic_instruction (instruction,0043,040,045);
				break;
			case IOR:
				as_logic_instruction (instruction,0013,010,015);
				break;
			case IEOR:
				as_logic_instruction (instruction,0063,060,065);
				break;
			case ISEQ:
				as_set_condition_instruction (instruction,004);
				break;
			case ISGE:
				as_set_condition_instruction (instruction,015);
				break;
			case ISGEU:
				as_set_condition_instruction (instruction,003);
				break;
			case ISGT:
				as_set_condition_instruction (instruction,017);
				break;
			case ISGTU:
				as_set_condition_instruction (instruction,007);
				break;
			case ISLE:
				as_set_condition_instruction (instruction,016);
				break;
			case ISLEU:
				as_set_condition_instruction (instruction,006);
				break;
			case ISLT:
				as_set_condition_instruction (instruction,014);
				break;
			case ISLTU:
				as_set_condition_instruction (instruction,002);
				break;
			case ISNE:
				as_set_condition_instruction (instruction,005);
				break;
			case ISO:
				as_set_condition_instruction (instruction,0);
				break;
			case ISNO:
				as_set_condition_instruction (instruction,1);
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
				as_movew_instruction (instruction);
				break;
			case IMOVEB:
				as_moveb_instruction (instruction);
				break;
			case IEXG:
				as_exg_instruction (instruction);
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
			case IADC:
				as_adc_instruction (instruction);
				break;
			case ISBB:
				as_sbb_instruction (instruction);
				break;
			case IMULUD:
				as_mulud_instruction (instruction);
				break;
			case IDIVDU:
				as_divdu_instruction (instruction);
				break;
			case IFLOORDIV:
				as_floordiv_mod_instruction (instruction,0);
				break;
			case IMOD:
				as_floordiv_mod_instruction (instruction,1);
				break;
			case IWORD:
				store_c (instruction->instruction_parameters[0].parameter_data.i);
				break;
			case IROTL:
				as_shift_instruction (instruction,0);
				break;
			case IROTR:
				as_shift_instruction (instruction,1);
				break;
			case IROTL_S:
				as_shift_s_instruction (instruction,0);
				break;
			case IROTR_S:
				as_shift_s_instruction (instruction,1);
				break;
			case IFMOVE:
				instruction=as_fmove_instruction (instruction);
				break;
			case IFADD:
				as_dyadic_float_instruction (instruction,0,0xc0,0xc0); /*faddl fadd faddp*/
				break;
			case IFSUB:
#ifdef FSUB_FDIV_REVERSED
				if (instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
					as_dyadic_float_instruction (instruction,5,0xe8,0xe0); /*fsubrl fsubr fsubp*/
				else
#endif
					as_dyadic_float_instruction (instruction,4,0xe0,0xe8); /*fsubl fsub fsubrp*/
				break;
			case IFCMP:
				as_compare_float_instruction (instruction);
				break;
			case IFDIV:
#ifdef FSUB_FDIV_REVERSED
				if (instruction->instruction_parameters[1].parameter_flags & FP_REVERSE_SUB_DIV_OPERANDS)
					as_dyadic_float_instruction (instruction,7,0xf8,0xf0); /*fdivrl fdivr fdivp*/
				else
#endif
					as_dyadic_float_instruction (instruction,6,0xf0,0xf8); /*fdivl fdiv fdivrp*/
				break;
			case IFMUL:
				as_dyadic_float_instruction (instruction,1,0xc8,0xc8); /*fmull fmul fmulp*/
				break;
			case IFMOVEL:
				as_fmovel_instruction (instruction);
				break;
			case IFLOADS:
				instruction=as_floads_instruction (instruction);
				break;
			case IFMOVES:
				instruction=as_fmoves_instruction (instruction);
				break;
			case IFSQRT:
				as_monadic_float_instruction (instruction,0xfa);
				break;
			case IFNEG:
				as_monadic_float_instruction (instruction,0xe0);
				break;
			case IFABS:
				as_monadic_float_instruction (instruction,0xe1);
				break;
			case IFSIN:
				as_monadic_float_instruction (instruction,0xfe);
				break;
			case IFCOS:
				as_monadic_float_instruction (instruction,0xff);
				break;
			case IFSEQ:
				as_set_float_condition_instruction (instruction,0);
				break;
			case IFSGE:
				as_set_float_condition_instruction (instruction,5);
				break;
			case IFSGT:
				as_set_float_condition_instruction (instruction,2);
				break;
			case IFSLE:
				as_set_float_condition_instruction (instruction,4);
				break;
			case IFSLT:
				as_set_float_condition_instruction (instruction,1);
				break;
			case IFSNE:
				as_set_float_condition_instruction (instruction,3);
				break;
			case IFCEQ:
				as_convert_float_condition_instruction (instruction,0);
				break;
			case IFCGE:
				as_convert_float_condition_instruction (instruction,5);
				break;
			case IFCGT:
				as_convert_float_condition_instruction (instruction,2);
				break;
			case IFCLE:
				as_convert_float_condition_instruction (instruction,4);
				break;
			case IFCLT:
				as_convert_float_condition_instruction (instruction,1);
				break;
			case IFCNE:
				as_convert_float_condition_instruction (instruction,3);
				break;
			case IRTSI:
				as_rtsi_instruction (instruction);
				break;
#ifdef FP_STACK_OPTIMIZATIONS
			case IFEXG:
				as_fexg (instruction);
				break;
#endif
			case IFSINCOS:
				as_fsincos_instruction (instruction);
				break;
#ifdef THREAD32
			case ILDTLSP:
				as_ldtsp_instruction (instruction);
				break;
#endif
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

	n_cells=block->block_n_new_heap_cells;	
	
	new_call_and_jump=allocate_memory_from_heap (sizeof (struct call_and_jump));
	new_call_and_jump->cj_next=NULL;

	switch (block->block_n_begin_a_parameter_registers){
		case 0:
			if (n_cells<=8)
				new_call_and_jump->cj_call_label=collect_0_label;
			else
				new_call_and_jump->cj_call_label=collect_0l_label;
			break;
		case 1:
			if (n_cells<=8)
				new_call_and_jump->cj_call_label=collect_1_label;
			else
				new_call_and_jump->cj_call_label=collect_1l_label;
			break;
		case 2:
			if (n_cells<=8)
				new_call_and_jump->cj_call_label=collect_2_label;
			else
				new_call_and_jump->cj_call_label=collect_2l_label;
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

#ifdef THREAD32
	as_id_r (0213,0,REGISTER_A4,HEAP_POINTER); /* mov */
#endif

	if (n_cells<=8)
#ifndef THREAD32
		as_r_a (0073,HEAP_POINTER,end_heap_label); /* cmp */
#else
		as_id_r (0073,4,REGISTER_A4,HEAP_POINTER); /* cmp */
#endif
	else {
#ifndef THREAD32
		as_id_r (0215,(n_cells-8)<<2,HEAP_POINTER,REGISTER_O0); /* lea */
		as_r_a (0073,REGISTER_O0,end_heap_label); /* cmp */
#else
		as_i_r2 (0201,0000,0005,(n_cells-8)<<2,HEAP_POINTER); /* add */
		as_id_r (0073,4,REGISTER_A4,HEAP_POINTER); /* cmp */
#endif
	}

	store_c (0x0f);
	store_c (0x83); /* jae */
	store_l (0);
	as_branch_label (&new_call_and_jump->cj_label,BRANCH_RELOCATION);

	new_call_and_jump->cj_jump.label_flags=0;
	new_call_and_jump->cj_jump.label_id=TEXT_LABEL_ID;
#ifdef FUNCTION_LEVEL_LINKING
	new_call_and_jump->cj_jump.label_object_label=code_object_label;
#endif
	new_call_and_jump->cj_jump.label_offset=CURRENT_CODE_OFFSET;

#ifdef THREAD32
	if (n_cells>8)
		as_id_r (0213,0,REGISTER_A4,HEAP_POINTER); /* mov */
#endif
}

static void as_call_and_jump (struct call_and_jump *call_and_jump)
{
	call_and_jump->cj_label.label_flags=0;
	call_and_jump->cj_label.label_id=TEXT_LABEL_ID;
#ifdef FUNCTION_LEVEL_LINKING
	call_and_jump->cj_label.label_object_label=code_object_label;
#endif
	call_and_jump->cj_label.label_offset=CURRENT_CODE_OFFSET;

	store_c (0350); /* call */
	store_l (0);
	as_branch_label (call_and_jump->cj_call_label,CALL_RELOCATION);

	store_c (0351); /* jmp */
	store_l (0);
	as_branch_label (&call_and_jump->cj_jump,JUMP_RELOCATION);
}

static void as_check_stack (struct basic_block *block)
{
	if (block->block_a_stack_check_size>0){
		if (block->block_a_stack_check_size<=32)
			as_r_a (0073,A_STACK_POINTER,end_a_stack_label); /* cmp */
		else {
			as_id_r (0215,block->block_a_stack_check_size,A_STACK_POINTER,REGISTER_O0); /* lea */
			as_r_a (0073,REGISTER_O0,end_a_stack_label); /* cmp */
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
			as_id_r (0215,block->block_b_stack_check_size,B_STACK_POINTER,REGISTER_O0); /* lea */
			as_r_a (0073,REGISTER_O0,end_b_stack_label); /* cmp */
		}
		
		store_c (0x0f);
		store_c (0x82); /* jb */
		store_l (0);
		as_branch_label (stack_overflow_label,BRANCH_RELOCATION);
	}
}

static void as_profile_call (struct basic_block *block)
{
	LABEL *profile_label;
	
	as_move_d_r (block->block_profile_function_label,0,REGISTER_A2);
	
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
	store_c (0350); /* call */
	store_l (0);
	as_branch_label (profile_label,CALL_RELOCATION);
}

#ifdef NEW_APPLY
extern LABEL *add_empty_node_labels[];

static void as_apply_update_entry (struct basic_block *block)
{
	int n_node_arguments;

	n_node_arguments=block->block_n_node_arguments;
	if (n_node_arguments<-200){
		store_c (0351); /* jmp */
		store_l (0);
		as_branch_label (block->block_descriptor,LONG_JUMP_RELOCATION);
		store_c (0x90);
		store_c (0x90);
		store_c (0x90);

		if (block->block_ea_label==NULL){
			if (block->block_profile)
				as_profile_call (block);

			store_c (0x90);
			store_c (0x90);
			store_c (0x90);
			store_c (0x90);
			store_c (0x90);
			store_c (0x90);
			store_c (0x90);
			store_c (0x90);
			store_c (0x90);
			store_c (0x90);

			if (!block->block_profile){
				store_c (0x90);
				store_c (0x90);
			}
			return;
		}
		
		n_node_arguments+=300;
	} else
		n_node_arguments+=200;

	if (block->block_profile)
		as_profile_call (block);

	if (n_node_arguments==0){
		store_c (0351); /* jmp */
		store_l (0);
		as_branch_label (block->block_ea_label,LONG_JUMP_RELOCATION);

		store_c (0x90);
		store_c (0x90);
		store_c (0x90);
		store_c (0x90);
		store_c (0x90);
	} else {
		store_c (0350); /* call */
		store_l (0);
		as_branch_label (add_empty_node_labels[n_node_arguments],CALL_RELOCATION);

		store_c (0351); /* jmp */
		store_l (0);
		as_branch_label (block->block_ea_label,LONG_JUMP_RELOCATION);
	}
	
	if (!block->block_profile){
		store_c (0x90);
		store_c (0x90);
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
#if 1
			if (!block->block_profile){
				as_move_l_r (block->block_ea_label,REGISTER_A2);

				store_c (0351);
				store_l (0);
				as_branch_label (eval_upd_labels[n_node_arguments],JUMP_RELOCATION);

				store_c (0x90);
				store_c (0x90);
			} else {
				store_c (0351);
				store_l (-7);
				as_branch_label (eval_upd_labels[n_node_arguments],JUMP_RELOCATION);

				store_c (0x90);
				store_c (0x90);
				store_c (0x90);

				as_move_l_r (block->block_ea_label,REGISTER_D0);
				as_move_l_r (block->block_profile_function_label,REGISTER_A2);

				store_c (0xeb);
				store_c (-20);
			}
#else
			as_move_l_r (eval_upd_labels[n_node_arguments],REGISTER_D0);
			as_move_l_r (block->block_ea_label,REGISTER_A2);

			store_c (0377);
			store_c (0340 | reg_num (REGISTER_D0)); /* jmp d0 */
#endif
		} else {
			as_move_l_r (block->block_ea_label,REGISTER_D0);
		
			store_c (0377);
			store_c (0340 | reg_num (REGISTER_D0)); /* jmp d0 */
		
			store_c (0x90);
			store_c (0x90);
			store_c (0x90);
			store_c (0x90);
			store_c (0x90);
		}
		
		if (block->block_descriptor!=NULL && (block->block_n_node_arguments<0 || parallel_flag || module_info_flag)){
			store_l (0);
			store_label_in_code_section (block->block_descriptor);
		} else
			store_l (0);
	} else
	if (block->block_descriptor!=NULL && (block->block_n_node_arguments<0 || parallel_flag || module_info_flag)){
		store_l (0);
		store_label_in_code_section (block->block_descriptor);
	}
	/* else
		store_l (0);
	*/
	
	if (callgraph_profiling && block->block_n_node_arguments>=0){
		if (block->block_descriptor && block->block_descriptor->label_name!=NULL && !strcmp (block->block_descriptor->label_name,"EMPTY"))
			store_l (0);
		else
			store_l (block->block_n_node_arguments+257);
	} else
		store_l (block->block_n_node_arguments);
}

static void write_code (void)
{
	struct basic_block *block;
	struct call_and_jump *call_and_jump;

#ifdef FUNCTION_LEVEL_LINKING
	if (first_block!=NULL && !first_block->block_begin_module)
		first_block->block_begin_module=1;
#endif
	
	for_l (block,first_block,block_next){
#ifdef FUNCTION_LEVEL_LINKING
		if (block->block_begin_module){
			if (block->block_link_module){
				if (code_object_label!=NULL && CURRENT_CODE_OFFSET!=code_object_label->object_label_offset && block->block_labels){
#ifdef OPTIMISE_BRANCHES
					{
						struct relocation *new_relocation;
						int align;

						new_relocation=fast_memory_allocate_type (struct relocation);
						
						*last_code_relocation_l=new_relocation;
						last_code_relocation_l=&new_relocation->next;
						new_relocation->next=NULL;
						
						align=3 & -(CURRENT_CODE_OFFSET-code_object_label->object_label_offset);						

						U5 (new_relocation,
							relocation_offset=CURRENT_CODE_OFFSET,
							relocation_kind=ALIGN_RELOCATION,
							relocation_align1=align,
							relocation_align2=align,			
							relocation_object_label=code_object_label);
					}
#endif
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
				as_new_code_module();
#endif
				*(struct object_label**)&block->block_last_instruction = code_object_label;
			}
		} else
			*(struct object_label**)&block->block_last_instruction = NULL;
#endif

		if (block->block_n_node_arguments>-100){
#ifndef FUNCTION_LEVEL_LINKING
# ifdef OPTIMISE_BRANCHES
			{
				struct relocation *new_relocation;
				int align;

				new_relocation=fast_memory_allocate_type (struct relocation);
				
				*last_code_relocation_l=new_relocation;
				last_code_relocation_l=&new_relocation->next;
				new_relocation->next=NULL;
				
				align=code_buffer_free & 3;

				U4 (new_relocation,
					relocation_offset=CURRENT_CODE_OFFSET,
					relocation_kind=ALIGN_RELOCATION,
					relocation_align1=align,
					relocation_align2=align);
			}
# endif

			while ((code_buffer_free & 3)!=0)
				store_c (0x90);
#endif

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

#ifdef FUNCTION_LEVEL_LINKING
	call_and_jump=first_call_and_jump;
	while (call_and_jump!=NULL){
		struct object_label *previous_code_object_label;

		as_new_code_module();
		as_call_and_jump (call_and_jump);
		previous_code_object_label=call_and_jump->cj_jump.label_object_label;

		call_and_jump=call_and_jump->cj_next;
		while (call_and_jump!=NULL && call_and_jump->cj_jump.label_object_label==previous_code_object_label){
			as_call_and_jump (call_and_jump);
			call_and_jump=call_and_jump->cj_next;
		}
	}
#else
	for_l (call_and_jump,first_call_and_jump,cj_next)
		as_call_and_jump (call_and_jump);
#endif
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
#endif

static void write_file_header_and_section_headers (void)
{
#ifndef OMF
# ifndef ELF
	int end_section_headers_offset;
	
	write_w (0x014c);
#  ifdef FUNCTION_LEVEL_LINKING
	write_w (n_code_sections+n_data_sections);
	end_section_headers_offset=20+40*(n_code_sections+n_data_sections);
#  else
	write_w (2);
	end_section_headers_offset=100;
#  endif
	write_l (0);
	write_l (end_section_headers_offset+code_buffer_offset+data_buffer_offset+(n_code_relocations+n_data_relocations)*10);
	write_l (n_object_labels);
	write_w (0);
	write_w (0x104);
	
#  ifdef FUNCTION_LEVEL_LINKING
	{
		struct object_label *object_label,*previous_code_object_label;
		int code_offset,code_file_offset,code_relocations_offset;
		struct relocation *code_relocation;

		code_relocation=first_code_relocation;		
		code_offset=0;
		code_file_offset=end_section_headers_offset;
		code_relocations_offset=code_file_offset+code_buffer_offset+data_buffer_offset;

		previous_code_object_label=NULL;

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
					
					write_string_8 (".text");
					
					write_l (0);
					write_l (0);
					write_l (code_section_length);
					write_l (code_file_offset+code_offset);
					
					code_offset+=code_section_length;
					
					write_l (code_relocations_offset);
					write_l (0);
					write_w (n_code_relocations_in_section);
					write_w (0);
					write_l ((3<<20)+0x20);
					
					code_relocations_offset+=10*n_code_relocations_in_section;
				}
				
				previous_code_object_label=object_label;
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
			
			write_string_8 (".text");
			
			write_l (0);
			write_l (0);
			write_l (code_section_length);
			write_l (code_file_offset+code_offset);
						
			write_l (code_relocations_offset);
			write_l (0);
			write_w (n_code_relocations_in_section);
			write_w (0);
			write_l ((3<<20)+0x20);
		}
	}
#  else
	write_string_8 (".text");

	write_l (0);
	write_l (0);
	write_l (code_buffer_offset);
	write_l (end_section_headers_offset);
	write_l (end_section_headers_offset+code_buffer_offset+data_buffer_offset);
	write_l (0);
	write_w (n_code_relocations);
	write_w (0);
	write_l (0x20);
#  endif

#  ifdef FUNCTION_LEVEL_LINKING
	{
		struct object_label *object_label,*previous_data_object_label;
		int data_offset,data_file_offset,data_relocations_offset;
		struct relocation *data_relocation;

		data_relocation=first_data_relocation;		
		data_offset=0;
		data_file_offset=end_section_headers_offset+code_buffer_offset;
		data_relocations_offset=data_file_offset+data_buffer_offset+n_code_relocations*10;

		previous_data_object_label=NULL;

		for_l (object_label,first_object_label,next){
			if (object_label->object_label_kind==DATA_CONTROL_SECTION){
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
					
					write_string_8 (".data");
					
					write_l (0);
					write_l (0);
					write_l (data_section_length);
					write_l (data_file_offset+data_offset);
					
					data_offset+=data_section_length;
					
					write_l (data_relocations_offset);
					write_l (0);
					write_w (n_data_relocations_in_section);
					write_w (0);
					write_l (previous_data_object_label->object_section_align8 ? (4<<20)+0x40 : (3<<20)+0x40);
					
					data_relocations_offset+=10*n_data_relocations_in_section;
				}
				
				previous_data_object_label=object_label;
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
			
			write_string_8 (".data");
			
			write_l (0);
			write_l (0);
			write_l (data_section_length);
			write_l (data_file_offset+data_offset);
						
			write_l (data_relocations_offset);
			write_l (0);
			write_w (n_data_relocations_in_section);
			write_w (0);
			write_l (previous_data_object_label->object_section_align8 ? (4<<20)+0x40 : (3<<20)+0x40);
		}
	}
#  else
	write_string_8 (".data");
	
	write_l (0);
	write_l (0);
	write_l (data_buffer_offset);
	write_l (end_section_headers_offset+code_buffer_offset);
	write_l (end_section_headers_offset+code_buffer_offset+data_buffer_offset+n_code_relocations*10);
	write_l (0);
	write_w (n_data_relocations);
	write_w (0);
	write_l (0x40);
#  endif
# else
	unsigned int offset;
	int n_code_relocation_sections,n_data_relocation_sections;
	int section_strings_size;
	
#  ifdef FUNCTION_LEVEL_LINKING
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
#  endif

	write_l (0x464c457f);
	write_l (0x00010101);
	write_l (0);
	write_l (0);
	write_l (0x00030001);
	write_l (1);
	write_l (0);
	write_l (0);
	write_l (0x34);
	write_l (0);
	write_l (0x00000034);
	write_l (0x00280000);
#  ifdef FUNCTION_LEVEL_LINKING
	write_l (0x00010000 | (n_sections+n_code_relocation_sections+n_data_relocation_sections+4));
#  else
	write_l (0x00010008);
#  endif

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
#  ifdef FUNCTION_LEVEL_LINKING
	offset=0xd4+40*(n_sections+n_code_relocation_sections+n_data_relocation_sections);
#  else
	offset=0x174;
#  endif

	write_l (1);
	write_l (SHT_STRTAB);
	write_l (0);
	write_l (0);
	write_l (offset);
#  ifdef FUNCTION_LEVEL_LINKING
	write_l ((27+section_strings_size+3) & -4);
#  else
	write_l (60);
#  endif
	write_l (0);
	write_l (0);
	write_l (1);
	write_l (0);
#  ifdef FUNCTION_LEVEL_LINKING
	offset+=(27+section_strings_size+3) & -4;
#  else
	offset+=60;
#  endif
#  ifdef FUNCTION_LEVEL_LINKING
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
#  else
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
#  endif

#  ifdef FUNCTION_LEVEL_LINKING
	write_l (11+section_strings_size);
#  else
	write_l (43);
#  endif
	write_l (SHT_SYMTAB);
	write_l (0);
	write_l (0);
	write_l (offset);
#  ifdef FUNCTION_LEVEL_LINKING
	write_l (16*(n_object_labels+n_sections));
	write_l (n_sections+n_code_relocation_sections+n_data_relocation_sections+3);
	write_l (1+n_sections);
#  else
	write_l (16*n_object_labels);
	write_l (7);
	write_l (3);
#  endif
	write_l (4);
	write_l (16);
#  ifdef FUNCTION_LEVEL_LINKING
	offset+=16*(n_object_labels+n_sections);
#else
	offset+=16*n_object_labels;
#endif

#  ifdef FUNCTION_LEVEL_LINKING
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
#  ifdef FUNCTION_LEVEL_LINKING
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
#  else
	write_zstring (".text");
	write_zstring (".data");
	write_zstring (".rel.text");
	write_zstring (".rel.data");
#  endif
	write_zstring (".symtab");
	write_zstring (".strtab");

	if (((27+section_strings_size) & 3)!=0){
		int n;

		n=4-((27+section_strings_size) & 3);
		do {
			write_c (0);
		} while (--n);
	}
# endif
#else
	int this_module_name_length;
	char *p;
	
	this_module_name_length=strlen (this_module_name);

	write_c (0x80);
	write_w (2+this_module_name_length);
	write_c (this_module_name_length);
	for (p=this_module_name; *p!='\0'; ++p)
		write_c (*p);
	write_c (0);
	
	write_c (0x96);
	write_w (1+7+7+5+5+5+1);
	write_c (0);
	write_c (6);
	write_c ('T');
	write_c ('E');
	write_c ('X');
	write_c ('T');
	write_c ('3');
	write_c ('2');
	write_c (6);
	write_c ('D');
	write_c ('A');
	write_c ('T');
	write_c ('A');
	write_c ('3');
	write_c ('2');
	write_c (4);
	write_c ('C');
	write_c ('O');
	write_c ('D');
	write_c ('E');
	write_c (4);
	write_c ('D');
	write_c ('A');
	write_c ('T');
	write_c ('A');
	write_c (4);
	write_c ('F');
	write_c ('L');
	write_c ('A');
	write_c ('T');
	write_c (0);
	
	write_c (0x99);
	write_w (9);
	write_c ((4<<5) | (2<<2) | 1);
	write_l (code_buffer_offset);
	write_c (2);
	write_c (4);
	write_c (1);
	write_c (0);	

	write_c (0x99);
	write_w (9);
	write_c ((4<<5) | (2<<2) | 1);
	write_l (data_buffer_offset);
	write_c (3);
	write_c (5);
	write_c (1);
	write_c (0);
	
	write_c (0x9a);
	write_w (2);
	write_c (6);
	write_c (0);
#endif
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
			case JUMP_RELOCATION:
			case BRANCH_RELOCATION:
				label=relocation->relocation_label;

				if (label->label_id!=TEXT_LABEL_ID)
					break;
				
#ifdef FUNCTION_LEVEL_LINKING
				if (label->label_object_label!=relocation->relocation_object_label)
					break;
#endif
				instruction_offset=relocation->relocation_offset;

				while (instruction_offset >= code_buffer_offset+BUFFER_SIZE){
					object_buffer=object_buffer->next;
					code_buffer_offset+=BUFFER_SIZE;
				}
				
				v=label->label_offset-(instruction_offset-offset_difference);
				if (relocation->relocation_kind==JUMP_RELOCATION)
					--v;
				
				if (instruction_offset-code_buffer_offset<=BUFFER_SIZE-4)
					v += *(LONG*)(object_buffer->data+(instruction_offset-code_buffer_offset));
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
				
					v+= (*p0) | (*p1<<8) | (*p2<<16) | (*p3<<24);
				}
				
				if (v>=-128 && v<=127){
					if (relocation->relocation_kind==JUMP_RELOCATION)
						relocation->relocation_kind=NEW_SHORT_JUMP_RELOCATION;
					else
						relocation->relocation_kind=NEW_SHORT_BRANCH_RELOCATION;
					found_new_short_branch=1;
				}
				
				break;
			case CALL_RELOCATION:
			case LONG_JUMP_RELOCATION:
			case LONG_WORD_RELOCATION:
#ifdef FUNCTION_LEVEL_LINKING
			case DUMMY_BRANCH_RELOCATION:
#endif
				break;
			case SHORT_BRANCH_RELOCATION:
				offset_difference+=4;
				break;
			case SHORT_JUMP_RELOCATION:
				offset_difference+=3;
				break;
			case ALIGN_RELOCATION:
				offset_difference += relocation->relocation_align1-relocation->relocation_align2;
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
				*new_offset_difference_p+=4;
				relocation->relocation_kind=SHORT_BRANCH_RELOCATION;
			case SHORT_BRANCH_RELOCATION:
				*offset_difference_p+=4;
				break;
			case NEW_SHORT_JUMP_RELOCATION:
				*new_offset_difference_p+=3;
				relocation->relocation_kind=SHORT_JUMP_RELOCATION;
			case SHORT_JUMP_RELOCATION:
				*offset_difference_p+=3;
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

#ifdef FUNCTION_LEVEL_LINKING
	struct object_label *object_label;
	
	object_label=first_object_label;
#endif

	relocation=first_code_relocation;
	call_and_jump=first_call_and_jump;
	
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
				
				while (call_and_jump!=NULL && call_and_jump->cj_jump.label_offset<label__offset){
					relocation=calculate_new_label_offset
						(&call_and_jump->cj_jump.label_offset,&offset_difference,&new_offset_difference,relocation);
										
					call_and_jump=call_and_jump->cj_next;
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
				
				while (call_and_jump!=NULL && call_and_jump->cj_jump.label_offset<object_label->object_label_offset){
					relocation=calculate_new_label_offset
						(&call_and_jump->cj_jump.label_offset,&offset_difference,&new_offset_difference,relocation);
										
					call_and_jump=call_and_jump->cj_next;
				}		
				
				relocation=calculate_new_label_offset
								(&object_label->object_label_offset,&offset_difference,&new_offset_difference,relocation);
			}
			object_label=object_label->next;
		}
#endif
	}
	
	for (; call_and_jump!=NULL; call_and_jump=call_and_jump->cj_next)
		relocation=calculate_new_label_offset
			(&call_and_jump->cj_jump.label_offset,&offset_difference,&new_offset_difference,relocation);
			
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
		if (relocation->relocation_kind==NEW_SHORT_BRANCH_RELOCATION)
			relocation->relocation_kind=SHORT_BRANCH_RELOCATION;
		else if (relocation->relocation_kind==NEW_SHORT_JUMP_RELOCATION)
			relocation->relocation_kind=SHORT_JUMP_RELOCATION;
		
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

	source_object_buffer=first_code_buffer;
	destination_object_buffer=first_code_buffer;
	source_offset=0;
	source_buffer_offset=0;
	destination_buffer_offset=0;
	
	offset_difference=0;
		
	relocation_p=&first_code_relocation;
	
	while ((relocation=*relocation_p)!=NULL){
		struct label *label;
		int instruction_offset,branch_opcode;
		LONG v;
		
		switch (relocation->relocation_kind){
			case SHORT_BRANCH_RELOCATION:
				label=relocation->relocation_label;
				instruction_offset=relocation->relocation_offset-2;
				*relocation_p=relocation->next;
				break;
			case SHORT_JUMP_RELOCATION:
				label=relocation->relocation_label;
				instruction_offset=relocation->relocation_offset-1;
				*relocation_p=relocation->next;
				break;
			case CALL_RELOCATION:
			case BRANCH_RELOCATION:
			case JUMP_RELOCATION:
			case LONG_JUMP_RELOCATION:
			case LONG_WORD_RELOCATION:
#ifdef FUNCTION_LEVEL_LINKING
			case DUMMY_BRANCH_RELOCATION:
#endif
				relocation->relocation_offset -= offset_difference;
				relocation_p=&relocation->next;
				continue;
			case ALIGN_RELOCATION:
				instruction_offset=relocation->relocation_offset;
				*relocation_p=relocation->next;
				break;
			default:
				internal_error_in_function ("relocate_short_branches_and_move_code");
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
			
			offset_difference+=old_align-new_align;

			source_buffer_offset+=old_align;
			source_offset+=old_align;

			if (source_buffer_offset>BUFFER_SIZE){
				source_buffer_offset-=BUFFER_SIZE;
				source_object_buffer=source_object_buffer->next;
			}

#if 1
			if (new_align!=0){
				if (destination_buffer_offset==BUFFER_SIZE){
					destination_buffer_offset=0;
					destination_object_buffer=destination_object_buffer->next;
				}
				switch (new_align){
					case 1:
						destination_object_buffer->data[destination_buffer_offset++]=0x90;
						--new_align;
						break;
					case 2:
						destination_object_buffer->data[destination_buffer_offset++]=0213;

						if (destination_buffer_offset==BUFFER_SIZE){
							destination_buffer_offset=0;
							destination_object_buffer=destination_object_buffer->next;
						}
						destination_object_buffer->data[destination_buffer_offset++]=0300 | (reg_num (EBP)<<3) | reg_num (EBP);
						new_align-=2;
						break;
					case 3:
						destination_object_buffer->data[destination_buffer_offset++]=0215;

						if (destination_buffer_offset==BUFFER_SIZE){
							destination_buffer_offset=0;
							destination_object_buffer=destination_object_buffer->next;
						}
						destination_object_buffer->data[destination_buffer_offset++]=0x40 | (reg_num (EBP)<<3) | reg_num (EBP);

						if (destination_buffer_offset==BUFFER_SIZE){
							destination_buffer_offset=0;
							destination_object_buffer=destination_object_buffer->next;
						}
						destination_object_buffer->data[destination_buffer_offset++]=0;
						new_align-=3;
						break;
				}
			}
#else
			while (new_align!=0){
				if (destination_buffer_offset==BUFFER_SIZE){
					destination_buffer_offset=0;
					destination_object_buffer=destination_object_buffer->next;
				}
				destination_object_buffer->data[destination_buffer_offset]=0x90;
				++destination_buffer_offset;
				
				--new_align;
			}
#endif
			continue;
		}

		if (source_buffer_offset>=BUFFER_SIZE){
			source_buffer_offset-=BUFFER_SIZE;
			source_object_buffer=source_object_buffer->next;
		}
		
		if (relocation->relocation_kind==SHORT_JUMP_RELOCATION){
			v=label->label_offset-(instruction_offset+2-offset_difference);
			
			if (source_buffer_offset<=BUFFER_SIZE-5){
				v += *(LONG*)(source_object_buffer->data+(source_buffer_offset+1));
								
			} else {
				unsigned char *p1,*p2,*p3,*p4,*end_buffer;
				
				p1=source_object_buffer->data+(source_buffer_offset+1);
				end_buffer=source_object_buffer->data+BUFFER_SIZE;
				if (p1==end_buffer)
					p1=source_object_buffer->next->data;
				p2=p1+1;
				if (p2==end_buffer)
					p2=source_object_buffer->next->data;
				p3=p2+1;
				if (p3==end_buffer)
					p3=source_object_buffer->next->data;
				p4=p3+1;
				if (p4==end_buffer)
					p4=source_object_buffer->next->data;
			
				v+= (*p1) | (*p2<<8) | (*p3<<16) | (*p4<<24);
			}

			branch_opcode=0xeb;
			
			source_buffer_offset+=5;
			source_offset+=5;		

			offset_difference+=3;
		} else {
			v=label->label_offset-(instruction_offset+2-offset_difference);
			
			if (source_buffer_offset<=BUFFER_SIZE-6){
				v += *(LONG*)(source_object_buffer->data+(source_buffer_offset+2));
								
				branch_opcode=0x70 | (source_object_buffer->data[source_buffer_offset+1] & 0x0f);
			} else {
				unsigned char *p1,*p2,*p3,*p4,*p5,*end_buffer;
				
				p1=source_object_buffer->data+(source_buffer_offset+1);
				end_buffer=source_object_buffer->data+BUFFER_SIZE;
				if (p1==end_buffer)
					p1=source_object_buffer->next->data;
				p2=p1+1;
				if (p2==end_buffer)
					p2=source_object_buffer->next->data;
				p3=p2+1;
				if (p3==end_buffer)
					p3=source_object_buffer->next->data;
				p4=p3+1;
				if (p4==end_buffer)
					p4=source_object_buffer->next->data;
				p5=p4+1;
				if (p5==end_buffer)
					p5=source_object_buffer->next->data;
			
				v+= (*p2) | (*p3<<8) | (*p4<<16) | (*p5<<24);
		
				branch_opcode=0x70 | (*p1 & 0x0f);
			}
						
			source_buffer_offset+=6;
			source_offset+=6;

			offset_difference+=4;
		}

		if (v<-128 || v>127)
			internal_error_in_function ("relocate_short_branches_and_move_code");

		if (source_buffer_offset>BUFFER_SIZE){
			source_buffer_offset-=BUFFER_SIZE;
			source_object_buffer=source_object_buffer->next;
		}
		
		if (destination_buffer_offset==BUFFER_SIZE){
			destination_buffer_offset=0;
			destination_object_buffer=destination_object_buffer->next;
		}
		destination_object_buffer->data[destination_buffer_offset]=branch_opcode;
		++destination_buffer_offset;

		if (destination_buffer_offset==BUFFER_SIZE){
			destination_buffer_offset=0;
			destination_object_buffer=destination_object_buffer->next;
		}
		destination_object_buffer->data[destination_buffer_offset]=v;
		++destination_buffer_offset;
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
			case CALL_RELOCATION:
			case BRANCH_RELOCATION:
			case JUMP_RELOCATION:
			case LONG_JUMP_RELOCATION:
				label=relocation->relocation_label;
				if (label->label_id==TEXT_LABEL_ID){
					instruction_offset=relocation->relocation_offset;

#ifdef FUNCTION_LEVEL_LINKING
					if (label->label_object_label!=relocation->relocation_object_label){
						v=label->label_offset-label->label_object_label->object_label_offset;
# ifdef ELF
						v-=4;
# endif	
						++n_code_relocations;
						relocation_p=&relocation->next;
						break;
					}
#endif
					v=label->label_offset-(instruction_offset+4);
					*relocation_p=relocation->next;
					break;
				} else {
					++n_code_relocations;
					relocation_p=&relocation->next;
#ifdef ELF
					instruction_offset=relocation->relocation_offset;
					v= -4;
					break;
#else
					continue;
#endif
				}
			case LONG_WORD_RELOCATION:
				relocation_p=&relocation->next;
				
				label=relocation->relocation_label;

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

#ifndef OMF
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
				write_c (0);
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
				write_c (0);
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
	write_zstring (".text");
	write_zstring (".data");
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

#define R_ABS 0
#define R_DIR32 6
#define R_PCLONG 20

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
			return label_n+n_sections;
	} else if (label_n==DATA_LABEL_ID){
		label_n=label->label_object_label->object_label_number;
		if (label_n==0)
			return 1+n_code_sections+label->label_object_label->object_label_section_n;
		else
			return label_n+n_sections;
	} else
			return label_n+n_sections;
}
#endif

static void write_code_relocations (void)
{
	struct relocation *relocation;

	for_l (relocation,first_code_relocation,next){
		switch (relocation->relocation_kind){
			case CALL_RELOCATION:
			case BRANCH_RELOCATION:
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
#ifdef ELF
# ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_386_PC32));
# else
				write_l (ELF32_R_INFO (label->label_id,R_386_PC32));
# endif
#else
# ifdef FUNCTION_LEVEL_LINKING
				if (label->label_id==TEXT_LABEL_ID || label->label_id==DATA_LABEL_ID)
					write_l (label->label_object_label->object_label_number);
				else
# endif
				write_l (label->label_id);
				write_w (R_PCLONG);
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
#ifdef ELF
# ifdef FUNCTION_LEVEL_LINKING
				write_l (ELF32_R_INFO (elf_label_number (label),R_386_32));
# else
				write_l (ELF32_R_INFO (label->label_id,R_386_32));
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
#ifdef FUNCTION_LEVEL_LINKING
			case DUMMY_BRANCH_RELOCATION:
			{
				struct label *label;
		
				label=relocation->relocation_label;
				if (label->label_id==-1)
					internal_error_in_function ("write_code_relocations");

				write_l (relocation->relocation_offset - 4);
#ifdef ELF
				write_l (ELF32_R_INFO (elf_label_number (label),R_386_NONE));
#else
				if (label->label_id==TEXT_LABEL_ID || label->label_id==DATA_LABEL_ID)
					write_l (label->label_object_label->object_label_number);
				else
					write_l (label->label_id);
# if 1
				write_w (R_ABS);
# else
				write_w (R_PCLONG);
# endif
#endif
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
				write_l (ELF32_R_INFO (elf_label_number (label),R_386_32));
# else
				write_l (ELF32_R_INFO (label->label_id,R_386_32));
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
#endif

#ifdef OMF
static void write_import_labels (void)
{
	struct object_label *object_label;
	unsigned char record[1024];
	int record_length,label_number;
	
	record_length=0;
	label_number=4;
	
	for_l (object_label,first_object_label,next){
		switch (object_label->object_label_kind){
			case IMPORTED_LABEL:
			{
				int label_length;
				struct label *label;
				char *label_name_p;
				
				label=object_label->object_label_label;

				label_name_p=label->label_name;
#ifdef REMOVE_UNDERSCORE_AT_BEGIN_OF_LABEL
				if (*label_name_p=='_')
					++label_name_p;
#endif		
				label_length = strlen (label_name_p);
				
				if (record_length+label_length+2 >= 1024){
					int n;
		
					write_c (0x8c);
					write_w (record_length+1);
					for (n=0; n<record_length; ++n)
						write_c (record[n]);
					write_c (0);
					
					record_length=0;
				}

				record[record_length++]=label_length;
				while (*label_name_p)
					record[record_length++]=*label_name_p++;
				record[record_length++]=0;					

				object_label->object_label_number=label_number++;
				break;
			}
		}
	}
	
	if (record_length!=0){
		int n;
		
		write_c (0x8c);
		write_w (record_length+1);
		for (n=0; n<record_length; ++n)
			write_c (record[n]);
		write_c (0);
	}
}			

static void write_exported_labels (int label_kind,int segment_index)
{
	struct object_label *object_label;
	unsigned char record[1024];
	int record_length;

	record_length=0;

	for_l (object_label,first_object_label,next){
		if (object_label->object_label_kind==label_kind){
			int label_length;
			char *label_name_p;
			struct label *label;
			unsigned int offset;
			
			label=object_label->object_label_label;
			label_name_p=label->label_name;
#ifdef REMOVE_UNDERSCORE_AT_BEGIN_OF_LABEL
			if (*label_name_p=='_')
				++label_name_p;
#endif		
			label_length=strlen (label_name_p);
			
			if (record_length+label_length+6 > 1021){
				int n;

				write_c (0x91);
				write_w (record_length+3);
				write_c (1);
				write_c (segment_index);
				for (n=0; n<record_length; ++n)
					write_c (record[n]);
				write_c (0);
				
				record_length=0;
			}

			record[record_length++]=label_length;
			while (*label_name_p)
				record[record_length++]=*label_name_p++;

			offset=label->label_offset;
			record[record_length++]=offset;
			record[record_length++]=offset>>8;
			record[record_length++]=offset>>16;
			record[record_length++]=offset>>24;
			record[record_length++]=0;
		}
	}

	if (record_length>0){
		int n;
	
		write_c (0x91);
		write_w (record_length+3);
		write_c (1);
		write_c (segment_index);
		for (n=0; n<record_length; ++n)
			write_c (record[n]);
		write_c (0);
	}
}
#endif

void assemble_code (void)
{
	as_import_labels (labels);

	write_code();

	if (code_buffer_free & 1)
		store_c (0x90);

	flush_data_buffer();
	flush_code_buffer();

#if defined (OPTIMISE_BRANCHES)
	optimise_branches();
#endif

#ifndef FUNCTION_LEVEL_LINKING
	code_object_label->object_label_length=code_buffer_offset;
	data_object_label->object_label_length=data_buffer_offset;
#endif

	relocate_code();
	relocate_data();

	write_file_header_and_section_headers();

#ifndef OMF
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
#else
	write_import_labels();
	write_exported_labels (EXPORTED_CODE_LABEL,1);
	write_exported_labels (EXPORTED_DATA_LABEL,2);
	
	/* link pass separator */
	write_c (0x88);
	write_w (4);
	write_c (0x40);
	write_c (0xa2);
	write_c (1);
	write_c (0);
	
	write_buffers_and_release_memory (&first_code_buffer,1,first_code_relocation);
	write_buffers_and_release_memory (&first_data_buffer,2,first_data_relocation);

	write_c (0x8a);
	write_w (2);
	write_c (0);
	write_c (0);
#endif
}
