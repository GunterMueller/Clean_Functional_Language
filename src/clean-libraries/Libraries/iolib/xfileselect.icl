implementation module xfileselect;

//1.3
from StdString import String;
//3.1


select_input_file :: !Int -> (!Int,!String);
select_input_file a0 = code {
	ccall select_input_file "I:VIS"
}
// void select_input_file (int,int*,CleanString*);

select_output_file :: !String !String -> (!Int,!String);
select_output_file a0 a1 = code {
	ccall select_output_file "SS:VIS"
}
// void select_output_file (CleanString,CleanString,int*,CleanString*);
