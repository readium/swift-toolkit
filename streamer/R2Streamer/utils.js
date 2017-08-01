//// Notify native code that the page has loaded.
//window.addEventListener("load", function(){ // on page load
//                        // Notify native code that the page is loaded.
//                        webkit.messageHandlers.didLoad.postMessage("");
//                        }, false);


var scrollToId = function(id, screenWidth) {
    var element = document.getElementById(id)
    var rect = element.getBoundingClientRect();
    var offset = window.scrollX + rect.left;
    var snappedOffset = offset - (offset % screenWidth);

    document.body.scrollLeft = snappedOffset;
};
