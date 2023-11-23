/*
	File:		mcon.c
	Written by:	John van Groningen
*/

/* #define MACOSX */
#define G_POWER
#define NEW_HEADERS
#ifdef MACHO
# define MACOSX
# define MACHO_EXCEPTIONS
#endif
#ifdef MACOSX
# define FLUSH_PORT_BUFFER
#endif
#if defined (MACOSX) || defined (MACHO)
# define STACK_OVERFLOW_EXCEPTION_HANDLER
#endif

#ifdef MACHO
# define NEWLINE_CHAR '\r'
#else
# define NEWLINE_CHAR '\n'
#endif

#ifdef MACHO
# define MAYBE_USE_STDIO
#endif

#ifdef MACOSX
# define TARGET_API_MAC_CARBON 1
#endif

#ifndef NEW_HEADERS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#else
# ifndef MACHO
extern void sprintf (char *,...);
# endif
#endif

#define MULW(a,b) ((int)((short)(a)*(short)(b)))
#define UDIVW(a,b) ((unsigned short)((unsigned short)(a)/(unsigned short)(b)))

#include <quickdraw.h>
#include <fonts.h>
#include <events.h>
#include <windows.h>
#ifndef NEW_HEADERS
//# include <desk.h>
#include <devices.h>
#endif
#include <memory.h>
#include <resources.h>
#include <menus.h>
#include <OSUtils.h>
#ifndef NEW_HEADERS
//# include <OSEvents.h>
#endif

#ifdef G_POWER
void first_function (void)
{
}
#endif

#ifdef STACK_OVERFLOW_EXCEPTION_HANDLER
# ifdef MACHO
#  include <mach/mach.h>
#  ifdef MACHO_EXCEPTIONS
#   include <pthread.h>
#  endif
# else
#	include <Files.h>
#	include <Folders.h>
#	include <CFBundle.h>
#	include <CFNumber.h>
#	include <CFURL.h>
#	define SIGBUS  10
#	define SIGSEGV 11
#	define SIG_DFL         (void (*)())0
#	define SIG_IGN         (void (*)())1
	struct  sigaction {
		void    (*sa_handler)();
		unsigned int sa_mask;
		int     sa_flags;
	};	
	struct  sigaltstack {
		char    *ss_sp;
		int     ss_size;
		int     ss_flags;
	};
	struct sigcontext {
		int     sc_onstack;
		int     sc_mask;
		int     sc_ir;
		int     sc_psw;
		int		sc_sp;
		void    *sc_regs;
	};
	struct vm_region_basic_info {
		int             protection;
		int             max_protection;
		unsigned int    inheritance;
		int             shared;
		int             reserved;
		int				offset;
		int 	        behavior;
		unsigned short  user_wired_count;
	};

	static CFBundleRef systemBundle=NULL;

	static int initSystemBundle (void)
	{
		FSRefParam fileRefParam;
		FSRef fileRef;
		OSErr error;
		CFURLRef url;
		
		{
			int i;
			char *p;
			
			p=(char*)&fileRefParam;
			for (i=0; i<sizeof (fileRefParam); ++i)
				p[i]=0;
	
			p=(char*)&fileRef;
			for (i=0; i<sizeof (fileRef); ++i)
				p[i]=0;
		}
		
		fileRefParam.ioNamePtr = "\pSystem.framework";;
		fileRefParam.newRef = &fileRef;
	
		error = FindFolder (kSystemDomain,kFrameworksFolderType,false,&fileRefParam.ioVRefNum,&fileRefParam.ioDirID);
		if (error!=noErr)
			return 0;
		
		error = PBMakeFSRefSync (&fileRefParam);
		if (error!=noErr)
			return 0;
	
		url = CFURLCreateFromFSRef (NULL/*kCFAllocatorDefault*/,&fileRef);
		if (url==NULL)
			return 0;
	
		systemBundle = CFBundleCreate(NULL/*kCFAllocatorDefault*/, url);
		if (systemBundle==NULL)
			return 0;	
		
		CFRelease (url);
		
		return 1;
	}

	static int (*sigaction_p) (int,void *,void *)=NULL;

	static int sigaction (int a1,void *a2,void *a3)
	{
		if (sigaction_p==NULL){
			if (systemBundle==NULL)
				initSystemBundle();
			sigaction_p = (int(*)(int,void*,void*)) CFBundleGetFunctionPointerForName (systemBundle,CFSTR ("sigaction"));
			if (sigaction_p==NULL)
				return -1;
		}
		
		return call_function_3 (a1,a2,a3,sigaction_p);
	}

	static int (*sigaltstack_p) (void *,void *);

	int sigaltstack (void *a1,void *a2)
	{
		if (sigaltstack_p==NULL){
			if (systemBundle==NULL)
				initSystemBundle();
			sigaltstack_p = (int(*)(void*,void*)) CFBundleGetFunctionPointerForName (systemBundle,CFSTR ("sigaltstack"));
			if (sigaltstack_p==NULL)
				return -1;
		}
		
		return call_function_2 (a1,a2,sigaltstack_p);
	}
	
	static int (*mach_task_self_p) (void)=NULL;

	int mach_task_self (void)
	{
		if (mach_task_self_p==NULL){
			if (systemBundle==NULL)
				initSystemBundle();
			mach_task_self_p = (int(*)(void)) CFBundleGetFunctionPointerForName (systemBundle,CFSTR ("mach_task_self"));
			if (mach_task_self_p==NULL)
				return -1;
		}
		
		return call_function_0 (mach_task_self_p);
	}

	static int (*vm_region_p) (int,void*,void *,int,void *,void *,void *);
	
	int vm_region (int a1,void *a2,void *a3,int a4,void *a5,void *a6,void *a7)
	{
		if (vm_region_p==NULL){
			if (systemBundle==NULL)
				initSystemBundle();
			vm_region_p = (int(*)(int,void*,void *,int,void *,void *,void *)) CFBundleGetFunctionPointerForName (systemBundle,CFSTR ("vm_region"));
			if (vm_region_p==NULL)
				return -1;
		}
		
		return call_function_7 (a1,a2,a3,a4,a5,a6,a7,vm_region_p);
	}

	static int (*vm_protect_p) (int,int,int,int,int);

	int vm_protect (int a1,int a2,int a3,int a4,int a5)
	{
		if (vm_protect_p==NULL){
			if (systemBundle==NULL)
				initSystemBundle();
			vm_protect_p = (int(*)(int,int,int,int,int)) CFBundleGetFunctionPointerForName (systemBundle,CFSTR ("vm_protect"));
			if (vm_protect_p==NULL)
				return -1;
		}
		
		return call_function_5 (a1,a2,a3,a4,a5,vm_protect_p);
	}
# endif
#endif

#ifdef MACOSX
# undef GetWindowPort
#endif

#undef PARALLEL
#undef SIMULATE
#undef COMMUNICATION

#include "mcon.h"
#ifdef COMMUNICATION
#	include "mcom.h"
#endif

extern void *abc_main();

extern void add_IO_time(),add_execute_time();

#define CONSOLE_WINDOW_ID	128
#define ERROR_WINDOW_ID		129

static int cur_y,cur_x;
static int g_cur_x;
static int n_screen_lines;

static int e_cur_y,e_cur_x;
static int e_g_cur_x;
static int n_e_screen_lines;

static int char_height,char_ascent,char_descent,char_leading,char_asc_lead;

#define MAX_N_COLUMNS 160

typedef char SCREEN_LINE_CHARS [MAX_N_COLUMNS+1];
static SCREEN_LINE_CHARS *screen_chars,*e_screen_chars;

static char *input_buffer;
static int input_buffer_pos,input_buffer_length;

static WindowPtr c_window,e_window;

static int error_window_visible;
static int console_window_visible;

static EventRecord my_event;

static void update_window (WindowPtr window,SCREEN_LINE_CHARS *chars,int n_lines,int g_cur_x,int cur_y)
{
	int y,screen_y_pos;
	GrafPtr old_port;
	
	BeginUpdate (window);
	GetPort(&old_port);

#ifdef MACOSX
	SetPort (GetWindowPort (window));
	{
		RgnHandle visible_region;
		
		visible_region=NewRgn();
		GetPortVisibleRegion (GetWindowPort (window),visible_region);
		EraseRgn (visible_region);
		DisposeRgn (visible_region);
	}
#else
	SetPort (window);
	EraseRgn (window->visRgn);
#endif
		
	for (y=0,screen_y_pos=char_asc_lead; y<n_lines; ++y,screen_y_pos+=char_height){
		char *line_chars,*c_p;
		int line_length;
		
		MoveTo (0,screen_y_pos);
		line_chars=chars[y];
		
		line_length=0;
		c_p=line_chars;
		while (*c_p++!=NEWLINE_CHAR)
			++line_length;
		DrawText (line_chars,0,line_length);
	}
	
	MoveTo (g_cur_x,MULW (cur_y,char_height)+char_asc_lead);
	
	SetPort (old_port);
	EndUpdate (window);
}

