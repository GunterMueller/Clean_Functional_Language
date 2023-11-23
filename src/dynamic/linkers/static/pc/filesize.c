
#include <windows.h>

void FileSize (size_t clean_s[],size_t *b_p,size_t *size_p)
{
	unsigned char s[256],*s_p,*clean_s_p;
	size_t i,clean_s_size;
	WIN32_FIND_DATA find_data;
	HANDLE h;

	clean_s_size=clean_s[0];
	clean_s_p=(unsigned char*)&clean_s[1];
	if (clean_s_size<256){
		s_p=s;
	} else {
		s_p=LocalAlloc (LMEM_FIXED,clean_s_size+1);
		if (s_p==NULL){
			*b_p=0;
			*size_p=0;
			return;
		}
	}
	
	for (i=0; i<clean_s_size; ++i)
		s_p[i]=clean_s_p[i];
	s_p[clean_s_size]='\0';
	
	h=FindFirstFile (s_p,&find_data);
	if (h==INVALID_HANDLE_VALUE || h==NULL){
		*b_p=0;
		*size_p=0;
	} else {
		*b_p=1;
#ifdef _WIN64
		*size_p=find_data.nFileSizeLow + (MAXDWORD+1) * find_data.nFileSizeHigh;
#else
		*size_p=find_data.nFileSizeLow;
#endif
		FindClose (h);
	}
	
	if (s_p!=s)
		LocalFree (s_p);
}