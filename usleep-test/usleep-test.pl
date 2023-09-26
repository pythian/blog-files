#!/usr/bin/env perl

use strict;
use warnings;
use Time::HiRes qw(usleep);


=head1 use with strace

 strace -T -ttt -f -o usleep-test.strace ./usleep-test.pl

 Process the strace with this one liner

 Over 100% is the amount of time greater than what was requested.


 RedHat based (Oracle 7)
 usleep-test.strace

 grep --color=never -E 'nanosleep\(' usleep-test.strace | tr -d '[[:punct:]]' | awk '{ print $4, $7 }' | perl -e 'chomp; while(<>){ ($asked,$got) = split(/\s+/);  print qq{asked: $asked  got: $got  error: } . sprintf(q{%3.2f},$got/($asked/1000)*100) .qq{\n} }'

 Debian based (Linux Mint 20)
 usleep-test-02.strace
 
 grep --color=never -E 'nanosleep\(' usleep-test-02.strace | tr '=' ' ' | tr -d '[[:punct:]]' | awk '{ print $8, $11 }' | perl -e 'chomp; while(<>){ ($asked,$got) = split(/\s+/);  print qq{asked: $asked  got: $got  error: } . sprintf(q{%3.2f},$got/($asked/1000)*100) .qq{\n} }'


the last number is the % of the asked for amount

eg. asked for 100ms (100000000 ns in the trace) got 0114970, which is 114.97% of the asked for amount

 ...
 asked: 92000000  got: 0113484  error: 123.35
 asked: 93000000  got: 0105980  error: 113.96
 asked: 94000000  got: 0094119  error: 100.13
 asked: 95000000  got: 0095129  error: 100.14
 asked: 96000000  got: 0096116  error: 100.12
 asked: 97000000  got: 0097142  error: 100.15
 asked: 98000000  got: 0098113  error: 100.12
 asked: 99000000  got: 0099132  error: 100.13
 asked: 100000000  got: 0114970  error: 114.97





=cut


# test sleep at ms level
# use with strace

for (my $i=1; $i <= 100; $i++) {
	usleep($i * 1000);
}

