definition module xwindow;

//1.3
from StdString import String;
//3.1

create_window :: !Int !Int !Int !Int !Int !String !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int -> (!Int,!Int);
// void create_window (int,int,int,int,int,CleanString,int,int,int,int,int,int,int,int,int,int,int*,int*);
get_mouse_state :: !Int -> (!Int,!Int,!Int,!Int,!Int,!Int,!Int);
// void get_mouse_state (int,int*,int*,int*,int*,int*,int*,int*);
get_expose_area :: !Int -> (!Int,!Int,!Int,!Int,!Int);
// void get_expose_area (int,int*,int*,int*,int*,int*);
start_update :: !Int -> Int;
// int start_update (int);
end_update :: !Int -> Int;
// int end_update (int);
get_key_state :: !Int -> (!Int,!Int,!Int,!Int,!Int,!Int);
// void get_key_state (int,int*,int*,int*,int*,int*,int*);
get_screen_size :: !Int -> (!Int,!Int);
// void get_screen_size (int,int*,int*);
get_window_event :: !Int -> Int;
// int get_window_event (int);
set_scrollbars :: !Int !Int !Int !Int !Int !Int !Int -> (!Int,!Int);
// void set_scrollbars (int,int,int,int,int,int,int,int*,int*);
get_window_size :: !Int -> (!Int,!Int);
// void get_window_size (int,int*,int*);
get_current_thumbs :: !Int -> (!Int,!Int);
// void get_current_thumbs (int,int*,int*);
change_window :: !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int -> Int;
// int change_window (int,int,int,int,int,int,int,int,int,int,int,int,int,int);
get_first_update :: !Int -> (!Int,!Int);
// void get_first_update (int,int*,int*);
discard_updates :: !Int -> Int;
// int discard_updates (int);
activate_window :: !Int -> Int;
// int activate_window (int);
set_window_title :: !Int !{#Char} -> Int;
// int set_window_title (int,CleanString);
popdown :: !Int -> Int;
// int popdown (int);
popup :: !Int -> Int;
// int popup (int);
set_dd_distance :: !Int -> Int;
// int set_dd_distance (int);
get_window_position :: !Int -> (!Int,!Int);
// void get_window_position (int,int*,int*);
