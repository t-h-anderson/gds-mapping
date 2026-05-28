function plantSig = traceToPlant(modelName, signal)
    %TRACETOPLANT Trace a controller-side leaf signal to its plant origin.
    %
    %   plantSig = traceToPlant(modelName, signal)
    %
    %   Walks the wires from a controller ModelReference port to its
    %   plant-side origin: inputs trace backward, outputs trace forward.
    %   On the way it transparently crosses organisational subsystem
    %   boundaries (an Inport/Outport block inside a subsystem hands off
    %   to the corresponding external port of that subsystem) and remaps
    %   the bus field through each translator MATLAB Function block. The
    %   first real block reached on the far side (Plant subsystem,
    %   Constant, another subsystem boundary block) is the terminal.
    %
    %   Returns an empty PlantSignal when the signal has no plant
    %   equivalent (untraceable -> "internal"). Only simple
    %   "out.x = in.y" translator scripts are followed.

    arguments
        modelName (1,1) string
        signal (1,1) eLumina.gds.extract.SimulinkSignal
    end

    % InstancePath is the model-relative block path plus port name, e.g.
    % "Controllers/ctrl1/In1": the block is everything but the last
    % segment, the port is the last segment.
    parts = split(signal.InstancePath, "/");
    blockPath = modelName + "/" + join(parts(1:end-1), "/");
    portName = parts(end);

    if signal.PortType == "Inport"
        portNum = portIndex(blockPath, "InputPortNames", portName);
        [plantSig, ok] = traceBack(blockPath, portNum, signal.BusField);
    else
        portNum = portIndex(blockPath, "OutputPortNames", portName);
        [plantSig, ok] = traceFwd(blockPath, portNum, signal.BusField);
    end

    if ~ok
        plantSig = eLumina.gds.extract.PlantSignal.empty(1,0);
    end
end

function n = portIndex(blockPath, prop, portName)
    names = eLumina.gds.extract.portNameList(get_param(char(blockPath), char(prop)));
    n = find(names == portName, 1);
    if isempty(n)
        n = 0;
    end
end

function [plantSig, ok] = traceBack(blockPath, portNum, field)
    plantSig = eLumina.gds.extract.PlantSignal.empty(1,0);
    ok = false;
    if portNum == 0
        return
    end
    [srcBlock, srcPort] = upstreamOf(blockPath, portNum);
    if srcBlock == ""
        return
    end
    bt = blockType(srcBlock);
    if bt == "Inport"
        % Subsystem boundary: hand off to the parent's external input.
        [parentSub, p] = crossBoundary(srcBlock);
        [plantSig, ok] = traceBack(parentSub, p, field);
        return
    end
    if isMFB(srcBlock)
        m = mfbFieldMap(srcBlock);
        if ~isKey(m, field)
            return
        end
        [plantSig, ok] = traceBack(srcBlock, 1, m(field));
        return
    end
    [plantSig, ok] = terminal(srcBlock, srcPort, "Outport", field);
end

function [plantSig, ok] = traceFwd(blockPath, portNum, field)
    plantSig = eLumina.gds.extract.PlantSignal.empty(1,0);
    ok = false;
    if portNum == 0
        return
    end
    [dstBlock, dstPort] = downstreamOf(blockPath, portNum);
    if dstBlock == ""
        return
    end
    bt = blockType(dstBlock);
    if bt == "Outport"
        % Subsystem boundary: hand off to the parent's external output.
        [parentSub, p] = crossBoundary(dstBlock);
        [plantSig, ok] = traceFwd(parentSub, p, field);
        return
    end
    if isMFB(dstBlock)
        m = mfbFieldMap(dstBlock);
        outField = reverseLookup(m, field);
        if outField == ""
            return
        end
        [plantSig, ok] = traceFwd(dstBlock, 1, outField);
        return
    end
    [plantSig, ok] = terminal(dstBlock, dstPort, "Inport", field);
end

function [parentSub, portNum] = crossBoundary(portBlock)
    parentSub = string(get_param(char(portBlock), 'Parent'));
    portNum = str2double(string(get_param(char(portBlock), 'Port')));
    if isnan(portNum)
        portNum = 1;
    end
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
    ph = get_param(char(blockPath), 'PortHandles');
    if portNum > numel(ph.Inport)
        return
    end
    line = get_param(ph.Inport(portNum), 'Line');
    if line == -1
        return
    end
    sp = get_param(line, 'SrcPortHandle');
    if sp == -1
        return
    end
    srcBlock = string(get_param(sp, 'Parent'));
    srcPort = get_param(sp, 'PortNumber');
end

function [dstBlock, dstPort] = downstreamOf(blockPath, portNum)
    dstBlock = "";
    dstPort = 0;
    ph = get_param(char(blockPath), 'PortHandles');
    if portNum > numel(ph.Outport)
        return
    end
    line = get_param(ph.Outport(portNum), 'Line');
    if line == -1
        return
    end
    dp = get_param(line, 'DstPortHandle');
    dp = dp(dp ~= -1);
    if isempty(dp)
        return
    end
    dstBlock = string(get_param(dp(1), 'Parent'));
    dstPort = get_param(dp(1), 'PortNumber');
end

function [plantSig, ok] = terminal(blockPath, portNum, portType, field)
    plantSig = eLumina.gds.extract.PlantSignal.empty(1,0);
    ok = false;
    bt = blockType(blockPath);
    blockName = string(get_param(char(blockPath), 'Name'));
    switch bt
        case "SubSystem"
            portName = subsystemPortName(blockPath, portType, portNum);
            plantSig = eLumina.gds.extract.PlantSignal( ...
                blockName + "/" + portName, BusField = field);
            ok = true;
        case "Constant"
            plantSig = eLumina.gds.extract.PlantSignal( ...
                blockName, BusField = field);
            ok = true;
    end
end

function bt = blockType(blockPath)
    bt = string(get_param(char(blockPath), 'BlockType'));
end

function tf = isMFB(blockPath)
    tf = false;
    try
        tf = string(get_param(char(blockPath), 'SFBlockType')) == "MATLAB Function";
    catch
    end
end

function m = mfbFieldMap(blockPath)
    charts = sfroot().find('-isa', 'Stateflow.EMChart');
    script = "";
    for i = 1:numel(charts)
        if string(charts(i).Path) == string(blockPath)
            script = string(charts(i).Script);
            break
        end
    end
    m = eLumina.gds.extract.parseMFBScript(script);
end

function name = subsystemPortName(blockPath, portType, portNum)
    inner = find_system(char(blockPath), 'SearchDepth', 1, ...
        'BlockType', char(portType), 'Port', num2str(portNum));
    if isempty(inner)
        name = portType + string(portNum);
    else
        name = string(get_param(inner{1}, 'Name'));
    end
end
