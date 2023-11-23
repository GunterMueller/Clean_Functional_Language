
#ifdef A64
typedef __int64 CLEAN_INT;
typedef unsigned __int64 UNSIGNED_CLEAN_INT;
typedef unsigned __int64 FilePositionT;
#else
typedef long CLEAN_INT;
typedef unsigned long UNSIGNED_CLEAN_INT;
typedef unsigned long FilePositionT;
#endif

struct file {
	unsigned char *	file_read_p;			/* offset 0 */
	unsigned char *	file_write_p;			/* offset 4 */
	unsigned char *	file_end_read_buffer_p;	/* offset 8 */
	unsigned char *	file_end_write_buffer_p;/* offset 12 */
	short			file_mode;				/* offset 16 */
	char			file_unique;			/* offset 18 */
	char			file_error;				/* offset 19 */

	unsigned char *	file_read_buffer_p;
	unsigned char *	file_write_buffer_p;

	FilePositionT	file_offset;
	FilePositionT	file_length;

	char *			file_name;
	FilePositionT	file_position;
	FilePositionT	file_position_2;

	HFILE			file_read_refnum;
	HFILE			file_write_refnum;
	CLEAN_INT		file_fill_offset_56,	/* fill to 64 bytes */
					file_fill_offset_60;
};

extern struct file file_table[];

#define CLEAN_TRUE 1
#define CLEAN_BOOL int

extern int file_read_char (struct file *f);
extern CLEAN_BOOL file_read_int (struct file *f,CLEAN_INT *i_p);
extern CLEAN_BOOL file_read_real (struct file *f,double *r_p);
extern UNSIGNED_CLEAN_INT file_read_characters (struct file *f,UNSIGNED_CLEAN_INT *length_p,char *s);
extern void file_write_char (int c,struct file *f);

extern void file_write_char (int c,struct file *f);
extern void file_write_characters (unsigned char *p,UNSIGNED_CLEAN_INT length,struct file *f);
extern void file_write_int (CLEAN_INT i,struct file *f);
extern void file_write_real (double r,struct file *f);
extern CLEAN_BOOL flush_file_buffer (struct file *f);
