implementation module gtk_cell_renderer_text;

import gtk_types;

gtk_cell_renderer_text_new :: !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_cell_renderer_text_new gs = code {
	ccall gtk_cell_renderer_text_new ":p:p"
}


