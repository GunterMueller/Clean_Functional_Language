implementation module gdk_drawable;

import gtk_types,pango_layout,gdk_gc;

:: GdkDrawableP :== Int;

gdk_draw_layout :: !GdkDrawableP !GdkGCP !Int !Int !PangoLayoutP !GtkSt -> GtkSt;
gdk_draw_layout drawable gc x y layout gs = code {
	ccall gdk_draw_layout "ppIIp:V:p"
}