static void select_window (WindowPtr window)
{
	if (window!=c_window && window!=e_window)
		return;
	
	SelectWindow (window);
}

static int c_window_width,c_window_height,e_window_width,e_window_height;

static Rect c_window_rect,e_window_rect;
static Rect c_local_window_rect,e_local_window_rect;

static void scroll_window (WindowPtr window,SCREEN_LINE_CHARS *chars,int n_lines)
{
	RgnHandle erase_region;
#ifdef MACOSX
	Rect rect;
#endif
	
	add_execute_time();
	
	erase_region=NewRgn();

#ifdef MACOSX
	GetPortBounds (GetWindowPort (window),&rect);
	ScrollRect (&rect,0,-char_height,erase_region);		
#else
	ScrollRect (&window->portRect,0,-char_height,erase_region);
#endif

	EraseRgn (erase_region);
	DisposeRgn (erase_region);

	BlockMove ((char*)chars[1],(char*)chars,(MAX_N_COLUMNS+1)*(n_lines-1));
	chars[n_lines-1][0]=NEWLINE_CHAR;

#ifdef FLUSH_PORT_BUFFER
	QDFlushPortBuffer (GetWindowPort (window),NULL);
#endif
	
	add_IO_time();
}

static void print_newline()
{
	screen_chars[cur_y][cur_x]=NEWLINE_CHAR;
	++cur_y;
	cur_x=0;
	g_cur_x=0;
	if (cur_y>=n_screen_lines){
		cur_y=n_screen_lines-1;
		scroll_window (c_window,screen_chars,n_screen_lines);
	} 
#ifdef FLUSH_PORT_BUFFER
	else
		QDFlushPortBuffer (GetWindowPort (c_window),NULL);
#endif
	MoveTo (0,MULW(cur_y,char_height)+char_asc_lead);
}
	
static void window_print_char (char c)
{	
	if (c==NEWLINE_CHAR)
		print_newline();
	else {
		char *screen_char;
		int w;

		w=CharWidth (c);
		if (g_cur_x+w>=c_window_width || cur_x+1>=MAX_N_COLUMNS)
			print_newline();
		g_cur_x+=w;
			
		screen_char=&screen_chars[cur_y][cur_x];
		*screen_char=c;
		screen_char[1]=NEWLINE_CHAR;
		DrawChar (c);
		++cur_x;
	}
}

static void make_error_window_visible ()
{
	if (!error_window_visible){
		add_execute_time();
		ShowWindow (e_window);
#ifdef MACOSX
		ValidWindowRect (e_window,&e_local_window_rect);
#else
		ValidRect (&e_local_window_rect);
#endif
		add_IO_time();
		error_window_visible=1;
	}
}

static void make_console_window_visible ()
{
	if (!console_window_visible){
		add_execute_time();

		ShowWindow (c_window);
		
#ifdef MACOSX
		ValidWindowRect (c_window,&c_local_window_rect);
#else
		ValidRect (&c_local_window_rect);
#endif
		add_IO_time();
		console_window_visible=1;
	}
}

/*
	#ifdef powerc
	   QDGlobals qd;
	#endif
**/

#ifndef MACOSX

#ifdef NO_INIT
extern QDGlobals qd;
#else
QDGlobals qd;
#endif

#endif

#ifdef MAYBE_USE_STDIO
static int use_stdio;
#define swap_nl_cr(c) (((c)=='\n' || (c)=='\r') ? ((c) ^ ((char)('\n' ^ '\r'))) : (c))
#define oputc(c) putchar(swap_nl_cr(c))
#define eputc(c) putc(swap_nl_cr (c),stderr)
#endif

void w_print_char (char c)
{
	GrafPtr port;
	
#ifdef MAYBE_USE_STDIO
	if (use_stdio){
		oputc (c);
		return;
	}
#endif
#ifdef MACOSX
	GetPort (&port);
	SetPort (GetWindowPort (c_window));
#else
	port=NULL;
	if (qd.thePort!=c_window){
		port=qd.thePort;
		SetPort (c_window);
	}
#endif

	if (!console_window_visible)
		make_console_window_visible();

	window_print_char (c);
	
#ifndef MACOSX
	if (port!=NULL)
#endif
		SetPort (port);
}

static void w_print_text_without_newlines (char *s,unsigned long length)
{
	unsigned long text_length,n;
	
	text_length=TextWidth (s,0,length);
	if (g_cur_x+text_length<c_window_width && cur_x+length<MAX_N_COLUMNS){
		char *screen_char;
		int n;
		
		screen_char=&screen_chars[cur_y][cur_x];
		for (n=0; n<length; ++n)
			*screen_char++=s[n];
		*screen_char=NEWLINE_CHAR;
		DrawText (s,0,length);
		g_cur_x+=text_length;
		cur_x+=length;
	} else
		for (n=0; n<length; ++n)
			window_print_char (s[n]);
}

void w_print_text (char *s,unsigned long length)
{
	char *end_s,c;
	GrafPtr port;
	
#ifdef MAYBE_USE_STDIO
	if (use_stdio){
		int l;
		
		l=length;
		if (l){
			flockfile (stdout);
			
			do {
				int c;
				
				c=*s;
				putchar_unlocked (swap_nl_cr (c));
				++s;
			} while (--l);
			
			funlockfile (stdout);
		}
		return;
	}
#endif
#ifdef MACOSX
	GetPort (&port);
	SetPort (GetWindowPort (c_window));
#else
	port=NULL;
	if (qd.thePort!=c_window){
		port=qd.thePort;
		SetPort (c_window);
	}
#endif

	if (!console_window_visible)
		make_console_window_visible();

	end_s=s;
	while (length!=0){
		while (length!=0 && (c=*end_s,c!=NEWLINE_CHAR)){
			++end_s;
			--length;
		}
		w_print_text_without_newlines (s,end_s-s);
		if (length==0)
			return;
		print_newline();
		--length;
		s=++end_s;
	}
	
#ifndef MACOSX
	if (port!=NULL)
#endif
		SetPort (port);
}

static void e_print_newline()
{
	e_screen_chars[e_cur_y][e_cur_x]=NEWLINE_CHAR;
	++e_cur_y;
	e_cur_x=0;
	e_g_cur_x=0;
	if (e_cur_y>=n_e_screen_lines){
		e_cur_y=n_e_screen_lines-1;
		scroll_window (e_window,e_screen_chars,n_e_screen_lines);
	}
#ifdef FLUSH_PORT_BUFFER
	else
		QDFlushPortBuffer (GetWindowPort (e_window),NULL);
#endif
	MoveTo (0,MULW(e_cur_y,char_height)+char_asc_lead);
}

static void e_print_char (char c)
{	
	if (c==NEWLINE_CHAR)
		e_print_newline();
	else {
		char *screen_char;
		int w;

		w=CharWidth (c);
		if (e_g_cur_x+w>=e_window_width || e_cur_x+1>=MAX_N_COLUMNS)
			e_print_newline();
		e_g_cur_x+=w;
			
		screen_char=&e_screen_chars[e_cur_y][e_cur_x];
		*screen_char=c;
		screen_char[1]=NEWLINE_CHAR;
		DrawChar (c);
		++e_cur_x;
	}
}

void ew_print_char (char c)
{
	GrafPtr port;
	
#ifdef MAYBE_USE_STDIO
	if (use_stdio){
		eputc (c);
		return;
	}
#endif
#ifdef MACOSX
	GetPort (&port);
	SetPort (GetWindowPort (e_window));
#else
	port=NULL;
	if (qd.thePort!=e_window){
		port=qd.thePort;
		SetPort (e_window);
	}
#endif

	if (!error_window_visible)
		make_error_window_visible();

	e_print_char (c);

#ifndef MACOSX
	if (port!=NULL)
#endif
		SetPort (port);
}

