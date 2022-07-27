#!/usr/bin/env bash
set -euo pipefail

#mdadm --stop /dev/md* || true
#umount /dev/md* || true

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -o Dpkg::Options::="--force-confold" upgrade -q -y
apt-get -o Dpkg::Options::="--force-confold" dist-upgrade -q -y
apt install -y apt-transport-https build-essential make gcc wget git rsync gettext autopoint bison libtool automake gperf texinfo patch iptables uidmap sudo file libexplain-dev libgpgme-dev libassuan-dev libbtrfs-dev libdevmapper-dev pkg-config iptables dbus-user-session moreutils jq systemd-container daemonize < /dev/null

git config --global user.name "Ace Eldeib"

# cgroupv2 delegation
mkdir -p /etc/systemd/system/user@.service.d
tee /etc/systemd/system/user@.service.d/delegate.conf > /dev/null <<EOF
[Service]
Delegate=cpu cpuset io memory pids
EOF

tee -a /etc/sysctl.d/99-forward.conf > /dev/null <<EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF

sysctl -p
systemctl daemon-reload

GOLANG_VERSION="go1.18.2"
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

userdel nonroot || true
useradd -m /home/nonroot -s /bin/bash nonroot || true
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

wget https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init
chmod a+x rustup-init
mv rustup-init /opt/rustup-init
# sudo -H -u root bash -c "
/opt/rustup-init -y -t x86_64-unknown-linux-gnu x86_64-unknown-linux-musl --default-toolchain stable
# "
# /opt/cargo/bin/rustup install stable

ln -sf /var/run/systemd/resolve/resolv.conf /etc/resolv.conf

curl -LO https://github.com/coredns/coredns/releases/download/v1.8.4/coredns_1.8.4_linux_amd64.tgz
tar -xvzf coredns_1.8.4_linux_amd64.tgz -C /usr/bin 
chmod a+x /usr/bin/coredns
rm coredns_1.8.4_linux_amd64.tgz

curl -o runc -L https://github.com/opencontainers/runc/releases/download/v1.0.2/runc.amd64
install -m 0555 runc /usr/local/sbin/runc
rm runc

containerd_version="1.6.6"
curl -LO https://github.com/containerd/containerd/releases/download/v${containerd_version}/containerd-${containerd_version}-linux-amd64.tar.gz
tar -xvzf containerd-${containerd_version}-linux-amd64.tar.gz -C /usr
rm containerd-${containerd_version}-linux-amd64.tar.gz

curl -LO https://github.com/containerd/stargz-snapshotter/releases/download/v0.8.0/stargz-snapshotter-v0.8.0-linux-amd64.tar.gz
tar -C /usr/local/bin -xvzf stargz-snapshotter-v0.8.0-linux-amd64.tar.gz containerd-stargz-grpc ctr-remote
wget -O /etc/systemd/system/stargz-snapshotter.service https://raw.githubusercontent.com/containerd/stargz-snapshotter/main/script/config/etc/systemd/system/stargz-snapshotter.service
rm stargz-snapshotter-v0.8.0-linux-amd64.tar.gz

curl -LO https://github.com/moby/buildkit/releases/download/v0.9.0/buildkit-v0.9.0.linux-amd64.tar.gz
tar -xvzf buildkit-v0.9.0.linux-amd64.tar.gz -C /usr/local
rm buildkit-v0.9.0.linux-amd64.tar.gz

mkdir -p /opt/cni/bin
curl -LO https://github.com/containernetworking/plugins/releases/download/v1.0.1/cni-plugins-linux-amd64-v1.0.1.tgz
tar -xvzf cni-plugins-linux-amd64-v1.0.1.tgz -C /opt/cni/bin/
rm cni-plugins-linux-amd64-v1.0.1.tgz

curl -LO https://github.com/AkihiroSuda/cni-isolation/releases/download/v0.0.3/cni-isolation-amd64.tgz
tar -xvzf cni-isolation-amd64.tgz -C /opt/cni/bin/
rm cni-isolation-amd64.tgz

curl -LO https://github.com/containerd/nerdctl/releases/download/v0.11.2/nerdctl-full-0.11.2-linux-amd64.tar.gz
tar -xvzf nerdctl-full-0.11.2-linux-amd64.tar.gz -C /usr/
rm nerdctl-full-0.11.2-linux-amd64.tar.gz

