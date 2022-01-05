include secrets

.PHONY: all
all: ignition

generate-files:
	mkdir -p ./generated
	rm -rf ./generated/files
	cp -a files generated/files
	find ./generated/files/ -type f -print0 | xargs -0 sed -i "s|<%%SSH_PUBKEY%%>|$(shell cat ${SSH_PUBKEY_PATH})|g"
	find ./generated/files/ -type f -print0 | xargs -0 sed -i "s|<%%TIMEZONE%%>|$(shell timedatectl show --va -p Timezone)|g"
	find ./generated/files/ -type f -print0 | xargs -0 sed -i "s|<%%HOSTNAME%%>|${HOSTNAME}|g"
	find ./generated/files/ -type f -print0 | xargs -0 sed -i "s|<%%OS_EXTENSIONS%%>|${OS_EXTENSIONS}|g"

files: generate-files

generate-butane: files
	rm -f ./generated/config.bu
	podman run --rm \
		--volume ${PWD}:/workdir:Z \
		docker.io/mikefarah/yq:latest \
		ea '. as $$item ireduce ({}; . *+ $$item )' ./config/*.bu \
	| sed "s|<%%SSH_PUBKEY%%>|$(shell cat ${SSH_PUBKEY_PATH})|" \
	| sed "s|<%%TIMEZONE%%>|$(shell timedatectl show --va -p Timezone)|" \
	| sed "s|<%%HOSTNAME%%>|${HOSTNAME}|" \
	| sed "s|<%%OS_EXTENSIONS%%>|${OS_EXTENSIONS}|" \
	> ./generated/config.bu

butane: generate-butane

generate-ignition: butane
	rm -f ./generated/config.ign
	podman run --rm \
		--security-opt label=disable \
		--volume ${PWD}:/pwd \
		--workdir /pwd \
		quay.io/coreos/butane:release \
		--strict --files-dir ./generated/ --output ./generated/config.ign \
		./generated/config.bu

ignition: generate-ignition clean-files clean-butane

disk: ignition
	sudo podman run --rm --privileged \
		--volume /dev:/dev \
		--volume /run/udev:/run/udev \
		--volume ${PWD}:/data \
		--workdir /data \
		quay.io/coreos/coreos-installer:release \
		install --stream=${OS_STREAM} --architecture=${OS_ARCH} --ignition-file ./generated/config.ign \
		${OS_DISK}
	sleep 5

disk-rpi: disk
	sudo OS_DISK=${OS_DISK} OS_ARCH=${OS_ARCH} ./hack/rpi.sh 

serve: ignition
	python3 -m http.server -d ./generated/

clean-files:
	rm -rf ./generated/files

clean-butane:
	rm -f ./generated/config.bu

clean-ignition:
	rm -rf ./generated/config.ign

clean: clean-files clean-butane clean-ignition