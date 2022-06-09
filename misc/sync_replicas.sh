#!/bin/bash

# sync_replicas.sh - synchronizes iRODS replicas from resource to resource
# Author: Ilari Korhonen, KTH Royal Institute of Technology
#
# Copyright (C) 2018 KTH Royal Institute of Technology. All rights reserved.
# See LICENSE file for more information.

show_help()
{
    echo "sync_replicas.sh - sync iRODS replicas from resouce to resource"
    echo "usage: $0 -S [source] -R [destination] [-sKvh] [virtual path]"
    echo "virtual path: absolute path of the collection to sync within iRODS virtual namespace"
    echo "-S sets the source resource to sync replicas from"
    echo "-R sets the destination resource to sync replicas to"
    echo "-s skips replication if size of the collection (total data objs, total bytes) at the source and destination agree"
    echo "-K enforces availability of checksums, replicates if and only if all checkums are present at path and resources"
    echo "-v sets verbose mode on"
    echo "-h shows this help"
}

# set defaults
SIZECHECK=0
CHECKSUMS=0
VERBOSE=0

# parse command line arguments
OPTIND=1

while getopts "hsKvS:R:" opt; do
    case "$opt" in
	S)
	    SOURCE_RESC=$OPTARG
	    ;;
	R)
	    DEST_RESC=$OPTARG
	    ;;
	s)
	    SIZECHECK=1
	    ;;
	K)
	    CHECKSUMS=1
	    ;;
	v)
	    VERBOSE=1
	    ;;
	h)
	    show_help
	    exit 0
	    ;;
	?)
	    show_help
	    exit -1
	    ;;
    esac
done

shift "$(($OPTIND -1))"
OBJPATH=$@

# check that parameters have been passed with arguments
if [ "$SOURCE_RESC" == "" ]; then
    echo "$0: source resouce is required!"
    exit -1
fi

if [ "$DEST_RESC" == "" ]; then
    echo "$0: destination resource is required!"
    exit -1
fi

# validate virtual path argument
if [ "$OBJPATH" == "" ]; then
    echo "$0: virtual path for replication is required!"
    exit -1
elif [[ "$OBJPATH" =~ ^/ ]]; then
    # try to access the path
    ils $OBJPATH > /dev/null

    if [ $? -ne 0 ]; then
	echo "$0: virtual path '${OBJPATH}' doesn't exist or not accessible!"
	exit -1
    fi
else
    echo "$0: virtual path needs to begin with a forward slash!"
    exit -1    
fi

if [ $VERBOSE -eq 1 ]; then
    echo "$0: syncing replicas for virtual path '${OBJPATH}'"
    echo "$0: source resource set to '${SOURCE_RESC}'"
    echo "$0: destination resouce set to '${DEST_RESC}'"
    echo "$0: flags: size check = ${SIZECHECK}, checksums = ${CHECKSUMS}, verbose = ${VERBOSE}"
fi

function query_data_count() 
{
    if [ $# -ne 2 ]; then
	return -1;
    fi

    local _resc=$1
    local _objpath=$2

    local _data_count_query_1="select count(DATA_ID) where DATA_RESC_NAME = '${_resc}' and COLL_NAME = '${_objpath}'"
    local _data_count_query_2="select count(DATA_ID) where DATA_RESC_NAME = '${_resc}' and COLL_NAME like '${_objpath}/%'"

    local _data_count_1=$(iquest "%s" "${_data_count_query_1}")
    local _data_count_2=$(iquest "%s" "${_data_count_query_2}")

    DATA_COUNT=$((_data_count_1 + _data_count_2))
}

function query_data_size() 
{
    if [ $# -ne 2 ]; then
	return -1;
    fi

    local _resc=$1
    local _objpath=$2

    local _data_size_query_1="select sum(DATA_SIZE) where DATA_RESC_NAME = '${_resc}' and COLL_NAME = '${_objpath}'"
    local _data_size_query_2="select sum(DATA_SIZE) where DATA_RESC_NAME = '${_resc}' and COLL_NAME like '${_objpath}/%'"

    local _data_size_1=$(iquest "%s" "${_data_size_query_1}")
    local _data_size_2=$(iquest "%s" "${_data_size_query_2}")

    DATA_SIZE=$((_data_size_1 + _data_size_2))
}

if [ $SIZECHECK -eq 1 ]; then
    query_data_count $SOURCE_RESC $OBJPATH
    DATA_COUNT_SRC=$DATA_COUNT
    [ $VERBOSE -eq 1 ] && echo "$0: object count for path '${OBJPATH}' at source resource '${SOURCE_RESC}' is ${DATA_COUNT_SRC}"
    
    query_data_count ${DEST_RESC} ${OBJPATH}
    DATA_COUNT_DEST=${DATA_COUNT}
    [ $VERBOSE -eq 1 ] && echo "$0: object count for path '${OBJPATH}' at destination resource '${DEST_RESC}' is ${DATA_COUNT_DEST}"

    # only query total size if object count is a match
    if [ $DATA_COUNT_SRC -eq $DATA_COUNT_DEST ]; then
	query_data_size $SOURCE_RESC $OBJPATH
	DATA_SIZE_SRC=$DATA_SIZE
	[ $VERBOSE -eq 1 ] && echo "$0: byte count for path '${OBJPATH}' at source resource '${SOURCE_RESC}' is ${DATA_SIZE_SRC}"

	query_data_size $DEST_RESC $OBJPATH
	DATA_SIZE_DEST=$DATA_SIZE
	[ $VERBOSE -eq 1 ] && echo "$0: byte count for path '${OBJPATH}' at destination resource '${DEST_RESC}' is ${DATA_SIZE_DEST}"

	# if the total size is also a match, we bail out (when size check = true)
	if [ $DATA_SIZE_SRC -eq $DATA_SIZE_DEST ]; then
	    echo "$0: no sync required for path '${OBJPATH}' from resc '${SOURCE_RESC}' to '${DEST_RESC}', exiting..."
	    exit 0
	fi
    fi
fi

echo "$0: synchronizing replicas for data objects at path '${OBJPATH}' from resource '${SOURCE_RESC}' to '${DEST_RESC}'"

START_DATE=$(date --iso-8601=seconds)
echo "$0: timestamp ${START_DATE}, starting irepl..."

irepl -MBar -R ${DEST_RESC} -S ${SOURCE_RESC} ${OBJPATH}
STATUS=$?
END_DATE=$(date --iso-8601=seconds)

printf "$0: timestamp ${END_DATE}, irepl finished "
[ $STATUS -eq 0 ] && printf "successfully, " || printf "with errors, "
printf "status = ${STATUS}\n"
