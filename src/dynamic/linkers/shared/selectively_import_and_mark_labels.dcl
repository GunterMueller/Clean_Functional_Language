definition module selectively_import_and_mark_labels;

from State import :: State;

replace_section_label_by_label2 :: !Int !Int !*State -> (!Int,!*State);

has_section_label_already_been_replaced  :: !Int !Int !*State -> (!Bool,!*State);

selective_import_symbol :: !Int !Int !*(!*{#Bool},!*State) -> *(!*{#Bool},!*State);
