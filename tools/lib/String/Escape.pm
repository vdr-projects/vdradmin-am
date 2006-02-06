### String::Escape - Backslash escaping, word splitting, and elision functions

### Copyright 2002 Matthew Simon Cavalletto.
  # You may use this software under the same terms as Perl.

########################################################################

package String::Escape;

require 5;
use strict;
use Carp;
use Exporter;

use vars qw( $VERSION @ISA @EXPORT_OK );
$VERSION = 2002.001;

push @ISA, qw( Exporter );
push @EXPORT_OK, qw( 
  escape 
  printable unprintable 
  elide 
  quote unquote quote_non_words qprintable unqprintable
  string2list string2hash list2string list2hash hash2string hash2list
);

########################################################################

### Call by-name interface

# %Escapes - escaper function references by name
use vars qw( %Escapes );
%Escapes = (
  %Escapes,
  'none' =>        sub ($) { $_[0]; },
  
  'uppercase' =>   sub ($) { uc $_[0] },
  'lowercase' =>   sub ($) { lc $_[0] },
  'initialcase' => sub ($) { ucfirst lc $_[0] },
  
  'quote' => \&quote,
  'unquote' => \&unquote,
  'quote_non_words' => \&quote_non_words,
  
  'printable' => \&printable,
  'unprintable' => \&unprintable,
  
  'qprintable' => 'printable quote_non_words',
  'unqprintable' => 'unquote unprintable',
  
  'elide' => \&elide,
);

# String::Escape::add( $name, $subroutine );
sub add ($$) { $Escapes{ shift(@_) } = shift(@_); }

# @defined_names = String::Escape::names();
sub names () { keys(%Escapes); }

