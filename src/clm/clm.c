/*
	File:		clm.c
	Written by: John van Groningen
	At:			Radboud University Nijmegen
*/

#define CLM_VERSION "3.1"

#define VERSION 920

#if !defined (SYSTEM_LINKER) && !(defined (MACH_O64) || defined (ARM)) && !defined (_WINDOWS_)
# define OPTIMISE_LINK
#endif

#define for_l(v,l,n) for(v=(l);v!=NULL;v=v->n)

#if defined (_WINDOWS_)
# undef USE_WLINK
# define USE_CLEANLINKER
# define NO_CLIB
#endif

#if defined (_WINDOWS_) || defined (OMF) || defined (LINUX)
# define NO_ASSEMBLE
#endif

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>

#if defined(LINUX) || (defined(I486) && !defined(_WINDOWS_))
# include <unistd.h>
#endif

#include <signal.h>

#ifdef A_64
# include <stdint.h>
# define Int32 int32_t
#else
# define Int32 long
#endif

#if !(defined (_WINDOWS_))
#   include <sys/file.h>
#	include <sys/types.h>
#	include <sys/wait.h>
#endif

#include <sys/stat.h>

#define USE_PATH_CACHE 0

#if USE_PATH_CACHE
#	include "path_cache.h"
#endif

#ifdef _WINDOWS_
# ifdef __MWERKS__
#  include <x86_prefix.h>
# else
#  if !defined (GNU_C) && !defined (_X86_)
#   define _X86_
#  endif
#  include <stdarg.h>
# endif
# ifdef GNU_C
#  include <windows.h>
#  include <windef.h>
#  include <winbase.h>
#  ifdef __MINGW32__
#    define QUOTE_SPAWN_ARGUMENTS
#    include <winuser.h>
#  else
#    include <WinUser.h>
#  endif
# else
#  define QUOTE_SPAWN_ARGUMENTS
#  include <windef.h>
#  include <winbase.h>
#  include <winGDI.h>
#  include <WinUser.h>
# endif
# include <process.h>
#endif

extern char *getenv();

#ifdef PATH_MAX
#define PATH_NAME_STRING_SIZE PATH_MAX
#define PATH_LIST_STRING_SIZE (PATH_MAX*4)
#else
#define PATH_NAME_STRING_SIZE 260
#define PATH_LIST_STRING_SIZE 1024
#endif

/* file and directory names which may be patched using patchbin */
#if defined (LINUX) || defined (_WINDOWS_)
#   define QUOTE_MACRO(s) #s
#   define CMD_LINE_ARG_TO_STR(s) QUOTE_MACRO(s)
#   ifdef CLEANLIB
	char _clean_lib_directory[PATH_NAME_STRING_SIZE] = "#$@CLEANLIB  %*&" CMD_LINE_ARG_TO_STR(CLEANLIB);
#   else
	char _clean_lib_directory[PATH_NAME_STRING_SIZE] = "#$@CLEANLIB  %*&.";
#   endif
#   ifdef CLEANPATH
	char _clean_directory_list[PATH_LIST_STRING_SIZE]= "#$@CLEANPATH %*&" CMD_LINE_ARG_TO_STR(CLEANPATH);
#   else
	char _clean_directory_list[PATH_LIST_STRING_SIZE]= "#$@CLEANPATH %*&.";
#   endif
	char _clean_include_library_directory[PATH_NAME_STRING_SIZE] = "#$@CLEANILIB %*&.";
#	define clean_lib_directory (&_clean_lib_directory[16])
#	define clean_directory_list (&_clean_directory_list[16])
#	define clean_include_library_directory (&_clean_include_library_directory[16])
#endif

#if defined (I486) && !defined (LINUX)
#   ifdef _WINDOWS_
	char assembler_file_name[PATH_NAME_STRING_SIZE] = "as.exe";
#	 ifndef USE_WLINK
#     ifdef USE_CLEANLINKER
	char linker_file_name[PATH_NAME_STRING_SIZE] = "linker.exe";
#     else
	char linker_file_name[PATH_NAME_STRING_SIZE] = "ld.exe";
#     endif
	char crt0_file_name [PATH_NAME_STRING_SIZE] = "c:\\gnu\\lib\\crt0.o";
#	 else
	char linker_file_name[PATH_NAME_STRING_SIZE] = "wlink";
	char crt0_file_name [PATH_NAME_STRING_SIZE] = "crt0.o";
#	 endif
	char ld_args [PATH_NAME_STRING_SIZE] = "";
#   else
	char clean_lib_directory[PATH_NAME_STRING_SIZE] = "/usr/scratch/johnvg/clean";
	char assembler_file_name[PATH_NAME_STRING_SIZE] = "/usr/bin/as";
	char linker_file_name[PATH_NAME_STRING_SIZE] = "/usr/bin/ld";
	char crt0_file_name [PATH_NAME_STRING_SIZE] = "/usr/lib/crt0.o";
#   endif
#else
#  ifdef LINUX
/* file and directory names which may be patched using patchbin */
    char _assembler_file_name[PATH_NAME_STRING_SIZE] = "#$@ASSEMBLER %*&/usr/bin/as";
    char _linker_file_name[PATH_NAME_STRING_SIZE]    = "#$@LINKER    %*&/usr/bin/gcc";
    char _crt0_file_name [PATH_NAME_STRING_SIZE]     = "#$@CRT       %*&crt1.o";
	char _ld_args [PATH_LIST_STRING_SIZE]            = "#$@LDARGS    %*&";
/* 	char _ld_args [PATH_LIST_STRING_SIZE]			 = "#$@LDARGS    %*& --dynamic /lib/ld-linux.so.1"; */
#   define assembler_file_name (&_assembler_file_name[16])
#   define linker_file_name (&_linker_file_name[16])
#   define crt0_file_name (&_crt0_file_name[16])
#   define ld_args (&_ld_args[16])
#  else
	char clean_lib_directory[PATH_NAME_STRING_SIZE] = ".";
	char assembler_file_name[PATH_NAME_STRING_SIZE] = "/bin/as";
	char linker_file_name[PATH_NAME_STRING_SIZE] = "/bin/ld";
	char crt0_file_name [PATH_NAME_STRING_SIZE] = "/lib/crt0.o";
#  endif
#endif

/* default options of cocl */

#define DEFAULT_WARNING 				1
#define DEFAULT_NO_REUSE_UNIQUE_NODES	1
#define DEFAULT_EXPORT_LOCAL_LABELS		0
#define DEFAULT_NO_DESCRIPTORS			1
#define DEFAULT_DEBUG					0
#define DEFAULT_NO_TIME_PROFILE			1
#define DEFAULT_STRICTNESS_ANALYSIS 	1
#define DEFAULT_LIST_TYPES				0
#define DEFAULT_LIST_ALL_TYPES			0
#define DEFAULT_CALLGRAPH_PROFILE		0

#define DEBUG_MASK					1
#define NO_REUSE_UNIQUE_NODES_MASK	2
#define PARALLEL_MASK				4
#define NO_DESCRIPTORS_MASK			8
#define STRICTNESS_ANALYSIS_MASK	16
#define NO_TIME_PROFILE_MASK 		32
#define EXPORT_LOCAL_LABELS_MASK	64
#define WARNING_MASK				128
#define SYSTEM_MASK 				256
#define FUSION_MASK					512
#define A64_MASK					1024
#define DYNAMICS_MASK				2048
#define GENERIC_FUSION_MASK			4096
#define CALLGRAPH_PROFILE_MASK		8192

#define LIST_TYPES_MASK 			16384
#define LIST_ALL_TYPES_MASK 		32768

#define MEMORY_PROFILE				65536
 
#define DEFAULT_OPTIONS \
	(DEFAULT_WARNING ? WARNING_MASK : 0)\
	| (DEFAULT_NO_REUSE_UNIQUE_NODES ? NO_REUSE_UNIQUE_NODES_MASK : 0)\
	| (DEFAULT_EXPORT_LOCAL_LABELS ? EXPORT_LOCAL_LABELS_MASK : 0)\
	| (DEFAULT_NO_DESCRIPTORS ? NO_DESCRIPTORS_MASK : 0)\
	| (DEFAULT_DEBUG ? DEBUG_MASK : 0)\
	| (DEFAULT_NO_TIME_PROFILE ? NO_TIME_PROFILE_MASK : 0)\
	| (DEFAULT_STRICTNESS_ANALYSIS ? STRICTNESS_ANALYSIS_MASK : 0)\
	| (DEFAULT_LIST_TYPES ? LIST_TYPES_MASK : 0)\
	| (DEFAULT_LIST_ALL_TYPES ? LIST_ALL_TYPES_MASK : 0)\
	| (DEFAULT_CALLGRAPH_PROFILE ? CALLGRAPH_PROFILE_MASK : 0)

static int clean_options=DEFAULT_OPTIONS;
static int clean_options_mask=0;
static int remove_symbol_table;
static int list_strict_export_types=0,funcmayfail_warning_or_error=0,nowarn=0;

static char *cocl_redirect_stdout,*cocl_redirect_stdout_option;
static char *cocl_redirect_stderr,*cocl_redirect_stderr_option;
#ifdef _WINDOWS_
static int redirect_stderr_to_stdout=1;
#endif

static int check_stack_overflow,check_indices,dynamics;
#ifdef ARM
static int position_independent_code;
#endif

#ifdef _WINDOWS_
	typedef FILETIME FileTime;
#	define FILE_TIME_LE(t1,t2) ((unsigned)(t1.dwHighDateTime)<(unsigned)(t2.dwHighDateTime) \
		|| (t1.dwHighDateTime==t2.dwHighDateTime && (unsigned)(t1.dwLowDateTime)<=(unsigned)(t2.dwLowDateTime)))
#else
	typedef unsigned long FileTime;
#	define FILE_TIME_LE(t1,t2) (t1<=t2)
#endif

typedef struct project_node {
	struct project_node *		pro_next;
	char *						pro_fname;
	struct dep_list *			pro_depend;
	int 						pro_options;
	FileTime					pro_abc_time;
	FileTime					pro_dcl_time;
	unsigned int				pro_up_to_date:1,
								pro_valid_abc_time:1,
								pro_valid_dcl_time:1,
								pro_no_abc_file:1,
								pro_no_dcl_file:1,
								pro_valid_options:1,
								pro_ignore_o:1;
	struct object_file_list *	pro_imported_object_files;
} *P_NODE;

typedef struct dep_list {
	struct dep_list *		dep_next;
	P_NODE					dep_node;
} *DEP_LIST;

P_NODE first_project_node,last_project_node,main_project_node;

struct object_file_list {
	struct object_file_list *	object_file_next;
#ifdef _WINDOWS_
	int							object_file_is_library;
#endif
#if !defined (GNU_C)
	char						object_file_name[];
#else
	char						object_file_name[1];
#endif
};

struct library_list {
	struct library_list *	library_next;
#if !defined (GNU_C)
	char					library_file_name[];
#else
	char					library_file_name[1];
#endif
};

static struct library_list *first_library,*last_library;

struct export_list {
	struct export_list *	export_next;
#if !defined (GNU_C)
	char					export_name[];
#else
	char					export_name[1];
#endif
};

static struct export_list *first_export,*last_export;

struct export_file_list {
	struct export_file_list*export_file_next;
#if !defined (GNU_C)
	char					export_file_name[];
#else
	char					export_file_name[1];
#endif
};

static struct export_file_list *first_export_file,*last_export_file;

static void warning_s (char *warning_string,char *s)
{
	fprintf (stderr,warning_string,s);
	fputc ('\n',stderr);
}

static void warning_s_s (char *warning_string,char *s1,char *s2)
{
	fprintf (stderr,warning_string,s1,s2);
	fputc ('\n',stderr);
}

static void error (char *error_string)
{
	fprintf (stderr,"%s\n",error_string);
	exit (1);
}

static void error_s (char *error_string,char *s)
{
	fprintf (stderr,error_string,s);
	fputc ('\n',stderr);
	exit (1);
}

static void error_s_s (char *error_string,char *s1,char *s2)
{
	fprintf (stderr,error_string,s1,s2);
	fputc ('\n',stderr);
	exit (1);
}

static void *memory_allocate (int size)
{
	void *block;
	
	block=malloc (size);
	if (block==NULL)
		error ("Out of memory");
	return block;
}

#if defined (_WINDOWS_)
int dos_exec (char *file_name,char **args,int use_temp_file)
{
	char command[1024];

	if (!use_temp_file){
		int length;

		strcpy (command,file_name);
		strcat (command," ");

		++args;
		while (*args){
			strcat (command,*args);
			strcat (command," ");
			++args;
		}
	
		length=strlen (command);

		command[--length]='\0';

		return system (command);
	} else {
		char *temp_file_name;
		FILE *temp_file;	
		int r;

		temp_file_name="param.$$$";
# ifdef OMF
		{
			char *p;
			
			for (p=temp_file_name; *p; ++p)
				if (*p=='/')
					*p='\\';
		}
# endif
		temp_file=fopen (temp_file_name,"w");
		if (temp_file==NULL)
			return 1;

		++args;
		while (*args!=NULL){
# ifdef OMF
			if (*args!=NULL && **args==','){
				++args;
				fprintf (temp_file,"\n");
			} else {
				if (args[1]!=NULL && *args[1]=='/')
					fprintf (temp_file,"%s ",*args);
				else if (args[1]!=NULL && *args[1]!=',')
					fprintf (temp_file," %s +\n",*args);
				else
					fprintf (temp_file,"%s\n",*args);
				++args;
				if (*args!=NULL && **args==',')
					++args;
			}
# else
			fprintf (temp_file,"%s\n",*args);
			++args;
# endif
		}
			
	 	if (fclose (temp_file)!=0){
			return 1;
		}

		sprintf (command,"%s @%s",file_name,temp_file_name);
		r=system (command);

		unlink (temp_file_name);

		return r;
	}
}
#endif

static P_NODE add_project_node (char *module_name)
{
	P_NODE new_project_node;
	char *pro_fname;
	
	new_project_node=memory_allocate (sizeof (struct project_node));
	new_project_node->pro_next=NULL;
	
	pro_fname=memory_allocate (1+strlen (module_name));
	strcpy (pro_fname,module_name);

	new_project_node->pro_fname=pro_fname;
	new_project_node->pro_depend=NULL;
	new_project_node->pro_up_to_date=0;
	new_project_node->pro_valid_abc_time=0;
	new_project_node->pro_valid_dcl_time=0;
	new_project_node->pro_no_abc_file=0;
	new_project_node->pro_no_dcl_file=0;
	new_project_node->pro_ignore_o=0;
	new_project_node->pro_valid_options=0;
	new_project_node->pro_imported_object_files=NULL;
	
	if (first_project_node==NULL)
		first_project_node=new_project_node;
	else
		last_project_node->pro_next=new_project_node;
	last_project_node=new_project_node;
	
	return new_project_node;
}

static P_NODE add_dependency (DEP_LIST *dependency_list_p,char *dependent_module)
{
	DEP_LIST new_dependency,dependency;
	P_NODE project_node;

	for_l (dependency,*dependency_list_p,dep_next)
		if (!strcmp (dependent_module,dependency->dep_node->pro_fname))
			return NULL;
	
	new_dependency=memory_allocate (sizeof (struct dep_list));
	
	for_l (project_node,first_project_node,pro_next)
		if (!strcmp (dependent_module,project_node->pro_fname))
			break;

	if (project_node==NULL)
		project_node=add_project_node (dependent_module);
	
	new_dependency->dep_node=project_node;
	
	new_dependency->dep_next=*dependency_list_p;
	*dependency_list_p=new_dependency;
	
	return project_node;
}

static char *clean_path_list,clean_path_list_copy[PATH_LIST_STRING_SIZE];
static int clean_path_list_max_size;
static char *clean_lib_path,clean_lib_path_copy[PATH_NAME_STRING_SIZE];

#ifdef _WINDOWS_
# ifdef A_64
static char *clean_cocl_file_name="CleanCompiler64.exe";
# else
static char *clean_cocl_file_name="CleanCompiler.exe";
# endif
#else
static char *clean_cocl_file_name="cocl";
#endif

static char *clean_abc_path,*clean_o_path;

static int verbose=0;
static int silent=0;

#if defined (_WINDOWS_)
#	define DIRECTORY_SEPARATOR_STRING "\\"
#	define DIRECTORY_SEPARATOR_CHAR '\\'
#	define PATH_SEPARATOR_STRING ";"
#	define PATH_SEPARATOR_CHAR ';'
#else
#	define DIRECTORY_SEPARATOR_STRING "/"
#	define DIRECTORY_SEPARATOR_CHAR '/'
#	define PATH_SEPARATOR_STRING ":"
#	define PATH_SEPARATOR_CHAR ':'
#endif

static void copy_file_name_with_directory_separators (char *p,char *file_name_p)
{
	char c;

	do {
		c=*file_name_p++;
		if (c=='.')
			*p++=DIRECTORY_SEPARATOR_CHAR;
		else
			*p++=c;
	} while (c!='\0');
}

static void append_file_name_with_directory_separators (char *p,char *file_name)
{
	while (*p!='\0')
		++p;
	copy_file_name_with_directory_separators (p,file_name);
}

#ifdef _WINDOWS_
static int file_exists (char *file_name,FileTime *time_p)
{
	HANDLE h;
# ifdef GNU_C
	WIN32_FIND_DATAA find_data;

	h=FindFirstFileA (file_name,&find_data);
# else
	WIN32_FIND_DATA find_data;

	h=FindFirstFile (file_name,&find_data);
# endif
	
	if (h!=INVALID_HANDLE_VALUE){
		FindClose (h);
		*time_p=find_data.ftLastWriteTime;
		return 1;
	} else
		return 0;
}
#endif

int find_file (char *file_name,char *extension,char *complete_file_name,char *first_path
#ifdef _WINDOWS_
	,FileTime *file_time_p
#endif
	)
{
	if (file_name[0]!=DIRECTORY_SEPARATOR_CHAR){
		if (first_path!=NULL){
			strcpy (complete_file_name,first_path);
			strcat (complete_file_name,DIRECTORY_SEPARATOR_STRING);
			append_file_name_with_directory_separators (complete_file_name,file_name);
			strcat (complete_file_name,extension);
					
#ifdef _WINDOWS_
			if (file_exists (complete_file_name,file_time_p))
#else
			if (access (complete_file_name,F_OK)==0)
#endif
				return 1;
		}
			
		if (clean_path_list!=NULL){
			char *s;
			int c;
				
			s=clean_path_list;
			c=*s++;
			while (c!='\0'){
				char *p;
					
				p=complete_file_name;
	
				while (c!=PATH_SEPARATOR_CHAR && c!='\0'){
					*p++=c;
					c=*s++;
				}
	
				*p++=DIRECTORY_SEPARATOR_CHAR;
	
				copy_file_name_with_directory_separators (p,file_name);
				strcat (p,extension);
					
#ifdef _WINDOWS_
				if (file_exists (complete_file_name,file_time_p))
#else
				if (access (complete_file_name,F_OK)==0)
#endif
					return 1;
	
				if (c==PATH_SEPARATOR_CHAR)
					c=*s++;
			}
		}
	}
			
	copy_file_name_with_directory_separators (complete_file_name,file_name);
	strcat (complete_file_name,extension);
	
#ifdef _WINDOWS_
	return file_exists (complete_file_name,file_time_p);
#else
	return access (complete_file_name,F_OK)==0;
#endif
}

static void replace_file_name_in_path (char *path,char *file_name,char *extension)
{
	char *p,*last_colon;

	last_colon=path;
	p=path;
	while (*p){
		if (*p==DIRECTORY_SEPARATOR_CHAR)
			last_colon=p+1;
		++p;
	}
	strcpy (last_colon,file_name);
	strcat (last_colon,extension);
}

