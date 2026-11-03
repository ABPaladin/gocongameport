(function() {
    // Add the "Exit" command to the options menu
    var _Window_Options_makeCommandList = Window_Options.prototype.makeCommandList;
    Window_Options.prototype.makeCommandList = function() {
        _Window_Options_makeCommandList.call(this);
        console.log("Adding Exit command");
        this.addCommand('Exit', 'exit', true);  // Adds "Exit" as a button
    };
    

    // Ensure the "Exit" command is handled
    var _Scene_Options_createOptionsWindow = Scene_Options.prototype.createOptionsWindow;
    Scene_Options.prototype.createOptionsWindow = function() {
        _Scene_Options_createOptionsWindow.call(this);
        console.log("Setting handler for Exit");
        this._optionsWindow.setHandler('exit', this.commandExit.bind(this));
    };
    
    Window_Options.prototype.processOk = function() {
        var index = this.index();
        var symbol = this.commandSymbol(index);
        
        console.log("Selected command:", symbol);  // This should print the command being selected
    
        if (symbol === "exit") {
            this.playOkSound();
            this.updateInputData();
            this.deactivate();
            this.callHandler(symbol);
        } else {
            this.changeValue(symbol, !this.getConfigValue(symbol));
        }
    };
    // Define the "Exit" command action
    Scene_Options.prototype.commandExit = function() {
        console.log("Exit button pressed");  // This should print when the Exit button is pressed
    
        if (SceneManager._scene instanceof Scene_Menu) {
            // If the current scene is the in-game menu, just go back to the previous scene (in-game)
            SceneManager.pop();
        } else if (SceneManager._scene instanceof Scene_Title) {
            // If the current scene is the title screen, go back to the title screen
            SceneManager.goto(Scene_Title);
        } else {
            // In any other case (like if we're in-game but not in the menu), pop the scene stack
            SceneManager.pop();
        }
    };    
})();
