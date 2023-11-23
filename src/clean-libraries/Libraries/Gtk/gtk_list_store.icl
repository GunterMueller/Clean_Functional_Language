implementation module gtk_list_store;

import StdArray;
import gtk_types;

gtk_list_store_newv :: !{#Int} !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_list_store_newv types gs
	= gtk_list_store_newv_ (size types) types gs;

gtk_list_store_newv_ :: !Int !{#Int} !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_list_store_newv_ n_columns types gs = code {
	ccall gtk_list_store_newv "IA:p:p"
}

gtk_list_store_append :: !GtkWidgetP !GtkTreeIter !GtkSt -> GtkSt;
gtk_list_store_append list_store iter gs = code {
	ccall gtk_list_store_append "pA:V:p"
}

gtk_list_store_set_value :: !GtkWidgetP !GtkTreeIter !Int !GValue !GtkSt -> GtkSt;
gtk_list_store_set_value list_store iter column value gs = code {
	ccall gtk_list_store_set_value "pAIA:V:p"
}

gtk_list_store_remove :: !GtkWidgetP !GtkTreeIter !GtkSt -> (!Bool,!GtkSt);
gtk_list_store_remove list_store iter gs = code {
	ccall gtk_list_store_remove "pA:I:p"
}

