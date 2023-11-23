definition module gdk_drawable;

import gtk_types,pango_layout,gdk_gc;

:: GdkDrawableP :== Int;

gdk_draw_layout :: !GdkDrawableP !GdkGCP !Int !Int !PangoLayoutP !GtkSt -> GtkSt;

