#ifndef __MACH__
#include <PMApplication.h>
#include <PMDefinitions.h>
#include <PMCore.h>
#include <Carbon.h>
#else
#include <Carbon/Carbon.h>
#endif
#include "Clean.h"

typedef struct pass_object *PassObject;
/*	with a PassObject one can pass strings back to Clean. It's first DWORD
	contains the size of the object -8, the second DWORD contains the length
	of the string, and the rest contains the string itself. In

	PassObject	pObj;

	the following expression points to a Clean string:

	((char*)passObj)[4] 
*/

#define	kDontScaleOutput	nil

static PMPrintSession	gPrintSession	= NULL;
static PMPrintSettings	gPrintSettings	= NULL;

static int	prGrafPortOK = 0;
static GrafPtr	prGrafPort;
static int	prXRes;
static int	prYRes;
	// prGrafPortOK indicates, that printing is in progress. prOpenDoc sets this
	// flag to True, and only prEndDoc sets it again to False, so these two functions
	// MUST be balanced in every condition (exception: abort) 
	// prGrafPortOK <=> prGrafPort, prXRes & prYRes are valid
PassObject	passObj1 = NULL;
	
int CStringLength(char* string)
// returns length of C string INCLUDING the '\0'
{
	int i=0;
	while(string[i]!='\0')
		i++;
	i++;
	return i;
}

CleanString PassMacHandle(PassObject *pPassObj,char** data,unsigned int size, int *pErr)
// err code: 0==ok; 1==out of memory
{
	unsigned int	passObjSize,i;
	PassObject		passObj;

	if (*pPassObj==NULL)
		{
		*pPassObj	= (PassObject) NewPtr(size+8);

		if (*pPassObj==NULL)
			{	*pErr	= 1;
				((unsigned int*)*pPassObj)[1]	= 0;
				return (CleanString) (((unsigned int*)*pPassObj)+1);
			};
		((unsigned int*)*pPassObj)[0]	= size;
		};

	passObjSize	= ((unsigned int*)*pPassObj)[0];
	if (passObjSize<size)
		{
		DisposePtr((char*)*pPassObj);

		*pPassObj	= (PassObject) NewPtr(size+8);
		if (*pPassObj==NULL)
			{	*pErr	= 1;
				((unsigned int*)*pPassObj)[1]	= 0;
				return (CleanString) (((unsigned int*)*pPassObj)+1);
			};
		((unsigned int*)*pPassObj)[0]	= size;
		};
	// now the pass object is big enough, so fill it with data
	passObj		= *pPassObj;
	((unsigned int*)passObj)[1]	= size;
	for(i=0; i<size; i++)
		((char*)passObj)[i+8]	= (*data)[i];
	*pErr	= 0;

	return (CleanString) (((unsigned int*)passObj)+1);
}

void getDefaultPrintSetupC(int *pErr, CleanString *pCleanString)
{
	OSStatus		status			= noErr;
	PMPrintSession	printSession	= NULL;
	PMPageFormat	pageFormat		= kPMNoPageFormat;
	
	status = PMCreateSession(&printSession);
	if (status == noErr)
	{
		status = PMCreatePageFormat(&pageFormat);
		if ((status == noErr) && (pageFormat != kPMNoPageFormat))
		{
			status = PMSessionDefaultPageFormat(printSession,pageFormat);
		}
		else
		{
			if (status == noErr)
				status = kPMGeneralError;
		}
	}
	if (status == noErr)
	{
		Handle			flattenFormat	= NULL;
		
		PMFlattenPageFormat(pageFormat, &flattenFormat);
		*pCleanString = PassMacHandle(&passObj1,flattenFormat,GetHandleSize(flattenFormat),pErr);
		DisposeHandle(flattenFormat);
		flattenFormat = NULL;
		PMRelease(pageFormat);
		pageFormat = kPMNoPageFormat;
	}
	else
	{
		if (pageFormat != kPMNoPageFormat)
		{
			PMRelease(pageFormat);
			pageFormat = kPMNoPageFormat;
		}
		if (printSession != NULL)
		{
			PMRelease(printSession);
			printSession = NULL;
		}
	}
	return;
}

