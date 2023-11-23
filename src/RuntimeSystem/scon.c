/*
	File:	scon.c
	Author:	John van Groningen
	At:		University of Nijmegen
*/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/time.h>
#ifndef MACH_O64
# include <unistd.h>
#endif

#if defined (__x86_64__) || defined (__aarch64__)
# define A64
#endif

#define GC_FLAGS
#ifndef SOLARIS
# define MARKING_GC
#endif
#if (!defined (A64) || defined (LINUX)) && !defined (ARM)
# define STACK_OVERFLOW_EXCEPTION_HANDLER
# ifndef A64
#  define USE_CR2
# endif
#else
# undef STACK_OVERFLOW_EXCEPTION_HANDLER
#endif

#ifdef STACK_OVERFLOW_EXCEPTION_HANDLER
# ifdef LINUX
#  ifndef USE_CR2
#   /* define __USE_GNU to define REG_RIP and REG_RSP */
#   ifdef __USE_GNU
#    include <ucontext.h>
#   else
#    define __USE_GNU
#    include <ucontext.h>
#    undef __USE_GNU
#   endif
#  endif
#  include <sys/resource.h>
# endif
# include <signal.h>
# ifdef SOLARIS
#  include <ucontext.h>
#  include <procfs.h>
# endif
# include <fcntl.h>
# include <sys/mman.h>
#endif

#ifdef MACH_O64
# include <mach-o/dyld.h>
#endif

long min_write_heap_size;

#ifndef SOLARIS
# include <limits.h>
# define MY_PATH_MAX PATH_MAX
#else
# define MY_PATH_MAX 1025
#endif

char appl_path[MY_PATH_MAX];
char home_path[MY_PATH_MAX];

void set_home_and_appl_path (char *command)
{
	char *p;
	int r;

	realpath (getenv ("HOME"),home_path);

#if 1
# ifdef SOLARIS
	p=getexecname();
	if (p!=NULL){
		realpath (p,appl_path);
		*strrchr (appl_path,'/')='\0';
	} else
		appl_path[0]='\0';
# else
#  ifndef MACH_O64
	r=readlink ("/proc/self/exe",appl_path,MY_PATH_MAX-1);
	if (r>=0){
		appl_path[r]='\0';
		
		p=strrchr (appl_path,'/');
		if (p!=NULL)
			*p='\0';
	} else
		appl_path[0]='\0';
#  else
	{
		uint32_t buf_size;
		char exec_path[MY_PATH_MAX];

		buf_size=MY_PATH_MAX;
		r=_NSGetExecutablePath (exec_path,&buf_size);
		if (r==0){
			realpath (exec_path,appl_path);
			*strrchr (appl_path,'/')='\0';
		} else
			appl_path[0]='\0';
	}
#  endif
# endif
#else
	p=strchr (command,'/');
  
	if (p!=NULL){
		realpath (command,appl_path);
		*strrchr (appl_path,'/')='\0';
	} else {
		char *path,*file_found_p;
		int colon_i;

		path=(char *)getenv("PATH");

		file_found_p=NULL;

		while (path!=NULL && file_found_p==NULL){
			char *next,try_path[MY_PATH_MAX];
			
			next=strchr (path,':');
			if (next==NULL)
				colon_i=strlen(path);
			else
				colon_i=next-path;

			strncpy (try_path,path,colon_i);
			try_path[colon_i]='\0';
			
			strcat (try_path,"/");
			strcat (try_path,command);
			
			file_found_p=(char *)realpath (try_path,appl_path);

			path=next;
			if (path!=NULL)
				++path;
		}

		if (file_found_p==NULL)
			*appl_path='\0';
		else
			*strrchr(appl_path,'/')='\0';
	}
#endif
}

#if defined (SOLARIS) || defined (I486) || defined (ARM)
# if defined (ARM) && defined (PIC)
__attribute__ ((visibility("hidden")))
# endif
extern long ab_stack_size,heap_size,flags;
#else
extern long stack_size,heap_size,flags;
#endif

