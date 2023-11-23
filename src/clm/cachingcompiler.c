/*
	File:		cachingcompiler.c
	Written by: Ronny Wichers Schreur
	At:			University of Nijmegen
*/

#include "Clean.h"
#include "cachingcompiler.h"
#include <stdlib.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>

#if defined(I486) || defined (SOLARIS) || defined (LINUX)
#	include <unistd.h>
#endif

#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>

#ifdef DEBUG
static void log_error (char *format, ...)
{
	va_list ap;

	va_start(ap, format);
	(void) vfprintf(stderr, format, ap);
	va_end(ap);
	fflush (stderr);
}
#else
# define log_error(...)
#endif

static int wait_for_child (pid_t pid, char *child_name, int *status_p)
{
    int result, stat;
	pid_t	return_pid;

	return_pid = waitpid (pid, &stat, 0);

	if (return_pid == -1)
		/* child exited before call to waitpid */
		return 0;

	if (return_pid != pid)
	{
		fprintf (stderr, "wait_for_child: unexpected pid result (%d)\n", (int) return_pid);
		exit (1);
	}

	*status_p=stat;
	result = WEXITSTATUS (stat);

#ifdef DEBUG
	if (WIFSIGNALED(stat) != 0)
       	log_error ("%s signaled (%d)\n",child_name, (int) WTERMSIG(stat));
	else if (WIFEXITED (stat))
		log_error ("%s exited normally (%d)\n", child_name, (int) WEXITSTATUS(stat));
	else
       	log_error ("%s exited abnormally (%d)\n",child_name, (int) result);
#endif

	return result;
}

static void error (char *error_string)
{
	fprintf (stderr,"%s\n",error_string);
}

static int compiler_initialised=0;
static pid_t compiler_pid=0;
static char *compiler_commands_name=NULL, *compiler_results_name=NULL;
static FILE *compiler_commands, *compiler_results;

int stop_caching_compiler (void)
{
	int r,status;

	log_error ("stop_caching_compiler\n");
	if (compiler_pid != 0) {
		pid_t	pid;

		pid	= compiler_pid;
		compiler_pid = 0;

		log_error ("stop_caching_compiler: compiler running\n");

		fputs ("quit\n", compiler_commands);
		fflush (compiler_commands);

		r=wait_for_child (pid, "Clean compiler",&status);
		if (r!=0){
			log_error ("r=%d	status=%xd\n", r, status);
			error ("clm: error after stopping compiler");
			exit (1);
		}
	}
	return 0;
}

static void cleanup_compiler (void)
{
	log_error ("cleanup_compiler\n");
	stop_caching_compiler ();

	if (compiler_commands_name != NULL){
		log_error ("cleanup_compiler: unlink commands\n");
		if (unlink (compiler_commands_name) != 0)
			perror ("clm: unlink compiler commands pipe");
		compiler_commands_name = NULL;
	}

	if (compiler_results_name != NULL){
		log_error ("cleanup_compiler: unlink results\n");
		if (unlink (compiler_results_name) != 0)
			perror ("clm: unlink compiler results pipe");
		compiler_results_name = NULL;
	}
}

static void cleanup_compiler_at_exit (void)
{
	log_error ("cleanup_compiler_on_exit\n");
	cleanup_compiler ();
}

/*
static void cleanup_compiler_on_signal (int signal_no)
{
	log_error ("cleanup_compiler_on_signal\n");
	cleanup_compiler ();
}

static void child_died (int signal_no)
{
	log_error ("child_died\n");
	if (compiler_pid != 0){
		log_error ("cocl exited abnormally\n");
		compiler_pid=0;
	}
}
*/

static void init_caching_compiler(void)
{
	log_error ("init_caching_compiler\n");
	if (atexit (cleanup_compiler_at_exit) != 0)
	{
		perror("clm: atexit install cleanup routine");
		exit(1);
	}

/*
	if (signal (SIGCHLD, child_died) == SIG_ERR)
	{
		perror("clm: signal install child died routine");
		exit(1);
	}

	if (signal (SIGINT, cleanup_compiler_on_signal) == SIG_ERR)
	{
		perror("clm: signal install cleanup routine");
		exit(1);
	}
*/
	compiler_initialised=1;
}

