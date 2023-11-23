definition module cache_variable;

import compile;

store_state :: !*DclCache -> Int;
load_state :: Int -> .DclCache;
