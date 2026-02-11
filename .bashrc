# =====================================================
# HOMELAB .bashrc – Productief & Docker-vriendelijk
# =====================================================

# ---- Basis instellingen ----
export EDITOR=vim
export VISUAL=vim
export LANG=en_US.UTF-8
export PATH=$HOME/bin:$PATH

# ---- Home Assistant stack pad ----
export HA_STACK="$HOME/home-assistant"

# ---- Kleuren prompt ----
# Groene user@host, blauwe path, rode errors
PS1='\[\e[32m\]\u@\h \[\e[34m\]\w\[\e[0m\]\$ '

# ---- Aliassen ----
# Veilig en snel werken
alias ll='ls -lh --color=auto'
alias la='ls -lha --color=auto'
alias l='ls -CF'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias docker='docker --config $HOME/.docker'
alias dc='docker compose'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dlogs='docker logs -f'
alias dcup='docker compose up -d'
alias dcdown='docker compose down'
alias dcb='docker compose build'
alias update='sudo apt update && sudo apt upgrade -y'
alias reboot='sudo reboot'

# ---- Home Assistant shortcuts ----
alias haup="docker compose -f $HA_STACK/docker-compose.yml up -d"
alias hadown="docker compose -f $HA_STACK/docker-compose.yml down"
alias halogs="docker compose -f $HA_STACK/docker-compose.yml logs -f"

# ---- FZF + fd ----
if [ -f /usr/share/doc/fzf/examples/key-bindings.bash ]; then
  source /usr/share/doc/fzf/examples/key-bindings.bash
fi
if [ -f /usr/share/doc/fzf/examples/completion.bash ]; then
  source /usr/share/doc/fzf/examples/completion.bash
fi

# ---- Tmux ----
# Start tmux automatisch als er geen session actief is
if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then
  tmux attach -t default || tmux new -s default
fi

# ---- Docker environment hints ----
export DOCKER_HOST=unix:///var/run/docker.sock

# ---- Safety ----
# Voorkomt dat je per ongeluk rm -rf / typt
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# ---- History settings ----
export HISTCONTROL=ignoredups:erasedups
export HISTSIZE=5000
export HISTFILESIZE=10000
shopt -s histappend

# ---- PS1 extra info ----
# Laat laatste commando status zien in prompt
PS1='\[\e[32m\]\u@\h\[\e[0m\] \[\e[34m\]\w\[\e[0m\]$([ $? -ne 0 ] && echo " \[\e[31m\]❌\[\e[0m\]")\$ '

# =====================================================
# Einde
# =====================================================