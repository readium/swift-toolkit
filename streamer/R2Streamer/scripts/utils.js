// Notify native code that the page has loaded.
window.addEventListener("load", function(){ // on page load
                        // Notify native code that the page is loaded.
                        webkit.messageHandlers.didLoad.postMessage("");
                        }, false);

var last_known_scroll_position = 0;
var ticking = false;

// Position in range [0 - 1].
var update = function(position) {
    let positionString = position.toString()
    webkit.messageHandlers.updateProgression.postMessage(positionString);
};

window.addEventListener('scroll', function(e) {
                       last_known_scroll_position = window.scrollX / document.getElementsByTagName("body")[0].scrollWidth;
                       if (!ticking) {
                       window.requestAnimationFrame(function() {
                                                    update(last_known_scroll_position);
                                                    ticking = false;
                                                    });
                       }
                       ticking = true;
                       });

// Scroll to the given TagId in document and snap.
var scrollToId = function(id) {
    var element = document.getElementById(id);
    var elementOffset = element.scrollLeft // element.getBoundingClientRect().left works for Gutenbergs books
    var offset = window.scrollX + elementOffset;

    document.body.scrollLeft = snapOffset(offset);
};

// Position must be in the range [0 - 1], 0-100%.
var scrollToPosition = function(position, dir) {
    console.log("ScrollToPosition");
    if ((position < 0) || (position > 1)) {
        console.log("InvalidPosition");
        return;
    }
    var offset = 0.0;
    if (dir == 'rtl') {
        offset = (-document.body.scrollWidth + maxScreenX) * (1.0-position);
    } else {
        offset = document.body.scrollWidth * position;
    }
    console.log(offset);
    document.body.scrollLeft = offset;
};

var scrollLeft = function(dir) {
    var scrollWidth = document.body.scrollWidth;
    var newOffset = window.scrollX - maxScreenX;
    var edge = -scrollWidth + maxScreenX;
    var newEdge = (dir == "rtl")? edge:0;
    
    if (newOffset > newEdge) {
        document.body.scrollLeft = newOffset
        return 0;
    } else {
        var oldOffset = window.scrollX;
        document.body.scrollLeft = newEdge;
        if (oldOffset != newEdge) {
            return 0;
        } else {
            return "edge";
        }
    }
};

var scrollRight = function(dir) {
    
    var scrollWidth = document.body.scrollWidth;
    var newOffset = window.scrollX + maxScreenX;
    var edge = scrollWidth - maxScreenX;
    var newEdge = (dir == "rtl")? 0:edge
    
    if (newOffset < newEdge) {
        document.body.scrollLeft = newOffset
        return 0;
    } else {
        var oldOffset = window.scrollX;
        document.body.scrollLeft = newEdge;
        if (oldOffset != newEdge) {
            return 0;
        } else {
            return "edge";
        }
    }
};

// Snap the offset to the screen width (page width).
var snapOffset = function(offset) {
    let value = offset + 1;

    return value - (value % maxScreenX);
};

/// User Settings.

// For setting user setting.
var setProperty = function(key, value) {
    var root = document.documentElement;

    root.style.setProperty(key, value);
};

// For removing user setting.
var removeProperty = function(key) {
    var root = document.documentElement;

    root.style.removeProperty(key);
};
