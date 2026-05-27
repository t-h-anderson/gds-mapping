function signals = extractSignals(modelPath)
    %EXTRACTSIGNALS Walk a Simulink model and emit bus-leaf signals.
    %
    %   signals = eLumina.gds.extract.extractSignals(modelPath)
    %
    %   For each ModelReference block in the root system, every port is
    %   fanned out to one SimulinkSignal per bus leaf field (read from
    %   the model's data dictionary). Scalar ports emit a single signal
    %   with BusField = "".
    %
    %   Root-level Inports / Outports of the model itself are also
    %   emitted, port-level only (no bus expansion until we hit a model
    %   that needs it).
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
        cleanupPath = onCleanup(@() rmpath(char(folder))); %#ok<NASGU>
    end

    if ~bdIsLoaded(char(modelName))
        load_system(char(modelPath));
    end

    dd = openDataDictionary(modelName);

    chunks = cell(1,0);

    modelRefs = find_system(char(modelName), ...
        'SearchDepth', 1, 'BlockType', 'ModelReference');
    for k = 1:numel(modelRefs)
        chunks{end+1} = expandModelReferencePorts(modelRefs{k}, dd); %#ok<AGROW>
    end

    chunks{end+1} = collectRootPorts(modelName, "Inport");
    chunks{end+1} = collectRootPorts(modelName, "Outport");

    signals = [chunks{:}];
end

function dd = openDataDictionary(modelName)
    ddName = string(get_param(char(modelName), 'DataDictionary'));
    if ddName == ""
        dd = Simulink.data.dictionary.Dictionary.empty;
        return
    end
    try
        dd = Simulink.data.dictionary.open(char(ddName));
    catch
        dd = Simulink.data.dictionary.Dictionary.empty;
    end
end

function leaves = expandModelReferencePorts(refBlock, dd)
    refBlockName = string(get_param(refBlock, 'Name'));
    inNames = string(get_param(refBlock, 'InputPortNames'));
    inBuses = string(get_param(refBlock, 'InputPortBusObjects'));
    outNames = string(get_param(refBlock, 'OutputPortNames'));
    outBuses = string(get_param(refBlock, 'OutputPortBusObjects'));

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
    if busName == "" || isempty(dd)
        leaves = eLumina.gds.extract.SimulinkSignal( ...
            portPath, PortType = portType);
        return
    end
    fields = eLumina.gds.extract.enumerateBusFields(busName, dd);
    if isempty(fields)
        leaves = eLumina.gds.extract.SimulinkSignal( ...
            portPath, PortType = portType);
        return
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
