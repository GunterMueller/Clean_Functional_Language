implementation module xpicture;

//1.3
from StdString import String;
//3.1


start_drawing :: !Int -> Int;
start_drawing a0 = code {
	ccall start_drawing "I:I"
}
// int start_drawing (int);

end_drawing :: !Int -> Int;
end_drawing a0 = code {
	ccall end_drawing "I:I"
}
// int end_drawing (int);

hide_pen :: !Int -> Int;
hide_pen a0 = code {
	ccall hide_pen "I:I"
}
// int hide_pen (int);

show_pen :: !Int -> Int;
show_pen a0 = code {
	ccall show_pen "I:I"
}
// int show_pen (int);

get_pen :: !Int -> (!Int,!Int);
get_pen a0 = code {
	ccall get_pen "I:VII"
}
// void get_pen (int,int*,int*);

pen_size :: !Int !Int !Int -> Int;
pen_size a0 a1 a2 = code {
	ccall pen_size "III:I"
}
// int pen_size (int,int,int);

pen_mode :: !Int !Int -> Int;
pen_mode a0 a1 = code {
	ccall pen_mode "II:I"
}
// int pen_mode (int,int);

pen_pattern :: !Int !Int -> Int;
pen_pattern a0 a1 = code {
	ccall pen_pattern "II:I"
}
// int pen_pattern (int,int);

pen_normal :: !Int -> Int;
pen_normal a0 = code {
	ccall pen_normal "I:I"
}
// int pen_normal (int);

move_to :: !Int !Int !Int -> Int;
move_to a0 a1 a2 = code {
	ccall move_to "III:I"
}
// int move_to (int,int,int);

move_relative :: !Int !Int !Int -> Int;
move_relative a0 a1 a2 = code {
	ccall move_relative "III:I"
}
// int move_relative (int,int,int);

line_to :: !Int !Int !Int -> Int;
line_to a0 a1 a2 = code {
	ccall line_to "III:I"
}
// int line_to (int,int,int);

line_relative :: !Int !Int !Int -> Int;
line_relative a0 a1 a2 = code {
	ccall line_relative "III:I"
}
// int line_relative (int,int,int);

