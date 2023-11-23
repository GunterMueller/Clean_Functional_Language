/*
	File:	ufileIO2.c
	Author:	John van Groningen
	At:		University of Nijmegen
*/

#ifdef applec
#	define MPW3
#endif

#include <stdio.h>
#include <stdlib.h>

#ifdef MPW3
#	include <string.h>
#endif

#if defined (__x86_64__) || defined (__aarch64__)
# define A64
#endif

#include "scon.h"

extern void IO_error (char*);

#ifdef GNU_C
# ifdef OS2
#	include <sys/types.h>
# endif
#	include <sys/stat.h>
#else
#	include <Traps.h>
#	include <Files.h>
#endif

#define MAX_N_FILES 20

#define MAX_FILE_NAME_LENGTH 128

#define FIRST_REAL_FILE 2

struct file {
	FILE			*file;
	unsigned long	position;
	unsigned long	file_length;
	char			*file_name;
	long			file_number;
#ifdef GNU_C
	int				device_number;
#else
	int				volume_number;
#endif
	short			mode;
	short			unique;
	unsigned long	position_2;
};

struct clean_string {
	long	length;
#if (defined (GNU_C) && !defined (SUN_C)) || defined (powerc)
	char	characters[0];
#else
	char	characters[];
#endif
};

#if defined (I486) || defined (ARM)
# define CLEAN_TRUE 1
#else
# define CLEAN_TRUE (-1)
#endif

static struct file file_table [MAX_N_FILES];

#ifdef LINUX
static void *buffers[MAX_N_FILES];
#endif

static int number_of_files=FIRST_REAL_FILE;

extern void *malloc();

static char *clean_to_c_string (struct clean_string *cs)
{
	int l;
	char *cp,*s,*sp;

	cp=cs->characters;
	l=cs->length;
	
	s=malloc (l+1);
	if (s==NULL)
		IO_error ("out of memory while opening file");
	
	for (sp=s; l!=0; --l)
		*sp++=*cp++;
	*sp='\0';
	
	return s;
}

#ifdef GNU_C

	static int get_file_number_and_device_number
		(char *file_name,long *file_number_p,int *device_number_p)
	{
		struct stat stat_buffer;
		
		if (stat (file_name,&stat_buffer))
			return 0;
		
		if ((stat_buffer.st_mode & S_IFMT)!=S_IFREG)
			return 0;
		
		*file_number_p=stat_buffer.st_ino;
		*device_number_p=stat_buffer.st_dev;
		return 1;
	}
	
	static int file_exists (char *file_name,long *file_number_p,int *device_number_p)
	{
		int n;
		
		if (!get_file_number_and_device_number (file_name,file_number_p,device_number_p))
			return -2;
		
		for (n=FIRST_REAL_FILE; n<number_of_files; ++n)
			if (file_table[n].file!=NULL &&
				file_table[n].file_number==*file_number_p &&
				file_table[n].device_number==*device_number_p)
			{
				return n;
			}
			
		return -1;
	}

#else

#ifdef THINK_C
	extern OSErr PBGetFInfo (ParmBlkPtr paramBlock,Boolean async);
#endif
	static int get_file_number (char *file_name,long *file_number_p)
	{
		FileParam fileParam;
		char file_name_s[MAX_FILE_NAME_LENGTH+2];
		int length;
		
		length=strlen (file_name);
		if (length>MAX_FILE_NAME_LENGTH)
			return 0;
		file_name_s[0]=length;
		strcpy (&file_name_s[1],file_name);
		
		fileParam.ioCompletion=NULL;
		fileParam.ioFDirIndex=0;
		fileParam.ioNamePtr=file_name_s;
		fileParam.ioFVersNum=0;
		fileParam.ioVRefNum=0;

#ifdef MPW3
		if (PBGetFInfo ((ParmBlkPtr)&fileParam,0)!=noErr)
#else
		if (PBGetFInfo (&fileParam,0)!=noErr)
#endif
			return 0;
		*file_number_p=fileParam.ioFlNum;
		return 1;
	}

#ifdef THINK_C	
	extern OSErr PBGetVInfo (ParmBlkPtr paramBlock,Boolean async);
#endif

	static int get_volume_number (char *file_name,int *volume_number_p)
	{
		VolumeParam volumeParam;
		char file_name_s[MAX_FILE_NAME_LENGTH+2];
		int length;
		
		length=strlen (file_name);
		if (length>MAX_FILE_NAME_LENGTH)
			return 0;
		file_name_s[0]=length;
		strcpy (&file_name_s[1],file_name);
	
		volumeParam.ioCompletion=NULL;
		volumeParam.ioVolIndex=-1;
		volumeParam.ioNamePtr=file_name_s;
		volumeParam.ioVRefNum=0;
#ifdef MPW3
		if (PBGetVInfo ((ParmBlkPtr)&volumeParam,0)!=noErr)
#else
		if (PBGetVInfo (&volumeParam,0)!=noErr)
#endif
			return 0;
		*volume_number_p=volumeParam.ioVRefNum;
		return 1;
	}
	
	static int file_exists (char *file_name,long *file_number_p,int *volume_number_p)
	{
		int n;
		
		if (!get_file_number (file_name,file_number_p))
			return -2;
			
		if (!get_volume_number (file_name,volume_number_p))
			IO_error ("can't determine volume number while opening file");
		
		for (n=FIRST_REAL_FILE; n<number_of_files; ++n)
			if (file_table[n].file!=NULL &&
				file_table[n].file_number==*file_number_p &&
				file_table[n].volume_number==*volume_number_p)
			{
				return n;
			}
		
		return -1;
	}