curl -LO https://download.docker.com/linux/static/stable/x86_64/docker-20.10.8.tgz
tar -xvzf docker-20.10.8.tgz

install -m 0555 docker/dockerd /usr/bin/dockerd
install -m 0555 docker/docker-init /usr/bin/docker-init
install -m 0555 docker/docker-proxy /usr/bin/docker-proxy
install -m 0555 docker/docker /usr/bin/docker
rm -rf docker 
rm docker-20.10.8.tgz

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
usermod -aG docker nonroot

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

# mkdir -p /etc/coredns
# tee /etc/coredns/Corefile > /dev/null <<EOF
# . {
#     forward . 127.0.0.1:5301 127.0.0.1:5302 127.0.0.1:5303
#     errors
#     loop
#     reload
#     cache {
#         success 5000
#         denial 2500
#     }
# }

# .:5301 {
#     forward . 8.8.8.8 8.8.4.4 {
#         tls_servername dns.google
#         health_check 5s
#     }
# }

# .:5302 {
#     forward . 1.1.1.1 1.0.0.1 {
#         tls_servername cloudflare-dns.com
#         health_check 5s
#     }
# }

# .:5303 {
#     forward . 9.9.9.9 {
#         tls_servername dns.quad9.net
#         health_check 5s
#     }
# }
# EOF

tee /etc/systemd/system/buildkit.service > /dev/null <<EOF
[Unit]
Description=BuildKit
Requires=buildkit.socket
After=buildkit.socket
Documentation=https://github.com/moby/buildkit

[Service]
ExecStart=/usr/local/bin/buildkitd --addr fd:// --oci-worker=true --oci-worker-snapshotter=stargz --containerd-worker=false --containerd-worker-snapshotter=stargz

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
# containerd config default > /etc/containerd/config.toml
# default config + stargz.
tee /etc/containerd/config.toml > /dev/null <<EOF
disabled_plugins = []
imports = []
oom_score = 0
plugin_dir = ""
required_plugins = []
root = "/var/lib/containerd"
state = "/run/containerd"
version = 2

[cgroup]
  path = ""

[debug]
  address = ""
  format = ""
  gid = 0
  level = ""
  uid = 0

[grpc]
  address = "/run/containerd/containerd.sock"
  gid = 0
  max_recv_message_size = 16777216
  max_send_message_size = 16777216
  tcp_address = ""
  tcp_tls_cert = ""
  tcp_tls_key = ""
  uid = 0

[metrics]
  address = "0.0.0.0:10257"
  grpc_histogram = false

