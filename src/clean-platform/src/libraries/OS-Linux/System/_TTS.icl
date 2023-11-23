implementation module System._TTS

import StdTuple, StdOverloaded
import System.Process

_tts :: !(?Voice) !String !*World -> *World
_tts (?Just v) s w = say ["-t", toString v, s] w
_tts ?None     s w = say [s] w

say :: ![String] !*World -> *World
say args world = snd (runProcess "/usr/bin/spd-say" args ?None world)

instance toString Voice where
  toString Male1       = "male1"
  toString Male2       = "male2"
  toString Male3       = "male3"
  toString Female1     = "female1"
  toString Female2     = "female2"
  toString Female3     = "female3"
  toString ChildMale   = "child_male"
  toString ChildFemale = "child_female"
