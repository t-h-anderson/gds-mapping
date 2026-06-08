function names = portNameList(value)
    %PORTNAMELIST Normalise a get_param port-list value to a string row.
    %
    %   ModelReference port properties (InputPortNames, OutputPortNames,
    %   InputPortBusObjects, ...) come back as a struct keyed port0,
    %   port1, ... on some MATLAB releases and as a cell / string array on
    %   others. This returns a (1,:) string in port order regardless.

    if isstruct(value)
        f = string(fieldnames(value));
        nums = double(regexprep(f, "\D", ""));
        [~, order] = sort(nums);
        f = f(order);
        names = strings(1, numel(f));
        for k = 1:numel(f)
            names(k) = string(value.(f(k)));
        end
    else
        names = reshape(string(value), 1, []);
    end
end
