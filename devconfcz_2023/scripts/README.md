# Introduction

This directory contains auxiliary scripts that can be used by the attendees to setup their laptop for the laboratories activities proposed on this workshop.

# Preparing a Virtual Machine (VM)

The laboratory entitled [Confidential Containers without confidential hardware](../labs/coco_without_confidential_hardware.md) will be carried out in an environment that requires Kubernetes and other softwares. Other than being a little complex to install the required software stack, the lab activities will change your system’s configuration, so we strongly recommend that you run these activities on a VM.

Therefore, we provide scripts that you can use to easily setup the lab environment in two scenarios. On both you are required to have Linux on your laptop, preferably [Fedora](https://fedoraproject.org/) or [Ubuntu](https://ubuntu.com/), and KVM virtualization supported and enabled.

For KVM virtualization on Fedora and Ubuntu hosts, see the following documents to Fedora and Ubuntu respectively:

- [Getting started with virtualization](https://docs.fedoraproject.org/en-US/quick-docs/getting-started-with-virtualization/)
- [Introduction to virtualisation](https://ubuntu.com/server/docs/virtualization-introduction)

## Bringing your own VM

In the first scenario, you bring your own KVM VM. It will be required to:

- be installed with CentOS Stream 8 or Ubuntu 20.04
- have at least 8GB of memory and 4 CPUs

You will need to install both `git` and `ansible` tools in your VM as well:

- On CentOS VM: `sudo dnf install -y git ansible-core && ansible-galaxy collection install community.docker`
- On Ubuntu VM: `sudo apt-get install -y git ansible`

>Note: you should be using a user configured with `sudo` for privileged tasks.

Then you copy the [setup environment script](./setup_lab_env.sh) to the VM and run it:

```
$ ./setup_lab_env.sh
```

## It will create and setup the VM for you

- (**Recommended**) Use the [setup VM script](../scripts/setup_lab_vm.sh) to create a fresh KVM VM and perform the setup for you, all in a single run. The only requirement for this approach is to have the [kcli](https://kcli.readthedocs.io) tool installed on your laptop. Then run:

```
$ cd devconfcz_2023/scripts/
$ ./setup_lab_vm.sh
```

If the installation succeeded you can connect to the VM by issuing the following command:

```
$ kcli delete vm coco-lab
```

Once you are done with the VM, it can be deleted as:

```
$ kcli delete vm coco-lab
```