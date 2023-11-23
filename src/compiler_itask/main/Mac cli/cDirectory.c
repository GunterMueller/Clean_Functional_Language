#ifdef __MACH__
#include <Carbon/Carbon.h>
#else
#include <Files.h>
#endif
#include "Clean.h"

#define min(x,y) (x)<(y) ? (x) : (y);
#define PascalStringLength(x) (x[0])
#define PascalStringCharacters(x) (x+1)
#define MAX_BYTE 255
#define MAX_NAME_LENGTH 40

// error codes:
#define OtherDirError		-1
#define DoesntExist			-2
#define BadName				-3
#define NotEnoughSpace		-4
#define AlreadyExists		-5
#define NoPermission		-6
#define MoveIntoOffspring	-7
#define MoveAcrossDisks		-8
#define NotYetRemovable		-9

CInfoPBRec gPb;
short	gVRefNr;
long	gDirId;
int		gFIndex;
CleanStringVariable(gFileName,MAX_BYTE);	

static int isRelativePath(StringPtr ps_path)
{
	// a path is relative on the Mac iff (the first character is  ':' or no character is ':')
	int i;
	if (PascalStringLength(ps_path)==0 || PascalStringCharacters(ps_path)[0]==':')
		return true;
	else {
		for(i=0; i<PascalStringLength(ps_path); i++)
			if (PascalStringCharacters(ps_path)[i]==':')
				return false;
		return true;
		}
}

static OSErr	DetermineVRefNum(StringPtr ps_path, short *pVRefNum)
{
	HParamBlockRec pb;
	Str255 ps_path_temp;
	OSErr err;
	
	if (isRelativePath(ps_path)) {
		*pVRefNum = 0;
		err = 0;
		}
	else {
		BlockMoveData(ps_path, ps_path_temp, PascalStringLength(ps_path) + 1);	// make a copy of the string and
		pb.volumeParam.ioVRefNum = 0;
		pb.volumeParam.ioNamePtr = (StringPtr)ps_path_temp;	// use the copy so original isn't trashed 
		pb.volumeParam.ioVolIndex = -1;	// use ioNamePtr/ioVRefNum combination
		err = PBHGetVInfoSync(&pb);
		*pVRefNum = pb.volumeParam.ioVRefNum;
		}
	return err;
}

static OSErr GetDirectoryID(short vRefNum, StringPtr ps_path, long *pDirId, int *pIsDirectory)
{
	CInfoPBRec pb;
	OSErr err;

	pb.dirInfo.ioNamePtr = ps_path;
	pb.dirInfo.ioFDirIndex = 0;	// use ioNamePtr and ioDirID
	pb.dirInfo.ioVRefNum = vRefNum;
	pb.dirInfo.ioDrDirID = 0;
	err = PBGetCatInfoSync(&pb);
	*pDirId = pb.dirInfo.ioDrDirID;
	*pIsDirectory = pb.dirInfo.ioFlAttrib & ioDirMask;
	return err;
}

static void cleanString2PascalString(CleanString cs, StringPtr ps)
// Clean String can be zero terminated
{
	int length, i;

	length	= min(CleanStringLength(cs), 255);
	for(i=0; i<length && CleanStringCharacters(cs)[i]!='\0'; i++)
		ps[i+1]	= CleanStringCharacters(cs)[i];
	PascalStringLength(ps)	= i;
}

static int mac_error_to_clean_error(OSErr mac_err)
{
	switch(mac_err) {
		case noErr:		return 0;
		case dirNFErr:
		case fnfErr:
		case nsvErr:	return DoesntExist;
		case bdNamErr:	return BadName;
		case dirFulErr:	return NotEnoughSpace;
		case dupFNErr:	return AlreadyExists;
		case extFSErr:
		case fLckdErr:
		case vLckdErr:
		case wPrErr:	return NoPermission;
		case badMovErr:	return MoveIntoOffspring;
		case fBsyErr:	return NotYetRemovable;
		default:		return OtherDirError;
		};
}

void init_parameter_block(unsigned char* ps_path, short vRefNum, HParamBlockRec *p_pb)
{
	p_pb->fileParam.ioNamePtr		= (StringPtr) ps_path;
	p_pb->fileParam.ioVRefNum		= vRefNum;
	p_pb->fileParam.ioDirID			= 0;
	p_pb->fileParam.ioFDirIndex		= 0;
}

