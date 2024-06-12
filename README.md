# Ceph Cluster Deployment with Ansible

This project automates the deployment of a Ceph cluster using Ansible. It includes playbooks and roles to bootstrap the Ceph cluster, add hosts, apply service specifications for OSDs (Object Storage Daemons), RGW (RADOS Gateway), and ingress services.

## Usage

### Pre-req
- RHEL Deployed
- We need Ansible setup and all cluster nodes accessible with passwordles SSH
- Update the inventory with the service lables, to configure the co-location of services
- Modify the Role variables to fit your Env.

### Running the Playbook

To run the playbook, you can use the provided bash wrapper script `run_ceph_deploy.sh`.

#### Script Usage

```bash
./ansible_wrapper.sh [-t <tags>] [-l <log_file>]
```

For a full deployment from scratch you need to run

```
bash run_ceph_deploy.sh -t update_os,enable_ibm_repo,preflight,bootstrap,add_hosts,add_osd,add_rgw,add_ingress -l log.log
```

## Inventory

If a single node is found on the inventory the automation will deploy Ceph in Single Node mode.

Nodes in the inventory need to have the Labels set to configure the placement of the Ceph services.

Single Node Example:

```
# cat inventory
[admin]
ceph-node-00.cephlab.com monitor_address=192.168.122.12 labels='_admin,osd,mon,mgr,rgw'
```

Multiple Node Example:
```
# cat inventory.ok
ceph-node-01.cephlab.com labels='osd,mon,mgr,rgwsync'
ceph-node-02.cephlab.com labels='osd,mon,mgr,rgw,ingress'
ceph-node-03.cephlab.com labels='osd,mgr,rgw,ingress'
ceph-node-00.cephlab.com labels='_admin,osd,mon,mgr,rgwsync'

[admin]
ceph-node-00.cephlab.com monitor_address=192.168.122.12 labels='_admin,osd,mon,mgr,rgwsync'
```

## Variables to configure

```
# ls deploy_ceph/vars/
ceph_config.yml  ceph.yml  ingress.yml osd.yml  rgw.yml
```
