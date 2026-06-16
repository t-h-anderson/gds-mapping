function plantSig = traceToPlant(modelName, signal)
    %TRACETOPLANT Trace a controller-side leaf signal to its plant origin.
    %
    %   plantSig = traceToPlant(modelName, signal)
    %
    %   Walks the wires from a controller-facing signal to its plant-side
    %   origin. Inputs trace backward, outputs trace forward. Traversal
    %   crosses organisational Subsystem boundaries, ModelReference
    %   boundaries, Bus Selector / Bus Creator blocks, and translator
    %   MATLAB Function blocks.
    %
    %   Returns an empty PlantSignal when the signal has no plant-side
    %   equivalent. Only simple field-to-field translators are followed.

    arguments
        modelName (1,1) string
        signal (1,1) eLumina.gds.extract.SimulinkSignal
    end

    topModelName = modelName;
    cleanupPath = ensureModelFolderOnPath(topModelName); %#ok<NASGU>

    parts = split(signal.InstancePath, "/");
    if isscalar(parts)
        plantSig = eLumina.gds.extract.PlantSignal( ...
            signal.InstancePath, BusField = signal.BusField);
        return
    end

    blockPath = modelName + "/" + join(parts(1:end-1), "/");
    portName = parts(end);
    refStack = string.empty(1, 0);

    if signal.PortType == "Inport"
        portNum = portIndex(blockPath, "InputPortNames", portName);
        [plantSig, ok] = traceBack( ...
            blockPath, portNum, signal.BusField, refStack, topModelName);
    else
        portNum = portIndex(blockPath, "OutputPortNames", portName);
        [plantSig, ok] = traceFwd( ...
            blockPath, portNum, signal.BusField, refStack, topModelName);
    end

    if ~ok
        plantSig = eLumina.gds.extract.PlantSignal.empty(1, 0);
    end
end

function n = portIndex(blockPath, prop, portName)
    names = eLumina.gds.extract.portNameList(get_param(char(blockPath), char(prop)));
    n = find(names == portName, 1);
    if isempty(n)
        n = 0;
    end
end

function [plantSig, ok] = traceBack(blockPath, portNum, field, refStack, topModelName)
    plantSig = eLumina.gds.extract.PlantSignal.empty(1, 0);
    ok = false;
    if portNum == 0
        return
    end

    [srcBlock, srcPort] = upstreamOf(blockPath, portNum);
    if srcBlock == ""
        return
    end

    bt = blockType(srcBlock);
    switch bt
        case "Inport"
            [plantSig, ok] = traceBackThroughInport( ...
                srcBlock, field, refStack, topModelName);
            return
        case "ModelReference"
            [plantSig, ok] = traceBackThroughModelReference( ...
                srcBlock, srcPort, field, refStack, topModelName);
            return
        case "BusSelector"
            [nextPort, nextField] = busSelectorTraceBack(srcBlock, srcPort, field);
            if nextPort == 0
                return
            end
            [plantSig, ok] = traceBack( ...
                srcBlock, nextPort, nextField, refStack, topModelName);
            return
        case "BusCreator"
            [nextPort, nextField] = busCreatorTraceBack(srcBlock, field);
            if nextPort == 0
                return
            end
            [plantSig, ok] = traceBack( ...
                srcBlock, nextPort, nextField, refStack, topModelName);
            return
        case "From"
            gotoBlock = gotoBlockForFrom(srcBlock);
            if gotoBlock == ""
                return
            end
            [plantSig, ok] = traceBack( ...
                gotoBlock, 1, field, refStack, topModelName);
            return
    end

    if isMFB(srcBlock)
        m = mfbFieldMap(srcBlock);
        if ~isKey(m, field)
            return
        end
        [plantSig, ok] = traceBack( ...
            srcBlock, 1, m(field), refStack, topModelName);
        return
    end

    [plantSig, ok] = terminal(srcBlock, srcPort, "Outport", field);
end

