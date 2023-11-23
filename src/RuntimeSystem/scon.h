extern int w_get_char();
#ifdef A64
extern int w_get_int (long *i_p);
#else
extern int w_get_int (int *i_p);
#endif
extern int w_get_real (double *r_p);
extern unsigned long w_get_text (char *string,unsigned long max_length);
extern void w_print_char (char c);
#ifdef A64
extern void w_print_int (long i);
#else
extern void w_print_int (int i);
#endif
extern void w_print_real (double r);
extern void w_print_string (char *s);
extern void w_print_text (char *s,unsigned long length);
extern void ew_print_char (char c);
#ifdef A64
extern void ew_print_int (long i);
#else
extern void ew_print_int (int i);
#endif
extern void ew_print_real (double r);
extern void ew_print_string (char *s);
extern void ew_print_text (char *s,unsigned long length);
