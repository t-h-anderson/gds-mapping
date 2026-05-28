classdef ttraceToPlant < matlab.unittest.TestCase
    %TTRACETOPLANT Tests for eLumina.gds.extract.traceToPlant against the
    %   DemoPlant fixture (needs Simulink).

    properties (Constant)
        ModelPath = fullfile(test.util.fixturesPath(), "DemoPlant.slx")
    end

    methods (TestClassSetup)
        function loadModel(testCase)
            modelPath = ttraceToPlant.ModelPath;
            folder = fileparts(modelPath);
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(folder));
            if ~bdIsLoaded("DemoPlant")
                load_system(modelPath);
            end
            testCase.addTeardown(@() closeModels());
            function closeModels()
                for name = ["DemoPlant", "DemoController"]
                    if bdIsLoaded(char(name))
                        close_system(char(name), 0);
                    end
                end
            end
        end
    end

    methods (Test)
        function tInputTracesBackToPlantOutput(testCase)
            sig = eLumina.gds.extract.SimulinkSignal( ...
                "ctrl1/In1", PortType = "Inport", BusField = "a");
            ps = eLumina.gds.extract.traceToPlant("DemoPlant", sig);
            testCase.verifyNotEmpty(ps);
            testCase.verifyEqual(ps.fullPath(), "Plant/pIn.a_p");
        end

        function tOutputTracesForwardToPlantInput(testCase)
            sig = eLumina.gds.extract.SimulinkSignal( ...
                "ctrl1/Out1", PortType = "Outport", BusField = "a");
            ps = eLumina.gds.extract.traceToPlant("DemoPlant", sig);
            testCase.verifyNotEmpty(ps);
            testCase.verifyEqual(ps.fullPath(), "Plant/pOut.a_p");
        end

        function tParameterTracesToConstant(testCase)
            sig = eLumina.gds.extract.SimulinkSignal( ...
                "ctrl1/In2", PortType = "Inport", BusField = "p");
            ps = eLumina.gds.extract.traceToPlant("DemoPlant", sig);
            testCase.verifyNotEmpty(ps);
            testCase.verifyEqual(ps.fullPath(), "Constant.p_ext");
        end

        function tBothControllersShareTheSamePlantInput(testCase)
            s1 = eLumina.gds.extract.SimulinkSignal( ...
                "ctrl1/In1", PortType = "Inport", BusField = "a2");
            s2 = eLumina.gds.extract.SimulinkSignal( ...
                "ctrl2/In1", PortType = "Inport", BusField = "a2");
            p1 = eLumina.gds.extract.traceToPlant("DemoPlant", s1);
            p2 = eLumina.gds.extract.traceToPlant("DemoPlant", s2);
            testCase.verifyEqual(p1.fullPath(), "Plant/pIn.a2_p");
            testCase.verifyEqual(p2.fullPath(), "Plant/pIn.a2_p");
        end

        function tCtrl2OutputTracesToPlantIn1(testCase)
            sig = eLumina.gds.extract.SimulinkSignal( ...
                "ctrl2/Out1", PortType = "Outport", BusField = "a1");
            ps = eLumina.gds.extract.traceToPlant("DemoPlant", sig);
            testCase.verifyEqual(ps.fullPath(), "Plant/In1.a1_p");
        end
    end
end
