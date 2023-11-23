/*
	This module contains all the compiler supporting routines,
	such as: the storage administration and the error handling
	routines and some global variables containing the compiler
	settings.
*/

#include <ctype.h>

#include "compiledefines.h"
#include "types.t"
#include "system.h"
#include "sizes.h"

#include "settings.h"
#include "syntaxtr.t"
#include "comsupport.h"
#include "buildtree.h"
#include "statesgen.h"
#include "codegen_types.h"
#include "codegen1.h"
#include "codegen2.h"
#include "instructions.h"

#ifdef NO_CLIB
# define isdigit clean_compiler_isdigit
#endif

/* 'CurrentModule' contains the name of the module that is currently under examination. */

char *CurrentModule;
unsigned CurrentLine;
SymbDef CurrentSymbDef;
Bool CompilerError;

int ExitEnv_valid=0;
jmp_buf ExitEnv;

/*	The storage administration. */

unsigned long NrOfBytes;
unsigned NrOfLargeBlocks;

static char *StartStorage, *FirstBlock, *LastBlock, *NextFreeMem;

static void *AllocLarge (SizeT size)
{
	char **newblock;

	size = ReSize (size);
	if ((newblock = (char **) malloc ((unsigned long) size + SizeOf (char *)))!=NULL){
		*newblock  = FirstBlock;
		FirstBlock = (char *) newblock++;
		NrOfBytes += size;
		return (char *) newblock;
	} else {
		FatalCompError ("comsupport", "AllocLarge", "Insufficient Memory");
		
		return (void *) NULL;
	}
}

static Bool InitStorageFlag = True;

void InitStorage (void)
{
	if (InitStorageFlag){
		char **newblock;
		
		if ((newblock = (char **) malloc ((unsigned long) (MemBlockSize + (SizeT) (SizeOf (char *)))))!=NULL){
			*newblock = NULL;
			StartStorage = LastBlock = FirstBlock = (char *) newblock;
			NextFreeMem = SizeOf(char*)+(char*)newblock;
			InitStorageFlag = False;
			NrOfBytes = (unsigned long) (MemBlockSize + (SizeT) (SizeOf (char *)));
			NrOfLargeBlocks = 0;
		} else
			FatalCompError ("comsupport", "InitStorage","Insufficient Memory");
	}
}

#undef FILL_ALLOCATED_MEMORY_WITH_GARBAGE

#ifdef FILL_ALLOCATED_MEMORY_WITH_GARBAGE
static unsigned char g_next_garbage_byte=0;
#endif

void *CompAlloc (SizeT size)
{
	char *new_block;
	
	size = ReSize (size);
	
	if (size > KBYTE){
		NrOfLargeBlocks++;
#ifdef FILL_ALLOCATED_MEMORY_WITH_GARBAGE
		{
			void *m;
			unsigned char *p,next_garbage_byte;
			int i;
			
			m=AllocLarge (size);
			
			i=size;
			p=m;

			next_garbage_byte=g_next_garbage_byte;
			while (--i>=0)
				*p++ = next_garbage_byte++;
			g_next_garbage_byte=next_garbage_byte;

			return m;
		}
#else
		return AllocLarge (size);
#endif
	}
	
	new_block=NextFreeMem;
	
	if (new_block-LastBlock+size > MemBlockSize+SizeOf(char*)){
		char **newblock;

		newblock = (char **) malloc ((unsigned long)(MemBlockSize + (SizeT) (sizeof (char *))));
		if (newblock!=NULL){
			*((char **) LastBlock) = (char *) newblock;
			LastBlock = (char *) newblock;
		
			*newblock = NULL;
			new_block=LastBlock+SizeOf(char*);
		
			NrOfBytes += (unsigned long) (MemBlockSize + (SizeT) (SizeOf (char *)));
		} else {
/*			FPrintF (StdError,"Allocated %ld bytes\n",(long)NrOfBytes); */
			FatalCompError ("comsupport", "CompAlloc", "Insufficient Memory");
		}
	}

	NextFreeMem = new_block+size;

#ifdef FILL_ALLOCATED_MEMORY_WITH_GARBAGE
		{
			unsigned char *p,next_garbage_byte;
			int i;
						
			i=size;
			p=(unsigned char*)new_block;

			next_garbage_byte=g_next_garbage_byte;
			while (--i>=0)
				*p++ = next_garbage_byte++;
			g_next_garbage_byte=next_garbage_byte;
		}
#endif

	return (void *) new_block;
}

extern void finish_strictness_analysis (void);

