
#include <stdlib.h>

#include "cgport.h"

#ifdef G_POWER

#include "cgrconst.h"
#include "cgtypes.h"
#include "cg.h"
#include "cgptoc.h"

int t_label_number;

struct toc_label *toc_labels,**last_toc_next_p;

struct toc_label *new_toc_label (struct label *label,int offset)
{
	struct toc_label *new_toc_label,**toc_label_p;
	int label_number;

	toc_label_p=&label->label_toc_labels;

	if (label->label_flags & HAS_TOC_LABELS){
		struct toc_label *toc_label;
		
		while (toc_label=*toc_label_p,toc_label!=NULL){
			if (toc_label->toc_label_offset==offset)
				return toc_label;
			
			toc_label_p=&toc_label->toc_label_next;
		}
	} else
		label->label_flags |= HAS_TOC_LABELS;
		
	new_toc_label=(struct toc_label*)allocate_memory_from_heap (sizeof (struct toc_label));
	
	label_number=t_label_number++;

	new_toc_label->toc_t_label_number=label_number;
	new_toc_label->toc_label_label=label;
	new_toc_label->toc_label_offset=offset;
	
	*toc_label_p=new_toc_label;
	new_toc_label->toc_label_next=NULL;
	
	*last_toc_next_p=new_toc_label;
	last_toc_next_p=&new_toc_label->toc_next;

	return new_toc_label;
}

int make_toc_label (struct label *label,int offset)
{
	return new_toc_label (label,offset)->toc_t_label_number;
}

void initialize_toc (void)
{
	t_label_number=0;
	last_toc_next_p=&toc_labels;
	toc_labels=NULL;
}

#endif
