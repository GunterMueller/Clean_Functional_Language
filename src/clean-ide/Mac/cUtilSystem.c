#ifndef __MACH__
# include <Carbon.h>
#else
# include <Carbon/Carbon.h>
# include <fcntl.h>
#endif

CFBundleRef systemBundle=NULL;

#ifndef __MACH__
typedef int pid_t;
typedef int mode_t;

#define        O_WRONLY        0x0001
#define        O_CREAT         0x0200
#define        O_TRUNC         0x0400

pid_t (*fork_p)(void) = NULL;
int (*execv_p)(const char *path,char *const argv[])=NULL;
pid_t (*waitpid_p)(pid_t wpid,int *status,int options)=NULL;
int (*open_p)(const char *path,int flags,mode_t mode)=NULL;
int (*dup2_p) (int oldd,int newd)=NULL;
int (*close_p) (int d)=NULL;
#endif

#ifndef __MACH__
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
#endif

#ifdef __MWERKS__

int get_toc (void)
{
	asm {
		mr	r3,RTOC
	}
}

int set_toc (int toc)
{
	asm {
		mr	RTOC,r3
	}
}

void __ptr_glue (void)
{
	asm {
		lwz		r0,0(r12)
		stw		RTOC,20(SP)
		mtctr	r0
		lwz		RTOC,4(r12)
		bctr
	}
}
#else

#define get_toc() 0;
#define set_toc(a) ;

#endif

#ifndef __MACH__
pid_t fork (void)
{
	int r,t;
	
	if (fork_p==NULL){
		if (systemBundle==NULL)
			initSystemBundle ();
		fork_p = (int(*)(void)) CFBundleGetFunctionPointerForName (systemBundle,CFSTR ("fork"));
	    if (fork_p==NULL)
			return -1;
	}

	t=get_toc();
	r= (*fork_p)();
	set_toc (t);
	
	return r;
}

int execv (const char *path,char *const argv[])
{
	int r,t;
	
	if (execv_p==NULL){
		if (systemBundle==NULL)
			initSystemBundle ();
		execv_p = (int (*)(const char *path,char *const argv[])) CFBundleGetFunctionPointerForName (systemBundle,CFSTR ("execv"));
	    if (execv_p==NULL)
			return -1;	
	}

	t=get_toc();
	r=(*execv_p) (path,argv);
	set_toc (t);

	return r;
}

pid_t waitpid (pid_t wpid,int *status,int options)
{
	int r,t;

	if (waitpid_p==NULL){
		if (systemBundle==NULL)
			initSystemBundle ();
		waitpid_p = (pid_t (*)(pid_t wpid,int *status,int options)) CFBundleGetFunctionPointerForName (systemBundle,CFSTR ("waitpid"));
	    if (waitpid_p==NULL)
			return -1;
	}

	t=get_toc();
	r=(*waitpid_p) (wpid,status,options);
	set_toc (t);
	
	return r;
}

int open (const char *path,int flags,mode_t mode)
{
	int r,t;

	if (open_p==NULL){
		if (systemBundle==NULL)
			initSystemBundle ();
		open_p = (int (*)(const char *path,int flags,mode_t mode)) CFBundleGetFunctionPointerForName (systemBundle,CFSTR ("open"));
	    if (open_p==NULL)
			return -1;
	}

	t=get_toc();
	r=(*open_p) (path,flags,mode);
	set_toc (t);
	
	return r;
}

int dup2 (int oldd,int newd)
{
	int r,t;

	if (dup2_p==NULL){
		if (systemBundle==NULL)
			initSystemBundle ();
		dup2_p = (int (*)(int oldd,int newd)) CFBundleGetFunctionPointerForName (systemBundle,CFSTR ("dup2"));
	    if (dup2_p==NULL)
			return -1;
	}

	t=get_toc();
	r=(*dup2_p) (oldd,newd);
	set_toc (t);
	
	return r;
}

int close (int d)
{
	int r,t;

	if (close_p==NULL){
		if (systemBundle==NULL)
			initSystemBundle ();
		close_p = (int (*)(int d)) CFBundleGetFunctionPointerForName (systemBundle,CFSTR ("close"));
	    if (close_p==NULL)
			return -1;
	}

	t=get_toc();
	r=(*close_p) (d);
	set_toc (t);
	
	return r;
}
#endif

