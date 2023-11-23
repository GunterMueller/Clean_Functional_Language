implementation module UtilIO

import code from "cUtilSystem."

/* OS dependent module */
/* Primitives which 'should be' in the standard CLEAN IO lib */

import StdArray, StdBool, StdClass, StdFile, StdList, StdMisc
import UtilDate

import StdSystem, StdWindow
import ostypes, OS_utilities;
from files import GetFInfo,GetCatInfo1,GetCatInfo2/*,GetWDInfo*/,HGetVol;

//---

import StdPathname, Directory

FReadOnly :: !{#Char} !*env -> (!Bool, !*env) | FileSystem env
FReadOnly path files
	# ((ok,dir),files)	= pd_StringToPath path files
	| not ok
		= (False,files)
	# ((err,fi),files)	= getFileInfo dir files
	| err <> NoDirError
		= (False,files)
	= (fi.pi_fileInfo.isReadOnly,files)

/* old version...
FReadOnly path files
	# dir				= RemoveFilename path
	# fnm				= RemovePath path
	# ((ok,dir),files)	= pd_StringToPath dir files
	| not ok
		= (False,files)
	# ((err,dct),files)	= getDirectoryContents dir files
	| err <> NoDirError
		= (False,files)
//	# dct				= map (\{fileInfo}->fileInfo.pi_fileInfo) dct
	# dct				= filter (\{fileName}->fileName==fnm) dct
	| isEmpty dct
		= (False,files)
	= ((hd dct).fileInfo.pi_fileInfo.isReadOnly,files)
*/
//--
//import files
/*
// FIXME: Util shouldn't import from Pm
from PmCleanSystem import Launch
*/
LaunchApplication :: !{#Char} !{#Char} !Bool !Files -> ( !Bool, !Files)
LaunchApplication execpath homepath console files
	// set working directory???
	# (error_n,files) = Launch execpath files
	| error_n >= 0
		= (True,files)
		= (False,files)

import files

Launch :: !{#Char} !.a -> (!Int, !.a)
Launch execpath env
	# (error_n,fsspec,tb)	= FSMakeFSSpec execpath OSNewToolbox
	| error_n <> 0 = (error_n,env)
	# (error_n,tb)			= LaunchApplicationFSSpec fsspec 0xC800 tb
//	# (error_n,_) = LaunchApplication execpath 0xC8000000 OSNewToolbox
	= (error_n, env)

/*	Returns True if the file name exists.
*/

FExists	:: !String !Files -> (!Bool, !Files);
FExists name disk = (result == 0, disk);
where
	(result,_,_)	= GetFInfo name NewToolbox;


/*	Returns the last modification date of the indicated file.
*/

FModified :: !String !Files -> (!DATE, !Files);
FModified path disk
	| result <> 0	= (NoDate,disk);
					= ({exists=True,yy=years,mm=months,dd=days,h=hours,m=minutes,s=seconds},disk);
where
	(result,modification,_)		= GetFInfo path NewToolbox;
	(years,months,days,_,_)		= Secs2Date modification 0;
	(hours,minutes,seconds,_)	= Secs2Time  modification 0;


/*	Returns directory in which the indicated application resides.
*/

FStartUpDir :: !String !*Files -> (!String, !*Files);
FStartUpDir applicationname files
	| result==0
		= (pathName % (0,size pathName-2), files);
where
	(result,wd_vref_num,directory_id,tb1)	= HGetVol NewToolbox;
	(pathName,_)	= Get_directory_path wd_vref_num directory_id "" tb1;

GetFullApplicationPath :: !*Files -> ({#Char}, *Files);
GetFullApplicationPath files
	=	FStartUpDir "" files;


RemoveFileName :: !String -> String;
RemoveFileName path
	| found	= (path % (0, dec position));
			= path;
where 
	(found,position)	= LastColon path last;
	last				= dec (size path);
		
LastColon :: !String !Int -> (!Bool, !Int);
LastColon s i
	| i <= 0
		= (False,0);
	| dirseparator==s.[i]
	 	= (True, i);
		= LastColon s (dec i);

Get_name_and_parent_id_of_directory :: !Int !Int !*Toolbox -> (!String,!Int,!*Toolbox);
Get_name_and_parent_id_of_directory volumeNumber directoryId tb
	|	0 == osError	= (folderName,parentId,tb1);
						= abort ("Error code returned by BPGetCatInfo: " +++ toString osError);
where
	(osError,folderName,parentId,tb1) = GetCatInfo2 volumeNumber directoryId String64 tb;

Get_directory_path :: !Int !Int !String !*Toolbox -> (!String, !*Toolbox);
Get_directory_path volumeNumber directoryId path tb
	| directoryId==2
		= (folderName +++ ":" +++ path, tb1);
		= Get_directory_path volumeNumber parentId (folderName +++ ":" +++ path) tb1;
where
		(folderName, parentId, tb1) = Get_name_and_parent_id_of_directory volumeNumber directoryId tb;
	
String64 :: String;
String64	= createArray 64 '@';

//--
//import StdDebug, dodebug

GetLongPathName :: !String -> String;
GetLongPathName s
//	#! (_,_,tb) = GetFName s 42
//	= trace_n s s
	= s

GetShortPathName :: !String -> (!Bool,!String);
GetShortPathName s = (True,s)//quoted_string s)

//--
GetFName :: !.{#Char} !*Toolbox -> (!Int,!Int,!*Toolbox);
GetFName ioNamePtr t = code (ioNamePtr=R80O0D0SD1,t=U)(ioResult=D0,ioDate_and_Time=I80A0,t2=Z){
	instruction 0x39400000	|	li	r10,0
	instruction 0x9141000C	|	stw	r10,12(sp)
	instruction 0x90810012	|	stw	r4,18(sp)
	instruction 0xB1410016	|	sth	r10,22(sp)
	instruction 0xB141001A	|	sth	r10,26(sp)
	instruction 0x91410030	|	stw	r10,48(sp)
	instruction 0x3940FFFF	|	li	r10,-1
	instruction 0xB141001C	|	sth	r10,28(sp)
	call	.PBHGetFInfoSync
	instruction 0x8321004C	|	lwz	r25,76(sp)
	};

/////////////////////
//import nodebug
trace_n` _ f :== f

LaunchTheDocument :: !String !String !Int !*a -> (!Int,!*a)
LaunchTheDocument docPath appPath appCreator env
	# (error_n,appSpec,tb)	= FSMakeFSSpec appPath OSNewToolbox
	| error_n <> 0 = trace_n` ("LaunchTheDocument",1,appPath,error_n) (error_n,env)
	# (error_n,docSpec,tb)	= FSMakeFSSpec docPath tb
	| error_n <> 0 = trace_n` ("LaunchTheDocument",2,docPath,error_n) (error_n,env)
	# (error_n,tb)			= LaunchTheDocument docSpec appCreator appSpec tb
	= trace_n` ("LaunchTheDocument",3,appCreator,error_n) (error_n,env)
where
	LaunchTheDocument :: !String !Int !String !*Toolbox -> (!Int,!*Toolbox)
	LaunchTheDocument _ _ _ _ = code {
		ccall LaunchTheDocument "sIs:I:I"
		}

/*
import appleevents

KAEApplicationDied	:== 0x6F626974; // 'obit'
KAEOpenDocuments	:== 0x6F646F63;	// 'odoc'
TypeList			:== 0x6C697374;	// 'list'

send_command_to_clean_compiler :: !String !String !String !Bool -> (!Int,!Int,!String);
send_command_to_clean_compiler signature name command wait_for_reply
	# (os_error_code,error_n,output_string,tb)
		= send_command_to_clean_compiler0 signature command wait_for_reply OSNewToolbox
	| error_n<>(-2)
		= (os_error_code,error_n,output_string);

	# (error_n,fsspec,tb)	= FSMakeFSSpec name tb
	| error_n <> 0
		= (error_n,-2,output_string)
	# (launch_error_n,tb)	= LaunchApplicationFSSpec fsspec 0xCA00 tb
//	# (launch_error_n,_)
//		= LaunchApplication name 0xCA000000 OSNewToolbox;	// Hangs under OS X?
	| launch_error_n>=0	
		# (os_error_code,error_n,output_string,tb)
			= send_command_to_clean_compiler0 signature command wait_for_reply tb
		= (os_error_code,error_n,output_string)
	= (os_error_code,-2,output_string);

send_command_to_clean_compiler0 :: !String !String !Bool !*OSToolbox -> (!Int,!Int,!String,!*OSToolbox);
send_command_to_clean_compiler0 signature command wait tb
	| error_code1<>0
		= (error_code1,-1,"NewPtr failed",tb);
//	# error_code2 = AECreateDesc TypeApplSignature "MPSX" descriptor; // Tool Server
	# error_code2
		= trace_n "AECreateDesc" AECreateDesc TypeApplSignature signature descriptor;
	| error_code2<>0
		= (free_memory error_code2,-1,"AECreateDesc failed",tb);
	# error_code3
		= trace_n "AECreateAppleEvent" AECreateAppleEvent KCoreEventClass KAEOpenDocuments  descriptor KAutoGenerateReturnID KAnyTransactionID apple_event;
	| error_code3<>0
		= (free_descriptor_and_memory error_code3,-1,"AECreateAppleEvent failed",tb);
	# error_code4
//		err = AECreateList(NULL, 0, false, &fileList); 
		= trace_n "AEPutParamPtr" AEPutParamPtr apple_event KeyDirectObject TypeChar command;
	| error_code4<>0
		= (free_apple_event_and_desciptor_and_memory error_code4,-1,"AEPutParamPtr failed",tb);
/*
	err = NewAlias(NULL, &the_file, &docAlias);

	HLock((Handle) docAlias);
	err = AECreateDesc(typeAlias, (Ptr) (*docAlias),
	GetHandleSize((Handle) docAlias), &fileListElt);
	HUnlock((Handle) docAlias); 
*/
//err = AEPutDesc(&fileList, 0, &fileListElt); 
	# error_code5
		= case wait of
			True -> trace_n "AESend wait" AESend apple_event result_apple_event KAEWaitReply KAENormalPriority KNoTimeOut 0 0;
//			True -> loop OSNewToolbox;
			_	 -> trace_n "AESend nowait" AESend apple_event 0 KAEQueueReply KAENormalPriority KNoTimeOut 0 0;
	| error_code5==(-600)
		= (free_apple_event_and_desciptor_and_memory error_code5,-2,"AESend failed",tb);
	| error_code5==(-609)
		= (free_apple_event_and_desciptor_and_memory error_code5,-2,"AESend failed",tb);
	| error_code5==(-903)
		= (free_apple_event_and_desciptor_and_memory error_code5,-2,"need to add HighLevel event aware to SIZE resource of IDE...",tb);
	| error_code5==(-1712)
		= (free_apple_event_and_desciptor_and_memory error_code5,-1,"AESend failed; Application died",tb);
	| error_code5<>0
		= (free_apple_event_and_desciptor_and_memory error_code5,-1,"AESend failed",tb);
	| not wait
		= (free_apple_event_and_desciptor_and_memory error_code5,0,"",tb);
	# (error_code6,_,v1,_)
		= trace_n "AEGetIntParamPtr" AEGetIntParamPtr result_apple_event KeyErrorNumber TypeLongInteger;
	# (error_code7,_,s2)
		= trace_n "AEGetStringParamPtr" AEGetStringParamPtr result_apple_event KeyErrorString TypeChar result_string;
	# os_error_code
		= trace_n "fraeaaeadam" free_result_apple_event_and_apple_event_and_desciptor_and_memory error_code6 error_code7
	# error_n
//		= if (error_code6<0) 0 v1
		= if (error_code6<>0) 0 v1
	# output_string
		= if (error_code7<>0) "" (result_string % (0,s2-1))
	# tb = trace_n` ("CALL",error_code6,v1,error_code7,s2) tb
	= (os_error_code,error_n,output_string,tb)
where
	loop tb
		# err	= AESend apple_event result_apple_event KAEWaitReply KAENormalPriority (60) 0 0;
		| err==(-1712)
			# (avail,what,message,when,wherex,wherey,modifiers,tb) = EventAvail NetworkMask tb
			| avail && what == HighLevelEvent && message == KCoreEventClass && wherex == KAEApplicationDied
				= -1712
			= loop tb
		= err
	result_string = createArray 5120 '0';

	(memory,error_code1,_)
		= NewPtr (SizeOfAEDesc+SizeOfAppleEvent+SizeOfAppleEvent) 0;
	descriptor
		= memory;
	apple_event
		= memory+SizeOfAEDesc;
	result_apple_event
		= memory+SizeOfAEDesc+SizeOfAppleEvent;

	free_result_apple_event_and_apple_event_and_desciptor_and_memory error_code6 error_code7
		| error_code6==error_code6 && error_code7==error_code7
			= free_apple_event_and_desciptor_and_memory free_error_code;
	where
		free_error_code = AEDisposeDesc result_apple_event;

	free_apple_event_and_desciptor_and_memory error_code
		| error_code==0
			= free_descriptor_and_memory free_error_code;
		| free_error_code==0
			= free_descriptor_and_memory error_code;
			= free_descriptor_and_memory error_code;
	where
		free_error_code = AEDisposeDesc apple_event;

	free_descriptor_and_memory error_code
		| error_code==0
			= free_memory free_error_code;
		| free_error_code==0
			= free_memory error_code;
			= free_memory error_code;
	where
		free_error_code = AEDisposeDesc descriptor;

	free_memory error_code
		| error_code==0
			= if (free_error_code==255) 0 free_error_code;
		| free_error_code==0
			= error_code;
			= error_code;
	where
		(free_error_code,_)	= DisposPtr memory 0;

DisposPtr p t
	# t = DisposePtr p t
	= MemError t
where
	MemError :: !*Toolbox -> (!Int,!*Toolbox)
	MemError _ = code {
		ccall MemError "P:I:I"
		}
/*
LSLaunchFSRefSpec inLaunchSpec;
    /* app to use, can be NULL*/
inLaunchSpec.appRef = &outAppRef;
    /* items to open/print, can be NULL*/
inLaunchSpec.numDocs = numDocuments;
    /* array of FSRefs*/
inLaunchSpec.itemRefs = documentRefArray;
    /* passed untouched to application as optional parameter*/
inLaunchSpec.passThruParams = nil;
    /* default = open, async, use Info.plist, start Classic*/
inLaunchSpec.launchFlags = kLSLaunchDefaults;
    /* used if you register for app birth/death notification*/
inLaunchSpec.asyncRefCon = nil;

err = LSOpenFromRefSpec( &inLaunchSpec, &outLaunchedRef ); 


extern OSStatus 
LSOpenFromRefSpec(
  const LSLaunchFSRefSpec *  inLaunchSpec,
  FSRef *                    outLaunchedRef)       /* can be NULL */ 


struct LSLaunchFSRefSpec {
  const FSRef *       appRef;                 /* app to use, can be NULL*/
  UInt32              numDocs;                /* items to open/print, can be NULL*/
  const FSRef *       itemRefs;               /* array of FSRefs*/
  const AEDesc *      passThruParams;         /* passed untouched to application as optional parameter*/
  LSLaunchFlags       launchFlags;
  void *              asyncRefCon;            /* used if you register for app birth/death notification*/
};
typedef struct LSLaunchFSRefSpec        LSLaunchFSRefSpec;
*/
*/