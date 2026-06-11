function linkedSignalPaths = traceSignalLinks(modelName, signals)
    %TRACESIGNALLINKS Trace extracted output signals to extracted input signals.
    %
    %   linkedSignalPaths = traceSignalLinks(modelName, signals)
    %
    %   Returns a string array parallel to signals. Only output signals
    %   with a direct Simulink wiring path to another extracted signal are
    %   populated. This is used for internal Simulink-to-Simulink links
    %   such as lane-to-lane buses that are not IEC/plant mappings.

    arguments
        modelName (1,1) string
        signals (1,:) eLumina.gds.extract.SimulinkSignal
    end

    endpoints = arrayfun(@(s) s.fullPath(), signals);
    linkedSignalPaths = strings(1, numel(signals));
    for k = 1:numel(signals)
        if signals(k).PortType ~= "Outport"
            continue
        end

        [blockPath, portName] = owningBlockAndPort(modelName, signals(k));
        if blockPath == "" || portName == ""
            continue
        end

        portNum = portIndex(blockPath, "OutputPortNames", portName);
        if portNum == 0
            continue
        end

        linkedSignalPaths(k) = traceForwardEndpoint( ...
            blockPath, portNum, signals(k).BusField, endpoints, modelName);
    end
end

function [blockPath, portName] = owningBlockAndPort(modelName, signal)
    blockPath = "";
    portName = "";
    parts = split(signal.InstancePath, "/");
    if isscalar(parts)
        return
    end
    blockPath = modelName + "/" + join(parts(1:end-1), "/");
    portName = parts(end);
end

function linkedPath = traceForwardEndpoint(blockPath, portNum, field, endpoints, modelName)
    linkedPath = "";
    [dstBlocks, dstPorts] = downstreamOf(blockPath, portNum);
    if isempty(dstBlocks)
        return
    end

    candidates = strings(1, 0);
    for k = 1:numel(dstBlocks)
        candidate = traceForwardDestination( ...
            dstBlocks(k), dstPorts(k), field, endpoints, modelName);
        if candidate == "" || any(candidates == candidate)
            continue
        end
        candidates(end+1) = candidate; %#ok<AGROW>
    end

    if isempty(candidates)
        return
    end
    if numel(candidates) > 1
        error("eLumina:gds:extract:ambiguousSignalLink", ...
            "Signal '%s' fans out to multiple extracted signals: %s", ...
            blockPath, strjoin(candidates, ", "));
    end
    linkedPath = candidates(1);
end

function linkedPath = traceForwardDestination(dstBlock, dstPort, field, endpoints, modelName)
    linkedPath = "";
    endpoint = endpointAtInput(dstBlock, dstPort, field, endpoints, modelName);
    if endpoint ~= ""
        linkedPath = endpoint;
        return
    end

    switch blockType(dstBlock)
        case "BusSelector"
            [nextPort, nextField] = busSelectorTraceFwd(dstBlock, field);
            if nextPort ~= 0
                linkedPath = traceForwardEndpoint( ...
                    dstBlock, nextPort, nextField, endpoints, modelName);
            end
        case "BusCreator"
            [nextPort, nextField] = busCreatorTraceFwd(dstBlock, dstPort, field);
            if nextPort ~= 0
                linkedPath = traceForwardEndpoint( ...
                    dstBlock, nextPort, nextField, endpoints, modelName);
            end
    end
end

function endpoint = endpointAtInput(blockPath, portNum, field, endpoints, modelName)
    endpoint = "";
    switch blockType(blockPath)
        case "ModelReference"
            portNames = eLumina.gds.extract.portNameList( ...
                get_param(char(blockPath), "InputPortNames"));
            if portNum > numel(portNames)
                return
            end
            candidate = relativeBlockPath(blockPath, modelName) + "/" + portNames(portNum);
        case "Inport"
            candidate = string(get_param(char(blockPath), "Name"));
        otherwise
            return
    end

    candidate = qualifyField(candidate, field);
    if any(endpoints == candidate)
        endpoint = candidate;
    end
end

