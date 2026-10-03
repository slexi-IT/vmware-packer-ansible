# The AWX execution environment for the vSphere image builds: Red Hat UBI 9 minimal with Ansible,
# the VMware and Windows collections, Packer and its vsphere plugin.
# Build and push with ee/build.sh <tag>.

# UBI 9 minimal (RHEL 9.8) of 2026-10-03, pinned by digest
FROM registry.access.redhat.com/ubi9/ubi-minimal@sha256:eba570d04193d1523a8576b1c0ff00e681c9edb1a41d4742559b6e3ff457601e

# Versions. Change them here, or for a single build with
# docker build --build-arg PACKER_VERSION=...
ARG ANSIBLE_CORE_VERSION=2.18.17
ARG ANSIBLE_RUNNER_VERSION=2.4.3
# The vmware_tools connection plugin: runs every configuration step inside the build VM
ARG COMMUNITY_VMWARE_VERSION=6.2.0
# Templates, tags and VM modules used by playbooks/
ARG VMWARE_VMWARE_VERSION=2.11.0
# Windows modules run through the vmware_tools connection
ARG ANSIBLE_WINDOWS_VERSION=3.5.0
# awx/configure.yml (job template "vsphere/Apply AWX config"); same version as the running AWX
ARG AWX_VERSION=24.6.1
# General-purpose filters and modules, available for new tasks; the playbooks do not use it yet
ARG COMMUNITY_GENERAL_VERSION=13.4.0
# The vSphere SDK (with pyVmomi) the two VMware collections need
ARG VCF_SDK_VERSION=9.1.1.0
ARG PACKER_VERSION=1.16.1
ARG PACKER_PLUGIN_VSPHERE_VERSION=2.5.0

# xorriso is in RHEL's AppStream but not in the UBI repositories: take it, and only it and its
# three libraries, from CentOS Stream 9 (signature-checked)
RUN printf '%s\n' \
      '[centos-stream-appstream-xorriso]' \
      'name=CentOS Stream 9 AppStream (xorriso only)' \
      'baseurl=https://mirror.stream.centos.org/9-stream/AppStream/$basearch/os/' \
      'gpgcheck=1' \
      'gpgkey=https://www.centos.org/keys/RPM-GPG-KEY-CentOS-Official' \
      'includepkgs=xorriso,libisoburn,libisofs,libburn' \
      > /etc/yum.repos.d/centos-stream-xorriso.repo

# python3.12: RHEL 9's python3 is 3.9, too old for ansible-core 2.18
# openssh-clients: ansible-runner starts ssh-agent when a job has an SSH key credential
# xorriso: Packer builds the kickstart / autounattend CDs (cd_files) with it before uploading them
RUN microdnf install -y --nodocs --setopt=install_weak_deps=0 \
      python3.12 python3.12-pip openssh-clients xorriso && \
    microdnf clean all && \
    ln -s /usr/bin/python3.12 /usr/local/bin/python3

# dumb-init: the container's first process, passes signals on and reaps finished child processes
# awxkit, pytz, python-dateutil: needed by the awx.awx collection
# python-tss-sdk: needed by the lookup community.general.tss (Delinea Secret Server)
RUN python3 -m pip install --no-cache-dir \
      "ansible-core==${ANSIBLE_CORE_VERSION}" \
      "ansible-runner==${ANSIBLE_RUNNER_VERSION}" \
      dumb-init==1.2.5 \
      "vcf-sdk==${VCF_SDK_VERSION}" \
      "awxkit==${AWX_VERSION}" pytz python-dateutil \
      python-tss-sdk

RUN ansible-galaxy collection install \
      "community.vmware:${COMMUNITY_VMWARE_VERSION}" \
      "vmware.vmware:${VMWARE_VMWARE_VERSION}" \
      "ansible.windows:${ANSIBLE_WINDOWS_VERSION}" \
      "awx.awx:${AWX_VERSION}" \
      "community.general:${COMMUNITY_GENERAL_VERSION}" \
      --collections-path /usr/share/ansible/collections

# Packer as a single static binary, verified against HashiCorp's published SHA256SUMS.
# /usr/local/bin is first in PATH, so it wins over cracklib's unrelated /usr/sbin/packer.
RUN set -eux; \
    cd /tmp; \
    base="https://releases.hashicorp.com/packer/${PACKER_VERSION}"; \
    zip="packer_${PACKER_VERSION}_linux_amd64.zip"; \
    curl -fsSLO "${base}/${zip}"; \
    curl -fsSL "${base}/packer_${PACKER_VERSION}_SHA256SUMS" | grep " ${zip}$" | sha256sum -c -; \
    python3 -c "import zipfile; zipfile.ZipFile('${zip}').extract('packer', '/usr/local/bin')"; \
    chmod 0755 /usr/local/bin/packer; \
    rm -f "${zip}"; \
    packer version

# The Packer plugin lives at a fixed path so jobs don't need `packer init` or internet access
ENV PACKER_PLUGIN_PATH=/usr/share/packer/plugins CHECKPOINT_DISABLE=1
RUN packer plugins install github.com/hashicorp/vsphere "v${PACKER_PLUGIN_VSPHERE_VERSION}" && \
    packer plugins installed

# What AWX expects of an execution environment: jobs run as user 1000 (group 0) in /runner
RUN mkdir -p /runner && chgrp 0 /runner && chmod g+rwx /runner && \
    echo 'runner:x:1000:0:AWX job:/runner:/bin/bash' >> /etc/passwd
ENV HOME=/runner
WORKDIR /runner
USER 1000
ENTRYPOINT ["dumb-init", "--"]
CMD ["bash"]
