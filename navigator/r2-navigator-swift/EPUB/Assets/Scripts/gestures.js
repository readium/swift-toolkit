(function() {
  window.addEventListener('DOMContentLoaded', function(event) {
    // If we don't set the CSS cursor property to pointer, then the click events are not triggered pre-iOS 13.
    document.body.style.cursor = 'pointer';
    
    document.addEventListener('click', onClick, false);
  });

  function onClick(event) {

    if (!window.getSelection().isCollapsed) {
      // There's an on-going selection, the tap will dismiss it so we don't forward it.
      return;
    }

    // Send the tap data over the JS bridge even if it's been handled
    // within the webview, so that it can be preserved and used
    // by the WKNavigationDelegate if needed.
    webkit.messageHandlers.tap.postMessage({
      "defaultPrevented": event.defaultPrevented,
      "screenX": event.screenX,
      "screenY": event.screenY,
      "clientX": event.clientX,
      "clientY": event.clientY,
      "targetElement": event.target.outerHTML,
      "interactiveElement": nearestInteractiveElement(event.target),
    });

    // We don't want to disable the default WebView behavior as it breaks some features without bringing any value.
//    event.stopPropagation();
//    event.preventDefault();
  }

  // See. https://github.com/JayPanoz/architecture/tree/touch-handling/misc/touch-handling
  function nearestInteractiveElement(element) {
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
      return element.outerHTML;
    }

    // Checks whether the element is editable by the user.
    if (element.hasAttribute('contenteditable') && element.getAttribute('contenteditable').toLowerCase() != 'false') {
      return element.outerHTML;
    }

    // Checks parents recursively because the touch might be for example on an <em> inside a <a>.
    if (element.parentElement) {
      return nearestInteractiveElement(element.parentElement);
    }
    
    return null;
  }

})();
