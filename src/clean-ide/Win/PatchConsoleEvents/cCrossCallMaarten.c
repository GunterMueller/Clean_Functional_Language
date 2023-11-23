#define WINVER 0x0500

#include "util_121.h"
#include <Windows.h>
#include <Windowsx.h>
#include "cCCallWindows_121.h"
#include "cCCallSystem_121.h"
#include "cCrossCallWindows_121.h"
#include "cCrossCall_121.h"
#include "cAcceleratorTable_121.h"
#include "cCrossCallxDI_121.h"

#define CcRqALTFILESAVEDIALOG						1479
#define CcRqALTFILEOPENDIALOG						1478
//#define CcRqGETBITMAPRESOURCE						1477		/* Get bitmap handle */
#define CcRqSHELLDEFAULT							1476		/* shell execute interface */
#define CcRqALTDIRECTORYDIALOG						1475		/* alternative directory selector */
#define CcRqSETWINDOWICON							1474		/* Set icon associated with window */
#define CcRqADDWINDOWHOOK							1473		/*  */
#define CcRqSETWINDOWFRAME							1472		/*  */
#define CcRqMDMDELCONTROLTIP						1471		/* remove controls from tooltip areas. */
#define CcRqMDMADDCONTROLTIP						1470		/* add controls to tooltip areas. */

static UINT rectTTId;
//static HWND ghwndRT;
WNDPROC g_pTool0WndProc;
WNDPROC g_pTool1WndProc;
POINT FAR gFarPoint;

static int left,top;

void InitialiseCrossCallMaarten();

void EvalCcRqSETWINDOWICON (CrossCallInfo *pcci)
{
	HWND	hWnd;
	HICON	hIcon, hPrevIcon;
	int		idIcon;

	hWnd		= (HWND) pcci->p1;
	idIcon		= (int) pcci->p2;

	hIcon		= LoadIcon ((HINSTANCE)GetModuleHandle(NULL), MAKEINTRESOURCE(idIcon));

	hPrevIcon	= (HICON) SendMessage(hWnd,WM_SETICON,(WPARAM)ICON_BIG,(LPARAM)hIcon);
	
	MakeReturn0Cci (pcci);
}

extern void rfree( HGLOBAL ptr );
extern HGLOBAL rmalloc( DWORD bytes );
extern void rsncopy(char *d, const char *s, int n);


PBITMAPINFO CreateBitmapInfoStruct(HBITMAP hBmp)
{ 
    BITMAP bmp; 
    PBITMAPINFO pbmi; 
    WORD    cClrBits; 

    // Retrieve the bitmap's color format, width, and height. 
    if (!GetObject(hBmp, sizeof(BITMAP), (LPSTR)&bmp)) 
        return NULL;; 

    // Convert the color format to a count of bits. 
    cClrBits = (WORD)(bmp.bmPlanes * bmp.bmBitsPixel); 
    if (cClrBits == 1) 
        cClrBits = 1; 
    else if (cClrBits <= 4) 
        cClrBits = 4; 
    else if (cClrBits <= 8) 
        cClrBits = 8; 
    else if (cClrBits <= 16) 
        cClrBits = 16; 
    else if (cClrBits <= 24) 
        cClrBits = 24; 
    else cClrBits = 32; 

    // Allocate memory for the BITMAPINFO structure. (This structure 
    // contains a BITMAPINFOHEADER structure and an array of RGBQUAD 
    // data structures.) 

     if (cClrBits != 24) 
         pbmi = (PBITMAPINFO) GlobalAlloc(GPTR, 
                    sizeof(BITMAPINFOHEADER) + 
                    sizeof(RGBQUAD) * (1<< cClrBits)); 

     // There is no RGBQUAD array for the 24-bit-per-pixel format. 

     else 
         pbmi = (PBITMAPINFO) GlobalAlloc(GPTR, 
                    sizeof(BITMAPINFOHEADER)); 

    // Initialize the fields in the BITMAPINFO structure. 

    pbmi->bmiHeader.biSize = sizeof(BITMAPINFOHEADER); 
    pbmi->bmiHeader.biWidth = bmp.bmWidth; 
    pbmi->bmiHeader.biHeight = bmp.bmHeight; 
    pbmi->bmiHeader.biPlanes = bmp.bmPlanes; 
    pbmi->bmiHeader.biBitCount = bmp.bmBitsPixel; 
    if (cClrBits < 24) 
        pbmi->bmiHeader.biClrUsed = (1<<cClrBits); 

    // If the bitmap is not compressed, set the BI_RGB flag. 
    pbmi->bmiHeader.biCompression = BI_RGB; 

    // Compute the number of bytes in the array of color 
    // indices and store the result in biSizeImage. 
    // Width must be DWORD aligned unless bitmap is RLE compressed.
    pbmi->bmiHeader.biSizeImage = (pbmi->bmiHeader.biWidth + 15) /16 
                                  * pbmi->bmiHeader.biHeight 
                                  * cClrBits;
    // Set biClrImportant to 0, indicating that all of the 
    // device colors are important. 
     pbmi->bmiHeader.biClrImportant = 0; 
     return pbmi; 
 } 