static void add_clean_system_files_and_replace_extension_in_path (char *path,char *extension)
{
	int path_len,dot_i,n_extra_chars,i;
	char *csfs;

	path_len=strlen (path);
	for (dot_i=path_len-1; dot_i>=0 && path[dot_i]!='.' && path[dot_i]!=DIRECTORY_SEPARATOR_CHAR; --dot_i)
		;
	if (dot_i<0 || path[dot_i]!='.')
		dot_i=path_len;
#ifndef NO_CLEAN_SYSTEM_FILES
	csfs = "Clean System Files";	
	n_extra_chars = 1+strlen(csfs);
	for (i=dot_i-1; i>=0; --i){
		char c;

		c=path[i];
		if (c==DIRECTORY_SEPARATOR_CHAR)
			break;
		path[i+n_extra_chars]=c;	
	}
	strcpy (&path[i+1],csfs);
	path[i+n_extra_chars]=DIRECTORY_SEPARATOR_CHAR;
	strcpy (&path[dot_i+n_extra_chars],extension);
#else
	strcat (&path[dot_i],extension);
#endif
}

int find_clean_system_file (char *file_name,char *extension,char *complete_file_name,char *first_path
#ifdef _WINDOWS_
	,FileTime *file_time_p
#endif
	)
{
	int found;

	found=find_file (file_name,".dcl",complete_file_name,first_path
#ifdef _WINDOWS_
	,file_time_p
#endif
		);
#ifdef _WINDOWS_
	/*	Special case for run time system on windows:
		The _startup.dcl file is implemented by multiple .o files
		(_startup0.o, _startup1.o, _startup2.o, etc.)
		If _startup0.o is searched for, _startup.dcl
	*/
	if(!strncmp(file_name,"_startup",8) && isdigit(file_name[8]) && file_name[9]=='\0') {
		found = find_file("_startup",".dcl",complete_file_name,first_path,file_time_p);
		if(found) {
			/*	Replace "_startup.dcl" at the end of the file name with the original
				file_name (startup0 or startup1 etc) plus extension
			*/
			replace_file_name_in_path(complete_file_name,file_name,extension);
		}

	}
#endif

	if (!found)
		found=find_file (file_name,".icl",complete_file_name,first_path
#ifdef _WINDOWS_
			,file_time_p
#endif
			);
	
	if (found) {
		add_clean_system_files_and_replace_extension_in_path (complete_file_name,extension);
#ifdef _WINDOWS_
		return file_exists (complete_file_name,file_time_p);
#else
		return access (complete_file_name,F_OK)==0;
#endif
	}
		
	return found;
}

static void need_file (char *file_name,char *extension,char *complete_file_name)
{
#ifdef _WINDOWS_
	FileTime time;

# ifdef QUOTE_SPAWN_ARGUMENTS
	complete_file_name[0]='\"';
	++complete_file_name;
# endif
#endif

	if (!find_clean_system_file (file_name, extension,complete_file_name,NULL
#ifdef _WINDOWS_
		,&time
#endif
	)){
#ifdef QUOTE_SPAWN_ARGUMENTS
		strcat (complete_file_name,"\"");
#endif
		fprintf (stderr,"Couldn't find %s%s\n", file_name, extension);
		exit (1);
	}
#ifdef QUOTE_SPAWN_ARGUMENTS
	else
		strcat (complete_file_name,"\"");
#endif
}

static void get_paths (void)
{
	clean_path_list=getenv ("CLEANPATH");		
	if (clean_path_list!=NULL){
		int l;
		
		l=strlen (clean_path_list);
		if (l<PATH_LIST_STRING_SIZE){
			clean_path_list=strcpy (clean_path_list_copy,clean_path_list);
			clean_path_list_max_size=PATH_LIST_STRING_SIZE;
		} else {
			clean_path_list=strcpy (memory_allocate (l+1),clean_path_list);
			clean_path_list_max_size=l+1;
		}
	} else {
		clean_path_list=clean_directory_list;
		clean_path_list_max_size=PATH_LIST_STRING_SIZE-16;
	}

	clean_lib_path=getenv ("CLEANLIB");
	if (clean_lib_path!=NULL)
		clean_lib_path=strcpy (clean_lib_path_copy,clean_lib_path);
	else
		clean_lib_path=clean_lib_directory;

	clean_abc_path=getenv ("CLEANABCPATH");
	clean_o_path=getenv ("CLEANOPATH");
}

static int get_abc_time (P_NODE project_node,FileTime *time_p)
{
	char file_name[PATH_NAME_STRING_SIZE];
	FileTime time;
	
	if (project_node->pro_valid_abc_time)
		time=project_node->pro_abc_time;
	else {
		if (project_node->pro_no_abc_file)
			return 0;

#ifdef _WINDOWS_
		if (!find_clean_system_file (project_node->pro_fname,".abc",file_name,clean_abc_path,&time))
			return 0;
#else
		{
		struct stat stat_buffer;
		
		if (!find_clean_system_file (project_node->pro_fname,".abc",file_name,clean_abc_path))
			return 0;
	
		if (stat (file_name,&stat_buffer)<0){
			project_node->pro_no_abc_file=1;
			return 0;
		}
		time=stat_buffer.st_mtime;
		}
#endif
		project_node->pro_abc_time=time;
		project_node->pro_valid_abc_time=1;
	}
	
	*time_p=time;
	return 1;
}

static int get_dcl_time (P_NODE project_node,FileTime *time_p)
{
	char file_name[PATH_NAME_STRING_SIZE];
	FileTime time;
	
	if (project_node->pro_valid_dcl_time)
		time=project_node->pro_dcl_time;
	else {
		if (project_node->pro_no_dcl_file)
			return 0;
#ifdef _WINDOWS_
		if (!find_file (project_node->pro_fname,".dcl",file_name,NULL,&time))
			return 0;
#else
		{	
		struct stat stat_buffer;

		if (!find_file (project_node->pro_fname,".dcl",file_name,NULL))
			return 0;
	
		if (stat (file_name,&stat_buffer)<0){
			project_node->pro_no_dcl_file=1;
			return 0;
		}
	
		time=stat_buffer.st_mtime;
		}
#endif
		project_node->pro_dcl_time=time;
		project_node->pro_valid_dcl_time=1;
	}
	
	*time_p=time;
	return 1;
}

static int get_time (P_NODE project_node,char *extension,FileTime *time_p,char *first_path)
{
	char file_name[PATH_NAME_STRING_SIZE];
#ifdef _WINDOWS_
	return find_file (project_node->pro_fname,extension,file_name,first_path,time_p);
#else
	struct stat stat_buffer;
		
	if (!find_file (project_node->pro_fname,extension,file_name,first_path))
		return 0;
		
	if (stat (file_name,&stat_buffer)<0)
		return 0;
	
	*time_p=stat_buffer.st_mtime;
	
	return 1;
#endif
}

static int get_clean_system_time (P_NODE project_node,char *extension,FileTime *time_p,char *first_path)
{
	char file_name[PATH_NAME_STRING_SIZE];
#ifdef _WINDOWS_
	return find_clean_system_file (project_node->pro_fname,extension,file_name,first_path,time_p);
#else
	struct stat stat_buffer;
		
	if (!find_clean_system_file (project_node->pro_fname,extension,file_name,first_path))
		return 0;
		
	if (stat (file_name,&stat_buffer)<0)
		return 0;
	
	*time_p=stat_buffer.st_mtime;
	
	return 1;
#endif
}

FILE *abc_file;
int last_char;

static int open_abc_file2 (P_NODE project_node,char file_name[])
{
	FILE *f;
	
#ifdef _WINDOWS_
	{
	FileTime time;
	
	if (!find_clean_system_file (project_node->pro_fname,".abc",file_name,clean_abc_path,&time))
		return 0;
	}
#else
	if (!find_clean_system_file (project_node->pro_fname,".abc",file_name,clean_abc_path))
		return 0;
#endif
	
	f=fopen (file_name,"r");
	if (f==NULL)
		return 0;
	
	setvbuf (f,NULL,_IOFBF,2048);
	
	last_char=getc (f);
	abc_file=f;
	return 1;
}

static int open_abc_file (P_NODE project_node)
{
	char file_name [PATH_NAME_STRING_SIZE];

	return open_abc_file2 (project_node,file_name);
}

static void skip_spaces (void)
{
	while (last_char==' ' || last_char=='\t')
		last_char=getc (abc_file);
}

static void skip_to_next_line (void)
{
	while (last_char!='\n' && last_char!=EOF)
		last_char=getc (abc_file);
	if (last_char=='\n')
		last_char=getc (abc_file);
}

static int last_char_was (int c)
{
	if (last_char==c){
		last_char=getc (abc_file);
		return 1;
	} else
		return 0;
}

static int last_char_was_digit (void)
{
	if (last_char<='9' && last_char>='0'){
		last_char=getc (abc_file);
		return 1;
	} else
		return 0;
}

static int get_version_and_options_of_abc_file (P_NODE project_node,int *version_p,long *comp_options_position_p)
{
	int version,options;
	
	*comp_options_position_p = -1;

	while (last_char!=EOF){
		skip_spaces();
		if (last_char!='.')
			return 0;
		last_char=getc (abc_file);
		if (last_char_was ('c')){
			if (last_char_was ('o') && last_char_was ('m') && last_char_was ('p')){
				int digit_1,digit_2,digit_3;
				
				skip_spaces();
				
				if ((digit_1=last_char,last_char_was_digit())
					&& (digit_2=last_char,last_char_was_digit())
					&& (digit_3=last_char,last_char_was_digit()))
				{
					int digit_n;
					
					version=(digit_1-'0')*100 + (digit_2-'0')*10 + (digit_3-'0');
					
					skip_spaces();
					
					options=0;
					if (last_char!='\n'){
						long comp_options_position;

						comp_options_position=ftell (abc_file)-1;

						for (digit_n=0; digit_n<9; ++digit_n){
							if (last_char=='0')
								;
							else if (last_char=='1')
								options |= (1<<digit_n);
							else
								return 0;
							last_char=getc (abc_file);
						}

						while (digit_n<14 && (last_char & 0xfe)=='0'){
							options |= ((last_char & 1)<<digit_n);
							last_char=getc (abc_file);
							++digit_n;
						}

						*comp_options_position_p=comp_options_position;
					}
					skip_to_next_line();
					
					project_node->pro_options=options;
					project_node->pro_valid_options=1;
					
					*version_p=version;
					return 1;
				}
			}
		} else if (last_char_was ('e') && last_char_was ('n') && last_char_was ('d')
			&& last_char_was ('i') && last_char_was ('n') && last_char_was ('f')
			&& last_char_was ('o'))
		{
			return 0;
		}
		skip_to_next_line();
	}
	return 0;
}

enum dependency_type {
	NO_DEPENDENCY,
	ABC_DEPENDENCY,
	OBJECT_FILE_DEPENDENCY,
	LIBRARY_DEPENDENCY
};

static int get_dependency_or_imported_object_or_library_file_of_abc_file (char *file_name,int max_length)
{
	int dependency_type;;

	dependency_type=ABC_DEPENDENCY;
	while (last_char!=EOF){
		skip_spaces();
		if (last_char!='.')
			return NO_DEPENDENCY;
		last_char=getc (abc_file);
		if (last_char_was ('d')){
			if (last_char_was ('e') && last_char_was ('p') && last_char_was ('e')
				&& last_char_was ('n') && last_char_was ('d'))
			{
				dependency_type=ABC_DEPENDENCY;
				break;
			}
		} else if (last_char_was ('i') && last_char_was ('m') && last_char_was ('p')){
			if (last_char_was ('o') && last_char_was ('b') && last_char_was ('j'))
			{
				dependency_type=OBJECT_FILE_DEPENDENCY;
				break;
			} else if (last_char_was ('l') && last_char_was ('i') && last_char_was ('b')){
				dependency_type=LIBRARY_DEPENDENCY;
				break;
			}
		} else if (last_char_was ('e') && last_char_was ('n') && last_char_was ('d')
			&& last_char_was ('i') && last_char_was ('n') && last_char_was ('f')
			&& last_char_was ('o'))
		{
			return 0;
		}
		skip_to_next_line();
	}

	if (dependency_type==NO_DEPENDENCY)
   		return 0;

	skip_spaces();
				
	if (last_char=='\"'){
		int n;

		last_char=getc (abc_file);
		n=0;
		while (last_char!='\"' && last_char!='\n' && last_char!=EOF
		   && n<max_length)
		{
			*file_name++=last_char;
			last_char=getc (abc_file);
			++n;
		}
		if (n<max_length && last_char=='\"'){
			*file_name='\0';
			skip_to_next_line();
			return dependency_type;
		}
	}

	return 0;
}

static void close_abc_file (void)
{
	fclose (abc_file);
}

static void add_imported_object_file_to_project_node (char *object_file_name,P_NODE project_node
#ifdef _WINDOWS_
		,int is_library
#endif
		)
{
	int object_file_name_size;
	struct object_file_list *new_imported_object_file,**object_file_h;
	int add_object_file_extension;

	object_file_name_size=strlen (object_file_name);
	
	add_object_file_extension=0;
	if (object_file_name_size>0 && object_file_name[object_file_name_size-1]=='.'){
		add_object_file_extension=1;
#if defined(_WINDOWS_) && defined(A_64)
		object_file_name_size+=3;
#else
		++object_file_name_size;
#endif
	}
	
	new_imported_object_file=memory_allocate (sizeof (struct object_file_list)+object_file_name_size+1);

	strcpy (new_imported_object_file->object_file_name,object_file_name);	
	if (add_object_file_extension){
#if defined(_WINDOWS_) && defined(A_64)
		new_imported_object_file->object_file_name[object_file_name_size-3]='o';
		new_imported_object_file->object_file_name[object_file_name_size-2]='b';
		new_imported_object_file->object_file_name[object_file_name_size-1]='j';
#else
		new_imported_object_file->object_file_name[object_file_name_size-1]='o';
#endif
		new_imported_object_file->object_file_name[object_file_name_size]='\0';
	}

#ifdef _WINDOWS_
	new_imported_object_file->object_file_is_library=is_library;
#endif
	
	new_imported_object_file->object_file_next=NULL;

	object_file_h=&project_node->pro_imported_object_files;
	while (*object_file_h!=NULL)
		object_file_h=&(*object_file_h)->object_file_next;
	*object_file_h=new_imported_object_file;
}

static int single_module=0;
static int syntax_check=0;
static int only_abc_files=0;
static int only_s_files=0;
static int only_o_files=0;

static void add_library (char *library_file_name);

static int project_node_is_abc_up_to_date (P_NODE project_node)
{
	FileTime abc_time,dcl_time,icl_time;
	int version,abc_options;
	DEP_LIST dependency_list;
	long comp_options_position;
	char abc_file_name [PATH_NAME_STRING_SIZE];
	char dependent_module [PATH_NAME_STRING_SIZE];

	if (!get_abc_time (project_node,&abc_time)){
		if (verbose)
			warning_s ("(%s.abc doesn't exist)",project_node->pro_fname);
		return 0;
	}
	
	if (!open_abc_file2 (project_node,abc_file_name))
		return 0;
	
	if (!get_version_and_options_of_abc_file (project_node,&version,&comp_options_position)){
		close_abc_file();
		return 0;
	}
	abc_options=project_node->pro_options;
	
	if (version!=VERSION){
		close_abc_file();
		warning_s ("Warning: %s.abc is generated with another compiler version",
				   project_node->pro_fname);
		return 0;
	}
	
	if (!(abc_options & SYSTEM_MASK)){
		if (abc_options & PARALLEL_MASK){
			if (verbose)
				warning_s ("(%s.abc is not sequential abc code)",
						   project_node->pro_fname);
			close_abc_file();
			return 0;
		}

		if (((NO_TIME_PROFILE_MASK | CALLGRAPH_PROFILE_MASK) & (clean_options ^ abc_options))!=0){
			if (verbose)
 				warning_s ("(%s.icl is compiled with different time profile options)",project_node->pro_fname);
			close_abc_file();
			return 0;
		}

		if ((NO_DESCRIPTORS_MASK & (clean_options ^ abc_options))!=0){
			if (verbose)
 				warning_s ("(%s.icl is compiled with different descriptors option)",project_node->pro_fname);
			close_abc_file();
			return 0;
		}

		if ((EXPORT_LOCAL_LABELS_MASK & (clean_options ^ abc_options))!=0){
			if (verbose)
 				warning_s ("(%s.icl is compiled with different export local labels option)",project_node->pro_fname);
			close_abc_file();
			return 0;
		}

		if (get_time (project_node,".icl",&icl_time,NULL) && FILE_TIME_LE (abc_time,icl_time)){
			if (verbose)
				warning_s ("(%s.abc is older than corresponding icl file)",
						   project_node->pro_fname);
			close_abc_file();
			return 0;
		}
		
		if (get_dcl_time (project_node,&dcl_time) && FILE_TIME_LE (abc_time,dcl_time)){
			if (verbose)
				warning_s ("(%s.abc is older than corresponding dcl file)",
						   project_node->pro_fname);
			return 0;
		}
	} else {
		if (((NO_TIME_PROFILE_MASK | CALLGRAPH_PROFILE_MASK) & (clean_options ^ abc_options))!=0){
			if (verbose)
 				warning_s ("(%s.icl is compiled with different time profile options)",project_node->pro_fname);
			close_abc_file();

			if (comp_options_position>=0){
				FILE *f;
				int c;

				f=fopen (abc_file_name,"r+");
				if (f==NULL)
					error_s ("Could not write to file %s\n",abc_file_name);
		
				if (fseek (f,comp_options_position+5,SEEK_SET)!=0)
					error_s ("Could not write to file %s\n",abc_file_name);

				if ((clean_options & NO_TIME_PROFILE_MASK)==0)
					fputc ('0',f);
				else
					fputc ('1',f);

				if (fseek (f,comp_options_position+13,SEEK_SET)!=0)
					error_s ("Could not write to file %s\n",abc_file_name);

				c=fgetc (f);
				if (c=='0' || c=='1'){
					char callgraph_profile_c;

					callgraph_profile_c = (clean_options & CALLGRAPH_PROFILE_MASK) ? '1' : '0';
					if (c!=callgraph_profile_c){
						if (fseek (f,comp_options_position+13,SEEK_SET)!=0)
							error_s ("Could not write to file %s\n",abc_file_name);

						fputc (callgraph_profile_c,f);
					}
				} else if (clean_options & CALLGRAPH_PROFILE_MASK)
					error_s ("Failed to patch %s for callgraph profiling",abc_file_name);
	
				if (fclose (f)!=0)
					error_s ("Could not write to file %s\n",abc_file_name);
			
				project_node->pro_options &= ~(NO_TIME_PROFILE_MASK | CALLGRAPH_PROFILE_MASK);
				project_node->pro_options |= clean_options & (NO_TIME_PROFILE_MASK | CALLGRAPH_PROFILE_MASK);
				project_node->pro_valid_abc_time=0;

				return 1;
			}
	
			return 0;
		}
	}
	
	if (project_node==main_project_node &&
		((DEBUG_MASK | STRICTNESS_ANALYSIS_MASK | FUSION_MASK | GENERIC_FUSION_MASK | NO_REUSE_UNIQUE_NODES_MASK) & clean_options_mask & (clean_options ^ abc_options))!=0)
	{
		if (verbose)
			warning_s ("(%s.icl is compiled with different options)", project_node->pro_fname);

		close_abc_file();
		return 0;
	}	

	{
	enum dependency_type dependency_type;

	dependency_list=NULL;
	while (
		dependency_type=get_dependency_or_imported_object_or_library_file_of_abc_file (dependent_module,PATH_NAME_STRING_SIZE-1),
		dependency_type!=NO_DEPENDENCY
	){
		if (dependency_type==ABC_DEPENDENCY){
			FileTime dcl_time;
			P_NODE dependency_node;
		
			dependency_node=add_dependency (&dependency_list,dependent_module);
		
			if (dependency_node==NULL)
				continue;
		
			if (!(abc_options & SYSTEM_MASK)){
				if (get_dcl_time (dependency_node,&dcl_time) && FILE_TIME_LE(abc_time,dcl_time)){
					if (verbose)
						warning_s_s ("(%s.icl conflicts with %s.dcl)",project_node->pro_fname,
									 dependent_module);
					close_abc_file();
					return 0;
				}
			
				/*
				if (is_system_file (dependency_node)){
					long dcl_abc_time;
				
					if (get_abc_time (dependency_node,&dcl_abc_time) && abc_time<=dcl_abc_time){
						if (verbose)
							warning_s_s ("(%s.icl conflicts with %s.abc)",
										 project_node->pro_fname,dependency_node->pro_fname);
						close_abc_file();
						return 0;
					}
				}
				*/
			}
		} else if (dependency_type==OBJECT_FILE_DEPENDENCY)
			add_imported_object_file_to_project_node (dependent_module,project_node
#ifdef _WINDOWS_
					,0
#endif
					);
		else if (dependency_type==LIBRARY_DEPENDENCY){
#ifdef _WINDOWS_
			if (!(dependent_module[0]=='-' && dependent_module[1]=='l'))
				add_imported_object_file_to_project_node (dependent_module,project_node,1);
#else
			if (dependent_module[0]=='-' && dependent_module[1]=='l')
				add_library (dependent_module);
			else if (strchr (dependent_module,'.')!=NULL)
				add_imported_object_file_to_project_node (dependent_module,project_node);
#endif
		}
	}

	}

	close_abc_file();
	
	project_node->pro_depend=dependency_list;
	
	if (verbose)
		warning_s ("(%s.abc is up to date)",project_node->pro_fname);
	return 1;
}