[plugins]

  [plugins."io.containerd.gc.v1.scheduler"]
    deletion_threshold = 0
    mutation_threshold = 100
    pause_threshold = 0.02
    schedule_delay = "0s"
    startup_delay = "100ms"

  [plugins."io.containerd.grpc.v1.cri"]
    disable_apparmor = false
    disable_cgroup = false
    disable_hugetlb_controller = true
    disable_proc_mount = false
    disable_tcp_service = true
    enable_selinux = false
    enable_tls_streaming = false
    ignore_image_defined_volumes = false
    max_concurrent_downloads = 3
    max_container_log_line_size = 16384
    netns_mounts_under_state_dir = false
    restrict_oom_score_adj = false
    sandbox_image = "k8s.gcr.io/pause:3.5"
    selinux_category_range = 1024
    stats_collect_period = 10
    stream_idle_timeout = "4h0m0s"
    stream_server_address = "127.0.0.1"
    stream_server_port = "0"
    systemd_cgroup = false
    tolerate_missing_hugetlb_controller = true
    unset_seccomp_profile = ""

    [plugins."io.containerd.grpc.v1.cri".cni]
      bin_dir = "/opt/cni/bin"
      conf_dir = "/etc/cni/net.d"
      conf_template = ""
      max_conf_num = 1

    [plugins."io.containerd.grpc.v1.cri".containerd]
      default_runtime_name = "runc"
      disable_snapshot_annotations = true
      discard_unpacked_layers = false
      no_pivot = false
      snapshotter = "stargz"

      [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime]
        base_runtime_spec = ""
        container_annotations = []
        pod_annotations = []
        privileged_without_host_devices = false
        runtime_engine = ""
        runtime_root = ""
        runtime_type = ""

        [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime.options]

      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]

        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          base_runtime_spec = ""
          container_annotations = []
          pod_annotations = []
          privileged_without_host_devices = false
          runtime_engine = ""
          runtime_root = ""
          runtime_type = "io.containerd.runc.v2"

          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            BinaryName = ""
            CriuImagePath = ""
            CriuPath = ""
            CriuWorkPath = ""
            IoGid = 0
            IoUid = 0
            NoNewKeyring = false
            NoPivotRoot = false
            Root = ""
            ShimCgroup = ""
            SystemdCgroup = true

      [plugins."io.containerd.grpc.v1.cri".containerd.untrusted_workload_runtime]
        base_runtime_spec = ""
        container_annotations = []
        pod_annotations = []
        privileged_without_host_devices = false
        runtime_engine = ""
        runtime_root = ""
        runtime_type = ""

        [plugins."io.containerd.grpc.v1.cri".containerd.untrusted_workload_runtime.options]

    [plugins."io.containerd.grpc.v1.cri".image_decryption]
      key_model = "node"

    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = ""

      [plugins."io.containerd.grpc.v1.cri".registry.auths]

      [plugins."io.containerd.grpc.v1.cri".registry.configs]

      [plugins."io.containerd.grpc.v1.cri".registry.headers]

      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]

    [plugins."io.containerd.grpc.v1.cri".x509_key_pair_streaming]
      tls_cert_file = ""
      tls_key_file = ""

  [plugins."io.containerd.internal.v1.opt"]
    path = "/opt/containerd"

  [plugins."io.containerd.internal.v1.restart"]
    interval = "10s"

  [plugins."io.containerd.metadata.v1.bolt"]
    content_sharing_policy = "shared"

  [plugins."io.containerd.monitor.v1.cgroups"]
    no_prometheus = false

  [plugins."io.containerd.runtime.v1.linux"]
    no_shim = false
    runtime = "runc"
    runtime_root = ""
    shim = "containerd-shim"
    shim_debug = false

  [plugins."io.containerd.runtime.v2.task"]
    platforms = ["linux/amd64"]

  [plugins."io.containerd.service.v1.diff-service"]
    default = ["walking"]

  [plugins."io.containerd.snapshotter.v1.aufs"]
    root_path = ""

  [plugins."io.containerd.snapshotter.v1.btrfs"]
    root_path = ""

  [plugins."io.containerd.snapshotter.v1.devmapper"]
    async_remove = false
    base_image_size = ""
    pool_name = ""
    root_path = ""

  [plugins."io.containerd.snapshotter.v1.native"]
    root_path = ""

  [plugins."io.containerd.snapshotter.v1.overlayfs"]
    root_path = ""

  [plugins."io.containerd.snapshotter.v1.zfs"]
    root_path = ""

[proxy_plugins]
    [proxy_plugins.stargz]
        type = "snapshot"
        address = "/run/containerd-stargz-grpc/containerd-stargz-grpc.sock"

[stream_processors]

  [stream_processors."io.containerd.ocicrypt.decoder.v1.tar"]
    accepts = ["application/vnd.oci.image.layer.v1.tar+encrypted"]
    args = ["--decryption-keys-path", "/etc/containerd/ocicrypt/keys"]
    env = ["OCICRYPT_KEYPROVIDER_CONFIG=/etc/containerd/ocicrypt/ocicrypt_keyprovider.conf"]
    path = "ctd-decoder"
    returns = "application/vnd.oci.image.layer.v1.tar"

  [stream_processors."io.containerd.ocicrypt.decoder.v1.tar.gzip"]
    accepts = ["application/vnd.oci.image.layer.v1.tar+gzip+encrypted"]
    args = ["--decryption-keys-path", "/etc/containerd/ocicrypt/keys"]
    env = ["OCICRYPT_KEYPROVIDER_CONFIG=/etc/containerd/ocicrypt/ocicrypt_keyprovider.conf"]
    path = "ctd-decoder"
    returns = "application/vnd.oci.image.layer.v1.tar+gzip"

[timeouts]
  "io.containerd.timeout.shim.cleanup" = "5s"
  "io.containerd.timeout.shim.load" = "5s"
  "io.containerd.timeout.shim.shutdown" = "3s"
  "io.containerd.timeout.task.state" = "2s"

[ttrpc]
  address = ""
  gid = 0
  uid = 0
EOF

systemctl enable --now stargz-snapshotter
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

pushd /tmp
go install github.com/onsi/ginkgo/ginkgo@latest
go install github.com/golang/mock/mockgen@v1.6.0
popd

mkdir -p /home/nonroot/code

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
