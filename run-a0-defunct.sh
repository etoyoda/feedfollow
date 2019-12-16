#!/bin/bash
set -Ceuo pipefail

: ${RUBY:='/usr/bin/ruby'}

$RUBY /nwp/bin/defunct-delete.rb
