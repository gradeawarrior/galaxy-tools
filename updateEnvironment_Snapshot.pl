#!/usr/bin/perl -w

use strict;


#***********************************
#******* Enviroment Variables ******
#***********************************


my $argument;
my $rollback=0;
my $console="";
my $snapshot_file="";
my $argc = @ARGV; # Save the number of commandline parameters.


#***********************************
#******* Retrieve Arguments ********
#***********************************


if ($argc<1) {
  usage();  # Call subroutine usage()
  exit();   # When usage() has completed execution,
            # exit the program.
} else {
  $argument=shift;
    
  while ($argument) {
	if ($argument eq "-r") {			# Check if this is debug or rollback should be performed
  		$rollback=1;
	} elsif ($argument eq "-f") {			# The location of the manifest file
		$snapshot_file = shift;
	} elsif ($argument eq "-c") {			# The galaxy console server
		$console = shift;
	} elsif ($argument =~ /--help/) {		# Print usage if --help is passed
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


#***********************************
#*** Check Required Arguments ******
#***********************************


if ($console eq '') {
	if ($ENV{'GALAXY_CONSOLE'}) {
		$console=$ENV{'GALAXY_CONSOLE'};
	} else {
		print "[ERROR] - console was not set\n\n";
		usage();
		exit();
	}
} elsif ($snapshot_file eq '') {
	print "[ERROR] - missing snapshot file\n\n";
	usage();
	exit();
}


# Print command line arguments for debugging purposes
print <<EOF;
- console: '$console'
- file: '$snapshot_file'
- rollback: $rollback
----------------------

EOF


# console/snapshot hashes
my %console_out;
my %snapshot_out;

my $galaxy_output = `galaxy -c $console show`;
my @galaxy_output = split(/\n/,$galaxy_output);


#***********************************
#***** Iterate through Galaxy ******
#***********************************


# Retrieve Galaxy console variables
foreach my $out(@galaxy_output) {
	# Split line up
	my ($zone, $path, $status, $binary, $type, $gzone, $ip) = split(/\s+/,$out);

	# Store variables in hash of galaxy console
	$console_out{$zone} = {
		path => $path,
		status => $status,
		binary => $binary,
		type => $type,
		gzone => $gzone,
		ip => $ip
	};
	#print $console_out{$zone}{path}."\n";
}


#***********************************
#**** Iterate through Snapshot *****
#***********************************


# Retrieve snapshot variables
open FILE, "<$snapshot_file" or die $!;
while (<FILE>) {
	# Strip newline characters
	chomp($_);

	# Split line up
	my ($zone, $path, $status, $binary, $type, $gzone, $ip) = split(/\s+/,$_);

	# Store variables in hash of snapshot file
	$snapshot_out{$zone} = {
		path => $path,
		status => $status,
		binary => $binary,
		type => $type,
		gzone => $gzone,
		ip => $ip
	};
	#print $snapshot_out{$zone}{path}."\n";
}

close(FILE);

#***********************************
#******** Compare Environment ******
#***********************************

foreach my $key(keys %snapshot_out) {
	# Check if zone exists in both snapshot and console
	if (exists $console_out{$key}) {
		my $output = '';
		my $cpath = $console_out{$key}{path};
		my $spath = $snapshot_out{$key}{path};
		my $cbinary = $console_out{$key}{binary};
		my $sbinary = $snapshot_out{$key}{binary};
		my $cstatus = $console_out{$key}{status};
		my $sstatus = $snapshot_out{$key}{status};

		# Check if console path does not match the snapshot path
		if ($cpath ne $spath) {
			$output .= print_difference("path", $cpath, $spath);
		}

		# Check if output is not an empty string
		if (length $output > 0) {
			print "\n$key\n===================\n";
			print $output;

			# Check if snapshot path is not unassigned AND console path is not dead
			if ($spath ne '-' and $cstatus ne 'dead') {
				my ($rootpath, $branch, $subdir) = galaxy_assignment($spath);

				my $cmd = "galaxy -c $console -i $key assign $rootpath $branch $subdir";
				print "\$ $cmd\n";		# Print Command to execute

				if ($rollback) {
					system $cmd;		# Execute command if rollback is set
				}
			}
			# Check if we need to clear a zone
			else {
				my $cmd = "galaxy -c $console -i $key clear";
				print "\$ $cmd\n";		# Print Command to execute
				
				if ($rollback) {
					system $cmd;		# Execute command if rollback is set
				}
			}
		}
	} else {
		print "*** Error - $key does not exist in $snapshot_file!\n";
	}
}

print "\n***** DONE *****\n";
exit(0);


#************************************
#********* Sub-routines *************
#************************************
	
sub usage {
	print <<EOF;
Usage: updateEnvironment_Snapshot [-c console] -f snapshot_file [-r]
    -c console		Galaxy console URL
    -f snapshot_file	the file to compare against galaxy console
    -r			This needs to be passed to actually perform the rollback operation
    --help		Display this usage message
EOF
}

sub print_difference {
	"$_[0]:\t$_[1] => $_[2]\n";
}

sub galaxy_assignment {
	my $string = $_[0];

	# Get index of third slash
	my $index_third_slash= index($string, "/", (index($string, "/", 1)+1));
	
	# Get rootdirectory and branch
	# e.g. /alpha/6.15.2/grim --> $rootdir = alpha && $branch = 6.15.2
	my ($rootdir, $branch) = split(/\//, substr($string, 1, $index_third_slash+1));

	# Get subdirectory
	my $subdir = substr($string, $index_third_slash+1, length($string)-$index_third_slash);
	#print "$string - $rootdir - $branch - $subdir\n";
	($rootdir, $branch, $subdir);
}

sub printGalaxyCommand {
	my ($rootpath, $branch, $subdir) = galaxy_assignment($_[0]);
	print "galaxy -i $_[1] assign $rootpath $branch $subdir\n";
}
