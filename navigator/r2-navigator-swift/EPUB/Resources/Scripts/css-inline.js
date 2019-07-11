(function() {

  document.addEventListener('DOMContentLoaded', injectCSS);

  function injectCSS() {
    function createStyle(css) {
      var style = document.createElement('style');
      style.innerHTML = css;
      return style;
    }

    var head = document.getElementsByTagName('head')[0];
    head.appendChild(createStyle(`${css-after}`));
    head.insertBefore(createStyle(`${css-before}`), head.children[0]);
  }

})();
