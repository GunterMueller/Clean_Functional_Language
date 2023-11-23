implementation module gtk_dialog;

import gtk_types;

gtk_dialog_new_with_buttons_sisii :: !{#Char} !GtkWidgetP !Int !{#Char} !Int !{#Char} !Int !Int !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_dialog_new_with_buttons_sisii title parent flags
	first_button_text first_button_response second_button_text second_button_response null gs = code {
	ccall gtk_dialog_new_with_buttons "spIsIsIp:p:p"
}

gtk_dialog_get_content_area :: !GtkWidgetP !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_dialog_get_content_area dialog gs = code {
	ccall gtk_dialog_get_content_area "p:p:p"
}

gtk_dialog_run :: !GtkWidgetP !GtkSt -> (!Int,!GtkSt);
gtk_dialog_run dialog gs = code {
	ccall gtk_dialog_run "Gp:I:p"
}