#endif

#define FILE_IO_BUFFER_SIZE (4*1024)

#define F_READ_TEXT 0
#define F_WRITE_TEXT 1
#define F_APPEND_TEXT 2
#define F_READ_DATA 3
#define F_WRITE_DATA 4
#define F_APPEND_DATA 5

static char *file_mode_string[] ={ "r","w","r+","rb","wb","r+b" };

long open_file (struct clean_string *file_name,unsigned int file_mode)
{
	FILE *fd;
	int fn,existing_fn;
	char *file_name_s;
	struct file *f;
	unsigned long file_length;
	long file_number;
#ifdef GNU_C
	int device_number;
#else
	int volume_number;
#endif
	
	if (file_mode>5)
		IO_error ("FOpen: invalid file mode");
	
	file_name_s=clean_to_c_string (file_name);

#ifdef GNU_C
	existing_fn=file_exists (file_name_s,&file_number,&device_number);
#else
	existing_fn=file_exists (file_name_s,&file_number,&volume_number);
#endif
	
	if (existing_fn>=0)
		IO_error ("FOpen: file already open");
	
	fn=number_of_files;
	if (fn>=MAX_N_FILES){
		for (fn=FIRST_REAL_FILE; fn<MAX_N_FILES; ++fn)
			if (file_table[fn].file==NULL)
				break;
		if (fn>=MAX_N_FILES)
			IO_error ("FOpen: too many files");
	}
	f=&file_table[fn];

	fd=fopen (file_name_s,file_mode_string[file_mode]);
	if (fd==NULL){
		free (file_name_s);
		return -1;
	}

	if (existing_fn==-2)
#ifdef GNU_C
		get_file_number_and_device_number (file_name_s,&file_number,&device_number);
#else
		get_file_number_and_device_number (file_name_s,&file_number,&volume_number);
#endif

	f->file_number=file_number;
#ifdef GNU_C
	f->device_number=device_number;
#else
	f->volume_number=volume_number;	
#endif

#ifdef LINUX
	{
		char *buffer;
		
		buffer=malloc (FILE_IO_BUFFER_SIZE);
		
		buffers[fn]=buffer;

		if (buffer!=NULL)
			setvbuf (fd,buffer,_IOFBF,FILE_IO_BUFFER_SIZE);
	}
#else
	setvbuf (fd,NULL,_IOFBF,FILE_IO_BUFFER_SIZE);
#endif
		
	switch (file_mode){
		case F_WRITE_TEXT:
#ifndef GNU_C
		{
			FileParam pb;
	
			pb.ioNamePtr=file_name->characters-1;
			pb.ioVRefNum=0;
			pb.ioFVersNum=0;
			pb.ioFDirIndex=0;
# ifdef MPW3
			if (PBGetFInfo ((ParmBlkPtr)&pb,0)==noErr) {
				pb.ioFlFndrInfo.fdType='TEXT';
				PBSetFInfo ((ParmBlkPtr)&pb,0);
			}
# else
			if (PBGetFInfo ((ParmBlkPtr)&pb,0)==noErr) {
				pb.ioFlFndrInfo.fdType='TEXT';
				PBSetFInfo (&pb,0);
			}
# endif
		}
#endif
		case F_WRITE_DATA:
			file_length=0;
			break;
		case F_APPEND_TEXT:
		case F_APPEND_DATA:
			if (fseek (fd,0l,2)!=0){
				fclose (fd);
				IO_error ("FOpen: seek to end of file failed");
			}
			file_length=ftell (fd);
			if (file_length==-1l){
				fclose (fd);
				IO_error ("FOpen: can't get file position");
			}
			break;
		default:
			if (fseek (fd,0l,2)!=0){
				fclose (fd);
				IO_error ("FOpen: seek to end of file failed");
			}
			file_length=ftell (fd);
			if (file_length==-1l){
				fclose (fd);
				IO_error ("FOpen: can't get file position");
			}
			if (fseek (fd,0l,0)!=0){
				fclose (fd);
				IO_error ("FOpen: seek to beginning of file failed");
			}
	}
	
	f->file=fd;
	f->mode=1<<file_mode;
	f->unique=1;
	f->file_name=file_name_s;
	f->file_length=file_length;
	f->position=-2;
	f->position_2=-1;

	if (fn>=number_of_files)
		number_of_files=fn+1;
	
	return fn;
}

static int stdio_open=0;

long open_stdio (void)
{
	if (stdio_open)
		IO_error ("stdio: already open");

	stdio_open=1;
	return 1;
}

long open_stderr (void)
{
	return 0;
}

