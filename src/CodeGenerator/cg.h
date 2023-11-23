void *memory_allocate (int size);
void memory_free (void *memory_block);
void *allocate_memory_from_heap (int size);
void *fast_memory_allocate (int size);
void release_heap (VOID);

#define memory_allocate_type(t) ((t*)memory_allocate(sizeof(t)))
#define fast_memory_allocate_type(t) ((t*)fast_memory_allocate(sizeof(t)))
#define allocate_memory_from_heap_type(t) ((t*)allocate_memory_from_heap(sizeof(t)))

void warning (char *error_string);
void warning_i (char *error_string,int integer);
void warning_s (char *error_string,char *string);
void warning_si (char *error_string,char *string,int i);
void error (char *error_string);
void error_i (char *error_string,int integer);
void error_s (char *error_string,char *string);
void error_si (char *error_string,char *string,int i);
void internal_error (char *error_string);
void internal_error_in_function (char *function_name);

extern int list_flag;
extern int check_stack;
extern int assembly_flag;
extern int sun_flag;
extern int mc68000_flag;
extern int mc68881_flag;
extern int parallel_flag;
extern int check_index_flag;
extern int module_info_flag;
extern int profile_table_flag;

#ifdef G_POWER
extern int fmadd_flag;
#endif

#if (defined (LINUX) && defined (G_AI64)) || defined (ARM)
extern int pic_flag;
#endif
#if defined (LINUX) && defined (G_AI64)
extern int rts_got_flag;
#endif

extern char *this_module_name;
