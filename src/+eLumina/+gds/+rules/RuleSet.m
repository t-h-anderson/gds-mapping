classdef RuleSet < handle
    %RULESET Ordered collection of MappingRules. First match wins.
    %
    %   Position in the list is the priority — top of the list (index 1)
    %   wins over later entries. The user controls ordering explicitly.

    properties (SetAccess = protected)
        Rules (1,:) eLumina.gds.rules.MappingRule = eLumina.gds.rules.MappingRule.empty(1,0)
    end

    methods
        function obj = RuleSet(rules)
            arguments
                rules (1,:) eLumina.gds.rules.MappingRule = eLumina.gds.rules.MappingRule.empty(1,0)
            end
            obj.Rules = rules;
        end

        function add(obj, rule)
            arguments
                obj
                rule (1,1) eLumina.gds.rules.MappingRule
            end
            obj.Rules = [obj.Rules, rule];
        end

        function remove(obj, idx)
            arguments
                obj
                idx (1,1) double {mustBePositive, mustBeInteger}
            end
            obj.Rules(idx) = [];
        end

        function [matched, path, rule] = applyTo(obj, signal)
            arguments
                obj
                signal (1,1) eLumina.gds.extract.SimulinkSignal
            end
            for k = 1:numel(obj.Rules)
                [matched, path] = obj.Rules(k).applyTo(signal);
                if matched
                    rule = obj.Rules(k);
                    return
                end
            end
            matched = false;
            path = eLumina.gds.iec.IecPath("");
            rule = eLumina.gds.rules.MappingRule.empty(1,0);
        end
    end
end
