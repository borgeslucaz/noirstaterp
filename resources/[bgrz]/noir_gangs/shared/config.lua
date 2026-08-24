Config = {}
Config.AdminAce = 'noir.gangsetup'
Config.Invitation = { maxDistance = 3.0, duration = 30, cooldown = 10 }
Config.ManagementDistance = 2.0
Config.DefaultGrade = 0
Config.DefaultZoneSize = vec3(1.5, 1.5, 1.5)
Config.DefaultPermissions = {
    [0] = { view_members = true },
    [1] = { view_members = true },
    [2] = { view_members = true, invite = true },
    [3] = { view_members = true, view_offline_members = true, invite = true, remove_member = true, promote = true, demote = true },
    [4] = { view_members = true, view_offline_members = true, invite = true, remove_member = true, promote = true, demote = true, manage_permissions = true, manage_ranks = true },
}
