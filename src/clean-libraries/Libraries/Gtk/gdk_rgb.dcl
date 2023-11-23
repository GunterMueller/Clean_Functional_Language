definition module gdk_rgb;

import gtk_types,gdk_gc,gdk_drawable;

GDK_RGB_DITHER_NONE:==0;
GDK_RGB_DITHER_NORMAL:==1;
GDK_RGB_DITHER_MAX:==2;

gdk_draw_rgb_image :: !GdkDrawableP !GdkGCP !Int !Int !Int !Int !Int !Int !Int !GtkSt -> GtkSt;

