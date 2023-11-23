
#include <stdio.h>

int main (int argc,char **argv)
{
	FILE *fs,*fd;
	char header[20];
	int f_nscns,f_nsyms,f_opthdr,f_symptr;
	int section_n,symbol_n,offset;
	
	if (argc!=3){
		printf ("usage: rename_Tn_sections source_object_file destination_object_file\n");
		return 1;
	}
	
	fs=fopen (argv[1],"rb");
	if (fs==NULL){
		printf ("opening file %s failed\n",argv[1]);
		return 1;
	}

	fd=fopen (argv[2],"wb");
	if (fd==NULL){
		printf ("creating file %s failed\n",argv[2]);
		return 1;
	}
	
	fread (header,1,20,fs);
	fwrite (header,1,20,fd);

	f_nscns = *(short *)&header[2];
	f_nsyms = *(int*)&header[12];
	f_opthdr = *(short*)&header[16];
	f_symptr = *(int*)&header[8];

	/*
	printf ("number of sections = %d\n",f_nscns);
	printf ("number of symbols = %d\n",f_nsyms);
	printf ("symbol table offset = %d\n",f_symptr);
	printf ("opthdr = %d\n",f_opthdr);
	*/

	for (section_n=0; section_n<f_nscns; ++section_n){
		char section_header[40];
		
		fread (section_header,1,40,fs);

/*		printf ("%s\n",section_header); */

		if (section_header[0]=='_' &&
			section_header[1]=='T' &&
			(unsigned)(section_header[2]-'0') < 10u &&
			(unsigned)(section_header[3]-'0') < 10u &&
			(unsigned)(section_header[4]-'0') < 10u &&
			section_header[5]=='\0')
		{
			section_header[0]='.';
			section_header[1]='t';
			section_header[2]='e';
			section_header[3]='x';
			section_header[4]='t';
		}

		fwrite (section_header,1,40,fd);
	}

	offset = 20 + 40*f_nscns;
	
	while (offset<f_symptr){
		int c;

		c=fgetc (fs);
		fputc (c,fd);
		++offset;
	}
//	fseek (fs,f_symptr,SEEK_SET);
	
	for (symbol_n=0; symbol_n<f_nsyms; ++symbol_n){
		char symbol[18];
		int n_numaux,n_scnum;
		
		fread (symbol,1,18,fs);

		n_numaux = *(unsigned char*)&symbol[17];
		n_scnum = *(short*)&symbol[12];

		if (symbol[16]==3 && n_numaux!=0 && n_scnum!=-1){
			if (*(int*)&symbol[0]!=0){
/*
				int n;

				for (n=0; n<8; ++n){
					if (symbol[n]=='\0')
						break;
					printf ("%c",symbol[n]);
				}
*/
				if (symbol[0]=='_' &&
					symbol[1]=='T' &&
					(unsigned)(symbol[2]-'0') < 10u &&
					(unsigned)(symbol[3]-'0') < 10u &&
					(unsigned)(symbol[4]-'0') < 10u &&
					symbol[5]=='\0')
				{
					symbol[0]='.';
					symbol[1]='t';
					symbol[2]='e';
					symbol[3]='x';
					symbol[4]='t';
				}

/*				printf ("\n"); */
			} else
/*				printf ("?\n")*/
				;
		}

		fwrite (symbol,1,18,fd);

		while (n_numaux>0){
			fread (symbol,1,18,fs);
			fwrite (symbol,1,18,fd);
			--n_numaux;
			++symbol_n;
		}
	}

	for (;;){
		int c;

		c=fgetc (fs);
		if (c==EOF)
			break;
		fputc (c,fd);
	}

	fclose (fs);
	fclose (fd);
	
	return 0;
}
