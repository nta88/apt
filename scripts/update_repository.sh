#!/bin/bash
set -Eeuo pipefail
shopt -s inherit_errexit

function main() {
  local distributions components architectures
  distributions=(stable)
  components=(main)
  architectures=(all amd64)

  local pool_dir dist_dir release_file
  for distribution in "${distributions[@]}"; do
    for component in "${components[@]}"; do
      pool_dir="./pool/${distribution}/${component}"

      for architecture in "${architectures[@]}"; do
        # Generate Packages indices
        dist_dir="./dists/${distribution}/${component}/binary-${architecture}"
        if [[ ! -d "$pool_dir" ]]; then
          rm -rf -- "$dist_dir"
        else
          mkdir -p -- "$dist_dir"
          dpkg-scanpackages --arch "$architecture" "./pool/${distribution}/${component}" >"${dist_dir}/Packages"
        fi

        # Generate Contents files
        apt-ftparchive -a "$architecture" contents "./pool/${distribution}/${component}" >"./dists/${distribution}/${component}/Contents-${architecture}"
      done

      # Compress indices
      find "./dists/${distribution}" \! -name '*.gz' -a \( -name 'Packages' -o -name 'Contents-*' \) -exec gzip -f -k6 {} \;

      # Generate Release file
      release_file="./dists/${distribution}/Release"
      apt-ftparchive \
        -o "APT::FTPArchive::Release::Codename=${distribution}" \
        -o "APT::FTPArchive::Release::Architectures=${architectures[*]}" \
        release "./dists/${distribution}" >"$release_file"

      # Sign Release file + Generate InRelease
      gpg -sba --default-key 'nta88 apt repository' <"$release_file" >"${release_file}.gpg"
      gpg -sba --default-key 'nta88 apt repository' --clearsign <"$release_file" >"./dists/${distribution}/InRelease"
    done
  done
}

main "$@"
exit "$?"