function relPath = relativeBlockPath(blockPath, modelName)
    prefix = modelName + "/";
    blockPath = string(blockPath);
    if startsWith(blockPath, prefix)
        relPath = extractAfter(blockPath, prefix);
    else
        relPath = string(get_param(char(blockPath), "Name"));
    end
end

function n = portIndex(blockPath, prop, portName)
    names = eLumina.gds.extract.portNameList(get_param(char(blockPath), char(prop)));
    n = find(names == portName, 1);
    if isempty(n)
        n = 0;
    end
end

function [dstBlock, dstPort] = downstreamOf(blockPath, portNum)
    dstBlock = string.empty(1, 0);
    dstPort = zeros(1, 0);
    ph = get_param(char(blockPath), "PortHandles");
    if portNum > numel(ph.Outport)
        return
    end
    line = get_param(ph.Outport(portNum), "Line");
    if line == -1
        return
    end
    dp = get_param(line, "DstPortHandle");
    dp = dp(dp ~= -1);
    if isempty(dp)
        return
    end
    dstBlock = strings(1, numel(dp));
    dstPort = zeros(1, numel(dp));
    for i = 1:numel(dp)
        dstBlock(i) = string(get_param(dp(i), "Parent"));
        dstPort(i) = get_param(dp(i), "PortNumber");
    end
end

function [nextPort, nextField] = busSelectorTraceFwd(blockPath, field)
    nextPort = 0;
    nextField = "";

    [head, tail] = splitTopField(field);
    if head == ""
        return
    end

    names = split(string(get_param(char(blockPath), "OutputSignals")), ",");
    names = strip(names);
    names = names(names ~= "");
    idx = find(names == head, 1);
    if isempty(idx)
        return
    end

    nextPort = idx;
    nextField = tail;
end

function [nextPort, nextField] = busCreatorTraceFwd(blockPath, dstPort, field)
    nextPort = 0;
    nextField = "";

    topFields = busCreatorTopFields(blockPath);
    if dstPort > numel(topFields)
        return
    end

    nextPort = 1;
    nextField = qualifyField(topFields(dstPort), field);
end

function fields = busCreatorTopFields(blockPath)
    fields = string.empty(1, 0);
    busName = busObjectName(string(get_param(char(blockPath), "OutDataTypeStr")));
    if busName == ""
        return
    end

    dd = openDataDictionaryForModel(string(bdroot(char(blockPath))));
    if isempty(dd)
        return
    end

    try
        section = getSection(dd, "Design Data");
        entry = getEntry(section, char(busName));
        bus = getValue(entry);
    catch
        return
    end
    if ~isa(bus, "Simulink.Bus")
        return
    end

    fields = strings(1, numel(bus.Elements));
    for k = 1:numel(bus.Elements)
        fields(k) = string(bus.Elements(k).Name);
    end
end

function dd = openDataDictionaryForModel(modelName)
    dd = Simulink.data.Dictionary.empty;
    ddName = string(get_param(char(modelName), "DataDictionary"));
    if ddName == ""
        return
    end

    ddPath = ddName;
    if ~isfile(ddPath)
        fileName = string(get_param(char(modelName), "FileName"));
        if fileName ~= ""
            candidate = fullfile(fileparts(fileName), ddName);
            if isfile(candidate)
                ddPath = string(candidate);
            end
        end
    end

    try
        dd = Simulink.data.dictionary.open(char(ddPath));
    catch
        dd = Simulink.data.Dictionary.empty;
    end
end

function name = busObjectName(dataType)
    name = "";
    dataType = strip(string(dataType));
    if startsWith(dataType, "Bus:")
        name = strip(extractAfter(dataType, "Bus:"));
    end
end

function [head, tail] = splitTopField(field)
    head = "";
    tail = "";
    parts = split(string(field), ".");
    parts = parts(parts ~= "");
    if isempty(parts)
        return
    end
    head = parts(1);
    if numel(parts) > 1
        tail = strjoin(parts(2:end), ".");
    end
end

function fullName = qualifyField(prefix, name)
    if prefix == ""
        fullName = name;
    elseif name == ""
        fullName = prefix;
    else
        fullName = prefix + "." + name;
    end
end

function bt = blockType(blockPath)
    bt = string(get_param(char(blockPath), "BlockType"));
end
