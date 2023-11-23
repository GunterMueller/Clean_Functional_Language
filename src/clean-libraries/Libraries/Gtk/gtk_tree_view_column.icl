implementation module gtk_tree_view_column;

import gtk_types;

gtk_tree_view_column_new :: !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_tree_view_column_new gs = code {
	ccall gtk_tree_view_column_new ":p:p"
}

gtk_tree_view_column_pack_start :: !GtkWidgetP !GtkWidgetP !Bool !GtkSt -> GtkSt;
gtk_tree_view_column_pack_start tree_column cell expand gs = code {
	ccall gtk_tree_view_column_pack_start "ppI:V:p"
}

gtk_tree_view_column_set_title :: !GtkWidgetP !{#Char} !GtkSt -> GtkSt;
gtk_tree_view_column_set_title tree_column title gs = code {
	ccall gtk_tree_view_column_set_title "ps:V:p"
}

