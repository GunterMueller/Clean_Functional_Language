/*
	File:	cg.c
	Author:	John van Groningen
	At:		University of Nijmegen
*/

#ifdef THINK_C
# define USER_INTERFACE
#endif

#include <string.h>

#include "cgport.h"

#ifdef ALIGN_C_CALLS
# define CG_PPC_XO
#endif

#include <stdlib.h>
#include <stdio.h>

#if ! (defined (M68000) && defined (SUN))
#	define GENERATE_OBJECT_FILE
#endif

#ifdef POWER
#	define USE_SYSTEM_ALLOC 1
/* #	include "Memory.h" */
#	include "MacMemory.h"
#else
#	define USE_SYSTEM_ALLOC 0
#endif

/* #define PERFORMANCE */

#include "MAIN_CLM.d"

#ifdef PERFORMANCE
#include <Perf.h>
TP2PerfGlobals ThePGlobals;
#endif

#ifdef THINK_C
#	include <console.h>
#	define NO_TOPOLOGY
#ifdef USER_INTERFACE
#	include "system.h"
#else
#	include "types.t"
#endif
#endif

#include "cgrconst.h"
#include "cgtypes.h"
#include "cgcode.h"
#include "cglin.h"
#include "cgopt.h"
#ifdef I486
# include "cgias.h"
# include "cgiwas.h"
#else
# ifdef ARM
#  include "cgarmas.h"
#  include "cgarmwas.h"
# else
#  ifdef SOLARIS
#   include "cgswas.h"
#  else
#   ifdef G_POWER
#    include "cgpas.h"
#    include "cgpwas.h"
#   else
#    include "cgas.h"
#    include "cgwas.h"
#   endif
#  endif
# endif
#endif
#include "cgstack.h"

#include "cg.h"

#ifdef USER_INTERFACE
#	include "cginterface.t"
#	include "cginterface.h"
#endif

#include "cginput.h"

#ifdef G_POWER
#	include "cgptoc.h"
#endif

#include <setjmp.h>

static jmp_buf error_jmp;

static void exit_code_generator (int r)
{
	longjmp (error_jmp,r);
}

int list_flag;
int check_stack;
int assembly_flag;
int mc68000_flag;
int mc68881_flag;
int parallel_flag;
int check_index_flag;
int module_info_flag=1;
#if defined (G_POWER) && defined (PROFILE)
int profile_table_flag;
#endif
#ifdef G_POWER
int fmadd_flag=1;
#endif
#if (defined (LINUX) && defined (G_AI64)) || defined (ARM)
int pic_flag=0;
#endif
#if defined (LINUX) && defined (G_AI64)
int rts_got_flag=0;
char **sl_mods;
char *no_sl_mods=NULL;
#endif

#ifdef USER_INTERFACE
#	define print_error(s1) FPrintF (StdError,"%s\n",s1)
#	define exit exit_code_generator
#else
# ifdef MAIN_CLM
#  ifdef MAKE_MPW_TOOL
#	define print_error(s1) printf("%s\n",s1)
#  else
#	ifdef CG_PPC_XO
	static char *return_error_string;
#	else
	extern char return_error_string[];
#	endif
#	define print_error(s1) strcpy (return_error_string,s1);
#  endif
#	define exit exit_code_generator
# else
/* #	define print_error(s1) printf("%s\n",s1) */
#	define print_error(s1) fprintf(stderr,"%s\n",s1)
# endif
#endif

void warning (char *error_string)
{
	print_error (error_string);
}

void warning_s (char *error_string,char *string)
{
	char error[300];
	
	sprintf (error,error_string,string);
	print_error (error);
}

void warning_i (char *error_string,int integer)
{
	char error[300];
	
	sprintf (error,error_string,integer);
	print_error (error);
}

void warning_si (char *error_string,char *string,int i)
{
	char error[300];
	
	sprintf (error,error_string,string,i);
	print_error (error);
}

void error (char *error_string)
{
	warning (error_string);
#ifdef PERFORMANCE
	PerfDump (ThePGlobals,"\pPerform.out",0,0);
	TermPerf (ThePGlobals);
#endif
	exit (-1);
}

void error_i (char *error_string,int integer)
{
	warning_i (error_string,integer);
#ifdef PERFORMANCE
	PerfDump (ThePGlobals,"\pPerform.out",0,0);
	TermPerf (ThePGlobals);
#endif
	exit (-1);
}	

