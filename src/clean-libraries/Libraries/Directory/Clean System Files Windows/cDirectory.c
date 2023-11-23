// version 1.1

#include <windows.h>
#include <direct.h>
#include "Clean.h"

// error codes:
#define NoDirError			 0
#define OtherDirError		-1
#define DoesntExist			-2
#define BadName				-3
#define NotEnoughSpace		-4
#define AlreadyExists		-5
#define NoPermission		-6
#define MoveIntoOffspring	-7
#define MoveAcrossDisks		-8
#define NotYetRemovable		-9

HANDLE			ghSearch;
WIN32_FIND_DATA	gWFD;
 
static int pc_error_to_clean_error(int pc_error)
{
	switch(pc_error) {
	case ERROR_SUCCESS:				return NoDirError;
	case ERROR_FILE_NOT_FOUND:
	case ERROR_INVALID_DRIVE:
	case ERROR_PATH_NOT_FOUND:
	case ERROR_BAD_NET_NAME:		return DoesntExist;
	case ERROR_BAD_PATHNAME:
	case ERROR_INVALID_NAME:		return BadName;
	case ERROR_DISK_FULL:
	case ERROR_HANDLE_DISK_FULL:	return NotEnoughSpace;
	case ERROR_ALREADY_EXISTS:
	case ERROR_FILE_EXISTS:			return AlreadyExists;
	case ERROR_DRIVE_LOCKED:
	case ERROR_SHARING_VIOLATION:
	case ERROR_ACCESS_DENIED:
	case ERROR_WRITE_PROTECT:
	case ERROR_LOCK_VIOLATION:		return NoPermission;
	case ERROR_DIR_NOT_EMPTY:		return NotYetRemovable;
	default:						return OtherDirError;
	};
}

// unhandled: NotADirectory, MoveIntoOffspring


int findFirstFileC(CleanString cs_path)
{
	char	*cPath;
	int		length,i,clean_err;

	ghSearch = INVALID_HANDLE_VALUE;
	length	= CleanStringLength(cs_path);
	if (CleanStringCharacters(cs_path)[length-1]=='\\')
		length--;
	cPath	= GlobalAlloc(LMEM_FIXED, length+3); // +3 for adding "\\*\0"
	if (!cPath)
		return -1;
	else {	// make a C string with "\\*" appended
		for(i=0; i<length; i++)
			cPath[i]	= CleanStringCharacters(cs_path)[i];
		cPath[length  ]	= '\\';
		cPath[length+1]	= '*';
		cPath[length+2]	= '\0';
		ghSearch	= FindFirstFile(cPath,&gWFD);
		clean_err = ghSearch==INVALID_HANDLE_VALUE ? pc_error_to_clean_error(GetLastError()) : NoDirError;
		GlobalFree(cPath);
		return clean_err;
		};
}

