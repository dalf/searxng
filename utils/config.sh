# global
# ------

PATH="${REPO_ROOT}/node_modules/.bin:${PATH}"

if [[ -z "${REPO_ROOT}" ]]; then
    REPO_ROOT=$(dirname "${BASH_SOURCE[0]}")
    while [ -h "${REPO_ROOT}" ] ; do
        REPO_ROOT=$(readlink "${REPO_ROOT}")
    done
    REPO_ROOT=$(cd "${REPO_ROOT}/.." && pwd -P )
fi

if [[ -z "$CACHE" ]]; then
    CACHE="${REPO_ROOT}/cache"
fi

if [ "$VERBOSE" = "1" ]; then
    SPHINX_VERBOSE="-v"
    PYLINT_VERBOSE="-v"
fi


# Redis
# -----

_dev_redis_sock="/usr/local/searxng-redis/run/redis.sock"
# set SEARXNG_REDIS_URL if it is not defined and "{_dev_redis_sock}" exists.
if [ -S "${_dev_redis_sock}" ] && [ -z "${SEARXNG_REDIS_URL}" ]; then
    export SEARXNG_REDIS_URL="unix://${_dev_redis_sock}?db=0"
fi


# Sphinx documentation
# --------------------

# SPHINXOPTS=
GH_PAGES="build/gh-pages"
DOCS_DIST="${DOCS_DIST:=dist/docs}"
DOCS_BUILD="${DOCS_BUILD:=build/docs}"

# needed by sphinx-docs
export DOCS_BUILD


# nvm
# ---

NVM_LOCAL_FOLDER=.nvm

[[ -z "${NVM_GIT_URL}" ]] &&  NVM_GIT_URL="https://github.com/nvm-sh/nvm.git"
[[ -z "${NVM_MIN_NODE_VER}" ]] && NVM_MIN_NODE_VER="16.13.0"


# themes
# ------

export NODE_MINIMUM_VERSION="16.13.0"


# static
# ------

STATIC_BUILD_COMMIT="[build] /static"
STATIC_BUILT_PATHS=(
    'searx/static/themes/simple/css'
    'searx/static/themes/simple/js'
    'searx/static/themes/simple/src/generated/pygments.less'
    'searx/static/themes/simple/img'
    'searx/templates/simple/searxng-wordmark.min.svg'
    'searx/templates/simple/icons.html'
)


# tests
# -----

GECKODRIVER_VERSION="v0.30.0"
BLACK_OPTIONS=("--target-version" "py37" "--line-length" "120" "--skip-string-normalization")
BLACK_TARGETS=("--exclude" "searx/static,searx/languages.py" "--include" 'searxng.msg|\.pyi?$' "searx" "searxng_extra" "tests")

YAMLLINT_FILES=()
while IFS= read -r line; do
   YAMLLINT_FILES+=("$line")
done <<< "$(git ls-files './tests/*.yml' './searx/*.yml' './utils/templates/etc/searxng/*.yml')"

RST_FILES=(
    'README.rst'
)

PYLINT_SEARXNG_DISABLE_OPTION="\
I,C,R,\
W0105,W0212,W0511,W0603,W0613,W0621,W0702,W0703,W1401,\
E1136"
PYLINT_ADDITIONAL_BUILTINS_FOR_ENGINES="supported_languages,language_aliases,logger,categories"
PYLINT_OPTIONS="-m pylint -j 0 --rcfile .pylintrc"


# weblate
# -------

TRANSLATIONS_WORKTREE="$CACHE/translations"


# python
# ------

PY="${PY:=3}"
PYTHON="${PYTHON:=python$PY}"
PY_ENV="${PY_ENV:=local/py${PY}}"
PY_ENV_BIN="${PY_ENV}/bin"
PY_ENV_PIP_INSTALL="-r requirements.txt"
PY_ENV_DEPENDENCIES="requirements.txt setup.py pyproject.toml"
PY_ENV_DEPENDENCIES_SHA="${PY_ENV}/dependencies.sha256.txt"

# folder where the python distribution takes place
PYDIST="${PYDIST:=dist}"

# folder where the intermediate build files take place
PYBUILD="${PYBUILD:=build/py${PY}}"
