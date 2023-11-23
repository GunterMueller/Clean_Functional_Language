
#include <Traps.h>
#include <Memory.h>
#include <Files.h>
#include <Errors.h>
#include <Script.h>
#include <Resources.h>
#include <LowMem.h>

#define pb_RefNum (((HIOParam*)&pb)->ioRefNum)
#define pb_Permssn (((HIOParam*)&pb)->ioPermssn)
#define pb_Misc (((HIOParam*)&pb)->ioMisc)
#define pb_PosMode (((HIOParam*)&pb)->ioPosMode)
#define pb_PosOffset (((HIOParam*)&pb)->ioPosOffset)
#define pb_Buffer (((HIOParam*)&pb)->ioBuffer)
#define pb_NamePtr (((HIOParam*)&pb)->ioNamePtr)
#define pb_VRefNum (((HIOParam*)&pb)->ioVRefNum)
#define pb_DirID (((HFileParam*)&pb)->ioDirID)
#define pb_FDirIndex (((HFileParam*)&pb)->ioFDirIndex)
#define pb_FlFndrInfo (((HFileParam*)&pb)->ioFlFndrInfo)
#define pb_ReqCount (((HIOParam*)&pb)->ioReqCount)
#define pb_ActCount (((HIOParam*)&pb)->ioActCount)

struct heap_info {
	int *heap1_begin;
	int *heap1_end;
	int *heap2_begin;
	int *heap2_end;
	int *stack_begin;
	int *stack_end;
	int *text_begin;
	int *data_begin;
	int *small_integers;
	int *characters;
	int int_descriptor;
	int char_descriptor;
	int real_descriptor;
	int bool_descriptor;
	int string_descriptor;
	int array_descriptor;
};

static int heap_written_count=0;

#define MAX_N_HEAPS 10

void write_heap (struct heap_info *h)
{
	HParamBlockRec pb;
	OSErr error;
	Str32 application_name,heap_file_name;
	int application_name_length;

	if (heap_written_count>=MAX_N_HEAPS)
		return;

	{
		unsigned char *s;
		int n;
		
		s=LMGetCurApName();
		application_name_length=*s++;
		
		for (n=0; n<32; ++n){
			if (n>=application_name_length)
				application_name[n]='\0';
			else {
				application_name[n]=*s;
				if (*s!='\0')
					++s;
			}
		}
	}

	{
	char *end_heap_file_name_p;
	int n,heap_file_name_length;
	
	for (n=0; n<application_name_length; ++n)
		heap_file_name[1+n]=application_name[n];

	heap_file_name_length=application_name_length+14;
	if (heap_file_name_length>31)
		heap_file_name_length=31;
	heap_file_name[0]=heap_file_name_length;
	
	end_heap_file_name_p=(char*)&heap_file_name[1+heap_file_name_length];

	end_heap_file_name_p[-14]=' ';
	end_heap_file_name_p[-13]='H';
	end_heap_file_name_p[-12]='e';
	end_heap_file_name_p[-11]='a';
	end_heap_file_name_p[-10]='p';
	end_heap_file_name_p[-9]=' ';
	end_heap_file_name_p[-8]='P';
	end_heap_file_name_p[-7]='r';
	end_heap_file_name_p[-6]='o';
	end_heap_file_name_p[-5]='f';
	end_heap_file_name_p[-4]='i';
	end_heap_file_name_p[-3]='l';
	end_heap_file_name_p[-2]='e';
	end_heap_file_name_p[-1]='0'+heap_written_count++;
	}

	pb_NamePtr=heap_file_name;
	pb_VRefNum=0;
	pb_DirID=0;
		
	error=PBHCreateSync ((void*)&pb);
	if (error!=noErr && error!=-48/* dupFNErr*/){
		heap_written_count=MAX_N_HEAPS;
		return;
	}

	pb_VRefNum=0;
	pb_DirID=0;
	pb_FDirIndex=0;

	if (PBHGetFInfoSync ((void*)&pb)==noErr){
		pb_VRefNum=0;
		pb_DirID=0;
		pb_FlFndrInfo.fdCreator='PRHP';
		pb_FlFndrInfo.fdType='PRHP';
		PBHSetFInfoSync ((void*)&pb);
	}

	pb_NamePtr=heap_file_name;
	pb_VRefNum=0;
	pb_DirID=0;
	pb_Misc=(Ptr)0;
	pb_Permssn=fsWrPerm;
	
	error=PBHOpenSync ((void*)&pb);
	if (error!=noErr){
		heap_written_count=MAX_N_HEAPS;
		return;
	}

	pb_Buffer=(char*)application_name;
	pb_ReqCount=32;
	
	pb_PosMode=fsAtMark;
	pb_PosOffset=0;

	error=PBWriteSync ((ParmBlkPtr)&pb);
	if (error!=noErr){
		PBCloseSync ((ParmBlkPtr)&pb);
		heap_written_count=MAX_N_HEAPS;
		return;
	}

	pb_Buffer=(char*)h;
	pb_ReqCount=sizeof (struct heap_info);
	
	pb_PosMode=fsAtMark;
	pb_PosOffset=0;

	error=PBWriteSync ((ParmBlkPtr)&pb);
	if (error!=noErr){
		PBCloseSync ((ParmBlkPtr)&pb);
		heap_written_count=MAX_N_HEAPS;
		return;
	}

#if 0
	{
		int n;
		Handle h;
				
		n=0;
		do {
			h=Get1Resource ('CODE',n);

			if (h!=NULL)
				pb_Buffer=(char*)h;
			else
				pb_Buffer=(char*)&h;
			pb_ReqCount=sizeof (Ptr);

			pb_PosMode=fsAtMark;
			pb_PosOffset=0;
		
			error=PBWriteSync ((ParmBlkPtr)&pb);
			if (error!=noErr){
				PBCloseSync ((ParmBlkPtr)&pb);
				heap_written_count=MAX_N_HEAPS;
				return;
			}				
		
			++n;
		} while (h!=NULL);
	}
#endif

	pb_Buffer=(char*)h->stack_begin;
	pb_ReqCount=(int)(h->stack_end) - (int)(h->stack_begin);
	
	pb_PosMode=fsAtMark;
	pb_PosOffset=0;

	error=PBWriteSync ((ParmBlkPtr)&pb);
	if (error!=noErr){
		PBCloseSync ((ParmBlkPtr)&pb);
		heap_written_count=MAX_N_HEAPS;
		return;
	}

	pb_Buffer=(char*)h->heap1_begin;
	pb_ReqCount=(int)(h->heap1_end) - (int)(h->heap1_begin);
	
	pb_PosMode=fsAtMark;
	pb_PosOffset=0;

	error=PBWriteSync ((ParmBlkPtr)&pb);
	if (error!=noErr){
		PBCloseSync ((ParmBlkPtr)&pb);
		heap_written_count=MAX_N_HEAPS;
		return;
	}

	if (h->heap2_begin!=h->heap2_end){
		pb_Buffer=(char*)h->heap2_begin;
		pb_ReqCount=(int)(h->heap2_end) - (int)(h->heap2_begin);
		
		pb_PosMode=fsAtMark;
		pb_PosOffset=0;
	
		error=PBWriteSync ((ParmBlkPtr)&pb);
		if (error!=noErr){
			PBCloseSync ((ParmBlkPtr)&pb);
			heap_written_count=MAX_N_HEAPS;
			return;
		}
	}

	PBCloseSync ((ParmBlkPtr)&pb);
}
