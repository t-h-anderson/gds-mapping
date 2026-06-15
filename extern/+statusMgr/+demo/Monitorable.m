classdef Monitorable < statusMgr.monitorable.Monitorable
    
    methods
        
        function showError(obj, message)
            status = statusMgr.Status("Error", message);
            obj.setStatus(status);
        end
    end
end