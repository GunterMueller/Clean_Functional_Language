definition module gtk_tree_view_column;

import gtk_types;

gtk_tree_view_column_new :: !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_tree_view_column_pack_start :: !GtkWidgetP !GtkWidgetP !Bool !GtkSt -> GtkSt;
gtk_tree_view_column_set_title :: !GtkWidgetP !{#Char} !GtkSt -> GtkSt;