draw_string :: !{#Char} !Int -> Int;
draw_string a0 a1 = code {
	ccall draw_string "SI:I"
}
// int draw_string (CleanString,int);

get_color :: !Int -> Int;
get_color a0 = code {
	ccall get_color "I:I"
}
// int get_color (int);

foreground_color :: !Int !Int -> Int;
foreground_color a0 a1 = code {
	ccall foreground_color "II:I"
}
// int foreground_color (int,int);

background_color :: !Int !Int -> Int;
background_color a0 a1 = code {
	ccall background_color "II:I"
}
// int background_color (int,int);

rgb_fg_color :: !Real !Real !Real !Int -> Int;
rgb_fg_color a0 a1 a2 a3 = code {
	ccall rgb_fg_color "RRRI:I"
}
// int rgb_fg_color (double,double,double,int);

rgb_bg_color :: !Real !Real !Real !Int -> Int;
rgb_bg_color a0 a1 a2 a3 = code {
	ccall rgb_bg_color "RRRI:I"
}
// int rgb_bg_color (double,double,double,int);

draw_line :: !Int !Int !Int !Int !Int -> Int;
draw_line a0 a1 a2 a3 a4 = code {
	ccall draw_line "IIIII:I"
}
// int draw_line (int,int,int,int,int);

draw_point :: !Int !Int !Int -> Int;
draw_point a0 a1 a2 = code {
	ccall draw_point "III:I"
}
// int draw_point (int,int,int);

frame_rectangle :: !Int !Int !Int !Int !Int -> Int;
frame_rectangle a0 a1 a2 a3 a4 = code {
	ccall frame_rectangle "IIIII:I"
}
// int frame_rectangle (int,int,int,int,int);

paint_rectangle :: !Int !Int !Int !Int !Int -> Int;
paint_rectangle a0 a1 a2 a3 a4 = code {
	ccall paint_rectangle "IIIII:I"
}
// int paint_rectangle (int,int,int,int,int);

erase_rectangle :: !Int !Int !Int !Int !Int -> Int;
erase_rectangle a0 a1 a2 a3 a4 = code {
	ccall erase_rectangle "IIIII:I"
}
// int erase_rectangle (int,int,int,int,int);

invert_rectangle :: !Int !Int !Int !Int !Int -> Int;
invert_rectangle a0 a1 a2 a3 a4 = code {
	ccall invert_rectangle "IIIII:I"
}
// int invert_rectangle (int,int,int,int,int);

move_rectangle :: !Int !Int !Int !Int !Int !Int !Int -> Int;
move_rectangle a0 a1 a2 a3 a4 a5 a6 = code {
	ccall move_rectangle "IIIIIII:I"
}
// int move_rectangle (int,int,int,int,int,int,int);

copy_rectangle :: !Int !Int !Int !Int !Int !Int !Int -> Int;
copy_rectangle a0 a1 a2 a3 a4 a5 a6 = code {
	ccall copy_rectangle "IIIIIII:I"
}
// int copy_rectangle (int,int,int,int,int,int,int);

frame_round_rectangle :: !Int !Int !Int !Int !Int !Int !Int -> Int;
frame_round_rectangle a0 a1 a2 a3 a4 a5 a6 = code {
	ccall frame_round_rectangle "IIIIIII:I"
}
// int frame_round_rectangle (int,int,int,int,int,int,int);

paint_round_rectangle :: !Int !Int !Int !Int !Int !Int !Int -> Int;
paint_round_rectangle a0 a1 a2 a3 a4 a5 a6 = code {
	ccall paint_round_rectangle "IIIIIII:I"
}
// int paint_round_rectangle (int,int,int,int,int,int,int);

erase_round_rectangle :: !Int !Int !Int !Int !Int !Int !Int -> Int;
erase_round_rectangle a0 a1 a2 a3 a4 a5 a6 = code {
	ccall erase_round_rectangle "IIIIIII:I"
}
// int erase_round_rectangle (int,int,int,int,int,int,int);

invert_round_rectangle :: !Int !Int !Int !Int !Int !Int !Int -> Int;
invert_round_rectangle a0 a1 a2 a3 a4 a5 a6 = code {
	ccall invert_round_rectangle "IIIIIII:I"
}
// int invert_round_rectangle (int,int,int,int,int,int,int);

frame_oval :: !Int !Int !Int !Int !Int -> Int;
frame_oval a0 a1 a2 a3 a4 = code {
	ccall frame_oval "IIIII:I"
}
// int frame_oval (int,int,int,int,int);

paint_oval :: !Int !Int !Int !Int !Int -> Int;
paint_oval a0 a1 a2 a3 a4 = code {
	ccall paint_oval "IIIII:I"
}
// int paint_oval (int,int,int,int,int);

erase_oval :: !Int !Int !Int !Int !Int -> Int;
erase_oval a0 a1 a2 a3 a4 = code {
	ccall erase_oval "IIIII:I"
}
// int erase_oval (int,int,int,int,int);

invert_oval :: !Int !Int !Int !Int !Int -> Int;
invert_oval a0 a1 a2 a3 a4 = code {
	ccall invert_oval "IIIII:I"
}
// int invert_oval (int,int,int,int,int);

frame_arc :: !Int !Int !Int !Int !Int !Int !Int -> Int;
frame_arc a0 a1 a2 a3 a4 a5 a6 = code {
	ccall frame_arc "IIIIIII:I"
}
// int frame_arc (int,int,int,int,int,int,int);

paint_arc :: !Int !Int !Int !Int !Int !Int !Int -> Int;
paint_arc a0 a1 a2 a3 a4 a5 a6 = code {
	ccall paint_arc "IIIIIII:I"
}
// int paint_arc (int,int,int,int,int,int,int);

erase_arc :: !Int !Int !Int !Int !Int !Int !Int -> Int;
erase_arc a0 a1 a2 a3 a4 a5 a6 = code {
	ccall erase_arc "IIIIIII:I"
}
// int erase_arc (int,int,int,int,int,int,int);

invert_arc :: !Int !Int !Int !Int !Int !Int !Int -> Int;
invert_arc a0 a1 a2 a3 a4 a5 a6 = code {
	ccall invert_arc "IIIIIII:I"
}
// int invert_arc (int,int,int,int,int,int,int);

alloc_polygon :: !Int -> Int;
alloc_polygon a0 = code {
	ccall alloc_polygon "I:I"
}
// int alloc_polygon (int);

free_polygon :: !Int !Int -> Int;
free_polygon a0 a1 = code {
	ccall free_polygon "II:I"
}
// int free_polygon (int,int);

set_polygon_point :: !Int !Int !Int !Int -> Int;
set_polygon_point a0 a1 a2 a3 = code {
	ccall set_polygon_point "IIII:I"
}
// int set_polygon_point (int,int,int,int);

frame_polygon :: !Int !Int !Int !Int !Int -> Int;
frame_polygon a0 a1 a2 a3 a4 = code {
	ccall frame_polygon "IIIII:I"
}
// int frame_polygon (int,int,int,int,int);

paint_polygon :: !Int !Int !Int !Int !Int -> Int;
paint_polygon a0 a1 a2 a3 a4 = code {
	ccall paint_polygon "IIIII:I"
}
// int paint_polygon (int,int,int,int,int);

erase_polygon :: !Int !Int !Int !Int !Int -> Int;
erase_polygon a0 a1 a2 a3 a4 = code {
	ccall erase_polygon "IIIII:I"
}
// int erase_polygon (int,int,int,int,int);

invert_polygon :: !Int !Int !Int !Int !Int -> Int;
invert_polygon a0 a1 a2 a3 a4 = code {
	ccall invert_polygon "IIIII:I"
}
// int invert_polygon (int,int,int,int,int);

get_number_fonts :: !Int -> Int;
get_number_fonts a0 = code {
	ccall get_number_fonts "I:I"
}
// int get_number_fonts (int);

get_font_name :: !Int -> {#Char};
get_font_name a0 = code {
	ccall get_font_name "I:S"
}
// CleanString get_font_name (int);

get_font_info :: !Int -> (!Int,!Int,!Int,!Int,!Int);
get_font_info a0 = code {
	ccall get_font_info "I:VIIIII"
}
// void get_font_info (int,int*,int*,int*,int*,int*);

get_font_font_info :: !Int -> (!Int,!Int,!Int,!Int);
get_font_font_info a0 = code {
	ccall get_font_font_info "I:VIIII"
}
// void get_font_font_info (int,int*,int*,int*,int*);

get_string_width :: !Int !String -> (!Int,!Int);
get_string_width a0 a1 = code {
	ccall get_string_width "IS:VII"
}
// void get_string_width (int,CleanString,int*,int*);

get_font_string_width :: !Int !{#Char} -> Int;
get_font_string_width a0 a1 = code {
	ccall get_font_string_width "IS:I"
}
// int get_font_string_width (int,CleanString);

set_font :: !Int !Int !{#Char} !{#Char} !{#Char} -> Int;
set_font a0 a1 a2 a3 a4 = code {
	ccall set_font "IISSS:I"
}
// int set_font (int,int,CleanString,CleanString,CleanString);

set_font_name :: !Int !{#Char} -> Int;
set_font_name a0 a1 = code {
	ccall set_font_name "IS:I"
}
// int set_font_name (int,CleanString);

set_font_style :: !Int !{#Char} -> Int;
set_font_style a0 a1 = code {
	ccall set_font_style "IS:I"
}
// int set_font_style (int,CleanString);

set_font_size :: !Int !{#Char} -> Int;
set_font_size a0 a1 = code {
	ccall set_font_size "IS:I"
}
// int set_font_size (int,CleanString);

select_default_font :: !Int -> Int;
select_default_font a0 = code {
	ccall select_default_font "I:I"
}
// int select_default_font (int);

select_font :: !{#Char} -> Int;
select_font a0 = code {
	ccall select_font "S:I"
}
// int select_font (CleanString);

get_font_styles :: !String -> (!Int,!Int,!Int,!Int,!Int);
get_font_styles a0 = code {
	ccall get_font_styles "S:VIIIII"
}
// void get_font_styles (CleanString,int*,int*,int*,int*,int*);

get_font_sizes :: !{#Char} -> Int;
get_font_sizes a0 = code {
	ccall get_font_sizes "S:I"
}
// int get_font_sizes (CleanString);

get_one_font_size :: !Int -> Int;
get_one_font_size a0 = code {
	ccall get_one_font_size "I:I"
}
// int get_one_font_size (int);
