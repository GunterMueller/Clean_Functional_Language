definition module texteditaccess


import	textedit


TEGetTextSize :: !TEHandle !*Toolbox -> (!Int,!*Toolbox)
TESetDestRect :: !TEHandle !Rect !*Toolbox -> *Toolbox
TESetViewRect :: !TEHandle !Rect !*Toolbox -> *Toolbox