static int is_system_file (P_NODE project_node)
{
	if (project_node->pro_no_abc_file)
		return 0;
	
	if (!project_node->pro_valid_options){
		int version;
		long comp_options_position;
		FILE *old_file;
		
		old_file=abc_file;
		
		if (!open_abc_file (project_node)){
			abc_file=old_file;
			return 0;
		}
	
		if (!get_version_and_options_of_abc_file (project_node,&version,&comp_options_position)){
			close_abc_file();
			abc_file=old_file;
			return 0;
		}
		close_abc_file();
		abc_file=old_file;
	}
	
	return (project_node->pro_options & SYSTEM_MASK)!=0;
}

#if defined(_WINDOWS_) && defined (GNU_C)
extern int wait (int*);
#endif

#include <errno.h>

#if !defined (_WINDOWS_)
static int wait_for_child (pid_t pid, char *child_name, int *status_p)
{
    int result;

   	result=waitpid (pid, status_p, 0);

    if (*status_p & 255)
        fprintf (stderr,"%s exited abnormally\n",child_name);

    return result;
}
#endif

#define CACHING_COMPILER

#ifdef CACHING_COMPILER
static char *concatenate_args (char **argv)
{
	int size;
	char **argv2, *p, *args;

	if (*argv == NULL)
		error ("concatenate_args: no args\n");

	size=0;
	for (argv2=argv; *argv2!=NULL; argv2++){
		char *arg;

		size += 1; /* '"' */
		for (arg=*argv2; *arg!='\0'; arg++)
			if (*arg=='"')
				size += 2; /* '\' and '"' */
			else
				size += 1; /* c */
		size += 2; /* '"' and (' ' or '\0') */
	}

	args=malloc(size);
	if (args==NULL)
		return NULL;

	p=args;
	for (argv2=argv; *argv2!=NULL; argv2++){
		char *arg;

		*p++='"';
		for (arg=*argv2; *arg!='\0'; arg++)
			if (*arg=='"')
			{
				*p++='\\';
				*p++='"';
			}
			else
				*p++=*arg;
		*p++='"';
		*p++=' ';
	}
	*(p-1)='\0';

	if (p-args!=size)
		error ("concatenate_args: fatal programming error\n");

	return args;
}

# ifdef _WINDOWS_

static int CleanCompiler_message_nunber;

static int get_message_number (void)
{
	return RegisterWindowMessage ("CleanCompiler");
}

static int get_current_thread_id (void)
{
	return GetCurrentThreadId();
}

static int compiler_started=0;

static int compiler_wm_number;
static int compiler_thread_id;
static size_t compiler_thread_handle;
static size_t compiler_process_handle;

static HANDLE std_output_pipe_read_handle,std_output;
static HANDLE std_error_pipe_read_handle,std_error;

static DWORD copy_std_output_thread_id,copy_std_error_thread_id;
static HANDLE copy_std_output_thread_handle,copy_std_error_thread_handle;

static DWORD WINAPI copy_std_output_thread_function (LPVOID unused_thread_parameter)
{
	HANDLE local_std_output_pipe_read_handle,local_std_output;
	CHAR read_buffer[512];

	local_std_output_pipe_read_handle = std_output_pipe_read_handle;
	local_std_output = std_output;
	
	for (;;){
		DWORD n_bytes_read,n_bytes_written;

		if (! ReadFile (local_std_output_pipe_read_handle, read_buffer, sizeof (read_buffer), &n_bytes_read, NULL) || n_bytes_read==0)
			break;
		if (! WriteFile (local_std_output, read_buffer, n_bytes_read, &n_bytes_written, NULL))
			break;
	}

	return 1;
}

static DWORD WINAPI copy_std_error_thread_function (LPVOID unused_thread_parameter)
{
	HANDLE local_std_error_pipe_read_handle,local_std_error;
	CHAR read_buffer[512];

	local_std_error_pipe_read_handle = std_error_pipe_read_handle;
	local_std_error = std_error;
	
	for (;;){
		DWORD n_bytes_read,n_bytes_written;

		if (! ReadFile (local_std_error_pipe_read_handle, read_buffer, sizeof (read_buffer), &n_bytes_read, NULL) || n_bytes_read==0)
			break;
		if (! WriteFile (local_std_error, read_buffer, n_bytes_read, &n_bytes_written, NULL))
			break;
	}
	
	return 1;
}

static int start_compiler_process
	(char *compiler_path,char *compiler_directory,char *command,
	 int *compiler_thread_id_p,size_t *compiler_thread_handle_p,size_t *compiler_process_handle_p)
{
	HANDLE std_output_pipe_write_handle,std_error_pipe_write_handle;
	PSTR env;
	STARTUPINFO si;
	PROCESS_INFORMATION pi;
	SECURITY_ATTRIBUTES sa;
	int r;
	
	/*
	a process cannot inherit a console handle on windows, therefore we create copies using pipes
	(not necessary if a handle is redirected to a file)
	*/

	std_output = GetStdHandle (STD_OUTPUT_HANDLE);
	if (!redirect_stderr_to_stdout)
		std_error = GetStdHandle (STD_ERROR_HANDLE);

	sa.nLength = sizeof (SECURITY_ATTRIBUTES);
	sa.lpSecurityDescriptor = NULL;
	sa.bInheritHandle = TRUE;

	if (!CreatePipe (&std_output_pipe_read_handle,&std_output_pipe_write_handle,&sa,0)){
		printf ("CreatePipe failed\n");
		exit (1);
	}
	if (!SetHandleInformation (std_output_pipe_read_handle,HANDLE_FLAG_INHERIT,0)){
		printf ("SetHandleInformation failed\n");
		exit (1);	
	}

	if (!redirect_stderr_to_stdout){
		if (!CreatePipe (&std_error_pipe_read_handle,&std_error_pipe_write_handle,&sa,0)){
			printf ("CreatePipe failed\n");
			exit (1);
		}
		if (!SetHandleInformation (std_error_pipe_read_handle,HANDLE_FLAG_INHERIT,0)){
			printf ("SetHandleInformation failed\n");
			exit (1);	
		}
	} else {
		if (!DuplicateHandle (GetCurrentProcess(),std_output_pipe_write_handle,GetCurrentProcess(),&std_error_pipe_write_handle,0,TRUE,DUPLICATE_SAME_ACCESS)){
			printf ("DuplicateHandle failed\n");
			exit (1);	
		}
	}

	env=NULL;
	
	si.cb = sizeof (STARTUPINFO);
	si.lpReserved = NULL;
	si.lpReserved2 = NULL;
	si.cbReserved2 = 0;
	si.lpDesktop = NULL;
	si.lpTitle = NULL;
	si.dwFlags = STARTF_USESTDHANDLES;
	si.hStdInput = GetStdHandle (STD_INPUT_HANDLE);
	si.hStdOutput = std_output_pipe_write_handle;
	si.hStdError = std_error_pipe_write_handle;

	r=CreateProcess (compiler_path,command,NULL,NULL,TRUE,0/*CREATE_NEW_CONSOLE*//*DETACHED_PROCESS*/,env,compiler_directory,&si,&pi);

	copy_std_output_thread_handle = CreateThread (NULL,0,copy_std_output_thread_function,(LPVOID)NULL,0,&copy_std_output_thread_id);
	if (!redirect_stderr_to_stdout)
		copy_std_error_thread_handle = CreateThread (NULL,0,copy_std_error_thread_function,(LPVOID)NULL,0,&copy_std_error_thread_id);

	if (r!=0){
		*compiler_thread_id_p=pi.dwThreadId;
		*compiler_thread_handle_p=(size_t)pi.hThread;
		*compiler_process_handle_p=(size_t)pi.hProcess;
	} else {
		*compiler_thread_id_p=0;
		*compiler_thread_handle_p=0;
		*compiler_process_handle_p=0;
	}
	
	return r;
}

static void start_compiler (void)
{
	int thread_id,r,i;
	char *end_command_line_p;
	char cocl_file_name[PATH_NAME_STRING_SIZE];
	char command_line[PATH_NAME_STRING_SIZE+32];

	compiler_wm_number = get_message_number();

	thread_id = get_current_thread_id();

	strcpy (cocl_file_name,clean_lib_path);
	strcat (cocl_file_name,"\\");
	strcat (cocl_file_name,clean_cocl_file_name);

	command_line[0]='\"';
	strcpy (command_line+1,cocl_file_name);
	strcat (command_line+1,"\" -con -ide ");

	end_command_line_p = command_line + strlen (command_line);
	for (i=7; i>=0; --i){
		int c;
		
		c = thread_id & 0xf;
		thread_id >>= 4;
		end_command_line_p[i] = c<10 ? ('0'+c) : ('A'-10+c);
	}
	end_command_line_p[8] = '\0';

	r = start_compiler_process (cocl_file_name,NULL/*clean_lib_path*/,command_line,
								 &compiler_thread_id,&compiler_thread_handle,&compiler_process_handle);
	
	if (r==0){
		fprintf (stderr,"Couldn't start compiler: %s\n", cocl_file_name);
		exit (1);
	}
}

static int send_string_to_thread (int thread_id,size_t process_handle,int wm_number,char *s)
{
	HANDLE file_map,file_map2;
	char *p1;
	int r,l;

	l=strlen (s)+1;
	
	file_map=CreateFileMapping (INVALID_HANDLE_VALUE,NULL,PAGE_READWRITE,0,l,NULL);
	if (file_map==NULL)
		return 0;

	p1=MapViewOfFile (file_map,FILE_MAP_ALL_ACCESS,0,0,l);
	if (p1==NULL)
		return 0;
		
	{
		char *s_p,*d_p,c;
		
		s_p=s;
		d_p=p1;
		do {
			c=*s_p++;
			*d_p++=c;
		} while (c!='\0');
	}
	
	UnmapViewOfFile (p1);

	r=DuplicateHandle (GetCurrentProcess(),file_map,(HANDLE)process_handle,&file_map2,0,0,DUPLICATE_CLOSE_SOURCE | DUPLICATE_SAME_ACCESS);

	if (r==0)
		return 0;

	do
		r=PostThreadMessage (thread_id,wm_number,l,(int)file_map2);
	while (r==0);
	
	return r;
}

#define PM_QS_POSTMESSAGE   ((QS_POSTMESSAGE | QS_HOTKEY | QS_TIMER) << 16)

static int get_integers_from_thread_message (int wm_number,size_t thread_handle,int *i1_p,int *i2_p)
{
	MSG message;
	int r;

	r=PeekMessage (&message,INVALID_HANDLE_VALUE,wm_number,wm_number,PM_NOREMOVE | (QS_POSTMESSAGE<<16));
	if (r==0){
		r=MsgWaitForMultipleObjects (1,(HANDLE*)&thread_handle,0,INFINITE,QS_POSTMESSAGE);

		if (r==-1 || r==WAIT_OBJECT_0 || r==WAIT_ABANDONED_0){
			*i1_p=0;
			*i2_p=0;
			return 0;
		}

		do {
			r=PeekMessage (&message,INVALID_HANDLE_VALUE,wm_number,wm_number,PM_NOREMOVE | (QS_POSTMESSAGE<<16));
		} while (r==0);
	}

	r=PeekMessage (&message,INVALID_HANDLE_VALUE,wm_number,wm_number,PM_REMOVE | (QS_POSTMESSAGE<<16));
/*	r=GetMessage (&message,INVALID_HANDLE_VALUE,wm_number,wm_number); */

	if (r!=0){
		*i1_p=message.wParam;
		*i2_p=message.lParam;
	} else {
		*i1_p=0;
		*i2_p=0;
	}
	
	return r;
}

static int call_caching_compiler (char *args)
{
	int r,i1,i2;
	
	if (!send_string_to_thread (compiler_thread_id,compiler_process_handle,compiler_wm_number,args)){
		fprintf (stderr,"Couldn't send message to the compiler\n");
		exit (1);
	}
	
	r = get_integers_from_thread_message (compiler_wm_number,compiler_thread_handle,&i1,&i2);
	if (r==0){
		fprintf (stderr,"Couldn't receive message from the compiler\n");
		exit (1);	
	}

	return i2;
}

static void stop_compiler (void)
{
	if (!send_string_to_thread (compiler_thread_id,compiler_process_handle,compiler_wm_number,"exit")){
		fprintf (stderr,"Couldn't send exit message to the compiler\n");
		exit (1);
	}
}

static int call_compiler (char * /*unused*/cocl_file_name, char **argv)
{
	int r;
	char *args;

	if (!compiler_started){
		start_compiler();
		compiler_started=1;
	}

	args=concatenate_args (argv);
	if (args != NULL){
		/* printf ("call compiler with:\n%s\n",args); */
	
		r=call_caching_compiler ((unsigned char *)args);
		free (args);
	}
	else
		r=-1;

	return r>=0;
}

# else

static char **cocl_argv=NULL;
static int cocl_argv_size;

static void add_compiler_arguments (char *s)
{
	char *s_p,*arg_chars,*arg_chars_p,**argv,c;
	int arg_n,argv_size;

	argv_size=6;
	for (s_p=s; (c=*s_p)!='\0'; ++s_p)
		if (c==',')
			++argv_size;

	argv=memory_allocate (argv_size*sizeof (char*));
	arg_chars=memory_allocate (s_p-s+1);
	
	arg_chars_p=arg_chars;
	argv[1]=arg_chars_p;
	arg_n=2;
	for (s_p=s; (c=*s_p)!='\0'; ++s_p){
		if (c==','){
			*arg_chars_p++='\0';
			argv[arg_n++]=arg_chars_p;					
		} else
			*arg_chars_p++=c;
	}
	*arg_chars_p=c;	

	cocl_argv_size=argv_size;
	cocl_argv=argv;
}

#include "Clean.h"
#include "cachingcompiler.h"

static int compiler_started=0;

static void start_compiler (void)
{
	int r;
	char cocl_file_name[PATH_NAME_STRING_SIZE];

	strcpy (cocl_file_name,clean_lib_path);
	strcat (cocl_file_name,"/");
	strcat (cocl_file_name,clean_cocl_file_name);

	if (cocl_argv==NULL)
		r=start_caching_compiler ((unsigned char *)cocl_file_name);
	else
		r=start_caching_compiler_with_args ((unsigned char *)cocl_file_name,cocl_argv,cocl_argv_size);

	if (r < 0)
		exit(r);	
}

static void stop_compiler (void)
{
	int r;

	r=stop_caching_compiler();
	if (r < 0)
		exit(r);
}

 #endif
#endif

#if !defined (_WINDOWS_)
static int call_compiler (char *cocl_file_name, char **argv)
{
# ifdef CACHING_COMPILER
	int r;
	char *args;

	if (!compiler_started){
		start_compiler();
		compiler_started=1;
	}

	args=concatenate_args(argv);
	if (args != NULL)
	{
		r=call_caching_compiler ((unsigned char *)args);
		free (args);
	}
	else
		r=-1;

	return r>=0;
# else /* ifndef CACHING_COMPILER */
	int pid,r,status;

	pid=fork();
	if (pid<0)
		error ("Fork failed");
	
	if (!pid){
		strcat (cocl_file_name,"/");
		strcat (cocl_file_name,clean_cocl_file_name);
		execv (cocl_file_name,argv);
		
		error ("Can't execute the clean compiler");
	}
	
	r=wait_for_child (pid, "Clean compiler",&status);
	
	return r>=0 && status==0;
# endif
}
#endif

