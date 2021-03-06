#!/bin/sh

source /tmp/hp-smartarray-utils.sh
ctrl_set 0 queuedepth 32

array_create 0 1 8 1I:1:3,1I:1:4 caching=disable
array_create 0 1 8 1I:1:5,1I:1:6 caching=disable
array_create 0 1 8 1I:1:7,1I:1:8 caching=disable
array_create 0 1 8 1I:1:9,1I:1:10 caching=disable
array_create 0 1 8 1I:1:11,1I:1:12 caching=disable
array_create 0 1 8 1I:1:13,2I:1:14 caching=disable
array_create 0 1 8 2I:1:15,2I:1:16 caching=disable
array_create 0 1 8 2I:1:17,2I:1:18 caching=disable
array_create 0 1 8 2I:1:19,2I:1:20 caching=disable
array_create 0 1 8 2I:1:21,2I:1:22 caching=disable
array_create 0 1 8 2I:1:23,2I:1:24 caching=disable

read -p "Please wait for the RAID arrays to finish initializing...Press return to continue."

for ((i=2; i <= 12; i++)); do
    echo "creating GPT partition table for mirror device $i"
    parted -a optimal /dev/disk/by-id/wwn-0x`array_get_wwn 0 $i` mklabel gpt
done

echo "creating zfs pool dbpool01..."
zpool create dbpool01 \
    wwn-0x`array_get_wwn 0 2` \
    wwn-0x`array_get_wwn 0 3` \
    wwn-0x`array_get_wwn 0 4` \
    wwn-0x`array_get_wwn 0 5` \
    wwn-0x`array_get_wwn 0 6` \
    wwn-0x`array_get_wwn 0 7` \
    wwn-0x`array_get_wwn 0 8` \
    wwn-0x`array_get_wwn 0 9` \
    wwn-0x`array_get_wwn 0 10` \
    wwn-0x`array_get_wwn 0 11` \
    wwn-0x`array_get_wwn 0 12`

zfs create -o atime=off -o logbias=throughput -o recordsize=8k dbpool01/data
zfs create -o atime=off -o logbias=latency -o recordsize=8k dbpool01/xlog

zfs create -o atime=off -o logbias=throughput -o recordsize=8k dbpool01/data/pgbench
zfs create -o atime=off -o logbias=latency -o recordsize=8k dbpool01/xlog/pgbench

chown -R postgres:postgres /dbpool01

runuser -l postgres -c "/usr/pgsql-9.4/bin/initdb -D /dbpool01/data/pgbench -X /dbpool01/xlog/pgbench"
runuser -l postgres -c "/usr/pgsql-9.4/bin/pg_ctl -D /dbpool01/data/pgbench start"

sleep 5

runuser -l postgres -c "createdb test"
runuser -l postgres -c "/usr/pgsql-9.4/bin/pgbench -i -s 75 test"

/tmp/pgbench-run.sh -c 10 -t 1000 -r 100 -d test -i zfs-hybrid-raid10-bigpool-8k-qd32 -o /tmp/pgbench.out
