#ifdef WINDOWS
# include <windows.h>
# define HFILE HANDLE
# include "wcon.h"
# include "wfileIO3.h"
extern void halt (void);
# define INT64 long long
# if _WIN64
#  define PTR_INT long long
#  define IF_INT_64_OR_32(a,b) (a)
# else
#  define PTR_INT long
#  define IF_INT_64_OR_32(a,b) (b)
# endif
#else
# include <stdlib.h>
# include <time.h>
# include "scon.h"
struct file;
extern void file_write_char (int c,struct file *f);
extern void file_write_characters (unsigned char *p,unsigned int length,struct file *f);
extern void file_write_int (long i,struct file *f);
# define INT64 long long
# define PTR_INT long
# define IF_INT_64_OR_32(a,b) (a)
#endif

struct clean_string {
	int length;
	char characters[];
};

extern struct file *open_file (struct clean_string *file_name,unsigned int file_mode);
extern int close_file (struct file *f);

#define CYCLE_DETECTION_FRAMES 5
#define STACK_FRAMES 20
#define OVERHEAD_SAMPLES 40
#ifdef WINDOWS
# define FREQUENCY_N_TICKS 1000
#endif
#define FREQUENCY_SAMPLES 32

static inline void *safe_malloc (size_t size)
{
#ifdef WINDOWS
	void *ptr=HeapAlloc (GetProcessHeap(),0,size);
#else
	void *ptr=malloc (size);
#endif
	if (!ptr){
		ew_print_string ("Failed to allocate memory for callgraph profiling.\n");
#ifdef WINDOWS
		halt();
#else
		exit (-1);
#endif
	}
	return ptr;
}

static inline void *safe_realloc (void *ptr,size_t size)
{
#ifdef WINDOWS
	ptr=HeapReAlloc (GetProcessHeap(),0,ptr,size);
#else
	ptr=realloc (ptr,size);
#endif
	if (!ptr){
		ew_print_string ("Failed to allocate memory for callgraph profiling.\n");
#ifdef WINDOWS
		halt();
#else
		exit (-1);
#endif
	}
	return ptr;
}

struct profile_info {
	int profile_info_id;
	int profile_info_module;
	char profile_info_name[];
};

static struct clean_string *module_string (struct profile_info *info)
{
#ifdef MACH_O64
	return (struct clean_string*)((long)&info->profile_info_module+info->profile_info_module);
#else
	return (struct clean_string*)(PTR_INT)info->profile_info_module;
#endif
}

struct profile_node;

struct profile_node_children {
	struct profile_node *node_children_cur;
	struct profile_node_children *node_children_next;
};

struct profile_node {
	struct profile_info *node_info;
#ifdef WIN32
	void *_padding;
#endif
	unsigned INT64 node_ticks;
	unsigned INT64 node_allocated_words;
	unsigned int node_tail_and_return_calls;
	unsigned int node_strict_calls;
	unsigned int node_lazy_calls;
	unsigned int node_curried_calls;
	struct profile_node *node_parent;
	struct profile_node_children node_children;
};

static struct profile_node *root_node;
static struct profile_node **profile_data_stack;
struct profile_node **profile_data_stack_ptr;
struct profile_node *profile_last_tail_call;
extern struct profile_node *profile_current_cost_centre;

static char system_module[]="\06\0\0\0System\0\0\0\0\0\0\0\0\0\0";
static struct profile_info init_profiler_info={0,0,"_start"};

void c_init_profiler (unsigned int ab_stack_size)
{
	profile_data_stack=profile_data_stack_ptr=safe_malloc (ab_stack_size*sizeof (struct profile_node*));
	profile_last_tail_call=NULL;

#ifdef MACH_O64
	init_profiler_info.profile_info_module=(int)((void*)&system_module-(void*)&init_profiler_info.profile_info_module);
#else
	init_profiler_info.profile_info_module=(int)(PTR_INT)&system_module;
#endif

	root_node=safe_malloc (sizeof (struct profile_node));
	root_node->node_info=&init_profiler_info;
	root_node->node_ticks=0;
	root_node->node_allocated_words=0;
	root_node->node_strict_calls=1;
	root_node->node_lazy_calls=0;
	root_node->node_curried_calls=0;
	root_node->node_parent=NULL;
	root_node->node_children.node_children_cur=NULL;
	root_node->node_children.node_children_next=NULL;
	*profile_data_stack_ptr=root_node;
	*++profile_data_stack_ptr=root_node;

	profile_current_cost_centre=root_node;
}

