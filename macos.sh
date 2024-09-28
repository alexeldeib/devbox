# TODO
# - chrome
# - 1pass
# - tailscale

# kubectx/kubie
# kubens

# interactive
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"


tee -a ~/.zprofile <<'EOF'
eval "$(/opt/homebrew/bin/brew shellenv)"
EOF
source ~/.zprofile

brew install google-cloud-sdk kitty oci-cli kubernetes-cli
brew install --cask slack visual-studio-code iterm2 warp

curl -fsSL -O https://raw.githubusercontent.com/ahmetb/kubectl-aliases/master/.kubectl_aliases
mv .kubectl_aliases ~/

tee -a ~/.zprofile <<'EOF'
source .kubectl_aliases
source "$(brew --prefix)/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc"
source "$(brew --prefix)/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc"
EOF

source ~/.zprofile

# interactive
gcloud components install gke-gcloud-auth-plugin

