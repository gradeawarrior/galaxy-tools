#*****************************
#********** Functions ********
#*****************************


printUsage() {
  cat <<EOF
Usage: galaxyWrapper [-c console] [-r revision] -f cores_affeced_file -u update_type [-t list_of_cores] [-cmd command]

EXAMPLES:
	Print out all the cores on the environment (galaxy show operation):

		galaxyWrapper -f 6.17-cores -u info

	Roll all cores to 6.16.2

		galaxyWrapper -r 6.16.2 -f 6.17-cores -u rolling

	Rolling update the configuration files for all cores to 6.17

		galaxyWrapper -f 6.17-cores -u rolling -cmd update-config

	Update only the sysc and appc to 6.17

		galaxyWrapper -f 6.17-cores -u rolling -t sysc/www,appc
	
DETAILS:
	console			the location of the galaxy console. Alternatively, you can export
				GALAXY_CONSOLE.
	revision		the revision number to update to (i.e. 6.17)
	cores_affected_file	the file (located at current dir) that lists the core types in the release
	update_type		update		Update of all cores. A manual restart is required
				rolling		Rolling update of all cores with 30 second sleep
				info		Display information about all cores in release
	list_of_cores		A list of all cores that you want updated/rolling/info. By default this is
				set to 'ALL' which will update all cores affected in this release. If using
				this feature, the core you want to update must exist in the cores_affected_file,
				otherwise, nothing will happen.
	command			update (default for update_type=update/rolling)
				update-config - useful for configuration updates when doing update_type=update/rolling
				
EOF
}


#*****************************
#************ Main ***********
#*****************************

cores="ALL";

# Check that there are at least 4 parameters
if (test $# -lt 4)
then
	printUsage;
	exit;
else
	while [ "$1" != '' ]
	do
		case $1
		in
		-c)
			console=$2;
			shift 2;;
		-r)
			revision=$2;
			shift 2;;
		-f)
			file=$2;
			shift 2;;
		-u)
			update_type=$2;
			shift 2;;
		-t)
			cores=$2;
			shift 2;;
		-cmd)
			cmd=$2;
			shift 2;;
		*)
			echo "[ERROR] Uknown Parameter: '$1'";
			printUsage;
			exit;;
		esac
	done
fi

# Check if the console is set, otherwise, check if GALAXY_CONSOLE is set
if [ "$console" = "" ]
then
	if [ "$GALAXY_CONSOLE" = "" ]
	then
		echo "[ERROR] The console is not set.";
		printUsage;
		exit;
	else
		console=$GALAXY_CONSOLE;
	fi
fi

# Set the default $cmd if it is not specified by the user
if [ "$cmd" = "" ]
then
	case $update_type
	in
		rolling)		# Rolling will perform a galaxy update operation
			cmd="update";;
		update)			# Update will perform a galaxy update operation
			cmd="update";;
		info)			# Info will perform a galaxy show operation
			cmd="show";;
		*)
			echo "[ERROR] Unknown update_type='$update_type'";
			printUsage;
			exit;;
	esac
fi

# If the revision is not set, assume the first part of the file name
# Example: '6.17-cores' file will assume the revision as '6.17'
if [ "$revision" = "" ]
then
	revision="`echo $file | sed "s/[\/a-zA-Z]*\([0-9][0-9]*.[0-9][0-9]*.*[0-9]*\)-cores/\1/g"`";
fi

# Debug information
cat <<EOF
GALAXY_CONSOLE='$console'
revision='$revision'
cores_affected_file='$file'
update_type='$update_type'
cores='$cores'
cmd='$cmd'
=============

EOF

# Loop #1 - Loop through types
for i in `cat $file`
do
	# Check Whether to run ALL or only a subset of core types
	if [ "$cores" != "ALL" ]
	then
		test1=`echo $cores | grep -c $i`;
		#echo "count = $test1 : cores='$cores' : type='$i'";

		if (test $test1 -eq 0)
		then
			continue;
		fi
	fi

	echo "------ $i -----";

	# Loop #2 - Loop through zones
	for k in `galaxy -c $console -t $i show | awk '{print $1}'`
	do
		if [ "$update_type" = "info" ] # INFO type
		then
			galaxy -c $console -i $k $cmd;
			#galaxy -s t show | grep $k;
		elif [ "$update_type" = "rolling" ] # ROLLING type
		then
			echo ">> Updating $k";

			galaxy -c $console -i $k show;
			galaxy -c $console -i $k $cmd $revision --relaxed-versioning;

			# Check if restart or start command should be used
			if [ "$update_type" = "update-config" ]
			then
				galaxy -c $console -i $k restart;
			else
				galaxy -c $console -i $k start;
			fi
			echo ">> Sleeping 30 seconds";
			sleep 30;
		elif [ "$update_type" = "update" ] # UPDATE type
		then
			echo ">> Updating $k";

			galaxy -c $console -i $k show;
			galaxy -c $console -i $k $cmd $revision --relaxed-versioning;
		fi
	done; # End Loop #2
done # End Loop #1
