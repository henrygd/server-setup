# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME" --depth=1
fi
# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in zsh plugins
zinit ice depth"1" wait lucid
zinit light zsh-users/zsh-syntax-highlighting
zinit ice depth"1" wait lucid
zinit light zsh-users/zsh-completions
zinit ice depth"1" wait lucid
zinit light zsh-users/zsh-autosuggestions
zinit ice depth"1" wait lucid
zinit light Aloxaf/fzf-tab

# Load completions
autoload -Uz compinit && compinit

zinit cdreplay -q

# Keybindings
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region

# vim mode
bindkey -v
bindkey -M viins jj vi-cmd-mode

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# gemini (if we want aichat)
# export GEMINI_API_KEY=""

# Aliases
alias c='clear'
alias vim="nvim"
alias vi="nvim"
alias dcu="docker compose up -d"
alias dcd="docker compose down"
alias dcr="docker compose restart"
alias dl="docker logs -f -n 30"
alias dcl="docker compose logs -f -n 30"
alias dce="docker compose exec"
# alias lg="lazygit"
alias ls="eza --icons=always"
alias bat="batcat"
alias cat="bat"
# alias b="yazi"
alias tree="ls --tree"
alias l="ls -lha"
alias se="sudoedit"
alias ctop="docker run --rm -ti --volume /var/run/docker.sock:/var/run/docker.sock:ro quay.io/vektorlab/ctop:latest"

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# Add neovim to PATH
export PATH="$PATH:/opt/nvim-linux-x86_64/bin"

# Shell integrations
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"

# Initialize Starship
eval "$(starship init zsh)"

# Run firewall script if it exists
type ~/firewall.sh &>/dev/null && ~/firewall.sh
