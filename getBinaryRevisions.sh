#*****************************
#********** Functions ********
#*****************************


printUsage() {
  cat <<EOF
Usage: getBinaryRevisions [console] core_affected_file
	console			the location of the galaxy console (i.e. gonsole.xna.ningops.net)
	cores_affected_file	the file (located at current dir) that lists the core types in the release
EOF
}


#*****************************
#************ Main ***********
#*****************************

# Check that there are at least 2 parameters
if (test $# -lt 1)
then
	printUsage;
	exit;
elif (test $# -eq 1)
then
	if [ $GALAXY_CONSOLE = "" ]
	then
		echo "GALAXY_CONSOLE is not set on this environment";
		printUsage;
		exit;
	fi
	
	console=$GALAXY_CONSOLE;
	file=$1;
elif (test $# -eq 2)
then
	console=$1;
	file=$2;
else
	printUsage;
	exit;
fi

for i in `cat $file`
do
        echo "------ $i -----";

        # Loop #2 - Loop through build revisions
        for k in `galaxy -c $console -t $i show | awk '{print $4}' | sort | uniq`
        do
                # Used by Loop #2 - echoing build numbers
                echo "build=$k";
        done
done
