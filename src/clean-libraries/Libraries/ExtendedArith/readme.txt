               ExtendedArith
               ^^^^^^^^^^^^^
  an arithmetic library for big integers, rationals & complex numbers

This library can only be used with Clean 1.3.3 or higher. Installation should
be trivial.

For documentation of the "BigInt" module see file "BigIntDocumentation.txt". 
The other modules should be self explanatory, so no documentation is provided.

You can ignore all "no inline code for this rule" warnings.

The file "pi.icl" is an example program that calculates a certain number.

The ExtendedArith library itself is based on another library, the GNU MP (GMP)
library version 2.0.2 which is written mostly in C but also in assembly. This
library has the advantage of being distributed under conditions of the GNU
General Library Public License (GLPL). This gives users of that library (like
us, the Clean team) freedom to access the source code and modify it. 
 
By using the ExtendedArith library you will become a licensee of the GMP
library as well. The GLPL is quite liberal, but it imposes certain
restrictions. In general, if you redistribute the GMP library (as a part of
something else) you have to ensure that everyone you is still able to apply
changes that part of your code. In particular: If you create an executable
Clean program that uses the ExtendedArith library (and hence the GMP library)
you are _not_ allowed to give the executable to someone else without giving
him the source of the GMP library, including documentation about all applied
modifications (yours and ours). Violation of these rules might be persecuted
like any other software piratery. For further details see the GLPL at
http://www.fsf.org/copyleft/lgpl.html or in the file "Copying.lib" that comes
with this distribution.

The file gmp.o is made by compiling parts of the GMP library. The (modified)
source is available at the location from where you got this ExtendedArith
library.

In case of problems or questions don't hesitate to mailto:clean@cs.kun.nl

