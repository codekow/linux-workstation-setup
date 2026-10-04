#!/bin/sh

setup_fedora_hibernate(){
  	swp_size="$(sed -n 's/ kB//; /MemTotal/ s/.*: //p' /proc/meminfo)K" && echo ${swp_size}
	swp_size=$(( ( ${swp_size%K} / 1024 / 1024 + 3 ) / 2 * 2 ))G && echo ${swp_size}

	echo "swp_size: ${swp_size}"
	# swp_size=34G

	btrfs subvolume create /.swap
	btrfs filesystem mkswapfile --size ${swp_size} /.swap/file
	swapon /var/swap

	seinfo -t | grep swap
	
	semanage fcontext -l -C
	semanage fcontext -a -f f -t swapfile_t "/var(/swap.*)?"
	semanage fcontext -a -t swapfile_t "/.swap(/.*)?"

	restorecon -Rv /var/swap
	restorecon -Rv /.swap

	SWAP_OFFSET=$(btrfs inspect-internal map-swapfile -r /.swap/file)
	SWAP_UUID=$(findmnt -no UUID -T /.swap/file)
	RESUME_ARGS="lockdown_hibernate.enable=1 hibernate.compressor=lz4"
	RESUME_ARGS="${RESUME_ARGS} resume=UUID=${SWAP_UUID} resume_offset=${SWAP_OFFSET}"

	echo "${RESUME_ARGS}"
	cat /sys/module/hibernate/parameters/compressor

	echo 252:0 > /sys/power/resume
	echo ${SWAP_OFFSET} > /sys/power/resume_offset

	# vi /etc/default/grub

	grub2-mkconfig -o /boot/grub2/grub.cfg
	dracut -fv

	# update-initramfs
	# update-grub

cat <<-EOF | sudo tee /etc/systemd/system/hibernate-prepare.service
[Unit]
Description=Enable swap file before hibernate
Before=systemd-hibernate.service

[Service]
User=root
Type=oneshot
ExecStart=/usr/sbin/swapon /.swap/file

[Install]
WantedBy=systemd-hibernate.service
EOF

cat <<-EOF | sudo tee /etc/systemd/system/hibernate-restore.service
[Unit]
Description=Disable swap after resuming from hibernation
After=hibernate.target

[Service]
User=root
Type=oneshot
ExecStart=/usr/sbin/swapoff /.swap/file

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
