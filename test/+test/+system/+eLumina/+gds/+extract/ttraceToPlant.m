classdef ttraceToPlant < matlab.unittest.TestCase
    %TTRACETOPLANT Tests for eLumina.gds.extract.traceToPlant against the
    %   ControlLane fixture: controller-facing ModelReference blocks at the
    %   top level, plant translation via helper-backed MATLAB Function
    %   blocks, and parameters fed through an Inputs subsystem.

    methods (TestClassSetup)
        function loadModel(testCase)
            modelPath = fullfile(test.util.fixturesPath(), "ControlLane.slx");
            folder = fileparts(modelPath);
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(folder));
            if ~bdIsLoaded("ControlLane")
                load_system(modelPath);
            end
            testCase.addTeardown(@() closeModels());
            function closeModels()
                for name = ["ControlLane", "DemoPlant", "DemoController", "Subsystem"]
                    if bdIsLoaded(char(name))
                        close_system(char(name), 0);
                    end
                end
            end
        end
    end

    methods (Test)
        function tInputTracesBackThroughControllersToPlant(testCase)
            sig = eLumina.gds.extract.SimulinkSignal( ...
                "CtrlDsp1/In1", PortType = "Inport", BusField = "a");
            ps = eLumina.gds.extract.traceToPlant("ControlLane", sig);
            testCase.verifyNotEmpty(ps);
            testCase.verifyEqual(ps.fullPath(), "fromPlant.a_p");
        end

        function tOutputTracesForwardToTopLevelOutport(testCase)
            sig = eLumina.gds.extract.SimulinkSignal( ...
                "CtrlDsp1/Out1", PortType = "Outport", BusField = "a");
            ps = eLumina.gds.extract.traceToPlant("ControlLane", sig);
            testCase.verifyNotEmpty(ps);
            testCase.verifyEqual(ps.fullPath(), "plantIn.pOut.a_p");
        end

        function tParameterTracesToInputsSubsystem(testCase)
            sig = eLumina.gds.extract.SimulinkSignal( ...
                "CtrlDsp1/Inport", PortType = "Inport", BusField = "p");
            ps = eLumina.gds.extract.traceToPlant("ControlLane", sig);
            testCase.verifyNotEmpty(ps);
            testCase.verifyEqual(ps.fullPath(), "params.p_ext");
        end

        function tBothControllersShareTheSamePlantInput(testCase)
            s1 = eLumina.gds.extract.SimulinkSignal( ...
                "CtrlDsp1/In1", PortType = "Inport", BusField = "a2");
            s2 = eLumina.gds.extract.SimulinkSignal( ...
                "CtrlDsp2/In1", PortType = "Inport", BusField = "a2");
            p1 = eLumina.gds.extract.traceToPlant("ControlLane", s1);
            p2 = eLumina.gds.extract.traceToPlant("ControlLane", s2);
            testCase.verifyEqual(p1.fullPath(), "fromPlant.a2_p");
            testCase.verifyEqual(p2.fullPath(), "fromPlant.a2_p");
        end

        function tCtrl2OutputTracesToSecondTopLevelOutport(testCase)
            sig = eLumina.gds.extract.SimulinkSignal( ...
                "CtrlDsp2/Out1", PortType = "Outport", BusField = "a1");
            ps = eLumina.gds.extract.traceToPlant("ControlLane", sig);
            testCase.verifyEqual(ps.fullPath(), "plantIn.pOut1.a1_p");
        end

        function tRootPortsTraceToThemselves(testCase)
            modelPath = createRootPortModel(testCase);
            signals = eLumina.gds.extract.extractSignals(modelPath);
            [~, modelName] = fileparts(modelPath);
            [plantPaths, isInternal] = eLumina.gds.extract.tracePlantPaths( ...
                string(modelName), signals);

            byPath = dictionary( ...
                arrayfun(@(s) s.fullPath(), signals), ...
                1:numel(signals));

            testCase.verifyEqual(plantPaths(byPath("In1")), "In1");
            testCase.verifyEqual(plantPaths(byPath("Out1")), "Out1");
            testCase.verifyFalse(any(isInternal));
        end

        function tBranchedOutputErrorsWhenTraceIsAmbiguous(testCase)
            modelPath = createAmbiguousBranchModel(testCase);
            signals = eLumina.gds.extract.extractSignals(modelPath);
            idx = find(arrayfun(@(s) s.fullPath() == "ctrl1/Out1", signals), 1);
            testCase.assertNotEmpty(idx);

            [~, modelName] = fileparts(modelPath);
            testCase.verifyError( ...
                @() eLumina.gds.extract.traceToPlant(string(modelName), signals(idx)), ...
                "eLumina:gds:extract:ambiguousTrace");
        end
    end
end

function modelPath = createRootPortModel(testCase)
    tmpDir = string(tempname);
    mkdir(tmpDir);
    modelName = "RootPortFixture";
    modelPath = fullfile(tmpDir, modelName + ".slx");

    if bdIsLoaded(char(modelName))
        close_system(char(modelName), 0);
    end

    new_system(char(modelName));
    add_block("simulink/Sources/In1", char(modelName + "/In1"));
    add_block("simulink/Sinks/Out1", char(modelName + "/Out1"));
    add_line(char(modelName), "In1/1", "Out1/1");
    save_system(char(modelName), char(modelPath));
    close_system(char(modelName), 0);

    testCase.addTeardown(@() closeIfLoaded(modelName));
    testCase.addTeardown(@() removeTempFolder(tmpDir));
end

function modelPath = createAmbiguousBranchModel(testCase)
    tmpDir = string(tempname);
    mkdir(tmpDir);
    testCase.applyFixture(matlab.unittest.fixtures.PathFixture(tmpDir));

    ctrlName = "BranchFixtureController";
    topName = "BranchFixtureTop";
    ctrlPath = fullfile(tmpDir, ctrlName + ".slx");
    modelPath = fullfile(tmpDir, topName + ".slx");

    if bdIsLoaded(char(ctrlName))
        close_system(char(ctrlName), 0);
    end
    if bdIsLoaded(char(topName))
        close_system(char(topName), 0);
    end

    new_system(char(ctrlName));
    add_block("simulink/Sources/Constant", char(ctrlName + "/Const"), ...
        "Value", "1");
    add_block("simulink/Sinks/Out1", char(ctrlName + "/Out1"));
    add_line(char(ctrlName), "Const/1", "Out1/1");
    save_system(char(ctrlName), char(ctrlPath));
    close_system(char(ctrlName), 0);

    new_system(char(topName));
    add_block("simulink/Ports & Subsystems/Model", char(topName + "/ctrl1"), ...
        "ModelName", char(ctrlName));
    add_block("simulink/Ports & Subsystems/Subsystem", char(topName + "/Plant"));
    add_block("simulink/Ports & Subsystems/Subsystem", char(topName + "/Logger"));
    add_line(char(topName), "ctrl1/1", "Plant/1");
    add_line(char(topName), "ctrl1/1", "Logger/1", "autorouting", "on");
    save_system(char(topName), char(modelPath));
    close_system(char(topName), 0);

    testCase.addTeardown(@() closeIfLoaded(topName));
    testCase.addTeardown(@() closeIfLoaded(ctrlName));
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
