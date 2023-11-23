implementation module EdLook

// the edit window update function

import StdInt, StdBool, StdClass
import StdIOCommon
import StdPicture
import EdVisualText, EdVisualCursor, EdVisualLineNr, EdSelection

// editWindowLook: updating the affected areas is done by updating
// each of the rectangles.

editWindowLook :: EditState SelectState !UpdateState -> (*Picture -> *Picture)
editWindowLook editState selectState updateState=:{ updArea, newFrame, oldFrame }
	= editWindowLook`
where
	editWindowLook`  picture
		# updArea = cleanUpdate updArea	// hack around object i/o bug...
		# picture = vDrawLineNrs fontInfo text newFrame updArea picture
		# picture = vUpdateText fontInfo text newFrame updArea picture
		# picture = case visible of
			True -> vUpdateCursor visible end height fontInfo text newFrame updArea picture
			_    -> vUpdateSelection selection fontInfo text newFrame updArea picture
		= picture
	(fontInfo,ds1)			= getFontInfo (editState,42)
	(text,ds2)				= getText ds1
	(visible,ds3)			= getCursorVisibility ds2
	(height,ds4)			= getCursorHeight ds3
	(selection=:{end},_)	= getSelection ds4

cleanUpdate [] = []
cleanUpdate [h:t]
	| h.corner1.x == h.corner2.x = cleanUpdate t
	| h.corner1.y == h.corner2.y = cleanUpdate t
	= [h: cleanUpdate t]
