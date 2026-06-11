classdef tExtractSignals < matlab.unittest.TestCase
    %TEXTRACTSIGNALS Tests for eLumina.gds.extract.extractSignals against
    %   the ControlLane fixture (controller bus-leaves).

    methods (TestMethodTeardown)
        function closeLoadedModels(testCase) %#ok<MANU>
            for name = ["ControlLane", "DemoPlant", "DemoController", "Subsystem"]
                if bdIsLoaded(char(name))
                    close_system(char(name), 0);
                end
            end
        end
    end

    methods (Test)
        function tEmitsBusLeafSignalsPerModelRefPort(testCase)
            modelPath = fullfile(test.util.fixturesPath(), "ControlLane.slx");
            signals = eLumina.gds.extract.extractSignals(modelPath);

            paths = arrayfun(@(s) s.fullPath(), signals);
            expected = [...
                "CtrlDsp1/In1.a", "CtrlDsp1/In1.a1", "CtrlDsp1/In1.a2", ...
                "CtrlDsp1/Inport.p", "CtrlDsp1/Inport.p1", "CtrlDsp1/Inport.p2", ...
                "CtrlDsp1/Out1.a", "CtrlDsp1/Out1.a1", "CtrlDsp1/Out1.a2", ...
                "CtrlDsp2/In1.a", "CtrlDsp2/In1.a1", "CtrlDsp2/In1.a2", ...
                "CtrlDsp2/Inport.p", "CtrlDsp2/Inport.p1", "CtrlDsp2/Inport.p2", ...
                "CtrlDsp2/Out1.a", "CtrlDsp2/Out1.a1", "CtrlDsp2/Out1.a2"];

            testCase.verifyEqual(sort(paths), sort(expected));
        end

        function tDistinguishesInportFromOutport(testCase)
            modelPath = fullfile(test.util.fixturesPath(), "ControlLane.slx");
            signals = eLumina.gds.extract.extractSignals(modelPath);

            byPath = dictionary( ...
                arrayfun(@(s) s.fullPath(), signals), ...
                1:numel(signals));

            testCase.verifyEqual( ...
                signals(byPath("CtrlDsp1/In1.a")).PortType, "Inport");
            testCase.verifyEqual( ...
                signals(byPath("CtrlDsp1/Out1.a")).PortType, "Outport");
            testCase.verifyEqual( ...
                signals(byPath("CtrlDsp2/Inport.p")).PortType, "Inport");
        end

        function tPopulatesBusField(testCase)
            modelPath = fullfile(test.util.fixturesPath(), "ControlLane.slx");
            signals = eLumina.gds.extract.extractSignals(modelPath);
            byPath = dictionary( ...
                arrayfun(@(s) s.fullPath(), signals), ...
                1:numel(signals));

            sig = signals(byPath("CtrlDsp1/In1.a1"));
            testCase.verifyEqual(sig.InstancePath, "CtrlDsp1/In1");
            testCase.verifyEqual(sig.BusField, "a1");
        end

        function tIsIdempotentWhenModelAlreadyLoaded(testCase)
            modelPath = fullfile(test.util.fixturesPath(), "ControlLane.slx");
            load_system(char(modelPath));
            signals1 = eLumina.gds.extract.extractSignals(modelPath);
            signals2 = eLumina.gds.extract.extractSignals(modelPath);
            testCase.verifyEqual(numel(signals1), numel(signals2));
        end

        function tMissingDataDictionaryErrors(testCase)
            tmpDir = copyDemoFixtureToTemp(testCase);
            modelPath = fullfile(tmpDir, "ControlLane.slx");

            load_system(char(modelPath));
            set_param("ControlLane", "DataDictionary", "MissingData.sldd");
            save_system("ControlLane");
            close_system("ControlLane", 0);

            testCase.verifyError( ...
                @() eLumina.gds.extract.extractSignals(string(modelPath)), ...
                "eLumina:gds:extract:dataDictionaryOpenFailed");
        end

        function tControllerPrefixConfigOverridesDefaultSelection(testCase)
            tmpDir = copyDemoFixtureToTemp(testCase);
            writelines(jsonencode(struct( ...
                "controllerModelRefPrefixes", "xgds")), ...
                fullfile(tmpDir, "gds-config.json"));

            signals = eLumina.gds.extract.extractSignals( ...
                fullfile(tmpDir, "ControlLane.slx"));
            paths = arrayfun(@(s) s.fullPath(), signals);

            testCase.verifyNotEmpty(paths);
            testCase.verifyTrue(all(startsWith(paths, "xGDSMapping/")));
        end
    end
end

function tmpDir = copyDemoFixtureToTemp(testCase)
    Simulink.data.dictionary.closeAll;

    srcDir = test.util.fixturesPath();
    tmpDir = string(tempname);
    mkdir(tmpDir);

    copyfile(fullfile(srcDir, "ControlLane.slx"), fullfile(tmpDir, "ControlLane.slx"));
    copyfile(fullfile(srcDir, "DemoPlant.slx"), fullfile(tmpDir, "DemoPlant.slx"));
    copyfile(fullfile(srcDir, "DemoController.slx"), ...
        fullfile(tmpDir, "DemoController.slx"));
    copyfile(fullfile(srcDir, "Subsystem.slx"), ...
        fullfile(tmpDir, "Subsystem.slx"));
    copyfile(fullfile(srcDir, "mapToPlant.m"), ...
        fullfile(tmpDir, "mapToPlant.m"));
    copyfile(fullfile(srcDir, "Data.sldd"), fullfile(tmpDir, "Data.sldd"));
    copyfile(fullfile(srcDir, "gds-config.json"), ...
        fullfile(tmpDir, "gds-config.json"));

    testCase.applyFixture(matlab.unittest.fixtures.PathFixture(tmpDir));
    testCase.addTeardown(@() closeIfLoaded("ControlLane"));
    testCase.addTeardown(@() closeIfLoaded("DemoPlant"));
    testCase.addTeardown(@() closeIfLoaded("DemoController"));
    testCase.addTeardown(@() closeIfLoaded("Subsystem"));
    testCase.addTeardown(@() Simulink.data.dictionary.closeAll);
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
