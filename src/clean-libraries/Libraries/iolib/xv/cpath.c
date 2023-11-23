/*
  This module implements the interface to the to the global variables
  'appl_path' and 'home_path' that contain the full pathname of the
  current application and the home directory of the user. These globals
  are set by the startup code.
*/

#include <stdio.h>
#include "interface.h"
#include "ckernel.h"

extern char appl_path[];
extern char home_path[];

CLEAN_STRING
get_appl_path (int dummy)
{
  return cleanstring (appl_path);
}

CLEAN_STRING
get_home_path (int dummy)
{
  return cleanstring (home_path);
}
