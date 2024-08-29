#!/usr/bin/env bash

set -e -o pipefail

# ddcbc.sh (DDC Brightness/Contrast)
# Set monitor brightness and contrast for all DDC capable monitors
# (C) 2020-2023 ppenguin

# TODO: implement: from ddcutil 1.3.0 getvcp supports multiple feature codes (which may speedup execution)
DDC="ddcutil --sleep-multiplier=0.3 --brief"

usage() {
	sn="$(basename "${0}")"
	printf "Brightness/contrast for all DDC monitors:\n"
	printf "\tget: %s get\n" "$sn"
	printf "\tset: %s [[+/-]N] [[+/-]N]\t(N=0..100, +/- for increment, if both omitted default to 50%%, if contrast omitted same as brightness)\n" "$sn"
}

# getincorabs <value> <increment_or_absolute>
# does not check for incorrect format!
getincorabs() {
	case ${2} in
	-* | +*)
		echo "$((${1}${2}))"
		;;
	*)
		echo "${2}"
		;;
	esac
}

# getvcp <displaynr> <feature> returns int value of the feature
getvcp() {
	${DDC} -d "${1}" getvcp "${2}" | awk '{ print $4 }'
}

# setvcp <displaynr> <feature> <tgtvalue> returns <tgtvalue>
setvcp() {
	${DDC} -d "${1}" setvcp "${2}" "${3}" 1>&2
	echo "${3}"
}

# getsetvcp <displaynr> <feature> <tgtvalue> returns old and new value
getsetvcp() {
	curval=$(getvcp "${1}" "${2}")
	tgtval=$(getincorabs "${curval}" "${3}")
	res=$(setvcp "${1}" "${2}" "${tgtval}")
	echo "${curval} ${res}"
}

# setbrightness <displaynr> <incr_or_abs>
setbrightness() {
	# shellcheck disable=SC2046,SC2183
	printf "display %s: brightness %s -> %s\n" "${1}" $(getsetvcp "${1}" 10 "${2}") >&2
}

# setbrightness <displaynr> <incr_or_abs>
setcontrast() {
	# shellcheck disable=SC2046,SC2183
	printf "display %s: contrast %s -> %s\n" "${1}" $(getsetvcp "${1}" 12 "${2}") >&2
}

# setbrco <displaynr> <br> [<co>]
# set both brightness and contrast with the same value if contrast is not given
setbrco() {
	disp=${1}
	br=${2}
	if [ -n "${3}" ]; then
		co=${3}
	else
		co=${2}
	fi
	setbrightness "${disp}" "${br}"
	setcontrast "${disp}" "${co}"
}

getbrco() {
	printf "\ndisplay %s:\n\tbrightness: %s\n\tcontrast: %s\n" "${1}" "$(getvcp "${1}" 10)" "$(getvcp "${1}" 12)"
}

B=""
C=""

while [[ $# -gt 0 ]]; do
	case "${1}" in
	g*)
		CMD=getbrco
		shift
		break
		;;
	+[0-9] | -[0-9] | [0-9] | +[0-9][0-9] | -[0-9][0-9] | [0-9][0-9] | 100)
		if [ -z "${B}" ]; then
			B="${1}"
		else
			C="${1}"
		fi
		shift
		;;
	*)
		usage
		exit 1
		;;
	esac
done

# default values
B="${B:-50}"
C="${C:-${B}}"
CMD="${CMD:-setbrco}"

ND=$(${DDC} detect | awk '$0~/Display/ { print $2 }')

# different monitors async (with &) didn't work...
for N in ${ND}; do
	${CMD} "${N}" "${B}" "${C}"
done
