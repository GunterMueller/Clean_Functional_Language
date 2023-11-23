definition module Gerda

import StdMisc, StdMaybe, StdGeneric

:: Gerda

openGerda 		:: !String !*World -> (!*Gerda, !*World)
closeGerda 		:: !*Gerda !*World -> *World
writeGerda 		:: !String !a !*Gerda -> *Gerda | gerda{|*|} a
readGerda 		:: !String !*Gerda -> (!Maybe a, !*Gerda) | gerda{|*|} a
deleteGerda 	:: !String !*Gerda -> *Gerda

:: Binary252 = {binary252 :: !.String}
:: CompactList a = CompactList a .(Maybe (CompactList a))
:: GerdaObject a = {gerdaObject :: a, 
					gerdaWrite :: a -> *Gerda -> *Gerda,
					gerdaRead :: *Gerda -> *(a, *Gerda)}
:: GerdaPrimary k v = {gerdaKey :: !k, gerdaValue :: v}
:: GerdaUnique u = {gerdaUnique :: !u}

gerdaObject x :== {gerdaObject = x, gerdaWrite = undef, gerdaRead = undef}

:: GerdaFunctions a

generic gerda a :: GerdaFunctions a

derive gerda OBJECT, EITHER, CONS, FIELD, PAIR, UNIT
derive gerda Int, Real, Char, Bool, Maybe, Binary252
derive gerda CompactList, String, [], {}, {!}, GerdaObject, GerdaPrimary, GerdaUnique
derive bimap GerdaFunctions