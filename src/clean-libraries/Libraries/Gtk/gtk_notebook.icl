implementation module gtk_notebook;

import gtk_types;

gtk_notebook_new :: !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_notebook_new gs = code {
	ccall gtk_notebook_new ":p:p"
}

gtk_notebook_append_page :: !GtkWidgetP !GtkWidgetP !GtkWidgetP !GtkSt -> (!Int,!GtkSt);
gtk_notebook_append_page notebook child tab_label gs = code {
	ccall gtk_notebook_append_page "ppp:I:p"
}

