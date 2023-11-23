/*
	File:		wfileIO3.c
	Written by:	John van Groningen
	At:			University of Nijmegen
*/

#if defined (_WIN64) && !defined (A64)
# define A64
#endif

#include "wcon.h"

#include <windows.h>
#define HFILE HANDLE
#define ULONG unsigned long
#define OS(w,o) w

#include "wfileIO3.h"

#ifndef FILE_END
# define FILE_END 2
#endif
#ifndef FILE_BEGIN
# define FILE_BEGIN 0
#endif
#ifndef A64
 extern DWORD __attribute__ ((stdcall)) GetFileSize (HANDLE,LPDWORD);
#endif

extern void IO_error (char*);
extern void *allocate_memory (int);
extern void free_memory (void*);

extern int std_input_from_file;
extern int std_output_to_file;
extern HANDLE std_input_handle,std_output_handle,std_error_handle;

#define EOF (-1)

#define MAX_N_FILES 20

#define MAX_FILE_NAME_LENGTH 255

#define FIRST_REAL_FILE 3

#define F_SEEK_SET 0
#define F_SEEK_CUR 1
#define F_SEEK_END 2

struct clean_string {
#ifdef A64
	__int64 length;
#else
	long	length;
#endif
	char	characters[0];
};

#ifndef WINDOWS
static
#endif
struct file file_table[MAX_N_FILES];

static int number_of_files=FIRST_REAL_FILE;

#define is_special_file(f) ((CLEAN_INT)(f)<(CLEAN_INT)(&file_table[FIRST_REAL_FILE]))

static char *clean_to_c_string (struct clean_string *cs)
{
	int l;
	char *cp,*s;

	cp=cs->characters;
	l=cs->length;
	
	s=allocate_memory (l+1);

	if (s!=NULL){
		register char *sp;
		
		for (sp=s; l!=0; --l)
			*sp++=*cp++;
		*sp='\0';
	}
	
	return s;
}

#define FILE_IO_BUFFER_SIZE (4*1024)

#define F_READ_TEXT 0
#define F_WRITE_TEXT 1
#define F_APPEND_TEXT 2
#define F_READ_DATA 3
#define F_WRITE_DATA 4
#define F_APPEND_DATA 5

#define ERROR_FILE ((struct file*)-(size_t)&file_table[2])

static OS(DWORD,ULONG) file_permission[]={
#ifdef WINDOWS
	GENERIC_READ,
	GENERIC_WRITE,
	GENERIC_READ | GENERIC_WRITE,
	GENERIC_READ,
	GENERIC_WRITE,
	GENERIC_READ | GENERIC_WRITE
#else
	OPEN_ACCESS_READONLY | OPEN_SHARE_DENYWRITE,
	OPEN_ACCESS_WRITEONLY | OPEN_SHARE_DENYWRITE,
	OPEN_ACCESS_READWRITE | OPEN_SHARE_DENYWRITE,
	OPEN_ACCESS_READONLY | OPEN_SHARE_DENYWRITE,
	OPEN_ACCESS_WRITEONLY | OPEN_SHARE_DENYWRITE,
	OPEN_ACCESS_READWRITE | OPEN_SHARE_DENYWRITE
#endif
};

static OS(DWORD,ULONG) file_action[]={
#ifdef WINDOWS
	OPEN_EXISTING,
	CREATE_ALWAYS,
	OPEN_ALWAYS,
	OPEN_EXISTING,
	CREATE_ALWAYS,
	OPEN_ALWAYS
#else
	FILE_OPEN,
	FILE_TRUNCATE | FILE_CREATE,
	FILE_OPEN | FILE_CREATE,
	FILE_OPEN,
	FILE_TRUNCATE | FILE_CREATE,
	FILE_OPEN | FILE_CREATE
#endif
};

struct file *open_file (struct clean_string *file_name,unsigned int file_mode)
{
	char *file_name_s;
	int fn;
	struct file *f;
	FilePositionT file_length;
	unsigned char *buffer;
	HFILE file_handle;
	ULONG action;
	OS(DWORD,APIRET) error;
	
	if (file_mode>5)
		IO_error ("fopen: invalid file mode");
	
	file_name_s=clean_to_c_string (file_name);
	if (file_name_s==NULL){
		IO_error ("fopen: out of memory");
		return ERROR_FILE;
	}
	
	fn=number_of_files;
	if (fn>=MAX_N_FILES){
		for (fn=FIRST_REAL_FILE; fn<MAX_N_FILES; ++fn)
			if (file_table[fn].file_mode==0)
				break;

		if (fn>=MAX_N_FILES){
			free_memory (file_name_s);
			IO_error ("fopen: too many files");
		}
	}

	f=&file_table[fn];

#ifdef WINDOWS
	file_handle=CreateFileA (file_name_s,file_permission[file_mode],file_permission[file_mode]==GENERIC_READ ? FILE_SHARE_READ : 0,NULL,
							file_action[file_mode],FILE_ATTRIBUTE_NORMAL,NULL);
	if (file_handle==INVALID_HANDLE_VALUE){
		free_memory (file_name_s);
		return ERROR_FILE;
	}
#else
	error=DosOpen (file_name_s,&file_handle,&action,0,FILE_NORMAL,
					file_action[file_mode],file_permission[file_mode],NULL);
	if (error!=0){
		free_memory (file_name_s);
		return ERROR_FILE;
	}
#endif
	
	buffer=allocate_memory (FILE_IO_BUFFER_SIZE);
	if (buffer==NULL){
		free_memory (file_name_s);
		OS(CloseHandle,DosClose) (file_handle);
		IO_error ("fopen: out of memory");
	}
	
	f->file_read_buffer_p=buffer;
	f->file_write_buffer_p=buffer;
	f->file_end_read_buffer_p=buffer;
	f->file_end_write_buffer_p=buffer;
	f->file_read_p=buffer;
	f->file_write_p=buffer;

	f->file_offset=0;
	
	switch (file_mode){
		case F_WRITE_TEXT:
		case F_WRITE_DATA:
			file_length=0;
			break;
		case F_APPEND_TEXT:
		case F_APPEND_DATA:
		{
			unsigned int file_length_low,file_length_high;
			
			file_length_high=0;
 			file_length_low=SetFilePointer (file_handle,0,&file_length_high,FILE_END);

			if (file_length_low==-1 && GetLastError()!=NO_ERROR){
				free_memory (file_name_s);
				free_memory (buffer);
				OS(CloseHandle,DosClose) (file_handle);
				IO_error ("fopen: can't seek to eof");
			}
#ifdef A64
 			file_length=file_length_low+((FilePositionT)file_length_high<<32);
#else
 			file_length=file_length_low;
#endif
			f->file_offset=file_length;
			break;
		}
		default:
		{
			unsigned int file_length_low,file_length_high;
			
			file_length_high=0;
			file_length_low=GetFileSize (file_handle,&file_length_high);

			if (file_length_low==-1 && GetLastError()!=NO_ERROR){
				free_memory (file_name_s);
				free_memory (buffer);
				OS(CloseHandle,DosClose) (file_handle);
				IO_error ("fopen: can't get eof");
			}
#ifdef A64
 			file_length=file_length_low+((FilePositionT)file_length_high<<32);
#else
 			file_length=file_length_low;
#endif
		}
	}
	
	f->file_mode=1<<file_mode;
	f->file_unique=1;
	f->file_error=0;
	
	f->file_name=file_name_s;
	f->file_length=file_length;
	f->file_position=-2;
	f->file_position_2=-1;
	f->file_read_refnum=file_handle;
	f->file_write_refnum=file_handle;
	
	if (fn>=number_of_files)
		number_of_files=fn+1;
	
	return f;
}

static int stdio_open=0;

void init_std_io_from_or_to_file (void)
{
	struct file *f;
	unsigned char *buffer;
	
	f=&file_table[1];

	buffer=allocate_memory (FILE_IO_BUFFER_SIZE<<1);
	if (buffer==NULL){
		std_input_from_file=0;
		std_output_to_file=0;
		return;
	}

	f->file_read_buffer_p=buffer;
	f->file_end_read_buffer_p=buffer;
	f->file_read_p=buffer;

	buffer+=FILE_IO_BUFFER_SIZE;

	f->file_write_buffer_p=buffer;
	f->file_end_write_buffer_p=buffer;
	f->file_write_p=buffer;

	f->file_mode=(1<<F_READ_TEXT) | (1<<F_WRITE_TEXT);
	f->file_unique=1;
	f->file_error=0;

	f->file_offset=0;
	f->file_length=0;

	f->file_name="stdio";
	f->file_position=-2;
	f->file_position_2=-1;

	f->file_read_refnum=std_input_handle;
	f->file_write_refnum=std_output_handle;
}

