#!/bin/sh

# define the ZFS pool (zpool) to be created
ZPOOL_DEVS="nvme0n1 nvme1n1"
ZPOOL_LOGS="pmem0 pmem1"
ZPOOL_NAME="tank"

# create optimally aligned GPT partition tables to the zpool devices
for dev in $ZPOOL_DEVS; do
    echo "creating GPT partition table for zpool device $dev"
    parted -a optimal /dev/$dev mklabel gpt
done

# create zpool as a mirror from block devices
echo "creating zfs pool $ZPOOL_NAME..."
zpool create $ZPOOL_NAME -o ashift=12 mirror $ZPOOL_DEVS log mirror $ZPOOL_LOGS

# create filesystems for io tests
echo "creating zfs filesystems..."
zfs create -o atime=off $ZPOOL_NAME/iotest
zfs create $ZPOOL_NAME/iotest/fiotest

# create filesystems for postgres db and xlog
zfs create -o atime=off -o recordsize=8k -o logbias=throughput $ZPOOL_NAME/db01
zfs create -o atime=off -o recordsize=8k -o logbias=latency $ZPOOL_NAME/xlog01

# create filesystems for postgres test
zfs create $ZPOOL_NAME/db01/test
zfs create $ZPOOL_NAME/xlog01/test

# set permissions for postgres
echo "fixing permissions..."
chown -R postgres:postgres /$ZPOOL_NAME/db01
chown -R postgres:postgres /$ZPOOL_NAME/xlog01

# initialize postgres test db cluster
echo "initializing postgres test database cluster..."
runuser -l postgres -c "/usr/pgsql-9.5/bin/initdb -D /$ZPOOL_NAME/db01/test -X /$ZPOOL_NAME/xlog01/test"
runuser -l postgres -c "/usr/pgsql-9.5/bin/pg_ctl -D /$ZPOOL_NAME/db01/test start"

# wait a bit for postgres to start properly 
sleep 5

# create test db and initialize test db for pgbench
echo "creating and initializing test db for benchmarking..."
runuser -l postgres -c "createdb test"
runuser -l postgres -c "/usr/pgsql-9.5/bin/pgbench -i -s 75 test"

# run pgbench to validate performance against test db
echo "running postgres benchmark..."
~ilarik/Public/pgbench-run/pgbench-run.sh -c 10 -t 1000 -r 100 -d test -i zfs-noatime-ashift12-8k-thruput-and-latency-nvme-slog-pmem -o /tmp/perftest/pgbench.out
