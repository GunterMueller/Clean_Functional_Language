implementation module gtk_menu_item;

import gtk_types;

gtk_menu_item_new_with_label :: !{#Char} !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_menu_item_new_with_label label gs = code {
	ccall gtk_menu_item_new_with_label "s:p:p"
}

gtk_menu_item_set_submenu :: !GtkWidgetP !GtkWidgetP !GtkSt -> GtkSt;
gtk_menu_item_set_submenu menu_item submenu gs = code {
	ccall gtk_menu_item_set_submenu "pp:V:p"
}
