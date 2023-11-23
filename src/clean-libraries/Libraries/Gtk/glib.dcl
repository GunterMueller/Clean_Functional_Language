definition module glib;

import gtk_types;

g_thread_init :: !Int !GtkSt -> GtkSt;
g_malloc :: !Int !GtkSt -> (!Int,!GtkSt);
g_free :: !Int !GtkSt -> GtkSt;
