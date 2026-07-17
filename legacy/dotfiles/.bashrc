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
if [[ "$platform" == "mac" ]]; then
	alias ls="ls -hC"
else
	alias ls="ls -h --color"
fi
alias ll="ls -l"
alias la="ls -a"
alias lla="ll -a"
alias mkdir="mkdir -p"
alias grep="grep -Hins --color=always"
alias rgrep="grep -r"
alias tree="tree -C"
alias hosts="sudo hostfiles --interactive"

# Only load Liquid Prompt in interactive shells, not from a script or from scp
[[ $- = *i* ]] && source ~/liquidprompt/liquidprompt

# sv command
svim() { [[ -d $1 ]] && cd $1 || CMD=`printf "'vim %s'" $1` && echo $CMD | xargs tmux new-window -n $1;}
if [[ "$platform" == "mac" ]]; then
	alias sv="mate"
	alias ssv="sudo /Users/$USER/bin/mate"
else
	alias sv="rmate"
	alias ssv="sudo /home/$USER/bin/rmate"
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
