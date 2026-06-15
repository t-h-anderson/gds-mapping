classdef StatusManager < handle
    %STATUSMANAGER Singleton registry of named StatusManagerGroups.
    %
    % Each group holds a Stack and zero or more views, keyed by name.
    % The "Default" group is created automatically on first access.
    %
    % Creating and clearing groups:
    %   smg = statusMgr.util.StatusManager.make()
    %   smg = statusMgr.util.StatusManager.make("MyGroup", PopupParent=fig, ...
    %             EnableCommandWindow=true, LogFolder="/logs")
    %   statusMgr.util.StatusManager.clear()           % remove all groups
    %   statusMgr.util.StatusManager.clear("MyGroup")  % remove one group
    %
    % Retrieving state (Type defaults to "Stack"):
    %   stack = statusMgr.util.StatusManager.get()
    %   stack = statusMgr.util.StatusManager.get("MyGroup")
    %   smg   = statusMgr.util.StatusManager.get(Type="StatusManagerGroup")
    %   views = statusMgr.util.StatusManager.get("MyGroup", Type="Views")
    %
    % Managing views:
    %   statusMgr.util.StatusManager.addPopup("MyGroup", Parent=fig)
    %   statusMgr.util.StatusManager.addCommandWindow("MyGroup")
    %   statusMgr.util.StatusManager.addFileLog("MyGroup", LogFolder="/logs")
    %   statusMgr.util.StatusManager.addView("MyGroup", existingView)
    %   statusMgr.util.StatusManager.removeView("MyGroup", idx)

    properties (Access = private)
        Groups (1,1) dictionary = configureDictionary("string", "statusMgr.util.StatusManagerGroup")
    end

    methods (Access = private)
        function obj = StatusManager()
            obj.Groups = configureDictionary("string", "statusMgr.util.StatusManagerGroup");
        end
    end

    methods (Static, Access = private)

        function obj = instance(action)
            %INSTANCE Manage the persistent singleton.
            %   instance()        – get or create
            %   instance("peek")  – return current without creating (may be empty)
            %   instance(true)    – reset to a fresh instance
            %   instance(sm)      – restore to a specific StatusManager object
            %   instance([])      – clear the persistent (set to empty)
            persistent singleton

            if nargin == 0
                if isempty(singleton) || ~isvalid(singleton)
                    singleton = statusMgr.util.StatusManager();
                end
                obj = singleton;
                return
            end

            if isstring(action) && action == "peek"
                obj = singleton;  % may be empty; does not auto-create
                return
            end

            if islogical(action) && action
                singleton = statusMgr.util.StatusManager();
            elseif isa(action, 'statusMgr.util.StatusManager')
                singleton = action;
            elseif isempty(action)
                singleton = [];
            end
            obj = singleton;
        end

    end

    methods (Static, Hidden)

        function token = snapshot()
            %SNAPSHOT Capture the current singleton state for later restoration.
            %
            % Saves both the singleton handle and a copy of the Groups
            % dictionary (value type) so that group additions or removals
            % made during a test are fully undone by restore().
            %
            % Typical test setup:
            %   token = statusMgr.util.StatusManager.snapshot();
            %   testCase.addTeardown( ...
            %       @() statusMgr.util.StatusManager.restore(token));
            sm = statusMgr.util.StatusManager.instance("peek");
            if isempty(sm) || ~isvalid(sm)
                token = struct('hasInstance', false, 'instance', [], 'groups', []);
            else
                token = struct('hasInstance', true, 'instance', sm, 'groups', sm.Groups);
            end
        end

        function restore(token)
            %RESTORE Restore the singleton to a previously snapshotted state.
            if ~token.hasInstance
                statusMgr.util.StatusManager.instance([]);
            elseif isvalid(token.instance)
                statusMgr.util.StatusManager.instance(token.instance);
                token.instance.Groups = token.groups;
            else
                statusMgr.util.StatusManager.instance([]);
            end
        end

    end

    methods (Static)

        function stack = make(name, nvp)
            %MAKE Return or create a named stack with groups attached.
            %
            % If the group already exists it is returned unchanged.
            % Construction arguments are only applied on first creation.
            % LogFolder=string(nan) (default) suppresses FileLog creation.
            arguments
                name                        (1,1) string  = "Default"
                nvp.PopupParent                           = []
                nvp.EnableCommandWindow     (1,1) logical = false
                nvp.LogFolder               (1,1) string  = string(nan)
            end

            obj = statusMgr.util.StatusManager.instance();

            if isKey(obj.Groups, name)
                smg = obj.Groups(name);
                stack = smg.Stack;
                return
            end

            smg = statusMgr.util.StatusManagerGroup();

            if ~isempty(nvp.PopupParent)
                smg.addView(statusMgr.view.Popup(nvp.PopupParent, smg.Stack));
            end
            if nvp.EnableCommandWindow
                smg.addView(statusMgr.view.CommandWindow(smg.Stack));
            end
            if ~ismissing(nvp.LogFolder)
                smg.addView(statusMgr.view.FileLog(smg.Stack, LogFolder=nvp.LogFolder));
            end

            obj.Groups(name) = smg;

            stack = smg.Stack;
        end

        function result = get(name, nvp)
            %GET Retrieve state from a named StatusManagerGroup.
            %
            % Returns the Stack by default. Use Type= to return the group
            % or its views. The "Default" group is created automatically if
            % it does not exist; all other names error if not found.
            arguments
                name     (1,1) string = "Default"
                nvp.Type (1,1) string ...
                    {mustBeMember(nvp.Type, ["Stack", "StatusManagerGroup", "Views"])} ...
                    = "Stack"
            end

            obj = statusMgr.util.StatusManager.instance();

            if name == "Default" && ~isKey(obj.Groups, name)
                statusMgr.util.StatusManager.make("Default");
            elseif ~isKey(obj.Groups, name)
                error("statusMgr:StatusManager:unknownGroup", ...
                    "No status manager named '%s'. Call StatusManager.make(" + name + ") first.", name);
            end

            smg = obj.Groups(name);

            switch nvp.Type
                case "Stack"
                    result = smg.Stack;
                case "StatusManagerGroup"
                    result = smg;
                case "Views"
                    result = smg.Views;
            end
        end

        function clear(name)
            %CLEAR Remove a group by name, or all groups if no name is given.
            arguments
                name (1,1) string = string(nan)
            end

            obj = statusMgr.util.StatusManager.instance();
            if ismissing(name)
                statusMgr.util.StatusManager.instance(true);
            elseif isKey(obj.Groups, name)
                obj.Groups = remove(obj.Groups, name);
            else
                error("statusMgr:StatusManager:unknownGroup", ...
                    "No status manager named '%s'.", name);
            end
        end

        function addPopup(name, nvp)
            %ADDPOPUP Add a Popup view to a named status manager group.
            arguments
                name       (1,1) string = "Default"
                nvp.Parent               = []
            end
            smg = statusMgr.util.StatusManager.get(name, Type="StatusManagerGroup");
            smg.addView(statusMgr.view.Popup(nvp.Parent, smg.Stack));
        end

        function addCommandWindow(name)
            %ADDCOMMANDWINDOW Add a CommandWindow view to a named group.
            arguments
                name (1,1) string = "Default"
            end
            smg = statusMgr.util.StatusManager.get(name, Type="StatusManagerGroup");
            smg.addView(statusMgr.view.CommandWindow(smg.Stack));
        end

        function addFileLog(name, nvp)
            %ADDFILELOG Add a FileLog view to a named group.
            arguments
                name          (1,1) string                = "Default"
                nvp.LogFolder (1,1) string {mustBeFolder} = pwd
            end
            smg = statusMgr.util.StatusManager.get(name, Type="StatusManagerGroup");
            smg.addView(statusMgr.view.FileLog(smg.Stack, LogFolder=nvp.LogFolder));
        end

        function addView(name, view)
            %ADDVIEW Add an existing view object to a named group.
            %
            % The view's Stack is updated to match the group's Stack.
            arguments
                name (1,1) string
                view (1,1) statusMgr.internal.view.StatusViewInterface
            end
            smg = statusMgr.util.StatusManager.get(name, Type="StatusManagerGroup");
            smg.addView(view);
        end

        function removeView(name, idx)
            %REMOVEVIEW Remove the view at position idx from a named group.
            arguments
                name (1,1) string
                idx  (1,1) double {mustBeInteger, mustBePositive}
            end
            smg = statusMgr.util.StatusManager.get(name, Type="StatusManagerGroup");
            smg.removeView(idx);
        end

    end

end
