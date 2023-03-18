# SPDX-License-Identifier: AGPL-3.0-or-later
# lint: pylint

"""vanilla searx engine API

"""

import searx.network
from searx.utils import gen_useragent
from searx.metrics.error_recorder import count_error


def get_query_and_params(engine, search_query):
    params = {}
    params['category'] = search_query.engineref_list[0].category
    params['pageno'] = search_query.pageno
    params['safesearch'] = search_query.safesearch
    params['time_range'] = search_query.time_range
    params['engine_data'] = search_query.engine_data.get(engine.name, {})
    params['language'] = search_query.lang
    return search_query.query, params


def get_query_and_params_online(engine, search_query):
    query, params = get_query_and_params(engine, search_query)

    # add default params
    params.update(
        {
            # fmt: off
            'method': 'GET',
            'headers': {},
            'data': {},
            'url': '',
            'cookies': {},
            'auth': None
            # fmt: on
        }
    )

    # add an user agent
    params['headers']['User-Agent'] = gen_useragent()

    # add Accept-Language header
    if engine.send_accept_language_header and search_query.locale:
        ac_lang = search_query.locale.language
        if search_query.locale.territory:
            ac_lang = "%s-%s,%s;q=0.9,*;q=0.5" % (
                search_query.locale.language,
                search_query.locale.territory,
                search_query.locale.language,
            )
        params['headers']['Accept-Language'] = ac_lang

    return query, params


def send_http_request(engine, params):
    # create dictionary which contain all
    # information about the request
    request_args = {'headers': params['headers'], 'cookies': params['cookies'], 'auth': params['auth']}

    # verify
    # if not None, it overrides the verify value defined in the network.
    # use False to accept any server certificate
    # use a path to file to specify a server certificate
    verify = params.get('verify')
    if verify is not None:
        request_args['verify'] = params['verify']

    # max_redirects
    max_redirects = params.get('max_redirects')
    if max_redirects:
        request_args['max_redirects'] = max_redirects

    # allow_redirects
    if 'allow_redirects' in params:
        request_args['allow_redirects'] = params['allow_redirects']

    # soft_max_redirects
    soft_max_redirects = params.get('soft_max_redirects', max_redirects or 0)

    # raise_for_status
    request_args['raise_for_httperror'] = params.get('raise_for_httperror', True)

    # specific type of request (GET or POST)
    if params['method'] == 'GET':
        req = searx.network.get
    else:
        req = searx.network.post

    request_args['data'] = params['data']

    # send the request
    response = req(params['url'], **request_args)

    # check soft limit of the redirect count
    if len(response.history) > soft_max_redirects:
        # unexpected redirect : record an error
        # but the engine might still return valid results.
        status_code = str(response.status_code or '')
        reason = response.reason_phrase or ''
        hostname = response.url.host
        count_error(
            engine.name,
            '{} redirects, maximum: {}'.format(len(response.history), soft_max_redirects),
            (status_code, reason, hostname),
            secondary=True,
        )

    return response
