function signals = extractSignals(modelPath)
    %EXTRACTSIGNALS Walk a Simulink model and emit port-level signals.
    %
    %   signals = eLumina.gds.extract.extractSignals(modelPath)
    %
    %   For the given model:
    %     - emits one SimulinkSignal per root Inport / Outport
    %     - recurses into each ModelReference block, emitting one signal
    %       per port of every instance (path: "<refBlockName>/<portName>")
    %
    %   Bus expansion is deliberately not done here — leaf-level signals
    %   come in a follow-up once we know the customer's bus conventions.

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

    chunks = cell(1,0);
    chunks{end+1} = collectPorts(modelName, "Inport", "");
    chunks{end+1} = collectPorts(modelName, "Outport", "");

    modelRefs = find_system(char(modelName), ...
        'SearchDepth', 1, 'BlockType', 'ModelReference');
    for k = 1:numel(modelRefs)
        refBlockName = string(get_param(modelRefs{k}, 'Name'));
        refModelRaw = string(get_param(modelRefs{k}, 'ModelName'));
        [~, refBase] = fileparts(refModelRaw);
        refModel = string(refBase);

        if ~bdIsLoaded(char(refModel))
            load_system(char(refModel));
        end

        chunks{end+1} = collectPorts(refModel, "Inport", refBlockName); %#ok<AGROW>
        chunks{end+1} = collectPorts(refModel, "Outport", refBlockName); %#ok<AGROW>
    end

    signals = [chunks{:}];
end

function ports = collectPorts(systemName, blockType, prefix)
    arguments
        systemName (1,1) string
        blockType (1,1) string {mustBeMember(blockType, ["Inport", "Outport"])}
        prefix (1,1) string
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
        if prefix == ""
            instancePath = name;
        else
            instancePath = prefix + "/" + name;
        end
        cells{k} = eLumina.gds.extract.SimulinkSignal(instancePath, ...
            PortType = blockType);
    end
    ports = [cells{:}];
end
