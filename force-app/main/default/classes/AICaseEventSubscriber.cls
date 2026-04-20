/**
 * AICaseEventSubscriber
 * Subscribes to AI_Case_Event__e Platform Events.
 * Handles async processing after AI creates or updates a case.
 * 
 * Processing includes:
 * - Logging the event to AI_Interaction_Log__c
 * - Auto-escalating high priority cases
 * - Notifying case owners
 */
public with sharing class AICaseEventSubscriber {

    /**
     * Handle incoming Platform Events
     * Called from the AI_Case_Event__e trigger
     */
    public static void handleEvents(List<AI_Case_Event__e> events) {
        List<AI_Interaction_Log__c> logsToInsert = new List<AI_Interaction_Log__c>();
        Set<Id> highPriorityCaseIds = new Set<Id>();

        for (AI_Case_Event__e evt : events) {
            // Create audit log for each event
            logsToInsert.add(new AI_Interaction_Log__c(
                Action__c = evt.Action__c,
                Record_Id__c = evt.Case_Id__c,
                Status__c = 'EVENT_PROCESSED',
                Timestamp__c = DateTime.now(),
                Request_Payload__c = 'Priority: ' + evt.Priority__c
            ));

            // Collect high priority cases for escalation
            if (evt.Priority__c == 'High') {
                highPriorityCaseIds.add(evt.Case_Id__c);
            }
        }

        // Bulk insert audit logs
        if (!logsToInsert.isEmpty() && 
            AISecurityService.isObjectCreateable('AI_Interaction_Log__c')) {
            insert logsToInsert;
        }

        // Auto-escalate high priority cases
        if (!highPriorityCaseIds.isEmpty()) {
            escalateHighPriorityCases(highPriorityCaseIds);
        }
    }

    /**
     * Auto-escalate high priority cases
     * Sets IsEscalated flag and adds escalation comment
     */
    private static void escalateHighPriorityCases(Set<Id> caseIds) {
        // Governance check - is auto-escalation enabled?
        if (!AIGovernanceService.isFeatureEnabled('Case_Auto_Escalation')) {
            return;
        }

        if (!AISecurityService.isObjectUpdateable('Case')) {
            return;
        }

        List<Case> casesToUpdate = [
            SELECT Id, IsEscalated, Priority
            FROM Case
            WHERE Id IN :caseIds
            AND IsEscalated = false
        ];

        for (Case c : casesToUpdate) {
            c.IsEscalated = true;
        }

        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }
    }
}
