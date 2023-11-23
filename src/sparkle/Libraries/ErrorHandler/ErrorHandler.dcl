definition module 
   ErrorHandler

import 
   StdEnv,
   StdPSt
   
:: HandlerError a       :== [a]
           
:: ErrorShortMessage a  :== a -> String
:: ErrorLongMessage a   :== a -> String

OK				:== []
isOK			:: !(HandlerError a) -> Bool
isError			:: !(HandlerError a) -> Bool
pushError		:: !a !(HandlerError a) -> HandlerError a

ErrorHandler	:: !(ErrorShortMessage a) !(ErrorLongMessage a) !Bool !(HandlerError a) ![String] !*(PSt .ps) -> (!String, !*PSt .ps)

TruncPath		:: !String -> String
TruncExtension	:: !String -> String  

smap			:: !(.a -> .b) !.[.a] -> .[.b]
             
umap			:: !(.a -> (.s -> (.c, .s))) !.[.a] !.s -> (!.[.c], !.s)
uwalk			:: !(.a -> (.s -> .s)) !.[.a] !.s -> .s
uuwalk			:: !(.a -> .(.s1 -> .(.s2 -> (.s1, .s2)))) ![.a] !.s1 !.s2 -> (!.s1, !.s2)
mapError		:: !(.a -> (HandlerError b, .c)) !.[.a] -> (!HandlerError b, !.[.c])
umapError		:: !(.a -> (.s -> (HandlerError b, .c, .s))) !.[.a] !.s -> (!HandlerError b, !.[.c], !.s)
uumapError		:: !(.a -> .(.s1 -> .(.s2 -> (HandlerError b, .c, .s1, .s2)))) !.[.a] !.s1 !.s2 -> (!HandlerError b, !.[.c], !.s1, !.s2)
uumap			:: !(.a -> .(.s1 -> .(.s2 -> (.c, .s1, .s2)))) !.[.a] !.s1 !.s2 -> (!.[.c], !.s1, !.s2)
uwalkError		:: !(.a -> (.s -> (HandlerError b, .s))) !.[.a] !.s -> (!HandlerError b, !.s)
uuwalkError		:: !(.a -> .(.s1 -> .(.s2 -> (HandlerError b, .s1, .s2)))) !.[.a] !.s1 !.s2 -> (!HandlerError b, !.s1, !.s2)
useqError		:: ![.a -> (HandlerError b, .a)] !.a -> (!HandlerError b, !.a)
ufilter			:: !(a .s -> (!Bool, .s)) ![a] !.s -> (![a], !.s)
