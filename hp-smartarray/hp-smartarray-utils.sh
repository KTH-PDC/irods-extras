# hp-smartarray-utils.sh - utility shell functions for managing HP Smart Array controller logical volumes
# Author: Ilari Korhonen, KTH Royal Institute of Technology

HPBIN=hpacucli

function array-create() {
    SLOT=$1
    RAID=$2
    STRIPE=$3
    DRIVES=$4

    $HPBIN ctrl slot=$SLOT create type=ld drives=$DRIVES raid=$RAID stripsize=$STRIPE
}
    
function array-show() {
    SLOT=$1
    ID=$2

    $HPBIN ctrl slot=$SLOT ld $ID show
}

function array-delete() {
    SLOT=$1
    ID=$2
   
   $HPBIN ctrl slot=$SLOT ld $ID delete
}

function array-get-wwn() {
    SLOT=$1
    ID=$2

    $HPBIN ctrl slot=$SLOT ld $ID show |grep Unique|awk '{print $3}'|awk '{print tolower($0)}'
}

function drive-show() {
    SLOT=$1
    ID=$2

    $HPBIN ctrl slot=$SLOT pd $ID show
}
