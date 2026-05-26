function results = runFromModel(modelPath, rulesCsv, outputCsv)
    %RUNFROMMODEL Headless end-to-end pipeline starting from a Simulink model.
    %
    %   results = eLumina.gds.runFromModel(modelPath, rulesCsv, outputCsv)
    %
    %   Wraps extractSignals + readRules + runMapping + writeResults.
    %   Use eLumina.gds.run instead if you already have signals as
    %   string paths (no Simulink dependency).

    arguments
        modelPath (1,1) string {mustBeFile}
        rulesCsv (1,1) string {mustBeFile}
        outputCsv (1,1) string
    end

    signals = eLumina.gds.extract.extractSignals(modelPath);
    ruleSet = eLumina.gds.io.readRules(rulesCsv);
    results = eLumina.gds.map.runMapping(signals, ruleSet);
    eLumina.gds.io.writeResults(results, outputCsv);
end
