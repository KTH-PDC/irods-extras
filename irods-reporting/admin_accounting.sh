#!/bin/bash

# admin_accounting.sh - dumps administrative accounting data from iRODS per user,superuser,group
# Author: Ilari Korhonen, KTH Royal Institute of Technology
#
# Copyright (C) 2018 KTH Royal Institute of Technology. All rights reserved.
# See LICENSE file for more information.

IRODSHOME="/var/lib/irods"
BASEPATH="$IRODSHOME/snic_admin_accounting/"

CURDATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
OUTFILE="$BASEPATH/acct-${CURDATE}.txt"

query_production_resc="select RESC_NAME where RESC_COMMENT = 'PRODUCTION'"
production_resc=$(iquest "%s" "$query_production_resc" | sort)

function acct_for_class()
{
    if [ $# -ne 3 ]; then
	return
    fi

    local class=$1
    local prefix=$2
    local name=$3

    query_entities="select USER_NAME where USER_TYPE = '${class}'"
    entities=$(iquest "%s" "${query_entities}" | sort)
    
    for entity in ${entities}; do
	query_total_objs="SELECT COUNT(DATA_ID) WHERE DATA_ACCESS_NAME = 'own' AND USER_NAME = '${entity}'"
	query_total_bytes="SELECT SUM(DATA_SIZE) WHERE DATA_ACCESS_NAME = 'own' AND USER_NAME = '${entity}'"

	total_objs=$(iquest "%s" "$query_total_objs")
	total_bytes=$(iquest "%s" "$query_total_bytes")

	printf "${name} ${entity} owns ${total_objs} objects (${total_bytes} bytes) in total (counting all replicas).\n" >> ${OUTFILE}

	if [ "$total_objs" -ne "0" ]; then
	    for objpath in /snic.se/{${prefix}/${entity},home/public,trash}; do
		query_path_objs="SELECT COUNT(DATA_ID) WHERE COLL_NAME LIKE '$objpath%' AND DATA_ACCESS_NAME = 'own' AND USER_NAME = '${entity}'"
		query_path_bytes="SELECT SUM(DATA_SIZE) WHERE COLL_NAME LIKE '$objpath%' AND DATA_ACCESS_NAME = 'own' AND USER_NAME = '${entity}'"

		path_objs=$(iquest "%s" "$query_path_objs")
		
		if [ "$path_objs" -ne "0" ]; then
		    total_objs=$(( $total_objs - $path_objs ))

		    path_bytes=$(iquest "%s" "$query_path_bytes")
		    printf "|-- Object path $objpath with $path_objs objects ($path_bytes bytes)\n" >> ${OUTFILE}

		    for resc in ${production_resc}; do
			query_resc_objs="SELECT COUNT(DATA_ID) WHERE COLL_NAME LIKE '$objpath%' AND DATA_ACCESS_NAME = 'own' AND USER_NAME = '${entity}' AND RESC_NAME = '$resc'" 
			query_resc_bytes="SELECT SUM(DATA_SIZE) WHERE COLL_NAME LIKE '$objpath%' AND DATA_ACCESS_NAME = 'own' AND USER_NAME = '${entity}' AND RESC_NAME = '$resc'"

			resc_objs=$(iquest "%s" "$query_resc_objs")
			resc_bytes=$(iquest "%s" "$query_resc_bytes")

			if [ "$resc_objs" -ne "0" ]; then
			    path_objs=$(( $path_objs - $resc_objs ))
			    printf "    |-- $resc: $resc_objs objects ($resc_bytes bytes)\n" >> ${OUTFILE}
			fi
		    done

		    printf "    |-- OTHER RESOURCES: $path_objs objects\n" >> ${OUTFILE}
		fi
	    done

	    printf "|-- OTHER PATHS: $total_objs objects\n" >> ${OUTFILE}
	fi

	printf "\n" >> ${OUTFILE}
    done
}

# ---

# output header

printf "SNIC iRODS Administrative Accounting as of ${CURDATE}\n\n" >> ${OUTFILE}

# report production data containing resources

printf "Resources classified as PRODUCTION\n\n${production_resc}\n\n" >> ${OUTFILE}

# report accounting for (SNIC) groups

printf "Accounting by Group and Resource\n\n" >> ${OUTFILE}
acct_for_class rodsgroup projects Group

# report accounting for ordinary users

printf "Accounting by User and Resource\n\n" >> ${OUTFILE}
acct_for_class rodsuser home User

# report accounting for privileged users (administrators)

printf "Accounting by Superuser and Resource\n\n" >> ${OUTFILE}
acct_for_class rodsadmin home Superuser