long close_file (long fn)
{
	if (fn<FIRST_REAL_FILE){
		if (fn==1){
			if (!stdio_open)
				IO_error ("fclose: file not open (stdio)");
			stdio_open=0;
			if (ferror (stdin) || ferror (stdout))
				return 0;
		}
		return CLEAN_TRUE;
	} else {
		struct file *f;
		int result;
	
		f=&file_table[fn];
		
		if (f->file==NULL)
			IO_error ("FClose: File not open");

		result=CLEAN_TRUE;
		if (fclose (f->file)!=0)
			result=0;
		
		free (f->file_name);
		
#ifdef LINUX
		if (buffers[fn]!=NULL)
			free (buffers[fn]);
#endif
		
		f->file=NULL;

		if (fn==number_of_files-1)
			--number_of_files;

		return result;
	}
}

long flush_file_buffer (long fn)
{
	if (fn<FIRST_REAL_FILE){
		if (fn==0)
			return fflush (stderr)==0 ? CLEAN_TRUE : 0;
		else if (fn==1)
			return fflush (stdout)==0 ? CLEAN_TRUE : 0;
		
		return CLEAN_TRUE;
	} else {
		FILE *fd;

		fd=file_table[fn].file;
		if (fd!=NULL)
			/* fflush (NULL) flushes all files on linux */
			return fflush (fd)==0 ? CLEAN_TRUE : 0;
		else
			return 0;
	}
}

int re_open_file (long fn,unsigned int file_mode)
{	
	if (file_mode>5)
		IO_error ("FReOpen: Invalid file mode");

	if (fn<FIRST_REAL_FILE){
		if (fn==0 && (file_mode==F_READ_TEXT || file_mode==F_READ_DATA))
			IO_error ("FReOpen: StdErr can't be opened for reading");
		return -1;
	} else {	
		unsigned long file_length;
		struct file *f;
		FILE *fd;
		int result;
	
		f=&file_table[fn];

		result=-1;
		if (fclose (f->file)!=0)
			result=0;

		fd=fopen (f->file_name,file_mode_string[file_mode]);
		if (fd==NULL)
			IO_error ("FReOpen: can't open file");
	
#ifdef LINUX
		if (buffers[fn]!=NULL)
			setvbuf (fd,buffers[fn],_IOFBF,FILE_IO_BUFFER_SIZE);
#else
		setvbuf (fd,NULL,_IOFBF,FILE_IO_BUFFER_SIZE);
#endif

		switch (file_mode){
			case F_WRITE_TEXT:
			case F_WRITE_DATA:
				file_length=0;
				break;
			case F_APPEND_TEXT:
			case F_APPEND_DATA:
				if (fseek (fd,0l,2)!=0){
					fclose (fd);
					IO_error ("FOpen: seek to end of file failed");
				}

				file_length=ftell (fd);
				if (file_length==-1l){
					fclose (fd);
					IO_error ("FReOpen: can't get file position");
				}
				break;
			default:
				if (fseek (fd,0l,2)!=0){
					fclose (fd);
					IO_error ("FReOpen: seek to end of file failed");
				}
				file_length=ftell (fd);
				if (file_length==-1l){
					fclose (fd);
					IO_error ("FReOpen: can't get file position");
				}
				if (fseek (fd,0l,0)!=0){
					fclose (fd);
					IO_error ("FReOpen: seek to beginning of file failed");
				}
		}
	
		f->file=fd;
		f->mode=1<<file_mode;
		f->file_length=file_length;
		f->position=-2;
		f->position_2=-1;
		
		return result;
	}
}

int file_read_char (long fn)
{
	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 0:
				IO_error ("FReadC: can't read from StdErr");
			case 1:
				return getchar();
			default:
				IO_error ("FReadC: can't open this file");
		}
	} else {
		struct file *f;

		f=&file_table[fn];

		if (f->mode & ~((1<<F_READ_TEXT) | (1<<F_READ_DATA)))
			IO_error ("FReadC: read from an output file");

		return getc (f->file);
	}
}

int file_read_int (long fn,long *i_p)
{
	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 0:
				IO_error ("FReadI: can't read from StdErr");
			case 1:
#ifdef A64
				return w_get_int (i_p);
#else
				return w_get_int ((int*)i_p);
#endif
			default:
				IO_error ("FReadI: can't open this file");
		}
	} else {
		struct file *f;

		f=&file_table[fn];

		*i_p=0;
		
		if (f->mode & (1<<F_READ_DATA)){
			int i;
			FILE *fd;
			
			fd=f->file;

			if ((i=getc (fd))==EOF)
				return 0;
			((char*)i_p)[0]=i;
			if ((i=getc (fd))==EOF)
				return 0;
			((char*)i_p)[1]=i;
			if ((i=getc (fd))==EOF)
				return 0;
			((char*)i_p)[2]=i;
			if ((i=getc (fd))==EOF)
				return 0;
			((char*)i_p)[3]=i;
#ifdef A64
			*i_p=(long)*(int*)i_p;
#endif

		} else if (f->mode & (1<<F_READ_TEXT)){
#ifdef A64
			if (fscanf (f->file,"%ld",i_p)!=1)
#else
			if (fscanf (f->file,"%d",(int*)i_p)!=1)
#endif
				return 0;
		} else
			IO_error ("FReadI: read from an output file");
		
		return -1;
	}
}

