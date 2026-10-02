# Golden images on VMware vSphere — Packer + Ansible

Golden VM templates for vSphere, built from AWX: versioned, boot-tested, and released through two
channels, `testing` (latest build) and `prod` (approved).

Packer only installs. Everything after the install runs as Ansible inside the VM through VMware
Tools (`community.vmware.vmware_tools`): no SSH and no WinRM.

## A build

`playbooks/build-image.yml -e image=<image>`:

| Phase | Rocky Linux | Windows Server |
|---|---|---|
| 1. Packer installs into `build-<image>-<version>` | Kickstart and the `open-vm-tools` RPMs from a CD labelled `OEMDRV`; ends with `poweroff` | `autounattend.xml`; the first logon installs VMware Tools from the ESXi tools ISO and shuts down |
| 2. Ansible through VMware Tools runs the image's `configure.yml` | Check `/root/build-complete`, seal (machine-id, SSH host keys, network profile, logs), power off | Fixed build address, Windows Update, cleanup, seal (address, setup answers, Administrator password, logs), shut down |
| 3. Publish | The VM is copied to the template `<image>-<version>`, deleted, and the template is tagged `testing` | same |

If phase 2 fails, the build VM stays in `vsphere_work_folder` for inspection.

### Passwords

The build generates one password per run for the account Ansible logs in with:

- **Rocky:** root. It stays root's password in the template and is published as the AWX artifact
  `root_password` (build job, Details, Artifacts; visible to everyone who can see the job). It works
  on the console and through VMware Tools; Rocky's sshd does not accept root passwords.
- **Windows:** Administrator. Sealing replaces it with a random one; VMware guest customization sets
  the real one at deploy time.

### Network

The build network has no DHCP. `image_build_network` in each `image.yml` is the build VM's fixed
address: the Rocky kickstart installs with it, the first Windows step sets it. Sealing removes it,
so templates carry no address. Rocky's NetworkManager does not create DHCP profiles on its own
(`no-auto-default=*`). VMs get their address from VMware guest customization when deployed.

### Windows is not sysprepped

VMware guest customization runs sysprep when a VM is deployed, which gives it its own SID, name,
address and Administrator password. Deploy Windows VMs with a customization specification.

## Layout

| Path | Contents |
|---|---|
| `vmware.yml` | Site settings: datacenter, cluster, datastore, network, folders, channel tags, ISO locations |
| `images/<os>/<image>/` | One image: `image.yml` (ISO, build address, boot-test expectations), `<image>.pkr.hcl`, the install answers (`*.j2`), `configure.yml` (phase 2), `files/` |
| `playbooks/build-image.yml` | Phases 1-3 |
| `playbooks/test-image.yml` | Deploys a VM from the template tagged `testing` (or `prod`), compares what VMware Tools report with `image.yml`, deletes the VM |
| `playbooks/promote-image.yml` | Moves the `prod` tag to the `testing` template, deletes older templates |
| `playbooks/tasks/linux/`, `playbooks/tasks/windows/` | Phase-2 steps shared by the images of one OS |
| `ee/` | AWX execution environment |
| `awx/` | AWX objects as code, all named `vsphere/...` |

Conventions the playbooks rely on, instead of settings: the `<os>` folder is `linux` or `windows`
and decides the guest login (root or Administrator); every `*.j2` in the image folder is rendered
into the build directory; Packer reads its variables from one file, `build.pkrvars.json`, and the
answer files from `var.build_dir`.

## Images

| Image | Source |
|---|---|
| `linux/rocky10-base` | Rocky Linux 10.2 minimal ISO, offline install, UEFI, PVSCSI/VMXNET3, open-vm-tools, SELinux enforcing; only account root |
| `windows/windows2025-std-desktop` | Windows Server 2025 Standard (Desktop Experience) evaluation ISO, UEFI/GPT, VMware Tools, all updates |

## Templates and channels

Templates are named `<image>-<version>` (UTC timestamp) and live in `vsphere_template_folder`.
Channels are vSphere tags in the category `golden-channel`: `testing` marks the latest successful
build, `prod` the approved one to deploy from. `promote-image.yml` keeps the newest
`vsphere_keep_versions` templates per image plus the `prod` one.

## Release cycle

AWX workflow `vsphere/<image>: pipeline` (build, boot test, approval, promote), scheduled as
`vsphere/<image>: monthly` on the Wednesday after Patch Tuesday: Rocky 05:00, Windows 06:00.

## Before the first build

1. Fill in `vmware.yml` and the placeholder addresses (`192.0.2.0/24`) in each `image.yml`.
2. Upload the install ISOs to `[<vsphere_iso_datastore>] <vsphere_iso_folder>/`.
3. Create the folders `vsphere_template_folder` and `vsphere_work_folder`.
4. vCenter account for AWX's **vCenter (golden images)** credential: rights on those folders, the
   datastore and tags, and `VirtualMachine.GuestOperations.*`.
5. AWX must reach vCenter and the ESXi hosts on port 443 (guest file transfers go to the host).
6. Build and load the EE (`ee/README.md`), bootstrap AWX (`awx/README.md`).
