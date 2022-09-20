packer {
  required_plugins {
    proxmox = {
      version = " >= 1.0.1"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "proxmox-debian-11" {
  proxmox_url      = "https://45.12.65.130:8006/api2/json"
  vm_name          = "debian-11-docker-template-ci-vm"
  iso_file         = "local:iso/debian-11.4.0-amd64-netinst.iso"
  iso_checksum     = "32c7ce39dbc977ce655869c7bd744db39fb84dff1e2493ad56ce05c3540dfc40"
  username         = "${var.pm_user}"
  password         = "${var.pm_pass}"
  node             = "Poincare"
  iso_storage_pool = "local"

  ssh_username           = "${var.ssh_user}"
  ssh_password           = "${var.ssh_pass}"
  ssh_timeout            = "10m"
  ssh_pty                = true
  ssh_handshake_attempts = 1000

  http_directory = "http"
  boot_key_interval= "1ms"
  boot_command   = [
    "<esc><wait>",
    "auto <wait>",
    "netcfg/disable_dhcp=true ",
    "netcfg/disable_autoconfig=true ",
    "netcfg/use_autoconfig=false ",
    "netcfg/get_ipaddress=45.12.65.131 ",
    "netcfg/get_netmask=255.255.240.0 ",
    "netcfg/get_gateway=45.12.65.129 ",
    "netcfg/get_nameservers=188.93.16.19 8.8.8.8 ",
    "netcfg/confirm_static=true <wait> ",
    "debian-installer/allow_unauthenticated_ssl=true ",
    "preseed/url=https://raw.githubusercontent.com/sabbath666/infrastructure-platform/master/packer/docker-template/http/preseed.cfg <wait>",
    "<enter><wait>"
  ]
  boot_wait = "2s"

  insecure_skip_tls_verify = true

  template_name        = "debian-11-docker-template-ci"
  template_description = "packer generated debian-11.4.0-amd64"
  unmount_iso          = true

  pool       = "admins"
  memory     = 2000
  cores      = 2
  sockets    = 2
  os         = "l26"
  qemu_agent = true

  disks {
    type              = "scsi"
    disk_size         = "25G"
    storage_pool      = "local"
    storage_pool_type = "lvm"
    format            = "raw"
  }

  network_adapters {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = false
  }
}

build {
  sources = ["source.proxmox-iso.proxmox-debian-11"]
  provisioner "shell" {
    execute_command = "{{.Vars}} sudo -S -E sh -eux '{{.Path}}'"
    inline          = [
      "apt-get update",
      "apt-get remove --purge apache2 apache2-utils -y",
      "apt-get install ca-certificates curl gnupg lsb-release cloud-init -y",
      "mkdir -p /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
      "echo \\",
      "\"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \\",
      "$(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "apt-get update",
      "apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y",
      "groupadd docker || true",
      "usermod -aG docker packer",
      "apt-get install -y auditd audispd-plugins",
      "docker network ls --quiet | xargs docker network inspect --format '{{ .Name }}: {{ .Options }}'",
      "docker pull hello-world",
      "docker run -d --name hello-world hello-world",
      "curl https://raw.githubusercontent.com/sabbath666/infrastructure-platform/master/packer/docker-template/http/daemon.json --output /etc/docker/daemon.json",
      "curl https://raw.githubusercontent.com/sabbath666/infrastructure-platform/master/packer/docker-template/http/audit.rules --output /etc/audit/rules.d/audit.rules",
      "systemctl restart docker",
      "service auditd start",
      "git clone https://github.com/docker/docker-bench-security.git",
      "openssl req -newkey rsa:4096 -x509 -sha256 -days 3650 -nodes -out /etc/ssl/nginx.crt -keyout /etc/ssl/nginx.key -subj '/C=RU/ST=Denial/L=Rostov-on-Don/O=CIB/CN=localhost'"
      "rm -rf /etc/network/interfaces"
    ]
  }
}