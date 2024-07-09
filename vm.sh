#!/bin/bash
# debugging and process cleaning
set -euo pipefail
trap 'echo "Error: The script got aborted."; exit 1' INT TERM

# global directory variables 
terraform_dir="/home/j4s/auto/terraform"
ansible_host_dir="/etc/ansible/hosts"
log_dir="/var/vm_deployment/logs"

#create log directory if not already created
mkdir -p $log_dir

# terraform deployment function
deployment() {
    echo "please insert the name of the deployment:"
    read depl_name
    
    echo "please insert the start id of the vm"
    read vm_id

    echo "please insert how many vms you want to deploy (no input equals one vm)"
    read vm_count

    # check if read variables are all set
    if [ -z "depl_name" ] || [ -z "vm_id" ]; then
        echo: "Error: one or more variables not set."
        exit 1
    fi

    if [ -z "vm_count" ]; then
        vm_count="1"
        echo "1 vm will be deployed" >> $log_dir/$depl_name.log 2>&1
    else
        echo "$vm_count vms will be deployed" >> $log_dir/$depl_name.log 2>&1
    fi
 
    # create new workspace and check if creation was successfully
    terraform workspace create $depl_name >> $log_dir/$depl_name.log 2>&1
    if [ $? -eq 0 ]; then
        echo "created workspace" >> $log_dir/$depl_name.log 2>&1
    else
        echo "Error: workspace could not be created. please check $depl_name.log."
        exit 1
    fi

    # change workspace to new deployment workspace
    terrafrom workspace select $depl_name >> $log_dir/$depl_name.log 2>&1

    # create new deployment directory and check if creation was successfully
    mkdir -p "$terraform_dir/depoyments/$depl_name"
    if [ $? -eq 0 ]; then
        echo "deployment directory created" >> $log_dir/$depl_name.log 2>&1
    else
        echo "Error: directory could not be created. please check $depl_name.log."
        exit 1
    fi

    # create terraform deployment plan in dedicated directory
    terraform plan --out "$terraform_dir/depoyments/$depl_name/$depl_name.tfplan" -var="vm_count=$vm_count" -var="vm_id=$vm_id" -var="depl_name=$depl_name" >> $log_dir/$depl_name.log 2>&1

    # deployment summarize before execution
    echo "summarize:"
    echo "deployment name: $depl_name"
    echo "deployment id: $vm_id"
    echo "vm count: $vm_count"
    echo ""
    # terraform execution with check if installation should start
    echo "start installation? (y/n)"
    read start_inst

    if [ $start -eq "y"]; then
        terraform apply "$depl_name.tfplan"
    else
       echo "installation aborted"
       exit 1
    fi 

}

# ansible update/upgrade function
upgrade() {
    ansible-playbook --vault-password-file /home/j4s/auto/cred/.vault_pass --ssh-extra-args='-o StrictHostKeyChecking=no' /home/j4s/auto/ansible/vm_update.ansible.yml
    echo "updated and upgraded all hosts in the $ansible_host_dir file, but watch ansible output."
}

# vm and dependency deletion function
deletion() {
}

# bind9 dns config
dns_config() {

    # loop for multiple deployments
    for ((i=1; i<=$vm_count; i++))
    do
        vm_ip="10.10.21.$vm_id"

        ssh -i raspi << 'EOF'
            sed -i "\$a \$depl_name            IN      A       \$vm_ip" /bind9/config/db.caesarlab.cc
            cd /bind9
            docker-compose restart
EOF
        vm_id=$((vm_id + 1))   
    done
}

echo "Proxmox Terraform deployment"
echo "--> install vms (i)"
echo "--> update vms  (u)"
echo "--> delete vms  (d)"

read init_selection

case $init_selection in
    i)
        deployment
        dns_config
        ;;
    u)
        upgrade
        ;;
    d)
        #tba
        ;;
    *)
        echo "Invalid selection. Please choose 'i', 'u' or 'd'"