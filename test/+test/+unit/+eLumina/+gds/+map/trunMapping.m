classdef trunMapping < matlab.unittest.TestCase
    %TRUNMAPPING Tests for eLumina.gds.map.runMapping.

    methods (Test)
        function tEmptySignalsReturnsEmptyResults(testCase)
            rs = eLumina.gds.rules.RuleSet();
            sigs = eLumina.gds.extract.SimulinkSignal.empty(1,0);
            results = eLumina.gds.map.runMapping(sigs, rs);
            testCase.verifyEmpty(results);
        end

        function tAllSignalsMatched(testCase)
            r = eLumina.gds.rules.RegexRule( ...
                Pattern = "^ref(\d+)/in(\d+)$", Template = "esca_${1}in${2}");
            rs = eLumina.gds.rules.RuleSet(r);
            sigs = [ ...
                eLumina.gds.extract.SimulinkSignal("ref1/in1"), ...
                eLumina.gds.extract.SimulinkSignal("ref1/in2"), ...
                eLumina.gds.extract.SimulinkSignal("ref2/in1")];
            results = eLumina.gds.map.runMapping(sigs, rs);

            testCase.verifyEqual(numel(results), 3);
            testCase.verifyEqual([results.Status], repmat( ...
                eLumina.gds.map.ResultStatus.Matched, 1, 3));
            paths = arrayfun(@(r) r.IecPath.Path, results);
            testCase.verifyEqual(paths, ["esca_1in1", "esca_1in2", "esca_2in1"]);
        end

        function tMixedMatchedAndUnmapped(testCase)
            r = eLumina.gds.rules.RegexRule( ...
                Pattern = "^ref(\d+)/in(\d+)$", Template = "esca_${1}in${2}");
            rs = eLumina.gds.rules.RuleSet(r);
            sigs = [ ...
                eLumina.gds.extract.SimulinkSignal("ref1/in1"), ...
                eLumina.gds.extract.SimulinkSignal("misc/orphan")];
            results = eLumina.gds.map.runMapping(sigs, rs);

            testCase.verifyEqual(results(1).Status, eLumina.gds.map.ResultStatus.Matched);
            testCase.verifyEqual(results(1).IecPath.Path, "esca_1in1");
            testCase.verifyEqual(results(2).Status, eLumina.gds.map.ResultStatus.Unmapped);
            testCase.verifyEqual(results(2).IecPath.Path, "");
            testCase.verifyEqual(results(2).RuleSource, "");
        end

        function tRuleSourceCarriesDescription(testCase)
            r = eLumina.gds.rules.RegexRule( ...
                Pattern = "^a$", Template = "b");
            rs = eLumina.gds.rules.RuleSet(r);
            sigs = eLumina.gds.extract.SimulinkSignal("a");
            results = eLumina.gds.map.runMapping(sigs, rs);
            testCase.verifyEqual(results.RuleSource, "regex: ^a$");
        end

        function tFlagsOverrideWhenLowerRuleAlsoMatches(testCase)
            exp = eLumina.gds.rules.ExplicitRule( ...
                Path = "ref2/in1", Target = "override");
            rgx = eLumina.gds.rules.RegexRule( ...
                Pattern = "^ref(\d+)/in(\d+)$", Template = "shadowed");
            rs = eLumina.gds.rules.RuleSet([exp, rgx]);
            sigs = [ ...
                eLumina.gds.extract.SimulinkSignal("ref2/in1"), ...
                eLumina.gds.extract.SimulinkSignal("ref3/in1")];
            results = eLumina.gds.map.runMapping(sigs, rs);
            % ref2/in1 hits the explicit and the regex would also match
            testCase.verifyTrue(results(1).IsOverride);
            testCase.verifyEqual(results(1).IecPath.Path, "override");
            % ref3/in1 only hits the regex
            testCase.verifyFalse(results(2).IsOverride);
        end
    end
end
