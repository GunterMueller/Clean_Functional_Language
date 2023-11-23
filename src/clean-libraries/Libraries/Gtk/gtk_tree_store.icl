implementation module gtk_tree_store;

import StdArray;
import gtk_types;

gtk_tree_store_newv :: !{#Int} !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_tree_store_newv types gs
	= gtk_tree_store_newv_ (size types) types gs;

gtk_tree_store_newv_ :: !Int !{#Int} !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_tree_store_newv_ n_columns types gs = code {
	ccall gtk_tree_store_newv "IA:p:p"
}

gtk_tree_store_append :: !GtkWidgetP !GtkTreeIter !GtkTreeIter !GtkSt -> GtkSt;
gtk_tree_store_append tree_store iter parent gs = code {
	ccall gtk_tree_store_append "pAA:V:p"
}

gtk_tree_store_append0 :: !GtkWidgetP !GtkTreeIter !Int !GtkSt -> GtkSt;
gtk_tree_store_append0 tree_store iter parent gs = code {
	ccall gtk_tree_store_append "pAp:V:p"
}

gtk_tree_store_set_value :: !GtkWidgetP !GtkTreeIter !Int !GValue !GtkSt -> GtkSt;
gtk_tree_store_set_value tree_store iter column value gs = code {
	ccall gtk_tree_store_set_value "pAIA:V:p"
}