static void e_print_text_without_newlines (char *s,unsigned long length)
{
	unsigned long text_length,n;
	
	text_length=TextWidth (s,0,length);
	if (e_g_cur_x+text_length<e_window_width && e_cur_x+length<MAX_N_COLUMNS){
		char *screen_char;
		int n;
		
		screen_char=&e_screen_chars[e_cur_y][e_cur_x];
		for (n=0; n<length; ++n)
			*screen_char++=s[n];
		*screen_char=NEWLINE_CHAR;
		DrawText (s,0,length);
		e_g_cur_x+=text_length;
		e_cur_x+=length;
	} else
		for (n=0; n<length; ++n)
			e_print_char (s[n]);
}

static void e_print_text (char *s,unsigned long length)
{
	char *end_s,c;
	
	end_s=s;
	while (length!=0){
		while (length!=0 && (c=*end_s,c!=NEWLINE_CHAR)){
			++end_s;
			--length;
		}
		e_print_text_without_newlines (s,end_s-s);
		if (length==0)
			return;
		e_print_newline();
		--length;
		s=++end_s;
	}
}

void ew_print_text (char *s,unsigned long length)
{
	GrafPtr port;
	
#ifdef MAYBE_USE_STDIO
	if (use_stdio){
		int l;
		
		l=length;
		if (l){
			flockfile (stderr);
		
			do {
				int c;
				
				c=*s;
				putc (swap_nl_cr (c),stderr);
				++s;
			} while (--l);
			
			funlockfile (stderr);
		}
		return;
	}
#endif
#ifdef MACOSX
	GetPort (&port);
	SetPort (GetWindowPort (e_window));
#else
	port=NULL;
	if (qd.thePort!=e_window){
		port=qd.thePort;
		SetPort (e_window);
	}
#endif

	if (!error_window_visible)
		make_error_window_visible();
	
	e_print_text (s,length);

#ifndef MACOSX
	if (port!=NULL)
#endif
		SetPort (port);
}

static void w_show_cursor()
{
	int y;
	
	y=MULW(cur_y,char_height);
	MoveTo (g_cur_x,y+char_height);
	LineTo (g_cur_x,y+1);
	MoveTo (g_cur_x,y+char_asc_lead);
}

static void w_remove_cursor()
{
	PenMode (patBic);
	w_show_cursor();
	PenMode (patCopy);
}

static void w_remove_char (int w)
{
	Rect r;
	int y;
	
	y=MULW(cur_y,char_height);
	
	r.bottom=y+char_height;
	r.top=y+1;
	r.left=g_cur_x;
	r.right=g_cur_x+w-1;
	
	EraseRect (&r);
}

void handle_update_or_mouse_down_event (EventRecord *event_p)
{
	if (event_p->what==updateEvt){
		if ((WindowPtr)event_p->message==c_window){
			w_remove_cursor();
			update_window (c_window,screen_chars,n_screen_lines,g_cur_x,cur_y);
			w_show_cursor();
		} else if ((WindowPtr)event_p->message==e_window)
			update_window (e_window,e_screen_chars,n_e_screen_lines,e_g_cur_x,e_cur_y);
	} else if (event_p->what==mouseDown){
		WindowPtr window;

		if (FindWindow (event_p->where,&window)==inContent)
			select_window (window);
	}
}

static int w_read_char()
{
	add_execute_time();
	
	while (1){
#ifndef MACOSX
		SystemTask();
#endif
		if (!GetNextEvent (everyEvent,&my_event))
			continue;
		switch (my_event.what){
			case keyDown:
			case autoKey:
			{
				int c;
				
				c=my_event.message & 0xff;
				
				add_IO_time();
				
				return c;
			}
			case updateEvt:
			case mouseDown:
				handle_update_or_mouse_down_event (&my_event);
				break;
		}
	}
}

static void w_read_line()
{
	int b_cur_x,b_cur_y,n_chars_read,c;
	
	n_chars_read=0;
	b_cur_x=cur_x;
	b_cur_y=cur_y;
	
	do {
		w_show_cursor();
		c=w_read_char();
		w_remove_cursor();
		if (c=='\b'){
			if (n_chars_read>0){
				while (cur_x==0){
					int line_length,x,c;
					char *screen_line;
		
					--cur_y;
					screen_line=screen_chars[cur_y];
					
					line_length=0;
					x=0;
					while (c=screen_line[line_length],c!=NEWLINE_CHAR){
						++line_length;
						x+=CharWidth (c);
					}
					cur_x=line_length;
					g_cur_x=x;
				}
				if (cur_x>0){
					int w;
					char *screen_char;
					
					--cur_x;
					screen_char=&screen_chars[cur_y][cur_x];
					w=CharWidth (*screen_char);
					*screen_char=NEWLINE_CHAR;
					g_cur_x-=w;
					--n_chars_read;
					w_remove_char (w);				
				}
			}
		} else {
			if (c==NEWLINE_CHAR){
				if (cur_y+1<n_screen_lines)
					print_newline();
				else
					if (b_cur_y>0){
						--b_cur_y;
						print_newline();
					}
			} else {
				char *screen_char;
				int w;
		
				w=CharWidth (c);
				if (g_cur_x+w>=c_window_width || cur_x+1>=MAX_N_COLUMNS)
					if (cur_y+1<n_screen_lines)
						print_newline();
					else
						if (b_cur_y>0){
							--b_cur_y;
							print_newline();
						} else
							continue;
				g_cur_x+=w;
					
				screen_char=&screen_chars[cur_y][cur_x];
				*screen_char=c;
				screen_char[1]=NEWLINE_CHAR;
				DrawChar (c);
				++cur_x;
				++n_chars_read;
			}
		}
	} while (c!=NEWLINE_CHAR);
	
	{
		char *char_p,*screen_p;
		
		input_buffer_length=n_chars_read+1;
		input_buffer_pos=0;
		
		char_p=input_buffer;
		screen_p=&screen_chars[b_cur_y][b_cur_x];
		while (n_chars_read!=0){
			int c;
			
			while (c=*screen_p++,c==NEWLINE_CHAR){
				++b_cur_y;
				screen_p=screen_chars[b_cur_y];
			}
			*char_p++=c;
			--n_chars_read;
		}
		*char_p++=NEWLINE_CHAR;
	}
}

int w_get_char (void)
{
	int c;

#ifdef MAYBE_USE_STDIO
	if (use_stdio){
		c=getchar();
		return swap_nl_cr (c);
	}
#endif

	if (input_buffer_length==0){
		GrafPtr port;
		
#ifdef MACOSX
		GetPort (&port);
		SetPort (GetWindowPort (c_window));
#else
		port=NULL;
		if (qd.thePort!=c_window){
			port=qd.thePort;
			SetPort (c_window);
		}
#endif
	
		if (!console_window_visible)
			make_console_window_visible();
	
		w_read_line();
	
#ifndef MACOSX
		if (port!=NULL)
#endif
			SetPort (port);
	}
	
	c=input_buffer[input_buffer_pos] & 0xff;
	++input_buffer_pos;
	--input_buffer_length;
	
	return c;
}

unsigned long w_get_string (char *string,unsigned long max_length)
{
	unsigned long length;

#ifdef MAYBE_USE_STDIO
	if (use_stdio){
		int i;
		
		length=fread (string,1,max_length,stdin);
		
		for (i=0; i<length; ++i){
			int c;
			
			c=string[i];
			string[i]=swap_nl_cr (c);
		}
		
		return length;
	}	
#endif

	length=0;
	while (length!=max_length){
		*string++=w_get_char();
		++length;
	}

	return length;
}

unsigned long w_get_line (char *string,unsigned long max_length)
{
	unsigned long length;

#ifdef MAYBE_USE_STDIO
	if (use_stdio){
		int c;
		length=0;

		flockfile (stdin);

		while (length!=max_length && (c=getchar_unlocked(),c!=EOF)){
			*string++=c;
			++length;
			if (c=='\n'){
				funlockfile (stdin);
				return length;
			}
		}

		funlockfile (stdin);

		if (c!=EOF)
			return -1;

		return length;
	}
#endif

	length=0;

	while (length!=max_length){
		int c;

		c=w_get_char();
		*string++=c;
		++length;
		if (c==NEWLINE_CHAR)
			return length;
	}

	return -1;		
}

#define is_digit(n) ((unsigned)((n)-'0')<(unsigned)10)

