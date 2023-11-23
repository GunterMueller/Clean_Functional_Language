
int add_menu_bar(int);
int add_menu(int,CleanString);
int add_sub_menu(int,CleanString);
int add_check_item(int,CleanString,int);
int add_menu_separator(int);
int add_menu_item(int,CleanString);
int enable_menu_widget(int);
int disable_menu_widget(int);
int check_widget(int,int);
int set_widget_title(int,CleanString);
int install_shortcut(int,CleanString);
int hide_menu(int);
int show_menu(int);
Clean(get_item_info :: Int -> (Int,Int,String,String))
void get_item_info(int, int *,int *,CleanString *,CleanString *);
Clean(get_submenu_info :: Int -> (String,Int))
void get_submenu_info(int,CleanString *,int *);
int destroy_item_widget(int);
int destroy_menu(int);
