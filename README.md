[![Actions Status](https://github.com/raku-community-modules/PrettyDump/actions/workflows/linux.yml/badge.svg)](https://github.com/raku-community-modules/PrettyDump/actions) [![Actions Status](https://github.com/raku-community-modules/PrettyDump/actions/workflows/macos.yml/badge.svg)](https://github.com/raku-community-modules/PrettyDump/actions) [![Actions Status](https://github.com/raku-community-modules/PrettyDump/actions/workflows/windows.yml/badge.svg)](https://github.com/raku-community-modules/PrettyDump/actions)

NAME
====

PrettyDump - represent a Raku data structure in a human readable way

SYNOPSIS
========

Use it in the OO fashion:

```raku
use PrettyDump;
my $pretty = PrettyDump.new: :after-opening-brace;

my $raku = { a => 1 };
say $pretty.dump: $raku; # '{:a(1)}'
```

Or, use its subroutine:

```raku
use PrettyDump;

my $ds = { a => 1 };

say pretty-dump( $ds );

# setting named arguments
say pretty-dump( $ds, :indent<\t>);
```

Or, a shorter shortcut that dumps and outputs to standard output:

```raku
use PrettyDump;

my $ds = { a => 1 };
pd $ds;
```

DESCRIPTION
===========

This module creates nicely formatted representations of your data structure for your viewing pleasure. It does not create valid Raku code and is not a serialization tool.

When `.dump` encounters an object in your data structure, it first checks for a `.PrettyDump` method. It that exists, it uses it to stringify that object. Otherwise, `.dump` looks for internal methods. So far, this module handles these types internally:

  * List

  * Array

  * Pair

  * Map

  * Hash

  * Match

Custom dump methods
-------------------

If you define a `.PrettyDump` method in your class, `.dump` will call that when it encounters an object in that class. The first argument to `.PrettyDump` is the dumper object, so you have access to some things in that class:

```raku
class Butterfly {
    has $.genus;
    has $.species;

    method PrettyDump ( PrettyDump $pretty, Int:D :$depth = 0 ) {
        "_{$.genus} {$.species}_";
    }
}
```

The second argument is the level of indentation so far. If you want to dump other objects that your object contains, you should call `.dump` again and pass it the value of `$depth+1` as it's second argument:

```raku
class Butterfly {
    has $.genus;
    has $.species;
    has $.some-other-object;

    method PrettyDump ( PrettyDump $pretty, Int:D :$depth = 0 ) {
        "_{$.genus} {$.species}_" ~
        $pretty.dump: $some-other-object, $depth + 1;
    }
}
```

You can add a `PrettyDump` method to an object with `but role`:

```raku
use PrettyDump;

my $pretty = PrettyDump.new;

my Int $a = 137;
put $pretty.dump: $a;

my $b = $a but role {
    method PrettyDump ( PrettyDump:D $pretty, Int:D :$depth = 0 ) {
        "({self.^name}) {self}";
    }
}
put $pretty.dump: $b;
```

This outputs:

    137
    (Int+{<anon|140644552324304>}) 137

Per-object dump handlers
------------------------

You can add custom handlers to your `PrettyDump` object. Once added, the object will try to use a handler first. This means that you can override builtin methods.

```raku
$pretty = PrettyDump.new: ... ;
$pretty.add-handler: "SomeTypeNameStr", $code-thingy;
```

The code signature for `$code-thingy` must be:

```raku
(PrettyDump $pretty, $ds, Int:D :$depth = 0 --> Str)
```

Once you are done with the per-object handler, you can remove it:

```raku
$pretty.remove-handler: "SomeTypeNameStr";
```

This allows you to temporarily override a builtin method. You might want to mute a particular object, for instance.

You can completely ignore a type as if it's not even there. It's a wrapper around g that supplies the code for you.

```raku
$pretty.ignore-type: SomeType;
```

This works by returning a `Str` type object instead of a defined string. If the type you want to exclude is at the top of the data structure, you'll get back a type object. But why are you dumpng something you want to ignore?

Formatting and Configuration
----------------------------

You can set some tidy-like settings to control how `.dump` will present the data stucture:

  * debug

Output debugging info to watch the module walk the data structure.

  * indent

The default is a tab.

  * intra-group-spacing

The spacing inserted inside (empty) `${}` and `$[]` constructs. The default is the empty string.

  * pre-item-spacing

The spacing inserted just after the opening brace or bracket of non-empty `${}` and `$[]` constructs. The default is a newline.

  * post-item-spacing

The spacing inserted just before the close brace or bracket of non-empty `${}` and `$[]` constructs. The default is a newline.

  * pre-separator-spacing

The spacing inserted just before the comma separator of non-empty `${}` and `$[]` constructs. The default is the empty string.

  * post-separator-spacing

The spacing inserted just after the comma separator of non-empty `${}` and `$[]` constructs. Defaults to a newline.

AUTHORS
=======

  * brian d foy

  * Raku Community

This module started as `Pretty::Printer` from Jeff Goff.

Parts of this module were supported by a grant from TPRF.

COPYRIGHT
=========

Copyright © 2017-2021, brian d foy

Copyright © 2024 Raku Community

LICENSE
=======

This module is available under the Artistic License 2.0. A copy of this license should have come with this distribution in the LICENSE file.

