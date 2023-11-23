implementation module gtk_tree_model;

import gtk_types;

gtk_tree_model_get_value :: !GtkWidgetP !GtkTreeIter !Int !GValue !GtkSt -> GtkSt;
gtk_tree_model_get_value tree_model iter column value gs = code {
	ccall gtk_tree_model_get_value "pAIA:V:p"
}

gtk_tree_model_iter_n_children :: !GtkWidgetP !GtkTreeIter !GtkSt -> (!Int,!GtkSt);
gtk_tree_model_iter_n_children tree_model iter gs = code {
	ccall gtk_tree_model_iter_n_children "pA:I:p"
}

gtk_tree_model_iter_parent :: !GtkWidgetP !GtkTreeIter !GtkTreeIter !GtkSt -> (!Bool,!GtkSt);
gtk_tree_model_iter_parent tree_model iter child gs = code {
	ccall gtk_tree_model_iter_parent "pAA:I:p"
}

gtk_tree_model_get_iter_first :: !GtkWidgetP !GtkTreeIter !GtkSt -> (!Bool,!GtkSt);
gtk_tree_model_get_iter_first tree_model iter gs = code {
	ccall gtk_tree_model_get_iter_first "pA:I:p"
}

gtk_tree_model_iter_next :: !GtkWidgetP !GtkTreeIter !GtkSt -> (!Bool,!GtkSt);
gtk_tree_model_iter_next tree_model iter gs = code {
	ccall gtk_tree_model_iter_next "pA:I:p"
}