int file_read_real (long fn,double *r_p)
{
	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 0:
				IO_error ("FReadR: can't read from StdErr");
			case 1:
				return w_get_real (r_p);
			default:
				IO_error ("FReadR: can't open this file");
		}
	} else {
		struct file *f;
		
		f=&file_table[fn];

		*r_p=0.0;
		
		if (f->mode & (1<<F_READ_DATA)){
			int n;
			FILE *fd;
			
			fd=f->file;
			for (n=0; n<8; ++n){
				int i;
				
				if ((i=getc (fd))==EOF)
					return 0;
				((char*)r_p)[n]=i;
			}
		} else if (f->mode & (1<<F_READ_TEXT)){
			if (fscanf (f->file,"%lg",r_p)!=1)
				return 0;
		} else
			IO_error ("FReadR: read from an output file");
		
		return -1;
	}
}

#ifndef LINUX
# define OLD_READ_STRING 1
# define OLD_WRITE_STRING 1
#endif

#if OLD_READ_STRING
unsigned long file_read_string (long fn,unsigned long max_length,struct clean_string *s)
{	
#else
unsigned long file_read_characters (long fn,unsigned long *length_p,char *s)
{
    unsigned long max_length;

    max_length=*length_p;
#endif
	unsigned long length;

	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 0:
				IO_error ("FReadS: can't read from StdErr");
			case 1:
#if OLD_READ_STRING
				length = fread (s->characters,1,max_length,stdin);
				s->length=length;
#else
				length = fread (s,1,max_length,stdin);
				*length_p=length;
#endif
				return length;
			default:
				IO_error ("FReadS: can't open this file");
		}
	} else {
		struct file *f;
		FILE *fd;

		f=&file_table[fn];

		if (f->mode & ~((1<<F_READ_TEXT) | (1<<F_READ_DATA)))
			IO_error ("FReadS: read from an output file");
		
		fd=f->file;
#if OLD_READ_STRING
		length = fread (s->characters,1,max_length,fd);	
		s->length=length;
#else
		length = fread (s,1,max_length,fd);	
		*length_p=length;
#endif
		return length;
	}
}

unsigned long file_read_line (long fn,unsigned long max_length,char *string)
{	
	unsigned long length;

	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 0:
				IO_error ("FReadLine: can't read from StdErr");
			case 1:
			{
				int c;
				length=0;

#if 0
				fgets (string,max_length,stdin);
				
				string [max_length-1]='\0';
				while (string[length]!='\0')
					++length;

				if (length<max_length-1 || string[length-1]=='\n')
					return length;

				c=getchar();
				if (c!=EOF){
					string[length++]=c;
					if (c!='\n')
						return -1;
				}

				return length;
#else
				flockfile (stdin);

				while (length!=max_length && (c=getchar_unlocked(),c!=EOF)){
					*string++=c;
					++length;
					if (c=='\n'){
						funlockfile (stdin);
						return length;
					}
				}

				funlockfile (stdin);

				if (c!=EOF)
					return -1;
#endif
		
				return length;
			}
			default:
				IO_error ("FReadLine: can't open this file");
		}
	} else {
		struct file *f;
		FILE *fd;
		int c;

		f=&file_table[fn];

		fd=f->file;
		length=0;

		c=0;
		if (f->mode & (1<<F_READ_TEXT)){
			flockfile (fd);
			while (length!=max_length && (c=getc_unlocked (fd),c!=EOF)){
				*string++=c;
				++length;
				if (c=='\n'){
					funlockfile (fd);
					return length;
				}
			}
			funlockfile (fd);
		} else if (f->mode & (1<<F_READ_DATA)){
			flockfile (fd);
			while (length!=max_length && (c=getc_unlocked (fd),c!=EOF)){
				*string++=c;
				++length;
				if (c=='\xa'){
					funlockfile (fd);
					return length;
				}
				else if (c=='\xd'){
					if (length!=max_length){
						if ((c=getc_unlocked (fd),c!=EOF)){
							funlockfile (fd);
							if (c=='\xa'){
								*string++=c;
								++length;
							} else
								ungetc (c,fd);
						
							return length;
						} else {
							funlockfile (fd);
							return length;
						}
					} else {
						if ((c=getc_unlocked (fd),c!=EOF)){
							funlockfile (fd);
							if (c=='\xa'){
								ungetc (c,fd);
								return -1;
							} else
								ungetc (c,fd);
						
							return length;
						} else {
							funlockfile (fd);
							return length;
						}
					}
				}
			}
			funlockfile (fd);
		} else
			IO_error ("freadline: read from an output file");

		if (c!=EOF)
			return -1;
		
		return length;
	}
}

void file_write_char (int c,long fn)
{	
	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 0:
				ew_print_char (c);
				break;
			case 1:
				w_print_char (c);
				break;
			default:
				IO_error ("FWriteC: can't open this file");
		}
	} else {
		struct file *f;
	
		f=&file_table[fn];

		if (f->mode & ~((1<<F_WRITE_TEXT)|(1<<F_WRITE_DATA)|(1<<F_APPEND_TEXT)|(1<<F_APPEND_DATA)))
			IO_error ("FWriteC: write to an input file");
		putc (c,f->file);
	}
}

