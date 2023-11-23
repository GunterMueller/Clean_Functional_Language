implementation module dynamic_string

import StdDynamic
import StdEnv

import graph_copy

dynamic_to_string :: !Dynamic -> *{#Char}
dynamic_to_string d
	= copy_to_string d

string_to_dynamic :: *{#Char} -> .Dynamic
string_to_dynamic s
	# (d,_) = copy_from_string s
	= d


mk_unique :: !{#Char} -> *{#Char}
mk_unique s = {s` \\ s` <-: s}
