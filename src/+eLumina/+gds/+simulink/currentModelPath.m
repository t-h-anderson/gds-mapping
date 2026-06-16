function modelPath = currentModelPath(callbackInfo)
    %CURRENTMODELPATH Resolve the model file from Simulink callback info.

    arguments
        callbackInfo
    end

    modelName = eLumina.gds.simulink.currentModelName(callbackInfo);
    if modelName == ""
        modelPath = "";
        return
    end

    try
        modelPath = string(get_param(char(modelName), "FileName"));
    catch
        % Some callback shapes identify objects without an owning model.
        modelPath = "";
    end
end
