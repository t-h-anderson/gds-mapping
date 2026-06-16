function sl_customization(cm)
    %SL_CUSTOMIZATION Register GDS Mapping entries in Simulink context menus.

    cm.addCustomMenuFcn('Simulink:PreContextMenu', @gdsContextMenu);
end

function schemaFcns = gdsContextMenu(~)
    schemaFcns = {@gdsMenu};
end

function schema = gdsMenu(~)
    schema = sl_container_schema;
    schema.tag = 'eLumina:gds:contextMenu';
    schema.label = 'GDS Mapping';
    schema.childrenFcns = {@openGdsAppSchema, @showInGdsAppSchema};
    schema.autoDisableWhen = 'Busy';
    schema.state = 'Enabled';
end

function schema = openGdsAppSchema(~)
    schema = sl_action_schema;
    schema.tag = 'eLumina:gds:openApp';
    schema.label = 'Open App for Model';
    schema.callback = @eLumina.gds.simulink.openApp;
    schema.autoDisableWhen = 'Busy';
    schema.state = 'Enabled';
end

function schema = showInGdsAppSchema(~)
    schema = sl_action_schema;
    schema.tag = 'eLumina:gds:showInOpenApp';
    schema.label = 'Show Port in Open App';
    schema.callback = @eLumina.gds.simulink.showInApp;
    schema.autoDisableWhen = 'Busy';
    schema.state = 'Enabled';
end
