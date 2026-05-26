classdef trunMapping < matlab.unittest.TestCase
    %TRUNMAPPING Tests for eLumina.gds.map.runMapping.

    methods (Test)
        function tEmptySignalsReturnsEmptyResults(testCase)
            rs = eLumina.gds.rules.RuleSet();
            sigs = eLumina.gds.extract.SimulinkSignal.empty(1,0);
            results = eLumina.gds.map.runMapping(sigs, rs);
            testCase.verifyEmpty(results);
        end

        function tAllSignalsMapped(testCase)
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
                eLumina.gds.map.ResultStatus.Mapped, 1, 3));
            paths = arrayfun(@(r) r.IecPath.Path, results);
            testCase.verifyEqual(paths, ["esca_1in1", "esca_1in2", "esca_2in1"]);
        end

        function tMixedMappedAndUnmapped(testCase)
            r = eLumina.gds.rules.RegexRule( ...
                Pattern = "^ref(\d+)/in(\d+)$", Template = "esca_${1}in${2}");
            rs = eLumina.gds.rules.RuleSet(r);
            sigs = [ ...
                eLumina.gds.extract.SimulinkSignal("ref1/in1"), ...
                eLumina.gds.extract.SimulinkSignal("misc/orphan")];
            results = eLumina.gds.map.runMapping(sigs, rs);

            testCase.verifyEqual(results(1).Status, eLumina.gds.map.ResultStatus.Mapped);
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
            % ref2/in1 hits the explicit (rule 1) and the regex (rule 2) shadows it
            testCase.verifyTrue(results(1).IsOverride);
            testCase.verifyEqual(results(1).IecPath.Path, "override");
            testCase.verifyEqual(results(1).RuleIndex, 1);
            % ref3/in1 only hits the regex
            testCase.verifyFalse(results(2).IsOverride);
            testCase.verifyEqual(results(2).RuleIndex, 2);
        end

        function tUnmappedHasRuleIndexZero(testCase)
            r = eLumina.gds.rules.RegexRule(Pattern = "^x$", Template = "y");
            rs = eLumina.gds.rules.RuleSet(r);
            sigs = eLumina.gds.extract.SimulinkSignal("nope");
            results = eLumina.gds.map.runMapping(sigs, rs);
            testCase.verifyEqual(results.RuleIndex, 0);
            testCase.verifyEqual(results.Status, eLumina.gds.map.ResultStatus.Unmapped);
        end
    end
end
