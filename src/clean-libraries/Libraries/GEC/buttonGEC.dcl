definition module buttonGEC

import genericgecs

// various buttons and controls ...

derive gGEC Button, Checkbox, Text, UpDown

:: Button 	= Pressed | Button Int String
:: UpDown 	= UpPressed | DownPressed | Neutral
:: Checkbox = Checked | NotChecked 
:: Text 	= Text String