static GrafPtr gSavePort;

void prOpenPage(PMPageFormat pageFormat, int os, int *okReturn, int *osReturn)
{
	OSStatus err;
	GrafPtr printingContext = NULL;
	
	*osReturn = os;
	*okReturn = 0;

	err = PMSessionBeginPage(gPrintSession,pageFormat,kDontScaleOutput);
	if (err!=noErr)
		{
//		DebugStr("\pError in PMSessionBeginPage");
		*okReturn = err;
		return;
		}
	err = PMSessionError(gPrintSession);
	if (err!=noErr)
		{
//		DebugStr("\pError in PMSessionError");
		*okReturn = err;
		return;
		}

	GetPort(&gSavePort);
	err = PMSessionGetGraphicsContext(gPrintSession,kPMGraphicsContextQuickdraw,(void**)&printingContext);
	if (err!=noErr)
		{
//		DebugStr("\pError in PMSessionGetGraphicsContext");
		*okReturn = err;
		return;
		}
	SetPort(printingContext);
	prGrafPort = printingContext;
}

void prClosePage(PMPageFormat pageFormat, int os, int *okReturn, int *osReturn)
{
	OSStatus err;
	
	*osReturn = os;
	err = PMSessionEndPage(gPrintSession);
	err = PMSessionError(gPrintSession);
	*okReturn = err==noErr;
	
	SetPort(gSavePort);
}

void prOpenDoc(PMPageFormat pageFormat, int os, int *err, int *grPortReturn, int *osReturn)
// error codes: 0=noErr, 2=non fatal error (especially user abort)
// 1 = fatal error.
{
	*osReturn = os;
	*err = PMSessionBeginDocument(gPrintSession,gPrintSettings,pageFormat);
	if (*err!=noErr)
		{
//		DebugStr("\pError in PMSessionBeginDocument");
		return;
		}
	*grPortReturn = (int)pageFormat;
	
	*err = PMSessionError(gPrintSession);
	if (*err!=noErr)
		{
//		DebugStr("\pError in PMSessionError");
		return;
		}
	
	if (*err==noErr) 
		  {	*err=0;
			prGrafPortOK = 1;
		  }
	else if (*err==iMemFullErr) *err=1;
	else *err=2;
}

int prCloseDoc(PMPageFormat pageFormat, int os, int pRecHandle)
{
	OSStatus	err;
	
	prGrafPortOK = 0;
	
	err = PMSessionEndDocument(gPrintSession);
	err = PMSessionError(gPrintSession);
	return os;
}

OSStatus setMaxResolution(PMPageFormat *pageFormat)
{
	OSStatus		err;
	Boolean			changed;
	PMPrinter		myPrinter;
	PMResolution	myResolution;
	
	err	= PMSessionGetCurrentPrinter(gPrintSession, &myPrinter);
	if (err != noErr)
		{
//		DebugStr("\pError in setMaxResolution:PMSessionGetCurrentPrinter");
		return err;
		};
	err = PMPrinterGetPrinterResolution(myPrinter,kPMMaxSquareResolution,&myResolution);
	if (err != noErr)
		{
//		DebugStr("\pError in setMaxResolution:PMPrinterGetPrinterResolution");
		return err;
		};
	err	= PMSetResolution(*pageFormat,&myResolution);
	if (err != noErr)
		{
//		DebugStr("\pError in setMaxResolution:PMSetResolution");
		return err;
		};
	err	= PMSessionValidatePageFormat(gPrintSession,*pageFormat, &changed);
	if (err != noErr)
		{
//		DebugStr("\pError in setMaxResolution:PMSessionValidatePageFormat");
		return err;
		};
	return err;
}

