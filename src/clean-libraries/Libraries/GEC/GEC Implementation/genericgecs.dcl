definition module genericgecs

import gec
import infragecs
//import StdBimap XXX

/** gGEC gecArgs env -->  (gec,env)
		creates the value-infrastructure of a Visual Editor Component (GEC) that is defined by
		induction on the structure of the type parameter t.
		
		Arguments:
		gecArgs:	a record of values to control the creation of the GEC.
		
		Result:
		gec:		the methods of the created GEC that a program can use to obtain information
					from the GEC at run-time in a polling way.
*/
generic gGEC t :: !(GECArgs t (PSt .ps)) !(PSt .ps) -> (!GECVALUE t (PSt .ps),!PSt .ps)
 
derive gGEC Bool, Int, Real, Char, String, UNIT, PAIR, EITHER, CONS, FIELD, OBJECT, []
