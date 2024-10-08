#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

declare -A tag_descriptions=(
  ["bootstrap"]="Bootstrap the Ceph cluster."
  ["add_hosts"]="Add hosts to the Ceph cluster."
  ["add_osd"]="Apply OSD (Object Storage Daemon) service specifications."
  ["add_rgw"]="Apply RGW (RADOS Gateway) service specifications."
  ["add_ingress"]="Apply ingress service specifications."
  ["preflight"]="Run preflight checks."
  ["rhel_registration"]="Register RHEL and enable required repositories."
  ["enable_ibm_repo"]="Enable IBM Ceph repository and install cephadm-ansible."
  ["update_os"]="Update the OS to the latest version and install necessary packages."
  ["add_coredns"]="Set up CoreDNS for S3 Ceph Cluster."
)

list_tags() {
  echo -e "${YELLOW}Available tags:${NC}"
  for tag in "${!tag_descriptions[@]}"; do
    echo -e "  ${GREEN}${tag}${NC}: ${tag_descriptions[$tag]}"
  done
}

usage() {
  echo -e "${YELLOW}Usage: run_ceph_deploy.sh [-t tags] [-l logfile]${NC}"
  echo "  -t, --tags    Comma-separated list of tags to run. If 'preflight' is included, preflight checks will be performed."
  echo "  -l, --logfile Path to the logfile."
  echo
  list_tags
  exit 1
}

tags=""
logfile=""
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -t|--tags)
      tags="$2"
      shift
      ;;
    -l|--logfile)
      logfile="$2"
      shift
      ;;
    *)
      usage
      ;;
  esac
  shift
done

if [ -z "$tags" ]; then
  usage
  exit 0
fi

if [ -z "$logfile" ]; then
  echo -e "${RED}Error: Logfile not specified.${NC}"
  usage
fi

command_exists() {
  command -v "$1" &> /dev/null
}

error_exit() {
  echo -e "${RED}Error: $1${NC}" >&2
  exit 1
}

IFS=',' read -r -a tag_array <<< "$tags"

# Check for 'preflight' tag
run_preflight=false
run_coredns=false
for tag in "${tag_array[@]}"; do
  if [ "$tag" == "preflight" ]; then
    run_preflight=true
  elif [ "$tag" == "add_coredns" ]; then
    run_coredns=true
  fi
done

# Read the value of distribution_origin from ceph.yml
ceph_release=$(grep 'ceph_release:' deploy_ceph/vars/ceph.yml | awk '{print $2}')
echo "ceph_release is: $ceph_release"

if [ "$run_preflight" = true ]; then
  echo -e "${GREEN}Running preflight checks...${NC}"

  if [ "$ceph_release" == "ibm" ]; then
    extra_vars="--extra-vars ceph_origin=ibm"
  elif [ -n "$ceph_release" ]; then
    # If ceph_release is set and not empty, use it
    extra_vars="--extra-vars ceph_release=$ceph_release"
  else
    # If ceph_release is empty or not set, don't pass any extra_vars
    extra_vars=""
  fi
fi

# Check if ansible-playbook exists
if ! command -v ansible-playbook &> /dev/null; then
    echo "Ansible not found, running update_os and enable_ibm_repo first..."
    ssh $(cat inventory | grep  _admin  | awk '{print $1}' | uniq) 'dnf install ansible-core -y' || error_exit "Failed to install Ansible on admin node"
fi
   
if [ "$ceph_release" == "ibm" ]; then
   echo -e "${YELLOW}IBM Ceph release detected. Downloading cephadm...${NC}"
   ansible-galaxy collection install community.general || error_exit "Failed to install ansible-galaxy on admin node"

  if [ ! -f /etc/yum.repos.d/ibm-storage-ceph-7-rhel-9.repo ]; then
    echo -e "${YELLOW}IBM Ceph repository file not found. Downloading...${NC}"
    curl -s https://public.dhe.ibm.com/ibmdl/export/pub/storage/ceph/ibm-storage-ceph-7-rhel-9.repo | sudo tee /etc/yum.repos.d/ibm-storage-ceph-7-rhel-9.repo || error_exit "Failed to download IBM Ceph repository"
  else
    echo -e "${GREEN}IBM Ceph repository file already exists. Skipping download.${NC}"
  fi
  dnf install cephadm-ansible -y || error_exit "Failed to install Cephadm-ansible"
  ansible-playbook -i inventory  ceph_deploy.yml --tags update_os || error_exit "Failed update os tasks"

elif [ "$ceph_release" == "main" ]; then
    echo -e "${YELLOW}Main Ceph release detected. Downloading cephadm...${NC}"
    CADM="https://raw.githubusercontent.com/ceph/ceph/main/src/cephadm/cephadm.py"
    echo -e "${YELLOW}Downloading cephadm from the source...${NC}"
    cd /root
    git clone https://github.com/ceph/ceph.git
    ln -s /root/ceph/src/cephadm/cephadm.py /usr/sbin/cephadm
    echo -e "${GREEN}cephadm downloaded and added"
    dnf -y install python3 chrony lvm2 podman nano strace firewalld tcpdump ceph-common || error_exit "Failed to install RPMs"
    cd -
else
  echo -e "${YELLOW}Ceph release detected. Downloading cephadm...${NC}"
  dnf install cephadm-ansible -y || error_exit "Failed to install Cephadm-ansible"
  ansible-playbook -i inventory  ceph_deploy.yml --tags update_os || error_exit "Failed update os tasks"
fi

if [ "$run_preflight" = true ] && [ "$ceph_release" != "main" ]; then
  echo -e "${GREEN}Running preflight checks...${NC}"
  ansible-playbook -i inventory /usr/share/cephadm-ansible/cephadm-preflight.yml $extra_vars | tee -a "$logfile" || error_exit "Failed Ansible preflight"
  if [ $? -ne 0 ]; then
    echo -e "${RED}Preflight checks failed. Exiting...${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}Skipping preflight checks because ceph_release is 'main'.${NC}"
fi



# Run CoreDNS setup if add_coredns tag is present
if [ "$run_coredns" = true ]; then
  echo -e "${GREEN}Running CoreDNS setup...${NC}"
  ansible-playbook -i inventory coredns_deploy.yml --tags "add_coredns" | tee -a "$logfile" || error_exit "CoreDNS setup failed"
fi
if [ $? -ne 0 ]; then
    echo -e "${RED}CoreDNS setup failed. Exiting...${NC}"
    exit 1
fi

# Remove 'add_coredns' from the tags if it exists
other_tags=("${tag_array[@]/add_coredns/}")
if [ "${#other_tags[@]}" -gt 0 ]; then
  other_tags_str=$(IFS=, ; echo "${other_tags[*]}")
  if [ -n "$other_tags_str" ]; then
    echo -e "${GREEN}Running Ansible playbook with tags: ${other_tags_str}${NC}"
    ansible-playbook -i inventory ceph_deploy.yml --tags "${other_tags_str}" | tee -a "$logfile" || error_exit "Failed ansible-playbook"
    if [ $? -ne 0 ]; then
      echo -e "${RED}Ansible playbook execution failed.${NC}"
      exit 1
    fi
  fi
fi

echo -e "${GREEN}Ansible playbook execution completed successfully.${NC}"

