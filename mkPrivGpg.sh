#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set +x

THIS=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
NIXOUT=$THIS/home/${USER}/sops-gpg.nix
GPGSECDIR="$THIS/home/${USER}/_secrets/gpg-private"
GPKDIR="private-keys-v1.d"
GPGDIR=~/.gnupg
KBX="pubring.kbx"

usage() {
	printf "\nUsage:\n\t%s <command>\n\n\twith <command> one of:\n\n" "$(basename "$0")"
	printf "\t\t%s\t%s\n" "edit" "materialise ~/.gnupg symlinks for editing"
	printf "\t\t%s\t%s\n\t\t\t%s\n" \
		"encode" \
		"(re)encode ~/.gnupg files (after editing) to sops dir" \
		"(remember to gennix if you added keys)"
	printf "\t\t%s\t%s\n" "gennix" "generate $NIXOUT file (overwrites existing!)"
}

enc_privkeys() {
	(
		cd $GPGDIR || return 1
		for k in "${GPKDIR}"/*.key $KBX; do
			# if the key is a link, we assume it's already a sops one
			if [ -L "$k" ]; then
				printf 'Ignoring symlink %s (assumed already in sops)\n' "$k" >&2
			else
				tgt="${GPGSECDIR}/$(basename "${k}").enc"
				#shellcheck disable=SC2015
				cp -f "$k" "${tgt}" &&
					sops --config "${THIS}/.sops.yaml" --encrypt --in-place "${tgt}" ||
					rm -f "${tgt}"
			fi
		done
	)
}

get_secrets_sops() {
	(
		cd "$GPGSECDIR" || return 1
		for k in *.key.enc; do
			kf="$(basename "$k" .enc)"
			#shellcheck disable=SC2016
			printf '\n      "%s" = 
                { 
                  format = "binary";
                  sopsFile = ./_secrets/gpg-private/%s;
                  mode = "0400";
                  path = "${config.home.homeDirectory}/.gnupg/private-keys-v1.d/%s";
                };' \
				"$kf" \
				"$k" \
				"$kf"
		done

		for k in "${KBX}"*; do
			kf="$(basename "$k" .enc)"
			#shellcheck disable=SC2016
			printf '\n      "%s" = 
                { 
                  format = "binary";
                  sopsFile = ./_secrets/gpg-private/%s;
                  mode = "0444";
                  path = "${config.home.homeDirectory}/.gnupg/%s";
                };' \
				"$kf" \
				"$k" \
				"$kf"
		done
	)
}

# (re)encode gpg files to flake secrets dir
enc() {
	printf 'Writing sops secrets to %s\n' "${GPGSECDIR}/"
	enc_privkeys
}

# gensopsnix: generate the sops-nix HM cfg
gensopsnix() {
	printf 'Writing sops gpg keys HM config to %s\n' "$NIXOUT"
	cat <<EOF | tee "$NIXOUT"
{ config, ...}: {
    sops.secrets = {
        $(get_secrets_sops)
    };
}
EOF
}

# decunlink: replace symlinks in ~/.gnupg to real files
# for the purpose of editing them (e.g. unexpire) to be re-encrypted
decunlink() {
	td="${GPGDIR}/${GPKDIR}"
	(
		cd $td || return 1
		for f in *.key; do
			mv "$f" "_$f" &&
				cp "_$f" "$f" &&
				chmod 644 "$f" &&
				rm -f "_$f"
		done
	)
	mv "$GPGDIR/$KBX" "$GPGDIR/_$KBX" &&
		cp "$GPGDIR/_$KBX" "$GPGDIR/$KBX" &&
		chmod 644 "$GPGDIR/$KBX" &&
		rm -f "$GPGDIR/_$KBX"
}

CMD=${1:-""}
case "$CMD" in
edit)
	decunlink
	;;
encode)
	enc
	;;
gennix)
	gensopsnix
	;;
*)
	usage
	exit 1
	;;
esac
