definition module xtimer;

//1.3
from StdString import String;
//3.1

install_timer :: !Int -> Int;
// int install_timer (int);
change_timer_interval :: !Int -> Int;
// int change_timer_interval (int);
get_timer_count :: !Int -> Int;
// int get_timer_count (int);
enable_timer :: !Int -> Int;
// int enable_timer (int);
disable_timer :: !Int -> Int;
// int disable_timer (int);
get_current_time :: !Int -> (!Int,!Int,!Int);
// void get_current_time (int,int*,int*,int*);
get_current_date :: !Int -> (!Int,!Int,!Int,!Int);
// void get_current_date (int,int*,int*,int*,int*);
wait_mseconds :: !Int -> Int;
// int wait_mseconds (int);