void error_s (char *error_string,char *string)
{
	warning_s (error_string,string);
#ifdef PERFORMANCE
	PerfDump (ThePGlobals,"\pPerform.out",0,0);
	TermPerf (ThePGlobals);
#endif
	exit (-1);
}

void error_si (char *error_string,char *string,int i)
{
	warning_si (error_string,string,i);
#ifdef PERFORMANCE
	PerfDump (ThePGlobals,"\pPerform.out",0,0);
	TermPerf (ThePGlobals);
#endif
	exit (-1);
}

void internal_error (char *error_string)
{
	error_s ("Internal error: %s",error_string);
}

void internal_error_in_function (char *function_name)
{
	error_s ("Internal error in function: %s",function_name);
}

void *memory_allocate (int size)
{
	void *memory_block;

	memory_block=malloc (size);
	if (memory_block==NULL)
		error ("Out of memory");
	return memory_block;
}

#if USE_SYSTEM_ALLOC
#define system_memory_allocate_type(t) ((t*)system_memory_allocate(sizeof (t)))

static void *system_memory_allocate (int size)
{
	char *memory_block;
	
	memory_block=NewPtr (size);
	if (memory_block==NULL)
		error ("Out of memory");
	return memory_block;
}

#endif

void memory_free (void *memory_block)
{
	free (memory_block);
}

#if USE_SYSTEM_ALLOC
static void system_memory_free (void *memory_block)
{
	DisposePtr ((char*)memory_block);
}
#endif

#ifdef THINK_C
#	define MEM_BLOCK_SIZE 16380
#else
# if defined (__MWERKS__) || defined (__MRC__)
#	define MEM_BLOCK_SIZE 16384
# else
#	define MEM_BLOCK_SIZE 4092
# endif
#endif

struct memory_block_list
{
	char						mem_block [MEM_BLOCK_SIZE];
	struct memory_block_list *	mem_next_block;
};

static struct memory_block_list *heap;
static int first_mem_block_size;

void *allocate_memory_from_heap (int size)
{
#ifdef sparc
	size = (size+7) & ~7;
#else
	size = (size+3) & ~3;
#endif
	if (first_mem_block_size+size<=MEM_BLOCK_SIZE){
		char *mem_block;
		
		mem_block=&heap->mem_block[first_mem_block_size];
		first_mem_block_size+=size;
		return mem_block;
	} else {
		struct memory_block_list *new_mem_block_list;

#if	USE_SYSTEM_ALLOC
		new_mem_block_list=system_memory_allocate_type (struct memory_block_list);
#else
		new_mem_block_list=memory_allocate (sizeof (struct memory_block_list));
#endif
		new_mem_block_list->mem_next_block=heap;
		heap=new_mem_block_list;
		first_mem_block_size=size;
		return new_mem_block_list->mem_block;
	}
}

void release_heap (VOID)
{
	while (heap->mem_next_block!=NULL){
		struct memory_block_list *next_mem_block;
		
		next_mem_block=heap->mem_next_block;
#if USE_SYSTEM_ALLOC
		system_memory_free (heap);
#else
		memory_free (heap);
#endif
		heap=next_mem_block;
	}
}

static struct memory_block_list *memory_list;
static char *fast_mem_block;
static int fast_mem_block_size;

static void initialize_memory (VOID)
{
	memory_list=NULL;
	
	first_mem_block_size=0;
#if	USE_SYSTEM_ALLOC
	heap=system_memory_allocate_type (struct memory_block_list);
#else
	heap=memory_allocate (sizeof (struct memory_block_list));
#endif
	heap->mem_next_block=NULL;

	fast_mem_block_size=0;
#if USE_SYSTEM_ALLOC
	memory_list=system_memory_allocate_type (struct memory_block_list);
#else
	memory_list=memory_allocate (sizeof (struct memory_block_list));
#endif
	memory_list->mem_next_block=NULL;
	fast_mem_block=memory_list->mem_block;
}

void *fast_memory_allocate (int size)
{
#ifdef sparc
	size=(size+7) & ~7;
#else
	size=(size+3) & ~3;
#endif
	if (fast_mem_block_size+size<=MEM_BLOCK_SIZE){
		char *memory_block;
		
		memory_block=&fast_mem_block[fast_mem_block_size];
		fast_mem_block_size+=size;
		return memory_block;
	} else {
		struct memory_block_list *new_memory_block;
		
#if USE_SYSTEM_ALLOC
		new_memory_block=system_memory_allocate_type (struct memory_block_list);
#else
		new_memory_block=memory_allocate (sizeof (struct memory_block_list));
#endif
		new_memory_block->mem_next_block=memory_list;
		memory_list=new_memory_block;
		
		fast_mem_block=new_memory_block->mem_block;
		fast_mem_block_size=size;
		
		return fast_mem_block;
	}
}

