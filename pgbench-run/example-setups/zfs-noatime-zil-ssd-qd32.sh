#!/bin/sh

source /tmp/hp-smartarray-utils.sh
ctrl_set 0 queuedepth 32

array_create 0 6 default 1I:1:3,1I:1:4,1I:1:5,1I:1:6,1I:1:7,1I:1:8 
array_create 0 6 default 1I:1:9,1I:1:10,1I:1:11,1I:1:12,1I:1:13,2I:1:14
array_create 0 1+0 default 2I:1:15,2I:1:16,2I:1:17,2I:1:18,2I:1:19,2I:1:20

for i in 2 3 4; do array_set 0 $i caching disable; done

read -p "Please wait for the RAID arrays to finish initializing...Press return to continue."

for i in 2 3 4 ; do parted /dev/disk/by-id/wwn-0x`array_get_wwn 0 $i` mklabel gpt; done

parted /dev/nvme0n1 mklabel gpt
parted /dev/nvme0n1 mkpart primary 0% 64GB
parted /dev/nvme0n1 mkpart primary 64GB 128GB

zpool create db01 wwn-0x`array_get_wwn 0 2` wwn-0x`array_get_wwn 0 3` log nvme0n1p1
zpool create xlog01 wwn-0x`array_get_wwn 0 4` log nvme0n1p2

zfs create -o atime=off db01/pgbench
zfs create -o atime=off xlog01/pgbench

chown -R postgres:postgres /db01
chown -R postgres:postgres /xlog01

runuser -l postgres -c "/usr/pgsql-9.4/bin/initdb -D /db01/pgbench -X /xlog01/pgbench"
runuser -l postgres -c "/usr/pgsql-9.4/bin/pg_ctl -D /db01/pgbench start"

sleep 5

runuser -l postgres -c "createdb test"
runuser -l postgres -c "/usr/pgsql-9.4/bin/pgbench -i -s 75 test"

/tmp/pgbench-run.sh -c 10 -t 1000 -r 100 -d test -i zfs-noatime-zil-ssd-qd32 -o /tmp/pgbench.out