static int compile_project_node (P_NODE project_node)
{
	char file_name[PATH_NAME_STRING_SIZE];
	char *abc_file_name,abc_file_name_s[PATH_NAME_STRING_SIZE];
	char cocl_file_name[PATH_NAME_STRING_SIZE];
	char *argv[16],**arg;
	int options;

	if (!silent)
		printf ("Compiling %s\n",project_node->pro_fname);
	
	project_node->pro_no_abc_file=0;
	project_node->pro_valid_abc_time=0;

#ifdef _WINDOWS_
	{
	FileTime time;
	
	if (!find_file (project_node->pro_fname,".icl",file_name,NULL,&time))
		error_s ("Can't find %s.icl",project_node->pro_fname);
	}
#else
	if (!find_file (project_node->pro_fname,".icl",file_name,NULL))
		error_s ("Can't find %s.icl",project_node->pro_fname);
#endif

#if defined (_WINDOWS_) && !defined (CACHING_COMPILER)
	abc_file_name_s[0]='\"';
	abc_file_name=&abc_file_name_s[1];
#else
	abc_file_name=abc_file_name_s;
#endif

	if (clean_abc_path==NULL){
#ifdef NO_CLEAN_SYSTEM_FILES
		int length;
#endif
		strcpy (abc_file_name,file_name);
#ifdef NO_CLEAN_SYSTEM_FILES
		length=strlen (abc_file_name);
		abc_file_name[length-3]='a';
		abc_file_name[length-2]='b';
		abc_file_name[length-1]='c';
#else
		{
			char *p,*last_colon,*begin_file_name;
			
			last_colon=abc_file_name;
			p=abc_file_name;
			while (*p){
				if (*p==DIRECTORY_SEPARATOR_CHAR)
					last_colon=p+1;
				++p;
			}
			strcpy (last_colon,"Clean System Files");
		
			if (access (abc_file_name,0)!=0){
#if defined(_WINDOWS_) && (!defined(GNU_C) || defined(__MINGW32__))
				if (mkdir (abc_file_name)!=0)
#else
				if (mkdir (abc_file_name,0777)!=0)
#endif
					error_s ("Could not create directory %s\n",abc_file_name);
			}

			strcat (last_colon,DIRECTORY_SEPARATOR_STRING);
			begin_file_name=project_node->pro_fname;
			for (p=begin_file_name; *p!='\0'; ++p)
				if (*p=='.')
					begin_file_name=p+1;
			strcat (last_colon,begin_file_name);
			strcat (last_colon,".abc");
		}
#endif
	} else {
		strcpy (abc_file_name,clean_abc_path);
		strcat (abc_file_name,DIRECTORY_SEPARATOR_STRING);
		strcat (abc_file_name,project_node->pro_fname);
		strcat (abc_file_name,".abc");
	}

#if defined (_WINDOWS_) && !defined (CACHING_COMPILER)
	strcat (abc_file_name,"\"");
	abc_file_name=abc_file_name_s;
#endif

	{
		char *p;
		int file_name_len;

		p=&file_name[strlen (file_name)];
		if (p-4>=file_name && p[-4]=='.')
			p-=4;

		file_name_len=strlen (project_node->pro_fname);
		if (p-file_name_len>=file_name){
			int i;

			p-=file_name_len;
			for (i=0; i<file_name_len; ++i)
				if (p[i]==DIRECTORY_SEPARATOR_CHAR)
					p[i]='.';
		}
	}

	arg=argv;
	*arg++="cocl";

#if defined (_WINDOWS_) && !defined (CACHING_COMPILER)
	*arg++="-con";
#endif

    if (cocl_redirect_stdout!=NULL){
        *arg++ = cocl_redirect_stdout_option;
        *arg++ = cocl_redirect_stdout;
    }

    if (cocl_redirect_stderr!=NULL){
        *arg++ = cocl_redirect_stderr_option;
        *arg++ = cocl_redirect_stderr;
    }

	*arg++="-sl";

#ifndef NO_CLEAN_SYSTEM_FILES
# ifndef _WINDOWS_
	*arg++="-csf";
# endif
#endif
	
	*arg++="-P";
	
	if (clean_path_list!=NULL) {
		int path_list_length;
		char *cocl_path_list;

		path_list_length=strlen (clean_path_list)+3;
#if defined (_WINDOWS_) && !defined (CACHING_COMPILER)
		cocl_path_list=memory_allocate (path_list_length+2);
		cocl_path_list[0]='\"';
		cocl_path_list[1]='\0';
		strcat (cocl_path_list+1,clean_path_list);
		strcat (cocl_path_list+1,PATH_SEPARATOR_STRING "." "\"");
#else
		cocl_path_list=memory_allocate (path_list_length);
		cocl_path_list[0]='\0';
		strcat (cocl_path_list,clean_path_list);
		strcat (cocl_path_list,PATH_SEPARATOR_STRING ".");
#endif

		*arg++=cocl_path_list;
	} else
		*arg++=".";
	
	if (syntax_check)
		*arg++="-c";
	
	if (((clean_options & EXPORT_LOCAL_LABELS_MASK)!=0)!=DEFAULT_EXPORT_LOCAL_LABELS)
		*arg++="-exl";
	if (((clean_options & NO_DESCRIPTORS_MASK)!=0)!=DEFAULT_NO_DESCRIPTORS)
		*arg++="-desc";
	if (((clean_options & LIST_TYPES_MASK)!=0)!=DEFAULT_LIST_TYPES)
		*arg++="-lt";
	if (((clean_options & LIST_ALL_TYPES_MASK)!=0)!=DEFAULT_LIST_ALL_TYPES)
		*arg++="-lat";

	if ((clean_options & MEMORY_PROFILE)!=0)
		*arg++="-pm";
	if ((clean_options & NO_TIME_PROFILE_MASK)==0)
		*arg++="-pt";
	if ((clean_options & CALLGRAPH_PROFILE_MASK)!=0)
		*arg++="-pg";
	if (dynamics)
		*arg++="-dynamics";

	if (project_node->pro_valid_options)
		options=project_node->pro_options;
	else
		options=DEFAULT_OPTIONS;

	project_node->pro_valid_options=0;
		
	if (project_node==main_project_node)
		options=(options & ~clean_options_mask) 
				| (clean_options & clean_options_mask);
	
	if (nowarn || ((options & WARNING_MASK)!=0)!=DEFAULT_WARNING)
		*arg++="-w";
	if (((options & DEBUG_MASK)!=0)!=DEFAULT_DEBUG)
		*arg++="-d";
	if (((options & STRICTNESS_ANALYSIS_MASK)!=0)!=DEFAULT_STRICTNESS_ANALYSIS)
		*arg++="-sa";
	if ((options & NO_REUSE_UNIQUE_NODES_MASK)==0)
		*arg++="-ou";
	if ((options & FUSION_MASK)!=0)
		*arg++="-fusion";
	if ((options & GENERIC_FUSION_MASK)!=0)
		*arg++="-generic_fusion";

	if (list_strict_export_types)
		*arg++="-lset";

	if (funcmayfail_warning_or_error)
		*arg++=funcmayfail_warning_or_error==2 ? "-emf" : "-wmf";

	*arg++="-wmt"; // Always write modification time to prevent re-compilation by cpm.

	*arg++="-o";
	*arg++=abc_file_name;

	*arg++=file_name;
	*arg=NULL;


	strcpy (cocl_file_name,clean_lib_path);
#if !defined (CACHING_COMPILER) && (defined (_WINDOWS_))
	strcat (cocl_file_name,"\\");
	strcat (cocl_file_name,clean_cocl_file_name);
	argv[0]=cocl_file_name;
# ifdef SPAWNVP_AND_WAIT
	{
	int r,status;
	
	r=spawnvp (_P_WAIT,cocl_file_name,argv);
	if (r>=0)
		r=wait (&status);
	return r>=0 && status==0;
	}
# else
	{
	int r;
	r=spawnv (_P_WAIT,cocl_file_name,argv);
	
	if (r<0){
		char error_s[256];
		
		if (errno==ENOENT)
			sprintf (error_s,"Cannot execute the clean compiler, %s does not exist",cocl_file_name);
		else
			sprintf  (error_s,"Error while executing the clean compiler %d %d",r,errno);
		error (error_s);
	} 
	
	return r==0;
	}
# endif
#else
	return call_compiler (cocl_file_name, argv);
#endif
}

#if (defined (_WINDOWS_) && (defined (USE_WLINK)) || defined (OMF))
#	define OBJECT_FILE_EXTENSION ".obj"
#else
#	define OBJECT_FILE_EXTENSION ".o"
#endif

static int generate_code_for_project_node (P_NODE project_node,char *file_name)
{
	char *argv[16],**arg;
#ifdef QUOTE_SPAWN_ARGUMENTS
	char quoted_cg_file_name[PATH_NAME_STRING_SIZE];
#endif

	if (!silent)
		printf ("Generating code for %s\n",project_node->pro_fname);
		
	arg=argv;
	*arg++="cg";

#if defined (NO_ASSEMBLE)
	if (only_s_files)
		*arg++="-a";
#endif
	if (check_stack_overflow)
		*arg++="-os";

	if (check_indices)
		*arg++="-ci";

#ifdef ARM
	if (position_independent_code)
		*arg++="-pic";
#endif

	*arg++=file_name;
	*arg=NULL;

	{
	char cg_file_name[PATH_NAME_STRING_SIZE];

	strcpy (cg_file_name,clean_lib_path);

#ifdef _WINDOWS_
# ifdef A_64
	strcat (cg_file_name,"\\CodeGenerator64.exe");
# else
	strcat (cg_file_name,"\\CodeGenerator.exe");
# endif

# ifdef QUOTE_SPAWN_ARGUMENTS
	quoted_cg_file_name[0]='\"';
	strcpy (quoted_cg_file_name+1,cg_file_name);
	strcat (quoted_cg_file_name+1,"\"");

	argv[0]=quoted_cg_file_name;
# else
	argv[0]=cg_file_name;
# endif

# ifdef SPAWNVP_AND_WAIT
	{
		int r,status;
	
		argv[0]=cg_file_name;
		r=spawnvp (_P_WAIT,cg_file_name,argv);
		if (r>=0)
			r=wait (&status);
		return r>=0 && status==0;
	}
# else
	{
	int r;

	r=spawnv(_P_WAIT,cg_file_name,argv);

	if (r<0){
		char error_s[256];
		
		if (errno==ENOENT)
			sprintf (error_s,"Cannot execute the code generator, %s does not exist",cg_file_name);
		else
			sprintf  (error_s,"Error while executing the code generator %d %d",r,errno);
		error (error_s);
	}
	
	return r==0;
	}
# endif
#else
	{
		int pid,r,status;
	
		pid=fork();
		if (pid<0)
			error ("Fork failed");
		
		if (!pid){
			strcat (cg_file_name,"/cg");

			execv (cg_file_name,argv);
			
			error ("Can't execute the code generator");
		}
	
		r=wait_for_child (pid, "Code generator",&status);
		return r>=0 && status==0;
	}
#endif
	}
}

#if !defined (NO_ASSEMBLE)
static int assemble (P_NODE project_node,char *file_name)
{
	int pid,r,status;
	char s_file_name[PATH_NAME_STRING_SIZE],o_file_name[PATH_NAME_STRING_SIZE];
	
	if (!silent)
		printf ("Assembling %s\n",project_node->pro_fname);

	strcpy (s_file_name,file_name);
	strcat (s_file_name,".s");

	if (clean_o_path==NULL)
		strcpy (o_file_name,file_name);
	else {
		strcpy (o_file_name,clean_o_path);
		strcat (o_file_name,DIRECTORY_SEPARATOR_STRING);
		strcat (o_file_name,project_node->pro_fname);
	}
	strcat (o_file_name,OBJECT_FILE_EXTENSION);

# if !(defined (_WINDOWS_))
	pid=fork();
	if (pid<0)
		error ("Fork failed");
	
	if (!pid)
# endif
	{
		char *argv[16],**arg;
		
		arg=argv;
		*arg++="as";

		*arg++=s_file_name;
		*arg++="-o";
		*arg++=o_file_name;
		*arg=0;
# if defined (_WINDOWS_)
#  ifdef _WINDOWS_
#   ifdef SPAWNVP_AND_WAIT
		{
			int status;
		
			argv[0]=assembler_file_name;
			r=spawnvp (_P_WAIT,assembler_file_name,argv);
			if (r>=0)
				r=wait (&status);
			return r>=0 && status==0;
		}
#   else
		return spawnvp (_P_WAIT,assembler_file_name,argv)==0;
#   endif
#  else
		r=dos_exec (assembler_file_name,argv,1);
#  endif
		return r==0;
	}
# else
		execv (assembler_file_name,argv);

		error ("Can't execute the assembler");
	}
	
	r=wait_for_child (pid, "Assembler",&status);
	return r>=0 && status==0;
# endif
}
#endif

static void get_dependencies (P_NODE project_node)
{
	DEP_LIST dependency_list;
	char dependent_module [PATH_NAME_STRING_SIZE];
	long comp_options_position;
	int dependency_type,version;

	if (!open_abc_file (project_node))
		return;

	if (!get_version_and_options_of_abc_file (project_node,&version,&comp_options_position)){
		close_abc_file();
		return;
	}

	dependency_list=NULL;
	do {
		dependency_type=get_dependency_or_imported_object_or_library_file_of_abc_file (dependent_module,PATH_NAME_STRING_SIZE-1);

		if (dependency_type==ABC_DEPENDENCY)
			add_dependency (&dependency_list,dependent_module);
		else if (dependency_type==OBJECT_FILE_DEPENDENCY)
			add_imported_object_file_to_project_node (dependent_module,project_node
#ifdef _WINDOWS_
					,0
#endif
					);
		else if (dependency_type==LIBRARY_DEPENDENCY){
#ifdef _WINDOWS_
			if (!(dependent_module[0]=='-' && dependent_module[1]=='l'))
				add_imported_object_file_to_project_node (dependent_module,project_node,1);
#else
			if (dependent_module[0]=='-' && dependent_module[1]=='l')
				add_library (dependent_module);
			else if (strchr (dependent_module,'.')!=NULL)
				add_imported_object_file_to_project_node (dependent_module,project_node);
#endif
		}
	} while (dependency_type!=NO_DEPENDENCY);

	close_abc_file();

	project_node->pro_depend=dependency_list;
}

static int make_project_to_abc_files (P_NODE project_node)
{
	DEP_LIST dependency;
	
	if (project_node->pro_up_to_date)
		return 1;
	
	project_node->pro_up_to_date=1;
	
	if (!project_node->pro_ignore_o && !project_node_is_abc_up_to_date (project_node)){
		if (is_system_file (project_node))
			return 0;
		if (!compile_project_node (project_node))
			return 0;
		if (!single_module)
			get_dependencies (project_node);
	}
	
	if (!single_module)
		for_l (dependency,project_node->pro_depend,dep_next)
			if (!make_project_to_abc_files (dependency->dep_node))
				return 0;
	
	return 1;
}

static int project_node_is_o_up_to_date (P_NODE project_node)
{
	FileTime abc_time,o_time;

	if (!get_clean_system_time (project_node,OBJECT_FILE_EXTENSION,&o_time
				   ,clean_o_path!=NULL ? clean_o_path : clean_abc_path
		))
	{
		if (verbose)
			warning_s ("(%s.o doesn't exist)",project_node->pro_fname);
		return 0;
	}
	
	if (get_abc_time (project_node,&abc_time) && FILE_TIME_LE (o_time,abc_time)){
		if (verbose)
			warning_s ("(%s.o is older than corresponding abc file)",
					   project_node->pro_fname);
		return 0;
	}
	
	if (verbose)
		warning_s ("(%s.o is up to date)",project_node->pro_fname);
	
	return 1;
}

static int make_project_to_o_files (void)
{
	P_NODE project_node;
	
	for_l (project_node,first_project_node,pro_next){
		if (project_node->pro_up_to_date && !project_node->pro_ignore_o && !project_node_is_o_up_to_date (project_node)){
#ifdef QUOTE_SPAWN_ARGUMENTS
			char file_name_s[PATH_NAME_STRING_SIZE],*file_name;

			file_name_s[0]='\"';
			file_name=&file_name_s[1];
#else
			char file_name[PATH_NAME_STRING_SIZE];
#endif
			
#ifdef _WINDOWS_
			{
			FileTime time;

			if (!find_clean_system_file (project_node->pro_fname,".abc",file_name,clean_abc_path,&time))
				error_s ("Can't find %s.abc",project_node->pro_fname);
			}
#else
			if (!find_clean_system_file (project_node->pro_fname,".abc",file_name,clean_abc_path))
				error_s ("Can't find %s.abc",project_node->pro_fname);
#endif
			
			file_name[strlen (file_name)-4]='\0';

#ifdef QUOTE_SPAWN_ARGUMENTS
			strcat (file_name,"\"");
			file_name = file_name_s;
#endif

			if (!generate_code_for_project_node (project_node,file_name))
				return 0;
#if !defined (NO_ASSEMBLE)
			if (!assemble (project_node,file_name))
				return 0;

			strcat (file_name,".s");
			unlink (file_name);
#endif
		}
	}
	return 1;
}

static int project_node_is_s_up_to_date (P_NODE project_node)
{
	FileTime abc_time,s_time;
	
	if (!get_clean_system_time (project_node,".s",&s_time
					,clean_abc_path
	)){
		if (verbose)
			warning_s ("(%s.s doesn't exist)",project_node->pro_fname);
		return 0;
	}
	
	if (get_abc_time (project_node,&abc_time) && FILE_TIME_LE (s_time,abc_time)){
		if (verbose)
			warning_s ("(%s.s is older than corresponding abc file)",
					   project_node->pro_fname);
		return 0;
	}
	
	if (verbose)
		warning_s ("(%s.s is up to date)",project_node->pro_fname);
	return 1;
}

static int make_project_to_s_files (void)
{
	P_NODE project_node;
	
	for_l (project_node,first_project_node,pro_next){
		if (project_node->pro_up_to_date && !project_node_is_s_up_to_date (project_node)){
			char file_name[PATH_NAME_STRING_SIZE];

#ifdef _WINDOWS_
			{
			FileTime time;
			if (!find_clean_system_file (project_node->pro_fname,".abc",file_name,clean_abc_path,&time))
				error_s ("Can't find %s.abc",project_node->pro_fname);
			}
#else
			if (!find_clean_system_file (project_node->pro_fname,".abc",file_name,clean_abc_path))
				error_s ("Can't find %s.abc",project_node->pro_fname);
#endif
			
			file_name[strlen (file_name)-4]='\0';
			
			if (!generate_code_for_project_node (project_node,file_name))
				return 0;
		}
	}
	return 1;
}

#ifdef _WINDOWS_
# define int_to_2_chars(i) (char)(i),(char)((i)>>8)
# define int_to_4_chars(i) (char)(i),(char)((i)>>8),(char)((i)>>16),(char)((i)>>24)
#endif

