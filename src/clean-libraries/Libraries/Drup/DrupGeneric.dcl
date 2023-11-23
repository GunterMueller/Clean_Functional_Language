definition module DrupGeneric

from DrupBasic import :: Write, :: Read, :: Chunk(..), :: Pointer
import StdGeneric

generic write a :: !.a !*Write -> *Write
generic read a :: !*Write -> *Read .a

derive write OBJECT, EITHER, CONS, FIELD, PAIR, UNIT, Int, Char, Real, Bool
derive read OBJECT, EITHER, CONS, FIELD, PAIR, UNIT, Int, Char, Real, Bool

derive bimap Read

derive write Pointer, Chunk, [], (,), (,,), (,,,)
derive read Pointer, Chunk, [], (,), (,,), (,,,)
