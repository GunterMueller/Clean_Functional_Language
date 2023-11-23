
#include <stdio.h>
#include <string.h>

FILE *file_seek (char *file,char *variable,char *mode)
{
	char name[17];
	FILE *a_out;
	int n,c;

	strcpy (name,"#$@          %*&");

	for (n=0; n<10 && variable[n]!='\0'; ++n)
		name[n+3]=variable[n];

	a_out=fopen (file,mode);
	if (a_out==NULL){
		fprintf (stderr,"can't open file %s\n",file);
		return NULL;
	}

	c=getc (a_out);
	while (c!=EOF){
		if (c=='#'){
			for (n=1; n<16; ++n){
				c=getc (a_out);
				if (c!=name[n])
					break;
			}

			if (n==16)
				break;
		} else
			c=getc (a_out);
	}

	if (c==EOF){
		fprintf (stderr,"Symbol %s not found\n",variable);		
		return NULL;
	}
	
	return a_out;
}

char *read_value (char *file,char *variable)
{
	FILE *a_out;
	static char buffer[1024];
	char *p;
	int c;
	
	a_out=file_seek (file,variable,"rb");
	if (a_out==NULL)
		return NULL;
	
	p=buffer;
	while ((c=getc (a_out))!=EOF && c!='\0')
		*p++=c;
	p='\0';
	
	if (fclose (a_out)!=0){
		fprintf (stderr,"Error reading file %s\n",file);
		return NULL;
	}
	
	return buffer;
}

int write_value (char *file,char *variable,char *value)
{
	FILE *a_out;
	int c;
	
	a_out=file_seek (file,variable,"r+b");
	if (a_out==NULL)
		return -1;

	fseek (a_out,0,SEEK_CUR);

	do {
		c=*value++;
		putc (c,a_out);
	} while (c!='\0');
	
	if (fclose (a_out)!=0){
		fprintf (stderr,"Error writing file %s\n",file);
		return -1;
	}
	
	return 0;
}

char *basename (char *path)
{
	char c,*p;
	
	p=path;
	while ((c=*path++)!='\0')
		if (c=='/')
			p=path;
	return p;
}

int main (int argc,char **argv)
{
	char *res;
	
	switch (argc){
		case 3:
			res=read_value (argv[1],argv[2]);
			if (res!=NULL)
				printf ("%s = %s\n",argv[2],res);
			break;
		case 4:
			if (write_value (argv[1],argv[2],argv[3]) == -1)
				return 1;
			break;
		default:
			fprintf (stderr,"Usage: %s <file> <variable> [<new-value>]\n",
					basename (argv[0]));
			return 1;
	}
	
	return 0;
}
