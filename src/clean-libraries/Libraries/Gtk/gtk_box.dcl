definition module gtk_box;

import gtk_types;

gtk_box_pack_start :: !GtkWidgetP !GtkWidgetP !Int !Int !Int !GtkSt -> GtkSt;
gtk_box_pack_end :: !GtkWidgetP !GtkWidgetP !Int !Int !Int !GtkSt -> GtkSt;

