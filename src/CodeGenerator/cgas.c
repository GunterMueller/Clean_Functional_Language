/*
	File:	cgas.c
	Author:	John van Groningen
*/

#include <stdio.h>
#include <string.h>

#define MODULES
#define USE_LABEL_VALUE
/* #define COUNT_RELEASES */
#undef GENERATE_MPW_OBJECT_CODE

#include "cgport.h"

#ifndef G_POWER

#include "cg.h"
#include "cgrconst.h"
#include "cgtypes.h"
#include "cgiconst.h"
#include "cgcode.h"
#include "cginstructions.h"
#include "cgas.h"

#define for_all(v,l,n) for(v=(l);v!=NULL;v=v->n)

extern LABEL *index_error_label;

#pragma segment Code5

enum {
	LBEGIN=1,
	LEND,
	LIMPORT,
	LLABEL,
	LCODE,
	LDATA,
	LREFERENCE,
	LUDATA,
	LC_REFERENCE,
	LLABEL_VALUE,
	LCOMMENT,
	LMODULE
};

#define LLABEL_TEXT		0
#define LLABEL_DATA		1
#define LLABEL_EXTERN	2
#define LLABEL_OFFSET	4

#define REFERENCE_PC		16
#define REFERENCE_OFFSET	8
#define REFERENCE_A5		4
#define REFERENCE_LONG		2
#define REFERENCE_DATA		1

#define LCR_WORD	2
#define LCR_BYTE	0
#define LCR_OFFSET	8

FILE *output_file;

#ifdef THINK_C
#	define IO_BUFFER_SIZE 16384
#else
#	define IO_BUFFER_SIZE 8192
#endif

struct object_buffer {
	struct object_buffer *next;
	int size;
	unsigned char data [IO_BUFFER_SIZE];
};

static struct object_buffer *first_buffer,*current_buffer;

static int buffer_free;
static unsigned char *buffer_p;

static void initialize_object_buffers (VOID)
{
	struct object_buffer *new_buffer;
	
	new_buffer=(struct object_buffer*)memory_allocate (sizeof (struct object_buffer));
	
	new_buffer->size=0;
	new_buffer->next=NULL;
	
	first_buffer=new_buffer;
	current_buffer=new_buffer;
	
	buffer_free=IO_BUFFER_SIZE;
	buffer_p=new_buffer->data;
}

static void write_c (int c)
{
	if (buffer_free>0){
		--buffer_free;
		*buffer_p++=c;
	} else {
		struct object_buffer *new_buffer;

		current_buffer->size=IO_BUFFER_SIZE;
	
		new_buffer=(struct object_buffer*)memory_allocate (sizeof (struct object_buffer));
	
		new_buffer->size=0;
		new_buffer->next=NULL;
	
		current_buffer->next=new_buffer;
		current_buffer=new_buffer;
	
		buffer_free=IO_BUFFER_SIZE-1;
		buffer_p=new_buffer->data;

		*buffer_p++=c;
	}
}

static void flush_object_buffer (VOID)
{
	current_buffer->size=IO_BUFFER_SIZE-buffer_free;
}

/* object optimizer */

static struct object_buffer *s_buffer,*d_buffer;
static int s_free,d_free;
static unsigned char *s_buffer_p,*d_buffer_p;

static int s_read (VOID)
{
	while (s_free==0){
		s_buffer=s_buffer->next;
		if (s_buffer==NULL)
			internal_error_in_function ("s_read");
		s_free=s_buffer->size;
		s_buffer_p=s_buffer->data;
	}
	
	--s_free;
	return *s_buffer_p++;
}

static void d_write (int c)
{
	while (d_free==0){
		d_buffer=d_buffer->next;
		if (d_buffer==NULL)
			internal_error_in_function ("d_write");
		d_free=d_buffer->size;
		d_buffer_p=d_buffer->data;
	}
	
	--d_free;
	*d_buffer_p++=c;
}

static void optimize_buffers (VOID)
{	
	int c;

	s_buffer=d_buffer=first_buffer;
	s_free=d_free=first_buffer->size;
	s_buffer_p=d_buffer_p=first_buffer->data;
	
	c=s_read();

	for (;;){
		d_write (c);
		switch (c){
			case LCODE:
			{
				int size,n,t;
				unsigned char buffer[256];
	
				n=0;			
				size=s_read();
				for (;;){
					t=size;
					while (t--)
						buffer[n++]=s_read();
					if (size & 1)
						s_read();
					c=s_read();
					if (c!=LCODE)
						break;
					else {
						size=s_read();
						if (size+n>=256){
							t=n;
							d_write (t);
							for (n=0; n<t; ++n)
								d_write (buffer[n]);
							if (t & 1)
								d_write (0);
							d_write (LCODE);
							n=0;
						}
					}
				}
				t=n;
				d_write (t);
				for (n=0; n<t; ++n)
					d_write (buffer[n]);
				if (t & 1)
					d_write (0);
				continue;
			}
			case LDATA:
			{
				int size;
				
				size=s_read();
				d_write (size);
				if (size & 1)
					d_write (s_read());
				while (size--)
					d_write (s_read());
				c=s_read();
				continue;
			}
			case LUDATA:
				d_write (s_read());
				d_write (s_read());
				c=s_read();
				continue;
			case LLABEL_VALUE:
				d_write (s_read());
				d_write (s_read());
				d_write (s_read());
				c=s_read();
				continue;
			case LREFERENCE:
			{
				int flags;
				
				flags=s_read();
				d_write (flags);
				d_write (s_read());
				d_write (s_read());
				if (flags & REFERENCE_OFFSET){
					d_write (s_read());
					d_write (s_read());
				}
				c=s_read();
				continue;
			}
			case LC_REFERENCE:
			{
				int flags;
				
				flags=s_read();
				d_write (flags);
				d_write (s_read());
				d_write (s_read());
				d_write (s_read());
				d_write (s_read());
				if (flags & LCR_OFFSET){
					d_write (s_read());
					d_write (s_read());
				}
				c=s_read();
				continue;
			}
			case LLABEL:
			{	
				int flags;
				
				flags=s_read();
				d_write (flags);
				d_write (s_read());
				d_write (s_read());
				if (flags & LLABEL_OFFSET){
					d_write (s_read());
					d_write (s_read());
				}
				if (flags & LLABEL_EXTERN){
					int size;

					size=s_read();
					d_write (size);
					if (!(size & 1))
						d_write (s_read());
					while (size--)
						d_write (s_read());
				}
				c=s_read();
				continue;
			}
			case LIMPORT:
			{
				int size;
				
				d_write (s_read());
				d_write (s_read());
				d_write (s_read());
				size=s_read();
				d_write (size);
				if (!(size & 1))
					d_write (s_read());
				while (size--)
					d_write (s_read());
				c=s_read();
				continue;
			}
			case LMODULE:
				d_write (s_read());
				c=s_read();
				continue;
			case LBEGIN:
				d_write (s_read());
				d_write (s_read());
				d_write (s_read());
				c=s_read();
				continue;
			case LEND:
				d_write (s_read());
				break;
			default:
				internal_error_in_function ("optimize_buffers");
		}
		break;
	}
	
	d_buffer->size-=d_free;
	
	{
		struct object_buffer *buffer,*next_buffer;

		for (buffer=d_buffer->next; buffer!=NULL; buffer=next_buffer){
			next_buffer=buffer->next;

			memory_free (buffer);
		}
	}
	
	d_buffer->next=NULL;
}

/* end object optimizer */

#ifdef GENERATE_MPW_OBJECT_CODE
/* mpw object conversion */

static int c_read (VOID)
{
	while (s_free==0){
		struct object_buffer *old_buffer;

		old_buffer=s_buffer;
		s_buffer=s_buffer->next;

		memory_free (old_buffer);

		if (s_buffer==NULL)
			internal_error_in_function ("c_read");
		s_free=s_buffer->size;
		s_buffer_p=s_buffer->data;
	}
	
	--s_free;
	return *s_buffer_p++;
}

static void c_write (int c)
{
	if (d_free==0){
		struct object_buffer *new_buffer;

		d_buffer->size=IO_BUFFER_SIZE;
	
		new_buffer=(struct object_buffer*)memory_allocate (sizeof (struct object_buffer));
		new_buffer->size=0;
		new_buffer->next=NULL;
		
		d_buffer->next=new_buffer;
		d_buffer=new_buffer;

		d_free=IO_BUFFER_SIZE;
		d_buffer_p=d_buffer->data;
	}
	
	--d_free;
	*d_buffer_p++=c;
}

enum { 
	O_FIRST=1,
	O_LAST,
	O_COMMENT,
	O_DICTIONARY,
	O_MODULE,
	O_ENTRY,
	O_SIZE,
	O_CONTENTS,
	O_REFERENCE,
	O_C_REFERENCE
};

static void convert_to_mpw_object_code (VOID)
{
	struct object_buffer *first_d_buffer;
	int c,code_module_id,data_module_id,segment_id;
	long code_offset,data_offset;

	first_d_buffer=(struct object_buffer*)memory_allocate (sizeof (struct object_buffer));
	first_d_buffer->size=0;
	first_d_buffer->next=NULL;

	d_buffer=first_d_buffer;
	d_free=IO_BUFFER_SIZE;
	d_buffer_p=d_buffer->data;

	s_buffer=first_buffer;
	s_free=first_buffer->size;
	s_buffer_p=first_buffer->data;
	
	segment_id=next_label_id++;
	code_module_id=next_label_id++;
	data_module_id=next_label_id++;

	code_offset=-1;
	data_offset=-1;
	
	c=c_read();

	for (;;){
		switch (c){
			case LCODE:
			{
				int size,n,t;
				unsigned char buffer[256];

				c_write (O_CONTENTS);
				c_write (8);
	
				n=0;			

				size=c_read();
				c_write ((size+8)>>8);
				c_write (size+8);

				c_write (code_offset>>24);
				c_write (code_offset>>16);
				c_write (code_offset>>8);
				c_write (code_offset);

				code_offset+=size;

				t=size;
				while (t--)
					buffer[n++]=c_read();
				if (size & 1)
					c_read();
				
				t=n;
				for (n=0; n<t; ++n)
					c_write (buffer[n]);
				if (t & 1)
					c_write (0);
				
				c=c_read();
				continue;
			}
			case LDATA:
			{
				int size;

				c_write (O_CONTENTS);
				c_write (9);

				size=c_read();
				c_write ((size+8)>>8);
				c_write (size+8);
				
				c_write (data_offset>>24);
				c_write (data_offset>>16);
				c_write (data_offset>>8);
				c_write (data_offset);
				
				data_offset+=size;
				
				if (size & 1)
					c_write (c_read());
				while (size--)
					c_write (c_read());
				c=c_read();
				continue;
			}
			case LUDATA:
				internal_error_in_function ("convert_to_mpw_object_code");
				break;
			case LLABEL_VALUE:
			{
				int flags,id_h,id_l;
				
				flags=c_read();
				id_h=c_read();
				id_l=c_read();

				if (flags & (REFERENCE_PC | REFERENCE_OFFSET))
					internal_error_in_function ("convert_to_mpw_object_code");

				if (flags & REFERENCE_LONG){
					if (flags & REFERENCE_DATA){
						c_write (O_CONTENTS);
						c_write (9);
						
						c_write (0);
						c_write (4+8);
	
						c_write (data_offset>>24);
						c_write (data_offset>>16);
						c_write (data_offset>>8);
						c_write (data_offset);
					} else {
						c_write (O_CONTENTS);
						c_write (8);
						
						c_write (0);
						c_write (4+8);
						
						c_write (code_offset>>24);
						c_write (code_offset>>16);
						c_write (code_offset>>8);
						c_write (code_offset);
					}
					c_write (0);					
					c_write (0);					
					c_write (0);					
					c_write (0);					
				} else {
					if (flags & REFERENCE_DATA){
						c_write (O_CONTENTS);
						c_write (9);
						
						c_write (0);
						c_write (2+8);
	
						c_write (data_offset>>24);
						c_write (data_offset>>16);
						c_write (data_offset>>8);
						c_write (data_offset);
					} else {
						c_write (O_CONTENTS);
						c_write (8);
						
						c_write (0);
						c_write (2+8);
						
						c_write (code_offset>>24);
						c_write (code_offset>>16);
						c_write (code_offset>>8);
						c_write (code_offset);
					}
					c_write (0);					
					c_write (0);					
				}
					
				c_write (O_REFERENCE);
				c_write ( (flags & REFERENCE_A5 ? 128 : 0)
						| (flags & REFERENCE_LONG ? 0 : 16)
						| (flags & REFERENCE_DATA ? 1 : 0));

				c_write (0);
				c_write (8);

				c_write (id_h);
				c_write (id_l);

				if (flags & REFERENCE_DATA){
					c_write (data_offset>>8);
					c_write (data_offset);

					if (flags & REFERENCE_LONG)
						data_offset+=4;
					else
						data_offset+=2;
				} else {
					c_write (code_offset>>8);
					c_write (code_offset);
					
					if (flags & REFERENCE_LONG)
						code_offset+=4;
					else
						code_offset+=2;
				}
				
				c=c_read();
				continue;
			}
			case LREFERENCE:
			{
				int flags;

				flags=c_read();

				c_write (O_REFERENCE);
				c_write ( (flags & REFERENCE_A5 ? 128 : 0)
						| (flags & REFERENCE_LONG ? 0 : 16)
						| (flags & REFERENCE_DATA ? 1 : 0));

				c_write (0);
				c_write (8);

				c_write (c_read());
				c_write (c_read());

				if (flags & REFERENCE_DATA){
					c_write (data_offset>>8);
					c_write (data_offset);
				} else {
					c_write (code_offset>>8);
					c_write (code_offset);
				}

				if (flags & REFERENCE_OFFSET)
					internal_error_in_function ("convert_to_mpw_object_code");

				c=c_read();
				continue;
			}
			case LC_REFERENCE:
			{
				int flags;

				flags=c_read();

				c_write (O_C_REFERENCE);
				c_write ((flags & LCR_WORD ? 16 : 0) | (flags & LCR_BYTE ? 32 : 0));
				
				c_write (0);
				c_write (10);
				
				c_write (c_read());
				c_write (c_read());

				c_write (c_read());
				c_write (c_read());
				if (flags & LCR_OFFSET)
					internal_error_in_function ("convert_to_mpw_object_code");

				c_write (code_offset>>8);
				c_write (code_offset);

				c=c_read();
				continue;
			}
			case LLABEL:
			{	
				int flags,id_h,id_l;
				
				flags=c_read();
				id_h=c_read();
				id_l=c_read();

				if (flags & LLABEL_EXTERN){
					int size;

					size=c_read();

					c_write (O_DICTIONARY);
					c_write (0);
					
					c_write (0);
					c_write (size+7);
					
					c_write (id_h);
					c_write (id_l);
				
					c_write (size);
					if (!(size & 1))
						c_write (c_read());
					while (size--)
						c_write (c_read());
				}

				c_write (O_ENTRY);
				c_write ((flags & LLABEL_DATA ? 1 : 0) | (flags & LLABEL_EXTERN ? 8 : 0));

				c_write (id_h);
				c_write (id_l);

				if (flags & LLABEL_DATA){
					c_write (data_offset>>24);
					c_write (data_offset>>16);
					c_write (data_offset>>8);
					c_write (data_offset);
				} else {
					c_write (code_offset>>24);
					c_write (code_offset>>16);
					c_write (code_offset>>8);
					c_write (code_offset);
				}

				if (flags & LLABEL_OFFSET)
					internal_error_in_function ("convert_to_mpw_object_code");

				c=c_read();
				continue;
			}
			case LIMPORT:
			{
				int size,id_l,id_h;

				c_read();

				id_h=c_read();
				id_l=c_read();
				size=c_read();
		
				c_write (O_DICTIONARY);
				c_write (0);
				
				c_write (0);
				c_write (size+7);
				
				c_write (id_h);
				c_write (id_l);
			
				c_write (size);
			
				if (!(size & 1))
					c_write (c_read());
				while (size--)
					c_write (c_read());

				c=c_read();
				continue;
			}
			case LMODULE:
			{
				int flag;
				
				flag=c_read();

				if (code_offset!=0){
					c_write (O_MODULE);
					c_write (0);
	
					c_write (code_module_id>>8);
					c_write (code_module_id);
					code_module_id=next_label_id++;
					
					c_write (segment_id>>8);
					c_write (segment_id);
					
					code_offset=0;
				}

				if (data_offset!=0){
					c_write (O_MODULE);
					c_write (1);
	
					c_write (data_module_id>>8);
					c_write (data_module_id);
					data_module_id=next_label_id++;
					
					c_write (0);
					c_write (0);
					
					data_offset=0;
				}
				c=c_read();
				continue;
			}
			case LBEGIN:
				c_read();
				c_read();
				c_read();
				
				c_write (O_FIRST);
				c_write (1);
				c_write (0);
				c_write (2);
				
				c_write (O_DICTIONARY);
				c_write (0);
				
				c_write (0);
				c_write (7+1);
				
				c_write (segment_id>>8);
				c_write (segment_id);
			
				c_write (1);
				c_write ('m');

				c=c_read();
				continue;
			case LEND:
				c_read();
				c_write (O_LAST);
				c_write (0);
				break;
			default:
				internal_error_in_function ("convert_to_mpw_object_code");
		}
		break;
	}
	
 	d_buffer->size=IO_BUFFER_SIZE-d_free;
	d_buffer->next=NULL;

	{
		struct object_buffer *buffer,*next_buffer;

		for (buffer=s_buffer; buffer!=NULL; buffer=next_buffer){
			next_buffer=buffer->next;

			memory_free (buffer);
		}
	}	

	first_buffer=first_d_buffer;
}

