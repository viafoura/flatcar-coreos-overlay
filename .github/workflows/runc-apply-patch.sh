#!/bin/bash

set -euo pipefail

. .github/workflows/common.sh

checkout_branches "runc-${VERSION_NEW}"

pushd "${SDK_OUTER_SRCDIR}/third_party/coreos-overlay" >/dev/null || exit

# Get the original runc version, including official releases and rc versions.
# We need some sed tweaks like adding underscore, sort, and trim the underscore again,
# so that sort -V can give the newest version including non-rc versions.
VERSION_OLD=$(sed -n "s/^DIST docker-runc-\([0-9]*.[0-9]*.*\)\.tar.*/\1/p" app-emulation/docker-runc/Manifest | sed '/-/!{s/$/_/}' | sort -ruV | sed 's/_$//' | head -n1 | tr '-' '_')
[[ "${VERSION_NEW}" = "${VERSION_OLD}" ]] && echo "already the latest Runc, nothing to do" && exit

runcEbuildOld=$(ls -1 app-emulation/docker-runc/docker-runc-${VERSION_OLD}*.ebuild | sort -ruV | head -n1)
runcEbuildNew="app-emulation/docker-runc/docker-runc-${VERSION_NEW}.ebuild"
git mv ${runcEbuildOld} ${runcEbuildNew}
sed -i "s/${VERSION_OLD}/${VERSION_NEW}/g" ${runcEbuildNew}

# update also runc versions used by docker and containerd
sed -i "s/docker-runc-${VERSION_OLD}/docker-runc-${VERSION_NEW}/g" app-emulation/docker/docker-9999.ebuild
sed -i "s/docker-runc-${VERSION_OLD}/docker-runc-${VERSION_NEW}/g" app-emulation/containerd/containerd-9999.ebuild

dockerVersion=$(sed -n "s/^DIST docker-\([0-9]*.[0-9]*.[0-9]*\).*/\1/p" app-emulation/docker/Manifest | sort -ruV | head -n1)

# torcx ebuild file has a docker version with only major and minor versions, like 19.03.
versionTorcx=${dockerVersion%.*}
torcxEbuildFile=$(ls -1 app-torcx/docker/docker-${versionTorcx}*.ebuild | sort -ruV | head -n1)
sed -i "s/docker-runc-${VERSION_OLD}/docker-runc-${VERSION_NEW}/g" ${torcxEbuildFile}

popd >/dev/null || exit

generate_patches app-emulation docker-runc Runc

apply_patches

echo ::set-output name=VERSION_OLD::"${VERSION_OLD}"
