require 5.006;

use strict;
use ExtUtils::MakeMaker;
eval "use Devel::Required";

WriteMakefile (
 NAME		=> "begin",
 AUTHOR		=> 'Elizabeth Mattijsen (liz@dijkmat.nl)',
 ABSTRACT	=> 'conditionally enable code within =begin pod sections',
 VERSION_FROM	=> 'lib/begin.pm',

 PREREQ_PM	=> {qw(
		    IO::File		0
		    Filter::Util::Call	0
                   )},
);