/* end mpw object conversion */
#endif

static void write_object_buffers_and_release_memory (VOID)
{
	struct object_buffer *buffer,*next_buffer;
	
	for (buffer=first_buffer; buffer!=NULL; buffer=next_buffer){
		int size;
		
		size=buffer->size;
		
		if (fwrite (buffer->data,1,size,output_file)!=size)
			error ("Write error");
		
		next_buffer=buffer->next;
		
		memory_free (buffer);
	}
	
	first_buffer=NULL;
}

/* #define write_c(c) putc((c),output_file) */

static void write_w (UWORD i)
{
	write_c (i>>8);
	write_c (i);
}

static void write_l (register ULONG i)
{
	write_c (i>>24);
	write_c (i>>16);
	write_c (i>>8);
	write_c (i);
}

static void write_block (void *buffer,int length)
{
	char *p;
	
	if (length){
		p=(char*)buffer;
		do
			write_c (*p++);
		while (--length);
	}
	/*
	if (fwrite (buffer,1,length,output_file)!=length)
		error ("Write error");
	*/
}

static void write_s (char string[])
{
	int length;

	length=strlen (string);
	if (length>255)
		length=255;
		
	write_c (length);
	write_block (string,length);
	if (!(length & 1))
		write_c (0);
}

#ifdef MODULES
void start_new_module (int flag)
{
	write_c (LMODULE);
	write_c (flag);
}
#endif

static void import_label (int id,char label_name[])
{
	write_c (LIMPORT);
	write_c (0);
	write_w (id);
	write_s (label_name);	
}

void define_local_label (int id,int flag)
{
	write_c (LLABEL);
	write_c (flag);
	write_w (id);
}

static void define_local_text_label (int id)
{
	write_c (LLABEL);
	write_c (LLABEL_TEXT);
	write_w (id);
}

void define_external_label (int id,int flag,char label_name[])
{
	write_c (LLABEL);
	write_c (flag | LLABEL_EXTERN);
	write_w (id);
	write_s (label_name);
}

void store_word_in_data_section (UWORD i)
{
	write_c (LDATA);
	write_c (2);
	write_w (i);
}

void store_long_word_in_data_section (ULONG i)
{
	write_c (LDATA);
	write_c (4);
	write_l (i);
}

void store_label_in_data_section (int label_id)
{
#ifdef USE_LABEL_VALUE
	write_c (LLABEL_VALUE);
	write_c (REFERENCE_LONG | REFERENCE_DATA);
	write_w (label_id);
#else
	write_c (LREFERENCE);
	write_c (REFERENCE_LONG | REFERENCE_DATA);
	write_w (label_id);
	write_c (LDATA);
	write_c (4);
	write_l (0);
#endif
}

void store_descriptor_in_code_section (int label_id)
{
	write_c (LLABEL_VALUE);
	write_c (REFERENCE_A5 | REFERENCE_LONG);
	write_w (label_id);
}

void store_descriptor_in_data_section (int label_id)
{
	write_c (LLABEL_VALUE);
	write_c (REFERENCE_DATA | REFERENCE_A5 | REFERENCE_LONG);
	write_w (label_id);
}

void store_label_offset_in_data_section (int label_id)
{
#ifdef USE_LABEL_VALUE
	write_c (LLABEL_VALUE);
	write_c (REFERENCE_DATA | REFERENCE_A5);
	write_w (label_id);
#else
	write_c (LREFERENCE);
	write_c (REFERENCE_DATA | REFERENCE_A5);
	write_w (label_id);
	write_c (LDATA);
	write_c (2);
	write_w (0);
#endif
}

void store_label_offset_in_code_section (int label_id)
{
#ifdef USE_LABEL_VALUE
	write_c (LLABEL_VALUE);
	write_c (REFERENCE_A5);
	write_w (label_id);
#else
	write_c (LREFERENCE);
	write_c (REFERENCE_A5);
	write_w (label_id);
	write_c (LCODE);
	write_c (2);
	write_w (0);
#endif
}

static void store_text_label_in_text_section (LABEL *label)
{
	if (label->label_id<0)
		label->label_id=next_label_id++;

#ifdef USE_LABEL_VALUE
	write_c (LLABEL_VALUE);
	write_c (0);	
	write_w (label->label_id);
#else
	write_c (LREFERENCE);
	write_c (0);	
	write_w (label->label_id);
	write_c (LCODE);
	write_c (2);
	write_w (0);
#endif
}

void store_c_string_in_data_section (char *string,int length)
{
	int t_length;
	
/*	t_length=(length+1+1) & ~1; */
	t_length=(length+1+3) & ~3;
	
	if (t_length+1>255)
		internal_error ("String too long in 'store_c_string_in_data_section'");
	
	write_c (LDATA);
	write_c (t_length);
	write_block (string,length);
	write_c (0);
/*
	if (!(length & 1))
		write_c (0);
*/
	while (++length,length<t_length)
		write_c (0);		
}

void store_abc_string_in_data_section (char *string,int length)
{
	int t_length=(length+4+3) & ~3;

	if (t_length>255)
		internal_error ("String too long in 'store_abc_string_in_data_section'");
	
	write_c (LDATA);
	write_c (t_length);
	write_l (length);
	write_block (string,length);
	while (length & 3){
		write_c (0);
		++length;
	}
}

void store_c_string_in_code_section (char *string,int length)
{
	int t_length=(length+1+1) & ~1;
	
	if (t_length+1>255)
		internal_error ("String too long in 'store_c_string_in_code_section'");
	
	write_c (LCODE);
	write_c (t_length);
	write_block (string,length);
	write_c (0);
	if (!(length & 1))
		write_c (0);
}

void store_abc_string_in_code_section (char *string,int length)
{
	int t_length=(length+4+3) & ~3;

	if (t_length>255)
		internal_error ("String too long in 'store_abc_string_in_code_section'");

	write_c (LCODE);
	write_c (t_length);
	write_l (length);
	write_block (string,length);
	while (length & 3){
		write_c (0);
		++length;
	}
}

static void write_number_of_arguments (int number_of_arguments)
{
	write_c (LCODE);
	write_c (2);
	write_w (number_of_arguments);
}

void store_descriptor_string_in_code_section
	(char *string,int length,int string_code_label_id,LABEL *string_label)
{
	int t_length;
	
	t_length=(length+4+3) & ~3;
	
	if (t_length>255)
		internal_error ("String too long in 'store_descriptor_string_in_code_section'");
		
	write_c (LLABEL);
	write_c (LLABEL_TEXT);
	write_w (string_code_label_id);

	write_c (LCODE);
	write_c (6);

	write_w (040772);		/* LEA 4+2(PC),A0 */
	write_w (4);
	write_w (0x4e75);		/* RTS */

	write_c (LMODULE);
	write_c (1);

	write_c (LLABEL);
	write_c (LLABEL_TEXT);
	write_w (string_label->label_id);

	write_c (LCODE);
	write_c (t_length);

	write_l (length);
	write_block (string,length);
	while (length & 3){
		write_c (0);
		++length;
	}
}

static WORD write_indirect_node_entry_jump (LABEL *label)
{
	register int new_label_id;
		
	new_label_id=next_label_id++;
	
	if (label->label_flags & EA_LABEL){
		int label_arity;
		extern LABEL *eval_upd_labels[],*eval_fill_label;
		LABEL *eval_upd_label;

		label_arity=label->label_arity;
		
		if (label_arity<-2)
			label_arity=1;
		
		if (label_arity>=0 && label->label_ea_label!=eval_fill_label){
			write_c (LCODE);
			write_c (2);
			write_w (042700);
	
			write_c (LLABEL_VALUE);
			write_c (0);
			if (label->label_ea_label->label_id<0)
				label->label_ea_label->label_id=next_label_id++;
			write_w (label->label_ea_label->label_id);
	
			write_c (LCODE);
			write_c (2);
			write_w (047300);
	
			write_c (LLABEL_VALUE);
			write_c (0);
			eval_upd_label=eval_upd_labels[label_arity];
			if (eval_upd_label->label_id<0)
				eval_upd_label->label_id=next_label_id++;
			write_w (eval_upd_label->label_id);
		} else {
			write_c (LCODE);
			write_c (2);
			write_w (047300);
	
			write_c (LLABEL_VALUE);
			write_c (0);
			if (label->label_ea_label->label_id<0)
				label->label_ea_label->label_id=next_label_id++;
			write_w (label->label_ea_label->label_id);
			
			write_c (LCODE);
			write_c (4);
			write_w (0x4e71);
			write_w (0x4e71);
		}

		if (label->label_arity<0 || parallel_flag){
			LABEL *descriptor_label;

			descriptor_label=label->label_descriptor;

			if (descriptor_label->label_id<0)
				descriptor_label->label_id=next_label_id++;

			store_label_offset_in_code_section (descriptor_label->label_id);
		} else
			write_number_of_arguments (0);
	} else
		if (label->label_arity<0 || parallel_flag){
			LABEL *descriptor_label;

			descriptor_label=label->label_descriptor;

			if (descriptor_label->label_id<0)
				descriptor_label->label_id=next_label_id++;

			store_label_offset_in_code_section (descriptor_label->label_id);
		}

	write_number_of_arguments (label->label_arity);
	
	define_local_text_label (new_label_id);
	
	write_w ((LCODE<<8)+2);
	write_w (047300);
	
#ifdef USE_LABEL_VALUE
	write_w (LLABEL_VALUE<<8);
	write_w (label->label_id);
#else
	write_w (LREFERENCE<<8);
	write_w (label->label_id);
			
	write_w ((LCODE<<8)+2);
	write_w (0);
#endif
	
	return new_label_id;
}

