#!/bin/sh

source /tmp/hp-smartarray-utils.sh
ctrl_set 0 queuedepth 16

for ((i=3; i <= 13; i++)); do
    echo "creating passthru device $i"
    array_create 0 0 default 1I:1:$i caching=disable
done

for ((i=14; i <= 24; i++)); do
    echo "creating passthru device $i"
    array_create 0 0 default 2I:1:$i caching=disable
done

read -p "Please wait for the RAID arrays to finish initializing...Press return to continue."

for ((i=2; i <= 23; i++)); do
    echo "creating GPT partition table for passthru device $i"
    parted /dev/disk/by-id/wwn-0x`array_get_wwn 0 $i` mklabel gpt
done

echo "creating zfs pool db01..."
zpool create db01 \
    mirror sdb sdc \
    mirror sdd sde \
    mirror sdf sdg \
    mirror sdh sdi \
 
echo "creating zfs pool dblog01..."
zpool create dblog01 \
    mirror sdj sdk \
    mirror sdl sdm \
    mirror sdn sdo \
    mirror sdp sdq \
    mirror sdr sds \
    mirror sdt sdu \
    mirror sdv sdw

zfs create -o atime=off db01/pgbench
zfs create -o atime=off dblog01/pgbench

chown -R postgres:postgres /db01
chown -R postgres:postgres /dblog01

runuser -l postgres -c "/usr/pgsql-9.4/bin/initdb -D /db01/pgbench -X /dblog01/pgbench"
runuser -l postgres -c "/usr/pgsql-9.4/bin/pg_ctl -D /db01/pgbench start"

sleep 5

runuser -l postgres -c "createdb test"
runuser -l postgres -c "/usr/pgsql-9.4/bin/pgbench -i -s 75 test"

/tmp/pgbench-run.sh -c 10 -t 1000 -r 100 -d test -i zfs-passthru-raid10 -o /tmp/pgbench.out
