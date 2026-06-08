function results = runMapping(signals, ruleSet, nvp)
    %RUNMAPPING Apply a RuleSet to each signal, producing MappingResult[].
    %
    %   results = runMapping(signals, ruleSet)
    %   results = runMapping(signals, ruleSet, PlantPaths=..., IsInternal=...)
    %
    %   Rules match against the plant-world path. With no PlantPaths the
    %   plant path defaults to each signal's own controller-side path
    %   (the no-model / string-list case). With a model, the caller
    %   passes the traced plant paths plus per-signal internal flags;
    %   internal signals (no plant equivalent) get Status = Internal and
    %   skip rule matching.

    arguments
        signals (1,:) eLumina.gds.extract.SimulinkSignal
        ruleSet (1,1) eLumina.gds.rules.RuleSet
        nvp.PlantPaths (1,:) string = string.empty
        nvp.IsInternal (1,:) logical = logical.empty
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
    if numel(plantPaths) ~= n || numel(isInternal) ~= n
        error("eLumina:gds:map:lengthMismatch", ...
            "PlantPaths and IsInternal must be the same length as signals.");
    end

    results = repmat(eLumina.gds.map.MappingResult(signals(1)), 1, n);
    for k = 1:n
        if isInternal(k)
            results(k) = eLumina.gds.map.MappingResult(signals(k), ...
                Status = eLumina.gds.map.ResultStatus.Internal);
            continue
        end
        plantPath = plantPaths(k);
        matchSig = eLumina.gds.extract.SimulinkSignal(plantPath);
        [matched, path, ruleIdx, shadows] = ruleSet.applyTo(matchSig);
        if matched
            rule = ruleSet.Rules(ruleIdx);
            results(k) = eLumina.gds.map.MappingResult(signals(k), ...
                IecPath = path, ...
                PlantPath = plantPath, ...
                RuleSource = rule.describe(), ...
                RuleIndex = ruleIdx, ...
                Status = eLumina.gds.map.ResultStatus.Mapped, ...
                IsOverride = ~isempty(shadows), ...
                Shadows = shadows);
        else
            results(k) = eLumina.gds.map.MappingResult(signals(k), ...
                PlantPath = plantPath, ...
                Status = eLumina.gds.map.ResultStatus.Unmapped);
        end
    end
end
