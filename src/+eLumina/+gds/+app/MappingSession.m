classdef MappingSession < handle
    %MAPPINGSESSION Stateful model for the GDS mapping app.
    %
    %   Owns the current rules, signals and computed results, and fires a
    %   Changed event whenever any of them are touched. The View listens to
    %   Changed and re-renders; there is no separate Controller.

    events (NotifyAccess = protected)
        Changed
    end

    properties (SetAccess = protected)
        OverrideRules (1,1) eLumina.gds.rules.RuleSet
        BaseRules (1,1) eLumina.gds.rules.RuleSet
        Rules (1,1) eLumina.gds.rules.RuleSet
        RuleWarnings (1,:) string = string.empty(1,0)
        Signals (1,:) eLumina.gds.extract.SimulinkSignal = eLumina.gds.extract.SimulinkSignal.empty(1,0)
        Results (1,:) eLumina.gds.map.MappingResult = eLumina.gds.map.MappingResult.empty(1,0)
        ModelPath (1,1) string = ""
        RulesPath (1,1) string = ""
        BaseRulesPath (1,1) string = ""
        ConfigPath (1,1) string = ""
    end

    properties (Access = private)
        PlantPaths (1,:) string = string.empty
        IsInternal (1,:) logical = logical.empty
        LinkedSignalPaths (1,:) string = string.empty
        ConfigValues = struct()
        HasExplicitConfig (1,1) logical = false
    end

    methods
        function obj = MappingSession()
            obj.OverrideRules = eLumina.gds.rules.RuleSet();
            obj.BaseRules = eLumina.gds.rules.RuleSet();
            obj.Rules = eLumina.gds.rules.RuleSet();
        end

        function loadRules(obj, path, nvp)
            arguments
                obj
                path (1,1) string {mustBeFile}
                nvp.ConfigPath (1,1) string = ""
            end
            obj.RulesPath = path;
            obj.OverrideRules = eLumina.gds.io.readRules(path, ...
                RuleLayer = "override");
            if nvp.ConfigPath ~= ""
                obj.setConfigPath(nvp.ConfigPath, true);
            elseif ~obj.HasExplicitConfig
                obj.refreshAutoConfigFromRules();
            end
            obj.refreshRules();
            obj.recompute();
        end

        function loadBaseRules(obj, path)
            arguments
                obj
                path (1,1) string {mustBeFile}
            end
            obj.BaseRulesPath = path;
            obj.BaseRules = eLumina.gds.io.readRules(path, RuleLayer = "base");
            if ~obj.HasExplicitConfig
                obj.refreshAutoConfigFromRules();
            end
            obj.refreshRules();
            obj.recompute();
        end

        function loadConfig(obj, path)
            arguments
                obj
                path (1,1) string {mustBeFile}
            end
            obj.setConfigPath(path, true);
            obj.refreshRuleWarnings();
            obj.recompute();
        end

        function saveRules(obj, path)
            arguments
                obj
                path (1,1) string = ""
            end
            if path == ""
                if obj.RulesPath == ""
                    error("eLumina:gds:app:noRulesPath", ...
                        "No rules path known; pass one explicitly or call loadRules first.");
                end
                path = obj.RulesPath;
            end
            eLumina.gds.io.writeRules(obj.OverrideRules, path);
            obj.RulesPath = path;
            obj.OverrideRules = eLumina.gds.io.readRules(path, ...
                RuleLayer = "override");
            if ~obj.HasExplicitConfig
                obj.refreshAutoConfigFromRules();
            end
            obj.refreshRules();
            obj.recompute();
        end

        function setSignals(obj, signals)
            arguments
                obj
                signals (1,:) eLumina.gds.extract.SimulinkSignal
            end
            % No model trace: rules match the controller-side path.
            obj.Signals = signals;
            obj.PlantPaths = string.empty;
            obj.IsInternal = logical.empty;
            obj.LinkedSignalPaths = string.empty;
            obj.recompute();
        end

        function loadModel(obj, modelPath)
            arguments
                obj
                modelPath (1,1) string {mustBeFile}
            end
            obj.ModelPath = modelPath;
            signals = eLumina.gds.extract.extractSignals(modelPath);
            [~, modelName] = fileparts(modelPath);
            [pp, ii, links] = eLumina.gds.extract.tracePlantPaths( ...
                string(modelName), signals);
            obj.Signals = signals;
            obj.PlantPaths = pp;
            obj.IsInternal = ii;
            obj.LinkedSignalPaths = links;
            obj.recompute();
        end

        function addRule(obj, rule)
            arguments
                obj
                rule (1,1) eLumina.gds.rules.MappingRule
            end
            obj.OverrideRules.add(obj.prepareOverrideRule(rule));
            obj.refreshRules();
            obj.recompute();
        end

        function removeRule(obj, idx)
            arguments
                obj
                idx (1,1) double {mustBePositive, mustBeInteger}
            end
            idx = obj.overrideRuleIndex(idx);
            obj.OverrideRules.remove(idx);
            obj.refreshRules();
            obj.recompute();
        end

        function moveRuleUp(obj, idx)
            arguments
                obj
                idx (1,1) double {mustBePositive, mustBeInteger}
            end
            idx = obj.overrideRuleIndex(idx);
            obj.OverrideRules.moveUp(idx);
            obj.refreshRules();
            obj.recompute();
        end

        function moveRuleDown(obj, idx)
            arguments
                obj
                idx (1,1) double {mustBePositive, mustBeInteger}
            end
            idx = obj.overrideRuleIndex(idx);
            obj.OverrideRules.moveDown(idx);
            obj.refreshRules();
            obj.recompute();
        end

        function updateRule(obj, idx, rule)
            arguments
                obj
                idx (1,1) double {mustBePositive, mustBeInteger}
                rule (1,1) eLumina.gds.rules.MappingRule
            end
            idx = obj.overrideRuleIndex(idx);
            obj.OverrideRules.replace(idx, obj.prepareOverrideRule(rule));
            obj.refreshRules();
            obj.recompute();
        end

        function [matched, iecPath, ruleDisplay, ruleOrigin, warning, status] = testSignal(obj, pathStr)
            %TESTSIGNAL Try the current rules against a hypothetical path.
            %   Stateless: does not touch Signals or Results. ruleDisplay
            %   is the pre-formatted "[N] kind: pattern (shadows [...])"
            %   string the View shows verbatim.
            arguments
                obj
                pathStr (1,1) string
            end
            sig = eLumina.gds.extract.SimulinkSignal(pathStr);
            [matched, path, ruleIdx, shadows, broken, warning] = obj.Rules.applyTo( ...
                sig, Variables = obj.ConfigValues);
            iecPath = path.Path;
            ruleOrigin = "";
            if matched
                rule = obj.Rules.Rules(ruleIdx);
                source = rule.describe();
                ruleDisplay = eLumina.gds.app.MappingSession.formatRuleDisplay( ...
                    ruleIdx, source, shadows);
                ruleOrigin = rule.provenance();
                if broken
                    status = eLumina.gds.map.ResultStatus.Broken;
                else
                    status = eLumina.gds.map.ResultStatus.Mapped;
                end
            else
                ruleDisplay = "";
                status = eLumina.gds.map.ResultStatus.Unmapped;
            end
        end

        function exportResults(obj, path)
            arguments
                obj
                path (1,1) string
            end
            eLumina.gds.io.writeResults(obj.Results, path);
        end
    end

    methods (Access = private)
        function recompute(obj)
            obj.Results = eLumina.gds.map.runMapping(obj.Signals, obj.Rules, ...
                PlantPaths = obj.PlantPaths, IsInternal = obj.IsInternal, ...
                LinkedSignalPaths = obj.LinkedSignalPaths, ...
                Variables = obj.ConfigValues);
            notify(obj, "Changed");
        end

        function refreshRules(obj)
            obj.Rules = eLumina.gds.rules.RuleSet([ ...
                obj.OverrideRules.Rules, ...
                obj.BaseRules.Rules]);
            obj.refreshRuleWarnings();
        end

        function refreshRuleWarnings(obj)
            rules = obj.Rules.Rules;
            n = numel(rules);
            warnings = strings(1, n);
            for k = 1:n
                warnings(k) = rules(k).placeholderWarning(obj.ConfigValues);
            end
            obj.RuleWarnings = warnings;
        end

        function setConfigPath(obj, path, isExplicit)
            arguments
                obj
                path (1,1) string
                isExplicit (1,1) logical
            end
            obj.ConfigPath = path;
            obj.HasExplicitConfig = isExplicit;
            obj.ConfigValues = eLumina.gds.io.readConfig(path);
        end

        function refreshAutoConfigFromRules(obj)
            configPath = eLumina.gds.io.discoverConfig([ ...
                obj.RulesPath, ...
                obj.BaseRulesPath]);
            obj.setConfigPath(configPath, false);
        end

        function idx = overrideRuleIndex(obj, idx)
            overrideCount = numel(obj.OverrideRules.Rules);
            if idx > overrideCount
                error("eLumina:gds:app:ruleReadOnly", ...
                    "Base rules are read-only in the app; edit the override rules instead.");
            end
        end

        function rule = prepareOverrideRule(obj, rule)
            rule = rule.withMetadata( ...
                SourcePath = obj.RulesPath, ...
                SourceRow = 0, ...
                RuleLayer = "override");
        end
    end

    methods (Static)
        function s = formatRuleDisplay(ruleIdx, source, shadows)
            %FORMATRULEDISPLAY Canonical "[N] kind: pattern (shadows [...])"
            %   used by both the results table and the test panel so the
            %   two stay in lockstep.
            arguments
                ruleIdx (1,1) double
                source (1,1) string
                shadows (1,:) double = zeros(1,0)
            end
            if ruleIdx == 0
                s = source;
                return
            end
            s = "[" + ruleIdx + "] " + source;
            if ~isempty(shadows)
                s = s + " (shadows [" + strjoin(string(shadows), ",") + "])";
            end
        end
    end
end
