definition module mach_o_linker;

from StdFile import ::Files;

link_mach_o_files :: ![String] !String !Files -> (!Bool,![String],!Files);