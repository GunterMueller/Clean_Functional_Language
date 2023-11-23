implementation module gtk;

import gtk_types;

gtk_init :: !Int !Int -> GtkSt;
gtk_init argc_p argv_p
	= gtk_init argc_p argv_p 0.0 newGtkSt;
{
	gtk_init :: !Int !Int !Real !GtkSt -> GtkSt;
	gtk_init argc_p argv_p r tk_st
		= code {
			ccall gtk_init "ppR:V:p"
		}
}

gtk_main :: !GtkSt -> GtkSt;
gtk_main gs = code {
	ccall gtk_main "G:V:p"
}

gtk_main_quit :: !GtkSt -> GtkSt;
gtk_main_quit gs = code {
	ccall gtk_main_quit ":V:p"
}

