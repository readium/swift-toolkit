(function() {

  document.addEventListener('DOMContentLoaded', injectCSS);

  function injectCSS() {
    function createLink(name) {
      var link = document.createElement('link');
      link.setAttribute('rel', 'stylesheet');
      link.setAttribute('type', 'text/css');
      link.setAttribute('href', '${resourcesURL}/styles/${contentLayout}/' + name + '.css');
      return link;
    }

    var head = document.getElementsByTagName('head')[0];
    head.appendChild(createLink('ReadiumCSS-after'));
    head.insertBefore(createLink('ReadiumCSS-before'), head.children[0]);
  }

})();
