classdef tRunFromModel < matlab.unittest.TestCase
    %TRUNFROMMODEL Full pipeline against DemoPlant: extract -> trace to
    %   plant -> match plant-space rules -> results.

    methods (TestMethodTeardown)
        function closeLoadedModels(testCase) %#ok<MANU>
            for name = ["DemoPlant", "DemoController"]
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
                "explicit,Plant/pIn.a2_p,esca_override,override"; ...
                "regex,^Plant/pIn\.(\w+)$,MMXU.${1},sensors"; ...
                "regex,^Plant/pOut\.(\w+)$,XCBR_out.${1},"; ...
                "regex,^Plant/In1\.(\w+)$,XCBR_in1.${1},"; ...
                "regex,^Inputs/Out1\.(\w+)$,HMI.${1},params"], ...
                "rules.csv");

            results = eLumina.gds.runFromModel( ...
                modelPath, "rules.csv", "out.csv");

            testCase.verifyEqual(numel(results), 18);

            byPath = dictionary( ...
                arrayfun(@(r) r.Signal.fullPath(), results), ...
                1:numel(results));

            % Input leaf traces to a plant sensor and maps in plant space
            r = results(byPath("Controllers/ctrl1/In1.a"));
            testCase.verifyEqual(r.PlantPath, "Plant/pIn.a_p");
            testCase.verifyEqual(r.IecPath.Path, "MMXU.a_p");
            testCase.verifyEqual(r.Status, eLumina.gds.map.ResultStatus.Mapped);

            % Both controllers read the same plant sensor -> same IEC path
            r2 = results(byPath("Controllers/ctrl2/In1.a"));
            testCase.verifyEqual(r2.IecPath.Path, "MMXU.a_p");

            % Explicit override on the plant path shadows the regex
            ov = results(byPath("Controllers/ctrl1/In1.a2"));
            testCase.verifyEqual(ov.IecPath.Path, "esca_override");
            testCase.verifyTrue(ov.IsOverride);

            % Output leaf traces forward to a plant input
            o = results(byPath("Controllers/ctrl1/Out1.a"));
            testCase.verifyEqual(o.PlantPath, "Plant/pOut.a_p");
            testCase.verifyEqual(o.IecPath.Path, "XCBR_out.a_p");

            % Parameter traces to the Inputs subsystem
            p = results(byPath("Controllers/ctrl1/In2.p"));
            testCase.verifyEqual(p.PlantPath, "Inputs/Out1.p_ext");
            testCase.verifyEqual(p.IecPath.Path, "HMI.p_ext");

            tbl = readtable("out.csv", TextType = "string");
            testCase.verifyEqual(height(tbl), 18);
            testCase.verifyTrue(ismember("PlantPath", ...
                string(tbl.Properties.VariableNames)));
        end
    end
end