#ifdef A64
void file_write_int (long i,long fn)
#else
void file_write_int (int i,long fn)
#endif
{
	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 0:
				ew_print_int (i);
				break;
			case 1:
				w_print_int (i);
				break;
			default:
				IO_error ("FWriteI: can't open this file");
		}
	} else {
		struct file *f;
	
		f=&file_table[fn];

		if (f->mode & ~((1<<F_WRITE_TEXT)|(1<<F_WRITE_DATA)|(1<<F_APPEND_TEXT)|(1<<F_APPEND_DATA)))
			IO_error ("FWriteI: write to an input file");
		
		if (f->mode & ((1<<F_WRITE_DATA)|(1<<F_APPEND_DATA))){
#ifdef powerc
			/* work around bug in lucid compiler for power macintosh */
			FILE *fd=f->file;
			
			putc (i>>24,fd);
			putc (i>>16,fd);
			putc (i>>8,fd);
			putc (i,fd);
#else
			int v=i;
			FILE *fd=f->file;

			putc (((char*)&v)[0],fd);
			putc (((char*)&v)[1],fd);
			putc (((char*)&v)[2],fd);
			putc (((char*)&v)[3],fd);
#endif
		} else
#ifdef A64
			fprintf (f->file,"%ld",i);
#else
			fprintf (f->file,"%d",i);
#endif
	}
}

void file_write_real (double r,long fn)
{	
	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 0:
				ew_print_real (r);
				break;
			case 1:
				w_print_real (r);
				break;
			default:
				IO_error ("FWriteR: can't open this file");
		}
	} else {
		struct file *f;
	
		f=&file_table[fn];

		if (f->mode & ~((1<<F_WRITE_TEXT)|(1<<F_WRITE_DATA)|(1<<F_APPEND_TEXT)|(1<<F_APPEND_DATA)))
			IO_error ("FWriteR: write to an input file");
		
		if (f->mode & ((1<<F_WRITE_DATA)|(1<<F_APPEND_DATA))){
#ifdef powerc
			/* work around bug in lucid compiler for power macintosh */
			int i1,i2;
			FILE *fd=f->file;
			
			i1=((int*)&r)[0];
			i2=((int*)&r)[1];
			
			putc (i1>>24,fd);
			putc (i1>>16,fd);
			putc (i1>>8,fd);
			putc (i1,fd);
			putc (i2>>24,fd);
			putc (i2>>16,fd);
			putc (i2>>8,fd);
			putc (i2,fd);			
#else
			double v=r;
			FILE *fd=f->file;
			putc (((char*)&v)[0],fd);
			putc (((char*)&v)[1],fd);
			putc (((char*)&v)[2],fd);
			putc (((char*)&v)[3],fd);
			putc (((char*)&v)[4],fd);
			putc (((char*)&v)[5],fd);
			putc (((char*)&v)[6],fd);
			putc (((char*)&v)[7],fd);
#endif
		} else
			fprintf (f->file,"%.15g",r);
	}
}

#if OLD_WRITE_STRING
void file_write_string (struct clean_string *s,long fn)
#else
void file_write_characters (unsigned char *p,int length,long fn)
#endif
{	
	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 0:
#if OLD_WRITE_STRING
				ew_print_text (s->characters,s->length);
#else
				ew_print_text (p,length);
#endif
				break;
			case 1:
#if OLD_WRITE_STRING
				w_print_text (s->characters,s->length);
#else
				w_print_text (p,length);
#endif
				break;
			default:
				IO_error ("FWriteS: can't open this file");
		}
	} else {
		struct file *f;
	
		f=&file_table[fn];

		if (f->mode & ~((1<<F_WRITE_TEXT)|(1<<F_WRITE_DATA)|(1<<F_APPEND_TEXT)|(1<<F_APPEND_DATA)))
			IO_error ("FWriteS: write to an input file");
#if OLD_WRITE_STRING
		fwrite (s->characters,sizeof (char),s->length,f->file);
#else
		fwrite (p,sizeof (char),length,f->file);
#endif
	}
}

int file_end (long fn)
{
	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 0:
			case 1:
				IO_error ("FEnd: not allowed for StdIO and StdErr");
			default:
				IO_error ("FEnd: can't open file");
		}
	} else {
		struct file *f;
		int c;
		FILE *file_p;
		
		f=&file_table[fn];
		if (f->mode & ~((1<<F_READ_TEXT) | (1<<F_READ_DATA)))
			IO_error ("FEnd: not allowed for output files");
		
		file_p=f->file;
		
		/* not portable to all compilers: */
#ifdef LINUX
# if defined (MACH_O64) || defined (ANDROID)
		if (file_p->_r>0)
# else
/*
		if (file_p->_gptr < file_p->_egptr)
*/
		if (file_p->_IO_read_ptr < file_p->_IO_read_end)
# endif
#else
# ifdef OS2
		if (file_p->rcount>0)
# else
#  ifdef _WINDOWS_
		if (file_p->_r>0)
#  else
		if (file_p->_cnt>0)
#  endif
# endif
#endif
			return 0;
		
		c=getc (file_p);
		if (c==EOF)
			return -1;
		
		ungetc (c,file_p);
		return 0;
	}
}

int file_error (long fn)
{
	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 1:
				if (ferror (stdin) || ferror (stdout))
					return -1;
				else
					return 0;
			case 0:
				return 0;
			default:
				return -1;
		}
	} else
		return ferror (file_table[fn].file) ? -1 : 0;
}

