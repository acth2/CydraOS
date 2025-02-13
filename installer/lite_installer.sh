#!/bin/bash
trap '' 2

BOLD_WHITE="\e[1;37m"
BOLD_BLUE="\e[1;34m"
BOLD_PURPLE="\e[1;35m"
RESET_COLOR="\e[0m"

#                       VARS                    #

IS_BIOS=3
IS_EFI=1
SWAPUSED=0
WIRELESS=0
SYSKERNEL_VER="5.19.2"

log() {
        echo -e "[${BOLD_BLUE}LOG${RESET_COLOR}] $*"
}

section() {
        echo -e "[${BOLD_PURPLE}${1}${RESET_COLOR}] Entering '${BOLD_WHITE}${1}${RESET_COLOR}' process"
}

# - - - - - - - - - - - - - #







#               INFORMATIONS            #

function welcome_menu {
        log "Welcome menu"
        dialog --msgbox "Welcome into CydraProject (Lite) installation guide!" 15 50
}

function print_licences {
        log "Showing licenses"
        dialog --msgbox "Licenses on: https://github.com/acth2/CydraProject/blob/main/LICENSE" 15 50
}


function print_credits {
        log "Showing credits"
        dialog --msgbox "Thanks to AinTea for the installer !" 15 50
        dialog --msgbox "Thanks to Emmett Syazwan for the LFS iso template" 15 50
        dialog --msgbox "Thanks to the LFS & BLFS team for everything !" 15 50
        dialog --msgbox "Thanks to YOU for installing CydraLite !" 15 50
}


function INFORMATIONS {
        section "INFORMATIONS"

        welcome_menu
        print_licences
        print_credits
}


# - - - - - - - - - - - - - #


function get_language {
        log "Getting language"

        language="$(dialog --title "Dialog title" --inputbox "Enter language name (fr / us):" 0 0 --stdout)"
        if [[ -n "${language}" ]]; then
            loadkeys "${language}"
            log "Language set to '${language}'"
        else
            log "Empty output, US by default.."
            sleep 2
        fi

}

function get_informations {
        log "Getting machine name"
        machine_name="$(dialog --title "System informations" --inputbox "Enter machine name:" 0 0 --stdout)"
        username="$(dialog --title "System informations" --inputbox "Enter your username:" 0 0 --stdout)"
        password="$(dialog --title "System informations" --insecure --passwordbox "Enter machine password" 0 0 --stdout)"
}


function configure_network {
        if dialog --yesno "Does the system should use Wireless connection?" 0 0 --stdout; then
            WIRELESS=1
            log "Configuring network"

            log "Getting network name and password"
            network_name="$(dialog --title "Network name" --inputbox "Enter network name:" 0 0 --stdout)"
            network_password="$(dialog --title "Network password" --insecure --passwordbox "Enter network password:" 0 0 --stdout)"

            log "Configuration of the network."

            mkdir "/root/installdir"
            mv "/etc/unusedwireless" "/root/installdir/25-wireless.network"
            log "Network configured"
            sleep 2
        else
            rm -f "/etc/unusedwirless"
            log "Network configured"
            sleep 2
        fi
}


function GET_USER_INFOS {
        section "GET USER INFOS"

        get_language
        get_informations
        configure_network

        echo -e "\n"
}


# - - - - - - - - - - - - - #




#               DISK PARTITION          #

function get_devices {
    awk '{print $4}' /proc/partitions | grep -Ev '^(loop0|sr0|name)$'
}

function getefi_devices {
    awk '{print $4}' /proc/partitions | grep -Ev "^(loop0|sr0|name|${chosen_partition})$"
}

function DISK_PARTITION {

    devices=$(get_devices)

    if [ -z "$devices" ]; then
        dialog --msgbox "No devices found.." 6 40
        exit 1
    fi

    menu_entries=()
    while read -r device; do
        menu_entries+=("$device" "$device")
    done <<< "$devices"

    chosen_partition=$(dialog --no-cancel --clear --title "Select The System Device" \
                    --menu "Choose The System Device:" 15 50 4 \
                    "${menu_entries[@]}" \
                    2>&1 >/dev/tty)

    if [ -d /sys/firmware/efi ]; then
        devices=$(getefi_devices)
        menu_entries=()
        while read -r device; do
            menu_entries+=("$device" "$device")
        done <<< "$devices"

        efi_partition=$(dialog --no-cancel --clear --title "Select the EFI Device" \
                        --menu "Choose the EFI device:" 15 50 4 \
                        "${menu_entries[@]}" \
                        2>&1 >/dev/tty)
        fi
        chosen_partition="/dev/${chosen_partition}"
        efi_partition="/dev/${efi_partition}"
}