static void write_indirect_defered_jump (LABEL *label)
{
	LABEL *node_label;

	if (EMPTY_label->label_id<0)
		EMPTY_label->label_id=next_label_id++;
	store_label_offset_in_code_section (EMPTY_label->label_id);

	write_number_of_arguments (label->label_arity);
	
	if (label->label_id<0)
		label->label_id=next_label_id++;
	define_local_text_label (label->label_id);
	
	write_w ((LCODE<<8)+2);
	write_w (047300);

	node_label=label->label_descriptor;
	if (node_label->label_id<0)
		node_label->label_id=next_label_id++;
#ifdef USE_LABEL_VALUE
	write_w (LLABEL_VALUE<<8);
	write_w (node_label->label_id);
#else
	write_w (LREFERENCE<<8);
	write_w (node_label->label_id);
			
	write_w ((LCODE<<8)+2);
	write_w (0);
#endif
}

#ifdef COUNT_RELEASES
static int node_entry_count_label_id;
#endif

static void import_labels (register struct label_node *label_node)
{
	register LABEL *label;
	
	if (label_node==NULL)
		return;
	
	label=&label_node->label_node_label;
	
	if (!(label->label_flags & LOCAL_LABEL) && label->label_number==0){
		if (label->label_id<0)
			label->label_id=next_label_id++;
		import_label (label->label_id,label->label_name);
		if (label->label_flags & NODE_ENTRY_LABEL){
#ifdef MODULES
			start_new_module (0);
#endif
			label->label_id=write_indirect_node_entry_jump (label);
		}
	}
	
	import_labels (label_node->label_node_left);
	import_labels (label_node->label_node_right);
}

static void write_indirect_jumps_for_defer_labels (void)
{
	struct local_label *local_label;
	
	for (local_label=local_labels; local_label!=NULL; local_label=local_label->local_label_next){
		LABEL *label;
		
		label=&local_label->local_label_label;
		if (label->label_flags & DEFERED_LABEL){
#ifdef MODULES
			start_new_module (0);
#endif
			write_indirect_defered_jump (label);
		}
	}
}

static void write_labels (register struct block_label *labels)
{
	for (; labels!=NULL; labels=labels->block_label_next)
		if (labels->block_label_label->label_number==0){
			register LABEL *label;
			register int id;
			
			label=labels->block_label_label;
			id=label->label_id;
			if (id<0){
				id=next_label_id++;
				label->label_id=id;
			}
			
			if (label->label_flags & EXPORT_LABEL)
				define_external_label (id,LLABEL_TEXT,label->label_name);
			else
				define_local_text_label (id);
		}
}

enum { SIZE_LONG, SIZE_WORD, SIZE_BYTE };

static void as_addressing_mode_instruction (struct parameter *parameter,int opcode,int size_flag)
{
	UWORD buffer[10],*code_buf_p,*end_buf_p;
	
	code_buf_p=buffer;
	end_buf_p=code_buf_p;
	*end_buf_p++=(LCODE<<8)+2;
	++end_buf_p;
	
	switch (parameter->parameter_type){
		case P_REGISTER:
		{
			int reg=parameter->parameter_data.reg.r;
			if (is_d_register (reg))
				opcode |= 000 | d_reg_num (reg);
			else
				opcode |= 010 | a_reg_num (reg);
			break;
		}
		case P_INDIRECT:
		{
			int offset=parameter->parameter_offset;
			if (offset==0){
				opcode |= 020 | a_reg_num (parameter->parameter_data.reg.r);
			} else {
				opcode |= 050 | a_reg_num (parameter->parameter_data.reg.r);
				((UBYTE*)code_buf_p)[1]+=2;
				*end_buf_p++ = offset;
			}
			break;
		}
		case P_POST_INCREMENT:
			opcode |= 030 | a_reg_num (parameter->parameter_data.reg.r);
			break;
		case P_PRE_DECREMENT:
			opcode |= 040 | a_reg_num (parameter->parameter_data.reg.r);
			break;
		case P_LABEL:
		{
			LABEL *label;
			
			opcode |= 055;
			
			label=parameter->parameter_data.l;
			if (label->label_id<0)
				label->label_id=next_label_id++;
#ifdef USE_LABEL_VALUE
			*end_buf_p++=(LLABEL_VALUE<<8)+REFERENCE_A5;
			*end_buf_p++=label->label_id;
#else
			*end_buf_p++=(LREFERENCE<<8)+REFERENCE_A5;
			*end_buf_p++=label->label_id;

			*end_buf_p++=(LCODE<<8)+2;
			*end_buf_p++=0;
#endif
			break;
		}
		case P_DESCRIPTOR_NUMBER:
		{
			LABEL *label;
			
			opcode |= 074;
			
			if (size_flag==SIZE_LONG){
				((UBYTE*)code_buf_p)[1]+=2;
				*end_buf_p++=0xffff;
			}
			
			label=parameter->parameter_data.l;
			if (label->label_id<0)
				label->label_id=next_label_id++;

#ifdef USE_LABEL_VALUE
			if (parameter->parameter_offset==0){
				*end_buf_p++=(LLABEL_VALUE<<8)+REFERENCE_A5;
				*end_buf_p++=label->label_id;		
			} else {
#endif
			*end_buf_p++=(LREFERENCE<<8)+REFERENCE_A5;
			*end_buf_p++=label->label_id;
			
			code_buf_p=end_buf_p;
			*end_buf_p++=(LCODE<<8)+2;
			*end_buf_p++=parameter->parameter_offset << 2;
#ifdef USE_LABEL_VALUE
			}
#endif
			break;
		}
		case P_IMMEDIATE:
			opcode |= 074;
			if (size_flag==SIZE_LONG){
				((UBYTE*)code_buf_p)[1]+=4;
				*(*(ULONG**)&end_buf_p)++ = parameter->parameter_data.i;
			} else {
				((UBYTE*)code_buf_p)[1]+=2;
				*end_buf_p++ = parameter->parameter_data.i;
			}
			break;
/* CHANGED 27-7-92 */
		case P_INDEXED:
		{
			struct index_registers *index_registers;
			int offset;
			
			offset=parameter->parameter_offset;
			index_registers=parameter->parameter_data.ir;
			
			((UBYTE*)code_buf_p)[1]+=2;
			*end_buf_p++ = 0x800 | (d_reg_num (index_registers->d_reg.r)<<12) 
							| ((offset>>2) & 0xff) | ((offset & 3)<<9);
			opcode |= 060 | a_reg_num (index_registers->a_reg.r);
			break;
		}
/* */
		default:
			internal_error_in_function ("as_addressing_mode_instruction");
	}
	
	buffer[1]=opcode;
	write_block (buffer,(UBYTE*)end_buf_p-(UBYTE*)buffer);
}

static void as_immediate_data_alterable_addressing_mode
	(int opcode,UWORD buffer[],UWORD *code_buf_p,UWORD *end_buf_p,struct parameter *parameter)
{
	switch (parameter->parameter_type){
		case P_REGISTER:
		{
			int reg=parameter->parameter_data.reg.r;
			if (is_d_register (reg))
				opcode |= 000 | d_reg_num (reg);
			else
				internal_error_in_function ("as_immediate_data_alterable_addressing mode");
			break;
		}
		case P_INDIRECT:
		{
			int offset=parameter->parameter_offset;
			if (offset==0){
				opcode |= 020 | a_reg_num (parameter->parameter_data.reg.r);
			} else {
#ifdef USE_LABEL_VALUE
				if (code_buf_p==NULL){
					code_buf_p=end_buf_p;
					*end_buf_p++=LCODE<<8;
				}
#endif
				opcode |= 050 | a_reg_num (parameter->parameter_data.reg.r);
				((UBYTE*)code_buf_p)[1]+=2;
				*end_buf_p++ = offset;
			}
			break;
		}
		case P_POST_INCREMENT:
			opcode |= 030 | a_reg_num (parameter->parameter_data.reg.r);
			break;
		case P_PRE_DECREMENT:
			opcode |= 040 | a_reg_num (parameter->parameter_data.reg.r);
			break;
		case P_LABEL:
		{
			LABEL *label;
			
			opcode |= 055;
			
			label=parameter->parameter_data.l;
			if (label->label_id<0)
				label->label_id=next_label_id++;
#ifdef USE_LABEL_VALUE
			*end_buf_p++=(LLABEL_VALUE<<8)+REFERENCE_A5;
			*end_buf_p++=label->label_id;
#else
			*end_buf_p++=(LREFERENCE<<8)+REFERENCE_A5;
			*end_buf_p++=label->label_id;
			
			*end_buf_p++=(LCODE<<8)+2;
			*end_buf_p++=0;
#endif
			break;
		}
/* CHANGED 27-7-92 */
		case P_INDEXED:
		{
			struct index_registers *index_registers;
			int offset;
			
			offset=parameter->parameter_offset;
			index_registers=parameter->parameter_data.ir;
#ifdef USE_LABEL_VALUE
			if (code_buf_p==NULL){
				code_buf_p=end_buf_p;
				*end_buf_p++=LCODE<<8;
			}
#endif
			((UBYTE*)code_buf_p)[1]+=2;
			*end_buf_p++ = 0x800 | (d_reg_num (index_registers->d_reg.r)<<12) 
							| ((offset>>2) & 0xff) | ((offset & 3)<<9);
			opcode |= 060 | a_reg_num (index_registers->a_reg.r);
			break;
		}
/* */
		default:
			internal_error_in_function ("as_immediate_data_alterable_addressing_mode");
	}
	
	buffer[1]=opcode;
	write_block (buffer,(UBYTE*)end_buf_p-(UBYTE*)buffer);
}

static void as_data_addressing_mode (	int opcode,UWORD buffer[],UWORD *code_buf_p,
										UWORD *end_buf_p,struct parameter *parameter,int size_flag)
{
	switch (parameter->parameter_type){
		case P_REGISTER:
		{
			int reg=parameter->parameter_data.reg.r;
			if (is_d_register (reg))
				opcode |= 000 | d_reg_num (reg);
			else
				internal_error_in_function ("as_data_addressing mode");
			break;
		}
		case P_INDIRECT:
		{
			int offset=parameter->parameter_offset;
			if (offset==0){
				opcode |= 020 | a_reg_num (parameter->parameter_data.reg.r);
			} else {
				opcode |= 050 | a_reg_num (parameter->parameter_data.reg.r);
				((UBYTE*)code_buf_p)[1]+=2;
				*end_buf_p++ = offset;
			}
			break;
		}
		case P_POST_INCREMENT:
			opcode |= 030 | a_reg_num (parameter->parameter_data.reg.r);
			break;
		case P_PRE_DECREMENT:
			opcode |= 040 | a_reg_num (parameter->parameter_data.reg.r);
			break;
		case P_LABEL:
		{
			LABEL *label;
			
			opcode |= 055;
			
			label=parameter->parameter_data.l;
			if (label->label_id<0)
				label->label_id=next_label_id++;
#ifdef USE_LABEL_VALUE
			*end_buf_p++=(LLABEL_VALUE<<8)+REFERENCE_A5;
			*end_buf_p++=label->label_id;			
#else
			*end_buf_p++=(LREFERENCE<<8)+REFERENCE_A5;
			*end_buf_p++=label->label_id;
			
			*end_buf_p++=(LCODE<<8)+2;
			*end_buf_p++=0;
#endif
			break;
		}
		case P_DESCRIPTOR_NUMBER:
		{
			LABEL *label;
			
			opcode |= 074;
			
			if (size_flag==SIZE_LONG){
				((UBYTE*)code_buf_p)[1]+=2;
				*end_buf_p++=0xffff;
			}
			
			label=parameter->parameter_data.l;
			if (label->label_id<0)
				label->label_id=next_label_id++;
#ifdef USE_LABEL_VALUE
			if (parameter->parameter_offset==0){
				*end_buf_p++=(LLABEL_VALUE<<8)+REFERENCE_A5;
				*end_buf_p++=label->label_id;
			} else {
#endif
			*end_buf_p++=(LREFERENCE<<8)+REFERENCE_A5;
			*end_buf_p++=label->label_id;
			
			*end_buf_p++=(LCODE<<8)+2;
			*end_buf_p++=parameter->parameter_offset << 2;
#ifdef USE_LABEL_VALUE
			}
#endif
			break;
		}
		case P_IMMEDIATE:
			opcode |= 074;
			if (size_flag==SIZE_LONG){
				((UBYTE*)code_buf_p)[1]+=4;
				*(*(ULONG**)&end_buf_p)++ = parameter->parameter_data.i;
			} else {
				((UBYTE*)code_buf_p)[1]+=2;
				*end_buf_p++ = parameter->parameter_data.i;
			}
			break;
/* CHANGED 27-7-92 */
		case P_INDEXED:
		{
			struct index_registers *index_registers;
			int offset;
			
			offset=parameter->parameter_offset;
			index_registers=parameter->parameter_data.ir;
			
			((UBYTE*)code_buf_p)[1]+=2;
			*end_buf_p++ = 0x800 | (d_reg_num (index_registers->d_reg.r)<<12) 
							| ((offset>>2) & 0xff) | ((offset & 3)<<9);
			opcode |= 060 | a_reg_num (index_registers->a_reg.r);
			break;
		}
/* */
		default:
			internal_error_in_function ("as_data_addressing_mode");
	}
	
	buffer[1]=opcode;
	write_block (buffer,(UBYTE*)end_buf_p-(UBYTE*)buffer);
}

