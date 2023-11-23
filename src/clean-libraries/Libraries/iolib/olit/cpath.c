/* 
  This module implements the interface to the to the global variables
  'appl_path' and 'home_path' that contain the full pathname of the
  current application and the home directory of the user. These globals
  are set by the startup code.
*/

#include <stdio.h>

typedef struct clean_string
{
    int length;
	    char    characters[0];
} *CLEAN_STRING;

extern char appl_path[];
extern char home_path[];

extern CLEAN_STRING cleanstring ();

CLEAN_STRING get_appl_path ()
{
/*	fprintf (stderr,"%s\n",appl_path); */
	
	return cleanstring (appl_path);
}

CLEAN_STRING get_home_path ()
{
/*	fprintf (stderr,"%s\n",home_path); */
	
	return cleanstring (home_path);
}
