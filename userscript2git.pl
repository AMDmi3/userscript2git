#!/usr/bin/perl
#
# Fetches script from userscripts.org with whole history and
# converts it to git repo
#
# Copyright (C) 2011 Dmitry Marakasov
#
# This script is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#

use strict;
use v5.10;
use LWP::Simple;
use Date::Parse;

my $USERSCRIPTS = "http://userscripts.org";

die "Usage: $0 <script id> <path to repo>" unless ($#ARGV == 1);

my $id = $ARGV[0];
my $path = $ARGV[1];

die 'Script id should be numeric' unless ($id =~ /^\d+$/);

say 'Will turn userscript '.$id.' into git repo in the current directory';
say 'Creating git repository...';
die "Cannot init git repository at $path" unless (system("git init $path") == 0);

say 'Fetching revisions list...';
my $revisions_list = get("$USERSCRIPTS/scripts/versions/$id") || die 'Cannot fetch revisions list';
chdir($path) || die 'Cannot chdir into repository';

my @revisions;
while ($revisions_list =~ /<li>\s*(.*?)\s*\[\s*<a href="(\/scripts\/version\/$id\/\d+.user.js)">install<\/a>/gm) {
	my $timestamp = $1;
	my $path = $2;

	$timestamp =~ s/[^\w ,:]//g;

	push @revisions, [ $timestamp, $path ];
}

die 'No revisions found' unless ($#revisions >= 0);
say 'Found '.($#revisions+1).' revisions';

my $initial = 1;
foreach my $rev (reverse @revisions) {
	say 'Fetching revision ('.$rev->[0].')';

	my $timestamp = str2time($rev->[0]);
	my $code = get("$USERSCRIPTS/$rev->[1]") || die 'Cannot fetch script revision';
	open (CODE, ">user.js") || die 'Cannot open user.js';
	print CODE $code;
	close(CODE);

	my $message = $rev->[0];
	if ($initial) {
		die 'cannot execute git add' unless (system("git add user.js") == 0);
		$message = "Initial commit";
		$initial = 0;
	}
	die 'cannot execute git commit' unless (system("git commit -m \"$message\" --date=\"$timestamp\" user.js") == 0);
}

say "You can now run `cd $path && git rebase -i HEAD~$#revisions` to edit commits and commit messages";
