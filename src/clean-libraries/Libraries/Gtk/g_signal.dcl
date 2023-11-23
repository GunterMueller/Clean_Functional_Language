definition module g_signal;

import gtk_types;

G_CONNECT_SWAPPED:==2;

g_signal_connect instance_ detailed_signal c_handler data gs
	:== g_signal_connect_data instance_ detailed_signal c_handler data 0 0 gs;

g_signal_connect_swapped instance_ detailed_signal c_handler data gs
	:== g_signal_connect_data instance_ detailed_signal c_handler data 0 G_CONNECT_SWAPPED gs;

g_signal_connect_data :: !GtkWidgetP !String !Int !Int !Int !Int !GtkSt -> (!Int,!GtkSt);