/*
extern long ab_stack_size=512*1024,heap_size=2048*1024,flags=8;
*/
#ifdef MARKING_GC
# if defined (ARM) && defined (PIC)
__attribute__ ((visibility("hidden")))
# endif
extern long heap_size_multiple,initial_heap_size;
#endif

#ifdef STACK_OVERFLOW_EXCEPTION_HANDLER
struct sigaction old_sa;

extern int stack_overflow (void);
extern int *halt_sp;

# ifdef LINUX
extern int *a_stack_guard_page;
int *below_stack_page;

void *allocate_memory_with_guard_page_at_end (int size)
{
	int alloc_size;
	char *p,*end_p;
	
	alloc_size=(size+4096+4095) & -4096;
	
	p=malloc (alloc_size);
	if (p==NULL)
		return p;

	end_p=(char*)(((size_t)p+size+4095) & -4096);
	mprotect (end_p,4096,PROT_NONE);

	return p;
}

# ifdef USE_CR2
static void clean_exception_handler (int s,volatile struct sigcontext sigcontext)
{
	if (
		(((size_t)sigcontext.cr2 ^ (size_t)below_stack_page) & -4096)==0 ||
		(((size_t)sigcontext.cr2 ^ (size_t)a_stack_guard_page) & -4096)==0)
	{
#  ifdef A64
		sigcontext.rip=(size_t)&stack_overflow;
		sigcontext.rsp=(size_t)halt_sp;
#  else
		sigcontext.eip=(int)&stack_overflow;
		sigcontext.esp=(int)halt_sp;
#  endif
	} else {
		sigaction (SIGSEGV,&old_sa,NULL);
		/*
		if (old_sa.sa_handler==SIG_DFL || old_sa.sa_handler==SIG_IGN)
			sigaction (SIGSEGV,&old_sa,NULL);
		else
			old_sa.sa_sigaction (s,sigcontext);
		*/
	}
}
# else
static void clean_exception_handler_info (int s,siginfo_t *siginfo_p,void *p)
{
	struct sigaction sa;

	if (
		(((long)siginfo_p->si_addr ^ (long)below_stack_page) & -4096)==0 ||
		(((long)siginfo_p->si_addr ^ (long)a_stack_guard_page) & -4096)==0)
	{
		/* REG_RIP and REG_RSP from /usr/include/x86_64-linux-gnu/sys/ucontext.h */
		((ucontext_t*)p)->uc_mcontext.gregs[REG_RIP/*16*/]=(size_t)&stack_overflow;
		((ucontext_t*)p)->uc_mcontext.gregs[REG_RSP/*15*/]=(size_t)halt_sp;
	} else {
		if (old_sa.sa_handler==SIG_DFL || old_sa.sa_handler==SIG_IGN)
			sigaction (SIGSEGV,&old_sa,NULL);
		else
			old_sa.sa_sigaction (s,siginfo_p,p);
	}
}
# endif