#ifdef _WINDOWS_
char
#else
int
#endif
data [] =
{
#ifdef I486
# ifdef _WINDOWS_
	/* header offset 0 */
#  ifdef A_64
	int_to_2_chars (0x8664)/*machine_type*/,
#  else
	int_to_2_chars (0x14c)/*machine_type*/,
#  endif
	int_to_2_chars (3)/*n_sections*/,	
	int_to_4_chars (817729185)/*time_date_stamp*/,
#  ifdef A_64
	int_to_4_chars (188)/*symbol_table_pointer*/,
#  else
	int_to_4_chars (164)/*symbol_table_pointer*/,
#  endif
	int_to_4_chars (14)/*n_symbols*/,
	int_to_2_chars (0)/*optional_header_size*/,
	int_to_2_chars (0x0104)/*characteristics*/,
	/* text section header offset 20 */
	'.','t','e','x','t','\0','\0','\0',
	int_to_4_chars (0)/*text_virtual_size*/,
	int_to_4_chars (0)/*text_rva_offset*/,
	int_to_4_chars (0)/*text_raw_data_size*/,
	int_to_4_chars (0)/*text_raw_data_pointer*/,
	int_to_4_chars (0)/*text_relocs_pointerm*/,
	int_to_4_chars (0)/*text_linenumbers_pointer*/,
	int_to_2_chars (0)/*text_n_relocs*/,
	int_to_2_chars (0)/*text_n_linenumbers*/,
	int_to_4_chars (0x60000020)/*text_section_flags*/,
	/* data section header offset 60 */
	'.','d','a','t','a','\0','\0','\0',
	int_to_4_chars (0)/*data_virtual_size*/,
	int_to_4_chars (0)/*data_rva_offset*/,
	int_to_4_chars (24)/*data_raw_data_size*/,
	int_to_4_chars (140)/*data_raw_data_pointer*/,
	int_to_4_chars (0)/*data_relocs_pointer*/,
	int_to_4_chars (0)/*data_linenumbers_pointer*/,
	int_to_2_chars (0)/*data_n_relocs*/,
	int_to_2_chars (0)/*data_n_linenumbers*/,
	int_to_4_chars (0xc0000040)/*data_section_flags*/,
	/* bss section header offset 100 */
	'.','b','s','s','\0','\0','\0','\0',
	int_to_4_chars (0)/*bss_virtual_size*/,
	int_to_4_chars (20)/*bss_rva_offset*/,
	int_to_4_chars (0)/*bss_raw_data_size*/,
	int_to_4_chars (0)/*bss_raw_data_pointer*/,
	int_to_4_chars (0)/*bss_relocs_pointer*/,
	int_to_4_chars (0)/*bss_linenumbers_pointer*/,
	int_to_2_chars (0)/*bss_n_relocs*/,
	int_to_2_chars (0)/*bss_n_linenumbers*/,
	int_to_4_chars (0xc0000080)/*bss_section_flags*/,		
	/* data section offset 140 */
	int_to_4_chars (0)/*heap_size*/,
#  ifdef A_64
	int_to_4_chars (0),
#  endif
	int_to_4_chars (0)/*stack_size*/,
#  ifdef A_64
	int_to_4_chars (0),
#  endif
	int_to_4_chars (0)/*flags*/,
#  ifdef A_64
	int_to_4_chars (0),
#  endif
	int_to_4_chars (0)/*initial_heap_size*/,
#  ifdef A_64
	int_to_4_chars (0),
#  endif
	int_to_4_chars (0)/*heap_size_multiple*/,
#  ifdef A_64
	int_to_4_chars (0),
#  endif
	int_to_4_chars (0)/*min_write_heap_size*/,
#  ifdef A_64
	int_to_4_chars (0),
#  endif
	/* symbol table offset */
	/* .file at 164 / 188 */
	'.','f','i','l', 'e','\0','\0','\0',
	int_to_4_chars (0)/*file_value*/,
	int_to_2_chars (65534)/*file_section_n(IMAGE_SYM_DEBUG)*/,
	int_to_2_chars (0)/*file_type*/,
	(char) 103/*file_storage_class(IMAGE_SYM_CLASS_FILE)*/,
	(char) 1/*file_n_aux_sections*/,
	/* fake (aux to .file) at 182 / 206  */
	'f','a','k','e','\0','\0','\0','\0',
	int_to_4_chars (0)/*file_aux_value*/,
	int_to_2_chars (0)/*file_aux_section_n(IMAGE_SYM_UNDEFINED)*/,
	int_to_2_chars (0)/*file_aux_type*/,
	(char) 0/*file_aux_storage_class(IMAGE_SYM_CLASS_NULL)*/,
	(char) 0 /*file_aux_n_aux_sections*/,
	/* .text at 200 / 224 */
	'.','t','e','x','t','\0','\0','\0',
	int_to_4_chars (0)/*text_value*/,
	int_to_2_chars (1)/*text_section_n*/,
	int_to_2_chars (0)/*text_type*/,
	(char) 3/*text_storage_class(IMAGE_SYM_CLASS_STATIC)*/,
	(char) 1/*text_n_aux_sections*/,
	/* null to .text at 214 / 238 */
	int_to_4_chars (0)/*text_raw_data_size*/,
	'\0','\0','\0','\0','\0','\0','\0','\0','\0','\0','\0','\0','\0','\0'/*null_aux_entry*/,
	/* .data at 236 / 260 */
	'.','d','a','t','a','\0','\0','\0',
	int_to_4_chars (0)/*data_value*/,
	int_to_2_chars (2)/*data_section_n*/,
	int_to_2_chars (0)/*data_type*/,
	(char) 3/*data_storage_class(IMAGE_SYM_CLASS_STATIC)*/,
	(char) 1/*data_n_aux_sections*/,
	/* null to .data at 254 / 278 */
#  ifdef A_64
	int_to_4_chars (48)/*data_raw_data_size*/,
#  else
	int_to_4_chars (24)/*data_raw_data_size*/,
#  endif
	'\0','\0','\0','\0','\0','\0','\0','\0','\0','\0','\0','\0','\0','\0'/*null_aux_entry*/,
	/* .bss at 272 / 296 */
	'.','b','s','s','\0','\0','\0','\0',
	int_to_4_chars (20)/*bss_value*/,
	int_to_2_chars (3)/*bss_section_n*/,
	int_to_2_chars (0)/*bss_type*/,
	(char) 3/*bss_storage_class(IMAGE_SYM_CLASS_STATIC)*/,
	(char) 1/*bss_n_aux_sections*/,
	/* null to .bss at 290 / 314 */
	int_to_4_chars (0)/*bss_raw_data_size*/,
	'\0','\0','\0','\0','\0','\0','\0','\0','\0','\0','\0','\0','\0','\0'/*null_aux_entry*/,

	/* _heap_size at 306 / 330 */
	int_to_4_chars (0), int_to_4_chars (4)/*heap_size_offset*/,
	int_to_4_chars (0)/*heap_size_value*/,
	int_to_2_chars (2)/*heap_size_section_n*/,		
	int_to_2_chars (0)/*heap_size_type*/,
	(char) 2/*heap_size_class(IMAGE_SYM_CLASS_EXTERNAL)*/,
	(char) 0/*heap_size_n_aux_sections*/,

	/* _ab_stack_size at 326 / 360 */
	int_to_4_chars (0),
#  ifdef A_64
	int_to_4_chars (14)/*ab_stack_size_offset*/,
	int_to_4_chars (8)/*ab_stack_size_value*/,
#  else
	int_to_4_chars (15)/*ab_stack_size_offset*/,
	int_to_4_chars (4)/*ab_stack_size_value*/,
#  endif
	int_to_2_chars (2)/*ab_stack_size_section_n*/,
	int_to_2_chars (0)/*ab_stack_size_type*/,
	(char) 2/*ab_stack_size_class(IMAGE_SYM_CLASS_EXTERNAL)*/,
	(char) 0/*ab_stack_size_n_aux_sections*/,

	/* _flags at 344 / 368 */
#  ifndef A_64
	'_',
#  endif
	'f','l','a','g','s','\0','\0',
#  ifdef A_64
	'\0',
#  endif
#  ifdef A_64
	int_to_4_chars (16)/*flags_value*/,
#  else
	int_to_4_chars (8)/*flags_value*/,
#  endif
	int_to_2_chars (2)/*flags_section_n*/,
	int_to_2_chars (0)/*flags_type*/,
	(char) 2/*flags_class(IMAGE_SYM_CLASS_EXTERNAL)*/,
	(char) 0/*flags_n_aux_sections*/,

	/* _initial_heap_size at 362 / 386 */
	int_to_4_chars (0),
#  ifdef A_64
	int_to_4_chars (28)/*initial_heap_size_offset*/,
	int_to_4_chars (24)/*initial_heap_size_value*/,
#  else
	int_to_4_chars (30)/*initial_heap_size_offset*/,
	int_to_4_chars (12)/*initial_heap_size_value*/,
#  endif
	int_to_2_chars (2)/*initial_heap_size_section_n*/,
	int_to_2_chars (0)/*initial_heap_size_type*/,
	(char) 2/*initial_heap_size_class(IMAGE_SYM_CLASS_EXTERNAL)*/,
	(char) 0/*initial_heap_size_n_aux_sections*/,

	/* _heap_size_multiple at 378 / 402 */
	int_to_4_chars (0),
#  ifdef A_64
	int_to_4_chars (46)/*heap_size_multiple_offset*/,
	int_to_4_chars (32)/*heap_size_multiple_value*/,
#  else
	int_to_4_chars (49)/*heap_size_multiple_offset*/,
	int_to_4_chars (16)/*heap_size_multiple_value*/,
#  endif
	int_to_2_chars (2)/*heap_size_multiple_section_n*/,
	int_to_2_chars (0)/*heap_size_multiple_type*/,
	(char) 2/*heap_size_multiple_class(IMAGE_SYM_CLASS_EXTERNAL)*/,
	(char) 0/*heap_size_multiple_n_aux_sections*/,

	/* _min_write_heap_size at 396 / 420 */
	int_to_4_chars (0),
#  ifdef A_64
	int_to_4_chars(65)/*min_write_heap_size_offset*/,
	int_to_4_chars (40)/*min_write_heap_size_value*/,
#  else
	int_to_4_chars(69)/*min_write_heap_size_offset*/,
	int_to_4_chars (20)/*min_write_heap_size_value*/,
#  endif
	int_to_2_chars (2)/*min_write_heap_size_section_n*/,
	int_to_2_chars (0)/*min_write_heap_size_type*/,
	(char) 2/*min_write_heap_size_class(IMAGE_SYM_CLASS_EXTERNAL)*/,
	(char) 0/*min_write_heap_size_n_aux_sections*/,

	/* string table at 414 / 438 */
#  ifdef A_64
	int_to_4_chars (81/*size string_table*/ + 4),
#  else
	int_to_4_chars (86/*size string_table*/ + 4),
	'_',
#  endif
	'h','e','a','p','_','s','i','z','e','\0',
#  ifndef A_64
	'_',
#  endif
	'a','b','_','s','t','a','c','k','_','s','i','z','e','\0',
#  ifndef A_64
	'_',
#  endif
	'i','n','i','t','i','a','l','_','h','e','a','p','_','s','i','z','e','\0',
#  ifndef A_64
	'_',
#  endif
	'h','e','a','p','_','s','i','z','e','_','m','u','l','t','i','p','l','e','\0',
#  ifndef A_64
	'_',
#  endif
	'm','i','n','_','w','r','i','t','e','_','h','e','a','p','_','s','i','z','e','\0'
# else
#  ifdef OMF
	 0x0b000d80,0x6974706f,0x2e736e6f,0xf36a626f
	,0x80000688,0x4c4803a1,0x005096ba,0x45540600
	,0x32335458,0x54414406,0x05323341,0x33535342
	,0x24240932,0x424d5953,0x07534c4f,0x59542424
	,0x04534550,0x45444f43,0x54414404,0x53420341
	,0x45440653,0x4d595342,0x42454406,0x04505954
	,0x54414c46,0x52474406,0x7350554f,0xa9000798
	,0x07020000,0x0798ae01,0x000ca900,0xa0010803
	,0xa9000798,0x09040000,0x0798aa01,0x0017a900
	,0x91010a05,0xa9000798,0x0b060000,0x029aa601
	,0x9a580c00,0xff0d0006,0x5002ff03,0x01002a90
	,0x65680902,0x735f7061,0x00657a69,0x610d0000
	,0x74735f62,0x5f6b6361,0x657a6973,0x05000004
	,0x67616c66,0x00000873,0x00048805,0x9101a240
	,0x020010a0,0x00010000,0x00020000,0x00030000
	,0xa0480000,0x00040015,0x01401000,0x20202004
	,0x35100020,0x01170017,0xa02b07cc,0x1104000a
	,0x00110500,0x2b000000,0x4400089d,0xc8011001
	,0x95af8c02,0x01000027,0x00000000,0x00000000
	,0x00000018,0x00000000,0x00000000,0x00000001
	,0x74706f0b,0x736e6f69,0x6a626f2e,0x00028baa
	,0x00007300
#  else
#	ifdef LINUX_ELF
#    ifdef A_64
	0x464c457f,0x00010102,0x00000000,0x00000000,
	0x003e0001,0x00000001,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000094,0x00000000,
	0x00000000,0x00000040,0x00400000,0x00040007,
	
	0x00000001,0x00000000,0x00000004,0x00000000,
	0x00000005,0x00000000,0x00000002,0x00000000,
	0x00000003,0x00000000,
						  0x79732e00,0x6261746d,
	0x74732e00,0x62617472,0x68732e00,0x74727473,
	0x2e006261,0x74786574,0x61642e00,0x2e006174,
	0x00737362,
			   0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000000,
			   0x0000001b,0x00000001,0x00000006,
	0x00000000,0x00000000,0x00000000,0x00000040,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000004,0x00000000,0x00000000,
	0x00000000,
			   0x00000021,0x00000001,0x00000003,
	0x00000000,0x00000000,0x00000000,0x00000040,
	0x00000000,0x00000028,0x00000000,0x00000000,
	0x00000000,0x00000008,0x00000000,0x00000000,
	0x00000000,
			   0x00000027,0x00000008,0x00000003,
	0x00000000,0x00000000,0x00000000,0x00000068,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000004,0x00000000,0x00000000,
	0x00000000,
			   0x00000011,0x00000003,0x00000000,
	0x00000000,0x00000000,0x00000000,0x00000068,
	0x00000000,0x0000002c,0x00000000,0x00000000,
	0x00000000,0x00000001,0x00000000,0x00000000,
	0x00000000,
			   0x00000001,0x00000002,0x00000000,
	0x00000000,0x00000000,0x00000000,0x00000254,
	0x00000000,0x000000d8,0x00000000,0x00000006,
	0x00000004,0x00000004,0x00000000,0x00000018,
	0x00000000,
			   0x00000009,0x00000003,0x00000000,
	0x00000000,0x00000000,0x00000000,0x0000032c,
	0x00000000,0x00000044,0x00000000,0x00000000,
	0x00000000,0x00000001,0x00000000,0x00000000,
	0x00000000,
			   0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000000,
									 0x00000000,
	0x00010003,0x00000000,0x00000000,0x00000000,
	0x00000000,
	           0x00000000,0x00020003,0x00000000,
	0x00000000,0x00000000,0x00000000,
		 	 				         0x00000000,
	0x00030003,0x00000000,0x00000000,0x00000000,
	0x00000000,
	           0x00000001,0x00020011,0x00000000,
	0x00000000,0x00000000,0x00000000,
									 0x0000000b,
	0x00020011,0x00000008,0x00000000,0x00000000,
	0x00000000,
	           0x00000019,0x00020011,0x00000010,
	0x00000000,0x00000000,0x00000000,
						     		 0x0000001f,
	0x00020011,0x00000018,0x00000000,0x00000000,
	0x00000000,
	           0x00000032,0x00020011,0x00000020,
	0x00000000,0x00000000,0x00000000,
									 0x61656800,
	0x69735f70,0x6100657a,0x74735f62,0x5f6b6361,
	0x657a6973,0x616c6600,0x68007367,0x5f706165,
	0x657a6973,0x6c756d5f,0x6c706974,0x6e690065,
	0x61697469,0x65685f6c,0x735f7061,0x00657a69
#    else
	0x464c457f,0x00010101,0x00000000,0x00000000,
#     ifdef ARM
	0x00280001,
#     else
	0x00030001,
#     endif
	           0x00000001,0x00000000,0x00000000,
	0x00000074,
#     ifdef ARM
	           0x05000000,
#     else
	           0x00000000,
#     endif
	                      0x00000034,0x00280000,
	0x00040007,0x00000001,0x00000004,0x00000005,
	0x00000002,0x00000003,0x79732e00,0x6261746d,
	0x74732e00,0x62617472,0x68732e00,0x74727473,
	0x2e006261,0x74786574,0x61642e00,0x2e006174,
	0x00737362,0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000000,0x0000001b,
	0x00000001,0x00000006,0x00000000,0x00000034,
	0x00000000,0x00000000,0x00000000,0x00000004,
	0x00000000,0x00000021,0x00000001,0x00000003,
	0x00000000,0x00000034,0x00000014,0x00000000,
	0x00000000,0x00000004,0x00000000,0x00000027,
	0x00000008,0x00000003,0x00000000,0x00000048,
	0x00000000,0x00000000,0x00000000,0x00000004,
	0x00000000,0x00000011,0x00000003,0x00000000,
	0x00000000,0x00000048,0x0000002c,0x00000000,
	0x00000000,0x00000001,0x00000000,0x00000001,
	0x00000002,0x00000000,0x00000000,0x0000018c,
	0x00000090,0x00000006,0x00000004,0x00000004,
	0x00000010,0x00000009,0x00000003,0x00000000,
	0x00000000,0x0000021c,0x00000044,0x00000000,
	0x00000000,0x00000001,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00010003,0x00000000,
	0x00000000,0x00000000,0x00020003,0x00000000,
	0x00000000,0x00000000,0x00030003,0x00000001,
#     if 0
	0x00000000,0x00000000,0x00020011,0x0000000b,
	0x00000004,0x00000000,0x00020011,0x00000019,
	0x00000008,0x00000000,0x00020011,0x0000001f,
	0x0000000c,0x00000000,0x00020011,0x00000032,
	0x00000010,0x00000000,0x00020011,0x61656800,
#     else
	/* st_other = STV_HIDDEN */
	0x00000000,0x00000000,0x00020211,0x0000000b,
	0x00000004,0x00000000,0x00020211,0x00000019,
	0x00000008,0x00000000,0x00020211,0x0000001f,
	0x0000000c,0x00000000,0x00020211,0x00000032,
	0x00000010,0x00000000,0x00020211,0x61656800,
#     endif
	0x69735f70,0x6100657a,0x74735f62,0x5f6b6361,
	0x657a6973,0x616c6600,0x68007367,0x5f706165,
	0x657a6973,0x6c756d5f,0x6c706974,0x6e690065,
	0x61697469,0x65685f6c,0x735f7061,0x00657a69
#    endif
#   else
#    ifdef MACH_O64
	0xfeedfacf,0x01000007,0x00000003,0x00000001,
	0x00000003,0x00000150,0x00000000,0x00000000,
	0x00000019,0x000000e8,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000028,0x00000000,0x00000170,0x00000000,
	0x00000028,0x00000000,0x00000007,0x00000007,
	0x00000002,0x00000000,0x65745f5f,0x00007478,
	0x00000000,0x00000000,0x45545f5f,0x00005458,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000170,0x00000000,
	0x00000000,0x00000000,0x80000000,0x00000000,
	0x00000000,0x00000000,0x61645f5f,0x00006174,
	0x00000000,0x00000000,0x41445f5f,0x00004154,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000028,0x00000000,0x00000170,0x00000000,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000002,0x00000018,
	0x00000198,0x00000005,0x000001e8,0x0000004c,
	0x0000000b,0x00000050,0x00000000,0x00000000,
	0x00000000,0x00000005,0x00000005,0x00000000,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000001,0x00000000,0x00000002,0x00000000,
	0x00000003,0x00000000,0x00000004,0x00000000,
	0x00000005,0x00000000,0x00000026,0x0000020f,
	0x00000018,0x00000000,0x00000001,0x0000020f,
	0x00000000,0x00000000,0x0000001b,0x0000020f,
	0x00000010,0x00000000,0x00000035,0x0000020f,
	0x00000020,0x00000000,0x00000008,0x0000020f,
	0x00000008,0x00000000,0x6c665f00,0x00736761,
	0x696e695f,0x6c616974,0x6165685f,0x69735f70,
	0x5f00657a,0x70616568,0x7a69735f,0x615f0065,
	0x74735f62,0x5f6b6361,0x657a6973,0x65685f00,
	0x735f7061,0x5f657a69,0x746c756d,0x656c7069,
	0x00000000
#    else
	0x00640107,0x00000000,0x0000000c,0x00000000,
	0x00000024,0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000000,0x00000004,
	0x00000007,0x00000000,0x0000000f,0x00000007,
	0x00000004,0x0000001e,0x00000007,0x00000008,
	0x00000025,0x6165685f,0x69735f70,0x5f00657a,
	0x735f6261,0x6b636174,0x7a69735f,0x665f0065,
	0x7367616c,0x00000000
#    endif
#   endif
#  endif
# endif
#else
# ifdef LINUX
#  if defined (LINUX_ELF) && defined (ARM) && defined (A_64)
	0x464c457f,0x00010102,0x00000000,0x00000000,
	0x00b70001,0x00000001,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000094,0x00000000,
	0x00000000,0x00000040,0x00400000,0x00040007,
	
	0x00000001,0x00000000,0x00000004,0x00000000,
	0x00000005,0x00000000,0x00000002,0x00000000,
	0x00000003,0x00000000,
						  0x79732e00,0x6261746d,
	0x74732e00,0x62617472,0x68732e00,0x74727473,
	0x2e006261,0x74786574,0x61642e00,0x2e006174,
	0x00737362,
			   0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000000,
			   0x0000001b,0x00000001,0x00000006,
	0x00000000,0x00000000,0x00000000,0x00000040,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000004,0x00000000,0x00000000,
	0x00000000,
			   0x00000021,0x00000001,0x00000003,
	0x00000000,0x00000000,0x00000000,0x00000040,
	0x00000000,0x00000028,0x00000000,0x00000000,
	0x00000000,0x00000008,0x00000000,0x00000000,
	0x00000000,
			   0x00000027,0x00000008,0x00000003,
	0x00000000,0x00000000,0x00000000,0x00000068,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000004,0x00000000,0x00000000,
	0x00000000,
			   0x00000011,0x00000003,0x00000000,
	0x00000000,0x00000000,0x00000000,0x00000068,
	0x00000000,0x0000002c,0x00000000,0x00000000,
	0x00000000,0x00000001,0x00000000,0x00000000,
	0x00000000,
			   0x00000001,0x00000002,0x00000000,
	0x00000000,0x00000000,0x00000000,0x00000254,
	0x00000000,0x000000d8,0x00000000,0x00000006,
	0x00000004,0x00000004,0x00000000,0x00000018,
	0x00000000,
			   0x00000009,0x00000003,0x00000000,
	0x00000000,0x00000000,0x00000000,0x0000032c,
	0x00000000,0x00000044,0x00000000,0x00000000,
	0x00000000,0x00000001,0x00000000,0x00000000,
	0x00000000,
			   0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000000,
									 0x00000000,
	0x00010003,0x00000000,0x00000000,0x00000000,
	0x00000000,
	           0x00000000,0x00020003,0x00000000,
	0x00000000,0x00000000,0x00000000,
		 	 				         0x00000000,
	0x00030003,0x00000000,0x00000000,0x00000000,
	0x00000000,
	           0x00000001,0x00020011,0x00000000,
	0x00000000,0x00000000,0x00000000,
									 0x0000000b,
	0x00020011,0x00000008,0x00000000,0x00000000,
	0x00000000,
	           0x00000019,0x00020011,0x00000010,
	0x00000000,0x00000000,0x00000000,
						     		 0x0000001f,
	0x00020011,0x00000018,0x00000000,0x00000000,
	0x00000000,
	           0x00000032,0x00020011,0x00000020,
	0x00000000,0x00000000,0x00000000,
									 0x61656800,
	0x69735f70,0x6100657a,0x74735f62,0x5f6b6361,
	0x657a6973,0x616c6600,0x68007367,0x5f706165,
	0x657a6973,0x6c756d5f,0x6c706974,0x6e690065,
	0x61697469,0x65685f6c,0x735f7061,0x00657a69
#  else
	0x7f454c46,0x01020100,0x00000000,0x00000000,
	0x00010014,0x00000001,0x00000000,0x00000000,
	0x00000074,0x00000000,0x00340000,0x00000028,
	0x00070004,0x00000008,0x00200000,0x00080000,
	0x00001400,0x00019000,0x002e7379,0x6d746162,
	0x002e7374,0x72746162,0x002e7368,0x73747274,
	0x6162002e,0x74657874,0x002e6461,0x7461002e,
	0x62737300,0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000000,0x0000001b,
	0x00000001,0x00000006,0x00000000,0x00000034,
	0x00000000,0x00000000,0x00000000,0x00000001,
	0x00000000,0x00000021,0x00000001,0x00000003,
	0x00000000,0x00000034,0x00000014,0x00000000,
	0x00000000,0x00000001,0x00000000,0x00000027,
	0x00000008,0x00000003,0x00000000,0x00000048,
	0x00000000,0x00000000,0x00000000,0x00000001,
	0x00000000,0x00000011,0x00000003,0x00000000,
	0x00000000,0x00000048,0x0000002c,0x00000000,
	0x00000000,0x00000001,0x00000000,0x00000001,
	0x00000002,0x00000000,0x00000000,0x0000018c,
	0x00000090,0x00000006,0x00000004,0x00000004,
	0x00000010,0x00000009,0x00000003,0x00000000,
	0x00000000,0x0000021c,0x00000041,0x00000000,
	0x00000000,0x00000001,0x00000000,0x00000000,
	0x00000000,0x00000000,0x00000000,0x00000000,
	0x00000000,0x00000000,0x03000001,0x00000000,
	0x00000000,0x00000000,0x03000002,0x00000000,
	0x00000000,0x00000000,0x03000003,0x00000001,
	0x00000000,0x00000000,0x11000002,0x00000007,
	0x00000004,0x00000000,0x11000002,0x00000011,
	0x00000008,0x00000000,0x11000002,0x0000001c,
	0x0000000c,0x00000000,0x11000002,0x0000002f,
	0x00000010,0x00000000,0x11000002,0x00666c61,
	0x67730068,0x6561705f,0x73697a65,0x00737461,
	0x636b5f73,0x697a6500,0x68656170,0x5f73697a,
	0x655f6d75,0x6c746970,0x6c650069,0x6e697469,
	0x616c5f68,0x6561705f,0x73697a65,0x00
#  endif
# else
	0x01030107,0x00000000,0x00000010,0x00000000,
	0x0000003c,0x00000000,0x00000000,0x00000000,
	0x00200000,0x00080000,0x00080000,0x00000008,
	0x00000004,0x07000000,0x00000008,0x00000012,
	0x07000000,0x0000000c,0x00000019,0x07000000,
	0x00000004,0x00000028,0x07000000,0x00000000,
	0x00000033,0x07000000,0x00000010,0x0000003c,
	0x5f635f73,0x7461636b,0x5f73697a,0x65005f66,
	0x6c616773,0x005f6162,0x5f737461,0x636b5f73,
	0x697a6500,0x5f686561,0x705f7369,0x7a650064,
	0x6174615f,0x656e6400
# endif
#endif
};