#if 0
char *CreateBMPFile(PBITMAPINFO pbi, HBITMAP hBMP) 
 { 
    BITMAPFILEHEADER hdr;       // bitmap file-header 
    PBITMAPINFOHEADER pbih;     // bitmap info-header 
    LPBYTE lpBits;              // memory pointer 
    DWORD dwTotal;              // total count of bytes 
    DWORD cb;                   // incremental count of bytes 
    BYTE *hp;                   // byte pointer 
    DWORD dwTmp; 
	HDC hDC;
	DWORD sz;
	BYTE *hf;
	BYTE *sf;

    pbih = (PBITMAPINFOHEADER) pbi; 
    lpBits = (LPBYTE) GlobalAlloc(GMEM_FIXED, pbih->biSizeImage);

    if (!lpBits) 
         return NULL; 

	hDC = CreateDC ("DISPLAY",NULL,NULL,NULL);

    // Retrieve the color table (RGBQUAD array) and the bits 
    // (array of palette indices) from the DIB. 
    if (!GetDIBits(hDC, hBMP, 0, (WORD) pbih->biHeight, lpBits, pbi, 
        DIB_RGB_COLORS)) 
    {
        return NULL; 
    }

	DeleteDC (hDC);

    hdr.bfType = 0x4d42;        // 0x42 = "B" 0x4d = "M" 
    // Compute the size of the entire file. 
    hdr.bfSize = (DWORD) (sizeof(BITMAPFILEHEADER) + 
                 pbih->biSize + pbih->biClrUsed 
                 * sizeof(RGBQUAD) + pbih->biSizeImage); 
    hdr.bfReserved1 = 0; 
    hdr.bfReserved2 = 0; 

    // Compute the offset to the array of color indices. 
    hdr.bfOffBits = (DWORD) sizeof(BITMAPFILEHEADER) + 
                    pbih->biSize + pbih->biClrUsed 
                    * sizeof (RGBQUAD); 

    sz = sizeof (BITMAPFILEHEADER) + sizeof (BITMAPINFOHEADER) + pbih->biClrUsed * sizeof (RGBQUAD) + pbih->biSizeImage;

    sf = (char*) GlobalAlloc(GPTR, 1114);//sizeof (int) + sz);
    
	return sz;
	
    if (!sf) return NULL;
    
    hf = sf;
    
	return 42;
	
    rsncopy(hf,&sz,sizeof(int));
    hf += sizeof(int);
	
    // Copy the BITMAPFILEHEADER.
    sz = sizeof (BITMAPFILEHEADER);
    rsncopy(hf,&hdr,sz);
    hf += sz;

    // Copy the BITMAPINFOHEADER and RGBQUAD array.
    sz = sizeof(BITMAPINFOHEADER) + pbih->biClrUsed * sizeof (RGBQUAD);
    rsncopy(hf,pbih,sz);
    hf += sz;

    // Copy the array of color indices.
    sz = pbih->biSizeImage;
    rsncopy(hf,lpBits,sz);
    hf += sz;
    
    // Free memory. 
    GlobalFree((HGLOBAL)lpBits);
    return sf;
}
#endif

