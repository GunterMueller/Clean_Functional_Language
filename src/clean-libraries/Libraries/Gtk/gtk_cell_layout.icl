implementation module gtk_cell_layout;

import gtk_types;

gtk_cell_layout_pack_start :: !GtkWidgetP !GtkWidgetP !Bool !GtkSt -> GtkSt;
gtk_cell_layout_pack_start cell_layout cell expand gs = code {
	ccall gtk_cell_layout_pack_start "ppI:V:p"
}


