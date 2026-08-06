#!/usr/bin/env bash
# Host-side wrapper: delegates the poco build into a FreeBSD jail (fbsd14 /
# fbsd15) on the freebsd-jail agent. Invoked by jenkins.sh when FREEBSD_JAIL is
# set; re-runs jenkins.sh inside the jail with IN_FREEBSD_JAIL=1 so it skips the
# host-only setup and falls through to the real build.
#
# Modelled on SharedSuite's build/jenkins_freebsd_jail_build.sh but kept
# repo-local, because that script only rsyncs test-reports back out. poco zips
# and uploads cmake_install_{Debug,Release} from the *host* (see the s3Upload in
# Jenkinsfile-Native), so those trees have to come back or the upload has
# nothing to publish.
#
# .git is excluded from the copy for speed - its objects/pack are several
# hundred MB and nothing in poco's build reads it. `shared` is already populated
# on the host by jenkins.sh, so it rides along in the rsync.

set -Eeuo pipefail

: "${FREEBSD_JAIL:?Need to set FREEBSD_JAIL (e.g. fbsd14, fbsd15)}"

# Jenkins gives each stage its own workspace dir (see the ws() call in
# Jenkinsfile-Native), so reusing that name keeps concurrent builds targeting
# the same jail from clobbering each other.
JAIL_WORKSPACE="$(basename "$PWD")"
JAIL_ROOT="/jails/${FREEBSD_JAIL}/workspace/${JAIL_WORKSPACE}"
JAIL_WORKSPACE_PATH="/workspace/${JAIL_WORKSPACE}"

echo "=== FreeBSD jail info ==="
echo "Jail: ${FREEBSD_JAIL}"
echo "Jail workspace: ${JAIL_ROOT}"
sudo jls -j "$FREEBSD_JAIL" || echo "jls failed for jail ${FREEBSD_JAIL}"
sudo jexec "$FREEBSD_JAIL" uname -a || echo "uname inside jail ${FREEBSD_JAIL} failed"
echo "=========================="

sudo mkdir -p "/jails/${FREEBSD_JAIL}/workspace"
sudo rsync -a --delete --exclude=.git "$PWD/" "${JAIL_ROOT}/"
sudo chown -R root:wheel "${JAIL_ROOT}"

# Rather than whitelist every var jenkins.sh and ccache.sh read (PLATFORM,
# TOOLCHAIN_NAME, OPENSSL_VERSION, CCACHE_FILE, the AWS_* credentials
# withAwsCredentials injects, ...), forward everything except host-specific
# values that would be wrong or harmful inside the jail:
#   FREEBSD_JAIL      - absent in the jail so the delegated jenkins.sh runs the
#                       build instead of re-delegating
#   PATH/HOME/SHELL/  - host filesystem and identity that don't exist in the jail
#   USER/LOGNAME/...
#   JENKINS_*_COOKIE/ - agent session bookkeeping
#   HUDSON_*_COOKIE
#   SSH_CLIENT/       - the inbound connection the agent was launched over
#   SSH_CONNECTION
# WORKSPACE/WORKSPACE_TMP are forwarded but rewritten below, since the jail
# mirrors the workspace under /workspace/<name>.
DENYLIST_RE='^(FREEBSD_JAIL|PATH|HOME|PWD|WORKSPACE|WORKSPACE_TMP|USER|LOGNAME|SHELL|TERM|JAVA_HOME|MAIL|BLOCKSIZE|TMPDIR|JENKINS_SERVER_COOKIE|JENKINS_NODE_COOKIE|HUDSON_SERVER_COOKIE|HUDSON_COOKIE|SSH_CLIENT|SSH_CONNECTION)$'
JAIL_ENV=()
while IFS= read -r name; do
    [[ $name =~ $DENYLIST_RE ]] && continue
    JAIL_ENV+=("${name}=${!name}")
done < <(compgen -e)

JAIL_ENV+=("WORKSPACE=${JAIL_WORKSPACE_PATH}" "WORKSPACE_TMP=${JAIL_WORKSPACE_PATH}@tmp")
JAIL_ENV+=("IN_FREEBSD_JAIL=1")

STATUS=0
sudo jexec "$FREEBSD_JAIL" env "${JAIL_ENV[@]}" \
    sh -c "cd ${JAIL_WORKSPACE_PATH} && ./jenkins.sh" || STATUS=$?

# Bring the install trees back so the Jenkinsfile can zip and upload them.
for build_type in Debug Release; do
    sudo rsync -a --delete \
        "${JAIL_ROOT}/cmake_install_${build_type}/" "cmake_install_${build_type}/" \
        2>/dev/null || true
    sudo chown -R "$(id -u):$(id -g)" "cmake_install_${build_type}" 2>/dev/null || true
done

exit $STATUS