void EvalCcRqGETBITMAPRESOURCE (CrossCallInfo *pcci)
{
	HANDLE			hBitmap;
	int				idBitmap;
/*
	int				n,w,h;
	int				cs;
	BITMAP			bitmap;
*/
	char*			data;
//	DWORD			dwCount;
	PBITMAPINFO		pbi;

	idBitmap	= (int) pcci->p1;

	hBitmap		= LoadImage ((HINSTANCE)GetModuleHandle(NULL), MAKEINTRESOURCE(idBitmap), IMAGE_BITMAP, 0, 0, LR_CREATEDIBSECTION);
	if (hBitmap == 0) {
		MakeReturn4Cci (pcci, 0, 0, 0, 0);
		return;
	};

	pbi			 = CreateBitmapInfoStruct(hBitmap);
//	data		 = CreateBMPFile(pbi, hBitmap);
	
	MakeReturn4Cci (pcci,(size_t)hBitmap,0/*data*/,pbi->bmiHeader.biWidth,pbi->bmiHeader.biHeight);
	GlobalFree(pbi);
	return;
/*	
	pBitmap		= (char*) *((int*)hBitmap);
	n			= *((int*)(hBitmap +  2));
	w			= *((int*)(hBitmap + 18));
	h			= *((int*)(hBitmap + 22));

	MakeReturn3Cci (pcci,n,w,h);
	return;

	cs			= ncleanstring(hBitmap,n-1);
	MakeReturn3Cci (pcci,cs,w,h);
*/
}

void WinGetBitmapResource(int idBitmap, int intoolbox, size_t *outbitmap, int *width, int *height, int *outtoolbox)
{
	HANDLE			hBitmap;
	char*			data;
	PBITMAPINFO		pbi;

//	hBitmap		= LoadImage ((HINSTANCE)GetModuleHandle(NULL), MAKEINTRESOURCE(idBitmap), IMAGE_BITMAP, 0, 0, LR_CREATEDIBSECTION);
//	hBitmap		= LoadImage ((HINSTANCE)GetModuleHandle(NULL), MAKEINTRESOURCE(idBitmap), IMAGE_BITMAP, 0, 0, 0x1020);//LR_DEFAULTCOLOR | LR_LOADTRANSPARENT | LR_LOADMAP3DCOLORS);
	hBitmap		= LoadImage ((HINSTANCE)GetModuleHandle(NULL), MAKEINTRESOURCE(idBitmap), IMAGE_BITMAP, 0, 0, LR_LOADMAP3DCOLORS);
	if (hBitmap == 0) {
		*outbitmap = 0;
		*width = 0;
		*height = 0;
		*outtoolbox = intoolbox;
		return;
		};

	pbi			 = CreateBitmapInfoStruct(hBitmap);
//	data		 = CreateBMPFile(pbi, hBitmap);
	
	*width = pbi->bmiHeader.biWidth;
	*height = pbi->bmiHeader.biHeight;
	GlobalFree(pbi);
	*outbitmap = (size_t)hBitmap;
	*outtoolbox = intoolbox;
	return;
}

#ifdef _WIN64
static int APIENTRY DirectorySelectorHook (HWND hdlg, UINT uiMsg, LPARAM wParam, LPARAM lParam)
#else
static UINT APIENTRY DirectorySelectorHook (HWND hdlg, UINT uiMsg, WPARAM wParam, LPARAM lParam)
#endif
{
	if (uiMsg == BFFM_INITIALIZED)
	{
		SendMessage (hdlg, BFFM_SETSELECTIONA, 1, lParam);
	}

	return 0;
}

#ifdef _WIN64
static UINT_PTR APIENTRY FileSelectorHook (HWND hdlg, UINT uiMsg, WPARAM wParam, LPARAM lParam)
#else
static UINT APIENTRY FileSelectorHook (HWND hdlg, UINT uiMsg, WPARAM wParam, LPARAM lParam)
#endif
{
	if (uiMsg == WM_INITDIALOG)
	{
		RECT	rect;
		int		x, y;
		GetWindowRect (hdlg, &rect);
		
		x	= (GetSystemMetrics (SM_CXSCREEN)>>1) - ((rect.right-rect.left)>>1);
		y	= (GetSystemMetrics (SM_CYSCREEN)>>1) - ((rect.bottom-rect.top)>>1);
		SetWindowPos (hdlg, NULL, x, y, 0, 0, SWP_NOACTIVATE | SWP_NOSIZE | SWP_NOZORDER);

		if (lParam!=0 && ((LPOPENFILENAME)lParam)->lCustData!=0)
			SendMessage(GetParent(hdlg),CDM_SETCONTROLTEXT,IDOK,((LPOPENFILENAME)lParam)->lCustData);
	}

	return 0;
}

