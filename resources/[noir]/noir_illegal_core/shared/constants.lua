NoirIllegal = NoirIllegal or {}

NoirIllegal.Errors = {
    INVALID_SOURCE = 'Invalid or offline player source.',
    INVALID_ARGUMENT = 'One or more arguments are invalid.',
    FORBIDDEN_CALLER = 'The calling resource is not authorized.',
    ACTIVITY_DISABLED = 'This activity is disabled.',
    INVALID_ACTIVITY = 'Unknown activity key.',
    ORGANIZATION_MISMATCH = 'The organization does not match the player current organization.',
    NOT_ELIGIBLE = 'The player does not meet the activity requirements.',
    COOLDOWN_ACTIVE = 'Activity cooldown is active.',
    DUPLICATE_TRANSACTION = 'The transaction id was already used for another request.',
    NOT_FOUND = 'The requested entity was not found.',
    DATABASE_ERROR = 'The database operation failed.',
    INTERNAL_ERROR = 'An internal error occurred.',
}

NoirIllegal.SubjectTypes = {
    PLAYER = 'player',
    ORGANIZATION = 'organization',
}

function NoirIllegal.error(code, details)
    return {
        ok = false,
        code = code,
        message = NoirIllegal.Errors[code] or NoirIllegal.Errors.INTERNAL_ERROR,
        details = details,
    }
end
