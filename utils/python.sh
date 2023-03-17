# SPDX-License-Identifier: AGPL-3.0-or-later

python.help() {
    cat <<EOF
py.:
  build     : Build python packages at ./${PYDIST}
  clean     : delete virtualenv and intermediate py files
pyenv.:
  install   : developer install of SearXNG into virtualenv
  uninstall : uninstall developer installation
  cmd ...   : run command ... in virtualenv
  OK        : test if virtualenv is OK
pypi.upload:
  Upload python packages to PyPi (to test use pypi.upload.test)
EOF
}

pyenv.cmd() {
    pyenv.install
    (   set -e
        # shellcheck source=/dev/null
        source "${PY_ENV_BIN}/activate"
        [ "$VERBOSE" = "1" ] && set -x
        "$@"
    )
}

pyenv.activate() {
    pyenv.install
    # shellcheck source=/dev/null
    source "${PY_ENV_BIN}/activate"
}

pyenv.drop() {

    build_msg PYENV "[virtualenv] drop ${PY_ENV}"
    rm -rf "${PY_ENV}"

}

_pyenv_install_OK=''
pyenv.install.OK() {
    # probes if virtualenv exists and is valid
    [ "$_pyenv_install_OK" == "OK" ] && return 0

    if [ ! -f "${PY_ENV_BIN}/python" ]; then
        build_msg PYENV "[virtualenv] missing ${PY_ENV_BIN}/python"
        return 1
    fi

    if [ ! -f "${PY_ENV_DEPENDENCIES_SHA}" ]; then
        build_msg PYENV "[virtualenv] ${PY_ENV_DEPENDENCIES_SHA} is missing"
        return 1
    fi

    if ! sha256sum -c "${PY_ENV_DEPENDENCIES_SHA}" > /dev/null 2>&1; then
        build_msg PYENV "[virtualenv] dependencies have changed"
        sed 's/^/          [virtualenv] - /' <"${PY_ENV_DEPENDENCIES_SHA}"
        return 1
    fi

    (
        [ "$VERBOSE" = "1" ] && set -x
        "${PY_ENV_BIN}/python" -c "import searx"
    )

    err=$?
    if [ "$err" -ne "0" ]; then
        build_msg PYENV "[install] python installation test failed"
        return "$err"
    fi

    build_msg PYENV "[install] OK"
    _pyenv_install_OK="OK"
    return 0
}

pyenv.install() {
    if pyenv.install.OK > /dev/null; then
        return 0
    fi

    required_commands sha256sum "${PYTHON}" || exit

    rm -f "${PY_ENV_DEPENDENCIES_SHA}"
    pyenv.drop > /dev/null

    (   set -e
        [ "$VERBOSE" = "1" ] && set -x

        build_msg PYENV "[virtualenv] create virtualenv in ${PY_ENV}"
        "${PYTHON}" -m venv "${PY_ENV}"

        # 
        sha256sum ${PY_ENV_DEPENDENCIES} > "${PY_ENV_DEPENDENCIES_SHA}"

        # shellcheck disable=SC2086
        build_msg PYENV "[install] pip install requirements.txt"
        "${PY_ENV_BIN}/python" -m pip install ${PY_ENV_PIP_INSTALL}

    )
    local exit_val=$?
    if [ ! $exit_val -eq 0 ]; then
        die 42 "error while pip install ${PY_ENV_BIN}"
    fi
}

pyenv.uninstall() {

    build_msg PYENV "[pyenv.uninstall] uninstall packages: ${PYOBJECTS}"
    pyenv.cmd python setup.py develop --uninstall 2>&1 \
        | prefix_stdout "${_Blue}PYENV     ${_creset}[pyenv.uninstall] "

}

py.clean() {

    build_msg CLEAN pyenv
    (   set -e
        pyenv.drop
        [ "$VERBOSE" = "1" ] && set -x
        rm -rf "${PYDIST}" "${PYBUILD}" "${PY_ENV}" ./.tox ./*.egg-info
        find . -name '*.pyc' -exec rm -f {} +
        find . -name '*.pyo' -exec rm -f {} +
        find . -name __pycache__ -exec rm -rf {} +
    )

}

py.build() {

    build_msg BUILD "python package ${PYDIST}"
    pyenv.cmd python setup.py \
              sdist -d "${PYDIST}" \
              bdist_wheel --bdist-dir "${PYBUILD}" -d "${PYDIST}"
}

pypi.upload() {

    py.clean
    py.build
    # https://github.com/pypa/twine
    pyenv.cmd twine upload "${PYDIST}"/*
}

pypi.upload.test() {

    py.clean
    py.build
    pyenv.cmd twine upload -r testpypi "${PYDIST}"/*
}
