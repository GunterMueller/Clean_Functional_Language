# Changelog

## 21.7

### New features
- added `Data.List.NonEmpty`, Erin van der Veen (@ErinvanderVeen), !470
- `Data.Error`: export `mapError` function, Gijs Alberts (gijs@gijsalberts.nl), !472
- `Data.Error`: implement `MonadFail` instance for `MaybeError String`, Erin van der Veen (@ErinvanderVeen), !473
- `Text.Html`: export `==` instance for `HtmlTag`, Gijs Alberts (gijs@gijsalberts.nl), !475
- `Data.Encoding.Binary`: export `gBinaryEncode`/`gBinaryEncodingSize`/`gBinaryDecode` for head strict/spine strict/head spine strict lists, !477
- Added `toString` instance to type `Either`, Elroy Jumpertz (@elroyTop), !478
- `System.Process`: Export `callProcessWithOutput` and `ProcessResult` record, Gijs Alberts (gijs@gijsalberts.nl), !479

### Other
- 32-bit platforms are not actively supported anymore, Steffen Michels (@smichels), !469

## 21.6

### New features
- Added `Text.CSV.foldedCsvRowsWith`, Steffen Michels (@smichels), !465

## 21.5

### New features
- Added System.AsyncIO module which supports performing network I/O operations in an asynchronous manner. For more information, see the System.AsyncIO module., Gijs Alberts (gijs@gijsalberts.nl), !451

## 21.4

### Bug fixes
- Bug fixes in Clean.Types.Tree and Clean.Types.Unify. `addType` has an extra argument for the type, prepared as a 'left' type for unification., Camil Staps (info@camilstaps.nl), !444

## 21.3

### New features
- Added `fromAscList`, `fromDescList`, `fromDistinctAscList`, and `fromDistinctDescList` to Data.Set that provide increased performance for less versatility, Erin van der Veen (erin@erinvanderveen.nl), !435
- Added functions `isSpecialisingUnifier`, `` generalises` ``, `` specialises` ``, and `` isomorphic_to` ``, which make it possible to check whether types that are already prepared for unification with `prepare_unification` specialise / generalise / are isomorphic to each other, Camil Staps (info@camilstaps.nl), !440

### Bug fixes
- Fixed bugs in unification of types with multiple scopes of universally quantified variables (Clean.Types.Unify), Camil Staps (info@camilstaps.nl), !440

## 21.2

### API changes
- Added support for non-standard notation of builtin types (e.g. `[] a`, but also `[]` and `[] a b`) to the Clean.Types parser and pretty-printer, Camil Staps (info@camilstaps.nl), !432

### Bug fixes
- Fixed timespecSleep for windows, Mart Lubbers (mart@cs.ru.nl), !433
