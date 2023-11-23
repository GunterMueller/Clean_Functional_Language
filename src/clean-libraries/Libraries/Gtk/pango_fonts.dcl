definition module pango_fonts;

import gtk_types;

:: PangoFontDescriptionP :== Int;

pango_font_description_from_string :: !String !GtkSt -> (!PangoFontDescriptionP,!GtkSt);
pango_font_description_free :: !PangoFontDescriptionP !GtkSt -> GtkSt;