static void as_alterable_memory_addressing_mode_instruction (struct parameter *parameter,int opcode)
{
	UWORD buffer[10],*code_buf_p,*end_buf_p;
	
	code_buf_p=buffer;
	end_buf_p=code_buf_p;
	*end_buf_p++=(LCODE<<8)+2;
	++end_buf_p;
	
	switch (parameter->parameter_type){
		case P_INDIRECT:
		{
			int offset=parameter->parameter_offset;
			if (offset==0){
				opcode |= 020 | a_reg_num (parameter->parameter_data.reg.r);
			} else {
				opcode |= 050 | a_reg_num (parameter->parameter_data.reg.r);
				((UBYTE*)code_buf_p)[1]+=2;
				*end_buf_p++ = offset;
			}
			break;
		}
		case P_POST_INCREMENT:
			opcode |= 030 | a_reg_num (parameter->parameter_data.reg.r);
			break;
		case P_PRE_DECREMENT:
			opcode |= 040 | a_reg_num (parameter->parameter_data.reg.r);
			break;
		case P_LABEL:
		{
			LABEL *label;
			
			opcode |= 055;
			
			label=parameter->parameter_data.l;
			if (label->label_id<0)
				label->label_id=next_label_id++;
#ifdef USE_LABEL_VALUE
			*end_buf_p++=(LLABEL_VALUE<<8)+REFERENCE_A5;
			*end_buf_p++=label->label_id;
#else
			*end_buf_p++=(LREFERENCE<<8)+REFERENCE_A5;
			*end_buf_p++=label->label_id;
			
			code_buf_p=end_buf_p;
			*end_buf_p++=(LCODE<<8)+2;
			*end_buf_p++=0;
#endif
			break;
		}
/* CHANGED 27-7-92 */
		case P_INDEXED:
		{
			struct index_registers *index_registers;
			int offset;
			
			offset=parameter->parameter_offset;
			index_registers=parameter->parameter_data.ir;
			
			((UBYTE*)code_buf_p)[1]+=2;
			*end_buf_p++ = 0x800 | (d_reg_num (index_registers->d_reg.r)<<12) 
							| ((offset>>2) & 0xff) | ((offset & 3)<<9);
			opcode |= 060 | a_reg_num (index_registers->a_reg.r);
			break;
		}
/* */
		default:
			internal_error_in_function ("as_alterable_memory_addressing_mode_instruction");
	}
	
	buffer[1]=opcode;
	write_block (buffer,(UBYTE*)end_buf_p-(UBYTE*)buffer);
}

static void as_control_addressing_mode_instruction (struct parameter *parameter,int opcode)
{
	UWORD buffer[10],*end_buf_p;
	
	end_buf_p=buffer;
	*end_buf_p++=(LCODE<<8)+2;
	
	switch (parameter->parameter_type){
		case P_INDIRECT:
		{
			int offset=parameter->parameter_offset;
			if (offset==0){
				opcode |= 020 | a_reg_num (parameter->parameter_data.reg.r);
				*end_buf_p++=opcode;
			} else {
				opcode |= 050 | a_reg_num (parameter->parameter_data.reg.r);
				*end_buf_p++=opcode;
				((UBYTE*)buffer)[1]+=2;
				*end_buf_p++ = offset;
			}
			break;
		}
		case P_LABEL:
		{
			LABEL *label;
			
			label=parameter->parameter_data.l;
			if (label->label_id<0)
				label->label_id=next_label_id++;
			
			if (label->label_flags & DATA_LABEL){
				opcode |= 055;
				*end_buf_p++=opcode;
#ifdef USE_LABEL_VALUE
				*end_buf_p++=(LLABEL_VALUE<<8)+REFERENCE_A5;
#else
				*end_buf_p++=(LREFERENCE<<8)+REFERENCE_A5;
#endif
			} else {
				*end_buf_p++=opcode;
#ifdef USE_LABEL_VALUE
				*end_buf_p++=(LLABEL_VALUE<<8);
#else
				*end_buf_p++=(LREFERENCE<<8);
#endif
			}
			
			*end_buf_p++=label->label_id;
#ifndef USE_LABEL_VALUE
			*end_buf_p++=(LCODE<<8)+2;
			*end_buf_p++=0;
#endif
			break;
		}
/* CHANGED 27-7-92 */
		case P_INDEXED:
		{
			struct index_registers *index_registers;
			int offset;
			
			offset=parameter->parameter_offset;
			index_registers=parameter->parameter_data.ir;
			opcode |= 060 | a_reg_num (index_registers->a_reg.r);
			
			*end_buf_p++=opcode;
			((UBYTE*)buffer)[1]+=2;
			*end_buf_p++ = 0x800 | (d_reg_num (index_registers->d_reg.r)<<12) 
							| ((offset>>2) & 0xff) | ((offset & 3)<<9);
			break;
		}
/* */
		default:
			internal_error_in_function ("as_control_addressing_mode_instruction");
	}
	
	write_block (buffer,(UBYTE*)end_buf_p-(UBYTE*)buffer);
}

static void as_fp_instruction_p (int opcode,int fp_opcode,struct parameter *parameter)
{
	UWORD buffer[14],*code_buf_p,*end_buf_p;
				
	buffer[0]=(LCODE<<8)+4;
	buffer[2]=fp_opcode;

	code_buf_p=buffer;
	end_buf_p=&buffer[3];

	switch (parameter->parameter_type){
		case P_REGISTER:
		{
			int reg=parameter->parameter_data.reg.r;
			if (is_d_register (reg))
				opcode |= 000 | d_reg_num (reg);
			else
				internal_error_in_function ("as_fp_addressing mode");
			break;
		}
		case P_INDIRECT:
		{
			int offset=parameter->parameter_offset;
			if (offset==0){
				opcode |= 020 | a_reg_num (parameter->parameter_data.reg.r);
			} else {
				opcode |= 050 | a_reg_num (parameter->parameter_data.reg.r);
				((UBYTE*)code_buf_p)[1]+=2;
				*end_buf_p++ = offset;
			}
			break;
		}
		case P_POST_INCREMENT:
			opcode |= 030 | a_reg_num (parameter->parameter_data.reg.r);
			break;
		case P_PRE_DECREMENT:
			opcode |= 040 | a_reg_num (parameter->parameter_data.reg.r);
			break;
		case P_LABEL:
		{
			LABEL *label;
			
			opcode |= 055;
			
			label=parameter->parameter_data.l;
			if (label->label_id<0)
				label->label_id=next_label_id++;
#ifdef USE_LABEL_VALUE
			*end_buf_p++=(LLABEL_VALUE<<8)+REFERENCE_A5;
			*end_buf_p++=label->label_id;
#else
			*end_buf_p++=(LREFERENCE<<8)+REFERENCE_A5;
			*end_buf_p++=label->label_id;
			
			*end_buf_p++=(LCODE<<8)+2;
			*end_buf_p++=0;
#endif
			break;
		}
		case P_F_IMMEDIATE:
		{
			DOUBLE d;
			float f;

			opcode |= 074;
			
			d=*parameter->parameter_data.r;
			f=d;
			if (d==f){
				buffer[2]&=~0x1000;
				((UBYTE*)code_buf_p)[1]+=4;
				*(*(float**)&end_buf_p)++ = f;
			} else {
				((UBYTE*)code_buf_p)[1]+=8;
				*(*(DOUBLE**)&end_buf_p)++ = d;
			}
			break;
		}
		case P_IMMEDIATE:
		{
			opcode |= 074;
			((UBYTE*)code_buf_p)[1]+=4;
			*(*(ULONG**)&end_buf_p)++ = parameter->parameter_data.i;
			break;
		}
/* CHANGED 22-7-92 */
		case P_INDEXED:
		{
			struct index_registers *index_registers;
			int offset;
			
			offset=parameter->parameter_offset;
			index_registers=parameter->parameter_data.ir;
			
			((UBYTE*)code_buf_p)[1]+=2;
			*end_buf_p++ = 0x800 | (d_reg_num (index_registers->d_reg.r)<<12)
							| ((offset>>2) & 0xff) | ((offset & 3)<<9);
			opcode |= 060 | a_reg_num (index_registers->a_reg.r);
			break;
		}
/* */
		default:
			internal_error_in_function ("as_fp_instruction_p");
	}
	
	buffer[1]=opcode;
	write_block (buffer,(UBYTE*)end_buf_p-(UBYTE*)buffer);
}

static void as_move_instruction (register struct instruction *instruction,int size_flag)
{
	register UWORD opcode;
	UWORD buffer[14];
	register UWORD *code_buf_p,*end_buf_p;
	
	code_buf_p=buffer;
	end_buf_p=code_buf_p;
	*end_buf_p++=(LCODE<<8)+2;
	++end_buf_p;
	opcode= size_flag==SIZE_LONG ? 020000 : (size_flag==SIZE_WORD ? 030000 : 010000);
	
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_REGISTER:
		{
			int reg=instruction->instruction_parameters[0].parameter_data.reg.r;
			if (is_d_register (reg))
				opcode |= 000 | d_reg_num (reg);
			else
				opcode |= 010 | a_reg_num (reg);
			break;
		}
		case P_INDIRECT:
		{
			int offset=instruction->instruction_parameters[0].parameter_offset;
			if (offset==0){
				opcode |= 020 | a_reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);
			} else {
				opcode |= 050 | a_reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);
				((UBYTE*)code_buf_p)[1]+=2;
				*end_buf_p++ = offset;
			}
			break;
		}
		case P_POST_INCREMENT:
			opcode |= 030 | a_reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);
			break;
		case P_PRE_DECREMENT:
			opcode |= 040 | a_reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);
			break;
		case P_LABEL:
		{
			LABEL *label;
			
			opcode |= 055;
			
			label=instruction->instruction_parameters[0].parameter_data.l;
			if (label->label_id<0)
				label->label_id=next_label_id++;
#ifdef USE_LABEL_VALUE
			*end_buf_p++=(LLABEL_VALUE<<8)+REFERENCE_A5;
			*end_buf_p++=label->label_id;
			code_buf_p=NULL;
#else
			*end_buf_p++=(LREFERENCE<<8)+REFERENCE_A5;
			*end_buf_p++=label->label_id;
			
			code_buf_p=end_buf_p;
			*end_buf_p++=(LCODE<<8)+2;
			*end_buf_p++=0;
#endif
			break;
		}
		case P_DESCRIPTOR_NUMBER:
		{
			LABEL *label;
			
			opcode |= 074;
			if (size_flag==SIZE_LONG){
				((UBYTE*)code_buf_p)[1]+=2;
				*end_buf_p++=0xffff;
			}
			
			label=instruction->instruction_parameters[0].parameter_data.l;
			if (label->label_id<0)
				label->label_id=next_label_id++;
#ifdef USE_LABEL_VALUE
			if (instruction->instruction_parameters[0].parameter_offset==0){
				*end_buf_p++=(LLABEL_VALUE<<8)+REFERENCE_A5;
				*end_buf_p++=label->label_id;
				code_buf_p=NULL;	
			} else {
#endif
			*end_buf_p++=(LREFERENCE<<8)+REFERENCE_A5;
			*end_buf_p++=label->label_id;
			
			code_buf_p=end_buf_p;
			*end_buf_p++=(LCODE<<8)+2;
			*end_buf_p++=instruction->instruction_parameters[0].parameter_offset << 2;
#ifdef USE_LABEL_VALUE
			}
#endif
			break;
		}
		case P_IMMEDIATE:
		{
			LONG i=instruction->instruction_parameters[0].parameter_data.i;
			
			/* MOVEQ ? */
			if (size_flag==SIZE_LONG && i<128 && i>=-128 
				&& instruction->instruction_parameters[1].parameter_type==P_REGISTER
				&& is_d_register (instruction->instruction_parameters[1].parameter_data.reg.r)){
					write_c (LCODE);
					write_c (2);
					write_c (0x70 | (d_reg_num 
						(instruction->instruction_parameters[1].parameter_data.reg.r)<<1));
					write_c (i);
					return;
			}
			
			/* CLR ? */
			if (i==0 && instruction->instruction_parameters[1].parameter_type!=P_REGISTER){
				buffer[0]=(LCODE<<8)+2;
				opcode=(size_flag==SIZE_LONG) ? 041200 : (size_flag==SIZE_WORD) ? 041100 : 041000 ;
			
				as_data_addressing_mode (opcode,buffer,buffer,&buffer[2],
										 &instruction->instruction_parameters[1],size_flag);
				return;
			}
			
			if (size_flag==SIZE_LONG){
				((UBYTE*)code_buf_p)[1]+=4;
				*(ULONG*)end_buf_p=i;
				end_buf_p+=2;
			} else {
				((UBYTE*)code_buf_p)[1]+=2;
				*end_buf_p++=i;
			}
			opcode |= 074;
			break;
		}
/* CHANGED 22-7-92 */
		case P_INDEXED:
		{
			struct index_registers *index_registers;
			int offset;
			
			offset=instruction->instruction_parameters[0].parameter_offset;
			
			index_registers=instruction->instruction_parameters[0].parameter_data.ir;
			
			((UBYTE*)code_buf_p)[1]+=2;
			*end_buf_p++ = 0x800 | (d_reg_num (index_registers->d_reg.r)<<12) 
							| ((offset>>2) & 0xff) | ((offset & 3)<<9);
			opcode |= 060 | a_reg_num (index_registers->a_reg.r);
			break;
		}
