package begin;

# Make sure we have version info for this module
# Be strict from now on

$VERSION = '0.02';
use strict;

# The flag to take all =begin CAPITALS pod sections

my $ALL;

# Get the necessary modules

use IO::File ();

# Use a source filter for the initial script
# Status as returned by source filter
# Flag: whether we're inside a =begin section being activated

use Filter::Util::Call ();
my $STATUS;
my $INSIDE;

# Install an @INC handler that
# Obtains the parameters (defining $path on the fly)
# For all of the directories to checl
#  If we have a reference
#   Let that handle the require if we're not it

unshift( @INC,sub {
    my ($ref,$filename,$path) = @_;
    foreach (@INC) {
        if (ref) {
            goto &$_ unless $_ eq $ref;

#  Elseif the file exists
#   Attempts to open the file and reloops if failed
#   Attempt to open a temporary file or dies if failed

        } elsif (-f ($path = "$_/$filename")) {
            open( my $in,$path ) or next;
            my $out = IO::File->new_tmpfile
             or die "Failed to create temporry file for '$path': $!\n";

#   Make sure we have our own $_
#   While there are lines to be read
#    If we're inside an active sequence
#     Checks if we're at the end and adapts and resets flag if so
#    Else
#     Checks if we're at the beginning and adapts and sets flag if so
#    Write the line to the temporary file
#   Close the input file
#   Make sure the action section flag is reset

            local $_;
            while (<$in>) {
                if ($INSIDE) {
                    $INSIDE = !s#^=cut#}#;
                } else {
                    s#^=begin\s+([A-Z_0-9]+)#
                     ($INSIDE = $ALL || $ENV{$1}) ? "{" : "=begin $1"#e;
                }
                print $out $_;
            }
            close $in;
            $INSIDE = undef;

#   Make sure we'll read from the original file again
#   And return that handle

            $out->seek( 0,0 ) or die "Failed to seek: $!\n";
            return $out;
        }
    }

# Return nothing to indicate that the rest should be searched (which will fail)

    return;
} );

# Satisfy require

1;

#---------------------------------------------------------------------------
#  IN: 1 class (ignored)object (not used)
#      2..N keys to watch for

sub import {

# Warn if we're being called from source (unless it's from the test-suite)

    warn "The '".
          __PACKAGE__.
          "' pragma is not supposed to be called from source\n"
           if ((caller)[2]) and ($_[0] ne '_testing_' and !shift);

# Lose the class
# Initialize the ignored list
# Loop for all parameters
#  If it is the "all" flag
#   Set the all flag
#  Elsif it is all uppercase
#   Set the environment variable
#  Else
#   Add to ignored list
# List any ignored parameters

    shift;
    my @ignored;
    foreach (@_) {
        if (m#^:?all$#) {
            $ALL = 1;
        } elsif (/^[A-Z_0-9]+$/) {
            $ENV{$_} = 1;
        } else {
            push @ignored,$_;
        }
    }
    warn "Ignored parameters: @ignored\n" if @ignored;

# Add a filter for the caller script which
#  If there is a line
#   If we're inside an active sequence
#    Checks if we're at the end and adapts and resets flag if so
#   Else
#    Checks if we're at the beginning and adapts and sets flag if so
#  Returns the status

    Filter::Util::Call::filter_add( sub {
        if (($STATUS = Filter::Util::Call::filter_read()) > 0) {
            if ($INSIDE) {
                $INSIDE = !s#^=cut*#}#;
            } else {
                s#^=begin\s+([A-Z_0-9]+)#
                 ($INSIDE = $ALL || $ENV{$1}) ? '{' : "=begin $1"#e;
            }
        }
        $STATUS;
    } );
} #import

#---------------------------------------------------------------------------

__END__

=head1 NAME

begin - conditionally enable code within =begin pod sections

=head1 SYNOPSIS

  export DEBUGGING=1
  perl -Mbegin yourscript.pl

 or:

  perl -Mbegin=VERBOSE yourscript.pl

 or:

  perl -Mbegin=all yourscript.pl

 with:

  ======= yourscript.pl ================================================

  # code that's always compiled and executed

  =begin DEBUGGING

  warn "Only compiled and executed when DEBUGGING or 'all' enabled\n"

  =cut

  # code that's always compiled and executed

  =begin VERBOSE

  warn "Only compiled and executed when VERBOSE or 'all' enabled\n"

  =cut

  # code that's always compiled and executed

  ======================================================================

=head1 DESCRIPTION

The "begin" pragma allows a developer to add sections of code that will be
compiled and executed only when the "begin" pragma is specifically enabled.
If the "begin" pragma is not enabled, then there is B<no> overhead involved
in either compilation of execution (other than the standard overhead of Perl
skipping =pod sections).

To prevent interference with other pod handlers, the name of the pod handler
B<must> be in uppercase.

If a =begin pod section is considered for replacement, then a scope is
created around that pod section so that there is no interference with any
of the code around it.  For example:

 my $foo = 2;

 =begin DEBUGGING

 my $foo = 1;
 warn "debug foo = $foo\n";

 =cut

 warn "normal foo = $foo\n";

is converted on the fly (before Perl compiles it) to:

 my $foo = 2;

 {

 my $foo = 1;
 warn "foo = $foo\n";

 }

 warn "normal foo = $foo\n";

But of course, this happens B<only> if the "begin" pragma is loaded B<and>
the environment variable B<DEBUGGING> is set.

=head1 WHY?

One day, I finally had enough of always putting in and taking out debug
statements from modules I was developing.  I figured there had to be a
better way to do this.  Now, this module allows to leave debugging code
inside your programs and only have them come alive when I<you> want them
to be alive.  I<Without any run-time penalties when you're in production>.

=head1 REQUIRED MODULES

 Filter::Util::Call (any)
 IO::File (any)

=head1 IMPLEMENTATION

This version is completely written in Perl.  It uses a source filter to
provide its magic to the script being run B<and> an @INC handler for all
of the modules that are loaded otherwise.  Because the =begin pod directive is
ignored by Perl during normal compilation, the source filter is B<not> needed
for production use so there will be B<no> performance penalty in that case.

=head1 CAVEATS

=head2 Overhead during development

Because the "begin" pragma uses a source filter for the invoked script, and
an @INC handler for all further required files, there is an inherent overhead
for compiling Perl source code.  Not loading begin.pm at all, causes the normal
=begin pod ignoring functionality of Perl to come in place (without any added
overhead).

=head2 No nesting allowed

Out of performance reasons, the filters are kept as simple as possible.
This is done by keeping only a single flag to mark whether the filter is
inside a =begin section with code to be activated.  For this reason, no nesting
of =begin sections are supported.  And there is also no check for it, so if
you _do_ do this, then you'd better know what you're doing.

=head2 No changing of environment variables during execution

Since the "begin" pragma performs all of this magic at compile time, it
generally does not make sense to change the values of applicable environment
variables at execution, as there will be no compiled code available to
activate.

=head2 Modules that use AutoLoader, SelfLoader, load, etc.

For the moment, these modules bypass the mechanism of this module.  An
interface with load.pm is on the TODO list.  Patches for other autoloading
modules are welcomed.

=head1 AUTHOR

Elizabeth Mattijsen, <liz@dijkmat.nl>.

Please report bugs to <perlbugs@dijkmat.nl>.

=head1 COPYRIGHT

Copyright (c) 2004 Elizabeth Mattijsen <liz@dijkmat.nl>. All rights
reserved.  This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
