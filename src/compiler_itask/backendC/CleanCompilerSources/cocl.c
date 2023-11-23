
#include "compiledefines.h"
#include "types.t"
#include "system.h"
#include "comsupport.h"
#include "settings.h"
#include <ctype.h>

#ifdef NO_CLIB
# define isdigit clean_compiler_isdigit
#endif

#ifndef CLEAN_FILE_IO
# if defined (_MSC_VER) || defined (_SUN_)
FILE *std_out_file_p,*std_error_file_p;
# endif
#endif

static Bool GetInt (char *s, int *i)
{
	int j;
	char *cp;
	
	for (j = 0, cp = s; *cp; cp++)
	{	if (!isdigit (*cp))
			return False;
		
		j = (10 * j) + (*cp - '0');
	}
	*i = j;
	return True;
}

static Bool SetStrictOption (char *opt)
{	int i;

	if (strcmp (opt, "w") == 0)
		DoStrictWarning = False;
	else if (strcmp (opt, "wa") == 0)
		DoStrictAllWarning = True;
	else if (strcmp (opt, "c") == 0)
		DoStrictCheck = True;
	else if (strcmp (opt, "sa") == 0)
		StrictDoAnnots = True;
	else if (opt[0] == 'd')
	{	if (GetInt (opt+1, &i))
			StrictDepth = i;
		else
			return False;
	}
	else
		return False;

	return True;
}

#ifdef _SUN_
int use_clean_system_files;
#endif

#ifdef CLEAN2
int StdOutReopened,StdErrorReopened;
#endif

#if defined (_MAC_) && defined (GNU_C)
extern char *convert_file_name (char *file_name,char *buffer);

static FILE *freopen_with_file_name_conversion (char *file_name,char *mode,FILE *file_p)
{
	char buffer[512+1];

	file_name=convert_file_name (file_name,buffer);
	if (file_name==NULL)
		return NULL;

	return freopen (file_name,mode,file_p);
}

# define freopen freopen_with_file_name_conversion
#endif

