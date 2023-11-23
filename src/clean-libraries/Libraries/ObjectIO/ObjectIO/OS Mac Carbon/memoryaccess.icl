implementation module memoryaccess


import	StdArray
import	memory


handle_to_string :: !Handle !Int !*Toolbox -> (!{#Char},!*Toolbox)
handle_to_string handle size tb
=	(string,copy_handle_data_to_string string handle size tb)
where
	string	= createArray size ' '
