class PrettyDump {
    has Str $.pre-item-spacing       = "\n";
    has Str $.post-item-spacing      = "\n";

    has Str $.pre-separator-spacing  = '';
    has Str $.intra-group-spacing    = '';
    has Str $.post-separator-spacing = "\n";

    has Str $.indent                 = "\t";
    has Bool $.debug                 = False;
    has Bool $.recompile             = False;

    has %!handlers                   = Hash.new;

    method !indent-string(Str:D $str, Int:D $depth) {
        $.indent eq '' || $depth == 0
          ?? $str
          !! $str.subst: /^^/, $.indent x $depth, :g
    }

    method Pair(Pair:D $ds, Int:D :$depth = 0 --> Str) {
        say "In Pair" if $.debug;
        my $key := $ds.key.Str;
        given $ds.value.^name {
            when "Bool" {
                $ds.value ?? ":$key" !! ":!$key"
            }
            when "NQPMu" { # I don't think I should ever see this, but I do
                ":$ds.key()(Mu)";
            }
            default {
                ":$key"
                  ~ '('
                  # depth is zero here because this part won't be indented
                  ~ self.dump($ds.value, :depth(0)).trim
                  ~ ')'
            }
        }
    }

    method Hash(
      Hash:D $ds,
      Str:D :$start = 'Hash={',
      Str:D :$end   = '}',
      Int:D :$depth = 0,
    --> Str) {
        say "In Hash" if $.debug;
        self!balanced: $ds.sort(*.key), $start, $end, $depth
    }

    method Array(
      Array:D $ds,
      Str:D  :$start = 'Array=[',
      Str:D  :$end   = ']',
      Int:D  :$depth = 0
    --> Str) {
        say "In Array" if $.debug;
        self!balanced: $ds, $start, $end, $depth
    }

    method List(
      List:D $ds,
      Str:D :$start = 'List=(',
      Str:D :$end   = ')',
      Int:D :$depth = 0
    --> Str) {
        say "In List" if $.debug;
        self!balanced: $ds, $start, $end, $depth
    }

    method !balanced($ds, $start, $end, $depth) {
        $start ~ self!structure($ds, $depth) ~ $end
    }

    method Range(Range:D $ds, Int:D :$depth = 0 --> Str) {
        say "In Range" if $.debug;
        $ds.min
          ~ ($ds.excludes-min ?? '^' !! '')
          ~ '..'
          ~ ($ds.excludes-max ?? '^' !! '')
          ~ ($ds.infinite ?? '*' !! $ds.max)
    }

    method !structure(@ds, Int:D $depth) {
        say "In structure" if $.debug;
        if @ds {
            $.pre-item-spacing
              ~ @ds.map({
                    my $dumped := self.dump($_, :depth($depth + 1));
                    $dumped if $dumped ~~ Str:D
                }).join("$.pre-separator-spacing,$.post-separator-spacing")
              ~ $.post-item-spacing
        }
        else {
            $.intra-group-spacing
        }
    }

    method Map(Map:D $ds, Int:D :$depth = 0 --> Str) {
        say "In Map" if $.debug;
        "$ds.^name()=(" ~ self!structure($ds.sort(*.key), $depth) ~ ')'
    }

    method Match (
      Match:D $ds,
      Int:D  :$depth = 0,
      Str:D  :$start = 'Match=(',
      Str:D  :$end   = ')',
    --> Str) {
        say "In match" if $.debug;
        my %hash =
          made => $ds.made,
          to   => $ds.to,
          from => $ds.from,
          orig => $ds.orig,
          hash => $ds.hash,
          list => $ds.list,
          pos  => $ds.pos,
        ;

        $start ~ self!structure(%hash.sort(*.key), $depth) ~ $end
    }

    method !numeric(Numeric:D $_, Int:D $depth) {
        when FatRat { "<$_.numerator()/$_.denominator()>" }
        when Rat    { "<$_.numerator()/$_.denominator()>" }
        default     { .Str }
    }


