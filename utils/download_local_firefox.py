#!/bin/sh
#!/usr/bin/env python
# lint: pylint
# SPDX-License-Identifier: AGPL-3.0-or-later

"""Dedicated to GitHub workflow: download the last Firefox version into the ./firefox directory
Avoid the Ubuntu Snap version: the gecko driver can't use it
"""

import pathlib
import tarfile
import re
import os
from urllib.parse import urlparse, urljoin
from distutils.version import LooseVersion  # pylint: disable=deprecated-module

import requests
import tempfile
from lxml import html


BASE_URL = 'https://ftp.mozilla.org'
RELEASE_PATH = '/pub/firefox/releases/'
URL = BASE_URL + RELEASE_PATH
NORMAL_REGEX = re.compile(r'^[0-9]+\.[0-9](\.[0-9])?$')


def fetch_firefox_binary_url():
    resp = requests.get(URL, timeout=2.0)
    if resp.status_code != 200:
        raise Exception("Error fetching firefox versions, HTTP code " + resp.status_code)
    dom = html.fromstring(resp.text)
    versions = []

    for link in dom.xpath('//a/@href'):
        url = urlparse(urljoin(URL, link))
        path = url.path
        if path.startswith(RELEASE_PATH):
            version = path[len(RELEASE_PATH) : -1]
            if NORMAL_REGEX.match(version):
                download_url = BASE_URL + link + f'linux-x86_64/en-US/firefox-{version}.tar.bz2'
                versions.append((LooseVersion(version), download_url))

    list.sort(versions, reverse=True, key=lambda t: t[0])
    return versions[0][1]


def main():
    firefox_binary_path = pathlib.Path.cwd() / 'firefox/firefox'
    firefox_link_path = pathlib.Path('/usr/bin/firefox')

    if firefox_link_path.exists() and firefox_binary_path.exists():
        print('Local Firefox is already installed')
        return

    tar_bz2_url = fetch_firefox_binary_url()
    print(f'downloading {tar_bz2_url}')
    tar_bz2_response = requests.get(tar_bz2_url, stream=True)
    tar_bz2_response.raise_for_status()
    temp_handle, temp_filename = tempfile.mkstemp(suffix='tar.bz2', prefix='firefox')
    try:
        with os.fdopen(temp_handle, "wb") as temp_file:
            for chunk in tar_bz2_response.iter_content(1_048_576):
                print('.', end='', flush=True)
                temp_file.write(chunk)
        print()

        print('untar')
        with tarfile.open(temp_filename, mode='r:bz2') as ff_tar:
            ff_tar.extractall('.')

        print(f'create symbolic link to {firefox_link_path}')
        if firefox_link_path.exists():
            firefox_link_path.unlink()
        firefox_link_path.symlink_to(firefox_binary_path)
    finally:
        os.remove(temp_filename)


if __name__ == '__main__':
    main()
