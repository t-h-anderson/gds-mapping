function modelName = currentModelName(callbackInfo)
    %CURRENTMODELNAME Resolve the active model from Simulink callback info.

    arguments
        callbackInfo
    end

    modelName = "";
    try
        modelName = string(callbackInfo.model.Name);
        return
    catch
        % Rich and legacy context menu callbacks expose different shapes.
    end

    target = eLumina.gds.simulink.contextTarget(callbackInfo);
    if target.BlockPath == ""
        return
    end

    try
        modelName = string(bdroot(char(target.BlockPath)));
    catch
        % A non-block callback target cannot be resolved to a model root.
        modelName = "";
    end
end
