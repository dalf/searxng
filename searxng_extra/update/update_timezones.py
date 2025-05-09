#!/usr/bin/env python
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Fetch user query --> timezone mapping
"""

import json
import collections
import zoneinfo

from searx.locales import LOCALE_NAMES, locales_initialize
from searx.network import set_timeout_for_thread
from searx.engines import wikidata, set_loggers
from searx.data import data_dir

DATA_FILE = data_dir / 'timezones.json'

set_loggers(wikidata, 'wikidata')
locales_initialize()


SPARQL_TAGS_REQUEST = """
SELECT
  ?label                                  # country name
  ?capitalLabel                           # one (arbitrary “first”) capital
WHERE {
  ?item wdt:P36  ?capital ;               # capital(s)
        wdt:P31  wd:Q3624078 ;            # sovereign state
        rdfs:label ?label .
  ?capital rdfs:label ?capitalLabel .
  FILTER ( LANG(?capitalLabel) = "en" ).
  FILTER (  LANG(?label) IN (%LANGUAGES_SPARQL%)).
   
  MINUS {                                 # exclude defunct states
    ?item wdt:P31 wd:Q3024240 .
  }
}
GROUP BY ?label ?capitalLabel
ORDER BY ?item ?label
"""


LANGUAGES = LOCALE_NAMES.keys()
LANGUAGES_SPARQL = ', '.join(set(map(lambda l: repr(l.split('_')[0]), LANGUAGES)))


def wikidata_request_result_iterator(request):
    result = wikidata.send_wikidata_query(request.replace('%LANGUAGES_SPARQL%', LANGUAGES_SPARQL), timeout=20)
    if result is not None:
        yield from result['results']['bindings']


def get_countries(cites: dict[str, str]):
    results = collections.OrderedDict()
    for tag in wikidata_request_result_iterator(SPARQL_TAGS_REQUEST):
        countryLabel = tag['label']['value'].lower()
        capitalLabel = tag['capitalLabel']['value'].lower()
        if capitalLabel not in cites:
            print("ignore", capitalLabel)
            continue
        capitalTZ = cites[capitalLabel]
        if countryLabel not in results:
            # keep only the first mapping
            results[countryLabel] = capitalTZ
    return results


def get_cities():
    return {
        e.split("/")[1].replace("_", " "): e
        for e in zoneinfo.available_timezones()
        if "/" in e and not e.startswith("Etc/")
    }


if __name__ == '__main__':
    set_timeout_for_thread(60)
    cites = get_cities()
    result = {
        'countries': get_countries(cites),
        'cities': cites,
    }
    with DATA_FILE.open('w', encoding="utf8") as f:
        json.dump(result, f, indent=4, sort_keys=True, ensure_ascii=False)