int w_get_int (int *i_p)
{
	int c,negative;
	unsigned int i;
	
	c=w_get_char();
#ifdef MAYBE_USE_STDIO
	while (c==' ' || c=='\t' || c=='\n' || c=='\r')
#else
	while (c==' ' || c=='\t' || c==NEWLINE_CHAR)
#endif
		c=w_get_char();
	
	negative=0;
	if (c=='+')
		c=w_get_char();
	else
		if (c=='-'){
			c=w_get_char();
			negative=1;
		}
	
	if (!is_digit (c)){
#ifdef MAYBE_USE_STDIO
		if (use_stdio){
			if (c!=EOF)
				ungetc (swap_nl_cr (c),stdin);
		} else {
#endif
		--input_buffer_pos;
		++input_buffer_length;
#ifdef MAYBE_USE_STDIO
		}
#endif	
		*i_p=0;
		return 0;
	}
	
	i=c-'0';
	while (c=w_get_char(),is_digit (c)){
		i+=i<<2;
		i+=i;
		i+=c-'0';
	};

	if (negative)
		i=-i;

#ifdef MAYBE_USE_STDIO
	if (use_stdio){
		if (c!=EOF)
			ungetc (swap_nl_cr (c),stdin);
	} else {
#endif
	--input_buffer_pos;
	++input_buffer_length;
#ifdef MAYBE_USE_STDIO
		}
#endif	

	*i_p=i;
	return -1;
}

int w_get_real (double *r_p)
{
	char s[256+1];
	int c,dot,digits,result,n;
	
	n=0;
	
	c=w_get_char();
#ifdef MAYBE_USE_STDIO
	while (c==' ' || c=='\t' || c=='\n' || c=='\r')
#else
	while (c==' ' || c=='\t' || c==NEWLINE_CHAR)
#endif
		c=w_get_char();
	
	if (c=='+')
		c=w_get_char();
	else
		if (c=='-'){
			s[n++]=c;
			c=w_get_char();
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
		c=w_get_char();
	}

	result=0;
	if (digits)
		if (dot==2 || ! (c=='e' || c=='E'))
			result=-1;
		else {
			if (n<256)
				s[n++]=c;
			c=w_get_char();
			
			if (c=='+')
				c=w_get_char();
			else
				if (c=='-'){
					if (n<256)
						s[n++]=c;
					c=w_get_char();
				}
			
			if (is_digit (c)){
				do {
					if (n<256)
						s[n++]=c;
					c=w_get_char();
				} while (is_digit (c));

				result=-1;
			}
		}

	if (n>=256)
		result=0;

#ifdef MAYBE_USE_STDIO
	if (use_stdio){
		if (c!=EOF)
			ungetc (swap_nl_cr (c),stdin);
	} else {
#endif
	--input_buffer_pos;
	++input_buffer_length;
#ifdef MAYBE_USE_STDIO
	}
#endif

	*r_p=0.0;
	
	if (result){
		s[n]='\0';

#if !defined (G_POWER)
		result=convert_string_to_real (s,r_p);
#else
		if (sscanf (s,"%lg",r_p)!=1)
			result=0;
#endif
	}
	
	return result;
}

unsigned long w_get_text (char *string,unsigned long max_length)
{
	unsigned long length,l;
	char *sp,*dp;
	GrafPtr port;
	
#ifdef MAYBE_USE_STDIO
	if (use_stdio){
		int length;
		
		fgets (string,(int)max_length,stdin);
		
		for (length=0; length<max_length; ++length)
			if (string[length]=='\0')
				break;
		
		return length;
	}
#endif
#ifdef MACOSX
	GetPort (&port);
	SetPort (GetWindowPort (c_window));
#else
	port=NULL;
	if (qd.thePort!=c_window){
		port=qd.thePort;
		SetPort (c_window);
	}
#endif
	
	if (!console_window_visible)
		make_console_window_visible();

	if (input_buffer_length==0)
		w_read_line();
	length=input_buffer_length;
	if (length>max_length)
		length=max_length;
	
	for (l=length,sp=&input_buffer[input_buffer_pos],dp=string; l!=0; --l)
		*dp++=*sp++;
	
	input_buffer_pos+=length;
	input_buffer_length-=length;
	
#ifndef MACOSX
	if (port!=NULL)
#endif
		SetPort (port);
	
	return length;
}

void w_print_string (char *s)
{
	char *end_s,c;
	GrafPtr port;
	
#ifdef MAYBE_USE_STDIO
	if (use_stdio){
		int c;
		
		flockfile (stdin);
		
		while ((c=*s)!='\0'){
			putchar_unlocked (swap_nl_cr (c));
			++s;
		}
		
		funlockfile (stdin);
		
		return;
	}
#endif
#ifdef MACOSX
	GetPort (&port);
	SetPort (GetWindowPort (c_window));
#else
	port=NULL;
	if (qd.thePort!=c_window){
		port=qd.thePort;
		SetPort (c_window);
	}
#endif
	
	if (!console_window_visible)
		make_console_window_visible();

	end_s=s;
	while (*s!='\0'){
		while (c=*end_s,c!='\0' && c!=NEWLINE_CHAR)
			++end_s;
		w_print_text_without_newlines (s,end_s-s);
		if (*end_s=='\0')
			break;
		print_newline();
		s=++end_s;
	}
	
#ifndef MACOSX
	if (port!=NULL)
#endif
		SetPort (port);
}

void ew_print_string (char *s)
{
	char *end_s,c;
	GrafPtr port;
	
#ifdef MAYBE_USE_STDIO
	if (use_stdio){
		int c;
		
		flockfile (stderr);
		
		while ((c=*s)!='\0'){
			putc_unlocked (swap_nl_cr (c),stderr);
			++s;
		}
		
		funlockfile (stderr);

		return;
	}
#endif
#ifdef MACOSX
	GetPort (&port);
	SetPort (GetWindowPort (e_window));
#else
	port=NULL;
	if (qd.thePort!=e_window){
		port=qd.thePort;
		SetPort (e_window);
	}
#endif

	if (!error_window_visible)
		make_error_window_visible();
	
	end_s=s;
	while (*s!='\0'){
		while (c=*end_s,c!='\0' && c!=NEWLINE_CHAR)
			++end_s;
		e_print_text_without_newlines (s,end_s-s);
		if (*end_s=='\0')
			break;
		e_print_newline();
		s=++end_s;
	}

#ifndef MACOSX
	if (port!=NULL)
#endif
		SetPort (port);
}

#if !defined (G_POWER)
extern char *convert_int_to_string (char *string,int i);
extern char *convert_real_to_string (char *string,double *r_p);
extern int convert_string_to_real (char *string,double *r_p);
#endif

void w_print_int (int n)
{
	char int_string [32];
	GrafPtr port;
	
#ifdef MAYBE_USE_STDIO
	if (use_stdio){
		printf ("%d",n);
		return;
	}
#endif
#ifdef MACOSX
	GetPort (&port);
	SetPort (GetWindowPort (c_window));
#else
	port=NULL;
	if (qd.thePort!=c_window){
		port=qd.thePort;
		SetPort (c_window);
	}
#endif
	
	if (!console_window_visible)
		make_console_window_visible();

#if !defined (G_POWER)
	{
		char *end_p;
	
		end_p=convert_int_to_string (int_string,n);
		w_print_text_without_newlines (int_string,end_p-int_string);
	}
#else
	sprintf (int_string,"%d",n);
	{
		int string_length;
		char *p;
		
		string_length=0;
		for (p=int_string; *p; ++p)
			++string_length;
		
		w_print_text_without_newlines (int_string,string_length);
	}
#endif

#ifndef MACOSX
	if (port!=NULL)
#endif
		SetPort (port);
}

void ew_print_int (int n)
{
	char int_string [32];
	GrafPtr port;

#ifdef MAYBE_USE_STDIO
	if (use_stdio){
		fprintf (stderr,"%d",n);
		return;
	}
#endif
#ifdef MACOSX
	GetPort (&port);
	SetPort (GetWindowPort (e_window));
#else
	port=NULL;
	if (qd.thePort!=e_window){
		port=qd.thePort;
		SetPort (e_window);
	}
#endif
	
	if (!error_window_visible)
		make_error_window_visible();

#if !defined (G_POWER)
	{
		char *end_p;
		
		end_p=convert_int_to_string (int_string,n);
		e_print_text_without_newlines (int_string,end_p-int_string);
	}
#else
	sprintf (int_string,"%d",n);
	{
		int string_length;
		char *p;
		
		string_length=0;
		for (p=int_string; *p; ++p)
			++string_length;

		e_print_text_without_newlines (int_string,string_length);
	}
#endif

#ifndef MACOSX
	if (port!=NULL)
#endif
		SetPort (port);
}