int findNextFileC(int dummy)
{
	// set up parameter block
	
	CleanStringCharacters((CleanString)gFileName)[-1]	= (char) MAX_BYTE;
		// make a pascal string out of the CleanString
	gPb.hFileInfo.ioNamePtr = (StringPtr)(CleanStringCharacters((CleanString)gFileName)-1);
		// store the address of the pascal string
	gPb.hFileInfo.ioVRefNum = gVRefNr;
	gPb.hFileInfo.ioDirID = gDirId;
	gFIndex++;
	gPb.hFileInfo.ioFDirIndex = gFIndex;
	
	return PBGetCatInfoSync(&gPb) ? 1 : 0;
}

int findFirstFileC(CleanString cs_path)
// return values: 0=ok, -1=file/directory does not exist, 1=directory is empty, -2=isn't directory
{
	int isDirectory;
	unsigned char ps_path[256];
	OSErr err;
	
	cleanString2PascalString(cs_path,ps_path);
	err = DetermineVRefNum(ps_path, &gVRefNr);
	if (err)
		return DoesntExist;
	err	= GetDirectoryID(gVRefNr, ps_path, &gDirId, &isDirectory);
	
	if (err)
		return mac_error_to_clean_error(err);
	if (!isDirectory)
		return DoesntExist;
		
	gFIndex	= 0;
	return findNextFileC(0);
}

DateTimeRec gDateTime,gDateTime2;

void getDateTimeC(	int *pYear, int *pMonth, int *pDay, int *pDayNr,
					int *pHours, int *pMinutes, int *pSeconds
					)
{
	*pYear			= gDateTime.year;
	*pMonth			= gDateTime.month;
	*pDay			= gDateTime.day;
	*pDayNr			= gDateTime.dayOfWeek;
	*pHours			= gDateTime.hour;
	*pMinutes		= gDateTime.minute;
	*pSeconds		= gDateTime.second;
}

void getDateTime2C(	int *pYear, int *pMonth, int *pDay, int *pDayNr,
					int *pHours, int *pMinutes, int *pSeconds
					)
{
	*pYear			= gDateTime2.year;
	*pMonth			= gDateTime2.month;
	*pDay			= gDateTime2.day;
	*pDayNr			= gDateTime2.dayOfWeek;
	*pHours			= gDateTime2.hour;
	*pMinutes		= gDateTime2.minute;
	*pSeconds		= gDateTime2.second;
}

void getCommonFileInfoC(int also_get_file_name,
						CleanString *pFileName, int *pFileSizeLow, int *pFileSizeHigh,
						int *pYear, int *pMonth, int *pDay, int *pDayNr,
						int *pHours, int *pMinutes, int *pSeconds,
						int *pIsDirectory, int *pIsReadOnly)
{
	int isDirectory;
	int filenameLength;
	DateTimeRec	dateTime;
	static int null = 0;
	
	filenameLength	= (int) (CleanStringCharacters(gFileName)[-1]);	// it's used as a pascal string
	CleanStringLength(gFileName)	= filenameLength;				// now it's a CleanString
	*pFileName = also_get_file_name ? (CleanString) gFileName : (CleanString) &null;
	isDirectory	= (gPb.hFileInfo.ioFlAttrib & ioDirMask) != 0;
	if (isDirectory) {
		*pFileSizeLow	=  0;
		SecondsToDate(gPb.dirInfo.ioDrMdDat, &dateTime);
		}
	else {
		*pFileSizeLow	=  gPb.hFileInfo.ioFlLgLen;
		SecondsToDate(gPb.hFileInfo.ioFlMdDat, &dateTime);
		};
	*pFileSizeHigh	= 0;
	*pYear			= dateTime.year;
	*pMonth			= dateTime.month;
	*pDay			= dateTime.day;
	*pDayNr			= dateTime.dayOfWeek;
	*pHours			= dateTime.hour;
	*pMinutes		= dateTime.minute;
	*pSeconds		= dateTime.second;
	*pIsDirectory	= isDirectory;
	*pIsReadOnly	= (gPb.hFileInfo.ioFlAttrib & 1) != 0;
}

struct CleanString4 { int length,contents; };
typedef struct CleanString4 CleanString4;

