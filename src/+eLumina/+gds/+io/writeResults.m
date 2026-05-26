function writeResults(results, csvPath)
    %WRITERESULTS Persist MappingResult[] to a CSV consumable by ESCA.
    %
    %   Columns: SimulinkPath, IecPath, Status, RuleSource.
    %   Final column layout will follow ESCA's import contract once
    %   that target is available; this is a stable interface ahead of
    %   that.

    arguments
        results (1,:) eLumina.gds.map.MappingResult
        csvPath (1,1) string
    end

    n = numel(results);
    simulinkPath = strings(n, 1);
    iecPath = strings(n, 1);
    status = strings(n, 1);
    ruleSource = strings(n, 1);

    for k = 1:n
        simulinkPath(k) = results(k).Signal.InstancePath;
        iecPath(k) = results(k).IecPath.Path;
        status(k) = string(results(k).Status);
        ruleSource(k) = results(k).RuleSource;
    end

    tbl = table(simulinkPath, iecPath, status, ruleSource, ...
        'VariableNames', {'SimulinkPath', 'IecPath', 'Status', 'RuleSource'});
    writetable(tbl, csvPath);
end
