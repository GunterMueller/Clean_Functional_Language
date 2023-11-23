implementation module gdk_threads;

import gtk_types;

gdk_threads_init :: !GtkSt -> GtkSt;
gdk_threads_init gs = code {
	ccall gdk_threads_init ":V:p"
}

gdk_threads_enter:: !GtkSt -> GtkSt;
gdk_threads_enter gs = code {
	ccall gdk_threads_enter ":V:p"
}

gdk_threads_leave :: !GtkSt -> GtkSt;
gdk_threads_leave gs = code {
	ccall gdk_threads_leave ":V:p"
}

