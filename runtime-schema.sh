#!/bin/bash

runtime_dir=$(dirname ${0})/ibek-runtime-support

module load uv
uvx ibek ioc generate-schema ${runtime_dir}/*/*.ibek.support.yaml --output ${runtime_dir}/ibek.runtime.schema.json