void allocPrintRecord(PMPrintSession printSession,CleanString printSetup,PMPageFormat *pageFormat,int *pErr)
// error code: 0 no error; 1=out of memory
{
	int				length,i;
	char			*from,*to;
	Handle			handle	= NULL;
	Boolean			changed;
	OSStatus		err;
	
	length	= CleanStringLength(printSetup);
	handle	= NewHandle(length);
	if (handle==NULL)
		{	*pErr	= 1;
			return;
		};
	from	= CleanStringCharacters(printSetup);
	to		= (char*) *handle;
	for(i=0;i<length;i++)
		to[i]	= from[i];

	err = PMCreatePageFormat(pageFormat);
	if (err != noErr)
		{	*pErr = 1;
//			DebugStr("\pCreatePF failed");
			return;
		};
	err = PMUnflattenPageFormat(handle,pageFormat);
	if (err != noErr)
		{	*pErr = 1;
//			DebugStr("\pUnflatten failed");
			return;
		};
	err = PMSessionValidatePageFormat(printSession,*pageFormat, &changed);
	if (err != noErr)
		{	*pErr = 1;
//			DebugStr("\pValidate failed");
			return;
		};
	
	*pErr		= 0;
}


//static PMPageFormat sPageFormat = kPMNoPageFormat;

void getPageDimensionsC(	CleanString printSetup, int emulateScreen,
							int *pErr,
							int *maxX, int *maxY,
							int *leftPaper, int *topPaper,
							int *rightPaper, int *bottomPaper,
							int *xRes, int *yRes
						 )
{
//	PMPageFormat	pageFormat;
	PMPageFormat	sPageFormat = kPMNoPageFormat;
	PMRect			rect;
	PMResolution	res;
	OSStatus		err;
	
//	if (!prGrafPortOK) PMBegin();
	if (!prGrafPortOK)
		{
		err = PMCreateSession(&gPrintSession);
		if (err != noErr) {
			*pErr	= err;
//			DebugStr("\pgetPageDimensionsC:PMCreateSession failed");
			return;
			};
		};
	
	allocPrintRecord(gPrintSession,printSetup,&sPageFormat,pErr);
	if (*pErr)
		{
		if (!prGrafPortOK)
			{
			PMRelease(gPrintSession);
			gPrintSession = NULL;
			};
		return;
		};
	if (!emulateScreen)
		{
		err			= setMaxResolution(&sPageFormat);
		};
	if (err != noErr)
		{
//			DebugStr("\psetMaxResolution failed");
			*pErr = err;
			if (!prGrafPortOK)
				{
				PMRelease(gPrintSession);
				gPrintSession = NULL;
				};
			return;
		};

	err				= PMGetAdjustedPageRect(sPageFormat,&rect);
	if (err != noErr)
		{
//			DebugStr("\pGetAdjustedPageRect failed");
			*pErr = err;
			if (!prGrafPortOK)
				{
				PMRelease(gPrintSession);
				gPrintSession = NULL;
				};
			return;
		};
	*maxX			= (int)rect.right;
	*maxY			= (int)rect.bottom;
	// According to "Inside Macintosh, ...Quickdraw.." rPage.left and rPage.top are always zero 

//    status			= PMGetAdjustedPaperRect(sPageFormat,rect);
//    *leftPaper		= (int)rect->left;
//	*topPaper		= (int)rect->top;
//	*rightPaper		= (int)rect->right;
//	*bottomPaper	= (int)rect->bottom;

	err				= PMGetResolution(sPageFormat,&res);
	if (err != noErr)
		{
//			DebugStr("\pGetResolution failed");
			*pErr = err;
			if (!prGrafPortOK)
				{
				PMRelease(gPrintSession);
				gPrintSession = NULL;
				};
			return;
		};
	*xRes			= (int)res.hRes;
    *yRes			= (int)res.vRes;
//    PMDisposePageFormat(sPageFormat);
//	DebugStr("\pOK to here");

/*
	return;
	
}

void getPageDimensionsMore( int *pErr,
							int *leftPaper, int *topPaper,
							int *rightPaper, int *bottomPaper
							)
{
	PMRect			rect;
	OSStatus		err;

	*pErr = 0;
*/	
    err				= PMGetAdjustedPaperRect(sPageFormat,&rect);
	if (err != noErr)
		{
//			DebugStr("\pPMGetAdjustedPaperRect failed");
			*pErr = err;
			if (!prGrafPortOK)
				{
				PMRelease(gPrintSession);
				gPrintSession = NULL;
				};
			return;
		};
    *leftPaper		= (int)rect.left;
	*topPaper		= (int)rect.top;
	*rightPaper		= (int)rect.right;
	*bottomPaper	= (int)rect.bottom;

    if (sPageFormat != kPMNoPageFormat)
    	{
//		    err				= PMDisposePageFormat(sPageFormat);
		    err				= PMRelease(sPageFormat);
		};
	if (err != noErr)
		{
//			DebugStr("\pPMRelease failed");
			*pErr = err;
			if (!prGrafPortOK)
				{
				PMRelease(gPrintSession);
				gPrintSession  = NULL;
				};
			return;
		};
//	if (!prGrafPortOK) PMEnd();
	if (!prGrafPortOK)
		{
		PMRelease(gPrintSession);
		gPrintSession = NULL;
		};

//	DebugStr("\pOK to here");

	return;
}

