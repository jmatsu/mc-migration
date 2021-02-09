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

if [[ -z "${NEXUS_USERNAME:-}" ]]; then
  echo "Enter the nexus username." 1>&2
  read -s -t 5 -r nexus_username
else
  nexus_username="$NEXUS_USERNAME"
fi

if [[ -z "${NEXUS_PASSWORD:-}" ]]; then
  echo "Enter the nexus password." 1>&2
  read -s -t 5 -r nexus_password
else
  nexus_password="$NEXUS_PASSWORD"
fi

main() {
  local -r working_directory="${WORKING_DIRECTORY-maven}"

  mkdir -p "$working_directory"
  pushd "$working_directory"

  local group_id="${1:?group id is required}" artifact_id="${2:-}" version="${3:-}" bundle_jar=
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

      bundle_jar="$artifact_id-$version-bundle.jar"
      
      if [[ ! -f "$bundle_jar" ]]; then
        echo "$bundle_jar does not exist so skipped"
      else
        curl \
          -f# \
          -u "$nexus_username:$nexus_password" \
          -X POST \
          -F "file=@$PWD/$bundle_jar" \
          "https://oss.sonatype.org/service/local/staging/bundle_upload"
      fi

      popd >/dev/null 2>&1
    done
  done
}

main "$@"