void getMacFileInfoC(int *pCYear, int *pCMonth, int *pCDay, int *pCDayNr,	// creation time
					int *pCHours, int *pCMinutes, int *pCSeconds,			// dito	
					int *pBYear, int *pBMonth, int *pBDay, int *pBDayNr,	// backup time
					int *pBHours, int *pBMinutes, int *pBSeconds,			// dito	
					int *pIsHidden,
					CleanString4 **ppCreator, CleanString4 **ppFileType, int *pFdFlags)
{
	static CleanString4 creator = {4,0}, fileType={4,0};
	int isDirectory;
	DateTimeRec	c_dateTime, b_dateTime;
	
	isDirectory		= (gPb.hFileInfo.ioFlAttrib & ioDirMask) != 0;
	if (isDirectory) {
		*pIsHidden	= false;
		creator.contents	= 0;
		fileType.contents	= 0;
		SecondsToDate(gPb.dirInfo.ioDrCrDat, &c_dateTime);
		SecondsToDate(gPb.dirInfo.ioDrBkDat, &b_dateTime);
		*pFdFlags			= gPb.dirInfo.ioDrUsrWds.frFlags;
		}
	else {
		*pIsHidden		= (gPb.hFileInfo.ioFlFndrInfo.fdFlags & fInvisible) != 0;
		creator.contents	= gPb.hFileInfo.ioFlFndrInfo.fdCreator;
		fileType.contents	= gPb.hFileInfo.ioFlFndrInfo.fdType;
		SecondsToDate(gPb.hFileInfo.ioFlCrDat, &c_dateTime);
		SecondsToDate(gPb.hFileInfo.ioFlBkDat, &b_dateTime);
		*pFdFlags			= gPb.hFileInfo.ioFlFndrInfo.fdFlags;
		};

	*pCYear			= c_dateTime.year;
	*pCMonth		= c_dateTime.month;
	*pCDay			= c_dateTime.day;
	*pCDayNr		= c_dateTime.dayOfWeek;
	*pCHours		= c_dateTime.hour;
	*pCMinutes		= c_dateTime.minute;
	*pCSeconds		= c_dateTime.second;

	*pBYear			= b_dateTime.year;
	*pBMonth		= b_dateTime.month;
	*pBDay			= b_dateTime.day;
	*pBDayNr		= b_dateTime.dayOfWeek;
	*pBHours		= b_dateTime.hour;
	*pBMinutes		= b_dateTime.minute;
	*pBSeconds		= b_dateTime.second;

	*ppCreator	= &creator;
	*ppFileType	= &fileType;
}

void closeSearchC()
{
}

int findSingleFileC(CleanString cs_path)
{
	short vRefNr;
	OSErr err;
	Str255 ps_path;
	int isDirectory;
	
	cleanString2PascalString(cs_path,ps_path);

	err = DetermineVRefNum(ps_path, &vRefNr);
	if (err)
		return false;
	
	// set up parameter block
	
	gPb.hFileInfo.ioNamePtr = ps_path;
	gPb.hFileInfo.ioVRefNum = vRefNr;
	gPb.hFileInfo.ioDirID	= 0;
	gPb.hFileInfo.ioFDirIndex = 0;
	
	err = PBGetCatInfoSync(&gPb);
	if (err)
		return mac_error_to_clean_error(err);
		
	isDirectory	= (gPb.hFileInfo.ioFlAttrib & ioDirMask) != 0;
	return (!isDirectory || gPb.hFileInfo.ioDirID!=2) ? 0 : OtherDirError;
}

void closeSingleSearchC()
{
}

static void set_absolute_ps_path_to_diskName_only(unsigned char* ps_path)
{
	int i;
	for(i=1; ps_path[i]!=':'; ) i++;
	PascalStringLength(ps_path) = i-1;
}

int createDirectoryC(CleanString cs_path)
{
	unsigned char ps_path[256];
	HParamBlockRec pb;
	int err;
	
	cleanString2PascalString(cs_path, ps_path);
	init_parameter_block(ps_path, 0, &pb);
	err	= PBDirCreateSync(&pb);
	return mac_error_to_clean_error(err);
}

int fremoveC(CleanString cs_path)
{
	unsigned char ps_path[256];
	HParamBlockRec pb;
	int err;
	
	cleanString2PascalString(cs_path, ps_path);
	init_parameter_block(ps_path, 0, &pb);
	err	= PBHDeleteSync(&pb);
	return mac_error_to_clean_error(err);
}

void getCurrentDirectory_SE()
{
}


