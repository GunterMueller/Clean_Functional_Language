implementation module gtk_menu_bar;

import gtk_types;

gtk_menu_bar_new :: !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_menu_bar_new gs = code {
	ccall gtk_menu_bar_new ":p:p"
}
