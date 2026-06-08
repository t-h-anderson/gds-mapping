classdef tRegexRule < matlab.unittest.TestCase
    %TREGEXRULE Tests for eLumina.gds.rules.RegexRule.

    methods (Test)
        function tMatchesAndSubstitutesCaptures(testCase)
            rule = eLumina.gds.rules.RegexRule( ...
                Pattern = "^ref(\d+)/in(\d+)$", ...
                Template = "esca_${1}in${2}");
            sig = eLumina.gds.extract.SimulinkSignal("ref2/in7");
            [matched, path] = rule.applyTo(sig);
            testCase.verifyTrue(matched);
            testCase.verifyEqual(path.Path, "esca_2in7");
        end

        function tNoMatchReturnsEmptyPath(testCase)
            rule = eLumina.gds.rules.RegexRule( ...
                Pattern = "^ref(\d+)/in(\d+)$", ...
                Template = "esca_${1}in${2}");
            sig = eLumina.gds.extract.SimulinkSignal("status/breaker1");
            [matched, path] = rule.applyTo(sig);
            testCase.verifyFalse(matched);
            testCase.verifyEqual(path.Path, "");
        end

        function tNoCaptureGroupsPassesTemplateThrough(testCase)
            rule = eLumina.gds.rules.RegexRule( ...
                Pattern = "^anything$", ...
                Template = "fixed_target");
            sig = eLumina.gds.extract.SimulinkSignal("anything");
            [matched, path] = rule.applyTo(sig);
            testCase.verifyTrue(matched);
            testCase.verifyEqual(path.Path, "fixed_target");
        end

        function tDescribeIncludesKindAndPattern(testCase)
            rule = eLumina.gds.rules.RegexRule( ...
                Pattern = "^foo$", Template = "bar");
            testCase.verifyEqual(rule.describe(), "regex: ^foo$");
        end
    end
end
