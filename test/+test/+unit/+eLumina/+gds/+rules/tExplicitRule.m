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

        function tDefaultsPriorityTo100(testCase)
            rule = eLumina.gds.rules.ExplicitRule(Path = "a", Target = "b");
            testCase.verifyEqual(rule.Priority, 100);
        end
    end
end
