definition module EdKeyMapping

// configuring the key mapping of the editor

from StdFile		import :: Files
from StdPSt			import :: PSt
from StdIOCommon	import :: KeyboardState, :: SpecialKey
from StdMaybe		import :: Maybe
from StdOverloaded	import class ==, class toString, class fromString
from EdActionType	import :: Action

KeyMapFileName	:== "default.km"

:: KeyMapping

// The first two arguments are there to circumvent the
// restriction that cyclic dependencies of definition modules are
// not allowed. The type should be:
//   configureKeyMapping :: (PSt EditorState .p) -> (PSt EditorState .p)
// But then you have to import EdState which imports this module...
// => can be removed in Clean 2.0!

configureKeyMapping :: KeyMapping (KeyMapping (PSt .l) -> (PSt .l)) (PSt .l) -> (PSt .l)

macKeyMapping		:: KeyMapping
//pcKeyMapping		:: KeyMapping

findAction			:: !KeyboardState !KeyMapping -> Maybe Action


ReadKeyMapFile	:: !{#Char} !*Files -> ((!KeyMapping, !Bool, !{#Char}),!*Files)
SaveKeyMapFile	:: !{#Char} !KeyMapping !*Files -> (!Bool, !*Files);

// avoid warnings
:: KeyCode
instance == KeyCode
instance toString KeyCode
instance fromString KeyCode
instance fromString SpecialKey
