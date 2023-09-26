#!/usr/bin/env perl


use warnings;
use strict;

eval {
	print "press ENTER to continue\n";

	alarm(2);
	$SIG{ALRM} = sub { die "timed out waiting for user\n"; };
	my $release = <STDIN>;

};

alarm(0);

print "leaving now\n";



