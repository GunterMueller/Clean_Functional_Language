definition module xfileselect;

//1.3
from StdString import String;
//3.1

select_input_file :: !Int -> (!Int,!String);
// void select_input_file (int,int*,CleanString*);
select_output_file :: !String !String -> (!Int,!String);
// void select_output_file (CleanString,CleanString,int*,CleanString*);
