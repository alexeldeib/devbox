#!/usr/bin/env bash
set -euxo pipefail

userdel nonroot || true
useradd -m -s /bin/bash nonroot || true

pacman -Syu

pacman -S base-devel git wget moreutils ripgrep

echo "setting up paru workdir"
pushd /tmp
git clone https://aur.archlinux.org/paru.git
pushd paru
chmod -R a+rw /tmp
sudo -H -u nonroot bash -c 'makepkg -si'
popd
sudo -H -u nonroot bash -c 'paru --noconfirm -S azure-cli'
sudo -H -u nonroot bash -c 'paru --noconfirm -S smem'
popd
rm -r "$WORKDIR"

git config --global user.name "Ace Eldeib"

mkdir -p /etc/systemd/system/user@.service.d
tee /etc/systemd/system/user@.service.d/delegate.conf > /dev/null <<EOF
[Service]
Delegate=cpu cpuset io memory pids
EOF


tee -a /etc/sysctl.d/99-forward.conf > /dev/null <<EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF

sysctl --system
systemctl daemon-reload

GOLANG_VERSION="$(curl -s 'https://go.dev/VERSION?m=text' | head -n 1)"
echo "Downloading ${GOLANG_VERSION}"
curl -O "https://dl.google.com/go/${GOLANG_VERSION}.linux-amd64.tar.gz"

echo "unpacking go"
mkdir -p /usr/local/go
chown -R "$(whoami):$(whoami)" /usr/local/go 
tar -xvf "${GOLANG_VERSION}.linux-amd64.tar.gz" -C /usr/local > log 2>&1
rm "${GOLANG_VERSION}.linux-amd64.tar.gz"

export PATH="/usr/local/go/bin:$PATH"
export GOPATH="/root/go"
export RUSTUP_HOME="/opt/rustup"
export CARGO_HOME="/opt/cargo/bin"
export PATH="${PATH}:/opt/cargo/bin"

tee -a /root/.bashrc > /dev/null <<'EOF'
export PATH="/usr/local/go/bin:/root/go/bin:$PATH"
export GOPATH="/root/go"
export PATH="${PATH}:/opt/cargo/bin:/opt"
EOF

tee /etc/sudoers.d/nonroot > /dev/null <<EOF
nonroot ALL=(ALL) NOPASSWD:ALL
EOF

mkdir -p $GOPATH/bin
chmod a+x /usr/local/go/bin

tee -a /home/nonroot/.bashrc > /dev/null <<'EOF'
export PATH="/usr/local/go/bin:/home/nonroot/go/bin:$PATH"
export GOPATH="/home/nonroot/go"
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export PATH="${PATH}:/opt/cargo/bin:/opt"
EOF

tee /home/nonroot/.profile > /dev/null <<'EOF'
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
EOF

ln -sf /var/run/systemd/resolve/resolv.conf /etc/resolv.conf

oras_version="1.0.1"
curl -LO "https://github.com/oras-project/oras/releases/download/v${oras_version}/oras_${oras_version}_linux_amd64.tar.gz"
mkdir -p oras-install/
tar -zxf oras_${oras_version}_*.tar.gz -C oras-install/
sudo mv oras-install/oras /usr/local/bin/
rm -rf oras_${oras_version}_*.tar.gz oras-install/

runc_version="1.1.9"
curl -o runc -L https://github.com/opencontainers/runc/releases/download/v${runc_version}/runc.amd64
install -m 0555 runc /usr/local/sbin/runc
rm runc

kubectl_version="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
curl -LO "https://dl.k8s.io/release/${kubectl_version}/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

containerd_version="1.7.1"
curl -LO https://github.com/containerd/containerd/releases/download/v${containerd_version}/containerd-${containerd_version}-linux-amd64.tar.gz
tar -xvzf containerd-${containerd_version}-linux-amd64.tar.gz -C /usr
rm containerd-${containerd_version}-linux-amd64.tar.gz

buildkit_version="v0.11.2"
curl -LO https://github.com/moby/buildkit/releases/download/${buildkit_version}/buildkit-${buildkit_version}.linux-amd64.tar.gz
tar -xvzf buildkit-${buildkit_version}.linux-amd64.tar.gz -C /usr/local
rm buildkit-${buildkit_version}.linux-amd64.tar.gz

cni_plugin_version="v1.3.0"
mkdir -p /opt/cni/bin
curl -LO https://github.com/containernetworking/plugins/releases/download/${cni_plugin_version}/cni-plugins-linux-amd64-${cni_plugin_version}.tgz
tar -xvzf cni-plugins-linux-amd64-${cni_plugin_version}.tgz -C /opt/cni/bin/
rm cni-plugins-linux-amd64-${cni_plugin_version}.tgz

