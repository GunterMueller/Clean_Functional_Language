implementation module gtk_drawing_area;

import gtk_types;

gtk_drawing_area_new :: !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_drawing_area_new gs = code {
	ccall gtk_drawing_area_new ":p:p"
}

gtk_drawing_area_size :: !GtkWidgetP !Int !Int !GtkSt -> GtkSt;
gtk_drawing_area_size drawing_area width height gs = code {
	ccall gtk_drawing_area_size "pII:V:p"
}

