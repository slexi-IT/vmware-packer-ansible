packer {
  required_plugins {
    vsphere = {
      source  = "github.com/hashicorp/vsphere"
      version = "= 2.5.0"
    }
  }
}

# Packer only installs: setup runs unattended from autounattend.xml, the first logon installs
# VMware Tools and powers the VM off. Everything after that (network, updates, cleanup, sealing,
# template, tags) is done by Ansible through VMware Tools - no WinRM. No sysprep: VMware guest
# customization runs it when VMs are deployed from the template.

# --- vSphere (from vmware.yml; credentials from the environment) ----------------------------
variable "vcenter_server" {
  type    = string
  default = env("VMWARE_HOST")
}
variable "vcenter_username" {
  type    = string
  default = env("VMWARE_USER")
}
variable "vcenter_password" {
  type      = string
  sensitive = true
  default   = env("VMWARE_PASSWORD")
}
variable "vsphere_insecure" {
  type    = bool
  default = true
}
variable "vsphere_datacenter" { type = string }
variable "vsphere_cluster" { type = string }
variable "vsphere_datastore" { type = string }
variable "vsphere_network" { type = string }
variable "vsphere_folder" { type = string }

# --- image ------------------------------------------------------------------------------------
variable "iso_path" {
  type        = string
  description = "Install ISO on a datastore"
}
variable "iso_checksum" { type = string }
variable "vm_name" {
  type        = string
  description = "Name of the build VM, e.g. build-windows2025-std-desktop-2026.10.02-0715"
}
variable "tools_iso_path" {
  type        = string
  description = "VMware Tools for Windows, e.g. [] /vmimages/tools-isoimages/windows.iso"
}
variable "autounattend_file" {
  type        = string
  description = "Rendered autounattend.xml (contains the per-build Administrator password)"
}

source "vsphere-iso" "windows2025-std-desktop" {
  vcenter_server      = var.vcenter_server
  username            = var.vcenter_username
  password            = var.vcenter_password
  insecure_connection = var.vsphere_insecure

  datacenter = var.vsphere_datacenter
  cluster    = var.vsphere_cluster
  datastore  = var.vsphere_datastore
  folder     = var.vsphere_folder
  vm_name    = var.vm_name

  guest_os_type = "windows2022srvNext_64Guest"
  firmware      = "efi"
  CPUs          = 2
  RAM           = 4096

  # Controller and NIC with drivers built into Windows, so setup needs no extra drivers.
  # VMware Tools add the PVSCSI and VMXNET3 drivers for VMs that want them.
  disk_controller_type = ["lsilogic-sas"]
  storage {
    disk_size             = 61440
    disk_thin_provisioned = true
  }
  network_adapters {
    network      = var.vsphere_network
    network_card = "e1000e"
  }

  iso_paths    = [var.iso_path, var.tools_iso_path]
  iso_checksum = var.iso_checksum
  # Setup finds autounattend.xml on this CD; the first logon runs install-vmware-tools.cmd from it
  cd_files     = [var.autounattend_file, "${path.root}/files/install-vmware-tools.cmd"]
  cd_label     = "PACKER"
  remove_cdrom = true

  # UEFI shows "Press any key to boot from CD or DVD" for a few seconds
  boot_wait    = "3s"
  boot_command = ["<spacebar><wait><spacebar>"]

  # No connection into the guest. install-vmware-tools.cmd shuts the VM down 30 seconds after the
  # VMware Tools installer returns, whether or not it succeeded; a failed install shows up when
  # build-image.yml waits for VMware Tools. shutdown_timeout is the limit for setup plus first
  # logon (setup took about 5 minutes in QEMU tests).
  communicator        = "none"
  shutdown_timeout    = "1h"
  # The build VM stays (powered off) for the Ansible phase
  convert_to_template = false
}

build {
  sources = ["source.vsphere-iso.windows2025-std-desktop"]
}
