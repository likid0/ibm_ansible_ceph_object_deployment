# Ceph Cluster Deployment with Ansible

This project automates the deployment of a Ceph cluster using Ansible. It includes playbooks and roles to bootstrap the Ceph cluster, add hosts, apply service specifications for OSDs (Object Storage Daemons), RGW (RADOS Gateway), and ingress services.

## Usage

### Pre-req
- RHEL Deployed
- We need Ansible setup and all cluster nodes accessible with passwordles SSH
- the IBM Storage Ceph tools repos enabled.
- cephadm-ansible RPM installed.
- Modify this Role variables

### Running the Playbook

To run the playbook, you can use the provided bash wrapper script `run_ceph_deploy.sh`.

#### Script Usage

```bash
./ansible_wrapper.sh [-t <tags>] [-l <log_file>]
```


## Variables

### Ceph Bootstrap Variables
- `monitor_address`: IP address of the monitor node.
- `dashboard_user`: Username for the Ceph dashboard.
- `dashboard_password`: Password for the Ceph dashboard.
- `allow_fqdn_hostname`: Boolean to allow FQDN hostnames.
- `registry_url`: URL of the container registry.
- `registry_username`: Username for the container registry.
- `registry_password`: Password for the container registry.
- `ec_data_pool_pg_num`: Number of placement groups for the EC data pool.
- `ec_data_pool_profile`: Name of the erasure coding profile.
- `ec_data_pool_profile_k`: Number of data chunks in the erasure coding profile.
- `ec_data_pool_profile_m`: Number of coding chunks in the erasure coding profile.

### RGW Variables
- `rgw_specs`: List of RGW specifications, it can be a list of RGW instances.
  - `name`: Name of the RGW spec.
  - `template`: Template file for the RGW spec.
  - `rgw_label`: Label for the RGW.
  - `rgw_count_per_host`: Number of RGW instances per host.
  - `rgw_realm`: RGW realm name.
  - `rgw_zone`: RGW zone name.
  - `rgw_zonegroup`: RGW zone group name.
  - `rgw_frontend_port`: Frontend port for RGW.
  - `rgw_id`: RGW ID.

### Ingress Variables
- `ingress_specs`: List of ingress specifications, each containing:
  - `name`: Name of the ingress spec.
  - `template`: Template file for the ingress spec.
  - `ingress_id`: ID of the ingress.
  - `backend_service`: Backend service for the ingress.
  - `virt_ip`: Virtual IP address for the ingress.
  - `frontend_port`: Frontend port for the ingress.
  - `monitor_port`: Monitor port for the ingress.
