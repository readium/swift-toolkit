var singleTouchGesture = false;
var startX = 0;
var startY = 0;
var maxScreenX = 0;
var maxScreenY = 0;

window.addEventListener("load", function(){ // on page load
                        // Get screen X and Y sizes.
                        maxScreenUpdate();
                        // Events listeners for the touches.
                        window.document.addEventListener("touchstart", handleTouchStart, false);
                        window.document.addEventListener("touchend", handleTouchEnd, false);
                        // When device orientation changes, screen X and Y sizes are recalculated.
                        window.addEventListener("orientationchange", maxScreenUpdate);
                        }, false);

// On screen orientation updates.
var maxScreenUpdate = function() {
    if (window.orientation === 0 || window.orientation == 180) {
        maxScreenX = screen.width;
        maxScreenY = screen.height;
    } else {
        maxScreenX = screen.height;
        maxScreenY = screen.width;
    }
    // snapCurrentPosition();
};

// var snapCurrentPosition = function() {
//     var currentOffset = window.scrollX;
//     var currentOffsetSnapped = snapOffset(currentOffset + 1);
//
//     document.body.scrollLeft = currentOffsetSnapped;
// };

// When a touch is detected records its starting coordinates and if it's a singleTouchGesture.
var handleTouchStart = function(event) {
    if (event.target.nodeName.toUpperCase() === 'A') {
        console.log("Touched a link.");
        // singleTouchGesture = false;
        return;
    }
    console.log("Touch sent to native code.");
    singleTouchGesture = event.touches.length == 1;

    var touch = event.changedTouches[0];

    startX = touch.screenX % maxScreenX;
    startY = touch.screenY % maxScreenY;
};

// When a touch ends, check if any action has to be made, and contact native code.
var handleTouchEnd = function(event) {
    if(!singleTouchGesture) {
        return;
    }

    var touch = event.changedTouches[0];

    var relativeDistanceX = Math.abs(((touch.screenX % maxScreenX) - startX) / maxScreenX);
    var relativeDistanceY = Math.abs(((touch.screenY % maxScreenY) - startY) / maxScreenY);
    var touchDistance = Math.max(relativeDistanceX, relativeDistanceY);

    var scrollWidth = document.scrollWidth;
    var screenWidth = maxScreenX;
    var tapAreaWidth = maxScreenX * 0.2;

    // // Tap to turn.
    if(touchDistance < 0.01) {
        var position = (touch.screenX % maxScreenX) / maxScreenX;
        if (position <= 0.2) {
            // TAP left.
            console.log("LeftTapped");
            webkit.messageHandlers.leftTap.postMessage("");
        } else if(position >= 0.8) {
            // TAP rigth.
            console.log("RightTapped");
            webkit.messageHandlers.rightTap.postMessage("");
        } else {
            // TAP center.
            console.log("CenterTapped");
            webkit.messageHandlers.centerTap.postMessage("");
        }
        event.stopPropagation();
        event.preventDefault();
        return;
    }
};
