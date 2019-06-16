-- Contains the functionality used by all picker dialogs
picker = {}

-- Adds a bar containing checkboxes to control whether enabled and hidden picks should be shown
function picker.refresh_filter_conditions(flow, disabled_caption, hidden_caption)
    if enabled_caption ~= nil or hidden_caption ~= nil then
        if flow["table_filter_conditions"] == nil then
            local table = flow.add{type="table", name="table_filter_conditions", column_count=3}
            table.style.horizontal_spacing = 16

            table.add{type="label", name="label_filter_conditions", caption={"label.show"}}
            if disabled_caption ~= nil then
                table.add{type="checkbox", name="fp_checkbox_picker_filter_condition_disabled", 
                  caption=disabled_caption, state=false}
            end
            if hidden_caption ~= nil then
                table.add{type="checkbox", name="fp_checkbox_picker_filter_condition_hidden", 
                  caption=hidden_caption, state=false}
            end
        end
    end
end


-- Adds a bar containing a search bar that is optionally hidden
function picker.refresh_search_bar(flow, search_term, visible)
    local table = flow["table_search_bar"]
    if table == nil then
        table = flow.add{type="flow", name="table_search_bar", direction="horizontal"}
        table.style.bottom_margin = 2
        table.style.horizontal_spacing = 12
        table.style.vertical_align = "center"
    else
        table.clear()
    end
    table.visible = visible

    table.add{type="label", name="label_search_bar", caption={"label.search"}}
    local textfield = table.add{type="textfield", name="fp_textfield_picker_search_bar", text=search_term}
    textfield.style.width = 140
    if visible then textfield.focus() end
end


-- Adds a warning label to the dialog
function picker.refresh_warning_label(flow, message)
    local label = flow["label_warning_message"]
    if label == nil then
        label = flow.add{type="label", name="label_warning_message"}
        label.style.font = "fp-font-16p"
        ui_util.set_label_color(label, "red")
        label.style.bottom_margin = 4
    end
    if (message == "") then
        label.visible = false
        label.style.top_margin = 0
    else
        label.visible = true
        label.style.top_margin = 6
    end
    label.caption = message
end


