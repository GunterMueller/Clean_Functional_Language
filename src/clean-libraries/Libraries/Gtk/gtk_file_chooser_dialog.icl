implementation module gtk_file_chooser_dialog;

import gtk_types;

:: GtkFileChooserAction:==Int;

gtk_file_chooser_dialog_new_sisii :: !String !GtkWidgetP !GtkFileChooserAction !String !Int !String !Int !Int !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_file_chooser_dialog_new_sisii title parent action button_text1s button_text2i button_text3s button_text4i button_text_end gs = code {
	ccall gtk_file_chooser_dialog_new "spIsIsIp:p:p"
}

gtk_file_chooser_get_filename :: !GtkWidgetP !GtkSt -> (!Int,!GtkSt);
gtk_file_chooser_get_filename chooser gs = code {
	ccall gtk_file_chooser_get_filename "p:p:p"
}

gtk_file_chooser_set_filename :: !GtkWidgetP !String !GtkSt -> (!Bool,!GtkSt);
gtk_file_chooser_set_filename chooser filename gs = code {
	ccall gtk_file_chooser_set_filename "ps:I:p"
}

gtk_file_chooser_set_current_folder :: !GtkWidgetP !String !GtkSt -> (!Bool,!GtkSt);
gtk_file_chooser_set_current_folder chooser filename gs = code {
	ccall gtk_file_chooser_set_current_folder "ps:I:p"
}

gtk_file_chooser_set_current_name :: !GtkWidgetP !String !GtkSt -> (!Bool,!GtkSt);
gtk_file_chooser_set_current_name chooser name gs = code {
	ccall gtk_file_chooser_set_current_name "ps:I:p"
}

