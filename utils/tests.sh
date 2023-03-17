# SPDX-License-Identifier: AGPL-3.0-or-later

tests.help() {
cat <<EOF
format.:
  python    : format Python code source using black
test.:
  yamllint  : lint YAML files (YAMLLINT_FILES)
  pylint    : lint PYLINT_FILES, searx/engines, searx & tests
  pyright   : static type check of python sources
  black     : check black code format
  unit      : run unit tests
  coverage  : run unit tests with coverage
  robot     : run robot test
  rst       : test .rst files incl. README.rst
  clean     : clean intermediate test stuff
gecko.driver:
  download & install geckodriver if not already installed (required for robot_tests)
EOF
}

pylint.FILES() {

    # List files tagged by comment:
    #
    #   # lint: pylint
    #
    # These py files are linted by test.pylint()

    grep -l -r --include \*.py '^#[[:blank:]]*lint:[[:blank:]]*pylint' searx searxng_extra tests
    find . -name searxng.msg
}

PYLINT_FILES=()
while IFS= read -r line; do
   PYLINT_FILES+=("$line")
done <<< "$(pylint.FILES)"

# shellcheck disable=SC2119
gecko.driver() {
    pyenv.install

    build_msg INSTALL "gecko.driver"
    # run installation in a subprocess and activate pyenv
    (   set -e
        pyenv.activate

        INSTALLED_VERSION=$(geckodriver -V 2> /dev/null | head -1 | awk '{ print "v" $2}') || INSTALLED_VERSION=""
        set +e
        if [ "${INSTALLED_VERSION}" = "${GECKODRIVER_VERSION}" ]; then
            build_msg INSTALL "geckodriver already installed"
            return
        fi
        PLATFORM="$(python3 -c 'import platform; print(platform.system().lower(), platform.architecture()[0])')"
        case "$PLATFORM" in
            "linux 32bit" | "linux2 32bit") ARCH="linux32";;
            "linux 64bit" | "linux2 64bit") ARCH="linux64";;
            "windows 32 bit") ARCH="win32";;
            "windows 64 bit") ARCH="win64";;
            "mac 64bit") ARCH="macos";;
        esac
        GECKODRIVER_URL="https://github.com/mozilla/geckodriver/releases/download/$GECKODRIVER_VERSION/geckodriver-$GECKODRIVER_VERSION-$ARCH.tar.gz";

        build_msg GECKO "Installing ${PY_ENV_BIN}/geckodriver from $GECKODRIVER_URL"

        FILE="$(mktemp)"
        wget -qO "$FILE" -- "$GECKODRIVER_URL" && tar xz -C "${PY_ENV_BIN}" -f "$FILE" geckodriver
        rm -- "$FILE"
        chmod 755 -- "${PY_ENV_BIN}/geckodriver"
    )
    dump_return $?
}

test.yamllint() {
    build_msg TEST "[yamllint] \$YAMLLINT_FILES"
    pyenv.cmd yamllint --strict --format parsable "${YAMLLINT_FILES[@]}"
    dump_return $?
}

test.pylint() {
    # shellcheck disable=SC2086
    (   set -e
        build_msg TEST "[pylint] \$PYLINT_FILES"
        pyenv.activate
        python ${PYLINT_OPTIONS} ${PYLINT_VERBOSE} \
            --additional-builtins="${PYLINT_ADDITIONAL_BUILTINS_FOR_ENGINES}" \
            "${PYLINT_FILES[@]}"

        build_msg TEST "[pylint] searx/engines"
        python ${PYLINT_OPTIONS} ${PYLINT_VERBOSE} \
            --disable="${PYLINT_SEARXNG_DISABLE_OPTION}" \
            --additional-builtins="${PYLINT_ADDITIONAL_BUILTINS_FOR_ENGINES}" \
            searx/engines

        build_msg TEST "[pylint] searx tests"
        python ${PYLINT_OPTIONS} ${PYLINT_VERBOSE} \
            --disable="${PYLINT_SEARXNG_DISABLE_OPTION}" \
	    --ignore=searx/engines \
	    searx tests
    )
    dump_return $?
}

test.pyright() {
    build_msg TEST "[pyright] static type check of python sources"
    node.env.dev
    # We run Pyright in the virtual environment because Pyright
    # executes "python" to determine the Python version.
    build_msg TEST "[pyright] suppress warnings related to intentional monkey patching"
    pyenv.cmd npx --no-install pyright -p pyrightconfig-ci.json \
        | grep -v ".py$" \
        | grep -v '/engines/.*.py.* - warning: "logger" is not defined'\
        | grep -v '/plugins/.*.py.* - error: "logger" is not defined'\
        | grep -v '/engines/.*.py.* - warning: "supported_languages" is not defined' \
        | grep -v '/engines/.*.py.* - warning: "language_aliases" is not defined' \
        | grep -v '/engines/.*.py.* - warning: "categories" is not defined'
    dump_return $?
}

format.python() {
    build_msg TEST "[format.python] black \$BLACK_TARGETS"
    pyenv.cmd black "${BLACK_OPTIONS[@]}" "${BLACK_TARGETS[@]}"
    dump_return $?
}

test.black() {
    build_msg TEST "[black] \$BLACK_TARGETS"
    pyenv.cmd black --check --diff "${BLACK_OPTIONS[@]}" "${BLACK_TARGETS[@]}"
    dump_return $?
}

test.unit() {
    build_msg TEST 'tests/unit'
    pyenv.cmd python -m nose2 -s tests/unit
    dump_return $?
}

test.coverage() {
    build_msg TEST 'unit test coverage'
    (   set -e
        pyenv.activate
        python -m nose2 -C --log-capture --with-coverage --coverage searx -s tests/unit
        coverage report
        coverage html
    )
    dump_return $?
}

test.robot() {
    build_msg TEST 'robot'
    gecko.driver
    PYTHONPATH=. pyenv.cmd python -m tests.robot
    dump_return $?
}

test.rst() {
    build_msg TEST "[reST markup] ${RST_FILES[*]}"
    for rst in "${RST_FILES[@]}"; do
        pyenv.cmd rst2html.py --halt error "$rst" > /dev/null || die 42 "fix issue in $rst"
    done
}

test.pybabel() {
    TEST_BABEL_FOLDER="build/test/pybabel"
    build_msg TEST "[extract messages] pybabel"
    mkdir -p "${TEST_BABEL_FOLDER}"
    pyenv.cmd pybabel extract -F babel.cfg -o "${TEST_BABEL_FOLDER}/messages.pot" searx
}

test.clean() {
    build_msg CLEAN  "test stuff"
    rm -rf geckodriver.log .coverage coverage/
    dump_return $?
}
