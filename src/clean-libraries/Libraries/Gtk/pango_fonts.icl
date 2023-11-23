implementation module pango_fonts;

import gtk_types,pango_layout;

:: PangoFontDescriptionP :== Int;

pango_font_description_from_string :: !String !GtkSt -> (!PangoFontDescriptionP,!GtkSt);
pango_font_description_from_string text gs = code {
	ccall pango_font_description_from_string "s:p:p"
}

pango_font_description_free :: !PangoFontDescriptionP !GtkSt -> GtkSt;
pango_font_description_free desc gs = code {
	ccall pango_font_description_free "p:V:p"
}

