#!/bin/sh

source /tmp/hp-smartarray-utils.sh

# set command queue depth to 32 for maximum performance
ctrl_set 0 queuedepth 32

# create mirror devices with 8k i/o size (postgres page size) and caching
array_create 0 1 8 1I:1:3,1I:1:4 caching=enable
array_create 0 1 8 1I:1:5,1I:1:6 caching=enable
array_create 0 1 8 1I:1:7,1I:1:8 caching=enable
array_create 0 1 8 1I:1:9,1I:1:10 caching=enable
array_create 0 1 8 1I:1:11,1I:1:12 caching=enable
array_create 0 1 8 1I:1:13,2I:1:14 caching=enable
array_create 0 1 8 2I:1:15,2I:1:16 caching=enable
array_create 0 1 8 2I:1:17,2I:1:18 caching=enable
array_create 0 1 8 2I:1:19,2I:1:20 caching=enable
array_create 0 1 8 2I:1:21,2I:1:22 caching=enable
array_create 0 1 8 2I:1:23,2I:1:24 caching=enable

read -p "Please wait for the RAID arrays to finish initializing...Press return to continue."

# create optimally aligned GPT partition tables to mirror devices
for ((i=2; i <= 12; i++)); do
    echo "creating GPT partition table for mirror device $i"
    parted -a optimal /dev/disk/by-id/wwn-0x`array_get_wwn 0 $i` mklabel gpt
done

# create 2 zfs pools from mirror devices
echo "creating zfs pool fastpool01..."
zpool create fastpool01 \
    wwn-0x`array_get_wwn 0 2` \
    wwn-0x`array_get_wwn 0 3` \
    wwn-0x`array_get_wwn 0 4` \
    wwn-0x`array_get_wwn 0 5` \
    wwn-0x`array_get_wwn 0 6` \
    wwn-0x`array_get_wwn 0 7`

echo "creating zfs pool fastpool02..."
zpool create fastpool02 \
    wwn-0x`array_get_wwn 0 8` \
    wwn-0x`array_get_wwn 0 9` \
    wwn-0x`array_get_wwn 0 10` \
    wwn-0x`array_get_wwn 0 11` \
    wwn-0x`array_get_wwn 0 12`

# create zfs filesystem for databases (no atime, 8k blocks, zil for thruput) 
zfs create -o atime=off -o recordsize=8k -o logbias=throughput fastpool01/db01

# create zfs filesystem for xlogs (no atime, 8k blocks, zil for latency)
zfs create -o atime=off -o recordsize=8k -o logbias=latency fastpool02/xlog01

# create zfs filesystems for test db
zfs create fastpool01/db01/test
zfs create fastpool02/xlog01/test

# set permissions for postgres
chown -R postgres:postgres /fastpool01/db01
chown -R postgres:postgres /fastpool02/xlog01

# initialize postgres test db cluster
runuser -l postgres -c "/usr/pgsql-9.4/bin/initdb -D /fastpool01/db01/test -X /fastpool02/xlog01/test"
runuser -l postgres -c "/usr/pgsql-9.4/bin/pg_ctl -D /fastpool01/db01/test start"

# wait a bit for postgres to start properly 
sleep 5

# create test db and initialize test db for pgbench
runuser -l postgres -c "createdb test"
runuser -l postgres -c "/usr/pgsql-9.4/bin/pgbench -i -s 75 test"

# run pgbench to validate performance against test db
/tmp/pgbench-run.sh -c 10 -t 1000 -r 100 -d test -i zfs-2pools-cached-qd32-8k-datasets -o /tmp/pgbench.out
