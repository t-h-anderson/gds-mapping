function fields = enumerateBusFields(busName, dd)
    %ENUMERATEBUSFIELDS Leaf field names for a Simulink.Bus in a data dictionary.
    %
    %   fields = enumerateBusFields("InBus", dd)
    %
    %   Returns a (1,:) string array of element names. Nested buses are
    %   currently flattened by emitting the element name as-is (recursion
    %   into nested bus elements is a follow-up when we encounter a real
    %   model that needs it).
    %
    %   Returns string.empty(1,0) if the bus isn't found or the entry
    %   isn't a Simulink.Bus.

    arguments
        busName (1,1) string
        dd (1,1) Simulink.data.Dictionary
    end

    fields = enumerateBusFieldsImpl(busName, dd, "", string.empty(1,0));
end

function fields = enumerateBusFieldsImpl(busName, dd, prefix, ancestry)
    bus = resolveBus(busName, dd);
    if isempty(bus)
        fields = string.empty(1,0);
        return
    end
    if any(ancestry == busName)
        error("eLumina:gds:extract:cyclicBusDefinition", ...
            "Bus '%s' references itself recursively.", busName);
    end

    ancestry = [ancestry, busName];
    chunks = cell(1,0);
    for k = 1:numel(bus.Elements)
        elem = bus.Elements(k);
        elemName = string(elem.Name);
        fullName = qualifyField(prefix, elemName);
        nestedBus = nestedBusName(elem.DataType);
        if nestedBus == ""
            chunks{end+1} = fullName; %#ok<AGROW>
            continue
        end
        nestedFields = enumerateBusFieldsImpl(nestedBus, dd, fullName, ancestry);
        if isempty(nestedFields)
            error("eLumina:gds:extract:missingNestedBus", ...
                "Bus '%s' references nested bus '%s' via element '%s'.", ...
                busName, nestedBus, fullName);
        end
        chunks{end+1} = nestedFields; %#ok<AGROW>
    end
    fields = [chunks{:}];
end

function bus = resolveBus(busName, dd)
    try
        section = getSection(dd, 'Design Data');
        entry = getEntry(section, char(busName));
        bus = getValue(entry);
    catch
        bus = [];
        return
    end

    if ~isa(bus, "Simulink.Bus")
        bus = [];
    end
end

function name = nestedBusName(dataType)
    name = "";
    dataType = strip(string(dataType));
    if startsWith(dataType, "Bus:")
        name = strip(extractAfter(dataType, "Bus:"));
    end
end

function fullName = qualifyField(prefix, name)
    if prefix == ""
        fullName = name;
    else
        fullName = prefix + "." + name;
    end
end