void c_write_profile_stack (void)
{
	int i=STACK_FRAMES;
	ew_print_string ("Stack:\n");
	for (; *profile_data_stack_ptr!=root_node; profile_data_stack_ptr--){
		if (--i<0){
			ew_print_string ("...\n");
			break;
		}
		struct profile_info *info=(*profile_data_stack_ptr)->node_info;
		struct clean_string *module_name=module_string (info);
		ew_print_text (module_name->characters,module_name->length);
		ew_print_string (": ");
		ew_print_string (info->profile_info_name);
		ew_print_char ('\n');
	}

	i=STACK_FRAMES;
	ew_print_string ("\nThe node under evaluation was created in:\n");
	for (profile_current_cost_centre=profile_current_cost_centre->node_parent;
			profile_current_cost_centre!=root_node;
			profile_current_cost_centre=profile_current_cost_centre->node_parent){
		if (--i<0){
			ew_print_string ("...\n");
			break;
		}
		struct profile_info *info=profile_current_cost_centre->node_info;
		struct clean_string *module_name=module_string (info);
		ew_print_text (module_name->characters,module_name->length);
		ew_print_string (": ");
		ew_print_string (info->profile_info_name);
		ew_print_char ('\n');
	}
}

static struct profile_info **unique_modules;
static unsigned int n_unique_modules;
static unsigned int unique_modules_ptr;

static struct profile_info **unique_cost_centres;
static unsigned int n_unique_cost_centres;
static unsigned int unique_cost_centres_ptr;

static void find_unique_modules_and_cost_centres (struct profile_node *node)
{
	struct profile_info *info=node->node_info;

	if (!info->profile_info_id){
		int *module_id_ptr=&((int*)module_string (info))[(module_string (info)->length+7)>>2];
		if (!*module_id_ptr){
			if (unique_modules_ptr==n_unique_modules){
				n_unique_modules<<=1;
				unique_modules=safe_realloc (unique_modules,n_unique_modules*sizeof (struct profile_info**));
			}
			unique_modules[unique_modules_ptr++]=info;
			*module_id_ptr=unique_modules_ptr;
		}

		if (unique_cost_centres_ptr==n_unique_cost_centres){
			n_unique_cost_centres<<=1;
			unique_cost_centres=safe_realloc (unique_cost_centres,n_unique_cost_centres*sizeof (struct profile_info*));
		}
		unique_cost_centres[unique_cost_centres_ptr++]=info;
		info->profile_info_id=unique_cost_centres_ptr;
	}

	if (node->node_children.node_children_cur){
		struct profile_node_children *children=&node->node_children;
		do {
			find_unique_modules_and_cost_centres (children->node_children_cur);
			children=children->node_children_next;
		} while (children);
	}
}

static void write_unsigned_int (unsigned INT64 n,struct file *f)
{
	do {
		char c=n & 0x7f;
		n>>=7;
		if (n)
			c|=0x80;
		file_write_char (c,f);
	} while (n);
}

static void write_profile_node (struct profile_node *node,struct file *f)
{
	struct profile_info *info=node->node_info;

	write_unsigned_int (info->profile_info_id,f);
	write_unsigned_int (node->node_ticks,f);
	write_unsigned_int (node->node_allocated_words,f);
	write_unsigned_int (node->node_tail_and_return_calls,f);
	write_unsigned_int (node->node_strict_calls,f);
	write_unsigned_int (node->node_lazy_calls,f);
	write_unsigned_int (node->node_curried_calls,f);

	if (!node->node_children.node_children_cur){
		write_unsigned_int (0,f);
		return;
	}

	unsigned int n_children=0;
	struct profile_node_children *list=&node->node_children;
	do {
		list=list->node_children_next;
		n_children++;
	} while (list);

	write_unsigned_int (n_children,f);

	list=&node->node_children;
	do {
		write_profile_node (list->node_children_cur,f);
		list=list->node_children_next;
	} while (list);
}

static void sort (unsigned int *arr,int lo,int hi)
{
	unsigned int p,temp;
	int i,j;

	if (lo>=hi)
		return;

	p=arr[lo+(hi-lo)/2];

	i=lo-1;
	j=hi+1;

	for (;;){
		do {
			i++;
		} while (arr[i]<p);
		do {
			j--;
		} while (arr[j]>p);
		if (i>=j)
			break;
		temp=arr[i];
		arr[i]=arr[j];
		arr[j]=temp;
	}

	sort (arr,lo,j);
	sort (arr,j+1,hi);
}

