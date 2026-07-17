#!/bin/bash

repo=`pwd`

link() {
	from="$1"
	to="$2"
	echo "Linking '$from' to '$to'"
	rm -f "$to"
	ln -sf "$from" "$to"
}

echo "Symlinking dotfiles from $repo/dotfiles"
for location in $(find dotfiles -name '.*'); do
	file="${location##*/}"
	file="${file%.sh}"
	link "$repo/$location" "$HOME/$file"
done

echo
echo "Symlinking scripts from $repo/scripts"
mkdir -p "$HOME/bin"
for location in $(find scripts/* -maxdepth 1 -exec basename {} \;); do
	file="${location##*/}"
	file="${file%.sh}"
	link "$repo/scripts/$location" "$HOME/bin/$location"
done

ln -s liquidprompt $HOME/liquidprompt