void printSetupDialogC(CleanString inSetup, int *pErr, CleanString *pOutSetup)
{
	PMPrintSession	printSession;
	PMPageFormat	pageFormat = kPMNoPageFormat;
	Boolean			changed, accepted;
	OSStatus		err;
/*
	err = PMBegin();
	if (err != noErr) {
		*pErr = err;
		*pOutSetup	= inSetup;
		DebugStr("\pprintSetupDialog:PMBegin failed");
		return;
		}

	allocPrintRecord(inSetup,&pageFormat,pErr);
	if (*pErr) {
		*pOutSetup	= inSetup;
		DebugStr("\pprintSetupDialog:allocPrintRecord failed");
		return;
		}

	err = PMValidatePageFormat(pageFormat, &changed);
	if (err != noErr) {
		*pErr = err;
		*pOutSetup	= inSetup;
		DebugStr("\pprintSetupDialog:PMValidatePageFormat failed");
		return;
		}

	err = PMEnd();
	if (err != noErr) {
		*pErr = err;
		*pOutSetup	= inSetup;
		DebugStr("\pprintSetupDialog:PMEnd failed");
		return;
		}
*/	
	err = PMCreateSession(&printSession);
	if (err != noErr) {
		*pErr = err;
		*pOutSetup	= inSetup;
//		DebugStr("\pprintSetupDialog:PMCreateSession failed");
		return;
		}
	allocPrintRecord(printSession,inSetup,&pageFormat,pErr);
	if (*pErr) {
		*pOutSetup	= inSetup;
//		DebugStr("\pprintSetupDialog:allocPrintRecord failed");
		return;
		}

	err = PMSessionValidatePageFormat(printSession,pageFormat, &changed);
	if (err != noErr) {
		*pErr = err;
		*pOutSetup	= inSetup;
//		DebugStr("\pprintSetupDialog:PMSessionValidatePageFormat failed");
		return;
		}

	err = PMSessionPageSetupDialog(printSession,pageFormat,&accepted);

	if (err != noErr) {
		*pErr = err;
		*pOutSetup	= inSetup;
//		DebugStr("\pprintSetupDialog:PMSessionPageSetupDialog failed");
		PMRelease(printSession);
		return;
		}
	if (err == noErr && accepted)
	{
		Handle			flattenFormat	= NULL;
		
		err = PMFlattenPageFormat(pageFormat, &flattenFormat);

		*pOutSetup = PassMacHandle(&passObj1,flattenFormat,GetHandleSize(flattenFormat),pErr);

		DisposeHandle(flattenFormat);
	}
	  else
		*pOutSetup	= inSetup;

	if (err != noErr) {
		*pErr = err;
//		DebugStr("\pprintSetupDialog:PMFlattenPageFormat failed");
		return;
		}
	err = PMRelease(printSession);

	if (err != noErr) {
		*pErr = err;
//		DebugStr("\pprintSetupDialog:PMRelease(printSession) failed");
		return;
		}
	if (pageFormat != kPMNoPageFormat)
		{
			err = PMRelease(pageFormat);
		}

	if (err != noErr) {
		*pErr = err;
//		DebugStr("\pprintSetupDialog:PMRelease(pageFormat) failed");
		return;
		}
	*pErr		= err;
}

