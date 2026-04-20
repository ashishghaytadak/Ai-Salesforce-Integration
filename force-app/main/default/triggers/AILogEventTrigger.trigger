/**
 * Trigger on AI_Log_Event__e Platform Event
 * Creates AI_Interaction_Log__c records asynchronously
 * This ensures audit logging doesn't impact REST API performance
 */
trigger AILogEventTrigger on AI_Log_Event__e (after insert) {
    List<AI_Interaction_Log__c> logsToInsert = new List<AI_Interaction_Log__c>();

    for (AI_Log_Event__e evt : Trigger.new) {
        logsToInsert.add(new AI_Interaction_Log__c(
            Action__c = evt.Action__c,
            Record_Id__c = evt.Record_Id__c,
            Request_Payload__c = evt.Payload__c,
            Status__c = evt.Status__c,
            User__c = evt.User_Id__c,
            Timestamp__c = DateTime.now()
        ));
    }

    if (!logsToInsert.isEmpty()) {
        insert logsToInsert;
    }
}
