include verbose.sh
include directories.sh

nbd_device() {
    echo /dev/nbd
}

nbd_first_device() {
    echo $(nbd_device)0
}

create_qcow2_image() {
    local image_file=$1
    local size=$2

    qemu-img create \
        -q \
        -f qcow2 \
        $image_file \
        $size
}

image_file_format() {
    local image_file=$1

    qemu-img info $image_file \
        | grep 'file format' \
        | awk '{print $3}'
}

verify_image_is_qcow2() {
    local image_file=$1

    qemu-img info $image_file \
        | grep -q 'file format: qcow2'
}

load_nbd_module() {
    modprobe nbd max_part=8
}

create_mount_point() {
    local mount_point=$1

    create_dir_if_needed $mount_point
}

nbd_connect() {
    local image_file=$1

    load_nbd_module
    qemu-nbd \
        --connect=$(nbd_first_device) \
        $image_file
}

nbd_disconnect() {
    qemu-nbd \
        --disconnect $(nbd_first_device) \
        > /dev/null
}

process_is_running() {
    local ps_fax_process_identifier_str=$@

    ps fax \
        | grep "$ps_fax_process_identifier_str" \
        | grep -v grep \
        | grep -q "$ps_fax_process_identifier_str"
}

nbd_connected() {
    local image_file=$1

    process_is_running \
        "qemu-nbd --connect=$(nbd_first_device) $image_file"
}

mount_qcow2_image() {
    local image_file=$1
    local partition_number=$2
    local mount_point=$3

    create_mount_point $mount_point
    nbd_connect $image_file
    mount $(nbd_first_device)p$partition_number $mount_point
}

umount_qcow2_image() {
    local mount_point=$1

    umount $mount_point
    nbd_disconnect
}
