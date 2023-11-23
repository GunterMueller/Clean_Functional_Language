implementation module gtk_box;

import gtk_types;

gtk_box_pack_start :: !GtkWidgetP !GtkWidgetP !Int !Int !Int !GtkSt -> GtkSt;
gtk_box_pack_start box child expand fill padding gs = code {
	ccall gtk_box_pack_start "ppIII:V:p"
}

gtk_box_pack_end :: !GtkWidgetP !GtkWidgetP !Int !Int !Int !GtkSt -> GtkSt;
gtk_box_pack_end box child expand fill padding gs = code {
	ccall gtk_box_pack_end "ppIII:V:p"
}

