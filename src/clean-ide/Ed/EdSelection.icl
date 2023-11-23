implementation module EdSelection

// non-visual operations on selections

import StdList, StdFunc, StdBool, StdArray, StdTuple
import EdPosition, EdText

:: Selection 
	= { start	:: Position
	  , end		:: Position
	  }
	  
// An empty selection has the same start as end position.

emptySelection :: Selection
emptySelection 
  = { start	= { col = 0, row = 0 }
    , end	= { col = 0, row = 0 }
    }

lineSelection :: !Int -> Selection
lineSelection lnr =
	{ start	= {row = dec lnr,	col = 0}
	, end	= {row = lnr,		col = 0}
	}

isEmptySelection :: !Selection -> Bool
isEmptySelection { start, end }
  = start == end

notEmptySelection :: !Selection -> Bool
notEmptySelection { start, end }
  = start <> end

// After ordering a selection the start position is smaller
// the end position.

orderSelection :: !Selection -> Selection
orderSelection { start, end }
  | start < end
	= { start = start, end = end   }
    = { start = end,   end = start }

// The function changeSelection computes which selections 
// have to hilited if the selection change from the old to the
// new one.

changeSelection :: !Selection !Selection -> [Selection]
changeSelection oldSelection newSelection 
	= normalise (changeSelection` oldSelection newSelection)
where
	normalise = filter (notEmptySelection)

	changeSelection` :: Selection Selection -> [Selection]
	changeSelection` old new
		# old = orderSelection old
		# new = orderSelection new
		// completely the same => redraw nothing
		| old.start == new.start && old.end == new.end
			= []
		// selections do not overlap => redraw both
		| old.end <= new.start || old.start >= new.end
			= [ old, new ]
		// otherwise, redraw two fragments
		=	[ orderSelection { start = old.start,	end = new.start }
			, orderSelection { start = old.end,	end = new.end	}
			]

selectLines :: !Int !Int !Text -> Selection
selectLines bound1 bound2 text
  | last >= textLength text - 1
    = {start={col=0,row=first},end={col=size (fst (getLine last text)), row=last}}
    = {start={col=0,row=first},end={col=0,row=last+1}}
  where
    first = min bound1 bound2
    last  = max bound1 bound2

validateSelection :: !Selection Text -> Selection
validateSelection {start,end} text
	= {start = {start & row = startrow}, end = {end & row = endrow}}
where
	startrow = validateLineNr start.row text
	endrow = validateLineNr end.row text
