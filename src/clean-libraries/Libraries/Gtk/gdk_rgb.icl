implementation module gdk_rgb;

import gtk_types,gdk_gc,gdk_drawable;

gdk_draw_rgb_image :: !GdkDrawableP !GdkGCP !Int !Int !Int !Int !Int !Int !Int !GtkSt -> GtkSt;
gdk_draw_rgb_image drawable gc x y width height dither rgb_buf rowstride gs = code {
	ccall gdk_draw_rgb_image "ppIIIIIpp:V:p"
}
