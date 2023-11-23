definition module dynamic_string;

import StdDynamic;

dynamic_to_string :: !Dynamic -> *{#Char};
string_to_dynamic :: *{#Char} -> Dynamic;
