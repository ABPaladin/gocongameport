/*:
 * @plugindesc Toggle visibility of Aloe VirtualButtons via the options menu in RPG Maker MV.
 * @author YourName
 *
 * @help
 * This plugin allows the player to toggle the visibility of Aloe VirtualButtons
 * via an option in the options menu.
 */

(function() {
    // Ensure the virtual buttons setting is initialized
    const _Game_System_initialize = Game_System.prototype.initialize;
    Game_System.prototype.initialize = function() {
        _Game_System_initialize.call(this);
        if (this._virtualButtonsEnabled === undefined) {
            this._virtualButtonsEnabled = true; // Default to enabled
        }
    };

    // Add the virtual buttons option to the options menu
    const _Window_Options_addGeneralOptions = Window_Options.prototype.addGeneralOptions;
    Window_Options.prototype.addGeneralOptions = function() {
        _Window_Options_addGeneralOptions.call(this);
        this.addCommand('Virtual Buttons', 'virtualButtons');
    };

    // Define getter for the virtual buttons option
    const _Window_Options_getConfigValue = Window_Options.prototype.getConfigValue;
    Window_Options.prototype.getConfigValue = function(symbol) {
        if (symbol === 'virtualButtons') {
            return $gameSystem._virtualButtonsEnabled;
        }
        return _Window_Options_getConfigValue.call(this, symbol);
    };

    // Define setter for the virtual buttons option
    const _Window_Options_setConfigValue = Window_Options.prototype.setConfigValue;
    Window_Options.prototype.setConfigValue = function(symbol, value) {
        if (symbol === 'virtualButtons') {
            $gameSystem._virtualButtonsEnabled = value;
            AloeVirtualButtonsToggle.refreshVirtualButtons(value);
        } else {
            _Window_Options_setConfigValue.call(this, symbol, value);
        }
    };

    // Function to refresh virtual buttons visibility
    const AloeVirtualButtonsToggle = {
        refreshVirtualButtons: function(enabled) {
            if (enabled) {
                AloeVirtualButtonsToggle.showVirtualButtons();
            } else {
                AloeVirtualButtonsToggle.hideVirtualButtons();
            }
        },

        showVirtualButtons: function() {
            const scene = SceneManager._scene;
            if (scene.showVirtualButtons) {
                scene.showVirtualButtons();
            }
        },

        hideVirtualButtons: function() {
            const scene = SceneManager._scene;
            if (scene.hideVirtualButtons) {
                scene.hideVirtualButtons();
            }
        }
    };

    // Hook into the Scene_Map start to ensure the buttons are refreshed
    const _Scene_Map_start = Scene_Map.prototype.start;
    Scene_Map.prototype.start = function() {
        _Scene_Map_start.call(this);
        AloeVirtualButtonsToggle.refreshVirtualButtons($gameSystem._virtualButtonsEnabled);
    };

})();
