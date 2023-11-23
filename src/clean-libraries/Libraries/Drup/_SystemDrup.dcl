definition module _SystemDrup

import StdArray, StdFile

fromArray :: !v:(a u:e) -> *[u:e] | Array a e, [v <= u]
//fromArray :: !v:(a e) -> *[e] | Array a e

unsafeCreateArray :: !Int -> *(a .e) | Array a e

unsafeTypeCast :: !.a -> .b

unsafeReopen :: !*File !Int -> (!Bool, !*File)
