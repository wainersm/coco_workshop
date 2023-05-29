#!/bin/bash

set -e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check_reqs() {
	if ! command -v kcli >/dev/null; then
		error "You must have 'kcli' installed. See https://kcli.readthedocs.io for further information"
	fi
}

error() {
	echo -e "\033[0;31mERROR: $*\033[0m"
	return 1
}

info () {
	echo -e "\033[0;34mINFO: $*\033[0m"
}

usage() {
	cat <<-EOF
	Create and setup a KVM VM for the CoCo workshop lab's activities.

	Use: $0 [-h], where:
	-h: show this help
	EOF
}

wait_for_ip() {
	local delta="${1:-120}"
	local sleep_time=10

	info "Set timeout to $delta seconds"
	timer_start=$(date +%s)
	while [ -z "$ip" ]; do
		sleep $sleep_time
		now=$(date +%s)
		if [ $((timer_start + delta)) -lt "$now" ]; then
			error "Timeout: unabled to get the IP address"
		fi
		info "Checking after $((now - timer_start)) seconds"
		ip=$(kcli info vm "${vm_name}" -f ip -v)	
	done
}

main() {
	local opt
	vm_name="coco-lab"

	while getopts "h" opt; do
		case "$opt" in
			h) usage && exit 0;;
			*) usage && exit 1;;
		esac
	done

	check_reqs

	if kcli list vm -o json | grep -q "\"name\": \"${vm_name}\""; then
		info "Delete the existing ${vm_name} VM"
		kcli delete -y vm ${vm_name}
	fi

	info "Create and start the VM"
	kcli create vm -i centos8stream -P numcpus=4 -P memory=$((1024*8)) -P disks=[30] "${vm_name}"
	kcli start vm "${vm_name}"

	info "Wait the VM to get an IP address"
	local ip
	wait_for_ip
	user=$(kcli info vm "${vm_name}" -f user -v)

	info "Install software requirements"
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		"${user}"@"${ip}" "bash -c 'sudo dnf -y update && sudo dnf install -y git ansible-core'"
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		"${user}"@"${ip}" "bash -c 'ansible-galaxy collection install community.docker'"

	info "Setup the lab environment"
	scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		-r "${script_dir}/setup_lab_env.sh" "${user}@${ip}:~/setup_lab_env.sh"
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		"${user}"@"${ip}" "bash -c './setup_lab_env.sh'"

	info "Installation succeeded. Use the 'kcli ssh ${vm_name}' command to connect to the VM"
}

main "$@"