unsigned long file_position (long fn)
{
	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 0:
			case 1:
				IO_error ("FPosition: not allowed for StdIO and StdErr");
			default:
				IO_error ("FPosition: can't open file");
		}
	} else {
		unsigned long position;
		
		position=ftell (file_table[fn].file);
		if (position==-1l)
			IO_error ("FPosition: can't get file position");
		
		return position;
	}
}

int file_seek (long fn,unsigned long position,unsigned long seek_mode)
{	
	if (seek_mode>(unsigned)2)
		IO_error ("FSeek: invalid mode");

	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 0:
			case 1:
				IO_error ("FSeek: can't seek on StdIO and StdErr");
			default:
				IO_error ("FSeek: can't open file");
		}
	} else {
		struct file *f;
		int r;
	
		f=&file_table[fn];
	
		r=fseek (f->file,position,(int)seek_mode);
		if (r!=0)
			return 0;
				
		return -1;
	}
}

long open_s_file (struct clean_string *file_name,unsigned int file_mode)
{
	FILE *fd;
	int fn,existing_fn;
	char *file_name_s;
	struct file *f;
	unsigned long file_length;

	long file_number;
#ifdef GNU_C
	int device_number;
#else
	int volume_number;
#endif

	if (file_mode!=F_READ_TEXT && file_mode!=F_READ_DATA)
		IO_error ("SFOpen: invalid file mode");
	
	file_name_s=clean_to_c_string (file_name);
	
#ifdef GNU_C
	existing_fn=file_exists (file_name_s,&file_number,&device_number);
#else
	existing_fn=file_exists (file_name_s,&file_number,&volume_number);
#endif

	if (existing_fn>=0){
		if (file_table[existing_fn].unique)
			IO_error ("SFOpen: file already opened by FOpen");
		if (file_table[existing_fn].mode!=(1<<file_mode))
			IO_error ("SFOpen: file already open in another file mode");
		
		free (file_name_s);
		
		return existing_fn;
	}

	fn=number_of_files;
	if (fn>=MAX_N_FILES){
		for (fn=FIRST_REAL_FILE; fn<MAX_N_FILES; ++fn)
			if (file_table[fn].file==NULL)
				break;
		if (fn>=MAX_N_FILES)
			IO_error ("SFOpen: too many files");
	}

	f=&file_table[fn];
	
	fd=fopen (file_name_s,file_mode_string[file_mode]);
	if (fd==NULL){
		free (file_name_s);

		return -1;
	}
	if (existing_fn==-2)
#ifdef GNU_C
		get_file_number_and_device_number (file_name_s,&file_number,&device_number);
#else
		get_file_number_and_device_number (file_name_s,&file_number,&volume_number);
#endif

	f->file_number=file_number;
#ifdef GNU_C
	f->device_number=device_number;
#else
	f->volume_number=volume_number;	
#endif

#ifdef LINUX
	{
		char *buffer;
		
		buffer=malloc (FILE_IO_BUFFER_SIZE);
		
		buffers[fn]=buffer;

		if (buffer!=NULL)
			setvbuf (fd,buffer,_IOFBF,FILE_IO_BUFFER_SIZE);
	}
#else
	setvbuf (fd,NULL,_IOFBF,FILE_IO_BUFFER_SIZE);
#endif

	if (fseek (fd,0l,2)!=0){
		fclose (fd);
		IO_error ("SFOpen: seek to end of file failed");
	}
	file_length=ftell (fd);
	if (file_length==-1l){
		fclose (fd);
		IO_error ("SFOpen: can't get file position");
	}
	if (fseek (fd,0l,0)!=0){
		fclose (fd);
		IO_error ("SFOpen: seek to beginning of file failed");
	}
	
	f->file=fd;
	f->mode=1<<file_mode;
	f->unique=0;
	f->file_name=file_name_s;
	f->file_length=file_length;
	f->position=-2;
	f->position_2=-1;
	
	if (fn>=number_of_files)
		number_of_files=fn+1;
	
	return fn;
}

void file_share (long fn)
{
	file_table[fn].unique=0;
}

int file_read_s_char (long fn,unsigned long *position_p)
{	
	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 0:
				IO_error ("SFReadC: can't read from StdErr");
			case 1:
				IO_error ("SFReadC: can't read from StdIO, use FReadC");
			default:
				IO_error ("SFReadC: can't open this file");
		}
	} else {
		struct file *f;
		int c;
		unsigned long position;

		f=&file_table[fn];

		position=*position_p;

		if (f->unique)
			IO_error ("SFReadC: can't read from a unique file");

		if (f->mode & ~((1<<F_READ_TEXT) | (1<<F_READ_DATA)))
			IO_error ("SFReadC: read from an output file");

		if (f->position!=position)
			switch (position){
				case -1l:
					if (position!=f->position_2)
						position=f->position_2;
					else {
						position=ftell (f->file);
						if (position==-1l)
							IO_error ("SFReadC: can't get file position");
						f->position_2=position;
						break;
					}
				default:
					if (fseek (f->file,position,0)!=0)
						IO_error ("SFReadC: seek failed");
			}

		c=getc (f->file);
		if (c!=EOF)
			++position;

		f->position=position;
		*position_p=position;

		return c;
	}
}

