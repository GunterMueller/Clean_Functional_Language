implementation module gtk_container;

import gtk_types;

gtk_container_add :: !GtkWidgetP !GtkWidgetP !GtkSt -> GtkSt;
gtk_container_add container widget gs = code {
	ccall gtk_container_add "pp:V:p"
}

gtk_container_set_border_width :: !GtkWidgetP !Int !GtkSt -> GtkSt;
gtk_container_set_border_width container border_width gs = code {
	ccall gtk_container_set_border_width "pI:V:p"
}

