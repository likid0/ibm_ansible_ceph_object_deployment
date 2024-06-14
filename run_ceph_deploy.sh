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

if [ "$run_preflight" = true ]; then
  echo -e "${GREEN}Running preflight checks...${NC}"
  ansible-playbook -i inventory /usr/share/cephadm-ansible/cephadm-preflight.yml --extra-vars "ceph_origin=ibm" | tee -a "$logfile"
  if [ $? -ne 0 ]; then
    echo -e "${RED}Preflight checks failed. Exiting...${NC}"
    exit 1
  fi
fi

if ! rpm -q cephadm-ansible &> /dev/null; then
  echo -e "${RED}Error: cephadm-ansible package is not installed.${NC}"
  exit 1
fi

# Run CoreDNS setup if add_coredns tag is present
if [ "$run_coredns" = true ]; then
  echo -e "${GREEN}Running CoreDNS setup...${NC}"
  ansible-playbook -i inventory coredns_deploy.yml --tags "add_coredns" | tee -a "$logfile"
  if [ $? -ne 0 ]; then
    echo -e "${RED}CoreDNS setup failed. Exiting...${NC}"
    exit 1
  fi
fi

# Remove 'add_coredns' from the tags if it exists
other_tags=("${tag_array[@]/add_coredns/}")
if [ "${#other_tags[@]}" -gt 0 ]; then
  other_tags_str=$(IFS=, ; echo "${other_tags[*]}")
  if [ -n "$other_tags_str" ]; then
    echo -e "${GREEN}Running Ansible playbook with tags: ${other_tags_str}${NC}"
    ansible-playbook -i inventory ceph_deploy.yml --tags "${other_tags_str}" | tee -a "$logfile"
    if [ $? -ne 0 ]; then
      echo -e "${RED}Ansible playbook execution failed.${NC}"
      exit 1
    fi
  fi
fi

echo -e "${GREEN}Ansible playbook execution completed successfully.${NC}"

