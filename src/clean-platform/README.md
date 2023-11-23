# Clean Platform

The Clean Platform is a general purpose collection of libraries to supplement the Clean Standard Environment.
To increase maintainability and readability, these libraries follow a strict coding style guideline.
This guideline can be found in the file STANDARDS.txt and on the Clean Wiki. A listing of the conceived
API the Clean Platform will provide can be found in the file API.txt

More information about this project can be found on the Clean Wiki:
http://wiki.clean.cs.ru.nl/Clean_platform

Note that 32-bit platforms are not actively supported anymore!
There is no guarantee that the library remains working on 32-bit platforms.
We however still accept MRs fixing issues with 32-bit platforms.

## License

All original modules are provided under the same license as the Clean System,
the Simplified BSD License (2-clause BSD License, see [LICENSE](LICENCE)).

Some modules were ported from Haskell and they are provided the compatible
Haskell's 3-clause BSD license (see [LICENSE.BSD3](LICENCE.BSD3)).

- Control.Arrow
- Control.Category
- Data.Foldable
- Data.Heap
- Data.Map
- Data.Traversable
- Data.Tree
- Data.IntSet.Base
- Text.URI
- Data.Integer (interface only)
- Text.Unicode.Encodings.UTF8
- System.GetOpt
