local Opt = require("orphans.config").options
local Git = require("orphans.git")
local api = vim.api

local P = {
}

function P.all_possible_plugin_dirs()
    -- pugins are located at `vim.opt.rtp`
    -- vim.opt.rtp:get()
    -- A more convenient way is to use `vim.api.nvim_list_runtime_paths`
    return api.nvim_list_runtime_paths()
end

function P.sort_by_last_commit(plugins)
    table.sort(plugins, function(a, b)
        return a.last_commit_time < b.last_commit_time
    end)
end

function P.sort_by_name(plugins)
    table.sort(plugins, function(a, b)
        return a.name > b.name
    end)
end

-- cache
-- serialize to json

P.is_plugin = function(path)
    if path == vim.fn.stdpath("config") then
        return false
    end
    return Git.is_git_dir(path) and
        (
            vim.fn.isdirectory(path .. "/plugin") == 1 or
            vim.fn.isdirectory(path .. "/autoload") == 1 or
            vim.fn.isdirectory(path .. "/lua") == 1 or
            vim.fn.isdirectory(path .. "/ftplugin") == 1
        )
end

-- Return a semantic string for a time delta.
-- e.g. "1 day ago", "2 hours ago", "over a year" etc.
local function format_delta(time)
    local delta = os.difftime(os.time(), time)
    if delta < 60 then
        return "just now"
    elseif delta < 60 * 60 then
        local minutes = math.floor(delta / 60)
        return minutes .. " minute" .. (minutes ~= 1 and "s" or "") .. " ago"
    elseif delta < 60 * 60 * 24 then
        local hours = math.floor(delta / (60 * 60))
        return hours .. " hour" .. (hours ~= 1 and "s" or "") .. " ago"
    elseif delta < 60 * 60 * 24 * 30 then
        local days = math.floor(delta / (60 * 60 * 24))
        return days .. " day" .. (days ~= 1 and "s" or "") .. " ago"
    elseif delta < 60 * 60 * 24 * 365 then
       local months = math.floor(delta / (60 * 60 * 24 * 30))
       return months .. " month" .. (months ~= 1 and "s" or "") .. " ago"
    else
        local years = math.floor(delta / (60 * 60 * 24 * 365))
        return years .. " year" .. (years ~= 1 and "s" or "") .. " ago"
    end
end

P.new_plugin = function()
    return {
        path = "",
        name = "",
        last_commit_time = 0,
        last_commit_time_str = "",
        last_commit_time_delta = "",
        last_commit_msg = "",
        -- repo_url = "", --TODO: show repo url
    }
end

P.new_plugin_async = function(path, callback)
    local plugin = P.new_plugin()
    Git.last_commit_info_async(path, function(info)
        -- split info by newline, first line is timestamp, second line is commit message
        local t = info:match("^(%d+)\n")
        -- the rest is the commit message, trim the newline
        local msg = info:match("\n(.*)"):gsub("\n", " ")
        t = tonumber(t)
        plugin.path = path
        plugin.name = vim.fn.fnamemodify(path, ":t")
        plugin.last_commit_time = t
        plugin.last_commit_time_str = os.date(Opt.ui.date_format, t)
        plugin.last_commit_time_delta = format_delta(t)
        plugin.last_commit_msg = msg
        vim.schedule(function()
            callback(plugin)
        end)
    end)
end

return P
