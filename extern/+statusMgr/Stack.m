classdef Stack < statusMgr.internal.StackInterface
    %STACK
    % Use example:
    % statusStack = statusMgr.Stack();
    % [newStatus, cleanObj] = statusStack.addStatus(statusMgr.StatusType.Running, "Initialising");
    % updateStatusMessage(obj, status, message)

    properties (SetAccess = protected)
        Statuses = statusMgr.Status("Idle")
        StatusListeners
        StackMonitorableListeners
    end

    properties (SetAccess = protected)
        % Use suppressIdentifier / unsuppressIdentifier to mutate. The
        % setter is protected so callers can read the list but cannot
        % bypass the de-duplication / removal helpers.
        SuppressedIdentifiers (1,:) string = string.empty(1,0)
    end

    properties (Hidden)
        ID
    end

    properties (Dependent)
        CurrentStatus
    end

    methods
        function obj = Stack()
            obj.ID = matlab.lang.internal.uuid();
        end

        function delete(obj)
            delete(obj.StatusListeners);
            delete(obj.StackMonitorableListeners);
        end
    end

    methods % get/set

        function set.Statuses(obj, val)
            obj.Statuses = val;
            obj.StatusListeners = event.listener(obj.Statuses, "Completed", @(s,e) obj.onStatusCompleted(s,e)); %#ok<MCSUP>
        end

        % Ensure there is always an idle status
        function val = get.Statuses(obj)
            if isempty(obj.Statuses)
                val = statusMgr.Status("Idle");
                obj.Statuses = val;
            else
                val = obj.Statuses;
            end
        end

        % Get the latest status
        function value = get.CurrentStatus(obj)
            % Note, statuses can never be empty as it will default to idle
            % if this ever occurs, see get.Statuses
            value = obj.Statuses(end);
        end

    end

    methods % Adding

        function [status, cleanupObj] = addStatus(objs, type, nvp)
            % Push a new Status of the given type to the stack
            % [status, cleanupObj] = addStatus(StatusType, nvp)
            % cleanupObj is an optional output that creates a cleanup object
            % Name value pairs:
            %   Message (Running) - set the Status message
            %   IsVisible (true) - set the Status visibility
            %   Value (double) - Used for setting progress bar values
            %   Data (Status data) - Store data in the Status
            %   Silent (logical) - whether to notify the Status has
            %   changed
            arguments
                objs (1,:) statusMgr.Stack
                type (1,1) statusMgr.StatusType = statusMgr.StatusType.Info
                nvp.Identifier (1,1) string = ""
                nvp.Message (1,1) string = ""
                nvp.Title (1,1) string = ""
                nvp.MessageShort(1,1) string = string(nan)
                nvp.IsVisible (1,1) logical = true
                nvp.IsTemporary (1,:) logical {mustBeScalarOrEmpty} = false
                nvp.Value (1,1) double = NaN
                nvp.Data = []
                nvp.Silent (1,1) logical = false
                nvp.CreateCleanupObj (1,1) logical = true
                nvp.CompletionFcn (1,:) function_handle {mustBeScalarOrEmpty} = function_handle.empty(1,0)
            end

            if nargout < 2
                nvp.CreateCleanupObj = false;
            end

            newStatus = statusMgr.Status(type, nvp.Message, ...
                "Title", nvp.Title, ...
                "Identifier", nvp.Identifier, ...
                "MessageShort", nvp.MessageShort, ...
                "IsVisible", nvp.IsVisible, ...
                "Value", nvp.Value, ...
                "IsTemporary", nvp.IsTemporary, ...
                "Data", nvp.Data, ...
                "CompletionFcn", nvp.CompletionFcn);

            [status, cleanupObj] = objs.add(newStatus, ...
                "Silent", nvp.Silent, ...
                "CreateCleanupObj", nvp.CreateCleanupObj);

        end

        function [newStatus, cleanupObj] = add(objs, newStatus, nvp)
            % Push a new status onto each stack in objs.
            % [newStatus, cleanupObj] = add(args, newStatus)
            % cleanupObj is an optional output that creates a cleanup object
            % Name value pairs:
            %   Silent (logical) - whether to notify the Status has changed
            arguments
                objs (1,:) statusMgr.Stack
                newStatus (1,1) statusMgr.Status
                nvp.Silent (1,1) logical = false
                nvp.CreateCleanupObj (1,1) logical = true
            end

            if nargout < 2
                nvp.CreateCleanupObj = false;
            end

            % Empty objs returns an empty Status to keep the contract.
            if isempty(objs)
                newStatus = statusMgr.Status.empty(1,0);
            end

            cleanupObj = onCleanup.empty(1,0);
            for i = 1:numel(objs)
                obj = objs(i);
                obj.appendStatus(newStatus);
                if nvp.CreateCleanupObj
                    cleanupObj(end+1) = onCleanup(@() obj.removeStatus(newStatus)); %#ok<AGROW>
                end
                if ~nvp.Silent
                    notify(obj, "StatusUpdated");
                end
            end
        end

        function [newStatus, cleanupObj] = addError(objs, err, nvp)
            arguments
                objs (1,:)
                err (1,1) MException
                nvp.IsVisible (1,1) logical = true
                nvp.IsTemporary (1,1) logical = false
                nvp.Silent (1,1) logical = false
                nvp.CreateCleanupObj (1,1) logical = true
            end

            % Remove test infrastructure
            messageShort = err.message;

            message = getReport(err, "extended");
            message = string(message);
            message = strsplit(message, newline);
            idx = find(contains(message, "matlab.unittest"), 1);
            message(idx:end) = [];
            message = strjoin(message, newline);

            if nargout < 2
                nvp.CreateCleanupObj = false;
            end

            nvpCell = namedargs2cell(nvp);
            [newStatus, cleanupObj] = objs.addStatus("Error", ...
                "Identifier", err.identifier, ...
                "Data", err, ...
                "Message", message, ...
                "MessageShort", messageShort, ...
                nvpCell{:});

        end

    end

    methods % Updating

        function updateStatus(objs, status, nvp)
            arguments
                objs (1,:) statusMgr.Stack
                status (1,1) statusMgr.Status
                nvp.Message (1,1) string
                nvp.Value (1,1) double
            end

            for i = 1:numel(objs)
                obj = objs(i);
                % obj.CurrentStatus is guaranteed non-empty by
                % get.Statuses (which restores an Idle default if the
                % array is ever cleared).
                if obj.CurrentStatus.ID == status.ID
                    % Quickest to just update the current status.
                    if isfield(nvp, "Message")
                        obj.CurrentStatus.updateMessage(nvp.Message);
                    end
                    if isfield(nvp, "Value")
                        obj.CurrentStatus.updateValue(nvp.Value);
                    end
                    if isfield(nvp, "Message") || isfield(nvp, "Value")
                        notify(obj, "StatusUpdated");
                    end
                else
                    % Otherwise find it in the stack. We don't issue
                    % StatusUpdated in this case because views read the
                    % current (top) status, which hasn't changed.
                    idx = ([obj.Statuses.ID] == status.ID);
                    if isfield(nvp, "Message")
                        obj.Statuses(idx).updateMessage(nvp.Message);
                    end
                    if isfield(nvp, "Value")
                        obj.Statuses(idx).updateValue(nvp.Value);
                    end
                end
            end
        end

    end

    methods % Removing

        function removeStatus(objs, toRemove, nvp)
            % Remove a status from the stack
            % - doesn't have to be top of the stack!

            arguments
                objs (1,:) statusMgr.Stack
                toRemove (1,:) statusMgr.Status
                nvp.Silent (1,1) logical = false
            end

            for ii = 1:numel(objs)
                obj = objs(ii);

                % Check if last status
                if isscalar(toRemove) ...
                        && obj.CurrentStatus.ID == toRemove.ID
                    matchingIdx = numel(obj.Statuses);
                else
                    % Find matching statuses by ID
                    allIds = string([obj.Statuses.ID]);
                    idsToRemove = string([toRemove.ID]);
                    matchingIdx = matches(allIds, idsToRemove);
                end

                toComplete = obj.Statuses(matchingIdx);
                obj.Statuses(matchingIdx) = [];
                toComplete.complete();

                if ~nvp.Silent
                    notify(obj, "StatusUpdated");
                end

            end

        end

        function removeLastStatus(obj, nvp)
            % Remove the last status from the stack
            arguments
                obj (1,1) statusMgr.Stack
                nvp.Silent (1,1) logical = false
            end

            obj.removeStatus(obj.CurrentStatus, Silent=nvp.Silent);

        end

        function removeAllStatuses(obj)
            arguments
                obj (1,:) statusMgr.Stack
            end

            % Remove all the statuses
            statuses = [obj.Statuses];
            obj.removeStatus(statuses);
        end

    end

    methods % Monitoring

        function monitor(obj, monitorable)
            arguments
                obj (1,1) statusMgr.Stack
                monitorable (1,1) statusMgr.monitorable.Monitorable
            end
            obj.StackMonitorableListeners(end+1) = event.listener(monitorable, "StatusChanged", @(s,e) obj.onMonitorableStatusChanged(s,e));
        end

        function status = monitorFuture(obj, future, nvp)
            % Push a status that mirrors a parallel.Future's lifecycle.
            %
            %   status = stack.monitorFuture(future)
            %   status = stack.monitorFuture(future, ProgressQueue=q, ...)
            %
            % The returned Status is held on the stack as
            % RunningCancellable (or Running, if Cancellable=false)
            % while the future is queued or running. When the future
            % finishes the status is completed; if it failed,
            % future.Error is converted into an Error status. If user
            % code completes the status (e.g. via the StatusBar Cancel
            % button) the future is cancelled.
            %
            % Progress updates: pass an optional parallel.pool.DataQueue
            % that the worker calls send() on. Numeric scalars set the
            % status's Value; strings update Message; structs with
            % Value/Message fields update both.
            %
            % Terminal detection uses a periodic poll (PollPeriod
            % seconds, default 0.5) on future.State so we catch both
            % success and failure uniformly — afterEach/afterAll fire
            % only on success.
            arguments
                obj (1,1) statusMgr.Stack
                future (1,1) parallel.Future
                nvp.Message (1,1) string = ""
                nvp.Cancellable (1,1) logical = true
                nvp.ProgressQueue = parallel.pool.DataQueue.empty(1,0)
                nvp.PollPeriod (1,1) double {mustBePositive} = 0.5
            end

            msg = nvp.Message;
            if msg == ""
                msg = "Background task #" + string(future.ID);
            end

            statusType = "Running";
            if nvp.Cancellable
                statusType = "RunningCancellable";
            end

            % addStatus with one output: no auto-cleanup. The poll
            % timer / cancel listener manage status lifetime.
            status = obj.addStatus(statusType, ...
                "Message", msg, ...
                "Data", future);

            if ~isempty(nvp.ProgressQueue)
                afterEach(nvp.ProgressQueue, ...
                    @(v) statusMgr.Stack.onProgressFromWorker(obj, status, v));
            end

            pollTimer = timer( ...
                "ExecutionMode", "fixedSpacing", ...
                "Period", nvp.PollPeriod, ...
                "TimerFcn", @(t,~) statusMgr.Stack.pollFutureState(t, obj, status, future));
            start(pollTimer);

            % If the user (or a view) completes the status, propagate
            % cancellation to the future and stop the poll timer.
            addlistener(status, "Completed", ...
                @(~,~) statusMgr.Stack.onStatusCompletedCancelFuture(future, pollTimer));
        end

        function [future, status] = runInBackground(obj, fcnHandle, nvp)
            % Convenience: parfeval + monitorFuture in one call.
            %
            %   [future, status] = stack.runInBackground(@myFcn, ...
            %       Args={a, b}, NumOutputs=1, Message="Loading data");
            %
            % To stream progress, create a DataQueue and pass it both
            % into Args (the worker calls send() on it) and as
            % ProgressQueue (the monitor listens):
            %
            %   q = parallel.pool.DataQueue;
            %   stack.runInBackground(@workerFcn, ...
            %       Args={q, x, y}, ProgressQueue=q);
            %
            % By default the work runs on the backgroundPool (no
            % Parallel Computing Toolbox required). Pass Pool=parpool
            % or any other parallel.Pool to override.
            arguments
                obj (1,1) statusMgr.Stack
                fcnHandle (1,1) function_handle
                nvp.Args (1,:) cell = {}
                nvp.NumOutputs (1,1) double {mustBeNonnegative, mustBeInteger} = 1
                nvp.Pool = backgroundPool
                nvp.Message (1,1) string = ""
                nvp.Cancellable (1,1) logical = true
                nvp.ProgressQueue = parallel.pool.DataQueue.empty(1,0)
                nvp.PollPeriod (1,1) double {mustBePositive} = 0.5
            end

            msg = nvp.Message;
            if msg == ""
                msg = "Running: " + eraseBetween(func2str(fcnHandle), ...
                    textBoundary, ")", "Boundaries", "inclusive");
            end

            future = parfeval(nvp.Pool, fcnHandle, nvp.NumOutputs, nvp.Args{:});

            status = obj.monitorFuture(future, ...
                Message=msg, ...
                Cancellable=nvp.Cancellable, ...
                ProgressQueue=nvp.ProgressQueue, ...
                PollPeriod=nvp.PollPeriod);
        end

        function varargout = run(obj, fcnHandle, varargin, nvp)
            % Run a function while pushing a Running status onto the
            % stack. By default, errors are caught and pushed as Error
            % statuses, and any warning issued during the call is
            % pushed as a Warning status.
            %
            %   stack.run(@myFcn)
            %   stack.run(@myFcn, arg1, arg2)
            %   stack.run(@myFcn, CatchErrors=false)
            %   stack.run(@myFcn, arg1, arg2, CatchWarnings=false)
            arguments
                obj (1,1) statusMgr.Stack
                fcnHandle (1,1) function_handle
            end
            arguments (Repeating)
                varargin
            end
            arguments
                nvp.CatchErrors (1,1) logical = true
                nvp.CatchWarnings (1,1) logical = true
            end

            varargout = cell(1, nargout);
            [varargout{:}] = obj.runWithStatus("Running", false, ...
                fcnHandle, varargin, nvp.CatchErrors, nvp.CatchWarnings);
        end

        function varargout = runCancellable(obj, fcnHandle, varargin, nvp)
            % Like run(), but pushes a RunningCancellable status and
            % passes that Status as the FIRST argument to fcnHandle.
            % Cancel-aware views (e.g. Popup) call status.complete()
            % when the user clicks Cancel; user code is expected to
            % poll status.IsComplete (or listen on Completed) and bail
            % out gracefully:
            %
            %   stack.runCancellable(@(status) work(status));
            %
            %   function work(status)
            %       for i = 1:N
            %           if status.IsComplete; return; end
            %           % ... do step i ...
            %       end
            %   end
            %
            % While the function is running, status.IsComplete=true
            % unambiguously means "cancel requested" — the natural-
            % completion path (the onCleanup created internally) fires
            % only after fcnHandle returns. Otherwise behaves
            % identically to run() — same name-value flags, same
            % warning capture, same status cleanup.
            arguments
                obj (1,1) statusMgr.Stack
                fcnHandle (1,1) function_handle
            end
            arguments (Repeating)
                varargin
            end
            arguments
                nvp.CatchErrors (1,1) logical = true
                nvp.CatchWarnings (1,1) logical = true
            end

            varargout = cell(1, nargout);
            [varargout{:}] = obj.runWithStatus("RunningCancellable", true, ...
                fcnHandle, varargin, nvp.CatchErrors, nvp.CatchWarnings);
        end

    end

    methods (Access = protected)

        function varargout = runWithStatus(obj, statusType, passStatusFirst, ...
                fcnHandle, fcnArgs, catchErrors, catchWarnings)
            % Shared body of run() and runCancellable(): push a status,
            % run fcnHandle, capture errors/warnings, clean up.
            %   statusType        - StatusType to push for the duration
            %   passStatusFirst   - true to inject the Status as the
            %                       first arg to fcnHandle (cancellable
            %                       work uses this to read IsComplete)
            %   fcnArgs (cell)    - positional args from the caller

            fcnCallStr = eraseBetween(func2str(fcnHandle), textBoundary, ")", ...
                "Boundaries", "inclusive");
            [status, statusCleanup] = obj.addStatus(statusType, ...
                "Message", "Running: " + fcnCallStr); %#ok<ASGLU>

            % WarningCapture silences warnings, sets a sentinel via
            % lastwarn, and restores the prior warning state on delete.
            captor = statusMgr.util.WarningCapture();

            if passStatusFirst
                fcnArgs = [{status}, fcnArgs];
            end

            try
                if nargout > 0
                    varargout = cell(1, nargout);
                    [varargout{:}] = fcnHandle(fcnArgs{:});
                else
                    fcnHandle(fcnArgs{:});
                end
            catch me
                if ~catchErrors
                    rethrow(me);
                end
                obj.addError(me);
            end

            if catchWarnings
                [warningMsg, ~] = captor.warning();
                if warningMsg ~= ""
                    obj.addStatus("Warning", "Message", warningMsg);
                end
            end
        end

    end

    methods % User input

        function value = requestInput(obj, prompt, nvp)
            % Block until a view supplies user input, or return DefaultValue
            % after Timeout seconds if no view claims the request.
            %
            % value = requestInput(prompt)
            % value = requestInput(prompt, DefaultValue="fallback", Timeout=5, Title="...")
            arguments
                obj (1,1) statusMgr.Stack
                prompt (1,1) string = ""
                nvp.DefaultValue (1,1) string = ""
                nvp.Title (1,1) string = "Input Required"
                nvp.Timeout (1,1) double {mustBePositive} = 0.5
            end

            % Push RequestingInput. Listeners fire synchronously here, so
            % a view may have already claimed (or even completed) the
            % request by the time addStatus returns.
            status = obj.addStatus(statusMgr.StatusType.RequestingInput, ...
                Message=prompt, ...
                Title=nvp.Title, ...
                Data=nvp.DefaultValue);
            cleanupStatus = onCleanup(@() obj.removeStatus(status)); %#ok<NASGU>

            % If no view has claimed the request after Timeout seconds,
            % auto-resolve with the default value. The handler is a no-op
            % once the status has already been resolved (IsComplete=true)
            % or a view has claimed it (Type=AwaitingInput).
            weakStatus = matlab.lang.WeakReference(status);
            timeoutTimer = timer( ...
                "StartDelay", nvp.Timeout, ...
                "ExecutionMode", "singleShot", ...
                "TimerFcn", @(~,~) statusMgr.Stack.resolveOnTimeout(weakStatus, nvp.DefaultValue));
            cleanupTimer = onCleanup(@() statusMgr.util.stopTimer(timeoutTimer)); %#ok<NASGU>
            start(timeoutTimer);

            % Block until the status is resolved. A view supplying a value
            % via transitionInputState(ValueSupplied) sets IsComplete=true,
            % as does external completion (e.g. removeAllStatuses) and the
            % timeout above. waitfor yields to the event loop while it
            % blocks, so timers and UI callbacks still fire.
            if ~status.IsComplete
                waitfor(status, "IsComplete", true);
            end

            if status.Type == statusMgr.StatusType.ValueSupplied
                value = status.Message;
            else
                value = nvp.DefaultValue;
            end
        end

    end

    methods % Suppression

        function suppressIdentifier(obj, id)
            % Hide statuses whose Identifier matches `id`.
            %
            %   stack.suppressIdentifier("myapp:network:timeout")
            %   stack.suppressIdentifier("myapp:network:*")  % glob
            %   stack.suppressIdentifier("*:timeout")
            %
            % `id` is matched against each new status's Identifier as
            % a glob: `*` matches any run of characters (including
            % none); other characters match literally. A status with
            % a matching identifier is added to the stack with
            % IsVisible=false so views skip displaying it.
            arguments
                obj (1,1) statusMgr.Stack
                id (1,1) string
            end
            if ~ismember(id, obj.SuppressedIdentifiers)
                obj.SuppressedIdentifiers(end+1) = id;
            end
        end

        function unsuppressIdentifier(obj, id)
            % Remove an exact `id` from the suppression list. The
            % string must match a previously-added entry exactly
            % (including any wildcards).
            arguments
                obj (1,1) statusMgr.Stack
                id (1,1) string
            end
            obj.SuppressedIdentifiers(obj.SuppressedIdentifiers == id) = [];
        end

        function tf = isIdentifierSuppressed(obj, identifier)
            % True if `identifier` matches any entry in
            % SuppressedIdentifiers (treating each entry as a glob).
            arguments
                obj (1,1) statusMgr.Stack
                identifier (1,1) string
            end
            tf = false;
            if identifier == "" || isempty(obj.SuppressedIdentifiers)
                return
            end
            for sup = obj.SuppressedIdentifiers
                if statusMgr.util.globMatches(identifier, sup)
                    tf = true;
                    return
                end
            end
        end

    end

    methods % Util

        function tbl = table(obj)
            arguments
                obj (1,1) statusMgr.Stack
            end
            tbl = obj.Statuses.table();
        end

    end

    methods (Access = protected)

        function appendStatus(obj, newStatus)

            % Pop any temporary statuses currently on top of the stack.
            % Cap iterations at the stack depth: we can never need to
            % pop more entries than exist, and the cap is a safety net
            % against an invariant violation (e.g. if the default Idle
            % were ever marked IsTemporary by a future change, this
            % loop would otherwise spin forever).
            for i = 1:numel(obj.Statuses)
                if ~obj.CurrentStatus.IsTemporary
                    break
                end
                obj.removeLastStatus(Silent=true);
            end

            % Hide status if its identifier is suppressed.
            if newStatus.Identifier ~= "" && obj.isIdentifierSuppressed(newStatus.Identifier)
                newStatus.IsVisible = false;
            end

            % Add the status
            obj.Statuses = [obj.Statuses, newStatus];
        end

        function onStatusCompleted(obj, s, e)
            idx = isvalid(obj);
            obj = obj(idx);
            obj.removeStatus(s);
        end

        function onMonitorableStatusChanged(obj, s, e)
            status = e.Status;
            obj.add(status);
        end

    end

    methods (Static, Access = private)

        function resolveOnTimeout(weakStatus, defaultValue)
            % requestInput timeout handler. Resolves with the default
            % value only if no view has claimed the request yet
            % (Type still RequestingInput). If a view has claimed
            % (AwaitingInput), the wait is unbounded by design.
            s = weakStatus.Handle;
            if isempty(s) || ~isvalid(s) || s.IsComplete
                return
            end
            if s.Type == statusMgr.StatusType.RequestingInput
                s.transitionInputState( ...
                    statusMgr.StatusType.ValueSupplied, defaultValue);
            end
        end

        function pollFutureState(pollTimer, stack, status, future)
            % monitorFuture's poll callback. Stops the timer and
            % completes the status when the future reaches a terminal
            % state. Failures are converted into an Error status on
            % the stack via addError.
            if ~isvalid(stack) || ~isvalid(status) || ~isvalid(future) ...
                    || status.IsComplete
                statusMgr.util.stopTimer(pollTimer);
                return
            end
            terminalStates = ["finished", "failed", "unavailable"];
            if ~ismember(string(future.State), terminalStates)
                return
            end
            statusMgr.util.stopTimer(pollTimer);
            if ~isempty(future.Error)
                stack.addError(future.Error);
            end
            status.complete();
        end

        function onProgressFromWorker(stack, status, value)
            % Translate a value sent on the progress DataQueue into a
            % status update. Numeric scalar → Value; string → Message;
            % struct with Value/Message → both.
            if ~isvalid(status) || status.IsComplete
                return
            end
            if isnumeric(value) && isscalar(value)
                stack.updateStatus(status, "Value", double(value));
            elseif isstring(value) || (ischar(value) && (isrow(value) || isempty(value)))
                stack.updateStatus(status, "Message", string(value));
            elseif isstruct(value)
                args = {};
                if isfield(value, "Value")
                    args = [args, {"Value", double(value.Value)}];
                end
                if isfield(value, "Message")
                    args = [args, {"Message", string(value.Message)}];
                end
                if ~isempty(args)
                    stack.updateStatus(status, args{:});
                end
            end
        end

        function onStatusCompletedCancelFuture(future, pollTimer)
            % If the status is completed externally (e.g. user clicks
            % Cancel on the StatusBar), stop the poll timer and
            % cancel any not-yet-finished future.
            statusMgr.util.stopTimer(pollTimer);
            if isvalid(future) && ismember(string(future.State), ["queued", "running"])
                cancel(future);
            end
        end

    end

end

