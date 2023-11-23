implementation module osdirectory

import	StdBool, StdInt, StdString, StdMisc, StdArray, StdClass, StdChar
import	osevent
import	/*standard_file,*/ files, memory, pointer, navigation, appleevents
from	quickdraw	import	QScreenRect


String64 :: String
String64 = string32+++string32
where
	string32 = "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"

Error_i	:: !String !Int -> .x
Error_i string i = abort (string +++ toString i)

get_or_put_file_selector_result :: !Int !Int !*OSToolbox -> (!Bool,!String,!*OSToolbox)
get_or_put_file_selector_result err nav_reply_record tb
	| err<>0
		# tb=DisposePtr nav_reply_record tb;
		= (False,"",tb);
	# (valid_record,tb) = LoadByte (nav_reply_record+NavReplyValidRecordOffset) tb;
	| valid_record==0
		# (_,tb)=NavDisposeReply nav_reply_record tb;
		# tb=DisposePtr nav_reply_record tb;
		= (False,"",tb);
	# fs_spec=createArray 70 '\0';
	# (r,theAEKeyword,typeCode,actualSize,tb) = AEGetNthPtr (nav_reply_record+NavReplySelectionOffset) 1 KeyFssString fs_spec tb;
	| r<>0 || actualSize<>70
		# (_,tb)=NavDisposeReply nav_reply_record tb;
		# tb=DisposePtr nav_reply_record tb;
		= (False,"",tb);
	# file_name_size=toInt fs_spec.[6]
	# vRefNum=((toInt fs_spec.[0]<<8 bitor toInt fs_spec.[1])<<16)>>16;
	# directoryId=((toInt fs_spec.[2]<<8 bitor toInt fs_spec.[3])<<8 bitor toInt fs_spec.[4])<<8 bitor toInt fs_spec.[5];
	# file_name=fs_spec % (7,6+file_name_size);
	# (path_name,tb)=Get_directory_path vRefNum directoryId file_name tb;
	# (_,tb)=NavDisposeReply nav_reply_record tb;
	# tb=DisposePtr nav_reply_record tb;
	= (True,path_name,tb);

Get_directory_path :: !Int !Int !String !*OSToolbox -> (!String,!*OSToolbox)
Get_directory_path volumeNumber directoryId path tb
#	(folderName,parentId,tb)	= Get_name_and_parent_id_of_directory volumeNumber directoryId tb
|	directoryId==2
=	(folderName +++ ":" +++ path, tb)
=	Get_directory_path volumeNumber parentId (folderName +++ ":" +++ path) tb

Get_name_and_parent_id_of_directory :: !Int !Int !*OSToolbox -> (!String,!Int,!*OSToolbox)
Get_name_and_parent_id_of_directory volumeNumber directoryId tb
#	(osError,folderName,parentId,tb)	= GetCatInfo2 volumeNumber directoryId String64 tb
|	osError==0
=	(folderName,parentId,tb)
=	Error_i "Error code returned by BPGetCatInfo: " osError
/*
/*
Get_parent_id_of_file :: !Int !String !*OSToolbox -> (!Int,!*OSToolbox)
Get_parent_id_of_file volumeNumber fileName tb
#	(osError,parentId,tb)	= GetCatInfo1 volumeNumber fileName tb
|	osError==0
=	(parentId,tb)
=	Error_i "Error code returned by GetCatInfo: " osError
*/
/*
Get_working_directory_info :: !Int !*OSToolbox -> (!Int,!Int,!*OSToolbox)
Get_working_directory_info workingDirectoryId tb
#	(osError,volumeNumber,directoryId,tb)	= GetWDInfo workingDirectoryId tb
|	osError==0
=	(volumeNumber,directoryId,tb)
=	Error_i "Error code returned by GetWDInfo: " osError
*/

Get_stored_dir_and_file :: !*OSToolbox -> (!Int,!Int,!*OSToolbox)
Get_stored_dir_and_file tb
#	(saveDisk,tb)		= LoadWord 532 tb
	sfSaveDisk			= 0-saveDisk
	(curDirStore,tb)	= LoadLong 920 tb
=	(sfSaveDisk,curDirStore,tb)

Set_directory :: !Int !Int !*OSToolbox -> *OSToolbox
Set_directory v d tb
#	tb = StoreWord 532 (0-v) tb
	tb = StoreLong 920 d tb
=	tb

SelectorPosition :: !*OSToolbox -> (!(!Int,!Int),!*OSToolbox)
SelectorPosition tb
#	(sl,st, sr,sb, tb)	= QScreenRect tb
	hPos				= (sr-sl-SelectorWidth ) / 2
	vPos				= (sb-st-SelectorHeight) / 3
=	((hPos,vPos), tb)

SelectorWidth  :== 350
SelectorHeight :== 250
*/

Get_directory_and_file_name :: !String !*OSToolbox -> (!Int,!Int,!String,!*OSToolbox)
Get_directory_and_file_name pathName tb
|	not colon					= (0,0,pathName,tb)
//|	select pathName 0 == ':'	= Get_directory_and_file_name2 pathName 0 sfSaveDisk curDirStore tb1
//								with
//									(sfSaveDisk,curDirStore,tb1)	= Get_stored_dir_and_file tb
#	(result,volumeNumber,tb)	= GetVInfo (pathName%(0,colonPosition)) tb
|	result==0					= Get_directory_and_file_name2 pathName colonPosition volumeNumber 2 tb
//#	(sfSaveDisk,curDirStore,tb)	= Get_stored_dir_and_file tb
|	otherwise					= (0,0,pathName,tb)
where
	(colon,colonPosition)		= Find_colon pathName 0

Get_directory_and_file_name2 :: !String !Int !Int !Int !*OSToolbox -> (!Int,!Int,!String,!*OSToolbox)
Get_directory_and_file_name2 pathName p v d tb
|	(p>=l) || (select pathName p<>':')			= (v,d,pathName%(p,l-1),tb)
#	(result,attrib,d2,tb)						= GetCatInfo3 v d (pathName%(p+1,p2-1)) tb
|	colon && result==0 && (16 bitand attrib)<>0	= Get_directory_and_file_name2 pathName p2 v d2 tb
												= (v,d,pathName%(p+1,l-1),tb)
where
	l											= size pathName
	(colon,p2)									= Find_colon pathName (p+1)

Find_colon :: !String !Int -> (!Bool,!Int)
Find_colon s p = Find_colon2 s p ((size s)-1)

Find_colon2 :: String !Int !Int -> (!Bool,!Int)
Find_colon2 s p l
|	p >= l				= (False,p)
|	select s p == ':'	= (True,p)
						= Find_colon2 s (p+1) l
