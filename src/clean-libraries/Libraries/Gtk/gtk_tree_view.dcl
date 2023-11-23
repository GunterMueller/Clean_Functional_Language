definition module gtk_tree_view;

import gtk_types;

gtk_tree_view_new :: !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_tree_view_set_model :: !GtkWidgetP !GtkWidgetP !GtkSt -> GtkSt;
gtk_tree_view_get_model :: !GtkWidgetP !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_tree_view_append_column :: !GtkWidgetP !GtkWidgetP !GtkSt -> GtkSt;
gtk_tree_view_column_add_attribute :: !GtkWidgetP !GtkWidgetP !{#Char} !Int !GtkSt -> GtkSt;
gtk_tree_view_set_reorderable :: !GtkWidgetP !Bool !GtkSt -> GtkSt;
gtk_tree_view_set_headers_visible :: !GtkWidgetP !Bool !GtkSt -> GtkSt;
gtk_tree_view_get_selection :: !GtkWidgetP !GtkSt -> (!GtkWidgetP,!GtkSt);

