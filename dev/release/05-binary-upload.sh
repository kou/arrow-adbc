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

export LANG=C
export LC_CTYPE=C

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <version> <rc-num>"
  exit
fi

version=$1
rc_number=$2

version_with_rc="${version}-rc${rc_number}"
package_dir="${SOURCE_DIR}/../../packages"

artifact_dir="${package_dir}/release-${version_with_rc}"

if [ ! -e "$artifact_dir" ]; then
  echo "$artifact_dir does not exist"
  exit 1
fi

if [ ! -d "$artifact_dir" ]; then
  echo "$artifact_dir is not a directory"
  exit 1
fi

cd "${SOURCE_DIR}"

if [ ! -f .env ]; then
  echo "You must create $(pwd)/.env"
  echo "You can use $(pwd)/.env.example as template"
  exit 1
fi
. .env

. utils-binary.sh

# By default upload all artifacts.
# To deactivate one category, deactivate the category and all of its dependents.
# To explicitly select one category, set UPLOAD_DEFAULT=0 UPLOAD_X=1.
: ${UPLOAD_DEFAULT:=1}
: ${UPLOAD_DOCS:=${UPLOAD_DEFAULT}}
: ${UPLOAD_PYTHON:=${UPLOAD_DEFAULT}}

rake_tasks=()
if [ ${UPLOAD_DOCS} -gt 0 ]; then
  rake_tasks+=(docs:rc)
fi
if [ ${UPLOAD_PYTHON} -gt 0 ]; then
  rake_tasks+=(python:rc)
fi
rake_tasks+=(summary:rc)

tmp_dir=binary/tmp
mkdir -p "${tmp_dir}"
source_artifacts_dir="${tmp_dir}/artifacts"
rm -rf "${source_artifacts_dir}"
cp -a "${artifact_dir}" "${source_artifacts_dir}"

docker_run \
  ./runner.sh \
  rake \
    "${rake_tasks[@]}" \
    ARTIFACTORY_API_KEY="${ARTIFACTORY_API_KEY}" \
    ARTIFACTS_DIR="${tmp_dir}/artifacts" \
    DRY_RUN=${DRY_RUN:-no} \
    GPG_KEY_ID="${GPG_KEY_ID}" \
    RC=${rc_number} \
    STAGING=${STAGING:-no} \
    VERSION=${version}
