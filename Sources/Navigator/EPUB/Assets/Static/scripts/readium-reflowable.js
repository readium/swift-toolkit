/******/ (() => { // webpackBootstrap
/******/ 	var __webpack_modules__ = ({

/***/ "./node_modules/@juggle/resize-observer/lib/DOMRectReadOnly.js":
/*!*********************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/DOMRectReadOnly.js ***!
  \*********************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   DOMRectReadOnly: () => (/* binding */ DOMRectReadOnly)
/* harmony export */ });
/* harmony import */ var _utils_freeze__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./utils/freeze */ "./node_modules/@juggle/resize-observer/lib/utils/freeze.js");

var DOMRectReadOnly = (function () {
    function DOMRectReadOnly(x, y, width, height) {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        this.top = this.y;
        this.left = this.x;
        this.bottom = this.top + this.height;
        this.right = this.left + this.width;
        return (0,_utils_freeze__WEBPACK_IMPORTED_MODULE_0__.freeze)(this);
    }
    DOMRectReadOnly.prototype.toJSON = function () {
        var _a = this, x = _a.x, y = _a.y, top = _a.top, right = _a.right, bottom = _a.bottom, left = _a.left, width = _a.width, height = _a.height;
        return { x: x, y: y, top: top, right: right, bottom: bottom, left: left, width: width, height: height };
    };
    DOMRectReadOnly.fromRect = function (rectangle) {
        return new DOMRectReadOnly(rectangle.x, rectangle.y, rectangle.width, rectangle.height);
    };
    return DOMRectReadOnly;
}());



/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/ResizeObservation.js":
/*!***********************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/ResizeObservation.js ***!
  \***********************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   ResizeObservation: () => (/* binding */ ResizeObservation)
/* harmony export */ });
/* harmony import */ var _ResizeObserverBoxOptions__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./ResizeObserverBoxOptions */ "./node_modules/@juggle/resize-observer/lib/ResizeObserverBoxOptions.js");
/* harmony import */ var _algorithms_calculateBoxSize__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./algorithms/calculateBoxSize */ "./node_modules/@juggle/resize-observer/lib/algorithms/calculateBoxSize.js");
/* harmony import */ var _utils_element__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./utils/element */ "./node_modules/@juggle/resize-observer/lib/utils/element.js");



var skipNotifyOnElement = function (target) {
    return !(0,_utils_element__WEBPACK_IMPORTED_MODULE_2__.isSVG)(target)
        && !(0,_utils_element__WEBPACK_IMPORTED_MODULE_2__.isReplacedElement)(target)
        && getComputedStyle(target).display === 'inline';
};
var ResizeObservation = (function () {
    function ResizeObservation(target, observedBox) {
        this.target = target;
        this.observedBox = observedBox || _ResizeObserverBoxOptions__WEBPACK_IMPORTED_MODULE_0__.ResizeObserverBoxOptions.CONTENT_BOX;
        this.lastReportedSize = {
            inlineSize: 0,
            blockSize: 0
        };
    }
    ResizeObservation.prototype.isActive = function () {
        var size = (0,_algorithms_calculateBoxSize__WEBPACK_IMPORTED_MODULE_1__.calculateBoxSize)(this.target, this.observedBox, true);
        if (skipNotifyOnElement(this.target)) {
            this.lastReportedSize = size;
        }
        if (this.lastReportedSize.inlineSize !== size.inlineSize
            || this.lastReportedSize.blockSize !== size.blockSize) {
            return true;
        }
        return false;
    };
    return ResizeObservation;
}());



/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/ResizeObserver.js":
/*!********************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/ResizeObserver.js ***!
  \********************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   ResizeObserver: () => (/* binding */ ResizeObserver)
/* harmony export */ });
/* harmony import */ var _ResizeObserverController__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./ResizeObserverController */ "./node_modules/@juggle/resize-observer/lib/ResizeObserverController.js");
/* harmony import */ var _utils_element__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./utils/element */ "./node_modules/@juggle/resize-observer/lib/utils/element.js");


var ResizeObserver = (function () {
    function ResizeObserver(callback) {
        if (arguments.length === 0) {
            throw new TypeError("Failed to construct 'ResizeObserver': 1 argument required, but only 0 present.");
        }
        if (typeof callback !== 'function') {
            throw new TypeError("Failed to construct 'ResizeObserver': The callback provided as parameter 1 is not a function.");
        }
        _ResizeObserverController__WEBPACK_IMPORTED_MODULE_0__.ResizeObserverController.connect(this, callback);
    }
    ResizeObserver.prototype.observe = function (target, options) {
        if (arguments.length === 0) {
            throw new TypeError("Failed to execute 'observe' on 'ResizeObserver': 1 argument required, but only 0 present.");
        }
        if (!(0,_utils_element__WEBPACK_IMPORTED_MODULE_1__.isElement)(target)) {
            throw new TypeError("Failed to execute 'observe' on 'ResizeObserver': parameter 1 is not of type 'Element");
        }
        _ResizeObserverController__WEBPACK_IMPORTED_MODULE_0__.ResizeObserverController.observe(this, target, options);
    };
    ResizeObserver.prototype.unobserve = function (target) {
        if (arguments.length === 0) {
            throw new TypeError("Failed to execute 'unobserve' on 'ResizeObserver': 1 argument required, but only 0 present.");
        }
        if (!(0,_utils_element__WEBPACK_IMPORTED_MODULE_1__.isElement)(target)) {
            throw new TypeError("Failed to execute 'unobserve' on 'ResizeObserver': parameter 1 is not of type 'Element");
        }
        _ResizeObserverController__WEBPACK_IMPORTED_MODULE_0__.ResizeObserverController.unobserve(this, target);
    };
    ResizeObserver.prototype.disconnect = function () {
        _ResizeObserverController__WEBPACK_IMPORTED_MODULE_0__.ResizeObserverController.disconnect(this);
    };
    ResizeObserver.toString = function () {
        return 'function ResizeObserver () { [polyfill code] }';
    };
    return ResizeObserver;
}());



/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/ResizeObserverBoxOptions.js":
/*!******************************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/ResizeObserverBoxOptions.js ***!
  \******************************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   ResizeObserverBoxOptions: () => (/* binding */ ResizeObserverBoxOptions)
/* harmony export */ });
var ResizeObserverBoxOptions;
(function (ResizeObserverBoxOptions) {
    ResizeObserverBoxOptions["BORDER_BOX"] = "border-box";
    ResizeObserverBoxOptions["CONTENT_BOX"] = "content-box";
    ResizeObserverBoxOptions["DEVICE_PIXEL_CONTENT_BOX"] = "device-pixel-content-box";
})(ResizeObserverBoxOptions || (ResizeObserverBoxOptions = {}));



/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/ResizeObserverController.js":
/*!******************************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/ResizeObserverController.js ***!
  \******************************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   ResizeObserverController: () => (/* binding */ ResizeObserverController)
/* harmony export */ });
/* harmony import */ var _utils_scheduler__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./utils/scheduler */ "./node_modules/@juggle/resize-observer/lib/utils/scheduler.js");
/* harmony import */ var _ResizeObservation__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./ResizeObservation */ "./node_modules/@juggle/resize-observer/lib/ResizeObservation.js");
/* harmony import */ var _ResizeObserverDetail__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./ResizeObserverDetail */ "./node_modules/@juggle/resize-observer/lib/ResizeObserverDetail.js");
/* harmony import */ var _utils_resizeObservers__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ./utils/resizeObservers */ "./node_modules/@juggle/resize-observer/lib/utils/resizeObservers.js");




var observerMap = new WeakMap();
var getObservationIndex = function (observationTargets, target) {
    for (var i = 0; i < observationTargets.length; i += 1) {
        if (observationTargets[i].target === target) {
            return i;
        }
    }
    return -1;
};
var ResizeObserverController = (function () {
    function ResizeObserverController() {
    }
    ResizeObserverController.connect = function (resizeObserver, callback) {
        var detail = new _ResizeObserverDetail__WEBPACK_IMPORTED_MODULE_2__.ResizeObserverDetail(resizeObserver, callback);
        observerMap.set(resizeObserver, detail);
    };
    ResizeObserverController.observe = function (resizeObserver, target, options) {
        var detail = observerMap.get(resizeObserver);
        var firstObservation = detail.observationTargets.length === 0;
        if (getObservationIndex(detail.observationTargets, target) < 0) {
            firstObservation && _utils_resizeObservers__WEBPACK_IMPORTED_MODULE_3__.resizeObservers.push(detail);
            detail.observationTargets.push(new _ResizeObservation__WEBPACK_IMPORTED_MODULE_1__.ResizeObservation(target, options && options.box));
            (0,_utils_scheduler__WEBPACK_IMPORTED_MODULE_0__.updateCount)(1);
            _utils_scheduler__WEBPACK_IMPORTED_MODULE_0__.scheduler.schedule();
        }
    };
    ResizeObserverController.unobserve = function (resizeObserver, target) {
        var detail = observerMap.get(resizeObserver);
        var index = getObservationIndex(detail.observationTargets, target);
        var lastObservation = detail.observationTargets.length === 1;
        if (index >= 0) {
            lastObservation && _utils_resizeObservers__WEBPACK_IMPORTED_MODULE_3__.resizeObservers.splice(_utils_resizeObservers__WEBPACK_IMPORTED_MODULE_3__.resizeObservers.indexOf(detail), 1);
            detail.observationTargets.splice(index, 1);
            (0,_utils_scheduler__WEBPACK_IMPORTED_MODULE_0__.updateCount)(-1);
        }
    };
    ResizeObserverController.disconnect = function (resizeObserver) {
        var _this = this;
        var detail = observerMap.get(resizeObserver);
        detail.observationTargets.slice().forEach(function (ot) { return _this.unobserve(resizeObserver, ot.target); });
        detail.activeTargets.splice(0, detail.activeTargets.length);
    };
    return ResizeObserverController;
}());



/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/ResizeObserverDetail.js":
/*!**************************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/ResizeObserverDetail.js ***!
  \**************************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   ResizeObserverDetail: () => (/* binding */ ResizeObserverDetail)
/* harmony export */ });
var ResizeObserverDetail = (function () {
    function ResizeObserverDetail(resizeObserver, callback) {
        this.activeTargets = [];
        this.skippedTargets = [];
        this.observationTargets = [];
        this.observer = resizeObserver;
        this.callback = callback;
    }
    return ResizeObserverDetail;
}());



/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/ResizeObserverEntry.js":
/*!*************************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/ResizeObserverEntry.js ***!
  \*************************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   ResizeObserverEntry: () => (/* binding */ ResizeObserverEntry)
/* harmony export */ });
/* harmony import */ var _algorithms_calculateBoxSize__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./algorithms/calculateBoxSize */ "./node_modules/@juggle/resize-observer/lib/algorithms/calculateBoxSize.js");
/* harmony import */ var _utils_freeze__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./utils/freeze */ "./node_modules/@juggle/resize-observer/lib/utils/freeze.js");


var ResizeObserverEntry = (function () {
    function ResizeObserverEntry(target) {
        var boxes = (0,_algorithms_calculateBoxSize__WEBPACK_IMPORTED_MODULE_0__.calculateBoxSizes)(target);
        this.target = target;
        this.contentRect = boxes.contentRect;
        this.borderBoxSize = (0,_utils_freeze__WEBPACK_IMPORTED_MODULE_1__.freeze)([boxes.borderBoxSize]);
        this.contentBoxSize = (0,_utils_freeze__WEBPACK_IMPORTED_MODULE_1__.freeze)([boxes.contentBoxSize]);
        this.devicePixelContentBoxSize = (0,_utils_freeze__WEBPACK_IMPORTED_MODULE_1__.freeze)([boxes.devicePixelContentBoxSize]);
    }
    return ResizeObserverEntry;
}());



/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/ResizeObserverSize.js":
/*!************************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/ResizeObserverSize.js ***!
  \************************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   ResizeObserverSize: () => (/* binding */ ResizeObserverSize)
/* harmony export */ });
/* harmony import */ var _utils_freeze__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./utils/freeze */ "./node_modules/@juggle/resize-observer/lib/utils/freeze.js");

var ResizeObserverSize = (function () {
    function ResizeObserverSize(inlineSize, blockSize) {
        this.inlineSize = inlineSize;
        this.blockSize = blockSize;
        (0,_utils_freeze__WEBPACK_IMPORTED_MODULE_0__.freeze)(this);
    }
    return ResizeObserverSize;
}());



/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/algorithms/broadcastActiveObservations.js":
/*!********************************************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/algorithms/broadcastActiveObservations.js ***!
  \********************************************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   broadcastActiveObservations: () => (/* binding */ broadcastActiveObservations)
/* harmony export */ });
/* harmony import */ var _utils_resizeObservers__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../utils/resizeObservers */ "./node_modules/@juggle/resize-observer/lib/utils/resizeObservers.js");
/* harmony import */ var _ResizeObserverEntry__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../ResizeObserverEntry */ "./node_modules/@juggle/resize-observer/lib/ResizeObserverEntry.js");
/* harmony import */ var _calculateDepthForNode__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./calculateDepthForNode */ "./node_modules/@juggle/resize-observer/lib/algorithms/calculateDepthForNode.js");
/* harmony import */ var _calculateBoxSize__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ./calculateBoxSize */ "./node_modules/@juggle/resize-observer/lib/algorithms/calculateBoxSize.js");




var broadcastActiveObservations = function () {
    var shallowestDepth = Infinity;
    var callbacks = [];
    _utils_resizeObservers__WEBPACK_IMPORTED_MODULE_0__.resizeObservers.forEach(function processObserver(ro) {
        if (ro.activeTargets.length === 0) {
            return;
        }
        var entries = [];
        ro.activeTargets.forEach(function processTarget(ot) {
            var entry = new _ResizeObserverEntry__WEBPACK_IMPORTED_MODULE_1__.ResizeObserverEntry(ot.target);
            var targetDepth = (0,_calculateDepthForNode__WEBPACK_IMPORTED_MODULE_2__.calculateDepthForNode)(ot.target);
            entries.push(entry);
            ot.lastReportedSize = (0,_calculateBoxSize__WEBPACK_IMPORTED_MODULE_3__.calculateBoxSize)(ot.target, ot.observedBox);
            if (targetDepth < shallowestDepth) {
                shallowestDepth = targetDepth;
            }
        });
        callbacks.push(function resizeObserverCallback() {
            ro.callback.call(ro.observer, entries, ro.observer);
        });
        ro.activeTargets.splice(0, ro.activeTargets.length);
    });
    for (var _i = 0, callbacks_1 = callbacks; _i < callbacks_1.length; _i++) {
        var callback = callbacks_1[_i];
        callback();
    }
    return shallowestDepth;
};



/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/algorithms/calculateBoxSize.js":
/*!*********************************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/algorithms/calculateBoxSize.js ***!
  \*********************************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   calculateBoxSize: () => (/* binding */ calculateBoxSize),
/* harmony export */   calculateBoxSizes: () => (/* binding */ calculateBoxSizes)
/* harmony export */ });
/* harmony import */ var _ResizeObserverBoxOptions__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../ResizeObserverBoxOptions */ "./node_modules/@juggle/resize-observer/lib/ResizeObserverBoxOptions.js");
/* harmony import */ var _ResizeObserverSize__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../ResizeObserverSize */ "./node_modules/@juggle/resize-observer/lib/ResizeObserverSize.js");
/* harmony import */ var _DOMRectReadOnly__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../DOMRectReadOnly */ "./node_modules/@juggle/resize-observer/lib/DOMRectReadOnly.js");
/* harmony import */ var _utils_element__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ../utils/element */ "./node_modules/@juggle/resize-observer/lib/utils/element.js");
/* harmony import */ var _utils_freeze__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! ../utils/freeze */ "./node_modules/@juggle/resize-observer/lib/utils/freeze.js");
/* harmony import */ var _utils_global__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! ../utils/global */ "./node_modules/@juggle/resize-observer/lib/utils/global.js");






var cache = new WeakMap();
var scrollRegexp = /auto|scroll/;
var verticalRegexp = /^tb|vertical/;
var IE = (/msie|trident/i).test(_utils_global__WEBPACK_IMPORTED_MODULE_5__.global.navigator && _utils_global__WEBPACK_IMPORTED_MODULE_5__.global.navigator.userAgent);
var parseDimension = function (pixel) { return parseFloat(pixel || '0'); };
var size = function (inlineSize, blockSize, switchSizes) {
    if (inlineSize === void 0) { inlineSize = 0; }
    if (blockSize === void 0) { blockSize = 0; }
    if (switchSizes === void 0) { switchSizes = false; }
    return new _ResizeObserverSize__WEBPACK_IMPORTED_MODULE_1__.ResizeObserverSize((switchSizes ? blockSize : inlineSize) || 0, (switchSizes ? inlineSize : blockSize) || 0);
};
var zeroBoxes = (0,_utils_freeze__WEBPACK_IMPORTED_MODULE_4__.freeze)({
    devicePixelContentBoxSize: size(),
    borderBoxSize: size(),
    contentBoxSize: size(),
    contentRect: new _DOMRectReadOnly__WEBPACK_IMPORTED_MODULE_2__.DOMRectReadOnly(0, 0, 0, 0)
});
var calculateBoxSizes = function (target, forceRecalculation) {
    if (forceRecalculation === void 0) { forceRecalculation = false; }
    if (cache.has(target) && !forceRecalculation) {
        return cache.get(target);
    }
    if ((0,_utils_element__WEBPACK_IMPORTED_MODULE_3__.isHidden)(target)) {
        cache.set(target, zeroBoxes);
        return zeroBoxes;
    }
    var cs = getComputedStyle(target);
    var svg = (0,_utils_element__WEBPACK_IMPORTED_MODULE_3__.isSVG)(target) && target.ownerSVGElement && target.getBBox();
    var removePadding = !IE && cs.boxSizing === 'border-box';
    var switchSizes = verticalRegexp.test(cs.writingMode || '');
    var canScrollVertically = !svg && scrollRegexp.test(cs.overflowY || '');
    var canScrollHorizontally = !svg && scrollRegexp.test(cs.overflowX || '');
    var paddingTop = svg ? 0 : parseDimension(cs.paddingTop);
    var paddingRight = svg ? 0 : parseDimension(cs.paddingRight);
    var paddingBottom = svg ? 0 : parseDimension(cs.paddingBottom);
    var paddingLeft = svg ? 0 : parseDimension(cs.paddingLeft);
    var borderTop = svg ? 0 : parseDimension(cs.borderTopWidth);
    var borderRight = svg ? 0 : parseDimension(cs.borderRightWidth);
    var borderBottom = svg ? 0 : parseDimension(cs.borderBottomWidth);
    var borderLeft = svg ? 0 : parseDimension(cs.borderLeftWidth);
    var horizontalPadding = paddingLeft + paddingRight;
    var verticalPadding = paddingTop + paddingBottom;
    var horizontalBorderArea = borderLeft + borderRight;
    var verticalBorderArea = borderTop + borderBottom;
    var horizontalScrollbarThickness = !canScrollHorizontally ? 0 : target.offsetHeight - verticalBorderArea - target.clientHeight;
    var verticalScrollbarThickness = !canScrollVertically ? 0 : target.offsetWidth - horizontalBorderArea - target.clientWidth;
    var widthReduction = removePadding ? horizontalPadding + horizontalBorderArea : 0;
    var heightReduction = removePadding ? verticalPadding + verticalBorderArea : 0;
    var contentWidth = svg ? svg.width : parseDimension(cs.width) - widthReduction - verticalScrollbarThickness;
    var contentHeight = svg ? svg.height : parseDimension(cs.height) - heightReduction - horizontalScrollbarThickness;
    var borderBoxWidth = contentWidth + horizontalPadding + verticalScrollbarThickness + horizontalBorderArea;
    var borderBoxHeight = contentHeight + verticalPadding + horizontalScrollbarThickness + verticalBorderArea;
    var boxes = (0,_utils_freeze__WEBPACK_IMPORTED_MODULE_4__.freeze)({
        devicePixelContentBoxSize: size(Math.round(contentWidth * devicePixelRatio), Math.round(contentHeight * devicePixelRatio), switchSizes),
        borderBoxSize: size(borderBoxWidth, borderBoxHeight, switchSizes),
        contentBoxSize: size(contentWidth, contentHeight, switchSizes),
        contentRect: new _DOMRectReadOnly__WEBPACK_IMPORTED_MODULE_2__.DOMRectReadOnly(paddingLeft, paddingTop, contentWidth, contentHeight)
    });
    cache.set(target, boxes);
    return boxes;
};
var calculateBoxSize = function (target, observedBox, forceRecalculation) {
    var _a = calculateBoxSizes(target, forceRecalculation), borderBoxSize = _a.borderBoxSize, contentBoxSize = _a.contentBoxSize, devicePixelContentBoxSize = _a.devicePixelContentBoxSize;
    switch (observedBox) {
        case _ResizeObserverBoxOptions__WEBPACK_IMPORTED_MODULE_0__.ResizeObserverBoxOptions.DEVICE_PIXEL_CONTENT_BOX:
            return devicePixelContentBoxSize;
        case _ResizeObserverBoxOptions__WEBPACK_IMPORTED_MODULE_0__.ResizeObserverBoxOptions.BORDER_BOX:
            return borderBoxSize;
        default:
            return contentBoxSize;
    }
};



/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/algorithms/calculateDepthForNode.js":
/*!**************************************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/algorithms/calculateDepthForNode.js ***!
  \**************************************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   calculateDepthForNode: () => (/* binding */ calculateDepthForNode)
/* harmony export */ });
/* harmony import */ var _utils_element__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../utils/element */ "./node_modules/@juggle/resize-observer/lib/utils/element.js");

var calculateDepthForNode = function (node) {
    if ((0,_utils_element__WEBPACK_IMPORTED_MODULE_0__.isHidden)(node)) {
        return Infinity;
    }
    var depth = 0;
    var parent = node.parentNode;
    while (parent) {
        depth += 1;
        parent = parent.parentNode;
    }
    return depth;
};



/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/algorithms/deliverResizeLoopError.js":
/*!***************************************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/algorithms/deliverResizeLoopError.js ***!
  \***************************************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   deliverResizeLoopError: () => (/* binding */ deliverResizeLoopError)
/* harmony export */ });
var msg = 'ResizeObserver loop completed with undelivered notifications.';
var deliverResizeLoopError = function () {
    var event;
    if (typeof ErrorEvent === 'function') {
        event = new ErrorEvent('error', {
            message: msg
        });
    }
    else {
        event = document.createEvent('Event');
        event.initEvent('error', false, false);
        event.message = msg;
    }
    window.dispatchEvent(event);
};



/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/algorithms/gatherActiveObservationsAtDepth.js":
/*!************************************************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/algorithms/gatherActiveObservationsAtDepth.js ***!
  \************************************************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   gatherActiveObservationsAtDepth: () => (/* binding */ gatherActiveObservationsAtDepth)
/* harmony export */ });
/* harmony import */ var _utils_resizeObservers__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../utils/resizeObservers */ "./node_modules/@juggle/resize-observer/lib/utils/resizeObservers.js");
/* harmony import */ var _calculateDepthForNode__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./calculateDepthForNode */ "./node_modules/@juggle/resize-observer/lib/algorithms/calculateDepthForNode.js");


var gatherActiveObservationsAtDepth = function (depth) {
    _utils_resizeObservers__WEBPACK_IMPORTED_MODULE_0__.resizeObservers.forEach(function processObserver(ro) {
        ro.activeTargets.splice(0, ro.activeTargets.length);
        ro.skippedTargets.splice(0, ro.skippedTargets.length);
        ro.observationTargets.forEach(function processTarget(ot) {
            if (ot.isActive()) {
                if ((0,_calculateDepthForNode__WEBPACK_IMPORTED_MODULE_1__.calculateDepthForNode)(ot.target) > depth) {
                    ro.activeTargets.push(ot);
                }
                else {
                    ro.skippedTargets.push(ot);
                }
            }
        });
    });
};



/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/algorithms/hasActiveObservations.js":
/*!**************************************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/algorithms/hasActiveObservations.js ***!
  \**************************************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   hasActiveObservations: () => (/* binding */ hasActiveObservations)
/* harmony export */ });
/* harmony import */ var _utils_resizeObservers__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../utils/resizeObservers */ "./node_modules/@juggle/resize-observer/lib/utils/resizeObservers.js");

var hasActiveObservations = function () {
    return _utils_resizeObservers__WEBPACK_IMPORTED_MODULE_0__.resizeObservers.some(function (ro) { return ro.activeTargets.length > 0; });
};



/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/algorithms/hasSkippedObservations.js":
/*!***************************************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/algorithms/hasSkippedObservations.js ***!
  \***************************************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   hasSkippedObservations: () => (/* binding */ hasSkippedObservations)
/* harmony export */ });
/* harmony import */ var _utils_resizeObservers__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../utils/resizeObservers */ "./node_modules/@juggle/resize-observer/lib/utils/resizeObservers.js");

var hasSkippedObservations = function () {
    return _utils_resizeObservers__WEBPACK_IMPORTED_MODULE_0__.resizeObservers.some(function (ro) { return ro.skippedTargets.length > 0; });
};



/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/exports/resize-observer.js":
/*!*****************************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/exports/resize-observer.js ***!
  \*****************************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   ResizeObserver: () => (/* reexport safe */ _ResizeObserver__WEBPACK_IMPORTED_MODULE_0__.ResizeObserver),
/* harmony export */   ResizeObserverEntry: () => (/* reexport safe */ _ResizeObserverEntry__WEBPACK_IMPORTED_MODULE_1__.ResizeObserverEntry),
/* harmony export */   ResizeObserverSize: () => (/* reexport safe */ _ResizeObserverSize__WEBPACK_IMPORTED_MODULE_2__.ResizeObserverSize)
/* harmony export */ });
/* harmony import */ var _ResizeObserver__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../ResizeObserver */ "./node_modules/@juggle/resize-observer/lib/ResizeObserver.js");
/* harmony import */ var _ResizeObserverEntry__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../ResizeObserverEntry */ "./node_modules/@juggle/resize-observer/lib/ResizeObserverEntry.js");
/* harmony import */ var _ResizeObserverSize__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../ResizeObserverSize */ "./node_modules/@juggle/resize-observer/lib/ResizeObserverSize.js");





/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/utils/element.js":
/*!*******************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/utils/element.js ***!
  \*******************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   isElement: () => (/* binding */ isElement),
/* harmony export */   isHidden: () => (/* binding */ isHidden),
/* harmony export */   isReplacedElement: () => (/* binding */ isReplacedElement),
/* harmony export */   isSVG: () => (/* binding */ isSVG)
/* harmony export */ });
var isSVG = function (target) { return target instanceof SVGElement && 'getBBox' in target; };
var isHidden = function (target) {
    if (isSVG(target)) {
        var _a = target.getBBox(), width = _a.width, height = _a.height;
        return !width && !height;
    }
    var _b = target, offsetWidth = _b.offsetWidth, offsetHeight = _b.offsetHeight;
    return !(offsetWidth || offsetHeight || target.getClientRects().length);
};
var isElement = function (obj) {
    var _a;
    if (obj instanceof Element) {
        return true;
    }
    var scope = (_a = obj === null || obj === void 0 ? void 0 : obj.ownerDocument) === null || _a === void 0 ? void 0 : _a.defaultView;
    return !!(scope && obj instanceof scope.Element);
};
var isReplacedElement = function (target) {
    switch (target.tagName) {
        case 'INPUT':
            if (target.type !== 'image') {
                break;
            }
        case 'VIDEO':
        case 'AUDIO':
        case 'EMBED':
        case 'OBJECT':
        case 'CANVAS':
        case 'IFRAME':
        case 'IMG':
            return true;
    }
    return false;
};



/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/utils/freeze.js":
/*!******************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/utils/freeze.js ***!
  \******************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   freeze: () => (/* binding */ freeze)
/* harmony export */ });
var freeze = function (obj) { return Object.freeze(obj); };


/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/utils/global.js":
/*!******************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/utils/global.js ***!
  \******************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   global: () => (/* binding */ global)
/* harmony export */ });
var global = typeof window !== 'undefined' ? window : {};


/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/utils/process.js":
/*!*******************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/utils/process.js ***!
  \*******************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   process: () => (/* binding */ process)
/* harmony export */ });
/* harmony import */ var _algorithms_hasActiveObservations__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../algorithms/hasActiveObservations */ "./node_modules/@juggle/resize-observer/lib/algorithms/hasActiveObservations.js");
/* harmony import */ var _algorithms_hasSkippedObservations__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../algorithms/hasSkippedObservations */ "./node_modules/@juggle/resize-observer/lib/algorithms/hasSkippedObservations.js");
/* harmony import */ var _algorithms_deliverResizeLoopError__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ../algorithms/deliverResizeLoopError */ "./node_modules/@juggle/resize-observer/lib/algorithms/deliverResizeLoopError.js");
/* harmony import */ var _algorithms_broadcastActiveObservations__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ../algorithms/broadcastActiveObservations */ "./node_modules/@juggle/resize-observer/lib/algorithms/broadcastActiveObservations.js");
/* harmony import */ var _algorithms_gatherActiveObservationsAtDepth__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! ../algorithms/gatherActiveObservationsAtDepth */ "./node_modules/@juggle/resize-observer/lib/algorithms/gatherActiveObservationsAtDepth.js");





var process = function () {
    var depth = 0;
    (0,_algorithms_gatherActiveObservationsAtDepth__WEBPACK_IMPORTED_MODULE_4__.gatherActiveObservationsAtDepth)(depth);
    while ((0,_algorithms_hasActiveObservations__WEBPACK_IMPORTED_MODULE_0__.hasActiveObservations)()) {
        depth = (0,_algorithms_broadcastActiveObservations__WEBPACK_IMPORTED_MODULE_3__.broadcastActiveObservations)();
        (0,_algorithms_gatherActiveObservationsAtDepth__WEBPACK_IMPORTED_MODULE_4__.gatherActiveObservationsAtDepth)(depth);
    }
    if ((0,_algorithms_hasSkippedObservations__WEBPACK_IMPORTED_MODULE_1__.hasSkippedObservations)()) {
        (0,_algorithms_deliverResizeLoopError__WEBPACK_IMPORTED_MODULE_2__.deliverResizeLoopError)();
    }
    return depth > 0;
};



/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/utils/queueMicroTask.js":
/*!**************************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/utils/queueMicroTask.js ***!
  \**************************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   queueMicroTask: () => (/* binding */ queueMicroTask)
/* harmony export */ });
var trigger;
var callbacks = [];
var notify = function () { return callbacks.splice(0).forEach(function (cb) { return cb(); }); };
var queueMicroTask = function (callback) {
    if (!trigger) {
        var toggle_1 = 0;
        var el_1 = document.createTextNode('');
        var config = { characterData: true };
        new MutationObserver(function () { return notify(); }).observe(el_1, config);
        trigger = function () { el_1.textContent = "".concat(toggle_1 ? toggle_1-- : toggle_1++); };
    }
    callbacks.push(callback);
    trigger();
};



/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/utils/queueResizeObserver.js":
/*!*******************************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/utils/queueResizeObserver.js ***!
  \*******************************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   queueResizeObserver: () => (/* binding */ queueResizeObserver)
/* harmony export */ });
/* harmony import */ var _queueMicroTask__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./queueMicroTask */ "./node_modules/@juggle/resize-observer/lib/utils/queueMicroTask.js");

var queueResizeObserver = function (cb) {
    (0,_queueMicroTask__WEBPACK_IMPORTED_MODULE_0__.queueMicroTask)(function ResizeObserver() {
        requestAnimationFrame(cb);
    });
};



/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/utils/resizeObservers.js":
/*!***************************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/utils/resizeObservers.js ***!
  \***************************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   resizeObservers: () => (/* binding */ resizeObservers)
/* harmony export */ });
var resizeObservers = [];



/***/ }),

/***/ "./node_modules/@juggle/resize-observer/lib/utils/scheduler.js":
/*!*********************************************************************!*\
  !*** ./node_modules/@juggle/resize-observer/lib/utils/scheduler.js ***!
  \*********************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   scheduler: () => (/* binding */ scheduler),
/* harmony export */   updateCount: () => (/* binding */ updateCount)
/* harmony export */ });
/* harmony import */ var _process__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./process */ "./node_modules/@juggle/resize-observer/lib/utils/process.js");
/* harmony import */ var _global__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./global */ "./node_modules/@juggle/resize-observer/lib/utils/global.js");
/* harmony import */ var _queueResizeObserver__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./queueResizeObserver */ "./node_modules/@juggle/resize-observer/lib/utils/queueResizeObserver.js");



var watching = 0;
var isWatching = function () { return !!watching; };
var CATCH_PERIOD = 250;
var observerConfig = { attributes: true, characterData: true, childList: true, subtree: true };
var events = [
    'resize',
    'load',
    'transitionend',
    'animationend',
    'animationstart',
    'animationiteration',
    'keyup',
    'keydown',
    'mouseup',
    'mousedown',
    'mouseover',
    'mouseout',
    'blur',
    'focus'
];
var time = function (timeout) {
    if (timeout === void 0) { timeout = 0; }
    return Date.now() + timeout;
};
var scheduled = false;
var Scheduler = (function () {
    function Scheduler() {
        var _this = this;
        this.stopped = true;
        this.listener = function () { return _this.schedule(); };
    }
    Scheduler.prototype.run = function (timeout) {
        var _this = this;
        if (timeout === void 0) { timeout = CATCH_PERIOD; }
        if (scheduled) {
            return;
        }
        scheduled = true;
        var until = time(timeout);
        (0,_queueResizeObserver__WEBPACK_IMPORTED_MODULE_2__.queueResizeObserver)(function () {
            var elementsHaveResized = false;
            try {
                elementsHaveResized = (0,_process__WEBPACK_IMPORTED_MODULE_0__.process)();
            }
            finally {
                scheduled = false;
                timeout = until - time();
                if (!isWatching()) {
                    return;
                }
                if (elementsHaveResized) {
                    _this.run(1000);
                }
                else if (timeout > 0) {
                    _this.run(timeout);
                }
                else {
                    _this.start();
                }
            }
        });
    };
    Scheduler.prototype.schedule = function () {
        this.stop();
        this.run();
    };
    Scheduler.prototype.observe = function () {
        var _this = this;
        var cb = function () { return _this.observer && _this.observer.observe(document.body, observerConfig); };
        document.body ? cb() : _global__WEBPACK_IMPORTED_MODULE_1__.global.addEventListener('DOMContentLoaded', cb);
    };
    Scheduler.prototype.start = function () {
        var _this = this;
        if (this.stopped) {
            this.stopped = false;
            this.observer = new MutationObserver(this.listener);
            this.observe();
            events.forEach(function (name) { return _global__WEBPACK_IMPORTED_MODULE_1__.global.addEventListener(name, _this.listener, true); });
        }
    };
    Scheduler.prototype.stop = function () {
        var _this = this;
        if (!this.stopped) {
            this.observer && this.observer.disconnect();
            events.forEach(function (name) { return _global__WEBPACK_IMPORTED_MODULE_1__.global.removeEventListener(name, _this.listener, true); });
            this.stopped = true;
        }
    };
    return Scheduler;
}());
var scheduler = new Scheduler();
var updateCount = function (n) {
    !watching && n > 0 && scheduler.start();
    watching += n;
    !watching && scheduler.stop();
};



/***/ }),

/***/ "./node_modules/approx-string-match/dist/index.js":
/*!********************************************************!*\
  !*** ./node_modules/approx-string-match/dist/index.js ***!
  \********************************************************/
/***/ ((__unused_webpack_module, exports) => {

"use strict";

/**
 * Implementation of Myers' online approximate string matching algorithm [1],
 * with additional optimizations suggested by [2].
 *
 * This has O((k/w) * n) complexity where `n` is the length of the text, `k` is
 * the maximum number of errors allowed (always <= the pattern length) and `w`
 * is the word size. Because JS only supports bitwise operations on 32 bit
 * integers, `w` is 32.
 *
 * As far as I am aware, there aren't any online algorithms which are
 * significantly better for a wide range of input parameters. The problem can be
 * solved faster using "filter then verify" approaches which first filter out
 * regions of the text that cannot match using a "cheap" check and then verify
 * the remaining potential matches. The verify step requires an algorithm such
 * as this one however.
 *
 * The algorithm's approach is essentially to optimize the classic dynamic
 * programming solution to the problem by computing columns of the matrix in
 * word-sized chunks (ie. dealing with 32 chars of the pattern at a time) and
 * avoiding calculating regions of the matrix where the minimum error count is
 * guaranteed to exceed the input threshold.
 *
 * The paper consists of two parts, the first describes the core algorithm for
 * matching patterns <= the size of a word (implemented by `advanceBlock` here).
 * The second uses the core algorithm as part of a larger block-based algorithm
 * to handle longer patterns.
 *
 * [1] G. Myers, “A Fast Bit-Vector Algorithm for Approximate String Matching
 * Based on Dynamic Programming,” vol. 46, no. 3, pp. 395–415, 1999.
 *
 * [2] Šošić, M. (2014). An simd dynamic programming c/c++ library (Doctoral
 * dissertation, Fakultet Elektrotehnike i računarstva, Sveučilište u Zagrebu).
 */
Object.defineProperty(exports, "__esModule", ({ value: true }));
function reverse(s) {
    return s
        .split("")
        .reverse()
        .join("");
}
/**
 * Given the ends of approximate matches for `pattern` in `text`, find
 * the start of the matches.
 *
 * @param findEndFn - Function for finding the end of matches in
 * text.
 * @return Matches with the `start` property set.
 */
function findMatchStarts(text, pattern, matches) {
    var patRev = reverse(pattern);
    return matches.map(function (m) {
        // Find start of each match by reversing the pattern and matching segment
        // of text and searching for an approx match with the same number of
        // errors.
        var minStart = Math.max(0, m.end - pattern.length - m.errors);
        var textRev = reverse(text.slice(minStart, m.end));
        // If there are multiple possible start points, choose the one that
        // maximizes the length of the match.
        var start = findMatchEnds(textRev, patRev, m.errors).reduce(function (min, rm) {
            if (m.end - rm.end < min) {
                return m.end - rm.end;
            }
            return min;
        }, m.end);
        return {
            start: start,
            end: m.end,
            errors: m.errors
        };
    });
}
/**
 * Return 1 if a number is non-zero or zero otherwise, without using
 * conditional operators.
 *
 * This should get inlined into `advanceBlock` below by the JIT.
 *
 * Adapted from https://stackoverflow.com/a/3912218/434243
 */
function oneIfNotZero(n) {
    return ((n | -n) >> 31) & 1;
}
/**
 * Block calculation step of the algorithm.
 *
 * From Fig 8. on p. 408 of [1], additionally optimized to replace conditional
 * checks with bitwise operations as per Section 4.2.3 of [2].
 *
 * @param ctx - The pattern context object
 * @param peq - The `peq` array for the current character (`ctx.peq.get(ch)`)
 * @param b - The block level
 * @param hIn - Horizontal input delta ∈ {1,0,-1}
 * @return Horizontal output delta ∈ {1,0,-1}
 */
function advanceBlock(ctx, peq, b, hIn) {
    var pV = ctx.P[b];
    var mV = ctx.M[b];
    var hInIsNegative = hIn >>> 31; // 1 if hIn < 0 or 0 otherwise.
    var eq = peq[b] | hInIsNegative;
    // Step 1: Compute horizontal deltas.
    var xV = eq | mV;
    var xH = (((eq & pV) + pV) ^ pV) | eq;
    var pH = mV | ~(xH | pV);
    var mH = pV & xH;
    // Step 2: Update score (value of last row of this block).
    var hOut = oneIfNotZero(pH & ctx.lastRowMask[b]) -
        oneIfNotZero(mH & ctx.lastRowMask[b]);
    // Step 3: Update vertical deltas for use when processing next char.
    pH <<= 1;
    mH <<= 1;
    mH |= hInIsNegative;
    pH |= oneIfNotZero(hIn) - hInIsNegative; // set pH[0] if hIn > 0
    pV = mH | ~(xV | pH);
    mV = pH & xV;
    ctx.P[b] = pV;
    ctx.M[b] = mV;
    return hOut;
}
/**
 * Find the ends and error counts for matches of `pattern` in `text`.
 *
 * Only the matches with the lowest error count are reported. Other matches
 * with error counts <= maxErrors are discarded.
 *
 * This is the block-based search algorithm from Fig. 9 on p.410 of [1].
 */
function findMatchEnds(text, pattern, maxErrors) {
    if (pattern.length === 0) {
        return [];
    }
    // Clamp error count so we can rely on the `maxErrors` and `pattern.length`
    // rows being in the same block below.
    maxErrors = Math.min(maxErrors, pattern.length);
    var matches = [];
    // Word size.
    var w = 32;
    // Index of maximum block level.
    var bMax = Math.ceil(pattern.length / w) - 1;
    // Context used across block calculations.
    var ctx = {
        P: new Uint32Array(bMax + 1),
        M: new Uint32Array(bMax + 1),
        lastRowMask: new Uint32Array(bMax + 1)
    };
    ctx.lastRowMask.fill(1 << 31);
    ctx.lastRowMask[bMax] = 1 << (pattern.length - 1) % w;
    // Dummy "peq" array for chars in the text which do not occur in the pattern.
    var emptyPeq = new Uint32Array(bMax + 1);
    // Map of UTF-16 character code to bit vector indicating positions in the
    // pattern that equal that character.
    var peq = new Map();
    // Version of `peq` that only stores mappings for small characters. This
    // allows faster lookups when iterating through the text because a simple
    // array lookup can be done instead of a hash table lookup.
    var asciiPeq = [];
    for (var i = 0; i < 256; i++) {
        asciiPeq.push(emptyPeq);
    }
    // Calculate `ctx.peq` - a map of character values to bitmasks indicating
    // positions of that character within the pattern, where each bit represents
    // a position in the pattern.
    for (var c = 0; c < pattern.length; c += 1) {
        var val = pattern.charCodeAt(c);
        if (peq.has(val)) {
            // Duplicate char in pattern.
            continue;
        }
        var charPeq = new Uint32Array(bMax + 1);
        peq.set(val, charPeq);
        if (val < asciiPeq.length) {
            asciiPeq[val] = charPeq;
        }
        for (var b = 0; b <= bMax; b += 1) {
            charPeq[b] = 0;
            // Set all the bits where the pattern matches the current char (ch).
            // For indexes beyond the end of the pattern, always set the bit as if the
            // pattern contained a wildcard char in that position.
            for (var r = 0; r < w; r += 1) {
                var idx = b * w + r;
                if (idx >= pattern.length) {
                    continue;
                }
                var match = pattern.charCodeAt(idx) === val;
                if (match) {
                    charPeq[b] |= 1 << r;
                }
            }
        }
    }
    // Index of last-active block level in the column.
    var y = Math.max(0, Math.ceil(maxErrors / w) - 1);
    // Initialize maximum error count at bottom of each block.
    var score = new Uint32Array(bMax + 1);
    for (var b = 0; b <= y; b += 1) {
        score[b] = (b + 1) * w;
    }
    score[bMax] = pattern.length;
    // Initialize vertical deltas for each block.
    for (var b = 0; b <= y; b += 1) {
        ctx.P[b] = ~0;
        ctx.M[b] = 0;
    }
    // Process each char of the text, computing the error count for `w` chars of
    // the pattern at a time.
    for (var j = 0; j < text.length; j += 1) {
        // Lookup the bitmask representing the positions of the current char from
        // the text within the pattern.
        var charCode = text.charCodeAt(j);
        var charPeq = void 0;
        if (charCode < asciiPeq.length) {
            // Fast array lookup.
            charPeq = asciiPeq[charCode];
        }
        else {
            // Slower hash table lookup.
            charPeq = peq.get(charCode);
            if (typeof charPeq === "undefined") {
                charPeq = emptyPeq;
            }
        }
        // Calculate error count for blocks that we definitely have to process for
        // this column.
        var carry = 0;
        for (var b = 0; b <= y; b += 1) {
            carry = advanceBlock(ctx, charPeq, b, carry);
            score[b] += carry;
        }
        // Check if we also need to compute an additional block, or if we can reduce
        // the number of blocks processed for the next column.
        if (score[y] - carry <= maxErrors &&
            y < bMax &&
            (charPeq[y + 1] & 1 || carry < 0)) {
            // Error count for bottom block is under threshold, increase the number of
            // blocks processed for this column & next by 1.
            y += 1;
            ctx.P[y] = ~0;
            ctx.M[y] = 0;
            var maxBlockScore = y === bMax ? pattern.length % w : w;
            score[y] =
                score[y - 1] +
                    maxBlockScore -
                    carry +
                    advanceBlock(ctx, charPeq, y, carry);
        }
        else {
            // Error count for bottom block exceeds threshold, reduce the number of
            // blocks processed for the next column.
            while (y > 0 && score[y] >= maxErrors + w) {
                y -= 1;
            }
        }
        // If error count is under threshold, report a match.
        if (y === bMax && score[y] <= maxErrors) {
            if (score[y] < maxErrors) {
                // Discard any earlier, worse matches.
                matches.splice(0, matches.length);
            }
            matches.push({
                start: -1,
                end: j + 1,
                errors: score[y]
            });
            // Because `search` only reports the matches with the lowest error count,
            // we can "ratchet down" the max error threshold whenever a match is
            // encountered and thereby save a small amount of work for the remainder
            // of the text.
            maxErrors = score[y];
        }
    }
    return matches;
}
/**
 * Search for matches for `pattern` in `text` allowing up to `maxErrors` errors.
 *
 * Returns the start, and end positions and error counts for each lowest-cost
 * match. Only the "best" matches are returned.
 */
function search(text, pattern, maxErrors) {
    var matches = findMatchEnds(text, pattern, maxErrors);
    return findMatchStarts(text, pattern, matches);
}
exports["default"] = search;


/***/ }),

/***/ "./src/decorator.js":
/*!**************************!*\
  !*** ./src/decorator.js ***!
  \**************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   DecorationGroup: () => (/* binding */ DecorationGroup),
/* harmony export */   getDecorations: () => (/* binding */ getDecorations),
/* harmony export */   handleDecorationClickEvent: () => (/* binding */ handleDecorationClickEvent),
/* harmony export */   registerTemplates: () => (/* binding */ registerTemplates)
/* harmony export */ });
/* harmony import */ var _rect__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./rect */ "./src/rect.js");
/* harmony import */ var _utils__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./utils */ "./src/utils.js");
/* harmony import */ var _juggle_resize_observer__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! @juggle/resize-observer */ "./node_modules/@juggle/resize-observer/lib/exports/resize-observer.js");
//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//




// Polyfill for iOS 13.3

const ResizeObserver = window.ResizeObserver || _juggle_resize_observer__WEBPACK_IMPORTED_MODULE_2__.ResizeObserver;
let styles = new Map();
let groups = new Map();
var lastGroupId = 0;

/**
 * Registers a list of additional supported Decoration Templates.
 *
 * Each template object is indexed by the style ID.
 */
function registerTemplates(newStyles) {
  var stylesheet = "";
  for (const [id, style] of Object.entries(newStyles)) {
    styles.set(id, style);
    if (style.stylesheet) {
      stylesheet += style.stylesheet + "\n";
    }
  }
  if (stylesheet) {
    let styleElement = document.createElement("style");
    styleElement.innerHTML = stylesheet;
    document.getElementsByTagName("head")[0].appendChild(styleElement);
  }
}

/**
 * Returns an instance of DecorationGroup for the given group name.
 */
function getDecorations(groupName) {
  var group = groups.get(groupName);
  if (!group) {
    let id = "r2-decoration-" + lastGroupId++;
    group = DecorationGroup(id, groupName);
    groups.set(groupName, group);
  }
  return group;
}

/**
 * Handles click events on a Decoration.
 * Returns whether a decoration matched this event.
 */
function handleDecorationClickEvent(event, clickEvent) {
  if (groups.size === 0) {
    return false;
  }
  function findTarget() {
    for (const [group, groupContent] of groups) {
      if (!groupContent.isActivable()) {
        continue;
      }
      for (const item of groupContent.items.reverse()) {
        if (!item.clickableElements) {
          continue;
        }
        for (const element of item.clickableElements) {
          let rect = element.getBoundingClientRect().toJSON();
          if ((0,_rect__WEBPACK_IMPORTED_MODULE_0__.rectContainsPoint)(rect, event.clientX, event.clientY, 1)) {
            return {
              group,
              item,
              element,
              rect
            };
          }
        }
      }
    }
  }
  let target = findTarget();
  if (!target) {
    return false;
  }
  webkit.messageHandlers.decorationActivated.postMessage({
    id: target.item.decoration.id,
    group: target.group,
    rect: (0,_rect__WEBPACK_IMPORTED_MODULE_0__.toNativeRect)(target.item.range.getBoundingClientRect()),
    click: clickEvent
  });
  return true;
}

/**
 * Creates a DecorationGroup object from a unique HTML ID and its name.
 */
function DecorationGroup(groupId, groupName) {
  var items = [];
  var lastItemId = 0;
  var container = null;
  var activable = false;
  function isActivable() {
    return activable;
  }
  function setActivable() {
    activable = true;
  }

  /**
   * Adds a new decoration to the group.
   */
  function add(decoration) {
    let id = groupId + "-" + lastItemId++;
    let range = (0,_utils__WEBPACK_IMPORTED_MODULE_1__.rangeFromLocator)(decoration.locator);
    if (!range) {
      (0,_utils__WEBPACK_IMPORTED_MODULE_1__.log)("Can't locate DOM range for decoration", decoration);
      return;
    }
    let item = {
      id,
      decoration,
      range
    };
    items.push(item);
    layout(item);
  }

  /**
   * Removes the decoration with given ID from the group.
   */
  function remove(decorationId) {
    let index = items.findIndex(i => i.decoration.id === decorationId);
    if (index === -1) {
      return;
    }
    let item = items[index];
    items.splice(index, 1);
    item.clickableElements = null;
    if (item.container) {
      item.container.remove();
      item.container = null;
    }
  }

  /**
   * Notifies that the given decoration was modified and needs to be updated.
   */
  function update(decoration) {
    remove(decoration.id);
    add(decoration);
  }

  /**
   * Removes all decorations from this group.
   */
  function clear() {
    clearContainer();
    items.length = 0;
  }

  /**
   * Recreates the decoration elements.
   *
   * To be called after reflowing the resource, for example.
   */
  function requestLayout() {
    clearContainer();
    items.forEach(item => layout(item));
  }

  /**
   * Layouts a single Decoration item.
   */
  function layout(item) {
    let groupContainer = requireContainer();
    let style = styles.get(item.decoration.style);
    if (!style) {
      (0,_utils__WEBPACK_IMPORTED_MODULE_1__.logErrorMessage)("Unknown decoration style: ".concat(item.decoration.style));
      return;
    }
    let itemContainer = document.createElement("div");
    itemContainer.setAttribute("id", item.id);
    itemContainer.setAttribute("data-style", item.decoration.style);
    itemContainer.style.setProperty("pointer-events", "none");
    let viewportWidth = window.innerWidth;
    let columnCount = parseInt(getComputedStyle(document.documentElement).getPropertyValue("column-count"));
    let pageWidth = viewportWidth / (columnCount || 1);
    let scrollingElement = document.scrollingElement;
    let xOffset = scrollingElement.scrollLeft;
    let yOffset = scrollingElement.scrollTop;
    function positionElement(element, rect, boundingRect) {
      element.style.position = "absolute";
      if (style.width === "wrap") {
        element.style.width = "".concat(rect.width, "px");
        element.style.height = "".concat(rect.height, "px");
        element.style.left = "".concat(rect.left + xOffset, "px");
        element.style.top = "".concat(rect.top + yOffset, "px");
      } else if (style.width === "viewport") {
        element.style.width = "".concat(viewportWidth, "px");
        element.style.height = "".concat(rect.height, "px");
        let left = Math.floor(rect.left / viewportWidth) * viewportWidth;
        element.style.left = "".concat(left + xOffset, "px");
        element.style.top = "".concat(rect.top + yOffset, "px");
      } else if (style.width === "bounds") {
        element.style.width = "".concat(boundingRect.width, "px");
        element.style.height = "".concat(rect.height, "px");
        element.style.left = "".concat(boundingRect.left + xOffset, "px");
        element.style.top = "".concat(rect.top + yOffset, "px");
      } else if (style.width === "page") {
        element.style.width = "".concat(pageWidth, "px");
        element.style.height = "".concat(rect.height, "px");
        let left = Math.floor(rect.left / pageWidth) * pageWidth;
        element.style.left = "".concat(left + xOffset, "px");
        element.style.top = "".concat(rect.top + yOffset, "px");
      }
    }
    let boundingRect = item.range.getBoundingClientRect();
    let elementTemplate;
    try {
      let template = document.createElement("template");
      template.innerHTML = item.decoration.element.trim();
      elementTemplate = template.content.firstElementChild;
    } catch (error) {
      (0,_utils__WEBPACK_IMPORTED_MODULE_1__.logErrorMessage)("Invalid decoration element \"".concat(item.decoration.element, "\": ").concat(error.message));
      return;
    }
    if (style.layout === "boxes") {
      let doNotMergeHorizontallyAlignedRects = true;
      let clientRects = (0,_rect__WEBPACK_IMPORTED_MODULE_0__.getClientRectsNoOverlap)(item.range, doNotMergeHorizontallyAlignedRects);
      clientRects = clientRects.sort((r1, r2) => {
        if (r1.top < r2.top) {
          return -1;
        } else if (r1.top > r2.top) {
          return 1;
        } else {
          return 0;
        }
      });
      for (let clientRect of clientRects) {
        const line = elementTemplate.cloneNode(true);
        line.style.setProperty("pointer-events", "none");
        positionElement(line, clientRect, boundingRect);
        itemContainer.append(line);
      }
    } else if (style.layout === "bounds") {
      const bounds = elementTemplate.cloneNode(true);
      bounds.style.setProperty("pointer-events", "none");
      positionElement(bounds, boundingRect, boundingRect);
      itemContainer.append(bounds);
    }
    groupContainer.append(itemContainer);
    item.container = itemContainer;
    item.clickableElements = Array.from(itemContainer.querySelectorAll("[data-activable='1']"));
    if (item.clickableElements.length === 0) {
      item.clickableElements = Array.from(itemContainer.children);
    }
  }

  /**
   * Returns the group container element, after making sure it exists.
   */
  function requireContainer() {
    if (!container) {
      container = document.createElement("div");
      container.setAttribute("id", groupId);
      container.setAttribute("data-group", groupName);
      container.style.setProperty("pointer-events", "none");
      requestAnimationFrame(function () {
        if (container != null) {
          document.body.append(container);
        }
      });
    }
    return container;
  }

  /**
   * Removes the group container.
   */
  function clearContainer() {
    if (container) {
      container.remove();
      container = null;
    }
  }
  return {
    add,
    remove,
    update,
    clear,
    items,
    requestLayout,
    isActivable,
    setActivable
  };
}
window.addEventListener("load", function () {
  // Will relayout all the decorations when the document body is resized.
  const body = document.body;
  var lastSize = {
    width: 0,
    height: 0
  };
  const observer = new ResizeObserver(() => {
    if (lastSize.width === body.clientWidth && lastSize.height === body.clientHeight) {
      return;
    }
    lastSize = {
      width: body.clientWidth,
      height: body.clientHeight
    };
    groups.forEach(function (group) {
      group.requestLayout();
    });
  });
  observer.observe(body);
}, false);

/***/ }),

/***/ "./src/dom.js":
/*!********************!*\
  !*** ./src/dom.js ***!
  \********************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   findFirstVisibleLocator: () => (/* binding */ findFirstVisibleLocator),
/* harmony export */   findNearestInteractiveElement: () => (/* binding */ findNearestInteractiveElement)
/* harmony export */ });
/* harmony import */ var _utils__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./utils */ "./src/utils.js");
/* harmony import */ var css_selector_generator__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! css-selector-generator */ "./node_modules/css-selector-generator/esm/index.js");
//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//




// Returns `element` or its first parent that is considered "user interactive".
// For example a link, a video clip or a text field.
//
// See. https://github.com/JayPanoz/architecture/tree/touch-handling/misc/touch-handling
function findNearestInteractiveElement(element) {
  if (element == null) {
    return null;
  }
  var interactiveTags = ["a", "audio", "button", "canvas", "details", "input", "label", "option", "select", "submit", "textarea", "video"];
  if (interactiveTags.indexOf(element.nodeName.toLowerCase()) !== -1) {
    return element.outerHTML;
  }

  // Checks whether the element is editable by the user.
  if (element.hasAttribute("contenteditable") && element.getAttribute("contenteditable").toLowerCase() != "false") {
    return element.outerHTML;
  }

  // Checks parents recursively because the touch might be for example on an <em> inside a <a>.
  if (element.parentElement) {
    return findNearestInteractiveElement(element.parentElement);
  }
  return null;
}

/// Returns the `Locator` object to the first block element that is visible on
/// the screen.
function findFirstVisibleLocator() {
  const element = findElement(document.body);
  return {
    href: "#",
    type: "application/xhtml+xml",
    locations: {
      cssSelector: (0,css_selector_generator__WEBPACK_IMPORTED_MODULE_1__.getCssSelector)(element)
    },
    text: {
      highlight: element.textContent
    }
  };
}
function findElement(rootElement) {
  for (var i = 0; i < rootElement.children.length; i++) {
    const child = rootElement.children[i];
    if (!shouldIgnoreElement(child) && isElementVisible(child)) {
      return findElement(child);
    }
  }
  return rootElement;
}
function isElementVisible(element) {
  if (readium.isFixedLayout) return true;
  if (element === document.body || element === document.documentElement) {
    return true;
  }
  if (!document || !document.documentElement || !document.body) {
    return false;
  }
  const rect = element.getBoundingClientRect();
  if ((0,_utils__WEBPACK_IMPORTED_MODULE_0__.isScrollModeEnabled)()) {
    return rect.bottom > 0 && rect.top < window.innerHeight;
  } else {
    return rect.right > 0 && rect.left < window.innerWidth;
  }
}
function shouldIgnoreElement(element) {
  const elStyle = getComputedStyle(element);
  if (elStyle) {
    const display = elStyle.getPropertyValue("display");
    if (display != "block") {
      return true;
    }
    // Cannot be relied upon, because web browser engine reports invisible when out of view in
    // scrolled columns!
    // const visibility = elStyle.getPropertyValue("visibility");
    // if (visibility === "hidden") {
    //     return false;
    // }
    const opacity = elStyle.getPropertyValue("opacity");
    if (opacity === "0") {
      return true;
    }
  }
  return false;
}

/***/ }),

/***/ "./src/gestures.js":
/*!*************************!*\
  !*** ./src/gestures.js ***!
  \*************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony import */ var _decorator__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./decorator */ "./src/decorator.js");
/* harmony import */ var _rect__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./rect */ "./src/rect.js");
/* harmony import */ var _dom__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./dom */ "./src/dom.js");
//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//




window.addEventListener("DOMContentLoaded", function () {
  // If we don't set the CSS cursor property to pointer, then the click events are not triggered pre-iOS 13.
  document.body.style.cursor = "pointer";
  document.addEventListener("click", onClick, false);
});
function onClick(event) {
  if (!getSelection().isCollapsed) {
    // There's an on-going selection, the tap will dismiss it so we don't forward it.
    return;
  }
  let point = (0,_rect__WEBPACK_IMPORTED_MODULE_1__.adjustPointToViewport)({
    x: event.clientX,
    y: event.clientY
  });
  let clickEvent = {
    defaultPrevented: event.defaultPrevented,
    x: point.x,
    y: point.y,
    targetElement: event.target.outerHTML,
    interactiveElement: (0,_dom__WEBPACK_IMPORTED_MODULE_2__.findNearestInteractiveElement)(event.target)
  };
  if ((0,_decorator__WEBPACK_IMPORTED_MODULE_0__.handleDecorationClickEvent)(event, clickEvent)) {
    return;
  }

  // Send the tap data over the JS bridge even if it's been handled
  // within the webview, so that it can be preserved and used
  // by the WKNavigationDelegate if needed.
  webkit.messageHandlers.tap.postMessage(clickEvent);

  // We don't want to disable the default WebView behavior as it breaks some features without bringing any value.
  // event.stopPropagation();
  // event.preventDefault();
}

/***/ }),

/***/ "./src/index.js":
/*!**********************!*\
  !*** ./src/index.js ***!
  \**********************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony import */ var _gestures__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./gestures */ "./src/gestures.js");
/* harmony import */ var _keyboard__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./keyboard */ "./src/keyboard.js");
/* harmony import */ var _dom__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./dom */ "./src/dom.js");
/* harmony import */ var _utils__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ./utils */ "./src/utils.js");
/* harmony import */ var _decorator__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! ./decorator */ "./src/decorator.js");
//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

// Base script used by both reflowable and fixed layout resources.







// Public API used by the navigator.
__webpack_require__.g.readium = {
  // utils
  scrollToId: _utils__WEBPACK_IMPORTED_MODULE_3__.scrollToId,
  scrollToPosition: _utils__WEBPACK_IMPORTED_MODULE_3__.scrollToPosition,
  scrollToText: _utils__WEBPACK_IMPORTED_MODULE_3__.scrollToText,
  scrollLeft: _utils__WEBPACK_IMPORTED_MODULE_3__.scrollLeft,
  scrollRight: _utils__WEBPACK_IMPORTED_MODULE_3__.scrollRight,
  setCSSProperties: _utils__WEBPACK_IMPORTED_MODULE_3__.setCSSProperties,
  setProperty: _utils__WEBPACK_IMPORTED_MODULE_3__.setProperty,
  removeProperty: _utils__WEBPACK_IMPORTED_MODULE_3__.removeProperty,
  // decoration
  registerDecorationTemplates: _decorator__WEBPACK_IMPORTED_MODULE_4__.registerTemplates,
  getDecorations: _decorator__WEBPACK_IMPORTED_MODULE_4__.getDecorations,
  // DOM
  findFirstVisibleLocator: _dom__WEBPACK_IMPORTED_MODULE_2__.findFirstVisibleLocator
};

/***/ }),

/***/ "./src/keyboard.js":
/*!*************************!*\
  !*** ./src/keyboard.js ***!
  \*************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony import */ var _dom__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./dom */ "./src/dom.js");
//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//


window.addEventListener("keydown", event => {
  if (shouldIgnoreEvent(event)) {
    return;
  }
  preventDefault(event);
  sendPressKeyMessage(event, "keydown");
});
window.addEventListener("keyup", event => {
  if (shouldIgnoreEvent(event)) {
    return;
  }
  preventDefault(event);
  sendPressKeyMessage(event, "keyup");
});
function shouldIgnoreEvent(event) {
  return event.defaultPrevented || (0,_dom__WEBPACK_IMPORTED_MODULE_0__.findNearestInteractiveElement)(document.activeElement) != null;
}

// We prevent the default behavior for keyboard events, otherwise the web view
// might scroll.
function preventDefault(event) {
  event.stopPropagation();
  event.preventDefault();
}
function sendPressKeyMessage(event, keyType) {
  if (event.repeat) return;
  webkit.messageHandlers.pressKey.postMessage({
    type: keyType,
    code: event.code,
    // We use a deprecated `keyCode` property, because the value of `event.key`
    // changes depending on which modifier is pressed, while `event.code` shows
    // the key code of the physical keyboard key, ignoring the virtual layout.
    key: String.fromCharCode(event.keyCode),
    option: event.altKey,
    control: event.ctrlKey,
    shift: event.shiftKey,
    command: event.metaKey
  });
}

/***/ }),

/***/ "./src/rect.js":
/*!*********************!*\
  !*** ./src/rect.js ***!
  \*********************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   adjustPointToViewport: () => (/* binding */ adjustPointToViewport),
/* harmony export */   getClientRectsNoOverlap: () => (/* binding */ getClientRectsNoOverlap),
/* harmony export */   rectContainsPoint: () => (/* binding */ rectContainsPoint),
/* harmony export */   toNativeRect: () => (/* binding */ toNativeRect)
/* harmony export */ });
/* harmony import */ var _utils__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./utils */ "./src/utils.js");
//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//


const debug = false;

/**
 * Converts a DOMRect into a JSON object understandable by the native side.
 */
function toNativeRect(rect) {
  let point = adjustPointToViewport({
    x: rect.left,
    y: rect.top
  });
  const width = rect.width;
  const height = rect.height;
  const left = point.x;
  const top = point.y;
  const right = left + width;
  const bottom = top + height;
  return {
    width,
    height,
    left,
    top,
    right,
    bottom
  };
}

/**
 * Adjusts the given coordinates to the viewport for FXL resources.
 */
function adjustPointToViewport(point) {
  if (!frameElement) {
    return point;
  }
  let frameRect = frameElement.getBoundingClientRect();
  if (!frameRect) {
    return point;
  }
  let topScrollingElement = window.top.document.documentElement;
  return {
    x: point.x + frameRect.x + topScrollingElement.scrollLeft,
    y: point.y + frameRect.y + topScrollingElement.scrollTop
  };
}
function getClientRectsNoOverlap(range, doNotMergeHorizontallyAlignedRects) {
  let clientRects = range.getClientRects();
  const tolerance = 1;
  const originalRects = [];
  for (const rangeClientRect of clientRects) {
    originalRects.push({
      bottom: rangeClientRect.bottom,
      height: rangeClientRect.height,
      left: rangeClientRect.left,
      right: rangeClientRect.right,
      top: rangeClientRect.top,
      width: rangeClientRect.width
    });
  }
  const mergedRects = mergeTouchingRects(originalRects, tolerance, doNotMergeHorizontallyAlignedRects);
  const noContainedRects = removeContainedRects(mergedRects, tolerance);
  const newRects = replaceOverlapingRects(noContainedRects);
  const minArea = 2 * 2;
  for (let j = newRects.length - 1; j >= 0; j--) {
    const rect = newRects[j];
    const bigEnough = rect.width * rect.height > minArea;
    if (!bigEnough) {
      if (newRects.length > 1) {
        log("CLIENT RECT: remove small");
        newRects.splice(j, 1);
      } else {
        log("CLIENT RECT: remove small, but keep otherwise empty!");
        break;
      }
    }
  }
  log("CLIENT RECT: reduced ".concat(originalRects.length, " --> ").concat(newRects.length));
  return newRects;
}
function mergeTouchingRects(rects, tolerance, doNotMergeHorizontallyAlignedRects) {
  for (let i = 0; i < rects.length; i++) {
    for (let j = i + 1; j < rects.length; j++) {
      const rect1 = rects[i];
      const rect2 = rects[j];
      if (rect1 === rect2) {
        log("mergeTouchingRects rect1 === rect2 ??!");
        continue;
      }
      const rectsLineUpVertically = almostEqual(rect1.top, rect2.top, tolerance) && almostEqual(rect1.bottom, rect2.bottom, tolerance);
      const rectsLineUpHorizontally = almostEqual(rect1.left, rect2.left, tolerance) && almostEqual(rect1.right, rect2.right, tolerance);
      const horizontalAllowed = !doNotMergeHorizontallyAlignedRects;
      const aligned = rectsLineUpHorizontally && horizontalAllowed || rectsLineUpVertically && !rectsLineUpHorizontally;
      const canMerge = aligned && rectsTouchOrOverlap(rect1, rect2, tolerance);
      if (canMerge) {
        log("CLIENT RECT: merging two into one, VERTICAL: ".concat(rectsLineUpVertically, " HORIZONTAL: ").concat(rectsLineUpHorizontally, " (").concat(doNotMergeHorizontallyAlignedRects, ")"));
        const newRects = rects.filter(rect => {
          return rect !== rect1 && rect !== rect2;
        });
        const replacementClientRect = getBoundingRect(rect1, rect2);
        newRects.push(replacementClientRect);
        return mergeTouchingRects(newRects, tolerance, doNotMergeHorizontallyAlignedRects);
      }
    }
  }
  return rects;
}
function getBoundingRect(rect1, rect2) {
  const left = Math.min(rect1.left, rect2.left);
  const right = Math.max(rect1.right, rect2.right);
  const top = Math.min(rect1.top, rect2.top);
  const bottom = Math.max(rect1.bottom, rect2.bottom);
  return {
    bottom,
    height: bottom - top,
    left,
    right,
    top,
    width: right - left
  };
}
function removeContainedRects(rects, tolerance) {
  const rectsToKeep = new Set(rects);
  for (const rect of rects) {
    const bigEnough = rect.width > 1 && rect.height > 1;
    if (!bigEnough) {
      log("CLIENT RECT: remove tiny");
      rectsToKeep.delete(rect);
      continue;
    }
    for (const possiblyContainingRect of rects) {
      if (rect === possiblyContainingRect) {
        continue;
      }
      if (!rectsToKeep.has(possiblyContainingRect)) {
        continue;
      }
      if (rectContains(possiblyContainingRect, rect, tolerance)) {
        log("CLIENT RECT: remove contained");
        rectsToKeep.delete(rect);
        break;
      }
    }
  }
  return Array.from(rectsToKeep);
}
function rectContains(rect1, rect2, tolerance) {
  return rectContainsPoint(rect1, rect2.left, rect2.top, tolerance) && rectContainsPoint(rect1, rect2.right, rect2.top, tolerance) && rectContainsPoint(rect1, rect2.left, rect2.bottom, tolerance) && rectContainsPoint(rect1, rect2.right, rect2.bottom, tolerance);
}
function rectContainsPoint(rect, x, y, tolerance) {
  return (rect.left < x || almostEqual(rect.left, x, tolerance)) && (rect.right > x || almostEqual(rect.right, x, tolerance)) && (rect.top < y || almostEqual(rect.top, y, tolerance)) && (rect.bottom > y || almostEqual(rect.bottom, y, tolerance));
}
function replaceOverlapingRects(rects) {
  for (let i = 0; i < rects.length; i++) {
    for (let j = i + 1; j < rects.length; j++) {
      const rect1 = rects[i];
      const rect2 = rects[j];
      if (rect1 === rect2) {
        log("replaceOverlapingRects rect1 === rect2 ??!");
        continue;
      }
      if (rectsTouchOrOverlap(rect1, rect2, -1)) {
        let toAdd = [];
        let toRemove;
        const subtractRects1 = rectSubtract(rect1, rect2);
        if (subtractRects1.length === 1) {
          toAdd = subtractRects1;
          toRemove = rect1;
        } else {
          const subtractRects2 = rectSubtract(rect2, rect1);
          if (subtractRects1.length < subtractRects2.length) {
            toAdd = subtractRects1;
            toRemove = rect1;
          } else {
            toAdd = subtractRects2;
            toRemove = rect2;
          }
        }
        log("CLIENT RECT: overlap, cut one rect into ".concat(toAdd.length));
        const newRects = rects.filter(rect => {
          return rect !== toRemove;
        });
        Array.prototype.push.apply(newRects, toAdd);
        return replaceOverlapingRects(newRects);
      }
    }
  }
  return rects;
}
function rectSubtract(rect1, rect2) {
  const rectIntersected = rectIntersect(rect2, rect1);
  if (rectIntersected.height === 0 || rectIntersected.width === 0) {
    return [rect1];
  }
  const rects = [];
  {
    const rectA = {
      bottom: rect1.bottom,
      height: 0,
      left: rect1.left,
      right: rectIntersected.left,
      top: rect1.top,
      width: 0
    };
    rectA.width = rectA.right - rectA.left;
    rectA.height = rectA.bottom - rectA.top;
    if (rectA.height !== 0 && rectA.width !== 0) {
      rects.push(rectA);
    }
  }
  {
    const rectB = {
      bottom: rectIntersected.top,
      height: 0,
      left: rectIntersected.left,
      right: rectIntersected.right,
      top: rect1.top,
      width: 0
    };
    rectB.width = rectB.right - rectB.left;
    rectB.height = rectB.bottom - rectB.top;
    if (rectB.height !== 0 && rectB.width !== 0) {
      rects.push(rectB);
    }
  }
  {
    const rectC = {
      bottom: rect1.bottom,
      height: 0,
      left: rectIntersected.left,
      right: rectIntersected.right,
      top: rectIntersected.bottom,
      width: 0
    };
    rectC.width = rectC.right - rectC.left;
    rectC.height = rectC.bottom - rectC.top;
    if (rectC.height !== 0 && rectC.width !== 0) {
      rects.push(rectC);
    }
  }
  {
    const rectD = {
      bottom: rect1.bottom,
      height: 0,
      left: rectIntersected.right,
      right: rect1.right,
      top: rect1.top,
      width: 0
    };
    rectD.width = rectD.right - rectD.left;
    rectD.height = rectD.bottom - rectD.top;
    if (rectD.height !== 0 && rectD.width !== 0) {
      rects.push(rectD);
    }
  }
  return rects;
}
function rectIntersect(rect1, rect2) {
  const maxLeft = Math.max(rect1.left, rect2.left);
  const minRight = Math.min(rect1.right, rect2.right);
  const maxTop = Math.max(rect1.top, rect2.top);
  const minBottom = Math.min(rect1.bottom, rect2.bottom);
  return {
    bottom: minBottom,
    height: Math.max(0, minBottom - maxTop),
    left: maxLeft,
    right: minRight,
    top: maxTop,
    width: Math.max(0, minRight - maxLeft)
  };
}
function rectsTouchOrOverlap(rect1, rect2, tolerance) {
  return (rect1.left < rect2.right || tolerance >= 0 && almostEqual(rect1.left, rect2.right, tolerance)) && (rect2.left < rect1.right || tolerance >= 0 && almostEqual(rect2.left, rect1.right, tolerance)) && (rect1.top < rect2.bottom || tolerance >= 0 && almostEqual(rect1.top, rect2.bottom, tolerance)) && (rect2.top < rect1.bottom || tolerance >= 0 && almostEqual(rect2.top, rect1.bottom, tolerance));
}
function almostEqual(a, b, tolerance) {
  return Math.abs(a - b) <= tolerance;
}
function log() {
  if (debug) {
    _utils__WEBPACK_IMPORTED_MODULE_0__.log.apply(null, arguments);
  }
}

/***/ }),

/***/ "./src/selection.js":
/*!**************************!*\
  !*** ./src/selection.js ***!
  \**************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   convertRangeInfo: () => (/* binding */ convertRangeInfo),
/* harmony export */   getCurrentSelection: () => (/* binding */ getCurrentSelection),
/* harmony export */   location2RangeInfo: () => (/* binding */ location2RangeInfo)
/* harmony export */ });
/* harmony import */ var _utils__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./utils */ "./src/utils.js");
/* harmony import */ var _rect__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./rect */ "./src/rect.js");
/* harmony import */ var _vendor_hypothesis_anchoring_text_range__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./vendor/hypothesis/anchoring/text-range */ "./src/vendor/hypothesis/anchoring/text-range.js");
/* harmony import */ var string_prototype_matchall__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! string.prototype.matchall */ "./node_modules/string.prototype.matchall/index.js");
/* harmony import */ var string_prototype_matchall__WEBPACK_IMPORTED_MODULE_3___default = /*#__PURE__*/__webpack_require__.n(string_prototype_matchall__WEBPACK_IMPORTED_MODULE_3__);
//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//





// Polyfill for iOS 12

string_prototype_matchall__WEBPACK_IMPORTED_MODULE_3___default().shim();
const debug = true;
function getCurrentSelection() {
  if (!readium.link) {
    return null;
  }
  const href = readium.link.href;
  if (!href) {
    return null;
  }
  const text = getCurrentSelectionText();
  if (!text) {
    return null;
  }
  const rect = getSelectionRect();
  return {
    href,
    text,
    rect
  };
}
function getSelectionRect() {
  try {
    let sel = window.getSelection();
    if (!sel) {
      return;
    }
    let range = sel.getRangeAt(0);
    return (0,_rect__WEBPACK_IMPORTED_MODULE_1__.toNativeRect)(range.getBoundingClientRect());
  } catch (e) {
    (0,_utils__WEBPACK_IMPORTED_MODULE_0__.logError)(e);
    return null;
  }
}
function getCurrentSelectionText() {
  const selection = window.getSelection();
  if (!selection) {
    return undefined;
  }
  if (selection.isCollapsed) {
    return undefined;
  }
  const highlight = selection.toString();
  const cleanHighlight = highlight.trim().replace(/\n/g, " ").replace(/\s\s+/g, " ");
  if (cleanHighlight.length === 0) {
    return undefined;
  }
  if (!selection.anchorNode || !selection.focusNode) {
    return undefined;
  }
  const range = selection.rangeCount === 1 ? selection.getRangeAt(0) : createOrderedRange(selection.anchorNode, selection.anchorOffset, selection.focusNode, selection.focusOffset);
  if (!range || range.collapsed) {
    log("$$$$$$$$$$$$$$$$$ CANNOT GET NON-COLLAPSED SELECTION RANGE?!");
    return undefined;
  }
  const text = document.body.textContent;
  const textRange = _vendor_hypothesis_anchoring_text_range__WEBPACK_IMPORTED_MODULE_2__.TextRange.fromRange(range).relativeTo(document.body);
  const start = textRange.start.offset;
  const end = textRange.end.offset;
  const snippetLength = 200;

  // Compute the text before the highlight, ignoring the first "word", which might be cut.
  let before = text.slice(Math.max(0, start - snippetLength), start);
  let firstWordStart = before.search(/(?:[\0-@\[-`\{-\xA9\xAB-\xB4\xB6-\xB9\xBB-\xBF\xD7\xF7\u02C2-\u02C5\u02D2-\u02DF\u02E5-\u02EB\u02ED\u02EF-\u036F\u0375\u0378\u0379\u037E\u0380-\u0385\u0387\u038B\u038D\u03A2\u03F6\u0482-\u0489\u0530\u0557\u0558\u055A-\u055F\u0589-\u05CF\u05EB-\u05EE\u05F3-\u061F\u064B-\u066D\u0670\u06D4\u06D6-\u06E4\u06E7-\u06ED\u06F0-\u06F9\u06FD\u06FE\u0700-\u070F\u0711\u0730-\u074C\u07A6-\u07B0\u07B2-\u07C9\u07EB-\u07F3\u07F6-\u07F9\u07FB-\u07FF\u0816-\u0819\u081B-\u0823\u0825-\u0827\u0829-\u083F\u0859-\u085F\u086B-\u086F\u0888\u088F-\u089F\u08CA-\u0903\u093A-\u093C\u093E-\u094F\u0951-\u0957\u0962-\u0970\u0981-\u0984\u098D\u098E\u0991\u0992\u09A9\u09B1\u09B3-\u09B5\u09BA-\u09BC\u09BE-\u09CD\u09CF-\u09DB\u09DE\u09E2-\u09EF\u09F2-\u09FB\u09FD-\u0A04\u0A0B-\u0A0E\u0A11\u0A12\u0A29\u0A31\u0A34\u0A37\u0A3A-\u0A58\u0A5D\u0A5F-\u0A71\u0A75-\u0A84\u0A8E\u0A92\u0AA9\u0AB1\u0AB4\u0ABA-\u0ABC\u0ABE-\u0ACF\u0AD1-\u0ADF\u0AE2-\u0AF8\u0AFA-\u0B04\u0B0D\u0B0E\u0B11\u0B12\u0B29\u0B31\u0B34\u0B3A-\u0B3C\u0B3E-\u0B5B\u0B5E\u0B62-\u0B70\u0B72-\u0B82\u0B84\u0B8B-\u0B8D\u0B91\u0B96-\u0B98\u0B9B\u0B9D\u0BA0-\u0BA2\u0BA5-\u0BA7\u0BAB-\u0BAD\u0BBA-\u0BCF\u0BD1-\u0C04\u0C0D\u0C11\u0C29\u0C3A-\u0C3C\u0C3E-\u0C57\u0C5B\u0C5C\u0C5E\u0C5F\u0C62-\u0C7F\u0C81-\u0C84\u0C8D\u0C91\u0CA9\u0CB4\u0CBA-\u0CBC\u0CBE-\u0CDC\u0CDF\u0CE2-\u0CF0\u0CF3-\u0D03\u0D0D\u0D11\u0D3B\u0D3C\u0D3E-\u0D4D\u0D4F-\u0D53\u0D57-\u0D5E\u0D62-\u0D79\u0D80-\u0D84\u0D97-\u0D99\u0DB2\u0DBC\u0DBE\u0DBF\u0DC7-\u0E00\u0E31\u0E34-\u0E3F\u0E47-\u0E80\u0E83\u0E85\u0E8B\u0EA4\u0EA6\u0EB1\u0EB4-\u0EBC\u0EBE\u0EBF\u0EC5\u0EC7-\u0EDB\u0EE0-\u0EFF\u0F01-\u0F3F\u0F48\u0F6D-\u0F87\u0F8D-\u0FFF\u102B-\u103E\u1040-\u104F\u1056-\u1059\u105E-\u1060\u1062-\u1064\u1067-\u106D\u1071-\u1074\u1082-\u108D\u108F-\u109F\u10C6\u10C8-\u10CC\u10CE\u10CF\u10FB\u1249\u124E\u124F\u1257\u1259\u125E\u125F\u1289\u128E\u128F\u12B1\u12B6\u12B7\u12BF\u12C1\u12C6\u12C7\u12D7\u1311\u1316\u1317\u135B-\u137F\u1390-\u139F\u13F6\u13F7\u13FE-\u1400\u166D\u166E\u1680\u169B-\u169F\u16EB-\u16F0\u16F9-\u16FF\u1712-\u171E\u1732-\u173F\u1752-\u175F\u176D\u1771-\u177F\u17B4-\u17D6\u17D8-\u17DB\u17DD-\u181F\u1879-\u187F\u1885\u1886\u18A9\u18AB-\u18AF\u18F6-\u18FF\u191F-\u194F\u196E\u196F\u1975-\u197F\u19AC-\u19AF\u19CA-\u19FF\u1A17-\u1A1F\u1A55-\u1AA6\u1AA8-\u1B04\u1B34-\u1B44\u1B4D-\u1B82\u1BA1-\u1BAD\u1BB0-\u1BB9\u1BE6-\u1BFF\u1C24-\u1C4C\u1C50-\u1C59\u1C7E\u1C7F\u1C89-\u1C8F\u1CBB\u1CBC\u1CC0-\u1CE8\u1CED\u1CF4\u1CF7-\u1CF9\u1CFB-\u1CFF\u1DC0-\u1DFF\u1F16\u1F17\u1F1E\u1F1F\u1F46\u1F47\u1F4E\u1F4F\u1F58\u1F5A\u1F5C\u1F5E\u1F7E\u1F7F\u1FB5\u1FBD\u1FBF-\u1FC1\u1FC5\u1FCD-\u1FCF\u1FD4\u1FD5\u1FDC-\u1FDF\u1FED-\u1FF1\u1FF5\u1FFD-\u2070\u2072-\u207E\u2080-\u208F\u209D-\u2101\u2103-\u2106\u2108\u2109\u2114\u2116-\u2118\u211E-\u2123\u2125\u2127\u2129\u212E\u213A\u213B\u2140-\u2144\u214A-\u214D\u214F-\u2182\u2185-\u2BFF\u2CE5-\u2CEA\u2CEF-\u2CF1\u2CF4-\u2CFF\u2D26\u2D28-\u2D2C\u2D2E\u2D2F\u2D68-\u2D6E\u2D70-\u2D7F\u2D97-\u2D9F\u2DA7\u2DAF\u2DB7\u2DBF\u2DC7\u2DCF\u2DD7\u2DDF-\u2E2E\u2E30-\u3004\u3007-\u3030\u3036-\u303A\u303D-\u3040\u3097-\u309C\u30A0\u30FB\u3100-\u3104\u3130\u318F-\u319F\u31C0-\u31EF\u3200-\u33FF\u4DC0-\u4DFF\uA48D-\uA4CF\uA4FE\uA4FF\uA60D-\uA60F\uA620-\uA629\uA62C-\uA63F\uA66F-\uA67E\uA69E\uA69F\uA6E6-\uA716\uA720\uA721\uA789\uA78A\uA7CB-\uA7CF\uA7D2\uA7D4\uA7DA-\uA7F1\uA802\uA806\uA80B\uA823-\uA83F\uA874-\uA881\uA8B4-\uA8F1\uA8F8-\uA8FA\uA8FC\uA8FF-\uA909\uA926-\uA92F\uA947-\uA95F\uA97D-\uA983\uA9B3-\uA9CE\uA9D0-\uA9DF\uA9E5\uA9F0-\uA9F9\uA9FF\uAA29-\uAA3F\uAA43\uAA4C-\uAA5F\uAA77-\uAA79\uAA7B-\uAA7D\uAAB0\uAAB2-\uAAB4\uAAB7\uAAB8\uAABE\uAABF\uAAC1\uAAC3-\uAADA\uAADE\uAADF\uAAEB-\uAAF1\uAAF5-\uAB00\uAB07\uAB08\uAB0F\uAB10\uAB17-\uAB1F\uAB27\uAB2F\uAB5B\uAB6A-\uAB6F\uABE3-\uABFF\uD7A4-\uD7AF\uD7C7-\uD7CA\uD7FC-\uD7FF\uE000-\uF8FF\uFA6E\uFA6F\uFADA-\uFAFF\uFB07-\uFB12\uFB18-\uFB1C\uFB1E\uFB29\uFB37\uFB3D\uFB3F\uFB42\uFB45\uFBB2-\uFBD2\uFD3E-\uFD4F\uFD90\uFD91\uFDC8-\uFDEF\uFDFC-\uFE6F\uFE75\uFEFD-\uFF20\uFF3B-\uFF40\uFF5B-\uFF65\uFFBF-\uFFC1\uFFC8\uFFC9\uFFD0\uFFD1\uFFD8\uFFD9\uFFDD-\uFFFF]|\uD800[\uDC0C\uDC27\uDC3B\uDC3E\uDC4E\uDC4F\uDC5E-\uDC7F\uDCFB-\uDE7F\uDE9D-\uDE9F\uDED1-\uDEFF\uDF20-\uDF2C\uDF41\uDF4A-\uDF4F\uDF76-\uDF7F\uDF9E\uDF9F\uDFC4-\uDFC7\uDFD0-\uDFFF]|\uD801[\uDC9E-\uDCAF\uDCD4-\uDCD7\uDCFC-\uDCFF\uDD28-\uDD2F\uDD64-\uDD6F\uDD7B\uDD8B\uDD93\uDD96\uDDA2\uDDB2\uDDBA\uDDBD-\uDDFF\uDF37-\uDF3F\uDF56-\uDF5F\uDF68-\uDF7F\uDF86\uDFB1\uDFBB-\uDFFF]|\uD802[\uDC06\uDC07\uDC09\uDC36\uDC39-\uDC3B\uDC3D\uDC3E\uDC56-\uDC5F\uDC77-\uDC7F\uDC9F-\uDCDF\uDCF3\uDCF6-\uDCFF\uDD16-\uDD1F\uDD3A-\uDD7F\uDDB8-\uDDBD\uDDC0-\uDDFF\uDE01-\uDE0F\uDE14\uDE18\uDE36-\uDE5F\uDE7D-\uDE7F\uDE9D-\uDEBF\uDEC8\uDEE5-\uDEFF\uDF36-\uDF3F\uDF56-\uDF5F\uDF73-\uDF7F\uDF92-\uDFFF]|\uD803[\uDC49-\uDC7F\uDCB3-\uDCBF\uDCF3-\uDCFF\uDD24-\uDE7F\uDEAA-\uDEAF\uDEB2-\uDEFF\uDF1D-\uDF26\uDF28-\uDF2F\uDF46-\uDF6F\uDF82-\uDFAF\uDFC5-\uDFDF\uDFF7-\uDFFF]|\uD804[\uDC00-\uDC02\uDC38-\uDC70\uDC73\uDC74\uDC76-\uDC82\uDCB0-\uDCCF\uDCE9-\uDD02\uDD27-\uDD43\uDD45\uDD46\uDD48-\uDD4F\uDD73-\uDD75\uDD77-\uDD82\uDDB3-\uDDC0\uDDC5-\uDDD9\uDDDB\uDDDD-\uDDFF\uDE12\uDE2C-\uDE3E\uDE41-\uDE7F\uDE87\uDE89\uDE8E\uDE9E\uDEA9-\uDEAF\uDEDF-\uDF04\uDF0D\uDF0E\uDF11\uDF12\uDF29\uDF31\uDF34\uDF3A-\uDF3C\uDF3E-\uDF4F\uDF51-\uDF5C\uDF62-\uDFFF]|\uD805[\uDC35-\uDC46\uDC4B-\uDC5E\uDC62-\uDC7F\uDCB0-\uDCC3\uDCC6\uDCC8-\uDD7F\uDDAF-\uDDD7\uDDDC-\uDDFF\uDE30-\uDE43\uDE45-\uDE7F\uDEAB-\uDEB7\uDEB9-\uDEFF\uDF1B-\uDF3F\uDF47-\uDFFF]|\uD806[\uDC2C-\uDC9F\uDCE0-\uDCFE\uDD07\uDD08\uDD0A\uDD0B\uDD14\uDD17\uDD30-\uDD3E\uDD40\uDD42-\uDD9F\uDDA8\uDDA9\uDDD1-\uDDE0\uDDE2\uDDE4-\uDDFF\uDE01-\uDE0A\uDE33-\uDE39\uDE3B-\uDE4F\uDE51-\uDE5B\uDE8A-\uDE9C\uDE9E-\uDEAF\uDEF9-\uDFFF]|\uD807[\uDC09\uDC2F-\uDC3F\uDC41-\uDC71\uDC90-\uDCFF\uDD07\uDD0A\uDD31-\uDD45\uDD47-\uDD5F\uDD66\uDD69\uDD8A-\uDD97\uDD99-\uDEDF\uDEF3-\uDF01\uDF03\uDF11\uDF34-\uDFAF\uDFB1-\uDFFF]|\uD808[\uDF9A-\uDFFF]|\uD809[\uDC00-\uDC7F\uDD44-\uDFFF]|[\uD80A\uD80E-\uD810\uD812-\uD819\uD824-\uD82A\uD82D\uD82E\uD830-\uD834\uD836\uD83C-\uD83F\uD87C\uD87D\uD87F\uD889-\uDBFF][\uDC00-\uDFFF]|\uD80B[\uDC00-\uDF8F\uDFF1-\uDFFF]|\uD80D[\uDC30-\uDC40\uDC47-\uDFFF]|\uD811[\uDE47-\uDFFF]|\uD81A[\uDE39-\uDE3F\uDE5F-\uDE6F\uDEBF-\uDECF\uDEEE-\uDEFF\uDF30-\uDF3F\uDF44-\uDF62\uDF78-\uDF7C\uDF90-\uDFFF]|\uD81B[\uDC00-\uDE3F\uDE80-\uDEFF\uDF4B-\uDF4F\uDF51-\uDF92\uDFA0-\uDFDF\uDFE2\uDFE4-\uDFFF]|\uD821[\uDFF8-\uDFFF]|\uD823[\uDCD6-\uDCFF\uDD09-\uDFFF]|\uD82B[\uDC00-\uDFEF\uDFF4\uDFFC\uDFFF]|\uD82C[\uDD23-\uDD31\uDD33-\uDD4F\uDD53\uDD54\uDD56-\uDD63\uDD68-\uDD6F\uDEFC-\uDFFF]|\uD82F[\uDC6B-\uDC6F\uDC7D-\uDC7F\uDC89-\uDC8F\uDC9A-\uDFFF]|\uD835[\uDC55\uDC9D\uDCA0\uDCA1\uDCA3\uDCA4\uDCA7\uDCA8\uDCAD\uDCBA\uDCBC\uDCC4\uDD06\uDD0B\uDD0C\uDD15\uDD1D\uDD3A\uDD3F\uDD45\uDD47-\uDD49\uDD51\uDEA6\uDEA7\uDEC1\uDEDB\uDEFB\uDF15\uDF35\uDF4F\uDF6F\uDF89\uDFA9\uDFC3\uDFCC-\uDFFF]|\uD837[\uDC00-\uDEFF\uDF1F-\uDF24\uDF2B-\uDFFF]|\uD838[\uDC00-\uDC2F\uDC6E-\uDCFF\uDD2D-\uDD36\uDD3E-\uDD4D\uDD4F-\uDE8F\uDEAE-\uDEBF\uDEEC-\uDFFF]|\uD839[\uDC00-\uDCCF\uDCEC-\uDFDF\uDFE7\uDFEC\uDFEF\uDFFF]|\uD83A[\uDCC5-\uDCFF\uDD44-\uDD4A\uDD4C-\uDFFF]|\uD83B[\uDC00-\uDDFF\uDE04\uDE20\uDE23\uDE25\uDE26\uDE28\uDE33\uDE38\uDE3A\uDE3C-\uDE41\uDE43-\uDE46\uDE48\uDE4A\uDE4C\uDE50\uDE53\uDE55\uDE56\uDE58\uDE5A\uDE5C\uDE5E\uDE60\uDE63\uDE65\uDE66\uDE6B\uDE73\uDE78\uDE7D\uDE7F\uDE8A\uDE9C-\uDEA0\uDEA4\uDEAA\uDEBC-\uDFFF]|\uD869[\uDEE0-\uDEFF]|\uD86D[\uDF3A-\uDF3F]|\uD86E[\uDC1E\uDC1F]|\uD873[\uDEA2-\uDEAF]|\uD87A[\uDFE1-\uDFEF]|\uD87B[\uDE5E-\uDFFF]|\uD87E[\uDE1E-\uDFFF]|\uD884[\uDF4B-\uDF4F]|\uD888[\uDFB0-\uDFFF]|[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?:[^\uD800-\uDBFF]|^)[\uDC00-\uDFFF])(?:[A-Za-z\xAA\xB5\xBA\xC0-\xD6\xD8-\xF6\xF8-\u02C1\u02C6-\u02D1\u02E0-\u02E4\u02EC\u02EE\u0370-\u0374\u0376\u0377\u037A-\u037D\u037F\u0386\u0388-\u038A\u038C\u038E-\u03A1\u03A3-\u03F5\u03F7-\u0481\u048A-\u052F\u0531-\u0556\u0559\u0560-\u0588\u05D0-\u05EA\u05EF-\u05F2\u0620-\u064A\u066E\u066F\u0671-\u06D3\u06D5\u06E5\u06E6\u06EE\u06EF\u06FA-\u06FC\u06FF\u0710\u0712-\u072F\u074D-\u07A5\u07B1\u07CA-\u07EA\u07F4\u07F5\u07FA\u0800-\u0815\u081A\u0824\u0828\u0840-\u0858\u0860-\u086A\u0870-\u0887\u0889-\u088E\u08A0-\u08C9\u0904-\u0939\u093D\u0950\u0958-\u0961\u0971-\u0980\u0985-\u098C\u098F\u0990\u0993-\u09A8\u09AA-\u09B0\u09B2\u09B6-\u09B9\u09BD\u09CE\u09DC\u09DD\u09DF-\u09E1\u09F0\u09F1\u09FC\u0A05-\u0A0A\u0A0F\u0A10\u0A13-\u0A28\u0A2A-\u0A30\u0A32\u0A33\u0A35\u0A36\u0A38\u0A39\u0A59-\u0A5C\u0A5E\u0A72-\u0A74\u0A85-\u0A8D\u0A8F-\u0A91\u0A93-\u0AA8\u0AAA-\u0AB0\u0AB2\u0AB3\u0AB5-\u0AB9\u0ABD\u0AD0\u0AE0\u0AE1\u0AF9\u0B05-\u0B0C\u0B0F\u0B10\u0B13-\u0B28\u0B2A-\u0B30\u0B32\u0B33\u0B35-\u0B39\u0B3D\u0B5C\u0B5D\u0B5F-\u0B61\u0B71\u0B83\u0B85-\u0B8A\u0B8E-\u0B90\u0B92-\u0B95\u0B99\u0B9A\u0B9C\u0B9E\u0B9F\u0BA3\u0BA4\u0BA8-\u0BAA\u0BAE-\u0BB9\u0BD0\u0C05-\u0C0C\u0C0E-\u0C10\u0C12-\u0C28\u0C2A-\u0C39\u0C3D\u0C58-\u0C5A\u0C5D\u0C60\u0C61\u0C80\u0C85-\u0C8C\u0C8E-\u0C90\u0C92-\u0CA8\u0CAA-\u0CB3\u0CB5-\u0CB9\u0CBD\u0CDD\u0CDE\u0CE0\u0CE1\u0CF1\u0CF2\u0D04-\u0D0C\u0D0E-\u0D10\u0D12-\u0D3A\u0D3D\u0D4E\u0D54-\u0D56\u0D5F-\u0D61\u0D7A-\u0D7F\u0D85-\u0D96\u0D9A-\u0DB1\u0DB3-\u0DBB\u0DBD\u0DC0-\u0DC6\u0E01-\u0E30\u0E32\u0E33\u0E40-\u0E46\u0E81\u0E82\u0E84\u0E86-\u0E8A\u0E8C-\u0EA3\u0EA5\u0EA7-\u0EB0\u0EB2\u0EB3\u0EBD\u0EC0-\u0EC4\u0EC6\u0EDC-\u0EDF\u0F00\u0F40-\u0F47\u0F49-\u0F6C\u0F88-\u0F8C\u1000-\u102A\u103F\u1050-\u1055\u105A-\u105D\u1061\u1065\u1066\u106E-\u1070\u1075-\u1081\u108E\u10A0-\u10C5\u10C7\u10CD\u10D0-\u10FA\u10FC-\u1248\u124A-\u124D\u1250-\u1256\u1258\u125A-\u125D\u1260-\u1288\u128A-\u128D\u1290-\u12B0\u12B2-\u12B5\u12B8-\u12BE\u12C0\u12C2-\u12C5\u12C8-\u12D6\u12D8-\u1310\u1312-\u1315\u1318-\u135A\u1380-\u138F\u13A0-\u13F5\u13F8-\u13FD\u1401-\u166C\u166F-\u167F\u1681-\u169A\u16A0-\u16EA\u16F1-\u16F8\u1700-\u1711\u171F-\u1731\u1740-\u1751\u1760-\u176C\u176E-\u1770\u1780-\u17B3\u17D7\u17DC\u1820-\u1878\u1880-\u1884\u1887-\u18A8\u18AA\u18B0-\u18F5\u1900-\u191E\u1950-\u196D\u1970-\u1974\u1980-\u19AB\u19B0-\u19C9\u1A00-\u1A16\u1A20-\u1A54\u1AA7\u1B05-\u1B33\u1B45-\u1B4C\u1B83-\u1BA0\u1BAE\u1BAF\u1BBA-\u1BE5\u1C00-\u1C23\u1C4D-\u1C4F\u1C5A-\u1C7D\u1C80-\u1C88\u1C90-\u1CBA\u1CBD-\u1CBF\u1CE9-\u1CEC\u1CEE-\u1CF3\u1CF5\u1CF6\u1CFA\u1D00-\u1DBF\u1E00-\u1F15\u1F18-\u1F1D\u1F20-\u1F45\u1F48-\u1F4D\u1F50-\u1F57\u1F59\u1F5B\u1F5D\u1F5F-\u1F7D\u1F80-\u1FB4\u1FB6-\u1FBC\u1FBE\u1FC2-\u1FC4\u1FC6-\u1FCC\u1FD0-\u1FD3\u1FD6-\u1FDB\u1FE0-\u1FEC\u1FF2-\u1FF4\u1FF6-\u1FFC\u2071\u207F\u2090-\u209C\u2102\u2107\u210A-\u2113\u2115\u2119-\u211D\u2124\u2126\u2128\u212A-\u212D\u212F-\u2139\u213C-\u213F\u2145-\u2149\u214E\u2183\u2184\u2C00-\u2CE4\u2CEB-\u2CEE\u2CF2\u2CF3\u2D00-\u2D25\u2D27\u2D2D\u2D30-\u2D67\u2D6F\u2D80-\u2D96\u2DA0-\u2DA6\u2DA8-\u2DAE\u2DB0-\u2DB6\u2DB8-\u2DBE\u2DC0-\u2DC6\u2DC8-\u2DCE\u2DD0-\u2DD6\u2DD8-\u2DDE\u2E2F\u3005\u3006\u3031-\u3035\u303B\u303C\u3041-\u3096\u309D-\u309F\u30A1-\u30FA\u30FC-\u30FF\u3105-\u312F\u3131-\u318E\u31A0-\u31BF\u31F0-\u31FF\u3400-\u4DBF\u4E00-\uA48C\uA4D0-\uA4FD\uA500-\uA60C\uA610-\uA61F\uA62A\uA62B\uA640-\uA66E\uA67F-\uA69D\uA6A0-\uA6E5\uA717-\uA71F\uA722-\uA788\uA78B-\uA7CA\uA7D0\uA7D1\uA7D3\uA7D5-\uA7D9\uA7F2-\uA801\uA803-\uA805\uA807-\uA80A\uA80C-\uA822\uA840-\uA873\uA882-\uA8B3\uA8F2-\uA8F7\uA8FB\uA8FD\uA8FE\uA90A-\uA925\uA930-\uA946\uA960-\uA97C\uA984-\uA9B2\uA9CF\uA9E0-\uA9E4\uA9E6-\uA9EF\uA9FA-\uA9FE\uAA00-\uAA28\uAA40-\uAA42\uAA44-\uAA4B\uAA60-\uAA76\uAA7A\uAA7E-\uAAAF\uAAB1\uAAB5\uAAB6\uAAB9-\uAABD\uAAC0\uAAC2\uAADB-\uAADD\uAAE0-\uAAEA\uAAF2-\uAAF4\uAB01-\uAB06\uAB09-\uAB0E\uAB11-\uAB16\uAB20-\uAB26\uAB28-\uAB2E\uAB30-\uAB5A\uAB5C-\uAB69\uAB70-\uABE2\uAC00-\uD7A3\uD7B0-\uD7C6\uD7CB-\uD7FB\uF900-\uFA6D\uFA70-\uFAD9\uFB00-\uFB06\uFB13-\uFB17\uFB1D\uFB1F-\uFB28\uFB2A-\uFB36\uFB38-\uFB3C\uFB3E\uFB40\uFB41\uFB43\uFB44\uFB46-\uFBB1\uFBD3-\uFD3D\uFD50-\uFD8F\uFD92-\uFDC7\uFDF0-\uFDFB\uFE70-\uFE74\uFE76-\uFEFC\uFF21-\uFF3A\uFF41-\uFF5A\uFF66-\uFFBE\uFFC2-\uFFC7\uFFCA-\uFFCF\uFFD2-\uFFD7\uFFDA-\uFFDC]|\uD800[\uDC00-\uDC0B\uDC0D-\uDC26\uDC28-\uDC3A\uDC3C\uDC3D\uDC3F-\uDC4D\uDC50-\uDC5D\uDC80-\uDCFA\uDE80-\uDE9C\uDEA0-\uDED0\uDF00-\uDF1F\uDF2D-\uDF40\uDF42-\uDF49\uDF50-\uDF75\uDF80-\uDF9D\uDFA0-\uDFC3\uDFC8-\uDFCF]|\uD801[\uDC00-\uDC9D\uDCB0-\uDCD3\uDCD8-\uDCFB\uDD00-\uDD27\uDD30-\uDD63\uDD70-\uDD7A\uDD7C-\uDD8A\uDD8C-\uDD92\uDD94\uDD95\uDD97-\uDDA1\uDDA3-\uDDB1\uDDB3-\uDDB9\uDDBB\uDDBC\uDE00-\uDF36\uDF40-\uDF55\uDF60-\uDF67\uDF80-\uDF85\uDF87-\uDFB0\uDFB2-\uDFBA]|\uD802[\uDC00-\uDC05\uDC08\uDC0A-\uDC35\uDC37\uDC38\uDC3C\uDC3F-\uDC55\uDC60-\uDC76\uDC80-\uDC9E\uDCE0-\uDCF2\uDCF4\uDCF5\uDD00-\uDD15\uDD20-\uDD39\uDD80-\uDDB7\uDDBE\uDDBF\uDE00\uDE10-\uDE13\uDE15-\uDE17\uDE19-\uDE35\uDE60-\uDE7C\uDE80-\uDE9C\uDEC0-\uDEC7\uDEC9-\uDEE4\uDF00-\uDF35\uDF40-\uDF55\uDF60-\uDF72\uDF80-\uDF91]|\uD803[\uDC00-\uDC48\uDC80-\uDCB2\uDCC0-\uDCF2\uDD00-\uDD23\uDE80-\uDEA9\uDEB0\uDEB1\uDF00-\uDF1C\uDF27\uDF30-\uDF45\uDF70-\uDF81\uDFB0-\uDFC4\uDFE0-\uDFF6]|\uD804[\uDC03-\uDC37\uDC71\uDC72\uDC75\uDC83-\uDCAF\uDCD0-\uDCE8\uDD03-\uDD26\uDD44\uDD47\uDD50-\uDD72\uDD76\uDD83-\uDDB2\uDDC1-\uDDC4\uDDDA\uDDDC\uDE00-\uDE11\uDE13-\uDE2B\uDE3F\uDE40\uDE80-\uDE86\uDE88\uDE8A-\uDE8D\uDE8F-\uDE9D\uDE9F-\uDEA8\uDEB0-\uDEDE\uDF05-\uDF0C\uDF0F\uDF10\uDF13-\uDF28\uDF2A-\uDF30\uDF32\uDF33\uDF35-\uDF39\uDF3D\uDF50\uDF5D-\uDF61]|\uD805[\uDC00-\uDC34\uDC47-\uDC4A\uDC5F-\uDC61\uDC80-\uDCAF\uDCC4\uDCC5\uDCC7\uDD80-\uDDAE\uDDD8-\uDDDB\uDE00-\uDE2F\uDE44\uDE80-\uDEAA\uDEB8\uDF00-\uDF1A\uDF40-\uDF46]|\uD806[\uDC00-\uDC2B\uDCA0-\uDCDF\uDCFF-\uDD06\uDD09\uDD0C-\uDD13\uDD15\uDD16\uDD18-\uDD2F\uDD3F\uDD41\uDDA0-\uDDA7\uDDAA-\uDDD0\uDDE1\uDDE3\uDE00\uDE0B-\uDE32\uDE3A\uDE50\uDE5C-\uDE89\uDE9D\uDEB0-\uDEF8]|\uD807[\uDC00-\uDC08\uDC0A-\uDC2E\uDC40\uDC72-\uDC8F\uDD00-\uDD06\uDD08\uDD09\uDD0B-\uDD30\uDD46\uDD60-\uDD65\uDD67\uDD68\uDD6A-\uDD89\uDD98\uDEE0-\uDEF2\uDF02\uDF04-\uDF10\uDF12-\uDF33\uDFB0]|\uD808[\uDC00-\uDF99]|\uD809[\uDC80-\uDD43]|\uD80B[\uDF90-\uDFF0]|[\uD80C\uD81C-\uD820\uD822\uD840-\uD868\uD86A-\uD86C\uD86F-\uD872\uD874-\uD879\uD880-\uD883\uD885-\uD887][\uDC00-\uDFFF]|\uD80D[\uDC00-\uDC2F\uDC41-\uDC46]|\uD811[\uDC00-\uDE46]|\uD81A[\uDC00-\uDE38\uDE40-\uDE5E\uDE70-\uDEBE\uDED0-\uDEED\uDF00-\uDF2F\uDF40-\uDF43\uDF63-\uDF77\uDF7D-\uDF8F]|\uD81B[\uDE40-\uDE7F\uDF00-\uDF4A\uDF50\uDF93-\uDF9F\uDFE0\uDFE1\uDFE3]|\uD821[\uDC00-\uDFF7]|\uD823[\uDC00-\uDCD5\uDD00-\uDD08]|\uD82B[\uDFF0-\uDFF3\uDFF5-\uDFFB\uDFFD\uDFFE]|\uD82C[\uDC00-\uDD22\uDD32\uDD50-\uDD52\uDD55\uDD64-\uDD67\uDD70-\uDEFB]|\uD82F[\uDC00-\uDC6A\uDC70-\uDC7C\uDC80-\uDC88\uDC90-\uDC99]|\uD835[\uDC00-\uDC54\uDC56-\uDC9C\uDC9E\uDC9F\uDCA2\uDCA5\uDCA6\uDCA9-\uDCAC\uDCAE-\uDCB9\uDCBB\uDCBD-\uDCC3\uDCC5-\uDD05\uDD07-\uDD0A\uDD0D-\uDD14\uDD16-\uDD1C\uDD1E-\uDD39\uDD3B-\uDD3E\uDD40-\uDD44\uDD46\uDD4A-\uDD50\uDD52-\uDEA5\uDEA8-\uDEC0\uDEC2-\uDEDA\uDEDC-\uDEFA\uDEFC-\uDF14\uDF16-\uDF34\uDF36-\uDF4E\uDF50-\uDF6E\uDF70-\uDF88\uDF8A-\uDFA8\uDFAA-\uDFC2\uDFC4-\uDFCB]|\uD837[\uDF00-\uDF1E\uDF25-\uDF2A]|\uD838[\uDC30-\uDC6D\uDD00-\uDD2C\uDD37-\uDD3D\uDD4E\uDE90-\uDEAD\uDEC0-\uDEEB]|\uD839[\uDCD0-\uDCEB\uDFE0-\uDFE6\uDFE8-\uDFEB\uDFED\uDFEE\uDFF0-\uDFFE]|\uD83A[\uDC00-\uDCC4\uDD00-\uDD43\uDD4B]|\uD83B[\uDE00-\uDE03\uDE05-\uDE1F\uDE21\uDE22\uDE24\uDE27\uDE29-\uDE32\uDE34-\uDE37\uDE39\uDE3B\uDE42\uDE47\uDE49\uDE4B\uDE4D-\uDE4F\uDE51\uDE52\uDE54\uDE57\uDE59\uDE5B\uDE5D\uDE5F\uDE61\uDE62\uDE64\uDE67-\uDE6A\uDE6C-\uDE72\uDE74-\uDE77\uDE79-\uDE7C\uDE7E\uDE80-\uDE89\uDE8B-\uDE9B\uDEA1-\uDEA3\uDEA5-\uDEA9\uDEAB-\uDEBB]|\uD869[\uDC00-\uDEDF\uDF00-\uDFFF]|\uD86D[\uDC00-\uDF39\uDF40-\uDFFF]|\uD86E[\uDC00-\uDC1D\uDC20-\uDFFF]|\uD873[\uDC00-\uDEA1\uDEB0-\uDFFF]|\uD87A[\uDC00-\uDFE0\uDFF0-\uDFFF]|\uD87B[\uDC00-\uDE5D]|\uD87E[\uDC00-\uDE1D]|\uD884[\uDC00-\uDF4A\uDF50-\uDFFF]|\uD888[\uDC00-\uDFAF])/g);
  if (firstWordStart !== -1) {
    before = before.slice(firstWordStart + 1);
  }

  // Compute the text after the highlight, ignoring the last "word", which might be cut.
  let after = text.slice(end, Math.min(text.length, end + snippetLength));
  let lastWordEnd = Array.from(after.matchAll(/(?:[A-Za-z\xAA\xB5\xBA\xC0-\xD6\xD8-\xF6\xF8-\u02C1\u02C6-\u02D1\u02E0-\u02E4\u02EC\u02EE\u0370-\u0374\u0376\u0377\u037A-\u037D\u037F\u0386\u0388-\u038A\u038C\u038E-\u03A1\u03A3-\u03F5\u03F7-\u0481\u048A-\u052F\u0531-\u0556\u0559\u0560-\u0588\u05D0-\u05EA\u05EF-\u05F2\u0620-\u064A\u066E\u066F\u0671-\u06D3\u06D5\u06E5\u06E6\u06EE\u06EF\u06FA-\u06FC\u06FF\u0710\u0712-\u072F\u074D-\u07A5\u07B1\u07CA-\u07EA\u07F4\u07F5\u07FA\u0800-\u0815\u081A\u0824\u0828\u0840-\u0858\u0860-\u086A\u0870-\u0887\u0889-\u088E\u08A0-\u08C9\u0904-\u0939\u093D\u0950\u0958-\u0961\u0971-\u0980\u0985-\u098C\u098F\u0990\u0993-\u09A8\u09AA-\u09B0\u09B2\u09B6-\u09B9\u09BD\u09CE\u09DC\u09DD\u09DF-\u09E1\u09F0\u09F1\u09FC\u0A05-\u0A0A\u0A0F\u0A10\u0A13-\u0A28\u0A2A-\u0A30\u0A32\u0A33\u0A35\u0A36\u0A38\u0A39\u0A59-\u0A5C\u0A5E\u0A72-\u0A74\u0A85-\u0A8D\u0A8F-\u0A91\u0A93-\u0AA8\u0AAA-\u0AB0\u0AB2\u0AB3\u0AB5-\u0AB9\u0ABD\u0AD0\u0AE0\u0AE1\u0AF9\u0B05-\u0B0C\u0B0F\u0B10\u0B13-\u0B28\u0B2A-\u0B30\u0B32\u0B33\u0B35-\u0B39\u0B3D\u0B5C\u0B5D\u0B5F-\u0B61\u0B71\u0B83\u0B85-\u0B8A\u0B8E-\u0B90\u0B92-\u0B95\u0B99\u0B9A\u0B9C\u0B9E\u0B9F\u0BA3\u0BA4\u0BA8-\u0BAA\u0BAE-\u0BB9\u0BD0\u0C05-\u0C0C\u0C0E-\u0C10\u0C12-\u0C28\u0C2A-\u0C39\u0C3D\u0C58-\u0C5A\u0C5D\u0C60\u0C61\u0C80\u0C85-\u0C8C\u0C8E-\u0C90\u0C92-\u0CA8\u0CAA-\u0CB3\u0CB5-\u0CB9\u0CBD\u0CDD\u0CDE\u0CE0\u0CE1\u0CF1\u0CF2\u0D04-\u0D0C\u0D0E-\u0D10\u0D12-\u0D3A\u0D3D\u0D4E\u0D54-\u0D56\u0D5F-\u0D61\u0D7A-\u0D7F\u0D85-\u0D96\u0D9A-\u0DB1\u0DB3-\u0DBB\u0DBD\u0DC0-\u0DC6\u0E01-\u0E30\u0E32\u0E33\u0E40-\u0E46\u0E81\u0E82\u0E84\u0E86-\u0E8A\u0E8C-\u0EA3\u0EA5\u0EA7-\u0EB0\u0EB2\u0EB3\u0EBD\u0EC0-\u0EC4\u0EC6\u0EDC-\u0EDF\u0F00\u0F40-\u0F47\u0F49-\u0F6C\u0F88-\u0F8C\u1000-\u102A\u103F\u1050-\u1055\u105A-\u105D\u1061\u1065\u1066\u106E-\u1070\u1075-\u1081\u108E\u10A0-\u10C5\u10C7\u10CD\u10D0-\u10FA\u10FC-\u1248\u124A-\u124D\u1250-\u1256\u1258\u125A-\u125D\u1260-\u1288\u128A-\u128D\u1290-\u12B0\u12B2-\u12B5\u12B8-\u12BE\u12C0\u12C2-\u12C5\u12C8-\u12D6\u12D8-\u1310\u1312-\u1315\u1318-\u135A\u1380-\u138F\u13A0-\u13F5\u13F8-\u13FD\u1401-\u166C\u166F-\u167F\u1681-\u169A\u16A0-\u16EA\u16F1-\u16F8\u1700-\u1711\u171F-\u1731\u1740-\u1751\u1760-\u176C\u176E-\u1770\u1780-\u17B3\u17D7\u17DC\u1820-\u1878\u1880-\u1884\u1887-\u18A8\u18AA\u18B0-\u18F5\u1900-\u191E\u1950-\u196D\u1970-\u1974\u1980-\u19AB\u19B0-\u19C9\u1A00-\u1A16\u1A20-\u1A54\u1AA7\u1B05-\u1B33\u1B45-\u1B4C\u1B83-\u1BA0\u1BAE\u1BAF\u1BBA-\u1BE5\u1C00-\u1C23\u1C4D-\u1C4F\u1C5A-\u1C7D\u1C80-\u1C88\u1C90-\u1CBA\u1CBD-\u1CBF\u1CE9-\u1CEC\u1CEE-\u1CF3\u1CF5\u1CF6\u1CFA\u1D00-\u1DBF\u1E00-\u1F15\u1F18-\u1F1D\u1F20-\u1F45\u1F48-\u1F4D\u1F50-\u1F57\u1F59\u1F5B\u1F5D\u1F5F-\u1F7D\u1F80-\u1FB4\u1FB6-\u1FBC\u1FBE\u1FC2-\u1FC4\u1FC6-\u1FCC\u1FD0-\u1FD3\u1FD6-\u1FDB\u1FE0-\u1FEC\u1FF2-\u1FF4\u1FF6-\u1FFC\u2071\u207F\u2090-\u209C\u2102\u2107\u210A-\u2113\u2115\u2119-\u211D\u2124\u2126\u2128\u212A-\u212D\u212F-\u2139\u213C-\u213F\u2145-\u2149\u214E\u2183\u2184\u2C00-\u2CE4\u2CEB-\u2CEE\u2CF2\u2CF3\u2D00-\u2D25\u2D27\u2D2D\u2D30-\u2D67\u2D6F\u2D80-\u2D96\u2DA0-\u2DA6\u2DA8-\u2DAE\u2DB0-\u2DB6\u2DB8-\u2DBE\u2DC0-\u2DC6\u2DC8-\u2DCE\u2DD0-\u2DD6\u2DD8-\u2DDE\u2E2F\u3005\u3006\u3031-\u3035\u303B\u303C\u3041-\u3096\u309D-\u309F\u30A1-\u30FA\u30FC-\u30FF\u3105-\u312F\u3131-\u318E\u31A0-\u31BF\u31F0-\u31FF\u3400-\u4DBF\u4E00-\uA48C\uA4D0-\uA4FD\uA500-\uA60C\uA610-\uA61F\uA62A\uA62B\uA640-\uA66E\uA67F-\uA69D\uA6A0-\uA6E5\uA717-\uA71F\uA722-\uA788\uA78B-\uA7CA\uA7D0\uA7D1\uA7D3\uA7D5-\uA7D9\uA7F2-\uA801\uA803-\uA805\uA807-\uA80A\uA80C-\uA822\uA840-\uA873\uA882-\uA8B3\uA8F2-\uA8F7\uA8FB\uA8FD\uA8FE\uA90A-\uA925\uA930-\uA946\uA960-\uA97C\uA984-\uA9B2\uA9CF\uA9E0-\uA9E4\uA9E6-\uA9EF\uA9FA-\uA9FE\uAA00-\uAA28\uAA40-\uAA42\uAA44-\uAA4B\uAA60-\uAA76\uAA7A\uAA7E-\uAAAF\uAAB1\uAAB5\uAAB6\uAAB9-\uAABD\uAAC0\uAAC2\uAADB-\uAADD\uAAE0-\uAAEA\uAAF2-\uAAF4\uAB01-\uAB06\uAB09-\uAB0E\uAB11-\uAB16\uAB20-\uAB26\uAB28-\uAB2E\uAB30-\uAB5A\uAB5C-\uAB69\uAB70-\uABE2\uAC00-\uD7A3\uD7B0-\uD7C6\uD7CB-\uD7FB\uF900-\uFA6D\uFA70-\uFAD9\uFB00-\uFB06\uFB13-\uFB17\uFB1D\uFB1F-\uFB28\uFB2A-\uFB36\uFB38-\uFB3C\uFB3E\uFB40\uFB41\uFB43\uFB44\uFB46-\uFBB1\uFBD3-\uFD3D\uFD50-\uFD8F\uFD92-\uFDC7\uFDF0-\uFDFB\uFE70-\uFE74\uFE76-\uFEFC\uFF21-\uFF3A\uFF41-\uFF5A\uFF66-\uFFBE\uFFC2-\uFFC7\uFFCA-\uFFCF\uFFD2-\uFFD7\uFFDA-\uFFDC]|\uD800[\uDC00-\uDC0B\uDC0D-\uDC26\uDC28-\uDC3A\uDC3C\uDC3D\uDC3F-\uDC4D\uDC50-\uDC5D\uDC80-\uDCFA\uDE80-\uDE9C\uDEA0-\uDED0\uDF00-\uDF1F\uDF2D-\uDF40\uDF42-\uDF49\uDF50-\uDF75\uDF80-\uDF9D\uDFA0-\uDFC3\uDFC8-\uDFCF]|\uD801[\uDC00-\uDC9D\uDCB0-\uDCD3\uDCD8-\uDCFB\uDD00-\uDD27\uDD30-\uDD63\uDD70-\uDD7A\uDD7C-\uDD8A\uDD8C-\uDD92\uDD94\uDD95\uDD97-\uDDA1\uDDA3-\uDDB1\uDDB3-\uDDB9\uDDBB\uDDBC\uDE00-\uDF36\uDF40-\uDF55\uDF60-\uDF67\uDF80-\uDF85\uDF87-\uDFB0\uDFB2-\uDFBA]|\uD802[\uDC00-\uDC05\uDC08\uDC0A-\uDC35\uDC37\uDC38\uDC3C\uDC3F-\uDC55\uDC60-\uDC76\uDC80-\uDC9E\uDCE0-\uDCF2\uDCF4\uDCF5\uDD00-\uDD15\uDD20-\uDD39\uDD80-\uDDB7\uDDBE\uDDBF\uDE00\uDE10-\uDE13\uDE15-\uDE17\uDE19-\uDE35\uDE60-\uDE7C\uDE80-\uDE9C\uDEC0-\uDEC7\uDEC9-\uDEE4\uDF00-\uDF35\uDF40-\uDF55\uDF60-\uDF72\uDF80-\uDF91]|\uD803[\uDC00-\uDC48\uDC80-\uDCB2\uDCC0-\uDCF2\uDD00-\uDD23\uDE80-\uDEA9\uDEB0\uDEB1\uDF00-\uDF1C\uDF27\uDF30-\uDF45\uDF70-\uDF81\uDFB0-\uDFC4\uDFE0-\uDFF6]|\uD804[\uDC03-\uDC37\uDC71\uDC72\uDC75\uDC83-\uDCAF\uDCD0-\uDCE8\uDD03-\uDD26\uDD44\uDD47\uDD50-\uDD72\uDD76\uDD83-\uDDB2\uDDC1-\uDDC4\uDDDA\uDDDC\uDE00-\uDE11\uDE13-\uDE2B\uDE3F\uDE40\uDE80-\uDE86\uDE88\uDE8A-\uDE8D\uDE8F-\uDE9D\uDE9F-\uDEA8\uDEB0-\uDEDE\uDF05-\uDF0C\uDF0F\uDF10\uDF13-\uDF28\uDF2A-\uDF30\uDF32\uDF33\uDF35-\uDF39\uDF3D\uDF50\uDF5D-\uDF61]|\uD805[\uDC00-\uDC34\uDC47-\uDC4A\uDC5F-\uDC61\uDC80-\uDCAF\uDCC4\uDCC5\uDCC7\uDD80-\uDDAE\uDDD8-\uDDDB\uDE00-\uDE2F\uDE44\uDE80-\uDEAA\uDEB8\uDF00-\uDF1A\uDF40-\uDF46]|\uD806[\uDC00-\uDC2B\uDCA0-\uDCDF\uDCFF-\uDD06\uDD09\uDD0C-\uDD13\uDD15\uDD16\uDD18-\uDD2F\uDD3F\uDD41\uDDA0-\uDDA7\uDDAA-\uDDD0\uDDE1\uDDE3\uDE00\uDE0B-\uDE32\uDE3A\uDE50\uDE5C-\uDE89\uDE9D\uDEB0-\uDEF8]|\uD807[\uDC00-\uDC08\uDC0A-\uDC2E\uDC40\uDC72-\uDC8F\uDD00-\uDD06\uDD08\uDD09\uDD0B-\uDD30\uDD46\uDD60-\uDD65\uDD67\uDD68\uDD6A-\uDD89\uDD98\uDEE0-\uDEF2\uDF02\uDF04-\uDF10\uDF12-\uDF33\uDFB0]|\uD808[\uDC00-\uDF99]|\uD809[\uDC80-\uDD43]|\uD80B[\uDF90-\uDFF0]|[\uD80C\uD81C-\uD820\uD822\uD840-\uD868\uD86A-\uD86C\uD86F-\uD872\uD874-\uD879\uD880-\uD883\uD885-\uD887][\uDC00-\uDFFF]|\uD80D[\uDC00-\uDC2F\uDC41-\uDC46]|\uD811[\uDC00-\uDE46]|\uD81A[\uDC00-\uDE38\uDE40-\uDE5E\uDE70-\uDEBE\uDED0-\uDEED\uDF00-\uDF2F\uDF40-\uDF43\uDF63-\uDF77\uDF7D-\uDF8F]|\uD81B[\uDE40-\uDE7F\uDF00-\uDF4A\uDF50\uDF93-\uDF9F\uDFE0\uDFE1\uDFE3]|\uD821[\uDC00-\uDFF7]|\uD823[\uDC00-\uDCD5\uDD00-\uDD08]|\uD82B[\uDFF0-\uDFF3\uDFF5-\uDFFB\uDFFD\uDFFE]|\uD82C[\uDC00-\uDD22\uDD32\uDD50-\uDD52\uDD55\uDD64-\uDD67\uDD70-\uDEFB]|\uD82F[\uDC00-\uDC6A\uDC70-\uDC7C\uDC80-\uDC88\uDC90-\uDC99]|\uD835[\uDC00-\uDC54\uDC56-\uDC9C\uDC9E\uDC9F\uDCA2\uDCA5\uDCA6\uDCA9-\uDCAC\uDCAE-\uDCB9\uDCBB\uDCBD-\uDCC3\uDCC5-\uDD05\uDD07-\uDD0A\uDD0D-\uDD14\uDD16-\uDD1C\uDD1E-\uDD39\uDD3B-\uDD3E\uDD40-\uDD44\uDD46\uDD4A-\uDD50\uDD52-\uDEA5\uDEA8-\uDEC0\uDEC2-\uDEDA\uDEDC-\uDEFA\uDEFC-\uDF14\uDF16-\uDF34\uDF36-\uDF4E\uDF50-\uDF6E\uDF70-\uDF88\uDF8A-\uDFA8\uDFAA-\uDFC2\uDFC4-\uDFCB]|\uD837[\uDF00-\uDF1E\uDF25-\uDF2A]|\uD838[\uDC30-\uDC6D\uDD00-\uDD2C\uDD37-\uDD3D\uDD4E\uDE90-\uDEAD\uDEC0-\uDEEB]|\uD839[\uDCD0-\uDCEB\uDFE0-\uDFE6\uDFE8-\uDFEB\uDFED\uDFEE\uDFF0-\uDFFE]|\uD83A[\uDC00-\uDCC4\uDD00-\uDD43\uDD4B]|\uD83B[\uDE00-\uDE03\uDE05-\uDE1F\uDE21\uDE22\uDE24\uDE27\uDE29-\uDE32\uDE34-\uDE37\uDE39\uDE3B\uDE42\uDE47\uDE49\uDE4B\uDE4D-\uDE4F\uDE51\uDE52\uDE54\uDE57\uDE59\uDE5B\uDE5D\uDE5F\uDE61\uDE62\uDE64\uDE67-\uDE6A\uDE6C-\uDE72\uDE74-\uDE77\uDE79-\uDE7C\uDE7E\uDE80-\uDE89\uDE8B-\uDE9B\uDEA1-\uDEA3\uDEA5-\uDEA9\uDEAB-\uDEBB]|\uD869[\uDC00-\uDEDF\uDF00-\uDFFF]|\uD86D[\uDC00-\uDF39\uDF40-\uDFFF]|\uD86E[\uDC00-\uDC1D\uDC20-\uDFFF]|\uD873[\uDC00-\uDEA1\uDEB0-\uDFFF]|\uD87A[\uDC00-\uDFE0\uDFF0-\uDFFF]|\uD87B[\uDC00-\uDE5D]|\uD87E[\uDC00-\uDE1D]|\uD884[\uDC00-\uDF4A\uDF50-\uDFFF]|\uD888[\uDC00-\uDFAF])(?:[\0-@\[-`\{-\xA9\xAB-\xB4\xB6-\xB9\xBB-\xBF\xD7\xF7\u02C2-\u02C5\u02D2-\u02DF\u02E5-\u02EB\u02ED\u02EF-\u036F\u0375\u0378\u0379\u037E\u0380-\u0385\u0387\u038B\u038D\u03A2\u03F6\u0482-\u0489\u0530\u0557\u0558\u055A-\u055F\u0589-\u05CF\u05EB-\u05EE\u05F3-\u061F\u064B-\u066D\u0670\u06D4\u06D6-\u06E4\u06E7-\u06ED\u06F0-\u06F9\u06FD\u06FE\u0700-\u070F\u0711\u0730-\u074C\u07A6-\u07B0\u07B2-\u07C9\u07EB-\u07F3\u07F6-\u07F9\u07FB-\u07FF\u0816-\u0819\u081B-\u0823\u0825-\u0827\u0829-\u083F\u0859-\u085F\u086B-\u086F\u0888\u088F-\u089F\u08CA-\u0903\u093A-\u093C\u093E-\u094F\u0951-\u0957\u0962-\u0970\u0981-\u0984\u098D\u098E\u0991\u0992\u09A9\u09B1\u09B3-\u09B5\u09BA-\u09BC\u09BE-\u09CD\u09CF-\u09DB\u09DE\u09E2-\u09EF\u09F2-\u09FB\u09FD-\u0A04\u0A0B-\u0A0E\u0A11\u0A12\u0A29\u0A31\u0A34\u0A37\u0A3A-\u0A58\u0A5D\u0A5F-\u0A71\u0A75-\u0A84\u0A8E\u0A92\u0AA9\u0AB1\u0AB4\u0ABA-\u0ABC\u0ABE-\u0ACF\u0AD1-\u0ADF\u0AE2-\u0AF8\u0AFA-\u0B04\u0B0D\u0B0E\u0B11\u0B12\u0B29\u0B31\u0B34\u0B3A-\u0B3C\u0B3E-\u0B5B\u0B5E\u0B62-\u0B70\u0B72-\u0B82\u0B84\u0B8B-\u0B8D\u0B91\u0B96-\u0B98\u0B9B\u0B9D\u0BA0-\u0BA2\u0BA5-\u0BA7\u0BAB-\u0BAD\u0BBA-\u0BCF\u0BD1-\u0C04\u0C0D\u0C11\u0C29\u0C3A-\u0C3C\u0C3E-\u0C57\u0C5B\u0C5C\u0C5E\u0C5F\u0C62-\u0C7F\u0C81-\u0C84\u0C8D\u0C91\u0CA9\u0CB4\u0CBA-\u0CBC\u0CBE-\u0CDC\u0CDF\u0CE2-\u0CF0\u0CF3-\u0D03\u0D0D\u0D11\u0D3B\u0D3C\u0D3E-\u0D4D\u0D4F-\u0D53\u0D57-\u0D5E\u0D62-\u0D79\u0D80-\u0D84\u0D97-\u0D99\u0DB2\u0DBC\u0DBE\u0DBF\u0DC7-\u0E00\u0E31\u0E34-\u0E3F\u0E47-\u0E80\u0E83\u0E85\u0E8B\u0EA4\u0EA6\u0EB1\u0EB4-\u0EBC\u0EBE\u0EBF\u0EC5\u0EC7-\u0EDB\u0EE0-\u0EFF\u0F01-\u0F3F\u0F48\u0F6D-\u0F87\u0F8D-\u0FFF\u102B-\u103E\u1040-\u104F\u1056-\u1059\u105E-\u1060\u1062-\u1064\u1067-\u106D\u1071-\u1074\u1082-\u108D\u108F-\u109F\u10C6\u10C8-\u10CC\u10CE\u10CF\u10FB\u1249\u124E\u124F\u1257\u1259\u125E\u125F\u1289\u128E\u128F\u12B1\u12B6\u12B7\u12BF\u12C1\u12C6\u12C7\u12D7\u1311\u1316\u1317\u135B-\u137F\u1390-\u139F\u13F6\u13F7\u13FE-\u1400\u166D\u166E\u1680\u169B-\u169F\u16EB-\u16F0\u16F9-\u16FF\u1712-\u171E\u1732-\u173F\u1752-\u175F\u176D\u1771-\u177F\u17B4-\u17D6\u17D8-\u17DB\u17DD-\u181F\u1879-\u187F\u1885\u1886\u18A9\u18AB-\u18AF\u18F6-\u18FF\u191F-\u194F\u196E\u196F\u1975-\u197F\u19AC-\u19AF\u19CA-\u19FF\u1A17-\u1A1F\u1A55-\u1AA6\u1AA8-\u1B04\u1B34-\u1B44\u1B4D-\u1B82\u1BA1-\u1BAD\u1BB0-\u1BB9\u1BE6-\u1BFF\u1C24-\u1C4C\u1C50-\u1C59\u1C7E\u1C7F\u1C89-\u1C8F\u1CBB\u1CBC\u1CC0-\u1CE8\u1CED\u1CF4\u1CF7-\u1CF9\u1CFB-\u1CFF\u1DC0-\u1DFF\u1F16\u1F17\u1F1E\u1F1F\u1F46\u1F47\u1F4E\u1F4F\u1F58\u1F5A\u1F5C\u1F5E\u1F7E\u1F7F\u1FB5\u1FBD\u1FBF-\u1FC1\u1FC5\u1FCD-\u1FCF\u1FD4\u1FD5\u1FDC-\u1FDF\u1FED-\u1FF1\u1FF5\u1FFD-\u2070\u2072-\u207E\u2080-\u208F\u209D-\u2101\u2103-\u2106\u2108\u2109\u2114\u2116-\u2118\u211E-\u2123\u2125\u2127\u2129\u212E\u213A\u213B\u2140-\u2144\u214A-\u214D\u214F-\u2182\u2185-\u2BFF\u2CE5-\u2CEA\u2CEF-\u2CF1\u2CF4-\u2CFF\u2D26\u2D28-\u2D2C\u2D2E\u2D2F\u2D68-\u2D6E\u2D70-\u2D7F\u2D97-\u2D9F\u2DA7\u2DAF\u2DB7\u2DBF\u2DC7\u2DCF\u2DD7\u2DDF-\u2E2E\u2E30-\u3004\u3007-\u3030\u3036-\u303A\u303D-\u3040\u3097-\u309C\u30A0\u30FB\u3100-\u3104\u3130\u318F-\u319F\u31C0-\u31EF\u3200-\u33FF\u4DC0-\u4DFF\uA48D-\uA4CF\uA4FE\uA4FF\uA60D-\uA60F\uA620-\uA629\uA62C-\uA63F\uA66F-\uA67E\uA69E\uA69F\uA6E6-\uA716\uA720\uA721\uA789\uA78A\uA7CB-\uA7CF\uA7D2\uA7D4\uA7DA-\uA7F1\uA802\uA806\uA80B\uA823-\uA83F\uA874-\uA881\uA8B4-\uA8F1\uA8F8-\uA8FA\uA8FC\uA8FF-\uA909\uA926-\uA92F\uA947-\uA95F\uA97D-\uA983\uA9B3-\uA9CE\uA9D0-\uA9DF\uA9E5\uA9F0-\uA9F9\uA9FF\uAA29-\uAA3F\uAA43\uAA4C-\uAA5F\uAA77-\uAA79\uAA7B-\uAA7D\uAAB0\uAAB2-\uAAB4\uAAB7\uAAB8\uAABE\uAABF\uAAC1\uAAC3-\uAADA\uAADE\uAADF\uAAEB-\uAAF1\uAAF5-\uAB00\uAB07\uAB08\uAB0F\uAB10\uAB17-\uAB1F\uAB27\uAB2F\uAB5B\uAB6A-\uAB6F\uABE3-\uABFF\uD7A4-\uD7AF\uD7C7-\uD7CA\uD7FC-\uD7FF\uE000-\uF8FF\uFA6E\uFA6F\uFADA-\uFAFF\uFB07-\uFB12\uFB18-\uFB1C\uFB1E\uFB29\uFB37\uFB3D\uFB3F\uFB42\uFB45\uFBB2-\uFBD2\uFD3E-\uFD4F\uFD90\uFD91\uFDC8-\uFDEF\uFDFC-\uFE6F\uFE75\uFEFD-\uFF20\uFF3B-\uFF40\uFF5B-\uFF65\uFFBF-\uFFC1\uFFC8\uFFC9\uFFD0\uFFD1\uFFD8\uFFD9\uFFDD-\uFFFF]|\uD800[\uDC0C\uDC27\uDC3B\uDC3E\uDC4E\uDC4F\uDC5E-\uDC7F\uDCFB-\uDE7F\uDE9D-\uDE9F\uDED1-\uDEFF\uDF20-\uDF2C\uDF41\uDF4A-\uDF4F\uDF76-\uDF7F\uDF9E\uDF9F\uDFC4-\uDFC7\uDFD0-\uDFFF]|\uD801[\uDC9E-\uDCAF\uDCD4-\uDCD7\uDCFC-\uDCFF\uDD28-\uDD2F\uDD64-\uDD6F\uDD7B\uDD8B\uDD93\uDD96\uDDA2\uDDB2\uDDBA\uDDBD-\uDDFF\uDF37-\uDF3F\uDF56-\uDF5F\uDF68-\uDF7F\uDF86\uDFB1\uDFBB-\uDFFF]|\uD802[\uDC06\uDC07\uDC09\uDC36\uDC39-\uDC3B\uDC3D\uDC3E\uDC56-\uDC5F\uDC77-\uDC7F\uDC9F-\uDCDF\uDCF3\uDCF6-\uDCFF\uDD16-\uDD1F\uDD3A-\uDD7F\uDDB8-\uDDBD\uDDC0-\uDDFF\uDE01-\uDE0F\uDE14\uDE18\uDE36-\uDE5F\uDE7D-\uDE7F\uDE9D-\uDEBF\uDEC8\uDEE5-\uDEFF\uDF36-\uDF3F\uDF56-\uDF5F\uDF73-\uDF7F\uDF92-\uDFFF]|\uD803[\uDC49-\uDC7F\uDCB3-\uDCBF\uDCF3-\uDCFF\uDD24-\uDE7F\uDEAA-\uDEAF\uDEB2-\uDEFF\uDF1D-\uDF26\uDF28-\uDF2F\uDF46-\uDF6F\uDF82-\uDFAF\uDFC5-\uDFDF\uDFF7-\uDFFF]|\uD804[\uDC00-\uDC02\uDC38-\uDC70\uDC73\uDC74\uDC76-\uDC82\uDCB0-\uDCCF\uDCE9-\uDD02\uDD27-\uDD43\uDD45\uDD46\uDD48-\uDD4F\uDD73-\uDD75\uDD77-\uDD82\uDDB3-\uDDC0\uDDC5-\uDDD9\uDDDB\uDDDD-\uDDFF\uDE12\uDE2C-\uDE3E\uDE41-\uDE7F\uDE87\uDE89\uDE8E\uDE9E\uDEA9-\uDEAF\uDEDF-\uDF04\uDF0D\uDF0E\uDF11\uDF12\uDF29\uDF31\uDF34\uDF3A-\uDF3C\uDF3E-\uDF4F\uDF51-\uDF5C\uDF62-\uDFFF]|\uD805[\uDC35-\uDC46\uDC4B-\uDC5E\uDC62-\uDC7F\uDCB0-\uDCC3\uDCC6\uDCC8-\uDD7F\uDDAF-\uDDD7\uDDDC-\uDDFF\uDE30-\uDE43\uDE45-\uDE7F\uDEAB-\uDEB7\uDEB9-\uDEFF\uDF1B-\uDF3F\uDF47-\uDFFF]|\uD806[\uDC2C-\uDC9F\uDCE0-\uDCFE\uDD07\uDD08\uDD0A\uDD0B\uDD14\uDD17\uDD30-\uDD3E\uDD40\uDD42-\uDD9F\uDDA8\uDDA9\uDDD1-\uDDE0\uDDE2\uDDE4-\uDDFF\uDE01-\uDE0A\uDE33-\uDE39\uDE3B-\uDE4F\uDE51-\uDE5B\uDE8A-\uDE9C\uDE9E-\uDEAF\uDEF9-\uDFFF]|\uD807[\uDC09\uDC2F-\uDC3F\uDC41-\uDC71\uDC90-\uDCFF\uDD07\uDD0A\uDD31-\uDD45\uDD47-\uDD5F\uDD66\uDD69\uDD8A-\uDD97\uDD99-\uDEDF\uDEF3-\uDF01\uDF03\uDF11\uDF34-\uDFAF\uDFB1-\uDFFF]|\uD808[\uDF9A-\uDFFF]|\uD809[\uDC00-\uDC7F\uDD44-\uDFFF]|[\uD80A\uD80E-\uD810\uD812-\uD819\uD824-\uD82A\uD82D\uD82E\uD830-\uD834\uD836\uD83C-\uD83F\uD87C\uD87D\uD87F\uD889-\uDBFF][\uDC00-\uDFFF]|\uD80B[\uDC00-\uDF8F\uDFF1-\uDFFF]|\uD80D[\uDC30-\uDC40\uDC47-\uDFFF]|\uD811[\uDE47-\uDFFF]|\uD81A[\uDE39-\uDE3F\uDE5F-\uDE6F\uDEBF-\uDECF\uDEEE-\uDEFF\uDF30-\uDF3F\uDF44-\uDF62\uDF78-\uDF7C\uDF90-\uDFFF]|\uD81B[\uDC00-\uDE3F\uDE80-\uDEFF\uDF4B-\uDF4F\uDF51-\uDF92\uDFA0-\uDFDF\uDFE2\uDFE4-\uDFFF]|\uD821[\uDFF8-\uDFFF]|\uD823[\uDCD6-\uDCFF\uDD09-\uDFFF]|\uD82B[\uDC00-\uDFEF\uDFF4\uDFFC\uDFFF]|\uD82C[\uDD23-\uDD31\uDD33-\uDD4F\uDD53\uDD54\uDD56-\uDD63\uDD68-\uDD6F\uDEFC-\uDFFF]|\uD82F[\uDC6B-\uDC6F\uDC7D-\uDC7F\uDC89-\uDC8F\uDC9A-\uDFFF]|\uD835[\uDC55\uDC9D\uDCA0\uDCA1\uDCA3\uDCA4\uDCA7\uDCA8\uDCAD\uDCBA\uDCBC\uDCC4\uDD06\uDD0B\uDD0C\uDD15\uDD1D\uDD3A\uDD3F\uDD45\uDD47-\uDD49\uDD51\uDEA6\uDEA7\uDEC1\uDEDB\uDEFB\uDF15\uDF35\uDF4F\uDF6F\uDF89\uDFA9\uDFC3\uDFCC-\uDFFF]|\uD837[\uDC00-\uDEFF\uDF1F-\uDF24\uDF2B-\uDFFF]|\uD838[\uDC00-\uDC2F\uDC6E-\uDCFF\uDD2D-\uDD36\uDD3E-\uDD4D\uDD4F-\uDE8F\uDEAE-\uDEBF\uDEEC-\uDFFF]|\uD839[\uDC00-\uDCCF\uDCEC-\uDFDF\uDFE7\uDFEC\uDFEF\uDFFF]|\uD83A[\uDCC5-\uDCFF\uDD44-\uDD4A\uDD4C-\uDFFF]|\uD83B[\uDC00-\uDDFF\uDE04\uDE20\uDE23\uDE25\uDE26\uDE28\uDE33\uDE38\uDE3A\uDE3C-\uDE41\uDE43-\uDE46\uDE48\uDE4A\uDE4C\uDE50\uDE53\uDE55\uDE56\uDE58\uDE5A\uDE5C\uDE5E\uDE60\uDE63\uDE65\uDE66\uDE6B\uDE73\uDE78\uDE7D\uDE7F\uDE8A\uDE9C-\uDEA0\uDEA4\uDEAA\uDEBC-\uDFFF]|\uD869[\uDEE0-\uDEFF]|\uD86D[\uDF3A-\uDF3F]|\uD86E[\uDC1E\uDC1F]|\uD873[\uDEA2-\uDEAF]|\uD87A[\uDFE1-\uDFEF]|\uD87B[\uDE5E-\uDFFF]|\uD87E[\uDE1E-\uDFFF]|\uD884[\uDF4B-\uDF4F]|\uD888[\uDFB0-\uDFFF]|[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?:[^\uD800-\uDBFF]|^)[\uDC00-\uDFFF])/g)).pop();
  if (lastWordEnd !== undefined && lastWordEnd.index > 1) {
    after = after.slice(0, lastWordEnd.index + 1);
  }
  return {
    highlight,
    before,
    after
  };
}
function createOrderedRange(startNode, startOffset, endNode, endOffset) {
  const range = new Range();
  range.setStart(startNode, startOffset);
  range.setEnd(endNode, endOffset);
  if (!range.collapsed) {
    return range;
  }
  log(">>> createOrderedRange COLLAPSED ... RANGE REVERSE?");
  const rangeReverse = new Range();
  rangeReverse.setStart(endNode, endOffset);
  rangeReverse.setEnd(startNode, startOffset);
  if (!rangeReverse.collapsed) {
    log(">>> createOrderedRange RANGE REVERSE OK.");
    return range;
  }
  log(">>> createOrderedRange RANGE REVERSE ALSO COLLAPSED?!");
  return undefined;
}
function convertRangeInfo(document, rangeInfo) {
  const startElement = document.querySelector(rangeInfo.startContainerElementCssSelector);
  if (!startElement) {
    log("^^^ convertRangeInfo NO START ELEMENT CSS SELECTOR?!");
    return undefined;
  }
  let startContainer = startElement;
  if (rangeInfo.startContainerChildTextNodeIndex >= 0) {
    if (rangeInfo.startContainerChildTextNodeIndex >= startElement.childNodes.length) {
      log("^^^ convertRangeInfo rangeInfo.startContainerChildTextNodeIndex >= startElement.childNodes.length?!");
      return undefined;
    }
    startContainer = startElement.childNodes[rangeInfo.startContainerChildTextNodeIndex];
    if (startContainer.nodeType !== Node.TEXT_NODE) {
      log("^^^ convertRangeInfo startContainer.nodeType !== Node.TEXT_NODE?!");
      return undefined;
    }
  }
  const endElement = document.querySelector(rangeInfo.endContainerElementCssSelector);
  if (!endElement) {
    log("^^^ convertRangeInfo NO END ELEMENT CSS SELECTOR?!");
    return undefined;
  }
  let endContainer = endElement;
  if (rangeInfo.endContainerChildTextNodeIndex >= 0) {
    if (rangeInfo.endContainerChildTextNodeIndex >= endElement.childNodes.length) {
      log("^^^ convertRangeInfo rangeInfo.endContainerChildTextNodeIndex >= endElement.childNodes.length?!");
      return undefined;
    }
    endContainer = endElement.childNodes[rangeInfo.endContainerChildTextNodeIndex];
    if (endContainer.nodeType !== Node.TEXT_NODE) {
      log("^^^ convertRangeInfo endContainer.nodeType !== Node.TEXT_NODE?!");
      return undefined;
    }
  }
  return createOrderedRange(startContainer, rangeInfo.startOffset, endContainer, rangeInfo.endOffset);
}
function location2RangeInfo(location) {
  const locations = location.locations;
  const domRange = locations.domRange;
  const start = domRange.start;
  const end = domRange.end;
  return {
    endContainerChildTextNodeIndex: end.textNodeIndex,
    endContainerElementCssSelector: end.cssSelector,
    endOffset: end.offset,
    startContainerChildTextNodeIndex: start.textNodeIndex,
    startContainerElementCssSelector: start.cssSelector,
    startOffset: start.offset
  };
}
function log() {
  if (debug) {
    _utils__WEBPACK_IMPORTED_MODULE_0__.log.apply(null, arguments);
  }
}

/***/ }),

/***/ "./src/utils.js":
/*!**********************!*\
  !*** ./src/utils.js ***!
  \**********************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   getColumnCountPerScreen: () => (/* binding */ getColumnCountPerScreen),
/* harmony export */   isScrollModeEnabled: () => (/* binding */ isScrollModeEnabled),
/* harmony export */   log: () => (/* binding */ log),
/* harmony export */   logError: () => (/* binding */ logError),
/* harmony export */   logErrorMessage: () => (/* binding */ logErrorMessage),
/* harmony export */   rangeFromLocator: () => (/* binding */ rangeFromLocator),
/* harmony export */   removeProperty: () => (/* binding */ removeProperty),
/* harmony export */   scrollLeft: () => (/* binding */ scrollLeft),
/* harmony export */   scrollRight: () => (/* binding */ scrollRight),
/* harmony export */   scrollToId: () => (/* binding */ scrollToId),
/* harmony export */   scrollToPosition: () => (/* binding */ scrollToPosition),
/* harmony export */   scrollToText: () => (/* binding */ scrollToText),
/* harmony export */   setCSSProperties: () => (/* binding */ setCSSProperties),
/* harmony export */   setProperty: () => (/* binding */ setProperty)
/* harmony export */ });
/* harmony import */ var _vendor_hypothesis_anchoring_types__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./vendor/hypothesis/anchoring/types */ "./src/vendor/hypothesis/anchoring/types.js");
/* harmony import */ var _selection__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./selection */ "./src/selection.js");
//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

// Catch JS errors to log them in the app.



window.addEventListener("error", function (event) {
  webkit.messageHandlers.logError.postMessage({
    message: event.message,
    filename: event.filename,
    line: event.lineno
  });
}, false);

// Notify native code that the page has loaded.
window.addEventListener("load", function () {
  const observer = new ResizeObserver(() => {
    appendVirtualColumnIfNeeded();
  });
  observer.observe(document.body);

  // on page load
  window.addEventListener("orientationchange", function () {
    orientationChanged();
    snapCurrentPosition();
  });
  orientationChanged();
}, false);

/**
 * Having an odd number of columns when displaying two columns per screen causes snapping and page
 * turning issues. To fix this, we insert a blank virtual column at the end of the resource.
 */
function appendVirtualColumnIfNeeded() {
  const id = "readium-virtual-page";
  var virtualCol = document.getElementById(id);
  if (isScrollModeEnabled() || getColumnCountPerScreen() != 2) {
    var _virtualCol;
    (_virtualCol = virtualCol) === null || _virtualCol === void 0 || _virtualCol.remove();
  } else {
    var documentWidth = document.scrollingElement.scrollWidth;
    var pageWidth = window.innerWidth;
    var colCount = documentWidth / pageWidth;
    var hasOddColCount = Math.round(colCount * 2) / 2 % 1 > 0.1;
    if (hasOddColCount) {
      if (virtualCol) {
        virtualCol.remove();
      } else {
        virtualCol = document.createElement("div");
        virtualCol.setAttribute("id", id);
        virtualCol.style.breakBefore = "column";
        virtualCol.innerHTML = "&#8203;"; // zero-width space
        document.body.appendChild(virtualCol);
      }
    }
  }
}
var last_known_scrollX_position = 0;
var last_known_scrollY_position = 0;
var ticking = false;
var maxScreenX = 0;

// Position in range [0 - 1].
function update(position) {
  var positionString = position.toString();
  webkit.messageHandlers.progressionChanged.postMessage(positionString);
}
window.addEventListener("scroll", function () {
  last_known_scrollY_position = window.scrollY / document.scrollingElement.scrollHeight;
  // Using Math.abs because for RTL books, the value will be negative.
  last_known_scrollX_position = Math.abs(window.scrollX / document.scrollingElement.scrollWidth);

  // Window is hidden
  if (document.scrollingElement.scrollWidth === 0 || document.scrollingElement.scrollHeight === 0) {
    return;
  }
  if (!ticking) {
    window.requestAnimationFrame(function () {
      update(isScrollModeEnabled() ? last_known_scrollY_position : last_known_scrollX_position);
      ticking = false;
    });
  }
  ticking = true;
});
document.addEventListener("selectionchange", debounce(50, function () {
  webkit.messageHandlers.selectionChanged.postMessage((0,_selection__WEBPACK_IMPORTED_MODULE_1__.getCurrentSelection)());
}));
function orientationChanged() {
  maxScreenX = window.orientation === 0 || window.orientation == 180 ? screen.width : screen.height;
}
function getColumnCountPerScreen() {
  return parseInt(window.getComputedStyle(document.documentElement).getPropertyValue("column-count"));
}
function isScrollModeEnabled() {
  const style = document.documentElement.style;
  return style.getPropertyValue("--USER__view").trim() == "readium-scroll-on" ||
  // FIXME: Will need to be removed in Readium 3.0, --USER__scroll was incorrect.
  style.getPropertyValue("--USER__scroll").trim() == "readium-scroll-on";
}

// Scroll to the given TagId in document and snap.
function scrollToId(id) {
  let element = document.getElementById(id);
  if (!element) {
    return false;
  }
  scrollToRect(element.getBoundingClientRect());
  return true;
}

// Position must be in the range [0 - 1], 0-100%.
function scrollToPosition(position, dir) {
  console.log("ScrollToPosition");
  if (position < 0 || position > 1) {
    console.log("InvalidPosition");
    return;
  }
  if (isScrollModeEnabled()) {
    let offset = document.scrollingElement.scrollHeight * position;
    document.scrollingElement.scrollTop = offset;
    // window.scrollTo(0, offset);
  } else {
    var documentWidth = document.scrollingElement.scrollWidth;
    var factor = dir == "rtl" ? -1 : 1;
    let offset = documentWidth * position * factor;
    document.scrollingElement.scrollLeft = snapOffset(offset);
  }
}

// Scrolls to the first occurrence of the given text snippet.
//
// The expected text argument is a Locator Text object, as defined here:
// https://readium.org/architecture/models/locators/
function scrollToText(text) {
  let range = rangeFromLocator({
    text
  });
  if (!range) {
    return false;
  }
  return scrollToRange(range);
}
function scrollToRange(range) {
  return scrollToRect(range.getBoundingClientRect());
}
function scrollToRect(rect) {
  if (isScrollModeEnabled()) {
    document.scrollingElement.scrollTop = rect.top + window.scrollY;
  } else {
    document.scrollingElement.scrollLeft = snapOffset(rect.left + window.scrollX);
  }
  return true;
}

// Returns false if the page is already at the left-most scroll offset.
function scrollLeft(dir) {
  var isRTL = dir == "rtl";
  var documentWidth = document.scrollingElement.scrollWidth;
  var pageWidth = window.innerWidth;
  var offset = window.scrollX - pageWidth;
  var minOffset = isRTL ? -(documentWidth - pageWidth) : 0;
  return scrollToOffset(Math.max(offset, minOffset));
}

// Returns false if the page is already at the right-most scroll offset.
function scrollRight(dir) {
  var isRTL = dir == "rtl";
  var documentWidth = document.scrollingElement.scrollWidth;
  var pageWidth = window.innerWidth;
  var offset = window.scrollX + pageWidth;
  var maxOffset = isRTL ? 0 : documentWidth - pageWidth;
  return scrollToOffset(Math.min(offset, maxOffset));
}

// Scrolls to the given left offset.
// Returns false if the page scroll position is already close enough to the given offset.
function scrollToOffset(offset) {
  var currentOffset = window.scrollX;
  var pageWidth = window.innerWidth;
  document.scrollingElement.scrollLeft = offset;
  // In some case the scrollX cannot reach the position respecting to innerWidth
  var diff = Math.abs(currentOffset - offset) / pageWidth;
  return diff > 0.01;
}

// Snap the offset to the screen width (page width).
function snapOffset(offset) {
  var value = offset + 1;
  return value - value % maxScreenX;
}
function snapCurrentPosition() {
  if (isScrollModeEnabled()) {
    return;
  }
  var currentOffset = window.scrollX;
  var currentOffsetSnapped = snapOffset(currentOffset + 1);
  document.scrollingElement.scrollLeft = currentOffsetSnapped;
}
function rangeFromLocator(locator) {
  try {
    let locations = locator.locations;
    let text = locator.text;
    if (text && text.highlight) {
      var root;
      if (locations && locations.cssSelector) {
        root = document.querySelector(locations.cssSelector);
      }
      if (!root) {
        root = document.body;
      }
      let anchor = new _vendor_hypothesis_anchoring_types__WEBPACK_IMPORTED_MODULE_0__.TextQuoteAnchor(root, text.highlight, {
        prefix: text.before,
        suffix: text.after
      });
      return anchor.toRange();
    }
    if (locations) {
      var element = null;
      if (!element && locations.cssSelector) {
        element = document.querySelector(locations.cssSelector);
      }
      if (!element && locations.fragments) {
        for (const htmlId of locations.fragments) {
          element = document.getElementById(htmlId);
          if (element) {
            break;
          }
        }
      }
      if (element) {
        let range = document.createRange();
        range.setStartBefore(element);
        range.setEndAfter(element);
        return range;
      }
    }
  } catch (e) {
    logError(e);
  }
  return null;
}

/// User Settings.

function setCSSProperties(properties) {
  for (const name in properties) {
    setProperty(name, properties[name]);
  }
}

// For setting user setting.
function setProperty(key, value) {
  if (value === null) {
    removeProperty(key);
  } else {
    var root = document.documentElement;
    // The `!important` annotation is added with `setProperty()` because if
    // it's part of the `value`, it will be ignored by the Web View.
    root.style.setProperty(key, value, "important");
  }
}

// For removing user setting.
function removeProperty(key) {
  var root = document.documentElement;
  root.style.removeProperty(key);
}

/// Toolkit

function debounce(delay, func) {
  var timeout;
  return function () {
    var self = this;
    var args = arguments;
    function callback() {
      func.apply(self, args);
      timeout = null;
    }
    clearTimeout(timeout);
    timeout = setTimeout(callback, delay);
  };
}
function log() {
  var message = Array.prototype.slice.call(arguments).join(" ");
  webkit.messageHandlers.log.postMessage(message);
}
function logErrorMessage(msg) {
  logError(new Error(msg));
}
function logError(e) {
  webkit.messageHandlers.logError.postMessage({
    message: e.message
  });
}

/***/ }),

/***/ "./src/vendor/hypothesis/anchoring/match-quote.js":
/*!********************************************************!*\
  !*** ./src/vendor/hypothesis/anchoring/match-quote.js ***!
  \********************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   matchQuote: () => (/* binding */ matchQuote)
/* harmony export */ });
/* harmony import */ var approx_string_match__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! approx-string-match */ "./node_modules/approx-string-match/dist/index.js");


/**
 * @typedef {import('approx-string-match').Match} StringMatch
 */

/**
 * @typedef Match
 * @prop {number} start - Start offset of match in text
 * @prop {number} end - End offset of match in text
 * @prop {number} score -
 *   Score for the match between 0 and 1.0, where 1.0 indicates a perfect match
 *   for the quote and context.
 */

/**
 * Find the best approximate matches for `str` in `text` allowing up to `maxErrors` errors.
 *
 * @param {string} text
 * @param {string} str
 * @param {number} maxErrors
 * @return {StringMatch[]}
 */
function search(text, str, maxErrors) {
  // Do a fast search for exact matches. The `approx-string-match` library
  // doesn't currently incorporate this optimization itself.
  let matchPos = 0;
  let exactMatches = [];
  while (matchPos !== -1) {
    matchPos = text.indexOf(str, matchPos);
    if (matchPos !== -1) {
      exactMatches.push({
        start: matchPos,
        end: matchPos + str.length,
        errors: 0
      });
      matchPos += 1;
    }
  }
  if (exactMatches.length > 0) {
    return exactMatches;
  }

  // If there are no exact matches, do a more expensive search for matches
  // with errors.
  return (0,approx_string_match__WEBPACK_IMPORTED_MODULE_0__["default"])(text, str, maxErrors);
}

/**
 * Compute a score between 0 and 1.0 for the similarity between `text` and `str`.
 *
 * @param {string} text
 * @param {string} str
 */
function textMatchScore(text, str) {
  /* istanbul ignore next - `scoreMatch` will never pass an empty string */
  if (str.length === 0 || text.length === 0) {
    return 0.0;
  }
  const matches = search(text, str, str.length);

  // prettier-ignore
  return 1 - matches[0].errors / str.length;
}

/**
 * Find the best approximate match for `quote` in `text`.
 *
 * Returns `null` if no match exceeding the minimum quality threshold was found.
 *
 * @param {string} text - Document text to search
 * @param {string} quote - String to find within `text`
 * @param {Object} context -
 *   Context in which the quote originally appeared. This is used to choose the
 *   best match.
 *   @param {string} [context.prefix] - Expected text before the quote
 *   @param {string} [context.suffix] - Expected text after the quote
 *   @param {number} [context.hint] - Expected offset of match within text
 * @return {Match|null}
 */
function matchQuote(text, quote) {
  let context = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : {};
  if (quote.length === 0) {
    return null;
  }

  // Choose the maximum number of errors to allow for the initial search.
  // This choice involves a tradeoff between:
  //
  //  - Recall (proportion of "good" matches found)
  //  - Precision (proportion of matches found which are "good")
  //  - Cost of the initial search and of processing the candidate matches [1]
  //
  // [1] Specifically, the expected-time complexity of the initial search is
  //     `O((maxErrors / 32) * text.length)`. See `approx-string-match` docs.
  const maxErrors = Math.min(256, quote.length / 2);

  // Find closest matches for `quote` in `text` based on edit distance.
  const matches = search(text, quote, maxErrors);
  if (matches.length === 0) {
    return null;
  }

  /**
   * Compute a score between 0 and 1.0 for a match candidate.
   *
   * @param {StringMatch} match
   */
  const scoreMatch = match => {
    const quoteWeight = 50; // Similarity of matched text to quote.
    const prefixWeight = 20; // Similarity of text before matched text to `context.prefix`.
    const suffixWeight = 20; // Similarity of text after matched text to `context.suffix`.
    const posWeight = 2; // Proximity to expected location. Used as a tie-breaker.

    const quoteScore = 1 - match.errors / quote.length;
    const prefixScore = context.prefix ? textMatchScore(text.slice(Math.max(0, match.start - context.prefix.length), match.start), context.prefix) : 1.0;
    const suffixScore = context.suffix ? textMatchScore(text.slice(match.end, match.end + context.suffix.length), context.suffix) : 1.0;
    let posScore = 1.0;
    if (typeof context.hint === 'number') {
      const offset = Math.abs(match.start - context.hint);
      posScore = 1.0 - offset / text.length;
    }
    const rawScore = quoteWeight * quoteScore + prefixWeight * prefixScore + suffixWeight * suffixScore + posWeight * posScore;
    const maxScore = quoteWeight + prefixWeight + suffixWeight + posWeight;
    const normalizedScore = rawScore / maxScore;
    return normalizedScore;
  };

  // Rank matches based on similarity of actual and expected surrounding text
  // and actual/expected offset in the document text.
  const scoredMatches = matches.map(m => ({
    start: m.start,
    end: m.end,
    score: scoreMatch(m)
  }));

  // Choose match with highest score.
  scoredMatches.sort((a, b) => b.score - a.score);
  return scoredMatches[0];
}

/***/ }),

/***/ "./src/vendor/hypothesis/anchoring/text-range.js":
/*!*******************************************************!*\
  !*** ./src/vendor/hypothesis/anchoring/text-range.js ***!
  \*******************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   RESOLVE_BACKWARDS: () => (/* binding */ RESOLVE_BACKWARDS),
/* harmony export */   RESOLVE_FORWARDS: () => (/* binding */ RESOLVE_FORWARDS),
/* harmony export */   TextPosition: () => (/* binding */ TextPosition),
/* harmony export */   TextRange: () => (/* binding */ TextRange)
/* harmony export */ });
/**
 * Return the combined length of text nodes contained in `node`.
 *
 * @param {Node} node
 */
function nodeTextLength(node) {
  switch (node.nodeType) {
    case Node.ELEMENT_NODE:
    case Node.TEXT_NODE:
      // nb. `textContent` excludes text in comments and processing instructions
      // when called on a parent element, so we don't need to subtract that here.

      return (/** @type {string} */node.textContent.length
      );
    default:
      return 0;
  }
}

/**
 * Return the total length of the text of all previous siblings of `node`.
 *
 * @param {Node} node
 */
function previousSiblingsTextLength(node) {
  let sibling = node.previousSibling;
  let length = 0;
  while (sibling) {
    length += nodeTextLength(sibling);
    sibling = sibling.previousSibling;
  }
  return length;
}

/**
 * Resolve one or more character offsets within an element to (text node, position)
 * pairs.
 *
 * @param {Element} element
 * @param {number[]} offsets - Offsets, which must be sorted in ascending order
 * @return {{ node: Text, offset: number }[]}
 */
function resolveOffsets(element) {
  for (var _len = arguments.length, offsets = new Array(_len > 1 ? _len - 1 : 0), _key = 1; _key < _len; _key++) {
    offsets[_key - 1] = arguments[_key];
  }
  let nextOffset = offsets.shift();
  const nodeIter = /** @type {Document} */element.ownerDocument.createNodeIterator(element, NodeFilter.SHOW_TEXT);
  const results = [];
  let currentNode = nodeIter.nextNode();
  let textNode;
  let length = 0;

  // Find the text node containing the `nextOffset`th character from the start
  // of `element`.
  while (nextOffset !== undefined && currentNode) {
    textNode = /** @type {Text} */currentNode;
    if (length + textNode.data.length > nextOffset) {
      results.push({
        node: textNode,
        offset: nextOffset - length
      });
      nextOffset = offsets.shift();
    } else {
      currentNode = nodeIter.nextNode();
      length += textNode.data.length;
    }
  }

  // Boundary case.
  while (nextOffset !== undefined && textNode && length === nextOffset) {
    results.push({
      node: textNode,
      offset: textNode.data.length
    });
    nextOffset = offsets.shift();
  }
  if (nextOffset !== undefined) {
    throw new RangeError('Offset exceeds text length');
  }
  return results;
}
let RESOLVE_FORWARDS = 1;
let RESOLVE_BACKWARDS = 2;

/**
 * Represents an offset within the text content of an element.
 *
 * This position can be resolved to a specific descendant node in the current
 * DOM subtree of the element using the `resolve` method.
 */
class TextPosition {
  /**
   * Construct a `TextPosition` that refers to the text position `offset` within
   * the text content of `element`.
   *
   * @param {Element} element
   * @param {number} offset
   */
  constructor(element, offset) {
    if (offset < 0) {
      throw new Error('Offset is invalid');
    }

    /** Element that `offset` is relative to. */
    this.element = element;

    /** Character offset from the start of the element's `textContent`. */
    this.offset = offset;
  }

  /**
   * Return a copy of this position with offset relative to a given ancestor
   * element.
   *
   * @param {Element} parent - Ancestor of `this.element`
   * @return {TextPosition}
   */
  relativeTo(parent) {
    if (!parent.contains(this.element)) {
      throw new Error('Parent is not an ancestor of current element');
    }
    let el = this.element;
    let offset = this.offset;
    while (el !== parent) {
      offset += previousSiblingsTextLength(el);
      el = /** @type {Element} */el.parentElement;
    }
    return new TextPosition(el, offset);
  }

  /**
   * Resolve the position to a specific text node and offset within that node.
   *
   * Throws if `this.offset` exceeds the length of the element's text. In the
   * case where the element has no text and `this.offset` is 0, the `direction`
   * option determines what happens.
   *
   * Offsets at the boundary between two nodes are resolved to the start of the
   * node that begins at the boundary.
   *
   * @param {Object} [options]
   *   @param {RESOLVE_FORWARDS|RESOLVE_BACKWARDS} [options.direction] -
   *     Specifies in which direction to search for the nearest text node if
   *     `this.offset` is `0` and `this.element` has no text. If not specified
   *     an error is thrown.
   * @return {{ node: Text, offset: number }}
   * @throws {RangeError}
   */
  resolve() {
    let options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
    try {
      return resolveOffsets(this.element, this.offset)[0];
    } catch (err) {
      if (this.offset === 0 && options.direction !== undefined) {
        const tw = document.createTreeWalker(this.element.getRootNode(), NodeFilter.SHOW_TEXT);
        tw.currentNode = this.element;
        const forwards = options.direction === RESOLVE_FORWARDS;
        const text = /** @type {Text|null} */
        forwards ? tw.nextNode() : tw.previousNode();
        if (!text) {
          throw err;
        }
        return {
          node: text,
          offset: forwards ? 0 : text.data.length
        };
      } else {
        throw err;
      }
    }
  }

  /**
   * Construct a `TextPosition` that refers to the `offset`th character within
   * `node`.
   *
   * @param {Node} node
   * @param {number} offset
   * @return {TextPosition}
   */
  static fromCharOffset(node, offset) {
    switch (node.nodeType) {
      case Node.TEXT_NODE:
        return TextPosition.fromPoint(node, offset);
      case Node.ELEMENT_NODE:
        return new TextPosition( /** @type {Element} */node, offset);
      default:
        throw new Error('Node is not an element or text node');
    }
  }

  /**
   * Construct a `TextPosition` representing the range start or end point (node, offset).
   *
   * @param {Node} node - Text or Element node
   * @param {number} offset - Offset within the node.
   * @return {TextPosition}
   */
  static fromPoint(node, offset) {
    switch (node.nodeType) {
      case Node.TEXT_NODE:
        {
          if (offset < 0 || offset > /** @type {Text} */node.data.length) {
            throw new Error('Text node offset is out of range');
          }
          if (!node.parentElement) {
            throw new Error('Text node has no parent');
          }

          // Get the offset from the start of the parent element.
          const textOffset = previousSiblingsTextLength(node) + offset;
          return new TextPosition(node.parentElement, textOffset);
        }
      case Node.ELEMENT_NODE:
        {
          if (offset < 0 || offset > node.childNodes.length) {
            throw new Error('Child node offset is out of range');
          }

          // Get the text length before the `offset`th child of element.
          let textOffset = 0;
          for (let i = 0; i < offset; i++) {
            textOffset += nodeTextLength(node.childNodes[i]);
          }
          return new TextPosition( /** @type {Element} */node, textOffset);
        }
      default:
        throw new Error('Point is not in an element or text node');
    }
  }
}

/**
 * Represents a region of a document as a (start, end) pair of `TextPosition` points.
 *
 * Representing a range in this way allows for changes in the DOM content of the
 * range which don't affect its text content, without affecting the text content
 * of the range itself.
 */
class TextRange {
  /**
   * Construct an immutable `TextRange` from a `start` and `end` point.
   *
   * @param {TextPosition} start
   * @param {TextPosition} end
   */
  constructor(start, end) {
    this.start = start;
    this.end = end;
  }

  /**
   * Return a copy of this range with start and end positions relative to a
   * given ancestor. See `TextPosition.relativeTo`.
   *
   * @param {Element} element
   */
  relativeTo(element) {
    return new TextRange(this.start.relativeTo(element), this.end.relativeTo(element));
  }

  /**
   * Resolve the `TextRange` to a DOM range.
   *
   * The resulting DOM Range will always start and end in a `Text` node.
   * Hence `TextRange.fromRange(range).toRange()` can be used to "shrink" a
   * range to the text it contains.
   *
   * May throw if the `start` or `end` positions cannot be resolved to a range.
   *
   * @return {Range}
   */
  toRange() {
    let start;
    let end;
    if (this.start.element === this.end.element && this.start.offset <= this.end.offset) {
      // Fast path for start and end points in same element.
      [start, end] = resolveOffsets(this.start.element, this.start.offset, this.end.offset);
    } else {
      start = this.start.resolve({
        direction: RESOLVE_FORWARDS
      });
      end = this.end.resolve({
        direction: RESOLVE_BACKWARDS
      });
    }
    const range = new Range();
    range.setStart(start.node, start.offset);
    range.setEnd(end.node, end.offset);
    return range;
  }

  /**
   * Convert an existing DOM `Range` to a `TextRange`
   *
   * @param {Range} range
   * @return {TextRange}
   */
  static fromRange(range) {
    const start = TextPosition.fromPoint(range.startContainer, range.startOffset);
    const end = TextPosition.fromPoint(range.endContainer, range.endOffset);
    return new TextRange(start, end);
  }

  /**
   * Return a `TextRange` from the `start`th to `end`th characters in `root`.
   *
   * @param {Element} root
   * @param {number} start
   * @param {number} end
   */
  static fromOffsets(root, start, end) {
    return new TextRange(new TextPosition(root, start), new TextPosition(root, end));
  }
}

/***/ }),

/***/ "./src/vendor/hypothesis/anchoring/types.js":
/*!**************************************************!*\
  !*** ./src/vendor/hypothesis/anchoring/types.js ***!
  \**************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   RangeAnchor: () => (/* binding */ RangeAnchor),
/* harmony export */   TextPositionAnchor: () => (/* binding */ TextPositionAnchor),
/* harmony export */   TextQuoteAnchor: () => (/* binding */ TextQuoteAnchor)
/* harmony export */ });
/* harmony import */ var _match_quote__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./match-quote */ "./src/vendor/hypothesis/anchoring/match-quote.js");
/* harmony import */ var _text_range__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./text-range */ "./src/vendor/hypothesis/anchoring/text-range.js");
/* harmony import */ var _xpath__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./xpath */ "./src/vendor/hypothesis/anchoring/xpath.js");
function ownKeys(e, r) { var t = Object.keys(e); if (Object.getOwnPropertySymbols) { var o = Object.getOwnPropertySymbols(e); r && (o = o.filter(function (r) { return Object.getOwnPropertyDescriptor(e, r).enumerable; })), t.push.apply(t, o); } return t; }
function _objectSpread(e) { for (var r = 1; r < arguments.length; r++) { var t = null != arguments[r] ? arguments[r] : {}; r % 2 ? ownKeys(Object(t), !0).forEach(function (r) { _defineProperty(e, r, t[r]); }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(e, Object.getOwnPropertyDescriptors(t)) : ownKeys(Object(t)).forEach(function (r) { Object.defineProperty(e, r, Object.getOwnPropertyDescriptor(t, r)); }); } return e; }
function _defineProperty(obj, key, value) { key = _toPropertyKey(key); if (key in obj) { Object.defineProperty(obj, key, { value: value, enumerable: true, configurable: true, writable: true }); } else { obj[key] = value; } return obj; }
function _toPropertyKey(arg) { var key = _toPrimitive(arg, "string"); return typeof key === "symbol" ? key : String(key); }
function _toPrimitive(input, hint) { if (typeof input !== "object" || input === null) return input; var prim = input[Symbol.toPrimitive]; if (prim !== undefined) { var res = prim.call(input, hint || "default"); if (typeof res !== "object") return res; throw new TypeError("@@toPrimitive must return a primitive value."); } return (hint === "string" ? String : Number)(input); }
/**
 * This module exports a set of classes for converting between DOM `Range`
 * objects and different types of selectors. It is mostly a thin wrapper around a
 * set of anchoring libraries. It serves two main purposes:
 *
 *  1. Providing a consistent interface across different types of anchors.
 *  2. Insulating the rest of the code from API changes in the underlying anchoring
 *     libraries.
 */





/**
 * @typedef {import('../../types/api').RangeSelector} RangeSelector
 * @typedef {import('../../types/api').TextPositionSelector} TextPositionSelector
 * @typedef {import('../../types/api').TextQuoteSelector} TextQuoteSelector
 */

/**
 * Converts between `RangeSelector` selectors and `Range` objects.
 */
class RangeAnchor {
  /**
   * @param {Node} root - A root element from which to anchor.
   * @param {Range} range -  A range describing the anchor.
   */
  constructor(root, range) {
    this.root = root;
    this.range = range;
  }

  /**
   * @param {Node} root -  A root element from which to anchor.
   * @param {Range} range -  A range describing the anchor.
   */
  static fromRange(root, range) {
    return new RangeAnchor(root, range);
  }

  /**
   * Create an anchor from a serialized `RangeSelector` selector.
   *
   * @param {Element} root -  A root element from which to anchor.
   * @param {RangeSelector} selector
   */
  static fromSelector(root, selector) {
    const startContainer = (0,_xpath__WEBPACK_IMPORTED_MODULE_2__.nodeFromXPath)(selector.startContainer, root);
    if (!startContainer) {
      throw new Error('Failed to resolve startContainer XPath');
    }
    const endContainer = (0,_xpath__WEBPACK_IMPORTED_MODULE_2__.nodeFromXPath)(selector.endContainer, root);
    if (!endContainer) {
      throw new Error('Failed to resolve endContainer XPath');
    }
    const startPos = _text_range__WEBPACK_IMPORTED_MODULE_1__.TextPosition.fromCharOffset(startContainer, selector.startOffset);
    const endPos = _text_range__WEBPACK_IMPORTED_MODULE_1__.TextPosition.fromCharOffset(endContainer, selector.endOffset);
    const range = new _text_range__WEBPACK_IMPORTED_MODULE_1__.TextRange(startPos, endPos).toRange();
    return new RangeAnchor(root, range);
  }
  toRange() {
    return this.range;
  }

  /**
   * @return {RangeSelector}
   */
  toSelector() {
    // "Shrink" the range so that it tightly wraps its text. This ensures more
    // predictable output for a given text selection.
    const normalizedRange = _text_range__WEBPACK_IMPORTED_MODULE_1__.TextRange.fromRange(this.range).toRange();
    const textRange = _text_range__WEBPACK_IMPORTED_MODULE_1__.TextRange.fromRange(normalizedRange);
    const startContainer = (0,_xpath__WEBPACK_IMPORTED_MODULE_2__.xpathFromNode)(textRange.start.element, this.root);
    const endContainer = (0,_xpath__WEBPACK_IMPORTED_MODULE_2__.xpathFromNode)(textRange.end.element, this.root);
    return {
      type: 'RangeSelector',
      startContainer,
      startOffset: textRange.start.offset,
      endContainer,
      endOffset: textRange.end.offset
    };
  }
}

/**
 * Converts between `TextPositionSelector` selectors and `Range` objects.
 */
class TextPositionAnchor {
  /**
   * @param {Element} root
   * @param {number} start
   * @param {number} end
   */
  constructor(root, start, end) {
    this.root = root;
    this.start = start;
    this.end = end;
  }

  /**
   * @param {Element} root
   * @param {Range} range
   */
  static fromRange(root, range) {
    const textRange = _text_range__WEBPACK_IMPORTED_MODULE_1__.TextRange.fromRange(range).relativeTo(root);
    return new TextPositionAnchor(root, textRange.start.offset, textRange.end.offset);
  }
  /**
   * @param {Element} root
   * @param {TextPositionSelector} selector
   */
  static fromSelector(root, selector) {
    return new TextPositionAnchor(root, selector.start, selector.end);
  }

  /**
   * @return {TextPositionSelector}
   */
  toSelector() {
    return {
      type: 'TextPositionSelector',
      start: this.start,
      end: this.end
    };
  }
  toRange() {
    return _text_range__WEBPACK_IMPORTED_MODULE_1__.TextRange.fromOffsets(this.root, this.start, this.end).toRange();
  }
}

/**
 * @typedef QuoteMatchOptions
 * @prop {number} [hint] - Expected position of match in text. See `matchQuote`.
 */

/**
 * Converts between `TextQuoteSelector` selectors and `Range` objects.
 */
class TextQuoteAnchor {
  /**
   * @param {Element} root - A root element from which to anchor.
   * @param {string} exact
   * @param {Object} context
   *   @param {string} [context.prefix]
   *   @param {string} [context.suffix]
   */
  constructor(root, exact) {
    let context = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : {};
    this.root = root;
    this.exact = exact;
    this.context = context;
  }

  /**
   * Create a `TextQuoteAnchor` from a range.
   *
   * Will throw if `range` does not contain any text nodes.
   *
   * @param {Element} root
   * @param {Range} range
   */
  static fromRange(root, range) {
    const text = /** @type {string} */root.textContent;
    const textRange = _text_range__WEBPACK_IMPORTED_MODULE_1__.TextRange.fromRange(range).relativeTo(root);
    const start = textRange.start.offset;
    const end = textRange.end.offset;

    // Number of characters around the quote to capture as context. We currently
    // always use a fixed amount, but it would be better if this code was aware
    // of logical boundaries in the document (paragraph, article etc.) to avoid
    // capturing text unrelated to the quote.
    //
    // In regular prose the ideal content would often be the surrounding sentence.
    // This is a natural unit of meaning which enables displaying quotes in
    // context even when the document is not available. We could use `Intl.Segmenter`
    // for this when available.
    const contextLen = 32;
    return new TextQuoteAnchor(root, text.slice(start, end), {
      prefix: text.slice(Math.max(0, start - contextLen), start),
      suffix: text.slice(end, Math.min(text.length, end + contextLen))
    });
  }

  /**
   * @param {Element} root
   * @param {TextQuoteSelector} selector
   */
  static fromSelector(root, selector) {
    const {
      prefix,
      suffix
    } = selector;
    return new TextQuoteAnchor(root, selector.exact, {
      prefix,
      suffix
    });
  }

  /**
   * @return {TextQuoteSelector}
   */
  toSelector() {
    return {
      type: 'TextQuoteSelector',
      exact: this.exact,
      prefix: this.context.prefix,
      suffix: this.context.suffix
    };
  }

  /**
   * @param {QuoteMatchOptions} [options]
   */
  toRange() {
    let options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
    return this.toPositionAnchor(options).toRange();
  }

  /**
   * @param {QuoteMatchOptions} [options]
   */
  toPositionAnchor() {
    let options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
    const text = /** @type {string} */this.root.textContent;
    const match = (0,_match_quote__WEBPACK_IMPORTED_MODULE_0__.matchQuote)(text, this.exact, _objectSpread(_objectSpread({}, this.context), {}, {
      hint: options.hint
    }));
    if (!match) {
      throw new Error('Quote not found');
    }
    return new TextPositionAnchor(this.root, match.start, match.end);
  }
}

/***/ }),

/***/ "./src/vendor/hypothesis/anchoring/xpath.js":
/*!**************************************************!*\
  !*** ./src/vendor/hypothesis/anchoring/xpath.js ***!
  \**************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   nodeFromXPath: () => (/* binding */ nodeFromXPath),
/* harmony export */   xpathFromNode: () => (/* binding */ xpathFromNode)
/* harmony export */ });
/**
 * Get the node name for use in generating an xpath expression.
 *
 * @param {Node} node
 */
function getNodeName(node) {
  const nodeName = node.nodeName.toLowerCase();
  let result = nodeName;
  if (nodeName === '#text') {
    result = 'text()';
  }
  return result;
}

/**
 * Get the index of the node as it appears in its parent's child list
 *
 * @param {Node} node
 */
function getNodePosition(node) {
  let pos = 0;
  /** @type {Node|null} */
  let tmp = node;
  while (tmp) {
    if (tmp.nodeName === node.nodeName) {
      pos += 1;
    }
    tmp = tmp.previousSibling;
  }
  return pos;
}
function getPathSegment(node) {
  const name = getNodeName(node);
  const pos = getNodePosition(node);
  return "".concat(name, "[").concat(pos, "]");
}

/**
 * A simple XPath generator which can generate XPaths of the form
 * /tag[index]/tag[index].
 *
 * @param {Node} node - The node to generate a path to
 * @param {Node} root - Root node to which the returned path is relative
 */
function xpathFromNode(node, root) {
  let xpath = '';

  /** @type {Node|null} */
  let elem = node;
  while (elem !== root) {
    if (!elem) {
      throw new Error('Node is not a descendant of root');
    }
    xpath = getPathSegment(elem) + '/' + xpath;
    elem = elem.parentNode;
  }
  xpath = '/' + xpath;
  xpath = xpath.replace(/\/$/, ''); // Remove trailing slash

  return xpath;
}

/**
 * Return the `index`'th immediate child of `element` whose tag name is
 * `nodeName` (case insensitive).
 *
 * @param {Element} element
 * @param {string} nodeName
 * @param {number} index
 */
function nthChildOfType(element, nodeName, index) {
  nodeName = nodeName.toUpperCase();
  let matchIndex = -1;
  for (let i = 0; i < element.children.length; i++) {
    const child = element.children[i];
    if (child.nodeName.toUpperCase() === nodeName) {
      ++matchIndex;
      if (matchIndex === index) {
        return child;
      }
    }
  }
  return null;
}

/**
 * Evaluate a _simple XPath_ relative to a `root` element and return the
 * matching element.
 *
 * A _simple XPath_ is a sequence of one or more `/tagName[index]` strings.
 *
 * Unlike `document.evaluate` this function:
 *
 *  - Only supports simple XPaths
 *  - Is not affected by the document's _type_ (HTML or XML/XHTML)
 *  - Ignores element namespaces when matching element names in the XPath against
 *    elements in the DOM tree
 *  - Is case insensitive for all elements, not just HTML elements
 *
 * The matching element is returned or `null` if no such element is found.
 * An error is thrown if `xpath` is not a simple XPath.
 *
 * @param {string} xpath
 * @param {Element} root
 * @return {Element|null}
 */
function evaluateSimpleXPath(xpath, root) {
  const isSimpleXPath = xpath.match(/^(\/[A-Za-z0-9-]+(\[[0-9]+\])?)+$/) !== null;
  if (!isSimpleXPath) {
    throw new Error('Expression is not a simple XPath');
  }
  const segments = xpath.split('/');
  let element = root;

  // Remove leading empty segment. The regex above validates that the XPath
  // has at least two segments, with the first being empty and the others non-empty.
  segments.shift();
  for (let segment of segments) {
    let elementName;
    let elementIndex;
    const separatorPos = segment.indexOf('[');
    if (separatorPos !== -1) {
      elementName = segment.slice(0, separatorPos);
      const indexStr = segment.slice(separatorPos + 1, segment.indexOf(']'));
      elementIndex = parseInt(indexStr) - 1;
      if (elementIndex < 0) {
        return null;
      }
    } else {
      elementName = segment;
      elementIndex = 0;
    }
    const child = nthChildOfType(element, elementName, elementIndex);
    if (!child) {
      return null;
    }
    element = child;
  }
  return element;
}

/**
 * Finds an element node using an XPath relative to `root`
 *
 * Example:
 *   node = nodeFromXPath('/main/article[1]/p[3]', document.body)
 *
 * @param {string} xpath
 * @param {Element} [root]
 * @return {Node|null}
 */
function nodeFromXPath(xpath) {
  let root = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : document.body;
  try {
    return evaluateSimpleXPath(xpath, root);
  } catch (err) {
    return document.evaluate('.' + xpath, root,
    // nb. The `namespaceResolver` and `result` arguments are optional in the spec
    // but required in Edge Legacy.
    null /* namespaceResolver */, XPathResult.FIRST_ORDERED_NODE_TYPE, null /* result */).singleNodeValue;
  }
}

/***/ }),

/***/ "./node_modules/call-bind/callBound.js":
/*!*********************************************!*\
  !*** ./node_modules/call-bind/callBound.js ***!
  \*********************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var callBind = __webpack_require__(/*! ./ */ "./node_modules/call-bind/index.js");

var $indexOf = callBind(GetIntrinsic('String.prototype.indexOf'));

module.exports = function callBoundIntrinsic(name, allowMissing) {
	var intrinsic = GetIntrinsic(name, !!allowMissing);
	if (typeof intrinsic === 'function' && $indexOf(name, '.prototype.') > -1) {
		return callBind(intrinsic);
	}
	return intrinsic;
};


/***/ }),

/***/ "./node_modules/call-bind/index.js":
/*!*****************************************!*\
  !*** ./node_modules/call-bind/index.js ***!
  \*****************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var bind = __webpack_require__(/*! function-bind */ "./node_modules/call-bind/node_modules/function-bind/index.js");
var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $apply = GetIntrinsic('%Function.prototype.apply%');
var $call = GetIntrinsic('%Function.prototype.call%');
var $reflectApply = GetIntrinsic('%Reflect.apply%', true) || bind.call($call, $apply);

var $gOPD = GetIntrinsic('%Object.getOwnPropertyDescriptor%', true);
var $defineProperty = GetIntrinsic('%Object.defineProperty%', true);
var $max = GetIntrinsic('%Math.max%');

if ($defineProperty) {
	try {
		$defineProperty({}, 'a', { value: 1 });
	} catch (e) {
		// IE 8 has a broken defineProperty
		$defineProperty = null;
	}
}

module.exports = function callBind(originalFunction) {
	var func = $reflectApply(bind, $call, arguments);
	if ($gOPD && $defineProperty) {
		var desc = $gOPD(func, 'length');
		if (desc.configurable) {
			// original length, plus the receiver, minus any additional arguments (after the receiver)
			$defineProperty(
				func,
				'length',
				{ value: 1 + $max(0, originalFunction.length - (arguments.length - 1)) }
			);
		}
	}
	return func;
};

var applyBind = function applyBind() {
	return $reflectApply(bind, $apply, arguments);
};

if ($defineProperty) {
	$defineProperty(module.exports, 'apply', { value: applyBind });
} else {
	module.exports.apply = applyBind;
}


/***/ }),

/***/ "./node_modules/call-bind/node_modules/function-bind/implementation.js":
/*!*****************************************************************************!*\
  !*** ./node_modules/call-bind/node_modules/function-bind/implementation.js ***!
  \*****************************************************************************/
/***/ ((module) => {

"use strict";


/* eslint no-invalid-this: 1 */

var ERROR_MESSAGE = 'Function.prototype.bind called on incompatible ';
var slice = Array.prototype.slice;
var toStr = Object.prototype.toString;
var funcType = '[object Function]';

module.exports = function bind(that) {
    var target = this;
    if (typeof target !== 'function' || toStr.call(target) !== funcType) {
        throw new TypeError(ERROR_MESSAGE + target);
    }
    var args = slice.call(arguments, 1);

    var bound;
    var binder = function () {
        if (this instanceof bound) {
            var result = target.apply(
                this,
                args.concat(slice.call(arguments))
            );
            if (Object(result) === result) {
                return result;
            }
            return this;
        } else {
            return target.apply(
                that,
                args.concat(slice.call(arguments))
            );
        }
    };

    var boundLength = Math.max(0, target.length - args.length);
    var boundArgs = [];
    for (var i = 0; i < boundLength; i++) {
        boundArgs.push('$' + i);
    }

    bound = Function('binder', 'return function (' + boundArgs.join(',') + '){ return binder.apply(this,arguments); }')(binder);

    if (target.prototype) {
        var Empty = function Empty() {};
        Empty.prototype = target.prototype;
        bound.prototype = new Empty();
        Empty.prototype = null;
    }

    return bound;
};


/***/ }),

/***/ "./node_modules/call-bind/node_modules/function-bind/index.js":
/*!********************************************************************!*\
  !*** ./node_modules/call-bind/node_modules/function-bind/index.js ***!
  \********************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var implementation = __webpack_require__(/*! ./implementation */ "./node_modules/call-bind/node_modules/function-bind/implementation.js");

module.exports = Function.prototype.bind || implementation;


/***/ }),

/***/ "./node_modules/define-data-property/index.js":
/*!****************************************************!*\
  !*** ./node_modules/define-data-property/index.js ***!
  \****************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var hasPropertyDescriptors = __webpack_require__(/*! has-property-descriptors */ "./node_modules/has-property-descriptors/index.js")();

var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $defineProperty = hasPropertyDescriptors && GetIntrinsic('%Object.defineProperty%', true);
if ($defineProperty) {
	try {
		$defineProperty({}, 'a', { value: 1 });
	} catch (e) {
		// IE 8 has a broken defineProperty
		$defineProperty = false;
	}
}

var $SyntaxError = GetIntrinsic('%SyntaxError%');
var $TypeError = GetIntrinsic('%TypeError%');

var gopd = __webpack_require__(/*! gopd */ "./node_modules/gopd/index.js");

/** @type {(obj: Record<PropertyKey, unknown>, property: PropertyKey, value: unknown, nonEnumerable?: boolean | null, nonWritable?: boolean | null, nonConfigurable?: boolean | null, loose?: boolean) => void} */
module.exports = function defineDataProperty(
	obj,
	property,
	value
) {
	if (!obj || (typeof obj !== 'object' && typeof obj !== 'function')) {
		throw new $TypeError('`obj` must be an object or a function`');
	}
	if (typeof property !== 'string' && typeof property !== 'symbol') {
		throw new $TypeError('`property` must be a string or a symbol`');
	}
	if (arguments.length > 3 && typeof arguments[3] !== 'boolean' && arguments[3] !== null) {
		throw new $TypeError('`nonEnumerable`, if provided, must be a boolean or null');
	}
	if (arguments.length > 4 && typeof arguments[4] !== 'boolean' && arguments[4] !== null) {
		throw new $TypeError('`nonWritable`, if provided, must be a boolean or null');
	}
	if (arguments.length > 5 && typeof arguments[5] !== 'boolean' && arguments[5] !== null) {
		throw new $TypeError('`nonConfigurable`, if provided, must be a boolean or null');
	}
	if (arguments.length > 6 && typeof arguments[6] !== 'boolean') {
		throw new $TypeError('`loose`, if provided, must be a boolean');
	}

	var nonEnumerable = arguments.length > 3 ? arguments[3] : null;
	var nonWritable = arguments.length > 4 ? arguments[4] : null;
	var nonConfigurable = arguments.length > 5 ? arguments[5] : null;
	var loose = arguments.length > 6 ? arguments[6] : false;

	/* @type {false | TypedPropertyDescriptor<unknown>} */
	var desc = !!gopd && gopd(obj, property);

	if ($defineProperty) {
		$defineProperty(obj, property, {
			configurable: nonConfigurable === null && desc ? desc.configurable : !nonConfigurable,
			enumerable: nonEnumerable === null && desc ? desc.enumerable : !nonEnumerable,
			value: value,
			writable: nonWritable === null && desc ? desc.writable : !nonWritable
		});
	} else if (loose || (!nonEnumerable && !nonWritable && !nonConfigurable)) {
		// must fall back to [[Set]], and was not explicitly asked to make non-enumerable, non-writable, or non-configurable
		obj[property] = value; // eslint-disable-line no-param-reassign
	} else {
		throw new $SyntaxError('This environment does not support defining a property as non-configurable, non-writable, or non-enumerable.');
	}
};


/***/ }),

/***/ "./node_modules/define-properties/index.js":
/*!*************************************************!*\
  !*** ./node_modules/define-properties/index.js ***!
  \*************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var keys = __webpack_require__(/*! object-keys */ "./node_modules/object-keys/index.js");
var hasSymbols = typeof Symbol === 'function' && typeof Symbol('foo') === 'symbol';

var toStr = Object.prototype.toString;
var concat = Array.prototype.concat;
var defineDataProperty = __webpack_require__(/*! define-data-property */ "./node_modules/define-data-property/index.js");

var isFunction = function (fn) {
	return typeof fn === 'function' && toStr.call(fn) === '[object Function]';
};

var supportsDescriptors = __webpack_require__(/*! has-property-descriptors */ "./node_modules/has-property-descriptors/index.js")();

var defineProperty = function (object, name, value, predicate) {
	if (name in object) {
		if (predicate === true) {
			if (object[name] === value) {
				return;
			}
		} else if (!isFunction(predicate) || !predicate()) {
			return;
		}
	}

	if (supportsDescriptors) {
		defineDataProperty(object, name, value, true);
	} else {
		defineDataProperty(object, name, value);
	}
};

var defineProperties = function (object, map) {
	var predicates = arguments.length > 2 ? arguments[2] : {};
	var props = keys(map);
	if (hasSymbols) {
		props = concat.call(props, Object.getOwnPropertySymbols(map));
	}
	for (var i = 0; i < props.length; i += 1) {
		defineProperty(object, props[i], map[props[i]], predicates[props[i]]);
	}
};

defineProperties.supportsDescriptors = !!supportsDescriptors;

module.exports = defineProperties;


/***/ }),

/***/ "./node_modules/es-abstract/node_modules/call-bind/callBound.js":
/*!**********************************************************************!*\
  !*** ./node_modules/es-abstract/node_modules/call-bind/callBound.js ***!
  \**********************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var callBind = __webpack_require__(/*! ./ */ "./node_modules/es-abstract/node_modules/call-bind/index.js");

var $indexOf = callBind(GetIntrinsic('String.prototype.indexOf'));

module.exports = function callBoundIntrinsic(name, allowMissing) {
	var intrinsic = GetIntrinsic(name, !!allowMissing);
	if (typeof intrinsic === 'function' && $indexOf(name, '.prototype.') > -1) {
		return callBind(intrinsic);
	}
	return intrinsic;
};


/***/ }),

/***/ "./node_modules/es-abstract/node_modules/call-bind/index.js":
/*!******************************************************************!*\
  !*** ./node_modules/es-abstract/node_modules/call-bind/index.js ***!
  \******************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var bind = __webpack_require__(/*! function-bind */ "./node_modules/function-bind/index.js");
var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");
var setFunctionLength = __webpack_require__(/*! set-function-length */ "./node_modules/set-function-length/index.js");

var $TypeError = GetIntrinsic('%TypeError%');
var $apply = GetIntrinsic('%Function.prototype.apply%');
var $call = GetIntrinsic('%Function.prototype.call%');
var $reflectApply = GetIntrinsic('%Reflect.apply%', true) || bind.call($call, $apply);

var $defineProperty = GetIntrinsic('%Object.defineProperty%', true);
var $max = GetIntrinsic('%Math.max%');

if ($defineProperty) {
	try {
		$defineProperty({}, 'a', { value: 1 });
	} catch (e) {
		// IE 8 has a broken defineProperty
		$defineProperty = null;
	}
}

module.exports = function callBind(originalFunction) {
	if (typeof originalFunction !== 'function') {
		throw new $TypeError('a function is required');
	}
	var func = $reflectApply(bind, $call, arguments);
	return setFunctionLength(
		func,
		1 + $max(0, originalFunction.length - (arguments.length - 1)),
		true
	);
};

var applyBind = function applyBind() {
	return $reflectApply(bind, $apply, arguments);
};

if ($defineProperty) {
	$defineProperty(module.exports, 'apply', { value: applyBind });
} else {
	module.exports.apply = applyBind;
}


/***/ }),

/***/ "./node_modules/es-set-tostringtag/index.js":
/*!**************************************************!*\
  !*** ./node_modules/es-set-tostringtag/index.js ***!
  \**************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $defineProperty = GetIntrinsic('%Object.defineProperty%', true);

var hasToStringTag = __webpack_require__(/*! has-tostringtag/shams */ "./node_modules/has-tostringtag/shams.js")();
var hasOwn = __webpack_require__(/*! hasown */ "./node_modules/hasown/index.js");

var toStringTag = hasToStringTag ? Symbol.toStringTag : null;

module.exports = function setToStringTag(object, value) {
	var overrideIfSet = arguments.length > 2 && arguments[2] && arguments[2].force;
	if (toStringTag && (overrideIfSet || !hasOwn(object, toStringTag))) {
		if ($defineProperty) {
			$defineProperty(object, toStringTag, {
				configurable: true,
				enumerable: false,
				value: value,
				writable: false
			});
		} else {
			object[toStringTag] = value; // eslint-disable-line no-param-reassign
		}
	}
};


/***/ }),

/***/ "./node_modules/es-to-primitive/es2015.js":
/*!************************************************!*\
  !*** ./node_modules/es-to-primitive/es2015.js ***!
  \************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var hasSymbols = typeof Symbol === 'function' && typeof Symbol.iterator === 'symbol';

var isPrimitive = __webpack_require__(/*! ./helpers/isPrimitive */ "./node_modules/es-to-primitive/helpers/isPrimitive.js");
var isCallable = __webpack_require__(/*! is-callable */ "./node_modules/is-callable/index.js");
var isDate = __webpack_require__(/*! is-date-object */ "./node_modules/is-date-object/index.js");
var isSymbol = __webpack_require__(/*! is-symbol */ "./node_modules/is-symbol/index.js");

var ordinaryToPrimitive = function OrdinaryToPrimitive(O, hint) {
	if (typeof O === 'undefined' || O === null) {
		throw new TypeError('Cannot call method on ' + O);
	}
	if (typeof hint !== 'string' || (hint !== 'number' && hint !== 'string')) {
		throw new TypeError('hint must be "string" or "number"');
	}
	var methodNames = hint === 'string' ? ['toString', 'valueOf'] : ['valueOf', 'toString'];
	var method, result, i;
	for (i = 0; i < methodNames.length; ++i) {
		method = O[methodNames[i]];
		if (isCallable(method)) {
			result = method.call(O);
			if (isPrimitive(result)) {
				return result;
			}
		}
	}
	throw new TypeError('No default value');
};

var GetMethod = function GetMethod(O, P) {
	var func = O[P];
	if (func !== null && typeof func !== 'undefined') {
		if (!isCallable(func)) {
			throw new TypeError(func + ' returned for property ' + P + ' of object ' + O + ' is not a function');
		}
		return func;
	}
	return void 0;
};

// http://www.ecma-international.org/ecma-262/6.0/#sec-toprimitive
module.exports = function ToPrimitive(input) {
	if (isPrimitive(input)) {
		return input;
	}
	var hint = 'default';
	if (arguments.length > 1) {
		if (arguments[1] === String) {
			hint = 'string';
		} else if (arguments[1] === Number) {
			hint = 'number';
		}
	}

	var exoticToPrim;
	if (hasSymbols) {
		if (Symbol.toPrimitive) {
			exoticToPrim = GetMethod(input, Symbol.toPrimitive);
		} else if (isSymbol(input)) {
			exoticToPrim = Symbol.prototype.valueOf;
		}
	}
	if (typeof exoticToPrim !== 'undefined') {
		var result = exoticToPrim.call(input, hint);
		if (isPrimitive(result)) {
			return result;
		}
		throw new TypeError('unable to convert exotic object to primitive');
	}
	if (hint === 'default' && (isDate(input) || isSymbol(input))) {
		hint = 'string';
	}
	return ordinaryToPrimitive(input, hint === 'default' ? 'number' : hint);
};


/***/ }),

/***/ "./node_modules/es-to-primitive/helpers/isPrimitive.js":
/*!*************************************************************!*\
  !*** ./node_modules/es-to-primitive/helpers/isPrimitive.js ***!
  \*************************************************************/
/***/ ((module) => {

"use strict";


module.exports = function isPrimitive(value) {
	return value === null || (typeof value !== 'function' && typeof value !== 'object');
};


/***/ }),

/***/ "./node_modules/function-bind/implementation.js":
/*!******************************************************!*\
  !*** ./node_modules/function-bind/implementation.js ***!
  \******************************************************/
/***/ ((module) => {

"use strict";


/* eslint no-invalid-this: 1 */

var ERROR_MESSAGE = 'Function.prototype.bind called on incompatible ';
var toStr = Object.prototype.toString;
var max = Math.max;
var funcType = '[object Function]';

var concatty = function concatty(a, b) {
    var arr = [];

    for (var i = 0; i < a.length; i += 1) {
        arr[i] = a[i];
    }
    for (var j = 0; j < b.length; j += 1) {
        arr[j + a.length] = b[j];
    }

    return arr;
};

var slicy = function slicy(arrLike, offset) {
    var arr = [];
    for (var i = offset || 0, j = 0; i < arrLike.length; i += 1, j += 1) {
        arr[j] = arrLike[i];
    }
    return arr;
};

var joiny = function (arr, joiner) {
    var str = '';
    for (var i = 0; i < arr.length; i += 1) {
        str += arr[i];
        if (i + 1 < arr.length) {
            str += joiner;
        }
    }
    return str;
};

module.exports = function bind(that) {
    var target = this;
    if (typeof target !== 'function' || toStr.apply(target) !== funcType) {
        throw new TypeError(ERROR_MESSAGE + target);
    }
    var args = slicy(arguments, 1);

    var bound;
    var binder = function () {
        if (this instanceof bound) {
            var result = target.apply(
                this,
                concatty(args, arguments)
            );
            if (Object(result) === result) {
                return result;
            }
            return this;
        }
        return target.apply(
            that,
            concatty(args, arguments)
        );

    };

    var boundLength = max(0, target.length - args.length);
    var boundArgs = [];
    for (var i = 0; i < boundLength; i++) {
        boundArgs[i] = '$' + i;
    }

    bound = Function('binder', 'return function (' + joiny(boundArgs, ',') + '){ return binder.apply(this,arguments); }')(binder);

    if (target.prototype) {
        var Empty = function Empty() {};
        Empty.prototype = target.prototype;
        bound.prototype = new Empty();
        Empty.prototype = null;
    }

    return bound;
};


/***/ }),

/***/ "./node_modules/function-bind/index.js":
/*!*********************************************!*\
  !*** ./node_modules/function-bind/index.js ***!
  \*********************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var implementation = __webpack_require__(/*! ./implementation */ "./node_modules/function-bind/implementation.js");

module.exports = Function.prototype.bind || implementation;


/***/ }),

/***/ "./node_modules/functions-have-names/index.js":
/*!****************************************************!*\
  !*** ./node_modules/functions-have-names/index.js ***!
  \****************************************************/
/***/ ((module) => {

"use strict";


var functionsHaveNames = function functionsHaveNames() {
	return typeof function f() {}.name === 'string';
};

var gOPD = Object.getOwnPropertyDescriptor;
if (gOPD) {
	try {
		gOPD([], 'length');
	} catch (e) {
		// IE 8 has a broken gOPD
		gOPD = null;
	}
}

functionsHaveNames.functionsHaveConfigurableNames = function functionsHaveConfigurableNames() {
	if (!functionsHaveNames() || !gOPD) {
		return false;
	}
	var desc = gOPD(function () {}, 'name');
	return !!desc && !!desc.configurable;
};

var $bind = Function.prototype.bind;

functionsHaveNames.boundFunctionsHaveNames = function boundFunctionsHaveNames() {
	return functionsHaveNames() && typeof $bind === 'function' && function f() {}.bind().name !== '';
};

module.exports = functionsHaveNames;


/***/ }),

/***/ "./node_modules/get-intrinsic/index.js":
/*!*********************************************!*\
  !*** ./node_modules/get-intrinsic/index.js ***!
  \*********************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var undefined;

var $SyntaxError = SyntaxError;
var $Function = Function;
var $TypeError = TypeError;

// eslint-disable-next-line consistent-return
var getEvalledConstructor = function (expressionSyntax) {
	try {
		return $Function('"use strict"; return (' + expressionSyntax + ').constructor;')();
	} catch (e) {}
};

var $gOPD = Object.getOwnPropertyDescriptor;
if ($gOPD) {
	try {
		$gOPD({}, '');
	} catch (e) {
		$gOPD = null; // this is IE 8, which has a broken gOPD
	}
}

var throwTypeError = function () {
	throw new $TypeError();
};
var ThrowTypeError = $gOPD
	? (function () {
		try {
			// eslint-disable-next-line no-unused-expressions, no-caller, no-restricted-properties
			arguments.callee; // IE 8 does not throw here
			return throwTypeError;
		} catch (calleeThrows) {
			try {
				// IE 8 throws on Object.getOwnPropertyDescriptor(arguments, '')
				return $gOPD(arguments, 'callee').get;
			} catch (gOPDthrows) {
				return throwTypeError;
			}
		}
	}())
	: throwTypeError;

var hasSymbols = __webpack_require__(/*! has-symbols */ "./node_modules/has-symbols/index.js")();
var hasProto = __webpack_require__(/*! has-proto */ "./node_modules/has-proto/index.js")();

var getProto = Object.getPrototypeOf || (
	hasProto
		? function (x) { return x.__proto__; } // eslint-disable-line no-proto
		: null
);

var needsEval = {};

var TypedArray = typeof Uint8Array === 'undefined' || !getProto ? undefined : getProto(Uint8Array);

var INTRINSICS = {
	'%AggregateError%': typeof AggregateError === 'undefined' ? undefined : AggregateError,
	'%Array%': Array,
	'%ArrayBuffer%': typeof ArrayBuffer === 'undefined' ? undefined : ArrayBuffer,
	'%ArrayIteratorPrototype%': hasSymbols && getProto ? getProto([][Symbol.iterator]()) : undefined,
	'%AsyncFromSyncIteratorPrototype%': undefined,
	'%AsyncFunction%': needsEval,
	'%AsyncGenerator%': needsEval,
	'%AsyncGeneratorFunction%': needsEval,
	'%AsyncIteratorPrototype%': needsEval,
	'%Atomics%': typeof Atomics === 'undefined' ? undefined : Atomics,
	'%BigInt%': typeof BigInt === 'undefined' ? undefined : BigInt,
	'%BigInt64Array%': typeof BigInt64Array === 'undefined' ? undefined : BigInt64Array,
	'%BigUint64Array%': typeof BigUint64Array === 'undefined' ? undefined : BigUint64Array,
	'%Boolean%': Boolean,
	'%DataView%': typeof DataView === 'undefined' ? undefined : DataView,
	'%Date%': Date,
	'%decodeURI%': decodeURI,
	'%decodeURIComponent%': decodeURIComponent,
	'%encodeURI%': encodeURI,
	'%encodeURIComponent%': encodeURIComponent,
	'%Error%': Error,
	'%eval%': eval, // eslint-disable-line no-eval
	'%EvalError%': EvalError,
	'%Float32Array%': typeof Float32Array === 'undefined' ? undefined : Float32Array,
	'%Float64Array%': typeof Float64Array === 'undefined' ? undefined : Float64Array,
	'%FinalizationRegistry%': typeof FinalizationRegistry === 'undefined' ? undefined : FinalizationRegistry,
	'%Function%': $Function,
	'%GeneratorFunction%': needsEval,
	'%Int8Array%': typeof Int8Array === 'undefined' ? undefined : Int8Array,
	'%Int16Array%': typeof Int16Array === 'undefined' ? undefined : Int16Array,
	'%Int32Array%': typeof Int32Array === 'undefined' ? undefined : Int32Array,
	'%isFinite%': isFinite,
	'%isNaN%': isNaN,
	'%IteratorPrototype%': hasSymbols && getProto ? getProto(getProto([][Symbol.iterator]())) : undefined,
	'%JSON%': typeof JSON === 'object' ? JSON : undefined,
	'%Map%': typeof Map === 'undefined' ? undefined : Map,
	'%MapIteratorPrototype%': typeof Map === 'undefined' || !hasSymbols || !getProto ? undefined : getProto(new Map()[Symbol.iterator]()),
	'%Math%': Math,
	'%Number%': Number,
	'%Object%': Object,
	'%parseFloat%': parseFloat,
	'%parseInt%': parseInt,
	'%Promise%': typeof Promise === 'undefined' ? undefined : Promise,
	'%Proxy%': typeof Proxy === 'undefined' ? undefined : Proxy,
	'%RangeError%': RangeError,
	'%ReferenceError%': ReferenceError,
	'%Reflect%': typeof Reflect === 'undefined' ? undefined : Reflect,
	'%RegExp%': RegExp,
	'%Set%': typeof Set === 'undefined' ? undefined : Set,
	'%SetIteratorPrototype%': typeof Set === 'undefined' || !hasSymbols || !getProto ? undefined : getProto(new Set()[Symbol.iterator]()),
	'%SharedArrayBuffer%': typeof SharedArrayBuffer === 'undefined' ? undefined : SharedArrayBuffer,
	'%String%': String,
	'%StringIteratorPrototype%': hasSymbols && getProto ? getProto(''[Symbol.iterator]()) : undefined,
	'%Symbol%': hasSymbols ? Symbol : undefined,
	'%SyntaxError%': $SyntaxError,
	'%ThrowTypeError%': ThrowTypeError,
	'%TypedArray%': TypedArray,
	'%TypeError%': $TypeError,
	'%Uint8Array%': typeof Uint8Array === 'undefined' ? undefined : Uint8Array,
	'%Uint8ClampedArray%': typeof Uint8ClampedArray === 'undefined' ? undefined : Uint8ClampedArray,
	'%Uint16Array%': typeof Uint16Array === 'undefined' ? undefined : Uint16Array,
	'%Uint32Array%': typeof Uint32Array === 'undefined' ? undefined : Uint32Array,
	'%URIError%': URIError,
	'%WeakMap%': typeof WeakMap === 'undefined' ? undefined : WeakMap,
	'%WeakRef%': typeof WeakRef === 'undefined' ? undefined : WeakRef,
	'%WeakSet%': typeof WeakSet === 'undefined' ? undefined : WeakSet
};

if (getProto) {
	try {
		null.error; // eslint-disable-line no-unused-expressions
	} catch (e) {
		// https://github.com/tc39/proposal-shadowrealm/pull/384#issuecomment-1364264229
		var errorProto = getProto(getProto(e));
		INTRINSICS['%Error.prototype%'] = errorProto;
	}
}

var doEval = function doEval(name) {
	var value;
	if (name === '%AsyncFunction%') {
		value = getEvalledConstructor('async function () {}');
	} else if (name === '%GeneratorFunction%') {
		value = getEvalledConstructor('function* () {}');
	} else if (name === '%AsyncGeneratorFunction%') {
		value = getEvalledConstructor('async function* () {}');
	} else if (name === '%AsyncGenerator%') {
		var fn = doEval('%AsyncGeneratorFunction%');
		if (fn) {
			value = fn.prototype;
		}
	} else if (name === '%AsyncIteratorPrototype%') {
		var gen = doEval('%AsyncGenerator%');
		if (gen && getProto) {
			value = getProto(gen.prototype);
		}
	}

	INTRINSICS[name] = value;

	return value;
};

var LEGACY_ALIASES = {
	'%ArrayBufferPrototype%': ['ArrayBuffer', 'prototype'],
	'%ArrayPrototype%': ['Array', 'prototype'],
	'%ArrayProto_entries%': ['Array', 'prototype', 'entries'],
	'%ArrayProto_forEach%': ['Array', 'prototype', 'forEach'],
	'%ArrayProto_keys%': ['Array', 'prototype', 'keys'],
	'%ArrayProto_values%': ['Array', 'prototype', 'values'],
	'%AsyncFunctionPrototype%': ['AsyncFunction', 'prototype'],
	'%AsyncGenerator%': ['AsyncGeneratorFunction', 'prototype'],
	'%AsyncGeneratorPrototype%': ['AsyncGeneratorFunction', 'prototype', 'prototype'],
	'%BooleanPrototype%': ['Boolean', 'prototype'],
	'%DataViewPrototype%': ['DataView', 'prototype'],
	'%DatePrototype%': ['Date', 'prototype'],
	'%ErrorPrototype%': ['Error', 'prototype'],
	'%EvalErrorPrototype%': ['EvalError', 'prototype'],
	'%Float32ArrayPrototype%': ['Float32Array', 'prototype'],
	'%Float64ArrayPrototype%': ['Float64Array', 'prototype'],
	'%FunctionPrototype%': ['Function', 'prototype'],
	'%Generator%': ['GeneratorFunction', 'prototype'],
	'%GeneratorPrototype%': ['GeneratorFunction', 'prototype', 'prototype'],
	'%Int8ArrayPrototype%': ['Int8Array', 'prototype'],
	'%Int16ArrayPrototype%': ['Int16Array', 'prototype'],
	'%Int32ArrayPrototype%': ['Int32Array', 'prototype'],
	'%JSONParse%': ['JSON', 'parse'],
	'%JSONStringify%': ['JSON', 'stringify'],
	'%MapPrototype%': ['Map', 'prototype'],
	'%NumberPrototype%': ['Number', 'prototype'],
	'%ObjectPrototype%': ['Object', 'prototype'],
	'%ObjProto_toString%': ['Object', 'prototype', 'toString'],
	'%ObjProto_valueOf%': ['Object', 'prototype', 'valueOf'],
	'%PromisePrototype%': ['Promise', 'prototype'],
	'%PromiseProto_then%': ['Promise', 'prototype', 'then'],
	'%Promise_all%': ['Promise', 'all'],
	'%Promise_reject%': ['Promise', 'reject'],
	'%Promise_resolve%': ['Promise', 'resolve'],
	'%RangeErrorPrototype%': ['RangeError', 'prototype'],
	'%ReferenceErrorPrototype%': ['ReferenceError', 'prototype'],
	'%RegExpPrototype%': ['RegExp', 'prototype'],
	'%SetPrototype%': ['Set', 'prototype'],
	'%SharedArrayBufferPrototype%': ['SharedArrayBuffer', 'prototype'],
	'%StringPrototype%': ['String', 'prototype'],
	'%SymbolPrototype%': ['Symbol', 'prototype'],
	'%SyntaxErrorPrototype%': ['SyntaxError', 'prototype'],
	'%TypedArrayPrototype%': ['TypedArray', 'prototype'],
	'%TypeErrorPrototype%': ['TypeError', 'prototype'],
	'%Uint8ArrayPrototype%': ['Uint8Array', 'prototype'],
	'%Uint8ClampedArrayPrototype%': ['Uint8ClampedArray', 'prototype'],
	'%Uint16ArrayPrototype%': ['Uint16Array', 'prototype'],
	'%Uint32ArrayPrototype%': ['Uint32Array', 'prototype'],
	'%URIErrorPrototype%': ['URIError', 'prototype'],
	'%WeakMapPrototype%': ['WeakMap', 'prototype'],
	'%WeakSetPrototype%': ['WeakSet', 'prototype']
};

var bind = __webpack_require__(/*! function-bind */ "./node_modules/function-bind/index.js");
var hasOwn = __webpack_require__(/*! hasown */ "./node_modules/hasown/index.js");
var $concat = bind.call(Function.call, Array.prototype.concat);
var $spliceApply = bind.call(Function.apply, Array.prototype.splice);
var $replace = bind.call(Function.call, String.prototype.replace);
var $strSlice = bind.call(Function.call, String.prototype.slice);
var $exec = bind.call(Function.call, RegExp.prototype.exec);

/* adapted from https://github.com/lodash/lodash/blob/4.17.15/dist/lodash.js#L6735-L6744 */
var rePropName = /[^%.[\]]+|\[(?:(-?\d+(?:\.\d+)?)|(["'])((?:(?!\2)[^\\]|\\.)*?)\2)\]|(?=(?:\.|\[\])(?:\.|\[\]|%$))/g;
var reEscapeChar = /\\(\\)?/g; /** Used to match backslashes in property paths. */
var stringToPath = function stringToPath(string) {
	var first = $strSlice(string, 0, 1);
	var last = $strSlice(string, -1);
	if (first === '%' && last !== '%') {
		throw new $SyntaxError('invalid intrinsic syntax, expected closing `%`');
	} else if (last === '%' && first !== '%') {
		throw new $SyntaxError('invalid intrinsic syntax, expected opening `%`');
	}
	var result = [];
	$replace(string, rePropName, function (match, number, quote, subString) {
		result[result.length] = quote ? $replace(subString, reEscapeChar, '$1') : number || match;
	});
	return result;
};
/* end adaptation */

var getBaseIntrinsic = function getBaseIntrinsic(name, allowMissing) {
	var intrinsicName = name;
	var alias;
	if (hasOwn(LEGACY_ALIASES, intrinsicName)) {
		alias = LEGACY_ALIASES[intrinsicName];
		intrinsicName = '%' + alias[0] + '%';
	}

	if (hasOwn(INTRINSICS, intrinsicName)) {
		var value = INTRINSICS[intrinsicName];
		if (value === needsEval) {
			value = doEval(intrinsicName);
		}
		if (typeof value === 'undefined' && !allowMissing) {
			throw new $TypeError('intrinsic ' + name + ' exists, but is not available. Please file an issue!');
		}

		return {
			alias: alias,
			name: intrinsicName,
			value: value
		};
	}

	throw new $SyntaxError('intrinsic ' + name + ' does not exist!');
};

module.exports = function GetIntrinsic(name, allowMissing) {
	if (typeof name !== 'string' || name.length === 0) {
		throw new $TypeError('intrinsic name must be a non-empty string');
	}
	if (arguments.length > 1 && typeof allowMissing !== 'boolean') {
		throw new $TypeError('"allowMissing" argument must be a boolean');
	}

	if ($exec(/^%?[^%]*%?$/, name) === null) {
		throw new $SyntaxError('`%` may not be present anywhere but at the beginning and end of the intrinsic name');
	}
	var parts = stringToPath(name);
	var intrinsicBaseName = parts.length > 0 ? parts[0] : '';

	var intrinsic = getBaseIntrinsic('%' + intrinsicBaseName + '%', allowMissing);
	var intrinsicRealName = intrinsic.name;
	var value = intrinsic.value;
	var skipFurtherCaching = false;

	var alias = intrinsic.alias;
	if (alias) {
		intrinsicBaseName = alias[0];
		$spliceApply(parts, $concat([0, 1], alias));
	}

	for (var i = 1, isOwn = true; i < parts.length; i += 1) {
		var part = parts[i];
		var first = $strSlice(part, 0, 1);
		var last = $strSlice(part, -1);
		if (
			(
				(first === '"' || first === "'" || first === '`')
				|| (last === '"' || last === "'" || last === '`')
			)
			&& first !== last
		) {
			throw new $SyntaxError('property names with quotes must have matching quotes');
		}
		if (part === 'constructor' || !isOwn) {
			skipFurtherCaching = true;
		}

		intrinsicBaseName += '.' + part;
		intrinsicRealName = '%' + intrinsicBaseName + '%';

		if (hasOwn(INTRINSICS, intrinsicRealName)) {
			value = INTRINSICS[intrinsicRealName];
		} else if (value != null) {
			if (!(part in value)) {
				if (!allowMissing) {
					throw new $TypeError('base intrinsic for ' + name + ' exists, but the property is not available.');
				}
				return void undefined;
			}
			if ($gOPD && (i + 1) >= parts.length) {
				var desc = $gOPD(value, part);
				isOwn = !!desc;

				// By convention, when a data property is converted to an accessor
				// property to emulate a data property that does not suffer from
				// the override mistake, that accessor's getter is marked with
				// an `originalValue` property. Here, when we detect this, we
				// uphold the illusion by pretending to see that original data
				// property, i.e., returning the value rather than the getter
				// itself.
				if (isOwn && 'get' in desc && !('originalValue' in desc.get)) {
					value = desc.get;
				} else {
					value = value[part];
				}
			} else {
				isOwn = hasOwn(value, part);
				value = value[part];
			}

			if (isOwn && !skipFurtherCaching) {
				INTRINSICS[intrinsicRealName] = value;
			}
		}
	}
	return value;
};


/***/ }),

/***/ "./node_modules/gopd/index.js":
/*!************************************!*\
  !*** ./node_modules/gopd/index.js ***!
  \************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $gOPD = GetIntrinsic('%Object.getOwnPropertyDescriptor%', true);

if ($gOPD) {
	try {
		$gOPD([], 'length');
	} catch (e) {
		// IE 8 has a broken gOPD
		$gOPD = null;
	}
}

module.exports = $gOPD;


/***/ }),

/***/ "./node_modules/has-property-descriptors/index.js":
/*!********************************************************!*\
  !*** ./node_modules/has-property-descriptors/index.js ***!
  \********************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $defineProperty = GetIntrinsic('%Object.defineProperty%', true);

var hasPropertyDescriptors = function hasPropertyDescriptors() {
	if ($defineProperty) {
		try {
			$defineProperty({}, 'a', { value: 1 });
			return true;
		} catch (e) {
			// IE 8 has a broken defineProperty
			return false;
		}
	}
	return false;
};

hasPropertyDescriptors.hasArrayLengthDefineBug = function hasArrayLengthDefineBug() {
	// node v0.6 has a bug where array lengths can be Set but not Defined
	if (!hasPropertyDescriptors()) {
		return null;
	}
	try {
		return $defineProperty([], 'length', { value: 1 }).length !== 1;
	} catch (e) {
		// In Firefox 4-22, defining length on an array throws an exception.
		return true;
	}
};

module.exports = hasPropertyDescriptors;


/***/ }),

/***/ "./node_modules/has-proto/index.js":
/*!*****************************************!*\
  !*** ./node_modules/has-proto/index.js ***!
  \*****************************************/
/***/ ((module) => {

"use strict";


var test = {
	foo: {}
};

var $Object = Object;

module.exports = function hasProto() {
	return { __proto__: test }.foo === test.foo && !({ __proto__: null } instanceof $Object);
};


/***/ }),

/***/ "./node_modules/has-symbols/index.js":
/*!*******************************************!*\
  !*** ./node_modules/has-symbols/index.js ***!
  \*******************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var origSymbol = typeof Symbol !== 'undefined' && Symbol;
var hasSymbolSham = __webpack_require__(/*! ./shams */ "./node_modules/has-symbols/shams.js");

module.exports = function hasNativeSymbols() {
	if (typeof origSymbol !== 'function') { return false; }
	if (typeof Symbol !== 'function') { return false; }
	if (typeof origSymbol('foo') !== 'symbol') { return false; }
	if (typeof Symbol('bar') !== 'symbol') { return false; }

	return hasSymbolSham();
};


/***/ }),

/***/ "./node_modules/has-symbols/shams.js":
/*!*******************************************!*\
  !*** ./node_modules/has-symbols/shams.js ***!
  \*******************************************/
/***/ ((module) => {

"use strict";


/* eslint complexity: [2, 18], max-statements: [2, 33] */
module.exports = function hasSymbols() {
	if (typeof Symbol !== 'function' || typeof Object.getOwnPropertySymbols !== 'function') { return false; }
	if (typeof Symbol.iterator === 'symbol') { return true; }

	var obj = {};
	var sym = Symbol('test');
	var symObj = Object(sym);
	if (typeof sym === 'string') { return false; }

	if (Object.prototype.toString.call(sym) !== '[object Symbol]') { return false; }
	if (Object.prototype.toString.call(symObj) !== '[object Symbol]') { return false; }

	// temp disabled per https://github.com/ljharb/object.assign/issues/17
	// if (sym instanceof Symbol) { return false; }
	// temp disabled per https://github.com/WebReflection/get-own-property-symbols/issues/4
	// if (!(symObj instanceof Symbol)) { return false; }

	// if (typeof Symbol.prototype.toString !== 'function') { return false; }
	// if (String(sym) !== Symbol.prototype.toString.call(sym)) { return false; }

	var symVal = 42;
	obj[sym] = symVal;
	for (sym in obj) { return false; } // eslint-disable-line no-restricted-syntax, no-unreachable-loop
	if (typeof Object.keys === 'function' && Object.keys(obj).length !== 0) { return false; }

	if (typeof Object.getOwnPropertyNames === 'function' && Object.getOwnPropertyNames(obj).length !== 0) { return false; }

	var syms = Object.getOwnPropertySymbols(obj);
	if (syms.length !== 1 || syms[0] !== sym) { return false; }

	if (!Object.prototype.propertyIsEnumerable.call(obj, sym)) { return false; }

	if (typeof Object.getOwnPropertyDescriptor === 'function') {
		var descriptor = Object.getOwnPropertyDescriptor(obj, sym);
		if (descriptor.value !== symVal || descriptor.enumerable !== true) { return false; }
	}

	return true;
};


/***/ }),

/***/ "./node_modules/has-tostringtag/shams.js":
/*!***********************************************!*\
  !*** ./node_modules/has-tostringtag/shams.js ***!
  \***********************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var hasSymbols = __webpack_require__(/*! has-symbols/shams */ "./node_modules/has-symbols/shams.js");

module.exports = function hasToStringTagShams() {
	return hasSymbols() && !!Symbol.toStringTag;
};


/***/ }),

/***/ "./node_modules/hasown/index.js":
/*!**************************************!*\
  !*** ./node_modules/hasown/index.js ***!
  \**************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var call = Function.prototype.call;
var $hasOwn = Object.prototype.hasOwnProperty;
var bind = __webpack_require__(/*! function-bind */ "./node_modules/function-bind/index.js");

/** @type {(o: {}, p: PropertyKey) => p is keyof o} */
module.exports = bind.call(call, $hasOwn);


/***/ }),

/***/ "./node_modules/internal-slot/index.js":
/*!*********************************************!*\
  !*** ./node_modules/internal-slot/index.js ***!
  \*********************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");
var hasOwn = __webpack_require__(/*! hasown */ "./node_modules/hasown/index.js");
var channel = __webpack_require__(/*! side-channel */ "./node_modules/side-channel/index.js")();

var $TypeError = GetIntrinsic('%TypeError%');

var SLOT = {
	assert: function (O, slot) {
		if (!O || (typeof O !== 'object' && typeof O !== 'function')) {
			throw new $TypeError('`O` is not an object');
		}
		if (typeof slot !== 'string') {
			throw new $TypeError('`slot` must be a string');
		}
		channel.assert(O);
		if (!SLOT.has(O, slot)) {
			throw new $TypeError('`' + slot + '` is not present on `O`');
		}
	},
	get: function (O, slot) {
		if (!O || (typeof O !== 'object' && typeof O !== 'function')) {
			throw new $TypeError('`O` is not an object');
		}
		if (typeof slot !== 'string') {
			throw new $TypeError('`slot` must be a string');
		}
		var slots = channel.get(O);
		return slots && slots['$' + slot];
	},
	has: function (O, slot) {
		if (!O || (typeof O !== 'object' && typeof O !== 'function')) {
			throw new $TypeError('`O` is not an object');
		}
		if (typeof slot !== 'string') {
			throw new $TypeError('`slot` must be a string');
		}
		var slots = channel.get(O);
		return !!slots && hasOwn(slots, '$' + slot);
	},
	set: function (O, slot, V) {
		if (!O || (typeof O !== 'object' && typeof O !== 'function')) {
			throw new $TypeError('`O` is not an object');
		}
		if (typeof slot !== 'string') {
			throw new $TypeError('`slot` must be a string');
		}
		var slots = channel.get(O);
		if (!slots) {
			slots = {};
			channel.set(O, slots);
		}
		slots['$' + slot] = V;
	}
};

if (Object.freeze) {
	Object.freeze(SLOT);
}

module.exports = SLOT;


/***/ }),

/***/ "./node_modules/is-callable/index.js":
/*!*******************************************!*\
  !*** ./node_modules/is-callable/index.js ***!
  \*******************************************/
/***/ ((module) => {

"use strict";


var fnToStr = Function.prototype.toString;
var reflectApply = typeof Reflect === 'object' && Reflect !== null && Reflect.apply;
var badArrayLike;
var isCallableMarker;
if (typeof reflectApply === 'function' && typeof Object.defineProperty === 'function') {
	try {
		badArrayLike = Object.defineProperty({}, 'length', {
			get: function () {
				throw isCallableMarker;
			}
		});
		isCallableMarker = {};
		// eslint-disable-next-line no-throw-literal
		reflectApply(function () { throw 42; }, null, badArrayLike);
	} catch (_) {
		if (_ !== isCallableMarker) {
			reflectApply = null;
		}
	}
} else {
	reflectApply = null;
}

var constructorRegex = /^\s*class\b/;
var isES6ClassFn = function isES6ClassFunction(value) {
	try {
		var fnStr = fnToStr.call(value);
		return constructorRegex.test(fnStr);
	} catch (e) {
		return false; // not a function
	}
};

var tryFunctionObject = function tryFunctionToStr(value) {
	try {
		if (isES6ClassFn(value)) { return false; }
		fnToStr.call(value);
		return true;
	} catch (e) {
		return false;
	}
};
var toStr = Object.prototype.toString;
var objectClass = '[object Object]';
var fnClass = '[object Function]';
var genClass = '[object GeneratorFunction]';
var ddaClass = '[object HTMLAllCollection]'; // IE 11
var ddaClass2 = '[object HTML document.all class]';
var ddaClass3 = '[object HTMLCollection]'; // IE 9-10
var hasToStringTag = typeof Symbol === 'function' && !!Symbol.toStringTag; // better: use `has-tostringtag`

var isIE68 = !(0 in [,]); // eslint-disable-line no-sparse-arrays, comma-spacing

var isDDA = function isDocumentDotAll() { return false; };
if (typeof document === 'object') {
	// Firefox 3 canonicalizes DDA to undefined when it's not accessed directly
	var all = document.all;
	if (toStr.call(all) === toStr.call(document.all)) {
		isDDA = function isDocumentDotAll(value) {
			/* globals document: false */
			// in IE 6-8, typeof document.all is "object" and it's truthy
			if ((isIE68 || !value) && (typeof value === 'undefined' || typeof value === 'object')) {
				try {
					var str = toStr.call(value);
					return (
						str === ddaClass
						|| str === ddaClass2
						|| str === ddaClass3 // opera 12.16
						|| str === objectClass // IE 6-8
					) && value('') == null; // eslint-disable-line eqeqeq
				} catch (e) { /**/ }
			}
			return false;
		};
	}
}

module.exports = reflectApply
	? function isCallable(value) {
		if (isDDA(value)) { return true; }
		if (!value) { return false; }
		if (typeof value !== 'function' && typeof value !== 'object') { return false; }
		try {
			reflectApply(value, null, badArrayLike);
		} catch (e) {
			if (e !== isCallableMarker) { return false; }
		}
		return !isES6ClassFn(value) && tryFunctionObject(value);
	}
	: function isCallable(value) {
		if (isDDA(value)) { return true; }
		if (!value) { return false; }
		if (typeof value !== 'function' && typeof value !== 'object') { return false; }
		if (hasToStringTag) { return tryFunctionObject(value); }
		if (isES6ClassFn(value)) { return false; }
		var strClass = toStr.call(value);
		if (strClass !== fnClass && strClass !== genClass && !(/^\[object HTML/).test(strClass)) { return false; }
		return tryFunctionObject(value);
	};


/***/ }),

/***/ "./node_modules/is-date-object/index.js":
/*!**********************************************!*\
  !*** ./node_modules/is-date-object/index.js ***!
  \**********************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var getDay = Date.prototype.getDay;
var tryDateObject = function tryDateGetDayCall(value) {
	try {
		getDay.call(value);
		return true;
	} catch (e) {
		return false;
	}
};

var toStr = Object.prototype.toString;
var dateClass = '[object Date]';
var hasToStringTag = __webpack_require__(/*! has-tostringtag/shams */ "./node_modules/has-tostringtag/shams.js")();

module.exports = function isDateObject(value) {
	if (typeof value !== 'object' || value === null) {
		return false;
	}
	return hasToStringTag ? tryDateObject(value) : toStr.call(value) === dateClass;
};


/***/ }),

/***/ "./node_modules/is-regex/index.js":
/*!****************************************!*\
  !*** ./node_modules/is-regex/index.js ***!
  \****************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var callBound = __webpack_require__(/*! call-bind/callBound */ "./node_modules/call-bind/callBound.js");
var hasToStringTag = __webpack_require__(/*! has-tostringtag/shams */ "./node_modules/has-tostringtag/shams.js")();
var has;
var $exec;
var isRegexMarker;
var badStringifier;

if (hasToStringTag) {
	has = callBound('Object.prototype.hasOwnProperty');
	$exec = callBound('RegExp.prototype.exec');
	isRegexMarker = {};

	var throwRegexMarker = function () {
		throw isRegexMarker;
	};
	badStringifier = {
		toString: throwRegexMarker,
		valueOf: throwRegexMarker
	};

	if (typeof Symbol.toPrimitive === 'symbol') {
		badStringifier[Symbol.toPrimitive] = throwRegexMarker;
	}
}

var $toString = callBound('Object.prototype.toString');
var gOPD = Object.getOwnPropertyDescriptor;
var regexClass = '[object RegExp]';

module.exports = hasToStringTag
	// eslint-disable-next-line consistent-return
	? function isRegex(value) {
		if (!value || typeof value !== 'object') {
			return false;
		}

		var descriptor = gOPD(value, 'lastIndex');
		var hasLastIndexDataProperty = descriptor && has(descriptor, 'value');
		if (!hasLastIndexDataProperty) {
			return false;
		}

		try {
			$exec(value, badStringifier);
		} catch (e) {
			return e === isRegexMarker;
		}
	}
	: function isRegex(value) {
		// In older browsers, typeof regex incorrectly returns 'function'
		if (!value || (typeof value !== 'object' && typeof value !== 'function')) {
			return false;
		}

		return $toString(value) === regexClass;
	};


/***/ }),

/***/ "./node_modules/is-symbol/index.js":
/*!*****************************************!*\
  !*** ./node_modules/is-symbol/index.js ***!
  \*****************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var toStr = Object.prototype.toString;
var hasSymbols = __webpack_require__(/*! has-symbols */ "./node_modules/has-symbols/index.js")();

if (hasSymbols) {
	var symToStr = Symbol.prototype.toString;
	var symStringRegex = /^Symbol\(.*\)$/;
	var isSymbolObject = function isRealSymbolObject(value) {
		if (typeof value.valueOf() !== 'symbol') {
			return false;
		}
		return symStringRegex.test(symToStr.call(value));
	};

	module.exports = function isSymbol(value) {
		if (typeof value === 'symbol') {
			return true;
		}
		if (toStr.call(value) !== '[object Symbol]') {
			return false;
		}
		try {
			return isSymbolObject(value);
		} catch (e) {
			return false;
		}
	};
} else {

	module.exports = function isSymbol(value) {
		// this environment does not support Symbols.
		return  false && 0;
	};
}


/***/ }),

/***/ "./node_modules/object-inspect/index.js":
/*!**********************************************!*\
  !*** ./node_modules/object-inspect/index.js ***!
  \**********************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

var hasMap = typeof Map === 'function' && Map.prototype;
var mapSizeDescriptor = Object.getOwnPropertyDescriptor && hasMap ? Object.getOwnPropertyDescriptor(Map.prototype, 'size') : null;
var mapSize = hasMap && mapSizeDescriptor && typeof mapSizeDescriptor.get === 'function' ? mapSizeDescriptor.get : null;
var mapForEach = hasMap && Map.prototype.forEach;
var hasSet = typeof Set === 'function' && Set.prototype;
var setSizeDescriptor = Object.getOwnPropertyDescriptor && hasSet ? Object.getOwnPropertyDescriptor(Set.prototype, 'size') : null;
var setSize = hasSet && setSizeDescriptor && typeof setSizeDescriptor.get === 'function' ? setSizeDescriptor.get : null;
var setForEach = hasSet && Set.prototype.forEach;
var hasWeakMap = typeof WeakMap === 'function' && WeakMap.prototype;
var weakMapHas = hasWeakMap ? WeakMap.prototype.has : null;
var hasWeakSet = typeof WeakSet === 'function' && WeakSet.prototype;
var weakSetHas = hasWeakSet ? WeakSet.prototype.has : null;
var hasWeakRef = typeof WeakRef === 'function' && WeakRef.prototype;
var weakRefDeref = hasWeakRef ? WeakRef.prototype.deref : null;
var booleanValueOf = Boolean.prototype.valueOf;
var objectToString = Object.prototype.toString;
var functionToString = Function.prototype.toString;
var $match = String.prototype.match;
var $slice = String.prototype.slice;
var $replace = String.prototype.replace;
var $toUpperCase = String.prototype.toUpperCase;
var $toLowerCase = String.prototype.toLowerCase;
var $test = RegExp.prototype.test;
var $concat = Array.prototype.concat;
var $join = Array.prototype.join;
var $arrSlice = Array.prototype.slice;
var $floor = Math.floor;
var bigIntValueOf = typeof BigInt === 'function' ? BigInt.prototype.valueOf : null;
var gOPS = Object.getOwnPropertySymbols;
var symToString = typeof Symbol === 'function' && typeof Symbol.iterator === 'symbol' ? Symbol.prototype.toString : null;
var hasShammedSymbols = typeof Symbol === 'function' && typeof Symbol.iterator === 'object';
// ie, `has-tostringtag/shams
var toStringTag = typeof Symbol === 'function' && Symbol.toStringTag && (typeof Symbol.toStringTag === hasShammedSymbols ? 'object' : 'symbol')
    ? Symbol.toStringTag
    : null;
var isEnumerable = Object.prototype.propertyIsEnumerable;

var gPO = (typeof Reflect === 'function' ? Reflect.getPrototypeOf : Object.getPrototypeOf) || (
    [].__proto__ === Array.prototype // eslint-disable-line no-proto
        ? function (O) {
            return O.__proto__; // eslint-disable-line no-proto
        }
        : null
);

function addNumericSeparator(num, str) {
    if (
        num === Infinity
        || num === -Infinity
        || num !== num
        || (num && num > -1000 && num < 1000)
        || $test.call(/e/, str)
    ) {
        return str;
    }
    var sepRegex = /[0-9](?=(?:[0-9]{3})+(?![0-9]))/g;
    if (typeof num === 'number') {
        var int = num < 0 ? -$floor(-num) : $floor(num); // trunc(num)
        if (int !== num) {
            var intStr = String(int);
            var dec = $slice.call(str, intStr.length + 1);
            return $replace.call(intStr, sepRegex, '$&_') + '.' + $replace.call($replace.call(dec, /([0-9]{3})/g, '$&_'), /_$/, '');
        }
    }
    return $replace.call(str, sepRegex, '$&_');
}

var utilInspect = __webpack_require__(/*! ./util.inspect */ "?4f7e");
var inspectCustom = utilInspect.custom;
var inspectSymbol = isSymbol(inspectCustom) ? inspectCustom : null;

module.exports = function inspect_(obj, options, depth, seen) {
    var opts = options || {};

    if (has(opts, 'quoteStyle') && (opts.quoteStyle !== 'single' && opts.quoteStyle !== 'double')) {
        throw new TypeError('option "quoteStyle" must be "single" or "double"');
    }
    if (
        has(opts, 'maxStringLength') && (typeof opts.maxStringLength === 'number'
            ? opts.maxStringLength < 0 && opts.maxStringLength !== Infinity
            : opts.maxStringLength !== null
        )
    ) {
        throw new TypeError('option "maxStringLength", if provided, must be a positive integer, Infinity, or `null`');
    }
    var customInspect = has(opts, 'customInspect') ? opts.customInspect : true;
    if (typeof customInspect !== 'boolean' && customInspect !== 'symbol') {
        throw new TypeError('option "customInspect", if provided, must be `true`, `false`, or `\'symbol\'`');
    }

    if (
        has(opts, 'indent')
        && opts.indent !== null
        && opts.indent !== '\t'
        && !(parseInt(opts.indent, 10) === opts.indent && opts.indent > 0)
    ) {
        throw new TypeError('option "indent" must be "\\t", an integer > 0, or `null`');
    }
    if (has(opts, 'numericSeparator') && typeof opts.numericSeparator !== 'boolean') {
        throw new TypeError('option "numericSeparator", if provided, must be `true` or `false`');
    }
    var numericSeparator = opts.numericSeparator;

    if (typeof obj === 'undefined') {
        return 'undefined';
    }
    if (obj === null) {
        return 'null';
    }
    if (typeof obj === 'boolean') {
        return obj ? 'true' : 'false';
    }

    if (typeof obj === 'string') {
        return inspectString(obj, opts);
    }
    if (typeof obj === 'number') {
        if (obj === 0) {
            return Infinity / obj > 0 ? '0' : '-0';
        }
        var str = String(obj);
        return numericSeparator ? addNumericSeparator(obj, str) : str;
    }
    if (typeof obj === 'bigint') {
        var bigIntStr = String(obj) + 'n';
        return numericSeparator ? addNumericSeparator(obj, bigIntStr) : bigIntStr;
    }

    var maxDepth = typeof opts.depth === 'undefined' ? 5 : opts.depth;
    if (typeof depth === 'undefined') { depth = 0; }
    if (depth >= maxDepth && maxDepth > 0 && typeof obj === 'object') {
        return isArray(obj) ? '[Array]' : '[Object]';
    }

    var indent = getIndent(opts, depth);

    if (typeof seen === 'undefined') {
        seen = [];
    } else if (indexOf(seen, obj) >= 0) {
        return '[Circular]';
    }

    function inspect(value, from, noIndent) {
        if (from) {
            seen = $arrSlice.call(seen);
            seen.push(from);
        }
        if (noIndent) {
            var newOpts = {
                depth: opts.depth
            };
            if (has(opts, 'quoteStyle')) {
                newOpts.quoteStyle = opts.quoteStyle;
            }
            return inspect_(value, newOpts, depth + 1, seen);
        }
        return inspect_(value, opts, depth + 1, seen);
    }

    if (typeof obj === 'function' && !isRegExp(obj)) { // in older engines, regexes are callable
        var name = nameOf(obj);
        var keys = arrObjKeys(obj, inspect);
        return '[Function' + (name ? ': ' + name : ' (anonymous)') + ']' + (keys.length > 0 ? ' { ' + $join.call(keys, ', ') + ' }' : '');
    }
    if (isSymbol(obj)) {
        var symString = hasShammedSymbols ? $replace.call(String(obj), /^(Symbol\(.*\))_[^)]*$/, '$1') : symToString.call(obj);
        return typeof obj === 'object' && !hasShammedSymbols ? markBoxed(symString) : symString;
    }
    if (isElement(obj)) {
        var s = '<' + $toLowerCase.call(String(obj.nodeName));
        var attrs = obj.attributes || [];
        for (var i = 0; i < attrs.length; i++) {
            s += ' ' + attrs[i].name + '=' + wrapQuotes(quote(attrs[i].value), 'double', opts);
        }
        s += '>';
        if (obj.childNodes && obj.childNodes.length) { s += '...'; }
        s += '</' + $toLowerCase.call(String(obj.nodeName)) + '>';
        return s;
    }
    if (isArray(obj)) {
        if (obj.length === 0) { return '[]'; }
        var xs = arrObjKeys(obj, inspect);
        if (indent && !singleLineValues(xs)) {
            return '[' + indentedJoin(xs, indent) + ']';
        }
        return '[ ' + $join.call(xs, ', ') + ' ]';
    }
    if (isError(obj)) {
        var parts = arrObjKeys(obj, inspect);
        if (!('cause' in Error.prototype) && 'cause' in obj && !isEnumerable.call(obj, 'cause')) {
            return '{ [' + String(obj) + '] ' + $join.call($concat.call('[cause]: ' + inspect(obj.cause), parts), ', ') + ' }';
        }
        if (parts.length === 0) { return '[' + String(obj) + ']'; }
        return '{ [' + String(obj) + '] ' + $join.call(parts, ', ') + ' }';
    }
    if (typeof obj === 'object' && customInspect) {
        if (inspectSymbol && typeof obj[inspectSymbol] === 'function' && utilInspect) {
            return utilInspect(obj, { depth: maxDepth - depth });
        } else if (customInspect !== 'symbol' && typeof obj.inspect === 'function') {
            return obj.inspect();
        }
    }
    if (isMap(obj)) {
        var mapParts = [];
        if (mapForEach) {
            mapForEach.call(obj, function (value, key) {
                mapParts.push(inspect(key, obj, true) + ' => ' + inspect(value, obj));
            });
        }
        return collectionOf('Map', mapSize.call(obj), mapParts, indent);
    }
    if (isSet(obj)) {
        var setParts = [];
        if (setForEach) {
            setForEach.call(obj, function (value) {
                setParts.push(inspect(value, obj));
            });
        }
        return collectionOf('Set', setSize.call(obj), setParts, indent);
    }
    if (isWeakMap(obj)) {
        return weakCollectionOf('WeakMap');
    }
    if (isWeakSet(obj)) {
        return weakCollectionOf('WeakSet');
    }
    if (isWeakRef(obj)) {
        return weakCollectionOf('WeakRef');
    }
    if (isNumber(obj)) {
        return markBoxed(inspect(Number(obj)));
    }
    if (isBigInt(obj)) {
        return markBoxed(inspect(bigIntValueOf.call(obj)));
    }
    if (isBoolean(obj)) {
        return markBoxed(booleanValueOf.call(obj));
    }
    if (isString(obj)) {
        return markBoxed(inspect(String(obj)));
    }
    // note: in IE 8, sometimes `global !== window` but both are the prototypes of each other
    /* eslint-env browser */
    if (typeof window !== 'undefined' && obj === window) {
        return '{ [object Window] }';
    }
    if (obj === __webpack_require__.g) {
        return '{ [object globalThis] }';
    }
    if (!isDate(obj) && !isRegExp(obj)) {
        var ys = arrObjKeys(obj, inspect);
        var isPlainObject = gPO ? gPO(obj) === Object.prototype : obj instanceof Object || obj.constructor === Object;
        var protoTag = obj instanceof Object ? '' : 'null prototype';
        var stringTag = !isPlainObject && toStringTag && Object(obj) === obj && toStringTag in obj ? $slice.call(toStr(obj), 8, -1) : protoTag ? 'Object' : '';
        var constructorTag = isPlainObject || typeof obj.constructor !== 'function' ? '' : obj.constructor.name ? obj.constructor.name + ' ' : '';
        var tag = constructorTag + (stringTag || protoTag ? '[' + $join.call($concat.call([], stringTag || [], protoTag || []), ': ') + '] ' : '');
        if (ys.length === 0) { return tag + '{}'; }
        if (indent) {
            return tag + '{' + indentedJoin(ys, indent) + '}';
        }
        return tag + '{ ' + $join.call(ys, ', ') + ' }';
    }
    return String(obj);
};

function wrapQuotes(s, defaultStyle, opts) {
    var quoteChar = (opts.quoteStyle || defaultStyle) === 'double' ? '"' : "'";
    return quoteChar + s + quoteChar;
}

function quote(s) {
    return $replace.call(String(s), /"/g, '&quot;');
}

function isArray(obj) { return toStr(obj) === '[object Array]' && (!toStringTag || !(typeof obj === 'object' && toStringTag in obj)); }
function isDate(obj) { return toStr(obj) === '[object Date]' && (!toStringTag || !(typeof obj === 'object' && toStringTag in obj)); }
function isRegExp(obj) { return toStr(obj) === '[object RegExp]' && (!toStringTag || !(typeof obj === 'object' && toStringTag in obj)); }
function isError(obj) { return toStr(obj) === '[object Error]' && (!toStringTag || !(typeof obj === 'object' && toStringTag in obj)); }
function isString(obj) { return toStr(obj) === '[object String]' && (!toStringTag || !(typeof obj === 'object' && toStringTag in obj)); }
function isNumber(obj) { return toStr(obj) === '[object Number]' && (!toStringTag || !(typeof obj === 'object' && toStringTag in obj)); }
function isBoolean(obj) { return toStr(obj) === '[object Boolean]' && (!toStringTag || !(typeof obj === 'object' && toStringTag in obj)); }

// Symbol and BigInt do have Symbol.toStringTag by spec, so that can't be used to eliminate false positives
function isSymbol(obj) {
    if (hasShammedSymbols) {
        return obj && typeof obj === 'object' && obj instanceof Symbol;
    }
    if (typeof obj === 'symbol') {
        return true;
    }
    if (!obj || typeof obj !== 'object' || !symToString) {
        return false;
    }
    try {
        symToString.call(obj);
        return true;
    } catch (e) {}
    return false;
}

function isBigInt(obj) {
    if (!obj || typeof obj !== 'object' || !bigIntValueOf) {
        return false;
    }
    try {
        bigIntValueOf.call(obj);
        return true;
    } catch (e) {}
    return false;
}

var hasOwn = Object.prototype.hasOwnProperty || function (key) { return key in this; };
function has(obj, key) {
    return hasOwn.call(obj, key);
}

function toStr(obj) {
    return objectToString.call(obj);
}

function nameOf(f) {
    if (f.name) { return f.name; }
    var m = $match.call(functionToString.call(f), /^function\s*([\w$]+)/);
    if (m) { return m[1]; }
    return null;
}

function indexOf(xs, x) {
    if (xs.indexOf) { return xs.indexOf(x); }
    for (var i = 0, l = xs.length; i < l; i++) {
        if (xs[i] === x) { return i; }
    }
    return -1;
}

function isMap(x) {
    if (!mapSize || !x || typeof x !== 'object') {
        return false;
    }
    try {
        mapSize.call(x);
        try {
            setSize.call(x);
        } catch (s) {
            return true;
        }
        return x instanceof Map; // core-js workaround, pre-v2.5.0
    } catch (e) {}
    return false;
}

function isWeakMap(x) {
    if (!weakMapHas || !x || typeof x !== 'object') {
        return false;
    }
    try {
        weakMapHas.call(x, weakMapHas);
        try {
            weakSetHas.call(x, weakSetHas);
        } catch (s) {
            return true;
        }
        return x instanceof WeakMap; // core-js workaround, pre-v2.5.0
    } catch (e) {}
    return false;
}

function isWeakRef(x) {
    if (!weakRefDeref || !x || typeof x !== 'object') {
        return false;
    }
    try {
        weakRefDeref.call(x);
        return true;
    } catch (e) {}
    return false;
}

function isSet(x) {
    if (!setSize || !x || typeof x !== 'object') {
        return false;
    }
    try {
        setSize.call(x);
        try {
            mapSize.call(x);
        } catch (m) {
            return true;
        }
        return x instanceof Set; // core-js workaround, pre-v2.5.0
    } catch (e) {}
    return false;
}

function isWeakSet(x) {
    if (!weakSetHas || !x || typeof x !== 'object') {
        return false;
    }
    try {
        weakSetHas.call(x, weakSetHas);
        try {
            weakMapHas.call(x, weakMapHas);
        } catch (s) {
            return true;
        }
        return x instanceof WeakSet; // core-js workaround, pre-v2.5.0
    } catch (e) {}
    return false;
}

function isElement(x) {
    if (!x || typeof x !== 'object') { return false; }
    if (typeof HTMLElement !== 'undefined' && x instanceof HTMLElement) {
        return true;
    }
    return typeof x.nodeName === 'string' && typeof x.getAttribute === 'function';
}

function inspectString(str, opts) {
    if (str.length > opts.maxStringLength) {
        var remaining = str.length - opts.maxStringLength;
        var trailer = '... ' + remaining + ' more character' + (remaining > 1 ? 's' : '');
        return inspectString($slice.call(str, 0, opts.maxStringLength), opts) + trailer;
    }
    // eslint-disable-next-line no-control-regex
    var s = $replace.call($replace.call(str, /(['\\])/g, '\\$1'), /[\x00-\x1f]/g, lowbyte);
    return wrapQuotes(s, 'single', opts);
}

function lowbyte(c) {
    var n = c.charCodeAt(0);
    var x = {
        8: 'b',
        9: 't',
        10: 'n',
        12: 'f',
        13: 'r'
    }[n];
    if (x) { return '\\' + x; }
    return '\\x' + (n < 0x10 ? '0' : '') + $toUpperCase.call(n.toString(16));
}

function markBoxed(str) {
    return 'Object(' + str + ')';
}

function weakCollectionOf(type) {
    return type + ' { ? }';
}

function collectionOf(type, size, entries, indent) {
    var joinedEntries = indent ? indentedJoin(entries, indent) : $join.call(entries, ', ');
    return type + ' (' + size + ') {' + joinedEntries + '}';
}

function singleLineValues(xs) {
    for (var i = 0; i < xs.length; i++) {
        if (indexOf(xs[i], '\n') >= 0) {
            return false;
        }
    }
    return true;
}

function getIndent(opts, depth) {
    var baseIndent;
    if (opts.indent === '\t') {
        baseIndent = '\t';
    } else if (typeof opts.indent === 'number' && opts.indent > 0) {
        baseIndent = $join.call(Array(opts.indent + 1), ' ');
    } else {
        return null;
    }
    return {
        base: baseIndent,
        prev: $join.call(Array(depth + 1), baseIndent)
    };
}

function indentedJoin(xs, indent) {
    if (xs.length === 0) { return ''; }
    var lineJoiner = '\n' + indent.prev + indent.base;
    return lineJoiner + $join.call(xs, ',' + lineJoiner) + '\n' + indent.prev;
}

function arrObjKeys(obj, inspect) {
    var isArr = isArray(obj);
    var xs = [];
    if (isArr) {
        xs.length = obj.length;
        for (var i = 0; i < obj.length; i++) {
            xs[i] = has(obj, i) ? inspect(obj[i], obj) : '';
        }
    }
    var syms = typeof gOPS === 'function' ? gOPS(obj) : [];
    var symMap;
    if (hasShammedSymbols) {
        symMap = {};
        for (var k = 0; k < syms.length; k++) {
            symMap['$' + syms[k]] = syms[k];
        }
    }

    for (var key in obj) { // eslint-disable-line no-restricted-syntax
        if (!has(obj, key)) { continue; } // eslint-disable-line no-restricted-syntax, no-continue
        if (isArr && String(Number(key)) === key && key < obj.length) { continue; } // eslint-disable-line no-restricted-syntax, no-continue
        if (hasShammedSymbols && symMap['$' + key] instanceof Symbol) {
            // this is to prevent shammed Symbols, which are stored as strings, from being included in the string key section
            continue; // eslint-disable-line no-restricted-syntax, no-continue
        } else if ($test.call(/[^\w$]/, key)) {
            xs.push(inspect(key, obj) + ': ' + inspect(obj[key], obj));
        } else {
            xs.push(key + ': ' + inspect(obj[key], obj));
        }
    }
    if (typeof gOPS === 'function') {
        for (var j = 0; j < syms.length; j++) {
            if (isEnumerable.call(obj, syms[j])) {
                xs.push('[' + inspect(syms[j]) + ']: ' + inspect(obj[syms[j]], obj));
            }
        }
    }
    return xs;
}


/***/ }),

/***/ "./node_modules/object-keys/implementation.js":
/*!****************************************************!*\
  !*** ./node_modules/object-keys/implementation.js ***!
  \****************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var keysShim;
if (!Object.keys) {
	// modified from https://github.com/es-shims/es5-shim
	var has = Object.prototype.hasOwnProperty;
	var toStr = Object.prototype.toString;
	var isArgs = __webpack_require__(/*! ./isArguments */ "./node_modules/object-keys/isArguments.js"); // eslint-disable-line global-require
	var isEnumerable = Object.prototype.propertyIsEnumerable;
	var hasDontEnumBug = !isEnumerable.call({ toString: null }, 'toString');
	var hasProtoEnumBug = isEnumerable.call(function () {}, 'prototype');
	var dontEnums = [
		'toString',
		'toLocaleString',
		'valueOf',
		'hasOwnProperty',
		'isPrototypeOf',
		'propertyIsEnumerable',
		'constructor'
	];
	var equalsConstructorPrototype = function (o) {
		var ctor = o.constructor;
		return ctor && ctor.prototype === o;
	};
	var excludedKeys = {
		$applicationCache: true,
		$console: true,
		$external: true,
		$frame: true,
		$frameElement: true,
		$frames: true,
		$innerHeight: true,
		$innerWidth: true,
		$onmozfullscreenchange: true,
		$onmozfullscreenerror: true,
		$outerHeight: true,
		$outerWidth: true,
		$pageXOffset: true,
		$pageYOffset: true,
		$parent: true,
		$scrollLeft: true,
		$scrollTop: true,
		$scrollX: true,
		$scrollY: true,
		$self: true,
		$webkitIndexedDB: true,
		$webkitStorageInfo: true,
		$window: true
	};
	var hasAutomationEqualityBug = (function () {
		/* global window */
		if (typeof window === 'undefined') { return false; }
		for (var k in window) {
			try {
				if (!excludedKeys['$' + k] && has.call(window, k) && window[k] !== null && typeof window[k] === 'object') {
					try {
						equalsConstructorPrototype(window[k]);
					} catch (e) {
						return true;
					}
				}
			} catch (e) {
				return true;
			}
		}
		return false;
	}());
	var equalsConstructorPrototypeIfNotBuggy = function (o) {
		/* global window */
		if (typeof window === 'undefined' || !hasAutomationEqualityBug) {
			return equalsConstructorPrototype(o);
		}
		try {
			return equalsConstructorPrototype(o);
		} catch (e) {
			return false;
		}
	};

	keysShim = function keys(object) {
		var isObject = object !== null && typeof object === 'object';
		var isFunction = toStr.call(object) === '[object Function]';
		var isArguments = isArgs(object);
		var isString = isObject && toStr.call(object) === '[object String]';
		var theKeys = [];

		if (!isObject && !isFunction && !isArguments) {
			throw new TypeError('Object.keys called on a non-object');
		}

		var skipProto = hasProtoEnumBug && isFunction;
		if (isString && object.length > 0 && !has.call(object, 0)) {
			for (var i = 0; i < object.length; ++i) {
				theKeys.push(String(i));
			}
		}

		if (isArguments && object.length > 0) {
			for (var j = 0; j < object.length; ++j) {
				theKeys.push(String(j));
			}
		} else {
			for (var name in object) {
				if (!(skipProto && name === 'prototype') && has.call(object, name)) {
					theKeys.push(String(name));
				}
			}
		}

		if (hasDontEnumBug) {
			var skipConstructor = equalsConstructorPrototypeIfNotBuggy(object);

			for (var k = 0; k < dontEnums.length; ++k) {
				if (!(skipConstructor && dontEnums[k] === 'constructor') && has.call(object, dontEnums[k])) {
					theKeys.push(dontEnums[k]);
				}
			}
		}
		return theKeys;
	};
}
module.exports = keysShim;


/***/ }),

/***/ "./node_modules/object-keys/index.js":
/*!*******************************************!*\
  !*** ./node_modules/object-keys/index.js ***!
  \*******************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var slice = Array.prototype.slice;
var isArgs = __webpack_require__(/*! ./isArguments */ "./node_modules/object-keys/isArguments.js");

var origKeys = Object.keys;
var keysShim = origKeys ? function keys(o) { return origKeys(o); } : __webpack_require__(/*! ./implementation */ "./node_modules/object-keys/implementation.js");

var originalKeys = Object.keys;

keysShim.shim = function shimObjectKeys() {
	if (Object.keys) {
		var keysWorksWithArguments = (function () {
			// Safari 5.0 bug
			var args = Object.keys(arguments);
			return args && args.length === arguments.length;
		}(1, 2));
		if (!keysWorksWithArguments) {
			Object.keys = function keys(object) { // eslint-disable-line func-name-matching
				if (isArgs(object)) {
					return originalKeys(slice.call(object));
				}
				return originalKeys(object);
			};
		}
	} else {
		Object.keys = keysShim;
	}
	return Object.keys || keysShim;
};

module.exports = keysShim;


/***/ }),

/***/ "./node_modules/object-keys/isArguments.js":
/*!*************************************************!*\
  !*** ./node_modules/object-keys/isArguments.js ***!
  \*************************************************/
/***/ ((module) => {

"use strict";


var toStr = Object.prototype.toString;

module.exports = function isArguments(value) {
	var str = toStr.call(value);
	var isArgs = str === '[object Arguments]';
	if (!isArgs) {
		isArgs = str !== '[object Array]' &&
			value !== null &&
			typeof value === 'object' &&
			typeof value.length === 'number' &&
			value.length >= 0 &&
			toStr.call(value.callee) === '[object Function]';
	}
	return isArgs;
};


/***/ }),

/***/ "./node_modules/regexp.prototype.flags/implementation.js":
/*!***************************************************************!*\
  !*** ./node_modules/regexp.prototype.flags/implementation.js ***!
  \***************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var setFunctionName = __webpack_require__(/*! set-function-name */ "./node_modules/set-function-name/index.js");

var $Object = Object;
var $TypeError = TypeError;

module.exports = setFunctionName(function flags() {
	if (this != null && this !== $Object(this)) {
		throw new $TypeError('RegExp.prototype.flags getter called on non-object');
	}
	var result = '';
	if (this.hasIndices) {
		result += 'd';
	}
	if (this.global) {
		result += 'g';
	}
	if (this.ignoreCase) {
		result += 'i';
	}
	if (this.multiline) {
		result += 'm';
	}
	if (this.dotAll) {
		result += 's';
	}
	if (this.unicode) {
		result += 'u';
	}
	if (this.unicodeSets) {
		result += 'v';
	}
	if (this.sticky) {
		result += 'y';
	}
	return result;
}, 'get flags', true);



/***/ }),

/***/ "./node_modules/regexp.prototype.flags/index.js":
/*!******************************************************!*\
  !*** ./node_modules/regexp.prototype.flags/index.js ***!
  \******************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var define = __webpack_require__(/*! define-properties */ "./node_modules/define-properties/index.js");
var callBind = __webpack_require__(/*! call-bind */ "./node_modules/call-bind/index.js");

var implementation = __webpack_require__(/*! ./implementation */ "./node_modules/regexp.prototype.flags/implementation.js");
var getPolyfill = __webpack_require__(/*! ./polyfill */ "./node_modules/regexp.prototype.flags/polyfill.js");
var shim = __webpack_require__(/*! ./shim */ "./node_modules/regexp.prototype.flags/shim.js");

var flagsBound = callBind(getPolyfill());

define(flagsBound, {
	getPolyfill: getPolyfill,
	implementation: implementation,
	shim: shim
});

module.exports = flagsBound;


/***/ }),

/***/ "./node_modules/regexp.prototype.flags/polyfill.js":
/*!*********************************************************!*\
  !*** ./node_modules/regexp.prototype.flags/polyfill.js ***!
  \*********************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var implementation = __webpack_require__(/*! ./implementation */ "./node_modules/regexp.prototype.flags/implementation.js");

var supportsDescriptors = (__webpack_require__(/*! define-properties */ "./node_modules/define-properties/index.js").supportsDescriptors);
var $gOPD = Object.getOwnPropertyDescriptor;

module.exports = function getPolyfill() {
	if (supportsDescriptors && (/a/mig).flags === 'gim') {
		var descriptor = $gOPD(RegExp.prototype, 'flags');
		if (
			descriptor
			&& typeof descriptor.get === 'function'
			&& typeof RegExp.prototype.dotAll === 'boolean'
			&& typeof RegExp.prototype.hasIndices === 'boolean'
		) {
			/* eslint getter-return: 0 */
			var calls = '';
			var o = {};
			Object.defineProperty(o, 'hasIndices', {
				get: function () {
					calls += 'd';
				}
			});
			Object.defineProperty(o, 'sticky', {
				get: function () {
					calls += 'y';
				}
			});
			if (calls === 'dy') {
				return descriptor.get;
			}
		}
	}
	return implementation;
};


/***/ }),

/***/ "./node_modules/regexp.prototype.flags/shim.js":
/*!*****************************************************!*\
  !*** ./node_modules/regexp.prototype.flags/shim.js ***!
  \*****************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var supportsDescriptors = (__webpack_require__(/*! define-properties */ "./node_modules/define-properties/index.js").supportsDescriptors);
var getPolyfill = __webpack_require__(/*! ./polyfill */ "./node_modules/regexp.prototype.flags/polyfill.js");
var gOPD = Object.getOwnPropertyDescriptor;
var defineProperty = Object.defineProperty;
var TypeErr = TypeError;
var getProto = Object.getPrototypeOf;
var regex = /a/;

module.exports = function shimFlags() {
	if (!supportsDescriptors || !getProto) {
		throw new TypeErr('RegExp.prototype.flags requires a true ES5 environment that supports property descriptors');
	}
	var polyfill = getPolyfill();
	var proto = getProto(regex);
	var descriptor = gOPD(proto, 'flags');
	if (!descriptor || descriptor.get !== polyfill) {
		defineProperty(proto, 'flags', {
			configurable: true,
			enumerable: false,
			get: polyfill
		});
	}
	return polyfill;
};


/***/ }),

/***/ "./node_modules/safe-regex-test/index.js":
/*!***********************************************!*\
  !*** ./node_modules/safe-regex-test/index.js ***!
  \***********************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var callBound = __webpack_require__(/*! call-bind/callBound */ "./node_modules/call-bind/callBound.js");
var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");
var isRegex = __webpack_require__(/*! is-regex */ "./node_modules/is-regex/index.js");

var $exec = callBound('RegExp.prototype.exec');
var $TypeError = GetIntrinsic('%TypeError%');

module.exports = function regexTester(regex) {
	if (!isRegex(regex)) {
		throw new $TypeError('`regex` must be a RegExp');
	}
	return function test(s) {
		return $exec(regex, s) !== null;
	};
};


/***/ }),

/***/ "./node_modules/set-function-length/index.js":
/*!***************************************************!*\
  !*** ./node_modules/set-function-length/index.js ***!
  \***************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");
var define = __webpack_require__(/*! define-data-property */ "./node_modules/define-data-property/index.js");
var hasDescriptors = __webpack_require__(/*! has-property-descriptors */ "./node_modules/has-property-descriptors/index.js")();
var gOPD = __webpack_require__(/*! gopd */ "./node_modules/gopd/index.js");

var $TypeError = GetIntrinsic('%TypeError%');
var $floor = GetIntrinsic('%Math.floor%');

module.exports = function setFunctionLength(fn, length) {
	if (typeof fn !== 'function') {
		throw new $TypeError('`fn` is not a function');
	}
	if (typeof length !== 'number' || length < 0 || length > 0xFFFFFFFF || $floor(length) !== length) {
		throw new $TypeError('`length` must be a positive 32-bit integer');
	}

	var loose = arguments.length > 2 && !!arguments[2];

	var functionLengthIsConfigurable = true;
	var functionLengthIsWritable = true;
	if ('length' in fn && gOPD) {
		var desc = gOPD(fn, 'length');
		if (desc && !desc.configurable) {
			functionLengthIsConfigurable = false;
		}
		if (desc && !desc.writable) {
			functionLengthIsWritable = false;
		}
	}

	if (functionLengthIsConfigurable || functionLengthIsWritable || !loose) {
		if (hasDescriptors) {
			define(fn, 'length', length, true, true);
		} else {
			define(fn, 'length', length);
		}
	}
	return fn;
};


/***/ }),

/***/ "./node_modules/set-function-name/index.js":
/*!*************************************************!*\
  !*** ./node_modules/set-function-name/index.js ***!
  \*************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var define = __webpack_require__(/*! define-data-property */ "./node_modules/define-data-property/index.js");
var hasDescriptors = __webpack_require__(/*! has-property-descriptors */ "./node_modules/has-property-descriptors/index.js")();
var functionsHaveConfigurableNames = (__webpack_require__(/*! functions-have-names */ "./node_modules/functions-have-names/index.js").functionsHaveConfigurableNames)();

var $TypeError = TypeError;

module.exports = function setFunctionName(fn, name) {
	if (typeof fn !== 'function') {
		throw new $TypeError('`fn` is not a function');
	}
	var loose = arguments.length > 2 && !!arguments[2];
	if (!loose || functionsHaveConfigurableNames) {
		if (hasDescriptors) {
			define(fn, 'name', name, true, true);
		} else {
			define(fn, 'name', name);
		}
	}
	return fn;
};


/***/ }),

/***/ "./node_modules/side-channel/index.js":
/*!********************************************!*\
  !*** ./node_modules/side-channel/index.js ***!
  \********************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");
var callBound = __webpack_require__(/*! call-bind/callBound */ "./node_modules/call-bind/callBound.js");
var inspect = __webpack_require__(/*! object-inspect */ "./node_modules/object-inspect/index.js");

var $TypeError = GetIntrinsic('%TypeError%');
var $WeakMap = GetIntrinsic('%WeakMap%', true);
var $Map = GetIntrinsic('%Map%', true);

var $weakMapGet = callBound('WeakMap.prototype.get', true);
var $weakMapSet = callBound('WeakMap.prototype.set', true);
var $weakMapHas = callBound('WeakMap.prototype.has', true);
var $mapGet = callBound('Map.prototype.get', true);
var $mapSet = callBound('Map.prototype.set', true);
var $mapHas = callBound('Map.prototype.has', true);

/*
 * This function traverses the list returning the node corresponding to the
 * given key.
 *
 * That node is also moved to the head of the list, so that if it's accessed
 * again we don't need to traverse the whole list. By doing so, all the recently
 * used nodes can be accessed relatively quickly.
 */
var listGetNode = function (list, key) { // eslint-disable-line consistent-return
	for (var prev = list, curr; (curr = prev.next) !== null; prev = curr) {
		if (curr.key === key) {
			prev.next = curr.next;
			curr.next = list.next;
			list.next = curr; // eslint-disable-line no-param-reassign
			return curr;
		}
	}
};

var listGet = function (objects, key) {
	var node = listGetNode(objects, key);
	return node && node.value;
};
var listSet = function (objects, key, value) {
	var node = listGetNode(objects, key);
	if (node) {
		node.value = value;
	} else {
		// Prepend the new node to the beginning of the list
		objects.next = { // eslint-disable-line no-param-reassign
			key: key,
			next: objects.next,
			value: value
		};
	}
};
var listHas = function (objects, key) {
	return !!listGetNode(objects, key);
};

module.exports = function getSideChannel() {
	var $wm;
	var $m;
	var $o;
	var channel = {
		assert: function (key) {
			if (!channel.has(key)) {
				throw new $TypeError('Side channel does not contain ' + inspect(key));
			}
		},
		get: function (key) { // eslint-disable-line consistent-return
			if ($WeakMap && key && (typeof key === 'object' || typeof key === 'function')) {
				if ($wm) {
					return $weakMapGet($wm, key);
				}
			} else if ($Map) {
				if ($m) {
					return $mapGet($m, key);
				}
			} else {
				if ($o) { // eslint-disable-line no-lonely-if
					return listGet($o, key);
				}
			}
		},
		has: function (key) {
			if ($WeakMap && key && (typeof key === 'object' || typeof key === 'function')) {
				if ($wm) {
					return $weakMapHas($wm, key);
				}
			} else if ($Map) {
				if ($m) {
					return $mapHas($m, key);
				}
			} else {
				if ($o) { // eslint-disable-line no-lonely-if
					return listHas($o, key);
				}
			}
			return false;
		},
		set: function (key, value) {
			if ($WeakMap && key && (typeof key === 'object' || typeof key === 'function')) {
				if (!$wm) {
					$wm = new $WeakMap();
				}
				$weakMapSet($wm, key, value);
			} else if ($Map) {
				if (!$m) {
					$m = new $Map();
				}
				$mapSet($m, key, value);
			} else {
				if (!$o) {
					/*
					 * Initialize the linked list as an empty node, so that we don't have
					 * to special-case handling of the first node: we can always refer to
					 * it as (previous node).next, instead of something like (list).head
					 */
					$o = { key: {}, next: null };
				}
				listSet($o, key, value);
			}
		}
	};
	return channel;
};


/***/ }),

/***/ "./node_modules/string.prototype.matchall/implementation.js":
/*!******************************************************************!*\
  !*** ./node_modules/string.prototype.matchall/implementation.js ***!
  \******************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var Call = __webpack_require__(/*! es-abstract/2023/Call */ "./node_modules/es-abstract/2023/Call.js");
var Get = __webpack_require__(/*! es-abstract/2023/Get */ "./node_modules/es-abstract/2023/Get.js");
var GetMethod = __webpack_require__(/*! es-abstract/2023/GetMethod */ "./node_modules/es-abstract/2023/GetMethod.js");
var IsRegExp = __webpack_require__(/*! es-abstract/2023/IsRegExp */ "./node_modules/es-abstract/2023/IsRegExp.js");
var ToString = __webpack_require__(/*! es-abstract/2023/ToString */ "./node_modules/es-abstract/2023/ToString.js");
var RequireObjectCoercible = __webpack_require__(/*! es-abstract/2023/RequireObjectCoercible */ "./node_modules/es-abstract/2023/RequireObjectCoercible.js");
var callBound = __webpack_require__(/*! call-bind/callBound */ "./node_modules/call-bind/callBound.js");
var hasSymbols = __webpack_require__(/*! has-symbols */ "./node_modules/has-symbols/index.js")();
var flagsGetter = __webpack_require__(/*! regexp.prototype.flags */ "./node_modules/regexp.prototype.flags/index.js");

var $indexOf = callBound('String.prototype.indexOf');

var regexpMatchAllPolyfill = __webpack_require__(/*! ./polyfill-regexp-matchall */ "./node_modules/string.prototype.matchall/polyfill-regexp-matchall.js");

var getMatcher = function getMatcher(regexp) { // eslint-disable-line consistent-return
	var matcherPolyfill = regexpMatchAllPolyfill();
	if (hasSymbols && typeof Symbol.matchAll === 'symbol') {
		var matcher = GetMethod(regexp, Symbol.matchAll);
		if (matcher === RegExp.prototype[Symbol.matchAll] && matcher !== matcherPolyfill) {
			return matcherPolyfill;
		}
		return matcher;
	}
	// fallback for pre-Symbol.matchAll environments
	if (IsRegExp(regexp)) {
		return matcherPolyfill;
	}
};

module.exports = function matchAll(regexp) {
	var O = RequireObjectCoercible(this);

	if (typeof regexp !== 'undefined' && regexp !== null) {
		var isRegExp = IsRegExp(regexp);
		if (isRegExp) {
			// workaround for older engines that lack RegExp.prototype.flags
			var flags = 'flags' in regexp ? Get(regexp, 'flags') : flagsGetter(regexp);
			RequireObjectCoercible(flags);
			if ($indexOf(ToString(flags), 'g') < 0) {
				throw new TypeError('matchAll requires a global regular expression');
			}
		}

		var matcher = getMatcher(regexp);
		if (typeof matcher !== 'undefined') {
			return Call(matcher, regexp, [O]);
		}
	}

	var S = ToString(O);
	// var rx = RegExpCreate(regexp, 'g');
	var rx = new RegExp(regexp, 'g');
	return Call(getMatcher(rx), rx, [S]);
};


/***/ }),

/***/ "./node_modules/string.prototype.matchall/index.js":
/*!*********************************************************!*\
  !*** ./node_modules/string.prototype.matchall/index.js ***!
  \*********************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var callBind = __webpack_require__(/*! call-bind */ "./node_modules/call-bind/index.js");
var define = __webpack_require__(/*! define-properties */ "./node_modules/define-properties/index.js");

var implementation = __webpack_require__(/*! ./implementation */ "./node_modules/string.prototype.matchall/implementation.js");
var getPolyfill = __webpack_require__(/*! ./polyfill */ "./node_modules/string.prototype.matchall/polyfill.js");
var shim = __webpack_require__(/*! ./shim */ "./node_modules/string.prototype.matchall/shim.js");

var boundMatchAll = callBind(implementation);

define(boundMatchAll, {
	getPolyfill: getPolyfill,
	implementation: implementation,
	shim: shim
});

module.exports = boundMatchAll;


/***/ }),

/***/ "./node_modules/string.prototype.matchall/polyfill-regexp-matchall.js":
/*!****************************************************************************!*\
  !*** ./node_modules/string.prototype.matchall/polyfill-regexp-matchall.js ***!
  \****************************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var hasSymbols = __webpack_require__(/*! has-symbols */ "./node_modules/has-symbols/index.js")();
var regexpMatchAll = __webpack_require__(/*! ./regexp-matchall */ "./node_modules/string.prototype.matchall/regexp-matchall.js");

module.exports = function getRegExpMatchAllPolyfill() {
	if (!hasSymbols || typeof Symbol.matchAll !== 'symbol' || typeof RegExp.prototype[Symbol.matchAll] !== 'function') {
		return regexpMatchAll;
	}
	return RegExp.prototype[Symbol.matchAll];
};


/***/ }),

/***/ "./node_modules/string.prototype.matchall/polyfill.js":
/*!************************************************************!*\
  !*** ./node_modules/string.prototype.matchall/polyfill.js ***!
  \************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var implementation = __webpack_require__(/*! ./implementation */ "./node_modules/string.prototype.matchall/implementation.js");

module.exports = function getPolyfill() {
	if (String.prototype.matchAll) {
		try {
			''.matchAll(RegExp.prototype);
		} catch (e) {
			return String.prototype.matchAll;
		}
	}
	return implementation;
};


/***/ }),

/***/ "./node_modules/string.prototype.matchall/regexp-matchall.js":
/*!*******************************************************************!*\
  !*** ./node_modules/string.prototype.matchall/regexp-matchall.js ***!
  \*******************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


// var Construct = require('es-abstract/2023/Construct');
var CreateRegExpStringIterator = __webpack_require__(/*! es-abstract/2023/CreateRegExpStringIterator */ "./node_modules/es-abstract/2023/CreateRegExpStringIterator.js");
var Get = __webpack_require__(/*! es-abstract/2023/Get */ "./node_modules/es-abstract/2023/Get.js");
var Set = __webpack_require__(/*! es-abstract/2023/Set */ "./node_modules/es-abstract/2023/Set.js");
var SpeciesConstructor = __webpack_require__(/*! es-abstract/2023/SpeciesConstructor */ "./node_modules/es-abstract/2023/SpeciesConstructor.js");
var ToLength = __webpack_require__(/*! es-abstract/2023/ToLength */ "./node_modules/es-abstract/2023/ToLength.js");
var ToString = __webpack_require__(/*! es-abstract/2023/ToString */ "./node_modules/es-abstract/2023/ToString.js");
var Type = __webpack_require__(/*! es-abstract/2023/Type */ "./node_modules/es-abstract/2023/Type.js");
var flagsGetter = __webpack_require__(/*! regexp.prototype.flags */ "./node_modules/regexp.prototype.flags/index.js");
var setFunctionName = __webpack_require__(/*! set-function-name */ "./node_modules/set-function-name/index.js");
var callBound = __webpack_require__(/*! call-bind/callBound */ "./node_modules/call-bind/callBound.js");

var $indexOf = callBound('String.prototype.indexOf');

var OrigRegExp = RegExp;

var supportsConstructingWithFlags = 'flags' in RegExp.prototype;

var constructRegexWithFlags = function constructRegex(C, R) {
	var matcher;
	// workaround for older engines that lack RegExp.prototype.flags
	var flags = 'flags' in R ? Get(R, 'flags') : ToString(flagsGetter(R));
	if (supportsConstructingWithFlags && typeof flags === 'string') {
		matcher = new C(R, flags);
	} else if (C === OrigRegExp) {
		// workaround for older engines that can not construct a RegExp with flags
		matcher = new C(R.source, flags);
	} else {
		matcher = new C(R, flags);
	}
	return { flags: flags, matcher: matcher };
};

var regexMatchAll = setFunctionName(function SymbolMatchAll(string) {
	var R = this;
	if (Type(R) !== 'Object') {
		throw new TypeError('"this" value must be an Object');
	}
	var S = ToString(string);
	var C = SpeciesConstructor(R, OrigRegExp);

	var tmp = constructRegexWithFlags(C, R);
	// var flags = ToString(Get(R, 'flags'));
	var flags = tmp.flags;
	// var matcher = Construct(C, [R, flags]);
	var matcher = tmp.matcher;

	var lastIndex = ToLength(Get(R, 'lastIndex'));
	Set(matcher, 'lastIndex', lastIndex, true);
	var global = $indexOf(flags, 'g') > -1;
	var fullUnicode = $indexOf(flags, 'u') > -1;
	return CreateRegExpStringIterator(matcher, S, global, fullUnicode);
}, '[Symbol.matchAll]', true);

module.exports = regexMatchAll;


/***/ }),

/***/ "./node_modules/string.prototype.matchall/shim.js":
/*!********************************************************!*\
  !*** ./node_modules/string.prototype.matchall/shim.js ***!
  \********************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var define = __webpack_require__(/*! define-properties */ "./node_modules/define-properties/index.js");
var hasSymbols = __webpack_require__(/*! has-symbols */ "./node_modules/has-symbols/index.js")();
var getPolyfill = __webpack_require__(/*! ./polyfill */ "./node_modules/string.prototype.matchall/polyfill.js");
var regexpMatchAllPolyfill = __webpack_require__(/*! ./polyfill-regexp-matchall */ "./node_modules/string.prototype.matchall/polyfill-regexp-matchall.js");

var defineP = Object.defineProperty;
var gOPD = Object.getOwnPropertyDescriptor;

module.exports = function shimMatchAll() {
	var polyfill = getPolyfill();
	define(
		String.prototype,
		{ matchAll: polyfill },
		{ matchAll: function () { return String.prototype.matchAll !== polyfill; } }
	);
	if (hasSymbols) {
		// eslint-disable-next-line no-restricted-properties
		var symbol = Symbol.matchAll || (Symbol['for'] ? Symbol['for']('Symbol.matchAll') : Symbol('Symbol.matchAll'));
		define(
			Symbol,
			{ matchAll: symbol },
			{ matchAll: function () { return Symbol.matchAll !== symbol; } }
		);

		if (defineP && gOPD) {
			var desc = gOPD(Symbol, symbol);
			if (!desc || desc.configurable) {
				defineP(Symbol, symbol, {
					configurable: false,
					enumerable: false,
					value: symbol,
					writable: false
				});
			}
		}

		var regexpMatchAll = regexpMatchAllPolyfill();
		var func = {};
		func[symbol] = regexpMatchAll;
		var predicate = {};
		predicate[symbol] = function () {
			return RegExp.prototype[symbol] !== regexpMatchAll;
		};
		define(RegExp.prototype, func, predicate);
	}
	return polyfill;
};


/***/ }),

/***/ "./node_modules/string.prototype.trim/implementation.js":
/*!**************************************************************!*\
  !*** ./node_modules/string.prototype.trim/implementation.js ***!
  \**************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var RequireObjectCoercible = __webpack_require__(/*! es-abstract/2023/RequireObjectCoercible */ "./node_modules/es-abstract/2023/RequireObjectCoercible.js");
var ToString = __webpack_require__(/*! es-abstract/2023/ToString */ "./node_modules/es-abstract/2023/ToString.js");
var callBound = __webpack_require__(/*! call-bind/callBound */ "./node_modules/call-bind/callBound.js");
var $replace = callBound('String.prototype.replace');

var mvsIsWS = (/^\s$/).test('\u180E');
/* eslint-disable no-control-regex */
var leftWhitespace = mvsIsWS
	? /^[\x09\x0A\x0B\x0C\x0D\x20\xA0\u1680\u180E\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u202F\u205F\u3000\u2028\u2029\uFEFF]+/
	: /^[\x09\x0A\x0B\x0C\x0D\x20\xA0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u202F\u205F\u3000\u2028\u2029\uFEFF]+/;
var rightWhitespace = mvsIsWS
	? /[\x09\x0A\x0B\x0C\x0D\x20\xA0\u1680\u180E\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u202F\u205F\u3000\u2028\u2029\uFEFF]+$/
	: /[\x09\x0A\x0B\x0C\x0D\x20\xA0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u202F\u205F\u3000\u2028\u2029\uFEFF]+$/;
/* eslint-enable no-control-regex */

module.exports = function trim() {
	var S = ToString(RequireObjectCoercible(this));
	return $replace($replace(S, leftWhitespace, ''), rightWhitespace, '');
};


/***/ }),

/***/ "./node_modules/string.prototype.trim/index.js":
/*!*****************************************************!*\
  !*** ./node_modules/string.prototype.trim/index.js ***!
  \*****************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var callBind = __webpack_require__(/*! call-bind */ "./node_modules/call-bind/index.js");
var define = __webpack_require__(/*! define-properties */ "./node_modules/define-properties/index.js");
var RequireObjectCoercible = __webpack_require__(/*! es-abstract/2023/RequireObjectCoercible */ "./node_modules/es-abstract/2023/RequireObjectCoercible.js");

var implementation = __webpack_require__(/*! ./implementation */ "./node_modules/string.prototype.trim/implementation.js");
var getPolyfill = __webpack_require__(/*! ./polyfill */ "./node_modules/string.prototype.trim/polyfill.js");
var shim = __webpack_require__(/*! ./shim */ "./node_modules/string.prototype.trim/shim.js");

var bound = callBind(getPolyfill());
var boundMethod = function trim(receiver) {
	RequireObjectCoercible(receiver);
	return bound(receiver);
};

define(boundMethod, {
	getPolyfill: getPolyfill,
	implementation: implementation,
	shim: shim
});

module.exports = boundMethod;


/***/ }),

/***/ "./node_modules/string.prototype.trim/polyfill.js":
/*!********************************************************!*\
  !*** ./node_modules/string.prototype.trim/polyfill.js ***!
  \********************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var implementation = __webpack_require__(/*! ./implementation */ "./node_modules/string.prototype.trim/implementation.js");

var zeroWidthSpace = '\u200b';
var mongolianVowelSeparator = '\u180E';

module.exports = function getPolyfill() {
	if (
		String.prototype.trim
		&& zeroWidthSpace.trim() === zeroWidthSpace
		&& mongolianVowelSeparator.trim() === mongolianVowelSeparator
		&& ('_' + mongolianVowelSeparator).trim() === ('_' + mongolianVowelSeparator)
		&& (mongolianVowelSeparator + '_').trim() === (mongolianVowelSeparator + '_')
	) {
		return String.prototype.trim;
	}
	return implementation;
};


/***/ }),

/***/ "./node_modules/string.prototype.trim/shim.js":
/*!****************************************************!*\
  !*** ./node_modules/string.prototype.trim/shim.js ***!
  \****************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var define = __webpack_require__(/*! define-properties */ "./node_modules/define-properties/index.js");
var getPolyfill = __webpack_require__(/*! ./polyfill */ "./node_modules/string.prototype.trim/polyfill.js");

module.exports = function shimStringTrim() {
	var polyfill = getPolyfill();
	define(String.prototype, { trim: polyfill }, {
		trim: function testTrim() {
			return String.prototype.trim !== polyfill;
		}
	});
	return polyfill;
};


/***/ }),

/***/ "?4f7e":
/*!********************************!*\
  !*** ./util.inspect (ignored) ***!
  \********************************/
/***/ (() => {

/* (ignored) */

/***/ }),

/***/ "./node_modules/es-abstract/2023/AdvanceStringIndex.js":
/*!*************************************************************!*\
  !*** ./node_modules/es-abstract/2023/AdvanceStringIndex.js ***!
  \*************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var CodePointAt = __webpack_require__(/*! ./CodePointAt */ "./node_modules/es-abstract/2023/CodePointAt.js");
var Type = __webpack_require__(/*! ./Type */ "./node_modules/es-abstract/2023/Type.js");

var isInteger = __webpack_require__(/*! ../helpers/isInteger */ "./node_modules/es-abstract/helpers/isInteger.js");
var MAX_SAFE_INTEGER = __webpack_require__(/*! ../helpers/maxSafeInteger */ "./node_modules/es-abstract/helpers/maxSafeInteger.js");

var $TypeError = GetIntrinsic('%TypeError%');

// https://262.ecma-international.org/12.0/#sec-advancestringindex

module.exports = function AdvanceStringIndex(S, index, unicode) {
	if (Type(S) !== 'String') {
		throw new $TypeError('Assertion failed: `S` must be a String');
	}
	if (!isInteger(index) || index < 0 || index > MAX_SAFE_INTEGER) {
		throw new $TypeError('Assertion failed: `length` must be an integer >= 0 and <= 2**53');
	}
	if (Type(unicode) !== 'Boolean') {
		throw new $TypeError('Assertion failed: `unicode` must be a Boolean');
	}
	if (!unicode) {
		return index + 1;
	}
	var length = S.length;
	if ((index + 1) >= length) {
		return index + 1;
	}
	var cp = CodePointAt(S, index);
	return index + cp['[[CodeUnitCount]]'];
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/Call.js":
/*!***********************************************!*\
  !*** ./node_modules/es-abstract/2023/Call.js ***!
  \***********************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");
var callBound = __webpack_require__(/*! call-bind/callBound */ "./node_modules/es-abstract/node_modules/call-bind/callBound.js");

var $TypeError = GetIntrinsic('%TypeError%');

var IsArray = __webpack_require__(/*! ./IsArray */ "./node_modules/es-abstract/2023/IsArray.js");

var $apply = GetIntrinsic('%Reflect.apply%', true) || callBound('Function.prototype.apply');

// https://262.ecma-international.org/6.0/#sec-call

module.exports = function Call(F, V) {
	var argumentsList = arguments.length > 2 ? arguments[2] : [];
	if (!IsArray(argumentsList)) {
		throw new $TypeError('Assertion failed: optional `argumentsList`, if provided, must be a List');
	}
	return $apply(F, V, argumentsList);
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/CodePointAt.js":
/*!******************************************************!*\
  !*** ./node_modules/es-abstract/2023/CodePointAt.js ***!
  \******************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $TypeError = GetIntrinsic('%TypeError%');
var callBound = __webpack_require__(/*! call-bind/callBound */ "./node_modules/es-abstract/node_modules/call-bind/callBound.js");
var isLeadingSurrogate = __webpack_require__(/*! ../helpers/isLeadingSurrogate */ "./node_modules/es-abstract/helpers/isLeadingSurrogate.js");
var isTrailingSurrogate = __webpack_require__(/*! ../helpers/isTrailingSurrogate */ "./node_modules/es-abstract/helpers/isTrailingSurrogate.js");

var Type = __webpack_require__(/*! ./Type */ "./node_modules/es-abstract/2023/Type.js");
var UTF16SurrogatePairToCodePoint = __webpack_require__(/*! ./UTF16SurrogatePairToCodePoint */ "./node_modules/es-abstract/2023/UTF16SurrogatePairToCodePoint.js");

var $charAt = callBound('String.prototype.charAt');
var $charCodeAt = callBound('String.prototype.charCodeAt');

// https://262.ecma-international.org/12.0/#sec-codepointat

module.exports = function CodePointAt(string, position) {
	if (Type(string) !== 'String') {
		throw new $TypeError('Assertion failed: `string` must be a String');
	}
	var size = string.length;
	if (position < 0 || position >= size) {
		throw new $TypeError('Assertion failed: `position` must be >= 0, and < the length of `string`');
	}
	var first = $charCodeAt(string, position);
	var cp = $charAt(string, position);
	var firstIsLeading = isLeadingSurrogate(first);
	var firstIsTrailing = isTrailingSurrogate(first);
	if (!firstIsLeading && !firstIsTrailing) {
		return {
			'[[CodePoint]]': cp,
			'[[CodeUnitCount]]': 1,
			'[[IsUnpairedSurrogate]]': false
		};
	}
	if (firstIsTrailing || (position + 1 === size)) {
		return {
			'[[CodePoint]]': cp,
			'[[CodeUnitCount]]': 1,
			'[[IsUnpairedSurrogate]]': true
		};
	}
	var second = $charCodeAt(string, position + 1);
	if (!isTrailingSurrogate(second)) {
		return {
			'[[CodePoint]]': cp,
			'[[CodeUnitCount]]': 1,
			'[[IsUnpairedSurrogate]]': true
		};
	}

	return {
		'[[CodePoint]]': UTF16SurrogatePairToCodePoint(first, second),
		'[[CodeUnitCount]]': 2,
		'[[IsUnpairedSurrogate]]': false
	};
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/CreateIterResultObject.js":
/*!*****************************************************************!*\
  !*** ./node_modules/es-abstract/2023/CreateIterResultObject.js ***!
  \*****************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $TypeError = GetIntrinsic('%TypeError%');

var Type = __webpack_require__(/*! ./Type */ "./node_modules/es-abstract/2023/Type.js");

// https://262.ecma-international.org/6.0/#sec-createiterresultobject

module.exports = function CreateIterResultObject(value, done) {
	if (Type(done) !== 'Boolean') {
		throw new $TypeError('Assertion failed: Type(done) is not Boolean');
	}
	return {
		value: value,
		done: done
	};
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/CreateMethodProperty.js":
/*!***************************************************************!*\
  !*** ./node_modules/es-abstract/2023/CreateMethodProperty.js ***!
  \***************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $TypeError = GetIntrinsic('%TypeError%');

var DefineOwnProperty = __webpack_require__(/*! ../helpers/DefineOwnProperty */ "./node_modules/es-abstract/helpers/DefineOwnProperty.js");

var FromPropertyDescriptor = __webpack_require__(/*! ./FromPropertyDescriptor */ "./node_modules/es-abstract/2023/FromPropertyDescriptor.js");
var IsDataDescriptor = __webpack_require__(/*! ./IsDataDescriptor */ "./node_modules/es-abstract/2023/IsDataDescriptor.js");
var IsPropertyKey = __webpack_require__(/*! ./IsPropertyKey */ "./node_modules/es-abstract/2023/IsPropertyKey.js");
var SameValue = __webpack_require__(/*! ./SameValue */ "./node_modules/es-abstract/2023/SameValue.js");
var Type = __webpack_require__(/*! ./Type */ "./node_modules/es-abstract/2023/Type.js");

// https://262.ecma-international.org/6.0/#sec-createmethodproperty

module.exports = function CreateMethodProperty(O, P, V) {
	if (Type(O) !== 'Object') {
		throw new $TypeError('Assertion failed: Type(O) is not Object');
	}

	if (!IsPropertyKey(P)) {
		throw new $TypeError('Assertion failed: IsPropertyKey(P) is not true');
	}

	var newDesc = {
		'[[Configurable]]': true,
		'[[Enumerable]]': false,
		'[[Value]]': V,
		'[[Writable]]': true
	};
	return DefineOwnProperty(
		IsDataDescriptor,
		SameValue,
		FromPropertyDescriptor,
		O,
		P,
		newDesc
	);
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/CreateRegExpStringIterator.js":
/*!*********************************************************************!*\
  !*** ./node_modules/es-abstract/2023/CreateRegExpStringIterator.js ***!
  \*********************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");
var hasSymbols = __webpack_require__(/*! has-symbols */ "./node_modules/has-symbols/index.js")();

var $TypeError = GetIntrinsic('%TypeError%');
var IteratorPrototype = GetIntrinsic('%IteratorPrototype%', true);

var AdvanceStringIndex = __webpack_require__(/*! ./AdvanceStringIndex */ "./node_modules/es-abstract/2023/AdvanceStringIndex.js");
var CreateIterResultObject = __webpack_require__(/*! ./CreateIterResultObject */ "./node_modules/es-abstract/2023/CreateIterResultObject.js");
var CreateMethodProperty = __webpack_require__(/*! ./CreateMethodProperty */ "./node_modules/es-abstract/2023/CreateMethodProperty.js");
var Get = __webpack_require__(/*! ./Get */ "./node_modules/es-abstract/2023/Get.js");
var OrdinaryObjectCreate = __webpack_require__(/*! ./OrdinaryObjectCreate */ "./node_modules/es-abstract/2023/OrdinaryObjectCreate.js");
var RegExpExec = __webpack_require__(/*! ./RegExpExec */ "./node_modules/es-abstract/2023/RegExpExec.js");
var Set = __webpack_require__(/*! ./Set */ "./node_modules/es-abstract/2023/Set.js");
var ToLength = __webpack_require__(/*! ./ToLength */ "./node_modules/es-abstract/2023/ToLength.js");
var ToString = __webpack_require__(/*! ./ToString */ "./node_modules/es-abstract/2023/ToString.js");
var Type = __webpack_require__(/*! ./Type */ "./node_modules/es-abstract/2023/Type.js");

var SLOT = __webpack_require__(/*! internal-slot */ "./node_modules/internal-slot/index.js");
var setToStringTag = __webpack_require__(/*! es-set-tostringtag */ "./node_modules/es-set-tostringtag/index.js");

var RegExpStringIterator = function RegExpStringIterator(R, S, global, fullUnicode) {
	if (Type(S) !== 'String') {
		throw new $TypeError('`S` must be a string');
	}
	if (Type(global) !== 'Boolean') {
		throw new $TypeError('`global` must be a boolean');
	}
	if (Type(fullUnicode) !== 'Boolean') {
		throw new $TypeError('`fullUnicode` must be a boolean');
	}
	SLOT.set(this, '[[IteratingRegExp]]', R);
	SLOT.set(this, '[[IteratedString]]', S);
	SLOT.set(this, '[[Global]]', global);
	SLOT.set(this, '[[Unicode]]', fullUnicode);
	SLOT.set(this, '[[Done]]', false);
};

if (IteratorPrototype) {
	RegExpStringIterator.prototype = OrdinaryObjectCreate(IteratorPrototype);
}

var RegExpStringIteratorNext = function next() {
	var O = this; // eslint-disable-line no-invalid-this
	if (Type(O) !== 'Object') {
		throw new $TypeError('receiver must be an object');
	}
	if (
		!(O instanceof RegExpStringIterator)
		|| !SLOT.has(O, '[[IteratingRegExp]]')
		|| !SLOT.has(O, '[[IteratedString]]')
		|| !SLOT.has(O, '[[Global]]')
		|| !SLOT.has(O, '[[Unicode]]')
		|| !SLOT.has(O, '[[Done]]')
	) {
		throw new $TypeError('"this" value must be a RegExpStringIterator instance');
	}
	if (SLOT.get(O, '[[Done]]')) {
		return CreateIterResultObject(undefined, true);
	}
	var R = SLOT.get(O, '[[IteratingRegExp]]');
	var S = SLOT.get(O, '[[IteratedString]]');
	var global = SLOT.get(O, '[[Global]]');
	var fullUnicode = SLOT.get(O, '[[Unicode]]');
	var match = RegExpExec(R, S);
	if (match === null) {
		SLOT.set(O, '[[Done]]', true);
		return CreateIterResultObject(undefined, true);
	}
	if (global) {
		var matchStr = ToString(Get(match, '0'));
		if (matchStr === '') {
			var thisIndex = ToLength(Get(R, 'lastIndex'));
			var nextIndex = AdvanceStringIndex(S, thisIndex, fullUnicode);
			Set(R, 'lastIndex', nextIndex, true);
		}
		return CreateIterResultObject(match, false);
	}
	SLOT.set(O, '[[Done]]', true);
	return CreateIterResultObject(match, false);
};
CreateMethodProperty(RegExpStringIterator.prototype, 'next', RegExpStringIteratorNext);

if (hasSymbols) {
	setToStringTag(RegExpStringIterator.prototype, 'RegExp String Iterator');

	if (Symbol.iterator && typeof RegExpStringIterator.prototype[Symbol.iterator] !== 'function') {
		var iteratorFn = function SymbolIterator() {
			return this;
		};
		CreateMethodProperty(RegExpStringIterator.prototype, Symbol.iterator, iteratorFn);
	}
}

// https://262.ecma-international.org/11.0/#sec-createregexpstringiterator
module.exports = function CreateRegExpStringIterator(R, S, global, fullUnicode) {
	// assert R.global === global && R.unicode === fullUnicode?
	return new RegExpStringIterator(R, S, global, fullUnicode);
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/DefinePropertyOrThrow.js":
/*!****************************************************************!*\
  !*** ./node_modules/es-abstract/2023/DefinePropertyOrThrow.js ***!
  \****************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $TypeError = GetIntrinsic('%TypeError%');

var isPropertyDescriptor = __webpack_require__(/*! ../helpers/isPropertyDescriptor */ "./node_modules/es-abstract/helpers/isPropertyDescriptor.js");
var DefineOwnProperty = __webpack_require__(/*! ../helpers/DefineOwnProperty */ "./node_modules/es-abstract/helpers/DefineOwnProperty.js");

var FromPropertyDescriptor = __webpack_require__(/*! ./FromPropertyDescriptor */ "./node_modules/es-abstract/2023/FromPropertyDescriptor.js");
var IsAccessorDescriptor = __webpack_require__(/*! ./IsAccessorDescriptor */ "./node_modules/es-abstract/2023/IsAccessorDescriptor.js");
var IsDataDescriptor = __webpack_require__(/*! ./IsDataDescriptor */ "./node_modules/es-abstract/2023/IsDataDescriptor.js");
var IsPropertyKey = __webpack_require__(/*! ./IsPropertyKey */ "./node_modules/es-abstract/2023/IsPropertyKey.js");
var SameValue = __webpack_require__(/*! ./SameValue */ "./node_modules/es-abstract/2023/SameValue.js");
var ToPropertyDescriptor = __webpack_require__(/*! ./ToPropertyDescriptor */ "./node_modules/es-abstract/2023/ToPropertyDescriptor.js");
var Type = __webpack_require__(/*! ./Type */ "./node_modules/es-abstract/2023/Type.js");

// https://262.ecma-international.org/6.0/#sec-definepropertyorthrow

module.exports = function DefinePropertyOrThrow(O, P, desc) {
	if (Type(O) !== 'Object') {
		throw new $TypeError('Assertion failed: Type(O) is not Object');
	}

	if (!IsPropertyKey(P)) {
		throw new $TypeError('Assertion failed: IsPropertyKey(P) is not true');
	}

	var Desc = isPropertyDescriptor({
		Type: Type,
		IsDataDescriptor: IsDataDescriptor,
		IsAccessorDescriptor: IsAccessorDescriptor
	}, desc) ? desc : ToPropertyDescriptor(desc);
	if (!isPropertyDescriptor({
		Type: Type,
		IsDataDescriptor: IsDataDescriptor,
		IsAccessorDescriptor: IsAccessorDescriptor
	}, Desc)) {
		throw new $TypeError('Assertion failed: Desc is not a valid Property Descriptor');
	}

	return DefineOwnProperty(
		IsDataDescriptor,
		SameValue,
		FromPropertyDescriptor,
		O,
		P,
		Desc
	);
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/FromPropertyDescriptor.js":
/*!*****************************************************************!*\
  !*** ./node_modules/es-abstract/2023/FromPropertyDescriptor.js ***!
  \*****************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var assertRecord = __webpack_require__(/*! ../helpers/assertRecord */ "./node_modules/es-abstract/helpers/assertRecord.js");
var fromPropertyDescriptor = __webpack_require__(/*! ../helpers/fromPropertyDescriptor */ "./node_modules/es-abstract/helpers/fromPropertyDescriptor.js");

var Type = __webpack_require__(/*! ./Type */ "./node_modules/es-abstract/2023/Type.js");

// https://262.ecma-international.org/6.0/#sec-frompropertydescriptor

module.exports = function FromPropertyDescriptor(Desc) {
	if (typeof Desc !== 'undefined') {
		assertRecord(Type, 'Property Descriptor', 'Desc', Desc);
	}

	return fromPropertyDescriptor(Desc);
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/Get.js":
/*!**********************************************!*\
  !*** ./node_modules/es-abstract/2023/Get.js ***!
  \**********************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $TypeError = GetIntrinsic('%TypeError%');

var inspect = __webpack_require__(/*! object-inspect */ "./node_modules/object-inspect/index.js");

var IsPropertyKey = __webpack_require__(/*! ./IsPropertyKey */ "./node_modules/es-abstract/2023/IsPropertyKey.js");
var Type = __webpack_require__(/*! ./Type */ "./node_modules/es-abstract/2023/Type.js");

// https://262.ecma-international.org/6.0/#sec-get-o-p

module.exports = function Get(O, P) {
	// 7.3.1.1
	if (Type(O) !== 'Object') {
		throw new $TypeError('Assertion failed: Type(O) is not Object');
	}
	// 7.3.1.2
	if (!IsPropertyKey(P)) {
		throw new $TypeError('Assertion failed: IsPropertyKey(P) is not true, got ' + inspect(P));
	}
	// 7.3.1.3
	return O[P];
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/GetMethod.js":
/*!****************************************************!*\
  !*** ./node_modules/es-abstract/2023/GetMethod.js ***!
  \****************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $TypeError = GetIntrinsic('%TypeError%');

var GetV = __webpack_require__(/*! ./GetV */ "./node_modules/es-abstract/2023/GetV.js");
var IsCallable = __webpack_require__(/*! ./IsCallable */ "./node_modules/es-abstract/2023/IsCallable.js");
var IsPropertyKey = __webpack_require__(/*! ./IsPropertyKey */ "./node_modules/es-abstract/2023/IsPropertyKey.js");

var inspect = __webpack_require__(/*! object-inspect */ "./node_modules/object-inspect/index.js");

// https://262.ecma-international.org/6.0/#sec-getmethod

module.exports = function GetMethod(O, P) {
	// 7.3.9.1
	if (!IsPropertyKey(P)) {
		throw new $TypeError('Assertion failed: IsPropertyKey(P) is not true');
	}

	// 7.3.9.2
	var func = GetV(O, P);

	// 7.3.9.4
	if (func == null) {
		return void 0;
	}

	// 7.3.9.5
	if (!IsCallable(func)) {
		throw new $TypeError(inspect(P) + ' is not a function: ' + inspect(func));
	}

	// 7.3.9.6
	return func;
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/GetV.js":
/*!***********************************************!*\
  !*** ./node_modules/es-abstract/2023/GetV.js ***!
  \***********************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $TypeError = GetIntrinsic('%TypeError%');

var inspect = __webpack_require__(/*! object-inspect */ "./node_modules/object-inspect/index.js");

var IsPropertyKey = __webpack_require__(/*! ./IsPropertyKey */ "./node_modules/es-abstract/2023/IsPropertyKey.js");
// var ToObject = require('./ToObject');

// https://262.ecma-international.org/6.0/#sec-getv

module.exports = function GetV(V, P) {
	// 7.3.2.1
	if (!IsPropertyKey(P)) {
		throw new $TypeError('Assertion failed: IsPropertyKey(P) is not true, got ' + inspect(P));
	}

	// 7.3.2.2-3
	// var O = ToObject(V);

	// 7.3.2.4
	return V[P];
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/IsAccessorDescriptor.js":
/*!***************************************************************!*\
  !*** ./node_modules/es-abstract/2023/IsAccessorDescriptor.js ***!
  \***************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var hasOwn = __webpack_require__(/*! hasown */ "./node_modules/hasown/index.js");

var Type = __webpack_require__(/*! ./Type */ "./node_modules/es-abstract/2023/Type.js");

var assertRecord = __webpack_require__(/*! ../helpers/assertRecord */ "./node_modules/es-abstract/helpers/assertRecord.js");

// https://262.ecma-international.org/5.1/#sec-8.10.1

module.exports = function IsAccessorDescriptor(Desc) {
	if (typeof Desc === 'undefined') {
		return false;
	}

	assertRecord(Type, 'Property Descriptor', 'Desc', Desc);

	if (!hasOwn(Desc, '[[Get]]') && !hasOwn(Desc, '[[Set]]')) {
		return false;
	}

	return true;
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/IsArray.js":
/*!**************************************************!*\
  !*** ./node_modules/es-abstract/2023/IsArray.js ***!
  \**************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


// https://262.ecma-international.org/6.0/#sec-isarray
module.exports = __webpack_require__(/*! ../helpers/IsArray */ "./node_modules/es-abstract/helpers/IsArray.js");


/***/ }),

/***/ "./node_modules/es-abstract/2023/IsCallable.js":
/*!*****************************************************!*\
  !*** ./node_modules/es-abstract/2023/IsCallable.js ***!
  \*****************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


// http://262.ecma-international.org/5.1/#sec-9.11

module.exports = __webpack_require__(/*! is-callable */ "./node_modules/is-callable/index.js");


/***/ }),

/***/ "./node_modules/es-abstract/2023/IsConstructor.js":
/*!********************************************************!*\
  !*** ./node_modules/es-abstract/2023/IsConstructor.js ***!
  \********************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! ../GetIntrinsic.js */ "./node_modules/es-abstract/GetIntrinsic.js");

var $construct = GetIntrinsic('%Reflect.construct%', true);

var DefinePropertyOrThrow = __webpack_require__(/*! ./DefinePropertyOrThrow */ "./node_modules/es-abstract/2023/DefinePropertyOrThrow.js");
try {
	DefinePropertyOrThrow({}, '', { '[[Get]]': function () {} });
} catch (e) {
	// Accessor properties aren't supported
	DefinePropertyOrThrow = null;
}

// https://262.ecma-international.org/6.0/#sec-isconstructor

if (DefinePropertyOrThrow && $construct) {
	var isConstructorMarker = {};
	var badArrayLike = {};
	DefinePropertyOrThrow(badArrayLike, 'length', {
		'[[Get]]': function () {
			throw isConstructorMarker;
		},
		'[[Enumerable]]': true
	});

	module.exports = function IsConstructor(argument) {
		try {
			// `Reflect.construct` invokes `IsConstructor(target)` before `Get(args, 'length')`:
			$construct(argument, badArrayLike);
		} catch (err) {
			return err === isConstructorMarker;
		}
	};
} else {
	module.exports = function IsConstructor(argument) {
		// unfortunately there's no way to truly check this without try/catch `new argument` in old environments
		return typeof argument === 'function' && !!argument.prototype;
	};
}


/***/ }),

/***/ "./node_modules/es-abstract/2023/IsDataDescriptor.js":
/*!***********************************************************!*\
  !*** ./node_modules/es-abstract/2023/IsDataDescriptor.js ***!
  \***********************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var hasOwn = __webpack_require__(/*! hasown */ "./node_modules/hasown/index.js");

var Type = __webpack_require__(/*! ./Type */ "./node_modules/es-abstract/2023/Type.js");

var assertRecord = __webpack_require__(/*! ../helpers/assertRecord */ "./node_modules/es-abstract/helpers/assertRecord.js");

// https://262.ecma-international.org/5.1/#sec-8.10.2

module.exports = function IsDataDescriptor(Desc) {
	if (typeof Desc === 'undefined') {
		return false;
	}

	assertRecord(Type, 'Property Descriptor', 'Desc', Desc);

	if (!hasOwn(Desc, '[[Value]]') && !hasOwn(Desc, '[[Writable]]')) {
		return false;
	}

	return true;
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/IsPropertyKey.js":
/*!********************************************************!*\
  !*** ./node_modules/es-abstract/2023/IsPropertyKey.js ***!
  \********************************************************/
/***/ ((module) => {

"use strict";


// https://262.ecma-international.org/6.0/#sec-ispropertykey

module.exports = function IsPropertyKey(argument) {
	return typeof argument === 'string' || typeof argument === 'symbol';
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/IsRegExp.js":
/*!***************************************************!*\
  !*** ./node_modules/es-abstract/2023/IsRegExp.js ***!
  \***************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $match = GetIntrinsic('%Symbol.match%', true);

var hasRegExpMatcher = __webpack_require__(/*! is-regex */ "./node_modules/is-regex/index.js");

var ToBoolean = __webpack_require__(/*! ./ToBoolean */ "./node_modules/es-abstract/2023/ToBoolean.js");

// https://262.ecma-international.org/6.0/#sec-isregexp

module.exports = function IsRegExp(argument) {
	if (!argument || typeof argument !== 'object') {
		return false;
	}
	if ($match) {
		var isRegExp = argument[$match];
		if (typeof isRegExp !== 'undefined') {
			return ToBoolean(isRegExp);
		}
	}
	return hasRegExpMatcher(argument);
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/OrdinaryObjectCreate.js":
/*!***************************************************************!*\
  !*** ./node_modules/es-abstract/2023/OrdinaryObjectCreate.js ***!
  \***************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $ObjectCreate = GetIntrinsic('%Object.create%', true);
var $TypeError = GetIntrinsic('%TypeError%');
var $SyntaxError = GetIntrinsic('%SyntaxError%');

var IsArray = __webpack_require__(/*! ./IsArray */ "./node_modules/es-abstract/2023/IsArray.js");
var Type = __webpack_require__(/*! ./Type */ "./node_modules/es-abstract/2023/Type.js");

var forEach = __webpack_require__(/*! ../helpers/forEach */ "./node_modules/es-abstract/helpers/forEach.js");

var SLOT = __webpack_require__(/*! internal-slot */ "./node_modules/internal-slot/index.js");

var hasProto = __webpack_require__(/*! has-proto */ "./node_modules/has-proto/index.js")();

// https://262.ecma-international.org/11.0/#sec-objectcreate

module.exports = function OrdinaryObjectCreate(proto) {
	if (proto !== null && Type(proto) !== 'Object') {
		throw new $TypeError('Assertion failed: `proto` must be null or an object');
	}
	var additionalInternalSlotsList = arguments.length < 2 ? [] : arguments[1];
	if (!IsArray(additionalInternalSlotsList)) {
		throw new $TypeError('Assertion failed: `additionalInternalSlotsList` must be an Array');
	}

	// var internalSlotsList = ['[[Prototype]]', '[[Extensible]]']; // step 1
	// internalSlotsList.push(...additionalInternalSlotsList); // step 2
	// var O = MakeBasicObject(internalSlotsList); // step 3
	// setProto(O, proto); // step 4
	// return O; // step 5

	var O;
	if ($ObjectCreate) {
		O = $ObjectCreate(proto);
	} else if (hasProto) {
		O = { __proto__: proto };
	} else {
		if (proto === null) {
			throw new $SyntaxError('native Object.create support is required to create null objects');
		}
		var T = function T() {};
		T.prototype = proto;
		O = new T();
	}

	if (additionalInternalSlotsList.length > 0) {
		forEach(additionalInternalSlotsList, function (slot) {
			SLOT.set(O, slot, void undefined);
		});
	}

	return O;
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/RegExpExec.js":
/*!*****************************************************!*\
  !*** ./node_modules/es-abstract/2023/RegExpExec.js ***!
  \*****************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $TypeError = GetIntrinsic('%TypeError%');

var regexExec = __webpack_require__(/*! call-bind/callBound */ "./node_modules/es-abstract/node_modules/call-bind/callBound.js")('RegExp.prototype.exec');

var Call = __webpack_require__(/*! ./Call */ "./node_modules/es-abstract/2023/Call.js");
var Get = __webpack_require__(/*! ./Get */ "./node_modules/es-abstract/2023/Get.js");
var IsCallable = __webpack_require__(/*! ./IsCallable */ "./node_modules/es-abstract/2023/IsCallable.js");
var Type = __webpack_require__(/*! ./Type */ "./node_modules/es-abstract/2023/Type.js");

// https://262.ecma-international.org/6.0/#sec-regexpexec

module.exports = function RegExpExec(R, S) {
	if (Type(R) !== 'Object') {
		throw new $TypeError('Assertion failed: `R` must be an Object');
	}
	if (Type(S) !== 'String') {
		throw new $TypeError('Assertion failed: `S` must be a String');
	}
	var exec = Get(R, 'exec');
	if (IsCallable(exec)) {
		var result = Call(exec, R, [S]);
		if (result === null || Type(result) === 'Object') {
			return result;
		}
		throw new $TypeError('"exec" method must return `null` or an Object');
	}
	return regexExec(R, S);
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/RequireObjectCoercible.js":
/*!*****************************************************************!*\
  !*** ./node_modules/es-abstract/2023/RequireObjectCoercible.js ***!
  \*****************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


module.exports = __webpack_require__(/*! ../5/CheckObjectCoercible */ "./node_modules/es-abstract/5/CheckObjectCoercible.js");


/***/ }),

/***/ "./node_modules/es-abstract/2023/SameValue.js":
/*!****************************************************!*\
  !*** ./node_modules/es-abstract/2023/SameValue.js ***!
  \****************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var $isNaN = __webpack_require__(/*! ../helpers/isNaN */ "./node_modules/es-abstract/helpers/isNaN.js");

// http://262.ecma-international.org/5.1/#sec-9.12

module.exports = function SameValue(x, y) {
	if (x === y) { // 0 === -0, but they are not identical.
		if (x === 0) { return 1 / x === 1 / y; }
		return true;
	}
	return $isNaN(x) && $isNaN(y);
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/Set.js":
/*!**********************************************!*\
  !*** ./node_modules/es-abstract/2023/Set.js ***!
  \**********************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $TypeError = GetIntrinsic('%TypeError%');

var IsPropertyKey = __webpack_require__(/*! ./IsPropertyKey */ "./node_modules/es-abstract/2023/IsPropertyKey.js");
var SameValue = __webpack_require__(/*! ./SameValue */ "./node_modules/es-abstract/2023/SameValue.js");
var Type = __webpack_require__(/*! ./Type */ "./node_modules/es-abstract/2023/Type.js");

// IE 9 does not throw in strict mode when writability/configurability/extensibility is violated
var noThrowOnStrictViolation = (function () {
	try {
		delete [].length;
		return true;
	} catch (e) {
		return false;
	}
}());

// https://262.ecma-international.org/6.0/#sec-set-o-p-v-throw

module.exports = function Set(O, P, V, Throw) {
	if (Type(O) !== 'Object') {
		throw new $TypeError('Assertion failed: `O` must be an Object');
	}
	if (!IsPropertyKey(P)) {
		throw new $TypeError('Assertion failed: `P` must be a Property Key');
	}
	if (Type(Throw) !== 'Boolean') {
		throw new $TypeError('Assertion failed: `Throw` must be a Boolean');
	}
	if (Throw) {
		O[P] = V; // eslint-disable-line no-param-reassign
		if (noThrowOnStrictViolation && !SameValue(O[P], V)) {
			throw new $TypeError('Attempted to assign to readonly property.');
		}
		return true;
	}
	try {
		O[P] = V; // eslint-disable-line no-param-reassign
		return noThrowOnStrictViolation ? SameValue(O[P], V) : true;
	} catch (e) {
		return false;
	}

};


/***/ }),

/***/ "./node_modules/es-abstract/2023/SpeciesConstructor.js":
/*!*************************************************************!*\
  !*** ./node_modules/es-abstract/2023/SpeciesConstructor.js ***!
  \*************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $species = GetIntrinsic('%Symbol.species%', true);
var $TypeError = GetIntrinsic('%TypeError%');

var IsConstructor = __webpack_require__(/*! ./IsConstructor */ "./node_modules/es-abstract/2023/IsConstructor.js");
var Type = __webpack_require__(/*! ./Type */ "./node_modules/es-abstract/2023/Type.js");

// https://262.ecma-international.org/6.0/#sec-speciesconstructor

module.exports = function SpeciesConstructor(O, defaultConstructor) {
	if (Type(O) !== 'Object') {
		throw new $TypeError('Assertion failed: Type(O) is not Object');
	}
	var C = O.constructor;
	if (typeof C === 'undefined') {
		return defaultConstructor;
	}
	if (Type(C) !== 'Object') {
		throw new $TypeError('O.constructor is not an Object');
	}
	var S = $species ? C[$species] : void 0;
	if (S == null) {
		return defaultConstructor;
	}
	if (IsConstructor(S)) {
		return S;
	}
	throw new $TypeError('no constructor found');
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/StringToNumber.js":
/*!*********************************************************!*\
  !*** ./node_modules/es-abstract/2023/StringToNumber.js ***!
  \*********************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $Number = GetIntrinsic('%Number%');
var $RegExp = GetIntrinsic('%RegExp%');
var $TypeError = GetIntrinsic('%TypeError%');
var $parseInteger = GetIntrinsic('%parseInt%');

var callBound = __webpack_require__(/*! call-bind/callBound */ "./node_modules/es-abstract/node_modules/call-bind/callBound.js");
var regexTester = __webpack_require__(/*! safe-regex-test */ "./node_modules/safe-regex-test/index.js");

var $strSlice = callBound('String.prototype.slice');
var isBinary = regexTester(/^0b[01]+$/i);
var isOctal = regexTester(/^0o[0-7]+$/i);
var isInvalidHexLiteral = regexTester(/^[-+]0x[0-9a-f]+$/i);
var nonWS = ['\u0085', '\u200b', '\ufffe'].join('');
var nonWSregex = new $RegExp('[' + nonWS + ']', 'g');
var hasNonWS = regexTester(nonWSregex);

var $trim = __webpack_require__(/*! string.prototype.trim */ "./node_modules/string.prototype.trim/index.js");

var Type = __webpack_require__(/*! ./Type */ "./node_modules/es-abstract/2023/Type.js");

// https://262.ecma-international.org/13.0/#sec-stringtonumber

module.exports = function StringToNumber(argument) {
	if (Type(argument) !== 'String') {
		throw new $TypeError('Assertion failed: `argument` is not a String');
	}
	if (isBinary(argument)) {
		return $Number($parseInteger($strSlice(argument, 2), 2));
	}
	if (isOctal(argument)) {
		return $Number($parseInteger($strSlice(argument, 2), 8));
	}
	if (hasNonWS(argument) || isInvalidHexLiteral(argument)) {
		return NaN;
	}
	var trimmed = $trim(argument);
	if (trimmed !== argument) {
		return StringToNumber(trimmed);
	}
	return $Number(argument);
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/ToBoolean.js":
/*!****************************************************!*\
  !*** ./node_modules/es-abstract/2023/ToBoolean.js ***!
  \****************************************************/
/***/ ((module) => {

"use strict";


// http://262.ecma-international.org/5.1/#sec-9.2

module.exports = function ToBoolean(value) { return !!value; };


/***/ }),

/***/ "./node_modules/es-abstract/2023/ToIntegerOrInfinity.js":
/*!**************************************************************!*\
  !*** ./node_modules/es-abstract/2023/ToIntegerOrInfinity.js ***!
  \**************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var ToNumber = __webpack_require__(/*! ./ToNumber */ "./node_modules/es-abstract/2023/ToNumber.js");
var truncate = __webpack_require__(/*! ./truncate */ "./node_modules/es-abstract/2023/truncate.js");

var $isNaN = __webpack_require__(/*! ../helpers/isNaN */ "./node_modules/es-abstract/helpers/isNaN.js");
var $isFinite = __webpack_require__(/*! ../helpers/isFinite */ "./node_modules/es-abstract/helpers/isFinite.js");

// https://262.ecma-international.org/14.0/#sec-tointegerorinfinity

module.exports = function ToIntegerOrInfinity(value) {
	var number = ToNumber(value);
	if ($isNaN(number) || number === 0) { return 0; }
	if (!$isFinite(number)) { return number; }
	return truncate(number);
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/ToLength.js":
/*!***************************************************!*\
  !*** ./node_modules/es-abstract/2023/ToLength.js ***!
  \***************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var MAX_SAFE_INTEGER = __webpack_require__(/*! ../helpers/maxSafeInteger */ "./node_modules/es-abstract/helpers/maxSafeInteger.js");

var ToIntegerOrInfinity = __webpack_require__(/*! ./ToIntegerOrInfinity */ "./node_modules/es-abstract/2023/ToIntegerOrInfinity.js");

module.exports = function ToLength(argument) {
	var len = ToIntegerOrInfinity(argument);
	if (len <= 0) { return 0; } // includes converting -0 to +0
	if (len > MAX_SAFE_INTEGER) { return MAX_SAFE_INTEGER; }
	return len;
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/ToNumber.js":
/*!***************************************************!*\
  !*** ./node_modules/es-abstract/2023/ToNumber.js ***!
  \***************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $TypeError = GetIntrinsic('%TypeError%');
var $Number = GetIntrinsic('%Number%');
var isPrimitive = __webpack_require__(/*! ../helpers/isPrimitive */ "./node_modules/es-abstract/helpers/isPrimitive.js");

var ToPrimitive = __webpack_require__(/*! ./ToPrimitive */ "./node_modules/es-abstract/2023/ToPrimitive.js");
var StringToNumber = __webpack_require__(/*! ./StringToNumber */ "./node_modules/es-abstract/2023/StringToNumber.js");

// https://262.ecma-international.org/13.0/#sec-tonumber

module.exports = function ToNumber(argument) {
	var value = isPrimitive(argument) ? argument : ToPrimitive(argument, $Number);
	if (typeof value === 'symbol') {
		throw new $TypeError('Cannot convert a Symbol value to a number');
	}
	if (typeof value === 'bigint') {
		throw new $TypeError('Conversion from \'BigInt\' to \'number\' is not allowed.');
	}
	if (typeof value === 'string') {
		return StringToNumber(value);
	}
	return $Number(value);
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/ToPrimitive.js":
/*!******************************************************!*\
  !*** ./node_modules/es-abstract/2023/ToPrimitive.js ***!
  \******************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var toPrimitive = __webpack_require__(/*! es-to-primitive/es2015 */ "./node_modules/es-to-primitive/es2015.js");

// https://262.ecma-international.org/6.0/#sec-toprimitive

module.exports = function ToPrimitive(input) {
	if (arguments.length > 1) {
		return toPrimitive(input, arguments[1]);
	}
	return toPrimitive(input);
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/ToPropertyDescriptor.js":
/*!***************************************************************!*\
  !*** ./node_modules/es-abstract/2023/ToPropertyDescriptor.js ***!
  \***************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var hasOwn = __webpack_require__(/*! hasown */ "./node_modules/hasown/index.js");

var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $TypeError = GetIntrinsic('%TypeError%');

var Type = __webpack_require__(/*! ./Type */ "./node_modules/es-abstract/2023/Type.js");
var ToBoolean = __webpack_require__(/*! ./ToBoolean */ "./node_modules/es-abstract/2023/ToBoolean.js");
var IsCallable = __webpack_require__(/*! ./IsCallable */ "./node_modules/es-abstract/2023/IsCallable.js");

// https://262.ecma-international.org/5.1/#sec-8.10.5

module.exports = function ToPropertyDescriptor(Obj) {
	if (Type(Obj) !== 'Object') {
		throw new $TypeError('ToPropertyDescriptor requires an object');
	}

	var desc = {};
	if (hasOwn(Obj, 'enumerable')) {
		desc['[[Enumerable]]'] = ToBoolean(Obj.enumerable);
	}
	if (hasOwn(Obj, 'configurable')) {
		desc['[[Configurable]]'] = ToBoolean(Obj.configurable);
	}
	if (hasOwn(Obj, 'value')) {
		desc['[[Value]]'] = Obj.value;
	}
	if (hasOwn(Obj, 'writable')) {
		desc['[[Writable]]'] = ToBoolean(Obj.writable);
	}
	if (hasOwn(Obj, 'get')) {
		var getter = Obj.get;
		if (typeof getter !== 'undefined' && !IsCallable(getter)) {
			throw new $TypeError('getter must be a function');
		}
		desc['[[Get]]'] = getter;
	}
	if (hasOwn(Obj, 'set')) {
		var setter = Obj.set;
		if (typeof setter !== 'undefined' && !IsCallable(setter)) {
			throw new $TypeError('setter must be a function');
		}
		desc['[[Set]]'] = setter;
	}

	if ((hasOwn(desc, '[[Get]]') || hasOwn(desc, '[[Set]]')) && (hasOwn(desc, '[[Value]]') || hasOwn(desc, '[[Writable]]'))) {
		throw new $TypeError('Invalid property descriptor. Cannot both specify accessors and a value or writable attribute');
	}
	return desc;
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/ToString.js":
/*!***************************************************!*\
  !*** ./node_modules/es-abstract/2023/ToString.js ***!
  \***************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $String = GetIntrinsic('%String%');
var $TypeError = GetIntrinsic('%TypeError%');

// https://262.ecma-international.org/6.0/#sec-tostring

module.exports = function ToString(argument) {
	if (typeof argument === 'symbol') {
		throw new $TypeError('Cannot convert a Symbol value to a string');
	}
	return $String(argument);
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/Type.js":
/*!***********************************************!*\
  !*** ./node_modules/es-abstract/2023/Type.js ***!
  \***********************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var ES5Type = __webpack_require__(/*! ../5/Type */ "./node_modules/es-abstract/5/Type.js");

// https://262.ecma-international.org/11.0/#sec-ecmascript-data-types-and-values

module.exports = function Type(x) {
	if (typeof x === 'symbol') {
		return 'Symbol';
	}
	if (typeof x === 'bigint') {
		return 'BigInt';
	}
	return ES5Type(x);
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/UTF16SurrogatePairToCodePoint.js":
/*!************************************************************************!*\
  !*** ./node_modules/es-abstract/2023/UTF16SurrogatePairToCodePoint.js ***!
  \************************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $TypeError = GetIntrinsic('%TypeError%');
var $fromCharCode = GetIntrinsic('%String.fromCharCode%');

var isLeadingSurrogate = __webpack_require__(/*! ../helpers/isLeadingSurrogate */ "./node_modules/es-abstract/helpers/isLeadingSurrogate.js");
var isTrailingSurrogate = __webpack_require__(/*! ../helpers/isTrailingSurrogate */ "./node_modules/es-abstract/helpers/isTrailingSurrogate.js");

// https://tc39.es/ecma262/2020/#sec-utf16decodesurrogatepair

module.exports = function UTF16SurrogatePairToCodePoint(lead, trail) {
	if (!isLeadingSurrogate(lead) || !isTrailingSurrogate(trail)) {
		throw new $TypeError('Assertion failed: `lead` must be a leading surrogate char code, and `trail` must be a trailing surrogate char code');
	}
	// var cp = (lead - 0xD800) * 0x400 + (trail - 0xDC00) + 0x10000;
	return $fromCharCode(lead) + $fromCharCode(trail);
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/floor.js":
/*!************************************************!*\
  !*** ./node_modules/es-abstract/2023/floor.js ***!
  \************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var Type = __webpack_require__(/*! ./Type */ "./node_modules/es-abstract/2023/Type.js");

// var modulo = require('./modulo');
var $floor = Math.floor;

// http://262.ecma-international.org/11.0/#eqn-floor

module.exports = function floor(x) {
	// return x - modulo(x, 1);
	if (Type(x) === 'BigInt') {
		return x;
	}
	return $floor(x);
};


/***/ }),

/***/ "./node_modules/es-abstract/2023/truncate.js":
/*!***************************************************!*\
  !*** ./node_modules/es-abstract/2023/truncate.js ***!
  \***************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var floor = __webpack_require__(/*! ./floor */ "./node_modules/es-abstract/2023/floor.js");

var $TypeError = GetIntrinsic('%TypeError%');

// https://262.ecma-international.org/14.0/#eqn-truncate

module.exports = function truncate(x) {
	if (typeof x !== 'number' && typeof x !== 'bigint') {
		throw new $TypeError('argument must be a Number or a BigInt');
	}
	var result = x < 0 ? -floor(-x) : floor(x);
	return result === 0 ? 0 : result; // in the spec, these are math values, so we filter out -0 here
};


/***/ }),

/***/ "./node_modules/es-abstract/5/CheckObjectCoercible.js":
/*!************************************************************!*\
  !*** ./node_modules/es-abstract/5/CheckObjectCoercible.js ***!
  \************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $TypeError = GetIntrinsic('%TypeError%');

// http://262.ecma-international.org/5.1/#sec-9.10

module.exports = function CheckObjectCoercible(value, optMessage) {
	if (value == null) {
		throw new $TypeError(optMessage || ('Cannot call method on ' + value));
	}
	return value;
};


/***/ }),

/***/ "./node_modules/es-abstract/5/Type.js":
/*!********************************************!*\
  !*** ./node_modules/es-abstract/5/Type.js ***!
  \********************************************/
/***/ ((module) => {

"use strict";


// https://262.ecma-international.org/5.1/#sec-8

module.exports = function Type(x) {
	if (x === null) {
		return 'Null';
	}
	if (typeof x === 'undefined') {
		return 'Undefined';
	}
	if (typeof x === 'function' || typeof x === 'object') {
		return 'Object';
	}
	if (typeof x === 'number') {
		return 'Number';
	}
	if (typeof x === 'boolean') {
		return 'Boolean';
	}
	if (typeof x === 'string') {
		return 'String';
	}
};


/***/ }),

/***/ "./node_modules/es-abstract/GetIntrinsic.js":
/*!**************************************************!*\
  !*** ./node_modules/es-abstract/GetIntrinsic.js ***!
  \**************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


// TODO: remove, semver-major

module.exports = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");


/***/ }),

/***/ "./node_modules/es-abstract/helpers/DefineOwnProperty.js":
/*!***************************************************************!*\
  !*** ./node_modules/es-abstract/helpers/DefineOwnProperty.js ***!
  \***************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var hasPropertyDescriptors = __webpack_require__(/*! has-property-descriptors */ "./node_modules/has-property-descriptors/index.js");

var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $defineProperty = hasPropertyDescriptors() && GetIntrinsic('%Object.defineProperty%', true);

var hasArrayLengthDefineBug = hasPropertyDescriptors.hasArrayLengthDefineBug();

// eslint-disable-next-line global-require
var isArray = hasArrayLengthDefineBug && __webpack_require__(/*! ../helpers/IsArray */ "./node_modules/es-abstract/helpers/IsArray.js");

var callBound = __webpack_require__(/*! call-bind/callBound */ "./node_modules/es-abstract/node_modules/call-bind/callBound.js");

var $isEnumerable = callBound('Object.prototype.propertyIsEnumerable');

// eslint-disable-next-line max-params
module.exports = function DefineOwnProperty(IsDataDescriptor, SameValue, FromPropertyDescriptor, O, P, desc) {
	if (!$defineProperty) {
		if (!IsDataDescriptor(desc)) {
			// ES3 does not support getters/setters
			return false;
		}
		if (!desc['[[Configurable]]'] || !desc['[[Writable]]']) {
			return false;
		}

		// fallback for ES3
		if (P in O && $isEnumerable(O, P) !== !!desc['[[Enumerable]]']) {
			// a non-enumerable existing property
			return false;
		}

		// property does not exist at all, or exists but is enumerable
		var V = desc['[[Value]]'];
		// eslint-disable-next-line no-param-reassign
		O[P] = V; // will use [[Define]]
		return SameValue(O[P], V);
	}
	if (
		hasArrayLengthDefineBug
		&& P === 'length'
		&& '[[Value]]' in desc
		&& isArray(O)
		&& O.length !== desc['[[Value]]']
	) {
		// eslint-disable-next-line no-param-reassign
		O.length = desc['[[Value]]'];
		return O.length === desc['[[Value]]'];
	}

	$defineProperty(O, P, FromPropertyDescriptor(desc));
	return true;
};


/***/ }),

/***/ "./node_modules/es-abstract/helpers/IsArray.js":
/*!*****************************************************!*\
  !*** ./node_modules/es-abstract/helpers/IsArray.js ***!
  \*****************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $Array = GetIntrinsic('%Array%');

// eslint-disable-next-line global-require
var toStr = !$Array.isArray && __webpack_require__(/*! call-bind/callBound */ "./node_modules/es-abstract/node_modules/call-bind/callBound.js")('Object.prototype.toString');

module.exports = $Array.isArray || function IsArray(argument) {
	return toStr(argument) === '[object Array]';
};


/***/ }),

/***/ "./node_modules/es-abstract/helpers/assertRecord.js":
/*!**********************************************************!*\
  !*** ./node_modules/es-abstract/helpers/assertRecord.js ***!
  \**********************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $TypeError = GetIntrinsic('%TypeError%');
var $SyntaxError = GetIntrinsic('%SyntaxError%');

var hasOwn = __webpack_require__(/*! hasown */ "./node_modules/hasown/index.js");
var isInteger = __webpack_require__(/*! ./isInteger */ "./node_modules/es-abstract/helpers/isInteger.js");

var isMatchRecord = __webpack_require__(/*! ./isMatchRecord */ "./node_modules/es-abstract/helpers/isMatchRecord.js");

var predicates = {
	// https://262.ecma-international.org/6.0/#sec-property-descriptor-specification-type
	'Property Descriptor': function isPropertyDescriptor(Desc) {
		var allowed = {
			'[[Configurable]]': true,
			'[[Enumerable]]': true,
			'[[Get]]': true,
			'[[Set]]': true,
			'[[Value]]': true,
			'[[Writable]]': true
		};

		if (!Desc) {
			return false;
		}
		for (var key in Desc) { // eslint-disable-line
			if (hasOwn(Desc, key) && !allowed[key]) {
				return false;
			}
		}

		var isData = hasOwn(Desc, '[[Value]]');
		var IsAccessor = hasOwn(Desc, '[[Get]]') || hasOwn(Desc, '[[Set]]');
		if (isData && IsAccessor) {
			throw new $TypeError('Property Descriptors may not be both accessor and data descriptors');
		}
		return true;
	},
	// https://262.ecma-international.org/13.0/#sec-match-records
	'Match Record': isMatchRecord,
	'Iterator Record': function isIteratorRecord(value) {
		return hasOwn(value, '[[Iterator]]') && hasOwn(value, '[[NextMethod]]') && hasOwn(value, '[[Done]]');
	},
	'PromiseCapability Record': function isPromiseCapabilityRecord(value) {
		return !!value
			&& hasOwn(value, '[[Resolve]]')
			&& typeof value['[[Resolve]]'] === 'function'
			&& hasOwn(value, '[[Reject]]')
			&& typeof value['[[Reject]]'] === 'function'
			&& hasOwn(value, '[[Promise]]')
			&& value['[[Promise]]']
			&& typeof value['[[Promise]]'].then === 'function';
	},
	'AsyncGeneratorRequest Record': function isAsyncGeneratorRequestRecord(value) {
		return !!value
			&& hasOwn(value, '[[Completion]]') // TODO: confirm is a completion record
			&& hasOwn(value, '[[Capability]]')
			&& predicates['PromiseCapability Record'](value['[[Capability]]']);
	},
	'RegExp Record': function isRegExpRecord(value) {
		return value
			&& hasOwn(value, '[[IgnoreCase]]')
			&& typeof value['[[IgnoreCase]]'] === 'boolean'
			&& hasOwn(value, '[[Multiline]]')
			&& typeof value['[[Multiline]]'] === 'boolean'
			&& hasOwn(value, '[[DotAll]]')
			&& typeof value['[[DotAll]]'] === 'boolean'
			&& hasOwn(value, '[[Unicode]]')
			&& typeof value['[[Unicode]]'] === 'boolean'
			&& hasOwn(value, '[[CapturingGroupsCount]]')
			&& typeof value['[[CapturingGroupsCount]]'] === 'number'
			&& isInteger(value['[[CapturingGroupsCount]]'])
			&& value['[[CapturingGroupsCount]]'] >= 0;
	}
};

module.exports = function assertRecord(Type, recordType, argumentName, value) {
	var predicate = predicates[recordType];
	if (typeof predicate !== 'function') {
		throw new $SyntaxError('unknown record type: ' + recordType);
	}
	if (Type(value) !== 'Object' || !predicate(value)) {
		throw new $TypeError(argumentName + ' must be a ' + recordType);
	}
};


/***/ }),

/***/ "./node_modules/es-abstract/helpers/forEach.js":
/*!*****************************************************!*\
  !*** ./node_modules/es-abstract/helpers/forEach.js ***!
  \*****************************************************/
/***/ ((module) => {

"use strict";


module.exports = function forEach(array, callback) {
	for (var i = 0; i < array.length; i += 1) {
		callback(array[i], i, array); // eslint-disable-line callback-return
	}
};


/***/ }),

/***/ "./node_modules/es-abstract/helpers/fromPropertyDescriptor.js":
/*!********************************************************************!*\
  !*** ./node_modules/es-abstract/helpers/fromPropertyDescriptor.js ***!
  \********************************************************************/
/***/ ((module) => {

"use strict";


module.exports = function fromPropertyDescriptor(Desc) {
	if (typeof Desc === 'undefined') {
		return Desc;
	}
	var obj = {};
	if ('[[Value]]' in Desc) {
		obj.value = Desc['[[Value]]'];
	}
	if ('[[Writable]]' in Desc) {
		obj.writable = !!Desc['[[Writable]]'];
	}
	if ('[[Get]]' in Desc) {
		obj.get = Desc['[[Get]]'];
	}
	if ('[[Set]]' in Desc) {
		obj.set = Desc['[[Set]]'];
	}
	if ('[[Enumerable]]' in Desc) {
		obj.enumerable = !!Desc['[[Enumerable]]'];
	}
	if ('[[Configurable]]' in Desc) {
		obj.configurable = !!Desc['[[Configurable]]'];
	}
	return obj;
};


/***/ }),

/***/ "./node_modules/es-abstract/helpers/isFinite.js":
/*!******************************************************!*\
  !*** ./node_modules/es-abstract/helpers/isFinite.js ***!
  \******************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var $isNaN = __webpack_require__(/*! ./isNaN */ "./node_modules/es-abstract/helpers/isNaN.js");

module.exports = function (x) { return (typeof x === 'number' || typeof x === 'bigint') && !$isNaN(x) && x !== Infinity && x !== -Infinity; };


/***/ }),

/***/ "./node_modules/es-abstract/helpers/isInteger.js":
/*!*******************************************************!*\
  !*** ./node_modules/es-abstract/helpers/isInteger.js ***!
  \*******************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var $abs = GetIntrinsic('%Math.abs%');
var $floor = GetIntrinsic('%Math.floor%');

var $isNaN = __webpack_require__(/*! ./isNaN */ "./node_modules/es-abstract/helpers/isNaN.js");
var $isFinite = __webpack_require__(/*! ./isFinite */ "./node_modules/es-abstract/helpers/isFinite.js");

module.exports = function isInteger(argument) {
	if (typeof argument !== 'number' || $isNaN(argument) || !$isFinite(argument)) {
		return false;
	}
	var absValue = $abs(argument);
	return $floor(absValue) === absValue;
};



/***/ }),

/***/ "./node_modules/es-abstract/helpers/isLeadingSurrogate.js":
/*!****************************************************************!*\
  !*** ./node_modules/es-abstract/helpers/isLeadingSurrogate.js ***!
  \****************************************************************/
/***/ ((module) => {

"use strict";


module.exports = function isLeadingSurrogate(charCode) {
	return typeof charCode === 'number' && charCode >= 0xD800 && charCode <= 0xDBFF;
};


/***/ }),

/***/ "./node_modules/es-abstract/helpers/isMatchRecord.js":
/*!***********************************************************!*\
  !*** ./node_modules/es-abstract/helpers/isMatchRecord.js ***!
  \***********************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var hasOwn = __webpack_require__(/*! hasown */ "./node_modules/hasown/index.js");

// https://262.ecma-international.org/13.0/#sec-match-records

module.exports = function isMatchRecord(record) {
	return (
		hasOwn(record, '[[StartIndex]]')
        && hasOwn(record, '[[EndIndex]]')
        && record['[[StartIndex]]'] >= 0
        && record['[[EndIndex]]'] >= record['[[StartIndex]]']
        && String(parseInt(record['[[StartIndex]]'], 10)) === String(record['[[StartIndex]]'])
        && String(parseInt(record['[[EndIndex]]'], 10)) === String(record['[[EndIndex]]'])
	);
};


/***/ }),

/***/ "./node_modules/es-abstract/helpers/isNaN.js":
/*!***************************************************!*\
  !*** ./node_modules/es-abstract/helpers/isNaN.js ***!
  \***************************************************/
/***/ ((module) => {

"use strict";


module.exports = Number.isNaN || function isNaN(a) {
	return a !== a;
};


/***/ }),

/***/ "./node_modules/es-abstract/helpers/isPrimitive.js":
/*!*********************************************************!*\
  !*** ./node_modules/es-abstract/helpers/isPrimitive.js ***!
  \*********************************************************/
/***/ ((module) => {

"use strict";


module.exports = function isPrimitive(value) {
	return value === null || (typeof value !== 'function' && typeof value !== 'object');
};


/***/ }),

/***/ "./node_modules/es-abstract/helpers/isPropertyDescriptor.js":
/*!******************************************************************!*\
  !*** ./node_modules/es-abstract/helpers/isPropertyDescriptor.js ***!
  \******************************************************************/
/***/ ((module, __unused_webpack_exports, __webpack_require__) => {

"use strict";


var GetIntrinsic = __webpack_require__(/*! get-intrinsic */ "./node_modules/get-intrinsic/index.js");

var hasOwn = __webpack_require__(/*! hasown */ "./node_modules/hasown/index.js");
var $TypeError = GetIntrinsic('%TypeError%');

module.exports = function IsPropertyDescriptor(ES, Desc) {
	if (ES.Type(Desc) !== 'Object') {
		return false;
	}
	var allowed = {
		'[[Configurable]]': true,
		'[[Enumerable]]': true,
		'[[Get]]': true,
		'[[Set]]': true,
		'[[Value]]': true,
		'[[Writable]]': true
	};

	for (var key in Desc) { // eslint-disable-line no-restricted-syntax
		if (hasOwn(Desc, key) && !allowed[key]) {
			return false;
		}
	}

	if (ES.IsDataDescriptor(Desc) && ES.IsAccessorDescriptor(Desc)) {
		throw new $TypeError('Property Descriptors may not be both accessor and data descriptors');
	}
	return true;
};


/***/ }),

/***/ "./node_modules/es-abstract/helpers/isTrailingSurrogate.js":
/*!*****************************************************************!*\
  !*** ./node_modules/es-abstract/helpers/isTrailingSurrogate.js ***!
  \*****************************************************************/
/***/ ((module) => {

"use strict";


module.exports = function isTrailingSurrogate(charCode) {
	return typeof charCode === 'number' && charCode >= 0xDC00 && charCode <= 0xDFFF;
};


/***/ }),

/***/ "./node_modules/es-abstract/helpers/maxSafeInteger.js":
/*!************************************************************!*\
  !*** ./node_modules/es-abstract/helpers/maxSafeInteger.js ***!
  \************************************************************/
/***/ ((module) => {

"use strict";


module.exports = Number.MAX_SAFE_INTEGER || 9007199254740991; // Math.pow(2, 53) - 1;


/***/ }),

/***/ "./node_modules/css-selector-generator/esm/constants.js":
/*!**************************************************************!*\
  !*** ./node_modules/css-selector-generator/esm/constants.js ***!
  \**************************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   INVALID_CLASS_RE: () => (/* binding */ INVALID_CLASS_RE),
/* harmony export */   INVALID_ID_RE: () => (/* binding */ INVALID_ID_RE),
/* harmony export */   SELECTOR_PATTERN: () => (/* binding */ SELECTOR_PATTERN),
/* harmony export */   SELECTOR_SEPARATOR: () => (/* binding */ SELECTOR_SEPARATOR)
/* harmony export */ });
/* harmony import */ var _types_js__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./types.js */ "./node_modules/css-selector-generator/esm/types.js");

const SELECTOR_SEPARATOR = ", ";
// RegExp that will match invalid patterns that can be used in ID attribute.
const INVALID_ID_RE = new RegExp([
    "^$",
    "\\s", // contains whitespace
].join("|"));
// RegExp that will match invalid patterns that can be used in class attribute.
const INVALID_CLASS_RE = new RegExp([
    "^$", // empty or not set
].join("|"));
// Order in which a combined selector is constructed.
const SELECTOR_PATTERN = [
    _types_js__WEBPACK_IMPORTED_MODULE_0__.CSS_SELECTOR_TYPE.nthoftype,
    _types_js__WEBPACK_IMPORTED_MODULE_0__.CSS_SELECTOR_TYPE.tag,
    _types_js__WEBPACK_IMPORTED_MODULE_0__.CSS_SELECTOR_TYPE.id,
    _types_js__WEBPACK_IMPORTED_MODULE_0__.CSS_SELECTOR_TYPE.class,
    _types_js__WEBPACK_IMPORTED_MODULE_0__.CSS_SELECTOR_TYPE.attribute,
    _types_js__WEBPACK_IMPORTED_MODULE_0__.CSS_SELECTOR_TYPE.nthchild,
];
//# sourceMappingURL=constants.js.map

/***/ }),

/***/ "./node_modules/css-selector-generator/esm/index.js":
/*!**********************************************************!*\
  !*** ./node_modules/css-selector-generator/esm/index.js ***!
  \**********************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   "default": () => (__WEBPACK_DEFAULT_EXPORT__),
/* harmony export */   getCssSelector: () => (/* binding */ getCssSelector)
/* harmony export */ });
/* harmony import */ var _selector_fallback_js__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./selector-fallback.js */ "./node_modules/css-selector-generator/esm/selector-fallback.js");
/* harmony import */ var _utilities_options_js__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./utilities-options.js */ "./node_modules/css-selector-generator/esm/utilities-options.js");
/* harmony import */ var _utilities_selectors_js__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./utilities-selectors.js */ "./node_modules/css-selector-generator/esm/utilities-selectors.js");
/* harmony import */ var _utilities_dom_js__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ./utilities-dom.js */ "./node_modules/css-selector-generator/esm/utilities-dom.js");
/* harmony import */ var _constants_js__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! ./constants.js */ "./node_modules/css-selector-generator/esm/constants.js");





/**
 * Generates unique CSS selector for an element.
 */
function getCssSelector(needle, custom_options = {}) {
    const elements = (0,_utilities_selectors_js__WEBPACK_IMPORTED_MODULE_2__.sanitizeSelectorNeedle)(needle);
    const options = (0,_utilities_options_js__WEBPACK_IMPORTED_MODULE_1__.sanitizeOptions)(elements[0], custom_options);
    let partialSelector = "";
    let currentRoot = options.root;
    /**
     * Utility function to make subsequent calls shorter.
     */
    function updateIdentifiableParent() {
        return (0,_utilities_selectors_js__WEBPACK_IMPORTED_MODULE_2__.getClosestIdentifiableParent)(elements, currentRoot, partialSelector, options);
    }
    let closestIdentifiableParent = updateIdentifiableParent();
    while (closestIdentifiableParent) {
        const { foundElements, selector } = closestIdentifiableParent;
        if ((0,_utilities_dom_js__WEBPACK_IMPORTED_MODULE_3__.testSelector)(elements, selector, options.root)) {
            return selector;
        }
        currentRoot = foundElements[0];
        partialSelector = selector;
        closestIdentifiableParent = updateIdentifiableParent();
    }
    // if failed to find single selector matching all elements, try to find
    // selector for each standalone element and join them together
    if (elements.length > 1) {
        return elements
            .map((element) => getCssSelector(element, options))
            .join(_constants_js__WEBPACK_IMPORTED_MODULE_4__.SELECTOR_SEPARATOR);
    }
    return (0,_selector_fallback_js__WEBPACK_IMPORTED_MODULE_0__.getFallbackSelector)(elements);
}
/* harmony default export */ const __WEBPACK_DEFAULT_EXPORT__ = (getCssSelector);
//# sourceMappingURL=index.js.map

/***/ }),

/***/ "./node_modules/css-selector-generator/esm/selector-attribute.js":
/*!***********************************************************************!*\
  !*** ./node_modules/css-selector-generator/esm/selector-attribute.js ***!
  \***********************************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   attributeBlacklistMatch: () => (/* binding */ attributeBlacklistMatch),
/* harmony export */   attributeNodeToSelector: () => (/* binding */ attributeNodeToSelector),
/* harmony export */   attributeNodeToSimplifiedSelector: () => (/* binding */ attributeNodeToSimplifiedSelector),
/* harmony export */   getAttributeSelectors: () => (/* binding */ getAttributeSelectors),
/* harmony export */   getElementAttributeSelectors: () => (/* binding */ getElementAttributeSelectors),
/* harmony export */   isValidAttributeNode: () => (/* binding */ isValidAttributeNode)
/* harmony export */ });
/* harmony import */ var _utilities_selectors_js__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./utilities-selectors.js */ "./node_modules/css-selector-generator/esm/utilities-selectors.js");
/* harmony import */ var _utilities_data_js__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./utilities-data.js */ "./node_modules/css-selector-generator/esm/utilities-data.js");


// List of attributes to be ignored. These are handled by different selector types.
const attributeBlacklistMatch = (0,_utilities_data_js__WEBPACK_IMPORTED_MODULE_1__.createPatternMatcher)([
    "class",
    "id",
    // Angular attributes
    "ng-*",
]);
/**
 * Get simplified attribute selector for an element.
 */
function attributeNodeToSimplifiedSelector({ nodeName, }) {
    return `[${nodeName}]`;
}
/**
 * Get attribute selector for an element.
 */
function attributeNodeToSelector({ nodeName, nodeValue, }) {
    const selector = `[${nodeName}='${(0,_utilities_selectors_js__WEBPACK_IMPORTED_MODULE_0__.sanitizeSelectorItem)(nodeValue)}']`;
    return selector;
}
/**
 * Checks whether attribute should be used as a selector.
 */
function isValidAttributeNode({ nodeName }, element) {
    // form input value should not be used as a selector
    const tagName = element.tagName.toLowerCase();
    if (["input", "option"].includes(tagName) && nodeName === "value") {
        return false;
    }
    return !attributeBlacklistMatch(nodeName);
}
/**
 * Get attribute selectors for an element.
 */
function getElementAttributeSelectors(element) {
    const validAttributes = Array.from(element.attributes).filter((attributeNode) => isValidAttributeNode(attributeNode, element));
    return [
        ...validAttributes.map(attributeNodeToSimplifiedSelector),
        ...validAttributes.map(attributeNodeToSelector),
    ];
}
/**
 * Get attribute selectors matching all elements.
 */
function getAttributeSelectors(elements) {
    const elementSelectors = elements.map(getElementAttributeSelectors);
    return (0,_utilities_data_js__WEBPACK_IMPORTED_MODULE_1__.getIntersection)(elementSelectors);
}
//# sourceMappingURL=selector-attribute.js.map

/***/ }),

/***/ "./node_modules/css-selector-generator/esm/selector-class.js":
/*!*******************************************************************!*\
  !*** ./node_modules/css-selector-generator/esm/selector-class.js ***!
  \*******************************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   getClassSelectors: () => (/* binding */ getClassSelectors),
/* harmony export */   getElementClassSelectors: () => (/* binding */ getElementClassSelectors)
/* harmony export */ });
/* harmony import */ var _utilities_selectors_js__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./utilities-selectors.js */ "./node_modules/css-selector-generator/esm/utilities-selectors.js");
/* harmony import */ var _constants_js__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./constants.js */ "./node_modules/css-selector-generator/esm/constants.js");
/* harmony import */ var _utilities_data_js__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./utilities-data.js */ "./node_modules/css-selector-generator/esm/utilities-data.js");



/**
 * Get class selectors for an element.
 */
function getElementClassSelectors(element) {
    return (element.getAttribute("class") || "")
        .trim()
        .split(/\s+/)
        .filter((item) => !_constants_js__WEBPACK_IMPORTED_MODULE_1__.INVALID_CLASS_RE.test(item))
        .map((item) => `.${(0,_utilities_selectors_js__WEBPACK_IMPORTED_MODULE_0__.sanitizeSelectorItem)(item)}`);
}
/**
 * Get class selectors matching all elements.
 */
function getClassSelectors(elements) {
    const elementSelectors = elements.map(getElementClassSelectors);
    return (0,_utilities_data_js__WEBPACK_IMPORTED_MODULE_2__.getIntersection)(elementSelectors);
}
//# sourceMappingURL=selector-class.js.map

/***/ }),

/***/ "./node_modules/css-selector-generator/esm/selector-fallback.js":
/*!**********************************************************************!*\
  !*** ./node_modules/css-selector-generator/esm/selector-fallback.js ***!
  \**********************************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   getElementFallbackSelector: () => (/* binding */ getElementFallbackSelector),
/* harmony export */   getFallbackSelector: () => (/* binding */ getFallbackSelector)
/* harmony export */ });
/* harmony import */ var _utilities_dom_js__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./utilities-dom.js */ "./node_modules/css-selector-generator/esm/utilities-dom.js");
/* harmony import */ var _constants_js__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./constants.js */ "./node_modules/css-selector-generator/esm/constants.js");
/* harmony import */ var _types_js__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./types.js */ "./node_modules/css-selector-generator/esm/types.js");
/* harmony import */ var _utilities_element_data_js__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ./utilities-element-data.js */ "./node_modules/css-selector-generator/esm/utilities-element-data.js");




/**
 * Creates fallback selector for single element.
 */
function getElementFallbackSelector(element) {
    const parentElements = (0,_utilities_dom_js__WEBPACK_IMPORTED_MODULE_0__.getElementParents)(element).reverse();
    const elementsData = parentElements.map((element) => {
        const elementData = (0,_utilities_element_data_js__WEBPACK_IMPORTED_MODULE_3__.createElementData)(element, [_types_js__WEBPACK_IMPORTED_MODULE_2__.CSS_SELECTOR_TYPE.nthchild], _types_js__WEBPACK_IMPORTED_MODULE_2__.OPERATOR.CHILD);
        elementData.selectors.nthchild.forEach((selectorData) => {
            selectorData.include = true;
        });
        return elementData;
    });
    return [":root", ...elementsData.map(_utilities_element_data_js__WEBPACK_IMPORTED_MODULE_3__.constructElementSelector)].join("");
}
/**
 * Creates chain of :nth-child selectors from root to the elements.
 */
function getFallbackSelector(elements) {
    return elements.map(getElementFallbackSelector).join(_constants_js__WEBPACK_IMPORTED_MODULE_1__.SELECTOR_SEPARATOR);
}
//# sourceMappingURL=selector-fallback.js.map

/***/ }),

/***/ "./node_modules/css-selector-generator/esm/selector-id.js":
/*!****************************************************************!*\
  !*** ./node_modules/css-selector-generator/esm/selector-id.js ***!
  \****************************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   getElementIdSelectors: () => (/* binding */ getElementIdSelectors),
/* harmony export */   getIdSelector: () => (/* binding */ getIdSelector)
/* harmony export */ });
/* harmony import */ var _utilities_selectors_js__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./utilities-selectors.js */ "./node_modules/css-selector-generator/esm/utilities-selectors.js");
/* harmony import */ var _constants_js__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./constants.js */ "./node_modules/css-selector-generator/esm/constants.js");
/* harmony import */ var _utilities_dom_js__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./utilities-dom.js */ "./node_modules/css-selector-generator/esm/utilities-dom.js");



/**
 * Get ID selector for an element.
 * */
function getElementIdSelectors(element) {
    const id = element.getAttribute("id") || "";
    const selector = `#${(0,_utilities_selectors_js__WEBPACK_IMPORTED_MODULE_0__.sanitizeSelectorItem)(id)}`;
    const rootNode = element.getRootNode({ composed: false });
    return !_constants_js__WEBPACK_IMPORTED_MODULE_1__.INVALID_ID_RE.test(id) && (0,_utilities_dom_js__WEBPACK_IMPORTED_MODULE_2__.testSelector)([element], selector, rootNode)
        ? [selector]
        : [];
}
/**
 * Get ID selector for an element.
 */
function getIdSelector(elements) {
    return elements.length === 0 || elements.length > 1
        ? []
        : getElementIdSelectors(elements[0]);
}
//# sourceMappingURL=selector-id.js.map

/***/ }),

/***/ "./node_modules/css-selector-generator/esm/selector-nth-child.js":
/*!***********************************************************************!*\
  !*** ./node_modules/css-selector-generator/esm/selector-nth-child.js ***!
  \***********************************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   getElementNthChildSelector: () => (/* binding */ getElementNthChildSelector),
/* harmony export */   getNthChildSelector: () => (/* binding */ getNthChildSelector)
/* harmony export */ });
/* harmony import */ var _utilities_iselement_js__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./utilities-iselement.js */ "./node_modules/css-selector-generator/esm/utilities-iselement.js");
/* harmony import */ var _utilities_data_js__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./utilities-data.js */ "./node_modules/css-selector-generator/esm/utilities-data.js");


/**
 * Get nth-child selector for an element.
 */
function getElementNthChildSelector(element) {
    const parent = element.parentNode;
    if (parent) {
        const siblings = Array.from(parent.childNodes).filter(_utilities_iselement_js__WEBPACK_IMPORTED_MODULE_0__.isElement);
        const elementIndex = siblings.indexOf(element);
        if (elementIndex > -1) {
            return [`:nth-child(${elementIndex + 1})`];
        }
    }
    return [];
}
/**
 * Get nth-child selector matching all elements.
 */
function getNthChildSelector(elements) {
    return (0,_utilities_data_js__WEBPACK_IMPORTED_MODULE_1__.getIntersection)(elements.map(getElementNthChildSelector));
}
//# sourceMappingURL=selector-nth-child.js.map

/***/ }),

/***/ "./node_modules/css-selector-generator/esm/selector-nth-of-type.js":
/*!*************************************************************************!*\
  !*** ./node_modules/css-selector-generator/esm/selector-nth-of-type.js ***!
  \*************************************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   getElementNthOfTypeSelector: () => (/* binding */ getElementNthOfTypeSelector),
/* harmony export */   getNthOfTypeSelector: () => (/* binding */ getNthOfTypeSelector)
/* harmony export */ });
/* harmony import */ var _selector_tag_js__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./selector-tag.js */ "./node_modules/css-selector-generator/esm/selector-tag.js");
/* harmony import */ var _utilities_data_js__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./utilities-data.js */ "./node_modules/css-selector-generator/esm/utilities-data.js");


/**
 * Get nth-of-type selector for an element.
 */
function getElementNthOfTypeSelector(element) {
    const tag = (0,_selector_tag_js__WEBPACK_IMPORTED_MODULE_0__.getTagSelector)([element])[0];
    const parentElement = element.parentElement;
    if (parentElement) {
        const siblings = Array.from(parentElement.children).filter((element) => element.tagName.toLowerCase() === tag);
        const elementIndex = siblings.indexOf(element);
        if (elementIndex > -1) {
            return [
                `${tag}:nth-of-type(${elementIndex + 1})`,
            ];
        }
    }
    return [];
}
/**
 * Get Nth-of-type selector matching all elements.
 */
function getNthOfTypeSelector(elements) {
    return (0,_utilities_data_js__WEBPACK_IMPORTED_MODULE_1__.getIntersection)(elements.map(getElementNthOfTypeSelector));
}
//# sourceMappingURL=selector-nth-of-type.js.map

/***/ }),

/***/ "./node_modules/css-selector-generator/esm/selector-tag.js":
/*!*****************************************************************!*\
  !*** ./node_modules/css-selector-generator/esm/selector-tag.js ***!
  \*****************************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   getElementTagSelectors: () => (/* binding */ getElementTagSelectors),
/* harmony export */   getTagSelector: () => (/* binding */ getTagSelector)
/* harmony export */ });
/* harmony import */ var _utilities_selectors_js__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./utilities-selectors.js */ "./node_modules/css-selector-generator/esm/utilities-selectors.js");
/* harmony import */ var _utilities_data_js__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./utilities-data.js */ "./node_modules/css-selector-generator/esm/utilities-data.js");


/**
 * Get tag selector for an element.
 */
function getElementTagSelectors(element) {
    return [
        (0,_utilities_selectors_js__WEBPACK_IMPORTED_MODULE_0__.sanitizeSelectorItem)(element.tagName.toLowerCase()),
    ];
}
/**
 * Get tag selector for list of elements.
 */
function getTagSelector(elements) {
    const selectors = [
        ...new Set((0,_utilities_data_js__WEBPACK_IMPORTED_MODULE_1__.flattenArray)(elements.map(getElementTagSelectors))),
    ];
    return selectors.length === 0 || selectors.length > 1 ? [] : [selectors[0]];
}
//# sourceMappingURL=selector-tag.js.map

/***/ }),

/***/ "./node_modules/css-selector-generator/esm/types.js":
/*!**********************************************************!*\
  !*** ./node_modules/css-selector-generator/esm/types.js ***!
  \**********************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   CSS_SELECTOR_TYPE: () => (/* binding */ CSS_SELECTOR_TYPE),
/* harmony export */   OPERATOR: () => (/* binding */ OPERATOR)
/* harmony export */ });
const OPERATOR = {
    NONE: "",
    DESCENDANT: " ",
    CHILD: " > ",
};
const CSS_SELECTOR_TYPE = {
    id: "id",
    class: "class",
    tag: "tag",
    attribute: "attribute",
    nthchild: "nthchild",
    nthoftype: "nthoftype",
};
//# sourceMappingURL=types.js.map

/***/ }),

/***/ "./node_modules/css-selector-generator/esm/utilities-cartesian.js":
/*!************************************************************************!*\
  !*** ./node_modules/css-selector-generator/esm/utilities-cartesian.js ***!
  \************************************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   getCartesianProduct: () => (/* binding */ getCartesianProduct)
/* harmony export */ });
/**
 * Generates cartesian product out of input object.
 */
function getCartesianProduct(input = {}) {
    let result = [];
    Object.entries(input).forEach(([key, values]) => {
        result = values.flatMap((value) => {
            if (result.length === 0) {
                return [{ [key]: value }];
            }
            else {
                return result.map((memo) => (Object.assign(Object.assign({}, memo), { [key]: value })));
            }
        });
    });
    return result;
}
//# sourceMappingURL=utilities-cartesian.js.map

/***/ }),

/***/ "./node_modules/css-selector-generator/esm/utilities-data.js":
/*!*******************************************************************!*\
  !*** ./node_modules/css-selector-generator/esm/utilities-data.js ***!
  \*******************************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   createPatternMatcher: () => (/* binding */ createPatternMatcher),
/* harmony export */   flattenArray: () => (/* binding */ flattenArray),
/* harmony export */   getIntersection: () => (/* binding */ getIntersection),
/* harmony export */   wildcardToRegExp: () => (/* binding */ wildcardToRegExp)
/* harmony export */ });
/* harmony import */ var _utilities_options_js__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./utilities-options.js */ "./node_modules/css-selector-generator/esm/utilities-options.js");
/* harmony import */ var _utilities_messages_js__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./utilities-messages.js */ "./node_modules/css-selector-generator/esm/utilities-messages.js");


/**
 * Creates array containing only items included in all input arrays.
 */
function getIntersection(items = []) {
    const [firstItem = [], ...otherItems] = items;
    if (otherItems.length === 0) {
        return firstItem;
    }
    return otherItems.reduce((accumulator, currentValue) => {
        return accumulator.filter((item) => currentValue.includes(item));
    }, firstItem);
}
/**
 * Converts array of arrays into a flat array.
 */
function flattenArray(input) {
    return [].concat(...input);
}
/**
 * Convert string that can contain wildcards (asterisks) to RegExp source.
 */
function wildcardToRegExp(input) {
    return (input
        // convert all special characters used by RegExp, except an asterisk
        .replace(/[|\\{}()[\]^$+?.]/g, "\\$&")
        // convert asterisk to pattern that matches anything
        .replace(/\*/g, ".+"));
}
/**
 * Creates function that will test list of provided matchers against input.
 * Used for white/blacklist functionality.
 */
function createPatternMatcher(list) {
    const matchFunctions = list.map((item) => {
        if ((0,_utilities_options_js__WEBPACK_IMPORTED_MODULE_0__.isRegExp)(item)) {
            return (input) => item.test(input);
        }
        if (typeof item === "function") {
            return (input) => {
                const result = item(input);
                if (typeof result !== "boolean") {
                    // eslint-disable-next-line max-len
                    (0,_utilities_messages_js__WEBPACK_IMPORTED_MODULE_1__.showWarning)("pattern matcher function invalid", "Provided pattern matching function does not return boolean. It's result will be ignored.", item);
                    return false;
                }
                return result;
            };
        }
        if (typeof item === "string") {
            const re = new RegExp("^" + wildcardToRegExp(item) + "$");
            return (input) => re.test(input);
        }
        // eslint-disable-next-line max-len
        (0,_utilities_messages_js__WEBPACK_IMPORTED_MODULE_1__.showWarning)("pattern matcher invalid", "Pattern matching only accepts strings, regular expressions and/or functions. This item is invalid and will be ignored.", item);
        return () => false;
    });
    return (input) => matchFunctions.some((matchFunction) => matchFunction(input));
}
//# sourceMappingURL=utilities-data.js.map

/***/ }),

/***/ "./node_modules/css-selector-generator/esm/utilities-dom.js":
/*!******************************************************************!*\
  !*** ./node_modules/css-selector-generator/esm/utilities-dom.js ***!
  \******************************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   getElementParents: () => (/* binding */ getElementParents),
/* harmony export */   getParents: () => (/* binding */ getParents),
/* harmony export */   getRootNode: () => (/* binding */ getRootNode),
/* harmony export */   testMultiSelector: () => (/* binding */ testMultiSelector),
/* harmony export */   testSelector: () => (/* binding */ testSelector)
/* harmony export */ });
/* harmony import */ var _utilities_iselement_js__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./utilities-iselement.js */ "./node_modules/css-selector-generator/esm/utilities-iselement.js");
/* harmony import */ var _utilities_data_js__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./utilities-data.js */ "./node_modules/css-selector-generator/esm/utilities-data.js");
/* harmony import */ var _utilities_options_js__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./utilities-options.js */ "./node_modules/css-selector-generator/esm/utilities-options.js");



/**
 * Check whether element is matched uniquely by selector.
 */
function testSelector(elements, selector, root) {
    const result = Array.from((0,_utilities_options_js__WEBPACK_IMPORTED_MODULE_2__.sanitizeRoot)(root, elements[0]).querySelectorAll(selector));
    return (result.length === elements.length &&
        elements.every((element) => result.includes(element)));
}
/**
 * Test whether selector targets element. It does not have to be a unique match.
 */
function testMultiSelector(element, selector, root) {
    const result = Array.from((0,_utilities_options_js__WEBPACK_IMPORTED_MODULE_2__.sanitizeRoot)(root, element).querySelectorAll(selector));
    return result.includes(element);
}
/**
 * Find all parents of a single element.
 */
function getElementParents(element, root) {
    root = root !== null && root !== void 0 ? root : getRootNode(element);
    const result = [];
    let parent = element;
    while ((0,_utilities_iselement_js__WEBPACK_IMPORTED_MODULE_0__.isElement)(parent) && parent !== root) {
        result.push(parent);
        parent = parent.parentElement;
    }
    return result;
}
/**
 * Find all common parents of elements.
 */
function getParents(elements, root) {
    return (0,_utilities_data_js__WEBPACK_IMPORTED_MODULE_1__.getIntersection)(elements.map((element) => getElementParents(element, root)));
}
/**
 * Returns root node for given element. This needs to be used because of document-less environments, e.g. jsdom.
 */
function getRootNode(element) {
    return element.ownerDocument.querySelector(":root");
}
//# sourceMappingURL=utilities-dom.js.map

/***/ }),

/***/ "./node_modules/css-selector-generator/esm/utilities-element-data.js":
/*!***************************************************************************!*\
  !*** ./node_modules/css-selector-generator/esm/utilities-element-data.js ***!
  \***************************************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   constructElementSelector: () => (/* binding */ constructElementSelector),
/* harmony export */   createElementData: () => (/* binding */ createElementData),
/* harmony export */   createElementSelectorData: () => (/* binding */ createElementSelectorData)
/* harmony export */ });
/* harmony import */ var _types_js__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./types.js */ "./node_modules/css-selector-generator/esm/types.js");
/* harmony import */ var _constants_js__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./constants.js */ "./node_modules/css-selector-generator/esm/constants.js");
/* harmony import */ var _utilities_selectors_js__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./utilities-selectors.js */ "./node_modules/css-selector-generator/esm/utilities-selectors.js");



/**
 * Creates data describing a specific selector.
 */
function createElementSelectorData(selector) {
    return {
        value: selector,
        include: false,
    };
}
/**
 * Creates data describing an element within CssSelector chain.
 */
function createElementData(element, selectorTypes, operator = _types_js__WEBPACK_IMPORTED_MODULE_0__.OPERATOR.NONE) {
    const selectors = {};
    selectorTypes.forEach((selectorType) => {
        Reflect.set(selectors, selectorType, (0,_utilities_selectors_js__WEBPACK_IMPORTED_MODULE_2__.getElementSelectorsByType)(element, selectorType).map(createElementSelectorData));
    });
    return {
        element,
        operator,
        selectors,
    };
}
/**
 * Constructs selector from element data.
 */
function constructElementSelector({ selectors, operator, }) {
    let pattern = [..._constants_js__WEBPACK_IMPORTED_MODULE_1__.SELECTOR_PATTERN];
    // `nthoftype` already contains tag
    if (selectors[_types_js__WEBPACK_IMPORTED_MODULE_0__.CSS_SELECTOR_TYPE.tag] &&
        selectors[_types_js__WEBPACK_IMPORTED_MODULE_0__.CSS_SELECTOR_TYPE.nthoftype]) {
        pattern = pattern.filter((item) => item !== _types_js__WEBPACK_IMPORTED_MODULE_0__.CSS_SELECTOR_TYPE.tag);
    }
    let selector = "";
    pattern.forEach((selectorType) => {
        const selectorsOfType = selectors[selectorType] || [];
        selectorsOfType.forEach(({ value, include }) => {
            if (include) {
                selector += value;
            }
        });
    });
    return (operator + selector);
}
//# sourceMappingURL=utilities-element-data.js.map

/***/ }),

/***/ "./node_modules/css-selector-generator/esm/utilities-iselement.js":
/*!************************************************************************!*\
  !*** ./node_modules/css-selector-generator/esm/utilities-iselement.js ***!
  \************************************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   isElement: () => (/* binding */ isElement)
/* harmony export */ });
/**
 * Guard function that checks if provided `input` is an Element.
 */
function isElement(input) {
    return input && input instanceof Element;
}
//# sourceMappingURL=utilities-iselement.js.map

/***/ }),

/***/ "./node_modules/css-selector-generator/esm/utilities-messages.js":
/*!***********************************************************************!*\
  !*** ./node_modules/css-selector-generator/esm/utilities-messages.js ***!
  \***********************************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   showWarning: () => (/* binding */ showWarning)
/* harmony export */ });
const libraryName = "CssSelectorGenerator";
/**
 * Convenient wrapper for `console.warn` using consistent formatting.
 */
function showWarning(id = "unknown problem", ...args) {
    // eslint-disable-next-line no-console
    console.warn(`${libraryName}: ${id}`, ...args);
}
//# sourceMappingURL=utilities-messages.js.map

/***/ }),

/***/ "./node_modules/css-selector-generator/esm/utilities-options.js":
/*!**********************************************************************!*\
  !*** ./node_modules/css-selector-generator/esm/utilities-options.js ***!
  \**********************************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   DEFAULT_OPTIONS: () => (/* binding */ DEFAULT_OPTIONS),
/* harmony export */   isCssSelectorMatch: () => (/* binding */ isCssSelectorMatch),
/* harmony export */   isNode: () => (/* binding */ isNode),
/* harmony export */   isParentNode: () => (/* binding */ isParentNode),
/* harmony export */   isRegExp: () => (/* binding */ isRegExp),
/* harmony export */   sanitizeCssSelectorMatchList: () => (/* binding */ sanitizeCssSelectorMatchList),
/* harmony export */   sanitizeMaxNumber: () => (/* binding */ sanitizeMaxNumber),
/* harmony export */   sanitizeOptions: () => (/* binding */ sanitizeOptions),
/* harmony export */   sanitizeRoot: () => (/* binding */ sanitizeRoot),
/* harmony export */   sanitizeSelectorTypes: () => (/* binding */ sanitizeSelectorTypes)
/* harmony export */ });
/* harmony import */ var _types_js__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./types.js */ "./node_modules/css-selector-generator/esm/types.js");
/* harmony import */ var _utilities_typescript_js__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./utilities-typescript.js */ "./node_modules/css-selector-generator/esm/utilities-typescript.js");
/* harmony import */ var _utilities_messages_js__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./utilities-messages.js */ "./node_modules/css-selector-generator/esm/utilities-messages.js");



const DEFAULT_OPTIONS = {
    selectors: [
        _types_js__WEBPACK_IMPORTED_MODULE_0__.CSS_SELECTOR_TYPE.id,
        _types_js__WEBPACK_IMPORTED_MODULE_0__.CSS_SELECTOR_TYPE.class,
        _types_js__WEBPACK_IMPORTED_MODULE_0__.CSS_SELECTOR_TYPE.tag,
        _types_js__WEBPACK_IMPORTED_MODULE_0__.CSS_SELECTOR_TYPE.attribute,
    ],
    // if set to true, always include tag name
    includeTag: false,
    whitelist: [],
    blacklist: [],
    combineWithinSelector: true,
    combineBetweenSelectors: true,
    root: null,
    maxCombinations: Number.POSITIVE_INFINITY,
    maxCandidates: Number.POSITIVE_INFINITY,
};
/**
 * Makes sure returned value is a list containing only valid selector types.
 * @param input
 */
function sanitizeSelectorTypes(input) {
    if (!Array.isArray(input)) {
        return [];
    }
    return input.filter((item) => (0,_utilities_typescript_js__WEBPACK_IMPORTED_MODULE_1__.isEnumValue)(_types_js__WEBPACK_IMPORTED_MODULE_0__.CSS_SELECTOR_TYPE, item));
}
/**
 * Checks whether provided value is of type RegExp.
 */
function isRegExp(input) {
    return input instanceof RegExp;
}
/**
 * Checks whether provided value is usable in whitelist or blacklist.
 * @param input
 */
function isCssSelectorMatch(input) {
    return ["string", "function"].includes(typeof input) || isRegExp(input);
}
/**
 * Converts input to a list of valid values for whitelist or blacklist.
 */
function sanitizeCssSelectorMatchList(input) {
    if (!Array.isArray(input)) {
        return [];
    }
    return input.filter(isCssSelectorMatch);
}
/**
 * Checks whether provided value is valid Node.
 */
function isNode(input) {
    return input instanceof Node;
}
/**
 * Checks whether provided value is valid ParentNode.
 */
function isParentNode(input) {
    const validParentNodeTypes = [
        Node.DOCUMENT_NODE,
        Node.DOCUMENT_FRAGMENT_NODE,
        Node.ELEMENT_NODE,
    ];
    return isNode(input) && validParentNodeTypes.includes(input.nodeType);
}
/**
 * Makes sure that the root node in options is valid.
 */
function sanitizeRoot(input, element) {
    if (isParentNode(input)) {
        if (!input.contains(element)) {
            // eslint-disable-next-line max-len
            (0,_utilities_messages_js__WEBPACK_IMPORTED_MODULE_2__.showWarning)("element root mismatch", "Provided root does not contain the element. This will most likely result in producing a fallback selector using element's real root node. If you plan to use the selector using provided root (e.g. `root.querySelector`), it will nto work as intended.");
        }
        return input;
    }
    const rootNode = element.getRootNode({ composed: false });
    if (isParentNode(rootNode)) {
        if (rootNode !== document) {
            // eslint-disable-next-line max-len
            (0,_utilities_messages_js__WEBPACK_IMPORTED_MODULE_2__.showWarning)("shadow root inferred", "You did not provide a root and the element is a child of Shadow DOM. This will produce a selector using ShadowRoot as a root. If you plan to use the selector using document as a root (e.g. `document.querySelector`), it will not work as intended.");
        }
        return rootNode;
    }
    return element.ownerDocument.querySelector(":root");
}
/**
 * Makes sure that the output is a number, usable as `maxResults` option in
 * powerset generator.
 */
function sanitizeMaxNumber(input) {
    return typeof input === "number" ? input : Number.POSITIVE_INFINITY;
}
/**
 * Makes sure the options object contains all required keys.
 */
function sanitizeOptions(element, custom_options = {}) {
    const options = Object.assign(Object.assign({}, DEFAULT_OPTIONS), custom_options);
    return {
        selectors: sanitizeSelectorTypes(options.selectors),
        whitelist: sanitizeCssSelectorMatchList(options.whitelist),
        blacklist: sanitizeCssSelectorMatchList(options.blacklist),
        root: sanitizeRoot(options.root, element),
        combineWithinSelector: !!options.combineWithinSelector,
        combineBetweenSelectors: !!options.combineBetweenSelectors,
        includeTag: !!options.includeTag,
        maxCombinations: sanitizeMaxNumber(options.maxCombinations),
        maxCandidates: sanitizeMaxNumber(options.maxCandidates),
    };
}
//# sourceMappingURL=utilities-options.js.map

/***/ }),

/***/ "./node_modules/css-selector-generator/esm/utilities-powerset.js":
/*!***********************************************************************!*\
  !*** ./node_modules/css-selector-generator/esm/utilities-powerset.js ***!
  \***********************************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   getPowerSet: () => (/* binding */ getPowerSet),
/* harmony export */   powerSetGenerator: () => (/* binding */ powerSetGenerator)
/* harmony export */ });
function* powerSetGenerator(input = [], { maxResults = Number.POSITIVE_INFINITY } = {}) {
    let resultCounter = 0;
    let offsets = generateOffsets(1);
    while (offsets.length <= input.length && resultCounter < maxResults) {
        resultCounter += 1;
        const result = offsets.map((offset) => input[offset]);
        yield result;
        offsets = bumpOffsets(offsets, input.length - 1);
    }
}
/**
 * Generates power set of input items.
 */
function getPowerSet(input = [], { maxResults = Number.POSITIVE_INFINITY } = {}) {
    return Array.from(powerSetGenerator(input, { maxResults }));
}
/**
 * Helper function used by `getPowerSet`. Updates internal pointers.
 */
function bumpOffsets(offsets = [], maxValue = 0) {
    const size = offsets.length;
    if (size === 0) {
        return [];
    }
    const result = [...offsets];
    result[size - 1] += 1;
    for (let index = size - 1; index >= 0; index--) {
        if (result[index] > maxValue) {
            if (index === 0) {
                return generateOffsets(size + 1);
            }
            else {
                result[index - 1]++;
                result[index] = result[index - 1] + 1;
            }
        }
    }
    if (result[size - 1] > maxValue) {
        return generateOffsets(size + 1);
    }
    return result;
}
/**
 * Generates array of size N, filled with numbers sequence starting from 0.
 */
function generateOffsets(size = 1) {
    return Array.from(Array(size).keys());
}
//# sourceMappingURL=utilities-powerset.js.map

/***/ }),

/***/ "./node_modules/css-selector-generator/esm/utilities-selectors.js":
/*!************************************************************************!*\
  !*** ./node_modules/css-selector-generator/esm/utilities-selectors.js ***!
  \************************************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   ELEMENT_SELECTOR_TYPE_GETTERS: () => (/* binding */ ELEMENT_SELECTOR_TYPE_GETTERS),
/* harmony export */   ESCAPED_COLON: () => (/* binding */ ESCAPED_COLON),
/* harmony export */   SELECTOR_TYPE_GETTERS: () => (/* binding */ SELECTOR_TYPE_GETTERS),
/* harmony export */   SPECIAL_CHARACTERS_RE: () => (/* binding */ SPECIAL_CHARACTERS_RE),
/* harmony export */   combineSelectorTypes: () => (/* binding */ combineSelectorTypes),
/* harmony export */   constructSelector: () => (/* binding */ constructSelector),
/* harmony export */   constructSelectorType: () => (/* binding */ constructSelectorType),
/* harmony export */   constructSelectors: () => (/* binding */ constructSelectors),
/* harmony export */   filterSelectors: () => (/* binding */ filterSelectors),
/* harmony export */   getAllSelectors: () => (/* binding */ getAllSelectors),
/* harmony export */   getClosestIdentifiableParent: () => (/* binding */ getClosestIdentifiableParent),
/* harmony export */   getElementSelectorsByType: () => (/* binding */ getElementSelectorsByType),
/* harmony export */   getSelectorWithinRoot: () => (/* binding */ getSelectorWithinRoot),
/* harmony export */   getSelectorsByType: () => (/* binding */ getSelectorsByType),
/* harmony export */   getSelectorsList: () => (/* binding */ getSelectorsList),
/* harmony export */   getSelectorsToGet: () => (/* binding */ getSelectorsToGet),
/* harmony export */   getTypeCombinations: () => (/* binding */ getTypeCombinations),
/* harmony export */   legacySanitizeSelectorItem: () => (/* binding */ legacySanitizeSelectorItem),
/* harmony export */   orderSelectors: () => (/* binding */ orderSelectors),
/* harmony export */   sanitizeSelectorItem: () => (/* binding */ sanitizeSelectorItem),
/* harmony export */   sanitizeSelectorNeedle: () => (/* binding */ sanitizeSelectorNeedle)
/* harmony export */ });
/* harmony import */ var _constants_js__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./constants.js */ "./node_modules/css-selector-generator/esm/constants.js");
/* harmony import */ var _selector_attribute_js__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./selector-attribute.js */ "./node_modules/css-selector-generator/esm/selector-attribute.js");
/* harmony import */ var _selector_class_js__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./selector-class.js */ "./node_modules/css-selector-generator/esm/selector-class.js");
/* harmony import */ var _selector_id_js__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ./selector-id.js */ "./node_modules/css-selector-generator/esm/selector-id.js");
/* harmony import */ var _selector_nth_child_js__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! ./selector-nth-child.js */ "./node_modules/css-selector-generator/esm/selector-nth-child.js");
/* harmony import */ var _selector_nth_of_type_js__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! ./selector-nth-of-type.js */ "./node_modules/css-selector-generator/esm/selector-nth-of-type.js");
/* harmony import */ var _selector_tag_js__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! ./selector-tag.js */ "./node_modules/css-selector-generator/esm/selector-tag.js");
/* harmony import */ var _utilities_data_js__WEBPACK_IMPORTED_MODULE_7__ = __webpack_require__(/*! ./utilities-data.js */ "./node_modules/css-selector-generator/esm/utilities-data.js");
/* harmony import */ var _utilities_dom_js__WEBPACK_IMPORTED_MODULE_8__ = __webpack_require__(/*! ./utilities-dom.js */ "./node_modules/css-selector-generator/esm/utilities-dom.js");
/* harmony import */ var _types_js__WEBPACK_IMPORTED_MODULE_9__ = __webpack_require__(/*! ./types.js */ "./node_modules/css-selector-generator/esm/types.js");
/* harmony import */ var _utilities_iselement_js__WEBPACK_IMPORTED_MODULE_10__ = __webpack_require__(/*! ./utilities-iselement.js */ "./node_modules/css-selector-generator/esm/utilities-iselement.js");
/* harmony import */ var _utilities_powerset_js__WEBPACK_IMPORTED_MODULE_11__ = __webpack_require__(/*! ./utilities-powerset.js */ "./node_modules/css-selector-generator/esm/utilities-powerset.js");
/* harmony import */ var _utilities_cartesian_js__WEBPACK_IMPORTED_MODULE_12__ = __webpack_require__(/*! ./utilities-cartesian.js */ "./node_modules/css-selector-generator/esm/utilities-cartesian.js");













const ESCAPED_COLON = ":".charCodeAt(0).toString(16).toUpperCase();
// Square brackets need to be escaped, but eslint has a problem with that.
/* eslint-disable-next-line no-useless-escape */
const SPECIAL_CHARACTERS_RE = /[ !"#$%&'()\[\]{|}<>*+,./;=?@^`~\\]/;
/**
 * Escapes special characters used by CSS selector items.
 */
function sanitizeSelectorItem(input = "") {
    var _a, _b;
    return (_b = (_a = CSS === null || CSS === void 0 ? void 0 : CSS.escape) === null || _a === void 0 ? void 0 : _a.call(CSS, input)) !== null && _b !== void 0 ? _b : legacySanitizeSelectorItem(input);
}
/**
 * Legacy version of escaping utility, originally used for IE11-. Should
 * probably be replaced by a polyfill:
 * https://github.com/mathiasbynens/CSS.escape
 */
function legacySanitizeSelectorItem(input = "") {
    return input
        .split("")
        .map((character) => {
        if (character === ":") {
            return `\\${ESCAPED_COLON} `;
        }
        if (SPECIAL_CHARACTERS_RE.test(character)) {
            return `\\${character}`;
        }
        return escape(character).replace(/%/g, "\\");
    })
        .join("");
}
const SELECTOR_TYPE_GETTERS = {
    tag: _selector_tag_js__WEBPACK_IMPORTED_MODULE_6__.getTagSelector,
    id: _selector_id_js__WEBPACK_IMPORTED_MODULE_3__.getIdSelector,
    class: _selector_class_js__WEBPACK_IMPORTED_MODULE_2__.getClassSelectors,
    attribute: _selector_attribute_js__WEBPACK_IMPORTED_MODULE_1__.getAttributeSelectors,
    nthchild: _selector_nth_child_js__WEBPACK_IMPORTED_MODULE_4__.getNthChildSelector,
    nthoftype: _selector_nth_of_type_js__WEBPACK_IMPORTED_MODULE_5__.getNthOfTypeSelector,
};
const ELEMENT_SELECTOR_TYPE_GETTERS = {
    tag: _selector_tag_js__WEBPACK_IMPORTED_MODULE_6__.getElementTagSelectors,
    id: _selector_id_js__WEBPACK_IMPORTED_MODULE_3__.getElementIdSelectors,
    class: _selector_class_js__WEBPACK_IMPORTED_MODULE_2__.getElementClassSelectors,
    attribute: _selector_attribute_js__WEBPACK_IMPORTED_MODULE_1__.getElementAttributeSelectors,
    nthchild: _selector_nth_child_js__WEBPACK_IMPORTED_MODULE_4__.getElementNthChildSelector,
    nthoftype: _selector_nth_of_type_js__WEBPACK_IMPORTED_MODULE_5__.getElementNthOfTypeSelector,
};
/**
 * Creates selector of given type for single element.
 */
function getElementSelectorsByType(element, selectorType) {
    return ELEMENT_SELECTOR_TYPE_GETTERS[selectorType](element);
}
/**
 * Returns list of selectors of given type for the element.
 */
function getSelectorsByType(elements, selector_type) {
    var _a;
    const getter = (_a = SELECTOR_TYPE_GETTERS[selector_type]) !== null && _a !== void 0 ? _a : (() => []);
    return getter(elements);
}
/**
 * Remove blacklisted selectors from list.
 */
function filterSelectors(list = [], matchBlacklist, matchWhitelist) {
    return list.filter((item) => matchWhitelist(item) || !matchBlacklist(item));
}
/**
 * Prioritise whitelisted selectors in list.
 */
function orderSelectors(list = [], matchWhitelist) {
    return list.sort((a, b) => {
        const a_is_whitelisted = matchWhitelist(a);
        const b_is_whitelisted = matchWhitelist(b);
        if (a_is_whitelisted && !b_is_whitelisted) {
            return -1;
        }
        if (!a_is_whitelisted && b_is_whitelisted) {
            return 1;
        }
        return 0;
    });
}
/**
 * Returns list of unique selectors applicable to given element.
 */
function getAllSelectors(elements, root, options) {
    const selectors_list = getSelectorsList(elements, options);
    const type_combinations = getTypeCombinations(selectors_list, options);
    const all_selectors = (0,_utilities_data_js__WEBPACK_IMPORTED_MODULE_7__.flattenArray)(type_combinations);
    return [...new Set(all_selectors)];
}
/**
 * Creates object containing all selector types and their potential values.
 */
function getSelectorsList(elements, options) {
    const { blacklist, whitelist, combineWithinSelector, maxCombinations } = options;
    const matchBlacklist = (0,_utilities_data_js__WEBPACK_IMPORTED_MODULE_7__.createPatternMatcher)(blacklist);
    const matchWhitelist = (0,_utilities_data_js__WEBPACK_IMPORTED_MODULE_7__.createPatternMatcher)(whitelist);
    const reducer = (data, selector_type) => {
        const selectors_by_type = getSelectorsByType(elements, selector_type);
        const filtered_selectors = filterSelectors(selectors_by_type, matchBlacklist, matchWhitelist);
        const found_selectors = orderSelectors(filtered_selectors, matchWhitelist);
        data[selector_type] = combineWithinSelector
            ? (0,_utilities_powerset_js__WEBPACK_IMPORTED_MODULE_11__.getPowerSet)(found_selectors, { maxResults: maxCombinations })
            : found_selectors.map((item) => [item]);
        return data;
    };
    return getSelectorsToGet(options).reduce(reducer, {});
}
/**
 * Creates list of selector types that we will need to generate the selector.
 */
function getSelectorsToGet(options) {
    const { selectors, includeTag } = options;
    const selectors_to_get = [].concat(selectors);
    if (includeTag && !selectors_to_get.includes("tag")) {
        selectors_to_get.push("tag");
    }
    return selectors_to_get;
}
/**
 * Adds "tag" to a list, if it does not contain it. Used to modify selectors
 * list when includeTag option is enabled to make sure all results contain the
 * TAG part.
 */
function addTagTypeIfNeeded(list) {
    return list.includes(_types_js__WEBPACK_IMPORTED_MODULE_9__.CSS_SELECTOR_TYPE.tag) ||
        list.includes(_types_js__WEBPACK_IMPORTED_MODULE_9__.CSS_SELECTOR_TYPE.nthoftype)
        ? [...list]
        : [...list, _types_js__WEBPACK_IMPORTED_MODULE_9__.CSS_SELECTOR_TYPE.tag];
}
/**
 * Generates list of possible selector type combinations.
 */
function combineSelectorTypes(options) {
    const { selectors, combineBetweenSelectors, includeTag, maxCandidates } = options;
    const combinations = combineBetweenSelectors
        ? (0,_utilities_powerset_js__WEBPACK_IMPORTED_MODULE_11__.getPowerSet)(selectors, { maxResults: maxCandidates })
        : selectors.map((item) => [item]);
    return includeTag ? combinations.map(addTagTypeIfNeeded) : combinations;
}
/**
 * Generates list of combined CSS selectors.
 */
function getTypeCombinations(selectors_list, options) {
    return combineSelectorTypes(options)
        .map((item) => {
        return constructSelectors(item, selectors_list);
    })
        .filter((item) => item.length > 0);
}
/**
 * Generates all variations of possible selectors from provided data.
 */
function constructSelectors(selector_types, selectors_by_type) {
    const data = {};
    selector_types.forEach((selector_type) => {
        const selector_variants = selectors_by_type[selector_type];
        if (selector_variants.length > 0) {
            data[selector_type] = selector_variants;
        }
    });
    const combinations = (0,_utilities_cartesian_js__WEBPACK_IMPORTED_MODULE_12__.getCartesianProduct)(data);
    return combinations.map(constructSelector);
}
/**
 * Creates selector for given selector type. Combines several parts if needed.
 */
function constructSelectorType(selector_type, selectors_data) {
    return selectors_data[selector_type]
        ? selectors_data[selector_type].join("")
        : "";
}
/**
 * Converts selector data object to a selector.
 */
function constructSelector(selectorData = {}) {
    const pattern = [..._constants_js__WEBPACK_IMPORTED_MODULE_0__.SELECTOR_PATTERN];
    // selector "nthoftype" already contains "tag"
    if (selectorData[_types_js__WEBPACK_IMPORTED_MODULE_9__.CSS_SELECTOR_TYPE.tag] &&
        selectorData[_types_js__WEBPACK_IMPORTED_MODULE_9__.CSS_SELECTOR_TYPE.nthoftype]) {
        pattern.splice(pattern.indexOf(_types_js__WEBPACK_IMPORTED_MODULE_9__.CSS_SELECTOR_TYPE.tag), 1);
    }
    return pattern
        .map((type) => constructSelectorType(type, selectorData))
        .join("");
}
/**
 * Generates combinations of child and descendant selectors within root
 * selector.
 */
function generateCandidateCombinations(selectors, rootSelector) {
    return [
        ...selectors.map((selector) => rootSelector + _types_js__WEBPACK_IMPORTED_MODULE_9__.OPERATOR.DESCENDANT + selector),
        ...selectors.map((selector) => rootSelector + _types_js__WEBPACK_IMPORTED_MODULE_9__.OPERATOR.CHILD + selector),
    ];
}
/**
 * Generates a list of selector candidates that can potentially match target
 * element.
 */
function generateCandidates(selectors, rootSelector) {
    return rootSelector === ""
        ? selectors
        : generateCandidateCombinations(selectors, rootSelector);
}
/**
 * Tries to find an unique CSS selector for element within given parent.
 */
function getSelectorWithinRoot(elements, root, rootSelector = "", options) {
    const elementSelectors = getAllSelectors(elements, options.root, options);
    const selectorCandidates = generateCandidates(elementSelectors, rootSelector);
    for (const candidateSelector of selectorCandidates) {
        if ((0,_utilities_dom_js__WEBPACK_IMPORTED_MODULE_8__.testSelector)(elements, candidateSelector, options.root)) {
            return candidateSelector;
        }
    }
    return null;
}
/**
 * Climbs through parents of the element and tries to find the one that is
 * identifiable by unique CSS selector.
 */
function getClosestIdentifiableParent(elements, root, rootSelector = "", options) {
    if (elements.length === 0) {
        return null;
    }
    const candidatesList = [
        elements.length > 1 ? elements : [],
        ...(0,_utilities_dom_js__WEBPACK_IMPORTED_MODULE_8__.getParents)(elements, root).map((element) => [element]),
    ];
    for (const currentElements of candidatesList) {
        const result = getSelectorWithinRoot(currentElements, root, rootSelector, options);
        if (result) {
            return {
                foundElements: currentElements,
                selector: result,
            };
        }
    }
    return null;
}
/**
 * Converts input into list of elements, removing duplicates and non-elements.
 */
function sanitizeSelectorNeedle(needle) {
    if (needle instanceof NodeList || needle instanceof HTMLCollection) {
        needle = Array.from(needle);
    }
    const elements = (Array.isArray(needle) ? needle : [needle]).filter(_utilities_iselement_js__WEBPACK_IMPORTED_MODULE_10__.isElement);
    return [...new Set(elements)];
}
//# sourceMappingURL=utilities-selectors.js.map

/***/ }),

/***/ "./node_modules/css-selector-generator/esm/utilities-typescript.js":
/*!*************************************************************************!*\
  !*** ./node_modules/css-selector-generator/esm/utilities-typescript.js ***!
  \*************************************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony export */ __webpack_require__.d(__webpack_exports__, {
/* harmony export */   isEnumValue: () => (/* binding */ isEnumValue)
/* harmony export */ });
/**
 * Checks whether value is one of the enum's values.
 */
function isEnumValue(haystack, needle) {
    return Object.values(haystack).includes(needle);
}
//# sourceMappingURL=utilities-typescript.js.map

/***/ })

/******/ 	});
/************************************************************************/
/******/ 	// The module cache
/******/ 	var __webpack_module_cache__ = {};
/******/ 	
/******/ 	// The require function
/******/ 	function __webpack_require__(moduleId) {
/******/ 		// Check if module is in cache
/******/ 		var cachedModule = __webpack_module_cache__[moduleId];
/******/ 		if (cachedModule !== undefined) {
/******/ 			return cachedModule.exports;
/******/ 		}
/******/ 		// Create a new module (and put it into the cache)
/******/ 		var module = __webpack_module_cache__[moduleId] = {
/******/ 			// no module.id needed
/******/ 			// no module.loaded needed
/******/ 			exports: {}
/******/ 		};
/******/ 	
/******/ 		// Execute the module function
/******/ 		__webpack_modules__[moduleId](module, module.exports, __webpack_require__);
/******/ 	
/******/ 		// Return the exports of the module
/******/ 		return module.exports;
/******/ 	}
/******/ 	
/************************************************************************/
/******/ 	/* webpack/runtime/compat get default export */
/******/ 	(() => {
/******/ 		// getDefaultExport function for compatibility with non-harmony modules
/******/ 		__webpack_require__.n = (module) => {
/******/ 			var getter = module && module.__esModule ?
/******/ 				() => (module['default']) :
/******/ 				() => (module);
/******/ 			__webpack_require__.d(getter, { a: getter });
/******/ 			return getter;
/******/ 		};
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/define property getters */
/******/ 	(() => {
/******/ 		// define getter functions for harmony exports
/******/ 		__webpack_require__.d = (exports, definition) => {
/******/ 			for(var key in definition) {
/******/ 				if(__webpack_require__.o(definition, key) && !__webpack_require__.o(exports, key)) {
/******/ 					Object.defineProperty(exports, key, { enumerable: true, get: definition[key] });
/******/ 				}
/******/ 			}
/******/ 		};
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/global */
/******/ 	(() => {
/******/ 		__webpack_require__.g = (function() {
/******/ 			if (typeof globalThis === 'object') return globalThis;
/******/ 			try {
/******/ 				return this || new Function('return this')();
/******/ 			} catch (e) {
/******/ 				if (typeof window === 'object') return window;
/******/ 			}
/******/ 		})();
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/hasOwnProperty shorthand */
/******/ 	(() => {
/******/ 		__webpack_require__.o = (obj, prop) => (Object.prototype.hasOwnProperty.call(obj, prop))
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/make namespace object */
/******/ 	(() => {
/******/ 		// define __esModule on exports
/******/ 		__webpack_require__.r = (exports) => {
/******/ 			if(typeof Symbol !== 'undefined' && Symbol.toStringTag) {
/******/ 				Object.defineProperty(exports, Symbol.toStringTag, { value: 'Module' });
/******/ 			}
/******/ 			Object.defineProperty(exports, '__esModule', { value: true });
/******/ 		};
/******/ 	})();
/******/ 	
/************************************************************************/
var __webpack_exports__ = {};
// This entry need to be wrapped in an IIFE because it need to be in strict mode.
(() => {
"use strict";
/*!*********************************!*\
  !*** ./src/index-reflowable.js ***!
  \*********************************/
__webpack_require__.r(__webpack_exports__);
/* harmony import */ var _index__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./index */ "./src/index.js");
//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

// Script used for reflowable resources.


window.readium.isReflowable = true;
window.addEventListener("load", function () {
  // Notifies native code that the page is loaded after it is rendered.
  // Waiting for the next animation frame seems to do the trick to make sure the page is fully rendered.
  window.requestAnimationFrame(function () {
    webkit.messageHandlers.spreadLoaded.postMessage({});
  });

  // Setups the `viewport` meta tag to disable zooming.
  let meta = document.createElement("meta");
  meta.setAttribute("name", "viewport");
  meta.setAttribute("content", "width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, shrink-to-fit=no");
  document.head.appendChild(meta);
});

// Injects Readium CSS stylesheets (legacy Settings API).
document.addEventListener("DOMContentLoaded", function () {
  if (!window.readiumCSSBaseURL) return;
  function createLink(name) {
    var link = document.createElement("link");
    link.setAttribute("rel", "stylesheet");
    link.setAttribute("type", "text/css");
    link.setAttribute("href", window.readiumCSSBaseURL + name + ".css");
    return link;
  }
  var head = document.getElementsByTagName("head")[0];
  head.appendChild(createLink("ReadiumCSS-after"));
  head.insertBefore(createLink("ReadiumCSS-before"), head.children[0]);
});
})();

/******/ })()
;