implementation module gtk_menu;

import gtk_types;

gtk_menu_new :: !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_menu_new gs = code {
	ccall gtk_menu_new ":p:p"
}
