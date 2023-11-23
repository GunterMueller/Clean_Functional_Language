
int install_timer(int);
int change_timer_interval(int);
int get_timer_count(int);
int enable_timer(int);
int disable_timer(int);
Clean(get_current_time :: Int -> (Int,Int,Int))
void get_current_time(int,int *,int *,int *);
Clean (get_current_date :: Int -> (Int,Int,Int,Int))
void get_current_date(int,int *,int *,int *,int *);
int wait_mseconds(int);
