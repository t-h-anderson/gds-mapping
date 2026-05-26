classdef tRuleSet < matlab.unittest.TestCase
    %TRULESET Tests for eLumina.gds.rules.RuleSet precedence and dispatch.

    methods (Test)
        function tEmptyRuleSetReturnsUnmatched(testCase)
            rs  = eLumina.gds.rules.RuleSet();
            sig = eLumina.gds.extract.SimulinkSignal("ref1/in1");
            [matched, path, rule] = rs.applyTo(sig);
            testCase.verifyFalse(matched);
            testCase.verifyEqual(path.Path, "");
            testCase.verifyTrue(isempty(rule));
        end

        function tSingleRuleFires(testCase)
            r = eLumina.gds.rules.RegexRule( ...
                Pattern = "^ref(\d+)/in(\d+)$", Template = "esca_${1}in${2}");
            rs  = eLumina.gds.rules.RuleSet(r);
            sig = eLumina.gds.extract.SimulinkSignal("ref1/in1");
            [matched, path, rule] = rs.applyTo(sig);
            testCase.verifyTrue(matched);
            testCase.verifyEqual(path.Path, "esca_1in1");
            testCase.verifyTrue(isa(rule, "eLumina.gds.rules.RegexRule"));
        end

        function tHigherPriorityWins(testCase)
            low  = eLumina.gds.rules.RegexRule( ...
                Pattern = "^ref(\d+)/in(\d+)$", Template = "lo_${1}_${2}", ...
                Priority = 10);
            high = eLumina.gds.rules.RegexRule( ...
                Pattern = "^ref(\d+)/in(\d+)$", Template = "hi_${1}_${2}", ...
                Priority = 20);
            rs  = eLumina.gds.rules.RuleSet([low, high]);
            sig = eLumina.gds.extract.SimulinkSignal("ref3/in4");
            [~, path] = rs.applyTo(sig);
            testCase.verifyEqual(path.Path, "hi_3_4");
        end

        function tExplicitBeatsRegexAtEqualPriority(testCase)
            rgx = eLumina.gds.rules.RegexRule( ...
                Pattern = "^ref(\d+)/in(\d+)$", Template = "regex_${1}_${2}", ...
                Priority = 50);
            exp = eLumina.gds.rules.ExplicitRule( ...
                Path = "ref2/in1", Target = "explicit_override", ...
                Priority = 50);
            rs  = eLumina.gds.rules.RuleSet([rgx, exp]);
            sig = eLumina.gds.extract.SimulinkSignal("ref2/in1");
            [~, path, rule] = rs.applyTo(sig);
            testCase.verifyEqual(path.Path, "explicit_override");
            testCase.verifyTrue(isa(rule, "eLumina.gds.rules.ExplicitRule"));
        end

        function tRegexBeatsLowerPriorityExplicit(testCase)
            % Higher priority wins even when the loser is explicit.
            exp = eLumina.gds.rules.ExplicitRule( ...
                Path = "ref2/in1", Target = "low_pri_override", Priority = 1);
            rgx = eLumina.gds.rules.RegexRule( ...
                Pattern = "^ref(\d+)/in(\d+)$", Template = "regex_${1}_${2}", ...
                Priority = 10);
            rs  = eLumina.gds.rules.RuleSet([exp, rgx]);
            sig = eLumina.gds.extract.SimulinkSignal("ref2/in1");
            [~, path] = rs.applyTo(sig);
            testCase.verifyEqual(path.Path, "regex_2_1");
        end

        function tAddInsertsAndReorders(testCase)
            rs = eLumina.gds.rules.RuleSet();
            rs.add(eLumina.gds.rules.RegexRule( ...
                Pattern = "^a$", Template = "lo", Priority = 5));
            rs.add(eLumina.gds.rules.RegexRule( ...
                Pattern = "^a$", Template = "hi", Priority = 20));
            sig = eLumina.gds.extract.SimulinkSignal("a");
            [~, path] = rs.applyTo(sig);
            testCase.verifyEqual(path.Path, "hi");
        end
    end
end
