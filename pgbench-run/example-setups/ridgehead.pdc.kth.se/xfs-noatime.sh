#!/bin/sh

source /tmp/hp-smartarray-utils.sh
ctrl_set 0 queuedepth 16

array_create 0 6 default 1I:1:3,1I:1:4,1I:1:5,1I:1:6,1I:1:7,1I:1:8
array_create 0 6 default 1I:1:9,1I:1:10,1I:1:11,1I:1:12,1I:1:13,2I:1:14
array_create 0 1+0 default 2I:1:15,2I:1:16,2I:1:17,2I:1:18,2I:1:19,2I:1:20

for i in 2 3 4 ; do parted /dev/disk/by-id/wwn-0x`array_get_wwn 0 $i` mklabel gpt; done
for i in 2 3 4 ; do parted -a optimal /dev/disk/by-id/wwn-0x`array_get_wwn 0 $i` mkpart primary 0% 100%; done

pvcreate /dev/disk/by-id/wwn-0x`array_get_wwn 0 2`-part1
pvcreate /dev/disk/by-id/wwn-0x`array_get_wwn 0 3`-part1
pvcreate /dev/disk/by-id/wwn-0x`array_get_wwn 0 4`-part1

vgcreate db01 /dev/sdb1 /dev/sdc1
vgcreate xlog01 /dev/sdd1

lvcreate -n pgbench -L4TB db01
lvcreate -n pgbench -L1TB xlog01

mkfs.xfs /dev/db01/pgbench
mkfs.xfs /dev/xlog01/pgbench

mkdir -p /db01/pgbench
mkdir -p /xlog01/pgbench

mount -t xfs -o noatime /dev/db01/pgbench /db01/pgbench
mount -t xfs -o noatime /dev/xlog01/pgbench /xlog01/pgbench

chown -R postgres:postgres /db01
chown -R postgres:postgres /xlog01

runuser -l postgres -c "/usr/pgsql-9.4/bin/initdb -D /db01/pgbench -X /xlog01/pgbench"
runuser -l postgres -c "/usr/pgsql-9.4/bin/pg_ctl -D /db01/pgbench start"

sleep 5

runuser -l postgres -c "createdb test"
runuser -l postgres -c "/usr/pgsql-9.4/bin/pgbench -i -s 75 test"

./pgbench-run.sh -c 10 -t 1000 -r 100 -d test -i xfs-noatime -o /tmp/pgbench.out
