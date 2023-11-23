definition module gtk_window;

import gtk_types;

GTK_WINDOW_TOPLEVEL:==0;

:: GtkWindowType:==Int;

gtk_window_new :: !GtkWindowType !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_window_set_default_size :: !GtkWidgetP !Int !Int !GtkSt -> GtkSt;
gtk_window_add_accel_group :: !GtkWidgetP !GtkWidgetP !GtkSt -> GtkSt;

