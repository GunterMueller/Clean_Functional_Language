implementation module DrupDynamic

import StdDynamic, DrupGeneric
import DrupBasic
from DynamicGraphConversion import string_to_dynamic, class EncodedDynamic (dynamic_to_string), instance EncodedDynamic String

write{|Dynamic|} x acc = write{|*|} (dynamicToString x) acc

read{|Dynamic|} acc = case read{|*|} acc of
	Read s left file -> Read (stringToDynamic s) left file
	Fail file -> Fail file

dynamicToString :: !Dynamic -> .String
dynamicToString d
	# (ok, s) = dynamic_to_string d
	| ok = s

stringToDynamic :: !String -> .Dynamic
stringToDynamic s
	# (ok, d) = string_to_dynamic s
	| ok = unsafeTypeCast d
