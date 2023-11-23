definition module gtk_tree_model;

import gtk_types;

gtk_tree_model_get_value :: !GtkWidgetP !GtkTreeIter !Int !GValue !GtkSt -> GtkSt;
gtk_tree_model_iter_n_children :: !GtkWidgetP !GtkTreeIter !GtkSt -> (!Int,!GtkSt);
gtk_tree_model_iter_parent :: !GtkWidgetP !GtkTreeIter !GtkTreeIter !GtkSt -> (!Bool,!GtkSt);
gtk_tree_model_get_iter_first :: !GtkWidgetP !GtkTreeIter !GtkSt -> (!Bool,!GtkSt);
gtk_tree_model_iter_next :: !GtkWidgetP !GtkTreeIter !GtkSt -> (!Bool,!GtkSt);