int ParseCommandArgs (int argc, char **argv)
{
	int i;

#ifndef CLEAN_FILE_IO
# if defined (_MSC_VER) || defined (_SUN_)
	std_out_file_p = stdout;
	std_error_file_p = stderr;
# endif
#endif

#ifdef _SUN_
	use_clean_system_files=0;
#endif
	
	DoWarning 				= True;
	DoCode					= True;
	DoDebug 				= False;
	DoStrictnessAnalysis	= True;
	DoStackLayout			= True /* False */;
	DoParallel				= False;
	DoShowAttributes		= True;
	DoListTypes				= False;
	DoListAllTypes			= False;
	DoListStrictTypes		= False;

	DoStrictCheck			= False;
	DoStrictWarning			= True;
	DoStrictAllWarning		= False;

	DoProfiling=False;
	DoTimeProfiling=False;
	DoCallGraphProfiling=False;
	DoReuseUniqueNodes=False;
	DoFusion=False;
	DoGenericFusion=False;
	DoDescriptors=False;
	ExportLocalLabels=False;
	AddStrictnessToExportedFunctionTypes=False;
#ifdef NO_OPTIMIZE_INSTANCE_CALLS
	OptimizeInstanceCalls=False;
#endif
	Dynamics=False;
	TclFile=False;

	StrictDoAnnots			= False;
	StrictDepth				= 10;/* 8; */

	FunctionMayFailWarningOrError = 0;

#ifdef CLEAN2
	StdErrorReopened	= False;
	StdOutReopened		= False;
#endif

	for (i = 0; i < argc; i++){
		if (argv[i][0] == '-' || argv[i][0] == '+'){
			char *argv_i;
			
			argv_i=argv[i];
			
			if (strcmp (argv_i, "-v") == 0)
				;
			else if (strcmp (argv_i, "-w") == 0){
				DoWarning = False;
				DoStrictWarning	= False;
			} else if (strcmp (argv_i, "-d") == 0)
				DoDebug = True;
			else if (strcmp (argv_i, "-c") == 0)
				DoCode = False;
			else if (strcmp (argv_i, "-p") == 0)
				DoParallel = True;
#ifdef _SUN_
			else if (strcmp (argv_i, "-csf")==0)
				use_clean_system_files=1;
#endif
			else if (strcmp (argv_i, "-sl") == 0)
				DoStackLayout = True;
			else if (strcmp (argv_i, "-sa") == 0)
				DoStrictnessAnalysis = False;
			else if (strcmp (argv_i,"-ou") == 0)
				DoReuseUniqueNodes=True;
			else if (strcmp (argv_i,"-pm") == 0)
				DoProfiling=True;
			else if (strcmp (argv_i,"-pt") == 0)
				DoTimeProfiling=True;
			else if (strcmp (argv_i,"-pg") == 0){
				DoTimeProfiling=True;
				DoCallGraphProfiling=True;
			} else if (strcmp (argv_i,"-wmt") == 0)
				WriteModificationTimes=True;
			else if (strcmp (argv_i,"-wmf") == 0)
				FunctionMayFailWarningOrError=1;
			else if (strcmp (argv_i,"-emf") == 0)
				FunctionMayFailWarningOrError=2;
			else if (strcmp (argv_i,"-desc") ==0)
				DoDescriptors=True;
			else if (strcmp (argv_i,"-exl") ==0)
				ExportLocalLabels=True;
			else if (strcmp (argv_i,"-fusion") == 0)
				DoFusion=True;
			else if (strcmp (argv_i,"-generic_fusion") == 0)
				DoGenericFusion=True;
			else if (strcmp (argv_i,"-seft") == 0)
				AddStrictnessToExportedFunctionTypes=True;
			else if (strcmp (argv_i,"-dynamics") == 0)
				Dynamics=True;
			else if (strcmp (argv_i,"-tcl") == 0)
				TclFile=True;
#ifdef NO_OPTIMIZE_INSTANCE_CALLS
			else if (strcmp (argv_i,"-oic") == 0)
				OptimizeInstanceCalls=True;
#endif
			else if (strncmp (argv_i, "-sa", 3) == 0){
				if (!SetStrictOption (argv[i]+3))
					return ~i;
			} else if (strcmp (argv_i, "-RE") == 0){
				if (++i < argc){
#ifndef CLEAN_FILE_IO
# if defined (_MSC_VER) || defined (_SUN_)
					std_error_file_p = fopen (argv[i],"w");
					if (std_error_file_p!=NULL)
						StdErrorReopened = True;
					else
						std_error_file_p = stderr;
# else
					freopen (argv[i],"w",StdError);
					StdErrorReopened	= True;
# endif
#endif
				} else
					return ~i;
			} else if (strcmp (argv_i, "-RAE") == 0){
				if (++i < argc){
#ifndef CLEAN_FILE_IO
# if defined (_MSC_VER) || defined (_SUN_)
					std_error_file_p = fopen (argv[i],"a");
					if (std_error_file_p!=NULL)
						StdErrorReopened = True;
					else
						std_error_file_p = stderr;
# else
					freopen (argv[i],"a",StdError);
					StdErrorReopened	= True;
# endif
#endif
				} else
					return ~i;
			} else if (strcmp (argv_i, "-RO") == 0){
				if (++i < argc){
#ifndef CLEAN_FILE_IO
# if defined (_MSC_VER) || defined (_SUN_)
					std_out_file_p = fopen (argv[i],"w");
					if (std_out_file_p!=NULL)
						StdOutReopened = True;
					else
						std_out_file_p = stdout;
# else
					freopen (argv[i],"w",StdOut);
					StdOutReopened	= True;
# endif
#endif
				} else
					return ~i;
			} else if (strcmp (argv_i, "-RAO") == 0){
				if (++i < argc){
#ifndef CLEAN_FILE_IO
# if defined (_MSC_VER) || defined (_SUN_)
					std_out_file_p = fopen (argv[i],"a");
					if (std_out_file_p!=NULL)
						StdOutReopened = True;
					else
						std_out_file_p = stdout;
# else
					freopen (argv[i],"a",StdOut);
					StdOutReopened	= True;
# endif
#endif
				} else
					return ~i;
			} else
				return ~i;
		} else {
			/* process (non-flag) argument, not used anymore */
		}
	}

	InitCompiler();

	return 1;
}
