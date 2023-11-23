definition module write_symbol_table;

from StdFile import :: Files;
from State import :: State;

compute_n_symbols_and_string_table_size :: !*State -> (!Int,!Int,!*State);
write_symbol_table :: !Int !Int !Int !Int !Int !*State !*File -> (!*State,!*File);