static void install_clean_exception_handler (void)
{
	char proc_map_file_name[64];
	int proc_map_fd,a;
	struct sigaction sa;
	stack_t sig_s;
	int *sig_stack;

	sprintf (proc_map_file_name,"/proc/%d/maps",getpid());

	proc_map_fd=open (proc_map_file_name,O_RDONLY);

	if (proc_map_fd<0)
		return;

	for (;;){
#ifndef A64
		static char m[17];
#else
		static char m[33];
#endif
		unsigned long b,e;
		int n_hex_digits;
		
		n_hex_digits=0;

		if (read (proc_map_fd,m,17)==17){
			if (m[8]=='-')
				n_hex_digits=8;
#ifdef A64
			else if (m[12]=='-'){
				if (read (proc_map_fd,&m[17],8)==8)
					n_hex_digits=12;			
			} else if (m[16]=='-'){
				if (read (proc_map_fd,&m[17],16)==16)
					n_hex_digits=16;
			}
#endif
		}
		
		if (n_hex_digits!=0){
			int i;
	
			b=0;
			e=0;
			for (i=0; i<n_hex_digits; ++i){
				int c;
				
				c=m[i];
				b=b<<4;
				if ((unsigned)(c-'0')<10)
					b+=c-'0';
				else if ((unsigned)((c & ~32)-'A')<26)
					b+=(c & ~32)-('A'-10);
				else
					break;

				c=m[n_hex_digits+1+i];
				e=e<<4;
				if ((unsigned)(c-'0')<10)
					e+=c-'0';
				else if ((unsigned)((c & ~32)-'A')<26)
					e+=(c & ~32)-('A'-10);
				else
					break;
			}

			if (i==n_hex_digits){
				if ((size_t)&a - (size_t)b < (size_t)(e-b)){
					struct rlimit rlimit;
					
					if (getrlimit (RLIMIT_STACK,&rlimit)==0){
						below_stack_page=(int*)((long)e-rlimit.rlim_cur-4096);					
						break;
					}
				}
			}
		}

		{
			char c;
			
			c='\0';
			while (read (proc_map_fd,&c,1)==1 && c!='\n')
				;
			
			if (c=='\n')
				continue;
		}

		close (proc_map_fd);
		return;		
	}

	close (proc_map_fd);

	sig_stack=malloc (MINSIGSTKSZ);

	if (sig_stack==NULL)
		return;

	sig_s.ss_flags=0;
	sig_s.ss_size=MINSIGSTKSZ;
	sig_s.ss_sp=sig_stack;

	sigaltstack (&sig_s,NULL);

	sigemptyset (&sa.sa_mask);
# ifdef USE_CR2
	sa.sa_sigaction=&clean_exception_handler;
	sa.sa_flags= SA_ONSTACK | SA_RESTART;
# else
	sa.sa_sigaction=&clean_exception_handler_info;
	sa.sa_flags= SA_ONSTACK | SA_RESTART | SA_SIGINFO;
# endif

	sigaction (SIGSEGV,&sa,&old_sa);
}
# else
#  ifdef DETECT_SYSTEM_STACK_OVERFLOW
int *below_stack_page;
#  endif
int *stack_guard_page;

void *allocate_stack (int size)
{
	int alloc_size,size_a8192;
	char *p,*end_p;
	
	size=(size+3) & -4;
	size_a8192=(size+8191) & -8192;
	alloc_size=8192+(size_a8192<<1)+8192;
	
	p=malloc (alloc_size);
	if (p==NULL)
		return NULL;

	end_p=(char*)(((int)p+size+8191) & -8192);

	mprotect (end_p,8192,PROT_NONE);

	stack_guard_page=(int*)end_p;
	
	return (void*)stack_guard_page;
}

void clean_exception_handler (int s,struct siginfo *siginfo_p,ucontext_t *ucontext_p)
{
	struct sigaction sa;
	mcontext_t *mcontext_p;
	
	if (
#  ifdef DETECT_SYSTEM_STACK_OVERFLOW
		(((int)siginfo_p->si_addr ^ (int)below_stack_page) & -8192)==0 ||
#  endif
		(((int)siginfo_p->si_addr ^ (int)stack_guard_page) & -8192)==0)
	{
		mcontext_p=&ucontext_p->uc_mcontext;
#  ifdef DETECT_SYSTEM_STACK_OVERFLOW
		if (mcontext_p->gwins!=NULL){
			int wi,wo,n_windows;

			n_windows=mcontext_p->gwins->wbcnt;
			wo=0;
			for (wi=0; wi<n_windows; ++wi){
				int *register_window_p;

				register_window_p=mcontext_p->gwins->spbuf[wi];
				if (((((int)register_window_p ^ (int)below_stack_page)) & -8192) != 0){
					/*
					struct rwindow *rwindow_p;
					int i;

					rwindow_p=&mcontext_p->gwins->wbuf[wi];
					for (i=0; i<8; ++i){
						register_window_p[i]=rwindow_p->rw_local[i];
						register_window_p[8+i]=rwindow_p->rw_in[i];
					}
					*/
					if (wi!=wo)
						mcontext_p->gwins->wbuf[wo]=mcontext_p->gwins->wbuf[wi];
					++wo;
				}
			}
			mcontext_p->gwins->wbcnt=wo;
		}
#  endif

		mcontext_p->gregs[REG_PC]=(int)&stack_overflow;
		mcontext_p->gregs[REG_nPC]=(int)&stack_overflow+4;
		mcontext_p->gregs[REG_G5]=(int)halt_sp;
	} else {
		if (old_sa.sa_sigaction==SIG_DFL || old_sa.sa_sigaction==SIG_IGN)
			sigaction (SIGSEGV,&old_sa,NULL);
		else
			old_sa.sa_sigaction (s,siginfo_p,ucontext_p);
	}
}

