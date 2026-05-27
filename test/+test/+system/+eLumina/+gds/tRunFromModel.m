classdef tRunFromModel < matlab.unittest.TestCase
    %TRUNFROMMODEL Full pipeline against the DemoPlant fixture (bus leaves).

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
        function tDemoModelEndToEnd(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);

            modelPath = fullfile(test.util.fixturesPath(), "DemoPlant.slx");
            writelines([ ...
                "Kind,SimulinkPattern,IecPathTemplate,Notes"; ...
                "regex,^ctrl(\d+)/In1\.(\w+)$,esca_ctrl${1}_in_${2},"; ...
                "regex,^ctrl(\d+)/In2\.(\w+)$,esca_ctrl${1}_param_${2},"; ...
                "regex,^ctrl(\d+)/Out1\.(\w+)$,esca_ctrl${1}_out_${2},"], ...
                "rules.csv");

            results = eLumina.gds.runFromModel( ...
                modelPath, "rules.csv", "out.csv");

            testCase.verifyEqual(numel(results), 18);

            byPath = dictionary( ...
                arrayfun(@(r) r.Signal.fullPath(), results), ...
                1:numel(results));

            % Bus-leaf signals across both controller instances
            testCase.verifyEqual( ...
                results(byPath("ctrl1/In1.a")).IecPath.Path, ...
                "esca_ctrl1_in_a");
            testCase.verifyEqual( ...
                results(byPath("ctrl2/Out1.a2")).IecPath.Path, ...
                "esca_ctrl2_out_a2");
            testCase.verifyEqual( ...
                results(byPath("ctrl1/In2.p1")).IecPath.Path, ...
                "esca_ctrl1_param_p1");

            % Output CSV exists with one row per leaf signal
            tbl = readtable("out.csv", TextType = "string");
            testCase.verifyEqual(height(tbl), 18);
        end
    end
end
