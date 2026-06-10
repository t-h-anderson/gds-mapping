function results = runMapping(signals, ruleSet, nvp)
    %RUNMAPPING Apply a RuleSet to each signal, producing MappingResult[].
    %
    %   results = runMapping(signals, ruleSet)
    %   results = runMapping(signals, ruleSet, PlantPaths=..., IsInternal=...)
    %
    %   IEC rules match against the plant-world path. With no PlantPaths
    %   the plant path defaults to each signal's own controller-side path
    %   (the no-model / string-list case). With a model, the caller
    %   passes the traced plant paths plus per-signal internal flags.
    %   Internal signals can carry a traced LinkedSignalPaths entry;
    %   otherwise they get Status = Internal.

    arguments
        signals (1,:) eLumina.gds.extract.SimulinkSignal
        ruleSet (1,1) eLumina.gds.rules.RuleSet
        nvp.PlantPaths (1,:) string = string.empty
        nvp.IsInternal (1,:) logical = logical.empty
        nvp.LinkedSignalPaths (1,:) string = string.empty
        nvp.Variables = struct()
    end

    n = numel(signals);
    if n == 0
        results = eLumina.gds.map.MappingResult.empty(1,0);
        return
    end

    plantPaths = nvp.PlantPaths;
    if isempty(plantPaths)
        plantPaths = arrayfun(@(s) s.fullPath(), signals);
    end
    isInternal = nvp.IsInternal;
    if isempty(isInternal)
        isInternal = false(1, n);
    end
    linkedSignalPaths = nvp.LinkedSignalPaths;
    if isempty(linkedSignalPaths)
        linkedSignalPaths = strings(1, n);
    end
    if numel(plantPaths) ~= n || numel(isInternal) ~= n || numel(linkedSignalPaths) ~= n
        error("eLumina:gds:map:lengthMismatch", ...
            "PlantPaths, IsInternal, and LinkedSignalPaths must be the same length as signals.");
    end

    results = repmat(eLumina.gds.map.MappingResult(signals(1)), 1, n);
    for k = 1:n
        if isInternal(k)
            if linkedSignalPaths(k) ~= ""
                results(k) = eLumina.gds.map.MappingResult(signals(k), ...
                    LinkedSignalPath = linkedSignalPaths(k), ...
                    Status = eLumina.gds.map.ResultStatus.SignalMapped);
            else
                results(k) = eLumina.gds.map.MappingResult(signals(k), ...
                    Status = eLumina.gds.map.ResultStatus.Internal);
            end
            continue
        end
        plantPath = plantPaths(k);
        matchSig = eLumina.gds.extract.SimulinkSignal(plantPath);
        [matched, path, ruleIdx, shadows, broken, warning] = ruleSet.applyTo( ...
            matchSig, Variables = nvp.Variables);
        if matched
            rule = ruleSet.Rules(ruleIdx);
            results(k) = matchedResult(signals(k), path, rule, ruleIdx, ...
                shadows, broken, warning, plantPath);
        else
            results(k) = eLumina.gds.map.MappingResult(signals(k), ...
                PlantPath = plantPath, ...
                Status = eLumina.gds.map.ResultStatus.Unmapped);
        end
    end
end

function result = matchedResult(signal, path, rule, ruleIdx, shadows, broken, warning, plantPath)
    if broken
        iecPath = eLumina.gds.iec.IecPath("");
    else
        iecPath = path;
    end
    result = eLumina.gds.map.MappingResult(signal, ...
        IecPath = iecPath, ...
        PlantPath = plantPath, ...
        RuleSource = rule.describe(), ...
        RuleOrigin = rule.provenance(), ...
        RuleIndex = ruleIdx, ...
        Status = ternaryStatus(broken), ...
        Warning = warning, ...
        IsOverride = ~isempty(shadows), ...
        Shadows = shadows);
end

function status = ternaryStatus(broken)
    if broken
        status = eLumina.gds.map.ResultStatus.Broken;
    else
        status = eLumina.gds.map.ResultStatus.Mapped;
    end
end
