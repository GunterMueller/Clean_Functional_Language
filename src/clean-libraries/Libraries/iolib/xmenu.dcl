definition module xmenu;

//1.3
from StdString import String;
//3.1

add_menu_bar :: !Int -> Int;
// int add_menu_bar (int);
add_menu :: !Int !{#Char} -> Int;
// int add_menu (int,CleanString);
add_sub_menu :: !Int !{#Char} -> Int;
// int add_sub_menu (int,CleanString);
add_check_item :: !Int !{#Char} !Int -> Int;
// int add_check_item (int,CleanString,int);
add_menu_separator :: !Int -> Int;
// int add_menu_separator (int);
add_menu_item :: !Int !{#Char} -> Int;
// int add_menu_item (int,CleanString);
enable_menu_widget :: !Int -> Int;
// int enable_menu_widget (int);
disable_menu_widget :: !Int -> Int;
// int disable_menu_widget (int);
check_widget :: !Int !Int -> Int;
// int check_widget (int,int);
set_widget_title :: !Int !{#Char} -> Int;
// int set_widget_title (int,CleanString);
install_shortcut :: !Int !{#Char} -> Int;
// int install_shortcut (int,CleanString);
hide_menu :: !Int -> Int;
// int hide_menu (int);
show_menu :: !Int -> Int;
// int show_menu (int);
get_item_info :: !Int -> (!Int,!Int,!String,!String);
// void get_item_info (int,int*,int*,CleanString*,CleanString*);
get_submenu_info :: !Int -> (!String,!Int);
// void get_submenu_info (int,CleanString*,int*);
destroy_item_widget :: !Int -> Int;
// int destroy_item_widget (int);
destroy_menu :: !Int -> Int;
// int destroy_menu (int);
