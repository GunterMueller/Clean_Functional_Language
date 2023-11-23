implementation module gtk_menu_shell;

import gtk_types;

gtk_menu_shell_append :: !GtkWidgetP !GtkWidgetP !GtkSt -> GtkSt;
gtk_menu_shell_append menu_shell child gs = code {
	ccall gtk_menu_shell_append "pp:V:p"
}