static void release_memory (VOID)
{
	while (memory_list!=NULL){
		struct memory_block_list *next_mem_block;
		
		next_mem_block=memory_list->mem_next_block;
#if USE_SYSTEM_ALLOC
		system_memory_free (memory_list);
#else
		memory_free (memory_list);
#endif
		memory_list=next_mem_block;
	}
	release_heap();
#if USE_SYSTEM_ALLOC
		system_memory_free (heap);
#else
		memory_free (heap);
#endif
}

#define IO_BUF_SIZE 8192

char *this_module_name;

#ifdef GNU_C
#	define FOLDER_SEPARATOR '/'
#else
#	define FOLDER_SEPARATOR ':'
#endif

#if defined (POWER) && defined (GNU_C)
static FILE *fopen_with_file_name_conversion (char *file_name,char *mode)
{
	CFURLRef hfs_url;
	CFStringRef	hfs_string, posix_string;
	char buffer[512+1];
	
	hfs_string = CFStringCreateWithCString (NULL/*kCFAllocatorDefault*/,file_name,kCFStringEncodingMacRoman);
	hfs_url = CFURLCreateWithFileSystemPath (NULL/*kCFAllocatorDefault*/,hfs_string,kCFURLHFSPathStyle,/*isDirectory*/false);
	CFRelease (hfs_string);
	posix_string = CFURLCopyFileSystemPath (hfs_url,kCFURLPOSIXPathStyle);
	CFRelease (hfs_url);
	if (! CFStringGetCString (posix_string,buffer,512,kCFStringEncodingMacRoman)){
		CFRelease (posix_string);
		return NULL;
	}
	
	file_name=buffer;

	return fopen (file_name,mode);
}

# define fopen fopen_with_file_name_conversion
#endif

#ifdef USER_INTERFACE

extern File abc_file;

static File obj_file,assembly_file;

extern int system_file;

int generate_code (char	*file_name,target_machine_type target_machine,int flags)
{
	int r;
	char *module_name;
	int object_file_type;
	
	/*
	InitProfile (400,200);
	freopen ("profile","w",stdout);
	*/

	system_file=0;
	
	obj_file=NULL;
	assembly_file=NULL;
	abc_file=NULL;
	
	if (!(r=setjmp (error_jmp))){
		initialize_memory();
		
		mc68000_flag=0;
		mc68881_flag=1;
		
		switch (target_machine){
			case MAC_II:
				break;
			case MAC_I:
				mc68000_flag=1;
				mc68881_flag=0;
				break;
			case MAC_IISANE:
				mc68881_flag=0;
				break;
			default:
				error ("Unknown target machine");
		}
		
		list_flag=0;
		check_stack=(flags & STACK_CHECKS)!=0;
		assembly_flag=(flags & ASSEMBLY)!=0;
		parallel_flag=(flags & DO_PARALLEL)!=0;
		check_index_flag=(flags & CHECK_INDICES)!=0;
#if defined (G_POWER) && defined (PROFILE)
		profile_table_flag=0;
#endif

#ifndef GENERATE_OBJECT_FILE
		assembly_flag=1;
#endif
		
		initialize_parser();
		initialize_coding();
		initialize_linearization();
		initialize_stacks();
		
		object_file_type=
			mc68000_flag ? obj00File : (mc68881_flag ? obj81File : obj20File);

		module_name=file_name+strlen (file_name);
		while (module_name>file_name && module_name[-1]!=FOLDER_SEPARATOR)
			--module_name;
	
		this_module_name=module_name;

	 	abc_file=FOpen (file_name,abcFile,"r");

		if (abc_file==NULL){
			fprintf (stderr,"file \"%s.abc\" could not be opened.\n",file_name);
			exit (-1);
		}

		setvbuf (abc_file,NULL,_IOFBF,8192);
		
#if defined (M68000) && !defined (SUN)
		obj_file=FOpen (file_name,object_file_type,"wb");
		if (obj_file==NULL)
			error_s ("Can't create the output file [%s]",this_module_name);
		setvbuf (obj_file,NULL,_IOFBF,IO_BUF_SIZE);
#endif
		
		if (assembly_flag){
#ifdef MACH_O
			assembly_file=FOpen (file_name,assFile,"wb");
#else
			assembly_file=FOpen (file_name,assFile,"w");
#endif
			if (assembly_file==NULL)
				error_s ("Can't create the assembly file [%s]",this_module_name);
			setvbuf (assembly_file,NULL,_IOFBF,IO_BUF_SIZE);
		}

#ifdef GENERATE_OBJECT_FILE
		initialize_assembler (obj_file);
#endif
		if (assembly_flag)
			initialize_write_assembly (assembly_file);

#ifdef G_POWER
		initialize_toc();
#endif

		if (parse_file (abc_file)!=0){
			if (abc_file!=NULL){
				FClose (abc_file);
				abc_file=NULL;
			}			

#ifdef PERFORMANCE
			PerfDump (ThePGlobals,"\pPerform.out",0,0);
			TermPerf (ThePGlobals);
#endif
			exit (-1);
		}

		if (abc_file!=NULL){
			FClose (abc_file);			
			abc_file=NULL;
		}			

#if defined (G_POWER) && defined (PROFILE)
		if (profile_table_flag)
			write_profile_table();
#endif

		optimize_jumps();

#if 0
		if (list_flag){	
			show_code();
			show_imports_and_exports();
		}
#endif

#ifdef GENERATE_OBJECT_FILE
		assemble_code();
#endif

		if (assembly_flag)
			write_assembly();

#if defined (M68000) && !defined (SUN)
 		if (fclose (obj_file)!=0){
 			obj_file=NULL;
 			FDelete (file_name,object_file_type);
			error_s ("Error while writing object file [%s]",this_module_name);
		}
#endif

		if (assembly_flag && fclose (assembly_file)!=0){
			assembly_file=NULL;
			FDelete (file_name,assFile);
			error_s ("Error while writing assembly file [%s]",this_module_name);
		}

		if (!(flags & KEEP_ABC) && !system_file)
			FDelete (file_name,abcFile);
	} else {
		/* if an error occurrs : */
		if (obj_file!=NULL){
			fclose (obj_file);
			FDelete (file_name,object_file_type);
		}
		if (assembly_file!=NULL){
			fclose (assembly_file);
			FDelete (file_name,assFile);
		}
		if (abc_file!=NULL){
			FClose (abc_file);
			abc_file=NULL;
		}			
	}

	release_memory();
	
	return r;
}

