definition module DrupDefault

import StdGeneric, StdMaybe

:: DefaultHistory
:: DefaultPath

maybeDefault :: Maybe .a | default{|*|} a

generic default a :: !DefaultPath !DefaultHistory -> (!Maybe .a, !Int)

derive default OBJECT, EITHER, CONS, FIELD, PAIR, UNIT
derive default Int, Char, Bool, Real, {}, {!}, String