static int parse_arguments (char *command,char **argv)
{
	char *p;
	int argc;
		
	argc=0;
	p=command;

	while (*p==' ' || *p=='\t')
		++p;

	while (*p!='\0' && argc<2048){
		if (*p=='\''){
			char c,*d_p;
			
			++p;
			argv[argc]=p;

			d_p=p;
			
			c=*p;
			while (!(c=='\'' && p[1]!='\'') && c!='\0'){
				*d_p++=c;
				if (c=='\'')
					++p;
				c=*++p;
			}
			
			if (*p=='\0'){
				*d_p='\0';
				break;
			}
			
			++argc;
			*d_p='\0';
			++p;
		} else {
			argv[argc++]=p;
			while (*p!=' ' && *p!='\t' && *p!='\0')
				++p;
	
			if (*p!='\0')
				*p++='\0';
		}
				
		while (*p==' ' || *p=='\t')
			++p;			
	}
	argv[argc]=NULL;
	
	return argc;
}

int fork_execv_waitpid (char *command,char *stderr_file_name,int *status_p)
{
	char *(argv[2049]);
	int argc,result;

#ifndef __MACH__
	if (!initSystemBundle())
		return -1;
#endif

	result=0;
		
	argc=parse_arguments (command,argv);

	if (argc>0){
		int pid;
		
		pid=fork();
		if (pid==0){
			if (stderr_file_name!=NULL && *stderr_file_name!='\0'){
				int fd;
				
				fd=open (stderr_file_name,O_CREAT | O_TRUNC | O_WRONLY,0777);
				if (fd!=-1){
					dup2 (fd,1);
					close (fd);
				}
			}

			result=execv (argv[0],argv);
		} else if (pid!=-1)
			result=waitpid (pid,status_p,0);
	} else
		result=-1;

	return result;
}

int fork_execv (char *p_command)
{
	char *(argv[2049]);
	int argc,result;
	char *command;

#ifndef __MACH__
	if (!initSystemBundle())
		return -1;
#endif

	{
	char *p,*d_p;

	for (p=p_command; *p!='\0'; ++p)
		;
	
	command=NewPtr (p+1-p_command);
	
	d_p=command;
	for (p=p_command; *p!='\0'; ++p)
		*d_p++=*p;
	*d_p='\0';
	}

	result=0;

	argc=parse_arguments (command,argv);
		
	if (argc>0){
		int pid;
		
		pid=fork();
		if (pid==0)
			result=execv (argv[0],argv);
		else if (pid!=-1)
			result=0;
		else
			result=1;
	}

	DisposePtr (command);

	return result;
}

int fork_execv_pid (char *p_command,int *pid_p)
{
	char *(argv[2049]);
	int argc,result;
	char *command;

#ifndef __MACH__
	if (!initSystemBundle())
		return -1;
#endif

	{
	char *p,*d_p;

	for (p=p_command; *p!='\0'; ++p)
		;
	
	command=NewPtr (p+1-p_command);
	
	d_p=command;
	for (p=p_command; *p!='\0'; ++p)
		*d_p++=*p;
	*d_p='\0';
	}

	result=0;

	argc=parse_arguments (command,argv);
		
	if (argc>0){
		int pid;
		
		pid=fork();
		
		*pid_p=pid;
		
		if (pid==0)
			result=execv (argv[0],argv);
		else if (pid!=-1)
			result=0;
		else
			result=1;
	} else
		*pid_p=0;

	DisposePtr (command);

	return result;
}

Boolean hfs2posix(char *hfsPath,char *buffer,int size)
{
	CFURLRef	hfs_url;
	CFStringRef	hfs_string, posix_string;
	Boolean		ok;
	
	hfs_string		= CFStringCreateWithCString(NULL/*kCFAllocatorDefault*/, hfsPath, kCFStringEncodingMacRoman);
	hfs_url			= CFURLCreateWithFileSystemPath(NULL/*kCFAllocatorDefault*/,hfs_string,kCFURLHFSPathStyle,/*isDirectory*/false);
	posix_string	= CFURLCopyFileSystemPath(hfs_url, kCFURLPOSIXPathStyle);
	ok				= CFStringGetCString(posix_string, buffer, size, kCFStringEncodingMacRoman);
	
	CFRelease(posix_string);
	CFRelease(hfs_url);
	CFRelease(hfs_string);

	return ok;
}


