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

    try
        section = getSection(dd, 'Design Data');
        entry = getEntry(section, char(busName));
        bus = getValue(entry);
    catch
        fields = string.empty(1,0);
        return
    end

    if ~isa(bus, "Simulink.Bus")
        fields = string.empty(1,0);
        return
    end

    fields = string({bus.Elements.Name});
end
