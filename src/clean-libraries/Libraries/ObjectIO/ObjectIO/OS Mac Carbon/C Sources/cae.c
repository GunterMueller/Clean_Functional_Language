#define CARBON 1

#ifdef __MACH__
#include <Carbon/Carbon.h>
#else
#ifdef CARBON
#include <Carbon.h>
#else
#include <MacTypes.h>
#include <Files.h>
#include <Events.h>
#include <EPPC.h>
#include <AppleEvents.h>
#include <AERegistry.h>
#endif
#endif

#ifdef __MACH__
# define NewAEEventHandlerProc(p) NewAEEventHandlerUPP(p)
#else
#ifdef CARBON
# define NewAEEventHandlerProc(p) NewAEEventHandlerUPP(p)
#endif
#endif

static char *result_string;
static int n_free_result_string_characters;

static pascal OSErr DoAEOpenApplication (const AppleEvent *theAppleEvent,AppleEvent *replyAppleEvent,long refCon)
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

static pascal OSErr DoAEOpenDocuments (const AppleEvent *theAppleEvent,AppleEvent *replyAppleEvent, long refCon)
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
		r = noErr;

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

static pascal OSErr DoAEPrintDocuments (const AppleEvent *theAppleEvent,AppleEvent *replyAppleEvent,long refCon)
{
	return errAEEventNotHandled;
}

static int in_handle_apple_event = 0;
static int received_quit = 0;

int ReceivedQuit(void)
{
	return received_quit;
}

