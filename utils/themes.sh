# SPDX-License-Identifier: AGPL-3.0-or-later

themes.help() {
cat <<EOF
node.:
  env       : download & install SearXNG's npm dependencies locally
  env.dev   : download & install developer and CI tools
  clean     : drop locally npm installations
themes.:
  all       : build all themes
  simple    : build simple theme
pygments.:
  less      : build LESS files for pygments
EOF
}

nodejs.ensure() {
    if ! nvm.min_node "${NODE_MINIMUM_VERSION}"; then
        info_msg "install Node.js by NVM"
        nvm.nodejs
    fi
}

node.env() {
    nodejs.ensure
    (   set -e
        build_msg INSTALL "./searx/static/themes/simple/package.json"
        npm --prefix searx/static/themes/simple install
    )
    dump_return $?
}

node.env.dev() {
    nodejs.ensure
    build_msg INSTALL "./package.json: developer and CI tools"
    npm install
}

node.clean() {
    if ! required_commands npm 2>/dev/null; then
        build_msg CLEAN "npm is not installed / ignore npm dependencies"
        return 0
    fi
    build_msg CLEAN "themes -- locally installed npm dependencies"
    (   set -e
        npm --prefix searx/static/themes/simple run clean
    )
    build_msg CLEAN "locally installed developer and CI tools"
    (   set -e
        npm --prefix . run clean
    )
    dump_return $?
}

pygments.less() {
    build_msg PYGMENTS "searxng_extra/update/update_pygments.py"
    if ! pyenv.cmd python searxng_extra/update/update_pygments.py; then
        build_msg PYGMENTS "building LESS files for pygments failed"
        return 1
    fi
    return 0
}

themes.all() {
    (   set -e
        pygments.less
        node.env
        themes.simple
    )
    dump_return $?
}

themes.live() {
    local LIVE_THEME="${LIVE_THEME:-${1}}"
    case "${LIVE_THEME}" in
        simple)
            theme="searx/static/themes/${LIVE_THEME}"
            ;;
        '')
            die_caller 42 "missing theme argument"
            ;;
        *)
            die_caller 42 "unknown theme '${LIVE_THEME}' // [simple]'"
            ;;
    esac
    build_msg GRUNT "theme: $1 (live build)"
    nodejs.ensure
    cd "${theme}"
    {
        npm install
        npm run watch
    } 2>&1 \
        | prefix_stdout "${_Blue}THEME ${1} ${_creset}  " \
        | grep -E --ignore-case --color 'error[s]?[:]? |warning[s]?[:]? |'
}

themes.simple() {
    (   set -e
        build_msg GRUNT "theme: simple"
        npm --prefix searx/static/themes/simple run build
    )
    dump_return $?
}

themes.simple.test() {
    build_msg TEST "theme: simple"
    nodejs.ensure
    npm --prefix searx/static/themes/simple install
    npm --prefix searx/static/themes/simple run test
    dump_return $?
}
