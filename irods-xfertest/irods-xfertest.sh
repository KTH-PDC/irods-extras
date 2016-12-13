# irAods-xfertest - do iRODS transfer (put and get) in a sequence and collect results 
# Author: Ilari Korhonen, KTH Royal Institute of Technology

#!/bin/sh

# set defaults
NUMRUNS=10
NUMTHREADS=64
DSTPATH=irods-xfertest.tmp
FILESIZE=256
FILEPATH=/tmp/irods-xfertest.tmp

export DYLD_LIBRARY_PATH=/Applications/iRODS.app/Contents/Frameworks

# function show_help - shows help
show_help() {
    echo "irods-xfertest - do iRODS transfer (put and get) in a sequence and collect results"
    echo "usage: $1 [-h] [-r runs] [-d dstpath] [-s filesize] [-n numthreads]"
}

# parse command line arguments POSIX style
OPTIND=1

while getopts "hc:t:r:d:i:o:" opt; do
    case "$opt" in
	h)
	    show_help
	    exit 0
	    ;;
	r)
	    NUMRUNS=$OPTARG
	    ;;
	d)
	    DBNAME=$OPTARG
	    ;;
	s)
	    FILESIZE=$OPTARG
	    ;;
	n)
	    NUMTHREADS=$OPTARG
	    ;;
    esac
done

# initialize counters
NUMFAILS=0
NUMSUCCESS=0

echo "$0: creating iRODS test collection $DSTPATH..."
imkdir $DSTPATH

if [ $? != "0" ]; then
    echo "$0: failed to create iRODS destination path, terminating..."
    exit
else
    echo "$0: success!"
fi

echo "$0: creating testfile $FILEPATH..."
dd if=/dev/zero of=$FILEPATH bs=1048576 count=$FILESIZE

if [ $? != "0" ]; then
    echo "$0: failed to create testfile at $FILEPATH, terminating..."
    exit
else
    echo "$0: success!"
fi

echo "$0: testing iRODS transfer to $DSTPATH with testfile $FILEPATH of size $FILESIZE MB"

for ((i=1; i <= $NUMRUNS; i++)); do 
    echo "$0: test run $i of $NUMRUNS..."

    echo "$0: iput of $FILEPATH to $DSTPATH with $NUMTHREADS..."
    iput -K -N $NUMTHREADS $FILEPATH $DSTPATH/irods-xfertest.tmp

    if [ $? != 0 ]; then
	echo "$0: put failed with $?, test run $i failed"
	continue
    fi

    echo "$0: iget ot $DSTPATH/irods-xfertest.tmp to $FILEPATH.2 with $NUMTHREADS..."
    iget -K -N $NUMTHREADS $DSTPATH/irods-xfertest.tmp $FILEPATH.2

    if [ $? != 0 ]; then
	echo "$0: get failed with $?, test run $i failed"
	continue
    fi

    echo "$0: diffing original $FILEPATH and $FILEPATH.2 from iRODS..."
    diff $FILEPATH $FILEPATH.2

    if [ $? != 0 ]; then
	echo "$0: files differ, test run $i failed!"
	continue
    fi
done

echo "$0: removing temporary iRODS collection $DSTPATH..."
irm -rf $DSTPATH

echo "$0: removing temporary local file $FILEPATH..."
rm $FILEPATH
