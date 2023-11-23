definition module dynamic_string

import StdDynamic
import graph_copy

dynamic_to_string 	:: !Dynamic -> *{#Char}
string_to_dynamic 	:: *{#Char} -> .Dynamic
