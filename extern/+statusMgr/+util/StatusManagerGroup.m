classdef StatusManagerGroup < handle
    %STATUSMANAGERGROUP A single Stack with a heterogeneous array of views.
    %
    % Managed by statusMgr.util.StatusManager; not intended for direct use.
    %
    % All views in the group are connected to the same Stack. Adding a view
    % (including an existing one) re-connects it to this group's Stack.

    properties (SetAccess = protected)
        Stack
        Views (1,:) statusMgr.internal.view.StatusViewInterface = ...
            statusMgr.internal.view.StatusViewInterface.empty(1,0)
    end

    methods

        function obj = StatusManagerGroup()
            obj.Stack = statusMgr.Stack();
        end

        function addView(obj, view)
            %ADDVIEW Connect view to this group's Stack and register it.
            arguments
                obj  (1,1)
                view (1,1) statusMgr.internal.view.StatusViewInterface
            end
            view.setStack(obj.Stack);
            obj.Views = [obj.Views, view];
        end

        function removeView(obj, idx)
            %REMOVEVIEW Remove the view at position idx.
            arguments
                obj (1,1)
                idx (1,1) double {mustBeInteger, mustBePositive}
            end
            if idx > numel(obj.Views)
                error("statusMgr:StatusManagerGroup:indexOutOfRange", ...
                    "View index %d exceeds number of views (%d).", ...
                    idx, numel(obj.Views));
            end
            obj.Views(idx) = [];
        end

    end

end