/* last cocl_argv[1..n_args] contain the n_args args, cocl_argv_size = n_args+5 */
int start_caching_compiler_with_args (CleanCharArray cocl_path,char *cocl_argv[],int cocl_argv_size)
{
	log_error ("start_caching_compiler\n");

	if (compiler_pid != 0)
		return 0;

	if (!compiler_initialised)
		init_caching_compiler ();

	if (compiler_commands_name == NULL)
	{
#if 1
		static char compiler_commands_file_name[]="/tmp/comXXXXXX";
		int fd;
		
		fd=mkstemp (compiler_commands_file_name);
		if (fd<0){
			perror ("clm: mkstemp failed");
		}
		close (fd);
		unlink (compiler_commands_file_name);
		compiler_commands_name=compiler_commands_file_name;
#else
		compiler_commands_name=tempnam (NULL, "com");
#endif
		if (mkfifo(compiler_commands_name, S_IRUSR | S_IWUSR)) {
			perror("clm: mkfifo compiler commands pipe");
			compiler_commands_name=NULL;
			exit(1);
		}
	}

	if (compiler_results_name == NULL)
	{
#if 1
		static char compiler_results_file_name[]="/tmp/resXXXXXX";
		int fd;
		
		fd=mkstemp (compiler_results_file_name);
		if (fd<0){
			perror ("clm: mkstemp failed");
		}
		close (fd);
		unlink (compiler_results_file_name);
		compiler_results_name=compiler_results_file_name;
#else
		compiler_results_name=tempnam (NULL, "res");
#endif
		if (mkfifo(compiler_results_name, S_IRUSR | S_IWUSR)) {
			perror("clm: mkfifo compiler results pipe");
			compiler_results_name=NULL;
			exit(1);
		}
	}

	compiler_pid=fork();
	if (compiler_pid<0)
		error ("Fork failed");
	if (compiler_pid==0){
		if (cocl_argv==NULL || cocl_argv_size<5)
			execlp ((char *)cocl_path, "cocl", "--pipe", compiler_commands_name,
				compiler_results_name, (char *) 0);
		else {
			cocl_argv[0]="cocl";
			cocl_argv[cocl_argv_size-4]="--pipe";
			cocl_argv[cocl_argv_size-3]=compiler_commands_name;
			cocl_argv[cocl_argv_size-2]=compiler_results_name;
			cocl_argv[cocl_argv_size-1]=(char *)0;
			execvp ((char *)cocl_path,cocl_argv);
		}
		
		log_error ("cocl path = %s\n", cocl_path);
		perror ("clm: can't start the clean compiler");
		exit(1);
	}

	do
		compiler_commands=fopen (compiler_commands_name, "w");
	while (compiler_commands==NULL && errno==EINTR);

	if (compiler_commands==NULL){
		perror("clm: fopen compiler commands pipe");
		exit(1);
	}

	do
		compiler_results=fopen (compiler_results_name, "r");
	while (compiler_results==NULL && errno==EINTR);

	if (compiler_results==NULL){
		perror("clm: fopen compiler commands pipe");
		exit(1);
	}

	return (0);	
}

int start_caching_compiler (CleanCharArray cocl_path)
{
	return start_caching_compiler_with_args (cocl_path,NULL,0);
}

#define RESULT_SIZE (sizeof (int)+2)

int call_caching_compiler (CleanCharArray args)
{
	int r;
	char result_string[RESULT_SIZE], *end;
#if defined (LINUX)
	void (*oldhandler)(int);

	oldhandler = signal (SIGALRM, SIG_IGN);
#endif

	log_error ("call_caching_compiler\n");

	if (compiler_pid == 0)
		error ("call_compiler: compiler not running");
	
	fputs ((const char *) args,compiler_commands);
	fputc ('\n',compiler_commands);
	fflush (compiler_commands);

	if (fgets(result_string,RESULT_SIZE,compiler_results) == NULL){
		perror ("clm: reading compiler result failed");
/*		exit (1); */
#if defined (LINUX)
		(void) signal (SIGALRM, oldhandler);
#endif
		return 0;
	}

	r=(int)strtol (result_string,&end,0);
	if (*end != '\n'){
		perror ("clm: non integer compiler result");
		exit (1);
	}

/* FIXME, clm/CleanIDE don't correspond
	return r>=0; */
#if defined (LINUX)
	(void) signal (SIGALRM, oldhandler);
#endif

	return r;
}
