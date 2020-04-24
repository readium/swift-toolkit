(function() {
  window.addEventListener('DOMContentLoaded', function(event) {
    // If we don't set the CSS cursor property to pointer, then the click events are not triggered pre-iOS 13.
    document.body.style.cursor = 'pointer';
    
    document.addEventListener('click', onClick, false);
  });

  function onClick(event) {
 
    // If the app should handle the tap.
    // Examples of the app handling the tap would be
    // navigating left/right, or show/hide the toolbar.
    // If false, the tap is being handled within the webview,
    // such as with a hyperlink or by an publication's JS handler.
    let appShouldHandle = true;
 
    if (event.defaultPrevented || isInteractiveElement(event.target)) {
      appShouldHandle = false;
    }

    if (!window.getSelection().isCollapsed) {
      // There's an on-going selection, the tap will dismiss it so we don't forward it.
      return;
    }

    // Send the tap data over the JS bridge even if it's been handled
    // within the webview, so that it can be preserved and used
    // by the WKNavigationDelegate if needed.
    webkit.messageHandlers.tap.postMessage({
      "shouldHandle": appShouldHandle,
      "screenX": event.screenX,
      "screenY": event.screenY,
      "clientX": event.clientX,
      "clientY": event.clientY,
      "anchor": getNearestAnchor(event.target),
    });

    // We don't want to disable the default WebView behavior as it breaks some features without bringing any value.
//    event.stopPropagation();
//    event.preventDefault();
  }

  // See. https://github.com/JayPanoz/architecture/tree/touch-handling/misc/touch-handling
  function isInteractiveElement(element) {
    var interactiveTags = [
      'a',
      'audio',
      'button',
      'canvas',
      'details',
      'input',
      'label',
      'option',
      'select',
      'submit',
      'textarea',
      'video',
    ]
    if (interactiveTags.indexOf(element.nodeName.toLowerCase()) != -1) {
      return true;
    }

    // Checks whether the element is editable by the user.
    if (element.hasAttribute('contenteditable') && element.getAttribute('contenteditable').toLowerCase() != 'false') {
      return true;
    }

    // Checks parents recursively because the touch might be for example on an <em> inside a <a>.
    if (element.parentElement) {
      return isInteractiveElement(element.parentElement);
    }
    
    return false;
  }

  // Retrieves the markup of <a>...</a> if the tap was
  // anywhere within such an element (i.e. even on an <em> tag within it).
  // We return the markup rather than just a boolean as this could be more
  // useful further up the line.
  function getNearestAnchor(element) {
    if (element.nodeName.toLowerCase() === 'a') {
      return element.outerHTML;
    }
    if (element.parentElement) {
      return getNearestAnchor(element.parentElement);
    }
    return null;
  }

})();
