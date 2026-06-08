classdef tExplicitRule < matlab.unittest.TestCase
    %TEXPLICITRULE Tests for eLumina.gds.rules.ExplicitRule.

    methods (Test)
        function tExactPathMatches(testCase)
            rule = eLumina.gds.rules.ExplicitRule( ...
                Path = "ref2/in1", Target = "esca_special_override");
            sig = eLumina.gds.extract.SimulinkSignal("ref2/in1");
            [matched, path] = rule.applyTo(sig);
            testCase.verifyTrue(matched);
            testCase.verifyEqual(path.Path, "esca_special_override");
        end

        function tDifferentPathMisses(testCase)
            rule = eLumina.gds.rules.ExplicitRule( ...
                Path = "ref2/in1", Target = "esca_special_override");
            sig = eLumina.gds.extract.SimulinkSignal("ref2/in2");
            [matched, path] = rule.applyTo(sig);
            testCase.verifyFalse(matched);
            testCase.verifyEqual(path.Path, "");
        end

        function tDescribeIncludesKindAndPath(testCase)
            rule = eLumina.gds.rules.ExplicitRule( ...
                Path = "ref2/in1", Target = "esca_x");
            testCase.verifyEqual(rule.describe(), "explicit: ref2/in1");
        end

        function tNamedPlaceholdersResolveFromConfig(testCase)
            rule = eLumina.gds.rules.ExplicitRule( ...
                Path = "ref_${projectSuffix}", ...
                Target = "iec_${projectSuffix}");
            sig = eLumina.gds.extract.SimulinkSignal("ref_demo");
            [matched, path, broken] = rule.applyTo(sig, ...
                Variables = struct("projectSuffix", "demo"));
            testCase.verifyTrue(matched);
            testCase.verifyFalse(broken);
            testCase.verifyEqual(path.Path, "iec_demo");
        end

        function tMissingTargetPlaceholderMarksBroken(testCase)
            rule = eLumina.gds.rules.ExplicitRule( ...
                Path = "ref2/in1", Target = "esca_${projectSuffix}");
            sig = eLumina.gds.extract.SimulinkSignal("ref2/in1");
            [matched, path, broken, warning] = rule.applyTo(sig);
            testCase.verifyTrue(matched);
            testCase.verifyTrue(broken);
            testCase.verifyEqual(path.Path, "");
            testCase.verifySubstring(warning, "projectSuffix");
        end

        function tMissingPathPlaceholderMarksBrokenWhenSignalCouldMatch(testCase)
            rule = eLumina.gds.rules.ExplicitRule( ...
                Path = "ref_${projectSuffix}", ...
                Target = "iec_${projectSuffix}");
            sig = eLumina.gds.extract.SimulinkSignal("ref_demo");
            [matched, path, broken, warning] = rule.applyTo(sig);
            testCase.verifyTrue(matched);
            testCase.verifyTrue(broken);
            testCase.verifyEqual(path.Path, "");
            testCase.verifySubstring(warning, "Path");
            testCase.verifySubstring(warning, "IEC target");
        end

        function tMissingPathPlaceholderDoesNotBlockUnrelatedSignal(testCase)
            rule = eLumina.gds.rules.ExplicitRule( ...
                Path = "ref_${projectSuffix}", ...
                Target = "iec_${projectSuffix}");
            sig = eLumina.gds.extract.SimulinkSignal("other");
            [matched, path, broken, warning] = rule.applyTo(sig);
            testCase.verifyFalse(matched);
            testCase.verifyFalse(broken);
            testCase.verifyEqual(path.Path, "");
            testCase.verifyEqual(warning, "");
        end
    end
end
