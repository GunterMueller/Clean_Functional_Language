definition module htmlDefault

// default values generator

import StdGeneric


generic defval a ::  a 

derive defval Int, Real, String, UNIT, EITHER, PAIR, CONS, FIELD, OBJECT

defaultval :: a | defval{|*|} a
