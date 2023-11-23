
#include <stdio.h>
#include <string.h>
#include <unistd.h>

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
	int int_descriptor;
	int char_descriptor;
	int real_descriptor;
	int bool_descriptor;
	int string_descriptor;
	int array_descriptor;
};

extern void ew_print_string (char *);

static int heap_written_count=0;

#define MAX_N_HEAPS 10

#define MAX_PATH_LENGTH 256

void write_heap (struct heap_info *h)
{
	static char heap_profile_file_name_suffix[]=" Heap Profile0.hcl";
	char heap_profile_file_name[MAX_PATH_LENGTH+1];
	FILE *heap_file;
	int length_application_name,file_ok;

	if (heap_written_count >= MAX_N_HEAPS)
		return;

    length_application_name=readlink ("/proc/self/exe",heap_profile_file_name,MAX_PATH_LENGTH);
    if (length_application_name>=0){
        int length_file_name,size_heap_profile_file_name_suffix;

        heap_profile_file_name[length_application_name]='\0';

        size_heap_profile_file_name_suffix=sizeof (heap_profile_file_name_suffix);
        length_file_name=0;
        while (heap_profile_file_name[length_file_name]!='\0')
            ++length_file_name;

        if (length_file_name+size_heap_profile_file_name_suffix>MAX_PATH_LENGTH){
			++heap_written_count;
			ew_print_string( "Heap file could not be created because the file name is too long.\n" );
			return;
		}

        strcat (&heap_profile_file_name[length_file_name],heap_profile_file_name_suffix);

		heap_profile_file_name[length_file_name+size_heap_profile_file_name_suffix-6]='0'+heap_written_count;
    } else {
		++heap_written_count;
		ew_print_string( "Heap file could not be created because /proc/self/exe could not be read\n");
		return;
    }

	++heap_written_count;
	
	heap_file = fopen (heap_profile_file_name,"w");
	if (heap_file==NULL){
		heap_written_count = MAX_N_HEAPS;
		
		ew_print_string ("Heap file '");
		ew_print_string (heap_profile_file_name);
		ew_print_string ("' could not be created.\n");
		
		return;
	}
	
	/* save application name */
	file_ok = fwrite (&length_application_name,sizeof (int),1,heap_file)==1;
	if (file_ok)
		file_ok = fwrite (heap_profile_file_name,1,length_application_name,heap_file)==length_application_name;	

	/*  write heap_info-structure */
	if (file_ok)
		file_ok = fwrite (h,sizeof (struct heap_info),1,heap_file)==1;

	/* write stack */
	if (file_ok)
		file_ok = fwrite (h->stack_begin,(int)(h->stack_end) - (int)(h->stack_begin),1,heap_file)==1;

	/* write heap1 */
	if (file_ok)
		file_ok = fwrite (h->heap1_begin,(int)(h->heap1_end) - (int)(h->heap1_begin),1,heap_file)==1;
	
	/* write heap2 */
	if (file_ok)
		file_ok = fwrite (h->heap2_begin,(int)(h->heap2_end) - (int)(h->heap2_begin),1,heap_file)==1;

	if (!file_ok){
		heap_written_count = MAX_N_HEAPS;
		
		ew_print_string ("Heap file '");
		ew_print_string (heap_profile_file_name);
		ew_print_string ("' could not be written.\n");		
	}

	fclose (heap_file);
}