    method Str   ( Str:D $ds --> Str) { $ds.raku }
    method Nil   ( Nil   $ds --> Str) { q/Nil/   }
    method Any   ( Any   $ds --> Str) { q/Any/   }
    method Mu    ( Mu    $ds --> Str) { q/Mu/    }
    method NQPMu (       $ds --> Str) { q/Mu/    }

    multi method ignore-type(Any:U $type) { self.ignore-type: $type.^name }
    multi method ignore-type(Str:D $type-name) {
        self.add-handler:
          $type-name,
          -> PrettyDump $pretty, $ds, Int:D :$depth = 0 --> Str { Str:U }
    }

    multi method add-handler(Str:D $type-name, Code:D $code) {
        my $sig        := $code.signature;
        my $needed-sig := :(PrettyDump $pretty, $ds, Int:D :$depth = 0 --> Str);

        unless $sig ~~ any $needed-sig {
            fail X::AdHoc.new:
              payload => "Signature should be:\n\t:$needed-sig.gist()\nbut got\n\t:$sig.gist()";
        }

        %!handlers{$type-name} = $code;
    }
    multi method add-handler(Any:U $type, Code:D $code) {
        self.add-handler: $type.^name, $code;
    }

    multi method create-handler(Str:D $type-name, Code:D $code --> Code) {
        -> :(PrettyDump $pretty, $ds, Int:D :$depth = 0 --> Str) {
            $code( $pretty, $ds, $depth )
        }
    }
    multi method create-handler(Any:U $type, Code:D $code --> Code) {
        self.create-handler: $type.^name, $code
    }

    multi method remove-handler(Str:D $type-name) {
        %!handlers{$type-name}:delete:exists
    }
    multi method remove-handler(Any:U $type) {
        %!handlers{$type.^name}:delete:exists
    }

    multi method handles(Str:D $type-name --> Bool) {
        %!handlers{$type-name}:exists
    }
    multi method handles(Any:U $type --> Bool) {
        %!handlers{$type.^name}:exists
    }

    method !handle($ds, Int:D :$depth = 0) {
        # fail if it doesn't exist
        my $handler := %!handlers{$ds.^name};
        $handler(self, $ds, :$depth)
    }

    method dump($ds, Int:D :$depth = 0 --> Str) {
        # If the PrettyDump object has a user-defined handler
        # for this type, prefer that one
        my $str := do if self.handles: $ds.^name {
            self!handle: $ds, :$depth
        }

        # The object might have its own method to dump its structure
        elsif $ds.can: 'PrettyDump' {
            $ds.PrettyDump: self, :$depth
        }

        # If it's any sort of Numeric, we'll handle it and dispatch
        # further
        elsif $ds ~~ Numeric:D {
            self!numeric: $ds, $depth
        }

        # If we have a method name that matches the class, we'll
        # use that.
        elsif self.can: $ds.^name {
            self."$ds.^name()"($ds, :$depth)
        }

        # If the class inherits from something that we know
        # about, use the most specific one that we know about
        elsif self.can: any($ds.^parents.map: *.^name) {
            for $ds.^parents.map: *.^name -> $type {
                return self."$type"( $ds,
                  :start("{$ds.^name}=("),
                  :end(  ')'),
                  :depth($depth)
                ) if self.can: $type;
            }
            ''
        }

        # If we're this far and the object has a .Str method,
        # we'll use that:
        elsif $ds.can: 'Str' {
            "($ds.^name()): $ds"
        }

        # Finally, we'll put a placeholder method there
        else {
            "(Unhandled $ds.^name())"
        }

        # we might return a type object
        $str.defined
          ?? self!indent-string: $str, $depth
          !! $str
    }
}

my sub pretty-dump($ds,
  :$pre-item-spacing       = "\n",
  :$post-item-spacing      = "\n",
  :$pre-separator-spacing  = '',
  :$intra-group-spacing    = '',
  :$post-separator-spacing = "\n",
  :$indent                 = "\t",
--> Str) is export {
    PrettyDump.new(
      :$indent,
      :$pre-item-spacing,
      :$post-item-spacing,
      :$pre-separator-spacing,
      :$intra-group-spacing,
      :$post-separator-spacing,
    ).dump: $ds
}

my constant &pd is export = &pretty-dump;

# vim: expandtab shiftwidth=4
