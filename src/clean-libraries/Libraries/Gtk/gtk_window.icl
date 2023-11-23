implementation module gtk_window;

import gtk_types;

:: GtkWindowType:==Int;

gtk_window_new :: !GtkWindowType !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_window_new type gs = code {
	ccall gtk_window_new "I:p:p"
}

gtk_window_set_default_size :: !GtkWidgetP !Int !Int !GtkSt -> GtkSt;
gtk_window_set_default_size window widht height gs = code {
	ccall gtk_window_set_default_size "pII:V:p"
}

gtk_window_add_accel_group :: !GtkWidgetP !GtkWidgetP !GtkSt -> GtkSt;
gtk_window_add_accel_group window accel_group gs = code {
	ccall gtk_window_add_accel_group "pp:V:p"
}


