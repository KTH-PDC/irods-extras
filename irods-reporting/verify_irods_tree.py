#!/usr/bin/env python

# verify_irods_tree.py - performs database consistency checks to verify the integrity of the iRODS virtual tree
# Author: Ilari Korhonen, KTH Royal Institute of Technology
#
# Copyright (C) 2018 KTH Royal Institute of Technology. All rights reserved.
# See LICENSE file for more information.

#!/usr/bin/env python

from __future__ import print_function

import sys

import psycopg2
import psycopg2.extras

def reset_line():
    sys.stdout.write(u"\u001b[0K")
    sys.stdout.write(u"\u001b[1000D")
    sys.stdout.flush()

try:
    conn = psycopg2.connect("dbname='ICAT' user='postgres' host='localhost'")
except:
    print("ERROR: unable to connect to the database at localhost!")

# get a dict type cursor
cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

# query all collections
print("querying for all iRODS collections from iCAT database...")

try:
    cur.execute("SELECT coll_id, coll_name, parent_coll_name from r_coll_main ORDER BY coll_name ASC")
    coll_rows = cur.fetchall()
except:
    print("ERROR: unable to execute query for all collections!")
    exit(-1)

coll_count = cur.rowcount
orphan_count = 0
data_err_count = 0

print("total of " + str(coll_count) + " collections present, verifying all collections...")

# loop over collections and verify
for coll_row in coll_rows:
    coll_id = coll_row['coll_id']
    coll_name = coll_row['coll_name']
    parent_coll_name = coll_row['parent_coll_name']

    coll_name_disp = coll_name
    
    if len(coll_name) > 128:
        coll_name_disp = coll_name[:128] + "..."
    
    print("verifying collection id: " + str(coll_id) + " (" + coll_name_disp + ")", end='')
    reset_line()

    # first, verify the existence of the parent collection
    try:
        cur.execute("SELECT coll_id FROM r_coll_main WHERE coll_name = '" + parent_coll_name + "'")
    except:
        print("ERROR: unable to execute query for parent collection!")
        exit(-1)

    # if parent not found, report consistency error and increase counter
    if cur.rowcount == 0:
        print("CONSISTENCY ERROR: collection id " + str(coll_id) + " has no parent in iCAT!")
        print("ORPHAN PATH: " + coll_name)
        
        orphan_count = orphan_count + 1

    # verify consistency of data objects in the collection
    try:
        cur.execute("SELECT DISTINCT data_id FROM r_data_main WHERE coll_id = " + str(coll_id))
    except:
        print("ERROR: unable to query data objects in collection id " + str(coll_id))
        exit(-1)

    data_count = cur.rowcount
    data_id_rows = cur.fetchall()

    for data_id_row in data_id_rows:
        data_id = data_id_row['data_id']

        try:
            cur.execute("""
            SELECT 
            COUNT (data_repl_num) as repls, 
            COUNT (DISTINCT data_repl_num) dst_repls, 
            COUNT (data_checksum) as chksums, 
            COUNT (DISTINCT data_checksum) as dst_chksums
            FROM r_data_main 
            WHERE data_id = """ + str(data_id)
            )
        except:
            print("ERROR: unable to query data object id " + str(data_id))
            exit(-1)

        if cur.rowcount != 0:
            data_row = cur.fetchone()

            repls = data_row['repls']
            dst_repls = data_row['dst_repls']
            chksums = data_row['chksums']
            dst_chksums = data_row['dst_chksums']

            if repls != dst_repls:
                data_err_count = data_err_count + 1
                print("CONSISTENCY ERROR: data object id " + str(data_id) + " has inconsistent replica numbers!")
                print("VIRTUAL PATH: " + coll_name)

            if chksums != repls:
                data_err_count = data_err_count + 1
                print("WARNING: data object id " + str(data_id) + " has unchecksummed replicas!")
                print("VIRTUAL PATH: " + coll_name)
                
            if dst_chksums != 1:
                data_err_count = data_err_count + 1
                print("WARNING: data object id " + str(data_id) + " has differing checksums for replicas!")
                print("VIRTUAL PATH: " + coll_name)

        else:
            print("ERROR: data object id " + str(data_id) + " missing")
            exit(-1)


reset_line()
print("iRODS virtual directory verification process complete:")
print("total of " + str(orphan_count) + " orphan collections")
print("total of " + str(data_err_count) + " data object issues")

# ----
# print "querying all iRODS data objects from iCAT database..."

# try:
#     cur.execute("SELECT data_id, data_name, data_repl_num, coll_id FROM r_data_main")
# except:
#     print "error: unable to execute query for all data objects!"
#     exit(-1)

# data_counter = 0
# data_count_total = cur.rowcount
# data_rows = cur.fetchall()

# for data_row in data_rows:
#     data_id = data_row['data_id']
#     data_name = data_row['data_name']
#     data_repl_num = data_row['data_repl_num']
#     coll_id = data_row['coll_id']

#     #print "querying for data object id " + str(data_id) + " parent collection..."
    
#     try: 
#         cur.execute("SELECT coll_name FROM r_coll_main WHERE coll_id = " + str(coll_id))
#     except:
#         print "error: unable to query for data object id " + str(data_id) + " parent collection!"
#         exit(-1)

#     if cur.rowcount == 0:
#         print "consistency error: data object id " + str(data_id) + " parent collection doesn't exist!"

#     data_counter = data_counter + 1

#     if data_counter % 10000 == 0:
#         print str(data_counter) + " objects done..."
