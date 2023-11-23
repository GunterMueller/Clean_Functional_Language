
#define MINIMUM(a,b)	(((a)<(b)) ? (a) : (b))
#define MAXIMUM(a,b)	(((a)>(b)) ? (a) : (b))

struct symbol_def;
struct type_symbol;

extern void StaticMessage_D_s (Bool error,struct symbol_def *symb_def_p,char *message);
extern void StaticMessage_S_Ts (Bool error,struct symbol_def *symbol_p1,struct type_symbol *type_symbol_p2,char *message);
extern void StaticMessage_S_s (Bool error,struct symbol_def *symbol_def_p,char *message);
extern void StaticMessage_T_Ss (Bool error,struct type_symbol *symbol_p1,struct symbol_def *symbol_def_p2,char *message);
extern void StaticMessage_s_s (Bool error,char *symbol_s,char *message);
extern void StaticErrorMessage_T_ss (struct type_symbol *symbol_p,char *message1,char *message2);
extern void StaticErrorMessage_s_Ds (char *symbol_s,struct symbol_def *symb_def_p,char *message);
extern void StaticErrorMessage_s_ss (char *symbol_s,char *message1,char *message2);

struct symbol;

/* do not use if symb_kind==definition */
extern char *symbol_to_string (struct symbol *symbol);
extern char *type_symbol_to_string (struct type_symbol *type_symbol);

extern Bool  CompilerError;
extern char *CurrentModule;

extern struct symbol_def *CurrentSymbDef;

extern unsigned CurrentLine;

extern int ExitEnv_valid;
extern File OpenedFile;

extern jmp_buf ExitEnv;

#define CompAllocType(t) ((t*)CompAlloc (SizeOf (t)))
#define CompAllocArray(s,t) ((t*)CompAlloc ((s)*SizeOf (t)))
extern void *CompAlloc (SizeT size);
extern void InitStorage (void);
extern void CompFree (void);

#ifdef CLEAN_FILE_IO
extern void file_write_char (int c,struct clean_file *f);
extern void file_write_characters (unsigned char *p,size_t length,struct clean_file *f);
extern void file_write_int (size_t i,struct clean_file *f);
extern void PutSStdError (char *s);
extern void PutCStdError (char c);
#else
# define PutSStdError(s) FPutS ((s),StdError)
# define PutCStdError(s) FPutC ((s),StdError)
#endif
extern void PutIStdError (long i);

extern void int_to_string (char *s,long i);

extern void FatalCompError (char *mod, char *proc, char *mess);

extern void InitCompiler (void);
extern void ExitCompiler (void);

#ifdef _DEBUG_
extern void ErrorInCompiler (char *mod, char *proc, char *msg);
extern void Assume (Bool cond, char *mod, char *proc);
extern void AssumeError (char *mod, char *proc);
#define ifnot(cond) if(!(cond))
#endif
