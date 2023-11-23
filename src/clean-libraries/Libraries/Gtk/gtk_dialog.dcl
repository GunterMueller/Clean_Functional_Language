definition module gtk_dialog;

import gtk_types;

GTK_RESPONSE_ACCEPT :== -3;
GTK_RESPONSE_CANCEL :== -6;

GTK_DIALOG_MODAL:==1;

gtk_dialog_new_with_buttons_sisii :: !{#Char} !GtkWidgetP !Int !{#Char} !Int !{#Char} !Int !Int !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_dialog_get_content_area :: !GtkWidgetP !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_dialog_run :: !GtkWidgetP !GtkSt -> (!Int,!GtkSt);