function DISK_INSTALL {
    section "INSTALL DISK"
    mkdir -p "/mnt/install"
    mkdir -p "/mnt/efi"
    mkdir -p "/mnt/temp"
    mkfs.ext4 -F ${chosen_partition}
}

#               GRUB CONFIGURATION              #

function GRUB_CONF {
    section "GRUB CONFIGURING"
    chosen_partition_uuid=$(blkid -s UUID -o value ${chosen_partition})
    swap_partition_uuid=$(blkid -s UUID -o value ${swap_partition})
    efi_partition_uuid=$(blkid -s UUID -o value ${efi_partition})
    if [ ! -d /sys/firmware/efi ]; then
        log "GRUB will be installed on ${chosen_partition}/boot for BIOS boot."
        sleep 2
    else
        mainPartitionUuid=$(blkid ${chosen_partion})
        if [ SWAPUSED = 0 ]; then
            swapPartitionUuid=$(blkid ${swap_partion})
        fi
        efiPartitionUuid=$(blkid ${efi_partion})

        if [[ "$efi_partition" =~ [0-9]$ ]]; then
             efi_device=$(echo "$efi_partition" | sed 's/[0-9]*$//')
             (
             echo "d"
             echo "n"
             echo "p"
             echo "1"
             echo
             echo
             echo "w"
             ) | fdisk "${efi_partition}"
             log "The partition ${efi_partition} has been set to EFI System Partition."

        else
              (
              echo "n"
              echo "p"
              echo "1"
              echo
              echo
              echo "w"
              ) | fdisk "${efi_partition}"
              log "An EFI partition has been created on the device ${efi_partition}."
        fi
        mkfs.vfat -F 32 "${efi_partition}1"
        mkdir /mnt/efi
        mount "${efi_partition}1" "/mnt/efi"
        log "The partition ${efi_partition}1 has been formatted as FAT32."
        grub-install "${efi_partition}1" --root-directory=/mnt/efi --target=x86_64-efi --removable
        rm -f "/mnt/efi/boot/grub/grub.cfg"
    fi
    rm -rf "/mnt/install/boot/grub/grub.cfg"
    rm -rf "/mnt/efi/boot/grub/grub.cf"
    mkdir -p /mnt/efi/boot/grub
    touch "/mnt/efi/boot/grub/grub.cfg"
    local disk=$(echo "${chosen_partition}1" | sed -E 's|/dev/([a-z]+)[0-9]*|\1|')
    local partition_letter=$(echo "${chosen_partition}1" | grep -o '[0-9]*$')
    local disk_letter=${disk:2:1}
    local grub_disk_letter=$(( $(printf "%d" "'${disk_letter}") - $(printf "%d" "'a") ))
    echo "set default=0" >> "/mnt/efi/boot/grub/grub.cfg"
    echo "set timeout=5" >> "/mnt/efi/boot/grub/grub.cfg"
    echo "" >> "/mnt/efi/boot/grub/grub.cfg"
    echo "insmod part_gpt" >> "/mnt/efi/boot/grub/grub.cfg"
    echo "insmod ext2" >> "/mnt/efi/boot/grub/grub.cfg"
    echo "set root=(hd${grub_disk_letter},${partition_letter})" >> "/mnt/efi/boot/grub/grub.cfg"
    echo "insmod all_video" >> "/mnt/efi/boot/grub/grub.cfg"
    echo "if loadfont /boot/grub/fonts/unicode.pf2; then" >> "/mnt/efi/boot/grub/grub.cfg"
    echo "  terminal_output gfxterm" >> "/mnt/efi/boot/grub/grub.cfg"
    echo "fi" >> "/mnt/efi/boot/grub/grub.cfg"
    echo "" >> "/mnt/efi/boot/grub/grub.cfg"
    echo 'menuentry "GNU/Linux, CydraLite Release V2.0"  {' >> "/mnt/efi/boot/grub/grub.cfg"
    echo "  echo Loading GNU/Linux CydraLite V02..." >> "/mnt/efi/boot/grub/grub.cfg"
    echo "  linux /boot/vmlinuz-5.19.2 init=/usr/lib/systemd/systemd root=${chosen_partition}1 ro" >> "/mnt/efi/boot/grub/grub.cfg"
    echo "  echo Loading ramdisk..." >> "/mnt/efi/boot/grub/grub.cfg"
    echo "  initrd /boot/initrd.img-5.19.2" >> "/mnt/efi/boot/grub/grub.cfg"
    echo "}" >> "/mnt/efi/boot/grub/grub.cfg"
    echo "" >> "/mnt/efi/boot/grub/grub.cfg"
    echo 'submenu "Advanced Options for CydraLite V2.0"  {'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '      menuentry "SAFE MODE"  {'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        echo Loading GNU/Linux CydraLite V02...'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo "        linux /boot/vmlinuz-5.19.2 init=/usr/lib/systemd/systemd root=${chosen_partition}1 ro failsafe"  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        echo Loading ramdisk...'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        initrd /boot/initrd.img-5.19.2'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '      }'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo ''
    echo '      menuentry "QUIET MODE"  {'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        echo Loading GNU/Linux CydraLite V02...'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo "        linux /boot/vmlinuz-5.19.2 init=/usr/lib/systemd/systemd root=${chosen_partition}1 ro quiet"  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        echo Loading ramdisk...'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        initrd /boot/initrd.img-5.19.2'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '      }'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo ''
    echo '      menuentry "SINGLE MODE"  {'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        echo Loading GNU/Linux CydraLite V02...'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo "        linux /boot/vmlinuz-5.19.2 init=/usr/lib/systemd/systemd root=${chosen_partition}1 ro single"  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        echo Loading ramdisk...'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        initrd /boot/initrd.img-5.19.2'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '      }'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo ''
    echo '      menuentry "SPLASH MODE"  {'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        echo Loading GNU/Linux CydraLite V02...'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo "        linux /boot/vmlinuz-5.19.2 init=/usr/lib/systemd/systemd root=${chosen_partition}1 ro splash"  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        echo Loading ramdisk...'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        initrd /boot/initrd.img-5.19.2'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '      }'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo ''
    echo '      menuentry "NOMODESET MODE"  {'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        echo Loading GNU/Linux CydraLite V02...'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo "        linux /boot/vmlinuz-5.19.2 init=/usr/lib/systemd/systemd root=${chosen_partition}1 ro nomodeset"  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        echo Loading ramdisk...'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        initrd /boot/initrd.img-5.19.2'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '      }'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo ''
    echo '      menuentry "DEBUG MODE"  {'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        echo Loading GNU/Linux CydraLite V02...'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo "        linux /boot/vmlinuz-5.19.2 init=/usr/lib/systemd/systemd root=${chosen_partition}1 ro debug"  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        echo Loading ramdisk...'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        initrd /boot/initrd.img-5.19.2'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '      }'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo ''
    echo '     menuentry "NOFAIL MODE"  {'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        echo RIP THE OS BRUH'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo "        linux /boot/vmlinuz-5.19.2 init=/usr/lib/systemd/systemd root=${chosen_partition}1 ro nofail"  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        echo Loading ramdisk...'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '        initrd /boot/initrd.img-5.19.2'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '      }'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo '}'  >> "/mnt/efi/boot/grub/grub.cfg"
    echo 'menuentry "Firmware Setup" {' >> "/mnt/efi/boot/grub/grub.cfg"
    echo "  fwsetup" >> "/mnt/efi/boot/grub/grub.cfg"
    echo "}" >> "/mnt/efi/boot/grub/grub.cfg"
}

