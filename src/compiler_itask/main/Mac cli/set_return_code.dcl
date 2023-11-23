definition module set_return_code;

//1.3
from StdString import String;
//3.1

:: *UniqueWorld :== World;
set_return_code :: !Int !UniqueWorld -> UniqueWorld;
// void set_return_code (int return_code);
