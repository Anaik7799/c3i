#!/usr/bin/env bash
if [ $# -eq 0 ]; then
    ./sa-mesh help
else
    ./sa-mesh "$@"
fi
