classdef RuleSet < handle
    %RULESET Ordered collection of MappingRules. Higher priority wins;
    %   ExplicitRule beats RegexRule at equal priority.

    properties (SetAccess = protected)
        Rules (1,:) eLumina.gds.rules.MappingRule = eLumina.gds.rules.MappingRule.empty(1,0)
    end

    methods
        function obj = RuleSet(rules)
            arguments
                rules (1,:) eLumina.gds.rules.MappingRule = eLumina.gds.rules.MappingRule.empty(1,0)
            end
            obj.Rules = eLumina.gds.rules.RuleSet.sortByPrecedence(rules);
        end

        function add(obj, rule)
            arguments
                obj
                rule (1,1) eLumina.gds.rules.MappingRule
            end
            obj.Rules = eLumina.gds.rules.RuleSet.sortByPrecedence([obj.Rules, rule]);
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

    methods (Static, Access = private)
        function sorted = sortByPrecedence(rules)
            if isempty(rules)
                sorted = rules;
                return
            end
            priorities = arrayfun(@(r) r.Priority, rules);
            isExplicit = arrayfun(@(r) isa(r, "eLumina.gds.rules.ExplicitRule"), rules);
            % Sort ascending on negated keys ⇒ descending priority, then
            % explicit (1) before regex (0) at equal priority.
            [~, idx] = sortrows([-priorities(:), -double(isExplicit(:))]);
            sorted = rules(idx);
        end
    end
end