void CompFree (void)
{
	if (! InitStorageFlag){
		char *block;

		for (block = FirstBlock; block; ){
			char *next_block;

			next_block=*((char **) block);
			free (block);
			block=next_block;
		}

		finish_strictness_analysis();

		InitStorageFlag = True;
	}
}

void int_to_string (char *s,long i)
{
	unsigned long u;
	unsigned int p,ua[8];
	int ua_i;
	
	if (i<0){
		*s++ = '-';
		u = -i;
	} else
		u = i;
	
	ua_i = 0;
	while (u>=10000){
		unsigned long d;
		
		d = u/10000;
		ua[ua_i++] = u-d*10000;
		u = d;
	}

	if (u<10){
		*s++ = '0'+u;	
	} else if (u<100){
		unsigned int i;
		
		p = u*103;
		i=p>>10;
		*s++ = '0'+i;
		*s++ = '0'+(u-10*i);
	} else if (u<1000){
		p = u*41;
		*s++ = '0'+(p>>12);
		p = 10 * (p & 0xfff);
		*s++ = '0'+(p>>12);
		p = 10 * (p & 0xfff);
		*s++ = '0'+(p>>12);
	} else {
		p = u*8389;
		*s++ = '0'+(p>>23);
		p = 10 * (p & 0x7fffff);
		*s++ = '0'+(p>>23);
		p = 10 * (p & 0x7fffff);
		*s++ = '0'+(p>>23);
		p = 10 * (p & 0x7fffff);
		*s++ = '0'+(p>>23);	
	}

	while (ua_i>0){
		u = ua[--ua_i];
		p = u*8389;
		*s++ = '0'+(p>>23);
		p = 10 * (p & 0x7fffff);
		*s++ = '0'+(p>>23);
		p = 10 * (p & 0x7fffff);
		*s++ = '0'+(p>>23);
		p = 10 * (p & 0x7fffff);
		*s++ = '0'+(p>>23);
	}
	
	*s='\0';
}

#ifdef CLEAN_FILE_IO
struct clean_file *clean_std_error_file = NULL;

void PutCStdError (char c)
{
	file_write_char (c,clean_std_error_file);
}

void PutSStdError (char *s)
{
	file_write_characters ((unsigned char*)s,strlen (s),clean_std_error_file);
}

void PutIStdError (long i)
{
	file_write_int (i,clean_std_error_file);
}
#else
#define PutSStdError(s) FPutS ((s),StdError)
#define PutCStdError(s) FPutC ((s),StdError)

void PutIStdError (long i)
{
	fprintf (StdError,"%ld",i);
}
#endif

/* The environment to leave the compiler if a fatal error occurs */

void FatalCompError (char *mod, char *proc, char *mess)
{
	PutSStdError ("Fatal Error in ");
	PutSStdError (mod);
	PutCStdError (':');
	PutSStdError (proc);
	PutSStdError (" \"");
	PutSStdError (mess);
	PutSStdError ("\"\n");

#ifndef CLEAN_FILE_IO
	if (OpenedFile){
		if (ABCFileName){
			CompilerError = True;
			CloseABCFile (ABCFileName);
		} else
			FClose (OpenedFile);
		OpenedFile = NULL;
	}
#endif

	if (!ExitEnv_valid)
		exit (1);
	longjmp (ExitEnv, 1);
}

static char *ConvertTypeSymbolKindToString (SymbKind skind)
{
	switch (skind){
		case int_type: 		return "Int";
		case bool_type:		return "Bool";
		case char_type:		return "Char";
		case real_type:		return "Real";
		case file_type:		return "File";
		case array_type:		return "{ }";
		case strict_array_type:	return "{ ! }";
		case unboxed_array_type:return "{ # }";
		case packed_array_type: return "{ 32# }";
		case world_type:	return "World";
		case procid_type:	return "ProcId";
		case redid_type:	return "RedId";
		case fun_type:		return "=>";
		case list_type:		return "List";
		case tuple_type:	return "Tuple";
		case dynamic_type:	return "Dynamic";
		default:			return "Erroneous";
	}
}

/* do not use if symb_kind==definition */
char *symbol_to_string (Symbol symbol)
{
	switch (symbol->symb_kind){
	case int_denot:
		return symbol->symb_int;
	case bool_denot:
		return symbol->symb_bool ? "True" : "False";
	case char_denot:
		return symbol->symb_char;
	case string_denot:
		return symbol->symb_string;
	case real_denot:
		return symbol->symb_real;
	case tuple_symb:
		return "Tuple";
	case cons_symb:
		return "[:]";
	case nil_symb:
		return "[]";
	case just_symb:
		return "+?";
	case none_symb:
		return "-?";
	case select_symb:
		return "_Select";
	case apply_symb:
		return "AP";
	case if_symb:
		return "if";
	case fail_symb:
		return "_Fail";
	case definition:
		return NULL;
	default:
		return "Erroneous";
	}
}

