// su2rad.gridImport.js
// . 
// functions used in importCanvas.html
// .
// Copyright (c) 2009 Thomas Bleicher


su2rad.dialog.weatherdata = function () {
    this.gCanvas = null;
};

su2rad.dialog.weatherdata.initPage = function () {
    // set up canvas
    document.getElementById("messagearea").value = '';
    this.gCanvas = new su2rad.canvas.GridCanvas();
    this.gCanvas.setCanvasId('cv');
    this.evaluateSketchup(); 
    su2rad.dialog.evaluateSketchup = this.evaluateSketchup
    this.updateUI();
}

su2rad.dialog.weatherdata.onResizeCanvas = function () {
    try {
        var newW = document.getElementById("canvasContainer").clientWidth;
        var newH = document.getElementById("canvasContainer").clientHeight;
        document.getElementById("cv").width = newW;
        document.getElementById("cv").height = newH;
        this.gCanvas.draw()
    } catch (e) {
        logError(e)
    }
}

su2rad.dialog.weatherdata.evaluateSketchup = function () {
    log.debug("weatherdata.evaluateSketchup() su2rad.SKETCHUP='" + su2rad.SKETCHUP + "'")
    document.getElementById("loadFileWarning").style.display='';
    document.getElementById("loadFileSUDiv").style.display='none';
    document.getElementById("graphOptions").style.display='none';
    document.getElementById("statsDiv").style.display='none';
    document.getElementById("useEPWInSUDiv").style.display='none';
    // show 'load file' button depending on browser and Sketchup
    // var idomFileList = document.getElementById("loadFileSelection").files;
    // log.debug("DEBUG: idomFileList='" + idomFileList + "' typeof=" + typeof(idomFileList));
    if (su2rad.SKETCHUP == true) {
        log.info("Sketchup available");
        document.getElementById("loadFileWarning").style.display='none';
        document.getElementById("loadFileSUDiv").style.display='';
        document.getElementById("graphOptions").style.display='';
        document.getElementById("statsDiv").style.display='';
    } else if (su2rad.NSIDOM == true)
        // this is Firefox -> enable direct load of file text
        log.info("nsIDOMFileList available");
        document.getElementById("loadFileWarning").style.display='none';
        document.getElementById("loadFileSelectionDiv").style.display=''; 
        document.getElementById("graphOptions").style.display='';
        document.getElementById("statsDiv").style.display='';
    } else {
        // this is not Firefox/Mozilla
        log.warn("Sketchup and nsIDOMFileList not available - no functionality");
        log.debug("broser: " + su2rad.BROWSER);
    }
}

su2rad.dialog.weatherdata.importEPWToSketchup = function () {
    var filename = this.gCanvas.array.filename;
    if (filename != "") {
        log.debug("TEST: importing file '" + filename + "'");
        if (su2rad.SKETCHUP == true) {
            window.location = 'skp:setEPWFilePathFromDialog@' + encodeURI(filename);
        }
    }
}

su2rad.dialog.weatherdata.loadFileIDOM = function () {
    log.debug("loadFileIDOM()")
    try {
        // access file contents via nsIDOMFileList (FireFox, Mozilla)
        var files = document.getElementById("loadFileSelection").files;
        var text = files.item(0).getAsText('UTF-8');
        var filename = files.item(0).fileName
        this.parseFileText(text, filename)
    } catch (e) {
        logError(e)
        alert(e)
    }
}

su2rad.dialog.weatherdata.loadFileSU = function (path) {
    log.debug("loadFileSU()")
    // function to be called with encoded text from SU
    try {
        su2rad.dialog.loadFileCallback = su2rad.dialog.weatherdata._loadFileSU
        // function to be called with fielpath in JS
        su2rad.dialog.fileSelector.callback = su2rad.dialog.loadTextFile; 
        log.debug("starting file selector ... ")
        su2rad.dialog.fileSelector.show(path)
    } catch (e) {
        logError(e)
    }
}