/* */
		default:
			internal_error_in_function ("as_move_instruction");
	}
	
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_REGISTER:
		{
			int reg=instruction->instruction_parameters[1].parameter_data.reg.r;
			if (is_d_register (reg))
				opcode |= 0000 | (d_reg_num (reg)<<9);
			else
				opcode |= 0100 | (a_reg_num (reg)<<9);
			break;
		}
		case P_INDIRECT:
		{
			int offset=instruction->instruction_parameters[1].parameter_offset;
			if (offset==0){
				opcode |= 0200 | 
					(a_reg_num (instruction->instruction_parameters[1].parameter_data.reg.r)<<9);
			} else {
#ifdef USE_LABEL_VALUE
				if (code_buf_p==NULL){
					code_buf_p=end_buf_p;
					*end_buf_p++=LCODE<<8;
				}
#endif
				opcode |= 0500 | 
					(a_reg_num (instruction->instruction_parameters[1].parameter_data.reg.r)<<9);
				((UBYTE*)code_buf_p)[1]+=2;
				*end_buf_p++ = offset;
			}
			break;
		}
		case P_POST_INCREMENT:
			opcode |= 0300 | 
				(a_reg_num (instruction->instruction_parameters[1].parameter_data.reg.r)<<9);
			break;
		case P_PRE_DECREMENT:
			opcode |= 0400 | 
				(a_reg_num (instruction->instruction_parameters[1].parameter_data.reg.r)<<9);
			break;
		case P_LABEL:
		{
			LABEL *label;

			opcode |= 05200;
			
			label=instruction->instruction_parameters[1].parameter_data.l;
			if (label->label_id<0)
				label->label_id=next_label_id++;

#ifdef USE_LABEL_VALUE
			*end_buf_p++=(LLABEL_VALUE<<8)+REFERENCE_A5;
			*end_buf_p++=label->label_id;
#else
			*end_buf_p++=(LREFERENCE<<8)+REFERENCE_A5;
			*end_buf_p++=label->label_id;
			
			*end_buf_p++=(LCODE<<8)+2;
			*end_buf_p++=0;
#endif
			break;
		}
/* CHANGED 22-7-92 */
		case P_INDEXED:
		{
			struct index_registers *index_registers;
			int offset;

#ifdef USE_LABEL_VALUE
			if (code_buf_p==NULL){
				code_buf_p=end_buf_p;
				*end_buf_p++=LCODE<<8;
			}
#endif
			index_registers=instruction->instruction_parameters[1].parameter_data.ir;
			offset=instruction->instruction_parameters[1].parameter_offset;
			
			((UBYTE*)code_buf_p)[1]+=2;
			*end_buf_p++ = 0x800 | (d_reg_num (index_registers->d_reg.r)<<12)
							| ((offset>>2) & 0xff) | ((offset & 3)<<9);
			opcode |= 0600 | (a_reg_num (index_registers->a_reg.r)<<9);
			break;
		}
/* */
		default:
			internal_error_in_function ("as_move_instruction");
	}
	
	buffer[1]=opcode;
	write_block (buffer,(UBYTE*)end_buf_p-(UBYTE*)buffer);
}

static void as_lea_instruction (struct instruction *instruction)
{
	int opcode=040700 | (a_reg_num (instruction->instruction_parameters[1].parameter_data.reg.r)<<9);
	
	if (instruction->instruction_parameters[0].parameter_type==P_LABEL &&
		instruction->instruction_parameters[0].parameter_offset!=0)
	{
		UWORD buffer[10],*end_buf_p;
		LABEL *label;
		
		end_buf_p=buffer;
		*end_buf_p++=(LCODE<<8)+2;
		
		label=instruction->instruction_parameters[0].parameter_data.l;
		if (label->label_id<0)
			label->label_id=next_label_id++;
		
		if (label->label_flags & DATA_LABEL){
			opcode |= 055;
			*end_buf_p++=opcode;
			*end_buf_p++=(LREFERENCE<<8)+REFERENCE_A5;
		} else {
			*end_buf_p++=opcode;
			*end_buf_p++=(LREFERENCE<<8);
		}
		
		*end_buf_p++=label->label_id;
		*end_buf_p++=(LCODE<<8)+2;
		*end_buf_p++=instruction->instruction_parameters[0].parameter_offset;
		
		write_block (buffer,(UBYTE*)end_buf_p-(UBYTE*)buffer);	
	} else
		as_control_addressing_mode_instruction (&instruction->instruction_parameters[0],opcode);
}

static void as_add_instruction (struct instruction *instruction)
{
	int opcode;
	
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		int reg=instruction->instruction_parameters[1].parameter_data.reg.r;

		/* ADDQ, SUBQ or LEA ? */
		if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
			LONG i=instruction->instruction_parameters[0].parameter_data.i;
			
			if (i<=8 && i>=-8 && i!=0){
				write_c (LCODE);
				write_c (2);
				if (i>0)
					opcode=050200 | ((i & 7) << 9);
				else
					opcode=050600 | ((-i & 7) << 9);
				if (is_d_register (reg))
					opcode |= d_reg_num (reg);
				else
					opcode |= 010 | a_reg_num (reg);
				write_w (opcode);
				return;
			} else if (is_a_register (reg) && i>=-32768 && i<32768){
				write_c (LCODE);
				write_c (4);
				write_w (040750 | a_reg_num (reg) | (a_reg_num (reg)<<9));
				write_w (i);
				return;
			}
		}
		
		if (is_d_register (reg))
			opcode=0150200 + (d_reg_num (reg)<<9);
		else
			opcode=0150700 + (a_reg_num (reg)<<9);
			
		as_addressing_mode_instruction (&instruction->instruction_parameters[0],opcode,SIZE_LONG);
	} else if (instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
		is_d_register (instruction->instruction_parameters[0].parameter_data.reg.r)){
			opcode=0150600 + 
				(d_reg_num (instruction->instruction_parameters[0].parameter_data.reg.r)<<9);
			as_alterable_memory_addressing_mode_instruction 
				(&instruction->instruction_parameters[1],opcode);
	} else
		/* ADDI not yet implemented */
		internal_error_in_function ("as_add_instruction");
}

static void as_sub_instruction (struct instruction *instruction)
{
	int opcode;
	
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		int reg=instruction->instruction_parameters[1].parameter_data.reg.r;
		
		/* SUBQ, ADDQ or LEA ? */
		if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE){
			LONG i=instruction->instruction_parameters[0].parameter_data.i;
			
			if (i<=8 && i>=-8 && i!=0){
				write_c (LCODE);
				write_c (2);
				if (i>0)
					opcode=050600 | ((i & 7) << 9);
				else
					opcode=050200 | ((-i & 7) << 9);
				if (is_d_register (reg))
					opcode |= d_reg_num (reg);
				else
					opcode |= 010 | a_reg_num (reg);
				write_w (opcode);
				return;
			} else if (is_a_register (reg) && i>-32768 && i<=32768){
				write_c (LCODE);
				write_c (4);
				write_w (040750 | a_reg_num (reg) | (a_reg_num (reg)<<9));
				write_w (-i);
				return;
			}

		}
		
		if (is_d_register (reg))
			opcode=0110200 + (d_reg_num (reg)<<9);
		else
			opcode=0110700 + (a_reg_num (reg)<<9);
			
		as_addressing_mode_instruction (&instruction->instruction_parameters[0],opcode,SIZE_LONG);
	} else if (instruction->instruction_parameters[0].parameter_type==P_REGISTER &&
		is_d_register (instruction->instruction_parameters[0].parameter_data.reg.r)){
			opcode=0110600 + 
				(d_reg_num (instruction->instruction_parameters[0].parameter_data.reg.r)<<9);
			as_alterable_memory_addressing_mode_instruction 
				(&instruction->instruction_parameters[1],opcode);
	} else
		/* SUBI not yet implemented */
		internal_error_in_function ("as_sub_instruction");
}

static void as_and_or_instruction (struct instruction *instruction,int opcode)
{
	UWORD buffer[14];
	int reg;
	
	if (instruction->instruction_parameters[1].parameter_type!=P_REGISTER ||
		is_a_register (reg=instruction->instruction_parameters[1].parameter_data.reg.r))
	{
		internal_error_in_function ("as_and_or_instruction");
		return;
	}
	
	opcode+=d_reg_num (reg)<<9;
							
	buffer[0]=(LCODE<<8)+2;	
	as_data_addressing_mode (opcode,buffer,buffer,&buffer[2],
							&instruction->instruction_parameters[0],SIZE_LONG);
}

static void as_eor_instruction (struct instruction *instruction)
{
	int reg_1,reg_2;
	
	if (instruction->instruction_parameters[1].parameter_type!=P_REGISTER ||
		is_a_register (reg_2=instruction->instruction_parameters[1].parameter_data.reg.r))
	{
		internal_error_in_function ("as_eor_instruction");
		return;
	}
	
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_IMMEDIATE:
		{
			long m=instruction->instruction_parameters[0].parameter_data.i;
			
			if (m==-1){	/* replace EOR #-1,Dn by NOT Dn */
				write_c (LCODE);
				write_c (2);
				write_w (043200 | d_reg_num (reg_2));
			} else {
				write_c (LCODE);
				write_c (6);
				write_w (005200 | d_reg_num (reg_2));
				write_l (m);
			}
			return;
		}
		case P_REGISTER:
			if (is_d_register (reg_1=instruction->instruction_parameters[0].parameter_data.reg.r)){
				write_c (LCODE);
				write_c (2);
				write_w (0130600 | (d_reg_num (reg_1)<<9) | d_reg_num (reg_2));
				return;
			}
		default:
			internal_error_in_function ("as_eor_instruction");
	}
}

static void as_cmp_instruction (struct instruction *instruction,int size_flag)
{
	int opcode;
	
	if (instruction->instruction_parameters[1].parameter_type==P_REGISTER){
		int reg=instruction->instruction_parameters[1].parameter_data.reg.r;
		
		if (is_d_register (reg)){
			if (instruction->instruction_parameters[0].parameter_type==P_IMMEDIATE &&
				instruction->instruction_parameters[0].parameter_data.i==0){
				/* CMPI #0 becomes TST */
				write_c (LCODE);
				write_c (2);
				write_w ((size_flag==SIZE_LONG ? 045200 : 045100) | d_reg_num (reg));
				return;
			}
			opcode=0130200 + (d_reg_num (reg)<<9);
		} else
			opcode=0130700 + (a_reg_num (reg)<<9);
	
		as_addressing_mode_instruction (&instruction->instruction_parameters[0],opcode,size_flag);
	} else 
		switch (instruction->instruction_parameters[0].parameter_type){
			case P_IMMEDIATE:
			{
				UWORD buffer[14],*end_buf_p,opcode;
				LONG i;
				
				i=instruction->instruction_parameters[0].parameter_data.i;
				
				if (i==0){
					/* CMPI #0 becomes TST */
					buffer[0]=(LCODE<<8)+2;
					opcode= size_flag==SIZE_LONG ? 045200 : 045100;
					as_immediate_data_alterable_addressing_mode
						(opcode,buffer,buffer,&buffer[2],&instruction->instruction_parameters[1]);
				} else {
					if (size_flag==SIZE_LONG){
						buffer[0]=(LCODE<<8)+6;
						*(ULONG*)(&buffer[2])=i;
						end_buf_p=&buffer[4];
						opcode=06200;
					} else {
						buffer[0]=(LCODE<<8)+4;
						buffer[2]=i;
						end_buf_p=&buffer[3];
						opcode=06100;
					}
					as_immediate_data_alterable_addressing_mode
						(opcode,buffer,buffer,end_buf_p,&instruction->instruction_parameters[1]);
				}
				break;
			}
			case P_DESCRIPTOR_NUMBER:
			{
				UWORD buffer[14],*end_buf_p,*code_buf_p,opcode;
				LABEL *label;
			
				buffer[0]=(LCODE<<8)+2;
				code_buf_p=buffer;
				end_buf_p=&buffer[2];
				
				if (size_flag==SIZE_LONG){
					((UBYTE*)code_buf_p)[1]+=2;
					*end_buf_p++=0xffff;
					opcode=06200;
				} else
					opcode=06100;
				
				label=instruction->instruction_parameters[0].parameter_data.l;
				if (label->label_id<0)
					label->label_id=next_label_id++;
#ifdef USE_LABEL_VALUE
				if (instruction->instruction_parameters[0].parameter_offset==0){
					*end_buf_p++=(LLABEL_VALUE<<8)+REFERENCE_A5;
					*end_buf_p++=label->label_id;
					code_buf_p=NULL;
				} else {
#endif
				*end_buf_p++=(LREFERENCE<<8)+REFERENCE_A5;
				*end_buf_p++=label->label_id;
			
				code_buf_p=end_buf_p;
				*end_buf_p++=(LCODE<<8)+2;
				*end_buf_p++=instruction->instruction_parameters[0].parameter_offset << 2;
#ifdef USE_LABEL_VALUE
				}
#endif
				as_immediate_data_alterable_addressing_mode
					(opcode,buffer,code_buf_p,end_buf_p,&instruction->instruction_parameters[1]);
				break;
			}
			default:
				internal_error_in_function ("as_cmp_instruction");
		}
}

static void as_tst_instruction (struct instruction *instruction,int size_flag)
{
	UWORD buffer[14],opcode;
							
	buffer[0]=(LCODE<<8)+2;
	opcode=045200;
			
	as_data_addressing_mode (opcode,buffer,buffer,&buffer[2],
							&instruction->instruction_parameters[0],size_flag);
}

