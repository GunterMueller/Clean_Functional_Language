
struct toc_label {
	int					toc_t_label_number;
	struct label *		toc_label_label;
	int					toc_label_offset;
	struct toc_label *	toc_label_next;
	struct toc_label *	toc_next;
};

extern struct toc_label *toc_labels,**last_toc_next_p;

extern int make_toc_label (struct label *label,int offset);
extern struct toc_label *new_toc_label (struct label *label,int offset);
extern void initialize_toc (void);

extern int t_label_number;

struct ms {	int m; int s; };

extern struct ms magic (int d);

