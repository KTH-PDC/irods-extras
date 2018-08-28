#!/usr/bin/env python

# verify_irods_tree.py - performs database consistency checks to verify the integrity of the iRODS virtual tree
# Author: Ilari Korhonen, KTH Royal Institute of Technology
#
# Copyright (C) 2018 KTH Royal Institute of Technology. All rights reserved.
# See LICENSE file for more information.

import psycopg2
import psycopg2.extras

try:
    conn = psycopg2.connect("dbname='ICAT' user='postgres' host='localhost'")
except:
    print "error: unable to connect to the database at localhost!"

# get a dict type cursor
cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

print "querying for all iRODS collections from iCAT database..."

# query all collections
try:
    cur.execute("SELECT coll_id, coll_name, parent_coll_name from r_coll_main")
    coll_rows = cur.fetchall()
except:
    print "error: unable to execute query for all collections!"
    exit(-1)

coll_count = cur.rowcount
orphan_count = 0
affected_count = 0
print "total of " + str(coll_count) + " collections present, verifying all collections..."

# loop over collections and verify
for coll_row in coll_rows:
    coll_id = coll_row['coll_id']
    coll_name = coll_row['coll_name']
    parent_coll_name = coll_row['parent_coll_name']
    
    try:
        cur.execute("SELECT coll_id from r_coll_main WHERE coll_name = '" + parent_coll_name + "'")
    except:
        print "error: unable to execute query for parent collection!"
        exit(-1)

    if cur.rowcount == 0:
        print "consistency error: collection id " + str(coll_id) + " has no parent in iCAT!"
        print "orphan path: " + coll_name
        
        try:
            cur.execute("SELECT DISTINCT data_name FROM r_data_main WHERE coll_id = " + str(coll_id))
        except:
            print "error: unable to query for count of data objects!"
            exit(-1)

        data_count = cur.rowcount
        print "objects affected: " + str(data_count)

        affected_count = affected_count + data_count
        orphan_count = orphan_count + 1

    else:
        parent_row = cur.fetchone()
        parent_id = parent_row['coll_id']

print "collection verification process complete:"
print "total of " + str(orphan_count) + " orphan collections"
print "total of " + str(affected_count) + " data objects affected by orpan collections"

print "querying all iRODS data objects from iCAT database..."

try:
    cur.execute("SELECT data_id, data_name, data_repl_num, coll_id FROM r_data_main")
except:
    print "error: unable to execute query for all data objects!"
    exit(-1)

data_counter = 0
data_count_total = cur.rowcount
data_rows = cur.fetchall()

for data_row in data_rows:
    data_id = data_row['data_id']
    data_name = data_row['data_name']
    data_repl_num = data_row['data_repl_num']
    coll_id = data_row['coll_id']

    try: 
        cur.execute("SELECT coll_name FROM r_coll_main WHERE coll_id = " + str(coll_id))
    except:
        print "error: unable to query for data object id " + str(data_id) + " parent collection!"
        exit(-1)

    if cur.rowcount == 0:
        print "consistency error: data object id " + str(data_id) + " parent collection doesn't exist!"

    data_counter = data_counter + 1

    if data_counter % 10000 == 0:
        print str(data_counter) + " objects done..."
