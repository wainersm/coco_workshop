# Lab: encrypting images for CoCo

The workloads on Confidential Containers are deployed from encrypted container images. You will learn on this lab:

- How to encrypt a container image for CoCo
- How to inspect the image's metadata
- How to push the image to image registry
- How the Offline fs KBC decrypt the image

## Supporting material

You will use the CoCo Keyprovider to feed the encryptation key to skopeo. So we recommend that you read its [README](https://github.com/confidential-containers/attestation-agent/blob/main/coco_keyprovider/README.md) document.

## Requirements

In order to fully accomplished all activities of this lab you will need:

- A bare-metal machine or VM istalled with Fedora or Ubuntu
- An account on Docker Hub (https://hub.docker.com)

## Activities

The following activities should be accomplished on this lab.

### 1. Encrypt the busybox image

You will encrypt the busybox image for using with either Offline fs, Offline SEV or Online SEV KBC.

1. Install skopeo:

- Fedora:

```shell
$ sudo dnf install skopeo
```

- Ubuntu:

```shell
$ ??
```

2. Create the work directory:

```shell
$ mkdir lab_encrypt_img
$ cd lab_encrypt_img
$ export LAB_WORKDIR="$(pwd)"
```

3. Clone and build the CoCo KeyProvider

```shell
$ git clone https://github.com/confidential-containers/attestation-agent
$ cd attestation-agent
$ git checkout bb6994390d8864c2b8745d296e780d54d6a522f2 -b workshop
$ export AA_HOME="$(pwd)"
$ cd coco_keyprovider
$ export COCO_KEYPROVIDER_HOME="$(pwd)"
$ cargo build --release
$ cp ../target/release/coco_keyprovider .
```

4. Start the coco_keyprovider service at port 50000:

```shell
$ ./coco_keyprovider --socket 127.0.0.1:50000 &
```

5. Create the ocicrypt.conf and export OCICRYPT_KEYPROVIDER_CONFIG:

```shell
$ cat <<EOF > ocicrypt.conf
{
  "key-providers": {
    "attestation-agent": {
      "grpc": "127.0.0.1:50000"
    }
  }
}
EOF

$ export OCICRYPT_KEYPROVIDER_CONFIG="$(pwd)/ocicrypt.conf"
```

6. Create a random 32-bytes key file:

```shell
$ cd "${LAB_WORKDIR}"
$ export KEY1_FILE="${LAB_WORKDIR}/key1"
$ head -c32 < /dev/random > "$KEY1_FILE"
```

7. Encrypt the busybox image:

```shell
$ skopeo copy --insecure-policy --encryption-key provider:attestation-agent:keypath=${KEY1_FILE}::keyid=kbs:///default/key/key_id1 docker://busybox oci:busybox_encrypted
```

There should be created the `busybox_encrypted` directory on the laboratory's workdir.

8. (Extra) Push the encrypted busybox to Docker Hub

You will only be able to accomplish this task if you have an account USER on Docker hub and created the REPOSITORY repository.

8a. Log-in Docker hub:

```shell
$ docker login
```

8b. Copy the encrypted image:

```
$ docker copy --insecure-policy oci:busybox_encrypted docker://USER/REPOSITORY
```

### 2. Inspect the encrypted image

You will inspect the encrypted image created on the previous activity to check it is properly encrypted as well as understand the metadata used by the KBC for decryption.

1. Switch to the workdir:

```shell
$ cd "${LAB_WORKDIR}"
```

2. Print the image low-lever information:

```shell
$ skopeo inspect oci:busybox_encrypted
```

3. Check layers data `MIMEType` is `application/vnd.oci.image.layer.v1.tar+gzip+encrypted`

4. Decode the `org.opencontainers.image.enc.keys.provider.attestation-agent` annotation:

```
$ echo "<Paste the annotation value here>" | base64 -d
```

5. Check `kid`(Key Broker Service Resource URI) is "kbs:///default/key/key_id1"

6. Decode the `org.opencontainers.image.enc.pubopts` annotation:

```shell
$ echo "<Paste the annotation value here>" | base64 -d
```

7. Check `cipher` is "AES_256_CTR_HMAC_SHA256"

### 3. The decrypt the image

You will use the Attestation Agent (AA) and its Offline fs KBC module to decrypt the busybox image created on the first activity.

1. Build and install the AA:

```shell
$ cd "$AA_HOME"
$ make KBC=offline_fs_kbc
$ make DESTDIR="$(pwd)" install
```

2. Start the AA service at port 48888:

```
$ RUST_LOG=attestation_agent ./attestation-agent --keyprovider_sock 127.0.0.1:48888 &
```

3. Create the ocicrypt.conf and export OCICRYPT_KEYPROVIDER_CONFIG:

```shell
$ cat <<EOF > ocicrypt.conf
{
  "key-providers": {
    "attestation-agent": {
      "grpc": "127.0.0.1:48888"
}}}
EOF
$ export OCICRYPT_KEYPROVIDER_CONFIG="$(pwd)/ocicrypt.conf"
```

4. Create the aa-offline_fs_kbc-keys.json:

```shell
$ cd "${LAB_WORKDIR}"
$ ENC_KEY_BASE64="$(cat $KEY1_FILE | base64)"
$ cat <<EOF > aa-offline_fs_kbc-keys.json
{
  "default/key/key_id1": "${ENC_KEY_BASE64}"
}
EOF
```

5. Copy aa-offline_fs_kbc-keys.json to /etc:

```shell
$ sudo cp aa-offline_fs_kbc-keys.json /etc/
```

6. Decrypt the busybox image:

```shell
$ skopeo copy --insecure-policy --decryption-key provider:attestation-agent:offline_fs_kbc::null oci:busybox_encrypted oci:busybox_decrypted
```

7. Check the image's layer data MIMEType is `application/vnd.oci.image.layer.v1.tar+gzip`:

```
$ skopeo inspect oci:busybox_decrypted | grep MIMEType
```