void w_print_real (double r)
{
	char real_string [40];
	GrafPtr port;
	
#ifdef MAYBE_USE_STDIO
	if (use_stdio){
		printf ("%.15g",r);
		return;
	}
#endif
#ifdef MACOSX
	GetPort (&port);
	SetPort (GetWindowPort (c_window));
#else
	port=NULL;
	if (qd.thePort!=c_window){
		port=qd.thePort;
		SetPort (c_window);
	}
#endif
	
	if (!console_window_visible)
		make_console_window_visible();

#if !defined (G_POWER)
	{
		char *end_p;
		
		end_p=convert_real_to_string (real_string,&r);
		w_print_text_without_newlines (real_string,end_p-real_string);
	}
#else
	sprintf (real_string,"%.15g",r);
	{
		int string_length;
		char *p;
		
		string_length=0;
		for (p=real_string; *p; ++p)
			++string_length;
		
		w_print_text_without_newlines (real_string,string_length);
	}
#endif

#ifndef MACOSX
	if (port!=NULL)
#endif
		SetPort (port);
}

void ew_print_real (double r)
{
	char real_string [40];
	GrafPtr port;
	
#ifdef MAYBE_USE_STDIO
	if (use_stdio){
		fprintf (stderr,"%.15g",r);
		return;
	}
#endif
#ifdef MACOSX
	GetPort (&port);
	SetPort (GetWindowPort (e_window));
#else
	port=NULL;
	if (qd.thePort!=e_window){
		port=qd.thePort;
		SetPort (e_window);
	}
#endif
	
	if (!error_window_visible)
		make_error_window_visible();

#if !defined (G_POWER)
	{
		char *end_p;
		
		end_p=convert_real_to_string (real_string,&r);
		e_print_text_without_newlines (real_string,end_p-real_string);
	}
#else
	sprintf (real_string,"%.15g",r);
	{
		int string_length;
		char *p;
		
		string_length=0;
		for (p=real_string; *p; ++p)
			++string_length;
		
		e_print_text_without_newlines (real_string,string_length);
	}
#endif

#ifndef MACOSX
	if (port!=NULL)
#endif
		SetPort (port);
}

static FontInfo font_info;
static short font_id,font_size;

long stack_size,heap_size,flags;
#ifdef WRITE_HEAP
long min_write_heap_size=0;
#endif;
#ifdef G_POWER
long heap_size_multiple;
long initial_heap_size;
#endif

static int init_terminal()
{
	int n;
	int screen_top,screen_left,screen_bottom,screen_right;
	int screen_width,screen_height,left_right_free,top_bottom_free;
	
	int three,ten;

#ifndef NO_INIT	
# ifdef MAYBE_USE_STDIO
	if (use_stdio){
		FlushEvents (everyEvent,0);
		InitCursor();
		error_window_visible=0;
		console_window_visible=0;

		return 1;
	}
# endif
# ifndef MACOSX
	InitGraf (&qd.thePort);
	InitFonts();
# endif
	FlushEvents (everyEvent,0);
# ifndef MACOSX
	InitWindows();
# endif
	InitCursor();
# ifndef MACOSX
	InitMenus();
# endif
#endif

	three=3; ten=10;	/* to get a divw instead of a divl */

#ifdef MACOSX
	{
		BitMap bit_map;
		
		GetQDGlobalsScreenBits (&bit_map);

		screen_top=bit_map.bounds.top;
		screen_left=bit_map.bounds.left;
		screen_bottom=bit_map.bounds.bottom;
		screen_right=bit_map.bounds.right;
	}
#else
	screen_top=qd.thePort->portRect.top;
	screen_left=qd.thePort->portRect.left;
	screen_bottom=qd.thePort->portRect.bottom;
	screen_right=qd.thePort->portRect.right;
#endif

	screen_top+=15; /* menu bar height */

	screen_width=screen_right-screen_left+1;
	screen_height=screen_bottom-screen_top+1;
	
	left_right_free=UDIVW (screen_width>>2,three); /* /12 */
	top_bottom_free=12;
	
	c_window_rect.left=screen_left+left_right_free;
	c_window_rect.right=screen_right-left_right_free;
	
	c_window_rect.top=screen_top+20+top_bottom_free;
	c_window_rect.bottom=screen_top+UDIVW (screen_height*7,ten)-6;

	c_local_window_rect.left=0;
	c_local_window_rect.right=c_window_rect.right-c_window_rect.left;
	
	c_local_window_rect.top=0;
	c_local_window_rect.bottom=c_window_rect.bottom-c_window_rect.top;
	
	e_window_rect.left=screen_left+left_right_free;
	e_window_rect.right=screen_right-left_right_free;
	
	e_window_rect.top=screen_top+20+UDIVW (screen_height*7,ten)+6;
	e_window_rect.bottom=screen_bottom-top_bottom_free;

	e_local_window_rect.left=0;
	e_local_window_rect.right=e_window_rect.right-e_window_rect.left;
	
	e_local_window_rect.top=0;
	e_local_window_rect.bottom=e_window_rect.bottom-e_window_rect.top;

	c_window_width=c_window_rect.right-c_window_rect.left+1;
	c_window_height=c_window_rect.bottom-c_window_rect.top+1;
	
	e_window_width=c_window_rect.right-e_window_rect.left+1;
	e_window_height=e_window_rect.bottom-e_window_rect.top+1;

	error_window_visible=0;

	console_window_visible=flags & 16 ? 0 : 1;

	c_window=NewWindow (NULL,&c_window_rect,"\pConsole",console_window_visible,0,(WindowPtr)-1,0,CONSOLE_WINDOW_ID);
	if (c_window==NULL)
		return 0;

	e_window=NewWindow (NULL,&e_window_rect,"\pMessages",0,0,(WindowPtr)-1,0,ERROR_WINDOW_ID);
	if (e_window==NULL)
		return 0;

#ifdef MACOSX
	SetPort (GetWindowPort (e_window));
#else	
	SetPort (e_window);
#endif
	TextFont (font_id);
	TextSize (font_size);
	
	GetFontInfo (&font_info);
	char_ascent=font_info.ascent;
	char_descent=font_info.descent;
	char_leading=font_info.leading;
	char_asc_lead=char_ascent+char_leading;
	char_height=char_asc_lead+char_descent;
	
	e_cur_y=0;
	e_cur_x=0;
	e_g_cur_x=0;
	n_e_screen_lines=UDIVW (e_window_height,char_height);

	MoveTo (0,char_asc_lead);

#ifdef MACOSX
	SetPort (GetWindowPort (c_window));
#else	
	SetPort (c_window);
#endif

	TextFont (font_id);
	TextSize (font_size);

	cur_y=0;
	cur_x=0;
	g_cur_x=0;
	n_screen_lines=UDIVW (c_window_height,char_height);

	MoveTo (0,char_asc_lead);
	
	if (console_window_visible){
		SelectWindow (c_window);
#ifdef MACOSX
		ValidWindowRect (c_window,&c_local_window_rect);
#else
		ValidRect (&c_local_window_rect);
#endif
}

	screen_chars=(SCREEN_LINE_CHARS*) NewPtr (n_screen_lines * (MAX_N_COLUMNS+1));
	if (screen_chars==NULL)
		return 0;

	for (n=0; n<n_screen_lines; ++n)
		screen_chars[n][0]=NEWLINE_CHAR;
	
	e_screen_chars=(SCREEN_LINE_CHARS*) NewPtr (n_e_screen_lines * (MAX_N_COLUMNS+1));
	if (e_screen_chars==NULL)
		return 0;
		
	for (n=0; n<n_e_screen_lines; ++n)
		e_screen_chars[n][0]=NEWLINE_CHAR;
	
	input_buffer=(char*) NewPtr (n_screen_lines * MAX_N_COLUMNS+1);
	if (input_buffer==NULL)
		return 0;
	
	input_buffer_length=0;

	return 1;
}

static void wait_key()
{
	while (1){
#ifndef MACOSX
		SystemTask();
#endif
		if (!GetNextEvent (everyEvent,&my_event))
			continue;
		switch (my_event.what){
			case keyDown:
				return;
			case updateEvt:
			case mouseDown:
				handle_update_or_mouse_down_event (&my_event);
				break;
		}
	}
}

#define VOID void

