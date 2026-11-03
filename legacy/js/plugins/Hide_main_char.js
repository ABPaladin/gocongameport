Scene_Menu.prototype.create = function() {
    Scene_MenuBase.prototype.create.call(this);
    this.createCommandWindow();
    this.createGoldWindow();
    // Comment out the following line to hide the status window
    // this.createStatusWindow();
};
Scene_Menu.prototype.createCommandWindow = function() {
    this._commandWindow = new Window_MenuCommand(0, 0);
    this._commandWindow.setHandler('item',      this.commandItem.bind(this));
    this._commandWindow.setHandler('options',   this.commandOptions.bind(this));
    this._commandWindow.setHandler('gameEnd',   this.commandGameEnd.bind(this));
    this._commandWindow.setHandler('cancel',    this.popScene.bind(this));
    this.addWindow(this._commandWindow);

    // Center the command window
    this._commandWindow.x = (Graphics.boxWidth - this._commandWindow.width) / 2;
    this._commandWindow.y = (Graphics.boxHeight - this._commandWindow.height) / 2;
};
Scene_Menu.prototype.createGoldWindow = function() {
    this._goldWindow = new Window_Gold(0, 0);
    // this.addWindow(this._goldWindow);
};
