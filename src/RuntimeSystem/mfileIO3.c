/*
	File:		mfileIO3.c
	Written by:	John van Groningen
	At:			University of Nijmegen
*/

#define MAC

#if defined(powerc) || defined (MACHO)
#	define USE_CLIB 1
#	include <stdio.h>
#else
#	define USE_CLIB 0
#endif

#define NEWLINE_CHAR '\015'

#include "mcon.h"

extern void IO_error (char*);

#ifndef MACHO
# include <Traps.h>
#endif
#include <Memory.h>
#include <Files.h>
#include <Errors.h>
#include <Script.h>

#define EOF (-1)

#define MAX_N_FILES 20

#define MAX_FILE_NAME_LENGTH 255

#define FIRST_REAL_FILE 4

#define F_SEEK_SET 0
#define F_SEEK_CUR 1
#define F_SEEK_END 2

#define WRITE_STDERR_TO_FILE_MASK 128

#define pb_RefNum (((HIOParam*)&pb)->ioRefNum)
#define pb_Permssn (((HIOParam*)&pb)->ioPermssn)
#define pb_Misc (((HIOParam*)&pb)->ioMisc)
#define pb_PosMode (((HIOParam*)&pb)->ioPosMode)
#define pb_PosOffset (((HIOParam*)&pb)->ioPosOffset)
#define pb_Buffer (((HIOParam*)&pb)->ioBuffer)
#define pb_NamePtr (((HIOParam*)&pb)->ioNamePtr)
#define pb_VRefNum (((HIOParam*)&pb)->ioVRefNum)
#define pb_DirID (((HFileParam*)&pb)->ioDirID)
#define pb_FDirIndex (((HFileParam*)&pb)->ioFDirIndex)
#define pb_FlFndrInfo (((HFileParam*)&pb)->ioFlFndrInfo)
#define pb_ReqCount (((HIOParam*)&pb)->ioReqCount)
#define pb_ActCount (((HIOParam*)&pb)->ioActCount)

struct file {								/* 48 bytes */
	unsigned char *	file_read_p;			/* offset 0 */
	unsigned char *	file_write_p;			/* offset 4 */
	unsigned char *	file_end_buffer_p;		/* offset 8 */
	unsigned short	file_mode;				/* offset 12 */
	char			file_unique;			/* offset 14 */
	char			file_error;				/* offset 15 */

	unsigned char *	file_buffer_p;

	unsigned long	file_offset;
	unsigned long	file_length;

	char *			file_name;
	long			file_number;
	unsigned long	file_position;
	unsigned long	file_position_2;

	short			file_refnum;
	short			file_volume_number;
};

struct clean_string {
	long	length;
#if (defined (powerc) && !defined (__MRC__)) || defined (MACHO)
	char	characters[0];
#else
	char	characters[];
#endif
};

#ifdef MAC
#define allocate_memory NewPtr
#define free_memory DisposePtr
#else
#define allocate_memory malloc
#define free_memory free
#endif

static struct file file_table[MAX_N_FILES];

static int number_of_files=FIRST_REAL_FILE;

#define is_special_file(f) ((long)(f)<(long)(&file_table[3]))

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

static void copy_c_to_p_string (unsigned char *ps,char *cs,int max_length)
{
	unsigned char *p,*max_p;
	char c;
	
	p=ps+1;

	max_p=p+max_length;
	
	while ((c=*cs++)!=0){
		if (p>=max_p){
			*ps=0;
			return;
		}
		*p++ = c;
	}

	*ps=p-(ps+1);
}

static int get_file_number (char *file_name,long *file_number_p)
{
	unsigned char file_name_s[MAX_FILE_NAME_LENGTH+1];
	HFileParam fileParam;
	
	copy_c_to_p_string (file_name_s,file_name,MAX_FILE_NAME_LENGTH);
	if (file_name_s[0]==0)
		return 0;
	
	fileParam.ioFDirIndex=0;
	fileParam.ioNamePtr=file_name_s;
	fileParam.ioVRefNum=0;
	fileParam.ioFDirIndex=-1;
	fileParam.ioDirID=0;

	if (PBHGetFInfoSync ((HParmBlkPtr)&fileParam)!=noErr)
		return 0;

	*file_number_p=	fileParam.ioDirID;
	return 1;
}

static int get_volume_number (char *file_name,short *volume_number_p)
{
	HVolumeParam volumeParam;
	unsigned char file_name_s[MAX_FILE_NAME_LENGTH+1];
	
	copy_c_to_p_string (file_name_s,file_name,MAX_FILE_NAME_LENGTH);
	if (*file_name_s==0)
		return 0;

	volumeParam.ioVolIndex=-1;
	volumeParam.ioNamePtr=file_name_s;
	volumeParam.ioVRefNum=0;

	if (PBHGetVInfoSync ((HParmBlkPtr)&volumeParam)!=noErr)
		return 0;

	*volume_number_p=volumeParam.ioVRefNum;
	return 1;
}

static int file_exists (char *file_name,long *file_number_p,short *volume_number_p)
{
	int n;
	
	*volume_number_p=0;
	
	if (!get_file_number (file_name,file_number_p))
		return -2;
		
	if (!get_volume_number (file_name,volume_number_p))
		IO_error ("can't determine volume number while opening file");
	
	for (n=FIRST_REAL_FILE; n<number_of_files; ++n)
		if (file_table[n].file_mode!=0 &&
			file_table[n].file_number==*file_number_p &&
			file_table[n].file_volume_number==*volume_number_p)
		{
			return n;
		}
	
	return -1;
}

#define FILE_IO_BUFFER_SIZE (4*1024)

#define F_READ_TEXT 0
#define F_WRITE_TEXT 1
#define F_APPEND_TEXT 2
#define F_READ_DATA 3
#define F_WRITE_DATA 4
#define F_APPEND_DATA 5

#define ERROR_FILE ((struct file*)-(long)&file_table[2])

static char file_permission[] ={ fsRdPerm,fsWrPerm,fsWrPerm,fsRdPerm,fsWrPerm,fsWrPerm };

OSType new_file_creator='3PRM';

struct file *open_file (struct clean_string *file_name,unsigned int file_mode)
{
	unsigned char p_file_name[MAX_FILE_NAME_LENGTH+1];
	char *file_name_s;
	int fn,existing_fn;
	struct file *f;
	long file_length;
	long file_number;
	unsigned char *buffer;
	short file_refnum,volume_number;
	OSErr error;
	HParamBlockRec pb;
	unsigned int buffer_mask;

	buffer_mask = file_mode & ~255;
	if (buffer_mask<8192)
		buffer_mask=4095;
	else if (buffer_mask>65535)
		buffer_mask=65535;
	else {
		buffer_mask |= buffer_mask>>8;
		buffer_mask |= buffer_mask>>4;
		buffer_mask |= buffer_mask>>2;
		buffer_mask |= buffer_mask>>1;
		buffer_mask = (buffer_mask>>1) | 4095;
	}
	
	file_mode &= 255;	
	
	if (file_mode>5)
		IO_error ("fopen: invalid file mode");
	
	file_name_s=clean_to_c_string (file_name);
	if (file_name_s==NULL){
		IO_error ("fopen: out of memory");
		return ERROR_FILE;
	}

	existing_fn=file_exists (file_name_s,&file_number,&volume_number);
	
