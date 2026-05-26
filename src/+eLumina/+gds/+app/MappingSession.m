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

        function [matched, iecPath, source] = testSignal(obj, pathStr)
            %TESTSIGNAL Try the current rules against a hypothetical path.
            %   Stateless: does not touch Signals or Results.
            arguments
                obj
                pathStr (1,1) string
            end
            sig = eLumina.gds.extract.SimulinkSignal(pathStr);
            [matched, path, rule] = obj.Rules.applyTo(sig);
            iecPath = path.Path;
            if matched
                source = rule.describe();
            else
                source = "";
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
end