extern unsigned INT64 get_time_stamp_counter (void);
static inline unsigned int measure_cpu_frequency (
#ifdef WINDOWS
		unsigned INT64 pc_frequency
#else
		void
#endif
){
	unsigned INT64 ticks;

#ifdef WINDOWS
	LARGE_INTEGER before,begin,end;

	QueryPerformanceCounter (&before);
	do {
		QueryPerformanceCounter (&begin);
		ticks=get_time_stamp_counter();
	} while (begin.QuadPart==before.QuadPart);

	do {
		QueryPerformanceCounter (&end);
	} while (end.QuadPart<begin.QuadPart+FREQUENCY_N_TICKS);

	ticks=get_time_stamp_counter()-ticks;
	ticks*=pc_frequency;
	/* avoid 64-bit division on 32-bit platforms */
	ticks=(unsigned INT64)((double)ticks/(double)(end.QuadPart-begin.QuadPart));
#else
	struct timespec tspec;
	unsigned long threshold;

	do {
		clock_gettime (CLOCK_THREAD_CPUTIME_ID,&tspec);
	} while (tspec.tv_nsec>=990000000);

	ticks=get_time_stamp_counter();
	threshold=tspec.tv_nsec+10000000;

	do {
		clock_gettime (CLOCK_THREAD_CPUTIME_ID,&tspec);
	} while (tspec.tv_nsec<threshold);

	ticks=get_time_stamp_counter()-ticks;
	ticks*=100;
#endif

	return ticks;
}

static unsigned int compute_cpu_frequency (void)
{
	unsigned int frequency[FREQUENCY_SAMPLES];
	int begin,end;
	unsigned INT64 avg_frequency;

#ifdef WINDOWS
	LARGE_INTEGER pc_frequency;
	QueryPerformanceFrequency (&pc_frequency);
#endif

	for (int i=0; i<FREQUENCY_SAMPLES; i++)
		frequency[i]=measure_cpu_frequency(
#ifdef WINDOWS
				pc_frequency.QuadPart
#endif
		);

	sort (frequency,0,FREQUENCY_SAMPLES-1);

	begin=FREQUENCY_SAMPLES>>2;
	end=FREQUENCY_SAMPLES-begin;
	avg_frequency=0;
	for (int i=begin; i<end; i++)
		avg_frequency+=frequency[i];

	return (unsigned INT64)((double)avg_frequency/(double)(FREQUENCY_SAMPLES>>1));
}

extern unsigned int measure_profile_overhead (void);
static unsigned int compute_profile_overhead_1000 (void)
{
	unsigned int ticks_without_profile[OVERHEAD_SAMPLES];
	unsigned int ticks_with_profile[OVERHEAD_SAMPLES];
	struct profile_node *with_profile_cost_centre;
	int begin,end;
	int overhead;

	/* measure_profile_overhead returns the nr. of ticks in 100k iterations
	 * *without* profiling calls, and leaves a cost centre *with* profiling one
	 * space above the stack. */
	for (int i=0; i<OVERHEAD_SAMPLES; i++){
		ticks_without_profile[i]=measure_profile_overhead();
		with_profile_cost_centre=profile_data_stack_ptr[1];
		ticks_with_profile[i]=with_profile_cost_centre->node_ticks;
		with_profile_cost_centre->node_ticks=0;
	}

	/* Drop potential outliers; keep middle half of the samples */
	sort (ticks_with_profile,0,OVERHEAD_SAMPLES-1);
	sort (ticks_without_profile,0,OVERHEAD_SAMPLES-1);

	begin=OVERHEAD_SAMPLES>>2;
	end=OVERHEAD_SAMPLES-begin;
	overhead=0;
	for (int i=begin; i<end; i++){
		overhead+=ticks_with_profile[i];
		overhead-=ticks_without_profile[i];
	}

	/* Remove the association of the new cost centre as child of root_node to
	 * make sure it is not exported. */
	root_node->node_children.node_children_next=root_node->node_children.node_children_next->node_children_next;

	/* measure_profile_overhead does 200000 profile calls, so we now have the
	 * overhead of OVERHEAD_SAMPLES / 2 * 200K calls; divide by 100 *
	 * OVERHEAD_SAMPLES to get the overhead per 1000 calls. */
	return overhead<0 ? 0 : overhead/OVERHEAD_SAMPLES/100;
}