	if (existing_fn>=0){
		free_memory (file_name_s);
		return ERROR_FILE;
/*		IO_error ("fopen: file already open"); */
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

	f->file_number=file_number;
	f->file_volume_number=volume_number;	
	
	copy_c_to_p_string (p_file_name,file_name_s,MAX_FILE_NAME_LENGTH);
	
	if (existing_fn==-2 && ((1<<file_mode) & ((1<<F_WRITE_TEXT)|(1<<F_WRITE_DATA)))){
		pb_NamePtr=p_file_name;
		pb_VRefNum=0;
		pb_DirID=0;

		/* may be use HCreate, which also sets creator and filetype ? */
		
		error=PBHCreateSync ((void*)&pb);
		if (error!=noErr){
			free_memory (file_name_s);
			return ERROR_FILE;
		}
		
		pb_VRefNum=0;
		pb_DirID=0;
		pb_FDirIndex=0;

		if (PBHGetFInfoSync ((void*)&pb)==noErr){
			pb_VRefNum=0;
			pb_DirID=0;
			pb_FlFndrInfo.fdCreator=new_file_creator;
			if ((1<<file_mode) & (1<<F_WRITE_TEXT))
				pb_FlFndrInfo.fdType='TEXT';
			PBHSetFInfoSync ((void*)&pb);
		}
	}

	pb_NamePtr=p_file_name;
	pb_VRefNum=0;
	pb_DirID=0;
	pb_Misc=(Ptr)0;
	pb_Permssn=file_permission[file_mode];
	
	error=PBHOpenSync ((void*)&pb);
	if (error!=noErr){
		free_memory (file_name_s);
		return ERROR_FILE;
	}

	file_refnum=pb_RefNum;
		
	buffer=allocate_memory (buffer_mask+1);
	if (buffer==NULL){
		free_memory (file_name_s);
		pb_RefNum=file_refnum;
		PBCloseSync ((ParmBlkPtr)&pb);
		IO_error ("fopen: out of memory");
	}
	
	f->file_buffer_p=buffer;
	f->file_end_buffer_p=buffer;
	f->file_read_p=buffer;
	f->file_write_p=buffer;

	f->file_offset=0;
	
	switch (file_mode){
		case F_WRITE_TEXT:
		case F_WRITE_DATA:
			pb_RefNum=file_refnum;
			pb_Misc=(Ptr)0;

			error=PBSetEOFSync ((ParmBlkPtr)&pb);

			if (error!=noErr){
				free_memory (file_name_s);
				free_memory (buffer);				
				pb_RefNum=file_refnum;
				PBCloseSync ((ParmBlkPtr)&pb);
				IO_error ("fopen: can't set eof");			
			}

			file_length=0;
			break;
		case F_APPEND_TEXT:
		case F_APPEND_DATA:		
			pb_RefNum=file_refnum;
			pb_PosMode=fsFromLEOF;
			pb_PosOffset=0;

			error=PBSetFPosSync ((ParmBlkPtr)&pb);
						
			if (error!=noErr){
				free_memory (file_name_s);
				free_memory (buffer);
				pb_RefNum=file_refnum;
				PBCloseSync ((ParmBlkPtr)&pb);
				IO_error ("fopen: can't seek to eof");
			}

			file_length=pb_PosOffset;
			f->file_offset=file_length;

			break;
		default:
			pb_RefNum=file_refnum;
			
			error=PBGetEOFSync ((ParmBlkPtr)&pb);
			
			file_length=(long)pb_Misc;

			if (error!=noErr){
				free_memory (file_name_s);
				free_memory (buffer);
				pb_RefNum=file_refnum;
				PBCloseSync ((ParmBlkPtr)&pb);
				IO_error ("fopen: can't get eof");
			}
	}
	
	f->file_mode=(1<<file_mode) | (buffer_mask & ~255);
	f->file_unique=1;
	f->file_error=0;
	
	f->file_name=file_name_s;
	f->file_length=file_length;
	f->file_position=-2;
	f->file_position_2=-1;
	f->file_refnum=file_refnum;
	
	if (fn>=number_of_files)
		number_of_files=fn+1;
	
	return f;
}

static int stdio_open=0;

struct file *open_stdio (void)
{
	if (stdio_open)
		IO_error ("stdio: already open");

	stdio_open=1;
	return &file_table[1];
}

static int open_stderr_file_failed=0;

static int open_stderr_file (void)
{
	unsigned char p_file_name[MAX_FILE_NAME_LENGTH+1];
	char *file_name_s;
	int existing_fn;
	struct file *f;
	long file_length;
	long file_number;
	unsigned char *buffer;
	short file_refnum,volume_number;
	OSErr error;
	unsigned int file_mode;
	HParamBlockRec pb;

	file_name_s="Messages";

	file_mode=F_WRITE_TEXT;
		
	if (!get_file_number (file_name_s,&file_number))
		existing_fn=-2;
	else {
		if (!get_volume_number (file_name_s,&volume_number))
			IO_error ("can't determine volume number while opening file");

		existing_fn=-1;
	}

	f=&file_table[3];
	f->file_number=file_number;
	f->file_volume_number=volume_number;	
	
	copy_c_to_p_string (p_file_name,file_name_s,MAX_FILE_NAME_LENGTH);
	
	if (existing_fn==-2){
		pb_NamePtr=p_file_name;
		pb_VRefNum=0;
		pb_DirID=0;
		
		error=PBHCreateSync ((void*)&pb);
		if (error!=noErr){
			open_stderr_file_failed=1;
			return 0;
		}
		
		pb_VRefNum=0;
		pb_DirID=0;
		pb_FDirIndex=0;

		if (PBHGetFInfoSync ((void*)&pb)==noErr){
			pb_VRefNum=0;
			pb_DirID=0;
			pb_FlFndrInfo.fdCreator=new_file_creator;
			pb_FlFndrInfo.fdType='TEXT';
			PBHSetFInfoSync ((void*)&pb);
		}
	}

	pb_NamePtr=p_file_name;
	pb_VRefNum=0;
	pb_DirID=0;
	pb_Misc=(Ptr)0;
	pb_Permssn=file_permission[file_mode];
	
	error=PBHOpenSync ((void*)&pb);
	if (error!=noErr){
		open_stderr_file_failed=1;
		return 0;
	}

	file_refnum=pb_RefNum;
		
	buffer=allocate_memory (4096);
	if (buffer==NULL){
		pb_RefNum=file_refnum;
		PBCloseSync ((ParmBlkPtr)&pb);
		IO_error ("fopen: out of memory");
	}
	
	f->file_buffer_p=buffer;
	f->file_end_buffer_p=buffer;
	f->file_read_p=buffer;
	f->file_write_p=buffer;
	f->file_offset=0;
	
	pb_RefNum=file_refnum;
	pb_Misc=(Ptr)0;

	error=PBSetEOFSync ((ParmBlkPtr)&pb);

	if (error!=noErr){
		free_memory (buffer);				
		pb_RefNum=file_refnum;
		PBCloseSync ((ParmBlkPtr)&pb);
		IO_error ("fopen: can't set eof");			
	}

	file_length=0;
	
	f->file_mode=(1<<file_mode);
	f->file_unique=1;
	f->file_error=0;
	
	f->file_name=file_name_s;
	f->file_length=file_length;
	f->file_position=-2;
	f->file_position_2=-1;
	f->file_refnum=file_refnum;
		
	return 1;
}

extern long flags;

struct file *open_stderr (void)
{
	if ((flags & WRITE_STDERR_TO_FILE_MASK) && file_table[3].file_mode==0 && !open_stderr_file_failed)
		open_stderr_file();
	
