/*
	File:		cgcon.c
	Written by:	John van Groningen
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MULW(a,b) ((int)((short)(a)*(short)(b)))
#define UDIVW(a,b) ((unsigned short)((unsigned short)(a)/(unsigned short)(b)))

#include <quickdraw.h>
#include <fonts.h>
#include <events.h>
#include <windows.h>
#include <desk.h>
#include <memory.h>
#include <resources.h>
#include <menus.h>
#include <OSUtils.h>
#include <OSEvents.h>

#undef PARALLEL
#undef SIMULATE
#undef COMMUNICATION

#include "cgcon.h"
#ifdef COMMUNICATION
#	include "cgcom.h"
#endif

#ifdef G_POWER
void first_function (void)
{
}
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

static void update_window (	WindowPtr window,SCREEN_LINE_CHARS *chars,int n_lines,int g_cur_x,int cur_y)
{
	int y,screen_y_pos;
	GrafPtr old_port;
	
	BeginUpdate (window);
	GetPort(&old_port);
	SetPort (window);
	
	EraseRgn (window->visRgn);
	
	for (y=0,screen_y_pos=char_asc_lead; y<n_lines; ++y,screen_y_pos+=char_height){
		char *line_chars,*c_p;
		int line_length;
		
		MoveTo (0,screen_y_pos);
		line_chars=chars[y];
		
		line_length=0;
		c_p=line_chars;
		while (*c_p++!='\n')
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
	
	add_execute_time();
	
	erase_region=NewRgn();
	ScrollRect (&window->portRect,0,-char_height,erase_region);
	EraseRgn (erase_region);
	DisposeRgn (erase_region);

	BlockMove ((char*)chars[1],(char*)chars,(MAX_N_COLUMNS+1)*(n_lines-1));
	chars[n_lines-1][0]='\n';
	
	add_IO_time();
}

static void print_newline()
{
	screen_chars[cur_y][cur_x]='\n';
	++cur_y;
	cur_x=0;
	g_cur_x=0;
	if (cur_y>=n_screen_lines){
		cur_y=n_screen_lines-1;
		scroll_window (c_window,screen_chars,n_screen_lines);
	} 
	MoveTo (0,MULW(cur_y,char_height)+char_asc_lead);
}
	
static void window_print_char (char c)
{	
	if (c=='\n')
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
		screen_char[1]='\n';
		DrawChar (c);
		++cur_x;
	}
}

static void make_error_window_visible ()
{
	if (!error_window_visible){
		add_execute_time();
		ShowWindow (e_window);
		ValidRect (&e_local_window_rect);
		add_IO_time();
		error_window_visible=1;
	}
}

static void make_console_window_visible ()
{
	if (!console_window_visible){
		add_execute_time();
		ShowWindow (c_window);
		ValidRect (&c_local_window_rect);
		add_IO_time();
		console_window_visible=1;
	}
}

#ifdef powerc
   QDGlobals qd;
#endif
   QDGlobals qd;

void w_print_char (char c)
{
	GrafPtr port;
	
	port=NULL;
	if (qd.thePort!=c_window){
		port=qd.thePort;
		SetPort (c_window);
	}

	if (!console_window_visible)
		make_console_window_visible();

	window_print_char (c);
	
	if (port!=NULL)
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
		*screen_char='\n';
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
	
	port=NULL;
	if (qd.thePort!=c_window){
		port=qd.thePort;
		SetPort (c_window);
	}

	if (!console_window_visible)
		make_console_window_visible();

	end_s=s;
	while (length!=0){
		while (length!=0 && (c=*end_s,c!='\n')){
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
	
	if (port!=NULL)
		SetPort (port);
}

static void e_print_newline()
{
	e_screen_chars[e_cur_y][e_cur_x]='\n';
	++e_cur_y;
	e_cur_x=0;
	e_g_cur_x=0;
	if (e_cur_y>=n_e_screen_lines){
		e_cur_y=n_e_screen_lines-1;
		scroll_window (e_window,e_screen_chars,n_e_screen_lines);
	}
	MoveTo (0,MULW(e_cur_y,char_height)+char_asc_lead);
}

static void e_print_char (char c)
{	
	if (c=='\n')
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
		screen_char[1]='\n';
		DrawChar (c);
		++e_cur_x;
	}
}

void ew_print_char (char c)
{
	GrafPtr port;
	
	port=NULL;
	if (qd.thePort!=e_window){
		port=qd.thePort;
		SetPort (e_window);
	}

	if (!error_window_visible)
		make_error_window_visible();

	e_print_char (c);

	if (port!=NULL)
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
		*screen_char='\n';
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
		while (length!=0 && (c=*end_s,c!='\n')){
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
	
	port=NULL;
	if (qd.thePort!=e_window){
		port=qd.thePort;
		SetPort (e_window);
	}

	if (!error_window_visible)
		make_error_window_visible();
	
	e_print_text (s,length);

	if (port!=NULL)
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
		SystemTask();
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
					while (c=screen_line[line_length],c!='\n'){
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
					*screen_char='\n';
					g_cur_x-=w;
					--n_chars_read;
					w_remove_char (w);				
				}
			}
		} else {
			if (c=='\n'){
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
				screen_char[1]='\n';
				DrawChar (c);
				++cur_x;
				++n_chars_read;
			}
		}
	} while (c!='\n');
	
	{
		char *char_p,*screen_p;
		
		input_buffer_length=n_chars_read+1;
		input_buffer_pos=0;
		
		char_p=input_buffer;
		screen_p=&screen_chars[b_cur_y][b_cur_x];
		while (n_chars_read!=0){
			int c;
			
			while (c=*screen_p++,c=='\n'){
				++b_cur_y;
				screen_p=screen_chars[b_cur_y];
			}
			*char_p++=c;
			--n_chars_read;
		}
		*char_p++='\n';
	}
}

int w_get_char()
{
	int c;

	if (input_buffer_length==0){
		GrafPtr port;
		
		port=NULL;
		if (qd.thePort!=c_window){
			port=qd.thePort;
			SetPort (c_window);
		}
	
		if (!console_window_visible)
			make_console_window_visible();
	
		w_read_line();
	
		if (port!=NULL)
			SetPort (port);
	}
	
	c=input_buffer[input_buffer_pos] & 0xff;
	++input_buffer_pos;
	--input_buffer_length;
	
	return c;
}

#define is_digit(n) ((unsigned)((n)-'0')<(unsigned)10)

int w_get_int (int *i_p)
{
	int c,negative;
	unsigned int i;
	
	c=w_get_char();
	while (c==' ' || c=='\t' || c=='\n')
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
		--input_buffer_pos;
		++input_buffer_length;
	
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

	--input_buffer_pos;
	++input_buffer_length;

	*i_p=i;
	return -1;
}

int w_get_real (double *r_p)
{
	char s[256+1];
	int c,dot,digits,result,n;
	
	n=0;
	
	c=w_get_char();
	while (c==' ' || c=='\t' || c=='\n')
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

	--input_buffer_pos;
	++input_buffer_length;

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
	
	port=NULL;
	if (qd.thePort!=c_window){
		port=qd.thePort;
		SetPort (c_window);
	}
	
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
	
	if (port!=NULL)
		SetPort (port);
	
	return length;
}

void w_print_string (char *s)
{
	char *end_s,c;
	GrafPtr port;
	
	port=NULL;
	if (qd.thePort!=c_window){
		port=qd.thePort;
		SetPort (c_window);
	}
	
	if (!console_window_visible)
		make_console_window_visible();

	end_s=s;
	while (*s!='\0'){
		while (c=*end_s,c!='\0' && c!='\n')
			++end_s;
		w_print_text_without_newlines (s,end_s-s);
		if (*end_s=='\0')
			break;
		print_newline();
		s=++end_s;
	}
	
	if (port!=NULL)
		SetPort (port);
}

void ew_print_string (char *s)
{
	char *end_s,c;
	GrafPtr port;
	
	port=NULL;
	if (qd.thePort!=e_window){
		port=qd.thePort;
		SetPort (e_window);
	}

	if (!error_window_visible)
		make_error_window_visible();
	
	end_s=s;
	while (*s!='\0'){
		while (c=*end_s,c!='\0' && c!='\n')
			++end_s;
		e_print_text_without_newlines (s,end_s-s);
		if (*end_s=='\0')
			break;
		e_print_newline();
		s=++end_s;
	}

	if (port!=NULL)
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
	
	port=NULL;
	if (qd.thePort!=c_window){
		port=qd.thePort;
		SetPort (c_window);
	}
	
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

	if (port!=NULL)
		SetPort (port);
}

void ew_print_int (int n)
{
	char int_string [32];
	GrafPtr port;

	port=NULL;
	if (qd.thePort!=e_window){
		port=qd.thePort;
		SetPort (e_window);
	}
	
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

	if (port!=NULL)
		SetPort (port);
}

void w_print_real (double r)
{
	char real_string [40];
	GrafPtr port;
	
	port=NULL;
	if (qd.thePort!=c_window){
		port=qd.thePort;
		SetPort (c_window);
	}
	
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

	if (port!=NULL)
		SetPort (port);
}

void ew_print_real (double r)
{
	char real_string [40];
	GrafPtr port;
	
	port=NULL;
	if (qd.thePort!=e_window){
		port=qd.thePort;
		SetPort (e_window);
	}
	
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

	if (port!=NULL)
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

#ifdef NO_INIT	
	InitGraf (&qd.thePort);
	InitFonts();
	FlushEvents (everyEvent,0);
	InitWindows();
	InitCursor();
	InitMenus();
#endif

	three=3; ten=10;	/* to get a divw instead of a divl */

	screen_top=qd.thePort->portRect.top;
	screen_left=qd.thePort->portRect.left;
	screen_bottom=qd.thePort->portRect.bottom;
	screen_right=qd.thePort->portRect.right;
	
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

	SetPort (e_window);
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
	
	SetPort (c_window);

	TextFont (font_id);
	TextSize (font_size);

	cur_y=0;
	cur_x=0;
	g_cur_x=0;
	n_screen_lines=UDIVW (c_window_height,char_height);

	MoveTo (0,char_asc_lead);
	
	if (console_window_visible){
		SelectWindow (c_window);
		ValidRect (&c_local_window_rect);
	}

	screen_chars=(SCREEN_LINE_CHARS*) NewPtr (n_screen_lines * (MAX_N_COLUMNS+1));
	if (screen_chars==NULL)
		return 0;

	for (n=0; n<n_screen_lines; ++n)
		screen_chars[n][0]='\n';
	
	e_screen_chars=(SCREEN_LINE_CHARS*) NewPtr (n_e_screen_lines * (MAX_N_COLUMNS+1));
	if (e_screen_chars==NULL)
		return 0;
		
	for (n=0; n<n_e_screen_lines; ++n)
		e_screen_chars[n][0]='\n';
	
	input_buffer=(char*) NewPtr (n_screen_lines * MAX_N_COLUMNS+1);
	if (input_buffer==NULL)
		return 0;
	
	input_buffer_length=0;
	
	return 1;
}

