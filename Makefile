PLUGIN_NAME = cyr-ius/seaweedfs-volume-plugin
PLUGIN_TAG ?= latest
PRIVATE_REGISTRY ?= localhost:5000
GITHUB_REGISTRY = ghcr.io
VERSION ?= 4.13

all: clean rootfs create

clean:
	@echo "### rm ./plugin"
	@rm -rf ./plugin

config:
	@echo "### copy config.json to ./plugin/"
	@mkdir -p ./plugin
	@cp config.json ./plugin/

rootfs: config
	@echo "### docker build: rootfs image with"
	@docker build -t ${PLUGIN_NAME}:rootfs \
		--build-arg http_proxy=${http_proxy} \
		--build-arg https_proxy=${https_proxy} \
		.
	@echo "### create rootfs directory in ./plugin/rootfs"
	@mkdir -p ./plugin/rootfs
	@docker create --name tmp ${PLUGIN_NAME}:rootfs
	@docker export tmp | tar -x -C ./plugin/rootfs
	@docker rm -vf tmp

create:
	@echo "### remove existing plugin ${PLUGIN_NAME}:${PLUGIN_TAG} if exists"
	@docker plugin rm -f ${PLUGIN_NAME}:${PLUGIN_TAG} || true
	@echo "### create new plugin ${PLUGIN_NAME}:${PLUGIN_TAG} from ./plugin"
	@docker plugin create ${PLUGIN_NAME}:${PLUGIN_TAG} ./plugin

create_private:
	@echo "### remove existing plugin (for private registry) ${PRIVATE_REGISTRY}/${PLUGIN_NAME}:${PLUGIN_TAG} if exists"
	@docker plugin rm -f ${PRIVATE_REGISTRY}/${PLUGIN_NAME}:${PLUGIN_TAG} || true
	@echo "### create new plugin (for private registry) ${PRIVATE_REGISTRY}/${PLUGIN_NAME}:${PLUGIN_TAG} from ./plugin"
	@docker plugin create ${PRIVATE_REGISTRY}/${PLUGIN_NAME}:${PLUGIN_TAG} ./plugin

login:
	@echo "### login to GitHub Container Registry"
	@echo ${GITHUB_TOKEN} | docker login ${GITHUB_REGISTRY} -u ${GITHUB_USER} --password-stdin

push: login
	@echo "### tag plugin for ghcr.io"
	@docker plugin push ${GITHUB_REGISTRY}/${PLUGIN_NAME}:${VERSION}
	@docker plugin push ${GITHUB_REGISTRY}/${PLUGIN_NAME}:latest

release: all push
	@echo "### create GitHub release v${VERSION}"
	@gh release create v${VERSION} \
		--title "Release v${VERSION}" \
		--notes "SeaweedFS Volume Plugin v${VERSION}" \
		--latest

.PHONY: all clean config rootfs create create_private login push release