void wait_for_key_press (VOID)
{
#ifdef MAYBE_USE_STDIO
	if (use_stdio)
		return;
#endif
	SetWTitle ((flags & 16) && error_window_visible ? e_window : c_window,"\ppress any key to exit");
	wait_key();	
}

static void exit_terminal()
{
#ifdef MAYBE_USE_STDIO
	if (use_stdio)
		return;
#endif
	DisposeWindow (c_window);
	DisposeWindow (e_window);
/*
	CloseWindow (c_window);
	CloseWindow (e_window);
*/
}

static void get_font_number (char *font_name)
{
	char system_font_name[256];
	
	GetFNum ((unsigned char*)font_name,&font_id);
	
	if (font_id==0){
		char *s1,*s2;
		
		GetFontName (0,(unsigned char*)system_font_name);
		
		s1=system_font_name;
		s2=font_name;
		while (*s1==*s2 && *s1!='\0'){
			++s1;
			++s2;
		}
		if (*s1 || *s2)
			font_id=-1;
	}
}

#ifdef PARALLEL
void load_code_segments (VOID)
{
	int n_code_resources,resource_number;
		
	n_code_resources=Count1Resources ('CODE');
	
	for (resource_number=1; resource_number<=n_code_resources; ++resource_number){
		Handle resource;
	
		SetResLoad (1);
	
		resource=Get1Resource ('CODE',resource_number);
		if (resource!=NULL && !ResError()){
			MoveHHi (resource);
			HLock (resource);
		}
	}
}
#endif

#ifndef G_POWER
	extern int target_processor;
#endif

#ifdef SIMULATE
	extern int n_processors,processor_table_size;
	extern int processor_table,end_processor_table;
#endif

int wait_next_event_available;

#include <types.h>

#ifndef MACOSX
SysEnvRec system_environment;

# ifndef powerc
#pragma parameter __D0 MySysEnvirons (__D0, __A0)
extern pascal OSErr MySysEnvirons(short versionRequested, SysEnvRec *theWorld)
 ONEWORDINLINE(0xA090);
# else
#define MySysEnvirons SysEnvirons
# endif
#endif

#define MINIMUM_HEAP_SIZE_MULTIPLE ((2*256)+128)
#define MAXIMUM_HEAP_SIZE_MULTIPLE (100*256)

void (*exit_tcpip_function) (void);
#ifndef MACHO
extern void my_pointer_glue (void (*function) (void));
#endif

int execution_aborted;

#ifdef STACK_OVERFLOW_EXCEPTION_HANDLER
int *a_stack_guard_page,*b_stack_guard_page;

void *allocate_a_stack (int size)
{
	int alloc_size;
	char *p,*end_p;
	
	alloc_size=(size+4096+4095) & -4096;
	
# ifdef MACHO
	p=malloc (alloc_size);
# else
	p=NewPtr (alloc_size);
# endif
	if (p==NULL)
		return NULL;

	end_p=(char*)(((int)p+size+4095) & -4096);

	vm_protect (mach_task_self(),(int)end_p,4096,0,0);

	a_stack_guard_page=(int*)end_p;

	return (void*)((int)end_p-size);
}

extern int *halt_sp;
extern void stack_overflow (void);

#ifndef MACHO_EXCEPTIONS
struct sigaction old_BUS_sa,old_SEGV_sa;

static void clean_exception_handler (int sig,void *sip,struct sigcontext *scp)
{
	struct sigaction *old_sa_p;
	unsigned int instruction;
	int *registers,a;
		
	instruction=*(unsigned int*)(scp->sc_ir);
	registers = &((int *)scp->sc_regs)[2];
	
	switch (instruction>>26){
		case 36: /* stw */	case 37: /* stwu */
		case 38: /* stb */	case 39: /* stbu */
		case 44: /* sth */	case 45: /* sthu */
		case 47: /* stmw */
		case 54: /* stfd */	case 55: /* stfdu */
		{
			int reg_a,a_aligned_4k;
			
			reg_a=(instruction>>16) & 31;
			a=(short)instruction;
			if (reg_a)
				a+=registers[reg_a];
			
			a_aligned_4k = (int)a & -4096;
			
			if (a_aligned_4k==(int)b_stack_guard_page || a_aligned_4k==(int)a_stack_guard_page){
				scp->sc_ir = (int)&stack_overflow;
				registers[1]=(int)halt_sp;
				return;
			}
		}
	}
	
	old_sa_p = sig==SIGBUS ? &old_BUS_sa : &old_SEGV_sa;

	if (old_sa_p->sa_handler==SIG_DFL || old_sa_p->sa_handler==SIG_IGN)
		sigaction (sig,old_sa_p,NULL);
	else
# ifdef MACHO
		old_sa_p->sa_handler (sig,sip,scp);
# else
		call_function_3 (sig,sip,scp,old_sa_p->sa_handler);
# endif
}
#else
# define N_OLD_EXCEPTION_PORTS 64

static mach_msg_type_number_t n_ports;
static exception_mask_t old_exception_masks[N_OLD_EXCEPTION_PORTS];
static exception_handler_t old_exception_handlers[N_OLD_EXCEPTION_PORTS];
static exception_behavior_t old_exception_behaviors[N_OLD_EXCEPTION_PORTS];
static thread_state_flavor_t old_thread_state_flavors[N_OLD_EXCEPTION_PORTS];

static mach_port_t exception_port;

static kern_return_t forward_exception (mach_port_t thread,mach_port_t task,exception_type_t exception,exception_data_t code,mach_msg_type_number_t code_count)
{
	exception_mask_t exception_mask;
	exception_behavior_t behavior;
	int port_n;
	
	exception_mask=1<<exception;
	
	for (port_n=0; port_n<n_ports; ++port_n)
		if (old_exception_masks[port_n] & exception_mask)
			break;
	
	if (port_n!=n_ports)
		return KERN_INVALID_ARGUMENT;
	
	behavior=old_exception_behaviors[port_n];
	
	if (behavior==EXCEPTION_DEFAULT)
		return exception_raise (old_exception_handlers[port_n],thread,task,exception,code,code_count);
	else {
		thread_state_data_t thread_state;
		mach_msg_type_number_t thread_state_count;
		thread_state_flavor_t flavor;
		kern_return_t r;
		
		flavor=old_thread_state_flavors[port_n];
		
		thread_state_count=THREAD_STATE_MAX;
		
		r=thread_get_state (thread,flavor,thread_state,&thread_state_count);
		if (r!=KERN_SUCCESS)
			return r;

		if (behavior==EXCEPTION_STATE)
			r=exception_raise_state (old_exception_handlers[port_n],exception,code,code_count,&flavor,thread_state,thread_state_count,thread_state,&thread_state_count);
		else if (behavior==EXCEPTION_STATE_IDENTITY)
			r=exception_raise_state_identity (old_exception_handlers[port_n],thread,task,exception,code,code_count,&flavor,thread_state,thread_state_count,thread_state,&thread_state_count);
		else
			return KERN_INVALID_ARGUMENT;

		if (r!=KERN_SUCCESS)
			return r;
		
		r=thread_set_state (thread,flavor,thread_state,thread_state_count);
		if (r!=KERN_SUCCESS)
			return r;
	}
	
	return KERN_SUCCESS;
}

kern_return_t catch_exception_raise (mach_port_t exception_port,mach_port_t thread,mach_port_t task,exception_type_t exception,exception_data_t code,mach_msg_type_number_t code_count)
{
	mach_msg_type_number_t exception_state_count;
	ppc_exception_state_t exception_state;
	mach_msg_type_number_t thread_state_count;
	ppc_thread_state_t thread_state;
	int a_aligned_4k;

	if (exception!=EXC_BAD_ACCESS || !(code[0]==KERN_PROTECTION_FAILURE || code[0]==KERN_INVALID_ADDRESS))
		return forward_exception (thread,task,exception,code,code_count);
	
	exception_state_count=PPC_EXCEPTION_STATE_COUNT;
	
	if (thread_get_state (thread,PPC_EXCEPTION_STATE,(natural_t*)&exception_state,&exception_state_count)!=KERN_SUCCESS){
		/* printf ("thread_get_state failed\n"); */
		exit (1);
	}

	a_aligned_4k = ((int)exception_state.dar) & -4096;

	if (!(a_aligned_4k==(int)b_stack_guard_page || a_aligned_4k==(int)a_stack_guard_page))
		return forward_exception (thread,task,exception,code,code_count);
	
	thread_state_count=PPC_THREAD_STATE_COUNT;
	
	if (thread_get_state (thread,PPC_THREAD_STATE,(natural_t*)&thread_state,&thread_state_count)!=KERN_SUCCESS){
		/* printf ("thread_get_state failed\n"); */
		exit (1);
	}

	thread_state.srr0=(int)&stack_overflow;;
	thread_state.r1=(int)halt_sp;

	if (thread_set_state (thread,PPC_THREAD_STATE,(natural_t*)&thread_state,thread_state_count)!=KERN_SUCCESS){
		/* printf ("thread_set_state failed\n"); */
		exit (1);
	}

	/* printf ("catch_exception_raise called\n"); */
	return KERN_SUCCESS;
}