	return file_table;
}

static int flush_write_buffer (struct file *f)
{	
	if (f->file_mode & ((1<<F_WRITE_TEXT)|(1<<F_WRITE_DATA)|(1<<F_APPEND_TEXT)|(1<<F_APPEND_DATA))){
		unsigned char *buffer;
		
		buffer=f->file_buffer_p;
		if (buffer!=f->file_end_buffer_p){
			OSErr error;
			long count;

			count=f->file_write_p-buffer;

			if (count==0)
				error=0;
			else {
				HParamBlockRec pb;

				pb_RefNum=f->file_refnum;
				pb_Buffer=buffer;
				pb_ReqCount=count;
				
				pb_PosMode=fsAtMark;
				pb_PosOffset=0;

				error=PBWriteSync ((ParmBlkPtr)&pb);
				
				count=pb_ActCount;

				f->file_offset = pb_PosOffset;
			}
			
			if (f->file_offset > f->file_length)
				f->file_length=f->file_offset;
		
			f->file_end_buffer_p=buffer;
			f->file_read_p=buffer;
		
			if (error!=noErr || count!=f->file_write_p-buffer){
				f->file_write_p=buffer;
				f->file_error=-1;
				return 0;
			}

			f->file_write_p=buffer;
		}
	}
	
	return 1;
}

int close_file (struct file *f)
{
	if (is_special_file (f)){
		if (f==&file_table[1]){
			if (!stdio_open)
				IO_error ("fclose: file not open (stdio)");
			stdio_open=0;
		}
		return -1;
	} else {
		HParamBlockRec pb;
		int result;
	
		if (f->file_mode==0)
			IO_error ("fclose: file not open");

		result=-1;

		if (f->file_error)
			result=0;
		
		if (! flush_write_buffer (f))
			result=0;
				
		pb_RefNum=f->file_refnum;
		if (PBCloseSync ((ParmBlkPtr)&pb)!=0)
			result=0;

		free_memory (f->file_name);
		free_memory (f->file_buffer_p);
		
		f->file_mode=0;

		return result;
	}
}

void close_stderr_file (void)
{
	if ((flags & WRITE_STDERR_TO_FILE_MASK) && file_table[3].file_mode!=0){
		HParamBlockRec pb;
		struct file *f;
		
		f=&file_table[3];

		flush_write_buffer (f);
				
		pb_RefNum=f->file_refnum;
		PBCloseSync ((ParmBlkPtr)&pb);

		free_memory (f->file_buffer_p);
		
		f->file_mode=0;
	}
}

int re_open_file (struct file *f,unsigned int file_mode)
{
	HParamBlockRec pb;
	unsigned int buffer_mask;
	
	buffer_mask = file_mode & ~255;
	if (buffer_mask<8192)
		buffer_mask=4095;
	else if (buffer_mask>65535)
		buffer_mask=65535;
	else {
		buffer_mask |= buffer_mask>>8;
		buffer_mask |= buffer_mask>>4;
		buffer_mask |= buffer_mask>>2;
		buffer_mask |= buffer_mask>>1;
		buffer_mask = (buffer_mask>>1) | 4095;
	}

	file_mode &= 255;

	if (file_mode>5)
		IO_error ("freopen: invalid file mode");

	if (is_special_file (f)){
		if (f==file_table && (file_mode==F_READ_TEXT || file_mode==F_READ_DATA))
			IO_error ("freopen: stderr can't be opened for reading");
		if (f==&file_table[2])
			IO_error ("freopen: file not open");
		return -1;
	} else {	
		long file_length;
		unsigned char p_file_name[MAX_FILE_NAME_LENGTH+1];
		int result;
		unsigned char *buffer;
		short file_refnum;
		OSErr error;

		result=-1;

		if (f->file_mode!=0){	
			flush_write_buffer (f);

			pb_RefNum=f->file_refnum;
			PBCloseSync ((ParmBlkPtr)&pb);

			if ((f->file_mode | 255)!=buffer_mask){
				free_memory (f->file_buffer_p);
		
				buffer=allocate_memory (buffer_mask+1);
				if (buffer==NULL)
					IO_error ("freopen: out of memory");
				f->file_buffer_p=buffer;
			}
		} else {
			buffer=allocate_memory (buffer_mask+1);
			if (buffer==NULL)
				IO_error ("freopen: out of memory");
			f->file_buffer_p=buffer;
		}

		f->file_mode=0;

		copy_c_to_p_string (p_file_name,f->file_name,MAX_FILE_NAME_LENGTH);

		pb_NamePtr=p_file_name;
		pb_VRefNum=0;
		pb_DirID=0;
		pb_Misc=(Ptr)0;
		pb_Permssn=file_permission[file_mode];
	
		error=PBHOpenSync ((void*)&pb);
		if (error!=noErr){
			free_memory (f->file_name);
			free_memory (f->file_buffer_p);
			return 0;
		}

		file_refnum=pb_RefNum;

		f->file_offset=0;

		switch (file_mode){
			case F_WRITE_TEXT:
			case F_WRITE_DATA:
				pb_RefNum=file_refnum;
				pb_Misc=(Ptr)0;

				error=PBSetEOFSync ((ParmBlkPtr)&pb);
				
				if (error!=noErr){
					free_memory (f->file_name);
					free_memory (f->file_buffer_p);
					pb_RefNum=file_refnum;
					PBCloseSync ((ParmBlkPtr)&pb);
					IO_error ("freopen: can't set eof");			
				}

				file_length=0;
				break;
			case F_APPEND_TEXT:
			case F_APPEND_DATA:
				pb_RefNum=file_refnum;
				pb_PosMode=fsFromLEOF;
				pb_PosOffset=0;

				error=PBSetFPosSync ((ParmBlkPtr)&pb);
			
				if (error!=noErr){
					free_memory (f->file_name);
					free_memory (f->file_buffer_p);
					pb_RefNum=file_refnum;
					PBCloseSync ((ParmBlkPtr)&pb);
					IO_error ("freopen: can't seek to eof");
				}

				file_length=pb_PosOffset;
				f->file_offset=file_length;
				break;
			default:
				pb_RefNum=file_refnum;
				
				error=PBGetEOFSync ((ParmBlkPtr)&pb);
				
				file_length=(long)pb_Misc;

				if (error!=noErr){
					free_memory (f->file_name);
					free_memory (f->file_buffer_p);
					pb_RefNum=file_refnum;
					PBCloseSync ((ParmBlkPtr)&pb);
					IO_error ("freopen: can't get eof");
				}
		}
	
		f->file_refnum=file_refnum;
		f->file_mode= (1<<file_mode) | (buffer_mask & ~255);
		f->file_length=file_length;
		f->file_position=-2;
		f->file_position_2=-1;
		f->file_error=0;

		buffer=f->file_buffer_p;
		f->file_end_buffer_p=buffer;
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

	count=((f->file_mode | 255)+1) - (f->file_offset & (f->file_mode | 255));
	buffer=f->file_buffer_p;
	
	*buffer=c;
	f->file_write_p=buffer+1;
	buffer+=count;
	f->file_end_buffer_p=buffer;
	f->file_read_p=buffer;
}

#if defined (__MWERKS__) || defined (powerc)
#define write_char(c,f) if ((f)->file_write_p<(f)->file_end_buffer_p) \
		*((f)->file_write_p)++=(c); \
	else \
		char_to_new_buffer((c),(f))
#else
#define write_char(c,f) ((f)->file_write_p<(f)->file_end_buffer_p ? (*((f)->file_write_p)++=(c)) : char_to_new_buffer((c),(f)))
#endif

static int char_from_new_buffer (struct file *f)
{
	OSErr error;
	long count;
	unsigned char *buffer;
	HParamBlockRec pb;
	int c;
	
	count=((f->file_mode | 255)+1) - (f->file_offset & (f->file_mode | 255));
	buffer=f->file_buffer_p;

	pb_RefNum=f->file_refnum;
	pb_Buffer=buffer;
	pb_ReqCount=count;
	
	pb_PosMode=fsAtMark;
	pb_PosOffset=0;

	error=PBReadSync ((ParmBlkPtr)&pb);
	if (error==eofErr)
		error=noErr;
		
	count=pb_ActCount;

	f->file_offset = pb_PosOffset;

	if (error!=noErr)
		f->file_error=-1;
	
	if (error!=noErr || count==0){
		f->file_end_buffer_p=buffer;
		f->file_read_p=buffer;
		f->file_write_p=buffer;
		return EOF;
	}

	c=*buffer;
	f->file_read_p=buffer+1;
	buffer+=count;
	f->file_end_buffer_p=buffer;
	f->file_write_p=buffer;

	return c;
}

#define read_char(f) ((f)->file_read_p<(f)->file_end_buffer_p ? *((f)->file_read_p)++ : char_from_new_buffer(f))

int file_read_char (struct file *f)
{
	if (f->file_read_p < f->file_end_buffer_p)
		return *(f->file_read_p)++;
	else {
		if (is_special_file (f)){
			if (f==file_table)
				IO_error ("freadc: can't read from stderr");
			else if (f==&file_table[1])
				return w_get_char();
			else
				IO_error ("freadc: can't open this file");
		} else {
			if (! (f->file_mode & ((1<<F_READ_TEXT) | (1<<F_READ_DATA))))
				IO_error ("freadc: read from an output file");
		
			return char_from_new_buffer (f);
		}
	}
}

#define is_digit(n) ((unsigned)((n)-'0')<(unsigned)10)

int file_read_int (struct file *f,int *i_p)
{
	if (is_special_file (f)){
		if (f==file_table)
			IO_error ("freadi: can't read from stderr");
		else if (f==&file_table[1])
			return w_get_int (i_p);
		else
			IO_error ("freadi: can't open this file");
	} else {
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
			
			result=-1;
			
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
				unsigned int i;
				
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

			if (f->file_read_p > f->file_buffer_p)
				--f->file_read_p;

			return result;
		} else
			IO_error ("freadi: read from an output file");
		
		return -1;
	}
}

int file_read_real (struct file *f,double *r_p)
{
	if (is_special_file (f)){
		if (f==file_table)
			IO_error ("freadr: can't read from stderr");
		else if (f==&file_table[1])
			return w_get_real (r_p);
		else
			IO_error ("freadr: can't open this file");
	} else {
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
					result=-1;
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
		
						result=-1;
					}
				}
		