static void as_branch_instruction (struct instruction *instruction,int opcode)
{
	UWORD buffer[10];
	register UWORD *buf_p;
	LABEL *label;
	
	if (instruction->instruction_parameters[0].parameter_type!=P_LABEL)
		internal_error_in_function ("as_branch_instruction");
		
	label=instruction->instruction_parameters[0].parameter_data.l;
	if (label->label_id<0)
		label->label_id=next_label_id++;
	
	buf_p=buffer;
	*buf_p++=(LCODE<<8)+2;
	*buf_p++=opcode;

#if defined (USE_LABEL_VALUE) && !defined (GENERATE_MPW_OBJECT_CODE)
	*buf_p++=(LLABEL_VALUE<<8)+REFERENCE_PC;
	*buf_p++=label->label_id;
#else
	{
	int id;

	id=next_label_id++;
	*buf_p++=(LLABEL<<8);
	*buf_p++=id;
	*buf_p++=(LC_REFERENCE<<8)+LCR_WORD;
	*buf_p++=label->label_id;
	*buf_p++=id;
	*buf_p++=(LCODE<<8)+2;
	*buf_p++=0;
	}
#endif
	write_block (buffer,(UBYTE*)buf_p-(UBYTE*)buffer);
}

static void as_short_branch_instruction (struct instruction *instruction,int opcode)
{
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_LABEL:
		{
			LABEL *label;
			UWORD buffer[10],*buf_p;
			int id;
			
			label=instruction->instruction_parameters[0].parameter_data.l;
			if (label->label_id<0)
				label->label_id=next_label_id++;
		
			id=next_label_id++;
			
			buf_p=buffer;
			*buf_p++=(LCODE<<8)+1;
			*buf_p++=opcode;
		
			*buf_p++=(LC_REFERENCE<<8)+LCR_BYTE;
			*buf_p++=label->label_id;
			*buf_p++=id;
		
			*buf_p++=(LCODE<<8)+1;
			*buf_p++=0;
		
			*buf_p++=(LLABEL<<8);
			*buf_p++=id;
		
			write_block (buffer,(UBYTE*)buf_p-(UBYTE*)buffer);
			return;
		}
		case P_IMMEDIATE:
		{
			int offset;
			
			offset=instruction->instruction_parameters[0].parameter_data.i;
					
			write_w ((LCODE<<8)+2);
			write_w (opcode+offset);
			return;
		}
		default:
			internal_error_in_function ("as_short_branch_instruction");
	}		
}

static void as_movem_instruction (struct instruction *instruction)
{
	UWORD opcode,register_list;
	UWORD buffer[10],*code_buf_p,*end_buf_p;
	register unsigned int n,arity;
	
	code_buf_p=buffer;
	end_buf_p=code_buf_p;
	*end_buf_p++=(LCODE<<8)+4;
	++end_buf_p;
	++end_buf_p;
	opcode=046300;
	
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_INDIRECT:
		{
			int offset=instruction->instruction_parameters[0].parameter_offset;
			if (offset==0){
				opcode |= 020 | a_reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);
			} else {
				opcode |= 050 | a_reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);
				((UBYTE*)code_buf_p)[1]+=2;
				*end_buf_p++ = offset;
			}
			break;
		}
		case P_POST_INCREMENT:
			opcode |= 030 | a_reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);
			break;
		case P_LABEL:
		{
			LABEL *label;
			
			opcode |= 055;
			
			label=instruction->instruction_parameters[0].parameter_data.l;
			if (label->label_id<0)
				label->label_id=next_label_id++;
#ifdef USE_LABEL_VALUE
			*end_buf_p++=(LLABEL_VALUE<<8)+REFERENCE_A5;
			*end_buf_p++=label->label_id;
#else
			*end_buf_p++=(LREFERENCE<<8)+REFERENCE_A5;
			*end_buf_p++=label->label_id;
			
			*end_buf_p++=(LCODE<<8)+2;
			*end_buf_p++=0;
#endif
			break;
		}
		case P_REGISTER:
		{
			int offset,reg;
			
			arity=instruction->instruction_arity;
		
			if (instruction->instruction_parameters[arity-1].parameter_type==P_PRE_DECREMENT){
				opcode = 044340 | a_reg_num (instruction->instruction_parameters[arity-1].parameter_data.reg.r);

				register_list=0;
				--arity;
				for (n=0; n<arity; ++n){
					register int reg;
					
					reg=instruction->instruction_parameters[n].parameter_data.reg.r;
					if (is_d_register (reg))
						register_list |= ((unsigned)0x8000>>d_reg_num (reg));
					else
						register_list |= ((unsigned)0x8000>>8+a_reg_num (reg));
				}
				
				buffer[1]=opcode;
				buffer[2]=register_list;
				write_block (buffer,(UBYTE*)end_buf_p-(UBYTE*)buffer);
				return;
			}
						
			if (instruction->instruction_arity!=2 
					|| instruction->instruction_parameters[1].parameter_type!=P_INDIRECT)
				internal_error_in_function ("as_movem_instruction");

			opcode=044300;
			offset=instruction->instruction_parameters[1].parameter_offset;
			if (offset==0){
				opcode |= 020 | a_reg_num (instruction->instruction_parameters[1].parameter_data.reg.r);
			} else {
				opcode |= 050 | a_reg_num (instruction->instruction_parameters[1].parameter_data.reg.r);
				((UBYTE*)code_buf_p)[1]+=2;
				*end_buf_p++ = offset;
			}
			
			reg=instruction->instruction_parameters[0].parameter_data.reg.r;
			if (is_d_register (reg))
				register_list = ((unsigned)1<<d_reg_num (reg));
			else
				register_list = ((unsigned)1<<8+a_reg_num (reg));
			
			buffer[1]=opcode;
			buffer[2]=register_list;
			write_block (buffer,(UBYTE*)end_buf_p-(UBYTE*)buffer);
			return;
		}
		default:
			internal_error_in_function ("as_movem_instruction");
	}
	
	register_list=0;
	
	arity=instruction->instruction_arity;
	for (n=1; n<arity; ++n){
		register int reg;
		
		reg=instruction->instruction_parameters[n].parameter_data.reg.r;
		if (is_d_register (reg))
			register_list |= ((unsigned)1<<d_reg_num (reg));
		else
			register_list |= ((unsigned)1<<8+a_reg_num (reg));
	}
	
	buffer[1]=opcode;
	buffer[2]=register_list;
	write_block (buffer,(UBYTE*)end_buf_p-(UBYTE*)buffer);
}

static void as_shift_instruction (struct instruction *instruction,int opcode)
{
	int reg_1,reg_2;
	
	if (instruction->instruction_parameters[1].parameter_type!=P_REGISTER ||
		!is_d_register (reg_2=instruction->instruction_parameters[1].parameter_data.reg.r))
	{
		internal_error_in_function ("as_shift_instruction");
		return;
	}
				
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_IMMEDIATE:
		{
			LONG count;
			
			count=instruction->instruction_parameters[0].parameter_data.i;
		
			if (count<=0 || count>8)
				internal_error_in_function ("as_shift_instruction");
			
			write_c (LCODE);
			write_c (2);
			write_w (opcode | ((count & 7)<<9) | d_reg_num (reg_2));
			return;
		}
		case P_REGISTER:
			if (is_d_register (reg_1=instruction->instruction_parameters[0].parameter_data.reg.r)){
				write_c (LCODE);
				write_c (2);
				write_w (opcode | 040 | (d_reg_num (reg_1)<<9) | d_reg_num (reg_2));
				return;
			}
		default:
			internal_error_in_function ("as_shift_instruction");
	}
}

static void as_mul_instruction (struct instruction *instruction)
{
	UWORD buffer[14],opcode,reg;
							
	buffer[0]=(LCODE<<8)+4;
	reg=instruction->instruction_parameters[1].parameter_data.reg.r;
	buffer[2]=004000 | reg | (reg<<12);
	opcode=046000;
			
	as_data_addressing_mode (opcode,buffer,buffer,&buffer[3],
							&instruction->instruction_parameters[0],SIZE_LONG);
}

static void as_div_instruction (struct instruction *instruction)
{
	UWORD buffer[14],opcode,reg_n;
							
	buffer[0]=(LCODE<<8)+4;
	reg_n=d_reg_num (instruction->instruction_parameters[1].parameter_data.reg.r);
	buffer[2]=004000 | reg_n | (reg_n<<12);
	opcode=046100;
			
	as_data_addressing_mode (opcode,buffer,buffer,&buffer[3],
							&instruction->instruction_parameters[0],SIZE_LONG);
}

static void as_mod_instruction (struct instruction *instruction)
{
	UWORD buffer[14],opcode;
				
				
	buffer[0]=(LCODE<<8)+4;
	buffer[2]=004000 | instruction->instruction_parameters[1].parameter_data.reg.r
						| (instruction->instruction_parameters[2].parameter_data.reg.r<<12);
	opcode=046100;
			
	as_data_addressing_mode (opcode,buffer,buffer,&buffer[3],
							&instruction->instruction_parameters[0],SIZE_LONG);
}

static void as_bmove_instruction (struct instruction *instruction)
{
	UWORD buffer[5],opcode;
	
	buffer[0]=(LCODE<<8)+8;
	buffer[1]=0x6002;			/* BRA.S	*+4 */
	opcode=020000;
	switch (instruction->instruction_parameters[0].parameter_type){
		case P_POST_INCREMENT:
			opcode |= 030 | 
				a_reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);
			break;
		case P_PRE_DECREMENT:
			opcode |= 040 |
				a_reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);
			break;
		default:
			internal_error_in_function ("as_bmove_instruction");
	}
	switch (instruction->instruction_parameters[1].parameter_type){
		case P_POST_INCREMENT:
			opcode |= 0300 |
				(a_reg_num (instruction->instruction_parameters[1].parameter_data.reg.r)<<9);
			break;
		case P_PRE_DECREMENT:
			opcode |= 0400 |
				(a_reg_num (instruction->instruction_parameters[1].parameter_data.reg.r)<<9);
			break;
		default:
			internal_error_in_function ("as_bmove_instruction");
	}
	buffer[2]=opcode;	/* MOVE -(An)+,-(An)+ */
	buffer[3]=0x51c8+d_reg_num (instruction->instruction_parameters[2].parameter_data.reg.r);
	buffer[4]=-4;		/* DBRA Dn,*-2 */
	
	write_block (buffer,10);
}

static void as_exg_instruction (struct instruction *instruction)
{
	int opcode,reg_1,reg_2;
	
	reg_1=instruction->instruction_parameters[0].parameter_data.reg.r;
	reg_2=instruction->instruction_parameters[1].parameter_data.reg.r;
	if (is_d_register (reg_1))
		if (is_d_register (reg_2))
			opcode=0xc140+(d_reg_num (reg_1)<<9)+d_reg_num (reg_2);
		else
			opcode=0xc188+(d_reg_num (reg_1)<<9)+a_reg_num (reg_2);
	else
		if (is_d_register (reg_2))
			opcode=0xc188+(d_reg_num (reg_2)<<9)+a_reg_num (reg_1);
		else
			opcode=0xc148+(a_reg_num (reg_1)<<9)+a_reg_num (reg_2);
	
	write_c (LCODE);
	write_c (2);
	write_w (opcode);
}

static void as_extb_instruction (struct instruction *instruction)
{
	int reg;
	
	reg=d_reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);

	if (!mc68000_flag){
		write_c (LCODE);
		write_c (2);
		write_w (044700 | d_reg_num (reg));
	} else {
		write_c (LCODE);
		write_c (4);
		write_w (044200 | d_reg_num (reg));
		write_w (044300 | d_reg_num (reg));
	}
}

static void as_ext_instruction (struct instruction *instruction)
{
	int reg=d_reg_num (instruction->instruction_parameters[0].parameter_data.reg.r);
	
	write_c (LCODE);
	write_c (2);
	write_w (044300+d_reg_num (reg));
}

static void as_set_condition_instruction (struct instruction *instruction,int opcode)
{
	int reg_1;
	
	if (instruction->instruction_parameters[0].parameter_type!=P_REGISTER ||
		!is_d_register (reg_1=instruction->instruction_parameters[0].parameter_data.reg.r))
	{
		internal_error_in_function ("as_set_condition_instruction");
		return;
	}
	
	if (!mc68000_flag){
		write_c (LCODE);
		write_c (4);
		write_w (opcode | d_reg_num (reg_1));
		write_w (044700 | d_reg_num (reg_1));
	} else {
		write_c (LCODE);
		write_c (6);
		write_w (opcode | d_reg_num (reg_1));
		write_w (044200 | d_reg_num (reg_1));
		write_w (044300 | d_reg_num (reg_1));
	}
}

static void as_fmove_instruction (struct instruction *instruction,int size_mask)
{
	if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
		int reg_1;
		
		reg_1=instruction->instruction_parameters[0].parameter_data.reg.r;
		
		if (instruction->instruction_parameters[1].parameter_type==P_F_REGISTER){
			int reg_2;
			
			reg_2=instruction->instruction_parameters[1].parameter_data.reg.r;
			write_c (LCODE);
			write_c (4);
			write_w (0xf200);
			write_w ((reg_1<<10) | (reg_2<<7));
		} else
			as_fp_instruction_p (0xf200,size_mask | 0x6000 | (reg_1<<7),
								 &instruction->instruction_parameters[1]);
	} else if (instruction->instruction_parameters[1].parameter_type==P_F_REGISTER){
		int reg_1;
		
		reg_1=instruction->instruction_parameters[1].parameter_data.reg.r;
		as_fp_instruction_p (0xf200,size_mask | 0x4000 | (reg_1<<7),
							 &instruction->instruction_parameters[0]);
	} else
		internal_error_in_function ("as_fmove_instruction");
}

