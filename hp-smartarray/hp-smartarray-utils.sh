# hp-smartarray-utils.sh - utility shell functions for managing HP Smart Array controller logical volumes
# Author: Ilari Korhonen, KTH Royal Institute of Technology

HPBIN=hpacucli

ctrl_set() { 
    SLOT=$1
    KEY=$2
    VALUE=$3

    $HPBIN ctrl slot=$SLOT modify $KEY=$VALUE
}

ctrl_show() { 
    SLOT=$1
    ARG2=$2
    ARG3=$3
    
    $HPBIN ctrl slot=$SLOT show $ARG2 $ARG3
}

array_set() {
    SLOT=$1
    ID=$2
    KEY=$3
    VALUE=$4

    $HPBIN ctrl slot=$SLOT ld $ID modify $KEY=$VALUE
}

array_create() {
    SLOT=$1
    RAID=$2
    STRIPE=$3
    DRIVES=$4

    $HPBIN ctrl slot=$SLOT create type=ld drives=$DRIVES raid=$RAID stripsize=$STRIPE
}
    
array_show() {
    SLOT=$1
    ID=$2

    $HPBIN ctrl slot=$SLOT ld $ID show
}

array_delete() {
    SLOT=$1
    ID=$2
   
   $HPBIN ctrl slot=$SLOT ld $ID delete
}

array_get_wwn() {
    SLOT=$1
    ID=$2

    $HPBIN ctrl slot=$SLOT ld $ID show |grep Unique|awk '{print $3}'|awk '{print tolower($0)}'
}

drive_show() {
    SLOT=$1
    ID=$2

    $HPBIN ctrl slot=$SLOT pd $ID show
}
