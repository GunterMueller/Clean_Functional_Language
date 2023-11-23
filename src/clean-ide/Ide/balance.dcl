definition module balance

from EdText import :: Text, :: LineNr, :: Selection

//	Text_Balance returns the Selection of the smallest piece of balanced text surrounding
//	the cursor or the current selection.
Text_Balance :: !LineNr !Int !LineNr !Int !Text -> (!Bool,!Selection)
