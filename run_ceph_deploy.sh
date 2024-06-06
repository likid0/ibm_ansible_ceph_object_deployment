#!/bin/bash

# Define colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default log file
LOG_FILE="/var/log/ansible_playbook_ceph_deploy.log"

# Path to Ansible playbook
PLAYBOOK="ceph_deploy.yml"

# Available tags
AVAILABLE_TAGS="bootstrap,add_hosts,add_osd,add_rgw,add_ingress"

# Custom module path
MODULE_PATH="/usr/share/cephadm-ansible"

# Help function
function show_help {
    echo -e "${YELLOW}Usage: $0 [-t <tags>] [-l <log_file>]${NC}"
    echo -e "${YELLOW}  -t <tags>     Comma-separated list of tags to run specific parts of the playbook${NC}"
    echo -e "${YELLOW}  -l <log_file> Path to the log file (default: /var/log/ansible_playbook.log)${NC}"
    echo -e "${YELLOW}Available tags: ${AVAILABLE_TAGS}${NC}"
}

# Check if cephadm-ansible package is installed
if ! rpm -q cephadm-ansible > /dev/null 2>&1; then
    echo -e "${RED}The cephadm-ansible package is not installed on this host.${NC}"
    echo -e "${RED}Please install cephadm-ansible before running this script.${NC}"
    exit 1
fi

# Parse command line arguments
while getopts ":t:l:h" opt; do
  case ${opt} in
    t )
      TAGS=$OPTARG
      ;;
    l )
      LOG_FILE=$OPTARG
      ;;
    h )
      show_help
      exit 0
      ;;
    \? )
      echo -e "${RED}Invalid option: -$OPTARG${NC}" 1>&2
      show_help
      exit 1
      ;;
    : )
      echo -e "${RED}Invalid option: -$OPTARG requires an argument${NC}" 1>&2
      show_help
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

# Check if tags are provided
if [ -z "$TAGS" ]; then
  echo -e "${RED}No tags specified. Available tags: ${AVAILABLE_TAGS}${NC}" 1>&2
  show_help
  exit 1
fi

# Run the preflight playbook
echo -e "${GREEN}Running preflight checks...${NC}"
#ansible-playbook -i inventory ${MODULE_PATH}/cephadm-preflight.yml --extra-vars "ceph_origin=ibm"


# Run Ansible playbook with specified tags
echo -e "${BLUE}Running Ansible playbook with tags: ${TAGS}${NC}"
ANSIBLE_LIBRARY=${MODULE_PATH} ansible-playbook ${PLAYBOOK} --tags ${TAGS} | tee ${LOG_FILE}

# Check if the playbook ran successfully
if [ $? -eq 0 ]; then
  echo -e "${GREEN}Playbook executed successfully.${NC}"
else
  echo -e "${RED}Playbook execution failed.${NC}"
  exit 1
fi