void getCommonFileInfoC(int also_get_file_name,
						CleanString *pFileName, int *pFileSizeLow, int *pFileSizeHigh,
						int *pYear, int *pMonth, int *pDay, int *pDayNr,
						int *pHours, int *pMinutes, int *pSeconds,
						int *pIsDirectory, int *pIsReadOnly)
{
	static int	null=0;
		
	FILETIME	localFileTime;
	SYSTEMTIME	systemTime,localSystemTime;
	int			i;
	static CleanStringVariable(fileName,MAX_PATH);
	static size_t nix = 0;

	if (also_get_file_name) {
		for(i=0; gWFD.cFileName[i]!='\0' && i<MAX_PATH; i++)
			CleanStringCharacters(fileName)[i]	= gWFD.cFileName[i];
		CleanStringLength(fileName)	= i;
		*pFileName		= (CleanString) fileName;
		}
	else
		*pFileName		= (CleanString) &nix;
	*pFileSizeLow	= gWFD.nFileSizeLow;
	*pFileSizeHigh	= gWFD.nFileSizeHigh;

	if (FileTimeToSystemTime (&gWFD.ftLastWriteTime,&systemTime)
		&& SystemTimeToTzSpecificLocalTime (NULL,&systemTime,&localSystemTime))
	{
		*pYear		= localSystemTime.wYear;
		*pMonth		= localSystemTime.wMonth;
		*pDay		= localSystemTime.wDay;
		*pDayNr		= localSystemTime.wDayOfWeek+1;
		*pHours		= localSystemTime.wHour;
		*pMinutes	= localSystemTime.wMinute;
		*pSeconds	= localSystemTime.wSecond;
	} else {
		*pYear		= 0;
		*pMonth		= 0;
		*pDay		= 0;
		*pDayNr		= 1;
		*pHours		= 0;
		*pMinutes	= 0;
		*pSeconds	= 0;
	}

	*pIsDirectory	= (gWFD.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
	*pIsReadOnly	= (gWFD.dwFileAttributes & FILE_ATTRIBUTE_READONLY) != 0;
}

#define ALT_LENGTH 14

void getWindowsFileInfoC(int *pFileAttributes,
						int *pCYear, int *pCMonth, int *pCDay, int *pCDayNr,		// creation time
						int *pCHours, int *pCMinutes, int *pCSeconds,				// dito	
						int *pLAYear, int *pLAMonth, int *pLADay, int *pLADayNr,	// last access time
						int *pLAHours, int *pLAMinutes, int *pLASeconds,			// dito	
						CleanString *pDOSName, int *pIsHidden)
{
	FILETIME	localFileTime;
	SYSTEMTIME	systemTime,localSystemTime;
	int			i;
	static CleanStringVariable(fileName,ALT_LENGTH);

	*pFileAttributes	= gWFD.dwFileAttributes;

	if (FileTimeToSystemTime (&gWFD.ftCreationTime,&systemTime)
		&& SystemTimeToTzSpecificLocalTime (NULL,&systemTime,&localSystemTime))
	{
		*pCYear		= localSystemTime.wYear;
		*pCMonth	= localSystemTime.wMonth;
		*pCDay		= localSystemTime.wDay;
		*pCDayNr	= localSystemTime.wDayOfWeek+1;
		*pCHours	= localSystemTime.wHour;
		*pCMinutes	= localSystemTime.wMinute;
		*pCSeconds	= localSystemTime.wSecond;
	} else {
		*pCYear		= 0;
		*pCMonth	= 0;
		*pCDay		= 0;
		*pCDayNr	= 1;
		*pCHours	= 0;
		*pCMinutes	= 0;
		*pCSeconds	= 0;
	}

	if (FileTimeToSystemTime (&gWFD.ftLastAccessTime,&systemTime)
		&& SystemTimeToTzSpecificLocalTime (NULL,&systemTime,&localSystemTime))
	{
		*pLAYear	= localSystemTime.wYear;
		*pLAMonth	= localSystemTime.wMonth;
		*pLADay		= localSystemTime.wDay;
		*pLADayNr	= localSystemTime.wDayOfWeek+1;
		*pLAHours	= localSystemTime.wHour;
		*pLAMinutes	= localSystemTime.wMinute;
		*pLASeconds	= localSystemTime.wSecond;
	} else {
		*pLAYear	= 0;
		*pLAMonth	= 0;
		*pLADay		= 0;
		*pLADayNr	= 1;
		*pLAHours	= 0;
		*pLAMinutes	= 0;
		*pLASeconds	= 0;
	}

	for(i=0; gWFD.cAlternateFileName[i]!='\0' && i<ALT_LENGTH; i++)
		CleanStringCharacters(fileName)[i]	= gWFD.cAlternateFileName[i];
	CleanStringLength(fileName)	= i;
	*pDOSName		= (CleanString) fileName;
	*pIsHidden		= (gWFD.dwFileAttributes & FILE_ATTRIBUTE_HIDDEN) != 0;
}

int findNextFileC(int dummy)
{
	return FindNextFile(ghSearch, &gWFD) ? 0 : 1;
}

int findSingleFileC(CleanString cs_path)
{	
	ghSearch	= FindFirstFile(CleanStringCharacters(cs_path),&gWFD);
	return ghSearch==INVALID_HANDLE_VALUE ? pc_error_to_clean_error(GetLastError()) : NoDirError;
}

void getMacFileInfoC()
{}

void getUnixFileInfoC()
{}

void closeSearchC()
{
	FindClose(ghSearch);
}

void closeSingleSearchC()
{
	FindClose(ghSearch);
}

int createDirectoryC(CleanString cs_path)
{
	int ok;

	ok = CreateDirectory(CleanStringCharacters(cs_path), NULL);
	return ok ? NoDirError : pc_error_to_clean_error(GetLastError());
}

int fremoveC(CleanString cs_path)
{
	int ok,  errCode;
	
	ok = DeleteFile(CleanStringCharacters(cs_path));
	if (ok)
		errCode = ERROR_SUCCESS;
	else {
		errCode = GetLastError();
		if (errCode==ERROR_FILE_NOT_FOUND 
			|| errCode == ERROR_ACCESS_DENIED /*&& CleanStringCharacters(cs_path)[0]=='\\'*/) 
			   // ERROR_ACCESS_DENIED happens when a folder in a network path is tried to be removed with
			   // DeleteFile()
			{
			ok = RemoveDirectory(CleanStringCharacters(cs_path));
			if (ok)
				errCode = ERROR_SUCCESS;
			else
				errCode = GetLastError();
			};
		};
	return errCode==ERROR_ACCESS_DENIED ? NotYetRemovable : pc_error_to_clean_error(errCode);
}


#define OK 0
#define STRING_TOO_SMALL 1
#define FATAL_ERROR 2

int getCurrentDirectory_SE(CleanString cs)
{
	unsigned int neededSize;
	neededSize = GetCurrentDirectory(CleanStringLength(cs), CleanStringCharacters(cs));
	if (neededSize==0)
		return FATAL_ERROR;
	else {
		if (neededSize>CleanStringLength(cs))
			return STRING_TOO_SMALL;
		else {
			CleanStringLength(cs) = neededSize;
			return OK;
			};
		};
}

int setCurrentDirectoryC(CleanString csPath)
{
	int ok;
	ok = SetCurrentDirectory(CleanStringCharacters(csPath));
	return ok ? NoDirError : pc_error_to_clean_error(GetLastError());
}


void get_mac_dir_parent_and_name_C()
{}


int getPlatformIdC(int dummy)
{
#define WindowsPlatform 1
	return WindowsPlatform;
}

void getMacDiskNameC()
{}


int get_windows_disk_available_bits_C(int dummy)
{
	return GetLogicalDrives();
}

int fmoveC(int overwrite, CleanString from, CleanString to)
{
	int ok, last_error;

	ok = MoveFile(CleanStringCharacters(from), CleanStringCharacters(to));
	if (!ok && overwrite && GetLastError()==ERROR_ALREADY_EXISTS) {
		if (!DeleteFile(CleanStringCharacters(to)))
			return AlreadyExists;
		else
			ok = MoveFile(CleanStringCharacters(from), CleanStringCharacters(to));
		};
	if (ok)
		return NoDirError;
	else {
		last_error = GetLastError();
		return last_error==ERROR_ACCESS_DENIED ? MoveIntoOffspring : pc_error_to_clean_error(last_error);
		};
}

void macMoveC()
{}

void macRenameC()
{}

