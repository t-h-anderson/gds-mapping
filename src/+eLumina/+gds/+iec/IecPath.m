classdef IecPath
    %IECPATH IEC-61850 path. Thin wrapper; structural parsing deferred.

    properties (SetAccess = protected)
        Path (1,1) string
    end

    methods
        function obj = IecPath(path)
            arguments
                path (1,1) string
            end
            obj.Path = path;
        end

        function s = string(obj)
            s = obj.Path;
        end
    end
end
