# AWX configuration as code

`config.yml` describes this repository's AWX objects: execution environment, credentials
(names only), project, and per image (`awx_images`) the job templates `vsphere/<image>: build`,
`: boot test` and `: promote`, the workflow `vsphere/<image>: pipeline` with its approval, the
schedule `vsphere/<image>: monthly`, the labels `golden-image`, `vsphere` and `linux`/`windows`,
and the team permissions. `configure.yml` applies it with the `awx.awx` collection.

Every name starts with `vsphere/` (`awx_name_prefix`), because the QEMU builds from
slexi-IT/packer are managed in the same AWX.

GitHub is the source of truth: changes made by hand in the AWX web UI are overwritten the next
time the config is applied.

## Changing something

1. Edit `config.yml` or `surveys/*.json`.
2. Commit and push.
3. In AWX, launch **vsphere/Apply AWX config**.

## Dry run from the laptop

```sh
export CONTROLLER_PASSWORD=$(KUBECONFIG=~/.kube/k0s.conf kubectl -n awx get secret awx-admin-password -o jsonpath='{.data.password}' | base64 -d)
podman run --rm --network host \
  -e CONTROLLER_HOST=http://localhost:30080 -e CONTROLLER_USERNAME=admin -e CONTROLLER_PASSWORD -e CONTROLLER_VERIFY_SSL=false \
  -v .:/p:Z -w /p localhost/awx-ee-vmware-packer:2026.10.02-1 \
  ansible-playbook awx/configure.yml --check --diff
```

Drop `--check --diff` to apply.

## Secrets

The repository holds no secrets. Credentials are declared by name and type only and applied
with `update_secrets: false`, so their stored keys and tokens are never touched. Create them in
AWX by hand once:

| Credential | Type | Inputs |
|---|---|---|
| GitHub deploy key slexi-IT/vmware-packer-ansible | Source Control | username `git`, private key `~/.ssh/vmware-packer-ansible_deploy` |
| AWX API (config as code) | Red Hat Ansible Automation Platform | already exists (shared with slexi-IT/packer) |
| vCenter (golden images) | VMware vCenter | vCenter host, user, password |

Then run the command above without `--check` once (bootstrap); afterwards
**vsphere/Apply AWX config** keeps AWX in line with the repository.
