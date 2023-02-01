terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.11"
    }
  }
}

provider "proxmox" {
  pm_api_url      = "https://45.12.65.130:8006/api2/json"
  pm_tls_insecure = true
  pm_user         = "packer@pve"
  pm_password     = "JVMwh3Gly8LC1uaofW0M"

}

resource "null_resource" "ssh_init" {
  connection {
    type        = "ssh"
    user        = "packer"
    private_key = file("~/.ssh/id_rsa")
    host        = "45.12.65.131"
  }
}

resource "proxmox_vm_qemu" "docker-vm" {
  depends_on   = [null_resource.ssh_init]
  count        = 2
  name         = "docker-worker-${count.index +1}"
  agent        = 1
  os_type      = "cloud-init"
  target_node  = "Poincare"
  clone        = "debian-11-docker-template-ci-vm-555"
  ssh_user     = "packer"
  provisioner "local-exec" {
    when = create
    command = "echo \"The IP of vm '${self.name}' is '${self.default_ipv4_address}'\""
  }
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
  nameserver = "188.93.16.19"
  ipconfig0  = "ip=45.12.65.13${count.index+1}/20,gw=45.12.65.129"
}
