classdef tExtractSignals < matlab.unittest.TestCase
    %TEXTRACTSIGNALS Tests for eLumina.gds.extract.extractSignals against
    %   the DemoPlant fixture (controller bus-leaves).

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
        function tEmitsBusLeafSignalsPerModelRefPort(testCase)
            modelPath = fullfile(test.util.fixturesPath(), "DemoPlant.slx");
            signals = eLumina.gds.extract.extractSignals(modelPath);

            paths = arrayfun(@(s) s.fullPath(), signals);
            expected = [...
                "Controllers/ctrl1/In1.a", "Controllers/ctrl1/In1.a1", "Controllers/ctrl1/In1.a2", ...
                "Controllers/ctrl1/In2.p", "Controllers/ctrl1/In2.p1", "Controllers/ctrl1/In2.p2", ...
                "Controllers/ctrl1/Out1.a", "Controllers/ctrl1/Out1.a1", "Controllers/ctrl1/Out1.a2", ...
                "Controllers/ctrl2/In1.a", "Controllers/ctrl2/In1.a1", "Controllers/ctrl2/In1.a2", ...
                "Controllers/ctrl2/In2.p", "Controllers/ctrl2/In2.p1", "Controllers/ctrl2/In2.p2", ...
                "Controllers/ctrl2/Out1.a", "Controllers/ctrl2/Out1.a1", "Controllers/ctrl2/Out1.a2"];

            testCase.verifyEqual(sort(paths), sort(expected));
        end

        function tDistinguishesInportFromOutport(testCase)
            modelPath = fullfile(test.util.fixturesPath(), "DemoPlant.slx");
            signals = eLumina.gds.extract.extractSignals(modelPath);

            byPath = dictionary( ...
                arrayfun(@(s) s.fullPath(), signals), ...
                1:numel(signals));

            testCase.verifyEqual( ...
                signals(byPath("Controllers/ctrl1/In1.a")).PortType, "Inport");
            testCase.verifyEqual( ...
                signals(byPath("Controllers/ctrl1/Out1.a")).PortType, "Outport");
            testCase.verifyEqual( ...
                signals(byPath("Controllers/ctrl2/In2.p")).PortType, "Inport");
        end

        function tPopulatesBusField(testCase)
            modelPath = fullfile(test.util.fixturesPath(), "DemoPlant.slx");
            signals = eLumina.gds.extract.extractSignals(modelPath);
            byPath = dictionary( ...
                arrayfun(@(s) s.fullPath(), signals), ...
                1:numel(signals));

            sig = signals(byPath("Controllers/ctrl1/In1.a1"));
            testCase.verifyEqual(sig.InstancePath, "Controllers/ctrl1/In1");
            testCase.verifyEqual(sig.BusField, "a1");
        end

        function tIsIdempotentWhenModelAlreadyLoaded(testCase)
            modelPath = fullfile(test.util.fixturesPath(), "DemoPlant.slx");
            load_system(char(modelPath));
            signals1 = eLumina.gds.extract.extractSignals(modelPath);
            signals2 = eLumina.gds.extract.extractSignals(modelPath);
            testCase.verifyEqual(numel(signals1), numel(signals2));
        end

        function tMissingDataDictionaryErrors(testCase)
            tmpDir = copyDemoFixtureToTemp(testCase);
            modelPath = fullfile(tmpDir, "DemoPlant.slx");

            load_system(char(modelPath));
            set_param("DemoPlant", "DataDictionary", "MissingData.sldd");
            save_system("DemoPlant");
            close_system("DemoPlant", 0);

            testCase.verifyError( ...
                @() eLumina.gds.extract.extractSignals(string(modelPath)), ...
                "eLumina:gds:extract:dataDictionaryOpenFailed");
        end
    end
end

function tmpDir = copyDemoFixtureToTemp(testCase)
    srcDir = test.util.fixturesPath();
    tmpDir = string(tempname);
    mkdir(tmpDir);

    copyfile(fullfile(srcDir, "DemoPlant.slx"), fullfile(tmpDir, "DemoPlant.slx"));
    copyfile(fullfile(srcDir, "DemoController.slx"), ...
        fullfile(tmpDir, "DemoController.slx"));
    copyfile(fullfile(srcDir, "Data.sldd"), fullfile(tmpDir, "Data.sldd"));

    testCase.applyFixture(matlab.unittest.fixtures.PathFixture(tmpDir));
    testCase.addTeardown(@() closeIfLoaded("DemoPlant"));
    testCase.addTeardown(@() closeIfLoaded("DemoController"));
    testCase.addTeardown(@() removeTempFolder(tmpDir));
end

function closeIfLoaded(modelName)
    if bdIsLoaded(char(modelName))
        close_system(char(modelName), 0);
    end
end

function removeTempFolder(tmpDir)
    if ismember(char(tmpDir), strsplit(path, pathsep))
        rmpath(char(tmpDir));
    end
    if isfolder(tmpDir)
        rmdir(tmpDir, "s");
    end
end
