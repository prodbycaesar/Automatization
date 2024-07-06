# Variables
variable "ci_pw" {
        type =  string
        sensitive = true
}
variable "vm_count" {
    type = number
    default = 1
}

variable "vm_id" {
    type = number
}

# Create vms
resource "proxmox_vm_qemu" "j4s_template" {
    count = var.vm_count
    name = "j4stest${var.vm_id + count.index}"
    target_node = "caesarlab"
    clone = "templateV3"
    full_clone = true
    vmid = "21${var.vm_id + count.index}"
    os_type = "cloud-init"
    qemu_os = "l26"
    sockets = 1
    cores = 4
    cpu = "host"
    memory = 4096
    scsihw = "virtio-scsi-pci"
    bootdisk = "scsi1"

    disks {
        scsi {
            scsi0 {
                disk {
                    size = "32G"
                    storage = "local-lvm"
                }
            }
            scsi1 {
                cloudinit {
                    storage = "local-lvm"
                }
            }
        }
    }

    network {
        model = "virtio"
        bridge = "vmbr0"
        firewall = false
        link_down = false
    }

    # Cloud init
    ciuser = "root"
    cipassword = var.ci_pw
    sshkeys = file("/home/j4s/auto/cred/adminvm.pub")
    ipconfig0 = "ip=10.10.21.${var.vm_id + count.index}/16,gw=10.10.0.1"
    nameserver = "10.10.20.5"

    # Set hostname
    provisioner "remote-exec" {
        connection {
            timeout     = "1m"
            type        = "ssh"
            user        = "root"
            private_key = file("/root/.ssh/id_rsa")
            host        = "10.10.21.${var.vm_id + count.index}"
        }
        inline = [
            "sudo hostnamectl set-hostname j4stest${var.vm_id}"
        ]
    }

    # Ansible script
    provisioner "local-exec" {
        command = <<EOT
            echo "[new_servers]" > /tmp/new_hosts
            echo "10.10.21.${var.vm_id + count.index}" >> /tmp/new_hosts
        EOT
    }

    provisioner "local-exec" {
        command = <<EOT
            ansible-playbook --vault-password-file /home/j4s/auto/cred/.vault_pass --ssh-extra-args='-o StrictHostKeyChecking=no' -i /tmp/new_hosts /home/j4s/auto/ansible/vm_config.ansible.yml
        EOT
    }

    provisioner "local-exec" {
        command = <<EOT
            echo "10.10.21.${var.vm_id + count.index}" >> /etc/ansible/hosts
        EOT
    }

}

