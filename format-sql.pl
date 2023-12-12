#!/usr/bin/env perl

use warnings;
use strict;
use Data::Dumper;
#use IO::File;

#my $fh=IO::File->new;
#$fh->open('j2','<');
#my $t = <$fh>;
#chomp $t;

my $t = <STDIN>;

$t =~ s/"//g;

my $indentLevel=0;
my $indentCharacter=chr(9);
my ($pass1Sql, $pass2Sql, $pass3Sql) = ('','','');

for ( my $i=0; $i < length($t); $i++ ) {

	my $currentCharacter = substr($t,$i,1);
	#print "$currentCharacter\n";

	if ($currentCharacter eq '(') {
		#print "\n" . $indentCharacter x $indentLevel . "(\n";
		$pass1Sql .= "\n" . $indentCharacter x $indentLevel . "(\n";
		$indentLevel += 1;
		next;
	} elsif ( $currentCharacter eq ')') {
		$indentLevel -= 1;
		#print "\n" . $indentCharacter x $indentLevel . ")\n";
		$pass1Sql .= "\n" . $indentCharacter x $indentLevel . ")\n";
		next;
	} else {
		;
	}

	#print "$currentCharacter";
	$pass1Sql .= $currentCharacter;
}


#print "pass 1:\n$pass1Sql\n";

my @parts = split(/\n/,$pass1Sql);

$indentLevel=0;
foreach my $part ( @parts ) {
	my $tmp = '';
	if (grep(/^\s*\(/,$part)) {
		$indentLevel += 1;
		$pass2Sql .= $part;
		#print $part;
		next;
	} elsif (grep(/^\s*\)/,$part)) {
		$indentLevel -= 1;
		$pass2Sql .= $part;
		#print $part;
		next;
	}

	$tmp = $part;
	my $indent = "\n" . $indentCharacter x $indentLevel;
	if ( $tmp =~ /\s+FROM/ ) {
		$tmp =~ s/(\s+)(FROM)(.*$)/$indent$2$3/;
	} elsif ( $tmp =~ /\s+WHERE/ ) {
		$tmp =~ s/(\s+)(WHERE)(.*$)/$indent$2$3/;
	}
	
	$pass2Sql .=  "\n" . $indentCharacter x $indentLevel . "$tmp\n";
	#print "\n" . $indentCharacter x $indentLevel . "$pass2Sql\n";
}

#print "$pass2Sql\n";

@parts = split(/\n/,$pass2Sql);

# fixup SELECT
my $closingParen=0;
my $parenIndent='';

foreach my $part ( @parts ) {

	if ( grep(/^\s*\)\s*$/,$part) ) {
		$closingParen = 1;
		$parenIndent = substr($part,0,index($part,')'));
		next;
	}


	if (grep(/^\s*SELECT/,$part) ) {
		my $indent = substr($part,0,index($part,'SELECT'));
		$part =~ s/^\s*SELECT\s+//;
		#warn "part2b: $part\n";

		my @lineParts = split(/,/,$part);

		print "${indent}SELECT\n";
		my $j = "\n$indent$indentCharacter,";
		print "${indent}${indentCharacter}" .  join($j, @lineParts) . "\n";
		next;
	}

	if ($closingParen) {
		$part =~ s/\s//g;
		print "${parenIndent}) $part\n";
		$closingParen = 0;
		next;
	}
	print "$part\n";
}


