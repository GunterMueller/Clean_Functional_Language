# undef DEBUG

typedef struct clean_string
{
	int	length;
#ifdef SOLARIS
	char	characters[4];
#else
	char	characters[0];
#endif
} *CLEAN_STRING;

typedef struct clean_file
{
	int	number;
	int	position;
} CLEAN_FILE;

struct file {
	FILE		*file;
	unsigned long	position;
	unsigned long	file_length;
	char		*file_name;
	long		file_number;
	int		device_number;
	short		mode;
	short		filler_1;
	long		filler_2;
};

#define	CLOSED_FILE	0
#define READ_FILE	1
#define WRITE_FILE	2

extern struct file file_table[];