static pascal OSErr DoAEQuitApplication (const AppleEvent *theAppleEvent,AppleEvent *replyAppleEvent,long refCon)
{
//	DebugStr("\pDoAEQuitApplication");
	if (!in_handle_apple_event){
//		AESend(theAppleEvent,replyAppleEvent,kAENoReply,kAENormalPriority,kAEDefaultTimeout,NULL,NULL);
		received_quit = 1;
		return noErr;
	}
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

static pascal OSErr DoAEScript (const AppleEvent *apple_event,AppleEvent *replyAppleEvent,long refCon)
{
	DescType returned_type;
	long actual_size;
	int error;

//	DebugStr("\pDoAEScript");
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

	if (error!=noErr){
		result_string=NULL;
		n_free_result_string_characters=0;
	} else {
		n_free_result_string_characters-=actual_size;
		result_string+=actual_size;	
	}

	return error;
}

static pascal OSErr DoAEApplicationDied (const AppleEvent *apple_event,AppleEvent *replyAppleEvent,long refCon)
{ 
	DescType returned_type;
	long actual_size;
	int error;
	
//	DebugStr("\pDoAEApplicationDied");
	if (n_free_result_string_characters>=7){	
		result_string[0]='A';
		result_string[1]='P';
		result_string[2]='P';
		result_string[3]='D';
		result_string[4]='I';
		result_string[5]='E';
		result_string[6]='D';
		result_string+=7;
		n_free_result_string_characters-=7;
	}

	error = AEGetParamPtr (apple_event,keyProcessSerialNumber,typeProcessSerialNumber,&returned_type,result_string,n_free_result_string_characters,&actual_size);	
	if (error==noErr){
		n_free_result_string_characters-=actual_size;
		result_string+=actual_size;
	}

//	DebugStr("\pDoAEApplicationDied exit");
	return error;
}

#define MAX_N_COMPILERS 32

static int compiler_finished[MAX_N_COMPILERS]={0};
static int compiler_exit_code[MAX_N_COMPILERS];

static int n_unknown_finished_compilers=0;

static pascal OSErr DoAEAnswer (const AppleEvent *apple_event,AppleEvent *replyAppleEvent,long refCon)
{
	DescType returned_type;
	long actual_size;
	int error;

//	DebugStr("\pDoAEAnswer");
	if (n_free_result_string_characters>=6){
		result_string[0]='A';
		result_string[1]='N';
		result_string[2]='S';
		result_string[3]='W';
		result_string[4]='E';
		result_string[5]='R';
		result_string+=6;
		n_free_result_string_characters-=6;
	}

	{
		int exit_code;

		exit_code = 0;
		
		actual_size=0;
		error=AEGetParamPtr (apple_event,keyErrorNumber,typeLongInteger,&returned_type,&exit_code,4,&actual_size);

		if (error==noErr)
			*(int*)result_string=exit_code;
		else
			*(int*)result_string=error;

		n_free_result_string_characters-=4;
		result_string+=4;
	
		if (exit_code>=2){
			int compiler_n;
			
			compiler_n=(exit_code>>1)-1;
			if ((unsigned)compiler_n<(unsigned)MAX_N_COMPILERS){
				compiler_finished[compiler_n]=1;
				compiler_exit_code[compiler_n]=exit_code & 1;
			}
		} else
			++n_unknown_finished_compilers;
#if 0
		{
			TargetID target_id;
			ProcessSerialNumber psn;
			ProcessInfoRec process_info;

			error=AEGetAttributePtr (apple_event,keyOriginalAddressAttr,typeTargetID,&returned_type,&target_id,sizeof (target_id),&actual_size);
			
			if (error==noErr)
				error=GetProcessSerialNumberFromPortName (&target_id.recvrName/*name*/,&psn); /* recvrName */
			
			if (error==noErr)
				error=GetProcessInformation (&psn,&process_info);

			if (error==noErr){
				*(int*)result_string=process_info.processSignature;
			} else
				*(int*)result_string=error;
				
			n_free_result_string_characters-=4;
			result_string+=4;
	
			error=AEGetAttributePtr (apple_event,keyAddressAttr,typeTargetID,&returned_type,&target_id,sizeof (target_id),&actual_size);
			
			if (error==noErr)
				error=GetProcessSerialNumberFromPortName (&target_id.recvrName/*name*/,&psn); /* recvrName */
				
			if (error==noErr)
				error=GetProcessInformation (&psn,&process_info);

			if (error==noErr){
				*(int*)result_string=process_info.processSignature;
			} else
				*(int*)result_string=error;
				
			n_free_result_string_characters-=4;
			result_string+=4;
		}
#endif

		error=AEGetParamPtr (apple_event,keyErrorString,typeChar,&returned_type,result_string,n_free_result_string_characters,&actual_size);
		
		if (error==noErr){
			n_free_result_string_characters-=actual_size;
			result_string+=actual_size;
		}
	}
	
	return 0;
}

int install_apple_event_handlers (void)
{
	OSErr r;

	r=AEInstallEventHandler (kCoreEventClass,kAEOpenApplication,NewAEEventHandlerProc (&DoAEOpenApplication),0,false);

	if (r==noErr)
		r=AEInstallEventHandler (kCoreEventClass,kAEOpenDocuments,NewAEEventHandlerProc (&DoAEOpenDocuments),0,false);

	if (r==noErr)
		r=AEInstallEventHandler (kCoreEventClass,kAEPrintDocuments,NewAEEventHandlerProc (&DoAEPrintDocuments),0,false);

	if (r==noErr)
		r=AEInstallEventHandler (kCoreEventClass,kAEQuitApplication,NewAEEventHandlerProc (&DoAEQuitApplication),0,false);
	
	if (r==noErr)
		r=AEInstallEventHandler (kCoreEventClass,kAEApplicationDied,NewAEEventHandlerProc (&DoAEApplicationDied),0,false);
	
	if (r==noErr)
		r=AEInstallEventHandler (kCoreEventClass,kAEAnswer,NewAEEventHandlerProc (&DoAEAnswer),0,false);
	
	if (r==noErr)
		r=AEInstallEventHandler (kAEMiscStandards,kAEDoScript,NewAEEventHandlerProc (&DoAEScript),0,false);
			
	return r;
}

#if 1
int search_appdied_event (void)
{
	EventRecord theEvent;
	
//	DebugStr("\psearch_appdied_event");
	if (EventAvail(kHighLevelEvent,&theEvent))
		return (
			((*(AEEventID*)&theEvent.where) == kAEApplicationDied) && 
				(theEvent.message == kCoreEventClass));

	return 0;
}
#else
static pascal Boolean AppDiedFilter (void *dataPtr, HighLevelEventMsg *msgBuff, const TargetID *sender)
{
	if ((msgBuff->theMsgEvent.message == kCoreEventClass)
	&& (((AEEventID)(msgBuff->theMsgEvent.where)) == (AEEventID)kAEApplicationDied)
	)
		return 1;
	
	return 0;
}

int search_appdied_event (void)
{
	OSErr r;
	Boolean ret;
	
	ret = GetSpecificHighLevelEvent(NewGetSpecificFilterUPP(AppDiedFilter), 0, &r);
	
	return ret;
}
#endif

int handle_apple_event (EventRecord *event_p,long *clean_string)
{	
	char *string;
	int string_length;
	
	string_length=clean_string[1];
	string=(char*)&clean_string[2];

	result_string=string;
	n_free_result_string_characters=string_length;

	in_handle_apple_event = 1;
//	DebugStr("\phandle_apple_event");
	AEProcessAppleEvent (event_p);
	in_handle_apple_event = 0;

	if (result_string!=NULL)
		string_length=result_string-string;
	else
		string_length=0;
	
	result_string=NULL;
	n_free_result_string_characters=0;

	return string_length;
}

int get_finished_compiler_id_and_exit_code (int *exit_code_p)
{
	int compiler_n;
	
	if (n_unknown_finished_compilers>0){
		--n_unknown_finished_compilers;
		*exit_code_p=1;
		return -1;
	}
	
	for (compiler_n=0; compiler_n<MAX_N_COMPILERS; ++compiler_n)
		if (compiler_finished[compiler_n]){
			*exit_code_p=compiler_exit_code[compiler_n];
			
			compiler_finished[compiler_n]=0;
			
			return compiler_n;
		}
		
	*exit_code_p=0;
	return -1;
}
