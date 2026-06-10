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

        function tFlagsOverrideAndShadowsWhenLowerRuleAlsoMatches(testCase)
            exp = eLumina.gds.rules.ExplicitRule( ...
                Path = "ref2/in1", Target = "override");
            rgx = eLumina.gds.rules.RegexRule( ...
                Pattern = "^ref(\d+)/in(\d+)$", Template = "shadowed");
            rs = eLumina.gds.rules.RuleSet([exp, rgx]);
            sigs = [ ...
                eLumina.gds.extract.SimulinkSignal("ref2/in1"), ...
                eLumina.gds.extract.SimulinkSignal("ref3/in1")];
            results = eLumina.gds.map.runMapping(sigs, rs);
            % ref2/in1 hits rule 1; rule 2 also matches and is shadowed
            testCase.verifyTrue(results(1).IsOverride);
            testCase.verifyEqual(results(1).Shadows, 2);
            testCase.verifyEqual(results(1).IecPath.Path, "override");
            testCase.verifyEqual(results(1).RuleIndex, 1);
            % ref3/in1 only hits rule 2 — no shadows
            testCase.verifyFalse(results(2).IsOverride);
            testCase.verifyEmpty(results(2).Shadows);
            testCase.verifyEqual(results(2).RuleIndex, 2);
        end

        function tMatchesAgainstPlantPathsWhenProvided(testCase)
            r = eLumina.gds.rules.RegexRule( ...
                Pattern = "^Plant/pIn\.(\w+)$", Template = "MMXU.${1}");
            rs = eLumina.gds.rules.RuleSet(r);
            sig = eLumina.gds.extract.SimulinkSignal( ...
                "Controllers/ctrl1/In1", PortType = "Inport", BusField = "a");
            results = eLumina.gds.map.runMapping(sig, rs, ...
                PlantPaths = "Plant/pIn.a_p");
            testCase.verifyEqual(results.Status, eLumina.gds.map.ResultStatus.Mapped);
            testCase.verifyEqual(results.PlantPath, "Plant/pIn.a_p");
            testCase.verifyEqual(results.IecPath.Path, "MMXU.a_p");
        end

        function tInternalSignalSkipsMatching(testCase)
            rs = eLumina.gds.rules.RuleSet( ...
                eLumina.gds.rules.RegexRule(Pattern = "^.+$", Template = "x"));
            sig = eLumina.gds.extract.SimulinkSignal( ...
                "Controllers/ctrl1/State", BusField = "z");
            results = eLumina.gds.map.runMapping(sig, rs, ...
                PlantPaths = "", IsInternal = true);
            testCase.verifyEqual(results.Status, eLumina.gds.map.ResultStatus.Internal);
            testCase.verifyEqual(results.PlantPath, "");
            testCase.verifyEqual(results.IecPath.Path, "");
        end

        function tInternalSignalCanUseTracedLinkedSignal(testCase)
            rs = eLumina.gds.rules.RuleSet();
            sig = eLumina.gds.extract.SimulinkSignal( ...
                "Lane1/toOtherLane", BusField = "toCtrl1.a");

            results = eLumina.gds.map.runMapping(sig, rs, ...
                PlantPaths = "", IsInternal = true, ...
                LinkedSignalPaths = "Lane2/fromOtherLane.toCtrl1.a");

            testCase.verifyEqual(results.Status, ...
                eLumina.gds.map.ResultStatus.SignalMapped);
            testCase.verifyEqual(results.LinkedSignalPath, ...
                "Lane2/fromOtherLane.toCtrl1.a");
            testCase.verifyEqual(results.PlantPath, "");
            testCase.verifyEqual(results.IecPath.Path, "");
        end

        function tLengthMismatchErrors(testCase)
            rs = eLumina.gds.rules.RuleSet();
            sigs = [ ...
                eLumina.gds.extract.SimulinkSignal("a"), ...
                eLumina.gds.extract.SimulinkSignal("b")];
            testCase.verifyError( ...
                @() eLumina.gds.map.runMapping(sigs, rs, PlantPaths = "only-one"), ...
                "eLumina:gds:map:lengthMismatch");
        end

        function tUnmappedHasRuleIndexZero(testCase)
            r = eLumina.gds.rules.RegexRule(Pattern = "^x$", Template = "y");
            rs = eLumina.gds.rules.RuleSet(r);
            sigs = eLumina.gds.extract.SimulinkSignal("nope");
            results = eLumina.gds.map.runMapping(sigs, rs);
            testCase.verifyEqual(results.RuleIndex, 0);
            testCase.verifyEqual(results.Status, eLumina.gds.map.ResultStatus.Unmapped);
        end

        function tBrokenRuleBeatsLaterFallback(testCase)
            brokenRule = eLumina.gds.rules.ExplicitRule( ...
                Path = "ref1/in1", Target = "iec_${projectSuffix}");
            fallbackRule = eLumina.gds.rules.ExplicitRule( ...
                Path = "ref1/in1", Target = "fallback");
            rs = eLumina.gds.rules.RuleSet([brokenRule, fallbackRule]);
            sigs = eLumina.gds.extract.SimulinkSignal("ref1/in1");
            results = eLumina.gds.map.runMapping(sigs, rs);

            testCase.verifyEqual(results.Status, eLumina.gds.map.ResultStatus.Broken);
            testCase.verifyEqual(results.IecPath.Path, "");
            testCase.verifyEqual(results.RuleIndex, 1);
            testCase.verifyTrue(results.IsOverride);
            testCase.verifyEqual(results.Shadows, 2);
            testCase.verifySubstring(results.Warning, "projectSuffix");
        end

        function tBrokenPatternRuleBeatsLaterFallback(testCase)
            brokenRule = eLumina.gds.rules.RegexRule( ...
                Pattern = "^ref_${projectSuffix}$", ...
                Template = "iec_${projectSuffix}");
            fallbackRule = eLumina.gds.rules.ExplicitRule( ...
                Path = "ref_demo", Target = "fallback");
            rs = eLumina.gds.rules.RuleSet([brokenRule, fallbackRule]);
            sigs = eLumina.gds.extract.SimulinkSignal("ref_demo");
            results = eLumina.gds.map.runMapping(sigs, rs);

            testCase.verifyEqual(results.Status, ...
                eLumina.gds.map.ResultStatus.Broken);
            testCase.verifyEqual(results.IecPath.Path, "");
            testCase.verifyEqual(results.RuleIndex, 1);
            testCase.verifyTrue(results.IsOverride);
            testCase.verifyEqual(results.Shadows, 2);
            testCase.verifySubstring(results.Warning, "Pattern");
        end
    end
end