kern_return_t catch_exception_raise_state (mach_port_t exception_port,exception_type_t exception,
									exception_data_t code,mach_msg_type_number_t codeCnt,int *flavor,
        		                	thread_state_t old_state,mach_msg_type_number_t old_stateCnt,thread_state_t new_state,mach_msg_type_number_t new_stateCnt)
{
	/* printf ("exception_raise_state\n"); */
	return KERN_INVALID_ARGUMENT;
}

kern_return_t catch_exception_raise_state_identity (mach_port_t exception_port,mach_port_t thread,mach_port_t task,exception_type_t exception,
											  exception_data_t code,mach_msg_type_number_t codeCnt,int *flavor,
					                          thread_state_t old_state,mach_msg_type_number_t old_stateCnt,thread_state_t new_state,mach_msg_type_number_t new_stateCnt)
{
	/* printf ("exception_raise_state_identity\n"); */
	return KERN_INVALID_ARGUMENT;
}

static void *my_pthread (void *a)
{
	for (;;){
		char msg_data[1024],reply_data[1024];
		mach_msg_header_t *msg,*reply;
	
		msg=(mach_msg_header_t*)msg_data;
		reply=(mach_msg_header_t*)reply_data;
		
		if (mach_msg (msg,MACH_RCV_MSG,0,1024,exception_port,0,MACH_PORT_NULL)!=KERN_SUCCESS){
			/* printf ("mach_msg failed\n"); */
			exit (1);
		}

		/* printf ("msg received\n"); */
		
		if (!exc_server (msg,reply)){
			/* printf ("exc_server failed\n"); */
			exit (1);
		}
		
		if (mach_msg (reply,MACH_SEND_MSG,reply->msgh_size,0,msg->msgh_local_port,0,MACH_PORT_NULL)!=KERN_SUCCESS){
			/* printf ("mach_msg failed\n"); */
			exit (1);
		}
	}
}
#endif

# ifndef MACHO
extern int *get_TOC (void);
# endif

static void install_clean_exception_handler (void)
{
	{
		struct vm_region_basic_info vm_region_info;
# ifdef MACHO
		vm_address_t vm_address,previous_address;
		mach_msg_type_number_t info_count;
		memory_object_name_t object_name;
		vm_size_t vm_size;
# else
		int vm_address,previous_address;
		int info_count;
		int object_name;
		int vm_size;
		int *stack_top;
# endif
		int r,var_on_stack;
	
	 	vm_address=(int)&var_on_stack;
	 
		info_count=sizeof (vm_region_info);
# ifdef MACHO
		r=vm_region (mach_task_self(),&vm_address,&vm_size,VM_REGION_BASIC_INFO,(vm_region_info_t)&vm_region_info,&info_count,&object_name);
# else
		r=vm_region (mach_task_self(),&vm_address,&vm_size,10,(void*)&vm_region_info,&info_count,&object_name);
# endif
		if (r!=0)
			return;

# ifndef MACHO
		stack_top=(int*)(vm_address+vm_size);
# endif

		do {
			previous_address=vm_address;
			vm_address=vm_address-1;

			info_count=sizeof (vm_region_info);
# ifdef MACHO
			r=vm_region (mach_task_self(),&vm_address,&vm_size,VM_REGION_BASIC_INFO,(vm_region_info_t)&vm_region_info,&info_count,&object_name);
# else
			r=vm_region (mach_task_self(),&vm_address,&vm_size,10,(void*)&vm_region_info,&info_count,&object_name);
# endif
		} while (vm_address!=previous_address && r==0);

		b_stack_guard_page=(int*)((int)previous_address-4096);

# ifndef MACHO
		{
			int stack_size_aligned_4k;

			stack_size_aligned_4k = (stack_size+4095) & -4096;
			if ((unsigned int)b_stack_guard_page < (unsigned int)((int)stack_top-stack_size_aligned_4k-4096)){
				b_stack_guard_page=(int*)((int)stack_top-stack_size_aligned_4k-4096);
				vm_protect (mach_task_self(),(int)b_stack_guard_page,4096,0,0);
			}
		}
# endif
	}

# ifndef MACHO_EXCEPTIONS
	{
		struct sigaltstack sa_stack;
		void *signal_stack;
		struct sigaction sa;

#  ifdef MACHO
		signal_stack=(int*)malloc (MINSIGSTKSZ);
#  else
		signal_stack=(int*)NewPtr (8192);
#  endif
		if (signal_stack!=NULL){
#  ifndef MACHO
			int *handler_trampoline;
#  endif

			sa_stack.ss_sp=signal_stack;
#  ifdef MACHO
			sa_stack.ss_size=MINSIGSTKSZ;
#  else
			sa_stack.ss_size=8192;
#  endif
			sa_stack.ss_flags=0;

			sigaltstack (&sa_stack,NULL);

#  ifdef MACHO
			sa.sa_handler=&clean_exception_handler;
			sigemptyset (&sa.sa_mask);
			sa.sa_flags=SA_ONSTACK;//SA_SIGINFO;
#  else
			handler_trampoline = (int*) NewPtr (24);
			if (handler_trampoline!=NULL){
				int *handler_address,*toc_register;

				handler_address=*(int**)&clean_exception_handler;
				toc_register=get_TOC();

#  define i_dai_i(i,rd,ra,si)((i<<26)|((rd)<<21)|((ra)<<16)|((unsigned short)(si)))
#  define addis_i(rd,ra,si)	i_dai_i (15,rd,ra,si)
#  define addi_i(rd,ra,si)	i_dai_i (14,rd,ra,si)
#  define lis_i(rd,si)		addis_i (rd,0,si)
#  define bctr_i()			((19<<26)|(20<<21)|(528<<1))
#  define mtspr_i(spr,rs)	((31<<26)|((rs)<<21)|(spr<<16)|(467<<1))
#  define mtctr_i(rs)		mtspr_i (9,rs)

				handler_trampoline[0]=lis_i (6,((int)handler_address-(short)handler_address)>>16);
				handler_trampoline[1]=addi_i (6,6,(short)handler_address);
				handler_trampoline[2]=mtctr_i (6);
				handler_trampoline[3]=lis_i (2,((int)toc_register-(short)toc_register)>>16);
				handler_trampoline[4]=addi_i (2,2,(short)toc_register);
				handler_trampoline[5]=bctr_i();

				__icbi (handler_trampoline,0);
				__icbi (handler_trampoline,20);
				
				sa.sa_handler=(void(*)())handler_trampoline;
				sa.sa_mask=0;
				sa.sa_flags=1;
			}
#  endif
			sigaction (SIGSEGV,&sa,&old_SEGV_sa);
			sigaction (SIGBUS,&sa,&old_BUS_sa);
		}
	}
#else
	{
		mach_port_t my_mach_task;
		pthread_attr_t attr;
		pthread_t pthread;

		my_mach_task=mach_task_self();
		
		if (mach_port_allocate (my_mach_task,MACH_PORT_RIGHT_RECEIVE,&exception_port)!=KERN_SUCCESS){
			/* printf ("mach_port_allocate failed\n"); */
			return;
		}
		
		if (mach_port_insert_right (my_mach_task,exception_port,exception_port,MACH_MSG_TYPE_MAKE_SEND)!=KERN_SUCCESS){
			/* printf ("mach_port_insert_right failed\n"); */
			return;
		}

		if (task_get_exception_ports (my_mach_task,EXC_MASK_BAD_ACCESS,old_exception_masks,&n_ports,old_exception_handlers,old_exception_behaviors,old_thread_state_flavors)!=KERN_SUCCESS){
			/* printf ("task_get_exception_ports failed\n"); */
			return;
		}

		if (task_set_exception_ports (my_mach_task,EXC_MASK_BAD_ACCESS,exception_port,EXCEPTION_DEFAULT,MACHINE_THREAD_STATE)!=KERN_SUCCESS){
			/* printf ("task_get_exception_ports failed\n"); */
			return;
		}

		if (pthread_attr_init (&attr)!=0){
			/* printf ("pthread_attr_init failed\n"); */
			return;
		}

		if (pthread_attr_setdetachstate (&attr,PTHREAD_CREATE_DETACHED)!=0){
			/* printf ("pthread_attr_setdetach_state failed\n"); */
			return;
		}

		if (pthread_create (&pthread,&attr,my_pthread,NULL)!=0){
			/* printf ("pthread_create failed\n"); */
			return;
		}

		if (pthread_attr_destroy (&attr)!=0){
			/* printf ("pthread_attr_destroy failed\n"); */
			return;
		}
	}
# endif
}
#endif