curl -LO https://github.com/AkihiroSuda/cni-isolation/releases/download/v0.0.3/cni-isolation-amd64.tgz
tar -xvzf cni-isolation-amd64.tgz -C /opt/cni/bin/
rm cni-isolation-amd64.tgz

nerdctl_version="1.5.0"
curl -LO https://github.com/containerd/nerdctl/releases/download/v${nerdctl_version}/nerdctl-full-${nerdctl_version}-linux-amd64.tar.gz
tar -xvzf nerdctl-full-${nerdctl_version}-linux-amd64.tar.gz -C /usr/
rm nerdctl-full-${nerdctl_version}-linux-amd64.tar.gz

docker_version="24.0.5"
curl -LO https://download.docker.com/linux/static/stable/x86_64/docker-${docker_version}.tgz
tar -xvzf docker-${docker_version}.tgz

install -m 0555 docker/dockerd /usr/bin/dockerd
install -m 0555 docker/docker-init /usr/bin/docker-init
install -m 0555 docker/docker-proxy /usr/bin/docker-proxy
install -m 0555 docker/docker /usr/bin/docker
rm -rf docker
rm docker-${docker_version}.tgz

buildx_version="0.11.2"
mkdir -p $(dirname /usr/local/lib/docker/cli-plugins/docker-buildx)
wget https://github.com/docker/buildx/releases/download/v${buildx_version}/buildx-v${buildx_version}.linux-amd64
mv buildx-v${buildx_version}.linux-amd64 /usr/local/lib/docker/cli-plugins/docker-buildx
chmod a+x /usr/local/lib/docker/cli-plugins/docker-buildx

go install github.com/schollz/croc/v9@latest