static void wait_key()
{
	while (1){
		SystemTask();
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
	SetWTitle (flags & 16 ? e_window : c_window,"\ppress any key to exit");
	wait_key();	
}

static void exit_terminal()
{
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

SysEnvRec system_environment;
int wait_next_event_available;

#include <types.h>

#ifndef powerc
#pragma parameter __D0 MySysEnvirons (__D0, __A0)
extern pascal OSErr MySysEnvirons(short versionRequested, SysEnvRec *theWorld)
 ONEWORDINLINE(0xA090);
#else
#define MySysEnvirons SysEnvirons
#endif

#define MINIMUM_HEAP_SIZE_MULTIPLE ((2*256)+128)
#define MAXIMUM_HEAP_SIZE_MULTIPLE (100*256)

void (*exit_tcpip_function) (void);
extern void my_pointer_glue (void (*function) (void));

int execution_aborted;

int main (void)
{
	Handle stack_handle,font_handle;
#ifdef WRITE_HEAP
	Handle profile_handle;
#endif
	long *stack_p;
	
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

#ifndef PARALLEL
	SetApplLimit (GetApplLimit()-stack_size-1024);
#else
	SetApplLimit (GetApplLimit()-heap_size-stack_size-1024);
#endif
	if (MemError()!=0)
		return 0;

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
		font_id=monaco;
		font_size=9;
	}
	
	if (!init_terminal())
		return 1;

/*	srand (TickCount()); */

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

	if (MySysEnvirons (1,&system_environment)==noErr){
#ifndef G_POWER
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
#endif
	}

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
		my_pointer_glue (exit_tcpip_function);

	if (!(flags & 16) || (flags & 8) || execution_aborted!=0)
#ifdef COMMUNICATION
		if (my_processor_id==0)
#endif
		wait_for_key_press();
	exit_terminal();
	
#ifdef G_POWER
	first_function();
#endif

	return 0;
}

#ifdef TIME_PROFILE
void create_profile_file_name (unsigned char *profile_file_name)
{
	unsigned char *cur_ap_name,*end_profile_file_name;
	int cur_ap_name_length,profile_file_name_length,n;
		
	cur_ap_name=LMGetCurApName();
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

#ifdef G_POWER
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

UserItemUPP myoutlinebuttonfunction (void)
{
	return NewUserItemProc (my_user_item_proc);
}

QDGlobals *qdglobals (void)
{
	return &qd;
}
#endif