-- Extracts, formats and sorts (by their group, subgroup and order) all objects so they can be displayed
function picker.create_object_tree(objects)
    -- First, categrorize the objects according to the order of their group, subgroup and themselves
    local unsorted_object_tree = {}
    for _, object in pairs(objects) do
        if unsorted_object_tree[object.group.order] == nil then
            unsorted_object_tree[object.group.order] = {}
        end
        local group = unsorted_object_tree[object.group.order]
        if group[object.subgroup.order] == nil then
            group[object.subgroup.order] = {}
        end
        local subgroup = group[object.subgroup.order]
        if subgroup[object.order] == nil then
            subgroup[object.order] = {}
        end
        table.insert(subgroup[object.order], object)
    end

    -- Then, sort them according to the orders into a new array
    -- Messy tree structure, but avoids modded situations where multiple objects have the same order
    local sorted_object_tree = {}
    local group_name, group_localised_name, subgroup_name
    for _, group in ui_util.pairsByKeys(unsorted_object_tree) do
        table.insert(sorted_object_tree, {name=nil, localised_name=nil, subgroups={}})
        local table_group = sorted_object_tree[#sorted_object_tree]
        for _, subgroup in ui_util.pairsByKeys(group) do
            table.insert(table_group.subgroups, {name=nil, objects={}})
            local table_subgroup = table_group.subgroups[#table_group.subgroups]
            for _, object_order in ui_util.pairsByKeys(subgroup) do
                for _, object in ipairs(object_order) do
                    if not group_name then group_name = object.group.name end
                    if not group_localised_name then group_localised_name = object.group.localised_name end
                    if not subgroup_name then subgroup_name = object.subgroup.name end
                    table.insert(table_subgroup.objects, object)
                end
            end
            table_subgroup.name = subgroup_name
            subgroup_name = nil
        end
        table_group.name = group_name
        group_name = nil
        table_group.localised_name = group_localised_name
        group_localised_name = nil
    end

    return sorted_object_tree
end

-- Refreshes the actual picker panel, for the given object type and with the given visibility
function picker.refresh_picker_panel(flow, object_type, visible)
    local player = game.get_player(flow.player_index)

    local flow_picker_panel = flow["flow_picker_panel"]
    if flow_picker_panel == nil then
        flow_picker_panel = flow.add{type="flow", name="flow_picker_panel", direction="vertical"}
        flow_picker_panel.style.top_margin = 6

        local table_item_groups = flow_picker_panel.add{type="table", name="table_item_groups", column_count=6}
        table_item_groups.style.bottom_margin = 6
        table_item_groups.style.horizontal_spacing = 3
        table_item_groups.style.vertical_spacing = 3
        table_item_groups.style.minimal_width = 6 * (64 + 9)

        local formatted_objects = picker.create_object_tree(_G["get_picker_" .. object_type .. "s"](player))
        for _, group in ipairs(formatted_objects) do
            if group.name ~= "creative-mod_creative-tools" then
                -- Item groups
                button_group = table_item_groups.add{type="sprite-button", name="fp_sprite-button_item_group_" .. group.name,
                  sprite="item-group/" .. group.name, style="fp_button_icon_medium_recipe", mouse_button_filter={"left"}}
                button_group.style.width = 70
                button_group.style.height = 70
                button_group.tooltip = group.localised_name
                if devmode then button_group.tooltip = {"", button_group.tooltip, "\n", group.name} end

                local scroll_pane_subgroups = flow_picker_panel.add{type="scroll-pane", name="scroll-pane_subgroups_"
                  .. group.name}
                scroll_pane_subgroups.style.bottom_margin = 4
                scroll_pane_subgroups.style.horizontally_stretchable = true
                local table_subgroup = scroll_pane_subgroups.add{type="table", name="table_subgroup", column_count=1}
                table_subgroup.style.vertical_spacing = 3
                for _, subgroup in ipairs(group.subgroups) do
                    -- Item subgroups
                    local table_subgroup = table_subgroup.add{type="table", name="table_subgroup_" .. subgroup.name,
                    column_count = 12}
                    table_subgroup.style.horizontal_spacing = 2
                    table_subgroup.style.vertical_spacing = 1
                    for _, object in ipairs(subgroup.objects) do
                        -- Objects
                        local sprite = ui_util["get_" .. object_type .. "_sprite"](player, object)
                        local button_object = table_subgroup.add{type="sprite-button", name="fp_sprite-button_picker_object_"
                          .. object.name, sprite=sprite, style="fp_button_icon_medium_recipe", mouse_button_filter={"left"}}
                        button_object.tooltip = _G["generate_" .. object_type .. "_tooltip"](object)
                        if devmode then button_object.tooltip = {"", button_object.tooltip, "\n", object.name} end
                    end
                end
            end
        end
    end

    flow_picker_panel.visible = visible
end


-- Applies filters to the object picker, optionally also (re)applies an appropriate button style
-- (This function is not object-type-agnostic for performance reasons (minimizing function calls))
function picker.apply_filter(player, object_type, apply_button_style)
    local flow_modal_dialog = player.gui.center["fp_frame_modal_dialog_" .. object_type .. "_picker"]["flow_modal_dialog"]
    local search_term = flow_modal_dialog["table_search_bar"]["fp_textfield_picker_search_bar"].text:gsub("^%s*(.-)%s*$", "%1")
    local warning_label = flow_modal_dialog["label_warning_message"]

    local disabled, hidden
    local existing_products = {}
    if object_type == "recipe" then
        disabled = flow_modal_dialog["table_filter_conditions"]["fp_checkbox_picker_filter_condition_disabled"].state
        hidden = flow_modal_dialog["table_filter_conditions"]["fp_checkbox_picker_filter_condition_hidden"].state
    else
        for _, product in pairs(Subfactory.get_in_order(get_context(player).subfactory, "Product")) do
            existing_products[product.name] = true
        end
    end

    local preferences = get_preferences(player)
    
    local first_visible_group = nil
    local visible_group_count = 0
    local total_group_count = 0
    local scroll_pane_height = 0
    for _, group_element in pairs(flow_modal_dialog["flow_picker_panel"]["table_item_groups"].children) do
        -- Dimensions need to be re-set here because they don't seem to survive a save-load-cycle
        group_element.style.width = 70
        group_element.style.height = 70

        local group_name = string.gsub(group_element.name, "fp_sprite%-button_item_group_", "")
        local group_visible = false
        local specific_scroll_pane_height = 0
        local subgroup_count = 0
        local subgroup_elements = flow_modal_dialog["flow_picker_panel"]["scroll-pane_subgroups_".. group_name]
          ["table_subgroup"].children
        for _, subgroup_element in pairs(subgroup_elements) do
            local subgroup_visible = false
            local object_count = 0
            for _, object_element in pairs(subgroup_element.children) do
                local object_name = string.gsub(object_element.name, "fp_sprite%-button_picker_object_", "")
                
                local visible = true
                if object_type == "item" then
                    -- (Re)apply an appropriate button style if need be
                    if apply_button_style then
                        if existing_products[object_name] then object_element.style = "fp_button_icon_medium_disabled"
                        else object_element.style = "fp_button_icon_medium_recipe" end
                    end

                    -- Set visibility of objects (and item-groups) appropriately
                    if not string.find(string.lower(object_name), string.lower(search_term), 1, true) then
                        visible = false
                    end

                elseif object_type == "recipe" then
                    local recipe = global.all_recipes[player.force.name][object_name]

                    -- (Re)apply an appropriate button style if need be
                    if apply_button_style then
                        if not recipe.enabled then object_element.style = "fp_button_icon_medium_disabled" 
                        elseif recipe.hidden then object_element.style = "fp_button_icon_medium_hidden"
                        else object_element.style = "fp_button_icon_medium_recipe" end
                    end

                    -- Set visibility of objects (and item-groups) appropriately
                    if item_recipe_map[search_term][recipe.name] == nil
                      or (not disabled and not recipe.enabled) or (not hidden and recipe.hidden)
                      or (preferences.ignore_barreling_recipes
                      and (recipe.subgroup.name == "empty-barrel" or recipe.subgroup.name == "fill-barrel")) then
                        visible = false
                    end
                end

                if visible then
                    object_element.visible = true
                    subgroup_visible = true
                    group_visible = true
                else
                    object_element.visible = false
                end
                
                object_count = object_count + 1
            end
            subgroup_element.visible = subgroup_visible
            specific_scroll_pane_height = specific_scroll_pane_height +  math.ceil(object_count / 12) * 33
            subgroup_count = subgroup_count + 1
        end
        group_element.visible = group_visible
        specific_scroll_pane_height = specific_scroll_pane_height + subgroup_count * 3
        scroll_pane_height = math.max(scroll_pane_height, specific_scroll_pane_height)
        
        if group_visible then
            visible_group_count = visible_group_count + 1
            if first_visible_group == nil then first_visible_group = group_name end
        end
        total_group_count = total_group_count + 1
    end

    -- Set selection to the first item group that is visible, respecting a previous selection
    local previously_selected_group = picker.get_selected_item_group_name(player, object_type)
    if (previously_selected_group == nil) or (not previously_selected_group.visible and first_visible_group ~= nil) then
        picker.select_item_group(player, object_type, first_visible_group)
    end


    -- Show warning message if no corresponding items/recipes are found
    if first_visible_group == nil then 
        picker.refresh_warning_label(flow_modal_dialog, {"label.error_no_" .. object_type .. "_found"})
    else picker.refresh_warning_label(flow_modal_dialog, "") end
    local warning_label_height = (warning_label.caption == "") and 0 or 38
    
    -- Set item group height and picker panel heights to always add up to the same so the dialog window size doesn't change
    local flow_picker_panel = flow_modal_dialog["flow_picker_panel"]
    local group_row_count = math.ceil(visible_group_count / 6)
    flow_picker_panel["table_item_groups"].style.height = group_row_count * 70
    
    -- Set scroll-pane height to be the same for all item groups
    scroll_pane_height = scroll_pane_height + (math.ceil(total_group_count / 6) * 70)
    local picker_panel_height = math.min(scroll_pane_height, 700) - (group_row_count) * 70 - warning_label_height
    for _, child in ipairs(flow_picker_panel.children_names) do
        if string.find(child, "^scroll%-pane_subgroups_[a-z-]+$") then
            flow_picker_panel[child].style.height = picker_panel_height
        end
    end
end


-- Returns the name of the currently selected item group, else if none is selected
function picker.get_selected_item_group_name(player, object_type)
    local picker_panel = player.gui.center["fp_frame_modal_dialog_" .. object_type .. "_picker"]
      ["flow_modal_dialog"]["flow_picker_panel"]

    for _, group_button in pairs(picker_panel["table_item_groups"].children) do
        if group_button.style.name == "fp_button_icon_clicked" then
            return group_button
        end
    end
    return nil
end

-- Changes the selected item group to be the one specified by the given name
function picker.select_item_group(player, object_type, item_group_name)
    local flow_modal_dialog = player.gui.center["fp_frame_modal_dialog_" .. object_type .. "_picker"]
      ["flow_modal_dialog"]
    picker.refresh_warning_label(flow_modal_dialog, "")

    for _, group_button in pairs(flow_modal_dialog["flow_picker_panel"]["table_item_groups"].children) do
        local name = string.gsub(group_button.name, "fp_sprite%-button_item_group_", "")
        local scroll_pane_items = flow_modal_dialog["flow_picker_panel"]["scroll-pane_subgroups_" .. name]
        if name == item_group_name then
            group_button.style = "fp_button_icon_clicked"
            group_button.mouse_button_filter = {"middle"}  -- Makes the button not click on normal clicks
            scroll_pane_items.visible = true
        else
            group_button.style = "fp_button_icon_medium_recipe"
            group_button.mouse_button_filter = {"left"}
            scroll_pane_items.visible = false
        end
    end
end

-- Handles a new search term in the search bar
function picker.search(player)
    local ui_state = get_ui_state(player)
    local object_type = string.gsub(ui_state.modal_dialog_type, "_picker", "")
    picker.apply_filter(player, object_type, false)
end