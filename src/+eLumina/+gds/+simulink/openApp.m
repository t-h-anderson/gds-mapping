function openApp(callbackInfo)
    %OPENAPP Open the GDS Mapping app for the active Simulink model.

    arguments
        callbackInfo
    end

    modelPath = eLumina.gds.simulink.currentModelPath(callbackInfo);
    if modelPath == ""
        eLumina.gds.app.MappingView.publishWarning( ...
            "Unable to resolve the current model file.", ...
            Identifier="eLumina:gds:simulink:noModelPath");
        return
    end

    [view, hasView] = eLumina.gds.app.MappingView.currentView();
    if hasView
        view.loadModel(modelPath);
        view.show();
        return
    end

    eLumina.gds.launch(ModelPath=modelPath);
end
