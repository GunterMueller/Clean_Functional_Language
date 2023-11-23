implementation module AltFileSelect

/*	Opens a directory selector dialog.
	Analogous to 'SelectInputFile'.
*/
SelectDir ::	!*(PSt .l .p) -> (!Bool, !String, *PSt .l .p)
SelectDir ps
   | gotit = ( True, RemoveFileName filepath, ps`)
           = (False,filepath,ps`)
where
	(result,ps`) = selectInputFile ps
	gotit = not (isNothing result)
	filepath = if gotit (fromJust result) "" 

