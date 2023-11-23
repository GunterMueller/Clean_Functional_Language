definition module StdGECExt

import StdIO
import genericgecs//, StdBimap
	
import StdIO
import genericgecs

// createNGEC is a variant of generic gGEC function, String indicates in which window to put the editor
// String will become name of window; same string = same window  

createNGEC 	   :: String OutputOnly Bool a (Update a (PSt .ps)) *(PSt .ps) -> *((GECVALUE a *(PSt .ps)),*(PSt .ps)) | gGEC{|*|} a & bimap{|*|} ps

// createDummyGEC stores *any* value, no editor is made, no gGEC instance needed
createDummyGEC :: OutputOnly a (Update a (PSt .ps)) *(PSt .ps) -> *((GECVALUE a *(PSt .ps)),*(PSt .ps))

createMouseGEC :: String OutputOnly (Update MouseState (PSt .ps)) *(PSt .ps) -> *((GECVALUE MouseState *(PSt .ps)),*(PSt .ps)) 

searchWindowIdWithTitle :: String (IOSt .ps) -> (Maybe Id,IOSt .ps)

createDGEC :: String OutputOnly Bool a  *(PSt .ps) -> (a,*(PSt .ps)) | gGEC{|*|} a & bimap{|*|} ps
