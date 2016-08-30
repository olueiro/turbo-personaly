# turbo-personaly
Visual editor for Persona.ly Campaigns API

----

###Requirements

1. Unix system (Linux, Ubuntu)
2. [LuaRocks](https://luarocks.org)

###Installation

1. Install Turbo via LuaRocks: `luarocks install turbo`
2. Install 7zip: `sudo apt-get install p7zip p7zip-full p7zip-rar lzma lzma-dev`
3. Install dependencies: `luarocks install turbo-fetch`, `luarocks install huntable`

###Hello World

``` lua
local turbo = require("turbo") -- require Turbo.lua
local personaly = require("turbo-personaly") -- require this module

local app = turbo.web.Application() -- create a Application to listen

local campaigns = personaly.new({ -- create a new instance of this module
  application = app, -- pass Application to instance
  address = "http://YOUR-URL-HERE" -- add URL to access this application, optional (default is http://127.0.0.1)
  users = {
    admin = { -- you can change admin to your name (use only lowercase letters, no spaces)
      url = "http://dsp.persona.ly/api/campaigns?token=YOUR-TOKEN-HERE", -- paste API URL. Get in Persona.ly > Settings
      password = "admin" -- your unique password
    }
  }
})

app:listen(80)
turbo.ioloop.instance():start()
```

In your browser access `http://127.0.0.1:80/turbopersonaly/`, on right top corner type your defined password and click **Log In**.

If your address is not a localhost, copy **Global Callback URL** to Persona.ly > Settings > Global Callback URL.

If you have an approved campaign, click **Activate campaign** to enable it.

Add tags on creatives files to quick find the creatives using methods below:

``` lua
campaigns:getCampaigns("admin", {
}, function(data)

  print(turbo.log.stringify(data), "getCampaigns")
  
end)

campaigns:getRandomCampaign("admin", {
}, function(data)

  print(turbo.log.stringify(data), "getRandomCampaign")
  
end)

campaigns:getCampaignsByTag("admin", {
}, {"YOUR TAG HERE", "YOUR OTHER TAG HERE"}, function(data)

  print(turbo.log.stringify(data), "getCampaignsByTag")
  
end)

campaigns:getRandomCampaignByTag("admin", {
}, {"YOUR TAG HERE", "YOUR OTHER TAG HERE"}, function(data)

  print(turbo.log.stringify(data), "getRandomCampaignByTag")
  
end)
```

When you receive a new notification, you can define a function to handle it:

``` lua
campaigns.onPromote = function(user, data)
  print(turbo.log.stringify(data),"onPromote " .. user)
end
```

###License

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
