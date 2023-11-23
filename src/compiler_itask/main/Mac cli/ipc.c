/*
	Unix clm/cocl interface

	Ronny Wichers Schreur

*/
# include <stdio.h>
# include <stdlib.h>
# include <stdarg.h>
# include <strings.h>

/*
	Clean string
	============
*/
typedef struct clean_string {int length; char chars [1]; } *CleanString;

# define Clean(ignore)
# include "ipc.h"

static void
log (char *format, ...)
{
#ifdef DEBUG
	va_list ap;

	va_start (ap, format);
	(void) fputs("                        cocl: ", stderr);
	(void) vfprintf(stderr, format, ap);
	va_end(ap);
#else /* ifndef DEBUG */
#endif
}

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
# define COMMAND_BUFFER_SIZE 1024
static char command_buffer[COMMAND_BUFFER_SIZE];

static void
crash (void)
{
	int	*p;

	p	= NULL;
	log ("crashing\n");
	*p	= 0;
} /* crash */

static void
hang (void)
{
	log ("hanging\n");
	for (;;)
		;
} /* hang */

int open_pipes (CleanString commands_clean, CleanString results_clean)
{
	char *commands_name, *results_name;

	commands_name	= ConvertCleanString (commands_clean);
	results_name	= ConvertCleanString (results_clean);

    if ((commands = fopen(commands_name, "r")) == NULL)
    {
		log("commands = %s\n",commands_name);
		perror("fopen commands");
		return -1;
    }
    if ((results = fopen(results_name, "w")) == NULL)
    {
		log("results = %s\n",results_name);
		perror("fopen results");
		return -1;
    }
	return 0;
}

int get_command_length (void)
{
	log ("reading command\n");
	if (fgets (command_buffer, COMMAND_BUFFER_SIZE, commands) == NULL)
		return -1;
	else	
	{
		log ("command = %s", command_buffer);
		return (strlen (command_buffer));
	}
}

int get_command (CleanString cleanString)
{
	log ("%s\n", command_buffer);
	strncpy (cleanString->chars, command_buffer, cleanString->length);
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
