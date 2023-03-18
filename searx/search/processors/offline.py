# SPDX-License-Identifier: AGPL-3.0-or-later
# lint: pylint

"""Processores for engine-type: ``offline``

"""

from .abstract import EngineProcessor
from .searx_engine_api import get_query_and_params


class OfflineProcessor(EngineProcessor):
    """Processor class used by ``offline`` engines"""

    engine_type = 'offline'

    def search(self, engine_search_query):
        return self.engine.search(*get_query_and_params(self.engine, engine_search_query))

    def search_wrapper(self, engine_search_query, result_container, start_time, timeout_limit):
        try:
            search_results = self.search(engine_search_query)
            self.extend_container(result_container, start_time, search_results)
        except ValueError as e:
            # do not record the error
            self.logger.exception('engine {0} : invalid input : {1}'.format(self.engine_name, e))
        except Exception as e:  # pylint: disable=broad-except
            self.handle_exception(result_container, e)
            self.logger.exception('engine {0} : exception : {1}'.format(self.engine_name, e))
