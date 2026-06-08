function results = runFromModel(modelPath, rulesCsv, outputCsv, nvp)
    %RUNFROMMODEL Headless end-to-end pipeline starting from a Simulink model.
    %
    %   results = eLumina.gds.runFromModel(modelPath, rulesCsv, outputCsv)
    %
    %   Extracts controller bus-leaf signals, traces each to its
    %   plant-world origin through the translator MATLAB Function blocks,
    %   matches the plant path against the rules, and writes the result
    %   CSV. Signals with no plant equivalent are reported as Internal.

    arguments
        modelPath (1,1) string {mustBeFile}
        rulesCsv (1,1) string {mustBeFile}
        outputCsv (1,1) string
        nvp.BaseRulesCsv (1,1) string = ""
        nvp.ConfigPath (1,1) string = ""
    end

    signals = eLumina.gds.extract.extractSignals(modelPath);
    [~, modelName] = fileparts(modelPath);
    [plantPaths, isInternal] = eLumina.gds.extract.tracePlantPaths( ...
        string(modelName), signals);
    [ruleSet, variables] = eLumina.gds.io.loadRuleContext(rulesCsv, ...
        BaseRulesCsv = nvp.BaseRulesCsv, ...
        ConfigPath = nvp.ConfigPath);
    results = eLumina.gds.map.runMapping(signals, ruleSet, ...
        PlantPaths = plantPaths, IsInternal = isInternal, ...
        Variables = variables);
    eLumina.gds.io.writeResults(results, outputCsv);
end
