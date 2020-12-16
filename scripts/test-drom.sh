#!/bin/bash
set -euo pipefail

DIR=$(dirname $0)

$DIR/test-drom-skeletons.sh
$DIR/test-drom-projects.sh