static void install_clean_exception_handler (void)
{
	struct sigaction sa;
#  ifdef DETECT_SYSTEM_STACK_OVERFLOW
	char proc_map_file_name[64];
	struct prmap prmap;
	stack_t sig_s;
	int proc_map_fd,a,*sig_stack;

	sprintf (proc_map_file_name,"/proc/%d/rmap",getpid());

	proc_map_fd=open (proc_map_file_name,O_RDONLY);

	if (proc_map_fd<0)
		return;

	do {
		if (read (proc_map_fd,&prmap,sizeof (prmap))!=sizeof (prmap)){
			close (proc_map_fd);
			return;
		}
	} while (! ((unsigned)&a - (unsigned)prmap.pr_vaddr < (unsigned)prmap.pr_size));

	close (proc_map_fd);

	below_stack_page=(int*)((int)prmap.pr_vaddr-8192);

	sig_stack=malloc (MINSIGSTKSZ);

	if (sig_stack==NULL)
		return;

	sig_s.ss_flags=0;
	sig_s.ss_size=MINSIGSTKSZ;
	sig_s.ss_sp=sig_stack;

	sigaltstack (&sig_s,NULL);
#  endif

	sigemptyset (&sa.sa_mask);
	sa.sa_sigaction=&clean_exception_handler;
#  ifdef DETECT_SYSTEM_STACK_OVERFLOW
	sa.sa_flags= SA_ONSTACK | SA_RESTART | SA_SIGINFO;
#  else
	sa.sa_flags= SA_RESTART | SA_SIGINFO;
#  endif

	sigaction (SIGSEGV,&sa,&old_sa);
}
# endif
#endif

void w_print_char (char c)
{	
	putchar (c);
}

void w_print_text (char *s,unsigned long length)
{
	if (length)
		fwrite (s,1,length,stdout);
}

void ew_print_char (char c)
{
	putc (c,stderr);
}

void ew_print_text (char *s,unsigned long length)
{
	if (length)
		fwrite (s,1,length,stderr);
}

int w_get_char()
{
	return getchar();
}

#define is_digit(n) ((unsigned)((n)-'0')<(unsigned)10)

#ifdef A64
int w_get_int (long *i_p)
#else
int w_get_int (int *i_p)
#endif
{
	int c,negative;
#ifdef A64
	unsigned long i;
#else
	unsigned int i;
#endif

	flockfile (stdin);
	
	c=getchar_unlocked();
	while (c==' ' || c=='\t' || c=='\n')
		c=getchar_unlocked();
	
	negative=0;
	if (c=='+')
		c=getchar_unlocked();
	else
		if (c=='-'){
			c=getchar_unlocked();
			negative=1;
		}
	
	if (!is_digit (c)){
		funlockfile (stdin);

		if (c!=EOF)
			ungetc (c,stdin);

		*i_p=0;
		return 0;
	}
	
	i=c-'0';
	while (c=getchar_unlocked(),is_digit (c)){
		i+=i<<2;
		i+=i;
		i+=c-'0';
	};

	if (negative)
		i=-i;

	funlockfile (stdin);

	if (c!=EOF)
		ungetc (c,stdin);

	*i_p=i;
	return -1;
}