void get_mac_dir_parent_and_name_C(int dirID,int *pParentDirID, CleanString *pDirName)
{
	int filenameLength;
	static int null=0;
	CInfoPBRec pb;
	OSErr err;
	
	// set up parameter block
	
	CleanStringCharacters((CleanString)gFileName)[-1]	= (char) MAX_BYTE;
		// make a pascal string out of the CleanString
	pb.dirInfo.ioNamePtr = (StringPtr)(CleanStringCharacters((CleanString)gFileName)-1);
		// store the address of the pascal string
	pb.dirInfo.ioVRefNum = 0;
	pb.dirInfo.ioDrDirID = dirID;
	pb.dirInfo.ioFDirIndex = -1;
	
	err = PBGetCatInfoSync(&pb);
	if (err!=noErr) {
		*pDirName = (CleanString) &null;
		*pParentDirID = 1;
		}
	else {
		filenameLength	= (int) (CleanStringCharacters(gFileName)[-1]);	// it's used as a pascal string
		CleanStringLength(gFileName)	= filenameLength;				// now it's a CleanString
		*pDirName = (CleanString) gFileName;
		*pParentDirID = pb.dirInfo.ioDrParID;
		};
}

int setCurrentDirectoryC(CleanString cs_path)
{
	WDPBRec wdpb;
	OSErr	err;
	Str255  ps_path;
	int		isDirectory;
	short	vRefNr;
	long	dirId;

	cleanString2PascalString(cs_path, ps_path);
	wdpb.ioNamePtr = ps_path;
	wdpb.ioVRefNum = 0;
	wdpb.ioWDDirID = 0;
	err = PBHSetVolSync(&wdpb);
	if (err==noErr)
		return 0;
	else {
		// generate a proper error value
		err = DetermineVRefNum(ps_path, &vRefNr);
		if (err)
			return DoesntExist;
		err	= GetDirectoryID(vRefNr, ps_path, &dirId, &isDirectory);
		if (!isDirectory)
			return DoesntExist;
		return mac_error_to_clean_error(err);
		};	
}

void getMacDiskNameC(int ioVolIndex, CleanString *pcsDiskName)
{
	static CleanStringVariable(csDiskName,MAX_NAME_LENGTH);
	StringPtr ps;
	HParamBlockRec pb;
	
	*pcsDiskName = (CleanString) csDiskName;
	ps = (unsigned char *) CleanStringCharacters(csDiskName) - 1;
	PascalStringLength(ps) = MAX_NAME_LENGTH;
	pb.volumeParam.ioNamePtr = ps;
	pb.volumeParam.ioVRefNum = 0;
	pb.volumeParam.ioVolIndex = ioVolIndex;
	if (PBHGetVInfoSync(&pb)==noErr)
		CleanStringLength(csDiskName) = PascalStringLength(ps);
	else
		CleanStringLength(csDiskName) = 0;
}

int getPlatformIdC(int dummy)
{
#define MacPlatform 2
	return MacPlatform;
}

void getWindowsFileInfoC()
{}

void getUnixFileInfoC()
{}

void get_windows_disk_available_bits_C()
{}

void fmoveC()
{}

int macMoveC(CleanString cs_from, CleanString cs_to)
{
	CMovePBRec pb;
	short vRefNum;
	unsigned char ps_from[256];
	unsigned char ps_to[256];
	OSErr err;

	cleanString2PascalString(cs_from,ps_from);
	cleanString2PascalString(cs_to,ps_to);

	err	= DetermineVRefNum(ps_from, &vRefNum);
	if (err)
		return DoesntExist;
	pb.ioNamePtr = ps_from;
	pb.ioVRefNum = vRefNum; 
	pb.ioNewName = ps_to;
	pb.ioNewDirID = 0;
	pb.ioDirID = 0;
	err = PBCatMoveSync(&pb);
	return err==bdNamErr ? MoveAcrossDisks : mac_error_to_clean_error(err);
}

int macRenameC(CleanString cs_path, CleanString cs_name)
{
	Str255 ps_path, ps_name;
	HParamBlockRec pb;
	short vRefNum;
	int err;
	
	cleanString2PascalString(cs_path,ps_path);
	err	= DetermineVRefNum(ps_path, &vRefNum);
	if (err)
		return mac_error_to_clean_error(err);
	init_parameter_block(ps_path, vRefNum, &pb);
	
	cleanString2PascalString(cs_name, ps_name);
	pb.ioParam.ioMisc = (char *) ps_name;
	err	= PBHRenameSync(&pb);
	return mac_error_to_clean_error(err);
}

