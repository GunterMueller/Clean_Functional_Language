# Standards

The following guidelines should be adhered to when developing libraries for the
Clean Platform library collection.

Clean Platform was created to have a central place where commonly used
functionality was stored so that people didn't have to look for it. All the
functionality should be available on all platforms. This means that
functionality only working on Windows has no place here. It is allowed to
simulate functionality across systems. Examples of this is the System.Process
module that offers the same API across platforms.

## Contents

[[_TOC_]]

## Code style

### Type names

The names of types should be clear and informative, and should always start
with a capital.  If the name of a type consists of multiple words, each new
word should start with a capital.  Whenever the name is an abbreviation the
abbreviation should be written using only capitals (e.g. GUI,SQL,HTTP).

### Function names

Function names should be written in lowerCamelCase. By starting types and
constructors with a capital and functions without one, the difference between
a constructor and a function is immediately clear for the reader of a program.
Generic function names should normally start with `g`, and the next character
should be a capital.

### Module names

For modules, the same guidelines apply as for naming types. Names should be
informative and preferably short.

- When a library module is not meant for direct imports by end users, but
  should only used by experts in modules that for example provide a more
  friendly interface, you should prefix the name of that module with an
  underscore character (`_`) or place it in a separate `Internal` submodule.

- When a module (mainly) provides generic functions for functionality that
  could also be reasonably implemented differently, it should be prefixed with
  `Gen`.

### Argument order

While there are no hard demands on the order in which you specify the arguments
of functions, there are two rules which make your functions easier to use and
somewhat more clear:

- State representing arguments such as the common `*World` type argument,
  should be at the end of the argument list.
- Arguments which are used as "options" in some way should be at the beginning
  of the arguments. This makes it easy to pass in options by currying.

### Comments

A concise description of the purpose of a function and the meaning of its
arguments and result should be present in the .dcl file for all exported
functions. The documentation should not be included in the .icl file for
maintainability. Comments are specified as follows:

```clean
/**
 * This function is the identity.
 * @param Some value
 * @result The same value
 */
id :: a -> a
id x = x
```

Several JavaDoc like parameters are supported such as `@param`, `@result`,
`@type`, `@var` and `@representation`. More info about this can be found in
[DOCUMENTATION.md](DOCUMENTATION.md). We use `@complexity` for the complexity
order. Some other special fields are used, like `@gin-icon`, but one should be
reluctant with inventing new field names. If there is a general use case,
adding it can be discussed.

### Layout

- Tabs should be used for indentation. Spaces for alignment.
- The `where` keyword should be at the same level as the parent code block.

### Exporting functions and types

Definition modules (.dcl) must be very specific about the modules they import
because everything imported in a definition module is exported as well,
increasing the chance of name collisions. To minimize the chance for
collisions, adhere to the following conventions:

- Explicitly import the types and classes you need for specifying the type
  signatures by using the `from ... import ...` notation.

- Only ever import an entire module with the `import ...` notation if you
  really want to re-export the entire module.

Implementation modules may import anything they like.

## Instances and derivations
Clean Platform should, where applicable, provide instances for the types it provides for classes defined in StdEnv, Gast, and Platform itself.

The applicable instances for the _general_ classes should be exported in the module of the type and not of the class.
This means that for example the `Functor` instance of `Either` should be defined in `Data.Either` and not in `Data.Functor`.

For _specific_ classes the instances for types should be exported in submodules.
For example, `JSONEncode` for `Map` should be exported in `Data.Map.GenJSON` and not in `Data.Map` nor in `Text.GenJSON`.
This rule also holds for types that have multiple valid instances such as the `Monoid` for `Int`.

*General* classes are:

  - `Functor` from `Data.Functor`
  - `Monoid, Semigroup` from `Data.Monoid`
  - `Monad` from `Control.Monad` and applicable monads from `Control.Monad.*`
  - `Applicative, Alternative` from `Control.Applicative`
  - `gEq{|*|}` from `Data.GenEq`
  - `gDefault{|*|}` from `Data.GenDefault`
  - `GenFDomain` from `Data.GenFDomain`
  - Everything from `StdOverloaded`

*Specific* classes are for example:

  - `JSONEncode, JSONDecode` from `Text.JSON`
  - `ggen, genShow` from `Gast`

## OS/Architecture-specific implementations

Some low-level functionality requires different implementations for different
platforms. This is for example the case for modules dealing with external
processes or network interfaces. In src/libraries there are different
directories for different platforms and architectures, besides the
OS-Independent directory which is for code that works anywhere.

When implementing functionality that is OS or Architecture-specific it should
be implemented for all platforms. A common interface should be defined in
OS-Independent. This allows programmers to rely on the common interface and
trust that their application is cross-platform. A separate, platform-dependent
module prefixed with an underscore should be added to the other OS- or
Platform- directories.

In general, such a setup should follow the following rules:

- Programs importing modules from OS-Independent must compile on any platform.
- The use of 'internal' functions should be discouraged by prefixing their name
  with an underscore.
- Differences between platforms must be documented.

An example is the text-to-speech module System.TTS. OS-Independent contains
System.TTS with the following definitions:

```clean
from System._TTS import :: Voice

tts :: !String !*World -> *World
ttsWithVoice :: !Voice !String !*World -> *World
```

System.\_TTS is defined in OS-Linux, OS-Mac, and OS-Windows, with something
like:

```clean
:: Voice = Male1 // | ...
_tts :: !(?Voice) !String !*World -> *World
```

The platform-specific function starts with an underscore, discouraging its use.
Furthermore, it is documented that `Voice` has different constructors on each
operating system.

When specific implementation details are not available everywhere, this should
be clearly documented in the OS-Independent definition module. For example, on
Windows no different TTS voices are available; `Voice` contains only one
constructor and `tts` and `ttsWithVoice` are essentially equivalent. This way,
the general System.TTS API can still be used on Windows even though this aspect
cannot be used.

On the other hand, in the OS-Mac version of System.\_TTS, additional functions
are defined:

```clean
ttsToFile :: !String !String !*World -> *World
ttsWithVoiceToFile :: !Voice !String !String !*World -> *World
```

Since these have not been implemented for other platforms, they cannot be added
to System.TTS (it would be confusing if they would be a no-op). Therefore they
are in the platform-specific System.\_TTS, with a clear warning that it is not
cross-platform.