void getPrintInfoC( int doDialog, int emulateScreen, CleanString inSetup, int unq,
					int *pErr,
					int *pRecHandleP,
					int *first, int *last,
					int *copies,
					CleanString *pOutSetup,
					int *unqReturn
				  )
// error code: 0==ok, 1=out of memory, 2==user cancelled
{
	PMPageFormat	pageFormat = kPMNoPageFormat;
	PMResolution	res;
	Boolean			changed, accepted;
	OSStatus		err;
	void		*pTemp;
		
	*unqReturn = unq;

	*pOutSetup = inSetup;
	
	// check whether there is enough extra memory for printing
	pTemp	= NewPtr(200000);
	if (!pTemp) {
		*pErr	= 1;
		return;
		};
	DisposePtr(pTemp);

	*pRecHandleP = (int) pageFormat;

	err = PMCreateSession(&gPrintSession);
	if (err != noErr) {
		*pErr	= err;
//		DebugStr("\pgetPrintInfoC:PMCreateSession failed");
		return;
		};
	
	allocPrintRecord(gPrintSession,inSetup,&pageFormat,pErr);
	if (*pErr)
		return;

	if (!emulateScreen)
		{
		err	= setMaxResolution(&pageFormat);
		};
	if (err != noErr) {
		*pErr	= err;
//		DebugStr("\pgetPrintInfoC:setMaxResolution failed");
		return;
		};

	err = PMSessionValidatePageFormat(gPrintSession,pageFormat,&changed);
	if (err != noErr) {
		*pErr	= err;
//		DebugStr("\pgetPrintInfoC:PMSessionValidatePageFormat failed");
		return;
		};
	if (changed)
		{
		Handle			flattenFormat	= NULL;
		
		err = PMFlattenPageFormat(pageFormat, &flattenFormat);
		if (err != noErr) {
			*pErr	= err;
//			DebugStr("\pgetPrintInfoC:PMFlattenPageFormat failed");
			return;
			};
		*pOutSetup = PassMacHandle(&passObj1,flattenFormat,GetHandleSize(flattenFormat),pErr);
		DisposeHandle(flattenFormat);
		if (*pErr)
			return;
		};
		
	err = PMCreatePrintSettings(&gPrintSettings);
	if (err != noErr) {
		*pErr	= err;
//		DebugStr("\pgetPrintInfoC:PMCreatePrintSettings failed");
		return;
		};
	err = PMSessionDefaultPrintSettings(gPrintSession,gPrintSettings);
	if (err != noErr) {
		*pErr	= err;
//		DebugStr("\pgetPrintInfoC:PMSessionDefaultPrintSettings failed");
		return;
		};
	
	if (doDialog)
	  {	
	  	err = PMSessionPrintDialog(gPrintSession,gPrintSettings,pageFormat,&accepted);
		if (err != noErr || !accepted)
		  {
		  	PMRelease(gPrintSession);
		  	PMRelease(gPrintSettings);
		  	gPrintSession = NULL;
		  	gPrintSettings = NULL;
//		    *pErr = 2;
			*pErr	= (err != noErr) ? err : 2;
//			DebugStr("\pgetPrintInfoC:PMSessionPrintDialog failed");
		  	return;
		  };
	  };

	*pErr = 0;

   	err = PMGetFirstPage(gPrintSettings,(UInt32 *)first);
	if (err != noErr) {
		*pErr	= err;
//		DebugStr("\pgetPrintInfoC:PMGetFirstPage failed");
		return;
		};
    err = PMGetLastPage(gPrintSettings,(UInt32 *)last);
	if (err != noErr) {
		*pErr	= err;
//		DebugStr("\pgetPrintInfoC:PMGetLastPage failed");
		return;
		};
    err = PMGetCopies(gPrintSettings,(UInt32 *)copies);
	if (err != noErr) {
		*pErr	= err;
//		DebugStr("\pgetPrintInfoC:PMGetCopies failed");
		return;
		};

	// reset the values for first and last page. This is also done in the 
	// "imaging with quickdraw" example. (otherwise the following could
	// happen: user chooses range 3..5, program generates 3 pages (nr 3..nr 5),
	// print manager leaves out two of them, only page nr. 5 is printed
	
	err = PMSetFirstPage(gPrintSettings,1,false);
	if (err != noErr) {
		*pErr	= err;
//		DebugStr("\pgetPrintInfoC:PMSetFirstPage failed");
		return;
		};
	err = PMSetLastPage(gPrintSettings,kPMPrintAllPages,false);
	if (err != noErr) {
		*pErr	= err;
//		DebugStr("\pgetPrintInfoC:PMSetLastPage failed");
		return;
		};
	
	// store printer resolution in globals for later use in getResolutionC and adjustToPrinterRes
	err			= PMGetResolution(pageFormat,&res);
	if (err != noErr) {
		*pErr	= err;
//		DebugStr("\pgetPrintInfoC:PMGetResolution failed");
		return;
		};
	prXRes		= (int)res.hRes;
    prYRes		= (int)res.vRes;
}

