Table of contents
1. [Introduction](#lab-confidential-containers-without-confidential-hardware)
1. [Supporting material](#supporting-material)
1. [Requirements](#requirements)
1. [Activities](#activities)

# Lab: Confidential Containers without confidential hardware

The project came up with a custom runtime that allows developers play with certain features of CoCo on either a simple virtual or bare-metal machine without TEE hardware. In this lab we will use that custom runtime so that you will be able to your laptop to learn on practice:

- How to install CoCo using its Kubernetes operator
- How to create a simple "confidential" pod
- Implementation details
- How to delete the CoCo installation

# Supporting material

This lab is based on the [How to use Confidential Containers without confidential hardware](https://www.redhat.com/en/blog/how-use-confidential-containers-without-confidential-hardware) blog post.

# Requirements

In order to fully accomplish all activities of this lab you will need:

- A bare-metal machine or KVM Virtual Machine (VM) installed with CentOS Stream 8 or Ubuntu 20.04
- The system must have at least 8GB of memory and 4 CPUs
- It must have installed Kubernetes version 1.24.0 or above, configured for the [containerd](https://containerd.io) container runtime

However, we **strongly recommend** that you run this lab activities on a VM because some instructions will change your system's configuration. Therefpre, We provide scripts that you can use to easily setup the lab environment in two scenarios:

- (Recommended) Use the [setup VM script](../scripts/setup_lab_vm.sh) to create a fresh KVM VM and perform the setup for you, all in a single run. The only requirement is to have the [kcli](https://kcli.readthedocs.io) tool installed on your laptop.
- Alternatively, bring up your own KVM VM matching the OS and system's requirements listed above, then run the [setup environment script](../scripts/setup_lab_env.sh) within the VM

# Activities

The following activities will be accomplished on this lab.

## 1. Get CoCo installed

You will install CoCo via [Kubernetes operator](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/).

1. Label the worker nodes:

```shell
$ kubectl label node "$(hostname)" "node-role.kubernetes.io/worker="
```

2. Disable SELinux enforce mode:

```shell
$ sudo setenforce 0
```

3. Install the CoCo operator's controller:

```shell
$ kubectl apply -k github.com/confidential-containers/operator/config/release?ref=v0.2.0
```

4. Wait for the controller's pod be running:

```shell
$ kubectl get pods -n confidential-containers-system --watch
```

5. Install the ssh-demo runtime

```shell
$ kubectl apply -f https://raw.githubusercontent.com/confidential-containers/operator/v0.2.0/config/samples/ccruntime-ssh-demo.yaml
```

6. Wait for all pods on `confidential-containers-system` namespace be running:

```shell
$ kubectl get pods -n confidential-containers-system --watch
```

7. Check the kata [runtime classes](https://kubernetes.io/docs/concepts/containers/runtime-class/) are deployed:

```shell
$ kubectl get runtimeclasses
```

## 2. Create the confidential pod

You will install your first "confidential" pod.

>**Note:** Since we will be using a custom runtime environment without confidential hardware, we will not be able to show how some of the confidential features are implemented by CoCo and the pod created won't be strictly “confidential.”

1. Create the *coco-demo.yaml* file:

```shell
cat <<EOF > coco-demo.yaml
kind: Service
apiVersion: v1
metadata:
  name: coco-demo
spec:
  selector:
    app: coco-demo
  ports:
  - port: 22
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: coco-demo
spec:
  selector:
    matchLabels:
      app: coco-demo
  template:
    metadata:
      labels:
        app: coco-demo
    spec:
      runtimeClassName: kata
      containers:
      - name: coco-demo
        image: docker.io/katadocker/ccv0-ssh
        imagePullPolicy: Always
EOF
```

2. Apply the *coco-demo.yaml* deployment:

```shell
$ kubectl apply -f coco-demo.yaml
```

3. Wait for the *coco-demo* pod be running:

```shell
$ kubectl get pods -l app=coco-demo --watch
```

## 3. Connect to the coco-demo pod

1. Get the cluster IP address

```shell
$ CLUSTER_IP=$(kubectl get service coco-demo -o jsonpath="{.spec.clusterIP}")
```

2. Get the SSH private key

```shell
$ curl -Lo ccv0-ssh https://raw.githubusercontent.com/confidential-containers/documentation/v0.2.0/demos/ssh-demo/ccv0-ssh
$ chmod 600 ccv0-ssh
```

3. Connect to the pod's container via SSH

```shell
$ ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ccv0-ssh root@<CLUSTER_IP>
```

4. (In the container) Check the kernel version

```shell
coco-demo-7c545b4d6b-44fx2:~# uname -a
```

5. (In the container) Check the kernel's command-line parameters

```shell
coco-demo-7c545b4d6b-44fx2:~# cat /proc/cmdline
```

## 4. Looking at the implementation details

1. Delete the previous coco-demo deployment:

```shell
$ kubectl delete -f coco-demo.yaml
```

2. Enable console debug

```shell
$ sudo cp /opt/confidential-containers/share/defaults/kata-containers/configuration-qemu.toml /opt/confidential-containers/share/defaults/kata-containers/configuration-qemu.toml.bak
$ sudo sed -i 's/^#debug_console_enabled = .*/debug_console_enabled = true/' /opt/confidential-containers/share/defaults/kata-containers/configuration-qemu.toml
```

3. Create the coco-demo pod (again)

```shell
$ kubectl apply -f coco-demo.yaml
$ kubectl get pods -l app=coco-demo --watch
```

4. Obtain the sandbox VMM process ID

```shell
$ SANDBOX_ID=$(sudo ls /run/kata-containers/shared/sandboxes/ | head -1)
$ ps aux | grep "qemu.*sandbox-${SANDBOX_ID}"
```

5. Check the image isn't present at the host filesystem

```shell
$ sudo ctr -n "k8s.io" image check name==docker.io/katadocker/ccv0-ssh
```

6. Connect to the sandbox guest VM

```shell
$ sudo /opt/confidential-containers/bin/kata-runtime exec "$SANDBOX_ID"
```

7. (In the guest) Print the offline fs keys file

```shell
root@localhost:/# cat /etc/aa-offline_fs_kbc-keys.json
```

8. (In the guest) Check the Attestation Agent is running

```shell
root@localhost:/# ps aux | grep attestation
```

9. (In the guest) Print the Kata agent configuration file

```shell
root@localhost:/# cat /etc/agent-config.toml
```

10. (In the guest) Check `ExecProcessRequest` endpoint isn't allowed

```shell
root@localhost:/# grep ExecProcessRequest /etc/agent-config.toml
```

11. Get out of the guest

```shell
root@localhost:/# exit
```

12. Check you are not allowed to exec in the pod's container

```shell
$ POD_NAME=$(kubectl get pods -l app=coco-demo -o jsonpath='{.items[0].metadata.name}')
$ kubectl exec "$POD_NAME" -- uname -a
```

## 5. Remove the CoCo installation

The party is over, let's delete the CoCo installation.

1. Delete the coco-demo deployment:

```shell
$ kubectl delete -f coco-demo.yaml
```

2. Delete the custom runtime

```shell
$ kubectl delete -f https://raw.githubusercontent.com/confidential-containers/operator/v0.2.0/config/samples/ccruntime-ssh-demo.yaml
```

3. Wait for all pods (except the controller) on `confidential-containers-system` namespace terminate

```shell
$ kubectl get pods -n confidential-containers-system
```

4. Delete the controller

```shell
$ kubectl delete -k github.com/confidential-containers/operator/config/release?ref=v0.2.0
```

5. Ensure all pods on `confidential-containers-system` are gone

```shell
$ kubectl get pods -n confidential-containers-system
```
