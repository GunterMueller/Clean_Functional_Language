implementation module gtk_tree_selection;

import gtk_types;

gtk_tree_selection_get_selected_i :: !GtkWidgetP !Int !GtkTreeIter !GtkSt -> (!Bool,!GtkSt);
gtk_tree_selection_get_selected_i selection model iter gs = code {
	ccall gtk_tree_selection_get_selected "ppA:I:p"
}
