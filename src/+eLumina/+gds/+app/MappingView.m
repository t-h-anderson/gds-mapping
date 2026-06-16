classdef MappingView < handle
    %MAPPINGVIEW uifigure-based view bound to a MappingSession.
    %
    %   Widgets:
    %     - Top buttons: Load Model, Load Base, Load Override, Load Config,
    %       Export Results
    %     - Results table (Signal | IEC Path | Linked Signal | Status | Rule | Source)
    %     - Test panel: type a path, see matched rule + resolved IEC path
    %     - Rules editor: merged override/base list; only override rows are editable
    %
    %   Uses gwidgets.Table for both tables -- sort/filter/group via
    %   right-click context menu. The results table also exposes the
    %   filter row (ShowRowFilter = true); the rules table doesn't,
    %   since order there is priority and the user controls it directly.

    properties (SetAccess = protected)
        Session (1,1) eLumina.gds.app.MappingSession
    end

    properties (Access = private)
        Figure
        ResultsTable
        RulesTable
        StatusStack
        StatusBar
        TestInput
        TestMatchLabel
        TestPathLabel
        ChangedListener
        Syncing (1,1) logical = false  % guards the two-way selection sync
    end

    properties (Constant, Access = private)
        AppDataKey (1,1) string = "eLuminaGdsMappingView"
    end

    methods
        function obj = MappingView(session)
            arguments
                session (1,1) eLumina.gds.app.MappingSession
            end
            obj.Session = session;
            obj.StatusStack = statusMgr.Stack();
            obj.build();
            obj.ChangedListener = addlistener(session, "Changed", ...
                @(~,~) obj.refresh());
            obj.refresh();
            obj.registerOpenView();
        end

        function delete(obj)
            obj.unregisterOpenView();
            delete(obj.ChangedListener);
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                obj.Figure.CloseRequestFcn = [];
                delete(obj.Figure);
            end
        end

        function loadModel(obj, modelPath)
            arguments
                obj
                modelPath (1,1) string {mustBeFile}
            end
            [~, name, ext] = fileparts(modelPath);
            obj.runWithStatus("Opening model " + name + ext, ...
                @() obj.Session.loadModel(modelPath));
        end

        function loadRules(obj, path, nvp)
            arguments
                obj
                path (1,1) string {mustBeFile}
                nvp.ConfigPath (1,1) string = ""
            end
            [~, name, ext] = fileparts(path);
            obj.runWithStatus("Loading override rules " + name + ext, ...
                @() obj.Session.loadRules(path, ConfigPath=nvp.ConfigPath));
        end

        function loadBaseRules(obj, path)
            arguments
                obj
                path (1,1) string {mustBeFile}
            end
            [~, name, ext] = fileparts(path);
            obj.runWithStatus("Loading base rules " + name + ext, ...
                @() obj.Session.loadBaseRules(path));
        end

        function loadConfig(obj, path)
            arguments
                obj
                path (1,1) string {mustBeFile}
            end
            [~, name, ext] = fileparts(path);
            obj.runWithStatus("Loading config " + name + ext, ...
                @() obj.Session.loadConfig(path));
        end

        function saveRules(obj, path)
            arguments
                obj
                path (1,1) string = ""
            end
            obj.runWithStatus("Saving override rules", ...
                @() obj.Session.saveRules(path));
        end

        function exportResults(obj, path)
            arguments
                obj
                path (1,1) string
            end
            [~, name, ext] = fileparts(path);
            obj.runWithStatus("Exporting results " + name + ext, ...
                @() obj.Session.exportResults(path));
        end

        function addWarningStatus(obj, message, nvp)
            arguments
                obj
                message (1,1) string
                nvp.Identifier (1,1) string = "eLumina:gds:app:warning"
            end

            obj.StatusStack.addStatus( ...
                statusMgr.StatusType.Warning, ...
                Identifier=nvp.Identifier, ...
                Message=message, ...
                MessageShort=message, ...
                IsTemporary=true);
            drawnow
        end

        function show(obj)
            if isempty(obj.Figure) || ~isvalid(obj.Figure)
                return
            end

            obj.Figure.Visible = "on";
            obj.Figure.WindowState = "normal";
            drawnow
            try
                figure(obj.Figure);
            catch
                % Figure focus is best-effort across MATLAB desktop releases.
            end
        end

        function idx = selectResultForSimulinkBlock(obj, blockPath, nvp)
            arguments
                obj
                blockPath (1,1) string
                nvp.PortName (1,1) string = ""
                nvp.PortType (1,1) string = ""
            end

            idx = obj.resultRowsForSimulinkBlock(blockPath, ...
                PortName = nvp.PortName, ...
                PortType = nvp.PortType);
            if isempty(idx)
                target = blockPath;
                if nvp.PortName ~= ""
                    target = target + "/" + nvp.PortName;
                end
                obj.show();
                obj.showNavigationWarning( ...
                    "No result row matched " + target + ".", ...
                    "No Matching Result");
                return
            end

            obj.ResultsTable.Selection = idx;
            obj.onResultSelected();
            obj.show();
        end

        function idx = resultRowsForSimulinkBlock(obj, blockPath, nvp)
            arguments
                obj
                blockPath (1,1) string
                nvp.PortName (1,1) string = ""
                nvp.PortType (1,1) string = ""
            end

            idx = obj.matchResultRows(blockPath, ...
                PortName = nvp.PortName, ...
                PortType = nvp.PortType);
        end
    end

    methods (Access = private)
        function build(obj)
            obj.Figure = uifigure( ...
                Name = "GDS Mapping", ...
                Position = [100 100 1200 760], ...
                CloseRequestFcn = @(~,~) delete(obj));

            main = uigridlayout(obj.Figure, [4 1], ...
                RowHeight = {40, "1x", 260, 28}, ColumnWidth = {"1x"});

            obj.buildTopBar(main, 1);
            obj.buildMiddle(main, 2);
            obj.buildRulesEditor(main, 3);
            obj.buildStatusBar(main, 4);
        end

        function buildTopBar(obj, parent, row)
            % Translation pipeline: model in -> layered rules in -> results out.
            top = uigridlayout(parent, [1 6], ...
                ColumnWidth = {110, 140, 130, 110, 150, "1x"});
            top.Layout.Row = row; top.Layout.Column = 1;
            uibutton(top, Text = "Load Model...", ...
                ButtonPushedFcn = @(~,~) obj.onLoadModel());
            uibutton(top, Text = "Load Base...", ...
                ButtonPushedFcn = @(~,~) obj.onLoadBaseRules());
            uibutton(top, Text = "Load Override...", ...
                ButtonPushedFcn = @(~,~) obj.onLoadRules());
            uibutton(top, Text = "Load Config...", ...
                ButtonPushedFcn = @(~,~) obj.onLoadConfig());
            uibutton(top, Text = "Export Results...", ...
                ButtonPushedFcn = @(~,~) obj.onExportResults());
        end

        function buildMiddle(obj, parent, row)
            mid = uigridlayout(parent, [1 2], ColumnWidth = {"4x", "1x"});
            mid.Layout.Row = row; mid.Layout.Column = 1;

            obj.ResultsTable = gwidgets.Table( ...
                Parent = mid, ...
                Data = obj.emptyResultsTable(), ...
                ColumnNames = ["Model Reference", "Signal", "Plant Path", ...
                               "IEC Path", "Linked Signal", "Status", ...
                               "Rule", "Source", "Warning", "IsOverride", ...
                               "RuleIndex", "ShadowTooltip"], ...
                HiddenColumnNames = ["IsOverride", "RuleIndex", "ShadowTooltip"], ...
                SelectionType = "row", ...
                Multiselect = "on", ...
                ShowRowFilter = true, ...
                HasToggleFilter = true, ...
                HasChangeGroupingVariable = true, ...
                CellSelectionCallback = @(~,~) obj.onResultSelected());
            obj.ResultsTable.Layout.Row = 1;
            obj.ResultsTable.Layout.Column = 1;

            % Hover-tooltip on override rows shows which lower rules
            % were shadowed. Persists across data refreshes. Popup style
            % matches the row's override-yellow so the link is visible.
            shadowTooltipStyle = gwidgets.internal.table.TooltipStyle( ...
                BackgroundColor = [1, 0.93, 0.70], ...
                FontWeight = "bold");
            obj.ResultsTable.addTooltip( ...
                @(ctx) ctx.Row.ShadowTooltip, ...
                "row", ...
                @(t) find(t.Data.IsOverride), ...
                Style = shadowTooltipStyle);
            obj.addResultNavigationMenu();

            test = uigridlayout(mid, [5 1], ...
                RowHeight = {22, 30, 30, 40, "1x"}, ColumnWidth = {"1x"});
            test.Layout.Row = 1; test.Layout.Column = 2;
            uilabel(test, Text = "Test signal path:");
            obj.TestInput = uieditfield(test, "text", ...
                ValueChangedFcn = @(src,~) obj.onTestSignalChanged(src.Value));
            obj.TestMatchLabel = uilabel(test, Text = "Rule: --");
            obj.TestPathLabel = uilabel(test, Text = "Path: --");
        end

        function buildRulesEditor(obj, parent, row)
            grp = uigridlayout(parent, [2 1], ...
                RowHeight = {40, "1x"}, ColumnWidth = {"1x"});
            grp.Layout.Row = row; grp.Layout.Column = 1;

            btns = uigridlayout(grp, [1 8], ...
                ColumnWidth = {140, 140, 130, 130, 70, 70, 110, "1x"});
            btns.Layout.Row = 1; btns.Layout.Column = 1;
            uibutton(btns, Text = "Add Regex Rule", ...
                ButtonPushedFcn = @(~,~) obj.onAddRegex());
            uibutton(btns, Text = "Add Explicit Rule", ...
                ButtonPushedFcn = @(~,~) obj.onAddExplicit());
            uibutton(btns, Text = "Edit Selected", ...
                ButtonPushedFcn = @(~,~) obj.onEditRule());
            uibutton(btns, Text = "Remove Rule", ...
                ButtonPushedFcn = @(~,~) obj.onRemoveRule());
            uibutton(btns, Text = "Up", ...
                ButtonPushedFcn = @(~,~) obj.onMoveUp());
            uibutton(btns, Text = "Down", ...
                ButtonPushedFcn = @(~,~) obj.onMoveDown());
            uibutton(btns, Text = "Save Rules", ...
                ButtonPushedFcn = @(~,~) obj.onSaveRules());

            obj.RulesTable = gwidgets.Table( ...
                Parent = grp, ...
                Data = obj.emptyRulesTable(), ...
                ColumnNames = ["Layer", "Source", "Kind", "Pattern / Path", ...
                               "Template / Target", "Notes", "Warning"], ...
                SelectionType = "row", ...
                Multiselect = "off", ...
                ShowRowFilter = false, ...
                HasToggleFilter = true, ...
                CellDoubleClickCallback = @(~,~) obj.onEditRule(), ...
                CellSelectionCallback = @(~,~) obj.onRuleSelected());
            obj.RulesTable.Layout.Row = 2;
            obj.RulesTable.Layout.Column = 1;
        end

        function buildStatusBar(obj, parent, row)
            obj.StatusBar = statusMgr.view.StatusBar(parent, obj.StatusStack, ...
                ShowInfo=false);
            obj.StatusBar.Layout.Layout.Row = row;
            obj.StatusBar.Layout.Layout.Column = 1;
        end

        function addResultNavigationMenu(obj)
            goToMenu = uimenu(obj.Figure, Text = "Go to");
            uimenu(goToMenu, ...
                Text = "Signal", ...
                MenuSelectedFcn = @(~,~) obj.onGoToSignal());
            uimenu(goToMenu, ...
                Text = "Plant", ...
                MenuSelectedFcn = @(~,~) obj.onGoToPlant());
            obj.ResultsTable.addContextMenuItem(goToMenu);
        end

        function refresh(obj)
            obj.ResultsTable.Data = obj.resultsToTable(obj.Session.Results);
            obj.RulesTable.Data = obj.rulesToTable( ...
                obj.Session.Rules.Rules, obj.Session.RuleWarnings);
            obj.applyResultStyles();
        end

        function applyResultStyles(obj)
            obj.ResultsTable.removeStyle();
            results = obj.Session.Results;
            if isempty(results)
                return
            end

            overrideRows = find(arrayfun(@(r) r.IsOverride, results));
            if ~isempty(overrideRows)
                overrideStyle = matlab.ui.style.Style( ...
                    BackgroundColor = [1, 0.93, 0.70]);
                obj.ResultsTable.addStyle(overrideStyle, "row", overrideRows);
            end

            brokenRows = find(arrayfun(@(r) ...
                r.Status == eLumina.gds.map.ResultStatus.Broken, results));
            if ~isempty(brokenRows)
                brokenStyle = matlab.ui.style.Style( ...
                    BackgroundColor = [1.00, 0.86, 0.86]);
                obj.ResultsTable.addStyle(brokenStyle, "row", brokenRows);
            end
        end

        function onRuleSelected(obj)
            % Rule clicked -> select the results it produced.
            if obj.Syncing; return; end
            results = obj.Session.Results;
            sel = obj.RulesTable.Selection;
            obj.Syncing = true;
            resetSync = onCleanup(@() obj.endSync());
            if isempty(sel) || isempty(results)
                obj.ResultsTable.Selection = [];
                return
            end
            ruleIdx = sel(1);
            obj.ResultsTable.Selection = ...
                find(arrayfun(@(r) r.RuleIndex == ruleIdx, results));
        end

        function onResultSelected(obj)
            % Result clicked -> select the rule(s) that produced it.
            if obj.Syncing; return; end
            results = obj.Session.Results;
            sel = obj.ResultsTable.Selection;
            obj.Syncing = true;
            resetSync = onCleanup(@() obj.endSync());
            if isempty(sel) || isempty(results)
                obj.RulesTable.Selection = [];
                return
            end
            ruleIdx = unique([results(sel).RuleIndex]);
            ruleIdx = ruleIdx(ruleIdx > 0);
            if isscalar(ruleIdx)
                obj.RulesTable.Selection = ruleIdx;
            else
                obj.RulesTable.Selection = [];
            end
        end

        function endSync(obj)
            obj.Syncing = false;
        end

        function onGoToSignal(obj)
            idx = obj.selectedResultIndex();
            if idx == 0
                return
            end

            relPath = obj.Session.Results(idx).Signal.InstancePath;
            obj.goToRelativeBlock(relPath, "Signal");
        end

        function onGoToPlant(obj)
            idx = obj.selectedResultIndex();
            if idx == 0
                return
            end

            plantPath = obj.Session.Results(idx).PlantPath;
            if plantPath == ""
                obj.showNavigationWarning( ...
                    "The selected result has no traced plant path.", ...
                    "No Plant Path");
                return
            end

            relPath = extractBefore(plantPath + ".", ".");
            obj.goToRelativeBlock(relPath, "Plant");
        end

        function idx = selectedResultIndex(obj)
            idx = 0;
            sel = obj.ResultsTable.Selection;
            if isscalar(sel)
                idx = sel;
                return
            end

            obj.showNavigationWarning( ...
                "Select exactly one result row before using navigation.", ...
                "Select One Row");
        end

        function goToRelativeBlock(obj, relPath, label)
            if obj.Session.ModelPath == ""
                obj.showNavigationWarning( ...
                    "Load a model before using result navigation.", ...
                    "No Model Loaded");
                return
            end

            [folder, modelName] = fileparts(obj.Session.ModelPath);
            folder = string(folder);
            if folder ~= "" && ~ismember(char(folder), strsplit(path, pathsep))
                addpath(char(folder));
                cleanupPath = onCleanup(@() rmpath(char(folder)));
            end

            try
                if ~bdIsLoaded(char(modelName))
                    load_system(char(obj.Session.ModelPath));
                end
                resolvedPath = obj.navigationBlockPath(relPath);
                open_system(char(bdroot(char(resolvedPath))));
                hilite_system(char(resolvedPath), "find");
            catch err
                obj.showNavigationWarning( ...
                    label + " block could not be opened: " + string(err.message), ...
                    label + " Navigation Failed");
            end
        end

        function blockPath = navigationBlockPath(obj, relPath)
            relPath = string(relPath);
            topPath = obj.modelName() + "/" + relPath;
            if obj.blockExists(topPath)
                blockPath = topPath;
                return
            end

            [blockPath, found] = obj.referencedModelBlockPath(relPath);
            if found
                return
            end

            blockPath = obj.resolveExistingBlock(topPath);
        end

        function [blockPath, found] = referencedModelBlockPath(obj, relPath)
            blockPath = "";
            found = false;
            parts = split(string(relPath), "/");
            for n = numel(parts)-1:-1:1
                refBlock = obj.modelName() + "/" + join(parts(1:n), "/");
                if ~obj.blockExists(refBlock)
                    continue
                end
                if string(get_param(char(refBlock), "BlockType")) ~= "ModelReference"
                    continue
                end

                refModel = string(get_param(char(refBlock), "ModelName"));
                if refModel == ""
                    return
                end
                if ~bdIsLoaded(char(refModel))
                    load_system(char(refModel));
                end

                suffix = join(parts(n+1:end), "/");
                refPath = refModel + "/" + suffix;
                blockPath = obj.resolveExistingBlock(refPath);
                found = true;
                return
            end
        end

        function blockPath = resolveExistingBlock(~, blockPath)
            blockPath = string(blockPath);
            requestedPath = blockPath;
            rootPath = extractBefore(blockPath + "/", "/");
            while blockPath ~= ""
                if blockPath == rootPath
                    break
                end
                if getSimulinkBlockHandle(char(blockPath)) ~= -1
                    return
                end

                lastSlash = find(char(blockPath) == '/', 1, "last");
                if isempty(lastSlash)
                    break
                end
                blockPath = extractBefore(blockPath, lastSlash);
            end

            error("eLumina:gds:app:blockNotFound", ...
                "No loaded block was found for '%s'.", requestedPath);
        end

        function tf = blockExists(~, blockPath)
            tf = getSimulinkBlockHandle(char(blockPath)) ~= -1;
        end

        function name = modelName(obj)
            [~, name] = fileparts(obj.Session.ModelPath);
            name = string(name);
        end

        function idx = matchResultRows(obj, blockPath, nvp)
            arguments
                obj
                blockPath (1,1) string
                nvp.PortName (1,1) string = ""
                nvp.PortType (1,1) string = ""
            end

            results = obj.Session.Results;
            if isempty(results)
                idx = zeros(1, 0);
                return
            end

            [exactPaths, prefixPaths] = obj.candidateSignalPaths( ...
                blockPath, ...
                PortName = nvp.PortName, ...
                PortType = nvp.PortType);
            if isempty(exactPaths) && isempty(prefixPaths)
                idx = zeros(1, 0);
                return
            end

            signalPaths = arrayfun(@(r) r.Signal.InstancePath, results);
            fullPaths = arrayfun(@(r) r.Signal.fullPath(), results);
            exactRows = matchingRows(signalPaths, fullPaths, exactPaths, "bus");
            prefixRows = zeros(1, 0);
            for k = 1:numel(prefixPaths)
                prefixRows = [prefixRows, matchingRows( ...
                    signalPaths, fullPaths, prefixPaths(k), "descendant")]; %#ok<AGROW>
            end
            idx = unique([exactRows, prefixRows], "stable");
        end

        function [exactPaths, prefixPaths] = candidateSignalPaths(obj, blockPath, nvp)
            arguments
                obj
                blockPath (1,1) string
                nvp.PortName (1,1) string = ""
                nvp.PortType (1,1) string = ""
            end

            exactPaths = strings(1, 0);
            prefixPaths = strings(1, 0);
            if obj.Session.ModelPath == ""
                return
            end

            blockPath = eraseTrailingSlash(blockPath);
            topModel = obj.modelName();
            topPrefix = topModel + "/";
            if blockPath == topModel
                prefixPaths = topModel;
                return
            end

            if startsWith(blockPath, topPrefix)
                relPath = extractAfter(blockPath, topPrefix);
                if nvp.PortName == ""
                    exactPaths = relPath;
                    prefixPaths = relPath;
                else
                    exactPaths = portSignalPaths(relPath, nvp.PortName);
                end
                return
            end

            refModel = modelNameFromPath(blockPath);
            refBlocks = obj.modelReferenceBlocksFor(refModel);
            if isempty(refBlocks)
                return
            end

            suffix = "";
            refPrefix = refModel + "/";
            if startsWith(blockPath, refPrefix)
                suffix = extractAfter(blockPath, refPrefix);
            end

            refRels = erase(extractAfter(refBlocks, topPrefix), newline);
            for k = 1:numel(refRels)
                if nvp.PortName == ""
                    suffixes = suffix;
                else
                    suffixes = referencedPortSignalPaths(suffix, nvp.PortName);
                end

                if isempty(suffixes)
                    prefixPaths(end+1) = refRels(k); %#ok<AGROW>
                else
                    exactPaths = [exactPaths, refRels(k) + "/" + suffixes]; %#ok<AGROW>
                end
            end
            exactPaths = unique(exactPaths, "stable");
            prefixPaths = unique(prefixPaths, "stable");
        end

        function refBlocks = modelReferenceBlocksFor(obj, refModel)
            if refModel == ""
                refBlocks = strings(1, 0);
                return
            end

            try
                if ~bdIsLoaded(char(obj.modelName()))
                    load_system(char(obj.Session.ModelPath));
                end
                blocks = string(find_system(char(obj.modelName()), ...
                    "LookUnderMasks", "all", ...
                    "BlockType", "ModelReference"));
            catch
                % Missing or unloadable model references simply cannot match.
                refBlocks = strings(1, 0);
                return
            end

            keep = false(size(blocks));
            for k = 1:numel(blocks)
                keep(k) = string(get_param(char(blocks(k)), "ModelName")) == refModel;
            end
            refBlocks = blocks(keep);
        end

        function showNavigationWarning(obj, message, title)
            obj.addWarningStatus(title + ": " + message, ...
                Identifier="eLumina:gds:app:navigationWarning");
        end

        function registerOpenView(obj)
            setappdata(groot, char(obj.AppDataKey), obj);
        end

        function unregisterOpenView(obj)
            [view, found] = eLumina.gds.app.MappingView.currentView();
            if found && view == obj
                rmappdata(groot, char(obj.AppDataKey));
            end
        end

        function onLoadModel(obj)
            [file, folder] = uigetfile( ...
                {'*.slx;*.mdl', 'Simulink models (*.slx, *.mdl)'}, ...
                'Load Simulink model');
            if isequal(file, 0); return; end
            obj.loadModel(string(fullfile(folder, file)));
        end

        function onLoadRules(obj)
            [file, folder] = uigetfile({'*.csv', 'CSV files (*.csv)'}, ...
                'Load override rules CSV');
            if isequal(file, 0); return; end
            obj.loadRules(string(fullfile(folder, file)));
        end

        function onLoadBaseRules(obj)
            [file, folder] = uigetfile({'*.csv', 'CSV files (*.csv)'}, ...
                'Load base rules CSV');
            if isequal(file, 0); return; end
            obj.loadBaseRules(string(fullfile(folder, file)));
        end

        function onLoadConfig(obj)
            [file, folder] = uigetfile({'*.json', 'JSON files (*.json)'}, ...
                'Load project config JSON');
            if isequal(file, 0); return; end
            obj.loadConfig(string(fullfile(folder, file)));
        end

        function onSaveRules(obj)
            if obj.Session.RulesPath == ""
                [file, folder] = uiputfile({'*.csv', 'CSV files (*.csv)'}, ...
                    'Save override rules CSV');
                if isequal(file, 0); return; end
                obj.saveRules(string(fullfile(folder, file)));
            else
                obj.saveRules();
            end
        end

        function onExportResults(obj)
            defaultName = obj.defaultExportName();
            [file, folder] = uiputfile({'*.csv', 'CSV files (*.csv)'}, ...
                'Export results CSV', defaultName);
            if isequal(file, 0); return; end
            obj.exportResults(string(fullfile(folder, file)));
        end

        function runWithStatus(obj, message, fcn)
            arguments
                obj
                message (1,1) string
                fcn (1,1) function_handle
            end
            [~, cleanup] = obj.StatusStack.addStatus( ...
                statusMgr.StatusType.Running, ...
                Identifier="eLumina:gds:app:running", ...
                Message=message, ...
                MessageShort=message); %#ok<ASGLU>
            drawnow
            try
                fcn();
            catch err
                obj.StatusStack.addError(err, CreateCleanupObj=false);
                rethrow(err);
            end
            obj.StatusStack.addStatus( ...
                statusMgr.StatusType.Success, ...
                Identifier="eLumina:gds:app:success", ...
                Message=message + " complete.", ...
                MessageShort=message + " complete.", ...
                IsTemporary=true);
            drawnow
        end

        function name = defaultExportName(obj)
            if obj.Session.ModelPath ~= ""
                [~, base] = fileparts(obj.Session.ModelPath);
                name = string(base) + "_mapping.csv";
            elseif obj.Session.RulesPath ~= ""
                [~, base] = fileparts(obj.Session.RulesPath);
                name = string(base) + "_mapping.csv";
            else
                name = "mapping.csv";
            end
        end

        function onTestSignalChanged(obj, val)
            if val == ""
                obj.TestMatchLabel.Text = "Rule: --";
                obj.TestPathLabel.Text = "Path: --";
                return
            end
            [matched, iecPath, ruleDisplay, ruleOrigin, warning, status] = ...
                obj.Session.testSignal(string(val));
            if matched
                obj.TestMatchLabel.Text = "Rule: " + ruleDisplay + ...
                    " @ " + ruleOrigin;
                if status == eLumina.gds.map.ResultStatus.Broken
                    obj.TestPathLabel.Text = "Path: (broken) " + warning;
                else
                    obj.TestPathLabel.Text = "Path: " + iecPath;
                end
            else
                obj.TestMatchLabel.Text = "Rule: (none)";
                obj.TestPathLabel.Text = "Path: --";
            end
        end

        function onAddRegex(obj)
            answer = inputdlg( ...
                {'Pattern (regex)', 'Template', 'Notes'}, ...
                'Add Regex Rule', 1, {'^x$', 'y', ''});
            if isempty(answer); return; end
            obj.Session.addRule(eLumina.gds.rules.RegexRule( ...
                Pattern = string(answer{1}), ...
                Template = string(answer{2}), ...
                Notes = string(answer{3})));
        end

        function onAddExplicit(obj)
            answer = inputdlg( ...
                {'Simulink path', 'IEC target', 'Notes'}, ...
                'Add Explicit Rule', 1, {'ref1/in1', 'esca_x', ''});
            if isempty(answer); return; end
            obj.Session.addRule(eLumina.gds.rules.ExplicitRule( ...
                Path = string(answer{1}), ...
                Target = string(answer{2}), ...
                Notes = string(answer{3})));
        end

        function onRemoveRule(obj)
            sel = obj.RulesTable.Selection;
            if isempty(sel); return; end
            if ~obj.ensureEditableRuleSelection(sel(1)); return; end
            obj.Session.removeRule(sel(1));
        end

        function onEditRule(obj)
            sel = obj.RulesTable.Selection;
            if isempty(sel); return; end
            idx = sel(1);
            if ~obj.ensureEditableRuleSelection(idx); return; end

            rule = obj.Session.Rules.Rules(idx);
            if isa(rule, "eLumina.gds.rules.RegexRule")
                answer = inputdlg( ...
                    {'Pattern (regex)', 'Template', 'Notes'}, ...
                    'Edit Regex Rule', 1, ...
                    {char(rule.Pattern), char(rule.Template), char(rule.Notes)});
                if isempty(answer); return; end
                newRule = eLumina.gds.rules.RegexRule( ...
                    Pattern = string(answer{1}), ...
                    Template = string(answer{2}), ...
                    Notes = string(answer{3}));
            else
                answer = inputdlg( ...
                    {'Simulink path', 'IEC target', 'Notes'}, ...
                    'Edit Explicit Rule', 1, ...
                    {char(rule.Path), char(rule.Target), char(rule.Notes)});
                if isempty(answer); return; end
                newRule = eLumina.gds.rules.ExplicitRule( ...
                    Path = string(answer{1}), ...
                    Target = string(answer{2}), ...
                    Notes = string(answer{3}));
            end
            obj.Session.updateRule(idx, newRule);
        end

        function onMoveUp(obj)
            sel = obj.RulesTable.Selection;
            if isempty(sel); return; end
            idx = sel(1);
            if ~obj.ensureEditableRuleSelection(idx); return; end
            if idx <= 1; return; end
            obj.Session.moveRuleUp(idx);
            obj.RulesTable.Selection = idx - 1;
        end

        function onMoveDown(obj)
            sel = obj.RulesTable.Selection;
            if isempty(sel); return; end
            idx = sel(1);
            if ~obj.ensureEditableRuleSelection(idx); return; end
            if idx >= numel(obj.Session.OverrideRules.Rules); return; end
            obj.Session.moveRuleDown(idx);
            obj.RulesTable.Selection = idx + 1;
        end

        function tf = ensureEditableRuleSelection(obj, idx)
            tf = true;
            if obj.Session.Rules.Rules(idx).isEditable()
                return
            end
            tf = false;
            obj.addWarningStatus( ...
                "Read-only Rule: Base rules are read-only here. Edit the override rules instead.", ...
                Identifier="eLumina:gds:app:readOnlyRule");
        end
    end

    methods (Static, Access = private)
        function tbl = emptyResultsTable()
            ModelReference = strings(0,1);
            Signal = strings(0,1);
            PlantPath = strings(0,1);
            IecPath = strings(0,1);
            LinkedSignalPath = strings(0,1);
            Status = strings(0,1);
            Rule = strings(0,1);
            Source = strings(0,1);
            Warning = strings(0,1);
            IsOverride = false(0,1);
            RuleIndex = zeros(0,1);
            ShadowTooltip = strings(0,1);
            tbl = table(ModelReference, Signal, PlantPath, IecPath, ...
                LinkedSignalPath, Status, Rule, Source, Warning, IsOverride, ...
                RuleIndex, ShadowTooltip);
        end

        function tbl = emptyRulesTable()
            Layer = strings(0,1);
            Source = strings(0,1);
            Kind = strings(0,1);
            Pattern = strings(0,1);
            Template = strings(0,1);
            Notes = strings(0,1);
            Warning = strings(0,1);
            tbl = table(Layer, Source, Kind, Pattern, Template, Notes, Warning);
        end

        function tbl = resultsToTable(results)
            n = numel(results);
            if n == 0
                tbl = eLumina.gds.app.MappingView.emptyResultsTable();
                return
            end
            ModelReference = strings(n,1);
            Signal = strings(n,1);
            PlantPath = strings(n,1);
            IecPath = strings(n,1);
            LinkedSignalPath = strings(n,1);
            Status = strings(n,1);
            Rule = strings(n,1);
            Source = strings(n,1);
            Warning = strings(n,1);
            IsOverride = false(n,1);
            RuleIndex = zeros(n,1);
            ShadowTooltip = strings(n,1);
            for k = 1:n
                r = results(k);
                [ModelReference(k), Signal(k)] = ...
                    eLumina.gds.app.MappingView.splitDisplaySignalPath(r.Signal.fullPath());
                PlantPath(k) = r.PlantPath;
                IecPath(k) = r.IecPath.Path;
                LinkedSignalPath(k) = r.LinkedSignalPath;
                Status(k) = string(r.Status);
                Rule(k) = eLumina.gds.app.MappingSession.formatRuleDisplay( ...
                    r.RuleIndex, r.RuleSource, r.Shadows);
                Source(k) = r.RuleOrigin;
                Warning(k) = r.Warning;
                IsOverride(k) = r.IsOverride;
                RuleIndex(k) = r.RuleIndex;
                if ~isempty(r.Shadows)
                    ShadowTooltip(k) = "Shadows rules [" + ...
                        strjoin(string(r.Shadows), ", ") + "]";
                end
            end
            tbl = table(ModelReference, Signal, PlantPath, IecPath, ...
                LinkedSignalPath, Status, Rule, Source, Warning, IsOverride, ...
                RuleIndex, ShadowTooltip);
        end

        function tbl = rulesToTable(rules, warnings)
            n = numel(rules);
            if n == 0
                tbl = eLumina.gds.app.MappingView.emptyRulesTable();
                return
            end
            Layer = strings(n,1);
            Source = strings(n,1);
            Kind = strings(n,1);
            Pattern = strings(n,1);
            Template = strings(n,1);
            Notes = strings(n,1);
            Warning = strings(n,1);
            for k = 1:n
                r = rules(k);
                Layer(k) = r.RuleLayer;
                Source(k) = r.provenance();
                if isa(r, "eLumina.gds.rules.RegexRule")
                    Kind(k) = "regex";
                    Pattern(k) = r.Pattern;
                    Template(k) = r.Template;
                else
                    Kind(k) = "explicit";
                    Pattern(k) = r.Path;
                    Template(k) = r.Target;
                end
                Notes(k) = r.Notes;
                Warning(k) = warnings(k);
            end
            tbl = table(Layer, Source, Kind, Pattern, Template, Notes, Warning);
        end

        function blockPath = owningBlockPath(instancePath)
            parts = split(string(instancePath), "/");
            if isscalar(parts)
                blockPath = parts;
            else
                blockPath = join(parts(1:end-1), "/");
            end
        end

        function [modelReference, signalPath] = splitDisplaySignalPath(fullPath)
            parts = split(string(fullPath), "/");
            if isscalar(parts)
                modelReference = "";
                signalPath = parts;
                return
            end

            modelReference = parts(1);
            signalPath = join(parts(2:end), "/");
        end
    end

    methods (Static)
        function [view, found] = currentView()
            key = char(eLumina.gds.app.MappingView.AppDataKey);
            found = false;
            view = eLumina.gds.app.MappingView.empty(1, 0);
            if ~isappdata(groot, key)
                return
            end

            candidate = getappdata(groot, key);
            if isa(candidate, "eLumina.gds.app.MappingView") ...
                    && isvalid(candidate) ...
                    && ~isempty(candidate.Figure) ...
                    && isvalid(candidate.Figure)
                view = candidate;
                found = true;
                return
            end

            rmappdata(groot, key);
        end

        function publishWarning(message, nvp)
            arguments
                message (1,1) string
                nvp.Identifier (1,1) string = "eLumina:gds:app:warning"
            end

            [view, found] = eLumina.gds.app.MappingView.currentView();
            if found
                view.addWarningStatus(message, Identifier=nvp.Identifier);
                return
            end

            stack = statusMgr.util.StatusManager.make( ...
                "GDS Mapping", ...
                EnableCommandWindow=true);
            stack.addStatus( ...
                statusMgr.StatusType.Warning, ...
                Identifier=nvp.Identifier, ...
                Message=message, ...
                MessageShort=message, ...
                IsTemporary=true);
            drawnow
        end
    end
