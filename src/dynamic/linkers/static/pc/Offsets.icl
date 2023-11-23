implementation module Offsets;

// FIXME: eliminate this module

import StdArray, StdClass;
import StdEnv;

Remove_at_size :: !String -> String;
Remove_at_size s = remove_at_size_i (size s-1);
		{
			remove_at_size_i -1
				= s;
			remove_at_size_i i
				| s.[i]<>'@'
					= remove_at_size_i (i-1);
					= s % (0,i-1) +++t;
					{
						t :: {#Char};
						t = createArray (size s-i) '\0';
					}
		}