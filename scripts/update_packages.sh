#!/bin/bash
set -Eeuo pipefail
shopt -s inherit_errexit

supported_architectures=(all amd64)

function main() {
  download_nta88_packages
  download_sublimetext
  download_gh_latest_release dive wagoodman/dive
  download_gh_latest_release mmdbinspect maxmind/mmdbinspect
  download_gh_latest_release sops mozilla/sops
  download_gh_latest_release xclicker robiot/xclicker
  download_gh_latest_release yaru818-theme nathan818fr/yaru818
}

function download_nta88_packages() {
  # TODO: Fetch all pages
  local releases_meta
  releases_meta="$(gh_curl -fsSL "https://api.github.com/repos/nta88/packaging/releases?per_page=100")"

  local selected_tags
  selected_tags="$(jq -Mr '.[] | select(.prerelease!=true) | .tag_name' <<<"$releases_meta" | sort_versions)"

  local selected_tag name version release_meta
  while IFS= read -r selected_tag; do
    name="${selected_tag%%_*}"
    version="${selected_tag##*_}"
    release_meta="$(jq --arg selected_tag "$selected_tag" '[.[] | select(.tag_name == $selected_tag)][0]' <<<"$releases_meta")"
    download_gh_release "$name" "$version" "$release_meta"
  done <<<"$selected_tags"
}

function download_sublimetext() {
  echo "Fetch sublime-text release url ..."
  local download_url
  download_url="$(curl -fsSL "https://www.sublimetext.com/download_thanks?target=x64-deb" |
    grep -F 'url = "https://download.sublimetext.com/sublime-text_' |
    grep -F '_amd64.deb' |
    cut -d'"' -f2)"

  local version
  version="$(cut -d_ -f2 <<<"$download_url")"
  check_valid_version "$version" || return 0

  download_deb 'sublime-text' "$version" 'amd64' "$download_url"
}

function download_gh_latest_release() {
  local name repo
  name="$1"
  repo="$2"

  echo "Fetch ${repo} release metadata ..."
  local release_meta
  release_meta="$(gh_curl -fsSL "https://api.github.com/repos/${repo}/releases/latest")"

  local version
  version="$(jq -Mr '.tag_name' <<<"$release_meta")"
  if [[ "$version" == v* ]]; then version="${version:1}"; fi
  check_valid_version "$version" || return 0

  download_gh_release "$name" "$version" "$release_meta"
}

function download_gh_release() {
  local name version release_meta
  name="$1"
  version="$2"
  release_meta="$3"

  local arch download_url
  for arch in "${supported_architectures[@]}"; do
    download_url="$(jq -Mr --arg arch "$arch" \
      '.assets[] | select(.name|endswith("_\($arch).deb")) | .browser_download_url' \
      <<<"$release_meta")"
    download_deb "$name" "$version" "$arch" "$download_url"
  done
}

function download_deb() {
  local name version arch download_url deb_file temp_file
  name="$1"
  version="$2"
  arch="$3"
  download_url="$4"

  if ! check_valid_version "$version"; then
    echo "Invalid version: ${version}" >&2
    return 1
  fi

  deb_file="./pool/stable/main/${name}_${version}_${arch}.deb"
  if [[ -e "$deb_file" ]]; then
    echo "$(basename "$deb_file") already exists"
    return 0
  fi

  if [[ "$download_url" == '' ]] || [[ "$download_url" == 'null' ]]; then
    echo "$(basename "$deb_file") has no candidate"
    return 0
  fi

  temp_file="$(mktemp)"
  curl -fL -o "$temp_file" -- "$download_url"
  cp_deb "$name" "$arch" "$temp_file" "$deb_file"
}

function cp_deb() {
  local name arch src_file dst_file
  name="$1"
  arch="$2"
  src_file="$3"
  dst_file="$4"

  find "$(dirname "$dst_file")" -name "${name}_*_${arch}.deb" -exec rm -vf {} \;
  mv -T -- "$src_file" "$dst_file"
  echo "$(basename "$dst_file") updated"
}

function check_valid_version() {
  local version="$1"
  if [[ "$version" =~ ^[a-z0-9\.\-]{1,32}$ ]]; then
    return 0
  fi

  echo "error: invalid version '${version}'" >&2
  return 1
}

function gh_curl() {
  curl -u "${GH_AUTH:-:}" "$@"
}

function sort_versions() {
  sed -E 's/([0-9]+|[^0-9]+)/\1\t/g' | LC_ALL=C sort -t $'\t' \
    -k 1,1rn -k 1,1r \
    -k 2,2rn -k 2,2r \
    -k 3,3rn -k 3,3r \
    -k 4,4rn -k 4,4r \
    -k 5,5rn -k 5,5r \
    -k 6,6rn -k 6,6r \
    -k 7,7rn -k 7,7r \
    -k 8,8rn -k 8,8r \
    -k 9,9rn -k 9,9r \
    -k 10,10rn -k 10,10r \
    -k 11,11rn -k 11,11r \
    -k 12,12rn -k 12,12r \
    -k 13,13rn -k 13,13r \
    -k 14,14rn -k 14,14r \
    -k 15,15rn -k 15,15r \
    -k 16,16rn -k 16,16r \
    -k 17,17rn -k 17,17r \
    -k 18,18rn -k 18,18r \
    -k 19,19rn -k 19,19r \
    -k 20,20rn -k 20,20r |
    tr -d '\t' |
    awk -F_ '{print $2" "$1}' |
    uniq -f1 |
    awk '{print $2"_"$1}'
}

main "$@"
exit 0
