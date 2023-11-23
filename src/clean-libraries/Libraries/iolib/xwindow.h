
Clean(create_window :: Int Int Int Int Int String Int Int Int Int Int Int Int Int Int Int -> (Int,Int))
void create_window(int,int,int,int,int,CleanString,int,int,int,int,int,int,int,int,int,int,int *,int *);

Clean(get_mouse_state :: Int -> (Int,Int,Int,Int,Int,Int,Int))
void get_mouse_state(int,int *,int *,int *,int *,int *,int *, int *);

Clean(get_expose_area :: Int -> (Int,Int,Int,Int,Int))
void get_expose_area(int,int *,int *,int *,int *,int *);

int start_update(int);
int end_update(int);

Clean(get_key_state :: Int -> (Int,Int,Int,Int,Int,Int))
void get_key_state(int,int *,int *,int*,int *,int *,int *); 

Clean(get_screen_size :: Int -> (Int,Int))
void get_screen_size(int,int *,int *);

int get_window_event(int);

Clean(set_scrollbars :: Int Int Int Int Int Int Int -> (Int,Int))
void set_scrollbars(int,int,int,int,int,int,int,int*,int*);

Clean(get_window_size :: Int -> (Int,Int))
void get_window_size(int, int*, int*);

Clean (get_current_thumbs :: Int -> (Int,Int))
void get_current_thumbs(int, int *, int *);

int change_window(int,int,int,int,int,int,int,int,int,int,int,int,int,int);

Clean(get_first_update :: Int -> (Int,Int))
void get_first_update(int,int *,int *);

int discard_updates(int);
int activate_window(int);
int set_window_title(int,CleanString);
 
int popdown(int);
int popup(int); 
int set_dd_distance(int);

Clean(get_window_position::Int -> (Int,Int))
void get_window_position (int,int*,int*);