int w_get_real (double *r_p)
{
	char s[256+1];
	int c,dot,digits,result,n;
	
	n=0;

	flockfile (stdin);
	
	c=getchar_unlocked();
	while (c==' ' || c=='\t' || c=='\n')
		c=getchar_unlocked();
	
	if (c=='+')
		c=getchar_unlocked();
	else
		if (c=='-'){
			s[n++]=c;
			c=getchar_unlocked();
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
		c=getchar_unlocked();
	}

	result=0;
	if (digits)
		if (dot==2 || ! (c=='e' || c=='E'))
			result=-1;
		else {
			if (n<256)
				s[n++]=c;
			c=getchar_unlocked();
			
			if (c=='+')
				c=getchar_unlocked();
			else
				if (c=='-'){
					if (n<256)
						s[n++]=c;
					c=getchar_unlocked();
				}
			
			if (is_digit (c)){
				do {
					if (n<256)
						s[n++]=c;
					c=getchar_unlocked();
				} while (is_digit (c));

				result=-1;
			}
		}

	if (n>=256)
		result=0;

	if (c!=EOF)
		ungetc (c,stdin);

	*r_p=0.0;
	
	if (result){
		s[n]='\0';
		*r_p=atof (s);
	}
	
	return result;
}

unsigned long w_get_text (register char *string,unsigned long max_length)
{
	register int length;
	
	fgets (string,(int)max_length,stdin);
	
	for (length=0; length<max_length; ++length)
		if (string[length]=='\0')
			break;
	
	return length;
}

void w_print_string (char *s)
{
	fputs (s,stdout);
}

void ew_print_string (char *s)
{
	fputs (s,stderr);
}

#ifdef A64
void w_print_int (long n)
{
	printf ("%ld",n);
}

void ew_print_int (long n)
{
	fprintf (stderr,"%ld",n);
}
#else
void w_print_int (int n)
{
	printf ("%d",n);
}

void ew_print_int (int n)
{
	fprintf (stderr,"%d",n);
}
#endif

void w_print_real (double r)
{
	printf ("%.15g",r);
}

void ew_print_real (double r)
{
	fprintf (stderr,"%.15g",r);
}

static long parse_size (register char *s)
{
	register int c;
	register long n;
	
	c=*s++;
	if (c<'0' || c>'9'){
		printf ("Digit expected in argument\n");
		exit (-1);
	}
	
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
	
	if (c!='\0'){
		printf ("Error in argument\n");
		exit (-1);
	}
	
	return n;
}

#ifdef MARKING_GC
static long parse_integer (register char *s)
{
	register int c;
	register long n;

	c=*s++;
	if (c<'0' || c>'9'){
		printf ("Digit expected in argument\n");
		exit (-1);
	}

	n=c-'0';

	while (c=*s++,c>='0' && c<='9')
		n=n*10+(c-'0');

	if (c!='\0'){
		printf ("Error in integer");
		exit (-1);
	}
	
	return n;
}
#endif

#ifdef PIC
__attribute__ ((visibility("default")))
#endif
int global_argc;
#ifdef PIC
__attribute__ ((visibility("default")))
#endif
char **global_argv;

#ifdef TIME_PROFILE
# ifdef PROFILE_GRAPH
char time_profile_file_name_suffix[]=".pgcl";
# else
char time_profile_file_name_suffix[]=" Time Profile.pcl";
# endif

