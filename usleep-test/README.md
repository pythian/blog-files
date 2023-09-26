
strace -T -ttt -f -o usleep-test.strace ./usleep-test.pl

RedHat based (Oracle 7)
usleep-test.strace

grep --color=never -E 'nanosleep\(' usleep-test.strace | tr -d '[[:punct:]]' | awk '{ print $4, $7 }' | perl -e 'chomp; while(<>){ ($asked,$got) = split(/\s+/);  print qq{asked: $asked  got: $got  error: } . sprintf(q{%3.2f},$got/($asked/1000)*100) .qq{\n} }'

Debian based (Linux Mint 20)
usleep-test-02.strace


grep --color=never -E 'nanosleep\(' usleep-test-02.strace | tr '=' ' ' | tr -d '[[:punct:]]' | awk '{ print $8, $11 }' | perl -e 'chomp; while(<>){ ($asked,$got) = split(/\s+/);  print qq{asked: $asked  got: $got  error: } . sprintf(q{%3.2f},$got/($asked/1000)*100) .qq{\n} }'


