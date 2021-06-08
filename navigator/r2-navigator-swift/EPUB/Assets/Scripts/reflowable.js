
// Script used for reflowable layouts.
// WARNING: iOS 9 requires ES5
(function() {

  window.addEventListener("load", function() {

    // Notifies native code that the page is loaded after it is rendered.
    // Waiting for the next animation frame seems to do the trick to make sure the page is fully rendered.
    window.requestAnimationFrame(function() {
      webkit.messageHandlers.spreadLoaded.postMessage({});
    });

    // Setups the `viewport` meta tag to disable zooming.
    var meta = document.createElement("meta");
    meta.setAttribute("name", "viewport");
    meta.setAttribute("content", "width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, shrink-to-fit=no");
    document.head.appendChild(meta);

  });

})();
