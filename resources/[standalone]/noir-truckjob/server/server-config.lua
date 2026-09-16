-- ============================================================
-- SERVER CONFIG (SENSITIVE SETTINGS)
-- This file runs SERVER-SIDE ONLY and is NOT sent to clients.
-- Move all sensitive data (webhooks, tokens, etc.) here.
-- ============================================================

ServerConfig = {}

-- Discord webhook URL for logging (leave '' to disable).
-- Do not commit live webhook URLs to public repositories.
ServerConfig.DiscordWebhook = ''

-- Set to true to enable the server-side version update checker.
ServerConfig.EnableVersionCheck = false
