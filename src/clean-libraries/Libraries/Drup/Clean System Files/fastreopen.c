/*
	File:		wfileIO3.c
	Written by:	John van Groningen
	At:			University of Nijmegen
*/

#ifdef _WIN64
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

//#ifndef WINDOWS
//static
//#endif
extern struct file file_table[MAX_N_FILES];

static int number_of_files=FIRST_REAL_FILE;

#define is_special_file(f) ((CLEAN_INT)(f)<(CLEAN_INT)(&file_table[FIRST_REAL_FILE]))
/*
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
*/
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
/*
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
 			file_length=file_length_low+(file_length_high<<32);
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
 			file_length=file_length_low+(file_length_high<<32);
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
*/
static int stdio_open=0;
/*
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
*/
/*
struct file *open_stdio (void)
{
	if (stdio_open)
		IO_error ("stdio: already open");

	stdio_open=1;
	return &file_table[1];
}
*/
/*
struct file *open_stderr (void)
{
	return file_table;
}
*/
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
/*
CLEAN_BOOL flush_file_buffer (struct file *f)
{
	if (is_special_file (f)){
		if (f==&file_table[1] && std_output_to_file)
			return flush_write_buffer (f);

		return 1;
	}

	return flush_write_buffer (f);
}
*/
/*
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
*/
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

CLEAN_BOOL fast_re_open_file (struct file *f,unsigned int file_mode)
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

//AvW           OS(CloseHandle,DosClose) (f->file_read_refnum);
		} else {
			buffer=allocate_memory (FILE_IO_BUFFER_SIZE);
			if (buffer==NULL)
				IO_error ("freopen: out of memory");
			f->file_read_buffer_p=buffer;
			f->file_write_buffer_p=buffer;
		}

		f->file_mode=0;

#ifdef WINDOWS
//AvW            file_handle=CreateFileA (f->file_name,file_permission[file_mode],file_permission[file_mode]==GENERIC_READ ? FILE_SHARE_READ : 0,NULL,
//AvW                                    file_action_reopen[file_mode],FILE_ATTRIBUTE_NORMAL,NULL);
     	file_handle=f->file_read_refnum;				//AvW
		SetFilePointer (file_handle,0,NULL,FILE_BEGIN);	//AvW
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
 				file_length=file_length_low+(file_length_high<<32);
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
 				file_length=file_length_low+(file_length_high<<32);
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
