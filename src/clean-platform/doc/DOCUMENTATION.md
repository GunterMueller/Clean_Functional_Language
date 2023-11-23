# Clean documentation
Cloogle indexes documentation of the syntax elements it stores, through
functions in `Clean.Doc`. Docblocks are comments that start with `/**` and have
a leading asterisk on every line (leading whitespace is ignored). The first
part of the docblock is taken as a general description. Below the description,
documentation fields can be added with `@`.

An example is below:

```clean
/**
 * Apply a function to every element in a list.
 *
 * @param The function
 * @param The list
 * @result The new list
 */
map :: (a -> b) [a] -> [b]
```

`@result` can be given multiple times for tuples.

For short documentation items, doclines, starting with `//*` can be used. When
documenting a constructor, or record field, they should be placed *after* the
item they document. For example:

```clean
/**
 * A date in the Gregorian calendar
 */
:: Date =
	{ day   :: Int  //* The day of the month, starting with 1
	, month :: Int  //* The month (January is 1)
	, year  :: Int  //* The year
	}
```

To add several lines of documentation to a constructor or record field, several
doclines can be used:

```clean
:: MyType
	= MyConstructor args // ...
		//* This constructor may require some more explanation,
		//* which is added on several lines.
```

Doclines can also be added *above* a function, type, or class definition:

```clean
//* The identity function.
id :: .a -> .a
```

To provide documentation for an entire module, the docblock or docline should
be placed after the module line and before anything else:

```clean
definition module Data.Either

/**
 * This module defines the `Either` type to represent binary choice.
 * Clean's generics define a similar type `EITHER`, but this should only be
 * used inside generic functions, since most generic functions treat this
 * type in a special way which may lead to strange behavior.
 */

from StdOverloaded import class ==
```

## Markup in documentation

Some simple Markdown-inspired markup is allowed in documentation:

- `` `foo` `` renders `foo` in monospaced font.
- Code blocks can be surrounded by `` ``` `` on separate lines. The start of a
  code block can indicate the language (for highlighting purposes), as in
  `` ```clean ``.
- `{{bar}}` marks `bar` as a defined entity (that can be searched for).
- Double newlines distinguish paragraphs; single newlines are ignored unless
  followed by a hyphen.

## Documentation fields

The tables below describe which fields and documentation types can be used for
different syntax elements, and what they should document. An extension, to
document test properties, is discussed below.

What fields are accepted for what syntax elements is defined by the records in
`Clean.Doc`; how they are parsed in the instances of the generic function
`docBlockToDoc`. The below is merely a convenient representation of the same
information.

|              | Description | `@param` | `@result` | `@type` | `@var` | `@representation` | `@throws` | `@complexity`
|--------------|-------------|----------|-----------|---------|--------|-------------------|-----------|--------------
| Class        | ![][y]      | ![][y]<sup>1</sup> | ![][y]<sup>1</sup> | | ![][y]          |           |
| Class member | ![][y]      | ![][y]   | ![][y]    |         |        |                   | ![][y]    | ![][y]
| Constructor  | ![][y]      |          |           |         |        |                   |           |
| Function     | ![][y]      | ![][y]   | ![][y]    |         |        |                   | ![][y]    | ![][y]
| Generic      | ![][y]      | ![][y]   | ![][y]    |         | ![][y] |                   |           |
| Instance     | ![][y]      |          |           |         |        |                   |           |
| Macro        | ![][y]      | ![][y]   | ![][y]    | ![][y]<sup>2</sup> | |               |           |
| Module       | ![][y]      |          |           |         |        |                   |           |
| Record field | ![][y]      |          |           |         |        |                   |           |
| Type         | ![][y]      |          |           |         | ![][y] | ![][y], for type synonyms |   |

<sup>1: only for shorthand classes like `class zero a :: a`, where there is no
other place for the documentation of the class member.</sup>  
<sup>2: for simple macros (depending on what the type deriver in
`Clean.Types.CoclTransform` can do), Cloogle will derive the type if it is not
given.</sup>

| Field             | Description
|-------------------|-------------
| `@complexity`     | E.g. "O(n log n)".
| `@param`          | Parameters of a function(-like). Name a parameter using `@param name: description`.
| `@representation` | The representation of a synonym type.
| `@result`         | The result of a function.
| `@return`         | A deprecated synonym of `@result`.
| `@throws`         | iTasks exceptions that can be thrown.
| `@type`           | The type of a macro (without name and `::`).
| `@var`            | Type variables of types, classes and generics.

### Property documentation

With [clean-test-properties][]' `testproperties` tool, [Gast][] test programs
can be generated with properties from docblocks. For this, several additional
fields can be used, which are further documented by [clean-test-properties][].

Our [standards](STANDARDS.md) require the use of tabs for indentation and spaces
for outlining. Because with properties code is included in documentation blocks,
using tabs for indentation would lead to tabs after spaces. To avoid this, we
use four spaces in this context instead. For example:

```clean
/**
 * @property correctness: A.xs :: Set a:
 *     minList (toList xs) == findMin xs
 */
```

[clean-test-properties]: https://gitlab.com/clean-and-itasks/clean-test-properties
[Gast]: https://gitlab.com/clean-and-itasks/gast

[y]: http://i.stack.imgur.com/iro5J.png
