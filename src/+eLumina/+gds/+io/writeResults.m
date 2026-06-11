function writeResults(results, csvPath)
    %WRITERESULTS Persist MappingResult[] to a CSV consumable by ESCA.
    %
    %   Columns: SimulinkPath, PlantPath, IecPath, LinkedSignalPath,
    %   Status, RuleSource, RuleOrigin, Warning.
    %   Final column layout will follow ESCA's import contract once
    %   that target is available; this is a stable interface ahead of
    %   that.

    arguments
        results (1,:) eLumina.gds.map.MappingResult
        csvPath (1,1) string
    end

    n = numel(results);
    simulinkPath = strings(n, 1);
    plantPath = strings(n, 1);
    iecPath = strings(n, 1);
    linkedSignalPath = strings(n, 1);
    status = strings(n, 1);
    ruleSource = strings(n, 1);
    ruleOrigin = strings(n, 1);
    warning = strings(n, 1);

    for k = 1:n
        simulinkPath(k) = results(k).Signal.fullPath();
        plantPath(k) = results(k).PlantPath;
        iecPath(k) = results(k).IecPath.Path;
        linkedSignalPath(k) = results(k).LinkedSignalPath;
        status(k) = string(results(k).Status);
        ruleSource(k) = results(k).RuleSource;
        ruleOrigin(k) = results(k).RuleOrigin;
        warning(k) = results(k).Warning;
    end

    tbl = table(simulinkPath, plantPath, iecPath, linkedSignalPath, ...
        status, ruleSource, ruleOrigin, warning, ...
        'VariableNames', {'SimulinkPath', 'PlantPath', 'IecPath', ...
                          'LinkedSignalPath', 'Status', 'RuleSource', ...
                          'RuleOrigin', 'Warning'});
    writetable(tbl, csvPath);
end
