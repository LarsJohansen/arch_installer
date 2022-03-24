#!/bin/bash

# Get variables from previous script
uefi=$(cat /var_uefi); hd=$(cat /var_hd)

# Name the system
cat /comp > /etc/hostname && rm /comp

# Keyboard Layout
# CHANGE THIS TO THE KEYBOARD LAYOUT YOU WANT!
loadkeys no
echo "KEYMAP=no" >> /etc/vconsole.conf

pacman --noconfirm -S dialog

# Install GRUB
pacman -S --noconfirm grub

if [ "$uefi" = 1 ]; then
    pacman -S --noconfirm efibootmgr
    grub-install --target=x86_64-efi \
        --bootloader-id=GRUB \
        --efi-directory=/boot/efi
else
    grub-install "$hd"
fi

grub-mkconfig -o /boot/grub/grub.cfg

# Set hwclock from system clock
hwclock --systohc

# SET TIMEZONE
# PLEASE SET THIS TO YOUR DESIRED TIMEZONE
# To list timezones: 'timedatectl list-timezones'
timedatectl set-timezone "Europe/Oslo"

# Set locale/lang.
# Change it to whatever you want if you don't want english.
# Run 'cat /etc/locale.gen' to see all available
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Root PW and User Creation

# No argument: ask for a username.
# One argument: use the username passed as argument.
function config_user() {
    if [ -z "$1" ]; then
        dialog --no-cancel --inputbox "Please enter your username." \
            10 60 2> name
    else
        echo "$1" > name
    fi
    dialog --no-cancel --passwordbox "Enter your password." \
        10 60 2> pass1
    dialog --no-cancel --passwordbox "Confirm your password." \
        10 60 2> pass2
    while [ "$(cat pass1)" != "$(cat pass2)" ]
    do
        dialog --no-cancel --passwordbox \
            "Passwords do not match.\n\nEnter password again." \
            10 60 2> pass1
        dialog --no-cancel --passwordbox \
            "Retype your password." \
            10 60 2> pass2
    done

    name=$(cat name) && rm name
    pass1=$(cat pass1) && rm pass1 pass2

    # Create user if doesn't exist
    if [[ ! "$(id -u "$name" 2> /dev/null)" ]]; then
        dialog --infobox "Adding user $name..." 4 50
        useradd -m -g wheel -s /bin/bash "$name"
    fi

    # Add password to user
    echo "$name:$pass1" | chpasswd
}

dialog --title "root password" \
    --msgbox "It's time to add a password for the root user" \
    10 60
config_user root

dialog --title "Add User" \
    --msgbox "Let's create another user." \
    10 60
config_user

# Save your username for the next script.
echo "$name" > /tmp/user_name

# Save your username for the next script.
echo "$name" > /tmp/user_name

# Ask to install all your apps / dotfiles.
dialog --title "Continue installation" --yesno \
    "Do you also want to install apps and dotfiles? (See README for details)" \
10 60 \
&& curl https://raw.githubusercontent.com/LarsJohansen\
/arch_installer/main/install_apps.sh > /tmp/install_apps.sh \
&& bash /tmp/install_apps.sh

