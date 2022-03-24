#!/bin/bash

# Never run pacman -Sy on your actual system
pacman -Sy dialog

# Ensure time is correct
timedatectl set-ntp true

dialog --defaultno --title "Are you sure?" --yesno \
    "This will install arch linux on your computer. \n\n\
    WARNING! It will DESTROY everything on the hd you choose. \n\n\
    Proceed with caution and Just Say NO if you're not sure what you're doing! \n\n\
    Do you really want to continue?" 15 60 || exit

# Verify boot (Uefi or BIOS)
uefi=0
ls /sys/firmware/efi/efivars 2> /dev/null && uefi=1

devices_list=($(lsblk -d | awk '{print "/dev/" $1 " " $4 " on"}' \
    | grep -E 'sd|hd|vd|nvme|mmcblk'))

dialog --title "Choose harddrive for installation" --no-cancel --radiolist \
    "Where do you want to install your new system \n\n\
    Select with SPACE, confirm with ENTER. \n\n\
    WARNING: The drive will be completely WIPED and all data destroyed!" \
    15 60 4 "${devices_list[@]}" 2> hd

hd=$(cat hd) && rm hd

# Partition sizes
default_size="8"
dialog --no-cancel --inputbox \
    "You need three partitions: Boot, Root and Swap \n\
    The boot partition will be 512M. \n\
    The root partition will be the remaining of the drive \n\n\
    Enter the partition size (in GB) for the Swap. \n\n\
    Default is ${default_size}G. \n" \
    20 60 2> swap_size
size=$(cat swap_size) && rm swap_size

[[ $size =~ ^[0-9]+$ ]] || size=$default_size

# Erase the hard drive
dialog --no-cancel \
    --title "!!! DELETE EVERYTHING !!!" \
    --menu "Choose the way I'll wipe your hard drive ($hd)" \
    15 60 4 \
    1 "Use dd (wipe all)" \
    2 "Use shred (slow but secure)" \
    3 "No need - my drive is empty" 2> eraser

hderaser=$(cat eraser); rm eraser

function eraseDrive() {
    case $1 in
        1) dd if=/dev/zero of="$hd" status=progress 2>&1 \
            | dialog \
            --title "Formatting $hd..." \
            --progressbox --stdout 20 60;;
        2) shred -v "$hd" \
            | dialog \
            --title "Formatting $hd..." \
            --progressbox --stdout 20 60;;
        3) ;;
    esac
}
eraseDrive "$hderaser"

# Creating Partitions
boot_partition_type=1
[[ "$uefi" == 0 ]] && boot_partition_type=4

#g - create non empty GPT partition table
#n - create new partition
#p - primary partition
#e - extended partition
#w - write the table to disk and exit

partprobe "$hd"

fdisk "$hd" << EOF
g
n


+512M
t
$boot_partition_type
n


+${size}G
n



w
EOF

partprobe "$hd"

# Formatting Partitions
mkswap "${hd}2"
swapon "${hd}2"

mkfs.ext4 "${hd}3"
mount "${hd}3" /mnt

if [ "$uefi" = 1 ]; then
    mkfs.fat -F32 "${hd}1"
    mkdir -p /mnt/boot/efi
    mount "${hd}1" /mnt/boot/efi
fi

# Generate fstab and install Arch Linux
pacstrap /mnt base base-devel linux linux-firmware
genfstab -U /mnt >> /mnt/etc/fstab

# Persist important values for the next script
echo "$uefi" > /mnt/var_uefi
echo "$hd" > /mnt/var_hd
mv comp /mnt/comp


curl https://raw.githubusercontent.com/LarsJohansen\
/arch_installer/main/install_chroot.sh > /mnt/install_chroot.sh

arch-chroot /mnt bash install_chroot.sh

rm /mnt/var_uefi
rm /mnt/var_hd
rm /mnt/install_chroot.sh
rm /mnt/comp

dialog --title "To reboot or not to reboot?" --yesno \
"Congrats! The install is done! \n\n\
Do you want to reboot your computer?" 20 60

response=$?

case $response in
    0) reboot;;
    1) clear;;
esac
