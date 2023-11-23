definition module xkernel;

//1.3
from StdString import String;
//3.1

init_toplevelx :: !Int -> Int;
// int init_toplevelx (int);
set_toplevelname :: !{#Char} -> Int;
// int set_toplevelname (CleanString);
close_toplevelx :: !Int -> Int;
// int close_toplevelx (int);
open_toplevelx :: !Int -> Int;
// int open_toplevelx (int);
show_toplevelx :: !Int -> Int;
// int show_toplevelx (int);
hide_toplevelx :: !Int -> Int;
// int hide_toplevelx (int);
single_event_catch :: !Int -> (!Int,!Int);
// void single_event_catch (int,int*,int*);
destroy_widget :: !Int -> Int;
// int destroy_widget (int);
