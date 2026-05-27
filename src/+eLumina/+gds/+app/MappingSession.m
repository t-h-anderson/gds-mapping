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
        Rules (1,1) eLumina.gds.rules.RuleSet
        Signals (1,:) eLumina.gds.extract.SimulinkSignal = eLumina.gds.extract.SimulinkSignal.empty(1,0)
        Results (1,:) eLumina.gds.map.MappingResult = eLumina.gds.map.MappingResult.empty(1,0)
        ModelPath (1,1) string = ""
        RulesPath (1,1) string = ""
    end

    methods
        function obj = MappingSession()
            obj.Rules = eLumina.gds.rules.RuleSet();
        end

        function loadRules(obj, path)
            arguments
                obj
                path (1,1) string {mustBeFile}
            end
            obj.Rules = eLumina.gds.io.readRules(path);
            obj.RulesPath = path;
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
            eLumina.gds.io.writeRules(obj.Rules, path);
            obj.RulesPath = path;
        end

        function setSignals(obj, signals)
            arguments
                obj
                signals (1,:) eLumina.gds.extract.SimulinkSignal
            end
            obj.Signals = signals;
            obj.recompute();
        end

        function loadModel(obj, modelPath)
            arguments
                obj
                modelPath (1,1) string {mustBeFile}
            end
            obj.ModelPath = modelPath;
            obj.setSignals(eLumina.gds.extract.extractSignals(modelPath));
        end

        function addRule(obj, rule)
            arguments
                obj
                rule (1,1) eLumina.gds.rules.MappingRule
            end
            obj.Rules.add(rule);
            obj.recompute();
        end

        function removeRule(obj, idx)
            arguments
                obj
                idx (1,1) double {mustBePositive, mustBeInteger}
            end
            obj.Rules.remove(idx);
            obj.recompute();
        end

        function moveRuleUp(obj, idx)
            arguments
                obj
                idx (1,1) double {mustBePositive, mustBeInteger}
            end
            obj.Rules.moveUp(idx);
            obj.recompute();
        end

        function moveRuleDown(obj, idx)
            arguments
                obj
                idx (1,1) double {mustBePositive, mustBeInteger}
            end
            obj.Rules.moveDown(idx);
            obj.recompute();
        end

        function updateRule(obj, idx, rule)
            arguments
                obj
                idx (1,1) double {mustBePositive, mustBeInteger}
                rule (1,1) eLumina.gds.rules.MappingRule
            end
            obj.Rules.replace(idx, rule);
            obj.recompute();
        end

        function [matched, iecPath, ruleDisplay] = testSignal(obj, pathStr)
            %TESTSIGNAL Try the current rules against a hypothetical path.
            %   Stateless: does not touch Signals or Results. ruleDisplay
            %   is the pre-formatted "[N] kind: pattern (shadows [...])"
            %   string the View shows verbatim.
            arguments
                obj
                pathStr (1,1) string
            end
            sig = eLumina.gds.extract.SimulinkSignal(pathStr);
            [matched, path, ruleIdx, shadows] = obj.Rules.applyTo(sig);
            iecPath = path.Path;
            if matched
                source = obj.Rules.Rules(ruleIdx).describe();
                ruleDisplay = eLumina.gds.app.MappingSession.formatRuleDisplay( ...
                    ruleIdx, source, shadows);
            else
                ruleDisplay = "";
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
            obj.Results = eLumina.gds.map.runMapping(obj.Signals, obj.Rules);
            notify(obj, "Changed");
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
