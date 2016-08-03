#
# Installation:
#
# Via shell config file  ~/.bashrc  (or ~/.zshrc)
#
#   Append the contents to config file
#   'source' the file in the config file
#
# You may also have a directory on your system that is configured
#    for completion files, such as:
#
#    /usr/local/etc/bash_completion.d/

###-begin-dartino-completion-###

DARTINO_BIN=$( cd $( dirname "${BASH_SOURCE[0]}" ) && pwd )
export PATH=$PATH:$DARTINO_BIN

if type complete &>/dev/null; then
  __dartino_completion() {
    local si="$IFS"
    IFS=$'\n' COMPREPLY=($(COMP_CWORD="$COMP_CWORD" \
                           COMP_LINE="$COMP_LINE" \
                           COMP_POINT="$COMP_POINT" \
                           dartino x-complete "${COMP_WORDS[@]}" \
                           2>/dev/null)) || return $?
    IFS="$si"
  }
  complete -F __dartino_completion dartino
elif type compdef &>/dev/null; then
  __dartino_completion() {
    si=$IFS
    compadd -- $(COMP_CWORD=$((CURRENT-1)) \
                 COMP_LINE=$BUFFER \
                 COMP_POINT=0 \
                 dartino x-complete "${words[@]}" \
                 2>/dev/null)
    IFS=$si
  }
  compdef __dartino_completion dartino
elif type compctl &>/dev/null; then
  __dartino_completion() {
    local cword line point words si
    read -Ac words
    read -cn cword
    let cword-=1
    read -l line
    read -ln point
    si="$IFS"
    IFS=$'\n' reply=($(COMP_CWORD="$cword" \
                       COMP_LINE="$line" \
                       COMP_POINT="$point" \
                       dartino x-complete "${words[@]}" \
                       2>/dev/null)) || return $?
    IFS="$si"
  }
  compctl -K __dartino_completion dartino
fi

###-end-dartino-completion-###
