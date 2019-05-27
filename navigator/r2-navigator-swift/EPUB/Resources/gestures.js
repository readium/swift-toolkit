(function() {
  var isTapping = false;
  var touchStartTime = null;
  var startX = 0;
  var startY = 0;

  document.addEventListener('touchstart', touchstart, false);
  document.addEventListener('touchend', touchend, false);

  function touchstart(event) {
    isTapping = (event.touches.length == 1);
    if (isInteractiveElement(event.target) || !isTapping) {
      return;
    }

    var touch = event.changedTouches[0];
    startX = touch.pageX;
    startY = touch.pageY;
    touchStartTime = Date.now();
  }

  function touchend(event) {
    if (!isTapping || touchStartTime == null || Date.now() - touchStartTime > 500) {
      return;
    }
    isTapping = false;

    var touch = event.changedTouches[0];

    function approximatelyEqual(a, b) {
      return Math.abs(a - b) < 2;
    }

    if (!approximatelyEqual(startX, touch.pageX) || !approximatelyEqual(startY, touch.pageY)) {
      return;
    }
 
    if (!window.getSelection().isCollapsed) {
      // There's an on-going selection, the tap will dismiss it so we don't forward it.
      return;
    }

    webkit.messageHandlers.tap.postMessage({
      "screenX": touch.screenX,
      "screenY": touch.screenY,
      "clientX": touch.clientX,
      "clientY": touch.clientY,
    });

    // We don't want to disable the default WebView behavior as it breaks some features without bringing any value.
//    event.stopPropagation();
//    event.preventDefault();
  }

  function isInteractiveElement(element) {
    var interactiveTags = [
      'a',
      'button',
      'input',
      'label',
      'option',
      'select',
      'submit',
      'textarea',
      'video',
    ]

    // https://stackoverflow.com/questions/4878484/difference-between-tagname-and-nodename
    if (interactiveTags.indexOf(element.nodeName.toLowerCase()) != -1) {
        return true;
    }

    // Checks parents recursively because the touch might be for example on an <em> inside a <a>.
    if (element.parentElement) {
      return isInteractiveElement(element.parentElement);
    }
    
    return false;
  }

})();