#else

static void argument_error (VOID)
{
	error ("Usage: cg [options] file [-o object_file] [-s assembly_file]");
}

#if defined (LINUX) && defined (G_AI64)
static char **make_sl_mods (char *module_list)
{
	char **modules,**module_p,*module_name,*p;
	int n_modules;

	if (*module_list=='\0')
		n_modules = 0;
	else {
		n_modules = 1;
		for (p=module_list; *p!='\0'; ++p)
			if (*p==',')
				++n_modules;
	}
	
	p = (char*)memory_allocate (strlen (module_list)+1);
	strcpy (p,module_list);

	modules=(char**)memory_allocate (sizeof (char*) * (n_modules+1));
	module_p=modules;
	module_name=p;
	while (*p!='\0'){
		if (*p==','){
			*p='\0';
			*module_p++ = module_name;
			module_name=p+1;
		}
		++p;
	}
	if (module_name!=p)
		*module_p++ = module_name;
	*module_p=NULL;

	return modules;
}
#endif

#if defined(MAIN_CLM) && (defined (POWER) && !defined (CG_PPC_XO))
extern int compiler_id;
#endif

#ifdef I486
extern int intel_asm;
#endif

#ifdef G_AI64
extern int sse_128;
#endif

#ifdef MAIN_CLM
# if !(defined (__MWERKS__) && defined (__cplusplus))
#  ifdef CG_PPC_XO
#   ifdef MACH_O
int generate_code_o (int argc,char **argv,char *return_error_string_p,int *compiler_id_p)
#   else
int generate_code_xo (int argc,char **argv,char *return_error_string_p,int *compiler_id_p)
#   endif
#  else
int generate_code (int argc,char **argv)
#  endif
# else
int generate_code68 (int argc,char **argv)
# endif
#else
int main (int argc,char **argv)
#endif
{
	char *file_name;

	static FILE *abc_file,*obj_file,*assembly_file;

	int arg_n,r,file_name_length;
	char *abc_file_name=NULL,*object_file_name_s=NULL,*assembly_file_name_s=NULL;
	char *module_name,*object_file_name,*assembly_file_name;


#if defined (MAIN_CLM) && defined (CG_PPC_XO)
	return_error_string=return_error_string_p;
#endif

#if defined (THINK_C)
	argc = ccommand (&argv);
#endif

#ifdef PERFORMANCE
	ThePGlobals=NULL;
	if (!InitPerf (&ThePGlobals,4,8,1,1,"\pCODE",0,"",0,0,0,0)){
		printf ("Can't initialize performance measurement\n");
		exit (-1);
	}
	PerfControl (ThePGlobals,1);
#endif

	obj_file=NULL;
	assembly_file=NULL;
	abc_file=NULL;
#if defined (LINUX) && defined (G_AI64)
	sl_mods=&no_sl_mods;
#endif

	if (!(r=setjmp (error_jmp))){
		initialize_memory();
	
		list_flag=0;
		check_stack=0;

		mc68000_flag=0;
		mc68881_flag=1;

		parallel_flag=0;
		check_index_flag=0;
		assembly_flag=0;
#if defined (G_POWER) && defined (PROFILE)
# if !defined (MACH_O)
		profile_table_flag=1;
# else
		profile_table_flag=0;
# endif
#endif
	
		for (arg_n=1; arg_n<argc && argv[arg_n][0]=='-'; ++arg_n){
			char *s;
			
			s=argv[arg_n]+1;
			if (!strcmp (s,"l"))
				list_flag=1;
			else if (!strcmp (s,"os"))
				check_stack=1;
			else if (!strcmp (s,"ci"))
				check_index_flag=1;
			else if (!strcmp (s,"p"))
				parallel_flag=1;
			else if (!strcmp (s,"a"))
				assembly_flag=1;
#if defined (G_POWER) && defined (PROFILE)
			else if (!strcmp (s,"pt"))
				profile_table_flag=1;
#endif
#ifdef I486
			else if (!strcmp (s,"intelasm"))
				intel_asm=1;
#endif
#ifdef G_AI64
			else if (!strcmp (s,"sse64"))
				sse_128=0;
#endif
#ifdef ARM
			else if (!strcmp (s,"pic"))
				pic_flag=1;
#endif
#if defined (LINUX) && defined (G_AI64)
			else if (!strcmp (s,"pic")){
				pic_flag=1;
				rts_got_flag=1;
			} else if (!strcmp (s,"picrts")){
				pic_flag=1;
				rts_got_flag=0;
			} else if (!strcmp (s,"slmods") && arg_n+1<argc){				
				++arg_n;
				sl_mods = make_sl_mods (argv[arg_n]);
			}
#endif
			else if (!strcmp (s,"mc68000")){
				mc68000_flag=1;
				mc68881_flag=0;
			} else if (!strcmp (s,"sane"))
				mc68881_flag=0;
#if defined (MAIN_CLM) && defined (POWER)
			else if (!strcmp (s,"id") && arg_n+1<argc){
				++arg_n;
# ifdef CG_PPC_XO
				*compiler_id_p=atoi (argv[arg_n]);
# else
				compiler_id=atoi (argv[arg_n]);
# endif
			}
#endif
			else 
				argument_error();
		}

#ifndef GENERATE_OBJECT_FILE
		assembly_flag=1;
#endif

		if (arg_n>=argc)
			argument_error();
		
		file_name=argv[arg_n++];
	
		module_name=file_name+strlen (file_name);
		while (module_name>file_name && module_name[-1]!=FOLDER_SEPARATOR)
			--module_name;
		
		this_module_name=module_name;
		
		file_name_length=strlen (file_name);

		abc_file_name=(char*)memory_allocate (file_name_length+5);
		strcpy (abc_file_name,file_name);
		strcat (abc_file_name,".abc");
		
		object_file_name_s=(char*)memory_allocate (file_name_length+6);
		strcpy (object_file_name_s,file_name);

#if defined (G_POWER) || defined (_WINDOWS_) || defined (LINUX) || defined (sparc)
# if defined (G_POWER) && !defined (MACH_O)
#  ifdef ALIGN_C_CALLS
		strcat (object_file_name_s,".xo");
#  else
		strcat (object_file_name_s,".cxo");
#  endif
# else
		strcat (object_file_name_s,".o");
# endif
#else
# ifdef I486
		strcat (object_file_name_s,".obj");
# else
		strcat (object_file_name_s,mc68000_flag ? ".obj0" : mc68881_flag ? ".obj2" : ".obj1");
# endif
#endif
		object_file_name=object_file_name_s;
		
		assembly_file_name_s=(char*)memory_allocate (file_name_length+3);
		strcpy (assembly_file_name_s,file_name);

#if (defined (M68000) && !defined (SUN)) || (defined (G_POWER) && !defined (LINUX_ELF))
		strcat (assembly_file_name_s,".a");
#else
		strcat (assembly_file_name_s,".s");
#endif
		assembly_file_name=assembly_file_name_s;
	
		while (arg_n<argc){
			if (arg_n+1==argc)
				argument_error();
			
			if (!strcmp (argv[arg_n],"-o"))
				object_file_name=argv[arg_n+1];
			else if (!strcmp (argv[arg_n],"-s")){
				assembly_file_name=argv[arg_n+1];
				assembly_flag=1;
			} else
				argument_error();
				
			arg_n+=2;
		}
		initialize_parser();
		initialize_coding();
		initialize_stacks();
		initialize_linearization();
		
#if 0
		abc_file=fopen (abc_file_name,"r");
#else
		abc_file=fopen (abc_file_name,"rb");
#endif
		if (abc_file==NULL)
			error_s ("Can't open file %s\n",abc_file_name);
		
#if defined (I486) && !defined (_WINDOWS_)
		{
			char *buffer;
			
			buffer=malloc (IO_BUF_SIZE);
			if (buffer==NULL)
				error ("Out of memory");
			setvbuf (abc_file,buffer,_IOFBF,IO_BUF_SIZE);
		}
#else
		setvbuf (abc_file,NULL,_IOFBF,IO_BUF_SIZE);
#endif

# ifdef GENERATE_OBJECT_FILE
		obj_file=fopen (object_file_name,"wb");
		if (obj_file==NULL)
			error ("Can't create the object file");
		setvbuf (obj_file,NULL,_IOFBF,IO_BUF_SIZE);
# endif
		
		if (assembly_flag){
#ifdef MACH_O
			assembly_file=fopen (assembly_file_name,"wb");
#else
			assembly_file=fopen (assembly_file_name,"w");
#endif
			if (assembly_file==NULL)
				error ("Can't create the assembly file");
#if defined (I486) && !defined (_WINDOWS_)
			{
				char *buffer;
				
				buffer=malloc (IO_BUF_SIZE);
				if (buffer==NULL)
					error ("Out of memory");
				setvbuf (assembly_file,buffer,_IOFBF,IO_BUF_SIZE);
			}
#else
			setvbuf (assembly_file,NULL,_IOFBF,IO_BUF_SIZE);
#endif
		}

#ifdef GENERATE_OBJECT_FILE
		initialize_assembler (obj_file);
#endif
		if (assembly_flag)
			initialize_write_assembly (assembly_file);

#ifdef G_POWER
		initialize_toc();
#endif

		if (parse_file (abc_file)!=0){
			if (abc_file!=NULL){
				fclose (abc_file);
				abc_file=NULL;
			}			

			exit (-1);
		}
		
		if (fclose (abc_file)!=0){
			abc_file=NULL;
			error_s ("Error while reading file %s\n",abc_file_name);
		}
		abc_file=NULL;
		
#ifdef G_POWER
		if (profile_table_flag)
			write_profile_table();
#endif

		optimize_jumps();

#if 0	
		if (list_flag){	
			show_code();
			show_imports_and_exports();
		}
#endif

#ifdef GENERATE_OBJECT_FILE
		assemble_code();
#endif
	
		if (assembly_flag)
			write_assembly();
	
#ifdef GENERATE_OBJECT_FILE
		if (fclose (obj_file)!=0){
			obj_file=NULL;
			error ("Error while writing object file");
		}
		obj_file=NULL;
#endif
		if (assembly_flag && fclose (assembly_file)!=0){
			assembly_file=NULL;
			error ("Error while writing assembly file");
		}
		assembly_file=NULL;
	} else {
		if (obj_file!=NULL)
			fclose (obj_file);
		if (assembly_file!=NULL)
			fclose (assembly_file);
		if (abc_file!=NULL)
			fclose (abc_file);
	}

	if (assembly_file_name_s!=NULL)
		memory_free (assembly_file_name_s);
	if (object_file_name_s!=NULL)
		memory_free (object_file_name_s);
	if (abc_file_name!=NULL)
		memory_free (abc_file_name);

	release_memory();

#ifdef PERFORMANCE
	PerfDump (ThePGlobals,"\pPerform.out",0,0);
	TermPerf (ThePGlobals);
#endif

	return r;
}

#endif
