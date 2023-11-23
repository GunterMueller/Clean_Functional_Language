implementation module xwindow;

//1.3
from StdString import String;
//3.1


create_window :: !Int !Int !Int !Int !Int !String !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int -> (!Int,!Int);
create_window a0 a1 a2 a3 a4 a5 a6 a7 a8 a9 a10 a11 a12 a13 a14 a15 = code {
	ccall create_window "IIIIISIIIIIIIIII:VII"
}
// void create_window (int,int,int,int,int,CleanString,int,int,int,int,int,int,int,int,int,int,int*,int*);

get_mouse_state :: !Int -> (!Int,!Int,!Int,!Int,!Int,!Int,!Int);
get_mouse_state a0 = code {
	ccall get_mouse_state "I:VIIIIIII"
}
// void get_mouse_state (int,int*,int*,int*,int*,int*,int*,int*);

get_expose_area :: !Int -> (!Int,!Int,!Int,!Int,!Int);
get_expose_area a0 = code {
	ccall get_expose_area "I:VIIIII"
}
// void get_expose_area (int,int*,int*,int*,int*,int*);

start_update :: !Int -> Int;
start_update a0 = code {
	ccall start_update "I:I"
}
// int start_update (int);

end_update :: !Int -> Int;
end_update a0 = code {
	ccall end_update "I:I"
}
// int end_update (int);

get_key_state :: !Int -> (!Int,!Int,!Int,!Int,!Int,!Int);
get_key_state a0 = code {
	ccall get_key_state "I:VIIIIII"
}
// void get_key_state (int,int*,int*,int*,int*,int*,int*);

get_screen_size :: !Int -> (!Int,!Int);
get_screen_size a0 = code {
	ccall get_screen_size "I:VII"
}
// void get_screen_size (int,int*,int*);

get_window_event :: !Int -> Int;
get_window_event a0 = code {
	ccall get_window_event "I:I"
}
// int get_window_event (int);

set_scrollbars :: !Int !Int !Int !Int !Int !Int !Int -> (!Int,!Int);
set_scrollbars a0 a1 a2 a3 a4 a5 a6 = code {
	ccall set_scrollbars "IIIIIII:VII"
}
// void set_scrollbars (int,int,int,int,int,int,int,int*,int*);

get_window_size :: !Int -> (!Int,!Int);
get_window_size a0 = code {
	ccall get_window_size "I:VII"
}
// void get_window_size (int,int*,int*);

get_current_thumbs :: !Int -> (!Int,!Int);
get_current_thumbs a0 = code {
	ccall get_current_thumbs "I:VII"
}
// void get_current_thumbs (int,int*,int*);

change_window :: !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int -> Int;
change_window a0 a1 a2 a3 a4 a5 a6 a7 a8 a9 a10 a11 a12 a13 = code {
	ccall change_window "IIIIIIIIIIIIII:I"
}
// int change_window (int,int,int,int,int,int,int,int,int,int,int,int,int,int);

get_first_update :: !Int -> (!Int,!Int);
get_first_update a0 = code {
	ccall get_first_update "I:VII"
}
// void get_first_update (int,int*,int*);

discard_updates :: !Int -> Int;
discard_updates a0 = code {
	ccall discard_updates "I:I"
}
// int discard_updates (int);

activate_window :: !Int -> Int;
activate_window a0 = code {
	ccall activate_window "I:I"
}
// int activate_window (int);

set_window_title :: !Int !{#Char} -> Int;
set_window_title a0 a1 = code {
	ccall set_window_title "IS:I"
}
// int set_window_title (int,CleanString);

popdown :: !Int -> Int;
popdown a0 = code {
	ccall popdown "I:I"
}
// int popdown (int);

popup :: !Int -> Int;
popup a0 = code {
	ccall popup "I:I"
}
// int popup (int);

set_dd_distance :: !Int -> Int;
set_dd_distance a0 = code {
	ccall set_dd_distance "I:I"
}
// int set_dd_distance (int);

get_window_position :: !Int -> (!Int,!Int);
get_window_position a0 = code {
	ccall get_window_position "I:VII"
}
// void get_window_position (int,int*,int*);
