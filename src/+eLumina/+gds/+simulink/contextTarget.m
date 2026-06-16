function target = contextTarget(callbackInfo)
    %CONTEXTTARGET Resolve the Simulink block/port represented by callback info.

    arguments
        callbackInfo
    end

    target = emptyTarget();

    obj = selectedObject(callbackInfo);
    if isempty(obj)
        return
    end

    handle = objectHandle(obj);
    if isempty(handle) || handle == -1
        return
    end

    target = targetFromHandle(handle);
end

function obj = selectedObject(callbackInfo)
    obj = [];
    try
        obj = callbackInfo.getSelection();
    catch
        % Some callback contexts expose only uiObject.
    end

    if ~isempty(obj)
        return
    end

    try
        obj = callbackInfo.uiObject;
    catch
        % Leave obj empty when the context has no selected object.
        obj = [];
    end
end

function handle = objectHandle(obj)
    handle = [];
    if isempty(obj)
        return
    end

    try
        if numel(obj) > 1
            obj = obj(1);
        end
        handle = obj.Handle;
        return
    catch
        % Fall back for numeric-handle callback objects.
    end

    try
        handle = double(obj);
    catch
        % Non-Simulink callback objects are ignored by this menu.
        handle = [];
    end
end

function target = targetFromHandle(handle)
    target = emptyTarget();

    try
        objectType = string(get_param(handle, "Type"));
    catch
        % Invalid or non-Simulink handles are ignored by this menu.
        return
    end

    switch objectType
        case "block"
            target = targetFromBlock(handle);
        case "port"
            target = targetFromPort(handle);
        case "line"
            target = targetFromLine(handle);
        otherwise
    end
end

function target = targetFromBlock(handle)
    target = emptyTarget();
    target.BlockPath = string(getfullname(handle));

    try
        blockType = string(get_param(handle, "BlockType"));
    catch
        % Block-like callback handles can still miss BlockType.
        return
    end

    if blockType == "Inport" || blockType == "Outport"
        target.PortName = string(get_param(handle, "Name"));
        target.PortType = blockType;
    end
end

function target = targetFromPort(handle)
    blockPath = string(get_param(handle, "Parent"));
    portNumber = str2double(string(get_param(handle, "PortNumber")));
    portType = lower(string(get_param(handle, "PortType")));

    target = emptyTarget();
    target.BlockPath = blockPath;
    target.PortName = portNameForBlockPort(blockPath, portType, portNumber);
    target.PortType = simulinkSignalPortType(portType);
end

function target = targetFromLine(handle)
    portHandle = -1;
    try
        portHandle = get_param(handle, "SrcPortHandle");
    catch
        % Lines without a source port cannot map to a result row.
    end

    if portHandle == -1
        target = emptyTarget();
        return
    end

    target = targetFromPort(portHandle);
end

function name = portNameForBlockPort(blockPath, portType, portNumber)
    name = "";
    if portNumber <= 0
        return
    end

    blockType = string(get_param(char(blockPath), "BlockType"));
    if blockType == "ModelReference"
        names = modelReferencePortNames(blockPath, portType);
        if portNumber <= numel(names)
            name = names(portNumber);
        end
        return
    end

    if blockType == "Inport" || blockType == "Outport"
        name = string(get_param(char(blockPath), "Name"));
    end
end

function names = modelReferencePortNames(blockPath, portType)
    if portType == "inport"
        paramName = "InputPortNames";
    elseif portType == "outport"
        paramName = "OutputPortNames";
    else
        names = strings(1, 0);
        return
    end

    names = eLumina.gds.extract.portNameList( ...
        get_param(char(blockPath), char(paramName)));
end

function portType = simulinkSignalPortType(portType)
    if portType == "inport"
        portType = "Inport";
    elseif portType == "outport"
        portType = "Outport";
    else
        portType = "";
    end
end

function target = emptyTarget()
    target = struct( ...
        BlockPath="", ...
        PortName="", ...
        PortType="");
end
