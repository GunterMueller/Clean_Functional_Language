implementation module gtk_misc;

import gtk_types;

gtk_misc_set_alignment :: !GtkWidgetP !Real !Real !GtkSt -> GtkSt;
gtk_misc_set_alignment misc xalign yalign gs = code {
	ccall gtk_misc_set_alignment "prr:V:p"
}

