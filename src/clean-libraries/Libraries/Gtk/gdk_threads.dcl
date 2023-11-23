definition module gdk_threads;

import gtk_types;

gdk_threads_init :: !GtkSt -> GtkSt;
gdk_threads_enter :: !GtkSt -> GtkSt;
gdk_threads_leave :: !GtkSt -> GtkSt;

