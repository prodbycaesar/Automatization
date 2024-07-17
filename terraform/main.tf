# variables
variable "ci_pw" {
        type =  string
        sensitive = true
}

variable "depl_name" {
    type = string
}

variable "vm_id" {
    type = number
}

variable "vm_count" {
    type = number
    default = 1
}



# create vms
resource "proxmox_vm_qemu" "j4s_template" {
    count = var.vm_count
    # name with deployment name + id
    # counts up +1 in a multiple deployment scenario
    name = "${var.depl_name}${var.vm_id + count.index}"
    target_node = "caesarlab"
    clone = "templateV3"
    full_clone = true
    # counts up +1 in a multiple deployment scenario
    vmid = "21${var.vm_id + count.index}"
    os_type = "cloud-init"
    qemu_os = "l26"
    sockets = 1
    # cpu cores per vm
    cores = 4
    cpu = "host"
    # ram per vm
    memory = 4096
    scsihw = "virtio-scsi-pci"
    bootdisk = "scsi1"

    disks {
        scsi {
            scsi0 {
                disk {
                    # disk size per vm
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

    # cloud init config
    # sets root user, ssh keys, network config and dns
    ciuser = "root"
    cipassword = var.ci_pw
    sshkeys = file("/home/j4s/auto/cred/adminvm.pub")
    ipconfig0 = "ip=10.10.21.${var.vm_id + count.index}/16,gw=10.10.0.1"
    nameserver = "10.10.20.5"

    # set hostname
    provisioner "remote-exec" {
        connection {
            timeout     = "1m"
            type        = "ssh"
            user        = "root"
            private_key = file("/root/.ssh/id_rsa")
            host        = "10.10.21.${var.vm_id + count.index}"
        }
        # set vm static hostname
        inline = [
            "sudo hostnamectl set-hostname ${var.depl_name}${var.vm_id}"
        ]
    }

    # ansible script
    # add server to tmp serverfile for deployment
    provisioner "local-exec" {
        command = <<EOT
            echo "[new_servers]" > /tmp/new_hosts
            echo "10.10.21.${var.vm_id + count.index}" >> /tmp/new_hosts
        EOT
    }
    
    # deploy ansible playbook for inital config and kubernetes config
    provisioner "local-exec" {
        command = <<EOT
            ansible-playbook --vault-password-file /home/j4s/auto/cred/.vault_pass.txt --ssh-extra-args='-o StrictHostKeyChecking=no' -i /tmp/new_hosts /home/j4s/auto/ansible/vm_inital_config.ansible.yml
            ansible-playbook --ssh-extra-args='-o StrictHostKeyChecking=no' -i /tmp/new_hosts /home/j4s/auto/ansible/ansible/kubernetes_initial_config.ansible.yml

        EOT
    }
    # add servers to permanent ansible host file
    provisioner "local-exec" {
        command = <<EOT
            echo "10.10.21.${var.vm_id + count.index}" >> /etc/ansible/hosts
        EOT
    }

}



