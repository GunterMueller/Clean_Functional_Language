definition module link_library_instance;

from StdFile import class FileEnv;
from StdMaybe import :: Maybe;
from DLState import :: DLClientState;
from dus_label import ::DusLabel;
from StdDynamicTypes import :: LibraryInstanceTypeReference;

LoadTypeTable :: !Int !Int *DLClientState *a -> *(*DLClientState,*a) | FileEnv a;

// redirect_type_implementation_equivalent_class :: !.LibraryInstanceTypeReference ![.LibraryInstanceTypeReference] !*DLClientState -> *DLClientState;

initialize_library_instance :: Int !*DLClientState *f -> (!Bool,!*DLClientState,!*f) | FileEnv f;

load_code_library_instance :: (Maybe [.DusLabel]) !.Int !*DLClientState !*f -> (!Int,[Int],!*DLClientState,!*f) | FileEnv f;