#ifdef MACHO
int global_argc;
char **global_argv;

int return_code;

int main (int argc, char **argv)
#else
int main (void)
#endif
{
	Handle stack_handle,font_handle;
#ifdef WRITE_HEAP
	Handle profile_handle;
#endif
	long *stack_p;
	
#ifdef MACHO
	global_argc = argc;
	global_argv = argv;

	return_code=0;
#endif
#ifdef MAYBE_USE_STDIO
	{
	int i;
	
	use_stdio=1;
	for (i=1; i<argc; ++i){
		char *s;
		
		s=argv[i];
		if (s[0]=='-' && 
			((s[1]=='p' && s[2]=='s' && s[3]=='n') ||
			 (s[1]=='s' && s[2]=='t' && s[3]=='d' && s[4]=='w' && s[5]=='i' && s[6]=='n' && s[7]=='\0') )
			){
			use_stdio=0;
			break;
		}
	}
	}
#endif
	exit_tcpip_function=NULL;
	execution_aborted=0;

#ifdef WRITE_HEAP
	profile_handle=GetResource ('PRFL',128);
	if (profile_handle!=NULL && *profile_handle!=NULL)
		min_write_heap_size=**(long**)profile_handle;
#endif

#ifdef G_POWER
	stack_handle=GetResource ('STHP',0);
#else
	stack_handle=GetResource ('STCK',0);
#endif
	stack_p=*(long**)stack_handle;

	stack_size=(stack_p[0]+3) & ~3;
	heap_size=(stack_p[2]+7) & ~7;
	flags=stack_p[3];

#ifdef STACK_OVERFLOW_EXCEPTION_HANDLER
	install_clean_exception_handler();
#endif

#ifdef SIMULATE
	n_processors=stack_p[1];
	if (n_processors<1)
		n_processors=1;
	if (n_processors>1024)
		n_processors=1024;
#else
# ifdef G_POWER
	heap_size_multiple=stack_p[1];
	if (heap_size_multiple<MINIMUM_HEAP_SIZE_MULTIPLE)
		heap_size_multiple=MINIMUM_HEAP_SIZE_MULTIPLE;
	if (heap_size_multiple>MAXIMUM_HEAP_SIZE_MULTIPLE)
		heap_size_multiple=MAXIMUM_HEAP_SIZE_MULTIPLE;
	initial_heap_size=(stack_p[4]+7) & ~7;
# endif
#endif

#ifndef MACOSX
# ifndef PARALLEL
	SetApplLimit (GetApplLimit()-stack_size-1024);
# else
	SetApplLimit (GetApplLimit()-heap_size-stack_size-1024);
# endif
	if (MemError()!=0)
		return 0;
#endif

#ifdef PARALLEL
	load_code_segments();
#endif
	
	font_id=-1;

	
	font_handle=GetResource ('Font',128);
	if (font_handle!=NULL){
		get_font_number ((char*)((*(short **)font_handle)+1));
		font_size=**(short**)font_handle;
	}

	if (font_id==-1){
#ifdef NEW_HEADERS
		font_id=kFontIDMonaco;
#else
		font_id=monaco;
#endif
		font_size=9;
	}
	
	if (!init_terminal())
		return 1;

#ifdef G_POWER
	wait_next_event_available=1;
#else
# ifdef powerc
	if (NGetTrapAddress (0xA860,ToolTrap)!=GetTrapAddress (0xA89F))
# else
	if (GetToolTrapAddress (0xA860)!=GetTrapAddress (0xA89F))
# endif
		wait_next_event_available=-1;
	else
		wait_next_event_available=0;
#endif

#ifndef MACOSX
	if (MySysEnvirons (1,&system_environment)==noErr){
# ifndef G_POWER
		switch (target_processor){
			case 2:
				if (system_environment.processor==env68000 ||
					system_environment.processor==env68010 ||
					system_environment.hasFPU==0)
				{
					ew_print_string ("This program requires a MC68020 processor with MC68881 coprocessor or better\n");

					wait_for_key_press();
					exit_terminal();
					return 0;
				}
				break;
			case 1:
				if (system_environment.processor==env68000 ||
					system_environment.processor==env68010)
				{
					ew_print_string ("This program requires a MC68020 processor or better\n");

					wait_for_key_press();
					exit_terminal();
					return 0;
				}
		}
# endif
	}
#endif

#ifdef SIMULATE
	processor_table_size=n_processors*64;
	processor_table=(int) NewPtr (processor_table_size);
	end_processor_table=processor_table+processor_table_size;
#endif

#ifdef COMMUNICATION
	if (init_communication())
#endif

	abc_main();

#ifdef COMMUNICATION
	exit_communication();
#endif

	if (exit_tcpip_function!=NULL)
#ifdef MACHO
		exit_tcpip_function();
#else
		my_pointer_glue (exit_tcpip_function);
#endif

	if (!(flags & 16) || (flags & 8) || execution_aborted!=0){
#ifdef COMMUNICATION
		if (my_processor_id==0)
#endif
		wait_for_key_press();
	}
	exit_terminal();
	
#ifdef G_POWER
	first_function();
#endif

#ifdef MACHO
	if (return_code==0 && execution_aborted!=0)
		return_code= -1;

	return return_code;
#else
	return 0;
#endif
}

#if defined (TIME_PROFILE) || defined (MACHO)
void create_profile_file_name (unsigned char *profile_file_name)
{
	unsigned char *cur_ap_name,*end_profile_file_name;
	int cur_ap_name_length,profile_file_name_length,n;
		
	cur_ap_name=(unsigned char *)LMGetCurApName();
	cur_ap_name_length=cur_ap_name[0];
	++cur_ap_name;	
	
	for (n=0; n<cur_ap_name_length; ++n)
		profile_file_name[8+n]=cur_ap_name[n];
	
	profile_file_name_length=cur_ap_name_length+13;
	if (profile_file_name_length>31)
		profile_file_name_length=31;

	*((unsigned int*)&profile_file_name[4])=profile_file_name_length;
	
	end_profile_file_name=&profile_file_name[8+profile_file_name_length];
	
	end_profile_file_name[-13]=' ';
	end_profile_file_name[-12]='T';
	end_profile_file_name[-11]='i';
	end_profile_file_name[-10]='m';
	end_profile_file_name[-9]='e';
	end_profile_file_name[-8]=' ';
	end_profile_file_name[-7]='P';
	end_profile_file_name[-6]='r';
	end_profile_file_name[-5]='o';
	end_profile_file_name[-4]='f';
	end_profile_file_name[-3]='i';
	end_profile_file_name[-2]='l';
	end_profile_file_name[-1]='e';
}
#endif

#if defined(G_POWER)
static void my_user_item_proc (DialogPtr dialog_p,int the_item)
{
	short item_type;
	Handle item_handle;
	Rect item_rect;
	PenState pen_state;
	
	GetDialogItem (dialog_p,the_item,&item_type,&item_handle,&item_rect);
	
	GetPenState (&pen_state);
	PenNormal();
	PenSize (3,3);
	InsetRect (&item_rect,-4,-4);
	FrameRoundRect (&item_rect,16,16);
	SetPenState (&pen_state);
}

#if defined (MACOSX) && !defined (NEW_HEADERS)
extern UserItemUPP NewUserItemUPP (ProcPtr);
#endif

#ifdef NEW_HEADERS
int
#else
UserItemUPP
#endif
	myoutlinebuttonfunction (void)
{
#ifdef MACOSX
	return NewUserItemUPP (my_user_item_proc);
#else
	return NewUserItemProc (my_user_item_proc);
#endif
}

#ifndef NEW_HEADERS
QDGlobals *qdglobals (void)
{
	return &qd;
}
#endif

#endif
