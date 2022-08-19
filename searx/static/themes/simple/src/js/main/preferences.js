/* SPDX-License-Identifier: AGPL-3.0-or-later */
(function (w, d, searxng) {
  'use strict';

  if (searxng.endpoint !== 'preferences') {
    return;
  }

  function update_engine_descriptions (engine_descriptions) {
    for (const [engine_name, description] of Object.entries(engine_descriptions)) {
      let elements = d.querySelectorAll('[data-engine-name="' + engine_name + '"] .engine-description');
      for (const element of elements) {
        let descriptionElement = document.createTextNode(description[0] + " ");
        // \xa0 is a breaking space ( &nbsp; ): see https://en.wikipedia.org/wiki/Non-breaking_space
        let sourceElement = searxng.h('i', null, searxng.settings.translations.Source + ':\xa0' + description[1]);
        element.appendChild(descriptionElement);
        element.appendChild(sourceElement);
      }
    }
  }

  searxng.ready(function () {
    let engine_descriptions = null;
    function load_engine_descriptions () {
      if (engine_descriptions == null) {
        searxng.http("GET", "engine_descriptions.json").then(function (content) {
          engine_descriptions = JSON.parse(content);
          update_engine_descriptions(engine_descriptions);
        });
      }
    }

    for (const el of d.querySelectorAll('[data-engine-name]')) {
      searxng.on(el, 'mouseenter', load_engine_descriptions);
    }
  });
})(window, document, window.searxng);
