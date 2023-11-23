definition module my_scrap;

from ioState import IOState;

IOPutScrap :: !{#Char} !(IOState s) -> IOState s;
IOGetScrap :: !(IOState s) -> (!{#Char},!IOState s);