int prClose(int os)
{
	PMRelease(gPrintSession);
	PMRelease(gPrintSettings);
	gPrintSession = NULL;
	gPrintSettings = NULL;
	return os;
}

int	isPrinting()
// if the current grafport is the printer grafport, then strech the size accordingly
// This function is called in quickdraw.icl
{
	GrafPtr		curGrafPort;

    if (!prGrafPortOK)
		return 0;
	  else		
		{ GetPort(&curGrafPort);
	 	  return (int) curGrafPort == (int) prGrafPort;
	 	};
}

int	adjustToPrinterRes(int scrnSize)
// if the current grafport is the printer grafport, then stretch the size accordingly
// This function is called in quickdraw.icl
{
	short scrnXRes,scrnYRes;

	if (isPrinting())
		{	ScreenRes(&scrnXRes,&scrnYRes);
			return (scrnSize*prYRes) / scrnYRes;
		}
	else
		return scrnSize;

	
}

void getResolutionC(int *xResP, int *yResP)
{
	short scrnXRes,scrnYRes;
	if (isPrinting())
		{	*xResP = prXRes;
			*yResP = prYRes;
		}
	else
		{	ScreenRes(&scrnXRes,&scrnYRes);
			*xResP = scrnXRes;
			*yResP = scrnYRes;
		};
}

int os_printsetupvalid(CleanString inSetup)
{
	PMPageFormat	pageFormat = kPMNoPageFormat;
	Boolean			changed;
	OSStatus		status = noErr;
	int			err, handleChanged;
	
	if (!prGrafPortOK)
		//PMBegin();
		err = PMCreateSession(&gPrintSession);
	if (err != noErr)
		return 0;

	allocPrintRecord(gPrintSession,inSetup,&pageFormat,&err);
	if (err)
		{
		if (!prGrafPortOK)
			PMRelease(gPrintSession);
		return 0;
		};
/*
	if (!prGrafPortOK)
		{
		status = PMValidatePageFormat(pageFormat, &changed);
		}
	else
		{
		status = PMSessionValidatePageFormat(gPrintSession,pageFormat,&changed);
		}
*/
	status = PMSessionValidatePageFormat(gPrintSession,pageFormat,&changed);
	PMRelease(pageFormat);
	if (!prGrafPortOK)
//		PMEnd();
		PMRelease(gPrintSession);
	return (changed ? 0 : -1);	//!changed;
}
/*
OSStatus printSetupToString(PMPageFormat pageFormat, CleanString *pCleanString)
{
	OSStatus	status			= noErr;
	Handle		flattenFormat	= NULL;
	
	status = PMFlattenPageFormat(pageFormat, &flattenFormat);
	if (status != noErr)
	{
		*pCleanString = PassMacHandle(&passObj1,flattenFormat,GetHandleSize(flattenFormat),&status);
		DisposeHandle(flattenFormat);
		flattenFormat = NULL;
	}
	return status;
}
int stringToPrintSetup(CleanString printSetup)
*/
