classdef tRunFromModel < matlab.unittest.TestCase
    %TRUNFROMMODEL Full pipeline against the DemoPlant fixture.

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
                "regex,^ctrl(\d+)/In(\d+)$,esca_ctrl${1}_in${2},"; ...
                "regex,^ctrl(\d+)/Out(\d+)$,esca_ctrl${1}_out${2},"; ...
                "regex,^In(\d+)$,esca_root_in${1},"; ...
                "regex,^Out(\d+)$,esca_root_out${1},"], ...
                "rules.csv");

            results = eLumina.gds.runFromModel( ...
                modelPath, "rules.csv", "out.csv");

            testCase.verifyEqual(numel(results), 12);

            byPath = dictionary( ...
                arrayfun(@(r) r.Signal.InstancePath, results), ...
                1:numel(results));

            % Model-ref instance ports
            testCase.verifyEqual( ...
                results(byPath("ctrl1/Out1")).IecPath.Path, ...
                "esca_ctrl1_out1");
            testCase.verifyEqual( ...
                results(byPath("ctrl2/In2")).IecPath.Path, ...
                "esca_ctrl2_in2");

            % Root ports
            testCase.verifyEqual( ...
                results(byPath("In3")).IecPath.Path, ...
                "esca_root_in3");
            testCase.verifyEqual( ...
                results(byPath("Out2")).IecPath.Path, ...
                "esca_root_out2");

            % Output CSV exists with one row per signal
            tbl = readtable("out.csv", TextType = "string");
            testCase.verifyEqual(height(tbl), 12);
        end
    end
end
