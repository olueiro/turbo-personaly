--[[
The MIT License (MIT)
Copyright (c) 2016 olueiro <github.com/olueiro>
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

_G.TURBO_SSL = true
_G.TURBO_STATIC_MAX = -1
local turbo = require("turbo")
local fetch = require("turbo-fetch")
local huntable = require("huntable")

-- is_ok, result, exit_code, exit_method = os.capture(command[, table_args = {}][, is_raw = true][, callback_lines = nil])
local function oscapture(a, b, c, d)
  if type(b) ~= "table" then
    d = c
    c = b
    b = {}
  end
  if type(c) ~= "boolean" then
    d = c
    c = true
  end
  local e = {""}
  local function f(a)
    if string.find(a, "[|;%s%(%)]") then
      a = string.gsub(a, "\"", "\\\"")
      return "\"" .. a .. "\""
    end
    return a
  end
  for g, h in pairs(b) do
    if tonumber(g) then
      e[#e+1] = f(h)
    else
      e[#e+1] = g .. " " .. f(h)
    end
  end
  local _, i = pcall(io.popen, a .. table.concat(e, " "), "r")
  local j = {}
  if d then
    local _, k = pcall(i.read, i, "*l")
    while k do
      d(k)
      j[#j+1] = k
      _, k = pcall(i.read, i, "*l")
    end
    j = table.concat(j, "\n")
  else
    _, j = pcall(i.read, i, "*a")
  end
  local _, l, m, n = pcall(i.close, i)
  if c then
    return l, j, n, m
  end
  j = string.gsub(j, "^%s+", "")
  j = string.gsub(j, "%s+$", "")
  j = string.gsub(j, "[\n\r]+", " ")
  return l, j, n, m
end

local personaly = {}
local personaly_mt = {
  __index = personaly
}

local sessions = {}

function personaly.new(data)
  local app = setmetatable({}, personaly_mt)

  app.data = {
    application = nil,
    address = "http://127.0.0.1",
    basedir = "turbopersonaly/",
    baseurl = "/turbopersonaly/",
    login_interval = 3600,
    users = {
      --[[admin = {
        url = "",
        password = ""
      }]]
    }
  }
  turbo.util.tablemerge(app.data, data)

  for key, _ in pairs(app.data.users) do
    if key == "" or string.find(key, "%W") then
      error(string.format("Invalid name for user '%s'.", key))
    end
  end

  if not app.data.application then
    app.data.application = turbo.web.Application()
  end

  app.onPromote = function() end

  local has_user = false
  for user_name, _ in pairs(app.data.users) do
    has_user = true
    local status, content = oscapture(string.format("[ -d %s ] && echo ok", app.data.basedir .. "campaigns/" .. user_name))
    if status and not string.find(content, "ok") then
      local status, content = oscapture(string.format("mkdir %s", app.data.basedir .. "campaigns/" ..user_name))
    end
  end

  local function add_static()
    oscapture("ls -a", {app.data.basedir .. "campaigns/"}, function(line)
      if string.find(line, "^%w+$") then
        oscapture("ls -a", {app.data.basedir .. "campaigns/" .. line}, function(line2)
          if string.find(line2, "^%w+$") then
            app.data.application:add_handler("^" .. app.data.baseurl .. "static/" .. line .. "/" .. line2 .. "/(.*)$", turbo.web.StaticFileHandler, app.data.basedir .. "campaigns/" .. line .. "/" .. line2 .. "/")
          end
        end)
      end
    end)
  end

  add_static()

  if has_user then

    local webappIndex = class("webappIndex", turbo.web.RequestHandler)

    function webappIndex:get()
      local session = self:get_cookie("turbo-session")
      local user_logged = false
      local user_not_logged = true
      local user_name = ""
      if session and sessions[session] then
        user_logged = true
        user_not_logged = false
        user_name = sessions[session].username
      end

      if user_logged then

        local user_data = {
          tracking = {},
          tags = {} -- {campaign_id, creative_filename, tag}
        }

        local file = io.open(app.data.basedir .. "users/" .. user_name .. ".json")

        content = nil

        if file then
          content = file:read("*a")
          file:close()
          local status, result = pcall(turbo.escape.json_decode, content)
          if status then
            user_data = result
          end
        end

        local tracking = user_data.tracking

        if not content then
          file = io.open(app.data.basedir .. "users/" .. user_name .. ".json", "w")
          file:write(turbo.escape.json_encode(user_data))
          file:close()
        end

        local user_callback = app.data.address .. app.data.baseurl .. "tracking?user=" .. turbo.escape.escape(user_name) .. "&clickid={clickid}&subid1={subid1}&subid2={subid2}&subid3={subid3}&subid4={subid4}&subid5={subid5}&campaign_id={campaign_id}&idfa={idfa}&gaid={gaid}&ip={ip}&payout={payout}&device_model={device_model}&device_brand={device_brand}&os={os}&os_version={os_version}&user_agent={user_agent}&operator={operator}"

        local response = coroutine.yield(turbo.async.HTTPClient():fetch(app.data.users[user_name].url))

        if not response or response.error then
          error(turbo.web.HTTPError(404, "error on request campaigns"))
          return
        end

        local status, content = pcall(turbo.escape.json_decode, response.body)
        if status then

          local campaigns = {}

          for _, value in pairs(content.campaigns or {}) do
            local status, content = oscapture(string.format("[ -d %s ] && echo ok", app.data.basedir .. "campaigns/" .. user_name .. "/" .. value.id))
            local enabled = false
            if status and string.find(content, "ok") then
              enabled = true
            end
            value.enabled = enabled
            if value.enabled then
              if value.categories then
                value.categories = table.concat(value.categories, ", ")
              end
              local campaign_icon_url
              if value.campaign_icon_url then
                campaign_icon_url = string.lower(string.match(value.campaign_icon_url, "([^/]-)$"))
                if campaign_icon_url then
                  campaign_icon_url = app.data.address .. app.data.baseurl .. "static/" .. user_name .. "/" .. value.id .. "/" .. campaign_icon_url
                  value.campaign_icon_url = campaign_icon_url
                end
              end
              local creatives = {}
              for key2, _ in ipairs(value.creatives) do
                for _, value3 in ipairs(value.creatives[key2]) do
                  creatives[#creatives+1] = value3
                end
              end
              value.creatives = creatives
              for key2, value2 in ipairs(value.creatives) do
                local filename = string.match(value2.creative_url or "", "f_name=([^&]+)")
                if filename and filename ~= "" then
                  filename = string.lower(turbo.escape.unescape(filename))
                  if turbo.util.file_exists(app.data.basedir.. "campaigns/" .. user_name .. "/" .. value.id .. "/" .. filename) then
                    value.creatives[key2].creative_url = app.data.address .. app.data.baseurl .. "static/" .. user_name .. "/" .. value.id .. "/" .. filename
                    value.creatives[key2].creative_id = value.id .. "-" .. string.gsub(filename, "%W", "")
                  else
                    table.remove(value.creatives, key2)
                  end
                  if value2.creative_dimensions then
                    value.creatives[key2].creative_dimensions_width = value2.creative_dimensions.width
                    value.creatives[key2].creative_dimensions_height = value2.creative_dimensions.height
                  end
                else
                  table.remove(value.creatives, key2)
                end
              end
              for _, value2 in ipairs(value.payouts) do
                value2.countries = table.concat(value2.countries, ", ")
                value2.cities = table.concat(value2.cities, ", ")
              end
              for key2, value2 in pairs(value.subscription_caps) do
                value[key2] = value2
              end
              for key2, value2 in pairs(value.traffic_restrictions) do
                value[key2] = value2
              end
              for key2, value2 in pairs(value.blacklist) do
                value[key2] = table.concat(value2, ", ")
                value.show_blacklist = true
              end
            end
            table.insert(campaigns, value)
          end

          self:write(turbo.web.Mustache.render(turbo.web.Mustache.compile(turbo.util.read_all(app.data.basedir .. "turbopersonaly.html")), {
            baseurl = app.data.address .. app.data.baseurl,
            user_logged = user_logged,
            user_not_logged = user_not_logged,
            user_name = user_name,
            user_data = user_data,
            user_callback = user_callback,
            campaigns = campaigns,
            tracking = tracking
          }))

        else
          error(turbo.web.HTTPError(404, "error on request campaigns"))
        end

      else

        self:write(turbo.web.Mustache.render(turbo.web.Mustache.compile(turbo.util.read_all(app.data.basedir .. "turbopersonaly.html")), {
          baseurl = app.data.address .. app.data.baseurl,
          user_logged = user_logged,
          user_not_logged = user_not_logged,
        }))

      end
    end

    app.data.application:add_handler("^" .. app.data.baseurl .. "$", webappIndex)

    local webappLogin = class("webappLogin", turbo.web.RequestHandler)

    function webappLogin:post()
      local session = self:get_cookie("turbo-session")
      if not session or not sessions[session] then
        local password = self:get_argument("password")
        if password then
          for user, value in pairs(app.data.users) do
            if value.password == password then
              local session_id = turbo.hash.SHA1(turbo.util.rand_str()):hex()
              sessions[session_id] = value
              sessions[session_id].username = user
              self:set_cookie("turbo-session", session_id)
              self:redirect(app.data.address .. app.data.baseurl)
              return
            end
          end
        end
      end

      error(turbo.web.HTTPError(404, "invalid login attempt"))
    end

    app.data.application:add_handler("^" .. app.data.baseurl .. "login$", webappLogin)

    local webappLogout = class("webappLogout", turbo.web.RequestHandler)

    function webappLogout:get()
      local session = self:get_cookie("turbo-session")
      if session and sessions[session] then
        self:set_cookie("turbo-session", "")
        sessions[session] = nil
        self:redirect(app.data.address ..app.data.baseurl)
        return
      end
      error(turbo.web.HTTPError(404, "invalid logout attempt"))
    end

    app.data.application:add_handler("^" .. app.data.baseurl .. "logout$", webappLogout)

    local webappAddTag = class("webappAddTag", turbo.web.RequestHandler)

    function webappAddTag:get()
      local session = self:get_cookie("turbo-session")
      if session and sessions[session] then
        local user_name = sessions[session].username
        local file = io.open(app.data.basedir .. "users/" .. user_name .. ".json")
        if file then
          local content = file:read("*a")
          file:close()
          local status, result = pcall(turbo.escape.json_decode, content)
          if status then
            local tag = self:get_argument("tag")
            local id = self:get_argument("id")
            if tag and id then
              local campaign = string.match(id, "^(.-)%-")
              local filename = string.match(id, "^.-%-(.*)")
              if campaign and filename then
                local exists = false
                for _, value in ipairs(result.tags) do
                  if value[1] == tonumber(campaign) and value[2] == filename and value[3] == tag then
                    exists = true
                    break
                  end
                end
                if not exists then
                  table.insert(result.tags, {tonumber(campaign) , filename, tag})
                  local file = io.open(app.data.basedir .. "users/" .. user_name .. ".json", "w")
                  file:write(turbo.escape.json_encode(result))
                  file:close()
                end
                self:write("ok")
              end
            end
          end
        end
      end
    end

    app.data.application:add_handler("^" .. app.data.baseurl .. "addtag$", webappAddTag)

    local webappGetTags = class("webappGetTags", turbo.web.RequestHandler)

    function webappGetTags:get()
      local session = self:get_cookie("turbo-session")
      if session and sessions[session] then
        local user_name = sessions[session].username
        local file = io.open(app.data.basedir .. "users/" .. user_name .. ".json")
        if file then
          local content = file:read("*a")
          file:close()
          local status, result = pcall(turbo.escape.json_decode, content)
          if status then
            local id = self:get_argument("id")
            if id then
              local campaign = string.match(id, "^(.-)%-")
              local filename = string.match(id, "^.-%-(.*)")
              if campaign and filename then
                local tags = {}
                for _, value in ipairs(result.tags) do
                  if value[1] == tonumber(campaign) and value[2] == filename then
                    tags[#tags+1] = value[3]
                  end
                end
                self:write(table.concat(tags, ", "))
              end
            end
          end
        end
      end
    end

    app.data.application:add_handler("^" .. app.data.baseurl .. "gettags$", webappGetTags)

    local webappClearTags = class("webappClearTags", turbo.web.RequestHandler)

    function webappClearTags:get()
      local session = self:get_cookie("turbo-session")
      if session and sessions[session] then
        local user_name = sessions[session].username
        local file = io.open(app.data.basedir .. "users/" .. user_name .. ".json")
        if file then
          local content = file:read("*a")
          file:close()
          local status, result = pcall(turbo.escape.json_decode, content)
          if status then
            local id = self:get_argument("id")
            if id then
              local campaign = string.match(id, "^(.-)%-")
              local filename = string.match(id, "^.-%-(.*)")
              if campaign and filename then
                local tags = {}
                for _, value in ipairs(result.tags) do
                  if value[1] ~= tonumber(campaign) or value[2] ~= filename then
                    tags[#tags+1] = value
                  end
                end
                result.tags = tags
                local file = io.open(app.data.basedir .. "users/" .. user_name .. ".json", "w")
                file:write(turbo.escape.json_encode(result))
                file:close()
                self:write("ok")
              end
            end
          end
        end
      end
    end

    app.data.application:add_handler("^" .. app.data.baseurl .. "cleartags$", webappClearTags)

    local webappActivate = class("webappActivate", turbo.web.RequestHandler)

    function webappActivate:get()
      local session = self:get_cookie("turbo-session")
      if session and sessions[session] then
        local user_name = sessions[session].username
        local campaign = self:get_argument("id")
        if campaign then
          local status, content = oscapture(string.format("[ -d %s ] && echo ok", app.data.basedir .. "campaigns/" ..user_name .. "/" .. campaign))
          if status and not string.find(content, "ok") then
            local status, content = oscapture(string.format("mkdir %s", app.data.basedir .. "campaigns/" ..user_name .. "/" .. campaign))
            if status then
              local campaign_path = app.data.basedir .. "campaigns/" ..user_name .. "/" .. campaign

              local response = coroutine.yield(turbo.async.HTTPClient():fetch(app.data.users[user_name].url))

              if not response or response.error then
                self:redirect(app.data.address .. app.data.baseurl)
                return
              end

              local status, content = pcall(turbo.escape.json_decode, response.body)
              if status and content.campaigns then
                local campaign_item
                for _, value in ipairs(content.campaigns) do
                  if tostring(value.id) == tostring(campaign) then
                    campaign_item = value
                    break
                  end
                end
                if campaign_item then
                  local campaign_icon_url = campaign_item.campaign_icon_url
                  if campaign_icon_url then
                    local campaign_icon_name = string.lower(string.match(campaign_icon_url, "([^/]-)$"))

                    local response = coroutine.yield(turbo.async.HTTPClient():fetch(campaign_icon_url, {
                      request_timeout = 600
                    }))

                    if response and not response.error then
                      local file = io.open(campaign_path .. "/" .. campaign_icon_name, "w")
                      file:write(response.body)
                      file:close()
                    end

                  end
                  local campaign_pack_url = campaign_item.creatives_pack_url
                  if campaign_pack_url then
                    local campaign_pack_name = string.match(campaign_pack_url, "([^/%?=]-)$")

                    local response = coroutine.yield(turbo.async.HTTPClient():fetch(campaign_pack_url, {
                      request_timeout = 600
                    }))

                    if response and not response.error then
                      local file = io.open(campaign_path .. "/" .. campaign_pack_name, "w")
                      file:write(response.body)
                      file:close()
                      file = io.open(campaign_path .. "/name.txt", "w")
                      file:write(campaign_item.campaign_name)
                      file:close()
                      local status, content = oscapture(string.format("7z e %s -y -o%s -r", campaign_path .. "/" .. campaign_pack_name, campaign_path))
                      if status then
                        oscapture(string.format("cd %s; rename 'y/A-Z/a-z/' *", campaign_path))
                        add_static()
                        self:redirect(app.data.address .. app.data.baseurl .. "#campaign-" .. campaign)
                      end
                    else
                      error(turbo.web.HTTPError(404, "error on activate campaign"))
                    end
                  end
                end
              end

            end
          end
        end
      end
    end

    app.data.application:add_handler("^" .. app.data.baseurl .. "activate$", webappActivate)

    local webappDeactivate = class("webappDeactivate", turbo.web.RequestHandler)

    function webappDeactivate:get()
      local session = self:get_cookie("turbo-session")
      if session and sessions[session] then
        local user_name = sessions[session].username
        local campaign = self:get_argument("id")
        if campaign then
          local status, content = oscapture(string.format("[ -d %s ] && echo ok", app.data.basedir .. "campaigns/" ..user_name .. "/" .. campaign))
          if status and string.find(content, "ok") then
            local status, content = oscapture(string.format("rm -rf %s", app.data.basedir .. "campaigns/" .. user_name .. "/" .. campaign))
            if status then
              local file = io.open(app.data.basedir .. "users/" .. user_name .. ".json")
              if file then
                local content = file:read("*a")
                file:close()
                local status, result = pcall(turbo.escape.json_decode, content)
                if status then
                  local tags = {}
                  for _, value in ipairs(result.tags) do
                    if value[1] ~= tonumber(campaign) then
                      tags[#tags+1]=value
                    end
                  end
                  result.tags = tags
                  local file = io.open(app.data.basedir .. "users/" .. user_name .. ".json", "w")
                  file:write(turbo.escape.json_encode(result))
                  file:close()
                  self:redirect(app.data.address .. app.data.baseurl .. "#campaign-" .. campaign)
                end
              end
            end
          end
        end
      end
    end

    app.data.application:add_handler("^" .. app.data.baseurl .. "deactivate$", webappDeactivate)

    local webappTracking = class("webappTracking", turbo.web.RequestHandler)

    function webappTracking:get()
      local user_name = self:get_argument("user")
      if user_name and string.find(user_name, "^%w+$") then
        local file = io.open(app.data.basedir .. "users/" .. user_name .. ".json")
        if file then
          local content = file:read("*a")
          file:close()
          local status, result = pcall(turbo.escape.json_decode, content)
          if status then
            local campaign_name = "(Campaign not activated)"
            local file = io.open(app.data.basedir .. "campaigns/" .. user_name .. "/" .. self:get_argument("campaign_id", "") .. "/name.txt")
            if file then
              campaign_name = file:read("*a")
              file:close()
            end
            local campaign_id = self:get_argument("campaign_id", "")
            if campaign_id ~= "" and campaign_id ~= "{campaign_id}" then
              table.insert(result.tracking, {
                clickid = self:get_argument("clickid", ""),
                subid1 = self:get_argument("subid1", ""),
                subid2 = self:get_argument("subid2", ""),
                subid3 = self:get_argument("subid3", ""),
                subid4 = self:get_argument("subid4", ""),
                subid5 = self:get_argument("subid5", ""),
                campaign_id = self:get_argument("campaign_id", ""),
                campaign_name = campaign_name,
                idfa = self:get_argument("idfa", ""),
                gaid = self:get_argument("gaid", ""),
                ip = self:get_argument("ip", ""),
                payout = self:get_argument("payout", ""),
                device_model = self:get_argument("device_model", ""),
                device_brand = self:get_argument("device_brand", ""),
                os = self:get_argument("os", ""),
                os_version = self:get_argument("os_version", ""),
                user_agent = self:get_argument("user_agent", ""),
                operator = self:get_argument("operator", ""),
                time = turbo.util.time_format_http_header(os.time())
              })
              file = io.open(app.data.basedir .. "users/" .. user_name .. ".json", "w")
              file:write(turbo.escape.json_encode(result))
              file:close()
              app:onPromote(user_name, result.tracking)
            end
          end
        end
      end
    end

    app.data.application:add_handler("^" .. app.data.baseurl .. "tracking$", webappTracking)

  else
    turbo.log.error("(turbo-personaly) Unable to start. No users specified.")
  end

  return app
end

function personaly:getCampaigns(user, conditions, callback)
  local campaigns = {}
  if self.data.users[user] then
    local handler = function(response)
      if not response or response.error then
        return
      end
      local status, result = pcall(turbo.escape.json_decode, response.body)
      if status then
        for _, campaign in ipairs(result.campaigns) do
          local file = io.open(self.data.basedir .. "campaigns/" .. user .. "/" .. campaign.id .. "/name.txt")
          if file then
            file:close()
            if huntable(campaign, conditions) then
              campaigns[#campaigns + 1] = campaign
            end
          end
        end
      end
      callback(campaigns)
    end
    fetch(turbo, self.data.users[user].url, {}, handler)
  end
end

function personaly:getRandomCampaign(user, conditions, callback)
  math.randomseed(os.time())
  self:getCampaigns(user, conditions, function(campaigns)
    if campaigns and #campaigns > 0 then
      callback(campaigns[math.random(1, #campaigns)])
    end
  end)
end

function personaly:getCampaignsByTag(user, conditions, tags, callback)
  if type(tags) ~= "table" then
    tags = { tags }
  end
  self:getCampaigns(user, conditions, function(campaigns)
    if not campaigns then
      callback(nil)
    end
    local user_tags = {}
    local file = io.open(self.data.basedir .. "users/" .. user .. ".json")
    if file then
      local content = file:read("*a")
      file:close()
      local status, result = pcall(turbo.escape.json_decode, content)
      if status then
        for _, tag in ipairs(result.tags) do
          user_tags[#user_tags+1] = {
            campaign = tag[1],
            creative = tag[2],
            tag = tag[3]
          }
        end
      end
    end
    local selected = {}
    for _, campaign in pairs(campaigns) do
      local creatives = {}
      for _, creative in pairs(campaign.creatives) do
        for _, creative2 in pairs(creative) do
          creatives[#creatives + 1] = creative2
        end
      end
      for _, tag in pairs(user_tags) do
        if tag.campaign == campaign.id then
          for _, value in pairs(creatives) do
            local filename = string.match(value.creative_url or "", "f_name=([^&]+)")
            if filename and filename ~= "" then
              filename= string.lower(filename)
              if turbo.util.file_exists(self.data.basedir.. "campaigns/" .. user .. "/" .. campaign.id .. "/" .. filename) then
                if tag.creative == string.gsub(filename, "%W", "") then
                  for _, value2 in pairs(tags) do
                    if value2 == tag.tag then
                      if not selected[value2] then
                        selected[value2] = {}
                      end
                      local campaign2 = {}
                      for key3, value3 in pairs(campaign) do
                        campaign2[key3] = value3
                      end
                      for key3, value3 in pairs(value) do
                        campaign2[key3] = value3
                      end
                      campaign2.creative_url = self.data.address .. self.data.baseurl .. "static/" .. user .. "/" .. campaign.id .. "/" .. filename
                      campaign2.creative_path = self.data.basedir.. "campaigns/" .. user .. "/" .. campaign.id .. "/" .. filename
                      campaign2.tag = value2
                      table.insert(selected[value2], campaign2)
                      break
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
    callback(selected)
  end)

end

function personaly:getRandomCampaignByTag(user, conditions, tags, callback)
  math.randomseed(os.time())
  self:getCampaignsByTag(user, conditions, tags, function(campaigns)
    if campaigns then
      local selected = {}
      for tag, campaign_list in pairs(campaigns) do
        for _, value in pairs(tags) do
          if value == tag then
            for _, value2 in pairs(campaign_list) do
              selected[#selected + 1] = value2
            end
            break
          end
        end
      end
      if #selected == 0 then
        callback(false)
        return
      end
      callback(selected[math.random(1, #selected)])
    end
  end)
end

return personaly