#               CYDRA INSTALLATION              #

function INSTALL_CYDRA {
    section "INSTALLING CYDRA"

    if [[ ! $chosen_partition =~ [0-9] ]]; then
        mkdir "/mnt/install"
        (
        echo "n"
        echo "p"
        echo "1"
        echo
        echo
        echo "w"
        ) | fdisk "${chosen_partition}"
        mkfs.ext4 -F "${chosen_partition}1"
    else
        mkfs.ext4 -F "${chosen_partition}"
    fi
    log "The partition ${chosen_partition} has been set to ext4 Partition."
    if [[ ! $chosen_partition =~ [0-9] ]]; then
        mount -t ext4 "${chosen_partition}1" "/mnt/install" 2> /dev/null
    else
        mount -t ext4 "${chosen_partition}" "/mnt/install" 2> /dev/null
    fi
    log "Copying the system into the main partition (${chosen_partition})"
    tar xf /root/system.tar.gz -C /mnt/install 2> /root/errlog.logt
    log "Configuring the system (${chosen_partition})"
    chosen_partition_uuid=$(blkid -s UUID -o value ${chosen_partition})
    swap_partition_uuid=$(blkid -s UUID -o value ${swap_partition})
    efi_partition_uuid=$(blkid -s UUID -o value ${efi_partition})
    cp -r "/mnt/temp/*" "/mnt/install" 2> /dev/null
    rm -f "/mnt/install/etc/fstab"
    touch "/mnt/install/etc/fstab"
    echo "#CydraLite FSTAB File, Make a backup if you want to modify it.." >> /mnt/install/etc/fstab
    echo "" >> /mnt/install/etc/fstab
    echo "UUID=${chosen_partition_uuid}     /            ext4    defaults            1     1" >> /mnt/install/etc/fstab
    echo "/swapfile                         swap         swap    pri=1               0     0" >> /mnt/install/etc/fstab
    rm -f /mnt/install/etc/pam.d
    mkdir -p "/mnt/install/etc/sudoers.d/" 2> /dev/null
    mkdir -p "/mnt/install/etc/pam.d/" 2> /dev/null
cat > /mnt/install/etc/sudoers.d/00-sudo << "EOF"
    Defaults secure_path="/usr/sbin:/usr/bin"
    %wheel ALL=(ALL) ALL
EOF

cat > /mnt/install/etc/pam.d/sudo << "EOF"
    auth      include     system-auth
    account   include     system-account
    session   required    pam_env.so
    session   include     system-session
EOF
    chmod 644 /mnt/install/etc/pam.d/sudo

    if [[ ${WIRELESS} = 1 ]]; then
        mv "/root/installdir/25-wireless.network" "/mnt/install/systemd/network/25-wireless.network"
    fi
    rm -f "/mnt/install/etc/wpa_supplicant.conf"
    cp -r "/etc/wpa_supplicant.conf" "/mnt/install/etc/wpa_supplicant.conf"
    log "Generating the initramfs (${chosen_partition})"
    rm -f /mnt/install/boot/initrd.img-5.19.2
chroot /mnt/install /bin/bash << 'EOF'
    cd /boot
    mkinitramfs 5.19.2 2> /dev/null
    exit
EOF
    log "Installing importants packages in the system.."
    mv /root/sudo.tar.gz /mnt/install/sources/sudo.tar.gz
    sleep 2
chroot /mnt/install /bin/bash << 'EOF'
    cd /sources
    tar xf sudo.tar.gz
    cd "sudo-1.9.15p5"
    ./configure --prefix=/usr          \
            --libexecdir=/usr/lib      \
            --with-secure-path         \
            --with-env-editor          \
            --docdir=/usr/share/doc/sudo-1.9.15p5 \
            --with-passprompt="[sudo] password for %p: " && make && make install
    exit
EOF
    if [ ! -d /sys/firmware/efi ]; then
        rm -rf /mnt/install/boot/grub
        grub-install --boot-directory=/mnt/install/boot ${chosen_partition} --force 2> /root/grub.log
        mv "/mnt/efi/boot/grub/grub.cfg" "/mnt/install/boot/grub/grub.cfg"
        log "GRUB has been installed on ${chosen_partition} for BIOS boot."
    fi
    dd if=/dev/zero of=/mnt/install/swapfile bs=1M count=2048 2> /dev/null
    chmod 600 /mnt/install/swapfile 2> /dev/null
    mkswap /mnt/install/swapfile 2> /dev/null
    log "a 2GB swapfile is created.. (${chosen_partition})"
    if [[ ${WIRELESS} == 2 ]]; then
       log "Configuring network.."
       touch /mnt/install/root/networkname
       echo "${network_name}" >> /mnt/install/root/networkname
       echo "${network_password}" >> /mnt/install/root/networkpass
chroot /mnt/install /bin/bash << 'EOF'
    export network_name=$(cat /root/networkname)
    export network_password=$(cat /root/networkpass)

    > /etc/wpa_supplicant.conf
    sudo wpa_passphrase ${network_name} ${network_password} >> /etc/wpa_supplicant.conf
    wpa_supplicant -B -i wlp3s0 -c /etc/wpa_supplicant.conf -D next

    sudo ifconfig wlp3s0 up

    rm -f /root/networkname
    rm -f /root/networkpass
    unset network_name
    unset network_password

    exit
EOF
    fi
    log "Creating and configuring the guest user"
    > /mnt/install/etc/hostname
    echo "${machine_name}" >> "/mnt/install/etc/hostname"
    echo "${username}" >> "/mnt/install/root/user"
    echo "${password}" >> "/mnt/install/root/userpass"
    sleep 3
chroot /mnt/install /bin/bash << 'EOF'
    export username=$(cat /root/user)
    export password=$(cat /root/userpass)

    useradd -m -s /bin/bash ${username}

    echo "${username}:${password}" | chpasswd

    echo "root:${password}" | chpasswd

    touch "/etc/sudoers.d/${username}"
    echo "${username} ALL=(ALL) NOPASSWD:ALL" >> "/etc/sudoers.d/${username}"
    echo "${username} ALL=(ALL) NOPASSWD:ALL" >> "/etc/sudoers"
    
    rm -f /root/userpass
    exit
EOF

    mv /root/curl.tar.xz /mnt/install/sources/curl.tar.xz
    mv /root/git.tar.xz /mnt/install/sources/git.tar.xz
chroot /mnt/install /bin/bash << 'EOF'
    export username=$(cat /root/user)
    
    cd /sources
    tar xf curl.tar.xz
    cd "curl-8.9.1"
    ./configure --prefix=/usr                       \
            --disable-static                        \
            --with-openssl                          \
            --enable-threaded-resolver              \
            --with-ca-path=/etc/ssl/certs &&
    make
    make install
    cd ..
    rm -rf curl-8.9.1/
    tar xf git.tar.xz
    cd "git-2.44.0"
    ./configure --prefix=/usr
    make
    make install
    cd /sources
    sleep 10
    exit
EOF
    rm -f /mnt/install/etc/profile
    cp -r /root/sys/postprofile /mnt/install/etc/profile
    cp -r /root/sys/postprofile /mnt/install/root/.bashrc
    cp -r /root/sys/postprofile /mnt/install/${username}/.bashrc
    mkdir -p /mnt/install/etc/profile.d
    sed -i "s/cydralite/${machine_name}/g" /mnt/install/etc/hosts
    mv /root/sys/bashcompletion /mnt/install/etc/profile.d/bash_completion.sh
    install --directory --mode=0755 --owner=root --group=root /mnt/install/etc/profile.d
    install --directory --mode=0755 --owner=root --group=root /mnt/install/etc/bash_completion.d
    mv /root/sys/dircolors /mnt/install/etc/profile.d/dircolors.sh
    mv /root/sys/extrapaths /mnt/install/etc/profile.d/extrapaths.sh
    mv /root/sys/readline /mnt/install/etc/profile.d/readline.sh
    mv /root/sys/umask /mnt/install/etc/profile.d/umask.sh
    mv /root/sys/bashrc /mnt/install/etc/bashrc.sh
    echo "export PATH=/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/bin:/usr/local/bin:/usr/sbin:/usr/local/sbin" >> /mnt/install/etc/profile
    echo "export PATH=/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/bin:/usr/local/bin:/usr/sbin:/usr/local/sbin" >> /mnt/install/root/.bashrc
    echo "export PATH=/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/bin:/usr/local/bin:/usr/sbin:/usr/local/sbin" >> /mnt/install/${username}/.bashrc
    echo 'Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' >> /mnt/install/etc/sudoers
    echo "sudo dmesg -n 3" >> /mnt/install/etc/profile
cat > /mnt/install/usr/cydraliteem << "EOF"
    #!/bin/bash

    ORANGE='\033[0;33m'
    NC='\033[0m'
    
    echo -e "${ORANGE}The cydralite package manager is brew!${NC}"
    sudo rm -f /usr/bin/apt
    sudo rm -f /usr/bin/pacman
    sudo rm -f /usr/cydraliteem
    exit 0
EOF

cat > /mnt/install/usr/bin/firstbootmsg << "EOF"
#!/bin/bash
FIRST_BOOT_FILE="/var/log/.firstbooted"
if [ ! -f "$FIRST_BOOT_FILE" ]; then
    echo "Welcome! The package manager (brew) wont work until you update it !!"
    sudo touch "$FIRST_BOOT_FILE"
fi
EOF

    echo "" >> /mnt/install/etc/profile
    echo "sudo bash /usr/bin/firstbootmsg" >> /mnt/install/etc/profile
    chmod +x /mnt/install/usr/cydraliteem
    ln -n /mnt/install/usr/cydraliteem /mnt/install/usr/bin/apt
    ln -n /mnt/install/usr/cydraliteem /mnt/install/usr/bin/pacman
    chmod +x /usr/bin/apt
    chmod +x /usr/bin/pacman
cat > /mnt/install/usr/bin/brew << "EOF"
#!/bin/bash
wget -q --spider http://google.com
if [ $? -eq 0 ]; then
    (
    echo ""
    ) | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo "Logoff to apply changes.."
    sudo rm -f /usr/bin/brew
    exit 0
else
    echo "Cant process, your computer does not have network!"
    exit 1
fi
EOF
    echo 'export PKG_CONFIG_PATH="/usr/lib/pkgconfig"' >> /mnt/install/etc/profile
    echo 'export CFLAGS="-I/home/linuxbrew/.linuxbrew/include $CFLAGS"' >> /mnt/install/etc/profile
    cp -r /root/brew /mnt/install/usr/bin/brewexec
    cp -r /root/brewupdate /mnt/install/usr/bin/brewupdate
    chmod +rwx /mnt/install/usr/bin/brew
    chmod +rwx /mnt/install/usr/bin/brewexec
    chmod +rwx /mnt/install/usr/bin/brewupdate
    rm -rf /mnt/install/sources/*
    rm -rf /root/*
    rm -rf /home/${username}/*
    chown ${username}:${username} /home/linuxbrew/.linuxbrew/var
    rm -f /mnt/install/usr/bin/cydramanager
    rm -rf /mnt/install/usr/cydramanager
    rm -rf /mnt/install/etc/cydra*
    rm -rf /mnt/install/root/*
}

#               CLEAN UP                #

function CLEAN_LIVE {
    section "CLEANING LIVECD BEFORE REBOOTING"

    umount "/mnt/install" > /dev/null 2>&1;
    umount "/mnt/efi" > /dev/null 2>&1;
    umount "/mnt/temp" > /dev/null 2>&1;
}


# - - - - - - - - - - - - - #



function main {
        section "INSTALLATION"
        INFORMATIONS
        GET_USER_INFOS
        DISK_PARTITION


        if dialog --yesno "The Installation will start. Continue?" 25 85 --stdout; then

                if [[ -z "${password}" || -z "${username}" || -z "${machine_name}" || -z "${chosen_partition}" ]]; then
                        err  "$@"
                        exit 1
                elif [[ ${WIRELESS} = 1 ]]; then
                     if [[ -z "${network_name}" || -z "${network_password}" ]]; then
                             err  "$@"
                             reboot
                     fi
                else
                        log "installation on '${chosen_partition}'"
                        if dialog --yesno "!! WARNING !! \n\nEVERY DATA ON THE DISK WILL BE ERASED.\nDo you want to continue ?" 25 85 --stdout; then
                             DISK_INSTALL
                             GRUB_CONF
                             INSTALL_CYDRA
                             CLEAN_LIVE

                             dialog --msgbox "The Installation is finished, thanks for using CydraLite !" 0 0
                             export PS1="Exiting system..."
                             stty -echo
                             clear
                        else
                             if dialog --yesno "Do you want to exit the Installation ?" 15 35 --stdout; then
                                  export PS1="Exiting system..."
                                  stty -echo
                                  clear
                             fi
                        fi
                        exit 0
                fi
        else
                main "$@"
        fi
}

function err {
        dialog --msgbox "The installation failed. The user did not gived all of the needed informations for the installation." 15 100
}

main "$@"
trap 2
