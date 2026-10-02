# Execution environment

The AWX execution environment for the image builds: the current `awx-ee` (ansible-core 2.18,
Python 3.12, pinned by digest) plus Packer with its vsphere plugin, and xorriso, which Packer
uses to build the kickstart / autounattend CDs.

The collections that do the work after Packer's install come with the base image or
`requirements.yml`:

| Collection | Used for |
|---|---|
| `community.vmware` | The `vmware_tools` connection plugin: runs every configuration step inside the build VM through VMware Tools (no SSH, no WinRM) |
| `ansible.windows` | Windows modules run through that connection (`win_updates`, `win_user`, `win_copy`, ...) |
| `vmware.vmware` | Power state, VM info, template creation, tags, test deployments |
| `community.general` | General filters and modules |

| File | Purpose |
|---|---|
| `execution-environment.yml` | ansible-builder definition: base image, Packer download with checksum check, plugin version |
| `bindep.txt` | System packages installed into the image |
| `requirements.yml` | Collections added on top of the base image |

## Build

```sh
cd ee
python3 -m venv .venv && .venv/bin/pip install ansible-builder   # once
.venv/bin/ansible-builder build --container-runtime podman -t <registry>/awx-ee-vmware-packer:<tag>
```

Use a new tag for every build, so a running AWX never picks up a changed image under an old
tag.

## Load into the cluster

In the lab there is no registry: the image goes into k0s's containerd as a file.

```sh
podman save --format docker-archive -o ee.tar <registry>/awx-ee-vmware-packer:<tag>
sudo k0s ctr -n k8s.io images import ee.tar
```

Then set the tag in `awx/config.yml` (execution environment *AWX EE VMware Packer*), push,
and run **Apply AWX config**.
