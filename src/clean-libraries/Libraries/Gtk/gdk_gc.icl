implementation module gdk_gc;

import gtk_types;

:: GdkGCP:==Int;
:: GdkColorP:==Int;

gdk_gc_set_background :: !GdkGCP !GdkColorP !GtkSt -> GtkSt;
gdk_gc_set_background gdk_gc_p gdk_color_p gs = code {
	ccall gdk_gc_set_background "pp:V:p"
}
