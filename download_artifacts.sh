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

#
# Usage:
#  Download from jcenter:
#     ./this_script jcenter <group id> <artifact id> [version]
#
#  Download from a bintray repo:
#     ./this_script <bintray_user_name> <group id> <artifact id> [version]
# 
# Options:
#   Environment Variables:
#     WORKING_DIRECTORY : Specify a directory which this script uses. It will be a root directory contains artifacts. The default is the current directory.
#     MAVEN_NAMESPACE   : Specify a maven repository name. The default is "maven".
#

list_versions_from_maven_metadata() {
  ruby -r 'rexml/document' -e 'puts REXML::Document.new(File.new(ARGV[0])).get_elements("//*/version").map(&:text).uniq' "$1"
}

list_artifact_urls() {
  local -r html_path="$__TEMP_DIR__/$(mktemp -u html.XXXXXX)"
  curl -sSfL -o "$html_path" "$1/$2"
  ruby -r 'rexml/document' -e 'puts REXML::Document.new(File.new(ARGV[0])).get_elements("//*/a").map(&:text).reject { |s| s == "../" }.uniq' "$html_path"
}

download_all_artifacts_of_single_version() {
  local -r base_url="$1" artifact_id="$2" version="$3"
  local artifact_name= download_to= download_url=

  mkdir -p "$artifact_id/$version"

  while read artifact_name; do
    download_to="$artifact_id/$version/$artifact_name"
    download_url="$base_url/$version/$artifact_name"

    echo "Download $download_url to $download_to"
    if ! curl -fL# "$download_url" \
        -o "$download_to"; then
        echo "a trouble occured when downloading $download_url" 1>&2
        rm "$download_to" >/dev/null 2>&1 || true
        exit 1
    fi
  done < <(list_artifact_urls "$base_url" "$version")
}

main() {
  local -r bintray_username="$1" group_id="$2" artifact_id="$3" download_version="${4:-}"
  local -r group_id_based_path="${group_id//.//}"
  local base_url=

  if [[ "$bintray_username" == "jcenter" ]]; then
    base_url="https://jcenter.bintray.com/$group_id_based_path/$artifact_id"
  else
    base_url="https://dl.bintray.com/$bintray_username/${MAVEN_NAMESPACE:-maven}/$group_id_based_path/$artifact_id"
  fi

  local -r working_directory="${WORKING_DIRECTORY:-maven}"

  mkdir -p "$working_directory"
  pushd "$working_directory"

  mkdir -p "$group_id_based_path" && cd "$group_id_based_path"

  mkdir -p "$artifact_id"

  declare -a versions=()

  if [[ -z "$download_version" ]]; then
    # BE CAREFUL! This will download all artifacts which maven-metadata defines.

    local -r maven_metadata_path="$artifact_id/maven-metadata.xml"
    curl -sSfL -o "$maven_metadata_path" "$base_url/maven-metadata.xml"

    mapfile -d $'\0' versions < <(list_versions_from_maven_metadata "$maven_metadata_path" | tr '\n' '\0')
  else
    versions+=("$download_version")
  fi

  local version=

  for version in "${versions[@]}"; do
    download_all_artifacts_of_single_version "$base_url" "$artifact_id" "$version"
  done
}

main "$@"
