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

        function moveUp(obj, idx)
            arguments
                obj
                idx (1,1) double {mustBePositive, mustBeInteger}
            end
            if idx <= 1 || idx > numel(obj.Rules)
                return
            end
            obj.Rules([idx-1, idx]) = obj.Rules([idx, idx-1]);
        end

        function moveDown(obj, idx)
            arguments
                obj
                idx (1,1) double {mustBePositive, mustBeInteger}
            end
            if idx < 1 || idx >= numel(obj.Rules)
                return
            end
            obj.Rules([idx, idx+1]) = obj.Rules([idx+1, idx]);
        end

        function replace(obj, idx, rule)
            arguments
                obj
                idx (1,1) double {mustBePositive, mustBeInteger}
                rule (1,1) eLumina.gds.rules.MappingRule
            end
            obj.Rules(idx) = rule;
        end

        function [matched, path, ruleIdx, shadows, broken, warning, targetKind] = applyTo(obj, signal, nvp)
            %APPLYTO First-match-wins lookup. Returns the index of the
            %   firing rule (0 if none) and the indices of any later
            %   rules that would also have matched (i.e. were shadowed
            %   by the firing rule).
            arguments
                obj
                signal (1,1) eLumina.gds.extract.SimulinkSignal
                nvp.Variables = struct()
            end
            matched = false;
            path = eLumina.gds.iec.IecPath("");
            ruleIdx = 0;
            shadows = zeros(1,0);
            broken = false;
            warning = "";
            targetKind = "iec";
            for k = 1:numel(obj.Rules)
                [m, p, b, w] = obj.Rules(k).applyTo(signal, ...
                    Variables = nvp.Variables);
                if ~m
                    continue
                end
                if ~matched
                    matched = true;
                    path = p;
                    ruleIdx = k;
                    broken = b;
                    warning = w;
                    targetKind = obj.Rules(k).TargetKind;
                else
                    shadows(end+1) = k; %#ok<AGROW>
                end
            end
        end
    end
end
