definition module store

import StdId, StdReceiver

::	Store a ls pst = Store (StoreId a) (Maybe a)
::	StoreId a

openStoreId :: !*env -> (!StoreId a,!*env) | Ids env

instance Receivers (Store a)

openStore	:: !(StoreId a) !(Maybe a) !(PSt .ps) -> (!Bool,!PSt .ps)
valueStored	:: !(StoreId a)            !(PSt .ps) -> (!Bool,!PSt .ps)
readStore	:: !(StoreId a)            !(PSt .ps) -> (a,    !PSt .ps)
writeStore	:: !(StoreId a) a          !(PSt .ps) ->         PSt .ps
closeStore  :: !(StoreId a)            !(PSt .ps) ->         PSt .ps
