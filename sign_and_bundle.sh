#!/usr/bin/env bash

# require bash 4.x or later

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

export __TEMP_DIR__="$(mktemp -d)"
readonly script_tmp_dir="$__TEMP_DIR__"

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  if [[ -d "$__TEMP_DIR__" ]]; then
    rm -fr "$__TEMP_DIR__"
  fi
}

readonly key_id="$1"
shift 1

if [[ -z "${SIGNING_PASSPHRASE:-}" ]]; then
  echo "Enter the passphrase." 1>&2
  read -s -t 5 -r passphrase
else
  passphrase="$SIGNING_PASSPHRASE"
fi

sign_with_ascii_detached_sig() {
  local -r signee_file="$1"

  if [[ ! -f "$signee_file" ]]; then
    echo "$signee_file is not found." 1>&2
    exit 1
  fi

  gpg --pinentry-mode loopback --passphrase-fd 0 --batch --yes -ab -u "$key_id" "$signee_file" <<< "$passphrase"
}

list_all_signees() {
  find . -type f | grep -v ".*\.asc"
}

main() {
  local -r working_directory="${WORKING_DIRECTORY:-maven}"

  mkdir -p "$working_directory"
  pushd "$working_directory"

  local group_id="${1:?group id is required}" artifact_id="${2:-}" version="${3:-}" artifact=
  local -r group_id_based_path="${group_id//.//}"

  cd "$group_id_based_path"

  declare -a artifact_id_directories=()

  if [[ -n "$artifact_id" ]]; then
    artifact_id_directories+=("$artifact_id")
  else
    mapfile -d $'\0' artifact_id_directories < <(find . -type d -maxdepth 1 -print0)
  fi

  for artifact_id_directory in "${artifact_id_directories[@]}"; do
    if [[ "$artifact_id_directory" == "." ]]; then
      continue
    fi

    pushd "$artifact_id_directory"
    artifact_id="$(basename $PWD)"

    declare -a version_directories=()

    if [[ -n "$version" ]]; then
      version_directories+=("$version")
    else
      mapfile -d $'\0' version_directories < <(find . -type d -maxdepth 1 -print0)
    fi

    for version_directory in "${version_directories[@]}"; do
      if [[ "$version_directory" == "." ]]; then
        continue
      fi

      pushd "$version_directory"
      version="$(basename $PWD)"

      if ls -1 | grep ".asc" >/dev/null 2>&1; then
        echo "$artifact_id/$version already contains detached signatures so skipped signing, just will do bundling" 1>&2
      else
        echo "Start sigining $artifact_id/$version" 1>&2
        while read artifact; do
          sign_with_ascii_detached_sig "$artifact"
        done < <(find . -type f -maxdepth 1 | grep -v ".*.backup")
      fi

      if [[ -f "$artifact_id-$version-bundle.jar" ]]; then
        cp "$artifact_id-$version-bundle.jar" "$artifact_id-$version-bundle.jar.backup"
      fi

      jar -cvf "$artifact_id-$version-bundle.jar" $(find . -type f -maxdepth 1 | grep -v ".*.backup" | xargs)

      popd >/dev/null 2>&1
    done
  done
}

main "$@"