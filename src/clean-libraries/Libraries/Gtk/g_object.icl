implementation module g_object;

import gtk_types;

g_object_unref :: !Int !GtkSt -> GtkSt;
g_object_unref object gs = code {
	ccall g_object_unref "p:V:p"
}

g_value_init :: !GValue !Int !GtkSt -> GtkSt;
g_value_init value g_type gs = code {
	ccall g_value_init "AI:V:p"
} // ignore GValue result

g_value_take_string :: !GValue !{#Char} !GtkSt -> GtkSt;
g_value_take_string value v_string gs = code {
	ccall g_value_take_string "As:V:p"
}

g_value_get_string :: !GValue !GtkSt -> (!Int,!GtkSt);
g_value_get_string value gs = code {
	ccall g_value_get_string "A:p:p"
}

g_value_unset :: !GValue !GtkSt -> GtkSt;
g_value_unset value gs = code {
	ccall g_value_unset "A:V:p"
}