#define MAXBUF 300
#define MAXFILTERS     10
static LPTSTR lpszFilterString ;
static TCHAR szFilterString[MAXBUF] ;
static TCHAR szFilterInits[MAXFILTERS][30] ;

void InitFilterString(void)
{
  int i ;
  int nInc = 0 ;
  LPTSTR lpStr = szFilterString ;


  /* First, zero out this memory just for the sake of sanity */

  for (i=0; i<MAXBUF; i++)
    szFilterString[i] = 0 ;


  /* Now, for each string in the szFilterInits array, concatenate it to
     the last one right after the last one's null terminator */

  i = 0 ;

  while (szFilterInits[i][0] != (TCHAR) 0)
  {
    lstrcpy(lpStr, &szFilterInits[i][0]) ;
    nInc+=lstrlen(&szFilterInits[i][0]) + 1 ;   //1 past null term...
    lpStr = &szFilterString[nInc] ;
    i++ ;
  }

  szFilterString[nInc] = (TCHAR) 0 ;  //double terminator


  /* Set the lpszFilterString to point to the memory we just filled in
     with the filters because lpszFilterString is what is in
     OPENFILENAME->lpstrFilter */

  lpszFilterString = szFilterString ;

  return ;
}

BOOL IsModernPlatform()
{ 
    OSVERSIONINFOA osvi = {0};
    osvi.dwOSVersionInfoSize = sizeof(osvi);
    GetVersionExA((OSVERSIONINFOA*)&osvi);
    return (5 <= osvi.dwMajorVersion);    
}

void EvalCcRqALTFILEOPENDIALOG (CrossCallInfo *pcci)		/* no params;  bool, textptr result; */
{
	OPENFILENAME ofn;
	BOOL recent,success;

   recent = IsModernPlatform();

   lstrcpy(&szFilterInits[0][0], TEXT("All Files (*.*)")) ;
   lstrcpy(&szFilterInits[1][0], TEXT("*.*")) ;
   szFilterInits[2][0] = (TCHAR) 0 ;

   InitFilterString();
   if (recent)
   {
	   ofn.lStructSize       = sizeof (OPENFILENAME);
   } 
   else
   {
#ifdef _WIN64
	   ofn.lStructSize       = sizeof (OPENFILENAME_NT4);
#else
	   ofn.lStructSize       = OPENFILENAME_SIZE_VERSION_400;
#endif
   } 
   
	ofn.hwndOwner         = GetActiveWindow ();
	ofn.hInstance         = NULL;
	ofn.lpstrFilter       = lpszFilterString;
	ofn.lpstrCustomFilter = NULL;
	ofn.nMaxCustFilter    = 0;
	ofn.nFilterIndex      = 0;
	ofn.lpstrFile         = (LPSTR) rmalloc (MAX_PATH);
	ofn.lpstrFile[0]      = '\0';
	ofn.nMaxFile          = MAX_PATH;
	ofn.lpstrFileTitle    = NULL;
	ofn.nMaxFileTitle     = 0;
	ofn.lpstrInitialDir   = NULL;
	ofn.lpstrTitle        = NULL;
	ofn.Flags             = 0x81c24;
		//OFN_EXPLORER
		//				  | OFN_FILEMUSTEXIST
		//				  |	OFN_HIDEREADONLY
		//				  | OFN_PATHMUSTEXIST;
//						  | OFN_NODEREFERENCELINKS;
						   
//						  | OFN_ENABLEHOOK;		// PA: OFN_ENABLEHOOK added from Ronny
	ofn.lpstrDefExt       = NULL;
	ofn.lCustData         = (LPARAM)NULL;
	ofn.lpfnHook          = &FileSelectorHook;	// PA: &FileSelectorHook instead of NULL from Ronny
	ofn.lpTemplateName    = NULL;
#if (_WIN32_WINNT >= 0x0500)
	ofn.pvReserved		  = NULL;
	ofn.dwReserved		  = 0;
	ofn.FlagsEx			  = 0;
#endif

	success = GetOpenFileName (&ofn);

	if (success)
	{
		MakeReturn2Cci (pcci, success, (size_t) ofn.lpstrFile);
		/* and have the calling clean function deallocate the filename buffer */
	}
	else
	{
		MakeReturn2Cci (pcci, success, (size_t) NULL);
		rfree (ofn.lpstrFile);
	}
}