struct file *open_stdio (void)
{
	if (stdio_open)
		IO_error ("stdio: already open");

	stdio_open=1;
	return &file_table[1];
}

struct file *open_stderr (void)
{
	return file_table;
}

static int flush_write_buffer (struct file *f)
{	
	if (f->file_mode & ((1<<F_WRITE_TEXT)|(1<<F_WRITE_DATA)|(1<<F_APPEND_TEXT)|(1<<F_APPEND_DATA))){
		unsigned char *buffer;
		
		buffer=f->file_write_buffer_p;
		if (buffer!=f->file_end_write_buffer_p){
			OS(DWORD,APIRET) error;
			long count;

			count=f->file_write_p-buffer;

			if (count==0)
				error=0;
			else {
#ifdef WINDOWS
				error=!WriteFile (f->file_write_refnum,buffer,count,&count,NULL);
#else
				error=DosWrite (f->file_write_refnum,buffer,count,&count);
#endif
				f->file_offset += count;
			}
			
			if (f->file_offset > f->file_length)
				f->file_length=f->file_offset;

			f->file_end_write_buffer_p=buffer;

			if (error!=0 || count!=f->file_write_p-buffer){
				f->file_write_p=buffer;
				f->file_error=-1;
				return 0;
			}

			f->file_write_p=buffer;
		}
	}
	
	return 1;
}

CLEAN_BOOL flush_file_buffer (struct file *f)
{
	if (is_special_file (f)){
		if (f==&file_table[1] && std_output_to_file)
			return flush_write_buffer (f);
		
		return 1;
	}
	
	return flush_write_buffer (f);
}

CLEAN_BOOL close_file (struct file *f)
{
	if (is_special_file (f)){
		if (f==&file_table[1]){
			if (!stdio_open)
				IO_error ("fclose: file not open (stdio)");
			stdio_open=0;

			if (std_input_from_file || std_output_to_file){
				int result;

				result=CLEAN_TRUE;

				if (f->file_error)
					result=0;
				
				if (std_output_to_file)
					if (! flush_write_buffer (f))
						result=0;

				return result;
			}
		}
		return CLEAN_TRUE;
	} else {
		int result;
	
		if (f->file_mode==0)
			IO_error ("fclose: file not open");

		result=CLEAN_TRUE;

		if (f->file_error)
			result=0;
		
		if (! flush_write_buffer (f))
			result=0;

#ifdef WINDOWS
		if (!CloseHandle (f->file_read_refnum))
			result=0;
#else
		if (DosClose (f->file_read_refnum)!=0)
			result=0;
#endif

		free_memory (f->file_name);
		free_memory (f->file_read_buffer_p);
		
		f->file_mode=0;

		return result;
	}
}

static OS(DWORD,ULONG) file_action_reopen[] ={
#ifdef WINDOWS
	OPEN_EXISTING,
	TRUNCATE_EXISTING,
	OPEN_EXISTING,
	OPEN_EXISTING,
	TRUNCATE_EXISTING,
	OPEN_EXISTING
#else
	FILE_OPEN,
	FILE_TRUNCATE,
	FILE_OPEN,
	FILE_OPEN,
	FILE_TRUNCATE,
	FILE_OPEN
#endif
};

static int clear_masks_for_stdio_reopen[6]={
	~ (1<<F_READ_DATA),							/* F_READ_TEXT */
	~ ((1<<F_WRITE_DATA) | (1<<F_APPEND_DATA)),	/* F_WRITE_TEXT */
	~ ((1<<F_WRITE_DATA) | (1<<F_APPEND_DATA)),	/* F_APPEND_TEXT */
	~ (1<<F_READ_TEXT),							/* F_READ_DATA */
	~ ((1<<F_WRITE_TEXT) | (1<<F_APPEND_TEXT)),	/* F_WRITE_DATA */
	~ ((1<<F_WRITE_TEXT) | (1<<F_APPEND_TEXT))	/* F_APPEND_DATA */
};

CLEAN_BOOL re_open_file (struct file *f,unsigned int file_mode)
{
	if (file_mode>5)
		IO_error ("freopen: invalid file mode");

	if (is_special_file (f)){
		if (f==file_table && (file_mode==F_READ_TEXT || file_mode==F_READ_DATA))
			IO_error ("freopen: stderr can't be opened for reading");
		if (f==&file_table[2])
			IO_error ("freopen: file not open");
		if (f==&file_table[1]){
			int m;
			
			m=file_table[1].file_mode;
			m &= clear_masks_for_stdio_reopen[file_mode];
			m |= 1<<file_mode;
			file_table[1].file_mode=m;
		}
		return CLEAN_TRUE;
	} else {
		FilePositionT file_length;
		int result;
		unsigned char *buffer;
		HFILE file_handle;
		OS(DWORD,APIRET) error;
		ULONG action;

		result=CLEAN_TRUE;

		if (f->file_mode!=0){	
			flush_write_buffer (f);

			OS(CloseHandle,DosClose) (f->file_read_refnum);
		} else {	
			buffer=allocate_memory (FILE_IO_BUFFER_SIZE);
			if (buffer==NULL)
				IO_error ("freopen: out of memory");
			f->file_read_buffer_p=buffer;
			f->file_write_buffer_p=buffer;
		}

		f->file_mode=0;

#ifdef WINDOWS
		file_handle=CreateFileA (f->file_name,file_permission[file_mode],file_permission[file_mode]==GENERIC_READ ? FILE_SHARE_READ : 0,NULL,
								file_action_reopen[file_mode],FILE_ATTRIBUTE_NORMAL,NULL);
		if (file_handle==INVALID_HANDLE_VALUE){
			free_memory (f->file_name);
			free_memory (f->file_read_buffer_p);
			return 0;
		}
#else
		error=DosOpen (f->file_name,&file_handle,&action,0,FILE_NORMAL,
						file_action_reopen[file_mode],file_permission[file_mode],NULL);
	
		if (error!=0){
			free_memory (f->file_name);
			free_memory (f->file_read_buffer_p);
			return 0;
		}
#endif

		f->file_offset=0;

		switch (file_mode){
			case F_WRITE_TEXT:
			case F_WRITE_DATA:
				file_length=0;
				break;
			case F_APPEND_TEXT:
			case F_APPEND_DATA:
			{
				unsigned int file_length_low,file_length_high;
			
				file_length_high=0;
	 			file_length_low=SetFilePointer (file_handle,0,&file_length_high,FILE_END);
			
				if (file_length_low==-1 && GetLastError()!=NO_ERROR){
					free_memory (f->file_name);
					free_memory (f->file_read_buffer_p);
					OS(CloseHandle,DosClose) (file_handle);
					IO_error ("freopen: can't seek to eof");
				}
#ifdef A64
 				file_length=file_length_low+((FilePositionT)file_length_high<<32);
#else
	 			file_length=file_length_low;
#endif
				f->file_offset=file_length;
				break;
			}
			default:
			{
				unsigned int file_length_low,file_length_high;
			
				file_length_high=0;
				file_length_low=GetFileSize (file_handle,&file_length_high);

				if (file_length_low==-1 && GetLastError()!=NO_ERROR){
					free_memory (f->file_name);
					free_memory (f->file_read_buffer_p);
					OS(CloseHandle,DosClose) (file_handle);
					IO_error ("freopen: can't get eof");
				}
#ifdef A64
 				file_length=file_length_low+((FilePositionT)file_length_high<<32);
#else
	 			file_length=file_length_low;
#endif
			}
		}
	
		f->file_read_refnum=file_handle;
		f->file_write_refnum=file_handle;
		f->file_mode=1<<file_mode;
		f->file_length=file_length;
		f->file_position=-2;
		f->file_position_2=-1;
		f->file_error=0;

		buffer=f->file_read_buffer_p;
		f->file_end_read_buffer_p=buffer;
		f->file_end_write_buffer_p=buffer;
		f->file_read_p=buffer;
		f->file_write_p=buffer;
		
		return result;
	}
}

