# Execution environment

The AWX execution environment for the image builds: Red Hat UBI 9 minimal (pinned by digest) with
ansible-core 2.18 on Python 3.12, ansible-runner, Packer with its vsphere plugin, and xorriso, which
Packer uses to build the kickstart / autounattend CDs. About 900 MB on disk.

| File | Purpose |
|---|---|
| `Dockerfile` | The whole image. Every version is an `ARG` at the top |
| `build.sh` | Build with Docker and push to Harbor |

The base image contains no Ansible content, so the `Dockerfile` installs every collection the
playbooks use:

| Collection | Used for |
|---|---|
| `community.vmware` | The `vmware_tools` connection plugin: runs every configuration step inside the build VM |
| `ansible.windows` | Windows modules run through that connection (`win_updates`, `win_user`, `win_copy`, ...) |
| `vmware.vmware` | Power state, VM info, template creation, tags, test deployments |
| `community.general` | General filters and modules |
| `awx.awx` | `awx/configure.yml`, run by the job template *vsphere/Apply AWX config* |

A plain `Dockerfile` does not install what a collection needs by itself: the Python packages are
listed by hand (`vcf-sdk` for the two VMware collections, `awxkit`, `pytz` and `python-dateutil`
for `awx.awx`, `python-tss-sdk` for the lookup `community.general.tss`, Delinea Secret Server). A new collection goes in with another line in the `ansible-galaxy` step, plus
whatever its `requirements.txt` names in the `pip install` step.

xorriso is not in the UBI repositories: the `Dockerfile` adds CentOS Stream 9's AppStream,
restricted to xorriso and its three libraries.

## Build

```sh
sudo systemctl start docker                # the daemon is not enabled at boot
docker login harbor.bitlex.li              # once: robot account with push on the project awxee
ee/build.sh 2026.10.03-3                   # a new tag for every build
```

`build.sh` runs `docker build` and `docker push` to Harbor (`harbor.bitlex.li`, private project
`awxee`), image `awx-ee-vmware-packer`.

Then set the new tag in `awx/config.yml` (execution environment *AWX EE VMware Packer*), push, and
run **Apply AWX config**. Use a new tag for every build, so a running AWX never picks up a changed
image under an old tag.
