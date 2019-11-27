#!/bin/bash

# admin_accounting.sh - dumps administrative accounting data from iRODS per user,superuser,group
# Author: Ilari Korhonen, KTH Royal Institute of Technology
#
# Copyright (C) 2018-2019 KTH Royal Institute of Technology. All rights reserved.
# See LICENSE file for more information.

BASEPATH="/gpfs/fs0/var/log/admin_accounting"

CURDATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
OUTFILE="$BASEPATH/acct-${CURDATE}.txt"

declare -a resc_tiers
declare -A resc_info


function expandlist()
{
    if [ $# -eq 0 ]; then
        return;
    fi

    printf "(\'$1\'"
    shift

    for arg in $@; do
        printf ",\'$arg\'";
    done

    printf ")"
}


function query_resc()
{
    local resc_id=$1
    local attr=$2

    iquest "%s" "select META_RESC_ATTR_VALUE where RESC_ID = '${resc_id}' and META_RESC_ATTR_NAME = 'se.snic::storage::${attr}'"
}


function acct_for_resc_tier()
{
    local tier=$1
    local entity=$2
    local class=$3
    local prefix=$4
    local name=$5

    tier_expr=$(expandlist ${resc_tiers[$tier]})

    query_tier_objs="SELECT COUNT(DATA_ID) WHERE COLL_NAME LIKE '${objpath}%' AND DATA_ACCESS_NAME = 'own' AND USER_NAME = '${entity}' AND RESC_ID IN ${tier_expr}"
    query_tier_bytes="SELECT SUM(DATA_SIZE) WHERE COLL_NAME LIKE '${objpath}%' AND DATA_ACCESS_NAME = 'own' AND USER_NAME = '${entity}' AND RESC_ID IN ${tier_expr}"

    tier_objs=$(iquest "%s" "${query_tier_objs}")

    if [ ${tier_objs} -ne 0 ]; then
	tier_bytes=$(iquest "%s" "${query_tier_bytes}")
	printf "    |-- TIER ${tier} TOTAL: ${tier_objs} objects (${tier_bytes} bytes)\n"
    fi
}

function acct_for_entity()
{
    if [ $# -ne 4 ]; then
        return
    fi
    
    local entity=$1
    local class=$2
    local prefix=$3
    local name=$4

    query_total_objs="SELECT COUNT(DATA_ID) WHERE DATA_ACCESS_NAME = 'own' AND USER_NAME = '${entity}'"
    query_total_bytes="SELECT SUM(DATA_SIZE) WHERE DATA_ACCESS_NAME = 'own' AND USER_NAME = '${entity}'"
    
    total_objs=$(iquest "%s" "$query_total_objs")
    
    [ "${total_objs}" -ne "0" ] && total_bytes=$(iquest "%s" "$query_total_bytes") || total_bytes="0"
    
    printf "${name} ${entity} owns ${total_objs} objects (${total_bytes} bytes) in total (counting all replicas).\n"
    
    if [ "$total_objs" -ne "0" ]; then
	for objpath in /snic.se/{${prefix}/${entity},home/public,trash}; do
	    query_path_objs="SELECT COUNT(DATA_ID) WHERE COLL_NAME LIKE '${objpath}%' AND DATA_ACCESS_NAME = 'own' AND USER_NAME = '${entity}'"
	    query_path_bytes="SELECT SUM(DATA_SIZE) WHERE COLL_NAME LIKE '${objpath}%' AND DATA_ACCESS_NAME = 'own' AND USER_NAME = '${entity}'"

	    path_objs=$(iquest "%s" "$query_path_objs")
 
	    if [ "$path_objs" -ne "0" ]; then
		total_objs=$(( $total_objs - $path_objs ))
		
		path_bytes=$(iquest "%s" "$query_path_bytes")
		printf "|-- Object path $objpath with $path_objs objects ($path_bytes bytes)\n"
		
		for resc in ${production_resc}; do
		    query_resc_objs="SELECT COUNT(DATA_ID) WHERE COLL_NAME LIKE '${objpath}%' AND DATA_ACCESS_NAME = 'own' AND USER_NAME = '${entity}' AND RESC_ID = '$resc'" 
		    query_resc_bytes="SELECT SUM(DATA_SIZE) WHERE COLL_NAME LIKE '${objpath}%' AND DATA_ACCESS_NAME = 'own' AND USER_NAME = '${entity}' AND RESC_ID = '$resc'"

		    resc_objs=$(iquest "%s" "$query_resc_objs")

		    [ "${resc_objs}" -ne "0" ] && resc_bytes=$(iquest "%s" "$query_resc_bytes") || resc_bytes="0"
		    
		    if [ "$resc_objs" -ne "0" ]; then
			path_objs=$(( $path_objs - $resc_objs ))
			printf "    |-- ${resc_info[${resc}]}: $resc_objs objects ($resc_bytes bytes)\n"
		    fi
		done

		for tier in {0..1}; do
		    acct_for_resc_tier ${tier} $@
		done

		printf "    |-- OTHER RESOURCES: $path_objs objects\n"
	    fi
	done
	
	printf "|-- OTHER PATHS: $total_objs objects\n"
    fi
}
    

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
	acct_for_entity ${entity} ${class} ${prefix} ${name}
	printf "\n"
    done
}


# ---

for tier in {0..1}; do
    query_resc_tier="select RESC_ID where META_RESC_ATTR_NAME = 'se.snic::storage::tier' and META_RESC_ATTR_VALUE = '${tier}'"
    resc_tier=$(iquest "%s" "${query_resc_tier}" | xargs echo)

    if [ "${resc_tier}" != "" ]; then
	resc_tiers[${tier}]=${resc_tier}
    fi
done

production_resc="${resc_tiers[0]} ${resc_tiers[1]}"

for resc_id in ${production_resc}; do
    name=$(iquest "%s" "SELECT RESC_NAME where RESC_ID = '${resc_id}'")

    element=$(query_resc ${resc_id} "element")
    status=$(query_resc ${resc_id} "status")
    tier=$(query_resc ${resc_id} "tier")
    provider=$(query_resc ${resc_id} "provider")
    center=$(query_resc ${resc_id} "center")

    resc_info[${resc_id}]="${name}: tier ${tier} ${provider} ${element} (${status}) at ${center}"
done

if [ "$1" != "" ]; then
    acct_for_entity $@
else
    {
	# output header
	printf "SNIC iRODS Administrative Accounting as of ${CURDATE}\n\n"
	
	# report production data containing resources
	printf "Resources classified as PRODUCTION\n\n"
	for resc_id in ${production_resc}; do 
	    echo ${resc_info[${resc_id}]}
	done
	printf "\n\n"
	
	# report accounting for (SNIC) groups
	printf "Accounting by Group and Resource\n\n"
	acct_for_class rodsgroup projects Group
	
	# report accounting for ordinary users
	printf "Accounting by User and Resource\n\n"
	acct_for_class rodsuser home User
	
	# report accounting for privileged users (administrators)
	printf "Accounting by Superuser and Resource\n\n"
	acct_for_class rodsadmin home Superuser
	
	# log end timestamp
	printf "Accounting run completed at $(date -u +"%Y-%m-%dT%H:%M:%SZ")\n"
    } > ${OUTFILE}
fi
