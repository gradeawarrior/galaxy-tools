#!/usr/bin/perl -w

use strict;
use LWP::Simple;

# Variables
my $manifest;
my $console='';
my $galaxy_path='galaxy';
my $time = localtime;
my %new_builds;
my %old_builds;
my %galaxified_unknown_cores;
my $new = 0;
my $old = 0;
my $release_rev;
my $manifest_rev;
my $use_gepo_file=1;
my $url = "http://gepo.ningops.net/manifests";

#############################################
################## Setup ####################
#############################################

my $argc = @ARGV; # Save the number of commandline parameters.
if ($argc < 2)
{
  usage();  # Call subroutine usage()
  exit();   # When usage() has completed execution,
            # exit the program.
} else {
  my $arg = shift;

  while ($arg) {
	if ($arg =~ "-c") {
		$console=shift;
	}
	elsif ($arg =~ "-g") {
		$manifest=shift;
	}
	elsif ($arg =~ "-f") {
		$manifest=shift;
		$use_gepo_file=0;
	} else {
		print "[ERROR] Unknown param '$arg'\n\n";
		usage();
		exit();
	}
	
	$arg = shift;
  }
}

# Check if Console is set
if ($console eq "") {
  if ($ENV{'GALAXY_CONSOLE'}) {
	$console=$ENV{'GALAXY_CONSOLE'};
  } else {
	print "[ERROR] - console was not set\n\n";
  	usage();  # Call subroutine usage()
  	exit();   # When usage() has completed execution,
            	  # exit the program.
  }
}


# Retrieve manifest from gepo and split into array separated by lines
my @manifest_out = split(m|\n|, getManifest($manifest, $use_gepo_file));

# Check that there was data, otherwise return usage()
if (@manifest_out < 1) {
	print "[ERROR] Undefined manifest file '$manifest'\n\n";
	usage();
	exit();
}

# Read Manifest
#($release_rev, $manifest_rev, %new_builds, %old_builds) = readManifest(@manifest_out);
readManifest(@manifest_out);

# Print Debug Information
print <<EOF;
- console=$console
- manifest=$manifest
- last_runtime=$time
- manifest_revision=$manifest_rev
- core_revision=$release_rev
- gepo_url=$url
- use_manifest_from_gepo=$use_gepo_file
=================

EOF


#############################################
########### New Cores Check #################
#############################################


# Iterate through cores
my $passfail = 1;

print "NEW CORES\n=========\n";
foreach my $key(keys %new_builds) {
	my $console_grep = `$galaxy_path -c $console -t $key.* show | grep $key | grep -v dummy`;

	# Split the line
	my @console_lines = split(/\n/, $console_grep);
	if (@console_lines < 1 and $console_grep !~ m/No hosts matching/) {
		print ">> Cannot find any cores for $key\n";
		next;
	}

	# Loop through console results
	foreach my $line (@console_lines) {
		my @line = split(/\s+/, $line);
		
		# Check if zone build is equal to the manifest build
		if ($line[3] eq $new_builds{$key}) {
			#print "PASS - type: $key\t$line[3] == $new_builds{$key}\n";
		} else {
			# If fail, then check if the core type is defined by another manifest type
			if (checkIfPathDefined($key, $line[1], $line[3])) {
				#print "[WOOHOO]\ttype: $key\tpath: $line[1]\t$line[0]\tPRODUCTION BUILD: $line[3]\tMANIFEST: $new_builds{$key}\n";
			} else {
				print "[FAIL]\ttype: $key\tpath: $line[1]\t$line[0]\tPRODUCTION BUILD: $line[3]\tMANIFEST: $new_builds{$key}\n";
				$passfail = 0;
			}
		}
	}

	# Only print PASS if all cores of specified type $key passes
	if ($passfail) {
		print "[PASS] $key\t$new_builds{$key}\n";
	} else {
		$passfail = 1;
	}
}


#############################################
########### Old Cores Check #################
#############################################


# Iterate through cores
$passfail = 1;

print "\nOLD CORES\n=========\n";
foreach my $key(keys %old_builds) {
	my $console_grep = `$galaxy_path -c $console -t $key.* show | grep $key | grep -v dummy`;

	# Split the line
	my @console_lines = split(/\n/, $console_grep);
	if (@console_lines < 1 and $console_grep !~ m/No hosts matching/) {
		print ">> Cannot find any cores for $key\n";
		next;
	}

	# Loop through console results
	foreach my $line (@console_lines) {
		my @line = split(/\s+/, $line);
		
		# Check if zone build is equal to the manifest build
		if ($line[3] eq $old_builds{$key}) {
			#print "PASS - type: $key\t$line[3] == $old_builds{$key}\n";
		} else {
			# If fail, then check if the core type is defined by another manifest type
			if (checkIfPathDefined($key, $line[1], $line[3])) {
				#print "[WOOHOO]\ttype: $key\tpath: $line[1]\t$line[0]\tPRODUCTION BUILD: $line[3]\tMANIFEST: $old_builds{$key}\n";
			} else {
				print "[FAIL]\ttype: $key\tpath: $line[1]\t$line[0]\tPRODUCTION BUILD: $line[3]\tMANIFEST: $old_builds{$key}\n";
				$passfail = 0;
			}
		}
	}

	# Only print PASS if all cores of specified type $key passes
	if ($passfail) {
		print "[PASS] $key\t$old_builds{$key}\n";
	} else {
		$passfail = 1;
	}
}


