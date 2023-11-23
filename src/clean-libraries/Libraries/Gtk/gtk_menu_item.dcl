definition module gtk_menu_item;

import gtk_types;

gtk_menu_item_new_with_label :: !{#Char} !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_menu_item_set_submenu :: !GtkWidgetP !GtkWidgetP !GtkSt -> GtkSt;
