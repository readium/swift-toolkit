
// Script used for fixed layouts, in the wrapper pages.
// WARNING: iOS 9 requires ES5

function FixedPage(iframeId) {
  // Fixed dimensions for the page, extracted from the viewport meta tag.
  var _pageSize = null;
  // Available viewport size to fill with the resource.
  var _viewportSize = null;
  // Margins that should not overlap the content.
  var _safeAreaInsets = null;

  // iFrame containing the page.
  var _iframe = document.getElementById(iframeId);
  _iframe.addEventListener('load', loadPageSize);
    
  // Viewport element containing the iFrame.
  var _viewport = _iframe.closest('.viewport')

  // Parses the page size from the viewport meta tag of the loaded resource.
  function loadPageSize() {
    var viewport = _iframe.contentWindow.document.querySelector('meta[name=viewport]');
    if (!viewport) {
      return;
    }
    var regex = /(\w+) *= *([^\s,]+)/g
    var properties = {};
    var match;
    while (match = regex.exec(viewport.content)) {
      properties[match[1]] = match[2];
    }
    var width = Number.parseFloat(properties.width);
    var height = Number.parseFloat(properties.height);
    if (width && height) {
      _pageSize = { 'width': width, 'height': height };
      layoutPage();
    }
  }

  // Layouts the page iframe to center its content and scale it to fill the available viewport.
  function layoutPage() {
    if (!_pageSize || !_viewportSize || !_safeAreaInsets) {
      return;
    }

    _iframe.style.width = _pageSize.width + 'px';
    _iframe.style.height = _pageSize.height + 'px';
    _iframe.style.marginTop = (_safeAreaInsets.top - _safeAreaInsets.bottom) + 'px';
    _iframe.style.marginLeft = (_safeAreaInsets.left - _safeAreaInsets.right) + 'px';

    // Calculates the zoom scale required to fit the content to the viewport.
    var widthRatio = _viewportSize.width / _pageSize.width;
    var heightRatio = _viewportSize.height / _pageSize.height;
    var scale = Math.min(widthRatio, heightRatio);

    // Sets the viewport of the wrapper page (this page) to scale the iframe.
    var viewport = document.querySelector('meta[name=viewport]');
    viewport.content = 'initial-scale=' + scale + ', minimum-scale=' + scale;
  }

  return {
    // Returns whether the page is currently loading its contents.
    'isLoading': false,

    // Href of the resource currently loaded in the page.
    'href': null,

    // Loads the given link ({href, url}) in the page.
    'load': function(link, completion) {
      if (!link.href || !link.url) {
        if (completion) { completion(); }
        return;
      }

      var page = this;
      page.href = link.href;
      page.isLoading = true;

      function loaded() {
        _iframe.removeEventListener('load', loaded);
        
        // Waiting for the next animation frame seems to do the trick to make sure the page is fully rendered.
        _iframe.contentWindow.requestAnimationFrame(function() {
          page.isLoading = false;
          if (completion) { completion(); }
        });
      }

      _iframe.addEventListener('load', loaded);
      _iframe.src = link.url;
    },

    // Resets the page and empty its contents.
    'reset': function() {
      if (!this.href) {
        return;
      }
      this.href = null;
      _pageSize = null;
      _iframe.src = 'about:blank';
    },

    // Evaluates a script in the context of the page.
    'eval': function(script) {
      if (!this.href || this.isLoading) {
        return;
      }
      return _iframe.contentWindow.eval(script);
    },

    // Updates the available viewport to display the resource.
    'setViewport': function(viewportSize, safeAreaInsets) {
      _viewportSize = viewportSize;
      _safeAreaInsets = safeAreaInsets;
      layoutPage();
    },

    // Shows the page's viewport.
    'show': function() {
      _viewport.style.display = 'block';
    },

    // Hides the page's viewport.
    'hide': function() {
      _viewport.style.display = 'none';
    }
  };
}
