implementation module gtk_scrolled_window;

import gtk_types;

:: GtkPolicyType:==Int;

gtk_scrolled_window_new :: !GtkWidgetP !GtkWidgetP !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_scrolled_window_new hadjustment vadjustment gs = code {
	ccall gtk_scrolled_window_new "pp:p:p"
}

gtk_scrolled_window_set_policy :: !GtkWidgetP !GtkPolicyType !GtkPolicyType !GtkSt -> GtkSt;
gtk_scrolled_window_set_policy scrolled_window hscrollbar_policy vscrollbor_policy gs = code {
	ccall gtk_scrolled_window_set_policy "pII:V:p"
}

gtk_scrolled_window_add_with_viewport :: !GtkWidgetP !GtkWidgetP !GtkSt -> GtkSt;
gtk_scrolled_window_add_with_viewport scrolled_window child gs = code {
	ccall gtk_scrolled_window_add_with_viewport "pp:V:p"
}

gtk_scrolled_window_get_hadjustment :: !GtkWidgetP ! GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_scrolled_window_get_hadjustment scrolled_window gs = code {
	ccall gtk_scrolled_window_get_hadjustment "p:p:p"
}
