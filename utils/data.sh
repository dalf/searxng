# SPDX-License-Identifier: AGPL-3.0-or-later

data.help() {
cat <<EOF
data.:
  all       : update searx/languages.py and ./data/*
  languages : update searx/data/engines_languages.json & searx/languages.py
  useragents: update searx/data/useragents.json with the most recent versions of Firefox.
EOF
}

data.all() {
    (   set -e
        pyenv.activate
        data.languages
        data.useragents
        data.osm_keys_tags
        build_msg DATA "update searx/data/ahmia_blacklist.txt"
        python searxng_extra/update/update_ahmia_blacklist.py
        build_msg DATA "update searx/data/wikidata_units.json"
        python searxng_extra/update/update_wikidata_units.py
        build_msg DATA "update searx/data/currencies.json"
        python searxng_extra/update/update_currencies.py
    )
}

data.languages() {
    (   set -e
        pyenv.activate
        build_msg ENGINES "fetch languages .."
        python searxng_extra/update/update_languages.py
        build_msg ENGINES "update update searx/languages.py"
        build_msg DATA "update searx/data/engines_languages.json"
    )
    dump_return $?
}

data.useragents() {
    build_msg DATA "update searx/data/useragents.json"
    pyenv.cmd python searxng_extra/update/update_firefox_version.py
    dump_return $?
}

data.osm_keys_tags() {
    build_msg DATA "update searx/data/osm_keys_tags.json"
    pyenv.cmd python searxng_extra/update/update_osm_keys_tags.py
    dump_return $?
}