function [plantSig, ok] = traceFwd(blockPath, portNum, field, refStack, topModelName)
    plantSig = eLumina.gds.extract.PlantSignal.empty(1, 0);
    ok = false;
    if portNum == 0
        return
    end

    [dstBlocks, dstPorts] = downstreamOf(blockPath, portNum);
    if isempty(dstBlocks)
        return
    end

    if isscalar(dstBlocks)
        [plantSig, ok] = traceFwdToDestination( ...
            dstBlocks(1), dstPorts(1), field, refStack, topModelName);
        return
    end

    [plantSig, ok] = resolveForwardBranches( ...
        blockPath, dstBlocks, dstPorts, field, refStack, topModelName);
end

function [plantSig, ok] = resolveForwardBranches(blockPath, dstBlocks, dstPorts, field, refStack, topModelName)
    plantSig = eLumina.gds.extract.PlantSignal.empty(1, 0);
    ok = false;
    candidatePaths = string.empty(1, 0);
    candidate = eLumina.gds.extract.PlantSignal.empty(1, 0);
    for i = 1:numel(dstBlocks)
        [nextSig, nextOk] = traceFwdToDestination( ...
            dstBlocks(i), dstPorts(i), field, refStack, topModelName);
        if ~nextOk
            continue
        end
        nextPath = nextSig.fullPath();
        if any(candidatePaths == nextPath)
            continue
        end
        candidatePaths(end+1) = nextPath; %#ok<AGROW>
        candidate = nextSig;
    end

    if isempty(candidatePaths)
        return
    end
    if numel(candidatePaths) > 1
        error("eLumina:gds:extract:ambiguousTrace", ...
            "Signal '%s' fans out to multiple terminals: %s", ...
            blockPath, strjoin(candidatePaths, ", "));
    end

    plantSig = candidate;
    ok = true;
end

function [plantSig, ok] = traceFwdToDestination(dstBlock, dstPort, field, refStack, topModelName)
    plantSig = eLumina.gds.extract.PlantSignal.empty(1, 0);
    ok = false;

    bt = blockType(dstBlock);
    switch bt
        case "Outport"
            [plantSig, ok] = traceFwdThroughOutport( ...
                dstBlock, field, refStack, topModelName);
            return
        case "ModelReference"
            [plantSig, ok] = traceFwdThroughModelReference( ...
                dstBlock, dstPort, field, refStack, topModelName);
            return
        case "BusSelector"
            [nextPort, nextField] = busSelectorTraceFwd(dstBlock, field);
            if nextPort == 0
                return
            end
            [plantSig, ok] = traceFwd( ...
                dstBlock, nextPort, nextField, refStack, topModelName);
            return
        case "BusCreator"
            [nextPort, nextField] = busCreatorTraceFwd(dstBlock, dstPort, field);
            if nextPort == 0
                return
            end
            [plantSig, ok] = traceFwd( ...
                dstBlock, nextPort, nextField, refStack, topModelName);
            return
        case "Goto"
            fromBlocks = fromBlocksForGoto(dstBlock);
            [plantSig, ok] = resolveForwardSources( ...
                dstBlock, fromBlocks, field, refStack, topModelName);
            return
    end

    if isMFB(dstBlock)
        m = mfbFieldMap(dstBlock);
        outField = reverseLookup(m, field);
        if outField == ""
            return
        end
        [plantSig, ok] = traceFwd( ...
            dstBlock, 1, outField, refStack, topModelName);
        return
    end

    [plantSig, ok] = terminal(dstBlock, dstPort, "Inport", field);
end

function [plantSig, ok] = resolveForwardSources(blockPath, srcBlocks, field, refStack, topModelName)
    plantSig = eLumina.gds.extract.PlantSignal.empty(1, 0);
    ok = false;
    candidatePaths = string.empty(1, 0);
    candidate = eLumina.gds.extract.PlantSignal.empty(1, 0);
    for i = 1:numel(srcBlocks)
        [nextSig, nextOk] = traceFwd( ...
            srcBlocks(i), 1, field, refStack, topModelName);
        if ~nextOk
            continue
        end
        nextPath = nextSig.fullPath();
        if any(candidatePaths == nextPath)
            continue
        end
        candidatePaths(end+1) = nextPath; %#ok<AGROW>
        candidate = nextSig;
    end

    if isempty(candidatePaths)
        return
    end
    if numel(candidatePaths) > 1
        error("eLumina:gds:extract:ambiguousTrace", ...
            "Signal '%s' fans out to multiple terminals: %s", ...
            blockPath, strjoin(candidatePaths, ", "));
    end

    plantSig = candidate;
    ok = true;
