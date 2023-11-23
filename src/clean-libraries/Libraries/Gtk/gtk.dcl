definition module gtk;

import gtk_types;

gtk_init :: !Int !Int -> GtkSt;
gtk_main :: !GtkSt -> GtkSt;
gtk_main_quit :: !GtkSt -> GtkSt;