			if (n>=256)
				result=0;
		
			if (f->file_read_p > f->file_buffer_p)
				--f->file_read_p;
					
			*r_p=0.0;
			
			if (result){
				s[n]='\0';
#if USE_CLIB
				if (sscanf (s,"%lg",r_p)!=1)
					result=0;
				else
					result=-1;
#else
				result=convert_string_to_real (s,r_p);
#endif
			}
			
			if (!result)
				f->file_error=-1;

			return result;
		} else
			IO_error ("freadr: read from an output file");
		
		return -1;
	}
}

#define OLD_READ_STRING 0
#define OLD_WRITE_STRING 0

#if OLD_READ_STRING
unsigned long file_read_string (struct file *f,unsigned long max_length,struct clean_string *s)
{
#else
unsigned long file_read_characters (struct file *f,unsigned long *length_p,char *s)
{
	unsigned long max_length;
	
	max_length=*length_p;
#endif
	if (is_special_file (f)){
		if (f==file_table)
			IO_error ("freads: can't read from stderr");
		else if (f==&file_table[1]){
			unsigned long length;

#if OLD_READ_STRING
			length=w_get_string (s->characters,max_length);
			s->length=length;
#else
			length=w_get_string (s,max_length);
			*length_p=length;
#endif

			return length;
		} else
			IO_error ("freads: can't open this file");
	} else {
		unsigned char *string,*end_string,*begin_string;

		if (! (f->file_mode & ((1<<F_READ_TEXT) | (1<<F_READ_DATA))))
			IO_error ("freads: read from an output file");
		
#if OLD_READ_STRING
		string=s->characters;
#else
		string=s;
#endif
		begin_string=string;
		end_string=string+max_length;

		while (string<end_string){
			if (f->file_read_p < f->file_end_buffer_p){
				unsigned char *read_p;
				long n;

				read_p=f->file_read_p;
				
				n=f->file_end_buffer_p-read_p;
				if (n > end_string-string)
					n=end_string-string;
				
				do {
					*string++ = *read_p++;
				} while (--n);
			
				f->file_read_p=read_p;
			} else {
				unsigned long align_buffer_mask;
				
				/* (unsigned long) cast added to prevent apple mpw c compiler from generating incorrect code */
				align_buffer_mask=~((unsigned long)f->file_mode | 255);
				
				if ((f->file_offset+(end_string-string) & align_buffer_mask) != (f->file_offset & align_buffer_mask)){
/*				if (end_string-string>=FILE_IO_BUFFER_SIZE && (f->file_offset & (FILE_IO_BUFFER_SIZE-1))==0){ */
					OSErr error;
					long count;
					unsigned char *buffer;
					HParamBlockRec pb;
					
					count=end_string-string;
					
					if (f->file_offset+count < f->file_length)
						count = (f->file_offset+count & align_buffer_mask) - f->file_offset;
/*						count &= ~(FILE_IO_BUFFER_SIZE-1); */
										
					pb_RefNum=f->file_refnum;
					pb_Buffer=string;
					pb_ReqCount=count;
					
					pb_PosMode=fsAtMark;
					pb_PosOffset=0;
				
					error=PBReadSync ((ParmBlkPtr)&pb);
					if (error==eofErr)
						error=noErr;
						
					count=pb_ActCount;
					
					f->file_offset = pb_PosOffset;
				
					if (error!=noErr)
						f->file_error=-1;

					buffer=f->file_buffer_p;
					f->file_end_buffer_p=buffer;
					f->file_read_p=buffer;
					f->file_write_p=buffer;
					
					string+=count;
					
					if (error!=noErr || count==0)
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

#if OLD_READ_STRING
		return (s->length=string-begin_string);
#else
		return (*length_p=string-begin_string);
#endif
	}
}

unsigned long file_read_line (struct file *f,unsigned long max_length,char *string)
{
	if (is_special_file (f)){
		if (f==file_table)
			IO_error ("freadline: can't read from stderr");
		else if (f==&file_table[1])
			return w_get_line (string,max_length);
		else
			IO_error ("freadline: can't open this file");
	} else {
		unsigned char *end_string,*begin_string;
		int c;

		begin_string=string;
		end_string=string+max_length;
		
		c=0;

		if (f->file_mode & (1<<F_READ_TEXT)){
			while (string<end_string){
				if (f->file_read_p < f->file_end_buffer_p){
					unsigned char *read_p;
					long n;
					
					read_p=f->file_read_p;
					
					n=f->file_end_buffer_p-read_p;
					if (n > end_string-(unsigned char*)string)
						n=end_string-(unsigned char*)string;
					
					do {
						char ch;
						
						ch=*read_p++;
						*string++=ch;
						if (ch==NEWLINE_CHAR){
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
					if (c==NEWLINE_CHAR)
						return (unsigned char*)string-begin_string;
				}
			}
		} else if (f->file_mode & (1<<F_READ_DATA)){
			while (string<end_string){
				if (f->file_read_p < f->file_end_buffer_p){
					unsigned char *read_p;
					long n;

					read_p=f->file_read_p;

					n=f->file_end_buffer_p-read_p;
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
							} else if (read_p < f->file_end_buffer_p){
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
									if (read_p > f->file_buffer_p)
										--read_p;							

									f->file_read_p=read_p;
									return (unsigned char*)string-begin_string;
								} else {
									if (string<end_string){
										*string++='\xa';
										f->file_read_p=read_p;
										return (unsigned char*)string-begin_string;											
									} else {
										if (read_p > f->file_buffer_p)
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
								if (f->file_read_p > f->file_buffer_p)
									--f->file_read_p;
						} else {
							if (f->file_read_p > f->file_buffer_p)
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
	if (f->file_write_p < f->file_end_buffer_p)
		*(f->file_write_p)++=c;
	else {
		if (is_special_file (f)){
			if (f==file_table){
#if MACOSX
				if (!(flags & WRITE_STDERR_TO_FILE_MASK)){
					ew_print_char (c);
					return;
				}
#else
				ew_print_char (c);
				
				if (!(flags & WRITE_STDERR_TO_FILE_MASK))
					return;
#endif
				f=&file_table[3];
				if (f->file_mode==0){
					if (open_stderr_file_failed || !open_stderr_file())
						return;
				}
			
				if (f->file_write_p < f->file_end_buffer_p)
					*(f->file_write_p)++=c;
				else
					char_to_new_buffer (c,f);
				
				return;
			} else if (f==&file_table[1]){
				w_print_char (c);
				return;
			} else {
				IO_error ("fwritec: can't open this file");
				return;
			}
		}
		
		if (! (f->file_mode & ((1<<F_WRITE_TEXT)|(1<<F_WRITE_DATA)|(1<<F_APPEND_TEXT)|(1<<F_APPEND_DATA))))
			IO_error ("fwritec: write to an input file");
	
		char_to_new_buffer (c,f);
	}
}

#if !USE_CLIB
extern char *convert_int_to_string (char *string,int i);
extern char *convert_real_to_string (char *string,double *r_p);
#endif

void file_write_int (int i,struct file *f)
{	
	if (is_special_file (f)){
		if (f==file_table){
#if MACOSX
			if (!(flags & WRITE_STDERR_TO_FILE_MASK)){
				ew_print_int (i);
				return;
			}
#else
			ew_print_int (i);

			if (!(flags & WRITE_STDERR_TO_FILE_MASK))
				return;
#endif
			f=&file_table[3];			
			if (f->file_mode==0){
				if (open_stderr_file_failed || !open_stderr_file())
					return;
			}
		} else if (f==&file_table[1]){
			w_print_int (i);
			return;
		} else {
			IO_error ("fwritei: can't open this file");
			return;
		}
	}
	
	if (! (f->file_mode & ((1<<F_WRITE_TEXT)|(1<<F_WRITE_DATA)|(1<<F_APPEND_TEXT)|(1<<F_APPEND_DATA))))
		IO_error ("fwritei: write to an input file");
	
	if (f->file_mode & ((1<<F_WRITE_DATA)|(1<<F_APPEND_DATA))){
#if defined (powerc)
		/* work around bug in apple compiler for power macintosh */			
		write_char (i>>24,f);
		write_char (i>>16,f);
		write_char (i>>8,f);
		write_char (i,f);
#else
		int v=i;

		write_char (((char*)&v)[0],f);
		write_char (((char*)&v)[1],f);
		write_char (((char*)&v)[2],f);
		write_char (((char*)&v)[3],f);
#endif
	} else {
		unsigned char string[24],*end_p,*s;
		int length;

#if USE_CLIB
		sprintf (string,"%d",i);
		{
			char *p;
			
			length=0;
			for (p=string; *p; ++p)
				++length;
		}
#else
		end_p=convert_int_to_string (string,i);
		length=end_p-string;
#endif
		
		s=string;
		do {
			write_char (*s++,f);
		} while (--length);
	}
}

void file_write_real (double r,struct file *f)
{	
	if (is_special_file (f)){
		if (f==file_table){
#if MACOSX
			if (!(flags & WRITE_STDERR_TO_FILE_MASK)){
				ew_print_real (r);
				return;
			}
#else
			ew_print_real (r);

			if (!(flags & WRITE_STDERR_TO_FILE_MASK))
				return;
#endif			
			f=&file_table[3];
			if (f->file_mode==0){
				if (open_stderr_file_failed || !open_stderr_file())
					return;
			}
		} else if (f==&file_table[1]){
			w_print_real (r);
			return;
		} else {
			IO_error ("fwriter: can't open this file");
			return;
		}
	}
	
	if (! (f->file_mode & ((1<<F_WRITE_TEXT)|(1<<F_WRITE_DATA)|(1<<F_APPEND_TEXT)|(1<<F_APPEND_DATA))))
		IO_error ("fwriter: write to an input file");
	
	if (f->file_mode & ((1<<F_WRITE_DATA)|(1<<F_APPEND_DATA))){
#ifdef powerc
		/* work around bug in apple compiler for power macintosh */
		int i1,i2;
		
		i1=((int*)&r)[0];
		i2=((int*)&r)[1];
		
		write_char (i1>>24,f);
		write_char (i1>>16,f);
		write_char (i1>>8,f);
		write_char (i1,f);
		write_char (i2>>24,f);
		write_char (i2>>16,f);
		write_char (i2>>8,f);
		write_char (i2,f);			
#else
		double v=r;

		write_char (((char*)&v)[0],f);
		write_char (((char*)&v)[1],f);
		write_char (((char*)&v)[2],f);
		write_char (((char*)&v)[3],f);
		write_char (((char*)&v)[4],f);
		write_char (((char*)&v)[5],f);
		write_char (((char*)&v)[6],f);
		write_char (((char*)&v)[7],f);
#endif
	} else {
		unsigned char string[32],*end_p,*s;
		int length;

#if USE_CLIB
		sprintf (string,"%.15g",r);
		{
			char *p;
			
			length=0;
			for (p=string; *p; ++p)
				++length;
		}
#else			
		end_p=convert_real_to_string (string,&r);
		length=end_p-string;
#endif	
		s=string;
		do {
			write_char (*s++,f);
		} while (--length);
	}
}

#if OLD_WRITE_STRING
void file_write_string (struct clean_string *s,struct file *f)
#else
void file_write_characters (unsigned char *p,int length,struct file *f)
#endif
{	
	if (is_special_file (f)){
		if (f==file_table){
#if MACOSX
			if (!(flags & WRITE_STDERR_TO_FILE_MASK)){
				ew_print_text (p,length);
				return;
			}
#else
# if OLD_WRITE_STRING
			ew_print_text (s->characters,s->length);
# else
			ew_print_text (p,length);
# endif
			if (!(flags & WRITE_STDERR_TO_FILE_MASK))
				return;
#endif
		
			f=&file_table[3];
			if (f->file_mode==0){
				if (open_stderr_file_failed || !open_stderr_file())
					return;
			}
		} else if (f==&file_table[1]){
#if OLD_WRITE_STRING
			w_print_text (s->characters,s->length);
#else
			w_print_text (p,length);
#endif
			return;
		} else {
			IO_error ("fwrites: can't open this file");
			return;
		}
	}

	{
#if OLD_WRITE_STRING
		unsigned char *p,*end_p;
#else
		unsigned char *end_p;
#endif
		if (! (f->file_mode & ((1<<F_WRITE_TEXT)|(1<<F_WRITE_DATA)|(1<<F_APPEND_TEXT)|(1<<F_APPEND_DATA))))
			IO_error ("fwrites: write to an input file");
		
#if OLD_WRITE_STRING
		p=s->characters;
		end_p=p+s->length;
#else
		end_p=p+length;
#endif

		while (p<end_p){
			if (f->file_write_p < f->file_end_buffer_p){
				unsigned char *write_p;
				long n;
				
				write_p=f->file_write_p;
				
				n=f->file_end_buffer_p-write_p;
				if (n>end_p-p)
					n=end_p-p;
				
				do {
					*write_p++ = *p++;
				} while (--n);

				f->file_write_p=write_p;	
			} else
				char_to_new_buffer (*p++,f);
		}
	}
}

int file_end (struct file *f)
{
	if (f->file_read_p < f->file_end_buffer_p)
		return 0;

	if (is_special_file (f)){
		if (f==file_table || f==&file_table[1])
			IO_error ("fend: not allowed for stdio and stderr");
		else
			IO_error ("fend: can't open file");
	} else {
		if (! (f->file_mode & ((1<<F_READ_TEXT) | (1<<F_READ_DATA))))
			IO_error ("fend: not allowed for output files");
		
		if (f->file_offset < f->file_length)
			return 0;

		return -1;
	}
}

int file_error (struct file *f)
{
	if (is_special_file (f)){
		if (f==file_table || f==&file_table[1])
			return 0;
		else
			return -1;
	} else
		return f->file_error;
}

unsigned long file_position (struct file *f)
{
	if (is_special_file (f)){
		if (f==file_table || f==&file_table[1])
			IO_error ("fposition: not allowed for stdio and stderr");
		else
			IO_error ("fposition: can't open file");
	} else {
		unsigned long position;
		
		if (f->file_mode & ((1<<F_READ_TEXT) | (1<<F_READ_DATA)))
			position=f->file_offset - (f->file_end_buffer_p - f->file_read_p);
		else
			position=f->file_offset + (f->file_write_p - f->file_buffer_p);
		
		return position;
	}
}

int file_seek (struct file *f,unsigned long position,unsigned long seek_mode)
{
	HParamBlockRec pb;

	if (is_special_file (f)){
		if (seek_mode>(unsigned)2)
			IO_error ("fseek: invalid mode");

		if (f==file_table || f==&file_table[1])
			IO_error ("fseek: can't seek on stdio and stderr");
		else
			IO_error ("fseek: can't open file");
	} else {
		long current_position;
		unsigned long buffer_size;
	
		if (f->file_mode & ((1<<F_READ_TEXT) | (1<<F_READ_DATA))){
			current_position=f->file_offset - (f->file_end_buffer_p - f->file_read_p);
			
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
			
			buffer_size=f->file_end_buffer_p - f->file_buffer_p;
			if ((unsigned long)(position - (f->file_offset-buffer_size)) < buffer_size){
				f->file_read_p = f->file_buffer_p + (position - (f->file_offset-buffer_size));
				
				return -1;
			} else {
				unsigned char *buffer;
				OSErr error;
				
				if (position<0 || position>f->file_length){
					f->file_error=-1;
					return 0;
				}
				
				buffer=f->file_buffer_p;
				f->file_end_buffer_p=buffer;
				f->file_read_p=buffer;
				f->file_write_p=buffer;
				
				pb_RefNum=f->file_refnum;
				pb_PosMode=fsFromStart;
				pb_PosOffset=position;

				error=PBSetFPosSync ((ParmBlkPtr)&pb);

				f->file_offset=pb_PosOffset;
				
				if (error!=noErr){
					f->file_error=-1;
					return 0;
				}
				
				return -1;
			}
		} else {
			OSErr error;
			int result;

			result=-1;

			current_position=f->file_offset + (f->file_write_p - f->file_buffer_p);
			
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
				return -1;

			if (! flush_write_buffer (f)){
				f->file_error=-1;
				result=0;
			}
			
			if (position<0 || position>f->file_length){
				f->file_error=-1;
				return 0;
			}

			pb_RefNum=f->file_refnum;
			pb_PosMode=fsFromStart;
			pb_PosOffset=position;

			error=PBSetFPosSync ((ParmBlkPtr)&pb);

			f->file_offset=pb_PosOffset;

			if (error!=noErr){
				f->file_error=-1;
				result=0;
			}
			
			return result;
		}
	}
}

struct file *open_s_file (struct clean_string *file_name,unsigned int file_mode)
{
	unsigned char p_file_name[MAX_FILE_NAME_LENGTH+1];
	int fn,existing_fn;
	char *file_name_s;
	struct file *f;
	long file_length;
	long file_number;
	short volume_number,file_refnum;
	unsigned char *buffer;
	OSErr error;
	HParamBlockRec pb;
	unsigned int buffer_mask;
	
	buffer_mask = file_mode & ~255;
	if (buffer_mask<8192)
		buffer_mask=4095;
	else if (buffer_mask>65535)
		buffer_mask=65535;
	else {
		buffer_mask |= buffer_mask>>8;
		buffer_mask |= buffer_mask>>4;
		buffer_mask |= buffer_mask>>2;
		buffer_mask |= buffer_mask>>1;
		buffer_mask = (buffer_mask>>1) | 4095;
	}

	file_mode &= 255;

	if (file_mode!=F_READ_TEXT && file_mode!=F_READ_DATA)
		IO_error ("sfopen: invalid file mode");
	
	file_name_s=clean_to_c_string (file_name);
	if (file_name_s==NULL){
		IO_error ("sfopen: out of memory");
		return ERROR_FILE;
	}	
	
	existing_fn=file_exists (file_name_s,&file_number,&volume_number);

	if (existing_fn>=0){
		if (file_table[existing_fn].file_unique)
			IO_error ("sfopen: file already opened by fopen");

		if ((file_table[existing_fn].file_mode & 255)!=(1<<file_mode))
			IO_error ("sfopen: file already open in another file mode");
		
		free_memory (file_name_s);
		
		return &file_table[existing_fn];
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

	f->file_number=file_number;
	f->file_volume_number=volume_number;	

	copy_c_to_p_string (p_file_name,file_name_s,MAX_FILE_NAME_LENGTH);
	
	pb_NamePtr=p_file_name;
	pb_VRefNum=0;
	pb_DirID=0;
	pb_Misc=(Ptr)0;
	pb_Permssn=file_permission[file_mode];
	
	error=PBHOpenSync ((void*)&pb);
	if (error!=noErr){
		free_memory (file_name_s);
		return ERROR_FILE;
	}

	file_refnum=pb_RefNum;
	
	buffer=allocate_memory (buffer_mask+1);
	if (buffer==NULL){
		free_memory (file_name_s);
		pb_RefNum=file_refnum;
		PBCloseSync ((ParmBlkPtr)&pb);
		IO_error ("sfopen: out of memory");
	}

	f->file_buffer_p=buffer;
	f->file_end_buffer_p=buffer;
	f->file_read_p=buffer;
	f->file_write_p=buffer;

	f->file_offset=0;

	pb_RefNum=file_refnum;
	
	error=PBGetEOFSync ((ParmBlkPtr)&pb);
	
	file_length=(long)pb_Misc;

	if (error!=noErr){
		free_memory (file_name_s);
		free_memory ((char*)buffer);
		pb_RefNum=file_refnum;
		PBCloseSync ((ParmBlkPtr)&pb);
		IO_error ("sfopen: can't get eof");
	}

	f->file_refnum=file_refnum;
	f->file_mode= (1<<file_mode) | (buffer_mask & ~255);
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

static int simple_seek (struct file *f,long position)
{
	int result;
	long buffer_size;
	HParamBlockRec pb;

	result=1;
	
	buffer_size=f->file_end_buffer_p - f->file_buffer_p;
	if ((unsigned long)(position - (f->file_offset-buffer_size)) < buffer_size){
		f->file_read_p = f->file_buffer_p + (position - (f->file_offset-buffer_size));
		f->file_position=position;
	} else {
		unsigned char *buffer;
		OSErr error;
		
		if (position<0 || position>f->file_length){
			f->file_error=-1;
			result=0;
		} else {
			buffer=f->file_buffer_p;
			f->file_end_buffer_p=buffer;
			f->file_read_p=buffer;
			f->file_write_p=buffer;

			pb_RefNum=f->file_refnum;
			pb_PosMode=fsFromStart;
			pb_PosOffset=position;

			error=PBSetFPosSync ((ParmBlkPtr)&pb);

			f->file_offset=pb_PosOffset;
			
			if (error!=noErr){
				f->file_error=-1;
				result=0;
			}
			f->file_position=position;
		}
	}
	
	return result;
}

int file_read_s_char (struct file *f,unsigned long *position_p)
{	
	if (is_special_file (f)){
		if (f==file_table)
			IO_error ("sfreadc: can't read from stderr");
		else if (f==&file_table[1])
			IO_error ("sfreadc: can't read from stdio, use freadc");
		else
			IO_error ("sfreadc: can't open this file");
	} else {
		int c;
		unsigned long position;

		position=*position_p;

		if (f->file_position!=position){
			if (f->file_unique)
				IO_error ("sfreadc: can't read from a unique file");
			
			switch (position){
				case -1l:
					if (position!=f->file_position_2)
						position=f->file_position_2;
					else {
						position=f->file_offset + (f->file_write_p - f->file_buffer_p);
						f->file_position_2=position;
						break;
					}
				default:
					if (!simple_seek (f,position))
						IO_error ("sfreadc: seek failed");
			}
		}

		if (f->file_read_p < f->file_end_buffer_p){
			c=*f->file_read_p++;
			++position;
		} else {
			c=char_from_new_buffer(f);
			if (c!=EOF)
				++position;
		}

		f->file_position=position;
		*position_p=position;

		return c;
	}
}

int file_read_s_int (struct file *f,int *i_p,unsigned long *position_p)
{
	if (is_special_file (f)){
		if (f==file_table)
			IO_error ("sfreadi: can't read from stderr");
		else if (f==&file_table[1])
			IO_error ("sfreadi: can't read from stdio, use freadi");
		else
			IO_error ("sfreadi: can't open this file");
	} else {
		int result;
		unsigned long position;

		position=*position_p;
		
		if (f->file_position!=position){
			if (f->file_unique)
				IO_error ("sfreadi: can't read from a unique file");

			switch (position){
				case -1l:
					if (position!=f->file_position_2)
						position=f->file_position_2;
					else {
						position=position=f->file_offset + (f->file_write_p - f->file_buffer_p);
						f->file_position_2=position;
						break;
					}
				default:
					if (!simple_seek (f,position))
						IO_error ("sfreadi: seek failed");
			}
		}
		
		*i_p=0;
		
		result=-1;
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

			if (f->file_read_p > f->file_buffer_p)
				--f->file_read_p;
		}

		f->file_position=position;
		*position_p=position;
		
		return result;
	}
}

int file_read_s_real (struct file *f,double *r_p,unsigned long *position_p)
{
	if (is_special_file (f)){
		if (f==file_table)
			IO_error ("sfreadr: can't read from stderr");
		else if (f==&file_table[1])
			IO_error ("sfreadr: can't read from stdio, use freadr");
		else
			IO_error ("sfreadr: can't open this file");
	} else {
		int result;
		unsigned long position;
		
		position=*position_p;
		if (f->file_position!=position){
			if (f->file_unique)
				IO_error ("sfreadr: can't read from a unique file");

			switch (position){
				case -1l:
					if (position!=f->file_position_2)
						position=f->file_position_2;
					else {
						position=position=f->file_offset + (f->file_write_p - f->file_buffer_p);
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

			result=-1;
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
			int c,dot,digits,result,n,n_characters;
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
					result=-1;
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
		
						result=-1;
					}
				}
		
			if (n>=256)
				result=0;

			position+=n_characters;
		
			if (f->file_read_p > f->file_buffer_p)
				--f->file_read_p;
					
			*r_p=0.0;
			
			if (result){
				s[n]='\0';
#if USE_CLIB
				if (sscanf (s,"%lg",r_p)!=1)
					result=0;
				else
					result=-1;
#else
				result=convert_string_to_real (s,r_p);
#endif
			}
			
			if (!result)
				f->file_error=-1;
		}
		
		f->file_position=position;
		*position_p=position;
		
		return result;
	}
}

unsigned long file_read_s_string
	(struct file *f,unsigned long max_length,struct clean_string *s,unsigned long *position_p)
{	
	unsigned long length;

	if (is_special_file (f)){
		if (f==file_table)
			IO_error ("sfreads: can't read from stderr");
		else if (f==&file_table[1])
			IO_error ("sfreads: can't read from stdio, use freads");
		else
			IO_error ("sfreads: can't open this file");
	} else {
		unsigned long position;
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
						position=f->file_offset + (f->file_write_p - f->file_buffer_p);
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

		while (length!=max_length && ((c=read_char (f))!=EOF)){
			*string++=c;
			++length;
		}
		
		s->length=length;

		position+=length;

		f->file_position=position;
		*position_p=position;
		
		return length;
	}
}

unsigned long file_read_s_line
	(struct file *f,unsigned long max_length,char *string,unsigned long *position_p)
{	
	unsigned long length;

	if (is_special_file (f)){
		if (f==file_table)
			IO_error ("sfreadline: can't read from stderr");
		else if (f==&file_table[1])
			IO_error ("sfreadline: can't read from stdio, use freadline");
		else
			IO_error ("sfreadline: can't open this file");
	} else {
		unsigned long position;
		int c;
		
		position=*position_p;
		if (f->file_position!=position){
			if (f->file_unique)
				IO_error ("sfreadline: can't read from a unique file");
	
			if (! (f->file_mode & (1<<F_READ_TEXT)))
				IO_error ("sfreadline: read from a data file");

			switch (position){
				case -1l:
					if (position!=f->file_position_2)
						position=f->file_position_2;
					else {
						position=f->file_offset + (f->file_write_p - f->file_buffer_p);
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
			*string++=c;
			++length;
			if (c==NEWLINE_CHAR)
				break;
		}
		
		position+=length;
		
		f->file_position=position;
		*position_p=position;
		
		if (c!=NEWLINE_CHAR && c!=EOF)
			return -1;
		
		return length;
	}
}

int file_s_end (struct file *f,unsigned long position)
{
	if (is_special_file (f)){
		if (f==file_table || f==&file_table[1])
			IO_error ("sfend: not allowed for stdio and stderr");
		else
			IO_error ("sfend: can't open file");
	} else {
		if (f->file_unique){
			if (! (f->file_mode & ((1<<F_READ_TEXT) | (1<<F_READ_DATA))))
				IO_error ("sfend: not allowed for output files");
			
			if (f->file_read_p < f->file_end_buffer_p)
				return 0;
			
			if (f->file_offset < f->file_length)
				return 0;

			return -1;
		} else {
			if (position==-1l){
				if (f->file_position_2!=-1l)
					position=f->file_position_2;
				else {
					position=f->file_offset + (f->file_end_buffer_p - f->file_read_p);
					f->file_position=position;
					f->file_position_2=position;
				}
			}
		
			return (position==f->file_length) ? -1 : 0;
		}
	}
}

unsigned long file_s_position (struct file *f,unsigned long position)
{
	if (is_special_file (f)){
		if (f==file_table || f==&file_table[1])
			IO_error ("sfposition: not allowed for stdio and stderr");
		else
			IO_error ("sfposition: can't open file");
	} else {
		if (f->file_unique){
			if (f->file_mode & ((1<<F_READ_TEXT) | (1<<F_READ_DATA)))
				position=f->file_offset - (f->file_end_buffer_p - f->file_read_p);
			else
				position=f->file_offset + (f->file_write_p - f->file_buffer_p);
		
			return position;
		} else {
			if (position==-1l){
				if (f->file_position_2!=-1l)
					return f->file_position_2;
				else {
					position=f->file_offset - (f->file_end_buffer_p - f->file_read_p);

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

int file_s_seek (struct file *f,unsigned long position,unsigned long seek_mode,unsigned long *position_p)
{
	HParamBlockRec pb;

	if (is_special_file (f)){
		if (seek_mode>(unsigned)2)
			IO_error ("sfseek: invalid mode");

		if (f==file_table)
			IO_error ("sfseek: can't seek on stdio");
		else if (f==&file_table[1])
			IO_error ("sfseek: can't seek on stderr");
		else
			IO_error ("sfseek: can't open file");
	} else {
		long current_position,buffer_size;
		int result;
			
		result=-1;
	
		if (f->file_unique)
			IO_error ("sfseek: can't seek on a unique file");
		
		current_position=f->file_offset - (f->file_end_buffer_p - f->file_read_p);
		
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
		
		buffer_size=f->file_end_buffer_p - f->file_buffer_p;
		if ((unsigned long)(position - (f->file_offset-buffer_size)) < buffer_size){
			f->file_read_p = f->file_buffer_p + (position - (f->file_offset-buffer_size));
			f->file_position=position;
		} else {
			unsigned char *buffer;
			OSErr error;
			
			if (position<0 || position>f->file_length){
				f->file_error=-1;
				result=0;
				f->file_position=current_position;
			} else {
				buffer=f->file_buffer_p;
				f->file_end_buffer_p=buffer;
				f->file_read_p=buffer;
				f->file_write_p=buffer;

				pb_RefNum=f->file_refnum;
				pb_PosMode=fsFromStart;
				pb_PosOffset=position;

				error=PBSetFPosSync ((ParmBlkPtr)&pb);

				f->file_offset=pb_PosOffset;
				
				if (error!=noErr){
					f->file_error=-1;
					result=0;
				}
				
				f->file_position=position;
			}
		}
		
		*position_p=position;
		
		return result;
	}
}

void er_print_char (char c)
{
#if MACOSX
	if (!(flags & WRITE_STDERR_TO_FILE_MASK))
		ew_print_char (c);
	else {
#else
	ew_print_char (c);
	
	if (flags & WRITE_STDERR_TO_FILE_MASK){
#endif
		struct file *f;
		
		f=&file_table[3];
		if (f->file_mode==0){
			if (open_stderr_file_failed || !open_stderr_file())
				return;
		}
	
		if (f->file_write_p < f->file_end_buffer_p)
			*(f->file_write_p)++=c;
		else
			char_to_new_buffer (c,f);
	}
}

void er_print_int (int i)
{
#if MACOSX
	if (!(flags & WRITE_STDERR_TO_FILE_MASK))
		ew_print_int (i);
	else {
#else
	ew_print_int (i);

	if (flags & WRITE_STDERR_TO_FILE_MASK){
#endif
		if (file_table[3].file_mode==0){
			if (open_stderr_file_failed || !open_stderr_file())
				return;
		}

		file_write_int (i,&file_table[3]);
	}
}

void er_print_real (double r)
{
#if MACOSX
	if (!(flags & WRITE_STDERR_TO_FILE_MASK))
		ew_print_real (r);
	else {
#else
	ew_print_real (r);

	if (flags & WRITE_STDERR_TO_FILE_MASK){
#endif
		if (file_table[3].file_mode==0){
			if (open_stderr_file_failed || !open_stderr_file())
				return;
		}

		file_write_real (r,&file_table[3]);
	}
}

static void write_chars (unsigned char *p,unsigned char *end_p,struct file *f)
{
	while (p<end_p){
		if (f->file_write_p < f->file_end_buffer_p){
			unsigned char *write_p;
			long n;
			
			write_p=f->file_write_p;
			
			n=f->file_end_buffer_p-write_p;
			if (n>end_p-p)
				n=end_p-p;
			
			do {
				*write_p++ = *p++;
			} while (--n);

			f->file_write_p=write_p;	
		} else
			char_to_new_buffer (*p++,f);
	}
}

void er_print_text (char *s,unsigned long length)
{
#if MACOSX	
	if (!(flags & WRITE_STDERR_TO_FILE_MASK))
		ew_print_text (s,length);
	else {
#else
	ew_print_text (s,length);
	
	if (flags & WRITE_STDERR_TO_FILE_MASK){
#endif
		struct file *f;
		
		f=&file_table[3];
		if (f->file_mode==0){
			if (open_stderr_file_failed || !open_stderr_file())
				return;
		}

		write_chars (s,s+length,f);
	}
}

void er_print_string (char *s)
{
#if MACOSX	
	if (!(flags & WRITE_STDERR_TO_FILE_MASK))
		ew_print_string (s);
	else {	
#else
	ew_print_string (s);
	
	if (flags & WRITE_STDERR_TO_FILE_MASK){
#endif
		unsigned char *end_p;
		struct file *f;
		
		f=&file_table[3];
		if (f->file_mode==0){
			if (open_stderr_file_failed || !open_stderr_file())
				return;
		}

		end_p=s;
		while (*end_p)
			++end_p;
		
		write_chars (s,end_p,f);
	}
}