end

function [plantSig, ok] = traceBackThroughInport(portBlock, field, refStack, topModelName)
    plantSig = eLumina.gds.extract.PlantSignal.empty(1, 0);
    ok = false;

    if isTopModelRootPort(portBlock, topModelName)
        [plantSig, ok] = terminal(portBlock, 1, "Inport", field);
        return
    end

    if isModelRootPort(portBlock)
        if isempty(refStack)
            return
        end
        portNum = blockPortNumber(portBlock);
        [plantSig, ok] = traceBack( ...
            refStack(end), portNum, field, refStack(1:end-1), topModelName);
        return
    end

    [parentSub, p] = crossBoundary(portBlock);
    [plantSig, ok] = traceBack(parentSub, p, field, refStack, topModelName);
end

function [plantSig, ok] = traceFwdThroughOutport(portBlock, field, refStack, topModelName)
    plantSig = eLumina.gds.extract.PlantSignal.empty(1, 0);
    ok = false;

    if isTopModelRootPort(portBlock, topModelName)
        [plantSig, ok] = terminal(portBlock, 1, "Outport", field);
        return
    end

    if isModelRootPort(portBlock)
        if isempty(refStack)
            return
        end
        portNum = blockPortNumber(portBlock);
        [plantSig, ok] = traceFwd( ...
            refStack(end), portNum, field, refStack(1:end-1), topModelName);
        return
    end

    [parentSub, p] = crossBoundary(portBlock);
    [plantSig, ok] = traceFwd(parentSub, p, field, refStack, topModelName);
end

function [plantSig, ok] = traceBackThroughModelReference(refBlock, portNum, field, refStack, topModelName)
    plantSig = eLumina.gds.extract.PlantSignal.empty(1, 0);
    ok = false;

    refModel = loadReferencedModel(refBlock);
    innerOutport = rootPortBlock(refModel, "Outport", portNum);
    if innerOutport == ""
        return
    end

    [plantSig, ok] = traceBack( ...
        innerOutport, 1, field, [refStack, refBlock], topModelName);
end

function [plantSig, ok] = traceFwdThroughModelReference(refBlock, portNum, field, refStack, topModelName)
    plantSig = eLumina.gds.extract.PlantSignal.empty(1, 0);
    ok = false;

    refModel = loadReferencedModel(refBlock);
    innerInport = rootPortBlock(refModel, "Inport", portNum);
    if innerInport == ""
        return
    end

    [plantSig, ok] = traceFwd( ...
        innerInport, 1, field, [refStack, refBlock], topModelName);
end

function [parentSub, portNum] = crossBoundary(portBlock)
    parentSub = string(get_param(char(portBlock), "Parent"));
    portNum = blockPortNumber(portBlock);
end

function out = reverseLookup(m, inField)
    out = "";
    ks = keys(m);
    for i = 1:numel(ks)
        if m(ks(i)) == inField
            out = ks(i);
            return
        end
    end
end

function [srcBlock, srcPort] = upstreamOf(blockPath, portNum)
    srcBlock = "";
    srcPort = 0;
    ph = get_param(char(blockPath), "PortHandles");
    if portNum > numel(ph.Inport)
        return
    end
    line = get_param(ph.Inport(portNum), "Line");
    if line == -1
        return
    end
    sp = get_param(line, "SrcPortHandle");
    if sp == -1
        return
    end
    srcBlock = string(get_param(sp, "Parent"));
    srcPort = get_param(sp, "PortNumber");
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

function [nextPort, nextField] = busSelectorTraceBack(blockPath, srcPort, field)
    nextPort = 0;
    nextField = "";

    names = busSelectorOutputs(blockPath);
    if srcPort > numel(names)
        return
    end

    nextPort = 1;
    nextField = qualifyField(names(srcPort), field);
end