echo "installing rootlessctl + rootlesskit"
WORKDIR="$(mktemp -d)"
pushd "$WORKDIR"
git clone https://github.com/rootless-containers/rootlesskit
cd rootlesskit
go install ./cmd/rootlessctl
go install ./cmd/rootlesskit
chmod a+x /root/go/bin/*
cp -a /root/go/bin/* /usr/local/bin/
popd
echo "removing rootlessctl + rootlesskit work dir"
rm -r "$WORKDIR"

WORKDIR="src-skopeo"
mkdir "$WORKDIR"
pushd "$WORKDIR"
echo "Cloning skopeo"
git clone https://github.com/containers/skopeo
echo "Descending into source dir"
pushd skopeo
echo "building skopeo"
make bin/skopeo
echo "Copying skopeo default-policy.json to config dir"
mkdir -p /etc/containers
cp default-policy.json /etc/containers/policy.json
echo "installing skopeo"
install -m 0555 "bin/skopeo" /usr/local/bin/skopeo 
popd
popd
echo "cleaning up skopeo"
rm -rf "$WORKDIR"

echo "setting up umoci work dir"
WORKDIR="$(mktemp -d)"
pushd "$WORKDIR"
echo "Cloning umoci"
git clone https://github.com/opencontainers/umoci
echo "Descending to source folder"
pushd "umoci/cmd/umoci"
echo "Building umoci"
CGO_ENABLED=1 go build -o umoci .
echo "installing umoci"
install -m 0555 umoci /usr/local/bin/umoci 
popd
popd
rm -rf "$WORKDIR"

WORKDIR="$(mktemp -d)"
pushd "$WORKDIR"
git clone https://github.com/karelzak/util-linux
pushd util-linux
# make static version
./autogen.sh
./configure
make LDFLAGS="--static" unshare
install -m 0555 unshare /usr/local/bin/unshare
popd
popd
rm -rf "$WORKDIR"

groupadd docker || true 
userdel nonroot || true
useradd -d /home/nonroot -s /bin/bash nonroot || true
mkdir -p /home/nonroot/.ssh
cp ~/.ssh/authorized_keys /home/nonroot/.ssh/authorized_keys
chown -R nonroot:nonroot /home/nonroot
usermod -aG docker nonroot

rm -rf /nix /etc/bash.bashrc.backup-before-nix /etc/zshrc /etc/zshrc.backup-before-nix /etc/bashrc /etc/profile.d/nix.sh /etc/profile.d/nix.sh.backup-before-nix || true

sudo -H -u nonroot bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash'
sudo -H -u nonroot bash -c 'source ~/.nvm/nvm.sh && nvm install --lts && nvm use --lts'
sudo -H -u nonroot bash -c 'sh <(curl -L https://nixos.org/nix/install) --daemon'

tee /etc/nix/nix.conf > /dev/null <<EOF
build-users-group = nixbld
experimental-features = nix-command flakes
EOF

tee /etc/systemd/system/containerd.service > /dev/null <<EOF
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/bin/containerd

Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this version.
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF

tee /etc/systemd/system/docker.service > /dev/null <<'EOF'
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target docker.socket firewalld.service containerd.service
Wants=network-online.target containerd.service
Requires=docker.socket

[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock --iptables=true
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutStartSec=0
RestartSec=2
Restart=always

# Note that StartLimit* options were moved from "Service" to "Unit" in systemd 229.
# Both the old, and new location are accepted by systemd 229 and up, so using the old location
# to make them work for either version of systemd.
StartLimitBurst=3

# Note that StartLimitInterval was renamed to StartLimitIntervalSec in systemd 230.
# Both the old, and new name are accepted by systemd 230 and up, so using the old name to make
# this option work for either version of systemd.
StartLimitInterval=60s

# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity

# Comment TasksMax if your systemd version does not support it.
# Only systemd 226 and above support this option.
TasksMax=infinity   

# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes

# kill only the docker process, not all processes in the cgroup
KillMode=process
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
EOF

tee /etc/systemd/system/docker.socket > /dev/null <<EOF
[Unit]
Description=Docker Socket for the API

[Socket]
# If /var/run is not implemented as a symlink to /run, you may need to
# specify ListenStream=/var/run/docker.sock instead.
ListenStream=/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
EOF

tee /etc/systemd/system/buildkit.service > /dev/null <<EOF
[Unit]
Description=BuildKit
Requires=buildkit.socket
After=buildkit.socket
Documentation=https://github.com/moby/buildkit

[Service]
ExecStart=/usr/local/bin/buildkitd --addr fd:// --oci-worker=true --containerd-worker=false

[Install]
WantedBy=multi-user.target
EOF

tee /etc/systemd/system/buildkit.socket > /dev/null <<EOF
[Unit]
Description=BuildKit
Documentation=https://github.com/moby/buildkit

[Socket]
ListenStream=%t/buildkit/buildkitd.sock
SocketMode=0660

[Install]
WantedBy=sockets.target
EOF

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
# default config + stargz.

systemctl enable containerd 
systemctl restart containerd
systemctl enable docker.socket
systemctl enable docker
systemctl restart docker
systemctl enable buildkit.socket
systemctl enable buildkit
systemctl restart buildkit

# cp /etc/default/grub /etc/default/grub.old
# sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1"/' /etc/default/grub
# update-grub

WORKDIR="$(mktemp -d)"
pushd "$WORKDIR"
git clone https://github.com/regclient/regclient.git
cd regclient
make
bin/regctl version
install -m 0555 bin/regctl /usr/local/bin/regctl
popd
echo "removing rootlessctl + rootlesskit work dir"
rm -r "$WORKDIR"

pushd /tmp
go install github.com/onsi/ginkgo/ginkgo@latest
go install github.com/golang/mock/mockgen@v1.6.0
popd

mkdir -p /home/nonroot/code

curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# tee /usr/local/bin/nonroot-setup.sh > /dev/null <<EOF
# #!/usr/bin/env bash
# containerd-rootless-setuptool.sh install
# containerd-rootless-setuptool.sh install-buildkit
# set +e
# containerd-rootless-setuptool.sh install-stargz
# set -e
# mkdir -p /home/nonroot/.config/containerd
# sudo chown -R nonroot /home/nonroot/.config/containerd
# echo '
# [plugins]
#   [plugins."io.containerd.grpc.v1.cri"]
#     [plugins."io.containerd.grpc.v1.cri".containerd]
#       disable_snapshot_annotations = true
#       snapshotter = "stargz"
# [proxy_plugins]
#   [proxy_plugins."stargz"]
#     type = "snapshot"
#     address = "/run/user/1000/containerd-stargz-grpc/containerd-stargz-grpc.sock"
# ' > /home/nonroot/.config/containerd/config.toml
# systemctl --user restart containerd
# timeout 3 systemctl --user status containerd
# EOF
# chmod a+x /usr/local/bin/nonroot-setup.sh
# machinectl --uid "$(id -u nonroot)" shell .host /usr/bin/env bash /usr/local/bin/nonroot-setup.sh

# curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.gpg | sudo apt-key add -
# curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.list | sudo tee /etc/apt/sources.list.d/tailscale.list
# sudo apt-get update
# sudo apt-get install tailscale
# tailscale up --authkey=$1