#define COMMENT_CHAR '#'

static char *parse_word (char **line_h)
{
    char *begin,*end;
	int c;

    begin=*line_h;
	while ((c = (*begin=='\\' && *(begin+1)!='\0') ? * ++begin : *begin),isspace (c))
		++begin;

    if (*begin==COMMENT_CHAR || *begin=='\0')
        return NULL;

    for (end=begin; !isspace ((int) *end) && *end!='\0'; ++end)
        if (*end=='\\' && *(end+1)!='\0')
            ++end;

    if (*end=='\0')
        *line_h = end;
    else {
        *line_h = end+1;
        *end = '\0';
    }

    return begin;
}

long ab_stack_size,heap_size,flags;
long heap_size_multiple=20<<8,initial_heap_size=100<<10;

int create_options_file (char **options_file_name_p)
{
	char *options_file_name;
	FILE *f;
	unsigned int data_size;

#if defined (_WINDOWS_)
	options_file_name="cgopt.$$$";

# ifdef OMF
	{
		char *p;
		
		for (p=options_file_name; *p; ++p)
			if (*p=='/')
				*p='\\';
	}
# endif

	f=fopen (options_file_name,"wb");
#else
	{
	static char cgopt_file_name[]="/tmp/cgoptXXXXXX";
	int options_fd;

	options_fd=mkstemp (cgopt_file_name);
	if (options_fd<0)
		return 0;

	options_file_name=cgopt_file_name;
	
	f=fdopen (options_fd,"wb");
	}
#endif
	if (f==NULL)
		error_s ("Can't create options file %s",options_file_name);

#if defined (LINUX_ELF)
# ifdef A_64
	data[16]=heap_size;
	data[18]=ab_stack_size;
	data[20]=flags;
	data[22]=heap_size_multiple;
	data[24]=initial_heap_size;
# else
	data[13]=heap_size;
	data[14]=ab_stack_size;
	data[15]=flags;
	data[16]=heap_size_multiple;
	data[17]=initial_heap_size;
# endif
	data_size=sizeof (data);
#elif defined (LINUX) && defined (POWERPC)
	data[13]=flags;
	data[14]=heap_size;
	data[15]=ab_stack_size;
	data[16]=heap_size_multiple;
	data[17]=initial_heap_size;
	data_size=sizeof (data);
#else
# ifdef _WINDOWS_
#  ifdef A_64
	((size_t*)&data[140])[0]=heap_size;
	((size_t*)&data[140])[1]=ab_stack_size;
	((size_t*)&data[140])[2]=flags;
	((size_t*)&data[140])[3]=initial_heap_size;
	((size_t*)&data[140])[4]=heap_size_multiple;
	((size_t*)&data[140])[5]=0/*min_write_heap_size*/;
#  else
	((int*)&data[140])[0]=heap_size;
	((int*)&data[140])[1]=ab_stack_size;
	((int*)&data[140])[2]=flags;
	((int*)&data[140])[3]=initial_heap_size;
	((int*)&data[140])[4]=heap_size_multiple;
	((int*)&data[140])[5]=0/*min_write_heap_size*/;
#  endif
	data_size=sizeof (data);
# else
#  ifdef MACH_O64
	data[92]=flags;
	data[94]=initial_heap_size;
	data[96]=heap_size;
	data[98]=ab_stack_size;
	data[100]=heap_size_multiple;
	data_size=sizeof (data);
#  else
#   ifdef OMF
	*(long*)((char*)data+230)=heap_size;
	*(long*)((char*)data+234)=ab_stack_size;
	*(long*)((char*)data+238)=flags;
	data_size=sizeof (data)-2;
#   else
	data[8]=heap_size;
	data[9]=ab_stack_size;
#    ifdef I486
	data[10]=flags;
	data_size=sizeof (data)-3;
#    else
	data[10]=512<<10;
	data[11]=flags;
	data_size=sizeof (data);
#    endif
#   endif
#  endif
# endif
#endif
	
	if (fwrite (data,1,data_size,f)!=data_size){
		fclose (f);
		unlink (options_file_name);
		error ("Error writing options file");
	}
	
	if (fclose (f)!=0){
		unlink (options_file_name);
		error ("Error writing options file");
	}
	
	*options_file_name_p=options_file_name;
	return 1;
}

#ifdef OPTIMISE_LINK
static char *linker_output_object_file_name;
static int no_optimise_link;
#endif

static int stack_trace;

static char **add_imported_object_files (P_NODE first_project_node,char *o_file_name,char **arg)
{
	P_NODE project_node;

	for_l (project_node,first_project_node,pro_next){
		struct object_file_list *imported_object_file;
		char *file_name;

		for_l (imported_object_file,project_node->pro_imported_object_files,object_file_next){
#ifdef _WINDOWS_
			FileTime time;
#endif

			/* use "Clean System Files/" as file name and the object file name as extension: */
			if (!find_file (
#ifndef NO_CLEAN_SYSTEM_FILES
					"Clean System Files" DIRECTORY_SEPARATOR_STRING
#else
					""
#endif
					,imported_object_file->object_file_name, o_file_name,clean_o_path!=NULL ? clean_o_path : clean_abc_path
#ifdef _WINDOWS_
				,&time
#endif
			))
			{
				/* can't find in root, search hierarchically */
				char prefix[PATH_NAME_STRING_SIZE] = {'\0'};
				int i;
				for(i = strlen(project_node->pro_fname)-1; i>=0; i--){
					if(project_node->pro_fname[i] == '.') {
						strncpy(prefix, project_node->pro_fname, i);
						prefix[i] = '\0';
						strcat(prefix, DIRECTORY_SEPARATOR_STRING);
						break;
					}
				}
#ifndef NO_CLEAN_SYSTEM_FILES
				strcat(prefix, "Clean System Files" DIRECTORY_SEPARATOR_STRING);
#endif
				if (!find_file(prefix, imported_object_file->object_file_name, o_file_name, clean_o_path!=NULL ? clean_o_path : clean_abc_path
#ifdef _WINDOWS_
					, &time
#endif
				)){
					error_s_s ("Can't find object file %s imported from %s",
						   imported_object_file->object_file_name,project_node->pro_fname);
				}
			}

#ifdef QUOTE_SPAWN_ARGUMENTS
			file_name=memory_allocate (strlen (o_file_name)+3+(imported_object_file->object_file_is_library ? 2 : 0));

			file_name[0]='\"';
			if (imported_object_file->object_file_is_library){
				file_name[1]='-';
				file_name[2]='l';
				strcpy (file_name+3,o_file_name);
				strcat (file_name+3,"\"");
			} else {
				strcpy (file_name+1,o_file_name);
				strcat (file_name+1,"\"");
			}
#else
# ifdef _WINDOWS_
			file_name=memory_allocate (strlen (o_file_name)+1+(imported_object_file->object_file_is_library ? 2 : 0));

			if (imported_object_file->object_file_is_library){
				file_name[0]='-';
				file_name[1]='l';
				strcpy (file_name+2,o_file_name);
			} else
				strcpy (file_name,o_file_name);
# else
			file_name=memory_allocate (strlen (o_file_name)+1);

			strcpy (file_name,o_file_name);
# endif
#endif
			*arg++=file_name;
		}
	}
	return arg;
}

# if defined (LINUX) && (defined (A_64) || defined (ARM) || defined (THUMB)) && !defined (MACH_O64)
int gcc_with_enable_default_pie (char *linker_file_name_p)
{
	char *command;
	FILE *f;
	int c,p;
	static char s[]="--enable-default-pie";

	command=malloc (strlen (linker_file_name_p)+1+8);
	if (command==NULL)
		return 0;

	strcpy (command,linker_file_name_p);
	strcat (command," -v 2>&1");
	f=popen (command,"r");

	free (command);

	if (f==NULL)
		return 0;

	p=0;
	while (c=getc(f),c!=EOF){
		if (c==s[p]){
			++p;
			if (p==sizeof(s)-1)
				break;
		} else if (p!=0)
			p = c=='-';
	}

	pclose (f);

	return c!=EOF;
}
#endif

