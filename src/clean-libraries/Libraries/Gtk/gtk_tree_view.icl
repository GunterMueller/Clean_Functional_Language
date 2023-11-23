implementation module gtk_tree_view;

import gtk_types;

gtk_tree_view_new :: !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_tree_view_new gs = code {
	ccall gtk_tree_view_new ":p:p"
}

gtk_tree_view_set_model :: !GtkWidgetP !GtkWidgetP !GtkSt -> GtkSt;
gtk_tree_view_set_model tree_view model gs = code {
	ccall gtk_tree_view_set_model "pp:V:p"
}

gtk_tree_view_get_model :: !GtkWidgetP !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_tree_view_get_model tree_view gs = code {
	ccall gtk_tree_view_get_model "p:p:p"
}

gtk_tree_view_append_column :: !GtkWidgetP !GtkWidgetP !GtkSt -> GtkSt;
gtk_tree_view_append_column tree_view column gs = code {
	ccall gtk_tree_view_append_column "pp:V:p"
}

gtk_tree_view_column_add_attribute :: !GtkWidgetP !GtkWidgetP !{#Char} !Int !GtkSt -> GtkSt;
gtk_tree_view_column_add_attribute tree_column cell_renderer attribute column gs = code {
	ccall gtk_tree_view_column_add_attribute "ppsI:V:p"
}

gtk_tree_view_set_reorderable :: !GtkWidgetP !Bool !GtkSt -> GtkSt;
gtk_tree_view_set_reorderable tree_view reorderable gs = code {
	ccall gtk_tree_view_set_reorderable "pI:V:p"
}

gtk_tree_view_set_headers_visible :: !GtkWidgetP !Bool !GtkSt -> GtkSt;
gtk_tree_view_set_headers_visible tree_view headers_visible gs = code {
	ccall gtk_tree_view_set_headers_visible "pI:V:p"
}

gtk_tree_view_get_selection :: !GtkWidgetP !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_tree_view_get_selection tree_view gs = code {
	ccall gtk_tree_view_get_selection "p:p:p"
}

