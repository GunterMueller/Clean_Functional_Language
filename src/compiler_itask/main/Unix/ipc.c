/*
	Unix clm/cocl interface

	Ronny Wichers Schreur

*/
# include <stdio.h>
# include <stdlib.h>
# include <stdarg.h>
# include <string.h>

/*
	Clean string
	============
*/

#ifdef _WIN64
typedef struct clean_string {__int64 length; char chars [1]; } *CleanString;
#else
typedef struct clean_string {long length; char chars [1]; } *CleanString;
#endif

# define Clean(ignore)
# include "ipc.h"

#ifdef DEBUG
static void
add_to_log (char *format, ...)
{
	va_list ap;

	va_start (ap, format);
	(void) fputs("                        cocl: ", stderr);
	(void) vfprintf(stderr, format, ap);
	va_end(ap);
}
#endif

static char *
ConvertCleanString (CleanString string)
{
	int		length;
	char	*copy;

	length	= string->length;
	copy	= malloc (length+1);
	strncpy (copy, string->chars, length);
	copy [length]	= '\0';

	return (copy);
} /* ConvertCleanString */

static FILE *commands, *results;
static char *command_buffer_p=NULL;
static int command_buffer_size=0;

int open_pipes (CleanString commands_clean, CleanString results_clean)
{
	char *commands_name, *results_name;

	commands_name	= ConvertCleanString (commands_clean);
	results_name	= ConvertCleanString (results_clean);

    if ((commands = fopen(commands_name, "r")) == NULL)
    {
#ifdef DEBUG
		add_to_log("commands = %s\n",commands_name);
#endif
		perror("fopen commands");
		return -1;
    }
    if ((results = fopen(results_name, "w")) == NULL)
    {
#ifdef DEBUG
		add_to_log("results = %s\n",results_name);
#endif
		perror("fopen results");
		return -1;
    }
	return 0;
}

int get_command_length (void)
{
#ifdef DEBUG
	add_to_log ("reading command\n");
#endif

	if (command_buffer_p==NULL){
		command_buffer_p = malloc (1024);
		if (command_buffer_p==NULL)
			return -1;
		command_buffer_size=1024;
	}

	{
		int n_chars,max_n_chars,c;

		n_chars=0;
		max_n_chars=command_buffer_size-1;

		do {
			c=fgetc (commands);
			if (c==EOF)
				break;
			command_buffer_p[n_chars++]=c;
			if (n_chars==max_n_chars){
				char *new_command_buffer_p;

				new_command_buffer_p = realloc (command_buffer_p,command_buffer_size<<1);
				if (new_command_buffer_p==NULL){
					command_buffer_p[n_chars-1]='\0';
					return -1;
				}
				command_buffer_p=new_command_buffer_p;
				command_buffer_size=command_buffer_size<<1;
				max_n_chars=command_buffer_size-1;
			}
		} while (c!='\n');

		command_buffer_p[n_chars]='\0';

#ifdef DEBUG
		add_to_log ("command = %s", command_buffer_p);
#endif

		return n_chars;
	}
}

int get_command (CleanString cleanString)
{
#ifdef DEBUG
	add_to_log ("%s\n", command_buffer_p);
#endif

	strncpy (cleanString->chars, command_buffer_p, cleanString->length);
	return (0);
}

int send_result (int result)
{
	int	r;

	if (fprintf (results, "%d\n", result) > 0)
		r=0;
	else
		r=-1;
	fflush (results);

	return r;
}
