implementation module xkernel;

//1.3
from StdString import String;
//3.1


init_toplevelx :: !Int -> Int;
init_toplevelx a0 = code {
	ccall init_toplevelx "I:I"
}
// int init_toplevelx (int);

set_toplevelname :: !{#Char} -> Int;
set_toplevelname a0 = code {
	ccall set_toplevelname "S:I"
}
// int set_toplevelname (CleanString);

close_toplevelx :: !Int -> Int;
close_toplevelx a0 = code {
	ccall close_toplevelx "I:I"
}
// int close_toplevelx (int);

open_toplevelx :: !Int -> Int;
open_toplevelx a0 = code {
	ccall open_toplevelx "I:I"
}
// int open_toplevelx (int);

show_toplevelx :: !Int -> Int;
show_toplevelx a0 = code {
	ccall show_toplevelx "I:I"
}
// int show_toplevelx (int);

hide_toplevelx :: !Int -> Int;
hide_toplevelx a0 = code {
	ccall hide_toplevelx "I:I"
}
// int hide_toplevelx (int);

single_event_catch :: !Int -> (!Int,!Int);
single_event_catch a0 = code {
	ccall single_event_catch "I:VII"
}
// void single_event_catch (int,int*,int*);

destroy_widget :: !Int -> Int;
destroy_widget a0 = code {
	ccall destroy_widget "I:I"
}
// int destroy_widget (int);
