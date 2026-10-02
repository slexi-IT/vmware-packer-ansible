packer {
  required_plugins {
    vsphere = {
      source  = "github.com/hashicorp/vsphere"
      version = "= 2.5.0"
    }
  }
}

# Packer only installs: it boots the ISO, Anaconda installs unattended and powers the VM off.
# Everything after that (sealing, template, tags) is done by Ansible through VMware Tools,
# see playbooks/build-image.yml and this image's configure.yml.

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
  description = "Install ISO on a datastore, e.g. [datastore1] iso/Rocky-10.2-x86_64-minimal.iso"
}
variable "iso_checksum" { type = string }
variable "vm_name" {
  type        = string
  description = "Name of the build VM, e.g. build-rocky10-base-2026.10.02-0715"
}
variable "ks_file" {
  type        = string
  description = "Rendered kickstart; Anaconda loads ks.cfg automatically from a disk labelled OEMDRV"
}

source "vsphere-iso" "rocky10-base" {
  vcenter_server      = var.vcenter_server
  username            = var.vcenter_username
  password            = var.vcenter_password
  insecure_connection = var.vsphere_insecure

  datacenter = var.vsphere_datacenter
  cluster    = var.vsphere_cluster
  datastore  = var.vsphere_datastore
  folder     = var.vsphere_folder
  vm_name    = var.vm_name

  guest_os_type = "rhel9_64Guest"
  firmware      = "efi"
  CPUs          = 2
  RAM           = 4096

  disk_controller_type = ["pvscsi"]
  storage {
    disk_size             = 20480
    disk_thin_provisioned = true
  }
  network_adapters {
    network      = var.vsphere_network
    network_card = "vmxnet3"
  }

  iso_paths    = [var.iso_path]
  iso_checksum = var.iso_checksum
  # Kickstart, init.sh and the open-vm-tools RPMs: uploaded as a second CD labelled OEMDRV
  cd_files     = [var.ks_file, "${path.root}/files/init.sh", "${path.root}/files/rpms/*.rpm"]
  cd_label     = "OEMDRV"
  remove_cdrom = true

  # Skip "Test this media" (the default GRUB entry) and pick "Install Rocky Linux"
  boot_wait    = "5s"
  boot_command = ["<up><enter>"]

  # No connection into the guest: the kickstart ends with poweroff and Packer waits for it.
  # Ansible later checks the kickstart's completion marker through VMware Tools.
  communicator     = "none"
  shutdown_timeout = "30m"
  # The build VM stays (powered off) for the Ansible phase
  convert_to_template = false
}

build {
  sources = ["source.vsphere-iso.rocky10-base"]
}
