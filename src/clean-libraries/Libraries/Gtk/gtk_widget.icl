implementation module gtk_widget;

import gtk_types,pango_layout,gdk_gc;

:: GdkModifierType:==Int;
:: GtkAccelFlags:==Int;
:: GtkStateType:==Int;

gtk_widget_show :: !GtkWidgetP !GtkSt -> GtkSt;
gtk_widget_show widget_p gs = code {
	ccall gtk_widget_show "p:V:p"
}

gtk_widget_show_all :: !GtkWidgetP !GtkSt -> GtkSt;
gtk_widget_show_all widget_p gs = code {
	ccall gtk_widget_show_all "p:V:p"
}

gtk_widget_add_accelerator :: !GtkWidgetP !String !GtkWidgetP !Char !GdkModifierType !GtkAccelFlags !GtkSt -> GtkSt;
gtk_widget_add_accelerator widget accel_signal accel_group accel_key accel_mods accel_flags gs = code {
	ccall gtk_widget_add_accelerator "pspIII:V:p"
}

gtk_widget_destroy :: !GtkWidgetP !GtkSt -> GtkSt;
gtk_widget_destroy widget gs = code {
	ccall gtk_widget_destroy "p:V:p"
}

gtk_widget_create_pango_layout :: !GtkWidgetP !String !GtkSt -> (!PangoLayoutP,!GtkSt);
gtk_widget_create_pango_layout widget tex gs = code {
	ccall gtk_widget_create_pango_layout "ps:p:p"
}

gtk_widget_queue_draw :: !GtkWidgetP !GtkSt -> GtkSt;
gtk_widget_queue_draw widget gs = code {
	ccall gtk_widget_queue_draw "p:V:p"
}

gtk_widget_set_size_request :: !GtkWidgetP !Int !Int !GtkSt -> GtkSt;
gtk_widget_set_size_request widget width height gs = code {
	ccall gtk_widget_set_size_request "pII:V:p"
}

gtk_widget_modify_bg :: !GtkWidgetP !GtkStateType !GdkColorP !GtkSt -> GtkSt;
gtk_widget_modify_bg widget state color gs = code {
	ccall gtk_widget_modify_bg "pIp:V:p"
}

gtk_widget_modify_bg_a :: !GtkWidgetP !GtkStateType !{#Int} !GtkSt -> GtkSt;
gtk_widget_modify_bg_a widget state color gs = code {
	ccall gtk_widget_modify_bg "pIA:V:p"
}