char *type_symbol_to_string (TypeSymbol symbol)
{
	switch (symbol->ts_kind){
	case apply_type_symb:
		return "AP";
	case definition:
		return NULL;
	default:
		return ConvertTypeSymbolKindToString ((SymbKind)symbol->ts_kind);
	}
}

static void write_compiler_generated_function_name_to_std_error (char *name, char *name_end, unsigned line_nr)
{
	char *parsed_digits;

	PutSStdError (name);
	
	parsed_digits=NULL;
	if (name_end[0]==';' && isdigit (name_end[1])){
		char *s;
		
		s=name_end+2;
		while (isdigit (*s))
			++s;
		if (*s==';')
			parsed_digits=s;
	}
	
	if (line_nr>0){
		PutSStdError ("[line: ");
		PutIStdError (line_nr);
		PutCStdError (']');
		if (parsed_digits)
			name_end=parsed_digits;
	} else
		if (parsed_digits){
			char *d_p;

			PutSStdError ("[line:");
			for (d_p=name_end+1; d_p<parsed_digits; ++d_p)
				PutCStdError (*d_p);
			PutCStdError (']');

			name_end=parsed_digits;
		}
	PutSStdError (name_end);
}

static void WriteSymbolOfIdentToStdError (char *name, unsigned line_nr)
{
	char *name_end;

	for (name_end=name; *name_end!=';' && *name_end!='\0'; ++name_end)
		;

	if (*name=='\\' && name+1==name_end){
		write_compiler_generated_function_name_to_std_error ("<lambda>",name_end,line_nr);
		return;
	}

	if (*name == '_'){
		if (name+2==name_end && name[1]=='c'){
			write_compiler_generated_function_name_to_std_error ("<case>",name_end,line_nr);
			return;
		} else if (name+3==name_end && name[1]=='i' && name[2]=='f'){
			write_compiler_generated_function_name_to_std_error ("<if>",name_end,line_nr);
			return;
		}
	} else
		if (line_nr > 0 && *name_end == ';' && isdigit (name_end[1])){
			char *end_name;

			for (; name!=name_end; name++)
				PutCStdError (*name);

			for (end_name = name_end + 2; *end_name!=';' && *end_name!='\0'; end_name++)
				 ;
			
			PutSStdError (" [line: ");
			PutIStdError (line_nr);
			PutCStdError (']');
			
			if (*end_name == '\0')
				return;

			name = end_name;
		}

	PutSStdError (name);
}

static void WriteTypeSymbolToStdError (TypeSymbol type_symbol)
{
	if (type_symbol->ts_kind==type_definition)
		WriteSymbolOfIdentToStdError (type_symbol->ts_def->sdef_name, 0);
	else
		PutSStdError (type_symbol_to_string (type_symbol));
}

void StaticMessage_D_s (Bool error,struct symbol_def *symb_def_p,char *message)
{
	if (! (error || DoWarning))
		return;

	PutSStdError (error ? "Error [" : "Warning [");
	PutSStdError (CurrentModule);
	if (CurrentLine > 0){
		PutCStdError (','); 
		PutIStdError (CurrentLine);
	}
	PutCStdError (',');
	WriteSymbolOfIdentToStdError (symb_def_p->sdef_name, 0);
	PutSStdError ("]: ");

	PutSStdError (message);

	PutCStdError ('\n');

	if (error)
		CompilerError = True;
}

void StaticMessage_S_s (Bool error,struct symbol_def *symb_def_p,char *message)
{
	if (! (error || DoWarning))
		return;

	PutSStdError (error ? "Error [" : "Warning [");
	PutSStdError (CurrentModule);
	if (CurrentLine > 0){
		PutCStdError (',');
		PutIStdError (CurrentLine);
	}
	PutCStdError (',');
	WriteSymbolOfIdentToStdError (symb_def_p->sdef_name, 0);
	PutSStdError ("]: ");

	PutSStdError (message);

	PutCStdError ('\n');

	if (error)
		CompilerError = True;
}

