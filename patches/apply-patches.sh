#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <source-directory>"
    exit 1
fi
source="$(readlink -f -- "$1")"
trebledroid="$source/patches/trebledroid"
personal="$source/patches/personal"
minimal="$source/patches/minimal"

apply_patch_file() {
	local patch_file="$1"

	if patch -f -p1 --dry-run -R < "$patch_file" > /dev/null; then
		printf "### ALREDY APPLIED: $patch_file \n";
		return 0
	fi

	if git am "$patch_file"; then
		return 0
	fi

	if patch -f -p1 --dry-run < "$patch_file" > /dev/null; then
		patch -f -p1 < "$patch_file"
		git add -u
		git am --continue
		return 0
	fi

	git am --abort || true
	printf "### FAILED APPLYING: $patch_file \n"
	return 1
}

printf "\n ### APPLYING TREBLEDROID PATCHES ###\n";
sleep 1.0;
for path in $(cd $trebledroid; echo *); do
	tree="$(tr _ / <<<$path | sed -e 's;platform/;;g')"
	printf "\n| $path ###\n";
	[ "$tree" == build ] && tree=build/make
    [ "$tree" == vendor/hardware/overlay ] && tree=vendor/hardware_overlay
    [ "$tree" == treble/app ] && tree=treble_app
	pushd $tree

	for patch in $trebledroid/$path/*.patch; do
		apply_patch_file "$patch"
	done

	popd
done

printf "\n### APPLYING PERSONAL PATCHES ###\n";
sleep 1.0;
for path_personal in $(cd $personal; echo *); do
	tree="$(tr _ / <<<$path_personal | sed -e 's;platform/;;g')"
	printf "\n| $path_personal ###\n";
	[ "$tree" == build ] && tree=build/make
    [ "$tree" == vendor/hardware/overlay ] && tree=vendor/hardware_overlay
    [ "$tree" == treble/app ] && tree=treble_app
    [ "$tree" == vendor/partner/gms ] && tree=vendor/partner_gms
	pushd $tree

	for patch in $personal/$path_personal/*.patch; do
		apply_patch_file "$patch"
	done

	popd
done

printf "\n ### APPLYING MINIMAL PATCHES ###\n";
sleep 1.0;
for path in $(cd $minimal; echo *); do
	tree="$(tr _ / <<<$path | sed -e 's;platform/;;g')"
	printf "\n| $path ###\n";
	[ "$tree" == build ] && tree=build/make
    [ "$tree" == vendor/hardware/overlay ] && tree=vendor/hardware_overlay
    [ "$tree" == treble/app ] && tree=treble_app
	pushd $tree

	for patch in $minimal/$path/*.patch; do
		apply_patch_file "$patch"
	done

	popd
done
