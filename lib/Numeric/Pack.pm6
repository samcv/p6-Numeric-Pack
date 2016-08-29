use v6;
unit module Numeric::Pack;

=begin pod

=head1 NAME

Numeric::Pack - Convert perl6 numerics to buffers and back again!

=head1 SYNOPSIS

  use Numeric::Pack :ALL;

  # pack and unpack floats
  my Buf $float-buf = pack-float-rat 2.5;
  say "{ $float-buf.perl } -> { unpack-float $float-buf }";

  # pack and unpack doubles
  my Buf $double-buf = pack-double-rat 2.5;
  say "{ $double-buf.perl } -> { unpack-double $double-buf }";

  # pack and unpack Int (see also int64 varients)
  my Buf $int-buf = pack-int32 11;
  say "{ $int-buf.perl } -> { unpack-int32 $int-buf }";

  # pack and unpack specific byte orders (big-endian is the default)
  my Buf $little-endian-buf = pack-int32 11, :endianness(little-endian);
  say "{ $little-endian-buf.perl } -> {
    unpack-int32 $little-endian-buf, :endianness(little-endian)
  }";


=head1 DESCRIPTION

Numeric::Pack is a Perl6 module for packing values of the Numeric role into Buf objects.
Currently there are no core language mechanisms for packing the majority of Numeric types into Bufs.
Both the experimental pack language feature and the PackUnpack module do not yet impliment packing to and from floating-point represetnations,
A feature used by many modules in the Perl5 pack and unpack routines.
Numeric::Pack fills this gap in functionality via a packaged native library and a corosponding NativeCall interface.
Useing a native library to pack Numeric types avoids many pitfalls of implimenting a pure perl solution and provides better performance.

Numeric::Pack exports the enum Endianness by default (Endianness is experted as :MANDATORY).

=begin table
        Endianness       | Desc.
        ===============================================================
        native-endian    | The native byte ordering of the current system
        little-endian    | Common byte ordering of contemporary CPUs
        big-endian       | Also known as network byte order
=end table

By default Numeric::Pack's pack and unpack functions return and accept big-endian Bufs.
To override this provide the :endianness named parameter with the enum value for your desired behaviour.
To disable byte order management pass :endianness(native-endian).

Use Numeric::Pack :ALL to export all exportable fucntionality.

Use :floats or :ints flags to export subsets of the module's functionality.
=begin table
        :floats              | :ints
        ===============================
        pack-float-rat    | pack-int32
        unpack-float      | unpack-int32
        pack-double-rat   | pack-int64
        unpack-double     | unpack-int64
=end table


=head1 AUTHOR

Sam Gillespie <samgwise@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2016 Sam Gillespie

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=head1 FUNCTIONS
=end pod

use NativeCall;
use LibraryMake;

# Find our compiled library.
sub libnumpack {
    my $so = get-vars('')<SO>;
    return ~(%?RESOURCES{"libnumpack$so"});
}

#= The Endianness enum is exported by default.
#= Use native-endian, little-endian and big-endian to specify the byte orderings.
#= For pack functions the :endianness parameter specifies the byte order of the output
#= For unpack functions :endianness specifies the byte order of the input buffer
#= While heard there are other endian behaviours about, little and big are the most common.
enum Endianness is export(:MANDATORY) ( native-endian => 0, little-endian => 1, big-endian => 2 );

#
# Native calls and wrappers:
#

### 4 byte types:

# void pack_rat_to_float(int32_t n, int32_t d, char *bytes)
sub pack_rat_to_float(int32, int32, CArray[uint8]) is native(&libnumpack) { * }

sub pack-float-rat(Rat(Cool) $rat, Endianness :$endianness = big-endian) returns Buf is export(:floats)
#= Pack a Rat into a single-precision floating-point Buf (e.g. float).
#= Exported via tag :floats.
#= Be aware that Rats and floats are not directly anaolgous storage schemes and
#=  as such you should expect some variation in the values packed via this method and the orginal value.
{
  my $bytes = CArray[uint8].new;
  $bytes[3] = 0; #make room for 4 bytes
  pack_rat_to_float $rat.numerator, $rat.denominator, $bytes;
  byte-array-to-buf($bytes, 4, :$endianness);
}

# float unpack_bits_to_float(char *bytes)
sub unpack_bits_to_float(CArray[uint8]) returns num32 is native(&libnumpack) { * }

sub unpack-float(Buf $float-buf, Endianness :$endianness = big-endian) returns Numeric is export(:floats)
#= Unpack a Buf containing a single-precision floating-point number (float) into a Numeric.
#= Exported via tag :floats.
{
  die "Unable to unpack buffer: expected 4 bytes but recieved { $float-buf.elems }" unless $float-buf.elems == 4;
  unpack_bits_to_float(buf-to-byte-array $float-buf, :$endianness);
}

# void pack_int32(int32_t i, char *bytes)
sub pack_int32(int32, CArray[uint8]) is native(&libnumpack) { * }

sub pack-int32(Int(Cool) $int, Endianness :$endianness = big-endian) returns Buf is export(:ints)
#= Pack an Int to an 4 byte intger buffer
#= Exported via tag :ints.
#= Be aware that the behaviour of Int values outside the range of a signed 32bit integer
#= [−2,147,483,648 to 2,147,483,647]
#= is undefined.
{
  my $bytes = CArray[uint8].new;
  $bytes[3] = 0; #make room for 4 bytes
  pack_int32 $int, $bytes;
  byte-array-to-buf($bytes, 4, :$endianness);
}

