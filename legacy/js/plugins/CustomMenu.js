/*:
 * @plugindesc Customizes the main menu by hiding the status, gold, and item windows, centering the command window, and adding an "Exit Menu" option.
 * @help This plugin hides the status, gold, and item windows in the main menu, centers the command window, and adds an "Exit Menu" option.
 */

(function() {
    // Alias the original create method
    var _Scene_Menu_create = Scene_Menu.prototype.create;
    Scene_Menu.prototype.create = function() {
        try {
            _Scene_Menu_create.call(this);
            this._commandWindow.x = (Graphics.boxWidth - this._commandWindow.width) / 2;
            this._commandWindow.y = (Graphics.boxHeight - this._commandWindow.height) / 2;
        } catch (e) {
            console.error('Error in Scene_Menu.create:', e);
        }
    };

    // Alias the original start method
    var _Scene_Menu_start = Scene_Menu.prototype.start;
    Scene_Menu.prototype.start = function() {
        try {
            if (this._statusWindow) {
                this._statusWindow.hide();
            } else {
                console.warn('Warning: _statusWindow is undefined in Scene_Menu.start');
            }
            if (this._goldWindow) {
                this._goldWindow.hide();
            } else {
                console.warn('Warning: _goldWindow is undefined in Scene_Menu.start');
            }
            if (this._itemWindow) {
                this._itemWindow.hide();
            } else {
                console.warn('Warning: _itemWindow is undefined in Scene_Menu.start');
            }
        } catch (e) {
            console.error('Error in Scene_Menu.start:', e);
        }
    };

    // Add "Exit Menu" command to the main menu
    var _Window_MenuCommand_makeCommandList = Window_MenuCommand.prototype.makeCommandList;
    Window_MenuCommand.prototype.makeCommandList = function() {
        _Window_MenuCommand_makeCommandList.call(this);
        this.addCommand('Exit Menu', 'exit', true);  // Adds the "Exit Menu" option
    };

    // Handle the "Exit Menu" command
    var _Scene_Menu_createCommandWindow = Scene_Menu.prototype.createCommandWindow;
    Scene_Menu.prototype.createCommandWindow = function() {
        _Scene_Menu_createCommandWindow.call(this);
        this._commandWindow.setHandler('exit', this.popScene.bind(this));  // Closes the menu and returns to the map
    };

    // Hide the status, gold, and item windows (Optional)
    Scene_Menu.prototype.createStatusWindow = function() {
        try {
            // No need to create the status window, it remains hidden
        } catch (e) {
            console.error('Error in Scene_Menu.createStatusWindow:', e);
        }
    };

    Scene_Menu.prototype.createGoldWindow = function() {
        try {
            // No need to create the gold window, it remains hidden
        } catch (e) {
            console.error('Error in Scene_Menu.createGoldWindow:', e);
        }
    };

    Scene_Menu.prototype.createItemWindow = function() {
        try {
            // No need to create the item window, it remains hidden
        } catch (e) {
            console.error('Error in Scene_Menu.createItemWindow:', e);
        }
    };
})();
