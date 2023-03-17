# SPDX-License-Identifier: AGPL-3.0-or-later

docs.help() {
cat <<EOF
docs.:
  html      : build HTML documentation
  live      : autobuild HTML documentation while editing
  gh-pages  : deploy on gh-pages branch
  prebuild  : build reST include files (./${DOCS_BUILD}/includes)
  clean     : clean documentation build
EOF
}

docs.html() {
    build_msg SPHINX "HTML ./docs --> file://$(readlink -e "$(pwd)/$DOCS_DIST")"
    pyenv.install
    docs.prebuild
    # shellcheck disable=SC2086
    PATH="${PY_ENV_BIN}:${PATH}" pyenv.cmd sphinx-build \
        ${SPHINX_VERBOSE} ${SPHINXOPTS} \
	-b html -c ./docs -d "${DOCS_BUILD}/.doctrees" ./docs "${DOCS_DIST}"
    dump_return $?
}

docs.live() {
    build_msg SPHINX  "autobuild ./docs --> file://$(readlink -e "$(pwd)/$DOCS_DIST")"
    pyenv.install
    docs.prebuild
    # shellcheck disable=SC2086
    PATH="${PY_ENV_BIN}:${PATH}" pyenv.cmd sphinx-autobuild \
        ${SPHINX_VERBOSE} ${SPHINXOPTS} --open-browser --host 0.0.0.0 \
	-b html -c ./docs -d "${DOCS_BUILD}/.doctrees" ./docs "${DOCS_DIST}"
    dump_return $?
}

docs.clean() {
    build_msg CLEAN "docs -- ${DOCS_BUILD} ${DOCS_DIST}"
    # shellcheck disable=SC2115
    rm -rf "${GH_PAGES}" "${DOCS_BUILD}" "${DOCS_DIST}"
    dump_return $?
}

docs.prebuild() {
    build_msg DOCS "build ${DOCS_BUILD}/includes"
    (
        set -e
        [ "$VERBOSE" = "1" ] && set -x
        mkdir -p "${DOCS_BUILD}/includes"
        ./utils/searxng.sh searxng.doc.rst >  "${DOCS_BUILD}/includes/searxng.rst"
        pyenv.cmd searxng_extra/docs_prebuild
    )
    dump_return $?
}

# shellcheck disable=SC2155
docs.gh-pages() {

    # The commit history in the gh-pages branch makes no sense, the history only
    # inflates the repository unnecessarily.  Therefore a *new orphan* branch
    # is created each time we deploy on the gh-pages branch.

    docs.clean
    docs.prebuild
    docs.html

    [ "$VERBOSE" = "1" ] && set -x
    local head="$(git rev-parse HEAD)"
    local branch="$(git name-rev --name-only HEAD)"
    local remote="$(git config branch."${branch}".remote)"
    local remote_url="$(git config remote."${remote}".url)"

    build_msg GH-PAGES "prepare folder: ${GH_PAGES}"
    build_msg GH-PAGES "remote of the gh-pages branch: ${remote} / ${remote_url}"
    build_msg GH-PAGES "current branch: ${branch}"

    # prepare the *orphan* gh-pages working tree
    (
        git worktree remove -f "${GH_PAGES}"
        git branch -D gh-pages
    ) &> /dev/null  || true
    git worktree add --no-checkout "${GH_PAGES}" "${remote}/master"

    pushd "${GH_PAGES}" &> /dev/null
    git checkout --orphan gh-pages
    git rm -rfq .
    popd &> /dev/null

    cp -r "${DOCS_DIST}"/* "${GH_PAGES}"/
    touch "${GH_PAGES}/.nojekyll"
    cat > "${GH_PAGES}/404.html" <<EOF
<html><head><META http-equiv='refresh' content='0;URL=index.html'></head></html>
EOF

    pushd "${GH_PAGES}" &> /dev/null
    git add --all .
    git commit -q -m "gh-pages build from: ${branch}@${head} (${remote_url})"
    git push -f "${remote}" gh-pages
    popd &> /dev/null

    set +x
    build_msg GH-PAGES "deployed"
}