static void char_to_new_buffer (int c,struct file *f)
{
	long count;
	unsigned char *buffer;

	flush_write_buffer (f);

	count=FILE_IO_BUFFER_SIZE - (f->file_offset & (FILE_IO_BUFFER_SIZE-1));
	buffer=f->file_write_buffer_p;
	
	*buffer=c;
	f->file_write_p=buffer+1;
	buffer+=count;
	f->file_end_write_buffer_p=buffer;
}

#if defined (__MWERKS__) || defined (powerc)
#define write_char(c,f) if ((f)->file_write_p<(f)->file_end_write_buffer_p) \
		*((f)->file_write_p)++=(c); \
	else \
		char_to_new_buffer((c),(f))
#else
#define write_char(c,f) ((f)->file_write_p<(f)->file_end_write_buffer_p ? (*((f)->file_write_p)++=(c)) : char_to_new_buffer((c),(f)))
#endif

static int char_from_new_buffer (struct file *f)
{
	OS(DWORD,APIRET) error;
	long count;
	unsigned char *buffer;
	int c;
	
	count=FILE_IO_BUFFER_SIZE - (f->file_offset & (FILE_IO_BUFFER_SIZE-1));
	buffer=f->file_read_buffer_p;
	
#ifdef WINDOWS
	error=!ReadFile (f->file_read_refnum,buffer,count,&count,NULL);
#else
	error=DosRead (f->file_read_refnum,buffer,count,&count);
#endif

	f->file_offset += count;

	if (error!=0)
		f->file_error=-1;

	if (error!=0 || count==0){
		f->file_end_read_buffer_p=buffer;
		f->file_read_p=buffer;
		return EOF;
	}

	c=*buffer;
	f->file_read_p=buffer+1;
	buffer+=count;
	f->file_end_read_buffer_p=buffer;

	return c;
}

#define read_char(f) ((f)->file_read_p<(f)->file_end_read_buffer_p ? *((f)->file_read_p)++ : char_from_new_buffer(f))

int file_read_char (struct file *f)
{
	if (f->file_read_p < f->file_end_read_buffer_p){
		unsigned char c;
		
		c=*(f->file_read_p)++;
		
		if (c=='\r' && f->file_mode & (1<<F_READ_TEXT)){
			if (read_char (f)=='\n')
				c='\n';
			else
				if (f->file_read_p > f->file_read_buffer_p)
					--f->file_read_p;
		}
		
		return c;
	} else {
		if (is_special_file (f)){
			if (f==&file_table[1]){
				if (std_input_from_file){
					int c;

					c=char_from_new_buffer (f);

					if (c=='\r'){
						if (read_char (f)=='\n')
							c='\n';
						else
							if (f->file_read_p > f->file_read_buffer_p)
								--f->file_read_p;
					}
					
					return c;
				} else
					return w_get_char();
			} else if (f==file_table){
				IO_error ("freadc: can't read from stderr");
				return 0;
			} else {
				IO_error ("freadc: can't open this file");
				return 0;
			}
		} else {
			int c;

			if (f->file_mode & ~((1<<F_READ_TEXT) | (1<<F_READ_DATA)))
				IO_error ("freadc: read from an output file");

			c=char_from_new_buffer (f);
			
			if (c=='\r' && f->file_mode & (1<<F_READ_TEXT)){
				if (read_char (f)=='\n')
					c='\n';
				else
					if (f->file_read_p > f->file_read_buffer_p)
						--f->file_read_p;
			}
			
			return c;
		}
	}
}

#define is_digit(n) ((unsigned)((n)-'0')<(unsigned)10)

CLEAN_BOOL file_read_int (struct file *f,CLEAN_INT *i_p)
{
	if (is_special_file (f)){
		if (f==&file_table[1]){
			if (!std_input_from_file)
				return w_get_int (i_p);
		} else if (f==file_table){
			IO_error ("freadi: can't read from stderr");
			return 0;
		} else {
			IO_error ("freadi: can't open this file");
			return 0;
		}
	}

	*i_p=0;

	if (f->file_mode & (1<<F_READ_DATA)){
		int i;
		
		if ((i=read_char (f))==EOF){
			f->file_error=-1;
			return 0;
		}
		((char*)i_p)[0]=i;
		if ((i=read_char (f))==EOF){
			f->file_error=-1;
			return 0;
		}
		((char*)i_p)[1]=i;
		if ((i=read_char (f))==EOF){
			f->file_error=-1;
			return 0;
		}
		((char*)i_p)[2]=i;
		if ((i=read_char (f))==EOF){
			f->file_error=-1;
			return 0;
		}
		((char*)i_p)[3]=i;	
	} else if (f->file_mode & (1<<F_READ_TEXT)){
		int c,negative,result;
		
		result=CLEAN_TRUE;
		
		while ((c=read_char (f))==' ' || c=='\t' || c=='\n' || c=='\r')
			;
		
		negative=0;
		if (c=='+')
			c=read_char (f);
		else
			if (c=='-'){
				c=read_char (f);
				negative=1;
			}
		
		if (!is_digit (c)){
			result=0;
			f->file_error=-1;
		} else {
			size_t i;
			
			i=c-'0';
			
			while (is_digit (c=read_char (f))){
				i+=i<<2;
				i+=i;
				i+=c-'0';
			};
		
			if (negative)
				i=-i;
			
			*i_p=i;
		}

		if (f->file_read_p > f->file_read_buffer_p)
			--f->file_read_p;

		return result;
	} else
		IO_error ("freadi: read from an output file");
	
	return CLEAN_TRUE;
}

extern char *convert_string_to_real (char *s,double *r_p);

CLEAN_BOOL file_read_real (struct file *f,double *r_p)
{
	if (is_special_file (f)){
		if (f==&file_table[1]){
			if (!std_input_from_file)
				return w_get_real (r_p);
		} else if (f==file_table){
			IO_error ("freadr: can't read from stderr");
			return 0;
		} else {
			IO_error ("freadr: can't open this file");
			return 0;
		}
	}
	
	*r_p=0.0;
	
	if (f->file_mode & (1<<F_READ_DATA)){
		int n;

		for (n=0; n<8; ++n){
			int i;
			
			if ((i=read_char (f))==EOF){
				f->file_error=-1;
				return 0;
			}
			((char*)r_p)[n]=i;
		}
	} else if (f->file_mode & (1<<F_READ_TEXT)){
		int c,dot,digits,result,n;
		char s[256+1];
		
		n=0;
		
		while ((c=read_char (f))==' ' || c=='\t' || c=='\n' || c=='\r')
			;
		
		if (c=='+')
			c=read_char (f);
		else
			if (c=='-'){
				s[n++]=c;
				c=read_char (f);
			}
		
		dot=0;
		digits=0;
		
		while (is_digit (c) || c=='.'){
			if (c=='.'){
				if (dot){
					dot=2;
					break;
				}
				dot=1;
			} else
				digits=-1;
			if (n<256)
				s[n++]=c;
			c=read_char (f);
		}
	
		result=0;
		if (digits)
			if (dot==2 || ! (c=='e' || c=='E'))
				result=CLEAN_TRUE;
			else {
				if (n<256)
					s[n++]=c;
				c=read_char (f);
				
				if (c=='+')
					c=read_char (f);
				else
					if (c=='-'){
						if (n<256)
							s[n++]=c;
						c=read_char (f);
					}
				
				if (is_digit (c)){
					do {
						if (n<256)
							s[n++]=c;
						c=read_char (f);
					} while (is_digit (c));
	
					result=CLEAN_TRUE;
				}
			}
	
		if (n>=256)
			result=0;
	
		if (f->file_read_p > f->file_read_buffer_p)
			--f->file_read_p;
				
		*r_p=0.0;
		
		if (result){
			s[n]='\0';
			result= convert_string_to_real (s,r_p)==&s[n];
		}
		
		if (!result)
			f->file_error=-1;

		return result;
	} else
		IO_error ("freadr: read from an output file");

	return CLEAN_TRUE;
}

#define OLD_READ_STRING 0
#define OLD_WRITE_STRING 0

