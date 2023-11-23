definition module pango_layout;

import gtk_types,pango_fonts;

:: PangoLayoutP :== Int;

pango_layout_set_font_description :: !PangoLayoutP !PangoFontDescriptionP !GtkSt -> GtkSt;

