implementation module xdialog;

//1.3
from StdString import String;
//3.1


create_commanddial :: !{#Char} !Int !Int !Int -> Int;
create_commanddial a0 a1 a2 a3 = code {
	ccall create_commanddial "SIII:I"
}
// int create_commanddial (CleanString,int,int,int);

create_propertydial :: !{#Char} !Int !Int -> Int;
create_propertydial a0 a1 a2 = code {
	ccall create_propertydial "SII:I"
}
// int create_propertydial (CleanString,int,int);

add_dialog_button :: !Int !Int !Int !Int !Int !{#Char} -> Int;
add_dialog_button a0 a1 a2 a3 a4 a5 = code {
	ccall add_dialog_button "IIIIIS:I"
}
// int add_dialog_button (int,int,int,int,int,CleanString);

add_static_text :: !Int !Int !Int !Int !Int !{#Char} -> Int;
add_static_text a0 a1 a2 a3 a4 a5 = code {
	ccall add_static_text "IIIIIS:I"
}
// int add_static_text (int,int,int,int,int,CleanString);

add_edit_text :: !Int !Int !Int !Int !Int !Int !{#Char} -> Int;
add_edit_text a0 a1 a2 a3 a4 a5 a6 = code {
	ccall add_edit_text "IIIIIIS:I"
}
// int add_edit_text (int,int,int,int,int,int,CleanString);

add_dialog_exclusives :: !Int !Int !Int !Int !Int !Int !Int -> Int;
add_dialog_exclusives a0 a1 a2 a3 a4 a5 a6 = code {
	ccall add_dialog_exclusives "IIIIIII:I"
}
// int add_dialog_exclusives (int,int,int,int,int,int,int);

add_dialog_popup :: !Int !Int !Int !Int !Int -> Int;
add_dialog_popup a0 a1 a2 a3 a4 = code {
	ccall add_dialog_popup "IIIII:I"
}
// int add_dialog_popup (int,int,int,int,int);

get_popup_ex :: !Int -> Int;
get_popup_ex a0 = code {
	ccall get_popup_ex "I:I"
}
// int get_popup_ex (int);

correct_popup_size :: !Int -> Int;
correct_popup_size a0 = code {
	ccall correct_popup_size "I:I"
}
// int correct_popup_size (int);

add_dialog_radiob :: !Int !Int !{#Char} !Int -> Int;
add_dialog_radiob a0 a1 a2 a3 = code {
	ccall add_dialog_radiob "IISI:I"
}
// int add_dialog_radiob (int,int,CleanString,int);

add_dialog_nonexclusives :: !Int !Int !Int !Int !Int !Int !Int -> Int;
add_dialog_nonexclusives a0 a1 a2 a3 a4 a5 a6 = code {
	ccall add_dialog_nonexclusives "IIIIIII:I"
}
// int add_dialog_nonexclusives (int,int,int,int,int,int,int);

add_dialog_checkb :: !Int !Int !{#Char} !Int -> Int;
add_dialog_checkb a0 a1 a2 a3 = code {
	ccall add_dialog_checkb "IISI:I"
}
// int add_dialog_checkb (int,int,CleanString,int);

add_dialog_control :: !Int !Int !Int !Int !Int !Int !Int !Int -> Int;
add_dialog_control a0 a1 a2 a3 a4 a5 a6 a7 = code {
	ccall add_dialog_control "IIIIIIII:I"
}
// int add_dialog_control (int,int,int,int,int,int,int,int);

set_command_default :: !Int !Int -> Int;
set_command_default a0 a1 = code {
	ccall set_command_default "II:I"
}
// int set_command_default (int,int);

get_edit_text :: !Int -> {#Char};
get_edit_text a0 = code {
	ccall get_edit_text "I:S"
}
// CleanString get_edit_text (int);

set_edit_text :: !Int !{#Char} -> Int;
set_edit_text a0 a1 = code {
	ccall set_edit_text "IS:I"
}
// int set_edit_text (int,CleanString);

set_static_text :: !Int !{#Char} -> Int;
set_static_text a0 a1 = code {
	ccall set_static_text "IS:I"
}
// int set_static_text (int,CleanString);

get_mark :: !Int -> Int;
get_mark a0 = code {
	ccall get_mark "I:I"
}
// int get_mark (int);

press_radio_widget :: !Int !{#Char} -> Int;
press_radio_widget a0 a1 = code {
	ccall press_radio_widget "IS:I"
}
// int press_radio_widget (int,CleanString);

get_dialog_event :: !Int -> (!Int,!Int);
get_dialog_event a0 = code {
	ccall get_dialog_event "I:VII"
}
// void get_dialog_event (int,int*,int*);

popup_modaldialog :: !Int -> Int;
popup_modaldialog a0 = code {
	ccall popup_modaldialog "I:I"
}
// int popup_modaldialog (int);

popup_modelessdialog :: !Int -> Int;
popup_modelessdialog a0 = code {
	ccall popup_modelessdialog "I:I"
}
// int popup_modelessdialog (int);

create_notice :: !{#Char} -> Int;
create_notice a0 = code {
	ccall create_notice "S:I"
}
// int create_notice (CleanString);

create_about_dialog :: !Int !Int !Int !Int !Int !{#Char} -> Int;
create_about_dialog a0 a1 a2 a3 a4 a5 = code {
	ccall create_about_dialog "IIIIIS:I"
}
// int create_about_dialog (int,int,int,int,int,CleanString);

add_n_button :: !Int !{#Char} !Int -> Int;
add_n_button a0 a1 a2 = code {
	ccall add_n_button "ISI:I"
}
// int add_n_button (int,CleanString,int);

handle_notice :: !Int -> Int;
handle_notice a0 = code {
	ccall handle_notice "I:I"
}
// int handle_notice (int);

beep :: !Int -> Int;
beep a0 = code {
	ccall beep "I:I"
}
// int beep (int);

get_current_rect :: !Int -> (!Int,!Int,!Int,!Int);
get_current_rect a0 = code {
	ccall get_current_rect "I:VIIII"
}
// void get_current_rect (int,int*,int*,int*,int*);

repos_widget :: !Int !Int !Int !Int !Int -> Int;
repos_widget a0 a1 a2 a3 a4 = code {
	ccall repos_widget "IIIII:I"
}
// int repos_widget (int,int,int,int,int);

get_father_width :: !Int -> Int;
get_father_width a0 = code {
	ccall get_father_width "I:I"
}
// int get_father_width (int);

set_dialog_margins :: !Int !Int !Int -> Int;
set_dialog_margins a0 a1 a2 = code {
	ccall set_dialog_margins "III:I"
}
// int set_dialog_margins (int,int,int);

mm_to_pixel_hor :: !Real -> Int;
mm_to_pixel_hor a0 = code {
	ccall mm_to_pixel_hor "R:I"
}
// int mm_to_pixel_hor (double);

mm_to_pixel_ver :: !Real -> Int;
mm_to_pixel_ver a0 = code {
	ccall mm_to_pixel_ver "R:I"
}
// int mm_to_pixel_ver (double);

activate_dialog :: !Int -> Int;
activate_dialog a0 = code {
	ccall activate_dialog "I:I"
}
// int activate_dialog (int);

enable_dialog_item :: !Int -> Int;
enable_dialog_item a0 = code {
	ccall enable_dialog_item "I:I"
}
// int enable_dialog_item (int);

disable_dialog_item :: !Int -> Int;
disable_dialog_item a0 = code {
	ccall disable_dialog_item "I:I"
}
// int disable_dialog_item (int);

check_dialog_item :: !Int !Int -> Int;
check_dialog_item a0 a1 = code {
	ccall check_dialog_item "II:I"
}
// int check_dialog_item (int,int);

destroy_dialog :: !Int -> Int;
destroy_dialog a0 = code {
	ccall destroy_dialog "I:I"
}
// int destroy_dialog (int);

popdown_dialog :: !Int -> Int;
popdown_dialog a0 = code {
	ccall popdown_dialog "I:I"
}
// int popdown_dialog (int);

dialog_item_to_object :: !Int -> Int;
dialog_item_to_object a0 = code {
	ccall dialog_item_to_object "I:I"
}
// int dialog_item_to_object (int);