# int32_t unpack_int32(char *bytes)
sub unpack_int32(CArray[uint8]) returns int32 is native(&libnumpack) { * }

sub unpack-int32(Buf $int-buf, Endianness :$endianness = big-endian) returns Int is export(:ints)
#= Exported via tag :ints.
{
  die "Unable to unpack buffer: expected 4 bytes but recieved { $int-buf.elems }" unless $int-buf.elems == 4;
  unpack_int32 buf-to-byte-array $int-buf, :$endianness;
}

### 8 byte types:

# void pack_rat_to_double(int64_t n, int64_t d, char *bytes)
sub pack_rat_to_double(int64, int64, CArray[uint8]) returns int64 is native(&libnumpack) { * }

sub pack-double-rat(Rat(Cool) $rat, Endianness :$endianness = big-endian) returns Buf is export(:floats)
#= Pack a Rat into a double-precision floating-point Buf (e.g. double).
#= Exported via tag :floats.
#= Be aware that Rats and doubles are not directly anaolgous storage schemes and
#=  as such you should expect some variation in the values packed via this method and the orginal value.
{
  my $bytes = CArray[uint8].new;
  $bytes[7] = 0; #make room for 8 bytes
  pack_rat_to_double $rat.numerator, $rat.denominator, $bytes;
  byte-array-to-buf($bytes, 8, :$endianness);
}

# double unpack_bits_to_double(char *bytes)
sub unpack_bits_to_double(CArray[uint8]) returns num64 is native(&libnumpack) { * }

sub unpack-double(Buf $double-buf, Endianness :$endianness = big-endian) returns Numeric is export((:floats))
#= Unpack a Buf containing a single-precision floating-point number (float) into a Numeric.
#= Exported via tag :floats.
{
  die "Unable to unpack buffer: expected 8 bytes but recieved { $double-buf.elems }" unless $double-buf.elems == 8;
  unpack_bits_to_double(buf-to-byte-array $double-buf, :$endianness);
}

# void pack_int64(int64_t i, char *bytes)
sub pack_int64(int64, CArray[uint8]) is native(&libnumpack) { * }

sub pack-int64(Int(Cool) $int, Endianness :$endianness = big-endian) returns Buf is export(:ints)
#= Pack an Int to an 8 byte integer buffer
#= Exported via tag :ints.
#= Be aware that the behaviour of Int values outside the range of a signed 64bit integer
#= [−9,223,372,036,854,775,808 to 9,223,372,036,854,775,807]
#= is undefined.
{
  my $bytes = CArray[uint8].new;
  $bytes[7] = 0; #make room for 8 bytes
  pack_int64 $int, $bytes;
  byte-array-to-buf($bytes, 8, :$endianness);
}

# int64_t unpack_int64(char *bytes)
sub unpack_int64(CArray[uint8]) returns int64 is native(&libnumpack) { * }

sub unpack-int64(Buf $int-buf, Endianness :$endianness = big-endian) returns Int is export(:ints)
#= Exported via tag :ints.
{
  die "Unable to unpack buffer: expected 8 bytes but recieved { $int-buf.elems }" unless $int-buf.elems == 8;
  unpack_int64 buf-to-byte-array $int-buf, :$endianness;
}


#
# Utils:
#
# Keep these here as they depend on the Endianness enum
#  which must also be exported up to any code using this module

sub native-endianness() returns Endianness {
  # Get a native to break the int into bytes and observe which endian order they use
  given pack-int32(0b00000001, :endianness(native-endian))[0] {
    when 0b00000000 {
      return big-endian;
    }
    when 0b00000001 {
      return little-endian;
    }
    default {
      die "Unable to determine local endianness!";
    }
  }
}

sub byte-array-to-buf(CArray[uint8] $bytes, Int $size, Endianness :$endianness = native-endian) returns Buf {
  given $endianness {
    when little-endian {
      return Buf.new($bytes[0..($size - 1)]) if native-endianness() eqv little-endian;
      # else return a reversed byte order to convert big to little
      return Buf.new($bytes[0..($size - 1)].reverse);
    }
    when big-endian {
      return Buf.new($bytes[0..($size - 1)]) if native-endianness() eqv big-endian;
      # else return a reversed byte order to convert little to big
      return Buf.new($bytes[0..($size - 1)].reverse);
    }
    default {
      # default to return native endianness
      return Buf.new($bytes[0..($size - 1)])
    }
  }
}

sub buf-to-byte-array(Buf $buf, Endianness :$endianness = native-endian) returns CArray[uint8] {
  my $bytes = CArray[uint8].new;
  my $end = $buf.elems - 1;

  given $endianness {
    when little-endian {
      if native-endianness() eqv little-endian {
        $buf[0..$end].kv.reverse.map( -> $k, $v { $bytes[$k] = $v } );
      }
      else {
        # else a reversed byte order to convert big to little
        $buf[0..$end].kv.map( -> $k, $v { $bytes[$end - $k] = $v } );
      }
      return $bytes;
    }
    when big-endian {
      if native-endianness() eqv big-endian {
        $buf[0..$end].kv.reverse.map( -> $k, $v { $bytes[$k] = $v } );
      }
      else {
        # else a reversed byte order to convert big to little
        $buf[0..$end].kv.map( -> $k, $v { $bytes[$end - $k] = $v } );
      }
      return $bytes;
    }
    default {
      # default to return native endianness
      $buf[0..$end].kv.reverse.map( -> $k, $v { $bytes[$k] = $v } );
      return $bytes;
    }
  }
}