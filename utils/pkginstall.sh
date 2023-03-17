# apt packages

SEARXNG_PACKAGES_debian="\
python3-dev python3-babel python3-venv
uwsgi uwsgi-plugin-python3
git build-essential libxslt-dev zlib1g-dev libffi-dev libssl-dev"

SEARXNG_BUILD_PACKAGES_debian="\
firefox graphviz imagemagick texlive-xetex librsvg2-bin
texlive-latex-recommended texlive-extra-utils fonts-dejavu
latexmk shellcheck"

# pacman packages

SEARXNG_PACKAGES_arch="\
python python-pip python-lxml python-babel
uwsgi uwsgi-plugin-python
git base-devel libxml2"

SEARXNG_BUILD_PACKAGES_arch="\
firefox graphviz imagemagick texlive-bin extra/librsvg
texlive-core texlive-latexextra ttf-dejavu shellcheck"

# dnf packages

SEARXNG_PACKAGES_fedora="\
python python-pip python-lxml python-babel python3-devel
uwsgi uwsgi-plugin-python3
git @development-tools libxml2 openssl"

SEARXNG_BUILD_PACKAGES_fedora="\
firefox graphviz graphviz-gd ImageMagick librsvg2-tools
texlive-xetex-bin texlive-collection-fontsrecommended
texlive-collection-latex dejavu-sans-fonts dejavu-serif-fonts
dejavu-sans-mono-fonts ShellCheck"

# ubuntu, debian, arch, fedora, centos ...
DIST_ID=$(source /etc/os-release; echo "$ID");
# shellcheck disable=SC2034
DIST_VERS=$(source /etc/os-release; echo "$VERSION_ID");

case $DIST_ID-$DIST_VERS in
    ubuntu-18.04)
        SEARXNG_PACKAGES="${SEARXNG_PACKAGES_debian}"
        SEARXNG_BUILD_PACKAGES="${SEARXNG_BUILD_PACKAGES_debian}"
        ;;
    ubuntu-20.04)
        # https://wiki.ubuntu.com/FocalFossa/ReleaseNotes#Python3_by_default
        SEARXNG_PACKAGES="${SEARXNG_PACKAGES_debian} python-is-python3"
        SEARXNG_BUILD_PACKAGES="${SEARXNG_BUILD_PACKAGES_debian}"
        ;;
    ubuntu-*|debian-*)
        SEARXNG_PACKAGES="${SEARXNG_PACKAGES_debian}"
        SEARXNG_BUILD_PACKAGES="${SEARXNG_BUILD_PACKAGES_debian}"
        ;;
    arch-*)
        SEARXNG_PACKAGES="${SEARXNG_PACKAGES_arch}"
        SEARXNG_BUILD_PACKAGES="${SEARXNG_BUILD_PACKAGES_arch}"
        ;;
    fedora-*)
        SEARXNG_PACKAGES="${SEARXNG_PACKAGES_fedora}"
        SEARXNG_BUILD_PACKAGES="${SEARXNG_BUILD_PACKAGES_fedora}"
        ;;
esac

pkg_install() {
    echo -e "\npackage(s)::\n $@"
    case $DIST_ID in
        ubuntu|debian)
            apt update
            # shellcheck disable=SC2068
            apt-get install -m -y $@
            ;;
        arch)
            # shellcheck disable=SC2068
            pacman --noprogressbar -Sy --noconfirm --needed $@
            ;;
        fedora)
            # shellcheck disable=SC2068
            dnf install -y $@
            ;;
	    centos)
            # shellcheck disable=SC2068
            yum install -y $@
            ;;
    esac
}

if [ "$1" == "build" ]; then
    pkg_install "${SEARXNG_BUILD_PACKAGES}"
else
    pkg_install "${SEARXNG_PACKAGES}"
fi
