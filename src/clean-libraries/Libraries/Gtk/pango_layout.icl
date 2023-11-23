implementation module pango_layout;

import gtk_types,pango_fonts;

pango_layout_set_font_description :: !PangoLayoutP !PangoFontDescriptionP !GtkSt -> GtkSt;
pango_layout_set_font_description layout desc gs = code {
    ccall pango_layout_set_font_description "pp:V:p"
}