static void as_fp_instruction (struct instruction *instruction,int function_code)
{
	int reg_1;
	
	if (instruction->instruction_parameters[1].parameter_type!=P_F_REGISTER){
		internal_error_in_function ("as_fp_instruction");
		return;
	}
	reg_1=instruction->instruction_parameters[1].parameter_data.reg.r;
		
	if (instruction->instruction_parameters[0].parameter_type==P_F_REGISTER){
		int reg_2;
		
		reg_2=instruction->instruction_parameters[0].parameter_data.reg.r;
		
		write_c (LCODE);
		write_c (4);
		write_w (0xf200);
		write_w (function_code | (reg_2<<10) | (reg_1<<7));
	} else
		as_fp_instruction_p (0xf200,function_code | (0x1400 | 0x4000) | (reg_1<<7),
							 &instruction->instruction_parameters[0]);
}

static void as_fp_set_condition_instruction (struct instruction *instruction,int c_code)
{
	as_fp_instruction_p (0171100,c_code,&instruction->instruction_parameters[0]);
	
	if (instruction->instruction_parameters[0].parameter_type==P_REGISTER){
		write_c (LCODE);
		write_c (2);
		write_w (044700 | d_reg_num (instruction->instruction_parameters[0].parameter_data.reg.r));
	}
}

static void as_jsr_schedule (int n_a_and_f_registers)
{
	write_c (LCODE);

	if (n_a_and_f_registers & 15){
		write_c (6);
		write_w (0xf227);
		if ((n_a_and_f_registers & 15)==1)
			write_w (0x6800);
		else
			write_w (0xe000 | (~(-1<<(n_a_and_f_registers & 15))) );
	} else
		write_c (2);

	write_w (047200);
	
	switch (n_a_and_f_registers>>4){
		case 0:		store_text_label_in_text_section (schedule_0_label);	break;
		case 1:		store_text_label_in_text_section (schedule_1_label);	break;
		case 2:		store_text_label_in_text_section (schedule_2_label);	break;
		case 3:		store_text_label_in_text_section (schedule_3_label);	break;
		case 256>>4:store_text_label_in_text_section (schedule_eval_label);	break;
		default:	internal_error_in_function ("as_jsr_schedule");
	}
	
	if (n_a_and_f_registers & 15){
		write_c (LCODE);
		write_c (4);
		write_w (0xf21f);
		if ((n_a_and_f_registers & 15)==1)
			write_w (0x4800);
		else
			write_w (0xd000 | ((0xff>>(n_a_and_f_registers & 15)) ^ 0xff) );
	}	
}

static void as_jmp_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_LABEL
		&& instruction->instruction_parameters[0].parameter_data.l->label_flags & LOCAL_LABEL)
	{
		if (parallel_flag){
			/* DBRA D6, */
			as_branch_instruction (instruction,0x51CE);
			/* JSR schedule */
			as_jsr_schedule (instruction->instruction_parameters[0].parameter_offset);
			/* BRA */
			as_branch_instruction (instruction,0x6000);
		} else
			as_branch_instruction (instruction,0x6000);
	} else {
		if (parallel_flag){
			int n_a_and_f_registers;

			if (instruction->instruction_parameters[0].parameter_type==P_LABEL)
				n_a_and_f_registers=instruction->instruction_parameters[0].parameter_offset;
			else
				n_a_and_f_registers=instruction->instruction_parameters[0].parameter_data.reg.u;

			if (n_a_and_f_registers!=128){
				/* DBRA D6,2+n(PC) */
				write_c (LCODE);
				write_c (4);
				write_w (0x51CE);
				
				if (n_a_and_f_registers & 15)
					write_w (14);
				else
					write_w (6);
				
				as_jsr_schedule (n_a_and_f_registers);
			}
		}
		as_control_addressing_mode_instruction (&instruction->instruction_parameters[0],047300);
	}
}

static void as_jsr_instruction (struct instruction *instruction)
{
	if (instruction->instruction_parameters[0].parameter_type==P_LABEL
		&& instruction->instruction_parameters[0].parameter_data.l->label_flags & LOCAL_LABEL)
	{
		if (parallel_flag){
			int n_a_and_f_registers;
			
			n_a_and_f_registers=instruction->instruction_parameters[0].parameter_offset;
			
			/* PEA 2+n(PC) */
			write_c (LCODE);
			write_c (4);
			write_w (044172);
			
			if (n_a_and_f_registers & 15)
				write_w (22);
			else
				write_w (14);
	
			/* DBRA D6, */
			as_branch_instruction (instruction,0x51CE);
			as_jsr_schedule (n_a_and_f_registers);
			/* BRA */
			as_branch_instruction (instruction,0x6000);
		} else
			as_branch_instruction (instruction,0x6100);
	} else {
		if (parallel_flag){
			int n_a_and_f_registers;

			if (instruction->instruction_parameters[0].parameter_type==P_LABEL)
				n_a_and_f_registers=instruction->instruction_parameters[0].parameter_offset;
			else
				n_a_and_f_registers=instruction->instruction_parameters[0].parameter_data.reg.u;

			/* DBRA D6,2+n(PC) */
			write_c (LCODE);
			write_c (4);
			write_w (0x51CE);
			
			if (n_a_and_f_registers & 15)
				write_w (14);
			else
				write_w (6);
			
			as_jsr_schedule (n_a_and_f_registers);
		}
		as_control_addressing_mode_instruction (&instruction->instruction_parameters[0],047200);
	}
}

struct call_and_jump {
	struct call_and_jump *cj_next;
	WORD cj_label_id;
	WORD cj_call_id;
	WORD cj_jump_id;
};

static struct call_and_jump *first_call_and_jump,*last_call_and_jump;

static void as_garbage_collect_test (register struct basic_block *block)
{
	int n_cells,label_id_1,label_id_2;
	struct call_and_jump *new_call_and_jump;

	label_id_1=next_label_id++;
	label_id_2=next_label_id++;
	
	new_call_and_jump=(struct call_and_jump*)allocate_memory_from_heap (sizeof (struct call_and_jump));
	
	new_call_and_jump->cj_next=NULL;
	new_call_and_jump->cj_label_id=label_id_1;
	new_call_and_jump->cj_jump_id=label_id_2;
	switch (block->block_n_begin_a_parameter_registers){
		case 0:		new_call_and_jump->cj_call_id=collect_0_label->label_id;	break;
		case 1:		new_call_and_jump->cj_call_id=collect_1_label->label_id;	break;
		case 2:		new_call_and_jump->cj_call_id=collect_2_label->label_id;	break;
		case 3:		new_call_and_jump->cj_call_id=collect_3_label->label_id;	break;
		default:	internal_error_in_function ("as_garbage_collect_test");
	}
	
	if (first_call_and_jump!=NULL)
		last_call_and_jump->cj_next=new_call_and_jump;
	else
		first_call_and_jump=new_call_and_jump;
	last_call_and_jump=new_call_and_jump;

	n_cells=block->block_n_new_heap_cells;
	if (n_cells<=8){
		/* SUBQ.L #n,D7 */
		write_c (LCODE);	
		write_c (4);
		write_w (050607+((n_cells & 7)<<9));
	} else if (n_cells<128
				&&	block->block_n_begin_d_parameter_registers <
					(parallel_flag ? N_DATA_PARAMETER_REGISTERS-1 : N_DATA_PARAMETER_REGISTERS))
	{
		write_c (LCODE);
		write_c (6);
		if (parallel_flag){
			/* MOVEQ #n,D5 */
			/* SUB.L D5,D7 */
			write_w (075000+n_cells);
			write_w (0117205);
		} else {
			/* MOVEQ #n,D6 */
			/* SUB.L D6,D7 */
			write_w (076000+n_cells);
			write_w (0117206);
		}
	} else {
		/* SUB.L #n,D7 */
		write_c (LCODE);
		write_c (8);
		write_w (0117274);
		write_l (n_cells);
	}
	
	/* BCS */
	write_c (0x65);
	write_c (0);
#if defined (USE_LABEL_VALUE) && !defined (GENERATE_MPW_OBJECT_CODE)
	write_c (LLABEL_VALUE);
	write_c (REFERENCE_PC);
	write_w (label_id_1);
#else	/* l3 */
	{
	int label_id;

	label_id=next_label_id++;
	define_local_text_label (label_id);
	/* l1 - l3 */
	write_c (LC_REFERENCE);
	write_c (LCR_WORD);
	write_w (label_id_1);
	write_w (label_id);
	write_c (LCODE);
	write_c (2);
	write_w (0);
	}
#endif
	
	/* l2 */
	define_local_text_label (label_id_2);
}

static void as_call_and_jump (struct call_and_jump *call_and_jump)
{
	/* l1 */
	define_local_text_label (call_and_jump->cj_label_id);
	/* JSR collect_n */
	write_c (LCODE);
	write_c (2);
	write_w (047200);
#ifdef USE_LABEL_VALUE
	write_c (LLABEL_VALUE);
#else
	write_c (LREFERENCE);
#endif
	write_c (0);
	write_w (call_and_jump->cj_call_id);
	write_c (LCODE);
#ifdef USE_LABEL_VALUE
	write_c (2);
#else
	write_c (4);
	write_w (0);
#endif
	/* JMP l2 */
	write_w (047300);
#ifdef USE_LABEL_VALUE
	write_c (LLABEL_VALUE);
	write_c (0);
	write_w (call_and_jump->cj_jump_id);
#else
	write_c (LREFERENCE);
	write_c (0);
	write_w (call_and_jump->cj_jump_id);
	write_c (LCODE);
	write_c (2);
	write_w (0);
#endif
}

static int local_stack_overflow_id;

static void init_stack_checking (VOID)
{
	local_stack_overflow_id=next_label_id++;
	define_local_text_label (local_stack_overflow_id);
		
	write_c (LCODE);
	write_c (2);
	write_w (047300);

#ifdef USE_LABEL_VALUE
	write_c (LLABEL_VALUE);
	write_c (0);
	write_w (stack_overflow_label->label_id);
#else
	write_c (LREFERENCE);
	write_c (0);
	write_w (stack_overflow_label->label_id);
	
	write_c (LCODE);
	write_c (2);
	write_w (0);
#endif
}

#define EXTRA_STACK_SPACE 2000 /* 300 */

static void as_check_stack (register struct basic_block *block)
{
	int size,n_d_parameters,n_a_parameters;
	int label_id,label_id_1,label_id_2;

	label_id=next_label_id++;

	if (parallel_flag){
		struct call_and_jump *new_call_and_jump;

		label_id_1=next_label_id++;
		label_id_2=next_label_id++;

		new_call_and_jump=(struct call_and_jump*)allocate_memory_from_heap (sizeof (struct call_and_jump));

		new_call_and_jump->cj_next=NULL;
		new_call_and_jump->cj_label_id=label_id_1;
		new_call_and_jump->cj_jump_id=label_id_2;
		switch (block->block_n_begin_a_parameter_registers){
			case 0:		new_call_and_jump->cj_call_id=realloc_0_label->label_id;	break;
			case 1:		new_call_and_jump->cj_call_id=realloc_1_label->label_id;	break;
			case 2:		new_call_and_jump->cj_call_id=realloc_2_label->label_id;	break;
			case 3:		new_call_and_jump->cj_call_id=realloc_3_label->label_id;	break;
			default:	internal_error_in_function ("as_garbage_collect_test");
		}

		if (first_call_and_jump!=NULL)
			last_call_and_jump->cj_next=new_call_and_jump;
		else
			first_call_and_jump=new_call_and_jump;
		last_call_and_jump=new_call_and_jump;
	}
	
	size=block->block_stack_check_size;
/*	if (parallel_flag) */
		size+=EXTRA_STACK_SPACE;
	n_d_parameters=block->block_n_begin_d_parameter_registers;
	n_a_parameters=block->block_n_begin_a_parameter_registers;
	
	if (size<=4){
		write_c (LCODE);
		write_c (4);
		/* CMPA.L A_STACK_POINTER,B_STACK_POINTER */
		write_w (0130710+a_reg_num (A_STACK_POINTER)+(a_reg_num (B_STACK_POINTER)<<9));
		/* BLS */
		write_w (0x6300);
	} else if (size<=127
			&&	n_d_parameters <
				(parallel_flag ? N_DATA_PARAMETER_REGISTERS-1 : N_DATA_PARAMETER_REGISTERS))
	{
		write_c (LCODE);
		write_c (8);
		if (parallel_flag){
			/* MOVEQ #size,D5 */
			write_w (0x7000+(d_reg_num (REGISTER_D5)<<9)+size);
			/* ADD.L A_STACK_POINTER,D5 */
			write_w (0150210+a_reg_num (A_STACK_POINTER)+(5<<9));
			/* CMP.L B_STACK_POINTER,D5 */
			write_w (0130210+a_reg_num (B_STACK_POINTER)+(5<<9));
		} else {
			/* MOVEQ #size,D6 */
			write_w (0x7000+(d_reg_num (REGISTER_D6)<<9)+size);
			/* ADD.L A_STACK_POINTER,D6 */
			write_w (0150210+a_reg_num (A_STACK_POINTER)+(6<<9));
			/* CMP.L B_STACK_POINTER,D6 */
			write_w (0130210+a_reg_num (B_STACK_POINTER)+(6<<9));		
		}
		/* BHI */
		write_w (0x6200);
	} else if (n_a_parameters<N_ADDRESS_PARAMETER_REGISTERS){
		write_c (LCODE);
		write_c (8);
		/* LEA size(A_STACK_POINTER),A2 */
		write_w (040750 + (2<<9) + a_reg_num (A_STACK_POINTER));
		write_w (size);
		/* CMPA.L B_STACK_POINTER,A2 */
		write_w (0130710+a_reg_num (B_STACK_POINTER)+(2<<9));
		/* BHI */
		write_w (0x6200);
	} else {
		write_c (LCODE);
		write_c (10);
		/* SUBA.L B_STACK_POINTER,A_STACK_POINTER */
		write_w (0110710+a_reg_num (B_STACK_POINTER)+(a_reg_num (A_STACK_POINTER)<<9));
		/* CMPA.W #-size,A_STACK_POINTER */
		write_w (0130374+(a_reg_num (A_STACK_POINTER)<<9));
		write_w (-size);
		/* ADDA.L B_STACK_POINTER,A_STACK_POINTER */
		write_w (0150710+a_reg_num (B_STACK_POINTER)+(a_reg_num (A_STACK_POINTER)<<9));
		/* BGT */
		write_w (0x6E00);
	}
	
	define_local_text_label (label_id);
	
	write_c (LC_REFERENCE);
	write_c (LCR_WORD);
	
	if (!parallel_flag){
		write_w (local_stack_overflow_id);
		write_w (label_id);
		write_c (LCODE);
		write_c (2);
		write_w (0);
	} else {
		write_w (label_id_1);
		write_w (label_id);
		write_c (LCODE);
		write_c (2);
		write_w (0);

		define_local_text_label (label_id_2);
	}
}

