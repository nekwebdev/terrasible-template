#cloud-config
# user configuration
users:
  - name: ${admin_user}
    doas:
      - "permit nopass ${admin_user} as root"
    groups: wheel
    shell: /bin/bash
    ssh_authorized_keys:
      - "${ssh_admin_key}"
      - "${ssh_services_key}"

# system update and upgrade
package_update: true
package_upgrade: true
package_reboot_if_required: true

# base packages
packages:
  - doas
  - bash
  - bash-completion
  - grep
  - curl
  - git
  - tzdata
  - vim
  - python3
  - iproute2

# system configuration commands
runcmd:
  # ensure user is unlocked 
  - usermod -p '*' ${admin_user}
  
  # create sudo alias for doas
  - echo "alias sudo='doas'" >> /etc/profile.d/doas-alias.sh
  - chmod +x /etc/profile.d/doas-alias.sh
  
  # create sudo symlink for doas
  - ln -sf /usr/bin/doas /usr/bin/sudo
  
  # ssh service management
  - rc-update add sshd default
  - rc-service sshd start
  
  # ssh hardening
  - sed -i '/Port/d' /etc/ssh/sshd_config
  - sed -i '/PermitRootLogin/d' /etc/ssh/sshd_config
  - sed -i '/PasswordAuthentication/d' /etc/ssh/sshd_config
  - sed -i '/ChallengeResponseAuthentication/d' /etc/ssh/sshd_config
  - sed -i '/PubkeyAuthentication/d' /etc/ssh/sshd_config
  - sed -i '/PermitEmptyPasswords/d' /etc/ssh/sshd_config
  - sed -i '/MaxAuthTries/d' /etc/ssh/sshd_config
  - sed -i '/LoginGraceTime/d' /etc/ssh/sshd_config
  - sed -i '/MaxSessions/d' /etc/ssh/sshd_config
  - sed -i '/ClientAliveInterval/d' /etc/ssh/sshd_config
  - sed -i '/ClientAliveCountMax/d' /etc/ssh/sshd_config
  - sed -i '/Compression/d' /etc/ssh/sshd_config
  - sed -i '/X11Forwarding/d' /etc/ssh/sshd_config

  - echo "Port ${ssh_port}" >> /etc/ssh/sshd_config
  - echo "PermitRootLogin no" >> /etc/ssh/sshd_config
  - echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
  - echo "ChallengeResponseAuthentication no" >> /etc/ssh/sshd_config
  - echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
  - echo "PermitEmptyPasswords no" >> /etc/ssh/sshd_config
  - echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
  - echo "LoginGraceTime 30" >> /etc/ssh/sshd_config
  - echo "MaxSessions 2" >> /etc/ssh/sshd_config
  - echo "ClientAliveInterval 30" >> /etc/ssh/sshd_config
  - echo "ClientAliveCountMax 10" >> /etc/ssh/sshd_config
  - echo "Compression no" >> /etc/ssh/sshd_config
  - echo "X11Forwarding no" >> /etc/ssh/sshd_config

  - chmod 600 /etc/ssh/sshd_config

  - rc-service sshd restart
  
  # kernel update check
  - if [ "$(uname -r)" != "$(ls -1 /lib/modules/ | grep -v grub | sort -V | tail -n1)" ]; then
      echo "reboot required due to kernel update";
      reboot;
    fi
  
  # cloud-init verification
  - echo "cloud-init schema"
  - cloud-init schema --system
  - echo "cloud-init status"
  - cloud-init status --long
