#!/bin/sh

setup_fedora_hibernate(){
  swp_size="$(sed -n 's/ kB//; /MemTotal/ s/.*: //p' /proc/meminfo)K" && echo ${swp_size}
	swp_size=$(( ( ${swp_size%K} / 1024 / 1024 + 3 ) / 2 * 2 ))G && echo ${swp_size}

	# swp_size=34G

	btrfs filesystem mkswapfile --size ${swp_size} /var/swap
	swapon /var/swap

	seinfo -t | grep swap
	
	semanage fcontext -l -C
	semanage fcontext -a -f f -t swapfile_t "/var(/swap.*)?"
	restorecon -Rv /var/swap

	SWAP_OFFSET=$(btrfs inspect-internal map-swapfile -r /var/swap)
	SWAP_UUID=$(findmnt -no UUID -T /var/swap)
	RESUME_ARGS="resume=UUID=${SWAP_UUID} resume_offset=${SWAP_OFFSET}"

	echo "${RESUME_ARGS}"

	# vi /etc/default/grub

	grub2-mkconfig -o /boot/grub2/grub.cfg
	dracut -fv

	# update-initramfs
	# update-grub

cat <<-EOF | sudo tee /etc/systemd/system/hibernate-preparation.service
[Unit]
Description=Enable swap file before hibernate
Before=systemd-hibernate.service

[Service]
User=root
Type=oneshot
ExecStart=/usr/sbin/swapon /var/swap

[Install]
WantedBy=systemd-hibernate.service
EOF

cat <<-EOF | sudo tee /etc/systemd/system/hibernate-resume.service
[Unit]
Description=Disable swap after resuming from hibernation
After=hibernate.target

[Service]
User=root
Type=oneshot
ExecStart=/usr/sbin/swapoff /var/swap

[Install]
WantedBy=hibernate.target
EOF

systemctl enable hibernate-preparation.service
systemctl enable hibernate-resume.service

mkdir -p /etc/systemd/system/systemd-logind.service.d/
cat <<-EOF | sudo tee /etc/systemd/system/systemd-logind.service.d/override.conf
[Service]
Environment=SYSTEMD_BYPASS_HIBERNATION_MEMORY_CHECK=1
EOF

mkdir -p /etc/systemd/system/systemd-hibernate.service.d/
cat <<-EOF | sudo tee /etc/systemd/system/systemd-hibernate.service.d/override.conf
[Service]
Environment=SYSTEMD_BYPASS_HIBERNATION_MEMORY_CHECK=1
EOF
}

setup_fedora_hibernate
