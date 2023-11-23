implementation module gdk;

import gtk_types;

gdk_flush:: !GtkSt -> GtkSt;
gdk_flush gs = code {
	ccall gdk_flush ":V:p"
}
