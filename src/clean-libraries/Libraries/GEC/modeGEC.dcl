definition module modeGEC

import genericgecs

// Mode = Display (non editable) ; Hide (invisable) ; Edit (regular)

derive gGEC Mode

:: Mode a 	= Display a
			| Hide a
			| Edit a
			| EmptyMode