function [nextPort, nextField] = busSelectorTraceFwd(blockPath, field)
    nextPort = 0;
    nextField = "";

    [head, tail] = splitTopField(field);
    if head == ""
        return
    end

    names = busSelectorOutputs(blockPath);
    idx = find(names == head, 1);
    if isempty(idx)
        return
    end

    nextPort = idx;
    nextField = tail;
end

function names = busSelectorOutputs(blockPath)
    names = split(string(get_param(char(blockPath), "OutputSignals")), ",");
    names = strip(names);
    names = names(names ~= "");
end

function [nextPort, nextField] = busCreatorTraceBack(blockPath, field)
    nextPort = 0;
    nextField = "";

    [head, tail] = splitTopField(field);
    if head == ""
        return
    end

    topFields = busCreatorTopFields(blockPath);
    idx = find(topFields == head, 1);
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
    fields = busTopLevelFields(busName, string(bdroot(char(blockPath))));
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

function fields = busTopLevelFields(busName, modelRoot)
    fields = string.empty(1, 0);
    dd = openDataDictionaryForModel(modelRoot);
    if isempty(dd)
        return
    end

    bus = resolveBus(busName, dd);
    if isempty(bus)
        return
    end

    fields = strings(1, numel(bus.Elements));
    for i = 1:numel(bus.Elements)
        fields(i) = string(bus.Elements(i).Name);
    end
end

function dd = openDataDictionaryForModel(modelName)
    dd = Simulink.data.Dictionary.empty;
    ddName = string(get_param(char(modelName), "DataDictionary"));
    if ddName == ""
        return
    end

    ddPath = resolveDictionaryPath(ddName, modelName);
    try
        dd = Simulink.data.dictionary.open(char(ddPath));
    catch
        dd = Simulink.data.Dictionary.empty;
    end
end

function ddPath = resolveDictionaryPath(ddName, modelName)
    ddPath = ddName;
    if isfile(ddPath)
        return
    end

    fileName = string(get_param(char(modelName), "FileName"));
    if fileName == ""
        return
    end

    candidate = fullfile(fileparts(fileName), ddName);
    if isfile(candidate)
        ddPath = string(candidate);
    end
end

function bus = resolveBus(busName, dd)
    try
        section = getSection(dd, "Design Data");
        entry = getEntry(section, char(busName));
        bus = getValue(entry);
    catch
        bus = [];
        return
    end

    if ~isa(bus, "Simulink.Bus")
        bus = [];
    end
end

function name = busObjectName(dataType)
    name = "";
    dataType = strip(string(dataType));
    if startsWith(dataType, "Bus:")
        name = strip(extractAfter(dataType, "Bus:"));
    end
end

function [plantSig, ok] = terminal(blockPath, portNum, portType, field)
    plantSig = eLumina.gds.extract.PlantSignal.empty(1, 0);
    ok = false;

    bt = blockType(blockPath);
    blockName = string(get_param(char(blockPath), "Name"));
    switch bt
        case "SubSystem"
            portName = subsystemPortName(blockPath, portType, portNum);
            instancePath = blockName + "/" + portName;
        case {"Constant", "Inport", "Outport"}
            instancePath = blockName;
        otherwise
            return
    end

    plantSig = eLumina.gds.extract.PlantSignal( ...
        instancePath, BusField = field);
    ok = true;
end

function bt = blockType(blockPath)
    bt = string(get_param(char(blockPath), "BlockType"));
end

function tf = isMFB(blockPath)
    tf = false;
    try
        tf = string(get_param(char(blockPath), "SFBlockType")) == "MATLAB Function";
    catch
    end
end

function m = mfbFieldMap(blockPath)
    m = eLumina.gds.extract.parseMFBScript(readMFBScript(blockPath));
end

function refModel = loadReferencedModel(refBlock)
    refModel = string(get_param(char(refBlock), "ModelName"));
    if refModel ~= "" && ~bdIsLoaded(char(refModel))
        load_system(char(refModel));
    end
end

