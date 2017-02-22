#!/bin/sh

source /tmp/hp-smartarray-utils.sh
ctrl_set 0 queuedepth 16

array_create 0 1+0 64 1I:1:3,1I:1:4,1I:1:5,1I:1:6,1I:1:7,1I:1:8 
array_create 0 1+0 64 1I:1:9,1I:1:10,1I:1:11,1I:1:12,1I:1:13,2I:1:14,2I:1:15,2I:1:16,2I:1:17,2I:1:18,2I:1:19,2I:1:20,2I:1:21,2I:1:22,2I:1:23,2I:1:24

for i in 2 3 ; do array_set 0 $i caching disable; done

read -p "Please wait for the RAID arrays to finish initializing...Press return to continue."

for i in 2 3 ; do parted /dev/disk/by-id/wwn-0x`array_get_wwn 0 $i` mklabel gpt; done

zpool create db01 wwn-0x`array_get_wwn 0 2`
zpool create dblog01 wwn-0x`array_get_wwn 0 3`

zfs create -o atime=off db01/pgbench
zfs create -o atime=off dblog01/pgbench

chown -R postgres:postgres /db01
chown -R postgres:postgres /dblog01

runuser -l postgres -c "/usr/pgsql-9.4/bin/initdb -D /db01/pgbench -X /dblog01/pgbench"
runuser -l postgres -c "/usr/pgsql-9.4/bin/pg_ctl -D /db01/pgbench start"

sleep 5

runuser -l postgres -c "createdb test"
runuser -l postgres -c "/usr/pgsql-9.4/bin/pgbench -i -s 75 test"

/tmp/pgbench-run.sh -c 10 -t 1000 -r 100 -d test -i zfs-raid10-64k-stripes -o /tmp/pgbench.out
