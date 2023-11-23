definition module Set

from StdOverloaded import class ==
from StdClass import class Eq

:: Set a :== [a]

union :: !.[a] !u:[a] -> v:[a] | Eq a, [u <= v]