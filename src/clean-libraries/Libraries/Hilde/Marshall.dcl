definition module Marshall

class marshall c f :: !c -> *f
class marshall_ c f :: c -> *f
class unmarshall c f :: !f -> *c

zeroString :: !Int -> *{#Char}
copyInt :: !Int -> *Int

instance marshall Int {#Char}
instance unmarshall Int {#Char}

instance marshall String {#Char}
instance unmarshall String {#Char}

