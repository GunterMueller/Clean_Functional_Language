definition module LoesKeyList

import LoesAssoc

:: KeyList k a

instance Empty (KeyList k .a)
instance Size (KeyList k a)

instance AssocX KeyList k a | == k
instance Assoc KeyList k a | == k

instance Fold (KeyList k) a

instance uSize (KeyList k .a)
instance uAssocX KeyList k a | == k
instance uAssoc KeyList k a | == k