#############################################
######### Galaxified Unknown Check ##########
#############################################


getUnknownCoreTypes();

print <<EOF;

GALAXIFIED UNKNOWN
==================
EOF
foreach my $key(keys %galaxified_unknown_cores) {
	my $path = $galaxified_unknown_cores{$key}{'path'};
	my $build = $galaxified_unknown_cores{$key}{'build'};
	print qq|type: $key\tpath: $path\tbuild: $build\n|;
}


#************************************
#********* Sub-routines *************
#************************************
	
sub usage {
	print <<EOF;
Usage: 
	compareEnvironmentToManifest [-c console] -f manifest_file
	compareEnvironmentToManifest [-c console] -g manifest_file

Examples:
	./compareEnvironmentToManifest.pl -f manifest/CORE-846.manifest
	./compareEnvironmentToManifest.pl -g CORE-846.manifest

Details:
	console		the galaxy console (i.e. gonsole.xnc.ningops.net)
	manifest_file	the manifest file created by release engineer.
			See the manifest list below for arguments you can use
			for the '-g' option, which will pull the manifest from
			$url . Otherwise, you should use the '-f' option to 
			specify the manifest file found locally on the machine.

Gepo Manifest List:
EOF

	my @manifest_list = getManifests();
	foreach (@manifest_list) {
		print "\t- $_\n";
	}
}

sub checkIfPathDefined {
	my $key = shift;
	my $path = shift;
	my $build = shift;

	# Get subpath 
	my $subpath = getSubPath($path);

	# Check if the subpath is defined in the list of types
	if (($key ne $subpath) and (exists $new_builds{ $subpath })) {
		1;
	} elsif (($key ne $subpath) and (exists $old_builds{ $subpath })) {
		1;
	} else {
		0;
	}
}

sub getSubPath {
	my $path = shift;

	# Get index of third slash
	# e.g. /alpha/6.15.2/grim
	my $index_third_slash= index($path, "/", (index($path, "/", 1)+1));
	
	# Get subpath 
	my $subpath = substr($path, $index_third_slash+1, length($path)-$index_third_slash);

	$subpath;
}

sub readManifest {
	my $throwable_var=1;

	# Read Manifest
	foreach (@_) {
		# Strip newline characters
		chomp($_);

		# Set control variables if in either new or old section of the manifest file
		if ($_ =~ "##new") {
			$new = 1;
			$old = 0;
			next;
		}
		elsif ($_ =~ "##old") {
			$new = 0;
			$old = 1;
			next;
		}

		# Retrieve Revision information
		if ($_ =~ "common_properties.tag") {
			$release_rev = (split(/=/,$_))[1];
		}
		elsif ($_ =~ "core=" and $throwable_var) {
			$manifest_rev = (split(/=/,$_))[1];
			$throwable_var = 0;
		}
	
		# Retrieve path and binary revision from manifest
		# and store them in a hash
		if ($new) {
			my $path = (split(/=/,$_))[0];
			my $binary = (split(/@/,$_))[1];
			$new_builds{$path} = $binary;

			#print "new - \$path:'$path'\t\$binary:'$new_builds{$path}'\n";
		}
		if ($old) {
			my $path = (split(/=/,$_))[0];
			my $binary = (split(/@/,$_))[1];
			$old_builds{$path} = $binary;

			#print "old - \$path:'$path'\t\$binary:'$old_builds{$path}'\n";
		}
	}

	#($release_rev, $manifest_rev, %new_builds, %old_builds);
}

sub getManifest {
	my $manifest = shift;
	my $use_gepo_file = shift;
	my $content;
	
	if ($use_gepo_file) {		# Retrieve manifest from gepo
		$content = get("$url/$manifest");
	} else {			# Retrieve manifest from specified file
		$content = `cat $manifest`;
	}

	# Return contents of manifest file
	$content;
}

sub getUnknownCoreTypes {
	my $console_output = `$galaxy_path -c $console -s t show | grep -v dummy`;
	my @console_lines = split(/\n/, $console_output);
	my $found;

	# iterate through each zone and check if they're defined in manifest
	foreach my $line(@console_lines) {
		my @line = split(/\s+/, $line);
		my $subpath = getSubPath($line[1]);
		$found = 0;

		if ((exists $new_builds{ $subpath }) or (exists $old_builds{ $subpath })) {
			$found = 1;
		} else {
			foreach my $key (keys %new_builds) {
				if ($line[1] =~ $key) {
					$found = 1;
					last;
				}
			}
			
			if ($found == 0) {
				foreach my $key (keys %old_builds) {
					if ($line[1] =~ $key) {
						$found = 1;
						last;
					}
				}
			}
		}
		
	
		if ($found == 0) {
			$galaxified_unknown_cores{ $subpath } = {
									path => $line[1],
									build => $line[3]
								};
		}
	}
}

sub getManifests {
	my $content = get($url);
	my @manifests = $content =~ m|\">(.*?manifest)<|g;

	@manifests;
}
