definition module WriteMapFile;

from StdFile import :: Files;
from State import :: State;

generate_map_file :: !*State !*Files -> (!*State,!*Files);
