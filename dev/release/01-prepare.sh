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
#
set -ue

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <version> <next_version> <rc-num>"
  exit 1
fi

. $SOURCE_DIR/utils-prepare.sh

version=$1
next_version=$2
next_version_snapshot="${next_version}-SNAPSHOT"
rc_number=$3

release_tag="adbc-${version}"
release_branch="release-${version}"
release_candidate_branch="release-${version}-rc${rc_number}"

if [ $(git tag -l "${release_tag}") ]; then
    echo "Delete existing git tag $release_tag"
    git tag -d "${release_tag}"
fi

if [[ $(git branch -l "${release_candidate_branch}") ]]; then
    next_rc_number=$(($rc_number+1))
    echo "Branch ${release_candidate_branch} already exists, so create a new release candidate:"
    echo "1. Checkout the default branch for major releases and maint-<version> for patch releases."
    echo "2. Execute the script again with bumped RC number."
    echo "Commands:"
    echo "   git checkout main"
    echo "   dev/release/01-prepare.sh ${version} ${next_version} ${next_rc_number}"
    exit 1
fi

############################## Pre-Tag Commits ##############################

echo "Updating changelog for $version"
# Update changelog
cz ch --incremental --unreleased-version "${release_tag}"
git add ${SOURCE_DIR}/../../CHANGELOG.md
git commit -m "chore: update CHANGELOG.md for $version"

echo "Prepare release ${version} on tag ${release_tag}"

update_versions "${version}" "${next_version}" "release"
git commit -m "chore: update versions for ${version}"

############################## Tag the Release ##############################

git tag -a "${release_tag}" -m "ADBC Libraries ${version}"

############################# Create the Branch #############################

echo "Create local branch ${release_candidate_branch} for release candidate ${rc_number}"
git branch ${release_candidate_branch}

########################## Update Snapshot Version ##########################

update_versions "${version}" "${next_version}" "snapshot"
git commit -m "chore: update versions for ${next_version_snapshot}"
