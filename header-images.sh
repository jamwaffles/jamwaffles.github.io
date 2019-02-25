#!/bin/bash

set -e

for f in $(find ./assets/images/headers-original -type f); do
    echo $f
done