end

function blockPath = eraseTrailingSlash(blockPath)
    blockPath = string(blockPath);
    while endsWith(blockPath, "/")
        blockPath = extractBefore(blockPath, strlength(blockPath));
    end
end

function name = modelNameFromPath(blockPath)
    parts = split(string(blockPath), "/");
    if isempty(parts)
        name = "";
    else
        name = parts(1);
    end
end

function paths = portSignalPaths(basePath, portName)
    basePath = eraseTrailingSlash(basePath);
    portName = string(portName);

    paths = joinPathParts(basePath, portName);
    if lastPathPart(basePath) == portName
        paths = [basePath, paths];
    end
    paths = unique(paths(paths ~= ""), "stable");
end

function paths = referencedPortSignalPaths(basePath, portName)
    paths = unique([portSignalPaths(basePath, portName), string(portName)], ...
        "stable");
    paths = paths(paths ~= "");
end

function rows = matchingRows(signalPaths, fullPaths, candidatePaths, mode)
    rows = zeros(1, 0);
    candidatePaths = string(candidatePaths);
    candidatePaths = candidatePaths(candidatePaths ~= "");
    for i = 1:numel(candidatePaths)
        candidate = candidatePaths(i);
        isMatch = signalPaths == candidate | fullPaths == candidate;
        if mode == "bus" || mode == "descendant"
            isMatch = isMatch | startsWith(fullPaths, candidate + ".");
        end
        if mode == "descendant"
            isMatch = isMatch ...
                | startsWith(signalPaths, candidate + "/") ...
                | startsWith(fullPaths, candidate + "/");
        end
        rows = [rows, find(isMatch)]; %#ok<AGROW>
    end
end

function pathStr = joinPathParts(parentPath, childName)
    parentPath = string(parentPath);
    childName = string(childName);
    if parentPath == ""
        pathStr = childName;
    elseif childName == ""
        pathStr = parentPath;
    else
        pathStr = parentPath + "/" + childName;
    end
end

function part = lastPathPart(pathStr)
    pathStr = string(pathStr);
    if pathStr == ""
        part = "";
        return
    end

    parts = split(pathStr, "/");
    part = parts(end);
end