void EvalCcRqALTFILESAVEDIALOG (CrossCallInfo *pcci)		/* promptptr, nameptr; bool, textptr result; */
{
	OPENFILENAME ofn;
	BOOL recent, success;
	char *promptptr;
	char *nameptr;
	char *okptr;

	recent = IsModernPlatform();

	promptptr = (char *) pcci->p1;
	nameptr   = (char *) pcci->p2;
	okptr     = (char *) pcci->p3;

	if (rstrlen (promptptr) == 0)
		promptptr = NULL;	/* the calling clean function will
							   deallocate the memory allocated
							   for this empty string */

	if (recent)
	{
	   ofn.lStructSize       = sizeof (OPENFILENAME);
	} 
	else
	{
#ifdef _WIN64
	   ofn.lStructSize       = sizeof (OPENFILENAME_NT4);
#else
	   ofn.lStructSize       = OPENFILENAME_SIZE_VERSION_400;
#endif
	} 

    ofn.hwndOwner         = GetActiveWindow ();
	ofn.lpstrFilter       = NULL;
	ofn.lpstrCustomFilter = NULL;
	ofn.nMaxCustFilter    = 0;
	ofn.nFilterIndex      = 0;
	ofn.lpstrFile         = (LPSTR) rmalloc (MAX_PATH);
	if (rstrlen (nameptr) < MAX_PATH)
	{
		rscopy (ofn.lpstrFile, nameptr);
	}
	else
	{
		rsncopy (ofn.lpstrFile, nameptr, MAX_PATH - 1);
		ofn.lpstrFile[MAX_PATH - 1] = '\0';
	}
	ofn.nMaxFile        = MAX_PATH;
	ofn.lpstrFileTitle  = NULL;
	ofn.nMaxFileTitle   = 0;
	ofn.lpstrInitialDir = NULL;
	ofn.lpstrTitle      = promptptr;
	ofn.Flags           = OFN_EXPLORER
//						| OFN_OVERWRITEPROMPT
						| OFN_HIDEREADONLY
						| OFN_ENABLEHOOK;			// PA: OFN_ENABLEHOOK added from Ronny
	ofn.lpstrDefExt     = NULL;
//	ofn.lCustData       = 0;
	if (rstrlen (okptr) == 0)
		okptr = NULL;	/* the calling clean function will
							   deallocate the memory allocated
							   for this empty string */
	ofn.lCustData       = (LPARAM) okptr;
	ofn.lpfnHook        = &FileSelectorHook;		// PA: &FileSelectorHook instead of NULL from Ronny
	ofn.lpTemplateName  = NULL;
#if (_WIN32_WINNT >= 0x0500)
	ofn.pvReserved		  = NULL;
	ofn.dwReserved		  = 0;
	ofn.FlagsEx			  = 0;
#endif

	success = GetSaveFileName (&ofn);

	if (success)
	{
		MakeReturn2Cci (pcci, success, (size_t) ofn.lpstrFile);
		/* and have the calling clean function deallocate the filename buffer */
	}
	else
	{
		MakeReturn2Cci (pcci, success, (size_t) NULL);
		rfree (ofn.lpstrFile);
	}
}

void EvalCcRqALTDIRECTORYDIALOG (CrossCallInfo *pcci)		/* no params;  bool, textptr result; */
{
	char buffer[MAX_PATH];
	LPITEMIDLIST pidlReturn;
	BROWSEINFO bi;
	char *s;
	LPARAM initialptr;
	char title[17] = "Select Directory\0";

	initialptr = (LPARAM) pcci->p1;

	bi.hwndOwner      = GetActiveWindow ();
	bi.pidlRoot       = NULL;
	bi.pszDisplayName = buffer;
	bi.lpszTitle      = title;
	bi.ulFlags        = BIF_RETURNONLYFSDIRS;	// DvA: on _WIN32_IE > 0x0500 add BIF_USENEWUI?
	bi.lpfn           = &DirectorySelectorHook;	// DvA NULL;
	bi.lParam         = initialptr;				// DvA 0;

	CoInitialize (NULL);		// Initialise the COM library; must be balanced by CoUninitialize()

	pidlReturn = SHBrowseForFolder (&bi);
	if (pidlReturn)
	{
		s = (char *) rmalloc (MAX_PATH+1);
		SHGetPathFromIDList (pidlReturn,s);
		CoTaskMemFree (pidlReturn);
		CoUninitialize ();		// Uninitialise the COM library

		MakeReturn2Cci (pcci, TRUE, (size_t)s);
		/* and have the calling Clean function deallocate the directory name buffer. */
	}
	else
	{
		CoUninitialize ();		// Uninitialise the COM library
		MakeReturn2Cci (pcci, FALSE, (size_t)NULL);
	}
}