OSErr LaunchTheDocument(FSSpec *document, OSType appCreator, FSSpec *appSpec) {
    OSErr err, sresult;
    AEAddressDesc appAddr;
    AEDescList fileList;
    AEDesc fileListElt, paraDesc;
    AppleEvent theEvent;
    AppleEvent eventReply;
    AliasHandle docAlias;
    FInfo fndrInfo;
    LaunchParamBlockRec launchPB;
    Size paraSize;
    AppParametersPtr paraData;

        /* initialize our records to NULL
        descriptors */
    AECreateDesc(typeNull, NULL, 0, &appAddr);
    AECreateDesc(typeNull, NULL, 0, &fileList);
    AECreateDesc(typeNull, NULL, 0, &fileListElt);
    AECreateDesc(typeNull, NULL, 0, &theEvent);
    AECreateDesc(typeNull, NULL, 0, &eventReply);
    AECreateDesc(typeNull, NULL, 0, &paraDesc);
    docAlias = NULL;
    paraData = NULL;

        /* create an open documents Apple Event */
    err = AECreateDesc(typeApplSignature,
          (Ptr)&appCreator, sizeof(OSType), &appAddr);
    if (err != noErr) goto bail;
    err = AECreateAppleEvent(kCoreEventClass, kAEOpenDocuments,
          &appAddr, kAutoGenerateReturnID, kAnyTransactionID,
          &theEvent);
    if (err != noErr) goto bail;

        /* create a one element list of files to send in the
        event */
    err = AECreateList(NULL, 0, false, &fileList);
    if (err != noErr) goto bail;
    err = NewAlias(NULL, document, &docAlias);
    if (err != noErr) goto bail;
    HLock((Handle) docAlias);
    err = AECreateDesc(typeAlias, (Ptr) (*docAlias),
          GetHandleSize((Handle) docAlias), &fileListElt);
    HUnlock((Handle) docAlias);
    if (err != noErr) goto bail;
    err = AEPutDesc(&fileList, 0, &fileListElt);
    if (err != noErr) goto bail;

        /* add the file list to the open documents event */
    err = AEPutParamDesc(&theEvent, keyDirectObject, &fileList);
    if (err != noErr) goto bail;

        /* send the Apple Event */
    err = AESend(&theEvent, &eventReply, kAENoReply,
          kAENormalPriority, kNoTimeOut, NULL, NULL);

        /* if the target could not be found...
        no such app running? */
    if (err == connectionInvalid || err == procNotFound) {

            /* ask the Apple Event Manager to coerce the Apple
            event into a launch application parameter block
            record. */
        err = AECoerceDesc(&theEvent, typeAppParameters,
              &paraDesc);
        if (err != noErr) goto bail;

            /* copy the record's data into our own memory
            location so it can be incorporated into the
            LaunchApplication parameter block.  Here, the new
            location is referenced using the variable paraData. */
#if TARGET_API_MAC_CARBON
        paraSize = AEGetDescDataSize(&paraDesc);
        paraData = (AppParametersPtr) NewPtr(paraSize);
        if (paraData == NULL) { err = memFullErr; goto bail; }
        err = AEGetDescData(&paraDesc, paraData, paraSize );
        if (err != noErr) goto bail;
#else
        paraSize = GetHandleSize((Handle) paraDesc.dataHandle);
        paraData = (AppParametersPtr) NewPtr(paraSize);
        if (paraData == NULL) { err = memFullErr; goto bail; }
        BlockMoveData(*paraDesc.dataHandle, paraData, paraSize);
#endif

            /* launch the application */
        launchPB.launchBlockID = extendedBlock;
        launchPB.launchEPBLength = extendedBlockLen;
        launchPB.launchFileFlags = 0;
        launchPB.launchControlFlags =
            launchContinue + launchNoFileFlags;
        launchPB.launchAppSpec = appSpec;
        launchPB.launchAppParameters = paraData;
        err = LaunchApplication(&launchPB);
    }
bail:
        /* clean up, and go.. */
    if (docAlias != NULL) DisposeHandle((Handle) docAlias);
    if (paraData != NULL) DisposePtr((Ptr) paraData);
    AEDisposeDesc(&paraDesc);
    AEDisposeDesc(&appAddr);
    AEDisposeDesc(&fileListElt);
    AEDisposeDesc(&fileList);
    AEDisposeDesc(&theEvent);
    AEDisposeDesc(&eventReply);
    return err;
}
