/**
 * AIGovernanceService
 * Reads governance configuration from Custom Metadata (AI_Config__mdt).
 * Allows admins to control AI behavior without code changes:
 * - Toggle AI features on/off
 * - Control which objects AI can access
 * - Set rate limiting rules
 * - Define allowed actions
 */
public with sharing class AIGovernanceService {

    // Cache config to avoid multiple SOQL queries in same transaction
    private static Map<String, AI_Config__mdt> configCache;

    /**
     * Load all AI configuration from Custom Metadata
     */
    private static Map<String, AI_Config__mdt> loadConfig() {
        if (configCache == null) {
            configCache = new Map<String, AI_Config__mdt>();
            for (AI_Config__mdt config : [
                SELECT DeveloperName, Label, Is_Active__c, 
                       Config_Value__c, Description__c
                FROM AI_Config__mdt
            ]) {
                configCache.put(config.DeveloperName, config);
            }
        }
        return configCache;
    }

    /**
     * Check if a specific AI feature is enabled
     * Example: isFeatureEnabled('Case_Auto_Assignment')
     */
    public static Boolean isFeatureEnabled(String featureName) {
        Map<String, AI_Config__mdt> configs = loadConfig();
        if (configs.containsKey(featureName)) {
            return configs.get(featureName).Is_Active__c;
        }
        // Default to disabled if config doesn't exist (fail-safe)
        return false;
    }

    /**
     * Get a configuration value by name
     * Example: getConfigValue('Max_Daily_AI_Calls')
     */
    public static String getConfigValue(String configName) {
        Map<String, AI_Config__mdt> configs = loadConfig();
        if (configs.containsKey(configName)) {
            return configs.get(configName).Config_Value__c;
        }
        return null;
    }

    /**
     * Check if AI is allowed to access a specific object
     */
    public static Boolean isObjectAllowedForAI(String objectName) {
        String allowedObjects = getConfigValue('Allowed_Objects');
        if (allowedObjects == null) return false;

        Set<String> objectSet = new Set<String>();
        for (String obj : allowedObjects.split(',')) {
            objectSet.add(obj.trim().toLowerCase());
        }
        return objectSet.contains(objectName.toLowerCase());
    }

    /**
     * Check rate limiting - has the user exceeded max AI calls today?
     */
    public static Boolean isWithinRateLimit(String userId) {
        String maxCallsStr = getConfigValue('Max_Daily_AI_Calls');
        if (maxCallsStr == null) return true; // No limit configured

        Integer maxCalls = Integer.valueOf(maxCallsStr);
        Integer todayCalls = [
            SELECT COUNT()
            FROM AI_Interaction_Log__c
            WHERE User__c = :userId
            AND Timestamp__c = TODAY
        ];

        return todayCalls < maxCalls;
    }

    /**
     * Get all active configurations (for LWC admin panel)
     */
    @AuraEnabled(cacheable=true)
    public static List<AI_Config__mdt> getAllConfigs() {
        return [
            SELECT DeveloperName, Label, Is_Active__c,
                   Config_Value__c, Description__c
            FROM AI_Config__mdt
            ORDER BY Label
        ];
    }

    /**
     * Clear config cache (use after admin makes changes)
     */
    public static void clearCache() {
        configCache = null;
    }
}
