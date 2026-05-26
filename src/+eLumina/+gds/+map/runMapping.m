function results = runMapping(signals, ruleSet)
    %RUNMAPPING Apply a RuleSet to each signal, producing MappingResult[].

    arguments
        signals (1,:) eLumina.gds.extract.SimulinkSignal
        ruleSet (1,1) eLumina.gds.rules.RuleSet
    end

    n = numel(signals);
    if n == 0
        results = eLumina.gds.map.MappingResult.empty(1,0);
        return
    end

    results = repmat(eLumina.gds.map.MappingResult(signals(1)), 1, n);
    for k = 1:n
        [matched, path, rule] = ruleSet.applyTo(signals(k));
        if matched
            results(k) = eLumina.gds.map.MappingResult(signals(k), ...
                IecPath = path, ...
                RuleSource = rule.describe(), ...
                Status = eLumina.gds.map.ResultStatus.Matched);
        else
            results(k) = eLumina.gds.map.MappingResult(signals(k), ...
                Status = eLumina.gds.map.ResultStatus.Unmapped);
        end
    end
end
