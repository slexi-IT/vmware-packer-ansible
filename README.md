# Golden images on VMware vSphere — Packer + Ansible

Golden VM images for vSphere, built from AWX: versioned, sealed, boot-tested and released
through two channels, `testing` (latest build) and `prod` (approved).

**Packer only installs. Everything after the install is Ansible, inside the VM through VMware
Tools** (`community.vmware.vmware_tools` connection): no SSH and no WinRM during the build, no
network path from AWX into the build VM.

## How a build works

| Phase | Tool | Rocky Linux | Windows Server |
|---|---|---|---|
| 1. Install | Packer `vsphere-iso`, communicator `none` | Kickstart from a CD labelled `OEMDRV`, `open-vm-tools` from the same CD, per-build root password, `poweroff` | `autounattend.xml`, per-build Administrator password; the first logon installs VMware Tools from the ESXi tools ISO and shuts down |
| 2. Configure | Ansible through VMware Tools | Check the kickstart's completion marker, seal (machine-id, SSH host keys, network profile, logs), lock root, power off | Windows Update (with reboots), OpenSSH + access account, cleanup, sysprep (powers off) |
| 3. Publish | `vmware.vmware` | Build VM → template `<image>-<version>`, build VM deleted, template tagged `testing` | same |

The build VM is called `build-<image>-<version>` and lives in `vsphere_work_folder` until
phase 3. If phase 2 fails it is left there for inspection.

## Network: no DHCP

The build network has no DHCP. Each image's `image.yml` sets the build VM's fixed address in
`image_build_network` (address, prefix, gateway, DNS): the Rocky kickstart uses it during the
install, Windows gets it as the first Ansible step (Windows Update needs it). Sealing removes it
again, so **templates carry no address**: Rocky has no network profile and NetworkManager's
automatic DHCP profiles are off; Windows' adapter is reset before sysprep. VMs made from a
template get their address from VMware guest customization when they are deployed.

The boot test therefore checks what VMware Tools report (Tools running, OS, hostname), not an
address.

## Repository layout

| Path | Contents |
|---|---|
| `vmware.yml` | Site settings: datacenter, cluster, datastore, network, folders, channel tags, ISO locations |
| `images/linux/<image>/`, `images/windows/<image>/` | One image per folder, grouped by OS: `image.yml` settings, Packer template, install answers, `configure.yml` (the steps phase 2 runs), files for the guest |
| `playbooks/build-image.yml` | Phases 1-3 for any image |
| `playbooks/test-image.yml` | Deploys a throwaway VM from the template tagged `testing` (or `prod`), checks it through VMware Tools, deletes it |
| `playbooks/promote-image.yml` | Moves the `prod` tag to the `testing` template, keeps the last 3 templates |
| `playbooks/tasks/linux/`, `playbooks/tasks/windows/` | Shared configure steps per OS, used by the images' `configure.yml` |
| `ee/` | The AWX execution environment |
| `awx/` | The AWX objects as code (all prefixed `vsphere/`) |

## Images

| Image | Source | Contents |
|---|---|---|
| `linux/rocky10-base` | Rocky Linux 10.2 minimal ISO | Offline install, UEFI, PVSCSI/VMXNET3, open-vm-tools, SELinux enforcing, no network configuration (no DHCP), access account `slexi` (SSH key) |
| `windows/windows2025-std-desktop` | Windows Server 2025 evaluation ISO | Standard with Desktop Experience, UEFI/GPT, VMware Tools, all updates, OpenSSH with access account `slexi` (SSH key), sysprepped; the built-in Administrator is disabled |

Adding an image: a new folder under `images/<os>/` with `image.yml`, a Packer template,
install answers and `configure.yml` (built from the shared steps in `playbooks/tasks/<os>/`),
plus an entry under `awx_images` in `awx/config.yml`.

## Templates and channels

Every build becomes a vSphere template `<image>-<version>` (UTC timestamp, e.g.
`rocky10-base-2026.10.02-0715`) in `vsphere_template_folder`. Channels are vSphere tags in the
category `golden-channel`:

| Tag | Meaning |
|---|---|
| `testing` | Latest successful build of the image |
| `prod` | Approved version: deploy VMs from the template of the image that carries this tag |

## Release cycle

Each image has its own AWX workflow, `vsphere/<image>: pipeline`, scheduled on the Wednesday
after Patch Tuesday (`vsphere/<image>: monthly`; Rocky at 05:00, Windows at 06:00): build,
boot test, then an approval in AWX before the new version becomes `prod`.

## Requirements in vSphere

- The account in AWX's **vCenter (golden images)** credential needs, besides VM and template
  rights, `VirtualMachine.GuestOperations.*` (for the VMware Tools connection) and tagging rights.
- AWX must reach **vCenter and the ESXi hosts** on port 443: guest file transfers go straight to
  the host running the VM.
- Folders `vsphere_template_folder` and `vsphere_work_folder` exist; the tag category and tags
  are created by the playbooks.
- The install ISOs are on `[<vsphere_iso_datastore>] <vsphere_iso_folder>/`; the ESXi VMware
  Tools ISO is at `vsphere_tools_windows_iso`.

## Before the first build

1. Fill in `vmware.yml`.
2. Upload the install ISOs.
3. Build the EE from `ee/` and load it (see `ee/README.md`).
4. Bootstrap AWX from `awx/` (see `awx/README.md`) and fill in the vCenter credential.
