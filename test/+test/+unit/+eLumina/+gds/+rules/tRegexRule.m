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

        function tNamedPlaceholdersResolveInPatternAndTemplate(testCase)
            rule = eLumina.gds.rules.RegexRule( ...
                Pattern = "^mySignal_${projectSuffix}_(\d+)$", ...
                Template = "iec.${projectSuffix}.${1}");
            sig = eLumina.gds.extract.SimulinkSignal("mySignal_demo_7");
            [matched, path, broken] = rule.applyTo(sig, ...
                Variables = struct("projectSuffix", "demo"));
            testCase.verifyTrue(matched);
            testCase.verifyFalse(broken);
            testCase.verifyEqual(path.Path, "iec.demo.7");
        end

        function tMissingTemplatePlaceholderMarksBroken(testCase)
            rule = eLumina.gds.rules.RegexRule( ...
                Pattern = "^foo$", Template = "bar_${projectSuffix}");
            sig = eLumina.gds.extract.SimulinkSignal("foo");
            [matched, path, broken, warning] = rule.applyTo(sig);
            testCase.verifyTrue(matched);
            testCase.verifyTrue(broken);
            testCase.verifyEqual(path.Path, "");
            testCase.verifySubstring(warning, "projectSuffix");
        end

        function tMissingPatternPlaceholderMarksBrokenWhenSignalCouldMatch(testCase)
            rule = eLumina.gds.rules.RegexRule( ...
                Pattern = "^foo_${projectSuffix}$", ...
                Template = "bar_${projectSuffix}");
            sig = eLumina.gds.extract.SimulinkSignal("foo_demo");
            [matched, path, broken, warning] = rule.applyTo(sig);
            testCase.verifyTrue(matched);
            testCase.verifyTrue(broken);
            testCase.verifyEqual(path.Path, "");
            testCase.verifySubstring(warning, "Pattern");
            testCase.verifySubstring(warning, "IEC template");
        end

        function tMissingPatternPlaceholderDoesNotBlockUnrelatedSignal(testCase)
            rule = eLumina.gds.rules.RegexRule( ...
                Pattern = "^foo_${projectSuffix}$", ...
                Template = "bar_${projectSuffix}");
            sig = eLumina.gds.extract.SimulinkSignal("other");
            [matched, path, broken, warning] = rule.applyTo(sig);
            testCase.verifyFalse(matched);
            testCase.verifyFalse(broken);
            testCase.verifyEqual(path.Path, "");
            testCase.verifyEqual(warning, "");
        end
    end
end