int file_read_s_int (long fn,long *i_p,unsigned long *position_p)
{
	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 0:
				IO_error ("SFReadI: can't read from StdErr");
			case 1:
				IO_error ("SFReadI: can't read from StdIO, use FReadI");
			default:
				IO_error ("SFReadI: can't open this file");
		}
	} else {
		struct file *f;
		int result;
		unsigned long position;

		f=&file_table[fn];
		position=*position_p;
		
		if (f->unique)
			IO_error ("SFReadI: can't read from a unique file");

		if (f->position!=position)
			if (f->mode & ((1<<F_READ_TEXT) | (1<<F_READ_DATA))){
				switch (position){
					case -1l:
						if (position!=f->position_2)
							position=f->position_2;
						else {
							position=ftell (f->file);
							if (position==-1l)
								IO_error ("SFReadI: can't get file position");
							f->position_2=position;
							break;
						}
					default:
						if (fseek (f->file,position,0)!=0)
							IO_error ("SFReadI: seek failed");
				}
			}

		*i_p=0;
		
		if (f->mode & (1<<F_READ_DATA)){
			int i;
			FILE *fd;
			
			fd=f->file;

			result=-1;
			if ((i=getc (fd))==EOF)
				result=0;
			else {
				((char*)i_p)[0]=i;
				if ((i=getc (fd))==EOF){
					++position;
					result=0;
				} else {
					((char*)i_p)[1]=i;
					if ((i=getc (fd))==EOF){
						position+=2;
						result=0;
					} else {
						((char*)i_p)[2]=i;
						if ((i=getc (fd))==EOF){
							position+=3;
							result=0;
						} else {
							((char*)i_p)[3]=i;
							position+=4;
#ifdef A64
							*i_p=(long)*(int*)i_p;
#endif
						}
					}
				}
			}
		} else if (f->mode & (1<<F_READ_TEXT)){
#ifdef A64
			if (fscanf (f->file,"%ld",i_p)!=1)
#else
			if (fscanf (f->file,"%d",(int*)i_p)!=1)
#endif
				result=0;
			else
				result=-1;
			position=ftell (f->file);
			if (position==-1l)
				IO_error ("SFReadI: can't get file position");
		} else
			IO_error ("SFReadI: read from an output file");

		f->position=position;
		*position_p=position;
		
		return result;
	}
}

int file_read_s_real (long fn,double *r_p,unsigned long *position_p)
{
	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 0:
				IO_error ("SFReadR: can't read from StdErr");
			case 1:
				IO_error ("SFReadR: can't read from StdIO, use FReadR");
			default:
				IO_error ("SFReadR: can't open this file");
		}
	} else {
		struct file *f;
		int result;
		unsigned long position;
		
		f=&file_table[fn];

		if (f->unique)
			IO_error ("SFReadR: can't read from a unique file");

		position=*position_p;
		if (f->position!=position)
			if (f->mode & ((1<<F_READ_TEXT) | (1<<F_READ_DATA))){
				switch (position){
					case -1l:
						if (position!=f->position_2)
							position=f->position_2;
						else {
							position=ftell (f->file);
							if (position==-1l)
								IO_error ("SFReadR: can't get file position");
							f->position_2=position;
							break;
						}
					default:
						if (fseek (f->file,position,0)!=0)
							IO_error ("SFReadR: seek failed");
				}
			}
		
		*r_p=0.0;
		
		if (f->mode & (1<<F_READ_DATA)){
			int n;
			FILE *fd;

			fd=f->file;
			
			result=-1;
			for (n=0; n<8; ++n){
				int i;
				
				if ((i=getc (fd))==EOF){
					result=0;
					break;
				}
				((char*)r_p)[n]=i;
			}
			
			position+=n;
		} else if (f->mode & (1<<F_READ_TEXT)){
			if (fscanf (f->file,"%lg",r_p)!=1)
				result=0;
			else
				result=-1;
			position=ftell (f->file);
			if (position==-1l)
				IO_error ("SFReadR: can't get file position");
		} else
			IO_error ("SFReadR: read from an output file");
		
		f->position=position;
		*position_p=position;
		
		return result;
	}
}

unsigned long file_read_s_string
	(long fn,unsigned long max_length,struct clean_string *s,unsigned long *position_p)
{	
	unsigned long length;

	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 0:
				IO_error ("SFReadS: can't read from StdErr");
			case 1:
				IO_error ("SFReadS: can't read from StdIO, use FReadS");
			default:
				IO_error ("SFReadS: can't open this file");
		}
	} else {
		struct file *f;
		unsigned long position;
		FILE *fd;
		char *string;
		int c;

		f=&file_table[fn];

		if (f->unique)
			IO_error ("SFReadS: can't read from a unique file");

		if (f->mode & ~((1<<F_READ_TEXT) | (1<<F_READ_DATA)))
			IO_error ("SFReadS: read from an output file");
		
		fd=f->file;
		
		position=*position_p;
		if (f->position!=position)
			switch (position){
				case -1l:
					if (position!=f->position_2)
						position=f->position_2;
					else {
						position=ftell (fd);
						if (position==-1l)
							IO_error ("SFReadS: can't get file position");
						f->position_2=position;
						break;
					}
				default:
					if (fseek (fd,position,0)!=0)
						IO_error ("SFReadS: seek failed");
			}

		length=0;
		string=s->characters;

		while (length!=max_length && (c=getc (fd),c!=EOF)){
			*string++=c;
			++length;
		}
		
		s->length=length;

		position+=length;

		f->position=position;
		*position_p=position;
		
		return length;
	}
}