#if OLD_READ_STRING
unsigned long file_read_string (struct file *f,unsigned long max_length,struct clean_string *s)
{
#else
UNSIGNED_CLEAN_INT file_read_characters (struct file *f,UNSIGNED_CLEAN_INT *length_p,char *s)
{
	UNSIGNED_CLEAN_INT max_length;
	
	max_length=*length_p;
#endif
	if (is_special_file (f)){
		if (f==&file_table[1]){
			if (!std_input_from_file){
				char *string;
				UNSIGNED_CLEAN_INT length;
				int c;
				
				length=0;
#if OLD_READ_STRING
				string=s->characters;
#else
				string=s;
#endif
				while (length!=max_length && (c=w_get_char(),c!=-1)){
					*string++=c;
					++length;
				}

#if OLD_READ_STRING
				s->length=length;
#else
				*length_p=length;
#endif
				return length;
			}
		} else if (f==file_table){
			IO_error ("freads: can't read from stderr");
			return 0;
		} else {
			IO_error ("freads: can't open this file");
			return 0;
		}
	} else {
		if (f->file_mode & ~((1<<F_READ_TEXT) | (1<<F_READ_DATA)))
			IO_error ("freads: read from an output file");
	}
	{
	unsigned char *string,*end_string,*begin_string;

#if OLD_READ_STRING
	string=s->characters;
#else
	string=s;
#endif
	begin_string=string;
	end_string=string+max_length;

	if (f->file_mode & (1<<F_READ_DATA)){
		while (string<end_string){
			if (f->file_read_p < f->file_end_read_buffer_p){
				unsigned char *read_p;
				long n;

				read_p=f->file_read_p;
				
				n=f->file_end_read_buffer_p-read_p;
				if (n > end_string-string)
					n=end_string-string;
				
				do {
					*string++ = *read_p++;
				} while (--n);
			
				f->file_read_p=read_p;
			} else {
				if (end_string-string>=FILE_IO_BUFFER_SIZE && (f->file_offset & (FILE_IO_BUFFER_SIZE-1))==0){
					OS(DWORD,APIRET) error;
					long count;
					unsigned char *buffer;
					
					count=(end_string-string) & (~(FILE_IO_BUFFER_SIZE-1));
#ifdef WINDOWS										
					error=!ReadFile (f->file_read_refnum,string,count,&count,NULL);
#else
					error=DosRead (f->file_read_refnum,string,count,&count);
#endif
					f->file_offset += count;

					if (error!=0)
						f->file_error=-1;

					buffer=f->file_read_buffer_p;
					f->file_end_read_buffer_p=buffer;
					f->file_read_p=buffer;
					string+=count;

					if (error!=0 || count==0)
#if OLD_READ_STRING
						return (s->length=string-begin_string);
#else
						return (*length_p=string-begin_string);
#endif
				} else {
					int c;
					
					c=char_from_new_buffer (f);
					if (c==EOF)
						break;
					*string++=c;
				}
			}
		}
	} else {
		while (string<end_string){
			if (f->file_read_p < f->file_end_read_buffer_p){
				unsigned char *read_p;
				long n;

				read_p=f->file_read_p;
				
				n=f->file_end_read_buffer_p-read_p;
				if (n > end_string-string)
					n=end_string-string;
				
				do {
					char c;

					c = *read_p++;
					if (c=='\r'){
						if (n>1){
							if (*read_p=='\n'){
								*string++='\n';
								++read_p;
								--n;
							} else
								*string++ = c;									
						} else {
							int c2;
							
							f->file_read_p=read_p;
							c2=read_char (f);
							read_p=f->file_read_p;
							
							if (c2=='\n')
								*string++=c2;
							else {
								*string++=c;
								if (read_p > f->file_read_buffer_p)
									--read_p;
							}
							break;
						}
					} else
						*string++ = c;
				} while (--n);
			
				f->file_read_p=read_p;
			} else {
				int c;
				
				c=char_from_new_buffer (f);
				if (c==EOF)
					break;

				if (c=='\r'){
					if (read_char (f)=='\n')
						c='\n';
					else
						if (f->file_read_p > f->file_read_buffer_p)
							--f->file_read_p;
				}
				
				*string++=c;
			}
		}
	}
#if OLD_READ_STRING
	return (s->length=string-begin_string);
#else
	return (*length_p=string-begin_string);
#endif
	}
}

#ifdef A64
 __int64
#else
 unsigned long
#endif
	file_read_line (struct file *f,UNSIGNED_CLEAN_INT max_length,char *string)
{
	if (is_special_file (f)){
		if (f==&file_table[1]){
			if (!std_input_from_file){
				unsigned long length;
				int c;

				length=0;
				c=0;

				while (length!=max_length && (c=w_get_char(),c!=-1)){
					*string++=c;
					++length;
					if (c=='\n')
						return length;
				}

				if (c!=-1)
					return -1;
			
				return length;
			}
		} else if (f==file_table){
			IO_error ("freadline: can't read from stderr");
			return 0;
		} else {
			IO_error ("freadline: can't open this file");
			return 0;
		}
	}
	
	{
	unsigned char *end_string,*begin_string;
	int c;

	begin_string=string;
	end_string=string+max_length;
	
	c=0;

	if (f->file_mode & (1<<F_READ_TEXT)){
		while ((unsigned char*)string<end_string){
			if (f->file_read_p < f->file_end_read_buffer_p){
				unsigned char *read_p;
				long n;
				
				read_p=f->file_read_p;
				
				n=f->file_end_read_buffer_p-read_p;
				if (n > end_string-(unsigned char*)string)
					n=end_string-(unsigned char*)string;

				do {
					char ch;
					
					ch=*read_p++;
					
					if (ch=='\r'){
						if (n>1 || read_p < f->file_end_read_buffer_p){
							if (*read_p=='\n'){
								f->file_read_p=++read_p;
								*string++='\n';
								return (unsigned char*)string-begin_string;
							} else {
								*string++=ch;	
							}
						} else {
							int c;
						
							f->file_read_p=read_p;
							c=char_from_new_buffer(f);
							read_p=f->file_read_p;

							if (c=='\n'){
								*string++=c;
								return (unsigned char*)string-begin_string;								
							} else {
								*string++=ch;
								
								if (f->file_read_p > f->file_read_buffer_p)
									--read_p;							
							}
						}
					} else {
						*string++=ch;
						if (ch=='\n'){
							f->file_read_p=read_p;
							return (unsigned char*)string-begin_string;
						}
					}
				} while (--n);
				
				c=0;
				f->file_read_p=read_p;
			} else {
				c=char_from_new_buffer(f);
				if (c==EOF)
					break;
				
				if (c=='\r'){
					if (read_char (f)=='\n')
						c='\n';
					else
						if (f->file_read_p > f->file_read_buffer_p)
							--f->file_read_p;
				}

				*string++=c;				
				if (c=='\n')
					return (unsigned char*)string-begin_string;
			}
		}
	} else if (f->file_mode & (1<<F_READ_DATA)){
		while (string<end_string){
			if (f->file_read_p < f->file_end_read_buffer_p){
				unsigned char *read_p;
				long n;

				read_p=f->file_read_p;

				n=f->file_end_read_buffer_p-read_p;
				if (n > end_string-(unsigned char*)string)
					n=end_string-(unsigned char*)string;
				do {
					char ch;

					ch=*read_p++;

					*string++=ch;	
					if (ch=='\xd'){
						if (n>1){
							if (*read_p=='\xa'){
								*string++='\xa';
								++read_p;
							}
							f->file_read_p=read_p;
							return (unsigned char*)string-begin_string;
						} else if (read_p < f->file_end_read_buffer_p){
							f->file_read_p=read_p;
							if (*read_p!='\xa'){
								return (unsigned char*)string-begin_string;
							} else {
								return -1; /* return \xd, read \xa next time */
							}
						} else {
							int c;

							f->file_read_p=read_p;
							c=char_from_new_buffer(f);
							read_p=f->file_read_p;

							if (c!='\xa'){
								if (read_p > f->file_read_buffer_p)
									--read_p;							

								f->file_read_p=read_p;
								return (unsigned char*)string-begin_string;
							} else {
								if (string<end_string){
									*string++='\xa';
									f->file_read_p=read_p;
									return (unsigned char*)string-begin_string;											
								} else {
									if (read_p > f->file_read_buffer_p)
										--read_p;							

									f->file_read_p=read_p;
									return -1; /* return \xd, read \xa next time */
								}
							}
						}
					} else if (ch=='\xa'){
						f->file_read_p=read_p;
						return (unsigned char*)string-begin_string;
					}
				} while (--n);

				c=0;
				f->file_read_p=read_p;
			} else {
				c=char_from_new_buffer(f);
				if (c==EOF)
					break;

				*string++=c;		

				if (c=='\xd'){
					c = read_char (f);
					if (string<end_string){
						if (c=='\xa')
							*string++=c;				
						else
							if (f->file_read_p > f->file_read_buffer_p)
								--f->file_read_p;
					} else {
						if (f->file_read_p > f->file_read_buffer_p)
							--f->file_read_p;
						
						if (c=='\xa')
							return -1;
					}

					return (unsigned char*)string-begin_string;
				} else if (c=='\xa')
					return (unsigned char*)string-begin_string;
			}
		}
	} else
		IO_error ("freadline: read from an output file");

	if (c!=EOF)
		return -1;
	
	return (unsigned char*)string-begin_string;
	}
}

void file_write_char (int c,struct file *f)
{	
	if (f->file_write_p < f->file_end_write_buffer_p){
		if (c=='\n' && f->file_mode & ((1<<F_WRITE_TEXT)|(1<<F_APPEND_TEXT))){
			*(f->file_write_p)++='\r';

			if (f->file_write_p < f->file_end_write_buffer_p)
				*(f->file_write_p)++=c;
			else
				char_to_new_buffer (c,f);				
		} else {
			*(f->file_write_p)++=c;
		}
	} else {
		if (is_special_file (f)){
			if (f==&file_table[1]){
				if (!std_output_to_file)
					w_print_char (c);
				else {
					if (c=='\n'){
						char_to_new_buffer ('\r',f);
						write_char (c,f);
					} else
						char_to_new_buffer (c,f);				
				}
			} else if (f==file_table)
				ew_print_char (c);
			else
				IO_error ("fwritec: can't open this file");
		} else {
			if (f->file_mode & ~((1<<F_WRITE_TEXT)|(1<<F_WRITE_DATA)|(1<<F_APPEND_TEXT)|(1<<F_APPEND_DATA)))
				IO_error ("fwritec: write to an input file");

			if (c=='\n' && f->file_mode & ((1<<F_WRITE_TEXT)|(1<<F_APPEND_TEXT))){
				char_to_new_buffer ('\r',f);
				write_char (c,f);
			} else
				char_to_new_buffer (c,f);
		}
	}
}

#ifdef A64
extern char *convert_int_to_string (char *string,__int64 i);
#else
extern char *convert_int_to_string (char *string,int i);
#endif

extern char *convert_real_to_string (double d,char *s_p);

void file_write_int (CLEAN_INT i,struct file *f)
{
	if (is_special_file (f)){
		if (f==&file_table[1]){
			if (!std_output_to_file){
				w_print_int (i);
				return;
			}
		} else if (f==file_table){
			ew_print_int (i);
			return;
		} else
			IO_error ("fwritei: can't open this file");
	} else {
		if (f->file_mode & ~((1<<F_WRITE_TEXT)|(1<<F_WRITE_DATA)|(1<<F_APPEND_TEXT)|(1<<F_APPEND_DATA)))
			IO_error ("fwritei: write to an input file");
	}

	if (f->file_mode & ((1<<F_WRITE_DATA)|(1<<F_APPEND_DATA))){
		int v=i;

		write_char (((char*)&v)[0],f);
		write_char (((char*)&v)[1],f);
		write_char (((char*)&v)[2],f);
		write_char (((char*)&v)[3],f);
	} else {
		unsigned char string[24],*end_p,*s;
		int length;

		end_p=convert_int_to_string (string,i);
		length=end_p-string;
		
		s=string;
		do {
			write_char (*s++,f);
		} while (--length);
	}
}

void file_write_real (double r,struct file *f)
{	
	if (is_special_file (f)){
		if (f==&file_table[1]){
			if (!std_output_to_file){
				w_print_real (r);
				return;
			}
		} else if (f==file_table){
			ew_print_real (r);
			return;
		} else
			IO_error ("fwriter: can't open this file");
	} else {
		if (f->file_mode & ~((1<<F_WRITE_TEXT)|(1<<F_WRITE_DATA)|(1<<F_APPEND_TEXT)|(1<<F_APPEND_DATA)))
			IO_error ("fwriter: write to an input file");
	}

	if (f->file_mode & ((1<<F_WRITE_DATA)|(1<<F_APPEND_DATA))){
		double v=r;

		write_char (((char*)&v)[0],f);
		write_char (((char*)&v)[1],f);
		write_char (((char*)&v)[2],f);
		write_char (((char*)&v)[3],f);
		write_char (((char*)&v)[4],f);
		write_char (((char*)&v)[5],f);
		write_char (((char*)&v)[6],f);
		write_char (((char*)&v)[7],f);
	} else {
		unsigned char string[32],*end_p,*s;
		int length;

		end_p=convert_real_to_string (r,string);
		length=end_p-string;

		s=string;
		do {
			write_char (*s++,f);
		} while (--length);
	}
}

#if OLD_WRITE_STRING
void file_write_string (struct clean_string *s,struct file *f)
#else
void file_write_characters (unsigned char *p,UNSIGNED_CLEAN_INT length,struct file *f)
#endif
{	
	if (is_special_file (f)){
		if (f==&file_table[1]){
			if (!std_output_to_file){
#if OLD_WRITE_STRING
				w_print_text (s->characters,s->length);
#else
				w_print_text (p,length);
#endif
				return;
			}
		} else if (f==file_table){
#if OLD_WRITE_STRING
			ew_print_text (s->characters,s->length);
#else
			ew_print_text (p,length);
#endif
			return;
		} else
			IO_error ("fwrites: can't open this file");
	} else {
		if (f->file_mode & ~((1<<F_WRITE_TEXT)|(1<<F_WRITE_DATA)|(1<<F_APPEND_TEXT)|(1<<F_APPEND_DATA)))
			IO_error ("fwrites: write to an input file");
	}

	{
#if OLD_WRITE_STRING
	unsigned char *p,*end_p;
#else
	unsigned char *end_p;
#endif

#if OLD_WRITE_STRING
	p=s->characters;
	end_p=p+s->length;
#else
	end_p=p+length;
#endif

	if (f->file_mode & ((1<<F_WRITE_DATA)|(1<<F_APPEND_DATA))){
		while (p<end_p){
			if (f->file_write_p < f->file_end_write_buffer_p){
				unsigned char *write_p;
				long n;
				
				write_p=f->file_write_p;
				
				n=f->file_end_write_buffer_p-write_p;
				if (n>end_p-p)
					n=end_p-p;
				
				do {
					*write_p++ = *p++;
				} while (--n);

				f->file_write_p=write_p;	
			} else
				char_to_new_buffer (*p++,f);
		}
	} else {
		while (p<end_p){
			if (f->file_write_p < f->file_end_write_buffer_p){
				unsigned char *write_p;
				long n;
				
				write_p=f->file_write_p;
				
				n=f->file_end_write_buffer_p-write_p;
				if (n>end_p-p)
					n=end_p-p;
				
				do {
					char c;
					
					c = *p++;
					if (c=='\n'){
						*write_p++ = '\r';
						if (--n){
							*write_p++ = c;
						} else {
							f->file_write_p=write_p;
							write_char (c,f);								
							write_p=f->file_write_p;
							break;
						}
					} else
						*write_p++ = c;
				} while (--n);

				f->file_write_p=write_p;	
			} else {
				char c;
				
				c=*p++;
				if (c=='\n'){
					char_to_new_buffer ('\r',f);
					write_char (c,f);
				} else
					char_to_new_buffer (c,f);
			}
		}
	}
	}
}

CLEAN_BOOL file_end (struct file *f)
{
	if (f->file_read_p < f->file_end_read_buffer_p)
		return 0;

	if (is_special_file (f)){
		if (f==file_table || f==&file_table[1])
			IO_error ("fend: not allowed for stdio and stderr");
		else
			IO_error ("fend: can't open file");
		return 0;
	} else {
		if (f->file_mode & ~((1<<F_READ_TEXT) | (1<<F_READ_DATA)))
			IO_error ("fend: not allowed for output files");
		
		if (f->file_offset < f->file_length)
			return 0;

		return CLEAN_TRUE;
	}
}

CLEAN_BOOL file_error (struct file *f)
{
	if (is_special_file (f)){
		if (f==&file_table[1]){
			if ((std_input_from_file || std_output_to_file) && f->file_error)
				return CLEAN_TRUE;
			else
				return 0;
		} else if (f==file_table)
			return 0;
		else
			return CLEAN_TRUE;
	} else
		if (f->file_error)
			return CLEAN_TRUE;
		else
			return 0;
}

FilePositionT file_position (struct file *f)
{
	if (is_special_file (f)){
		if (f==file_table || f==&file_table[1])
			IO_error ("fposition: not allowed for stdio and stderr");
		else
			IO_error ("fposition: can't open file");
		return 0;
	} else {
		FilePositionT position;
		
		if (f->file_mode & ((1<<F_READ_TEXT) | (1<<F_READ_DATA)))
			position=f->file_offset - (f->file_end_read_buffer_p - f->file_read_p);
		else
			position=f->file_offset + (f->file_write_p - f->file_write_buffer_p);
		
		return position;
	}
}

CLEAN_BOOL file_seek (struct file *f,FilePositionT position,unsigned long seek_mode)
{
	if (is_special_file (f)){
		if (seek_mode>(unsigned)2)
			IO_error ("fseek: invalid mode");

		if (f==file_table || f==&file_table[1])
			IO_error ("fseek: can't seek on stdio and stderr");
		else
			IO_error ("fseek: can't open file");
		return 0;
	} else {
		FilePositionT current_position;
		unsigned long buffer_size;
	
		if (f->file_mode & ((1<<F_READ_TEXT) | (1<<F_READ_DATA))){
			current_position=f->file_offset - (f->file_end_read_buffer_p - f->file_read_p);
			
			switch (seek_mode){
				case F_SEEK_SET:
					break;
				case F_SEEK_CUR:
					position+=current_position;
					break;
				case F_SEEK_END:
					position=f->file_length-position;
					break;
				default:
					IO_error ("fseek: invalid mode");
			}
			
			buffer_size=f->file_end_read_buffer_p - f->file_read_buffer_p;
			if ((FilePositionT)(position - (f->file_offset-buffer_size)) < buffer_size){
				f->file_read_p = f->file_read_buffer_p + (position - (f->file_offset-buffer_size));
				
				return CLEAN_TRUE;
			} else {
				unsigned char *buffer;
				FilePositionT file_position;
				unsigned int file_position_low,file_position_high;
							
				if (position>f->file_length){
					f->file_error=-1;
					return 0;
				}
				
				buffer=f->file_read_buffer_p;
				f->file_end_read_buffer_p=buffer;
				f->file_read_p=buffer;
#ifdef A64
				file_position_high=position>>32;
#else
				file_position_high=0;
#endif
	 			file_position_low=SetFilePointer (f->file_read_refnum,position,&file_position_high,FILE_BEGIN);

				if (file_position_low==-1 && GetLastError()!=NO_ERROR){
					f->file_error=-1;
					return 0;
				}
#ifdef A64
				file_position=file_position_low+((FilePositionT)file_position_high<<32);
#else
				file_position=file_position_low;
#endif				
				f->file_offset=file_position;
				return CLEAN_TRUE;
			}
		} else {
			FilePositionT file_position;
			int result;
			unsigned int file_position_low,file_position_high;

			result=CLEAN_TRUE;

			current_position=f->file_offset + (f->file_write_p - f->file_write_buffer_p);
			
			if (current_position > f->file_length)
				f->file_length=current_position;
			
			switch (seek_mode){
				case F_SEEK_SET:
					break;
				case F_SEEK_CUR:
					position+=current_position;
					break;
				case F_SEEK_END:
					position=f->file_length-position;
					break;
				default:
					IO_error ("fseek: invalid mode");
			}

			if (position==current_position)
				return CLEAN_TRUE;

			if (! flush_write_buffer (f)){
				f->file_error=-1;
				result=0;
			}

			if (position>f->file_length){
				f->file_error=-1;
				return 0;
			}

#ifdef A64
			file_position_high=position>>32;
#else
			file_position_high=0;
#endif
			file_position_low=SetFilePointer (f->file_write_refnum,position,&file_position_high,FILE_BEGIN);

			if (file_position_low==-1 && GetLastError()!=NO_ERROR){
				f->file_error=-1;
				result=0;
			} else {
#ifdef A64
				file_position=file_position_low+((FilePositionT)file_position_high<<32);
#else
				file_position=file_position_low;
#endif
				f->file_offset=file_position;
			}
			return result;
		}
	}
}

static int equal_string (char *s1,char*s2)
{
	char c;
	
	do {
		c=*s1++;
		if (c=='\0')
			return *s2==c;
	} while (*s2++ == c);

	return 0;
}

struct file *open_s_file (struct clean_string *file_name,unsigned int file_mode)
{
	int fn;
	char *file_name_s;
	struct file *f;
	FilePositionT file_length;
	HFILE file_handle;
	unsigned char *buffer;
	ULONG action;
	OS(DWORD,APIRET) error;

	if (file_mode!=F_READ_TEXT && file_mode!=F_READ_DATA)
		IO_error ("sfopen: invalid file mode");
	
	file_name_s=clean_to_c_string (file_name);
	if (file_name_s==NULL){
		IO_error ("sfopen: out of memory");
		return ERROR_FILE;
	}	
	
	fn=number_of_files;
	if (fn>=MAX_N_FILES){
		for (fn=FIRST_REAL_FILE; fn<MAX_N_FILES; ++fn)
			if (file_table[fn].file_mode==0)
				break;

		if (fn>=MAX_N_FILES)
			IO_error ("sfopen: too many files");
	}
	f=&file_table[fn];

#ifdef WINDOWS
	file_handle=CreateFileA (file_name_s,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL);

	if (file_handle==INVALID_HANDLE_VALUE){
		/* added 13-1-1999 */
		if (GetLastError()==ERROR_SHARING_VIOLATION){
			for (fn=FIRST_REAL_FILE; fn<MAX_N_FILES; ++fn){
				f=&file_table[fn];
				if (f->file_mode!=0 && equal_string (file_name_s,f->file_name) && f->file_mode==1<<file_mode){
					free_memory (file_name_s);
					return f;
				}
			}
		}
		/* */
		
		free_memory (file_name_s);
		return ERROR_FILE;
	}
#else
	error=DosOpen (file_name_s,&file_handle,&action,0,FILE_NORMAL,
					FILE_OPEN,file_permission[file_mode],NULL);

	if (error!=0){
		free_memory (file_name_s);
		return ERROR_FILE;
	}
#endif

	buffer=allocate_memory (FILE_IO_BUFFER_SIZE);
	if (buffer==NULL){
		free_memory (file_name_s);
		OS(CloseHandle,DosClose) (file_handle);
		IO_error ("sfopen: out of memory");
	}

	f->file_read_buffer_p=buffer;
	f->file_write_buffer_p=buffer;
	f->file_end_read_buffer_p=buffer;
	f->file_end_write_buffer_p=buffer;
	f->file_read_p=buffer;
	f->file_write_p=buffer;

	f->file_offset=0;

	{
	unsigned int file_length_low,file_length_high;
			
	file_length_high=0;
	file_length_low=GetFileSize (file_handle,&file_length_high);

	if (file_length_low==-1 && GetLastError()!=NO_ERROR){
		free_memory (file_name_s);
		free_memory (buffer);
		OS(CloseHandle,DosClose) (file_handle);
		IO_error ("sfopen: can't get eof");
	}
#ifdef A64
 	file_length=file_length_low+((FilePositionT)file_length_high<<32);
#else
 	file_length=file_length_low;
#endif
	}

	f->file_read_refnum=file_handle;
	f->file_write_refnum=file_handle;
	f->file_mode=1<<file_mode;
	f->file_unique=0;
	f->file_error=0;

	f->file_name=file_name_s;
	f->file_length=file_length;
	f->file_position=-2;
	f->file_position_2=-1;
	
	if (fn>=number_of_files)
		number_of_files=fn+1;
	
	return f;
}

void file_share (struct file *f)
{
	f->file_unique=0;
}

static int simple_seek (struct file *f,FilePositionT position)
{
	int result;
	long buffer_size;

	result=1;
	
	buffer_size=f->file_end_read_buffer_p - f->file_read_buffer_p;
	if ((FilePositionT)(position - (f->file_offset-buffer_size)) < buffer_size){
		f->file_read_p = f->file_read_buffer_p + (position - (f->file_offset-buffer_size));
		f->file_position=position;
	} else {
		unsigned char *buffer;
		FilePositionT file_position;

		if (position>f->file_length){
			f->file_error=-1;
			result=0;
		} else {
			unsigned int file_position_low,file_position_high;

			buffer=f->file_read_buffer_p;
			f->file_end_read_buffer_p=buffer;
			f->file_read_p=buffer;

#ifdef A64
			file_position_high=position>>32;
#else
			file_position_high=0;
#endif
			file_position_low=SetFilePointer (f->file_read_refnum,position,&file_position_high,FILE_BEGIN);

			if (file_position_low==-1 && GetLastError()!=NO_ERROR){
				f->file_error=-1;
				result=0;
			} else {
#ifdef A64
				file_position=file_position_low+((FilePositionT)file_position_high<<32);
#else
				file_position=file_position_low;
#endif
				f->file_offset=file_position;
			}
		}
	}
	
	return result;
}

int file_read_s_char (struct file *f,FilePositionT *position_p)
{	
	if (is_special_file (f)){
		if (f==file_table)
			IO_error ("sfreadc: can't read from stderr");
		else if (f==&file_table[1])
			IO_error ("sfreadc: can't read from stdio, use freadc");
		else
			IO_error ("sfreadc: can't open this file");
		return 0;
	} else {
		int c;
		FilePositionT position;

		position=*position_p;

		if (f->file_position!=position){
			if (f->file_unique)
				IO_error ("sfreadc: can't read from a unique file");
			
			switch (position){
				case -1l:
					if (position!=f->file_position_2)
						position=f->file_position_2;
					else {
						position=f->file_offset + (f->file_write_p - f->file_write_buffer_p);
						f->file_position_2=position;
						break;
					}
				default:
					if (!simple_seek (f,position))
						IO_error ("sfreadc: seek failed");
			}
		}

		if (f->file_read_p < f->file_end_read_buffer_p){
			c=*f->file_read_p++;
			++position;
		} else {
			c=char_from_new_buffer(f);
			if (c!=EOF)
				++position;
		}

		if (c=='\r' && f->file_mode & (1<<F_READ_TEXT)){
			if (read_char (f)=='\n'){
				c='\n';
				++position;
			} else
				if (f->file_read_p > f->file_read_buffer_p)
					--f->file_read_p;
		}

		f->file_position=position;
		*position_p=position;

		return c;
	}
}

CLEAN_BOOL file_read_s_int (struct file *f,int *i_p,FilePositionT *position_p)
{
	if (is_special_file (f)){
		if (f==file_table)
			IO_error ("sfreadi: can't read from stderr");
		else if (f==&file_table[1])
			IO_error ("sfreadi: can't read from stdio, use freadi");
		else
			IO_error ("sfreadi: can't open this file");
		return 0;
	} else {
		int result;
		FilePositionT position;

		position=*position_p;
		
		if (f->file_position!=position){
			if (f->file_unique)
				IO_error ("sfreadi: can't read from a unique file");

			switch (position){
				case -1l:
					if (position!=f->file_position_2)
						position=f->file_position_2;
					else {
						position=f->file_offset + (f->file_write_p - f->file_write_buffer_p);
						f->file_position_2=position;
						break;
					}
				default:
					if (!simple_seek (f,position))
						IO_error ("sfreadi: seek failed");
			}
		}
		
		*i_p=0;
		
		result=CLEAN_TRUE;
		if (f->file_mode & (1<<F_READ_DATA)){
			int i;

			if ((i=read_char (f))==EOF){
				f->file_error=-1;
				result=0;
			} else {
				((char*)i_p)[0]=i;
				if ((i=read_char (f))==EOF){
					++position;
					f->file_error=-1;
					result=0;
				} else {
					((char*)i_p)[1]=i;
					if ((i=read_char (f))==EOF){
						position+=2;
						f->file_error=-1;
						result=0;
					} else {
						((char*)i_p)[2]=i;
						if ((i=read_char (f))==EOF){
							position+=3;
							f->file_error=-1;
							result=0;
						} else {
							((char*)i_p)[3]=i;
							position+=4;
						}
					}
				}
			}
		} else if (f->file_mode & (1<<F_READ_TEXT)){
			int c,negative,n_characters;
			
			n_characters=-1;
			++n_characters;
			while ((c=read_char (f))==' ' || c=='\t' || c=='\n' || c=='\r')
				++n_characters;
			
			negative=0;
			if (c=='+'){
				c=read_char (f);
				++n_characters;
			} else
				if (c=='-'){
					c=read_char (f);
					++n_characters;
					negative=1;
				}
			
			if (!is_digit (c)){
				f->file_error=-1;
				result=0;
			} else {
				unsigned int i;
				
				i=c-'0';
				
				++n_characters;
				while (is_digit (c=read_char (f))){
					i+=i<<2;
					i+=i;
					i+=c-'0';
					++n_characters;
				};
			
				if (negative)
					i=-i;
				
				*i_p=i;
			}

			position+=n_characters;

			if (f->file_read_p > f->file_read_buffer_p)
				--f->file_read_p;
		}

		f->file_position=position;
		*position_p=position;
		
		return result;
	}
}

CLEAN_BOOL file_read_s_real (struct file *f,double *r_p,FilePositionT *position_p)
{
	if (is_special_file (f)){
		if (f==file_table)
			IO_error ("sfreadr: can't read from stderr");
		else if (f==&file_table[1])
			IO_error ("sfreadr: can't read from stdio, use freadr");
		else
			IO_error ("sfreadr: can't open this file");
		return 0;
	} else {
		int result;
		FilePositionT position;
		
		position=*position_p;
		if (f->file_position!=position){
			if (f->file_unique)
				IO_error ("sfreadr: can't read from a unique file");

			switch (position){
				case -1l:
					if (position!=f->file_position_2)
						position=f->file_position_2;
					else {
						position=f->file_offset + (f->file_write_p - f->file_write_buffer_p);
						f->file_position_2=position;
						break;
					}
				default:
					if (!simple_seek (f,position))
						IO_error ("sfreadr: seek failed");
			}
		}
		
		*r_p=0.0;
		
		if (f->file_mode & (1<<F_READ_DATA)){
			int n;

			result=CLEAN_TRUE;
			for (n=0; n<8; ++n){
				int i;
				
				if ((i=read_char (f))==EOF){
					f->file_error=-1;
					result=0;
					break;
				}
				((char*)r_p)[n]=i;
			}
			
			position+=n;
		} else if (f->file_mode & (1<<F_READ_TEXT)){
			int c,dot,digits,n,n_characters;
			char s[256+1];
			
			n_characters=-1;
			
			n=0;
			
			++n_characters;
			while ((c=read_char (f))==' ' || c=='\t' || c=='\n' || c=='\r')
				++n_characters;
			
			if (c=='+'){
				c=read_char (f);
				++n_characters;
			} else
				if (c=='-'){
					s[n++]=c;
					c=read_char (f);
					++n_characters;
				}
			
			dot=0;
			digits=0;
			
			while (is_digit (c) || c=='.'){
				if (c=='.'){
					if (dot){
						dot=2;
						break;
					}
					dot=1;
				} else
					digits=-1;
				if (n<256)
					s[n++]=c;
				c=read_char (f);
				++n_characters;
			}
		
			result=0;
			if (digits)
				if (dot==2 || ! (c=='e' || c=='E'))
					result=CLEAN_TRUE;
				else {
					if (n<256)
						s[n++]=c;
					c=read_char (f);
					++n_characters;
					
					if (c=='+'){
						c=read_char (f);
						++n_characters;
					} else
						if (c=='-'){
							if (n<256)
								s[n++]=c;
							c=read_char (f);
							++n_characters;
						}
					
					if (is_digit (c)){
						do {
							if (n<256)
								s[n++]=c;
							c=read_char (f);
							++n_characters;
						} while (is_digit (c));
		
						result=CLEAN_TRUE;
					}
				}
		
			if (n>=256)
				result=0;

			position+=n_characters;
		
			if (f->file_read_p > f->file_read_buffer_p)
				--f->file_read_p;
					
			*r_p=0.0;
			
			if (result){
				s[n]='\0';
				result= convert_string_to_real (s,r_p)==&s[n];
			}
			
			if (!result)
				f->file_error=-1;
		} else
			result=0;
		
		f->file_position=position;
		*position_p=position;
		
		return result;
	}
}

FilePositionT file_read_s_string
	(struct file *f,UNSIGNED_CLEAN_INT max_length,struct clean_string *s,FilePositionT *position_p)
{	
	unsigned long length;

	if (is_special_file (f)){
		if (f==file_table)
			IO_error ("sfreads: can't read from stderr");
		else if (f==&file_table[1])
			IO_error ("sfreads: can't read from stdio, use freads");
		else
			IO_error ("sfreads: can't open this file");
		return 0;
	} else {
		FilePositionT position;
		char *string;
		int c;

		position=*position_p;
		if (f->file_position!=position){
			if (f->file_unique)
				IO_error ("sfreads: can't read from a unique file");

			switch (position){
				case -1l:
					if (position!=f->file_position_2)
						position=f->file_position_2;
					else {
						position=f->file_offset + (f->file_write_p - f->file_write_buffer_p);
						f->file_position_2=position;
						break;
					}
				default:
					if (!simple_seek (f,position))
						IO_error ("sfreads: seek failed");
			}
		}

		length=0;
		string=s->characters;

		if (f->file_mode & (1<<F_READ_DATA)){
			while (length!=max_length && ((c=read_char (f))!=EOF)){
				*string++=c;
				++length;
			}
			position+=length;
		} else {
			while (length!=max_length && ((c=read_char (f))!=EOF)){
				if (c=='\r'){
					if (read_char (f)=='\n'){
						++position;
						c='\n';
					} else
						if (f->file_read_p > f->file_read_buffer_p)
							--f->file_read_p;
				}
			
				*string++=c;
				++length;
				++position;
			}		
		}
		
		s->length=length;

		f->file_position=position;
		*position_p=position;
		
		return length;
	}
}

UNSIGNED_CLEAN_INT file_read_s_line (struct file *f,UNSIGNED_CLEAN_INT max_length,char *string,FilePositionT *position_p)
{	
	unsigned long length;

	if (is_special_file (f)){
		if (f==file_table)
			IO_error ("sfreadline: can't read from stderr");
		else if (f==&file_table[1])
			IO_error ("sfreadline: can't read from stdio, use freadline");
		else
			IO_error ("sfreadline: can't open this file");
		return 0;
	} else {
		FilePositionT position;
		int c;
		
		position=*position_p;
		if (f->file_position!=position){
			if (f->file_unique)
				IO_error ("sfreadline: can't read from a unique file");
	
			if (f->file_mode & ~(1<<F_READ_TEXT))
				IO_error ("sfreadline: read from a data file");

			switch (position){
				case -1l:
					if (position!=f->file_position_2)
						position=f->file_position_2;
					else {
						position=f->file_offset + (f->file_write_p - f->file_write_buffer_p);
						f->file_position_2=position;
						break;
					}
				default:
					if (!simple_seek (f,position))
						IO_error ("sfreadline: seek failed");
			}
		}

		length=0;
		
		c=0;
		while (length!=max_length && ((c=read_char (f))!=EOF)){
			if (c=='\r'){
				if (read_char (f)=='\n'){
					++position;
					c='\n';
				} else
					if (f->file_read_p > f->file_read_buffer_p)
						--f->file_read_p;
			}

			*string++=c;
			++length;
			++position;
			if (c=='\n')
				break;
		}
		
		f->file_position=position;
		*position_p=position;
		
		if (c!='\n' && c!=EOF)
			return -1;
		
		return length;
	}
}

CLEAN_BOOL file_s_end (struct file *f,FilePositionT position)
{
	if (is_special_file (f)){
		if (f==file_table || f==&file_table[1])
			IO_error ("sfend: not allowed for stdio and stderr");
		else
			IO_error ("sfend: can't open file");
		return 0;
	} else {
		if (f->file_unique){
			if (f->file_mode & ~((1<<F_READ_TEXT) | (1<<F_READ_DATA)))
				IO_error ("sfend: not allowed for output files");
			
			if (f->file_read_p < f->file_end_read_buffer_p)
				return 0;
			
			if (f->file_offset < f->file_length)
				return 0;

			return CLEAN_TRUE;
		} else {
			if (position==-1l){
				if (f->file_position_2!=-1l)
					position=f->file_position_2;
				else {
					position=f->file_offset + (f->file_end_read_buffer_p - f->file_read_p);
					f->file_position=position;
					f->file_position_2=position;
				}
			}
		
			return (position==f->file_length) ? CLEAN_TRUE : 0;
		}
	}
}

FilePositionT file_s_position (struct file *f,FilePositionT position)
{
	if (is_special_file (f)){
		if (f==file_table || f==&file_table[1])
			IO_error ("sfposition: not allowed for stdio and stderr");
		else
			IO_error ("sfposition: can't open file");
		return 0;
	} else {
		if (f->file_unique){
			if (f->file_mode & ((1<<F_READ_TEXT) | (1<<F_READ_DATA)))
				position=f->file_offset - (f->file_end_read_buffer_p - f->file_read_p);
			else
				position=f->file_offset + (f->file_write_p - f->file_write_buffer_p);
		
			return position;
		} else {
			if (position==-1l){
				if (f->file_position_2!=-1l)
					return f->file_position_2;
				else {
					position=f->file_offset - (f->file_end_read_buffer_p - f->file_read_p);

					f->file_position=position;
					f->file_position_2=position;
				}
			}

			return position;
		}
	}
}

#define F_SEEK_SET 0
#define	F_SEEK_CUR 1
#define F_SEEK_END 2

CLEAN_BOOL file_s_seek (struct file *f,FilePositionT position,unsigned long seek_mode,FilePositionT *position_p)
{
	if (is_special_file (f)){
		if (seek_mode>(unsigned)2)
			IO_error ("sfseek: invalid mode");

		if (f==file_table)
			IO_error ("sfseek: can't seek on stdio");
		else if (f==&file_table[1])
			IO_error ("sfseek: can't seek on stderr");
		else
			IO_error ("sfseek: can't open file");
		return 0;
	} else {
		FilePositionT current_position;
		long buffer_size;
		int result;
			
		result=CLEAN_TRUE;

		if (f->file_unique)
			IO_error ("sfseek: can't seek on a unique file");
		
		current_position=f->file_offset - (f->file_end_read_buffer_p - f->file_read_p);
		
		if (*position_p==-1l){
			if (f->file_position_2!=-1l)
				*position_p=f->file_position_2;
			else {
				f->file_position_2=current_position;
				*position_p=current_position;
			}
		}
		
		switch (seek_mode){
			case F_SEEK_SET:
				break;
			case F_SEEK_CUR:
				position+=*position_p;				
				break;
			case F_SEEK_END:
				position=f->file_length+position;
				break;
			default:
				IO_error ("sfseek: invalid mode");
		}
		
		buffer_size=f->file_end_read_buffer_p - f->file_read_buffer_p;
		if ((FilePositionT)(position - (f->file_offset-buffer_size)) < buffer_size){
			f->file_read_p = f->file_read_buffer_p + (position - (f->file_offset-buffer_size));
			f->file_position=position;
		} else {
			unsigned char *buffer;
			FilePositionT file_position;

			if (position>f->file_length){
				f->file_error=-1;
				result=0;
				f->file_position=current_position;
			} else {
				unsigned int file_position_low,file_position_high;

				buffer=f->file_read_buffer_p;
				f->file_end_read_buffer_p=buffer;
				f->file_read_p=buffer;

#ifdef A64
				file_position_high=position>>32;
#else
				file_position_high=0;
#endif
				file_position_low=SetFilePointer (f->file_read_refnum,position,&file_position_high,FILE_BEGIN);
				
				if (file_position_low==-1 && GetLastError()!=NO_ERROR){
					f->file_error=-1;
					result=0;
				} else {
#ifdef A64
					file_position=file_position_low+((FilePositionT)file_position_high<<32);
#else
					file_position=file_position_low;
#endif
					f->file_offset=file_position;
				}
				f->file_position=position;
			}
		}
		
		*position_p=position;
		
		return result;
	}
}
