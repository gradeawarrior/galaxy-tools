#!/usr/bin/perl -w

use strict;

my $console = $1;
my $revision = $2;
my $roll_cmd = "for i in `galaxy -c $console -s taken show | awk '{print $1}'`; do galaxy -i $i show; galaxy -i $i update $revision --relaxed-versioning; galaxy -i $i start; sleep 5; done";