static int link_project (P_NODE first_project_node,char *options_file_name,char *application_file_name)
{
	P_NODE project_node;
	char o_file_name[PATH_NAME_STRING_SIZE],system_file_name[PATH_NAME_STRING_SIZE];
	char *argv[1024],**arg;
	struct library_list *library;
#if defined (OPTIMISE_LINK) || (defined (_WINDOWS_) && defined (USE_CLEANLINKER))
# ifdef _WINDOWS_
	char quoted_linker_file_name_[PATH_NAME_STRING_SIZE];
# endif
	char linker_file_name_[PATH_NAME_STRING_SIZE];
#endif

#if (defined (_WINDOWS_) && !defined (USE_WLINK)) || defined (OMF)
# if defined (NO_CLIB)
	char startup0_file_name[PATH_NAME_STRING_SIZE];
# endif
	char startup1_file_name[PATH_NAME_STRING_SIZE],startup2_file_name[PATH_NAME_STRING_SIZE];
# ifdef A_64
	char startup3_file_name[PATH_NAME_STRING_SIZE],startup4_file_name[PATH_NAME_STRING_SIZE];
# endif
#else
	char start_up_file_name[PATH_NAME_STRING_SIZE];
#endif
#ifdef sparc
	char reals_file_name[PATH_NAME_STRING_SIZE];
#endif
#if defined (_WINDOWS_) && defined (USE_WLINK)
	char w_crt0_file_name[PATH_NAME_STRING_SIZE];
#endif
#if defined (_WINDOWS_) && (defined (USE_WLINK) || defined (OMF))
	char stack_option[32];
#endif	
#if defined (USE_CLEANLINKER)
	char kernel32_file_name[PATH_NAME_STRING_SIZE];
	char user32_file_name[PATH_NAME_STRING_SIZE];
	char gdi32_file_name[PATH_NAME_STRING_SIZE];
#endif
	if (!silent)
		printf ("Linking %s\n",main_project_node->pro_fname);


#ifdef OPTIMISE_LINK

	if (!no_optimise_link){
# if defined (_WINDOWS_)
	static char linker_output_file_name[]="linker.$$$";

#  ifdef OMF
	{
		char *p;
		
		for (p=linker_output_file_name; *p; ++p)
			if (*p=='/')
				*p='\\';
	}
#  endif

	linker_output_object_file_name=linker_output_file_name;
# else
	{
	static char linker_output_file_name[]="/tmp/linkerXXXXXX";
	int linker_output_fd;

	linker_output_fd=mkstemp (linker_output_file_name);
	if (linker_output_fd<0){
		error_s ("Can't create %s",linker_output_file_name);
		return 0;
	}
	close (linker_output_fd);
	linker_output_object_file_name=linker_output_file_name;
	}
# endif

	arg=argv;

	*arg++="linker";

# if defined (USE_CLEANLINKER)
	*arg++="-con";
# else
	*arg++=linker_output_object_file_name;
# endif

# if (defined (_WINDOWS_) && !defined (USE_WLINK)) || defined (OMF)
#  ifdef NO_CLIB
	need_file ("_startup0",OBJECT_FILE_EXTENSION,startup0_file_name);
	*arg++=startup0_file_name;
#  endif
	if ((clean_options & NO_TIME_PROFILE_MASK)!=0){
		need_file ("_startup1",OBJECT_FILE_EXTENSION,startup1_file_name);
	} else if (stack_trace)
		need_file ("_startup1Trace",OBJECT_FILE_EXTENSION,startup1_file_name);
	else
		need_file ("_startup1Profile",OBJECT_FILE_EXTENSION,startup1_file_name);
	*arg++=startup1_file_name;

	need_file ("_startup2",OBJECT_FILE_EXTENSION,startup2_file_name);
	*arg++=startup2_file_name;

#  ifdef A_64
	need_file ("_startup3",OBJECT_FILE_EXTENSION,startup3_file_name);
	*arg++=startup3_file_name;

	need_file ("_startup4",OBJECT_FILE_EXTENSION,startup4_file_name);
	*arg++=startup4_file_name;
#  endif
# else

	if ((clean_options & NO_TIME_PROFILE_MASK)!=0){
		need_file ("_startup",OBJECT_FILE_EXTENSION,start_up_file_name);
	} else if (stack_trace)
		need_file ("_startupTrace",OBJECT_FILE_EXTENSION,start_up_file_name);
	else if ((clean_options & CALLGRAPH_PROFILE_MASK)!=0)
		need_file ("_startupProfileGraph",OBJECT_FILE_EXTENSION,start_up_file_name);
	else
		need_file ("_startupProfile",OBJECT_FILE_EXTENSION,start_up_file_name);
	*arg++=start_up_file_name;
# endif
	need_file ("_system",OBJECT_FILE_EXTENSION,system_file_name);
	*arg++=system_file_name;

	for_l (project_node,first_project_node,pro_next){
		if (project_node->pro_up_to_date && !project_node->pro_ignore_o){
			char *file_name;
# ifdef _WINDOWS_
			FileTime time;
# endif

			if (!find_clean_system_file (project_node->pro_fname,OBJECT_FILE_EXTENSION,o_file_name,
							clean_o_path!=NULL ? clean_o_path : clean_abc_path
# ifdef _WINDOWS_
				,&time
# endif
			))
			{
				error_s ("Can't find %s.o",project_node->pro_fname);
			}

# ifdef _WINDOWS_
			file_name=memory_allocate (strlen (o_file_name)+3);

			file_name[0]='\"';
			strcpy (file_name+1,o_file_name);
			strcat (file_name,"\"");
# else
			file_name=memory_allocate (strlen (o_file_name)+1);
		
			strcpy (file_name,o_file_name);
# endif
			*arg++=file_name;
		}
	}

	arg = add_imported_object_files (first_project_node,o_file_name,arg);
	
	for_l (library,first_library,library_next){
		int s;

		s=strlen (library->library_file_name);
		if (s>=2 && library->library_file_name[0]!=':' && library->library_file_name[s-2]=='.' && library->library_file_name[s-1]=='o')
			*arg++=library->library_file_name;
	}

	{
	struct export_list *export;
	struct export_file_list *export_file;

	for_l (export,first_export,export_next){
		*arg++="-e";
		*arg++=export->export_name;
	}

	for_l (export_file,first_export_file,export_file_next){
		*arg++="-E";
		*arg++=export_file->export_file_name;
	}

	}

	*arg=NULL;

	{
	int pid,r,status;

# ifdef _WINDOWS_
	strcpy (linker_file_name_,clean_lib_path);
	strcat (linker_file_name_,DIRECTORY_SEPARATOR_STRING "StaticLinker.exe");

#  ifdef SPAWNVP_AND_WAIT
	argv[0]=linker_file_name_;
	r=spawnvp (_P_WAIT,linker_file_name_,argv);
	if (r>=0)
		r=wait (&status);

	return r>=0 && status==0;
#  else
	r=spawnv (_P_WAIT,linker_file_name_,argv);
#  endif
# else
	pid=fork();
	if (pid<0)
		error ("Fork failed");
	
	if (!pid){
		strcpy (linker_file_name_,clean_lib_path);
		strcat (linker_file_name_,"/linker");

		execv (linker_file_name_,argv);
		
		error ("Can't execute the linker");
	}
	
	r=wait_for_child (pid, "Linker",&status);

	if (!(r>=0 && status==0))
		return 0;
# endif
	}
	}
#endif
	
	arg=argv;

#ifdef USE_WLINK
	*arg++="wlink";
	*arg++="sys";
	*arg++="nt";
	*arg++="op";
	*arg++="c";
	*arg++="op";
	*arg++="q";
	*arg++="op";
	sprintf (stack_option,"stack=%dk",(ab_stack_size+1023) >> 10);
	*arg++=stack_option;
#else
# ifdef OMF
	*arg++="link386";
	*arg++="/bat";
	*arg++="/nol";
	*arg++="/noe";
	*arg++="/noi";
	*arg++="/nod";
	*arg++="/base:0x10000";
	sprintf (stack_option,"/st:%ld",(long)ab_stack_size);
	*arg++=stack_option;
# else
#  ifdef USE_CLEANLINKER
	strcpy (linker_file_name_,clean_lib_path);
	strcat (linker_file_name_,DIRECTORY_SEPARATOR_STRING "StaticLinker.exe");
#   ifdef _WINDOWS_
	quoted_linker_file_name_[0]='\"';
	strcpy (quoted_linker_file_name_+1,linker_file_name_);
	strcat (quoted_linker_file_name_+1,"\"");
	*arg++=quoted_linker_file_name_;
#   else
	*arg++=linker_file_name_;
#   endif
#  else
	*arg++=linker_file_name;
#  endif
# endif
#endif

#if defined (USE_CLEANLINKER) && !defined (_WINDOWS_)
	*arg++="-con";
#endif

    {
        static char ld_args_copy[PATH_LIST_STRING_SIZE];
        char *rest,*ld_arg;

        rest = strcpy (ld_args_copy,ld_args);
        while ((ld_arg=parse_word (&rest))!=NULL)
            *arg++=ld_arg;
    }

#if !defined (I486) && !defined (LINUX)
	*arg++="-e";
	*arg++="start";
	*arg++="-dc";
	*arg++="-dp";
#endif

#if !(defined (USE_WLINK) || defined (OMF) || defined (USE_CLEANLINKER))
	if (remove_symbol_table)
		*arg++="-s";
# if defined (LINUX) && (defined (A_64) || defined (ARM) || defined (THUMB)) && !defined (MACH_O64)
	if (gcc_with_enable_default_pie (linker_file_name))
		*arg++="-no-pie";
# endif
# if defined (LINUX) && !defined (A_64) && !defined (ARM)
	*arg++="-m32";
# endif
# ifdef ARM
	*arg++="-Wl,--gc-sections";
# endif
#endif
	if (application_file_name!=NULL){
#ifdef USE_WLINK
		*arg++="name";
#else
		*arg++="-o";
#endif
		*arg++=application_file_name;
	}
#if defined (_WINDOWS_) && !defined (USE_CLEANLINKER)
	else {
# ifdef USE_WLINK
		*arg++="name";
		*arg++="a";
# else 
		*arg++="-o";
		*arg++="a.exe";
# endif
	}
#endif

#ifndef NO_CLIB
# ifdef USE_WLINK
	*arg++="file";
	strcpy (w_crt0_file_name,clean_lib_path);
	strcat (w_crt0_file_name,"\\crt0.obj");
	*arg++=w_crt0_file_name;
# else
#  ifdef OMF
	*arg++="e:\\emx\\lib\\crt0.obj";
#  else
#   ifndef LINUX
	*arg++=crt0_file_name;
#   endif
#  endif
# endif
#endif

#ifdef OPTIMISE_LINK
	if (!no_optimise_link)
		*arg++ = linker_output_object_file_name;
	else {
#endif

#if (defined (_WINDOWS_) && !defined (USE_WLINK)) || defined (OMF)
# ifdef NO_CLIB
	need_file ("_startup0",OBJECT_FILE_EXTENSION,startup0_file_name);
	*arg++=startup0_file_name;
# endif
	need_file ("_startup1",OBJECT_FILE_EXTENSION,startup1_file_name);
	*arg++=startup1_file_name;

	need_file ("_startup2",OBJECT_FILE_EXTENSION,startup2_file_name);
	*arg++=startup2_file_name;

# ifdef A_64
	need_file ("_startup3",OBJECT_FILE_EXTENSION,startup3_file_name);
	*arg++=startup3_file_name;

	need_file ("_startup4",OBJECT_FILE_EXTENSION,startup4_file_name);
	*arg++=startup4_file_name;
# endif
#else
	if ((clean_options & NO_TIME_PROFILE_MASK)!=0)
		need_file ("_startup",OBJECT_FILE_EXTENSION,start_up_file_name);
	else if (stack_trace)
		need_file ("_startupTrace",OBJECT_FILE_EXTENSION,start_up_file_name);
	else if ((clean_options & CALLGRAPH_PROFILE_MASK)!=0)
		need_file ("_startupProfileGraph",OBJECT_FILE_EXTENSION,start_up_file_name);
	else
		need_file ("_startupProfile",OBJECT_FILE_EXTENSION,start_up_file_name);
	*arg++=start_up_file_name;
#endif	

	need_file ("_system",OBJECT_FILE_EXTENSION,system_file_name);
	*arg++=system_file_name;

	for_l (project_node,first_project_node,pro_next){
		if (project_node->pro_up_to_date && !project_node->pro_ignore_o){
			char *file_name;
#ifdef _WINDOWS_
			FileTime time;
#endif

			if (!find_clean_system_file (project_node->pro_fname,OBJECT_FILE_EXTENSION,o_file_name,
							clean_o_path!=NULL ? clean_o_path : clean_abc_path
#ifdef _WINDOWS_
				,&time
#endif
			))
			{
				error_s ("Can't find %s.o",project_node->pro_fname);
			}

#ifdef QUOTE_SPAWN_ARGUMENTS
			file_name=memory_allocate (strlen (o_file_name)+3);

			file_name[0]='\"';
			strcpy (file_name+1,o_file_name);
			strcat (file_name,"\"");
#else
			file_name=memory_allocate (strlen (o_file_name)+1);
		
			strcpy (file_name,o_file_name);
#endif
#ifdef USE_WLINK
			*arg++="file";
#endif
			*arg++=file_name;
		}
	}

	arg = add_imported_object_files (first_project_node,o_file_name,arg);

#ifdef OPTIMISE_LINK
	}
#endif

	for_l (library,first_library,library_next){
#ifdef OPTIMISE_LINK
		if (!no_optimise_link){
			int s;

			if (library->library_file_name[0]==':')
				*arg++=&library->library_file_name[1];
			else
				if (s=strlen (library->library_file_name), ! (s>=2 && library->library_file_name[s-2]=='.' && library->library_file_name[s-1]=='o'))
					*arg++=library->library_file_name;
		} else
#endif
		*arg++=library->library_file_name;
	}

#ifdef USE_WLINK
	*arg++="file";
#endif
	*arg++=options_file_name;

#ifdef sparc
	strcpy (reals_file_name,start_up_file_name);\
	replace_file_name_in_path (reals_file_name,"_reals",OBJECT_FILE_EXTENSION);
	*arg++=reals_file_name;
#endif

#if defined(_WINDOWS_) && !defined (USE_WLINK) && !defined (USE_CLEANLINKER)
	*arg++="-Lc:\\Gnu\\lib";
#endif

#if defined (sparc) || defined (LINUX) || (defined (I486) && !defined (USE_WLINK) && !defined (OMF) && !defined (USE_CLEANLINKER))
	*arg++="-lm";
#endif

#ifndef USE_WLINK
# if defined (_WINDOWS_) && !defined (USE_WLINK)
#  ifndef NO_CLIB
	*arg++="-lgcc";
	*arg++="-lc";
#  endif
#  if defined (USE_CLEANLINKER)
#   ifdef QUOTE_SPAWN_ARGUMENTS
	strcpy (kernel32_file_name,"\"-l");
	strcpy (kernel32_file_name+3,system_file_name+1);
	replace_file_name_in_path (kernel32_file_name+3,"kernel_library","");
	strcat (kernel32_file_name+3,"\"");
	*arg++ = kernel32_file_name;
	strcpy (user32_file_name,"\"-l");
	strcpy (user32_file_name+3,system_file_name+1);
	replace_file_name_in_path (user32_file_name+3,"user_library","");
	strcat (user32_file_name+3,"\"");
	*arg++ = user32_file_name;
	strcpy (gdi32_file_name,"\"-l");
	strcpy (gdi32_file_name+3,system_file_name+1);
	replace_file_name_in_path (gdi32_file_name+3,"gdi_library","");
	strcat (gdi32_file_name+3,"\"");
	*arg++ = gdi32_file_name;
#   else
	strcpy (kernel32_file_name,"-l");
	strcpy (kernel32_file_name+2,system_file_name);
	replace_file_name_in_path (kernel32_file_name+2,"kernel_library","");
	*arg++ = kernel32_file_name;
	strcpy (user32_file_name,"-l");
	strcpy (user32_file_name+2,system_file_name);
	replace_file_name_in_path (user32_file_name+2,"user_library","");
	*arg++ = user32_file_name;
	strcpy (gdi32_file_name,"-l");
	strcpy (gdi32_file_name+2,system_file_name);
	replace_file_name_in_path (gdi32_file_name+2,"gdi_library","");
	*arg++ = gdi32_file_name;
#   endif
#  else
	*arg++="-lkernel32";
#  endif
#  ifndef NO_CLIB
	*arg++="-ladvapi32";
	*arg++="-luser32";
	*arg++="-lgcc";
#  endif
# else	
	*arg++="-lc";
# endif
#endif

	*arg=NULL;

#if defined (_WINDOWS_)
	{
	int r;

# ifdef _WINDOWS_
#  ifdef SPAWNVP_AND_WAIT
	{
		int status;

		argv[0]=quoted_linker_file_name_;
		r=spawnvp (_P_WAIT,linker_file_name_,argv);
		if (r>=0)
			r=wait (&status);

		return r>=0 && status==0;
	}
#  else
	{
		static char linkerrs_file_name[]="linkerrs.$$$";
		SECURITY_ATTRIBUTES sa;
		STARTUPINFO si;
		PROCESS_INFORMATION pi;
		HANDLE linkerrs;
		char buffer[32767];
		char *c_p;
		char *cmd=buffer;

		sa.nLength=sizeof (SECURITY_ATTRIBUTES);
		sa.lpSecurityDescriptor=NULL;
		sa.bInheritHandle=TRUE;
		linkerrs=CreateFile (linkerrs_file_name,GENERIC_WRITE,FILE_SHARE_WRITE|FILE_SHARE_READ,&sa,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL);

		si.cb=sizeof (STARTUPINFO);
		si.lpReserved=NULL;
		si.lpReserved2=NULL;
		si.cbReserved2=0;
		si.lpDesktop=NULL;
		si.lpTitle=NULL;
		si.dwFlags=STARTF_USESTDHANDLES;
		si.hStdInput=GetStdHandle (STD_INPUT_HANDLE);
		si.hStdOutput=linkerrs;
		si.hStdError=linkerrs;

		*cmd++='"';
		for (c_p=linker_file_name_; *c_p; c_p++)
			*cmd++=*c_p;
		*cmd++='"';
		for (arg=argv+1; *arg; arg++){			
			c_p=*arg;
			
			if (cmd+3+strlen(c_p) > &buffer[32766]){
				fprintf (stderr,"Linker command line requires more than 32767 characters (use cpm instead)\n");
				exit (1);
			}

			*cmd++=' ';
#ifndef QUOTE_SPAWN_ARGUMENTS
			*cmd++='"';
#endif
			while (*c_p)
				*cmd++=*c_p++;
#ifndef QUOTE_SPAWN_ARGUMENTS
			*cmd++='"';
#endif
		}
		*cmd='\0';

		if (!CreateProcess (linker_file_name_,buffer,NULL,NULL,TRUE,0,NULL,NULL,&si,&pi)){
			fprintf (stderr,"CreateProcess failed\n");
			exit (1);
		}

		CloseHandle (pi.hThread);
		CloseHandle (linkerrs);

		if (WaitForSingleObject (pi.hProcess,INFINITE)!=WAIT_OBJECT_0){
			fprintf (stderr,"WaitForSingleObject failed\n");
			exit (1);
		}

		if (!GetExitCodeProcess (pi.hProcess,&r)){
			fprintf (stderr,"GetExitCodeProcess failed\n");
			exit (1);
		}

		CloseHandle (pi.hProcess);

		if ((linkerrs=fopen (linkerrs_file_name,"r"))==NULL){
			fprintf (stderr,"Failed to open %s\n",linkerrs_file_name);
			exit (1);
		}

		while (fgets (buffer,32767,linkerrs)!=NULL)
			fputs (buffer,stderr);

		fclose (linkerrs);
		unlink (linkerrs_file_name);
	}
#  endif
# else
	r=dos_exec (linker_file_name,argv,1);
# endif

	return r==0;
	}
#else
	{
	int pid,r,status;

	pid=fork();
	if (pid<0)
		error ("Fork failed");
	
	if (!pid){
		execv (linker_file_name,argv);
		
		error ("Can't execute the linker");
	}
	
	r=wait_for_child (pid, "Linker",&status);

# ifdef OPTIMISE_LINK
	if (!no_optimise_link)
		unlink (linker_output_object_file_name);
# endif

	return r>=0 && status==0;
	}
#endif
}

static void print_clm_version (void)
{
	printf ("clm - Clean make - version %s\n", CLM_VERSION);
}

static void print_version_and_variables (void)
{
    fprintf (stderr, "clm - Clean make - version %s\n\n", CLM_VERSION);
#if defined (I486) && defined (DOS)
    fprintf (stderr,"\tclean_lib_directory = \n\t\t%s\n", clean_lib_directory);
    fprintf (stderr,"\tassembler_file_name =\n\t\t%s\n", assembler_file_name);
    fprintf (stderr,"\tlinker_file_name =\n\t\t%s\n", linker_file_name);
    fprintf (stderr,"\tcrt0_file_name =\n\t\t%s\n", crt0_file_name);
    fprintf (stderr,"\tgcc_lib_directory_arg =\n\t\t%s\n", gcc_lib_directory_arg);
#else
    fprintf (stderr,"\tclean_lib_directory =\n\t\t%s\n", clean_lib_directory);
    fprintf (stderr,"\tclean_default_path_list =\n\t\t%s\n", clean_directory_list);
    fprintf (stderr,"\tclean_include_library_directory =\n\t\t%s\n", clean_include_library_directory);
	fprintf (stderr,"\tassembler_file_name =\n\t\t%s\n", assembler_file_name);
    fprintf (stderr,"\tlinker_file_name =\n\t\t%s\n", linker_file_name);
    fprintf (stderr,"\tcrt0_file_name =\n\t\t%s\n", crt0_file_name);
    fprintf (stderr,"\tld_args =\n\t\t%s\n", ld_args);
#endif

}

static void argument_error (void)
{
	print_clm_version();
	printf ("\nUsage:\n");
	printf ("  clm [options] module_name [-o application_name]\n");
	printf ("                 Make module_name\n");
	printf ("  clm -V\n");
	printf ("                 Print the version and variables\n");
	printf ("  clm --version\n");
	printf ("                 Print the version\n");
	printf ("\nPath options:\n");
	printf ("  -I <path>     Append <path> to the search path\n");
	printf ("  -IL <path>    Prepend the library path to <path> and append to the search path\n");
	printf ("  -P <path>     Replace the complete search path with <path>\n");
	printf ("\nMain module options:\n");
	printf ("  -w -nw        Enable/disable warnings\n");
	printf ("                (default: -w)\n");
	printf ("  -d -nd        Enable/disable the generation of readable label names\n");
	printf ("                (default: -nd)\n");
	printf ("  -sa -nsa      Enable/disable strictness analysis\n");
	printf ("                (default: -sa)\n");
	printf ("\nProject options:\n");
	printf ("  -mv           Verbose output of the make process\n");
	printf ("  -ms           Silent make process\n");
	printf ("  -O            Only generate the object file of the main module\n");
	printf ("  -PO           Only generate object files of the project modules\n");
	printf ("  -S            Only generate the assembly file of the main module\n");
	printf ("  -PS           Only generate assembly files of the project modules\n");
	printf ("  -ABC          Only generate the ABC file of the main module\n");
	printf ("  -PABC         Only generate ABC files of the project modules\n");
	printf ("  -c            Only check the syntax\n");
	printf ("                (note: compilation only considers the main module)\n");
	printf ("  -lt -nlt      Enable/disable listing only the inferred types\n");
	printf ("                (note: strictness information is never included)\n");
	printf ("                (default: -nlt)\n");
	printf ("  -lat -nlat    Enable/disable listing all the types\n");
	printf ("                (default: -nlat)\n");
	printf ("  -lset         List the types of functions for which not all strictness\n");
	printf ("                information has been exported\n");
	printf ("  -ci -nci      Enable/disable array indices checking\n");
	printf ("                (default: -nci)\n");
	printf ("  -ou -nou      Enable/disable optimizing uniqueness typing\n");
	printf ("                (default: -ou)\n");
#ifdef ARM
	printf ("  -pic          Generate position independent code\n");
#endif
	printf ("  -fusion -nfusion\n");
	printf ("                Enable/disable optimizing by fusion transformation\n");
	printf ("                (default: -nfusion)\n");
	printf ("  -generic_fusion -ngeneric_fusion\n");
	printf ("                Enable/disable optimizing by generic fusion transformation\n");
	printf ("                (default: -ngeneric_fusion)\n");
	printf ("  -pt -npt      Enable/disable the generation of code for time profiling\n");
	printf ("                (default: -npt)\n");
	printf ("  -pg -npg      Enable/disable the generation of code for callgraph profiling\n");
	printf ("                (default: -npg)\n");
	printf ("  -desc         Generate all descriptors\n");
	printf ("  -exl          Export local labels\n");
	printf ("  -tst          Generate code for stack tracing\n");
	printf ("  -dynamics     Enable support for dynamics\n");
	printf ("  -funcmayfail  Enable the function totality checker\n");
	printf ("  -warnfuncmayfail\n");
	printf ("                Enable the function totality checker but only emit it as a warning\n");
	printf ("\nLinker options:\n");
	printf ("  -ns           Disable stripping the application\n");
#ifdef OPTIMISE_LINK
	printf ("  -no-opt-link  Disable the optimizing linker\n");
#endif
	printf ("  -l <file>     Include the object file <file>\n");
	printf ("  -sl <file>    Include the shared library file <file>\n");
	printf ("  -e <symbol>   Export the label name <symbol> for shared libraries\n");
	printf ("  -E <file>     Same as -e, but the exported label names are specified in the\n");
	printf ("                file <file>, separated by newlines\n");
	printf ("\nCompiler application options:\n");
	printf ("  -clc <file>   Use <file> as the compiler executable\n");
#ifndef _WINDOWS_
	printf ("  -aC,<option(s)>\n");
	printf ("                Pass comma separated <option(s)> to the compiler\n");
	printf ("                (e.g. to set the compiler's heap size: -aC,-h,100m)\n");
#endif
	printf ("  -RE <file>    Redirect compiler stderror to <file>\n");
	printf ("  -RO <file>    Redirect compiler stdout to <file>\n");
#ifdef _WINDOWS_
	printf ("  -no-redirect-stderr\n");
	printf ("                Do not redirect stderr of child processes to stdout\n");
#endif
	printf ("\nApplication options:\n");
	printf ("  -h <size>     Set the heap size to <size> in bytes\n");
	printf ("                (note: append k, K, m, or M to denote kilobytes or megabytes)\n");
	printf ("                (default: 2M)\n");
	printf ("  -s <size>     Set the stack size to <size> in bytes\n");
	printf ("                (note: append k, K, m, or M to denote kilobytes or megabytes)\n");
	printf ("                (default: 512K)\n");
	printf ("  -b -sc        Display the basic values or the constructors\n");
	printf ("                (default: -sc)\n");
	printf ("  -t -nt        Enable/disable displaying the execution times\n");
	printf ("                (default: -t)\n");
	printf ("  -gc -ngc      Enable/disable displaying heap size after garbage collection\n");
	printf ("                (default: -ngc)\n");
	printf ("  -st -nst      Enable/disable displaying stack size before garbage collection\n");
	printf ("                (default: -nst)\n");
	printf ("  -nr           Disable displaying the result of the application\n"); 
	printf ("  -gcm          Use marking/compacting garbage collection\n");
	printf ("  -gcc          Use copy/compacting garbage collection\n");
	printf ("  -gcf <n>      Multiply the heap size with <n> after garbage collection\n");
	printf ("                (default: 20)\n");
	printf ("  -gci <size>   Set the initial heap size to <size> in bytes\n");
	printf ("                (note: append k, K, m, or M to denote kilobytes or megabytes)\n");
	printf ("                (default: 100K)\n");
	printf ("  -nortsopts    Disable the runtime system command line options\n");
	exit (1);
}

static long parse_size (register char *s)
{
	register int c;
	register long n;
	
	c=*s++;
	if (c<'0' || c>'9')
		error ("Digit expected in argument\n");
	
	n=c-'0';
	
	while (c=*s++,c>='0' && c<='9')
		n=n*10+(c-'0');
	
	if (c=='k' || c=='K'){
		c=*s++;
		n<<=10;
	} else if (c=='m' || c=='M'){
		c=*s++;
		n<<=20;
	}
	
	if (c!='\0')
		error ("Error in size");
	
	return n;
}

static long parse_integer (register char *s)
{
	register int c;
	register long n;

	c=*s++;
	if (c<'0' || c>'9')
		error ("Digit expected in argument\n");

	n=c-'0';

	while (c=*s++,c>='0' && c<='9')
		n=n*10+(c-'0');

	if (c!='\0')
		error ("Error in integer");

	return n;
}

