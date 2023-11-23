
#include <AppleEvents.h>
#include <AERegistry.h>
#include <Files.h>
#include <Events.h>

#if TARGET_API_MAC_CARBON
/* for gcc */
#define NewAEEventHandlerProc(a) NewAEEventHandlerUPP(a)
/* */
#endif

#undef DEBUG_FILE

#ifdef DEBUG_FILE
#include <LowMem.h>
#endif

static char *result_string;
static int n_free_result_string_characters;

static int string_begins_with (char *s1,char *s2)
{
	while (*s2!='\0'){
		if (*s2!=*s1)
			return 0;
		++s2;
		++s1;
	}
	
	return 1;
}

#define RefConType /*unsigned*/ long

static pascal OSErr DoAEOpenApplication (const AppleEvent *theAppleEvent,AppleEvent *replyAppleEvent,RefConType refCon)
{
	return noErr;
}

static int has_required_parameters (const AppleEvent *theAppleEvent)
{
	Size actual_size;
	DescType returned_type;
	OSErr r;
	
	r=AEGetAttributePtr (theAppleEvent,keyMissedKeywordAttr,typeWildCard,&returned_type,NULL,0,&actual_size);
	if (r==errAEDescNotFound)
		return noErr;
	if (r==noErr)
		r=errAEEventNotHandled;
	return r;
}

static pascal OSErr DoAEOpenDocuments (const AppleEvent *theAppleEvent,AppleEvent *replyAppleEvent,RefConType refCon)
{
	OSErr r;
	AEDescList document_list;

	if (n_free_result_string_characters<4){
		n_free_result_string_characters=0;
		result_string=NULL;
		return 0;
	}

	result_string[0]='O';
	result_string[1]='P';
	result_string[2]='E';
	result_string[3]='N';		
	result_string+=4;
	n_free_result_string_characters-=4;
	
	r=AEGetParamDesc (theAppleEvent,keyDirectObject,typeAEList,&document_list);
	
	if (r==noErr){
		r=has_required_parameters (theAppleEvent);

		if (r==noErr){
			long n_items;
		
			r=AECountItems (&document_list,&n_items);
						
			if (r==noErr){
				long i;
				
				for (i=1; i<=n_items; ++i){
					AEKeyword keyword;
					DescType returned_type;
					FSSpec fss;
					Size actual_size;

					r=AEGetNthPtr (&document_list,i,typeFSS,&keyword,&returned_type,&fss,sizeof (FSSpec),&actual_size);
					
					if (r!=noErr)
						break;
					
					if (n_free_result_string_characters<sizeof (FSSpec)){
						AEDisposeDesc (&document_list);
						n_free_result_string_characters=0;
						result_string=NULL;
						return 0;
					}
					
					*(FSSpec*)result_string=fss;
					result_string+=sizeof (FSSpec);
					n_free_result_string_characters-=sizeof (FSSpec);
				}
			}
		}
	}

	AEDisposeDesc (&document_list);

	if (r!=noErr){
		result_string=NULL;
		n_free_result_string_characters=0;
	}
	
	return r;
}
 
static pascal OSErr DoAEPrintDocuments (const AppleEvent *theAppleEvent,AppleEvent *replyAppleEvent,RefConType refCon)
{
	return errAEEventNotHandled;
}
 
static pascal OSErr DoAEQuitApplication (const AppleEvent *theAppleEvent,AppleEvent *replyAppleEvent,RefConType refCon)
{
	if (n_free_result_string_characters>=4){
		result_string[0]='Q';
		result_string[1]='U';
		result_string[2]='I';
		result_string[3]='T';		
		result_string+=4;
		n_free_result_string_characters-=4;
	}
	return noErr;
}

extern pascal OSErr do_script_apple_event (const AppleEvent *apple_event,AppleEvent *replyAppleEvent,RefConType refCon);

extern int clean2_compile (int);

static int compiler_id=-1;

static int last_exit_code=0;

#ifdef DEBUG_FILE
static short debug_file_ref_num=0;
#endif

