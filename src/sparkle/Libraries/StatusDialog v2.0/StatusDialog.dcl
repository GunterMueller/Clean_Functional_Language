definition module
	StatusDialog

import
	StdString,
	StdPSt

:: StatusDialogEvent		=    NewMessage !String | Finished | CloseStatusDialog
:: StatusDialogFunction ps	:== (StatusDialogEvent -> ps -> ps) -> ps -> ps

openStatusDialog :: !String !(StatusDialogFunction (*PSt .ps)) !(*PSt .ps) -> *PSt .ps