static void add_library (char *library_file_name)
{
	int file_name_length;
	struct library_list *new_library_file;
	
	file_name_length=strlen (library_file_name);
	new_library_file=memory_allocate (sizeof (struct library_list)+file_name_length+1);

	strcpy (new_library_file->library_file_name,library_file_name);
	new_library_file->library_next=NULL;
	
	if (first_library==NULL)
		first_library=new_library_file;
	else
		last_library->library_next=new_library_file;
	last_library=new_library_file;
}

static void add_export (char *export_name)
{
	int export_name_length;
	struct export_list *new_export;
	
	export_name_length=strlen (export_name);
	new_export=memory_allocate (sizeof (struct export_list)+export_name_length+1);

	strcpy (new_export->export_name,export_name);
	new_export->export_next=NULL;
	
	if (first_export==NULL)
		first_export=new_export;
	else
		last_export->export_next=new_export;
	last_export=new_export;
}

static void add_export_file (char *export_file_name)
{
	int export_file_name_length;
	struct export_file_list *new_export_file;
	
	export_file_name_length=strlen (export_file_name);
	new_export_file=memory_allocate (sizeof (struct export_file_list)+export_file_name_length+1);

	strcpy (new_export_file->export_file_name,export_file_name);
	new_export_file->export_file_next=NULL;
	
	if (first_export_file==NULL)
		first_export_file=new_export_file;
	else
		last_export_file->export_file_next=new_export_file;
	last_export_file=new_export_file;
}

static P_NODE add_ignored (char *ignored_name)
{
    P_NODE ignored_module;

    for_l (ignored_module,first_project_node,pro_next)
        if (!strcmp (ignored_name,ignored_module->pro_fname))
            break;
    
	if (ignored_module==NULL)
        ignored_module=add_project_node(ignored_name);

    ignored_module->pro_ignore_o=1;

    return ignored_module;
}

static void read_shared_library (char *shared_script_name)
{
	char script_file_name[PATH_NAME_STRING_SIZE];
	char file_name[PATH_NAME_STRING_SIZE];
	FILE *fp;
#ifdef _WINDOWS_
	FileTime time;
#endif

	if (!find_file (shared_script_name,".lo",script_file_name,clean_lib_path
#ifdef _WINDOWS_
		,&time
#endif
	))
		error_s ("Can't find %s.lo",shared_script_name);

	if (!(fp=fopen (script_file_name,"r")))
		error_s ("Can't open %s.lo",shared_script_name);

	while (fgets (file_name,PATH_NAME_STRING_SIZE,fp)!=NULL && file_name[0]!='='){
		char *rest,*parsed_file_name;

		rest=file_name;
		while ((parsed_file_name=parse_word (&rest))!=NULL)
			add_library (parsed_file_name);
	}
	{
	P_NODE ignored_module;
	int adding_dependencies;
	
	ignored_module=NULL;
	adding_dependencies=0;
	
	while (fgets (file_name,PATH_NAME_STRING_SIZE,fp)!=NULL){
		char *rest,*parsed_file_name;

		rest=file_name;
		while ((parsed_file_name=parse_word (&rest))!=NULL){
			if (parsed_file_name[0]=='('){
				++parsed_file_name;
				adding_dependencies=1;
			}

			if (adding_dependencies){
				int length;

				length=strlen (parsed_file_name);
				if (parsed_file_name[length-1]==')'){
					--length;
					parsed_file_name[length]='\0';
					adding_dependencies=0;
				}

				if (length>0){
				    if (ignored_module==NULL)
						fprintf (stderr,"no ignored module specified for %s\n",parsed_file_name);
					else
						add_dependency (&ignored_module->pro_depend,parsed_file_name);
				}
			} else 
				ignored_module=add_ignored (file_name);
		}
	}
	}
}

#define option_on(mask)  clean_options|=(mask);  clean_options_mask|=(mask);
#define option_off(mask) clean_options&=~(mask); clean_options_mask|=(mask);

#ifdef __MWERKS__
#	include <SIOUX.h>
extern int ccommand(char ***);
#	include <Memory.h>
#endif

void init_directories_from_environment()
{
	char* clean_home;

	if (!  (clean_lib_directory[0]=='.' && clean_lib_directory[1]=='\0' &&
			clean_directory_list[0]=='.' && clean_directory_list[1]=='\0' &&
		  	clean_include_library_directory[0]=='.' && clean_include_library_directory[1]=='\0'))
		return;

#if defined (LINUX) || defined (_WINDOWS_)
	/* If the CLEAN_HOME environment variable is set, it is used to initialize the default directories */	
	clean_home = getenv ("CLEAN_HOME");
	if (clean_home==NULL)
		return;

	if (clean_lib_directory[0]=='.' && clean_lib_directory[1]=='\0'){
		/* CLEANLIB */
		strncpy(clean_lib_directory, clean_home, sizeof(_clean_lib_directory) - 17);
# ifdef _WINDOWS_
#  ifdef A_64
		strncat(clean_lib_directory,"\\Tools\\Clean System 64",sizeof(_clean_lib_directory) - 17 - strlen(clean_lib_directory));
#  else
		strncat(clean_lib_directory,"\\Tools\\Clean System",sizeof(_clean_lib_directory) - 17 - strlen(clean_lib_directory));
#  endif
# else
		strncat(clean_lib_directory,"/lib/exe",sizeof(_clean_lib_directory) - 17 - strlen(clean_lib_directory));
# endif
	}

	if (clean_directory_list[0]=='.' && clean_directory_list[1]=='\0'){
		/* CLEANPATH */
		strncpy(clean_directory_list, clean_home, sizeof(_clean_directory_list) - 17);
# ifdef _WINDOWS_
		strncat(clean_directory_list,"\\Libraries\\StdEnv",sizeof(_clean_directory_list) - 17 - strlen(clean_directory_list));
# else
		strncat(clean_directory_list,"/lib/StdEnv",sizeof(_clean_directory_list) - 17 - strlen(clean_directory_list) - 17);
# endif
	}

	if (clean_include_library_directory[0]=='.' && clean_include_library_directory[1]=='\0'){
		/* CLEANILIB */
		strncpy(clean_include_library_directory, clean_home, sizeof(_clean_include_library_directory) - 17);
# ifdef _WINDOWS_
		strncat(clean_include_library_directory,"\\Libraries",sizeof(_clean_include_library_directory) - 17 - strlen(clean_include_library_directory));
# else
		strncat(clean_include_library_directory,"/lib",sizeof(_clean_include_library_directory) - 17 - strlen(clean_include_library_directory));
# endif
	}
#endif
}

#if defined (__MWERKS__)
int main (void)
{
	int argc;
	char *(arg_vector[32]),**argv;
#else
int main (int argc,char **argv)
{
#endif
	int arg_n;
	char *application_file_name,*main_module_name;

#if defined (POWER)
# if defined (__MWERKS__)
	SetApplLimit (GetApplLimit() - 200*1024);
	argv=arg_vector;
	argc = ccommand (&argv);
# else
#  ifdef _LBFSIZ
	setvbuf (stdout,NULL,_IOLBF,_LBFSIZ);
#  else
	setvbuf (stdout,NULL,_IOLBF,256);
#  endif
# endif
#endif

#if defined (__MWERKS__)
	SIOUXSettings.showstatusline=0;
#endif

#ifdef DOS
	{
		int length;
	
		strcpy (clean_lib_directory,argv[0]);

		length=strlen (clean_lib_directory);
		while (length>0){
			--length;
			if (clean_lib_directory[length]=='/' ||
				clean_lib_directory[length]=='\\')
			{
				clean_lib_directory[length]=0;
				break;
			}
		}
		
		if (length==0)
			error ("argv[0] doesn't contain path name");
		strcat (clean_lib_directory,"/lib");
	}	
#endif
	init_directories_from_environment();

    if (argc==2 && strcmp (argv[1],"-V")==0){
        print_version_and_variables();
        exit (0);
    }

	if (argc==2 && strcmp (argv[1],"--version")==0){
		print_clm_version();
		exit (0);
	}

	if (argc<2 || argv[argc-1][0]=='-')
		argument_error();
	
	heap_size=2048<<10;
	ab_stack_size=512<<10;
	flags=8;
	initial_heap_size=100<<10;
	heap_size_multiple=20<<8;
	remove_symbol_table=1;
	check_stack_overflow=0;
	check_indices=0;
#ifdef ARM
	position_independent_code=0;
#endif
	dynamics=0;
#ifdef OPTIMISE_LINK
	no_optimise_link=0;
#endif
	stack_trace=0;

	cocl_redirect_stdout=NULL;
	cocl_redirect_stderr=NULL;
 
	first_library=NULL;
	last_library=NULL;
	first_export=NULL;
	last_export=NULL;
	first_export_file=NULL;
	last_export_file=NULL;

	get_paths();
	
	for (arg_n=1; arg_n<argc && argv[arg_n][0]=='-'; ++arg_n){
		char *argument,*s;
		
		argument=argv[arg_n];		
		s=argument+1;
		
		/* driver options */
		if (!strcmp (s,"mv"))
			verbose=1;
		else if (!strcmp (s,"ms"))
			silent=1;
		else if (!strcmp (s,"c")){
			single_module=1;
			syntax_check=1;
		} else if (!strcmp (s,"ABC")){
			single_module=1;
			only_abc_files=1;
		} else if (!strcmp (s,"S")){
			single_module=1;
			only_s_files=1;
		} else if (!strcmp (s,"O")){
			single_module=1;
			only_o_files=1;
		} else if (!strcmp (s,"PABC"))
			only_abc_files=1;
		else if (!strcmp (s,"PS"))
			only_s_files=1;
		else if (!strcmp (s,"PO"))
			only_o_files=1;
		else if (!strcmp (s,"ns"))
			remove_symbol_table=0;
#ifdef OPTIMISE_LINK
		else if (!strcmp (s,"no-opt-link"))
			no_optimise_link=1;
#endif
		/* application options */
		else if (!strcmp (s,"h")){
			++arg_n;
			if (arg_n>=argc)
				error ("Heap size missing\n");
			heap_size=parse_size (argv[arg_n]);
		} else if (!strcmp (s,"s")){
			++arg_n;
			if (arg_n>=argc)
				error ("Stack size missing\n");
			ab_stack_size=parse_size (argv[arg_n]);
		} else if (!strcmp (s,"b"))
			flags |= 1;
		else if (!strcmp (s,"sc"))
			flags &= ~1;
		else if (!strcmp (s,"t"))
			flags |= 8;
		else if (!strcmp (s,"nt"))
			flags &= ~8;
		else if (!strcmp (s,"gc"))
			flags |= 2;
		else if (!strcmp (s,"ngc"))
			flags &= ~2;
		else if (!strcmp (s,"st"))
			flags |= 4;
		else if (!strcmp (s,"nst"))
			flags &= ~4;
		else if (!strcmp (s,"nr"))
			flags |= 16;
		else if (!strcmp (s,"gcm"))
			flags |= 64;
		else if (!strcmp (s,"gcc"))
			flags &= ~64;
		else if (!strcmp (s,"gci")){
			++arg_n;
			if (arg_n>=argc)
				error ("Initial heap size missing\n");
			initial_heap_size=parse_size (argv[arg_n]);
		} else if (!strcmp (s,"gcf")){
			++arg_n;
			if (arg_n>=argc)
				error ("Next heap size factor missing\n");
			heap_size_multiple=parse_integer (argv[arg_n])<<8;
		} else if (!strcmp (s,"nortsopts"))
			flags |= 8192;
		/* clean options */
		else if (!strcmp (s,"exl")){
			option_on (EXPORT_LOCAL_LABELS_MASK);
		} else if (!strcmp (s,"desc")){
			option_off (NO_DESCRIPTORS_MASK);
		} else if (!strcmp (s,"w")){
			option_on (WARNING_MASK);
		} else if (!strcmp (s,"nw")){
			option_off (WARNING_MASK);
		} else if (!strcmp (s,"d")){
			option_on (DEBUG_MASK);
		} else if (!strcmp (s,"nd")){
			option_off (DEBUG_MASK);
		} else if (!strcmp (s,"sa")){
			option_on (STRICTNESS_ANALYSIS_MASK);
		} else if (!strcmp (s,"nsa")){
			option_off (STRICTNESS_ANALYSIS_MASK);
		} else if (!strcmp (s,"lt")){
			option_on (LIST_TYPES_MASK);
		} else if (!strcmp (s,"nlt")){
			option_off (LIST_TYPES_MASK);
		} else if (!strcmp (s,"lat")){
			option_on (LIST_ALL_TYPES_MASK);
		} else if (!strcmp (s,"nlat")){
			option_off (LIST_ALL_TYPES_MASK);
		} else if (!strcmp (s,"lset")){
			list_strict_export_types=1;
        } else if (!strcmp (s,"ou")){
            option_off (NO_REUSE_UNIQUE_NODES_MASK);
        } else if (!strcmp (s,"nou")){
            option_on (NO_REUSE_UNIQUE_NODES_MASK);
/*
        } else if (!strcmp (s,"pm")){
            option_on (MEMORY_PROFILE);
        } else if (!strcmp (s,"npm")){
            option_off (MEMORY_PROFILE);
*/
        } else if (!strcmp (s,"pg")){
            option_on (CALLGRAPH_PROFILE_MASK);
            option_off (NO_TIME_PROFILE_MASK);
			stack_trace=0;
        } else if (!strcmp (s,"npg")){
            option_off (CALLGRAPH_PROFILE_MASK);
            option_on (NO_TIME_PROFILE_MASK);
        } else if (!strcmp (s,"pt")){
            option_off (NO_TIME_PROFILE_MASK);
			stack_trace=0;
        } else if (!strcmp (s,"npt")){
            option_on (NO_TIME_PROFILE_MASK);
        } else if (!strcmp (s,"tst")){
            option_off (NO_TIME_PROFILE_MASK);
			stack_trace=1;
        } else if (!strcmp (s,"fusion")){
            option_on (FUSION_MASK);
        } else if (!strcmp (s,"nfusion")){
            option_off (FUSION_MASK);
		} else if (!strcmp (s,"generic_fusion")){
			option_on (GENERIC_FUSION_MASK);
		} else if (!strcmp (s,"ngeneric_fusion")){
			option_off (GENERIC_FUSION_MASK);
		} else if (!strcmp (s,"dynamics")){
			dynamics=1;
		} else if (!strcmp (s,"clc")){
			++arg_n;
			if (arg_n>=argc)
				error ("Clean compiler file name missing\n");
			clean_cocl_file_name=argv[arg_n];
        } else if (strcmp (s, "RE") == 0 || strcmp (s, "RAE") == 0){
            cocl_redirect_stderr_option = argument;
            if (++arg_n < argc)
                cocl_redirect_stderr = argv [arg_n];
            else
                error ("file name expected after -RE");
        } else if (strcmp (s, "RO") == 0 || strcmp (s, "RAO") == 0){
            cocl_redirect_stdout_option = argument;
            if (++arg_n < argc)
                cocl_redirect_stdout = argv [arg_n];
            else
                error ("file name expected after -RO");
#ifdef _WINDOWS_
		} else if (!strcmp (s,"no-redirect-stderr")){
			redirect_stderr_to_stdout=0;
#endif
		} else if (!strcmp (s,"con")){
#ifdef _WINDOWS_
			flags |= 2048;
#endif
		} else if (!strcmp (s,"funcmayfail")){
			funcmayfail_warning_or_error=2;
		} else if (!strcmp (s,"warnfuncmayfail")){
			funcmayfail_warning_or_error=1;
		/* code generator options */
		} else if (!strcmp (s,"ci")){
			check_indices=1;
		} else if (!strcmp (s,"nci")){
			check_indices=0;
#ifdef ARM
		} else if (!strcmp (s,"pic")){
			position_independent_code=1;
#endif
		} else if (!strcmp (s,"l")){
			++arg_n;
			if (arg_n>=argc)
				error ("Library name missing\n");
			add_library (argv[arg_n]);
		} else if (!strcmp (s,"sl")){
			++arg_n;
			if (arg_n>=argc)
			   error ("Shared library name missing\n");
			read_shared_library (argv[arg_n]);
		} else if (!strcmp (s,"e")){
			++arg_n;
			if (arg_n>=argc)
				error ("Exported label name missing\n");
			add_export (argv[arg_n]);
		} else if (!strcmp (s,"E")){
			++arg_n;
			if (arg_n>=argc)
				error ("File name with exported label names missing\n");
			add_export_file (argv[arg_n]);
		} else if (!strcmp (s,"P")){
			int l;
			
			++arg_n;
			if (arg_n>=argc)
			   error ("Path list missing\n");
			l=strlen (argv[arg_n]);
			if (l<clean_path_list_max_size){
				strcpy (clean_path_list,argv[arg_n]);
			} else if (l<PATH_LIST_STRING_SIZE){
				clean_path_list=strcpy (clean_path_list_copy,argv[arg_n]);
				clean_path_list_max_size=PATH_LIST_STRING_SIZE;
			} else {
				clean_path_list=strcpy (memory_allocate(l+1),argv[arg_n]);
				clean_path_list_max_size=l+1;
			}
		} else if (!strcmp (s,"I")){
			int l;

			++arg_n;
			if (arg_n>=argc)
			   error ("Path missing\n");
			l=strlen (argv[arg_n]);
			if (clean_path_list[0]!='\0')
				++l;
			if (l>=clean_path_list_max_size){
				clean_path_list_max_size += (clean_path_list_max_size>>1) + l + 64;
				clean_path_list=strcpy (memory_allocate (clean_path_list_max_size),clean_path_list);
			}
			if (clean_path_list[0]!='\0')
				strcat (clean_path_list,PATH_SEPARATOR_STRING);
			strcat (clean_path_list,argv[arg_n]);
		} else if (!strcmp (s,"IL")){
			int l;

			++arg_n;
			if (arg_n>=argc)
			   error ("Path missing\n");
			l=strlen (clean_include_library_directory) + 1 + strlen (argv[arg_n]);
			if (clean_path_list[0]!='\0')
				++l;
			if (l>=clean_path_list_max_size){
				clean_path_list_max_size += (clean_path_list_max_size>>1) + l + 64;
				clean_path_list=strcpy (memory_allocate (clean_path_list_max_size),clean_path_list);
			}			
			if (clean_path_list[0]!='\0')
				strcat (clean_path_list,PATH_SEPARATOR_STRING);
			strcat (clean_path_list,clean_include_library_directory);
			strcat (clean_path_list,"/");
			strcat (clean_path_list,argv[arg_n]);
		} else
#ifndef _WINDOWS_
		if (s[0]=='a' && s[1]=='C' && s[2]==',')
			add_compiler_arguments (&s[3]);
		else
#endif
			error_s ("Unknown option: %s",argument);
	}

	main_module_name=argv[arg_n];

	if (arg_n==argc-3){
		if (strcmp (argv[arg_n+1],"-o")!=0)
			argument_error();
		application_file_name=argv[arg_n+2];
	} else {
		application_file_name=NULL;
		if (arg_n!=argc-1)
			argument_error();
	}

	if (first_project_node==NULL)
		main_project_node=add_project_node (main_module_name);
	else {
		P_NODE old_first_project_node,old_last_project_node;
		
		old_first_project_node=first_project_node;
		old_last_project_node=last_project_node;

		first_project_node=NULL;

		main_project_node=add_project_node (main_module_name);

		main_project_node->pro_next=old_first_project_node;
		last_project_node=old_last_project_node;
	}

	if (make_project_to_abc_files (first_project_node)){
#ifdef CACHING_COMPILER
		if (compiler_started){
			stop_compiler();
			compiler_started=0;
		}
#endif
		if (only_abc_files || syntax_check)
			return 0;
		
		if (only_s_files)
			return make_project_to_s_files();
		
		if (make_project_to_o_files()){
			char *options_file_name;

			if (only_o_files)
				return 0;

			if (create_options_file (&options_file_name)){
				if (!link_project (first_project_node,options_file_name,application_file_name)){
					unlink (options_file_name);
					return 1;
				}
 				unlink (options_file_name);
				return 0;
			}
		}
	}
#ifdef CACHING_COMPILER
	stop_compiler ();
#endif
	return 1;
}

