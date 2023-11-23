definition module ExtInt;

// import pdExtInt;
from StdOverloaded import class + (+), class - (-), class ~ (~), class < (<),
		class zero (zero), class one (one);
from StdClass import class Ord, <=, class IncDec, dec;
from StdBool import &&, not;
from StdInt import bitnot, bitand;

roundup_to_multiple s m :== (s + (dec m)) bitand (~m);

from_base_i :: !String !Int !Int !Int -> Int;

between start middle end	:==  start <= middle && middle <= end;

