# pgbench-run.sh - run pgbench in a sequence and collect results 
# Author: Ilari Korhonen, KTH Royal Institute of Technology

#!/bin/sh

# set defaults
NUMCLIENTS=10
NUMXACTS=1000
NUMRUNS=10
DBNAME=test
OUTFILE=/tmp/pgbench-run.out

ID=untitled
LOGDIR=/tmp/pgbench-run/$ID
LOGFILE=$LOGDIR/pgbench-run.log
TAG="including connections establishing"

# function show_help - shows help
show_help() {
    echo "pgbench-run.sh - run pgbench in a sequence and collect results"
    echo "usage: $1 [-h] [-c clients] [-t transactions/client] [-r runs] [-d dbname] [-i identifier] [-o outfile]"
}

# parse command line arguments POSIX style
OPTIND=1

while getopts "hc:t:r:d:i:o:" opt; do
    case "$opt" in
	h)
	    show_help
	    exit 0
	    ;;
	c)
	    NUMCLIENTS=$OPTARG
	    ;;
	t)
	    NUMXACTS=$OPTARG
	    ;;
	r)
	    NUMRUNS=$OPTARG
	    ;;
	d)
	    DBNAME=$OPTARG
	    ;;
	i)
	    ID=$OPTARG
	    ;;
	o)
	    OUTFILE=$OPTARG
	    ;;
    esac
done

mkdir -p $LOGDIR
chown -R postgres:postgres $LOGDIR

if [ $? -eq "0" ]; then
    echo "$0: writing pgbench log to $LOGFILE"
else
    echo "$0: FATAL: failed to create $LOGDIR!"
    exit
fi

echo "$0: running pgbench against database $DBNAME with $NUMCLIENTS clients and $NUMXACTS transactions per client..."

for i in {1..10}; do 
    echo "$0: pgbench run $i of $NUMRUNS against postgres database $DBNAME..."
    runuser -l postgres -c  "/usr/pgsql-9.4/bin/pgbench -c $NUMCLIENTS -t $NUMXACTS $DBNAME >> $LOGFILE"
done

# compute maximum, minimum, average and standard deviation from log using awk
MAX=`grep "$TAG" $LOGFILE | awk 'BEGIN {max=$3} {if ($3 > max) max=$3} END {print max}'`
MIN=`grep "$TAG" $LOGFILE | awk -v min=$MAX '{if ($3 < min) min=$3} END {print min}'`
AVG=`grep "$TAG" $LOGFILE | awk '{x+=$3} END {print (x/NR)}'`
STDDEV=`grep "$TAG" $LOGFILE | awk '{x+=$3; y+=$3^2} END {print sqrt(y/NR-(x/NR)^2)}'`

echo "# id numruns numclients numxacts min(tps) max(tps) avg(tps) stddev(tps)" >> $OUTFILE
echo "$ID $NUMRUNS $NUMCLIENTS $NUMXACTS $MIN $MAX $AVG $STDDEV" >> $OUTFILE
echo "$0: COMPLETE - results written to $OUTFILE"
