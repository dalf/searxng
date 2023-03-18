# SPDX-License-Identifier: AGPL-3.0-or-later
# lint: pylint

"""Processores for engine-type: ``online``

"""
# pylint: disable=use-dict-literal

from timeit import default_timer
import asyncio
import ssl
import httpx

import searx.network
from searx.exceptions import (
    SearxEngineAccessDeniedException,
    SearxEngineCaptchaException,
    SearxEngineTooManyRequestsException,
)
from .abstract import EngineProcessor
from .searx_engine_api import get_query_and_params_online, send_http_request


class OnlineProcessor(EngineProcessor):
    """Processor class for ``online`` engines."""

    engine_type = 'online'

    def initialize(self):
        # set timeout for all HTTP requests
        searx.network.set_timeout_for_thread(self.engine.timeout, start_time=default_timer())
        # reset the HTTP total time
        searx.network.reset_time_for_thread()
        # set the network
        searx.network.set_context_network_name(self.engine_name)
        super().initialize()

    def request(self, query, params):
        self.engine.request(query, params)

    def response(self, resp):
        return self.engine.response(resp)

    def get_query_and_params_online(self, engine_search_query):
        return get_query_and_params_online(self.engine, engine_search_query)

    def search(self, engine_search_query):
        query, params = self.get_query_and_params_online(engine_search_query)
        if query is None or params is None:
            return None

        # update request parameters dependent on
        # search-engine (contained in engines folder)
        self.request(query, params)

        # ignoring empty urls
        if params['url'] is None:
            return None

        if not params['url']:
            return None

        # send request
        resp = send_http_request(self.engine, params)

        # parse the response
        resp.search_params = params
        return self.response(resp)

    def search_wrapper(self, engine_search_query, result_container, start_time, timeout_limit):
        # set timeout for all HTTP requests
        searx.network.set_timeout_for_thread(timeout_limit, start_time=start_time)
        # reset the HTTP total time
        searx.network.reset_time_for_thread()
        # set the network
        searx.network.set_context_network_name(self.engine_name)

        try:
            # send requests and parse the results
            search_results = self.search(engine_search_query)
            self.extend_container(result_container, start_time, search_results)
        except ssl.SSLError as e:
            # requests timeout (connect or read)
            self.handle_exception(result_container, e, suspend=True)
            self.logger.error("SSLError {}, verify={}".format(e, searx.network.get_network(self.engine_name).verify))
        except (httpx.TimeoutException, asyncio.TimeoutError) as e:
            # requests timeout (connect or read)
            self.handle_exception(result_container, e, suspend=True)
            self.logger.error(
                "HTTP requests timeout (search duration : {0} s, timeout: {1} s) : {2}".format(
                    default_timer() - start_time, timeout_limit, e.__class__.__name__
                )
            )
        except (httpx.HTTPError, httpx.StreamError) as e:
            # other requests exception
            self.handle_exception(result_container, e, suspend=True)
            self.logger.exception(
                "requests exception (search duration : {0} s, timeout: {1} s) : {2}".format(
                    default_timer() - start_time, timeout_limit, e
                )
            )
        except SearxEngineCaptchaException as e:
            self.handle_exception(result_container, e, suspend=True)
            self.logger.exception('CAPTCHA')
        except SearxEngineTooManyRequestsException as e:
            if "google" in self.engine_name:
                self.logger.warn(
                    "Set to 'true' the use_mobile_ui parameter in the 'engines:'"
                    " section of your settings.yml file if google is blocked for you."
                )
            self.handle_exception(result_container, e, suspend=True)
            self.logger.exception('Too many requests')
        except SearxEngineAccessDeniedException as e:
            self.handle_exception(result_container, e, suspend=True)
            self.logger.exception('Searx is blocked')
        except Exception as e:  # pylint: disable=broad-except
            self.handle_exception(result_container, e)
            self.logger.exception('exception : {0}'.format(e))

    def get_default_tests(self):
        tests = {}

        tests['simple'] = {
            'matrix': {'query': ('life', 'computer')},
            'result_container': ['not_empty'],
        }

        if getattr(self.engine, 'paging', False):
            tests['paging'] = {
                'matrix': {'query': 'time', 'pageno': (1, 2, 3)},
                'result_container': ['not_empty'],
                'test': ['unique_results'],
            }
            if 'general' in self.engine.categories:
                # avoid documentation about HTML tags (<time> and <input type="time">)
                tests['paging']['matrix']['query'] = 'news'

        if getattr(self.engine, 'time_range', False):
            tests['time_range'] = {
                'matrix': {'query': 'news', 'time_range': (None, 'day')},
                'result_container': ['not_empty'],
                'test': ['unique_results'],
            }

        if getattr(self.engine, 'supported_languages', []):
            tests['lang_fr'] = {
                'matrix': {'query': 'paris', 'lang': 'fr'},
                'result_container': ['not_empty', ('has_language', 'fr')],
            }
            tests['lang_en'] = {
                'matrix': {'query': 'paris', 'lang': 'en'},
                'result_container': ['not_empty', ('has_language', 'en')],
            }

        if getattr(self.engine, 'safesearch', False):
            tests['safesearch'] = {'matrix': {'query': 'porn', 'safesearch': (0, 2)}, 'test': ['unique_results']}

        return tests
