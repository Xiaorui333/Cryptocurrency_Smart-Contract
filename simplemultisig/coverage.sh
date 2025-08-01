#!/bin/bash

set -Eeuxoa pipefail


rm -rf lcov.info coverage
forge coverage --report lcov --ir-minimum
genhtml --ignore-errors inconsistent lcov.info --branch-coverage --output-dir coverage
open coverage/index.html