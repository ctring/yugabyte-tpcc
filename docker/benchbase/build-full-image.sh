#!/bin/bash

set -eu

scriptdir=$(dirname "$(readlink -f "$0")")
rootdir=$(readlink -f "$scriptdir/../../")

cd "$scriptdir"
. ./common-env.sh


if [ "$CLEAN_BUILD" == 'true' ]; then
    grep '^FROM ' fullimage/Dockerfile \
        | sed -r -e 's/^FROM\s+//' -e 's/--platform=\S+\s+//' -e 's/\s+AS \S+\s*$/ /' \
        | while read base_image; do
            set -x
            docker pull $base_image &
            set +x
        done
        wait
fi


logs_child_pid=
container_id=
function trap_ctrlc() {
    docker stop -t 1 $container_id >/dev/null || true
    if [ -n "$logs_child_pid" ]; then
        kill $logs_child_pid 2>/dev/null || true
    fi
    exit 1
}

# Build the requested profiles using the dev image.
./build-dev-image.sh
# Use non-interactive mode so that the build doesn't prompt us to accept git ssh keys.
# But setup some Ctrl-C handlers as well.
container_id=$(INTERACTIVE='false' ./run-dev-image.sh /benchbase/docker/benchbase/devcontainer/build-in-container.sh)
trap trap_ctrlc SIGINT SIGTERM
echo "INFO: build-devcontainer-id: $container_id"
docker logs -f $container_id &
logs_child_pid=$!
rc=$(docker wait $container_id)
trap - SIGINT SIGTERM
if [ "$rc" != 0 ]; then
    echo "ERROR: Build in devcontainer failed." >&2
    exit $rc
fi



# Prepare the build context.

# Make (hard-linked) copies of the build results that we can put into the image.
pushd "$scriptdir/fullimage/"
rm -rf tmp/
mkdir -p tmp/config/
cp -a "$rootdir/config/workload_all.xml" tmp/config/
cp -a "$rootdir/config/geopartitioned_workload.xml" tmp/config/

# Make a copy of the entrypoint script that changes the default profile to
# execute for singleton images.
cp -a $rootdir/tpccbenchmark tmp/tpccbenchmark
cp -a $rootdir/classpath.sh tmp/classpath.sh
cp -a $rootdir/log4j.properties tmp/log4j.properties
cp -al "$rootdir/target" tmp/lib

# Adjust the image tags.
target_image_tag_args="-t benchbase:yugabyte"

set -x
docker build $docker_build_args \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --build-arg="http_proxy=${http_proxy:-}" --build-arg="https_proxy=${https_proxy:-}" --build-arg="no_proxy=${no_proxy:-}" \
    --build-arg CONTAINERUSER_UID="$CONTAINERUSER_UID" --build-arg CONTAINERUSER_GID="$CONTAINERUSER_GID" \
    $target_image_tag_args -f "$scriptdir/fullimage/Dockerfile" "$scriptdir/fullimage/tmp/"
set +x

# Cleanup the temporary copies.
rm -rf "$scriptdir/fullimage/tmp/"
popd