su2rad.dialog.weatherdata._loadFileSU = function (text) {
    // function called from SU with escaped javascript string
    log.debug("_loadFileSU: received " + text.length + " bytes")
    // text received from WeatherDataImportDialog.loadTextFile 
    var lines = text.split("\n")
    log.debug("_loadFileSU: lines=" + lines.length)
    var filename = su2rad.dialog.fileSelector.getFilepath();
    try {
        // will be called as method of su2rad.dialog => this.parseFileText does not work!
        su2rad.dialog.weatherdata.parseFileText(text, filename);
    } catch (e) {
        logError(e)
    }
}

function logError(e) {
    log.error(e.toString())
    log.error("e.name " + e.name)
    log.error("e.message " + e.message)
    log.error("e.fileName " + e.fileName)
    log.error("e.lineNumber " + e.lineNumber)
}

su2rad.dialog.weatherdata.parseFileText = function (text, filename) {
    log.debug("parseFileText(): received " + text.length + " bytes")
    if (text == "") {
        return
    }
    //document.getElementById('messagearea').value = text;
    var gArray = new su2rad.grid.GridArray();
    gArray.parseText(text);
    
    if (gArray.empty() == false) {
        if (filename != null) {
            gArray.filename = filename;
            //this.setLabelFromFilename(filename)
        }
        this.setGridArray(gArray);
    }
}

su2rad.dialog.weatherdata.setFilename = function (filename) {
    // set new title
    var title = document.getElementById("pageTitle")
    while (title.hasChildNodes() == true) {
        title.removeChild(title.firstChild)
    }
    if (filename != "") {
        var tNode = document.createTextNode("file: " + filename);
        if (su2rad.SKETCHUP == true) {
            document.getElementById("useEPWInSUDiv").style.display='';
        }
    } else {
        var tNode = document.createTextNode("file: [simulated values]");
        document.getElementById("useEPWInSUDiv").style.display='none';
    }
    title.appendChild(tNode);
}

su2rad.dialog.weatherdata.setFileFromSketchup = function (encText,filename) {
    // function called from SU with encoded text and encoded filename
    // TODO: set fileselector root
    var text = su2rad.utils.decodeText(encText);
    filename = su2rad.utils.decodeText(filename);
    log.debug("setFileFromSketchup: " + text.length + " bytes")
    try {
        this.parseFileText(text, filename);
        // TODO: call parseFileText() with timeout
    } catch (e) {
        logError(e)
    }
}

su2rad.dialog.weatherdata.setLabelFromFilename = function (filename) {
    // extract extension for label
    var ridx = filename.lastIndexOf('.');
    if (ridx != -1) {
        var ext = filename.slice(ridx+1, filename.length);
        if ( ext != '') {
            ext = ext.toUpperCase();
            if ( ext == 'EPW') {
                
                document.getElementById("legendLabelInput").value = ext;
                this.gCanvas.setLegendLabel(ext);
            }
        }
    } else {
        this.gCanvas.setLegendLabel('');
    } 
}

su2rad.dialog.weatherdata.simulateGrid = function () {
    document.getElementById('messagearea').value = '';
    document.getElementById("graphOptions").style.display='';
    document.getElementById("statsDiv").style.display='';
    var gArray = new su2rad.grid.GridArray();
    gArray.generate();
    gArray.filename = ""
    this.setGridArray(gArray)
}

su2rad.dialog.weatherdata.setDataType = function () {
    var v = document.getElementById('weatherDataType').value;
    this.gCanvas.setDataTypeIndex( parseInt(v) );
    this.gCanvas.draw();
    this.updateUI();
    this.updateStats();
}

su2rad.dialog.weatherdata.setGridArray = function (gArray) {
    this.setFilename(gArray.filename)
    this.gCanvas.setArray(gArray);
    this.gCanvas.setLegend('right');
    this.gCanvas.setDataTypeIndex(0);
    document.getElementById('weatherDataType').selectedIndex = 0;
    this.setComment(gArray.commentLines);
    this.gCanvas.draw();
    this.updateUI();
    this.updateStats();
}

