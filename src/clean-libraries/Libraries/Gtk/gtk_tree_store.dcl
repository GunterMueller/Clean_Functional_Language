definition module gtk_tree_store;

import gtk_types;

gtk_tree_store_newv :: !{#Int} !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_tree_store_append :: !GtkWidgetP !GtkTreeIter !GtkTreeIter !GtkSt -> GtkSt;
gtk_tree_store_append0 :: !GtkWidgetP !GtkTreeIter !Int !GtkSt -> GtkSt;
gtk_tree_store_set_value :: !GtkWidgetP !GtkTreeIter !Int !GValue !GtkSt -> GtkSt;