function gotoBlock = gotoBlockForFrom(fromBlock)
    gotoBlock = "";
    try
        gotoInfo = get_param(char(fromBlock), "GotoBlock");
    catch
        return
    end

    if isstruct(gotoInfo)
        if isfield(gotoInfo, "name") && string(gotoInfo.name) ~= ""
            gotoBlock = string(gotoInfo.name);
            return
        end
        if isfield(gotoInfo, "handle") && gotoInfo.handle ~= -1
            gotoBlock = string(getfullname(gotoInfo.handle));
        end
    end
end

function fromBlocks = fromBlocksForGoto(gotoBlock)
    fromBlocks = string.empty(1, 0);
    tag = string(get_param(char(gotoBlock), "GotoTag"));
    if tag == ""
        return
    end

    candidates = string(find_system(char(bdroot(char(gotoBlock))), ...
        "LookUnderMasks", "all", ...
        "BlockType", "From", ...
        "GotoTag", char(tag)));
    if isempty(candidates)
        return
    end

    gotoHandle = get_param(char(gotoBlock), "Handle");
    matches = false(size(candidates));
    for i = 1:numel(candidates)
        matches(i) = fromResolvesToGoto(candidates(i), gotoBlock, gotoHandle);
    end
    fromBlocks = candidates(matches);
end

function tf = fromResolvesToGoto(fromBlock, gotoBlock, gotoHandle)
    tf = false;
    try
        gotoInfo = get_param(char(fromBlock), "GotoBlock");
    catch
        return
    end

    if ~isstruct(gotoInfo)
        return
    end
    if isfield(gotoInfo, "handle") && gotoInfo.handle == gotoHandle
        tf = true;
        return
    end
    if isfield(gotoInfo, "name") && string(gotoInfo.name) == gotoBlock
        tf = true;
    end
end

function blockPath = rootPortBlock(modelName, blockType, portNum)
    blockPath = "";
    blocks = find_system(char(modelName), "SearchDepth", 1, ...
        "BlockType", char(blockType));
    for i = 1:numel(blocks)
        candidate = string(blocks{i});
        if blockPortNumber(candidate) == portNum
            blockPath = candidate;
            return
        end
    end
end

function n = blockPortNumber(blockPath)
    n = str2double(string(get_param(char(blockPath), "Port")));
    if isnan(n)
        n = 1;
    end
end

function tf = isModelRootPort(blockPath)
    parent = string(get_param(char(blockPath), "Parent"));
    tf = parent == string(bdroot(char(blockPath)));
end

function tf = isTopModelRootPort(blockPath, topModelName)
    tf = isModelRootPort(blockPath) && string(bdroot(char(blockPath))) == topModelName;
end

function cleanupPath = ensureModelFolderOnPath(modelName)
    cleanupPath = [];
    try
        fileName = string(get_param(char(modelName), "FileName"));
    catch
        return
    end
    if fileName == ""
        return
    end

    folder = string(fileparts(fileName));
    if folder ~= "" && ~ismember(char(folder), strsplit(path, pathsep))
        addpath(char(folder));
        cleanupPath = onCleanup(@() rmpath(char(folder)));
    end
end

function script = readMFBScript(blockPath)
    script = "";
    try
        cfg = Simulink.MATLABFunctionConfiguration(char(blockPath));
        script = string(cfg.FunctionScript);
    catch
    end
    if strlength(script) > 0
        return
    end

    try
        blockName = string(get_param(char(blockPath), "Name"));
        charts = sfroot().find("-isa", "Stateflow.EMChart");
        for i = 1:numel(charts)
            p = string(charts(i).Path);
            if p == string(blockPath)
                script = string(charts(i).Script);
                return
            end
        end

        rootName = string(bdroot(char(blockPath)));
        for i = 1:numel(charts)
            p = string(charts(i).Path);
            if chartRoot(p) == rootName && endsWith(p, "/" + blockName)
                script = string(charts(i).Script);
                return
            end
        end
    catch
    end
end

function rootName = chartRoot(chartPath)
    parts = split(string(chartPath), "/");
    rootName = parts(1);
end

function name = subsystemPortName(blockPath, portType, portNum)
    inner = find_system(char(blockPath), "SearchDepth", 1, ...
        "BlockType", char(portType), "Port", num2str(portNum));
    if isempty(inner)
        name = portType + string(portNum);
    else
        name = string(get_param(inner{1}, "Name"));
    end
end
