definition module type_io_static

from StdFile import :: Files
from type_io_read import :: TIO_CommonDefs, :: TypeIOState

collect_type_infoNEW :: ![String] !*Files -> (!Bool,!*{#TIO_CommonDefs},!*TypeIOState,!*Files)