unsigned long file_read_s_line
	(long fn,unsigned long max_length,char *string,unsigned long *position_p)
{	
	unsigned long length;

	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 0:
				IO_error ("SFReadLine: can't read from StdErr");
			case 1:
				IO_error ("SFReadLine: can't read from StdIO, use FReadLine");
			default:
				IO_error ("SFReadLine: can't open this file");
		}
	} else {
		struct file *f;
		unsigned long position;
		FILE *fd;
		int c;

		f=&file_table[fn];

		if (f->unique)
			IO_error ("SFReadLine: can't read from a unique file");

		if (f->mode & ~(1<<F_READ_TEXT))
			if (f->mode & (1<<F_READ_DATA))
				IO_error ("SFReadLine: read from a data file");
			else
				IO_error ("SFReadLine: read from an output file");
		
		fd=f->file;

		position=*position_p;
		if (f->position!=position)
			switch (position){
				case -1l:
					if (position!=f->position_2)
						position=f->position_2;
					else {
						position=ftell (fd);
						if (position==-1l)
							IO_error ("SFReadLine: can't get file position");
						f->position_2=position;
						break;
					}
				default:
					if (fseek (fd,position,0)!=0)
						IO_error ("SFReadLine: seek failed");
			}

		length=0;
		
		c=0;
		while (length!=max_length && (c=getc (fd),c!=EOF)){
			*string++=c;
			++length;
			if (c=='\n')
				break;
		}
		
		position+=length;
		
		f->position=position;
		*position_p=position;
		
		if (c!='\n' && c!=EOF)
			return -1;
		
		return length;
	}
}

int file_s_end (long fn,unsigned long position)
{
	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 0:
			case 1:
				IO_error ("SFEnd: not allowed for StdIO and StdErr");
			default:
				IO_error ("SFEnd: can't open file");
		}
	} else {
		struct file *f;
		
		f=&file_table[fn];
		if (f->mode & ~((1<<F_READ_TEXT) | (1<<F_READ_DATA)))
			IO_error ("SFEnd: not allowed for output files");

		if (f->unique){
			int c;
			FILE *file_p;
			
			file_p=f->file;
		
			/* not portable to all compilers: */
#ifdef LINUX
# if defined (MACH_O64) || defined (ANDROID)
			if (file_p->_r>0)
# else
/*
			if (file_p->_gptr < file_p->_egptr)
*/
			if (file_p->_IO_read_ptr < file_p->_IO_read_end)
# endif
#else
# ifdef OS2
			if (file_p->rcount>0)
# else
#  ifdef _WINDOWS_
			if (file_p->_r>0)
#  else
			if (file_p->_cnt>0)
#  endif
# endif
#endif
				return 0;
		
			c=getc (file_p);
			if (c==EOF)
				return -1;
		
			ungetc (c,file_p);
			return 0;
		} else {
			if (position==-1l){
				if (f->position_2!=-1l)
					position=f->position_2;
				else {
					position=ftell (f->file);
					if (position==-1l)
						IO_error ("SFEnd: can't get file position");
					f->position=position;
					f->position_2=position;
				}
			}
		
			return (position==f->file_length) ? -1 : 0;
		}
	}
}

unsigned long file_s_position (long fn,unsigned long position)
{
	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 0:
			case 1:
				IO_error ("SFPosition: not allowed for StdIO and StdErr");
			default:
				IO_error ("SFPosition: can't open file");
		}
	} else {
		struct file *f;
	
		f=&file_table[fn];

		if (f->unique){
			unsigned long position;
		
			position=ftell (file_table[fn].file);
			if (position==-1l)
				IO_error ("SFPosition: can't get file position");
		
			return position;
		} else {
			if (position==-1l){
				if (f->position_2!=-1l)
					return f->position_2;
				else {
					position=ftell (f->file);
					if (position==-1l)
						IO_error ("SFPosition: can't get file position");
					f->position=position;
					f->position_2=position;
				}
			}

			return position;
		}
	}
}

#define F_SEEK_SET 0
#define	F_SEEK_CUR 1
#define F_SEEK_END 2

int file_s_seek (long fn,unsigned long position,unsigned long seek_mode,unsigned long *position_p)
{
	if (fn<FIRST_REAL_FILE){
		switch (fn){
			case 0:
				IO_error ("SFSeek: can't seek on StdIO");
			case 1:
				IO_error ("SFSeek: can't seek on StdErr");
			default:
				IO_error ("SFSeek: can't open file");
		}
	} else {
		struct file *f;
	
		f=&file_table[fn];		

		if (f->unique)
			IO_error ("SFSeek: can't seek on a unique file");

		if (*position_p==-1l){
			if (f->position_2!=-1l)
				*position_p=f->position_2;
			else {
				unsigned long current_position;

				current_position=ftell (f->file);
				if (current_position==-1l)
					IO_error ("SFSeek: can't get file position");
				f->position_2=current_position;
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
				seek_mode=F_SEEK_SET;
				break;
			default:
				IO_error ("SFSeek: invalid mode");
		}

		if (fseek (f->file,position,(int)seek_mode)!=0)
			return 0;
		
		*position_p=position;
		f->position=position;
		
		return -1;
	}
}
