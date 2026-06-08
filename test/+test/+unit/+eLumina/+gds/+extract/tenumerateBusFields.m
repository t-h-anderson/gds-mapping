classdef tenumerateBusFields < matlab.unittest.TestCase
    %TENUMERATEBUSFIELDS Tests for nested Simulink.Bus expansion.

    methods (Test)
        function tReturnsNestedLeafPaths(testCase)
            ddPath = string(tempname) + ".sldd";
            dd = Simulink.data.dictionary.create(ddPath);
            cleanup = onCleanup(@() cleanupDictionary(dd, ddPath)); %#ok<NASGU>

            section = getSection(dd, "Design Data");

            inner = Simulink.Bus;
            inner.Elements = [makeElement("x"), makeElement("y")];
            outer = Simulink.Bus;
            outer.Elements = [ ...
                makeElement("inner", DataType = "Bus: InnerBus"), ...
                makeElement("z")];

            addEntry(section, "InnerBus", inner);
            addEntry(section, "OuterBus", outer);
            saveChanges(dd);

            fields = eLumina.gds.extract.enumerateBusFields("OuterBus", dd);

            testCase.verifyEqual(fields, ["inner.x", "inner.y", "z"]);
        end
    end
end

function elem = makeElement(name, nvp)
    arguments
        name (1,1) string
        nvp.DataType (1,1) string = "double"
    end

    elem = Simulink.BusElement;
    elem.Name = char(name);
    elem.DataType = char(nvp.DataType);
end

function cleanupDictionary(dd, ddPath)
    close(dd);
    if isfile(ddPath)
        delete(ddPath);
    end
end
