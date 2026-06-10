classdef tRunFromModel < matlab.unittest.TestCase
    %TRUNFROMMODEL Full pipeline against DemoPlant: extract -> trace to
    %   plant -> match plant-space rules -> results.

    methods (TestMethodTeardown)
        function closeLoadedModels(testCase) %#ok<MANU>
            for name = ["DemoPlant", "DemoController", "Subsystem"]
                if bdIsLoaded(char(name))
                    close_system(char(name), 0);
                end
            end
        end
    end

    methods (Test)
        function tDemoModelTracesToPlantThenMaps(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);

            modelPath = fullfile(test.util.fixturesPath(), "DemoPlant.slx");
            writelines([ ...
                "Kind,SimulinkPattern,IecPathTemplate,Notes"; ...
                "explicit,fromPlant.a2_p,esca_override,override"; ...
                "regex,^fromPlant\.(\w+)$,MMXU.${1},sensors"; ...
                "regex,^pOut\.(\w+)$,XCBR_out.${1},"; ...
                "regex,^pOut1\.(\w+)$,XCBR_in1.${1},"; ...
                "regex,^Inputs/Out1\.(\w+)$,HMI.${1},params"], ...
                "rules.csv");

            results = eLumina.gds.runFromModel( ...
                modelPath, "rules.csv", "out.csv");

            testCase.verifyEqual(numel(results), 18);

            byPath = dictionary( ...
                arrayfun(@(r) r.Signal.fullPath(), results), ...
                1:numel(results));

            % Input leaf traces to a plant sensor and maps in plant space
            r = results(byPath("CtrlDsp1/In1.a"));
            testCase.verifyEqual(r.PlantPath, "fromPlant.a_p");
            testCase.verifyEqual(r.IecPath.Path, "MMXU.a_p");
            testCase.verifyEqual(r.Status, eLumina.gds.map.ResultStatus.Mapped);

            % Both controllers read the same plant sensor -> same IEC path
            r2 = results(byPath("CtrlDsp2/In1.a"));
            testCase.verifyEqual(r2.IecPath.Path, "MMXU.a_p");

            % Explicit override on the plant path shadows the regex
            ov = results(byPath("CtrlDsp1/In1.a2"));
            testCase.verifyEqual(ov.IecPath.Path, "esca_override");
            testCase.verifyTrue(ov.IsOverride);

            % Output leaf traces forward to a plant input
            o = results(byPath("CtrlDsp1/Out1.a"));
            testCase.verifyEqual(o.PlantPath, "pOut.a_p");
            testCase.verifyEqual(o.IecPath.Path, "XCBR_out.a_p");

            % Parameter traces to the Inputs subsystem
            p = results(byPath("CtrlDsp1/Inport.p"));
            testCase.verifyEqual(p.PlantPath, "Inputs/Out1.p_ext");
            testCase.verifyEqual(p.IecPath.Path, "HMI.p_ext");

            tbl = readtable("out.csv", TextType = "string");
            testCase.verifyEqual(height(tbl), 18);
            testCase.verifyTrue(ismember("PlantPath", ...
                string(tbl.Properties.VariableNames)));
            testCase.verifyTrue(ismember("RuleOrigin", ...
                string(tbl.Properties.VariableNames)));
            testCase.verifyTrue(ismember("Warning", ...
                string(tbl.Properties.VariableNames)));
        end

        function tLayeredDemoFixtureUsesOverrideAndProjectVariables(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);

            fixtures = test.util.fixturesPath();
            modelPath = fullfile(fixtures, "DemoPlant.slx");
            overridePath = fullfile(fixtures, "demoOverrideRules.csv");
            basePath = fullfile(fixtures, "demoBaseRules.csv");

            results = eLumina.gds.runFromModel( ...
                modelPath, overridePath, "out.csv", ...
                BaseRulesCsv = basePath);

            testCase.verifyEqual(numel(results), 18);

            byPath = dictionary( ...
                arrayfun(@(r) r.Signal.fullPath(), results), ...
                1:numel(results));

            measured = results(byPath("CtrlDsp1/In1.a"));
            testCase.verifyEqual(measured.IecPath.Path, ...
                "MMXU1.PhV.a_p.cVal.mag.f");
            testCase.verifyEqual(measured.RuleOrigin, "demoBaseRules.csv:5");
            testCase.verifyEqual(measured.Warning, "");

            overridden = results(byPath("CtrlDsp1/In1.a2"));
            testCase.verifyEqual(overridden.IecPath.Path, "esca_special_override");
            testCase.verifyEqual(overridden.RuleOrigin, ...
                "demoOverrideRules.csv:4");
            testCase.verifyTrue(overridden.IsOverride);

            param = results(byPath("CtrlDsp1/Inport.p"));
            testCase.verifyEqual(param.IecPath.Path, "GGIO1.p_ext.setMag.f");
        end

        function tSingleFileDemoFixtureAlsoUsesProjectVariables(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);

            fixtures = test.util.fixturesPath();
            modelPath = fullfile(fixtures, "DemoPlant.slx");
            rulesPath = fullfile(fixtures, "demoRules.csv");

            results = eLumina.gds.runFromModel(modelPath, rulesPath, "out.csv");

            byPath = dictionary( ...
                arrayfun(@(r) r.Signal.fullPath(), results), ...
                1:numel(results));

            overridden = results(byPath("CtrlDsp1/In1.a2"));
            testCase.verifyEqual(overridden.IecPath.Path, "esca_special_override");
            testCase.verifyEqual(overridden.RuleOrigin, "demoRules.csv:5");

            measured = results(byPath("CtrlDsp1/In1.a"));
            testCase.verifyEqual(measured.IecPath.Path, ...
                "MMXU1.PhV.a_p.cVal.mag.f");
            testCase.verifyEqual(measured.RuleOrigin, "demoRules.csv:6");
        end
    end
end
