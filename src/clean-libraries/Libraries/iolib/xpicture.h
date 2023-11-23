
int start_drawing(int);
int end_drawing(int);

int hide_pen(int);
int show_pen(int);
Clean(get_pen :: Int -> (Int,Int))
void get_pen(int,int *,int *);
int pen_size(int,int,int);
int pen_mode(int,int);
int pen_pattern(int,int);
int pen_normal(int);

int move_to(int,int,int);
int move_relative(int,int,int);
int line_to(int,int,int);
int line_relative(int,int,int);
int draw_string(CleanString,int);

int get_color(int);
int foreground_color(int,int);
int background_color(int,int);
int rgb_fg_color(double,double,double,int);
int rgb_bg_color(double,double,double,int);

int draw_line(int,int,int,int,int);
int draw_point(int,int,int);
int frame_rectangle(int,int,int,int,int);
int paint_rectangle(int,int,int,int,int);
int erase_rectangle(int,int,int,int,int);
int invert_rectangle(int,int,int,int,int);
int move_rectangle(int,int,int,int,int,int,int);
int copy_rectangle(int,int,int,int,int,int,int);
int frame_round_rectangle(int,int,int,int,int,int,int);
int paint_round_rectangle(int,int,int,int,int,int,int);
int erase_round_rectangle(int,int,int,int,int,int,int);
int invert_round_rectangle(int,int,int,int,int,int,int);
int frame_oval(int,int,int,int,int);
int paint_oval(int,int,int,int,int);
int erase_oval(int,int,int,int,int);
int invert_oval(int,int,int,int,int);
int frame_arc(int,int,int,int,int,int,int);
int paint_arc(int,int,int,int,int,int,int);
int erase_arc(int,int,int,int,int,int,int);
int invert_arc(int,int,int,int,int,int,int);
int alloc_polygon(int);
int free_polygon(int,int);
int set_polygon_point(int,int,int,int);
int frame_polygon(int,int,int,int,int);
int paint_polygon(int,int,int,int,int);
int erase_polygon(int,int,int,int,int);
int invert_polygon(int,int,int,int,int);

int get_number_fonts(int);
CleanString get_font_name(int);
Clean(get_font_info::Int -> (Int,Int,Int,Int,Int))
void get_font_info(int,int *,int *,int *,int *,int*);
Clean(get_font_font_info :: Int -> (Int,Int,Int,Int))
void get_font_font_info(int,int *,int *,int *,int *);
Clean(get_string_width :: Int String -> (Int,Int))
void get_string_width(int,CleanString,int *,int*);
int get_font_string_width(int,CleanString);
int set_font(int,int,CleanString,CleanString,CleanString);
int set_font_name(int, CleanString);
int set_font_style(int, CleanString);
int set_font_size(int, CleanString);
int select_default_font(int);
int select_font(CleanString);
Clean(get_font_styles :: String -> (Int,Int,Int,Int,Int))
void get_font_styles(CleanString,int *,int *,int *,int *,int *);
int get_font_sizes(CleanString);
int get_one_font_size(int);
