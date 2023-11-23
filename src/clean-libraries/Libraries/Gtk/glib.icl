implementation module glib;

import gtk_types;

g_thread_init :: !Int !GtkSt -> GtkSt;
g_thread_init vtable gs = code {
	ccall g_thread_init "p:V:p"
}

g_malloc :: !Int !GtkSt -> (!Int,!GtkSt);
g_malloc n_bytes gs = code {
	ccall g_malloc "p:p:p"
}

g_free :: !Int !GtkSt -> GtkSt;
g_free p gs = code {
	ccall g_free "p:V:p"
}

