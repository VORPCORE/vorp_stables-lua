fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'VORP @CrimsonFreak'
name 'VORP Stables'
description 'A Stables script for vorp core framework'
repository 'https://github.com/VORPCORE/vorp_stables-lua'
lua54 'yes'

shared_scripts {
  "keys.lua",
  "events.lua",
  "data.lua",
  "languages.lua",
  "deathReasons.lua",
  "config.lua",
}
client_scripts {
  '@vorp_core/client/dataview.lua',
  'Client/*.lua'
}
server_script 'Server/main.lua'

files {
  'UI/dist/assets/*.js',
  'UI/dist/assets/*.css',
  'UI/dist/index.html',
}

ui_page 'UI/dist/index.html'

--version check dont touch
version '1.3'
vorp_checker 'yes'
vorp_name '^4Resource version Check^3'
vorp_github 'https://github.com/VORPCORE/vorp_stables-lua'
