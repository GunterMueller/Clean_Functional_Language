definition module AltFileSelect

//	Opens a directory selector dialog.
//	Analogous to 'SelectInputFile'.
SelectDir ::	!*(PSt .l .p) -> (!Bool, !String, *PSt .l .p)
