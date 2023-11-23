implementation module xpath;

//1.3
from StdString import String;
//3.1


get_home_path :: !Int -> {#Char};
get_home_path a0 = code {
	ccall get_home_path "I:S"
}
// CleanString get_home_path (int);

get_appl_path :: !Int -> {#Char};
get_appl_path a0 = code {
	ccall get_appl_path "I:S"
}
// CleanString get_appl_path (int);
