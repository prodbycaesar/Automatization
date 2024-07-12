#!/bin/bash
# debugging and process cleaning
set -euo pipefail
trap 'echo "Error: The script got aborted."; exit 1' INT TERM

# global directory variables 
terraform_dir="/home/j4s/auto/terraform"
ansible_host_dir="/etc/ansible/hosts"
ansible_playbook="/home/j4s/auto/ansible"
log_dir="/var/vm_deployment/logs"
credentials_dir="/home/j4s/auto/cred"

#create log directory if not already created
mkdir -p $log_dir

# terraform deployment function
deployment() {
    echo ""
    echo "INSTALLATION"
    echo "-------------"
    echo "insert config:"
    echo "-------------"
    echo ""
    echo "please insert the name of the deployment:"
    echo ""
    read depl_name
    echo ""
    echo "please insert the start id of the vm"
    echo ""
    read vm_id
    echo ""
    echo "please insert how many vms you want to deploy (no input equals one vm)"
    echo ""
    read vm_count
    echo ""

    # check if read variables are all set
    if [ -z "depl_name" ] || [ -z "vm_id" ]; then
        echo: "Error: one or more variables not set."
        exit 1
    fi

    if [ -z "$vm_count" ]; then
        vm_count=1
        echo "1 vm will be deployed" >> $log_dir/$depl_name.log 2>&1
    else
        echo "$vm_count vms will be deployed" >> $log_dir/$depl_name.log 2>&1
    fi
 
    # create new workspace and check if creation was successfully
    terraform workspace new $depl_name >> $log_dir/$depl_name.log 2>&1
    if [ $? -eq 0 ]; then
        echo "created workspace" >> $log_dir/$depl_name.log 2>&1
    else
        echo "Error: workspace could not be created. please check $depl_name.log."
        exit 1
    fi

    # create new deployment directory and check if creation was successfully
    mkdir -p "$terraform_dir/deployments/"
    if [ $? -eq 0 ]; then
        echo "deployment directory created" >> $log_dir/$depl_name.log 2>&1
    else
        echo "Error: directory could not be created. please check $depl_name.log."
        exit 1
    fi

    # create terraform deployment plan in dedicated directory
    cd $terraform_dir
    terraform plan --out "$depl_name.tfplan" -var="vm_count=$vm_count" -var="vm_id=$vm_id" -var="depl_name=$depl_name" >> $log_dir/$depl_name.log 2>&1


    # deployment summarize before execution
    echo "----------"
    echo "summarize:"
    echo "----------"
    echo ""
    echo "deployment name: $depl_name"
    echo "deployment id: $vm_id"
    echo "vm count: $vm_count"
    echo ""
    # terraform execution with check if installation should start
    echo "start installation? (y/n)"
    read start_inst

    if [ $start_inst == "y" ]; then
        echo "starting installation ..."
        terraform apply "$depl_name.tfplan" >> $log_dir/$depl_name.log 2>&1
        mv $terraform_dir/$depl_name.tfplan $terraform_dir/deployments
        echo "installation done."
    else
       echo "installation aborted."
       echo "logs in $log_dir."
       exit 1
    fi 

}

# ansible update/upgrade function
upgrade() {
    ansible-playbook --vault-password-file $credentials_dir/.vault_pass --ssh-extra-args='-o StrictHostKeyChecking=no' $ansible_playbook/vm_initial_update.ansible.yml
    echo "updated and upgraded all hosts in the $ansible_host_dir file, but watch ansible output."
}

# vm and dependency deletion function
deletion() {
    echo ""
}

# bind9 dns config
dns_config() {
    echo "starting dns config"
    # loop for multiple deployments
    for ((i=1; i<=$vm_count; i++))
    do
        vm_ip="10.10.21.$vm_id"

        vm_ip_config="$depl_name$vm_id         IN     A      $vm_ip"
        #scp /tmp/vm_ip.txt raspi:/tmp/vm_ip_tmp.txt >> $log_dir/$depl_name.log 2>&1
        #cat /tmp/vm_ip_tmp.txt >> /bind9/config/db.caesarlab.cc

        ssh raspi << EOF >> $log_dir/$depl_name.log 2>&1
            echo "$vm_ip_config" >> /bind9/config/db.caesarlab.cc
            cd /bind9
            docker-compose restart
EOF
        vm_id=$((vm_id + 1))   
    done
    echo ""
    echo "dns config updated."
}

echo "Proxmox Terraform deployment"
echo "|--------------|------------|"
echo "| Install      |      i     |"
echo "|--------------|------------|"
echo "| Update       |      u     |"
echo "|--------------|------------|"
echo "| Delete       |      d     |"
echo "|--------------|------------|"
echo ""
echo "please insert your action."
read init_selection

case $init_selection in
    i)
        deployment
        dns_config
        echo ""
        echo "-----------------------------"
        echo "Deployment has been finished." 
        echo "-----------------------------"
        ;;
    u)
        upgrade
        echo ""
        echo "-----------------------------"
        echo "Update has been finished." 
        echo "-----------------------------"
        ;;
    d)
        #tba
        ;;
    *)
        echo "Invalid selection. Please choose 'i', 'u' or 'd'"
esac