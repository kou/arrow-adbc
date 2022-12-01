#!/usr/bin/env bash
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

set -e
set -u
set -o pipefail

main() {
    local -r source_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    local -r source_top_dir="$( cd "${source_dir}/../../" && pwd )"

    if [ "$#" -ne 2 ]; then
        echo "Usage: $0 <version> <rc-num>"
        exit 1
    fi

    local -r version="$1"
    local -r rc_number="$2"
    local -r tag="adbc-${version}"
    local -r rc_branch="release-${version}-rc${rc_number}"

    : ${REPOSITORY:="apache/arrow-adbc"}

    if [[ ! -f "${source_dir}/.env" ]]; then
        echo "You must create ${source_dir}/.env"
        echo "You can use ${source_dir}/.env.example as a template"
    fi

    source "${source_dir}/.env"

    echo "Creating release ${version}"

    local -r assets="${source_top_dir}/packages/${rc_branch}"
    local -r release_notes=$(cz ch --dry-run "${tag}" --unreleased-version "ADBC Libraries ${version}")

    header "Release Notes"
    echo "${release_notes}"

    gh release create \
       --repo "${REPOSITORY}" \
       "${tag}" \
       --notes "${release_notes}" \
       --prerelease \
       --title "ADBC Libraries ${version}"

    header "Uploading assets: docs"
    upload_assets "${tag}" "${assets}/docs/docs.tgz"

    header "Uploading assets: java"
    upload_assets "${tag}" $(find "${assets}/java" -name '*.jar' -o -name '*.pom')

    header "Uploading assets: python"
    # Must uniq because we build a none-any wheel across multiple platforms
    upload_assets "${tag}" $(find "${assets}" -name '*.whl' | sort | uniq)

    header "Uploading assets: source"
    upload_assets "${tag}" \
        "${source_top_dir}/adbc-${version}.tar.gz" \
        "${source_top_dir}/adbc-${version}.tar.gz.asc" \
        "${source_top_dir}/adbc-${version}.tar.gz.sha512"
}

header() {
    echo "============================================================"
    echo "${1}"
    echo "============================================================"
}

sign_asset() {
    local -r asset="$1"
    local -r sigfile="${asset}.asc"

    if [[ -f "${sigfile}" ]]; then
        if env LANG=C gpg --verify "${sigfile}" "${asset}" >/dev/null 2>&1; then
            echo "Valid signature at $(basename "${sigfile}"), skipping"
            return
        fi
        rm "${sigfile}"
    fi

    gpg \
        --armor \
        --detach-sign \
        --local-user "${GPG_KEY_ID}" \
        --output "${sigfile}" \
        "${asset}"
    echo "Generated $(basename "${sigfile}")"
}

sum_asset() {
    local -r asset="$1"
    local -r sumfile="${asset}.sha512"

    local -r digest=$(shasum --algorithm 512 "${asset}")
    if [[ -f "${sumfile}" ]]; then
        if [[ "${digest}" = $(cat "${sumfile}") ]]; then
            echo "Valid digest at $(basename "${sumfile}"), skipping"
            return
        fi
    fi

    echo "${digest}" > "${sumfile}"
    echo "Generated $(basename "${sumfile}")"
}

upload_assets() {
    local -r tag="${1}"
    shift 1

    for asset in "$@"; do
        sign_asset "${asset}"
        sum_asset "${asset}"
    done

    gh release upload \
       --repo "${REPOSITORY}" \
       "${tag}" \
       "$@"
}

main "$@"