# $escaped = escape($escape_spec, $value); 
# @escaped = escape($escape_spec, @values);
sub escape ($@) {
  my ($escape_spec, @values) = @_;
  
  croak "escape called with multiple values but in scalar context"
      if ($#values > 0 && ! wantarray);
  
  my @escapes = expand_escape_spec($escape_spec);
  # warn "Escaping: ". join(' ', @escapes) . "\n";
  my ($value, $escaper);
  foreach $value ( @values ) {
    foreach $escaper ( @escapes ) {
      $value = &$escaper( $value );
    }
  }
  
  return wantarray ? @values : $values[0];
}

# @escape_functions = expand_escape_spec($escape_spec);
sub expand_escape_spec {
  my $escape_spec = shift;
  
  if ( ref($escape_spec) eq 'CODE' ) {
    return $escape_spec;
  } elsif ( ref($escape_spec) eq 'ARRAY' ) {
    return map { expand_escape_spec($_) } @$escape_spec;
  } elsif ( ! ref($escape_spec) ) {
    return map { 
      expand_escape_spec($_) 
    } map { 
      $Escapes{$_} or croak "unsupported escape specification '$_'; " . 
			    "should be one of " . join(', ', names())
    } split(/\s+/, $escape_spec);
  } else {
    croak "unsupported escape specification '$escape_spec'";
  }
}

########################################################################

### Double Quoting

# $with_surrounding_quotes = quote( $string_value );
sub quote ($) { '"' . $_[0] . '"' }

# $remove_surrounding_quotes = quote( $string_value );
sub unquote ($) { local $_ = $_[0]; s/\A\"(.*)\"\Z/$1/s; $_; }

# $word_or_phrase_with_surrounding_quotes = quote( $string_value );
sub quote_non_words ($) {
  ( ! length $_[0] or $_[0] =~ /[^\w\_\-\/\.\:\#]/ ) ? '"'.$_[0].'"' : $_[0]
}

### Backslash Escaping

use vars qw( %Printable %Unprintable );
%Printable = ( ( map { chr($_), unpack('H2', chr($_)) } (0..255) ),
	      "\\"=>'\\', "\r"=>'r', "\n"=>'n', "\t"=>'t', "\""=>'"' );
%Unprintable = ( reverse %Printable );

# $special_characters_escaped = printable( $source_string );
sub printable ($) {
  local $_ = ( defined $_[0] ? $_[0] : '' );
  s/([\r\n\t\"\\\x00-\x1f\x7F-\xFF])/\\$Printable{$1}/sg;
  return $_;
}

# $original_string = unprintable( $special_characters_escaped );
sub unprintable ($) {
  local $_ = ( defined $_[0] ? $_[0] : '' );
  s/((?:\A|\G|[^\\]))\\([rRnNtT\"\\]|[\da-fA-F]{2})/$1.$Unprintable{lc($2)}/gse;
  return $_;
}

# quoted_and_escaped = qprintable( $source_string );
sub qprintable ($) { quote_non_words printable $_[0] }

# $original_string = unqprintable( quoted_and_escaped );
sub unqprintable ($) { unprintable unquote $_[0] }

########################################################################

### Elision

use vars qw( $Elipses $DefaultLength $DefaultStrictness );
$Elipses = '...';
$DefaultLength = 60;
$DefaultStrictness = 10;

# $elided_string = elide($string);
# $elided_string = elide($string, $length);
# $elided_string = elide($string, $length, $word_boundary_strictness);
  # Return a single-quoted, shortened version of the string, with ellipsis
sub elide ($;$$) {
  my $source = shift;
  my $length = scalar(@_) ? shift() : $DefaultLength;
  my $word_limit = scalar(@_) ? shift() : $DefaultStrictness;
  
  # If the source is already short, we don't need to do anything
  return $source if (length($source) < $length);
  
  # Leave room for the elipses and make sure we include at least one character.
  $length -= length( $Elipses );
  $length = 1 if ( $length < 1 );
  
  my $excerpt;
  
  # Try matching $length characters or less at a word boundary.
  $excerpt = ( $source =~ /^(.{0,$length})(?:\s|\Z)/ )[0] if ( $word_limit );
  
  # Ignore boundaries if that fails or returns much less than we wanted.
  $excerpt = substr($source, 0, $length) if ( ! defined $excerpt or 
  	length($excerpt) < length($source) and
	! length($excerpt) || abs($length - length($excerpt)) > $word_limit);
  
  return $excerpt . $Elipses;
}

########################################################################

# @words = string2list( $space_separated_phrases );
sub string2list {
  my $text = shift;
  
  carp "string2list called with a non-text argument, '$text'" if (ref $text);
  
  my @words;
  my $word = '';
  
  while ( defined $text and length $text ) {
    if ($text =~ s/\A(?: ([^\"\s\\]+) | \\(.) )//mx) {
      $word .= $1;
    } elsif ($text =~ s/\A"((?:[^\"\\]|\\.)*)"//mx) {
      $word .= $1;
    } elsif ($text =~ s/\A\s+//m){
      push(@words, unprintable($word));
      $word = '';
    } elsif ($text =~ s/\A"//) {
      carp "string2list found an unmatched quote at '$text'"; 
      return;
    } else {
      carp "string2list parse exception at '$text'";
      return;
    }
  }
  push(@words, unprintable($word));
  
  return @words;
}

# $space_sparated_string = list2string( @words );
sub list2string {
  join ( ' ', map qprintable($_), @_ );
}

# %hash = list2hash( @words );
sub list2hash {
  my @pairs;
  foreach (@_) { 
    my ($key, $val) = m/\A(.*?)(?:\=(.*))?\Z/s;
    push @pairs, $key, $val;
  }  
  return @pairs;
}

# @words = hash2list( %hash );
sub hash2list {
  my @words;
  while ( scalar @_ ) { 
    my ($key, $value) = ( shift, shift );
    push @words, qprintable($key) . '=' . qprintable($value) 
  }
  return @words;
}

# %hash = string2hash( $string );
sub string2hash {
  return list2hash( string2list( shift ) );
}

# $string = hash2string( %hash );
sub hash2string {
  join ( ' ', hash2list( @_ ) );
}

########################################################################

1;

__END__

=pod

=head1 NAME

String::Escape - Registry of string functions, including backslash escapes


=head1 SYNOPSIS

  use String::Escape qw( printable unprintable );
  # Convert control, high-bit chars to \n or \xxx escapes
  $output = printable($value);
  # Convert escape sequences back to original chars
  $value = unprintable($input);
  
  use String::Escape qw( elide );
  # Shorten strings to fit, if necessary
  foreach (@_) { print elide( $_, 79 ) . "\n"; } 
  
  use String::Escape qw( string2list list2string );
  # Pack and unpack simple lists by quoting each item
  $list = list2string( @list );
  @list = string2list( $list );
  
  use String::Escape qw( string2hash hash2string );
  # Pack and unpack simple hashes by quoting each item
  $hash = hash2string( %hash );
  %hash = string2hash( $hash );
  
  use String::Escape qw( escape );
  # Defer selection of escaping routines until runtime
  $escape_name = $use_quotes ? 'qprintable' : 'printable';
  @escaped = escape($escape_name, @values);


=head1 DESCRIPTION

This module provides a flexible calling interface to some frequently-performed string conversion functions, including applying and removing C/Unix-style backslash escapes like \n and \t, wrapping and removing double-quotes, and truncating to fit within a desired length.

Furthermore, the escape() function provides for dynamic selection of operations by using a package hash variable to map escape specification strings to the functions which implement them. The lookup imposes a bit of a performance penalty, but allows for some useful late-binding behaviour. Compound specifications (ex. 'quoted uppercase') are expanded to a list of functions to be applied in order. Other modules may also register their functions here for later general use. (See the "CALLING BY NAME" section below for more.)


=head1 FUNCTION REFERENCE

=head2 Escaping And Unescaping Functions

Each of these functions takes a single simple scalar argument and 
returns its escaped (or unescaped) equivalent.

=over 4

=item quote($value) : $escaped

Add double quote characters to each end of the string.

=item quote_non_words($value) : $escaped

As above, but only quotes empty, punctuated, and multiword values; simple values consisting of alphanumerics without special characters are not quoted.

=item unquote($value) : $escaped

If the string both begins and ends with double quote characters, they are removed, otherwise the string is returned unchanged.

=item printable($value) : $escaped

=item unprintable($value) : $escaped

These functions convert return, newline, tab, backslash and unprintable 
characters to their backslash-escaped equivalents and back again.

=item qprintable($value) : $escaped

=item unqprintable($value) : $escaped

The qprintable function applies printable escaping and then wraps the results 
with quote_non_words, while unqprintable applies  unquote and then unprintable. 
(Note that this is I<not> MIME quoted-printable encoding.)

=back

=head2 Simple Arrays and Hashes

=over 4

=item @words = string2list( $space_separated_phrases );

Converts a space separated string of words and quoted phrases to an array;

=item $space_sparated_string = list2string( @words );

Joins an array of strings into a space separated string of words and quoted phrases;

=item %hash = string2hash( $string );

Converts a space separated string of equal-sign-associated key=value pairs into a simple hash.

=item $string = hash2string( %hash );

Converts a simple hash into a space separated string of equal-sign-associated key=value pairs.

=item %hash = list2hash( @words );

Converts an array of equal-sign-associated key=value strings into a simple hash.

=item @words = hash2list( %hash );

Converts a hash to an array of equal-sign-associated key=value strings.

=back

=head2 String Elision Function

This function extracts the leading portion of a provided string and appends ellipsis if it's longer than the desired maximum excerpt length.

=over 4

=item elide($string) : $elided_string

=item elide($string, $length) : $elided_string

=item elide($string, $length, $word_boundary_strictness) : $elided_string

If the original string is shorter than $length, it is returned unchanged. At most $length characters are returned; if called with a single argument, $length defaults to $DefaultLength. 

Up to $word_boundary_strictness additional characters may be ommited in order to make the elided portion end on a word boundary; you can pass 0 to ignore word boundaries. If not provided, $word_boundary_strictness defaults to $DefaultStrictness.

=item $Elipses

The string of characters used to indicate the end of the excerpt. Initialized to '...'.

=item $DefaultLength

The default target excerpt length, used when the elide function is called with a single argument. Initialized to 60.

=item $DefaultStrictness

The default word-boundary flexibility, used when the elide function is called without the third argument. Initialized to 10.

=back

=head1 CALLING BY NAME

These functions provide for the registration of string-escape specification 
names and corresponding functions, and then allow the invocation of one or 
several of these functions on one or several source string values.

=over 4

=item escape($escapes, $value) : $escaped_value

=item escape($escapes, @values) : @escaped_values

Returns an altered copy of the provided values by looking up the escapes string in a registry of string-modification functions.

If called in a scalar context, operates on the single value passed in; if 
called in a list contact, operates identically on each of the provided values. 

Valid escape specifications are:

=over 4

=item one of the keys defined in %Escapes

The coresponding specification will be looked up and used.

=item a sequence of names separated by whitespace,

Each name will be looked up, and each of the associated functions will be applied successively, from left to right.

=item a reference to a function

The provided function will be called on with each value in turn.

=item a reference to an array

Each item in the array will be expanded as provided above.

=back

A fatal error will be generated if you pass an unsupported escape specification, or if the function is called with multiple values in a scalar context. 

=item String::Escape::names() : @defined_escapes

Returns a list of defined escape specification strings.

=item String::Escape::add( $escape_name, \&escape_function );

Add a new escape specification and corresponding function.

=item %Escapes : $name, $operation, ...

By default, the %Escapes hash is initialized to contain the following mappings:

=over 4

=item quote, unquote, or quote_non_words

=item printable, unprintable, qprintable, or unqprintable, 

=item elide

Run the above-described functions of the same names.  

=item uppercase, lowercase, or initialcase

Alters the case of letters in the string to upper or lower case, or for initialcase, sets the first letter to upper case and all others to lower.

=item none

Return an unchanged copy of the original value.

=back

=back


=head1 EXAMPLES

Here are a few example uses of these functions, along with their output.

=head2 Backslash Escaping

C<print printable( "\tNow is the time\nfor all good folks\n" );>

  \tNow is the time\nfor all good folks\n

C<print unprintable( '\\tNow is the time\\nfor all good folks\\n' );>

	  Now is the time
  for all good folks
   


=head2 Escape By Name

C<print escape('qprintable', "\tNow is the time\nfor all good folks\n" );>

  "\tNow is the time\nfor all good folks\n"

C<print escape('uppercase qprintable', "\tNow is the time\nfor all good folks\n" );>

  "\tNOW IS THE TIME\nFOR ALL GOOD FOLKS\n"


C<print join '--', escape('printable', "\tNow is the time\n", "for all good folks\n" );>

  \tNow is the time\n--for all good folks\n


=head2 String Elision Function

C<$string = 'foo bar baz this that the other';>

C<print elide( $string, 100 );>

  foo bar baz this that the other


C<print elide( $string, 12 );>

  foo bar...


C<print elide( $string, 12, 0 );>

  foo bar b...


=head2 Simple Arrays and Hashes

C<print list2string('hello', 'I move next march');>

  hello "I move next march"


C<@list = string2list('one "second item" 3 "four\nlines\nof\ntext"');>

C<print $list[1];>

  second item


C<print hash2string( 'foo' =E<gt> 'Animal Cities', 'bar' =E<gt> 'Cheap' );>

  foo="Animal Cities" bar=Cheap


C<%hash = string2hash('key=value "undefined key" words="the cat in the hat"');>

C<print $hash{'words'};>

  the cat in the hat

C<print exists $hash{'undefined_key'} and ! defined $hash{'undefined_key'};>

  1


=head1 PREREQUISITES AND INSTALLATION

This package should run on any standard Perl 5 installation.

To install this package, download and unpack the distribution archive from
http://www.evoscript.com/dist/ or your favorite CPAN mirror, and execute
the standard "perl Makefile.PL", "make test", "make install" sequence.


=head1 STATUS AND SUPPORT

This release of String::Escape is intended for public review and feedback. 
It has been tested in several environments and no major problems have been 
discovered, but it should be considered "beta" pending that feedback.

  Name            DSLI  Description
  --------------  ----  ---------------------------------------------
  String::
  ::Escape        bdpf  Registry of useful string escaping functions

Further information and support for this module is available at E<lt>www.evoscript.orgE<gt>.

Please report bugs or other problems to C<E<lt>simonm@cavalletto.orgE<gt>>.

The following changes are in progress or under consideration:

=over 4

=item *

Use word-boundary test in elide's regular expression rather than \s|\Z.

=item *

Check for possible problems in the use of printable escaping functions and list2hash. For example, are the encoded strings for hashes with high-bit characters in their keys properly unquoted and unescaped?

=item *

Update string2list; among other things, embedded quotes (eg: a@"!a) shouldn't cause phrase breaks.

=back


=head1 SEE ALSO

Numerous modules provide collections of string manipulation functions; see L<String::Edit> for an example.

The string2list function is similar to to the quotewords function in the standard distribution; see L<Text::ParseWords>.

Use other packages to stringify more complex data structures; see L<Data::PropertyList>, L<Data::Dumper>, or other similar package.


=head1 CREDITS AND COPYRIGHT

=head2 Developed By

  M. Simon Cavalletto, simonm@cavalletto.org
  Evolution Softworks, www.evoscript.org

=head2 Contributors 

  Eleanor J. Evans piglet@piglet.org
  Jeremy G. Bishop 

=head2 Copyright

Copyright 2002 Matthew Simon Cavalletto. 

Portions copyright 1996, 1997, 1998, 2001 Evolution Online Systems, Inc.

=head2 License

You may use, modify, and distribute this software under the same terms as Perl.

=cut