static pascal OSErr DoAEScript (const AppleEvent *apple_event,AppleEvent *replyAppleEvent,RefConType refCon)
{
	DescType returned_type;
	long actual_size;
	int error,exit_code;
	char *result_string_begin;

	result_string_begin=result_string;
	
	if (n_free_result_string_characters>=6){
		result_string[0]='S';
		result_string[1]='C';
		result_string[2]='R';
		result_string[3]='I';
		result_string[4]='P';
		result_string[5]='T';
		result_string+=6;
		n_free_result_string_characters-=6;
	}

	error=AEGetParamPtr (apple_event,keyDirectObject,'TEXT',&returned_type,result_string,n_free_result_string_characters,&actual_size);

	if (error!=noErr || actual_size > n_free_result_string_characters){
		result_string=NULL;
		n_free_result_string_characters=0;
	} else

#ifdef DEBUG_FILE
	{
		long count;
		ParamBlockRec parameter_block;

		count=actual_size;
		FSWrite (debug_file_ref_num,&count,result_string);

		count=1;
		FSWrite (debug_file_ref_num,&count,"\n");

		parameter_block.ioParam.ioRefNum=debug_file_ref_num;
		PBFlushFileSync (&parameter_block);
	}
#endif

#if 1
	/* RWS ... : ugly, special case for Clean IDE / cg combo */
	if (string_begins_with (result_string, "cg ")
		|| string_begins_with (result_string, "cg_o ")
		|| string_begins_with (result_string, "cg_xo ")
		|| string_begins_with (result_string, "cg_cxo "))
	{
		exit_code=do_script_apple_event (apple_event, replyAppleEvent, refCon);

		last_exit_code = exit_code;
	}
	/* ... RWS */
	else
#endif
	if (string_begins_with (result_string,"cocl ")){
		int string_length;
		
		result_string += actual_size;
		string_length=result_string-result_string_begin;

		result_string=NULL;

#if 0
		{
			int n;

			exit_code=clean2_compile (string_length);
			
			n=5;
			while (n<string_length-5){
				if (   result_string_begin[n]=='-'
					&& result_string_begin[n+1]=='i'
					&& result_string_begin[n+2]=='d'
					&& result_string_begin[n+3]==' ')
				{
					compiler_id=result_string_begin[n+4]-'0';
					break;
				}
				
				++n;
			}
		}
		exit_code=1;
#else
		exit_code=clean2_compile (string_length);
#endif

		if (compiler_id>=0){
			exit_code += (compiler_id+1)<<1;
			compiler_id=-1;
		}
		
		last_exit_code = exit_code;
	} else if (string_begins_with (result_string,"repeat_result")){
		result_string=NULL;
		n_free_result_string_characters=0;

		exit_code=last_exit_code;
	} else {
		result_string += actual_size;

		return 1;
	}
	
	{
		int error_code1;
		
		error_code1 = AEPutParamPtr (replyAppleEvent,keyErrorNumber,typeLongInteger,&exit_code,4);

#ifdef DEBUG_FILE
		{
			long count;
			ParamBlockRec parameter_block;
			char hex_number[20];
			int i;
		
			for (i=0; i<8; ++i){
				unsigned int d;
				
				d=exit_code<<(i<<2);
				d>>=28;
				hex_number[i]= d<10 ? '0'+d : 'A'+(d-10);
			}
		
			count=8;
			FSWrite (debug_file_ref_num,&count,hex_number);
		
			for (i=0; i<8; ++i){
				unsigned int d;
				
				d=error_code1<<(i<<2);
				d>>=28;
				hex_number[i]= d<10 ? '0'+d : 'A'+(d-10);
			}
		
			count=8;
			FSWrite (debug_file_ref_num,&count,hex_number);
		
			count=1;
			FSWrite (debug_file_ref_num,&count,"\n");
		
			parameter_block.ioParam.ioRefNum=debug_file_ref_num;
			PBFlushFileSync (&parameter_block);
		}
#endif			
	}

	return exit_code;
}

int set_compiler_id (int id)
{
	compiler_id=id;

	return id;
}

int install_apple_event_handlers (void)
{
	OSErr r;

#ifdef DEBUG_FILE
	unsigned char *file_name_p,*app_file_name_p,*p,file_name[64];
	int n,l;

	app_file_name_p=LMGetCurApName();
	n=*app_file_name_p;
	p=&app_file_name_p[1];

	file_name_p=&file_name[1];
	l=0;
	
	while (n!=0){
		*file_name_p++ = *p++;
		++l;
		--n;
	}
	
	p=(unsigned char*)" debug";
	
	while (*p){
		*file_name_p++ = *p++;
		++l;	
	}
	
	file_name[0]=l;
	
	HCreate (0,0,file_name,'3PRM','TEXT');

	HOpen (0,0,file_name,fsWrPerm,&debug_file_ref_num);
#endif

	r=AEInstallEventHandler (kCoreEventClass,kAEOpenApplication,NewAEEventHandlerProc (DoAEOpenApplication),0,false);

	if (r==noErr)
		r=AEInstallEventHandler (kCoreEventClass,kAEOpenDocuments,NewAEEventHandlerProc (DoAEOpenDocuments),0,false);

	if (r==noErr)
		r=AEInstallEventHandler (kCoreEventClass,kAEPrintDocuments,NewAEEventHandlerProc (DoAEPrintDocuments),0,false);

	if (r==noErr)
		r=AEInstallEventHandler (kCoreEventClass,kAEQuitApplication,NewAEEventHandlerProc (DoAEQuitApplication),0,false);

	if (r==noErr)
		r=AEInstallEventHandler (kAEMiscStandards,kAEDoScript,NewAEEventHandlerProc (DoAEScript),0,false);
		
	return r;
}

int handle_apple_event (EventRecord *event_p,long *clean_string)
{	
	char *string;
	int string_length;
	
	string_length=clean_string[1];
	string=(char*)&clean_string[2];

	result_string=string;
	n_free_result_string_characters=string_length;

	AEProcessAppleEvent (event_p);

	if (result_string!=NULL)
		string_length=result_string-string;
	else
		string_length=0;
	
	result_string=NULL;
	n_free_result_string_characters=0;

	return string_length;
}

static char apple_event_string[2052];

int handle_apple_event2 (int what,int message,int when,int p1,int p2,int modifiers)
{
	EventRecord event;
	char *string;
	int string_length;

	event.what=what;
	event.message=message;
	event.when=when;
	event.where.h=p1;
	event.where.v=p2;
	event.modifiers=modifiers;
	
	string_length=2048;
	string=apple_event_string;

	result_string=string;
	n_free_result_string_characters=string_length;

	AEProcessAppleEvent (&event);

	if (result_string!=NULL)
		string_length=result_string-string;
	else
		string_length=0;
	
	result_string=NULL;
	n_free_result_string_characters=0;

	return string_length;
}

int get_apple_event_string (int length,long *clean_string)
{
	char *string;
	int string_length;
	
	string_length=clean_string[0];
	string=(char*)&clean_string[1];

	if (length==string_length){
		int i;
		
		for (i=0; i<string_length; ++i)
			string[i]=apple_event_string[i];
	} else
		string_length=0;

	return string_length;
}

