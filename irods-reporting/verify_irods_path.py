#!/usr/bin/env python

# verify_irods_path.py - performs database consistency checks to verify the consistency of data object replicas
# Authors: Ilari Korhonen, Mattias Claesson, KTH Royal Institute of Technology
#
# Copyright (C) 2018 KTH Royal Institute of Technology. All rights reserved.
# See LICENSE file for more information.

#!/usr/bin/env python

from __future__ import print_function

import sys

import psycopg2
import psycopg2.extras

# we take two arguments currently, db role and a virtual path in iRODS
if len(sys.argv) < 3:
    print("usage: " + sys.argv[0] + "[database role] [base path in iRODS]")
    exit(-1)

db_role = sys.argv[1]
base_path = sys.argv[2]

# we connect to the local postgres
try:
    conn = psycopg2.connect("dbname='ICAT' user='" + db_role + "' host='localhost'")
except:
    print("ERROR: unable to connect to the database at localhost as role '" + db_role + "' !")

# get a dict type cursor
cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

# query all collections at base path
print("querying for iRODS subcollections from iCAT database at base path...")

try:
    cur.execute("SELECT coll_id, coll_name from r_coll_main WHERE coll_name like '" + base_path + "%' ORDER BY coll_name ASC")
    coll_rows = cur.fetchall()
except:
    print("ERROR: unable to execute query for all collections!")
    exit(-1)

# initialize counters
coll_count = cur.rowcount

data_total_count = 0
data_anomaly_count = 0
data_ok_count = 0

repl_num_distribution = dict()

repl_total_count = 0
repl_ok_count = 0
repl_err_count = 0
repl_nochksum_count = 0

# loop over collections and verify all data object replicas
print("total of " + str(coll_count) + " subcollections present at base path '" + base_path + "', verifying all...")

for coll_row in coll_rows:
    coll_id = coll_row['coll_id']
    coll_name = coll_row['coll_name']

    # verify consistency of data objects in the current collection
    try:
        cur.execute("SELECT DISTINCT data_id FROM r_data_main WHERE coll_id = " + str(coll_id))
    except:
        print("ERROR: unable to query data objects in collection id " + str(coll_id))
        exit(-1)

    data_count = cur.rowcount
    data_total_count += data_count

    data_id_rows = cur.fetchall()

    # go thru all available data object ID's in the collection
    for data_id_row in data_id_rows:
        data_id = data_id_row['data_id']

        try:
            cur.execute("""
            SELECT data_name, data_repl_num, resc_name, data_path, data_checksum 
            FROM r_data_main 
            WHERE data_id = """ + str(data_id) + " ORDER BY data_repl_num ASC")
        except:
            print("\nERROR: unable to query data object id " + str(data_id))
            exit(-1)

        if cur.rowcount != 0:
            data_rows = cur.fetchall()
            data_repls = cur.rowcount
            repl_total_count += data_repls

            repl_num_distribution[data_repls] = repl_num_distribution.get(data_repls, 0) + 1
            
            # we assume that the data_name of first row is correct/consistent
            data_name = data_rows[0]['data_name']
            objpath = coll_name + "/" + data_name
            
            # innocent until proven guilty
            ok = True
            
            # we take the attributes of the first replica to compare against
            repl_num = data_rows[0]['data_repl_num']
            resc_name = data_rows[0]['resc_name']
            checksum = data_rows[0]['data_checksum']
            
            print("\n" + objpath + " [" + checksum + "]", end='')

            # process each replica and compare to baseline (first available replica)
            current_repl_num = 0

            for data_row in data_rows:
                current_repl_num += 1
                print(" [replica ID: " + str(data_row['data_repl_num']) + " (" + str(current_repl_num) + "/" + str(data_repls) +  ")", end='')

                if data_row['data_name'] == data_name and len(data_row['data_checksum']) == 0:
                    repl_nochksum_count += 1
                    ok = False
                    print(" NOCHKSUM]", end='') 
                elif data_row['data_name'] == data_name and data_row['data_checksum'] == checksum:
                    repl_ok_count += 1
                    print(" OK]", end='')
                else:
                    repl_err_count += 1
                    ok = False
                    print(" ERROR]", end='')
                
            if not ok:
                data_anomaly_count += 1
            else:
                data_ok_count += 1

        else:
            print("ERROR: data object id " + str(data_id) + " missing")
            exit(-1)

# report statistics to the user
print("\n\niRODS object verification complete for virtual path: '" + base_path + "' !\n")

print("Collections (TOTAL):\t\t" + str(coll_count) + "\n")

print("Data objects (TOTAL):\t\t" + str(data_total_count))
print("Data objects (OK):\t\t" + str(data_ok_count))
print("Data objects (ANOMALY):\t\t" + str(data_anomaly_count) + "\n")

print("Data replicas (TOTAL):\t\t" + str(repl_total_count))
print("Data replicas (OK):\t\t" + str(repl_ok_count))
print("Data replicas (NOCHKSUM):\t" + str(repl_nochksum_count))
print("Data replicas (ERROR):\t\t" + str(repl_err_count) + "\n")

print("Number of replicas:\t", end='')
for num_repls in repl_num_distribution.keys():
    print("\t" + str(num_repls),  end='')

print("\nData object count:\t", end='')
for num_repls in repl_num_distribution.keys():
    print("\t" + str(repl_num_distribution[num_repls]), end='')

print("\n")
