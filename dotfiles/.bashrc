# set paths
PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"
MANPATH="/usr/local/opt/coreutils/libexec/gnuman:$MANPATH"

platform="linux"
uname=`uname`
if [[ "$uname" == "Darwin" ]]; then
	platform="mac"
fi

# enable terminal colors
export CLICOLOR=1

# dir colors
test -e ~/.dircolors && eval `dircolors -b ~/.dir_colors`

# aliases
alias ls="ls -h"
alias ll="ls -l"
alias la="ls -a"
alias lla="ll -a"
alias mkdir="mkdir -p"
alias grep="grep -Hns --color=always"
alias rgrep="grep -r"
alias tree="tree -C"
alias hosts="sudo hostfiles --interactive"

# prompt
WHITE="\[\e[37m\]"
WHITE_ON_GREEN="\[\e[37;46m\]"
GRAY="\[\e[30m\]"
RED="\[\e[31m\]"
ORANGE="\[\e[33m\]"
YELLOW="\[\e[32m\]"
GREEN="\[\e[36m\]"
GREEN_ON_GRAY="\[\e[36;40m\]"
BLUE="\[\e[34m\]"
PURPLE="\[\e[35m\]"
CLEAR="\e[0m"
GRAY_BG="\[\e[;40m\]"

ARROW=`echo -e "\xE2\x86\xB3"`
THEREFORE=`echo -e "\xE2\x88\xB4"`
BRANCH=`echo -e "\xE2\x8C\xA5"`
LBRACKET=`echo -e "\xE2\x9F\xAE"`
RBRACKET=`echo -e "\xE2\x9F\xAF"`
SYM_CHANGE=`echo -e "\xE2\x88\x86"`
SYM_NEW=`echo -e "\xE2\x9F\xA1"`
SYM_ADDED=`echo -e "\xE2\x98\x85"`

if [[ "$platform" == "mac" ]]; then
	export PS0="$WHITE$THEREFORE$WHITE_ON_GREEN\u$CLEAR$BLUE@$GREEN_ON_GRAY\h$CLEAR $ORANGE\w %{$GRAY_BG$LBRACKET$BRANCH $YELLOW%b 	$GREEN%c$PURPLE%u$RED%f$CLEAR$RBRACKET%}$CLEAR $WHITE$ARROW$CLEAR "
	export PROMPT_COMMAND='export PS1=$("$HOME"/bin/gitprompt.pl c='"$SYM_ADDED"' u='"$SYM_CHANGE"' f='"$SYM_NEW"' statuscount=1 keepempty=0)'
else
	GIT_PROMPT_ONLY_IN_REPO=1
	GIT_PROMPT_THEME=Solarized
	source ~/bin/bash-git-prompt/gitprompt.sh
	export PS1="$WHITE$THEREFORE$WHITE_ON_GREEN\u$CLEAR$BLUE@$GREEN_ON_GRAY\h$CLEAR $ORANGE\w$CLEAR $WHITE$ARROW$CLEAR "
fi

# sv command
svim() { [[ -d $1 ]] && cd $1 || CMD=`printf "'vim %s'" $1` && echo $CMD | xargs tmux new-window -n $1;}
if [[ "$platform" == "mac" ]]; then
	alias sv="mate"
	alias ssv="sudo /Users/Tim/bin/mate"
else
	alias sv="rmate"
	alias ssv="sudo /home/tim/bin/rmate"
fi


# up command
function up() {
	COUNTER="$@";
	# default $COUNTER to 1 if it isn't already set
	if [[ -z $COUNTER ]]; then
		COUNTER=1
	fi
	# make sure $COUNTER is a number
	if [ $COUNTER -eq $COUNTER 2> /dev/null ]; then
		nwd=`pwd` # Set new working directory (nwd) to current directory
		# Loop $nwd up directory tree one at a time
		until [[ $COUNTER -lt 1 ]]; do
			nwd=`dirname $nwd`
			let COUNTER-=1
		done
		cd $nwd # change directories to the new working directory
	else
		# print usage and return error
		echo "usage: up [NUMBER]"
		return 1
	fi
}

if [[ "$platform" == "mac" ]]; then
	PERL_MB_OPT="--install_base \"/Users/Tim/perl5\""; export PERL_MB_OPT;
	PERL_MM_OPT="INSTALL_BASE=/Users/Tim/perl5"; export PERL_MM_OPT;
fi
