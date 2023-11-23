definition module StdBimap

// from StdGeneric import generic bimap
import StdGeneric
from StdMaybe import :: Maybe

derive bimap Maybe, [], (,), (,,), (,,,), (,,,,), (,,,,,), (,,,,,,), (,,,,,,,)
