definition module EdFind

import	StdMaybe
from	StrictList	import :: StrictList
import	EdSelection

simpleLineSearch ::
	// plain search
	!Selection			// initial position	
	!Bool				// backwards
	!Bool				// wraparound
	!Bool				// ignore_case
	!Bool				// match_words
	!String				// search string
	!Text				// text
	-> Maybe Selection	// maybe found selection

simpleLineSearch` ::	// Alternative version for Replace All
	!Selection !Bool !Bool !Bool !Bool !String !*{String} -> (!Maybe Selection,!*{String})

regexpLineSearch ::
	// regexp search
	!Selection			// initial position	
	!Bool				// backwards
	!Bool				// wraparound
	!Bool				// ignore_case						[unused]
	!Bool				// match_words						[unused]
	!String				// search expression
	!Text				// text
	-> Maybe Selection	// maybe found selection

regexpLineSearch` ::	// Alternative version for Replace All
	!Selection !Bool !Bool !Bool !Bool !String !*{String} -> (!Maybe Selection,!*{String})

regexpLineReplace ::
	// regexp replace
	// Assumption is that the initial selection is a text fragment matching the
	// search expression. Checks that it indeed matches (mainly to find the sub-
	// strings. Returns the appropriate replacement string.
	!Selection			// initial selection
	!Bool				// search backwards					[unused]
	!Bool				// wraparound search				[unused]
	!Bool				// ignore case in search string		[unused]
	!Bool				// match_words						[unused]
	!String				// search expression
	!String				// replace expression
	!String				// original string
	-> Maybe String		// replacement string

