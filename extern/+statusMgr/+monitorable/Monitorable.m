classdef (Abstract) Monitorable < handle
    %MONITORABLE Able to be monitored by an statusMgrStack

    events
        StatusChanged
    end

    methods
        
        function setStatus(obj, status)
            arguments
                obj (1,1)
                status (1,1) statusMgr.Status
            end
            statusData = statusMgr.monitorable.StatusEventData(status);
            notify(obj, "StatusChanged", statusData);
        end

    end

end