// Override the onRightButtonDown function to disable two-finger input
TouchInput._onRightButtonDown = function(event) {
    // Prevent the default behavior when two fingers are used
    if (event.touches && event.touches.length > 1) {
        event.preventDefault();
    } else {
        this._newState.cancelled = true;
    }
};

// Additionally, override the _onTrigger function to ensure two-finger taps don't trigger a right-click
TouchInput._onTrigger = function(x, y) {
    if (this.isTriggered() && !(this.isCancelled() || this.isCancelled())) {
        this._screenX = x;
        this._screenY = y;
        this._triggered = true;
    }
};

// Make sure that only single-touch inputs are recognized
TouchInput._onTouchStart = function(event) {
    for (var i = 0; i < event.changedTouches.length; i++) {
        var touch = event.changedTouches[i];
        if (event.touches.length === 1) {
            var x = Graphics.pageToCanvasX(touch.pageX);
            var y = Graphics.pageToCanvasY(touch.pageY);
            this._onTrigger(x, y);
        }
    }
};

// Ignore touch end events if there are more than one finger on the screen
TouchInput._onTouchEnd = function(event) {
    for (var i = 0; i < event.changedTouches.length; i++) {
        var touch = event.changedTouches[i];
        if (event.touches.length === 1) {
            var x = Graphics.pageToCanvasX(touch.pageX);
            var y = Graphics.pageToCanvasY(touch.pageY);
            this._onRelease(x, y);
        }
    }
};
