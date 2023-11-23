
#include <stdio.h>

int main (void)
{
	FILE *f,*o;
	int c,offset;
	
	f=fopen ("areals.s","r");
	o=fopen ("areals_offsets.s","w");

	for (;;){
		c=getc (f);
		if (c!='\t')
			goto next_line_1;
		c=getc (f);
		if (c!='#')
			goto next_line_1;
		c=getc (f);
		if (c!='o')
			goto next_line_1;
		c=getc (f);
		if (c!='f')
			goto next_line_1;
		c=getc (f);
		if (c!='f')
			goto next_line_1;
		c=getc (f);
		if (c!='s')
			goto next_line_1;
		c=getc (f);
		if (c!='e')
			goto next_line_1;
		c=getc (f);
		if (c!='t')
			goto next_line_1;
		c=getc (f);
		if (c!='s')
			goto next_line_1;
			
		c=getc (f);
		while (c!='\n')
			c=getc (f);			
		break;
		
		next_line_1:
		while (c!='\n')
			c=getc (f);			
	}

	printf ("found #offsets\n");

	offset=0;

	for (;;){
		if (c=='\n' || c=='\r'){
			c=getc (f);
			continue;
		}
		if (c=='#')
			goto next_line;
		if ((c>='a' && c<='z') || (c>='A' && c<='Z') || (c>='0' && c<='9') || c=='_'){
			do {
				fprintf (o,"%c",c);
				c=getc (f);
			} while ((c>='a' && c<='z') || (c>='A' && c<='Z') || (c>='0' && c<='9') || c=='_');
			fprintf (o,"_offset = %d\n",offset);
			if (c==':')
				goto next_line;
			printf (": expected, not %c\n",c);
			return 0;							
		}
		if (c==EOF)
			break;
		if (!(c==' ' || c=='\t')){
			printf ("line should start with a tab, space or #, not %c\n",c);
			return 0;
		}
		
		c=getc (f);
		if (c!='.'){
			printf (". expected, not %c\n",c);
			return 0;							
		}

		c=getc (f);
		if (c=='d'){
			c=getc (f);
			if (c!='o'){
				printf ("o. expected, not %c\n",c);
				return 0;			
			}
			c=getc (f);
			if (c!='u'){
				printf ("u. expected, not %c\n",c);
				return 0;			
			}
			c=getc (f);
			if (c!='b'){
				printf ("b. expected, not %c\n",c);
				return 0;			
			}
			c=getc (f);
			if (c!='l'){
				printf ("l. expected, not %c\n",c);
				return 0;			
			}
			c=getc (f);
			if (c!='e'){
				printf ("e. expected, not %c\n",c);
				return 0;			
			}

			if (offset & 7){
				printf (".double not 8 byte aligned\n");
				return 0; 
			}
			offset+=8;
			
			c=getc (f);
			goto next_line;
		}
		if (c=='q'){
			c=getc (f);
			if (c!='u'){
				printf ("u. expected, not %c\n",c);
				return 0;			
			}
			c=getc (f);
			if (c!='a'){
				printf ("a. expected, not %c\n",c);
				return 0;			
			}
			c=getc (f);
			if (c!='d'){
				printf ("d. expected, not %c\n",c);
				return 0;			
			}
			offset+=4;

			c=getc (f);
			goto next_line;
		}

		printf (".double or .quad expected, not .%c\n",c);
		return 0;			

		next_line:
		while (c!='\n' && c!='\r' && c!=EOF)
			c=getc (f);
		if (c==EOF)
			break;
	}

	fclose (o);
	fclose (f);

	printf ("all offsets written\n");
	
	return 1;
}