/* from scon.c */
extern void create_profile_file_name (unsigned char *profile_file_name_string);
void c_write_profile_information (void)
{
	unsigned char profile_file_name[128];
	unsigned INT64 cpu_frequency,profile_overhead_1000;

#ifdef WINDOWS
	HANDLE thread=GetCurrentThread();
	int priority=GetThreadPriority (thread);
	if (priority!=THREAD_PRIORITY_ERROR_RETURN)
		SetThreadPriority (thread,THREAD_PRIORITY_TIME_CRITICAL);
#endif
	cpu_frequency=compute_cpu_frequency();
	profile_overhead_1000=compute_profile_overhead_1000();
#ifdef WINDOWS
	if (priority!=THREAD_PRIORITY_ERROR_RETURN)
		SetThreadPriority (thread,priority);
#endif

	create_profile_file_name (profile_file_name);

	unique_modules=safe_malloc (2*sizeof (struct profile_info*));
	n_unique_modules=2;
	unique_modules_ptr=0;

	unique_cost_centres=safe_malloc (2*sizeof (int*));
	n_unique_cost_centres=2;
	unique_cost_centres_ptr=0;

	find_unique_modules_and_cost_centres (root_node);

	struct file *f=open_file ((struct clean_string*)(profile_file_name+IF_INT_64_OR_32(8,4)),4);

	file_write_characters ((unsigned char*)"prof",4,f); /* magic number */
	file_write_int (2,f); /* version */
	file_write_int (unique_modules_ptr,f);
	file_write_int (unique_cost_centres_ptr,f);
	write_unsigned_int (cpu_frequency,f);
	write_unsigned_int (profile_overhead_1000,f);

	for (int i=0; i<unique_modules_ptr; i++){
		struct clean_string *module_name=module_string (unique_modules[i]);
		file_write_characters ((unsigned char*)module_name->characters,module_name->length,f);
		file_write_char ('\0',f);
	}

	for (int i=0; i<unique_cost_centres_ptr; i++){
		int *info_module_string=(int*)module_string (unique_cost_centres[i]);
		char *name=unique_cost_centres[i]->profile_info_name;
		write_unsigned_int (info_module_string[(info_module_string[0]+7)>>2],f);
		char *name_p;
		for (name_p=name; *name_p; name_p++);
		file_write_characters ((unsigned char*)name,name_p-name,f);
		file_write_char ('\0',f);
	}

	write_profile_node (root_node,f);

	close_file (f);
}

static inline struct profile_node *push (struct profile_node *parent,int *address)
{
	struct profile_info *info=(struct profile_info*)(&address[-2]);

	if (profile_last_tail_call){
		parent=profile_last_tail_call;
		profile_last_tail_call=NULL;
	}

	if (parent->node_info==info)
		return *++profile_data_stack_ptr=parent;

	int i=0;
	for (struct profile_node *ancestor=parent->node_parent; ancestor!=NULL; ancestor=ancestor->node_parent){
		if (ancestor->node_info==info)
			return *++profile_data_stack_ptr=ancestor;
		if (++i>CYCLE_DETECTION_FRAMES)
			break;
	}

	struct profile_node *node=parent->node_children.node_children_cur;
	if (!node){
		node=safe_malloc (sizeof (struct profile_node));
		node->node_info=info;
		node->node_ticks=0;
		node->node_allocated_words=0;
		node->node_strict_calls=0;
		node->node_lazy_calls=0;
		node->node_curried_calls=0;
		node->node_parent=parent;
		node->node_children.node_children_cur=NULL;
		node->node_children.node_children_next=NULL;
		parent->node_children.node_children_cur=node;
		return *++profile_data_stack_ptr=node;
	} else if (node->node_info==info){
		return *++profile_data_stack_ptr=node;
	} else {
		struct profile_node_children *child_list=parent->node_children.node_children_next;
		for (struct profile_node_children *list=child_list; list; list=list->node_children_next)
			if (list->node_children_cur->node_info==info)
				return *++profile_data_stack_ptr=list->node_children_cur;

		struct profile_node *new_node=safe_malloc (sizeof (struct profile_node));
		new_node->node_info=info;
		new_node->node_ticks=0;
		new_node->node_allocated_words=0;
		new_node->node_strict_calls=0;
		new_node->node_lazy_calls=0;
		new_node->node_curried_calls=0;
		new_node->node_parent=parent;
		new_node->node_children.node_children_cur=NULL;
		new_node->node_children.node_children_next=NULL;

		struct profile_node_children *new_list_item=safe_malloc (sizeof (struct profile_node_children));
		new_list_item->node_children_cur=new_node;
		new_list_item->node_children_next=child_list;
		parent->node_children.node_children_next=new_list_item;

		return *++profile_data_stack_ptr=new_node;
	}
}

void c_profile_n (int *address,INT64 ticks,INT64 words,void **a0)
{
	profile_current_cost_centre->node_ticks+=ticks;
	profile_current_cost_centre->node_allocated_words+=words;

	profile_last_tail_call=NULL;

	int arity=((int*)*a0)[-1];
	if (arity<0)
		arity=2;
	struct profile_node *parent=(struct profile_node*)a0[arity & 0xff];

	push (parent,address)->node_lazy_calls++;
}

void c_profile_s (int *address,INT64 ticks,INT64 words)
{
	profile_current_cost_centre->node_ticks+=ticks;
	profile_current_cost_centre->node_allocated_words+=words;

	push (profile_current_cost_centre,address)->node_strict_calls++;
}

void c_profile_l (int *address,INT64 ticks,INT64 words)
{
	profile_current_cost_centre->node_ticks+=ticks;
	profile_current_cost_centre->node_allocated_words+=words;

	push (profile_current_cost_centre,address)->node_curried_calls++;
}
