#!/bin/bash

set -e

check_reqs() {
	if ! command -v git >/dev/null; then
		error "you must have 'git' installed"
	fi

	if ! command -v ansible >/dev/null; then
		error "you must have 'ansible' installed"
	fi
}

error() {
	echo -e "\033[0;31mERROR: $*\033[0m"
	return 1
}

info () {
	echo -e "\033[0;34mINFO: $*\033[0m"
}

on_exit() {
	rm -rf "$workdir"
}

trap on_exit EXIT

main() {
	check_reqs
	ansible-galaxy collection install community.docker
	workdir="$(mktemp -d)"
	pushd "$workdir"
	git clone https://github.com/confidential-containers/operator
	pushd operator/tests/e2e
	git checkout bba3c4343d5399f1c -b lab_setup
	info "install and configure the environment"
	ansible-playbook -i localhost, -c local --tags untagged ansible/main.yml
	info "start kubernetes"
	sudo -E PATH="$PATH" bash -c './cluster/up.sh'
	popd
	mkdir -p "$HOME/.kube"
	sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
	sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
	popd
	info "installation successful"
}

main "$@"