su2rad.dialog.weatherdata.setComment = function (lines) {
    try {
        // DESIGN CONDITIONS
        lines[1] = lines[1].replace(/Heating/g, "\n\tHeating");
        lines[1] = lines[1].replace(/Cooling/g, "\n\tCooling");
        lines[1] = lines[1].replace(/Extremes/g, "\n\tExtremes");
        var conditions = lines[1].split("\n")
        var values = conditions[2].split(",")
        var middle = parseInt(values.length/2)
        var newcool = values.slice(0,middle).join(",")
        newcool += "\n\t\t" + values.slice(middle,-1).join(",")
        conditions[2] = newcool;
        lines[1] = conditions.join("\n")
        // TYPICAL/EXTREME PERIODS
        var periods = lines[2].split(",")
        var nline = []
        nline.push( periods[0] + " (" + periods[1] + "):" )
        for (var i=2; i<periods.length; i+=4) {
            nline.push( "\t" + periods.slice(i,i+4).join(", ") )
        }
        lines[2] = nline.join("\n");   
        // GROUND TEMPERATURES
        lines[3] = this._splitLongLine(lines[3], ",", 70);   
        lines[5] = this._splitLongLine(lines[5], " ", 70);   
        
    } catch (e) {
        logError(e)
    }
    document.getElementById("messagearea").value = lines.join("\n\n"); 
}

su2rad.dialog.weatherdata._splitLongLine = function (line, sep, maxl) {
    var offset = 0;
    var parts = line.split(sep);
    var nline = parts[0]
    for (var i=1; i<parts.length; i++ ) {
        nline += sep;
        if ( (nline.length-offset) > maxl ) {
            nline += "\n\t";
            offset = nline.length;
        }
        nline += parts[i];
    }
    return nline;   
}

su2rad.dialog.weatherdata.setLegendLabel = function (label) {
    this.gCanvas.setLegendLabel(label)
    this.updateUI()
}

su2rad.dialog.weatherdata.setLegendLightness = function (lightness) {
    var value = parseFloat(lightness)
    if ( ! isNaN(value) ) {
        this.gCanvas.setLegendLightness(value)
    }
    this.updateUI()
}

su2rad.dialog.weatherdata.setLegendMax = function (v) {
    var value = parseFloat(v)
    if ( ! isNaN(value) ) {
        this.gCanvas.setLegendMax(value)
    }
    this.updateUI()
}

su2rad.dialog.weatherdata.setLegendMin = function (v) {
    var value = parseFloat(v)
    if ( ! isNaN(value) ) {
        this.gCanvas.setLegendMin(value)
    }
    this.updateUI()
}

su2rad.dialog.weatherdata.setLegendSteps = function (v) {
    var value = parseFloat(v)
    if ( ! isNaN(value) ) {
        this.gCanvas.setLegendSteps(value)
    }
    this.updateUI();
}

su2rad.dialog.weatherdata.updateStats = function () {
    var statsDiv = document.getElementById('statsTable');
    while (statsDiv.hasChildNodes() == true) {
        statsDiv.removeChild(statsDiv.firstChild)
    }
    var stats = this.gCanvas.array.getStatsAsText();
    for (i=0; i<stats.length; i++) {
        var k = stats[i].split(' ')[0]
        var v = stats[i].split(' ')[1]
        var label = document.createElement('span');
        var ltxt = document.createTextNode(k);
        label.appendChild(ltxt);
        var value = document.createElement('span');
        var vtxt = document.createTextNode(v);
        value.appendChild(vtxt);
        var row = document.createElement('div');
        row.appendChild(label);
        row.appendChild(value);
        statsDiv.appendChild(row);
    }
    try {
        $("#statsTable > div").attr("class", "gridRow")
        $("#statsTable > div > span:first-child").attr("class", "gridLabel")
    } catch (e) {
        log.error(e);
    }
}

su2rad.dialog.weatherdata.updateUI = function () {
    //log.debug("updateUI()")
    var opts = this.gCanvas.getLegendOptions();
    document.getElementById("legendMinInput").value = opts.minValue.toFixed(2);
    document.getElementById("legendMaxInput").value = opts.maxValue.toFixed(2);
    document.getElementById("legendStepsInput").value = opts.steps.toFixed();
    document.getElementById("legendLabelInput").value = opts.label;
    document.getElementById("legendLightnessInput").value = opts.lightness.toFixed(2);
}