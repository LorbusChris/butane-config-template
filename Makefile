include secrets

.PHONY: all
all: ignition

generate-butane:
	@podman run --rm \
		--volume ${PWD}:/workdir:Z \
		docker.io/mikefarah/yq:latest \
		ea '. as $$item ireduce ({}; . *+ $$item )' ./config/*.bu \
	| sed "s|<%%SSH_PUBKEY%%>|$(shell cat ${SSH_PUBKEY_PATH})|" \
	| sed "s|<%%TIMEZONE%%>|$(shell timedatectl show --va -p Timezone)|" \
	| sed "s|<%%HOSTNAME%%>|${HOSTNAME}|" \
	| sed "s|<%%OS_EXTENSIONS%%>|${OS_EXTENSIONS}|" \
	> config.bu

butane: generate-butane

generate-ignition: generate-butane
	podman run --rm \
        --security-opt label=disable \
        --volume ${PWD}:/pwd \
		--workdir /pwd \
        quay.io/coreos/butane:release \
		--strict --files-dir files_generated --output config.ign \
		config.bu

ignition: generate-ignition

disk: ignition
	sudo podman run --rm --privileged \
    	--volume /dev:/dev \
		--volume /run/udev:/run/udev \
		--volume ${PWD}:/data \
		--workdir /data \
    	quay.io/coreos/coreos-installer:release \
    	install --stream=${OS_STREAM} --architecture=${OS_ARCH} --ignition-file config.ign \
		${OS_DISK}
	sleep 1

disk-rpi: disk
	sudo OS_DISK=${OS_DISK} OS_ARCH=${OS_ARCH} ./hack/rpi.sh 