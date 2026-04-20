/**
 * AIInteractionLogger
 * Logs every AI interaction to AI_Interaction_Log__c for audit and compliance.
 * Uses Platform Events for async logging to avoid impacting API performance.
 */
public with sharing class AIInteractionLogger {

    /**
     * Log an AI interaction synchronously (for non-critical paths)
     */
    public static AI_Interaction_Log__c logInteraction(
        String action,
        String recordId,
        String requestPayload,
        String responsePayload,
        String status
    ) {
        AI_Interaction_Log__c log = new AI_Interaction_Log__c(
            Action__c = action,
            Record_Id__c = recordId,
            Request_Payload__c = truncateField(requestPayload, 131072),
            Response_Payload__c = truncateField(responsePayload, 131072),
            Status__c = status,
            Timestamp__c = DateTime.now(),
            User__c = UserInfo.getUserId(),
            User_Name__c = UserInfo.getUserName(),
            Session_Id__c = UserInfo.getSessionId()
        );

        if (AISecurityService.isObjectCreateable('AI_Interaction_Log__c')) {
            insert log;
        }
        return log;
    }

    /**
     * Log an AI interaction asynchronously via Platform Event
     * Use this for high-volume or performance-sensitive paths
     */
    public static void logInteractionAsync(
        String action,
        String recordId,
        String payload,
        String status
    ) {
        AI_Log_Event__e logEvent = new AI_Log_Event__e(
            Action__c = action,
            Record_Id__c = recordId,
            Payload__c = truncateField(payload, 131072),
            Status__c = status,
            User_Id__c = UserInfo.getUserId()
        );

        Database.SaveResult sr = EventBus.publish(logEvent);
        if (!sr.isSuccess()) {
            System.debug(LoggingLevel.ERROR, 
                'Failed to publish AI log event: ' + sr.getErrors()[0].getMessage()
            );
        }
    }

    /**
     * Query interaction logs for a specific record
     */
    public static List<AI_Interaction_Log__c> getLogsForRecord(String recordId) {
        if (!AISecurityService.isObjectAccessible('AI_Interaction_Log__c')) {
            throw new AISecurityService.AISecurityException(
                'Insufficient access to AI Interaction Logs'
            );
        }
        return [
            SELECT Id, Action__c, Record_Id__c, Status__c, 
                   Timestamp__c, User_Name__c, Request_Payload__c
            FROM AI_Interaction_Log__c
            WHERE Record_Id__c = :recordId
            ORDER BY Timestamp__c DESC
            LIMIT 50
        ];
    }

    /**
     * Query recent interaction logs across all records
     */
    @AuraEnabled(cacheable=true)
    public static List<AI_Interaction_Log__c> getRecentLogs(Integer limitCount) {
        if (!AISecurityService.isObjectAccessible('AI_Interaction_Log__c')) {
            throw new AISecurityService.AISecurityException(
                'Insufficient access to AI Interaction Logs'
            );
        }
        return [
            SELECT Id, Action__c, Record_Id__c, Status__c,
                   Timestamp__c, User_Name__c
            FROM AI_Interaction_Log__c
            ORDER BY Timestamp__c DESC
            LIMIT :limitCount
        ];
    }

    /**
     * Truncate long strings to fit within field limits
     */
    private static String truncateField(String value, Integer maxLength) {
        if (value == null) return null;
        return value.length() > maxLength ? value.substring(0, maxLength) : value;
    }
}
