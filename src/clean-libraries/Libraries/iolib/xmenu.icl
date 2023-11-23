implementation module xmenu;

//1.3
from StdString import String;
//3.1


add_menu_bar :: !Int -> Int;
add_menu_bar a0 = code {
	ccall add_menu_bar "I:I"
}
// int add_menu_bar (int);

add_menu :: !Int !{#Char} -> Int;
add_menu a0 a1 = code {
	ccall add_menu "IS:I"
}
// int add_menu (int,CleanString);

add_sub_menu :: !Int !{#Char} -> Int;
add_sub_menu a0 a1 = code {
	ccall add_sub_menu "IS:I"
}
// int add_sub_menu (int,CleanString);

add_check_item :: !Int !{#Char} !Int -> Int;
add_check_item a0 a1 a2 = code {
	ccall add_check_item "ISI:I"
}
// int add_check_item (int,CleanString,int);

add_menu_separator :: !Int -> Int;
add_menu_separator a0 = code {
	ccall add_menu_separator "I:I"
}
// int add_menu_separator (int);

add_menu_item :: !Int !{#Char} -> Int;
add_menu_item a0 a1 = code {
	ccall add_menu_item "IS:I"
}
// int add_menu_item (int,CleanString);

enable_menu_widget :: !Int -> Int;
enable_menu_widget a0 = code {
	ccall enable_menu_widget "I:I"
}
// int enable_menu_widget (int);

disable_menu_widget :: !Int -> Int;
disable_menu_widget a0 = code {
	ccall disable_menu_widget "I:I"
}
// int disable_menu_widget (int);

check_widget :: !Int !Int -> Int;
check_widget a0 a1 = code {
	ccall check_widget "II:I"
}
// int check_widget (int,int);

set_widget_title :: !Int !{#Char} -> Int;
set_widget_title a0 a1 = code {
	ccall set_widget_title "IS:I"
}
// int set_widget_title (int,CleanString);

install_shortcut :: !Int !{#Char} -> Int;
install_shortcut a0 a1 = code {
	ccall install_shortcut "IS:I"
}
// int install_shortcut (int,CleanString);

hide_menu :: !Int -> Int;
hide_menu a0 = code {
	ccall hide_menu "I:I"
}
// int hide_menu (int);

show_menu :: !Int -> Int;
show_menu a0 = code {
	ccall show_menu "I:I"
}
// int show_menu (int);

get_item_info :: !Int -> (!Int,!Int,!String,!String);
get_item_info a0 = code {
	ccall get_item_info "I:VIISS"
}
// void get_item_info (int,int*,int*,CleanString*,CleanString*);

get_submenu_info :: !Int -> (!String,!Int);
get_submenu_info a0 = code {
	ccall get_submenu_info "I:VSI"
}
// void get_submenu_info (int,CleanString*,int*);

destroy_item_widget :: !Int -> Int;
destroy_item_widget a0 = code {
	ccall destroy_item_widget "I:I"
}
// int destroy_item_widget (int);

destroy_menu :: !Int -> Int;
destroy_menu a0 = code {
	ccall destroy_menu "I:I"
}
// int destroy_menu (int);