static void as_word_instruction (struct instruction *instruction)
{
	write_w ((LCODE<<8)+2);
	write_w ((int)instruction->instruction_parameters[0].parameter_data.i);
}

static void write_instructions (struct instruction *instructions)
{
	register struct instruction *instruction;
	
	for (instruction=instructions; instruction!=NULL; instruction=instruction->instruction_next){
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
			case ISUB:
				as_sub_instruction (instruction);
				break;
			case ICMP:
				as_cmp_instruction (instruction,SIZE_LONG);
				break;
			case ITST:
				as_tst_instruction (instruction,SIZE_LONG);
				break;
			case ITSTB:
				as_tst_instruction (instruction,SIZE_BYTE);
				break;
			case IJMP:
				as_jmp_instruction (instruction);
				break;
			case IJSR:
				as_jsr_instruction (instruction);
				break;
			case IRTS:
#ifdef COUNT_RELEASES
				if (parallel_flag && instruction->instruction_arity){
					write_c (LCODE);
					write_c (2);
					write_w (0x52ad);

					write_c (LLABEL_VALUE);
					write_c (REFERENCE_A5);
					write_w (node_entry_count_label_id);
				}
#endif
				write_w ((LCODE<<8)+2);
				write_w (047165);
				break;
			case IBGE:
				as_branch_instruction (instruction,0x6C00);
				break;
			case IBGT:
				as_branch_instruction (instruction,0x6E00);
				break;
			case IBHS:
				as_branch_instruction (instruction,0x6400);
				break;
			case IBLE:
				as_branch_instruction (instruction,0x6F00);
				break;
			case IBLT:
				as_branch_instruction (instruction,0x6D00);
				break;
			case IBEQ:
				as_branch_instruction (instruction,0x6700);
				break;
			case IBNE:
				as_branch_instruction (instruction,0x6600);
				break;
			case IBMI:
				as_short_branch_instruction (instruction,0x6b00);
				break;
			case IMOVEM:
				as_movem_instruction (instruction);
				break;
			case IMOVEDB:
				as_move_instruction (instruction,SIZE_WORD);
				break;
			case IMOVEB:
				as_move_instruction (instruction,SIZE_BYTE);
				break;
			case ICMPW:
				as_cmp_instruction (instruction,SIZE_WORD);
				break;
			case ILSL:
				as_shift_instruction (instruction,0160610);
				break;
			case ILSR:
				as_shift_instruction (instruction,0160210);
				break;
			case IASR:
				as_shift_instruction (instruction,0160200);
				break;
			case IMUL:
				as_mul_instruction (instruction);
				break;
			case IDIV:
				as_div_instruction (instruction);
				break;
			case IREM:
				as_mod_instruction (instruction);
				break;
			case IBMOVE:
				as_bmove_instruction (instruction);
				break;
			case IEXG:
				as_exg_instruction (instruction);
				break;
			case IAND:
				as_and_or_instruction (instruction,0140200);
				break;
			case IOR:
				as_and_or_instruction (instruction,0100200);
				break;
			case IEOR:
				as_eor_instruction (instruction);
				break;
			case ISEQ:
				as_set_condition_instruction (instruction,0x57c0);
				break;
			case ISGE:
				as_set_condition_instruction (instruction,0x5cc0);
				break;
			case ISGT:
				as_set_condition_instruction (instruction,0x5ec0);
				break;
			case ISLE:
				as_set_condition_instruction (instruction,0x5fc0);
				break;
			case ISLT:
				as_set_condition_instruction (instruction,0x5dc0);
				break;
			case ISNE:
				as_set_condition_instruction (instruction,0x56c0);
				break;	
			case IFMOVE:
				as_fmove_instruction (instruction,0x1400);
				break;
			case IFADD:
				as_fp_instruction (instruction,0x22);
				break;
			case IFSUB:
				as_fp_instruction (instruction,0x28);
				break;
			case IFCMP:
				as_fp_instruction (instruction,0x38);
				break;
			case IFDIV:
				as_fp_instruction (instruction,0x20);
				break;
			case IFMUL:
				as_fp_instruction (instruction,0x23);
				break;
			case IFREM:
				as_fp_instruction (instruction,0x25);
				break;
			case IFBEQ:
				as_branch_instruction (instruction,0xf281);
				break;
			case IFBGE:
				as_branch_instruction (instruction,0xf293);
				break;
			case IFBGT:
				as_branch_instruction (instruction,0xf292);
				break;
			case IFBLE:
				as_branch_instruction (instruction,0xf295);
				break;
			case IFBLT:
				as_branch_instruction (instruction,0xf294);
				break;
			case IFBNE:
				as_branch_instruction (instruction,0xf28e);
				break;
			case IFMOVEL:
				as_fmove_instruction (instruction,0);
				break;
			case IFACOS:
				as_fp_instruction (instruction,0x1c);
				break;
			case IFASIN:
				as_fp_instruction (instruction,0x0c);
				break;
			case IFATAN:
				as_fp_instruction (instruction,0x0a);
				break;
			case IFCOS:
				as_fp_instruction (instruction,0x1d);
				break;
			case IFEXP:
				as_fp_instruction (instruction,0x10);
				break;
			case IFLN:
				as_fp_instruction (instruction,0x14);
				break;
			case IFLOG10:
				as_fp_instruction (instruction,0x15);
				break;
			case IFNEG:
				as_fp_instruction (instruction,0x1a);
				break;
			case IFSIN:
				as_fp_instruction (instruction,0xe);
				break;
			case IFSQRT:
				as_fp_instruction (instruction,4);
				break;
			case IFTAN:
				as_fp_instruction (instruction,0xf);
				break;
			case IFSEQ:
				as_fp_set_condition_instruction (instruction,1);
				break;
			case IFSGE:
				as_fp_set_condition_instruction (instruction,0x13);
				break;
			case IFSGT:
				as_fp_set_condition_instruction (instruction,0x12);
				break;
			case IFSLE:
				as_fp_set_condition_instruction (instruction,0x15);
				break;
			case IFSLT:
				as_fp_set_condition_instruction (instruction,0x14);
				break;
			case IFSNE:
				as_fp_set_condition_instruction (instruction,0xe);
				break;
			case IWORD:
				as_word_instruction (instruction);
				break;
			case ISCHEDULE:
				as_jsr_schedule (instruction->instruction_parameters[0].parameter_data.i);
				break;
			case IEXTB:
				as_extb_instruction (instruction);
				break;
			case IEXT:
				as_ext_instruction (instruction);
				break;
			case IFTST:
			default:
				internal_error_in_function ("write_instructions");
		}
	}
}

static void write_code()
{
	register struct basic_block *block;
	register struct call_and_jump *call_and_jump;

	release_heap();
	
	first_call_and_jump=NULL;

	for_all (block,first_block,block_next){
#ifdef MODULES
		if (block->block_begin_module)
			start_new_module (block->block_link_module != 0);
#endif
		if (block->block_n_node_arguments>-100){
			LABEL *label;
			
			label=block->block_descriptor;

#ifdef CLOSURE_NAMES
			if (label!=NULL && block->block_descriptor_or_string!=0){
				unsigned char *string_p;
				char *string;
				ULONG string_length;
				int length;
				
				string=(char*)block->block_descriptor;
				string_length=strlen (string);
				
				string_p=(unsigned char*)string;
				length=string_length;

				write_c (LCODE);
				write_c ((string_length+7) & ~3);
				
				while (length>=4){
					write_l (*(ULONG*)string_p);
					string_p+=4;
					length-=4;
				}
				
				if (length>0){
					ULONG d;
					int shift;
							
					d=0;
					shift=24;
					while (length>0){
						d |= ((ULONG)string_p[0])<<shift;
						shift-=8;
						--length;
						++string_p;
					}
					write_l (d);
				}
				
				write_l ((string_length<<2) | (string_length<<10) | (string_length<<18) | (string_length<<26) | 0x00010203);
			}
#endif

			if (block->block_ea_label!=NULL){
				int n_node_arguments;
				extern LABEL *eval_fill_label,*eval_upd_labels[];

				n_node_arguments=block->block_n_node_arguments;
				if (n_node_arguments<-2)
					n_node_arguments=1;

				if (n_node_arguments>=0 && block->block_ea_label!=eval_fill_label){
					write_c (LCODE);
					write_c (2);
					write_w (042700);
	
					write_c (LLABEL_VALUE);
					write_c (0);
					if (block->block_ea_label->label_id<0)
						block->block_ea_label->label_id=next_label_id++;
					write_w (block->block_ea_label->label_id);
	
					write_c (LCODE);
					write_c (2);
					write_w (047300);
	
					write_c (LLABEL_VALUE);
					write_c (0);
					write_w (eval_upd_labels[n_node_arguments]->label_id);	
				} else {
					write_c (LCODE);
					write_c (2);
					write_w (047300);
	
					write_c (LLABEL_VALUE);
					write_c (0);
					if (block->block_ea_label->label_id<0)
						block->block_ea_label->label_id=next_label_id++;
					write_w (block->block_ea_label->label_id);
	
					write_c (LCODE);
					write_c (4);
					write_w (0x4e71);
					write_w (0x4e71);
				}
				if (block->block_descriptor!=NULL
					&& (block->block_n_node_arguments<0 || parallel_flag))
				{
					if (label->label_id<0)
						label->label_id=next_label_id++;
					store_label_offset_in_code_section (label->label_id);
				} else
					write_number_of_arguments (0);
			} else
				if (label!=NULL
					&& (block->block_n_node_arguments<0 || parallel_flag))
				{
					if (label->label_id<0)
						label->label_id=next_label_id++;
					store_label_offset_in_code_section (label->label_id);
				} 
				/* else
					write_number_of_arguments (0); */

			write_number_of_arguments (block->block_n_node_arguments);
		}
		
		write_labels (block->block_labels);
		if (block->block_n_new_heap_cells>0)
			as_garbage_collect_test (block);
		if (check_stack && block->block_stack_check_size>0)
			as_check_stack (block);
		write_instructions (block->block_instructions);
	}
	
	for_all (call_and_jump,first_call_and_jump,cj_next)
	{
#ifdef MODULES
		start_new_module (0);
#endif
		as_call_and_jump (call_and_jump);
	}
	
	release_heap();
}

void write_version_and_options (int version,int options)
{
#ifndef GENERATE_MPW_OBJECT_CODE
	putc (LCOMMENT,output_file);
	putc (4,output_file);

	putc (version>>8,output_file);
	putc (version,output_file);

	putc (options>>8,output_file);
	putc (options,output_file);
#endif
}

void write_depend (char *module_name)
{
#ifndef GENERATE_MPW_OBJECT_CODE
	int l,n;
	
	l=strlen (module_name);
	putc (LCOMMENT,output_file);
	putc (l,output_file);
	
	for (n=0; n<l; ++n)
		putc (module_name[n],output_file);

	if (l & 1)
		putc (0,output_file);
#endif
}

void initialize_assembler (FILE *output_file_d)
{
	output_file=output_file_d;

	setvbuf (output_file,NULL,_IOFBF,IO_BUFFER_SIZE);

	initialize_object_buffers();

#ifndef GENERATE_MPW_OBJECT_CODE
	putc (LBEGIN,output_file);
	putc (0,output_file);
	putc (0,output_file);
	putc (0,output_file);
#else
	write_c (LBEGIN);
	write_c (0);
	write_w (0);
#endif

	if (check_stack && !parallel_flag)
		init_stack_checking();
}

void assemble_code ()
{	
	import_labels (labels);

	write_indirect_jumps_for_defer_labels();

#ifdef COUNT_RELEASES
	if (parallel_flag){
		node_entry_count_label_id=next_label_id++;
		import_label (node_entry_count_label_id,"node_entry_count");
	}
#endif

	if (index_error_label!=NULL && !(index_error_label->label_flags & EXPORT_LABEL)){
		int new_index_error_label;
		
		new_index_error_label=next_label_id++;
		define_local_text_label (new_index_error_label);
		
		write_w ((LCODE<<8)+2);
		write_w (047300);
		
		write_w (LLABEL_VALUE<<8);
		write_w (index_error_label->label_id);
		
		index_error_label->label_id=new_index_error_label;
	}

	write_code();
	
	write_c (LEND);
	write_c (0);
	
	flush_object_buffer();
	
	optimize_buffers();

#ifdef GENERATE_MPW_OBJECT_CODE
	convert_to_mpw_object_code();
#endif
	
	write_object_buffers_and_release_memory();

#ifndef GENERATE_MPW_OBJECT_CODE
	fseek (output_file,2l,0);

	putc (next_label_id>>8,output_file);
	putc (next_label_id,output_file);
#endif
}

#endif