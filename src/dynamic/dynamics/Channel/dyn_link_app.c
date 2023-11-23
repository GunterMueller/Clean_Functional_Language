
extern char lib_name[];

/* the Clean linker requires symbol _start */
void start()
{
}

int clean_main (void)
{
	static char libInit_message[100];
	char *p,*s,*clean_string;

	(void) StartDynamicLinker();

	s="LibInit";
	p=&libInit_message[4];
	while (*s!='\0')
		*p++ = *s++;
	
	*p++='\n';

	s=lib_name;
	while (*s!='\0')
		*p++ = *s++;
	
	*p++='\n';
	*p++='\0';
	
	*(int*)libInit_message = (p-1)-&libInit_message[4];

	clean_string = (char*) DoReqS (libInit_message);
	
	if (!clean_string)
		return 1;

	(*(void(**)())(clean_string + 4)) ();

	return 0;
}
