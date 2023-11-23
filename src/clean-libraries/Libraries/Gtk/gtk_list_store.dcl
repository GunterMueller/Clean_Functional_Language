definition module gtk_list_store;

import gtk_types;

gtk_list_store_newv :: !{#Int} !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_list_store_append :: !GtkWidgetP !GtkTreeIter !GtkSt -> GtkSt;
gtk_list_store_set_value :: !GtkWidgetP !GtkTreeIter !Int !GValue !GtkSt -> GtkSt;
gtk_list_store_remove :: !GtkWidgetP !GtkTreeIter !GtkSt -> (!Bool,!GtkSt);