void EvalCcRqSHELLDEFAULT (CrossCallInfo *pcci) /* parentPtr, controlPtr, textPtr; no result. */
{
	HWND hwndParent;				/* The handle to the window. */
	TOOLINFO ti;					/* The tool information that is sent to the tooltip control. */
	LPCTSTR  file,verb;
	HINSTANCE retn;

	rectTTId++;
	
	hwndParent  = NULL;//GetActiveWindow();//ghMainWindow;
	verb		= (LPCTSTR)pcci->p1;
	file        = (LPCTSTR)pcci->p2;
	
	retn = ShellExecute(hwndParent,verb,file,0,0,1);
	MakeReturn1Cci (pcci,(size_t)retn);
}

/*	Install the cross call procedures in the gCrossCallProcedureTable of cCrossCall_121.
*/

int InstallCrossCallMaarten (int ios)
{
	CrossCallProcedureTable newTable;

	InitialiseCrossCallMaarten ();

	newTable = EmptyCrossCallProcedureTable ();
//	AddCrossCallEntry (newTable, CcRqMDMADDCONTROLTIP,          EvalCcRqMDMADDCONTROLTIP);
//	AddCrossCallEntry (newTable, CcRqMDMDELCONTROLTIP,          EvalCcRqMDMDELCONTROLTIP);
//	AddCrossCallEntry (newTable, CcRqSETWINDOWFRAME,            EvalCcRqSETWINDOWFRAME);
//	AddCrossCallEntry (newTable, CcRqADDWINDOWHOOK,             EvalCcRqADDWINDOWHOOK);
	AddCrossCallEntry (newTable, CcRqSETWINDOWICON,             EvalCcRqSETWINDOWICON);
//	AddCrossCallEntry (newTable, CcRqGETBITMAPRESOURCE,			EvalCcRqGETBITMAPRESOURCE);
	AddCrossCallEntry (newTable, CcRqALTDIRECTORYDIALOG,        EvalCcRqALTDIRECTORYDIALOG);
	AddCrossCallEntry (newTable, CcRqALTFILEOPENDIALOG,			EvalCcRqALTFILEOPENDIALOG);
	AddCrossCallEntry (newTable, CcRqALTFILESAVEDIALOG,			EvalCcRqALTFILESAVEDIALOG);
	AddCrossCallEntry (newTable, CcRqSHELLDEFAULT, 		        EvalCcRqSHELLDEFAULT);
	AddCrossCallEntries (gCrossCallProcedureTable, newTable);

	return ios;
}

void InitialiseCrossCallMaarten()
{
	rectTTId = 0;
/*
	//	Before creating Clean controls, the tooltip control is created as the topmost child of this window.
	ghwndRT = CreateWindowEx (	WS_EX_TOPMOST,					// Apply the topmost style for this window
								TOOLTIPS_CLASS,					// Class name
								NULL,							// Title (NULL)
								WS_POPUP | TTS_ALWAYSTIP,		// Style *must* be WS_POPUP
								CW_USEDEFAULT,					// Default position (x,y)
								CW_USEDEFAULT,
								CW_USEDEFAULT,					// Default size (w,h)
								CW_USEDEFAULT,
								ghMainWindow,					// Parent is the ghMainWindow
								(HMENU) NULL,					// No menu
								(HANDLE) ghInst,				// The instance
								NULL							// No window creation data
							 );
	
	// DvA...
	SetWindowPos(ghwndRT,HWND_TOPMOST,0,0,0,0,SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
	SendMessage(ghwndRT,TTM_SETMAXTIPWIDTH,0,300);
	//...DvA
*/
}
