#!/usr/bin/perl -w

use strict;


#***********************************
#******* Enviroment Variables ******
#***********************************


my @basic = ("cacc/core/stor.*",
	"cacc/core/prox.*",
	"cacc/aclu/stor.*",
	"cacc/aclu/prox.*",
	"adcc.*",
	"appc.*",
	"sysc.*",
	"filx",
	"dav",
	"rocc.*",
	"rslv.*",
	"proc.*",
	"prtz.*",
	"borc.*"
   );


#***********************************
#******* Retrieve Arguments ********
#***********************************

my $argument;
my $console;
my $type;
my $num_cores_started = 0;
my $argc = @ARGV; # Save the number of command-line args

if ($argc > 0) {
  $argument=shift;
    
  while ($argument) {
	if ($argument eq "all") {			# Set the startup type to all cores
  		$type="all";
	} elsif ($argument eq "basic") {		# Set the startup type to basic
		$type="basic";
	} elsif ($argument eq "-c") {			# The galaxy console server
		$console = shift;
	} elsif ($argument =~ /--help/ or $argument =~ /-help/) {		# Print usage if --help is passed
		usage();
		exit();
	} else {					# Throw exception if unknown parameter
		print "[ERROR] - Unknown argument '$argument'\n\n";
		usage();
		exit();
	}

	$argument=shift;
  } # End while loop
} # End condition
else { # Require that user enter at least 1 argument
	usage();
	exit();
}


#***********************************
#*** Check Required Arguments ******
#***********************************


if (!$console) {
	if ($ENV{'GALAXY_CONSOLE'}) {
		$console=$ENV{'GALAXY_CONSOLE'};
	} else {
		print "[ERROR] - console was not set\n\n";
		usage();
		exit();
	}
}

if (!$type) {
	$type = 'all';
}


#***********************************
#*************** Main **************
#***********************************


my $galaxy_out;
my @galaxy_out;
my $sleep;

foreach my $path(@basic) {
	$sleep = 0;
	$galaxy_out = `galaxy -c $console -t $path show | grep -v dead | grep -v running`;
	@galaxy_out = split(/\n/,$galaxy_out);

	print "\n--- Starting $path ---\n";

	foreach my $out(@galaxy_out) {
		# Split line up
		print "$out\n";
		my ($zone, $path, $status, $binary, $type, $gzone, $ip) = split(/\s+/,$out);

		galaxy_start_i($console, $zone);
		$num_cores_started++;
	}

	if (@galaxy_out > 0) {
		if ($path =~ m/cacc/) {
			$sleep = 30;
		} 
		elsif ($path =~ m/adcc/) {
			$sleep = 40;
		}
		elsif ($path =~ m/rocc/) {
			$sleep = 20;
		}
	}

	# Sleep for $sleep seconds
	print "\n>> Sleeping for $sleep seconds\n";
	sleep $sleep;
}

if ($type eq 'all') {
	if ($num_cores_started >= 1) {
		print "\n>> Sleeping for 10 seconds\n";
		sleep 10;
	}

	$galaxy_out = `galaxy -c $console -s t show | grep -v dead | grep -v running`;
	@galaxy_out = split(/\n/,$galaxy_out);

	foreach my $out(@galaxy_out) {
		# Split line up
		my ($zone, $path, $status, $binary, $type, $gzone, $ip) = split(/\s+/,$out);

		print "\n--- Restarting $zone\t$path\t$status\t$type ---\n";
		#print "$out\n";

		galaxy_start_i($console, $zone);
		$num_cores_started++;
	}
}


#************************************
#********* Sub-routines *************
#************************************


sub usage {
	print <<EOF;
Usage: startEnv [-c console] all|basic
    -c console		Galaxy console URL

    all			Will start the entire environment taking into account the order
			and sleeps necessary to start the cache

    basic		Starts only the necessary cores to test bazel and www pages. This
			should typically be followed by passing 'all' to start the rest
			of the environment. The following cores are started with the basic
			argument set:

				- cacc
				- adcc
				- appc
				- sysc
				- filx
				- dav
				- rocc
				- rslv
				- proc
				- prtz
				- borc

    --help		Display this usage message
EOF
}

sub galaxy_start_t {
	my $console = shift;
	my $path = shift;
	my $cmd = "galaxy -c $console -t $path start";

	#print "> $cmd\n";
	system($cmd);
}

sub galaxy_start_i {
	my $console = shift;
	my $zone = shift;
	my $cmd = "galaxy -c $console -i $zone start";

	print "> $cmd\n";
	system($cmd);
}
