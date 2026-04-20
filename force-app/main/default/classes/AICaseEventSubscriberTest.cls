/**
 * AICaseEventSubscriberTest
 * Tests Platform Event handling
 */
@isTest
public class AICaseEventSubscriberTest {

    @isTest
    static void testHandleMediumPriorityEvent() {
        Case testCase = new Case(
            Subject = 'Medium Priority Test',
            Status = 'New',
            Priority = 'Medium'
        );
        insert testCase;

        List<AI_Case_Event__e> events = new List<AI_Case_Event__e>{
            new AI_Case_Event__e(
                Case_Id__c = testCase.Id,
                Action__c = 'NEW_CASE',
                Priority__c = 'Medium'
            )
        };

        Test.startTest();
        AICaseEventSubscriber.handleEvents(events);
        Test.stopTest();

        Case updated = [SELECT IsEscalated FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(false, updated.IsEscalated, 'Medium priority should not be escalated');
    }
}
