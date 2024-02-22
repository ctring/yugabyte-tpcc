#!/bin/bash
#
# A simple script for building one or more profiles (in parallel) inside the container.

# TODO: Convert this to a multi-stage build for better caching.

# Make sure any failure halts the rest of the operation.
set -eu -o pipefail

CLEAN_BUILD="${CLEAN_BUILD:-true}"    # true, false, pre, post

cd /benchbase
mkdir -p results
mkdir -p profiles

SKIP_TEST_ARGS='-D skipTests -D maven.test.skip -D maven.javadoc.skip=true'
EXTRA_MAVEN_ARGS="${EXTRA_MAVEN_ARGS:-}"

if [ "$CLEAN_BUILD" == false ]; then
    # In tight dev build loops we want to avoid regenerating classes when only
    # the git properties have changed.
    EXTRA_MAVEN_ARGS+=" -D maven.gitcommitid.skip=true"
fi

# Make sure that we've built the base stuff (and test) before we build individual profiles.
mvn -T 2C -B --file pom.xml $SKIP_TEST_ARGS $EXTRA_MAVEN_ARGS compile # ${TEST_TARGET:-}


mkdir -p target
# Build the profile without tests (we did that separately).
mvn -T 2C -B --file pom.xml package -D descriptors=src/main/assembly/dir.xml \
    $SKIP_TEST_ARGS $EXTRA_MAVEN_ARGS -D buildDirectory=target/
