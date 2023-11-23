implementation module xcursor;

//1.3
from StdString import String;
//3.1


set_window_cursor :: !Int !Int -> Int;
set_window_cursor a0 a1 = code {
	ccall set_window_cursor "II:I"
}
// int set_window_cursor (int,int);
