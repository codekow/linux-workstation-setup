#!/bin/bash

setup_dnf_brave_browser(){
  # https://brave.com/linux
  sudo dnf -y install dnf-plugins-core

  sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
  sudo dnf -y install brave-browser
}

setup_dnf_vscode(){
  # https://code.visualstudio.com/docs/setup/linux#_rhel-fedora-and-centos-based-distributions

  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null

  dnf check-update
  sudo dnf -y install code # or code-insiders
}

download_bins(){
  BIN_PATH=${HOME}/bin
  . <(curl -Ls https://raw.githubusercontent.com/redhat-na-ssa/demo-ai-gitops-catalog/refs/heads/main/scripts/library/bin.sh)
  bin_check rclone
  bin_check restic

  rclone completion bash - | sudo tee /etc/profile.d/rclone.sh
  restic generate --bash-completion - | sudo tee /etc/profile.d/restic.sh
  
  PATH=${HOME}/bin:${PATH}
  export PATH
}

fedora_update(){
  sudo dnf -y upgrade --refresh
}

ubuntu_update(){
  sudo apt update
  sudo apt upgrade -y
}

setup_no_password_sudo(){
  # echo "${USER} ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/"${USER}"
  echo "%wheel ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/wheel
}

setup_flatpak_software(){
  [ -e fp-packages.txt ] || return 1
  flatpak -y install flathub $(cat fp-packages.txt)
}

setup_dnf_software(){
  [ -e fedora/dnf-packages.txt ] || return 1
  sudo dnf -y install $(grep -v ^group fedora/dnf-packages.txt)
  sudo dnf -y group install $(sed -n '/^group/ s/^group//p' fedora/dnf-packages.txt)
}

setup_apt_software(){
  [ -e ubuntu/apt-packages.txt ] || return 1
  sudo apt update
  sudo apt -y upgrade
  sudo apt install -y $(grep -v ^group ubuntu/apt-packages.txt)
}

setup_dnf_display_link(){
  DISPLAY_LINK_RPM=https://github.com/displaylink-rpm/displaylink-rpm/releases/download/v6.2.0-1/fedora-42-displaylink-1.14.16-1.github_evdi.x86_64.rpm
  sudo dnf -y install "${DISPLAY_LINK_RPM}"
}

setup_user(){
  sudo usermod -a -G libvirt,disk,cdrom,floppy,kvm,users,dialout "${USER}"
}

setup_clevis_tpm(){
  sudo clevis luks bind -d /dev/nvme0n1p3 -s1 tpm2 '{"hash":"sha256","pcr_ids":"0,7,11"}'
  sudo systemd-analyze pcrs | sudo tee /root/pcrs
  sudo dracut --regenerate-all --force
}

setup_dconf(){
  [ -e dconf-dump ] || return 1
  dconf load / < dconf-dump

  # fix terminal transparency
  TERM_UUID=$(dconf read /org/gnome/Ptyxis/default-profile-uuid | sed "s@'@@g")
  dconf write "/org/gnome/Ptyxis/Profiles/${TERM_UUID}/opacity" 0.9375


cat << EOF | sudo tee /etc/dconf/db/local.d/10-power
[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-timeout=0
sleep-inactive-ac-type='nothing'
sleep-inactive-battery-timeout=900
sleep-inactive-battery-type='suspend'
EOF

cat << EOF | sudo tee /etc/dconf/db/local.d/20-session
[org/gnome/desktop/session]
idle-delay=uint32 0
EOF

cat << EOF | sudo tee /etc/dconf/db/local.d/00-media-automount
[org/gnome/desktop/media-handling]
automount=false
automount-open=false
autorun-never=true
EOF

}

setup_gnome_extensions(){
  python -m venv venv
  . venv/bin/activate

  pip install -U pip
  pip install gnome-extensions-cli

  gnome-extensions-cli install $(cat g-extensions.txt)
  gnome-extensions-cli enable $(cat g-extensions.txt)
  gnome-extensions-cli update

  deactivate
  rm -rf venv
}

setup_obs(){
  mkdir -p ~/.config/obs-studio/plugins
}

tweaks_fedora(){
  # fix hidraw access
  echo 'KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", TAG+="uaccess"' | sudo tee /etc/udev/rules.d/99-hidraw-permissions.rules
  sudo udevadm control --reload-rules && sudo udevadm trigger

  # fingerprint reader enable
  # https://www.bentasker.co.uk/posts/documentation/linux/enabling-fingerprint-authentication-on-linux.html
  sudo authselect enable-feature with-fingerprint
  sudo authselect apply-changes

}

tweak_fedora_old_ssh(){
# https://discussion.fedoraproject.org/t/fedora-41-ssh-to-rhel6-error-in-libcrypto/135999/12

sudo update-crypto-policies --set DEFAULT:SHA1

cat << EOF | sudo tee /etc/crypto-policies/policies/modules/SHA1-SSL-SIG.pmod
# https://discussion.fedoraproject.org/t/fedora-41-ssh-to-rhel6-error-in-libcrypto/135999/12
# Unblock openssl sha1 signatures for ssh to <RH6
__openssl_block_sha1_signatures = 0
EOF

sudo update-crypto-policies --set DEFAULT:SHA1-SSL-SIG
}

download_printer_driver(){
  echo "https://in.canon/en/support/0100924010"
}

setup_fedora(){
  fedora_update

  setup_dnf_software
  setup_dnf_display_link
  
  setup_flatpak_software
  setup_vscode

  setup_dconf
  setup_gnome_extensions
  setup_clevis_tpm
  setup_no_password_sudo
  setup_user
  tweaks_fedora

  download_printer_driver
  # setup_obs
}

setup_ubuntu(){
  ubuntu_update
  setup_apt_software
}

main(){
  echo "Starting OS configuration..."
  printf " Complete"
}

main
