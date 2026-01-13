@{
    # Prefer explicit includes to keep signal high
    IncludeRules = @(
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSAvoidGlobalVars',
        'PSUseCorrectCasing',
        'PSUseConsistentWhitespace',
        'PSUseApprovedVerbs',
        'PSAvoidUsingWriteHost'
    )

    Rules = @{
        PSUseConsistentWhitespace = @{
            CheckOpenBrace = $true
            CheckSeparator = $true
            CheckInnerWhitespace = $true
            CheckPipelineLineTermination = $true
        }
    }
}