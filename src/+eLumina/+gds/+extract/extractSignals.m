function signals = extractSignals(modelPath)
    %EXTRACTSIGNALS Walk a Simulink model and emit bus-leaf signals.
    %
    %   signals = eLumina.gds.extract.extractSignals(modelPath)
    %
    %   For each controller-facing ModelReference block, every port is
    %   fanned out to one SimulinkSignal per bus leaf field (read from
    %   the model's data dictionary). Scalar ports emit a single signal
    %   with BusField = "".
    %
    %   Controller-facing references are selected by block-name prefix.
    %   The default is case-insensitive "ctrl", and it can be overridden
    %   by setting controllerModelRefPrefixes in gds-config.json next to
    %   the model. Provide a comma-separated list for multiple prefixes.
    %
    %   Root-level Inports / Outports of the model itself are emitted only
    %   when the model has no controller-facing ModelReference blocks. For
    %   adapter-style models such as the DemoPlant fixture, this keeps
    %   root plumbing and intermediate referenced models out of the signal
    %   list that drives mapping.
    %
    %   Tracing through translator MATLAB Function blocks to plant-side
    %   origins is a separate concern handled by the Mapper layer.

    arguments
        modelPath (1,1) string {mustBeFile}
    end

    [folder, modelName] = fileparts(modelPath);
    folder = string(folder);
    modelName = string(modelName);

    if folder ~= "" && ~ismember(char(folder), strsplit(path, pathsep))
        addpath(char(folder));
        cleanupPath = onCleanup(@() rmpath(char(folder)));
    end

    if ~bdIsLoaded(char(modelName))
        load_system(char(modelPath));
    end

    dd = openDataDictionary(modelName, folder);
    controllerPrefixes = discoverControllerModelRefPrefixes(modelPath);

    chunks = cell(1,0);

    % Model references at any depth (controllers may be tucked inside
    % organisational subsystems). Prefer block-name prefix selection from
    % config, falling back to excluding root-plumbing references when the
    % model does not follow the naming convention.
    modelRefs = string(find_system(char(modelName), ...
        'LookUnderMasks', 'all', 'BlockType', 'ModelReference'));
    modelRefs = selectSignalModelReferences(modelRefs, modelName, controllerPrefixes);
    for k = 1:numel(modelRefs)
        chunks{end+1} = expandModelReferencePorts( ...
            modelRefs(k), modelName, dd); %#ok<AGROW>
    end

    if isempty(modelRefs)
        chunks{end+1} = collectRootPorts(modelName, "Inport");
        chunks{end+1} = collectRootPorts(modelName, "Outport");
    end

    signals = [chunks{:}];
end

function modelRefs = selectSignalModelReferences(modelRefs, modelName, controllerPrefixes)
    modelRefs = reshape(modelRefs, 1, []);
    if isempty(modelRefs)
        return
    end

    if ~isempty(controllerPrefixes)
        matchesPrefix = false(size(modelRefs));
        for k = 1:numel(modelRefs)
            matchesPrefix(k) = hasControllerPrefix(modelRefs(k), controllerPrefixes);
        end

        filtered = modelRefs(matchesPrefix);
        if ~isempty(filtered)
            modelRefs = filtered;
            return
        end
    end

    touchesRoot = false(size(modelRefs));
    for k = 1:numel(modelRefs)
        touchesRoot(k) = isDirectlyConnectedToRootPort(modelRefs(k), modelName);
    end

    filtered = modelRefs(~touchesRoot);
    if ~isempty(filtered)
        modelRefs = filtered;
    end
end

function tf = hasControllerPrefix(refBlockPath, prefixes)
    blockName = string(get_param(char(refBlockPath), 'Name'));
    tf = any(startsWith(lower(blockName), prefixes));
end

function tf = isDirectlyConnectedToRootPort(refBlockPath, modelName)
    tf = false;
    ph = get_param(char(refBlockPath), 'PortHandles');

    inports = ph.Inport(ph.Inport ~= -1);
    for k = 1:numel(inports)
        line = get_param(inports(k), 'Line');
        if line == -1
            continue
        end
        sp = get_param(line, 'SrcPortHandle');
        if sp == -1
            continue
        end
        srcBlock = string(get_param(sp, 'Parent'));
        if isRootPortBlock(srcBlock, modelName, "Inport")
            tf = true;
            return
        end
    end

    outports = ph.Outport(ph.Outport ~= -1);
    for k = 1:numel(outports)
        line = get_param(outports(k), 'Line');
        if line == -1
            continue
        end
        dp = get_param(line, 'DstPortHandle');
        dp = dp(dp ~= -1);
        for j = 1:numel(dp)
            dstBlock = string(get_param(dp(j), 'Parent'));
            if isRootPortBlock(dstBlock, modelName, "Outport")
                tf = true;
                return
            end
        end
    end
end

function tf = isRootPortBlock(blockPath, modelName, blockType)
    tf = false;
    if blockPath == ""
        return
    end
    if string(get_param(char(blockPath), 'BlockType')) ~= blockType
        return
    end
    tf = string(get_param(char(blockPath), 'Parent')) == modelName;
end

function prefixes = discoverControllerModelRefPrefixes(modelPath)
    prefixes = "ctrl";

    configPath = eLumina.gds.io.discoverConfig(string(modelPath));
    if configPath == ""
        return
    end

    cfg = eLumina.gds.io.readConfig(configPath);
    fieldName = "";
    for candidate = ["controllerModelRefPrefixes", "controllerModelRefPrefix"]
        if isfield(cfg, char(candidate))
            fieldName = candidate;
            break
        end
    end
    if fieldName == ""
        return
    end

    prefixes = splitConfigList(string(cfg.(char(fieldName))));
    if isempty(prefixes)
        prefixes = "ctrl";
    end
end

function items = splitConfigList(rawValue)
    items = split(string(rawValue), ",");
    items = lower(strip(items));
    items = items(items ~= "");
end

function dd = openDataDictionary(modelName, modelFolder)
    ddName = string(get_param(char(modelName), 'DataDictionary'));
    if ddName == ""
        dd = Simulink.data.Dictionary.empty;
        return
    end
    ddPath = resolveDictionaryPath(ddName, modelFolder);
    try
        dd = Simulink.data.dictionary.open(char(ddPath));
    catch ME
        error("eLumina:gds:extract:dataDictionaryOpenFailed", ...
            "Unable to open data dictionary '%s' for model '%s': %s", ...
            ddName, modelName, ME.message);
    end
end

function ddPath = resolveDictionaryPath(ddName, modelFolder)
    ddPath = ddName;
    if isfile(ddPath)
        return
    end
    if modelFolder ~= ""
        candidate = fullfile(modelFolder, ddName);
        if isfile(candidate)
            ddPath = string(candidate);
        end
    end
end

function leaves = expandModelReferencePorts(refBlockPath, modelName, dd)
    % Path relative to the model, e.g. "Ctrls/ctrl1" or just "ctrl1".
    refBlockName = extractAfter(refBlockPath, modelName + "/");
    inNames = eLumina.gds.extract.portNameList(get_param(char(refBlockPath), 'InputPortNames'));
    inBuses = eLumina.gds.extract.portNameList(get_param(char(refBlockPath), 'InputPortBusObjects'));
    outNames = eLumina.gds.extract.portNameList(get_param(char(refBlockPath), 'OutputPortNames'));
    outBuses = eLumina.gds.extract.portNameList(get_param(char(refBlockPath), 'OutputPortBusObjects'));

    chunks = cell(1,0);
    for j = 1:numel(inNames)
        chunks{end+1} = expandPort( ...
            refBlockName + "/" + inNames(j), "Inport", inBuses(j), dd); %#ok<AGROW>
    end
    for j = 1:numel(outNames)
        chunks{end+1} = expandPort( ...
            refBlockName + "/" + outNames(j), "Outport", outBuses(j), dd); %#ok<AGROW>
    end
    leaves = [chunks{:}];
end

function leaves = expandPort(portPath, portType, busName, dd)
    if busName == ""
        leaves = eLumina.gds.extract.SimulinkSignal( ...
            portPath, PortType = portType);
        return
    end
    if isempty(dd)
        error("eLumina:gds:extract:busExpansionUnavailable", ...
            "Cannot expand bus port '%s' because no data dictionary is available.", ...
            portPath);
    end
    fields = eLumina.gds.extract.enumerateBusFields(busName, dd);
    if isempty(fields)
        error("eLumina:gds:extract:busDefinitionNotFound", ...
            "Cannot expand bus port '%s' because bus '%s' was not found.", ...
            portPath, busName);
    end
    n = numel(fields);
    cells = cell(1, n);
    for k = 1:n
        cells{k} = eLumina.gds.extract.SimulinkSignal( ...
            portPath, PortType = portType, BusField = fields(k));
    end
    leaves = [cells{:}];
end

function ports = collectRootPorts(systemName, blockType)
    arguments
        systemName (1,1) string
        blockType (1,1) string {mustBeMember(blockType, ["Inport", "Outport"])}
    end
    blocks = find_system(char(systemName), ...
        'SearchDepth', 1, 'BlockType', char(blockType));
    n = numel(blocks);
    if n == 0
        ports = eLumina.gds.extract.SimulinkSignal.empty(1,0);
        return
    end
    cells = cell(1, n);
    for k = 1:n
        name = string(get_param(blocks{k}, 'Name'));
        cells{k} = eLumina.gds.extract.SimulinkSignal( ...
            name, PortType = blockType);
    end
    ports = [cells{:}];
end
