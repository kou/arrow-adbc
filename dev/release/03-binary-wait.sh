#!/usr/bin/env bash
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

set -ex

main() {
    local -r source_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

    if [ "$#" -ne 2 ]; then
        echo "Usage: $0 <version> <rc-num>"
        exit 1
    fi

    local -r version="$1"
    local -r rc_number="$2"
    local -r tag="adbc-${version}-rc${rc_number}"

    : ${REPOSITORY:="apache/arrow-adbc"}

    echo "Looking for GitHub Actions workflow on ${REPOSITORY}:${tag}"

    local run_id=""
    while [[ -z "${run_id}" ]]
    do
        echo "Waiting for run to start..."
        run_id=$(gh run list \
                    --repo "${REPOSITORY}" \
                    --workflow=packaging-wheels.yml \
                    --json 'databaseId,event,headBranch,status' \
                    --jq ".[] | select(.event == \"push\" and .headBranch == \"${tag}\") | .databaseId")
        sleep 1
    done

    echo "Found GitHub Actions workflow with ID: ${run_id}"

    gh run watch --repo ${REPOSITORY} ${run_id}
}

main "$@"