void StaticMessage_S_Ts (Bool error,struct symbol_def *symb_def_p1,struct type_symbol *symbol_p2,char *message)
{
	if (! (error || DoWarning))
		return;

	PutSStdError (error ? "Error [" : "Warning [");
	PutSStdError (CurrentModule);
	PutCStdError (',');
	WriteSymbolOfIdentToStdError (symb_def_p1->sdef_name, 0);
	PutSStdError ("]: ");

	WriteTypeSymbolToStdError (symbol_p2);
	PutSStdError (message);

	PutCStdError ('\n');

	if (error)
		CompilerError = True;
}

void StaticMessage_T_Ss (Bool error,struct type_symbol *symbol_p1,struct symbol_def *symb_def_p2,char *message)
{
	if (! (error || DoWarning))
		return;

	PutSStdError (error ? "Error [" : "Warning [");
	PutSStdError (CurrentModule);
	PutCStdError (',');
	WriteTypeSymbolToStdError (symbol_p1);
	PutSStdError ("]: ");

	WriteSymbolOfIdentToStdError (symb_def_p2->sdef_name, 0);
	PutSStdError (message);

	PutCStdError ('\n');

	if (error)
		CompilerError = True;
}

void StaticMessage_s_s (Bool error,char *symbol_s,char *message)
{
	if (! (error || DoWarning))
		return;

	PutSStdError (error ? "Error [" : "Warning [");
	PutSStdError (CurrentModule);
	if (CurrentLine > 0){
		PutCStdError (',');
		PutIStdError (CurrentLine);
	}
	PutCStdError (',');
	PutSStdError (symbol_s);
	PutSStdError ("]: ");

	PutSStdError (message);

	PutCStdError ('\n');

	if (error)
		CompilerError = True;
}

void StaticErrorMessage_T_ss (struct type_symbol *symbol_p,char *message1,char *message2)
{
	PutSStdError ("Error [");
	PutSStdError (CurrentModule);
	PutCStdError (',');
	WriteTypeSymbolToStdError (symbol_p);
	PutSStdError ("]: ");

	PutSStdError (message1);
	PutSStdError (message2);

	PutCStdError ('\n');

	CompilerError = True;
}

void StaticErrorMessage_s_Ds (char *symbol_s,struct symbol_def *symb_def_p,char *message)
{
	PutSStdError ("Error [");
	PutSStdError (CurrentModule);
	if (CurrentLine > 0){
		PutCStdError (',');
		PutIStdError (CurrentLine);
	}
	PutCStdError (',');
	PutSStdError (symbol_s);
	PutSStdError ("]: ");

	WriteSymbolOfIdentToStdError (symb_def_p->sdef_name, 0);
	PutSStdError (message);

	PutCStdError ('\n');

	CompilerError = True;
}

void StaticErrorMessage_s_ss (char *symbol_s,char *message1,char *message2)
{
	PutSStdError ("Error [");
	PutSStdError (CurrentModule);
	PutCStdError (',');
	PutSStdError (symbol_s);
	PutSStdError ("]: ");

	PutSStdError (message1);
	PutSStdError (message2);

	PutCStdError ('\n');

	CompilerError = True;
}

static char Init[] = "Compiler initialization";

File OpenedFile;

void InitCompiler (void)
{
	OpenedFile     = NULL;
	CompilerError	= False;
	/* Call all the initialization functions */
	/* InitStorage has to be called first */
	CurrentModule = Init;

	InitStorage		();
	InitGlobalSymbols();
	InitStatesGen		();
	InitCoding		();
	InitInstructions	();
} /* InitCompiler */

void ExitCompiler (void)
{
	CompFree();
}

#ifdef _DEBUG_

void ErrorInCompiler (char *mod, char *proc, char *msg)
{
	PutSStdError ("Error in compiler");;
	if (CurrentModule!=NULL){
		PutSStdError (" while compiling ");
		PutSStdError (CurrentModule);
		PutSStdError (".icl");
	}
	PutSStdError (": Module ");
	PutSStdError (mod);
	PutSStdError (", Function ");
	PutSStdError (proc);
	PutSStdError (", \"");
	PutSStdError (msg);
	PutSStdError ("\"\n");

	if (ExitEnv_valid)
		longjmp (ExitEnv, 1);
}

void Assume (Bool cond, char *mod, char *proc)
{
	if (! cond)
		ErrorInCompiler (mod, proc, "wrong assumption");
}

void AssumeError (char *mod, char *proc)
{
	ErrorInCompiler (mod, proc, "wrong assumption");
}
#endif

#if D
void error (void)
{
	printf ("error in compiler\n");
}
#endif
