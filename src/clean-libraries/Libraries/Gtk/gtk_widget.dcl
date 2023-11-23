definition module gtk_widget;

import StdInt;
import gtk_types,pango_layout,gdk_gc;

:: GdkModifierType:==Int;
:: GtkAccelFlags:==Int;
:: GtkStateType:==Int;

GTK_STATE_NORMAL:==0;

gtk_widget_style_offset:==IF_INT_64_OR_32 48 24;
gtk_widget_window_offset:==IF_INT_64_OR_32 80 52;

gtk_widget_show :: !GtkWidgetP !GtkSt -> GtkSt;
gtk_widget_show_all :: !GtkWidgetP !GtkSt -> GtkSt;
gtk_widget_add_accelerator :: !GtkWidgetP !String !GtkWidgetP !Char !GdkModifierType !GtkAccelFlags !GtkSt -> GtkSt;
gtk_widget_destroy :: !GtkWidgetP !GtkSt -> GtkSt;
gtk_widget_create_pango_layout :: !GtkWidgetP !String !GtkSt -> (!PangoLayoutP,!GtkSt);
gtk_widget_queue_draw :: !GtkWidgetP !GtkSt -> GtkSt;
gtk_widget_set_size_request :: !GtkWidgetP !Int !Int !GtkSt -> GtkSt;
gtk_widget_modify_bg :: !GtkWidgetP !GtkStateType !GdkColorP !GtkSt -> GtkSt;
gtk_widget_modify_bg_a :: !GtkWidgetP !GtkStateType !{#Int} !GtkSt -> GtkSt;
