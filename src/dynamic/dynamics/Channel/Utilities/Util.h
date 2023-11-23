#ifndef _UTILH
#define _UTILH

//#define STRICT
#include <windows.h>


#define SIGNEDLOWORD(i)  ((short) i)
#define SIGNEDHIWORD(i)  ((short) ((i)>>16))


/*  OS type, threading all calls from Clean.
*/

typedef int OS;
typedef int Bool; 
typedef int HITEM; 

typedef struct 
{   int  mess;
    int  p1;
    int  p2;
    int  p3;
    int  p4;
    int  p5;
    int  p6;
} CrossCallInfo;

typedef struct clean_string
    {   int  length;
        char characters[1];
    } *CLEAN_STRING;

#define EXPORT_TO_CLEAN

/*  since we don't use the C runtime library, here are some simple
    routines that would normally come from the C runtime lib.
*/

void rfree( HGLOBAL ptr );
HGLOBAL rmalloc( DWORD bytes );



int rstrlen(char *s);
void rsncopy(char *d, const char *s, int n);
void rscopy(char *d, const char *s);
BOOL strequal( char *s1, char *s2 );
int rabs(int i);


/*  clean_strings don't have to end with 0, so we have to make
    copy the clean string and end it with a 0.
    global variables used for conversion from c strings to clean strings
*/

char *cstring (CLEAN_STRING s);
CLEAN_STRING cleanstring (char *s);
CLEAN_STRING cleanstringn (char *s, int length);


/*  The following routines are used to write to the console, or convey runtime errors
    with message boxes. 
*/

#ifndef _RPRINTBUFSIZE
#define _RPRINTBUFSIZE 512
#endif

void rMessageBox(HWND owner, UINT style, char *title, char *format, ... );
void CheckF(BOOL theCheck, char *checkText, char *checkMess, char *filename, int linenum);
void ErrorExit(char *format, ...);
char *BOOLstring( BOOL b );

#define Check(check,mess) CheckF((check),(#check),(mess),__FILE__,__LINE__)

void DumpMem( int *ptr, int lines);

#define LOGFILE "debuglog.txt"

#ifdef LOGFILE
void rprintf(char *format, ... );
void printCCI( CrossCallInfo *pcci );
void printMessage( char* fname, HWND hWin, UINT uMess, WPARAM wPara, LPARAM lPara);
#else
# define rprintf /* RWS() */
# define printCCI(a1)
# define printMessage(a1,a2,a3,a4,a5)
#endif

#endif
