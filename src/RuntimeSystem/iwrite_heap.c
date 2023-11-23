
#include <windows.h>

#ifndef TCHAR
# define TCHAR char

# if 0
typedef struct _WIN32_FIND_DATA {
    DWORD dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD    nFileSizeHigh;
    DWORD    nFileSizeLow;
    DWORD    dwReserved0;
    DWORD    dwReserved1;
    TCHAR    cFileName[ MAX_PATH ];
    TCHAR    cAlternateFileName[ 14 ];
} WIN32_FIND_DATA;
# endif
#endif

struct heap_info {
	int *heap1_begin;
	int *heap1_end;
	int *heap2_begin;
	int *heap2_end;
	int *stack_begin;
	int *stack_end;
	int *text_begin;
	int *data_begin;
	int *small_integers;
	int *characters;
	size_t int_descriptor;
	size_t char_descriptor;
	size_t real_descriptor;
	size_t bool_descriptor;
	size_t string_descriptor;
	size_t array_descriptor;
};

static int heap_written_count=0;

#define MAX_N_HEAPS 10

extern char **global_argv;

#define MAX_PATH_LENGTH 256

void write_heap (struct heap_info *h)
{
	HANDLE heap_file_h;
	int NumberOfBytesWritten;
	static char heap_profile_file_name_suffix[]=" Heap Profile0.hcl";
	char heap_profile_file_name[MAX_PATH_LENGTH+1];
	char *argv0,*heap_profile_file_name_p;
	int length_argv0,length_argv0_copy_in_memory,length_heap_profile_file_name;
	BOOL fileOk;

	if (heap_written_count >= MAX_N_HEAPS)
		return;

	argv0=global_argv[0];
	{
		char *arg_p;

		for (arg_p=argv0; *arg_p!='\0'; ++arg_p)
			;
		length_argv0=arg_p-argv0;
	}
	
	if (argv0[0]=='\"' && length_argv0>1 && argv0[length_argv0-1]=='\"'){
		++argv0;
		length_argv0-=2;
	}

	heap_profile_file_name_p=argv0;
	length_heap_profile_file_name=length_argv0;

	if (length_heap_profile_file_name<=MAX_PATH_LENGTH){
		WIN32_FIND_DATA find_data;
		HANDLE find_first_file_handle;
		int i;
		
		for (i=0; i<length_heap_profile_file_name; ++i)
			heap_profile_file_name[i]=heap_profile_file_name_p[i];
		heap_profile_file_name[length_heap_profile_file_name]='\0';

		find_first_file_handle=FindFirstFileA (heap_profile_file_name,&find_data);
		if (find_first_file_handle!=INVALID_HANDLE_VALUE){
			char *file_name_p,*p;
			int file_name_length;
			
			file_name_p=find_data.cFileName;
			for (p=file_name_p; *p!='\0'; ++p)
				;
			file_name_length=p-file_name_p;
			
			for (p=heap_profile_file_name+length_heap_profile_file_name; p>heap_profile_file_name && p[-1]!='\\' && p[-1]!='/'; --p)
				;
			
			if ((p-heap_profile_file_name)+file_name_length<=MAX_PATH_LENGTH){				
				for (i=0; i<file_name_length; ++i)
					p[i]=file_name_p[i];
				p[i]='\0';
				
				heap_profile_file_name_p=heap_profile_file_name;
				length_heap_profile_file_name=&p[i]-heap_profile_file_name;
			}
			
			FindClose (find_first_file_handle);
		}
	}

	{
		char *p;
		
		p=&heap_profile_file_name_p[length_heap_profile_file_name];
		if (length_heap_profile_file_name>3 && p[-4]=='.' && p[-3]=='e' && p[-2]=='x' && p[-1]=='e')
			length_heap_profile_file_name-=4;
	}
	
	if (length_heap_profile_file_name+sizeof (heap_profile_file_name_suffix)>MAX_PATH_LENGTH){
		++heap_written_count;
		ew_print_string( "Heap file could not be created because the file name is too long.\n" );
		return;
	}
	
	{
		char *p;
		int i;

		if (heap_profile_file_name_p!=heap_profile_file_name)
			for (i=0; i<length_heap_profile_file_name; ++i)
				heap_profile_file_name[i]=heap_profile_file_name_p[i];
		
		p=heap_profile_file_name+length_heap_profile_file_name;
		for (i=0; i<=sizeof(heap_profile_file_name_suffix); ++i)
			p[i]=heap_profile_file_name_suffix[i];
			
		p[sizeof(heap_profile_file_name_suffix)-6]='0'+heap_written_count;
	}
	
	++heap_written_count;
	
	heap_file_h = CreateFileA (heap_profile_file_name, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
	if (heap_file_h==INVALID_HANDLE_VALUE){
		heap_written_count = MAX_N_HEAPS;
		
		ew_print_string( "Heap file '" );
		ew_print_string( heap_profile_file_name );
		ew_print_string( "' could not be created.\n" );
		
		return;
	}
	
	/* save application name */
	length_argv0_copy_in_memory=length_argv0;
	fileOk = WriteFile (heap_file_h, &length_argv0_copy_in_memory, sizeof(int), &NumberOfBytesWritten, NULL);
	if (fileOk)
		fileOk = WriteFile (heap_file_h, argv0, length_argv0, &NumberOfBytesWritten, NULL);	

	/*  write heap_info-structure */
	if (fileOk)
		fileOk = WriteFile (heap_file_h, h, sizeof(struct heap_info), &NumberOfBytesWritten, NULL);  

	/* write stack */
	if (fileOk)
		fileOk = WriteFile (heap_file_h, h->stack_begin, (size_t)(h->stack_end) - (size_t)(h->stack_begin), &NumberOfBytesWritten, NULL);

	/* write heap1 */
	if (fileOk)
		fileOk = WriteFile (heap_file_h, h->heap1_begin, (size_t)(h->heap1_end) - (size_t)(h->heap1_begin), &NumberOfBytesWritten, NULL);
	
	/* write heap2 */
	if (fileOk)
		fileOk = WriteFile (heap_file_h, h->heap2_begin, (size_t)(h->heap2_end) - (size_t)(h->heap2_begin), &NumberOfBytesWritten, NULL);

	if (!fileOk){
		heap_written_count = MAX_N_HEAPS;
		
		ew_print_string( "Heap file '" );
		ew_print_string( heap_profile_file_name );
		ew_print_string( "' could not be written.\n" );		
	}

	CloseHandle (heap_file_h);
}
