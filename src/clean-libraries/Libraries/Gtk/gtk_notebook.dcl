definition module gtk_notebook;

import gtk_types;

gtk_notebook_new :: !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_notebook_append_page :: !GtkWidgetP !GtkWidgetP !GtkWidgetP !GtkSt -> (!Int,!GtkSt);