void create_profile_file_name (unsigned char *profile_file_name_string)
{
	char *profile_file_name;
	int r;

	profile_file_name=&profile_file_name_string[2*sizeof(size_t)];

# ifndef MACH_O64
	r=readlink ("/proc/self/exe",profile_file_name,MY_PATH_MAX-1);
	if (r>=0){
		int length_file_name,size_time_profile_file_name_suffix;

		profile_file_name[r]='\0';

		size_time_profile_file_name_suffix=sizeof (time_profile_file_name_suffix);
		length_file_name=0;
        while (profile_file_name[length_file_name]!='\0')
			++length_file_name;

		if (length_file_name+size_time_profile_file_name_suffix>MY_PATH_MAX)
			length_file_name=MY_PATH_MAX-size_time_profile_file_name_suffix;

		strcat (&profile_file_name[length_file_name],time_profile_file_name_suffix);
		*(size_t*)&profile_file_name_string[sizeof(size_t)] = length_file_name+size_time_profile_file_name_suffix-1;
	} else {
		strcpy (profile_file_name,&time_profile_file_name_suffix[1]);
		*(size_t*)&profile_file_name_string[sizeof(size_t)] = sizeof (time_profile_file_name_suffix)-1;
    }
# else
	{
		uint32_t buf_size;
		char exec_path[MY_PATH_MAX];

		buf_size=MY_PATH_MAX;
		r=_NSGetExecutablePath (exec_path,&buf_size);
		if (r==0){
		    int length_file_name,size_time_profile_file_name_suffix;

			realpath (exec_path,profile_file_name);

			size_time_profile_file_name_suffix=sizeof (time_profile_file_name_suffix);
			length_file_name=0;
			while (profile_file_name[length_file_name]!='\0')
				++length_file_name;

			if (length_file_name+size_time_profile_file_name_suffix>MY_PATH_MAX)
				length_file_name=MY_PATH_MAX-size_time_profile_file_name_suffix;

			strcat (&profile_file_name[length_file_name],time_profile_file_name_suffix);
			*(size_t*)&profile_file_name_string[sizeof(size_t)] = length_file_name+size_time_profile_file_name_suffix-1;
		} else {
			profile_file_name[0]='\0';

			strcpy (profile_file_name,&time_profile_file_name_suffix[1]);
			*(size_t*)&profile_file_name_string[sizeof(size_t)] = sizeof (time_profile_file_name_suffix)-1;
		}
	}
# endif
}
#endif

int execution_aborted;
int return_code;

int main (int argc,char **argv)
{
	int arg_n;

	execution_aborted=0;
	return_code=0;

#ifdef STACK_OVERFLOW_EXCEPTION_HANDLER
	install_clean_exception_handler();
#endif
	
	set_home_and_appl_path (argv[0]);

	arg_n=1;	
	if ((flags & 8192)==0)
		for (; arg_n<argc; ++arg_n){
			char *s;
			
			s=argv[arg_n];
			if (*s!='-')
				break;

			++s;
			if (!strcmp (s,"h")){
				++arg_n;
				if (arg_n>=argc){
					printf ("Heapsize missing\n");
					return -1;
				}
				heap_size=parse_size (argv[arg_n]);
			} else if (!strcmp (s,"s")){
				++arg_n;
				if (arg_n>=argc){
					printf ("Stacksize missing\n");
					return -1;
				}
#if defined (SOLARIS) || defined (I486) || defined (ARM)
				ab_stack_size=parse_size (argv[arg_n]);
#else
				stack_size=parse_size (argv[arg_n]);
#endif
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
#ifdef MARKING_GC
			else if (!strcmp (s,"gcm"))
				flags |= 64;
			else if (!strcmp (s,"gcc"))
				flags &= ~64;
			else if (!strcmp (s,"gci")){
				++arg_n;
				if (arg_n>=argc){
					printf ("Initial heap size missing\n");
					exit (-1);
				}
				initial_heap_size=parse_size (argv[arg_n]);
			} else if (!strcmp (s,"gcf")){
				++arg_n;
				if (arg_n>=argc){
					printf ("Next heap size factor missing\n");
					exit (-1);
				}
				heap_size_multiple=parse_integer (argv[arg_n])<<8;
			}	
#endif
			else
				break;
		}

	--arg_n;
	argv[arg_n]=argv[0];
	global_argv=&argv[arg_n];
	global_argc=argc-arg_n;

	abc_main();

	if (return_code==0 && execution_aborted!=0)
		return_code= -1;

	return return_code;
}
