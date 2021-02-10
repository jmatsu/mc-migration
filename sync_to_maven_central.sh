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

log() {
  echo "$*" 1>&2
}

ask() {
  local -r yes_msg="$1" no_msg="$2"
  local answer= ok="false"
  select answer in Yes No; do
    case "$answer" in
      "Yes")
        log "$yes_msg"
        ok="true"
        break
        ;;
      "No")
        log "$no_msg"
        ok="false"
        break
        ;;
      *)
        log "Canceled the procedure"
        exit 1
        ;;
    esac
  done

  [[ "$ok" == "true" ]]
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

  local group_id="${1:?group id is required}" artifact_id="${2:-}" version="${3:-}"
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

    pushd "$artifact_id_directory" >/dev/null 1>&2
    artifact_id="$(basename $PWD)"
    
    log "Dive into $artifact_id"

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

      pushd "$version_directory" >/dev/null 1>&2
      version="$(basename $PWD)"
    
      log "Look up $artifact_id/$version"
      
      if [[ ! -f "response.json" ]]; then
        log "$PWD/response.json does not exist so skipped"
      elif [[ -f "release.json" ]]; then
        log "$PWD/released.json"
      else
        local repo_content_url= pom_url= repo_id= repo_state_json= 

        repo_content_url="$(ruby -r json -e 'puts JSON.parse(File.read(ARGV[0])).dig("repositoryUris", 0)' response.json)"
        pom_url="$repo_content_url/$group_id_based_path/$artifact_id/$version/$artifact_id-$version.pom"

        if ! curl -sSLf --head -u "$nexus_username:$nexus_password" "$pom_url" >/dev/null 2>&1; then
          log "$pom_url is not found. The current file state is untrusted."
          exit 1
        fi

        log "pom is available."

        repo_id="$(basename $repo_content_url)"

        repo_state_json="$script_tmp_dir/$repo_id.json"

        curl \
          -sSLf \
          -u "$nexus_username:$nexus_password" \
          -X GET \
          -H 'Accept: application/json' \
          -o "$repo_state_json" \
          "https://oss.sonatype.org/service/local/staging/repository/$repo_id"

        local state= profile_id= answer=
        read state profile_id <<< "$(ruby -r json -e 'j = JSON.parse(File.read(ARGV[0])); puts "#{j["type"]} #{j["profileId"]}"' $repo_state_json)"
        
        if ! [[ "$state" == "closed" ]]; then
          log "$profile_id is not closed but $state. I have no idea, so let me skip this."
          popd >/dev/null 2>&1
          continue
        fi

        log "Would you like to release $artifact_id/$version through $repo_id?"
        log "You can check the artifacts at $repo_content_url/$group_id_based_path/$artifact_id/$version"

        if ! ask "Release $artifact_id/$version..." "Skip $artifact_id/$version"; then
          popd >/dev/null 2>&1
          continue
        fi

        # release : promote from closed
        curl \
          -f# \
          -u "$nexus_username:$nexus_password" \
          -H 'Content-type: application/json' \
          -X POST \
          -d "{ \"data\": { \"stagedRepositoryId\": \"$repo_id\" } }" \
          -o "released.json" \
          "https://oss.sonatype.org/service/local/staging/profiles/${profile_id}/promote"

        # drop?
      fi

      popd >/dev/null 2>&1
    done
  done
}

main "$@"