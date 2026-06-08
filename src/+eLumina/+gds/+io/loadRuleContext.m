function [ruleSet, variables, configPath] = loadRuleContext(overrideCsv, nvp)
    %LOADRULECONTEXT Load layered rules plus any auto-discovered config.

    arguments
        overrideCsv (1,1) string {mustBeFile}
        nvp.BaseRulesCsv (1,1) string = ""
        nvp.ConfigPath (1,1) string = ""
    end

    configPath = nvp.ConfigPath;
    if configPath == ""
        configPath = eLumina.gds.io.discoverConfig([ ...
            overrideCsv, ...
            nvp.BaseRulesCsv]);
    end
    variables = eLumina.gds.io.readConfig(configPath);

    overrideRules = eLumina.gds.io.readRules(overrideCsv, ...
        RuleLayer = "override");
    if nvp.BaseRulesCsv == ""
        baseRules = eLumina.gds.rules.RuleSet();
    else
        baseRules = eLumina.gds.io.readRules(nvp.BaseRulesCsv, ...
            RuleLayer = "base");
    end

    ruleSet = eLumina.gds.rules.RuleSet([ ...
        overrideRules.Rules, ...
        baseRules.Rules]);
end
