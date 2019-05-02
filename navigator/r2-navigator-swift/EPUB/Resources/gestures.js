(function() {
  var isTapping = false;
  var touchStartTime = null;
  var startX = 0;
  var startY = 0;

  document.addEventListener('touchstart', touchstart, false);
  document.addEventListener('touchend', touchend, false);

  function touchstart(event) {
    // https://stackoverflow.com/questions/4878484/difference-between-tagname-and-nodename
    var nodeName = event.target.nodeName.toLowerCase();
    // Ignores taps on interactive HTML elements.
    // FIXME: there are more cases to handle, it needs to be researched
    if (nodeName == 'a' || nodeName == 'input') {
        return;
    }

    isTapping = (event.touches.length == 1);
    if (!isTapping) {
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

    webkit.messageHandlers.tap.postMessage({
      "x": touch.screenX,
      "y": touch.screenY,
    });

    event.stopPropagation();
    event.preventDefault();
  }
})();
