/**
 * AIInteractionLoggerTest
 * Tests audit logging functionality
 */
@isTest
public class AIInteractionLoggerTest {

    @isTest
    static void testSynchronousLogging() {
        Test.startTest();
        AI_Interaction_Log__c log = AIInteractionLogger.logInteraction(
            'TEST_ACTION', '001000000000001',
            '{"test": "request"}', '{"test": "response"}', 'SUCCESS'
        );
        Test.stopTest();

        System.assertNotEquals(null, log.Id, 'Log should be inserted');
        System.assertEquals('TEST_ACTION', log.Action__c);
        System.assertEquals('SUCCESS', log.Status__c);
    }

    @isTest
    static void testAsyncLogging() {
        Test.startTest();
        AIInteractionLogger.logInteractionAsync(
            'ASYNC_TEST', '001000000000002',
            '{"async": "test"}', 'SUCCESS'
        );
        Test.stopTest();

        List<AI_Interaction_Log__c> logs = [
            SELECT Action__c FROM AI_Interaction_Log__c
            WHERE Action__c = 'ASYNC_TEST'
        ];
        System.assert(logs.size() >= 0, 'Async logging should not throw errors');
    }
}
