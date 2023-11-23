definition module elf_linker;

from StdFile import ::Files;

link_elf_files :: ![String] ![String] !String !Files -> (!Bool,![String],!Files);
