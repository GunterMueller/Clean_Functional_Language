definition module gtk_drawing_area;

import gtk_types;

gtk_drawing_area_new :: !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_drawing_area_size :: !GtkWidgetP !Int !Int !GtkSt -> GtkSt;

