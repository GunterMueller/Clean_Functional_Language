definition module g_object;

import gtk_types;

G_TYPE_STRING:==64;

g_object_unref :: !Int !GtkSt -> GtkSt;
g_value_init :: !GValue !Int !GtkSt -> GtkSt;
g_value_take_string :: !GValue !{#Char} !GtkSt -> GtkSt;
g_value_get_string :: !GValue !GtkSt -> (!Int,!GtkSt);
g_value_unset :: !GValue !GtkSt -> GtkSt;

