# Ceph Cluster Deployment with Ansible

This project automates the deployment of a Ceph cluster using Ansible. It includes playbooks and roles to bootstrap the Ceph cluster, add hosts, apply service specifications for OSDs (Object Storage Daemons), RGW (RADOS Gateway), and ingress services.

## Usage

### Pre-req
- RHEL Deployed
- We need Ansible setup and all cluster nodes accessible with passwordles SSH
- Modify the Role variables to fit your Env.

### Running the Playbook

To run the playbook, you can use the provided bash wrapper script `run_ceph_deploy.sh`.

#### Script Usage

```bash
./ansible_wrapper.sh [-t <tags>] [-l <log_file>]
```

For a full deployment from scratch you need to run

```
 bash run_ceph_deploy.sh -t rhel_registration,update_os,enable_ibm_repo,bootstrap,add_hosts,add_osd,add_ingress -l log.log
```

## Variables

```
# ls deploy_ceph/vars/
ceph_config.yml  ceph.yml  ingress.yml  main.yml  osd.yml  rgw.yml
```
