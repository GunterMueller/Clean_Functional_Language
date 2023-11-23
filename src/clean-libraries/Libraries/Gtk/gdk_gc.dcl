definition module gdk_gc;

import gtk_types;

:: GdkGCP:==Int;
:: GdkColorP:==Int;

gdk_gc_set_background :: !GdkGCP !GdkColorP !GtkSt -> GtkSt;
