-- Handles populating the recipe picker dialog
function open_recipe_picker_dialog(flow_modal_dialog)
    local player = game.get_player(flow_modal_dialog.player_index)
    local ui_state = get_ui_state(player)
    local product = ui_state.selected_object

    flow_modal_dialog.parent.caption = {"label.add_recipe"}
    flow_modal_dialog.style.bottom_margin = 8

    local recipe, error, show = run_preliminary_checks(player, product)
    if error ~= nil then
        queue_message(player, error, "warning")
        exit_modal_dialog(player, "cancel", {})
    else
        -- If 1 relevant, enabled, non-duplicate recipe is found, add it immediately and exit dialog
        if recipe ~= nil then
            Floor.add(ui_state.context.floor, Line.init(player, recipe))
            update_calculations(player, ui_state.context.subfactory)
            if show.message ~= nil then queue_message(player, show.message.string, show.message.type) end
            exit_modal_dialog(player, "cancel", {})
        
        else  -- Otherwise, show the appropriately filtered dialog
            picker.refresh_filter_conditions(flow_modal_dialog, {"checkbox.unresearched_recipes"}, {"checkbox.hidden_recipes"})
            picker.refresh_search_bar(flow_modal_dialog, product.name, false)
            picker.refresh_warning_label(flow_modal_dialog, "")
            flow_modal_dialog["table_filter_conditions"]["fp_checkbox_picker_filter_condition_disabled"].state = show.disabled
            flow_modal_dialog["table_filter_conditions"]["fp_checkbox_picker_filter_condition_hidden"].state = show.hidden
            picker.refresh_picker_panel(flow_modal_dialog, "recipe", true)

            picker.select_item_group(player, "recipe", "logistics")
            picker.apply_filter(player, "recipe", true)
        end
    end
end


-- Reacts to either the disabled or hidden radiobutton being pressed
function handle_filter_radiobutton_click(player, type, state)
    local ui_state = get_ui_state(player)

    -- Remember the user selection for this type of filter
    ui_state.recipe_filter_preferences[type] = state

    picker.apply_filter(player, "recipe", false)
end

-- Reacts to a picker recipe button being pressed
function handle_picker_recipe_click(player, button)
    local context = get_context(player)
    local recipe_name = string.gsub(button.name, "fp_sprite%-button_picker_object_", "")
    local recipe = global.all_recipes[player.force.name][recipe_name]
    
    Floor.add(context.floor, Line.init(player, recipe))
    update_calculations(player, context.subfactory)
    exit_modal_dialog(player, "cancel", {})
end


-- Serves the dual-purpose of setting the filter to include disabled recipes if no enabled ones are found
-- and, if there is only one that matches, to return a recipe name that can be added directly without the modal dialog
-- (This is more efficient than the big filter-loop, which would have to run twice otherwise)
function run_preliminary_checks(player, product)
    -- First determine all relevant recipes and the amount in each category (enabled and hidden)
    local relevant_recipes = {}
    local disabled_recipes_count = 0
    if item_recipe_map[product.type][product.name] ~= nil then  -- this being nil means that the item has no recipes
        for _, recipe in pairs(global.all_recipes[player.force.name]) do
            if recipe_produces_product(player, recipe, product.type, product.name) then
                table.insert(relevant_recipes, recipe)
                if not recipe.enabled then disabled_recipes_count = disabled_recipes_count + 1 end
            end
        end
    end
    
    -- Set filters to try and show at least one recipe, should one exist, incorporating user preferences
    local user_prefs = get_ui_state(player).recipe_filter_preferences
    local show = {disabled = user_prefs.disabled, hidden = user_prefs.hidden, message = nil}
    if not user_prefs.disabled and (#relevant_recipes - disabled_recipes_count) == 0 then
        show.disabled = true  -- avoids showing no recipes if there are some disabled ones
    end
    
    -- Return result, format: return recipe, error-message, show
    if #relevant_recipes == 0 then
        return nil, {"label.error_no_relevant_recipe"}, show
    elseif #relevant_recipes == 1 then
        local recipe = relevant_recipes[1]
        if not recipe.enabled then  -- Show hint if adding unresearched recipe
            show.message={string={"label.hint_disabled_recipe"}, type="hint"}
        end
        return recipe, nil, show
    else  -- 2+ relevant recipes
        return nil, nil, show
    end
end


-- Returns all recipes
function get_picker_recipes(player)
    return global.all_recipes[player.force.name]
end

-- Generates the tooltip string for the given recipe
function generate_recipe_tooltip(recipe)
    local tooltip = recipe.localised_name
    if recipe.energy ~= nil then 
        tooltip = {"", tooltip, "\n  ", {"tooltip.crafting_time"}, ":  ", recipe.energy}
    end

    local lists = {"ingredients", "products"}
    for _, item_type in ipairs(lists) do
        if recipe[item_type] ~= nil then
            tooltip = {"", tooltip, "\n  ", {"tooltip." .. item_type}, ":"}
            for _, item in ipairs(recipe[item_type]) do
                if item.amount == nil then item.amount = item.probability end
                tooltip = {"", tooltip, "\n    ", "[", item.type, "=", item.name, "] ", item.amount, "x ",
                  game[item.type .. "_prototypes"][item.name].localised_name}
            end
        end
    end

    return tooltip
end

-- Returns true when the given recipe produces the given product
-- (Tries all types if no product type is given)
function recipe_produces_product(player, recipe, product_type, product_name)
    -- Exclude barreling recipes according to preference
    if (get_preferences(player).ignore_barreling_recipes and (recipe.subgroup.name == "empty-barrel"
      or recipe.subgroup.name == "fill-barrel")) then
        return false
    else
        if product_type ~= nil then
            return item_recipe_map[product_type][product_name][recipe.name] 
        else
            local product_types = {"item", "fluid", "entity"}
            for _, type in ipairs(product_types) do
                if item_recipe_map[type][product_name] ~= nil 
                  and item_recipe_map[type][product_name][recipe.name] then
                    return true
                end
            end
            return false  -- return false if no product is found
        end
    end
end
